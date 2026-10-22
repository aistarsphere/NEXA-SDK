/// Typed identifiers.
///
/// Extension types give compile-time safety (a [MessageId] cannot be passed
/// where a [SessionId] is expected) with zero runtime cost. They serialise as
/// plain strings, which keeps the wire contracts simple.
library;

import 'package:json_annotation/json_annotation.dart';

/// Identifier of a chat session issued by the NEXA gateway.
extension type const SessionId(String value) {
  /// Returns the wire form.
  String toJson() => value;

  /// Parses the wire form.
  static SessionId fromJson(String json) => SessionId(json);
}

/// Identifier of a message within a session.
extension type const MessageId(String value) {
  /// Returns the wire form.
  String toJson() => value;

  /// Parses the wire form.
  static MessageId fromJson(String json) => MessageId(json);
}

/// Client-generated idempotency key for a user message. Stable across retries.
extension type const ClientMessageId(String value) {
  /// Returns the wire form.
  String toJson() => value;

  /// Parses the wire form.
  static ClientMessageId fromJson(String json) => ClientMessageId(json);
}

/// Identifier of a tool call requested by the assistant.
extension type const ToolCallId(String value) {
  /// Returns the wire form.
  String toJson() => value;

  /// Parses the wire form.
  static ToolCallId fromJson(String json) => ToolCallId(json);
}

/// Globally unique identifier of a conversation event (used for de-duplication).
extension type const EventId(String value) {
  /// Returns the wire form.
  String toJson() => value;

  /// Parses the wire form.
  static EventId fromJson(String json) => EventId(json);
}

/// JSON converter for [SessionId]. Applied on fields of generated models.
final class SessionIdConverter implements JsonConverter<SessionId, String> {
  const SessionIdConverter();
  @override
  SessionId fromJson(String json) => SessionId(json);
  @override
  String toJson(SessionId object) => object.value;
}

/// JSON converter for [MessageId].
final class MessageIdConverter implements JsonConverter<MessageId, String> {
  const MessageIdConverter();
  @override
  MessageId fromJson(String json) => MessageId(json);
  @override
  String toJson(MessageId object) => object.value;
}

/// JSON converter for [ClientMessageId].
final class ClientMessageIdConverter
    implements JsonConverter<ClientMessageId, String> {
  const ClientMessageIdConverter();
  @override
  ClientMessageId fromJson(String json) => ClientMessageId(json);
  @override
  String toJson(ClientMessageId object) => object.value;
}

/// JSON converter for [ToolCallId].
final class ToolCallIdConverter implements JsonConverter<ToolCallId, String> {
  const ToolCallIdConverter();
  @override
  ToolCallId fromJson(String json) => ToolCallId(json);
  @override
  String toJson(ToolCallId object) => object.value;
}

/// JSON converter for [EventId].
final class EventIdConverter implements JsonConverter<EventId, String> {
  const EventIdConverter();
  @override
  EventId fromJson(String json) => EventId(json);
  @override
  String toJson(EventId object) => object.value;
}
