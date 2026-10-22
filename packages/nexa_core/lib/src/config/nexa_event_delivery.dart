/// How the SDK receives conversation events from the gateway.
///
/// Both modes carry the same `ConversationEvent` schema and the same
/// `after=<sequence>` resume cursor; only the HTTP mechanics differ.
enum NexaEventDelivery {
  /// `GET /events/stream` as Server-Sent Events (default). Lowest latency;
  /// one long-lived response per subscription.
  serverSentEvents,

  /// `GET /events?after&wait_ms` long-polling. Fallback for proxies that
  /// buffer or terminate streaming responses.
  longPolling,
}
