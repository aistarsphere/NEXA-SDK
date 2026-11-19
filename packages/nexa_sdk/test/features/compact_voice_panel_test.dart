// Compact assistant panel: same voice controller as the app, real-state
// orb, idle timeout rules, close / mute / expand, reduced motion.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexa_core/testing.dart';
import 'package:nexa_sdk/nexa_sdk.dart';

import '../helpers.dart';

final class _AllowAll implements NexaPermissionHandler {
  const _AllowAll();
  @override
  Future<bool> request(NexaPermission permission) async => true;
}

void main() {
  late MockRealtimeVoiceTransport transport;
  late MockVoiceProvisioner provisioner;
  late NexaClient client;
  late List<NexaPanelCloseReason> closed;
  var expanded = 0;

  Future<void> init(WidgetTester tester) async {
    transport = MockRealtimeVoiceTransport();
    provisioner = MockVoiceProvisioner();
    closed = [];
    expanded = 0;
    client = await Nexa.initialize(
      config: testConfig(),
      auth: MockAuthProvider(),
      overrides: NexaOverrides(
        chatTransport: fastMock(),
        voiceTransport: transport,
        voiceProvisioner: provisioner,
        permissionHandler: const _AllowAll(),
      ),
    );
    addTearDown(client.dispose);
  }

  Widget panel({
    Duration? idle = const Duration(seconds: 60),
    bool reduceMotion = false,
    NexaPanelPlacement placement = NexaPanelPlacement.bottom,
  }) => MaterialApp(
    supportedLocales: NexaLocale.supported,
    localizationsDelegates: NexaLocale.delegates,
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: reduceMotion),
      child: Scaffold(
        body: Align(
          alignment: Alignment.bottomCenter,
          child: SizedBox(
            height: placement == NexaPanelPlacement.bottom ? 140 : 520,
            width: placement == NexaPanelPlacement.bottom ? 400 : 340,
            child: NexaCompactVoicePanel(
              voice: client.voice,
              tools: client.toolCalls,
              title: 'LABEEB',
              placement: placement,
              idleTimeout: idle,
              voiceVerified: true,
              onClosed: closed.add,
              onExpand: () => expanded++,
            ),
          ),
        ),
      ),
    ),
  );

  /// Unmounts the panel and ends any call so no timer outlives the test.
  Future<void> finish(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await client.voice.end();
    await tester.pump(const Duration(seconds: 1));
  }

  /// The orb animates while in a call: pump instead of settling.
  Future<void> frames(WidgetTester tester, [int n = 10]) async {
    for (var i = 0; i < n; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('opens the call on the shared controller and shows its state', (
    tester,
  ) async {
    await init(tester);
    await tester.pumpWidget(panel());
    await frames(tester);
    expect(client.voice.state.value.isActive, isTrue);
    expect(find.byKey(const Key('nexa_panel_orb')), findsOneWidget);
    expect(find.text('Listening'), findsOneWidget);
    expect(find.text('Your voice'), findsOneWidget); // verified chip

    transport.emit(const RealtimeTranscript(text: 'hello', isFinal: false));
    await frames(tester, 2);
    expect(find.text('hello'), findsOneWidget);
    await finish(tester);
  });

  testWidgets('idle timeout ends the call after 60 s of silence', (
    tester,
  ) async {
    await init(tester);
    await tester.pumpWidget(panel());
    await frames(tester);
    await tester.pump(const Duration(seconds: 55));
    expect(closed, isEmpty);
    // Real speech resets the countdown.
    transport.emit(const RealtimeTranscript(text: 'one more', isFinal: true));
    await tester.pump(const Duration(seconds: 55));
    expect(closed, isEmpty);
    await tester.pump(const Duration(seconds: 6));
    await frames(tester, 3);
    expect(closed, [NexaPanelCloseReason.idleTimeout]);
    expect(client.voice.state.value.isActive, isFalse);
    await finish(tester);
  });

  testWidgets('never times out while the assistant is speaking', (
    tester,
  ) async {
    await init(tester);
    await tester.pumpWidget(panel(idle: const Duration(seconds: 5)));
    await frames(tester);
    transport.emit(const RealtimeAssistantSpeakingStarted());
    transport.emit(const RealtimeAudioLevels(local: 0, agent: 0.4));
    await frames(tester, 2);
    await tester.pump(const Duration(seconds: 30));
    expect(closed, isEmpty, reason: 'speaking blocks the timeout');
    transport.emit(const RealtimeAssistantSpeakingEnded());
    transport.emit(const RealtimeAudioLevels(local: 0, agent: 0));
    await frames(tester, 2);
    await tester.pump(const Duration(seconds: 6));
    await frames(tester, 3);
    expect(closed, [NexaPanelCloseReason.idleTimeout]);
    await finish(tester);
  });

  testWidgets('close ends the call; mute toggles; expand keeps the call', (
    tester,
  ) async {
    await init(tester);
    await tester.pumpWidget(panel());
    await frames(tester);
    await tester.tap(find.byKey(const Key('nexa_panel_mute')));
    await frames(tester, 2);
    expect(client.voice.state.value.muted, isTrue);
    expect(find.text('Muted'), findsOneWidget);

    await tester.tap(find.byKey(const Key('nexa_panel_expand')));
    await frames(tester, 2);
    expect(expanded, 1);
    expect(client.voice.state.value.isActive, isTrue, reason: 'call continues');

    await tester.pumpWidget(const SizedBox()); // the panel is dismissed
    await tester.pumpWidget(panel());
    await frames(tester);
    await tester.tap(find.byKey(const Key('nexa_panel_close')));
    await frames(tester, 3);
    expect(closed, [NexaPanelCloseReason.userClosed]);
    expect(client.voice.state.value.isActive, isFalse);
    await finish(tester);
  });

  testWidgets('side placement and reduced motion still show the state', (
    tester,
  ) async {
    await init(tester);
    await tester.pumpWidget(
      panel(placement: NexaPanelPlacement.right, reduceMotion: true),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(find.byKey(const Key('nexa_panel_orb')), findsOneWidget);
    expect(find.text('Listening'), findsOneWidget);
    // Reduced motion: nothing keeps animating, so the tree settles.
    await tester.pumpAndSettle();
    await finish(tester);
  });

  testWidgets('no voice capacity: plain message and Retry, no endless '
      'connecting', (tester) async {
    await init(tester);
    provisioner.failCreateWith = const ServerException(
      statusCode: 503,
      message: 'No voice capacity is available right now.',
    );
    await tester.pumpWidget(panel());
    await frames(tester);
    expect(client.voice.state.value.isActive, isFalse);
    expect(
      find.text("Voice isn't available right now. Try again in a moment."),
      findsOneWidget,
    );
    expect(find.byKey(const Key('nexa_panel_retry')), findsOneWidget);

    provisioner.failCreateWith = null; // capacity is back
    await tester.tap(find.byKey(const Key('nexa_panel_retry')));
    await frames(tester);
    expect(client.voice.state.value.isActive, isTrue);
    expect(find.text('Listening'), findsOneWidget);
    await finish(tester);
  });

  testWidgets('choices presented in a panel call offer "Show options"', (
    tester,
  ) async {
    await init(tester);
    await tester.pumpWidget(panel());
    await frames(tester);
    expect(find.byKey(const Key('nexa_panel_show_options')), findsNothing);
    transport.emit(
      const RealtimeToolEvent('ui_presented', {
        'ui': {'schema': 'nexa.ui/1', 'id': 'ui_1', 'components': <Object>[]},
      }),
    );
    await frames(tester, 2);
    await tester.tap(find.byKey(const Key('nexa_panel_show_options')));
    await frames(tester, 2);
    expect(expanded, 1);
    expect(client.voice.state.value.isActive, isTrue, reason: 'same call');
    await finish(tester);
  });

  test('orb modes follow real states', () {
    expect(nexaOrbModeFor(VoiceState.aiSpeaking), NexaOrbMode.speaking);
    expect(nexaOrbModeFor(VoiceState.thinking), NexaOrbMode.understanding);
    expect(nexaOrbModeFor(VoiceState.reconnecting), NexaOrbMode.reconnecting);
    expect(nexaOrbModeFor(VoiceState.muted), NexaOrbMode.muted);
    expect(
      nexaOrbModeFor(VoiceState.listening, toolActive: true),
      NexaOrbMode.tool,
    );
    expect(
      nexaOrbModeFor(VoiceState.aiSpeaking, toolActive: true),
      NexaOrbMode.speaking,
    );
    expect(
      nexaOrbModeFor(VoiceState.disconnected, failed: true),
      NexaOrbMode.error,
    );
  });
}
