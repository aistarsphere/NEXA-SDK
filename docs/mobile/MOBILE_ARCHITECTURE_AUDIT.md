# LABEEB Beta Mobile — Architecture Audit

Date 2026-11-03. Branch `feature/phase5-3b-voice-contract-v1` @ `46c6c7f` (3 uncommitted files + 1 untracked, all wake-word benchmark; preserved). Auditor: principal Flutter review, static tracing of the real code plus the committed device evidence (`docs/qa/android-voice-acceptance.md`, 2026-10-30, Xiaomi 2ba15772 and Nubia bf5c6761). No device was run during this audit; `flutter analyze packages apps tools` → "No issues found" (4.9 s). No test suite was executed in this audit; the counts below are from the sources.

Classification vocabulary: `VERIFIED WORKING` (code traced + test or device evidence), `VERIFIED DEFECT` (code traced to a wrong behaviour), `PARTIAL`, `MISSING`, `UNKNOWN / NEEDS TEST`.

## 1. Baseline

| Item | Value |
|---|---|
| Toolchain | Flutter 3.44.4 stable (engine 700aebec), Dart 3.12.2, DevTools 2.57.0; Gradle 9.1.0, AGP 9.0.1, Kotlin 2.3.20, compileSdk 36 (plugin), minSdk 24 (plugin) / `flutter.minSdkVersion` (app), Java 17 |
| Workspace | pub workspace, one root `pubspec.lock`; packages `nexa_core` (pure Dart), `nexa_ui`, `nexa_realtime` (LiveKit), `nexa_device`, `nexa_assistant` (Android plugin), `nexa_sdk`; app `apps/nexa_example` (= LABEEB); `tools/nexa_reference_gateway` (dev only) |
| Size | ≈57.7 k lines incl. tests (`wc -l`), 462 test cases by `grep` (core 100, ui 40, realtime 4, sdk 233, device 18, assistant 6, app 27, gateway 34) + 8 Kotlin JVM tests |
| Key deps | flutter_bloc 9.1 / bloc 9, dio 5.11, retrofit 4.10, freezed 3.2.6-dev.1 (pinned, see `nexa-toolchain-quirks`), json_serializable 6.15, get_it 9.3 + injectable 3.0, go_router 18.1 (app only), livekit_client 2.13.1 (flutter_webrtc 1.6.2+hotfix.4), pinenacl 0.6 (Ed25519), permission_handler 12, camera/geolocator/image_picker/file_picker/record/audioplayers/share_plus/url_launcher, ONNX Runtime Android 1.29.0 |
| Entrypoints | `apps/nexa_example/lib/main.dart` (`main`), `MainActivity.kt` (shared cached `FlutterEngine` `nexa_assistant_engine`), `NexaVoiceInteractionSession` (system panel attaches a second `FlutterView` to the same engine) |
| Environments | build-time `--dart-define`: `NEXA_REAL_BACKEND`, `NEXA_GATEWAY_URL`, `NEXA_APP_ID`, `NEXA_LANGUAGE`, `NEXA_DEV_SDK_TOKEN(_EXPIRES_AT)`, `NEXA_USE_MOCK`, `NEXA_DEV_TOOLS`, `NEXA_LAUNCH_MODE`, `NEXA_SHOW_*`; `NexaEnvironment.{development,staging,production}` only tunes policies (wss enforcement, verbose logs). Real backend builds use `staging` policies. Secrets via `--dart-define-from-file=~/.nexa/nexa_dev.json` only |
| Backend | `https://52.58.22.19/nexa/api`, app `app_wsyCTDpZNf2yfwbROBcPqQ` (voice-capable token) / `app_1Atzjgrw-kFLRCyF-OojKQ` (live tests); contracts: `labeeb.sdk/1` v1.0.0 (2026-10-28, 35 endpoints) and `nexa.voice.v1` handoff 1.0.0 |
| Docs | `.ai/flutter-architecture.md` (SDK memory, accurate for packages), `.ai/assumptions-and-blockers.md` (B1–B13), 4 ADRs, phase reports, `docs/assistant/ANDROID-ASSISTANT-REPORT.md`, `docs/qa/android-voice-acceptance.md`, contract matrices |
| Quality gates | `tool/check.sh` (format, analyze, all tests), `tool/e2e.sh` (reference gateway + livekit-server + integration_test), no CI definition (B6) |

### 1.1 Actual architecture (as built)

