import 'package:flutter_test/flutter_test.dart';
import 'package:nexa_assistant/nexa_assistant.dart';

void main() {
  NexaPhraseValidation v(String s, {Set<String> installed = const {}}) =>
      validateCustomPhrase(s, installed: installed);

  test('the shipped phrases are acceptable text', () {
    for (final p in ['يا أمير', 'أمير', 'عباس']) {
      // They are installed, so the only issue allowed is "already installed".
      final r = v(p, installed: {v(p).normalized});
      expect(
        r.issues.where((i) => i != NexaPhraseIssue.alreadyInstalled),
        isEmpty,
        reason: p,
      );
    }
    expect(v('يا أمير').ok, isTrue);
  });

  test('at least three user-perceived characters, not code units', () {
    expect(v('ab').issues, contains(NexaPhraseIssue.tooFewCharacters));
    expect(v('يا').issues, contains(NexaPhraseIssue.tooFewCharacters));
    // A letter with its diacritics is ONE character: «بِي» is two graphemes.
    expect(v('بِي').graphemes, 2);
    expect(v('بِي').issues, contains(NexaPhraseIssue.tooFewCharacters));
    // Three graphemes pass the length rule (and then need to pass the rest).
    expect(
      v('سلمان').issues,
      isNot(contains(NexaPhraseIssue.tooFewCharacters)),
    );
    expect(v('أَمِير').graphemes, 4);
  });

  test('diacritics, tatweel and alef variants do not change identity', () {
    expect(v('أَمِير').normalized, v('امير').normalized);
    expect(
      v('أمـــير').normalized,
      v('اإمير').normalized.replaceAll('اا', 'ا'),
    );
    expect(v('  يا   أمير ').normalized, 'يا امير');
    expect(
      v('أمير', installed: {v('امير').normalized}).issues,
      contains(NexaPhraseIssue.alreadyInstalled),
    );
  });

  test('digits, symbols, emoji and hidden controls are refused', () {
    expect(v('سلمان123').issues, contains(NexaPhraseIssue.invalidCharacters));
    expect(v('سلمان!').issues, contains(NexaPhraseIssue.invalidCharacters));
    expect(v('سلمان😀').issues, contains(NexaPhraseIssue.invalidCharacters));
    expect(v('سل\u202Eمان').issues, contains(NexaPhraseIssue.hiddenControls));
    expect(v('سل\u200Fمان').issues, contains(NexaPhraseIssue.hiddenControls));
  });

  test('one script per phrase', () {
    expect(v('سلمان hello').issues, contains(NexaPhraseIssue.mixedScripts));
    expect(
      v('computer jarvis').issues,
      isNot(contains(NexaPhraseIssue.mixedScripts)),
    );
  });

  test('length is limited by what the detector window can hold', () {
    expect(
      v('سلمان سلمان سلمان سلمان').issues,
      contains(NexaPhraseIssue.tooLong),
    );
    expect(v('ا' * 25).issues, contains(NexaPhraseIssue.tooLong));
    expect(v('يا سلمان').issues, isNot(contains(NexaPhraseIssue.tooLong)));
  });

  test('character count alone does not make a good wake word', () {
    // Plenty of characters, but one repeated sound and no structure.
    expect(v('هههههههه').issues, contains(NexaPhraseIssue.repeatedLetters));
    expect(v('اااااا').issues, contains(NexaPhraseIssue.repeatedLetters));
    // A very common word fires all day however long it is.
    expect(v('شكرا').issues, contains(NexaPhraseIssue.commonWord));
    expect(v('مرحبا').issues, contains(NexaPhraseIssue.commonWord));
    expect(v('السلام').issues, contains(NexaPhraseIssue.commonWord));
  });

  test('two syllables is allowed with a warning, one is refused', () {
    final w = v('عباس');
    expect(w.ok, isTrue);
    expect(w.syllables, 2);
    expect(w.warnings, contains(NexaPhraseWarning.short));
    expect(v('بحر').issues, contains(NexaPhraseIssue.tooFewSyllables));
    expect(v('يا سلمان').warnings, isNot(contains(NexaPhraseWarning.short)));
  });

  test('empty and whitespace', () {
    expect(v('').issues, [NexaPhraseIssue.empty]);
    expect(v('   ').issues, [NexaPhraseIssue.empty]);
  });
}
