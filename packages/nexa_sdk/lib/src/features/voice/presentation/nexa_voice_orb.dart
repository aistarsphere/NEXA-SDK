import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:nexa_core/nexa_core.dart';

/// What the orb shows. Each mode follows a real state of the assistant.
enum NexaOrbMode {
  /// Waiting for the wake phrase (not in a call).
  idle,

  /// The wake phrase was just recognised.
  wake,

  /// Setting up the call.
  connecting,

  /// In the call, the microphone is open.
  listening,

  /// The user is speaking.
  userSpeaking,

  /// Transcribing or thinking.
  understanding,

  /// A tool is running or waiting for approval.
  tool,

  /// The assistant is speaking.
  speaking,
  muted,
  reconnecting,
  error,
}

/// Maps a voice phase (plus tool activity and a failed start) to an orb
/// mode.
NexaOrbMode nexaOrbModeFor(
  VoiceState phase, {
  bool toolActive = false,
  bool failed = false,
}) {
  if (failed) return NexaOrbMode.error;
  if (toolActive &&
      phase != VoiceState.aiSpeaking &&
      phase != VoiceState.userSpeaking) {
    return NexaOrbMode.tool;
  }
  return switch (phase) {
    VoiceState.idle || VoiceState.ended => NexaOrbMode.idle,
    VoiceState.connecting => NexaOrbMode.connecting,
    VoiceState.listening => NexaOrbMode.listening,
    VoiceState.userSpeaking || VoiceState.bargeIn => NexaOrbMode.userSpeaking,
    VoiceState.transcribing ||
    VoiceState.thinking ||
    VoiceState.modelBusy => NexaOrbMode.understanding,
    VoiceState.aiSpeaking => NexaOrbMode.speaking,
    VoiceState.muted => NexaOrbMode.muted,
    VoiceState.weakNetwork ||
    VoiceState.reconnecting ||
    VoiceState.disconnected => NexaOrbMode.reconnecting,
    VoiceState.microphoneDenied ||
    VoiceState.quotaExceeded => NexaOrbMode.error,
  };
}

/// The assistant's presence: a soft orb of three light lobes around a core.
///
/// * Motion comes only from real input: the lobes swell with the actual
///   speaking level ([level], from the media server) of whoever is
///   speaking, drift while the assistant understands, ring while a tool
///   runs, and stay still when muted or in error.
/// * Colours come from the host theme (primary, tertiary, secondary).
/// * With reduced motion (or [animate] false) it draws a still frame per
///   mode, and the ticker only runs while something moves.
class NexaVoiceOrb extends StatefulWidget {
  const NexaVoiceOrb({
    required this.mode,
    this.level,
    this.size = 96,
    this.animate = true,
    this.semanticLabel,
    super.key,
  });

  final NexaOrbMode mode;

  /// 0..1 speaking level of the side that matters in [mode].
  final ValueListenable<double>? level;
  final double size;
  final bool animate;
  final String? semanticLabel;

  @override
  State<NexaVoiceOrb> createState() => _NexaVoiceOrbState();
}

class _NexaVoiceOrbState extends State<NexaVoiceOrb>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_tick);
  final ValueNotifier<int> _frame = ValueNotifier(0);
  Duration _elapsed = Duration.zero;
  Duration _last = Duration.zero;
  double _energy = 0;
  double _bloom = 0;

  bool get _reduced =>
      !widget.animate || MediaQuery.maybeDisableAnimationsOf(context) == true;

  bool get _moving => switch (widget.mode) {
    NexaOrbMode.muted || NexaOrbMode.error => false,
    _ => true,
  };

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(NexaVoiceOrb old) {
    super.didUpdateWidget(old);
    if (old.mode != widget.mode && widget.mode == NexaOrbMode.wake) {
      _bloom = 1;
    }
    _sync();
  }

  void _sync() {
    final run = !_reduced && (_moving || _bloom > 0 || _energy > 0.01);
    if (run && !_ticker.isActive) {
      _last = Duration.zero;
      _ticker.start();
    } else if (!run && _ticker.isActive) {
      _ticker.stop();
    }
  }

  double get _target {
    final l = widget.level?.value ?? 0;
    return switch (widget.mode) {
      NexaOrbMode.userSpeaking ||
      NexaOrbMode.speaking => 0.35 + 0.65 * math.min(1, l * 2.2),
      NexaOrbMode.listening => math.min(1, l * 2.2) * 0.6,
      NexaOrbMode.understanding => 0.25,
      NexaOrbMode.tool => 0.2,
      NexaOrbMode.wake => 0.5,
      _ => 0,
    };
  }

  void _tick(Duration now) {
    final dt = _last == Duration.zero
        ? 1 / 60
        : (now - _last).inMicroseconds / 1e6;
    _last = now;
    _elapsed += Duration(microseconds: (dt * 1e6).round());
    // Ease towards the real level: quick rise, gentle fall.
    final target = _target;
    final rate = target > _energy ? 10.0 : 3.0;
    _energy += (target - _energy) * math.min(1, dt * rate);
    _bloom = math.max(0, _bloom - dt * 1.6);
    _frame.value++;
    if (!_moving && _bloom == 0 && _energy < 0.01) _ticker.stop();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _frame.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final reduced = _reduced;
    return Semantics(
      label: widget.semanticLabel,
      image: true,
      child: RepaintBoundary(
        child: SizedBox.square(
          dimension: widget.size,
          child: CustomPaint(
            painter: _OrbPainter(
              repaint: _frame,
              mode: widget.mode,
              scheme: scheme,
              time: () => reduced ? 0 : _elapsed.inMicroseconds / 1e6,
              energy: () => reduced ? _target : _energy,
              bloom: () => reduced ? 0 : _bloom,
            ),
          ),
        ),
      ),
    );
  }
}

