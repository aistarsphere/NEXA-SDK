import 'package:flutter/material.dart';
import 'package:nexa_core/nexa_core.dart';
import 'package:nexa_sdk/src/features/dynamic_ui/nexa_ui_view.dart';
import 'package:nexa_sdk/src/features/media/nexa_conversation_media.dart';
import 'package:nexa_sdk/src/features/tools/labeeb_tool_call_card.dart';
import 'package:nexa_sdk/src/features/tools/labeeb_tool_calls.dart';
import 'package:nexa_ui/nexa_ui.dart';

/// Rich content of a live call (labeeb.sdk/1): the newest `nexa.ui/1`
/// document of the call and any tool call that needs the user or is still
/// running. Minimize / dismiss never touch the call; mic and audio
/// controls stay below.
class LabeebVoiceCompanion extends StatefulWidget {
  const LabeebVoiceCompanion({
    required this.media,
    required this.controller,
    this.openExternal,
    super.key,
  });

  final NexaConversationMedia media;
  final LabeebToolCallController controller;
  final NexaExternalOpener? openExternal;

  @override
  State<LabeebVoiceCompanion> createState() => _LabeebVoiceCompanionState();
}

class _LabeebVoiceCompanionState extends State<LabeebVoiceCompanion> {
  final Set<String> _dismissed = {};
  bool _minimized = false;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([widget.media, widget.controller]),
      builder: (context, _) {
        final items = widget.media.items
            .where((i) => i.surface == NexaItemSurface.voice)
            .toList();
        final doc = items
            .whereType<NexaUiDocumentItem>()
            .where((i) => !_dismissed.contains(i.id))
            .lastOrNull;
        final calls = [
          for (final i in items.whereType<NexaToolCallItem>())
            if (widget.controller.activity(i.toolCallId) case final a?
                when !a.call.status.terminal && !_dismissed.contains(i.id))
              i,
        ];
        if (doc == null && calls.isEmpty) return const SizedBox.shrink();
        final l10n = NexaLocalizations.of(context);
        final theme = Theme.of(context);
        final title = doc == null
            ? labeebToolTitle(
                l10n,
                widget.controller.activity(calls.last.toolCallId)!.call.tool,
              )
            : widget.controller
                      .document(doc.uiId)
                      ?.titleFor(
                        Localizations.localeOf(context).languageCode,
                      ) ??
                  '';
        return Padding(
          key: const Key('labeeb_voice_companion'),
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
          child: Material(
            color: theme.colorScheme.surfaceContainerLow,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: theme.colorScheme.outlineVariant),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelLarge,
                      ),
                    ),
                    IconButton(
                      key: const Key('labeeb_companion_toggle'),
                      tooltip: _minimized ? l10n.duiExpand : l10n.duiMinimize,
                      onPressed: () => setState(() => _minimized = !_minimized),
                      icon: Icon(
                        _minimized
                            ? Icons.expand_less_rounded
                            : Icons.expand_more_rounded,
                      ),
                    ),
                    if (doc != null)
                      IconButton(
                        key: const Key('labeeb_companion_open'),
                        tooltip: l10n.duiOpen,
                        onPressed: () => showNexaUi(
                          context,
                          widget.controller,
                          doc.uiId,
                          openExternal: widget.openExternal,
                          as: NexaUiPresentation.fullscreen,
                        ),
                        icon: const Icon(Icons.open_in_full_rounded),
                      ),
                    IconButton(
                      key: const Key('labeeb_companion_dismiss'),
                      tooltip: l10n.duiDismiss,
                      onPressed: () => setState(() {
                        if (doc != null) _dismissed.add(doc.id);
                        // Calls needing approval stay: the user must answer.
                        for (final c in calls) {
                          final a = widget.controller.activity(c.toolCallId);
                          if (a?.call.status !=
                              NexaToolCallStatus.awaitingApproval) {
                            _dismissed.add(c.id);
                          }
                        }
                      }),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                if (!_minimized)
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.sizeOf(context).height * 0.42,
                    ),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (final c in calls) ...[
                            LabeebToolCallCard(
                              toolCallId: c.toolCallId,
                              controller: widget.controller,
                              openExternal: widget.openExternal,
                              compact: true,
                            ),
                            const SizedBox(height: 8),
                          ],
                          if (doc != null)
                            NexaUiView(
                              uiId: doc.uiId,
                              controller: widget.controller,
                              openExternal: widget.openExternal,
                              compact: true,
                              onDismiss: () =>
                                  setState(() => _dismissed.add(doc.id)),
                            ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
