import 'package:flutter/widgets.dart';

/// Strings for "LABEEB as assistant" (English and Modern Standard Arabic).
final class DeviceAssistantStrings {
  const DeviceAssistantStrings._(this._ar);

  final bool _ar;

  static DeviceAssistantStrings of(BuildContext context) =>
      DeviceAssistantStrings._(
        Localizations.localeOf(context).languageCode == 'ar',
      );

  static DeviceAssistantStrings ofCode(String languageCode) =>
      DeviceAssistantStrings._(languageCode == 'ar');

  String _t(String en, String ar) => _ar ? ar : en;

  // Call notification (foreground service).
  String get callNotificationTitle => _t('LABEEB call', 'مكالمة لبيب');
  String get callNotificationEnd => _t('End call', 'إنهاء المكالمة');

  // Settings entry and page.
  String get title => _t('LABEEB as assistant', 'لبيب كمساعد للجهاز');
  String get entrySubtitle => _t(
    'Default assistant, wake phrase and your voice',
    'المساعد الافتراضي وعبارة التنبيه وصوتك',
  );

  String get defaultAssistant => _t('Default assistant', 'المساعد الافتراضي');
  String get isDefault =>
      _t('LABEEB is your default assistant', 'لبيب هو مساعدك الافتراضي');
  String get notDefault => _t(
    'Another assistant is selected. Tap the button below, then tap the FIRST '
        'item, "Digital assistant app", and choose LABEEB. Leave "Voice '
        'input" as it is: that is voice typing.',
    'تم اختيار مساعد آخر. اضغط الزر أدناه، ثم اضغط البند الأول «تطبيق المساعد '
        'الرقمي» واختر لبيب. اترك «الإدخال الصوتي» كما هو: فهو للكتابة '
        'الصوتية.',
  );
  String get recheck => _t('Check again', 'تحقق مجدداً');
  String get change => _t('Change', 'تغيير');
  String get signalRole =>
      _t('Android assistant role', 'دور المساعد في أندرويد');
  String get signalSetting => _t('Assistant setting', 'إعداد المساعد');
  String get signalBound => _t(
    'Assistant service connected by Android',
    'خدمة المساعد متصلة من أندرويد',
  );
  String get roleHelp => _t(
    'Still not set? Android settings → Apps → Default apps → Digital '
        'assistant app → LABEEB. Then come back and tap Check again.',
    'لم يتم بعد؟ إعدادات أندرويد ← التطبيقات ← التطبيقات الافتراضية ← تطبيق '
        'المساعد الرقمي ← لبيب. ثم عد واضغط تحقق مجدداً.',
  );
  String get chooseInSettings =>
      _t('Choose digital assistant', 'اختيار المساعد الرقمي');
  String get roleUnavailable => _t(
    'This device does not offer a default assistant setting.',
    'هذا الجهاز لا يتيح اختيار مساعد افتراضي.',
  );

  String get panelTitle => _t('Assistant panel', 'لوحة المساعد');
  String get panelBody => _t(
    'The assist gesture or «يا لبيب» opens a compact panel over the app you '
        'are using. It ends the conversation after the time below without '
        'speech, then goes back to listening for the phrase.',
    'تفتح إيماءة المساعد أو «يا لبيب» لوحة صغيرة فوق التطبيق الذي تستخدمه. '
        'تنهي المحادثة بعد المدة أدناه دون كلام، ثم تعود للاستماع للعبارة.',
  );
  String get panelPosition => _t('Position', 'الموضع');
  String get posBottom => _t('Bottom', 'أسفل');
  String get posTop => _t('Top', 'أعلى');
  String get posLeft => _t('Left', 'يسار');
  String get posRight => _t('Right', 'يمين');
  String get idleTimeout => _t('End after silence', 'الإنهاء بعد الصمت');
  String seconds(int n) => _t('$n s', '$n ث');
  String minutes(int n) => _t('$n min', '$n د');
  String get never => _t('Never', 'أبداً');

