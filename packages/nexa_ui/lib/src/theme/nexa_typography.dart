import 'package:flutter/material.dart';

/// Bilingual typography. Noto Sans for Latin scripts, Tajawal for Arabic.
/// Both fonts are bundled with `nexa_ui`, so no network fetch happens.
abstract final class NexaTypography {
  static const String latinFamily = 'NotoSans';
  static const String arabicFamily = 'Tajawal';
  static const String package = 'nexa_ui';

  /// Font family for [locale].
  static String familyFor(Locale locale) =>
      locale.languageCode == 'ar' ? arabicFamily : latinFamily;

  /// Builds the M3 text theme for [locale] on top of [base].
  ///
  /// Tajawal renders slightly smaller than Noto Sans at equal point size, so
  /// Arabic body styles get a small height bump for comfortable line spacing.
  static TextTheme textTheme(TextTheme base, Locale locale) {
    final family = familyFor(locale);
    final isArabic = locale.languageCode == 'ar';
    final themed = base.apply(fontFamily: family, package: package);
    if (!isArabic) return themed;
    return themed.copyWith(
      bodyLarge: themed.bodyLarge?.copyWith(height: 1.6),
      bodyMedium: themed.bodyMedium?.copyWith(height: 1.6),
      bodySmall: themed.bodySmall?.copyWith(height: 1.5),
      labelLarge: themed.labelLarge?.copyWith(height: 1.4),
    );
  }
}
