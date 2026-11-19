import 'package:flutter/material.dart';
import 'package:nexa_sdk/src/features/history/nexa_history.dart';
import 'package:nexa_ui/nexa_ui.dart';

/// Conversation history (design D1): server pages when the service offers
/// history, otherwise the device's bounded UI cache (labelled as such),
/// with search over loaded items and the Data & privacy screen.
class NexaHistoryView extends StatefulWidget {
  const NexaHistoryView({
    required this.history,
    required this.deleteLocalMedia,
    this.onResume,
    super.key,
  });

  final NexaHistoryController history;
  final Future<int> Function() deleteLocalMedia;

  /// Continues a server conversation in the chat (null: not offered).
  final Future<void> Function(NexaHistoryEntry entry)? onResume;

  @override
  State<NexaHistoryView> createState() => _NexaHistoryViewState();
}

class _NexaHistoryViewState extends State<NexaHistoryView> {
  final _query = TextEditingController();
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    widget.history.refresh();
    _scroll.addListener(() {
      if (_scroll.position.extentAfter < 300) widget.history.loadMore();
    });
  }

  @override
  void dispose() {
    _query.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _openPrivacy() => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => nexaScoped(
        context,
        NexaDataPrivacyView(
          history: widget.history,
          deleteLocalMedia: widget.deleteLocalMedia,
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = NexaLocalizations.of(context);
    final theme = Theme.of(context);
    final h = widget.history;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.historyTitle),
        actions: [
          IconButton(
            key: const Key('nexa_history_privacy'),
            tooltip: l10n.dataPrivacyTitle,
            onPressed: _openPrivacy,
            icon: const Icon(Icons.shield_outlined),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: Listenable.merge([h, _query]),
        builder: (context, _) {
          final q = _query.text.trim().toLowerCase();
          final entries = [
            for (final e in h.entries)
              if (q.isEmpty ||
                  (e.displayTitle ?? '').toLowerCase().contains(q) ||
                  e.messages.any((m) => m.text.toLowerCase().contains(q)))
                e,
          ];
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: TextField(
                  key: const Key('nexa_history_search'),
                  controller: _query,
                  decoration: InputDecoration(
                    isDense: true,
                    prefixIcon: const Icon(Icons.search_rounded),
                    hintText: l10n.historySearch,
                  ),
                ),
              ),
              if (!h.serverBacked)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                  child: Text(
                    l10n.historyCacheNote,
                    key: const Key('nexa_history_local_note'),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              if (h.error != null)
                ListTile(
                  key: const Key('nexa_history_error'),
                  leading: const Icon(Icons.cloud_off_outlined),
                  title: Text(l10n.historyLoadFailed),
                  trailing: TextButton(
                    onPressed: h.loadMore,
                    child: Text(l10n.retry),
                  ),
                ),
              Expanded(
                child: entries.isEmpty && !h.loading
                    ? Center(
                        child: Text(
                          l10n.historyEmpty,
                          key: const Key('nexa_history_empty'),
                        ),
                      )
                    : ListView.builder(
                        key: const Key('nexa_history_list'),
                        controller: _scroll,
                        itemCount: entries.length + (h.loading ? 1 : 0),
                        itemBuilder: (context, i) {
                          if (i == entries.length) {
                            return const Padding(
                              padding: EdgeInsets.all(16),
                              child: Center(
                                child: CircularProgressIndicator(
                                  key: Key('nexa_history_loading'),
                                ),
                              ),
                            );
                          }
                          final e = entries[i];
                          final voice = e.kind == NexaHistoryKind.voice;
                          return ListTile(
                            key: Key('nexa_history_${e.id}'),
                            leading: Icon(
                              voice
                                  ? Icons.graphic_eq_rounded
                                  : Icons.chat_bubble_outline_rounded,
                            ),
                            title: Text(
                              e.displayTitle ??
                                  (voice
                                      ? l10n.historyVoice
                                      : l10n.historyUntitled),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              '${voice ? l10n.historyVoice : l10n.historyChat}'
                              ' · ${MaterialLocalizations.of(context).formatShortDate(e.updatedAt.toLocal())}'
                              ' · ${l10n.historyMessages(e.count)}',
                            ),
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => nexaScoped(
                                  context,
                                  NexaHistoryDetailView(
                                    history: h,
                                    entry: e,
                                    deleteLocalMedia: widget.deleteLocalMedia,
                                    onResume: widget.onResume,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// One conversation, read-only: messages from the server when it can open
/// conversations, else the cached copy. Continue and rename stay disabled
/// (with the reason) until the server supports them.
class NexaHistoryDetailView extends StatefulWidget {
  const NexaHistoryDetailView({
    required this.history,
    required this.entry,
    required this.deleteLocalMedia,
    this.onResume,
    super.key,
  });

  final NexaHistoryController history;
  final NexaHistoryEntry entry;
  final Future<int> Function() deleteLocalMedia;
  final Future<void> Function(NexaHistoryEntry entry)? onResume;

  @override
  State<NexaHistoryDetailView> createState() => _NexaHistoryDetailViewState();
}

class _NexaHistoryDetailViewState extends State<NexaHistoryDetailView> {
  late Future<List<NexaHistoryMessage>> _messages = widget.history.open(
    widget.entry,
  );
  late String? _title = widget.entry.displayTitle;

  Future<void> _rename() async {
    final l10n = NexaLocalizations.of(context);
    final controller = TextEditingController(text: _title);
    final title = await showDialog<String>(
      context: context,
      builder: (dialogContext) => nexaScoped(
        context,
        AlertDialog(
          title: Text(l10n.historyRename),
          content: TextField(
            key: const Key('nexa_history_rename_field'),
            controller: controller,
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              key: const Key('nexa_history_rename_save'),
              onPressed: () => Navigator.pop(dialogContext, controller.text),
              child: Text(l10n.historyRename),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    if (title == null) return;
    await widget.history.rename(widget.entry, title);
    if (mounted) setState(() => _title = title.trim());
  }

  Future<void> _delete() async {
    final nav = Navigator.of(context);
    final outcome = await showNexaDeletionFlow(
      context,
      widget.history,
      NexaDeletionScope.conversation,
      conversation: widget.entry,
      deleteLocalMedia: widget.deleteLocalMedia,
    );
    if (outcome != null) nav.pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = NexaLocalizations.of(context);
    final theme = Theme.of(context);
    final server = widget.history.server;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _title ?? l10n.historyUntitled,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            key: const Key('nexa_history_rename'),
            tooltip: server.canRename
                ? l10n.historyRename
                : l10n.historyRenameUnavailable,
            onPressed: server.canRename ? _rename : null,
            icon: const Icon(Icons.drive_file_rename_outline_rounded),
          ),
          IconButton(
            key: const Key('nexa_history_delete'),
            tooltip: l10n.scopeConversation,
            onPressed: _delete,
            icon: const Icon(Icons.delete_outline_rounded),
          ),
        ],
      ),
      body: FutureBuilder(
        future: _messages,
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(
              child: TextButton(
                onPressed: () => setState(
                  () => _messages = widget.history.open(widget.entry),
                ),
                child: Text('${l10n.historyLoadFailed} ${l10n.retry}'),
              ),
            );
          }
          final messages = snap.data ?? widget.entry.messages;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final m in messages)
                Align(
                  alignment: m.fromUser
                      ? AlignmentDirectional.centerEnd
                      : AlignmentDirectional.centerStart,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    constraints: const BoxConstraints(maxWidth: 320),
                    decoration: BoxDecoration(
                      color: m.fromUser
                          ? theme.colorScheme.primaryContainer
                          : theme.colorScheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Text(
                      m.text,
                      textDirection: nexaTextDirectionOf(m.text),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FilledButton(
                key: const Key('nexa_history_resume'),
                onPressed: server.canResume && widget.onResume != null
                    ? () => widget.onResume!(widget.entry)
                    : null,
                child: Text(l10n.historyResume),
              ),
              if (!server.canResume)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    l10n.historyResumeUnavailable,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Design E "Data & privacy": retention notice and the deletion scopes.
/// Each row says whether the server part is available.
class NexaDataPrivacyView extends StatelessWidget {
  const NexaDataPrivacyView({
    required this.history,
    required this.deleteLocalMedia,
    super.key,
  });

  final NexaHistoryController history;
  final Future<int> Function() deleteLocalMedia;

  static const _scopes = [
    (NexaDeletionScope.allChats, Icons.forum_outlined),
    (NexaDeletionScope.allVoice, Icons.record_voice_over_outlined),
    (NexaDeletionScope.assets, Icons.folder_outlined),
    (NexaDeletionScope.localCache, Icons.cleaning_services_outlined),
    (NexaDeletionScope.everything, Icons.delete_forever_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = NexaLocalizations.of(context);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.dataPrivacyTitle)),
      body: ListView(
        key: const Key('nexa_data_privacy'),
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            history.options.retentionNotice ?? l10n.retentionDefault,
            key: const Key('nexa_retention_notice'),
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          for (final (scope, icon) in _scopes)
            Card(
              child: ListTile(
                key: Key('nexa_scope_${scope.name}'),
                leading: Icon(
                  icon,
                  color: scope == NexaDeletionScope.everything
                      ? theme.colorScheme.error
                      : theme.colorScheme.primary,
                ),
                title: Text(nexaScopeLabel(l10n, scope)),
                subtitle:
                    scope != NexaDeletionScope.localCache &&
                        !history.server.supportsDeletion(scope)
                    ? Text(l10n.scopeServerUnavailable)
                    : null,
                onTap: () => showNexaDeletionFlow(
                  context,
                  history,
                  scope,
                  deleteLocalMedia: deleteLocalMedia,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

String nexaScopeLabel(NexaLocalizations l10n, NexaDeletionScope s) =>
    switch (s) {
      NexaDeletionScope.conversation => l10n.scopeConversation,
      NexaDeletionScope.allConversations => l10n.scopeAllConversations,
      NexaDeletionScope.allChats => l10n.scopeAllChats,
      NexaDeletionScope.allVoice => l10n.scopeAllVoice,
      NexaDeletionScope.assets => l10n.scopeAssets,
      NexaDeletionScope.localCache => l10n.scopeLocalCache,
      NexaDeletionScope.everything => l10n.scopeEverything,
    };

/// Confirm (scope + what is kept) → progress → result: removed locally,
/// server confirmed / requested with request id / partial failure with
/// retry / server not available. Returns null when cancelled **or** when
/// the sheet was dismissed without its Done button, so follow-up work that
/// must happen after a deletion belongs in [onDeleted]: it runs as soon as
/// the deletion ran, however the sheet is closed afterwards.
Future<NexaDeletionOutcome?> showNexaDeletionFlow(
  BuildContext context,
  NexaHistoryController history,
  NexaDeletionScope scope, {
  required Future<int> Function() deleteLocalMedia,
  NexaHistoryEntry? conversation,
  Future<void> Function(NexaDeletionOutcome outcome)? onDeleted,
}) => showModalBottomSheet<NexaDeletionOutcome>(
  context: context,
  isScrollControlled: true,
  builder: (_) => nexaScoped(
    context,
    _DeletionSheet(
      history: history,
      scope: scope,
      conversation: conversation,
      deleteLocalMedia: deleteLocalMedia,
      onDeleted: onDeleted,
    ),
  ),
);

class _DeletionSheet extends StatefulWidget {
  const _DeletionSheet({
    required this.history,
    required this.scope,
    required this.deleteLocalMedia,
    this.conversation,
    this.onDeleted,
  });

  final NexaHistoryController history;
  final NexaDeletionScope scope;
  final NexaHistoryEntry? conversation;
  final Future<int> Function() deleteLocalMedia;
  final Future<void> Function(NexaDeletionOutcome outcome)? onDeleted;

  @override
  State<_DeletionSheet> createState() => _DeletionSheetState();
}

enum _Step { confirm, working, result }

class _DeletionSheetState extends State<_DeletionSheet> {
  _Step _step = _Step.confirm;
  NexaDeletionOutcome? _outcome;

  Future<void> _run({bool retry = false}) async {
    setState(() => _step = _Step.working);
    final o = retry
        ? await widget.history.retryServer(
            widget.scope,
            conversation: widget.conversation,
          )
        : await widget.history.delete(
            widget.scope,
            conversation: widget.conversation,
            deleteLocalMedia: widget.deleteLocalMedia,
          );
    // Before the mounted check: the sheet may already be dismissed.
    if (!retry) await widget.onDeleted?.call(o);
    if (!mounted) return;
    setState(() {
      final previous = _outcome;
      _outcome = retry && previous != null
          ? NexaDeletionOutcome(
              scope: o.scope,
              localRemoved: previous.localRemoved,
              serverAvailable: o.serverAvailable,
              server: o.server,
              serverError: o.serverError,
            )
          : o;
      _step = _Step.result;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = NexaLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colors = NexaColors.of(context);
    final note = switch (widget.scope) {
      NexaDeletionScope.localCache => l10n.scopeNoteLocalCache,
      NexaDeletionScope.everything => l10n.scopeNoteEverything,
      NexaDeletionScope.allConversations => l10n.scopeNoteAllConversations,
      _ => l10n.scopeNoteDefault,
    };
    final title = nexaScopeLabel(l10n, widget.scope);
    final o = _outcome;
    final List<Widget> body;
    final List<Widget> actions;
    switch (_step) {
      case _Step.confirm:
        body = [
          Text(note, key: const Key('nexa_deletion_note')),
          if (widget.scope != NexaDeletionScope.localCache &&
              !widget.history.server.supportsDeletion(widget.scope)) ...[
            const SizedBox(height: 8),
            Text(
              l10n.scopeServerUnavailable,
              style: theme.textTheme.bodySmall?.copyWith(color: colors.warning),
            ),
          ],
        ];
        actions = [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            key: const Key('nexa_deletion_confirm'),
            style: FilledButton.styleFrom(
              backgroundColor: scheme.error,
              foregroundColor: scheme.onError,
            ),
            onPressed: _run,
            child: Text(l10n.deleteAction),
          ),
        ];
      case _Step.working:
        body = [
          Text(l10n.deletionWorking),
          const SizedBox(height: 12),
          const LinearProgressIndicator(key: Key('nexa_deletion_progress')),
        ];
        actions = const [];
      case _Step.result:
        final receipt = o?.server;
        final String serverLine;
        final Color serverColor;
        var canRetry = false;
        if (widget.scope == NexaDeletionScope.localCache) {
          serverLine = l10n.scopeNoteLocalCache;
          serverColor = scheme.onSurfaceVariant;
        } else if (o == null || !o.serverAvailable) {
          serverLine = l10n.deletionServerUnavailable;
          serverColor = colors.warning;
        } else if (o.serverError != null || receipt == null) {
          serverLine = l10n.deletionServerFailed;
          serverColor = scheme.error;
          canRetry = true;
        } else {
          (serverLine, serverColor) = switch (receipt.state) {
            NexaDeletionState.completed => (
              l10n.deletionConfirmed,
              colors.success,
            ),
            NexaDeletionState.requested || NexaDeletionState.running => (
              l10n.deletionRequested,
              colors.warning,
            ),
            NexaDeletionState.partial => (
              l10n.deletionPartial(receipt.failedItems),
              colors.warning,
            ),
            NexaDeletionState.failed => (
              l10n.deletionServerFailed,
              scheme.error,
            ),
          };
          canRetry =
              receipt.retryable &&
              (receipt.state == NexaDeletionState.partial ||
                  receipt.state == NexaDeletionState.failed);
        }
        body = [
          Row(
            children: [
              Icon(Icons.check_circle_outline, color: colors.success),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.deletionLocalDone,
                  key: const Key('nexa_deletion_local'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.cloud_outlined, color: serverColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(serverLine, key: const Key('nexa_deletion_server')),
              ),
            ],
          ),
          if (receipt?.requestId case final id?) ...[
            const SizedBox(height: 8),
            Text(
              l10n.deletionRequestId(id),
              key: const Key('nexa_deletion_request_id'),
              style: theme.textTheme.bodySmall,
            ),
          ],
        ];
        actions = [
          if (canRetry)
            TextButton(
              key: const Key('nexa_deletion_retry'),
              onPressed: () => _run(retry: true),
              child: Text(l10n.deletionRetry),
            ),
          FilledButton(
            key: const Key('nexa_deletion_done'),
            onPressed: () => Navigator.pop(context, o),
            child: Text(l10n.done),
          ),
        ];
    }
    return SafeArea(
      child: SingleChildScrollView(
        key: const Key('nexa_deletion_sheet'),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: scheme.error,
                  size: 28,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    l10n.deletionQuestion(title),
                    key: const Key('nexa_deletion_title'),
                    style: theme.textTheme.titleLarge,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...body,
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                for (final (i, a) in actions.indexed) ...[
                  if (i > 0) const SizedBox(width: 8),
                  a,
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
