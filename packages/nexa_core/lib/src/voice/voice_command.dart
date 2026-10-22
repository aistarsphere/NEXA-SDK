/// Side effects the orchestrator must perform after a transition. The state
/// machine itself never touches audio or network.
sealed class VoiceCommand {
  const VoiceCommand();
}

final class RequestMicrophonePermission extends VoiceCommand {
  const RequestMicrophonePermission();
}

final class ConnectTransport extends VoiceCommand {
  const ConnectTransport();
}

final class StartCapture extends VoiceCommand {
  const StartCapture();
}

final class StopCapture extends VoiceCommand {
  const StopCapture();
}

final class StartPlayback extends VoiceCommand {
  const StartPlayback();
}

final class StopPlayback extends VoiceCommand {
  const StopPlayback();
}

final class SendInterrupt extends VoiceCommand {
  const SendInterrupt();
}

final class SetTransportMuted extends VoiceCommand {
  const SetTransportMuted({required this.muted});
  final bool muted;
}

final class DisconnectTransport extends VoiceCommand {
  const DisconnectTransport();
}

/// Emit a diagnostic/analytics log line.
final class LogVoiceEvent extends VoiceCommand {
  const LogVoiceEvent(this.message);
  final String message;
}
