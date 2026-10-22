// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'conversation_event.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$EventError {

 String get code; String get message; bool get retryable;
/// Create a copy of EventError
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$EventErrorCopyWith<EventError> get copyWith => _$EventErrorCopyWithImpl<EventError>(this as EventError, _$identity);

  /// Serializes this EventError to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is EventError&&(identical(other.code, code) || other.code == code)&&(identical(other.message, message) || other.message == message)&&(identical(other.retryable, retryable) || other.retryable == retryable));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,code,message,retryable);

@override
String toString() {
  return 'EventError(code: $code, message: $message, retryable: $retryable)';
}


}

/// @nodoc
abstract mixin class $EventErrorCopyWith<$Res>  {
  factory $EventErrorCopyWith(EventError value, $Res Function(EventError) _then) = _$EventErrorCopyWithImpl;
@useResult
$Res call({
 String code, String message, bool retryable
});




}
/// @nodoc
class _$EventErrorCopyWithImpl<$Res>
    implements $EventErrorCopyWith<$Res> {
  _$EventErrorCopyWithImpl(this._self, this._then);

  final EventError _self;
  final $Res Function(EventError) _then;

/// Create a copy of EventError
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


/// Adds pattern-matching-related methods to [EventError].
extension EventErrorPatterns on EventError {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _EventError value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _EventError() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _EventError value)  $default,){
final _that = this;
switch (_that) {
case _EventError():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _EventError value)?  $default,){
final _that = this;
switch (_that) {
case _EventError() when $default != null:
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
case _EventError() when $default != null:
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
case _EventError():
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
case _EventError() when $default != null:
return $default(_that.code,_that.message,_that.retryable);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _EventError implements EventError {
  const _EventError({required this.code, required this.message, this.retryable = false});
  factory _EventError.fromJson(Map<String, dynamic> json) => _$EventErrorFromJson(json);

@override final  String code;
@override final  String message;
@override@JsonKey() final  bool retryable;

/// Create a copy of EventError
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$EventErrorCopyWith<_EventError> get copyWith => __$EventErrorCopyWithImpl<_EventError>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$EventErrorToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _EventError&&(identical(other.code, code) || other.code == code)&&(identical(other.message, message) || other.message == message)&&(identical(other.retryable, retryable) || other.retryable == retryable));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,code,message,retryable);

@override
String toString() {
  return 'EventError(code: $code, message: $message, retryable: $retryable)';
}


}

