import 'package:freezed_annotation/freezed_annotation.dart';

part 'tool_result.freezed.dart';
part 'tool_result.g.dart';

/// Structured result of a backend-executed tool, rendered by the SDK.
///
/// The SDK **renders** these and returns user actions (`ToolAction`); it never
/// executes third-party APIs itself. Every variant is validated by
/// `ToolResultValidator` before it reaches a widget.
///
/// Wire format: `{"kind": "<snake_case_variant>", ...fields}`.
@Freezed(unionKey: 'kind', unionValueCase: FreezedUnionCase.snake)
sealed class ToolResult with _$ToolResult {
  const ToolResult._();

  /// Plain text (markdown subset allowed, rendered as text in this phase).
  const factory ToolResult.text({required String text}) = TextToolResult;

  /// Generic rich card.
  const factory ToolResult.richCard({required RichCard card}) =
      RichCardToolResult;

  /// Restaurant search results.
  const factory ToolResult.restaurants({
    required List<RestaurantResult> items,
    String? query,
  }) = RestaurantsToolResult;

  /// Map with optional route.
  const factory ToolResult.mapRoute({required MapRoute route}) =
      MapRouteToolResult;

  /// Weather snapshot and short forecast.
  const factory ToolResult.weather({required WeatherData weather}) =
      WeatherToolResult;

  /// Video / audio / image items.
  const factory ToolResult.media({required List<MediaItem> items}) =
      MediaToolResult;

  /// A form the user fills in; answered with `ToolAction.formSubmitted`.
  const factory ToolResult.form({required FormSpec form}) = FormToolResult;

  /// A choice the user makes; answered with `ToolAction.optionSelected`.
  const factory ToolResult.selection({required SelectionSpec selection}) =
      SelectionToolResult;

  /// Explicit confirmation of a consequential action;
  /// answered with `ToolAction.confirmed` / `ToolAction.declined`.
  const factory ToolResult.confirmation({
    required ConfirmationSpec confirmation,
  }) = ConfirmationToolResult;

  /// Tool failed; the user may retry via `ToolAction.retryRequested`.
  const factory ToolResult.error({required ToolError error}) = ErrorToolResult;

  /// Deserialises from the wire format. Prefer `ToolResultValidator.parse`,
  /// which never throws.
  factory ToolResult.fromJson(Map<String, Object?> json) =>
      _$ToolResultFromJson(json);
}

/// Generic card payload.
@freezed
abstract class RichCard with _$RichCard {
  const factory RichCard({
    required String title,
    String? subtitle,
    String? body,
    Uri? imageUri,
    @Default(<CardAction>[]) List<CardAction> actions,
  }) = _RichCard;

  factory RichCard.fromJson(Map<String, Object?> json) =>
      _$RichCardFromJson(json);
}

/// Action button on a card. Returned to the backend as
/// `ToolAction.cardActionTapped`.
@freezed
abstract class CardAction with _$CardAction {
  const factory CardAction({
    required String id,
    required String label,
    @Default(false) bool primary,
  }) = _CardAction;

  factory CardAction.fromJson(Map<String, Object?> json) =>
      _$CardActionFromJson(json);
}

/// One restaurant.
@freezed
abstract class RestaurantResult with _$RestaurantResult {
  const factory RestaurantResult({
    required String id,
    required String name,
    String? cuisine,

    /// 0..5
    double? rating,

    /// 1..4 price tier
    int? priceTier,
    String? address,
    double? distanceMeters,
    Uri? imageUri,
    @Default(false) bool openNow,
  }) = _RestaurantResult;

  factory RestaurantResult.fromJson(Map<String, Object?> json) =>
      _$RestaurantResultFromJson(json);
}

/// Geographic point.
@freezed
abstract class GeoPoint with _$GeoPoint {
  const factory GeoPoint({
    required double latitude,
    required double longitude,
  }) = _GeoPoint;

  factory GeoPoint.fromJson(Map<String, Object?> json) =>
      _$GeoPointFromJson(json);
}

/// Route between two points with an optional encoded polyline.
@freezed
abstract class MapRoute with _$MapRoute {
  const factory MapRoute({
    required GeoPoint origin,
    required GeoPoint destination,
    String? originLabel,
    String? destinationLabel,
    double? distanceMeters,
    Duration? duration,

    /// Google-style encoded polyline; decoded by a map widget later.
    String? encodedPolyline,
    @Default(<GeoPoint>[]) List<GeoPoint> waypoints,
  }) = _MapRoute;

  factory MapRoute.fromJson(Map<String, Object?> json) =>
      _$MapRouteFromJson(json);
}

