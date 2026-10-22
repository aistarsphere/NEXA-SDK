// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'chat_message.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ChatMessage {

 MessageId get id; MessageRole get role; MessageStatus get status; DateTime get createdAt; String get text;/// Idempotency key for user messages (null for assistant messages).
 ClientMessageId? get clientMessageId;/// Tool calls attached to this assistant message, in request order.
 List<ToolCallId> get toolCallIds;/// Index of the last applied text delta; used to drop duplicates.
 int get lastDeltaIndex;/// Stable error code when [status] is [MessageStatus.failed].
 String? get errorCode;/// Developer-facing error message when failed.
 String? get errorMessage;/// Whether the user may retry this message (user role, failed/pending).
 bool get retryable;
/// Create a copy of ChatMessage
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ChatMessageCopyWith<ChatMessage> get copyWith => _$ChatMessageCopyWithImpl<ChatMessage>(this as ChatMessage, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ChatMessage&&(identical(other.id, id) || other.id == id)&&(identical(other.role, role) || other.role == role)&&(identical(other.status, status) || other.status == status)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.text, text) || other.text == text)&&(identical(other.clientMessageId, clientMessageId) || other.clientMessageId == clientMessageId)&&const DeepCollectionEquality().equals(other.toolCallIds, toolCallIds)&&(identical(other.lastDeltaIndex, lastDeltaIndex) || other.lastDeltaIndex == lastDeltaIndex)&&(identical(other.errorCode, errorCode) || other.errorCode == errorCode)&&(identical(other.errorMessage, errorMessage) || other.errorMessage == errorMessage)&&(identical(other.retryable, retryable) || other.retryable == retryable));
}


@override
int get hashCode => Object.hash(runtimeType,id,role,status,createdAt,text,clientMessageId,const DeepCollectionEquality().hash(toolCallIds),lastDeltaIndex,errorCode,errorMessage,retryable);

@override
String toString() {
  return 'ChatMessage(id: $id, role: $role, status: $status, createdAt: $createdAt, text: $text, clientMessageId: $clientMessageId, toolCallIds: $toolCallIds, lastDeltaIndex: $lastDeltaIndex, errorCode: $errorCode, errorMessage: $errorMessage, retryable: $retryable)';
}


}

/// @nodoc
abstract mixin class $ChatMessageCopyWith<$Res>  {
  factory $ChatMessageCopyWith(ChatMessage value, $Res Function(ChatMessage) _then) = _$ChatMessageCopyWithImpl;
@useResult
$Res call({
 MessageId id, MessageRole role, MessageStatus status, DateTime createdAt, String text, ClientMessageId? clientMessageId, List<ToolCallId> toolCallIds, int lastDeltaIndex, String? errorCode, String? errorMessage, bool retryable
});




}
/// @nodoc
class _$ChatMessageCopyWithImpl<$Res>
    implements $ChatMessageCopyWith<$Res> {
  _$ChatMessageCopyWithImpl(this._self, this._then);

  final ChatMessage _self;
  final $Res Function(ChatMessage) _then;

/// Create a copy of ChatMessage
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? role = null,Object? status = null,Object? createdAt = null,Object? text = null,Object? clientMessageId = freezed,Object? toolCallIds = null,Object? lastDeltaIndex = null,Object? errorCode = freezed,Object? errorMessage = freezed,Object? retryable = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as MessageId,role: null == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as MessageRole,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as MessageStatus,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,text: null == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String,clientMessageId: freezed == clientMessageId ? _self.clientMessageId : clientMessageId // ignore: cast_nullable_to_non_nullable
as ClientMessageId?,toolCallIds: null == toolCallIds ? _self.toolCallIds : toolCallIds // ignore: cast_nullable_to_non_nullable
as List<ToolCallId>,lastDeltaIndex: null == lastDeltaIndex ? _self.lastDeltaIndex : lastDeltaIndex // ignore: cast_nullable_to_non_nullable
as int,errorCode: freezed == errorCode ? _self.errorCode : errorCode // ignore: cast_nullable_to_non_nullable
as String?,errorMessage: freezed == errorMessage ? _self.errorMessage : errorMessage // ignore: cast_nullable_to_non_nullable
as String?,retryable: null == retryable ? _self.retryable : retryable // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [ChatMessage].
extension ChatMessagePatterns on ChatMessage {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ChatMessage value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ChatMessage() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ChatMessage value)  $default,){
final _that = this;
switch (_that) {
case _ChatMessage():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ChatMessage value)?  $default,){
final _that = this;
switch (_that) {
case _ChatMessage() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( MessageId id,  MessageRole role,  MessageStatus status,  DateTime createdAt,  String text,  ClientMessageId? clientMessageId,  List<ToolCallId> toolCallIds,  int lastDeltaIndex,  String? errorCode,  String? errorMessage,  bool retryable)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ChatMessage() when $default != null:
return $default(_that.id,_that.role,_that.status,_that.createdAt,_that.text,_that.clientMessageId,_that.toolCallIds,_that.lastDeltaIndex,_that.errorCode,_that.errorMessage,_that.retryable);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( MessageId id,  MessageRole role,  MessageStatus status,  DateTime createdAt,  String text,  ClientMessageId? clientMessageId,  List<ToolCallId> toolCallIds,  int lastDeltaIndex,  String? errorCode,  String? errorMessage,  bool retryable)  $default,) {final _that = this;
switch (_that) {
case _ChatMessage():
return $default(_that.id,_that.role,_that.status,_that.createdAt,_that.text,_that.clientMessageId,_that.toolCallIds,_that.lastDeltaIndex,_that.errorCode,_that.errorMessage,_that.retryable);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( MessageId id,  MessageRole role,  MessageStatus status,  DateTime createdAt,  String text,  ClientMessageId? clientMessageId,  List<ToolCallId> toolCallIds,  int lastDeltaIndex,  String? errorCode,  String? errorMessage,  bool retryable)?  $default,) {final _that = this;
switch (_that) {
case _ChatMessage() when $default != null:
return $default(_that.id,_that.role,_that.status,_that.createdAt,_that.text,_that.clientMessageId,_that.toolCallIds,_that.lastDeltaIndex,_that.errorCode,_that.errorMessage,_that.retryable);case _:
  return null;

}
}

}

/// @nodoc


class _ChatMessage extends ChatMessage {
  const _ChatMessage({required this.id, required this.role, required this.status, required this.createdAt, this.text = '', this.clientMessageId, final  List<ToolCallId> toolCallIds = const <ToolCallId>[], this.lastDeltaIndex = -1, this.errorCode, this.errorMessage, this.retryable = false}): _toolCallIds = toolCallIds,super._();
  

@override final  MessageId id;
@override final  MessageRole role;
@override final  MessageStatus status;
@override final  DateTime createdAt;
@override@JsonKey() final  String text;
/// Idempotency key for user messages (null for assistant messages).
@override final  ClientMessageId? clientMessageId;
/// Tool calls attached to this assistant message, in request order.
 final  List<ToolCallId> _toolCallIds;
/// Tool calls attached to this assistant message, in request order.
@override@JsonKey() List<ToolCallId> get toolCallIds {
  if (_toolCallIds is EqualUnmodifiableListView) return _toolCallIds;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_toolCallIds);
}

/// Index of the last applied text delta; used to drop duplicates.
@override@JsonKey() final  int lastDeltaIndex;
/// Stable error code when [status] is [MessageStatus.failed].
@override final  String? errorCode;
/// Developer-facing error message when failed.
@override final  String? errorMessage;
/// Whether the user may retry this message (user role, failed/pending).
@override@JsonKey() final  bool retryable;

/// Create a copy of ChatMessage
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ChatMessageCopyWith<_ChatMessage> get copyWith => __$ChatMessageCopyWithImpl<_ChatMessage>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ChatMessage&&(identical(other.id, id) || other.id == id)&&(identical(other.role, role) || other.role == role)&&(identical(other.status, status) || other.status == status)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.text, text) || other.text == text)&&(identical(other.clientMessageId, clientMessageId) || other.clientMessageId == clientMessageId)&&const DeepCollectionEquality().equals(other._toolCallIds, _toolCallIds)&&(identical(other.lastDeltaIndex, lastDeltaIndex) || other.lastDeltaIndex == lastDeltaIndex)&&(identical(other.errorCode, errorCode) || other.errorCode == errorCode)&&(identical(other.errorMessage, errorMessage) || other.errorMessage == errorMessage)&&(identical(other.retryable, retryable) || other.retryable == retryable));
}


