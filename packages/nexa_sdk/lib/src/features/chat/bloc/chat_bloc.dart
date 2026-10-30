import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:clock/clock.dart';
import 'package:injectable/injectable.dart';
import 'package:nexa_core/nexa_core.dart';
import 'package:nexa_sdk/src/data/network/error_mapper.dart';
import 'package:nexa_sdk/src/features/chat/bloc/chat_event.dart';
import 'package:nexa_sdk/src/features/chat/bloc/chat_state.dart';
import 'package:nexa_sdk/src/permissions/nexa_permission_handler.dart';
import 'package:nexa_sdk/src/session/session_manager.dart';
import 'package:uuid/uuid.dart';

/// Orchestrates one chat screen: session start, event subscription with
/// ordering/de-duplication, automatic reconnection, sending/retrying/
/// cancelling messages, tool actions and permission round-trips.
///
/// All conversation mutations go through [ConversationReducer]; the bloc
/// never edits messages directly.
///
/// ## Reconnect policy
/// The transport makes one attempt per subscription. When it fails with a
/// retryable error (or closes before `session_ended`) the bloc enters
/// [ChatConnection.reconnecting] and resubscribes from the sequencer's last
/// applied sequence after an exponential back-off
/// (`eventPollInterval × 2^attempt`, capped at 15 s), up to
/// [NexaConfig.maxReconnectAttempts]. Auth, session-expiry and quota errors
/// are never retried automatically: they end in
/// [ChatConnection.disconnected] with an error the UI surfaces, and a user
/// retry starts a fresh session when the old one is gone.
@injectable
final class ChatBloc extends Bloc<ChatEvent, ChatState> {
  ChatBloc(
    this._sessions,
    this._reducer,
    this._permissions,
    this._logger,
    NexaConfig config,
    this._diagnostics,
  ) : _config = config,
      _languageTag = config.languageTag,
      super(const ChatState()) {
    // Sequential processing: transport events, sends and connection changes
    // must not interleave (bloc's default is concurrent). The permission
    // round-trip is the exception because it awaits a host dialog.
    on<ChatStarted>(_onStarted, transformer: _sequential());
    on<ChatMessageSent>(_onSent, transformer: _sequential());
    on<ChatMessageRetried>(_onRetried, transformer: _sequential());
    on<ChatGenerationCancelled>(_onCancelled, transformer: _sequential());
    on<ChatToolActionSubmitted>(_onToolAction, transformer: _sequential());
    on<ChatPermissionAnswered>(_onPermissionAnswered);
    on<ChatEnded>(_onEnded, transformer: _sequential());
    on<ChatTransportEventReceived>(
      _onTransportEvent,
      transformer: _sequential(),
    );
    on<ChatTransportFailed>(_onTransportFailed, transformer: _sequential());
    on<ChatTransportClosed>(_onTransportClosed, transformer: _sequential());
    on<ChatReconnectRequested>(
      _onReconnectRequested,
      transformer: _sequential(),
    );
  }

  /// One shared FIFO across the handlers that use it (bloc applies a
  /// transformer per event type, so the queue is shared via [_queue]).
  EventTransformer<E> _sequential<E extends ChatEvent>() =>
      (events, mapper) => _queue.enqueue(events, mapper);

  final _SequentialQueue<ChatEvent> _queue = _SequentialQueue();

  static const Duration maxReconnectBackoff = Duration(seconds: 15);

  final SessionManager _sessions;
  final ConversationReducer _reducer;
  final NexaPermissionHandler _permissions;
  final NexaLogger _logger;
  final NexaDiagnostics _diagnostics;
  final NexaConfig _config;
  final EventSequencer _sequencer = EventSequencer();
  static const _uuid = Uuid();

  String _languageTag;
  StreamSubscription<ConversationEvent>? _subscription;
  int _subscriptionGeneration = 0;
  SessionId? _sessionId;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  DateTime? _expiryRestartAt;

  /// Text deltas applied per assistant message (diagnostics: first token
  /// and delta count).
  final Map<MessageId, int> _deltas = {};

  /// Attachments per message, so a retry resends them.
  final Map<ClientMessageId, List<String>> _attachments = {};

  final StreamController<ConversationEvent> _toolEvents =
      StreamController<ConversationEvent>.broadcast();

