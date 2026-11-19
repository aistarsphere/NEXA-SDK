// Deleting conversations: one row from the list, all of them, and what the
// gateway is asked to do for each scope.
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexa_sdk/nexa_sdk.dart';

/// A server that really forgets what was deleted.
final class _Server implements NexaConversationsApi {
  _Server(int n) : ids = [for (var i = 1; i <= n; i++) 'conv_$i'];
  final List<String> ids;
  final calls = <String>[];
  bool fail = false;

  @override
  bool get canList => true;
  @override
  bool supportsDeletion(NexaDeletionScope scope) => true;

  @override
  Future<NexaHistoryPage> list({String? cursor, int limit = 20}) async =>
      NexaHistoryPage([
        for (final (i, id) in ids.indexed)
          NexaHistoryEntry(
            id: id,
            kind: NexaHistoryKind.chat,
            sessionId: id,
            startedAt: DateTime.utc(2026, 1, 1, i),
            updatedAt: DateTime.utc(2026, 1, 1, i),
            title: 'Talk $id',
            messageCount: 2,
          ),
      ]);

  @override
  Future<NexaDeletionReceipt> delete(
    NexaDeletionScope scope, {
    String? conversationId,
  }) async {
    calls.add('${scope.name}:${conversationId ?? '-'}');
    if (fail) {
      throw const NetworkException(NexaErrorCode.networkUnreachable, 'offline');
    }
    if (scope == NexaDeletionScope.conversation) {
      ids.remove(conversationId);
    } else {
      ids.clear();
    }
    return const NexaDeletionReceipt(state: NexaDeletionState.completed);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => false;
}

/// Records gateway requests; conversations listed are removed when deleted.
final class _Gateway implements HttpClientAdapter {
  final ids = ['c1', 'c2', 'c3'];
  final requests = <String>[];
  String? failing;

