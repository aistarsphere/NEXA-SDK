# NEXA Flutter SDK — Architecture (source of truth)

Last updated: 2026-10-22 (Phase 4.1). Read this before changing any package.
Companion files: `.ai/assumptions-and-blockers.md`, `docs/adr/`, `docs/contracts/`.

## 1. Workspace and package boundaries

```
chat-boot-sdk/                 pub workspace (Dart ≥3.12, Flutter ≥3.44); one root lockfile
├─ packages/nexa_core          pure Dart contracts (NO flutter import)
├─ packages/nexa_ui            design system + localisation + chat components (flutter, no networking)
├─ packages/nexa_sdk           public SDK: facade, DI, session, chat orchestration, gateway transport, screens
├─ apps/nexa_example           host app (go_router) showing integration; never a dependency of anything
├─ tools/nexa_reference_gateway DEV INFRASTRUCTURE: local executable reference gateway (shelf); test dependency of nexa_sdk only
├─ docs/contracts              GPU Manager export (authoritative), PROPOSED gateway (0.2.0) + realtime contracts, fixtures
└─ tool/                       bootstrap.sh, gen.sh, check.sh, gateway.sh, e2e.sh (+ Makefile)
```

**Status vocabulary used in this document and in reports** (keep them distinct):
* *Implemented Flutter SDK behaviour* — code in `packages/`, covered by unit/widget tests.
* *Reference gateway behaviour* — `tools/nexa_reference_gateway`: scripted, in-memory, no model; defines what "validated" means today.
* *Proposed backend API* — `docs/contracts/nexa-gateway-api.proposed.yaml`; unconfirmed by the backend team.
* *Missing production integration* — anything that needs a deployed gateway, tenant auth, GPU-backed inference or voice (see `.ai/assumptions-and-blockers.md`).

**Dependency direction (enforced by pubspecs):** `nexa_sdk → nexa_ui → nexa_core`.
Never import `nexa_sdk` from `nexa_ui`/`nexa_core`; never import Flutter in `nexa_core`.

| Package | Owns | Must not contain |
|---|---|---|
| `nexa_core` | `NexaConfig`, `NexaAuthProvider`/`SessionCredential`/`CredentialManager`, `NexaException` hierarchy, typed ids, `ConversationEvent`/`ConversationState`/`ConversationReducer`/`EventSequencer`, `ToolResult`/`ToolAction`/`ToolResultValidator`, `ChatTransport`, `RealtimeVoiceTransport` (proposed), `VoiceSessionMachine`, logging + lifecycle events, `testing.dart` mocks | widgets, Dio, platform code |
| `nexa_ui` | `MochaPalette` (single token file), `NexaTheme`, `NexaColors` extension, shapes, motion, typography, `NexaLocalizations` (gen-l10n, en/ar), `NexaLocale`, components (`NexaMessageBubble`, `NexaComposer`, `NexaToolResultCard`, `NexaToolCallTile`, `NexaStatusBanner`, `NexaTypingIndicator`, permission sheet) | blocs, transports, JSON parsing |
| `nexa_sdk` | `Nexa`/`NexaClient` facade, `NexaOverrides`, `NexaPermissionHandler`, DI (`buildSdkInjector`, `SdkModule`), `SessionManager`, `ChatBloc` (incl. reconnect policy), `NexaChatView`/`NexaChatScreen`, `GatewayChatTransport` (SSE + long-poll) + `decodeSse` + DTOs + Retrofit API + Dio factory + error mapper | design tokens, provider payload parsing |
| `nexa_reference_gateway` | shelf server implementing the proposed contract with scripted replies and chaos switches; dev token endpoint standing in for the host backend | any import of `nexa_core` (its JSON is written from the contract so tests are real contract tests), anything deployable |

Why not `nexa_tools` / `nexa_realtime` packages: both are small pure-Dart contracts versioned with the core event model. Split `nexa_realtime` out **only** when a concrete transport (WebSocket/WebRTC/audio) introduces platform dependencies that text-only hosts should not pay for.

Versioning: all packages share `0.1.0` and move together until the gateway contract is confirmed; afterwards `nexa_sdk` is the only package with a public semver promise (`nexa_core`/`nexa_ui` are implementation detail re-exported through it).

