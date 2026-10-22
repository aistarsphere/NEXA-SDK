import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:nexa_core/src/ids/ids.dart';
import 'package:nexa_core/src/tools/tool_call.dart';
import 'package:nexa_core/src/tools/tool_result.dart';
import 'package:nexa_core/src/tools/tool_result_validator.dart';

part 'conversation_event.freezed.dart';
part 'conversation_event.g.dart';

/// Why an assistant message stopped.
@JsonEnum(fieldRename: FieldRename.snake)
enum FinishReason { stop, length, cancelled, error, toolCalls }

/// Why a session ended.
@JsonEnum(fieldRename: FieldRename.snake)
enum SessionEndReason { userEnded, expired, serverEnded, quotaExceeded, error }

/// Platform permissions the backend may ask the host to obtain.
@JsonEnum(fieldRename: FieldRename.snake)
enum NexaPermission { microphone, location, camera, notifications }

/// Error attached to an event.
@freezed
abstract class EventError with _$EventError {
  const factory EventError({
    required String code,
    required String message,
    @Default(false) bool retryable,
  }) = _EventError;

  factory EventError.fromJson(Map<String, Object?> json) =>
      _$EventErrorFromJson(json);
}

/// Quota information carried by quota events.
@freezed
abstract class QuotaInfo with _$QuotaInfo {
  const factory QuotaInfo({
    required String kind,
    int? remaining,
    int? limit,
    DateTime? resetsAt,
  }) = _QuotaInfo;

  factory QuotaInfo.fromJson(Map<String, Object?> json) =>
      _$QuotaInfoFromJson(json);
}

/// JSON converter that validates tool results on the way in. A malformed
/// payload becomes `ToolResult.error` instead of crashing deserialisation.
final class _ValidatedToolResultConverter
    implements JsonConverter<ToolResult, Object?> {
  const _ValidatedToolResultConverter();

  static const _validator = ToolResultValidator();

  @override
  ToolResult fromJson(Object? json) =>
      _validator.toRenderable(_validator.parse(json));

  @override
  Object? toJson(ToolResult object) => object.toJson();
}

/// Typed, ordered event emitted by a conversation session.
///
/// ## Identity and ordering
/// * [eventId] is globally unique and is the de-duplication key.
/// * [sequence] is assigned by the gateway, strictly increasing per session,
///   starting at 1. The SDK applies events in sequence order and buffers
///   out-of-order arrivals (see `EventSequencer`).
/// * Text deltas additionally carry a per-message `deltaIndex` starting at 0.
///
/// ## Wire format
/// `{"type": "snake_case_variant", "event_id": ..., "session_id": ...,
///   "sequence": ..., "occurred_at": ..., ...fields}`
@Freezed(unionKey: 'type', unionValueCase: FreezedUnionCase.snake)
sealed class ConversationEvent with _$ConversationEvent {
  const ConversationEvent._();

  /// Gateway accepted the session.
  const factory ConversationEvent.sessionStarted({
    @EventIdConverter() required EventId eventId,
    @SessionIdConverter() required SessionId sessionId,
    required int sequence,
    required DateTime occurredAt,
    required DateTime expiresAt,
  }) = SessionStartedEvent;

  /// Session is over; no further events will follow.
  const factory ConversationEvent.sessionEnded({
    @EventIdConverter() required EventId eventId,
    @SessionIdConverter() required SessionId sessionId,
    required int sequence,
    required DateTime occurredAt,
    required SessionEndReason reason,
  }) = SessionEndedEvent;

  /// Gateway accepted a user message and assigned its server id.
  const factory ConversationEvent.userMessageAccepted({
    @EventIdConverter() required EventId eventId,
    @SessionIdConverter() required SessionId sessionId,
    required int sequence,
    required DateTime occurredAt,
    @MessageIdConverter() required MessageId messageId,
    @ClientMessageIdConverter() required ClientMessageId clientMessageId,
  }) = UserMessageAcceptedEvent;

  /// Gateway rejected a user message (policy, quota, validation).
  const factory ConversationEvent.userMessageRejected({
    @EventIdConverter() required EventId eventId,
    @SessionIdConverter() required SessionId sessionId,
    required int sequence,
    required DateTime occurredAt,
    @ClientMessageIdConverter() required ClientMessageId clientMessageId,
    required EventError error,
  }) = UserMessageRejectedEvent;

  /// Assistant began a reply.
  const factory ConversationEvent.assistantMessageStarted({
    @EventIdConverter() required EventId eventId,
    @SessionIdConverter() required SessionId sessionId,
    required int sequence,
    required DateTime occurredAt,
    @MessageIdConverter() required MessageId messageId,
    @MessageIdConverter() MessageId? inReplyTo,
  }) = AssistantMessageStartedEvent;

  /// Streaming text chunk. [deltaIndex] starts at 0 per message.
  const factory ConversationEvent.assistantTextDelta({
    @EventIdConverter() required EventId eventId,
    @SessionIdConverter() required SessionId sessionId,
    required int sequence,
    required DateTime occurredAt,
    @MessageIdConverter() required MessageId messageId,
    required int deltaIndex,
    required String text,
  }) = AssistantTextDeltaEvent;

