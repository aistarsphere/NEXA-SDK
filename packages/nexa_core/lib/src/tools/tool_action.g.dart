// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tool_action.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

FormSubmittedAction _$FormSubmittedActionFromJson(Map<String, dynamic> json) =>
    FormSubmittedAction(
      toolCallId: const ToolCallIdConverter().fromJson(
        json['tool_call_id'] as String,
      ),
      formId: json['form_id'] as String,
      values: json['values'] as Map<String, dynamic>,
      $type: json['kind'] as String?,
    );

Map<String, dynamic> _$FormSubmittedActionToJson(
  FormSubmittedAction instance,
) => <String, dynamic>{
  'tool_call_id': const ToolCallIdConverter().toJson(instance.toolCallId),
  'form_id': instance.formId,
  'values': instance.values,
  'kind': instance.$type,
};

OptionSelectedAction _$OptionSelectedActionFromJson(
  Map<String, dynamic> json,
) => OptionSelectedAction(
  toolCallId: const ToolCallIdConverter().fromJson(
    json['tool_call_id'] as String,
  ),
  selectionId: json['selection_id'] as String,
  optionIds: (json['option_ids'] as List<dynamic>)
      .map((e) => e as String)
      .toList(),
  $type: json['kind'] as String?,
);

Map<String, dynamic> _$OptionSelectedActionToJson(
  OptionSelectedAction instance,
) => <String, dynamic>{
  'tool_call_id': const ToolCallIdConverter().toJson(instance.toolCallId),
  'selection_id': instance.selectionId,
  'option_ids': instance.optionIds,
  'kind': instance.$type,
};

ConfirmedAction _$ConfirmedActionFromJson(Map<String, dynamic> json) =>
    ConfirmedAction(
      toolCallId: const ToolCallIdConverter().fromJson(
        json['tool_call_id'] as String,
      ),
      confirmationId: json['confirmation_id'] as String,
      $type: json['kind'] as String?,
    );

Map<String, dynamic> _$ConfirmedActionToJson(ConfirmedAction instance) =>
    <String, dynamic>{
      'tool_call_id': const ToolCallIdConverter().toJson(instance.toolCallId),
      'confirmation_id': instance.confirmationId,
      'kind': instance.$type,
    };

DeclinedAction _$DeclinedActionFromJson(Map<String, dynamic> json) =>
    DeclinedAction(
      toolCallId: const ToolCallIdConverter().fromJson(
        json['tool_call_id'] as String,
      ),
      confirmationId: json['confirmation_id'] as String,
      $type: json['kind'] as String?,
    );

Map<String, dynamic> _$DeclinedActionToJson(DeclinedAction instance) =>
    <String, dynamic>{
      'tool_call_id': const ToolCallIdConverter().toJson(instance.toolCallId),
      'confirmation_id': instance.confirmationId,
      'kind': instance.$type,
    };

CardActionTappedAction _$CardActionTappedActionFromJson(
  Map<String, dynamic> json,
) => CardActionTappedAction(
  toolCallId: const ToolCallIdConverter().fromJson(
    json['tool_call_id'] as String,
  ),
  actionId: json['action_id'] as String,
  $type: json['kind'] as String?,
);

Map<String, dynamic> _$CardActionTappedActionToJson(
  CardActionTappedAction instance,
) => <String, dynamic>{
  'tool_call_id': const ToolCallIdConverter().toJson(instance.toolCallId),
  'action_id': instance.actionId,
  'kind': instance.$type,
};

RetryRequestedAction _$RetryRequestedActionFromJson(
  Map<String, dynamic> json,
) => RetryRequestedAction(
  toolCallId: const ToolCallIdConverter().fromJson(
    json['tool_call_id'] as String,
  ),
  $type: json['kind'] as String?,
);

Map<String, dynamic> _$RetryRequestedActionToJson(
  RetryRequestedAction instance,
) => <String, dynamic>{
  'tool_call_id': const ToolCallIdConverter().toJson(instance.toolCallId),
  'kind': instance.$type,
};