  /// labeeb.sdk/1 tool, job, asset and UI events, in sequence order, for
  /// the tool-call controller.
  Stream<ConversationEvent> get toolEvents => _toolEvents.stream;

  /// Capabilities the backend granted for this session.
  Set<NexaCapability> get grantedCapabilities =>
      _sessions.current?.grantedCapabilities ?? const {};

  /// The active session (tool-call answers are scoped to it).
  SessionId? get sessionId => _sessionId;

  /// The server conversation of this chat (null without server history).
  String? get conversationId => _sessions.conversationId;

  /// Sends a `nexa.ui/1` touch event as `ui_event` on `POST /messages`.
  /// Returns the gateway error code when it was refused (e.g. a stale
  /// document answers `unknown_ui_component`), null when accepted.
  Future<String?> sendUiEvent(NexaUiEvent event) async {
    final id = _sessionId;
    if (id == null) return 'session_not_found';
    final clientId = ClientMessageId(_uuid.v4());
    try {
      await _sessions.transport.sendMessage(
        id,
        OutgoingMessage(
          clientMessageId: clientId,
          languageTag: _languageTag,
          uiEvent: event.toJson(),
        ),
      );
      _diagnostics.record('chat.ui_event', {
        'ui_id': event.uiId,
        'component_id': event.componentId,
        'event': event.event,
      });
      return null;
    } on NexaException catch (e) {
      final code = gatewayErrorCode(e) ?? e.code.name;
      _diagnostics.record('chat.ui_event_failed', {
        ...nexaErrorFields(e),
        'gateway_code': code,
      });
      return code;
    }
  }

  /// Updates the language hint sent with messages.
  set languageTag(String tag) => _languageTag = tag;

  Future<void> _onStarted(ChatStarted event, Emitter<ChatState> emit) async {
    if (state.connection == ChatConnection.connected ||
        state.connection == ChatConnection.connecting ||
        state.connection == ChatConnection.reconnecting) {
      return;
    }
    _cancelReconnect();
    emit(
      state.copyWith(connection: ChatConnection.connecting, clearError: true),
    );
    try {
      final handle = await _sessions.start();
      final resuming = handle.sessionId == _sessionId;
      _sessionId = handle.sessionId;
      if (!resuming) {
        _sequencer.reset(handle.sessionId, lastApplied: handle.lastSequence);
      }
      final after = resuming ? _sequencer.lastApplied : handle.lastSequence;
      emit(
        state.copyWith(
          conversation: state.conversation.copyWith(
            phase: resuming
                ? state.conversation.phase
                : ConversationPhase.starting,
            sessionId: handle.sessionId,
            sessionExpiresAt: handle.expiresAt,
            lastSequence: after,
            endReason: null,
          ),
          connection: ChatConnection.connected,
          reconnectAttempt: 0,
        ),
      );
      _subscribe(handle.sessionId, after);
      await _loadResumedHistory(emit);
    } on NexaException catch (e) {
      emit(state.copyWith(connection: ChatConnection.disconnected, error: e));
    }
  }

  /// A resumed server conversation shows its earlier messages first.
  Future<void> _loadResumedHistory(Emitter<ChatState> emit) async {
    final cid = _sessions.conversationId;
    final load = _sessions.historyLoader;
    if (!_sessions.resumePending || cid == null || load == null) return;
    _sessions.resumePending = false;
    try {
      final earlier = await load(cid);
      final known = {for (final m in state.conversation.messages) m.id};
      emit(
        state.copyWith(
          conversation: state.conversation.copyWith(
            messages: [
              for (final m in earlier)
                if (!known.contains(m.id)) m,
              ...state.conversation.messages,
            ],
          ),
        ),
      );
    } on Object catch (e) {
      _diagnostics.record('chat.history_load_failed', {
        'error': e.runtimeType.toString(),
      });
    }
  }

