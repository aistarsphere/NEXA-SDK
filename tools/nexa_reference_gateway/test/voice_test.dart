// Voice provisioning contract tests. They need a local `livekit-server --dev`
// on ws://127.0.0.1:7880 (brew install livekit); when it is not reachable the
// LiveKit-dependent cases are skipped and reported as such.
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:nexa_reference_gateway/nexa_reference_gateway.dart';
import 'package:test/test.dart';

import 'helpers.dart';

final liveKitUrl = Uri.parse('ws://127.0.0.1:7880');

Future<bool> liveKitUp() async {
  final c = HttpClient()..connectionTimeout = const Duration(seconds: 1);
  try {
    final req = await c.getUrl(Uri.parse('http://127.0.0.1:7880/'));
    final res = await req.close();
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
  expect(parts.length, 3, reason: 'JWT has three parts');
  String pad(String s) => s + '=' * ((4 - s.length % 4) % 4);
  return jsonDecode(utf8.decode(base64Url.decode(pad(parts[1]))))
      as Map<String, Object?>;
}

void main() {
  late bool lk;
  setUpAll(() async => lk = await liveKitUp());

  group('voice provisioning (no LiveKit configured)', () {
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

    test('liveVoice is not granted and voice answers 403', () async {
      await c.mint();
      final (status, body) = await c.createSession(
        caps: const ['textChat', 'liveVoice'],
      );
      expect(status, 201);
      expect(body['granted_capabilities'], ['textChat']);
      final sid = body['session_id']! as String;
      final (vs, vb) = await c.call('POST', '/v1/sdk/sessions/$sid/voice');
      expect(vs, 403);
      expect((vb['error']! as Map)['code'], 'capability_not_granted');
    });
  });

  group('voice provisioning (LiveKit dev server)', () {
    late ReferenceGateway gw;
    late GwClient c;
    setUp(() async {
      gw = await ReferenceGateway.start(
        port: 0,
        options: fastOptions,
        voice: VoiceOptions(
          liveKitUrl: liveKitUrl,
          voiceQuotaPerApplication: 2,
          scriptStep: const Duration(milliseconds: 50),
        ),
      );
      c = GwClient(gw);
    });
    tearDown(() async {
      c.close();
      await gw.close();
    });

    Future<String> voiceSession() async {
      await c.mint();
      final (status, body) = await c.createSession(
        caps: const ['textChat', 'liveVoice'],
      );
      expect(status, 201);
      expect(body['granted_capabilities'], contains('liveVoice'));
      return body['session_id']! as String;
    }

    test(
      'issues a room-scoped participant grant with a verification key',
      () async {
        if (!lk) markTestSkipped('livekit-server not running');
        if (!lk) return;
        final sid = await voiceSession();
        final (status, grant) = await c.call(
          'POST',
          '/v1/sdk/sessions/$sid/voice',
        );
        expect(status, 201, reason: '$grant');
        expect(grant['livekit_url'], liveKitUrl.toString());
        expect(grant['voice_session_id'], startsWith('vs_'));
        expect(grant['agent_identity'], 'nexa-agent');
        expect(grant['event_signature_alg'], 'HMAC-SHA256');
        expect(
          (grant['event_verification_key']! as String).length,
          greaterThan(16),
        );
        expect(grant['max_duration_seconds'], isA<int>());
        final payload = jwtPayload(grant['participant_token']! as String);
        expect(payload['iss'], 'devkey');
        expect(payload['sub'], grant['participant_identity']);
        final video = payload['video']! as Map;
        expect(video['room'], grant['room_name']);
        expect(video['roomJoin'], isTrue);
        expect(video['canPublish'], isTrue);
        expect(video['canSubscribe'], isTrue);
        expect(
          video['roomAdmin'],
          isNull,
          reason: 'no admin rights for devices',
        );
        expect(video['roomCreate'], isNull);
        // The grant never carries the LiveKit API secret.
        expect(jsonEncode(grant), isNot(contains('secret')));
      },
    );

    test(
      'second provision for the same chat session is 409; DELETE ends it',
      () async {
        if (!lk) markTestSkipped('livekit-server not running');
        if (!lk) return;
        final sid = await voiceSession();
        final (s1, _) = await c.call('POST', '/v1/sdk/sessions/$sid/voice');
        expect(s1, 201);
        final (s2, b2) = await c.call('POST', '/v1/sdk/sessions/$sid/voice');
        expect(s2, 409);
        expect((b2['error']! as Map)['code'], 'voice_session_active');
        final (s3, _) = await c.call('DELETE', '/v1/sdk/sessions/$sid/voice');
        expect(s3, 204);
        final (s4, _) = await c.call('DELETE', '/v1/sdk/sessions/$sid/voice');
        expect(s4, 204, reason: 'idempotent');
        final (s5, _) = await c.call('POST', '/v1/sdk/sessions/$sid/voice');
        expect(s5, 201, reason: 'a new voice session can start');
      },
    );

    test('voice quota is enforced per application (402)', () async {
      if (!lk) markTestSkipped('livekit-server not running');
      if (!lk) return;
      final sid = await voiceSession();
      for (var i = 0; i < 2; i++) {
        final (s, _) = await c.call('POST', '/v1/sdk/sessions/$sid/voice');
        expect(s, 201);
        await c.call('DELETE', '/v1/sdk/sessions/$sid/voice');
      }
      final (s, b) = await c.call('POST', '/v1/sdk/sessions/$sid/voice');
      expect(s, 402);
      expect((b['error']! as Map)['quota_kind'], 'voice_minutes');
      await c.call('POST', '/v1/dev/applications/app_test/reset', auth: false);
      final (again, _) = await c.call('POST', '/v1/sdk/sessions/$sid/voice');
      expect(again, 201);
    });

    test(
      'intents need an active voice session; ending the chat ends voice',
      () async {
        if (!lk) markTestSkipped('livekit-server not running');
        if (!lk) return;
        final sid = await voiceSession();
        final (none, _) = await c.call(
          'POST',
          '/v1/sdk/sessions/$sid/voice/intents',
          body: {'type': 'interrupt'},
        );
        expect(none, 404);
        await c.call('POST', '/v1/sdk/sessions/$sid/voice');
        final (ok, _) = await c.call(
          'POST',
          '/v1/sdk/sessions/$sid/voice/intents',
          body: {'type': 'interrupt'},
        );
        expect(ok, 202);
        await c.call('DELETE', '/v1/sdk/sessions/$sid');
        expect(gw.voice.forChatSession(sid), isNull);
      },
    );

    test('another application cannot touch the voice session', () async {
      if (!lk) markTestSkipped('livekit-server not running');
      if (!lk) return;
      final sid = await voiceSession();
      final other = GwClient(gw, appId: 'app_other');
      await other.mint();
      final (s, b) = await other.call('POST', '/v1/sdk/sessions/$sid/voice');
      expect(s, 403);
      expect((b['error']! as Map)['code'], 'forbidden');
      other.close();
    });
  });

  group('event signing', () {
    test('signEvent produces the documented canonical HMAC', () {
      final e = VoiceService.signEvent(
        voiceSessionId: 'vs_1',
        key: 'k',
        sequence: 3,
        type: 'transcript',
        payload: {'text': 'hi', 'is_final': true},
        issuedAtMs: 1700000000000,
      );
      const canonical =
          '1|vs_1|3|transcript|1700000000000|{"is_final":true,"text":"hi"}';
      final expected = base64Url
          .encode(
            Hmac(
              sha256,
              utf8.encode('k'),
            ).convert(utf8.encode(canonical)).bytes,
          )
          .replaceAll('=', '');
      expect(e['sig'], expected);
      expect(e['v'], 1);
      expect(e['seq'], 3);
    });

    test('unsigned mode omits sig', () {
      final e = VoiceService.signEvent(
        voiceSessionId: 'vs',
        key: 'k',
        sequence: 1,
        type: 'x',
        payload: const {},
        sign: false,
      );
      expect(e.containsKey('sig'), isFalse);
    });
  });
}