  String get checks => _t('Checks', 'الفحوصات');
  String get checkRole => _t('Default assistant', 'المساعد الافتراضي');
  String get checkEnrollment =>
      _t('Wake phrase recorded', 'تسجيل عبارة التنبيه');
  String get checkOffline => _t(
    'Phrase detected on this device (last test)',
    'اكتشاف العبارة على الجهاز (آخر اختبار)',
  );
  String get checkRunTest =>
      _t('Not tested yet: use Test below', 'لم يُختبر بعد: استخدم الاختبار');
  String get checkOwner =>
      _t('Owner voice check (last test)', 'التحقق من صوت المالك (آخر اختبار)');
  String get checkOff => _t('Off', 'متوقف');
  String get checkListener => _t('Background listener', 'المستمع في الخلفية');
  String get checkInvocation =>
      _t('Last assistant activation', 'آخر تشغيل للمساعد');
  String get checkMicrophone => _t('Microphone', 'الميكروفون');
  String get micHandedOver =>
      _t('Released to a conversation or call', 'متاح لمحادثة أو مكالمة');
  String get checkLastEnd =>
      _t('Last panel conversation ended', 'آخر محادثة في اللوحة انتهت');

  String get wakeTitle => _t('Wake phrase', 'عبارة التنبيه');
  String wakeSwitch(String phrase) =>
      _t('Respond to “$phrase”', 'الاستجابة لـ «$phrase»');
  String get wakeListening =>
      _t('Listening on this device', 'يستمع على هذا الجهاز');
  String get wakePaused => _t(
    'Paused (conversation or call in progress)',
    'متوقف مؤقتاً (محادثة أو مكالمة جارية)',
  );
  String get wakeOff => _t('Off', 'متوقف');
  String get wakeNeedsEnrollment => _t(
    'Record your voice first so LABEEB knows how you say it.',
    'سجّل صوتك أولاً ليتعرف لبيب على طريقة نطقك لها.',
  );
  String get wakeNeedsForeground =>
      _t('Open LABEEB to turn it on.', 'افتح لبيب لتشغيلها.');
  String get wakeBlocked => _t(
    'Android did not allow listening to start. Open LABEEB and try again.',
    'لم يسمح أندرويد ببدء الاستماع. افتح لبيب وحاول مجدداً.',
  );
  String get micNeeded =>
      _t('Microphone permission is needed.', 'يلزم إذن الميكروفون.');
  String get notificationsOff => _t(
    'Notifications are off: Android hides the “listening” notice. Turn them '
        'on so you always see when LABEEB listens.',
    'الإشعارات متوقفة: يخفي أندرويد إشعار «يستمع». فعّلها لترى دائماً متى '
        'يستمع لبيب.',
  );
  String get allowNotifications =>
      _t('Allow notifications', 'السماح بالإشعارات');
  String get hardwareHotword => _t(
    'Android’s low-power hotword chip is reserved for preinstalled '
        'assistants. LABEEB uses its own on-device listener, which uses more '
        'battery.',
    'شريحة التنبيه منخفضة الطاقة في أندرويد مخصصة للمساعدات المثبتة مسبقاً. '
        'يستخدم لبيب مستمعاً خاصاً به على الجهاز، ويستهلك بطارية أكثر.',
  );

