import 'package:nexa_core/src/conversation/chat_message.dart';
import 'package:nexa_core/src/conversation/conversation_event.dart';
import 'package:nexa_core/src/conversation/conversation_state.dart';
import 'package:nexa_core/src/ids/ids.dart';
import 'package:nexa_core/src/tools/tool_call.dart';
import 'package:nexa_core/src/tools/tool_result.dart';

/// Pure function `(state, event) -> state`. No I/O, no clocks, no randomness,
/// so every ordering scenario is a plain unit test.
///
/// Semantics for messy inputs:
/// * **Duplicate delta** (`deltaIndex <= lastDeltaIndex`): ignored.
/// * **Late delta** (message already terminal): ignored.
/// * **Delta before `assistantMessageStarted`**: a placeholder streaming
///   message is created so text is never lost.
/// * **Completed with `fullText`**: replaces accumulated text (authoritative).
/// * **Failed after completed**: failure wins (errors are never hidden).
/// * **Cancelled after completed**: ignored.
/// * **Retry**: a user re-send reuses the same `clientMessageId`; the reducer
///   matches `userMessageAccepted` by that key, so retries never duplicate
///   the bubble.
final class ConversationReducer {
  const ConversationReducer();

  /// Applies [event] to [state].
  ConversationState reduce(ConversationState state, ConversationEvent event) {
    final next = switch (event) {
      SessionStartedEvent() => state.copyWith(
        phase: ConversationPhase.active,
        sessionId: event.sessionId,
        sessionExpiresAt: event.expiresAt,
      ),
      SessionEndedEvent(:final reason) => _endSession(state, reason),
      UserMessageAcceptedEvent() => _userAccepted(state, event),
      UserMessageRejectedEvent() => _userRejected(state, event),
      AssistantMessageStartedEvent() => _assistantStarted(state, event),
      AssistantTextDeltaEvent() => _delta(state, event),
      AssistantMessageCompletedEvent() => _completed(state, event),
      MessageFailedEvent() => _failed(state, event),
      MessageCancelledEvent(:final messageId) => _cancelled(state, messageId),
      ToolCallRequestedEvent() => _toolRequested(state, event),
      ToolExecutionProgressEvent() => _toolProgress(state, event),
      ToolResultReceivedEvent() => _toolResult(state, event),
      UserConfirmationRequestedEvent() => _confirmationRequested(state, event),
      PermissionRequestedEvent() => _permissionRequested(state, event),
      QuotaUpdatedEvent(:final quota, :final exceeded) => state.copyWith(
        quota: quota,
        quotaExceeded: exceeded,
      ),
      UnsupportedEvent() => state,
    };
    return next.copyWith(
      lastSequence: event.sequence > next.lastSequence
          ? event.sequence
          : next.lastSequence,
    );
  }

  /// Adds an optimistic user message before the gateway acknowledges it.
  /// Not an event because it is local-only; `userMessageAccepted` reconciles.
  ConversationState addPendingUserMessage(
    ConversationState state, {
    required ClientMessageId clientMessageId,
    required String text,
    required DateTime now,
  }) {
    final existingIndex = state.messages.indexWhere(
      (m) => m.clientMessageId == clientMessageId,
    );
    final message = ChatMessage(
      id: MessageId('local:${clientMessageId.value}'),
      role: MessageRole.user,
      status: MessageStatus.pending,
      createdAt: now,
      text: text,
      clientMessageId: clientMessageId,
    );
    if (existingIndex >= 0) {
      // Retry: keep position, reset status.
      final messages = [...state.messages];
      messages[existingIndex] = message.copyWith(
        id: messages[existingIndex].id,
        createdAt: messages[existingIndex].createdAt,
      );
      return state.copyWith(messages: messages);
    }
    return state.copyWith(messages: [...state.messages, message]);
  }

  /// Marks a pending user message as failed locally (e.g. send threw).
  ConversationState markSendFailed(
    ConversationState state, {
    required ClientMessageId clientMessageId,
    required String errorCode,
    required String errorMessage,
    bool retryable = true,
  }) => _updateWhere(
    state,
    (m) => m.clientMessageId == clientMessageId,
    (m) => m.copyWith(
      status: MessageStatus.failed,
      errorCode: errorCode,
      errorMessage: errorMessage,
      retryable: retryable,
    ),
  );

  /// Marks a streaming assistant message as cancelled locally while the
  /// gateway confirmation is in flight.
  ConversationState markCancelling(ConversationState state, MessageId id) =>
      _cancelled(state, id);

