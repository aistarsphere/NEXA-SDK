# LABEEB Mobile — architectural memory (read before editing the app or the SDK)

Updated 2026-11-03. Companion files: `.ai/flutter-architecture.md` (SDK package rules, still authoritative for package boundaries), `.ai/assumptions-and-blockers.md` (B1–B13), `docs/adr/`.

Primary documents for the Beta (source of truth, in this order):
1. `docs/mobile/MOBILE_BETA_REQUIREMENTS.md` — requirements M-01…M-16 with status.
2. `docs/mobile/MOBILE_ARCHITECTURE_AUDIT.md` — evidence, findings F-xx, backend gaps G-xx.
3. `docs/mobile/MOBILE_MASTER_IMPLEMENTATION_PLAN.md` — tasks A-01…G-05 in execution order.
4. `docs/mobile/MOBILE_QA_MASTER_PLAN.md` — tests T-*, quality gates Q1–Q10.
5. `docs/mobile/MOBILE_IMPLEMENTATION_STATUS.md` — the checklist to update after every task.

This file is not a log. Record decisions and conventions here; record progress in the status file.

## 1. Product mission

LABEEB (لبيب) is an Arabic-first assistant with one persistent, server-owned conversation history. Text chat and live voice are modes of the same conversation. Android first (Xiaomi 25010PN30G / Android 16, Nubia NX679J / Android 13). Beta is a technical implementation against the AWS gateway; company admins and the app never select AI models (M-16).

## 2. Baseline

Flutter 3.44.4 stable, Dart 3.12.2; Gradle 9.1, AGP 9.0.1, Kotlin 2.3.20, compileSdk 36, minSdk 24, Java 17; livekit_client 2.13.1; ONNX Runtime Android 1.29.0. Pub workspace with one root lockfile; generated files committed (`tool/gen.sh`). Pins and quirks: freezed 3.2.6-dev.1, build_runner 2.15 (see memory `nexa-toolchain-quirks`).

## 3. Architecture: current and intended

Current: `apps/nexa_example` (LABEEB app: branding, auth provider, permissions, Android assistant bridge, dev tools) → `nexa_sdk` (client facade, DI per client, `SessionManager`, `ChatBloc`, `NexaVoiceController`, `LabeebToolCallController`, `NexaHistoryController`, views) → `nexa_ui`, `nexa_realtime`, `nexa_device`, `nexa_assistant` → `nexa_core` (pure contracts, reducers, voice machine, verifier, nexa.ui/1 parser). Dependency direction is enforced by pubspecs; `nexa_core` has no Flutter; `livekit_client` only in `nexa_realtime`; Kotlin only in `nexa_assistant`.

Intended (plan Phase A/B): add `ConversationCoordinator` (nexa_sdk) as the single owner of the conversation id; the app owns the route graph with go_router (`/`, `/c/:id`, `/c/:id/call`, `/settings`, `/settings/assistant`, dev `/dev/*`); the SDK exposes pages and callbacks, pushes only sheets/dialogs; an in-call foreground service lives in `nexa_assistant`; the legacy `NexaSurfaceController` renderer is removed after the theme picker moves to `nexa.ui/1`.

## 4. Coding conventions

* Lints: root `analysis_options.yaml` (strict casts/inference/raw types, `always_use_package_imports`, `require_trailing_commas`, `unawaited_futures`, `cancel_subscriptions`, `close_sinks`). `flutter analyze packages apps tools` must stay at zero issues.
* Errors reach UI/hosts only as sealed `NexaException`; map transport errors with `mapError`; switch on gateway `error.code` via `gatewayErrorCode`, never on messages.
* Time via `package:clock`, ids via `uuid`; both injectable in tests.
* Strings in `packages/nexa_ui/lib/l10n/nexa_{en,ar}.arb` only (`flutter gen-l10n`); app-only strings in `app_strings.dart` / `device_assistant_strings.dart`.
* Layout: `AlignmentDirectional`, `EdgeInsetsDirectional`, `BorderRadiusDirectional`; never `left/right`. Motion through `NexaMotion.of`. Touch targets ≥ 48 dp. Semantics labels on every control; live regions for state changes.
* Logging: never tokens, join tokens, keys, audio or message text. Diagnostics through `NexaDiagnostics` (`QaRecorder` in dev builds); content capture is per-session opt-in.
* Secrets: only `--dart-define-from-file=~/.nexa/nexa_dev.json`; no in-app token entry (owner decision).
* Tests at the lowest layer that can express the behaviour; transport changes need a contract fixture; device claims need evidence under `docs/qa/evidence/`.

## 5. Navigation conventions

One conversation id per route; at most one `/call` route; closing the call route ends the call and lands on `/c/:id`; history resume navigates to `/c/:id` and remounts the chat; the Android system panel is an overlay over the router (`DeviceAssistantPanelHost`) that drives the same `NexaVoiceController`; the lock gate covers everything until Android unlocks.

## 6. State management rules

`ChatBloc` (sequential FIFO, sealed events, reducer in `nexa_core`) for chat; `NexaVoiceController` + pure `VoiceSessionMachine` (the machine is the only source of the voice phase); `ChangeNotifier`/`ValueNotifier` for tool calls, history, media, coordinator. Do not add a second state-management stack. Widgets never parse JSON; blocs never edit messages directly.

