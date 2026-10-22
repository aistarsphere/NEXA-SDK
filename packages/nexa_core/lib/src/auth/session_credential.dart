import 'package:clock/clock.dart';
import 'package:meta/meta.dart';

/// Short-lived credential issued by the **host's backend** (or by the NEXA
/// gateway via the host's backend) that authorises one SDK session.
///
/// The SDK treats [token] as opaque. The gateway binds it to a tenant and
/// application server-side; the mobile-supplied `applicationId` is never
/// used as proof of anything.
@immutable
final class SessionCredential {
  const SessionCredential({
    required this.token,
    required this.expiresAt,
    this.scopes = const {},
  });

  /// Opaque bearer token. Never log it.
  final String token;

  /// Absolute expiry. Use [isExpired] / [expiresWithin].
  final DateTime expiresAt;

  /// Optional scopes granted to the token, for diagnostics only.
  final Set<String> scopes;

  /// True when the credential is already expired (uses package:clock for tests).
  bool get isExpired => !clock.now().isBefore(expiresAt);

  /// True when the credential expires within [window].
  bool expiresWithin(Duration window) =>
      !clock.now().add(window).isBefore(expiresAt);

  @override
  String toString() =>
      'SessionCredential(expiresAt: $expiresAt, scopes: $scopes, token: <redacted>)';
}

/// Implemented by the host application. The host obtains a session credential
/// from **its own backend**, which holds the tenant's NEXA API key and calls
/// the gateway's token endpoint. Long-lived secrets therefore never reach the
/// device.
abstract interface class NexaAuthProvider {
  /// Returns a fresh credential. Called on first use and again before expiry.
  /// Throw any exception to signal failure; the SDK maps it to
  /// `AuthenticationException`.
  Future<SessionCredential> fetchSessionCredential();
}
