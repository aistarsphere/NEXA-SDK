# NEXA Phase 4.1 — Production Chat SDK Vertical Slice: Implementation Report

Date: 2026-10-22 · Toolchain: Flutter 3.44.4 (stable), Dart 3.12.2, macOS, Xcode 27, iOS simulator (iPhone 17 Pro Max), Android SDK.
Baseline at start: Phase 4 workspace, `./tool/check.sh` green (54 + 40 + 32 + 1 tests, 0 analyzer issues).

## 1. Status vocabulary (use these words, not others)

| Term | Meaning in this report |
|---|---|
| **Implemented SDK behaviour** | Code in `packages/`, covered by unit/widget tests |
| **Validated against the reference gateway** | Exercised over real sockets against `tools/nexa_reference_gateway` (local, scripted, no model) |
| **Proposed backend API** | `docs/contracts/nexa-gateway-api.proposed.yaml` 0.2.0-proposed; not confirmed by the backend team |
| **Missing production integration** | Needs a deployed NEXA gateway, tenant token minting, GPU-backed inference or a voice channel; none exist |

**No real NEXA gateway or staging environment exists.** Nothing in this phase is integration with a live backend.

## 2. What was built

### Backend strategy (spec §4): local executable reference gateway
`tools/nexa_reference_gateway` — pure Dart (shelf), workspace package, clearly labelled development infrastructure.
Implements the full proposed contract: dev token minting (stands in for the host backend), session create/end, SSE stream, long-poll, messages with idempotency, cancel, tool actions, permissions; error-code catalogue (401 missing/invalid/expired token, 402 quota, 403 application mismatch, 409 idempotency/busy/finished, 410 ended/expired, 422, 429 with retry-after, 503).
Keyword scenarios: `long`, `slow`, `fail`, `reject`, `interrupt` (SSE dropped after 3rd delta / 503 once on long-poll), `duplicate`, `ratelimit`, `quota`, `expire`, `weather`, `book`, `mic`; Arabic text for `ar` sessions.
It does **not** import `nexa_core`; its JSON is written from the contract fixtures, so SDK ↔ gateway tests are genuine contract tests. Run: `make gateway`.

### Contract (spec §2): 0.2.0-proposed, additive
Adds `GET /v1/sdk/sessions/{id}/events/stream` (SSE), the error catalogue, idempotency replay/conflict, `assistant_busy`, cancel semantics, and the rule that clients ignore unknown events. Versioning policy written into the document. Tenant/application identity is bound to the credential server-side; `X-Nexa-App-Id` mismatch is 403.

### SDK (spec §3, §6, §7)
* `GatewayChatTransport` rewritten: SSE primary (`decodeSse`, Dio stream, cancel token) with long-poll fallback via `NexaConfig.eventDelivery`; one attempt per subscription, errors mapped to `NexaException`.
* `ChatBloc`: sequential event processing; subscription generation guard; **reconnect policy** (back-off from `eventPollInterval`, cap 15 s, `NexaConfig.maxReconnectAttempts`, never for auth/expiry/quota); resume from `EventSequencer.lastApplied`; session expiry → fresh session on Retry; duplicate-submission guard via `ChatState.canSend` (pending ack, streaming, quota, connection).
* `ConversationEvent.tryParse` → `UnsupportedEvent` for unknown/invalid events (forward compatibility; sequencer never wedges).
* `CredentialManager`: adaptive refresh skew (`min(30 s, lifetime/4)`); Dio interceptor still retries once after 401. Tokens never logged (asserted by test).
* Error mapper: dart:io `HttpException` (dropped stream) → retryable `NetworkException`.

### UI (spec §5)
Streaming caret (`NexaStreamingCaret`, static under reduced motion), jump-to-latest (`NexaJumpToLatestButton`) with near-bottom auto-follow, `NexaLiveAnnouncer` live region (reconnecting/connected, assistant finished, message failed), banners for reconnecting / auth error / session expired / rate limited / quota (en + ar), keyboard handling (dismiss on drag, bottom inset for Scaffold-less hosts), retry disabled while another send is pending. Mocha tokens unchanged.

### Example app (spec §3)
Talks to the reference gateway over real HTTP/SSE by default (`http://127.0.0.1:8080`, Android emulator `10.0.2.2`); `HostAuthProvider` mints tokens from the dev endpoint exactly as a host backend call would; settings page can shorten token TTL to demonstrate renewal; home page shows gateway health and scenario keywords; `--dart-define=NEXA_USE_MOCK=true` keeps the labelled mock path. iOS deployment target raised to 15.0.