/// Weather snapshot.
@freezed
abstract class WeatherData with _$WeatherData {
  const factory WeatherData({
    required String locationName,
    required double temperatureC,
    required String condition,

    /// Icon key from a fixed vocabulary (e.g. `clear`, `cloudy`, `rain`).
    String? iconKey,
    double? feelsLikeC,
    double? humidityPercent,
    double? windKph,
    @Default(<DailyForecast>[]) List<DailyForecast> forecast,
  }) = _WeatherData;

  factory WeatherData.fromJson(Map<String, Object?> json) =>
      _$WeatherDataFromJson(json);
}

/// One forecast day.
@freezed
abstract class DailyForecast with _$DailyForecast {
  const factory DailyForecast({
    required DateTime date,
    required double highC,
    required double lowC,
    required String condition,
    String? iconKey,
  }) = _DailyForecast;

  factory DailyForecast.fromJson(Map<String, Object?> json) =>
      _$DailyForecastFromJson(json);
}

/// Media type.
@JsonEnum(fieldRename: FieldRename.snake)
enum MediaKind { image, video, audio }

/// A media item. Only `https` URIs are accepted by the validator.
@freezed
abstract class MediaItem with _$MediaItem {
  const factory MediaItem({
    required MediaKind kind,
    required Uri uri,
    String? title,
    Uri? thumbnailUri,
    Duration? duration,
    String? mimeType,
  }) = _MediaItem;

  factory MediaItem.fromJson(Map<String, Object?> json) =>
      _$MediaItemFromJson(json);
}

/// Field types the SDK can render.
@JsonEnum(fieldRename: FieldRename.snake)
enum FormFieldType { text, number, email, phone, date, toggle, select }

/// One form field.
@freezed
abstract class FormFieldSpec with _$FormFieldSpec {
  const factory FormFieldSpec({
    required String id,
    required String label,
    required FormFieldType type,
    @Default(false) bool required,
    String? placeholder,
    String? helperText,

    /// For [FormFieldType.select].
    @Default(<SelectionOption>[]) List<SelectionOption> options,
    Object? defaultValue,
  }) = _FormFieldSpec;

  factory FormFieldSpec.fromJson(Map<String, Object?> json) =>
      _$FormFieldSpecFromJson(json);
}

/// A form.
@freezed
abstract class FormSpec with _$FormSpec {
  const factory FormSpec({
    required String id,
    required String title,
    required List<FormFieldSpec> fields,
    String? description,
    @Default('Submit') String submitLabel,
  }) = _FormSpec;

  factory FormSpec.fromJson(Map<String, Object?> json) =>
      _$FormSpecFromJson(json);
}

/// One selectable option.
@freezed
abstract class SelectionOption with _$SelectionOption {
  const factory SelectionOption({
    required String id,
    required String label,
    String? description,
    Uri? imageUri,
  }) = _SelectionOption;

  factory SelectionOption.fromJson(Map<String, Object?> json) =>
      _$SelectionOptionFromJson(json);
}

/// A selection prompt.
@freezed
abstract class SelectionSpec with _$SelectionSpec {
  const factory SelectionSpec({
    required String id,
    required String prompt,
    required List<SelectionOption> options,
    @Default(false) bool multiSelect,
    @Default(1) int minSelections,
    int? maxSelections,
  }) = _SelectionSpec;

  factory SelectionSpec.fromJson(Map<String, Object?> json) =>
      _$SelectionSpecFromJson(json);
}

/// Risk level shown to the user before they confirm.
@JsonEnum(fieldRename: FieldRename.snake)
enum ConfirmationSeverity { low, medium, high }

/// Explicit confirmation request. Used for consequential actions such as
/// bookings, payments or deletions. The backend must not proceed without the
/// corresponding `ToolAction.confirmed`.
@freezed
abstract class ConfirmationSpec with _$ConfirmationSpec {
  const factory ConfirmationSpec({
    required String id,
    required String title,
    required String description,
    @Default('Confirm') String confirmLabel,
    @Default('Cancel') String declineLabel,
    @Default(ConfirmationSeverity.medium) ConfirmationSeverity severity,

    /// Human-readable summary of what will happen (shown verbatim).
    @Default(<String>[]) List<String> details,
  }) = _ConfirmationSpec;

  factory ConfirmationSpec.fromJson(Map<String, Object?> json) =>
      _$ConfirmationSpecFromJson(json);
}

/// Tool failure description.
@freezed
abstract class ToolError with _$ToolError {
  const factory ToolError({
    required String code,
    required String message,
    @Default(false) bool retryable,
  }) = _ToolError;

  factory ToolError.fromJson(Map<String, Object?> json) =>
      _$ToolErrorFromJson(json);
}
