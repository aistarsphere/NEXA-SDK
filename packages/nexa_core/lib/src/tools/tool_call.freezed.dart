// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'tool_call.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ToolCallRequest {

@ToolCallIdConverter() ToolCallId get id;/// Backend tool name (e.g. `restaurants.search`). Not shown raw to users.
 String get toolName;/// Localised, user-facing title supplied by the backend.
 String get displayTitle;/// Optional short, user-safe summary of the arguments.
 String? get argumentsSummary;/// Whether the backend will wait for explicit user confirmation.
 bool get requiresConfirmation;
/// Create a copy of ToolCallRequest
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ToolCallRequestCopyWith<ToolCallRequest> get copyWith => _$ToolCallRequestCopyWithImpl<ToolCallRequest>(this as ToolCallRequest, _$identity);

  /// Serializes this ToolCallRequest to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ToolCallRequest&&(identical(other.id, id) || other.id == id)&&(identical(other.toolName, toolName) || other.toolName == toolName)&&(identical(other.displayTitle, displayTitle) || other.displayTitle == displayTitle)&&(identical(other.argumentsSummary, argumentsSummary) || other.argumentsSummary == argumentsSummary)&&(identical(other.requiresConfirmation, requiresConfirmation) || other.requiresConfirmation == requiresConfirmation));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,toolName,displayTitle,argumentsSummary,requiresConfirmation);

@override
String toString() {
  return 'ToolCallRequest(id: $id, toolName: $toolName, displayTitle: $displayTitle, argumentsSummary: $argumentsSummary, requiresConfirmation: $requiresConfirmation)';
}


}

