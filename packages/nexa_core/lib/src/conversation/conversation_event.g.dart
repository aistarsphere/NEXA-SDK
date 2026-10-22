// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'conversation_event.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_EventError _$EventErrorFromJson(Map<String, dynamic> json) => _EventError(
  code: json['code'] as String,
  message: json['message'] as String,
  retryable: json['retryable'] as bool? ?? false,
);

Map<String, dynamic> _$EventErrorToJson(_EventError instance) =>
    <String, dynamic>{
      'code': instance.code,
      'message': instance.message,
      'retryable': instance.retryable,
    };

_QuotaInfo _$QuotaInfoFromJson(Map<String, dynamic> json) => _QuotaInfo(
  kind: json['kind'] as String,
  remaining: (json['remaining'] as num?)?.toInt(),
  limit: (json['limit'] as num?)?.toInt(),
  resetsAt: json['resets_at'] == null
      ? null
      : DateTime.parse(json['resets_at'] as String),
);

Map<String, dynamic> _$QuotaInfoToJson(_QuotaInfo instance) =>
    <String, dynamic>{
      'kind': instance.kind,
      'remaining': ?instance.remaining,
      'limit': ?instance.limit,
      'resets_at': ?instance.resetsAt?.toIso8601String(),
    };

SessionStartedEvent _$SessionStartedEventFromJson(Map<String, dynamic> json) =>
    SessionStartedEvent(
      eventId: const EventIdConverter().fromJson(json['event_id'] as String),
      sessionId: const SessionIdConverter().fromJson(
        json['session_id'] as String,
      ),
      sequence: (json['sequence'] as num).toInt(),
      occurredAt: DateTime.parse(json['occurred_at'] as String),
      expiresAt: DateTime.parse(json['expires_at'] as String),
      $type: json['type'] as String?,
    );

Map<String, dynamic> _$SessionStartedEventToJson(
  SessionStartedEvent instance,
) => <String, dynamic>{
  'event_id': const EventIdConverter().toJson(instance.eventId),
  'session_id': const SessionIdConverter().toJson(instance.sessionId),
  'sequence': instance.sequence,
  'occurred_at': instance.occurredAt.toIso8601String(),
  'expires_at': instance.expiresAt.toIso8601String(),
  'type': instance.$type,
};

SessionEndedEvent _$SessionEndedEventFromJson(Map<String, dynamic> json) =>
    SessionEndedEvent(
      eventId: const EventIdConverter().fromJson(json['event_id'] as String),
      sessionId: const SessionIdConverter().fromJson(
        json['session_id'] as String,
      ),
      sequence: (json['sequence'] as num).toInt(),
      occurredAt: DateTime.parse(json['occurred_at'] as String),
      reason: $enumDecode(_$SessionEndReasonEnumMap, json['reason']),
      $type: json['type'] as String?,
    );

Map<String, dynamic> _$SessionEndedEventToJson(SessionEndedEvent instance) =>
    <String, dynamic>{
      'event_id': const EventIdConverter().toJson(instance.eventId),
      'session_id': const SessionIdConverter().toJson(instance.sessionId),
      'sequence': instance.sequence,
      'occurred_at': instance.occurredAt.toIso8601String(),
      'reason': _$SessionEndReasonEnumMap[instance.reason]!,
      'type': instance.$type,
    };

const _$SessionEndReasonEnumMap = {
  SessionEndReason.userEnded: 'user_ended',
  SessionEndReason.expired: 'expired',
  SessionEndReason.serverEnded: 'server_ended',
  SessionEndReason.quotaExceeded: 'quota_exceeded',
  SessionEndReason.error: 'error',
};

UserMessageAcceptedEvent _$UserMessageAcceptedEventFromJson(
  Map<String, dynamic> json,
) => UserMessageAcceptedEvent(
  eventId: const EventIdConverter().fromJson(json['event_id'] as String),
  sessionId: const SessionIdConverter().fromJson(json['session_id'] as String),
  sequence: (json['sequence'] as num).toInt(),
  occurredAt: DateTime.parse(json['occurred_at'] as String),
  messageId: const MessageIdConverter().fromJson(json['message_id'] as String),
  clientMessageId: const ClientMessageIdConverter().fromJson(
    json['client_message_id'] as String,
  ),
  $type: json['type'] as String?,
);

