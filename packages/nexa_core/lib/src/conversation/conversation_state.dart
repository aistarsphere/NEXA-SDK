import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:nexa_core/src/conversation/chat_message.dart';
import 'package:nexa_core/src/conversation/conversation_event.dart';
import 'package:nexa_core/src/ids/ids.dart';
import 'package:nexa_core/src/tools/tool_call.dart';
import 'package:nexa_core/src/tools/tool_result.dart';

part 'conversation_state.freezed.dart';

/// Coarse session phase.
enum ConversationPhase { idle, starting, active, ending, ended, failed }

/// Tracked state of one tool call.
@freezed
abstract class ToolCallState with _$ToolCallState {
  const factory ToolCallState({
    required ToolCallRequest request,
    required MessageId messageId,
    required ToolExecutionStatus status,
    double? progress,
    String? statusMessage,
    ToolResult? result,
    ConfirmationSpec? pendingConfirmation,
  }) = _ToolCallState;
}

/// Pending platform permission request.
@freezed
abstract class PendingPermission with _$PendingPermission {
  const factory PendingPermission({
    required String requestId,
    required NexaPermission permission,
    String? reason,
  }) = _PendingPermission;
}

/// Complete, immutable snapshot of a conversation. Produced only by
/// `ConversationReducer`; presentation reads it, never mutates it.
@freezed
abstract class ConversationState with _$ConversationState {
  const ConversationState._();

  const factory ConversationState({
    @Default(ConversationPhase.idle) ConversationPhase phase,
    SessionId? sessionId,
    DateTime? sessionExpiresAt,

    /// Messages in display order.
    @Default(<ChatMessage>[]) List<ChatMessage> messages,
    @Default(<ToolCallId, ToolCallState>{})
    Map<ToolCallId, ToolCallState> toolCalls,
    @Default(<PendingPermission>[]) List<PendingPermission> pendingPermissions,

    /// Highest sequence applied so far (0 = none).
    @Default(0) int lastSequence,
    QuotaInfo? quota,
    @Default(false) bool quotaExceeded,
    SessionEndReason? endReason,

    /// Last session-level error.
    EventError? lastError,
  }) = _ConversationState;

  /// Initial, empty state.
  static const initial = ConversationState();

  /// Finds a message by id.
  ChatMessage? messageById(MessageId id) {
    for (final m in messages) {
      if (m.id == id) return m;
    }
    return null;
  }

  /// True while an assistant message is streaming.
  bool get isAssistantResponding => messages.any((m) => m.isInProgress);

  /// Assistant message currently streaming, if any.
  ChatMessage? get streamingMessage {
    for (final m in messages.reversed) {
      if (m.isInProgress) return m;
    }
    return null;
  }

  /// Tool calls that are waiting for the user.
  Iterable<ToolCallState> get awaitingUser => toolCalls.values.where(
    (t) => t.status == ToolExecutionStatus.awaitingConfirmation,
  );

  /// Whether the user may send a new message now.
  bool get canSend =>
      phase == ConversationPhase.active &&
      !quotaExceeded &&
      !isAssistantResponding;
}
