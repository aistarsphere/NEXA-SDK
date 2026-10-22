import 'dart:async';

import 'package:clock/clock.dart';

import 'package:nexa_core/src/auth/session_credential.dart';
import 'package:nexa_core/src/errors/nexa_exception.dart';

/// Caches the current [SessionCredential], refreshes it ahead of expiry and
/// collapses concurrent refreshes into one in-flight request.
///
/// Pure Dart, no I/O of its own; fully unit-testable with `package:clock`.
final class CredentialManager {
  CredentialManager(
    this._provider, {
    this.refreshSkew = const Duration(seconds: 30),
  });

  final NexaAuthProvider _provider;

  /// Credentials expiring within this window are refreshed proactively. For
  /// short-lived credentials the effective window shrinks to a quarter of
  /// the credential's lifetime so a 60 s token is not refreshed on every
  /// call.
  final Duration refreshSkew;

  Duration _skewFor(SessionCredential c) {
    final lifetime = c.expiresAt.difference(_issuedAt ?? c.expiresAt);
    final quarter = lifetime ~/ 4;
    return quarter < refreshSkew ? quarter : refreshSkew;
  }

  DateTime? _issuedAt;

  SessionCredential? _current;
  Future<SessionCredential>? _inFlight;

  /// Currently cached credential, possibly expired. Diagnostics only.
  SessionCredential? get current => _current;

  /// Returns a credential valid for at least [refreshSkew], refreshing if
  /// needed. Concurrent callers share one refresh.
  Future<SessionCredential> getValid() {
    final cached = _current;
    if (cached != null && !cached.expiresWithin(_skewFor(cached))) {
      return Future.value(cached);
    }
    return _refresh();
  }

  /// Forces a refresh, e.g. after the gateway answered 401.
  Future<SessionCredential> forceRefresh() {
    _current = null;
    return _refresh();
  }

  /// Drops the cached credential.
  void clear() {
    _current = null;
  }

  Future<SessionCredential> _refresh() {
    final existing = _inFlight;
    if (existing != null) return existing;
    final future = _fetch();
    _inFlight = future;
    return future.whenComplete(() => _inFlight = null);
  }

  Future<SessionCredential> _fetch() async {
    final SessionCredential credential;
    try {
      credential = await _provider.fetchSessionCredential();
    } on NexaException {
      rethrow;
    } on Object catch (error) {
      throw AuthenticationException(
        'Host auth provider failed to issue a session credential.',
        cause: error,
      );
    }
    if (credential.isExpired) {
      throw const AuthenticationException(
        'Host auth provider returned an already-expired credential.',
      );
    }
    _current = credential;
    _issuedAt = clock.now();
    return credential;
  }
}