Map<String, dynamic> _$UserMessageAcceptedEventToJson(
  UserMessageAcceptedEvent instance,
) => <String, dynamic>{
  'event_id': const EventIdConverter().toJson(instance.eventId),
  'session_id': const SessionIdConverter().toJson(instance.sessionId),
  'sequence': instance.sequence,
  'occurred_at': instance.occurredAt.toIso8601String(),
  'message_id': const MessageIdConverter().toJson(instance.messageId),
  'client_message_id': const ClientMessageIdConverter().toJson(
    instance.clientMessageId,
  ),
  'type': instance.$type,
};

UserMessageRejectedEvent _$UserMessageRejectedEventFromJson(
  Map<String, dynamic> json,
) => UserMessageRejectedEvent(
  eventId: const EventIdConverter().fromJson(json['event_id'] as String),
  sessionId: const SessionIdConverter().fromJson(json['session_id'] as String),
  sequence: (json['sequence'] as num).toInt(),
  occurredAt: DateTime.parse(json['occurred_at'] as String),
  clientMessageId: const ClientMessageIdConverter().fromJson(
    json['client_message_id'] as String,
  ),
  error: EventError.fromJson(json['error'] as Map<String, dynamic>),
  $type: json['type'] as String?,
);

Map<String, dynamic> _$UserMessageRejectedEventToJson(
  UserMessageRejectedEvent instance,
) => <String, dynamic>{
  'event_id': const EventIdConverter().toJson(instance.eventId),
  'session_id': const SessionIdConverter().toJson(instance.sessionId),
  'sequence': instance.sequence,
  'occurred_at': instance.occurredAt.toIso8601String(),
  'client_message_id': const ClientMessageIdConverter().toJson(
    instance.clientMessageId,
  ),
  'error': instance.error.toJson(),
  'type': instance.$type,
};

AssistantMessageStartedEvent _$AssistantMessageStartedEventFromJson(
  Map<String, dynamic> json,
) => AssistantMessageStartedEvent(
  eventId: const EventIdConverter().fromJson(json['event_id'] as String),
  sessionId: const SessionIdConverter().fromJson(json['session_id'] as String),
  sequence: (json['sequence'] as num).toInt(),
  occurredAt: DateTime.parse(json['occurred_at'] as String),
  messageId: const MessageIdConverter().fromJson(json['message_id'] as String),
  inReplyTo: _$JsonConverterFromJson<String, MessageId>(
    json['in_reply_to'],
    const MessageIdConverter().fromJson,
  ),
  $type: json['type'] as String?,
);

Map<String, dynamic> _$AssistantMessageStartedEventToJson(
  AssistantMessageStartedEvent instance,
) => <String, dynamic>{
  'event_id': const EventIdConverter().toJson(instance.eventId),
  'session_id': const SessionIdConverter().toJson(instance.sessionId),
  'sequence': instance.sequence,
  'occurred_at': instance.occurredAt.toIso8601String(),
  'message_id': const MessageIdConverter().toJson(instance.messageId),
  'in_reply_to': ?_$JsonConverterToJson<String, MessageId>(
    instance.inReplyTo,
    const MessageIdConverter().toJson,
  ),
  'type': instance.$type,
};

Value? _$JsonConverterFromJson<Json, Value>(
  Object? json,
  Value? Function(Json json) fromJson,
) => json == null ? null : fromJson(json as Json);

Json? _$JsonConverterToJson<Json, Value>(
  Value? value,
  Json? Function(Value value) toJson,
) => value == null ? null : toJson(value);

AssistantTextDeltaEvent _$AssistantTextDeltaEventFromJson(
  Map<String, dynamic> json,
) => AssistantTextDeltaEvent(
  eventId: const EventIdConverter().fromJson(json['event_id'] as String),
  sessionId: const SessionIdConverter().fromJson(json['session_id'] as String),
  sequence: (json['sequence'] as num).toInt(),
  occurredAt: DateTime.parse(json['occurred_at'] as String),
  messageId: const MessageIdConverter().fromJson(json['message_id'] as String),
  deltaIndex: (json['delta_index'] as num).toInt(),
  text: json['text'] as String,
  $type: json['type'] as String?,
);

Map<String, dynamic> _$AssistantTextDeltaEventToJson(
  AssistantTextDeltaEvent instance,
) => <String, dynamic>{
  'event_id': const EventIdConverter().toJson(instance.eventId),
  'session_id': const SessionIdConverter().toJson(instance.sessionId),
  'sequence': instance.sequence,
  'occurred_at': instance.occurredAt.toIso8601String(),
  'message_id': const MessageIdConverter().toJson(instance.messageId),
  'delta_index': instance.deltaIndex,
  'text': instance.text,
  'type': instance.$type,
};

