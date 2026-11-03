// Plan B-03 in the chat view: scrolling to the top of a resumed
// conversation loads the older page and keeps the reading position.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexa_sdk/nexa_sdk.dart';
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
  testWidgets('scrolling up loads the older page and keeps the position', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final loads = <int?>[];
    final client = await initMockClient();
    addTearDown(client.dispose);
    final sessions = client.injector<SessionManager>()
      ..historyLoader = (cid, {beforeSeq}) async {
        loads.add(beforeSeq);
        return beforeSeq == null
            ? ChatHistoryPage([
                for (var i = 21; i <= 40; i++) msg(i),
              ], nextBefore: 21)
            : ChatHistoryPage([for (var i = 1; i <= 20; i++) msg(i)]);
      };
    sessions.coordinator!.open('conv_1');
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: NexaLocale.delegates,
        supportedLocales: NexaLocale.supported,
        home: Scaffold(body: client.chatView()),
      ),
    );
    await tester.pumpAndSettle();
    expect(loads, [null]);
    expect(find.text('text 40'), findsOneWidget);

    final list = find.byKey(const Key('nexa_message_list'));
    await tester.dragUntilVisible(
      find.text('text 21'),
      list,
      const Offset(0, 300),
    );
    await tester.pumpAndSettle();
    expect(loads, [null, 21]);
    // The message the user was reading is still there (no jump to the top).
    expect(find.text('text 21'), findsOneWidget);

    await tester.dragUntilVisible(
      find.text('text 1'),
      list,
      const Offset(0, 300),
    );
    expect(find.text('text 1'), findsOneWidget);
    expect(find.byKey(const Key('nexa_older_loading')), findsNothing);
  });
}
