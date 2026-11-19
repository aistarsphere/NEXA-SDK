import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:nexa_sdk/nexa_sdk.dart'
    show NexaAssistantFeatures, NexaLaunchMode;

/// Build-time switches for the example host app.
///
/// * `--dart-define=NEXA_GATEWAY_URL=http://host:port` points the SDK at a
///   gateway. Default: the local reference gateway (`make gateway`) on the
///   loopback address appropriate for the platform (Android emulators reach
///   the host through 10.0.2.2).
/// * `--dart-define=NEXA_USE_MOCK=true` swaps the gateway for the in-memory
///   `MockChatTransport` (no server needed). Mock only; never production.
/// * `--dart-define=NEXA_REAL_BACKEND=true` targets the real NEXA backend at
///   `NEXA_GATEWAY_URL` (must be https) with application `NEXA_APP_ID`. The
///   SDK token comes from the development-only `DevTokenAuthProvider`, filled
///   from `NEXA_DEV_SDK_TOKEN` / `NEXA_DEV_SDK_TOKEN_EXPIRES_AT` in a secrets
///   file passed with `--dart-define-from-file` (`~/.nexa/nexa_dev.json`, or
///   the git-ignored `config/nexa_dev.json`; template
///   `config/nexa_dev.example.json`). There is no in-app token entry. Never
///   commit a token.
/// * `--dart-define=NEXA_LANGUAGE=ar` sets the initial SDK language.
/// * `--dart-define=NEXA_DEV_TOOLS=true` keeps the developer tools (token
///   file, gateway diagnostics, the SDK playground) in a profile/release
///   build. Debug builds always have them; production builds never should.
abstract final class ExampleConfig {
  /// Developer tools: build-time SDK token, diagnostics, the SDK playground.
  static const bool devTools =
      kDebugMode || bool.fromEnvironment('NEXA_DEV_TOOLS');

  static const String appVersion = '1.1.0';

  /// What the assistant opens with: `list` (default: the conversation
  /// list), `chat`, `voice` or `home` (`--dart-define=NEXA_LAUNCH_MODE=home`).
  static NexaLaunchMode get launchMode =>
      switch (const String.fromEnvironment('NEXA_LAUNCH_MODE')) {
        'voice' => NexaLaunchMode.voice,
        'home' => NexaLaunchMode.home,
        'chat' => NexaLaunchMode.chat,
        _ => NexaLaunchMode.list,
      };

  /// Feature visibility (`--dart-define=NEXA_SHOW_VOICE=false` …). These only
  /// hide features; the backend still enforces what a session may do.
  static const NexaAssistantFeatures features = NexaAssistantFeatures(
    voice: bool.fromEnvironment('NEXA_SHOW_VOICE', defaultValue: true),
    newConversation: bool.fromEnvironment(
      'NEXA_SHOW_NEW_CONVERSATION',
      defaultValue: true,
    ),
    suggestions: bool.fromEnvironment(
      'NEXA_SHOW_SUGGESTIONS',
      defaultValue: true,
    ),
  );

  static const String applicationId = String.fromEnvironment(
    'NEXA_APP_ID',
    defaultValue: 'app_example_host',
  );

  static const bool useMock = bool.fromEnvironment('NEXA_USE_MOCK');

  static const bool realBackend =
      bool.fromEnvironment('NEXA_REAL_BACKEND') && !useMock;

  static const String initialLanguage = String.fromEnvironment(
    'NEXA_LANGUAGE',
    defaultValue: realBackend ? 'ar' : 'en',
  );

  /// Build-time development token; ignored unless [devTools] is on, so a
  /// production binary never carries one.
  static const String devSdkToken = devTools
      ? String.fromEnvironment('NEXA_DEV_SDK_TOKEN')
      : '';

  static DateTime? get devSdkTokenExpiresAt => DateTime.tryParse(
    const String.fromEnvironment('NEXA_DEV_SDK_TOKEN_EXPIRES_AT'),
  );

  static const String _gatewayOverride = String.fromEnvironment(
    'NEXA_GATEWAY_URL',
  );

  static Uri get gatewayUri {
    if (_gatewayOverride.isNotEmpty) return Uri.parse(_gatewayOverride);
    final host = !kIsWeb && Platform.isAndroid ? '10.0.2.2' : '127.0.0.1';
    return Uri.parse('http://$host:8080');
  }

  /// Fails fast on a real-backend build that would send credentials in clear
  /// text or has no application id.
  static void validate() {
    if (!realBackend) return;
    if (gatewayUri.scheme != 'https') {
      throw StateError('NEXA_REAL_BACKEND needs an https NEXA_GATEWAY_URL.');
    }
    if (applicationId == 'app_example_host') {
      throw StateError('NEXA_REAL_BACKEND needs NEXA_APP_ID.');
    }
  }
}
