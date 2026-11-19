import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:nexa_core/nexa_core.dart';
import 'package:nexa_realtime/nexa_realtime.dart';
import 'package:nexa_sdk/src/features/voice/nexa_voice_signals.dart';
import 'package:nexa_sdk/src/features/voice/nexa_voice_state.dart';
import 'package:nexa_sdk/src/permissions/nexa_permission_handler.dart';
import 'package:nexa_sdk/src/session/session_manager.dart';

/// Orchestrates one live voice session against contract `nexa.voice.v1`
/// (backend handoff 1.0.0).
///
/// `VoiceSessionMachine` (pure, in `nexa_core`) is the single source of the
/// displayed phase; this controller executes its commands against the host
/// permission handler, the `VoiceProvisioner` (gateway REST) and the
/// `RealtimeVoiceTransport` (LiveKit), and feeds outcomes back as
/// `VoiceEvent`s.
///
/// Lifecycle rules from the contract:
/// * `create` returns only after the agent joined; `503 voice_unavailable`
///   means nothing was created — a retry waits at least `Retry-After`.
/// * A server-side end deletes the room and usually sends **no** event: on
///   any unexpected disconnect the controller asks `GET` for the
///   authoritative state, then either ends (mapping `end_reason`) or
///   refreshes the join token and rejoins with the same identity.
/// * After the agent's `session_ended` (e.g. quota) REST still reports
///   `active`: the controller `DELETE`s, then disconnects. `DELETE` is sent
///   on every exit path.
/// * The 60 s join token is not the session lifetime; the call is capped by
///   `limits.max_seconds` server-side, with a client backstop.
/// * There is no interrupt command: barge-in is detected by the agent.
///
/// Obtain through `NexaClient.voice`; hosts never construct it.
final class NexaVoiceController {
  NexaVoiceController({
    required SessionManager sessions,
    required VoiceProvisioner provisioner,
    required RealtimeVoiceTransport transport,
    required NexaPermissionHandler permissions,
    required NexaLogger logger,
    NexaDiagnostics diagnostics = const NoopNexaDiagnostics(),
    NexaVoiceOptions options = const NexaVoiceOptions(),
    String languageTag = 'en',
    NexaCallAudio? callAudio,
  }) : _diagnostics = diagnostics,
       _callAudio = callAudio,
       _sessions = sessions,
       _provisioner = provisioner,
       _transport = transport,
       _permissions = permissions,
       _logger = logger,
       _options = options,
       _languageTag = languageTag {
    final audio = callAudio;
    if (audio != null) {
      _audioSubs
        ..add(audio.phoneCallChanges.listen(_onPhoneCall))
        ..add(
          audio.changes.listen((_) {
            _onAudioChanged();
            _sendClientInfo();
          }),
        );
    }
  }

  /// Extra time after `max_seconds` before the client ends the call itself
  /// (the server normally ends it first with `quota_exceeded`).
  static const capBackstop = Duration(seconds: 15);

  final SessionManager _sessions;
  final VoiceProvisioner _provisioner;
  final RealtimeVoiceTransport _transport;
  final NexaPermissionHandler _permissions;
  final NexaLogger _logger;
  final NexaDiagnostics _diagnostics;
  final NexaVoiceOptions _options;
  final NexaCallAudio? _callAudio;
  final List<StreamSubscription<Object?>> _audioSubs = [];
  bool _phoneHold = false;
  bool _phoneReleasing = false;
  bool _bluetoothAsked = false;
  late final NexaVoiceSignals _signals = NexaVoiceSignals(
    send: _transport.sendSignal,
    diagnostics: _diagnostics,
  );
  late final VoiceSessionMachine _machine = VoiceSessionMachine(
    waitForInterruptConfirmation: _options.waitForInterruptConfirmation,
  );
  Timer? _speakingWatchdog;
  bool _agentSilent = true;
  // The agent's audio was heard in this "speaking" stretch: the watchdog
  // counts only silence after real audio, never a reply whose level
  // updates have not arrived yet.
  bool _agentHeard = false;

  final ValueNotifier<NexaVoiceState> _state = ValueNotifier(
    const NexaVoiceState(),
  );
  final ValueNotifier<NexaVoiceLevels> _levels = ValueNotifier(
    NexaVoiceLevels.silent,
  );
  final ValueNotifier<NexaVoiceCallStats> _stats = ValueNotifier(
    const NexaVoiceCallStats(),
  );
  final StreamController<NexaVoiceEvent> _events =
      StreamController<NexaVoiceEvent>.broadcast();
  final StreamController<NexaVoiceToolEvent> _toolEvents =
      StreamController<NexaVoiceToolEvent>.broadcast();

  /// Device tool names to request tools with (set by `NexaClient`).
  Future<List<String>> Function()? clientToolsProvider;

  /// Reports a final spoken turn into the shared conversation
  /// (`POST /conversations/{id}/voice-turns`; set by `NexaClient`).
  Future<void> Function(
    String conversationId,
    String voiceSessionId,
    String role,
    String text,
    String clientTurnId,
  )?
  turnReporter;
  int _turnCounter = 0;

  StreamSubscription<RealtimeVoiceEvent>? _subscription;
  VoiceGrant? _grant;
  String? _voiceSessionId;
  Timer? _capTimer;
  DateTime? _retryNotBefore;
  String _languageTag;
  bool _disposed = false;
  bool _ending = false;
  bool _recovering = false;
  bool _tearingDown = false;
  Timer? _backgroundTimer;
  String _endReason = 'user';

  /// Current snapshot; listen for UI binding.
  ValueListenable<NexaVoiceState> get state => _state;

