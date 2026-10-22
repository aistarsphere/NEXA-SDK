// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'tool_action.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
ToolAction _$ToolActionFromJson(
  Map<String, dynamic> json
) {
        switch (json['kind']) {
                  case 'form_submitted':
          return FormSubmittedAction.fromJson(
            json
          );
                case 'option_selected':
          return OptionSelectedAction.fromJson(
            json
          );
                case 'confirmed':
          return ConfirmedAction.fromJson(
            json
          );
                case 'declined':
          return DeclinedAction.fromJson(
            json
          );
                case 'card_action_tapped':
          return CardActionTappedAction.fromJson(
            json
          );
                case 'retry_requested':
          return RetryRequestedAction.fromJson(
            json
          );
        
          default:
            throw CheckedFromJsonException(
  json,
  'kind',
  'ToolAction',
  'Invalid union type "${json['kind']}"!'
);
        }
      
}

/// @nodoc
mixin _$ToolAction {

@ToolCallIdConverter() ToolCallId get toolCallId;
/// Create a copy of ToolAction
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ToolActionCopyWith<ToolAction> get copyWith => _$ToolActionCopyWithImpl<ToolAction>(this as ToolAction, _$identity);

  /// Serializes this ToolAction to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ToolAction&&(identical(other.toolCallId, toolCallId) || other.toolCallId == toolCallId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,toolCallId);

@override
String toString() {
  return 'ToolAction(toolCallId: $toolCallId)';
}


}

/// @nodoc
abstract mixin class $ToolActionCopyWith<$Res>  {
  factory $ToolActionCopyWith(ToolAction value, $Res Function(ToolAction) _then) = _$ToolActionCopyWithImpl;
@useResult
$Res call({
@ToolCallIdConverter() ToolCallId toolCallId
});




}
/// @nodoc
class _$ToolActionCopyWithImpl<$Res>
    implements $ToolActionCopyWith<$Res> {
  _$ToolActionCopyWithImpl(this._self, this._then);

  final ToolAction _self;
  final $Res Function(ToolAction) _then;

/// Create a copy of ToolAction
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? toolCallId = null,}) {
  return _then(_self.copyWith(
toolCallId: null == toolCallId ? _self.toolCallId : toolCallId // ignore: cast_nullable_to_non_nullable
as ToolCallId,
  ));
}

}


