import 'package:flutter/material.dart';
import 'package:nexa_ui/src/theme/nexa_colors.dart';
import 'package:nexa_ui/src/theme/nexa_shapes.dart';

/// Tone of a [NexaStatusBanner].
enum NexaBannerTone { info, warning, error, success }

/// Inline banner for session-level states (ended, offline, quota, errors).
class NexaStatusBanner extends StatelessWidget {
  const NexaStatusBanner({
    required this.message,
    this.tone = NexaBannerTone.info,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  final String message;
  final NexaBannerTone tone;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = NexaColors.of(context);
    final (bg, fg, icon) = switch (tone) {
      NexaBannerTone.info => (
        scheme.surfaceContainerHigh,
        scheme.onSurface,
        Icons.info_outline,
      ),
      NexaBannerTone.warning => (
        colors.warning,
        colors.onWarning,
        Icons.warning_amber,
      ),
      NexaBannerTone.error => (
        scheme.errorContainer,
        scheme.onErrorContainer,
        Icons.error_outline,
      ),
      NexaBannerTone.success => (
        colors.success,
        colors.onSuccess,
        Icons.check_circle_outline,
      ),
    };
    return Semantics(
      liveRegion: true,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(color: bg, borderRadius: NexaShapes.card),
        child: Row(
          children: [
            Icon(icon, color: fg, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: fg),
              ),
            ),
            if (actionLabel != null && onAction != null)
              TextButton(
                onPressed: onAction,
                style: TextButton.styleFrom(foregroundColor: fg),
                child: Text(actionLabel!),
              ),
          ],
        ),
      ),
    );
  }
}
