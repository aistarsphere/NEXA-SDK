import 'dart:async';
import 'dart:convert';

import 'package:livekit_client/livekit_client.dart' as lk;
import 'package:nexa_core/nexa_core.dart';
import 'package:nexa_realtime/src/livekit_audio_setup.dart';
import 'package:nexa_realtime/src/livekit_stats_sampler.dart';

/// [RealtimeVoiceTransport] over the official LiveKit Flutter SDK, for
/// contract `nexa.voice.v1` (backend handoff 1.0.0).
///
/// * Joins with `livekit.url` + `livekit.token` and the fixed identity;
///   publishes the **microphone only**.
/// * Agent audio arrives as an ordinary remote audio track (played by the
///   engine).
/// * Agent events are sealed envelopes on `events.topic`; every packet goes
///   through [VoiceEventPipeline] (verify → seq → map). The packet sender is
///   never trusted.
/// * Handshake / gap repair: RPC `events.resume_rpc` to
///   `nexa-agent-<voice_session_id>` with `{"last_seq": n}`, retried every
///   ~0.3 s for up to ~25 s; [RealtimeAgentUnresponsive] when it never
///   succeeds.
/// * The client publishes **no data packets** of its own (contract §4) and
///   has no interrupt command: [interrupt] is local only.
/// * A server-side end deletes the room: the transport reports
///   [RealtimeDisconnected] and the controller asks the gateway (`GET`).
final class LiveKitVoiceTransport implements RealtimeVoiceTransport {
  LiveKitVoiceTransport({
    required NexaLogger logger,
    NexaDiagnostics diagnostics = const NoopNexaDiagnostics(),
    lk.Room Function()? roomFactory,
    this.handshakeWindow = const Duration(seconds: 25),
    this.handshakeInterval = const Duration(milliseconds: 300),
  }) : _logger = logger,
       _diagnostics = diagnostics,
       _roomFactory =
           roomFactory ??
           (() => lk.Room(roomOptions: LiveKitAudioSetup.roomOptions()));

  final NexaLogger _logger;
  final NexaDiagnostics _diagnostics;
  final lk.Room Function() _roomFactory;

  /// How long the `resume` handshake is retried (contract §8: ~25 s).
  final Duration handshakeWindow;

  /// Pause between failed `resume` attempts (contract §8: ~0.3 s).
  final Duration handshakeInterval;

  final StreamController<RealtimeVoiceEvent> _events =
      StreamController<RealtimeVoiceEvent>.broadcast();

  lk.Room? _room;
  lk.EventsListener<lk.RoomEvent>? _listener;
  VoiceGrant? _grant;
  VoiceEventPipeline? _pipeline;
  bool _disposed = false;
  bool _resuming = false;
  int _connection = 0;
  bool _mediaWeak = false;
  LiveKitStatsSampler? _sampler;

  @override
  Stream<RealtimeVoiceEvent> get events => _events.stream;

  @override
  bool get isMicrophoneEnabled =>
      _room?.localParticipant?.isMicrophoneEnabled() ?? false;

  /// Underlying room, for diagnostics and tests. Null when not connected.
  lk.Room? get room => _room;

  /// Highest applied event `seq` of the current voice session.
  int get lastAppliedSeq => _pipeline?.lastApplied ?? 0;

  @override
  Future<void> connect(VoiceGrant grant) async {
    _check();
    if (grant.isTokenExpired) {
      throw const SessionExpiredException('Voice join token expired.');
    }
    await _teardownRoom();
    // A rejoin of the same session keeps the replay guard (resume cursor).
    if (_grant?.voiceSessionId != grant.voiceSessionId || _pipeline == null) {
      _pipeline = VoiceEventPipeline(
        grant: grant,
        emit: _emit,
        requestResume: () => unawaited(_resume()),
        logger: _logger,
        diagnostics: _diagnostics,
      );
    }
    _grant = grant;
    final room = _roomFactory();
    _room = room;
    _listener = room.createListener()..on<lk.RoomEvent>(_onRoomEvent);
    final connectWatch = Stopwatch()..start();
    _diagnostics.record('voice.room_connect_started', {
      'voice_session_id': grant.voiceSessionId,
    });
    try {
      await room.connect(
        grant.liveKitUrl.toString(),
        grant.participantToken,
        connectOptions: const lk.ConnectOptions(autoSubscribe: true),
      );
    } on Object catch (e) {
      _diagnostics.record('voice.room_connect_failed', {
        'ms': connectWatch.elapsedMilliseconds,
        'error': e.runtimeType.toString(),
      });
      await _teardownRoom();
      throw _mapConnectError(e);
    }
    // After the join: LiveKit's iOS audio device module exists only once a
    // room is connected; the microphone is enabled later (StartCapture).
    await _beginAudioSession();
    _diagnostics.record('voice.room_connected', {
      'ms': connectWatch.elapsedMilliseconds,
      'remote_participants': room.remoteParticipants.length,
    });
    _sampler = LiveKitStatsSampler(room, _diagnostics)..start();
    for (final p in room.remoteParticipants.values) {
      _onParticipantJoined(p);
    }
    _pipeline!.beginConnection();
    unawaited(_handshake(++_connection));
  }

