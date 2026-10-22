// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'conversation_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ToolCallState {

 ToolCallRequest get request; MessageId get messageId; ToolExecutionStatus get status; double? get progress; String? get statusMessage; ToolResult? get result; ConfirmationSpec? get pendingConfirmation;
/// Create a copy of ToolCallState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ToolCallStateCopyWith<ToolCallState> get copyWith => _$ToolCallStateCopyWithImpl<ToolCallState>(this as ToolCallState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ToolCallState&&(identical(other.request, request) || other.request == request)&&(identical(other.messageId, messageId) || other.messageId == messageId)&&(identical(other.status, status) || other.status == status)&&(identical(other.progress, progress) || other.progress == progress)&&(identical(other.statusMessage, statusMessage) || other.statusMessage == statusMessage)&&(identical(other.result, result) || other.result == result)&&(identical(other.pendingConfirmation, pendingConfirmation) || other.pendingConfirmation == pendingConfirmation));
}


@override
int get hashCode => Object.hash(runtimeType,request,messageId,status,progress,statusMessage,result,pendingConfirmation);

@override
String toString() {
  return 'ToolCallState(request: $request, messageId: $messageId, status: $status, progress: $progress, statusMessage: $statusMessage, result: $result, pendingConfirmation: $pendingConfirmation)';
}


}

/// @nodoc
abstract mixin class $ToolCallStateCopyWith<$Res>  {
  factory $ToolCallStateCopyWith(ToolCallState value, $Res Function(ToolCallState) _then) = _$ToolCallStateCopyWithImpl;
@useResult
$Res call({
 ToolCallRequest request, MessageId messageId, ToolExecutionStatus status, double? progress, String? statusMessage, ToolResult? result, ConfirmationSpec? pendingConfirmation
});


$ToolCallRequestCopyWith<$Res> get request;$ToolResultCopyWith<$Res>? get result;$ConfirmationSpecCopyWith<$Res>? get pendingConfirmation;

}
/// @nodoc
class _$ToolCallStateCopyWithImpl<$Res>
    implements $ToolCallStateCopyWith<$Res> {
  _$ToolCallStateCopyWithImpl(this._self, this._then);

  final ToolCallState _self;
  final $Res Function(ToolCallState) _then;

/// Create a copy of ToolCallState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? request = null,Object? messageId = null,Object? status = null,Object? progress = freezed,Object? statusMessage = freezed,Object? result = freezed,Object? pendingConfirmation = freezed,}) {
  return _then(_self.copyWith(
request: null == request ? _self.request : request // ignore: cast_nullable_to_non_nullable
as ToolCallRequest,messageId: null == messageId ? _self.messageId : messageId // ignore: cast_nullable_to_non_nullable
as MessageId,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as ToolExecutionStatus,progress: freezed == progress ? _self.progress : progress // ignore: cast_nullable_to_non_nullable
as double?,statusMessage: freezed == statusMessage ? _self.statusMessage : statusMessage // ignore: cast_nullable_to_non_nullable
as String?,result: freezed == result ? _self.result : result // ignore: cast_nullable_to_non_nullable
as ToolResult?,pendingConfirmation: freezed == pendingConfirmation ? _self.pendingConfirmation : pendingConfirmation // ignore: cast_nullable_to_non_nullable
as ConfirmationSpec?,
  ));
}
/// Create a copy of ToolCallState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ToolCallRequestCopyWith<$Res> get request {
  
  return $ToolCallRequestCopyWith<$Res>(_self.request, (value) {
    return _then(_self.copyWith(request: value));
  });
}/// Create a copy of ToolCallState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ToolResultCopyWith<$Res>? get result {
    if (_self.result == null) {
    return null;
  }

  return $ToolResultCopyWith<$Res>(_self.result!, (value) {
    return _then(_self.copyWith(result: value));
  });
}/// Create a copy of ToolCallState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ConfirmationSpecCopyWith<$Res>? get pendingConfirmation {
    if (_self.pendingConfirmation == null) {
    return null;
  }

  return $ConfirmationSpecCopyWith<$Res>(_self.pendingConfirmation!, (value) {
    return _then(_self.copyWith(pendingConfirmation: value));
  });
}
}


