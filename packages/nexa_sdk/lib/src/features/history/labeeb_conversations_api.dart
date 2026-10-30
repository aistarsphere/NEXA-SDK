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

  @override
  Future<NexaDeletionReceipt> deletionStatus(String requestId) async =>
      const NexaDeletionReceipt(state: NexaDeletionState.completed);
}
