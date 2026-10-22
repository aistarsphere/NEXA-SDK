import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:nexa_core/src/ids/ids.dart';

part 'tool_action.freezed.dart';
part 'tool_action.g.dart';

/// An authorised user action returned to the backend in response to a
/// rendered `ToolResult`. The backend validates every action again; the SDK
/// never grants permissions on its own.
///
/// Wire format: `{"kind": "<snake_case_variant>", ...fields}`.
@Freezed(unionKey: 'kind', unionValueCase: FreezedUnionCase.snake)
sealed class ToolAction with _$ToolAction {
  const ToolAction._();

  /// User submitted a form. Keys are `FormFieldSpec.id`.
  const factory ToolAction.formSubmitted({
    @ToolCallIdConverter() required ToolCallId toolCallId,
    required String formId,
    required Map<String, Object?> values,
  }) = FormSubmittedAction;

  /// User chose one or more options.
  const factory ToolAction.optionSelected({
    @ToolCallIdConverter() required ToolCallId toolCallId,
    required String selectionId,
    required List<String> optionIds,
  }) = OptionSelectedAction;

  /// User explicitly confirmed a consequential action.
  const factory ToolAction.confirmed({
    @ToolCallIdConverter() required ToolCallId toolCallId,
    required String confirmationId,
  }) = ConfirmedAction;

  /// User declined.
  const factory ToolAction.declined({
    @ToolCallIdConverter() required ToolCallId toolCallId,
    required String confirmationId,
  }) = DeclinedAction;

  /// User tapped a card action button.
  const factory ToolAction.cardActionTapped({
    @ToolCallIdConverter() required ToolCallId toolCallId,
    required String actionId,
  }) = CardActionTappedAction;

  /// User asked to retry a failed tool.
  const factory ToolAction.retryRequested({
    @ToolCallIdConverter() required ToolCallId toolCallId,
  }) = RetryRequestedAction;

  /// Deserialises from the wire format.
  factory ToolAction.fromJson(Map<String, Object?> json) =>
      _$ToolActionFromJson(json);
}
