// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'tool_result.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
ToolResult _$ToolResultFromJson(
  Map<String, dynamic> json
) {
        switch (json['kind']) {
                  case 'text':
          return TextToolResult.fromJson(
            json
          );
                case 'rich_card':
          return RichCardToolResult.fromJson(
            json
          );
                case 'restaurants':
          return RestaurantsToolResult.fromJson(
            json
          );
                case 'map_route':
          return MapRouteToolResult.fromJson(
            json
          );
                case 'weather':
          return WeatherToolResult.fromJson(
            json
          );
                case 'media':
          return MediaToolResult.fromJson(
            json
          );
                case 'form':
          return FormToolResult.fromJson(
            json
          );
                case 'selection':
          return SelectionToolResult.fromJson(
            json
          );
                case 'confirmation':
          return ConfirmationToolResult.fromJson(
            json
          );
                case 'error':
          return ErrorToolResult.fromJson(
            json
          );
        
          default:
            throw CheckedFromJsonException(
  json,
  'kind',
  'ToolResult',
  'Invalid union type "${json['kind']}"!'
);
        }
      
}

/// @nodoc
mixin _$ToolResult {



  /// Serializes this ToolResult to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ToolResult);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'ToolResult()';
}


}

/// @nodoc
class $ToolResultCopyWith<$Res>  {
$ToolResultCopyWith(ToolResult _, $Res Function(ToolResult) __);
}


/// Adds pattern-matching-related methods to [ToolResult].
extension ToolResultPatterns on ToolResult {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( TextToolResult value)?  text,TResult Function( RichCardToolResult value)?  richCard,TResult Function( RestaurantsToolResult value)?  restaurants,TResult Function( MapRouteToolResult value)?  mapRoute,TResult Function( WeatherToolResult value)?  weather,TResult Function( MediaToolResult value)?  media,TResult Function( FormToolResult value)?  form,TResult Function( SelectionToolResult value)?  selection,TResult Function( ConfirmationToolResult value)?  confirmation,TResult Function( ErrorToolResult value)?  error,required TResult orElse(),}){
final _that = this;
switch (_that) {
case TextToolResult() when text != null:
return text(_that);case RichCardToolResult() when richCard != null:
return richCard(_that);case RestaurantsToolResult() when restaurants != null:
return restaurants(_that);case MapRouteToolResult() when mapRoute != null:
return mapRoute(_that);case WeatherToolResult() when weather != null:
return weather(_that);case MediaToolResult() when media != null:
return media(_that);case FormToolResult() when form != null:
return form(_that);case SelectionToolResult() when selection != null:
return selection(_that);case ConfirmationToolResult() when confirmation != null:
return confirmation(_that);case ErrorToolResult() when error != null:
return error(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( TextToolResult value)  text,required TResult Function( RichCardToolResult value)  richCard,required TResult Function( RestaurantsToolResult value)  restaurants,required TResult Function( MapRouteToolResult value)  mapRoute,required TResult Function( WeatherToolResult value)  weather,required TResult Function( MediaToolResult value)  media,required TResult Function( FormToolResult value)  form,required TResult Function( SelectionToolResult value)  selection,required TResult Function( ConfirmationToolResult value)  confirmation,required TResult Function( ErrorToolResult value)  error,}){
final _that = this;
switch (_that) {
case TextToolResult():
return text(_that);case RichCardToolResult():
return richCard(_that);case RestaurantsToolResult():
return restaurants(_that);case MapRouteToolResult():
return mapRoute(_that);case WeatherToolResult():
return weather(_that);case MediaToolResult():
return media(_that);case FormToolResult():
return form(_that);case SelectionToolResult():
return selection(_that);case ConfirmationToolResult():
return confirmation(_that);case ErrorToolResult():
return error(_that);}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( TextToolResult value)?  text,TResult? Function( RichCardToolResult value)?  richCard,TResult? Function( RestaurantsToolResult value)?  restaurants,TResult? Function( MapRouteToolResult value)?  mapRoute,TResult? Function( WeatherToolResult value)?  weather,TResult? Function( MediaToolResult value)?  media,TResult? Function( FormToolResult value)?  form,TResult? Function( SelectionToolResult value)?  selection,TResult? Function( ConfirmationToolResult value)?  confirmation,TResult? Function( ErrorToolResult value)?  error,}){
final _that = this;
switch (_that) {
case TextToolResult() when text != null:
return text(_that);case RichCardToolResult() when richCard != null:
return richCard(_that);case RestaurantsToolResult() when restaurants != null:
return restaurants(_that);case MapRouteToolResult() when mapRoute != null:
return mapRoute(_that);case WeatherToolResult() when weather != null:
return weather(_that);case MediaToolResult() when media != null:
return media(_that);case FormToolResult() when form != null:
return form(_that);case SelectionToolResult() when selection != null:
return selection(_that);case ConfirmationToolResult() when confirmation != null:
return confirmation(_that);case ErrorToolResult() when error != null:
return error(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( String text)?  text,TResult Function( RichCard card)?  richCard,TResult Function( List<RestaurantResult> items,  String? query)?  restaurants,TResult Function( MapRoute route)?  mapRoute,TResult Function( WeatherData weather)?  weather,TResult Function( List<MediaItem> items)?  media,TResult Function( FormSpec form)?  form,TResult Function( SelectionSpec selection)?  selection,TResult Function( ConfirmationSpec confirmation)?  confirmation,TResult Function( ToolError error)?  error,required TResult orElse(),}) {final _that = this;
switch (_that) {
case TextToolResult() when text != null:
return text(_that.text);case RichCardToolResult() when richCard != null:
return richCard(_that.card);case RestaurantsToolResult() when restaurants != null:
return restaurants(_that.items,_that.query);case MapRouteToolResult() when mapRoute != null:
return mapRoute(_that.route);case WeatherToolResult() when weather != null:
return weather(_that.weather);case MediaToolResult() when media != null:
return media(_that.items);case FormToolResult() when form != null:
return form(_that.form);case SelectionToolResult() when selection != null:
return selection(_that.selection);case ConfirmationToolResult() when confirmation != null:
return confirmation(_that.confirmation);case ErrorToolResult() when error != null:
return error(_that.error);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( String text)  text,required TResult Function( RichCard card)  richCard,required TResult Function( List<RestaurantResult> items,  String? query)  restaurants,required TResult Function( MapRoute route)  mapRoute,required TResult Function( WeatherData weather)  weather,required TResult Function( List<MediaItem> items)  media,required TResult Function( FormSpec form)  form,required TResult Function( SelectionSpec selection)  selection,required TResult Function( ConfirmationSpec confirmation)  confirmation,required TResult Function( ToolError error)  error,}) {final _that = this;
switch (_that) {
case TextToolResult():
return text(_that.text);case RichCardToolResult():
return richCard(_that.card);case RestaurantsToolResult():
return restaurants(_that.items,_that.query);case MapRouteToolResult():
return mapRoute(_that.route);case WeatherToolResult():
return weather(_that.weather);case MediaToolResult():
return media(_that.items);case FormToolResult():
return form(_that.form);case SelectionToolResult():
return selection(_that.selection);case ConfirmationToolResult():
return confirmation(_that.confirmation);case ErrorToolResult():
return error(_that.error);}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( String text)?  text,TResult? Function( RichCard card)?  richCard,TResult? Function( List<RestaurantResult> items,  String? query)?  restaurants,TResult? Function( MapRoute route)?  mapRoute,TResult? Function( WeatherData weather)?  weather,TResult? Function( List<MediaItem> items)?  media,TResult? Function( FormSpec form)?  form,TResult? Function( SelectionSpec selection)?  selection,TResult? Function( ConfirmationSpec confirmation)?  confirmation,TResult? Function( ToolError error)?  error,}) {final _that = this;
switch (_that) {
case TextToolResult() when text != null:
return text(_that.text);case RichCardToolResult() when richCard != null:
return richCard(_that.card);case RestaurantsToolResult() when restaurants != null:
return restaurants(_that.items,_that.query);case MapRouteToolResult() when mapRoute != null:
return mapRoute(_that.route);case WeatherToolResult() when weather != null:
return weather(_that.weather);case MediaToolResult() when media != null:
return media(_that.items);case FormToolResult() when form != null:
return form(_that.form);case SelectionToolResult() when selection != null:
return selection(_that.selection);case ConfirmationToolResult() when confirmation != null:
return confirmation(_that.confirmation);case ErrorToolResult() when error != null:
return error(_that.error);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class TextToolResult extends ToolResult {
  const TextToolResult({required this.text, final  String? $type}): $type = $type ?? 'text',super._();
  factory TextToolResult.fromJson(Map<String, dynamic> json) => _$TextToolResultFromJson(json);

 final  String text;

@JsonKey(name: 'kind')
final String $type;


/// Create a copy of ToolResult
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TextToolResultCopyWith<TextToolResult> get copyWith => _$TextToolResultCopyWithImpl<TextToolResult>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TextToolResultToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TextToolResult&&(identical(other.text, text) || other.text == text));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,text);

@override
String toString() {
  return 'ToolResult.text(text: $text)';
}


}

/// @nodoc
abstract mixin class $TextToolResultCopyWith<$Res> implements $ToolResultCopyWith<$Res> {
  factory $TextToolResultCopyWith(TextToolResult value, $Res Function(TextToolResult) _then) = _$TextToolResultCopyWithImpl;
@useResult
$Res call({
 String text
});




}
/// @nodoc
class _$TextToolResultCopyWithImpl<$Res>
    implements $TextToolResultCopyWith<$Res> {
  _$TextToolResultCopyWithImpl(this._self, this._then);

  final TextToolResult _self;
  final $Res Function(TextToolResult) _then;

/// Create a copy of ToolResult
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? text = null,}) {
  return _then(TextToolResult(
text: null == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
@JsonSerializable()

class RichCardToolResult extends ToolResult {
  const RichCardToolResult({required this.card, final  String? $type}): $type = $type ?? 'rich_card',super._();
  factory RichCardToolResult.fromJson(Map<String, dynamic> json) => _$RichCardToolResultFromJson(json);

 final  RichCard card;

@JsonKey(name: 'kind')
final String $type;


/// Create a copy of ToolResult
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RichCardToolResultCopyWith<RichCardToolResult> get copyWith => _$RichCardToolResultCopyWithImpl<RichCardToolResult>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$RichCardToolResultToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RichCardToolResult&&(identical(other.card, card) || other.card == card));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,card);

@override
String toString() {
  return 'ToolResult.richCard(card: $card)';
}


}

/// @nodoc
abstract mixin class $RichCardToolResultCopyWith<$Res> implements $ToolResultCopyWith<$Res> {
  factory $RichCardToolResultCopyWith(RichCardToolResult value, $Res Function(RichCardToolResult) _then) = _$RichCardToolResultCopyWithImpl;
@useResult
$Res call({
 RichCard card
});


$RichCardCopyWith<$Res> get card;

}
/// @nodoc
class _$RichCardToolResultCopyWithImpl<$Res>
    implements $RichCardToolResultCopyWith<$Res> {
  _$RichCardToolResultCopyWithImpl(this._self, this._then);

  final RichCardToolResult _self;
  final $Res Function(RichCardToolResult) _then;

/// Create a copy of ToolResult
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? card = null,}) {
  return _then(RichCardToolResult(
card: null == card ? _self.card : card // ignore: cast_nullable_to_non_nullable
as RichCard,
  ));
}

/// Create a copy of ToolResult
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$RichCardCopyWith<$Res> get card {
  
  return $RichCardCopyWith<$Res>(_self.card, (value) {
    return _then(_self.copyWith(card: value));
  });
}
}

/// @nodoc
@JsonSerializable()

class RestaurantsToolResult extends ToolResult {
  const RestaurantsToolResult({required final  List<RestaurantResult> items, this.query, final  String? $type}): _items = items,$type = $type ?? 'restaurants',super._();
  factory RestaurantsToolResult.fromJson(Map<String, dynamic> json) => _$RestaurantsToolResultFromJson(json);

 final  List<RestaurantResult> _items;
 List<RestaurantResult> get items {
  if (_items is EqualUnmodifiableListView) return _items;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_items);
}

 final  String? query;

@JsonKey(name: 'kind')
final String $type;


/// Create a copy of ToolResult
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RestaurantsToolResultCopyWith<RestaurantsToolResult> get copyWith => _$RestaurantsToolResultCopyWithImpl<RestaurantsToolResult>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$RestaurantsToolResultToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RestaurantsToolResult&&const DeepCollectionEquality().equals(other._items, _items)&&(identical(other.query, query) || other.query == query));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_items),query);

@override
String toString() {
  return 'ToolResult.restaurants(items: $items, query: $query)';
}


}

/// @nodoc
abstract mixin class $RestaurantsToolResultCopyWith<$Res> implements $ToolResultCopyWith<$Res> {
  factory $RestaurantsToolResultCopyWith(RestaurantsToolResult value, $Res Function(RestaurantsToolResult) _then) = _$RestaurantsToolResultCopyWithImpl;
@useResult
$Res call({
 List<RestaurantResult> items, String? query
});




}
/// @nodoc
class _$RestaurantsToolResultCopyWithImpl<$Res>
    implements $RestaurantsToolResultCopyWith<$Res> {
  _$RestaurantsToolResultCopyWithImpl(this._self, this._then);

  final RestaurantsToolResult _self;
  final $Res Function(RestaurantsToolResult) _then;

/// Create a copy of ToolResult
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? items = null,Object? query = freezed,}) {
  return _then(RestaurantsToolResult(
items: null == items ? _self._items : items // ignore: cast_nullable_to_non_nullable
as List<RestaurantResult>,query: freezed == query ? _self.query : query // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc
@JsonSerializable()

class MapRouteToolResult extends ToolResult {
  const MapRouteToolResult({required this.route, final  String? $type}): $type = $type ?? 'map_route',super._();
  factory MapRouteToolResult.fromJson(Map<String, dynamic> json) => _$MapRouteToolResultFromJson(json);

 final  MapRoute route;

@JsonKey(name: 'kind')
final String $type;


/// Create a copy of ToolResult
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MapRouteToolResultCopyWith<MapRouteToolResult> get copyWith => _$MapRouteToolResultCopyWithImpl<MapRouteToolResult>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MapRouteToolResultToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MapRouteToolResult&&(identical(other.route, route) || other.route == route));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,route);

@override
String toString() {
  return 'ToolResult.mapRoute(route: $route)';
}


}

/// @nodoc
abstract mixin class $MapRouteToolResultCopyWith<$Res> implements $ToolResultCopyWith<$Res> {
  factory $MapRouteToolResultCopyWith(MapRouteToolResult value, $Res Function(MapRouteToolResult) _then) = _$MapRouteToolResultCopyWithImpl;
@useResult
$Res call({
 MapRoute route
});


$MapRouteCopyWith<$Res> get route;

}
/// @nodoc
class _$MapRouteToolResultCopyWithImpl<$Res>
    implements $MapRouteToolResultCopyWith<$Res> {
  _$MapRouteToolResultCopyWithImpl(this._self, this._then);

  final MapRouteToolResult _self;
  final $Res Function(MapRouteToolResult) _then;

/// Create a copy of ToolResult
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? route = null,}) {
  return _then(MapRouteToolResult(
route: null == route ? _self.route : route // ignore: cast_nullable_to_non_nullable
as MapRoute,
  ));
}

