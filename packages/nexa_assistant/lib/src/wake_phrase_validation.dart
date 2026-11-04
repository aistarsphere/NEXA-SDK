/// Rules a custom wake phrase must pass before anything is trained.
///
/// Passing means "worth trying", never "will be recognised": a phrase only
/// works once an acoustic model exists for it (see [NexaPhraseReadiness]).
library;

import 'package:characters/characters.dart';

/// Why a phrase was refused (codes the screen turns into Arabic/English text).
enum NexaPhraseIssue {
  empty,

  /// Fewer than three user-perceived characters (grapheme clusters).
  tooFewCharacters,

  /// Longer than the detector's window can hold.
  tooLong,

  /// Digits, symbols, emoji or control characters.
  invalidCharacters,

  /// Arabic and Latin letters mixed in one phrase.
  mixedScripts,

  /// Hidden bidirectional-control characters.
  hiddenControls,

  /// Too few syllables for the detector to tell it from speech.
  tooFewSyllables,

  /// A very common word that would fire all day.
  commonWord,

  /// One letter repeated, or a repeated sound.
  repeatedLetters,

  /// Already installed: select it instead.
  alreadyInstalled,
}

/// Soft warnings on a phrase that is allowed.
enum NexaPhraseWarning {
  /// Two syllables: more false activations than a longer phrase.
  short,

  /// Three or more words: easy to say differently each time.
  manyWords,
}

/// How far a phrase is from working.
enum NexaPhraseReadiness {
  /// An acoustic model is installed and was measured on this kind of device.
  validated,

  /// Installed, but measured only on synthetic speech (not yet on real recordings).
  experimental,

  /// The text is acceptable but needs a personal model trained from the
  /// person's own recordings first.
  requiresEnrollment,

  /// A personal model is being built.
  preparing,

  /// Cannot work (refused text, or the engine cannot build such a model).
  unsupported,
}

final class NexaPhraseValidation {
  const NexaPhraseValidation({
    required this.normalized,
    required this.issues,
    required this.warnings,
    required this.graphemes,
    required this.syllables,
  });

  /// The phrase the detector would be trained on (diacritics and tatweel
  /// removed, alef variants unified, spaces collapsed).
  final String normalized;
  final List<NexaPhraseIssue> issues;
  final List<NexaPhraseWarning> warnings;
  final int graphemes;

  /// A rough estimate; the real test is the recording.
  final int syllables;

  bool get ok => issues.isEmpty;
}

/// Limits of the current engine: a one-and-a-quarter second window.
const maxPhraseGraphemes = 20;
const maxPhraseWords = 3;
const minPhraseGraphemes = 3;
const minPhraseSyllables = 2;

const _commonWords = {
  'نعم',
  'لا',
  'شكرا',
  'مرحبا',
  'اهلا',
  'السلام',
  'الله',
  'ماشي',
  'اوكي',
  'تمام',
  'طيب',
  'هلا',
  'يلا',
  'ايوه',
  'اي',
  'ليش',
  'شنو',
  'وين',
  'هذا',
  'هذه',
  'في',
  'من',
  'على',
  'الى',
  'يا',
  'انا',
  'انت',
  'هو',
  'هي',
};

bool _isArabicLetter(int c) =>
    (c >= 0x0621 && c <= 0x063A) ||
    (c >= 0x0641 && c <= 0x064A) ||
    (c >= 0x066E && c <= 0x06D3);

bool _isDiacritic(int c) =>
    (c >= 0x064B && c <= 0x065F) || c == 0x0670 || (c >= 0x06D6 && c <= 0x06ED);

bool _isLatin(int c) => (c >= 0x41 && c <= 0x5A) || (c >= 0x61 && c <= 0x7A);

bool _isBidiControl(int c) =>
    c == 0x200E ||
    c == 0x200F ||
    (c >= 0x202A && c <= 0x202E) ||
    (c >= 0x2066 && c <= 0x2069) ||
    c == 0x200B ||
    c == 0x200C ||
    c == 0x200D ||
    c == 0xFEFF;

