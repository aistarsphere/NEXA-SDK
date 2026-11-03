# AMEER Mobile — current implementation status (reconciliation)

Written 2026-11-04. Source of truth for "what is actually true now". Supersedes the optimistic wording of earlier
reports where they differ; `MOBILE_IMPLEMENTATION_STATUS.md` keeps the per-task history and now carries a
reconciliation block pointing here. No code was changed for this report.

Status words: **VERIFIED ON DEVICE** (physical phone, evidence file), **VERIFIED BY INTEGRATION TEST**,
**IMPLEMENTED BUT UNVERIFIED**, **PARTIALLY IMPLEMENTED**, **VERIFIED BROKEN**, **NOT IMPLEMENTED**.
"Emulator" evidence is named as such and is not counted as device verification.

## 1. Baseline

| | |
|---|---|
| Repository | `/Users/devalqaasem/Documents/Mobile_PRJ/flutter_project/chat-boot-sdk` (Flutter pub workspace: `nexa_core`, `nexa_ui`, `nexa_realtime`, `nexa_device`, `nexa_assistant` (Kotlin), `nexa_sdk`; app `apps/nexa_example` = AMEER) |
| Branch / HEAD | `feature/phase5-3b-voice-contract-v1` @ `9d2d55a`; working tree clean; **never pushed** (local only) |
| Since the Fable audit (`b680e41`) | 45 commits: 23 task commits + status/QA/branding/fix commits |
| Toolchain | Flutter 3.44.4 stable, Dart 3.12.2, Gradle 9.1, AGP 9.0.1, Kotlin 2.3.20 |
| Checks run for this report | `tool/check.sh` → **ALL CHECKS PASSED** (format, `flutter analyze` 0 issues; core 114, reference gateway 34, ui 82, realtime 4, device 18, assistant 10, sdk 326 (5 skipped), app 79). `tool/ci.sh` passed earlier today (also generated files in sync, `flutter build apk --debug`, Kotlin `testDebugUnitTest`). |
| Builds | debug APK ✔; profile APK (arm64, dev defines) ✔ and installed on the Nubia and an emulator; local release APK ✔ (debug-signed, **not distributable**; no release key exists) |
| Devices | Nubia NX679J (adb `bf5c6761`, Android 13) connected and used today; Xiaomi 25010PN30G not connected; emulator `emulator-5554` (Android 16) used for launcher/splash only |

## 2. Executive summary

* **Usable today on a real phone:** conversation list as the root, text chat against the production gateway, **typed**
  tool calling with the theme picker (verified end to end today), live voice calls (connect, agent audio, microphone,
  server-recorded turns, End call, cleanup), the in-call foreground service (call survives backgrounding), AMEER branding
  in the app and on the emulator launcher.
* **The reported tool-calling failure is real and its earliest failing boundary is in Flutter, in voice only.** The
  voice event validator rejects every tool and UI event (`ui_presented`, `tool_call_requested`, …) as `unknownType`.
  Typed requests work. This is P0.
* **Not working / not built:** wake phrase «يا أمير» (not implemented; the detector is configured for «يا لبيب» and
  rejected the owner's real voice in the only real-voice test), speaker verification (code exists, no real-voice
  evidence), mute final-utterance delivery (not implemented, gated), reliable barge-in (server-owned; background speech
  reproduced as interruption), login (no production auth source), performance measurements (none).
* **Build readiness:** the app builds and the automated suite is green. It is **not release-ready**: no signing key,
  no production auth, voice tool path broken, no physical-device acceptance for most rows.
* Three completed tasks (D-01, D-02, C-03) depend on the same broken voice boundary, so they pass unit tests yet
  cannot work in a real call. They are marked accordingly below.

## 3. Requirement matrix (the 24 items)

IDs refer to `MOBILE_BETA_REQUIREMENTS.md` (M-xx) and the plan (task ids).

