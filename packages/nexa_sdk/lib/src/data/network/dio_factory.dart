import 'package:dio/dio.dart';
import 'package:nexa_core/nexa_core.dart';
import 'package:nexa_sdk/src/version.dart';
import 'package:uuid/uuid.dart';

/// Builds the SDK's [Dio] instance. One per `NexaClient`; never shared with
/// the host's own HTTP stack.
abstract final class DioFactory {
  static Dio create({
    required NexaConfig config,
    required CredentialManager credentials,
    required NexaLogger logger,
    NexaDiagnostics diagnostics = const NoopNexaDiagnostics(),
  }) {
    final dio = Dio(
      BaseOptions(
        baseUrl: config.gatewayBaseUri.toString(),
        connectTimeout: config.connectTimeout,
        receiveTimeout: config.receiveTimeout,
        headers: {
          'Accept': 'application/json',
          'X-Nexa-App-Id': config.applicationId,
          'X-Nexa-Sdk-Version': nexaSdkVersion,
        },
      ),
    );
    dio.interceptors.addAll([
      _RequestIdInterceptor(),
      // Before auth, so a 401 is recorded before the one refresh-and-retry.
      if (diagnostics.enabled) _DiagnosticsInterceptor(diagnostics),
      _AuthInterceptor(credentials, dio, logger),
      if (config.environment.allowsVerboseLogging) _LogInterceptor(logger),
    ]);
    return dio;
  }
}

final class _RequestIdInterceptor extends Interceptor {
  static const _uuid = Uuid();

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.headers.putIfAbsent('X-Request-Id', _uuid.v4);
    handler.next(options);
  }
}

/// Attaches the session credential and retries exactly once after a 401 with
/// a force-refreshed credential.
final class _AuthInterceptor extends Interceptor {
  _AuthInterceptor(this._credentials, this._dio, this._logger);

  final CredentialManager _credentials;
  final Dio _dio;
  final NexaLogger _logger;
  static const _retriedKey = 'nexa.auth.retried';

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    try {
      final credential = await _credentials.getValid();
      options.headers['Authorization'] = 'Bearer ${credential.token}';
      handler.next(options);
    } on Object catch (error, stack) {
      handler.reject(
        DioException(requestOptions: options, error: error, stackTrace: stack),
      );
    }
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final alreadyRetried = err.requestOptions.extra[_retriedKey] == true;
    if (err.response?.statusCode != 401 || alreadyRetried) {
      handler.next(err);
      return;
    }
    _logger.log(
      NexaLogLevel.info,
      'Gateway returned 401; refreshing credential once.',
    );
    try {
      final fresh = await _credentials.forceRefresh();
      final options = err.requestOptions
        ..headers['Authorization'] = 'Bearer ${fresh.token}'
        ..extra[_retriedKey] = true;
      final response = await _dio.fetch<Object?>(options);
      handler.resolve(response);
    } on DioException catch (retryError) {
      handler.next(retryError);
    } on Object catch (error, stack) {
      handler.next(
        DioException(
          requestOptions: err.requestOptions,
          error: error,
          stackTrace: stack,
        ),
      );
    }
  }
}

final class _LogInterceptor extends Interceptor {
  _LogInterceptor(this._logger);
  final NexaLogger _logger;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    _logger.log(NexaLogLevel.debug, '→ ${options.method} ${options.uri.path}');
    handler.next(options);
  }

  @override
  void onResponse(
    Response<Object?> response,
    ResponseInterceptorHandler handler,
  ) {
    _logger.log(
      NexaLogLevel.debug,
      '← ${response.statusCode} ${response.requestOptions.uri.path}',
    );
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    _logger.log(
      NexaLogLevel.warning,
      '✗ ${err.response?.statusCode ?? err.type.name} ${err.requestOptions.uri.path}',
    );
    handler.next(err);
  }
}

/// One `http.request` diagnostic per call: method, path (no query), status,
/// duration to response headers, our `X-Request-Id`, the server's request id
/// header and the gateway error code. Never headers or bodies.
final class _DiagnosticsInterceptor extends Interceptor {
  _DiagnosticsInterceptor(this._diagnostics);
  final NexaDiagnostics _diagnostics;
  static const _watchKey = 'nexa.diag.watch';

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.extra[_watchKey] = Stopwatch()..start();
    handler.next(options);
  }

  @override
  void onResponse(
    Response<Object?> response,
    ResponseInterceptorHandler handler,
  ) {
    _record(response.requestOptions, response, null);
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    _record(err.requestOptions, err.response, err);
    handler.next(err);
  }

  void _record(
    RequestOptions options,
    Response<Object?>? response,
    DioException? error,
  ) {
    final watch = options.extra[_watchKey];
    final path = options.uri.path;
    String? errorCode;
    final data = response?.data;
    if (data is Map && data['error'] is Map) {
      final code = (data['error'] as Map)['code'];
      if (code is String) errorCode = code;
    }
    _diagnostics.record('http.request', {
      'channel': path.contains('/voice/') ? 'voice' : 'chat',
      'method': options.method,
      'path': path,
      'status': response?.statusCode,
      'ms': watch is Stopwatch ? watch.elapsedMilliseconds : null,
      'stream': options.responseType == ResponseType.stream,
      'request_id': options.headers['X-Request-Id']?.toString(),
      'server_request_id':
          response?.headers.value('x-request-id') ??
          response?.headers.value('x-nexa-request-id'),
      'error_code': errorCode,
      'retry_after': response?.headers.value('retry-after'),
      if (error != null) 'dio_error': error.type.name,
      'auth_retry': options.extra[_AuthInterceptor._retriedKey] == true,
    });
  }
}
