import 'dart:async';
import 'dart:convert';

import 'package:livekit_client/livekit_client.dart' as lk;
import 'package:nexa_core/nexa_core.dart';
import 'package:nexa_realtime/src/livekit_audio_setup.dart';

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
    lk.Room Function()? roomFactory,
    this.handshakeWindow = const Duration(seconds: 25),
    this.handshakeInterval = const Duration(milliseconds: 300),
  }) : _logger = logger,
       _roomFactory =
           roomFactory ??
           (() => lk.Room(roomOptions: LiveKitAudioSetup.roomOptions()));

  final NexaLogger _logger;
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
      );
    }
    _grant = grant;
    final room = _roomFactory();
    _room = room;
    _listener = room.createListener()..on<lk.RoomEvent>(_onRoomEvent);
    try {
      await room.connect(
        grant.liveKitUrl.toString(),
        grant.participantToken,
        connectOptions: const lk.ConnectOptions(autoSubscribe: true),
      );
    } on Object catch (e) {
      await _teardownRoom();
      throw _mapConnectError(e);
    }
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
    } on Object catch (e) {
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
      _logger.log(NexaLogLevel.debug, 'resume RPC failed: $e');
      return false;
    }
  }

  Future<void> _teardownRoom() async {
    final room = _room;
    _room = null;
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
