import 'package:flutter/widgets.dart';
import 'package:nexa_assistant/nexa_assistant.dart';

/// Texts of "Set up my voice" (Arabic and English). No engineering words.
final class VoiceWizardStrings {
  const VoiceWizardStrings._(this._ar);
  final bool _ar;
  static VoiceWizardStrings of(BuildContext c) =>
      VoiceWizardStrings._(Localizations.localeOf(c).languageCode == 'ar');
  String _t(String en, String ar) => _ar ? ar : en;
  bool get ar => _ar;

  // Entry and status.
  String get title => _t('Voice recognition', 'التعرف على صوتي');
  String get setUp => _t('Set up my voice', 'إعداد صوتي');
  String get setUpBody => _t(
    'Two short sentences, about a minute. AMEER will recognise you more than other people.',
    'جملتان قصيرتان، حوالي دقيقة. سيتعرف أمير عليك أكثر من غيرك.',
  );
  String status(NexaEnrollState s) => switch (s) {
    NexaEnrollState.ready => _t('Ready', 'جاهز'),
    NexaEnrollState.improve => _t('Needs improvement', 'يحتاج إلى تحسين'),
    NexaEnrollState.more ||
    NexaEnrollState.enrolled => _t('Not finished', 'لم يكتمل'),
    NexaEnrollState.none => _t('Not configured', 'غير مُعدّ'),
  };
  String get readyNote => _t(
    'AMEER recognises your voice for the basics. This is not a password: sensitive actions still ask you.',
    'يتعرف أمير على صوتك للأمور الأساسية. هذا ليس كلمة مرور: الإجراءات الحساسة تسألك دائماً.',
  );
  String get improveNote => _t(
    'AMEER could not recognise your voice reliably yet. You can still tap to talk. Try again in a quieter place.',
    'لم يستطع أمير التعرف على صوتك بموثوقية بعد. يمكنك الضغط للتحدث. جرّب في مكان أهدأ.',
  );
  String get testMyVoice => _t('Test my voice', 'اختبار صوتي');
  String get reEnroll => _t('Set up again', 'إعادة الإعداد');
  String get delete => _t('Delete my voice profile', 'حذف ملفي الصوتي');
  String get onlyMyVoice =>
      _t('Respond only to my voice', 'الاستجابة لصوتي فقط');
  String get onlyMyVoiceBody => _t(
    'Reduces activations by other people. Not a lock.',
    'يقلل التنشيط من أشخاص آخرين. وليس قفلاً.',
  );
  String get deleteConfirm => _t(
    'Delete your voice profile and every voice sample from this phone? You can set it up again any time.',
    'حذف ملفك الصوتي وكل عينات الصوت من هذا الهاتف؟ يمكنك إعداده مجدداً في أي وقت.',
  );
  String get deleted => _t('Voice profile deleted', 'حُذف الملف الصوتي');
  String get cancel => _t('Cancel', 'إلغاء');
  String get notNow => _t('Not now', 'ليس الآن');

  // Consent.
  String get consentTitle => _t('Before we record', 'قبل أن نسجّل');
  String get consent1 => _t(
    'AMEER listens to you read two short sentences to learn how your voice sounds.',
    'يستمع أمير إليك وأنت تقرأ جملتين قصيرتين ليتعلم كيف يبدو صوتك.',
  );
  String get consent2 => _t(
    'Only a numeric voice profile is kept, encrypted on this phone. No recording is saved and nothing is uploaded.',
    'يُحفظ ملف صوتي رقمي فقط، مشفّراً على هذا الهاتف. لا يُحفظ أي تسجيل ولا يُرفع شيء.',
  );
  String get consent3 => _t(
    'It is not a password. You can delete it any time.',
    'وهو ليس كلمة مرور. وتحذفه في أي وقت.',
  );
  String get consentCheck => _t('I agree', 'أوافق');
  String get start => _t('Agree and start', 'أوافق وأبدأ');

  // Steps.
  String get step1 => _t('Record your voice', 'سجّل صوتك');
  String get step2 => _t('Verify', 'تحقّق');
  String get step3 => _t('Try the assistant', 'جرّب المساعد');
  String get read =>
      _t('Read this sentence naturally', 'اقرأ هذه الجملة بطبيعتك');
  String get readDifferent =>
      _t('Now read a different sentence', 'الآن اقرأ جملة مختلفة');
  String get readAnother =>
      _t('One more sentence, please', 'جملة أخرى من فضلك');
  String get record => _t('Record', 'سجّل');
  String get stop => _t('Stop', 'إيقاف');
  String get tryAgain => _t('Try again', 'حاول مجدداً');
  String get next => _t('Next', 'التالي');

  // Live recording states.
  String get preparing =>
      _t('Preparing the microphone…', 'جارٍ تجهيز الميكروفون…');
  String get speakNow => _t('Speak now', 'تكلّم الآن');
  String get hearing => _t('Listening…', 'أستمع…');
  String get checking => _t('Checking the recording…', 'جارٍ فحص التسجيل…');
  String get accepted =>
      _t('We captured your voice successfully', 'تم التقاط صوتك بنجاح');

