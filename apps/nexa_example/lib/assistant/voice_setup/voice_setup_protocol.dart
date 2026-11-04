/// The recording protocol of the guided voice setup. It is data, so the
/// screen, the tests and the offline evaluation agree on what was asked.
///
/// Design rules (from the brief): the owner is recorded saying the wake phrase
/// under many natural conditions; identity is learned from DIFFERENT
/// sentences so it is not tied to the wake phrase; real negatives and
/// background audio are included; consented guests give the stranger side.
library;

/// One thing the person is asked to say or do.
final class SetupPrompt {
  const SetupPrompt({
    required this.id,
    required this.kind,
    required this.tags,
    required this.textAr,
    required this.textEn,
    this.maxMs = 6000,
  });

  final String id;

  /// `wake`, `identity`, `negative` or `background`.
  final String kind;
  final List<String> tags;

  /// What to say (or do), shown large.
  final String textAr;
  final String textEn;
  final int maxMs;
}

/// A group of prompts sharing one condition, with its own instruction.
final class SetupStage {
  const SetupStage({
    required this.id,
    required this.titleAr,
    required this.titleEn,
    required this.hintAr,
    required this.hintEn,
    required this.prompts,
  });

  final String id;
  final String titleAr;
  final String titleEn;
  final String hintAr;
  final String hintEn;
  final List<SetupPrompt> prompts;

  String get kind => prompts.first.kind;
}

const _wake = 'يا أمير';

List<SetupPrompt> _repeat(
  String id,
  String kind,
  List<String> tags,
  String ar,
  String en,
  int n, {
  int maxMs = 6000,
}) => [
  for (var i = 1; i <= n; i++)
    SetupPrompt(
      id: '${id}_$i',
      kind: kind,
      tags: tags,
      textAr: ar,
      textEn: en,
      maxMs: maxMs,
    ),
];

/// Iraqi/Arabic sentences for identity (none contains the wake phrase).
const _identitySentences = [
  'شلونك اليوم وشنو أخبارك',
  'أريد أعرف الطقس بكرة في بغداد',
  'افتح الكاميرا وخذ لي صورة',
  'ذكرني بالاجتماع الساعة الخامسة',
  'اتصل بأبو حسين وكله وصلت',
  'شكد الساعة هسه',
  'ابحث لي عن مطعم قريب',
  'ما أكدر أسمعك زين، عيد مرة ثانية',
  'غير لون التطبيق إلى الأخضر',
  'اقرأ لي آخر الأخبار',
  'ضيف موعد عند الطبيب يوم الخميس',
  'شكراً جزيلاً على مساعدتك',
];

/// Things the owner says that must NOT wake the assistant.
const _negatives = [
  'يا لبيب',
  'يا أمين',
  'أمير',
  'يا أميرة',
  'يا سمير',
  'يا أمل',
  'يا أخي',
  'هلا والله',
  'شنو تسوي',
  'تعال هنا بسرعة',
  'الأمير سافر أمس',
  'مرحبا كيف حالك',
  'الله يسلمك',
  'خلينا نروح',
  'وين راح الولد',
  'الشاي جاهز',
  'يا محمد',
  'يا علي',
  'أريد أمير الكتب',
  'يا إمام',
];

SetupStage _identity(
  String id,
  String ar,
  String en,
  String hintAr,
  String hintEn,
  List<String> tags,
  List<int> sentences,
) => SetupStage(
  id: id,
  titleAr: ar,
  titleEn: en,
  hintAr: hintAr,
  hintEn: hintEn,
  prompts: [
    for (final i in sentences)
      SetupPrompt(
        id: '${id}_$i',
        kind: 'identity',
        tags: tags,
        textAr: _identitySentences[i],
        textEn: _identitySentences[i],
        maxMs: 8000,
      ),
  ],
);