```
apps/nexa_example (LABEEB)            go_router: '/', '/settings', '/settings/assistant', dev '/dev/*'
  AssistantPage ──► client.assistantView()            (SDK widget; pushes its own routes on the host Navigator)
  DeviceAssistant ──► nexa_assistant plugin           (activations → voiceRequests stream; panel overlay; lock gate)
  HostAuthProvider / DevTokenAuthProvider / HostPermissionHandler / LabeebThemeController / QaRecorder (dev)
packages/nexa_sdk
  Nexa.initialize → NexaClient (GetIt scope per client; injectable SdkModule)
    SessionManager (one chat session; owns conversationId; conversationProvider → POST /conversations)
    ChatBloc (per chat view; sequential FIFO; EventSequencer; reconnect back-off; expiry restart)
    NexaVoiceController (VoiceSessionMachine commands → permission → GatewayVoiceProvisioner → LiveKitVoiceTransport)
    LabeebToolCallController (tool-call lifecycle, nexa.ui/1 docs, assets, restore from history)
    NexaHistoryController (server pages via LabeebConversationsApi + bounded JSON cache)
    NexaConversationMedia / NexaDeviceActions / NexaSurfaceController (legacy local surfaces, theme picker)
    Views: NexaAssistantView (chat/home/voice pages), NexaChatView, NexaVoiceView(+Capsule), NexaCompactVoicePanel, NexaHistoryView, NexaUiView
packages/nexa_core   contracts, reducer/sequencer, voice machine + v1 events/verifier/replay guard, nexa.ui/1 parser, tool call model, mocks
packages/nexa_realtime  LiveKitVoiceTransport, LiveKitAudioSetup, stats sampler
packages/nexa_assistant Kotlin: VoiceInteractionService/Session (panel), RecognitionService (delegates), WakeListenerService (FGS microphone), WakeEngine (MFCC+DTW + CAM++), VoiceProfileStore (Keystore AES-GCM), NexaAssistantPlugin (channels)
```

The documented intent in `.ai/flutter-architecture.md` ("SDK for third-party hosts") is still the shape of the code; the product (LABEEB) is the example host. This is sound for Beta: the app layer is thin and the SDK layer is testable. The audit recommends **keeping** this split and adding a thin *conversation coordinator* rather than moving logic into the app.

### 1.2 Professional-foundation scorecard

| Criterion | Finding | Verdict |
|---|---|---|
| Feature-first organisation | `nexa_sdk/lib/src/features/{assistant,chat,dynamic_ui,history,media,tools,voice}` | KEEP |
| Clean boundaries | pure reducers/machines in `nexa_core` (no Flutter), transports behind interfaces, DI per client | KEEP |
| BLoC/Cubit | `ChatBloc` (sealed events, sequential), voice is `ValueNotifier` + pure machine, tool calls `ChangeNotifier`. Mixed but each is appropriate; no second state stack | KEEP (do not convert notifiers to blocs) |
| Dio + Retrofit | `NexaGatewayApi` (Retrofit) for chat, hand-written `LabeebSdkClient` for `labeeb.sdk/1`, `GatewayVoiceProvisioner` for voice; one Dio with auth/request-id/diagnostics interceptors | KEEP (Retrofit for the remaining REST is optional; not worth a migration) |
| Freezed/json_serializable | conversation events, config, DTOs | KEEP |
| go_router | app-level only; SDK pushes routes on the host navigator (by design for an embeddable SDK) | REFACTOR (define the route graph once; see §M-02) |
| get_it/injectable | `buildSdkInjector` → `GetIt.asNewInstance()` per client | KEEP |
| Error normalisation | `mapError` → sealed `NexaException`; `gatewayErrorCode` | KEEP |
| Environment config | dart-defines + `NexaEnvironment`; no flavors; release signs with debug key and allows cleartext | REFACTOR (release hardening, Phase G) |
| Testable boundaries | 462 tests, reference-gateway contract tests, fixture-verified voice contract, 5 live tests against production, 4 device integration tests | KEEP |

Conflicts worth fixing (why they matter): (a) three navigation mechanisms (go_router, SDK `Navigator.push`, panel `Offstage` stack) with no single owner of "which conversation is on screen" → M-02 defects; (b) the local history cache models voice calls as separate conversations (`vs_*`) while the server merges them → M-01/M-04 inconsistency; (c) in-call Android lifecycle is not modelled anywhere (no foreground service, no lifecycle observer) → M-12 gap; (d) the hidden tools session id for voice tool calls is in-memory only → M-06 gap.

## 2. Findings by requirement

### M-01 Conversation-first

