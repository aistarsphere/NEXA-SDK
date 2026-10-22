import 'dart:io';

import 'package:dio/dio.dart';
import 'package:nexa_core/nexa_core.dart';
import 'package:nexa_sdk/src/data/gateway/gateway_dtos.dart';

/// Maps transport failures to the public [NexaException] hierarchy. Widgets
/// and host code never see `DioException`.
NexaException mapError(Object error) {
  if (error is NexaException) return error;
  if (error is DioException) return _mapDio(error);
  if (error is SocketException) {
    return NetworkException(
      NexaErrorCode.networkUnreachable,
      'Network unreachable: ${error.message}',
      cause: error,
    );
  }
  if (error is HttpException) {
    // e.g. "Connection closed while receiving data" on a dropped stream.
    return NetworkException(
      NexaErrorCode.networkUnreachable,
      'Connection lost: ${error.message}',
      cause: error,
    );
  }
  return UnknownNexaException(error.toString(), cause: error);
}

NexaException _mapDio(DioException e) {
  switch (e.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
    case DioExceptionType.transformTimeout:
      return NetworkException(
        NexaErrorCode.networkTimeout,
        'Request timed out.',
        cause: e,
      );
    case DioExceptionType.connectionError:
      return NetworkException(
        NexaErrorCode.networkUnreachable,
        'Could not reach the gateway.',
        cause: e,
      );
    case DioExceptionType.cancel:
      return const CancelledException();
    case DioExceptionType.badCertificate:
      return TransportException(
        'TLS certificate rejected.',
        cause: e,
        retryable: false,
      );
    case DioExceptionType.badResponse:
      return _mapResponse(e);
    case DioExceptionType.unknown:
      final inner = e.error;
      if (inner is SocketException || inner is HttpException) {
        return mapError(inner!);
      }
      return TransportException('Transport failure: ${e.message}', cause: e);
  }
}

NexaException _mapResponse(DioException e) {
  final response = e.response;
  final status = response?.statusCode ?? 0;
  GatewayErrorDto? body;
  final data = response?.data;
  if (data is Map<String, Object?>) {
    final inner = data['error'];
    if (inner is Map<String, Object?>) {
      try {
        body = GatewayErrorDto.fromJson(inner);
      } on Object {
        body = null;
      }
    }
  }
  final message = body?.message ?? 'Gateway returned HTTP $status';
  switch (status) {
    case 401:
      return AuthenticationException(message, cause: e);
    case 403:
      return body?.code == 'capability_not_granted'
          ? CapabilityNotGrantedException(body?.quotaKind ?? 'unknown')
          : AuthenticationException(message, cause: e);
    case 410:
      return SessionExpiredException(message);
    case 402:
      return QuotaExceededException(quotaKind: body?.quotaKind ?? 'unknown');
    case 429:
      final retryAfter =
          body?.retryAfterSeconds ??
          int.tryParse(response?.headers.value('retry-after') ?? '');
      return RateLimitedException(
        retryAfter: retryAfter == null ? null : Duration(seconds: retryAfter),
        cause: e,
      );
    case 422:
      return ContractViolationException(message, cause: e);
    default:
      return ServerException(
        statusCode: status,
        message: message,
        serverCode: body?.code,
        retryable: body?.retryable ?? status >= 500,
        cause: e,
      );
  }
}
