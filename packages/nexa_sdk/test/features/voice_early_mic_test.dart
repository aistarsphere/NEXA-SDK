// The first seconds of a call (FIRST_SECONDS_AUDIO_2026-11-21): the
// microphone is published as soon as the room connects, in parallel with the
// agent handshake, and "listening" shows only once the agent is ready and the
// microphone is live.
import 'package:flutter_test/flutter_test.dart';
import 'package:nexa_core/testing.dart';
import 'package:nexa_sdk/nexa_sdk.dart';

import '../helpers.dart';

final class _Permissions implements NexaPermissionHandler {
  @override
  Future<bool> request(NexaPermission permission) async => true;
}

final class _AudioPlatform implements NexaCallAudioPlatform {
  final facts = <String, Object?>{
    'platform': 'android',
    'mode': 'in_communication',
    'route': 'speaker',
    'phoneCall': false,
    'bluetoothPresent': false,
    'bluetoothPermissionNeeded': false,
  };
  @override
  Future<bool> acquireFocus() async => true;
  @override
  Future<void> releaseFocus() async {}
  @override
  Future<Map<String, Object?>?> state() async => Map.of(facts);
  @override
  Future<String?> reassertCommunicationMode() async => 'in_communication';
}

const _signalCaps = RealtimeAgentReady(
  capabilities: {
    'client_signals': {
      'listening_control': 'nexa.voice.listening',
      'client_info': 'nexa.voice.client_info',
    },
  },
);

