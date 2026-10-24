import 'package:nexa_core/src/voice/voice_grant.dart';

/// Events emitted by a realtime voice transport.
///
/// With the LiveKit-based design the transport does **not** move audio
/// frames through Dart: capture and playback happen inside the WebRTC
/// engine. The transport therefore reports *what is happening* (connection,
/// who is speaking, transcripts, agent signals) and the voice controller
/// feeds these into `VoiceSessionMachine`.
///
/// Agent-originated events (`RealtimeAgent*`, transcripts, thinking,
/// interrupted, model busy, quota) arrive as signed data packets and are
/// only surfaced after `VoiceEventVerifier` accepted them. Rejected packets
/// surface as [RealtimeEventRejected] for diagnostics and never change state.
sealed class RealtimeVoiceEvent {
  const RealtimeVoiceEvent();
}

/// Room joined **and** the agent handshake succeeded (contract v1 §8: the
/// `resume` RPC answered, or a verified `agent_ready` / `session_state`
/// arrived). Emitted again after every successful rejoin.
final class RealtimeConnected extends RealtimeVoiceEvent {
  const RealtimeConnected();
}

/// Verified `agent_ready`: the agent pipeline is up for this session.
final class RealtimeAgentReady extends RealtimeVoiceEvent {
  const RealtimeAgentReady();
}

/// Verified `session_state` snapshot (pushed on every (re)join) or the
/// `state` of a `resume` RPC answer. [state] is a server state string
/// (`listening`, `user_speaking`, `thinking`, `ai_speaking`, ...).
final class RealtimeSessionSnapshot extends RealtimeVoiceEvent {
  const RealtimeSessionSnapshot({required this.state, this.lastSeq});
  final String state;
  final int? lastSeq;
}

/// Verified agent `error{code, component, retryable}`.
final class RealtimeAgentError extends RealtimeVoiceEvent {
  const RealtimeAgentError({
    required this.code,
    required this.retryable,
    this.component,
  });
  final String code;
  final String? component;
  final bool retryable;
}

/// The `resume` handshake kept failing for the whole handshake window
/// (~25 s): the agent is gone. The controller asks the gateway (`GET`).
final class RealtimeAgentUnresponsive extends RealtimeVoiceEvent {
  const RealtimeAgentUnresponsive();
}

/// The engine lost the connection and is retrying on its own.
final class RealtimeReconnecting extends RealtimeVoiceEvent {
  const RealtimeReconnecting();
}

/// The assistant participant joined the room.
final class RealtimeAgentJoined extends RealtimeVoiceEvent {
  const RealtimeAgentJoined(this.identity);
  final String identity;
}

/// A remote audio track from the assistant was subscribed (true) or
/// unsubscribed (false). This is the engine-level proof that agent audio is
/// being received and played; it is independent of agent-signed events.
final class RealtimeAgentAudioTrack extends RealtimeVoiceEvent {
  const RealtimeAgentAudioTrack({required this.subscribed});
  final bool subscribed;
}

/// The assistant participant left the room.
final class RealtimeAgentLeft extends RealtimeVoiceEvent {
  const RealtimeAgentLeft(this.identity);
  final String identity;
}

/// Local participant started speaking (engine audio-level detection or
/// server VAD relayed by the agent).
final class RealtimeUserSpeechStarted extends RealtimeVoiceEvent {
  const RealtimeUserSpeechStarted();
}

/// Local participant stopped speaking.
final class RealtimeUserSpeechEnded extends RealtimeVoiceEvent {
  const RealtimeUserSpeechEnded();
}

/// Partial or final transcript of the user's speech.
final class RealtimeTranscript extends RealtimeVoiceEvent {
  const RealtimeTranscript({required this.text, required this.isFinal});
  final String text;
  final bool isFinal;
}

/// Partial or final caption of the assistant's speech.
final class RealtimeAssistantTranscript extends RealtimeVoiceEvent {
  const RealtimeAssistantTranscript({
    required this.text,
    required this.isFinal,
  });
  final String text;
  final bool isFinal;
}

