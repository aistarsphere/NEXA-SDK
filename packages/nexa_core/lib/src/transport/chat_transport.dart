import 'package:nexa_core/src/auth/session_credential.dart';
import 'package:nexa_core/src/config/nexa_capability.dart';
import 'package:nexa_core/src/conversation/conversation_event.dart';
import 'package:nexa_core/src/ids/ids.dart';
import 'package:nexa_core/src/session/session_handle.dart';
import 'package:nexa_core/src/tools/tool_action.dart';

/// Outgoing user message.
final class OutgoingMessage {
  const OutgoingMessage({
    required this.clientMessageId,
    this.text,
    this.languageTag,
    this.attachments = const [],
    this.uiEvent,
  });

  /// Idempotency key; identical across retries of the same message.
  final ClientMessageId clientMessageId;

  /// `text` and/or [uiEvent] (labeeb.sdk/1 `POST /messages`).
  final String? text;

  /// Language hint for the backend (`en`, `ar`).
  final String? languageTag;

  /// Up to 4 uploaded asset ids (`ast_*`).
  final List<String> attachments;

  /// A `nexa.ui/1` touch event (`NexaUiEvent.toJson`).
  final Map<String, Object?>? uiEvent;
}

/// Transport-independent contract between the SDK and the NEXA gateway for
/// text conversations.
///
/// Implementations:
/// * `GatewayChatTransport` (nexa_sdk) - HTTP + event polling against the
///   **proposed** gateway API. Unvalidated until a gateway exists.
/// * `MockChatTransport` (nexa_core/testing) - deterministic in-memory mock
///   for tests and demos. Never production.
///
/// All methods throw `NexaException` subtypes on failure.
abstract interface class ChatTransport {
  /// Opens a session. [credential] is the short-lived server-issued token.
  Future<SessionHandle> startSession({
    required SessionCredential credential,
    required Set<NexaCapability> requestedCapabilities,
    required String languageTag,
    Map<String, String> clientMetadata = const {},

    /// labeeb.sdk/1 device tool names this client can run.
    List<String> clientTools = const [],

    /// labeeb.sdk/1: join this server-owned conversation.
    String? conversationId,
  });

  /// Ordered event stream for [sessionId], starting after [afterSequence].
  /// Implementations may deliver out-of-order or duplicate events; the SDK's
  /// `EventSequencer` normalises them. The stream closes after
  /// `sessionEnded` or on unrecoverable failure (as an error).
  Stream<ConversationEvent> events(
    SessionId sessionId, {
    int afterSequence = 0,
  });

  /// Sends a user message. Returns once the gateway accepted the request;
  /// the `userMessageAccepted` event follows on [events].
  Future<void> sendMessage(SessionId sessionId, OutgoingMessage message);

  /// Returns a user action for a rendered tool result.
  Future<void> submitToolAction(SessionId sessionId, ToolAction action);

  /// Answers a `permissionRequested` event.
  Future<void> reportPermissionResult(
    SessionId sessionId, {
    required String requestId,
    required bool granted,
  });

  /// Requests cancellation of an in-progress assistant message.
  /// Confirmation arrives as `messageCancelled`.
  Future<void> cancelMessage(SessionId sessionId, MessageId messageId);

  /// Ends the session. Idempotent.
  Future<void> endSession(SessionId sessionId);

  /// Releases resources. The transport is unusable afterwards.
  Future<void> dispose();
}
