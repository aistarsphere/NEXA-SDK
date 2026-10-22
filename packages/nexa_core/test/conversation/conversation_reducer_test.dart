import 'package:nexa_core/nexa_core.dart';
import 'package:test/test.dart';

import '../helpers.dart';

void main() {
  const reducer = ConversationReducer();

  group('ConversationReducer', () {
    test('session start activates the conversation', () {
      final s = applyAll([started(1)]);
      expect(s.phase, ConversationPhase.active);
      expect(s.sessionId, session);
      expect(s.lastSequence, 1);
    });

    test('streams deltas in order and completes', () {
      final s = applyAll([
        started(1),
        assistantStarted(2, 'a1'),
        delta(3, 'a1', 0, 'Hel'),
        delta(4, 'a1', 1, 'lo'),
        completed(5, 'a1'),
      ]);
      final m = s.messageById(const MessageId('a1'))!;
      expect(m.text, 'Hello');
      expect(m.status, MessageStatus.completed);
    });

    test('duplicate delta (same deltaIndex) is ignored', () {
      final s = applyAll([
        started(1),
        assistantStarted(2, 'a1'),
        delta(3, 'a1', 0, 'Hi'),
        delta(4, 'a1', 0, 'Hi'),
      ]);
      expect(s.messageById(const MessageId('a1'))!.text, 'Hi');
    });

    test('late delta after completion is ignored', () {
      final s = applyAll([
        started(1),
        assistantStarted(2, 'a1'),
        delta(3, 'a1', 0, 'Hi'),
        completed(4, 'a1'),
        delta(5, 'a1', 1, ' late'),
      ]);
      expect(s.messageById(const MessageId('a1'))!.text, 'Hi');
    });

    test('delta before started creates a placeholder (no text lost)', () {
      final s = applyAll([
        started(1),
        delta(2, 'a1', 0, 'Hi'),
        assistantStarted(3, 'a1'),
      ]);
      expect(s.messages.length, 1);
      expect(s.messageById(const MessageId('a1'))!.text, 'Hi');
      expect(
        s.messageById(const MessageId('a1'))!.status,
        MessageStatus.streaming,
      );
    });

    test('completion fullText is authoritative over lost deltas', () {
      final s = applyAll([
        started(1),
        assistantStarted(2, 'a1'),
        delta(3, 'a1', 0, 'Hel'),
        // delta 1 lost
        completed(5, 'a1', fullText: 'Hello world'),
      ]);
      expect(s.messageById(const MessageId('a1'))!.text, 'Hello world');
    });

    test('failure after completion wins', () {
      final s = applyAll([
        started(1),
        assistantStarted(2, 'a1'),
        completed(3, 'a1', fullText: 'ok'),
        failed(4, 'a1'),
      ]);
      expect(
        s.messageById(const MessageId('a1'))!.status,
        MessageStatus.failed,
      );
    });

    test('cancelled after completion is ignored', () {
      final s = applyAll([
        started(1),
        assistantStarted(2, 'a1'),
        completed(3, 'a1', fullText: 'ok'),
        ConversationEvent.messageCancelled(
          eventId: eid(),
          sessionId: session,
          sequence: 4,
          occurredAt: t0,
          messageId: const MessageId('a1'),
        ),
      ]);
      expect(
        s.messageById(const MessageId('a1'))!.status,
        MessageStatus.completed,
      );
    });

    test('retry reuses the same bubble and accepted reconciles id', () {
      var s = applyAll([started(1)]);
      s = reducer.addPendingUserMessage(
        s,
        clientMessageId: const ClientMessageId('c1'),
        text: 'hi',
        now: t0,
      );
      s = reducer.markSendFailed(
        s,
        clientMessageId: const ClientMessageId('c1'),
        errorCode: 'network',
        errorMessage: 'offline',
      );
      expect(s.messages.single.status, MessageStatus.failed);
      expect(s.messages.single.retryable, isTrue);
      // retry
      s = reducer.addPendingUserMessage(
        s,
        clientMessageId: const ClientMessageId('c1'),
        text: 'hi',
        now: t0,
      );
      expect(s.messages.length, 1);
      expect(s.messages.single.status, MessageStatus.pending);
      s = reducer.reduce(s, accepted(2, 'c1', 'u1'));
      expect(s.messages.single.id, const MessageId('u1'));
      expect(s.messages.single.status, MessageStatus.sent);
    });

    test('session end cancels streaming and fails pending', () {
      var s = applyAll([started(1), assistantStarted(2, 'a1')]);
      s = reducer.addPendingUserMessage(
        s,
        clientMessageId: const ClientMessageId('c9'),
        text: 'x',
        now: t0,
      );
      s = reducer.reduce(
        s,
        ConversationEvent.sessionEnded(
          eventId: eid(),
          sessionId: session,
          sequence: 3,
          occurredAt: t0,
          reason: SessionEndReason.quotaExceeded,
        ),
      );
      expect(s.phase, ConversationPhase.ended);
      expect(s.quotaExceeded, isTrue);
      expect(
        s.messageById(const MessageId('a1'))!.status,
        MessageStatus.cancelled,
      );
      expect(s.messages.last.status, MessageStatus.failed);
      expect(s.canSend, isFalse);
    });

    test('tool call lifecycle: requested -> confirmation -> result', () {
      const toolId = ToolCallId('t1');
      final s = applyAll([
        started(1),
        assistantStarted(2, 'a1'),
        ConversationEvent.toolCallRequested(
          eventId: eid(),
          sessionId: session,
          sequence: 3,
          occurredAt: t0,
          messageId: const MessageId('a1'),
          toolCall: const ToolCallRequest(
            id: toolId,
            toolName: 'bookings.create',
            displayTitle: 'Book',
            requiresConfirmation: true,
          ),
        ),
        ConversationEvent.userConfirmationRequested(
          eventId: eid(),
          sessionId: session,
          sequence: 4,
          occurredAt: t0,
          toolCallId: toolId,
          confirmation: const ConfirmationSpec(
            id: 'c',
            title: 'T',
            description: 'D',
          ),
        ),
        ConversationEvent.toolExecutionProgress(
          eventId: eid(),
          sessionId: session,
          sequence: 5,
          occurredAt: t0,
          toolCallId: toolId,
          status: ToolExecutionStatus.running,
          progress: 0.5,
        ),
        ConversationEvent.toolResultReceived(
          eventId: eid(),
          sessionId: session,
          sequence: 6,
          occurredAt: t0,
          toolCallId: toolId,
          messageId: const MessageId('a1'),
          result: const ToolResult.text(text: 'done'),
        ),
        // late progress after terminal is ignored
        ConversationEvent.toolExecutionProgress(
          eventId: eid(),
          sessionId: session,
          sequence: 7,
          occurredAt: t0,
          toolCallId: toolId,
          status: ToolExecutionStatus.running,
        ),
      ]);
      final t = s.toolCalls[toolId]!;
      expect(t.status, ToolExecutionStatus.succeeded);
      expect(t.result, isA<TextToolResult>());
      expect(s.messageById(const MessageId('a1'))!.toolCallIds, [toolId]);
    });

    test('permission requests are de-duplicated and resolvable', () {
      ConversationEvent perm(int seq) => ConversationEvent.permissionRequested(
        eventId: eid(),
        sessionId: session,
        sequence: seq,
        occurredAt: t0,
        requestId: 'p1',
        permission: NexaPermission.microphone,
      );
      var s = applyAll([started(1), perm(2), perm(3)]);
      expect(s.pendingPermissions.length, 1);
      s = reducer.resolvePermission(s, 'p1');
      expect(s.pendingPermissions, isEmpty);
    });
  });
}