  // Why more is needed.
  String more(String? reason) => switch (reason) {
    'different_voice' => _t(
      'That did not sound like the first sentence. Please read another one in your normal voice, in a quiet place.',
      'لم يبدُ هذا مثل الجملة الأولى. اقرأ جملة أخرى بصوتك الطبيعي في مكان هادئ.',
    ),
    _ => _t(
      'Not sure yet. One more sentence in your normal voice will help.',
      'لست متأكداً بعد. جملة أخرى بصوتك الطبيعي ستساعد.',
    ),
  };

  String problem(String? r) => switch (r) {
    'consent_required' => _t('Please agree first.', 'وافق أولاً من فضلك.'),
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
      'No speech detected. Move a little closer.',
      'لم أسمع كلاماً. اقترب قليلاً.',
    ),
    'too_short' => _t(
      'Please speak a little longer: read the whole sentence.',
      'تكلّم لفترة أطول قليلاً: اقرأ الجملة كاملة.',
    ),
    'too_long' => _t(
      'That was longer than needed. Read only the sentence shown.',
      'كان أطول من اللازم. اقرأ الجملة المعروضة فقط.',
    ),
    'too_noisy' => _t(
      'Too much background noise. Move somewhere quieter.',
      'ضجيج الخلفية كثير. انتقل لمكان أهدأ.',
    ),
    'too_quiet' => _t(
      'Too quiet. Speak a little louder or closer.',
      'الصوت منخفض. تكلّم أعلى قليلاً أو أقرب.',
    ),
    'clipped' => _t(
      'Too loud: the sound distorts. Move back a little.',
      'الصوت عالٍ ويتشوّه. ابتعد قليلاً.',
    ),
    'interrupted' => _t(
      'The recording was interrupted. Try again.',
      'انقطع التسجيل. حاول مجدداً.',
    ),
    'model_unavailable' => _t(
      'Voice recognition is not available on this build.',
      'التعرف على الصوت غير متاح في هذا الإصدار.',
    ),
    'not_enrolled' => _t(
      'Record the first sentence first.',
      'سجّل الجملة الأولى أولاً.',
    ),
    _ => _t(
      'Something went wrong. Try again; if it repeats, delete the voice profile and start over.',
      'حدث خطأ. أعد المحاولة؛ وإن تكرر احذف الملف الصوتي وابدأ من جديد.',
    ),
  };

  // Sentences (about three seconds each; none contains the wake phrase).
  String sentence(int i) => _ar
      ? const [
          'اليوم الجو حلو وأريد أطلع أتمشى شوية بالحديقة',
          'ذكرني بالاجتماع بكرة الصبح الساعة تسعة',
          'أريد أعرف أخبار الطقس والمرور هذا المساء',
          'شكراً على مساعدتك وتصبح على خير',
        ][i % 4]
      : const [
          'The weather is nice today and I want to take a walk in the park',
          'Remind me about the meeting tomorrow morning at nine',
          'I would like to know the weather and the traffic this evening',
          'Thank you for your help and have a good night',
        ][i % 4];

  // Step 3.
  String get tryTitle => _t('Say your wake phrase', 'قل عبارة التنبيه');
  String tryBody(String phrase) => _t(
    'Say «$phrase» once. It listens for 10 seconds.',
    'قل «$phrase» مرة واحدة. يستمع 10 ثوانٍ.',
  );
  String get tryRun => _t('Start the test', 'ابدأ الاختبار');
  String get listening => _t('Listening… say it now', 'أستمع… قلها الآن');
  String phraseResult(bool heard) => heard
      ? _t('Phrase heard', 'سُمعت العبارة')
      : _t(
          'Phrase not heard: try again, a little closer',
          'لم تُسمع العبارة: حاول مجدداً وأقرب قليلاً',
        );
  String ownerResult(String? r) => switch (r) {
    'match' => _t('Voice: matches you', 'الصوت: يطابقك'),
    'uncertain' => _t(
      'Voice: not sure. AMEER will offer tap to talk instead of opening by itself.',
      'الصوت: غير متأكد. سيعرض أمير زر الضغط للتحدث بدل أن يفتح تلقائياً.',
    ),
    'different' => _t('Voice: does not match you', 'الصوت: لا يطابقك'),
    _ => '',
  };
  String get assistantOk =>
      _t('Android assistant: set up', 'مساعد أندرويد: مُعدّ');
  String get assistantNo =>
      _t('Android assistant: not set up yet', 'مساعد أندرويد: غير مُعدّ بعد');
  String get assistantOpen => _t('Open assistant setup', 'فتح إعداد المساعد');
  String get finish => _t('Finish', 'إنهاء');
  String get finishNote => _t(
    'Your voice is set up provisionally. It is good for everyday use, but its accuracy has not been measured on your voice and it is not a password.',
    'تم إعداد صوتك مبدئياً. يصلح للاستعمال اليومي، لكن لم تُقَس دقته على صوتك وهو ليس كلمة مرور.',
  );
}
