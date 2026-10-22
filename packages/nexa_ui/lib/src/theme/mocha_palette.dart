import 'dart:ui';

/// Coffee & Mocha semantic colour tokens.
///
/// **Provenance:** the approved prototype (Design QA 3.1, conditional pass)
/// was not available as an exportable file in this workspace, so these hex
/// values are the engineering baseline derived from the written design
/// contract (Coffee & Mocha, Material 3). They live in exactly one place so a
/// token export from the prototype can replace them without touching
/// components. Contrast is enforced by `theme_contrast_test.dart`.
abstract final class MochaPalette {
  // Seed / brand
  static const Color espresso = Color(0xFF3B2A20);
  static const Color mocha = Color(0xFF6F4E37);
  static const Color latte = Color(0xFFC8A27A);
  static const Color cream = Color(0xFFFBF7F2);
  static const Color foam = Color(0xFFF3EBE2);
  static const Color caramel = Color(0xFFB9772E);
  static const Color cocoa = Color(0xFF4E342E);

  // Light scheme
  static const Color lightPrimary = Color(0xFF6F4E37);
  static const Color lightOnPrimary = Color(0xFFFFFFFF);
  static const Color lightPrimaryContainer = Color(0xFFF2DCC8);
  static const Color lightOnPrimaryContainer = Color(0xFF2A1708);
  static const Color lightSecondary = Color(0xFF8A5A2B);
  static const Color lightOnSecondary = Color(0xFFFFFFFF);
  static const Color lightSecondaryContainer = Color(0xFFFFDCC2);
  static const Color lightOnSecondaryContainer = Color(0xFF2E1500);
  static const Color lightTertiary = Color(0xFF5B6B45);
  static const Color lightOnTertiary = Color(0xFFFFFFFF);
  static const Color lightTertiaryContainer = Color(0xFFDFECC2);
  static const Color lightOnTertiaryContainer = Color(0xFF192007);
  static const Color lightError = Color(0xFFB3261E);
  static const Color lightOnError = Color(0xFFFFFFFF);
  static const Color lightErrorContainer = Color(0xFFF9DEDC);
  static const Color lightOnErrorContainer = Color(0xFF410E0B);
  static const Color lightSurface = Color(0xFFFBF7F2);
  static const Color lightOnSurface = Color(0xFF1F1A16);
  static const Color lightSurfaceVariant = Color(0xFFEFE2D6);
  static const Color lightOnSurfaceVariant = Color(0xFF52443B);
  static const Color lightOutline = Color(0xFF85746A);
  static const Color lightOutlineVariant = Color(0xFFD8C3B6);
  static const Color lightSurfaceContainerLowest = Color(0xFFFFFFFF);
  static const Color lightSurfaceContainerLow = Color(0xFFF6F0E9);
  static const Color lightSurfaceContainer = Color(0xFFF0E8DF);
  static const Color lightSurfaceContainerHigh = Color(0xFFEAE1D7);
  static const Color lightSurfaceContainerHighest = Color(0xFFE4DBD0);
  static const Color lightInverseSurface = Color(0xFF352F2A);
  static const Color lightInverseOnSurface = Color(0xFFF8EEE6);
  static const Color lightInversePrimary = Color(0xFFDDB999);

  // Dark scheme
  static const Color darkPrimary = Color(0xFFDDB999);
  static const Color darkOnPrimary = Color(0xFF3E2A18);
  static const Color darkPrimaryContainer = Color(0xFF55402E);
  static const Color darkOnPrimaryContainer = Color(0xFFF2DCC8);
  static const Color darkSecondary = Color(0xFFF2BE8E);
  static const Color darkOnSecondary = Color(0xFF4A2800);
  static const Color darkSecondaryContainer = Color(0xFF6A4219);
  static const Color darkOnSecondaryContainer = Color(0xFFFFDCC2);
  static const Color darkTertiary = Color(0xFFC3D0A7);
  static const Color darkOnTertiary = Color(0xFF2D3619);
  static const Color darkTertiaryContainer = Color(0xFF434D2F);
  static const Color darkOnTertiaryContainer = Color(0xFFDFECC2);
  static const Color darkError = Color(0xFFF2B8B5);
  static const Color darkOnError = Color(0xFF601410);
  static const Color darkErrorContainer = Color(0xFF8C1D18);
  static const Color darkOnErrorContainer = Color(0xFFF9DEDC);
  static const Color darkSurface = Color(0xFF1A1512);
  static const Color darkOnSurface = Color(0xFFEDE3DA);
  static const Color darkSurfaceVariant = Color(0xFF52443B);
  static const Color darkOnSurfaceVariant = Color(0xFFD8C3B6);
  static const Color darkOutline = Color(0xFFA08E82);
  static const Color darkOutlineVariant = Color(0xFF52443B);
  static const Color darkSurfaceContainerLowest = Color(0xFF14100D);
  static const Color darkSurfaceContainerLow = Color(0xFF221C18);
  static const Color darkSurfaceContainer = Color(0xFF27201C);
  static const Color darkSurfaceContainerHigh = Color(0xFF322A26);
  static const Color darkSurfaceContainerHighest = Color(0xFF3D3530);
  static const Color darkInverseSurface = Color(0xFFEDE3DA);
  static const Color darkInverseOnSurface = Color(0xFF352F2A);
  static const Color darkInversePrimary = Color(0xFF6F4E37);

  // Semantic extras used by chat components (not in ColorScheme)
  static const Color lightUserBubble = Color(0xFF6F4E37);
  static const Color lightOnUserBubble = Color(0xFFFFFFFF);
  static const Color lightAssistantBubble = Color(0xFFF0E8DF);
  static const Color lightOnAssistantBubble = Color(0xFF1F1A16);
  static const Color lightSuccess = Color(0xFF2E6B3A);
  static const Color lightOnSuccess = Color(0xFFFFFFFF);
  static const Color lightWarning = Color(0xFF8A5A00);
  static const Color lightOnWarning = Color(0xFFFFFFFF);
  static const Color lightVoiceActive = Color(0xFFB9772E);

  static const Color darkUserBubble = Color(0xFF55402E);
  static const Color darkOnUserBubble = Color(0xFFF2DCC8);
  static const Color darkAssistantBubble = Color(0xFF27201C);
  static const Color darkOnAssistantBubble = Color(0xFFEDE3DA);
  static const Color darkSuccess = Color(0xFF9CD8A6);
  static const Color darkOnSuccess = Color(0xFF0B3A17);
  static const Color darkWarning = Color(0xFFF3C070);
  static const Color darkOnWarning = Color(0xFF3F2A00);
  static const Color darkVoiceActive = Color(0xFFF2BE8E);
}
