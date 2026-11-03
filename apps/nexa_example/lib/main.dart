import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
// MOCK ONLY: used when the app is built with --dart-define=NEXA_USE_MOCK=true.
import 'package:nexa_core/testing.dart'
    show
        MockAuthProvider,
        MockChatTransport,
        MockRealtimeVoiceTransport,
        MockVoiceProvisioner;
import 'package:nexa_example/assistant/assistant_page.dart';
import 'package:nexa_example/assistant/assistant_settings_page.dart';
import 'package:nexa_example/assistant/device_assistant.dart';
import 'package:nexa_example/assistant/device_assistant_page.dart';
import 'package:nexa_example/assistant/labeeb_router.dart';
import 'package:nexa_example/brand/labeeb_brand.dart';
import 'package:nexa_example/brand/labeeb_theme_controller.dart';
import 'package:nexa_example/crash/crash_sink.dart';
import 'package:nexa_example/dev/dynamic_ui_gallery_page.dart';
import 'package:nexa_example/dev/qa/qa_recorder.dart';
import 'package:nexa_example/dev_token_auth_provider.dart';
import 'package:nexa_example/example_config.dart';
import 'package:nexa_example/host_auth_provider.dart';
import 'package:nexa_example/host_permission_handler.dart';
import 'package:nexa_example/playground/embedded_chat_page.dart';
import 'package:nexa_example/playground/home_page.dart';
import 'package:nexa_example/playground/settings_page.dart';
import 'package:nexa_example/playground/voice_page.dart';
import 'package:nexa_sdk/nexa_sdk.dart';
import 'package:path_provider/path_provider.dart';

/// The account whose local cache is used. No sign-in exists yet (backend
/// B2): one account per install until a host auth provider supplies it.
const _accountKey = 'default';