  ConversationState _endSession(
    ConversationState state,
    SessionEndReason reason,
  ) {
    final messages = state.messages
        .map(
          (m) => m.isInProgress
              ? m.copyWith(status: MessageStatus.cancelled)
              : m.status == MessageStatus.pending
              ? m.copyWith(
                  status: MessageStatus.failed,
                  errorCode: 'session_ended',
                  errorMessage:
                      'Session ended before the message was accepted.',
                  retryable: false,
                )
              : m,
        )
        .toList(growable: false);
    return state.copyWith(
      phase: ConversationPhase.ended,
      endReason: reason,
      messages: messages,
      quotaExceeded:
          state.quotaExceeded || reason == SessionEndReason.quotaExceeded,
    );
  }

  ConversationState _userAccepted(
    ConversationState state,
    UserMessageAcceptedEvent event,
  ) {
    final index = state.messages.indexWhere(
      (m) => m.clientMessageId == event.clientMessageId,
    );
    if (index < 0) {
      // Accepted message we never saw locally (e.g. resumed session): create it.
      return state.copyWith(
        messages: [
          ...state.messages,
          ChatMessage(
            id: event.messageId,
            role: MessageRole.user,
            status: MessageStatus.sent,
            createdAt: event.occurredAt,
            clientMessageId: event.clientMessageId,
          ),
        ],
      );
    }
    final messages = [...state.messages];
    messages[index] = messages[index].copyWith(
      id: event.messageId,
      status: MessageStatus.sent,
      errorCode: null,
      errorMessage: null,
      retryable: false,
    );
    return state.copyWith(messages: messages);
  }

  ConversationState _userRejected(
    ConversationState state,
    UserMessageRejectedEvent event,
  ) => _updateWhere(
    state,
    (m) => m.clientMessageId == event.clientMessageId,
    (m) => m.copyWith(
      status: MessageStatus.failed,
      errorCode: event.error.code,
      errorMessage: event.error.message,
      retryable: event.error.retryable,
    ),
  );

  ConversationState _assistantStarted(
    ConversationState state,
    AssistantMessageStartedEvent event,
  ) {
    if (state.messageById(event.messageId) != null) return state;
    return state.copyWith(
      messages: [
        ...state.messages,
        ChatMessage(
          id: event.messageId,
          role: MessageRole.assistant,
          status: MessageStatus.streaming,
          createdAt: event.occurredAt,
        ),
      ],
    );
  }

  ConversationState _delta(
    ConversationState state,
    AssistantTextDeltaEvent event,
  ) {
    final existing = state.messageById(event.messageId);
    if (existing == null) {
      // Placeholder: started event lost or reordered beyond the window.
      return state.copyWith(
        messages: [
          ...state.messages,
          ChatMessage(
            id: event.messageId,
            role: MessageRole.assistant,
            status: MessageStatus.streaming,
            createdAt: event.occurredAt,
            text: event.text,
            lastDeltaIndex: event.deltaIndex,
          ),
        ],
      );
    }
    if (existing.isTerminal) return state; // late
    if (event.deltaIndex <= existing.lastDeltaIndex) return state; // duplicate
    return _replace(
      state,
      existing.copyWith(
        text: existing.text + event.text,
        lastDeltaIndex: event.deltaIndex,
        status: MessageStatus.streaming,
      ),
    );
  }

  ConversationState _completed(
    ConversationState state,
    AssistantMessageCompletedEvent event,
  ) {
    final existing = state.messageById(event.messageId);
    final fullText = event.fullText;
    if (existing == null) {
      if (fullText == null) return state;
      return state.copyWith(
        messages: [
          ...state.messages,
          ChatMessage(
            id: event.messageId,
            role: MessageRole.assistant,
            status: MessageStatus.completed,
            createdAt: event.occurredAt,
            text: fullText,
          ),
        ],
      );
    }
    if (existing.status == MessageStatus.failed) return state; // failure wins
    final status = switch (event.finishReason) {
      FinishReason.cancelled => MessageStatus.cancelled,
      FinishReason.error => MessageStatus.failed,
      _ => MessageStatus.completed,
    };
    return _replace(
      state,
      existing.copyWith(status: status, text: fullText ?? existing.text),
    );
  }

  ConversationState _failed(ConversationState state, MessageFailedEvent event) {
    final existing = state.messageById(event.messageId);
    if (existing == null) return state;
    return _replace(
      state,
      existing.copyWith(
        status: MessageStatus.failed,
        errorCode: event.error.code,
        errorMessage: event.error.message,
        retryable: event.error.retryable && existing.role == MessageRole.user,
      ),
    );
  }

  ConversationState _cancelled(ConversationState state, MessageId id) {
    final existing = state.messageById(id);
    if (existing == null || existing.isTerminal) return state;
    return _replace(state, existing.copyWith(status: MessageStatus.cancelled));
  }

