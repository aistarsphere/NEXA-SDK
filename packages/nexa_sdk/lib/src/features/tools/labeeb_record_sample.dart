import 'dart:async';
import 'dart:io';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:nexa_core/nexa_core.dart';
import 'package:nexa_device/nexa_device.dart';
import 'package:nexa_sdk/src/features/tools/labeeb_device_tools.dart';
import 'package:nexa_ui/nexa_ui.dart';

/// `device.microphone.record_sample` (group `voice_identity`) →
/// `{asset_id, duration_s}`.
///
/// The gateway only calls it after the user agreed to voice cloning, and
/// the call itself needs approval. Even then nothing is captured until the
/// user taps "Start recording" on the sheet; the sheet shows a recording
/// indicator and the user finishes it. The temporary file is deleted after
/// the upload, and no audio is logged.
final class LabeebRecordSampleTool implements LabeebDeviceTool {
  LabeebRecordSampleTool({
    NexaMicrophoneRecorder Function()? recorder,
    this.onOpenSettings,
  }) : _recorder = recorder ?? PluginMicrophoneRecorder.new;

  final NexaMicrophoneRecorder Function() _recorder;
  final VoidCallback? onOpenSettings;

  /// Contract bounds: `min_seconds` 5..30, `max_seconds` 10..60.
  static (int, int) bounds(Map<String, Object?> args) {
    final min = ((args['min_seconds'] as num?)?.toInt() ?? 5).clamp(5, 30);
    final max = ((args['max_seconds'] as num?)?.toInt() ?? 30).clamp(10, 60);
    return (min, max < min ? min : max);
  }

  @override
  String get name => LabeebTools.recordSample;

  @override
  bool get needsUi => true;

  @override
  Future<bool> supported() async => true;

  @override
  Future<NexaToolCallAnswer> run(
    LabeebToolRunContext ctx,
    NexaToolCall call,
  ) async {
    final context = ctx.context;
    if (context == null || !context.mounted) {
      return _failure(NexaDeviceErrorCodes.cancelled);
    }
    final (min, max) = bounds(call.arguments);
    final outcome = await showModalBottomSheet<LabeebSampleOutcome>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => nexaScoped(
        context,
        LabeebRecordSampleSheet(
          purpose: call.arguments['purpose'] as String?,
          minSeconds: min,
          maxSeconds: max,
          recorder: _recorder,
          onOpenSettings: onOpenSettings,
        ),
      ),
    );
    switch (outcome) {
      case LabeebSampleRecorded(:final file, :final duration):
        try {
          final id = await ctx.upload(
            await file.readAsBytes(),
            'audio/wav',
            'voice-sample.wav',
          );
          return NexaToolCallAnswer.success({
            'asset_id': id,
            'duration_s': (duration.inMilliseconds / 100).round() / 10,
          });
        } finally {
          if (file.existsSync()) file.deleteSync();
        }
      case LabeebSampleDenied():
        return _failure(NexaDeviceErrorCodes.permissionDenied);
      case LabeebSampleFailed():
        return _failure(NexaDeviceErrorCodes.deviceError);
      case LabeebSampleCancelled() || null:
        return _failure(NexaDeviceErrorCodes.cancelled);
    }
  }

  NexaToolCallAnswer _failure(String code) =>
      NexaToolCallAnswer.failure(NexaToolCallError(code));
}

/// How the recording sheet closed.
sealed class LabeebSampleOutcome {
  const LabeebSampleOutcome();
}

final class LabeebSampleRecorded extends LabeebSampleOutcome {
  const LabeebSampleRecorded(this.file, this.duration);
  final File file;
  final Duration duration;
}

final class LabeebSampleCancelled extends LabeebSampleOutcome {
  const LabeebSampleCancelled();
}

final class LabeebSampleDenied extends LabeebSampleOutcome {
  const LabeebSampleDenied();
}

final class LabeebSampleFailed extends LabeebSampleOutcome {
  const LabeebSampleFailed();
}

enum _Phase { ready, asking, denied, recording, finishing }

/// Consent-first recording sheet: what is captured and why, then a
/// user-started recording with a visible indicator, elapsed time, the
/// minimum still needed, and Finish / Cancel. Stops itself at the maximum.
class LabeebRecordSampleSheet extends StatefulWidget {
  const LabeebRecordSampleSheet({
    required this.minSeconds,
    required this.maxSeconds,
    required this.recorder,
    this.purpose,
    this.onOpenSettings,
    super.key,
  });

  final String? purpose;
  final int minSeconds;
  final int maxSeconds;
  final NexaMicrophoneRecorder Function() recorder;
  final VoidCallback? onOpenSettings;

  @override
  State<LabeebRecordSampleSheet> createState() =>
      _LabeebRecordSampleSheetState();
}

class _LabeebRecordSampleSheetState extends State<LabeebRecordSampleSheet> {
  late final NexaMicrophoneRecorder _recorder = widget.recorder();
  final Stopwatch _watch = clock.stopwatch();
  Timer? _ticker;
  StreamSubscription<double>? _levels;
  double _level = 0;
  _Phase _phase = _Phase.ready;
  bool _closed = false;

  Duration get _elapsed => _watch.elapsed;
  bool get _longEnough => _elapsed.inSeconds >= widget.minSeconds;

