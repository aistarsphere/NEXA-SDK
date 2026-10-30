// The mute-mode API is marked experimental in livekit_client 2.13; it is the
// documented way to choose how iOS mutes the microphone. Re-check on upgrades.
// ignore_for_file: experimental_member_use

import 'package:flutter/foundation.dart';
import 'package:livekit_client/livekit_client.dart';

/// Platform audio configuration for voice calls, kept apart from the
/// transport so the reusable logic has no platform branches.
///
/// * iOS: the LiveKit engine configures `AVAudioSession` for voice chat
///   (play-and-record, speaker output by default on phones). [beginCall]
///   switches microphone muting to the engine's input mixer: with the
///   default voice-processing mute, the mute applied when a call ends
///   stayed in effect in the rebuilt engine, and every later call sent
///   silence (iPhone 15, iOS 27: mic level 0.0 and iOS "muted talker"
///   events from the second call on).
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

  /// After joining a call's room and before enabling the microphone (iOS
  /// only; no-op elsewhere). Earlier, the native audio device module does
  /// not exist yet and the call fails.
  static Future<void> beginCall() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return;
    final manager = AudioManager.instance;
    if (await manager.getMicrophoneMuteMode() !=
        MicrophoneMuteMode.inputMixer) {
      await manager.setMicrophoneMuteMode(MicrophoneMuteMode.inputMixer);
    }
  }

  /// Room options for a voice-only session: no video, no adaptive stream,
  /// no dynacast (nothing to simulcast).
  static RoomOptions roomOptions() => const RoomOptions(
    adaptiveStream: false,
    dynacast: false,
    defaultAudioCaptureOptions: capture,
    defaultAudioOutputOptions: output,
  );
}
