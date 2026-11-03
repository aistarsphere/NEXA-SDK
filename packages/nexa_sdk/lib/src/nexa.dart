import 'dart:async';

import 'package:clock/clock.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart'
    show BuildContext, MaterialPageRoute, Navigator, Widget;
import 'package:get_it/get_it.dart';
import 'package:nexa_core/nexa_core.dart';
import 'package:nexa_sdk/src/data/labeeb/labeeb_sdk_client.dart';
import 'package:nexa_sdk/src/di/sdk_injector.dart';
import 'package:nexa_sdk/src/features/assistant/nexa_assistant_options.dart';
import 'package:nexa_sdk/src/features/assistant/nexa_assistant_view.dart';
import 'package:nexa_sdk/src/features/chat/bloc/chat_bloc.dart';
import 'package:nexa_sdk/src/features/chat/presentation/nexa_chat_screen.dart';
import 'package:nexa_sdk/src/features/chat/presentation/nexa_chat_view.dart';
import 'package:nexa_sdk/src/features/conversation/conversation_coordinator.dart';
import 'package:nexa_sdk/src/features/dynamic_ui/nexa_host_capabilities.dart';
import 'package:nexa_sdk/src/features/dynamic_ui/nexa_surface_controller.dart';
import 'package:nexa_sdk/src/features/dynamic_ui/nexa_surface_presentation.dart';
import 'package:nexa_sdk/src/features/history/labeeb_conversations_api.dart';
import 'package:nexa_sdk/src/features/history/nexa_history.dart';
import 'package:nexa_sdk/src/features/media/nexa_conversation_media.dart';
import 'package:nexa_sdk/src/features/media/nexa_device_actions.dart';
import 'package:nexa_sdk/src/features/tools/labeeb_device_tools.dart';
import 'package:nexa_sdk/src/features/tools/labeeb_tool_calls.dart';
import 'package:nexa_sdk/src/features/voice/nexa_voice_controller.dart';
import 'package:nexa_sdk/src/features/voice/nexa_voice_state.dart';
import 'package:nexa_sdk/src/features/voice/presentation/nexa_voice_view.dart';
import 'package:nexa_sdk/src/identity/nexa_installation.dart';
import 'package:nexa_sdk/src/nexa_overrides.dart';
import 'package:nexa_sdk/src/nexa_ui_settings.dart';
import 'package:nexa_sdk/src/session/session_manager.dart';
import 'package:nexa_ui/nexa_ui.dart' show NexaThemeOverrides;

/// Entry point of the NEXA SDK.
///
/// ```dart
/// final nexa = await Nexa.initialize(
///   config: NexaConfig(
///     applicationId: 'app_123',
///     gatewayBaseUri: Uri.parse('https://gw.staging.nexa.example'),
///     environment: NexaEnvironment.staging,
///     languageTag: 'ar',
///     requestedCapabilities: {NexaCapability.textChat, NexaCapability.toolCalling},
///   ),
///   auth: MyBackendAuthProvider(), // fetches a short-lived session token
/// );
/// nexa.lifecycle.listen(print);
/// await nexa.openChat(context);
/// ```
abstract final class Nexa {
  static NexaClient? _client;

