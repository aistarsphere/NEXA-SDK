// The conversation list (plan B-01): the root screen of LABEEB. Server
// pages, pull to refresh, infinite scroll, empty/error states, and the
// New / Call actions.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexa_sdk/nexa_sdk.dart';

import 'history_identity_test.dart' show FakeConversationsApi;

final class _FailingApi implements NexaConversationsApi {
  int calls = 0;
  @override
  bool get canList => true;
  @override
  Future<NexaHistoryPage> list({String? cursor, int limit = 20}) {
    calls++;
    return Future.error(
      const NetworkException(NexaErrorCode.networkUnreachable, 'offline'),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => false;
}

void main() {
  late NexaHistoryController history;
  late List<String> log;

  Widget app(
    NexaConversationsApi api, {
    bool call = true,
    Locale? locale,
    double scale = 1,
  }) {
    history = NexaHistoryController(
      NexaHistoryOptions(
        cache: InMemoryHistoryStore(),
        server: api,
        pageSize: 20,
      ),
    );
    addTearDown(history.dispose);
    return MaterialApp(
      locale: locale,
      localizationsDelegates: NexaLocale.delegates,
      supportedLocales: NexaLocale.supported,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: NexaConversationListPage(
        history: history,
        title: const Text('LABEEB'),
        onNew: () => log.add('new'),
        onCall: call ? () => log.add('call') : null,
        onOpen: (e) => log.add('open:${e.sessionId}'),
      ),
    );
  }

  setUp(() => log = []);

  testWidgets('shows server conversations; tapping one opens it', (
    tester,
  ) async {
    await tester.pumpWidget(app(FakeConversationsApi(5)));
    await tester.pumpAndSettle();
    expect(find.text('Conversation 5'), findsOneWidget);

    await tester.tap(find.byKey(const Key('nexa_list_srv_3')));
    expect(log, ['open:ses_3']);
  });

  testWidgets('empty: two entry points', (tester) async {
    await tester.pumpWidget(app(FakeConversationsApi(0)));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('nexa_list_empty')), findsOneWidget);

    await tester.tap(find.byKey(const Key('nexa_list_empty_chat')));
    await tester.tap(find.byKey(const Key('nexa_list_empty_call')));
    expect(log, ['new', 'call']);
  });

  testWidgets('New and Call actions; no Call without a handler', (
    tester,
  ) async {
    await tester.pumpWidget(app(FakeConversationsApi(2)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('nexa_list_new')));
    await tester.tap(find.byKey(const Key('nexa_list_call')));
    expect(log, ['new', 'call']);

    await tester.pumpWidget(app(FakeConversationsApi(2), call: false));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('nexa_list_call')), findsNothing);
  });

  testWidgets('error: message and Retry', (tester) async {
    final api = _FailingApi();
    await tester.pumpWidget(app(api));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('nexa_list_error')), findsOneWidget);
    final before = api.calls;
    await tester.tap(find.byKey(const Key('nexa_list_retry')));
    await tester.pumpAndSettle();
    expect(api.calls, greaterThan(before));
  });

  testWidgets('scrolling to the end loads the next page', (tester) async {
    final api = FakeConversationsApi(45);
    await tester.pumpWidget(app(api));
    await tester.pumpAndSettle();
    expect(api.listCalls, hasLength(1));
    await tester.fling(
      find.byKey(const Key('nexa_list')),
      const Offset(0, -3000),
      3000,
    );
    await tester.pumpAndSettle();
    expect(api.listCalls.length, greaterThan(1));
  });

  testWidgets('pull to refresh reloads from the server', (tester) async {
    final api = FakeConversationsApi(5);
    await tester.pumpWidget(app(api));
    await tester.pumpAndSettle();
    await tester.fling(
      find.byKey(const Key('nexa_list')),
      const Offset(0, 400),
      1000,
    );
    await tester.pumpAndSettle();
    expect(api.listCalls.length, greaterThan(1));
  });

  testWidgets('targets are 48 dp and labelled', (tester) async {
    await tester.pumpWidget(app(FakeConversationsApi(2)));
    await tester.pumpAndSettle();
    final handle = tester.ensureSemantics();
    expect(
      tester.getSize(find.byKey(const Key('nexa_list_call'))).shortestSide,
      greaterThanOrEqualTo(48),
    );
    expect(find.bySemanticsLabel('New conversation'), findsWidgets);
    handle.dispose();
  });

  testWidgets('Arabic: right-to-left, no overflow at 2x text', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      app(FakeConversationsApi(3), locale: const Locale('ar'), scale: 2),
    );
    await tester.pumpAndSettle();
    expect(
      Directionality.of(tester.element(find.byKey(const Key('nexa_list')))),
      TextDirection.rtl,
    );
    expect(tester.takeException(), isNull);
  });
}
