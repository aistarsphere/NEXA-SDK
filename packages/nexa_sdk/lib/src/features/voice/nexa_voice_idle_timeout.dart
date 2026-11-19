import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:nexa_core/nexa_core.dart';
import 'package:nexa_sdk/src/features/tools/labeeb_tool_calls.dart';
import 'package:nexa_sdk/src/features/voice/nexa_voice_controller.dart';

/// Fires [onTimeout] after [timeout] of genuine inactivity in a live call.
///
/// Activity: speech on either side (phases and real audio levels), new
/// transcript text, tool events and tool-call changes. It never fires
/// while someone is speaking, the assistant is thinking, the call is
/// connecting or reconnecting, or a tool call is running or waiting for an
/// approval or for this device; it waits for those to finish and then
/// counts a full [timeout] again.
class NexaVoiceIdleTimeout {
  NexaVoiceIdleTimeout({
    required this.voice,
    required this.timeout,
    required this.onTimeout,
    this.tools,
  });

  final NexaVoiceController voice;
  final LabeebToolCallController? tools;
  final Duration timeout;
  final VoidCallback onTimeout;

  /// Above this level a side counts as speaking.
  static const speechLevel = 0.04;

  Timer? _timer;
  StreamSubscription<NexaVoiceToolEvent>? _toolEvents;
  int _transcript = 0;
  String? _lastText;
  bool _started = false;
  DateTime _since = DateTime.now();
  bool _fired = false;

  /// Begins counting (call once the call is starting or live).
  void start() {
    if (_started) return;
    _started = true;
    _since = DateTime.now();
    voice.state.addListener(_onState);
    voice.levels.addListener(_onLevels);
    tools?.addListener(_onTools);
    _toolEvents = voice.toolEvents.listen((_) => touch());
    touch();
  }

  /// Resets the countdown.
  void touch() {
    if (!_started || _fired) return;
    _timer?.cancel();
    _timer = Timer(timeout, _expire);
  }

  /// Something is happening that must never be cut off.
  bool get busy => busyReason != null;

  /// Why the timeout is waiting (diagnostics), or null.
  String? get busyReason {
    final phase = voice.state.value.phase;
    final talking = switch (phase) {
      VoiceState.connecting ||
      VoiceState.userSpeaking ||
      VoiceState.transcribing ||
      VoiceState.thinking ||
      VoiceState.aiSpeaking ||
      VoiceState.bargeIn ||
      VoiceState.reconnecting ||
      VoiceState.modelBusy => true,
      _ => false,
    };
    if (talking) return 'voice:${phase.name}';
    final l = voice.levels.value;
    if (l.local > speechLevel || l.agent > speechLevel) return 'speech_level';
    // Only tool calls of this conversation: calls restored from history
    // (e.g. an old job) must not keep the panel open.
    final open = tools?.activities.where(
      (a) =>
          !a.firstSeen.isBefore(_since) &&
          switch (a.call.status) {
            NexaToolCallStatus.awaitingApproval ||
            NexaToolCallStatus.awaitingClient ||
            NexaToolCallStatus.running => true,
            _ => false,
          },
    );
    final first = open == null || open.isEmpty ? null : open.first;
    return first == null
        ? null
        : 'tool:${first.call.tool}:${first.call.status.wire}';
  }

  void _onState() {
    final s = voice.state.value;
    final text = s.transcript.isEmpty ? null : s.transcript.last.text;
    if (s.transcript.length != _transcript || text != _lastText) {
      _transcript = s.transcript.length;
      _lastText = text;
      touch();
    } else if (busy) {
      touch();
    }
  }

  String _toolsSeen = '';

  /// Background refreshes of the tool list are not activity: only a new
  /// tool call of this conversation or a status change counts.
  void _onTools() {
    final t = tools;
    if (t == null) return;
    final now = t.activities
        .where((a) => !a.firstSeen.isBefore(_since))
        .map((a) => '${a.call.id}:${a.call.status.wire}')
        .join(',');
    if (now == _toolsSeen) return;
    _toolsSeen = now;
    touch();
  }

  void _onLevels() {
    final l = voice.levels.value;
    if (l.local > speechLevel || l.agent > speechLevel) touch();
  }

  /// Also fires when no call is running any more (it failed or ended
  /// without the host noticing): there is nothing left to protect.
  void _expire() {
    if (_fired) return;
    final reason = busyReason;
    if (reason != null) {
      debugPrint('[nexa idle] waiting: $reason');
      touch();
      return;
    }
    _fired = true;
    onTimeout();
  }

  void dispose() {
    _timer?.cancel();
    if (_started) {
      voice.state.removeListener(_onState);
      voice.levels.removeListener(_onLevels);
      tools?.removeListener(_onTools);
    }
    unawaited(_toolEvents?.cancel());
  }
}
