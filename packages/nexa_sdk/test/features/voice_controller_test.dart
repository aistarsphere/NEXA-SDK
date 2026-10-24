// Voice controller behaviour for contract nexa.voice.v1 (backend handoff
// 1.0.0), with the labelled mocks (no LiveKit, no gateway). The pure
// VoiceSessionMachine decides phases; these tests verify the lifecycle rules
// of voice-contract-v1.md §3, §7, §8 and session-lifecycle.md.
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

VoiceSessionStatus ended(String id, String reason, {String agent = 'ended'}) =>
    VoiceSessionStatus(
      voiceSessionId: id,
      status: 'ended',
      agentState: agent,
      endReason: reason,
    );

void main() {
  late MockRealtimeVoiceTransport transport;
  late MockVoiceProvisioner provisioner;
  late _Permissions permissions;
  late NexaClient client;

  setUp(() {
    transport = MockRealtimeVoiceTransport();
    provisioner = MockVoiceProvisioner();
    permissions = _Permissions();
  });

  tearDown(() => client.dispose());

  Future<NexaVoiceController> voice({
    NexaVoiceOptions options = const NexaVoiceOptions(),
    String lang = 'en',
  }) async {
    client = await Nexa.initialize(
      config: testConfig(lang: lang),
      auth: MockAuthProvider(),
      overrides: NexaOverrides(
        chatTransport: fastMock(),
        voiceTransport: transport,
        voiceProvisioner: provisioner,
        permissionHandler: permissions,
      ),
      voiceOptions: options,
    );
    return client.voice;
  }

  Future<void> phase(NexaVoiceController v, VoiceState s) => waitFor(
    () => v.state.value.phase == s,
    reason: 'phase ${s.name} (now ${v.state.value.phase.name})',
  );

  group('provisioning (POST /v1/sdk/voice/sessions)', () {
    test(
      'permission → create → join → handshake → listening, mic on',
      () async {
        final v = await voice(lang: 'ar');
        final phases = <VoiceState>[];
        final sub = v.events.listen((e) {
          if (e is NexaVoicePhaseChanged) phases.add(e.to);
        });
        await v.start();
        await phase(v, VoiceState.listening);
        await sub.cancel();
        expect(permissions.calls, 1);
        expect(provisioner.created, 1);
        expect(provisioner.languageTags.single, 'ar');
        expect(transport.grants.single.voiceSessionId, 'vs_mock_1');
        expect(
          transport.grants.single.participantIdentity,
          'nexa-user-vs_mock_1',
        );
        expect(v.state.value.agentIdentity, 'nexa-agent-vs_mock_1');
        expect(transport.isMicrophoneEnabled, isTrue);
        expect(phases, [VoiceState.connecting, VoiceState.listening]);
        expect(v.state.value.error, isNull);
      },
    );

    test(
      'voice does not require a chat session; passes it when one is active',
      () async {
        final v = await voice();
        await v.start();
        await phase(v, VoiceState.listening);
        expect(provisioner.chatSessionIds.single, isNull);
        await v.end();
        await phase(v, VoiceState.ended);
        final chat = await client.startSession();
        await v.start();
        await phase(v, VoiceState.listening);
        expect(provisioner.chatSessionIds.last, chat.sessionId);
      },
    );

    test('microphone denied: terminal, nothing created', () async {
      permissions.grant = false;
      final v = await voice();
      await v.start();
      await phase(v, VoiceState.microphoneDenied);
      expect(v.state.value.error, isA<PermissionDeniedException>());
      expect(provisioner.created, 0);
      permissions.grant = true;
      await v.start();
      await phase(v, VoiceState.listening);
    });

    test(
      '503 voice_unavailable: disconnected, nothing to clean up, retry waits Retry-After',
      () async {
        provisioner.failCreateWith = const ServerException(
          statusCode: 503,
          serverCode: 'voice_unavailable',
          message: 'No voice capacity',
          retryable: true,
          retryAfter: Duration(milliseconds: 400),
        );
        final v = await voice();
        await v.start();
        await phase(v, VoiceState.disconnected);
        final error = v.state.value.error! as ServerException;
        expect(error.serverCode, 'voice_unavailable');
        expect(provisioner.ended, isEmpty, reason: 'no id was issued');
        expect(transport.grants, isEmpty);
        provisioner.failCreateWith = null;
        final retryAt = DateTime.now();
        await v.start();
        await phase(v, VoiceState.listening);
        expect(
          DateTime.now().difference(retryAt),
          greaterThanOrEqualTo(const Duration(milliseconds: 300)),
          reason: 'never faster than Retry-After',
        );
        expect(provisioner.created, 1);
      },
    );

    test(
      '402 quota_exceeded at creation: quotaExceeded, nothing created',
      () async {
        provisioner.failCreateWith = const QuotaExceededException(
          quotaKind: 'voice_seconds',
        );
        final v = await voice();
        await v.start();
        await phase(v, VoiceState.quotaExceeded);
        expect(
          (v.state.value.error! as QuotaExceededException).quotaKind,
          'voice_seconds',
        );
        expect(provisioner.ended, isEmpty);
      },
    );

    test('403 capability_not_granted from the server is surfaced', () async {
      provisioner.failCreateWith = const CapabilityNotGrantedException(
        'liveVoice',
      );
      final v = await voice();
      await v.start();
      await phase(v, VoiceState.disconnected);
      expect(v.state.value.error, isA<CapabilityNotGrantedException>());
    });

    test('room join failure after create: DELETE is still sent', () async {
      transport = MockRealtimeVoiceTransport(
        failConnectWith: const NetworkException(
          NexaErrorCode.networkUnreachable,
          'no route',
        ),
      );
      final v = await voice();
      await v.start();
      await phase(v, VoiceState.disconnected);
      expect(provisioner.ended, ['vs_mock_1']);
    });

    test('startMuted joins with the mic off', () async {
      final v = await voice(options: const NexaVoiceOptions(startMuted: true));
      await v.start();
      await phase(v, VoiceState.muted);
      expect(transport.isMicrophoneEnabled, isFalse);
    });
  });

  group('conversation', () {
    test('a scripted turn drives states and transcript', () async {
      final v = await voice();
      await v.start();
      await phase(v, VoiceState.listening);
      final phases = <VoiceState>[];
      final sub = v.events.listen((e) {
        if (e is NexaVoicePhaseChanged) phases.add(e.to);
      });
      await transport.scriptedTurn(
        userText: 'شكد الساعة',
        assistantText: 'Sure.',
      );
      await phase(v, VoiceState.listening);
      await sub.cancel();
      expect(phases, [
        VoiceState.userSpeaking,
        VoiceState.transcribing,
        VoiceState.thinking,
        VoiceState.aiSpeaking,
        VoiceState.listening,
      ]);
      final t = v.state.value.transcript;
      expect(t.map((e) => e.text), ['شكد الساعة', 'Sure.']);
      expect(t.first.isFinal, isTrue);
    });

    test(
      'barge-in: local only, nothing sent to the server; agent confirms',
      () async {
        final v = await voice();
        await v.start();
        await phase(v, VoiceState.listening);
        transport.emit(const RealtimeAssistantSpeakingStarted());
        await phase(v, VoiceState.aiSpeaking);
        transport.emit(const RealtimeUserSpeechStarted());
        await phase(v, VoiceState.bargeIn);
        expect(transport.interrupts, 1, reason: 'local stop only');
        transport.emit(const RealtimeInterrupted());
        await phase(v, VoiceState.userSpeaking);
        // the interrupted turn's turn_ended is filtered by the pipeline; even
        // if one arrived, userSpeaking ignores it.
        transport.emit(const RealtimeAssistantSpeakingEnded());
        await Future<void>.delayed(const Duration(milliseconds: 10));
        expect(v.state.value.phase, VoiceState.userSpeaking);
      },
    );

    test(
      'session_state snapshots reconcile without impossible states',
      () async {
        final v = await voice();
        await v.start();
        await phase(v, VoiceState.listening);
        transport.emit(const RealtimeSessionSnapshot(state: 'ai_speaking'));
        await phase(v, VoiceState.aiSpeaking);
        transport.emit(const RealtimeSessionSnapshot(state: 'listening'));
        await phase(v, VoiceState.listening);
        transport.emit(const RealtimeSessionSnapshot(state: 'barge_in'));
        await Future<void>.delayed(const Duration(milliseconds: 10));
        expect(v.state.value.phase, VoiceState.listening, reason: 'ignored');
      },
    );

    test('model busy / available, rejected events counted but inert', () async {
      final v = await voice();
      await v.start();
      await phase(v, VoiceState.listening);
      transport.emit(const RealtimeModelBusy());
      await phase(v, VoiceState.modelBusy);
      transport.emit(const RealtimeModelAvailable());
      await phase(v, VoiceState.listening);
      transport.emit(const RealtimeEventRejected('badSignature'));
      await waitFor(() => v.state.value.rejectedEvents == 1);
      expect(v.state.value.phase, VoiceState.listening);
    });

    test('non-retryable agent error fails the call (with DELETE)', () async {
      final v = await voice();
      await v.start();
      await phase(v, VoiceState.listening);
      transport.emit(
        const RealtimeAgentError(code: 'stt_failed', retryable: true),
      );
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(
        v.state.value.phase,
        VoiceState.listening,
        reason: 'retryable: logged only',
      );
      transport.emit(
        const RealtimeAgentError(code: 'pipeline_dead', retryable: false),
      );
      await phase(v, VoiceState.disconnected);
      expect(provisioner.ended, ['vs_mock_1']);
    });
  });

  group('mute and network', () {
    test('mute/unmute toggle the mic track only', () async {
      final v = await voice();
      await v.start();
      await phase(v, VoiceState.listening);
      await v.toggleMute();
      await phase(v, VoiceState.muted);
      expect(transport.isMicrophoneEnabled, isFalse);
      await v.toggleMute();
      await phase(v, VoiceState.listening);
      expect(transport.microphoneCalls, [true, false, true]);
    });

    test(
      'engine-level reconnect: reconnecting → listening, mic back on',
      () async {
        final v = await voice();
        await v.start();
        await phase(v, VoiceState.listening);
        await transport.simulateDrop();
        await phase(v, VoiceState.listening);
        expect(transport.microphoneCalls.last, isTrue);
        expect(provisioner.refreshed, 0, reason: 'same connection, no rejoin');
      },
    );

    test(
      'room lost while active: GET → refresh token → rejoin same identity',
      () async {
        final v = await voice();
        await v.start();
        await phase(v, VoiceState.listening);
        transport.simulateRoomDeleted();
        await waitFor(() => transport.grants.length == 2, reason: 'rejoined');
        await phase(v, VoiceState.listening);
        expect(provisioner.statusCalls, 1);
        expect(provisioner.refreshed, 1);
        expect(
          transport.grants.last.participantIdentity,
          transport.grants.first.participantIdentity,
        );
        expect(
          transport.grants.last.participantToken,
          isNot(transport.grants.first.participantToken),
        );
        expect(provisioner.ended, isEmpty, reason: 'call continues');
      },
    );

    test('refresh refused (410 / budget) → session treated as over', () async {
      final v = await voice();
      await v.start();
      await phase(v, VoiceState.listening);
      provisioner.failRefreshWith = const VoiceSessionOverException(
        'voice_session_ended',
      );
      var calls = 0;
      provisioner.serverStatus = (id) => calls++ == 0
          ? VoiceSessionStatus(
              voiceSessionId: id,
              status: 'active',
              agentState: 'joined',
            )
          : ended(id, 'revoked');
      transport.simulateRoomDeleted();
      await phase(v, VoiceState.ended);
      expect(v.state.value.endReason, 'server:revoked');
      expect(provisioner.ended, ['vs_mock_1']);
    });

    test(
      'gateway unreachable during recovery: disconnected with network error',
      () async {
        final v = await voice();
        await v.start();
        await phase(v, VoiceState.listening);
        provisioner.failStatusWith = const ContractViolationException('boom');
        transport.simulateRoomDeleted();
        await phase(v, VoiceState.disconnected);
        expect(v.state.value.error, isA<NetworkException>());
      },
    );
  });

  group('server-side termination (no event; disconnect + GET)', () {
    Future<NexaVoiceController> inCall() async {
      final v = await voice();
      await v.start();
      await phase(v, VoiceState.listening);
      return v;
    }

    test(
      'agent_lost → disconnected with "voice unavailable", DELETE sent',
      () async {
        final v = await inCall();
        provisioner.serverStatus = (id) =>
            ended(id, 'agent_lost', agent: 'unavailable');
        transport.simulateRoomDeleted();
        await phase(v, VoiceState.disconnected);
        final error = v.state.value.error! as ServerException;
        expect(error.serverCode, 'agent_lost');
        expect(error.retryable, isTrue);
        expect(v.state.value.endReason, 'agent_lost');
        expect(provisioner.ended, ['vs_mock_1'], reason: 'idempotent DELETE');
        expect(provisioner.refreshed, 0, reason: 'ended: never refresh');
      },
    );

    test(
      'revoked / user_ended elsewhere / room_closed → ended with reason',
      () async {
        for (final reason in [
          'revoked',
          'user_ended',
          'room_closed',
          'join_timeout',
          'something_new',
        ]) {
          transport = MockRealtimeVoiceTransport();
          provisioner = MockVoiceProvisioner()
            ..serverStatus = (id) => ended(id, reason);
          final v = await inCall();
          transport.simulateRoomDeleted();
          await phase(v, VoiceState.ended);
          expect(v.state.value.endReason, 'server:$reason');
          expect(provisioner.refreshed, 0);
          await client.dispose();
        }
        client = await Nexa.initialize(
          config: testConfig(),
          auth: MockAuthProvider(),
        );
      },
    );

    test('quota_exceeded discovered via GET → quotaExceeded', () async {
      final v = await inCall();
      provisioner.serverStatus = (id) => ended(id, 'quota_exceeded');
      transport.simulateRoomDeleted();
      await phase(v, VoiceState.quotaExceeded);
      expect(v.state.value.error, isA<QuotaExceededException>());
    });

    test(
      'agent never answers resume → GET still active → DELETE + unavailable',
      () async {
        final v = await inCall();
        transport.emit(const RealtimeAgentUnresponsive());
        await phase(v, VoiceState.disconnected);
        expect(
          (v.state.value.error! as ServerException).serverCode,
          'agent_lost',
        );
        expect(provisioner.ended, ['vs_mock_1']);
      },
    );
  });

  group('quota, expiry, end, cleanup', () {
    test(
      'quota in call: quota_exceeded + session_ended → DELETE (REST still active)',
      () async {
        final v = await voice();
        await v.start();
        await phase(v, VoiceState.listening);
        transport
          ..emit(const RealtimeQuotaExceeded('voice_seconds'))
          ..emit(const RealtimeSessionEnding('quota_exceeded'));
        await phase(v, VoiceState.quotaExceeded);
        await waitFor(() => provisioner.ended.isNotEmpty);
        expect(provisioner.ended, ['vs_mock_1']);
        expect(transport.isConnected, isFalse);
      },
    );

    test('session_ended with another reason → ended + DELETE', () async {
      final v = await voice();
      await v.start();
      await phase(v, VoiceState.listening);
      transport.emit(const RealtimeSessionEnding('idle_timeout'));
      await phase(v, VoiceState.ended);
      expect(v.state.value.endReason, 'server:idle_timeout');
      await waitFor(() => provisioner.ended.isNotEmpty);
    });

    test('the 60 s join token is NOT the session lifetime', () async {
      provisioner = MockVoiceProvisioner(
        tokenLifetime: const Duration(milliseconds: 50),
      );
      final v = await voice();
      await v.start();
      await phase(v, VoiceState.listening);
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(v.state.value.phase, VoiceState.listening);
    });

    test(
      'client backstop after max_seconds: GET decides, else expired',
      () async {
        provisioner = MockVoiceProvisioner(maxSeconds: 0);
        final v = await voice();
        await v.start();
        await phase(v, VoiceState.listening);
        await waitFor(
          () => v.state.value.phase == VoiceState.ended,
          timeout: const Duration(seconds: 20),
        );
        expect(v.state.value.endReason, 'expired');
        expect(v.state.value.error, isA<SessionExpiredException>());
        expect(provisioner.ended, ['vs_mock_1']);
      },
      timeout: const Timeout(Duration(seconds: 30)),
    );

    test('user end: DELETE before leaving the room; restart works', () async {
      final v = await voice();
      await v.start();
      await phase(v, VoiceState.listening);
      await v.end();
      await phase(v, VoiceState.ended);
      await waitFor(() => provisioner.ended.isNotEmpty);
      expect(provisioner.ended, ['vs_mock_1']);
      expect(transport.isConnected, isFalse);
      expect(v.state.value.endReason, 'user');
      await v.start();
      await phase(v, VoiceState.listening);
      expect(provisioner.created, 2);
      expect(v.state.value.transcript, isEmpty);
    });

    test(
      'end while creating: the late grant is released with DELETE',
      () async {
        transport = MockRealtimeVoiceTransport(
          connectDelay: const Duration(milliseconds: 50),
        );
        final v = await voice();
        await v.start();
        await waitFor(() => v.state.value.phase == VoiceState.connecting);
        await v.end();
        await phase(v, VoiceState.ended);
        await waitFor(() => provisioner.ended.isNotEmpty);
      },
    );

    test('dispose ends an active call with DELETE', () async {
      final v = await voice();
      await v.start();
      await phase(v, VoiceState.listening);
      await client.dispose();
      expect(provisioner.ended, ['vs_mock_1']);
      expect(transport.isConnected, isFalse);
      expect(() => v.start(), throwsA(isA<NotInitializedException>()));
      client = await Nexa.initialize(
        config: testConfig(),
        auth: MockAuthProvider(),
      );
    });
  });
}
