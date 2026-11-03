// Plan C-01 in the chat view: turns spoken in a call show a small
// microphone mark; typed messages do not.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexa_sdk/nexa_sdk.dart';

import '../helpers.dart';

ChatMessage msg(String id, int s, String text, MessageOrigin origin) =>
    ChatMessage(
      id: MessageId(id),
      role: MessageRole.user,
      status: MessageStatus.sent,
      createdAt: DateTime.utc(2026, 1, 1, 0, 0, s),
      text: text,
      origin: origin,
    );

void main() {
  testWidgets('a spoken turn is marked; a typed one is not', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final client = await initMockClient();
    addTearDown(client.dispose);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: NexaLocale.delegates,
        supportedLocales: NexaLocale.supported,
        home: Scaffold(body: client.chatView()),
      ),
    );
    await tester.pumpAndSettle();

    client.conversations.publishPersisted([
      msg('t1', 10, 'typed one', MessageOrigin.text),
      msg('v1', 20, 'spoken one', MessageOrigin.voice),
    ]);
    await tester.pumpAndSettle();

    expect(find.text('typed one'), findsOneWidget);
    expect(find.text('spoken one'), findsOneWidget);
    expect(find.byKey(const Key('nexa_message_spoken')), findsOneWidget);
    expect(find.text('Spoken'), findsOneWidget);
  });
}
