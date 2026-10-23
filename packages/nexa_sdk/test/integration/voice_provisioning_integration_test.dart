// Voice provisioning over real HTTP against the reference gateway, plus
// signing compatibility between the gateway's signer and the SDK verifier.
// Joining the LiveKit room itself needs a platform WebRTC engine and is
// covered by apps/nexa_example/integration_test on a simulator.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nexa_core/testing.dart';
import 'package:nexa_reference_gateway/nexa_reference_gateway.dart';
import 'package:nexa_sdk/nexa_sdk.dart';

import '../helpers.dart';
import 'reference_auth_provider.dart';

final liveKitUrl = Uri.parse('ws://127.0.0.1:7880');

Future<bool> liveKitUp() async {
  final c = HttpClient()..connectionTimeout = const Duration(seconds: 1);
  try {
    final res = await (await c.getUrl(
      Uri.parse('http://127.0.0.1:7880/'),
    )).close();
    await res.drain<void>();
    return true;
  } on Object {
    return false;
  } finally {
    c.close();
  }
}

void main() {
  late ReferenceGateway gw;
  late ReferenceAuthProvider auth;
  late MockRealtimeVoiceTransport transport;
  NexaClient? client;
  late bool lk;

  setUpAll(() async {
    HttpOverrides.global = null;
    lk = await liveKitUp();
  });

  setUp(() async {
    gw = await ReferenceGateway.start(
      port: 0,
      options: const GatewayOptions(
        deltaDelay: Duration.zero,
        thinkDelay: Duration.zero,
      ),
      voice: VoiceOptions(
        liveKitUrl: lk ? liveKitUrl : null,
        voiceQuotaPerApplication: 1,
        scriptStep: const Duration(milliseconds: 50),
      ),
    );
    auth = ReferenceAuthProvider(gw.uri);
    transport = MockRealtimeVoiceTransport();
  });

  tearDown(() async {
    await client?.dispose();
    client = null;
    await gw.close();
  });

  Future<NexaVoiceController> voice() async {
    client = await Nexa.initialize(
      config: testConfig(gateway: gw.uri).copyWith(
        requestedCapabilities: const {
          NexaCapability.textChat,
          NexaCapability.liveVoice,
        },
      ),
      auth: auth,
      overrides: NexaOverrides(
        voiceTransport: transport, // real provisioning, mock room
        permissionHandler: _Grant(),
      ),
    );
    return client!.voice;
  }

  group('voice provisioning via the reference gateway', () {
    test(
      'real grant: room-scoped token, key, agent identity → listening',
      () async {
        if (!lk) markTestSkipped('livekit-server not running');
        if (!lk) return;
        final v = await voice();
        await v.start();
        await waitFor(() => v.state.value.phase == VoiceState.listening);
        final grant = transport.grants.single;
        expect(grant.liveKitUrl, liveKitUrl);
        expect(grant.agentIdentity, 'nexa-agent');
        expect(grant.eventVerificationKey, isNotNull);
        expect(grant.participantToken.split('.').length, 3);
        expect(v.state.value.eventsVerified, isTrue);
        final gwSession = gw.voice.sessions.values.single;
        expect(gwSession.participantIdentity, grant.participantIdentity);
        // End: the gateway releases the voice session.
        await v.end();
        await waitFor(() => gwSession.ended);
        expect(gwSession.endReason, 'user_ended');
      },
    );

    test('voice quota 402 ends in quotaExceeded', () async {
      if (!lk) markTestSkipped('livekit-server not running');
      if (!lk) return;
      final v = await voice();
      await v.start();
      await waitFor(() => v.state.value.phase == VoiceState.listening);
      await v.end();
      await waitFor(() => v.state.value.phase == VoiceState.ended);
      await v.start(); // quota is 1 per application
      await waitFor(() => v.state.value.phase == VoiceState.quotaExceeded);
      expect(v.state.value.error, isA<QuotaExceededException>());
    });

    test(
      'without LiveKit the gateway refuses voice (capability not granted)',
      () async {
        if (lk) {
          markTestSkipped('LiveKit is running; covered by the other cases');
        }
        if (lk) return;
        final v = await voice();
        await v.start();
        await waitFor(() => v.state.value.phase == VoiceState.disconnected);
        expect(v.state.value.error, isA<CapabilityNotGrantedException>());
      },
    );

    test('expired chat credential is renewed before provisioning', () async {
      if (!lk) markTestSkipped('livekit-server not running');
      if (!lk) return;
      final v = await voice();
      await client!.startSession();
      gw.store.tokens.clear(); // 401 on the next call → forced refresh
      await v.start();
      await waitFor(() => v.state.value.phase == VoiceState.listening);
      expect(auth.issued, 2);
    });
  });

  group('signing compatibility (gateway signer ↔ SDK verifier)', () {
    test('events signed by the reference gateway verify in the SDK', () {
      final verifier = VoiceEventVerifier(voiceSessionId: 'vs_x', key: 'k1');
      for (var seq = 1; seq <= 3; seq++) {
        final e = VoiceService.signEvent(
          voiceSessionId: 'vs_x',
          key: 'k1',
          sequence: seq,
          type: 'assistant_transcript',
          payload: {'text': 'مرحبا', 'is_final': seq == 3, 'n': seq},
        );
        final verdict = verifier.verify(e);
        expect(verdict, isA<VoiceEventAccepted>(), reason: 'seq $seq');
        expect((verdict as VoiceEventAccepted).verified, isTrue);
      }
      // Replay of seq 3 and a forged key are rejected.
      final replay = VoiceService.signEvent(
        voiceSessionId: 'vs_x',
        key: 'k1',
        sequence: 3,
        type: 'assistant_transcript',
        payload: const {},
      );
      expect(verifier.verify(replay), isA<VoiceEventRejected>());
      final forged = VoiceService.signEvent(
        voiceSessionId: 'vs_x',
        key: 'wrong',
        sequence: 4,
        type: 'quota_exceeded',
        payload: const {},
      );
      expect(
        (verifier.verify(forged) as VoiceEventRejected).reason,
        VoiceEventRejection.badSignature,
      );
    });
  });
}

final class _Grant implements NexaPermissionHandler {
  @override
  Future<bool> request(NexaPermission permission) async => true;
}