  void _subscribe(SessionId sessionId, int after) {
    unawaited(_subscription?.cancel());
    // Generation guard: callbacks from a superseded subscription (e.g. the
    // onDone that follows an onError) must not feed the bloc.
    final generation = ++_subscriptionGeneration;
    bool live() => generation == _subscriptionGeneration && !isClosed;
    _diagnostics.record('chat.stream_subscribe', {
      'session_id': sessionId.value,
      'after': after,
    });
    _subscription = _sessions.transport
        .events(sessionId, afterSequence: after)
        .listen(
          (e) {
            if (live()) add(ChatTransportEventReceived(e));
          },
          onError: (Object e) {
            if (!live()) return;
            _subscriptionGeneration++; // ignore the trailing onDone
            final error = e is NexaException
                ? e
                : UnknownNexaException(e.toString(), cause: e);
            _diagnostics.record('chat.stream_failed', nexaErrorFields(error));
            add(ChatTransportFailed(error));
          },
          onDone: () {
            if (!live()) return;
            _diagnostics.record('chat.stream_closed');
            add(const ChatTransportClosed());
          },
        );
  }

  void _onTransportEvent(
    ChatTransportEventReceived event,
    Emitter<ChatState> emit,
  ) {
    final result = _sequencer.accept(event.event);
    if (_reconnectAttempts != 0 || state.reconnectAttempt != 0) {
      // Any accepted event proves the new subscription works.
      _reconnectAttempts = 0;
      emit(
        state.copyWith(
          reconnectAttempt: 0,
          connection: ChatConnection.connected,
        ),
      );
    }
    switch (result.verdict) {
      case SequencerVerdict.duplicate:
      case SequencerVerdict.buffered:
        return;
      case SequencerVerdict.gapSkipped:
        _diagnostics.record('chat.event_gap', {
          'last_applied': _sequencer.lastApplied,
        });
        _logger.log(
          NexaLogLevel.warning,
          'Event gap skipped; resyncing from ${_sequencer.lastApplied}',
        );
        _applyAll(result.ready, emit);
        final id = _sessionId;
        if (id != null) _subscribe(id, _sequencer.lastApplied);
      case SequencerVerdict.apply:
        _applyAll(result.ready, emit);
    }
  }

  void _applyAll(List<ConversationEvent> events, Emitter<ChatState> emit) {
    var conversation = state.conversation;
    var connection = state.connection;
    var expired = false;
    for (final e in events) {
      conversation = _reducer.reduce(conversation, e);
      if (e is ContractToolCallEvent ||
          e is ToolCallProgressEvent ||
          e is AssetCreatedEvent ||
          e is UiPresentedEvent) {
        if (!_toolEvents.isClosed) _toolEvents.add(e);
      }
      if (_diagnostics.enabled) _recordEvent(e, conversation);
      switch (e) {
        case SessionEndedEvent(:final reason, :final sessionId):
          connection = ChatConnection.disconnected;
          _sessions.markEnded(sessionId, reason.name);
          expired = reason == SessionEndReason.expired;
        case QuotaUpdatedEvent(exceeded: true):
          _logger.log(NexaLogLevel.info, 'Quota exceeded for session');
        default:
          break;
      }
    }
    emit(state.copyWith(conversation: conversation, connection: connection));
    // An idle session timed out on the server: continue the same
    // conversation in a new session instead of stopping the chat.
    if (expired) _restartAfterExpiry(emit);
  }

  void _recordEvent(ConversationEvent e, ConversationState conversation) {
    switch (e) {
      case UserMessageAcceptedEvent(:final clientMessageId, :final messageId):
        _diagnostics.record('chat.user_accepted', {
          'client_message_id': clientMessageId.value,
          'message_id': messageId.value,
          'seq': e.sequence,
        });
      case UserMessageRejectedEvent(:final clientMessageId, :final error):
        _diagnostics.record('chat.user_rejected', {
          'client_message_id': clientMessageId.value,
          'error_code': error.code,
          'seq': e.sequence,
        });
      case AssistantMessageStartedEvent(:final messageId):
        _deltas[messageId] = 0;
        _diagnostics.record('chat.assistant_started', {
          'message_id': messageId.value,
          'seq': e.sequence,
        });
      case AssistantTextDeltaEvent(:final messageId, :final text):
        final n = (_deltas[messageId] ?? 0) + 1;
        _deltas[messageId] = n;
        if (n == 1) {
          _diagnostics.record('chat.assistant_first_delta', {
            'message_id': messageId.value,
            'seq': e.sequence,
            'text_len': text.length,
          });
        }
      case AssistantMessageCompletedEvent(
        :final messageId,
        :final finishReason,
      ):
        String? text;
        for (final m in conversation.messages) {
          if (m.id == messageId) text = m.text;
        }
        _diagnostics.record('chat.assistant_completed', {
          'message_id': messageId.value,
          'seq': e.sequence,
          'finish_reason': finishReason.name,
          'deltas': _deltas.remove(messageId) ?? 0,
          'text_len': text?.length,
          if (_diagnostics.captureContent) 'text': text,
        });
      case MessageFailedEvent(:final messageId, :final error):
        _deltas.remove(messageId);
        _diagnostics.record('chat.assistant_failed', {
          'message_id': messageId.value,
          'error_code': error.code,
          'retryable': error.retryable,
          'seq': e.sequence,
        });
      case MessageCancelledEvent(:final messageId):
        _deltas.remove(messageId);
        _diagnostics.record('chat.assistant_cancelled', {
          'message_id': messageId.value,
          'seq': e.sequence,
        });
      case SessionEndedEvent(:final reason):
        _diagnostics.record('chat.session_ended_event', {
          'reason': reason.name,
          'seq': e.sequence,
        });
      default:
        break;
    }
  }