| # | Finding | Class | Evidence |
|---|---|---|---|
| F-01.1 | One conversation id is attached to chat session, voice session, uploads and tool answers | VERIFIED WORKING | `session_manager.dart:90-104,125`; `nexa_voice_controller.dart:355-362`; `labeeb_tool_calls.dart:573-580`; device: `tools=true server_tools=54` (2026-10-30) |
| F-01.2 | Conversation creation `client_ref` = `<installation>:<µs timestamp>` regenerated on every attempt → a timed-out `POST /conversations` that the server actually completed is followed by a second create on retry (duplicate conversation) | VERIFIED DEFECT (low frequency) | `nexa.dart:201-216`; contract says create is idempotent per `client_ref` |
| F-01.3 | Root screen is chat-first; the list is behind a history icon; `home` launch mode is a brand splash with two buttons | MISSING (requirement M-01.1) | `nexa_assistant_view.dart:68-74,297-379` |
| F-01.4 | Local cache writes `voice` entries keyed by `vs_*` and `chat` entries keyed by `ses_*` (`conversation.sessionId`), while the server keys by `conv_*`; when server-backed, `recordChat`/`recordVoice` still upsert cache rows that never match server rows (cache bloat, wrong "fromCache" fallback) | VERIFIED DEFECT | `nexa_history.dart:424-476,478-487`; `labeeb_conversations_api.dart:50-51` |
| F-01.5 | Resume: `resumeConversation` ends the session, sets `resumePending`, the chat view is remounted and `ChatBloc._loadResumedHistory` prepends `GET …/messages` (limit 100, one page) | VERIFIED WORKING (one page only; older pages MISSING) | `nexa.dart:221-247`; `chat_bloc.dart:191-215` |
| F-01.6 | After a server `410 session_expired` the bloc opens a new session on the same conversation (≤1/min) | VERIFIED WORKING (unit) | `chat_bloc.dart:487-500`, `chat_bloc_reliability_test.dart` |

### M-02 Direct call and navigation

| # | Finding | Class | Evidence |
|---|---|---|---|
| F-02.1 | Navigation graph: go_router (`/`, `/settings`, `/settings/assistant`, dev-only `/dev`, `/dev/embedded`, `/dev/voice`, `/dev/settings`, `/dev/dynamic-ui`) + SDK pushes (`_liveVoiceRoute` fullscreenDialog; chat from home; `NexaHistoryView` → `NexaHistoryDetailView` → privacy; attach sheets, UI sheets) + the system panel rendered as an `Offstage` stack above the router | PARTIAL (works; three owners) | `main.dart:214-271`; `nexa_assistant_view.dart:76-87,185-208,448-475`; `device_assistant.dart:174-225` |
| F-02.2 | Header "voice" button has no re-entrancy guard: two quick taps push two `_LiveVoicePage`s; the second's `autoStart` is a no-op, but popping either page runs `dispose` → `voice.end()` and ends the call under the other | VERIFIED DEFECT | `nexa_assistant_view.dart:267-273,522-534`; guard only in `_VoiceRequestsState._open` |
| F-02.3 | Call from the home splash returns to the splash, not to the conversation | VERIFIED DEFECT vs M-02.2 | `:365` |
| F-02.4 | Panel cold start: voice controller joins/creates the conversation before `create` | VERIFIED WORKING (device 2026-10-30) | `nexa_voice_controller.dart:336-351`; commit `5f010cb` |
| F-02.5 | Duplicate call screens: `_LiveVoicePage` (full), `NexaCompactVoicePanel` (system panel), dev `VoicePage` (`/dev/voice`). All drive the single `NexaVoiceController`; dev page compiled only with `devTools` | VERIFIED WORKING (one controller) | `nexa.dart:398-401`; `main.dart:243-267` |
| F-02.6 | Back-stack: history resume uses `popUntil(r == chat || r.isFirst)` then remounts chat; voice page `maybePop` ends call; Android system back = same | VERIFIED WORKING (widget tests `assistant_test.dart`) | `nexa_assistant_view.dart:192-201,595-599` |
| F-02.7 | App backgrounding / process death during a call: no `WidgetsBindingObserver` in SDK voice; no foreground service; behaviour on Android 14+/16 when the activity is stopped is not measured | UNKNOWN / NEEDS TEST (likely capture loss after the OS grace) | grep; `flutter_webrtc` manifest has no service |
| F-02.8 | Auth guard: `AssistantPage` shows "not connected" when the dev token is missing/expired; there is no login route (host backend B2) | PARTIAL (by design for Beta) | `assistant_page.dart:28-31,44-63` |
| F-02.9 | Lost conversation id: `newConversation()` sets `conversationId = null` and the next `start()` creates one; a voice call started between `end()` and the chat's `ChatStarted` creates its own (correct) | VERIFIED WORKING | `nexa.dart:249-256`; `session_manager.dart:90-95` |

### M-03 Realtime voice

