// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'nexa_config.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$NexaConfig {

/// Public SDK application identifier (e.g. `app_8f3e...`).
 String get applicationId;/// Base URI of the NEXA gateway, e.g. `https://gw.staging.nexa.example`.
 Uri get gatewayBaseUri;/// Target environment. Defaults to production.
 NexaEnvironment get environment;/// BCP-47 language tag for the SDK UI. Supported: `en`, `ar`.
 String get languageTag;/// Capabilities the host wants enabled. Grants are decided by the gateway.
 Set<NexaCapability> get requestedCapabilities;/// HTTP connect timeout.
 Duration get connectTimeout;/// HTTP receive timeout for non-streaming calls.
 Duration get receiveTimeout;/// Event delivery mechanism. Server-Sent Events by default; long-polling
/// for networks that cannot keep a streaming response open.
 NexaEventDelivery get eventDelivery;/// Base delay for reconnect back-off (doubles per attempt, capped) and
/// the pause between long-poll requests.
 Duration get eventPollInterval;/// How many automatic reconnects the chat attempts after a transient
/// event-stream failure before asking the user to retry.
 int get maxReconnectAttempts;/// Opaque metadata echoed to the gateway for support/diagnostics
/// (e.g. host app version). Never put secrets here.
 Map<String, String> get clientMetadata;
/// Create a copy of NexaConfig
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$NexaConfigCopyWith<NexaConfig> get copyWith => _$NexaConfigCopyWithImpl<NexaConfig>(this as NexaConfig, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is NexaConfig&&(identical(other.applicationId, applicationId) || other.applicationId == applicationId)&&(identical(other.gatewayBaseUri, gatewayBaseUri) || other.gatewayBaseUri == gatewayBaseUri)&&(identical(other.environment, environment) || other.environment == environment)&&(identical(other.languageTag, languageTag) || other.languageTag == languageTag)&&const DeepCollectionEquality().equals(other.requestedCapabilities, requestedCapabilities)&&(identical(other.connectTimeout, connectTimeout) || other.connectTimeout == connectTimeout)&&(identical(other.receiveTimeout, receiveTimeout) || other.receiveTimeout == receiveTimeout)&&(identical(other.eventDelivery, eventDelivery) || other.eventDelivery == eventDelivery)&&(identical(other.eventPollInterval, eventPollInterval) || other.eventPollInterval == eventPollInterval)&&(identical(other.maxReconnectAttempts, maxReconnectAttempts) || other.maxReconnectAttempts == maxReconnectAttempts)&&const DeepCollectionEquality().equals(other.clientMetadata, clientMetadata));
}


@override
int get hashCode => Object.hash(runtimeType,applicationId,gatewayBaseUri,environment,languageTag,const DeepCollectionEquality().hash(requestedCapabilities),connectTimeout,receiveTimeout,eventDelivery,eventPollInterval,maxReconnectAttempts,const DeepCollectionEquality().hash(clientMetadata));

@override
String toString() {
  return 'NexaConfig(applicationId: $applicationId, gatewayBaseUri: $gatewayBaseUri, environment: $environment, languageTag: $languageTag, requestedCapabilities: $requestedCapabilities, connectTimeout: $connectTimeout, receiveTimeout: $receiveTimeout, eventDelivery: $eventDelivery, eventPollInterval: $eventPollInterval, maxReconnectAttempts: $maxReconnectAttempts, clientMetadata: $clientMetadata)';
}


}