  void _close(LabeebSampleOutcome outcome) {
    if (_closed || !mounted) return;
    _closed = true;
    Navigator.of(context).pop(outcome);
  }

  Future<void> _start() async {
    setState(() => _phase = _Phase.asking);
    final granted = await _recorder.requestPermission();
    if (!mounted) return;
    if (!granted) {
      setState(() => _phase = _Phase.denied);
      return;
    }
    try {
      await _recorder.start();
    } on Object {
      _close(const LabeebSampleFailed());
      return;
    }
    if (!mounted) return;
    _watch.start();
    _levels = _recorder.level.listen((v) {
      if (mounted) setState(() => _level = v);
    });
    _ticker = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (!mounted) return;
      if (_elapsed.inSeconds >= widget.maxSeconds) {
        unawaited(_finish());
      } else {
        setState(() {});
      }
    });
    setState(() => _phase = _Phase.recording);
  }

  Future<void> _finish() async {
    if (_phase != _Phase.recording) return;
    _ticker?.cancel();
    _watch.stop();
    setState(() => _phase = _Phase.finishing);
    final duration = _elapsed;
    File? file;
    try {
      file = await _recorder.stop();
    } on Object {
      file = null;
    }
    _close(
      file == null
          ? const LabeebSampleFailed()
          : LabeebSampleRecorded(file, duration),
    );
  }

  Future<void> _cancel() async {
    _ticker?.cancel();
    _watch.stop();
    final denied = _phase == _Phase.denied;
    if (_phase == _Phase.recording) {
      _phase = _Phase.finishing; // dispose must not cancel again
      try {
        await _recorder.cancel();
      } on Object {
        // Nothing kept either way.
      }
    }
    _close(denied ? const LabeebSampleDenied() : const LabeebSampleCancelled());
  }

  @override
  void dispose() {
    _ticker?.cancel();
    unawaited(_levels?.cancel());
    if (_phase == _Phase.recording) unawaited(_recorder.cancel());
    unawaited(_recorder.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = NexaLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final seconds = _elapsed.inSeconds;
    final recording = _phase == _Phase.recording;
    final purpose = widget.purpose?.trim();
    return PopScope(
      canPop: false,
      child: Padding(
        key: const Key('labeeb_rec_sheet'),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.recTitle,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(l10n.recIntro, style: theme.textTheme.bodyMedium),
            if (purpose != null && purpose.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                purpose,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              l10n.recHint(widget.minSeconds, widget.maxSeconds),
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 20),
            if (_phase == _Phase.denied)
              Text(
                l10n.recMicDenied,
                key: const Key('labeeb_rec_denied'),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.error,
                ),
              )
            else
              _Indicator(
                recording: recording,
                level: _level,
                label: recording || _phase == _Phase.finishing
                    ? l10n.recElapsed(seconds, widget.maxSeconds)
                    : null,
                progress: seconds / widget.maxSeconds,
                semantics: l10n.recRecording,
              ),
            if (recording && !_longEnough) ...[
              const SizedBox(height: 8),
              Text(
                l10n.recMore(widget.minSeconds - seconds),
                key: const Key('labeeb_rec_more'),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    key: const Key('labeeb_rec_cancel'),
                    onPressed: _phase == _Phase.finishing ? null : _cancel,
                    child: Text(l10n.cancel),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: switch (_phase) {
                    _Phase.ready || _Phase.asking => FilledButton.icon(
                      key: const Key('labeeb_rec_start'),
                      onPressed: _phase == _Phase.ready ? _start : null,
                      icon: const Icon(Icons.mic_rounded),
                      label: Text(l10n.recStart),
                    ),
                    _Phase.denied => FilledButton(
                      key: const Key('labeeb_rec_settings'),
                      onPressed: widget.onOpenSettings,
                      child: Text(l10n.openSettings),
                    ),
                    _Phase.recording || _Phase.finishing => FilledButton.icon(
                      key: const Key('labeeb_rec_finish'),
                      onPressed: recording && _longEnough ? _finish : null,
                      icon: const Icon(Icons.stop_rounded),
                      label: Text(l10n.recFinish),
                    ),
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Indicator extends StatelessWidget {
  const _Indicator({
    required this.recording,
    required this.level,
    required this.progress,
    required this.semantics,
    this.label,
  });

  final bool recording;
  final double level;
  final double progress;
  final String semantics;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Semantics(
      liveRegion: true,
      label: recording ? '$semantics ${label ?? ''}' : null,
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: 72 + 24 * level,
            height: 72 + 24 * level,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: recording
                  ? scheme.errorContainer
                  : scheme.surfaceContainerHigh,
            ),
            child: Icon(
              recording ? Icons.mic_rounded : Icons.mic_none_rounded,
              key: Key(recording ? 'labeeb_rec_live' : 'labeeb_rec_idle'),
              size: 36,
              color: recording ? scheme.error : scheme.onSurfaceVariant,
            ),
          ),
          if (label != null) ...[
            const SizedBox(height: 12),
            LinearProgressIndicator(value: progress.clamp(0.0, 1.0)),
            const SizedBox(height: 6),
            Text(label!, style: theme.textTheme.labelLarge),
          ],
        ],
      ),
    );
  }
}