/// Create a copy of ToolResult
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$MapRouteCopyWith<$Res> get route {
  
  return $MapRouteCopyWith<$Res>(_self.route, (value) {
    return _then(_self.copyWith(route: value));
  });
}
}

/// @nodoc
@JsonSerializable()

class WeatherToolResult extends ToolResult {
  const WeatherToolResult({required this.weather, final  String? $type}): $type = $type ?? 'weather',super._();
  factory WeatherToolResult.fromJson(Map<String, dynamic> json) => _$WeatherToolResultFromJson(json);

 final  WeatherData weather;

@JsonKey(name: 'kind')
final String $type;


/// Create a copy of ToolResult
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$WeatherToolResultCopyWith<WeatherToolResult> get copyWith => _$WeatherToolResultCopyWithImpl<WeatherToolResult>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$WeatherToolResultToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is WeatherToolResult&&(identical(other.weather, weather) || other.weather == weather));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,weather);

@override
String toString() {
  return 'ToolResult.weather(weather: $weather)';
}


}

/// @nodoc
abstract mixin class $WeatherToolResultCopyWith<$Res> implements $ToolResultCopyWith<$Res> {
  factory $WeatherToolResultCopyWith(WeatherToolResult value, $Res Function(WeatherToolResult) _then) = _$WeatherToolResultCopyWithImpl;
@useResult
$Res call({
 WeatherData weather
});


$WeatherDataCopyWith<$Res> get weather;

}
/// @nodoc
class _$WeatherToolResultCopyWithImpl<$Res>
    implements $WeatherToolResultCopyWith<$Res> {
  _$WeatherToolResultCopyWithImpl(this._self, this._then);

  final WeatherToolResult _self;
  final $Res Function(WeatherToolResult) _then;

/// Create a copy of ToolResult
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? weather = null,}) {
  return _then(WeatherToolResult(
weather: null == weather ? _self.weather : weather // ignore: cast_nullable_to_non_nullable
as WeatherData,
  ));
}

/// Create a copy of ToolResult
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$WeatherDataCopyWith<$Res> get weather {
  
  return $WeatherDataCopyWith<$Res>(_self.weather, (value) {
    return _then(_self.copyWith(weather: value));
  });
}
}

/// @nodoc
@JsonSerializable()

class MediaToolResult extends ToolResult {
  const MediaToolResult({required final  List<MediaItem> items, final  String? $type}): _items = items,$type = $type ?? 'media',super._();
  factory MediaToolResult.fromJson(Map<String, dynamic> json) => _$MediaToolResultFromJson(json);

 final  List<MediaItem> _items;
 List<MediaItem> get items {
  if (_items is EqualUnmodifiableListView) return _items;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_items);
}


@JsonKey(name: 'kind')
final String $type;


/// Create a copy of ToolResult
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MediaToolResultCopyWith<MediaToolResult> get copyWith => _$MediaToolResultCopyWithImpl<MediaToolResult>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MediaToolResultToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MediaToolResult&&const DeepCollectionEquality().equals(other._items, _items));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_items));

@override
String toString() {
  return 'ToolResult.media(items: $items)';
}


}

/// @nodoc
abstract mixin class $MediaToolResultCopyWith<$Res> implements $ToolResultCopyWith<$Res> {
  factory $MediaToolResultCopyWith(MediaToolResult value, $Res Function(MediaToolResult) _then) = _$MediaToolResultCopyWithImpl;
@useResult
$Res call({
 List<MediaItem> items
});




}
/// @nodoc
class _$MediaToolResultCopyWithImpl<$Res>
    implements $MediaToolResultCopyWith<$Res> {
  _$MediaToolResultCopyWithImpl(this._self, this._then);

  final MediaToolResult _self;
  final $Res Function(MediaToolResult) _then;

/// Create a copy of ToolResult
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? items = null,}) {
  return _then(MediaToolResult(
items: null == items ? _self._items : items // ignore: cast_nullable_to_non_nullable
as List<MediaItem>,
  ));
}


}

/// @nodoc
@JsonSerializable()

class FormToolResult extends ToolResult {
  const FormToolResult({required this.form, final  String? $type}): $type = $type ?? 'form',super._();
  factory FormToolResult.fromJson(Map<String, dynamic> json) => _$FormToolResultFromJson(json);

 final  FormSpec form;

@JsonKey(name: 'kind')
final String $type;


/// Create a copy of ToolResult
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FormToolResultCopyWith<FormToolResult> get copyWith => _$FormToolResultCopyWithImpl<FormToolResult>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$FormToolResultToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FormToolResult&&(identical(other.form, form) || other.form == form));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,form);

@override
String toString() {
  return 'ToolResult.form(form: $form)';
}


}

/// @nodoc
abstract mixin class $FormToolResultCopyWith<$Res> implements $ToolResultCopyWith<$Res> {
  factory $FormToolResultCopyWith(FormToolResult value, $Res Function(FormToolResult) _then) = _$FormToolResultCopyWithImpl;
@useResult
$Res call({
 FormSpec form
});


$FormSpecCopyWith<$Res> get form;

}
/// @nodoc
class _$FormToolResultCopyWithImpl<$Res>
    implements $FormToolResultCopyWith<$Res> {
  _$FormToolResultCopyWithImpl(this._self, this._then);

  final FormToolResult _self;
  final $Res Function(FormToolResult) _then;

/// Create a copy of ToolResult
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? form = null,}) {
  return _then(FormToolResult(
form: null == form ? _self.form : form // ignore: cast_nullable_to_non_nullable
as FormSpec,
  ));
}

/// Create a copy of ToolResult
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$FormSpecCopyWith<$Res> get form {
  
  return $FormSpecCopyWith<$Res>(_self.form, (value) {
    return _then(_self.copyWith(form: value));
  });
}
}

/// @nodoc
@JsonSerializable()

class SelectionToolResult extends ToolResult {
  const SelectionToolResult({required this.selection, final  String? $type}): $type = $type ?? 'selection',super._();
  factory SelectionToolResult.fromJson(Map<String, dynamic> json) => _$SelectionToolResultFromJson(json);

 final  SelectionSpec selection;

@JsonKey(name: 'kind')
final String $type;


/// Create a copy of ToolResult
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SelectionToolResultCopyWith<SelectionToolResult> get copyWith => _$SelectionToolResultCopyWithImpl<SelectionToolResult>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SelectionToolResultToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SelectionToolResult&&(identical(other.selection, selection) || other.selection == selection));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,selection);

@override
String toString() {
  return 'ToolResult.selection(selection: $selection)';
}


}

/// @nodoc
abstract mixin class $SelectionToolResultCopyWith<$Res> implements $ToolResultCopyWith<$Res> {
  factory $SelectionToolResultCopyWith(SelectionToolResult value, $Res Function(SelectionToolResult) _then) = _$SelectionToolResultCopyWithImpl;
@useResult
$Res call({
 SelectionSpec selection
});


$SelectionSpecCopyWith<$Res> get selection;

}
/// @nodoc
class _$SelectionToolResultCopyWithImpl<$Res>
    implements $SelectionToolResultCopyWith<$Res> {
  _$SelectionToolResultCopyWithImpl(this._self, this._then);

  final SelectionToolResult _self;
  final $Res Function(SelectionToolResult) _then;

/// Create a copy of ToolResult
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? selection = null,}) {
  return _then(SelectionToolResult(
selection: null == selection ? _self.selection : selection // ignore: cast_nullable_to_non_nullable
as SelectionSpec,
  ));
}

/// Create a copy of ToolResult
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SelectionSpecCopyWith<$Res> get selection {
  
  return $SelectionSpecCopyWith<$Res>(_self.selection, (value) {
    return _then(_self.copyWith(selection: value));
  });
}
}

/// @nodoc
@JsonSerializable()

class ConfirmationToolResult extends ToolResult {
  const ConfirmationToolResult({required this.confirmation, final  String? $type}): $type = $type ?? 'confirmation',super._();
  factory ConfirmationToolResult.fromJson(Map<String, dynamic> json) => _$ConfirmationToolResultFromJson(json);

 final  ConfirmationSpec confirmation;

@JsonKey(name: 'kind')
final String $type;


/// Create a copy of ToolResult
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ConfirmationToolResultCopyWith<ConfirmationToolResult> get copyWith => _$ConfirmationToolResultCopyWithImpl<ConfirmationToolResult>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ConfirmationToolResultToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ConfirmationToolResult&&(identical(other.confirmation, confirmation) || other.confirmation == confirmation));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,confirmation);

@override
String toString() {
  return 'ToolResult.confirmation(confirmation: $confirmation)';
}


}

/// @nodoc
abstract mixin class $ConfirmationToolResultCopyWith<$Res> implements $ToolResultCopyWith<$Res> {
  factory $ConfirmationToolResultCopyWith(ConfirmationToolResult value, $Res Function(ConfirmationToolResult) _then) = _$ConfirmationToolResultCopyWithImpl;
@useResult
$Res call({
 ConfirmationSpec confirmation
});


$ConfirmationSpecCopyWith<$Res> get confirmation;

}
/// @nodoc
class _$ConfirmationToolResultCopyWithImpl<$Res>
    implements $ConfirmationToolResultCopyWith<$Res> {
  _$ConfirmationToolResultCopyWithImpl(this._self, this._then);

  final ConfirmationToolResult _self;
  final $Res Function(ConfirmationToolResult) _then;

/// Create a copy of ToolResult
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? confirmation = null,}) {
  return _then(ConfirmationToolResult(
confirmation: null == confirmation ? _self.confirmation : confirmation // ignore: cast_nullable_to_non_nullable
as ConfirmationSpec,
  ));
}

/// Create a copy of ToolResult
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ConfirmationSpecCopyWith<$Res> get confirmation {
  
  return $ConfirmationSpecCopyWith<$Res>(_self.confirmation, (value) {
    return _then(_self.copyWith(confirmation: value));
  });
}
}

/// @nodoc
@JsonSerializable()

class ErrorToolResult extends ToolResult {
  const ErrorToolResult({required this.error, final  String? $type}): $type = $type ?? 'error',super._();
  factory ErrorToolResult.fromJson(Map<String, dynamic> json) => _$ErrorToolResultFromJson(json);

 final  ToolError error;

@JsonKey(name: 'kind')
final String $type;


/// Create a copy of ToolResult
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ErrorToolResultCopyWith<ErrorToolResult> get copyWith => _$ErrorToolResultCopyWithImpl<ErrorToolResult>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ErrorToolResultToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ErrorToolResult&&(identical(other.error, error) || other.error == error));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,error);

@override
String toString() {
  return 'ToolResult.error(error: $error)';
}


}

/// @nodoc
abstract mixin class $ErrorToolResultCopyWith<$Res> implements $ToolResultCopyWith<$Res> {
  factory $ErrorToolResultCopyWith(ErrorToolResult value, $Res Function(ErrorToolResult) _then) = _$ErrorToolResultCopyWithImpl;
@useResult
$Res call({
 ToolError error
});


$ToolErrorCopyWith<$Res> get error;

}
/// @nodoc
class _$ErrorToolResultCopyWithImpl<$Res>
    implements $ErrorToolResultCopyWith<$Res> {
  _$ErrorToolResultCopyWithImpl(this._self, this._then);

  final ErrorToolResult _self;
  final $Res Function(ErrorToolResult) _then;

/// Create a copy of ToolResult
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? error = null,}) {
  return _then(ErrorToolResult(
error: null == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as ToolError,
  ));
}

/// Create a copy of ToolResult
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ToolErrorCopyWith<$Res> get error {
  
  return $ToolErrorCopyWith<$Res>(_self.error, (value) {
    return _then(_self.copyWith(error: value));
  });
}
}


/// @nodoc
mixin _$RichCard {

 String get title; String? get subtitle; String? get body; Uri? get imageUri; List<CardAction> get actions;
/// Create a copy of RichCard
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RichCardCopyWith<RichCard> get copyWith => _$RichCardCopyWithImpl<RichCard>(this as RichCard, _$identity);

  /// Serializes this RichCard to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RichCard&&(identical(other.title, title) || other.title == title)&&(identical(other.subtitle, subtitle) || other.subtitle == subtitle)&&(identical(other.body, body) || other.body == body)&&(identical(other.imageUri, imageUri) || other.imageUri == imageUri)&&const DeepCollectionEquality().equals(other.actions, actions));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,title,subtitle,body,imageUri,const DeepCollectionEquality().hash(actions));

@override
String toString() {
  return 'RichCard(title: $title, subtitle: $subtitle, body: $body, imageUri: $imageUri, actions: $actions)';
}


}

/// @nodoc
abstract mixin class $RichCardCopyWith<$Res>  {
  factory $RichCardCopyWith(RichCard value, $Res Function(RichCard) _then) = _$RichCardCopyWithImpl;
@useResult
$Res call({
 String title, String? subtitle, String? body, Uri? imageUri, List<CardAction> actions
});




}
/// @nodoc
class _$RichCardCopyWithImpl<$Res>
    implements $RichCardCopyWith<$Res> {
  _$RichCardCopyWithImpl(this._self, this._then);

  final RichCard _self;
  final $Res Function(RichCard) _then;

/// Create a copy of RichCard
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? title = null,Object? subtitle = freezed,Object? body = freezed,Object? imageUri = freezed,Object? actions = null,}) {
  return _then(_self.copyWith(
title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,subtitle: freezed == subtitle ? _self.subtitle : subtitle // ignore: cast_nullable_to_non_nullable
as String?,body: freezed == body ? _self.body : body // ignore: cast_nullable_to_non_nullable
as String?,imageUri: freezed == imageUri ? _self.imageUri : imageUri // ignore: cast_nullable_to_non_nullable
as Uri?,actions: null == actions ? _self.actions : actions // ignore: cast_nullable_to_non_nullable
as List<CardAction>,
  ));
}

}


