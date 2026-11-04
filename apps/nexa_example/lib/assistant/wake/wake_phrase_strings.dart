import 'package:flutter/widgets.dart';
import 'package:nexa_assistant/nexa_assistant.dart';

final class WakePhraseStrings {
  const WakePhraseStrings._(this._ar);
  final bool _ar;
  static WakePhraseStrings of(BuildContext c) =>
      WakePhraseStrings._(Localizations.localeOf(c).languageCode == 'ar');
  String _t(String en, String ar) => _ar ? ar : en;

  String get title => _t('Wake phrase', 'عبارة التنبيه');
  String get entrySubtitle => _t(
    'Choose the phrase AMEER listens for, and try it',
    'اختر العبارة التي يستمع لها أمير وجرّبها',
  );
  String get intro => _t(
    'Each phrase here has its own acoustic model on this phone. Choosing one switches the real detector, not just the label.',
    'لكل عبارة هنا نموذج صوتي خاص على هذا الهاتف. اختيارها يبدّل الكاشف الفعلي وليس الاسم فقط.',
  );
  String status(String s) => switch (s) {
    'validated' => _t('Validated on this phone', 'مؤكَّدة على هذا الهاتف'),
    _ => _t(
      'Experimental: trained on synthetic speech, not yet measured on real voices',
      'تجريبية: دُرّبت على كلام صناعي ولم تُقَس بعد على أصوات حقيقية',
    ),
  };
  String get selected => _t('In use', 'مستخدمة');
  String get use => _t('Use', 'استخدم');
  String get tryIt => _t('Try it (10 s)', 'جرّبها (10 ث)');
  String get listening => _t('Listening… say the phrase', 'أستمع… قل العبارة');
  String result(int n, double best, double thr) => n > 0
      ? _t(
          'Heard it $n time(s). Best score ${best.toStringAsFixed(2)}.',
          'سمعتها $n مرة. أفضل درجة ${best.toStringAsFixed(2)}.',
        )
      : _t(
          'Not heard. Best score ${best.toStringAsFixed(2)} (needs ${thr.toStringAsFixed(2)}). Try again or closer.',
          'لم أسمعها. أفضل درجة ${best.toStringAsFixed(2)} (المطلوب ${thr.toStringAsFixed(2)}). أعد المحاولة أو اقترب.',
        );
  String get micDenied =>
      _t('Allow the microphone first.', 'اسمح بالميكروفون أولاً.');

  String get customTitle => _t('Your own phrase', 'عبارتك الخاصة');
  String get customHint => _t(
    'Type a phrase (Arabic or Latin letters)',
    'اكتب عبارة (حروف عربية أو لاتينية)',
  );
  String get customStatusUnsupported => _t(
    'Not available yet: AMEER cannot build a model for a new phrase on this phone in this version. Only the installed phrases above can wake it. A phrase is never "recognised" just because it is typed.',
    'غير متاح بعد: لا يستطيع أمير بناء نموذج لعبارة جديدة على هذا الهاتف في هذا الإصدار. العبارات المثبّتة أعلاه فقط توقظه. لا تُعرف عبارة لمجرد كتابتها.',
  );
  String get customTextOk => _t(
    'The text is acceptable for a future personal model.',
    'النص مقبول لنموذج شخصي مستقبلاً.',
  );

  String issue(NexaPhraseIssue i) => switch (i) {
    NexaPhraseIssue.empty => _t('Type a phrase.', 'اكتب عبارة.'),
    NexaPhraseIssue.tooFewCharacters => _t(
      'Use at least three characters.',
      'استعمل ثلاثة أحرف على الأقل.',
    ),
    NexaPhraseIssue.tooLong => _t(
      'Too long: at most 20 characters and 3 words fit the detector window.',
      'طويلة جداً: يتسع الكاشف لـ 20 حرفاً و3 كلمات كحد أقصى.',
    ),
    NexaPhraseIssue.invalidCharacters => _t(
      'Letters only: no digits, symbols or emoji.',
      'حروف فقط: بلا أرقام أو رموز أو إيموجي.',
    ),
    NexaPhraseIssue.mixedScripts => _t(
      'Do not mix Arabic and Latin letters.',
      'لا تخلط الحروف العربية واللاتينية.',
    ),
    NexaPhraseIssue.hiddenControls => _t(
      'The text has hidden direction characters. Retype it.',
      'يحتوي النص على رموز اتجاه مخفية. أعد كتابته.',
    ),
    NexaPhraseIssue.tooFewSyllables => _t(
      'Too short to tell apart from ordinary speech: use at least two syllables.',
      'قصيرة جداً فلا تتميز عن الكلام العادي: استعمل مقطعين على الأقل.',
    ),
    NexaPhraseIssue.commonWord => _t(
      'A very common word would wake it all day.',
      'كلمة شائعة جداً ستوقظه طوال اليوم.',
    ),
    NexaPhraseIssue.repeatedLetters => _t(
      'A repeated letter or sound is not a distinctive phrase.',
      'تكرار حرف أو صوت ليس عبارة مميزة.',
    ),
    NexaPhraseIssue.alreadyInstalled => _t(
      'This phrase is already installed: choose it above.',
      'هذه العبارة مثبّتة بالفعل: اخترها من الأعلى.',
    ),
  };
  String warning(NexaPhraseWarning w) => switch (w) {
    NexaPhraseWarning.short => _t(
      'Two syllables: expect more accidental wakes than with a longer phrase.',
      'مقطعان: توقّع تنبيهات خاطئة أكثر من العبارة الأطول.',
    ),
    NexaPhraseWarning.manyWords => _t(
      'Three words: you may say it differently each time.',
      'ثلاث كلمات: قد تقولها بشكل مختلف كل مرة.',
    ),
  };
}
