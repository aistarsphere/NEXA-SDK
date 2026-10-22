import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:nexa_core/src/ids/ids.dart';

part 'chat_message.freezed.dart';

/// Who authored a message.
enum MessageRole { user, assistant, system }

/// Delivery / generation status of a message.
enum MessageStatus {
  /// User message created locally, not yet acknowledged by the gateway.
  pending,

  /// User message acknowledged by the gateway.
  sent,

  /// Assistant message currently receiving text deltas.
  streaming,

  /// Final.
  completed,

  /// Terminal failure; see [ChatMessage.errorCode].
  failed,

  /// Cancelled by the user before completion.
  cancelled,
}

/// A message in the conversation, as held in `ConversationState`.
///
/// Presentation widgets consume this type only; they never see wire payloads.
@freezed
abstract class ChatMessage with _$ChatMessage {
  const ChatMessage._();

  const factory ChatMessage({
    required MessageId id,
    required MessageRole role,
    required MessageStatus status,
    required DateTime createdAt,
    @Default('') String text,

    /// Idempotency key for user messages (null for assistant messages).
    ClientMessageId? clientMessageId,

    /// Tool calls attached to this assistant message, in request order.
    @Default(<ToolCallId>[]) List<ToolCallId> toolCallIds,

    /// Index of the last applied text delta; used to drop duplicates.
    @Default(-1) int lastDeltaIndex,

    /// Stable error code when [status] is [MessageStatus.failed].
    String? errorCode,

    /// Developer-facing error message when failed.
    String? errorMessage,

    /// Whether the user may retry this message (user role, failed/pending).
    @Default(false) bool retryable,
  }) = _ChatMessage;

  /// True while the assistant is still producing this message.
  bool get isInProgress => status == MessageStatus.streaming;

  /// True for terminal statuses.
  bool get isTerminal =>
      status == MessageStatus.completed ||
      status == MessageStatus.failed ||
      status == MessageStatus.cancelled;
}