/// Adds pattern-matching-related methods to [RichCard].
extension RichCardPatterns on RichCard {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _RichCard value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _RichCard() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _RichCard value)  $default,){
final _that = this;
switch (_that) {
case _RichCard():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _RichCard value)?  $default,){
final _that = this;
switch (_that) {
case _RichCard() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String title,  String? subtitle,  String? body,  Uri? imageUri,  List<CardAction> actions)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RichCard() when $default != null:
return $default(_that.title,_that.subtitle,_that.body,_that.imageUri,_that.actions);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String title,  String? subtitle,  String? body,  Uri? imageUri,  List<CardAction> actions)  $default,) {final _that = this;
switch (_that) {
case _RichCard():
return $default(_that.title,_that.subtitle,_that.body,_that.imageUri,_that.actions);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String title,  String? subtitle,  String? body,  Uri? imageUri,  List<CardAction> actions)?  $default,) {final _that = this;
switch (_that) {
case _RichCard() when $default != null:
return $default(_that.title,_that.subtitle,_that.body,_that.imageUri,_that.actions);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _RichCard implements RichCard {
  const _RichCard({required this.title, this.subtitle, this.body, this.imageUri, final  List<CardAction> actions = const <CardAction>[]}): _actions = actions;
  factory _RichCard.fromJson(Map<String, dynamic> json) => _$RichCardFromJson(json);

@override final  String title;
@override final  String? subtitle;
@override final  String? body;
@override final  Uri? imageUri;
 final  List<CardAction> _actions;
@override@JsonKey() List<CardAction> get actions {
  if (_actions is EqualUnmodifiableListView) return _actions;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_actions);
}


/// Create a copy of RichCard
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RichCardCopyWith<_RichCard> get copyWith => __$RichCardCopyWithImpl<_RichCard>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$RichCardToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _RichCard&&(identical(other.title, title) || other.title == title)&&(identical(other.subtitle, subtitle) || other.subtitle == subtitle)&&(identical(other.body, body) || other.body == body)&&(identical(other.imageUri, imageUri) || other.imageUri == imageUri)&&const DeepCollectionEquality().equals(other._actions, _actions));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,title,subtitle,body,imageUri,const DeepCollectionEquality().hash(_actions));

@override
String toString() {
  return 'RichCard(title: $title, subtitle: $subtitle, body: $body, imageUri: $imageUri, actions: $actions)';
}


}

/// @nodoc
abstract mixin class _$RichCardCopyWith<$Res> implements $RichCardCopyWith<$Res> {
  factory _$RichCardCopyWith(_RichCard value, $Res Function(_RichCard) _then) = __$RichCardCopyWithImpl;
@override @useResult
$Res call({
 String title, String? subtitle, String? body, Uri? imageUri, List<CardAction> actions
});




}
/// @nodoc
class __$RichCardCopyWithImpl<$Res>
    implements _$RichCardCopyWith<$Res> {
  __$RichCardCopyWithImpl(this._self, this._then);

  final _RichCard _self;
  final $Res Function(_RichCard) _then;

/// Create a copy of RichCard
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? title = null,Object? subtitle = freezed,Object? body = freezed,Object? imageUri = freezed,Object? actions = null,}) {
  return _then(_RichCard(
title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,subtitle: freezed == subtitle ? _self.subtitle : subtitle // ignore: cast_nullable_to_non_nullable
as String?,body: freezed == body ? _self.body : body // ignore: cast_nullable_to_non_nullable
as String?,imageUri: freezed == imageUri ? _self.imageUri : imageUri // ignore: cast_nullable_to_non_nullable
as Uri?,actions: null == actions ? _self._actions : actions // ignore: cast_nullable_to_non_nullable
as List<CardAction>,
  ));
}


}


/// @nodoc
mixin _$CardAction {

 String get id; String get label; bool get primary;
/// Create a copy of CardAction
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CardActionCopyWith<CardAction> get copyWith => _$CardActionCopyWithImpl<CardAction>(this as CardAction, _$identity);

  /// Serializes this CardAction to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CardAction&&(identical(other.id, id) || other.id == id)&&(identical(other.label, label) || other.label == label)&&(identical(other.primary, primary) || other.primary == primary));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,label,primary);

@override
String toString() {
  return 'CardAction(id: $id, label: $label, primary: $primary)';
}


}

/// @nodoc
abstract mixin class $CardActionCopyWith<$Res>  {
  factory $CardActionCopyWith(CardAction value, $Res Function(CardAction) _then) = _$CardActionCopyWithImpl;
@useResult
$Res call({
 String id, String label, bool primary
});




}
/// @nodoc
class _$CardActionCopyWithImpl<$Res>
    implements $CardActionCopyWith<$Res> {
  _$CardActionCopyWithImpl(this._self, this._then);

  final CardAction _self;
  final $Res Function(CardAction) _then;

/// Create a copy of CardAction
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? label = null,Object? primary = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,label: null == label ? _self.label : label // ignore: cast_nullable_to_non_nullable
as String,primary: null == primary ? _self.primary : primary // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [CardAction].
extension CardActionPatterns on CardAction {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CardAction value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CardAction() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CardAction value)  $default,){
final _that = this;
switch (_that) {
case _CardAction():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CardAction value)?  $default,){
final _that = this;
switch (_that) {
case _CardAction() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String label,  bool primary)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CardAction() when $default != null:
return $default(_that.id,_that.label,_that.primary);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String label,  bool primary)  $default,) {final _that = this;
switch (_that) {
case _CardAction():
return $default(_that.id,_that.label,_that.primary);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String label,  bool primary)?  $default,) {final _that = this;
switch (_that) {
case _CardAction() when $default != null:
return $default(_that.id,_that.label,_that.primary);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _CardAction implements CardAction {
  const _CardAction({required this.id, required this.label, this.primary = false});
  factory _CardAction.fromJson(Map<String, dynamic> json) => _$CardActionFromJson(json);

@override final  String id;
@override final  String label;
@override@JsonKey() final  bool primary;

/// Create a copy of CardAction
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CardActionCopyWith<_CardAction> get copyWith => __$CardActionCopyWithImpl<_CardAction>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CardActionToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CardAction&&(identical(other.id, id) || other.id == id)&&(identical(other.label, label) || other.label == label)&&(identical(other.primary, primary) || other.primary == primary));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,label,primary);

@override
String toString() {
  return 'CardAction(id: $id, label: $label, primary: $primary)';
}


}

/// @nodoc
abstract mixin class _$CardActionCopyWith<$Res> implements $CardActionCopyWith<$Res> {
  factory _$CardActionCopyWith(_CardAction value, $Res Function(_CardAction) _then) = __$CardActionCopyWithImpl;
@override @useResult
$Res call({
 String id, String label, bool primary
});




}
/// @nodoc
class __$CardActionCopyWithImpl<$Res>
    implements _$CardActionCopyWith<$Res> {
  __$CardActionCopyWithImpl(this._self, this._then);

  final _CardAction _self;
  final $Res Function(_CardAction) _then;

/// Create a copy of CardAction
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? label = null,Object? primary = null,}) {
  return _then(_CardAction(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,label: null == label ? _self.label : label // ignore: cast_nullable_to_non_nullable
as String,primary: null == primary ? _self.primary : primary // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}


/// @nodoc
mixin _$RestaurantResult {

 String get id; String get name; String? get cuisine;/// 0..5
 double? get rating;/// 1..4 price tier
 int? get priceTier; String? get address; double? get distanceMeters; Uri? get imageUri; bool get openNow;
/// Create a copy of RestaurantResult
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RestaurantResultCopyWith<RestaurantResult> get copyWith => _$RestaurantResultCopyWithImpl<RestaurantResult>(this as RestaurantResult, _$identity);

  /// Serializes this RestaurantResult to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RestaurantResult&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.cuisine, cuisine) || other.cuisine == cuisine)&&(identical(other.rating, rating) || other.rating == rating)&&(identical(other.priceTier, priceTier) || other.priceTier == priceTier)&&(identical(other.address, address) || other.address == address)&&(identical(other.distanceMeters, distanceMeters) || other.distanceMeters == distanceMeters)&&(identical(other.imageUri, imageUri) || other.imageUri == imageUri)&&(identical(other.openNow, openNow) || other.openNow == openNow));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,cuisine,rating,priceTier,address,distanceMeters,imageUri,openNow);

@override
String toString() {
  return 'RestaurantResult(id: $id, name: $name, cuisine: $cuisine, rating: $rating, priceTier: $priceTier, address: $address, distanceMeters: $distanceMeters, imageUri: $imageUri, openNow: $openNow)';
}


}

/// @nodoc
abstract mixin class $RestaurantResultCopyWith<$Res>  {
  factory $RestaurantResultCopyWith(RestaurantResult value, $Res Function(RestaurantResult) _then) = _$RestaurantResultCopyWithImpl;
@useResult
$Res call({
 String id, String name, String? cuisine, double? rating, int? priceTier, String? address, double? distanceMeters, Uri? imageUri, bool openNow
});




}
/// @nodoc
class _$RestaurantResultCopyWithImpl<$Res>
    implements $RestaurantResultCopyWith<$Res> {
  _$RestaurantResultCopyWithImpl(this._self, this._then);

  final RestaurantResult _self;
  final $Res Function(RestaurantResult) _then;

/// Create a copy of RestaurantResult
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? cuisine = freezed,Object? rating = freezed,Object? priceTier = freezed,Object? address = freezed,Object? distanceMeters = freezed,Object? imageUri = freezed,Object? openNow = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,cuisine: freezed == cuisine ? _self.cuisine : cuisine // ignore: cast_nullable_to_non_nullable
as String?,rating: freezed == rating ? _self.rating : rating // ignore: cast_nullable_to_non_nullable
as double?,priceTier: freezed == priceTier ? _self.priceTier : priceTier // ignore: cast_nullable_to_non_nullable
as int?,address: freezed == address ? _self.address : address // ignore: cast_nullable_to_non_nullable
as String?,distanceMeters: freezed == distanceMeters ? _self.distanceMeters : distanceMeters // ignore: cast_nullable_to_non_nullable
as double?,imageUri: freezed == imageUri ? _self.imageUri : imageUri // ignore: cast_nullable_to_non_nullable
as Uri?,openNow: null == openNow ? _self.openNow : openNow // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [RestaurantResult].
extension RestaurantResultPatterns on RestaurantResult {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _RestaurantResult value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _RestaurantResult() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _RestaurantResult value)  $default,){
final _that = this;
switch (_that) {
case _RestaurantResult():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _RestaurantResult value)?  $default,){
final _that = this;
switch (_that) {
case _RestaurantResult() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  String? cuisine,  double? rating,  int? priceTier,  String? address,  double? distanceMeters,  Uri? imageUri,  bool openNow)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RestaurantResult() when $default != null:
return $default(_that.id,_that.name,_that.cuisine,_that.rating,_that.priceTier,_that.address,_that.distanceMeters,_that.imageUri,_that.openNow);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  String? cuisine,  double? rating,  int? priceTier,  String? address,  double? distanceMeters,  Uri? imageUri,  bool openNow)  $default,) {final _that = this;
switch (_that) {
case _RestaurantResult():
return $default(_that.id,_that.name,_that.cuisine,_that.rating,_that.priceTier,_that.address,_that.distanceMeters,_that.imageUri,_that.openNow);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  String? cuisine,  double? rating,  int? priceTier,  String? address,  double? distanceMeters,  Uri? imageUri,  bool openNow)?  $default,) {final _that = this;
switch (_that) {
case _RestaurantResult() when $default != null:
return $default(_that.id,_that.name,_that.cuisine,_that.rating,_that.priceTier,_that.address,_that.distanceMeters,_that.imageUri,_that.openNow);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _RestaurantResult implements RestaurantResult {
  const _RestaurantResult({required this.id, required this.name, this.cuisine, this.rating, this.priceTier, this.address, this.distanceMeters, this.imageUri, this.openNow = false});
  factory _RestaurantResult.fromJson(Map<String, dynamic> json) => _$RestaurantResultFromJson(json);

@override final  String id;
@override final  String name;
@override final  String? cuisine;
/// 0..5
@override final  double? rating;
/// 1..4 price tier
@override final  int? priceTier;
@override final  String? address;
@override final  double? distanceMeters;
@override final  Uri? imageUri;
@override@JsonKey() final  bool openNow;

/// Create a copy of RestaurantResult
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RestaurantResultCopyWith<_RestaurantResult> get copyWith => __$RestaurantResultCopyWithImpl<_RestaurantResult>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$RestaurantResultToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _RestaurantResult&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.cuisine, cuisine) || other.cuisine == cuisine)&&(identical(other.rating, rating) || other.rating == rating)&&(identical(other.priceTier, priceTier) || other.priceTier == priceTier)&&(identical(other.address, address) || other.address == address)&&(identical(other.distanceMeters, distanceMeters) || other.distanceMeters == distanceMeters)&&(identical(other.imageUri, imageUri) || other.imageUri == imageUri)&&(identical(other.openNow, openNow) || other.openNow == openNow));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,cuisine,rating,priceTier,address,distanceMeters,imageUri,openNow);

@override
String toString() {
  return 'RestaurantResult(id: $id, name: $name, cuisine: $cuisine, rating: $rating, priceTier: $priceTier, address: $address, distanceMeters: $distanceMeters, imageUri: $imageUri, openNow: $openNow)';
}


}

