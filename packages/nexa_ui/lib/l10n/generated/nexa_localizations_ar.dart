// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'nexa_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class NexaLocalizationsAr extends NexaLocalizations {
  NexaLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get chatTitle => 'المساعد';

  @override
  String get composerHint => 'اكتب رسالة';

  @override
  String get send => 'إرسال';

  @override
  String get cancel => 'إلغاء';

  @override
  String get retry => 'إعادة المحاولة';

  @override
  String get stopGenerating => 'إيقاف';

  @override
  String get endSession => 'إنهاء المحادثة';

  @override
  String get connecting => 'جارٍ الاتصال…';

  @override
  String get thinking => 'جارٍ التفكير…';

  @override
  String get assistantTyping => 'المساعد يكتب';

  @override
  String get messageFailed => 'تعذّر إرسال هذه الرسالة.';

  @override
  String get messageCancelled => 'تم الإيقاف.';

  @override
  String get sessionEnded => 'انتهت هذه المحادثة.';

  @override
  String get sessionEndedQuota => 'لقد وصلت إلى حد الاستخدام لهذه المحادثة.';

  @override
  String get sessionError => 'حدث خطأ ما. يرجى المحاولة مرة أخرى.';

  @override
  String get offline =>
      'أنت غير متصل بالإنترنت. لن تُرسل الرسائل حتى تعود للاتصال.';

  @override
  String quotaWarning(int remaining) {
    return 'تبقّى $remaining رسالة';
  }

  @override
  String get toolRunning => 'جارٍ العمل عليه…';

  @override
  String get toolFailed => 'فشلت هذه الخطوة.';

  @override
  String get toolCancelled => 'تم الإلغاء.';

  @override
  String get invalidResult => 'أعاد المساعد شيئاً لم نتمكن من عرضه.';

  @override
  String get confirm => 'تأكيد';

  @override
  String get decline => 'إلغاء';

  @override
  String get submit => 'إرسال';

  @override
  String get requiredField => 'مطلوب';

  @override
  String get selectOne => 'اختر واحداً';

  @override
  String get selectMany => 'اختر واحداً أو أكثر';

  @override
  String get openNow => 'مفتوح الآن';

  @override
  String get closed => 'مغلق';

  @override
  String distanceKm(String km) {
    return '$km كم';
  }

  @override
  String distanceM(int m) {
    return '$m م';
  }

  @override
  String routeSummary(String distance, int minutes) {
    return '$distance · $minutes دقيقة';
  }

  @override
  String weatherFeelsLike(int temp) {
    return 'الإحساس كأنها $temp°';
  }

  @override
  String weatherHumidity(int percent) {
    return 'الرطوبة $percent٪';
  }

  @override
  String weatherWind(int kph) {
    return 'الرياح $kph كم/س';
  }

  @override
  String get permissionMicrophoneTitle => 'الوصول إلى الميكروفون';

  @override
  String get permissionMicrophoneBody =>
      'اسمح بالوصول إلى الميكروفون للتحدث مع المساعد.';

  @override
  String get permissionAllow => 'السماح';

  @override
  String get permissionDeny => 'ليس الآن';

  @override
  String get mediaPlay => 'تشغيل';

  @override
  String semanticsUserMessage(String text) {
    return 'قلت: $text';
  }

  @override
  String semanticsAssistantMessage(String text) {
    return 'قال المساعد: $text';
  }

  @override
  String get semanticsSendButton => 'إرسال الرسالة';

  @override
  String get semanticsStopButton => 'إيقاف التوليد';

  @override
  String get poweredBy => 'مدعوم من نيكسا';

  @override
  String get reconnecting => 'جارٍ إعادة الاتصال…';

  @override
  String get connected => 'متصل';

  @override
  String get authError =>
      'تعذّر التحقق من صلاحية الوصول. يرجى المحاولة مرة أخرى.';

  @override
  String get sessionExpired => 'انتهت صلاحية الجلسة. ابدأ من جديد للمتابعة.';

  @override
  String get rateLimited => 'طلبات كثيرة جداً. يرجى الانتظار قليلاً.';

  @override
  String get jumpToLatest => 'الانتقال إلى الأحدث';

  @override
  String get semanticsAssistantResponding => 'المساعد يجيب';

  @override
  String get semanticsAssistantFinished => 'أنهى المساعد الرد';

  @override
  String get semanticsMessageFailed => 'تعذّر إرسال الرسالة';
}
