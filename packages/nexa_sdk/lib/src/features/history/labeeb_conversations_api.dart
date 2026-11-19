import 'package:nexa_core/nexa_core.dart';
import 'package:nexa_sdk/src/data/labeeb/labeeb_sdk_client.dart';
import 'package:nexa_sdk/src/features/history/nexa_history.dart';

/// Server-owned history of contract `labeeb.sdk/1` (`conversations.history`,
/// E2E_VERIFIED): list, open (message pages), rename and deletion that
/// cascades on the server. The local cache only mirrors it.
final class LabeebConversationsApi implements NexaConversationsApi {
  LabeebConversationsApi(this.api, {this.installationId});

  final LabeebSdkClient api;

  /// Lists only this installation's conversations when set.
  final String? installationId;

  @override
  bool get canList => true;
  @override
  bool get canOpen => true;
  @override
  bool get canResume => true;
  @override
  bool get canRename => true;

  @override
  bool supportsDeletion(NexaDeletionScope scope) => switch (scope) {
    NexaDeletionScope.conversation ||
    NexaDeletionScope.allConversations ||
    NexaDeletionScope.allChats ||
    NexaDeletionScope.allVoice ||
    NexaDeletionScope.everything => true,
    // No asset-only bulk delete in the contract (per-asset DELETE only).
    NexaDeletionScope.assets || NexaDeletionScope.localCache => false,
  };

  @override
  Future<NexaHistoryPage> list({String? cursor, int limit = 20}) async {
    final page = await api.conversations(
      cursor: cursor,
      limit: limit,
      installation: installationId,
    );
    return NexaHistoryPage([
      for (final c in page.items)
        NexaHistoryEntry(
          id: c.id,
          kind: switch (c.kind) {
            'voice' => NexaHistoryKind.voice,
            'mixed' => NexaHistoryKind.mixed,
            _ => NexaHistoryKind.chat,
          },
          // The conversation id is what resume and open use.
          sessionId: c.id,
          startedAt: c.createdAt ?? DateTime.now().toUtc(),
          updatedAt: c.lastMessageAt ?? c.updatedAt ?? DateTime.now().toUtc(),
          title: c.title,
          messageCount: c.messageCount,
          fromCache: false,
        ),
    ], nextCursor: page.nextCursor);
  }

  /// All text messages, oldest first (pages back with `before_seq`).
  @override
  Future<List<NexaHistoryMessage>> open(String conversationId) async {
    final out = <NexaHistoryMessage>[];
    int? before;
    for (var page = 0; page < 10; page++) {
      final p = await api.messages(
        conversationId,
        limit: 100,
        beforeSeq: before,
      );
      out.insertAll(0, [
        for (final m in p.items)
          if (m.text.isNotEmpty)
            NexaHistoryMessage(
              fromUser: m.fromUser,
              text: m.text,
              at: m.createdAt ?? DateTime.now().toUtc(),
            ),
      ]);
      before = p.nextBefore;
      if (before == null) break;
    }
    return out;
  }

  @override
  Future<void> rename(String conversationId, String title) =>
      api.renameConversation(conversationId, title);

  @override
  Future<NexaDeletionReceipt> delete(
    NexaDeletionScope scope, {
    String? conversationId,
  }) async {
    switch (scope) {
      case NexaDeletionScope.conversation:
        await api.deleteConversation(conversationId!);
      case NexaDeletionScope.allConversations:
        // The list shows only this installation's conversations when the
        // filter is set, so only those are deleted; otherwise the whole
        // history of the account is cleared in one request.
        if (installationId != null) return _deleteListed();
        await api.clearConversations();
      case NexaDeletionScope.allChats:
        await api.clearConversations(kind: 'chat');
      case NexaDeletionScope.allVoice:
        await api.clearConversations(kind: 'voice');
      case NexaDeletionScope.everything:
        await api.deleteAssistantData();
      case NexaDeletionScope.assets || NexaDeletionScope.localCache:
        throw const NexaFeatureUnavailable('deletion');
    }
    // The gateway deletes synchronously and reports the counts.
    return const NexaDeletionReceipt(state: NexaDeletionState.completed);
  }

  /// Deletes this installation's conversations one by one (the first page
  /// again after each pass). Rows that fail are reported as partial and
  /// retryable.
  Future<NexaDeletionReceipt> _deleteListed() async {
    final failed = <String>{};
    for (var pass = 0; pass < 100; pass++) {
      final p = await api.conversations(
        limit: 50,
        installation: installationId,
      );
      final todo = [
        for (final c in p.items)
          if (!failed.contains(c.id)) c.id,
      ];
      // Only rows that already failed are left (or nothing at all).
      if (todo.isEmpty) break;
      for (final id in todo) {
        try {
          await api.deleteConversation(id);
        } on NexaException {
          failed.add(id);
        }
      }
    }
    return failed.isEmpty
        ? const NexaDeletionReceipt(state: NexaDeletionState.completed)
        : NexaDeletionReceipt(
            state: NexaDeletionState.partial,
            failedItems: failed.length,
            retryable: true,
          );
  }

  @override
  Future<NexaDeletionReceipt> deletionStatus(String requestId) async =>
      const NexaDeletionReceipt(state: NexaDeletionState.completed);
}
