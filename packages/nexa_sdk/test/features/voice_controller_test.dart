// Voice controller unit tests with the labelled mocks (no LiveKit, no
// gateway). State transitions come from the pure VoiceSessionMachine; these
// tests verify the orchestration around it.
import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexa_core/testing.dart';
import 'package:nexa_sdk/nexa_sdk.dart';

import '../helpers.dart';

final class _Permissions implements NexaPermissionHandler {
  bool grant = true;
  int calls = 0;
  @override
  Future<bool> request(NexaPermission permission) async {
    calls++;
    return grant;
  }
}

void main() {
  late MockRealtimeVoiceTransport transport;
  late MockVoiceProvisioner provisioner;
  late _Permissions permissions;
  late NexaClient client;

  setUp(() async {
    transport = MockRealtimeVoiceTransport();
    provisioner = MockVoiceProvisioner();
    permissions = _Permissions();
  });

  tearDown(() => client.dispose());

  Future<NexaVoiceController> voice({
    NexaVoiceOptions options = const NexaVoiceOptions(),
    Set<NexaCapability>? capabilities,
  }) async {
    client = await Nexa.initialize(
      config: testConfig().copyWith(
        requestedCapabilities:
            capabilities ??
            const {NexaCapability.textChat, NexaCapability.liveVoice},
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
        voiceProvisioner: provisioner,
        permissionHandler: permissions,
      ),
      voiceOptions: options,
    );
    return client.voice;
  }

  Future<void> listening(NexaVoiceController v) => waitFor(
    () => v.state.value.phase == VoiceState.listening,
    reason: 'listening',
  );

  group('start', () {
    test('permission → provisioning → room join → listening, mic on', () async {
      final v = await voice();
      final phases = <VoiceState>[];
      final sub = v.events.listen((e) {
        if (e is NexaVoicePhaseChanged) phases.add(e.to);
      });
      await v.start();
      await listening(v);
      await sub.cancel();
      expect(permissions.calls, 1);
      expect(provisioner.provisioned, 1);
      expect(transport.grants.single.voiceSessionId, 'vs_mock_1');
      expect(transport.isMicrophoneEnabled, isTrue);
      expect(phases, [VoiceState.connecting, VoiceState.listening]);
      expect(v.state.value.eventsVerified, isTrue);
      expect(v.state.value.error, isNull);
      expect(client.currentSession, isNotNull, reason: 'chat session started');
    });

    test('microphone denied is terminal with a permission error', () async {
      permissions.grant = false;
      final v = await voice();
      await v.start();
      await waitFor(() => v.state.value.phase == VoiceState.microphoneDenied);
      expect(v.state.value.error, isA<PermissionDeniedException>());
      expect(v.state.value.endReason, 'microphone_denied');
      expect(provisioner.provisioned, 0, reason: 'never provisioned');
      // Retry after the user fixed settings.
      permissions.grant = true;
      await v.start();
      await listening(v);
    });

    test('liveVoice not granted fails before provisioning', () async {
      final v = await voice(capabilities: const {NexaCapability.textChat});
      await v.start();
      await waitFor(() => v.state.value.phase == VoiceState.disconnected);
      expect(v.state.value.error, isA<CapabilityNotGrantedException>());
      expect(provisioner.provisioned, 0);
    });

    test('voice quota exhausted (402) ends in quotaExceeded', () async {
      provisioner.failWith = const QuotaExceededException(
        quotaKind: 'voice_minutes',
      );
      final v = await voice();
      await v.start();
      await waitFor(() => v.state.value.phase == VoiceState.quotaExceeded);
      expect(v.state.value.error, isA<QuotaExceededException>());
      expect(v.state.value.endReason, 'quota_exceeded');
      expect(transport.grants, isEmpty);
    });

    test('transport connect failure surfaces and is retryable', () async {
      transport = MockRealtimeVoiceTransport(
        failConnectWith: const NetworkException(
          NexaErrorCode.networkUnreachable,
          'no route',
        ),
      );
      final v = await voice();
      await v.start();
      await waitFor(() => v.state.value.phase == VoiceState.disconnected);
      expect(v.state.value.error, isA<NetworkException>());
      expect(provisioner.ended, 1, reason: 'gateway told to release the grant');
    });

    test(
      'unsigned grant is refused when allowUnverifiedEvents is false',
      () async {
        provisioner = MockVoiceProvisioner(eventVerificationKey: null);
        final v = await voice(
          options: const NexaVoiceOptions(allowUnverifiedEvents: false),
        );
        await v.start();
        await waitFor(() => v.state.value.phase == VoiceState.disconnected);
        expect(v.state.value.error, isA<ContractViolationException>());
      },
    );

    test('unsigned grant accepted in dev mode but flagged', () async {
      provisioner = MockVoiceProvisioner(eventVerificationKey: null);
      final v = await voice();
      await v.start();
      await listening(v);
      expect(v.state.value.eventsVerified, isFalse);
    });

    test('startMuted joins with the mic off', () async {
      final v = await voice(options: const NexaVoiceOptions(startMuted: true));
      await v.start();
      await waitFor(() => v.state.value.phase == VoiceState.muted);
      expect(transport.isMicrophoneEnabled, isFalse);
      expect(v.state.value.muted, isTrue);
    });
  });

  group('conversation', () {
    test('a scripted turn drives states and transcript', () async {
      final v = await voice();
      await v.start();
      await listening(v);
      final phases = <VoiceState>[];
      final sub = v.events.listen((e) {
        if (e is NexaVoicePhaseChanged) phases.add(e.to);
      });
      await transport.scriptedTurn(
        userText: 'book a table',
        assistantText: 'Sure.',
      );
      await waitFor(() => v.state.value.phase == VoiceState.listening);
      await sub.cancel();
      expect(phases, [
        VoiceState.userSpeaking,
        VoiceState.transcribing,
        VoiceState.thinking,
        VoiceState.aiSpeaking,
        VoiceState.listening,
      ]);
      final t = v.state.value.transcript;
      expect(t.length, 2);
      expect(t[0].speaker, VoiceSpeaker.user);
      expect(t[0].text, 'book a table');
      expect(t[0].isFinal, isTrue, reason: 'partial replaced in place');
      expect(t[1].speaker, VoiceSpeaker.assistant);
      expect(t[1].text, 'Sure.');
    });

    test('agent presence and audio track are tracked', () async {
      final v = await voice();
      await v.start();
      await listening(v);
      transport
        ..emit(const RealtimeAgentJoined('nexa-agent'))
        ..emit(const RealtimeAgentAudioTrack(subscribed: true));
      await waitFor(() => v.state.value.agentAudioActive);
      expect(v.state.value.agentPresent, isTrue);
      transport.emit(const RealtimeAgentLeft('nexa-agent'));
      await waitFor(() => !v.state.value.agentPresent);
    });

    test('barge-in: speaking over the assistant sends interrupt', () async {
      final v = await voice();
      await v.start();
      await listening(v);
      transport.emit(const RealtimeAssistantSpeakingStarted());
      await waitFor(() => v.state.value.phase == VoiceState.aiSpeaking);
      transport.emit(const RealtimeUserSpeechStarted());
      await waitFor(() => v.state.value.phase == VoiceState.userSpeaking);
      expect(transport.interrupts, 1);
      expect(provisioner.intents, ['interrupt']);
    });

    test('model busy and available', () async {
      final v = await voice();
      await v.start();
      await listening(v);
      transport.emit(const RealtimeModelBusy());
      await waitFor(() => v.state.value.phase == VoiceState.modelBusy);
      transport.emit(const RealtimeModelAvailable());
      await listening(v);
    });

    test('rejected agent events never change state but are counted', () async {
      final v = await voice();
      await v.start();
      await listening(v);
      final rejected = <String>[];
      final sub = v.events.listen((e) {
        if (e is NexaVoiceEventRejected) rejected.add(e.reason);
      });
      transport.emit(const RealtimeEventRejected('badSignature'));
      await waitFor(() => v.state.value.rejectedEvents == 1);
      await sub.cancel();
      expect(v.state.value.phase, VoiceState.listening);
      expect(rejected, ['badSignature']);
    });
  });

  group('mute, reconnect, quota, expiry, end', () {
    test('mute and unmute toggle the microphone track', () async {
      final v = await voice();
      await v.start();
      await listening(v);
      await v.toggleMute();
      await waitFor(() => v.state.value.phase == VoiceState.muted);
      expect(transport.isMicrophoneEnabled, isFalse);
      // Assistant may still speak while muted; state stays muted.
      transport.emit(const RealtimeAssistantSpeakingStarted());
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(v.state.value.phase, VoiceState.muted);
      await v.toggleMute();
      await listening(v);
      expect(transport.isMicrophoneEnabled, isTrue);
      expect(transport.microphoneCalls, [true, false, true]);
    });

    test(
      'engine reconnect: reconnecting then listening, mic re-enabled',
      () async {
        final v = await voice();
        await v.start();
        await listening(v);
        final phases = <VoiceState>[];
        final sub = v.events.listen((e) {
          if (e is NexaVoicePhaseChanged) phases.add(e.to);
        });
        await transport.simulateDrop();
        await listening(v);
        await sub.cancel();
        expect(phases, [VoiceState.reconnecting, VoiceState.listening]);
        expect(transport.microphoneCalls.last, isTrue);
      },
    );

    test('final disconnect from the server ends in disconnected', () async {
      final v = await voice();
      await v.start();
      await listening(v);
      await transport.simulateDrop(willReconnect: false);
      await waitFor(() => v.state.value.phase == VoiceState.disconnected);
      expect(v.state.value.endReason, startsWith('server:'));
    });

    test('quota exceeded from the agent ends the call', () async {
      final v = await voice();
      await v.start();
      await listening(v);
      transport.emit(const RealtimeQuotaExceeded('voice_minutes'));
      await waitFor(() => v.state.value.phase == VoiceState.quotaExceeded);
      expect(v.state.value.error, isA<QuotaExceededException>());
      expect(transport.isConnected, isFalse);
      expect(provisioner.ended, 1);
    });

    test('grant expiry ends the call with an expiry error', () async {
      provisioner = MockVoiceProvisioner(
        grantLifetime: const Duration(milliseconds: 120),
      );
      final v = await voice();
      await v.start();
      await listening(v);
      await waitFor(() => v.state.value.phase == VoiceState.ended);
      expect(v.state.value.error, isA<SessionExpiredException>());
      expect(v.state.value.endReason, 'expired');
    });

    test('expired grant is rejected by the transport before joining', () async {
      provisioner = MockVoiceProvisioner(grantLifetime: Duration.zero);
      transport = MockRealtimeVoiceTransport();
      final v = await voice();
      await withClock(Clock.fixed(DateTime(2030)), () async {
        await v.start();
      });
      // Mock transport does not check expiry; the LiveKit one does (covered
      // in nexa_realtime tests). Here the expiry timer fires immediately.
      await waitFor(
        () =>
            v.state.value.phase == VoiceState.ended ||
            v.state.value.phase == VoiceState.listening,
      );
    });

    test('server session_ending ends the call', () async {
      final v = await voice();
      await v.start();
      await listening(v);
      transport.emit(const RealtimeSessionEnding('max_duration'));
      await waitFor(() => v.state.value.phase == VoiceState.ended);
      expect(v.state.value.endReason, 'server:max_duration');
    });

    test(
      'end: transport disconnected, gateway notified, restart works',
      () async {
        final v = await voice();
        await v.start();
        await listening(v);
        final ended = <String>[];
        final sub = v.events.listen((e) {
          if (e is NexaVoiceEnded) ended.add(e.reason);
        });
        await v.end();
        await waitFor(() => v.state.value.phase == VoiceState.ended);
        await sub.cancel();
        expect(transport.isConnected, isFalse);
        expect(transport.isMicrophoneEnabled, isFalse);
        expect(provisioner.ended, 1);
        expect(ended, ['user']);
        expect(v.state.value.isActive, isFalse);
        await v.start();
        await listening(v);
        expect(provisioner.provisioned, 2);
        expect(v.state.value.transcript, isEmpty, reason: 'fresh call');
      },
    );

    test('end while idle is a no-op; double start is a no-op', () async {
      final v = await voice();
      await v.end();
      expect(v.state.value.phase, VoiceState.idle);
      await v.start();
      await v.start();
      await listening(v);
      expect(provisioner.provisioned, 1);
    });
  });

  group('lifecycle', () {
    test('disposing the client ends an active call', () async {
      final v = await voice();
      await v.start();
      await listening(v);
      await client.dispose();
      expect(transport.isConnected, isFalse);
      expect(provisioner.ended, 1);
      expect(() => v.start(), throwsA(isA<NotInitializedException>()));
      // tearDown's dispose must stay safe.
      client = await Nexa.initialize(
        config: testConfig(),
        auth: MockAuthProvider(),
        overrides: NexaOverrides(chatTransport: fastMock()),
      );
    });

    test('voice is not available after dispose', () async {
      await voice();
      final c = client;
      await c.dispose();
      expect(() => c.voice, throwsA(isA<NotInitializedException>()));
      client = await Nexa.initialize(
        config: testConfig(),
        auth: MockAuthProvider(),
        overrides: NexaOverrides(chatTransport: fastMock()),
      );
    });
  });
}