/// @nodoc
abstract mixin class _$EventErrorCopyWith<$Res> implements $EventErrorCopyWith<$Res> {
  factory _$EventErrorCopyWith(_EventError value, $Res Function(_EventError) _then) = __$EventErrorCopyWithImpl;
@override @useResult
$Res call({
 String code, String message, bool retryable
});




}
/// @nodoc
class __$EventErrorCopyWithImpl<$Res>
    implements _$EventErrorCopyWith<$Res> {
  __$EventErrorCopyWithImpl(this._self, this._then);

  final _EventError _self;
  final $Res Function(_EventError) _then;

/// Create a copy of EventError
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? code = null,Object? message = null,Object? retryable = null,}) {
  return _then(_EventError(
code: null == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as String,message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,retryable: null == retryable ? _self.retryable : retryable // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}


/// @nodoc
mixin _$QuotaInfo {

 String get kind; int? get remaining; int? get limit; DateTime? get resetsAt;
/// Create a copy of QuotaInfo
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$QuotaInfoCopyWith<QuotaInfo> get copyWith => _$QuotaInfoCopyWithImpl<QuotaInfo>(this as QuotaInfo, _$identity);

  /// Serializes this QuotaInfo to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is QuotaInfo&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.remaining, remaining) || other.remaining == remaining)&&(identical(other.limit, limit) || other.limit == limit)&&(identical(other.resetsAt, resetsAt) || other.resetsAt == resetsAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,kind,remaining,limit,resetsAt);

@override
String toString() {
  return 'QuotaInfo(kind: $kind, remaining: $remaining, limit: $limit, resetsAt: $resetsAt)';
}


}

/// @nodoc
abstract mixin class $QuotaInfoCopyWith<$Res>  {
  factory $QuotaInfoCopyWith(QuotaInfo value, $Res Function(QuotaInfo) _then) = _$QuotaInfoCopyWithImpl;
@useResult
$Res call({
 String kind, int? remaining, int? limit, DateTime? resetsAt
});




}
/// @nodoc
class _$QuotaInfoCopyWithImpl<$Res>
    implements $QuotaInfoCopyWith<$Res> {
  _$QuotaInfoCopyWithImpl(this._self, this._then);

  final QuotaInfo _self;
  final $Res Function(QuotaInfo) _then;

/// Create a copy of QuotaInfo
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? kind = null,Object? remaining = freezed,Object? limit = freezed,Object? resetsAt = freezed,}) {
  return _then(_self.copyWith(
kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as String,remaining: freezed == remaining ? _self.remaining : remaining // ignore: cast_nullable_to_non_nullable
as int?,limit: freezed == limit ? _self.limit : limit // ignore: cast_nullable_to_non_nullable
as int?,resetsAt: freezed == resetsAt ? _self.resetsAt : resetsAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [QuotaInfo].
extension QuotaInfoPatterns on QuotaInfo {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _QuotaInfo value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _QuotaInfo() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _QuotaInfo value)  $default,){
final _that = this;
switch (_that) {
case _QuotaInfo():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _QuotaInfo value)?  $default,){
final _that = this;
switch (_that) {
case _QuotaInfo() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String kind,  int? remaining,  int? limit,  DateTime? resetsAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _QuotaInfo() when $default != null:
return $default(_that.kind,_that.remaining,_that.limit,_that.resetsAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String kind,  int? remaining,  int? limit,  DateTime? resetsAt)  $default,) {final _that = this;
switch (_that) {
case _QuotaInfo():
return $default(_that.kind,_that.remaining,_that.limit,_that.resetsAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String kind,  int? remaining,  int? limit,  DateTime? resetsAt)?  $default,) {final _that = this;
switch (_that) {
case _QuotaInfo() when $default != null:
return $default(_that.kind,_that.remaining,_that.limit,_that.resetsAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _QuotaInfo implements QuotaInfo {
  const _QuotaInfo({required this.kind, this.remaining, this.limit, this.resetsAt});
  factory _QuotaInfo.fromJson(Map<String, dynamic> json) => _$QuotaInfoFromJson(json);

@override final  String kind;
@override final  int? remaining;
@override final  int? limit;
@override final  DateTime? resetsAt;

/// Create a copy of QuotaInfo
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$QuotaInfoCopyWith<_QuotaInfo> get copyWith => __$QuotaInfoCopyWithImpl<_QuotaInfo>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$QuotaInfoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _QuotaInfo&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.remaining, remaining) || other.remaining == remaining)&&(identical(other.limit, limit) || other.limit == limit)&&(identical(other.resetsAt, resetsAt) || other.resetsAt == resetsAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,kind,remaining,limit,resetsAt);

@override
String toString() {
  return 'QuotaInfo(kind: $kind, remaining: $remaining, limit: $limit, resetsAt: $resetsAt)';
}


}

/// @nodoc
abstract mixin class _$QuotaInfoCopyWith<$Res> implements $QuotaInfoCopyWith<$Res> {
  factory _$QuotaInfoCopyWith(_QuotaInfo value, $Res Function(_QuotaInfo) _then) = __$QuotaInfoCopyWithImpl;
@override @useResult
$Res call({
 String kind, int? remaining, int? limit, DateTime? resetsAt
});




}
/// @nodoc
class __$QuotaInfoCopyWithImpl<$Res>
    implements _$QuotaInfoCopyWith<$Res> {
  __$QuotaInfoCopyWithImpl(this._self, this._then);

  final _QuotaInfo _self;
  final $Res Function(_QuotaInfo) _then;

/// Create a copy of QuotaInfo
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? kind = null,Object? remaining = freezed,Object? limit = freezed,Object? resetsAt = freezed,}) {
  return _then(_QuotaInfo(
kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as String,remaining: freezed == remaining ? _self.remaining : remaining // ignore: cast_nullable_to_non_nullable
as int?,limit: freezed == limit ? _self.limit : limit // ignore: cast_nullable_to_non_nullable
as int?,resetsAt: freezed == resetsAt ? _self.resetsAt : resetsAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

ConversationEvent _$ConversationEventFromJson(
  Map<String, dynamic> json
) {
        switch (json['type']) {
                  case 'session_started':
          return SessionStartedEvent.fromJson(
            json
          );
                case 'session_ended':
          return SessionEndedEvent.fromJson(
            json
          );
                case 'user_message_accepted':
          return UserMessageAcceptedEvent.fromJson(
            json
          );
                case 'user_message_rejected':
          return UserMessageRejectedEvent.fromJson(
            json
          );
                case 'assistant_message_started':
          return AssistantMessageStartedEvent.fromJson(
            json
          );
                case 'assistant_text_delta':
          return AssistantTextDeltaEvent.fromJson(
            json
          );
                case 'assistant_message_completed':
          return AssistantMessageCompletedEvent.fromJson(
            json
          );
                case 'message_failed':
          return MessageFailedEvent.fromJson(
            json
          );
                case 'message_cancelled':
          return MessageCancelledEvent.fromJson(
            json
          );
                case 'tool_call_requested':
          return ToolCallRequestedEvent.fromJson(
            json
          );
                case 'tool_execution_progress':
          return ToolExecutionProgressEvent.fromJson(
            json
          );
                case 'tool_result_received':
          return ToolResultReceivedEvent.fromJson(
            json
          );
                case 'user_confirmation_requested':
          return UserConfirmationRequestedEvent.fromJson(
            json
          );
                case 'permission_requested':
          return PermissionRequestedEvent.fromJson(
            json
          );
                case 'quota_updated':
          return QuotaUpdatedEvent.fromJson(
            json
          );
                case 'unsupported':
          return UnsupportedEvent.fromJson(
            json
          );
        
          default:
            throw CheckedFromJsonException(
  json,
  'type',
  'ConversationEvent',
  'Invalid union type "${json['type']}"!'
);
        }
      
}

/// @nodoc
mixin _$ConversationEvent {

@EventIdConverter() EventId get eventId;@SessionIdConverter() SessionId get sessionId; int get sequence; DateTime get occurredAt;
/// Create a copy of ConversationEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ConversationEventCopyWith<ConversationEvent> get copyWith => _$ConversationEventCopyWithImpl<ConversationEvent>(this as ConversationEvent, _$identity);

  /// Serializes this ConversationEvent to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ConversationEvent&&(identical(other.eventId, eventId) || other.eventId == eventId)&&(identical(other.sessionId, sessionId) || other.sessionId == sessionId)&&(identical(other.sequence, sequence) || other.sequence == sequence)&&(identical(other.occurredAt, occurredAt) || other.occurredAt == occurredAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,eventId,sessionId,sequence,occurredAt);

@override
String toString() {
  return 'ConversationEvent(eventId: $eventId, sessionId: $sessionId, sequence: $sequence, occurredAt: $occurredAt)';
}


}

/// @nodoc
abstract mixin class $ConversationEventCopyWith<$Res>  {
  factory $ConversationEventCopyWith(ConversationEvent value, $Res Function(ConversationEvent) _then) = _$ConversationEventCopyWithImpl;
@useResult
$Res call({
@EventIdConverter() EventId eventId,@SessionIdConverter() SessionId sessionId, int sequence, DateTime occurredAt
});




}
/// @nodoc
class _$ConversationEventCopyWithImpl<$Res>
    implements $ConversationEventCopyWith<$Res> {
  _$ConversationEventCopyWithImpl(this._self, this._then);

  final ConversationEvent _self;
  final $Res Function(ConversationEvent) _then;

/// Create a copy of ConversationEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? eventId = null,Object? sessionId = null,Object? sequence = null,Object? occurredAt = null,}) {
  return _then(_self.copyWith(
eventId: null == eventId ? _self.eventId : eventId // ignore: cast_nullable_to_non_nullable
as EventId,sessionId: null == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as SessionId,sequence: null == sequence ? _self.sequence : sequence // ignore: cast_nullable_to_non_nullable
as int,occurredAt: null == occurredAt ? _self.occurredAt : occurredAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}


/// Adds pattern-matching-related methods to [ConversationEvent].
extension ConversationEventPatterns on ConversationEvent {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( SessionStartedEvent value)?  sessionStarted,TResult Function( SessionEndedEvent value)?  sessionEnded,TResult Function( UserMessageAcceptedEvent value)?  userMessageAccepted,TResult Function( UserMessageRejectedEvent value)?  userMessageRejected,TResult Function( AssistantMessageStartedEvent value)?  assistantMessageStarted,TResult Function( AssistantTextDeltaEvent value)?  assistantTextDelta,TResult Function( AssistantMessageCompletedEvent value)?  assistantMessageCompleted,TResult Function( MessageFailedEvent value)?  messageFailed,TResult Function( MessageCancelledEvent value)?  messageCancelled,TResult Function( ToolCallRequestedEvent value)?  toolCallRequested,TResult Function( ToolExecutionProgressEvent value)?  toolExecutionProgress,TResult Function( ToolResultReceivedEvent value)?  toolResultReceived,TResult Function( UserConfirmationRequestedEvent value)?  userConfirmationRequested,TResult Function( PermissionRequestedEvent value)?  permissionRequested,TResult Function( QuotaUpdatedEvent value)?  quotaUpdated,TResult Function( UnsupportedEvent value)?  unsupported,required TResult orElse(),}){
final _that = this;
switch (_that) {
case SessionStartedEvent() when sessionStarted != null:
return sessionStarted(_that);case SessionEndedEvent() when sessionEnded != null:
return sessionEnded(_that);case UserMessageAcceptedEvent() when userMessageAccepted != null:
return userMessageAccepted(_that);case UserMessageRejectedEvent() when userMessageRejected != null:
return userMessageRejected(_that);case AssistantMessageStartedEvent() when assistantMessageStarted != null:
return assistantMessageStarted(_that);case AssistantTextDeltaEvent() when assistantTextDelta != null:
return assistantTextDelta(_that);case AssistantMessageCompletedEvent() when assistantMessageCompleted != null:
return assistantMessageCompleted(_that);case MessageFailedEvent() when messageFailed != null:
return messageFailed(_that);case MessageCancelledEvent() when messageCancelled != null:
return messageCancelled(_that);case ToolCallRequestedEvent() when toolCallRequested != null:
return toolCallRequested(_that);case ToolExecutionProgressEvent() when toolExecutionProgress != null:
return toolExecutionProgress(_that);case ToolResultReceivedEvent() when toolResultReceived != null:
return toolResultReceived(_that);case UserConfirmationRequestedEvent() when userConfirmationRequested != null:
return userConfirmationRequested(_that);case PermissionRequestedEvent() when permissionRequested != null:
return permissionRequested(_that);case QuotaUpdatedEvent() when quotaUpdated != null:
return quotaUpdated(_that);case UnsupportedEvent() when unsupported != null:
return unsupported(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( SessionStartedEvent value)  sessionStarted,required TResult Function( SessionEndedEvent value)  sessionEnded,required TResult Function( UserMessageAcceptedEvent value)  userMessageAccepted,required TResult Function( UserMessageRejectedEvent value)  userMessageRejected,required TResult Function( AssistantMessageStartedEvent value)  assistantMessageStarted,required TResult Function( AssistantTextDeltaEvent value)  assistantTextDelta,required TResult Function( AssistantMessageCompletedEvent value)  assistantMessageCompleted,required TResult Function( MessageFailedEvent value)  messageFailed,required TResult Function( MessageCancelledEvent value)  messageCancelled,required TResult Function( ToolCallRequestedEvent value)  toolCallRequested,required TResult Function( ToolExecutionProgressEvent value)  toolExecutionProgress,required TResult Function( ToolResultReceivedEvent value)  toolResultReceived,required TResult Function( UserConfirmationRequestedEvent value)  userConfirmationRequested,required TResult Function( PermissionRequestedEvent value)  permissionRequested,required TResult Function( QuotaUpdatedEvent value)  quotaUpdated,required TResult Function( UnsupportedEvent value)  unsupported,}){
final _that = this;
switch (_that) {
case SessionStartedEvent():
return sessionStarted(_that);case SessionEndedEvent():
return sessionEnded(_that);case UserMessageAcceptedEvent():
return userMessageAccepted(_that);case UserMessageRejectedEvent():
return userMessageRejected(_that);case AssistantMessageStartedEvent():
return assistantMessageStarted(_that);case AssistantTextDeltaEvent():
return assistantTextDelta(_that);case AssistantMessageCompletedEvent():
return assistantMessageCompleted(_that);case MessageFailedEvent():
return messageFailed(_that);case MessageCancelledEvent():
return messageCancelled(_that);case ToolCallRequestedEvent():
return toolCallRequested(_that);case ToolExecutionProgressEvent():
return toolExecutionProgress(_that);case ToolResultReceivedEvent():
return toolResultReceived(_that);case UserConfirmationRequestedEvent():
return userConfirmationRequested(_that);case PermissionRequestedEvent():
return permissionRequested(_that);case QuotaUpdatedEvent():
return quotaUpdated(_that);case UnsupportedEvent():
return unsupported(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( SessionStartedEvent value)?  sessionStarted,TResult? Function( SessionEndedEvent value)?  sessionEnded,TResult? Function( UserMessageAcceptedEvent value)?  userMessageAccepted,TResult? Function( UserMessageRejectedEvent value)?  userMessageRejected,TResult? Function( AssistantMessageStartedEvent value)?  assistantMessageStarted,TResult? Function( AssistantTextDeltaEvent value)?  assistantTextDelta,TResult? Function( AssistantMessageCompletedEvent value)?  assistantMessageCompleted,TResult? Function( MessageFailedEvent value)?  messageFailed,TResult? Function( MessageCancelledEvent value)?  messageCancelled,TResult? Function( ToolCallRequestedEvent value)?  toolCallRequested,TResult? Function( ToolExecutionProgressEvent value)?  toolExecutionProgress,TResult? Function( ToolResultReceivedEvent value)?  toolResultReceived,TResult? Function( UserConfirmationRequestedEvent value)?  userConfirmationRequested,TResult? Function( PermissionRequestedEvent value)?  permissionRequested,TResult? Function( QuotaUpdatedEvent value)?  quotaUpdated,TResult? Function( UnsupportedEvent value)?  unsupported,}){
final _that = this;
switch (_that) {
case SessionStartedEvent() when sessionStarted != null:
return sessionStarted(_that);case SessionEndedEvent() when sessionEnded != null:
return sessionEnded(_that);case UserMessageAcceptedEvent() when userMessageAccepted != null:
return userMessageAccepted(_that);case UserMessageRejectedEvent() when userMessageRejected != null:
return userMessageRejected(_that);case AssistantMessageStartedEvent() when assistantMessageStarted != null:
return assistantMessageStarted(_that);case AssistantTextDeltaEvent() when assistantTextDelta != null:
return assistantTextDelta(_that);case AssistantMessageCompletedEvent() when assistantMessageCompleted != null:
return assistantMessageCompleted(_that);case MessageFailedEvent() when messageFailed != null:
return messageFailed(_that);case MessageCancelledEvent() when messageCancelled != null:
return messageCancelled(_that);case ToolCallRequestedEvent() when toolCallRequested != null:
return toolCallRequested(_that);case ToolExecutionProgressEvent() when toolExecutionProgress != null:
return toolExecutionProgress(_that);case ToolResultReceivedEvent() when toolResultReceived != null:
return toolResultReceived(_that);case UserConfirmationRequestedEvent() when userConfirmationRequested != null:
return userConfirmationRequested(_that);case PermissionRequestedEvent() when permissionRequested != null:
return permissionRequested(_that);case QuotaUpdatedEvent() when quotaUpdated != null:
return quotaUpdated(_that);case UnsupportedEvent() when unsupported != null:
return unsupported(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function(@EventIdConverter()  EventId eventId, @SessionIdConverter()  SessionId sessionId,  int sequence,  DateTime occurredAt,  DateTime expiresAt)?  sessionStarted,TResult Function(@EventIdConverter()  EventId eventId, @SessionIdConverter()  SessionId sessionId,  int sequence,  DateTime occurredAt,  SessionEndReason reason)?  sessionEnded,TResult Function(@EventIdConverter()  EventId eventId, @SessionIdConverter()  SessionId sessionId,  int sequence,  DateTime occurredAt, @MessageIdConverter()  MessageId messageId, @ClientMessageIdConverter()  ClientMessageId clientMessageId)?  userMessageAccepted,TResult Function(@EventIdConverter()  EventId eventId, @SessionIdConverter()  SessionId sessionId,  int sequence,  DateTime occurredAt, @ClientMessageIdConverter()  ClientMessageId clientMessageId,  EventError error)?  userMessageRejected,TResult Function(@EventIdConverter()  EventId eventId, @SessionIdConverter()  SessionId sessionId,  int sequence,  DateTime occurredAt, @MessageIdConverter()  MessageId messageId, @MessageIdConverter()  MessageId? inReplyTo)?  assistantMessageStarted,TResult Function(@EventIdConverter()  EventId eventId, @SessionIdConverter()  SessionId sessionId,  int sequence,  DateTime occurredAt, @MessageIdConverter()  MessageId messageId,  int deltaIndex,  String text)?  assistantTextDelta,TResult Function(@EventIdConverter()  EventId eventId, @SessionIdConverter()  SessionId sessionId,  int sequence,  DateTime occurredAt, @MessageIdConverter()  MessageId messageId,  FinishReason finishReason,  String? fullText)?  assistantMessageCompleted,TResult Function(@EventIdConverter()  EventId eventId, @SessionIdConverter()  SessionId sessionId,  int sequence,  DateTime occurredAt, @MessageIdConverter()  MessageId messageId,  EventError error)?  messageFailed,TResult Function(@EventIdConverter()  EventId eventId, @SessionIdConverter()  SessionId sessionId,  int sequence,  DateTime occurredAt, @MessageIdConverter()  MessageId messageId)?  messageCancelled,TResult Function(@EventIdConverter()  EventId eventId, @SessionIdConverter()  SessionId sessionId,  int sequence,  DateTime occurredAt, @MessageIdConverter()  MessageId messageId,  ToolCallRequest toolCall)?  toolCallRequested,TResult Function(@EventIdConverter()  EventId eventId, @SessionIdConverter()  SessionId sessionId,  int sequence,  DateTime occurredAt, @ToolCallIdConverter()  ToolCallId toolCallId,  ToolExecutionStatus status,  double? progress,  String? message)?  toolExecutionProgress,TResult Function(@EventIdConverter()  EventId eventId, @SessionIdConverter()  SessionId sessionId,  int sequence,  DateTime occurredAt, @ToolCallIdConverter()  ToolCallId toolCallId, @MessageIdConverter()  MessageId messageId, @_ValidatedToolResultConverter()  ToolResult result)?  toolResultReceived,TResult Function(@EventIdConverter()  EventId eventId, @SessionIdConverter()  SessionId sessionId,  int sequence,  DateTime occurredAt, @ToolCallIdConverter()  ToolCallId toolCallId,  ConfirmationSpec confirmation)?  userConfirmationRequested,TResult Function(@EventIdConverter()  EventId eventId, @SessionIdConverter()  SessionId sessionId,  int sequence,  DateTime occurredAt,  String requestId,  NexaPermission permission,  String? reason)?  permissionRequested,TResult Function(@EventIdConverter()  EventId eventId, @SessionIdConverter()  SessionId sessionId,  int sequence,  DateTime occurredAt,  QuotaInfo quota,  bool exceeded)?  quotaUpdated,TResult Function(@EventIdConverter()  EventId eventId, @SessionIdConverter()  SessionId sessionId,  int sequence,  DateTime occurredAt,  String originalType,  String? reason)?  unsupported,required TResult orElse(),}) {final _that = this;
switch (_that) {
case SessionStartedEvent() when sessionStarted != null:
return sessionStarted(_that.eventId,_that.sessionId,_that.sequence,_that.occurredAt,_that.expiresAt);case SessionEndedEvent() when sessionEnded != null:
return sessionEnded(_that.eventId,_that.sessionId,_that.sequence,_that.occurredAt,_that.reason);case UserMessageAcceptedEvent() when userMessageAccepted != null:
return userMessageAccepted(_that.eventId,_that.sessionId,_that.sequence,_that.occurredAt,_that.messageId,_that.clientMessageId);case UserMessageRejectedEvent() when userMessageRejected != null:
return userMessageRejected(_that.eventId,_that.sessionId,_that.sequence,_that.occurredAt,_that.clientMessageId,_that.error);case AssistantMessageStartedEvent() when assistantMessageStarted != null:
return assistantMessageStarted(_that.eventId,_that.sessionId,_that.sequence,_that.occurredAt,_that.messageId,_that.inReplyTo);case AssistantTextDeltaEvent() when assistantTextDelta != null:
return assistantTextDelta(_that.eventId,_that.sessionId,_that.sequence,_that.occurredAt,_that.messageId,_that.deltaIndex,_that.text);case AssistantMessageCompletedEvent() when assistantMessageCompleted != null:
return assistantMessageCompleted(_that.eventId,_that.sessionId,_that.sequence,_that.occurredAt,_that.messageId,_that.finishReason,_that.fullText);case MessageFailedEvent() when messageFailed != null:
return messageFailed(_that.eventId,_that.sessionId,_that.sequence,_that.occurredAt,_that.messageId,_that.error);case MessageCancelledEvent() when messageCancelled != null:
return messageCancelled(_that.eventId,_that.sessionId,_that.sequence,_that.occurredAt,_that.messageId);case ToolCallRequestedEvent() when toolCallRequested != null:
return toolCallRequested(_that.eventId,_that.sessionId,_that.sequence,_that.occurredAt,_that.messageId,_that.toolCall);case ToolExecutionProgressEvent() when toolExecutionProgress != null:
return toolExecutionProgress(_that.eventId,_that.sessionId,_that.sequence,_that.occurredAt,_that.toolCallId,_that.status,_that.progress,_that.message);case ToolResultReceivedEvent() when toolResultReceived != null:
return toolResultReceived(_that.eventId,_that.sessionId,_that.sequence,_that.occurredAt,_that.toolCallId,_that.messageId,_that.result);case UserConfirmationRequestedEvent() when userConfirmationRequested != null:
return userConfirmationRequested(_that.eventId,_that.sessionId,_that.sequence,_that.occurredAt,_that.toolCallId,_that.confirmation);case PermissionRequestedEvent() when permissionRequested != null:
return permissionRequested(_that.eventId,_that.sessionId,_that.sequence,_that.occurredAt,_that.requestId,_that.permission,_that.reason);case QuotaUpdatedEvent() when quotaUpdated != null:
return quotaUpdated(_that.eventId,_that.sessionId,_that.sequence,_that.occurredAt,_that.quota,_that.exceeded);case UnsupportedEvent() when unsupported != null:
return unsupported(_that.eventId,_that.sessionId,_that.sequence,_that.occurredAt,_that.originalType,_that.reason);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function(@EventIdConverter()  EventId eventId, @SessionIdConverter()  SessionId sessionId,  int sequence,  DateTime occurredAt,  DateTime expiresAt)  sessionStarted,required TResult Function(@EventIdConverter()  EventId eventId, @SessionIdConverter()  SessionId sessionId,  int sequence,  DateTime occurredAt,  SessionEndReason reason)  sessionEnded,required TResult Function(@EventIdConverter()  EventId eventId, @SessionIdConverter()  SessionId sessionId,  int sequence,  DateTime occurredAt, @MessageIdConverter()  MessageId messageId, @ClientMessageIdConverter()  ClientMessageId clientMessageId)  userMessageAccepted,required TResult Function(@EventIdConverter()  EventId eventId, @SessionIdConverter()  SessionId sessionId,  int sequence,  DateTime occurredAt, @ClientMessageIdConverter()  ClientMessageId clientMessageId,  EventError error)  userMessageRejected,required TResult Function(@EventIdConverter()  EventId eventId, @SessionIdConverter()  SessionId sessionId,  int sequence,  DateTime occurredAt, @MessageIdConverter()  MessageId messageId, @MessageIdConverter()  MessageId? inReplyTo)  assistantMessageStarted,required TResult Function(@EventIdConverter()  EventId eventId, @SessionIdConverter()  SessionId sessionId,  int sequence,  DateTime occurredAt, @MessageIdConverter()  MessageId messageId,  int deltaIndex,  String text)  assistantTextDelta,required TResult Function(@EventIdConverter()  EventId eventId, @SessionIdConverter()  SessionId sessionId,  int sequence,  DateTime occurredAt, @MessageIdConverter()  MessageId messageId,  FinishReason finishReason,  String? fullText)  assistantMessageCompleted,required TResult Function(@EventIdConverter()  EventId eventId, @SessionIdConverter()  SessionId sessionId,  int sequence,  DateTime occurredAt, @MessageIdConverter()  MessageId messageId,  EventError error)  messageFailed,required TResult Function(@EventIdConverter()  EventId eventId, @SessionIdConverter()  SessionId sessionId,  int sequence,  DateTime occurredAt, @MessageIdConverter()  MessageId messageId)  messageCancelled,required TResult Function(@EventIdConverter()  EventId eventId, @SessionIdConverter()  SessionId sessionId,  int sequence,  DateTime occurredAt, @MessageIdConverter()  MessageId messageId,  ToolCallRequest toolCall)  toolCallRequested,required TResult Function(@EventIdConverter()  EventId eventId, @SessionIdConverter()  SessionId sessionId,  int sequence,  DateTime occurredAt, @ToolCallIdConverter()  ToolCallId toolCallId,  ToolExecutionStatus status,  double? progress,  String? message)  toolExecutionProgress,required TResult Function(@EventIdConverter()  EventId eventId, @SessionIdConverter()  SessionId sessionId,  int sequence,  DateTime occurredAt, @ToolCallIdConverter()  ToolCallId toolCallId, @MessageIdConverter()  MessageId messageId, @_ValidatedToolResultConverter()  ToolResult result)  toolResultReceived,required TResult Function(@EventIdConverter()  EventId eventId, @SessionIdConverter()  SessionId sessionId,  int sequence,  DateTime occurredAt, @ToolCallIdConverter()  ToolCallId toolCallId,  ConfirmationSpec confirmation)  userConfirmationRequested,required TResult Function(@EventIdConverter()  EventId eventId, @SessionIdConverter()  SessionId sessionId,  int sequence,  DateTime occurredAt,  String requestId,  NexaPermission permission,  String? reason)  permissionRequested,required TResult Function(@EventIdConverter()  EventId eventId, @SessionIdConverter()  SessionId sessionId,  int sequence,  DateTime occurredAt,  QuotaInfo quota,  bool exceeded)  quotaUpdated,required TResult Function(@EventIdConverter()  EventId eventId, @SessionIdConverter()  SessionId sessionId,  int sequence,  DateTime occurredAt,  String originalType,  String? reason)  unsupported,}) {final _that = this;
switch (_that) {
case SessionStartedEvent():
return sessionStarted(_that.eventId,_that.sessionId,_that.sequence,_that.occurredAt,_that.expiresAt);case SessionEndedEvent():
return sessionEnded(_that.eventId,_that.sessionId,_that.sequence,_that.occurredAt,_that.reason);case UserMessageAcceptedEvent():
return userMessageAccepted(_that.eventId,_that.sessionId,_that.sequence,_that.occurredAt,_that.messageId,_that.clientMessageId);case UserMessageRejectedEvent():
return userMessageRejected(_that.eventId,_that.sessionId,_that.sequence,_that.occurredAt,_that.clientMessageId,_that.error);case AssistantMessageStartedEvent():
return assistantMessageStarted(_that.eventId,_that.sessionId,_that.sequence,_that.occurredAt,_that.messageId,_that.inReplyTo);case AssistantTextDeltaEvent():
return assistantTextDelta(_that.eventId,_that.sessionId,_that.sequence,_that.occurredAt,_that.messageId,_that.deltaIndex,_that.text);case AssistantMessageCompletedEvent():
return assistantMessageCompleted(_that.eventId,_that.sessionId,_that.sequence,_that.occurredAt,_that.messageId,_that.finishReason,_that.fullText);case MessageFailedEvent():
return messageFailed(_that.eventId,_that.sessionId,_that.sequence,_that.occurredAt,_that.messageId,_that.error);case MessageCancelledEvent():
return messageCancelled(_that.eventId,_that.sessionId,_that.sequence,_that.occurredAt,_that.messageId);case ToolCallRequestedEvent():
return toolCallRequested(_that.eventId,_that.sessionId,_that.sequence,_that.occurredAt,_that.messageId,_that.toolCall);case ToolExecutionProgressEvent():
return toolExecutionProgress(_that.eventId,_that.sessionId,_that.sequence,_that.occurredAt,_that.toolCallId,_that.status,_that.progress,_that.message);case ToolResultReceivedEvent():
return toolResultReceived(_that.eventId,_that.sessionId,_that.sequence,_that.occurredAt,_that.toolCallId,_that.messageId,_that.result);case UserConfirmationRequestedEvent():
return userConfirmationRequested(_that.eventId,_that.sessionId,_that.sequence,_that.occurredAt,_that.toolCallId,_that.confirmation);case PermissionRequestedEvent():
return permissionRequested(_that.eventId,_that.sessionId,_that.sequence,_that.occurredAt,_that.requestId,_that.permission,_that.reason);case QuotaUpdatedEvent():
return quotaUpdated(_that.eventId,_that.sessionId,_that.sequence,_that.occurredAt,_that.quota,_that.exceeded);case UnsupportedEvent():
return unsupported(_that.eventId,_that.sessionId,_that.sequence,_that.occurredAt,_that.originalType,_that.reason);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function(@EventIdConverter()  EventId eventId, @SessionIdConverter()  SessionId sessionId,  int sequence,  DateTime occurredAt,  DateTime expiresAt)?  sessionStarted,TResult? Function(@EventIdConverter()  EventId eventId, @SessionIdConverter()  SessionId sessionId,  int sequence,  DateTime occurredAt,  SessionEndReason reason)?  sessionEnded,TResult? Function(@EventIdConverter()  EventId eventId, @SessionIdConverter()  SessionId sessionId,  int sequence,  DateTime occurredAt, @MessageIdConverter()  MessageId messageId, @ClientMessageIdConverter()  ClientMessageId clientMessageId)?  userMessageAccepted,TResult? Function(@EventIdConverter()  EventId eventId, @SessionIdConverter()  SessionId sessionId,  int sequence,  DateTime occurredAt, @ClientMessageIdConverter()  ClientMessageId clientMessageId,  EventError error)?  userMessageRejected,TResult? Function(@EventIdConverter()  EventId eventId, @SessionIdConverter()  SessionId sessionId,  int sequence,  DateTime occurredAt, @MessageIdConverter()  MessageId messageId, @MessageIdConverter()  MessageId? inReplyTo)?  assistantMessageStarted,TResult? Function(@EventIdConverter()  EventId eventId, @SessionIdConverter()  SessionId sessionId,  int sequence,  DateTime occurredAt, @MessageIdConverter()  MessageId messageId,  int deltaIndex,  String text)?  assistantTextDelta,TResult? Function(@EventIdConverter()  EventId eventId, @SessionIdConverter()  SessionId sessionId,  int sequence,  DateTime occurredAt, @MessageIdConverter()  MessageId messageId,  FinishReason finishReason,  String? fullText)?  assistantMessageCompleted,TResult? Function(@EventIdConverter()  EventId eventId, @SessionIdConverter()  SessionId sessionId,  int sequence,  DateTime occurredAt, @MessageIdConverter()  MessageId messageId,  EventError error)?  messageFailed,TResult? Function(@EventIdConverter()  EventId eventId, @SessionIdConverter()  SessionId sessionId,  int sequence,  DateTime occurredAt, @MessageIdConverter()  MessageId messageId)?  messageCancelled,TResult? Function(@EventIdConverter()  EventId eventId, @SessionIdConverter()  SessionId sessionId,  int sequence,  DateTime occurredAt, @MessageIdConverter()  MessageId messageId,  ToolCallRequest toolCall)?  toolCallRequested,TResult? Function(@EventIdConverter()  EventId eventId, @SessionIdConverter()  SessionId sessionId,  int sequence,  DateTime occurredAt, @ToolCallIdConverter()  ToolCallId toolCallId,  ToolExecutionStatus status,  double? progress,  String? message)?  toolExecutionProgress,TResult? Function(@EventIdConverter()  EventId eventId, @SessionIdConverter()  SessionId sessionId,  int sequence,  DateTime occurredAt, @ToolCallIdConverter()  ToolCallId toolCallId, @MessageIdConverter()  MessageId messageId, @_ValidatedToolResultConverter()  ToolResult result)?  toolResultReceived,TResult? Function(@EventIdConverter()  EventId eventId, @SessionIdConverter()  SessionId sessionId,  int sequence,  DateTime occurredAt, @ToolCallIdConverter()  ToolCallId toolCallId,  ConfirmationSpec confirmation)?  userConfirmationRequested,TResult? Function(@EventIdConverter()  EventId eventId, @SessionIdConverter()  SessionId sessionId,  int sequence,  DateTime occurredAt,  String requestId,  NexaPermission permission,  String? reason)?  permissionRequested,TResult? Function(@EventIdConverter()  EventId eventId, @SessionIdConverter()  SessionId sessionId,  int sequence,  DateTime occurredAt,  QuotaInfo quota,  bool exceeded)?  quotaUpdated,TResult? Function(@EventIdConverter()  EventId eventId, @SessionIdConverter()  SessionId sessionId,  int sequence,  DateTime occurredAt,  String originalType,  String? reason)?  unsupported,}) {final _that = this;
switch (_that) {
case SessionStartedEvent() when sessionStarted != null:
return sessionStarted(_that.eventId,_that.sessionId,_that.sequence,_that.occurredAt,_that.expiresAt);case SessionEndedEvent() when sessionEnded != null:
return sessionEnded(_that.eventId,_that.sessionId,_that.sequence,_that.occurredAt,_that.reason);case UserMessageAcceptedEvent() when userMessageAccepted != null:
return userMessageAccepted(_that.eventId,_that.sessionId,_that.sequence,_that.occurredAt,_that.messageId,_that.clientMessageId);case UserMessageRejectedEvent() when userMessageRejected != null:
return userMessageRejected(_that.eventId,_that.sessionId,_that.sequence,_that.occurredAt,_that.clientMessageId,_that.error);case AssistantMessageStartedEvent() when assistantMessageStarted != null:
return assistantMessageStarted(_that.eventId,_that.sessionId,_that.sequence,_that.occurredAt,_that.messageId,_that.inReplyTo);case AssistantTextDeltaEvent() when assistantTextDelta != null:
return assistantTextDelta(_that.eventId,_that.sessionId,_that.sequence,_that.occurredAt,_that.messageId,_that.deltaIndex,_that.text);case AssistantMessageCompletedEvent() when assistantMessageCompleted != null:
return assistantMessageCompleted(_that.eventId,_that.sessionId,_that.sequence,_that.occurredAt,_that.messageId,_that.finishReason,_that.fullText);case MessageFailedEvent() when messageFailed != null:
return messageFailed(_that.eventId,_that.sessionId,_that.sequence,_that.occurredAt,_that.messageId,_that.error);case MessageCancelledEvent() when messageCancelled != null:
return messageCancelled(_that.eventId,_that.sessionId,_that.sequence,_that.occurredAt,_that.messageId);case ToolCallRequestedEvent() when toolCallRequested != null:
return toolCallRequested(_that.eventId,_that.sessionId,_that.sequence,_that.occurredAt,_that.messageId,_that.toolCall);case ToolExecutionProgressEvent() when toolExecutionProgress != null:
return toolExecutionProgress(_that.eventId,_that.sessionId,_that.sequence,_that.occurredAt,_that.toolCallId,_that.status,_that.progress,_that.message);case ToolResultReceivedEvent() when toolResultReceived != null:
return toolResultReceived(_that.eventId,_that.sessionId,_that.sequence,_that.occurredAt,_that.toolCallId,_that.messageId,_that.result);case UserConfirmationRequestedEvent() when userConfirmationRequested != null:
return userConfirmationRequested(_that.eventId,_that.sessionId,_that.sequence,_that.occurredAt,_that.toolCallId,_that.confirmation);case PermissionRequestedEvent() when permissionRequested != null:
return permissionRequested(_that.eventId,_that.sessionId,_that.sequence,_that.occurredAt,_that.requestId,_that.permission,_that.reason);case QuotaUpdatedEvent() when quotaUpdated != null:
return quotaUpdated(_that.eventId,_that.sessionId,_that.sequence,_that.occurredAt,_that.quota,_that.exceeded);case UnsupportedEvent() when unsupported != null:
return unsupported(_that.eventId,_that.sessionId,_that.sequence,_that.occurredAt,_that.originalType,_that.reason);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class SessionStartedEvent extends ConversationEvent {
  const SessionStartedEvent({@EventIdConverter() required this.eventId, @SessionIdConverter() required this.sessionId, required this.sequence, required this.occurredAt, required this.expiresAt, final  String? $type}): $type = $type ?? 'session_started',super._();
  factory SessionStartedEvent.fromJson(Map<String, dynamic> json) => _$SessionStartedEventFromJson(json);

@override@EventIdConverter() final  EventId eventId;
@override@SessionIdConverter() final  SessionId sessionId;
@override final  int sequence;
@override final  DateTime occurredAt;
 final  DateTime expiresAt;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of ConversationEvent
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SessionStartedEventCopyWith<SessionStartedEvent> get copyWith => _$SessionStartedEventCopyWithImpl<SessionStartedEvent>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SessionStartedEventToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SessionStartedEvent&&(identical(other.eventId, eventId) || other.eventId == eventId)&&(identical(other.sessionId, sessionId) || other.sessionId == sessionId)&&(identical(other.sequence, sequence) || other.sequence == sequence)&&(identical(other.occurredAt, occurredAt) || other.occurredAt == occurredAt)&&(identical(other.expiresAt, expiresAt) || other.expiresAt == expiresAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,eventId,sessionId,sequence,occurredAt,expiresAt);

@override
String toString() {
  return 'ConversationEvent.sessionStarted(eventId: $eventId, sessionId: $sessionId, sequence: $sequence, occurredAt: $occurredAt, expiresAt: $expiresAt)';
}


}

/// @nodoc
abstract mixin class $SessionStartedEventCopyWith<$Res> implements $ConversationEventCopyWith<$Res> {
  factory $SessionStartedEventCopyWith(SessionStartedEvent value, $Res Function(SessionStartedEvent) _then) = _$SessionStartedEventCopyWithImpl;
@override @useResult
$Res call({
@EventIdConverter() EventId eventId,@SessionIdConverter() SessionId sessionId, int sequence, DateTime occurredAt, DateTime expiresAt
});




}
/// @nodoc
class _$SessionStartedEventCopyWithImpl<$Res>
    implements $SessionStartedEventCopyWith<$Res> {
  _$SessionStartedEventCopyWithImpl(this._self, this._then);

  final SessionStartedEvent _self;
  final $Res Function(SessionStartedEvent) _then;

/// Create a copy of ConversationEvent
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? eventId = null,Object? sessionId = null,Object? sequence = null,Object? occurredAt = null,Object? expiresAt = null,}) {
  return _then(SessionStartedEvent(
eventId: null == eventId ? _self.eventId : eventId // ignore: cast_nullable_to_non_nullable
as EventId,sessionId: null == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as SessionId,sequence: null == sequence ? _self.sequence : sequence // ignore: cast_nullable_to_non_nullable
as int,occurredAt: null == occurredAt ? _self.occurredAt : occurredAt // ignore: cast_nullable_to_non_nullable
as DateTime,expiresAt: null == expiresAt ? _self.expiresAt : expiresAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}

/// @nodoc
@JsonSerializable()

class SessionEndedEvent extends ConversationEvent {
  const SessionEndedEvent({@EventIdConverter() required this.eventId, @SessionIdConverter() required this.sessionId, required this.sequence, required this.occurredAt, required this.reason, final  String? $type}): $type = $type ?? 'session_ended',super._();
  factory SessionEndedEvent.fromJson(Map<String, dynamic> json) => _$SessionEndedEventFromJson(json);

@override@EventIdConverter() final  EventId eventId;
@override@SessionIdConverter() final  SessionId sessionId;
@override final  int sequence;
@override final  DateTime occurredAt;
 final  SessionEndReason reason;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of ConversationEvent
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SessionEndedEventCopyWith<SessionEndedEvent> get copyWith => _$SessionEndedEventCopyWithImpl<SessionEndedEvent>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SessionEndedEventToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SessionEndedEvent&&(identical(other.eventId, eventId) || other.eventId == eventId)&&(identical(other.sessionId, sessionId) || other.sessionId == sessionId)&&(identical(other.sequence, sequence) || other.sequence == sequence)&&(identical(other.occurredAt, occurredAt) || other.occurredAt == occurredAt)&&(identical(other.reason, reason) || other.reason == reason));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,eventId,sessionId,sequence,occurredAt,reason);

@override
String toString() {
  return 'ConversationEvent.sessionEnded(eventId: $eventId, sessionId: $sessionId, sequence: $sequence, occurredAt: $occurredAt, reason: $reason)';
}


}

/// @nodoc
abstract mixin class $SessionEndedEventCopyWith<$Res> implements $ConversationEventCopyWith<$Res> {
  factory $SessionEndedEventCopyWith(SessionEndedEvent value, $Res Function(SessionEndedEvent) _then) = _$SessionEndedEventCopyWithImpl;
@override @useResult
$Res call({
@EventIdConverter() EventId eventId,@SessionIdConverter() SessionId sessionId, int sequence, DateTime occurredAt, SessionEndReason reason
});




}
/// @nodoc
class _$SessionEndedEventCopyWithImpl<$Res>
    implements $SessionEndedEventCopyWith<$Res> {
  _$SessionEndedEventCopyWithImpl(this._self, this._then);

  final SessionEndedEvent _self;
  final $Res Function(SessionEndedEvent) _then;

/// Create a copy of ConversationEvent
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? eventId = null,Object? sessionId = null,Object? sequence = null,Object? occurredAt = null,Object? reason = null,}) {
  return _then(SessionEndedEvent(
eventId: null == eventId ? _self.eventId : eventId // ignore: cast_nullable_to_non_nullable
as EventId,sessionId: null == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as SessionId,sequence: null == sequence ? _self.sequence : sequence // ignore: cast_nullable_to_non_nullable
as int,occurredAt: null == occurredAt ? _self.occurredAt : occurredAt // ignore: cast_nullable_to_non_nullable
as DateTime,reason: null == reason ? _self.reason : reason // ignore: cast_nullable_to_non_nullable
as SessionEndReason,
  ));
}


}

/// @nodoc
@JsonSerializable()

class UserMessageAcceptedEvent extends ConversationEvent {
  const UserMessageAcceptedEvent({@EventIdConverter() required this.eventId, @SessionIdConverter() required this.sessionId, required this.sequence, required this.occurredAt, @MessageIdConverter() required this.messageId, @ClientMessageIdConverter() required this.clientMessageId, final  String? $type}): $type = $type ?? 'user_message_accepted',super._();
  factory UserMessageAcceptedEvent.fromJson(Map<String, dynamic> json) => _$UserMessageAcceptedEventFromJson(json);

@override@EventIdConverter() final  EventId eventId;
@override@SessionIdConverter() final  SessionId sessionId;
@override final  int sequence;
@override final  DateTime occurredAt;
@MessageIdConverter() final  MessageId messageId;
@ClientMessageIdConverter() final  ClientMessageId clientMessageId;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of ConversationEvent
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UserMessageAcceptedEventCopyWith<UserMessageAcceptedEvent> get copyWith => _$UserMessageAcceptedEventCopyWithImpl<UserMessageAcceptedEvent>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$UserMessageAcceptedEventToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UserMessageAcceptedEvent&&(identical(other.eventId, eventId) || other.eventId == eventId)&&(identical(other.sessionId, sessionId) || other.sessionId == sessionId)&&(identical(other.sequence, sequence) || other.sequence == sequence)&&(identical(other.occurredAt, occurredAt) || other.occurredAt == occurredAt)&&(identical(other.messageId, messageId) || other.messageId == messageId)&&(identical(other.clientMessageId, clientMessageId) || other.clientMessageId == clientMessageId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,eventId,sessionId,sequence,occurredAt,messageId,clientMessageId);

@override
String toString() {
  return 'ConversationEvent.userMessageAccepted(eventId: $eventId, sessionId: $sessionId, sequence: $sequence, occurredAt: $occurredAt, messageId: $messageId, clientMessageId: $clientMessageId)';
}


}

/// @nodoc
abstract mixin class $UserMessageAcceptedEventCopyWith<$Res> implements $ConversationEventCopyWith<$Res> {
  factory $UserMessageAcceptedEventCopyWith(UserMessageAcceptedEvent value, $Res Function(UserMessageAcceptedEvent) _then) = _$UserMessageAcceptedEventCopyWithImpl;
@override @useResult
$Res call({
@EventIdConverter() EventId eventId,@SessionIdConverter() SessionId sessionId, int sequence, DateTime occurredAt,@MessageIdConverter() MessageId messageId,@ClientMessageIdConverter() ClientMessageId clientMessageId
});




}
/// @nodoc
class _$UserMessageAcceptedEventCopyWithImpl<$Res>
    implements $UserMessageAcceptedEventCopyWith<$Res> {
  _$UserMessageAcceptedEventCopyWithImpl(this._self, this._then);

  final UserMessageAcceptedEvent _self;
  final $Res Function(UserMessageAcceptedEvent) _then;

/// Create a copy of ConversationEvent
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? eventId = null,Object? sessionId = null,Object? sequence = null,Object? occurredAt = null,Object? messageId = null,Object? clientMessageId = null,}) {
  return _then(UserMessageAcceptedEvent(
eventId: null == eventId ? _self.eventId : eventId // ignore: cast_nullable_to_non_nullable
as EventId,sessionId: null == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as SessionId,sequence: null == sequence ? _self.sequence : sequence // ignore: cast_nullable_to_non_nullable
as int,occurredAt: null == occurredAt ? _self.occurredAt : occurredAt // ignore: cast_nullable_to_non_nullable
as DateTime,messageId: null == messageId ? _self.messageId : messageId // ignore: cast_nullable_to_non_nullable
as MessageId,clientMessageId: null == clientMessageId ? _self.clientMessageId : clientMessageId // ignore: cast_nullable_to_non_nullable
as ClientMessageId,
  ));
}


}

/// @nodoc
@JsonSerializable()

class UserMessageRejectedEvent extends ConversationEvent {
  const UserMessageRejectedEvent({@EventIdConverter() required this.eventId, @SessionIdConverter() required this.sessionId, required this.sequence, required this.occurredAt, @ClientMessageIdConverter() required this.clientMessageId, required this.error, final  String? $type}): $type = $type ?? 'user_message_rejected',super._();
  factory UserMessageRejectedEvent.fromJson(Map<String, dynamic> json) => _$UserMessageRejectedEventFromJson(json);

@override@EventIdConverter() final  EventId eventId;
@override@SessionIdConverter() final  SessionId sessionId;
@override final  int sequence;
@override final  DateTime occurredAt;
@ClientMessageIdConverter() final  ClientMessageId clientMessageId;
 final  EventError error;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of ConversationEvent
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UserMessageRejectedEventCopyWith<UserMessageRejectedEvent> get copyWith => _$UserMessageRejectedEventCopyWithImpl<UserMessageRejectedEvent>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$UserMessageRejectedEventToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UserMessageRejectedEvent&&(identical(other.eventId, eventId) || other.eventId == eventId)&&(identical(other.sessionId, sessionId) || other.sessionId == sessionId)&&(identical(other.sequence, sequence) || other.sequence == sequence)&&(identical(other.occurredAt, occurredAt) || other.occurredAt == occurredAt)&&(identical(other.clientMessageId, clientMessageId) || other.clientMessageId == clientMessageId)&&(identical(other.error, error) || other.error == error));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,eventId,sessionId,sequence,occurredAt,clientMessageId,error);

@override
String toString() {
  return 'ConversationEvent.userMessageRejected(eventId: $eventId, sessionId: $sessionId, sequence: $sequence, occurredAt: $occurredAt, clientMessageId: $clientMessageId, error: $error)';
}


}

/// @nodoc
abstract mixin class $UserMessageRejectedEventCopyWith<$Res> implements $ConversationEventCopyWith<$Res> {
  factory $UserMessageRejectedEventCopyWith(UserMessageRejectedEvent value, $Res Function(UserMessageRejectedEvent) _then) = _$UserMessageRejectedEventCopyWithImpl;
@override @useResult
$Res call({
@EventIdConverter() EventId eventId,@SessionIdConverter() SessionId sessionId, int sequence, DateTime occurredAt,@ClientMessageIdConverter() ClientMessageId clientMessageId, EventError error
});


$EventErrorCopyWith<$Res> get error;

}
/// @nodoc
class _$UserMessageRejectedEventCopyWithImpl<$Res>
    implements $UserMessageRejectedEventCopyWith<$Res> {
  _$UserMessageRejectedEventCopyWithImpl(this._self, this._then);

  final UserMessageRejectedEvent _self;
  final $Res Function(UserMessageRejectedEvent) _then;

/// Create a copy of ConversationEvent
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? eventId = null,Object? sessionId = null,Object? sequence = null,Object? occurredAt = null,Object? clientMessageId = null,Object? error = null,}) {
  return _then(UserMessageRejectedEvent(
eventId: null == eventId ? _self.eventId : eventId // ignore: cast_nullable_to_non_nullable
as EventId,sessionId: null == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as SessionId,sequence: null == sequence ? _self.sequence : sequence // ignore: cast_nullable_to_non_nullable
as int,occurredAt: null == occurredAt ? _self.occurredAt : occurredAt // ignore: cast_nullable_to_non_nullable
as DateTime,clientMessageId: null == clientMessageId ? _self.clientMessageId : clientMessageId // ignore: cast_nullable_to_non_nullable
as ClientMessageId,error: null == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as EventError,
  ));
}

/// Create a copy of ConversationEvent
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$EventErrorCopyWith<$Res> get error {
  
  return $EventErrorCopyWith<$Res>(_self.error, (value) {
    return _then(_self.copyWith(error: value));
  });
}
}

/// @nodoc
@JsonSerializable()

class AssistantMessageStartedEvent extends ConversationEvent {
  const AssistantMessageStartedEvent({@EventIdConverter() required this.eventId, @SessionIdConverter() required this.sessionId, required this.sequence, required this.occurredAt, @MessageIdConverter() required this.messageId, @MessageIdConverter() this.inReplyTo, final  String? $type}): $type = $type ?? 'assistant_message_started',super._();
  factory AssistantMessageStartedEvent.fromJson(Map<String, dynamic> json) => _$AssistantMessageStartedEventFromJson(json);

@override@EventIdConverter() final  EventId eventId;
@override@SessionIdConverter() final  SessionId sessionId;
@override final  int sequence;
@override final  DateTime occurredAt;
@MessageIdConverter() final  MessageId messageId;
@MessageIdConverter() final  MessageId? inReplyTo;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of ConversationEvent
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AssistantMessageStartedEventCopyWith<AssistantMessageStartedEvent> get copyWith => _$AssistantMessageStartedEventCopyWithImpl<AssistantMessageStartedEvent>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AssistantMessageStartedEventToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AssistantMessageStartedEvent&&(identical(other.eventId, eventId) || other.eventId == eventId)&&(identical(other.sessionId, sessionId) || other.sessionId == sessionId)&&(identical(other.sequence, sequence) || other.sequence == sequence)&&(identical(other.occurredAt, occurredAt) || other.occurredAt == occurredAt)&&(identical(other.messageId, messageId) || other.messageId == messageId)&&(identical(other.inReplyTo, inReplyTo) || other.inReplyTo == inReplyTo));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,eventId,sessionId,sequence,occurredAt,messageId,inReplyTo);

@override
String toString() {
  return 'ConversationEvent.assistantMessageStarted(eventId: $eventId, sessionId: $sessionId, sequence: $sequence, occurredAt: $occurredAt, messageId: $messageId, inReplyTo: $inReplyTo)';
}


}

/// @nodoc
abstract mixin class $AssistantMessageStartedEventCopyWith<$Res> implements $ConversationEventCopyWith<$Res> {
  factory $AssistantMessageStartedEventCopyWith(AssistantMessageStartedEvent value, $Res Function(AssistantMessageStartedEvent) _then) = _$AssistantMessageStartedEventCopyWithImpl;
@override @useResult
$Res call({
@EventIdConverter() EventId eventId,@SessionIdConverter() SessionId sessionId, int sequence, DateTime occurredAt,@MessageIdConverter() MessageId messageId,@MessageIdConverter() MessageId? inReplyTo
});




}
/// @nodoc
class _$AssistantMessageStartedEventCopyWithImpl<$Res>
    implements $AssistantMessageStartedEventCopyWith<$Res> {
  _$AssistantMessageStartedEventCopyWithImpl(this._self, this._then);

  final AssistantMessageStartedEvent _self;
  final $Res Function(AssistantMessageStartedEvent) _then;

/// Create a copy of ConversationEvent
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? eventId = null,Object? sessionId = null,Object? sequence = null,Object? occurredAt = null,Object? messageId = null,Object? inReplyTo = freezed,}) {
  return _then(AssistantMessageStartedEvent(
eventId: null == eventId ? _self.eventId : eventId // ignore: cast_nullable_to_non_nullable
as EventId,sessionId: null == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as SessionId,sequence: null == sequence ? _self.sequence : sequence // ignore: cast_nullable_to_non_nullable
as int,occurredAt: null == occurredAt ? _self.occurredAt : occurredAt // ignore: cast_nullable_to_non_nullable
as DateTime,messageId: null == messageId ? _self.messageId : messageId // ignore: cast_nullable_to_non_nullable
as MessageId,inReplyTo: freezed == inReplyTo ? _self.inReplyTo : inReplyTo // ignore: cast_nullable_to_non_nullable
as MessageId?,
  ));
}


}

/// @nodoc
@JsonSerializable()

class AssistantTextDeltaEvent extends ConversationEvent {
  const AssistantTextDeltaEvent({@EventIdConverter() required this.eventId, @SessionIdConverter() required this.sessionId, required this.sequence, required this.occurredAt, @MessageIdConverter() required this.messageId, required this.deltaIndex, required this.text, final  String? $type}): $type = $type ?? 'assistant_text_delta',super._();
  factory AssistantTextDeltaEvent.fromJson(Map<String, dynamic> json) => _$AssistantTextDeltaEventFromJson(json);

@override@EventIdConverter() final  EventId eventId;
@override@SessionIdConverter() final  SessionId sessionId;
@override final  int sequence;
@override final  DateTime occurredAt;
@MessageIdConverter() final  MessageId messageId;
 final  int deltaIndex;
 final  String text;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of ConversationEvent
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AssistantTextDeltaEventCopyWith<AssistantTextDeltaEvent> get copyWith => _$AssistantTextDeltaEventCopyWithImpl<AssistantTextDeltaEvent>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AssistantTextDeltaEventToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AssistantTextDeltaEvent&&(identical(other.eventId, eventId) || other.eventId == eventId)&&(identical(other.sessionId, sessionId) || other.sessionId == sessionId)&&(identical(other.sequence, sequence) || other.sequence == sequence)&&(identical(other.occurredAt, occurredAt) || other.occurredAt == occurredAt)&&(identical(other.messageId, messageId) || other.messageId == messageId)&&(identical(other.deltaIndex, deltaIndex) || other.deltaIndex == deltaIndex)&&(identical(other.text, text) || other.text == text));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,eventId,sessionId,sequence,occurredAt,messageId,deltaIndex,text);

@override
String toString() {
  return 'ConversationEvent.assistantTextDelta(eventId: $eventId, sessionId: $sessionId, sequence: $sequence, occurredAt: $occurredAt, messageId: $messageId, deltaIndex: $deltaIndex, text: $text)';
}


}