  /// Real speaking levels from the media server (a few updates per
  /// second; silent outside a call). For visualisation only.
  ValueListenable<NexaVoiceLevels> get levels => _levels;

  /// Audio-quality counters of the current call (QA / debug panel).
  ValueListenable<NexaVoiceCallStats> get stats => _stats;

  /// Route choice (loudspeaker / earpiece) and the platform audio state;
  /// null when the transport is not LiveKit (tests, mocks).
  NexaCallAudio? get callAudio => _callAudio;

  /// Typed event stream for hosts (analytics, custom UI).
  Stream<NexaVoiceEvent> get events => _events.stream;

  /// labeeb.sdk/1 tool events of the call (tool calls, assets, UI).
  Stream<NexaVoiceToolEvent> get toolEvents => _toolEvents.stream;

  /// Active grant (redacted `toString`), for diagnostics only.
  VoiceGrant? get currentGrant => _grant;

  /// Whether the microphone track is currently published and enabled.
  bool get microphoneEnabled => _transport.isMicrophoneEnabled;

  /// Set by the host: true while something keeps the call alive in the
  /// background (an Android foreground service, or the system assistant
  /// panel). Without it a backgrounded call is ended after
  /// `NexaVoiceOptions.backgroundGrace`.
  bool Function()? keepAliveInBackground;

  /// The app left the foreground. With a call running and nothing holding
  /// it, the call ends after the grace period (`endReason: background`).
  void notePaused() {
    if (_disposed || !_state.value.isActive) return;
    final held = keepAliveInBackground?.call() ?? false;
    _diagnostics.record('voice.app_paused', {
      'phase': _state.value.phase.name,
      'held': held,
    });
    _backgroundTimer?.cancel();
    if (held) return;
    _backgroundTimer = Timer(_options.backgroundGrace, () {
      if (_disposed || !_state.value.isActive) return;
      if (keepAliveInBackground?.call() ?? false) return;
      _diagnostics.record('voice.background_end');
      unawaited(end(reason: 'background'));
    });
  }

  /// The app is back. A stalled reconnect is retried at once (the OS may
  /// have frozen the sockets while backgrounded).
  void noteResumed() {
    _backgroundTimer?.cancel();
    if (_disposed || !_state.value.isActive) return;
    _diagnostics.record('voice.app_resumed', {
      'phase': _state.value.phase.name,
    });
    if (_state.value.phase == VoiceState.reconnecting) unawaited(_recover());
  }

  /// Language sent as `language_tag` when a call is created (`en`/`ar`).
  set languageTag(String tag) => _languageTag = tag;

  // ------------------------------------------------------------ public API

  /// Starts a call: permission → `create` → room join → handshake. Returns
  /// once the request is accepted; progress is observable on [state]. Safe
  /// to call again after `ended` / `disconnected`. After a
  /// `503 voice_unavailable` it waits out `Retry-After` before creating.
  Future<void> start() async {
    _check();
    final phase = _state.value.phase;
    if (phase.isTerminal || phase == VoiceState.ended) {
      _dispatch(const VoiceReset());
    }
    if (_state.value.phase != VoiceState.idle &&
        _state.value.phase != VoiceState.disconnected) {
      return; // already in a call
    }
    _set(
      _state.value.copyWith(
        clearError: true,
        transcript: const [],
        agentPresent: false,
        agentAudioActive: false,
        rejectedEvents: 0,
        muted: _options.startMuted,
        clearEndReason: true,
      ),
    );
    _stats.value = const NexaVoiceCallStats();
    _bluetoothAsked = false;
    _callAudioOff(); // nothing from a previous call carries over
    _diagnostics.record('voice.start', {
      'language': _languageTag,
      'muted': _options.startMuted,
      'chat_session_id': _sessions.current?.sessionId.value,
    });
    _dispatch(const VoiceStartRequested());
  }

  /// Ends the call (`DELETE`, then leave the room). Safe when no call is
  /// active.
  ///
  /// [reason] becomes `endReason` of the state and the `NexaVoiceEnded`
  /// event (`user` by default; `background` when the app was left).
  Future<void> end({String reason = 'user'}) async {
    if (_disposed) return;
    _endReason = reason;
    _ending = true;
    _dispatch(const VoiceEndRequested());
    _ending = false;
  }

  /// Ends the call in progress and starts a new one in the same
  /// conversation, so a voice activated with `voice.profile.activate`
  /// applies (the contract changes the voice of the *next* session only;
  /// there is no hot swap). No-op when no call is active.
  bool get restartsOnVoiceActivation => _options.restartOnVoiceActivation;

  Future<void> restartForNewVoice() async {
    if (_disposed || !_state.value.isActive) return;
    _diagnostics.record('voice.restart_for_new_voice', {
      'voice_session_id': _voiceSessionId,
    });
    _set(_state.value.copyWith(switchingVoice: true));
    await end();
    await _settled();
    if (_disposed) return;
    await start();
    // A refused start leaves the flag set otherwise.
    if (!_state.value.isActive) {
      _set(_state.value.copyWith(switchingVoice: false));
    }
  }

  /// Completes once the call is fully over (DELETE sent, room left).
  Future<void> _settled() {
    bool over(NexaVoiceState s) => !s.isActive;
    if (over(_state.value)) return Future.value();
    final done = Completer<void>();
    void check() {
      if (over(_state.value) && !done.isCompleted) done.complete();
    }

    _state.addListener(check);
    return done.future
        .timeout(const Duration(seconds: 20), onTimeout: () {})
        .whenComplete(() => _state.removeListener(check));
  }

