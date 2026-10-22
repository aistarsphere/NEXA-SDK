import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:nexa_core/src/ids/ids.dart';

part 'tool_call.freezed.dart';
part 'tool_call.g.dart';

/// Lifecycle of a tool call as reported by the backend.
@JsonEnum(fieldRename: FieldRename.snake)
enum ToolExecutionStatus {
  requested,
  awaitingConfirmation,
  running,
  succeeded,
  failed,
  cancelled,
}

/// A tool call the assistant asked the backend to run. The SDK shows it to the
/// user; execution happens server-side.
@freezed
abstract class ToolCallRequest with _$ToolCallRequest {
  const factory ToolCallRequest({
    @ToolCallIdConverter() required ToolCallId id,

    /// Backend tool name (e.g. `restaurants.search`). Not shown raw to users.
    required String toolName,

    /// Localised, user-facing title supplied by the backend.
    required String displayTitle,

    /// Optional short, user-safe summary of the arguments.
    String? argumentsSummary,

    /// Whether the backend will wait for explicit user confirmation.
    @Default(false) bool requiresConfirmation,
  }) = _ToolCallRequest;

  factory ToolCallRequest.fromJson(Map<String, Object?> json) =>
      _$ToolCallRequestFromJson(json);
}