/// Adds pattern-matching-related methods to [ToolCallState].
extension ToolCallStatePatterns on ToolCallState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ToolCallState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ToolCallState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ToolCallState value)  $default,){
final _that = this;
switch (_that) {
case _ToolCallState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ToolCallState value)?  $default,){
final _that = this;
switch (_that) {
case _ToolCallState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( ToolCallRequest request,  MessageId messageId,  ToolExecutionStatus status,  double? progress,  String? statusMessage,  ToolResult? result,  ConfirmationSpec? pendingConfirmation)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ToolCallState() when $default != null:
return $default(_that.request,_that.messageId,_that.status,_that.progress,_that.statusMessage,_that.result,_that.pendingConfirmation);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( ToolCallRequest request,  MessageId messageId,  ToolExecutionStatus status,  double? progress,  String? statusMessage,  ToolResult? result,  ConfirmationSpec? pendingConfirmation)  $default,) {final _that = this;
switch (_that) {
case _ToolCallState():
return $default(_that.request,_that.messageId,_that.status,_that.progress,_that.statusMessage,_that.result,_that.pendingConfirmation);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( ToolCallRequest request,  MessageId messageId,  ToolExecutionStatus status,  double? progress,  String? statusMessage,  ToolResult? result,  ConfirmationSpec? pendingConfirmation)?  $default,) {final _that = this;
switch (_that) {
case _ToolCallState() when $default != null:
return $default(_that.request,_that.messageId,_that.status,_that.progress,_that.statusMessage,_that.result,_that.pendingConfirmation);case _:
  return null;

}
}

}

/// @nodoc


class _ToolCallState implements ToolCallState {
  const _ToolCallState({required this.request, required this.messageId, required this.status, this.progress, this.statusMessage, this.result, this.pendingConfirmation});
  

@override final  ToolCallRequest request;
@override final  MessageId messageId;
@override final  ToolExecutionStatus status;
@override final  double? progress;
@override final  String? statusMessage;
@override final  ToolResult? result;
@override final  ConfirmationSpec? pendingConfirmation;

/// Create a copy of ToolCallState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ToolCallStateCopyWith<_ToolCallState> get copyWith => __$ToolCallStateCopyWithImpl<_ToolCallState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ToolCallState&&(identical(other.request, request) || other.request == request)&&(identical(other.messageId, messageId) || other.messageId == messageId)&&(identical(other.status, status) || other.status == status)&&(identical(other.progress, progress) || other.progress == progress)&&(identical(other.statusMessage, statusMessage) || other.statusMessage == statusMessage)&&(identical(other.result, result) || other.result == result)&&(identical(other.pendingConfirmation, pendingConfirmation) || other.pendingConfirmation == pendingConfirmation));
}


@override
int get hashCode => Object.hash(runtimeType,request,messageId,status,progress,statusMessage,result,pendingConfirmation);

@override
String toString() {
  return 'ToolCallState(request: $request, messageId: $messageId, status: $status, progress: $progress, statusMessage: $statusMessage, result: $result, pendingConfirmation: $pendingConfirmation)';
}


}

/// @nodoc
abstract mixin class _$ToolCallStateCopyWith<$Res> implements $ToolCallStateCopyWith<$Res> {
  factory _$ToolCallStateCopyWith(_ToolCallState value, $Res Function(_ToolCallState) _then) = __$ToolCallStateCopyWithImpl;
@override @useResult
$Res call({
 ToolCallRequest request, MessageId messageId, ToolExecutionStatus status, double? progress, String? statusMessage, ToolResult? result, ConfirmationSpec? pendingConfirmation
});


@override $ToolCallRequestCopyWith<$Res> get request;@override $ToolResultCopyWith<$Res>? get result;@override $ConfirmationSpecCopyWith<$Res>? get pendingConfirmation;

}
/// @nodoc
class __$ToolCallStateCopyWithImpl<$Res>
    implements _$ToolCallStateCopyWith<$Res> {
  __$ToolCallStateCopyWithImpl(this._self, this._then);

  final _ToolCallState _self;
  final $Res Function(_ToolCallState) _then;

/// Create a copy of ToolCallState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? request = null,Object? messageId = null,Object? status = null,Object? progress = freezed,Object? statusMessage = freezed,Object? result = freezed,Object? pendingConfirmation = freezed,}) {
  return _then(_ToolCallState(
request: null == request ? _self.request : request // ignore: cast_nullable_to_non_nullable
as ToolCallRequest,messageId: null == messageId ? _self.messageId : messageId // ignore: cast_nullable_to_non_nullable
as MessageId,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as ToolExecutionStatus,progress: freezed == progress ? _self.progress : progress // ignore: cast_nullable_to_non_nullable
as double?,statusMessage: freezed == statusMessage ? _self.statusMessage : statusMessage // ignore: cast_nullable_to_non_nullable
as String?,result: freezed == result ? _self.result : result // ignore: cast_nullable_to_non_nullable
as ToolResult?,pendingConfirmation: freezed == pendingConfirmation ? _self.pendingConfirmation : pendingConfirmation // ignore: cast_nullable_to_non_nullable
as ConfirmationSpec?,
  ));
}

