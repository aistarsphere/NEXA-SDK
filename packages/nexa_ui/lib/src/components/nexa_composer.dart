import 'package:flutter/material.dart';
import 'package:nexa_ui/l10n/generated/nexa_localizations.dart';
import 'package:nexa_ui/src/components/nexa_rich_text.dart';
import 'package:nexa_ui/src/theme/nexa_motion.dart';

/// Message input with a send/stop action button.
///
/// Design (NEXA Assistant Phone): a 52 dp pill field with an optional
/// in-field voice button, and a separate 52 dp round send button that turns
/// into a squarer inverse "stop" button while a reply is generating.
class NexaComposer extends StatefulWidget {
  const NexaComposer({
    required this.onSend,
    this.onStop,
    this.onVoice,
    this.onAttach,
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

  /// When set, a voice button inside the field starts a live voice
  /// conversation (the host decides how to present it).
  final VoidCallback? onVoice;

  /// When set, an attach button before the field opens the host/SDK
  /// attachment menu (photo, library, location).
  final VoidCallback? onAttach;

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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final duration = NexaMotion.of(context, NexaMotion.medium);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
        child: ValueListenableBuilder<TextEditingValue>(
          valueListenable: _controller,
          builder: (context, value, _) {
            final hasText = value.text.trim().isNotEmpty;
            final canSend = widget.enabled && hasText;
            return Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (widget.onAttach != null) ...[
                  SizedBox(
                    width: 44,
                    height: 52,
                    child: IconButton(
                      key: const Key('nexa_composer_attach'),
                      tooltip: l10n.attachButton,
                      onPressed: widget.enabled ? widget.onAttach : null,
                      icon: const Icon(Icons.add_circle_outline_rounded),
                    ),
                  ),
                  const SizedBox(width: 2),
                ],
                Expanded(
                  child: AnimatedOpacity(
                    duration: duration,
                    opacity: widget.enabled ? 1 : 0.5,
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 52),
                      padding: EdgeInsetsDirectional.only(
                        start: 18,
                        end: widget.onVoice == null ? 18 : 4,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(26),
                      ),
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
                              textDirection: nexaTextDirectionOf(value.text),
                              onSubmitted: (_) => _submit(),
                              style: theme.textTheme.bodyLarge,
                              decoration: InputDecoration(
                                hintText: l10n.composerHint,
                                filled: false,
                                isDense: true,
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                disabledBorder: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 15,
                                ),
                              ),
                            ),
                          ),
                          if (widget.onVoice != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: IconButton(
                                key: const Key('nexa_composer_voice'),
                                tooltip: l10n.composerLiveVoice,
                                onPressed:
                                    widget.enabled && !widget.isGenerating
                                    ? widget.onVoice
                                    : null,
                                icon: const Icon(Icons.graphic_eq_rounded),
                                color: scheme.onSurface,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (widget.isGenerating)
                  _RoundAction(
                    key: const Key('nexa_composer_stop'),
                    tooltip: l10n.semanticsStopButton,
                    onPressed: widget.onStop,
                    radius: 18,
                    background: scheme.inverseSurface,
                    foreground: scheme.onInverseSurface,
                    icon: Icons.stop_rounded,
                  )
                else
                  _RoundAction(
                    key: const Key('nexa_composer_send'),
                    tooltip: l10n.semanticsSendButton,
                    onPressed: canSend ? _submit : null,
                    radius: 26,
                    background: canSend
                        ? scheme.primary
                        : scheme.surfaceContainerHigh,
                    foreground: canSend
                        ? scheme.onPrimary
                        : scheme.onSurfaceVariant,
                    icon: Icons.arrow_upward_rounded,
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// 52 dp square-ish action whose corner radius and colours animate between
/// states (Material 3 Expressive shape morph).
class _RoundAction extends StatelessWidget {
  const _RoundAction({
    required this.tooltip,
    required this.onPressed,
    required this.radius,
    required this.background,
    required this.foreground,
    required this.icon,
    super.key,
  });

  final String tooltip;
  final VoidCallback? onPressed;
  final double radius;
  final Color background;
  final Color foreground;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final duration = NexaMotion.of(context, NexaMotion.medium);
    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: tooltip,
      excludeSemantics: true,
      child: Tooltip(
        message: tooltip,
        child: AnimatedContainer(
          duration: duration,
          curve: NexaMotion.emphasized,
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(radius),
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              borderRadius: BorderRadius.circular(radius),
              onTap: onPressed,
              child: Icon(icon, color: foreground),
            ),
          ),
        ),
      ),
    );
  }
}
