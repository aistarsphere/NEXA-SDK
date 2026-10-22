import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

/// Build-time switches for the example host app.
///
/// * `--dart-define=NEXA_GATEWAY_URL=http://host:port` points the SDK at a
///   gateway. Default: the local reference gateway (`make gateway`) on the
///   loopback address appropriate for the platform (Android emulators reach
///   the host through 10.0.2.2).
/// * `--dart-define=NEXA_USE_MOCK=true` swaps the gateway for the in-memory
///   `MockChatTransport` (no server needed). Mock only; never production.
abstract final class ExampleConfig {
  static const String applicationId = 'app_example_host';

  static const bool useMock = bool.fromEnvironment('NEXA_USE_MOCK');

  static const String _gatewayOverride = String.fromEnvironment(
    'NEXA_GATEWAY_URL',
  );

  static Uri get gatewayUri {
    if (_gatewayOverride.isNotEmpty) return Uri.parse(_gatewayOverride);
    final host = !kIsWeb && Platform.isAndroid ? '10.0.2.2' : '127.0.0.1';
    return Uri.parse('http://$host:8080');
  }
}