/// @nodoc
abstract mixin class $AssistantTextDeltaEventCopyWith<$Res> implements $ConversationEventCopyWith<$Res> {
  factory $AssistantTextDeltaEventCopyWith(AssistantTextDeltaEvent value, $Res Function(AssistantTextDeltaEvent) _then) = _$AssistantTextDeltaEventCopyWithImpl;
@override @useResult
$Res call({
@EventIdConverter() EventId eventId,@SessionIdConverter() SessionId sessionId, int sequence, DateTime occurredAt,@MessageIdConverter() MessageId messageId, int deltaIndex, String text
});




}
/// @nodoc
class _$AssistantTextDeltaEventCopyWithImpl<$Res>
    implements $AssistantTextDeltaEventCopyWith<$Res> {
  _$AssistantTextDeltaEventCopyWithImpl(this._self, this._then);

  final AssistantTextDeltaEvent _self;
  final $Res Function(AssistantTextDeltaEvent) _then;

/// Create a copy of ConversationEvent
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? eventId = null,Object? sessionId = null,Object? sequence = null,Object? occurredAt = null,Object? messageId = null,Object? deltaIndex = null,Object? text = null,}) {
  return _then(AssistantTextDeltaEvent(
eventId: null == eventId ? _self.eventId : eventId // ignore: cast_nullable_to_non_nullable
as EventId,sessionId: null == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as SessionId,sequence: null == sequence ? _self.sequence : sequence // ignore: cast_nullable_to_non_nullable
as int,occurredAt: null == occurredAt ? _self.occurredAt : occurredAt // ignore: cast_nullable_to_non_nullable
as DateTime,messageId: null == messageId ? _self.messageId : messageId // ignore: cast_nullable_to_non_nullable
as MessageId,deltaIndex: null == deltaIndex ? _self.deltaIndex : deltaIndex // ignore: cast_nullable_to_non_nullable
as int,text: null == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
@JsonSerializable()

class AssistantMessageCompletedEvent extends ConversationEvent {
  const AssistantMessageCompletedEvent({@EventIdConverter() required this.eventId, @SessionIdConverter() required this.sessionId, required this.sequence, required this.occurredAt, @MessageIdConverter() required this.messageId, required this.finishReason, this.fullText, final  String? $type}): $type = $type ?? 'assistant_message_completed',super._();
  factory AssistantMessageCompletedEvent.fromJson(Map<String, dynamic> json) => _$AssistantMessageCompletedEventFromJson(json);

@override@EventIdConverter() final  EventId eventId;
@override@SessionIdConverter() final  SessionId sessionId;
@override final  int sequence;
@override final  DateTime occurredAt;
@MessageIdConverter() final  MessageId messageId;
 final  FinishReason finishReason;
 final  String? fullText;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of ConversationEvent
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AssistantMessageCompletedEventCopyWith<AssistantMessageCompletedEvent> get copyWith => _$AssistantMessageCompletedEventCopyWithImpl<AssistantMessageCompletedEvent>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AssistantMessageCompletedEventToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AssistantMessageCompletedEvent&&(identical(other.eventId, eventId) || other.eventId == eventId)&&(identical(other.sessionId, sessionId) || other.sessionId == sessionId)&&(identical(other.sequence, sequence) || other.sequence == sequence)&&(identical(other.occurredAt, occurredAt) || other.occurredAt == occurredAt)&&(identical(other.messageId, messageId) || other.messageId == messageId)&&(identical(other.finishReason, finishReason) || other.finishReason == finishReason)&&(identical(other.fullText, fullText) || other.fullText == fullText));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,eventId,sessionId,sequence,occurredAt,messageId,finishReason,fullText);

@override
String toString() {
  return 'ConversationEvent.assistantMessageCompleted(eventId: $eventId, sessionId: $sessionId, sequence: $sequence, occurredAt: $occurredAt, messageId: $messageId, finishReason: $finishReason, fullText: $fullText)';
}


}

/// @nodoc
abstract mixin class $AssistantMessageCompletedEventCopyWith<$Res> implements $ConversationEventCopyWith<$Res> {
  factory $AssistantMessageCompletedEventCopyWith(AssistantMessageCompletedEvent value, $Res Function(AssistantMessageCompletedEvent) _then) = _$AssistantMessageCompletedEventCopyWithImpl;
@override @useResult
$Res call({
@EventIdConverter() EventId eventId,@SessionIdConverter() SessionId sessionId, int sequence, DateTime occurredAt,@MessageIdConverter() MessageId messageId, FinishReason finishReason, String? fullText
});




}
/// @nodoc
class _$AssistantMessageCompletedEventCopyWithImpl<$Res>
    implements $AssistantMessageCompletedEventCopyWith<$Res> {
  _$AssistantMessageCompletedEventCopyWithImpl(this._self, this._then);

  final AssistantMessageCompletedEvent _self;
  final $Res Function(AssistantMessageCompletedEvent) _then;

/// Create a copy of ConversationEvent
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? eventId = null,Object? sessionId = null,Object? sequence = null,Object? occurredAt = null,Object? messageId = null,Object? finishReason = null,Object? fullText = freezed,}) {
  return _then(AssistantMessageCompletedEvent(
eventId: null == eventId ? _self.eventId : eventId // ignore: cast_nullable_to_non_nullable
as EventId,sessionId: null == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as SessionId,sequence: null == sequence ? _self.sequence : sequence // ignore: cast_nullable_to_non_nullable
as int,occurredAt: null == occurredAt ? _self.occurredAt : occurredAt // ignore: cast_nullable_to_non_nullable
as DateTime,messageId: null == messageId ? _self.messageId : messageId // ignore: cast_nullable_to_non_nullable
as MessageId,finishReason: null == finishReason ? _self.finishReason : finishReason // ignore: cast_nullable_to_non_nullable
as FinishReason,fullText: freezed == fullText ? _self.fullText : fullText // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc
@JsonSerializable()

class MessageFailedEvent extends ConversationEvent {
  const MessageFailedEvent({@EventIdConverter() required this.eventId, @SessionIdConverter() required this.sessionId, required this.sequence, required this.occurredAt, @MessageIdConverter() required this.messageId, required this.error, final  String? $type}): $type = $type ?? 'message_failed',super._();
  factory MessageFailedEvent.fromJson(Map<String, dynamic> json) => _$MessageFailedEventFromJson(json);

@override@EventIdConverter() final  EventId eventId;
@override@SessionIdConverter() final  SessionId sessionId;
@override final  int sequence;
@override final  DateTime occurredAt;
@MessageIdConverter() final  MessageId messageId;
 final  EventError error;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of ConversationEvent
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MessageFailedEventCopyWith<MessageFailedEvent> get copyWith => _$MessageFailedEventCopyWithImpl<MessageFailedEvent>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MessageFailedEventToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MessageFailedEvent&&(identical(other.eventId, eventId) || other.eventId == eventId)&&(identical(other.sessionId, sessionId) || other.sessionId == sessionId)&&(identical(other.sequence, sequence) || other.sequence == sequence)&&(identical(other.occurredAt, occurredAt) || other.occurredAt == occurredAt)&&(identical(other.messageId, messageId) || other.messageId == messageId)&&(identical(other.error, error) || other.error == error));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,eventId,sessionId,sequence,occurredAt,messageId,error);

@override
String toString() {
  return 'ConversationEvent.messageFailed(eventId: $eventId, sessionId: $sessionId, sequence: $sequence, occurredAt: $occurredAt, messageId: $messageId, error: $error)';
}


}

/// @nodoc
abstract mixin class $MessageFailedEventCopyWith<$Res> implements $ConversationEventCopyWith<$Res> {
  factory $MessageFailedEventCopyWith(MessageFailedEvent value, $Res Function(MessageFailedEvent) _then) = _$MessageFailedEventCopyWithImpl;
@override @useResult
$Res call({
@EventIdConverter() EventId eventId,@SessionIdConverter() SessionId sessionId, int sequence, DateTime occurredAt,@MessageIdConverter() MessageId messageId, EventError error
});


$EventErrorCopyWith<$Res> get error;

}
/// @nodoc
class _$MessageFailedEventCopyWithImpl<$Res>
    implements $MessageFailedEventCopyWith<$Res> {
  _$MessageFailedEventCopyWithImpl(this._self, this._then);

  final MessageFailedEvent _self;
  final $Res Function(MessageFailedEvent) _then;

/// Create a copy of ConversationEvent
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? eventId = null,Object? sessionId = null,Object? sequence = null,Object? occurredAt = null,Object? messageId = null,Object? error = null,}) {
  return _then(MessageFailedEvent(
eventId: null == eventId ? _self.eventId : eventId // ignore: cast_nullable_to_non_nullable
as EventId,sessionId: null == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as SessionId,sequence: null == sequence ? _self.sequence : sequence // ignore: cast_nullable_to_non_nullable
as int,occurredAt: null == occurredAt ? _self.occurredAt : occurredAt // ignore: cast_nullable_to_non_nullable
as DateTime,messageId: null == messageId ? _self.messageId : messageId // ignore: cast_nullable_to_non_nullable
as MessageId,error: null == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as EventError,
  ));
}

