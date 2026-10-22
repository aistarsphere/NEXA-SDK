import 'package:nexa_core/nexa_core.dart';

const session = SessionId('s1');
final t0 = DateTime.utc(2026, 10, 22, 12);

int _n = 0;
EventId eid() => EventId('e${++_n}');

ConversationEvent started(int seq) => ConversationEvent.sessionStarted(
  eventId: eid(),
  sessionId: session,
  sequence: seq,
  occurredAt: t0,
  expiresAt: t0.add(const Duration(hours: 1)),
);

ConversationEvent assistantStarted(int seq, String id) =>
    ConversationEvent.assistantMessageStarted(
      eventId: eid(),
      sessionId: session,
      sequence: seq,
      occurredAt: t0,
      messageId: MessageId(id),
    );

ConversationEvent delta(
  int seq,
  String id,
  int index,
  String text, {
  EventId? eventId,
}) => ConversationEvent.assistantTextDelta(
  eventId: eventId ?? eid(),
  sessionId: session,
  sequence: seq,
  occurredAt: t0,
  messageId: MessageId(id),
  deltaIndex: index,
  text: text,
);

ConversationEvent completed(int seq, String id, {String? fullText}) =>
    ConversationEvent.assistantMessageCompleted(
      eventId: eid(),
      sessionId: session,
      sequence: seq,
      occurredAt: t0,
      messageId: MessageId(id),
      finishReason: FinishReason.stop,
      fullText: fullText,
    );

ConversationEvent failed(int seq, String id) => ConversationEvent.messageFailed(
  eventId: eid(),
  sessionId: session,
  sequence: seq,
  occurredAt: t0,
  messageId: MessageId(id),
  error: const EventError(code: 'boom', message: 'Boom', retryable: true),
);

ConversationEvent accepted(int seq, String clientId, String serverId) =>
    ConversationEvent.userMessageAccepted(
      eventId: eid(),
      sessionId: session,
      sequence: seq,
      occurredAt: t0,
      messageId: MessageId(serverId),
      clientMessageId: ClientMessageId(clientId),
    );

ConversationState applyAll(
  Iterable<ConversationEvent> events, [
  ConversationState state = ConversationState.initial,
]) {
  const reducer = ConversationReducer();
  return events.fold(state, reducer.reduce);
}
