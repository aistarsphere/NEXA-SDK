import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexa_core/nexa_core.dart';
import 'package:nexa_sdk/src/data/gateway/gateway_voice_provisioner.dart';

/// Dio adapter answering from a map so the provisioner's wire mapping can be
/// tested without sockets.
final class _Adapter implements HttpClientAdapter {
  _Adapter(this.respond);
  final (int, Object?) Function(RequestOptions) respond;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final (status, body) = respond(options);
    return ResponseBody.fromString(
      body == null ? '' : _json(body),
      status,
      headers: {
        'content-type': ['application/json'],
      },
    );
  }

  static String _json(Object body) =>
      body is String ? body : jsonEncodeOf(body);

  @override
  void close({bool force = false}) {}
}

String jsonEncodeOf(Object body) {
  // Minimal encoder to avoid importing dart:convert in the adapter signature.
  return const _Enc().convert(body);
}

final class _Enc {
  const _Enc();
  String convert(Object body) => _encode(body);
  static String _encode(Object? v) {
    if (v == null) return 'null';
    if (v is num || v is bool) return '$v';
    if (v is String) return '"${v.replaceAll('"', r'\"')}"';
    if (v is Map) {
      return '{${v.entries.map((e) => '"${e.key}":${_encode(e.value)}').join(',')}}';
    }
    if (v is List) return '[${v.map(_encode).join(',')}]';
    throw ArgumentError('unsupported $v');
  }
}

Map<String, Object?> grantJson({Map<String, Object?> overrides = const {}}) => {
  'voice_session_id': 'vs_1',
  'livekit_url': 'wss://lk.example/x',
  'participant_token': 'tok',
  'room_name': 'room',
  'participant_identity': 'user-1',
  'agent_identity': 'nexa-agent',
  'expires_at': '2030-01-01T00:00:00Z',
  'event_verification_key': 'key',
  'event_signature_alg': 'HMAC-SHA256',
  'max_duration_seconds': 300,
  ...overrides,
};

void main() {
  GatewayVoiceProvisioner make(_Adapter adapter) {
    final dio = Dio(BaseOptions(baseUrl: 'http://gw'))
      ..httpClientAdapter = adapter;
    return GatewayVoiceProvisioner(dio: dio, logger: const NoopNexaLogger());
  }

  group('GatewayVoiceProvisioner', () {
    test('maps a full grant and posts to the proposed path', () async {
      final adapter = _Adapter((_) => (201, grantJson()));
      final g = await make(adapter).provision(const SessionId('s1'));
      expect(adapter.requests.single.path, '/v1/sdk/sessions/s1/voice');
      expect(g.voiceSessionId, 'vs_1');
      expect(g.liveKitUrl.scheme, 'wss');
      expect(g.agentIdentity, 'nexa-agent');
      expect(g.eventVerificationKey, 'key');
      expect(g.maxDuration, const Duration(seconds: 300));
      expect(g.isExpired, isFalse);
    });

    test('missing required fields are contract violations', () async {
      for (final key in [
        'voice_session_id',
        'livekit_url',
        'participant_token',
        'room_name',
        'participant_identity',
        'expires_at',
      ]) {
        final adapter = _Adapter((_) => (201, grantJson()..remove(key)));
        await expectLater(
          make(adapter).provision(const SessionId('s')),
          throwsA(
            isA<ContractViolationException>().having(
              (e) => e.path,
              'path',
              key,
            ),
          ),
          reason: key,
        );
      }
    });

    test(
      'non-websocket url and unknown signature algorithm are rejected',
      () async {
        await expectLater(
          make(
            _Adapter(
              (_) => (201, grantJson(overrides: {'livekit_url': 'https://x'})),
            ),
          ).provision(const SessionId('s')),
          throwsA(isA<ContractViolationException>()),
        );
        await expectLater(
          make(
            _Adapter(
              (_) =>
                  (201, grantJson(overrides: {'event_signature_alg': 'RSA'})),
            ),
          ).provision(const SessionId('s')),
          throwsA(isA<ContractViolationException>()),
        );
      },
    );

    test(
      'optional fields may be absent (dev gateway without signing)',
      () async {
        final g = await make(
          _Adapter(
            (_) => (
              201,
              grantJson()
                ..remove('event_verification_key')
                ..remove('event_signature_alg')
                ..remove('agent_identity')
                ..remove('max_duration_seconds'),
            ),
          ),
        ).provision(const SessionId('s'));
        expect(g.eventVerificationKey, isNull);
        expect(g.agentIdentity, isNull);
        expect(g.maxDuration, isNull);
      },
    );

    test('gateway errors map to the public hierarchy', () async {
      Future<void> expectError(int status, String code, Matcher m) async {
        final adapter = _Adapter(
          (_) => (
            status,
            {
              'error': {
                'code': code,
                'message': 'x',
                'quota_kind': 'voice_minutes',
              },
            },
          ),
        );
        await expectLater(
          make(adapter).provision(const SessionId('s')),
          throwsA(m),
        );
      }

      await expectError(402, 'quota_exceeded', isA<QuotaExceededException>());
      await expectError(
        403,
        'capability_not_granted',
        isA<CapabilityNotGrantedException>(),
      );
      await expectError(401, 'token_expired', isA<AuthenticationException>());
      await expectError(410, 'session_expired', isA<SessionExpiredException>());
      await expectError(503, 'voice_unavailable', isA<ServerException>());
    });

    test('intents and end are best effort and never throw', () async {
      final adapter = _Adapter(
        (_) => (
          500,
          {
            'error': {'code': 'boom', 'message': 'x'},
          },
        ),
      );
      final p = make(adapter);
      await p.sendIntent(const SessionId('s'), 'interrupt');
      await p.end(const SessionId('s'));
      expect(adapter.requests.map((r) => r.method), ['POST', 'DELETE']);
      expect(adapter.requests.first.path, '/v1/sdk/sessions/s/voice/intents');
    });
  });
}
