// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tool_result.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TextToolResult _$TextToolResultFromJson(Map<String, dynamic> json) =>
    TextToolResult(
      text: json['text'] as String,
      $type: json['kind'] as String?,
    );

Map<String, dynamic> _$TextToolResultToJson(TextToolResult instance) =>
    <String, dynamic>{'text': instance.text, 'kind': instance.$type};

RichCardToolResult _$RichCardToolResultFromJson(Map<String, dynamic> json) =>
    RichCardToolResult(
      card: RichCard.fromJson(json['card'] as Map<String, dynamic>),
      $type: json['kind'] as String?,
    );

Map<String, dynamic> _$RichCardToolResultToJson(RichCardToolResult instance) =>
    <String, dynamic>{'card': instance.card.toJson(), 'kind': instance.$type};

RestaurantsToolResult _$RestaurantsToolResultFromJson(
  Map<String, dynamic> json,
) => RestaurantsToolResult(
  items: (json['items'] as List<dynamic>)
      .map((e) => RestaurantResult.fromJson(e as Map<String, dynamic>))
      .toList(),
  query: json['query'] as String?,
  $type: json['kind'] as String?,
);

Map<String, dynamic> _$RestaurantsToolResultToJson(
  RestaurantsToolResult instance,
) => <String, dynamic>{
  'items': instance.items.map((e) => e.toJson()).toList(),
  'query': ?instance.query,
  'kind': instance.$type,
};

MapRouteToolResult _$MapRouteToolResultFromJson(Map<String, dynamic> json) =>
    MapRouteToolResult(
      route: MapRoute.fromJson(json['route'] as Map<String, dynamic>),
      $type: json['kind'] as String?,
    );

Map<String, dynamic> _$MapRouteToolResultToJson(MapRouteToolResult instance) =>
    <String, dynamic>{'route': instance.route.toJson(), 'kind': instance.$type};

WeatherToolResult _$WeatherToolResultFromJson(Map<String, dynamic> json) =>
    WeatherToolResult(
      weather: WeatherData.fromJson(json['weather'] as Map<String, dynamic>),
      $type: json['kind'] as String?,
    );

Map<String, dynamic> _$WeatherToolResultToJson(WeatherToolResult instance) =>
    <String, dynamic>{
      'weather': instance.weather.toJson(),
      'kind': instance.$type,
    };

