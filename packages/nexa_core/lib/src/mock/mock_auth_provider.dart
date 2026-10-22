import 'package:clock/clock.dart';
import 'package:nexa_core/src/auth/session_credential.dart';

/// **MOCK - never ship.** Issues fake credentials locally. Real host apps
/// fetch credentials from their own backend.
final class MockAuthProvider implements NexaAuthProvider {
  MockAuthProvider({
    this.lifetime = const Duration(minutes: 15),
    this.failWith,
  });

  /// Lifetime of each issued credential.
  final Duration lifetime;

  /// When set, every fetch throws this object (to test failure paths).
  final Object? failWith;

  int _issued = 0;

  /// Number of credentials issued so far.
  int get issuedCount => _issued;

  @override
  Future<SessionCredential> fetchSessionCredential() async {
    final failure = failWith;
    if (failure != null) throw failure;
    _issued++;
    return SessionCredential(
      token: 'mock-token-$_issued',
      expiresAt: clock.now().add(lifetime),
      scopes: const {'chat:session'},
    );
  }
}