## 7. Backend / API ownership

* `labeeb.sdk/1` v1.0.0 (`docs/contracts/labeeb-sdk-1/contract-1.0.0.json`, 35 endpoints): conversations, messages, voice-turns, assets, preferences, sessions (SSE/long-poll), tool calls, tools catalogue, assistant profile, voice sessions. Client: `LabeebSdkClient`, `GatewayChatTransport`, `GatewayVoiceProvisioner`.
* `nexa.voice.v1` handoff 1.0.0 (`docs/contracts/voice-v1/`): REST lifecycle + sealed Ed25519 events on LiveKit data topic `nexa.voice.events`, `resume` RPC. The client publishes no data packets and has no interrupt command; barge-in and turn detection are agent-side.
* Known gaps G-01…G-09 are listed in the audit §4; never work around them by inventing endpoints.
* Production gateway `https://52.58.22.19/nexa/api`; conversation ids are `conv_*`; `client_tools` ≤ 8; `client_turn_id` `[A-Za-z0-9._-]{1,64}`.

## 8. Realtime voice contracts (client view)

Create → join (mic only, `wss`) → `resume` handshake → states from verified events only → `DELETE` on every exit. Reconnect: `GET` → `POST …/token` → rejoin same identity → `resume(last_seq)`. Mute = `setMicrophoneEnabled(false)` (capture stops; `TrackMuted` to the server); plan E-01 adds a bounded grace (≤ 1.2 s) while the user's last utterance is being finalised. Voice turns persist server-side (`server_recorded` when tools are on, else client `voice-turns`).

## 9. Tool UI schema

`nexa.ui/1` only: 18 components, 4 actions (`send_ui_event`, `open_url`, `client_tool`, `dismiss`), 6 events, limits 200 nodes / depth 6 / 48 kB, https-only links, host `extensionTypes` for extra renderers. Selections go as `ui_event` on `POST /sessions/{id}/messages`; answers to device tools go once to `POST …/tool-calls/{id}/result`. Orchestration stays on AWS.

## 10. Environment and build

```bash
./tool/bootstrap.sh && ./tool/gen.sh && ./tool/check.sh
cd apps/nexa_example && flutter run -d <device> --profile --dart-define-from-file=$HOME/.nexa/nexa_dev.json --dart-define=NEXA_DEV_TOOLS=true
make gateway   # local reference gateway; make e2e for device journeys
cd apps/nexa_example/android && ./gradlew :nexa_assistant:testDebugUnitTest   # Kotlin tests
```
Defines: `NEXA_REAL_BACKEND`, `NEXA_GATEWAY_URL`, `NEXA_APP_ID`, `NEXA_LANGUAGE`, `NEXA_DEV_SDK_TOKEN(_EXPIRES_AT)`, `NEXA_USE_MOCK`, `NEXA_DEV_TOOLS`, `NEXA_LAUNCH_MODE`, `NEXA_SHOW_*`. Speaker model: `packages/nexa_assistant/tool/fetch_models.sh` (not committed). Release hardening is task G-03 (signing, no cleartext, bundle).

## 11. QA commands and gates

Q1 `flutter analyze packages apps tools`; Q3 `tool/check.sh` or the touched package's `flutter test`; Q4 Kotlin tests; Q5 `tool/e2e.sh <device> integration_test/<file>`; Q10 `packages/nexa_sdk/test/live/labeeb_live_test.dart` against production when a contract changes. Device evidence: `dart run tool/qa.dart pull|report`, `adb shell dumpsys audio`. Full matrix in the QA plan.

## 12. Known exceptions and platform facts

* Android 14+: a microphone foreground service cannot be created from the background; start it while an activity is visible (wake listener and the planned call service). Reboot/force-stop stop the wake listener; the app posts a notification.
* Hardware always-on hotword is privileged (preinstalled apps only); the software listener is the only option.
* The MFCC+DTW wake detector fails on real voices (5/5 rejected, 2026-10-30); it remains the fallback behind the `WakeDetector` interface until a trained Arabic model (Porcupine or self-trained) passes the benchmark.
* Speaker verification is a wake-gating convenience, never authorisation; no liveness.
* iOS: `inputMixer` mute mode after join; simulator CoreAudio aborts with WebRTC; physical iPhone acceptance is a separate phase.
* NetBird-connected networks break ICE after ~19 s (backend B10); test on normal networks.
* The reference gateway is dev infrastructure; "validated against the reference gateway" is not a backend claim.

## 13. Decisions log (append)

* 2026-11-03 Keep the SDK/app split; add a coordinator rather than moving logic into the app (audit §1.2).
* 2026-11-03 Mute: client-side bounded grace (E-01) unless T-M07-01 shows the agent already commits on mute; request G-02 regardless.
* 2026-11-03 Barge-in: no client gating of call audio; honest label; evidence to AWS (G-03).
* 2026-11-03 Wake word: evaluate Porcupine Arabic custom keyword first (licence check), then a self-owned speech-embedding classifier; DTW stays as fallback.