/// Create a copy of ToolCallState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ToolCallRequestCopyWith<$Res> get request {
  
  return $ToolCallRequestCopyWith<$Res>(_self.request, (value) {
    return _then(_self.copyWith(request: value));
  });
}/// Create a copy of ToolCallState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ToolResultCopyWith<$Res>? get result {
    if (_self.result == null) {
    return null;
  }

  return $ToolResultCopyWith<$Res>(_self.result!, (value) {
    return _then(_self.copyWith(result: value));
  });
}/// Create a copy of ToolCallState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ConfirmationSpecCopyWith<$Res>? get pendingConfirmation {
    if (_self.pendingConfirmation == null) {
    return null;
  }

  return $ConfirmationSpecCopyWith<$Res>(_self.pendingConfirmation!, (value) {
    return _then(_self.copyWith(pendingConfirmation: value));
  });
}
}

/// @nodoc
mixin _$PendingPermission {

 String get requestId; NexaPermission get permission; String? get reason;
/// Create a copy of PendingPermission
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PendingPermissionCopyWith<PendingPermission> get copyWith => _$PendingPermissionCopyWithImpl<PendingPermission>(this as PendingPermission, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PendingPermission&&(identical(other.requestId, requestId) || other.requestId == requestId)&&(identical(other.permission, permission) || other.permission == permission)&&(identical(other.reason, reason) || other.reason == reason));
}


@override
int get hashCode => Object.hash(runtimeType,requestId,permission,reason);

@override
String toString() {
  return 'PendingPermission(requestId: $requestId, permission: $permission, reason: $reason)';
}


}

/// @nodoc
abstract mixin class $PendingPermissionCopyWith<$Res>  {
  factory $PendingPermissionCopyWith(PendingPermission value, $Res Function(PendingPermission) _then) = _$PendingPermissionCopyWithImpl;
@useResult
$Res call({
 String requestId, NexaPermission permission, String? reason
});




}
/// @nodoc
class _$PendingPermissionCopyWithImpl<$Res>
    implements $PendingPermissionCopyWith<$Res> {
  _$PendingPermissionCopyWithImpl(this._self, this._then);

  final PendingPermission _self;
  final $Res Function(PendingPermission) _then;

/// Create a copy of PendingPermission
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? requestId = null,Object? permission = null,Object? reason = freezed,}) {
  return _then(_self.copyWith(
requestId: null == requestId ? _self.requestId : requestId // ignore: cast_nullable_to_non_nullable
as String,permission: null == permission ? _self.permission : permission // ignore: cast_nullable_to_non_nullable
as NexaPermission,reason: freezed == reason ? _self.reason : reason // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [PendingPermission].
extension PendingPermissionPatterns on PendingPermission {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PendingPermission value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PendingPermission() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PendingPermission value)  $default,){
final _that = this;
switch (_that) {
case _PendingPermission():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PendingPermission value)?  $default,){
final _that = this;
switch (_that) {
case _PendingPermission() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String requestId,  NexaPermission permission,  String? reason)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PendingPermission() when $default != null:
return $default(_that.requestId,_that.permission,_that.reason);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String requestId,  NexaPermission permission,  String? reason)  $default,) {final _that = this;
switch (_that) {
case _PendingPermission():
return $default(_that.requestId,_that.permission,_that.reason);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String requestId,  NexaPermission permission,  String? reason)?  $default,) {final _that = this;
switch (_that) {
case _PendingPermission() when $default != null:
return $default(_that.requestId,_that.permission,_that.reason);case _:
  return null;

}
}

}

/// @nodoc