/// Create a copy of ConversationEvent
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$EventErrorCopyWith<$Res> get error {
  
  return $EventErrorCopyWith<$Res>(_self.error, (value) {
    return _then(_self.copyWith(error: value));
  });
}
}

/// @nodoc
@JsonSerializable()

class MessageCancelledEvent extends ConversationEvent {
  const MessageCancelledEvent({@EventIdConverter() required this.eventId, @SessionIdConverter() required this.sessionId, required this.sequence, required this.occurredAt, @MessageIdConverter() required this.messageId, final  String? $type}): $type = $type ?? 'message_cancelled',super._();
  factory MessageCancelledEvent.fromJson(Map<String, dynamic> json) => _$MessageCancelledEventFromJson(json);

@override@EventIdConverter() final  EventId eventId;
@override@SessionIdConverter() final  SessionId sessionId;
@override final  int sequence;
@override final  DateTime occurredAt;
@MessageIdConverter() final  MessageId messageId;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of ConversationEvent
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MessageCancelledEventCopyWith<MessageCancelledEvent> get copyWith => _$MessageCancelledEventCopyWithImpl<MessageCancelledEvent>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MessageCancelledEventToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MessageCancelledEvent&&(identical(other.eventId, eventId) || other.eventId == eventId)&&(identical(other.sessionId, sessionId) || other.sessionId == sessionId)&&(identical(other.sequence, sequence) || other.sequence == sequence)&&(identical(other.occurredAt, occurredAt) || other.occurredAt == occurredAt)&&(identical(other.messageId, messageId) || other.messageId == messageId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,eventId,sessionId,sequence,occurredAt,messageId);

@override
String toString() {
  return 'ConversationEvent.messageCancelled(eventId: $eventId, sessionId: $sessionId, sequence: $sequence, occurredAt: $occurredAt, messageId: $messageId)';
}


}