## 2. Selected libraries (resolved versions in root `pubspec.lock`)

flutter_bloc 9.1 / bloc 9 · dio 5.11 · retrofit 4.10 (+generator 10.3) · freezed 3.2.6-dev.1 (stable 3.2.5 is incompatible with analyzer 12 required by the generators) + json_serializable 6.15 · get_it 9.3 + injectable 3.0 (+generator 3.1.3) · build_runner 2.15 (2.17 conflicts with injectable_generator) · go_router 18.1 (example only) · clock, uuid, intl, mocktail, bloc_test. Lints: `flutter_lints` + strict analyzer modes + workspace rules in root `analysis_options.yaml` (packages include it; only tighten).

shelf 1.4 + shelf_router (reference gateway only). Rules: no second HTTP or state-management stack. No `GetIt.instance`: the SDK builds `GetIt.asNewInstance()` per client (`sdk_injector.dart`). No global singletons except `Nexa._client`.

## 3. Public API rules (nexa_sdk)

* Everything public is exported from `package:nexa_sdk/nexa_sdk.dart` (re-exports `nexa_core` and the two host-facing `nexa_ui` types). Anything under `src/` not exported is private; the example app must compile against the public surface only (except `package:nexa_core/testing.dart`, which is mock-only).
* Host lifecycle: `Nexa.initialize(config, auth, overrides) → NexaClient` → `startSession()` / `openChat(context)` / `chatView()` → `endSession()` → `dispose()`. Double `initialize` throws; use after `dispose` throws `NotInitializedException`.
* Errors reach hosts only as `NexaException` subtypes (sealed, switch-exhaustive) and as `NexaErrorOccurred` on `lifecycle`.
* Secrets: `NexaConfig` has no credential field and rejects credential-looking metadata. Only `NexaAuthProvider.fetchSessionCredential()` supplies authorisation, as a short-lived opaque token minted by the host's backend. The SDK keeps it in memory only (no persistence).
* Permissions: the SDK never calls platform permission APIs; it renders a rationale sheet and delegates to `NexaPermissionHandler` (host). Default denies.
* Navigation: `openChat` uses a plain `MaterialPageRoute`; the SDK never depends on go_router or assumes a host router.
* Theming knobs for hosts are exactly `NexaThemeOverrides` (seed colour, user bubble colour, corner scale 0.5–1.25, brightness) plus `setLanguage`/`setThemeMode`. Nothing else is overridable.

## 4. Feature structure and state conventions

```
nexa_sdk/lib/src/
  nexa.dart                      facade (public)
  di/                            injectable module + injector
  session/session_manager.dart   one active session, lifecycle stream
  data/gateway/                  DTOs, Retrofit API, GatewayChatTransport
  data/network/                  DioFactory (auth/request-id/log interceptors), error mapper
  features/chat/bloc/            ChatBloc, ChatEvent (sealed), ChatState
  features/chat/presentation/    NexaChatView (embeddable), NexaChatScreen (modal)
  permissions/                   NexaPermissionHandler
```

* Feature-first; `data/domain/presentation` folders appear only when a feature has all three (chat has bloc + presentation; the domain logic is the pure reducer in `nexa_core`).
* BLoC for screens with event streams (`ChatBloc`); Cubit is acceptable for simple local UI state. Events are sealed classes; state is an immutable class with `copyWith`.
* `ChatBloc` processes its events **sequentially** (shared FIFO transformer) except the permission round-trip; subscriptions carry a generation id so stale callbacks are dropped.
* **Reconnect policy (bloc, not transport):** a subscription makes one attempt; on a retryable failure or a close before `session_ended` the bloc enters `ChatConnection.reconnecting`, waits `eventPollInterval × 2^(n-1)` (cap 15 s) and resubscribes from `EventSequencer.lastApplied`, up to `NexaConfig.maxReconnectAttempts`; then `disconnected` + retryable error with a user Retry. `AuthenticationException`, `SessionExpiredException` and `QuotaExceededException` are never auto-retried; expiry marks the session ended so Retry starts a fresh one.
* **Duplicate submission:** `ChatState.canSend` is false while a user message is pending acknowledgement, while the assistant streams, when quota is exceeded, or when not connected. Composer, retry affordance and bloc all gate on it; retries reuse `client_message_id` (gateway idempotency).
* All conversation mutations go through `ConversationReducer`. Blocs never edit messages. Widgets never parse JSON.
* Time via `package:clock`; ids via `uuid`; both injectable for tests.