  @override
  Future<ResponseBody> fetch(
    RequestOptions o,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(
      '${o.method} ${o.uri.path}${o.uri.hasQuery ? '?${o.uri.query}' : ''}',
    );
    ResponseBody json(Object body, [int status = 200]) =>
        ResponseBody.fromString(
          jsonEncode(body),
          status,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
    if (o.method == 'GET') {
      return json({
        'items': [
          for (final id in ids) {'id': id, 'kind': 'chat', 'message_count': 1},
        ],
        'next_cursor': null,
      });
    }
    final id = o.uri.pathSegments.last;
    if (id == failing) {
      return json({
        'error': {'code': 'internal'},
      }, 500);
    }
    if (id == 'conversations') {
      ids.clear();
    } else {
      ids.remove(id);
    }
    return json({
      'deleted': {'conversations': 1},
    });
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  group('NexaHistoryController', () {
    test('all conversations: the device list empties and the server is asked '
        'once', () async {
      final server = _Server(3);
      final history = NexaHistoryController(
        NexaHistoryOptions(cache: InMemoryHistoryStore(), server: server),
      );
      await history.refresh();
      expect(history.entries, hasLength(3));

      final o = await history.delete(NexaDeletionScope.allConversations);
      expect(o.serverConfirmed, isTrue);
      expect(o.localRemoved, 3);
      expect(server.calls, ['allConversations:-']);
      expect(history.entries, isEmpty);
      expect(history.cachedEntries, isEmpty);
      await history.refresh();
      expect(history.entries, isEmpty);
    });
  });

  group('LabeebConversationsApi', () {
    late _Gateway gw;
    LabeebConversationsApi api({String? installation}) =>
        LabeebConversationsApi(
          LabeebSdkClient(
            Dio(BaseOptions(baseUrl: 'https://gw.test'))
              ..httpClientAdapter = gw,
          ),
          installationId: installation,
        );
    setUp(() => gw = _Gateway());

    test('one conversation: DELETE on its id', () async {
      final r = await api().delete(
        NexaDeletionScope.conversation,
        conversationId: 'c2',
      );
      expect(r.state, NexaDeletionState.completed);
      expect(gw.requests, ['DELETE /v1/sdk/conversations/c2']);
    });

    test('all conversations: one clear request without a kind', () async {
      final r = await api().delete(NexaDeletionScope.allConversations);
      expect(r.state, NexaDeletionState.completed);
      expect(gw.requests, ['DELETE /v1/sdk/conversations']);
    });

    test('all conversations with an installation filter: only the listed '
        'ones, one by one', () async {
      final r = await api(
        installation: 'ins_1',
      ).delete(NexaDeletionScope.allConversations);
      expect(r.state, NexaDeletionState.completed);
      expect(gw.requests.where((r) => r.startsWith('DELETE')), [
        'DELETE /v1/sdk/conversations/c1',
        'DELETE /v1/sdk/conversations/c2',
        'DELETE /v1/sdk/conversations/c3',
      ]);
      expect(
        gw.requests.where((r) => r.startsWith('GET')),
        everyElement(contains('installation=ins_1')),
      );
    });

    test(
      'a conversation the server refuses to delete is reported, once',
      () async {
        gw.failing = 'c2';
        final r = await api(
          installation: 'ins_1',
        ).delete(NexaDeletionScope.allConversations);
        expect(r.state, NexaDeletionState.partial);
        expect(r.failedItems, 1);
        expect(r.retryable, isTrue);
        expect(gw.ids, ['c2']);
        expect(
          gw.requests.where((r) => r.endsWith('/c2')),
          hasLength(1),
          reason: 'not retried in a loop',
        );
      },
    );
  });

  group('conversation list', () {
    late NexaHistoryController history;
    late List<String> deleted;

    Widget app(_Server server) {
      history = NexaHistoryController(
        NexaHistoryOptions(cache: InMemoryHistoryStore(), server: server),
      );
      addTearDown(history.dispose);
      deleted = [];
      return MaterialApp(
        localizationsDelegates: NexaLocale.delegates,
        supportedLocales: NexaLocale.supported,
        home: NexaConversationListPage(
          history: history,
          onNew: () {},
          onOpen: (_) {},
          onDeleted: (e) async => deleted.add(e.conversationId),
        ),
      );
    }

    Future<void> openDelete(WidgetTester tester, String id) async {
      await tester.tap(find.byKey(Key('nexa_list_menu_$id')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(Key('nexa_list_delete_$id')));
      await tester.pumpAndSettle();
    }

    testWidgets('menu → delete → confirm removes the row on the server and '
        'in the list', (tester) async {
      final server = _Server(3);
      await tester.pumpWidget(app(server));
      await tester.pumpAndSettle();

      await openDelete(tester, 'conv_2');
      expect(find.byKey(const Key('nexa_deletion_sheet')), findsOneWidget);
      expect(server.calls, isEmpty, reason: 'nothing before confirmation');
      await tester.tap(find.byKey(const Key('nexa_deletion_confirm')));
      await tester.pumpAndSettle();
      expect(find.text('Deleted on the server'), findsOneWidget);
      await tester.tap(find.byKey(const Key('nexa_deletion_done')));
      await tester.pumpAndSettle();

      expect(server.calls, ['conversation:conv_2']);
      expect(deleted, ['conv_2']);
      expect(find.byKey(const Key('nexa_list_conv_2')), findsNothing);
      expect(find.byKey(const Key('nexa_list_conv_1')), findsOneWidget);
      expect(find.byKey(const Key('nexa_list_conv_3')), findsOneWidget);
    });

    testWidgets('cancel keeps the row and asks the server nothing', (
      tester,
    ) async {
      final server = _Server(2);
      await tester.pumpWidget(app(server));
      await tester.pumpAndSettle();

      await openDelete(tester, 'conv_1');
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(server.calls, isEmpty);
      expect(deleted, isEmpty);
      expect(find.byKey(const Key('nexa_list_conv_1')), findsOneWidget);
    });

    testWidgets('long press opens the same confirmation', (tester) async {
      await tester.pumpWidget(app(_Server(1)));
      await tester.pumpAndSettle();
      await tester.longPress(find.byKey(const Key('nexa_list_conv_1')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('nexa_deletion_confirm')), findsOneWidget);
    });

    testWidgets('the server fails: the sheet says so and the row comes back', (
      tester,
    ) async {
      final server = _Server(2)..fail = true;
      await tester.pumpWidget(app(server));
      await tester.pumpAndSettle();

      await openDelete(tester, 'conv_1');
      await tester.tap(find.byKey(const Key('nexa_deletion_confirm')));
      await tester.pumpAndSettle();
      expect(find.text('Deleted on the server'), findsNothing);
      expect(find.byKey(const Key('nexa_deletion_retry')), findsOneWidget);
      await tester.tap(find.byKey(const Key('nexa_deletion_done')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('nexa_list_conv_1')), findsOneWidget);
    });
  });
}
