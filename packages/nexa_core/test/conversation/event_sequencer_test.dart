import 'package:nexa_core/nexa_core.dart';
import 'package:test/test.dart';

import '../helpers.dart';

void main() {
  group('EventSequencer', () {
    late EventSequencer seq;
    setUp(() => seq = EventSequencer(reorderWindow: 3)..reset(session));

    test('applies contiguous events', () {
      final r = seq.accept(started(1));
      expect(r.verdict, SequencerVerdict.apply);
      expect(r.ready.single.sequence, 1);
      expect(seq.lastApplied, 1);
    });

    test('buffers early events and drains when gap fills', () {
      expect(
        seq.accept(delta(3, 'a', 1, 'c')).verdict,
        SequencerVerdict.buffered,
      );
      expect(
        seq.accept(delta(2, 'a', 0, 'b')).verdict,
        SequencerVerdict.buffered,
      );
      final r = seq.accept(started(1));
      expect(r.verdict, SequencerVerdict.apply);
      expect(r.ready.map((e) => e.sequence), [1, 2, 3]);
      expect(seq.bufferedCount, 0);
    });

    test('rejects duplicates by sequence and by eventId', () {
      seq.accept(started(1));
      expect(seq.accept(started(1)).verdict, SequencerVerdict.duplicate);
      const id = EventId('dup');
      expect(
        seq.accept(delta(2, 'a', 0, 'x', eventId: id)).verdict,
        SequencerVerdict.apply,
      );
      expect(
        seq.accept(delta(3, 'a', 1, 'x', eventId: id)).verdict,
        SequencerVerdict.duplicate,
      );
    });

    test('rejects events from another session', () {
      final other = ConversationEvent.sessionStarted(
        eventId: eid(),
        sessionId: const SessionId('other'),
        sequence: 1,
        occurredAt: t0,
        expiresAt: t0,
      );
      expect(seq.accept(other).verdict, SequencerVerdict.duplicate);
    });

    test('skips a gap when the reorder window overflows', () {
      seq.accept(started(1));
      seq.accept(delta(3, 'a', 0, 'a'));
      seq.accept(delta(4, 'a', 1, 'b'));
      seq.accept(delta(5, 'a', 2, 'c'));
      final r = seq.accept(delta(6, 'a', 3, 'd'));
      expect(r.verdict, SequencerVerdict.gapSkipped);
      expect(r.ready.map((e) => e.sequence), [3, 4, 5, 6]);
      expect(seq.lastApplied, 6);
      // the late seq 2 is now a duplicate
      expect(
        seq.accept(delta(2, 'a', 9, 'late')).verdict,
        SequencerVerdict.duplicate,
      );
    });

    test('resume after lastApplied', () {
      seq.reset(session, lastApplied: 10);
      expect(
        seq.accept(delta(10, 'a', 0, 'x')).verdict,
        SequencerVerdict.duplicate,
      );
      expect(
        seq.accept(delta(11, 'a', 0, 'x')).verdict,
        SequencerVerdict.apply,
      );
    });
  });
}