  Future<void> _onSent(ChatMessageSent event, Emitter<ChatState> emit) async {
    final text = event.text.trim();
    final sessionId = _sessionId;
    // canSend already covers pending sends, streaming replies, quota and
    // connection state; this is the single gate against double submission.
    if (text.isEmpty || sessionId == null || !state.canSend) return;
    final clientId = ClientMessageId(_uuid.v4());
    if (event.attachments.isNotEmpty) {
      _attachments[clientId] = event.attachments;
    }
    await _send(sessionId, clientId, text, emit);
  }

  Future<void> _onRetried(
    ChatMessageRetried event,
    Emitter<ChatState> emit,
  ) async {
    final sessionId = _sessionId;
    if (sessionId == null || state.hasPendingUserMessage) return;
    ChatMessage? existing;
    for (final m in state.conversation.messages) {
      if (m.clientMessageId == event.clientMessageId) existing = m;
    }
    if (existing == null || !existing.retryable) return;
    await _send(sessionId, event.clientMessageId, existing.text, emit);
  }

  Future<void> _send(
    SessionId sessionId,
    ClientMessageId clientId,
    String text,
    Emitter<ChatState> emit,
  ) async {
    emit(
      state.copyWith(
        conversation: _reducer.addPendingUserMessage(
          state.conversation,
          clientMessageId: clientId,
          text: text,
          now: clock.now(),
        ),
        clearError: true,
      ),
    );
    final watch = Stopwatch()..start();
    _diagnostics.record('chat.send', {
      'session_id': sessionId.value,
      'client_message_id': clientId.value,
      'language': _languageTag,
      'text_len': text.length,
      if (_diagnostics.captureContent) 'text': text,
    });
    try {
      await _sessions.transport.sendMessage(
        sessionId,
        OutgoingMessage(
          clientMessageId: clientId,
          text: text,
          languageTag: _languageTag,
          // Retries resend the same attachments under the same key.
          attachments: _attachments[clientId] ?? const [],
        ),
      );
      _diagnostics.record('chat.send_accepted', {
        'client_message_id': clientId.value,
        'ms': watch.elapsedMilliseconds,
      });
    } on NexaException catch (e) {
      _diagnostics.record('chat.send_failed', {
        'client_message_id': clientId.value,
        'ms': watch.elapsedMilliseconds,
        ...nexaErrorFields(e),
      });
      final sessionLevel =
          e is QuotaExceededException ||
          e is SessionExpiredException ||
          e is AuthenticationException;
      if (e is SessionExpiredException) {
        _sessions.markEnded(sessionId, 'expired');
      }
      emit(
        state.copyWith(
          conversation: _reducer.markSendFailed(
            state.conversation,
            clientMessageId: clientId,
            errorCode: e.code.name,
            errorMessage: e.message,
            retryable: e is! QuotaExceededException,
          ),
          connection: e is SessionExpiredException
              ? ChatConnection.disconnected
              : null,
          error: sessionLevel ? e : null,
        ),
      );
      if (e is SessionExpiredException) _restartAfterExpiry(emit);
    }
  }

