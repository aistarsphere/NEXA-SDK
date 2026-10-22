import 'dart:async';
import 'dart:typed_data';

import 'package:nexa_core/src/auth/session_credential.dart';
import 'package:nexa_core/src/ids/ids.dart';
import 'package:nexa_core/src/transport/realtime_voice_transport.dart';

/// **MOCK ADAPTER - NOT REALTIME NETWORKING.**
///
/// In-memory [RealtimeVoiceTransport] that lets tests and demos drive the
/// voice state machine. It records uplink frames and lets the test script
/// server events with [emit] or [scriptedTurn].
final class MockRealtimeVoiceTransport implements RealtimeVoiceTransport {
  MockRealtimeVoiceTransport({this.connectDelay = Duration.zero});

  /// Simulated connection latency.
  final Duration connectDelay;

  final StreamController<RealtimeVoiceEvent> _controller =
      StreamController<RealtimeVoiceEvent>.broadcast();

  /// Frames sent uplink, for assertions.
  final List<AudioFrame> sentFrames = [];

  /// Interrupts requested, for assertions.
  int interrupts = 0;

  /// Last mute state requested.
  bool? muted;

  bool _connected = false;
  bool _disposed = false;

  /// Whether [connect] completed and [disconnect] has not been called.
  bool get isConnected => _connected;

  @override
  Stream<RealtimeVoiceEvent> get events => _controller.stream;

  @override
  Future<void> connect({
    required SessionId sessionId,
    required SessionCredential credential,
    required int sampleRateHz,
  }) async {
    _check();
    if (connectDelay != Duration.zero) await Future<void>.delayed(connectDelay);
    _connected = true;
    emit(const RealtimeConnected());
  }

  @override
  void sendAudio(AudioFrame frame) {
    _check();
    if (_connected && muted != true) sentFrames.add(frame);
  }

  @override
  Future<void> interrupt() async {
    _check();
    interrupts++;
    emit(const RealtimeInterrupted());
  }

  @override
  Future<void> setMuted({required bool muted}) async {
    _check();
    this.muted = muted;
  }

  @override
  Future<void> disconnect() async {
    if (!_connected) return;
    _connected = false;
    emit(const RealtimeDisconnected(willReconnect: false, reason: 'client'));
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    await _controller.close();
  }

  /// Pushes a server event.
  void emit(RealtimeVoiceEvent event) {
    if (!_controller.isClosed) _controller.add(event);
  }

  /// Emits a complete scripted turn: user speaks, transcript, thinking,
  /// assistant audio, turn end.
  Future<void> scriptedTurn({
    Duration step = Duration.zero,
    String transcript = 'hello',
  }) async {
    Future<void> wait() => step == Duration.zero
        ? Future<void>.value()
        : Future<void>.delayed(step);
    emit(const RealtimeUserSpeechStarted());
    await wait();
    emit(RealtimeTranscript(text: transcript, isFinal: false));
    await wait();
    emit(const RealtimeUserSpeechEnded());
    emit(RealtimeTranscript(text: transcript, isFinal: true));
    await wait();
    emit(const RealtimeAssistantThinking());
    await wait();
    emit(
      RealtimeAssistantAudio(
        AudioFrame(pcm16: Uint8List(0), sampleRateHz: 16000, sequence: 0),
      ),
    );
    await wait();
    emit(const RealtimeAssistantTurnEnded());
  }

  void _check() {
    if (_disposed) throw StateError('MockRealtimeVoiceTransport disposed');
  }
}