/// @nodoc
abstract mixin class _$RestaurantResultCopyWith<$Res> implements $RestaurantResultCopyWith<$Res> {
  factory _$RestaurantResultCopyWith(_RestaurantResult value, $Res Function(_RestaurantResult) _then) = __$RestaurantResultCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, String? cuisine, double? rating, int? priceTier, String? address, double? distanceMeters, Uri? imageUri, bool openNow
});




}
/// @nodoc
class __$RestaurantResultCopyWithImpl<$Res>
    implements _$RestaurantResultCopyWith<$Res> {
  __$RestaurantResultCopyWithImpl(this._self, this._then);

  final _RestaurantResult _self;
  final $Res Function(_RestaurantResult) _then;

/// Create a copy of RestaurantResult
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? cuisine = freezed,Object? rating = freezed,Object? priceTier = freezed,Object? address = freezed,Object? distanceMeters = freezed,Object? imageUri = freezed,Object? openNow = null,}) {
  return _then(_RestaurantResult(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,cuisine: freezed == cuisine ? _self.cuisine : cuisine // ignore: cast_nullable_to_non_nullable
as String?,rating: freezed == rating ? _self.rating : rating // ignore: cast_nullable_to_non_nullable
as double?,priceTier: freezed == priceTier ? _self.priceTier : priceTier // ignore: cast_nullable_to_non_nullable
as int?,address: freezed == address ? _self.address : address // ignore: cast_nullable_to_non_nullable
as String?,distanceMeters: freezed == distanceMeters ? _self.distanceMeters : distanceMeters // ignore: cast_nullable_to_non_nullable
as double?,imageUri: freezed == imageUri ? _self.imageUri : imageUri // ignore: cast_nullable_to_non_nullable
as Uri?,openNow: null == openNow ? _self.openNow : openNow // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}


/// @nodoc
mixin _$GeoPoint {

 double get latitude; double get longitude;
/// Create a copy of GeoPoint
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GeoPointCopyWith<GeoPoint> get copyWith => _$GeoPointCopyWithImpl<GeoPoint>(this as GeoPoint, _$identity);

  /// Serializes this GeoPoint to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GeoPoint&&(identical(other.latitude, latitude) || other.latitude == latitude)&&(identical(other.longitude, longitude) || other.longitude == longitude));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,latitude,longitude);

@override
String toString() {
  return 'GeoPoint(latitude: $latitude, longitude: $longitude)';
}


}

/// @nodoc
abstract mixin class $GeoPointCopyWith<$Res>  {
  factory $GeoPointCopyWith(GeoPoint value, $Res Function(GeoPoint) _then) = _$GeoPointCopyWithImpl;
@useResult
$Res call({
 double latitude, double longitude
});




}
/// @nodoc
class _$GeoPointCopyWithImpl<$Res>
    implements $GeoPointCopyWith<$Res> {
  _$GeoPointCopyWithImpl(this._self, this._then);

  final GeoPoint _self;
  final $Res Function(GeoPoint) _then;

/// Create a copy of GeoPoint
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? latitude = null,Object? longitude = null,}) {
  return _then(_self.copyWith(
latitude: null == latitude ? _self.latitude : latitude // ignore: cast_nullable_to_non_nullable
as double,longitude: null == longitude ? _self.longitude : longitude // ignore: cast_nullable_to_non_nullable
as double,
  ));
}

}


/// Adds pattern-matching-related methods to [GeoPoint].
extension GeoPointPatterns on GeoPoint {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _GeoPoint value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _GeoPoint() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _GeoPoint value)  $default,){
final _that = this;
switch (_that) {
case _GeoPoint():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _GeoPoint value)?  $default,){
final _that = this;
switch (_that) {
case _GeoPoint() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( double latitude,  double longitude)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _GeoPoint() when $default != null:
return $default(_that.latitude,_that.longitude);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( double latitude,  double longitude)  $default,) {final _that = this;
switch (_that) {
case _GeoPoint():
return $default(_that.latitude,_that.longitude);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( double latitude,  double longitude)?  $default,) {final _that = this;
switch (_that) {
case _GeoPoint() when $default != null:
return $default(_that.latitude,_that.longitude);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _GeoPoint implements GeoPoint {
  const _GeoPoint({required this.latitude, required this.longitude});
  factory _GeoPoint.fromJson(Map<String, dynamic> json) => _$GeoPointFromJson(json);

@override final  double latitude;
@override final  double longitude;

/// Create a copy of GeoPoint
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$GeoPointCopyWith<_GeoPoint> get copyWith => __$GeoPointCopyWithImpl<_GeoPoint>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$GeoPointToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _GeoPoint&&(identical(other.latitude, latitude) || other.latitude == latitude)&&(identical(other.longitude, longitude) || other.longitude == longitude));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,latitude,longitude);

@override
String toString() {
  return 'GeoPoint(latitude: $latitude, longitude: $longitude)';
}


}

/// @nodoc
abstract mixin class _$GeoPointCopyWith<$Res> implements $GeoPointCopyWith<$Res> {
  factory _$GeoPointCopyWith(_GeoPoint value, $Res Function(_GeoPoint) _then) = __$GeoPointCopyWithImpl;
@override @useResult
$Res call({
 double latitude, double longitude
});




}
/// @nodoc
class __$GeoPointCopyWithImpl<$Res>
    implements _$GeoPointCopyWith<$Res> {
  __$GeoPointCopyWithImpl(this._self, this._then);

  final _GeoPoint _self;
  final $Res Function(_GeoPoint) _then;

/// Create a copy of GeoPoint
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? latitude = null,Object? longitude = null,}) {
  return _then(_GeoPoint(
latitude: null == latitude ? _self.latitude : latitude // ignore: cast_nullable_to_non_nullable
as double,longitude: null == longitude ? _self.longitude : longitude // ignore: cast_nullable_to_non_nullable
as double,
  ));
}


}


/// @nodoc
mixin _$MapRoute {

 GeoPoint get origin; GeoPoint get destination; String? get originLabel; String? get destinationLabel; double? get distanceMeters; Duration? get duration;/// Google-style encoded polyline; decoded by a map widget later.
 String? get encodedPolyline; List<GeoPoint> get waypoints;
/// Create a copy of MapRoute
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MapRouteCopyWith<MapRoute> get copyWith => _$MapRouteCopyWithImpl<MapRoute>(this as MapRoute, _$identity);

  /// Serializes this MapRoute to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MapRoute&&(identical(other.origin, origin) || other.origin == origin)&&(identical(other.destination, destination) || other.destination == destination)&&(identical(other.originLabel, originLabel) || other.originLabel == originLabel)&&(identical(other.destinationLabel, destinationLabel) || other.destinationLabel == destinationLabel)&&(identical(other.distanceMeters, distanceMeters) || other.distanceMeters == distanceMeters)&&(identical(other.duration, duration) || other.duration == duration)&&(identical(other.encodedPolyline, encodedPolyline) || other.encodedPolyline == encodedPolyline)&&const DeepCollectionEquality().equals(other.waypoints, waypoints));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,origin,destination,originLabel,destinationLabel,distanceMeters,duration,encodedPolyline,const DeepCollectionEquality().hash(waypoints));

@override
String toString() {
  return 'MapRoute(origin: $origin, destination: $destination, originLabel: $originLabel, destinationLabel: $destinationLabel, distanceMeters: $distanceMeters, duration: $duration, encodedPolyline: $encodedPolyline, waypoints: $waypoints)';
}


}

/// @nodoc
abstract mixin class $MapRouteCopyWith<$Res>  {
  factory $MapRouteCopyWith(MapRoute value, $Res Function(MapRoute) _then) = _$MapRouteCopyWithImpl;
@useResult
$Res call({
 GeoPoint origin, GeoPoint destination, String? originLabel, String? destinationLabel, double? distanceMeters, Duration? duration, String? encodedPolyline, List<GeoPoint> waypoints
});


$GeoPointCopyWith<$Res> get origin;$GeoPointCopyWith<$Res> get destination;

}
/// @nodoc
class _$MapRouteCopyWithImpl<$Res>
    implements $MapRouteCopyWith<$Res> {
  _$MapRouteCopyWithImpl(this._self, this._then);

  final MapRoute _self;
  final $Res Function(MapRoute) _then;

/// Create a copy of MapRoute
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? origin = null,Object? destination = null,Object? originLabel = freezed,Object? destinationLabel = freezed,Object? distanceMeters = freezed,Object? duration = freezed,Object? encodedPolyline = freezed,Object? waypoints = null,}) {
  return _then(_self.copyWith(
origin: null == origin ? _self.origin : origin // ignore: cast_nullable_to_non_nullable
as GeoPoint,destination: null == destination ? _self.destination : destination // ignore: cast_nullable_to_non_nullable
as GeoPoint,originLabel: freezed == originLabel ? _self.originLabel : originLabel // ignore: cast_nullable_to_non_nullable
as String?,destinationLabel: freezed == destinationLabel ? _self.destinationLabel : destinationLabel // ignore: cast_nullable_to_non_nullable
as String?,distanceMeters: freezed == distanceMeters ? _self.distanceMeters : distanceMeters // ignore: cast_nullable_to_non_nullable
as double?,duration: freezed == duration ? _self.duration : duration // ignore: cast_nullable_to_non_nullable
as Duration?,encodedPolyline: freezed == encodedPolyline ? _self.encodedPolyline : encodedPolyline // ignore: cast_nullable_to_non_nullable
as String?,waypoints: null == waypoints ? _self.waypoints : waypoints // ignore: cast_nullable_to_non_nullable
as List<GeoPoint>,
  ));
}
/// Create a copy of MapRoute
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$GeoPointCopyWith<$Res> get origin {
  
  return $GeoPointCopyWith<$Res>(_self.origin, (value) {
    return _then(_self.copyWith(origin: value));
  });
}/// Create a copy of MapRoute
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$GeoPointCopyWith<$Res> get destination {
  
  return $GeoPointCopyWith<$Res>(_self.destination, (value) {
    return _then(_self.copyWith(destination: value));
  });
}
}


/// Adds pattern-matching-related methods to [MapRoute].
extension MapRoutePatterns on MapRoute {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MapRoute value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MapRoute() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MapRoute value)  $default,){
final _that = this;
switch (_that) {
case _MapRoute():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MapRoute value)?  $default,){
final _that = this;
switch (_that) {
case _MapRoute() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( GeoPoint origin,  GeoPoint destination,  String? originLabel,  String? destinationLabel,  double? distanceMeters,  Duration? duration,  String? encodedPolyline,  List<GeoPoint> waypoints)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MapRoute() when $default != null:
return $default(_that.origin,_that.destination,_that.originLabel,_that.destinationLabel,_that.distanceMeters,_that.duration,_that.encodedPolyline,_that.waypoints);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( GeoPoint origin,  GeoPoint destination,  String? originLabel,  String? destinationLabel,  double? distanceMeters,  Duration? duration,  String? encodedPolyline,  List<GeoPoint> waypoints)  $default,) {final _that = this;
switch (_that) {
case _MapRoute():
return $default(_that.origin,_that.destination,_that.originLabel,_that.destinationLabel,_that.distanceMeters,_that.duration,_that.encodedPolyline,_that.waypoints);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( GeoPoint origin,  GeoPoint destination,  String? originLabel,  String? destinationLabel,  double? distanceMeters,  Duration? duration,  String? encodedPolyline,  List<GeoPoint> waypoints)?  $default,) {final _that = this;
switch (_that) {
case _MapRoute() when $default != null:
return $default(_that.origin,_that.destination,_that.originLabel,_that.destinationLabel,_that.distanceMeters,_that.duration,_that.encodedPolyline,_that.waypoints);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _MapRoute implements MapRoute {
  const _MapRoute({required this.origin, required this.destination, this.originLabel, this.destinationLabel, this.distanceMeters, this.duration, this.encodedPolyline, final  List<GeoPoint> waypoints = const <GeoPoint>[]}): _waypoints = waypoints;
  factory _MapRoute.fromJson(Map<String, dynamic> json) => _$MapRouteFromJson(json);

@override final  GeoPoint origin;
@override final  GeoPoint destination;
@override final  String? originLabel;
@override final  String? destinationLabel;
@override final  double? distanceMeters;
@override final  Duration? duration;
/// Google-style encoded polyline; decoded by a map widget later.
@override final  String? encodedPolyline;
 final  List<GeoPoint> _waypoints;
@override@JsonKey() List<GeoPoint> get waypoints {
  if (_waypoints is EqualUnmodifiableListView) return _waypoints;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_waypoints);
}


/// Create a copy of MapRoute
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MapRouteCopyWith<_MapRoute> get copyWith => __$MapRouteCopyWithImpl<_MapRoute>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MapRouteToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _MapRoute&&(identical(other.origin, origin) || other.origin == origin)&&(identical(other.destination, destination) || other.destination == destination)&&(identical(other.originLabel, originLabel) || other.originLabel == originLabel)&&(identical(other.destinationLabel, destinationLabel) || other.destinationLabel == destinationLabel)&&(identical(other.distanceMeters, distanceMeters) || other.distanceMeters == distanceMeters)&&(identical(other.duration, duration) || other.duration == duration)&&(identical(other.encodedPolyline, encodedPolyline) || other.encodedPolyline == encodedPolyline)&&const DeepCollectionEquality().equals(other._waypoints, _waypoints));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,origin,destination,originLabel,destinationLabel,distanceMeters,duration,encodedPolyline,const DeepCollectionEquality().hash(_waypoints));

@override
String toString() {
  return 'MapRoute(origin: $origin, destination: $destination, originLabel: $originLabel, destinationLabel: $destinationLabel, distanceMeters: $distanceMeters, duration: $duration, encodedPolyline: $encodedPolyline, waypoints: $waypoints)';
}


}

/// @nodoc
abstract mixin class _$MapRouteCopyWith<$Res> implements $MapRouteCopyWith<$Res> {
  factory _$MapRouteCopyWith(_MapRoute value, $Res Function(_MapRoute) _then) = __$MapRouteCopyWithImpl;
@override @useResult
$Res call({
 GeoPoint origin, GeoPoint destination, String? originLabel, String? destinationLabel, double? distanceMeters, Duration? duration, String? encodedPolyline, List<GeoPoint> waypoints
});


@override $GeoPointCopyWith<$Res> get origin;@override $GeoPointCopyWith<$Res> get destination;

}
/// @nodoc
class __$MapRouteCopyWithImpl<$Res>
    implements _$MapRouteCopyWith<$Res> {
  __$MapRouteCopyWithImpl(this._self, this._then);

  final _MapRoute _self;
  final $Res Function(_MapRoute) _then;

/// Create a copy of MapRoute
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? origin = null,Object? destination = null,Object? originLabel = freezed,Object? destinationLabel = freezed,Object? distanceMeters = freezed,Object? duration = freezed,Object? encodedPolyline = freezed,Object? waypoints = null,}) {
  return _then(_MapRoute(
origin: null == origin ? _self.origin : origin // ignore: cast_nullable_to_non_nullable
as GeoPoint,destination: null == destination ? _self.destination : destination // ignore: cast_nullable_to_non_nullable
as GeoPoint,originLabel: freezed == originLabel ? _self.originLabel : originLabel // ignore: cast_nullable_to_non_nullable
as String?,destinationLabel: freezed == destinationLabel ? _self.destinationLabel : destinationLabel // ignore: cast_nullable_to_non_nullable
as String?,distanceMeters: freezed == distanceMeters ? _self.distanceMeters : distanceMeters // ignore: cast_nullable_to_non_nullable
as double?,duration: freezed == duration ? _self.duration : duration // ignore: cast_nullable_to_non_nullable
as Duration?,encodedPolyline: freezed == encodedPolyline ? _self.encodedPolyline : encodedPolyline // ignore: cast_nullable_to_non_nullable
as String?,waypoints: null == waypoints ? _self._waypoints : waypoints // ignore: cast_nullable_to_non_nullable
as List<GeoPoint>,
  ));
}

