# LABEEB Beta Mobile — Implementation Status

Updated 2026-11-03 (plan v1.0). The implementing session updates this file at the end of every task: state, commit hash, evidence path. States: `NOT STARTED`, `IN PROGRESS`, `BLOCKED_BACKEND (G-xx)`, `DONE`, `DONE (device pending)`.

Order is the execution order of `MOBILE_MASTER_IMPLEMENTATION_PLAN.md`. Do not start a task whose dependencies are not `DONE`.

| # | Task | Req | Depends on | State | Commit | Evidence (tests / device) |
|---|---|---|---|---|---|---|
| 0 | F-01 Commit wake-word benchmark (uncommitted files) | M-10 | — | DONE | 9156df7 | Q1 clean; nexa_assistant 6 + app 28 Dart tests; Kotlin testDebugUnitTest green (2026-11-03) |
| 1 | A-01 ConversationCoordinator | M-01, M-02, M-04 | F-01 | DONE (device pending) | 3bc1a0e | unit: conversation_coordinator_test (8) + conversation_session_test (5, incl. cold-start guard mutation-checked); `tool/check.sh` green on rerun; device T-M01-01 (offline → online → one conversation) pending |
| 2 | A-02 Route graph owned by the app | M-02 | A-01 | DONE (device pending) | d8e2c2c | SDK `assistant_navigation_test` (4; guard + home-flow mutation-checked), app `router_test` (3); `tool/check.sh` green (sdk 265, app 31). Device T-M02-01..04 pending. Scope notes: `/` stays the chat root until B-01; history/settings pushes are still SDK/app-internal; call route uses `MaterialPage(fullscreenDialog)`, not the custom fade transition |
| 3 | A-03 In-call foreground service | M-12.2, M-03.5 | A-02 | DONE (device pending) | d6075bd | plugin Dart tests (10, 4 new), app `device_assistant_test` (3 new; 34 total), Kotlin compile + `testDebugUnitTest` green, debug APK builds and the merged manifest declares `CallForegroundService`. Device T-M12-02 (2-minute backgrounded call, `dumpsys activity services`, End call → DELETE 200) pending. Deviations: type `microphone` only (no `mediaPlayback`; not needed to hold capture, avoids an extra permission); no `NexaAssistantOptions.callForegroundService` flag (the bridge lives in the app; rollback = remove the `_startCallService` call); `onTaskRemoved` sends `end_requested/task_removed` |
| 4 | A-04 App lifecycle hooks for calls | M-02.5, M-12 | A-03 | DONE (device pending) | 60fe48f | SDK `voice_lifecycle_test` (5; hold, early resume and recover each mutation-checked), app `device_assistant_test` (+1, 12 total); `tool/check.sh` green. Device T-M02-05..07 pending. Deviation: the plan's "refresh `isMicrophoneEnabled` into state on resume" is left to E-02 (`micOpen`); `NexaVoiceController.microphoneEnabled` already reads it live. The panel holds the call (not only the service), otherwise a panel call over another app would be ended after 25 s |
| 5 | B-01 Conversation list root | M-01.1 | A-01, A-02 | DONE (device pending) | 944766e | SDK `conversation_list_test` (8: list, open, empty, New/Call, error+Retry, infinite scroll, pull-to-refresh, 48 dp/semantics, Arabic RTL at 2x text), app `router_test` (6; list root, New → `/c/new`, open → `/c/:id` resume, Call list→chat→call); `tool/check.sh` green (sdk 278, app 38). Device T-M01-03/05 pending. Notes: LABEEB defaults to `NexaLaunchMode.list` (needs `history` configured, else the chat); with the list as root the chat header drops the history button and shows the name only (a pushed page left ~30 px for the title and overflowed); `/c/:id` always resumes on mount (a remounted chat needs its history), the call route does not; "cached entries greyed while loading" not done (controller already merges cache and server) |
| 6 | B-02 Cache keyed by conv_* + account | M-01.5, M-15.2 | A-01 | DONE (device pending) | eb300f6 | SDK `history_scope_test` (9; voice-row guard and legacy migration mutation-checked); `tool/check.sh` green (sdk 287, app 38). Device T-M01-06/T-M15-02 pending. Design deltas: account scoping is `JsonFileHistoryStore.forAccount(dir, key)` (file `history_<sha256 first 8>.json`) instead of a `NexaHistoryOptions.accountKey` field; no `NexaClient.clearLocalData` (the existing `localCache` deletion scope clears the active account's store; switching account = re-initialise with that account's store); `NexaHistoryEntry.conversationId` added as the name of `sessionId` (kept, not deprecated, to avoid churn); the app removes the old unscoped `history.json` once (cache only; otherwise "Clear all" would miss it); the app account key is the constant `default` until sign-in exists (backend B2) |
| 7 | B-03 Older message pages | M-01.2 | B-01 | NOT STARTED | | bloc + widget tests |
| 8 | C-01 Post-call reconciliation | M-04.2 | A-01, B-02 | NOT STARTED | | T-M04-01..05 |
| 9 | C-02 Live voice turn card in chat (optional) | M-04 | C-01 | NOT STARTED | | widget |
| 10 | C-03 Tool stage in full capsule | M-03.3 | — | NOT STARTED | | T-M03-08 |
| 11 | C-04 Honest barge-in label | M-08.2 | — | NOT STARTED | | T-M08-01 |
| 12 | C-05 Reconnect/background polish | M-02.5, M-03.5 | A-03, A-04 | NOT STARTED | | T-M03-05 |
| 13 | D-01 Pending tool state persistence | M-06 | B-02 | NOT STARTED | | T-M06-01, T-M06-02, T-M06-04 |
| 14 | D-02 ui_event in-flight guard + voice sink | M-05.3 | A-01 | NOT STARTED | | T-M05-03, T-M05-07 |
| 15 | D-03 Fallback / expired / loading states | M-05.4 | D-02 | NOT STARTED | | T-M05-01, T-M05-04 |
| 16 | D-04 Theme picker → nexa.ui/1, remove legacy surfaces | M-05 | D-03 | NOT STARTED | | dynamic_ui tests |
| 17 | T-M07-01 device evidence run (prerequisite of E-01) | M-07 | C-01 | NOT STARTED | | docs/qa/evidence/<date>/T-M07-01 |
| 18 | E-01 Mute finalisation | M-07 | C-01, #17 | NOT STARTED | | T-M07-00..06 |
| 19 | E-02 Mute debounce + track honesty | M-07.6 | E-01 | NOT STARTED | | T-M07-03 |
| 20 | E-03 Bluetooth / route / focus | M-12.1, M-12.3 | A-03 | NOT STARTED | | T-M12-03, T-M12-04 |
| 21 | E-04 Barge-in evidence + G-03 request | M-08 | C-04 | NOT STARTED | | T-M08-02, T-M08-03 |
| 22 | F-02 Wake engine interface + Porcupine spike | M-10 | F-01 | NOT STARTED | | T-M10-01..03 |
| 23 | F-03 Speech-embedding classifier spike | M-10 | F-02 | NOT STARTED | | T-M10-02 |
| 24 | F-04 Speaker verification calibration + consent | M-11 | F-02 | NOT STARTED | | T-M11-01, T-M11-02 |
| 25 | F-05 Assistant cold-start conversation policy | M-09.2 | A-01 | NOT STARTED | | T-M09-07, T-M02-04 |
| 26 | G-01 Performance baseline | M-13 | A–E | NOT STARTED | | T-M13-01..04 |
| 27 | G-02 Accessibility device pass | M-14 | B-01, C-03 | NOT STARTED | | T-M14-01, T-M14-02 |
| 28 | G-03 Release hardening | M-12.7, M-15 | — | NOT STARTED | | Q6, Q7, T-M12-06 |
| 29 | G-04 Crash / diagnostics hook | M-13 | — | NOT STARTED | | unit |
| 30 | G-05 CI gate script | all | — | NOT STARTED | | tool/ci.sh run log |