  ConversationState _toolRequested(
    ConversationState state,
    ToolCallRequestedEvent event,
  ) {
    final id = event.toolCall.id;
    if (state.toolCalls.containsKey(id)) return state;
    var next = state.copyWith(
      toolCalls: {
        ...state.toolCalls,
        id: ToolCallState(
          request: event.toolCall,
          messageId: event.messageId,
          status: event.toolCall.requiresConfirmation
              ? ToolExecutionStatus.awaitingConfirmation
              : ToolExecutionStatus.requested,
        ),
      },
    );
    final message = next.messageById(event.messageId);
    if (message == null) {
      next = next.copyWith(
        messages: [
          ...next.messages,
          ChatMessage(
            id: event.messageId,
            role: MessageRole.assistant,
            status: MessageStatus.streaming,
            createdAt: event.occurredAt,
            toolCallIds: [id],
          ),
        ],
      );
    } else if (!message.toolCallIds.contains(id)) {
      next = _replace(
        next,
        message.copyWith(toolCallIds: [...message.toolCallIds, id]),
      );
    }
    return next;
  }

  ConversationState _toolProgress(
    ConversationState state,
    ToolExecutionProgressEvent event,
  ) {
    final existing = state.toolCalls[event.toolCallId];
    if (existing == null) return state;
    if (_isToolTerminal(existing.status) && !_isToolTerminal(event.status)) {
      return state; // late progress after terminal status
    }
    return state.copyWith(
      toolCalls: {
        ...state.toolCalls,
        event.toolCallId: existing.copyWith(
          status: event.status,
          progress: event.progress ?? existing.progress,
          statusMessage: event.message ?? existing.statusMessage,
          pendingConfirmation:
              event.status == ToolExecutionStatus.awaitingConfirmation
              ? existing.pendingConfirmation
              : null,
        ),
      },
    );
  }

  ConversationState _toolResult(
    ConversationState state,
    ToolResultReceivedEvent event,
  ) {
    final existing = state.toolCalls[event.toolCallId];
    final request =
        existing?.request ??
        ToolCallRequest(
          id: event.toolCallId,
          toolName: 'unknown',
          displayTitle: '',
        );
    final isError = event.result is ErrorToolResult;
    return state.copyWith(
      toolCalls: {
        ...state.toolCalls,
        event.toolCallId: ToolCallState(
          request: request,
          messageId: event.messageId,
          status: isError
              ? ToolExecutionStatus.failed
              : ToolExecutionStatus.succeeded,
          progress: isError ? existing?.progress : 1,
          result: event.result,
        ),
      },
    );
  }

  ConversationState _confirmationRequested(
    ConversationState state,
    UserConfirmationRequestedEvent event,
  ) {
    final existing = state.toolCalls[event.toolCallId];
    if (existing == null || _isToolTerminal(existing.status)) return state;
    return state.copyWith(
      toolCalls: {
        ...state.toolCalls,
        event.toolCallId: existing.copyWith(
          status: ToolExecutionStatus.awaitingConfirmation,
          pendingConfirmation: event.confirmation,
        ),
      },
    );
  }

  ConversationState _permissionRequested(
    ConversationState state,
    PermissionRequestedEvent event,
  ) {
    if (state.pendingPermissions.any((p) => p.requestId == event.requestId)) {
      return state;
    }
    return state.copyWith(
      pendingPermissions: [
        ...state.pendingPermissions,
        PendingPermission(
          requestId: event.requestId,
          permission: event.permission,
          reason: event.reason,
        ),
      ],
    );
  }

  /// Removes a resolved permission request.
  ConversationState resolvePermission(
    ConversationState state,
    String requestId,
  ) => state.copyWith(
    pendingPermissions: state.pendingPermissions
        .where((p) => p.requestId != requestId)
        .toList(),
  );

  static bool _isToolTerminal(ToolExecutionStatus s) =>
      s == ToolExecutionStatus.succeeded ||
      s == ToolExecutionStatus.failed ||
      s == ToolExecutionStatus.cancelled;

  ConversationState _replace(ConversationState state, ChatMessage message) =>
      _updateWhere(state, (m) => m.id == message.id, (_) => message);

  ConversationState _updateWhere(
    ConversationState state,
    bool Function(ChatMessage) test,
    ChatMessage Function(ChatMessage) update,
  ) {
    final index = state.messages.indexWhere(test);
    if (index < 0) return state;
    final messages = [...state.messages];
    messages[index] = update(messages[index]);
    return state.copyWith(messages: messages);
  }
}