/// @nodoc
abstract mixin class $MessageCancelledEventCopyWith<$Res> implements $ConversationEventCopyWith<$Res> {
  factory $MessageCancelledEventCopyWith(MessageCancelledEvent value, $Res Function(MessageCancelledEvent) _then) = _$MessageCancelledEventCopyWithImpl;
@override @useResult
$Res call({
@EventIdConverter() EventId eventId,@SessionIdConverter() SessionId sessionId, int sequence, DateTime occurredAt,@MessageIdConverter() MessageId messageId
});




}
/// @nodoc
class _$MessageCancelledEventCopyWithImpl<$Res>
    implements $MessageCancelledEventCopyWith<$Res> {
  _$MessageCancelledEventCopyWithImpl(this._self, this._then);

  final MessageCancelledEvent _self;
  final $Res Function(MessageCancelledEvent) _then;

/// Create a copy of ConversationEvent
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? eventId = null,Object? sessionId = null,Object? sequence = null,Object? occurredAt = null,Object? messageId = null,}) {
  return _then(MessageCancelledEvent(
eventId: null == eventId ? _self.eventId : eventId // ignore: cast_nullable_to_non_nullable
as EventId,sessionId: null == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as SessionId,sequence: null == sequence ? _self.sequence : sequence // ignore: cast_nullable_to_non_nullable
as int,occurredAt: null == occurredAt ? _self.occurredAt : occurredAt // ignore: cast_nullable_to_non_nullable
as DateTime,messageId: null == messageId ? _self.messageId : messageId // ignore: cast_nullable_to_non_nullable
as MessageId,
  ));
}


}

