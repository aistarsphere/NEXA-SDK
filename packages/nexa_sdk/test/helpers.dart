import 'dart:async';

import 'package:nexa_core/testing.dart';
import 'package:nexa_sdk/nexa_sdk.dart';

NexaConfig testConfig({
  String lang = 'en',
  Uri? gateway,
  NexaEventDelivery delivery = NexaEventDelivery.serverSentEvents,
  int maxReconnectAttempts = 5,
  Duration eventPollInterval = const Duration(milliseconds: 1),
}) => NexaConfig(
  applicationId: 'app_test',
  gatewayBaseUri: gateway ?? Uri.parse('http://localhost:1'),
  environment: NexaEnvironment.development,
  languageTag: lang,
  requestedCapabilities: const {
    NexaCapability.textChat,
    NexaCapability.toolCalling,
    NexaCapability.richResults,
  },
  eventDelivery: delivery,
  eventPollInterval: eventPollInterval,
  maxReconnectAttempts: maxReconnectAttempts,
);

MockChatTransport fastMock() =>
    MockChatTransport(tokenDelay: Duration.zero, thinkDelay: Duration.zero);

Future<NexaClient> initMockClient({
  ChatTransport? transport,
  NexaAuthProvider? auth,
  NexaPermissionHandler? permissions,
  NexaLogger? logger,
  String lang = 'en',
  NexaConfig? config,
}) => Nexa.initialize(
  config: config ?? testConfig(lang: lang),
  auth: auth ?? MockAuthProvider(),
  overrides: NexaOverrides(
    chatTransport: transport ?? fastMock(),
    permissionHandler: permissions,
    logger: logger,
  ),
);

/// Polls [condition] until true or [timeout] elapses (real time).
Future<void> waitFor(
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 10),
  String? reason,
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      throw TimeoutException(reason ?? 'waitFor timed out');
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

Future<void> settle([int ms = 30]) =>
    Future<void>.delayed(Duration(milliseconds: ms));