/// @nodoc
abstract mixin class $ToolCallRequestCopyWith<$Res>  {
  factory $ToolCallRequestCopyWith(ToolCallRequest value, $Res Function(ToolCallRequest) _then) = _$ToolCallRequestCopyWithImpl;
@useResult
$Res call({
@ToolCallIdConverter() ToolCallId id, String toolName, String displayTitle, String? argumentsSummary, bool requiresConfirmation
});




}
/// @nodoc
class _$ToolCallRequestCopyWithImpl<$Res>
    implements $ToolCallRequestCopyWith<$Res> {
  _$ToolCallRequestCopyWithImpl(this._self, this._then);

  final ToolCallRequest _self;
  final $Res Function(ToolCallRequest) _then;

/// Create a copy of ToolCallRequest
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? toolName = null,Object? displayTitle = null,Object? argumentsSummary = freezed,Object? requiresConfirmation = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as ToolCallId,toolName: null == toolName ? _self.toolName : toolName // ignore: cast_nullable_to_non_nullable
as String,displayTitle: null == displayTitle ? _self.displayTitle : displayTitle // ignore: cast_nullable_to_non_nullable
as String,argumentsSummary: freezed == argumentsSummary ? _self.argumentsSummary : argumentsSummary // ignore: cast_nullable_to_non_nullable
as String?,requiresConfirmation: null == requiresConfirmation ? _self.requiresConfirmation : requiresConfirmation // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [ToolCallRequest].
extension ToolCallRequestPatterns on ToolCallRequest {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ToolCallRequest value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ToolCallRequest() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ToolCallRequest value)  $default,){
final _that = this;
switch (_that) {
case _ToolCallRequest():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ToolCallRequest value)?  $default,){
final _that = this;
switch (_that) {
case _ToolCallRequest() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@ToolCallIdConverter()  ToolCallId id,  String toolName,  String displayTitle,  String? argumentsSummary,  bool requiresConfirmation)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ToolCallRequest() when $default != null:
return $default(_that.id,_that.toolName,_that.displayTitle,_that.argumentsSummary,_that.requiresConfirmation);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@ToolCallIdConverter()  ToolCallId id,  String toolName,  String displayTitle,  String? argumentsSummary,  bool requiresConfirmation)  $default,) {final _that = this;
switch (_that) {
case _ToolCallRequest():
return $default(_that.id,_that.toolName,_that.displayTitle,_that.argumentsSummary,_that.requiresConfirmation);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@ToolCallIdConverter()  ToolCallId id,  String toolName,  String displayTitle,  String? argumentsSummary,  bool requiresConfirmation)?  $default,) {final _that = this;
switch (_that) {
case _ToolCallRequest() when $default != null:
return $default(_that.id,_that.toolName,_that.displayTitle,_that.argumentsSummary,_that.requiresConfirmation);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ToolCallRequest implements ToolCallRequest {
  const _ToolCallRequest({@ToolCallIdConverter() required this.id, required this.toolName, required this.displayTitle, this.argumentsSummary, this.requiresConfirmation = false});
  factory _ToolCallRequest.fromJson(Map<String, dynamic> json) => _$ToolCallRequestFromJson(json);

@override@ToolCallIdConverter() final  ToolCallId id;
/// Backend tool name (e.g. `restaurants.search`). Not shown raw to users.
@override final  String toolName;
/// Localised, user-facing title supplied by the backend.
@override final  String displayTitle;
/// Optional short, user-safe summary of the arguments.
@override final  String? argumentsSummary;
/// Whether the backend will wait for explicit user confirmation.
@override@JsonKey() final  bool requiresConfirmation;

/// Create a copy of ToolCallRequest
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ToolCallRequestCopyWith<_ToolCallRequest> get copyWith => __$ToolCallRequestCopyWithImpl<_ToolCallRequest>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ToolCallRequestToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ToolCallRequest&&(identical(other.id, id) || other.id == id)&&(identical(other.toolName, toolName) || other.toolName == toolName)&&(identical(other.displayTitle, displayTitle) || other.displayTitle == displayTitle)&&(identical(other.argumentsSummary, argumentsSummary) || other.argumentsSummary == argumentsSummary)&&(identical(other.requiresConfirmation, requiresConfirmation) || other.requiresConfirmation == requiresConfirmation));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,toolName,displayTitle,argumentsSummary,requiresConfirmation);

@override
String toString() {
  return 'ToolCallRequest(id: $id, toolName: $toolName, displayTitle: $displayTitle, argumentsSummary: $argumentsSummary, requiresConfirmation: $requiresConfirmation)';
}


}

/// @nodoc
abstract mixin class _$ToolCallRequestCopyWith<$Res> implements $ToolCallRequestCopyWith<$Res> {
  factory _$ToolCallRequestCopyWith(_ToolCallRequest value, $Res Function(_ToolCallRequest) _then) = __$ToolCallRequestCopyWithImpl;
@override @useResult
$Res call({
@ToolCallIdConverter() ToolCallId id, String toolName, String displayTitle, String? argumentsSummary, bool requiresConfirmation
});




}
/// @nodoc
class __$ToolCallRequestCopyWithImpl<$Res>
    implements _$ToolCallRequestCopyWith<$Res> {
  __$ToolCallRequestCopyWithImpl(this._self, this._then);

  final _ToolCallRequest _self;
  final $Res Function(_ToolCallRequest) _then;

/// Create a copy of ToolCallRequest
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? toolName = null,Object? displayTitle = null,Object? argumentsSummary = freezed,Object? requiresConfirmation = null,}) {
  return _then(_ToolCallRequest(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as ToolCallId,toolName: null == toolName ? _self.toolName : toolName // ignore: cast_nullable_to_non_nullable
as String,displayTitle: null == displayTitle ? _self.displayTitle : displayTitle // ignore: cast_nullable_to_non_nullable
as String,argumentsSummary: freezed == argumentsSummary ? _self.argumentsSummary : argumentsSummary // ignore: cast_nullable_to_non_nullable
as String?,requiresConfirmation: null == requiresConfirmation ? _self.requiresConfirmation : requiresConfirmation // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
