import 'package:flutter/widgets.dart';

/// Strings of the guided voice setup (Arabic and English).
final class VoiceSetupStrings {
  const VoiceSetupStrings._(this._ar);

  final bool _ar;

  static VoiceSetupStrings of(BuildContext context) =>
      VoiceSetupStrings._(Localizations.localeOf(context).languageCode == 'ar');

  static VoiceSetupStrings ofCode(String code) =>
      VoiceSetupStrings._(code == 'ar');

  String _t(String en, String ar) => _ar ? ar : en;

  String get title => _t('Voice setup', 'إعداد الصوت');
  String get entry => _t('Guided voice setup', 'إعداد صوتي موجّه');
  String get entrySubtitle => _t(
    'Teach AMEER your voice and the wake phrase (about 15 minutes)',
    'علّم أمير صوتك وعبارة التنبيه (حوالي 15 دقيقة)',
  );

  // Quick vs advanced.
  String get quickTitle =>
      _t('Quick setup (about 2 minutes)', 'إعداد سريع (حوالي دقيقتين)');
  String get advancedTitle => _t('Advanced calibration', 'معايرة متقدمة');
  String get advancedSubtitle => _t(
    'For testing: about 15 minutes, many conditions, optional guests',
    'للاختبار: حوالي 15 دقيقة، ظروف كثيرة، وضيوف اختيارياً',
  );
  String get backToQuick => _t('Back to quick setup', 'العودة للإعداد السريع');
  String get quickFinishHint => _t(
    'Needs the 15 short takes above.',
    'يحتاج إلى التسجيلات الخمسة عشر القصيرة أعلاه.',
  );
  String get consentLine1 => _t(
    'We record you saying «يا أمير» and a few sentences, about 2 minutes.',
    'نسجّل صوتك وأنت تقول «يا أمير» وبضع جمل، حوالي دقيقتين.',
  );
  String get consentLine2 => _t(
    'Your voice profile stays encrypted on this phone. Nothing is uploaded.',
    'يبقى ملفك الصوتي مشفّراً على هاتفك. لا يُرفع أي شيء.',
  );
  String get consentLine3 => _t(
    'You can delete it any time. It is not a password.',
    'تحذفه متى شئت. وهو ليس كلمة مرور.',
  );
  String get consentDetails => _t('Details', 'التفاصيل');

  // Consent.
  String get consentTitle =>
      _t('Before we record your voice', 'قبل أن نسجّل صوتك');
  String get consentWhat => _t('What is recorded', 'ما الذي يُسجَّل');
  String get consentWhatBody => _t(
    'You will be asked to say the wake phrase «يا أمير» in different ways '
        '(quiet, loud, far, with noise), read some sentences, say phrases that '
        'must not wake AMEER, and play background sound. About 15 minutes. A '
        'guest is recorded only if you confirm they agree.',
    'سيُطلب منك قول عبارة التنبيه «يا أمير» بطرق مختلفة (بصوت منخفض وعالٍ '
        'ومن بعيد ومع ضجيج)، وقراءة جمل، وقول عبارات يجب ألّا توقظ أمير، '
        'وتشغيل صوت خلفية. حوالي 15 دقيقة. لا يُسجَّل ضيف إلا إذا أكدت '
        'موافقته.',
  );
  String get consentStored =>
      _t('What is stored, and where', 'ما الذي يُخزَّن وأين');
  String get consentStoredBody => _t(
    'A voice profile (numbers that describe your voice) is stored encrypted '
        'on this phone only. If you choose to keep the recordings, they are '
        'saved in AMEER’s private folder on this phone so the wake model can '
        'be trained and tested with your real voice. The app never uploads '
        'them. Nothing biometric is written to logs.',
    'يُخزَّن ملف صوتي (أرقام تصف صوتك) مشفّراً على هذا الهاتف فقط. إذا '
        'اخترت الاحتفاظ بالتسجيلات فإنها تُحفظ في مجلد أمير الخاص على هذا '
        'الهاتف ليُدرَّب نموذج التنبيه ويُختبر بصوتك الحقيقي. لا يرفعها '
        'التطبيق إلى أي مكان. ولا يُكتب أي شيء بيومتري في السجلات.',
  );
  String get consentLimits => _t('What it is not', 'ما الذي لا يعنيه');
  String get consentLimitsBody => _t(
    'Voice recognition is not a password: a recording of you may fool it. '
        'It can make AMEER respond to you more than to others, but sensitive '
        'actions still ask for confirmation.',
    'التعرف على الصوت ليس كلمة مرور: قد يخدعه تسجيل لصوتك. يجعل أمير '
        'يستجيب لك أكثر من غيرك، لكن الإجراءات الحساسة تبقى تطلب تأكيداً.',
  );
  String get consentDelete => _t('You stay in control', 'أنت صاحب القرار');
  String get consentDeleteBody => _t(
    'You can delete all voice data at any time from this screen or from '
        'AMEER as assistant → Delete voice data. Nothing is recorded until you '
        'tap «Agree and start».',
    'يمكنك حذف كل بيانات الصوت في أي وقت من هذه الشاشة أو من أمير كمساعد '
        '← حذف بيانات الصوت. لا يُسجَّل شيء قبل أن تضغط «أوافق وأبدأ».',
  );
  String get consentCheck => _t(
    'I understand, and I agree that AMEER records my voice for this setup.',
    'فهمت، وأوافق على أن يسجّل أمير صوتي لهذا الإعداد.',
  );
  String get consentKeep => _t(
    'Keep my recordings on this phone to train the wake model',
    'احتفظ بتسجيلاتي على هذا الهاتف لتدريب نموذج التنبيه',
  );
  String get consentKeepHint => _t(
    'Off (recommended): only measurements and the profile are kept.',
    'مُطفأ (الأفضل): يُحفظ القياس والملف الصوتي فقط.',
  );
  String get agree => _t('Agree and start', 'أوافق وأبدأ');
  String get notNow => _t('Not now', 'ليس الآن');