  /// Mutes/unmutes the microphone (local only; the backend has no mute
  /// event). No-op outside a call.
  Future<void> setMuted({required bool muted}) async {
    _check();
    if (!_state.value.isActive || muted == _state.value.muted) return;
    _set(_state.value.copyWith(muted: muted));
    _diagnostics.record('voice.mute', {'muted': muted});
    _emit(NexaVoiceMuteChanged(clock.now(), muted: muted));
    _dispatch(VoiceMuteToggled(muted: muted));
    _sendClientInfo();
  }

  /// Convenience for the capsule's single button.
  Future<void> toggleMute() => setMuted(muted: !_state.value.muted);

  // ------------------------------------------------- mute grace (E-01/E-02)

  Timer? _muteGrace;
  VoiceState? _muteFromPhase;
  DateTime? _lastSpeechAt;
  bool? _micWanted;
  bool _micBusy = false;

  /// A sentence may still be in flight: the user is speaking or the server
  /// is transcribing, or speech was heard in the last 1.5 s.
  bool _utterancePending() {
    final from = _muteFromPhase;
    if (from == VoiceState.userSpeaking || from == VoiceState.transcribing) {
      return true;
    }
    final at = _lastSpeechAt;
    return at != null &&
        clock.now().difference(at) < const Duration(milliseconds: 1500);
  }

  void _startMuteGrace() {
    _muteGrace?.cancel();
    _set(_state.value.copyWith(mutePending: true));
    _diagnostics.record('voice.mute_deferred', {
      'grace_ms': _options.muteGrace.inMilliseconds,
    });
    _muteGrace = Timer(_options.muteGrace, () => _applyMute('grace'));
  }

  void _cancelMuteGrace() {
    if (_muteGrace == null) return;
    _muteGrace!.cancel();
    _muteGrace = null;
    if (!_disposed && _state.value.mutePending) {
      _set(_state.value.copyWith(mutePending: false));
    }
  }

  void _applyMute(String cause) {
    if (_muteGrace == null || _disposed) return;
    _muteGrace!.cancel();
    _muteGrace = null;
    _diagnostics.record('voice.mute_applied', {'cause': cause});
    if (_state.value.mutePending) {
      _set(_state.value.copyWith(mutePending: false));
    }
    if (_state.value.muted && _state.value.isActive) unawaited(_setMic(false));
  }

  /// Applies the newest wanted microphone state; rapid toggles collapse into
  /// at most one call in flight plus one for the final intent.
  Future<void> _setMic(bool enabled) async {
    _micWanted = enabled;
    if (_micBusy) return;
    _micBusy = true;
    try {
      while (_micWanted != null) {
        final want = _micWanted!;
        _micWanted = null;
        if (want == _transport.isMicrophoneEnabled) continue;
        await _timedMic(want);
      }
    } finally {
      _micBusy = false;
    }
  }

  /// A phone call took the audio (true) or ended (false). The microphone is
  /// off during it whatever the mute button says; afterwards the user's
  /// choice applies again and the communication mode is restored.
  Future<void> _onPhoneCall(bool active) async {
    if (_disposed || _phoneHold == active) return;
    if (!_options.holdOnPhoneCall) return;
    _phoneHold = active;
    _set(_state.value.copyWith(phoneCallHold: active));
    _diagnostics.record('voice.phone_hold', {'active': active});
    if (!_state.value.isActive) return;
    if (active) {
      await _setMic(false);
      return;
    }
    await _callAudio?.recoverAfterPhoneCall();
    if (_disposed || !_state.value.isActive || _phoneHold) return;
    _phoneReleasing = true;
    try {
      await _setMic(!_state.value.muted);
    } finally {
      _phoneReleasing = false;
    }
    _sendClientInfo();
  }

  /// While "speaking", once the agent's audio was heard and then went
  /// silent, a timer returns the call to "listening" unless a server event
  /// or agent audio comes first (a lost `assistant_turn_ended` or
  /// `interrupted` must not leave the UI stuck on "speaking").
  void _armSpeakingWatchdog() {
    final timeout = _options.speakingSilenceTimeout;
    if (_disposed ||
        timeout <= Duration.zero ||
        _state.value.phase != VoiceState.aiSpeaking ||
        !_agentHeard ||
        !_agentSilent) {
      _speakingWatchdog?.cancel();
      _speakingWatchdog = null;
      return;
    }
    _speakingWatchdog ??= Timer(timeout, () {
      _speakingWatchdog = null;
      if (_disposed ||
          !_agentSilent ||
          _state.value.phase != VoiceState.aiSpeaking) {
        return;
      }
      _diagnostics.record('voice.speaking_timeout', {
        'ms': timeout.inMilliseconds,
      });
      _dispatch(const VoiceAssistantTurnEnded());
    });
  }

  String _micOffReason() => _phoneHold ? 'phone_call' : 'mute';

  /// The call is over (any path): stop polling platform audio, forget the
  /// agent's signal configuration and any phone-call hold.
  void _callAudioOff() {
    if (_callAudio?.state.value.active ?? false) {
      unawaited(_callAudio!.endCall());
    }
    _signals.reset();
    if (_phoneHold) {
      _phoneHold = false;
      _set(_state.value.copyWith(phoneCallHold: false));
    }
  }

  /// Client info for the server's call trace (no content): which app and
  /// device, the route, mute and phone-call state. Sent on agent_ready and
  /// on every change, coalesced by [NexaVoiceSignals].
  void _sendClientInfo() {
    if (_disposed || !_signals.clientInfoEnabled) return;
    final audio = _callAudio?.state.value;
    _signals.clientInfo({
      'source': 'app',
      'sdk': 'nexa_flutter',
      'platform': audio?.platform ?? defaultTargetPlatform.name,
      'os_version': audio?.osVersion,
      'device_model': audio?.model,
      'route': audio?.route.name,
      'speaker_preferred': audio?.speakerPreferred,
      'audio_mode': audio?.mode,
      'muted': _state.value.muted,
      'microphone_on': _transport.isMicrophoneEnabled,
      'phone_call': _phoneHold,
    });
  }