| # | Feature | Status | Key source | Done since the audit | Tests (latest) | Device |
|---|---|---|---|---|---|---|
| 1 | AMEER branding, launcher, splash, notification | **PARTIALLY IMPLEMENTED** | `tool/branding/generate_ameer_assets.py`, `apps/nexa_example/android/app/src/main/res/**`, `lib/brand/ameer_logo.dart`, `nexa_assistant` `Notifications.smallIcon` | whole item (commit `34f87db`) | `branding_test` (resources, safe area, silhouettes, names) green | Emulator: launcher icon, light/dark splash ✔. Nubia: header logo, label ✔; launcher icon not looked at; **notification badge shows the Flutter logo** (open defect) |
| 2 | Login, authentication, token refresh | **NOT IMPLEMENTED** (production) / refresh **IMPLEMENTED BUT UNVERIFIED** | `CredentialManager` (401 → one refresh, proactive), `DevTokenAuthProvider` (no refresh), `HostAuthProvider` | — (no change; backend B2: no host backend) | credential tests green | dev token works; real issuer never tested |
| 3 | Home screen and history | **VERIFIED ON DEVICE** | `NexaConversationListPage`, `labeebListPage` (`labeeb_router.dart`), `NexaHistoryController`, `JsonFileHistoryStore.forAccount` | B-01, B-02, B-03 | `conversation_list_test` (8), `router_test`, `history_scope_test` (9), paging tests | Nubia list shows server conversations (incl. a 16-message voice conversation). Defect: failed call attempts leave **empty "0 messages" conversations** in the list |
| 4 | New conversation | **VERIFIED ON DEVICE** | `ConversationCoordinator.ensureConversation` (stable `client_ref`), `_startNew` | A-01 | `conversation_coordinator_test` (9), `conversation_session_test` (5) | `POST /conversations` 201 seen in logs; offline-then-online single-conversation case (T-M01-01) not run |
| 5 | Existing-conversation text chat | send/reply **VERIFIED ON DEVICE**; resume of an old conversation **IMPLEMENTED BUT UNVERIFIED** | `ChatBloc` (`_loadResumedHistory`, `ChatOlderRequested`), `RouteConversation` (`/c/:id`) | B-01, B-03 | bloc + view tests | typed send → 202 → reply on Nubia; opening an old conversation from the list not exercised |
| 6 | Voice call from an existing conversation | **IMPLEMENTED BUT UNVERIFIED** | `openLabeebCall` (`labeeb_router.dart`), `/c/:id/call`, `_LiveVoicePage` | A-02 | `router_test`, `assistant_navigation_test` | call from the list/chat verified; call opened from a conversation with prior messages not exercised |
| 7 | New voice conversation from home | **VERIFIED ON DEVICE** | same + coordinator | A-01, A-02 | tests above | list → call created a conversation (201) and a voice session. First start was slow (~35 s) once: **unexplained** |
| 8 | Server-owned transcript sync | persistence **VERIFIED ON DEVICE**; post-call merge into the open chat **IMPLEMENTED BUT UNVERIFIED** | `ConversationReducer.mergePersisted`, `ChatHistoryMerged`, `NexaClient._reconcileAfterCall` | C-01 | `merge_persisted_test` (9), `chat_reconcile_test` (3) | list shows server-recorded voice turns; reconcile into a chat that was open during the call not seen on device |
| 9 | Voice/text context continuity | **IMPLEMENTED BUT UNVERIFIED** | one `conversationId` for chat session, voice create, tool answers | A-01 | — | whether the agent uses earlier text in a call is agent-side (AWS); never checked |
| 10 | LiveKit connection and audio playback | **VERIFIED ON DEVICE** | `LiveKitVoiceTransport`, `GatewayVoiceProvisioner`, `NexaVoiceController` | — | realtime 4, voice controller tests, fixtures | today: connect, agent speaking, mic capture (`VOICE_COMMUNICATION`, AEC/NS), end → `DELETE`; audibility was not judged by a person today (owner confirmed on 10-27/10-30). `resume RPC failed: RpcError` is logged on every call (impact unknown) |
| 11 | Tool calling and Dynamic UI | **text VERIFIED ON DEVICE; voice VERIFIED BROKEN** | `labeeb_tool_calls.dart`, `nexa_ui_view.dart`, `voice_events_v1.dart` | D-01, D-02, D-03 (see §6) | tool-call and UI tests green | §6 |
| 12 | Theme selection and colour application | **text VERIFIED ON DEVICE; voice VERIFIED BROKEN** | `LabeebThemeApplyTool`, `LabeebThemeController` | — | `labeeb_theme_test`, tool tests | typed flow end to end today (picker → select → preview → Apply → persisted → confirmed → reset) |
| 13 | Places, news, Jira, other interactive results | **IMPLEMENTED BUT UNVERIFIED** | generic `nexa.ui/1` renderer, places/maps widgets | D-03 (fallback/expired/retry) | widget tests | no such tool call was run on a device today; Jira has no client code (server tool, rendered generically) |
| 14 | Microphone mute; final utterance delivery | mute **VERIFIED BY INTEGRATION TEST**; finalisation **NOT IMPLEMENTED** | `VoiceSessionMachine` mute, `NexaVoiceController.setMuted` | — (E-01/E-02 not started) | machine + controller tests | owner-reported loss of the last request not re-tested; T-M07-01 evidence run not done |
| 15 | Barge-in / interruption | **PARTIALLY IMPLEMENTED** (client side honest; behaviour is server-owned) | `voice_session_machine.dart` (`bargeIn`), `interruptConfirmed`, `qa_analysis.dart` | C-04, E-04 | capsule/controller tests, `qa_analysis_test` | 10-30 log: background speech produced captions and "Interrupting…" (**FAIL_REPRODUCED**, agent VAD); six noise scenarios not run |
| 16 | Wake phrase «يا أمير» | **NOT IMPLEMENTED** | `device_assistant.dart:38` `wakePhrase = 'يا لبيب'` | F-01 only (benchmark harness) | JVM engine tests (synthetic only) | detector rejected 5/5 real owner attempts on 10-30 |
| 17 | New session after wake invocation | **IMPLEMENTED BUT UNVERIFIED** | `DeviceAssistant._requestVoice` → `ensureConversation(reason:'assistant')`, `NexaAssistantActivation` | F-05 | `activation_policy_test` (4), `device_assistant_test` | assist-gesture panel cold start verified 10-30 (before F-05); the **wake** path cannot be exercised while the detector fails |
| 18 | Speaker verification / owner recognition | **PARTIALLY IMPLEMENTED** | `WakeEngine.kt` (`SpeakerProfile`), `OnnxSpeakerEmbedder.kt`, `VoiceProfileStore.kt` | — | JVM tests with synthetic voices | no real-voice calibration (F-04 not started) |
| 19 | Android assistant integration, background | assist/role **VERIFIED ON DEVICE (10-30)**; call in background **VERIFIED ON DEVICE (today)**; wake listener in background **IMPLEMENTED BUT UNVERIFIED** | `AssistantServices.kt`, `NexaAssistantPlugin.kt`, `WakeListenerService.kt`, `CallForegroundService.kt` | A-03, A-04 | device/assistant tests, Kotlin tests | see §7 |
| 20 | Microphone, notification, foreground-service permissions | **IMPLEMENTED BUT UNVERIFIED** (mic request works on device) | manifests, `HostPermissionHandler` | A-03 (service type `microphone`) | permission tests | Android 14+ behaviour not tested (phone is Android 13); Bluetooth permission never requested (E-03 not started) |
| 21 | Navigation, routing, back stack | **IMPLEMENTED BUT UNVERIFIED** (partly device) | `labeeb_router.dart`, `main.dart` routes | A-02, B-01 | `router_test` (6), `assistant_navigation_test` (4) | list → chat → call → close → chat worked on the Nubia; deep links, history resume and the T-M02 matrix not run |
| 22 | Performance, memory, cleanup, crashes | **NOT IMPLEMENTED** (measurement) / cleanup **VERIFIED ON DEVICE** | G-01 not started; `crash_sink.dart` | G-04 | `crash_sink_test` (5) | no cold-start, jank, memory or battery numbers; call end releases mic and service ✔ |
| 23 | Arabic RTL and accessibility | RTL **VERIFIED ON DEVICE**; 200 % text **VERIFIED BY TEST**; TalkBack **NOT VERIFIED** | `NexaLocale`, directional layouts | G-02 (partial) | `text_scale_test` (8), `large_text_test` (6) | Arabic UI checked visually; system font 200 % and TalkBack not run on the phone |
| 24 | Build readiness, QA coverage | **PARTIALLY IMPLEMENTED** | `tool/check.sh`, `tool/ci.sh`, `docs/mobile/RELEASE.md` | G-03, G-05 | suite above | CI workflow written, **not enabled**; no release key; release build not run on a device |