  String get voiceTitle => _t('Your voice', 'صوتك');
  String get enroll => _t('Record my voice', 'تسجيل صوتي');
  String get reEnroll => _t('Record again', 'إعادة التسجيل');
  String enrolledSamples(int n) =>
      _t('Recorded: $n samples', 'تم التسجيل: $n عينات');
  String get requireMyVoice =>
      _t('Only respond to my voice', 'الاستجابة لصوتي فقط');
  String get requireMyVoiceBody => _t(
    'Checked on this device after the phrase. It reduces activations by '
        'others; it is not a password and can be fooled.',
    'يُتحقق منه على هذا الجهاز بعد العبارة. يقلل التشغيل من أشخاص آخرين؛ '
        'لكنه ليس كلمة مرور ويمكن خداعه.',
  );
  String get modelMissing => _t(
    'The voice model is not installed in this build.',
    'نموذج الصوت غير مثبت في هذا الإصدار.',
  );
  String get noVoiceProfile => _t(
    'Record again to create a voice profile.',
    'أعد التسجيل لإنشاء بصمة صوتية.',
  );
  String get deleteVoice => _t('Delete my voice data', 'حذف بيانات صوتي');
  String get deleteVoiceBody => _t(
    'Turns the wake phrase off and deletes your voice samples’ features and '
        'voice profile from this device.',
    'يوقف عبارة التنبيه ويحذف خصائص عينات صوتك وبصمتك الصوتية من هذا الجهاز.',
  );
  String get deleted => _t('Voice data deleted', 'تم حذف بيانات الصوت');

  String get sensitivity => _t('Sensitivity', 'الحساسية');
  String get strict => _t('Strict', 'صارمة');
  String get normal => _t('Normal', 'عادية');
  String get relaxed => _t('Relaxed', 'مرنة');

  String get test => _t('Test', 'اختبار');
  String testPrompt(String phrase) =>
      _t('Say “$phrase” now…', 'قل «$phrase» الآن…');
  String get testRun => _t('Test the phrase', 'اختبار العبارة');
  String get testAccepted => _t('Recognised', 'تم التعرف');
  String get testRejected => _t('Not recognised', 'لم يتم التعرف');
  String get phraseMatched => _t('Phrase matched', 'العبارة مطابقة');
  String get phraseNotMatched => _t('Phrase not matched', 'العبارة غير مطابقة');
  String get voiceMatched => _t('Your voice matched', 'صوتك مطابق');
  String get voiceNotMatched => _t('Voice not matched', 'الصوت غير مطابق');
  String get heardNothing => _t('Didn’t hear anything', 'لم يُسمع شيء');

  String get background => _t('Background and battery', 'الخلفية والبطارية');
  String get batteryOk => _t(
    'Battery optimisation is off for LABEEB.',
    'تحسين البطارية متوقف للبيب.',
  );
  String get batteryOn => _t(
    'Android may stop listening to save battery. Allow LABEEB to run '
        'unrestricted.',
    'قد يوقف أندرويد الاستماع لتوفير البطارية. اسمح للبيب بالعمل دون قيود.',
  );
  String get batterySettings => _t('Battery settings', 'إعدادات البطارية');
  String get oemSettings =>
      _t('Autostart settings', 'إعدادات التشغيل التلقائي');
  String get oemNote => _t(
    'On Xiaomi phones also allow Autostart and set battery saver to “No '
        'restrictions”.',
    'في هواتف شاومي اسمح أيضاً بالتشغيل التلقائي واضبط توفير البطارية على '
        '«بلا قيود».',
  );
  String get limits => _t(
    'Listening continues with the screen off or locked while its '
        'notification is shown. It stops after a restart or when the app is '
        'force-stopped: open LABEEB once to turn it back on. Some phones also '
        'stop it when the app is swiped away.',
    'يستمر الاستماع والشاشة مطفأة أو مقفلة طالما يظهر إشعاره. يتوقف بعد إعادة '
        'التشغيل أو عند إيقاف التطبيق إجبارياً: افتح لبيب مرة لإعادة تشغيله. '
        'وبعض الهواتف توقفه عند إزالة التطبيق من التطبيقات الأخيرة.',
  );

