import 'package:flutter/material.dart';
import 'package:nexa_ui/l10n/generated/nexa_localizations.dart';
import 'package:nexa_ui/src/theme/nexa_motion.dart';

/// Message input with a send/stop action button.
class NexaComposer extends StatefulWidget {
  const NexaComposer({
    required this.onSend,
    this.onStop,
    this.enabled = true,
    this.isGenerating = false,
    this.controller,
    this.focusNode,
    super.key,
  });

  /// Called with trimmed, non-empty text.
  final ValueChanged<String> onSend;

  /// Called when the user taps stop while [isGenerating].
  final VoidCallback? onStop;

  /// Whether input is accepted.
  final bool enabled;

  /// Shows the stop button instead of send.
  final bool isGenerating;

  final TextEditingController? controller;
  final FocusNode? focusNode;

  @override
  State<NexaComposer> createState() => _NexaComposerState();
}

class _NexaComposerState extends State<NexaComposer> {
  late final TextEditingController _controller =
      widget.controller ?? TextEditingController();
  late final FocusNode _focusNode = widget.focusNode ?? FocusNode();

  @override
  void dispose() {
    if (widget.controller == null) _controller.dispose();
    if (widget.focusNode == null) _focusNode.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty || !widget.enabled) return;
    widget.onSend(text);
    _controller.clear();
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = NexaLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                key: const Key('nexa_composer_field'),
                controller: _controller,
                focusNode: _focusNode,
                enabled: widget.enabled,
                minLines: 1,
                maxLines: 5,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _submit(),
                decoration: InputDecoration(hintText: l10n.composerHint),
              ),
            ),
            const SizedBox(width: 8),
            AnimatedSwitcher(
              duration: NexaMotion.of(context, NexaMotion.short),
              child: widget.isGenerating
                  ? IconButton.filledTonal(
                      key: const Key('nexa_composer_stop'),
                      tooltip: l10n.semanticsStopButton,
                      onPressed: widget.onStop,
                      icon: const Icon(Icons.stop_rounded),
                    )
                  : ValueListenableBuilder<TextEditingValue>(
                      valueListenable: _controller,
                      builder: (context, value, _) {
                        final canSend =
                            widget.enabled && value.text.trim().isNotEmpty;
                        return IconButton.filled(
                          key: const Key('nexa_composer_send'),
                          tooltip: l10n.semanticsSendButton,
                          onPressed: canSend ? _submit : null,
                          style: IconButton.styleFrom(
                            backgroundColor: canSend
                                ? scheme.primary
                                : scheme.surfaceContainerHighest,
                            foregroundColor: canSend
                                ? scheme.onPrimary
                                : scheme.onSurfaceVariant,
                          ),
                          icon: const Icon(Icons.arrow_upward_rounded),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
