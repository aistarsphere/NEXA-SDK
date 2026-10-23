import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart'
    show BuildContext, MaterialPageRoute, Navigator, Widget;
import 'package:get_it/get_it.dart';
import 'package:nexa_core/nexa_core.dart';
import 'package:nexa_sdk/src/di/sdk_injector.dart';
import 'package:nexa_sdk/src/features/chat/bloc/chat_bloc.dart';
import 'package:nexa_sdk/src/features/chat/presentation/nexa_chat_screen.dart';
import 'package:nexa_sdk/src/features/chat/presentation/nexa_chat_view.dart';
import 'package:nexa_sdk/src/features/voice/nexa_voice_controller.dart';
import 'package:nexa_sdk/src/features/voice/nexa_voice_state.dart';
import 'package:nexa_sdk/src/features/voice/presentation/nexa_voice_view.dart';
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
    final client = NexaClient._(config, injector);
    _client = client;
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
  NexaClient._(this.config, this._injector)
    : _settings = ValueNotifier(
        NexaUiSettings(languageTag: config.languageTag),
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
  Widget chatView({
    Key? key,
    bool showEndAction = false,
    VoidCallback? onEnded,
  }) {
    _checkAlive();
    return NexaChatView(
      key: key,
      createBloc: () => _injector<ChatBloc>(),
      settings: _settings,
      showEndAction: showEndAction,
      onEnded: onEnded,
    );
  }

  /// Live voice controller: start/end a call, mute, observe typed state and
  /// events. Requires `NexaCapability.liveVoice` to be requested *and*
  /// granted by the gateway, and a `NexaPermissionHandler` that can obtain
  /// the microphone permission.
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
    if (_injector.isRegistered<NexaVoiceController>()) {
      await _injector<NexaVoiceController>().dispose();
      await _injector<RealtimeVoiceTransport>().dispose();
    }
    await sessions.dispose();
    await transport.dispose();
    await _injector.reset();
    _settings.dispose();
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