## 4. What was completed since the Fable audit (and whether it is real)

| Task | Commit | Verdict |
|---|---|---|
| F-01 wake benchmark committed | `9156df7` | Finished, valid (dev tool only) |
| A-01 ConversationCoordinator | `3bc1a0e` | Finished, valid, in the running app |
| A-02 route graph, no double call page | `d8e2c2c` | Finished, valid (device: partly) |
| A-03 in-call foreground service | `d6075bd` | Finished, **device-verified today** (40 s background, End call → `DELETE`) |
| A-04 lifecycle hooks | `60fe48f` | Finished; the 25 s end-when-unheld rule is unit-tested only |
| B-01/B-02/B-03 list, cache, older pages | `944766e`, `eb300f6`, `686731e` | Finished, valid |
| C-01 post-call reconcile | `2b8881b` | Implemented, tested, not seen on device |
| C-03 tool stage in capsule | `4671655` | **Finished but not integrated in practice**: needs voice tool events (§6) |
| C-04 honest barge-in label | `4671655` | Finished, valid |
| C-05 reconnect banner/announce | `e8dad07` | Finished, valid |
| D-01 pending tool state | `9b3f488` | **Finished but not integrated in practice**: voice-raised calls never reach the controller |
| D-02 `ui_event` guard + voice sink | `ca40de4` | Guard valid (text); **voice sink never exercised** (same cause) |
| D-03 fallback/expired/retry | `ca4274d` | Finished, valid (also reached by text path) |
| E-04 barge-in evidence tooling | `e736be2` | Finished; no evidence collected, request to AWS **not sent** |
| F-05 activation ensures a conversation | `4ff53b1` | Implemented, unit-tested |
| G-02 partial (banner/capsule at 200 %) | `d10eba3` | Partial; app tests added later |
| G-03 release hardening | `b853ea4` | Valid on built APKs; no key, no device run |
| G-04 crash hook | `dc7618e` | Finished, valid (no vendor) |
| G-05 CI script | `c411d74` | Valid locally; workflow not enabled. Also fixed: `check.sh` skipped 28 tests |
| Test fix: flaky expiry test | `6c76d99` | Root cause was the test, fixed |
| Branding (AMEER) | `34f87db` | See row 1 |
| Visual QA fixes (call panel at bottom, rate-limit text, palette name) | `9d2d55a` | Finished, device-checked |
| **Not started / omitted** | — | E-01, E-02 (gated), E-03, F-02, F-03, F-04, G-01, T-M07-01 device run; C-02 (optional, deferred); D-04 (deferred, needs a local-action design) |

