import 'package:nexa_core/src/voice/voice_command.dart';
import 'package:nexa_core/src/voice/voice_event.dart';
import 'package:nexa_core/src/voice/voice_state.dart';

/// Result of a transition.
final class VoiceTransition {
  const VoiceTransition(this.state, [this.commands = const []]);

  final VoiceState state;
  final List<VoiceCommand> commands;
}

/// Pure, table-driven live voice state machine.
///
/// `(state, event) -> (state, commands)`. No timers, no I/O. The orchestrator
/// (nexa_sdk) executes commands against the audio capture, playback, VAD and
/// transport interfaces and feeds the outcomes back as events.
///
/// Interruption semantics:
/// * While `aiSpeaking`, `VoiceUserSpeechStarted` enters `bargeIn`: playback
///   stops locally **immediately** and `SendInterrupt` is issued. On
///   `VoiceInterruptAcknowledged` the machine returns to `userSpeaking`.
/// * `VoiceEndRequested` from any non-terminal state stops capture and
///   playback and disconnects.
///
/// Mute is modelled as a state that remembers it was listening; unmuting
/// resumes `listening`.
final class VoiceSessionMachine {
  const VoiceSessionMachine();

  /// Computes the next state and the commands to execute.
  VoiceTransition transition(VoiceState state, VoiceEvent event) {
    // Global events first.
    switch (event) {
      case VoiceReset():
        return const VoiceTransition(VoiceState.idle);
      case VoiceEndRequested():
        if (state == VoiceState.idle || state.isTerminal) {
          return VoiceTransition(
            state == VoiceState.idle ? state : VoiceState.ended,
          );
        }
        return const VoiceTransition(VoiceState.ended, [
          StopCapture(),
          StopPlayback(),
          DisconnectTransport(),
        ]);
      case VoiceQuotaExceeded():
        if (state == VoiceState.idle || state.isTerminal) {
          return VoiceTransition(state);
        }
        return const VoiceTransition(VoiceState.quotaExceeded, [
          StopCapture(),
          StopPlayback(),
          DisconnectTransport(),
        ]);
      case VoiceFailed(:final error):
        if (state == VoiceState.idle || state.isTerminal) {
          return VoiceTransition(state);
        }
        return VoiceTransition(VoiceState.disconnected, [
          const StopCapture(),
          const StopPlayback(),
          const DisconnectTransport(),
          LogVoiceEvent('voice failed: $error'),
        ]);
      default:
        break;
    }

    return switch (state) {
      VoiceState.idle => switch (event) {
        VoiceStartRequested() => const VoiceTransition(VoiceState.connecting, [
          RequestMicrophonePermission(),
        ]),
        _ => VoiceTransition(state),
      },
      VoiceState.connecting => switch (event) {
        VoicePermissionResult(granted: true) => const VoiceTransition(
          VoiceState.connecting,
          [ConnectTransport()],
        ),
        VoicePermissionResult(granted: false) => const VoiceTransition(
          VoiceState.microphoneDenied,
        ),
        VoiceConnected() => const VoiceTransition(VoiceState.listening, [
          StartCapture(),
        ]),
        VoiceModelBusy() => const VoiceTransition(VoiceState.modelBusy),
        VoiceDisconnected(willReconnect: true) => const VoiceTransition(
          VoiceState.reconnecting,
        ),
        VoiceDisconnected(willReconnect: false) => const VoiceTransition(
          VoiceState.disconnected,
        ),
        _ => VoiceTransition(state),
      },
      VoiceState.listening => _listeningLike(state, event),
      VoiceState.weakNetwork => _listeningLike(state, event),
      VoiceState.userSpeaking => switch (event) {
        VoiceUserSpeechEnded() => const VoiceTransition(
          VoiceState.transcribing,
        ),
        VoiceMuteToggled(muted: true) => const VoiceTransition(
          VoiceState.muted,
          [SetTransportMuted(muted: true)],
        ),
        VoiceNetworkQualityChanged(weak: true) => const VoiceTransition(
          VoiceState.weakNetwork,
        ),
        VoiceDisconnected(:final willReconnect) => _dropped(willReconnect),
        _ => VoiceTransition(state),
      },
      VoiceState.transcribing => switch (event) {
        VoiceTranscriptFinal() => const VoiceTransition(VoiceState.thinking),
        VoiceAssistantThinking() => const VoiceTransition(VoiceState.thinking),
        VoiceAssistantAudioStarted() => const VoiceTransition(
          VoiceState.aiSpeaking,
          [StartPlayback()],
        ),
        VoiceUserSpeechStarted() => const VoiceTransition(
          VoiceState.userSpeaking,
        ),
        VoiceDisconnected(:final willReconnect) => _dropped(willReconnect),
        _ => VoiceTransition(state),
      },
      VoiceState.thinking => switch (event) {
        VoiceAssistantAudioStarted() => const VoiceTransition(
          VoiceState.aiSpeaking,
          [StartPlayback()],
        ),
        VoiceAssistantTurnEnded() => const VoiceTransition(
          VoiceState.listening,
        ),
        VoiceModelBusy() => const VoiceTransition(VoiceState.modelBusy),
        VoiceUserSpeechStarted() => const VoiceTransition(VoiceState.bargeIn, [
          SendInterrupt(),
        ]),
        VoiceDisconnected(:final willReconnect) => _dropped(willReconnect),
        _ => VoiceTransition(state),
      },
      VoiceState.aiSpeaking => switch (event) {
        VoiceUserSpeechStarted() => const VoiceTransition(VoiceState.bargeIn, [
          StopPlayback(),
          SendInterrupt(),
        ]),
        VoiceAssistantTurnEnded() => const VoiceTransition(
          VoiceState.listening,
          [StopPlayback()],
        ),
        VoiceMuteToggled(muted: true) => const VoiceTransition(
          VoiceState.muted,
          [SetTransportMuted(muted: true)],
        ),
        VoiceNetworkQualityChanged(weak: true) => const VoiceTransition(
          VoiceState.weakNetwork,
          [StopPlayback()],
        ),
        VoiceDisconnected(:final willReconnect) => _dropped(willReconnect),
        _ => VoiceTransition(state),
      },
      VoiceState.bargeIn => switch (event) {
        VoiceInterruptAcknowledged() => const VoiceTransition(
          VoiceState.userSpeaking,
        ),
        VoiceUserSpeechEnded() => const VoiceTransition(
          VoiceState.transcribing,
        ),
        VoiceDisconnected(:final willReconnect) => _dropped(willReconnect),
        _ => VoiceTransition(state),
      },
      VoiceState.muted => switch (event) {
        VoiceMuteToggled(muted: false) => const VoiceTransition(
          VoiceState.listening,
          [SetTransportMuted(muted: false)],
        ),
        VoiceAssistantAudioStarted() => const VoiceTransition(
          VoiceState.muted,
          [StartPlayback()],
        ),
        VoiceAssistantTurnEnded() => const VoiceTransition(VoiceState.muted, [
          StopPlayback(),
        ]),
        VoiceDisconnected(:final willReconnect) => _dropped(willReconnect),
        _ => VoiceTransition(state),
      },
      VoiceState.reconnecting => switch (event) {
        VoiceConnected() => const VoiceTransition(VoiceState.listening, [
          StartCapture(),
        ]),
        VoiceDisconnected(willReconnect: false) => const VoiceTransition(
          VoiceState.disconnected,
        ),
        _ => VoiceTransition(state),
      },
      VoiceState.disconnected => switch (event) {
        VoiceStartRequested() => const VoiceTransition(VoiceState.connecting, [
          ConnectTransport(),
        ]),
        VoiceReconnecting() => const VoiceTransition(VoiceState.reconnecting),
        _ => VoiceTransition(state),
      },
      VoiceState.modelBusy => switch (event) {
        VoiceModelAvailable() => const VoiceTransition(VoiceState.listening),
        VoiceAssistantAudioStarted() => const VoiceTransition(
          VoiceState.aiSpeaking,
          [StartPlayback()],
        ),
        VoiceDisconnected(:final willReconnect) => _dropped(willReconnect),
        _ => VoiceTransition(state),
      },
      VoiceState.microphoneDenied ||
      VoiceState.quotaExceeded ||
      VoiceState.ended => VoiceTransition(state),
    };
  }

  VoiceTransition _listeningLike(VoiceState state, VoiceEvent event) =>
      switch (event) {
        VoiceUserSpeechStarted() => const VoiceTransition(
          VoiceState.userSpeaking,
        ),
        VoiceAssistantThinking() => const VoiceTransition(VoiceState.thinking),
        VoiceAssistantAudioStarted() => const VoiceTransition(
          VoiceState.aiSpeaking,
          [StartPlayback()],
        ),
        VoiceMuteToggled(muted: true) => const VoiceTransition(
          VoiceState.muted,
          [SetTransportMuted(muted: true)],
        ),
        VoiceNetworkQualityChanged(weak: true) => const VoiceTransition(
          VoiceState.weakNetwork,
        ),
        VoiceNetworkQualityChanged(weak: false) => const VoiceTransition(
          VoiceState.listening,
        ),
        VoiceModelBusy() => const VoiceTransition(VoiceState.modelBusy),
        VoiceDisconnected(:final willReconnect) => _dropped(willReconnect),
        _ => VoiceTransition(state),
      };

  VoiceTransition _dropped(bool willReconnect) => VoiceTransition(
    willReconnect ? VoiceState.reconnecting : VoiceState.disconnected,
    const [StopCapture(), StopPlayback()],
  );
}