  // Overview.
  String get overviewTitle => _t('Steps', 'الخطوات');
  String progress(int done, int total) =>
      _t('$done of $total', '$done من $total');
  String get continueLabel => _t('Continue', 'تابع');
  String get redo => _t('Record again', 'سجّل مجدداً');
  String get finish => _t('Build my voice profile', 'ابنِ ملفي الصوتي');
  String get finishHint => _t(
    'Needs at least 24 takes, 8 different sentences and 4 conditions.',
    'يحتاج 24 تسجيلاً على الأقل، و8 جمل مختلفة، و4 ظروف.',
  );
  String get addGuest => _t('Add a guest speaker', 'إضافة ضيف');
  String get addGuestHint => _t(
    'Strangers’ voices are needed to measure false accepts.',
    'أصوات الغرباء لازمة لقياس القبول الخاطئ.',
  );
  String get guestConfirmTitle =>
      _t('Is the guest agreeing?', 'هل الضيف موافق؟');
  String get guestConfirmBody => _t(
    'The guest is present, understands that their voice is recorded for '
        'testing, and agrees. No name is saved. Their data is deleted with '
        '«Delete voice data».',
    'الضيف حاضر ويفهم أن صوته يُسجَّل للاختبار ويوافق. لا يُحفظ أي اسم. '
        'تُحذف بياناته مع «حذف بيانات الصوت».',
  );
  String get confirm => _t('Yes, they agree', 'نعم، موافق');
  String get cancel => _t('Cancel', 'إلغاء');
  String get deleteData => _t('Delete voice data', 'حذف بيانات الصوت');
  String get deleteConfirm => _t(
    'Delete every recording, the voice profile and the consent? You will need to agree again to set up.',
    'حذف كل التسجيلات والملف الصوتي والموافقة؟ ستحتاج إلى الموافقة مجدداً للإعداد.',
  );
  String get deleted => _t('Voice data deleted', 'حُذفت بيانات الصوت');
  String keptClips(int n) =>
      _t('$n recordings kept on this phone', 'محفوظ على هذا الهاتف: $n تسجيل');

  // Recording.
  String get record => _t('Record', 'سجّل');
  String get listening => _t('Listening… speak now', 'أستمع… تكلّم الآن');
  String get next => _t('Next', 'التالي');
  String get backToSteps => _t('Back to steps', 'العودة إلى الخطوات');
  String get skip => _t('Skip', 'تخطَّ');
  String get tapToRecordBackground => _t(
    'Start the sound, then tap Record. 30 seconds are recorded.',
    'شغّل الصوت ثم اضغط تسجيل. يُسجَّل 30 ثانية.',
  );
  String get take => _t('Take', 'تسجيل');
  String get taken => _t('Saved', 'تم الحفظ');
  String level(double peak, double snr) => _t(
    'Level ${peak.toStringAsFixed(0)} dB · noise gap ${snr.toStringAsFixed(0)} dB',
    'المستوى ${peak.toStringAsFixed(0)} dB · الفرق عن الضجيج ${snr.toStringAsFixed(0)} dB',
  );

  // Live recording status.
  String get opening =>
      _t('Starting the microphone…', 'جارٍ تشغيل الميكروفون…');
  String get speakNow => _t('Speak now', 'تكلّم الآن');
  String get hearing => _t('I hear you…', 'أسمعك…');
  String get processing => _t('Finishing the take…', 'جارٍ إنهاء التسجيل…');
  String get captured =>
      _t('We captured your voice successfully', 'تم التقاط صوتك بنجاح');
  String get start => _t('Start', 'ابدأ');
  String get stop => _t('Stop', 'إيقاف');
  String get tryAgain => _t('Try again', 'حاول مجدداً');
  String get autoNote => _t(
    'After each good take the next step starts by itself.',
    'بعد كل تسجيل جيد تبدأ الخطوة التالية تلقائياً.',
  );

