import 'dart:typed_data';

import 'package:nexa_core/src/auth/session_credential.dart';
import 'package:nexa_core/src/ids/ids.dart';

/// PCM audio frame exchanged with the realtime transport.
final class AudioFrame {
  const AudioFrame({
    required this.pcm16,
    required this.sampleRateHz,
    required this.sequence,
  });

  /// 16-bit little-endian mono PCM.
  final Uint8List pcm16;
  final int sampleRateHz;

  /// Monotonic per-direction counter for loss detection.
  final int sequence;
}

/// Events emitted by the realtime voice transport.
///
/// **STATUS: PROPOSED.** No bidirectional low-latency voice endpoint exists in
/// the GPU Manager API (it is request/poll only). This contract describes
/// what the NEXA realtime gateway must provide; see
/// `docs/contracts/nexa-realtime-voice.proposed.md`.
sealed class RealtimeVoiceEvent {
  const RealtimeVoiceEvent();
}

/// Transport connected and the server is ready to receive audio.
final class RealtimeConnected extends RealtimeVoiceEvent {
  const RealtimeConnected();
}

/// Server-side VAD detected the user started speaking.
final class RealtimeUserSpeechStarted extends RealtimeVoiceEvent {
  const RealtimeUserSpeechStarted();
}

/// Server-side VAD detected the user stopped speaking.
final class RealtimeUserSpeechEnded extends RealtimeVoiceEvent {
  const RealtimeUserSpeechEnded();
}

/// Partial or final transcript of the user's speech.
final class RealtimeTranscript extends RealtimeVoiceEvent {
  const RealtimeTranscript({required this.text, required this.isFinal});
  final String text;
  final bool isFinal;
}

/// Assistant is generating a reply (no audio yet).
final class RealtimeAssistantThinking extends RealtimeVoiceEvent {
  const RealtimeAssistantThinking();
}

/// Assistant audio chunk to play.
final class RealtimeAssistantAudio extends RealtimeVoiceEvent {
  const RealtimeAssistantAudio(this.frame, {this.transcriptDelta});
  final AudioFrame frame;
  final String? transcriptDelta;
}

/// Assistant finished speaking the current turn.
final class RealtimeAssistantTurnEnded extends RealtimeVoiceEvent {
  const RealtimeAssistantTurnEnded();
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

/// Quota exhausted; server will close the session.
final class RealtimeQuotaExceeded extends RealtimeVoiceEvent {
  const RealtimeQuotaExceeded(this.quotaKind);
  final String quotaKind;
}

/// Network quality changed. [weak] true means degraded.
final class RealtimeNetworkQuality extends RealtimeVoiceEvent {
  const RealtimeNetworkQuality({required this.weak, this.rttMs});
  final bool weak;
  final int? rttMs;
}

/// Transport disconnected. [willReconnect] signals the transport will try again.
final class RealtimeDisconnected extends RealtimeVoiceEvent {
  const RealtimeDisconnected({required this.willReconnect, this.reason});
  final bool willReconnect;
  final String? reason;
}

/// Unrecoverable failure.
final class RealtimeFailed extends RealtimeVoiceEvent {
  const RealtimeFailed(this.error);
  final Object error;
}

/// Transport-independent realtime voice contract.
///
/// **STATUS: PROPOSED / MOCK ONLY.** The only implementation in this phase is
/// `MockRealtimeVoiceTransport`. A production implementation (WebSocket or
/// WebRTC) will live in a separate package once the gateway contract is
/// finalised, so platform-specific dependencies never leak into consumers
/// that only need text chat.
abstract interface class RealtimeVoiceTransport {
  /// Connects for [sessionId] using the session credential.
  Future<void> connect({
    required SessionId sessionId,
    required SessionCredential credential,
    required int sampleRateHz,
  });

  /// Server-to-client events.
  Stream<RealtimeVoiceEvent> get events;

  /// Uplink audio.
  void sendAudio(AudioFrame frame);

  /// User interrupted the assistant (barge-in).
  Future<void> interrupt();

  /// Tells the server to ignore uplink audio.
  Future<void> setMuted({required bool muted});

  /// Graceful disconnect.
  Future<void> disconnect();

  /// Releases resources.
  Future<void> dispose();
}