  void _onAudioChanged() {
    if (_state.value.isActive) unawaited(_askBluetoothIfNeeded());
  }

  /// Android 12+: a Bluetooth headset is usable only with BLUETOOTH_CONNECT.
  /// Asked only when a headset is actually present, once per call; a
  /// refusal changes nothing (the call stays on the phone).
  Future<void> _askBluetoothIfNeeded() async {
    final audio = _callAudio;
    if (audio == null || _bluetoothAsked) return;
    await audio.refresh();
    final s = audio.state.value;
    if (!s.bluetoothPresent || !s.bluetoothPermissionNeeded) return;
    _bluetoothAsked = true;
    bool granted;
    try {
      granted = await _permissions
          .request(NexaPermission.bluetooth)
          .timeout(const Duration(seconds: 30), onTimeout: () => false);
    } on Object {
      granted = false;
    }
    _diagnostics.record('voice.bluetooth_permission', {'granted': granted});
    await audio.refresh();
  }

  /// Toggles the published microphone and records how long the engine took
  /// (the unmute budget is 1 s; the first unmute of a call that started
  /// muted also publishes the track and is the slow case).
  Future<void> _timedMic(bool enabled) async {
    final watch = Stopwatch()..start();
    await _transport.setMicrophoneEnabled(enabled: enabled);
    final ms = watch.elapsedMilliseconds;
    _diagnostics.record('voice.mic_applied', {'enabled': enabled, 'ms': ms});
    if (_disposed) return;
    _signals.listening(
      listening: enabled,
      reason: enabled
          ? (_phoneReleasing ? 'phone_call_ended' : 'unmute')
          : _micOffReason(),
    );
    _sendClientInfo();
    _stats.value = enabled
        ? _stats.value.copyWith(unmuteMs: ms)
        : _stats.value.copyWith(muteMs: ms);
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _muteGrace?.cancel();
    _speakingWatchdog?.cancel();
    if (_voiceSessionId != null) await _teardown();
    _disposed = true;
    _backgroundTimer?.cancel();
    _capTimer?.cancel();
    await _subscription?.cancel();
    for (final sub in _audioSubs) {
      await sub.cancel();
    }
    await _callAudio?.dispose();
    await _events.close();
    await _toolEvents.close();
    _state.dispose();
    _levels.dispose();
    _stats.dispose();
  }

  // --------------------------------------------------------------- engine

  void _dispatch(VoiceEvent event) {
    if (_disposed) return;
    final before = _state.value.phase;
    if (event is VoiceMuteToggled && event.muted) _muteFromPhase = before;
    if (event is VoiceUserSpeechStarted || event is VoiceUserSpeechEnded) {
      _lastSpeechAt = clock.now();
    }
    // The reply starting means the server closed that turn.
    if (event is VoiceAssistantThinking ||
        event is VoiceAssistantAudioStarted ||
        event is VoiceAssistantTurnEnded) {
      _lastSpeechAt = null;
    }
    if (_muteGrace != null &&
        (event is VoiceAssistantThinking ||
            event is VoiceAssistantAudioStarted)) {
      _applyMute('reply_started');
    }
    final transition = _machine.transition(before, event);
    if (transition.state != before) {
      _diagnostics.record('voice.phase', {
        'from': before.name,
        'to': transition.state.name,
        'cause': event.runtimeType.toString(),
      });
      // The confirmation belongs to one stretch of the user's speech.
      _set(
        _state.value.copyWith(
          phase: transition.state,
          interruptConfirmed: false,
        ),
      );
      if (!_state.value.isActive) _callAudioOff();
      if (transition.state == VoiceState.aiSpeaking) _agentHeard = false;
      _armSpeakingWatchdog();
      _emit(
        NexaVoicePhaseChanged(clock.now(), from: before, to: transition.state),
      );
      if (transition.state == VoiceState.quotaExceeded) {
        _finish('quota_exceeded');
      } else if (transition.state == VoiceState.ended) {
        _finish(_state.value.endReason ?? (_ending ? _endReason : 'server'));
      } else if (transition.state == VoiceState.microphoneDenied) {
        _set(
          _state.value.copyWith(
            error: const PermissionDeniedException('microphone'),
          ),
        );
        _finish('microphone_denied');
      }
    }
    for (final command in transition.commands) {
      unawaited(_execute(command));
    }
  }

