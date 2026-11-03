import 'dart:async';

import 'package:clock/clock.dart';
import 'package:nexa_core/nexa_core.dart';
import 'package:nexa_sdk/src/features/conversation/conversation_coordinator.dart';

/// Owns the single active session: starts it with a fresh credential, exposes
/// the handle, ends it, and publishes lifecycle events to the host.
final class SessionManager {
  SessionManager({
    required ChatTransport transport,
    required CredentialManager credentials,
    required NexaConfig config,
    required NexaLogger logger,
    NexaDiagnostics diagnostics = const NoopNexaDiagnostics(),
  }) : _transport = transport,
       _credentials = credentials,
       _config = config,
       _logger = logger,
       _diagnostics = diagnostics;

  final ChatTransport _transport;
  final CredentialManager _credentials;
  final NexaConfig _config;
  final NexaLogger _logger;
  final NexaDiagnostics _diagnostics;
  final StreamController<NexaLifecycleEvent> _lifecycle =
      StreamController<NexaLifecycleEvent>.broadcast();

  SessionHandle? _current;

  /// Supplies the device tool names to declare in `client_tools`
  /// (labeeb.sdk/1; set by `NexaClient`).
  Future<List<String>> Function()? clientToolsProvider;

  /// Owner of the conversation id (set by `NexaClient`). When it can create
  /// conversations (real gateway) it does so with a stable `client_ref` and
  /// takes precedence over [conversationProvider].
  ConversationCoordinator? coordinator;

  /// Legacy hook for hosts and tests without a coordinator: returns the
  /// server conversation the next session joins, creating one when needed
  /// (null: the backend keeps no conversations).
  Future<String?> Function()? conversationProvider;

  /// Whether a call or chat can ask for a conversation to be created.
  bool get canCreateConversation =>
      (coordinator?.canCreate ?? false) || conversationProvider != null;

  String? _localConversationId;
  bool _localResumePending = false;

  /// The server conversation of the active (or next) session.
  String? get conversationId =>
      coordinator?.conversationId ?? _localConversationId;

  @Deprecated('Use ConversationCoordinator (NexaClient.conversations).')
  set conversationId(String? id) => _setConversation(id, force: true);

  void _setConversation(String? id, {bool force = false}) {
    final c = coordinator;
    if (c == null) {
      _localConversationId = id;
    } else if (id != null) {
      c.adopt(id);
    } else if (force) {
      c.startNew();
    }
  }

  Future<String?> _ensureConversation() async {
    final c = coordinator;
    if (c == null || !c.canCreate) {
      final provider = conversationProvider;
      return provider == null ? null : await provider();
    }
    try {
      return await c.ensureConversation(reason: 'session');
    } on NexaException catch (e) {
      // Sessions still work without one; tools and uploads will say so.
      _logger.log(
        NexaLogLevel.warning,
        'conversation not created: ${e.code.name}',
      );
      return null;
    }
  }

  /// Loads earlier messages of a resumed conversation (set by NexaClient).
  Future<List<ChatMessage>> Function(String conversationId)? historyLoader;

  /// True after a resume until the chat showed the earlier messages.
  bool get resumePending => coordinator?.resumePending ?? _localResumePending;
  set resumePending(bool value) {
    final c = coordinator;
    if (c == null) {
      _localResumePending = value;
    } else {
      c.resumePending = value;
    }
  }

  /// The gateway refused the device-tool declaration of the last session.
  bool declaredToolsRefused = false;
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
    final watch = Stopwatch()..start();
    _diagnostics.record('session.start_requested', {
      'language': _config.languageTag,
    });
    try {
      final credential = await _credentials.getValid();
      emit(NexaCredentialRefreshed(clock.now(), credential.expiresAt));
      _diagnostics.record('session.credential', {
        'ms': watch.elapsedMilliseconds,
        'expires_in_s': credential.expiresAt.difference(clock.now()).inSeconds,
      });
      final tools = clientToolsProvider == null
          ? const <String>[]
          : await clientToolsProvider!();
      final conversation = conversationId ?? await _ensureConversation();
      // Keep it even if opening the session fails below (e.g. 429): a
      // retry or a voice call then joins it instead of creating another.
      _setConversation(conversation);
      Future<SessionHandle> open(List<String> declared) =>
          _transport.startSession(
            credential: credential,
            requestedCapabilities: _config.requestedCapabilities,
            languageTag: _config.languageTag,
            clientMetadata: _config.clientMetadata,
            clientTools: declared,
            conversationId: conversation,
          );
      SessionHandle handle;
      try {
        handle = await open(tools);
      } on ContractViolationException catch (e) {
        // A refused device-tool declaration must not cost the user the
        // chat: start without device tools and say so.
        if (tools.isEmpty || !e.message.contains('client_tools')) {
          rethrow;
        }
        _logger.log(
          NexaLogLevel.warning,
          'client_tools refused by the gateway; continuing without device '
          'tools (${tools.length} declared)',
        );
        _diagnostics.record('session.client_tools_refused', {
          'declared': tools.length,
        });
        declaredToolsRefused = true;
        handle = await open(const []);
      }
      _setConversation(handle.conversationId ?? conversation);
      _current = handle;
      emit(NexaSessionStarted(clock.now(), handle.sessionId));
      final missing = _config.requestedCapabilities.difference(
        handle.grantedCapabilities,
      );
      _diagnostics.record('session.started', {
        'session_id': handle.sessionId.value,
        'ms': watch.elapsedMilliseconds,
        'granted': handle.grantedCapabilities.map((c) => c.name).join(','),
        'not_granted': missing.map((c) => c.name).join(','),
        'last_sequence': handle.lastSequence,
      });
      if (missing.isNotEmpty) {
        _logger.log(
          NexaLogLevel.info,
          'Capabilities not granted: ${missing.map((c) => c.name).join(', ')}',
        );
      }
      return handle;
    } on NexaException catch (e) {
      _recordStartFailed(watch, e);
      emit(NexaErrorOccurred(clock.now(), e));
      rethrow;
    } on Object catch (e) {
      final wrapped = UnknownNexaException('Failed to start session', cause: e);
      _recordStartFailed(watch, wrapped);
      emit(NexaErrorOccurred(clock.now(), wrapped));
      throw wrapped;
    }
  }

  void _recordStartFailed(Stopwatch watch, NexaException e) =>
      _diagnostics.record('session.start_failed', {
        'ms': watch.elapsedMilliseconds,
        ...nexaErrorFields(e),
      });

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
      _diagnostics.record('session.ended', {
        'session_id': handle.sessionId.value,
        'reason': reason,
      });
      emit(NexaSessionEnded(clock.now(), handle.sessionId, reason: reason));
    }
  }

  /// Marks the session as ended by the server (no network call).
  void markEnded(SessionId sessionId, String reason) {
    if (_current?.sessionId == sessionId) {
      _current = null;
      _diagnostics.record('session.ended', {
        'session_id': sessionId.value,
        'reason': reason,
        'by': 'server',
      });
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