/// Assistant is generating a reply (no audio yet).
final class RealtimeAssistantThinking extends RealtimeVoiceEvent {
  const RealtimeAssistantThinking();
}

/// Assistant audio is now audible (remote track active / agent signal).
final class RealtimeAssistantSpeakingStarted extends RealtimeVoiceEvent {
  const RealtimeAssistantSpeakingStarted();
}

/// Assistant finished speaking the current turn.
final class RealtimeAssistantSpeakingEnded extends RealtimeVoiceEvent {
  const RealtimeAssistantSpeakingEnded();
}

/// Server acknowledged a barge-in; playback must stop immediately.
final class RealtimeInterrupted extends RealtimeVoiceEvent {
  const RealtimeInterrupted();
}

/// Model/queue is saturated; the UI shows "model busy".
final class RealtimeModelBusy extends RealtimeVoiceEvent {
  const RealtimeModelBusy({this.estimatedWait});
  final Duration? estimatedWait;
}

/// Model available again after [RealtimeModelBusy].
final class RealtimeModelAvailable extends RealtimeVoiceEvent {
  const RealtimeModelAvailable();
}

/// Quota exhausted; the gateway will close the session.
final class RealtimeQuotaExceeded extends RealtimeVoiceEvent {
  const RealtimeQuotaExceeded(this.quotaKind);
  final String quotaKind;
}

/// Gateway announced the session is ending (max duration, agent shutdown).
final class RealtimeSessionEnding extends RealtimeVoiceEvent {
  const RealtimeSessionEnding(this.reason);
  final String reason;
}

/// Network quality changed. [weak] true means degraded.
final class RealtimeNetworkQuality extends RealtimeVoiceEvent {
  const RealtimeNetworkQuality({required this.weak, this.rttMs});
  final bool weak;
  final int? rttMs;
}

/// Transport disconnected. [willReconnect] signals the engine will retry.
final class RealtimeDisconnected extends RealtimeVoiceEvent {
  const RealtimeDisconnected({required this.willReconnect, this.reason});
  final bool willReconnect;
  final String? reason;
}

/// A data packet was dropped by the verifier (bad signature, replay, stale,
/// wrong session). Diagnostic only; never changes voice state.
final class RealtimeEventRejected extends RealtimeVoiceEvent {
  const RealtimeEventRejected(this.reason);
  final String reason;
}

/// Unrecoverable failure.
final class RealtimeFailed extends RealtimeVoiceEvent {
  const RealtimeFailed(this.error);
  final Object error;
}

/// Transport-independent realtime voice contract.
///
/// Implementations:
/// * `LiveKitVoiceTransport` (package `nexa_realtime`) - real WebRTC room via
///   the official LiveKit Flutter SDK.
/// * `MockRealtimeVoiceTransport` (nexa_core/testing) - in-memory, scripted.
///
/// The transport never provisions credentials itself: it receives a
/// [VoiceGrant] produced by the gateway through `VoiceProvisioner`.
/// Calling [connect] again with a refreshed grant (same identity) rejoins
/// and resumes from the last applied event `seq`.
abstract interface class RealtimeVoiceTransport {
  /// Joins the room described by [grant]. Completes once connected.
  Future<void> connect(VoiceGrant grant);

  /// Transport and (verified) agent events.
  Stream<RealtimeVoiceEvent> get events;

  /// Enables or disables publishing the microphone track. Disabling is the
  /// mute implementation; the track stays published but silent-muted.
  Future<void> setMicrophoneEnabled({required bool enabled});

  /// Whether the microphone track is currently enabled.
  bool get isMicrophoneEnabled;

  /// Local barge-in only. Contract v1 has **no** interrupt command: the
  /// agent detects barge-in from the microphone and confirms with
  /// `interrupted`. Implementations must not send anything to the server.
  Future<void> interrupt();

  /// Leaves the room. Safe to call when not connected.
  Future<void> disconnect();

  /// Releases engine resources. The transport is unusable afterwards.
  Future<void> dispose();
}
