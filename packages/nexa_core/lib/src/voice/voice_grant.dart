import 'dart:convert';
import 'dart:typed_data';

import 'package:clock/clock.dart';
import 'package:meta/meta.dart';

/// Wire contract id of the NEXA voice API (`contract` field and every
/// event's `v`). Source: backend handoff 1.0.0 (`voice-contract-v1.md`).
const voiceContractV1 = 'nexa.voice.v1';

/// Event-signing algorithm announced in `events.alg` and pinned for the
/// whole session. There is no negotiation.
enum VoiceEventAlgorithm {
  /// Default: Ed25519, the grant carries a 32-byte public key.
  ed25519('ed25519'),

  /// Legacy, operator opt-in only: HMAC-SHA256, the grant carries `key`.
  hmacSha256('hmac-sha256');

  const VoiceEventAlgorithm(this.wire);
  final String wire;

  static VoiceEventAlgorithm? fromWire(String? value) {
    for (final a in values) {
      if (a.wire == value) return a;
    }
    return null;
  }
}

/// Scoped, short-lived credentials for one voice session, as returned by
/// `POST /v1/sdk/voice/sessions` (contract `nexa.voice.v1` §3.1).
///
/// Security: [participantToken] is a LiveKit join JWT for one room and one
/// identity (60 s by default). It is never logged ([toString] redacts it)
/// and never persisted. [eventKey] is the Ed25519 **public** key (or, in
/// legacy mode, the HMAC key) that authenticates agent events of this
/// session only.
@immutable
final class VoiceGrant {
  const VoiceGrant({
    required this.voiceSessionId,
    required this.liveKitUrl,
    required this.roomName,
    required this.participantIdentity,
    required this.participantToken,
    required this.tokenExpiresAt,
    required this.eventAlgorithm,
    required this.eventKey,
    required this.maxSeconds,
    this.contract = voiceContractV1,
    this.eventsTopic = 'nexa.voice.events',
    this.resumeRpc = 'nexa.voice.resume',
    this.reservedSeconds,
    this.reconnectGraceSeconds = 30,
    this.tokenRefreshPath,
    this.maxRefreshes = 30,
    this.joinDeadlineSeconds = 60,
    this.voicePath,
    this.tools = const VoiceToolsGrant(),
    this.voiceIdentity,
  });

  /// `voice_identity`: whether the user's own voice is used in this call.
  /// Null when the gateway does not report it.
  final VoiceIdentity? voiceIdentity;

  /// `voice_path`: `realtime|standard`.
  final String? voicePath;

  /// What the call got for tools (labeeb.sdk/1 `tools`).
  final VoiceToolsGrant tools;

  /// Allowed clock skew when comparing [tokenExpiresAt] (contract §5).
  static const tokenClockSkew = Duration(seconds: 60);

  final String voiceSessionId;
  final String contract;

  /// `livekit.url` (`wss://` in production; `ws://` only for local dev).
  final Uri liveKitUrl;

  /// `livekit.room`.
  final String roomName;

  /// `livekit.identity` — the client must join with exactly this identity.
  final String participantIdentity;

  /// `livekit.token`. Secret, short-lived.
  final String participantToken;

  /// `livekit.token_expires_at` (gateway wall clock, UTC).
  final DateTime tokenExpiresAt;

  /// `events.topic`.
  final String eventsTopic;

  /// `events.resume_rpc`.
  final String resumeRpc;

  /// `events.alg`, pinned.
  final VoiceEventAlgorithm eventAlgorithm;

  /// `events.public_key` (32 bytes) or, in legacy mode, `events.key`.
  final Uint8List eventKey;

  /// `limits.max_seconds`: how long the call may last.
  final int maxSeconds;

  /// `limits.reserved_seconds`.
  final int? reservedSeconds;

  /// `reconnect.grace_seconds`.
  final int reconnectGraceSeconds;

  /// `reconnect.token_refresh_path`.
  final String? tokenRefreshPath;

  /// `reconnect.max_refreshes`.
  final int maxRefreshes;

  /// `join_deadline_seconds`.
  final int joinDeadlineSeconds;

  /// The agent's identity in the room (contract §1:
  /// `nexa-agent-<voice_session_id>`).
  String get agentIdentity => 'nexa-agent-$voiceSessionId';

  /// Hard cap on the call as a duration.
  Duration get maxDuration => Duration(seconds: maxSeconds);

  /// True when the join token is past expiry beyond the allowed skew. A
  /// token within the window may still be refused by LiveKit; the SDK
  /// refreshes before any rejoin regardless.
  bool get isTokenExpired =>
      clock.now().isAfter(tokenExpiresAt.add(tokenClockSkew));