  Future<void> _execute(VoiceCommand command) async {
    try {
      switch (command) {
        case RequestMicrophonePermission():
          final watch = Stopwatch()..start();
          final granted = await _permissions.request(NexaPermission.microphone);
          _diagnostics.record('voice.permission', {
            'granted': granted,
            'ms': watch.elapsedMilliseconds,
          });
          if (granted) await _askBluetoothIfNeeded();
          _dispatch(VoicePermissionResult(granted: granted));
        case ConnectTransport():
          try {
            await _connect();
          } on NexaException catch (e) {
            // Ended while joining: the teardown deleted the room, so the
            // join fails. That is not an error for the user.
            if (_callOver) {
              _diagnostics.record('voice.connect_aborted', nexaErrorFields(e));
              return;
            }
            rethrow;
          }
        case StartCapture():
          await _timedMic(!_state.value.muted && !_phoneHold);
          if (_state.value.muted) {
            _dispatch(const VoiceMuteToggled(muted: true));
          }
        case StopCapture():
          // Ending: leaving the room releases the microphone. Muting first
          // is redundant and, on iOS, the voice-processing mute set here
          // survived into the next call (every later call was silent).
          if (_callOver) break;
          if (_transport.isMicrophoneEnabled) {
            await _transport.setMicrophoneEnabled(enabled: false);
          }
        case SetTransportMuted(:final muted):
          if (muted &&
              _options.muteGrace > Duration.zero &&
              _utterancePending()) {
            _startMuteGrace();
          } else {
            _cancelMuteGrace();
            await _setMic(!muted && !_phoneHold);
          }
        case StartPlayback():
        case StopPlayback():
          break; // the engine plays the agent's track; nothing to do locally
        case SendInterrupt():
          await _transport.interrupt(); // local only: no server command
        case DisconnectTransport():
          await _teardown();
        case LogVoiceEvent(:final message):
          _logger.log(NexaLogLevel.info, message);
      }
    } on NexaException catch (e) {
      _fail(e);
    } on Object catch (e) {
      _logger.log(
        NexaLogLevel.warning,
        'voice command ${command.runtimeType} failed: ${e.runtimeType}',
      );
      _fail(UnknownNexaException('voice command failed', cause: e));
    }
  }

  Future<void> _connect() async {
    final notBefore = _retryNotBefore;
    if (notBefore != null) {
      final wait = notBefore.difference(clock.now());
      if (wait > Duration.zero) {
        _diagnostics.record('voice.retry_wait', {'ms': wait.inMilliseconds});
        await Future<void>.delayed(wait);
      }
      _retryNotBefore = null;
    }
    if (_state.value.phase != VoiceState.connecting) return; // ended meanwhile
    // Tools and saved spoken turns need the server conversation. A call
    // can start before the chat has created it (e.g. the assistant panel
    // on a cold start): join or create it first.
    if (_sessions.conversationId == null && _sessions.canCreateConversation) {
      try {
        await _sessions.start();
      } on NexaException catch (e) {
        _logger.log(
          NexaLogLevel.warning,
          'voice: no conversation (${e.code.name}); tools and saved turns '
          'are unavailable in this call',
        );
      }
      if (_state.value.phase != VoiceState.connecting) return;
    }
    final VoiceGrant grant;
    final watch = Stopwatch()..start();
    try {
      grant = await _provisioner.create(
        languageTag: _languageTag,
        chatSessionId: _sessions.current?.sessionId,
        conversationId: _sessions.conversationId,
        clientTools: clientToolsProvider == null
            ? const []
            : await clientToolsProvider!(),
      );
    } on NexaException catch (e) {
      _diagnostics.record('voice.create_failed', {
        'ms': watch.elapsedMilliseconds,
        ...nexaErrorFields(e),
        if (e is ServerException && e.retryAfter != null)
          'retry_after_ms': e.retryAfter!.inMilliseconds,
      });
      if (e is ServerException && e.serverCode == 'voice_unavailable') {
        _retryNotBefore = clock.now().add(
          e.retryAfter ?? const Duration(seconds: 5),
        );
      }
      rethrow;
    }
    // QA evidence (names only): can this call run tools, and which device
    // tools did the server accept?
    _logger.log(
      NexaLogLevel.info,
      'voice ${grant.voiceSessionId}: tools=${grant.tools.enabled}'
      '${grant.tools.reason == null ? '' : ' (${grant.tools.reason})'}'
      ' client_tools=${grant.tools.clientTools.join(',')}'
      ' server_tools=${grant.tools.tools.length}',
    );
    _diagnostics.record('voice.created', {
      'ms': watch.elapsedMilliseconds,
      'voice_session_id': grant.voiceSessionId,
      'chat_session_id': _sessions.current?.sessionId.value,
      'tools_enabled': grant.tools.enabled,
      'tools_reason': grant.tools.reason,
      'voice_path': grant.voicePath,
      'max_seconds': grant.maxDuration.inSeconds,
      'reconnect_grace_s': grant.reconnectGraceSeconds,
    });
    _grant = grant;
    _voiceSessionId = grant.voiceSessionId;
    if (_state.value.phase != VoiceState.connecting) {
      // Ended while the create call was in flight: release it.
      await _teardown();
      return;
    }
    _set(
      _state.value.copyWith(
        agentIdentity: grant.agentIdentity,
        eventsVerified: true,
        voiceIdentity: grant.voiceIdentity,
        clearVoiceIdentity: grant.voiceIdentity == null,
        switchingVoice: false,
      ),
    );
    _armCapBackstop(grant);
    await _subscription?.cancel();
    _subscription = _transport.events.listen(_onTransportEvent);
    await _callAudio?.beginCall();
    await _transport.connect(grant);
    unawaited(_callAudio?.afterConnect());
  }

  void _armCapBackstop(VoiceGrant grant) {
    _capTimer?.cancel();
    _capTimer = Timer(grant.maxDuration + capBackstop, () {
      if (!_state.value.isActive) return;
      unawaited(
        _resolveFromServer(
          fallbackError: const SessionExpiredException(
            'Voice session expired.',
          ),
          fallbackReason: 'expired',
        ),
      );
    });
  }

