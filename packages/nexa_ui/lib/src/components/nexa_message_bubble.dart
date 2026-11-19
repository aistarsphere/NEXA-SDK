import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nexa_core/nexa_core.dart';
import 'package:nexa_ui/l10n/generated/nexa_localizations.dart';
import 'package:nexa_ui/src/components/nexa_rich_text.dart';
import 'package:nexa_ui/src/components/nexa_streaming_caret.dart';
import 'package:nexa_ui/src/components/nexa_typing_indicator.dart';
import 'package:nexa_ui/src/theme/nexa_colors.dart';
import 'package:nexa_ui/src/theme/nexa_motion.dart';

/// One [ChatMessage]. Tool results are rendered separately by
/// `NexaToolResultCard`; this widget only shows text and status.
///
/// Design (NEXA Assistant Phone): the user's message is a primary-colour
/// bubble with a tucked end corner; the assistant's reply is unboxed rich
/// text with a copy action once it is complete. Each message takes its text
/// direction from its content, not from the UI language.
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
    final showTyping = message.isInProgress && message.text.isEmpty;
    final width = MediaQuery.sizeOf(context).width;

    final semanticsLabel = isUser
        ? l10n.semanticsUserMessage(message.text)
        : l10n.semanticsAssistantMessage(message.text);

    final Widget content;
    if (isUser) {
      content = Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: colors.userBubble,
          borderRadius: const BorderRadiusDirectional.only(
            topStart: Radius.circular(22),
            topEnd: Radius.circular(22),
            bottomStart: Radius.circular(22),
            bottomEnd: Radius.circular(6),
          ),
        ),
        child: Text(
          message.text,
          textDirection: nexaTextDirectionOf(message.text),
          style: theme.textTheme.bodyLarge?.copyWith(
            color: colors.onUserBubble,
          ),
        ),
      );
    } else if (showTyping) {
      content = Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: NexaTypingIndicator(color: theme.colorScheme.onSurfaceVariant),
      );
    } else {
      content = NexaRichText(
        message.text,
        style: theme.textTheme.bodyLarge?.copyWith(
          color: message.status == MessageStatus.cancelled
              ? theme.colorScheme.onSurfaceVariant
              : theme.colorScheme.onSurface,
        ),
        trailing: message.isInProgress
            ? NexaStreamingCaret(color: theme.colorScheme.primary)
            : null,
      );
    }

    return Align(
      alignment: isUser
          ? AlignmentDirectional.centerEnd
          : AlignmentDirectional.centerStart,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: width * (isUser ? 0.82 : 0.92)),
        child: Column(
          crossAxisAlignment: isUser
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(
              label: showTyping ? null : semanticsLabel,
              excludeSemantics: !showTyping,
              child: AnimatedSize(
                duration: NexaMotion.of(context, NexaMotion.short),
                curve: NexaMotion.standard,
                alignment: AlignmentDirectional.topStart,
                child: content,
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
    final isUser = message.role == MessageRole.user;

    switch (message.status) {
      case MessageStatus.failed:
        return Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Container(
            padding: const EdgeInsetsDirectional.fromSTEB(12, 4, 4, 4),
            decoration: BoxDecoration(
              color: scheme.errorContainer,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_rounded, size: 18, color: scheme.error),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    isUser ? l10n.messageFailed : l10n.sessionError,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onErrorContainer,
                    ),
                  ),
                ),
                if (message.retryable && onRetry != null) ...[
                  const SizedBox(width: 4),
                  FilledButton(
                    onPressed: onRetry,
                    style: FilledButton.styleFrom(
                      backgroundColor: scheme.error,
                      foregroundColor: scheme.onError,
                      minimumSize: const Size(48, 36),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                    ),
                    child: Text(l10n.retry),
                  ),
                ] else
                  const SizedBox(width: 8),
              ],
            ),
          ),
        );
      case MessageStatus.cancelled:
        return Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.stop_circle_outlined,
                size: 16,
                color: scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Text(
                l10n.messageCancelled,
                style: style?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
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
      case MessageStatus.completed:
        if (isUser || message.text.isEmpty) return const SizedBox.shrink();
        // Under the start of the text, which follows the reply's language.
        return Directionality(
          textDirection:
              nexaTextDirectionOf(message.text) ?? Directionality.of(context),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: _CopyButton(text: message.text),
          ),
        );
      case MessageStatus.sent:
      case MessageStatus.streaming:
        return const SizedBox.shrink();
    }
  }
}

class _CopyButton extends StatefulWidget {
  const _CopyButton({required this.text});
  final String text;

  @override
  State<_CopyButton> createState() => _CopyButtonState();
}

class _CopyButtonState extends State<_CopyButton> {
  bool _copied = false;
  Timer? _reset;

  @override
  void dispose() {
    _reset?.cancel();
    super.dispose();
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.text));
    if (!mounted) return;
    setState(() => _copied = true);
    _reset?.cancel();
    _reset = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = NexaLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      // Optically align the icon with the text start (design: -10px).
      padding: const EdgeInsetsDirectional.only(top: 2),
      child: Transform.translate(
        offset: Offset(
          Directionality.of(context) == TextDirection.rtl ? 10 : -10,
          0,
        ),
        child: IconButton(
          key: const Key('nexa_message_copy'),
          tooltip: _copied ? l10n.messageCopied : l10n.messageCopy,
          onPressed: _copy,
          iconSize: 18,
          color: _copied
              ? NexaColors.of(context).success
              : scheme.onSurfaceVariant,
          icon: Icon(
            _copied ? Icons.check_rounded : Icons.content_copy_rounded,
          ),
        ),
      ),
    );
  }
}
