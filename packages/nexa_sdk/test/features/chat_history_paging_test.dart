// Plan B-03: a resumed conversation shows its newest page and pages to
// older messages (before_seq) on demand, without duplicates.
import 'package:flutter_test/flutter_test.dart';
import 'package:nexa_sdk/nexa_sdk.dart';
import 'package:nexa_sdk/src/features/chat/bloc/chat_bloc.dart';
import 'package:nexa_sdk/src/features/chat/bloc/chat_event.dart';
import 'package:nexa_sdk/src/features/chat/bloc/chat_state.dart';
import 'package:nexa_sdk/src/session/session_manager.dart';

import '../helpers.dart';

ChatMessage msg(int n) => ChatMessage(
  id: MessageId('m$n'),
  role: n.isOdd ? MessageRole.user : MessageRole.assistant,
  status: n.isOdd ? MessageStatus.sent : MessageStatus.completed,
  createdAt: DateTime.utc(2026, 1, 1, 0, n),
  text: 'text $n',
);

void main() {
  late NexaClient client;
  late List<int?> loads;
  late bool failNext;

  setUp(() {
    loads = [];
    failNext = false;
  });

  tearDown(() => client.dispose());

  Future<ChatBloc> resumed() async {
    client = await initMockClient();
    final sessions = client.injector<SessionManager>()
      ..historyLoader = (cid, {beforeSeq}) async {
        loads.add(beforeSeq);
        if (failNext) {
          failNext = false;
          throw const NetworkException(NexaErrorCode.networkUnreachable, 'x');
        }
        return switch (beforeSeq) {
          null => ChatHistoryPage([msg(3), msg(4)], nextBefore: 3),
          3 => ChatHistoryPage([msg(2), msg(3)], nextBefore: 2),
          2 => ChatHistoryPage([msg(1)]),
          _ => const ChatHistoryPage([]),
        };
      };
    sessions.coordinator!.open('conv_1');
    final bloc = client.injector<ChatBloc>()..add(const ChatStarted());
    await waitFor(() => bloc.state.olderBefore != null, reason: 'resumed');
    return bloc;
  }

  List<String> ids(ChatBloc b) => [
    for (final m in b.state.conversation.messages) m.id.value,
  ];

  test('resume shows the newest page and remembers the cursor', () async {
    final bloc = await resumed();
    expect(ids(bloc), ['m3', 'm4']);
    expect(bloc.state.olderBefore, 3);
    expect(loads, [null]);
    await bloc.close();
  });

  test(
    'older pages are prepended once, in order, without duplicates',
    () async {
      final bloc = await resumed();
      bloc.add(const ChatOlderRequested());
      await waitFor(() => bloc.state.olderBefore == 2, reason: 'second page');
      expect(ids(bloc), ['m2', 'm3', 'm4']); // m3 was in both pages
      bloc.add(const ChatOlderRequested());
      await waitFor(() => bloc.state.olderBefore == null, reason: 'start');
      expect(ids(bloc), ['m1', 'm2', 'm3', 'm4']);
      expect(loads, [null, 3, 2]);
      expect(bloc.state.loadingOlder, isFalse);
      await bloc.close();
    },
  );

  test('at the start of the conversation nothing more is loaded', () async {
    final bloc = await resumed();
    bloc
      ..add(const ChatOlderRequested())
      ..add(const ChatOlderRequested())
      ..add(const ChatOlderRequested())
      ..add(const ChatOlderRequested());
    await waitFor(() => bloc.state.olderBefore == null);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(loads, [null, 3, 2]);
    await bloc.close();
  });

  test('a failed page keeps the cursor and can be retried', () async {
    final bloc = await resumed();
    failNext = true;
    bloc.add(const ChatOlderRequested());
    await waitFor(() => loads.length == 2, reason: 'attempt');
    await waitFor(() => !bloc.state.loadingOlder);
    expect(bloc.state.olderBefore, 3);
    expect(ids(bloc), ['m3', 'm4']);
    bloc.add(const ChatOlderRequested());
    await waitFor(() => bloc.state.olderBefore == 2, reason: 'retry');
    await bloc.close();
  });

  test('without a resumed conversation nothing is requested', () async {
    client = await initMockClient();
    final bloc = client.injector<ChatBloc>()..add(const ChatStarted());
    await waitFor(
      () => bloc.state.connection == ChatConnection.connected,
      reason: 'connected',
    );
    bloc.add(const ChatOlderRequested());
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(loads, isEmpty);
    expect(bloc.state.olderBefore, isNull);
    await bloc.close();
  });
}
