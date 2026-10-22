import 'package:freezed_annotation/freezed_annotation.dart';

part 'gateway_dtos.freezed.dart';
part 'gateway_dtos.g.dart';

/// Wire DTOs for the **proposed** NEXA gateway SDK API
/// (`docs/contracts/nexa-gateway-api.proposed.yaml`). Kept separate from the
/// core domain models so the wire format can evolve without touching them.

@freezed
abstract class CreateSessionRequestDto with _$CreateSessionRequestDto {
  const factory CreateSessionRequestDto({
    required String applicationId,
    required List<String> requestedCapabilities,
    required String languageTag,
    @Default(<String, String>{}) Map<String, String> clientMetadata,
    required String sdkVersion,
    required String platform,
  }) = _CreateSessionRequestDto;

  factory CreateSessionRequestDto.fromJson(Map<String, Object?> json) =>
      _$CreateSessionRequestDtoFromJson(json);
}

@freezed
abstract class SessionDto with _$SessionDto {
  const factory SessionDto({
    required String sessionId,
    required DateTime expiresAt,
    required List<String> grantedCapabilities,
    @Default(0) int lastSequence,
  }) = _SessionDto;

  factory SessionDto.fromJson(Map<String, Object?> json) =>
      _$SessionDtoFromJson(json);
}

@freezed
abstract class EventPageDto with _$EventPageDto {
  const factory EventPageDto({
    required List<Map<String, Object?>> events,

    /// Highest sequence included in [events] (or the cursor echoed back).
    required int cursor,

    /// True once the session has ended and no more events will follow.
    @Default(false) bool done,
  }) = _EventPageDto;

  factory EventPageDto.fromJson(Map<String, Object?> json) =>
      _$EventPageDtoFromJson(json);
}

@freezed
abstract class MessageRequestDto with _$MessageRequestDto {
  const factory MessageRequestDto({
    required String clientMessageId,
    required String text,
    String? languageTag,
  }) = _MessageRequestDto;

  factory MessageRequestDto.fromJson(Map<String, Object?> json) =>
      _$MessageRequestDtoFromJson(json);
}

@freezed
abstract class PermissionResultDto with _$PermissionResultDto {
  const factory PermissionResultDto({required bool granted}) =
      _PermissionResultDto;

  factory PermissionResultDto.fromJson(Map<String, Object?> json) =>
      _$PermissionResultDtoFromJson(json);
}

/// Gateway error envelope: `{"error": {"code": ..., "message": ..., "retryable": ...}}`.
@freezed
abstract class GatewayErrorDto with _$GatewayErrorDto {
  const factory GatewayErrorDto({
    required String code,
    required String message,
    @Default(false) bool retryable,
    int? retryAfterSeconds,
    String? quotaKind,
  }) = _GatewayErrorDto;

  factory GatewayErrorDto.fromJson(Map<String, Object?> json) =>
      _$GatewayErrorDtoFromJson(json);
}