  /// Initialises the SDK. Call once; call [NexaClient.dispose] before
  /// initialising again (e.g. on logout).
  static Future<NexaClient> initialize({
    required NexaConfig config,
    required NexaAuthProvider auth,
    NexaOverrides overrides = const NexaOverrides(),
    NexaVoiceOptions voiceOptions = const NexaVoiceOptions(),
    NexaClientToolOptions clientTools = const NexaClientToolOptions(),
    NexaHistoryOptions? history,
    NexaInstallationIdStore? installationStore,
    NexaHostCapabilities host = const NexaHostCapabilities(),
  }) async {
    if (_client != null) {
      throw const ConfigurationException(
        'Nexa.initialize called twice. Dispose the existing client first.',
      );
    }
    config.validate();
    final injector = buildSdkInjector(
      config: config,
      authProvider: auth,
      overrides: overrides,
      voiceOptions: voiceOptions,
    );
    final installation = await NexaInstallation.load(
      installationStore ?? InMemoryInstallationIdStore(),
    );
    // Correlation only; authentication stays the SDK session token.
    injector<Dio>().options.headers['X-Nexa-Installation-Id'] = installation.id;
    final api = LabeebSdkClient(injector<Dio>());
    // A real gateway (no mock transport): labeeb.sdk/1 server history.
    final contract = overrides.chatTransport == null;
    final serverHistory =
        history != null &&
            contract &&
            history.server is UnavailableConversationsApi
        ? NexaHistoryOptions(
            cache: history.cache,
            server: LabeebConversationsApi(api),
            maxCachedConversations: history.maxCachedConversations,
            maxCachedMessages: history.maxCachedMessages,
            pageSize: history.pageSize,
            retentionNotice: history.retentionNotice,
            onClearHostData: history.onClearHostData,
          )
        : history;
    final client = NexaClient._(
      config,
      injector,
      clientTools,
      serverHistory,
      installation,
      host,
      api,
    );
    _client = client;
    // labeeb.sdk/1: declare the device tools this client can run, and join
    // a server-owned conversation (tools, attachments and voice need one).
    client._sessions.clientToolsProvider = client.toolCalls.declaredTools;
    if (contract) {
      client._sessions
        ..coordinator = client.conversations
        ..historyLoader = client._earlierMessages;
    }
    if (injector.isRegistered<NexaVoiceController>()) {
      // Tools in a call: same lifecycle, answered in `tools.session_id`.
      final voice = injector<NexaVoiceController>()
        ..clientToolsProvider = client.toolCalls.declaredTools;
      if (contract) {
        voice.turnReporter = (cid, vsid, role, text, turnId) =>
            client.api.reportVoiceTurns(
              cid,
              voiceSessionId: vsid,
              turns: [
                LabeebVoiceTurn(role: role, text: text, clientTurnId: turnId),
              ],
            );
      }
      client._voiceTools = voice.toolEvents.listen(
        (e) => client.toolCalls.ingestVoice(
          e.type,
          e.fields,
          toolsSessionId: e.toolsSessionId,
        ),
      );
      if (voice.restartsOnVoiceActivation) {
        client._voiceActivation = client.toolCalls.completed
            .where((c) => c.tool == LabeebTools.voiceProfileActivate)
            .listen((_) => unawaited(voice.restartForNewVoice()));
      }
    }
    client._sessions.emit(NexaInitialized(clock.now()));
    return client;
  }

  /// The initialised client. Throws [NotInitializedException] otherwise.
  static NexaClient get instance {
    final c = _client;
    if (c == null) throw const NotInitializedException();
    return c;
  }

  /// Whether [initialize] has completed and [NexaClient.dispose] has not run.
  static bool get isInitialized => _client != null;
}

/// Handle to the initialised SDK.
final class NexaClient {
  NexaClient._(
    this.config,
    this._injector,
    NexaClientToolOptions tools,
    NexaHistoryOptions? history,
    this.installation,
    this.host,
    this.api,
  ) : _settings = ValueNotifier(
        NexaUiSettings(languageTag: config.languageTag),
      ),
      _toolOptions = tools,
      history = history == null ? null : NexaHistoryController(history);

  /// What the host app lets the assistant control (e.g. its theme).
  final NexaHostCapabilities host;

  /// REST surface of contract `labeeb.sdk/1` (conversations, assets,
  /// tools, tool calls, preferences, deletion).
  final LabeebSdkClient api;

  /// labeeb.sdk/1 tool calls, long jobs, produced assets and `nexa.ui/1`
  /// documents of the conversation (chat and voice).
  late final LabeebToolCallController toolCalls = LabeebToolCallController(
    api: api,
    tools: labeebDeviceTools(_toolOptions, theme: host.theme),
    media: media,
    host: host,
    priority: _toolOptions.declarationPriority,
    diagnostics: _injector<NexaDiagnostics>(),
  );

  /// The server conversation of the current chat (null before the first
  /// session, or without server conversations).
  String? get conversationId => _sessions.conversationId;

  StreamSubscription<NexaVoiceToolEvent>? _voiceTools;
  StreamSubscription<NexaToolCall>? _voiceActivation;

  /// Single owner of the current conversation id (create with a stable
  /// `client_ref`, resume, new).
  late final ConversationCoordinator conversations = ConversationCoordinator(
    installationId: installation.id,
    diagnostics: _injector<NexaDiagnostics>(),
    create: ({required clientRef}) async =>
        (await api.createConversation(kind: 'chat', clientRef: clientRef)).id,
  );

  /// Continues server conversation [conversationId] (history resume): the
  /// next session joins it and the chat shows its earlier messages. Ends
  /// the current session first.
  Future<void> resumeConversation(String conversationId) async {
    _checkAlive();
    media.clear();
    toolCalls.reset();
    await _sessions.end(reason: 'resume');
    conversations.open(conversationId);
  }