/// Adds pattern-matching-related methods to [ToolAction].
extension ToolActionPatterns on ToolAction {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( FormSubmittedAction value)?  formSubmitted,TResult Function( OptionSelectedAction value)?  optionSelected,TResult Function( ConfirmedAction value)?  confirmed,TResult Function( DeclinedAction value)?  declined,TResult Function( CardActionTappedAction value)?  cardActionTapped,TResult Function( RetryRequestedAction value)?  retryRequested,required TResult orElse(),}){
final _that = this;
switch (_that) {
case FormSubmittedAction() when formSubmitted != null:
return formSubmitted(_that);case OptionSelectedAction() when optionSelected != null:
return optionSelected(_that);case ConfirmedAction() when confirmed != null:
return confirmed(_that);case DeclinedAction() when declined != null:
return declined(_that);case CardActionTappedAction() when cardActionTapped != null:
return cardActionTapped(_that);case RetryRequestedAction() when retryRequested != null:
return retryRequested(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( FormSubmittedAction value)  formSubmitted,required TResult Function( OptionSelectedAction value)  optionSelected,required TResult Function( ConfirmedAction value)  confirmed,required TResult Function( DeclinedAction value)  declined,required TResult Function( CardActionTappedAction value)  cardActionTapped,required TResult Function( RetryRequestedAction value)  retryRequested,}){
final _that = this;
switch (_that) {
case FormSubmittedAction():
return formSubmitted(_that);case OptionSelectedAction():
return optionSelected(_that);case ConfirmedAction():
return confirmed(_that);case DeclinedAction():
return declined(_that);case CardActionTappedAction():
return cardActionTapped(_that);case RetryRequestedAction():
return retryRequested(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( FormSubmittedAction value)?  formSubmitted,TResult? Function( OptionSelectedAction value)?  optionSelected,TResult? Function( ConfirmedAction value)?  confirmed,TResult? Function( DeclinedAction value)?  declined,TResult? Function( CardActionTappedAction value)?  cardActionTapped,TResult? Function( RetryRequestedAction value)?  retryRequested,}){
final _that = this;
switch (_that) {
case FormSubmittedAction() when formSubmitted != null:
return formSubmitted(_that);case OptionSelectedAction() when optionSelected != null:
return optionSelected(_that);case ConfirmedAction() when confirmed != null:
return confirmed(_that);case DeclinedAction() when declined != null:
return declined(_that);case CardActionTappedAction() when cardActionTapped != null:
return cardActionTapped(_that);case RetryRequestedAction() when retryRequested != null:
return retryRequested(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function(@ToolCallIdConverter()  ToolCallId toolCallId,  String formId,  Map<String, Object?> values)?  formSubmitted,TResult Function(@ToolCallIdConverter()  ToolCallId toolCallId,  String selectionId,  List<String> optionIds)?  optionSelected,TResult Function(@ToolCallIdConverter()  ToolCallId toolCallId,  String confirmationId)?  confirmed,TResult Function(@ToolCallIdConverter()  ToolCallId toolCallId,  String confirmationId)?  declined,TResult Function(@ToolCallIdConverter()  ToolCallId toolCallId,  String actionId)?  cardActionTapped,TResult Function(@ToolCallIdConverter()  ToolCallId toolCallId)?  retryRequested,required TResult orElse(),}) {final _that = this;
switch (_that) {
case FormSubmittedAction() when formSubmitted != null:
return formSubmitted(_that.toolCallId,_that.formId,_that.values);case OptionSelectedAction() when optionSelected != null:
return optionSelected(_that.toolCallId,_that.selectionId,_that.optionIds);case ConfirmedAction() when confirmed != null:
return confirmed(_that.toolCallId,_that.confirmationId);case DeclinedAction() when declined != null:
return declined(_that.toolCallId,_that.confirmationId);case CardActionTappedAction() when cardActionTapped != null:
return cardActionTapped(_that.toolCallId,_that.actionId);case RetryRequestedAction() when retryRequested != null:
return retryRequested(_that.toolCallId);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function(@ToolCallIdConverter()  ToolCallId toolCallId,  String formId,  Map<String, Object?> values)  formSubmitted,required TResult Function(@ToolCallIdConverter()  ToolCallId toolCallId,  String selectionId,  List<String> optionIds)  optionSelected,required TResult Function(@ToolCallIdConverter()  ToolCallId toolCallId,  String confirmationId)  confirmed,required TResult Function(@ToolCallIdConverter()  ToolCallId toolCallId,  String confirmationId)  declined,required TResult Function(@ToolCallIdConverter()  ToolCallId toolCallId,  String actionId)  cardActionTapped,required TResult Function(@ToolCallIdConverter()  ToolCallId toolCallId)  retryRequested,}) {final _that = this;
switch (_that) {
case FormSubmittedAction():
return formSubmitted(_that.toolCallId,_that.formId,_that.values);case OptionSelectedAction():
return optionSelected(_that.toolCallId,_that.selectionId,_that.optionIds);case ConfirmedAction():
return confirmed(_that.toolCallId,_that.confirmationId);case DeclinedAction():
return declined(_that.toolCallId,_that.confirmationId);case CardActionTappedAction():
return cardActionTapped(_that.toolCallId,_that.actionId);case RetryRequestedAction():
return retryRequested(_that.toolCallId);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function(@ToolCallIdConverter()  ToolCallId toolCallId,  String formId,  Map<String, Object?> values)?  formSubmitted,TResult? Function(@ToolCallIdConverter()  ToolCallId toolCallId,  String selectionId,  List<String> optionIds)?  optionSelected,TResult? Function(@ToolCallIdConverter()  ToolCallId toolCallId,  String confirmationId)?  confirmed,TResult? Function(@ToolCallIdConverter()  ToolCallId toolCallId,  String confirmationId)?  declined,TResult? Function(@ToolCallIdConverter()  ToolCallId toolCallId,  String actionId)?  cardActionTapped,TResult? Function(@ToolCallIdConverter()  ToolCallId toolCallId)?  retryRequested,}) {final _that = this;
switch (_that) {
case FormSubmittedAction() when formSubmitted != null:
return formSubmitted(_that.toolCallId,_that.formId,_that.values);case OptionSelectedAction() when optionSelected != null:
return optionSelected(_that.toolCallId,_that.selectionId,_that.optionIds);case ConfirmedAction() when confirmed != null:
return confirmed(_that.toolCallId,_that.confirmationId);case DeclinedAction() when declined != null:
return declined(_that.toolCallId,_that.confirmationId);case CardActionTappedAction() when cardActionTapped != null:
return cardActionTapped(_that.toolCallId,_that.actionId);case RetryRequestedAction() when retryRequested != null:
return retryRequested(_that.toolCallId);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class FormSubmittedAction extends ToolAction {
  const FormSubmittedAction({@ToolCallIdConverter() required this.toolCallId, required this.formId, required final  Map<String, Object?> values, final  String? $type}): _values = values,$type = $type ?? 'form_submitted',super._();
  factory FormSubmittedAction.fromJson(Map<String, dynamic> json) => _$FormSubmittedActionFromJson(json);

@override@ToolCallIdConverter() final  ToolCallId toolCallId;
 final  String formId;
 final  Map<String, Object?> _values;
 Map<String, Object?> get values {
  if (_values is EqualUnmodifiableMapView) return _values;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_values);
}


@JsonKey(name: 'kind')
final String $type;


/// Create a copy of ToolAction
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FormSubmittedActionCopyWith<FormSubmittedAction> get copyWith => _$FormSubmittedActionCopyWithImpl<FormSubmittedAction>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$FormSubmittedActionToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FormSubmittedAction&&(identical(other.toolCallId, toolCallId) || other.toolCallId == toolCallId)&&(identical(other.formId, formId) || other.formId == formId)&&const DeepCollectionEquality().equals(other._values, _values));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,toolCallId,formId,const DeepCollectionEquality().hash(_values));

@override
String toString() {
  return 'ToolAction.formSubmitted(toolCallId: $toolCallId, formId: $formId, values: $values)';
}


}

/// @nodoc
abstract mixin class $FormSubmittedActionCopyWith<$Res> implements $ToolActionCopyWith<$Res> {
  factory $FormSubmittedActionCopyWith(FormSubmittedAction value, $Res Function(FormSubmittedAction) _then) = _$FormSubmittedActionCopyWithImpl;
@override @useResult
$Res call({
@ToolCallIdConverter() ToolCallId toolCallId, String formId, Map<String, Object?> values
});




}
/// @nodoc
class _$FormSubmittedActionCopyWithImpl<$Res>
    implements $FormSubmittedActionCopyWith<$Res> {
  _$FormSubmittedActionCopyWithImpl(this._self, this._then);

  final FormSubmittedAction _self;
  final $Res Function(FormSubmittedAction) _then;

/// Create a copy of ToolAction
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? toolCallId = null,Object? formId = null,Object? values = null,}) {
  return _then(FormSubmittedAction(
toolCallId: null == toolCallId ? _self.toolCallId : toolCallId // ignore: cast_nullable_to_non_nullable
as ToolCallId,formId: null == formId ? _self.formId : formId // ignore: cast_nullable_to_non_nullable
as String,values: null == values ? _self._values : values // ignore: cast_nullable_to_non_nullable
as Map<String, Object?>,
  ));
}


}