@override
int get hashCode => Object.hash(runtimeType,id,role,status,createdAt,text,clientMessageId,const DeepCollectionEquality().hash(_toolCallIds),lastDeltaIndex,errorCode,errorMessage,retryable);

@override
String toString() {
  return 'ChatMessage(id: $id, role: $role, status: $status, createdAt: $createdAt, text: $text, clientMessageId: $clientMessageId, toolCallIds: $toolCallIds, lastDeltaIndex: $lastDeltaIndex, errorCode: $errorCode, errorMessage: $errorMessage, retryable: $retryable)';
}


}

/// @nodoc
abstract mixin class _$ChatMessageCopyWith<$Res> implements $ChatMessageCopyWith<$Res> {
  factory _$ChatMessageCopyWith(_ChatMessage value, $Res Function(_ChatMessage) _then) = __$ChatMessageCopyWithImpl;
@override @useResult
$Res call({
 MessageId id, MessageRole role, MessageStatus status, DateTime createdAt, String text, ClientMessageId? clientMessageId, List<ToolCallId> toolCallIds, int lastDeltaIndex, String? errorCode, String? errorMessage, bool retryable
});




}
/// @nodoc
class __$ChatMessageCopyWithImpl<$Res>
    implements _$ChatMessageCopyWith<$Res> {
  __$ChatMessageCopyWithImpl(this._self, this._then);

  final _ChatMessage _self;
  final $Res Function(_ChatMessage) _then;

/// Create a copy of ChatMessage
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? role = null,Object? status = null,Object? createdAt = null,Object? text = null,Object? clientMessageId = freezed,Object? toolCallIds = null,Object? lastDeltaIndex = null,Object? errorCode = freezed,Object? errorMessage = freezed,Object? retryable = null,}) {
  return _then(_ChatMessage(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as MessageId,role: null == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as MessageRole,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as MessageStatus,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,text: null == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String,clientMessageId: freezed == clientMessageId ? _self.clientMessageId : clientMessageId // ignore: cast_nullable_to_non_nullable
as ClientMessageId?,toolCallIds: null == toolCallIds ? _self._toolCallIds : toolCallIds // ignore: cast_nullable_to_non_nullable
as List<ToolCallId>,lastDeltaIndex: null == lastDeltaIndex ? _self.lastDeltaIndex : lastDeltaIndex // ignore: cast_nullable_to_non_nullable
as int,errorCode: freezed == errorCode ? _self.errorCode : errorCode // ignore: cast_nullable_to_non_nullable
as String?,errorMessage: freezed == errorMessage ? _self.errorMessage : errorMessage // ignore: cast_nullable_to_non_nullable
as String?,retryable: null == retryable ? _self.retryable : retryable // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
