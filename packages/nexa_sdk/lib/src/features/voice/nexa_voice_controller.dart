import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:nexa_core/nexa_core.dart';
import 'package:nexa_sdk/src/features/voice/nexa_voice_state.dart';
import 'package:nexa_sdk/src/permissions/nexa_permission_handler.dart';
import 'package:nexa_sdk/src/session/session_manager.dart';

/// Orchestrates one live voice session.
///
/// `VoiceSessionMachine` (pure, in `nexa_core`) decides state and commands;
/// this controller executes the commands against the host permission
/// handler, the `VoiceProvisioner` (gateway) and the `RealtimeVoiceTransport`
/// (LiveKit), and feeds the outcomes back as `VoiceEvent`s. Transport and
/// agent events are mapped 1:1; nothing here is timer-driven except the
/// grant-expiry guard.
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
  }) : _sessions = sessions,
       _provisioner = provisioner,
       _transport = transport,
       _permissions = permissions,
       _logger = logger,
       _options = options;

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
  SessionId? _chatSessionId;
  VoiceGrant? _grant;
  Timer? _expiryTimer;
  bool _disposed = false;
  bool _ending = false;

  /// Current snapshot; listen for UI binding.
  ValueListenable<NexaVoiceState> get state => _state;

  /// Typed event stream for hosts (analytics, custom UI).
  Stream<NexaVoiceEvent> get events => _events.stream;

  /// Active grant (redacted `toString`), for diagnostics only.
  VoiceGrant? get currentGrant => _grant;

  /// Whether the microphone track is currently published and enabled.
  bool get microphoneEnabled => _transport.isMicrophoneEnabled;

  // ------------------------------------------------------------ public API

  /// Starts a call: permission → provisioning → room join. Returns once the
  /// request is accepted; progress is observable on [state]. Safe to call
  /// again after `ended` / `disconnected`.
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
        endReason: null,
      ),
    );
    _dispatch(const VoiceStartRequested());
  }

  /// Ends the call. Safe when no call is active.
  Future<void> end() async {
    if (_disposed) return;
    _ending = true;
    _dispatch(const VoiceEndRequested());
    _ending = false;
  }

  /// Mutes/unmutes the microphone. No-op outside a call.
  Future<void> setMuted({required bool muted}) async {
    _check();
    if (!_state.value.isActive || muted == _state.value.muted) return;
    _set(_state.value.copyWith(muted: muted));
    _emit(NexaVoiceMuteChanged(clock.now(), muted: muted));
    _dispatch(VoiceMuteToggled(muted: muted));
  }

  /// Convenience for the capsule's single button.
  Future<void> toggleMute() => setMuted(muted: !_state.value.muted);

  /// Explicit barge-in (the agent also detects speech while it talks).
  Future<void> interrupt() async {
    _check();
    if (_state.value.phase == VoiceState.aiSpeaking) {
      _dispatch(const VoiceUserSpeechStarted());
    }
  }

  Future<void> dispose() async {
    if (_disposed) return;
    if (_state.value.isActive) {
      await _teardown(reason: 'dispose', notifyGateway: true);
    }
    _disposed = true;
    _expiryTimer?.cancel();
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
          break; // the engine plays subscribed audio; nothing to do locally
        case SendInterrupt():
          await _transport.interrupt();
          final id = _chatSessionId;
          if (id != null) await _provisioner.sendIntent(id, 'interrupt');
        case DisconnectTransport():
          await _teardown(reason: null, notifyGateway: true);
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
    final handle = await _sessions.start();
    _chatSessionId = handle.sessionId;
    if (!handle.has(NexaCapability.liveVoice)) {
      throw const CapabilityNotGrantedException('liveVoice');
    }
    final grant = await _provisioner.provision(handle.sessionId);
    if (grant.eventVerificationKey == null && !_options.allowUnverifiedEvents) {
      await _provisioner.end(handle.sessionId);
      throw const ContractViolationException(
        'Gateway issued no event verification key.',
        path: 'event_verification_key',
      );
    }
    _grant = grant;
    _set(
      _state.value.copyWith(
        agentIdentity: grant.agentIdentity,
        eventsVerified: grant.eventVerificationKey != null,
      ),
    );
    _armExpiry(grant);
    await _subscription?.cancel();
    _subscription = _transport.events.listen(_onTransportEvent);
    await _transport.connect(grant);
  }

  void _armExpiry(VoiceGrant grant) {
    _expiryTimer?.cancel();
    final until = grant.expiresAt.difference(clock.now());
    final cap = grant.maxDuration;
    final limit = cap != null && cap < until ? cap : until;
    if (limit <= Duration.zero) return;
    _expiryTimer = Timer(limit, () {
      if (!_state.value.isActive) return;
      _set(
        _state.value.copyWith(
          error: const SessionExpiredException('Voice session expired.'),
          endReason: 'expired',
        ),
      );
      _dispatch(const VoiceEndRequested());
    });
  }

  void _onTransportEvent(RealtimeVoiceEvent e) {
    if (_disposed) return;
    switch (e) {
      case RealtimeConnected():
        _dispatch(const VoiceConnected());
      case RealtimeReconnecting():
        _dispatch(const VoiceDisconnected(willReconnect: true));
      case RealtimeDisconnected(:final willReconnect, :final reason):
        if (_state.value.phase == VoiceState.ended ||
            _state.value.phase == VoiceState.idle) {
          return; // our own teardown
        }
        if (!willReconnect) {
          _set(
            _state.value.copyWith(endReason: 'server:${reason ?? 'unknown'}'),
          );
        }
        _dispatch(VoiceDisconnected(willReconnect: willReconnect));
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
      case RealtimeAgentAudioTrack(:final subscribed):
        _set(_state.value.copyWith(agentAudioActive: subscribed));
      case RealtimeAgentLeft(:final identity):
        _set(_state.value.copyWith(agentPresent: false));
        _emit(
          NexaVoiceAgentPresence(
            clock.now(),
            identity: identity,
            present: false,
          ),
        );
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
        _set(_state.value.copyWith(endReason: 'server:$reason'));
        _dispatch(const VoiceEndRequested());
      case RealtimeNetworkQuality(:final weak):
        _dispatch(VoiceNetworkQualityChanged(weak: weak));
      case RealtimeEventRejected(:final reason):
        _set(
          _state.value.copyWith(
            rejectedEvents: _state.value.rejectedEvents + 1,
          ),
        );
        _emit(NexaVoiceEventRejected(clock.now(), reason));
        _logger.log(NexaLogLevel.warning, 'voice event rejected: $reason');
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

  void _transcript(VoiceSpeaker speaker, String text, bool isFinal) {
    if (!_options.keepTranscript || text.isEmpty) return;
    final entries = [..._state.value.transcript];
    final last = entries.isEmpty ? null : entries.last;
    final entry = last != null && last.speaker == speaker && !last.isFinal
        ? last.copyWith(text: text, isFinal: isFinal)
        : VoiceTranscriptEntry(
            speaker: speaker,
            text: text,
            isFinal: isFinal,
            at: clock.now(),
          );
    if (last != null && last.speaker == speaker && !last.isFinal) {
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

  Future<void> _teardown({
    required String? reason,
    required bool notifyGateway,
  }) async {
    _expiryTimer?.cancel();
    final id = _chatSessionId;
    _grant = null;
    try {
      await _transport.disconnect();
    } on Object catch (e) {
      _logger.log(NexaLogLevel.debug, 'voice disconnect: $e');
    }
    if (notifyGateway && id != null) {
      await _provisioner.end(id);
    }
    _set(_state.value.copyWith(agentPresent: false, agentAudioActive: false));
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
