// Navigation rules of the assistant view (plan A-02): one call page at a
// time, a call from the home splash returns to the chat, and a host router
// can own the call route through the callbacks and `callPage`.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexa_core/testing.dart';
import 'package:nexa_sdk/nexa_sdk.dart';

void main() {
  late NexaClient client;

  Future<void> init() async {
    client = await Nexa.initialize(
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
      ),
    );
    addTearDown(client.dispose);
  }

  /// The live voice page animates continuously: no settling.
  Future<void> frames(WidgetTester tester) async {
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> phone(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }

  testWidgets('two quick taps on the header voice button open one call page', (
    tester,
  ) async {
    await phone(tester);
    await init();
    await tester.pumpWidget(
      MaterialApp(
        home: client.assistantView(brand: const NexaBrand(name: 'LABEEB')),
      ),
    );
    await tester.pumpAndSettle();

    // Two presses before the next frame (the real double tap).
    final press = tester
        .widget<IconButton>(find.byKey(const Key('assistant_voice')))
        .onPressed!;
    press();
    press();
    await frames(tester);
    expect(find.byKey(const Key('live_voice_close')), findsOneWidget);

    await tester.tap(find.byKey(const Key('live_voice_close')));
    await frames(tester);
    // One close was enough: nothing is left on top of the chat.
    expect(find.byKey(const Key('live_voice_close')), findsNothing);
    expect(find.byKey(const Key('assistant_voice')), findsOneWidget);
  });

  testWidgets('a call started from the home splash returns to the chat', (
    tester,
  ) async {
    await phone(tester);
    await init();
    await tester.pumpWidget(
      MaterialApp(
        home: client.assistantView(
          brand: const NexaBrand(name: 'LABEEB'),
          launchMode: NexaLaunchMode.home,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('assistant_home_voice')));
    await frames(tester);
    expect(find.byKey(const Key('live_voice_close')), findsOneWidget);

    await tester.tap(find.byKey(const Key('live_voice_close')));
    await frames(tester);
    // The conversation (chat), not the splash.
    expect(find.byKey(const Key('assistant_home_voice')), findsNothing);
    expect(find.byKey(const Key('assistant_voice')), findsOneWidget);
  });

  testWidgets('with onOpenCall the host owns the call route', (tester) async {
    await phone(tester);
    await init();
    var opened = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: client.assistantView(
          brand: const NexaBrand(name: 'LABEEB'),
          onOpenCall: (_, {required fromHome}) => opened++,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('assistant_voice')));
    await frames(tester);
    expect(opened, 1);
    // The SDK pushed nothing itself.
    expect(find.byKey(const Key('live_voice_close')), findsNothing);
  });

  testWidgets('callPage closes through the host callback', (tester) async {
    await phone(tester);
    await init();
    var closed = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: client
            .assistantView(brand: const NexaBrand(name: 'LABEEB'))
            .callPage(onClose: () => closed++),
      ),
    );
    await frames(tester);
    await tester.tap(find.byKey(const Key('live_voice_close')));
    await tester.pump();
    expect(closed, 1);
  });
}