  String reason(String? r) => switch (r) {
    'consent_required' => _t(
      'Consent is needed first.',
      'الموافقة مطلوبة أولاً.',
    ),
    'permission_denied' => _t(
      'Allow the microphone for AMEER.',
      'اسمح لأمير باستخدام الميكروفون.',
    ),
    'busy' => _t(
      'Still recording. Wait a moment.',
      'ما زال التسجيل جارياً. انتظر لحظة.',
    ),
    'microphone_unavailable' => _t(
      'The microphone is busy. Close other apps and try again.',
      'الميكروفون مشغول. أغلق التطبيقات الأخرى وحاول.',
    ),
    'no_speech' => _t(
      'No speech detected. Move a little closer and try again.',
      'لم أسمع كلاماً. اقترب قليلاً وحاول مجدداً.',
    ),
    'too_short' => _t(
      'Please speak a little longer: say the whole phrase.',
      'تكلّم لفترة أطول قليلاً: قل العبارة كاملة.',
    ),
    'too_long' => _t(
      'The speech was longer than this step allows. Say only what is shown.',
      'كان الكلام أطول مما تسمح به هذه الخطوة. قل ما هو معروض فقط.',
    ),
    'interrupted' => _t(
      'The recording was interrupted. Try again.',
      'انقطع التسجيل. حاول مجدداً.',
    ),
    'too_quiet' => _t(
      'Too quiet for this step. A bit louder or closer.',
      'الصوت منخفض لهذه الخطوة. أعلى قليلاً أو أقرب.',
    ),
    'too_noisy' => _t(
      'Too much background noise. Move somewhere quieter.',
      'ضجيج الخلفية كثير. انتقل لمكان أهدأ.',
    ),
    'clipped' => _t(
      'Too loud: the sound distorts. Move back a little.',
      'الصوت عالٍ ويتشوّه. ابتعد قليلاً.',
    ),
    _ => _t('Something went wrong. Try again.', 'حدث خطأ. أعد المحاولة.'),
  };

  // Summary.
  String get summaryTitle => _t('Your voice profile', 'ملفك الصوتي');
  String get ownerOnlyNote => _t(
    'Measured only against your own voice (false rejections). Strangers were not measured: add a guest to measure false accepts.',
    'قيس بصوتك أنت فقط (الرفض الخاطئ). لم يُقَس الغرباء: أضف ضيفاً لقياس القبول الخاطئ.',
  );
  String get withGuestsNote => _t(
    'Measured against your voice and the guests’ voices.',
    'قيس بصوتك وبأصوات الضيوف.',
  );
  String get notSeparable => _t(
    'Warning: the guests’ scores overlap yours. These samples cannot separate you reliably.',
    'تحذير: درجات الضيوف تتداخل مع درجاتك. هذه العينات لا تفصل صوتك بموثوقية.',
  );
  String threshold(double t) => _t(
    'Acceptance threshold: ${t.toStringAsFixed(2)}',
    'عتبة القبول: ${t.toStringAsFixed(2)}',
  );
  String ownerScores(double p05, double med) => _t(
    'Your own scores: median ${med.toStringAsFixed(2)}, lowest 5% ${p05.toStringAsFixed(2)}',
    'درجاتك: الوسيط ${med.toStringAsFixed(2)}، أدنى 5% ${p05.toStringAsFixed(2)}',
  );
  String samples(int owner, int identity, int guests) => _t(
    '$owner of your takes ($identity sentences) and $guests guest takes were used.',
    'استُعمل $owner تسجيلاً لك ($identity جملة) و$guests تسجيل ضيف.',
  );
  String missing(String? reason, int have) => switch (reason) {
    'too_few_samples' => _t(
      'Not enough takes yet ($have). Record more steps.',
      'التسجيلات غير كافية ($have). سجّل خطوات أخرى.',
    ),
    'too_few_identity_sentences' => _t(
      'Record more sentences ($have so far): identity must not depend on the wake phrase.',
      'سجّل جملاً أكثر ($have حتى الآن): لا يجوز أن يعتمد التعرّف على عبارة التنبيه.',
    ),
    'too_few_conditions' => _t(
      'Record more conditions ($have so far): quiet, loud, far, noise.',
      'سجّل ظروفاً أكثر ($have حتى الآن): منخفض، عالٍ، بعيد، ضجيج.',
    ),
    _ => this.reason(reason),
  };
  String get done => _t('Done', 'تم');
}
