// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tool_call.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ToolCallRequest _$ToolCallRequestFromJson(Map<String, dynamic> json) =>
    _ToolCallRequest(
      id: const ToolCallIdConverter().fromJson(json['id'] as String),
      toolName: json['tool_name'] as String,
      displayTitle: json['display_title'] as String,
      argumentsSummary: json['arguments_summary'] as String?,
      requiresConfirmation: json['requires_confirmation'] as bool? ?? false,
    );

Map<String, dynamic> _$ToolCallRequestToJson(_ToolCallRequest instance) =>
    <String, dynamic>{
      'id': const ToolCallIdConverter().toJson(instance.id),
      'tool_name': instance.toolName,
      'display_title': instance.displayTitle,
      'arguments_summary': ?instance.argumentsSummary,
      'requires_confirmation': instance.requiresConfirmation,
    };
