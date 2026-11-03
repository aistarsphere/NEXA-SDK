import 'package:flutter_test/flutter_test.dart';
import 'package:nexa_example/dev/qa/qa_analysis.dart';

/// Shapes seen in the first real iPhone record (LiveKit reports track kinds
/// as `AUDIO`; barge-in is the `bargeIn` phase; ICE closes on teardown).
void main() {
  QaLine l(int t, String ev, [Map<String, Object?> d = const {}]) =>
      QaLine(t, '', ev, d);

  test('real-device voice shapes are read correctly', () {
    final a = QaAnalysis.of([
      l(0, 'qa.record_started', {'type': 'voice'}),
      l(1, 'voice.start'),
      l(10, 'voice.ice', {'pc': 'sub', 'state': 'Connected'}),
      l(20, 'voice.local_track_published', {'kind': 'AUDIO'}),
      l(30, 'voice.remote_track_subscribed', {'agent': true, 'kind': 'AUDIO'}),
      l(40, 'voice.phase', {'from': 'aiSpeaking', 'to': 'bargeIn'}),
      l(50, 'voice.agent_event', {'type': 'interrupted', 'turn_id': 't1'}),
      l(60, 'voice.ended', {'reason': 'user'}),
      l(70, 'voice.ice', {'pc': 'sub', 'state': 'Disconnected'}),
      l(80, 'voice.teardown_done'),
    ]);
    expect(a.metrics['mic_published'], isTrue);
    expect(a.metrics['agent_audio_subscribed'], isTrue);
    expect(a.metrics['barge_in_attempts'], 1);
    expect(a.metrics['interruptions_confirmed'], 1);
    expect(a.warnings.where((w) => w.contains('ICE')), isEmpty);
    expect(a.errors.where((e) => e.contains('track')), isEmpty);
  });

  test('CER uses the tester phrase as reference', () {
    expect(characterErrorRate('مرحبا كيف حالك', 'مرحبا كيف حالك'), 0);
    expect(characterErrorRate('مرحبا', 'مرحبأ'), 0); // alef variants
    expect(characterErrorRate('abcd', 'abxd'), 0.25);
  });

  group('barge-in evidence (E-04)', () {
    QaAnalysis record(List<QaLine> body) => QaAnalysis.of([
      l(0, 'qa.record_started', {'type': 'voice'}),
      ...body,
    ]);

    test('a confirmed interruption carries the agent ids and timings', () {
      final a = record([
        l(100, 'voice.agent_event', {
          'type': 'assistant_audio_started',
          'turn_id': 't1',
        }),
        l(900, 'voice.phase', {'from': 'aiSpeaking', 'to': 'bargeIn'}),
        l(1250, 'voice.agent_event', {
          'type': 'interrupted',
          'turn_id': 't1',
          'cancel_id': 'c1',
          'by_turn_id': 't2',
          'audio_started': true,
        }),
      ]);
      expect(a.bargeIns, hasLength(1));
      final b = a.bargeIns.single;
      expect(b['confirmed'], isTrue);
      expect(b['cancel_id'], 'c1');
      expect(b['by_turn_id'], 't2');
      expect(b['audio_started'], isTrue);
      expect(
        b['into_reply_ms'],
        800,
        reason: 'user speech at 900, reply at 100',
      );
      expect(b['confirm_delay_ms'], 350);
      expect(a.metrics['barge_ins_confirmed'], 1);
      expect(a.metrics['barge_ins_unconfirmed'], 0);
    });

    test('an attempt the agent never confirmed is reported as such', () {
      final a = record([
        l(100, 'voice.agent_event', {
          'type': 'assistant_audio_started',
          'turn_id': 't1',
        }),
        l(900, 'voice.phase', {'from': 'aiSpeaking', 'to': 'bargeIn'}),
        l(1250, 'voice.agent_event', {
          'type': 'interrupted',
          'cancel_id': 'c1',
          'by_turn_id': 't2',
          'audio_started': true,
        }),
        l(5000, 'voice.phase', {'from': 'aiSpeaking', 'to': 'bargeIn'}),
        l(6000, 'voice.phase', {'from': 'bargeIn', 'to': 'listening'}),
      ]);
      expect(a.bargeIns, hasLength(2));
      expect(a.bargeIns.last['confirmed'], isFalse);
      expect(a.bargeIns.last['cancel_id'], isNull);
      expect(a.metrics['barge_ins_unconfirmed'], 1);
      expect(
        a.hypotheses.any((h) => h.contains('without an `interrupted`')),
        isTrue,
        reason: 'looks like speech the agent decided was not an interruption',
      );
    });

    test('says plainly what the record cannot show', () {
      final a = record([
        l(900, 'voice.phase', {'from': 'aiSpeaking', 'to': 'bargeIn'}),
      ]);
      expect(a.missing.any((m) => m.contains('microphone level')), isTrue);
    });

    test('a call without interruptions reports none', () {
      final a = record([l(10, 'voice.start')]);
      expect(a.bargeIns, isEmpty);
      expect(a.metrics['barge_ins_confirmed'], 0);
    });
  });
}
