import 'package:meta/meta.dart';

/// Who said a transcript line.
enum VoiceSpeaker { user, assistant }

/// One line of the live transcript. Partial lines are replaced in place when
/// the final text arrives.
@immutable
final class VoiceTranscriptEntry {
  const VoiceTranscriptEntry({
    required this.speaker,
    required this.text,
    required this.isFinal,
    required this.at,
  });

  final VoiceSpeaker speaker;
  final String text;
  final bool isFinal;
  final DateTime at;

  VoiceTranscriptEntry copyWith({String? text, bool? isFinal}) =>
      VoiceTranscriptEntry(
        speaker: speaker,
        text: text ?? this.text,
        isFinal: isFinal ?? this.isFinal,
        at: at,
      );
}
