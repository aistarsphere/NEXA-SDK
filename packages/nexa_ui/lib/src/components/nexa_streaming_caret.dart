import 'package:flutter/material.dart';
import 'package:nexa_ui/src/theme/nexa_motion.dart';

/// Blinking block caret appended to streaming assistant text. Static (solid)
/// under reduced motion. Purely decorative: excluded from semantics.
class NexaStreamingCaret extends StatefulWidget {
  const NexaStreamingCaret({this.color, super.key});

  final Color? color;

  @override
  State<NexaStreamingCaret> createState() => _NexaStreamingCaretState();
}

class _NexaStreamingCaretState extends State<NexaStreamingCaret>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (NexaMotion.reduced(context)) {
      _controller
        ..stop()
        ..value = 1;
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? Theme.of(context).colorScheme.primary;
    return ExcludeSemantics(
      child: FadeTransition(
        opacity: _controller,
        child: Container(
          width: 8,
          height: 16,
          margin: const EdgeInsetsDirectional.only(start: 2),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }
}