| # | Finding | Class | Evidence |
|---|---|---|---|
| F-03.1 | Admission errors mapped: 503→retry-after wait, 402→quota, 401/403→auth, 404/409→server code, 422→contract | VERIFIED WORKING (14 fixtures) | `gateway_voice_provisioner.dart`; `backend-compatibility-v1.md` §3 |
| F-03.2 | LiveKit join, mic publish only, agent track subscribe, `resume` handshake with 25 s window, gap repair, Ed25519 verification, replay guard | VERIFIED WORKING (device: ICE connected, events verified 0 rejected) | `livekit_voice_transport.dart`; `voice_event_pipeline.dart`; B1/B11 |
| F-03.3 | Stage model: 16 states with distinct labels/hints (ar/en); `transcribing`/`thinking`/`modelBusy` are distinct; the full capsule does **not** show the tool stage (panel does) | PARTIAL | `nexa_voice_capsule.dart:62-117`; `nexa_compact_voice_panel.dart:216-230`; `nexa_voice_orb.dart:40-67` |
| F-03.4 | `muted` state ignores `VoiceUserSpeechEnded/TranscriptFinal/AssistantThinking`; unmute always returns to `listening` even while the assistant is speaking (label briefly wrong) | VERIFIED DEFECT (cosmetic) | `voice_session_machine.dart:199-213` |
| F-03.5 | Reconnect: `RoomDisconnected` → `GET` within grace → `POST …/token` → rejoin; `RoomReconnected` → re-handshake; agent unresponsive → GET → DELETE | VERIFIED WORKING (unit; live rejoin NOT_TESTED) | `nexa_voice_controller.dart:433-450,610-668` |
| F-03.6 | Cleanup on every exit: `DELETE` then `room.disconnect/dispose`; iOS re-call fix (no mute at end) | VERIFIED WORKING (device: DELETE 200, no capture, no session window) | `:836-862`; QA log |
| F-03.7 | Background operation: no FGS, no lifecycle; iOS has `UIBackgroundModes audio` | MISSING (Android) | `Info.plist:72-75`; manifests |
| F-03.8 | Diagnostics: request ids, durations, phases, tool events, ICE stats; content opt-in | VERIFIED WORKING | `dio_factory.dart:141-200`; `qa_recorder.dart`; `livekit_stats_sampler.dart` |
| F-03.9 | ICE path on NetBird networks fails after ~19 s (backend B10) | BLOCKED_BACKEND | `.ai/assumptions-and-blockers.md` B10 |

### M-04 Transcript synchronisation

| # | Finding | Class | Evidence |
|---|---|---|---|
| F-04.1 | Final user/assistant turns posted via `voice-turns` unless `tools.enabled` (then gateway-recorded) | VERIFIED WORKING (production 200; history shows turns, user-confirmed 2026-10-28) | `nexa_voice_controller.dart:744-786` |
| F-04.2 | After the call, the open `ChatBloc` state is not refreshed: the voice page only writes the local cache (`history.recordVoice`) and the chat timeline shows the turns only after `resumeConversation` or a restart | VERIFIED DEFECT (blocks M-04.2) | `nexa_assistant_view.dart:538-543`; `chat_bloc.dart:191-215` |
| F-04.3 | Interim/final replace-in-place per speaker; `Partial` flag in captions; max 50 entries | VERIFIED WORKING | `nexa_voice_controller.dart:788-811`; capsule |
| F-04.4 | Reconnect resumes from `last_seq`; `covers:false` → cursor jump + snapshot | VERIFIED WORKING (fixtures) | `voice_events_v1.dart:345-392` |
| F-04.5 | Dedupe between client-posted turn and server message: not needed today (client posts only when gateway does not record) but the chat list has no `client_turn_id` matching | PARTIAL | gap G-01 |
| F-04.6 | AWS changes: S1 (conversation id) and S1b (server persistence) are deployed and exercised; S2 (model governance) is unobservable from the client and the client sends no model ids | VERIFIED WORKING (S1, S1b), N/A (S2) | QA log 2026-10-30; `grep model_id` empty |

### M-05 Structured tool responses / Dynamic UI

| # | Finding | Class | Evidence |
|---|---|---|---|
| F-05.1 | `nexa.ui/1` parser enforces schema id, id pattern, limits, duplicate ids, https-only links, extension types; unknown components skipped | VERIFIED WORKING (unit) | `nexa_ui_document.dart:242-364`; `dynamic_ui_test.dart` |
| F-05.2 | Rendering of all 18 components, 4 actions, ordinals; compact mode in the voice companion | VERIFIED WORKING (widget) / device PARTIAL | `nexa_ui_view.dart`; `labeeb_voice_companion.dart` |
| F-05.3 | Spoken vs display text: the client never synthesises speech; captions come from `assistant_text`; display text from components | VERIFIED WORKING | pipeline |
| F-05.4 | Selection path: `ui_event` on `POST /messages` (chat) with a fresh `client_message_id`; in voice the `uiEventSink` is the **chat** bloc's sender, which is unset when no chat view is mounted (panel-only call) → `sendUiEvent` returns `'unavailable'` | VERIFIED DEFECT (voice-only selections) | `labeeb_tool_calls.dart:126,709-713`; `nexa_chat_view.dart:188-192`; panel shows "Show options" → expand only |
| F-05.5 | Duplicate action prevention: tool approval/result answer-once; `ui_event` has no in-flight guard per component (double tap → two events) | PARTIAL | `labeeb_tool_calls.dart:519`; `nexa_ui_view.dart` (no pending set) |
| F-05.6 | Stale document: gateway `422 unknown_ui_component` → code returned to the view | VERIFIED WORKING (unit) | `chat_bloc.dart:137-144` |
| F-05.7 | Theme flow on device with fixture events: PASS; live agent path NOT_TESTED | PARTIAL | `assistant_tools_device_test.dart` |
| F-05.8 | Legacy `NexaSurfaceController` (`dynamic_surface.dart`, `nexa_surface_view.dart` 1469 lines) still used by the host theme picker → two renderers | REFACTOR (migrate picker to `nexa.ui/1`, then REMOVE) | INTEGRATION-MATRIX "FLUTTER_INCOMPLETE" |

