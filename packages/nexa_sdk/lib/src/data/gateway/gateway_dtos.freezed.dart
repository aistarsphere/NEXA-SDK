// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'gateway_dtos.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$CreateSessionRequestDto {

 String get applicationId; List<String> get requestedCapabilities; String get languageTag; Map<String, String> get clientMetadata; String get sdkVersion; String get platform;
/// Create a copy of CreateSessionRequestDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CreateSessionRequestDtoCopyWith<CreateSessionRequestDto> get copyWith => _$CreateSessionRequestDtoCopyWithImpl<CreateSessionRequestDto>(this as CreateSessionRequestDto, _$identity);

  /// Serializes this CreateSessionRequestDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CreateSessionRequestDto&&(identical(other.applicationId, applicationId) || other.applicationId == applicationId)&&const DeepCollectionEquality().equals(other.requestedCapabilities, requestedCapabilities)&&(identical(other.languageTag, languageTag) || other.languageTag == languageTag)&&const DeepCollectionEquality().equals(other.clientMetadata, clientMetadata)&&(identical(other.sdkVersion, sdkVersion) || other.sdkVersion == sdkVersion)&&(identical(other.platform, platform) || other.platform == platform));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,applicationId,const DeepCollectionEquality().hash(requestedCapabilities),languageTag,const DeepCollectionEquality().hash(clientMetadata),sdkVersion,platform);

@override
String toString() {
  return 'CreateSessionRequestDto(applicationId: $applicationId, requestedCapabilities: $requestedCapabilities, languageTag: $languageTag, clientMetadata: $clientMetadata, sdkVersion: $sdkVersion, platform: $platform)';
}


}

