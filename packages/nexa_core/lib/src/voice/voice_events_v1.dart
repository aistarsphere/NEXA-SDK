import 'dart:collection';
import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:meta/meta.dart';
import 'package:nexa_core/src/transport/realtime_voice_transport.dart';
import 'package:nexa_core/src/voice/voice_grant.dart';
import 'package:pinenacl/ed25519.dart' as nacl;

/// One verified agent event of contract `nexa.voice.v1` (§5).
///
/// `occurred_at` is informational (agent wall clock) and `mono_ms` is a
/// per-process diagnostic clock: neither is used for ordering or freshness.
/// Ordering is by [seq] only.
@immutable
final class VoiceEventV1 {
  const VoiceEventV1({
    required this.type,
    required this.seq,
    required this.eventId,
    required this.voiceSessionId,
    required this.occurredAt,
    required this.fields,
    this.turnId,
  });

  final String type;
  final int seq;
  final String eventId;
  final String voiceSessionId;
  final String occurredAt;
  final String? turnId;

  /// The full decoded event object (type-specific fields included).
  final Map<String, Object?> fields;

  Object? operator [](String key) => fields[key];
}

/// Why a packet was rejected (event-verification.md steps 1–6).
enum VoiceEventRejection {
  /// Packet is not JSON, or `e`/`sig` are not strings, or bad hex.
  malformedEnvelope,

  /// `envelope.alg` differs from the pinned `events.alg`.
  algorithmMismatch,

  /// Signature does not verify with the session key.
  badSignature,

  /// `e` is not a JSON object or a required field is missing/invalid.
  malformedEvent,

  /// `v` is not `nexa.voice.v1`.
  unsupportedVersion,

  /// `type` is not a known v1 event type.
  unknownType,

  /// `voice_session_id` is another session's (cross-session replay).
  wrongSession,
}

/// Outcome of authenticating one sealed envelope.
sealed class VoiceEventVerdict {
  const VoiceEventVerdict();
}

final class VoiceEventAuthentic extends VoiceEventVerdict {
  const VoiceEventAuthentic(this.event);
  final VoiceEventV1 event;
}

final class VoiceEventRejected extends VoiceEventVerdict {
  const VoiceEventRejected(this.reason, [this.detail]);
  final VoiceEventRejection reason;
  final String? detail;

  @override
  String toString() =>
      'VoiceEventRejected(${reason.name}${detail == null ? '' : ': $detail'})';
}

/// Verifies sealed envelopes (`{"e": event-json-string, "sig": hex,
/// "alg": alg}`) exactly as `event-verification.md` v1.0.0 specifies:
///
/// 1. envelope is JSON; `e` and `sig` are strings;
/// 2. `envelope.alg` equals the algorithm pinned from the REST response;
/// 3. Ed25519 over `UTF8("nexa.voice.v1") + 0x00 + UTF8(e)` (legacy HMAC:
///    HMAC-SHA256 over `UTF8(e)` with the base64url-decoded key, no prefix);
/// 4. `sig` is lowercase hex of the 64-byte signature;
/// 5. only then `e` is parsed and validated (version, known type, required
///    fields, turn-scoped `turn_id`, typed fields);
/// 6. `voice_session_id` must equal this session's.
///
/// Sequence handling (step 7) is [VoiceReplayGuard]'s job. The packet
/// sender identity is never used as trust.
final class VoiceEventVerifier {
  VoiceEventVerifier({
    required this.voiceSessionId,
    required this.algorithm,
    required Uint8List key,
  }) : _key = key,
       _ed25519 = algorithm == VoiceEventAlgorithm.ed25519
           ? nacl.VerifyKey(key)
           : null {
    if (algorithm == VoiceEventAlgorithm.ed25519 && key.length != 32) {
      throw ArgumentError('Ed25519 public key must be 32 bytes');
    }
  }

  /// Builds a verifier from a grant (pinned alg + key + session id).
  factory VoiceEventVerifier.forGrant(VoiceGrant grant) => VoiceEventVerifier(
    voiceSessionId: grant.voiceSessionId,
    algorithm: grant.eventAlgorithm,
    key: grant.eventKey,
  );

  final String voiceSessionId;
  final VoiceEventAlgorithm algorithm;
  final Uint8List _key;
  final nacl.VerifyKey? _ed25519;

  static final _domain = utf8.encode('$voiceContractV1\u0000');

  /// Authenticates one envelope given as packet text (UTF-8 JSON).
  VoiceEventVerdict verifyText(String packet) {
    Object? decoded;
    try {
      decoded = jsonDecode(packet);
    } on FormatException {
      return const VoiceEventRejected(
        VoiceEventRejection.malformedEnvelope,
        'not json',
      );
    }
    return verify(decoded);
  }