  /// labeeb.sdk/1: a server-owned conversation outlives its session
  /// (`410 session_ended|session_expired` → "create a new session on the same
  /// conversation"). At most once a minute, so a refusal cannot loop.
  bool _restartAfterExpiry(Emitter<ChatState> emit) {
    if (_sessions.conversationId == null) return false;
    final now = clock.now();
    final last = _expiryRestartAt;
    if (last != null && now.difference(last) < const Duration(minutes: 1)) {
      return false;
    }
    _expiryRestartAt = now;
    _cancelReconnect();
    _diagnostics.record('chat.session_renewed', const {});
    emit(state.copyWith(connection: ChatConnection.disconnected));
    add(const ChatStarted());
    return true;
  }

  Future<void> _onCancelled(
    ChatGenerationCancelled event,
    Emitter<ChatState> emit,
  ) async {
    final sessionId = _sessionId;
    final streaming = state.generating;
    if (sessionId == null || streaming == null) return;
    emit(
      state.copyWith(
        conversation: _reducer.markCancelling(state.conversation, streaming.id),
      ),
    );
    try {
      await _sessions.transport.cancelMessage(sessionId, streaming.id);
    } on NexaException catch (e) {
      // 409 "already finished": the completion event is on its way and wins.
      _logger.log(NexaLogLevel.info, 'cancel not applied: ${e.code.name}');
    }
  }

  Future<void> _onToolAction(
    ChatToolActionSubmitted event,
    Emitter<ChatState> emit,
  ) async {
    final sessionId = _sessionId;
    if (sessionId == null) return;
    if (state.resolvedToolCalls.contains(event.action.toolCallId)) return;
    emit(
      state.copyWith(
        resolvedToolCalls: {
          ...state.resolvedToolCalls,
          event.action.toolCallId,
        },
      ),
    );
    try {
      await _sessions.transport.submitToolAction(sessionId, event.action);
    } on NexaException catch (e) {
      emit(
        state.copyWith(
          resolvedToolCalls: {...state.resolvedToolCalls}
            ..remove(event.action.toolCallId),
          error: e,
        ),
      );
    }
  }

  Future<void> _onPermissionAnswered(
    ChatPermissionAnswered event,
    Emitter<ChatState> emit,
  ) async {
    final sessionId = _sessionId;
    PendingPermission? pending;
    for (final p in state.conversation.pendingPermissions) {
      if (p.requestId == event.requestId) pending = p;
    }
    if (sessionId == null || pending == null) return;
    emit(
      state.copyWith(
        conversation: _reducer.resolvePermission(
          state.conversation,
          event.requestId,
        ),
      ),
    );
    var granted = false;
    if (event.proceed) {
      try {
        granted = await _permissions.request(pending.permission);
      } on Object catch (e) {
        _logger.log(NexaLogLevel.warning, 'permission handler threw: $e');
      }
    }
    try {
      await _sessions.transport.reportPermissionResult(
        sessionId,
        requestId: event.requestId,
        granted: granted,
      );
    } on NexaException catch (e) {
      _logger.log(NexaLogLevel.warning, 'reportPermissionResult failed: $e');
    }
  }

  Future<void> _onEnded(ChatEnded event, Emitter<ChatState> emit) async {
    _cancelReconnect();
    // Fire-and-forget: nothing downstream depends on the cancel completing,
    // and awaiting it stalls under Flutter's fake-async test zone.
    unawaited(_subscription?.cancel());
    _subscription = null;
    await _sessions.end(reason: 'user');
    emit(
      state.copyWith(
        connection: ChatConnection.disconnected,
        conversation: state.conversation.copyWith(
          phase: ConversationPhase.ended,
          endReason: state.conversation.endReason ?? SessionEndReason.userEnded,
        ),
      ),
    );
  }

  void _onTransportFailed(ChatTransportFailed event, Emitter<ChatState> emit) {
    final error = event.error;
    if (state.conversation.phase == ConversationPhase.ended) {
      emit(state.copyWith(connection: ChatConnection.disconnected));
      return;
    }
    if (error is SessionExpiredException) {
      final id = _sessionId;
      if (id != null) _sessions.markEnded(id, 'expired');
      if (_restartAfterExpiry(emit)) return;
    }
    final automatic =
        error.retryable &&
        error is! SessionExpiredException &&
        error is! AuthenticationException &&
        error is! QuotaExceededException;
    if (automatic && _scheduleReconnect(emit)) return;
    emit(
      state.copyWith(
        connection: ChatConnection.disconnected,
        reconnectAttempt: 0,
        error: error,
      ),
    );
  }

