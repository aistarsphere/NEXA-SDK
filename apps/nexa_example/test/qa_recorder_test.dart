import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexa_core/testing.dart';
import 'package:nexa_example/dev/qa/qa_analysis.dart';
import 'package:nexa_example/dev/qa/qa_recorder.dart';
import 'package:nexa_example/main.dart';
import 'package:nexa_sdk/nexa_sdk.dart';

/// Focused acceptance check for the QA diagnostics: one chat and one voice
/// session through the real SDK code paths (labelled mock transports) must
/// produce an index plus one inspectable, redacted record per session.
///
/// The store is left in `build/qa_test_store` so the CLI can be tried on it:
/// `NEXA_QA_DIR=build/qa_test_store dart run tool/qa.dart report latest-chat`.
void main() {
  final store = Directory('build/qa_test_store');

  testWidgets('chat + voice sessions produce redacted, inspectable records', (
    tester,
  ) async {
    final qa = (await tester.runAsync(() async {
      if (store.existsSync()) store.deleteSync(recursive: true);
      return QaRecorder.open(
        root: store,
        appMeta: {'app_id': 'app_test', 'platform': 'test'},
      );
    }))!;
    qa.label.value = 'acceptance';
    final client = await Nexa.initialize(
      config: NexaConfig(
        applicationId: 'app_test',
        gatewayBaseUri: Uri.parse('http://localhost'),
        environment: NexaEnvironment.development,
        requestedCapabilities: const {
          NexaCapability.textChat,
          NexaCapability.liveVoice,
        },
      ),
      auth: MockAuthProvider(),
      overrides: NexaOverrides(
        chatTransport: MockChatTransport(
          tokenDelay: Duration.zero,
          thinkDelay: Duration.zero,
        ),
        voiceTransport: MockRealtimeVoiceTransport(),
        voiceProvisioner: MockVoiceProvisioner(),
        permissionHandler: const _AllowMicrophone(),
        diagnostics: qa,
      ),
    );
    addTearDown(client.dispose);

    // Chat: one message, streamed reply.
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ExampleApp(client: client, auth: MockAuthProvider(), qa: qa),
    );
    await tester.pumpAndSettle();
    const secretMessage = 'What can you help me with?';
    await tester.tap(find.text(secretMessage));
    await tester.pumpAndSettle();
    expect(find.textContaining('Welcome to NEXA'), findsOneWidget);

    // Voice: start, reach the room, end.
    await client.voice.start();
    await tester.pump(const Duration(seconds: 2));
    await client.voice.end();
    await tester.pump(const Duration(seconds: 2));
    await client.endSession();
    await tester.pumpAndSettle();

    // Defence in depth: a buggy caller passing secrets is still redacted.
    expect(
      QaRecorder.redactForTest({
        'authorization': 'Bearer abc',
        'participant_token': 'x',
        'path': '/v1?token=nxs_abcdef123&x=1',
        'note': 'eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxMjM0NTY3ODkwIn0.sig',
        'text': 'hello',
        'n': 3,
      }),
      {'path': '/v1?[REDACTED]&x=1', 'note': '[REDACTED]', 'n': 3},
    );

    await tester.runAsync(() async {
      await qa.flush();
      final index = [
        for (final l in File('${store.path}/index.jsonl').readAsLinesSync())
          (jsonDecode(l) as Map).cast<String, Object?>(),
      ];
      expect(index.map((e) => e['type']), containsAll(['chat', 'voice']));
      for (final e in index) {
        expect(e['outcome'], isNot('in_progress'));
        expect(e['label'], 'acceptance');
        expect(e['session_id'], isNotNull);
        final text = File('${store.path}/${e['file']}').readAsStringSync();
        // No credentials, join tokens or message bodies on disk.
        expect(text, isNot(contains('mock-token')));
        expect(text, isNot(contains('mock-join-token')));
        expect(text, isNot(contains('Bearer')));
        expect(text, isNot(contains(secretMessage)));
        expect(text, isNot(contains('Welcome to NEXA')));
      }

      List<QaLine> lines(String type) {
        final e = index.firstWhere((e) => e['type'] == type);
        return [
          for (final l in File('${store.path}/${e['file']}').readAsLinesSync())
            QaLine.fromJson((jsonDecode(l) as Map).cast<String, Object?>()),
        ];
      }

      final chat = QaAnalysis.of(lines('chat'));
      expect(chat.metrics['session_id'], startsWith('mock-session'));
      expect(chat.turns, hasLength(1));
      expect(chat.turns.single['first_token_ms'], isA<int>());
      expect(chat.turns.single['total_ms'], isA<int>());
      expect(chat.transcript, isEmpty); // capture was off

      final voice = QaAnalysis.of(lines('voice'));
      expect(voice.metrics['voice_session_id'], isNotNull);
      expect(voice.metrics['create_ms'], isA<int>());
      expect(voice.metrics['end_reason'], isNotNull);
      final events = lines('voice').map((l) => l.event).toList();
      expect(
        events,
        containsAllInOrder([
          'qa.record_started',
          'voice.start',
          'voice.permission',
          'voice.created',
          'voice.teardown_done',
          'qa.record_ended',
        ]),
      );
    });
  });
}

final class _AllowMicrophone implements NexaPermissionHandler {
  const _AllowMicrophone();
  @override
  Future<bool> request(NexaPermission permission) async => true;
}
