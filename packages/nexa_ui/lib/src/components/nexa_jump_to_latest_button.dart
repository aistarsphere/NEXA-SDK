import 'package:flutter/material.dart';
import 'package:nexa_ui/l10n/generated/nexa_localizations.dart';
import 'package:nexa_ui/src/theme/nexa_motion.dart';

/// Small floating affordance shown when the user has scrolled away from the
/// newest message and new content arrived. Animates in/out; instant under
/// reduced motion.
class NexaJumpToLatestButton extends StatelessWidget {
  const NexaJumpToLatestButton({
    required this.visible,
    required this.onPressed,
    super.key,
  });

  final bool visible;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = NexaLocalizations.of(context);
    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: NexaMotion.of(context, NexaMotion.short),
        curve: NexaMotion.standard,
        child: AnimatedSlide(
          offset: visible ? Offset.zero : const Offset(0, 0.5),
          duration: NexaMotion.of(context, NexaMotion.short),
          curve: NexaMotion.emphasizedDecelerate,
          child: Semantics(
            button: true,
            hidden: !visible,
            label: l10n.jumpToLatest,
            child: ExcludeSemantics(
              child: FilledButton.tonalIcon(
                key: const Key('nexa_jump_to_latest'),
                onPressed: onPressed,
                icon: const Icon(Icons.arrow_downward_rounded, size: 18),
                label: Text(l10n.jumpToLatest),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
