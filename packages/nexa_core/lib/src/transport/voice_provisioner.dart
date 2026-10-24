import 'package:nexa_core/src/ids/ids.dart';
import 'package:nexa_core/src/voice/voice_grant.dart';

/// The four SDK calls of the NEXA voice API (contract `nexa.voice.v1` §3,
/// backend handoff 1.0.0). Implemented by `GatewayVoiceProvisioner`
/// (nexa_sdk). The SDK never talks to LiveKit's server API or holds API keys.
abstract interface class VoiceProvisioner {
  /// `POST /v1/sdk/voice/sessions`. Returns only after the agent joined
  /// the room. Throws a `NexaException`; notably `ServerException` with
  /// `serverCode: 'voice_unavailable'` and a `retryAfter` when no agent
  /// could be provided (nothing was created).
  Future<VoiceGrant> create({
    required String languageTag,
    SessionId? chatSessionId,
  });

  /// `POST /v1/sdk/voice/sessions/{id}/token`: fresh join token for the
  /// same identity. Throws `VoiceSessionOverException` when the session is
  /// over (`410 voice_session_ended`) or the refresh budget is used up
  /// (`429 rate_limited`, `retryable: false`).
  Future<VoiceGrant> refreshToken(VoiceGrant grant);

  /// `GET /v1/sdk/voice/sessions/{id}`: authoritative status. Call it after
  /// any disconnect before choosing between "ended" and "reconnect".
  Future<VoiceSessionStatus> status(String voiceSessionId);

  /// `DELETE /v1/sdk/voice/sessions/{id}` (idempotent). Must be called on
  /// every exit path. Returns the final status, or null when the call could
  /// not be made (network); never throws.
  Future<VoiceSessionStatus?> end(String voiceSessionId);
}

/// The voice session cannot be resumed: refresh answered `410` or the
/// refresh budget is exhausted. The caller should read [status] (or `GET`)
/// and stop.
final class VoiceSessionOverException implements Exception {
  const VoiceSessionOverException(this.code, [this.message]);

  /// `voice_session_ended` or `rate_limited`.
  final String code;
  final String? message;

  @override
  String toString() => 'VoiceSessionOverException($code)';
}