  void _onTransportEvent(RealtimeVoiceEvent e) {
    if (_disposed) return;
    if (e is! RealtimeAudioLevels && _speakingWatchdog != null) {
      // A server event: the silence timer restarts from it.
      _speakingWatchdog!.cancel();
      _speakingWatchdog = null;
      scheduleMicrotask(_armSpeakingWatchdog);
    }
    switch (e) {
      case RealtimeConnected():
        _diagnostics.record('voice.handshake_done');
        _dispatch(const VoiceConnected());
      case RealtimeReconnecting():
        _dispatch(const VoiceDisconnected(willReconnect: true));
      case RealtimeDisconnected(:final reason):
        if (_tearingDown ||
            _state.value.phase == VoiceState.ended ||
            _state.value.phase == VoiceState.idle ||
            _state.value.phase.isTerminal) {
          return; // our own teardown or already over
        }
        _logger.log(NexaLogLevel.info, 'voice room disconnected: $reason');
        _dispatch(const VoiceDisconnected(willReconnect: true));
        unawaited(_recover());
      case RealtimeAgentUnresponsive():
        _diagnostics.record('voice.agent_unresponsive');
        unawaited(
          _resolveFromServer(
            fallbackError: _agentUnavailable('agent did not answer resume'),
            fallbackReason: 'agent_lost',
          ),
        );
      case RealtimeAgentJoined(:final identity):
        _set(
          _state.value.copyWith(agentIdentity: identity, agentPresent: true),
        );
        _emit(
          NexaVoiceAgentPresence(
            clock.now(),
            identity: identity,
            present: true,
          ),
        );
      case RealtimeAgentReady(:final capabilities):
        _set(_state.value.copyWith(agentPresent: true));
        _signals.configure(capabilities);
        _sendClientInfo();
        // Only a deliberate off state; the mic may simply not be started
        // yet when agent_ready arrives.
        if (_state.value.muted || _phoneHold) {
          _signals.listening(listening: false, reason: _micOffReason());
        }
      case RealtimeAgentAudioTrack(:final subscribed):
        _set(_state.value.copyWith(agentAudioActive: subscribed));
      case RealtimeAgentLeft(:final identity):
        // The server declares `agent_lost` after ~30 s and deletes the room;
        // the resulting disconnect drives the outcome. Only mark presence.
        _set(_state.value.copyWith(agentPresent: false));
        _emit(
          NexaVoiceAgentPresence(
            clock.now(),
            identity: identity,
            present: false,
          ),
        );
      case RealtimeSessionSnapshot(:final state):
        _applySnapshot(state);
      case RealtimeAudioLevels(:final local, :final agent):
        _levels.value = NexaVoiceLevels(
          local: _state.value.muted ? 0 : local,
          agent: agent,
        );
        _agentSilent = agent < 0.01;
        if (!_agentSilent) _agentHeard = true;
        _armSpeakingWatchdog();
      case RealtimeUserSpeechStarted():
        _stats.value = _stats.value.copyWith(
          speechStarts: _stats.value.speechStarts + 1,
        );
        if (_state.value.phase == VoiceState.aiSpeaking) {
          // Barge-in attempt (QA analysis); the reply keeps playing until
          // the server confirms with `interrupted`.
          _diagnostics.record('voice.speech_during_reply');
        }
        _dispatch(const VoiceUserSpeechStarted());
      case RealtimeUserSpeechEnded():
        _dispatch(const VoiceUserSpeechEnded());
      case RealtimeTranscript(:final text, :final isFinal):
        _transcript(VoiceSpeaker.user, text, isFinal);
        if (isFinal) {
          _dispatch(const VoiceTranscriptFinal());
          _reportTurn('user', text);
        }
      case RealtimeAssistantTranscript(:final text, :final isFinal):
        _transcript(VoiceSpeaker.assistant, text, isFinal);
        if (isFinal) _reportTurn('assistant', text);
      case RealtimeToolEvent(:final type, :final fields):
        // QA evidence: which tool events arrive (no arguments or results).
        _logger.log(
          NexaLogLevel.info,
          'voice tool event: $type '
          'tool=${fields['tool'] ?? (fields['ui'] is Map ? 'ui' : '-')} '
          'status=${fields['status'] ?? '-'} '
          'id=${fields['tool_call_id'] ?? '-'}',
        );
        if (!_toolEvents.isClosed) {
          _toolEvents.add(
            NexaVoiceToolEvent(type, fields, _grant?.tools.sessionId),
          );
        }
      case RealtimeAssistantThinking():
        _dispatch(const VoiceAssistantThinking());
      case RealtimeAssistantSpeakingStarted():
        _dispatch(const VoiceAssistantAudioStarted());
      case RealtimeAssistantSpeakingEnded():
        _dispatch(const VoiceAssistantTurnEnded());
      case RealtimeInterrupted():
        _stats.value = _stats.value.copyWith(
          interruptions: _stats.value.interruptions + 1,
        );
        final from = _state.value.phase;
        final wasBargeIn =
            from == VoiceState.bargeIn || from == VoiceState.aiSpeaking;
        _dispatch(const VoiceInterruptAcknowledged());
        if (wasBargeIn && _state.value.phase == VoiceState.userSpeaking) {
          _set(_state.value.copyWith(interruptConfirmed: true));
        }
      case RealtimeModelBusy():
        _dispatch(const VoiceModelBusy());
      case RealtimeModelAvailable():
        _dispatch(const VoiceModelAvailable());
      case RealtimeQuotaExceeded(:final quotaKind):
        _set(
          _state.value.copyWith(
            error: QuotaExceededException(quotaKind: quotaKind),
          ),
        );
        _dispatch(const VoiceQuotaExceeded());
      case RealtimeSessionEnding(:final reason):
        // Agent's session_ended: REST stays `active` until we DELETE.
        if (reason == 'quota_exceeded') {
          _dispatch(const VoiceQuotaExceeded()); // no-op if already there
        } else {
          _set(_state.value.copyWith(endReason: 'server:$reason'));
          _dispatch(const VoiceEndRequested());
        }
      case RealtimeNetworkQuality(:final weak):
        _dispatch(VoiceNetworkQualityChanged(weak: weak));
      case RealtimeAgentError(:final code, :final retryable, :final component):
        _logger.log(
          NexaLogLevel.warning,
          'voice agent error $code (${component ?? '-'}) retryable=$retryable',
        );
        if (!retryable) {
          _fail(
            ServerException(
              statusCode: 0,
              serverCode: code,
              message: 'Voice agent error: $code',
            ),
          );
        }
      case RealtimeEventRejected(:final reason):
        _set(
          _state.value.copyWith(
            rejectedEvents: _state.value.rejectedEvents + 1,
          ),
        );
        _emit(NexaVoiceEventRejected(clock.now(), reason));
      case RealtimeFailed(:final error):
        _fail(
          error is NexaException
              ? error
              : TransportException(
                  'Voice transport failed: $error',
                  cause: error,
                ),
        );
    }
  }