/// Create a copy of MapRoute
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$GeoPointCopyWith<$Res> get origin {
  
  return $GeoPointCopyWith<$Res>(_self.origin, (value) {
    return _then(_self.copyWith(origin: value));
  });
}/// Create a copy of MapRoute
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$GeoPointCopyWith<$Res> get destination {
  
  return $GeoPointCopyWith<$Res>(_self.destination, (value) {
    return _then(_self.copyWith(destination: value));
  });
}
}


/// @nodoc
mixin _$WeatherData {

 String get locationName; double get temperatureC; String get condition;/// Icon key from a fixed vocabulary (e.g. `clear`, `cloudy`, `rain`).
 String? get iconKey; double? get feelsLikeC; double? get humidityPercent; double? get windKph; List<DailyForecast> get forecast;
/// Create a copy of WeatherData
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$WeatherDataCopyWith<WeatherData> get copyWith => _$WeatherDataCopyWithImpl<WeatherData>(this as WeatherData, _$identity);

  /// Serializes this WeatherData to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is WeatherData&&(identical(other.locationName, locationName) || other.locationName == locationName)&&(identical(other.temperatureC, temperatureC) || other.temperatureC == temperatureC)&&(identical(other.condition, condition) || other.condition == condition)&&(identical(other.iconKey, iconKey) || other.iconKey == iconKey)&&(identical(other.feelsLikeC, feelsLikeC) || other.feelsLikeC == feelsLikeC)&&(identical(other.humidityPercent, humidityPercent) || other.humidityPercent == humidityPercent)&&(identical(other.windKph, windKph) || other.windKph == windKph)&&const DeepCollectionEquality().equals(other.forecast, forecast));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,locationName,temperatureC,condition,iconKey,feelsLikeC,humidityPercent,windKph,const DeepCollectionEquality().hash(forecast));

@override
String toString() {
  return 'WeatherData(locationName: $locationName, temperatureC: $temperatureC, condition: $condition, iconKey: $iconKey, feelsLikeC: $feelsLikeC, humidityPercent: $humidityPercent, windKph: $windKph, forecast: $forecast)';
}


}

/// @nodoc
abstract mixin class $WeatherDataCopyWith<$Res>  {
  factory $WeatherDataCopyWith(WeatherData value, $Res Function(WeatherData) _then) = _$WeatherDataCopyWithImpl;
@useResult
$Res call({
 String locationName, double temperatureC, String condition, String? iconKey, double? feelsLikeC, double? humidityPercent, double? windKph, List<DailyForecast> forecast
});




}
/// @nodoc
class _$WeatherDataCopyWithImpl<$Res>
    implements $WeatherDataCopyWith<$Res> {
  _$WeatherDataCopyWithImpl(this._self, this._then);

  final WeatherData _self;
  final $Res Function(WeatherData) _then;

/// Create a copy of WeatherData
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? locationName = null,Object? temperatureC = null,Object? condition = null,Object? iconKey = freezed,Object? feelsLikeC = freezed,Object? humidityPercent = freezed,Object? windKph = freezed,Object? forecast = null,}) {
  return _then(_self.copyWith(
locationName: null == locationName ? _self.locationName : locationName // ignore: cast_nullable_to_non_nullable
as String,temperatureC: null == temperatureC ? _self.temperatureC : temperatureC // ignore: cast_nullable_to_non_nullable
as double,condition: null == condition ? _self.condition : condition // ignore: cast_nullable_to_non_nullable
as String,iconKey: freezed == iconKey ? _self.iconKey : iconKey // ignore: cast_nullable_to_non_nullable
as String?,feelsLikeC: freezed == feelsLikeC ? _self.feelsLikeC : feelsLikeC // ignore: cast_nullable_to_non_nullable
as double?,humidityPercent: freezed == humidityPercent ? _self.humidityPercent : humidityPercent // ignore: cast_nullable_to_non_nullable
as double?,windKph: freezed == windKph ? _self.windKph : windKph // ignore: cast_nullable_to_non_nullable
as double?,forecast: null == forecast ? _self.forecast : forecast // ignore: cast_nullable_to_non_nullable
as List<DailyForecast>,
  ));
}

}


/// Adds pattern-matching-related methods to [WeatherData].
extension WeatherDataPatterns on WeatherData {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _WeatherData value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _WeatherData() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _WeatherData value)  $default,){
final _that = this;
switch (_that) {
case _WeatherData():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _WeatherData value)?  $default,){
final _that = this;
switch (_that) {
case _WeatherData() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String locationName,  double temperatureC,  String condition,  String? iconKey,  double? feelsLikeC,  double? humidityPercent,  double? windKph,  List<DailyForecast> forecast)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _WeatherData() when $default != null:
return $default(_that.locationName,_that.temperatureC,_that.condition,_that.iconKey,_that.feelsLikeC,_that.humidityPercent,_that.windKph,_that.forecast);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String locationName,  double temperatureC,  String condition,  String? iconKey,  double? feelsLikeC,  double? humidityPercent,  double? windKph,  List<DailyForecast> forecast)  $default,) {final _that = this;
switch (_that) {
case _WeatherData():
return $default(_that.locationName,_that.temperatureC,_that.condition,_that.iconKey,_that.feelsLikeC,_that.humidityPercent,_that.windKph,_that.forecast);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String locationName,  double temperatureC,  String condition,  String? iconKey,  double? feelsLikeC,  double? humidityPercent,  double? windKph,  List<DailyForecast> forecast)?  $default,) {final _that = this;
switch (_that) {
case _WeatherData() when $default != null:
return $default(_that.locationName,_that.temperatureC,_that.condition,_that.iconKey,_that.feelsLikeC,_that.humidityPercent,_that.windKph,_that.forecast);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _WeatherData implements WeatherData {
  const _WeatherData({required this.locationName, required this.temperatureC, required this.condition, this.iconKey, this.feelsLikeC, this.humidityPercent, this.windKph, final  List<DailyForecast> forecast = const <DailyForecast>[]}): _forecast = forecast;
  factory _WeatherData.fromJson(Map<String, dynamic> json) => _$WeatherDataFromJson(json);

@override final  String locationName;
@override final  double temperatureC;
@override final  String condition;
/// Icon key from a fixed vocabulary (e.g. `clear`, `cloudy`, `rain`).
@override final  String? iconKey;
@override final  double? feelsLikeC;
@override final  double? humidityPercent;
@override final  double? windKph;
 final  List<DailyForecast> _forecast;
@override@JsonKey() List<DailyForecast> get forecast {
  if (_forecast is EqualUnmodifiableListView) return _forecast;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_forecast);
}


/// Create a copy of WeatherData
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$WeatherDataCopyWith<_WeatherData> get copyWith => __$WeatherDataCopyWithImpl<_WeatherData>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$WeatherDataToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _WeatherData&&(identical(other.locationName, locationName) || other.locationName == locationName)&&(identical(other.temperatureC, temperatureC) || other.temperatureC == temperatureC)&&(identical(other.condition, condition) || other.condition == condition)&&(identical(other.iconKey, iconKey) || other.iconKey == iconKey)&&(identical(other.feelsLikeC, feelsLikeC) || other.feelsLikeC == feelsLikeC)&&(identical(other.humidityPercent, humidityPercent) || other.humidityPercent == humidityPercent)&&(identical(other.windKph, windKph) || other.windKph == windKph)&&const DeepCollectionEquality().equals(other._forecast, _forecast));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,locationName,temperatureC,condition,iconKey,feelsLikeC,humidityPercent,windKph,const DeepCollectionEquality().hash(_forecast));

@override
String toString() {
  return 'WeatherData(locationName: $locationName, temperatureC: $temperatureC, condition: $condition, iconKey: $iconKey, feelsLikeC: $feelsLikeC, humidityPercent: $humidityPercent, windKph: $windKph, forecast: $forecast)';
}


}

/// @nodoc
abstract mixin class _$WeatherDataCopyWith<$Res> implements $WeatherDataCopyWith<$Res> {
  factory _$WeatherDataCopyWith(_WeatherData value, $Res Function(_WeatherData) _then) = __$WeatherDataCopyWithImpl;
@override @useResult
$Res call({
 String locationName, double temperatureC, String condition, String? iconKey, double? feelsLikeC, double? humidityPercent, double? windKph, List<DailyForecast> forecast
});




}
/// @nodoc
class __$WeatherDataCopyWithImpl<$Res>
    implements _$WeatherDataCopyWith<$Res> {
  __$WeatherDataCopyWithImpl(this._self, this._then);

  final _WeatherData _self;
  final $Res Function(_WeatherData) _then;

/// Create a copy of WeatherData
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? locationName = null,Object? temperatureC = null,Object? condition = null,Object? iconKey = freezed,Object? feelsLikeC = freezed,Object? humidityPercent = freezed,Object? windKph = freezed,Object? forecast = null,}) {
  return _then(_WeatherData(
locationName: null == locationName ? _self.locationName : locationName // ignore: cast_nullable_to_non_nullable
as String,temperatureC: null == temperatureC ? _self.temperatureC : temperatureC // ignore: cast_nullable_to_non_nullable
as double,condition: null == condition ? _self.condition : condition // ignore: cast_nullable_to_non_nullable
as String,iconKey: freezed == iconKey ? _self.iconKey : iconKey // ignore: cast_nullable_to_non_nullable
as String?,feelsLikeC: freezed == feelsLikeC ? _self.feelsLikeC : feelsLikeC // ignore: cast_nullable_to_non_nullable
as double?,humidityPercent: freezed == humidityPercent ? _self.humidityPercent : humidityPercent // ignore: cast_nullable_to_non_nullable
as double?,windKph: freezed == windKph ? _self.windKph : windKph // ignore: cast_nullable_to_non_nullable
as double?,forecast: null == forecast ? _self._forecast : forecast // ignore: cast_nullable_to_non_nullable
as List<DailyForecast>,
  ));
}


}


/// @nodoc
mixin _$DailyForecast {

 DateTime get date; double get highC; double get lowC; String get condition; String? get iconKey;
/// Create a copy of DailyForecast
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DailyForecastCopyWith<DailyForecast> get copyWith => _$DailyForecastCopyWithImpl<DailyForecast>(this as DailyForecast, _$identity);

  /// Serializes this DailyForecast to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DailyForecast&&(identical(other.date, date) || other.date == date)&&(identical(other.highC, highC) || other.highC == highC)&&(identical(other.lowC, lowC) || other.lowC == lowC)&&(identical(other.condition, condition) || other.condition == condition)&&(identical(other.iconKey, iconKey) || other.iconKey == iconKey));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,date,highC,lowC,condition,iconKey);

@override
String toString() {
  return 'DailyForecast(date: $date, highC: $highC, lowC: $lowC, condition: $condition, iconKey: $iconKey)';
}


}

