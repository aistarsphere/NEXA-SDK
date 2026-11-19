// The debug-build call audio panel (manual test sheet T1–T6).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexa_core/testing.dart';
import 'package:nexa_example/dev/call_audio_debug.dart';
import 'package:nexa_sdk/nexa_sdk.dart';

final class _Allow implements NexaPermissionHandler {
  const _Allow();
  @override
  Future<bool> request(NexaPermission permission) async => true;
}

final class _Platform implements NexaCallAudioPlatform {
  @override
  Future<Map<String, Object?>?> state() async => {
    'platform': 'android',
    'mode': 'in_communication',
    'route': 'earpiece',
    'phoneCall': false,
    'bluetoothPresent': false,
    'bluetoothPermissionNeeded': false,
  };
  @override
  Future<String?> reassertCommunicationMode() async => 'in_communication';
}

void main() {
  testWidgets('hidden outside a call; during a call shows mode, route, '
      'mute and the server counters', (tester) async {
    final transport = MockRealtimeVoiceTransport();
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
        voiceTransport: transport,
        voiceProvisioner: MockVoiceProvisioner(),
        permissionHandler: const _Allow(),
        callAudio: NexaCallAudio(
          platform: _Platform(),
          setSpeaker: (_) async {},
          readProcessing: () async => {
            'aec': 'platform',
            'ns': 'platform',
            'agc': 'software',
          },
          pollInterval: const Duration(hours: 1),
        ),
      ),
    );
    addTearDown(client.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: CallAudioDebugOverlay(
          voice: client.voice,
          child: const Scaffold(body: SizedBox.expand()),
        ),
      ),
    );
    expect(find.byKey(const Key('call_audio_debug')), findsNothing);

    await tester.runAsync(() async {
      await client.voice.start();
      for (
        var i = 0;
        i < 100 && client.voice.state.value.phase != VoiceState.listening;
        i++
      ) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      await client.voice.callAudio!.afterConnect();
      transport.emit(const RealtimeInterrupted());
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
    await tester.pump();
    expect(find.byKey(const Key('call_audio_debug')), findsOneWidget);
    expect(find.text('mode (actual): in_communication'), findsOneWidget);
    expect(find.text('route: earpiece'), findsOneWidget);
    expect(
      find.text('AEC / NS / AGC: platform / platform / software'),
      findsOneWidget,
    );
    expect(find.text('muted (user): false'), findsOneWidget);
    expect(find.text('interruptions (server): 1'), findsOneWidget);

    await tester.tap(find.byKey(const Key('call_audio_debug')));
    await tester.pump();
    expect(find.text('audio debug'), findsOneWidget);
    await tester.runAsync(() => client.voice.end());
  });
}
