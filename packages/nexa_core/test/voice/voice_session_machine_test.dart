import 'package:nexa_core/nexa_core.dart';
import 'package:test/test.dart';

void main() {
  const m = VoiceSessionMachine();

  VoiceState run(
    VoiceState from,
    List<VoiceEvent> events, [
    List<VoiceCommand>? out,
  ]) {
    var s = from;
    for (final e in events) {
      final t = m.transition(s, e);
      out?.addAll(t.commands);
      s = t.state;
    }
    return s;
  }

  group('VoiceSessionMachine', () {
    test(
      'happy path: start -> permission -> connect -> listen -> speak -> reply',
      () {
        final cmds = <VoiceCommand>[];
        final s = run(VoiceState.idle, const [
          VoiceStartRequested(),
          VoicePermissionResult(granted: true),
          VoiceConnected(),
          VoiceUserSpeechStarted(),
          VoiceUserSpeechEnded(),
          VoiceTranscriptFinal(),
          VoiceAssistantAudioStarted(),
          VoiceAssistantTurnEnded(),
        ], cmds);
        expect(s, VoiceState.listening);
        expect(cmds.whereType<RequestMicrophonePermission>().length, 1);
        expect(cmds.whereType<ConnectTransport>().length, 1);
        expect(cmds.whereType<StartCapture>().length, 1);
        expect(cmds.whereType<StartPlayback>().length, 1);
        expect(cmds.whereType<StopPlayback>().length, 1);
      },
    );

    test('microphone denied is terminal until reset', () {
      final s = run(VoiceState.idle, const [
        VoiceStartRequested(),
        VoicePermissionResult(granted: false),
        VoiceConnected(),
      ]);
      expect(s, VoiceState.microphoneDenied);
      expect(m.transition(s, const VoiceReset()).state, VoiceState.idle);
    });

    test('barge-in stops playback immediately and sends interrupt', () {
      final t = m.transition(
        VoiceState.aiSpeaking,
        const VoiceUserSpeechStarted(),
      );
      expect(t.state, VoiceState.bargeIn);
      expect(t.commands, const [StopPlayback(), SendInterrupt()]);
      final ack = m.transition(t.state, const VoiceInterruptAcknowledged());
      expect(ack.state, VoiceState.userSpeaking);
    });

    test('mute remembers listening and resumes', () {
      final muted = m.transition(
        VoiceState.listening,
        const VoiceMuteToggled(muted: true),
      );
      expect(muted.state, VoiceState.muted);
      expect(muted.commands, const [SetTransportMuted(muted: true)]);
      final back = m.transition(
        muted.state,
        const VoiceMuteToggled(muted: false),
      );
      expect(back.state, VoiceState.listening);
    });

    test('weak network and recovery', () {
      final weak = m.transition(
        VoiceState.listening,
        const VoiceNetworkQualityChanged(weak: true),
      );
      expect(weak.state, VoiceState.weakNetwork);
      expect(weak.state.isCapturing, isTrue);
      final ok = m.transition(
        weak.state,
        const VoiceNetworkQualityChanged(weak: false),
      );
      expect(ok.state, VoiceState.listening);
    });

    test('disconnect with reconnect goes through reconnecting', () {
      final d = m.transition(
        VoiceState.aiSpeaking,
        const VoiceDisconnected(willReconnect: true),
      );
      expect(d.state, VoiceState.reconnecting);
      expect(d.commands, const [StopCapture(), StopPlayback()]);
      final r = m.transition(d.state, const VoiceConnected());
      expect(r.state, VoiceState.listening);
      expect(r.commands, const [StartCapture()]);
    });

    test('model busy then available', () {
      final b = m.transition(VoiceState.thinking, const VoiceModelBusy());
      expect(b.state, VoiceState.modelBusy);
      expect(
        m.transition(b.state, const VoiceModelAvailable()).state,
        VoiceState.listening,
      );
    });

    test('quota exceeded tears down from any active state', () {
      for (final s in VoiceState.values.where(
        (s) => s != VoiceState.idle && !s.isTerminal,
      )) {
        final t = m.transition(s, const VoiceQuotaExceeded());
        expect(t.state, VoiceState.quotaExceeded, reason: 'from $s');
        expect(t.commands, contains(const DisconnectTransport()));
      }
    });

    test('end request from active states disconnects; from idle is no-op', () {
      final t = m.transition(VoiceState.listening, const VoiceEndRequested());
      expect(t.state, VoiceState.ended);
      expect(t.commands, const [
        StopCapture(),
        StopPlayback(),
        DisconnectTransport(),
      ]);
      final idle = m.transition(VoiceState.idle, const VoiceEndRequested());
      expect(idle.state, VoiceState.idle);
      expect(idle.commands, isEmpty);
    });

    test('every (state, event) pair yields a state (total function)', () {
      const events = [
        VoiceStartRequested(),
        VoicePermissionResult(granted: true),
        VoiceConnected(),
        VoiceUserSpeechStarted(),
        VoiceUserSpeechEnded(),
        VoiceTranscriptFinal(),
        VoiceAssistantThinking(),
        VoiceAssistantAudioStarted(),
        VoiceAssistantTurnEnded(),
        VoiceInterruptAcknowledged(),
        VoiceMuteToggled(muted: true),
        VoiceNetworkQualityChanged(weak: true),
        VoiceDisconnected(willReconnect: false),
        VoiceReconnecting(),
        VoiceModelBusy(),
        VoiceModelAvailable(),
        VoiceQuotaExceeded(),
        VoiceEndRequested(),
        VoiceFailed('x'),
        VoiceReset(),
      ];
      for (final s in VoiceState.values) {
        for (final e in events) {
          expect(() => m.transition(s, e), returnsNormally, reason: '$s + $e');
        }
      }
    });
  });
}
