import 'package:flutter/material.dart';
import 'package:nexa_core/nexa_core.dart';
import 'package:nexa_ui/l10n/generated/nexa_localizations.dart';
import 'package:nexa_ui/src/components/nexa_streaming_caret.dart';
import 'package:nexa_ui/src/components/nexa_typing_indicator.dart';
import 'package:nexa_ui/src/theme/nexa_colors.dart';
import 'package:nexa_ui/src/theme/nexa_motion.dart';
import 'package:nexa_ui/src/theme/nexa_shapes.dart';

/// A chat bubble for one [ChatMessage]. Tool results are rendered separately
/// by `NexaToolResultCard`; this widget only shows text and status.
class NexaMessageBubble extends StatelessWidget {
  const NexaMessageBubble({required this.message, this.onRetry, super.key});

  final ChatMessage message;

  /// Shown for failed, retryable user messages.
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = NexaLocalizations.of(context);
    final colors = NexaColors.of(context);
    final theme = Theme.of(context);
    final isUser = message.role == MessageRole.user;
    final background = isUser ? colors.userBubble : colors.assistantBubble;
    final foreground = isUser ? colors.onUserBubble : colors.onAssistantBubble;
    final showTyping = message.isInProgress && message.text.isEmpty;
    final alignment = isUser
        ? AlignmentDirectional.centerEnd
        : AlignmentDirectional.centerStart;

    final semanticsLabel = isUser
        ? l10n.semanticsUserMessage(message.text)
        : l10n.semanticsAssistantMessage(message.text);

    final textStyle = theme.textTheme.bodyLarge?.copyWith(color: foreground);
    final Widget body;
    if (showTyping) {
      body = NexaTypingIndicator(color: foreground);
    } else if (message.isInProgress) {
      // Streaming: text plus a caret so partial delivery is visible.
      body = Text.rich(
        TextSpan(
          text: message.text,
          children: [
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: NexaStreamingCaret(color: foreground),
            ),
          ],
        ),
        style: textStyle,
      );
    } else {
      body = Text(message.text, style: textStyle);
    }

    return Align(
      alignment: alignment,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.82,
        ),
        child: Column(
          crossAxisAlignment: isUser
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(
              label: showTyping ? null : semanticsLabel,
              excludeSemantics: !showTyping,
              child: AnimatedContainer(
                duration: NexaMotion.of(context, NexaMotion.short),
                curve: NexaMotion.standard,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: background,
                  borderRadius: isUser
                      ? NexaShapes.userBubble
                      : NexaShapes.assistantBubble,
                ),
                child: body,
              ),
            ),
            _StatusRow(message: message, onRetry: onRetry),
          ],
        ),
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({required this.message, this.onRetry});

  final ChatMessage message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = NexaLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final style = Theme.of(context).textTheme.labelSmall;

    switch (message.status) {
      case MessageStatus.failed:
        return Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 16, color: scheme.error),
              const SizedBox(width: 4),
              Text(
                message.role == MessageRole.user
                    ? l10n.messageFailed
                    : l10n.sessionError,
                style: style?.copyWith(color: scheme.error),
              ),
              if (message.retryable && onRetry != null)
                TextButton(
                  onPressed: onRetry,
                  style: TextButton.styleFrom(
                    minimumSize: const Size(48, 32),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  child: Text(l10n.retry),
                ),
            ],
          ),
        );
      case MessageStatus.cancelled:
        return Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            l10n.messageCancelled,
            style: style?.copyWith(color: scheme.onSurfaceVariant),
          ),
        );
      case MessageStatus.pending:
        return Padding(
          padding: const EdgeInsets.only(top: 4),
          child: SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              color: scheme.onSurfaceVariant,
            ),
          ),
        );
      case MessageStatus.sent:
      case MessageStatus.streaming:
      case MessageStatus.completed:
        return const SizedBox.shrink();
    }
  }
}