## 5. Conversation event semantics

* `ConversationEvent` is a sealed freezed union, wire discriminator `type` (snake_case), snake_case keys, enum values snake_case. Every variant carries `event_id` (global dedupe key), `session_id`, `sequence` (gateway-assigned, strictly increasing from 1 per session), `occurred_at`.
* `EventSequencer` rules: duplicate if `sequence ≤ lastApplied` or `event_id` seen; apply when contiguous; buffer early events up to `reorderWindow` (64); on overflow apply lowest buffered and report `gapSkipped` → `ChatBloc` resubscribes from `lastApplied` (resync).
* `ConversationReducer` rules: duplicate delta (`delta_index ≤ last`) ignored; late delta after terminal ignored; delta before `assistant_message_started` creates a placeholder; `full_text` on completion is authoritative; failure after completion wins; cancel after completion ignored; retries reuse `client_message_id` and never duplicate bubbles; `session_ended` cancels streaming and fails pending.
* Tool results are validated on deserialisation (`ToolResultValidator`); malformed payloads become `ToolResult.error(code: invalid_tool_result)` and render as a generic error card. Allowed media/image URI scheme: https only.
* Unknown event types or invalid payloads that still carry the envelope (`event_id`, `session_id`, `sequence`, `occurred_at`) become `UnsupportedEvent` via `ConversationEvent.tryParse`; the reducer ignores them and the cursor advances (forward compatibility). Envelope-less garbage is dropped and logged.

## 6. Backend contract boundaries

* **Authoritative:** `docs/contracts/gpu-manager-api.v1.2.0.json` — request/poll job API, service-to-service bearer key, no tenant/user concept, no push channel, no runnable TTS. The SDK never calls it.
* **Proposed 0.2.0, validated against the reference gateway only:** `docs/contracts/nexa-gateway-api.proposed.yaml` — sessions, SSE stream + long-poll events, messages with `Idempotency-Key`, tool-actions, permissions, cancel, end, error-code catalogue. `GatewayChatTransport` is exercised over real sockets in `packages/nexa_sdk/test/integration` (both delivery modes, interruption, duplication, cancel, 429 retry, auth renewal, 401 forced refresh, quota, expiry, disposal) and in `apps/nexa_example/integration_test` on a simulator. Status flips to "validated against staging" only after the same tests pass against a deployed gateway.
* **Auth:** `CredentialManager` refreshes proactively within `min(30 s, lifetime/4)` of expiry; the Dio auth interceptor retries exactly once after a 401 with a force-refreshed credential. Tokens are never logged (`SessionCredential.toString` redacts; the log interceptor logs paths only; an integration test asserts no token appears in `MemoryNexaLogger`).
* **Proposed (interface + mock only):** `docs/contracts/nexa-realtime-voice.proposed.md`.
* Boundary mapping (gateway responsibilities, not SDK): see `docs/contracts/gpu-manager-boundary.md`.

## 7. Realtime voice status

`VoiceSessionMachine` (pure, total, tested for every state×event pair) + `RealtimeVoiceTransport` interface + `MockRealtimeVoiceTransport`. **No audio capture, playback, VAD or network implementation exists.** Do not add a voice UI that implies otherwise. Next step requires the gateway channel decision (codec, VAD location, TTS engine).

## 8. Localization and theme rules

