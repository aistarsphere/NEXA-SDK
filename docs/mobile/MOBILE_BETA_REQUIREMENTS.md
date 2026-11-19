# LABEEB Beta Mobile — Requirements (authoritative)

Status: v1.0, 2026-11-03. Audit baseline: branch `feature/phase5-3b-voice-contract-v1` @ `46c6c7f` plus the uncommitted wake-word benchmark (`apps/nexa_example/lib/dev/wake_benchmark_page.dart`, `NexaAssistantPlugin.kt` bench methods).

Companion documents: `MOBILE_ARCHITECTURE_AUDIT.md` (evidence), `MOBILE_MASTER_IMPLEMENTATION_PLAN.md` (tasks), `MOBILE_QA_MASTER_PLAN.md` (tests), `MOBILE_IMPLEMENTATION_STATUS.md` (checklist), `.ai/mobile.md` (memory).

## How to read this file

* Every requirement has a stable id `M-xx.n`. Tasks (`MOBILE_MASTER_IMPLEMENTATION_PLAN.md`) and tests (`MOBILE_QA_MASTER_PLAN.md`) reference these ids. Never renumber; add new ids at the end of a section.
* **Status** is the state of the code on 2026-11-03, with the vocabulary of the audit: `VERIFIED WORKING`, `VERIFIED DEFECT`, `PARTIAL`, `MISSING`, `UNKNOWN / NEEDS TEST`. A status never upgrades without the evidence listed in the QA plan.
* **Backend dependency** names the contract the requirement needs: `labeeb.sdk/1` (`docs/contracts/labeeb-sdk-1/contract-1.0.0.json`, 35 endpoints, released 2026-10-28), `nexa.voice.v1` (`docs/contracts/voice-v1/handoff-1.0.0-4cd5247/`), or a gap id `G-xx` from the audit (a contract requirement the backend has not published).
* **Priority:** `P0` blocks Beta, `P1` required for Beta sign-off, `P2` Beta-quality improvement, `P3` after Beta.
* Vocabulary: *conversation* = server object `conv_*` (contract documents `cnv_*`, production returns `conv_*`); *chat session* = `ses_*`, one live SSE session on a conversation; *voice session* = `vs_*`, one LiveKit call on a conversation; *tools session* = the hidden `ses_*` the voice call answers device tools in (`tools.session_id`).

## Product mission (fixed)

LABEEB (لبيب) is an Arabic-first assistant app, built on the NEXA Flutter SDK, with one persistent conversation history in which text chat and live voice calls are interaction modes of the same conversation. Beta is a technical implementation on Android first (Xiaomi 25010PN30G / Android 16 and Nubia NX679J / Android 13 are the reference devices), with the AWS gateway `https://52.58.22.19/nexa/api` as the only backend. Company admins and the app do not choose AI models (M-16).

---

## M-01 — Conversation-first application

**User goal.** Open the app and continue where I left off: see my conversations, open one, read it, type or talk in it, and come back to it later.

**Expected behaviour.**
1. The root screen lists the user's conversations (server-backed, newest activity first), with "New conversation" as the primary action and a direct "Call" action.
2. Opening a conversation shows its full message list (text, voice turns, tool results, attachments) and a composer. The voice call is started *inside* that conversation.
3. A new conversation is created intentionally (user taps "New" or sends the first message / starts the first call without one), on the authenticated user and application, exactly once per intent (retries reuse the same `client_ref`).
4. The same conversation id is attached to the chat session (`POST /v1/sdk/sessions {conversation_id}`), the voice session (`POST /v1/sdk/voice/sessions {conversation_id}`), uploads and tool calls.
5. The server is the system of record; the device keeps only a bounded cache. There is one history, not a chat history plus a call history.