/// The owner's protocol (about 15 minutes).
final List<SetupStage> ownerProtocol = [
  SetupStage(
    id: 'wake_normal',
    titleAr: 'صوتك الطبيعي',
    titleEn: 'Your normal voice',
    hintAr: 'قل «$_wake» كما تقولها عادة، على بعد ذراع من الهاتف.',
    hintEn: 'Say «$_wake» the way you normally do, an arm’s length away.',
    prompts: _repeat(
      'wake_normal',
      'wake',
      ['normal', 'near'],
      _wake,
      _wake,
      10,
    ),
  ),
  SetupStage(
    id: 'wake_quiet',
    titleAr: 'بصوت منخفض',
    titleEn: 'Quietly',
    hintAr: 'قلها بهدوء كأن أحدهم نائم قربك.',
    hintEn: 'Say it softly, as if someone is sleeping nearby.',
    prompts: _repeat('wake_quiet', 'wake', ['quiet'], _wake, _wake, 6),
  ),
  SetupStage(
    id: 'wake_loud',
    titleAr: 'بصوت عالٍ',
    titleEn: 'Loudly',
    hintAr: 'قلها بصوت عالٍ كأنك تنادي من غرفة أخرى.',
    hintEn: 'Say it loudly, as if calling from another room.',
    prompts: _repeat('wake_loud', 'wake', ['loud'], _wake, _wake, 6),
  ),
  SetupStage(
    id: 'wake_fast',
    titleAr: 'بسرعة',
    titleEn: 'Quickly',
    hintAr: 'قلها بسرعة كأنك مستعجل.',
    hintEn: 'Say it fast, as if in a hurry.',
    prompts: _repeat('wake_fast', 'wake', ['fast'], _wake, _wake, 5),
  ),
  SetupStage(
    id: 'wake_slow',
    titleAr: 'ببطء',
    titleEn: 'Slowly',
    hintAr: 'قلها ببطء وبمدّ الحروف.',
    hintEn: 'Say it slowly, stretching it.',
    prompts: _repeat('wake_slow', 'wake', ['slow'], _wake, _wake, 5),
  ),
  SetupStage(
    id: 'wake_far',
    titleAr: 'من بعيد',
    titleEn: 'From a distance',
    hintAr: 'ضع الهاتف على الطاولة وابتعد متراً ونصفاً إلى مترين.',
    hintEn: 'Put the phone on a table and stand 1.5–2 m away.',
    prompts: _repeat('wake_far', 'wake', ['far'], _wake, _wake, 6),
  ),
  SetupStage(
    id: 'wake_close',
    titleAr: 'قريب جداً',
    titleEn: 'Very close',
    hintAr: 'قلها والهاتف قرب فمك (10 سم).',
    hintEn: 'Say it with the phone about 10 cm from your mouth.',
    prompts: _repeat('wake_close', 'wake', ['near', 'close'], _wake, _wake, 4),
  ),
  SetupStage(
    id: 'wake_noise',
    titleAr: 'مع ضجيج',
    titleEn: 'With background noise',
    hintAr: 'شغّل تلفزيوناً أو مروحة أو حديثاً في الخلفية ثم قلها.',
    hintEn: 'Turn on a TV, a fan or people talking, then say it.',
    prompts: _repeat('wake_noise', 'wake', ['noise'], _wake, _wake, 8),
  ),
  SetupStage(
    id: 'wake_variants',
    titleAr: 'نطق مختلف',
    titleEn: 'Different ways of saying it',
    hintAr: 'قل كما تقول طبيعياً: «يا أمير»، «هلا يا أمير»، «يا أمير شلونك».',
    hintEn:
        'Say it your natural ways: «يا أمير», «هلا يا أمير», «يا أمير شلونك».',
    prompts: [
      for (var i = 0; i < 6; i++)
        SetupPrompt(
          id: 'wake_variants_${i + 1}',
          kind: 'wake',
          tags: const ['normal', 'variant'],
          textAr: const [
            'يا أمير',
            'هلا يا أمير',
            'يا أمير شلونك',
            'يا أمير',
            'هلا يا أمير',
            'يا أمير شنو الأخبار',
          ][i],
          textEn: const [
            'يا أمير',
            'هلا يا أمير',
            'يا أمير شلونك',
            'يا أمير',
            'هلا يا أمير',
            'يا أمير شنو الأخبار',
          ][i],
          maxMs: 7000,
        ),
    ],
  ),
  SetupStage(
    id: 'wake_tone',
    titleAr: 'نبرات مختلفة',
    titleEn: 'Different moods',
    hintAr: 'مرة متعباً، مرة متحمساً، مرة وكأنك تسأل.',
    hintEn: 'Once tired, once excited, once as if asking.',
    prompts: _repeat('wake_tone', 'wake', ['tone'], _wake, _wake, 6),
  ),
  _identity(
    'id_normal',
    'جمل بصوتك الطبيعي',
    'Sentences, normal voice',
    'اقرأ كل جملة بطبيعتك. هذه الجمل لتعرّف أمير على صوتك، وليس على عبارة التنبيه.',
    'Read each sentence naturally. These teach AMEER your voice, not the wake phrase.',
    ['normal'],
    [0, 1, 2, 3, 4, 5, 6, 7],
  ),
  _identity(
    'id_quiet',
    'جمل بصوت منخفض',
    'Sentences, quietly',
    'بصوت منخفض.',
    'Quietly.',
    ['quiet'],
    [8, 9, 10, 11],
  ),
  _identity(
    'id_loud',
    'جمل بصوت عالٍ',
    'Sentences, loudly',
    'بصوت عالٍ.',
    'Loudly.',
    ['loud'],
    [0, 3, 5, 7],
  ),
  _identity(
    'id_far',
    'جمل من بعيد',
    'Sentences, from a distance',
    'الهاتف على الطاولة وأنت على بعد متر ونصف.',
    'Phone on the table, you 1.5 m away.',
    ['far'],
    [1, 2, 4, 6],
  ),
  _identity(
    'id_noise',
    'جمل مع ضجيج',
    'Sentences, with noise',
    'مع تلفزيون أو مروحة في الخلفية.',
    'With a TV or fan on.',
    ['noise'],
    [8, 9, 10, 11],
  ),
  SetupStage(
    id: 'negatives',
    titleAr: 'عبارات يجب ألّا توقظ أمير',
    titleEn: 'Phrases that must NOT wake AMEER',
    hintAr: 'اقرأ كل عبارة بطبيعتك. تساعد على قياس التنبيه الخاطئ.',
    hintEn: 'Say each one naturally. They measure false wakes.',
    prompts: [
      for (var i = 0; i < _negatives.length; i++)
        SetupPrompt(
          id: 'negatives_${i + 1}',
          kind: 'negative',
          tags: const ['negative'],
          textAr: _negatives[i],
          textEn: _negatives[i],
          maxMs: 5000,
        ),
    ],
  ),
  SetupStage(
    id: 'background',
    titleAr: 'أصوات الخلفية',
    titleEn: 'Background audio',
    hintAr:
        'لا تتكلم. شغّل تلفزيوناً أو حديثاً أو ضجيج المطبخ لمدة 30 ثانية '
        'في كل مرة. تُستعمل لقياس التنبيه الخاطئ.',
    hintEn:
        'Do not speak. Play a TV, people talking or kitchen noise for 30 s '
        'each time. Used to measure false wakes.',
    prompts: [
      for (var i = 1; i <= 3; i++)
        SetupPrompt(
          id: 'background_$i',
          kind: 'background',
          tags: const ['background'],
          textAr: const [
            'تلفزيون أو أخبار',
            'أشخاص يتحدثون',
            'ضجيج المنزل أو الشارع',
          ][i - 1],
          textEn: const [
            'TV or news',
            'People talking',
            'House or street noise',
          ][i - 1],
          maxMs: 30000,
        ),
    ],
  ),
];

