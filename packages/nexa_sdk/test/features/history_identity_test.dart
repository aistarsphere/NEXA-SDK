import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexa_sdk/nexa_sdk.dart';

/// Stands in for the future AWS history API (no such API exists today).
final class FakeConversationsApi implements NexaConversationsApi {
  FakeConversationsApi(this.total);
  final int total;
  final listCalls = <String?>[];
  final deletions = <NexaDeletionScope>[];
  final renamed = <String, String>{};
  int deleteAttempts = 0;

  NexaHistoryEntry _entry(int i) => NexaHistoryEntry(
    id: 'srv_$i',
    kind: i.isEven ? NexaHistoryKind.chat : NexaHistoryKind.voice,
    sessionId: 'ses_$i',
    startedAt: DateTime.utc(2026, 1, 1).add(Duration(minutes: i)),
    updatedAt: DateTime.utc(2026, 1, 1).add(Duration(minutes: i)),
    title: 'Conversation $i',
    messageCount: i,
  );

  @override
  bool get canList => true;
  @override
  bool get canOpen => true;
  @override
  bool get canResume => false;
  @override
  bool get canRename => true;
  @override
  bool supportsDeletion(NexaDeletionScope scope) => true;

  @override
  Future<NexaHistoryPage> list({String? cursor, int limit = 20}) async {
    listCalls.add(cursor);
    final start = cursor == null ? 0 : int.parse(cursor);
    final end = min(start + limit, total);
    return NexaHistoryPage([
      for (var i = start; i < end; i++) _entry(total - i),
    ], nextCursor: end < total ? '$end' : null);
  }

  @override
  Future<List<NexaHistoryMessage>> open(String conversationId) async => [
    NexaHistoryMessage(fromUser: true, text: 'q', at: DateTime.utc(2026)),
    NexaHistoryMessage(fromUser: false, text: 'a', at: DateTime.utc(2026)),
  ];

  @override
  Future<void> rename(String conversationId, String title) async =>
      renamed[conversationId] = title;

  @override
  Future<NexaDeletionReceipt> delete(
    NexaDeletionScope scope, {
    String? conversationId,
  }) async {
    deletions.add(scope);
    deleteAttempts++;
    // First attempt: partial failure; retry completes.
    return deleteAttempts == 1
        ? const NexaDeletionReceipt(
            state: NexaDeletionState.partial,
            requestId: 'del_2043',
            failedItems: 2,
            retryable: true,
          )
        : const NexaDeletionReceipt(
            state: NexaDeletionState.completed,
            requestId: 'del_2043',
          );
  }

  @override
  Future<NexaDeletionReceipt> deletionStatus(String requestId) async =>
      const NexaDeletionReceipt(state: NexaDeletionState.completed);
}

void main() {
  group('installation id', () {
    test('random, well-formed, persisted across restarts', () async {
      final dir = Directory.systemTemp.createTempSync('nexa_ins');
      addTearDown(() => dir.deleteSync(recursive: true));
      final store = FileInstallationIdStore(File('${dir.path}/id'));
      final first = await NexaInstallation.load(store);
      expect(NexaInstallation.isValid(first.id), isTrue);
      // "Restart": a new load from the same store returns the same id.
      final again = await NexaInstallation.load(
        FileInstallationIdStore(File('${dir.path}/id')),
      );
      expect(again.id, first.id);
      // Another installation gets a different id.
      final other = await NexaInstallation.load(InMemoryInstallationIdStore());
      expect(other.id, isNot(first.id));
      expect(first.linkedAccount.value, isNull); // no login implemented
    });

    test('a corrupted stored id is replaced', () async {
      final store = InMemoryInstallationIdStore();
      await store.write('device-imei-123');
      final ins = await NexaInstallation.load(store);
      expect(NexaInstallation.isValid(ins.id), isTrue);
      expect(await store.read(), ins.id);
    });
  });

  group('server-owned history', () {
    late FakeConversationsApi api;
    late InMemoryHistoryStore cache;
    late NexaHistoryController history;

    setUp(() {
      api = FakeConversationsApi(45);
      cache = InMemoryHistoryStore();
      history = NexaHistoryController(
        NexaHistoryOptions(
          cache: cache,
          server: api,
          pageSize: 20,
          maxCachedConversations: 30,
        ),
      );
    });

    test('pages through the server and keeps a bounded cache', () async {
      await history.refresh();
      expect(history.serverBacked, isTrue);
      expect(history.entries, hasLength(20));
      expect(history.entries.first.fromCache, isFalse);
      expect(history.hasMore, isTrue);
      await history.loadMore();
      await history.loadMore();
      expect(history.entries, hasLength(45));
      expect(history.hasMore, isFalse);
      expect(api.listCalls, [null, '20', '40']);
      await history.loadMore(); // no more pages: no call
      expect(api.listCalls, hasLength(3));
      expect((await cache.load()).length, 30); // bounded
    });

    test('open and rename go through the server', () async {
      await history.refresh();
      final e = history.entries.first;
      final messages = await history.open(e);
      expect(messages.map((m) => m.text), ['q', 'a']);
      await history.rename(e, '  Dinner  ');
      expect(api.renamed[e.sessionId], 'Dinner');
      expect(history.entries.first.title, 'Dinner');
    });

    test('deletion reports partial failure, retry, request id', () async {
      await history.refresh();
      final first = await history.delete(
        NexaDeletionScope.allVoice,
        deleteLocalMedia: () async => 0,
      );
      expect(first.serverAvailable, isTrue);
      expect(first.server!.state, NexaDeletionState.partial);
      expect(first.server!.requestId, 'del_2043');
      expect(first.serverConfirmed, isFalse);
      expect(
        history.entries.where((e) => e.kind == NexaHistoryKind.voice),
        isEmpty,
      );
      final retry = await history.retryServer(NexaDeletionScope.allVoice);
      expect(retry.serverConfirmed, isTrue);
    });

    test('without a server API, local deletion never claims server', () async {
      final local = NexaHistoryController(
        NexaHistoryOptions(cache: InMemoryHistoryStore()),
      );
      await local.refresh();
      expect(local.serverBacked, isFalse);
      final o = await local.delete(
        NexaDeletionScope.everything,
        deleteLocalMedia: () async => 3,
      );
      expect(o.localRemoved, 3);
      expect(o.serverAvailable, isFalse);
      expect(o.server, isNull);
      expect(o.serverConfirmed, isFalse);
    });
  });

  testWidgets('deletion sheet: confirm → partial → retry → confirmed', (
    tester,
  ) async {
    final api = FakeConversationsApi(3);
    final history = NexaHistoryController(
      NexaHistoryOptions(cache: InMemoryHistoryStore(), server: api),
    );
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: NexaLocale.delegates,
        supportedLocales: NexaLocale.supported,
        home: NexaDataPrivacyView(
          history: history,
          deleteLocalMedia: () async => 0,
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('nexa_scope_everything')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('nexa_deletion_note')), findsOneWidget);
    await tester.tap(find.byKey(const Key('nexa_deletion_confirm')));
    await tester.pumpAndSettle();
    String server() => tester
        .widget<Text>(find.byKey(const Key('nexa_deletion_server')))
        .data!;
    expect(server(), "Partly deleted: 2 items couldn't be removed.");
    expect(find.text('Request del_2043'), findsOneWidget);
    await tester.tap(find.byKey(const Key('nexa_deletion_retry')));
    await tester.pumpAndSettle();
    expect(server(), 'Deleted on the server');
    expect(find.byKey(const Key('nexa_deletion_retry')), findsNothing);
  });
}