/// LABEEB | لبيب: the assistant app, built on the NEXA SDK (its example host).
///
/// The user-facing app is the assistant (`lib/assistant/`): chat through
/// `client.chatView()`, live voice through `client.voiceView()`, settings.
/// Development builds add the SDK playground (`lib/playground/`), which
/// demonstrates the three integration styles:
/// 1. `Nexa.openChat(context)` - full-screen modal chat.
/// 2. `client.chatView()` - chat embedded in a host page.
/// 3. Runtime language / theme switching through the client.
///
/// By default the SDK talks over real HTTP (SSE) to the **local reference
/// gateway** (`make gateway`). With `NEXA_REAL_BACKEND=true` it talks to the
/// real NEXA backend; the token then comes from the development-only
/// [DevTokenAuthProvider] until the customer's host backend exists. The
/// host-side pieces (`HostAuthProvider`, `HostPermissionHandler`) are exactly
/// what a real host would write.
Future<void> main() async {
  // Uncaught errors go to a CrashSink (type and stack, never message text).
  // No vendor yet: debug builds print the type, release builds report nothing.
  installCrashHandlers(
    kDebugMode ? const DebugPrintCrashSink() : const NoopCrashSink(),
  );
  WidgetsFlutterBinding.ensureInitialized();
  ExampleConfig.validate();
  await Labeeb.loadAssets();

  final NexaAuthProvider auth = ExampleConfig.useMock
      // MOCK ONLY: no server, so no token issuer either.
      ? MockAuthProvider()
      : ExampleConfig.realBackend
      ? DevTokenAuthProvider(
          token: ExampleConfig.devSdkToken,
          expiresAt: ExampleConfig.devSdkTokenExpiresAt,
        )
      : HostAuthProvider(
          hostBackendUri: ExampleConfig.gatewayUri,
          applicationId: ExampleConfig.applicationId,
        );
  // DEVELOPMENT ONLY: per-session QA diagnostics on the device. Compiled
  // out of production builds (devTools is a compile-time constant).
  final qa = ExampleConfig.devTools ? await _openQaRecorder() : null;
  final support = await getApplicationSupportDirectory();
  final legacyHistory = File('${support.path}/history.json');
  if (legacyHistory.existsSync()) await legacyHistory.delete();
  // LABEEB's palette + light/dark/system; the assistant may preview and
  // (with the user's approval) apply it through the SDK host capability.
  final theme = await LabeebThemeController.load(
    File('${support.path}/labeeb_theme.json'),
  );
  final client = await Nexa.initialize(
    config: NexaConfig(
      applicationId: ExampleConfig.applicationId,
      gatewayBaseUri: ExampleConfig.gatewayUri,
      // Real backend: production-like policies (wss only, no ws:// LiveKit).
      environment: ExampleConfig.realBackend
          ? NexaEnvironment.staging
          : NexaEnvironment.development,
      languageTag: ExampleConfig.initialLanguage,
      requestedCapabilities: const {
        NexaCapability.textChat,
        NexaCapability.toolCalling,
        NexaCapability.richResults,
        NexaCapability.liveVoice,
      },
      clientMetadata: const {'host_app_version': '1.1.0'},
    ),
    auth: auth,
    host: NexaHostCapabilities(theme: theme),
    overrides: NexaOverrides(
      // MOCK ONLY when NEXA_USE_MOCK=true; otherwise the real HTTP transport
      // and the real LiveKit voice transport.
      chatTransport: ExampleConfig.useMock ? MockChatTransport() : null,
      voiceTransport: ExampleConfig.useMock
          ? MockRealtimeVoiceTransport()
          : null,
      voiceProvisioner: ExampleConfig.useMock ? MockVoiceProvisioner() : null,
      permissionHandler: const HostPermissionHandler(),
      logger: const _PrintLogger(),
      diagnostics: qa,
    ),
    // Device tools: each run asks the user; nothing is uploaded while the
    // backend has no client-tool / attachment API.
    clientTools: NexaClientToolOptions(
      onOpenSettings: HostPermissionHandler.openSettings,
      // Apps the assistant may open (LABEEB's allowlist).
      apps: LabeebApps.allowlist,
    ),
    // Unfinished tool calls survive a restart (per account).
    pendingStore: JsonFilePendingStore.forAccount(support, _accountKey),
    // Anonymous app-scoped installation id (correlation only, not auth).
    installationStore: FileInstallationIdStore(
      File('${support.path}/installation_id'),
    ),
    // Local conversation history in the app's private support directory.
    // The unscoped `history.json` of older builds held ses_/vs_ rows that
    // can never match the server; it is cache only and is removed so that
    // "Clear all" leaves no conversation text behind.
    history: NexaHistoryOptions(
      // Bounded UI cache only: the service owns conversation history.
      // One file per account (`history_<hash>.json`). There is no sign-in
      // yet (backend B2), so the single account key is `default`.
      cache: JsonFileHistoryStore.forAccount(support, _accountKey),
      onClearHostData: qa == null
          ? null
          : () async {
              final n = qa.index.value.length;
              await qa.delete();
              return n;
            },
    ),
  );

  client.lifecycle.listen((event) {
    // Hosts typically forward these to analytics / crash reporting.
    debugPrint('[nexa lifecycle] $event');
  });

  if (!ExampleConfig.useMock) unawaited(Labeeb.loadProfile(client));

  // Android: default assistant + «يا لبيب» (on-device). No-op elsewhere.
  final device = DeviceAssistant(client: client);
  await device.start();

  runApp(
    ExampleApp(
      client: client,
      auth: auth,
      qa: qa,
      theme: theme,
      device: device,
    ),
  );
}

Future<QaRecorder> _openQaRecorder() async {
  final docs = await getApplicationDocumentsDirectory();
  final qa = await QaRecorder.open(
    root: Directory('${docs.path}/nexa_qa'),
    appMeta: {
      'app_id': ExampleConfig.applicationId,
      'app_version': ExampleConfig.appVersion,
      'sdk_version': nexaSdkVersion,
      'platform': Platform.operatingSystem,
      'os_version': Platform.operatingSystemVersion,
      'build_mode': kReleaseMode
          ? 'release'
          : kProfileMode
          ? 'profile'
          : 'debug',
      'backend': ExampleConfig.useMock
          ? 'mock'
          : ExampleConfig.realBackend
          ? 'real'
          : 'reference',
      'gateway_host': ExampleConfig.gatewayUri.host,
      'language': ExampleConfig.initialLanguage,
    },
  );
  WidgetsBinding.instance.addObserver(qa);
  return qa;
}

/// The NEXA assistant app.
///
/// * `/` the assistant (chat, with live voice on top), `/settings`.
/// * `/dev/…` the SDK playground (modal + embedded chat, voice event log,
///   theme overrides): registered only when [ExampleConfig.devTools] is on,
///   so production builds cannot reach it.
class ExampleApp extends StatelessWidget {
  ExampleApp({
    required this.client,
    required this.auth,
    this.initialLocation = '/',
    this.qa,
    this.theme,
    this.device,
    super.key,
  });

  final NexaClient client;

  /// Android assistant integration; null in tests and on other platforms.
  final DeviceAssistant? device;