## 3. Checks run

| Check | Result |
|---|---|
| `dart format` (packages, apps, tools) | clean |
| `flutter analyze packages apps tools` (strict) | 0 issues |
| `dart test` nexa_core | 58 passed (+ `tryParse`/unsupported, adaptive skew) |
| `dart test` nexa_reference_gateway | 24 passed (every endpoint/scenario over dart:io sockets) |
| `flutter test` nexa_ui | 45 passed (+ caret, jump button, announcer) |
| `flutter test` nexa_sdk | 78 passed: 22 **contract/integration tests over real HTTP against the reference gateway** (SSE + long-poll journeys, interruption + reconnect, duplicates, 503, server gone, 429 retry with same idempotency key, rapid double send, upstream failure, proactive renewal, 401 forced refresh, auth failure + recovery, cross-application token rejected, no token in logs, quota → 402, expiry, tool round trips); SSE decoder; reconnect-policy / duplicate-guard bloc tests; widget state tests (banners en/ar, caret, jump-to-latest, unmount mid-stream, language + theme switch with content, live announcements) |
| `flutter test` nexa_example | 1 passed (mock journey) |
| `flutter build apk --debug` nexa_example | built |
| `tool/e2e.sh` (example `integration_test/` on the iOS simulator against the reference gateway) | see §4 |

## 4. On-device journey (acceptance evidence)

`apps/nexa_example/integration_test/chat_journey_test.dart` runs the host app on the simulator against `make gateway`: token mint → session → send → incremental stream → stop → retry after 429 → interrupt + reconnect → quota ended state → close → dispose, asserting lifecycle events.

Result this session: **passed** on the iPhone 17 Pro Max simulator (`00:08 +1: All tests passed!`). Gateway request log for the run: token mint 201 → session 201 → SSE stream 200 → messages 202 ×2 → cancel 202 → message 429 → retry 202 → interrupt 202 → second SSE stream 200 (reconnect) → quota 202. Earlier attempts failed only on test-harness issues (iOS deployment target 13 → 15, fake IME not registered in the integration binding, ambiguous close-button finder); the last of those exposed a real UX bug — the fullscreen-dialog route added a second unlabelled close button — fixed in `NexaChatScreen`.

## 5. Honest status against the acceptance criteria

| Criterion | Status |
|---|---|
| Example host app runs | Yes — iOS simulator (journey test), Android debug APK built (not launched) |
| SDK opens a real embedded chat | Yes (modal + embedded) |
| Message travels over a working HTTP/stream connection | Yes — **to the local reference gateway** (SSE and long-poll). No staging gateway exists |
| Responses stream back incrementally | Yes (word-sized deltas; partial text asserted before completion) |
| Stop, retry, auth errors, quota states | Yes, validated against the reference gateway and in widget tests |
| Safe to embed in third-party apps | Isolated DI container, own theme/l10n scope, no secrets in config, token redaction, no global state except `Nexa._client`; no new host-facing API beyond `NexaConfig.eventDelivery` / `maxReconnectAttempts` |
| Mocha identity preserved | Yes (tokens untouched; contrast tests unchanged) |
| Tests and static checks pass | Yes (`./tool/check.sh`) |

**Not claimed:** production readiness; integration with a real NEXA backend; GPU-backed inference; realtime voice; billing. Mocked-transport tests are reported as such; reference-gateway tests are reported as "validated against the reference gateway", never as service integration.

## 6. Blockers (owner) — see `.ai/assumptions-and-blockers.md`

B1 no gateway (Backend) · B2 no tenant/session-token contract (Backend/Security) · B3 no realtime channel / TTS (Backend/ML) · B4 prototype export missing (Design) · B5 device-level a11y validation (Design+QA) · B6 no CI (Platform) · B7 Android journey not executed on device this session (SDK).

## 7. Next steps

1. Backend confirms contract 0.2.0 and deploys a dev gateway; run `packages/nexa_sdk/test/integration` against it (switch the base URI) and flip status to "validated against staging".
2. CI: `tool/check.sh` on every push; nightly `tool/e2e.sh` on a simulator.
3. Replace `mocha_palette.dart` from the prototype export; rerun contrast tests.
4. Realtime voice remains interface + mock until the channel decision (unchanged from Phase 4).
