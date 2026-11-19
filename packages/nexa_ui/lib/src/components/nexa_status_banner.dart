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
    // Design: a tonal container, a coloured icon, body text in onSurface.
    final (bg, iconColor, icon) = switch (tone) {
      NexaBannerTone.info => (
        scheme.surfaceContainerHigh,
        colors.info,
        Icons.info_rounded,
      ),
      NexaBannerTone.warning => (
        colors.warningContainer,
        colors.warning,
        Icons.warning_rounded,
      ),
      NexaBannerTone.error => (
        scheme.errorContainer,
        scheme.error,
        Icons.error_rounded,
      ),
      NexaBannerTone.success => (
        colors.successContainer,
        colors.success,
        Icons.check_circle_rounded,
      ),
    };
    final fg = tone == NexaBannerTone.error
        ? scheme.onErrorContainer
        : scheme.onSurface;
    return Semantics(
      liveRegion: true,
      child: Container(
        margin: const EdgeInsets.fromLTRB(10, 4, 10, 6),
        padding: const EdgeInsetsDirectional.fromSTEB(12, 10, 8, 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(NexaShapes.large),
        ),
        child: _layout(
          context,
          icon: Icon(icon, color: iconColor, size: 20),
          text: Text(
            message,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: fg),
          ),
          action: actionLabel != null && onAction != null
              ? TextButton(
                  onPressed: onAction,
                  style: TextButton.styleFrom(
                    foregroundColor: tone == NexaBannerTone.error
                        ? scheme.error
                        : scheme.primary,
                  ),
                  child: Text(actionLabel!),
                )
              : null,
        ),
      ),
    );
  }

  /// One line (icon, message, action) normally; at large text the action
  /// moves under the message so nothing overflows.
  Widget _layout(
    BuildContext context, {
    required Widget icon,
    required Widget text,
    Widget? action,
  }) {
    final large = MediaQuery.textScalerOf(context).scale(10) >= 13;
    if (!large || action == null) {
      return Row(
        children: [
          icon,
          const SizedBox(width: 10),
          Expanded(child: text),
          ?action,
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            icon,
            const SizedBox(width: 10),
            Expanded(child: text),
          ],
        ),
        Align(alignment: AlignmentDirectional.centerEnd, child: action),
      ],
    );
  }
}