/// @nodoc
abstract mixin class $DailyForecastCopyWith<$Res>  {
  factory $DailyForecastCopyWith(DailyForecast value, $Res Function(DailyForecast) _then) = _$DailyForecastCopyWithImpl;
@useResult
$Res call({
 DateTime date, double highC, double lowC, String condition, String? iconKey
});




}
/// @nodoc
class _$DailyForecastCopyWithImpl<$Res>
    implements $DailyForecastCopyWith<$Res> {
  _$DailyForecastCopyWithImpl(this._self, this._then);

  final DailyForecast _self;
  final $Res Function(DailyForecast) _then;

/// Create a copy of DailyForecast
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? date = null,Object? highC = null,Object? lowC = null,Object? condition = null,Object? iconKey = freezed,}) {
  return _then(_self.copyWith(
date: null == date ? _self.date : date // ignore: cast_nullable_to_non_nullable
as DateTime,highC: null == highC ? _self.highC : highC // ignore: cast_nullable_to_non_nullable
as double,lowC: null == lowC ? _self.lowC : lowC // ignore: cast_nullable_to_non_nullable
as double,condition: null == condition ? _self.condition : condition // ignore: cast_nullable_to_non_nullable
as String,iconKey: freezed == iconKey ? _self.iconKey : iconKey // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [DailyForecast].
extension DailyForecastPatterns on DailyForecast {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _DailyForecast value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _DailyForecast() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _DailyForecast value)  $default,){
final _that = this;
switch (_that) {
case _DailyForecast():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _DailyForecast value)?  $default,){
final _that = this;
switch (_that) {
case _DailyForecast() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( DateTime date,  double highC,  double lowC,  String condition,  String? iconKey)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DailyForecast() when $default != null:
return $default(_that.date,_that.highC,_that.lowC,_that.condition,_that.iconKey);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( DateTime date,  double highC,  double lowC,  String condition,  String? iconKey)  $default,) {final _that = this;
switch (_that) {
case _DailyForecast():
return $default(_that.date,_that.highC,_that.lowC,_that.condition,_that.iconKey);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( DateTime date,  double highC,  double lowC,  String condition,  String? iconKey)?  $default,) {final _that = this;
switch (_that) {
case _DailyForecast() when $default != null:
return $default(_that.date,_that.highC,_that.lowC,_that.condition,_that.iconKey);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _DailyForecast implements DailyForecast {
  const _DailyForecast({required this.date, required this.highC, required this.lowC, required this.condition, this.iconKey});
  factory _DailyForecast.fromJson(Map<String, dynamic> json) => _$DailyForecastFromJson(json);

@override final  DateTime date;
@override final  double highC;
@override final  double lowC;
@override final  String condition;
@override final  String? iconKey;

/// Create a copy of DailyForecast
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DailyForecastCopyWith<_DailyForecast> get copyWith => __$DailyForecastCopyWithImpl<_DailyForecast>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$DailyForecastToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _DailyForecast&&(identical(other.date, date) || other.date == date)&&(identical(other.highC, highC) || other.highC == highC)&&(identical(other.lowC, lowC) || other.lowC == lowC)&&(identical(other.condition, condition) || other.condition == condition)&&(identical(other.iconKey, iconKey) || other.iconKey == iconKey));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,date,highC,lowC,condition,iconKey);

@override
String toString() {
  return 'DailyForecast(date: $date, highC: $highC, lowC: $lowC, condition: $condition, iconKey: $iconKey)';
}


}

/// @nodoc
abstract mixin class _$DailyForecastCopyWith<$Res> implements $DailyForecastCopyWith<$Res> {
  factory _$DailyForecastCopyWith(_DailyForecast value, $Res Function(_DailyForecast) _then) = __$DailyForecastCopyWithImpl;
@override @useResult
$Res call({
 DateTime date, double highC, double lowC, String condition, String? iconKey
});




}
/// @nodoc
class __$DailyForecastCopyWithImpl<$Res>
    implements _$DailyForecastCopyWith<$Res> {
  __$DailyForecastCopyWithImpl(this._self, this._then);

  final _DailyForecast _self;
  final $Res Function(_DailyForecast) _then;

/// Create a copy of DailyForecast
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? date = null,Object? highC = null,Object? lowC = null,Object? condition = null,Object? iconKey = freezed,}) {
  return _then(_DailyForecast(
date: null == date ? _self.date : date // ignore: cast_nullable_to_non_nullable
as DateTime,highC: null == highC ? _self.highC : highC // ignore: cast_nullable_to_non_nullable
as double,lowC: null == lowC ? _self.lowC : lowC // ignore: cast_nullable_to_non_nullable
as double,condition: null == condition ? _self.condition : condition // ignore: cast_nullable_to_non_nullable
as String,iconKey: freezed == iconKey ? _self.iconKey : iconKey // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$MediaItem {

 MediaKind get kind; Uri get uri; String? get title; Uri? get thumbnailUri; Duration? get duration; String? get mimeType;
/// Create a copy of MediaItem
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MediaItemCopyWith<MediaItem> get copyWith => _$MediaItemCopyWithImpl<MediaItem>(this as MediaItem, _$identity);

  /// Serializes this MediaItem to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MediaItem&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.uri, uri) || other.uri == uri)&&(identical(other.title, title) || other.title == title)&&(identical(other.thumbnailUri, thumbnailUri) || other.thumbnailUri == thumbnailUri)&&(identical(other.duration, duration) || other.duration == duration)&&(identical(other.mimeType, mimeType) || other.mimeType == mimeType));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,kind,uri,title,thumbnailUri,duration,mimeType);

@override
String toString() {
  return 'MediaItem(kind: $kind, uri: $uri, title: $title, thumbnailUri: $thumbnailUri, duration: $duration, mimeType: $mimeType)';
}


}

/// @nodoc
abstract mixin class $MediaItemCopyWith<$Res>  {
  factory $MediaItemCopyWith(MediaItem value, $Res Function(MediaItem) _then) = _$MediaItemCopyWithImpl;
@useResult
$Res call({
 MediaKind kind, Uri uri, String? title, Uri? thumbnailUri, Duration? duration, String? mimeType
});




}
/// @nodoc
class _$MediaItemCopyWithImpl<$Res>
    implements $MediaItemCopyWith<$Res> {
  _$MediaItemCopyWithImpl(this._self, this._then);

  final MediaItem _self;
  final $Res Function(MediaItem) _then;

/// Create a copy of MediaItem
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? kind = null,Object? uri = null,Object? title = freezed,Object? thumbnailUri = freezed,Object? duration = freezed,Object? mimeType = freezed,}) {
  return _then(_self.copyWith(
kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as MediaKind,uri: null == uri ? _self.uri : uri // ignore: cast_nullable_to_non_nullable
as Uri,title: freezed == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String?,thumbnailUri: freezed == thumbnailUri ? _self.thumbnailUri : thumbnailUri // ignore: cast_nullable_to_non_nullable
as Uri?,duration: freezed == duration ? _self.duration : duration // ignore: cast_nullable_to_non_nullable
as Duration?,mimeType: freezed == mimeType ? _self.mimeType : mimeType // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [MediaItem].
extension MediaItemPatterns on MediaItem {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MediaItem value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MediaItem() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MediaItem value)  $default,){
final _that = this;
switch (_that) {
case _MediaItem():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MediaItem value)?  $default,){
final _that = this;
switch (_that) {
case _MediaItem() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( MediaKind kind,  Uri uri,  String? title,  Uri? thumbnailUri,  Duration? duration,  String? mimeType)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MediaItem() when $default != null:
return $default(_that.kind,_that.uri,_that.title,_that.thumbnailUri,_that.duration,_that.mimeType);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( MediaKind kind,  Uri uri,  String? title,  Uri? thumbnailUri,  Duration? duration,  String? mimeType)  $default,) {final _that = this;
switch (_that) {
case _MediaItem():
return $default(_that.kind,_that.uri,_that.title,_that.thumbnailUri,_that.duration,_that.mimeType);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( MediaKind kind,  Uri uri,  String? title,  Uri? thumbnailUri,  Duration? duration,  String? mimeType)?  $default,) {final _that = this;
switch (_that) {
case _MediaItem() when $default != null:
return $default(_that.kind,_that.uri,_that.title,_that.thumbnailUri,_that.duration,_that.mimeType);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _MediaItem implements MediaItem {
  const _MediaItem({required this.kind, required this.uri, this.title, this.thumbnailUri, this.duration, this.mimeType});
  factory _MediaItem.fromJson(Map<String, dynamic> json) => _$MediaItemFromJson(json);

@override final  MediaKind kind;
@override final  Uri uri;
@override final  String? title;
@override final  Uri? thumbnailUri;
@override final  Duration? duration;
@override final  String? mimeType;

/// Create a copy of MediaItem
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MediaItemCopyWith<_MediaItem> get copyWith => __$MediaItemCopyWithImpl<_MediaItem>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MediaItemToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _MediaItem&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.uri, uri) || other.uri == uri)&&(identical(other.title, title) || other.title == title)&&(identical(other.thumbnailUri, thumbnailUri) || other.thumbnailUri == thumbnailUri)&&(identical(other.duration, duration) || other.duration == duration)&&(identical(other.mimeType, mimeType) || other.mimeType == mimeType));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,kind,uri,title,thumbnailUri,duration,mimeType);

@override
String toString() {
  return 'MediaItem(kind: $kind, uri: $uri, title: $title, thumbnailUri: $thumbnailUri, duration: $duration, mimeType: $mimeType)';
}


}

/// @nodoc
abstract mixin class _$MediaItemCopyWith<$Res> implements $MediaItemCopyWith<$Res> {
  factory _$MediaItemCopyWith(_MediaItem value, $Res Function(_MediaItem) _then) = __$MediaItemCopyWithImpl;
@override @useResult
$Res call({
 MediaKind kind, Uri uri, String? title, Uri? thumbnailUri, Duration? duration, String? mimeType
});




}
/// @nodoc
class __$MediaItemCopyWithImpl<$Res>
    implements _$MediaItemCopyWith<$Res> {
  __$MediaItemCopyWithImpl(this._self, this._then);

  final _MediaItem _self;
  final $Res Function(_MediaItem) _then;

/// Create a copy of MediaItem
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? kind = null,Object? uri = null,Object? title = freezed,Object? thumbnailUri = freezed,Object? duration = freezed,Object? mimeType = freezed,}) {
  return _then(_MediaItem(
kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as MediaKind,uri: null == uri ? _self.uri : uri // ignore: cast_nullable_to_non_nullable
as Uri,title: freezed == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String?,thumbnailUri: freezed == thumbnailUri ? _self.thumbnailUri : thumbnailUri // ignore: cast_nullable_to_non_nullable
as Uri?,duration: freezed == duration ? _self.duration : duration // ignore: cast_nullable_to_non_nullable
as Duration?,mimeType: freezed == mimeType ? _self.mimeType : mimeType // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$FormFieldSpec {

 String get id; String get label; FormFieldType get type; bool get required; String? get placeholder; String? get helperText;/// For [FormFieldType.select].
 List<SelectionOption> get options; Object? get defaultValue;
/// Create a copy of FormFieldSpec
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FormFieldSpecCopyWith<FormFieldSpec> get copyWith => _$FormFieldSpecCopyWithImpl<FormFieldSpec>(this as FormFieldSpec, _$identity);

  /// Serializes this FormFieldSpec to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FormFieldSpec&&(identical(other.id, id) || other.id == id)&&(identical(other.label, label) || other.label == label)&&(identical(other.type, type) || other.type == type)&&(identical(other.required, required) || other.required == required)&&(identical(other.placeholder, placeholder) || other.placeholder == placeholder)&&(identical(other.helperText, helperText) || other.helperText == helperText)&&const DeepCollectionEquality().equals(other.options, options)&&const DeepCollectionEquality().equals(other.defaultValue, defaultValue));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,label,type,required,placeholder,helperText,const DeepCollectionEquality().hash(options),const DeepCollectionEquality().hash(defaultValue));

@override
String toString() {
  return 'FormFieldSpec(id: $id, label: $label, type: $type, required: $required, placeholder: $placeholder, helperText: $helperText, options: $options, defaultValue: $defaultValue)';
}


}

/// @nodoc
abstract mixin class $FormFieldSpecCopyWith<$Res>  {
  factory $FormFieldSpecCopyWith(FormFieldSpec value, $Res Function(FormFieldSpec) _then) = _$FormFieldSpecCopyWithImpl;
@useResult
$Res call({
 String id, String label, FormFieldType type, bool required, String? placeholder, String? helperText, List<SelectionOption> options, Object? defaultValue
});




}
/// @nodoc
class _$FormFieldSpecCopyWithImpl<$Res>
    implements $FormFieldSpecCopyWith<$Res> {
  _$FormFieldSpecCopyWithImpl(this._self, this._then);

  final FormFieldSpec _self;
  final $Res Function(FormFieldSpec) _then;

/// Create a copy of FormFieldSpec
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? label = null,Object? type = null,Object? required = null,Object? placeholder = freezed,Object? helperText = freezed,Object? options = null,Object? defaultValue = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,label: null == label ? _self.label : label // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as FormFieldType,required: null == required ? _self.required : required // ignore: cast_nullable_to_non_nullable
as bool,placeholder: freezed == placeholder ? _self.placeholder : placeholder // ignore: cast_nullable_to_non_nullable
as String?,helperText: freezed == helperText ? _self.helperText : helperText // ignore: cast_nullable_to_non_nullable
as String?,options: null == options ? _self.options : options // ignore: cast_nullable_to_non_nullable
as List<SelectionOption>,defaultValue: freezed == defaultValue ? _self.defaultValue : defaultValue ,
  ));
}

}


/// Adds pattern-matching-related methods to [FormFieldSpec].
extension FormFieldSpecPatterns on FormFieldSpec {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _FormFieldSpec value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _FormFieldSpec() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _FormFieldSpec value)  $default,){
final _that = this;
switch (_that) {
case _FormFieldSpec():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _FormFieldSpec value)?  $default,){
final _that = this;
switch (_that) {
case _FormFieldSpec() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String label,  FormFieldType type,  bool required,  String? placeholder,  String? helperText,  List<SelectionOption> options,  Object? defaultValue)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _FormFieldSpec() when $default != null:
return $default(_that.id,_that.label,_that.type,_that.required,_that.placeholder,_that.helperText,_that.options,_that.defaultValue);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String label,  FormFieldType type,  bool required,  String? placeholder,  String? helperText,  List<SelectionOption> options,  Object? defaultValue)  $default,) {final _that = this;
switch (_that) {
case _FormFieldSpec():
return $default(_that.id,_that.label,_that.type,_that.required,_that.placeholder,_that.helperText,_that.options,_that.defaultValue);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String label,  FormFieldType type,  bool required,  String? placeholder,  String? helperText,  List<SelectionOption> options,  Object? defaultValue)?  $default,) {final _that = this;
switch (_that) {
case _FormFieldSpec() when $default != null:
return $default(_that.id,_that.label,_that.type,_that.required,_that.placeholder,_that.helperText,_that.options,_that.defaultValue);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _FormFieldSpec implements FormFieldSpec {
  const _FormFieldSpec({required this.id, required this.label, required this.type, this.required = false, this.placeholder, this.helperText, final  List<SelectionOption> options = const <SelectionOption>[], this.defaultValue}): _options = options;
  factory _FormFieldSpec.fromJson(Map<String, dynamic> json) => _$FormFieldSpecFromJson(json);

@override final  String id;
@override final  String label;
@override final  FormFieldType type;
@override@JsonKey() final  bool required;
@override final  String? placeholder;
@override final  String? helperText;
/// For [FormFieldType.select].
 final  List<SelectionOption> _options;
/// For [FormFieldType.select].
@override@JsonKey() List<SelectionOption> get options {
  if (_options is EqualUnmodifiableListView) return _options;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_options);
}

@override final  Object? defaultValue;

/// Create a copy of FormFieldSpec
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$FormFieldSpecCopyWith<_FormFieldSpec> get copyWith => __$FormFieldSpecCopyWithImpl<_FormFieldSpec>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$FormFieldSpecToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _FormFieldSpec&&(identical(other.id, id) || other.id == id)&&(identical(other.label, label) || other.label == label)&&(identical(other.type, type) || other.type == type)&&(identical(other.required, required) || other.required == required)&&(identical(other.placeholder, placeholder) || other.placeholder == placeholder)&&(identical(other.helperText, helperText) || other.helperText == helperText)&&const DeepCollectionEquality().equals(other._options, _options)&&const DeepCollectionEquality().equals(other.defaultValue, defaultValue));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,label,type,required,placeholder,helperText,const DeepCollectionEquality().hash(_options),const DeepCollectionEquality().hash(defaultValue));

@override
String toString() {
  return 'FormFieldSpec(id: $id, label: $label, type: $type, required: $required, placeholder: $placeholder, helperText: $helperText, options: $options, defaultValue: $defaultValue)';
}


}

/// @nodoc
abstract mixin class _$FormFieldSpecCopyWith<$Res> implements $FormFieldSpecCopyWith<$Res> {
  factory _$FormFieldSpecCopyWith(_FormFieldSpec value, $Res Function(_FormFieldSpec) _then) = __$FormFieldSpecCopyWithImpl;
@override @useResult
$Res call({
 String id, String label, FormFieldType type, bool required, String? placeholder, String? helperText, List<SelectionOption> options, Object? defaultValue
});




}
/// @nodoc
class __$FormFieldSpecCopyWithImpl<$Res>
    implements _$FormFieldSpecCopyWith<$Res> {
  __$FormFieldSpecCopyWithImpl(this._self, this._then);

  final _FormFieldSpec _self;
  final $Res Function(_FormFieldSpec) _then;

/// Create a copy of FormFieldSpec
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? label = null,Object? type = null,Object? required = null,Object? placeholder = freezed,Object? helperText = freezed,Object? options = null,Object? defaultValue = freezed,}) {
  return _then(_FormFieldSpec(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,label: null == label ? _self.label : label // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as FormFieldType,required: null == required ? _self.required : required // ignore: cast_nullable_to_non_nullable
as bool,placeholder: freezed == placeholder ? _self.placeholder : placeholder // ignore: cast_nullable_to_non_nullable
as String?,helperText: freezed == helperText ? _self.helperText : helperText // ignore: cast_nullable_to_non_nullable
as String?,options: null == options ? _self._options : options // ignore: cast_nullable_to_non_nullable
as List<SelectionOption>,defaultValue: freezed == defaultValue ? _self.defaultValue : defaultValue ,
  ));
}


}


