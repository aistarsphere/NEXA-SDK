/// Inputs to the voice state machine. Produced by UI, transport, VAD,
/// permission handler and connectivity monitors; the machine does not care
/// which.
sealed class VoiceEvent {
  const VoiceEvent();
}

/// User tapped "start".
final class VoiceStartRequested extends VoiceEvent {
  const VoiceStartRequested();
}

/// Host reported the microphone permission outcome.
final class VoicePermissionResult extends VoiceEvent {
  const VoicePermissionResult({required this.granted});
  final bool granted;
}

/// Transport connected.
final class VoiceConnected extends VoiceEvent {
  const VoiceConnected();
}

/// Local or server VAD: user started talking.
final class VoiceUserSpeechStarted extends VoiceEvent {
  const VoiceUserSpeechStarted();
}

/// Local or server VAD: user stopped talking.
final class VoiceUserSpeechEnded extends VoiceEvent {
  const VoiceUserSpeechEnded();
}

/// Final transcript received.
final class VoiceTranscriptFinal extends VoiceEvent {
  const VoiceTranscriptFinal();
}

/// Assistant started generating.
final class VoiceAssistantThinking extends VoiceEvent {
  const VoiceAssistantThinking();
}

/// First assistant audio chunk arrived.
final class VoiceAssistantAudioStarted extends VoiceEvent {
  const VoiceAssistantAudioStarted();
}

/// Assistant finished its turn.
final class VoiceAssistantTurnEnded extends VoiceEvent {
  const VoiceAssistantTurnEnded();
}

/// Server acknowledged the barge-in.
final class VoiceInterruptAcknowledged extends VoiceEvent {
  const VoiceInterruptAcknowledged();
}

/// User toggled mute.
final class VoiceMuteToggled extends VoiceEvent {
  const VoiceMuteToggled({required this.muted});
  final bool muted;
}

/// Network quality changed.
final class VoiceNetworkQualityChanged extends VoiceEvent {
  const VoiceNetworkQualityChanged({required this.weak});
  final bool weak;
}

/// Transport dropped.
final class VoiceDisconnected extends VoiceEvent {
  const VoiceDisconnected({required this.willReconnect});
  final bool willReconnect;
}

/// Transport is attempting to reconnect.
final class VoiceReconnecting extends VoiceEvent {
  const VoiceReconnecting();
}

/// Server reported the model is saturated.
final class VoiceModelBusy extends VoiceEvent {
  const VoiceModelBusy();
}

/// Server reported the model is available again.
final class VoiceModelAvailable extends VoiceEvent {
  const VoiceModelAvailable();
}

/// Quota exhausted.
final class VoiceQuotaExceeded extends VoiceEvent {
  const VoiceQuotaExceeded();
}

/// User tapped "end" or the host disposed the SDK.
final class VoiceEndRequested extends VoiceEvent {
  const VoiceEndRequested();
}

/// Unrecoverable failure.
final class VoiceFailed extends VoiceEvent {
  const VoiceFailed(this.error);
  final Object error;
}

/// Returns the machine to idle after a terminal state.
final class VoiceReset extends VoiceEvent {
  const VoiceReset();
}