  void _onTransportClosed(ChatTransportClosed event, Emitter<ChatState> emit) {
    if (state.conversation.phase == ConversationPhase.ended ||
        state.connection == ChatConnection.disconnected ||
        state.connection == ChatConnection.reconnecting) {
      return;
    }
    // Closed without session_ended (e.g. long-poll `done` after an end the
    // reducer already saw is handled above): reconnect from the cursor.
    if (!_scheduleReconnect(emit)) {
      emit(
        state.copyWith(
          connection: ChatConnection.disconnected,
          error: const TransportException(
            'Lost connection to the conversation.',
          ),
        ),
      );
    }
  }

  /// Returns false when the attempt budget is exhausted.
  bool _scheduleReconnect(Emitter<ChatState> emit) {
    if (_sessionId == null) return false;
    if (_reconnectAttempts >= _config.maxReconnectAttempts) return false;
    _reconnectAttempts++;
    final delay = _backoff(_reconnectAttempts);
    _diagnostics.record('chat.reconnect_scheduled', {
      'attempt': _reconnectAttempts,
      'delay_ms': delay.inMilliseconds,
    });
    _logger.log(
      NexaLogLevel.info,
      'Event stream interrupted; reconnect $_reconnectAttempts/'
      '${_config.maxReconnectAttempts} in $delay',
    );
    emit(
      state.copyWith(
        connection: ChatConnection.reconnecting,
        reconnectAttempt: _reconnectAttempts,
        clearError: true,
      ),
    );
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, () {
      if (!isClosed) add(const ChatReconnectRequested());
    });
    return true;
  }

  void _onReconnectRequested(
    ChatReconnectRequested event,
    Emitter<ChatState> emit,
  ) {
    final id = _sessionId;
    if (id == null ||
        state.connection != ChatConnection.reconnecting ||
        state.conversation.phase == ConversationPhase.ended) {
      return;
    }
    try {
      _subscribe(id, _sequencer.lastApplied);
    } on NotInitializedException {
      // The client was disposed while the retry was pending: stop quietly.
      _reconnectTimer?.cancel();
      emit(state.copyWith(connection: ChatConnection.disconnected));
      return;
    }
    // Optimistically connected; a failure comes straight back as
    // ChatTransportFailed and the attempt counter keeps climbing until an
    // event is actually received.
    emit(state.copyWith(connection: ChatConnection.connected));
  }

  Duration _backoff(int attempt) {
    final ms =
        _config.eventPollInterval.inMilliseconds *
        (1 << (attempt - 1).clamp(0, 6));
    return Duration(
      milliseconds: ms.clamp(0, maxReconnectBackoff.inMilliseconds),
    );
  }

  void _cancelReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _reconnectAttempts = 0;
  }

  @override
  Future<void> close() {
    _cancelReconnect();
    _subscriptionGeneration++;
    // Not awaited: cancelling a live socket subscription can take a round
    // trip, and `isClosed` must flip immediately so widgets can dispose.
    unawaited(_subscription?.cancel());
    _subscription = null;
    unawaited(_toolEvents.close());
    return super.close();
  }
}

/// FIFO shared by several `on<E>` handlers: each registration gets its own
/// transformer, but all of them funnel through one chain so handlers never
/// overlap.
final class _SequentialQueue<T> {
  Future<void> _tail = Future<void>.value();

  Stream<E> enqueue<E extends T>(
    Stream<E> events,
    Stream<E> Function(E) mapper,
  ) {
    late final StreamController<E> out;
    StreamSubscription<E>? sub;
    out = StreamController<E>(
      onListen: () {
        sub = events.listen(
          (event) {
            final previous = _tail;
            final completer = Completer<void>();
            _tail = completer.future;
            unawaited(
              previous.then((_) async {
                try {
                  await for (final e in mapper(event)) {
                    if (!out.isClosed) out.add(e);
                  }
                } on Object catch (error, stack) {
                  if (!out.isClosed) out.addError(error, stack);
                } finally {
                  completer.complete();
                }
              }),
            );
          },
          onError: out.addError,
          onDone: () => _tail.whenComplete(out.close),
        );
      },
      onCancel: () => sub?.cancel(),
    );
    return out.stream;
  }
}
