# Engineering assumptions and blockers

Updated 2026-10-22 (end of Phase 4.1). Resolve or re-confirm each item before the next phase.

## Assumptions made so far

| # | Assumption | Where it lives | How to revisit |
|---|---|---|---|
| A1 | The interactive prototype and Design QA 3.1 artefacts were **not available** in this environment. Colour tokens were derived from the written contract (Coffee & Mocha, M3). | `packages/nexa_ui/lib/src/theme/mocha_palette.dart` | Export tokens from the prototype and replace the palette file; contrast tests will catch regressions. |
| A2 | Gateway event delivery is SSE (`GET /events/stream`) with long-polling as fallback, both with a `sequence` cursor. The reference gateway implements both. | `GatewayChatTransport`, `NexaConfig.eventDelivery`, contract 0.2.0 | Backend confirms which it will ship; the SDK keeps both. |
| A3 | Session credentials are minted by the host's backend and are opaque bearer tokens with an expiry. No refresh-token flow on device. The reference gateway's `/v1/dev/session-tokens` stands in for the host backend. | `NexaAuthProvider`, `CredentialManager`, `HostAuthProvider` | Confirm token format/TTL with backend security review. |
| A4 | Tool execution is server-side; the SDK only renders results and returns actions; the gateway re-validates. | `ToolResult`/`ToolAction`, reference `POST /tool-actions` | Backend to confirm it never trusts client-side action payloads. |
| A5 | Text deltas may be coarse (GPU Manager exposes no documented token stream for `llm.chat`). The reference gateway streams word-sized deltas. | reducer handles both | Backend to confirm partial text in `JobEventOut.data`. |
| A6 | Supported UI languages are exactly `en` and `ar`. | `NexaConfig.supportedLanguageTags`, ARB files | Add ARB + enum entry when more are approved. |
| A7 | Map and media results render as static summaries (no map SDK or media player approved). | `_RouteBody`, `_MediaBody` | Pick providers; add widgets behind the same `ToolResult` types. |
| A8 | `freezed 3.2.6-dev.1` is acceptable because stable 3.2.5 cannot resolve with analyzer 12 required by retrofit/injectable generators. | root lockfile | Move to freezed 3.2.6 stable when published. |
| A9 | Automatic reconnect: 5 attempts, exponential back-off from `eventPollInterval` (750 ms) capped at 15 s; auth/expiry/quota are never auto-retried. | `ChatBloc`, `NexaConfig.maxReconnectAttempts` | Tune with product once real network data exists. |
| A10 | A gateway that answers `409 assistant_busy` is a contract violation the SDK never triggers (client-side `canSend` guard). | `ChatState.canSend` | Keep the server rule as backstop. |

## Blockers (cannot be closed by the SDK team alone)

| # | Blocker | Impact | Owner |
|---|---|---|---|
| B1 | **No NEXA gateway exists.** The SDK is validated over real HTTP/SSE against the **local reference gateway only** (`tools/nexa_reference_gateway`). | No production or staging integration can be claimed. | Backend |
| B2 | **No tenant/session-token contract.** GPU Manager has only service-to-service API keys; tenant registry, quotas, audit and session minting are undefined. The reference gateway's dev token endpoint is a placeholder. | Auth flow is validated against a placeholder issuer only. | Backend / Security |
| B3 | **No realtime voice channel.** GPU Manager is request/poll; `speech.synthesize` is not runnable. | Live voice is a state machine + mock only. Not touched in 4.1. | Backend / ML |
| B4 | **Prototype export missing.** Tokens, motion specs and component states are reconstructed from the written contract. | Visual fidelity unverified against QA 3.1. | Design |
| B5 | **Accessibility validation incomplete.** Automated baseline (contrast, semantics labels, live-region announcements, tap targets) exists; screen-reader and dynamic-type passes on devices are not done. | A11y certification pending. | Design + QA |
| B6 | No CI definition in this repository. `tool/check.sh` is the intended CI entry point; `tool/e2e.sh` needs a simulator. | Quality gates are manual. | Platform |
| B7 | Android: the example was built (`apk --debug`) but the e2e journey was executed on the iOS simulator only this session. | Android runtime behaviour verified by build + unit/widget tests, not by the on-device journey. | SDK |

## Explicit non-claims

* Not production ready. * No integration with a real NEXA backend. * No voice networking.
* The reference gateway is development infrastructure: no model, no GPU Manager, no persistence, no multi-tenant security.
* Mocks are labelled `MockChatTransport` / `MockRealtimeVoiceTransport` / `MockAuthProvider` and live in `package:nexa_core/testing.dart`.
