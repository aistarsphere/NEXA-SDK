import 'package:clock/clock.dart';
import 'package:meta/meta.dart';

/// Scoped, short-lived credentials for one live voice session, issued by
/// the NEXA gateway after it has authorised the chat session and checked the
/// tenant's voice quota.
///
/// **STATUS: PROPOSED (SDK-side model).** The backend's `nexa-integration`
/// provisioning response was not available when this was written; the
/// `GatewayVoiceProvisioner` maps the wire payload onto this model in one
/// place so that field names can be realigned without touching the voice
/// controller or UI. See `docs/contracts/nexa-voice-provisioning.proposed.md`.
///
/// Security: [participantToken] is a LiveKit *participant* JWT scoped to one
/// room with publish/subscribe grants only. It is never a LiveKit API key or
/// secret, never a tenant key, and never a GPU Manager credential. The SDK
/// keeps it in memory for the lifetime of the voice session only.
@immutable
final class VoiceGrant {
  const VoiceGrant({
    required this.voiceSessionId,
    required this.liveKitUrl,
    required this.participantToken,
    required this.roomName,
    required this.participantIdentity,
    required this.expiresAt,
    this.agentIdentity,
    this.eventVerificationKey,
    this.eventSignatureAlgorithm,
    this.maxDuration,
  });

  /// Gateway-side id of the voice session (not the chat session id).
  final String voiceSessionId;

  /// `wss://` (or `ws://` in development) LiveKit signalling URL.
  final Uri liveKitUrl;

  /// Room-scoped LiveKit participant JWT. Treated as opaque.
  final String participantToken;

  final String roomName;

  /// Identity the gateway assigned to this device in the room.
  final String participantIdentity;

  /// Identity of the assistant participant, when the gateway pre-announces
  /// it. Used to attribute remote audio and speaking state.
  final String? agentIdentity;

  /// Per-voice-session key used to verify signed agent events delivered as
  /// LiveKit data packets. Null means the gateway does not sign events
  /// (development only); the SDK then accepts unsigned events but reports
  /// them as unverified.
  final String? eventVerificationKey;

  /// Algorithm name announced by the gateway (e.g. `HMAC-SHA256`).
  final String? eventSignatureAlgorithm;

  /// Absolute expiry of [participantToken].
  final DateTime expiresAt;

  /// Hard cap on call length enforced by the gateway, when announced.
  final Duration? maxDuration;

  bool get isExpired => !clock.now().isBefore(expiresAt);

  @override
  String toString() =>
      'VoiceGrant(voiceSessionId: $voiceSessionId, room: $roomName, '
      'identity: $participantIdentity, expiresAt: $expiresAt, '
      'participantToken: <redacted>, eventVerificationKey: '
      '${eventVerificationKey == null ? 'none' : '<redacted>'})';
}
