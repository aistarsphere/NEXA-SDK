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
  String get toolCancelled => 'أُلغي. لم تتم مشاركة أي شيء.';

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

  @override
  String get voiceTitle => 'محادثة صوتية';

  @override
  String get voiceStart => 'ابدأ الصوت';

  @override
  String get voiceEnd => 'إنهاء المكالمة';

  @override
  String get voiceMute => 'كتم';

  @override
  String get voiceUnmute => 'إلغاء الكتم';

  @override
  String get voiceRetry => 'حاول مرة أخرى';

  @override
  String get voiceOpenSettings => 'افتح الإعدادات';

  @override
  String get voiceStateIdle => 'جاهز';

  @override
  String get voiceStateConnecting => 'جارٍ الاتصال…';

  @override
  String get voiceStateListening => 'أستمع إليك';

  @override
  String get voiceStateUserSpeaking => 'تفضّل، أنا أستمع';

  @override
  String get voiceStateTranscribing => 'فهمت…';

  @override
  String get voiceStateThinking => 'جارٍ التفكير…';

  @override
  String get voiceStateAiSpeaking => 'يتحدث';

  @override
  String get voiceStateBargeIn => 'أستمع إليك…';

  @override
  String get voiceReconnected => 'عاد الاتصال';

  @override
  String get voiceStateInterrupted => 'تمت المقاطعة';

  @override
  String get voiceStateMuted => 'الصوت مكتوم';

  @override
  String get voiceStateWeakNetwork => 'الاتصال ضعيف';

  @override
  String get voiceStateDisconnected => 'انقطع الاتصال';

  @override
  String get voiceStateReconnecting => 'جارٍ إعادة الاتصال…';

  @override
  String get voiceStateModelBusy => 'المساعد مشغول، لحظة من فضلك…';

  @override
  String get voiceStateMicrophoneDenied => 'الوصول إلى الميكروفون غير مفعّل';

  @override
  String get voiceStateQuotaExceeded => 'وصلت إلى حد المحادثات الصوتية';

  @override
  String get voiceStateEnded => 'انتهت المكالمة';

  @override
  String get voiceTranscriptYou => 'أنت';

  @override
  String get voiceTranscriptAssistant => 'المساعد';

  @override
  String get voiceUnverifiedEvents => 'وضع التطوير: أحداث المساعد غير موقّعة.';

  @override
  String get voiceAgentWaiting => 'بانتظار انضمام المساعد…';

  @override
  String semanticsVoiceOrb(String state) {
    return 'حالة الصوت: $state';
  }

  @override
  String get semanticsMuteButton => 'كتم الميكروفون';

  @override
  String get semanticsUnmuteButton => 'إلغاء كتم الميكروفون';

  @override
  String get semanticsEndCallButton => 'إنهاء المكالمة الصوتية';

  @override
  String get voiceUnavailable => 'الصوت مو متوفر هسه. جرّب بعد شوية.';

  @override
  String get chatEmptyTitle => 'كيف يمكنني مساعدتك اليوم؟';

  @override
  String get chatEmptyBody =>
      'اسأل أي شيء كتابةً، أو ابدأ محادثة صوتية مباشرة.';

  @override
  String get messageCopy => 'نسخ';

  @override
  String get messageCopied => 'تم النسخ';

  @override
  String get composerLiveVoice => 'ابدأ محادثة صوتية مباشرة';

  @override
  String get voiceHintIdle => 'يبدأ الصوت والنص عند الضغط على ابدأ';

  @override
  String get voiceHintConnecting => 'نجهّز جلسة آمنة';

  @override
  String get voiceHintListening => 'تحدّث في أي وقت';

  @override
  String get voiceHintUserSpeaking => 'توقّف قليلًا عندما تنتهي';

  @override
  String get voiceHintTranscribing => 'نحوّل كلامك إلى نص';

  @override
  String get voiceHintThinking => 'نجهّز الرد';

  @override
  String get voiceHintAiSpeaking => 'تحدّث في أي وقت للمقاطعة';

  @override
  String get voiceHintBargeIn => 'تفضّل، أنا أستمع';

  @override
  String get voiceHintMuted => 'ألغِ الكتم لتتحدث';

  @override
  String get voiceHintWeakNetwork => 'قد يتأخر الصوت، وتبقى النصوص ظاهرة.';

  @override
  String get voiceHintDisconnected => 'اضغط «حاول مرة أخرى» لإعادة الاتصال';

  @override
  String get voiceHintReconnecting => 'لن يضيع شيء أثناء إعادة الاتصال';

  @override
  String get voiceHintModelBusy => 'سيستمر تلقائيًا';

  @override
  String get voiceHintMicrophoneDenied => 'ما زال بإمكانك الكتابة';

  @override
  String get voiceHintQuotaExceeded => 'المحادثة النصية ما زالت متاحة';

  @override
  String get voiceHintEnded => 'اضغط «ابدأ» لمحادثة جديدة';

  @override
  String get voiceCaptionsEmpty => 'تظهر هنا نصوص الطرفين';

  @override
  String get voiceShowCaptions => 'إظهار النصوص';

  @override
  String get voiceHideCaptions => 'إخفاء النصوص';

  @override
  String get voiceCaptionsHidden => 'النصوص مخفية';

  @override
  String get voicePartial => 'جزئي';

  @override
  String get voiceFlagMuted => 'الميكروفون مكتوم';

  @override
  String get voiceFlagWeakNetwork => 'شبكة ضعيفة';

  @override
  String get assistantLiveVoice => 'محادثة صوتية';

  @override
  String get assistantLiveConversation => 'مكالمة مباشرة';

  @override
  String get assistantNewConversation => 'محادثة جديدة';

  @override
  String get assistantNewConversationStarted => 'بدأت محادثة جديدة';

  @override
  String get assistantSettings => 'الإعدادات';

  @override
  String get assistantClose => 'إغلاق';

  @override
  String get assistantStartChat => 'ابدأ محادثة';

  @override
  String get assistantStartVoice => 'تحدّث مباشرة';

  @override
  String get assistantHomeBody => 'اكتب سؤالك، أو تحدّث معي مباشرة.';

  @override
  String get attachTitle => 'إضافة إلى المحادثة';

  @override
  String get attachButton => 'إرفاق';

  @override
  String get attachTakePhoto => 'التقاط صورة';

  @override
  String get attachChooseImage => 'اختيار من المعرض';

  @override
  String get attachShareLocation => 'مشاركة موقعي';

  @override
  String get previewAdd => 'إضافة';

  @override
  String get cameraExplain =>
      'وجّه الكاميرا إلى ما تريد عرضه. لن تتم مشاركة أي شيء قبل أن تضغط «استخدام الصورة».';

  @override
  String get cameraCapture => 'التقاط';

  @override
  String get cameraRetake => 'إعادة';

  @override
  String get cameraUsePhoto => 'استخدام الصورة';

  @override
  String get cameraDenied =>
      'الوصول إلى الكاميرا متوقف. اسمح به من الإعدادات لالتقاط صورة.';

  @override
  String get cameraUnavailable => 'الكاميرا غير متاحة على هذا الجهاز.';

  @override
  String get cameraError => 'تعذّر تشغيل الكاميرا.';

  @override
  String get openSettings => 'فتح الإعدادات';

  @override
  String get toolAllow => 'سماح';

  @override
  String get toolNotNow => 'ليس الآن';

  @override
  String get locationApproveTitle => 'مشاركة موقعك الحالي؟';

  @override
  String get locationApproveBody =>
      'يُقرأ موقعك مرة واحدة لهذا الطلب ولا يتم تتبّعه.';

  @override
  String get cameraApproveTitle => 'فتح الكاميرا؟';

  @override
  String get cameraApproveBody =>
      'التقط صورة واحدة لعرضها. ستراجعها قبل مشاركتها.';

  @override
  String get locationResultTitle => 'موقعك';

  @override
  String locationAccuracy(int meters) {
    return 'بدقة تقارب $meters م';
  }

  @override
  String get locationWorking => 'جارٍ تحديد موقعك…';

  @override
  String get locationDenied => 'الوصول إلى الموقع متوقف.';

  @override
  String get locationServiceOff => 'خدمات الموقع متوقفة.';

  @override
  String get locationTimeout => 'تعذّر تحديد الموقع في الوقت المحدد.';

  @override
  String get locationFailed => 'تعذّر تحديد موقعك.';

  @override
  String get toolDeclined => 'لم تتم المشاركة.';

  @override
  String get toolNotDelivered =>
      'لم يُرسل إلى المساعد: الخادم لا يستقبل نتائج الجهاز بعد.';

  @override
  String get attachmentNotSent =>
      'على هذا الجهاز فقط: الخادم لا يستقبل المرفقات بعد.';

  @override
  String get attachmentUploading => 'جارٍ الرفع…';

  @override
  String get attachmentFailed => 'فشل الرفع';

  @override
  String get attachmentCancelled => 'أُلغي';

  @override
  String get imageShare => 'مشاركة';

  @override
  String get imageAskAbout => 'اسأل عن هذه الصورة';

  @override
  String get imageReference => 'حول هذه الصورة';

  @override
  String get referenceNotSent =>
      'لم تُرسل الإشارة إلى الصورة: الخادم لا يستقبل الصور بعد.';

  @override
  String get voiceShowSomething => 'اعرض شيئًا';

  @override
  String get historyTitle => 'السجل';

  @override
  String get historyEmpty => 'لا توجد محادثات محفوظة على هذا الجهاز بعد.';

  @override
  String get messageSpoken => 'بالصوت';

  @override
  String get listEmpty =>
      'لا توجد محادثات بعد. ابدأ واحدة بالكتابة أو بالتحدث.';

  @override
  String get historyChat => 'محادثة';

  @override
  String get historyVoice => 'مكالمة صوتية';

  @override
  String get historyUntitled => 'محادثة';

  @override
  String historyMessages(int count) {
    return 'الرسائل: $count';
  }

  @override
  String get historyRename => 'إعادة تسمية';

  @override
  String get historyResume => 'متابعة المحادثة';

  @override
  String get historyResumeUnavailable =>
      'متابعة محادثة سابقة تتطلب سجلًا على الخادم، وهو غير متاح بعد.';

  @override
  String get deleteAction => 'حذف';

  @override
  String get deletionWorking => 'جارٍ الحذف…';

  @override
  String get placesTitle => 'أماكن قريبة';

  @override
  String get placesLoading => 'جارٍ البحث بالقرب منك…';

  @override
  String get placesEmpty => 'لم يُعثر على أماكن قريبة.';

  @override
  String get placesLocationDenied => 'يحتاج البحث القريب إلى موقعك.';

  @override
  String get placesError => 'تعذّر تحميل الأماكن.';

  @override
  String get placesDirections => 'الاتجاهات';

  @override
  String placesDistanceM(int meters) {
    return 'على بعد $meters م';
  }

  @override
  String placesDistanceKm(String km) {
    return 'على بعد $km كم';
  }

  @override
  String get placesOpenNow => 'مفتوح الآن';

  @override
  String get placesClosed => 'مغلق';

  @override
  String get directionsFailed => 'تعذّر فتح الخرائط.';

  @override
  String get dataPrivacyTitle => 'البيانات والخصوصية';

  @override
  String get retentionDefault =>
      'مدة احتفاظ الخدمة بالمحادثات يحددها مشغّل التطبيق.';

  @override
  String get scopeConversation => 'حذف هذه المحادثة';

  @override
  String get scopeAllConversations => 'حذف كل المحادثات';

  @override
  String get scopeAllChats => 'مسح سجل المحادثات';

  @override
  String get scopeAllVoice => 'مسح سجل المكالمات الصوتية';

  @override
  String get scopeAssets => 'حذف الملفات المرفوعة والمُنشأة';

  @override
  String get scopeLocalCache => 'مسح ذاكرة الجهاز المؤقتة';

  @override
  String get scopeEverything => 'طلب حذف كل بياناتي لدى المساعد';

  @override
  String get scopeNoteLocalCache =>
      'البيانات المخزّنة مؤقتًا على هذا الجهاز فقط. لا يتأثر السجل على الخادم.';

  @override
  String get scopeNoteEverything =>
      'يُرسل الطلب إلى الخدمة. تُحفظ سجلات الفوترة والتدقيق الأمني وفق سياسة الاحتفاظ.';

  @override
  String get scopeNoteAllConversations =>
      'تُحذف كل المحادثات والمكالمات في سجلك من هذا الجهاز ومن الخدمة. لا يمكن التراجع عن ذلك.';

  @override
  String deletionQuestion(String title) {
    return '$title؟';
  }

  @override
  String get scopeNoteDefault => 'لا يمكن استرجاع ما تمت مشاركته خارج التطبيق.';

  @override
  String get scopeServerUnavailable => 'على الخادم: غير متاح بعد';

  @override
  String get deletionLocalDone => 'حُذف من هذا الجهاز';

  @override
  String get deletionServerUnavailable =>
      'حذف البيانات من الخادم غير متاح بعد، لذلك لم يُحذف شيء من الخادم.';

  @override
  String get deletionRequested => 'مطلوب · بانتظار تأكيد الخدمة';

  @override
  String get deletionConfirmed => 'حُذف من الخادم';

  @override
  String deletionPartial(int count) {
    return 'حُذف جزئيًا: تعذّر حذف $count عناصر.';
  }

  @override
  String get deletionServerFailed => 'لم تؤكد الخدمة الحذف.';

  @override
  String deletionRequestId(String id) {
    return 'الطلب $id';
  }

  @override
  String get deletionRetry => 'إعادة المحاولة';

  @override
  String get done => 'تم';

  @override
  String get historySearch => 'بحث';

  @override
  String get historyLoadFailed => 'تعذّر تحميل السجل.';

  @override
  String get historyCacheNote =>
      'معروض من ذاكرة هذا الجهاز المؤقتة. الخادم لا يوفّر سجل المحادثات بعد.';

  @override
  String get historyRenameUnavailable =>
      'إعادة التسمية تتطلب سجلًا على الخادم، وهو غير متاح بعد.';

  @override
  String get toolOriginDevice => 'الجهاز';

  @override
  String get toolOriginServer => 'الخادم';

  @override
  String get toolOriginCompany => 'الشركة';

  @override
  String get toolStateApproval => 'بانتظار الموافقة';

  @override
  String get toolStateDenied => 'مرفوض';

  @override
  String get toolStateRunning => 'قيد التنفيذ';

  @override
  String get toolStateSuccess => 'تم';

  @override
  String get toolStateError => 'فشل';

  @override
  String get toolStateCancelled => 'أُلغي';

  @override
  String get toolStateUnavailable => 'غير متاح';

  @override
  String get toolStateSetup => 'يحتاج إعدادًا';

  @override
  String get toolAllowOnce => 'سماح لمرة واحدة';

  @override
  String get toolRunAgain => 'تشغيل مجددًا';

  @override
  String get toolDismiss => 'إغلاق';

  @override
  String get toolLocationName => 'الموقع الحالي';

  @override
  String get toolCameraName => 'التقاط صورة';

  @override
  String get toolDirectionsName => 'فتح الملاحة';

  @override
  String get toolWhereDevice => 'يعمل على هذا الجهاز';

  @override
  String get toolWhereOtherApp => 'يفتح تطبيقًا آخر';

  @override
  String get toolLocationApproval =>
      'مشاركة موقعك مرة واحدة؟ لا تتم مشاركة أي شيء قبل أن تسمح.';

  @override
  String get toolCameraApproval =>
      'التقاط صورة لعرضها؟ لا تُفتح الكاميرا إلا بعد أن تسمح.';

  @override
  String get toolCameraRunning => 'بانتظار الكاميرا…';

  @override
  String get toolCameraSuccess => 'تم التقاط الصورة وإرفاقها.';

  @override
  String get toolDirectionsSuccess => 'تم فتح الاتجاهات.';

  @override
  String get toolDenied =>
      'تم رفض الوصول. يمكنك المتابعة بدونه أو السماح به من الإعدادات.';

  @override
  String get toolUnavailable => 'هذا غير متاح على هذا الجهاز.';

  @override
  String get toolSetup => 'لم يفعّل التطبيق هذه الميزة.';

  @override
  String get toolError => 'لم يكتمل. لم يتغير شيء.';

  @override
  String get toolRowCoordinates => 'الإحداثيات';

  @override
  String get toolRowAccuracy => 'الدقة';

  @override
  String get toolRowShared => 'المشاركة';

  @override
  String get toolRowSharedOnce => 'مرة واحدة، لهذا الطلب فقط';

  @override
  String get toolRowPhoto => 'الصورة';

  @override
  String get toolRowSentAs => 'أُرسلت كـ';

  @override
  String get toolRowDestination => 'الوجهة';

  @override
  String get toolRowOpenedIn => 'تُفتح في';

  @override
  String get toolOpenedApp => 'تطبيق الخرائط';

  @override
  String get toolOpenedBrowser => 'المتصفح';

  @override
  String toolAboutMeters(int meters) {
    return 'حوالي $meters م';
  }

  @override
  String get cameraOn => 'الكاميرا شغّالة';

  @override
  String get attachChooseFile => 'اختيار ملف';

  @override
  String get fileTooLarge => 'هذا الملف أكبر من 10 ميغابايت.';

  @override
  String get fileUnsupported => 'نوع هذا الملف غير مدعوم.';

  @override
  String get imageGenerated => 'مُنشأة بالذكاء الاصطناعي';

  @override
  String get imageEdited => 'معدّلة · ذكاء اصطناعي';

  @override
  String get attachmentCancel => 'إلغاء الرفع';

  @override
  String get attachmentReady => 'جاهز';

  @override
  String get toolNetworkName => 'حالة الشبكة';

  @override
  String get toolWifiName => 'شبكة الواي فاي';

  @override
  String get toolBrowserName => 'فتح موقع ويب';

  @override
  String get toolAppName => 'فتح تطبيق';

  @override
  String get toolAppsName => 'التطبيقات المدعومة';

  @override
  String get toolShareName => 'مشاركة';

  @override
  String get toolFilesName => 'اختيار ملف';

  @override
  String get toolSettingsName => 'فتح الإعدادات';

  @override
  String toolApprovalPersonal(String name) {
    return 'السماح للمساعد باستخدام «$name»؟ لا تتم مشاركة أي شيء قبل أن تسمح.';
  }

  @override
  String toolApprovalExternal(String name) {
    return 'السماح للمساعد بـ«$name»؟ سيُفتح هذا خارج التطبيق.';
  }

  @override
  String get toolWorking => 'جارٍ التنفيذ…';

  @override
  String get toolDoneGeneric => 'تم.';

  @override
  String get toolWhereServer => 'يعمل على الخادم';

  @override
  String get toolRowNetwork => 'الشبكة';

  @override
  String get toolRowWebsite => 'الموقع';

  @override
  String get toolRowApp => 'التطبيق';

  @override
  String get toolRowStatus => 'الحالة';

  @override
  String get toolRowFile => 'الملف';

  @override
  String get toolRowSsidHidden => 'غير متاح (النظام لا يسمح)';

  @override
  String get toolFileTooLarge => 'الملف أكبر من 10 ميغابايت.';

  @override
  String get toolFileUnsupported => 'نوع هذا الملف غير مدعوم.';

  @override
  String get duiDemo => 'بيانات تجريبية';

  @override
  String get duiLoading => 'جارٍ التحميل…';

  @override
  String get duiPartial => 'جارٍ تحميل المزيد…';

  @override
  String get duiEmpty => 'لا يوجد شيء لعرضه هنا.';

  @override
  String get duiError => 'حدث خطأ. لم يتغير شيء.';

  @override
  String get duiProviderUnavailable => 'المزوّد غير متاح، لذلك لا تُعرض نتائج.';

  @override
  String get duiOffline => 'غير متصل · يُعرض آخر نتيجة';

  @override
  String get duiDisabled => 'غير متاح حاليًا.';

  @override
  String get duiUnsupported => 'لا يمكن عرض هذا المحتوى في إصدار التطبيق هذا.';

  @override
  String get duiActionUnsupported => 'غير متاح في إصدار التطبيق هذا';

  @override
  String get duiHostUnavailable => 'هذا التطبيق لا يسمح بتغيير مظهره.';

  @override
  String get duiConfirmTitle => 'تأكيد';

  @override
  String get duiConfirmBody => 'هل تريد المتابعة؟';

  @override
  String get duiConfirm => 'تأكيد';

  @override
  String duiSource(String name) {
    return 'المصدر: $name';
  }

  @override
  String get duiOpen => 'فتح';

  @override
  String get duiExpand => 'توسيع';

  @override
  String get duiMinimize => 'تصغير';

  @override
  String get duiDismiss => 'إغلاق';

  @override
  String duiPosition(int position, int count, String label) {
    return '$position من $count، $label';
  }

  @override
  String get duiSelected => 'محدد';

  @override
  String get duiPreviewing => 'معاينة';

  @override
  String get duiApplied => 'مطبّق';

  @override
  String get duiThemeApplied => 'تم تطبيق المظهر.';

  @override
  String get duiThemeReset => 'تمت استعادة المظهر الأصلي.';

  @override
  String get duiSelectionsLocal =>
      'تبقى الاختيارات على هذا الجهاز حتى يتمكن المساعد من استقبالها.';

  @override
  String get duiLive => 'مباشر';

  @override
  String get duiUpcoming => 'قادمة';

  @override
  String get duiFinished => 'انتهت';

  @override
  String get duiStepDone => 'تم';

  @override
  String get duiStepRunning => 'قيد التنفيذ';

  @override
  String get duiStepWaiting => 'بانتظار';

  @override
  String get duiStepFailed => 'فشل';

  @override
  String get duiStepCancelled => 'أُلغي';

  @override
  String get duiMapPreview => 'معاينة الخريطة';

  @override
  String duiPages(int count) {
    return '$count صفحات';
  }

  @override
  String get duiCompare => 'مقارنة';

  @override
  String get duiOpenLinkTitle => 'فتح هذا الرابط في المتصفح؟';

  @override
  String get duiStale => 'هذا الخيار لم يعد حاليًا. اطلب خيارات جديدة.';

  @override
  String get duiNotDelivered => 'تعذر إرسال ذلك إلى المساعد. حاول مرة أخرى.';

  @override
  String get duiSend => 'إرسال';

  @override
  String get tcAllow => 'سماح';

  @override
  String get tcNotNow => 'ليس الآن';

  @override
  String get tcWaitingForYou => 'بانتظار موافقتك';

  @override
  String get tcRunning => 'جارٍ التنفيذ…';

  @override
  String get tcSending => 'جارٍ إرسال النتيجة…';

  @override
  String get tcDone => 'تم';

  @override
  String get tcFailed => 'لم يكتمل';

  @override
  String get tcDenied => 'رفضت الطلب';

  @override
  String get tcExpired => 'انتهت المهلة دون رد';

  @override
  String get tcCancelled => 'أُلغي';

  @override
  String get tcClosed => 'هذا الطلب لم يعد مفتوحًا.';

  @override
  String get tcCancelJob => 'إيقاف';

  @override
  String get tcJobStarted => 'بدأ التنفيذ. يمكنك متابعة المحادثة.';

  @override
  String get tcJobQueued => 'بانتظار مكان متاح…';

  @override
  String tcJobWaited(int seconds) {
    return 'الانتظار $seconds ث';
  }

  @override
  String tcUnavailable(String reason) {
    return 'غير متاح: $reason';
  }

  @override
  String tcErrorCode(String code) {
    return 'خطأ: $code';
  }

  @override
  String get tcThemePreview => 'معاينة الألوان الجديدة';

  @override
  String get tcApplyTheme => 'تطبيق';

  @override
  String get tcToolLocation => 'استخدام موقعك الحالي';

  @override
  String get tcToolCamera => 'التقاط صورة';

  @override
  String get tcToolPhoto => 'اختيار صورة';

  @override
  String get tcToolFile => 'اختيار ملف';

  @override
  String get tcToolDirections => 'فتح الاتجاهات في الخرائط';

  @override
  String get tcToolOpenUrl => 'فتح رابط في المتصفح';

  @override
  String get tcToolNetwork => 'التحقق من الاتصال';

  @override
  String get tcToolShare => 'مشاركة';

  @override
  String get tcToolSettings => 'فتح إعدادات التطبيق';

  @override
  String get tcToolTheme => 'تغيير ألوان التطبيق';

  @override
  String get tcToolThemeReset => 'استعادة الألوان الأصلية';

  @override
  String get tcToolPlaces => 'البحث عن أماكن';

  @override
  String get tcToolVision => 'تحليل الصورة';

  @override
  String get tcToolImageGenerate => 'إنشاء صورة';

  @override
  String get tcToolImageEdit => 'تعديل الصورة';

  @override
  String get tcToolOcr => 'قراءة النص من الصورة';

  @override
  String get tcToolFileRead => 'قراءة الملف';

  @override
  String get tcToolFileCreate => 'إنشاء ملف';

  @override
  String get tcToolWeb => 'البحث في الويب';

  @override
  String get tcToolNews => 'البحث في الأخبار';

  @override
  String get tcToolSports => 'التحقق من نتائج المباريات';

  @override
  String get tcToolVideo => 'البحث عن فيديوهات';

  @override
  String get tcToolPalettes => 'عرض ألوان المظهر';

  @override
  String get tcToolJobs => 'التحقق من مهامك';

  @override
  String get tcToolOther => 'أداة المساعد';

  @override
  String get tcProviderBlocked =>
      'هذا المصدر غير متصل بعد، لذلك لا توجد نتائج.';

  @override
  String get tcRateLimited => 'المصدر مشغول. حاول لاحقًا.';

  @override
  String get tcGpuBlocked => 'خدمة الذكاء الاصطناعي لا تستطيع تنفيذ ذلك الآن.';

  @override
  String get tcEncyclopedia => 'مقالات مرجعية (موسوعة)، وليست نتائج ويب مباشرة';

  @override
  String tcSeenAt(String time) {
    return 'أول ظهور $time';
  }

  @override
  String get tcOpenLink => 'فتح';

  @override
  String get tcGenerated => 'صورة مولدة';

  @override
  String tcPurpose(String purpose) {
    return 'السبب: $purpose';
  }

  @override
  String get tcUploadUnavailable => 'المرفقات غير مفعّلة لهذا التطبيق بعد.';

  @override
  String get tcGpuBusy =>
      'خدمة الصور مشغولة الآن (محجوزة للمحادثة الصوتية). حاول مرة أخرى بعد قليل.';

  @override
  String get tcNotEnabled => 'هذه الميزة غير مفعّلة لهذا التطبيق بعد.';

  @override
  String get tcTryAgain => 'حدث خطأ. حاول مرة أخرى.';

  @override
  String get tcDomainNotAllowed => 'هذا الموقع غير مسموح به لهذا التطبيق.';

  @override
  String get tcNotReadable => 'لا يمكن قراءة هذا الملف كنص.';

  @override
  String get tcJobNotFound => 'هذه المهمة لم تعد موجودة.';

  @override
  String get tcCouldNotRun => 'تعذّر على المساعد تنفيذ ذلك.';

  @override
  String get tcAssetDeleted => 'تم حذف الملف';

  @override
  String get tcDeleteAssetTitle => 'حذف هذا الملف؟';

  @override
  String get tcDeleteAssetBody => 'سيُحذف من المحادثة نهائيًا.';

  @override
  String get tcShare => 'مشاركة';

  @override
  String get tcDeleteFailed => 'تعذّر حذف الملف.';

  @override
  String get recTitle => 'سجّل صوتك';

  @override
  String get recIntro =>
      'يُلتقط فقط ما تسجّله الآن، ويُستخدم لإنشاء صوتك الخاص.';

  @override
  String recHint(int min, int max) {
    return 'تحدّث بشكل طبيعي من $min إلى $max ثانية، ثم اضغط إنهاء.';
  }

  @override
  String get recStart => 'ابدأ التسجيل';

  @override
  String get recFinish => 'إنهاء';

  @override
  String get recRecording => 'جارٍ التسجيل';

  @override
  String recMore(int seconds) {
    return 'واصل الحديث: $seconds ث أخرى';
  }

  @override
  String recElapsed(int seconds, int max) {
    return '$seconds من $max ث';
  }

  @override
  String get recUploading => 'جارٍ إرسال التسجيل…';

  @override
  String get recMicDenied =>
      'الوصول إلى الميكروفون متوقف. فعّله من الإعدادات للتسجيل.';

  @override
  String get audioPlay => 'تشغيل';

  @override
  String get audioPause => 'إيقاف مؤقت';

  @override
  String get audioFailed => 'تعذّر تشغيل الصوت.';

  @override
  String get voiceIdentityApplied => 'يتحدث بصوتك';

  @override
  String get voiceIdentityNotApplied => 'لا يُستخدم صوتك في هذه المكالمة';

  @override
  String get voiceSwitching => 'جارٍ التبديل إلى الصوت الجديد…';

  @override
  String get panelExpand => 'فتح بملء الشاشة';

  @override
  String get panelClose => 'إغلاق المساعد';

  @override
  String get panelVoiceVerified => 'صوتك';

  @override
  String get panelWorking => 'جارٍ التنفيذ…';

  @override
  String get panelNeedsApproval => 'يحتاج موافقتك';

  @override
  String get panelOpenToContinue => 'افتح للمتابعة';

  @override
  String get panelShowOptions => 'عرض الخيارات';

  @override
  String get tcJiraNotConnected => 'لم يتم ربط Jira لمؤسستك بعد.';

  @override
  String get tcJiraReconnect => 'يحتاج المسؤول إلى إعادة ربط Jira.';

  @override
  String get tcJiraForbidden => 'ليس لديك صلاحية الوصول إلى هذا في Jira.';

  @override
  String get tcJiraNotFound => 'غير موجود في Jira.';

  @override
  String get tcUnsupportedMedia => 'لا يمكن إرسال هذا النوع من الملفات.';

  @override
  String get tcToolVoiceProfile => 'صوتك';

  @override
  String get tcToolJira => 'Jira';

  @override
  String get voiceOutputSpeaker => 'السماعة الخارجية';

  @override
  String get voiceOutputEarpiece => 'سماعة الهاتف';

  @override
  String get voiceOutputHeadset => 'سماعة الرأس';

  @override
  String get voiceOutputSpeakerTooltip =>
      'السماعة الخارجية مشغّلة. اضغط لاستخدام سماعة الهاتف';

  @override
  String get voiceOutputEarpieceTooltip =>
      'سماعة الهاتف. اضغط لاستخدام السماعة الخارجية';

  @override
  String get voiceOutputHeadsetTooltip =>
      'سماعة الرأس موصولة. اضغط لتغيير سماعة الهاتف عند فصلها';

  @override
  String get voicePhoneCallHold => 'متوقف بسبب مكالمة هاتفية';

  @override
  String get voiceOtherAppHold => 'متوقف: تطبيق آخر يستخدم الصوت';

  @override
  String get voiceResume => 'استئناف';
}