/// The protocol for one consented guest (a stranger to the owner's voice).
List<SetupStage> guestProtocol() => [
  SetupStage(
    id: 'guest_wake',
    titleAr: 'الضيف يقول «يا أمير»',
    titleEn: 'Guest says «يا أمير»',
    hintAr: 'اطلب من الضيف أن يقولها بطبيعته، قريباً من الهاتف.',
    hintEn: 'Ask the guest to say it naturally, near the phone.',
    prompts: _repeat('guest_wake', 'wake', ['normal'], _wake, _wake, 10),
  ),
  SetupStage(
    id: 'guest_speech',
    titleAr: 'الضيف يقرأ جملاً',
    titleEn: 'Guest reads sentences',
    hintAr: 'اطلب من الضيف أن يقرأ كل جملة بطبيعته.',
    hintEn: 'Ask the guest to read each sentence naturally.',
    prompts: [
      for (var i = 0; i < 6; i++)
        SetupPrompt(
          id: 'guest_speech_${i + 1}',
          kind: 'identity',
          tags: const ['normal'],
          textAr: _identitySentences[i],
          textEn: _identitySentences[i],
          maxMs: 8000,
        ),
    ],
  ),
];

int totalPrompts(List<SetupStage> stages) =>
    stages.fold(0, (n, s) => n + s.prompts.length);