AssistantMessageCompletedEvent _$AssistantMessageCompletedEventFromJson(
  Map<String, dynamic> json,
) => AssistantMessageCompletedEvent(
  eventId: const EventIdConverter().fromJson(json['event_id'] as String),
  sessionId: const SessionIdConverter().fromJson(json['session_id'] as String),
  sequence: (json['sequence'] as num).toInt(),
  occurredAt: DateTime.parse(json['occurred_at'] as String),
  messageId: const MessageIdConverter().fromJson(json['message_id'] as String),
  finishReason: $enumDecode(_$FinishReasonEnumMap, json['finish_reason']),
  fullText: json['full_text'] as String?,
  $type: json['type'] as String?,
);

Map<String, dynamic> _$AssistantMessageCompletedEventToJson(
  AssistantMessageCompletedEvent instance,
) => <String, dynamic>{
  'event_id': const EventIdConverter().toJson(instance.eventId),
  'session_id': const SessionIdConverter().toJson(instance.sessionId),
  'sequence': instance.sequence,
  'occurred_at': instance.occurredAt.toIso8601String(),
  'message_id': const MessageIdConverter().toJson(instance.messageId),
  'finish_reason': _$FinishReasonEnumMap[instance.finishReason]!,
  'full_text': ?instance.fullText,
  'type': instance.$type,
};

const _$FinishReasonEnumMap = {
  FinishReason.stop: 'stop',
  FinishReason.length: 'length',
  FinishReason.cancelled: 'cancelled',
  FinishReason.error: 'error',
  FinishReason.toolCalls: 'tool_calls',
};

MessageFailedEvent _$MessageFailedEventFromJson(
  Map<String, dynamic> json,
) => MessageFailedEvent(
  eventId: const EventIdConverter().fromJson(json['event_id'] as String),
  sessionId: const SessionIdConverter().fromJson(json['session_id'] as String),
  sequence: (json['sequence'] as num).toInt(),
  occurredAt: DateTime.parse(json['occurred_at'] as String),
  messageId: const MessageIdConverter().fromJson(json['message_id'] as String),
  error: EventError.fromJson(json['error'] as Map<String, dynamic>),
  $type: json['type'] as String?,
);

Map<String, dynamic> _$MessageFailedEventToJson(MessageFailedEvent instance) =>
    <String, dynamic>{
      'event_id': const EventIdConverter().toJson(instance.eventId),
      'session_id': const SessionIdConverter().toJson(instance.sessionId),
      'sequence': instance.sequence,
      'occurred_at': instance.occurredAt.toIso8601String(),
      'message_id': const MessageIdConverter().toJson(instance.messageId),
      'error': instance.error.toJson(),
      'type': instance.$type,
    };

MessageCancelledEvent _$MessageCancelledEventFromJson(
  Map<String, dynamic> json,
) => MessageCancelledEvent(
  eventId: const EventIdConverter().fromJson(json['event_id'] as String),
  sessionId: const SessionIdConverter().fromJson(json['session_id'] as String),
  sequence: (json['sequence'] as num).toInt(),
  occurredAt: DateTime.parse(json['occurred_at'] as String),
  messageId: const MessageIdConverter().fromJson(json['message_id'] as String),
  $type: json['type'] as String?,
);

Map<String, dynamic> _$MessageCancelledEventToJson(
  MessageCancelledEvent instance,
) => <String, dynamic>{
  'event_id': const EventIdConverter().toJson(instance.eventId),
  'session_id': const SessionIdConverter().toJson(instance.sessionId),
  'sequence': instance.sequence,
  'occurred_at': instance.occurredAt.toIso8601String(),
  'message_id': const MessageIdConverter().toJson(instance.messageId),
  'type': instance.$type,
};

ToolCallRequestedEvent _$ToolCallRequestedEventFromJson(
  Map<String, dynamic> json,
) => ToolCallRequestedEvent(
  eventId: const EventIdConverter().fromJson(json['event_id'] as String),
  sessionId: const SessionIdConverter().fromJson(json['session_id'] as String),
  sequence: (json['sequence'] as num).toInt(),
  occurredAt: DateTime.parse(json['occurred_at'] as String),
  messageId: const MessageIdConverter().fromJson(json['message_id'] as String),
  toolCall: ToolCallRequest.fromJson(json['tool_call'] as Map<String, dynamic>),
  $type: json['type'] as String?,
);

