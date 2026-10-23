import 'package:livekit_client/livekit_client.dart';

/// Platform audio configuration for voice calls, kept apart from the
/// transport so the reusable logic has no platform branches.
///
/// * iOS: the LiveKit engine configures `AVAudioSession` for voice chat
///   (play-and-record, speaker output by default on phones).
/// * Android: `AudioManager` is put in communication mode by the engine.
/// * Hosts must declare `NSMicrophoneUsageDescription` (iOS) and
///   `RECORD_AUDIO` + `MODIFY_AUDIO_SETTINGS` (Android); see
///   `docs/voice/flutter-voice-sdk.md`.
abstract final class LiveKitAudioSetup {
  /// Capture options tuned for speech: mono, echo cancellation, noise
  /// suppression and auto gain so the assistant does not hear itself.
  static const AudioCaptureOptions capture = AudioCaptureOptions(
    echoCancellation: true,
    noiseSuppression: true,
    autoGainControl: true,
    highPassFilter: true,
    typingNoiseDetection: true,
  );

  /// Output options: loudspeaker on by default for a hands-free call.
  static const AudioOutputOptions output = AudioOutputOptions(speakerOn: true);

  /// Room options for a voice-only session: no video, no adaptive stream,
  /// no dynacast (nothing to simulcast).
  static RoomOptions roomOptions() => const RoomOptions(
    adaptiveStream: false,
    dynacast: false,
    defaultAudioCaptureOptions: capture,
    defaultAudioOutputOptions: output,
  );
}
