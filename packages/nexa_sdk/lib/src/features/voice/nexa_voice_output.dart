import 'package:nexa_realtime/nexa_realtime.dart';
import 'package:nexa_ui/nexa_ui.dart';

/// What the output button shows: a connected headset wins; otherwise the
/// user's loudspeaker / earpiece choice. Null without platform call audio.
NexaVoiceOutput? nexaVoiceOutputOf(NexaCallAudio? audio) {
  if (audio == null) return null;
  final s = audio.state.value;
  if (s.headset) return NexaVoiceOutput.headset;
  return s.speakerPreferred
      ? NexaVoiceOutput.speaker
      : NexaVoiceOutput.earpiece;
}

/// Loudspeaker ⇄ earpiece (with a headset connected this sets what is used
/// once it is removed).
Future<void> nexaToggleVoiceOutput(NexaCallAudio audio) =>
    audio.setSpeakerPreferred(!audio.state.value.speakerPreferred);
