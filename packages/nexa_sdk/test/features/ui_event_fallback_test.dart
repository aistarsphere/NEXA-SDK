// Plan D-02: a selection made while no chat view is open (a voice-only
// call) is still sent: the client opens the conversation's chat session and
// posts the `ui_event` there. The chat view's own sender wins while it is
// mounted and is released when it goes away.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexa_core/testing.dart';
import 'package:nexa_sdk/nexa_sdk.dart';

import '../helpers.dart';

const event = NexaUiEvent(
  uiId: 'ui_1',
  componentId: 'list',
  event: 'select',
  optionIds: ['pl_2'],
);

void main() {
  late MockChatTransport transport;
  late NexaClient client;

  setUp(() => transport = fastMock());
  tearDown(() => client.dispose());

  Future<void> init() async =>
      client = await initMockClient(transport: transport);

  test('with no chat open the event goes out on the chat session', () async {
    await init();
    expect(client.toolCalls.uiEventSink, isNull);

    final code = await client.toolCalls.sendUiEvent(event);

    expect(code, isNull);
    final sent = transport.sentMessages.single;
    expect(sent.uiEvent, event.toJson());
    expect(sent.clientMessageId.value, isNotEmpty);
  });

  test('every event gets its own client_message_id', () async {
    await init();
    await client.toolCalls.sendUiEvent(event);
    await client.toolCalls.sendUiEvent(
      const NexaUiEvent(uiId: 'ui_1', componentId: 'other', event: 'select'),
    );
    final ids = transport.sentMessages.map((m) => m.clientMessageId.value);
    expect(ids.toSet(), hasLength(2));
  });

  testWidgets('the chat view takes the sender while mounted and releases it', (
    tester,
  ) async {
    await init();
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: NexaLocale.delegates,
        supportedLocales: NexaLocale.supported,
        home: Scaffold(body: client.chatView()),
      ),
    );
    await tester.pumpAndSettle();
    expect(client.toolCalls.uiEventSink, isNotNull);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    expect(client.toolCalls.uiEventSink, isNull);
  });
}
