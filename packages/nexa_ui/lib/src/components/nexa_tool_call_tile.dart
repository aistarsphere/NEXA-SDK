import 'package:flutter/material.dart';
import 'package:nexa_core/nexa_core.dart';
import 'package:nexa_ui/l10n/generated/nexa_localizations.dart';
import 'package:nexa_ui/src/theme/nexa_shapes.dart';

/// Shows a tool call that is requested, awaiting confirmation or running.
/// Once a result arrives, `NexaToolResultCard` takes over.
class NexaToolCallTile extends StatelessWidget {
  const NexaToolCallTile({required this.toolCall, super.key});

  final ToolCallState toolCall;

  @override
  Widget build(BuildContext context) {
    final l10n = NexaLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final status = toolCall.status;
    final (label, leading) = switch (status) {
      ToolExecutionStatus.requested || ToolExecutionStatus.running => (
        toolCall.statusMessage ?? l10n.toolRunning,
        SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            value: toolCall.progress,
          ),
        ),
      ),
      ToolExecutionStatus.awaitingConfirmation => (
        toolCall.request.displayTitle,
        Icon(Icons.pending_outlined, size: 18, color: scheme.onSurfaceVariant),
      ),
      ToolExecutionStatus.failed => (
        l10n.toolFailed,
        Icon(Icons.error_outline, size: 18, color: scheme.error),
      ),
      ToolExecutionStatus.cancelled => (
        l10n.toolCancelled,
        Icon(Icons.block, size: 18, color: scheme.onSurfaceVariant),
      ),
      ToolExecutionStatus.succeeded => (
        toolCall.request.displayTitle,
        Icon(Icons.check_circle_outline, size: 18, color: scheme.primary),
      ),
    };
    return Semantics(
      liveRegion: status == ToolExecutionStatus.running,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: scheme.surfaceContainer,
          borderRadius: NexaShapes.pill,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            leading,
            const SizedBox(width: 10),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(toolCall.request.displayTitle, style: text.labelLarge),
                  if (label != toolCall.request.displayTitle)
                    Text(
                      label,
                      style: text.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