/// @nodoc
@JsonSerializable()

class OptionSelectedAction extends ToolAction {
  const OptionSelectedAction({@ToolCallIdConverter() required this.toolCallId, required this.selectionId, required final  List<String> optionIds, final  String? $type}): _optionIds = optionIds,$type = $type ?? 'option_selected',super._();
  factory OptionSelectedAction.fromJson(Map<String, dynamic> json) => _$OptionSelectedActionFromJson(json);

@override@ToolCallIdConverter() final  ToolCallId toolCallId;
 final  String selectionId;
 final  List<String> _optionIds;
 List<String> get optionIds {
  if (_optionIds is EqualUnmodifiableListView) return _optionIds;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_optionIds);
}


@JsonKey(name: 'kind')
final String $type;


/// Create a copy of ToolAction
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$OptionSelectedActionCopyWith<OptionSelectedAction> get copyWith => _$OptionSelectedActionCopyWithImpl<OptionSelectedAction>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$OptionSelectedActionToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is OptionSelectedAction&&(identical(other.toolCallId, toolCallId) || other.toolCallId == toolCallId)&&(identical(other.selectionId, selectionId) || other.selectionId == selectionId)&&const DeepCollectionEquality().equals(other._optionIds, _optionIds));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,toolCallId,selectionId,const DeepCollectionEquality().hash(_optionIds));

@override
String toString() {
  return 'ToolAction.optionSelected(toolCallId: $toolCallId, selectionId: $selectionId, optionIds: $optionIds)';
}


}

