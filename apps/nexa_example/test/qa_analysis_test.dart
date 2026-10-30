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
}
