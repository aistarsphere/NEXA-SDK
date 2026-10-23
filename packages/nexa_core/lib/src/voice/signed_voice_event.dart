import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:crypto/crypto.dart';
import 'package:meta/meta.dart';
import 'package:nexa_core/src/transport/realtime_voice_transport.dart';

/// Wire form of an agent event delivered as a LiveKit data packet on topic
/// [topic].
///
/// **STATUS: PROPOSED.** The backend's actual signing scheme
/// (`docs/voice/security-review.md` in `nexa-integration`) was not available;
/// this is the SDK-side mechanism the reference gateway implements. Field
/// names are isolated here and in `VoiceEventVerifier` so they can be
/// realigned with the backend without touching the controller.
///
/// ```json
/// {"v":1,"type":"assistant_speaking_started","seq":7,
///  "voice_session_id":"vs_...","issued_at":1760000000000,
///  "payload":{...},"sig":"<base64url(HMAC-SHA256(key, canonical))>"}
/// ```
/// `canonical = "$v|$voiceSessionId|$seq|$type|$issuedAtMs|" +
///   jsonEncode(payload with keys sorted)`.
@immutable
final class SignedVoiceEvent {
  const SignedVoiceEvent({
    required this.version,
    required this.type,
    required this.sequence,
    required this.voiceSessionId,
    required this.issuedAtMs,
    required this.payload,
    this.signature,
  });

  /// LiveKit data-packet topic carrying these events.
  static const topic = 'nexa.voice';

  static const currentVersion = 1;

  final int version;
  final String type;
  final int sequence;
  final String voiceSessionId;

  /// Unix epoch milliseconds when the gateway/agent issued the event.
  final int issuedAtMs;
  final Map<String, Object?> payload;

  /// Base64url HMAC, absent when the gateway does not sign.
  final String? signature;

  /// Parses the wire JSON. Returns null when the envelope is unusable.
  static SignedVoiceEvent? tryParse(Object? json) {
    if (json is! Map<String, Object?>) return null;
    final version = json['v'];
    final type = json['type'];
    final seq = json['seq'];
    final vsid = json['voice_session_id'];
    final issued = json['issued_at'];
    final payload = json['payload'];
    final sig = json['sig'];
    if (version is! int ||
        type is! String ||
        seq is! int ||
        vsid is! String ||
        issued is! int ||
        (payload != null && payload is! Map<String, Object?>) ||
        (sig != null && sig is! String)) {
      return null;
    }
    return SignedVoiceEvent(
      version: version,
      type: type,
      sequence: seq,
      voiceSessionId: vsid,
      issuedAtMs: issued,
      payload: (payload as Map<String, Object?>?) ?? const {},
      signature: sig as String?,
    );
  }

  /// Deterministic string the signature is computed over.
  String canonical() =>
      '$version|$voiceSessionId|$sequence|$type|$issuedAtMs|'
      '${canonicalJson(payload)}';

  /// JSON with recursively sorted object keys and no whitespace.
  static String canonicalJson(Object? value) => jsonEncode(_sorted(value));

  static Object? _sorted(Object? value) {
    if (value is Map) {
      final keys = value.keys.map((k) => k.toString()).toList()..sort();
      return {for (final k in keys) k: _sorted(value[k])};
    }
    if (value is List) return value.map(_sorted).toList();
    return value;
  }

  /// Computes the base64url HMAC-SHA256 of [canonical] with [key]. Used by
  /// the verifier and by the reference gateway's signer (through tests).
  static String sign(String key, String canonical) => base64Url
      .encode(
        Hmac(sha256, utf8.encode(key)).convert(utf8.encode(canonical)).bytes,
      )
      .replaceAll('=', '');
}

/// Why a signed event was rejected.
enum VoiceEventRejection {
  malformed,
  unsupportedVersion,
  wrongSession,
  missingSignature,
  badSignature,
  duplicateOrStaleSequence,
  clockSkew,
}

/// Outcome of verification.
sealed class VoiceEventVerdict {
  const VoiceEventVerdict();
}

final class VoiceEventAccepted extends VoiceEventVerdict {
  const VoiceEventAccepted(this.event, {required this.verified});
  final SignedVoiceEvent event;

  /// False when accepted without a signature because no key was issued
  /// (development). The controller surfaces this in diagnostics.
  final bool verified;
}

final class VoiceEventRejected extends VoiceEventVerdict {
  const VoiceEventRejected(this.reason, [this.detail]);
  final VoiceEventRejection reason;
  final String? detail;
}

