import 'dart:async';
import 'dart:convert';

import 'package:livekit_client/livekit_client.dart' as lk;
import 'package:nexa_core/nexa_core.dart';
import 'package:nexa_realtime/src/livekit_audio_setup.dart';

/// [RealtimeVoiceTransport] over the official LiveKit Flutter SDK.
///
/// Responsibilities:
/// * join the room described by a [VoiceGrant] (room-scoped participant JWT,
///   never an API secret);
/// * publish the microphone track and expose mute/unmute;
/// * play remote audio (handled by the engine for subscribed audio tracks);
/// * translate engine events (connection, reconnect, quality, speaking,
///   transcriptions) into [RealtimeVoiceEvent]s;
/// * decode agent data packets on topic [SignedVoiceEvent.topic], run them
///   through [VoiceEventVerifier] and surface only accepted events;
/// * send the `interrupt` intent to the agent as a data packet.
///
/// Reconnection: LiveKit's engine reconnects on its own (ICE restart, then
/// full reconnect). The transport reports [RealtimeReconnecting] and, on
/// success, [RealtimeConnected]; on final failure [RealtimeDisconnected]
/// with `willReconnect: false`. The voice controller decides what to show.
final class LiveKitVoiceTransport implements RealtimeVoiceTransport {
  LiveKitVoiceTransport({
    required NexaLogger logger,
    lk.Room Function()? roomFactory,
    VoiceEventVerifier Function(VoiceGrant grant)? verifierFactory,
  }) : _logger = logger,
       _roomFactory =
           roomFactory ??
           (() => lk.Room(roomOptions: LiveKitAudioSetup.roomOptions())),
       _verifierFactory =
           verifierFactory ??
           ((g) => VoiceEventVerifier(
             voiceSessionId: g.voiceSessionId,
             key: g.eventVerificationKey,
           ));

  final NexaLogger _logger;
  final lk.Room Function() _roomFactory;
  final VoiceEventVerifier Function(VoiceGrant) _verifierFactory;

  final StreamController<RealtimeVoiceEvent> _events =
      StreamController<RealtimeVoiceEvent>.broadcast();

  lk.Room? _room;
  lk.EventsListener<lk.RoomEvent>? _listener;
  VoiceGrant? _grant;
  VoiceEventVerifier? _verifier;
  bool _disposed = false;
  bool _userSpeaking = false;
  bool _agentSpeaking = false;
  bool _weakNetwork = false;

  /// Identity of the assistant participant once known (grant or first
  /// non-local participant).
  String? _agentIdentity;

  @override
  Stream<RealtimeVoiceEvent> get events => _events.stream;

  @override
  bool get isMicrophoneEnabled =>
      _room?.localParticipant?.isMicrophoneEnabled() ?? false;

  /// Underlying room, for diagnostics and tests. Null when not connected.
  lk.Room? get room => _room;

  @override
  Future<void> connect(VoiceGrant grant) async {
    _check();
    if (grant.isExpired) {
      throw const SessionExpiredException('Voice grant already expired.');
    }
    await disconnect();
    _grant = grant;
    _agentIdentity = grant.agentIdentity;
    _verifier = _verifierFactory(grant);
    final room = _roomFactory();
    _room = room;
    _listener = room.createListener().._bind(this);
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
    _emit(const RealtimeConnected());
    for (final p in room.remoteParticipants.values) {
      _onParticipantJoined(p);
    }
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
    await _publishIntent('interrupt');
  }

  @override
  Future<void> disconnect() async {
    final room = _room;
    if (room == null) return;
    await _teardownRoom();
    _emit(const RealtimeDisconnected(willReconnect: false, reason: 'client'));
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _teardownRoom();
    await _events.close();
  }

  // ------------------------------------------------------------ internals

  Future<void> _teardownRoom() async {
    final room = _room;
    _room = null;
    await _listener?.dispose();
    _listener = null;
    _userSpeaking = false;
    _agentSpeaking = false;
    _weakNetwork = false;
    if (room != null) {
      try {
        await room.disconnect();
      } on Object catch (e) {
        _logger.log(NexaLogLevel.debug, 'room.disconnect: $e');
      }
      await room.dispose();
    }
  }

  Future<void> _publishIntent(String type) async {
    final local = _room?.localParticipant;
    final grant = _grant;
    if (local == null || grant == null) return;
    final payload = jsonEncode({
      'v': SignedVoiceEvent.currentVersion,
      'type': type,
      'voice_session_id': grant.voiceSessionId,
      'issued_at': DateTime.now().millisecondsSinceEpoch,
    });
    try {
      await local.publishData(
        utf8.encode(payload),
        reliable: true,
        topic: SignedVoiceEvent.topic,
        destinationIdentities: _agentIdentity == null
            ? null
            : [_agentIdentity!],
      );
    } on Object catch (e) {
      _logger.log(NexaLogLevel.warning, 'intent "$type" not sent: $e');
    }
  }

  void _emit(RealtimeVoiceEvent event) {
    if (!_events.isClosed) _events.add(event);
  }

