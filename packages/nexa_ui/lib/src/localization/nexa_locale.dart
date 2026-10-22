import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:nexa_ui/l10n/generated/nexa_localizations.dart';

/// Locale helpers for the SDK UI.
abstract final class NexaLocale {
  /// Locales the SDK ships strings for.
  static const supported = [Locale('en'), Locale('ar')];

  /// Delegates a host `MaterialApp` or the SDK's own `Localizations` wrapper
  /// must install.
  static const delegates = <LocalizationsDelegate<Object>>[
    NexaLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ];

  /// Parses a BCP-47 tag into a supported [Locale], defaulting to English.
  static Locale fromTag(String tag) {
    final code = tag.split(RegExp('[-_]')).first.toLowerCase();
    return supported.firstWhere(
      (l) => l.languageCode == code,
      orElse: () => const Locale('en'),
    );
  }

  /// Whether [locale] is written right-to-left.
  static bool isRtl(Locale locale) => locale.languageCode == 'ar';

  /// Text direction for [locale].
  static TextDirection directionOf(Locale locale) =>
      isRtl(locale) ? TextDirection.rtl : TextDirection.ltr;
}
