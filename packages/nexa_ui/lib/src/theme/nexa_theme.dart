import 'package:flutter/material.dart';
import 'package:nexa_ui/src/theme/mocha_palette.dart';
import 'package:nexa_ui/src/theme/nexa_colors.dart';
import 'package:nexa_ui/src/theme/nexa_shapes.dart';
import 'package:nexa_ui/src/theme/nexa_theme_overrides.dart';
import 'package:nexa_ui/src/theme/nexa_typography.dart';

/// Builds the NEXA Material 3 Expressive [ThemeData].
///
/// Usage inside the SDK: `NexaTheme.light(locale)` / `NexaTheme.dark(locale)`.
/// Hosts never construct the theme directly; they pass [NexaThemeOverrides]
/// through the SDK configuration.
abstract final class NexaTheme {
  /// Light theme.
  static ThemeData light(
    Locale locale, {
    NexaThemeOverrides overrides = NexaThemeOverrides.none,
  }) => _build(Brightness.light, locale, overrides);

  /// Dark theme.
  static ThemeData dark(
    Locale locale, {
    NexaThemeOverrides overrides = NexaThemeOverrides.none,
  }) => _build(Brightness.dark, locale, overrides);

  /// Picks light or dark for [brightness] honouring the override.
  static ThemeData forBrightness(
    Brightness brightness,
    Locale locale, {
    NexaThemeOverrides overrides = NexaThemeOverrides.none,
  }) {
    final effective = overrides.brightnessOverride ?? brightness;
    return effective == Brightness.dark
        ? dark(locale, overrides: overrides)
        : light(locale, overrides: overrides);
  }

