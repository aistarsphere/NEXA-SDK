import 'package:flutter/widgets.dart';

/// Host-app chrome strings (the SDK localises its own widgets). English and
/// Modern Standard Arabic, following the SDK's language setting.
final class AppStrings {
  const AppStrings._(this._ar);

  final bool _ar;

  static AppStrings of(BuildContext context) =>
      AppStrings._(Localizations.localeOf(context).languageCode == 'ar');

  String _t(String en, String ar) => _ar ? ar : en;

  String get appName => _t('LABEEB', 'لبيب');
  String get assistantSubtitle => _t('Your assistant', 'مساعدك الذكي');
  String get liveVoice => _t('Live voice', 'محادثة صوتية');
  String get liveConversation => _t('Live conversation', 'مكالمة مباشرة');
  String get newConversation => _t('New conversation', 'محادثة جديدة');
  String get newConversationStarted =>
      _t('Started a new conversation', 'بدأت محادثة جديدة');
  String get settings => _t('Settings', 'الإعدادات');
  String get close => _t('Close', 'إغلاق');

  String get language => _t('Language', 'اللغة');
  String get appearance => _t('Appearance', 'المظهر');
  String get system => _t('System', 'النظام');
  String get light => _t('Light', 'فاتح');
  String get dark => _t('Dark', 'داكن');
  String get colorTheme => _t('Color theme', 'ألوان التطبيق');
  String get conversations => _t('Conversations', 'المحادثات');
  String get historyUnavailable => _t(
    'Conversation history isn\'t available yet. A conversation lasts until '
        'you start a new one.',
    'سجل المحادثات غير متاح بعد. تستمر المحادثة حتى تبدأ محادثة جديدة.',
  );
  String get historyServer => _t(
    'Your conversations are kept by the service. Open History to continue '
        'one, rename it or delete it.',
    'تحتفظ الخدمة بمحادثاتك. افتح السجل لمتابعة محادثة أو إعادة تسميتها أو '
        'حذفها.',
  );
  String get about => _t('About', 'حول التطبيق');
  String get privacy => _t('Privacy', 'الخصوصية');
  String get deleteData =>
      _t('Delete my assistant data', 'حذف بياناتي لدى المساعد');
  String get deleteDataBody => _t(
    'Deletes your conversations, files, saved voices and preferences in '
        'this app. This can\'t be undone.',
    'يحذف محادثاتك وملفاتك وأصواتك المحفوظة وتفضيلاتك في هذا التطبيق. '
        'لا يمكن التراجع عن ذلك.',
  );
  String get delete => _t('Delete', 'حذف');
  String get cancel => _t('Cancel', 'إلغاء');
  String get deleteDataDone =>
      _t('Your assistant data was deleted.', 'تم حذف بياناتك لدى المساعد.');
  String get deleteDataFailed => _t(
    "Your data couldn't be deleted. Try again.",
    'تعذّر حذف بياناتك. حاول مرة أخرى.',
  );
  String version(String v) => _t('Version $v', 'الإصدار $v');
  String get privacyNote => _t(
    'The microphone is used only during a live conversation.',
    'يُستخدم الميكروفون فقط أثناء المحادثة الصوتية المباشرة.',
  );

  String get notConnectedTitle =>
      _t('Assistant not connected', 'المساعد غير متصل');
  String get notConnectedBody => _t(
    'This build has no sign-in service yet, so it can\'t start a '
        'conversation. Access to LABEEB is issued by your organisation\'s '
        'server.',
    'هذه النسخة لا تحتوي على خدمة تسجيل دخول بعد، لذلك لا يمكنها بدء '
        'محادثة. يمنح خادم مؤسستك الوصول إلى لبيب.',
  );
  String get tokenExpiredTitle => _t('Access expired', 'انتهت صلاحية الوصول');
  String get devTokenBody => _t(
    'Development build: put a short-lived SDK token in your secrets file '
        '(NEXA_DEV_SDK_TOKEN) and rebuild with:',
    'نسخة تطوير: ضع رمز SDK قصير الصلاحية في ملف الأسرار '
        '(NEXA_DEV_SDK_TOKEN) ثم أعد البناء باستخدام:',
  );

  String get developer => _t('Developer', 'المطوّر');
  String get developerOnly =>
      _t('Visible in development builds only.', 'يظهر في نسخ التطوير فقط.');
  String get playground => _t('SDK playground', 'ساحة تجربة SDK');
  String get playgroundBody => _t(
    'Embedded and modal chat, the voice event log and theme overrides.',
    'المحادثة المضمّنة والنافذة، وسجل أحداث الصوت، وتخصيص المظهر.',
  );
  String get diagnostics => _t('Diagnostics', 'التشخيص');

  List<String> suggestions() => _ar
      ? const [
          'بماذا يمكنك مساعدتي؟',
          'لخّص لي موضوعًا في ثلاث نقاط',
          'ساعدني في كتابة رسالة قصيرة ومهذبة',
          'أريدك أن تتحدث بصوتي',
        ]
      : const [
          'What can you help me with?',
          'Summarise a topic for me in three points',
          'Help me write a short, polite message',
          'I want you to speak in my voice',
        ];

  static List<String> suggestionsFor(String languageCode) =>
      AppStrings._(languageCode == 'ar').suggestions();
}
