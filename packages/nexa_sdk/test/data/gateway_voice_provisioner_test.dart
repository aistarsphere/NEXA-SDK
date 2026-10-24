// Consumer contract tests: the SDK's real GatewayVoiceProvisioner + error
// mapper against the backend's sanitized fixtures (handoff 1.0.0). Each
// fixture is replayed with its HTTP status and headers through a fake Dio
// adapter. FIXTURE-BASED: no live backend is involved.
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexa_core/nexa_core.dart';
import 'package:nexa_sdk/src/data/gateway/gateway_voice_provisioner.dart';

const handoff = '../../docs/contracts/voice-v1/handoff-1.0.0-4cd5247/fixtures';

/// A real 43-char base64url Ed25519 public key (the published TEST key).
const testPublicKey = 'A6EHv_POEL4dcN0Y50vAmWfk1jCbpQ1fHdyGZBJVMbg';

Map<String, Object?> fixture(String path) =>
    jsonDecode(File('$handoff/$path').readAsStringSync())
        as Map<String, Object?>;

/// Replaces the documented placeholders with concrete, valid values.
Object? concretize(Object? v) {
  if (v is Map) {
    return {for (final e in v.entries) e.key as String: concretize(e.value)};
  }
  if (v is List) return v.map(concretize).toList();
  if (v == '<number>') return 12;
  if (v is String) {
    return v
        .replaceAll('vs_<id>', 'vs_FIXTURE01')
        .replaceAll('wss://<livekit-host>', 'wss://livekit.example')
        .replaceAll('<livekit-join-jwt>', 'header.payload.signature')
        .replaceAll('<iso8601-utc>', '2030-01-01T00:00:00Z')
        .replaceAll('<ed25519-public-key:base64url,43 chars>', testPublicKey);
  }
  return v;
}