  Future<List<ChatMessage>> _earlierMessages(String conversationId) async {
    final page = await api.messages(conversationId, limit: 100);
    // Attachments, generated files, tool results and documents come back
    // as media items at their original time.
    toolCalls.restore(page.items);
    return [
      for (final m in page.items)
        if (m.text.isNotEmpty)
          ChatMessage(
            id: MessageId(m.id),
            role: m.fromUser ? MessageRole.user : MessageRole.assistant,
            status: m.fromUser ? MessageStatus.sent : MessageStatus.completed,
            createdAt: m.createdAt ?? clock.now().toUtc(),
            text: m.text,
          ),
    ];
  }

  /// Starts a fresh server conversation on the next session.
  Future<void> newConversation() async {
    _checkAlive();
    media.clear();
    toolCalls.reset();
    await _sessions.end(reason: 'new_conversation');
    conversations.startNew();
  }

  /// Dynamic UI surfaces of this client (chat, voice, host pickers).
  late final NexaSurfaceController surfaces = NexaSurfaceController(
    host: host,
    deviceActions: deviceActions,
  );

  /// Opens the host's theme picker (design "Themes & appearance") as a
  /// bottom sheet: palette preview app-wide, Apply / Cancel / Reset. Shows
  /// the Unavailable state when the host registered no theme controller.
  Future<void> showThemePicker(BuildContext context) async {
    _checkAlive();
    final lang = _settings.value.languageTag;
    final theme = host.theme;
    surfaces.upsert(
      theme != null
          ? buildThemeSurface(theme, languageCode: lang)
          : parseNexaSurface({
              'schema_version': '1.0',
              'surface_id': 'srf_theme_local',
              'category': 'themes_appearance',
              'presentation': 'bottom_sheet',
              'title': lang == 'ar' ? 'مظهر التطبيق' : 'App theme',
              'fallback_text': '',
            })!,
    );
    await showNexaSurface(context, surfaces, 'srf_theme_local');
  }

  /// Anonymous, app-scoped installation identity (not authentication).
  final NexaInstallation installation;

  /// Conversation history: the service's when it offers it, shown from a
  /// bounded local cache otherwise (null unless the host enabled it).
  final NexaHistoryController? history;

  final NexaClientToolOptions _toolOptions;

  /// Attachments and tool runs of the current conversation, shared by the
  /// chat and live voice views.
  late final NexaConversationMedia media = NexaConversationMedia();

  /// Device actions (camera, photo library, location) and the client tool
  /// registry.
  late final NexaDeviceActions deviceActions = NexaDeviceActions(
    options: _toolOptions,
    media: media,
    hostTools: [
      if (host.theme case final theme?) ...HostThemeTool.forHost(theme),
    ],
  );

  /// Immutable configuration supplied at initialisation.
  final NexaConfig config;
  final GetIt _injector;
  final ValueNotifier<NexaUiSettings> _settings;
  bool _disposed = false;

  SessionManager get _sessions => _injector<SessionManager>();

  /// Lifecycle and error events: initialised, session started/ended,
  /// credential refreshed, errors, disposed.
  Stream<NexaLifecycleEvent> get lifecycle => _sessions.lifecycle;

  /// Active session, if any.
  SessionHandle? get currentSession => _sessions.current;

  /// Current presentation settings.
  ValueListenable<NexaUiSettings> get uiSettings => _settings;

  /// Starts (or returns) the session without opening UI, e.g. to pre-warm or
  /// to check granted capabilities.
  Future<SessionHandle> startSession() {
    _checkAlive();
    return _sessions.start();
  }

  /// Ends the active session. Safe when none is active.
  Future<void> endSession() {
    _checkAlive();
    media.clear();
    toolCalls.reset();
    return _sessions.end(reason: 'host');
  }

  /// Changes the UI language at runtime (`en` or `ar`).
  void setLanguage(String languageTag) {
    _checkAlive();
    if (!NexaConfig.supportedLanguageTags.contains(languageTag)) {
      throw ConfigurationException('Unsupported languageTag "$languageTag".');
    }
    _settings.value = _settings.value.copyWith(languageTag: languageTag);
  }

  /// Applies approved branding overrides at runtime.
  void setThemeOverrides(NexaThemeOverrides overrides) {
    _checkAlive();
    _settings.value = _settings.value.copyWith(themeOverrides: overrides);
  }

  /// Forces light/dark or follows the system.
  void setThemeMode(NexaThemeMode mode) {
    _checkAlive();
    _settings.value = _settings.value.copyWith(themeMode: mode);
  }

