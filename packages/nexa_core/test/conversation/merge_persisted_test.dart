// Plan C-01: persisted messages (server `GET …/messages`) are merged into
// the live conversation: persisted wins by id; the same text from the same
// role within 2 s is one message; order is by time.
import 'package:nexa_core/nexa_core.dart';
import 'package:test/test.dart';

ChatMessage m(
  String id,
  int sec,
  String text, {
  MessageRole role = MessageRole.user,
  MessageStatus status = MessageStatus.sent,
  MessageOrigin origin = MessageOrigin.text,
}) => ChatMessage(
  id: MessageId(id),
  role: role,
  status: status,
  createdAt: DateTime.utc(2026, 1, 1, 0, 0, sec),
  text: text,
  origin: origin,
);

ConversationState state(List<ChatMessage> messages) =>
    ConversationState(messages: messages);

List<String> ids(ConversationState s) => [
  for (final x in s.messages) x.id.value,
];

void main() {
  const reducer = ConversationReducer();

  test('new persisted messages are inserted by time', () {
    final s = reducer.mergePersisted(
      state([m('a', 10, 'one'), m('d', 40, 'four')]),
      [m('b', 20, 'two'), m('c', 30, 'three')],
    );
    expect(ids(s), ['a', 'b', 'c', 'd']);
  });

  test('a known id is not duplicated; persisted wins', () {
    final s = reducer.mergePersisted(
      state([m('a', 10, 'old', status: MessageStatus.pending)]),
      [m('a', 10, 'new', status: MessageStatus.sent)],
    );
    expect(s.messages.single.text, 'new');
    expect(s.messages.single.status, MessageStatus.sent);
  });

  test('a streaming message is not overwritten by the persisted copy', () {
    final s = reducer.mergePersisted(
      state([
        m(
          'a',
          10,
          'partial',
          role: MessageRole.assistant,
          status: MessageStatus.streaming,
        ),
      ]),
      [m('a', 10, 'partial and more', role: MessageRole.assistant)],
    );
    expect(s.messages.single.text, 'partial');
  });

  test('same role and text within 2 s is the same message', () {
    final s = reducer.mergePersisted(state([m('local_1', 10, 'hello')]), [
      m('srv_9', 11, 'hello'),
    ]);
    expect(ids(s), ['local_1']);
  });

  test('same text 3 s apart is a different message', () {
    final s = reducer.mergePersisted(state([m('a', 10, 'hello')]), [
      m('b', 13, 'hello'),
    ]);
    expect(ids(s), ['a', 'b']);
  });

  test('same text from another role is a different message', () {
    final s = reducer.mergePersisted(state([m('a', 10, 'ok')]), [
      m('b', 10, 'ok', role: MessageRole.assistant),
    ]);
    expect(s.messages, hasLength(2));
  });

  test('voice origin is kept', () {
    final s = reducer.mergePersisted(state([]), [
      m('v', 5, 'spoken', origin: MessageOrigin.voice),
    ]);
    expect(s.messages.single.origin, MessageOrigin.voice);
  });

  test('merging nothing changes nothing; the same page twice is stable', () {
    final base = state([m('a', 10, 'one')]);
    expect(reducer.mergePersisted(base, const []), base);
    final page = [m('b', 20, 'two')];
    final once = reducer.mergePersisted(base, page);
    expect(reducer.mergePersisted(once, page), once);
  });

  test('equal timestamps keep the existing order, then the page order', () {
    final s = reducer.mergePersisted(
      state([m('a', 10, 'x'), m('b', 10, 'y')]),
      [m('c', 10, 'z'), m('d', 10, 'w')],
    );
    expect(ids(s), ['a', 'b', 'c', 'd']);
  });
}
