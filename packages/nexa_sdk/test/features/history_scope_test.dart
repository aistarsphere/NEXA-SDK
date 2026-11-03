// Plan B-02: the local cache is keyed by the server conversation (conv_*),
// holds no vs_* voice rows when the server owns history, and is scoped per
// account.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nexa_sdk/nexa_sdk.dart';

import 'history_identity_test.dart' show FakeConversationsApi;

NexaHistoryEntry row(
  String id, {
  NexaHistoryKind kind = NexaHistoryKind.chat,
}) => NexaHistoryEntry(
  id: 'h_$id',
  kind: kind,
  sessionId: id,
  startedAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
  messages: [
    NexaHistoryMessage(fromUser: true, text: 'q', at: DateTime.utc(2026)),
  ],
);

ConversationState chat(String sessionId) => ConversationState(
  sessionId: SessionId(sessionId),
  messages: [
    ChatMessage(
      id: const MessageId('m1'),
      role: MessageRole.user,
      status: MessageStatus.sent,
      createdAt: DateTime.utc(2026),
      text: 'hello',
    ),
  ],
);

final voiceLines = [
  VoiceTranscriptEntry(
    speaker: VoiceSpeaker.user,
    text: 'hi',
    isFinal: true,
    at: DateTime.utc(2026),
  ),
];

void main() {
  late InMemoryHistoryStore cache;

  NexaHistoryController make({bool server = true}) => NexaHistoryController(
    NexaHistoryOptions(
      cache: cache,
      server: server
          ? FakeConversationsApi(0)
          : const UnavailableConversationsApi(),
    ),
  );

  setUp(() => cache = InMemoryHistoryStore());

  test(
    'chat is cached under the conversation id, not the session id',
    () async {
      final h = make();
      await h.recordChat(chat('ses_9'), conversationId: 'conv_1');
      expect(h.cachedEntries.map((e) => e.conversationId), ['conv_1']);
    },
  );

  test(
    'without a conversation id the session id keys the row (local only)',
    () async {
      final h = make(server: false);
      await h.recordChat(chat('ses_9'));
      expect(h.cachedEntries.map((e) => e.conversationId), ['ses_9']);
    },
  );

  test('a voice call adds no vs_ row when the server owns history', () async {
    final h = make();
    await h.recordVoice('vs_1', voiceLines, conversationId: 'conv_1');
    expect(h.cachedEntries, isEmpty);
  });

  test(
    'local-only voice goes under the conversation when known, else vs_',
    () async {
      final h = make(server: false);
      await h.recordVoice('vs_1', voiceLines, conversationId: 'conv_1');
      await h.recordVoice('vs_2', voiceLines);
      expect(h.cachedEntries.map((e) => e.conversationId).toSet(), {
        'conv_1',
        'vs_2',
      });
    },
  );

  test(
    'legacy ses_/vs_ rows are dropped when the server owns history',
    () async {
      await cache.save([row('vs_a'), row('ses_b'), row('conv_c')]);
      final h = make();
      await h.refresh();
      expect(h.cachedEntries.map((e) => e.conversationId), ['conv_c']);
      expect((await cache.load()).map((e) => e.conversationId), ['conv_c']);
    },
  );

  test(
    'local-only caches keep their rows (they are the only record)',
    () async {
      await cache.save([row('vs_a'), row('ses_b')]);
      final h = make(server: false);
      await h.refresh();
      expect(h.cachedEntries, hasLength(2));
    },
  );

  group('per-account cache files', () {
    late Directory dir;
    setUp(() => dir = Directory.systemTemp.createTempSync('nexa_hist'));
    tearDown(() => dir.deleteSync(recursive: true));

    test('two accounts, two files, no leakage', () async {
      final a = JsonFileHistoryStore.forAccount(dir, 'alice@example.com');
      final b = JsonFileHistoryStore.forAccount(dir, 'bob@example.com');
      expect(a.file.path, isNot(b.file.path));
      await a.save([row('conv_a')]);
      expect(await b.load(), isEmpty);
      expect((await a.load()).single.conversationId, 'conv_a');
    });

    test('the file name does not contain the account key', () {
      final a = JsonFileHistoryStore.forAccount(dir, 'alice@example.com');
      expect(a.file.path, isNot(contains('alice')));
      expect(
        a.file.uri.pathSegments.last,
        matches(r'^history_[0-9a-f]{8}\.json$'),
      );
    });

    test('the same account always gets the same file', () {
      expect(
        JsonFileHistoryStore.forAccount(dir, 'x').file.path,
        JsonFileHistoryStore.forAccount(dir, 'x').file.path,
      );
    });
  });
}