/// @nodoc
@JsonSerializable()

class ToolCallRequestedEvent extends ConversationEvent {
  const ToolCallRequestedEvent({@EventIdConverter() required this.eventId, @SessionIdConverter() required this.sessionId, required this.sequence, required this.occurredAt, @MessageIdConverter() required this.messageId, required this.toolCall, final  String? $type}): $type = $type ?? 'tool_call_requested',super._();
  factory ToolCallRequestedEvent.fromJson(Map<String, dynamic> json) => _$ToolCallRequestedEventFromJson(json);

@override@EventIdConverter() final  EventId eventId;
@override@SessionIdConverter() final  SessionId sessionId;
@override final  int sequence;
@override final  DateTime occurredAt;
@MessageIdConverter() final  MessageId messageId;
 final  ToolCallRequest toolCall;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of ConversationEvent
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ToolCallRequestedEventCopyWith<ToolCallRequestedEvent> get copyWith => _$ToolCallRequestedEventCopyWithImpl<ToolCallRequestedEvent>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ToolCallRequestedEventToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ToolCallRequestedEvent&&(identical(other.eventId, eventId) || other.eventId == eventId)&&(identical(other.sessionId, sessionId) || other.sessionId == sessionId)&&(identical(other.sequence, sequence) || other.sequence == sequence)&&(identical(other.occurredAt, occurredAt) || other.occurredAt == occurredAt)&&(identical(other.messageId, messageId) || other.messageId == messageId)&&(identical(other.toolCall, toolCall) || other.toolCall == toolCall));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,eventId,sessionId,sequence,occurredAt,messageId,toolCall);

@override
String toString() {
  return 'ConversationEvent.toolCallRequested(eventId: $eventId, sessionId: $sessionId, sequence: $sequence, occurredAt: $occurredAt, messageId: $messageId, toolCall: $toolCall)';
}


}

