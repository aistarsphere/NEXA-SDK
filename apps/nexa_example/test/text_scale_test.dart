// Plan G-02 (automated part): the main screens stay usable at 200 % text in
// English and Arabic: nothing overflows, the key controls are still there.
// TalkBack and a real device pass are separate (docs/qa/a11y-<date>.md).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexa_core/testing.dart';
import 'package:nexa_example/main.dart';
import 'package:nexa_sdk/nexa_sdk.dart';

final class _Api implements NexaConversationsApi {
  @override
  bool get canList => true;
  @override
  Future<NexaHistoryPage> list({String? cursor, int limit = 20}) async =>
      NexaHistoryPage([
        for (var i = 1; i <= 4; i++)
          NexaHistoryEntry(
            id: 'srv_$i',
            kind: i.isEven ? NexaHistoryKind.voice : NexaHistoryKind.chat,
            sessionId: 'conv_$i',
            startedAt: DateTime.utc(2026, 1, i),
            updatedAt: DateTime.utc(2026, 1, i),
            title: 'A fairly long conversation title number $i for scaling',
            messageCount: 12,
          ),
      ]);
  @override
  dynamic noSuchMethod(Invocation invocation) => false;
}

void main() {
  Future<NexaClient> client(String lang) async {
    final c = await Nexa.initialize(
      config: NexaConfig(
        applicationId: 'app_test',
        gatewayBaseUri: Uri.parse('http://localhost'),
        environment: NexaEnvironment.development,
        languageTag: lang,
        requestedCapabilities: const {
          NexaCapability.textChat,
          NexaCapability.liveVoice,
        },
      ),
      auth: MockAuthProvider(),
      history: NexaHistoryOptions(
        cache: InMemoryHistoryStore(),
        server: _Api(),
      ),
      overrides: NexaOverrides(
        chatTransport: MockChatTransport(
          tokenDelay: Duration.zero,
          thinkDelay: Duration.zero,
        ),
        voiceTransport: MockRealtimeVoiceTransport(),
        voiceProvisioner: MockVoiceProvisioner(),
      ),
    );
    addTearDown(c.dispose);
    return c;
  }

  Future<void> frames(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  for (final lang in ['en', 'ar']) {
    group('200 % text, $lang', () {
      Future<ExampleApp> open(WidgetTester tester, String location) async {
        // A small phone: 360 x 740 dp.
        tester.view.physicalSize = const Size(1080, 2220);
        tester.view.devicePixelRatio = 3;
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.view.reset);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final c = await client(lang);
        final app = ExampleApp(
          client: c,
          auth: MockAuthProvider(),
          initialLocation: location,
        );
        await tester.pumpWidget(app);
        await frames(tester);
        return app;
      }

      testWidgets('conversation list', (tester) async {
        await open(tester, '/');
        expect(find.byKey(const Key('nexa_list')), findsOneWidget);
        expect(find.byKey(const Key('nexa_list_new')), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('chat', (tester) async {
        await open(tester, '/c/new');
        expect(find.byKey(const Key('nexa_composer_field')), findsOneWidget);
        expect(find.byKey(const Key('assistant_voice')), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('call', (tester) async {
        await open(tester, '/c/new/call');
        expect(find.byKey(const Key('live_voice_close')), findsOneWidget);
        expect(
          find.byWidgetPredicate(
            (w) => w.runtimeType.toString() == 'NexaVoiceCapsule',
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      });

      testWidgets('settings', (tester) async {
        await open(tester, '/settings');
        // The list builds lazily: scroll to About, which must be reachable.
        await tester.scrollUntilVisible(
          find.byKey(const Key('settings_about')),
          300,
        );
        expect(find.byKey(const Key('settings_about')), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    });
  }
}