  /// A copy with the fields of a token-refresh response (`livekit.*`).
  VoiceGrant withRefreshedToken({
    required Uri liveKitUrl,
    required String roomName,
    required String participantIdentity,
    required String participantToken,
    required DateTime tokenExpiresAt,
  }) => VoiceGrant(
    voiceSessionId: voiceSessionId,
    contract: contract,
    liveKitUrl: liveKitUrl,
    roomName: roomName,
    participantIdentity: participantIdentity,
    participantToken: participantToken,
    tokenExpiresAt: tokenExpiresAt,
    eventsTopic: eventsTopic,
    resumeRpc: resumeRpc,
    eventAlgorithm: eventAlgorithm,
    eventKey: eventKey,
    maxSeconds: maxSeconds,
    reservedSeconds: reservedSeconds,
    reconnectGraceSeconds: reconnectGraceSeconds,
    tokenRefreshPath: tokenRefreshPath,
    maxRefreshes: maxRefreshes,
    joinDeadlineSeconds: joinDeadlineSeconds,
    voicePath: voicePath,
    tools: tools,
    voiceIdentity: voiceIdentity,
  );

  /// Decodes base64url without padding (as used for `events.public_key`).
  static Uint8List decodeBase64Url(String value) =>
      base64Url.decode(base64Url.normalize(value));

  @override
  String toString() =>
      'VoiceGrant(voiceSessionId: $voiceSessionId, room: $roomName, '
      'identity: $participantIdentity, tokenExpiresAt: $tokenExpiresAt, '
      'alg: ${eventAlgorithm.wire}, participantToken: <redacted>, '
      'eventKey: <redacted>)';
}

/// Authoritative server view of a voice session
/// (`GET /v1/sdk/voice/sessions/{id}` and the `DELETE` response, §3.3).
@immutable
final class VoiceSessionStatus {
  const VoiceSessionStatus({
    required this.voiceSessionId,
    required this.status,
    required this.agentState,
    this.endReason,
    this.maxSeconds,
    this.usedSeconds,
    this.remainingSeconds,
    this.languageTag,
  });

  final String voiceSessionId;

  /// `provisioning` | `active` | `ended`.
  final String status;

  /// `pending` | `dispatched` | `joined` | `unavailable` | `ended`.
  final String agentState;

  /// Null until ended. Known values (contract §7): `user_ended`,
  /// `room_closed`, `quota_exceeded`, `join_timeout`, `provision_failed`,
  /// `revoked`, `room_missing`, `agent_lost`, `agent_unavailable`. Unknown
  /// values must be treated as a generic end.
  final String? endReason;

  final int? maxSeconds;
  final int? usedSeconds;

  /// Present only while `status == active`.
  final int? remainingSeconds;
  final String? languageTag;

  bool get isEnded => status == 'ended';

  /// The agent vanished (`agent_lost`) or never came (`agent_unavailable`):
  /// the UI shows "voice unavailable, try again".
  bool get isAgentUnavailable =>
      agentState == 'unavailable' ||
      endReason == 'agent_lost' ||
      endReason == 'agent_unavailable';
}

/// The `tools` block of a voice session: whether tools are on and, if so,
/// the hidden chat session device tools are answered in.
@immutable
final class VoiceToolsGrant {
  const VoiceToolsGrant({
    this.enabled = false,
    this.sessionId,
    this.clientTools = const [],
    this.tools = const [],
    this.voicePath,
    this.reason,
  });

  factory VoiceToolsGrant.fromJson(Object? v) {
    if (v is! Map) return const VoiceToolsGrant();
    List<String> names(Object? l) => [
      for (final n in (l as List?) ?? const [])
        if (n is String) n,
    ];
    return VoiceToolsGrant(
      enabled: v['enabled'] == true,
      sessionId: v['session_id'] as String?,
      clientTools: names(v['client_tools']),
      tools: names(v['tools']),
      voicePath: v['voice_path'] as String?,
      reason: v['reason'] as String?,
    );
  }

  final bool enabled;

  /// `tools.session_id` (`ses_*`): where device tools are answered.
  final String? sessionId;
  final List<String> clientTools;
  final List<String> tools;
  final String? voicePath;

  /// Why tools are off: `not_requested|tools_disabled|scope_missing|
  /// conversation_required|no_tools_available`.
  final String? reason;
}

/// `voice_identity` of a voice session: `{applied, voice_id?, reason?}`.
/// The voice is chosen when the session starts; activating another voice
/// applies to the next session only.
@immutable
final class VoiceIdentity {
  const VoiceIdentity({required this.applied, this.voiceId, this.reason});

  static VoiceIdentity? fromJson(Object? v) => v is Map
      ? VoiceIdentity(
          applied: v['applied'] == true,
          voiceId: v['voice_id'] as String?,
          reason: v['reason'] as String?,
        )
      : null;

  final bool applied;
  final String? voiceId;

  /// Why it was not applied (server vocabulary, shown generically).
  final String? reason;
}
