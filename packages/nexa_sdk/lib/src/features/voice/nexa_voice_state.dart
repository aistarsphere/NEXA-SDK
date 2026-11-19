import 'package:meta/meta.dart';
import 'package:nexa_core/nexa_core.dart';

/// Speaking levels during a call, each 0..1 (see [NexaVoiceController.levels]).
@immutable
final class NexaVoiceLevels {
  const NexaVoiceLevels({this.local = 0, this.agent = 0});
  static const silent = NexaVoiceLevels();

  /// The user's microphone.
  final double local;

  /// The assistant's voice.
  final double agent;
}

/// Audio-quality counters of the current call, for QA and the debug panel
/// (see [NexaVoiceController.stats]). Reset when a call starts. No content.
@immutable
final class NexaVoiceCallStats {
  const NexaVoiceCallStats({
    this.interruptions = 0,
    this.speechStarts = 0,
    this.unmuteMs,
    this.muteMs,
  });

  /// Server-confirmed interruptions (`interrupted`) of the assistant. In
  /// echo test T1 the user is silent, so every one is a self-interruption.
  final int interruptions;

  /// `user_speech_started` events from the server (the server heard
  /// "speech"; while the user is silent, that is echo or noise).
  final int speechStarts;

  /// How long the last microphone enable / disable took in the engine.
  final int? unmuteMs;
  final int? muteMs;

  NexaVoiceCallStats copyWith({
    int? interruptions,
    int? speechStarts,
    int? unmuteMs,
    int? muteMs,
  }) => NexaVoiceCallStats(
    interruptions: interruptions ?? this.interruptions,
    speechStarts: speechStarts ?? this.speechStarts,
    unmuteMs: unmuteMs ?? this.unmuteMs,
    muteMs: muteMs ?? this.muteMs,
  );
}

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
    this.voiceIdentity,
    this.switchingVoice = false,
    this.interruptConfirmed = false,
    this.mutePending = false,
    this.phoneCallHold = false,
  });

  /// The voice of this call as the gateway reported it at start (null when
  /// not reported).
  final VoiceIdentity? voiceIdentity;

  /// Restarting the call so a newly activated voice applies.
  final bool switchingVoice;

  /// The agent confirmed (`interrupted`) that the user cut the assistant
  /// off. The UI says "Interrupted" only then; before that the user is
  /// merely heard (the interruption is the agent's decision).
  final bool interruptConfirmed;

  /// Machine state (see `VoiceState`).
  final VoiceState phase;

  /// Local microphone muted by the user.
  final bool muted;

  /// Live transcript, oldest first. Partial lines are replaced in place.
  final List<VoiceTranscriptEntry> transcript;

  final String? agentIdentity;
  final bool agentPresent;

  /// The user asked to mute while a sentence was still being finished: the
  /// microphone stays open for a short, bounded grace so the server can
  /// close that turn, then closes. [muted] already reads true.
  final bool mutePending;

  /// A phone call holds the audio: the microphone is off until it ends,
  /// then the user's own mute choice applies again.
  final bool phoneCallHold;

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
    VoiceIdentity? voiceIdentity,
    bool clearVoiceIdentity = false,
    bool? switchingVoice,
    bool? interruptConfirmed,
    bool? mutePending,
    bool? phoneCallHold,
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
    voiceIdentity: clearVoiceIdentity
        ? null
        : (voiceIdentity ?? this.voiceIdentity),
    switchingVoice: switchingVoice ?? this.switchingVoice,
    interruptConfirmed: interruptConfirmed ?? this.interruptConfirmed,
    mutePending: mutePending ?? this.mutePending,
    phoneCallHold: phoneCallHold ?? this.phoneCallHold,
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
    this.restartOnVoiceActivation = true,
    this.muteGrace = Duration.zero,
    this.backgroundGrace = const Duration(seconds: 25),
    this.holdOnPhoneCall = true,
    this.waitForInterruptConfirmation = true,
    this.speakingSilenceTimeout = const Duration(milliseconds: 2500),
    this.postCallReconcileDelays = const [
      Duration(milliseconds: 500),
      Duration(milliseconds: 2500),
    ],
  });

  /// How long the microphone stays open after Mute when the user was
  /// speaking, so the server hears the trailing silence and commits the
  /// turn (a muted track sends nothing, so the reply otherwise waits until
  /// the user unmutes: device test T-M07-01). Ends early when the reply
  /// starts. The default, [Duration.zero], mutes at once: Mute must stop
  /// the agent hearing anything (owner decision 2026-11-19); closing the
  /// cut-off sentence is the server's job (listening control).
  final Duration muteGrace;

  /// After `voice.profile.activate` succeeds during a call, end it and
  /// start a new one in the same conversation so the new voice applies.
  final bool restartOnVoiceActivation;

  /// How long a call may stay in the background when nothing holds it alive
  /// (see `NexaVoiceController.keepAliveInBackground`) before it is ended
  /// deliberately. Shorter than the server's reconnect grace (30 s) so the
  /// server is not left to its idle timeout.
  final Duration backgroundGrace;

  /// Turn the microphone off while a phone call holds the audio (detected
  /// from the platform audio mode on Android, CallKit on iOS) and back on
  /// afterwards. Off: phone calls are left to the OS.
  final bool holdOnPhoneCall;

  /// True (default): while the assistant speaks, the UI keeps "speaking"
  /// until the server confirms an interruption (`interrupted`); echo and
  /// noise do not look like one. False: speech shows "listening to you" at
  /// once (the earlier behaviour).
  final bool waitForInterruptConfirmation;

  /// Safety net for "speaking": when the assistant's audio has been silent
  /// this long and no server event arrived meanwhile, the call returns to
  /// "listening" (a lost `assistant_turn_ended` or `interrupted` must not
  /// leave the UI stuck). [Duration.zero] disables it.
  final Duration speakingSilenceTimeout;

  /// After a call ends the open chat refetches the conversation at each of
  /// these delays, so the spoken turns the gateway recorded show up (the
  /// last turn is persisted around the `DELETE`). Empty disables it.
  final List<Duration> postCallReconcileDelays;

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
