import 'package:meta/meta.dart';
import 'package:nexa_core/nexa_core.dart';

/// Snapshot of the live voice session exposed to hosts and to the capsule.
@immutable
final class NexaVoiceState {
  const NexaVoiceState({
    this.phase = VoiceState.idle,
    this.muted = false,
    this.transcript = const [],
    this.agentIdentity,
    this.agentPresent = false,
    this.agentAudioActive = false,
    this.eventsVerified = true,
    this.rejectedEvents = 0,
    this.error,
    this.endReason,
  });

  /// Machine state (see `VoiceState`).
  final VoiceState phase;

  /// Local microphone muted by the user.
  final bool muted;

  /// Live transcript, oldest first. Partial lines are replaced in place.
  final List<VoiceTranscriptEntry> transcript;

  final String? agentIdentity;
  final bool agentPresent;

  /// True while a remote audio track from the assistant is subscribed, i.e.
  /// agent audio is actually being received and played by the engine.
  final bool agentAudioActive;

  /// Agent events are always signature-verified under contract v1; kept
  /// for diagnostics and API stability.
  final bool eventsVerified;

  /// Count of agent packets dropped by the verifier (diagnostics).
  final int rejectedEvents;

  /// Last error to surface, if any.
  final NexaException? error;

  /// Why the call ended, when it did: `user`, `quota_exceeded`, `expired`,
  /// `microphone_denied`, `failed`, `agent_lost` / `agent_unavailable`, or
  /// `server:<end_reason>` for other server-side ends (contract §7).
  final String? endReason;

  bool get isActive =>
      phase != VoiceState.idle &&
      phase != VoiceState.ended &&
      phase != VoiceState.disconnected &&
      !phase.isTerminal;

  NexaVoiceState copyWith({
    VoiceState? phase,
    bool? muted,
    List<VoiceTranscriptEntry>? transcript,
    String? agentIdentity,
    bool? agentPresent,
    bool? agentAudioActive,
    bool? eventsVerified,
    int? rejectedEvents,
    NexaException? error,
    bool clearError = false,
    String? endReason,
    bool clearEndReason = false,
  }) => NexaVoiceState(
    phase: phase ?? this.phase,
    muted: muted ?? this.muted,
    transcript: transcript ?? this.transcript,
    agentIdentity: agentIdentity ?? this.agentIdentity,
    agentPresent: agentPresent ?? this.agentPresent,
    agentAudioActive: agentAudioActive ?? this.agentAudioActive,
    eventsVerified: eventsVerified ?? this.eventsVerified,
    rejectedEvents: rejectedEvents ?? this.rejectedEvents,
    error: clearError ? null : (error ?? this.error),
    endReason: clearEndReason ? null : (endReason ?? this.endReason),
  );
}

/// Typed events hosts can observe through `NexaVoiceController.events`.
sealed class NexaVoiceEvent {
  const NexaVoiceEvent(this.at);
  final DateTime at;
}

final class NexaVoicePhaseChanged extends NexaVoiceEvent {
  const NexaVoicePhaseChanged(super.at, {required this.from, required this.to});
  final VoiceState from;
  final VoiceState to;
}

final class NexaVoiceTranscriptUpdated extends NexaVoiceEvent {
  const NexaVoiceTranscriptUpdated(super.at, this.entry);
  final VoiceTranscriptEntry entry;
}

final class NexaVoiceAgentPresence extends NexaVoiceEvent {
  const NexaVoiceAgentPresence(
    super.at, {
    required this.identity,
    required this.present,
  });
  final String identity;
  final bool present;
}

final class NexaVoiceMuteChanged extends NexaVoiceEvent {
  const NexaVoiceMuteChanged(super.at, {required this.muted});
  final bool muted;
}

final class NexaVoiceErrorOccurred extends NexaVoiceEvent {
  const NexaVoiceErrorOccurred(super.at, this.error);
  final NexaException error;
}

/// An agent packet failed verification (replay, bad signature, stale...).
final class NexaVoiceEventRejected extends NexaVoiceEvent {
  const NexaVoiceEventRejected(super.at, this.reason);
  final String reason;
}

final class NexaVoiceEnded extends NexaVoiceEvent {
  const NexaVoiceEnded(super.at, this.reason);
  final String reason;
}

/// Host-configurable voice settings (the permitted knobs; everything else is
/// decided by the gateway).
@immutable
final class NexaVoiceOptions {
  const NexaVoiceOptions({
    this.startMuted = false,
    this.keepTranscript = true,
    this.maxTranscriptEntries = 50,
    this.allowLegacyHmac = false,
  });

  /// Join with the microphone muted.
  final bool startMuted;

  /// Keep a transcript in [NexaVoiceState.transcript].
  final bool keepTranscript;

  final int maxTranscriptEntries;

  /// Accept the backend's legacy `events.alg: "hmac-sha256"` mode. Off by
  /// default: the contract default is Ed25519 and the operator must enable
  /// legacy mode explicitly (security decision D2).
  final bool allowLegacyHmac;
}