/// @nodoc
mixin _$FormSpec {

 String get id; String get title; List<FormFieldSpec> get fields; String? get description; String get submitLabel;
/// Create a copy of FormSpec
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FormSpecCopyWith<FormSpec> get copyWith => _$FormSpecCopyWithImpl<FormSpec>(this as FormSpec, _$identity);

  /// Serializes this FormSpec to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FormSpec&&(identical(other.id, id) || other.id == id)&&(identical(other.title, title) || other.title == title)&&const DeepCollectionEquality().equals(other.fields, fields)&&(identical(other.description, description) || other.description == description)&&(identical(other.submitLabel, submitLabel) || other.submitLabel == submitLabel));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,title,const DeepCollectionEquality().hash(fields),description,submitLabel);

@override
String toString() {
  return 'FormSpec(id: $id, title: $title, fields: $fields, description: $description, submitLabel: $submitLabel)';
}


}

/// @nodoc
abstract mixin class $FormSpecCopyWith<$Res>  {
  factory $FormSpecCopyWith(FormSpec value, $Res Function(FormSpec) _then) = _$FormSpecCopyWithImpl;
@useResult
$Res call({
 String id, String title, List<FormFieldSpec> fields, String? description, String submitLabel
});




}
/// @nodoc
class _$FormSpecCopyWithImpl<$Res>
    implements $FormSpecCopyWith<$Res> {
  _$FormSpecCopyWithImpl(this._self, this._then);

  final FormSpec _self;
  final $Res Function(FormSpec) _then;

/// Create a copy of FormSpec
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? title = null,Object? fields = null,Object? description = freezed,Object? submitLabel = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,fields: null == fields ? _self.fields : fields // ignore: cast_nullable_to_non_nullable
as List<FormFieldSpec>,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,submitLabel: null == submitLabel ? _self.submitLabel : submitLabel // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [FormSpec].
extension FormSpecPatterns on FormSpec {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _FormSpec value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _FormSpec() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _FormSpec value)  $default,){
final _that = this;
switch (_that) {
case _FormSpec():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _FormSpec value)?  $default,){
final _that = this;
switch (_that) {
case _FormSpec() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String title,  List<FormFieldSpec> fields,  String? description,  String submitLabel)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _FormSpec() when $default != null:
return $default(_that.id,_that.title,_that.fields,_that.description,_that.submitLabel);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String title,  List<FormFieldSpec> fields,  String? description,  String submitLabel)  $default,) {final _that = this;
switch (_that) {
case _FormSpec():
return $default(_that.id,_that.title,_that.fields,_that.description,_that.submitLabel);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String title,  List<FormFieldSpec> fields,  String? description,  String submitLabel)?  $default,) {final _that = this;
switch (_that) {
case _FormSpec() when $default != null:
return $default(_that.id,_that.title,_that.fields,_that.description,_that.submitLabel);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _FormSpec implements FormSpec {
  const _FormSpec({required this.id, required this.title, required final  List<FormFieldSpec> fields, this.description, this.submitLabel = 'Submit'}): _fields = fields;
  factory _FormSpec.fromJson(Map<String, dynamic> json) => _$FormSpecFromJson(json);

@override final  String id;
@override final  String title;
 final  List<FormFieldSpec> _fields;
@override List<FormFieldSpec> get fields {
  if (_fields is EqualUnmodifiableListView) return _fields;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_fields);
}

@override final  String? description;
@override@JsonKey() final  String submitLabel;

/// Create a copy of FormSpec
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$FormSpecCopyWith<_FormSpec> get copyWith => __$FormSpecCopyWithImpl<_FormSpec>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$FormSpecToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _FormSpec&&(identical(other.id, id) || other.id == id)&&(identical(other.title, title) || other.title == title)&&const DeepCollectionEquality().equals(other._fields, _fields)&&(identical(other.description, description) || other.description == description)&&(identical(other.submitLabel, submitLabel) || other.submitLabel == submitLabel));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,title,const DeepCollectionEquality().hash(_fields),description,submitLabel);

@override
String toString() {
  return 'FormSpec(id: $id, title: $title, fields: $fields, description: $description, submitLabel: $submitLabel)';
}


}

/// @nodoc
abstract mixin class _$FormSpecCopyWith<$Res> implements $FormSpecCopyWith<$Res> {
  factory _$FormSpecCopyWith(_FormSpec value, $Res Function(_FormSpec) _then) = __$FormSpecCopyWithImpl;
@override @useResult
$Res call({
 String id, String title, List<FormFieldSpec> fields, String? description, String submitLabel
});




}
/// @nodoc
class __$FormSpecCopyWithImpl<$Res>
    implements _$FormSpecCopyWith<$Res> {
  __$FormSpecCopyWithImpl(this._self, this._then);

  final _FormSpec _self;
  final $Res Function(_FormSpec) _then;

/// Create a copy of FormSpec
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? title = null,Object? fields = null,Object? description = freezed,Object? submitLabel = null,}) {
  return _then(_FormSpec(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,fields: null == fields ? _self._fields : fields // ignore: cast_nullable_to_non_nullable
as List<FormFieldSpec>,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,submitLabel: null == submitLabel ? _self.submitLabel : submitLabel // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$SelectionOption {

 String get id; String get label; String? get description; Uri? get imageUri;
/// Create a copy of SelectionOption
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SelectionOptionCopyWith<SelectionOption> get copyWith => _$SelectionOptionCopyWithImpl<SelectionOption>(this as SelectionOption, _$identity);

  /// Serializes this SelectionOption to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SelectionOption&&(identical(other.id, id) || other.id == id)&&(identical(other.label, label) || other.label == label)&&(identical(other.description, description) || other.description == description)&&(identical(other.imageUri, imageUri) || other.imageUri == imageUri));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,label,description,imageUri);

@override
String toString() {
  return 'SelectionOption(id: $id, label: $label, description: $description, imageUri: $imageUri)';
}


}

/// @nodoc
abstract mixin class $SelectionOptionCopyWith<$Res>  {
  factory $SelectionOptionCopyWith(SelectionOption value, $Res Function(SelectionOption) _then) = _$SelectionOptionCopyWithImpl;
@useResult
$Res call({
 String id, String label, String? description, Uri? imageUri
});




}
/// @nodoc
class _$SelectionOptionCopyWithImpl<$Res>
    implements $SelectionOptionCopyWith<$Res> {
  _$SelectionOptionCopyWithImpl(this._self, this._then);

  final SelectionOption _self;
  final $Res Function(SelectionOption) _then;

/// Create a copy of SelectionOption
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? label = null,Object? description = freezed,Object? imageUri = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,label: null == label ? _self.label : label // ignore: cast_nullable_to_non_nullable
as String,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,imageUri: freezed == imageUri ? _self.imageUri : imageUri // ignore: cast_nullable_to_non_nullable
as Uri?,
  ));
}

}


/// Adds pattern-matching-related methods to [SelectionOption].
extension SelectionOptionPatterns on SelectionOption {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SelectionOption value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SelectionOption() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SelectionOption value)  $default,){
final _that = this;
switch (_that) {
case _SelectionOption():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SelectionOption value)?  $default,){
final _that = this;
switch (_that) {
case _SelectionOption() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String label,  String? description,  Uri? imageUri)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SelectionOption() when $default != null:
return $default(_that.id,_that.label,_that.description,_that.imageUri);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String label,  String? description,  Uri? imageUri)  $default,) {final _that = this;
switch (_that) {
case _SelectionOption():
return $default(_that.id,_that.label,_that.description,_that.imageUri);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String label,  String? description,  Uri? imageUri)?  $default,) {final _that = this;
switch (_that) {
case _SelectionOption() when $default != null:
return $default(_that.id,_that.label,_that.description,_that.imageUri);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _SelectionOption implements SelectionOption {
  const _SelectionOption({required this.id, required this.label, this.description, this.imageUri});
  factory _SelectionOption.fromJson(Map<String, dynamic> json) => _$SelectionOptionFromJson(json);

@override final  String id;
@override final  String label;
@override final  String? description;
@override final  Uri? imageUri;

/// Create a copy of SelectionOption
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SelectionOptionCopyWith<_SelectionOption> get copyWith => __$SelectionOptionCopyWithImpl<_SelectionOption>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SelectionOptionToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SelectionOption&&(identical(other.id, id) || other.id == id)&&(identical(other.label, label) || other.label == label)&&(identical(other.description, description) || other.description == description)&&(identical(other.imageUri, imageUri) || other.imageUri == imageUri));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,label,description,imageUri);

@override
String toString() {
  return 'SelectionOption(id: $id, label: $label, description: $description, imageUri: $imageUri)';
}


}

/// @nodoc
abstract mixin class _$SelectionOptionCopyWith<$Res> implements $SelectionOptionCopyWith<$Res> {
  factory _$SelectionOptionCopyWith(_SelectionOption value, $Res Function(_SelectionOption) _then) = __$SelectionOptionCopyWithImpl;
@override @useResult
$Res call({
 String id, String label, String? description, Uri? imageUri
});




}
/// @nodoc
class __$SelectionOptionCopyWithImpl<$Res>
    implements _$SelectionOptionCopyWith<$Res> {
  __$SelectionOptionCopyWithImpl(this._self, this._then);

  final _SelectionOption _self;
  final $Res Function(_SelectionOption) _then;

/// Create a copy of SelectionOption
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? label = null,Object? description = freezed,Object? imageUri = freezed,}) {
  return _then(_SelectionOption(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,label: null == label ? _self.label : label // ignore: cast_nullable_to_non_nullable
as String,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,imageUri: freezed == imageUri ? _self.imageUri : imageUri // ignore: cast_nullable_to_non_nullable
as Uri?,
  ));
}


}


/// @nodoc
mixin _$SelectionSpec {

 String get id; String get prompt; List<SelectionOption> get options; bool get multiSelect; int get minSelections; int? get maxSelections;
/// Create a copy of SelectionSpec
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SelectionSpecCopyWith<SelectionSpec> get copyWith => _$SelectionSpecCopyWithImpl<SelectionSpec>(this as SelectionSpec, _$identity);

  /// Serializes this SelectionSpec to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SelectionSpec&&(identical(other.id, id) || other.id == id)&&(identical(other.prompt, prompt) || other.prompt == prompt)&&const DeepCollectionEquality().equals(other.options, options)&&(identical(other.multiSelect, multiSelect) || other.multiSelect == multiSelect)&&(identical(other.minSelections, minSelections) || other.minSelections == minSelections)&&(identical(other.maxSelections, maxSelections) || other.maxSelections == maxSelections));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,prompt,const DeepCollectionEquality().hash(options),multiSelect,minSelections,maxSelections);

@override
String toString() {
  return 'SelectionSpec(id: $id, prompt: $prompt, options: $options, multiSelect: $multiSelect, minSelections: $minSelections, maxSelections: $maxSelections)';
}


}

/// @nodoc
abstract mixin class $SelectionSpecCopyWith<$Res>  {
  factory $SelectionSpecCopyWith(SelectionSpec value, $Res Function(SelectionSpec) _then) = _$SelectionSpecCopyWithImpl;
@useResult
$Res call({
 String id, String prompt, List<SelectionOption> options, bool multiSelect, int minSelections, int? maxSelections
});




}
/// @nodoc
class _$SelectionSpecCopyWithImpl<$Res>
    implements $SelectionSpecCopyWith<$Res> {
  _$SelectionSpecCopyWithImpl(this._self, this._then);

  final SelectionSpec _self;
  final $Res Function(SelectionSpec) _then;

/// Create a copy of SelectionSpec
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? prompt = null,Object? options = null,Object? multiSelect = null,Object? minSelections = null,Object? maxSelections = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,prompt: null == prompt ? _self.prompt : prompt // ignore: cast_nullable_to_non_nullable
as String,options: null == options ? _self.options : options // ignore: cast_nullable_to_non_nullable
as List<SelectionOption>,multiSelect: null == multiSelect ? _self.multiSelect : multiSelect // ignore: cast_nullable_to_non_nullable
as bool,minSelections: null == minSelections ? _self.minSelections : minSelections // ignore: cast_nullable_to_non_nullable
as int,maxSelections: freezed == maxSelections ? _self.maxSelections : maxSelections // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

}