/// @nodoc
abstract mixin class $ToolCallRequestedEventCopyWith<$Res> implements $ConversationEventCopyWith<$Res> {
  factory $ToolCallRequestedEventCopyWith(ToolCallRequestedEvent value, $Res Function(ToolCallRequestedEvent) _then) = _$ToolCallRequestedEventCopyWithImpl;
@override @useResult
$Res call({
@EventIdConverter() EventId eventId,@SessionIdConverter() SessionId sessionId, int sequence, DateTime occurredAt,@MessageIdConverter() MessageId messageId, ToolCallRequest toolCall
});


$ToolCallRequestCopyWith<$Res> get toolCall;

}
/// @nodoc
class _$ToolCallRequestedEventCopyWithImpl<$Res>
    implements $ToolCallRequestedEventCopyWith<$Res> {
  _$ToolCallRequestedEventCopyWithImpl(this._self, this._then);

  final ToolCallRequestedEvent _self;
  final $Res Function(ToolCallRequestedEvent) _then;

/// Create a copy of ConversationEvent
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? eventId = null,Object? sessionId = null,Object? sequence = null,Object? occurredAt = null,Object? messageId = null,Object? toolCall = null,}) {
  return _then(ToolCallRequestedEvent(
eventId: null == eventId ? _self.eventId : eventId // ignore: cast_nullable_to_non_nullable
as EventId,sessionId: null == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as SessionId,sequence: null == sequence ? _self.sequence : sequence // ignore: cast_nullable_to_non_nullable
as int,occurredAt: null == occurredAt ? _self.occurredAt : occurredAt // ignore: cast_nullable_to_non_nullable
as DateTime,messageId: null == messageId ? _self.messageId : messageId // ignore: cast_nullable_to_non_nullable
as MessageId,toolCall: null == toolCall ? _self.toolCall : toolCall // ignore: cast_nullable_to_non_nullable
as ToolCallRequest,
  ));
}

/// Create a copy of ConversationEvent
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ToolCallRequestCopyWith<$Res> get toolCall {
  
  return $ToolCallRequestCopyWith<$Res>(_self.toolCall, (value) {
    return _then(_self.copyWith(toolCall: value));
  });
}
}

/// @nodoc
@JsonSerializable()

class ToolExecutionProgressEvent extends ConversationEvent {
  const ToolExecutionProgressEvent({@EventIdConverter() required this.eventId, @SessionIdConverter() required this.sessionId, required this.sequence, required this.occurredAt, @ToolCallIdConverter() required this.toolCallId, required this.status, this.progress, this.message, final  String? $type}): $type = $type ?? 'tool_execution_progress',super._();
  factory ToolExecutionProgressEvent.fromJson(Map<String, dynamic> json) => _$ToolExecutionProgressEventFromJson(json);

@override@EventIdConverter() final  EventId eventId;
@override@SessionIdConverter() final  SessionId sessionId;
@override final  int sequence;
@override final  DateTime occurredAt;
@ToolCallIdConverter() final  ToolCallId toolCallId;
 final  ToolExecutionStatus status;
/// 0..1 when known.
 final  double? progress;
 final  String? message;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of ConversationEvent
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ToolExecutionProgressEventCopyWith<ToolExecutionProgressEvent> get copyWith => _$ToolExecutionProgressEventCopyWithImpl<ToolExecutionProgressEvent>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ToolExecutionProgressEventToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ToolExecutionProgressEvent&&(identical(other.eventId, eventId) || other.eventId == eventId)&&(identical(other.sessionId, sessionId) || other.sessionId == sessionId)&&(identical(other.sequence, sequence) || other.sequence == sequence)&&(identical(other.occurredAt, occurredAt) || other.occurredAt == occurredAt)&&(identical(other.toolCallId, toolCallId) || other.toolCallId == toolCallId)&&(identical(other.status, status) || other.status == status)&&(identical(other.progress, progress) || other.progress == progress)&&(identical(other.message, message) || other.message == message));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,eventId,sessionId,sequence,occurredAt,toolCallId,status,progress,message);

@override
String toString() {
  return 'ConversationEvent.toolExecutionProgress(eventId: $eventId, sessionId: $sessionId, sequence: $sequence, occurredAt: $occurredAt, toolCallId: $toolCallId, status: $status, progress: $progress, message: $message)';
}


}

/// @nodoc
abstract mixin class $ToolExecutionProgressEventCopyWith<$Res> implements $ConversationEventCopyWith<$Res> {
  factory $ToolExecutionProgressEventCopyWith(ToolExecutionProgressEvent value, $Res Function(ToolExecutionProgressEvent) _then) = _$ToolExecutionProgressEventCopyWithImpl;
@override @useResult
$Res call({
@EventIdConverter() EventId eventId,@SessionIdConverter() SessionId sessionId, int sequence, DateTime occurredAt,@ToolCallIdConverter() ToolCallId toolCallId, ToolExecutionStatus status, double? progress, String? message
});




}
/// @nodoc
class _$ToolExecutionProgressEventCopyWithImpl<$Res>
    implements $ToolExecutionProgressEventCopyWith<$Res> {
  _$ToolExecutionProgressEventCopyWithImpl(this._self, this._then);

  final ToolExecutionProgressEvent _self;
  final $Res Function(ToolExecutionProgressEvent) _then;

/// Create a copy of ConversationEvent
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? eventId = null,Object? sessionId = null,Object? sequence = null,Object? occurredAt = null,Object? toolCallId = null,Object? status = null,Object? progress = freezed,Object? message = freezed,}) {
  return _then(ToolExecutionProgressEvent(
eventId: null == eventId ? _self.eventId : eventId // ignore: cast_nullable_to_non_nullable
as EventId,sessionId: null == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as SessionId,sequence: null == sequence ? _self.sequence : sequence // ignore: cast_nullable_to_non_nullable
as int,occurredAt: null == occurredAt ? _self.occurredAt : occurredAt // ignore: cast_nullable_to_non_nullable
as DateTime,toolCallId: null == toolCallId ? _self.toolCallId : toolCallId // ignore: cast_nullable_to_non_nullable
as ToolCallId,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as ToolExecutionStatus,progress: freezed == progress ? _self.progress : progress // ignore: cast_nullable_to_non_nullable
as double?,message: freezed == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc
@JsonSerializable()

class ToolResultReceivedEvent extends ConversationEvent {
  const ToolResultReceivedEvent({@EventIdConverter() required this.eventId, @SessionIdConverter() required this.sessionId, required this.sequence, required this.occurredAt, @ToolCallIdConverter() required this.toolCallId, @MessageIdConverter() required this.messageId, @_ValidatedToolResultConverter() required this.result, final  String? $type}): $type = $type ?? 'tool_result_received',super._();
  factory ToolResultReceivedEvent.fromJson(Map<String, dynamic> json) => _$ToolResultReceivedEventFromJson(json);

@override@EventIdConverter() final  EventId eventId;
@override@SessionIdConverter() final  SessionId sessionId;
@override final  int sequence;
@override final  DateTime occurredAt;
@ToolCallIdConverter() final  ToolCallId toolCallId;
@MessageIdConverter() final  MessageId messageId;
@_ValidatedToolResultConverter() final  ToolResult result;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of ConversationEvent
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ToolResultReceivedEventCopyWith<ToolResultReceivedEvent> get copyWith => _$ToolResultReceivedEventCopyWithImpl<ToolResultReceivedEvent>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ToolResultReceivedEventToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ToolResultReceivedEvent&&(identical(other.eventId, eventId) || other.eventId == eventId)&&(identical(other.sessionId, sessionId) || other.sessionId == sessionId)&&(identical(other.sequence, sequence) || other.sequence == sequence)&&(identical(other.occurredAt, occurredAt) || other.occurredAt == occurredAt)&&(identical(other.toolCallId, toolCallId) || other.toolCallId == toolCallId)&&(identical(other.messageId, messageId) || other.messageId == messageId)&&(identical(other.result, result) || other.result == result));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,eventId,sessionId,sequence,occurredAt,toolCallId,messageId,result);

@override
String toString() {
  return 'ConversationEvent.toolResultReceived(eventId: $eventId, sessionId: $sessionId, sequence: $sequence, occurredAt: $occurredAt, toolCallId: $toolCallId, messageId: $messageId, result: $result)';
}


}

/// @nodoc
abstract mixin class $ToolResultReceivedEventCopyWith<$Res> implements $ConversationEventCopyWith<$Res> {
  factory $ToolResultReceivedEventCopyWith(ToolResultReceivedEvent value, $Res Function(ToolResultReceivedEvent) _then) = _$ToolResultReceivedEventCopyWithImpl;
@override @useResult
$Res call({
@EventIdConverter() EventId eventId,@SessionIdConverter() SessionId sessionId, int sequence, DateTime occurredAt,@ToolCallIdConverter() ToolCallId toolCallId,@MessageIdConverter() MessageId messageId,@_ValidatedToolResultConverter() ToolResult result
});


$ToolResultCopyWith<$Res> get result;

}
/// @nodoc
class _$ToolResultReceivedEventCopyWithImpl<$Res>
    implements $ToolResultReceivedEventCopyWith<$Res> {
  _$ToolResultReceivedEventCopyWithImpl(this._self, this._then);

  final ToolResultReceivedEvent _self;
  final $Res Function(ToolResultReceivedEvent) _then;

/// Create a copy of ConversationEvent
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? eventId = null,Object? sessionId = null,Object? sequence = null,Object? occurredAt = null,Object? toolCallId = null,Object? messageId = null,Object? result = null,}) {
  return _then(ToolResultReceivedEvent(
eventId: null == eventId ? _self.eventId : eventId // ignore: cast_nullable_to_non_nullable
as EventId,sessionId: null == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as SessionId,sequence: null == sequence ? _self.sequence : sequence // ignore: cast_nullable_to_non_nullable
as int,occurredAt: null == occurredAt ? _self.occurredAt : occurredAt // ignore: cast_nullable_to_non_nullable
as DateTime,toolCallId: null == toolCallId ? _self.toolCallId : toolCallId // ignore: cast_nullable_to_non_nullable
as ToolCallId,messageId: null == messageId ? _self.messageId : messageId // ignore: cast_nullable_to_non_nullable
as MessageId,result: null == result ? _self.result : result // ignore: cast_nullable_to_non_nullable
as ToolResult,
  ));
}

/// Create a copy of ConversationEvent
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ToolResultCopyWith<$Res> get result {
  
  return $ToolResultCopyWith<$Res>(_self.result, (value) {
    return _then(_self.copyWith(result: value));
  });
}
}

/// @nodoc
@JsonSerializable()

class UserConfirmationRequestedEvent extends ConversationEvent {
  const UserConfirmationRequestedEvent({@EventIdConverter() required this.eventId, @SessionIdConverter() required this.sessionId, required this.sequence, required this.occurredAt, @ToolCallIdConverter() required this.toolCallId, required this.confirmation, final  String? $type}): $type = $type ?? 'user_confirmation_requested',super._();
  factory UserConfirmationRequestedEvent.fromJson(Map<String, dynamic> json) => _$UserConfirmationRequestedEventFromJson(json);

@override@EventIdConverter() final  EventId eventId;
@override@SessionIdConverter() final  SessionId sessionId;
@override final  int sequence;
@override final  DateTime occurredAt;
@ToolCallIdConverter() final  ToolCallId toolCallId;
 final  ConfirmationSpec confirmation;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of ConversationEvent
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UserConfirmationRequestedEventCopyWith<UserConfirmationRequestedEvent> get copyWith => _$UserConfirmationRequestedEventCopyWithImpl<UserConfirmationRequestedEvent>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$UserConfirmationRequestedEventToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UserConfirmationRequestedEvent&&(identical(other.eventId, eventId) || other.eventId == eventId)&&(identical(other.sessionId, sessionId) || other.sessionId == sessionId)&&(identical(other.sequence, sequence) || other.sequence == sequence)&&(identical(other.occurredAt, occurredAt) || other.occurredAt == occurredAt)&&(identical(other.toolCallId, toolCallId) || other.toolCallId == toolCallId)&&(identical(other.confirmation, confirmation) || other.confirmation == confirmation));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,eventId,sessionId,sequence,occurredAt,toolCallId,confirmation);

@override
String toString() {
  return 'ConversationEvent.userConfirmationRequested(eventId: $eventId, sessionId: $sessionId, sequence: $sequence, occurredAt: $occurredAt, toolCallId: $toolCallId, confirmation: $confirmation)';
}


}