class _PendingPermission implements PendingPermission {
  const _PendingPermission({required this.requestId, required this.permission, this.reason});
  

@override final  String requestId;
@override final  NexaPermission permission;
@override final  String? reason;

/// Create a copy of PendingPermission
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PendingPermissionCopyWith<_PendingPermission> get copyWith => __$PendingPermissionCopyWithImpl<_PendingPermission>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PendingPermission&&(identical(other.requestId, requestId) || other.requestId == requestId)&&(identical(other.permission, permission) || other.permission == permission)&&(identical(other.reason, reason) || other.reason == reason));
}


@override
int get hashCode => Object.hash(runtimeType,requestId,permission,reason);

@override
String toString() {
  return 'PendingPermission(requestId: $requestId, permission: $permission, reason: $reason)';
}


}

/// @nodoc
abstract mixin class _$PendingPermissionCopyWith<$Res> implements $PendingPermissionCopyWith<$Res> {
  factory _$PendingPermissionCopyWith(_PendingPermission value, $Res Function(_PendingPermission) _then) = __$PendingPermissionCopyWithImpl;
@override @useResult
$Res call({
 String requestId, NexaPermission permission, String? reason
});




}
/// @nodoc
class __$PendingPermissionCopyWithImpl<$Res>
    implements _$PendingPermissionCopyWith<$Res> {
  __$PendingPermissionCopyWithImpl(this._self, this._then);

  final _PendingPermission _self;
  final $Res Function(_PendingPermission) _then;

/// Create a copy of PendingPermission
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? requestId = null,Object? permission = null,Object? reason = freezed,}) {
  return _then(_PendingPermission(
requestId: null == requestId ? _self.requestId : requestId // ignore: cast_nullable_to_non_nullable
as String,permission: null == permission ? _self.permission : permission // ignore: cast_nullable_to_non_nullable
as NexaPermission,reason: freezed == reason ? _self.reason : reason // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc
mixin _$ConversationState {

 ConversationPhase get phase; SessionId? get sessionId; DateTime? get sessionExpiresAt;/// Messages in display order.
 List<ChatMessage> get messages; Map<ToolCallId, ToolCallState> get toolCalls; List<PendingPermission> get pendingPermissions;/// Highest sequence applied so far (0 = none).
 int get lastSequence; QuotaInfo? get quota; bool get quotaExceeded; SessionEndReason? get endReason;/// Last session-level error.
 EventError? get lastError;
/// Create a copy of ConversationState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ConversationStateCopyWith<ConversationState> get copyWith => _$ConversationStateCopyWithImpl<ConversationState>(this as ConversationState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ConversationState&&(identical(other.phase, phase) || other.phase == phase)&&(identical(other.sessionId, sessionId) || other.sessionId == sessionId)&&(identical(other.sessionExpiresAt, sessionExpiresAt) || other.sessionExpiresAt == sessionExpiresAt)&&const DeepCollectionEquality().equals(other.messages, messages)&&const DeepCollectionEquality().equals(other.toolCalls, toolCalls)&&const DeepCollectionEquality().equals(other.pendingPermissions, pendingPermissions)&&(identical(other.lastSequence, lastSequence) || other.lastSequence == lastSequence)&&(identical(other.quota, quota) || other.quota == quota)&&(identical(other.quotaExceeded, quotaExceeded) || other.quotaExceeded == quotaExceeded)&&(identical(other.endReason, endReason) || other.endReason == endReason)&&(identical(other.lastError, lastError) || other.lastError == lastError));
}


@override
int get hashCode => Object.hash(runtimeType,phase,sessionId,sessionExpiresAt,const DeepCollectionEquality().hash(messages),const DeepCollectionEquality().hash(toolCalls),const DeepCollectionEquality().hash(pendingPermissions),lastSequence,quota,quotaExceeded,endReason,lastError);

@override
String toString() {
  return 'ConversationState(phase: $phase, sessionId: $sessionId, sessionExpiresAt: $sessionExpiresAt, messages: $messages, toolCalls: $toolCalls, pendingPermissions: $pendingPermissions, lastSequence: $lastSequence, quota: $quota, quotaExceeded: $quotaExceeded, endReason: $endReason, lastError: $lastError)';
}


}

/// @nodoc
abstract mixin class $ConversationStateCopyWith<$Res>  {
  factory $ConversationStateCopyWith(ConversationState value, $Res Function(ConversationState) _then) = _$ConversationStateCopyWithImpl;
@useResult
$Res call({
 ConversationPhase phase, SessionId? sessionId, DateTime? sessionExpiresAt, List<ChatMessage> messages, Map<ToolCallId, ToolCallState> toolCalls, List<PendingPermission> pendingPermissions, int lastSequence, QuotaInfo? quota, bool quotaExceeded, SessionEndReason? endReason, EventError? lastError
});


$QuotaInfoCopyWith<$Res>? get quota;$EventErrorCopyWith<$Res>? get lastError;

}
/// @nodoc
class _$ConversationStateCopyWithImpl<$Res>
    implements $ConversationStateCopyWith<$Res> {
  _$ConversationStateCopyWithImpl(this._self, this._then);

  final ConversationState _self;
  final $Res Function(ConversationState) _then;

/// Create a copy of ConversationState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? phase = null,Object? sessionId = freezed,Object? sessionExpiresAt = freezed,Object? messages = null,Object? toolCalls = null,Object? pendingPermissions = null,Object? lastSequence = null,Object? quota = freezed,Object? quotaExceeded = null,Object? endReason = freezed,Object? lastError = freezed,}) {
  return _then(_self.copyWith(
phase: null == phase ? _self.phase : phase // ignore: cast_nullable_to_non_nullable
as ConversationPhase,sessionId: freezed == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as SessionId?,sessionExpiresAt: freezed == sessionExpiresAt ? _self.sessionExpiresAt : sessionExpiresAt // ignore: cast_nullable_to_non_nullable
as DateTime?,messages: null == messages ? _self.messages : messages // ignore: cast_nullable_to_non_nullable
as List<ChatMessage>,toolCalls: null == toolCalls ? _self.toolCalls : toolCalls // ignore: cast_nullable_to_non_nullable
as Map<ToolCallId, ToolCallState>,pendingPermissions: null == pendingPermissions ? _self.pendingPermissions : pendingPermissions // ignore: cast_nullable_to_non_nullable
as List<PendingPermission>,lastSequence: null == lastSequence ? _self.lastSequence : lastSequence // ignore: cast_nullable_to_non_nullable
as int,quota: freezed == quota ? _self.quota : quota // ignore: cast_nullable_to_non_nullable
as QuotaInfo?,quotaExceeded: null == quotaExceeded ? _self.quotaExceeded : quotaExceeded // ignore: cast_nullable_to_non_nullable
as bool,endReason: freezed == endReason ? _self.endReason : endReason // ignore: cast_nullable_to_non_nullable
as SessionEndReason?,lastError: freezed == lastError ? _self.lastError : lastError // ignore: cast_nullable_to_non_nullable
as EventError?,
  ));
}
/// Create a copy of ConversationState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$QuotaInfoCopyWith<$Res>? get quota {
    if (_self.quota == null) {
    return null;
  }

  return $QuotaInfoCopyWith<$Res>(_self.quota!, (value) {
    return _then(_self.copyWith(quota: value));
  });
}/// Create a copy of ConversationState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$EventErrorCopyWith<$Res>? get lastError {
    if (_self.lastError == null) {
    return null;
  }

  return $EventErrorCopyWith<$Res>(_self.lastError!, (value) {
    return _then(_self.copyWith(lastError: value));
  });
}
}