/// Verifies agent events for one voice session: signature (when a key was
/// issued), session binding, strictly increasing sequence (replay and
/// duplicate defence) and a clock-skew window (stale defence).
///
/// ## Threat model (document for human approval)
/// The verification key is delivered to the *client* in the voice grant.
/// Therefore:
/// * It proves an event was produced by a party holding the per-session key
///   (gateway/agent or this very client), not by an arbitrary room member.
/// * It does **not** make the client trustworthy to the server: the gateway
///   must never accept client-originated "events" as authorisation for
///   quota, billing or session decisions. The SDK only sends intents
///   (`interrupt`) and the server remains authoritative.
/// * Compromise scope is one voice session (key rotates per grant).
/// * Replay is bounded by the monotonic `seq`; staleness by [maxSkew].
/// * A missing key (development) downgrades to unverified acceptance, which
///   the controller reports so it is never mistaken for verified mode.
final class VoiceEventVerifier {
  VoiceEventVerifier({
    required this.voiceSessionId,
    this.key,
    this.maxSkew = const Duration(minutes: 2),
  });

  final String voiceSessionId;
  final String? key;
  final Duration maxSkew;

  int _lastSequence = 0;

  /// Highest accepted sequence.
  int get lastSequence => _lastSequence;

  VoiceEventVerdict verify(Object? json) {
    final event = SignedVoiceEvent.tryParse(json);
    if (event == null) {
      return const VoiceEventRejected(VoiceEventRejection.malformed);
    }
    if (event.version != SignedVoiceEvent.currentVersion) {
      return VoiceEventRejected(
        VoiceEventRejection.unsupportedVersion,
        'v${event.version}',
      );
    }
    if (event.voiceSessionId != voiceSessionId) {
      return const VoiceEventRejected(VoiceEventRejection.wrongSession);
    }
    final k = key;
    var verified = false;
    if (k != null) {
      final sig = event.signature;
      if (sig == null || sig.isEmpty) {
        return const VoiceEventRejected(VoiceEventRejection.missingSignature);
      }
      final expected = SignedVoiceEvent.sign(k, event.canonical());
      if (!_constantTimeEquals(expected, sig)) {
        return const VoiceEventRejected(VoiceEventRejection.badSignature);
      }
      verified = true;
    }
    if (event.sequence <= _lastSequence) {
      return VoiceEventRejected(
        VoiceEventRejection.duplicateOrStaleSequence,
        'seq ${event.sequence} <= $_lastSequence',
      );
    }
    final skew = clock.now().millisecondsSinceEpoch - event.issuedAtMs;
    if (skew.abs() > maxSkew.inMilliseconds) {
      return VoiceEventRejected(VoiceEventRejection.clockSkew, '${skew}ms');
    }
    _lastSequence = event.sequence;
    return VoiceEventAccepted(event, verified: verified);
  }

  static bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diff == 0;
  }
}

/// Maps an accepted agent event onto the transport event family. Returns
/// null for agent event types the SDK does not know (forward compatible).
RealtimeVoiceEvent? realtimeEventFromSigned(SignedVoiceEvent e) {
  final p = e.payload;
  switch (e.type) {
    case 'agent_joined':
      return RealtimeAgentJoined(p['identity']?.toString() ?? 'agent');
    case 'agent_left':
      return RealtimeAgentLeft(p['identity']?.toString() ?? 'agent');
    case 'user_speech_started':
      return const RealtimeUserSpeechStarted();
    case 'user_speech_ended':
      return const RealtimeUserSpeechEnded();
    case 'transcript':
      return RealtimeTranscript(
        text: p['text']?.toString() ?? '',
        isFinal: p['is_final'] == true,
      );
    case 'assistant_transcript':
      return RealtimeAssistantTranscript(
        text: p['text']?.toString() ?? '',
        isFinal: p['is_final'] == true,
      );
    case 'assistant_thinking':
      return const RealtimeAssistantThinking();
    case 'assistant_speaking_started':
      return const RealtimeAssistantSpeakingStarted();
    case 'assistant_speaking_ended':
      return const RealtimeAssistantSpeakingEnded();
    case 'interrupted':
      return const RealtimeInterrupted();
    case 'model_busy':
      final ms = p['estimated_wait_ms'];
      return RealtimeModelBusy(
        estimatedWait: ms is int ? Duration(milliseconds: ms) : null,
      );
    case 'model_available':
      return const RealtimeModelAvailable();
    case 'quota_exceeded':
      return RealtimeQuotaExceeded(p['quota_kind']?.toString() ?? 'voice');
    case 'session_ending':
      return RealtimeSessionEnding(p['reason']?.toString() ?? 'server');
    default:
      return null;
  }
}