  @override
  Future<void> setMicrophoneEnabled({required bool enabled}) async {
    _check();
    final local = _room?.localParticipant;
    if (local == null) {
      throw const TransportException('Not connected.', retryable: false);
    }
    try {
      await local.setMicrophoneEnabled(
        enabled,
        audioCaptureOptions: LiveKitAudioSetup.capture,
      );
      _diagnostics.record('voice.microphone', {'enabled': enabled});
    } on Object catch (e) {
      _diagnostics.record('voice.microphone_failed', {
        'enabled': enabled,
        'error': e.runtimeType.toString(),
      });
      throw TransportException('Microphone toggle failed: $e', cause: e);
    }
  }

  @override
  Future<void> interrupt() async {
    _check();
    // Local only: the agent detects barge-in from the microphone and
    // confirms with `interrupted` (contract has no interrupt command).
  }

  @override
  Future<RealtimeSignalResult> sendSignal(
    String method,
    Map<String, Object?> payload,
  ) async {
    _check();
    final grant = _grant;
    final local = _room?.localParticipant;
    if (grant == null || local == null) return RealtimeSignalResult.failed;
    try {
      await local.performRpc(
        lk.PerformRpcParams(
          destinationIdentity: grant.agentIdentity,
          method: method,
          payload: jsonEncode(payload),
          responseTimeoutMs: const Duration(seconds: 5),
        ),
      );
      return RealtimeSignalResult.sent;
    } on lk.RpcError catch (e) {
      _diagnostics.record('voice.signal_failed', {
        'method': method,
        'code': e.code,
      });
      return e.code == lk.RpcError.unsupportedMethod
          ? RealtimeSignalResult.unsupported
          : RealtimeSignalResult.failed;
    } on Object catch (e) {
      _diagnostics.record('voice.signal_failed', {
        'method': method,
        'error': e.runtimeType.toString(),
      });
      return RealtimeSignalResult.failed;
    }
  }

  @override
  Future<void> disconnect() async {
    if (_room == null) return;
    await _teardownRoom();
    _emit(const RealtimeDisconnected(willReconnect: false, reason: 'client'));
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _teardownRoom();
    _pipeline = null;
    _grant = null;
    await _events.close();
  }

  // ------------------------------------------------------------ internals

  Future<void> _beginAudioSession() async {
    try {
      await LiveKitAudioSetup.beginCall();
      _diagnostics.record('voice.audio_session', {'mute_mode': 'inputMixer'});
    } on Object catch (e) {
      // Not fatal: the call works; only re-calls on iOS may be affected.
      _logger.log(NexaLogLevel.warning, 'audio setup failed: $e');
      _diagnostics.record('voice.audio_session', {
        'state': 'setup_failed',
        'error': e.runtimeType.toString(),
      });
    }
  }

  /// Contract §8 step 1: call `resume` until it answers, for ~25 s.
  Future<void> _handshake(int connection) async {
    final deadline = DateTime.now().add(handshakeWindow);
    while (connection == _connection && _room != null && !_disposed) {
      final pipeline = _pipeline;
      if (pipeline == null || pipeline.isConnected) return;
      if (await _resumeOnce(connection)) return;
      if (DateTime.now().isAfter(deadline)) {
        if (!(pipeline.isConnected)) {
          _emit(const RealtimeAgentUnresponsive());
        }
        return;
      }
      await Future<void>.delayed(handshakeInterval);
    }
  }