### M-06 Tool-calling continuity

| # | Finding | Class | Evidence |
|---|---|---|---|
| F-06.1 | Lifecycle awaiting_approval → approval → awaiting_client → run → result once; 409 closed terminal | VERIFIED WORKING (31 unit tests) | `labeeb_tool_calls.dart:436-552` |
| F-06.2 | Restore from history parts + follow running jobs | VERIFIED WORKING (unit) | `:725-862` |
| F-06.3 | `_sessionOf` (incl. `tools.session_id`) and `_uiValues` in memory only; after a process kill a voice-raised call cannot be answered (no session id) and a half-filled form is lost | VERIFIED DEFECT | `:130-132,923-936` |
| F-06.4 | Orchestration stays on AWS; the client never resolves ordinals | VERIFIED WORKING | by inspection |

### M-07 Mute

| # | Finding | Class | Evidence |
|---|---|---|---|
| F-07.1 | Mute reaches the transport in every live state; `StartCapture` re-applies mute on (re)connect | VERIFIED WORKING (unit + device `rec stop`) | `voice_session_machine.dart:71-96`; `nexa_voice_controller.dart:289-293` |
| F-07.2 | `setMicrophoneEnabled(false)` with `stopAudioCaptureOnMute` default true stops capture immediately; LiveKit signals `TrackMuted` to the SFU/agent; no end-of-speech is sent by the client | VERIFIED (behaviour) | `livekit_audio_setup.dart`; livekit_client docs |
| F-07.3 | Root cause hypothesis for "last request disappears": the agent's VAD/turn detector needs trailing silence frames to end the turn; a mute within the endpointing window (`min_delay` 0.5 s default) stops frames and may leave the turn uncommitted or commit it late. LiveKit Agents docs expose `commit_user_turn(stt_flush_duration)` for manual commit; nothing documents automatic commit on `TrackMuted` | UNKNOWN / NEEDS TEST (backend-dependent) | LiveKit docs (turns, tuning); agents PRs #8303/#8304 (stale VAD commits) |
| F-07.4 | Rapid mute/unmute: each toggle is an engine track enable/disable (capture restart); no debounce | PARTIAL | `nexa_voice_controller.dart:208-215` |
| F-07.5 | Levels forced to 0 while muted; UI reads `state.muted`, not `transport.isMicrophoneEnabled` | PARTIAL (cosmetic honesty) | `:487-491` |

### M-08 Barge-in

| # | Finding | Class | Evidence |
|---|---|---|---|
| F-08.1 | Barge-in is decided by the agent; the client has no interrupt command and no VAD | VERIFIED (contract) | `livekit_voice_transport.dart:152-157` |
| F-08.2 | UI enters `bargeIn` ("Interrupting…") on `user_speech_started` while `aiSpeaking`, before the agent confirms `interrupted` | VERIFIED DEFECT (misleading) | `voice_session_machine.dart:169-173` |
| F-08.3 | AEC/NS/AGC/high-pass on; `VOICE_COMMUNICATION` source; single capture; wake listener off during calls | VERIFIED WORKING (device `dumpsys audio`) | QA log §C |
| F-08.4 | Background speech produced captions and "Interrupting…" on device | FAIL_REPRODUCED (backend VAD) | QA log 2026-10-30 |
| F-08.5 | Gating options exist server-side: `interruption.min_duration` (0.5 s), `min_words` (0, needs STT), `false_interruption_timeout` (2 s) + `resume_false_interruption`, voice isolation (Krisp BVC); LiveKit audio turn detector supports Arabic (14 languages), text detector does not | RESEARCHED | LiveKit docs 2026 |

### M-09 Android assistant