  /// Authenticates one already-decoded envelope object.
  VoiceEventVerdict verify(Object? envelope) {
    if (envelope is! Map) {
      return const VoiceEventRejected(VoiceEventRejection.malformedEnvelope);
    }
    final e = envelope['e'];
    final sig = envelope['sig'];
    final alg = envelope['alg'];
    if (e is! String || sig is! String) {
      return const VoiceEventRejected(
        VoiceEventRejection.malformedEnvelope,
        'e/sig must be strings',
      );
    }
    if (alg != algorithm.wire) {
      return VoiceEventRejected(
        VoiceEventRejection.algorithmMismatch,
        '$alg != ${algorithm.wire}',
      );
    }
    final signature = _hexDecode(sig);
    if (signature == null) {
      return const VoiceEventRejected(
        VoiceEventRejection.malformedEnvelope,
        'sig is not lowercase hex',
      );
    }
    if (!_verifySignature(utf8.encode(e), signature)) {
      return const VoiceEventRejected(VoiceEventRejection.badSignature);
    }
    Object? event;
    try {
      event = jsonDecode(e);
    } on FormatException {
      return const VoiceEventRejected(
        VoiceEventRejection.malformedEvent,
        'e is not json',
      );
    }
    final parsed = parseEventV1(event);
    if (parsed is VoiceEventRejected) return parsed;
    final authentic = (parsed as VoiceEventAuthentic).event;
    if (authentic.voiceSessionId != voiceSessionId) {
      return const VoiceEventRejected(VoiceEventRejection.wrongSession);
    }
    return parsed;
  }

  bool _verifySignature(Uint8List message, Uint8List signature) {
    switch (algorithm) {
      case VoiceEventAlgorithm.ed25519:
        if (signature.length != 64) return false;
        try {
          return _ed25519!.verify(
            signature: nacl.Signature(signature),
            message: Uint8List.fromList([..._domain, ...message]),
          );
        } on Object {
          return false; // pinenacl throws on forgery
        }
      case VoiceEventAlgorithm.hmacSha256:
        final expected = Hmac(sha256, _key).convert(message).bytes;
        return _constantTimeEquals(expected, signature);
    }
  }

  static Uint8List? _hexDecode(String hex) {
    if (hex.isEmpty || hex.length.isOdd || hex != hex.toLowerCase()) {
      return null;
    }
    final out = Uint8List(hex.length ~/ 2);
    for (var i = 0; i < out.length; i++) {
      final b = int.tryParse(hex.substring(i * 2, i * 2 + 2), radix: 16);
      if (b == null) return null;
      out[i] = b;
    }
    return out;
  }

  static bool _constantTimeEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }
}

/// Event types of contract v1 and whether they are turn-scoped.
const _turnScoped = {
  'user_speech_started',
  'user_speech_ended',
  'transcript',
  'assistant_thinking',
  'assistant_audio_started',
  'assistant_text',
  'assistant_turn_ended',
  'interrupted',
  'model_busy',
  'model_available',
};

const _sessionScoped = {
  'session_state',
  'agent_ready',
  'quota_exceeded',
  'network_quality',
  'error',
  'session_ended',
};

/// `session_ended.reason` values allowed by the v1 schema.
const voiceSessionEndedReasons = {
  'user_ended',
  'quota_exceeded',
  'expired',
  'revoked',
  'server_ended',
  'agent_error',
  'idle_timeout',
};

/// Parses and validates the event JSON (step 5). Exposed for fixture tests;
/// production code reaches it only through [VoiceEventVerifier.verify].
VoiceEventVerdict parseEventV1(Object? json) {
  if (json is! Map<String, Object?>) {
    return const VoiceEventRejected(VoiceEventRejection.malformedEvent);
  }
  if (json['v'] != voiceContractV1) {
    return VoiceEventRejected(
      VoiceEventRejection.unsupportedVersion,
      '${json['v']}',
    );
  }
  final type = json['type'];
  if (type is! String ||
      !(_turnScoped.contains(type) || _sessionScoped.contains(type))) {
    return VoiceEventRejected(VoiceEventRejection.unknownType, '$type');
  }
  final seq = json['seq'];
  final eventId = json['event_id'];
  final vsid = json['voice_session_id'];
  final occurredAt = json['occurred_at'];
  if (seq is! int || seq < 1) return _missing('seq');
  if (eventId is! String || eventId.isEmpty) return _missing('event_id');
  if (vsid is! String || vsid.isEmpty) return _missing('voice_session_id');
  if (occurredAt is! String) return _missing('occurred_at');
  final turnId = json['turn_id'];
  if (_turnScoped.contains(type) && (turnId is! String || turnId.isEmpty)) {
    return _missing('turn_id');
  }
  switch (type) {
    case 'transcript':
      if (json['is_final'] is! bool) return _missing('is_final');
      if (json['text'] is! String) return _missing('text');
    case 'assistant_text':
      if (json['text'] is! String) return _missing('text');
    case 'interrupted':
      if (json['cancel_id'] is! String) return _missing('cancel_id');
    case 'session_ended':
      if (!voiceSessionEndedReasons.contains(json['reason'])) {
        return _missing('reason');
      }
    case 'network_quality':
      if (json['weak'] is! bool) return _missing('weak');
    default:
      break;
  }
  return VoiceEventAuthentic(
    VoiceEventV1(
      type: type,
      seq: seq,
      eventId: eventId,
      voiceSessionId: vsid,
      occurredAt: occurredAt,
      turnId: turnId is String ? turnId : null,
      fields: Map.unmodifiable(json),
    ),
  );
}