String _unifyArabic(String s) => s
    .replaceAll(RegExp('[أإآٱ]'), 'ا')
    .replaceAll('ى', 'ي')
    .replaceAll('ة', 'ه');

/// Validates [input]; [installed] are the normalized forms already shipped.
NexaPhraseValidation validateCustomPhrase(
  String input, {
  Set<String> installed = const {},
}) {
  final issues = <NexaPhraseIssue>[];
  final warnings = <NexaPhraseWarning>[];

  final collapsed = input.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (collapsed.isEmpty) {
    return const NexaPhraseValidation(
      normalized: '',
      issues: [NexaPhraseIssue.empty],
      warnings: [],
      graphemes: 0,
      syllables: 0,
    );
  }

  final runes = collapsed.runes.toList();
  if (runes.any(_isBidiControl)) issues.add(NexaPhraseIssue.hiddenControls);
  final visible = runes.where((c) => !_isBidiControl(c));
  var arabic = 0;
  var latin = 0;
  var bad = false;
  for (final c in visible) {
    if (c == 0x20 || c == 0x640 || _isDiacritic(c)) continue;
    if (_isArabicLetter(c)) {
      arabic++;
    } else if (_isLatin(c)) {
      latin++;
    } else {
      bad = true;
    }
  }
  if (bad) issues.add(NexaPhraseIssue.invalidCharacters);
  if (arabic > 0 && latin > 0) issues.add(NexaPhraseIssue.mixedScripts);

  // User-perceived characters: a letter with its diacritics is one.
  final graphemes = collapsed
      .replaceAll(' ', '')
      .replaceAll('ـ', '')
      .characters
      .length;
  if (graphemes < minPhraseGraphemes) {
    issues.add(NexaPhraseIssue.tooFewCharacters);
  }
  if (graphemes > maxPhraseGraphemes) issues.add(NexaPhraseIssue.tooLong);
  final words = collapsed.split(' ');
  if (words.length > maxPhraseWords) issues.add(NexaPhraseIssue.tooLong);

  final stripped = collapsed.runes
      .where((c) => !_isDiacritic(c) && c != 0x640 && !_isBidiControl(c))
      .map(String.fromCharCode)
      .join();
  final normalized = _unifyArabic(stripped).toLowerCase();

  final letters = normalized.replaceAll(' ', '');
  if (letters.isNotEmpty && RegExp('^(.)\\1+\$').hasMatch(letters) ||
      RegExp('(.)\\1{2,}').hasMatch(letters)) {
    issues.add(NexaPhraseIssue.repeatedLetters);
  }
  final nwords = normalized.split(' ');
  if (nwords.length == 1 && _commonWords.contains(nwords.first) ||
      nwords.every(_commonWords.contains)) {
    issues.add(NexaPhraseIssue.commonWord);
  }
  if (installed.contains(normalized)) {
    issues.add(NexaPhraseIssue.alreadyInstalled);
  }

  // Syllable estimate: each long-vowel letter is a nucleus; consonants that
  // are left over share a short vowel about two to a syllable.
  const vowels = {'\u0627', '\u0648', '\u064A'};
  final nv = letters.split('').where(vowels.contains).length;
  final syllables = latin > 0
      ? (letters.length / 2.5).round().clamp(1, 20)
      : (nv + (letters.length - 2 * nv).clamp(0, 99) ~/ 2).clamp(1, 20);
  if (syllables < minPhraseSyllables) {
    issues.add(NexaPhraseIssue.tooFewSyllables);
  }
  if (issues.isEmpty) {
    if (syllables == minPhraseSyllables) warnings.add(NexaPhraseWarning.short);
    if (words.length >= 3) warnings.add(NexaPhraseWarning.manyWords);
  }

  return NexaPhraseValidation(
    normalized: normalized,
    issues: issues,
    warnings: warnings,
    graphemes: graphemes,
    syllables: syllables,
  );
}
