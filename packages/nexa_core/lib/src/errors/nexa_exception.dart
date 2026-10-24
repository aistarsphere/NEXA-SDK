/// Stable, machine-readable error codes surfaced to host applications.
///
/// Codes are part of the public contract; add new ones, never rename.
enum NexaErrorCode {
  configuration,
  notInitialized,
  authenticationFailed,
  sessionExpired,
  networkOffline,
  networkTimeout,
  networkUnreachable,
  rateLimited,
  quotaExceeded,
  server,
  contractViolation,
  cancelled,
  permissionDenied,
  capabilityNotGranted,
  transport,
  unknown,
}

/// Base type of every error the SDK exposes. Sealed so host code can switch
/// exhaustively.
sealed class NexaException implements Exception {
  const NexaException(
    this.code,
    this.message, {
    this.retryable = false,
    this.cause,
  });

  /// Stable error code.
  final NexaErrorCode code;

  /// Human-readable, developer-facing message (not localised).
  final String message;

  /// Whether retrying the same operation later is reasonable.
  final bool retryable;

  /// Underlying cause, if any.
  final Object? cause;

  @override
  String toString() => '$runtimeType(${code.name}): $message';
}

/// Invalid [NexaConfig] or misuse of the public API.
final class ConfigurationException extends NexaException {
  const ConfigurationException(String message, {Object? cause})
    : super(NexaErrorCode.configuration, message, cause: cause);
}

/// SDK used before `Nexa.initialize` or after `dispose`.
final class NotInitializedException extends NexaException {
  const NotInitializedException([
    String message = 'NEXA SDK is not initialised.',
  ]) : super(NexaErrorCode.notInitialized, message);
}

/// The gateway rejected the session credential.
final class AuthenticationException extends NexaException {
  const AuthenticationException(String message, {Object? cause})
    : super(NexaErrorCode.authenticationFailed, message, cause: cause);
}

/// The session credential or server session is no longer valid.
final class SessionExpiredException extends NexaException {
  const SessionExpiredException([String message = 'Session expired.'])
    : super(NexaErrorCode.sessionExpired, message, retryable: true);
}

/// Connectivity problems. [code] distinguishes offline / timeout / unreachable.
final class NetworkException extends NexaException {
  const NetworkException(super.code, super.message, {super.cause})
    : assert(
        code == NexaErrorCode.networkOffline ||
            code == NexaErrorCode.networkTimeout ||
            code == NexaErrorCode.networkUnreachable,
        'NetworkException requires a network error code',
      ),
      super(retryable: true);
}

/// Too many requests; honour [retryAfter] when present.
final class RateLimitedException extends NexaException {
  const RateLimitedException({this.retryAfter, Object? cause})
    : super(
        NexaErrorCode.rateLimited,
        'Rate limit exceeded.',
        retryable: true,
        cause: cause,
      );

  final Duration? retryAfter;
}

/// The tenant's quota is exhausted. [quotaKind] is a gateway-defined string
/// such as `messages`, `voice_minutes` or `tool_calls`.
final class QuotaExceededException extends NexaException {
  const QuotaExceededException({required this.quotaKind, this.resetsAt})
    : super(NexaErrorCode.quotaExceeded, 'Quota exceeded: $quotaKind');

  final String quotaKind;
  final DateTime? resetsAt;
}

/// Gateway returned an error response.
final class ServerException extends NexaException {
  const ServerException({
    required this.statusCode,
    required String message,
    this.serverCode,
    this.retryAfter,
    bool retryable = false,
    Object? cause,
  }) : super(NexaErrorCode.server, message, retryable: retryable, cause: cause);

  final int statusCode;

  /// Stable gateway error `code` (e.g. `voice_unavailable`), when known.
  final String? serverCode;

  /// `retry_after_seconds` / `Retry-After`: never retry sooner than this.
  final Duration? retryAfter;
}

/// A payload did not match the typed contract. Never rendered blindly.
final class ContractViolationException extends NexaException {
  const ContractViolationException(String message, {this.path, Object? cause})
    : super(NexaErrorCode.contractViolation, message, cause: cause);

  /// JSON path of the offending field when known.
  final String? path;
}

/// Operation cancelled by the user or by `dispose`.
final class CancelledException extends NexaException {
  const CancelledException([String message = 'Cancelled.'])
    : super(NexaErrorCode.cancelled, message);
}

/// A platform permission (microphone, etc.) was refused.
final class PermissionDeniedException extends NexaException {
  const PermissionDeniedException(this.permission)
    : super(NexaErrorCode.permissionDenied, 'Permission denied: $permission');

  final String permission;
}

/// The host requested a capability the gateway did not grant.
final class CapabilityNotGrantedException extends NexaException {
  const CapabilityNotGrantedException(this.capability)
    : super(
        NexaErrorCode.capabilityNotGranted,
        'Capability not granted: $capability',
      );

  final String capability;
}

/// Transport-level failure not covered by a more specific type.
final class TransportException extends NexaException {
  const TransportException(
    String message, {
    Object? cause,
    bool retryable = true,
  }) : super(
         NexaErrorCode.transport,
         message,
         retryable: retryable,
         cause: cause,
       );
}

/// Anything else. Should be rare; file a bug when it appears.
final class UnknownNexaException extends NexaException {
  const UnknownNexaException(String message, {Object? cause})
    : super(NexaErrorCode.unknown, message, cause: cause);
}