* Strings live in `packages/nexa_ui/lib/l10n/nexa_{en,ar}.arb`; run `flutter gen-l10n` in `nexa_ui` (generated files are committed under `lib/l10n/generated`). Never hard-code user-facing text in widgets.
* `NexaChatView` installs its own `Localizations` + `Directionality` + `Theme` scope → works in any host, with or without host localisation. Hosts may additionally add `NexaLocale.delegates` to their `MaterialApp` if they use SDK components directly.
* RTL: use `AlignmentDirectional`, `BorderRadiusDirectional`, `EdgeInsetsDirectional`, `CrossAxisAlignment.start/end`; never `left/right`.
* Tokens: change colours only in `mocha_palette.dart`; `theme_contrast_test.dart` enforces ≥4.5:1 for text pairs in both modes. Fonts are bundled (Noto Sans, Tajawal, OFL) via `NexaTypography`; never google_fonts at runtime.
* Motion: use `NexaMotion.of(context, duration)` so reduced-motion collapses animations; `NexaTypingIndicator` and `NexaStreamingCaret` are static under reduced motion.
* Touch targets ≥48dp (theme-level minimum sizes), semantics labels on bubbles/buttons, live regions on status banners, and `NexaLiveAnnouncer` for state announcements (reconnecting/connected, assistant finished, message failed). No `SemanticsService.announce`.
* Scrolling: the list auto-follows only while pinned near the bottom (72 dp); otherwise `NexaJumpToLatestButton` appears when new content lands. A user's own send always scrolls. Keyboard: `keyboardDismissBehavior.onDrag` and bottom view-inset padding for hosts without a Scaffold.

## 9. Testing requirements (all must stay green: `tool/check.sh`)

| Layer | Location | Covers |
|---|---|---|
| Unit (VM) | `nexa_core/test` | reducer ordering/dup/late/retry, sequencer, voice machine (incl. totality), validator, credential manager, config, mock transport |
| Contract | `nexa_core/test/contracts` + `docs/contracts/fixtures` | every event/action variant round-trips; fixtures parse |
| Theme/a11y | `nexa_ui/test/theme` | contrast baseline, bundled fonts, override bounds, touch targets |
| Widget | `nexa_ui/test/components` | bubble LTR/RTL, retry, typing + reduced motion, composer, every tool card, forms/selection/confirmation actions |
| SDK unit/widget | `nexa_sdk/test` | init/dispose/lifecycle, error mapper, SSE decoder, gateway transport vs mocked API, ChatBloc flows (send/retry/cancel/tool/permission/quota/error), reconnect policy + budget + auth/expiry handling, duplicate-submission guard, chat view embedding, banners (reconnecting/auth/expired/quota, en+ar), streaming caret, jump-to-latest, unmount mid-stream, runtime language/theme, openChat, semantics |
| SDK ↔ gateway contract | `nexa_sdk/test/integration` (starts `ReferenceGateway` on port 0) | real HTTP: SSE and long-poll journeys, interruption + reconnect, duplicates, 503, server gone, 429 retry, rapid double send, upstream failure, proactive renewal, 401 forced refresh, auth failure + recovery, cross-application token, no token in logs, quota, expiry, tool round trips |
| Reference gateway | `tools/nexa_reference_gateway/test` | every endpoint and scenario over dart:io sockets (auth codes, idempotency, SSE drop/resume, duplicates, cancel, quota, end, tools, permissions) |
| Example | `apps/nexa_example/test` (mock) and `integration_test/` (device + reference gateway via `tool/e2e.sh`) | host opens modal chat; full on-device journey: token mint, session, stream, stop, retry after 429, interrupt + reconnect, quota, dispose |

Integration tests against the reference gateway are **not** service integration tests; report them as "validated against the reference gateway".

New behaviour needs a test at the lowest layer that can express it. Transport changes need a contract fixture update.

## 10. Environments

`NexaEnvironment.{development,staging,production}` only tunes defaults (verbose logging allowed outside production; https enforced in production; mock transport warns outside development). Gateway base URLs are host-supplied (`NexaConfig.gatewayBaseUri`) because no environment exists yet; once they do, add `NexaEnvironment.defaultGatewayUri` and keep the override.

Local development: `make gateway` runs the reference gateway on 127.0.0.1:8080; the example app defaults to it (Android emulators use 10.0.2.2). `--dart-define=NEXA_GATEWAY_URL=...` overrides, `--dart-define=NEXA_USE_MOCK=true` uses the in-memory mock. `make e2e` (or `tool/e2e.sh <device>`) runs the on-device journey.

## 11. Codegen and tooling

`tool/bootstrap.sh` (pub get) → `tool/gen.sh` (build_runner in core + sdk, gen-l10n in ui) → `tool/check.sh` (format, analyze, all tests incl. the reference-gateway contract tests) → `tool/e2e.sh` (device journey). Generated files are committed so a fresh clone builds without running generators.