  /// Assistant reply finished. When [fullText] is present it is authoritative
  /// and replaces the accumulated deltas (protects against lost deltas).
  const factory ConversationEvent.assistantMessageCompleted({
    @EventIdConverter() required EventId eventId,
    @SessionIdConverter() required SessionId sessionId,
    required int sequence,
    required DateTime occurredAt,
    @MessageIdConverter() required MessageId messageId,
    required FinishReason finishReason,
    String? fullText,
  }) = AssistantMessageCompletedEvent;

  /// A message (user or assistant) failed terminally.
  const factory ConversationEvent.messageFailed({
    @EventIdConverter() required EventId eventId,
    @SessionIdConverter() required SessionId sessionId,
    required int sequence,
    required DateTime occurredAt,
    @MessageIdConverter() required MessageId messageId,
    required EventError error,
  }) = MessageFailedEvent;

  /// Gateway confirmed cancellation of an in-progress message.
  const factory ConversationEvent.messageCancelled({
    @EventIdConverter() required EventId eventId,
    @SessionIdConverter() required SessionId sessionId,
    required int sequence,
    required DateTime occurredAt,
    @MessageIdConverter() required MessageId messageId,
  }) = MessageCancelledEvent;

  /// Assistant requested a backend tool call.
  const factory ConversationEvent.toolCallRequested({
    @EventIdConverter() required EventId eventId,
    @SessionIdConverter() required SessionId sessionId,
    required int sequence,
    required DateTime occurredAt,
    @MessageIdConverter() required MessageId messageId,
    required ToolCallRequest toolCall,
  }) = ToolCallRequestedEvent;

  /// Backend progress on a tool call.
  const factory ConversationEvent.toolExecutionProgress({
    @EventIdConverter() required EventId eventId,
    @SessionIdConverter() required SessionId sessionId,
    required int sequence,
    required DateTime occurredAt,
    @ToolCallIdConverter() required ToolCallId toolCallId,
    required ToolExecutionStatus status,

    /// 0..1 when known.
    double? progress,
    String? message,
  }) = ToolExecutionProgressEvent;

  /// Backend delivered a tool result (already validated on deserialisation).
  const factory ConversationEvent.toolResultReceived({
    @EventIdConverter() required EventId eventId,
    @SessionIdConverter() required SessionId sessionId,
    required int sequence,
    required DateTime occurredAt,
    @ToolCallIdConverter() required ToolCallId toolCallId,
    @MessageIdConverter() required MessageId messageId,
    @_ValidatedToolResultConverter() required ToolResult result,
  }) = ToolResultReceivedEvent;

  /// Backend needs explicit user confirmation before running a tool.
  const factory ConversationEvent.userConfirmationRequested({
    @EventIdConverter() required EventId eventId,
    @SessionIdConverter() required SessionId sessionId,
    required int sequence,
    required DateTime occurredAt,
    @ToolCallIdConverter() required ToolCallId toolCallId,
    required ConfirmationSpec confirmation,
  }) = UserConfirmationRequestedEvent;

  /// Backend asks the host app to obtain a platform permission.
  const factory ConversationEvent.permissionRequested({
    @EventIdConverter() required EventId eventId,
    @SessionIdConverter() required SessionId sessionId,
    required int sequence,
    required DateTime occurredAt,
    required String requestId,
    required NexaPermission permission,
    String? reason,
  }) = PermissionRequestedEvent;

  /// Quota is running low or exhausted.
  const factory ConversationEvent.quotaUpdated({
    @EventIdConverter() required EventId eventId,
    @SessionIdConverter() required SessionId sessionId,
    required int sequence,
    required DateTime occurredAt,
    required QuotaInfo quota,
    @Default(false) bool exceeded,
  }) = QuotaUpdatedEvent;

  /// An event the SDK could not interpret (unknown `type` from a newer
  /// gateway, or a payload that failed validation). Carries only the common
  /// envelope so the sequence cursor still advances; the reducer ignores it.
  /// Built by transports, never sent by the gateway under this name.
  const factory ConversationEvent.unsupported({
    @EventIdConverter() required EventId eventId,
    @SessionIdConverter() required SessionId sessionId,
    required int sequence,
    required DateTime occurredAt,
    @Default('') String originalType,
    String? reason,
  }) = UnsupportedEvent;

  /// Deserialises from the wire format.
  factory ConversationEvent.fromJson(Map<String, Object?> json) =>
      _$ConversationEventFromJson(json);

  /// Parses [json]; when the payload is not a known, valid event but carries
  /// the common envelope, returns [UnsupportedEvent] so ordering is kept.
  /// Returns null when even the envelope is unusable.
  static ConversationEvent? tryParse(Map<String, Object?> json) {
    try {
      return ConversationEvent.fromJson(json);
    } on Object catch (e) {
      final eventId = json['event_id'];
      final sessionId = json['session_id'];
      final sequence = json['sequence'];
      final occurredAt = json['occurred_at'];
      if (eventId is! String ||
          sessionId is! String ||
          sequence is! int ||
          occurredAt is! String) {
        return null;
      }
      final at = DateTime.tryParse(occurredAt);
      if (at == null) return null;
      return ConversationEvent.unsupported(
        eventId: EventId(eventId),
        sessionId: SessionId(sessionId),
        sequence: sequence,
        occurredAt: at,
        originalType: json['type']?.toString() ?? '',
        reason: e.toString(),
      );
    }
  }
}
