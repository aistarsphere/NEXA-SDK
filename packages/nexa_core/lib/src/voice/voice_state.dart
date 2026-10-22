/// States of the live voice session. Mirrors the approved UI states.
enum VoiceState {
  idle,
  connecting,
  listening,
  userSpeaking,
  transcribing,
  thinking,
  aiSpeaking,
  bargeIn,
  muted,
  weakNetwork,
  disconnected,
  reconnecting,
  modelBusy,
  microphoneDenied,
  quotaExceeded,
  ended;

  /// States in which the microphone is capturing.
  bool get isCapturing =>
      this == listening ||
      this == userSpeaking ||
      this == bargeIn ||
      this == weakNetwork;

  /// States in which assistant audio is playing.
  bool get isPlaying => this == aiSpeaking;

  /// True for states no event can leave except `reset`.
  bool get isTerminal =>
      this == ended || this == microphoneDenied || this == quotaExceeded;
}
