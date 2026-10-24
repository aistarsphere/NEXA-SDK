// Reference-gateway voice API (nexa.voice.v1 mirror) over dart:io sockets.
// LiveKit-dependent cases need `livekit-server --dev` on 127.0.0.1:7880
// (brew install livekit) and are skipped otherwise.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:nexa_reference_gateway/nexa_reference_gateway.dart';
import 'package:pinenacl/ed25519.dart' as nacl;
import 'package:test/test.dart';

import 'helpers.dart';

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

Map<String, Object?> jwtPayload(String token) {
  final parts = token.split('.');
  String pad(String s) => s + '=' * ((4 - s.length % 4) % 4);
  return jsonDecode(utf8.decode(base64Url.decode(pad(parts[1]))))
      as Map<String, Object?>;
}

void main() {
  late bool lk;
  setUpAll(() async => lk = await liveKitUp());

  Future<String> voiceToken(GwClient c) async {
    final (status, body) = await c.call(
      'POST',
      '/v1/dev/session-tokens',
      body: {
        'application_id': c.appId,
        'scopes': ['chat:session', 'voice:session'],
      },
      auth: false,
    );
    expect(status, 201);
    return c.token = body['token']! as String;
  }

  group('without LiveKit', () {
    late ReferenceGateway gw;
    late GwClient c;
    setUp(() async {
      gw = await ReferenceGateway.start(port: 0, options: fastOptions);
      c = GwClient(gw);
    });
    tearDown(() async {
      c.close();
      await gw.close();
    });

    test(
      'default-scope token is forbidden (voice:session is opt-in)',
      () async {
        await c.mint();
        final (s, b) = await c.call(
          'POST',
          '/v1/sdk/voice/sessions',
          body: {'language_tag': 'en'},
        );
        expect(s, 403);
        expect((b['error']! as Map)['code'], 'forbidden');
      },
    );

    test(
      'voice-scoped token, voice not enabled → 403 capability_not_granted(liveVoice)',
      () async {
        await voiceToken(c);
        final (s, b) = await c.call(
          'POST',
          '/v1/sdk/voice/sessions',
          body: {'language_tag': 'en'},
        );
        expect(s, 403);
        expect((b['error']! as Map)['code'], 'capability_not_granted');
        expect((b['error']! as Map)['quota_kind'], 'liveVoice');
      },
    );

    test('invalid language → 422', () async {
      await voiceToken(c);
      final (s, _) = await c.call(
        'POST',
        '/v1/sdk/voice/sessions',
        body: {'language_tag': 'fr'},
      );
      expect(s, 422);
    });
  });

  group('with LiveKit dev server', () {
    late ReferenceGateway gw;
    late GwClient c;
    setUp(() async {
      gw = await ReferenceGateway.start(
        port: 0,
        options: fastOptions,
        voice: VoiceOptions(
          liveKitUrl: liveKitUrl,
          voiceSecondsPerApplication: 100,
          maxSeconds: 60,
          maxRefreshes: 2,
          scriptStep: const Duration(milliseconds: 50),
        ),
      );
      c = GwClient(gw);
    });
    tearDown(() async {
      c.close();
      await gw.close();
    });

    Future<Map<String, Object?>> create() async {
      final (s, b) = await c.call(
        'POST',
        '/v1/sdk/voice/sessions',
        body: {'language_tag': 'en'},
      );
      expect(s, 201, reason: '$b');
      return b;
    }

    test(
      '201 has the v1 shape; join token is one-room, mic+data, no admin',
      () async {
        if (!lk) return markTestSkipped('livekit-server not running');
        await voiceToken(c);
        final g = await create();
        final id = g['voice_session_id']! as String;
        expect(g['contract'], voiceContractV1);
        final livekit = g['livekit']! as Map;
        expect(livekit['room'], 'nexa-$id');
        expect(livekit['identity'], 'nexa-user-$id');
        final events = g['events']! as Map;
        expect(events['alg'], 'ed25519');
        expect((events['public_key']! as String).length, 43);
        expect(events['topic'], 'nexa.voice.events');
        expect((g['limits']! as Map)['max_seconds'], 60);
        expect(
          (g['reconnect']! as Map)['token_refresh_path'],
          '/v1/sdk/voice/sessions/$id/token',
        );
        final video = jwtPayload(livekit['token']! as String)['video']! as Map;
        expect(video['room'], 'nexa-$id');
        expect(video['roomAdmin'], isNull);
        expect(jsonEncode(g), isNot(contains('secret')));
      },
    );

    test(
      '409 for a second live session; GET/refresh/DELETE lifecycle; 410 after end',
      () async {
        if (!lk) return markTestSkipped('livekit-server not running');
        await voiceToken(c);
        final id = (await create())['voice_session_id']! as String;
        final (dup, db) = await c.call(
          'POST',
          '/v1/sdk/voice/sessions',
          body: {'language_tag': 'en'},
        );
        expect(dup, 409);
        expect((db['error']! as Map)['code'], 'voice_session_active');
        final (gs, gb) = await c.call('GET', '/v1/sdk/voice/sessions/$id');
        expect(gs, 200);
        expect(gb['status'], 'provisioning', reason: 'user has not joined');
        expect(gb['agent_state'], 'joined');
        final (rs, rb) = await c.call(
          'POST',
          '/v1/sdk/voice/sessions/$id/token',
        );
        expect(rs, 200);
        expect(rb.keys, unorderedEquals(['voice_session_id', 'livekit']));
        final (ds, delBody) = await c.call(
          'DELETE',
          '/v1/sdk/voice/sessions/$id',
        );
        expect(ds, 200);
        expect(delBody['status'], 'ended');
        expect(delBody['end_reason'], 'user_ended');
        final (again, againBody) = await c.call(
          'DELETE',
          '/v1/sdk/voice/sessions/$id',
        );
        expect(again, 200);
        expect(
          againBody['end_reason'],
          'user_ended',
          reason: 'idempotent, first reason kept',
        );
        final (r410, b410) = await c.call(
          'POST',
          '/v1/sdk/voice/sessions/$id/token',
        );
        expect(r410, 410);
        expect((b410['error']! as Map)['code'], 'voice_session_ended');
      },
    );

    test('refresh budget → 429 rate_limited (retryable false)', () async {
      if (!lk) return markTestSkipped('livekit-server not running');
      await voiceToken(c);
      final id = (await create())['voice_session_id']! as String;
      for (var i = 0; i < 2; i++) {
        expect(
          (await c.call('POST', '/v1/sdk/voice/sessions/$id/token')).$1,
          200,
        );
      }
      final (s, b) = await c.call('POST', '/v1/sdk/voice/sessions/$id/token');
      expect(s, 429);
      expect((b['error']! as Map)['retryable'], isFalse);
    });

    test(
      'foreign session id answers exactly like an unknown one (404)',
      () async {
        if (!lk) return markTestSkipped('livekit-server not running');
        await voiceToken(c);
        final id = (await create())['voice_session_id']! as String;
        final other = GwClient(gw);
        await voiceToken(other);
        final (s1, b1) = await other.call('GET', '/v1/sdk/voice/sessions/$id');
        final (s2, b2) = await other.call(
          'GET',
          '/v1/sdk/voice/sessions/vs_nope',
        );
        expect(s1, 404);
        expect(b1, b2);
        other.close();
      },
    );

    test(
      '503 voice_unavailable carries Retry-After; 402 when quota is gone',
      () async {
        if (!lk) return markTestSkipped('livekit-server not running');
        await voiceToken(c);
        await c.call('POST', '/v1/dev/voice/fail-next-create', auth: false);
        final (s, b) = await c.call(
          'POST',
          '/v1/sdk/voice/sessions',
          body: {'language_tag': 'en'},
        );
        expect(s, 503);
        expect((b['error']! as Map)['retry_after_seconds'], 5);
        expect(gw.voice.sessions, isEmpty, reason: 'nothing issued');
        gw.voice.setQuota('app_test', 0);
        final (q, qb) = await c.call(
          'POST',
          '/v1/sdk/voice/sessions',
          body: {'language_tag': 'en'},
        );
        expect(q, 402);
        expect((qb['error']! as Map)['quota_kind'], 'voice_seconds');
      },
    );

    test('dev end agent_lost → GET ended/unavailable/agent_lost', () async {
      if (!lk) return markTestSkipped('livekit-server not running');
      await voiceToken(c);
      final id = (await create())['voice_session_id']! as String;
      await c.call(
        'POST',
        '/v1/dev/voice/sessions/$id/end',
        body: {'reason': 'agent_lost'},
        auth: false,
      );
      final (_, g) = await c.call('GET', '/v1/sdk/voice/sessions/$id');
      expect(g['status'], 'ended');
      expect(g['agent_state'], 'unavailable');
      expect(g['end_reason'], 'agent_lost');
    });
  });

  test('seal() produces envelopes the published spec verifies', () {
    final key = nacl.SigningKey.fromSeed(
      base64Url.decode(
        base64Url.normalize('AAECAwQFBgcICQoLDA0ODxAREhMUFRYXGBkaGxwdHh8'),
      ),
    );
    final env =
        jsonDecode(
              VoiceService.seal(key, {
                'v': voiceContractV1,
                'type': 'agent_ready',
              }),
            )
            as Map<String, Object?>;
    expect(env['alg'], 'ed25519');
    final message = [
      ...utf8.encode('$voiceContractV1\u0000'),
      ...utf8.encode(env['e']! as String),
    ];
    final sig = env['sig']! as String;
    final bytes = [
      for (var i = 0; i < sig.length; i += 2)
        int.parse(sig.substring(i, i + 2), radix: 16),
    ];
    expect(
      key.verifyKey.verify(
        signature: nacl.Signature(Uint8List.fromList(bytes)),
        message: Uint8List.fromList(message),
      ),
      isTrue,
    );
    expect(
      base64Url.encode(key.verifyKey.asTypedList).replaceAll('=', ''),
      'A6EHv_POEL4dcN0Y50vAmWfk1jCbpQ1fHdyGZBJVMbg',
      reason: 'same test seed as the backend vectors',
    );
  });
}
