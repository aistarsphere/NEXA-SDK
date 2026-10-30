import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nexa_example/brand/labeeb_palette.dart';
import 'package:nexa_sdk/nexa_sdk.dart';

/// LABEEB | لبيب: the customer-facing brand of this app. The assistant
/// engine underneath is the brand-neutral NEXA SDK; everything visible here
/// (name, logo, colours, fonts) is supplied by the app.
abstract final class Labeeb {
  static const nameEn = 'LABEEB';
  static const nameAr = 'لبيب';

  /// Final logo goes here (square PNG, transparent background, ≥ 512 px).
  /// Until the file exists the app shows a text mark ("L" / "ل").
  static const logoAsset = 'assets/brand/labeeb_logo.png';

  static bool _hasLogo = false;

  /// Checks once at start-up whether [logoAsset] is bundled.
  static Future<void> loadAssets() async {
    try {
      await rootBundle.load(logoAsset);
      _hasLogo = true;
    } on Object {
      _hasLogo = false; // text fallback
    }
  }

  static String name(String languageCode) =>
      languageCode == 'ar' ? nameAr : nameEn;

  /// What the company set for this application (`GET /assistant`), once
  /// loaded. Unset values keep LABEEB's own.
  static final profile = ValueNotifier<LabeebAssistantProfile?>(null);

  /// Reads the company profile in the background (never delays start).
  static Future<void> loadProfile(NexaClient client) async {
    try {
      profile.value = await client.api.assistantProfile().timeout(
        const Duration(seconds: 8),
      );
    } on Object {
      // Offline or not configured: the app's own brand stays.
    }
  }

  /// The brand as shown by the SDK assistant (header, home).
  static NexaBrand get brand => NexaBrand(
    name: profile.value?.assistantName ?? nameEn,
    localizedNames: profile.value?.assistantName == null
        ? const {'ar': nameAr}
        : const {},
    subtitle: profile.value?.welcomeMessage ?? 'Your assistant',
    localizedSubtitles: profile.value?.welcomeMessage == null
        ? const {'ar': 'مساعدك الذكي'}
        : const {},
    logoBuilder: _hasLogo
        ? (context, size) => Image.asset(
            logoAsset,
            width: size,
            height: size,
            fit: BoxFit.contain,
          )
        : null,
  );
}

/// Apps LABEEB lets the assistant open, with their verified ways to open
/// them. Custom schemes are declared in Info.plist
/// (`LSApplicationQueriesSchemes`) and AndroidManifest `<queries>`.
abstract final class LabeebApps {
  static final allowlist = [
    NexaAppTarget(
      id: 'google_maps',
      name: 'Google Maps',
      iosUri: Uri.parse('comgooglemaps://'),
      androidUri: Uri.parse('https://maps.google.com/'),
      fallbackUri: Uri.parse('https://www.google.com/maps'),
    ),
    NexaAppTarget(
      id: 'apple_maps',
      name: 'Apple Maps',
      iosUri: Uri.parse('maps://'),
    ),
    NexaAppTarget(
      id: 'waze',
      name: 'Waze',
      iosUri: Uri.parse('waze://'),
      androidUri: Uri.parse('waze://'),
      fallbackUri: Uri.parse('https://www.waze.com/'),
    ),
  ];
}

/// LABEEB's app theme. The SDK views inherit it (`NexaThemeSource.host`).
abstract final class LabeebTheme {
  /// Fonts. LABEEB currently uses the families bundled with the SDK UI
  /// package; to use brand fonts, add the files under `assets/fonts/`,
  /// declare them in pubspec.yaml and set [fontPackage] to ''.
  static const latinFont = 'NotoSans';
  static const arabicFont = 'Tajawal';
  static const fontPackage = 'nexa_ui';

  static ThemeData light(Locale locale) =>
      fromColors(LabeebPalette.light, LabeebPalette.lightRoles, locale);

  static ThemeData dark(Locale locale) =>
      fromColors(LabeebPalette.dark, LabeebPalette.darkRoles, locale);

  /// LABEEB's theme for any palette (see `LabeebThemeController`).
  static ThemeData fromColors(
    ColorScheme scheme,
    NexaColors roles,
    Locale locale,
  ) {
    final arabic = locale.languageCode == 'ar';
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: arabic ? arabicFont : latinFont,
      package: fontPackage.isEmpty ? null : fontPackage,
    );
    return base.copyWith(
      scaffoldBackgroundColor: scheme.surface,
      extensions: [roles],
      textTheme: arabic
          ? base.textTheme.copyWith(
              bodyLarge: base.textTheme.bodyLarge?.copyWith(height: 1.6),
              bodyMedium: base.textTheme.bodyMedium?.copyWith(height: 1.6),
            )
          : base.textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
