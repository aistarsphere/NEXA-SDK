import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:nexa_core/src/config/nexa_capability.dart';
import 'package:nexa_core/src/config/nexa_environment.dart';
import 'package:nexa_core/src/config/nexa_event_delivery.dart';
import 'package:nexa_core/src/errors/nexa_exception.dart';

part 'nexa_config.freezed.dart';

/// Immutable configuration supplied by the host application at initialisation.
///
/// Security notes:
/// * [applicationId] is a **public** identifier of the SDK integration. It is
///   never treated as proof of authorisation. Authorisation comes exclusively
///   from the server-issued session credential (see `NexaAuthProvider`).
/// * There is deliberately no field for an API key, tenant secret or provider
///   credential. Those must stay on the host's backend.
@freezed
abstract class NexaConfig with _$NexaConfig {
  const NexaConfig._();

  /// Creates a configuration. Call [validate] (done automatically by the SDK
  /// on initialisation) to surface mistakes early.
  const factory NexaConfig({
    /// Public SDK application identifier (e.g. `app_8f3e...`).
    required String applicationId,

    /// Base URI of the NEXA gateway, e.g. `https://gw.staging.nexa.example`.
    required Uri gatewayBaseUri,

    /// Target environment. Defaults to production.
    @Default(NexaEnvironment.production) NexaEnvironment environment,

    /// BCP-47 language tag for the SDK UI. Supported: `en`, `ar`.
    @Default('en') String languageTag,

    /// Capabilities the host wants enabled. Grants are decided by the gateway.
    @Default({NexaCapability.textChat})
    Set<NexaCapability> requestedCapabilities,

    /// HTTP connect timeout.
    @Default(Duration(seconds: 10)) Duration connectTimeout,

    /// HTTP receive timeout for non-streaming calls.
    @Default(Duration(seconds: 30)) Duration receiveTimeout,

    /// Event delivery mechanism. Server-Sent Events by default; long-polling
    /// for networks that cannot keep a streaming response open.
    @Default(NexaEventDelivery.serverSentEvents)
    NexaEventDelivery eventDelivery,

    /// Base delay for reconnect back-off (doubles per attempt, capped) and
    /// the pause between long-poll requests.
    @Default(Duration(milliseconds: 750)) Duration eventPollInterval,

    /// How many automatic reconnects the chat attempts after a transient
    /// event-stream failure before asking the user to retry.
    @Default(5) int maxReconnectAttempts,

    /// Opaque metadata echoed to the gateway for support/diagnostics
    /// (e.g. host app version). Never put secrets here.
    @Default(<String, String>{}) Map<String, String> clientMetadata,
  }) = _NexaConfig;

  /// Languages the SDK UI ships localisations for.
  static const supportedLanguageTags = {'en', 'ar'};

  /// Throws [ConfigurationException] if the configuration is unusable.
  void validate() {
    if (applicationId.trim().isEmpty) {
      throw const ConfigurationException('applicationId must not be empty.');
    }
    if (!gatewayBaseUri.hasScheme || gatewayBaseUri.host.isEmpty) {
      throw ConfigurationException(
        'gatewayBaseUri must be absolute, got "$gatewayBaseUri".',
      );
    }
    if (environment == NexaEnvironment.production &&
        gatewayBaseUri.scheme != 'https') {
      throw const ConfigurationException(
        'Production gateway must be reached over https.',
      );
    }
    if (!supportedLanguageTags.contains(languageTag)) {
      throw ConfigurationException(
        'Unsupported languageTag "$languageTag". '
        'Supported: ${supportedLanguageTags.join(', ')}.',
      );
    }
    for (final entry in clientMetadata.entries) {
      final lower = entry.key.toLowerCase();
      if (lower.contains('secret') ||
          lower.contains('token') ||
          lower.contains('key')) {
        throw ConfigurationException(
          'clientMetadata key "${entry.key}" looks like a credential. '
          'Secrets must never be placed in the SDK configuration.',
        );
      }
    }
  }
}
