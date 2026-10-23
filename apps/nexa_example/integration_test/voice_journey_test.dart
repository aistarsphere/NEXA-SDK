// End-to-end live voice journey on a real device/simulator:
// reference gateway (mock agent, synthetic audio) + local livekit-server.
// Run with tool/e2e.sh. Requires microphone permission to be granted
// beforehand (the script does `simctl privacy grant microphone`).
//
// Proves: real LiveKit room join, microphone track published, remote agent
// audio track subscribed, signed agent events driving the capsule,
// mute/unmute, end-call. It does NOT prove AI inference (mock agent).
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:nexa_example/example_config.dart';
import 'package:nexa_example/host_auth_provider.dart';
import 'package:nexa_sdk/nexa_sdk.dart';

Future<void> _until(
  bool Function() condition, {
  required WidgetTester tester,
  required String reason,
  Duration timeout = const Duration(seconds: 30),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 100));
    if (condition()) return;
  }
  throw TestFailure('Timed out: $reason');
}

/// iOS simulators abort in CoreAudio when WebRTC opens the microphone; the
/// e2e script sets this so the join / remote-audio / signed-event path is
/// still proven there, while the microphone path is proven on Android or a
/// physical device.
final startMuted =
    const bool.fromEnvironment('NEXA_E2E_START_MUTED') ||
    (Platform.isIOS && Platform.environment.containsKey('SIMULATOR_UDID'));

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'joins a real LiveKit room, publishes mic, receives agent audio',
    (tester) async {
      final auth = HostAuthProvider(
        hostBackendUri: ExampleConfig.gatewayUri,
        applicationId: ExampleConfig.applicationId,
      );
      final client = await Nexa.initialize(
        config: NexaConfig(
          applicationId: ExampleConfig.applicationId,
          gatewayBaseUri: ExampleConfig.gatewayUri,
          environment: NexaEnvironment.development,
          requestedCapabilities: const {
            NexaCapability.textChat,
            NexaCapability.liveVoice,
          },
        ),
        auth: auth,
        overrides: const NexaOverrides(permissionHandler: _PreGranted()),
      );
      final events = <NexaVoiceEvent>[];
      client.voice.events.listen(events.add);

      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: client.voiceView())),
      );
      await tester.pumpAndSettle();

      // 1-4: start → permission → gateway grant → LiveKit room.
      await tester.tap(find.byKey(const Key('nexa_voice_start')));
      final v = client.voice;
      await _until(
        () =>
            v.state.value.phase == VoiceState.listening ||
            v.state.value.phase == VoiceState.muted ||
            v.state.value.phase.isTerminal ||
            v.state.value.phase == VoiceState.disconnected,
        tester: tester,
        reason: 'room joined',
      );
      expect(v.state.value.error, isNull, reason: '${v.state.value.error}');
      expect(v.currentGrant, isNotNull);
      expect(v.currentGrant!.liveKitUrl.scheme, 'ws');
      expect(v.state.value.eventsVerified, isTrue, reason: 'signed events');

      // 5: microphone track published (asynchronous after `listening`).
      if (startMuted) {
        expect(v.state.value.muted, isTrue);
        expect(client.voice.microphoneEnabled, isFalse);
      } else {
        await _until(
          () => client.voice.microphoneEnabled,
          tester: tester,
          reason: 'microphone track published',
        );
      }

      // 6-7: mock agent joins, publishes synthetic audio, sends signed events.
      await _until(
        () => v.state.value.agentPresent,
        tester: tester,
        reason: 'agent joined',
      );
      await _until(
        () => v.state.value.agentAudioActive,
        tester: tester,
        reason: 'remote agent audio track subscribed',
      );
      await _until(
        () => events.whereType<NexaVoicePhaseChanged>().any(
          (e) => e.to == VoiceState.aiSpeaking,
        ),
        tester: tester,
        reason: 'assistant_speaking_started (signed) reached the capsule',
      );
      await _until(
        () => v.state.value.transcript.any(
          (t) => t.speaker == VoiceSpeaker.assistant,
        ),
        tester: tester,
        reason: 'assistant transcript',
      );
      expect(
        v.state.value.rejectedEvents,
        0,
        reason: 'all agent packets verified',
      );

      // 8: mute / unmute.
      await tester.tap(find.byKey(const Key('nexa_voice_mute')));
      await _until(() => v.state.value.muted, tester: tester, reason: 'muted');
      expect(client.voice.microphoneEnabled, isFalse);
      await tester.tap(find.byKey(const Key('nexa_voice_mute')));
      await _until(
        () => !v.state.value.muted,
        tester: tester,
        reason: 'unmuted',
      );
      expect(client.voice.microphoneEnabled, isTrue);

      // 10: end.
      await tester.tap(find.byKey(const Key('nexa_voice_end')));
      await _until(
        () => v.state.value.phase == VoiceState.ended,
        tester: tester,
        reason: 'ended',
      );
      expect(events.whereType<NexaVoiceEnded>().single.reason, 'user');
      await client.dispose();
    },
  );
}

final class _PreGranted implements NexaPermissionHandler {
  const _PreGranted();
  @override
  Future<bool> request(NexaPermission permission) async => true;
}