| Field | Value |
|---|---|
| Status | `PARTIAL` |
| Evidence | Conversation id ownership: `packages/nexa_sdk/lib/src/session/session_manager.dart:37-47,90-95,125` (`conversationId`, `conversationProvider`); creation: `packages/nexa_sdk/lib/src/nexa.dart:201-216` (`_newConversation`, `client_ref` = installation id + timestamp, **not stable across retries**); voice joins or creates it first: `packages/nexa_sdk/lib/src/features/voice/nexa_voice_controller.dart:336-351`; history list/open/rename/delete server-backed: `packages/nexa_sdk/lib/src/features/history/labeeb_conversations_api.dart`; root screen is chat-first with history behind an icon: `packages/nexa_sdk/lib/src/features/assistant/nexa_assistant_view.dart:175-208,262-291`; `NexaLaunchMode.home` is a brand splash, not a list (`:297-379`); local cache records voice calls as separate `voice` entries keyed by `vs_*` (`packages/nexa_sdk/lib/src/features/history/nexa_history.dart:442-476`) |
| Backend dependency | `labeeb.sdk/1` conversations endpoints (E2E_VERIFIED on production 2026-10-29, INTEGRATION-MATRIX); gap `G-01` (no `after_seq` on `GET …/messages`) |
| Acceptance criteria | AC1 root screen = conversation list from `GET /v1/sdk/conversations` (cache shown while loading, labelled); AC2 opening an entry resumes it (`resumeConversation`) and renders earlier messages before the composer is enabled; AC3 one `POST /conversations` per user intent, verified by `client_ref` reuse on retry; AC4 the voice `create` body carries the open conversation's id; AC5 no `vs_*`-keyed entries in the cache when the server lists history |
| QA | `T-M01-*` in the QA plan (unit: coordinator + client_ref; widget: list/empty/error; integration: login→list→open→send→call→resume; device: kill app, reopen, continue) |
| Priority | P0 |

## M-02 — Direct call and navigation

**User goal.** Start a call with one tap from wherever I am, and get back to the conversation I was in.

