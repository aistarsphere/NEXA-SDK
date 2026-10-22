import 'package:flutter/foundation.dart';
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
  });

  final String languageTag;
  final NexaThemeOverrides themeOverrides;
  final NexaThemeMode themeMode;

  NexaUiSettings copyWith({
    String? languageTag,
    NexaThemeOverrides? themeOverrides,
    NexaThemeMode? themeMode,
  }) => NexaUiSettings(
    languageTag: languageTag ?? this.languageTag,
    themeOverrides: themeOverrides ?? this.themeOverrides,
    themeMode: themeMode ?? this.themeMode,
  );
}

/// Light/dark preference.
enum NexaThemeMode { system, light, dark }