/// Adds pattern-matching-related methods to [ConversationState].
extension ConversationStatePatterns on ConversationState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ConversationState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ConversationState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ConversationState value)  $default,){
final _that = this;
switch (_that) {
case _ConversationState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ConversationState value)?  $default,){
final _that = this;
switch (_that) {
case _ConversationState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( ConversationPhase phase,  SessionId? sessionId,  DateTime? sessionExpiresAt,  List<ChatMessage> messages,  Map<ToolCallId, ToolCallState> toolCalls,  List<PendingPermission> pendingPermissions,  int lastSequence,  QuotaInfo? quota,  bool quotaExceeded,  SessionEndReason? endReason,  EventError? lastError)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ConversationState() when $default != null:
return $default(_that.phase,_that.sessionId,_that.sessionExpiresAt,_that.messages,_that.toolCalls,_that.pendingPermissions,_that.lastSequence,_that.quota,_that.quotaExceeded,_that.endReason,_that.lastError);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( ConversationPhase phase,  SessionId? sessionId,  DateTime? sessionExpiresAt,  List<ChatMessage> messages,  Map<ToolCallId, ToolCallState> toolCalls,  List<PendingPermission> pendingPermissions,  int lastSequence,  QuotaInfo? quota,  bool quotaExceeded,  SessionEndReason? endReason,  EventError? lastError)  $default,) {final _that = this;
switch (_that) {
case _ConversationState():
return $default(_that.phase,_that.sessionId,_that.sessionExpiresAt,_that.messages,_that.toolCalls,_that.pendingPermissions,_that.lastSequence,_that.quota,_that.quotaExceeded,_that.endReason,_that.lastError);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( ConversationPhase phase,  SessionId? sessionId,  DateTime? sessionExpiresAt,  List<ChatMessage> messages,  Map<ToolCallId, ToolCallState> toolCalls,  List<PendingPermission> pendingPermissions,  int lastSequence,  QuotaInfo? quota,  bool quotaExceeded,  SessionEndReason? endReason,  EventError? lastError)?  $default,) {final _that = this;
switch (_that) {
case _ConversationState() when $default != null:
return $default(_that.phase,_that.sessionId,_that.sessionExpiresAt,_that.messages,_that.toolCalls,_that.pendingPermissions,_that.lastSequence,_that.quota,_that.quotaExceeded,_that.endReason,_that.lastError);case _:
  return null;

}
}

}

/// @nodoc


class _ConversationState extends ConversationState {
  const _ConversationState({this.phase = ConversationPhase.idle, this.sessionId, this.sessionExpiresAt, final  List<ChatMessage> messages = const <ChatMessage>[], final  Map<ToolCallId, ToolCallState> toolCalls = const <ToolCallId, ToolCallState>{}, final  List<PendingPermission> pendingPermissions = const <PendingPermission>[], this.lastSequence = 0, this.quota, this.quotaExceeded = false, this.endReason, this.lastError}): _messages = messages,_toolCalls = toolCalls,_pendingPermissions = pendingPermissions,super._();
  

@override@JsonKey() final  ConversationPhase phase;
@override final  SessionId? sessionId;
@override final  DateTime? sessionExpiresAt;
/// Messages in display order.
 final  List<ChatMessage> _messages;
/// Messages in display order.
@override@JsonKey() List<ChatMessage> get messages {
  if (_messages is EqualUnmodifiableListView) return _messages;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_messages);
}

 final  Map<ToolCallId, ToolCallState> _toolCalls;
@override@JsonKey() Map<ToolCallId, ToolCallState> get toolCalls {
  if (_toolCalls is EqualUnmodifiableMapView) return _toolCalls;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_toolCalls);
}

 final  List<PendingPermission> _pendingPermissions;