class _OrbPainter extends CustomPainter {
  _OrbPainter({
    required Listenable repaint,
    required this.mode,
    required this.scheme,
    required this.time,
    required this.energy,
    required this.bloom,
  }) : super(repaint: repaint);

  final NexaOrbMode mode;
  final ColorScheme scheme;
  final double Function() time;
  final double Function() energy;
  final double Function() bloom;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide * 0.30;
    final t = time();
    final e = energy();
    final b = bloom();

    final (a1, a2, a3) = switch (mode) {
      NexaOrbMode.muted => (
        scheme.outline,
        scheme.outlineVariant,
        scheme.onSurfaceVariant,
      ),
      NexaOrbMode.error => (scheme.error, scheme.errorContainer, scheme.error),
      NexaOrbMode.reconnecting => (
        scheme.primary.withValues(alpha: 0.5),
        scheme.secondary.withValues(alpha: 0.4),
        scheme.tertiary.withValues(alpha: 0.4),
      ),
      _ => (scheme.primary, scheme.tertiary, scheme.secondary),
    };

    // Halo: grows with the speaking level and the wake bloom.
    final halo = r * (1.35 + 0.45 * e + 0.5 * b);
    canvas.drawCircle(
      c,
      halo,
      Paint()
        ..shader = RadialGradient(
          colors: [
            a1.withValues(alpha: 0.28 + 0.2 * b),
            a1.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: c, radius: halo)),
    );

    // Three lobes orbit the core. Their offset and size follow energy; the
    // drift speed follows the mode (thinking drifts, speech pulses).
    final drift = switch (mode) {
      NexaOrbMode.understanding => 0.9,
      NexaOrbMode.tool => 0.5,
      NexaOrbMode.connecting => 0.6,
      NexaOrbMode.idle => 0.15,
      _ => 0.35,
    };
    final colors = [a1, a2, a3];
    for (var i = 0; i < 3; i++) {
      final phase = t * drift * (1 + i * 0.27) + i * 2.1;
      final wobble = math.sin(t * (2.2 + i) + i) * 0.5 + 0.5;
      final off = r * (0.14 + 0.22 * e * (0.6 + 0.4 * wobble));
      final p = c + Offset(math.cos(phase), math.sin(phase)) * off;
      final lr = r * (0.78 + 0.18 * e * wobble);
      canvas.drawCircle(
        p,
        lr,
        Paint()
          ..shader = RadialGradient(
            colors: [
              colors[i].withValues(alpha: 0.75),
              colors[i].withValues(alpha: 0),
            ],
          ).createShader(Rect.fromCircle(center: p, radius: lr)),
      );
    }

    // Core.
    canvas.drawCircle(
      c,
      r * (0.62 + 0.08 * e),
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.3, -0.35),
          colors: [Color.lerp(a1, Colors.white, 0.55)!, a1],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );

    // State marks.
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = r * 0.07;
    switch (mode) {
      case NexaOrbMode.tool:
        // Three arcs turning slowly: work in progress, not a fake timer.
        ring.color = a2;
        for (var i = 0; i < 3; i++) {
          canvas.drawArc(
            Rect.fromCircle(center: c, radius: r * 1.18),
            t * 0.8 + i * 2 * math.pi / 3,
            math.pi / 4,
            false,
            ring,
          );
        }
      case NexaOrbMode.connecting:
        ring.color = a1.withValues(alpha: 0.6);
        canvas.drawArc(
          Rect.fromCircle(center: c, radius: r * 1.18),
          t * 1.6,
          math.pi / 2,
          false,
          ring,
        );
      case NexaOrbMode.reconnecting:
        ring.color = a1.withValues(alpha: 0.35 + 0.25 * math.sin(t * 3).abs());
        const dashes = 12;
        for (var i = 0; i < dashes; i++) {
          canvas.drawArc(
            Rect.fromCircle(center: c, radius: r * 1.18),
            i * 2 * math.pi / dashes,
            math.pi / dashes,
            false,
            ring,
          );
        }
      case NexaOrbMode.muted:
        final s = Paint()
          ..color = scheme.surface
          ..strokeWidth = r * 0.12
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(
          c + Offset(-r * 0.4, -r * 0.4),
          c + Offset(r * 0.4, r * 0.4),
          s,
        );
      default:
        break;
    }
  }

  @override
  bool shouldRepaint(_OrbPainter old) =>
      old.mode != mode || old.scheme != scheme;
}
