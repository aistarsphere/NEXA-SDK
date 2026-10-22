import 'dart:async';

import 'package:clock/clock.dart';
import 'package:nexa_core/nexa_core.dart';

/// Owns the single active session: starts it with a fresh credential, exposes
/// the handle, ends it, and publishes lifecycle events to the host.
final class SessionManager {
  SessionManager({
    required ChatTransport transport,
    required CredentialManager credentials,
    required NexaConfig config,
    required NexaLogger logger,
  }) : _transport = transport,
       _credentials = credentials,
       _config = config,
       _logger = logger;

  final ChatTransport _transport;
  final CredentialManager _credentials;
  final NexaConfig _config;
  final NexaLogger _logger;
  final StreamController<NexaLifecycleEvent> _lifecycle =
      StreamController<NexaLifecycleEvent>.broadcast();

  SessionHandle? _current;
  Future<SessionHandle>? _starting;

  /// Active session, if any.
  SessionHandle? get current => _current;

  /// Lifecycle events for the host.
  Stream<NexaLifecycleEvent> get lifecycle => _lifecycle.stream;

  /// Transport in use (for the chat bloc).
  ChatTransport get transport => _transport;

  /// Starts a session or returns the active one. Concurrent calls share one
  /// start.
  Future<SessionHandle> start() {
    final existing = _current;
    if (existing != null && existing.expiresAt.isAfter(clock.now())) {
      return Future.value(existing);
    }
    final inFlight = _starting;
    if (inFlight != null) return inFlight;
    final future = _start();
    _starting = future;
    return future.whenComplete(() => _starting = null);
  }

  Future<SessionHandle> _start() async {
    try {
      final credential = await _credentials.getValid();
      emit(NexaCredentialRefreshed(clock.now(), credential.expiresAt));
      final handle = await _transport.startSession(
        credential: credential,
        requestedCapabilities: _config.requestedCapabilities,
        languageTag: _config.languageTag,
        clientMetadata: _config.clientMetadata,
      );
      _current = handle;
      emit(NexaSessionStarted(clock.now(), handle.sessionId));
      final missing = _config.requestedCapabilities.difference(
        handle.grantedCapabilities,
      );
      if (missing.isNotEmpty) {
        _logger.log(
          NexaLogLevel.info,
          'Capabilities not granted: ${missing.map((c) => c.name).join(', ')}',
        );
      }
      return handle;
    } on NexaException catch (e) {
      emit(NexaErrorOccurred(clock.now(), e));
      rethrow;
    } on Object catch (e) {
      final wrapped = UnknownNexaException('Failed to start session', cause: e);
      emit(NexaErrorOccurred(clock.now(), wrapped));
      throw wrapped;
    }
  }

  /// Ends the active session. Safe to call when none is active.
  Future<void> end({String reason = 'host'}) async {
    final handle = _current;
    if (handle == null) return;
    _current = null;
    try {
      await _transport.endSession(handle.sessionId);
    } on NexaException catch (e) {
      _logger.log(NexaLogLevel.warning, 'endSession failed: $e');
    } finally {
      emit(NexaSessionEnded(clock.now(), handle.sessionId, reason: reason));
    }
  }

  /// Marks the session as ended by the server (no network call).
  void markEnded(SessionId sessionId, String reason) {
    if (_current?.sessionId == sessionId) {
      _current = null;
      emit(NexaSessionEnded(clock.now(), sessionId, reason: reason));
    }
  }

  /// Publishes a lifecycle event.
  void emit(NexaLifecycleEvent event) {
    if (!_lifecycle.isClosed) _lifecycle.add(event);
  }

  /// Releases resources.
  Future<void> dispose() async {
    await end(reason: 'dispose');
    _credentials.clear();
    await _lifecycle.close();
  }
}