@override@JsonKey() List<PendingPermission> get pendingPermissions {
  if (_pendingPermissions is EqualUnmodifiableListView) return _pendingPermissions;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_pendingPermissions);
}

/// Highest sequence applied so far (0 = none).
@override@JsonKey() final  int lastSequence;
@override final  QuotaInfo? quota;
@override@JsonKey() final  bool quotaExceeded;
@override final  SessionEndReason? endReason;
/// Last session-level error.
@override final  EventError? lastError;

/// Create a copy of ConversationState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ConversationStateCopyWith<_ConversationState> get copyWith => __$ConversationStateCopyWithImpl<_ConversationState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ConversationState&&(identical(other.phase, phase) || other.phase == phase)&&(identical(other.sessionId, sessionId) || other.sessionId == sessionId)&&(identical(other.sessionExpiresAt, sessionExpiresAt) || other.sessionExpiresAt == sessionExpiresAt)&&const DeepCollectionEquality().equals(other._messages, _messages)&&const DeepCollectionEquality().equals(other._toolCalls, _toolCalls)&&const DeepCollectionEquality().equals(other._pendingPermissions, _pendingPermissions)&&(identical(other.lastSequence, lastSequence) || other.lastSequence == lastSequence)&&(identical(other.quota, quota) || other.quota == quota)&&(identical(other.quotaExceeded, quotaExceeded) || other.quotaExceeded == quotaExceeded)&&(identical(other.endReason, endReason) || other.endReason == endReason)&&(identical(other.lastError, lastError) || other.lastError == lastError));
}