  void _onRoomEvent(lk.RoomEvent event) {
    switch (event) {
      case lk.RoomReconnectingEvent():
        _emit(const RealtimeReconnecting());
      case lk.RoomReconnectedEvent():
        _emit(const RealtimeConnected());
      case lk.RoomDisconnectedEvent(:final reason):
        if (_room == null) return; // our own teardown already reported
        final r = reason?.name ?? 'unknown';
        _emit(RealtimeDisconnected(willReconnect: false, reason: r));
      case lk.ParticipantConnectedEvent(:final participant):
        _onParticipantJoined(participant);
      case lk.ParticipantDisconnectedEvent(:final participant):
        if (participant.identity == _agentIdentity) {
          _emit(RealtimeAgentLeft(participant.identity));
        }
      case lk.ActiveSpeakersChangedEvent(:final speakers):
        _onSpeakers(speakers);
      case lk.TrackSubscribedEvent(:final participant, :final track):
        if (track is lk.AudioTrack && participant.identity == _agentIdentity) {
          _emit(const RealtimeAgentAudioTrack(subscribed: true));
        }
      case lk.TrackUnsubscribedEvent(:final participant, :final track):
        if (track is lk.AudioTrack && participant.identity == _agentIdentity) {
          _emit(const RealtimeAgentAudioTrack(subscribed: false));
        }
      case lk.ParticipantConnectionQualityUpdatedEvent(
        :final participant,
        :final connectionQuality,
      ):
        if (participant is lk.LocalParticipant) {
          final weak =
              connectionQuality == lk.ConnectionQuality.poor ||
              connectionQuality == lk.ConnectionQuality.lost;
          if (weak != _weakNetwork) {
            _weakNetwork = weak;
            _emit(RealtimeNetworkQuality(weak: weak));
          }
        }
      case lk.TranscriptionEvent(:final participant, :final segments):
        for (final s in segments) {
          if (participant is lk.LocalParticipant) {
            _emit(RealtimeTranscript(text: s.text, isFinal: s.isFinal));
          } else {
            _emit(
              RealtimeAssistantTranscript(text: s.text, isFinal: s.isFinal),
            );
          }
        }
      case lk.DataReceivedEvent(:final data, :final topic, :final participant):
        if (topic != SignedVoiceEvent.topic) return;
        // Packets from the server API have no participant; packets from
        // other participants are only trusted after signature verification.
        _onAgentPacket(data, from: participant?.identity);
      default:
        break;
    }
  }

  void _onParticipantJoined(lk.RemoteParticipant participant) {
    _agentIdentity ??= participant.identity;
    if (participant.identity == _agentIdentity) {
      _emit(RealtimeAgentJoined(participant.identity));
    }
  }

  void _onSpeakers(List<lk.Participant> speakers) {
    final userNow = speakers.any((p) => p is lk.LocalParticipant);
    final agentNow = speakers.any(
      (p) => p is lk.RemoteParticipant && p.identity == _agentIdentity,
    );
    if (userNow != _userSpeaking) {
      _userSpeaking = userNow;
      _emit(
        userNow
            ? const RealtimeUserSpeechStarted()
            : const RealtimeUserSpeechEnded(),
      );
    }
    if (agentNow != _agentSpeaking) {
      _agentSpeaking = agentNow;
      _emit(
        agentNow
            ? const RealtimeAssistantSpeakingStarted()
            : const RealtimeAssistantSpeakingEnded(),
      );
    }
  }

  void _onAgentPacket(List<int> data, {String? from}) {
    final verifier = _verifier;
    if (verifier == null) return;
    Object? json;
    try {
      json = jsonDecode(utf8.decode(data));
    } on Object {
      _emit(const RealtimeEventRejected('malformed json'));
      return;
    }
    switch (verifier.verify(json)) {
      case VoiceEventRejected(:final reason, :final detail):
        _emit(RealtimeEventRejected('${reason.name} ${detail ?? ''}'.trim()));
      case VoiceEventAccepted(:final event, :final verified):
        if (!verified && from != null && from != _agentIdentity) {
          // Unsigned packet from a non-agent participant: never trusted.
          _emit(const RealtimeEventRejected('unsigned from non-agent'));
          return;
        }
        final mapped = realtimeEventFromSigned(event);
        if (mapped == null) {
          _logger.log(
            NexaLogLevel.debug,
            'Unknown agent event "${event.type}" ignored',
          );
          return;
        }
        // Agent-reported speaking state supersedes audio-level detection so
        // the two never disagree: remember it before emitting.
        if (mapped is RealtimeAssistantSpeakingStarted) _agentSpeaking = true;
        if (mapped is RealtimeAssistantSpeakingEnded) _agentSpeaking = false;
        if (mapped is RealtimeUserSpeechStarted) _userSpeaking = true;
        if (mapped is RealtimeUserSpeechEnded) _userSpeaking = false;
        _emit(mapped);
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

extension on lk.EventsListener<lk.RoomEvent> {
  void _bind(LiveKitVoiceTransport t) {
    on<lk.RoomEvent>(t._onRoomEvent);
  }
}