/// @nodoc
abstract mixin class $NexaConfigCopyWith<$Res>  {
  factory $NexaConfigCopyWith(NexaConfig value, $Res Function(NexaConfig) _then) = _$NexaConfigCopyWithImpl;
@useResult
$Res call({
 String applicationId, Uri gatewayBaseUri, NexaEnvironment environment, String languageTag, Set<NexaCapability> requestedCapabilities, Duration connectTimeout, Duration receiveTimeout, NexaEventDelivery eventDelivery, Duration eventPollInterval, int maxReconnectAttempts, Map<String, String> clientMetadata
});




}
/// @nodoc
class _$NexaConfigCopyWithImpl<$Res>
    implements $NexaConfigCopyWith<$Res> {
  _$NexaConfigCopyWithImpl(this._self, this._then);

  final NexaConfig _self;
  final $Res Function(NexaConfig) _then;

/// Create a copy of NexaConfig
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? applicationId = null,Object? gatewayBaseUri = null,Object? environment = null,Object? languageTag = null,Object? requestedCapabilities = null,Object? connectTimeout = null,Object? receiveTimeout = null,Object? eventDelivery = null,Object? eventPollInterval = null,Object? maxReconnectAttempts = null,Object? clientMetadata = null,}) {
  return _then(_self.copyWith(
applicationId: null == applicationId ? _self.applicationId : applicationId // ignore: cast_nullable_to_non_nullable
as String,gatewayBaseUri: null == gatewayBaseUri ? _self.gatewayBaseUri : gatewayBaseUri // ignore: cast_nullable_to_non_nullable
as Uri,environment: null == environment ? _self.environment : environment // ignore: cast_nullable_to_non_nullable
as NexaEnvironment,languageTag: null == languageTag ? _self.languageTag : languageTag // ignore: cast_nullable_to_non_nullable
as String,requestedCapabilities: null == requestedCapabilities ? _self.requestedCapabilities : requestedCapabilities // ignore: cast_nullable_to_non_nullable
as Set<NexaCapability>,connectTimeout: null == connectTimeout ? _self.connectTimeout : connectTimeout // ignore: cast_nullable_to_non_nullable
as Duration,receiveTimeout: null == receiveTimeout ? _self.receiveTimeout : receiveTimeout // ignore: cast_nullable_to_non_nullable
as Duration,eventDelivery: null == eventDelivery ? _self.eventDelivery : eventDelivery // ignore: cast_nullable_to_non_nullable
as NexaEventDelivery,eventPollInterval: null == eventPollInterval ? _self.eventPollInterval : eventPollInterval // ignore: cast_nullable_to_non_nullable
as Duration,maxReconnectAttempts: null == maxReconnectAttempts ? _self.maxReconnectAttempts : maxReconnectAttempts // ignore: cast_nullable_to_non_nullable
as int,clientMetadata: null == clientMetadata ? _self.clientMetadata : clientMetadata // ignore: cast_nullable_to_non_nullable
as Map<String, String>,
  ));
}

}


/// Adds pattern-matching-related methods to [NexaConfig].
extension NexaConfigPatterns on NexaConfig {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _NexaConfig value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _NexaConfig() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _NexaConfig value)  $default,){
final _that = this;
switch (_that) {
case _NexaConfig():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _NexaConfig value)?  $default,){
final _that = this;
switch (_that) {
case _NexaConfig() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String applicationId,  Uri gatewayBaseUri,  NexaEnvironment environment,  String languageTag,  Set<NexaCapability> requestedCapabilities,  Duration connectTimeout,  Duration receiveTimeout,  NexaEventDelivery eventDelivery,  Duration eventPollInterval,  int maxReconnectAttempts,  Map<String, String> clientMetadata)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _NexaConfig() when $default != null:
return $default(_that.applicationId,_that.gatewayBaseUri,_that.environment,_that.languageTag,_that.requestedCapabilities,_that.connectTimeout,_that.receiveTimeout,_that.eventDelivery,_that.eventPollInterval,_that.maxReconnectAttempts,_that.clientMetadata);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String applicationId,  Uri gatewayBaseUri,  NexaEnvironment environment,  String languageTag,  Set<NexaCapability> requestedCapabilities,  Duration connectTimeout,  Duration receiveTimeout,  NexaEventDelivery eventDelivery,  Duration eventPollInterval,  int maxReconnectAttempts,  Map<String, String> clientMetadata)  $default,) {final _that = this;
switch (_that) {
case _NexaConfig():
return $default(_that.applicationId,_that.gatewayBaseUri,_that.environment,_that.languageTag,_that.requestedCapabilities,_that.connectTimeout,_that.receiveTimeout,_that.eventDelivery,_that.eventPollInterval,_that.maxReconnectAttempts,_that.clientMetadata);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String applicationId,  Uri gatewayBaseUri,  NexaEnvironment environment,  String languageTag,  Set<NexaCapability> requestedCapabilities,  Duration connectTimeout,  Duration receiveTimeout,  NexaEventDelivery eventDelivery,  Duration eventPollInterval,  int maxReconnectAttempts,  Map<String, String> clientMetadata)?  $default,) {final _that = this;
switch (_that) {
case _NexaConfig() when $default != null:
return $default(_that.applicationId,_that.gatewayBaseUri,_that.environment,_that.languageTag,_that.requestedCapabilities,_that.connectTimeout,_that.receiveTimeout,_that.eventDelivery,_that.eventPollInterval,_that.maxReconnectAttempts,_that.clientMetadata);case _:
  return null;

}
}

}