@override
int get hashCode => Object.hash(runtimeType,phase,sessionId,sessionExpiresAt,const DeepCollectionEquality().hash(_messages),const DeepCollectionEquality().hash(_toolCalls),const DeepCollectionEquality().hash(_pendingPermissions),lastSequence,quota,quotaExceeded,endReason,lastError);

@override
String toString() {
  return 'ConversationState(phase: $phase, sessionId: $sessionId, sessionExpiresAt: $sessionExpiresAt, messages: $messages, toolCalls: $toolCalls, pendingPermissions: $pendingPermissions, lastSequence: $lastSequence, quota: $quota, quotaExceeded: $quotaExceeded, endReason: $endReason, lastError: $lastError)';
}


}

/// @nodoc
abstract mixin class _$ConversationStateCopyWith<$Res> implements $ConversationStateCopyWith<$Res> {
  factory _$ConversationStateCopyWith(_ConversationState value, $Res Function(_ConversationState) _then) = __$ConversationStateCopyWithImpl;
@override @useResult
$Res call({
 ConversationPhase phase, SessionId? sessionId, DateTime? sessionExpiresAt, List<ChatMessage> messages, Map<ToolCallId, ToolCallState> toolCalls, List<PendingPermission> pendingPermissions, int lastSequence, QuotaInfo? quota, bool quotaExceeded, SessionEndReason? endReason, EventError? lastError
});


@override $QuotaInfoCopyWith<$Res>? get quota;@override $EventErrorCopyWith<$Res>? get lastError;

}
/// @nodoc
class __$ConversationStateCopyWithImpl<$Res>
    implements _$ConversationStateCopyWith<$Res> {
  __$ConversationStateCopyWithImpl(this._self, this._then);

  final _ConversationState _self;
  final $Res Function(_ConversationState) _then;

/// Create a copy of ConversationState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? phase = null,Object? sessionId = freezed,Object? sessionExpiresAt = freezed,Object? messages = null,Object? toolCalls = null,Object? pendingPermissions = null,Object? lastSequence = null,Object? quota = freezed,Object? quotaExceeded = null,Object? endReason = freezed,Object? lastError = freezed,}) {
  return _then(_ConversationState(
phase: null == phase ? _self.phase : phase // ignore: cast_nullable_to_non_nullable
as ConversationPhase,sessionId: freezed == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as SessionId?,sessionExpiresAt: freezed == sessionExpiresAt ? _self.sessionExpiresAt : sessionExpiresAt // ignore: cast_nullable_to_non_nullable
as DateTime?,messages: null == messages ? _self._messages : messages // ignore: cast_nullable_to_non_nullable
as List<ChatMessage>,toolCalls: null == toolCalls ? _self._toolCalls : toolCalls // ignore: cast_nullable_to_non_nullable
as Map<ToolCallId, ToolCallState>,pendingPermissions: null == pendingPermissions ? _self._pendingPermissions : pendingPermissions // ignore: cast_nullable_to_non_nullable
as List<PendingPermission>,lastSequence: null == lastSequence ? _self.lastSequence : lastSequence // ignore: cast_nullable_to_non_nullable
as int,quota: freezed == quota ? _self.quota : quota // ignore: cast_nullable_to_non_nullable
as QuotaInfo?,quotaExceeded: null == quotaExceeded ? _self.quotaExceeded : quotaExceeded // ignore: cast_nullable_to_non_nullable
as bool,endReason: freezed == endReason ? _self.endReason : endReason // ignore: cast_nullable_to_non_nullable
as SessionEndReason?,lastError: freezed == lastError ? _self.lastError : lastError // ignore: cast_nullable_to_non_nullable
as EventError?,
  ));
}

/// Create a copy of ConversationState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$QuotaInfoCopyWith<$Res>? get quota {
    if (_self.quota == null) {
    return null;
  }

  return $QuotaInfoCopyWith<$Res>(_self.quota!, (value) {
    return _then(_self.copyWith(quota: value));
  });
}/// Create a copy of ConversationState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$EventErrorCopyWith<$Res>? get lastError {
    if (_self.lastError == null) {
    return null;
  }

  return $EventErrorCopyWith<$Res>(_self.lastError!, (value) {
    return _then(_self.copyWith(lastError: value));
  });
}
}

// dart format on