  /// Gap repair after a missing `seq` or an engine-level reconnect.
  Future<void> _resume() async {
    if (_resuming) return;
    _resuming = true;
    try {
      await _resumeOnce(_connection);
    } finally {
      _resuming = false;
    }
  }

  /// One `resume` exchange (following `has_more`). Returns true on success.
  Future<bool> _resumeOnce(int connection) async {
    final grant = _grant;
    final pipeline = _pipeline;
    final local = _room?.localParticipant;
    if (grant == null || pipeline == null || local == null) return false;
    try {
      var more = true;
      while (more && connection == _connection) {
        final response = await local.performRpc(
          lk.PerformRpcParams(
            destinationIdentity: grant.agentIdentity,
            method: grant.resumeRpc,
            payload: jsonEncode({'last_seq': pipeline.lastApplied}),
            responseTimeoutMs: const Duration(seconds: 8),
          ),
        );
        more = pipeline.onResumeResponse(response);
      }
      return true;
    } on Object catch (e) {
      // RpcError's toString hides the code; the code says why (1500 = the
      // agent has no such method, 1501 = it did not answer in time).
      final why = e is lk.RpcError ? 'RpcError ${e.code} ${e.message}' : '$e';
      _logger.log(NexaLogLevel.debug, 'resume RPC failed: $why');
      return false;
    }
  }

  Future<void> _teardownRoom() async {
    final room = _room;
    _room = null;
    _mediaWeak = false;
    final sampler = _sampler;
    _sampler = null;
    await sampler?.stop();
    _connection++;
    await _listener?.dispose();
    _listener = null;
    if (room != null) {
      try {
        await room.disconnect();
      } on Object catch (e) {
        _logger.log(NexaLogLevel.debug, 'room.disconnect: $e');
      }
      await room.dispose();
    }
  }

  void _emit(RealtimeVoiceEvent event) {
    if (!_events.isClosed) _events.add(event);
  }

  void _onRoomEvent(lk.RoomEvent event) {
    final grant = _grant;
    if (_diagnostics.enabled) _recordRoomEvent(event, grant);
    switch (event) {
      case lk.RoomReconnectingEvent():
        _emit(const RealtimeReconnecting());
      case lk.RoomReconnectedEvent():
        // Engine-level recovery of the same connection: re-handshake so a
        // fresh snapshot and any missed events are applied.
        _pipeline?.beginConnection();
        unawaited(_handshake(++_connection));
      case lk.RoomDisconnectedEvent(:final reason):
        if (_room == null) return; // our own teardown
        _emit(
          RealtimeDisconnected(
            willReconnect: false,
            reason: reason?.name ?? 'unknown',
          ),
        );
      case lk.ParticipantConnectionQualityUpdatedEvent(
        :final participant,
        :final connectionQuality,
      ):
        // Server-measured quality of OUR media. It arrives over signaling,
        // so it still reports when media has stopped (e.g. ICE lost) while
        // the WebSocket is up and the agent cannot tell us.
        if (participant is! lk.LocalParticipant) return;
        final weak = isWeakConnectionQuality(connectionQuality);
        if (weak == _mediaWeak) return;
        _mediaWeak = weak;
        _emit(RealtimeNetworkQuality(weak: weak));
      case lk.ParticipantConnectedEvent(:final participant):
        _onParticipantJoined(participant);
      case lk.ParticipantDisconnectedEvent(:final participant):
        if (participant.identity == grant?.agentIdentity) {
          _emit(RealtimeAgentLeft(participant.identity));
        }
      case lk.TrackSubscribedEvent(:final participant, :final track):
        if (track is lk.AudioTrack &&
            participant.identity == grant?.agentIdentity) {
          _emit(const RealtimeAgentAudioTrack(subscribed: true));
        }
      case lk.TrackUnsubscribedEvent(:final participant, :final track):
        if (track is lk.AudioTrack &&
            participant.identity == grant?.agentIdentity) {
          _emit(const RealtimeAgentAudioTrack(subscribed: false));
        }
      case lk.ActiveSpeakersChangedEvent(:final speakers):
        // Always (not only with diagnostics): the controller uses the
        // agent's level to notice a reply that went silent.
        double level(bool Function(lk.Participant) who) =>
            speakers.where(who).firstOrNull?.audioLevel ?? 0;
        _emit(
          RealtimeAudioLevels(
            local: level((p) => p is lk.LocalParticipant),
            agent: level((p) => p.identity == grant?.agentIdentity),
          ),
        );
      case lk.DataReceivedEvent(:final data, :final topic):
        if (grant == null || topic != grant.eventsTopic) return;
        final String text;
        try {
          text = utf8.decode(data);
        } on FormatException {
          _emit(const RealtimeEventRejected('packet is not utf-8'));
          return;
        }
        _pipeline?.onPacket(text);
      default:
        break;
    }
  }

