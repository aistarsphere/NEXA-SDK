// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'session_handle.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$SessionHandle {

 SessionId get sessionId; DateTime get expiresAt;/// Capabilities the gateway actually granted (policy-filtered).
 Set<NexaCapability> get grantedCapabilities;/// Sequence to resume from when reconnecting (0 for a new session).
 int get lastSequence;
/// Create a copy of SessionHandle
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SessionHandleCopyWith<SessionHandle> get copyWith => _$SessionHandleCopyWithImpl<SessionHandle>(this as SessionHandle, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SessionHandle&&(identical(other.sessionId, sessionId) || other.sessionId == sessionId)&&(identical(other.expiresAt, expiresAt) || other.expiresAt == expiresAt)&&const DeepCollectionEquality().equals(other.grantedCapabilities, grantedCapabilities)&&(identical(other.lastSequence, lastSequence) || other.lastSequence == lastSequence));
}


@override
int get hashCode => Object.hash(runtimeType,sessionId,expiresAt,const DeepCollectionEquality().hash(grantedCapabilities),lastSequence);

@override
String toString() {
  return 'SessionHandle(sessionId: $sessionId, expiresAt: $expiresAt, grantedCapabilities: $grantedCapabilities, lastSequence: $lastSequence)';
}


}

/// @nodoc
abstract mixin class $SessionHandleCopyWith<$Res>  {
  factory $SessionHandleCopyWith(SessionHandle value, $Res Function(SessionHandle) _then) = _$SessionHandleCopyWithImpl;
@useResult
$Res call({
 SessionId sessionId, DateTime expiresAt, Set<NexaCapability> grantedCapabilities, int lastSequence
});




}
/// @nodoc
class _$SessionHandleCopyWithImpl<$Res>
    implements $SessionHandleCopyWith<$Res> {
  _$SessionHandleCopyWithImpl(this._self, this._then);

  final SessionHandle _self;
  final $Res Function(SessionHandle) _then;

/// Create a copy of SessionHandle
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? sessionId = null,Object? expiresAt = null,Object? grantedCapabilities = null,Object? lastSequence = null,}) {
  return _then(_self.copyWith(
sessionId: null == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as SessionId,expiresAt: null == expiresAt ? _self.expiresAt : expiresAt // ignore: cast_nullable_to_non_nullable
as DateTime,grantedCapabilities: null == grantedCapabilities ? _self.grantedCapabilities : grantedCapabilities // ignore: cast_nullable_to_non_nullable
as Set<NexaCapability>,lastSequence: null == lastSequence ? _self.lastSequence : lastSequence // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [SessionHandle].
extension SessionHandlePatterns on SessionHandle {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SessionHandle value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SessionHandle() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SessionHandle value)  $default,){
final _that = this;
switch (_that) {
case _SessionHandle():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SessionHandle value)?  $default,){
final _that = this;
switch (_that) {
case _SessionHandle() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( SessionId sessionId,  DateTime expiresAt,  Set<NexaCapability> grantedCapabilities,  int lastSequence)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SessionHandle() when $default != null:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( SessionId sessionId,  DateTime expiresAt,  Set<NexaCapability> grantedCapabilities,  int lastSequence)  $default,) {final _that = this;
switch (_that) {
case _SessionHandle():
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( SessionId sessionId,  DateTime expiresAt,  Set<NexaCapability> grantedCapabilities,  int lastSequence)?  $default,) {final _that = this;
switch (_that) {
case _SessionHandle() when $default != null:
return $default(_that.sessionId,_that.expiresAt,_that.grantedCapabilities,_that.lastSequence);case _:
  return null;

}
}

}

/// @nodoc


class _SessionHandle extends SessionHandle {
  const _SessionHandle({required this.sessionId, required this.expiresAt, required final  Set<NexaCapability> grantedCapabilities, this.lastSequence = 0}): _grantedCapabilities = grantedCapabilities,super._();
  

@override final  SessionId sessionId;
@override final  DateTime expiresAt;
/// Capabilities the gateway actually granted (policy-filtered).
 final  Set<NexaCapability> _grantedCapabilities;
/// Capabilities the gateway actually granted (policy-filtered).
@override Set<NexaCapability> get grantedCapabilities {
  if (_grantedCapabilities is EqualUnmodifiableSetView) return _grantedCapabilities;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableSetView(_grantedCapabilities);
}

/// Sequence to resume from when reconnecting (0 for a new session).
@override@JsonKey() final  int lastSequence;

/// Create a copy of SessionHandle
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SessionHandleCopyWith<_SessionHandle> get copyWith => __$SessionHandleCopyWithImpl<_SessionHandle>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SessionHandle&&(identical(other.sessionId, sessionId) || other.sessionId == sessionId)&&(identical(other.expiresAt, expiresAt) || other.expiresAt == expiresAt)&&const DeepCollectionEquality().equals(other._grantedCapabilities, _grantedCapabilities)&&(identical(other.lastSequence, lastSequence) || other.lastSequence == lastSequence));
}


@override
int get hashCode => Object.hash(runtimeType,sessionId,expiresAt,const DeepCollectionEquality().hash(_grantedCapabilities),lastSequence);

@override
String toString() {
  return 'SessionHandle(sessionId: $sessionId, expiresAt: $expiresAt, grantedCapabilities: $grantedCapabilities, lastSequence: $lastSequence)';
}


}

/// @nodoc
abstract mixin class _$SessionHandleCopyWith<$Res> implements $SessionHandleCopyWith<$Res> {
  factory _$SessionHandleCopyWith(_SessionHandle value, $Res Function(_SessionHandle) _then) = __$SessionHandleCopyWithImpl;
@override @useResult
$Res call({
 SessionId sessionId, DateTime expiresAt, Set<NexaCapability> grantedCapabilities, int lastSequence
});




}
/// @nodoc
class __$SessionHandleCopyWithImpl<$Res>
    implements _$SessionHandleCopyWith<$Res> {
  __$SessionHandleCopyWithImpl(this._self, this._then);

  final _SessionHandle _self;
  final $Res Function(_SessionHandle) _then;

/// Create a copy of SessionHandle
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? sessionId = null,Object? expiresAt = null,Object? grantedCapabilities = null,Object? lastSequence = null,}) {
  return _then(_SessionHandle(
sessionId: null == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as SessionId,expiresAt: null == expiresAt ? _self.expiresAt : expiresAt // ignore: cast_nullable_to_non_nullable
as DateTime,grantedCapabilities: null == grantedCapabilities ? _self._grantedCapabilities : grantedCapabilities // ignore: cast_nullable_to_non_nullable
as Set<NexaCapability>,lastSequence: null == lastSequence ? _self.lastSequence : lastSequence // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
