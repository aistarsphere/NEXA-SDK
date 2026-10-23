import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexa_core/testing.dart';
import 'package:nexa_sdk/nexa_sdk.dart';
import 'package:nexa_ui/nexa_ui.dart';

import '../helpers.dart';

final class _Grant implements NexaPermissionHandler {
  @override
  Future<bool> request(NexaPermission permission) async => true;
}

void main() {
  late NexaClient client;
  late MockRealtimeVoiceTransport transport;

  setUp(() async {
    transport = MockRealtimeVoiceTransport();
    client = await Nexa.initialize(
      config: testConfig().copyWith(
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
          grantedCapabilities: const {
            NexaCapability.textChat,
            NexaCapability.liveVoice,
          },
        ),
        voiceTransport: transport,
        voiceProvisioner: MockVoiceProvisioner(),
        permissionHandler: _Grant(),
      ),
    );
  });

  tearDown(() => client.dispose());

  Widget host(Widget child) => MaterialApp(home: Scaffold(body: child));

  testWidgets('embedded capsule: start → listening → turn → mute → end', (
    tester,
  ) async {
    var ended = 0;
    await tester.pumpWidget(host(client.voiceView(onEnded: () => ended++)));
    await tester.pumpAndSettle();
    expect(find.text('Ready'), findsOneWidget);
    await tester.tap(find.byKey(const Key('nexa_voice_start')));
    await tester.pumpAndSettle();
    expect(find.text('Listening'), findsOneWidget);
    expect(find.byKey(const Key('nexa_voice_mute')), findsOneWidget);

    await transport.scriptedTurn(userText: 'hi', assistantText: 'Hello!');
    await tester.pumpAndSettle();
    expect(find.text('hi'), findsOneWidget);
    expect(find.text('Hello!'), findsOneWidget);

    await tester.tap(find.byKey(const Key('nexa_voice_mute')));
    await tester.pumpAndSettle();
    expect(find.text('Muted'), findsOneWidget);
    expect(transport.isMicrophoneEnabled, isFalse);

    await tester.tap(find.byKey(const Key('nexa_voice_end')));
    await tester.pumpAndSettle();
    expect(find.text('Call ended'), findsOneWidget);
    expect(ended, 1);
    expect(find.byKey(const Key('nexa_voice_start')), findsOneWidget);
  });

  testWidgets('Arabic + dark theme at runtime inside the capsule', (
    tester,
  ) async {
    await tester.pumpWidget(host(client.voiceView()));
    await tester.pumpAndSettle();
    client
      ..setLanguage('ar')
      ..setThemeMode(NexaThemeMode.dark);
    await tester.pumpAndSettle();
    expect(find.text('جاهز'), findsOneWidget);
    final ctx = tester.element(find.byType(NexaVoiceCapsule));
    expect(Directionality.of(ctx), TextDirection.rtl);
    expect(Theme.of(ctx).brightness, Brightness.dark);
  });

  testWidgets('autoStart begins the call; unmounting keeps the controller', (
    tester,
  ) async {
    await tester.pumpWidget(host(client.voiceView(autoStart: true)));
    await tester.pumpAndSettle();
    expect(client.voice.state.value.phase, VoiceState.listening);
    await tester.pumpWidget(host(const SizedBox()));
    await tester.pumpAndSettle();
    expect(
      client.voice.state.value.phase,
      VoiceState.listening,
      reason: 'the host decides when to end',
    );
    await client.voice.end();
    await tester.pumpAndSettle();
    expect(client.voice.state.value.phase, VoiceState.ended);
  });
}
