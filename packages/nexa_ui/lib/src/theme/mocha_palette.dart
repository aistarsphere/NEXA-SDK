import 'dart:ui';

/// Coffee & Mocha semantic colour tokens.
///
/// **Provenance:** `nexa-tokens.css` v2.2 ("Mocha × Material 3 Expressive")
/// from the NEXA Claude Design project, the design team's token export. CSS
/// names are noted next to each role (`--s0`…`--s4` are the surface
/// containers). They live in exactly one place so a later export can replace
/// them without touching components. Contrast is enforced by
/// `theme_contrast_test.dart`.
abstract final class MochaPalette {
  // Seed / brand
  static const Color espresso = Color(0xFF2E1C13);
  static const Color mocha = Color(0xFF7B5A49);
  static const Color latte = Color(0xFFBD9075);
  static const Color cream = Color(0xFFF7F3F0);
  static const Color foam = Color(0xFFEFE7E2);
  static const Color caramel = Color(0xFF9E7A63);
  static const Color cocoa = Color(0xFF65493C);

  // Light scheme
  static const Color lightPrimary = Color(0xFF7B5A49); // --p
  static const Color lightOnPrimary = Color(0xFFFFFFFF); // --on-p
  static const Color lightPrimaryContainer = Color(0xFFEAD9CF); // --pc
  static const Color lightOnPrimaryContainer = Color(0xFF2E1C13); // --on-pc
  static const Color lightSecondary = Color(0xFF9E7A63); // --sec
  static const Color lightOnSecondary = Color(0xFFFFFFFF);
  static const Color lightSecondaryContainer = Color(0xFFF2E2D8); // --sec-c
  static const Color lightOnSecondaryContainer = Color(0xFF3A271B);
  static const Color lightTertiary = Color(0xFF6E5B49); // --ter
  static const Color lightOnTertiary = Color(0xFFFFFFFF);
  static const Color lightTertiaryContainer = Color(0xFFE9DCCF); // --ter-c
  static const Color lightOnTertiaryContainer = Color(0xFF2B2016);
  static const Color lightError = Color(0xFFB3261E); // --err
  static const Color lightOnError = Color(0xFFFFFFFF);
  static const Color lightErrorContainer = Color(0xFFF9DEDC); // --err-c
  static const Color lightOnErrorContainer = Color(0xFF410E0B);
  static const Color lightSurface = Color(0xFFF7F3F0); // --bg
  static const Color lightOnSurface = Color(0xFF211915); // --on
  static const Color lightSurfaceVariant = Color(0xFFEEE5DF);
  static const Color lightOnSurfaceVariant = Color(0xFF72635D); // --on-var
  static const Color lightOutline = Color(0xFF8E7D75); // --ol
  static const Color lightOutlineVariant = Color(0xFFDDCEC4); // --olv
  static const Color lightSurfaceContainerLowest = Color(0xFFFFFFFF); // --s0
  static const Color lightSurfaceContainerLow = Color(0xFFFAF6F3); // --s1
  static const Color lightSurfaceContainer = Color(0xFFF4EDE8); // --s2
  static const Color lightSurfaceContainerHigh = Color(0xFFEEE5DF); // --s3
  static const Color lightSurfaceContainerHighest = Color(0xFFE8DDD6); // --s4
  static const Color lightInverseSurface = Color(0xFF362E2A); // --inv
  static const Color lightInverseOnSurface = Color(0xFFF7EFEA); // --on-inv
  static const Color lightInversePrimary = Color(0xFFBD9075);

  // Dark scheme
  static const Color darkPrimary = Color(0xFFBD9075);
  static const Color darkOnPrimary = Color(0xFF2A1A10);
  static const Color darkPrimaryContainer = Color(0xFF2C211B);
  static const Color darkOnPrimaryContainer = Color(0xFFF2DCCD);
  static const Color darkSecondary = Color(0xFFD4AD90);
  static const Color darkOnSecondary = Color(0xFF3A2A21);
  static const Color darkSecondaryContainer = Color(0xFF3A2A21);
  static const Color darkOnSecondaryContainer = Color(0xFFF4DFD0);
  static const Color darkTertiary = Color(0xFFE7D2C1);
  static const Color darkOnTertiary = Color(0xFF3B3029);
  static const Color darkTertiaryContainer = Color(0xFF3B3029);
  static const Color darkOnTertiaryContainer = Color(0xFFF5E7DC);
  static const Color darkError = Color(0xFFFFB4AB);
  static const Color darkOnError = Color(0xFF690005);
  static const Color darkErrorContainer = Color(0xFF4A1A16);
  static const Color darkOnErrorContainer = Color(0xFFFFDAD6);
  static const Color darkSurface = Color(0xFF110D0B);
  static const Color darkOnSurface = Color(0xFFF7EFEA);
  static const Color darkSurfaceVariant = Color(0xFF251D18);
  static const Color darkOnSurfaceVariant = Color(0xFFC0AEA5);
  static const Color darkOutline = Color(0xFF8A766C);
  static const Color darkOutlineVariant = Color(0xFF3D2F28);
  static const Color darkSurfaceContainerLowest = Color(0xFF0C0908);
  static const Color darkSurfaceContainerLow = Color(0xFF161110);
  static const Color darkSurfaceContainer = Color(0xFF1B1512);
  static const Color darkSurfaceContainerHigh = Color(0xFF251D18);
  static const Color darkSurfaceContainerHighest = Color(0xFF30251F);
  static const Color darkInverseSurface = Color(0xFFF7EFEA);
  static const Color darkInverseOnSurface = Color(0xFF211915);
  static const Color darkInversePrimary = Color(0xFF7B5A49);

  // Semantic extras used by chat and voice components (not in ColorScheme)
  static const Color lightUserBubble = Color(0xFF7B5A49);
  static const Color lightOnUserBubble = Color(0xFFFFFFFF);
  static const Color lightAssistantBubble = Color(0xFFF4EDE8);
  static const Color lightOnAssistantBubble = Color(0xFF211915);
  static const Color lightSuccess = Color(0xFF3B6B4C); // --ok
  static const Color lightOnSuccess = Color(0xFFFFFFFF);
  static const Color lightSuccessContainer = Color(0xFFDCEBDD); // --ok-c
  static const Color lightWarning = Color(0xFF8A5A12); // --warn
  static const Color lightOnWarning = Color(0xFFFFFFFF);
  static const Color lightWarningContainer = Color(0xFFF8E5C6); // --warn-c
  static const Color lightInfo = Color(0xFF35657A); // --info
  static const Color lightInfoContainer = Color(0xFFD9E8EF); // --info-c
  static const Color lightVoiceActive = Color(0xFF7B5A49);

  static const Color darkUserBubble = Color(0xFFBD9075);
  static const Color darkOnUserBubble = Color(0xFF2A1A10);
  static const Color darkAssistantBubble = Color(0xFF1B1512);
  static const Color darkOnAssistantBubble = Color(0xFFF7EFEA);
  static const Color darkSuccess = Color(0xFFA3D1B0);
  static const Color darkOnSuccess = Color(0xFF1F3326);
  static const Color darkSuccessContainer = Color(0xFF1F3326);
  static const Color darkWarning = Color(0xFFEEC27E);
  static const Color darkOnWarning = Color(0xFF3A2B12);
  static const Color darkWarningContainer = Color(0xFF3A2B12);
  static const Color darkInfo = Color(0xFFA8CCDD);
  static const Color darkInfoContainer = Color(0xFF1D2E36);
  static const Color darkVoiceActive = Color(0xFFBD9075);
}
