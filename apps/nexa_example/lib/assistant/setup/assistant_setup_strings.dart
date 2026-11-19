import 'package:flutter/widgets.dart';
import 'package:nexa_assistant/nexa_assistant.dart';

/// Texts of the assistant setup wizard (Arabic and English).
final class AssistantSetupStrings {
  const AssistantSetupStrings._(this._ar);
  final bool _ar;

  static AssistantSetupStrings of(BuildContext c) =>
      AssistantSetupStrings._(Localizations.localeOf(c).languageCode == 'ar');

  String _t(String en, String ar) => _ar ? ar : en;

  String get title => _t('Assistant setup', 'إعداد المساعد');
  String get entrySubtitle => _t(
    'A checklist built from what this phone really supports',
    'قائمة مبنية على ما يدعمه هذا الهاتف فعلاً',
  );
  String device(String maker, String model, int sdk) => _t(
    '$maker $model · Android ${_release(sdk)} (API $sdk)',
    '$maker $model · أندرويد ${_release(sdk)} (API $sdk)',
  );
  static String _release(int sdk) => switch (sdk) {
    28 => '9',
    29 => '10',
    30 => '11',
    31 => '12',
    32 => '12L',
    33 => '13',
    34 => '14',
    35 => '15',
    36 => '16',
    _ => '?',
  };

  String overall(NexaSetupOverall o) => switch (o) {
    NexaSetupOverall.ready => _t('Ready and verified', 'جاهز ومؤكَّد'),
    NexaSetupOverall.partial => _t('Partly set up', 'إعداد جزئي'),
    NexaSetupOverall.blocked => _t('Blocked by the system', 'محجوب من النظام'),
  };

  String state(NexaStepState s) => switch (s) {
    NexaStepState.verified => _t('Verified', 'مؤكَّد'),
    NexaStepState.configuredNotTested => _t(
      'Set, not tested',
      'مضبوط، لم يُختبر',
    ),
    NexaStepState.todo => _t('To do', 'مطلوب'),
    NexaStepState.blocked => _t('Blocked', 'محجوب'),
    NexaStepState.unsupported => _t('Not supported here', 'غير مدعوم هنا'),
  };

  String get optional => _t('Optional', 'اختياري');

  String stepTitle(NexaStepId id) => switch (id) {
    NexaStepId.microphone => _t('Microphone', 'الميكروفون'),
    NexaStepId.notifications => _t('Notifications', 'الإشعارات'),
    NexaStepId.defaultAssistant => _t('Default assistant', 'المساعد الافتراضي'),
    NexaStepId.wakeListening => _t(
      'Wake phrase listening',
      'الاستماع لعبارة التنبيه',
    ),
    NexaStepId.battery => _t('Battery', 'البطارية'),
    NexaStepId.oemBackground => _t(
      'Background running (phone maker)',
      'التشغيل في الخلفية (الشركة المصنّعة)',
    ),
    NexaStepId.lockScreen => _t('Lock screen', 'شاشة القفل'),
  };

  String stepBody(NexaStepId id) => switch (id) {
    NexaStepId.microphone => _t('Needed to hear you.', 'لازم ليسمعك أمير.'),
    NexaStepId.notifications => _t(
      'Android shows a notification while AMEER listens for the wake phrase.',
      'يعرض أندرويد إشعاراً طوال استماع أمير لعبارة التنبيه.',
    ),
    NexaStepId.defaultAssistant => _t(
      'Lets the system assistant gesture or button open AMEER, including from the lock screen.',
      'يسمح لإيماءة أو زر المساعد في النظام بفتح أمير، ومنها من شاشة القفل.',
    ),
    NexaStepId.wakeListening => _t(
      'AMEER listens on this phone for your wake phrase. Nothing leaves the phone.',
      'يستمع أمير على هذا الهاتف لعبارتك. لا يخرج شيء من الهاتف.',
    ),
    NexaStepId.battery => _t(
      'Android may stop background listening to save power.',
      'قد يوقف أندرويد الاستماع في الخلفية لتوفير الطاقة.',
    ),
    NexaStepId.oemBackground => _t(
      'Some phone makers stop background apps on their own.',
      'بعض الشركات توقف التطبيقات في الخلفية من تلقاء نفسها.',
    ),
    NexaStepId.lockScreen => _t(
      'Opening AMEER while the phone is locked.',
      'فتح أمير والهاتف مقفل.',
    ),
  };