Superseded work: none. Nothing was reverted. The unfinished test file from G-02 was completed and committed.

## 5. Verified working (with evidence)

* Typed tool calling and theme change, end to end: `docs/qa/evidence/2026-11-04/tool_calling_trace.md`.
* Call survives 40 s in the background; microphone live; End call from the notification → `DELETE`; service stopped:
  `docs/qa/evidence/2026-11-04/README.md`.
* Call screen layout after the fix; list, chat, settings, About, assistant settings: `visual_qa.md`.
* Release/debug/profile builds; automated suite; Kotlin tests.

## 6. Tool calling and theme selection — failure analysis

**Reproduced split:** the same request ("change my application color") works when typed and fails in voice.

| Boundary | Evidence | Verdict |
|---|---|---|
| Voice transcription → AI/tool request | An earlier real call on the Nubia logged two agent events of types `ui_presented` and `tool_call_requested` | works (the agent produced the workflow) |
| Backend tool execution → `nexa.ui/1` event | those event types exist; contract: tool events use the **same sealed topic** `nexa.voice.events` and the same fields as SSE (`contract-1.0.0.json`, "sealed") | backend behaves as documented |
| LiveKit transport | events were received, signature-checked and parsed (rejection text comes from the v1 validator, step 5) | works |
| **Flutter decoder** | `parseEventV1` (`packages/nexa_core/lib/src/voice/voice_events_v1.dart`, ~l.272-280) accepts only `_turnScoped ∪ _sessionScoped`. `tool_call_requested/updated/progress/completed/failed`, `asset_created`, `ui_presented` are in neither → `VoiceEventRejected(unknownType)` → dropped. The mapping to `RealtimeToolEvent` (~l.450-457) is **unreachable with real traffic**. Tests missed it because the mock transport emits `RealtimeToolEvent` directly. | **FAILS — earliest failing boundary** |
| Dynamic UI renderer | renders the theme picker, preview and Apply card (typed path, device) | works |
| Action submission | typed: `ui_event` 202, approval 200, result 200, preferences `PUT` 200 | works (typed); not reachable in voice |
| Backend confirmation | assistant: "تم تطبيق اللون الأخضر…" | works (typed) |
| Local theme application | whole app turned green, persisted, reset works | works |
| Spoken colour choice resolving the workflow | cannot be tested while the client never sees or answers the tool call | **unproven**; likely cause of the spoken "technical error": the device tool call stays open and the agent's tool step fails (hypothesis, not captured) |
| Conversation / action ids preserved | typed path: same session and tool-call ids across approval and result | yes (typed) |
| Permissions / confirmations | the theme tool needs approval; the card shows it and Apply sends it | no missing confirmation in the typed flow |

