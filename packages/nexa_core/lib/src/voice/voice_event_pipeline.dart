import 'dart:convert';

import 'package:nexa_core/src/logging/nexa_logger.dart';
import 'package:nexa_core/src/transport/realtime_voice_transport.dart';
import 'package:nexa_core/src/voice/voice_events_v1.dart';
import 'package:nexa_core/src/voice/voice_grant.dart';

/// Transport-independent processing of agent events for one voice session
/// (contract `nexa.voice.v1` §5 and §8):
///
/// * every data packet and every `resume` RPC entry is verified by
///   [VoiceEventVerifier] before anything else;
/// * [VoiceReplayGuard] applies each `seq` once, drops older ones silently,
///   and on a gap asks the transport for a `resume` (nothing is applied past
///   a gap);
/// * the handshake of a connection completes on the first successful
///   `resume` answer or on a verified `agent_ready` / `session_state`
///   (matrix §A: a late joiner may only get the snapshot), and then emits
///   [RealtimeConnected] once for that connection;
/// * `assistant_text` caption chunks are folded per turn in `index` order.
///
/// The guard survives rejoins of the same session (call
/// [beginConnection] for every new room connection).
final class VoiceEventPipeline {
  VoiceEventPipeline({
    required VoiceGrant grant,
    required void Function(RealtimeVoiceEvent event) emit,
    required void Function() requestResume,
    NexaLogger logger = const NoopNexaLogger(),
  }) : verifier = VoiceEventVerifier.forGrant(grant),
       _emit = emit,
       _requestResume = requestResume,
       _logger = logger;

  final VoiceEventVerifier verifier;
  final VoiceReplayGuard guard = VoiceReplayGuard();
  final void Function(RealtimeVoiceEvent) _emit;
  final void Function() _requestResume;
  final NexaLogger _logger;

  bool _connected = false;
  final Map<String, Map<int, String>> _captions = {};

  /// Highest applied `seq` (the `last_seq` cursor for `resume`).
  int get lastApplied => guard.lastApplied;

  /// Whether the handshake of the current connection has completed.
  bool get isConnected => _connected;

  /// Starts a new room connection (initial join or rejoin).
  void beginConnection() => _connected = false;

  /// Handles one data packet received on `events.topic`.
  void onPacket(String text) => _accept(verifier.verifyText(text));

  /// Handles the JSON string returned by the `resume` RPC. Returns `true`
  /// when the server reported `has_more` (call again with [lastApplied]).
  bool onResumeResponse(String response) {
    final Object? decoded;
    try {
      decoded = jsonDecode(response);
    } on FormatException {
      _emit(const RealtimeEventRejected('resume: not json'));
      return false;
    }
    if (decoded is! Map<String, Object?>) {
      _emit(const RealtimeEventRejected('resume: not an object'));
      return false;
    }
    final events = decoded['events'];
    if (events is List) {
      for (final entry in events) {
        if (entry is String) {
          _accept(verifier.verifyText(entry));
        } else {
          _accept(verifier.verify(entry));
        }
      }
    }
    final lastSeq = decoded['last_seq'];
    if (decoded['covers'] == false && lastSeq is int) {
      // Replay buffer no longer reaches back: rely on `state`.
      for (final e in guard.skipTo(lastSeq)) {
        _apply(e);
      }
    }
    final state = decoded['state'];
    if (state is String) {
      _emit(
        RealtimeSessionSnapshot(
          state: state,
          lastSeq: lastSeq is int ? lastSeq : null,
        ),
      );
    }
    _markConnected();
    return decoded['has_more'] == true;
  }

  void _accept(VoiceEventVerdict verdict) {
    switch (verdict) {
      case VoiceEventRejected():
        _logger.log(NexaLogLevel.warning, 'voice event rejected: $verdict');
        _emit(RealtimeEventRejected(verdict.toString()));
      case VoiceEventAuthentic(:final event):
        final result = guard.accept(event);
        switch (result.verdict) {
          case VoiceReplayVerdict.duplicate:
            return; // dropped silently (spec step 7)
          case VoiceReplayVerdict.gap:
            _requestResume();
          case VoiceReplayVerdict.apply:
            result.ready.forEach(_apply);
        }
    }
  }

  void _apply(VoiceEventV1 event) {
    if (event.type == 'agent_ready' || event.type == 'session_state') {
      _markConnected();
    }
    if (event.type == 'assistant_text') {
      _foldCaption(event);
      return;
    }
    if (event.type == 'assistant_turn_ended') {
      _captions.remove(event.turnId);
    }
    final mapped = realtimeEventFromV1(event);
    if (mapped != null) _emit(mapped);
  }

  void _foldCaption(VoiceEventV1 event) {
    final turn = event.turnId ?? '';
    final chunks = _captions.putIfAbsent(turn, () => {});
    final index = event['index'];
    chunks[index is int ? index : chunks.length] = event['text']! as String;
    final ordered = chunks.keys.toList()..sort();
    _emit(
      RealtimeAssistantTranscript(
        text: [for (final i in ordered) chunks[i]].join(),
        isFinal: event['final'] == true,
      ),
    );
  }

  void _markConnected() {
    if (_connected) return;
    _connected = true;
    _emit(const RealtimeConnected());
  }
}