| # | Finding | Class | Evidence |
|---|---|---|---|
| F-09.1 | `VoiceInteractionService` + session service + required `RecognitionService` (delegates to the device recogniser) + `ASSIST`/`VOICE_COMMAND` filters + keyguard launch | VERIFIED WORKING (device: role listed, assist key → panel) | manifest; `AssistantServices.kt`; QA §D |
| F-09.2 | Panel = second `FlutterView` on the cached engine; host view detached while shown; touch region limited to the card | VERIFIED WORKING (device) | `AssistantServices.kt:118-154,193-202` |
| F-09.3 | Wake FGS type `microphone`, `START_NOT_STICKY`, starts only while resumed, boot → notification; Android 14+ rule confirmed in docs; exemption "app provides the VoiceInteractionService" exists for while-in-use restrictions but the code does not rely on it | VERIFIED WORKING (code) / device background NOT_TESTED | `WakeListenerService.kt`; `NexaAssistantPlugin.kt:400-417` |
| F-09.4 | Hardware hotword not possible for installed apps (`MANAGE_HOTWORD_DETECTION` internal|preinstalled) | VERIFIED (platform) | AOSP source |
| F-09.5 | Lock gate: activity shown over keyguard for the activation, content offstage until `requestDismissKeyguard` | VERIFIED WORKING (widget) / device NOT_TESTED | `device_assistant.dart:227-358` |
| F-09.6 | Expand keeps the same `voiceSessionId` | VERIFIED WORKING (unit) / device NOT_TESTED | `device_assistant_test.dart` |
| F-09.7 | OEM: Xiaomi autostart intent + battery settings deep links | VERIFIED WORKING (code) | `NexaAssistantPlugin.kt:375-388` |

### M-10 Wake word

| # | Finding | Class | Evidence |
|---|---|---|---|
| F-10.1 | Implementation is still MFCC (Kaldi fbank) + DTW per enrolled template, energy segmenter (0.6 s hangover), threshold cap 0.30 | VERIFIED | `engine/*.kt` |
| F-10.2 | Real voice: enrolment nearest 0.22–0.41; five owner attempts 0.354–0.422 all rejected; attempts ~0.85 s vs 1.5–2.4 s at enrolment | FAIL_REPRODUCED | QA log; commit `46c6c7f` |
| F-10.3 | Uncommitted benchmark: labelled WAV recorder + ONNX speed test of openWakeWord-style mel + Google speech-embedding (96-d, 1.36 s window, 80 ms step) | PARTIAL (harness only) | diff |
| F-10.4 | Options (researched): **Porcupine** — Arabic listed, custom keyword trained in the console in seconds, Android SDK, offline inference, AccessKey + commercial licence/plan required (free plan evaluation-only per third-party summaries; verify current terms); **openWakeWord** — code Apache-2.0, pre-trained models CC BY-NC-SA, training on synthetic English TTS, non-English not supported officially, Pi-class CPU; **sherpa-onnx KWS** — open-vocabulary within model language, models zh/en only (3–3.3 M params), Arabic would need training a zipformer KWS; **microWakeWord** — MCU-oriented; **hardware hotword** — privileged | RESEARCHED | sources in §5 |

### M-11 Speaker verification

| # | Finding | Class | Evidence |
|---|---|---|---|
| F-11.1 | CAM++ VoxCeleb 16 k ONNX (29.6 MB, Apache-2.0; VoxCeleb CC BY 4.0), ORT 1.29.0; runs only after phrase match; profile v2 keeps per-sample embeddings; score = max(mean, avg top-2); leave-one-out threshold −0.12 clamped 0.40–0.65 | VERIFIED WORKING (code, JVM test) | `WakeEngine.kt:21-82` |
| F-11.2 | Storage: AES-GCM with non-exportable Keystore key, `noBackupFilesDir`; delete flow | VERIFIED WORKING (code) | `VoiceProfileStore.kt` |
| F-11.3 | Replay: 3 s refractory + near-identical DTW (threshold×0.12) | PARTIAL (heuristic; no liveness) | `WakeEngine.kt:134-145` |
| F-11.4 | Never used for authorisation or call audio | VERIFIED WORKING | design + QA §C |
| F-11.5 | Real-voice calibration | NOT_TESTED | QA log |
| F-11.6 | APK +93 MB (3 ABIs) / +62 MB arm64 | VERIFIED | report §7 |

### M-12 Permissions and lifecycle

| # | Finding | Class | Evidence |
|---|---|---|---|
| F-12.1 | Declared: INTERNET, RECORD_AUDIO, MODIFY_AUDIO_SETTINGS, BLUETOOTH(≤30), BLUETOOTH_CONNECT, CAMERA, FINE/COARSE_LOCATION + plugin: FOREGROUND_SERVICE(_MICROPHONE), POST_NOTIFICATIONS, RECEIVE_BOOT_COMPLETED. No unnecessary permission found | VERIFIED WORKING | manifests |
| F-12.2 | Runtime requests at use: mic (call/wake), notification (wake), camera/location/photos (tools) | VERIFIED WORKING | `host_permission_handler.dart`; `device_assistant_page.dart` |
| F-12.3 | `BLUETOOTH_CONNECT` never requested at runtime; headset routing on Android 12+ may be silently limited | MISSING | grep |
| F-12.4 | No in-call foreground service; no audio-focus handling in Dart; engine puts `AudioManager` in communication mode | MISSING / UNKNOWN | §1.1 |
| F-12.5 | Connectivity: no listener; chat back-off (5 attempts, cap 15 s) and voice GET-within-grace are reactive | PARTIAL | `chat_bloc.dart:652-711` |
| F-12.6 | Process termination: no persisted "active call" marker; server ends it (`idle_timeout`/`room_closed`) | PARTIAL | contract §7 |
| F-12.7 | Release config: `usesCleartextTraffic="true"`, debug signing, no minify, universal APK | VERIFIED DEFECT (release hardening) | `AndroidManifest.xml:15`; `build.gradle.kts:28-34` |