**Defects and owners**

| ID | Defect | Owner | State |
|---|---|---|---|
| V-01 | Voice validator rejects all tool and UI event types | **Flutter** (`nexa_core`) | open, P0 |
| V-02 | No contract fixture for sealed tool events in the voice tests (why V-01 was invisible) | Flutter (test) + AWS (provide fixtures) | open |
| V-03 | Payload of real voice tool events and the agent's error on a spoken colour were never captured | Flutter (logging after V-01) + AWS (confirm expectations) | open |
| V-04 | `resume RPC failed: RpcError` on every call | AWS agent (RPC) / Flutter (handling) | open, impact unknown |
| V-05 | Chat sessions log `Capabilities not granted: richResults, liveVoice` after a rate limit | AWS (grant policy) | observed once |

No evidence points at GPU services. Not implemented here (analysis only).

## 7. Wake word, speaker verification, barge-in, Android integration

**Wake word.** Detector: MFCC (Kaldi fbank) + DTW against the owner's recorded templates, energy segmenter, accept
threshold capped at 0.30 (`WakeEngine`, `WakePhraseModel`). Configured phrase: **«يا لبيب»** only
(`device_assistant.dart:38`, plugin `phraseLabel`); «يا أمير» appears nowhere in code. Acoustic evidence: synthetic
JVM tests only; real-voice test 2026-10-30: five owner attempts, distances 0.354–0.422, **all rejected**
(`docs/qa/android-voice-acceptance.md`, commit `46c6c7f`). The embedding benchmark (F-01) is a recorder and a speed
test, not a detector. A trained detector (Porcupine or self-trained) is not started. Starting a conversation after a
wake: the path exists (`ActivationRouter` → host → `ensureConversation` → call) but cannot be exercised while the
detector fails. **Status: NOT IMPLEMENTED for «يا أمير»; existing detector fails on real voices.**

**Speaker verification.** Enrolment (five recordings, at least three kept), encrypted profile (Keystore AES-GCM), CAM++ VoxCeleb 16 kHz ONNX
(29.6 MB, ORT 1.29), score = max(mean, average of top-2 cosine), threshold = weakest leave-one-out − 0.12 clamped to
0.40–0.65 (default 0.55), run only after a phrase match. Protection: 3 s refractory, near-identical-DTW replay
heuristic. **No liveness**, so a replay of the owner's voice can pass; never used to gate call audio or barge-in.
Evidence: synthetic JVM tests; real-voice calibration not done (F-04). **Status: PARTIALLY IMPLEMENTED, unproven.**

**Barge-in.** Decided entirely by the agent (server VAD); the client sends no interrupt command and applies no gating.
The UI says "Listening to you…" until `interrupted` arrives. Television or another voice can interrupt: reproduced on
10-30 (agent-side). Speaker recognition is not involved. Owner of the fix: AWS/agent (thresholds, false-interruption
resume, voice isolation); the evidence request (`docs/qa/barge-in-evidence.md`) is written but **not sent**, and the six
scenarios have not been run.