/// @nodoc
abstract mixin class $OptionSelectedActionCopyWith<$Res> implements $ToolActionCopyWith<$Res> {
  factory $OptionSelectedActionCopyWith(OptionSelectedAction value, $Res Function(OptionSelectedAction) _then) = _$OptionSelectedActionCopyWithImpl;
@override @useResult
$Res call({
@ToolCallIdConverter() ToolCallId toolCallId, String selectionId, List<String> optionIds
});




}
/// @nodoc
class _$OptionSelectedActionCopyWithImpl<$Res>
    implements $OptionSelectedActionCopyWith<$Res> {
  _$OptionSelectedActionCopyWithImpl(this._self, this._then);

  final OptionSelectedAction _self;
  final $Res Function(OptionSelectedAction) _then;

/// Create a copy of ToolAction
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? toolCallId = null,Object? selectionId = null,Object? optionIds = null,}) {
  return _then(OptionSelectedAction(
toolCallId: null == toolCallId ? _self.toolCallId : toolCallId // ignore: cast_nullable_to_non_nullable
as ToolCallId,selectionId: null == selectionId ? _self.selectionId : selectionId // ignore: cast_nullable_to_non_nullable
as String,optionIds: null == optionIds ? _self._optionIds : optionIds // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}


}

/// @nodoc
@JsonSerializable()

class ConfirmedAction extends ToolAction {
  const ConfirmedAction({@ToolCallIdConverter() required this.toolCallId, required this.confirmationId, final  String? $type}): $type = $type ?? 'confirmed',super._();
  factory ConfirmedAction.fromJson(Map<String, dynamic> json) => _$ConfirmedActionFromJson(json);

@override@ToolCallIdConverter() final  ToolCallId toolCallId;
 final  String confirmationId;

@JsonKey(name: 'kind')
final String $type;


/// Create a copy of ToolAction
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ConfirmedActionCopyWith<ConfirmedAction> get copyWith => _$ConfirmedActionCopyWithImpl<ConfirmedAction>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ConfirmedActionToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ConfirmedAction&&(identical(other.toolCallId, toolCallId) || other.toolCallId == toolCallId)&&(identical(other.confirmationId, confirmationId) || other.confirmationId == confirmationId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,toolCallId,confirmationId);

@override
String toString() {
  return 'ToolAction.confirmed(toolCallId: $toolCallId, confirmationId: $confirmationId)';
}


}

/// @nodoc
abstract mixin class $ConfirmedActionCopyWith<$Res> implements $ToolActionCopyWith<$Res> {
  factory $ConfirmedActionCopyWith(ConfirmedAction value, $Res Function(ConfirmedAction) _then) = _$ConfirmedActionCopyWithImpl;
@override @useResult
$Res call({
@ToolCallIdConverter() ToolCallId toolCallId, String confirmationId
});




}
/// @nodoc
class _$ConfirmedActionCopyWithImpl<$Res>
    implements $ConfirmedActionCopyWith<$Res> {
  _$ConfirmedActionCopyWithImpl(this._self, this._then);

  final ConfirmedAction _self;
  final $Res Function(ConfirmedAction) _then;

/// Create a copy of ToolAction
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? toolCallId = null,Object? confirmationId = null,}) {
  return _then(ConfirmedAction(
toolCallId: null == toolCallId ? _self.toolCallId : toolCallId // ignore: cast_nullable_to_non_nullable
as ToolCallId,confirmationId: null == confirmationId ? _self.confirmationId : confirmationId // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
@JsonSerializable()

class DeclinedAction extends ToolAction {
  const DeclinedAction({@ToolCallIdConverter() required this.toolCallId, required this.confirmationId, final  String? $type}): $type = $type ?? 'declined',super._();
  factory DeclinedAction.fromJson(Map<String, dynamic> json) => _$DeclinedActionFromJson(json);

@override@ToolCallIdConverter() final  ToolCallId toolCallId;
 final  String confirmationId;

@JsonKey(name: 'kind')
final String $type;


/// Create a copy of ToolAction
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DeclinedActionCopyWith<DeclinedAction> get copyWith => _$DeclinedActionCopyWithImpl<DeclinedAction>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$DeclinedActionToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DeclinedAction&&(identical(other.toolCallId, toolCallId) || other.toolCallId == toolCallId)&&(identical(other.confirmationId, confirmationId) || other.confirmationId == confirmationId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,toolCallId,confirmationId);

@override
String toString() {
  return 'ToolAction.declined(toolCallId: $toolCallId, confirmationId: $confirmationId)';
}


}

/// @nodoc
abstract mixin class $DeclinedActionCopyWith<$Res> implements $ToolActionCopyWith<$Res> {
  factory $DeclinedActionCopyWith(DeclinedAction value, $Res Function(DeclinedAction) _then) = _$DeclinedActionCopyWithImpl;
@override @useResult
$Res call({
@ToolCallIdConverter() ToolCallId toolCallId, String confirmationId
});




}
/// @nodoc
class _$DeclinedActionCopyWithImpl<$Res>
    implements $DeclinedActionCopyWith<$Res> {
  _$DeclinedActionCopyWithImpl(this._self, this._then);

  final DeclinedAction _self;
  final $Res Function(DeclinedAction) _then;

/// Create a copy of ToolAction
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? toolCallId = null,Object? confirmationId = null,}) {
  return _then(DeclinedAction(
toolCallId: null == toolCallId ? _self.toolCallId : toolCallId // ignore: cast_nullable_to_non_nullable
as ToolCallId,confirmationId: null == confirmationId ? _self.confirmationId : confirmationId // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
@JsonSerializable()

class CardActionTappedAction extends ToolAction {
  const CardActionTappedAction({@ToolCallIdConverter() required this.toolCallId, required this.actionId, final  String? $type}): $type = $type ?? 'card_action_tapped',super._();
  factory CardActionTappedAction.fromJson(Map<String, dynamic> json) => _$CardActionTappedActionFromJson(json);

@override@ToolCallIdConverter() final  ToolCallId toolCallId;
 final  String actionId;

@JsonKey(name: 'kind')
final String $type;


/// Create a copy of ToolAction
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CardActionTappedActionCopyWith<CardActionTappedAction> get copyWith => _$CardActionTappedActionCopyWithImpl<CardActionTappedAction>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CardActionTappedActionToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CardActionTappedAction&&(identical(other.toolCallId, toolCallId) || other.toolCallId == toolCallId)&&(identical(other.actionId, actionId) || other.actionId == actionId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,toolCallId,actionId);

@override
String toString() {
  return 'ToolAction.cardActionTapped(toolCallId: $toolCallId, actionId: $actionId)';
}


}

/// @nodoc
abstract mixin class $CardActionTappedActionCopyWith<$Res> implements $ToolActionCopyWith<$Res> {
  factory $CardActionTappedActionCopyWith(CardActionTappedAction value, $Res Function(CardActionTappedAction) _then) = _$CardActionTappedActionCopyWithImpl;
@override @useResult
$Res call({
@ToolCallIdConverter() ToolCallId toolCallId, String actionId
});




}
/// @nodoc
class _$CardActionTappedActionCopyWithImpl<$Res>
    implements $CardActionTappedActionCopyWith<$Res> {
  _$CardActionTappedActionCopyWithImpl(this._self, this._then);

  final CardActionTappedAction _self;
  final $Res Function(CardActionTappedAction) _then;

/// Create a copy of ToolAction
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? toolCallId = null,Object? actionId = null,}) {
  return _then(CardActionTappedAction(
toolCallId: null == toolCallId ? _self.toolCallId : toolCallId // ignore: cast_nullable_to_non_nullable
as ToolCallId,actionId: null == actionId ? _self.actionId : actionId // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
@JsonSerializable()

class RetryRequestedAction extends ToolAction {
  const RetryRequestedAction({@ToolCallIdConverter() required this.toolCallId, final  String? $type}): $type = $type ?? 'retry_requested',super._();
  factory RetryRequestedAction.fromJson(Map<String, dynamic> json) => _$RetryRequestedActionFromJson(json);

@override@ToolCallIdConverter() final  ToolCallId toolCallId;

@JsonKey(name: 'kind')
final String $type;


/// Create a copy of ToolAction
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RetryRequestedActionCopyWith<RetryRequestedAction> get copyWith => _$RetryRequestedActionCopyWithImpl<RetryRequestedAction>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$RetryRequestedActionToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RetryRequestedAction&&(identical(other.toolCallId, toolCallId) || other.toolCallId == toolCallId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,toolCallId);

@override
String toString() {
  return 'ToolAction.retryRequested(toolCallId: $toolCallId)';
}


}

/// @nodoc
abstract mixin class $RetryRequestedActionCopyWith<$Res> implements $ToolActionCopyWith<$Res> {
  factory $RetryRequestedActionCopyWith(RetryRequestedAction value, $Res Function(RetryRequestedAction) _then) = _$RetryRequestedActionCopyWithImpl;
@override @useResult
$Res call({
@ToolCallIdConverter() ToolCallId toolCallId
});




}
/// @nodoc
class _$RetryRequestedActionCopyWithImpl<$Res>
    implements $RetryRequestedActionCopyWith<$Res> {
  _$RetryRequestedActionCopyWithImpl(this._self, this._then);

  final RetryRequestedAction _self;
  final $Res Function(RetryRequestedAction) _then;

/// Create a copy of ToolAction
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? toolCallId = null,}) {
  return _then(RetryRequestedAction(
toolCallId: null == toolCallId ? _self.toolCallId : toolCallId // ignore: cast_nullable_to_non_nullable
as ToolCallId,
  ));
}


}

// dart format on
