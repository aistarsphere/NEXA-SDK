import 'dart:async';

import 'package:flutter/material.dart';
import 'package:nexa_sdk/src/features/history/nexa_history.dart';
import 'package:nexa_ui/nexa_ui.dart';

/// The conversation list: the root screen of an assistant that keeps one
/// persistent conversation history. Server pages (newest first) with pull
/// to refresh and infinite scroll; "New conversation" and "Call" are always
/// one tap away. Navigation stays with the host through the callbacks.
class NexaConversationListPage extends StatefulWidget {
  const NexaConversationListPage({
    required this.history,
    required this.onNew,
    required this.onOpen,
    this.onCall,
    this.onOpenSettings,
    this.title,
    super.key,
  });

  final NexaHistoryController history;

  /// Starts a new conversation (the host opens its chat).
  final VoidCallback onNew;

  /// Starts a call; null hides the Call actions.
  final VoidCallback? onCall;

  /// Opens [entry] (the host resumes it and shows the chat).
  final void Function(NexaHistoryEntry entry) onOpen;

  final VoidCallback? onOpenSettings;
  final Widget? title;

  @override
  State<NexaConversationListPage> createState() =>
      _NexaConversationListPageState();
}

class _NexaConversationListPageState extends State<NexaConversationListPage> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    unawaited(widget.history.refresh());
    _scroll.addListener(() {
      if (_scroll.position.extentAfter < 300) {
        unawaited(widget.history.loadMore());
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = NexaLocalizations.of(context);
    final h = widget.history;
    return Scaffold(
      appBar: AppBar(
        title: widget.title ?? Text(l10n.historyTitle),
        actions: [
          if (widget.onCall != null)
            IconButton(
              key: const Key('nexa_list_call'),
              tooltip: l10n.assistantLiveVoice,
              onPressed: widget.onCall,
              icon: const Icon(Icons.graphic_eq_rounded),
            ),
          if (widget.onOpenSettings != null)
            IconButton(
              key: const Key('nexa_list_settings'),
              tooltip: l10n.assistantSettings,
              onPressed: widget.onOpenSettings,
              icon: const Icon(Icons.tune_rounded),
            ),
          const SizedBox(width: 4),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('nexa_list_new'),
        heroTag: null, // an extended FAB overflows while hero-flying
        tooltip: l10n.assistantNewConversation,
        onPressed: widget.onNew,
        icon: const Icon(Icons.edit_square),
        label: Text(l10n.assistantNewConversation),
      ),
      body: ListenableBuilder(
        listenable: h,
        builder: (context, _) {
          final entries = h.entries;
          if (entries.isEmpty && h.error != null) {
            return _Message(
              key: const Key('nexa_list_error'),
              icon: Icons.cloud_off_outlined,
              text: l10n.historyLoadFailed,
              action: TextButton(
                key: const Key('nexa_list_retry'),
                onPressed: h.refresh,
                child: Text(l10n.retry),
              ),
            );
          }
          if (entries.isEmpty && !h.loading) {
            return _Message(
              key: const Key('nexa_list_empty'),
              icon: Icons.forum_outlined,
              text: l10n.listEmpty,
              action: Wrap(
                spacing: 12,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  FilledButton.icon(
                    key: const Key('nexa_list_empty_chat'),
                    onPressed: widget.onNew,
                    icon: const Icon(Icons.chat_bubble_outline_rounded),
                    label: Text(l10n.assistantStartChat),
                  ),
                  if (widget.onCall != null)
                    FilledButton.tonalIcon(
                      key: const Key('nexa_list_empty_call'),
                      onPressed: widget.onCall,
                      icon: const Icon(Icons.graphic_eq_rounded),
                      label: Text(l10n.assistantStartVoice),
                    ),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: h.refresh,
            child: ListView.builder(
              key: const Key('nexa_list'),
              controller: _scroll,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsetsDirectional.only(bottom: 88),
              itemCount: entries.length + (h.loading ? 1 : 0),
              itemBuilder: (context, i) {
                if (i == entries.length) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final e = entries[i];
                final voice = e.kind == NexaHistoryKind.voice;
                return ListTile(
                  key: Key('nexa_list_${e.id}'),
                  minVerticalPadding: 12,
                  leading: Icon(
                    voice
                        ? Icons.graphic_eq_rounded
                        : Icons.chat_bubble_outline_rounded,
                  ),
                  title: Text(
                    e.displayTitle ?? l10n.historyUntitled,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    '${MaterialLocalizations.of(context).formatShortDate(e.updatedAt.toLocal())}'
                    ' · ${l10n.historyMessages(e.count)}',
                  ),
                  onTap: () => widget.onOpen(e),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.text,
    required this.action,
    super.key,
  });
  final IconData icon;
  final String text;
  final Widget action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(text, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            action,
          ],
        ),
      ),
    );
  }
}
