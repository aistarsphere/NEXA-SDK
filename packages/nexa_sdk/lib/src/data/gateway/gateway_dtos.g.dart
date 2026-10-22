// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'gateway_dtos.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_CreateSessionRequestDto _$CreateSessionRequestDtoFromJson(
  Map<String, dynamic> json,
) => _CreateSessionRequestDto(
  applicationId: json['application_id'] as String,
  requestedCapabilities: (json['requested_capabilities'] as List<dynamic>)
      .map((e) => e as String)
      .toList(),
  languageTag: json['language_tag'] as String,
  clientMetadata:
      (json['client_metadata'] as Map<String, dynamic>?)?.map(
        (k, e) => MapEntry(k, e as String),
      ) ??
      const <String, String>{},
  sdkVersion: json['sdk_version'] as String,
  platform: json['platform'] as String,
);

Map<String, dynamic> _$CreateSessionRequestDtoToJson(
  _CreateSessionRequestDto instance,
) => <String, dynamic>{
  'application_id': instance.applicationId,
  'requested_capabilities': instance.requestedCapabilities,
  'language_tag': instance.languageTag,
  'client_metadata': instance.clientMetadata,
  'sdk_version': instance.sdkVersion,
  'platform': instance.platform,
};

_SessionDto _$SessionDtoFromJson(Map<String, dynamic> json) => _SessionDto(
  sessionId: json['session_id'] as String,
  expiresAt: DateTime.parse(json['expires_at'] as String),
  grantedCapabilities: (json['granted_capabilities'] as List<dynamic>)
      .map((e) => e as String)
      .toList(),
  lastSequence: (json['last_sequence'] as num?)?.toInt() ?? 0,
);

Map<String, dynamic> _$SessionDtoToJson(_SessionDto instance) =>
    <String, dynamic>{
      'session_id': instance.sessionId,
      'expires_at': instance.expiresAt.toIso8601String(),
      'granted_capabilities': instance.grantedCapabilities,
      'last_sequence': instance.lastSequence,
    };

_EventPageDto _$EventPageDtoFromJson(Map<String, dynamic> json) =>
    _EventPageDto(
      events: (json['events'] as List<dynamic>)
          .map((e) => e as Map<String, dynamic>)
          .toList(),
      cursor: (json['cursor'] as num).toInt(),
      done: json['done'] as bool? ?? false,
    );

Map<String, dynamic> _$EventPageDtoToJson(_EventPageDto instance) =>
    <String, dynamic>{
      'events': instance.events,
      'cursor': instance.cursor,
      'done': instance.done,
    };

_MessageRequestDto _$MessageRequestDtoFromJson(Map<String, dynamic> json) =>
    _MessageRequestDto(
      clientMessageId: json['client_message_id'] as String,
      text: json['text'] as String,
      languageTag: json['language_tag'] as String?,
    );

Map<String, dynamic> _$MessageRequestDtoToJson(_MessageRequestDto instance) =>
    <String, dynamic>{
      'client_message_id': instance.clientMessageId,
      'text': instance.text,
      'language_tag': ?instance.languageTag,
    };

_PermissionResultDto _$PermissionResultDtoFromJson(Map<String, dynamic> json) =>
    _PermissionResultDto(granted: json['granted'] as bool);

Map<String, dynamic> _$PermissionResultDtoToJson(
  _PermissionResultDto instance,
) => <String, dynamic>{'granted': instance.granted};

_GatewayErrorDto _$GatewayErrorDtoFromJson(Map<String, dynamic> json) =>
    _GatewayErrorDto(
      code: json['code'] as String,
      message: json['message'] as String,
      retryable: json['retryable'] as bool? ?? false,
      retryAfterSeconds: (json['retry_after_seconds'] as num?)?.toInt(),
      quotaKind: json['quota_kind'] as String?,
    );

Map<String, dynamic> _$GatewayErrorDtoToJson(_GatewayErrorDto instance) =>
    <String, dynamic>{
      'code': instance.code,
      'message': instance.message,
      'retryable': instance.retryable,
      'retry_after_seconds': ?instance.retryAfterSeconds,
      'quota_kind': ?instance.quotaKind,
    };