/// @nodoc


class _NexaConfig extends NexaConfig {
  const _NexaConfig({required this.applicationId, required this.gatewayBaseUri, this.environment = NexaEnvironment.production, this.languageTag = 'en', final  Set<NexaCapability> requestedCapabilities = const {NexaCapability.textChat}, this.connectTimeout = const Duration(seconds: 10), this.receiveTimeout = const Duration(seconds: 30), this.eventDelivery = NexaEventDelivery.serverSentEvents, this.eventPollInterval = const Duration(milliseconds: 750), this.maxReconnectAttempts = 5, final  Map<String, String> clientMetadata = const <String, String>{}}): _requestedCapabilities = requestedCapabilities,_clientMetadata = clientMetadata,super._();
  

/// Public SDK application identifier (e.g. `app_8f3e...`).
@override final  String applicationId;
/// Base URI of the NEXA gateway, e.g. `https://gw.staging.nexa.example`.
@override final  Uri gatewayBaseUri;
/// Target environment. Defaults to production.
@override@JsonKey() final  NexaEnvironment environment;
/// BCP-47 language tag for the SDK UI. Supported: `en`, `ar`.
@override@JsonKey() final  String languageTag;
/// Capabilities the host wants enabled. Grants are decided by the gateway.
 final  Set<NexaCapability> _requestedCapabilities;
/// Capabilities the host wants enabled. Grants are decided by the gateway.
@override@JsonKey() Set<NexaCapability> get requestedCapabilities {
  if (_requestedCapabilities is EqualUnmodifiableSetView) return _requestedCapabilities;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableSetView(_requestedCapabilities);
}

/// HTTP connect timeout.
@override@JsonKey() final  Duration connectTimeout;
/// HTTP receive timeout for non-streaming calls.
@override@JsonKey() final  Duration receiveTimeout;
/// Event delivery mechanism. Server-Sent Events by default; long-polling
/// for networks that cannot keep a streaming response open.
@override@JsonKey() final  NexaEventDelivery eventDelivery;
/// Base delay for reconnect back-off (doubles per attempt, capped) and
/// the pause between long-poll requests.
@override@JsonKey() final  Duration eventPollInterval;
/// How many automatic reconnects the chat attempts after a transient
/// event-stream failure before asking the user to retry.
@override@JsonKey() final  int maxReconnectAttempts;
/// Opaque metadata echoed to the gateway for support/diagnostics
/// (e.g. host app version). Never put secrets here.
 final  Map<String, String> _clientMetadata;
/// Opaque metadata echoed to the gateway for support/diagnostics
/// (e.g. host app version). Never put secrets here.
@override@JsonKey() Map<String, String> get clientMetadata {
  if (_clientMetadata is EqualUnmodifiableMapView) return _clientMetadata;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_clientMetadata);
}


/// Create a copy of NexaConfig
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$NexaConfigCopyWith<_NexaConfig> get copyWith => __$NexaConfigCopyWithImpl<_NexaConfig>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _NexaConfig&&(identical(other.applicationId, applicationId) || other.applicationId == applicationId)&&(identical(other.gatewayBaseUri, gatewayBaseUri) || other.gatewayBaseUri == gatewayBaseUri)&&(identical(other.environment, environment) || other.environment == environment)&&(identical(other.languageTag, languageTag) || other.languageTag == languageTag)&&const DeepCollectionEquality().equals(other._requestedCapabilities, _requestedCapabilities)&&(identical(other.connectTimeout, connectTimeout) || other.connectTimeout == connectTimeout)&&(identical(other.receiveTimeout, receiveTimeout) || other.receiveTimeout == receiveTimeout)&&(identical(other.eventDelivery, eventDelivery) || other.eventDelivery == eventDelivery)&&(identical(other.eventPollInterval, eventPollInterval) || other.eventPollInterval == eventPollInterval)&&(identical(other.maxReconnectAttempts, maxReconnectAttempts) || other.maxReconnectAttempts == maxReconnectAttempts)&&const DeepCollectionEquality().equals(other._clientMetadata, _clientMetadata));
}