  String note(String n) => switch (n) {
    '' => '',
    'listening_needs_visible_notification' => _t(
      'Required for the listening service.',
      'مطلوب لخدمة الاستماع.',
    ),
    'role_held_not_tested' => _t(
      'AMEER is the default assistant. Use the test to prove the gesture opens it.',
      'أمير هو المساعد الافتراضي. استعمل الاختبار لإثبات أن الإيماءة تفتحه.',
    ),
    'role_held_service_not_bound' => _t(
      'Android lists AMEER as the assistant but has not started its service yet. Open the test.',
      'يعرض أندرويد أمير كمساعد لكنه لم يشغّل خدمته بعد. افتح الاختبار.',
    ),
    'role_unavailable' => _t(
      'This Android build has no assistant role. Only the older settings route may exist.',
      'لا يتوفر دور المساعد في هذا الإصدار. قد يوجد المسار الأقدم فقط.',
    ),
    'choose_digital_assistant' => _t(
      'Android does not let apps pick this for you. In the screen that opens choose “Digital assistant app”, then AMEER. When you come back this page re-reads the system.',
      'لا يسمح أندرويد للتطبيقات باختيار هذا عنك. في الشاشة التي تُفتح اختر «تطبيق المساعد الرقمي» ثم أمير. عند عودتك تعيد هذه الصفحة قراءة النظام.',
    ),
    'role_request_unavailable' => _t(
      'The direct request is not available here: choose AMEER in the default apps screen.',
      'الطلب المباشر غير متاح هنا: اختر أمير من شاشة التطبيقات الافتراضية.',
    ),
    'no_settings_destination' => _t(
      'This phone offers no screen for it that AMEER can open. Open Settings → Apps → Default apps by hand.',
      'لا يوفر الهاتف شاشة يستطيع أمير فتحها. افتح الإعدادات ← التطبيقات ← التطبيقات الافتراضية يدوياً.',
    ),
    'cannot_verify_role' => _t(
      'Android 9 and older cannot confirm this from the app.',
      'أندرويد 9 وما قبله لا يؤكد هذا للتطبيق.',
    ),
    'no_wake_model' => _t(
      'No acoustic wake model is installed.',
      'لا يوجد نموذج صوتي مثبّت لعبارة التنبيه.',
    ),
    'needs_microphone_and_notification' => _t(
      'Allow the microphone and notifications first.',
      'اسمح بالميكروفون والإشعارات أولاً.',
    ),
    'listening_not_tested' => _t(
      'Listening, but no wake phrase has been detected yet. Say it to test.',
      'يستمع، لكن لم تُكتشف عبارة بعد. قلها للاختبار.',
    ),
    'background_start_blocked' => _t(
      'Android refused to start listening from the background. Open AMEER and turn it on again.',
      'رفض أندرويد بدء الاستماع من الخلفية. افتح أمير وفعّله مجدداً.',
    ),
    'permission_denied' => _t(
      'The microphone permission was revoked.',
      'سُحب إذن الميكروفون.',
    ),
    'enabled_but_not_running' => _t(
      'It is turned on but not running (after a restart or force-stop Android only allows starting it while AMEER is open).',
      'مفعّل لكنه لا يعمل (بعد إعادة التشغيل أو الإيقاف الإجباري لا يسمح أندرويد بتشغيله إلا وأمير مفتوح).',
    ),
    'battery_saver_on' => _t(
      'Battery saver is on and may stop listening.',
      'وضع توفير الطاقة مفعّل وقد يوقف الاستماع.',
    ),
    'oem_cannot_be_verified' => _t(
      'Android cannot tell what this phone maker screen is set to. Allow background running there, then test.',
      'لا يستطيع أندرويد معرفة ضبط هذه الشاشة. اسمح بالتشغيل في الخلفية ثم اختبر.',
    ),
    'oem_manual' => _t(
      'Open Settings → Battery / App launch and allow AMEER to run in the background. This phone has no screen AMEER can open directly.',
      'افتح الإعدادات ← البطارية / تشغيل التطبيقات واسمح لأمير بالعمل في الخلفية. لا توجد شاشة يستطيع أمير فتحها مباشرة.',
    ),
    'keyguard_not_supported' => _t(
      'The system assistant service does not support the lock screen.',
      'خدمة المساعد لا تدعم شاشة القفل.',
    ),
    'needs_assistant_or_listening' => _t(
      'Set AMEER as the assistant or turn on wake listening first.',
      'اجعل أمير المساعد أو فعّل الاستماع أولاً.',
    ),
    'android14_reopen_after_restart' => _t(
      'On Android 14+ listening restarts only while AMEER is open (after a restart open it once).',
      'في أندرويد 14+ يعود الاستماع بفتح أمير فقط (بعد إعادة التشغيل افتحه مرة).',
    ),
    'verified_via_assist_only' => _t(
      'Verified through the assistant gesture. Waking it by voice while locked is a separate test.',
      'تأكّد عبر إيماءة المساعد. إيقاظه بالصوت والهاتف مقفل اختبار منفصل.',
    ),
    'no_screen_lock' => _t(
      'This phone has no screen lock, so anyone can use it.',
      'لا يوجد قفل للشاشة في هذا الهاتف، فيستطيع أي شخص استعماله.',
    ),
    _ => n,
  };