final class FixtureAdapter implements HttpClientAdapter {
  FixtureAdapter(this.respond);
  final (int, Object?, Map<String, String>) Function(RequestOptions) respond;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final (status, body, headers) = respond(options);
    return ResponseBody.fromString(
      body == null ? '' : jsonEncode(body),
      status,
      headers: {
        'content-type': ['application/json'],
        for (final h in headers.entries) h.key.toLowerCase(): [h.value],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// Serves a fixture file `{status, headers?, body}`.
FixtureAdapter serve(String path, {Object? Function(Object?)? edit}) {
  final f = concretize(fixture(path))! as Map<String, Object?>;
  final headers = (f['headers'] as Map?)?.cast<String, String>() ?? const {};
  final body = edit == null ? f['body'] : edit(f['body']);
  return FixtureAdapter((_) => (f['status']! as int, body, headers));
}

GatewayVoiceProvisioner make(
  FixtureAdapter adapter, {
  bool legacy = false,
  bool insecure = false,
}) {
  final dio = Dio(BaseOptions(baseUrl: 'https://gw.example'))
    ..httpClientAdapter = adapter;
  return GatewayVoiceProvisioner(
    dio: dio,
    logger: const NoopNexaLogger(),
    allowLegacyHmac: legacy,
    allowInsecureWebSocket: insecure,
  );
}

VoiceGrant sampleGrant() => GatewayVoiceProvisioner.parseGrant(
  concretize(fixture('rest/create_session.201.json')['body'])!
      as Map<String, Object?>,
);

void main() {
  group('POST /v1/sdk/voice/sessions (rest/create_session.201.json)', () {
    test('parses every field of the 201 body', () async {
      final adapter = serve('rest/create_session.201.json');
      final g = await make(
        adapter,
      ).create(languageTag: 'ar', chatSessionId: const SessionId('chat_1'));
      final req = adapter.requests.single;
      expect(req.method, 'POST');
      expect(req.path, '/v1/sdk/voice/sessions');
      expect(req.data, {'language_tag': 'ar', 'chat_session_id': 'chat_1'});
      expect(g.voiceSessionId, 'vs_FIXTURE01');
      expect(g.contract, 'nexa.voice.v1');
      expect(g.liveKitUrl, Uri.parse('wss://livekit.example'));
      expect(g.roomName, 'nexa-vs_FIXTURE01');
      expect(g.participantIdentity, 'nexa-user-vs_FIXTURE01');
      expect(g.agentIdentity, 'nexa-agent-vs_FIXTURE01');
      expect(g.participantToken, 'header.payload.signature');
      expect(g.tokenExpiresAt, DateTime.utc(2030));
      expect(g.eventsTopic, 'nexa.voice.events');
      expect(g.resumeRpc, 'nexa.voice.resume');
      expect(g.eventAlgorithm, VoiceEventAlgorithm.ed25519);
      expect(g.eventKey.length, 32);
      expect(g.maxSeconds, 60);
      expect(g.reservedSeconds, 60);
      expect(g.reconnectGraceSeconds, 30);
      expect(g.tokenRefreshPath, '/v1/sdk/voice/sessions/vs_FIXTURE01/token');
      expect(g.maxRefreshes, 30);
      expect(g.joinDeadlineSeconds, 60);
      expect(g.toString(), isNot(contains('header.payload.signature')));
    });

    test('chat_session_id is omitted when there is no chat session', () async {
      final adapter = serve('rest/create_session.201.json');
      await make(adapter).create(languageTag: 'en');
      expect(adapter.requests.single.data, {'language_tag': 'en'});
    });

    Future<void> rejects(
      Object? Function(Map<String, Object?>) edit,
      String path,
    ) => expectLater(
      make(
        serve(
          'rest/create_session.201.json',
          edit: (b) => edit(Map<String, Object?>.from(b! as Map)),
        ),
      ).create(languageTag: 'en'),
      throwsA(
        isA<ContractViolationException>().having((e) => e.path, 'path', path),
      ),
    );

    test(
      'refuses a different contract',
      () => rejects((b) => b..['contract'] = 'nexa.voice.v2', 'contract'),
    );

    test('refuses algorithm other than ed25519 (no negotiation)', () async {
      await rejects(
        (b) => b..['events'] = {...b['events']! as Map, 'alg': 'none'},
        'events.alg',
      );
      await rejects(
        (b) => b..['events'] = {...b['events']! as Map, 'alg': 'hmac-sha256'},
        'events.alg',
      );
    });

    test(
      'refuses a public key that is not 43 base64url chars',
      () => rejects(
        (b) => b..['events'] = {...b['events']! as Map, 'public_key': 'AAAA'},
        'events.public_key',
      ),
    );

    test(
      'refuses non-sealed event format',
      () => rejects(
        (b) => b..['events'] = {...b['events']! as Map, 'format': 'plain'},
        'events.format',
      ),
    );

    test(
      'refuses ws:// outside development',
      () => rejects(
        (b) => b..['livekit'] = {...b['livekit']! as Map, 'url': 'ws://lk'},
        'livekit.url',
      ),
    );

    test(
      'legacy hmac-sha256 accepted only when enabled; uses events.key',
      () async {
        final g = await make(
          serve(
            'rest/create_session.201.json',
            edit: (b) {
              final m = Map<String, Object?>.from(b! as Map);
              final events = Map<String, Object?>.from(m['events']! as Map)
                ..remove('public_key')
                ..['alg'] = 'hmac-sha256'
                ..['key'] = 'c2VjcmV0LWtleS1ieXRlcw';
              return m..['events'] = events;
            },
          ),
          legacy: true,
        ).create(languageTag: 'en');
        expect(g.eventAlgorithm, VoiceEventAlgorithm.hmacSha256);
        expect(utf8.decode(g.eventKey), 'secret-key-bytes');
      },
    );
  });

  group('token refresh / GET / DELETE', () {
    test(
      'refresh (rest/refresh_token.200.json) keeps id, key and limits',
      () async {
        final adapter = serve('rest/refresh_token.200.json');
        final before = sampleGrant();
        final after = await make(adapter).refreshToken(before);
        expect(
          adapter.requests.single.path,
          '/v1/sdk/voice/sessions/vs_FIXTURE01/token',
        );
        expect(adapter.requests.single.method, 'POST');
        expect(after.participantIdentity, before.participantIdentity);
        expect(
          after.eventKey,
          same(before.eventKey),
          reason: 'refresh never re-sends the key',
        );
        expect(after.maxSeconds, before.maxSeconds);
      },
    );

    test(
      'refresh after end (errors/refresh_after_end.410.json) → session over',
      () async {
        await expectLater(
          make(
            serve('errors/refresh_after_end.410.json'),
          ).refreshToken(sampleGrant()),
          throwsA(isA<VoiceSessionOverException>()),
        );
      },
    );

    test(
      'refresh budget used (errors/refresh_limit.429.json) → session over',
      () async {
        await expectLater(
          make(
            serve('errors/refresh_limit.429.json'),
          ).refreshToken(sampleGrant()),
          throwsA(
            isA<VoiceSessionOverException>().having(
              (e) => e.code,
              'code',
              'rate_limited',
            ),
          ),
        );
      },
    );

    test('GET joined / agent_lost / ended_user', () async {
      final joined = await make(
        serve('rest/get_session.joined.200.json'),
      ).status('vs_FIXTURE01');
      expect(joined.status, 'active');
      expect(joined.agentState, 'joined');
      expect(joined.remainingSeconds, 12);
      expect(joined.isEnded, isFalse);

      final lost = await make(
        serve('rest/get_session.agent_lost.200.json'),
      ).status('vs_FIXTURE01');
      expect(lost.isEnded, isTrue);
      expect(lost.endReason, 'agent_lost');
      expect(lost.isAgentUnavailable, isTrue);

      final user = await make(
        serve('rest/get_session.ended_user.200.json'),
      ).status('vs_FIXTURE01');
      expect(user.endReason, 'user_ended');
      expect(user.isAgentUnavailable, isFalse);
      expect(user.usedSeconds, 12);
    });

    test(
      'DELETE (rest/delete_session.200.json) returns the final status; errors never throw',
      () async {
        final adapter = serve('rest/delete_session.200.json');
        final s = await make(adapter).end('vs_FIXTURE01');
        expect(adapter.requests.single.method, 'DELETE');
        expect(s!.endReason, 'user_ended');
        expect(
          await make(serve('errors/foreign_session.404.json')).end('vs_X'),
          isNull,
        );
      },
    );
  });

  group('error catalogue (fixtures/errors/*.json → NexaException)', () {
    final expectations = <String, Matcher>{
      'capability_not_granted.403.json': isA<CapabilityNotGrantedException>()
          .having((e) => e.capability, 'capability', 'liveVoice'),
      'expired_credential.401.json': isA<AuthenticationException>(),
      'invalid_credential.401.json': isA<AuthenticationException>(),
      'missing_credential.401.json': isA<AuthenticationException>(),
      'missing_scope.403.json': isA<AuthenticationException>(),
      'foreign_session.404.json': isA<ServerException>().having(
        (e) => e.serverCode,
        'code',
        'voice_session_not_found',
      ),
      'invalid_language.422.json': isA<ContractViolationException>(),
      'missing_app_id.400.json': isA<ServerException>().having(
        (e) => e.serverCode,
        'code',
        'bad_request',
      ),
      'missing_sdk_version.400.json': isA<ServerException>().having(
        (e) => e.serverCode,
        'code',
        'missing_sdk_version',
      ),
      'quota_exceeded_on_create.402.json': isA<QuotaExceededException>().having(
        (e) => e.quotaKind,
        'quotaKind',
        'voice_seconds',
      ),
      'refresh_after_end.410.json': isA<SessionExpiredException>(),
      'refresh_limit.429.json': isA<RateLimitedException>(),
      'session_already_active.409.json': isA<ServerException>().having(
        (e) => e.serverCode,
        'code',
        'voice_session_active',
      ),
      'voice_unavailable_no_capacity.503.json': isA<ServerException>()
          .having((e) => e.serverCode, 'code', 'voice_unavailable')
          .having((e) => e.retryable, 'retryable', isTrue)
          .having(
            (e) => e.retryAfter,
            'retryAfter',
            const Duration(seconds: 5),
          ),
    };

    test('all 14 error fixtures are covered', () {
      final files = Directory(
        '$handoff/errors',
      ).listSync().map((f) => f.uri.pathSegments.last).toSet();
      expect(files, expectations.keys.toSet());
    });

    for (final entry in expectations.entries) {
      test(entry.key, () async {
        await expectLater(
          make(serve('errors/${entry.key}')).status('vs_FIXTURE01'),
          throwsA(entry.value),
        );
      });
    }

    test('503 on create keeps Retry-After from the header too', () async {
      await expectLater(
        make(
          serve(
            'errors/voice_unavailable_no_capacity.503.json',
            edit: (b) {
              final m = Map<String, Object?>.from(b! as Map);
              final err = Map<String, Object?>.from(m['error']! as Map)
                ..remove('retry_after_seconds');
              return m..['error'] = err;
            },
          ),
        ).create(languageTag: 'en'),
        throwsA(
          isA<ServerException>().having(
            (e) => e.retryAfter,
            'retryAfter',
            const Duration(seconds: 5),
          ),
        ),
      );
    });
  });
}