/// @nodoc
abstract mixin class $CreateSessionRequestDtoCopyWith<$Res>  {
  factory $CreateSessionRequestDtoCopyWith(CreateSessionRequestDto value, $Res Function(CreateSessionRequestDto) _then) = _$CreateSessionRequestDtoCopyWithImpl;
@useResult
$Res call({
 String applicationId, List<String> requestedCapabilities, String languageTag, Map<String, String> clientMetadata, String sdkVersion, String platform
});




}
/// @nodoc
class _$CreateSessionRequestDtoCopyWithImpl<$Res>
    implements $CreateSessionRequestDtoCopyWith<$Res> {
  _$CreateSessionRequestDtoCopyWithImpl(this._self, this._then);

  final CreateSessionRequestDto _self;
  final $Res Function(CreateSessionRequestDto) _then;

/// Create a copy of CreateSessionRequestDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? applicationId = null,Object? requestedCapabilities = null,Object? languageTag = null,Object? clientMetadata = null,Object? sdkVersion = null,Object? platform = null,}) {
  return _then(_self.copyWith(
applicationId: null == applicationId ? _self.applicationId : applicationId // ignore: cast_nullable_to_non_nullable
as String,requestedCapabilities: null == requestedCapabilities ? _self.requestedCapabilities : requestedCapabilities // ignore: cast_nullable_to_non_nullable
as List<String>,languageTag: null == languageTag ? _self.languageTag : languageTag // ignore: cast_nullable_to_non_nullable
as String,clientMetadata: null == clientMetadata ? _self.clientMetadata : clientMetadata // ignore: cast_nullable_to_non_nullable
as Map<String, String>,sdkVersion: null == sdkVersion ? _self.sdkVersion : sdkVersion // ignore: cast_nullable_to_non_nullable
as String,platform: null == platform ? _self.platform : platform // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [CreateSessionRequestDto].
extension CreateSessionRequestDtoPatterns on CreateSessionRequestDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CreateSessionRequestDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CreateSessionRequestDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CreateSessionRequestDto value)  $default,){
final _that = this;
switch (_that) {
case _CreateSessionRequestDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CreateSessionRequestDto value)?  $default,){
final _that = this;
switch (_that) {
case _CreateSessionRequestDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String applicationId,  List<String> requestedCapabilities,  String languageTag,  Map<String, String> clientMetadata,  String sdkVersion,  String platform)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CreateSessionRequestDto() when $default != null:
return $default(_that.applicationId,_that.requestedCapabilities,_that.languageTag,_that.clientMetadata,_that.sdkVersion,_that.platform);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String applicationId,  List<String> requestedCapabilities,  String languageTag,  Map<String, String> clientMetadata,  String sdkVersion,  String platform)  $default,) {final _that = this;
switch (_that) {
case _CreateSessionRequestDto():
return $default(_that.applicationId,_that.requestedCapabilities,_that.languageTag,_that.clientMetadata,_that.sdkVersion,_that.platform);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String applicationId,  List<String> requestedCapabilities,  String languageTag,  Map<String, String> clientMetadata,  String sdkVersion,  String platform)?  $default,) {final _that = this;
switch (_that) {
case _CreateSessionRequestDto() when $default != null:
return $default(_that.applicationId,_that.requestedCapabilities,_that.languageTag,_that.clientMetadata,_that.sdkVersion,_that.platform);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _CreateSessionRequestDto implements CreateSessionRequestDto {
  const _CreateSessionRequestDto({required this.applicationId, required final  List<String> requestedCapabilities, required this.languageTag, final  Map<String, String> clientMetadata = const <String, String>{}, required this.sdkVersion, required this.platform}): _requestedCapabilities = requestedCapabilities,_clientMetadata = clientMetadata;
  factory _CreateSessionRequestDto.fromJson(Map<String, dynamic> json) => _$CreateSessionRequestDtoFromJson(json);

@override final  String applicationId;
 final  List<String> _requestedCapabilities;
@override List<String> get requestedCapabilities {
  if (_requestedCapabilities is EqualUnmodifiableListView) return _requestedCapabilities;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_requestedCapabilities);
}

@override final  String languageTag;
 final  Map<String, String> _clientMetadata;
@override@JsonKey() Map<String, String> get clientMetadata {
  if (_clientMetadata is EqualUnmodifiableMapView) return _clientMetadata;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_clientMetadata);
}

@override final  String sdkVersion;
@override final  String platform;

/// Create a copy of CreateSessionRequestDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CreateSessionRequestDtoCopyWith<_CreateSessionRequestDto> get copyWith => __$CreateSessionRequestDtoCopyWithImpl<_CreateSessionRequestDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CreateSessionRequestDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CreateSessionRequestDto&&(identical(other.applicationId, applicationId) || other.applicationId == applicationId)&&const DeepCollectionEquality().equals(other._requestedCapabilities, _requestedCapabilities)&&(identical(other.languageTag, languageTag) || other.languageTag == languageTag)&&const DeepCollectionEquality().equals(other._clientMetadata, _clientMetadata)&&(identical(other.sdkVersion, sdkVersion) || other.sdkVersion == sdkVersion)&&(identical(other.platform, platform) || other.platform == platform));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,applicationId,const DeepCollectionEquality().hash(_requestedCapabilities),languageTag,const DeepCollectionEquality().hash(_clientMetadata),sdkVersion,platform);

@override
String toString() {
  return 'CreateSessionRequestDto(applicationId: $applicationId, requestedCapabilities: $requestedCapabilities, languageTag: $languageTag, clientMetadata: $clientMetadata, sdkVersion: $sdkVersion, platform: $platform)';
}


}