**Expected behaviour (precise).**
1. *From an open chat:* "Call" starts a voice session on that conversation id. The call page is pushed over the chat; closing it returns to the same chat with the spoken turns visible (M-04).
2. *From the root (no chat selected):* "Call" first creates a conversation (M-01.3), then starts the call. Closing the call lands in that conversation's chat, not on the root, so the user sees what was said.
3. *From the Android assistant (assist gesture / wake phrase) with no conversation open:* a new conversation is created for the call (the panel's cold-start path). If a chat is open and unlocked, the call joins it.
4. Call UI and chat UI are two routes on one navigator with one conversation id. There is exactly one live call page at a time; a second request while a call page is open focuses it.
5. *Disconnect:* the call page shows `reconnecting` while the SDK recovers (`GET` → `POST …/token` → rejoin); after `reconnect.grace_seconds` (30 s) it shows a plain error with Retry. *Background:* an active call keeps running while the app is backgrounded for the duration allowed by the OS (see M-12); if the OS stops capture, the user sees "call ended" on return. *Process restoration:* after a kill the app reopens on the conversation list; the previously active call is over (the server ended it as `idle_timeout`); the conversation is intact.
6. Back-stack: Root → Chat(conv) → Call(conv). Back from Call = end call, land on Chat(conv). Back from Chat = Root. History detail and settings are pushed on top of Root and never duplicate Chat.

| Field | Value |
|---|---|
| Status | `PARTIAL` (`VERIFIED DEFECT` for double-push and for "land on chat after a root call") |
| Evidence | Navigation graph: `apps/nexa_example/lib/main.dart:214-271` (go_router `/`, `/settings`, `/settings/assistant`, dev `/dev/*`) plus SDK-internal `Navigator.push` for voice/history/chat (`nexa_assistant_view.dart:76-87,185-204,448-475`) plus the system-panel overlay (`apps/nexa_example/lib/assistant/device_assistant.dart:174-225`); the header voice button has no re-entrancy guard (`nexa_assistant_view.dart:267-273`, guard exists only for `voiceRequests` at `:398,420-434`); leaving the voice page always ends the call (`:522-534`); voice from the home splash lands back on the splash (`:365`); panel cold start creates the conversation inside the voice controller (`nexa_voice_controller.dart:336-351`, device-verified 2026-10-30 `vs_MEcpxnlKfzOQ-aaAFslRKg`); no app-lifecycle handling for calls (grep `didChangeAppLifecycleState` → only camera, QA recorder, settings page) |
| Backend dependency | `nexa.voice.v1` §8 reconnect (implemented); none new |
| Acceptance criteria | AC1 one call page max (rapid double tap pushes one route); AC2 root call → chat of the new conversation on close; AC3 call from assistant panel with no chat → new conversation, visible in list afterwards; AC4 back from call returns to the same chat with the same `conversationId`; AC5 reconnect banner and Retry per state machine; AC6 process kill → list → conversation intact |
| QA | `T-M02-*` (widget back-stack tests; integration resume; device kill/restore; device background 2 min) |
| Priority | P0 |

## M-03 — Realtime voice calling

**User goal.** A call that connects fast, shows me exactly what is happening, survives a dropped connection, and fails with a reason I can act on.

**Expected behaviour.**
1. Admission: `POST /v1/sdk/voice/sessions` with `language_tag`, `conversation_id`, `chat_session_id?`, `tools:true` and up to 8 `client_tools`. `503 voice_unavailable` → "try again" state honouring `Retry-After`; `402` → quota state; `401/403` → auth state.
2. Connection: join LiveKit with the issued identity and token (`wss://` only outside development), publish the microphone only, subscribe to the agent's audio track, `resume` RPC handshake (≤25 s) → `listening`.
3. Stages shown to the user are exactly the machine states: `connecting`, `listening`, `userSpeaking`, `transcribing`, `thinking`, `aiSpeaking`, `bargeIn`, `muted`, `weakNetwork`, `reconnecting`, `modelBusy`, plus a **tool stage** ("Working: <tool>") when a tool call of this call is `running`/`awaiting_*`. Each stage is driven only by a verified agent event or an engine event (no synthetic timers).
4. End-of-turn, interruption, model busy, quota and session end follow `nexa.voice.v1` §5; captions fold `assistant_text` by `index`.
5. Reconnection per §8 (GET → token → rejoin same identity → resume from `last_seq`); cancellation (`end()`) always sends `DELETE` and leaves the room; every exit path cleans up (no lingering capture, no room).
6. Diagnostics: every call logs `voice_session_id`, `X-Request-Id`s, create/join/handshake durations, phase transitions with cause, tool events (names only), rejected events; never tokens, keys, audio or transcript text unless the tester opted in.

| Field | Value |
|---|---|
| Status | `VERIFIED WORKING` (code + one real Arabic conversation on NX679J 2026-10-27, several calls on Xiaomi 2026-10-30) for 1, 2, 4, 5, 6; `PARTIAL` for 3 (tool stage only in the compact panel, not the full capsule) |
| Evidence | Machine: `packages/nexa_core/lib/src/voice/voice_session_machine.dart`; controller: `nexa_voice_controller.dart` (`_connect` :325-416, `_recover` :610-668, `_teardown` :836-862); transport: `packages/nexa_realtime/lib/src/livekit_voice_transport.dart`; event pipeline/verifier: `packages/nexa_core/lib/src/voice/voice_event_pipeline.dart`, `voice_events_v1.dart`; labels: `packages/nexa_ui/lib/src/components/nexa_voice_capsule.dart:62-117`; tool stage in panel only: `nexa_compact_voice_panel.dart:216-230`; diagnostics: `QaRecorder` + `NexaDiagnostics` records (`voice.*`, `http.request`) |
| Backend dependency | `nexa.voice.v1` 1.0.0 (deployed; verified live) |
| Acceptance criteria | AC1 each stage label appears only after its causal event (table in QA `T-M03-02`); AC2 `503` shows "try again" and the next start waits `Retry-After`; AC3 pull the network for 10 s mid-call → `reconnecting` → `listening` with no duplicate captions; AC4 `end()` → `DELETE 200` and `dumpsys audio` shows no capture; AC5 diagnostics record contains no token (`QaRecorder` test) |
| QA | `T-M03-*` |
| Priority | P0 |

## M-04 — Transcript and conversation synchronisation

**User goal.** What I said and what the assistant answered in a call appears in the same conversation as my text messages, once, in order, and survives a restart.

**Expected behaviour.**
1. Final user transcripts and final assistant captions of a call are persisted on the server in the conversation (tool-enabled calls: `server_recorded` by the gateway; otherwise the client posts `POST …/voice-turns` idempotently per `client_turn_id`).
2. The chat timeline shows those turns (marked as voice) as soon as the call ends, and while the call is open the live captions are visible in the call UI. No duplicate rendering when the client-posted turn and the server-recorded message both exist (dedupe by `client_turn_id`/message id/`seq`).
3. Provisional (interim) captions are shown as provisional and replaced in place; a user utterance that never received `is_final` (interrupted, muted, dropped) is shown as partial, never silently dropped.
4. After a reconnect the client resumes from `last_seq`; after a kill the client reloads the server messages.
5. Ordering is by server `seq` for persisted messages and by arrival for live captions.

| Field | Value |
|---|---|
| Status | `PARTIAL` with a `VERIFIED DEFECT` (turns are persisted but the open chat is not refreshed after the call; only a resume/reopen shows them) |
| Evidence | Turn reporting: `nexa_voice_controller.dart:744-786` (skipped when `grant.tools.enabled`, because the gateway records them); transcript folding: `voice_event_pipeline.dart:145-157`, controller `_transcript` :788-811; chat only loads history when `resumePending`: `packages/nexa_sdk/lib/src/features/chat/bloc/chat_bloc.dart:191-215`; voice page writes to the **local cache only** on dispose: `nexa_assistant_view.dart:538-543`; server shows voice turns in history (user-confirmed 2026-10-28, INTEGRATION-MATRIX); AWS S1/S1b: conversation id sent on voice create and `voice-turns` 200 (deployed); S2: no model selection anywhere (`grep model_id` empty) |
| Backend dependency | `labeeb.sdk/1` `voice-turns`, `GET …/messages` (deployed); gap `G-01` (`after_seq` or SSE notification of voice messages on the chat session) |
| Acceptance criteria | AC1 end a 3-turn call from an open chat → the 6 turns are in the chat list within 2 s, each once; AC2 the same after a reconnect mid-call; AC3 kill the app during a call → reopen → conversation shows the turns the server recorded; AC4 an utterance cut by mute is shown as partial (M-07) |
| QA | `T-M04-*` |
| Priority | P0 |

## M-05 — Structured tool responses and Dynamic UI

**User goal.** When the assistant needs a choice (theme, colour, place, article, Jira project, confirmation), I see real controls, pick one, and the assistant continues; it never reads JSON to me.

**Expected behaviour.**
1. The `nexa.ui/1` contract is the only UI protocol (18 components, 4 actions, 6 events, limits 200 nodes / depth 6 / 48 kB). Documents are validated on parse; invalid documents are dropped and logged, never rendered.
2. The five kinds are distinct in the model and UI: spoken assistant text (TTS, from `assistant_text`), display-only text (`text` component / `fallback_text`), structured components, tool execution state (`tool_call_*` status), user selections (`ui_event`).
3. A selection is sent once per intent (`POST /messages {ui_event}`, idempotent per `client_message_id`); the gateway's `422 unknown_ui_component` for a stale document is shown as "these options expired".
4. Each component shows loading / success / error; unknown component types are skipped with the document's fallback text; everything renders in RTL and with screen readers (labels, 48 dp targets).
5. The user's selection returns to the active conversation and the pending tool call (`tool_call_id`), in chat and in voice (`tools.session_id`).
6. Raw JSON never reaches TTS: the agent speaks only `assistant_text`; the app never synthesises speech.

| Field | Value |
|---|---|
| Status | `VERIFIED WORKING` (contract parse, render, selection, theme flow on device with fixture events) / `PARTIAL` (ordinals-by-voice, stale handling and RTL on every component not device-verified; "live" theme flow against the real agent `NOT_TESTED`) |
| Evidence | Parser: `packages/nexa_core/lib/src/labeeb/nexa_ui_document.dart`; renderer: `packages/nexa_sdk/lib/src/features/dynamic_ui/nexa_ui_view.dart` (952 lines) + `nexa_surface_view.dart`; selections: `labeeb_tool_calls.dart:696-713`, `chat_bloc.dart:118-145`; device test: `apps/nexa_example/integration_test/assistant_tools_device_test.dart` (PASS on 2ba15772, fixture events); unit: `dynamic_ui_test.dart`, `labeeb_tool_calls_test.dart` (31) |
| Backend dependency | `labeeb.sdk/1` `ui`, `ui_event`; the real agent emitting `ui_presented` in a live call is `BLOCKED_BACKEND`/`NOT_TESTED` (QA log 2026-10-30) |
| Acceptance criteria | AC1 every component type renders in `ar` RTL and `en` in a widget test; AC2 a stale `ui_event` shows the expired state and re-enables nothing; AC3 double-tap on a choice sends one `ui_event`; AC4 malformed doc → no card, no crash, diagnostic `ui.rejected`; AC5 live: "غيّرلي شكل التطبيق" shows palettes, a tap applies the theme, one `/result` |
| QA | `T-M05-*` |
| Priority | P0 (live path), P1 (RTL/a11y completeness) |

## M-06 — Tool-calling interaction continuity

**User goal.** A multi-step tool flow (ask → choose → confirm → done) keeps working across a dropped call, an app restart, or a switch between voice and chat.

**Expected behaviour.**
1. The client keeps, per conversation: `conversation_id`, open `tool_call_id`s with their `status`, the session each must be answered in (`ses_*` or `tools.session_id`), presented `ui_id`s, local selections, and approval state.
2. After a restart the client restores open calls from `GET …/messages` (`tool_request` without result) and `GET /sessions/{id}/tool-calls/{id}` until terminal; it never re-runs or re-answers a call (answer-once set).
3. Idempotency: approval and result are sent once; `409 tool_call_closed` is terminal; retries only on network errors.
4. Orchestration (which tool, arguments, ordinal resolution "the third one") stays on AWS; the client only renders, collects and answers.

| Field | Value |
|---|---|
| Status | `PARTIAL` (restore-from-history and answer-once `VERIFIED WORKING`; in-memory pending state is lost on restart for calls raised in a **voice** call because `tools.session_id` is not persisted; interrupted-call behaviour `UNKNOWN / NEEDS TEST`) |
| Evidence | `labeeb_tool_calls.dart` (`_answered` :131,519; `restore` :725-784; `_follow` :809-862; `_sessionOf` :130 in memory only); gap `G-06` |
| Backend dependency | `labeeb.sdk/1` tool-call endpoints; gap `G-06` (list open tool calls per conversation, incl. hidden tools session) |
| Acceptance criteria | AC1 theme flow interrupted by killing the app at `awaiting_approval` → after restart the card shows the live status (expired/awaiting) and Allow works or is disabled correctly; AC2 the same for a call raised in voice; AC3 no second `/approval` or `/result` ever (unit) |
| QA | `T-M06-*` |
| Priority | P1 |

## M-07 — Microphone mute semantics

**User goal.** Mute stops the assistant hearing new audio immediately, without losing what I already said or the answer that was coming.

**Expected behaviour.**
1. Mute stops sending new microphone audio (no frames after the tap; Android mic indicator off within 1 s).
2. A complete utterance captured before the tap is still transcribed and answered.
3. An assistant reply in progress continues (audio keeps playing) while muted.
4. Buffered audio and pending STT finalisation are handled deliberately: the client either keeps capture for a bounded grace period until the agent signals `user_speech_ended`/final `transcript`, or the backend commits the turn on `TrackMuted` (gap `G-02`). One of the two must be true; the chosen design is in the plan (E-01).
5. Unmute restores input without re-sending or duplicating an earlier utterance.
6. The UI always reflects the real track state (`isMicrophoneEnabled`), including after reconnect (mute re-applied) and after expanding the panel.

| Field | Value |
|---|---|
| Status | `VERIFIED WORKING` for 1, 3, 6 (device evidence 2026-10-30: `rec stop VOICE_COMMUNICATION`, no capture while muted, new capture on unmute; unit test "mute reaches the microphone in every live state"); `UNKNOWN / NEEDS TEST` for 2 and 4 (the reported defect "last request disappears" is consistent with capture stopping before the server VAD saw end-of-speech; not reproduced with the current build) |
| Evidence | `voice_session_machine.dart:71-96`; `nexa_voice_controller.dart:206-215,289-303`; `livekit_voice_transport.dart:131-150`; `livekit_audio_setup.dart:25-31` (`stopAudioCaptureOnMute` default true in livekit_client 2.13.1); QA log §A |
| Backend dependency | gap `G-02` (turn commit on mute); `nexa.voice.v1` has no mute signal |
| Acceptance criteria | the six scripted cases in QA `T-M07-01..06` (mute after sentence, mid-utterance, rapid toggles, during reply, network drop while muted, reconnect while muted), each with `dumpsys audio` evidence and agent event log |
| QA | `T-M07-*` |
| Priority | P0 |

## M-08 — Smart barge-in and background speech rejection

**User goal.** The assistant stops when *I* interrupt it, not when a TV or another person speaks.

**Expected behaviour.**
1. The client distinguishes and logs: speech detected (`user_speech_started`), interruption applied (`interrupted`), speaker verified (optional, M-11), wake-word (M-10).
2. The UI shows "Interrupting…" only after the agent confirms `interrupted`; mere `user_speech_started` during `aiSpeaking` is shown as "listening to you" without claiming an interruption.
3. Client capture uses echo cancellation, noise suppression, auto gain and `VOICE_COMMUNICATION` (verified) so playback echo does not trigger the agent.
4. Barge-in gating is a backend policy (LiveKit Agents `interruption.min_duration`, `min_words`, `false_interruption_timeout` + `resume_false_interruption`, voice isolation); the app exposes evidence (`voice_session_id`, timestamps, events) and does not gate call audio with the owner-voice model (unvalidated for that use; would block legitimate speech).
5. Trade-offs are documented: higher `min_words` adds latency; voice isolation costs server CPU; no client-side gate is claimed to be reliable.

| Field | Value |
|---|---|
| Status | `PARTIAL` (client AEC/NS verified on device; UI shows barge-in on `user_speech_started`, not on `interrupted`: `VERIFIED DEFECT` of honesty; false barge-in from background speech `FAIL_REPRODUCED` on device 2026-10-30 — backend owned) |
| Evidence | `voice_session_machine.dart:169-173` (aiSpeaking + `VoiceUserSpeechStarted` → `bargeIn`); labels `nexa_voice_capsule.dart:71`; capture options `livekit_audio_setup.dart`; QA log §C |
| Backend dependency | gap `G-03` (interruption tuning + `interrupted` confidence); LiveKit Agents turn-handling options (docs 2026) |
| Acceptance criteria | AC1 widget: `user_speech_started` while `aiSpeaking` shows "listening", `interrupted` shows "Interrupting"; AC2 device noise matrix (6 scenarios) recorded with event timestamps; AC3 diagnostics include `interrupted.cancel_id` |
| QA | `T-M08-*` |
| Priority | P1 (client), backend P0 |

## M-09 — Android voice assistant

**User goal.** Make LABEEB my phone's assistant: long-press home or say the wake phrase and talk, even from another app or the lock screen.

**Expected behaviour.**
1. Entry points supported by public APIs: `VoiceInteractionService` role (user picks LABEEB in Android settings), assist gesture/button → system panel, `ASSIST`/`VOICE_COMMAND` intents, voice assist from keyguard, wake phrase via a microphone foreground service started while the app is visible.
2. Wake-word (M-10) activation with no chat open starts a new conversation; with a chat open and unlocked, it joins it.
3. Authentication and microphone permission are enforced before a call; a missing token shows "not connected", a denied mic shows the settings action.
4. Background: Android 14+ forbids starting the microphone service from the background (verified in Android docs); reboot and force-stop stop listening and the app says so (notification). Not claimed: always-on hardware hotword (`AlwaysOnHotwordDetector` needs `MANAGE_HOTWORD_DETECTION`, preinstalled apps only).
5. Setup and troubleshooting screen lists the real Android signals (role held, settings, service bound, mic, notifications, battery optimisation, OEM autostart).

| Field | Value |
|---|---|
| Status | `VERIFIED WORKING` on device for role, panel, close, idle timeout, mic hand-over, cold-start panel call (QA log §D, 2026-10-30); `PARTIAL` for lock-screen flow and Expand (code verified, device `NOT_TESTED`); wake phrase `FAIL_REPRODUCED` (M-10) |
| Evidence | `packages/nexa_assistant/android/src/main/AndroidManifest.xml`; `AssistantServices.kt`; `WakeListenerService.kt` (type `microphone`, `START_NOT_STICKY`, `background_start_blocked`); `NexaAssistantPlugin.kt:400-417` (`not_in_foreground`); `device_assistant.dart`; `MainActivity.kt` shared engine; Android docs: while-in-use FGS cannot be created from background on 14+, exemption "service started by an app which provides the VoiceInteractionService" |
| Backend dependency | none |
| Acceptance criteria | AC1 role chooser → status card verified on both devices; AC2 assist key over another app → panel → spoken exchange; AC3 lock screen → gate → unlock → call; AC4 reboot → notification → open app → listening resumes; AC5 Xiaomi autostart/battery steps documented and verified |
| QA | `T-M09-*` |
| Priority | P1 |

## M-10 — Wake word

**User goal.** Say «يا لبيب» and LABEEB answers, for me and ideally for anyone, without false wakes from TV or conversation.

**Expected behaviour.**
1. Detection runs offline on the device, in the microphone foreground service, with a bounded CPU/battery budget (target ≤ 5 % of one core and ≤ 40 MB RAM while idle, measured).
2. Measured on real voices: owner true-accept ≥ 90 % in a quiet room at 1 m, false accepts ≤ 1 per 8 h of mixed speech/TV, measured with the labelled-clip benchmark already in the uncommitted dev page.
3. The detector is replaceable behind one interface (`WakeEngine` decision pipeline); the current MFCC+DTW engine is kept as the fallback until a trained model passes 2.
4. Licensing and training-data provenance are documented before release.

| Field | Value |
|---|---|
| Status | `VERIFIED DEFECT` (`FAIL_REPRODUCED` 5/5 owner attempts rejected on Xiaomi 2026-10-30: distances 0.354–0.422 vs threshold 0.300; the code is still MFCC+DTW: `engine/WakePhraseModel.kt`, `engine/WakeEngine.kt`); benchmark harness `UNCOMMITTED` |
| Evidence | QA log "Wake phrase … FAIL_REPRODUCED"; commit `46c6c7f`; research in the audit §M-10 (Porcupine lists Arabic + custom keywords, commercial licence; openWakeWord code Apache-2.0 but pre-trained models CC BY-NC-SA and English TTS; sherpa-onnx KWS models zh/en only; hardware hotword privileged) |
| Backend dependency | none |
| Acceptance criteria | AC1 benchmark report (clips × engines × thresholds) committed under `docs/qa/`; AC2 chosen engine meets the numbers in 2 on both reference devices; AC3 idle CPU/battery measured 30 min |
| QA | `T-M10-*` |
| Priority | P1 (Beta can ship with assist-gesture entry only; wake word is a Beta goal, not a Beta blocker) |

## M-11 — Optional speaker verification

**User goal.** Optionally, only my voice wakes LABEEB. It is a convenience, never a login.

**Expected behaviour.**
1. Opt-in enrolment with explicit consent text, 3–5 samples, re-enrol and delete at any time; template encrypted with a non-exportable Keystore key, never uploaded, not backed up.
2. Verification runs only after a wake-phrase match; decision and scores are logged (numbers only).
3. Replay resistance: refractory window and near-identical-feature rejection (heuristic, documented as not a liveness check).
4. It gates wake activation only; it never authorises account actions and is never used to gate call audio.
5. Thresholds calibrated on real voices (owner 5×, stranger 3×) on both devices before enabling by default.

| Field | Value |
|---|---|
| Status | `VERIFIED WORKING` in code (CAM++ ONNX, leave-one-out threshold 0.40–0.65, AES-GCM store); `UNKNOWN / NEEDS TEST` on real voices (synthetic calibration only) |
| Evidence | `OnnxSpeakerEmbedder.kt`, `VoiceProfileStore.kt`, `engine/WakeEngine.kt:21-82,146-162`; model fetched by `tool/fetch_models.sh` (Apache-2.0, VoxCeleb CC BY 4.0); APK +62 MB arm64 |
| Backend dependency | none |
| Acceptance criteria | AC1 consent + delete flows in widget tests; AC2 device calibration table (owner/stranger/noise) recorded; AC3 verification never required for any server action (code review) |
| QA | `T-M11-*` |
| Priority | P2 |

## M-12 — Android permissions and lifecycle

**User goal.** The app asks only for what it needs, explains why, and keeps working (or says what it cannot do) when I deny something, plug in a headset, switch networks, or leave it in the background.

**Expected behaviour.**
1. Runtime permissions requested at the moment of use with rationale: microphone (call, wake), notifications (wake listener, Android 13+), camera/location/photos (device tools), `BLUETOOTH_CONNECT` (before enumerating/routing to a headset, Android 12+).
2. An active call is held by a foreground service of type `microphone` (started while visible) with a persistent notification and "End call" action, so backgrounding does not cut capture on Android 14+/15; the service ends with the call.
3. Audio focus is requested for the call and released after; a lost focus (phone call) ends or mutes the call with a visible state; headset/speaker route changes are reflected and switchable.
4. Connectivity changes trigger the existing reconnect paths (chat back-off, voice GET/refresh); offline shows the offline banner.
5. Battery optimisation guidance is shown only for the wake listener (not for calls).
6. OS versions: minSdk 24; Android 12/13/14/15/16 differences documented in `.ai/mobile.md`.

| Field | Value |
|---|---|
| Status | `PARTIAL`: permissions 1 `VERIFIED WORKING` except Bluetooth (`MISSING` runtime request); 2 `MISSING` (no in-call foreground service; `flutter_webrtc`/`livekit_client` ship none); 3 `UNKNOWN / NEEDS TEST` (engine sets communication mode; focus/route handling not implemented in Dart); 4 `PARTIAL` (no connectivity listener; reconnect is reactive) |
| Evidence | `apps/nexa_example/android/app/src/main/AndroidManifest.xml:3-11`; `host_permission_handler.dart`; `device_assistant_page.dart:72-77,467-476,635-673`; no FGS for calls (grep in `flutter_webrtc-1.6.2+hotfix.4/android`, `livekit_client-2.13.1/android`); Android docs on while-in-use FGS |
| Backend dependency | none |
| Acceptance criteria | AC1 deny mic → capsule shows settings action; AC2 call survives 2 min in background on Android 16 with the notification visible; AC3 Bluetooth headset call: audio in/out via headset, route chip correct; AC4 incoming phone call → LABEEB call muted/ended with state shown; AC5 airplane mode 10 s → reconnect |
| QA | `T-M12-*` |
| Priority | P0 (2), P1 (1,3,4) |

## M-13 — Performance and reliability

**User goal.** The app opens fast, scrolls smoothly, does not leak, and does not drain the battery.

**Expected behaviour (targets, measured on the reference devices in profile mode).**
Cold start to interactive list ≤ 2.0 s; chat list 60 fps with 200 messages; call page rebuilds ≤ 10/s while idle; no stream/subscription leak across 20 call start/end cycles (DevTools memory flat ±5 %); wake listener idle CPU ≤ 5 % of one core; APK size budget documented (model via Play Asset Delivery or on-demand download).

| Field | Value |
|---|---|
| Status | `UNKNOWN / NEEDS TEST` — nothing measured yet; hypotheses listed in the audit §M-13 |
| Evidence | Audit §M-13 (hypotheses: per-tick `setState` on the whole call page, timeline re-sort per build, history `open` up to 10×100 messages, ONNX Runtime +93 MB universal APK) |
| Backend dependency | none |
| Acceptance criteria | the numbers above, recorded in `docs/qa/perf-baseline.md` with device, build mode and date |
| QA | `T-M13-*` |
| Priority | P1 (measure), P2 (optimise) |

## M-14 — Accessibility and Arabic experience

**User goal.** Arabic first, English complete, readable at large text sizes, usable with TalkBack.

**Expected behaviour.** RTL layouts everywhere (directional insets/alignment), mixed Arabic/English text direction per message, text scaling to 200 % without clipping, semantics labels on all controls, live-region announcements for state changes, 48 dp targets, contrast ≥ 4.5:1 (enforced by test), reduced motion respected, keyboard inset handling.

| Field | Value |
|---|---|
| Status | `VERIFIED WORKING` baseline (contrast test, semantics, live regions, reduced motion, bundled fonts); `UNKNOWN / NEEDS TEST` for TalkBack and 200 % text on devices (B5) |
| Evidence | `.ai/flutter-architecture.md` §8; `packages/nexa_ui/test/theme/theme_contrast_test.dart`; `nexa_history_view.dart:329` (`nexaTextDirectionOf`); voice capsule RTL tests |
| Backend dependency | none |
| Acceptance criteria | AC1 TalkBack script (QA `T-M14-01`) passes on Xiaomi; AC2 200 % font: no overflow in chat, call, list, settings (golden/widget tests); AC3 every new widget uses directional APIs (lint rule in review checklist) |
| QA | `T-M14-*` |
| Priority | P1 |

## M-15 — Authentication and account isolation

**User goal.** My token is safe, refreshes silently, and nobody else's data ever shows on my phone.

**Expected behaviour.**
1. The SDK session token lives in memory only (never on disk, never logged); the host `NexaAuthProvider` is the only source; proactive refresh and one retry on `401`.
2. Logout/account switch disposes the client, clears credentials, and clears or re-keys every local cache (history cache, theme preference, media files, QA records, installation-scoped caches) so no cross-account history is shown.
3. Conversations are owned server-side; the client never lists another installation's conversations unless the server returns them.
4. Expired session during a call: token refresh through the provider; if the provider cannot refresh (dev token), the call ends with an auth state and the chat shows "access expired".
5. No sensitive data in logs or diagnostics (asserted by tests).

| Field | Value |
|---|---|
| Status | 1, 5 `VERIFIED WORKING`; 2 `VERIFIED DEFECT` (latent: local caches are not keyed by user/tenant; today there is one dev token so it is not exploitable, but Beta sign-in will make it one); 3 `VERIFIED WORKING`; 4 `PARTIAL` (dev provider cannot refresh by design) |
| Evidence | `credential_manager.dart`, `session_credential.dart:34-36`, `dio_factory.dart:50-107,109-139`; cache path `apps/nexa_example/lib/main.dart:118-121` (`history.json` not account-scoped); `NexaClient.dispose` :483-504 |
| Backend dependency | host backend minting tokens (`POST /v1/server/session-tokens`, not public) — B2 open |
| Acceptance criteria | AC1 integration test: no token in `MemoryNexaLogger` or QA records; AC2 sign in as A, chat, sign out, sign in as B → empty list, no A entries in cache file; AC3 401 mid-call → auth state within 5 s |
| QA | `T-M15-*` |
| Priority | P0 (2), P1 (4) |

## M-16 — Scope boundaries

1. The app never sends or selects model ids (LLM/STT/TTS); it consumes `voice_path`, `tools`, `limits` from the voice session response and `grantedCapabilities` from the chat session. **`VERIFIED WORKING`** (no model identifiers in `NexaConfig`, provisioner bodies or any request).
2. Company Admin dashboards and GPU model governance are out of scope for the mobile Beta.
3. Beta scope excludes: iOS acceptance (separate phase), production token minting (host backend), Jira write actions, weather tool, assets bulk delete (not in contract).

---

## Cross-cutting requirements

| Id | Requirement | Status |
|---|---|---|
| X-01 | No new UI protocol; `nexa.ui/1` extended only through its `extensionTypes` hook | enforced |
| X-02 | All backend behaviour claims cite deployed evidence (QA log date + device) or are marked `BLOCKED_BACKEND` | enforced in QA plan |
| X-03 | Secrets only through `--dart-define-from-file`; never in-app token entry (owner feedback) | enforced |
| X-04 | Uncommitted wake benchmark code is preserved and committed with its own task (F-01) | planned |
