import 'package:flutter/material.dart';
import 'package:nexa_ui/l10n/generated/nexa_localizations.dart';
import 'package:nexa_ui/src/theme/nexa_motion.dart';

/// Three pulsing dots. Static under reduced motion.
class NexaTypingIndicator extends StatefulWidget {
  const NexaTypingIndicator({this.color, super.key});

  final Color? color;

  @override
  State<NexaTypingIndicator> createState() => _NexaTypingIndicatorState();
}

class _NexaTypingIndicatorState extends State<NexaTypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (NexaMotion.reduced(context)) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color =
        widget.color ?? Theme.of(context).colorScheme.onSurfaceVariant;
    return Semantics(
      label: NexaLocalizations.of(context).assistantTyping,
      liveRegion: true,
      child: SizedBox(
        height: 20,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (i) {
                final t = ((_controller.value - i * 0.2) % 1.0).clamp(0.0, 1.0);
                final opacity = NexaMotion.reduced(context)
                    ? 0.7
                    : 0.35 + 0.65 * (1 - (t - 0.5).abs() * 2).clamp(0.0, 1.0);
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Opacity(
                    opacity: opacity,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                      child: const SizedBox(width: 8, height: 8),
                    ),
                  ),
                );
              }),
            );
          },
        ),
      ),
    );
  }
}