/// @nodoc
abstract mixin class $UserConfirmationRequestedEventCopyWith<$Res> implements $ConversationEventCopyWith<$Res> {
  factory $UserConfirmationRequestedEventCopyWith(UserConfirmationRequestedEvent value, $Res Function(UserConfirmationRequestedEvent) _then) = _$UserConfirmationRequestedEventCopyWithImpl;
@override @useResult
$Res call({
@EventIdConverter() EventId eventId,@SessionIdConverter() SessionId sessionId, int sequence, DateTime occurredAt,@ToolCallIdConverter() ToolCallId toolCallId, ConfirmationSpec confirmation
});


$ConfirmationSpecCopyWith<$Res> get confirmation;

}
/// @nodoc
class _$UserConfirmationRequestedEventCopyWithImpl<$Res>
    implements $UserConfirmationRequestedEventCopyWith<$Res> {
  _$UserConfirmationRequestedEventCopyWithImpl(this._self, this._then);

  final UserConfirmationRequestedEvent _self;
  final $Res Function(UserConfirmationRequestedEvent) _then;

/// Create a copy of ConversationEvent
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? eventId = null,Object? sessionId = null,Object? sequence = null,Object? occurredAt = null,Object? toolCallId = null,Object? confirmation = null,}) {
  return _then(UserConfirmationRequestedEvent(
eventId: null == eventId ? _self.eventId : eventId // ignore: cast_nullable_to_non_nullable
as EventId,sessionId: null == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as SessionId,sequence: null == sequence ? _self.sequence : sequence // ignore: cast_nullable_to_non_nullable
as int,occurredAt: null == occurredAt ? _self.occurredAt : occurredAt // ignore: cast_nullable_to_non_nullable
as DateTime,toolCallId: null == toolCallId ? _self.toolCallId : toolCallId // ignore: cast_nullable_to_non_nullable
as ToolCallId,confirmation: null == confirmation ? _self.confirmation : confirmation // ignore: cast_nullable_to_non_nullable
as ConfirmationSpec,
  ));
}

/// Create a copy of ConversationEvent
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

class PermissionRequestedEvent extends ConversationEvent {
  const PermissionRequestedEvent({@EventIdConverter() required this.eventId, @SessionIdConverter() required this.sessionId, required this.sequence, required this.occurredAt, required this.requestId, required this.permission, this.reason, final  String? $type}): $type = $type ?? 'permission_requested',super._();
  factory PermissionRequestedEvent.fromJson(Map<String, dynamic> json) => _$PermissionRequestedEventFromJson(json);

@override@EventIdConverter() final  EventId eventId;
@override@SessionIdConverter() final  SessionId sessionId;
@override final  int sequence;
@override final  DateTime occurredAt;
 final  String requestId;
 final  NexaPermission permission;
 final  String? reason;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of ConversationEvent
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PermissionRequestedEventCopyWith<PermissionRequestedEvent> get copyWith => _$PermissionRequestedEventCopyWithImpl<PermissionRequestedEvent>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PermissionRequestedEventToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PermissionRequestedEvent&&(identical(other.eventId, eventId) || other.eventId == eventId)&&(identical(other.sessionId, sessionId) || other.sessionId == sessionId)&&(identical(other.sequence, sequence) || other.sequence == sequence)&&(identical(other.occurredAt, occurredAt) || other.occurredAt == occurredAt)&&(identical(other.requestId, requestId) || other.requestId == requestId)&&(identical(other.permission, permission) || other.permission == permission)&&(identical(other.reason, reason) || other.reason == reason));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,eventId,sessionId,sequence,occurredAt,requestId,permission,reason);

@override
String toString() {
  return 'ConversationEvent.permissionRequested(eventId: $eventId, sessionId: $sessionId, sequence: $sequence, occurredAt: $occurredAt, requestId: $requestId, permission: $permission, reason: $reason)';
}


}

/// @nodoc
abstract mixin class $PermissionRequestedEventCopyWith<$Res> implements $ConversationEventCopyWith<$Res> {
  factory $PermissionRequestedEventCopyWith(PermissionRequestedEvent value, $Res Function(PermissionRequestedEvent) _then) = _$PermissionRequestedEventCopyWithImpl;
@override @useResult
$Res call({
@EventIdConverter() EventId eventId,@SessionIdConverter() SessionId sessionId, int sequence, DateTime occurredAt, String requestId, NexaPermission permission, String? reason
});




}
/// @nodoc
class _$PermissionRequestedEventCopyWithImpl<$Res>
    implements $PermissionRequestedEventCopyWith<$Res> {
  _$PermissionRequestedEventCopyWithImpl(this._self, this._then);

  final PermissionRequestedEvent _self;
  final $Res Function(PermissionRequestedEvent) _then;

/// Create a copy of ConversationEvent
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? eventId = null,Object? sessionId = null,Object? sequence = null,Object? occurredAt = null,Object? requestId = null,Object? permission = null,Object? reason = freezed,}) {
  return _then(PermissionRequestedEvent(
eventId: null == eventId ? _self.eventId : eventId // ignore: cast_nullable_to_non_nullable
as EventId,sessionId: null == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as SessionId,sequence: null == sequence ? _self.sequence : sequence // ignore: cast_nullable_to_non_nullable
as int,occurredAt: null == occurredAt ? _self.occurredAt : occurredAt // ignore: cast_nullable_to_non_nullable
as DateTime,requestId: null == requestId ? _self.requestId : requestId // ignore: cast_nullable_to_non_nullable
as String,permission: null == permission ? _self.permission : permission // ignore: cast_nullable_to_non_nullable
as NexaPermission,reason: freezed == reason ? _self.reason : reason // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc
@JsonSerializable()

class QuotaUpdatedEvent extends ConversationEvent {
  const QuotaUpdatedEvent({@EventIdConverter() required this.eventId, @SessionIdConverter() required this.sessionId, required this.sequence, required this.occurredAt, required this.quota, this.exceeded = false, final  String? $type}): $type = $type ?? 'quota_updated',super._();
  factory QuotaUpdatedEvent.fromJson(Map<String, dynamic> json) => _$QuotaUpdatedEventFromJson(json);

@override@EventIdConverter() final  EventId eventId;
@override@SessionIdConverter() final  SessionId sessionId;
@override final  int sequence;
@override final  DateTime occurredAt;
 final  QuotaInfo quota;
@JsonKey() final  bool exceeded;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of ConversationEvent
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$QuotaUpdatedEventCopyWith<QuotaUpdatedEvent> get copyWith => _$QuotaUpdatedEventCopyWithImpl<QuotaUpdatedEvent>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$QuotaUpdatedEventToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is QuotaUpdatedEvent&&(identical(other.eventId, eventId) || other.eventId == eventId)&&(identical(other.sessionId, sessionId) || other.sessionId == sessionId)&&(identical(other.sequence, sequence) || other.sequence == sequence)&&(identical(other.occurredAt, occurredAt) || other.occurredAt == occurredAt)&&(identical(other.quota, quota) || other.quota == quota)&&(identical(other.exceeded, exceeded) || other.exceeded == exceeded));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,eventId,sessionId,sequence,occurredAt,quota,exceeded);

@override
String toString() {
  return 'ConversationEvent.quotaUpdated(eventId: $eventId, sessionId: $sessionId, sequence: $sequence, occurredAt: $occurredAt, quota: $quota, exceeded: $exceeded)';
}


}

/// @nodoc
abstract mixin class $QuotaUpdatedEventCopyWith<$Res> implements $ConversationEventCopyWith<$Res> {
  factory $QuotaUpdatedEventCopyWith(QuotaUpdatedEvent value, $Res Function(QuotaUpdatedEvent) _then) = _$QuotaUpdatedEventCopyWithImpl;
@override @useResult
$Res call({
@EventIdConverter() EventId eventId,@SessionIdConverter() SessionId sessionId, int sequence, DateTime occurredAt, QuotaInfo quota, bool exceeded
});


$QuotaInfoCopyWith<$Res> get quota;

}
/// @nodoc
class _$QuotaUpdatedEventCopyWithImpl<$Res>
    implements $QuotaUpdatedEventCopyWith<$Res> {
  _$QuotaUpdatedEventCopyWithImpl(this._self, this._then);

  final QuotaUpdatedEvent _self;
  final $Res Function(QuotaUpdatedEvent) _then;

/// Create a copy of ConversationEvent
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? eventId = null,Object? sessionId = null,Object? sequence = null,Object? occurredAt = null,Object? quota = null,Object? exceeded = null,}) {
  return _then(QuotaUpdatedEvent(
eventId: null == eventId ? _self.eventId : eventId // ignore: cast_nullable_to_non_nullable
as EventId,sessionId: null == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as SessionId,sequence: null == sequence ? _self.sequence : sequence // ignore: cast_nullable_to_non_nullable
as int,occurredAt: null == occurredAt ? _self.occurredAt : occurredAt // ignore: cast_nullable_to_non_nullable
as DateTime,quota: null == quota ? _self.quota : quota // ignore: cast_nullable_to_non_nullable
as QuotaInfo,exceeded: null == exceeded ? _self.exceeded : exceeded // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

/// Create a copy of ConversationEvent
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$QuotaInfoCopyWith<$Res> get quota {
  
  return $QuotaInfoCopyWith<$Res>(_self.quota, (value) {
    return _then(_self.copyWith(quota: value));
  });
}
}

/// @nodoc
@JsonSerializable()

class UnsupportedEvent extends ConversationEvent {
  const UnsupportedEvent({@EventIdConverter() required this.eventId, @SessionIdConverter() required this.sessionId, required this.sequence, required this.occurredAt, this.originalType = '', this.reason, final  String? $type}): $type = $type ?? 'unsupported',super._();
  factory UnsupportedEvent.fromJson(Map<String, dynamic> json) => _$UnsupportedEventFromJson(json);

@override@EventIdConverter() final  EventId eventId;
@override@SessionIdConverter() final  SessionId sessionId;
@override final  int sequence;
@override final  DateTime occurredAt;
@JsonKey() final  String originalType;
 final  String? reason;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of ConversationEvent
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UnsupportedEventCopyWith<UnsupportedEvent> get copyWith => _$UnsupportedEventCopyWithImpl<UnsupportedEvent>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$UnsupportedEventToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UnsupportedEvent&&(identical(other.eventId, eventId) || other.eventId == eventId)&&(identical(other.sessionId, sessionId) || other.sessionId == sessionId)&&(identical(other.sequence, sequence) || other.sequence == sequence)&&(identical(other.occurredAt, occurredAt) || other.occurredAt == occurredAt)&&(identical(other.originalType, originalType) || other.originalType == originalType)&&(identical(other.reason, reason) || other.reason == reason));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,eventId,sessionId,sequence,occurredAt,originalType,reason);

@override
String toString() {
  return 'ConversationEvent.unsupported(eventId: $eventId, sessionId: $sessionId, sequence: $sequence, occurredAt: $occurredAt, originalType: $originalType, reason: $reason)';
}


}

/// @nodoc
abstract mixin class $UnsupportedEventCopyWith<$Res> implements $ConversationEventCopyWith<$Res> {
  factory $UnsupportedEventCopyWith(UnsupportedEvent value, $Res Function(UnsupportedEvent) _then) = _$UnsupportedEventCopyWithImpl;
@override @useResult
$Res call({
@EventIdConverter() EventId eventId,@SessionIdConverter() SessionId sessionId, int sequence, DateTime occurredAt, String originalType, String? reason
});




}
/// @nodoc
class _$UnsupportedEventCopyWithImpl<$Res>
    implements $UnsupportedEventCopyWith<$Res> {
  _$UnsupportedEventCopyWithImpl(this._self, this._then);

  final UnsupportedEvent _self;
  final $Res Function(UnsupportedEvent) _then;

/// Create a copy of ConversationEvent
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? eventId = null,Object? sessionId = null,Object? sequence = null,Object? occurredAt = null,Object? originalType = null,Object? reason = freezed,}) {
  return _then(UnsupportedEvent(
eventId: null == eventId ? _self.eventId : eventId // ignore: cast_nullable_to_non_nullable
as EventId,sessionId: null == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as SessionId,sequence: null == sequence ? _self.sequence : sequence // ignore: cast_nullable_to_non_nullable
as int,occurredAt: null == occurredAt ? _self.occurredAt : occurredAt // ignore: cast_nullable_to_non_nullable
as DateTime,originalType: null == originalType ? _self.originalType : originalType // ignore: cast_nullable_to_non_nullable
as String,reason: freezed == reason ? _self.reason : reason // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
