import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:nexa_core/nexa_core.dart';
import 'package:uuid/uuid.dart';

/// Single owner of "which server conversation is current".
///
/// Chat, voice, history resume and the assistant all go through here, so a
/// conversation is created once. The `client_ref` of a create stays the same
/// across failed attempts (`POST /conversations` is idempotent per ref), so
/// a retry after a timeout cannot make a duplicate.
final class ConversationCoordinator extends ChangeNotifier {
  ConversationCoordinator({
    required String installationId,
    Future<String> Function({required String clientRef})? create,
    String Function()? newId,
    NexaDiagnostics diagnostics = const NoopNexaDiagnostics(),
  }) : _create = create,
       _installationId = installationId,
       _newId = newId ?? (() => const Uuid().v4()),
       _diagnostics = diagnostics;

  final Future<String> Function({required String clientRef})? _create;
  final String _installationId;
  final String Function() _newId;
  final NexaDiagnostics _diagnostics;

  String? _conversationId;
  String? _pendingClientRef;
  Future<String>? _creating;
  int _lastKnownSeq = 0;

  /// Whether this coordinator can create conversations (a real gateway).
  /// Without it ([open]/[adopt] still track an id) a session or call runs
  /// without a server conversation.
  bool get canCreate => _create != null;

  final StreamController<List<ChatMessage>> _persisted =
      StreamController<List<ChatMessage>>.broadcast();

  /// Messages persisted by the server that the open chat should merge (the
  /// turns of a call). Never replays: a chat opening later loads history.
  Stream<List<ChatMessage>> get persistedMessages => _persisted.stream;

  /// Hands persisted [messages] to the open chat(s).
  void publishPersisted(List<ChatMessage> messages) {
    if (!_persisted.isClosed && messages.isNotEmpty) _persisted.add(messages);
  }

  @override
  void dispose() {
    unawaited(_persisted.close());
    super.dispose();
  }

  /// The current server conversation, or null before the first create.
  String? get conversationId => _conversationId;

  /// Highest message sequence seen for the current conversation.
  int get lastKnownSeq => _lastKnownSeq;

  /// True after [open] until the chat has shown the earlier messages.
  bool resumePending = false;

  /// Returns the current conversation id, creating the conversation when
  /// there is none. Concurrent callers share one request.
  Future<String> ensureConversation({required String reason}) {
    final id = _conversationId;
    if (id != null) return Future.value(id);
    if (_create == null) {
      return Future.error(
        const ConfigurationException(
          'This client keeps no server conversations',
        ),
      );
    }
    return _creating ??= _createNow(reason);
  }

  Future<String> _createNow(String reason) async {
    final ref = _pendingClientRef ??= '$_installationId:${_newId()}';
    try {
      final id = await _create!(clientRef: ref);
      // startNew/open while the request was in flight: the user moved on.
      if (_pendingClientRef == ref) {
        _pendingClientRef = null;
        _conversationId = id;
        _lastKnownSeq = 0;
        _diagnostics.record('conversation.created', {'reason': reason});
        notifyListeners();
      }
      return id;
    } finally {
      _creating = null;
    }
  }

  /// Continues an existing conversation (history resume).
  void open(String id) {
    _conversationId = id;
    _pendingClientRef = null;
    _lastKnownSeq = 0;
    resumePending = true;
    notifyListeners();
  }

  /// Forgets the current conversation; the next [ensureConversation] makes
  /// a new one with a new `client_ref`.
  void startNew() {
    _conversationId = null;
    _pendingClientRef = null;
    _lastKnownSeq = 0;
    resumePending = false;
    notifyListeners();
  }

  /// Takes the conversation id the gateway assigned to a session.
  void adopt(String? id) {
    if (id == null || id == _conversationId) return;
    _conversationId = id;
    notifyListeners();
  }

  /// Records a message sequence number (only moves forward).
  void noteSeq(int seq) {
    if (seq > _lastKnownSeq) _lastKnownSeq = seq;
  }
}
