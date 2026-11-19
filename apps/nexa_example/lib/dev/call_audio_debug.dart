import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:nexa_sdk/nexa_sdk.dart';

/// Debug builds only (`kDebugMode`): a small panel over the app during a
/// call with the audio facts the manual test sheet asks for (T1–T6): the
/// audio mode, the output in use, mute and microphone state, phone-call
/// hold, the engine's echo canceller, and this call's server counters.
/// Tap to collapse. No audio and no text are shown or stored.
class CallAudioDebugOverlay extends StatefulWidget {
  const CallAudioDebugOverlay({
    required this.voice,
    required this.child,
    super.key,
  });

  final NexaVoiceController voice;
  final Widget child;

  /// Whether the overlay exists in this build.
  static const bool enabled = kDebugMode;

  @override
  State<CallAudioDebugOverlay> createState() => _CallAudioDebugOverlayState();
}

class _CallAudioDebugOverlayState extends State<CallAudioDebugOverlay> {
  bool _open = true;
  late Listenable _sources;
  bool _queued = false;

  @override
  void initState() {
    super.initState();
    _sources = _listen(widget.voice);
  }

  @override
  void didUpdateWidget(CallAudioDebugOverlay old) {
    super.didUpdateWidget(old);
    if (old.voice != widget.voice) {
      _sources.removeListener(_changed);
      _sources = _listen(widget.voice);
    }
  }

  Listenable _listen(NexaVoiceController v) =>
      Listenable.merge([v.state, v.stats, ?v.callAudio?.state])
        ..addListener(_changed);

  /// Deferred: the call page ends the call in its dispose, while the tree
  /// is locked; this overlay outlives it.
  void _changed() {
    if (_queued) return;
    _queued = true;
    scheduleMicrotask(() {
      _queued = false;
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _sources.removeListener(_changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.voice;
    final active = v.state.value.isActive;
    return Stack(
      children: [
        widget.child,
        if (active)
          PositionedDirectional(
            top: MediaQuery.paddingOf(context).top + 56,
            start: 8,
            child: _Panel(
              open: _open,
              onTap: () => setState(() => _open = !_open),
              rows: callAudioDebugRows(v),
            ),
          ),
      ],
    );
  }
}

/// The rows of the panel (also used by tests): label → value.
List<(String, String)> callAudioDebugRows(NexaVoiceController v) {
  final s = v.state.value;
  final st = v.stats.value;
  final a = v.callAudio?.state.value;
  String ms(int? x) => x == null ? '-' : '$x ms';
  return [
    ('phase', s.phase.name),
    ('muted (user)', '${s.muted}'),
    ('mic sending', '${v.microphoneEnabled}'),
    ('hold', s.hold?.name ?? 'none'),
    ('focus', a?.focus ?? 'n/a'),
    ('route', a?.route.name ?? 'n/a'),
    (
      'choice',
      a == null ? 'n/a' : (a.speakerPreferred ? 'speaker' : 'earpiece'),
    ),
    ('mode (actual)', a?.mode ?? 'n/a'),
    if (a?.requestedMode != null) ('mode (requested)', a!.requestedMode!),
    (
      'AEC / NS / AGC',
      a == null || a.processing.isEmpty
          ? 'n/a'
          : '${a.processing['aec']} / ${a.processing['ns']} / '
                '${a.processing['agc']}',
    ),
    (
      'bluetooth',
      a == null
          ? 'n/a'
          : '${a.bluetoothPresent ? 'present' : 'none'}'
                '${a.bluetoothPermissionNeeded ? ' (no permission)' : ''}',
    ),
    ('interruptions (server)', '${st.interruptions}'),
    ('speech starts (server)', '${st.speechStarts}'),
    ('last unmute / mute', '${ms(st.unmuteMs)} / ${ms(st.muteMs)}'),
  ];
}

class _Panel extends StatelessWidget {
  const _Panel({required this.open, required this.onTap, required this.rows});

  final bool open;
  final VoidCallback onTap;
  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelSmall?.copyWith(
      color: Colors.white,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    return GestureDetector(
      key: const Key('call_audio_debug'),
      onTap: onTap,
      child: Material(
        color: Colors.black.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 260),
              // Values are English/ASCII: keep them left-to-right in Arabic.
              child: open
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final (k, v) in rows) Text('$k: $v', style: style),
                      ],
                    )
                  : Text('audio debug', style: style),
            ),
          ),
        ),
      ),
    );
  }
}