@override
int get hashCode => Object.hash(runtimeType,applicationId,gatewayBaseUri,environment,languageTag,const DeepCollectionEquality().hash(_requestedCapabilities),connectTimeout,receiveTimeout,eventDelivery,eventPollInterval,maxReconnectAttempts,const DeepCollectionEquality().hash(_clientMetadata));

@override
String toString() {
  return 'NexaConfig(applicationId: $applicationId, gatewayBaseUri: $gatewayBaseUri, environment: $environment, languageTag: $languageTag, requestedCapabilities: $requestedCapabilities, connectTimeout: $connectTimeout, receiveTimeout: $receiveTimeout, eventDelivery: $eventDelivery, eventPollInterval: $eventPollInterval, maxReconnectAttempts: $maxReconnectAttempts, clientMetadata: $clientMetadata)';
}


}

/// @nodoc
abstract mixin class _$NexaConfigCopyWith<$Res> implements $NexaConfigCopyWith<$Res> {
  factory _$NexaConfigCopyWith(_NexaConfig value, $Res Function(_NexaConfig) _then) = __$NexaConfigCopyWithImpl;
@override @useResult
$Res call({
 String applicationId, Uri gatewayBaseUri, NexaEnvironment environment, String languageTag, Set<NexaCapability> requestedCapabilities, Duration connectTimeout, Duration receiveTimeout, NexaEventDelivery eventDelivery, Duration eventPollInterval, int maxReconnectAttempts, Map<String, String> clientMetadata
});




}
/// @nodoc
class __$NexaConfigCopyWithImpl<$Res>
    implements _$NexaConfigCopyWith<$Res> {
  __$NexaConfigCopyWithImpl(this._self, this._then);

  final _NexaConfig _self;
  final $Res Function(_NexaConfig) _then;

/// Create a copy of NexaConfig
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? applicationId = null,Object? gatewayBaseUri = null,Object? environment = null,Object? languageTag = null,Object? requestedCapabilities = null,Object? connectTimeout = null,Object? receiveTimeout = null,Object? eventDelivery = null,Object? eventPollInterval = null,Object? maxReconnectAttempts = null,Object? clientMetadata = null,}) {
  return _then(_NexaConfig(
applicationId: null == applicationId ? _self.applicationId : applicationId // ignore: cast_nullable_to_non_nullable
as String,gatewayBaseUri: null == gatewayBaseUri ? _self.gatewayBaseUri : gatewayBaseUri // ignore: cast_nullable_to_non_nullable
as Uri,environment: null == environment ? _self.environment : environment // ignore: cast_nullable_to_non_nullable
as NexaEnvironment,languageTag: null == languageTag ? _self.languageTag : languageTag // ignore: cast_nullable_to_non_nullable
as String,requestedCapabilities: null == requestedCapabilities ? _self._requestedCapabilities : requestedCapabilities // ignore: cast_nullable_to_non_nullable
as Set<NexaCapability>,connectTimeout: null == connectTimeout ? _self.connectTimeout : connectTimeout // ignore: cast_nullable_to_non_nullable
as Duration,receiveTimeout: null == receiveTimeout ? _self.receiveTimeout : receiveTimeout // ignore: cast_nullable_to_non_nullable
as Duration,eventDelivery: null == eventDelivery ? _self.eventDelivery : eventDelivery // ignore: cast_nullable_to_non_nullable
as NexaEventDelivery,eventPollInterval: null == eventPollInterval ? _self.eventPollInterval : eventPollInterval // ignore: cast_nullable_to_non_nullable
as Duration,maxReconnectAttempts: null == maxReconnectAttempts ? _self.maxReconnectAttempts : maxReconnectAttempts // ignore: cast_nullable_to_non_nullable
as int,clientMetadata: null == clientMetadata ? _self._clientMetadata : clientMetadata // ignore: cast_nullable_to_non_nullable
as Map<String, String>,
  ));
}


}

// dart format on
