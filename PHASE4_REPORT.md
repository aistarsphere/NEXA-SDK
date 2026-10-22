# NEXA Phase 4 — Production Engineering Foundation: Implementation Report

Date: 2026-10-22 · Toolchain: Flutter 3.44.4 (stable), Dart 3.12.2, macOS, Xcode 27, Android SDK present.

## 1. Inspection results

| Input | Found | Used as |
|---|---|---|
| Existing Flutter code in `chat-boot-sdk/` | **None** (empty directory) | Built from scratch |
| NEXA prototype / Design QA 3.1 export | **Not available** on disk or in the artifact gallery | Design rebuilt from the written contract; tokens provisional (`mocha_palette.dart`) |
| `gpu-manager-api.json` (v1.2.0) + `GPU-Manager-Handover-2026-10-20.md` | Found in `~/Downloads` | Copied to `docs/contracts/`; treated as authoritative for its own operations only |
| NEXA backend / gateway | **Does not exist** | Contract **proposed** in `docs/contracts/nexa-gateway-api.proposed.yaml` |
| Sibling Flutter projects (STTANDTTS-Mobile etc.) | Found | Reused stack conventions (bloc/dio/retrofit/freezed/get_it/injectable/go_router), bundled Noto Sans + Tajawal (OFL) |

Classification of functionality:
- **Implemented and tested:** config/auth contracts, typed conversation events + ordering/dedupe, reducer, tool contracts + validation, voice state machine, Mocha M3 theme, en/ar localisation with RTL, chat components, SDK facade + DI + session + chat bloc + embedded/modal chat, example host app.
- **Proposed, compiled, unvalidated:** `GatewayChatTransport` (long-poll HTTP against the proposed gateway), DTOs, Retrofit API.
- **Mock only (clearly labelled, `package:nexa_core/testing.dart`):** `MockChatTransport`, `MockRealtimeVoiceTransport`, `MockAuthProvider`.
- **Not implemented:** real networking to any backend, audio capture/playback/VAD, map and media rendering, billing/portal/website (out of SDK scope).

## 2. Workspace delivered

```
pubspec.yaml (pub workspace)        analysis_options.yaml (shared strict lints)   tool/{bootstrap,gen,check}.sh  Makefile
packages/nexa_core   pure Dart      54 tests
packages/nexa_ui     Flutter UI     40 tests
packages/nexa_sdk    public SDK     32 tests
apps/nexa_example    host app        1 test   + debug APK built (android)
docs/adr/0001-phase4-foundation.md  docs/contracts/{gpu-manager-api.v1.2.0.json, nexa-gateway-api.proposed.yaml, nexa-realtime-voice.proposed.md, gpu-manager-boundary.md, fixtures/}
.ai/flutter-architecture.md         .ai/assumptions-and-blockers.md         README.md
```

Package decision: `nexa_tools` and `nexa_realtime` were folded into `nexa_core` (small pure-Dart contracts that version together); a realtime package is justified only when a concrete transport brings platform dependencies. Dependency direction `nexa_sdk → nexa_ui → nexa_core`, no cycles, `nexa_core` has no Flutter import.

## 3. Public SDK API (nexa_sdk)

`Nexa.initialize(config, auth, overrides) → NexaClient`; `client.startSession() / endSession()`; `client.openChat(context)` (modal) or `client.chatView()` (embedded); `client.lifecycle` stream (`NexaInitialized`, `NexaSessionStarted/Ended`, `NexaCredentialRefreshed`, `NexaErrorOccurred`, `NexaDisposed`); `client.setLanguage('ar') / setThemeMode / setThemeOverrides(NexaThemeOverrides)`; `client.dispose()`. Host implements `NexaAuthProvider` (short-lived server-issued credential, never a long-lived key) and optionally `NexaPermissionHandler`. Sample integration: `apps/nexa_example/lib/main.dart`.

## 4. Checks run

| Check | Result |
|---|---|
| `dart format` (all packages) | clean |
| `flutter analyze packages apps` (strict modes + workspace rules) | 0 issues |
| `dart test` nexa_core | 54 passed |
| `flutter test` nexa_ui | 40 passed (contrast ≥4.5:1 both modes, RTL mirroring, reduced motion, every tool card, forms/selection/confirmation) |
| `flutter test` nexa_sdk | 32 passed (init/dispose/lifecycle, error mapping, gateway transport vs mocked API, bloc send/retry/cancel/tool/permission/quota/error, embedding, runtime language+theme, openChat, semantics + 48dp targets) |
| `flutter test` nexa_example | 1 passed (host opens modal chat, mocked reply) |
| `flutter build apk --debug` nexa_example | built (fonts + l10n packaged) |
| Code generation (`tool/gen.sh`) | repeatable; generated files committed |

Not run: iOS build, device/simulator launch, any call to a real backend (none exists).

## 5. Honest status

- **Not production ready.** **No API integration completed.** All conversation behaviour was exercised through `MockChatTransport`.
- Realtime voice = state machine + interfaces + mock. No audio or network code.
- Design tokens are an engineering baseline pending the prototype export; accessibility validation beyond the automated baseline is still open (carried from Design QA 3.1).

## 6. Blockers (owner)

B1 no gateway (Backend) · B2 no tenant/session-token contract (Backend/Security) · B3 no realtime voice channel, no runnable TTS in GPU Manager (Backend/ML) · B4 prototype export missing (Design) · B5 device-level a11y validation (Design+QA) · B6 no CI, repo not yet under git (Platform) · B7 example not launched on a device this session (SDK). Details and assumptions A1–A8 in `.ai/assumptions-and-blockers.md`.

## 7. Recommended next steps

1. Backend confirms or amends `nexa-gateway-api.proposed.yaml` (especially partial-text delivery for `llm.chat` and the session-token minting flow); then run `GatewayChatTransport` against a dev gateway and flip its status to validated.
2. Design exports tokens → replace `mocha_palette.dart`; rerun contrast tests.
3. Decide realtime channel (codec, VAD location, TTS engine) → implement a `nexa_realtime` package behind the existing interface.
4. `git init` + CI running `tool/check.sh`.
