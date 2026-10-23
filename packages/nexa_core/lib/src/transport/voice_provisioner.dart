import 'package:nexa_core/src/ids/ids.dart';
import 'package:nexa_core/src/voice/voice_grant.dart';

/// Obtains scoped voice credentials from the NEXA gateway for an active chat
/// session and relays client intents the gateway must know about.
///
/// **STATUS: PROPOSED.** Implemented by `GatewayVoiceProvisioner` (nexa_sdk)
/// against `POST /v1/sdk/sessions/{id}/voice` of the reference gateway;
/// the production `nexa-integration` surface must be mapped here once it is
/// available. The SDK never talks to LiveKit's server API or holds API keys.
abstract interface class VoiceProvisioner {
  /// Requests a room-scoped grant. Throws `CapabilityNotGrantedException`
  /// when `liveVoice` was not granted, `QuotaExceededException` when the
  /// voice quota is exhausted, `AuthenticationException` /
  /// `SessionExpiredException` for credential problems.
  Future<VoiceGrant> provision(SessionId sessionId);

  /// Tells the gateway about a client intent (`interrupt`). Best effort.
  Future<void> sendIntent(SessionId sessionId, String type);

  /// Ends the voice session server-side. Idempotent.
  Future<void> end(SessionId sessionId);
}
