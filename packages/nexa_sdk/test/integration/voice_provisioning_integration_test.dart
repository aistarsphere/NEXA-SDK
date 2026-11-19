// Voice REST over real HTTP against the REFERENCE gateway (a dev mirror of
// contract nexa.voice.v1, not the NEXA backend). The LiveKit room is the
// labelled mock transport here; the real room path runs on devices via
// apps/nexa_example/integration_test. Needs `livekit-server --dev`.
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

final class _Grant implements NexaPermissionHandler {
  @override
  Future<bool> request(NexaPermission permission) async => true;
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
        voiceSecondsPerApplication: 120,
        maxSeconds: 60,
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
      config: testConfig(gateway: gw.uri, lang: 'ar'),
      auth: auth,
      overrides: NexaOverrides(
        voiceTransport: transport,
        permissionHandler: _Grant(),
      ),
    );
    return client!.voice;
  }

  Future<void> phase(NexaVoiceController v, VoiceState s) => waitFor(
    () => v.state.value.phase == s,
    reason:
        'phase ${s.name} (now ${v.state.value.phase.name}, error ${v.state.value.error})',
  );

  test(
    'create → v1 grant over HTTP (ws:// accepted in development) → DELETE on end',
    () async {
      if (!lk) return markTestSkipped('livekit-server not running');
      final v = await voice();
      await v.start();
      await phase(v, VoiceState.listening);
      final g = transport.grants.single;
      expect(g.contract, 'nexa.voice.v1');
      expect(g.eventAlgorithm, VoiceEventAlgorithm.ed25519);
      expect(g.eventKey.length, 32);
      expect(g.participantIdentity, 'nexa-user-${g.voiceSessionId}');
      final server = gw.voice.sessions[g.voiceSessionId]!;
      expect(server.languageTag, 'ar');
      await v.end();
      await phase(v, VoiceState.ended);
      await waitFor(() => server.status == 'ended');
      expect(server.endReason, 'user_ended');
    },
  );

  test(
    '503 voice_unavailable → disconnected; retry honours Retry-After (5 s)',
    () async {
      if (!lk) return markTestSkipped('livekit-server not running');
      final v = await voice();
      await client!.startSession(); // forces the first token mint
      await (HttpClient()
          .postUrl(gw.uri.resolve('/v1/dev/voice/fail-next-create'))
          .then((r) => r.close()));
      await v.start();
      await phase(v, VoiceState.disconnected);
      final error = v.state.value.error! as ServerException;
      expect(error.serverCode, 'voice_unavailable');
      expect(error.retryAfter, const Duration(seconds: 5));
      expect(gw.voice.sessions, isEmpty);
      final retryAt = DateTime.now();
      await v.start();
      await waitFor(
        () => v.state.value.phase == VoiceState.listening,
        timeout: const Duration(seconds: 15),
      );
      expect(
        DateTime.now().difference(retryAt).inMilliseconds,
        greaterThan(4500),
      );
    },
    timeout: const Timeout(Duration(seconds: 40)),
  );

  test(
    'server-side agent_lost: disconnect → GET → "voice unavailable"',
    () async {
      if (!lk) return markTestSkipped('livekit-server not running');
      final v = await voice();
      await v.start();
      await phase(v, VoiceState.listening);
      final id = transport.grants.single.voiceSessionId;
      await gw.voice.end(
        gw.voice.sessions[id]!,
        'agent_lost',
        agentState: 'unavailable',
      );
      transport
          .simulateRoomDeleted(); // what LiveKit does when the room is deleted
      await phase(v, VoiceState.disconnected);
      expect(
        (v.state.value.error! as ServerException).serverCode,
        'agent_lost',
      );
      expect(v.state.value.endReason, 'agent_lost');
    },
  );

  test(
    'server-side revoke: disconnect → GET → ended(server:revoked), no refresh',
    () async {
      if (!lk) return markTestSkipped('livekit-server not running');
      final v = await voice();
      await v.start();
      await phase(v, VoiceState.listening);
      final server = gw.voice.sessions[transport.grants.single.voiceSessionId]!;
      await gw.voice.end(server, 'revoked');
      transport.simulateRoomDeleted();
      await phase(v, VoiceState.ended);
      expect(v.state.value.endReason, 'server:revoked');
      expect(server.refreshes, 0);
    },
  );

  test(
    'network drop while active: GET → POST token → rejoin same identity',
    () async {
      if (!lk) return markTestSkipped('livekit-server not running');
      final v = await voice();
      await v.start();
      await phase(v, VoiceState.listening);
      final server = gw.voice.sessions[transport.grants.single.voiceSessionId]!;
      server.status = 'active'; // the mock room never really joined LiveKit
      transport.simulateRoomDeleted();
      await waitFor(() => transport.grants.length == 2);
      await phase(v, VoiceState.listening);
      expect(server.refreshes, 1);
      expect(
        transport.grants.last.participantIdentity,
        transport.grants.first.participantIdentity,
      );
    },
  );

  test('quota exhausted at creation (402)', () async {
    if (!lk) return markTestSkipped('livekit-server not running');
    gw.voice.setQuota('app_test', 0);
    final v = await voice();
    await v.start();
    await phase(v, VoiceState.quotaExceeded);
    expect(
      (v.state.value.error! as QuotaExceededException).quotaKind,
      'voice_seconds',
    );
  });

  test(
    'expired SDK token is renewed (401 → forced refresh) before create',
    () async {
      if (!lk) return markTestSkipped('livekit-server not running');
      final v = await voice();
      await client!.startSession();
      gw.store.tokens.clear();
      await v.start();
      await phase(v, VoiceState.listening);
      expect(auth.issued, 2);
    },
  );
}
