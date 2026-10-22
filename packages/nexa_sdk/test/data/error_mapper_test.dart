import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexa_core/nexa_core.dart';
import 'package:nexa_sdk/src/data/network/error_mapper.dart';

DioException response(
  int status, {
  Map<String, Object?>? body,
  Map<String, List<String>>? headers,
}) {
  final options = RequestOptions(path: '/x');
  return DioException(
    requestOptions: options,
    type: DioExceptionType.badResponse,
    response: Response<Object?>(
      requestOptions: options,
      statusCode: status,
      data: body,
      headers: Headers.fromMap(headers ?? {}),
    ),
  );
}

void main() {
  group('mapError', () {
    test('timeouts and connection errors are retryable NetworkExceptions', () {
      for (final t in [
        DioExceptionType.connectionTimeout,
        DioExceptionType.receiveTimeout,
        DioExceptionType.connectionError,
      ]) {
        final e = mapError(
          DioException(requestOptions: RequestOptions(), type: t),
        );
        expect(e, isA<NetworkException>(), reason: t.name);
        expect(e.retryable, isTrue);
      }
    });

    test('status codes map to typed exceptions', () {
      expect(mapError(response(401)), isA<AuthenticationException>());
      expect(mapError(response(410)), isA<SessionExpiredException>());
      expect(
        mapError(
          response(
            402,
            body: {
              'error': {
                'code': 'quota',
                'message': 'q',
                'quota_kind': 'messages',
              },
            },
          ),
        ),
        isA<QuotaExceededException>().having(
          (e) => e.quotaKind,
          'kind',
          'messages',
        ),
      );
      expect(mapError(response(422)), isA<ContractViolationException>());
      final rl =
          mapError(
                response(
                  429,
                  headers: {
                    'retry-after': ['7'],
                  },
                ),
              )
              as RateLimitedException;
      expect(rl.retryAfter, const Duration(seconds: 7));
      final srv =
          mapError(
                response(
                  503,
                  body: {
                    'error': {
                      'code': 'busy',
                      'message': 'Model busy',
                      'retryable': true,
                    },
                  },
                ),
              )
              as ServerException;
      expect(srv.serverCode, 'busy');
      expect(srv.retryable, isTrue);
      expect(srv.message, 'Model busy');
    });

    test('passes NexaException through and wraps unknowns', () {
      const c = CancelledException();
      expect(identical(mapError(c), c), isTrue);
      expect(mapError(StateError('x')), isA<UnknownNexaException>());
      expect(
        mapError(
          DioException(
            requestOptions: RequestOptions(),
            type: DioExceptionType.cancel,
          ),
        ),
        isA<CancelledException>(),
      );
    });
  });
}
