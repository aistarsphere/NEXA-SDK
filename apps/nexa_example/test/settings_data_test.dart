// Settings → Conversations: "Delete all conversations" and "Clear cache".
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexa_core/testing.dart';
import 'package:nexa_example/assistant/assistant_settings_page.dart';
import 'package:nexa_example/main.dart';
import 'package:nexa_sdk/nexa_sdk.dart';

final class _Server implements NexaConversationsApi {
  final ids = ['conv_1', 'conv_2'];
  final calls = <String>[];

  @override
  bool get canList => true;
  @override
  bool supportsDeletion(NexaDeletionScope scope) => true;

  @override
  Future<NexaHistoryPage> list({String? cursor, int limit = 20}) async =>
      NexaHistoryPage([
        for (final id in ids)
          NexaHistoryEntry(
            id: id,
            kind: NexaHistoryKind.chat,
            sessionId: id,
            startedAt: DateTime.utc(2026),
            updatedAt: DateTime.utc(2026),
            title: 'Talk $id',
            messageCount: 2,
          ),
      ]);

  @override
  Future<NexaDeletionReceipt> delete(
    NexaDeletionScope scope, {
    String? conversationId,
  }) async {
    calls.add(scope.name);
    ids.clear();
    return const NexaDeletionReceipt(state: NexaDeletionState.completed);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => false;
}

void main() {
  Future<NexaClient> client({NexaHistoryOptions? history}) async {
    final c = await Nexa.initialize(
      config: NexaConfig(
        applicationId: 'app_test',
        gatewayBaseUri: Uri.parse('http://localhost'),
        environment: NexaEnvironment.development,
        requestedCapabilities: const {NexaCapability.textChat},
      ),
      auth: MockAuthProvider(),
      history: history,
      overrides: NexaOverrides(chatTransport: MockChatTransport()),
    );
    addTearDown(c.dispose);
    return c;
  }

  Future<void> open(
    WidgetTester tester,
    NexaClient c, {
    String location = '/settings',
  }) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ExampleApp(
        client: c,
        auth: MockAuthProvider(),
        initialLocation: location,
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('delete all conversations: asks first, then the server and the '
      'device list are empty', (tester) async {
    final server = _Server();
    final cache = InMemoryHistoryStore();
    final c = await client(
      history: NexaHistoryOptions(cache: cache, server: server),
    );
    final pending = InMemoryPendingStore();
    c.toolCalls.pendingStore = pending;
    await pending.save(
      'conv_2',
      const LabeebPendingState(
        uiValues: {
          'ui_1': {'name': 'x'},
        },
      ),
    );
    await c.history!.refresh();
    expect(c.history!.entries, hasLength(2));
    await open(tester, c);

    final tile = find.byKey(const Key('settings_delete_all_conversations'));
    await tester.ensureVisible(tile);
    await tester.tap(tile);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('nexa_deletion_note')), findsOneWidget);
    expect(server.calls, isEmpty, reason: 'nothing before confirmation');

    await tester.tap(find.byKey(const Key('nexa_deletion_confirm')));
    await tester.pumpAndSettle();
    expect(find.text('Deleted on the server'), findsOneWidget);
    await tester.tap(find.byKey(const Key('nexa_deletion_done')));
    await tester.pumpAndSettle();

    expect(server.calls, ['allConversations']);
    expect((await pending.load('conv_2')).isEmpty, isTrue);
    expect(c.history!.entries, isEmpty);
    expect(await cache.load(), isEmpty);
    expect(c.conversationId, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('deleting the open conversation from the list leaves it, also '
      'when the sheet is closed by tapping outside', (tester) async {
    final server = _Server();
    final pending = InMemoryPendingStore();
    final c = await client(
      history: NexaHistoryOptions(
        cache: InMemoryHistoryStore(),
        server: server,
      ),
    );
    c.toolCalls.pendingStore = pending;
    await pending.save(
      'conv_1',
      const LabeebPendingState(
        uiValues: {
          'ui_1': {'name': 'x'},
        },
      ),
    );
    c.conversations.open('conv_1');
    expect(c.conversationId, 'conv_1');
    await open(tester, c, location: '/');

    await tester.tap(find.byKey(const Key('nexa_list_menu_conv_1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('nexa_list_delete_conv_1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('nexa_deletion_confirm')));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(20, 20)); // the barrier, not "Done"
    await tester.pumpAndSettle();

    expect(server.calls, ['conversation']);
    expect(c.conversationId, isNull);
    expect((await pending.load('conv_1')).isEmpty, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('delete all conversations: cancel deletes nothing', (
    tester,
  ) async {
    final server = _Server();
    final c = await client(
      history: NexaHistoryOptions(
        cache: InMemoryHistoryStore(),
        server: server,
      ),
    );
    await open(tester, c);
    final tile = find.byKey(const Key('settings_delete_all_conversations'));
    await tester.ensureVisible(tile);
    await tester.tap(tile);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(server.calls, isEmpty);
    expect(server.ids, hasLength(2));
  });

  testWidgets('clear cache: the device copy goes, the server is not asked', (
    tester,
  ) async {
    final server = _Server();
    final cache = InMemoryHistoryStore();
    var hostCleared = 0;
    final c = await client(
      history: NexaHistoryOptions(
        cache: cache,
        server: server,
        onClearHostData: () async {
          hostCleared++;
          return 1;
        },
      ),
    );
    await c.history!.refresh();
    expect(await cache.load(), hasLength(2));
    // The app's support and temporary directories, with one leftover file.
    final dir = Directory.systemTemp.createTempSync('ameer_cache');
    addTearDown(() => dir.deleteSync(recursive: true));
    final leftover = File('${dir.path}/capture.jpg')..writeAsStringSync('x');
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          ..setMockMethodCallHandler(channel, (_) async => dir.path);
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    await open(tester, c);

    final tile = find.byKey(const Key('settings_clear_cache'));
    await tester.ensureVisible(tile);
    await tester.tap(tile);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('nexa_deletion_confirm')));
    // Deleting local media is real file I/O.
    for (var i = 0; i < 20; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
      if (find.byKey(const Key('nexa_deletion_done')).evaluate().isNotEmpty) {
        break;
      }
    }
    await tester.tap(find.byKey(const Key('nexa_deletion_done')));
    await tester.pumpAndSettle();
    // Temporary files are removed after the sheet closes (real file I/O).
    for (var i = 0; i < 20 && leftover.existsSync(); i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
    await tester.pumpAndSettle();

    expect(server.calls, isEmpty);
    expect(server.ids, hasLength(2), reason: 'server history untouched');
    expect(await cache.load(), isEmpty);
    expect(leftover.existsSync(), isFalse, reason: 'temporary files go');
    expect(hostCleared, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('no history configured: neither tile is shown', (tester) async {
    await open(tester, await client());
    expect(
      find.byKey(const Key('settings_delete_all_conversations')),
      findsNothing,
    );
    expect(find.byKey(const Key('settings_clear_cache')), findsNothing);
  });

  test('clearTemporaryFiles empties the directory and keeps it', () async {
    final dir = Directory.systemTemp.createTempSync('ameer_tmp');
    addTearDown(() => dir.deleteSync(recursive: true));
    File('${dir.path}/a.jpg').writeAsStringSync('x');
    Directory('${dir.path}/picked').createSync();
    File('${dir.path}/picked/b.pdf').writeAsStringSync('y');

    expect(await clearTemporaryFiles(dir), 2);
    expect(dir.existsSync(), isTrue);
    expect(dir.listSync(), isEmpty);
    expect(await clearTemporaryFiles(Directory('${dir.path}/missing')), 0);
  });
}
