/// Capabilities a host app may request. The gateway grants the intersection of
/// what the host requested, what the tenant plan permits, and what the
/// platform currently supports. Never assume a requested capability is granted;
/// read `SessionHandle.grantedCapabilities`.
enum NexaCapability {
  /// Text conversation (always requested implicitly).
  textChat,

  /// Record and send voice messages (asynchronous speech.transcribe path).
  voiceMessages,

  /// Low-latency live voice conversation (requires the proposed realtime gateway).
  liveVoice,

  /// Assistant may request tool calls that the SDK renders and the user acts on.
  toolCalling,

  /// Assistant may return rich structured results (cards, maps, media, forms).
  richResults,

  /// User may attach images/files to messages.
  attachments,
}
