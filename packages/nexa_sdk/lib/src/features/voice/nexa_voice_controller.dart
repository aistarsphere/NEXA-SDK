import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:nexa_core/nexa_core.dart';
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
    NexaVoiceOptions options = const NexaVoiceOptions(),
    String languageTag = 'en',
  }) : _sessions = sessions,
       _provisioner = provisioner,
       _transport = transport,
       _permissions = permissions,
       _logger = logger,
       _options = options,
       _languageTag = languageTag;

  /// Extra time after `max_seconds` before the client ends the call itself
  /// (the server normally ends it first with `quota_exceeded`).
  static const capBackstop = Duration(seconds: 15);

  final SessionManager _sessions;
  final VoiceProvisioner _provisioner;
  final RealtimeVoiceTransport _transport;
  final NexaPermissionHandler _permissions;
  final NexaLogger _logger;
  final NexaVoiceOptions _options;
  final VoiceSessionMachine _machine = const VoiceSessionMachine();

  final ValueNotifier<NexaVoiceState> _state = ValueNotifier(
    const NexaVoiceState(),
  );
  final StreamController<NexaVoiceEvent> _events =
      StreamController<NexaVoiceEvent>.broadcast();

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

  /// Current snapshot; listen for UI binding.
  ValueListenable<NexaVoiceState> get state => _state;

  /// Typed event stream for hosts (analytics, custom UI).
  Stream<NexaVoiceEvent> get events => _events.stream;

  /// Active grant (redacted `toString`), for diagnostics only.
  VoiceGrant? get currentGrant => _grant;

  /// Whether the microphone track is currently published and enabled.
  bool get microphoneEnabled => _transport.isMicrophoneEnabled;

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
    _dispatch(const VoiceStartRequested());
  }

  /// Ends the call (`DELETE`, then leave the room). Safe when no call is
  /// active.
  Future<void> end() async {
    if (_disposed) return;
    _ending = true;
    _dispatch(const VoiceEndRequested());
    _ending = false;
  }

  /// Mutes/unmutes the microphone (local only; the backend has no mute
  /// event). No-op outside a call.
  Future<void> setMuted({required bool muted}) async {
    _check();
    if (!_state.value.isActive || muted == _state.value.muted) return;
    _set(_state.value.copyWith(muted: muted));
    _emit(NexaVoiceMuteChanged(clock.now(), muted: muted));
    _dispatch(VoiceMuteToggled(muted: muted));
  }

  /// Convenience for the capsule's single button.
  Future<void> toggleMute() => setMuted(muted: !_state.value.muted);

  Future<void> dispose() async {
    if (_disposed) return;
    if (_voiceSessionId != null) await _teardown();
    _disposed = true;
    _capTimer?.cancel();
    await _subscription?.cancel();
    await _events.close();
    _state.dispose();
  }

  // --------------------------------------------------------------- engine

  void _dispatch(VoiceEvent event) {
    if (_disposed) return;
    final before = _state.value.phase;
    final transition = _machine.transition(before, event);
    if (transition.state != before) {
      _set(_state.value.copyWith(phase: transition.state));
      _emit(
        NexaVoicePhaseChanged(clock.now(), from: before, to: transition.state),
      );
      if (transition.state == VoiceState.quotaExceeded) {
        _finish('quota_exceeded');
      } else if (transition.state == VoiceState.ended) {
        _finish(_state.value.endReason ?? (_ending ? 'user' : 'server'));
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
          final granted = await _permissions.request(NexaPermission.microphone);
          _dispatch(VoicePermissionResult(granted: granted));
        case ConnectTransport():
          await _connect();
        case StartCapture():
          await _transport.setMicrophoneEnabled(enabled: !_state.value.muted);
          if (_state.value.muted) {
            _dispatch(const VoiceMuteToggled(muted: true));
          }
        case StopCapture():
          if (_transport.isMicrophoneEnabled) {
            await _transport.setMicrophoneEnabled(enabled: false);
          }
        case SetTransportMuted(:final muted):
          await _transport.setMicrophoneEnabled(enabled: !muted);
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
      _fail(UnknownNexaException('voice command failed', cause: e));
    }
  }

  Future<void> _connect() async {
    final notBefore = _retryNotBefore;
    if (notBefore != null) {
      final wait = notBefore.difference(clock.now());
      if (wait > Duration.zero) await Future<void>.delayed(wait);
      _retryNotBefore = null;
    }
    if (_state.value.phase != VoiceState.connecting) return; // ended meanwhile
    final VoiceGrant grant;
    try {
      grant = await _provisioner.create(
        languageTag: _languageTag,
        chatSessionId: _sessions.current?.sessionId,
      );
    } on ServerException catch (e) {
      if (e.serverCode == 'voice_unavailable') {
        _retryNotBefore = clock.now().add(
          e.retryAfter ?? const Duration(seconds: 5),
        );
      }
      rethrow;
    }
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
      ),
    );
    _armCapBackstop(grant);
    await _subscription?.cancel();
    _subscription = _transport.events.listen(_onTransportEvent);
    await _transport.connect(grant);
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
    switch (e) {
      case RealtimeConnected():
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
      case RealtimeAgentReady():
        _set(_state.value.copyWith(agentPresent: true));
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
      case RealtimeUserSpeechStarted():
        _dispatch(const VoiceUserSpeechStarted());
      case RealtimeUserSpeechEnded():
        _dispatch(const VoiceUserSpeechEnded());
      case RealtimeTranscript(:final text, :final isFinal):
        _transcript(VoiceSpeaker.user, text, isFinal);
        if (isFinal) _dispatch(const VoiceTranscriptFinal());
      case RealtimeAssistantTranscript(:final text, :final isFinal):
        _transcript(VoiceSpeaker.assistant, text, isFinal);
      case RealtimeAssistantThinking():
        _dispatch(const VoiceAssistantThinking());
      case RealtimeAssistantSpeakingStarted():
        _dispatch(const VoiceAssistantAudioStarted());
      case RealtimeAssistantSpeakingEnded():
        _dispatch(const VoiceAssistantTurnEnded());
      case RealtimeInterrupted():
        _dispatch(const VoiceInterruptAcknowledged());
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
    try {
      final id = _voiceSessionId;
      final grant = _grant;
      if (id == null || grant == null) return;
      final status = await _statusWithin(
        Duration(seconds: grant.reconnectGraceSeconds),
      );
      if (status == null) {
        _fail(
          const NetworkException(
            NexaErrorCode.networkUnreachable,
            'Could not reach the gateway to resume the call.',
          ),
        );
        return;
      }
      if (status.isEnded) {
        _applyServerEnd(status);
        return;
      }
      final VoiceGrant fresh;
      try {
        fresh = await _provisioner.refreshToken(grant);
      } on VoiceSessionOverException {
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
    } on NexaException catch (e) {
      _fail(e);
    } finally {
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
    _set(_state.value.copyWith(error: error, endReason: 'failed'));
    _emit(NexaVoiceErrorOccurred(clock.now(), error));
    if (error is QuotaExceededException) {
      _dispatch(const VoiceQuotaExceeded());
    } else {
      _dispatch(VoiceFailed(error));
    }
  }

  void _finish(String reason) {
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
      final id = _voiceSessionId;
      _voiceSessionId = null;
      _grant = null;
      try {
        if (_transport.isMicrophoneEnabled) {
          await _transport.setMicrophoneEnabled(enabled: false);
        }
      } on Object catch (e) {
        _logger.log(NexaLogLevel.debug, 'voice mic off: $e');
      }
      if (id != null) await _provisioner.end(id);
      try {
        await _transport.disconnect();
      } on Object catch (e) {
        _logger.log(NexaLogLevel.debug, 'voice disconnect: $e');
      }
      _set(_state.value.copyWith(agentPresent: false, agentAudioActive: false));
    } finally {
      _tearingDown = false;
    }
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