  /// LABEEB's theme controller; null keeps the fixed Mocha palette and the
  /// SDK's light/dark/system setting (tests).
  final LabeebThemeController? theme;
  final NexaAuthProvider auth;

  /// Development builds only (see [QaRecorder]).
  final QaRecorder? qa;

  /// Integration tests start in the playground (`/dev`).
  final String initialLocation;

  /// The app router (exposed for navigation tests).
  @visibleForTesting
  GoRouter get router => _router;

  late final GoRouter _router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: '/c/:id',
        builder: (context, state) => RouteConversation(
          key: ValueKey('chat_${state.pathParameters['id']}'),
          client: client,
          alwaysResume: true,
          conversationId: state.pathParameters['id']!,
          builder: (context) => AssistantPage(
            client: client,
            auth: auth,
            voiceRequests: device?.voiceRequests,
            chatOnly: true,
          ),
        ),
        routes: [
          GoRoute(
            path: 'call',
            pageBuilder: (context, state) {
              final id = state.pathParameters['id']!;
              return MaterialPage<void>(
                key: state.pageKey,
                fullscreenDialog: true,
                child: RouteConversation(
                  client: client,
                  conversationId: id,
                  builder: (context) =>
                      labeebAssistantView(context, client).callPage(
                        onClose: () => context.canPop()
                            ? context.pop()
                            : context.go('/c/$id'),
                      ),
                ),
              );
            },
          ),
        ],
      ),
      GoRoute(
        path: '/',
        builder: (context, state) => AssistantPage(
          client: client,
          auth: auth,
          voiceRequests: device?.voiceRequests,
          list: ExampleConfig.launchMode == NexaLaunchMode.list,
        ),
        routes: [
          GoRoute(
            path: 'settings',
            builder: (context, state) => AssistantSettingsPage(
              client: client,
              auth: auth,
              qa: qa,
              device: device,
            ),
            routes: [
              if (device case final DeviceAssistant d when d.supported)
                GoRoute(
                  path: 'assistant',
                  builder: (context, state) =>
                      DeviceAssistantPage(assistant: d),
                ),
            ],
          ),
          if (ExampleConfig.devTools)
            GoRoute(
              path: 'dev',
              builder: (context, state) => HomePage(client: client, auth: auth),
              routes: [
                GoRoute(
                  path: 'embedded',
                  builder: (context, state) => EmbeddedChatPage(client: client),
                ),
                GoRoute(
                  path: 'voice',
                  builder: (context, state) => VoicePage(client: client),
                ),
                GoRoute(
                  path: 'settings',
                  builder: (context, state) =>
                      SettingsPage(client: client, auth: auth),
                ),
                GoRoute(
                  path: 'dynamic-ui',
                  builder: (context, state) =>
                      DynamicUiGalleryPage(client: client),
                ),
              ],
            ),
        ],
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    // App chrome uses the LABEEB theme and follows the SDK's language and
    // the host theme controller, so the whole app switches together (incl.
    // RTL and an assistant theme preview).
    return ListenableBuilder(
      listenable: Listenable.merge([client.uiSettings, ?theme]),
      builder: (context, _) {
        final settings = client.uiSettings.value;
        final locale = NexaLocale.fromTag(settings.languageTag);
        final t = theme;
        ThemeData themed(Brightness b) {
          if (t == null) {
            return b == Brightness.light
                ? LabeebTheme.light(locale)
                : LabeebTheme.dark(locale);
          }
          final (scheme, roles) = t.colors(b);
          return LabeebTheme.fromColors(scheme, roles, locale);
        }

        return MaterialApp.router(
          title: Labeeb.nameEn,
          onGenerateTitle: (context) =>
              Labeeb.name(Localizations.localeOf(context).languageCode),
          debugShowCheckedModeBanner: false,
          locale: locale,
          supportedLocales: NexaLocale.supported,
          localizationsDelegates: NexaLocale.delegates,
          // LABEEB supplies its own theme; the SDK views inherit it.
          theme: themed(Brightness.light),
          darkTheme: themed(Brightness.dark),
          themeMode:
              t?.themeMode ??
              switch (settings.themeMode) {
                NexaThemeMode.light => ThemeMode.light,
                NexaThemeMode.dark => ThemeMode.dark,
                NexaThemeMode.system => ThemeMode.system,
              },
          routerConfig: _router,
          builder: (context, child) {
            final d = device;
            final app = child ?? const SizedBox.shrink();
            return d == null
                ? app
                : DeviceAssistantLockGate(
                    assistant: d,
                    child: DeviceAssistantPanelHost(assistant: d, child: app),
                  );
          },
        );
      },
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