/// Adds pattern-matching-related methods to [SelectionSpec].
extension SelectionSpecPatterns on SelectionSpec {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SelectionSpec value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SelectionSpec() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SelectionSpec value)  $default,){
final _that = this;
switch (_that) {
case _SelectionSpec():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SelectionSpec value)?  $default,){
final _that = this;
switch (_that) {
case _SelectionSpec() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String prompt,  List<SelectionOption> options,  bool multiSelect,  int minSelections,  int? maxSelections)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SelectionSpec() when $default != null:
return $default(_that.id,_that.prompt,_that.options,_that.multiSelect,_that.minSelections,_that.maxSelections);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String prompt,  List<SelectionOption> options,  bool multiSelect,  int minSelections,  int? maxSelections)  $default,) {final _that = this;
switch (_that) {
case _SelectionSpec():
return $default(_that.id,_that.prompt,_that.options,_that.multiSelect,_that.minSelections,_that.maxSelections);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String prompt,  List<SelectionOption> options,  bool multiSelect,  int minSelections,  int? maxSelections)?  $default,) {final _that = this;
switch (_that) {
case _SelectionSpec() when $default != null:
return $default(_that.id,_that.prompt,_that.options,_that.multiSelect,_that.minSelections,_that.maxSelections);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _SelectionSpec implements SelectionSpec {
  const _SelectionSpec({required this.id, required this.prompt, required final  List<SelectionOption> options, this.multiSelect = false, this.minSelections = 1, this.maxSelections}): _options = options;
  factory _SelectionSpec.fromJson(Map<String, dynamic> json) => _$SelectionSpecFromJson(json);

@override final  String id;
@override final  String prompt;
 final  List<SelectionOption> _options;
@override List<SelectionOption> get options {
  if (_options is EqualUnmodifiableListView) return _options;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_options);
}

@override@JsonKey() final  bool multiSelect;
@override@JsonKey() final  int minSelections;
@override final  int? maxSelections;

/// Create a copy of SelectionSpec
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SelectionSpecCopyWith<_SelectionSpec> get copyWith => __$SelectionSpecCopyWithImpl<_SelectionSpec>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SelectionSpecToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SelectionSpec&&(identical(other.id, id) || other.id == id)&&(identical(other.prompt, prompt) || other.prompt == prompt)&&const DeepCollectionEquality().equals(other._options, _options)&&(identical(other.multiSelect, multiSelect) || other.multiSelect == multiSelect)&&(identical(other.minSelections, minSelections) || other.minSelections == minSelections)&&(identical(other.maxSelections, maxSelections) || other.maxSelections == maxSelections));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,prompt,const DeepCollectionEquality().hash(_options),multiSelect,minSelections,maxSelections);

@override
String toString() {
  return 'SelectionSpec(id: $id, prompt: $prompt, options: $options, multiSelect: $multiSelect, minSelections: $minSelections, maxSelections: $maxSelections)';
}


}

/// @nodoc
abstract mixin class _$SelectionSpecCopyWith<$Res> implements $SelectionSpecCopyWith<$Res> {
  factory _$SelectionSpecCopyWith(_SelectionSpec value, $Res Function(_SelectionSpec) _then) = __$SelectionSpecCopyWithImpl;
@override @useResult
$Res call({
 String id, String prompt, List<SelectionOption> options, bool multiSelect, int minSelections, int? maxSelections
});




}
/// @nodoc
class __$SelectionSpecCopyWithImpl<$Res>
    implements _$SelectionSpecCopyWith<$Res> {
  __$SelectionSpecCopyWithImpl(this._self, this._then);

  final _SelectionSpec _self;
  final $Res Function(_SelectionSpec) _then;

/// Create a copy of SelectionSpec
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? prompt = null,Object? options = null,Object? multiSelect = null,Object? minSelections = null,Object? maxSelections = freezed,}) {
  return _then(_SelectionSpec(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,prompt: null == prompt ? _self.prompt : prompt // ignore: cast_nullable_to_non_nullable
as String,options: null == options ? _self._options : options // ignore: cast_nullable_to_non_nullable
as List<SelectionOption>,multiSelect: null == multiSelect ? _self.multiSelect : multiSelect // ignore: cast_nullable_to_non_nullable
as bool,minSelections: null == minSelections ? _self.minSelections : minSelections // ignore: cast_nullable_to_non_nullable
as int,maxSelections: freezed == maxSelections ? _self.maxSelections : maxSelections // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}


/// @nodoc
mixin _$ConfirmationSpec {

 String get id; String get title; String get description; String get confirmLabel; String get declineLabel; ConfirmationSeverity get severity;/// Human-readable summary of what will happen (shown verbatim).
 List<String> get details;
/// Create a copy of ConfirmationSpec
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ConfirmationSpecCopyWith<ConfirmationSpec> get copyWith => _$ConfirmationSpecCopyWithImpl<ConfirmationSpec>(this as ConfirmationSpec, _$identity);

  /// Serializes this ConfirmationSpec to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ConfirmationSpec&&(identical(other.id, id) || other.id == id)&&(identical(other.title, title) || other.title == title)&&(identical(other.description, description) || other.description == description)&&(identical(other.confirmLabel, confirmLabel) || other.confirmLabel == confirmLabel)&&(identical(other.declineLabel, declineLabel) || other.declineLabel == declineLabel)&&(identical(other.severity, severity) || other.severity == severity)&&const DeepCollectionEquality().equals(other.details, details));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,title,description,confirmLabel,declineLabel,severity,const DeepCollectionEquality().hash(details));

@override
String toString() {
  return 'ConfirmationSpec(id: $id, title: $title, description: $description, confirmLabel: $confirmLabel, declineLabel: $declineLabel, severity: $severity, details: $details)';
}


}

/// @nodoc
abstract mixin class $ConfirmationSpecCopyWith<$Res>  {
  factory $ConfirmationSpecCopyWith(ConfirmationSpec value, $Res Function(ConfirmationSpec) _then) = _$ConfirmationSpecCopyWithImpl;
@useResult
$Res call({
 String id, String title, String description, String confirmLabel, String declineLabel, ConfirmationSeverity severity, List<String> details
});




}
/// @nodoc
class _$ConfirmationSpecCopyWithImpl<$Res>
    implements $ConfirmationSpecCopyWith<$Res> {
  _$ConfirmationSpecCopyWithImpl(this._self, this._then);

  final ConfirmationSpec _self;
  final $Res Function(ConfirmationSpec) _then;

/// Create a copy of ConfirmationSpec
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? title = null,Object? description = null,Object? confirmLabel = null,Object? declineLabel = null,Object? severity = null,Object? details = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,confirmLabel: null == confirmLabel ? _self.confirmLabel : confirmLabel // ignore: cast_nullable_to_non_nullable
as String,declineLabel: null == declineLabel ? _self.declineLabel : declineLabel // ignore: cast_nullable_to_non_nullable
as String,severity: null == severity ? _self.severity : severity // ignore: cast_nullable_to_non_nullable
as ConfirmationSeverity,details: null == details ? _self.details : details // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}

}


/// Adds pattern-matching-related methods to [ConfirmationSpec].
extension ConfirmationSpecPatterns on ConfirmationSpec {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ConfirmationSpec value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ConfirmationSpec() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ConfirmationSpec value)  $default,){
final _that = this;
switch (_that) {
case _ConfirmationSpec():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ConfirmationSpec value)?  $default,){
final _that = this;
switch (_that) {
case _ConfirmationSpec() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String title,  String description,  String confirmLabel,  String declineLabel,  ConfirmationSeverity severity,  List<String> details)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ConfirmationSpec() when $default != null:
return $default(_that.id,_that.title,_that.description,_that.confirmLabel,_that.declineLabel,_that.severity,_that.details);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String title,  String description,  String confirmLabel,  String declineLabel,  ConfirmationSeverity severity,  List<String> details)  $default,) {final _that = this;
switch (_that) {
case _ConfirmationSpec():
return $default(_that.id,_that.title,_that.description,_that.confirmLabel,_that.declineLabel,_that.severity,_that.details);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String title,  String description,  String confirmLabel,  String declineLabel,  ConfirmationSeverity severity,  List<String> details)?  $default,) {final _that = this;
switch (_that) {
case _ConfirmationSpec() when $default != null:
return $default(_that.id,_that.title,_that.description,_that.confirmLabel,_that.declineLabel,_that.severity,_that.details);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ConfirmationSpec implements ConfirmationSpec {
  const _ConfirmationSpec({required this.id, required this.title, required this.description, this.confirmLabel = 'Confirm', this.declineLabel = 'Cancel', this.severity = ConfirmationSeverity.medium, final  List<String> details = const <String>[]}): _details = details;
  factory _ConfirmationSpec.fromJson(Map<String, dynamic> json) => _$ConfirmationSpecFromJson(json);

@override final  String id;
@override final  String title;
@override final  String description;
@override@JsonKey() final  String confirmLabel;
@override@JsonKey() final  String declineLabel;
@override@JsonKey() final  ConfirmationSeverity severity;
/// Human-readable summary of what will happen (shown verbatim).
 final  List<String> _details;
/// Human-readable summary of what will happen (shown verbatim).
@override@JsonKey() List<String> get details {
  if (_details is EqualUnmodifiableListView) return _details;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_details);
}


/// Create a copy of ConfirmationSpec
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ConfirmationSpecCopyWith<_ConfirmationSpec> get copyWith => __$ConfirmationSpecCopyWithImpl<_ConfirmationSpec>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ConfirmationSpecToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ConfirmationSpec&&(identical(other.id, id) || other.id == id)&&(identical(other.title, title) || other.title == title)&&(identical(other.description, description) || other.description == description)&&(identical(other.confirmLabel, confirmLabel) || other.confirmLabel == confirmLabel)&&(identical(other.declineLabel, declineLabel) || other.declineLabel == declineLabel)&&(identical(other.severity, severity) || other.severity == severity)&&const DeepCollectionEquality().equals(other._details, _details));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,title,description,confirmLabel,declineLabel,severity,const DeepCollectionEquality().hash(_details));

@override
String toString() {
  return 'ConfirmationSpec(id: $id, title: $title, description: $description, confirmLabel: $confirmLabel, declineLabel: $declineLabel, severity: $severity, details: $details)';
}


}

/// @nodoc
abstract mixin class _$ConfirmationSpecCopyWith<$Res> implements $ConfirmationSpecCopyWith<$Res> {
  factory _$ConfirmationSpecCopyWith(_ConfirmationSpec value, $Res Function(_ConfirmationSpec) _then) = __$ConfirmationSpecCopyWithImpl;
@override @useResult
$Res call({
 String id, String title, String description, String confirmLabel, String declineLabel, ConfirmationSeverity severity, List<String> details
});




}
/// @nodoc
class __$ConfirmationSpecCopyWithImpl<$Res>
    implements _$ConfirmationSpecCopyWith<$Res> {
  __$ConfirmationSpecCopyWithImpl(this._self, this._then);

  final _ConfirmationSpec _self;
  final $Res Function(_ConfirmationSpec) _then;

/// Create a copy of ConfirmationSpec
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? title = null,Object? description = null,Object? confirmLabel = null,Object? declineLabel = null,Object? severity = null,Object? details = null,}) {
  return _then(_ConfirmationSpec(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,confirmLabel: null == confirmLabel ? _self.confirmLabel : confirmLabel // ignore: cast_nullable_to_non_nullable
as String,declineLabel: null == declineLabel ? _self.declineLabel : declineLabel // ignore: cast_nullable_to_non_nullable
as String,severity: null == severity ? _self.severity : severity // ignore: cast_nullable_to_non_nullable
as ConfirmationSeverity,details: null == details ? _self._details : details // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}


}


/// @nodoc
mixin _$ToolError {

 String get code; String get message; bool get retryable;
/// Create a copy of ToolError
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ToolErrorCopyWith<ToolError> get copyWith => _$ToolErrorCopyWithImpl<ToolError>(this as ToolError, _$identity);

  /// Serializes this ToolError to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ToolError&&(identical(other.code, code) || other.code == code)&&(identical(other.message, message) || other.message == message)&&(identical(other.retryable, retryable) || other.retryable == retryable));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,code,message,retryable);

@override
String toString() {
  return 'ToolError(code: $code, message: $message, retryable: $retryable)';
}


}

/// @nodoc
abstract mixin class $ToolErrorCopyWith<$Res>  {
  factory $ToolErrorCopyWith(ToolError value, $Res Function(ToolError) _then) = _$ToolErrorCopyWithImpl;
@useResult
$Res call({
 String code, String message, bool retryable
});




}
/// @nodoc
class _$ToolErrorCopyWithImpl<$Res>
    implements $ToolErrorCopyWith<$Res> {
  _$ToolErrorCopyWithImpl(this._self, this._then);

  final ToolError _self;
  final $Res Function(ToolError) _then;

/// Create a copy of ToolError
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? code = null,Object? message = null,Object? retryable = null,}) {
  return _then(_self.copyWith(
code: null == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as String,message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,retryable: null == retryable ? _self.retryable : retryable // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [ToolError].
extension ToolErrorPatterns on ToolError {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ToolError value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ToolError() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ToolError value)  $default,){
final _that = this;
switch (_that) {
case _ToolError():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ToolError value)?  $default,){
final _that = this;
switch (_that) {
case _ToolError() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String code,  String message,  bool retryable)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ToolError() when $default != null:
return $default(_that.code,_that.message,_that.retryable);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String code,  String message,  bool retryable)  $default,) {final _that = this;
switch (_that) {
case _ToolError():
return $default(_that.code,_that.message,_that.retryable);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String code,  String message,  bool retryable)?  $default,) {final _that = this;
switch (_that) {
case _ToolError() when $default != null:
return $default(_that.code,_that.message,_that.retryable);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ToolError implements ToolError {
  const _ToolError({required this.code, required this.message, this.retryable = false});
  factory _ToolError.fromJson(Map<String, dynamic> json) => _$ToolErrorFromJson(json);

@override final  String code;
@override final  String message;
@override@JsonKey() final  bool retryable;

/// Create a copy of ToolError
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ToolErrorCopyWith<_ToolError> get copyWith => __$ToolErrorCopyWithImpl<_ToolError>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ToolErrorToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ToolError&&(identical(other.code, code) || other.code == code)&&(identical(other.message, message) || other.message == message)&&(identical(other.retryable, retryable) || other.retryable == retryable));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,code,message,retryable);

@override
String toString() {
  return 'ToolError(code: $code, message: $message, retryable: $retryable)';
}


}

/// @nodoc
abstract mixin class _$ToolErrorCopyWith<$Res> implements $ToolErrorCopyWith<$Res> {
  factory _$ToolErrorCopyWith(_ToolError value, $Res Function(_ToolError) _then) = __$ToolErrorCopyWithImpl;
@override @useResult
$Res call({
 String code, String message, bool retryable
});




}
/// @nodoc
class __$ToolErrorCopyWithImpl<$Res>
    implements _$ToolErrorCopyWith<$Res> {
  __$ToolErrorCopyWithImpl(this._self, this._then);

  final _ToolError _self;
  final $Res Function(_ToolError) _then;

/// Create a copy of ToolError
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? code = null,Object? message = null,Object? retryable = null,}) {
  return _then(_ToolError(
code: null == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as String,message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,retryable: null == retryable ? _self.retryable : retryable // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
