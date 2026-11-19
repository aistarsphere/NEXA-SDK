import 'package:flutter/material.dart';
import 'package:nexa_ui/nexa_ui.dart';

/// Runtime-adjustable presentation settings (language, theme overrides,
/// brightness). Held by `NexaClient` and observed by the chat UI, so a host
/// can switch language or branding without re-initialising the SDK.
@immutable
final class NexaUiSettings {
  const NexaUiSettings({
    required this.languageTag,
    this.themeOverrides = NexaThemeOverrides.none,
    this.themeMode = NexaThemeMode.system,
    this.themeSource = NexaThemeSource.host,
  });

  final String languageTag;
  final NexaThemeOverrides themeOverrides;
  final NexaThemeMode themeMode;

  /// Where the SDK views take their theme from (default: the host app).
  final NexaThemeSource themeSource;

  NexaUiSettings copyWith({
    String? languageTag,
    NexaThemeOverrides? themeOverrides,
    NexaThemeMode? themeMode,
    NexaThemeSource? themeSource,
  }) => NexaUiSettings(
    languageTag: languageTag ?? this.languageTag,
    themeOverrides: themeOverrides ?? this.themeOverrides,
    themeMode: themeMode ?? this.themeMode,
    themeSource: themeSource ?? this.themeSource,
  );

  /// The theme for SDK views at [context]: the host's `ThemeData` adapted
  /// with the SDK roles ([NexaThemeSource.host]), or the SDK's built-in
  /// theme for [locale] and [themeMode] ([NexaThemeSource.builtIn]).
  /// [themeOverrides] apply to both.
  ThemeData resolveTheme(BuildContext context, Locale locale) {
    switch (themeSource) {
      case NexaThemeSource.host:
        return NexaTheme.adapt(Theme.of(context), overrides: themeOverrides);
      case NexaThemeSource.builtIn:
        final brightness = switch (themeMode) {
          NexaThemeMode.light => Brightness.light,
          NexaThemeMode.dark => Brightness.dark,
          NexaThemeMode.system => MediaQuery.platformBrightnessOf(context),
        };
        return NexaTheme.forBrightness(
          brightness,
          locale,
          overrides: themeOverrides,
        );
    }
  }
}

/// Light/dark preference.
enum NexaThemeMode { system, light, dark }

/// Theme source of the SDK views.
enum NexaThemeSource {
  /// Inherit the host app's `ThemeData` (colours, fonts, component themes);
  /// the SDK adds its own roles (bubbles, status colours) derived from it.
  /// [NexaThemeMode] is then the host's business (its `MaterialApp`).
  host,

  /// The SDK's built-in neutral theme, following [NexaThemeMode].
  builtIn,
}
