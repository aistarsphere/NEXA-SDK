import 'package:flutter/material.dart';
import 'package:nexa_ui/l10n/generated/nexa_localizations.dart';
import 'package:nexa_ui/src/theme/nexa_colors.dart';

/// Where a tool runs (design "origin tag").
enum NexaToolOrigin { device, server, company }

/// The shared tool-card states (design "Tool card system").
enum NexaToolCardState {
  approval,
  denied,
  running,
  success,
  error,
  cancelled,
  unavailable,
  setup,
}

@immutable
final class NexaToolCardAction {
  const NexaToolCardAction(
    this.label,
    this.onPressed, {
    this.primary = false,
    this.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool primary;
  final Key? key;
}

/// One card anatomy for every tool: header (icon, name, origin tag, status
/// chip), message, optional progress with step text, result rows (slot),
/// action row. Device, server and company tools reuse the same shell.
class NexaToolCard extends StatelessWidget {
  const NexaToolCard({
    required this.icon,
    required this.name,
    required this.origin,
    required this.state,
    required this.message,
    this.where,
    this.progress,
    this.stepText,
    this.rows = const [],
    this.body,
    this.actions = const [],
    super.key,
  });

  final IconData icon;
  final String name;
  final NexaToolOrigin origin;
  final NexaToolCardState state;
  final String message;

  /// Subtitle under the name (e.g. "Runs on this device").
  final String? where;

  /// 0..1, or null for an indeterminate bar while [NexaToolCardState.running].
  final double? progress;
  final String? stepText;

  /// Structured result as key/value rows.
  final List<(String, String)> rows;

  /// Custom result body (slot), shown after [rows].
  final Widget? body;
  final List<NexaToolCardAction> actions;

  @override
  Widget build(BuildContext context) {
    final l10n = NexaLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colors = NexaColors.of(context);
    final (chipBg, chipFg) = switch (state) {
      NexaToolCardState.approval ||
      NexaToolCardState.setup => (colors.warningContainer, colors.warning),
      NexaToolCardState.denied || NexaToolCardState.error => (
        scheme.errorContainer,
        scheme.onErrorContainer,
      ),
      NexaToolCardState.running => (colors.infoContainer, colors.info),
      NexaToolCardState.success => (colors.successContainer, colors.success),
      NexaToolCardState.cancelled || NexaToolCardState.unavailable => (
        scheme.surfaceContainerHighest,
        scheme.onSurfaceVariant,
      ),
    };
    final stateLabel = switch (state) {
      NexaToolCardState.approval => l10n.toolStateApproval,
      NexaToolCardState.denied => l10n.toolStateDenied,
      NexaToolCardState.running => l10n.toolStateRunning,
      NexaToolCardState.success => l10n.toolStateSuccess,
      NexaToolCardState.error => l10n.toolStateError,
      NexaToolCardState.cancelled => l10n.toolStateCancelled,
      NexaToolCardState.unavailable => l10n.toolStateUnavailable,
      NexaToolCardState.setup => l10n.toolStateSetup,
    };
    final originLabel = switch (origin) {
      NexaToolOrigin.device => l10n.toolOriginDevice,
      NexaToolOrigin.server => l10n.toolOriginServer,
      NexaToolOrigin.company => l10n.toolOriginCompany,
    };
    return Semantics(
      container: true,
      liveRegion: true,
      label: '$name, $stateLabel',
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 20, color: scheme.onPrimaryContainer),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Wraps on narrow phones instead of overflowing.
                      Wrap(
                        spacing: 6,
                        runSpacing: 2,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            name,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall,
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: colors.infoContainer,
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text(
                              originLabel,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: colors.info,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (where != null)
                        Text(
                          where!,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Container(
                    key: Key('nexa_tool_state_${state.name}'),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: chipBg,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      stateLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: chipFg,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              message,
              key: const Key('nexa_tool_message'),
              style: theme.textTheme.bodyMedium,
            ),
            if (state == NexaToolCardState.running) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(minHeight: 6, value: progress),
              ),
              if (stepText != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    stepText!,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
            if (rows.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                key: const Key('nexa_tool_rows'),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: [
                    for (final (k, v) in rows)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 96,
                              child: Text(
                                k,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                v,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
            if (body != null) ...[const SizedBox(height: 10), body!],
            if (actions.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final a in actions)
                    a.primary
                        ? FilledButton(
                            key: a.key,
                            onPressed: a.onPressed,
                            child: Text(a.label),
                          )
                        : OutlinedButton(
                            key: a.key,
                            onPressed: a.onPressed,
                            child: Text(a.label),
                          ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