VoiceEventRejected _missing(String field) =>
    VoiceEventRejected(VoiceEventRejection.malformedEvent, field);

/// What the replay guard decided.
enum VoiceReplayVerdict {
  /// Ready events (possibly including previously held ones) can be applied.
  apply,

  /// `seq <= lastApplied` or already held: dropped silently.
  duplicate,

  /// `seq > lastApplied + 1`: held back; the caller must repair the gap
  /// with the `resume` RPC. Nothing is applied past a gap.
  gap,
}

final class VoiceReplayResult {
  const VoiceReplayResult(this.verdict, this.ready);
  final VoiceReplayVerdict verdict;
  final List<VoiceEventV1> ready;
}

/// Step 7 of the verification spec: per-session, gapless `seq` ordering.
/// Applies each `seq` at most once, drops `seq <= lastApplied`, holds events
/// after a gap (up to [maxHeld], the backend replay buffer size) until the
/// gap is filled by `resume`.
final class VoiceReplayGuard {
  VoiceReplayGuard({this.maxHeld = 256});

  final int maxHeld;
  int _lastApplied = 0;
  final SplayTreeMap<int, VoiceEventV1> _held = SplayTreeMap();

  int get lastApplied => _lastApplied;
  bool get hasGap => _held.isNotEmpty;

  VoiceReplayResult accept(VoiceEventV1 event) {
    if (event.seq <= _lastApplied || _held.containsKey(event.seq)) {
      return const VoiceReplayResult(VoiceReplayVerdict.duplicate, []);
    }
    if (event.seq != _lastApplied + 1) {
      if (_held.length < maxHeld) _held[event.seq] = event;
      return const VoiceReplayResult(VoiceReplayVerdict.gap, []);
    }
    final ready = [event];
    _lastApplied = event.seq;
    while (_held.isNotEmpty && _held.firstKey() == _lastApplied + 1) {
      final next = _held.remove(_held.firstKey())!;
      ready.add(next);
      _lastApplied = next.seq;
    }
    return VoiceReplayResult(VoiceReplayVerdict.apply, ready);
  }

  /// When `resume` answers `covers: false` the buffer no longer reaches
  /// back: jump the cursor to the server's `last_seq`, rely on `state`, and
  /// release any held events that are now contiguous.
  List<VoiceEventV1> skipTo(int lastSeq) {
    if (lastSeq <= _lastApplied) return const [];
    _lastApplied = lastSeq;
    _held.removeWhere((seq, _) => seq <= lastSeq);
    final ready = <VoiceEventV1>[];
    while (_held.isNotEmpty && _held.firstKey() == _lastApplied + 1) {
      final next = _held.remove(_held.firstKey())!;
      ready.add(next);
      _lastApplied = next.seq;
    }
    return ready;
  }
}

/// Maps a verified v1 event onto the transport event family. Returns null
/// for events that carry no state change for the SDK (e.g. interim
/// captions are folded by the transport, `assistant_turn_ended` with
/// reason `interrupted`).
RealtimeVoiceEvent? realtimeEventFromV1(VoiceEventV1 e) {
  switch (e.type) {
    case 'agent_ready':
      return const RealtimeAgentReady();
    case 'session_state':
      return RealtimeSessionSnapshot(
        state: e['state']?.toString() ?? 'listening',
        lastSeq: e['last_seq'] is int ? e['last_seq']! as int : null,
      );
    case 'user_speech_started':
      return const RealtimeUserSpeechStarted();
    case 'user_speech_ended':
      return const RealtimeUserSpeechEnded();
    case 'transcript':
      return RealtimeTranscript(
        text: e['text']! as String,
        isFinal: e['is_final']! as bool,
      );
    case 'assistant_thinking':
      return const RealtimeAssistantThinking();
    case 'assistant_audio_started':
      return const RealtimeAssistantSpeakingStarted();
    case 'assistant_turn_ended':
      // After `interrupted` the old turn still sends its turn_ended; it
      // must not cause a second `listening` transition (matrix §A).
      if (e['reason'] == 'interrupted') return null;
      return const RealtimeAssistantSpeakingEnded();
    case 'interrupted':
      return const RealtimeInterrupted();
    case 'model_busy':
      final ms = e['estimated_wait_ms'];
      return RealtimeModelBusy(
        estimatedWait: ms is int ? Duration(milliseconds: ms) : null,
      );
    case 'model_available':
      return const RealtimeModelAvailable();
    case 'quota_exceeded':
      return RealtimeQuotaExceeded(
        e['quota_kind']?.toString() ?? 'voice_seconds',
      );
    case 'network_quality':
      return RealtimeNetworkQuality(weak: e['weak']! as bool);
    case 'error':
      return RealtimeAgentError(
        code: e['code']?.toString() ?? 'unknown',
        component: e['component']?.toString(),
        retryable: e['retryable'] == true,
      );
    case 'session_ended':
      return RealtimeSessionEnding(e['reason']! as String);
    case 'assistant_text':
      return null; // folded into captions by the transport (needs index)
    default:
      return null;
  }
}
