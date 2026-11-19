import 'package:flutter/material.dart';
import 'package:nexa_sdk/nexa_sdk.dart' show NexaColors;

/// LABEEB | لبيب brand palette, owned by this app (not the SDK). The values
/// are the current LABEEB design tokens (Claude Design "nexa-tokens" v2.2,
/// Mocha × Material 3 Expressive). Change them here to re-brand: the SDK
/// chat and voice views inherit this theme.
abstract final class LabeebPalette {
  static const light = ColorScheme(
    brightness: Brightness.light,
    primary: Color(0xFF7B5A49),
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFFEAD9CF),
    onPrimaryContainer: Color(0xFF2E1C13),
    secondary: Color(0xFF9E7A63),
    onSecondary: Color(0xFFFFFFFF),
    secondaryContainer: Color(0xFFF2E2D8),
    onSecondaryContainer: Color(0xFF3A271B),
    tertiary: Color(0xFF6E5B49),
    onTertiary: Color(0xFFFFFFFF),
    tertiaryContainer: Color(0xFFE9DCCF),
    onTertiaryContainer: Color(0xFF2B2016),
    error: Color(0xFFB3261E),
    onError: Color(0xFFFFFFFF),
    errorContainer: Color(0xFFF9DEDC),
    onErrorContainer: Color(0xFF410E0B),
    surface: Color(0xFFF7F3F0),
    onSurface: Color(0xFF211915),
    onSurfaceVariant: Color(0xFF72635D),
    outline: Color(0xFF8E7D75),
    outlineVariant: Color(0xFFDDCEC4),
    surfaceContainerLowest: Color(0xFFFFFFFF),
    surfaceContainerLow: Color(0xFFFAF6F3),
    surfaceContainer: Color(0xFFF4EDE8),
    surfaceContainerHigh: Color(0xFFEEE5DF),
    surfaceContainerHighest: Color(0xFFE8DDD6),
    inverseSurface: Color(0xFF362E2A),
    inversePrimary: Color(0xFFBD9075),
    onInverseSurface: Color(0xFFF7EFEA),
  );

  static const dark = ColorScheme(
    brightness: Brightness.dark,
    primary: Color(0xFFBD9075),
    onPrimary: Color(0xFF2A1A10),
    primaryContainer: Color(0xFF2C211B),
    onPrimaryContainer: Color(0xFFF2DCCD),
    secondary: Color(0xFFD4AD90),
    onSecondary: Color(0xFF3A2A21),
    secondaryContainer: Color(0xFF3A2A21),
    onSecondaryContainer: Color(0xFFF4DFD0),
    tertiary: Color(0xFFE7D2C1),
    onTertiary: Color(0xFF3B3029),
    tertiaryContainer: Color(0xFF3B3029),
    onTertiaryContainer: Color(0xFFF5E7DC),
    error: Color(0xFFFFB4AB),
    onError: Color(0xFF690005),
    errorContainer: Color(0xFF4A1A16),
    onErrorContainer: Color(0xFFFFDAD6),
    surface: Color(0xFF110D0B),
    onSurface: Color(0xFFF7EFEA),
    onSurfaceVariant: Color(0xFFC0AEA5),
    outline: Color(0xFF8A766C),
    outlineVariant: Color(0xFF3D2F28),
    surfaceContainerLowest: Color(0xFF0C0908),
    surfaceContainerLow: Color(0xFF161110),
    surfaceContainer: Color(0xFF1B1512),
    surfaceContainerHigh: Color(0xFF251D18),
    surfaceContainerHighest: Color(0xFF30251F),
    inverseSurface: Color(0xFFF7EFEA),
    inversePrimary: Color(0xFF7B5A49),
    onInverseSurface: Color(0xFF211915),
  );

  /// Bubble and status roles for the SDK views (optional: without them the
  /// SDK derives the roles from the colour scheme).
  static const lightRoles = NexaColors(
    userBubble: Color(0xFF7B5A49),
    onUserBubble: Color(0xFFFFFFFF),
    assistantBubble: Color(0xFFF4EDE8),
    onAssistantBubble: Color(0xFF211915),
    success: Color(0xFF3B6B4C),
    onSuccess: Color(0xFFFFFFFF),
    warning: Color(0xFF8A5A12),
    onWarning: Color(0xFFFFFFFF),
    voiceActive: Color(0xFF7B5A49),
    successContainer: Color(0xFFDCEBDD),
    warningContainer: Color(0xFFF8E5C6),
    info: Color(0xFF35657A),
    infoContainer: Color(0xFFD9E8EF),
  );

  static const darkRoles = NexaColors(
    userBubble: Color(0xFFBD9075),
    onUserBubble: Color(0xFF2A1A10),
    assistantBubble: Color(0xFF1B1512),
    onAssistantBubble: Color(0xFFF7EFEA),
    success: Color(0xFFA3D1B0),
    onSuccess: Color(0xFF1F3326),
    warning: Color(0xFFEEC27E),
    onWarning: Color(0xFF3A2B12),
    voiceActive: Color(0xFFBD9075),
    successContainer: Color(0xFF1F3326),
    warningContainer: Color(0xFF3A2B12),
    info: Color(0xFFA8CCDD),
    infoContainer: Color(0xFF1D2E36),
  );
}