  /// Reconciles the server state string (`session_state` / resume) with the
  /// machine. Only transitions the machine accepts take effect, so a stale
  /// snapshot cannot produce an impossible state.
  void _applySnapshot(String state) {
    switch (state) {
      case 'user_speaking':
        _dispatch(const VoiceUserSpeechStarted());
      case 'transcribing':
        _dispatch(const VoiceUserSpeechEnded());
      case 'thinking':
        _dispatch(const VoiceAssistantThinking());
      case 'ai_speaking':
        _dispatch(const VoiceAssistantAudioStarted());
      case 'model_busy':
        _dispatch(const VoiceModelBusy());
      case 'listening':
        final phase = _state.value.phase;
        if (phase == VoiceState.aiSpeaking || phase == VoiceState.thinking) {
          _dispatch(const VoiceAssistantTurnEnded());
        } else if (phase == VoiceState.modelBusy) {
          _dispatch(const VoiceModelAvailable());
        }
      default:
        break; // idle / barge_in / quota_exceeded / ended: events decide
    }
  }

  /// Contract §8 step 3: after a disconnect, `GET` first; ended → stop;
  /// active → refresh the join token and rejoin with the same identity.
  Future<void> _recover() async {
    if (_recovering) return;
    _recovering = true;
    final watch = Stopwatch()..start();
    var outcome = 'aborted';
    _diagnostics.record('voice.recover_started');
    try {
      final id = _voiceSessionId;
      final grant = _grant;
      if (id == null || grant == null) return;
      final status = await _statusWithin(
        Duration(seconds: grant.reconnectGraceSeconds),
      );
      if (status == null) {
        outcome = 'gateway_unreachable';
        _fail(
          const NetworkException(
            NexaErrorCode.networkUnreachable,
            'Could not reach the gateway to resume the call.',
          ),
        );
        return;
      }
      if (status.isEnded) {
        outcome = 'server_ended:${status.endReason ?? '-'}';
        _applyServerEnd(status);
        return;
      }
      final VoiceGrant fresh;
      try {
        fresh = await _provisioner.refreshToken(grant);
      } on VoiceSessionOverException {
        outcome = 'session_over';
        final after = await _statusWithin(const Duration(seconds: 5));
        _applyServerEnd(
          after ??
              VoiceSessionStatus(
                voiceSessionId: id,
                status: 'ended',
                agentState: 'ended',
              ),
        );
        return;
      }
      if (_state.value.phase != VoiceState.reconnecting) return;
      _grant = fresh;
      await _transport.connect(fresh); // handshake → RealtimeConnected
      unawaited(_callAudio?.afterConnect());
      outcome = 'rejoined';
    } on NexaException catch (e) {
      outcome = 'failed:${e.code.name}';
      _fail(e);
    } finally {
      _diagnostics.record('voice.recover_done', {
        'outcome': outcome,
        'ms': watch.elapsedMilliseconds,
      });
      _recovering = false;
    }
  }

  /// `GET` with retries (network only) for up to [window].
  Future<VoiceSessionStatus?> _statusWithin(Duration window) async {
    final id = _voiceSessionId;
    if (id == null) return null;
    final deadline = clock.now().add(window);
    var delay = const Duration(milliseconds: 500);
    while (true) {
      try {
        return await _provisioner.status(id);
      } on NetworkException {
        if (clock.now().isAfter(deadline)) return null;
        await Future<void>.delayed(delay);
        delay = delay * 2 > const Duration(seconds: 4)
            ? const Duration(seconds: 4)
            : delay * 2;
      } on NexaException catch (e) {
        _logger.log(NexaLogLevel.warning, 'voice GET failed: ${e.code.name}');
        return null;
      }
    }
  }

  /// `GET`, then end according to the server; when the server still says
  /// active, end the call ourselves with [fallbackError].
  Future<void> _resolveFromServer({
    required NexaException fallbackError,
    required String fallbackReason,
  }) async {
    final status = await _statusWithin(const Duration(seconds: 5));
    if (status != null && status.isEnded) {
      _applyServerEnd(status);
      return;
    }
    _set(
      _state.value.copyWith(error: fallbackError, endReason: fallbackReason),
    );
    _emit(NexaVoiceErrorOccurred(clock.now(), fallbackError));
    if (fallbackError is SessionExpiredException) {
      _dispatch(const VoiceEndRequested());
    } else {
      _dispatch(VoiceFailed(fallbackError)); // → disconnected + teardown
    }
  }

