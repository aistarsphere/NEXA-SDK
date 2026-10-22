import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
// MOCK ONLY: used when the app is built with --dart-define=NEXA_USE_MOCK=true.
import 'package:nexa_core/testing.dart' show MockChatTransport;
import 'package:nexa_example/example_config.dart';
import 'package:nexa_example/host_auth_provider.dart';
import 'package:nexa_example/host_permission_handler.dart';
import 'package:nexa_example/pages/embedded_chat_page.dart';
import 'package:nexa_example/pages/home_page.dart';
import 'package:nexa_example/pages/settings_page.dart';
import 'package:nexa_sdk/nexa_sdk.dart';

/// Example host application.
///
/// Demonstrates the three integration styles:
/// 1. `Nexa.openChat(context)` - full-screen modal chat.
/// 2. `client.chatView()` - chat embedded in a host page.
/// 3. Runtime language / theme switching through the client.
///
/// By default the SDK talks over real HTTP (SSE) to the **local reference
/// gateway** (`make gateway`), which stands in for the NEXA backend that does
/// not exist yet. The host-side pieces (`HostAuthProvider`,
/// `HostPermissionHandler`) are exactly what a real host would write.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final auth = HostAuthProvider(
    hostBackendUri: ExampleConfig.gatewayUri,
    applicationId: ExampleConfig.applicationId,
  );
  final client = await Nexa.initialize(
    config: NexaConfig(
      applicationId: ExampleConfig.applicationId,
      gatewayBaseUri: ExampleConfig.gatewayUri,
      environment: NexaEnvironment.development,
      languageTag: 'en',
      requestedCapabilities: const {
        NexaCapability.textChat,
        NexaCapability.toolCalling,
        NexaCapability.richResults,
        NexaCapability.liveVoice, // will NOT be granted (no voice backend)
      },
      clientMetadata: const {'host_app_version': '1.1.0'},
    ),
    auth: auth,
    overrides: NexaOverrides(
      // MOCK ONLY when NEXA_USE_MOCK=true; otherwise the real HTTP transport.
      chatTransport: ExampleConfig.useMock ? MockChatTransport() : null,
      permissionHandler: const HostPermissionHandler(),
      logger: const _PrintLogger(),
    ),
  );

  client.lifecycle.listen((event) {
    // Hosts typically forward these to analytics / crash reporting.
    debugPrint('[nexa lifecycle] $event');
  });

  runApp(ExampleApp(client: client, auth: auth));
}

class ExampleApp extends StatelessWidget {
  ExampleApp({required this.client, required this.auth, super.key});

  final NexaClient client;
  final HostAuthProvider auth;

  late final GoRouter _router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => HomePage(client: client, auth: auth),
        routes: [
          GoRoute(
            path: 'embedded',
            builder: (context, state) => EmbeddedChatPage(client: client),
          ),
          GoRoute(
            path: 'settings',
            builder: (context, state) =>
                SettingsPage(client: client, auth: auth),
          ),
        ],
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    // The host keeps its own theme; the SDK chat installs the Mocha theme
    // only inside its own subtree.
    return MaterialApp.router(
      title: 'NEXA Example Host',
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      darkTheme: ThemeData(
        colorSchemeSeed: Colors.indigo,
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      routerConfig: _router,
    );
  }
}

final class _PrintLogger implements NexaLogger {
  const _PrintLogger();
  @override
  void log(
    NexaLogLevel level,
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    debugPrint(
      '[nexa ${level.name}] $message${error == null ? '' : ' $error'}',
    );
  }
}