## Backend gaps to raise with AWS (from the audit §4)

| Gap | Blocks | Raised | Answer |
|---|---|---|---|
| G-01 `after_seq` / voice message notification | C-01 (partial workaround exists) | NOT RAISED | |
| G-02 turn commit on `TrackMuted` | E-01 (client grace exists) | NOT RAISED | |
| G-03 barge-in tuning, `interrupted` confidence | M-08 | NOT RAISED | |
| G-04 `voice_identity` documented | M-03 | NOT RAISED | |
| G-05 `client_tools` ≤ 8, id prefixes | M-05 | known (matrix) | |
| G-06 open tool calls per conversation | D-01 (file workaround) | NOT RAISED | |
| G-07 background call policy | A-04 | NOT RAISED | |
| G-08 `client_turn_id` charset | M-04 | known (matrix) | |
| G-09 audio upload media type | M-05 | known (matrix) | |

## Device acceptance rows still open from the 2026-10-30 QA log

Live «غيّرلي شكل التطبيق» (T-M05-05) · six noise scenarios (T-M08-02) · owner/stranger voice test (T-M11-02) · wake phrase in four app states (T-M10-03) · lock-screen gate (T-M09-03) · Expand (T-M09-04) · reboot notification (T-M09-05) · Xiaomi background policy (T-M09-06).

## Defects found that were not in the audit

| Date | Defect | Evidence | State |
|---|---|---|---|
| 2026-11-03 | `reference_gateway_integration_test` "server-side expiry ends the chat with reason expired" is timing-flaky under full-suite load (`waitFor` timeout) | baseline `flutter test` in `packages/nexa_sdk`: 1 failure in 3 runs; passes alone; same on A-01 | OPEN (test-only; raise the wait or poll the gateway clock) |
| 2026-11-03 | `chat_bloc.dart:81` and `dio_factory.dart:39` use a non-injectable `static const Uuid()` | source | OPEN (convention; fix when those files are touched) |
| 2026-11-03 | go_router `GoRouter.routerDelegate.currentConfiguration.uri` ignores imperatively pushed routes; use `router.state.uri` to know the top route | go_router 18.1 `match.dart:532` | NOTE (applied in `labeeb_router.dart`) |
| 2026-11-03 | The flaky gateway test fails about 1 in 3 even when its own file runs alone (2 of 3 full-suite runs during B-01); likely the 410 restart racing the `ended` phase in `ChatBloc`; needs its own investigation | `reference_gateway_integration_test.dart:351` | OPEN |
