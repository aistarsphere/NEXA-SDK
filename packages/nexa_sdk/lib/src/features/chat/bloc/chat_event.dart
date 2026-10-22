import 'package:nexa_core/nexa_core.dart';

/// Inputs to [ChatBloc]. Public ones come from the UI; the underscored ones
/// are internal (transport feedback).
sealed class ChatEvent {
  const ChatEvent();
}

/// Open the session and start listening for events.
final class ChatStarted extends ChatEvent {
  const ChatStarted();
}

/// User submitted text.
final class ChatMessageSent extends ChatEvent {
  const ChatMessageSent(this.text);
  final String text;
}

/// User asked to retry a failed message.
final class ChatMessageRetried extends ChatEvent {
  const ChatMessageRetried(this.clientMessageId);
  final ClientMessageId clientMessageId;
}

/// User tapped stop while the assistant was generating.
final class ChatGenerationCancelled extends ChatEvent {
  const ChatGenerationCancelled();
}

/// User acted on a rendered tool result.
final class ChatToolActionSubmitted extends ChatEvent {
  const ChatToolActionSubmitted(this.action);
  final ToolAction action;
}

/// User answered the in-app permission rationale.
final class ChatPermissionAnswered extends ChatEvent {
  const ChatPermissionAnswered({
    required this.requestId,
    required this.proceed,
  });
  final String requestId;

  /// True when the user agreed to be asked by the OS.
  final bool proceed;
}

/// Host or user ended the chat.
final class ChatEnded extends ChatEvent {
  const ChatEnded();
}

/// Transport delivered an event (internal).
final class ChatTransportEventReceived extends ChatEvent {
  const ChatTransportEventReceived(this.event);
  final ConversationEvent event;
}

/// Transport stream failed (internal).
final class ChatTransportFailed extends ChatEvent {
  const ChatTransportFailed(this.error);
  final NexaException error;
}

/// Transport stream closed without `sessionEnded` (internal).
final class ChatTransportClosed extends ChatEvent {
  const ChatTransportClosed();
}

/// Back-off elapsed; resubscribe to the event stream (internal).
final class ChatReconnectRequested extends ChatEvent {
  const ChatReconnectRequested();
}