  /// Media-level facts for QA (identities only for the agent; no tokens).
  void _recordRoomEvent(lk.RoomEvent event, VoiceGrant? grant) {
    bool isAgent(lk.Participant p) => p.identity == grant?.agentIdentity;
    switch (event) {
      case lk.RoomReconnectingEvent():
        _diagnostics.record('voice.room_reconnecting');
      case lk.RoomReconnectedEvent():
        _diagnostics.record('voice.room_reconnected');
      case lk.RoomDisconnectedEvent(:final reason):
        _diagnostics.record('voice.room_disconnected', {
          'reason': reason?.name,
          'own_teardown': _room == null,
        });
      case lk.LocalTrackPublishedEvent(:final publication):
        _diagnostics.record('voice.local_track_published', {
          'kind': publication.kind.name,
          'source': publication.source.name,
        });
      case lk.LocalTrackUnpublishedEvent(:final publication):
        _diagnostics.record('voice.local_track_unpublished', {
          'kind': publication.kind.name,
        });
      case lk.ParticipantConnectedEvent(:final participant):
        _diagnostics.record('voice.participant_joined', {
          'agent': isAgent(participant),
        });
      case lk.ParticipantDisconnectedEvent(:final participant):
        _diagnostics.record('voice.participant_left', {
          'agent': isAgent(participant),
        });
      case lk.TrackSubscribedEvent(:final participant, :final track):
        _diagnostics.record('voice.remote_track_subscribed', {
          'agent': isAgent(participant),
          'kind': track.kind.name,
        });
      case lk.TrackUnsubscribedEvent(:final participant, :final track):
        _diagnostics.record('voice.remote_track_unsubscribed', {
          'agent': isAgent(participant),
          'kind': track.kind.name,
        });
      case lk.TrackSubscriptionExceptionEvent(:final reason):
        _diagnostics.record('voice.remote_track_failed', {
          'reason': reason.name,
        });
      case lk.ActiveSpeakersChangedEvent(:final speakers):
        _diagnostics.record('voice.active_speakers', {
          'agent': speakers.any(isAgent),
          'local': speakers.any((p) => p is lk.LocalParticipant),
        });
      case lk.ParticipantConnectionQualityUpdatedEvent(
        :final participant,
        :final connectionQuality,
      ):
        if (participant is lk.LocalParticipant || isAgent(participant)) {
          _diagnostics.record('voice.connection_quality', {
            'local': participant is lk.LocalParticipant,
            'quality': connectionQuality.name,
          });
        }
      case lk.AudioPlaybackStatusChanged(:final isPlaying):
        _diagnostics.record('voice.audio_playback', {'playing': isPlaying});
      default:
        break;
    }
  }

  void _onParticipantJoined(lk.RemoteParticipant participant) {
    if (participant.identity == _grant?.agentIdentity) {
      _emit(RealtimeAgentJoined(participant.identity));
    }
  }

  NexaException _mapConnectError(Object e) {
    final text = e.toString();
    if (e is lk.ConnectException || text.contains('ConnectException')) {
      return NetworkException(
        NexaErrorCode.networkUnreachable,
        'Could not reach the voice server.',
        cause: e,
      );
    }
    if (text.contains('401') || text.toLowerCase().contains('token')) {
      return AuthenticationException('Voice credentials rejected.', cause: e);
    }
    return TransportException('Voice connection failed: $e', cause: e);
  }

  void _check() {
    if (_disposed) {
      throw const NotInitializedException('Voice transport disposed.');
    }
  }
}

/// Whether LiveKit's server-measured [quality] should show "weak network".
bool isWeakConnectionQuality(lk.ConnectionQuality quality) =>
    quality == lk.ConnectionQuality.poor ||
    quality == lk.ConnectionQuality.lost;