  /// Maps an authoritative `end_reason` onto the machine (contract §7).
  void _applyServerEnd(VoiceSessionStatus status) {
    final reason = status.endReason ?? 'ended';
    if (status.isAgentUnavailable) {
      final error = _agentUnavailable(reason);
      _set(_state.value.copyWith(error: error, endReason: reason));
      _emit(NexaVoiceErrorOccurred(clock.now(), error));
      _dispatch(VoiceFailed(error)); // disconnected + teardown, retry offered
    } else if (reason == 'quota_exceeded') {
      _set(
        _state.value.copyWith(
          error: const QuotaExceededException(quotaKind: 'voice_seconds'),
        ),
      );
      _dispatch(const VoiceQuotaExceeded());
    } else {
      _set(_state.value.copyWith(endReason: 'server:$reason'));
      _dispatch(const VoiceEndRequested());
    }
  }

  static ServerException _agentUnavailable(String detail) => ServerException(
    statusCode: 0,
    serverCode: 'agent_lost',
    message: 'Voice agent unavailable ($detail).',
    retryable: true,
  );

  /// Spoken turns join the shared conversation. Tool-enabled calls are
  /// recorded by the gateway itself (`server_recorded`).
  void _reportTurn(String role, String text) {
    final reporter = turnReporter;
    final grant = _grant;
    final conversation = _sessions.conversationId;
    if (reporter == null ||
        grant == null ||
        conversation == null ||
        grant.tools.enabled ||
        text.trim().isEmpty) {
      return;
    }
    // Production accepts `[A-Za-z0-9._-]{1,64}` (no `:`).
    final turnId = '${grant.voiceSessionId}_${++_turnCounter}';
    unawaited(
      _sendTurn(
        reporter,
        conversation,
        grant.voiceSessionId,
        role,
        text,
        turnId,
      ),
    );
  }

  // The reporter may return a typed future (`Future<bool>`), so failures are
  // caught here rather than with `catchError`, whose handler must match it.
  Future<void> _sendTurn(
    Future<void> Function(String, String, String, String, String) reporter,
    String conversation,
    String voiceSessionId,
    String role,
    String text,
    String turnId,
  ) async {
    try {
      await reporter(conversation, voiceSessionId, role, text, turnId);
    } on Object catch (e) {
      _diagnostics.record('voice.turn_report_failed', {
        'error': e.runtimeType.toString(),
      });
    }
  }

  void _transcript(VoiceSpeaker speaker, String text, bool isFinal) {
    if (!_options.keepTranscript || text.isEmpty) return;
    final entries = [..._state.value.transcript];
    final last = entries.isEmpty ? null : entries.last;
    final replace = last != null && last.speaker == speaker && !last.isFinal;
    final entry = replace
        ? last.copyWith(text: text, isFinal: isFinal)
        : VoiceTranscriptEntry(
            speaker: speaker,
            text: text,
            isFinal: isFinal,
            at: clock.now(),
          );
    if (replace) {
      entries[entries.length - 1] = entry;
    } else {
      entries.add(entry);
    }
    while (entries.length > _options.maxTranscriptEntries) {
      entries.removeAt(0);
    }
    _set(_state.value.copyWith(transcript: entries));
    _emit(NexaVoiceTranscriptUpdated(clock.now(), entry));
  }

  void _fail(NexaException error) {
    _logger.log(NexaLogLevel.warning, 'voice failed: ${error.code.name}');
    _diagnostics.record('voice.failed', nexaErrorFields(error));
    _set(_state.value.copyWith(error: error, endReason: 'failed'));
    _emit(NexaVoiceErrorOccurred(clock.now(), error));
    if (error is QuotaExceededException) {
      _dispatch(const VoiceQuotaExceeded());
    } else {
      _dispatch(VoiceFailed(error));
    }
  }

  void _finish(String reason) {
    _diagnostics.record('voice.ended', {
      'reason': reason,
      'rejected_events': _state.value.rejectedEvents,
    });
    _set(_state.value.copyWith(endReason: reason));
    _emit(NexaVoiceEnded(clock.now(), reason));
  }

  /// Cleanup obligations (lifecycle §cleanup): stop capture, `DELETE`,
  /// disconnect, drop the grant. Idempotent.
  Future<void> _teardown() async {
    if (_tearingDown) return;
    _tearingDown = true;
    try {
      _capTimer?.cancel();
      _levels.value = NexaVoiceLevels.silent;
      final id = _voiceSessionId;
      _voiceSessionId = null;
      _grant = null;
      final watch = Stopwatch()..start();
      // No explicit mute: disconnect() unpublishes the microphone (see
      // StopCapture).
      if (id != null) await _provisioner.end(id);
      try {
        await _transport.disconnect();
      } on Object catch (e) {
        _logger.log(NexaLogLevel.debug, 'voice disconnect: $e');
      }
      _callAudioOff();
      _set(_state.value.copyWith(agentPresent: false, agentAudioActive: false));
      _diagnostics.record('voice.teardown_done', {
        'voice_session_id': id,
        'ms': watch.elapsedMilliseconds,
      });
    } finally {
      _tearingDown = false;
    }
  }

  /// The call is ending (no reconnect): capture stops with the room.
  bool get _callOver {
    final phase = _state.value.phase;
    return phase == VoiceState.ended ||
        phase == VoiceState.idle ||
        phase.isTerminal;
  }

  void _set(NexaVoiceState next) {
    if (!_disposed) _state.value = next;
  }

  void _emit(NexaVoiceEvent event) {
    if (!_events.isClosed) _events.add(event);
  }

  void _check() {
    if (_disposed) throw const NotInitializedException('Voice disposed.');
  }
}

/// A labeeb.sdk/1 tool event received in a call. [toolsSessionId] is the
/// hidden chat session (`tools.session_id`) that device tools answer in.
final class NexaVoiceToolEvent {
  const NexaVoiceToolEvent(this.type, this.fields, this.toolsSessionId);
  final String type;
  final Map<String, Object?> fields;
  final String? toolsSessionId;
}