Map<String, dynamic> _$ToolCallRequestedEventToJson(
  ToolCallRequestedEvent instance,
) => <String, dynamic>{
  'event_id': const EventIdConverter().toJson(instance.eventId),
  'session_id': const SessionIdConverter().toJson(instance.sessionId),
  'sequence': instance.sequence,
  'occurred_at': instance.occurredAt.toIso8601String(),
  'message_id': const MessageIdConverter().toJson(instance.messageId),
  'tool_call': instance.toolCall.toJson(),
  'type': instance.$type,
};

ToolExecutionProgressEvent _$ToolExecutionProgressEventFromJson(
  Map<String, dynamic> json,
) => ToolExecutionProgressEvent(
  eventId: const EventIdConverter().fromJson(json['event_id'] as String),
  sessionId: const SessionIdConverter().fromJson(json['session_id'] as String),
  sequence: (json['sequence'] as num).toInt(),
  occurredAt: DateTime.parse(json['occurred_at'] as String),
  toolCallId: const ToolCallIdConverter().fromJson(
    json['tool_call_id'] as String,
  ),
  status: $enumDecode(_$ToolExecutionStatusEnumMap, json['status']),
  progress: (json['progress'] as num?)?.toDouble(),
  message: json['message'] as String?,
  $type: json['type'] as String?,
);

Map<String, dynamic> _$ToolExecutionProgressEventToJson(
  ToolExecutionProgressEvent instance,
) => <String, dynamic>{
  'event_id': const EventIdConverter().toJson(instance.eventId),
  'session_id': const SessionIdConverter().toJson(instance.sessionId),
  'sequence': instance.sequence,
  'occurred_at': instance.occurredAt.toIso8601String(),
  'tool_call_id': const ToolCallIdConverter().toJson(instance.toolCallId),
  'status': _$ToolExecutionStatusEnumMap[instance.status]!,
  'progress': ?instance.progress,
  'message': ?instance.message,
  'type': instance.$type,
};

const _$ToolExecutionStatusEnumMap = {
  ToolExecutionStatus.requested: 'requested',
  ToolExecutionStatus.awaitingConfirmation: 'awaiting_confirmation',
  ToolExecutionStatus.running: 'running',
  ToolExecutionStatus.succeeded: 'succeeded',
  ToolExecutionStatus.failed: 'failed',
  ToolExecutionStatus.cancelled: 'cancelled',
};

ToolResultReceivedEvent _$ToolResultReceivedEventFromJson(
  Map<String, dynamic> json,
) => ToolResultReceivedEvent(
  eventId: const EventIdConverter().fromJson(json['event_id'] as String),
  sessionId: const SessionIdConverter().fromJson(json['session_id'] as String),
  sequence: (json['sequence'] as num).toInt(),
  occurredAt: DateTime.parse(json['occurred_at'] as String),
  toolCallId: const ToolCallIdConverter().fromJson(
    json['tool_call_id'] as String,
  ),
  messageId: const MessageIdConverter().fromJson(json['message_id'] as String),
  result: const _ValidatedToolResultConverter().fromJson(json['result']),
  $type: json['type'] as String?,
);

Map<String, dynamic> _$ToolResultReceivedEventToJson(
  ToolResultReceivedEvent instance,
) => <String, dynamic>{
  'event_id': const EventIdConverter().toJson(instance.eventId),
  'session_id': const SessionIdConverter().toJson(instance.sessionId),
  'sequence': instance.sequence,
  'occurred_at': instance.occurredAt.toIso8601String(),
  'tool_call_id': const ToolCallIdConverter().toJson(instance.toolCallId),
  'message_id': const MessageIdConverter().toJson(instance.messageId),
  'result': ?const _ValidatedToolResultConverter().toJson(instance.result),
  'type': instance.$type,
};

UserConfirmationRequestedEvent _$UserConfirmationRequestedEventFromJson(
  Map<String, dynamic> json,
) => UserConfirmationRequestedEvent(
  eventId: const EventIdConverter().fromJson(json['event_id'] as String),
  sessionId: const SessionIdConverter().fromJson(json['session_id'] as String),
  sequence: (json['sequence'] as num).toInt(),
  occurredAt: DateTime.parse(json['occurred_at'] as String),
  toolCallId: const ToolCallIdConverter().fromJson(
    json['tool_call_id'] as String,
  ),
  confirmation: ConfirmationSpec.fromJson(
    json['confirmation'] as Map<String, dynamic>,
  ),
  $type: json['type'] as String?,
);