  String action(NexaStepAction a) => switch (a) {
    NexaStepAction.requestMicrophone => _t('Allow', 'السماح'),
    NexaStepAction.requestNotifications => _t('Allow', 'السماح'),
    NexaStepAction.openDefaultApps => _t(
      'Open default apps',
      'فتح التطبيقات الافتراضية',
    ),
    NexaStepAction.openVoiceInput => _t(
      'Choose assistant app',
      'اختيار تطبيق المساعد',
    ),
    NexaStepAction.openNotifications => _t(
      'Open notification settings',
      'فتح إعدادات الإشعارات',
    ),
    NexaStepAction.openBattery => _t(
      'Open battery screen',
      'فتح شاشة البطارية',
    ),
    NexaStepAction.openOemBackground => _t(
      'Open phone-maker screen',
      'فتح شاشة الشركة المصنّعة',
    ),
    NexaStepAction.openAppDetails => _t(
      'Open app settings',
      'فتح إعدادات التطبيق',
    ),
    NexaStepAction.enableWake => _t('Turn on', 'تفعيل'),
    NexaStepAction.testAssist => _t('Test', 'اختبار'),
    NexaStepAction.testLock => _t('Test', 'اختبار'),
    NexaStepAction.none => '',
  };

  String get recheck => _t('Checked again just now', 'أُعيد الفحص الآن');
  String roleAnswer(bool? held) => held == true
      ? _t(
          'Android confirms AMEER is now the default assistant.',
          'يؤكد أندرويد أن أمير أصبح المساعد الافتراضي.',
        )
      : _t(
          'Android says AMEER is not the default assistant.',
          'يقول أندرويد إن أمير ليس المساعد الافتراضي.',
        );
  String get notOpenable => _t(
    'This phone cannot open that screen from AMEER. Follow the instructions in the step.',
    'لا يستطيع الهاتف فتح تلك الشاشة من أمير. اتبع التعليمات في الخطوة.',
  );
  String get testAssistTitle =>
      _t('Test the assistant gesture', 'اختبار إيماءة المساعد');
  String get testAssistBody => _t(
    'Use your phone’s assistant gesture or button (for example hold the power or home button). AMEER should open. This page turns “Verified” only when Android really starts AMEER.',
    'استعمل إيماءة أو زر المساعد في هاتفك (مثلاً اضغط مطولاً على زر التشغيل أو الرئيسية). يجب أن يفتح أمير. تصبح الخطوة «مؤكَّدة» فقط حين يشغّل أندرويد أمير فعلاً.',
  );
  String get testLockTitle =>
      _t('Test from the lock screen', 'اختبار من شاشة القفل');
  String get testLockBody => _t(
    'Turn the screen off and lock the phone. Then use the assistant gesture or say your wake phrase. Unlock and reopen this page: the step becomes “Verified” only if AMEER really activated while the phone was locked.',
    'أطفئ الشاشة وأقفل الهاتف. ثم استعمل إيماءة المساعد أو قل عبارة التنبيه. افتح القفل وعد إلى هذه الصفحة: تصبح الخطوة «مؤكَّدة» فقط إذا نشط أمير فعلاً والهاتف مقفل.',
  );
  String get ok => _t('OK', 'حسناً');
}