### M-13 Performance

All `UNKNOWN / NEEDS TEST` (nothing measured). Hypotheses to verify first: (h1) `_LiveVoicePageState._onState` calls `setState` on every state tick plus a 1 s timer → whole-page rebuilds; (h2) `_ChatBodyState._timeline` sorts messages+media on every build; (h3) `NexaHistoryController.open` fetches up to 10×100 messages serially; (h4) `LabeebToolCallController` notifies on every catalogue refresh; (h5) startup awaits assets, theme file, QA recorder, installation id and history cache before `runApp`; (h6) ONNX Runtime + model add 62 MB arm64 and load time at first wake; (h7) `LiveKitStatsSampler` cadence in diagnostics mode. Leaks: subscriptions are cancelled in `dispose` paths reviewed (`ChatBloc.close`, `NexaVoiceController.dispose`, `_VoiceRequestsState`, `LabeebToolCallController.dispose`); `_follow` timers are cancelled on `reset`. No crash reporting integration (lifecycle stream exists for the host).

### M-14 Accessibility

| # | Finding | Class |
|---|---|---|
| F-14.1 | Directional APIs, bundled Arabic font, contrast test, semantics, live regions, 48 dp, reduced motion | VERIFIED WORKING |
| F-14.2 | Mixed-direction text per message in history detail (`nexaTextDirectionOf`); chat bubbles via `NexaRichText` | VERIFIED WORKING |
| F-14.3 | TalkBack and 200 % text on device | UNKNOWN / NEEDS TEST (B5) |
| F-14.4 | History detail bubble `maxWidth: 320` fixed → cramped at large text | PARTIAL |

### M-15 Authentication

| # | Finding | Class | Evidence |
|---|---|---|---|
| F-15.1 | Token in memory; redacted `toString`; path-only logs; one 401 retry; proactive refresh | VERIFIED WORKING (tests incl. "no token in logs") | `credential_manager.dart`; `dio_factory.dart` |
| F-15.2 | Dev token compiled into debug builds from the secrets file (never typed) | VERIFIED WORKING (policy) | `example_config.dart`; `feedback-dev-token-from-file` |
| F-15.3 | Local caches (`history.json`, `labeeb_theme.json`, media files, QA records, installation id) are per app, not per account | VERIFIED DEFECT (latent until sign-in exists) | `main.dart:69-128` |
| F-15.4 | Tenant/app isolation server-side; `X-Nexa-App-Id` fixed per build | VERIFIED WORKING | `dio_factory.dart:20-25` |
| F-15.5 | Expiry mid-call: 401 → one refresh; dev provider returns the same token → auth error state | PARTIAL (by design) | `dev_token_auth_provider.dart` |

### M-16 Scope

No model identifiers in config, requests or UI (`grep model_id|modelId|llm_model|stt_model|tts_model` → none). `VERIFIED WORKING`.

## 3. Component disposition

| Component | Disposition | Reason |
|---|---|---|
| `nexa_core` reducer/sequencer/machine/verifier/nexa.ui parser | KEEP | pure, tested, contract-verified |
| `ChatBloc` | KEEP + extend (`ChatHistoryMerged` event, `after_seq` reload) | sequential design is right |
| `SessionManager` conversation ownership | REFACTOR → `ConversationCoordinator` facade in `nexa_sdk` (owns id, stable `client_ref`, create policy, post-call reconcile) | three callers mutate `conversationId` today |
| `NexaVoiceController` + `LiveKitVoiceTransport` | KEEP + extend (mute grace, lifecycle hooks, FGS bridge) | contract-aligned, device-verified |
| `NexaAssistantView` navigation | REFACTOR (route graph owned by the app via go_router; SDK exposes pages, not pushes) | M-02 |
| `NexaHistoryController` cache model | REFACTOR (key by `conv_*`, drop `vs_*` entries when server-backed, account scope) | M-01/M-15 |
| `NexaSurfaceController` + `nexa_surface_view.dart` | MIGRATE host theme picker to `nexa.ui/1`, then REMOVE | duplicate renderer |
| `LabeebToolCallController` | KEEP + persist pending state | M-06 |
| `nexa_assistant` Kotlin services | KEEP | correct platform usage |
| `WakeEngine` MFCC+DTW | KEEP as fallback behind an interface; add trained detector | M-10 |
| `nexa_reference_gateway` | KEEP (dev) | contract tests |
| playground `/dev/*` | KEEP (dev-only) | gated by `devTools` |
| Release Gradle config | REFACTOR | signing, cleartext, ABI splits |

