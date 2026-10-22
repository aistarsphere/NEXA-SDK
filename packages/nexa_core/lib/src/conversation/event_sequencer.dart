import 'dart:collection';

import 'package:nexa_core/src/conversation/conversation_event.dart';
import 'package:nexa_core/src/ids/ids.dart';

/// What the sequencer decided about an incoming event.
enum SequencerVerdict {
  /// Apply now (and any buffered successors returned alongside).
  apply,

  /// Already seen (same eventId or sequence <= last applied).
  duplicate,

  /// Arrived early; buffered until the gap fills or the window overflows.
  buffered,

  /// Window overflowed: a gap was skipped. Caller should resync from
  /// `lastApplied` (e.g. re-fetch events `after=lastApplied`).
  gapSkipped,
}

/// Result of [EventSequencer.accept].
final class SequencerResult {
  const SequencerResult(this.verdict, this.ready);

  final SequencerVerdict verdict;

  /// Events to apply, in order. Empty for duplicate/buffered.
  final List<ConversationEvent> ready;
}

/// Enforces per-session ordering and de-duplication of [ConversationEvent]s.
///
/// Rules (documented in `.ai/flutter-architecture.md`):
/// 1. `sequence` must be > `lastApplied`; otherwise the event is a duplicate.
/// 2. Any `eventId` seen in the recent window is a duplicate, even with a new
///    sequence (defends against gateway retries that re-number).
/// 3. Events with `sequence == lastApplied + 1` are applied immediately,
///    followed by any contiguous buffered successors.
/// 4. Events arriving early are buffered up to [reorderWindow]; when the
///    window is exceeded, the lowest buffered sequence is applied and the gap
///    is reported via [SequencerVerdict.gapSkipped] so the transport can
///    resync.
/// 5. [reset] starts a fresh session; events from other sessions are rejected
///    as duplicates.
final class EventSequencer {
  EventSequencer({this.reorderWindow = 64, this.rememberEventIds = 512});

  /// Max number of early events held before a gap is skipped.
  final int reorderWindow;

  /// Size of the eventId de-duplication memory.
  final int rememberEventIds;

  SessionId? _sessionId;
  int _lastApplied = 0;
  final SplayTreeMap<int, ConversationEvent> _buffer = SplayTreeMap();
  final LinkedHashSet<EventId> _seen = LinkedHashSet();

  /// Highest sequence applied so far.
  int get lastApplied => _lastApplied;

  /// Number of events waiting for a gap to fill.
  int get bufferedCount => _buffer.length;

  /// Begins tracking [sessionId], optionally resuming after [lastApplied].
  void reset(SessionId sessionId, {int lastApplied = 0}) {
    _sessionId = sessionId;
    _lastApplied = lastApplied;
    _buffer.clear();
    _seen.clear();
  }

  /// Classifies [event] and returns the events that are now ready to apply.
  SequencerResult accept(ConversationEvent event) {
    if (_sessionId == null || event.sessionId != _sessionId) {
      return const SequencerResult(SequencerVerdict.duplicate, []);
    }
    if (event.sequence <= _lastApplied || _seen.contains(event.eventId)) {
      return const SequencerResult(SequencerVerdict.duplicate, []);
    }
    if (_buffer.containsKey(event.sequence)) {
      return const SequencerResult(SequencerVerdict.duplicate, []);
    }
    _remember(event.eventId);

    if (event.sequence == _lastApplied + 1) {
      final ready = <ConversationEvent>[event];
      _lastApplied = event.sequence;
      _drain(ready);
      return SequencerResult(SequencerVerdict.apply, ready);
    }

    _buffer[event.sequence] = event;
    if (_buffer.length <= reorderWindow) {
      return const SequencerResult(SequencerVerdict.buffered, []);
    }

    // Window overflow: skip the gap and apply from the lowest buffered seq.
    final first = _buffer.firstKey()!;
    final ready = <ConversationEvent>[_buffer.remove(first)!];
    _lastApplied = first;
    _drain(ready);
    return SequencerResult(SequencerVerdict.gapSkipped, ready);
  }

  void _drain(List<ConversationEvent> into) {
    while (_buffer.isNotEmpty && _buffer.firstKey() == _lastApplied + 1) {
      final next = _buffer.remove(_buffer.firstKey())!;
      into.add(next);
      _lastApplied = next.sequence;
    }
  }

  void _remember(EventId id) {
    _seen.add(id);
    if (_seen.length > rememberEventIds) {
      _seen.remove(_seen.first);
    }
  }
}