MediaToolResult _$MediaToolResultFromJson(Map<String, dynamic> json) =>
    MediaToolResult(
      items: (json['items'] as List<dynamic>)
          .map((e) => MediaItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      $type: json['kind'] as String?,
    );

Map<String, dynamic> _$MediaToolResultToJson(MediaToolResult instance) =>
    <String, dynamic>{
      'items': instance.items.map((e) => e.toJson()).toList(),
      'kind': instance.$type,
    };

FormToolResult _$FormToolResultFromJson(Map<String, dynamic> json) =>
    FormToolResult(
      form: FormSpec.fromJson(json['form'] as Map<String, dynamic>),
      $type: json['kind'] as String?,
    );

Map<String, dynamic> _$FormToolResultToJson(FormToolResult instance) =>
    <String, dynamic>{'form': instance.form.toJson(), 'kind': instance.$type};

SelectionToolResult _$SelectionToolResultFromJson(Map<String, dynamic> json) =>
    SelectionToolResult(
      selection: SelectionSpec.fromJson(
        json['selection'] as Map<String, dynamic>,
      ),
      $type: json['kind'] as String?,
    );

Map<String, dynamic> _$SelectionToolResultToJson(
  SelectionToolResult instance,
) => <String, dynamic>{
  'selection': instance.selection.toJson(),
  'kind': instance.$type,
};

ConfirmationToolResult _$ConfirmationToolResultFromJson(
  Map<String, dynamic> json,
) => ConfirmationToolResult(
  confirmation: ConfirmationSpec.fromJson(
    json['confirmation'] as Map<String, dynamic>,
  ),
  $type: json['kind'] as String?,
);

Map<String, dynamic> _$ConfirmationToolResultToJson(
  ConfirmationToolResult instance,
) => <String, dynamic>{
  'confirmation': instance.confirmation.toJson(),
  'kind': instance.$type,
};

ErrorToolResult _$ErrorToolResultFromJson(Map<String, dynamic> json) =>
    ErrorToolResult(
      error: ToolError.fromJson(json['error'] as Map<String, dynamic>),
      $type: json['kind'] as String?,
    );

Map<String, dynamic> _$ErrorToolResultToJson(ErrorToolResult instance) =>
    <String, dynamic>{'error': instance.error.toJson(), 'kind': instance.$type};

_RichCard _$RichCardFromJson(Map<String, dynamic> json) => _RichCard(
  title: json['title'] as String,
  subtitle: json['subtitle'] as String?,
  body: json['body'] as String?,
  imageUri: json['image_uri'] == null
      ? null
      : Uri.parse(json['image_uri'] as String),
  actions:
      (json['actions'] as List<dynamic>?)
          ?.map((e) => CardAction.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const <CardAction>[],
);

Map<String, dynamic> _$RichCardToJson(_RichCard instance) => <String, dynamic>{
  'title': instance.title,
  'subtitle': ?instance.subtitle,
  'body': ?instance.body,
  'image_uri': ?instance.imageUri?.toString(),
  'actions': instance.actions.map((e) => e.toJson()).toList(),
};

_CardAction _$CardActionFromJson(Map<String, dynamic> json) => _CardAction(
  id: json['id'] as String,
  label: json['label'] as String,
  primary: json['primary'] as bool? ?? false,
);

Map<String, dynamic> _$CardActionToJson(_CardAction instance) =>
    <String, dynamic>{
      'id': instance.id,
      'label': instance.label,
      'primary': instance.primary,
    };

_RestaurantResult _$RestaurantResultFromJson(Map<String, dynamic> json) =>
    _RestaurantResult(
      id: json['id'] as String,
      name: json['name'] as String,
      cuisine: json['cuisine'] as String?,
      rating: (json['rating'] as num?)?.toDouble(),
      priceTier: (json['price_tier'] as num?)?.toInt(),
      address: json['address'] as String?,
      distanceMeters: (json['distance_meters'] as num?)?.toDouble(),
      imageUri: json['image_uri'] == null
          ? null
          : Uri.parse(json['image_uri'] as String),
      openNow: json['open_now'] as bool? ?? false,
    );

Map<String, dynamic> _$RestaurantResultToJson(_RestaurantResult instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'cuisine': ?instance.cuisine,
      'rating': ?instance.rating,
      'price_tier': ?instance.priceTier,
      'address': ?instance.address,
      'distance_meters': ?instance.distanceMeters,
      'image_uri': ?instance.imageUri?.toString(),
      'open_now': instance.openNow,
    };

_GeoPoint _$GeoPointFromJson(Map<String, dynamic> json) => _GeoPoint(
  latitude: (json['latitude'] as num).toDouble(),
  longitude: (json['longitude'] as num).toDouble(),
);

Map<String, dynamic> _$GeoPointToJson(_GeoPoint instance) => <String, dynamic>{
  'latitude': instance.latitude,
  'longitude': instance.longitude,
};

_MapRoute _$MapRouteFromJson(Map<String, dynamic> json) => _MapRoute(
  origin: GeoPoint.fromJson(json['origin'] as Map<String, dynamic>),
  destination: GeoPoint.fromJson(json['destination'] as Map<String, dynamic>),
  originLabel: json['origin_label'] as String?,
  destinationLabel: json['destination_label'] as String?,
  distanceMeters: (json['distance_meters'] as num?)?.toDouble(),
  duration: json['duration'] == null
      ? null
      : Duration(microseconds: (json['duration'] as num).toInt()),
  encodedPolyline: json['encoded_polyline'] as String?,
  waypoints:
      (json['waypoints'] as List<dynamic>?)
          ?.map((e) => GeoPoint.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const <GeoPoint>[],
);

Map<String, dynamic> _$MapRouteToJson(_MapRoute instance) => <String, dynamic>{
  'origin': instance.origin.toJson(),
  'destination': instance.destination.toJson(),
  'origin_label': ?instance.originLabel,
  'destination_label': ?instance.destinationLabel,
  'distance_meters': ?instance.distanceMeters,
  'duration': ?instance.duration?.inMicroseconds,
  'encoded_polyline': ?instance.encodedPolyline,
  'waypoints': instance.waypoints.map((e) => e.toJson()).toList(),
};

_WeatherData _$WeatherDataFromJson(Map<String, dynamic> json) => _WeatherData(
  locationName: json['location_name'] as String,
  temperatureC: (json['temperature_c'] as num).toDouble(),
  condition: json['condition'] as String,
  iconKey: json['icon_key'] as String?,
  feelsLikeC: (json['feels_like_c'] as num?)?.toDouble(),
  humidityPercent: (json['humidity_percent'] as num?)?.toDouble(),
  windKph: (json['wind_kph'] as num?)?.toDouble(),
  forecast:
      (json['forecast'] as List<dynamic>?)
          ?.map((e) => DailyForecast.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const <DailyForecast>[],
);

Map<String, dynamic> _$WeatherDataToJson(_WeatherData instance) =>
    <String, dynamic>{
      'location_name': instance.locationName,
      'temperature_c': instance.temperatureC,
      'condition': instance.condition,
      'icon_key': ?instance.iconKey,
      'feels_like_c': ?instance.feelsLikeC,
      'humidity_percent': ?instance.humidityPercent,
      'wind_kph': ?instance.windKph,
      'forecast': instance.forecast.map((e) => e.toJson()).toList(),
    };

_DailyForecast _$DailyForecastFromJson(Map<String, dynamic> json) =>
    _DailyForecast(
      date: DateTime.parse(json['date'] as String),
      highC: (json['high_c'] as num).toDouble(),
      lowC: (json['low_c'] as num).toDouble(),
      condition: json['condition'] as String,
      iconKey: json['icon_key'] as String?,
    );

Map<String, dynamic> _$DailyForecastToJson(_DailyForecast instance) =>
    <String, dynamic>{
      'date': instance.date.toIso8601String(),
      'high_c': instance.highC,
      'low_c': instance.lowC,
      'condition': instance.condition,
      'icon_key': ?instance.iconKey,
    };

_MediaItem _$MediaItemFromJson(Map<String, dynamic> json) => _MediaItem(
  kind: $enumDecode(_$MediaKindEnumMap, json['kind']),
  uri: Uri.parse(json['uri'] as String),
  title: json['title'] as String?,
  thumbnailUri: json['thumbnail_uri'] == null
      ? null
      : Uri.parse(json['thumbnail_uri'] as String),
  duration: json['duration'] == null
      ? null
      : Duration(microseconds: (json['duration'] as num).toInt()),
  mimeType: json['mime_type'] as String?,
);

Map<String, dynamic> _$MediaItemToJson(_MediaItem instance) =>
    <String, dynamic>{
      'kind': _$MediaKindEnumMap[instance.kind]!,
      'uri': instance.uri.toString(),
      'title': ?instance.title,
      'thumbnail_uri': ?instance.thumbnailUri?.toString(),
      'duration': ?instance.duration?.inMicroseconds,
      'mime_type': ?instance.mimeType,
    };

const _$MediaKindEnumMap = {
  MediaKind.image: 'image',
  MediaKind.video: 'video',
  MediaKind.audio: 'audio',
};

_FormFieldSpec _$FormFieldSpecFromJson(Map<String, dynamic> json) =>
    _FormFieldSpec(
      id: json['id'] as String,
      label: json['label'] as String,
      type: $enumDecode(_$FormFieldTypeEnumMap, json['type']),
      required: json['required'] as bool? ?? false,
      placeholder: json['placeholder'] as String?,
      helperText: json['helper_text'] as String?,
      options:
          (json['options'] as List<dynamic>?)
              ?.map((e) => SelectionOption.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <SelectionOption>[],
      defaultValue: json['default_value'],
    );

Map<String, dynamic> _$FormFieldSpecToJson(_FormFieldSpec instance) =>
    <String, dynamic>{
      'id': instance.id,
      'label': instance.label,
      'type': _$FormFieldTypeEnumMap[instance.type]!,
      'required': instance.required,
      'placeholder': ?instance.placeholder,
      'helper_text': ?instance.helperText,
      'options': instance.options.map((e) => e.toJson()).toList(),
      'default_value': ?instance.defaultValue,
    };

const _$FormFieldTypeEnumMap = {
  FormFieldType.text: 'text',
  FormFieldType.number: 'number',
  FormFieldType.email: 'email',
  FormFieldType.phone: 'phone',
  FormFieldType.date: 'date',
  FormFieldType.toggle: 'toggle',
  FormFieldType.select: 'select',
};

_FormSpec _$FormSpecFromJson(Map<String, dynamic> json) => _FormSpec(
  id: json['id'] as String,
  title: json['title'] as String,
  fields: (json['fields'] as List<dynamic>)
      .map((e) => FormFieldSpec.fromJson(e as Map<String, dynamic>))
      .toList(),
  description: json['description'] as String?,
  submitLabel: json['submit_label'] as String? ?? 'Submit',
);

Map<String, dynamic> _$FormSpecToJson(_FormSpec instance) => <String, dynamic>{
  'id': instance.id,
  'title': instance.title,
  'fields': instance.fields.map((e) => e.toJson()).toList(),
  'description': ?instance.description,
  'submit_label': instance.submitLabel,
};

_SelectionOption _$SelectionOptionFromJson(Map<String, dynamic> json) =>
    _SelectionOption(
      id: json['id'] as String,
      label: json['label'] as String,
      description: json['description'] as String?,
      imageUri: json['image_uri'] == null
          ? null
          : Uri.parse(json['image_uri'] as String),
    );

Map<String, dynamic> _$SelectionOptionToJson(_SelectionOption instance) =>
    <String, dynamic>{
      'id': instance.id,
      'label': instance.label,
      'description': ?instance.description,
      'image_uri': ?instance.imageUri?.toString(),
    };

_SelectionSpec _$SelectionSpecFromJson(Map<String, dynamic> json) =>
    _SelectionSpec(
      id: json['id'] as String,
      prompt: json['prompt'] as String,
      options: (json['options'] as List<dynamic>)
          .map((e) => SelectionOption.fromJson(e as Map<String, dynamic>))
          .toList(),
      multiSelect: json['multi_select'] as bool? ?? false,
      minSelections: (json['min_selections'] as num?)?.toInt() ?? 1,
      maxSelections: (json['max_selections'] as num?)?.toInt(),
    );

Map<String, dynamic> _$SelectionSpecToJson(_SelectionSpec instance) =>
    <String, dynamic>{
      'id': instance.id,
      'prompt': instance.prompt,
      'options': instance.options.map((e) => e.toJson()).toList(),
      'multi_select': instance.multiSelect,
      'min_selections': instance.minSelections,
      'max_selections': ?instance.maxSelections,
    };

_ConfirmationSpec _$ConfirmationSpecFromJson(
  Map<String, dynamic> json,
) => _ConfirmationSpec(
  id: json['id'] as String,
  title: json['title'] as String,
  description: json['description'] as String,
  confirmLabel: json['confirm_label'] as String? ?? 'Confirm',
  declineLabel: json['decline_label'] as String? ?? 'Cancel',
  severity:
      $enumDecodeNullable(_$ConfirmationSeverityEnumMap, json['severity']) ??
      ConfirmationSeverity.medium,
  details:
      (json['details'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const <String>[],
);

Map<String, dynamic> _$ConfirmationSpecToJson(_ConfirmationSpec instance) =>
    <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'description': instance.description,
      'confirm_label': instance.confirmLabel,
      'decline_label': instance.declineLabel,
      'severity': _$ConfirmationSeverityEnumMap[instance.severity]!,
      'details': instance.details,
    };

const _$ConfirmationSeverityEnumMap = {
  ConfirmationSeverity.low: 'low',
  ConfirmationSeverity.medium: 'medium',
  ConfirmationSeverity.high: 'high',
};

_ToolError _$ToolErrorFromJson(Map<String, dynamic> json) => _ToolError(
  code: json['code'] as String,
  message: json['message'] as String,
  retryable: json['retryable'] as bool? ?? false,
);

Map<String, dynamic> _$ToolErrorToJson(_ToolError instance) =>
    <String, dynamic>{
      'code': instance.code,
      'message': instance.message,
      'retryable': instance.retryable,
    };
