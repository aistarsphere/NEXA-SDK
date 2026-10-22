import 'package:nexa_core/nexa_core.dart';
import 'package:nexa_core/testing.dart';
import 'package:test/test.dart';

void main() {
  group('MockChatTransport', () {
    late MockChatTransport t;
    late SessionHandle h;

    setUp(() async {
      t = MockChatTransport(
        tokenDelay: Duration.zero,
        thinkDelay: Duration.zero,
      );
      h = await t.startSession(
        credential: await MockAuthProvider().fetchSessionCredential(),
        requestedCapabilities: {
          NexaCapability.textChat,
          NexaCapability.liveVoice,
        },
        languageTag: 'en',
      );
    });

    tearDown(() => t.dispose());

    test('grants only supported capabilities', () {
      expect(h.grantedCapabilities, {NexaCapability.textChat});
    });

    test(
      'streams a complete reply through the sequencer and reducer',
      () async {
        final seq = EventSequencer()..reset(h.sessionId);
        var state = ConversationState.initial;
        const reducer = ConversationReducer();
        final done = t.events(h.sessionId).listen((e) {
          for (final ready in seq.accept(e).ready) {
            state = reducer.reduce(state, ready);
          }
        });
        await t.sendMessage(
          h.sessionId,
          const OutgoingMessage(
            clientMessageId: ClientMessageId('c1'),
            text: 'hello',
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await done.cancel();
        expect(state.phase, ConversationPhase.active);
        expect(state.messages.length, 2);
        expect(state.messages.last.status, MessageStatus.completed);
        expect(state.messages.last.text, contains('hello'));
      },
    );

    test('reorder scenario still yields ordered text', () async {
      final seq = EventSequencer()..reset(h.sessionId);
      var state = ConversationState.initial;
      const reducer = ConversationReducer();
      final sub = t.events(h.sessionId).listen((e) {
        for (final ready in seq.accept(e).ready) {
          state = reducer.reduce(state, ready);
        }
      });
      await t.sendMessage(
        h.sessionId,
        const OutgoingMessage(
          clientMessageId: ClientMessageId('c2'),
          text: 'reorder please',
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await sub.cancel();
      expect(state.messages.last.text, 'Order is preserved.');
    });

    test('cancel stops streaming', () async {
      final slow = MockChatTransport(
        tokenDelay: const Duration(milliseconds: 20),
        thinkDelay: Duration.zero,
      );
      final sh = await slow.startSession(
        credential: await MockAuthProvider().fetchSessionCredential(),
        requestedCapabilities: {NexaCapability.textChat},
        languageTag: 'en',
      );
      final events = <ConversationEvent>[];
      final sub = slow.events(sh.sessionId).listen(events.add);
      await slow.sendMessage(
        sh.sessionId,
        const OutgoingMessage(
          clientMessageId: ClientMessageId('c3'),
          text: 'slow',
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 30));
      final startedEvent = events
          .whereType<AssistantMessageStartedEvent>()
          .single;
      await slow.cancelMessage(sh.sessionId, startedEvent.messageId);
      await Future<void>.delayed(const Duration(milliseconds: 300));
      await sub.cancel();
      expect(events.whereType<MessageCancelledEvent>().length, 1);
      expect(events.whereType<AssistantMessageCompletedEvent>(), isEmpty);
      await slow.dispose();
    });

    test(
      'retry with same clientMessageId does not start a second reply',
      () async {
        final events = <ConversationEvent>[];
        final sub = t.events(h.sessionId).listen(events.add);
        const msg = OutgoingMessage(
          clientMessageId: ClientMessageId('c4'),
          text: 'hi',
        );
        await t.sendMessage(h.sessionId, msg);
        await t.sendMessage(h.sessionId, msg);
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await sub.cancel();
        expect(events.whereType<UserMessageAcceptedEvent>().length, 2);
        expect(events.whereType<AssistantMessageStartedEvent>().length, 1);
      },
    );

    test('invalid tool payload becomes an error result', () async {
      final events = <ConversationEvent>[];
      final sub = t.events(h.sessionId).listen(events.add);
      await t.sendMessage(
        h.sessionId,
        const OutgoingMessage(
          clientMessageId: ClientMessageId('c5'),
          text: 'invalid',
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await sub.cancel();
      final result = events.whereType<ToolResultReceivedEvent>().single;
      expect(result.result, isA<ErrorToolResult>());
    });

    test('expired credential is rejected', () async {
      expect(
        t.startSession(
          credential: SessionCredential(
            token: 'x',
            expiresAt: DateTime.now().subtract(const Duration(minutes: 1)),
          ),
          requestedCapabilities: const {},
          languageTag: 'en',
        ),
        throwsA(isA<SessionExpiredException>()),
      );
    });
  });
}