/// @nodoc
abstract mixin class _$CreateSessionRequestDtoCopyWith<$Res> implements $CreateSessionRequestDtoCopyWith<$Res> {
  factory _$CreateSessionRequestDtoCopyWith(_CreateSessionRequestDto value, $Res Function(_CreateSessionRequestDto) _then) = __$CreateSessionRequestDtoCopyWithImpl;
@override @useResult
$Res call({
 String applicationId, List<String> requestedCapabilities, String languageTag, Map<String, String> clientMetadata, String sdkVersion, String platform
});




}
/// @nodoc
class __$CreateSessionRequestDtoCopyWithImpl<$Res>
    implements _$CreateSessionRequestDtoCopyWith<$Res> {
  __$CreateSessionRequestDtoCopyWithImpl(this._self, this._then);

  final _CreateSessionRequestDto _self;
  final $Res Function(_CreateSessionRequestDto) _then;

/// Create a copy of CreateSessionRequestDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? applicationId = null,Object? requestedCapabilities = null,Object? languageTag = null,Object? clientMetadata = null,Object? sdkVersion = null,Object? platform = null,}) {
  return _then(_CreateSessionRequestDto(
applicationId: null == applicationId ? _self.applicationId : applicationId // ignore: cast_nullable_to_non_nullable
as String,requestedCapabilities: null == requestedCapabilities ? _self._requestedCapabilities : requestedCapabilities // ignore: cast_nullable_to_non_nullable
as List<String>,languageTag: null == languageTag ? _self.languageTag : languageTag // ignore: cast_nullable_to_non_nullable
as String,clientMetadata: null == clientMetadata ? _self._clientMetadata : clientMetadata // ignore: cast_nullable_to_non_nullable
as Map<String, String>,sdkVersion: null == sdkVersion ? _self.sdkVersion : sdkVersion // ignore: cast_nullable_to_non_nullable
as String,platform: null == platform ? _self.platform : platform // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$SessionDto {

 String get sessionId; DateTime get expiresAt; List<String> get grantedCapabilities; int get lastSequence;
/// Create a copy of SessionDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SessionDtoCopyWith<SessionDto> get copyWith => _$SessionDtoCopyWithImpl<SessionDto>(this as SessionDto, _$identity);

  /// Serializes this SessionDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SessionDto&&(identical(other.sessionId, sessionId) || other.sessionId == sessionId)&&(identical(other.expiresAt, expiresAt) || other.expiresAt == expiresAt)&&const DeepCollectionEquality().equals(other.grantedCapabilities, grantedCapabilities)&&(identical(other.lastSequence, lastSequence) || other.lastSequence == lastSequence));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,sessionId,expiresAt,const DeepCollectionEquality().hash(grantedCapabilities),lastSequence);

@override
String toString() {
  return 'SessionDto(sessionId: $sessionId, expiresAt: $expiresAt, grantedCapabilities: $grantedCapabilities, lastSequence: $lastSequence)';
}


}

/// @nodoc
abstract mixin class $SessionDtoCopyWith<$Res>  {
  factory $SessionDtoCopyWith(SessionDto value, $Res Function(SessionDto) _then) = _$SessionDtoCopyWithImpl;
@useResult
$Res call({
 String sessionId, DateTime expiresAt, List<String> grantedCapabilities, int lastSequence
});




}
/// @nodoc
class _$SessionDtoCopyWithImpl<$Res>
    implements $SessionDtoCopyWith<$Res> {
  _$SessionDtoCopyWithImpl(this._self, this._then);

  final SessionDto _self;
  final $Res Function(SessionDto) _then;

/// Create a copy of SessionDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? sessionId = null,Object? expiresAt = null,Object? grantedCapabilities = null,Object? lastSequence = null,}) {
  return _then(_self.copyWith(
sessionId: null == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as String,expiresAt: null == expiresAt ? _self.expiresAt : expiresAt // ignore: cast_nullable_to_non_nullable
as DateTime,grantedCapabilities: null == grantedCapabilities ? _self.grantedCapabilities : grantedCapabilities // ignore: cast_nullable_to_non_nullable
as List<String>,lastSequence: null == lastSequence ? _self.lastSequence : lastSequence // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [SessionDto].
extension SessionDtoPatterns on SessionDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SessionDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SessionDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SessionDto value)  $default,){
final _that = this;
switch (_that) {
case _SessionDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SessionDto value)?  $default,){
final _that = this;
switch (_that) {
case _SessionDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String sessionId,  DateTime expiresAt,  List<String> grantedCapabilities,  int lastSequence)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SessionDto() when $default != null:
return $default(_that.sessionId,_that.expiresAt,_that.grantedCapabilities,_that.lastSequence);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String sessionId,  DateTime expiresAt,  List<String> grantedCapabilities,  int lastSequence)  $default,) {final _that = this;
switch (_that) {
case _SessionDto():
return $default(_that.sessionId,_that.expiresAt,_that.grantedCapabilities,_that.lastSequence);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String sessionId,  DateTime expiresAt,  List<String> grantedCapabilities,  int lastSequence)?  $default,) {final _that = this;
switch (_that) {
case _SessionDto() when $default != null:
return $default(_that.sessionId,_that.expiresAt,_that.grantedCapabilities,_that.lastSequence);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _SessionDto implements SessionDto {
  const _SessionDto({required this.sessionId, required this.expiresAt, required final  List<String> grantedCapabilities, this.lastSequence = 0}): _grantedCapabilities = grantedCapabilities;
  factory _SessionDto.fromJson(Map<String, dynamic> json) => _$SessionDtoFromJson(json);

@override final  String sessionId;
@override final  DateTime expiresAt;
 final  List<String> _grantedCapabilities;
@override List<String> get grantedCapabilities {
  if (_grantedCapabilities is EqualUnmodifiableListView) return _grantedCapabilities;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_grantedCapabilities);
}

@override@JsonKey() final  int lastSequence;

/// Create a copy of SessionDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SessionDtoCopyWith<_SessionDto> get copyWith => __$SessionDtoCopyWithImpl<_SessionDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SessionDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SessionDto&&(identical(other.sessionId, sessionId) || other.sessionId == sessionId)&&(identical(other.expiresAt, expiresAt) || other.expiresAt == expiresAt)&&const DeepCollectionEquality().equals(other._grantedCapabilities, _grantedCapabilities)&&(identical(other.lastSequence, lastSequence) || other.lastSequence == lastSequence));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,sessionId,expiresAt,const DeepCollectionEquality().hash(_grantedCapabilities),lastSequence);

@override
String toString() {
  return 'SessionDto(sessionId: $sessionId, expiresAt: $expiresAt, grantedCapabilities: $grantedCapabilities, lastSequence: $lastSequence)';
}


}

/// @nodoc
abstract mixin class _$SessionDtoCopyWith<$Res> implements $SessionDtoCopyWith<$Res> {
  factory _$SessionDtoCopyWith(_SessionDto value, $Res Function(_SessionDto) _then) = __$SessionDtoCopyWithImpl;
@override @useResult
$Res call({
 String sessionId, DateTime expiresAt, List<String> grantedCapabilities, int lastSequence
});




}
/// @nodoc
class __$SessionDtoCopyWithImpl<$Res>
    implements _$SessionDtoCopyWith<$Res> {
  __$SessionDtoCopyWithImpl(this._self, this._then);

  final _SessionDto _self;
  final $Res Function(_SessionDto) _then;

/// Create a copy of SessionDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? sessionId = null,Object? expiresAt = null,Object? grantedCapabilities = null,Object? lastSequence = null,}) {
  return _then(_SessionDto(
sessionId: null == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as String,expiresAt: null == expiresAt ? _self.expiresAt : expiresAt // ignore: cast_nullable_to_non_nullable
as DateTime,grantedCapabilities: null == grantedCapabilities ? _self._grantedCapabilities : grantedCapabilities // ignore: cast_nullable_to_non_nullable
as List<String>,lastSequence: null == lastSequence ? _self.lastSequence : lastSequence // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}


/// @nodoc
mixin _$EventPageDto {

 List<Map<String, Object?>> get events;/// Highest sequence included in [events] (or the cursor echoed back).
 int get cursor;/// True once the session has ended and no more events will follow.
 bool get done;
/// Create a copy of EventPageDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$EventPageDtoCopyWith<EventPageDto> get copyWith => _$EventPageDtoCopyWithImpl<EventPageDto>(this as EventPageDto, _$identity);

  /// Serializes this EventPageDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is EventPageDto&&const DeepCollectionEquality().equals(other.events, events)&&(identical(other.cursor, cursor) || other.cursor == cursor)&&(identical(other.done, done) || other.done == done));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(events),cursor,done);

@override
String toString() {
  return 'EventPageDto(events: $events, cursor: $cursor, done: $done)';
}


}

/// @nodoc
abstract mixin class $EventPageDtoCopyWith<$Res>  {
  factory $EventPageDtoCopyWith(EventPageDto value, $Res Function(EventPageDto) _then) = _$EventPageDtoCopyWithImpl;
@useResult
$Res call({
 List<Map<String, Object?>> events, int cursor, bool done
});




}
/// @nodoc
class _$EventPageDtoCopyWithImpl<$Res>
    implements $EventPageDtoCopyWith<$Res> {
  _$EventPageDtoCopyWithImpl(this._self, this._then);

  final EventPageDto _self;
  final $Res Function(EventPageDto) _then;

/// Create a copy of EventPageDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? events = null,Object? cursor = null,Object? done = null,}) {
  return _then(_self.copyWith(
events: null == events ? _self.events : events // ignore: cast_nullable_to_non_nullable
as List<Map<String, Object?>>,cursor: null == cursor ? _self.cursor : cursor // ignore: cast_nullable_to_non_nullable
as int,done: null == done ? _self.done : done // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [EventPageDto].
extension EventPageDtoPatterns on EventPageDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _EventPageDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _EventPageDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _EventPageDto value)  $default,){
final _that = this;
switch (_that) {
case _EventPageDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _EventPageDto value)?  $default,){
final _that = this;
switch (_that) {
case _EventPageDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<Map<String, Object?>> events,  int cursor,  bool done)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _EventPageDto() when $default != null:
return $default(_that.events,_that.cursor,_that.done);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<Map<String, Object?>> events,  int cursor,  bool done)  $default,) {final _that = this;
switch (_that) {
case _EventPageDto():
return $default(_that.events,_that.cursor,_that.done);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<Map<String, Object?>> events,  int cursor,  bool done)?  $default,) {final _that = this;
switch (_that) {
case _EventPageDto() when $default != null:
return $default(_that.events,_that.cursor,_that.done);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _EventPageDto implements EventPageDto {
  const _EventPageDto({required final  List<Map<String, Object?>> events, required this.cursor, this.done = false}): _events = events;
  factory _EventPageDto.fromJson(Map<String, dynamic> json) => _$EventPageDtoFromJson(json);

 final  List<Map<String, Object?>> _events;
@override List<Map<String, Object?>> get events {
  if (_events is EqualUnmodifiableListView) return _events;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_events);
}

/// Highest sequence included in [events] (or the cursor echoed back).
@override final  int cursor;
/// True once the session has ended and no more events will follow.
@override@JsonKey() final  bool done;

/// Create a copy of EventPageDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$EventPageDtoCopyWith<_EventPageDto> get copyWith => __$EventPageDtoCopyWithImpl<_EventPageDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$EventPageDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _EventPageDto&&const DeepCollectionEquality().equals(other._events, _events)&&(identical(other.cursor, cursor) || other.cursor == cursor)&&(identical(other.done, done) || other.done == done));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_events),cursor,done);

@override
String toString() {
  return 'EventPageDto(events: $events, cursor: $cursor, done: $done)';
}


}

/// @nodoc
abstract mixin class _$EventPageDtoCopyWith<$Res> implements $EventPageDtoCopyWith<$Res> {
  factory _$EventPageDtoCopyWith(_EventPageDto value, $Res Function(_EventPageDto) _then) = __$EventPageDtoCopyWithImpl;
@override @useResult
$Res call({
 List<Map<String, Object?>> events, int cursor, bool done
});




}
/// @nodoc
class __$EventPageDtoCopyWithImpl<$Res>
    implements _$EventPageDtoCopyWith<$Res> {
  __$EventPageDtoCopyWithImpl(this._self, this._then);

  final _EventPageDto _self;
  final $Res Function(_EventPageDto) _then;

/// Create a copy of EventPageDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? events = null,Object? cursor = null,Object? done = null,}) {
  return _then(_EventPageDto(
events: null == events ? _self._events : events // ignore: cast_nullable_to_non_nullable
as List<Map<String, Object?>>,cursor: null == cursor ? _self.cursor : cursor // ignore: cast_nullable_to_non_nullable
as int,done: null == done ? _self.done : done // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}


/// @nodoc
mixin _$MessageRequestDto {

 String get clientMessageId; String get text; String? get languageTag;
/// Create a copy of MessageRequestDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MessageRequestDtoCopyWith<MessageRequestDto> get copyWith => _$MessageRequestDtoCopyWithImpl<MessageRequestDto>(this as MessageRequestDto, _$identity);

  /// Serializes this MessageRequestDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MessageRequestDto&&(identical(other.clientMessageId, clientMessageId) || other.clientMessageId == clientMessageId)&&(identical(other.text, text) || other.text == text)&&(identical(other.languageTag, languageTag) || other.languageTag == languageTag));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,clientMessageId,text,languageTag);

@override
String toString() {
  return 'MessageRequestDto(clientMessageId: $clientMessageId, text: $text, languageTag: $languageTag)';
}


}

/// @nodoc
abstract mixin class $MessageRequestDtoCopyWith<$Res>  {
  factory $MessageRequestDtoCopyWith(MessageRequestDto value, $Res Function(MessageRequestDto) _then) = _$MessageRequestDtoCopyWithImpl;
@useResult
$Res call({
 String clientMessageId, String text, String? languageTag
});




}
/// @nodoc
class _$MessageRequestDtoCopyWithImpl<$Res>
    implements $MessageRequestDtoCopyWith<$Res> {
  _$MessageRequestDtoCopyWithImpl(this._self, this._then);

  final MessageRequestDto _self;
  final $Res Function(MessageRequestDto) _then;

/// Create a copy of MessageRequestDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? clientMessageId = null,Object? text = null,Object? languageTag = freezed,}) {
  return _then(_self.copyWith(
clientMessageId: null == clientMessageId ? _self.clientMessageId : clientMessageId // ignore: cast_nullable_to_non_nullable
as String,text: null == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String,languageTag: freezed == languageTag ? _self.languageTag : languageTag // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [MessageRequestDto].
extension MessageRequestDtoPatterns on MessageRequestDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MessageRequestDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MessageRequestDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MessageRequestDto value)  $default,){
final _that = this;
switch (_that) {
case _MessageRequestDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MessageRequestDto value)?  $default,){
final _that = this;
switch (_that) {
case _MessageRequestDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String clientMessageId,  String text,  String? languageTag)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MessageRequestDto() when $default != null:
return $default(_that.clientMessageId,_that.text,_that.languageTag);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String clientMessageId,  String text,  String? languageTag)  $default,) {final _that = this;
switch (_that) {
case _MessageRequestDto():
return $default(_that.clientMessageId,_that.text,_that.languageTag);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String clientMessageId,  String text,  String? languageTag)?  $default,) {final _that = this;
switch (_that) {
case _MessageRequestDto() when $default != null:
return $default(_that.clientMessageId,_that.text,_that.languageTag);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _MessageRequestDto implements MessageRequestDto {
  const _MessageRequestDto({required this.clientMessageId, required this.text, this.languageTag});
  factory _MessageRequestDto.fromJson(Map<String, dynamic> json) => _$MessageRequestDtoFromJson(json);

@override final  String clientMessageId;
@override final  String text;
@override final  String? languageTag;

/// Create a copy of MessageRequestDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MessageRequestDtoCopyWith<_MessageRequestDto> get copyWith => __$MessageRequestDtoCopyWithImpl<_MessageRequestDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MessageRequestDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _MessageRequestDto&&(identical(other.clientMessageId, clientMessageId) || other.clientMessageId == clientMessageId)&&(identical(other.text, text) || other.text == text)&&(identical(other.languageTag, languageTag) || other.languageTag == languageTag));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,clientMessageId,text,languageTag);

@override
String toString() {
  return 'MessageRequestDto(clientMessageId: $clientMessageId, text: $text, languageTag: $languageTag)';
}


}

/// @nodoc
abstract mixin class _$MessageRequestDtoCopyWith<$Res> implements $MessageRequestDtoCopyWith<$Res> {
  factory _$MessageRequestDtoCopyWith(_MessageRequestDto value, $Res Function(_MessageRequestDto) _then) = __$MessageRequestDtoCopyWithImpl;
@override @useResult
$Res call({
 String clientMessageId, String text, String? languageTag
});




}
/// @nodoc
class __$MessageRequestDtoCopyWithImpl<$Res>
    implements _$MessageRequestDtoCopyWith<$Res> {
  __$MessageRequestDtoCopyWithImpl(this._self, this._then);

  final _MessageRequestDto _self;
  final $Res Function(_MessageRequestDto) _then;

/// Create a copy of MessageRequestDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? clientMessageId = null,Object? text = null,Object? languageTag = freezed,}) {
  return _then(_MessageRequestDto(
clientMessageId: null == clientMessageId ? _self.clientMessageId : clientMessageId // ignore: cast_nullable_to_non_nullable
as String,text: null == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String,languageTag: freezed == languageTag ? _self.languageTag : languageTag // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$PermissionResultDto {

 bool get granted;
/// Create a copy of PermissionResultDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PermissionResultDtoCopyWith<PermissionResultDto> get copyWith => _$PermissionResultDtoCopyWithImpl<PermissionResultDto>(this as PermissionResultDto, _$identity);

  /// Serializes this PermissionResultDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PermissionResultDto&&(identical(other.granted, granted) || other.granted == granted));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,granted);

@override
String toString() {
  return 'PermissionResultDto(granted: $granted)';
}


}

/// @nodoc
abstract mixin class $PermissionResultDtoCopyWith<$Res>  {
  factory $PermissionResultDtoCopyWith(PermissionResultDto value, $Res Function(PermissionResultDto) _then) = _$PermissionResultDtoCopyWithImpl;
@useResult
$Res call({
 bool granted
});




}
/// @nodoc
class _$PermissionResultDtoCopyWithImpl<$Res>
    implements $PermissionResultDtoCopyWith<$Res> {
  _$PermissionResultDtoCopyWithImpl(this._self, this._then);

  final PermissionResultDto _self;
  final $Res Function(PermissionResultDto) _then;

/// Create a copy of PermissionResultDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? granted = null,}) {
  return _then(_self.copyWith(
granted: null == granted ? _self.granted : granted // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [PermissionResultDto].
extension PermissionResultDtoPatterns on PermissionResultDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PermissionResultDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PermissionResultDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PermissionResultDto value)  $default,){
final _that = this;
switch (_that) {
case _PermissionResultDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PermissionResultDto value)?  $default,){
final _that = this;
switch (_that) {
case _PermissionResultDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool granted)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PermissionResultDto() when $default != null:
return $default(_that.granted);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool granted)  $default,) {final _that = this;
switch (_that) {
case _PermissionResultDto():
return $default(_that.granted);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool granted)?  $default,) {final _that = this;
switch (_that) {
case _PermissionResultDto() when $default != null:
return $default(_that.granted);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _PermissionResultDto implements PermissionResultDto {
  const _PermissionResultDto({required this.granted});
  factory _PermissionResultDto.fromJson(Map<String, dynamic> json) => _$PermissionResultDtoFromJson(json);

@override final  bool granted;

/// Create a copy of PermissionResultDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PermissionResultDtoCopyWith<_PermissionResultDto> get copyWith => __$PermissionResultDtoCopyWithImpl<_PermissionResultDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PermissionResultDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PermissionResultDto&&(identical(other.granted, granted) || other.granted == granted));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,granted);

@override
String toString() {
  return 'PermissionResultDto(granted: $granted)';
}


}

/// @nodoc
abstract mixin class _$PermissionResultDtoCopyWith<$Res> implements $PermissionResultDtoCopyWith<$Res> {
  factory _$PermissionResultDtoCopyWith(_PermissionResultDto value, $Res Function(_PermissionResultDto) _then) = __$PermissionResultDtoCopyWithImpl;
@override @useResult
$Res call({
 bool granted
});




}
/// @nodoc
class __$PermissionResultDtoCopyWithImpl<$Res>
    implements _$PermissionResultDtoCopyWith<$Res> {
  __$PermissionResultDtoCopyWithImpl(this._self, this._then);

  final _PermissionResultDto _self;
  final $Res Function(_PermissionResultDto) _then;

/// Create a copy of PermissionResultDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? granted = null,}) {
  return _then(_PermissionResultDto(
granted: null == granted ? _self.granted : granted // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}


/// @nodoc
mixin _$GatewayErrorDto {

 String get code; String get message; bool get retryable; int? get retryAfterSeconds; String? get quotaKind;
/// Create a copy of GatewayErrorDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GatewayErrorDtoCopyWith<GatewayErrorDto> get copyWith => _$GatewayErrorDtoCopyWithImpl<GatewayErrorDto>(this as GatewayErrorDto, _$identity);

  /// Serializes this GatewayErrorDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GatewayErrorDto&&(identical(other.code, code) || other.code == code)&&(identical(other.message, message) || other.message == message)&&(identical(other.retryable, retryable) || other.retryable == retryable)&&(identical(other.retryAfterSeconds, retryAfterSeconds) || other.retryAfterSeconds == retryAfterSeconds)&&(identical(other.quotaKind, quotaKind) || other.quotaKind == quotaKind));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,code,message,retryable,retryAfterSeconds,quotaKind);

@override
String toString() {
  return 'GatewayErrorDto(code: $code, message: $message, retryable: $retryable, retryAfterSeconds: $retryAfterSeconds, quotaKind: $quotaKind)';
}


}

/// @nodoc
abstract mixin class $GatewayErrorDtoCopyWith<$Res>  {
  factory $GatewayErrorDtoCopyWith(GatewayErrorDto value, $Res Function(GatewayErrorDto) _then) = _$GatewayErrorDtoCopyWithImpl;
@useResult
$Res call({
 String code, String message, bool retryable, int? retryAfterSeconds, String? quotaKind
});




}
/// @nodoc
class _$GatewayErrorDtoCopyWithImpl<$Res>
    implements $GatewayErrorDtoCopyWith<$Res> {
  _$GatewayErrorDtoCopyWithImpl(this._self, this._then);

  final GatewayErrorDto _self;
  final $Res Function(GatewayErrorDto) _then;

/// Create a copy of GatewayErrorDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? code = null,Object? message = null,Object? retryable = null,Object? retryAfterSeconds = freezed,Object? quotaKind = freezed,}) {
  return _then(_self.copyWith(
code: null == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as String,message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,retryable: null == retryable ? _self.retryable : retryable // ignore: cast_nullable_to_non_nullable
as bool,retryAfterSeconds: freezed == retryAfterSeconds ? _self.retryAfterSeconds : retryAfterSeconds // ignore: cast_nullable_to_non_nullable
as int?,quotaKind: freezed == quotaKind ? _self.quotaKind : quotaKind // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [GatewayErrorDto].
extension GatewayErrorDtoPatterns on GatewayErrorDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _GatewayErrorDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _GatewayErrorDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _GatewayErrorDto value)  $default,){
final _that = this;
switch (_that) {
case _GatewayErrorDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _GatewayErrorDto value)?  $default,){
final _that = this;
switch (_that) {
case _GatewayErrorDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String code,  String message,  bool retryable,  int? retryAfterSeconds,  String? quotaKind)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _GatewayErrorDto() when $default != null:
return $default(_that.code,_that.message,_that.retryable,_that.retryAfterSeconds,_that.quotaKind);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String code,  String message,  bool retryable,  int? retryAfterSeconds,  String? quotaKind)  $default,) {final _that = this;
switch (_that) {
case _GatewayErrorDto():
return $default(_that.code,_that.message,_that.retryable,_that.retryAfterSeconds,_that.quotaKind);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String code,  String message,  bool retryable,  int? retryAfterSeconds,  String? quotaKind)?  $default,) {final _that = this;
switch (_that) {
case _GatewayErrorDto() when $default != null:
return $default(_that.code,_that.message,_that.retryable,_that.retryAfterSeconds,_that.quotaKind);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _GatewayErrorDto implements GatewayErrorDto {
  const _GatewayErrorDto({required this.code, required this.message, this.retryable = false, this.retryAfterSeconds, this.quotaKind});
  factory _GatewayErrorDto.fromJson(Map<String, dynamic> json) => _$GatewayErrorDtoFromJson(json);

@override final  String code;
@override final  String message;
@override@JsonKey() final  bool retryable;
@override final  int? retryAfterSeconds;
@override final  String? quotaKind;

/// Create a copy of GatewayErrorDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$GatewayErrorDtoCopyWith<_GatewayErrorDto> get copyWith => __$GatewayErrorDtoCopyWithImpl<_GatewayErrorDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$GatewayErrorDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _GatewayErrorDto&&(identical(other.code, code) || other.code == code)&&(identical(other.message, message) || other.message == message)&&(identical(other.retryable, retryable) || other.retryable == retryable)&&(identical(other.retryAfterSeconds, retryAfterSeconds) || other.retryAfterSeconds == retryAfterSeconds)&&(identical(other.quotaKind, quotaKind) || other.quotaKind == quotaKind));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,code,message,retryable,retryAfterSeconds,quotaKind);

@override
String toString() {
  return 'GatewayErrorDto(code: $code, message: $message, retryable: $retryable, retryAfterSeconds: $retryAfterSeconds, quotaKind: $quotaKind)';
}


}

/// @nodoc
abstract mixin class _$GatewayErrorDtoCopyWith<$Res> implements $GatewayErrorDtoCopyWith<$Res> {
  factory _$GatewayErrorDtoCopyWith(_GatewayErrorDto value, $Res Function(_GatewayErrorDto) _then) = __$GatewayErrorDtoCopyWithImpl;
@override @useResult
$Res call({
 String code, String message, bool retryable, int? retryAfterSeconds, String? quotaKind
});




}
/// @nodoc
class __$GatewayErrorDtoCopyWithImpl<$Res>
    implements _$GatewayErrorDtoCopyWith<$Res> {
  __$GatewayErrorDtoCopyWithImpl(this._self, this._then);

  final _GatewayErrorDto _self;
  final $Res Function(_GatewayErrorDto) _then;

/// Create a copy of GatewayErrorDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? code = null,Object? message = null,Object? retryable = null,Object? retryAfterSeconds = freezed,Object? quotaKind = freezed,}) {
  return _then(_GatewayErrorDto(
code: null == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as String,message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,retryable: null == retryable ? _self.retryable : retryable // ignore: cast_nullable_to_non_nullable
as bool,retryAfterSeconds: freezed == retryAfterSeconds ? _self.retryAfterSeconds : retryAfterSeconds // ignore: cast_nullable_to_non_nullable
as int?,quotaKind: freezed == quotaKind ? _self.quotaKind : quotaKind // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
