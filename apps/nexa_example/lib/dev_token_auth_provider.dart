import 'package:flutter/foundation.dart';
import 'package:nexa_sdk/nexa_sdk.dart';

/// DEVELOPMENT ONLY: forwards a short-lived SDK session token that a tester
/// supplied, for testing against the real NEXA backend before the customer's
/// host backend exists.
///
/// A real host implements [NexaAuthProvider] by calling its **own** backend,
/// which holds the tenant API key and mints the token
/// (`POST /v1/server/session-tokens` on the server side). That endpoint is
/// never called from the device, and the tenant API key never ships in an app.
///
/// The token comes from the developer's secrets file at build time
/// (`--dart-define-from-file`, a git-ignored file, see the example README);
/// it cannot be typed into the app. At runtime it lives in memory only. When
/// the gateway rejects it, the SDK asks for a new one; this provider can only
/// return the same token, so the UI shows an authentication error until the
/// app is rebuilt with a fresh token.
final class DevTokenAuthProvider extends ChangeNotifier
    implements NexaAuthProvider {
  DevTokenAuthProvider({String token = '', DateTime? expiresAt})
    : _token = token.trim(),
      _expiresAt = expiresAt;

  String _token;
  DateTime? _expiresAt;

  bool get hasToken => _token.isNotEmpty;

  /// Expiry stated by whoever minted the token, when known.
  DateTime? get expiresAt => _expiresAt;

  bool get isExpired =>
      _expiresAt != null && DateTime.now().toUtc().isAfter(_expiresAt!);

  /// Replaces the token (tests and the build-time configuration).
  void setToken(String token, {DateTime? expiresAt}) {
    _token = token.trim();
    _expiresAt = expiresAt?.toUtc();
    notifyListeners();
  }

  void clear() => setToken('');

  @override
  Future<SessionCredential> fetchSessionCredential() async {
    if (_token.isEmpty) {
      throw const AuthenticationException(
        'No SDK session token. Set NEXA_DEV_SDK_TOKEN in the secrets file '
        'and rebuild (development mode).',
      );
    }
    return SessionCredential(
      token: _token,
      // Unknown expiry: assume 30 minutes; the gateway is authoritative
      // and answers 401 when the token is no longer valid.
      expiresAt:
          _expiresAt ?? DateTime.now().toUtc().add(const Duration(minutes: 30)),
      scopes: const {'voice:session'},
    );
  }

  @override
  String toString() =>
      'DevTokenAuthProvider(hasToken: $hasToken, expiresAt: $_expiresAt)';
}
