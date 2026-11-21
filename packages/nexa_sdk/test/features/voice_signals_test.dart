// Client→agent signals (listening control, client info): sent only when
// agent_ready advertises them, coalesced, never with content.
import 'package:flutter_test/flutter_test.dart';
import 'package:nexa_core/testing.dart';
import 'package:nexa_sdk/nexa_sdk.dart';
import 'package:nexa_sdk/src/features/voice/nexa_voice_signals.dart';

import '../helpers.dart';

final class _Permissions implements NexaPermissionHandler {
  @override
  Future<bool> request(NexaPermission permission) async => true;
}

void main() {
  late MockRealtimeVoiceTransport transport;
  late NexaClient client;

  setUp(() => transport = MockRealtimeVoiceTransport());
  tearDown(() => client.dispose());

  Future<NexaVoiceController> inCall() async {
    client = await Nexa.initialize(
      config: testConfig(),
      auth: MockAuthProvider(),
      overrides: NexaOverrides(
        chatTransport: fastMock(),
        voiceTransport: transport,
        voiceProvisioner: MockVoiceProvisioner(),
        permissionHandler: _Permissions(),
      ),
    );
    final v = client.voice;
    await v.start();
    await waitFor(
      () => v.state.value.phase == VoiceState.listening,
      reason: 'listening',
    );
    return v;
  }

  Iterable<Map<String, Object?>> sent(String method) =>
      transport.signals.where((s) => s.$1 == method).map((s) => s.$2);

  test(
    'an agent that does not advertise client_signals gets nothing',
    () async {
      final v = await inCall();
      transport.emit(const RealtimeAgentReady(capabilities: {'stt': {}}));
      await v.toggleMute();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(transport.signals, isEmpty);
    },
  );

  test('listening control follows mute and unmute; client info has no '
      'content', () async {
    final v = await inCall();
    transport.emit(
      const RealtimeAgentReady(
        capabilities: {
          'client_signals': {
            'listening_control': 'srv.listening',
            'client_info': true,
          },
        },
      ),
    );
    await waitFor(
      () => sent(NexaVoiceSignals.defaultClientInfoMethod).isNotEmpty,
      reason: 'client info on agent_ready',
    );
    final info = sent(NexaVoiceSignals.defaultClientInfoMethod).first;
    expect(info['source'], 'app');
    expect(info['muted'], isFalse);
    expect(
      info.keys,
      everyElement(isNot(anyOf('text', 'transcript', 'audio'))),
    );

    await v.toggleMute();
    await waitFor(
      () => sent('srv.listening').isNotEmpty,
      reason: 'listening false',
    );
    expect(sent('srv.listening').last, {'listening': false, 'reason': 'mute'});
    expect(v.stats.value.listeningSignal, 'srv.listening');
    await waitFor(
      () => v.stats.value.lastListeningSignal == 'false (mute): sent',
      reason: 'debug panel stats',
    );
    await waitFor(
      () => sent(
        NexaVoiceSignals.defaultClientInfoMethod,
      ).any((p) => p['muted'] == true && p['microphone_on'] == false),
      reason: 'client info after mute',
      timeout: const Duration(seconds: 3),
    );
    await v.toggleMute();
    await waitFor(
      () => sent('srv.listening').length == 2,
      reason: 'listening true',
      timeout: const Duration(seconds: 3),
    );
    expect(sent('srv.listening').last, {'listening': true, 'reason': 'unmute'});
    await waitFor(
      () =>
          sent(NexaVoiceSignals.defaultClientInfoMethod).last['muted'] == false,
      reason: 'newest state wins',
      timeout: const Duration(seconds: 3),
    );
  });

  test('a call that is already muted tells the agent at agent_ready', () async {
    final v = await inCall();
    await v.toggleMute();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    transport.emit(
      const RealtimeAgentReady(
        capabilities: {
          'client_signals': {'listening_control': true},
        },
      ),
    );
    await waitFor(
      () => sent(NexaVoiceSignals.defaultListeningMethod).isNotEmpty,
      reason: 'sent',
    );
    expect(
      sent(NexaVoiceSignals.defaultListeningMethod).first['listening'],
      isFalse,
    );
  });

  test('capabilities learned from session_state (agent_ready missed): a '
      'muted call tells the agent at once', () async {
    final v = await inCall();
    await v.toggleMute();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    const caps = {
      'client_signals': {
        'listening_control': 'nexa.voice.listening',
        'client_info': 'nexa.voice.client_info',
      },
    };
    transport.emit(
      const RealtimeSessionSnapshot(state: 'listening', capabilities: caps),
    );
    await waitFor(
      () => sent('nexa.voice.listening').isNotEmpty,
      reason: 'listening false from the snapshot',
    );
    expect(sent('nexa.voice.listening').single, {
      'listening': false,
      'reason': 'mute',
    });
    await waitFor(
      () => sent('nexa.voice.client_info').isNotEmpty,
      reason: 'client info from the snapshot',
    );
    // The same capabilities again (every snapshot, resume): nothing resent.
    transport.emit(
      const RealtimeSessionSnapshot(state: 'listening', capabilities: caps),
    );
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(sent('nexa.voice.listening'), hasLength(1));
  });

  group('NexaVoiceSignals', () {
    test('update keeps a running signal; a new method replaces it', () async {
      final calls = <String>[];
      final s = NexaVoiceSignals(
        send: (m, p) async {
          calls.add(m);
          return m == 'a'
              ? RealtimeSignalResult.unsupported
              : RealtimeSignalResult.sent;
        },
        minInterval: Duration.zero,
      );
      expect(
        s.update({
          'client_signals': {'listening_control': 'a'},
        }),
        isTrue,
      );
      s.listening(listening: false, reason: 'mute');
      await Future<void>.delayed(const Duration(milliseconds: 20));
      // Same method again: still stopped after `unsupported`.
      expect(
        s.update({
          'client_signals': {'listening_control': 'a'},
        }),
        isFalse,
      );
      s.listening(listening: true, reason: 'unmute');
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(calls, ['a']);
      // A different method name: a fresh signal.
      s
        ..update({
          'client_signals': {'listening_control': 'b'},
        })
        ..listening(listening: false, reason: 'mute');
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(calls, ['a', 'b']);
      // client_signals gone: nothing more is sent.
      s
        ..update(const {})
        ..listening(listening: true, reason: 'unmute');
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(calls, ['a', 'b']);
      expect(s.listeningEnabled, isFalse);
    });

    test('rapid changes collapse to the newest value', () async {
      final calls = <Map<String, Object?>>[];
      final s =
          NexaVoiceSignals(
            send: (m, p) async {
              calls.add(p);
              await Future<void>.delayed(const Duration(milliseconds: 20));
              return RealtimeSignalResult.sent;
            },
            minInterval: const Duration(milliseconds: 30),
          )..configure({
            'client_signals': {'listening_control': true},
          });
      for (var i = 0; i < 10; i++) {
        s.listening(listening: i.isEven, reason: 'r$i');
      }
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(calls.length, lessThanOrEqualTo(2));
      expect(calls.last['reason'], 'r9');
    });

    test('unsupported stops that signal; failed is retried once', () async {
      final calls = <String>[];
      var result = RealtimeSignalResult.unsupported;
      final s =
          NexaVoiceSignals(
            send: (m, p) async {
              calls.add(m);
              return result;
            },
            minInterval: Duration.zero,
          )..configure({
            'client_signals': {'listening_control': true, 'client_info': true},
          });
      s.listening(listening: false, reason: 'mute');
      await Future<void>.delayed(const Duration(milliseconds: 20));
      s.listening(listening: true, reason: 'unmute');
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(calls, [NexaVoiceSignals.defaultListeningMethod]);

      result = RealtimeSignalResult.failed;
      s.clientInfo({'source': 'app'});
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(
        calls.where((c) => c == NexaVoiceSignals.defaultClientInfoMethod),
        hasLength(2),
      );
    });
  });
}