Map<String, dynamic> _$UserConfirmationRequestedEventToJson(
  UserConfirmationRequestedEvent instance,
) => <String, dynamic>{
  'event_id': const EventIdConverter().toJson(instance.eventId),
  'session_id': const SessionIdConverter().toJson(instance.sessionId),
  'sequence': instance.sequence,
  'occurred_at': instance.occurredAt.toIso8601String(),
  'tool_call_id': const ToolCallIdConverter().toJson(instance.toolCallId),
  'confirmation': instance.confirmation.toJson(),
  'type': instance.$type,
};

PermissionRequestedEvent _$PermissionRequestedEventFromJson(
  Map<String, dynamic> json,
) => PermissionRequestedEvent(
  eventId: const EventIdConverter().fromJson(json['event_id'] as String),
  sessionId: const SessionIdConverter().fromJson(json['session_id'] as String),
  sequence: (json['sequence'] as num).toInt(),
  occurredAt: DateTime.parse(json['occurred_at'] as String),
  requestId: json['request_id'] as String,
  permission: $enumDecode(_$NexaPermissionEnumMap, json['permission']),
  reason: json['reason'] as String?,
  $type: json['type'] as String?,
);

Map<String, dynamic> _$PermissionRequestedEventToJson(
  PermissionRequestedEvent instance,
) => <String, dynamic>{
  'event_id': const EventIdConverter().toJson(instance.eventId),
  'session_id': const SessionIdConverter().toJson(instance.sessionId),
  'sequence': instance.sequence,
  'occurred_at': instance.occurredAt.toIso8601String(),
  'request_id': instance.requestId,
  'permission': _$NexaPermissionEnumMap[instance.permission]!,
  'reason': ?instance.reason,
  'type': instance.$type,
};

const _$NexaPermissionEnumMap = {
  NexaPermission.microphone: 'microphone',
  NexaPermission.location: 'location',
  NexaPermission.camera: 'camera',
  NexaPermission.notifications: 'notifications',
};

QuotaUpdatedEvent _$QuotaUpdatedEventFromJson(Map<String, dynamic> json) =>
    QuotaUpdatedEvent(
      eventId: const EventIdConverter().fromJson(json['event_id'] as String),
      sessionId: const SessionIdConverter().fromJson(
        json['session_id'] as String,
      ),
      sequence: (json['sequence'] as num).toInt(),
      occurredAt: DateTime.parse(json['occurred_at'] as String),
      quota: QuotaInfo.fromJson(json['quota'] as Map<String, dynamic>),
      exceeded: json['exceeded'] as bool? ?? false,
      $type: json['type'] as String?,
    );

Map<String, dynamic> _$QuotaUpdatedEventToJson(QuotaUpdatedEvent instance) =>
    <String, dynamic>{
      'event_id': const EventIdConverter().toJson(instance.eventId),
      'session_id': const SessionIdConverter().toJson(instance.sessionId),
      'sequence': instance.sequence,
      'occurred_at': instance.occurredAt.toIso8601String(),
      'quota': instance.quota.toJson(),
      'exceeded': instance.exceeded,
      'type': instance.$type,
    };

UnsupportedEvent _$UnsupportedEventFromJson(Map<String, dynamic> json) =>
    UnsupportedEvent(
      eventId: const EventIdConverter().fromJson(json['event_id'] as String),
      sessionId: const SessionIdConverter().fromJson(
        json['session_id'] as String,
      ),
      sequence: (json['sequence'] as num).toInt(),
      occurredAt: DateTime.parse(json['occurred_at'] as String),
      originalType: json['original_type'] as String? ?? '',
      reason: json['reason'] as String?,
      $type: json['type'] as String?,
    );

Map<String, dynamic> _$UnsupportedEventToJson(UnsupportedEvent instance) =>
    <String, dynamic>{
      'event_id': const EventIdConverter().toJson(instance.eventId),
      'session_id': const SessionIdConverter().toJson(instance.sessionId),
      'sequence': instance.sequence,
      'occurred_at': instance.occurredAt.toIso8601String(),
      'original_type': instance.originalType,
      'reason': ?instance.reason,
      'type': instance.$type,
    };
