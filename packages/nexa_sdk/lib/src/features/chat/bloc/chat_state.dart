import 'package:meta/meta.dart';
import 'package:nexa_core/nexa_core.dart';

/// Connection status of the event stream.
enum ChatConnection { idle, connecting, connected, reconnecting, disconnected }

/// Presentation state for the chat screen: the reduced conversation plus
/// UI-only bookkeeping.
@immutable
final class ChatState {
  const ChatState({
    this.conversation = ConversationState.initial,
    this.connection = ChatConnection.idle,
    this.resolvedToolCalls = const {},
    this.reconnectAttempt = 0,
    this.error,
  });

  /// Reduced conversation (messages, tool calls, quota...).
  final ConversationState conversation;

  final ChatConnection connection;

  /// Tool calls the user already acted on (controls disabled).
  final Set<ToolCallId> resolvedToolCalls;

  /// Current automatic reconnect attempt (0 when connected).
  final int reconnectAttempt;

  /// Last session-level error to surface, if any.
  final NexaException? error;

  /// A user message was sent but the gateway has not acknowledged it yet.
  /// Blocks a second send so one tap cannot produce two messages.
  bool get hasPendingUserMessage =>
      conversation.messages.any((m) => m.status == MessageStatus.pending);

  /// True while the user can type and send.
  bool get canSend =>
      connection == ChatConnection.connected &&
      conversation.canSend &&
      !hasPendingUserMessage;

  /// Streaming assistant message, if any.
  ChatMessage? get generating => conversation.streamingMessage;

  ChatState copyWith({
    ConversationState? conversation,
    ChatConnection? connection,
    Set<ToolCallId>? resolvedToolCalls,
    int? reconnectAttempt,
    NexaException? error,
    bool clearError = false,
  }) => ChatState(
    conversation: conversation ?? this.conversation,
    connection: connection ?? this.connection,
    resolvedToolCalls: resolvedToolCalls ?? this.resolvedToolCalls,
    reconnectAttempt: reconnectAttempt ?? this.reconnectAttempt,
    error: clearError ? null : (error ?? this.error),
  );
}