  /// Embeddable chat widget for the host's own layout. Each instance owns its
  /// bloc; the session is shared.
  ///
  /// [suggestions] supplies tappable first messages for an empty
  /// conversation, per language code. [onVoice] adds a live-voice button to
  /// the composer; the host decides how to present [voiceView].
  Widget chatView({
    Key? key,
    bool showEndAction = false,
    VoidCallback? onEnded,
    List<String> Function(String languageCode)? suggestions,
    VoidCallback? onVoice,
  }) {
    _checkAlive();
    return NexaChatView(
      key: key,
      createBloc: () => _injector<ChatBloc>(),
      media: media,
      deviceActions: deviceActions.anyEnabled ? deviceActions : null,
      history: history,
      surfaces: surfaces,
      toolCalls: toolCalls,
      settings: _settings,
      showEndAction: showEndAction,
      onEnded: onEnded,
      suggestions: suggestions,
      onVoice: onVoice,
    );
  }

  /// Live voice controller: start/end a call, mute, observe typed state and
  /// events. Requires `NexaCapability.liveVoice` to be requested, a token
  /// with scope `voice:session` (the voice endpoint authorizes each call;
  /// the chat session's granted set does not), and a
  /// `NexaPermissionHandler` that can obtain the microphone permission.
  NexaVoiceController get voice {
    _checkAlive();
    return _injector<NexaVoiceController>();
  }

  /// Embeddable Live Voice Capsule bound to [voice]. The host owns
  /// navigation; the SDK never pushes routes for voice.
  Widget voiceView({
    Key? key,
    bool showTranscript = true,
    bool autoStart = false,
    VoidCallback? onEnded,
    VoidCallback? onOpenSettings,
  }) {
    _checkAlive();
    return NexaVoiceView(
      key: key,
      controller: voice,
      settings: _settings,
      showTranscript: showTranscript,
      autoStart: autoStart,
      onEnded: onEnded,
      onOpenSettings: onOpenSettings,
    );
  }

  /// The complete assistant (header with the host's [brand], chat, live
  /// voice, optional home) as one widget for the host's own route.
  ///
  /// * [launchMode]: chat-first, voice-only or a home screen.
  /// * [features]: hide voice, "new conversation" or suggestions. Features
  ///   can only be hidden: voice also needs `NexaCapability.liveVoice`
  ///   requested, and the backend enforces what the session may do.
  /// * The SDK inherits the host's `ThemeData` by default
  ///   (`NexaUiSettings.themeSource`); [setThemeOverrides] still applies.
  /// * [onOpenSettings] adds a settings action that opens the host's screen;
  ///   [onOpenMicrophoneSettings] opens the OS settings after a denial.
  /// * [voiceRequests]: each event opens live voice (an assistant button or
  ///   wake phrase handled by the host); ignored while a call is open.
  Widget assistantView({
    required NexaBrand brand,
    Key? key,
    NexaLaunchMode launchMode = NexaLaunchMode.chat,
    NexaAssistantFeatures features = const NexaAssistantFeatures(),
    List<String> Function(String languageCode)? suggestions,
    VoidCallback? onOpenSettings,
    VoidCallback? onOpenMicrophoneSettings,
    Widget? headerBadge,
    Stream<void>? voiceRequests,
  }) {
    _checkAlive();
    return NexaAssistantView(
      key: key,
      client: this,
      brand: brand,
      launchMode: launchMode,
      features: features,
      suggestions: suggestions,
      onOpenSettings: onOpenSettings,
      onOpenMicrophoneSettings: onOpenMicrophoneSettings,
      headerBadge: headerBadge,
      voiceRequests: voiceRequests,
    );
  }

  /// Chooses where the SDK views take their theme from (default: the host).
  void setThemeSource(NexaThemeSource source) {
    _checkAlive();
    _settings.value = _settings.value.copyWith(themeSource: source);
  }

  /// Pushes the full-screen chat. Returns when it is popped.
  Future<void> openChat(BuildContext context) {
    _checkAlive();
    final view = chatView() as NexaChatView;
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => NexaChatScreen(view: view),
      ),
    );
  }

  /// Ends the session, closes transports and releases the container. The
  /// client is unusable afterwards; call `Nexa.initialize` again if needed.
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    final sessions = _sessions;
    final transport = _injector<ChatTransport>();
    sessions.emit(NexaDisposed(clock.now()));
    unawaited(_voiceTools?.cancel());
    unawaited(_voiceActivation?.cancel());
    if (_injector.isRegistered<NexaVoiceController>()) {
      await _injector<NexaVoiceController>().dispose();
      await _injector<RealtimeVoiceTransport>().dispose();
    }
    await sessions.dispose();
    await transport.dispose();
    await _injector.reset();
    _settings.dispose();
    media.dispose();
    surfaces.dispose();
    toolCalls.dispose();
    history?.dispose();
    Nexa._client = null;
  }

  /// Internal container, exposed for SDK tests only.
  @internal
  GetIt get injector => _injector;

  void _checkAlive() {
    if (_disposed) {
      throw const NotInitializedException('NexaClient was disposed.');
    }
  }
}