  static ColorScheme _scheme(Brightness brightness, NexaThemeOverrides o) {
    final isDark = brightness == Brightness.dark;
    final base = isDark
        ? const ColorScheme(
            brightness: Brightness.dark,
            primary: MochaPalette.darkPrimary,
            onPrimary: MochaPalette.darkOnPrimary,
            primaryContainer: MochaPalette.darkPrimaryContainer,
            onPrimaryContainer: MochaPalette.darkOnPrimaryContainer,
            secondary: MochaPalette.darkSecondary,
            onSecondary: MochaPalette.darkOnSecondary,
            secondaryContainer: MochaPalette.darkSecondaryContainer,
            onSecondaryContainer: MochaPalette.darkOnSecondaryContainer,
            tertiary: MochaPalette.darkTertiary,
            onTertiary: MochaPalette.darkOnTertiary,
            tertiaryContainer: MochaPalette.darkTertiaryContainer,
            onTertiaryContainer: MochaPalette.darkOnTertiaryContainer,
            error: MochaPalette.darkError,
            onError: MochaPalette.darkOnError,
            errorContainer: MochaPalette.darkErrorContainer,
            onErrorContainer: MochaPalette.darkOnErrorContainer,
            surface: MochaPalette.darkSurface,
            onSurface: MochaPalette.darkOnSurface,
            onSurfaceVariant: MochaPalette.darkOnSurfaceVariant,
            outline: MochaPalette.darkOutline,
            outlineVariant: MochaPalette.darkOutlineVariant,
            surfaceContainerLowest: MochaPalette.darkSurfaceContainerLowest,
            surfaceContainerLow: MochaPalette.darkSurfaceContainerLow,
            surfaceContainer: MochaPalette.darkSurfaceContainer,
            surfaceContainerHigh: MochaPalette.darkSurfaceContainerHigh,
            surfaceContainerHighest: MochaPalette.darkSurfaceContainerHighest,
            inverseSurface: MochaPalette.darkInverseSurface,
            onInverseSurface: MochaPalette.darkInverseOnSurface,
            inversePrimary: MochaPalette.darkInversePrimary,
          )
        : const ColorScheme(
            brightness: Brightness.light,
            primary: MochaPalette.lightPrimary,
            onPrimary: MochaPalette.lightOnPrimary,
            primaryContainer: MochaPalette.lightPrimaryContainer,
            onPrimaryContainer: MochaPalette.lightOnPrimaryContainer,
            secondary: MochaPalette.lightSecondary,
            onSecondary: MochaPalette.lightOnSecondary,
            secondaryContainer: MochaPalette.lightSecondaryContainer,
            onSecondaryContainer: MochaPalette.lightOnSecondaryContainer,
            tertiary: MochaPalette.lightTertiary,
            onTertiary: MochaPalette.lightOnTertiary,
            tertiaryContainer: MochaPalette.lightTertiaryContainer,
            onTertiaryContainer: MochaPalette.lightOnTertiaryContainer,
            error: MochaPalette.lightError,
            onError: MochaPalette.lightOnError,
            errorContainer: MochaPalette.lightErrorContainer,
            onErrorContainer: MochaPalette.lightOnErrorContainer,
            surface: MochaPalette.lightSurface,
            onSurface: MochaPalette.lightOnSurface,
            onSurfaceVariant: MochaPalette.lightOnSurfaceVariant,
            outline: MochaPalette.lightOutline,
            outlineVariant: MochaPalette.lightOutlineVariant,
            surfaceContainerLowest: MochaPalette.lightSurfaceContainerLowest,
            surfaceContainerLow: MochaPalette.lightSurfaceContainerLow,
            surfaceContainer: MochaPalette.lightSurfaceContainer,
            surfaceContainerHigh: MochaPalette.lightSurfaceContainerHigh,
            surfaceContainerHighest: MochaPalette.lightSurfaceContainerHighest,
            inverseSurface: MochaPalette.lightInverseSurface,
            onInverseSurface: MochaPalette.lightInverseOnSurface,
            inversePrimary: MochaPalette.lightInversePrimary,
          );

    final seed = o.seedColor;
    if (seed == null) return base;
    // Brand seed: derive accent roles, keep Mocha neutrals/surfaces.
    final seeded = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
    );
    return base.copyWith(
      primary: seeded.primary,
      onPrimary: seeded.onPrimary,
      primaryContainer: seeded.primaryContainer,
      onPrimaryContainer: seeded.onPrimaryContainer,
      secondary: seeded.secondary,
      onSecondary: seeded.onSecondary,
      secondaryContainer: seeded.secondaryContainer,
      onSecondaryContainer: seeded.onSecondaryContainer,
      tertiary: seeded.tertiary,
      onTertiary: seeded.onTertiary,
      tertiaryContainer: seeded.tertiaryContainer,
      onTertiaryContainer: seeded.onTertiaryContainer,
      inversePrimary: seeded.inversePrimary,
    );
  }

  static NexaColors _nexaColors(
    Brightness brightness,
    ColorScheme scheme,
    NexaThemeOverrides o,
  ) {
    final base = brightness == Brightness.dark
        ? NexaColors.dark
        : NexaColors.light;
    final seeded = o.seedColor != null
        ? base.copyWith(
            userBubble: scheme.primary,
            onUserBubble: scheme.onPrimary,
          )
        : base;
    final bubble = o.userBubbleColor;
    if (bubble == null) return seeded;
    final onBubble =
        ThemeData.estimateBrightnessForColor(bubble) == Brightness.dark
        ? Colors.white
        : MochaPalette.espresso;
    return seeded.copyWith(userBubble: bubble, onUserBubble: onBubble);
  }

  static ThemeData _build(
    Brightness brightness,
    Locale locale,
    NexaThemeOverrides o,
  ) {
    final scheme = _scheme(brightness, o);
    final r = o.cornerScale;
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      brightness: brightness,
      fontFamily: NexaTypography.familyFor(locale),
      package: NexaTypography.package,
    );
    final textTheme = NexaTypography.textTheme(base.textTheme, locale);
    RoundedRectangleBorder rounded(double radius) =>
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius * r));

    return base.copyWith(
      textTheme: textTheme,
      scaffoldBackgroundColor: scheme.surface,
      extensions: [_nexaColors(brightness, scheme, o)],
      visualDensity: VisualDensity.standard,
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge?.copyWith(color: scheme.onSurface),
      ),
      cardTheme: CardThemeData(
        color: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: rounded(NexaShapes.extraLarge),
      ),
      chipTheme: ChipThemeData(
        shape: rounded(NexaShapes.full),
        side: BorderSide(color: scheme.outlineVariant),
        labelStyle: textTheme.labelLarge,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: rounded(NexaShapes.full),
          minimumSize: const Size(48, 48),
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: rounded(NexaShapes.full),
          minimumSize: const Size(48, 48),
          side: BorderSide(color: scheme.outline),
          textStyle: textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: rounded(NexaShapes.full),
          minimumSize: const Size(48, 40),
          textStyle: textTheme.labelLarge,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHigh,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(NexaShapes.extraLarge * r),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(NexaShapes.extraLarge * r),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(NexaShapes.extraLarge * r),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 14,
        ),
        hintStyle: textTheme.bodyLarge?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: rounded(NexaShapes.large),
      ),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant, space: 1),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: scheme.primary),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(NexaShapes.extraLarge),
          ),
        ),
      ),
    );
  }
}