  String get privacy => _t('Privacy', 'الخصوصية');
  String get privacyBody => _t(
    'The phrase and your voice are checked on this device only. Nothing is '
        'recorded or sent while LABEEB waits; a conversation starts only after '
        'it recognises the phrase. Your voice profile is encrypted on this '
        'device, never uploaded and not backed up.',
    'تُفحص العبارة وصوتك على هذا الجهاز فقط. لا يُسجَّل أو يُرسَل شيء أثناء '
        'الانتظار؛ ولا تبدأ المحادثة إلا بعد التعرف على العبارة. بصمتك الصوتية '
        'مشفرة على هذا الجهاز ولا تُرفع ولا تُنسخ احتياطياً.',
  );
  String get sensitiveNote => _t(
    'Private information and actions still need the phone unlocked and your '
        'approval.',
    'لا تزال المعلومات والإجراءات الخاصة تتطلب فتح قفل الهاتف وموافقتك.',
  );

  String get notOnThisDevice =>
      _t('Available on Android only.', 'متاح على أندرويد فقط.');

  // Enrolment.
  String get enrollTitle => _t('Record your voice', 'تسجيل صوتك');
  String enrollIntro(String phrase, int n) => _t(
    'Say “$phrase” $n times, the way you normally would. Pause briefly after '
        'each one. Recordings stay on this device and are discarded after '
        'their features are saved.',
    'قل «$phrase» $n مرات كما تقولها عادة، مع توقف قصير بعد كل مرة. تبقى '
        'التسجيلات على هذا الجهاز وتُحذف بعد حفظ خصائصها.',
  );
  String get enrollTip => _t(
    'Use different moments: closer, farther, a little louder or quieter.',
    'نوّع قليلاً: أقرب وأبعد، وبصوت أعلى أو أهدأ.',
  );
  String get recordSample => _t('Record', 'تسجيل');
  String get listening => _t('Listening…', 'يستمع…');
  String enrollProgress(int n, int total) => _t('$n of $total', '$n من $total');
  String get save => _t('Save', 'حفظ');
  String get cancel => _t('Cancel', 'إلغاء');
  String get saved => _t('Your voice is saved', 'تم حفظ صوتك');
  String get savedNoVoice => _t(
    'Phrase saved. The voice profile could not be created.',
    'تم حفظ العبارة. تعذر إنشاء البصمة الصوتية.',
  );
  String get saveFailed =>
      _t('Could not save. Try again.', 'تعذر الحفظ. حاول مجدداً.');
  String sampleProblem(String? reason) => switch (reason) {
    'no_speech' => _t('Didn’t hear you. Try again.', 'لم أسمعك. حاول مجدداً.'),
    'too_short' => _t(
      'Too short. Say the whole phrase.',
      'قصيرة جداً. قل العبارة كاملة.',
    ),
    'too_long' => _t(
      'Too long. Say only the phrase.',
      'طويلة جداً. قل العبارة فقط.',
    ),
    'too_quiet' => _t(
      'Too quiet. Speak a bit louder.',
      'منخفضة جداً. ارفع صوتك قليلاً.',
    ),
    'clipped' => _t(
      'Too loud. Move back a little.',
      'عالية جداً. ابتعد قليلاً.',
    ),
    'inconsistent' => _t(
      'That sounded different. Say the same phrase.',
      'بدت مختلفة. قل العبارة نفسها.',
    ),
    'permission_denied' => micNeeded,
    'busy' => _t('Still recording…', 'التسجيل جارٍ…'),
    _ => _t('The microphone is not available.', 'الميكروفون غير متاح.'),
  };
  String get openSettings => _t('Open settings', 'فتح الإعدادات');

  // Lock gate.
  String get unlockToContinue => _t(
    'Unlock your phone to continue. Nothing is shown before that.',
    'افتح قفل هاتفك للمتابعة. لا يُعرض شيء قبل ذلك.',
  );
  String get unlock => _t('Unlock', 'فتح القفل');
  String get notNow => _t('Not now', 'ليس الآن');
  String get unlockNotDone => _t('Still locked.', 'لا يزال مقفلاً.');
}
