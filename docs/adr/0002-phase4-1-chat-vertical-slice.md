# ADR 0002 — Phase 4.1 Chat Vertical Slice: reference gateway, SSE transport, reconnect policy

Date: 2026-10-22 · Status: accepted (Phase 4.1) · Supersedes parts of ADR 0001 §6

## Context

Phase 4 delivered the architecture and a mock-only conversation path. Phase
4.1 must make a message travel over a real HTTP/stream connection, with stop,
retry, reconnect, auth-expiry and quota behaviour, without a NEXA backend
existing. Tests had to prove the SDK's transport against something other
than its own mocks.

## Decisions

1. **Local reference gateway as development infrastructure**
   (`tools/nexa_reference_gateway`, pure Dart, shelf). It implements the
   proposed contract with deterministic keyword-scripted replies and chaos
   switches (dropped stream, duplicated events, 429/503 once, quota, expiry).
   It deliberately does **not** import `nexa_core`: its JSON is hand-written
   from the contract fixtures, so SDK ↔ gateway tests are genuine contract
   tests rather than the SDK serialising to itself. It is a workspace
   package so the SDK's integration tests can start it in-process on port 0.
   It is *not* a backend: no model, no GPU Manager, no persistence, no
   tenant security. A dev-only `POST /v1/dev/session-tokens` stands in for
   the host backend's token minting and is called only by host-side code
   (`HostAuthProvider`, `ReferenceAuthProvider`), never by the SDK.

2. **Contract 0.2.0-proposed (additive).** Adds `GET /events/stream`
   (Server-Sent Events, same schema, same `after` cursor), an error-code
   catalogue, idempotency replay/conflict semantics, `assistant_busy`,
   `already_finished`, `not_awaiting_action`, and the rule that clients
   ignore unknown event types. Versioning policy is written into the
   document.

3. **SSE primary, long-poll fallback** selected by
   `NexaConfig.eventDelivery`. One Dio instance; the stream endpoint uses
   `ResponseType.stream` with no receive timeout and a `CancelToken`.
   `decodeSse` is a small pure-Dart decoder (unit-tested, including the
   `Stream<Uint8List>` covariance pitfall).

4. **Reconnect policy lives in `ChatBloc`, not in the transport.** A
   subscription makes one attempt and ends with a `NexaException`; the bloc
   enters `reconnecting`, resubscribes from `EventSequencer.lastApplied`
   with exponential back-off (`eventPollInterval × 2^n`, cap 15 s) up to
   `NexaConfig.maxReconnectAttempts`, then surfaces a retryable error with a
   user Retry. Auth, session-expiry and quota errors are never auto-retried.
   Rationale: the policy is testable with in-memory transports via
   `bloc_test`-style tests, visible to the UI as a first-class state, and
   independent of the delivery mechanism.

5. **Sequential event processing in `ChatBloc`.** bloc's default concurrent
   transformer let a send, a transport event and a reconnect interleave.
   All handlers except the permission round-trip (which awaits a host
   dialog) share one FIFO. Subscriptions carry a generation id so callbacks
   from a superseded subscription (e.g. the `onDone` after an `onError`) are
   ignored.

6. **Forward-compatible event parsing.** `ConversationEvent.tryParse` maps
   unknown or invalid events that still carry the common envelope to
   `UnsupportedEvent`, which the reducer ignores. Without this a single new
   event type from a newer gateway would wedge the sequencer with a permanent
   gap.

7. **Adaptive credential refresh skew.** `CredentialManager` shrinks its
   30 s proactive-refresh window to a quarter of the credential lifetime so
   short-lived tokens are not re-minted on every call. 401 still triggers one
   forced refresh and a single retry.

8. **Duplicate-submission guard** is `ChatState.canSend`, which also covers
   a user message that is pending acknowledgement; the composer, the retry
   affordance and the bloc all gate on it, and the gateway enforces
   idempotency keys as the server-side backstop.

## Consequences

* "Validated against the reference gateway" is the strongest claim this
  phase can make. Nothing is validated against a production or staging
  gateway because none exists (blocker B1 stands).
* When the backend ships, `GatewayChatTransport` should need no change if the
  contract is honoured; the reference gateway's test-suite doubles as the
  acceptance checklist for the real implementation.
* The reference gateway must never be deployed. Its README and every file
  header say so.
