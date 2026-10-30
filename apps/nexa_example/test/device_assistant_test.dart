// LABEEB as Android assistant: device activations → live voice, the lock
// gate, and the microphone hand-over. Channels are mocked (no device).
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexa_assistant/nexa_assistant.dart';
import 'package:nexa_core/testing.dart';
import 'package:nexa_example/assistant/device_assistant.dart';
import 'package:nexa_example/host_auth_provider.dart';
import 'package:nexa_example/main.dart';
import 'package:nexa_sdk/nexa_sdk.dart';

void main() {
  const methods = MethodChannel('nexa_assistant/methods');
  const events = EventChannel('nexa_assistant/events');
  late List<String> calls;
  late Map<String, Object?> replies;
  late void Function(Map<String, Object?>) push;
  final closeReasons = <String>[];

  Future<(NexaClient, DeviceAssistant)> setUpApp(WidgetTester tester) async {
    calls = [];
    closeReasons.clear();
    replies = {'requestUnlock': 'unlocked'};
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(methods, (call) async {
      calls.add(call.method);
      if (call.method == 'closePanel') {
        closeReasons.add((call.arguments as Map)['reason'] as String);
      }
      return replies[call.method];
    });
    messenger.setMockStreamHandler(
      events,
      MockStreamHandler.inline(
        onListen: (_, sink) {
          push = sink.success;
        },
      ),
    );
    addTearDown(() {
      messenger.setMockMethodCallHandler(methods, null);
      messenger.setMockStreamHandler(events, null);
    });
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
        permissionHandler: const _AllowAll(),
      ),
    );
    addTearDown(client.dispose);
    final device = DeviceAssistant(
      client: client,
      plugin: NexaAssistant(supported: true),
    );
    addTearDown(device.dispose);
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    return (client, device);
  }

  Widget app(NexaClient client, DeviceAssistant device) => ExampleApp(
    client: client,
    auth: HostAuthProvider(
      hostBackendUri: Uri.parse('http://localhost:1'),
      applicationId: 'app_test',
    ),
    device: device,
  );

  /// Live voice animates continuously: pump frames instead of settling.
  Future<void> frames(WidgetTester tester) async {
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('wake activation opens live voice; mic handed over', (
    tester,
  ) async {
    final (client, device) = await setUpApp(tester);
    await tester.pumpWidget(app(client, device));
    await device.start();
    await tester.pumpAndSettle();
    expect(calls, containsAll(['configure', 'takePendingActivation']));

    push({'type': 'activation', 'source': 'wake', 'locked': false});
    await frames(tester);
    expect(find.byKey(const Key('live_voice_view')), findsOneWidget);
    expect(find.byKey(const Key('assistant_lock_gate')), findsNothing);
    // The call took the microphone: the wake listener was paused.
    expect(calls, contains('suspendListening'));

    await tester.tap(find.byKey(const Key('live_voice_close')));
    await frames(tester);
    expect(calls.last, 'resumeListening');
  });

  testWidgets('locked activation shows only the gate until unlocked', (
    tester,
  ) async {
    final (client, device) = await setUpApp(tester);
    await tester.pumpWidget(app(client, device));
    await device.start();
    await tester.pumpAndSettle();

    push({'type': 'activation', 'source': 'system', 'locked': true});
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('assistant_lock_gate')), findsOneWidget);
    // The conversation is not painted or readable behind the gate.
    expect(find.byKey(const Key('nexa_composer_field')), findsNothing);
    expect(find.byKey(const Key('live_voice_view')), findsNothing);

    replies['requestUnlock'] = 'cancelled';
    await tester.tap(find.byKey(const Key('assistant_lock_unlock')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('assistant_lock_gate')), findsOneWidget);

    replies['requestUnlock'] = 'unlocked';
    await tester.tap(find.byKey(const Key('assistant_lock_unlock')));
    await frames(tester);
    expect(find.byKey(const Key('assistant_lock_gate')), findsNothing);
    expect(find.byKey(const Key('live_voice_view')), findsOneWidget);
  });

  testWidgets('"Not now" leaves the lock screen without opening anything', (
    tester,
  ) async {
    final (client, device) = await setUpApp(tester);
    await tester.pumpWidget(app(client, device));
    await device.start();
    await tester.pumpAndSettle();
    push({'type': 'activation', 'source': 'keyguard', 'locked': true});
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('assistant_lock_cancel')));
    await tester.pumpAndSettle();
    expect(calls, containsAll(['endLockScreenSession', 'resumeListening']));
    expect(find.byKey(const Key('live_voice_view')), findsNothing);
  });

  testWidgets('cold start by the assist gesture opens voice once ready', (
    tester,
  ) async {
    final (client, device) = await setUpApp(tester);
    replies['takePendingActivation'] = {
      'type': 'activation',
      'source': 'system',
      'locked': false,
    };
    await device.start(); // before the UI exists
    await tester.pumpWidget(app(client, device));
    await frames(tester);
    expect(find.byKey(const Key('live_voice_view')), findsOneWidget);
  });
  testWidgets('system panel: shared call, close ends it with user_closed', (
    tester,
  ) async {
    final (client, device) = await setUpApp(tester);
    await tester.pumpWidget(app(client, device));
    await device.start();
    await tester.pumpAndSettle();

    push({
      'type': 'surface',
      'surface': 'panel',
      'position': 'bottom',
      'source': 'wake',
      'verified': true,
    });
    await frames(tester);
    expect(find.byKey(const Key('assistant_panel')), findsOneWidget);
    // The app is kept but not painted behind the panel.
    expect(find.byKey(const Key('nexa_composer_field')), findsNothing);
    expect(client.voice.state.value.isActive, isTrue);
    expect(calls, contains('suspendListening'));

    await tester.tap(find.byKey(const Key('nexa_panel_close')));
    await frames(tester);
    expect(closeReasons, ['user_closed']);
    expect(client.voice.state.value.isActive, isFalse);
    // The panel is still on screen: the wake listener waits.
    expect(calls, isNot(contains('resumeListening')));

    push({'type': 'surface', 'surface': 'hidden', 'reason': 'closed'});
    await tester.pumpAndSettle();
    expect(calls.last, 'resumeListening');
    expect(find.byKey(const Key('assistant_panel')), findsNothing);
    expect(find.byKey(const Key('nexa_composer_field')), findsOneWidget);
  });

  testWidgets('panel dismissed by the system ends the call', (tester) async {
    final (client, device) = await setUpApp(tester);
    await tester.pumpWidget(app(client, device));
    await device.start();
    await tester.pumpAndSettle();
    push({'type': 'surface', 'surface': 'panel', 'position': 'right'});
    await frames(tester);
    expect(client.voice.state.value.isActive, isTrue);
    push({'type': 'surface', 'surface': 'hidden', 'reason': 'dismissed'});
    await frames(tester);
    expect(client.voice.state.value.isActive, isFalse);
    expect(calls, contains('reportSessionEnd'));
  });

  testWidgets('expand continues the same call in the full app', (tester) async {
    final (client, device) = await setUpApp(tester);
    await tester.pumpWidget(app(client, device));
    await device.start();
    await tester.pumpAndSettle();
    push({'type': 'surface', 'surface': 'panel', 'position': 'bottom'});
    await frames(tester);
    final grant = client.voice.currentGrant?.voiceSessionId;
    await tester.tap(find.byKey(const Key('nexa_panel_expand')));
    await frames(tester);
    expect(calls, contains('expandPanel'));
    push({'type': 'surface', 'surface': 'hidden', 'reason': 'expand'});
    push({'type': 'activation', 'source': 'expand', 'locked': false});
    await frames(tester);
    expect(find.byKey(const Key('live_voice_view')), findsOneWidget);
    expect(client.voice.state.value.isActive, isTrue);
    expect(client.voice.currentGrant?.voiceSessionId, grant);
  });
}

final class _AllowAll implements NexaPermissionHandler {
  const _AllowAll();
  @override
  Future<bool> request(NexaPermission permission) async => true;
}
