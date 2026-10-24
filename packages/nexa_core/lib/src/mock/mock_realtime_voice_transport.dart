import 'dart:async';

import 'package:nexa_core/src/transport/realtime_voice_transport.dart';
import 'package:nexa_core/src/voice/voice_grant.dart';

/// **MOCK ADAPTER - NOT REALTIME NETWORKING, NOT A MODEL.**
///
/// In-memory [RealtimeVoiceTransport] that lets tests and demos drive the
/// voice controller without LiveKit. Server/agent behaviour is scripted by
/// the test through [emit] or [scriptedTurn].
final class MockRealtimeVoiceTransport implements RealtimeVoiceTransport {
  MockRealtimeVoiceTransport({
    this.connectDelay = Duration.zero,
    this.failConnectWith,
  });

  /// Simulated connection latency.
  final Duration connectDelay;

  /// When set, [connect] throws this instead of connecting.
  final Object? failConnectWith;

  final StreamController<RealtimeVoiceEvent> _controller =
      StreamController<RealtimeVoiceEvent>.broadcast();

  /// Grants received, for assertions.
  final List<VoiceGrant> grants = [];

  /// Interrupts requested, for assertions.
  int interrupts = 0;

  /// Microphone enable/disable calls, for assertions.
  final List<bool> microphoneCalls = [];

  bool _connected = false;
  bool _disposed = false;
  bool _micEnabled = false;

  /// Whether [connect] completed and [disconnect] has not been called.
  bool get isConnected => _connected;

  @override
  bool get isMicrophoneEnabled => _micEnabled;

  @override
  Stream<RealtimeVoiceEvent> get events => _controller.stream;

  @override
  Future<void> connect(VoiceGrant grant) async {
    _check();
    final failure = failConnectWith;
    if (failure != null) throw failure;
    grants.add(grant);
    if (connectDelay != Duration.zero) await Future<void>.delayed(connectDelay);
    _connected = true;
    emit(const RealtimeConnected());
  }

  @override
  Future<void> setMicrophoneEnabled({required bool enabled}) async {
    _check();
    microphoneCalls.add(enabled);
    _micEnabled = enabled;
  }

  /// Local only, like the real transport (contract v1 has no interrupt
  /// command). Tests emit [RealtimeInterrupted] themselves when the
  /// scripted agent acknowledges a barge-in.
  @override
  Future<void> interrupt() async {
    _check();
    interrupts++;
  }

  @override
  Future<void> disconnect() async {
    if (!_connected) return;
    _connected = false;
    _micEnabled = false;
    emit(const RealtimeDisconnected(willReconnect: false, reason: 'client'));
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    _connected = false;
    await _controller.close();
  }

  /// Pushes a server/agent event to the controller.
  void emit(RealtimeVoiceEvent event) {
    if (!_controller.isClosed) _controller.add(event);
  }

  /// Engine-level transient drop (ICE restart): [RealtimeReconnecting]
  /// then, when [reconnect], [RealtimeConnected] after [after]. A final loss
  /// is [simulateRoomDeleted].
  Future<void> simulateDrop({
    bool reconnect = true,
    Duration after = Duration.zero,
  }) async {
    emit(const RealtimeReconnecting());
    if (reconnect) {
      if (after != Duration.zero) await Future<void>.delayed(after);
      emit(const RealtimeConnected());
    }
  }

  /// A server-side end (DELETE elsewhere, agent lost, revoke): the room is
  /// deleted and the client is disconnected **without** any event.
  void simulateRoomDeleted() {
    _connected = false;
    _micEnabled = false;
    emit(
      const RealtimeDisconnected(willReconnect: false, reason: 'roomDeleted'),
    );
  }

  /// Scripts one complete assistant turn: user speaks, transcript, thinking,
  /// assistant speaks, turn ends.
  Future<void> scriptedTurn({
    String userText = 'hello',
    String assistantText = 'Hi, how can I help?',
    Duration step = Duration.zero,
  }) async {
    Future<void> pause() =>
        step == Duration.zero ? Future.value() : Future<void>.delayed(step);
    emit(const RealtimeUserSpeechStarted());
    await pause();
    emit(RealtimeTranscript(text: userText, isFinal: false));
    emit(const RealtimeUserSpeechEnded());
    await pause();
    emit(RealtimeTranscript(text: userText, isFinal: true));
    emit(const RealtimeAssistantThinking());
    await pause();
    emit(const RealtimeAssistantSpeakingStarted());
    emit(RealtimeAssistantTranscript(text: assistantText, isFinal: true));
    await pause();
    emit(const RealtimeAssistantSpeakingEnded());
  }

  void _check() {
    if (_disposed) throw StateError('MockRealtimeVoiceTransport disposed');
  }
}