## 4. Backend contract gaps (explicit requirements for AWS)

| Id | Gap | Needed by | Proposed requirement (not invented behaviour; a request) |
|---|---|---|---|
| G-01 | `GET /conversations/{id}/messages` pages only backwards (`before_seq`); no `after_seq`; no SSE event on the chat session when a voice turn is recorded | M-04 | add `after_seq` (chronological page) **or** emit `conversation_message_added{channel:voice}` on the open chat session's stream |
| G-02 | No defined agent behaviour on `TrackMuted` for a pending user turn | M-07 | on `TrackMuted` of the user's mic track, commit the pending user turn if ≥ `min_duration` speech was captured (`commit_user_turn` with STT flush), else clear it; publish `user_speech_ended` + final `transcript` as usual |
| G-03 | Barge-in gating and false-interruption resume not configured/observable; `interrupted` has no confidence | M-08 | expose `interruption.min_duration/min_words`, enable `resume_false_interruption`, consider voice isolation; add `confidence` or `reason` to `interrupted` |
| G-04 | `voice_identity` missing from the documented create response | M-03 | document the field |
| G-05 | `client_tools` max 8 undocumented; `cnv_*` vs `conv_*` | M-05 | document |
| G-06 | No way to list open tool calls per conversation (incl. the hidden voice tools session) after a restart | M-06 | `GET /conversations/{id}/tool-calls?status=open` returning `session_id` per call |
| G-07 | Background call policy: `reconnect.grace_seconds` 30 and `idle_timeout` make a backgrounded call die; no "hold" | M-02/M-12 | product decision + optional longer grace for `app_backgrounded` |
| G-08 | `voice-turns` `client_turn_id` charset undocumented | M-04 | document |
| G-09 | Asset upload lacks audio media types while `record_sample` returns audio | M-05 | add `audio/wav` |

## 5. Research notes (sources)

* LiveKit Agents turn handling: endpointing `min_delay` 0.5 s / `max_delay` 3 s; interruption `min_duration` 0.5 s, `min_words` 0, `false_interruption_timeout` 2 s, `resume_false_interruption` true; turn modes vad/stt/realtime_llm/manual; manual `commit_user_turn(stt_flush_duration)`; audio turn detector supports Arabic, text detector does not. (docs.livekit.io/agents/logic/turns, …/tuning, …/turn-detector)
* livekit_client Flutter: `AudioCaptureOptions.stopAudioCaptureOnMute` default true; `setMicrophoneMuteMode(inputMixer)` iOS/macOS only. (docs.livekit.io reference)
* Android: apps targeting 14+ cannot *create* a microphone FGS from the background even with a background-start exemption; while-in-use exemptions include "service started by an app which provides the VoiceInteractionService" and "started by interacting with a notification"; Android 15 requires a visible overlay for the `SYSTEM_ALERT_WINDOW` exemption. (developer.android.com/develop/background-work/services/fgs/restrictions-bg-start)
* Hotword: `createAlwaysOnHotwordDetector` requires `MANAGE_HOTWORD_DETECTION` (internal|preinstalled); `HotwordDetectionService` is a system API. (AOSP)
* Porcupine: Arabic in the supported language list, custom keywords via Picovoice Console (`.ppn` + `_ar.pv` model), Android SDK on Maven, on-device inference; `.ppn` files carry plan restrictions; verify current pricing/terms before committing. (github.com/Picovoice/porcupine; picovoice.ai)
* openWakeWord: code Apache-2.0; pre-trained models CC BY-NC-SA 4.0; custom models from synthetic English TTS; non-English not officially supported. (github.com/dscripka/openWakeWord)
* sherpa-onnx KWS: models zh-en 3M (2025-12-20), zh 3.3M, en 3.3M; open-vocabulary within the model's language. (k2-fsa.github.io/sherpa/onnx/kws)
* CAM++ vs ECAPA-TDNN: CAM++ 0.89 % vs 1.07 % EER VoxCeleb1-E (authors' numbers); sherpa-onnx ships speaker-ID APKs with WeSpeaker CAM++. No anti-spoofing component found for on-device use.

## 6. Unverified assumptions carried into the plan

1. The agent does not commit a user turn on `TrackMuted` (G-02) — to be tested in T-M07-01 before building the grace window.
2. Server-recorded voice turns are returned by `GET …/messages` with `channel: "voice"` and a `seq` after the chat messages (INTEGRATION-MATRIX says history shows them; field shapes unverified).
3. An Android 16 activity in the background keeps WebRTC capture for only a short grace without a microphone FGS (platform behaviour; to be measured in T-M12-02).
4. Porcupine's current commercial terms allow a Beta on two devices under a developer plan (to be checked on picovoice.ai before F-02).
5. `flutter_webrtc` audio-focus handling is adequate for incoming phone calls (T-M12-04).