void main() {
  late MockRealtimeVoiceTransport transport;
  late NexaClient client;

  tearDown(() => client.dispose());

  Future<NexaVoiceController> voice({
    NexaVoiceOptions options = const NexaVoiceOptions(),
    Duration micDelay = const Duration(milliseconds: 300),
    NexaCallAudio? callAudio,
  }) async {
    transport = MockRealtimeVoiceTransport(
      handshakeOnConnect: false,
      microphoneDelay: micDelay,
    );
    client = await Nexa.initialize(
      config: testConfig(),
      auth: MockAuthProvider(),
      overrides: NexaOverrides(
        chatTransport: fastMock(),
        voiceTransport: transport,
        voiceProvisioner: MockVoiceProvisioner(),
        permissionHandler: _Permissions(),
        callAudio: callAudio,
      ),
      voiceOptions: options,
    );
    return client.voice;
  }

  Future<void> joined() =>
      waitFor(() => transport.isConnected, reason: 'room connected');

  Future<void> phase(NexaVoiceController v, VoiceState s) => waitFor(
    () => v.state.value.phase == s,
    reason: 'phase ${s.name} (now ${v.state.value.phase.name})',
  );

  test('the microphone is published before agent_ready', () async {
    final v = await voice(micDelay: Duration.zero);
    await v.start();
    await joined();
    await waitFor(() => transport.isMicrophoneEnabled, reason: 'mic on');
    expect(v.state.value.phase, VoiceState.connecting);
    transport.emit(const RealtimeConnected());
    await phase(v, VoiceState.listening);
    expect(transport.microphoneCalls, [true]); // no second publish
  });

  test('"listening" waits for the microphone; events meanwhile are '
      'replayed', () async {
    final v = await voice(micDelay: const Duration(milliseconds: 400));
    await v.start();
    await joined();
    // agent_ready while the publish is still running.
    transport.emit(const RealtimeConnected());
    transport.emit(const RealtimeUserSpeechStarted());
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(v.state.value.phase, VoiceState.connecting);
    expect(transport.isMicrophoneEnabled, isFalse);
    await phase(v, VoiceState.userSpeaking); // listening, then the replay
    expect(transport.isMicrophoneEnabled, isTrue);
    expect(transport.microphoneCalls, [true]);
  });

  test('muted at start: nothing is published early', () async {
    final v = await voice(options: const NexaVoiceOptions(startMuted: true));
    await v.start();
    await joined();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(transport.microphoneCalls, isEmpty);
    transport.emit(const RealtimeConnected());
    await phase(v, VoiceState.muted);
    expect(transport.isMicrophoneEnabled, isFalse);
  });

  test('mute while connecting reaches the early microphone', () async {
    final v = await voice();
    await v.start();
    await joined();
    await waitFor(
      () => transport.microphoneCalls.isNotEmpty,
      reason: 'early publish started',
    );
    await v.setMuted(muted: true);
    await waitFor(
      () => transport.microphoneCalls.length == 2,
      reason: 'mute queued after the publish',
    );
    await waitFor(() => !transport.isMicrophoneEnabled, reason: 'mic off');
    transport.emit(const RealtimeConnected());
    await phase(v, VoiceState.muted);
    expect(transport.isMicrophoneEnabled, isFalse);
    expect(transport.microphoneCalls, [true, false]);
  });

  test(
    'early publish fails: the call connects and reports the error',
    () async {
      final v = await voice(micDelay: Duration.zero);
      transport.failMicrophoneWith = const TransportException('no mic');
      await v.start();
      await joined();
      await waitFor(
        () => transport.microphoneCalls.isNotEmpty,
        reason: 'early publish tried',
      );
      transport.emit(const RealtimeConnected());
      // StartCapture retries once and surfaces the failure as today.
      await waitFor(
        () => transport.microphoneCalls.length == 2,
        reason: 'publish retried on connect',
      );
      await waitFor(() => v.state.value.error != null, reason: 'error shown');
    },
  );

  test('earlyMicrophone: false keeps the old order', () async {
    final v = await voice(
      options: const NexaVoiceOptions(earlyMicrophone: false),
      micDelay: Duration.zero,
    );
    await v.start();
    await joined();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(transport.microphoneCalls, isEmpty);
    transport.emit(const RealtimeConnected());
    await phase(v, VoiceState.listening);
    await waitFor(() => transport.isMicrophoneEnabled, reason: 'mic on');
  });

  test('a drop while waiting for the microphone voids the wait', () async {
    final v = await voice(micDelay: const Duration(milliseconds: 400));
    await v.start();
    await joined();
    transport.emit(const RealtimeConnected());
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await transport.simulateDrop(reconnect: false);
    await phase(v, VoiceState.reconnecting);
    await Future<void>.delayed(const Duration(milliseconds: 500));
    // The stale wait must not move the call to "listening".
    expect(v.state.value.phase, VoiceState.reconnecting);
  });

  test('a phone call at start: nothing is published early', () async {
    final platform = _AudioPlatform()..facts['phoneCall'] = true;
    final v = await voice(
      micDelay: Duration.zero,
      callAudio: NexaCallAudio(
        platform: platform,
        setSpeaker: (_) async {},
        readProcessing: () async => const {},
        pollInterval: const Duration(hours: 1),
      ),
    );
    await v.start();
    await joined();
    await waitFor(() => v.state.value.phoneCallHold, reason: 'held');
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(transport.microphoneCalls, isEmpty);
    transport.emit(const RealtimeConnected());
    await phase(v, VoiceState.listening);
    expect(transport.isMicrophoneEnabled, isFalse);
  });

  test('a full rejoin publishes early again and sends no signal before the '
      "agent's announcement", () async {
    final v = await voice(micDelay: Duration.zero);
    await v.start();
    await joined();
    transport.emit(const RealtimeConnected());
    transport.emit(_signalCaps);
    await phase(v, VoiceState.listening);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    transport.signals.clear();
    transport.microphoneCalls.clear();

    transport.simulateRoomDeleted();
    await waitFor(() => transport.grants.length == 2, reason: 'rejoined');
    await waitFor(
      () => transport.isMicrophoneEnabled,
      reason: 'early publish on rejoin',
    );
    expect(v.state.value.phase, VoiceState.reconnecting);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(
      transport.signals.where((s) => s.$1 == 'nexa.voice.listening'),
      isEmpty,
    );
    transport.emit(const RealtimeConnected());
    await phase(v, VoiceState.listening);
    expect(transport.microphoneCalls, [true]);
  });

  test('a second call on the same controller sends nothing before '
      'agent_ready', () async {
    final v = await voice(micDelay: Duration.zero);
    await v.start();
    await joined();
    transport.emit(const RealtimeConnected());
    transport.emit(_signalCaps);
    await phase(v, VoiceState.listening);
    await v.end();
    await phase(v, VoiceState.ended);
    transport.signals.clear();
    await v.start();
    await waitFor(() => transport.grants.length == 2, reason: 'second call');
    await waitFor(() => transport.isMicrophoneEnabled, reason: 'early mic');
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(transport.signals, isEmpty);
  });
}
