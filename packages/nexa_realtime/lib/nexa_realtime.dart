/// NEXA realtime voice transport over the official LiveKit Flutter SDK.
///
/// Kept separate from `nexa_core` because it brings native WebRTC
/// dependencies; `nexa_sdk` depends on it to offer `NexaClient.voice`.
library;

export 'src/livekit_audio_setup.dart';
export 'src/livekit_voice_transport.dart';