**Android integration.** Implemented: `VoiceInteractionService` + session service, `RecognitionService` (delegating),
ASSIST/VOICE_COMMAND intents, role detection, lock-screen handling, a `microphone` foreground service for the wake
listener (starts only while the app is visible, Android 14+ rule) and for calls, boot notification. Permissions:
RECORD_AUDIO, POST_NOTIFICATIONS, FOREGROUND_SERVICE(_MICROPHONE), RECEIVE_BOOT_COMPLETED, BLUETOOTH_CONNECT
(declared, never requested). Verified on device: role and assist key → panel (10-30); call in background (today).
Foreground only: starting the wake listener and a call service. Background: a running wake listener until
force-stop/reboot; a running call service. Not possible without privileges: hardware always-on hotword
(`MANAGE_HOTWORD_DETECTION` is privileged), starting microphone services from the background, surviving OEM
force-stop/autostart limits (Xiaomi untested).

## 8. Backend dependencies

G-01 `after_seq`/voice-message event (workaround in place); G-02 turn commit on `TrackMuted` (E-01 depends on the
device run first); G-03 barge-in tuning (request not sent); G-04…G-09 documentation gaps; **new:** confirmation of
tool-event envelope fields and a sealed fixture (V-02), the `resume` RPC failure (V-04), a rate limit on
`POST /voice/sessions` hit after a handful of attempts (limit unknown), and the company profile name/welcome text
still "لبيب" (dashboard data).

## 9. Real-device QA gaps

Not run on a phone: mute scripts T-M07-01..06; barge-in scenarios; wake and speaker tests; Android 14+/16 service
start rules; Xiaomi autostart/battery; offline-then-online single conversation; history resume; deep links;
two-way audio for 2 minutes; 200 % system font and TalkBack; release build; performance (G-01). Today's physical
evidence is limited to the Nubia (Android 13).

## 10. Priorities in dependency order

| P | Work | Code area | First action |
|---|---|---|---|
| P0 | **V-01**: accept tool and UI events in the voice path, then prove the typed flow in a call | `packages/nexa_core/lib/src/voice/voice_events_v1.dart`, `voice_event_pipeline.dart`, `nexa_voice_controller.dart` (`RealtimeToolEvent`) | write a failing test that feeds a sealed `ui_presented` envelope (ask AWS for fixtures if the handoff has none), then add the tool types to the validator |
| P0 | V-03: capture the real voice payload and the spoken-colour error with event logging; run T-M05-05 on the Nubia | `QaRecorder`, voice controller | one call with the owner saying «غيّر لون التطبيق» then a colour; keep the QA record |
| P1 | Empty conversations from failed starts; slow first start; `resume` RPC failure | `ConversationCoordinator`/`openLabeebCall`, voice controller | log timings around `ensureConversation` and `POST /voice/sessions`; do not create the conversation until the call is accepted, or remove it on failure |
| P1 | Mute and last utterance | `voice_session_machine.dart`, controller | run T-M07-01 on the Nubia (needs the owner), then E-01 as designed |
| P1 | Wake phrase «يا أمير», speaker verification, barge-in evidence | `nexa_assistant` engine; `docs/qa/barge-in-evidence.md` | collect ≥ 20 owner clips of «يا أمير» with the benchmark page; send the G-03 request with the six-scenario evidence |
| P2 | Notification badge on the Nubia, Bluetooth/route/focus (E-03), Android 14+ checks, Xiaomi | plugin, manifest | read how the Nubia shell picks the badge; request `BLUETOOTH_CONNECT` before a call |
| P2 | Performance (G-01), TalkBack, signed release, enable CI | — | create the release key; run `tool/perf.sh` baseline |

## 11. Source and test evidence index

`docs/qa/evidence/2026-11-04/` (trace, services, notification, screenshots), `docs/qa/android-voice-acceptance.md`
(10-30 device log), `docs/qa/barge-in-evidence.md`, `docs/mobile/RELEASE.md`, `docs/mobile/AMEER_BRANDING.md`,
`MOBILE_IMPLEMENTATION_STATUS.md` (per-task rows with commits), `tool/check.sh` output at HEAD (§1).
