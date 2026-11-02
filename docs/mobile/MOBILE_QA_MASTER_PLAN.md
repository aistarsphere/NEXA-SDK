# LABEEB Beta Mobile — QA Master Plan

Version 1.0, 2026-11-03. Traces every requirement in `MOBILE_BETA_REQUIREMENTS.md` to tests. Evidence conventions follow `docs/qa/android-voice-acceptance.md`: `PASS_REAL_DEVICE`, `FAIL_REPRODUCED`, `BLOCKED_BACKEND`, `NOT_IMPLEMENTED`, `NOT_TESTED`, plus `PASS_UNIT` / `PASS_WIDGET` / `PASS_INTEGRATION` for automated levels. Unit, widget, mock and emulator runs are **never** counted as device passes.

## 1. Devices, builds, environments

| Device | OS | Serial | Role |
|---|---|---|---|
| Xiaomi 25010PN30G | Android 16 / HyperOS 3.0 | 2ba15772 | primary (OEM background policy, Android 16 FGS rules) |
| Nubia NX679J (RedMagic) | Android 13 | bf5c6761 | secondary (Android 13 behaviour) |
| iPhone 15 | iOS 27 | — | out of Beta scope (smoke only) |

Builds: profile for performance and acceptance, debug for `adb run-as` QA pulls; always `--dart-define-from-file=~/.nexa/nexa_dev.json`; `NEXA_DEV_TOOLS=true` for diagnostics. Backend: `https://52.58.22.19/nexa/api` (QA quota is shared; one short call per check). Reference gateway + `livekit-server --dev` for integration tests (`tool/e2e.sh`).

Evidence location: `docs/qa/evidence/<yyyy-mm-dd>/<test-id>/` (logs via `dart run tool/qa.dart pull|report`, `adb shell dumpsys audio`, screenshots). Logs must not contain tokens or transcript text unless the tester enabled capture for that session.

## 2. Quality gates

| Gate | Command | When | Blocking |
|---|---|---|---|
| Q1 static | `flutter analyze packages apps tools` | every task | yes |
| Q2 format | `dart format --set-exit-if-changed …` (in `tool/check.sh`) | every task | yes |
| Q3 unit/widget | `tool/check.sh` (all packages) | every task touching the package; otherwise only the touched package's `flutter test` | yes |
| Q4 Kotlin | `cd apps/nexa_example/android && ./gradlew :nexa_assistant:testDebugUnitTest` | tasks touching `nexa_assistant/android` | yes |
| Q5 targeted integration | `tool/e2e.sh <device> integration_test/<file>` | tasks in Phases B–E | yes for the named file |
| Q6 builds | `flutter build apk --debug`, `flutter build appbundle --release` (G-03) | Phase gates | yes |
| Q7 manifest/permissions | `aapt dump permissions` diff against the allow-list in §6 | G-03 and any manifest change | yes |
| Q8 device acceptance | this plan's `T-*` device rows | phase gates | BLOCKING rows marked `B` |
| Q9 perf baseline | `tool/perf.sh` | G-01 and before release | advisory until G-01 sets targets |
| Q10 contract | `packages/nexa_sdk/test/live/labeeb_live_test.dart` (5 tests, production) + voice fixtures | when a contract snapshot changes | yes |

Do not rerun the whole suite for unrelated one-line changes: run the touched package's tests and Q1. Use existing evidence when the code under test did not change (record the commit hash of the evidence).

## 3. Traceability matrix

Columns: Test id · Level · Setup · Steps · Expected · Failure signature · Evidence · Automation · Device · Pass/fail · Blocking (B = blocks Beta).

### M-01 Conversation-first

| Id | Level | Setup | Steps | Expected | Failure signature | Evidence | Automation | Device | Pass/fail | B |
|---|---|---|---|---|---|---|---|---|---|---|
| T-M01-01 | unit | mocktail `LabeebSdkClient` | `ensureConversation` ×3 with first two throwing `NetworkException` | one `client_ref` reused; one id | different `client_ref`s | test log | `conversation_coordinator_test.dart` (new) | — | id equal, refs equal | B |
| T-M01-02 | unit | same | chat and voice call `ensureConversation` concurrently | one POST | two POSTs | test log | same | — | call count 1 | B |
| T-M01-03 | widget | `InMemoryHistoryStore` + fake server api | render list root: empty, loading, error, 3 items; tap item | routes `/c/<id>`; RTL golden matches | missing route / overflow | golden | `conversation_list_page_test.dart` (new) | — | all states | B |
| T-M01-04 | integration | reference gateway | login → list → new → send → list shows it with count 2 | server list contains the conversation | not listed | gateway log | `reference_gateway_integration_test.dart` (extend) | emulator | pass | B |
| T-M01-05 | device | profile build, Xiaomi | create 2 conversations, chat in each, force-stop, reopen | list shows both, newest first; open continues with full history | missing/duplicated entries | screenshots + `qa.dart report` | manual | 2ba15772 | pass | B |
| T-M01-06 | unit | cache store | server-backed run with a voice call | no `vs_*` rows written | `vs_` key present | test | `history_identity_test.dart` (extend) | — | pass | B |

### M-02 Navigation and direct call

| Id | Level | Setup | Steps | Expected | Failure signature | Evidence | Automation | Device | Pass/fail | B |
|---|---|---|---|---|---|---|---|---|---|---|
| T-M02-01 | widget | router harness | tap voice twice within 100 ms | one `/call` route | two routes | test | `labeeb_router_test.dart` (new) | — | route count 1 | B |
| T-M02-02 | widget | same | call from list → end | lands on `/c/<new id>`; chat mounted on that id | lands on `/` | test | same | — | pass | B |
| T-M02-03 | widget | same | history → detail → resume | `/c/<id>`, chat remounted, earlier messages shown | stale chat | test | same + `assistant_test.dart` | — | pass | B |
| T-M02-04 | device | Xiaomi, assist key with app closed | panel → say two sentences → close → open app | list contains a new conversation with the turns | no conversation / empty | log `voice tool event`, screenshots | manual | 2ba15772 | pass | B |
| T-M02-05 | device | Xiaomi | in a call press Home, wait 120 s, return | call still live (both directions audible), notification shown | audio dead / call ended | `dumpsys activity services`, audio recording note | manual | 2ba15772 + bf5c6761 | pass | B |
| T-M02-06 | device | Xiaomi | in a call swipe the app from Recents | call ended on server (`DELETE` or `idle_timeout`), no capture left | capture lingering | `dumpsys audio` | manual | 2ba15772 | pass | B |
| T-M02-07 | device | both | kill app mid-call, reopen | list → conversation intact; no stuck "reconnecting" | stuck UI | screenshots | manual | both | pass | B |

### M-03 Realtime voice

| Id | Level | Setup | Steps | Expected | Failure signature | Evidence | Automation | Device | Pass/fail | B |
|---|---|---|---|---|---|---|---|---|---|---|
| T-M03-01 | unit | fixtures | all 14 error fixtures + create/refresh/status/delete | mapped exceptions as in `backend-compatibility-v1.md` | mapping drift | test | `gateway_voice_provisioner_test.dart` (exists) | — | pass | B |
| T-M03-02 | unit | `MockRealtimeVoiceTransport` | drive events in contract order | labels change only on causal events: `connecting`→`listening` (RealtimeConnected), `userSpeaking` (user_speech_started), `transcribing` (ended), `thinking` (assistant_thinking / final transcript), `aiSpeaking` (audio_started), `listening` (turn_ended) | label without event | test | `voice_controller_test.dart` (extend with a stage table) | — | pass | B |
| T-M03-03 | unit | mock provisioner 503 `Retry-After: 5` | start, then start again at t+2 s | second start waits until t+5 s | immediate retry | test | exists ("503 … waits") | — | pass | B |
| T-M03-04 | integration | reference gateway + livekit-server | journey: join, mic published, agent audio subscribed, mute/unmute, end | events → states; `DELETE` | missing state | `voice_journey_test.dart` (exists) | emulator | pass | B |
| T-M03-05 | device | Xiaomi, Wi-Fi | call; toggle airplane mode 10 s; back on | `reconnecting` → `listening`, captions continue, no duplicates | stuck reconnecting / duplicates | `qa.dart report latest-voice` (`voice.recover_done outcome=rejoined`) | manual | 2ba15772 | pass | B |
| T-M03-06 | device | both | end call via X, via back, via notification (A-03) | `DELETE 200`; `dumpsys audio` no capture; no LiveKit room | capture/room lingering | logs | manual | both | pass | B |
| T-M03-07 | unit | `QaRecorder` with mocks | record a call | no `nxs_`/JWT/`public_key` strings in any record | token in record | test | `qa_recorder_test.dart` (exists) | — | pass | B |
| T-M03-08 | device | Xiaomi | tool-enabled call: "ابحث عن مقهى قريب" | capsule shows "Working: Places" (C-03) only while the call is running | generic "Thinking" | screenshot + events | manual | 2ba15772 | pass | — |

### M-04 Transcript synchronisation

| Id | Level | Setup | Steps | Expected | Failure signature | Evidence | Automation | Device | Pass/fail | B |
|---|---|---|---|---|---|---|---|---|---|---|
| T-M04-01 | unit | reducer | `mergePersisted` with overlaps (same id, same text ±1 s, new) | no duplicates; order by createdAt/seq; `origin: voice` kept | dup bubble | test | `conversation_reducer_test.dart` (extend) | — | pass | B |
| T-M04-02 | bloc | mocked coordinator | `ChatHistoryMerged` after SSE events | state merged; `lastKnownSeq` updated | regression | bloc_test | `chat_bloc_test.dart` (extend) | — | pass | B |
| T-M04-03 | integration | reference gateway recording voice turns | call → 3 turns → close | chat list shows 6 messages once within 2 s | missing/dup | test | `chat_journey_test.dart` (extend) | emulator | pass | B |
| T-M04-04 | device | Xiaomi, open chat | call with 3 exchanges → close | 6 bubbles with mic glyph, once, ordered | missing | screenshot + `GET messages` dump | manual | 2ba15772 | pass | B |
| T-M04-05 | device | Xiaomi | same but airplane 10 s mid-call | no missing turn; no duplicate | dup/missing | same | manual | 2ba15772 | pass | B |
| T-M04-06 | device | Xiaomi | kill app during a call; reopen conversation | server-recorded turns present | missing | screenshot | manual | 2ba15772 | pass | — |
| T-M04-07 | unit | controller | interim then mute (no final) | transcript entry `isFinal:false` shown as Partial, not dropped | dropped | test | `voice_controller_test.dart` | — | pass | B |

### M-05 Dynamic UI

| Id | Level | Setup | Steps | Expected | Failure signature | Evidence | Automation | Device | Pass/fail | B |
|---|---|---|---|---|---|---|---|---|---|---|
| T-M05-01 | widget | 18 component docs | render each in `ar` (RTL) and `en`, text scale 1.0 and 2.0 | no overflow; semantics labels present; directional layout | overflow / missing label | goldens | `dynamic_ui_test.dart` (extend) | — | pass | B |
| T-M05-02 | unit | parser | oversize, deep, dup ids, bad schema, unknown type | rejected / skipped per contract | crash | test | `labeeb_sdk_1_test.dart` (exists) | — | pass | B |
| T-M05-03 | widget | doc with `choice` | double-tap option | one `ui_event`; control disabled while in flight | two events | test | `dynamic_ui_test.dart` | — | pass | B |
| T-M05-04 | widget | sink returns `unknown_ui_component` | tap | document marked expired; label shown | re-enabled | test | same | — | pass | B |
| T-M05-05 | device | Xiaomi, panel or call page | «لبيب، غيّرلي شكل التطبيق» | palettes shown; tap applies; one `/result`; classification TOOL_NOT_EMITTED / TOOL_NOT_RENDERED / ACTION_NOT_EXECUTED / RESULT_NOT_ACKNOWLEDGED when failing | per QA log | `voice tool event:` log lines, screenshots | manual | 2ba15772 | pass or BLOCKED_BACKEND | B |
| T-M05-06 | device | Xiaomi | malformed `ui_presented` (fixture test) | no card, no crash, `ui.rejected` | crash | `assistant_tools_device_test.dart` (exists) | automated on device | 2ba15772 | pass | B |
| T-M05-07 | device | Xiaomi, voice-only panel (D-02) | choose an option in the panel-expanded view | selection accepted on the chat session, or `409 voice_session` recorded as BLOCKED_BACKEND | silent failure | log | manual | 2ba15772 | pass/blocked | — |

### M-06 Tool continuity

| Id | Level | Setup | Steps | Expected | Failure signature | Evidence | Automation | Device | Pass/fail | B |
|---|---|---|---|---|---|---|---|---|---|---|
| T-M06-01 | unit | pending store | export at `awaiting_approval`, import, `restore(messages)` | call shown with live status; Allow sends one approval | re-run / second approval | test | `labeeb_tool_calls_test.dart` (extend) | — | pass | B |
| T-M06-02 | unit | voice-raised call | kill/import | answered in persisted `tools.session_id` | `session_not_found` | test | same | — | pass | — |
| T-M06-03 | unit | existing | approval/result/cancel idempotency, 409 terminal | once | twice | test | exists (31 tests) | — | pass | B |
| T-M06-04 | device | Xiaomi | start theme flow, kill app at the card, reopen | card shows live status; no auto-action | wrong status | screenshots | manual | 2ba15772 | pass | — |

### M-07 Mute

| Id | Level | Setup | Steps | Expected | Failure signature | Evidence | Automation | Device | Pass/fail | B |
|---|---|---|---|---|---|---|---|---|---|---|
| T-M07-00 | unit | machine | mute in all 8 live states + deferred path | `muted` + transport command | missing command | test | `voice_session_machine_test.dart` (exists + extend) | — | pass | B |
| T-M07-01 | device | Xiaomi, quiet room, live call | say a full sentence; tap Mute within 0.3 s of finishing; wait 10 s | sentence transcribed (final `transcript`), assistant replies; `rec stop` within grace | no `user_speech_ended`, no reply ("request disappears") | `qa.dart report` events + `dumpsys audio` timestamps | manual | 2ba15772 | pass / FAIL_REPRODUCED → feeds E-01 | B |
| T-M07-02 | device | same | tap Mute mid-word | partial transcript shown as Partial; no reply or an honest "I didn't catch that"; unmute, speak → normal | ghost reply from old audio | same | manual | 2ba15772 | pass | B |
| T-M07-03 | device | same | 10 mute/unmute taps in 3 s, then speak | ≤ 2 transport toggles (E-02); final state = last tap; speech recognised | stuck muted / crash | log + `dumpsys` | manual | 2ba15772 | pass | B |
| T-M07-04 | device | same | mute while assistant speaks | audio continues; `muted` label; no barge-in | audio stops | log | manual | 2ba15772 | pass | B |
| T-M07-05 | device | same | mute, airplane 10 s, back | stays muted after rejoin (`StartCapture` re-applies) | unmuted after reconnect | `voice.microphone` records | manual | 2ba15772 | pass | B |
| T-M07-06 | device | same | mute, Expand panel → full screen | stays muted; icon correct | unmuted | screenshot | manual | 2ba15772 | pass | — |

### M-08 Barge-in

| Id | Level | Setup | Steps | Expected | Failure signature | Evidence | Automation | Device | Pass/fail | B |
|---|---|---|---|---|---|---|---|---|---|---|
| T-M08-01 | unit | controller | `user_speech_started` during `aiSpeaking`; then `interrupted` | label "listening to you" then "Interrupting" | early "Interrupting" | test | `voice_controller_test.dart` | — | pass | — |
| T-M08-02 | device | Xiaomi, 6 scenarios: quiet, fan/AC, TV at 1 m, other person talking, assistant on speaker (echo), owner interrupting over noise | one reply each, 30 s | record per scenario: `user_speech_started`, `interrupted{cancel_id}`, whether the assistant stopped, local level | — (evidence) | `docs/qa/barge-in-evidence.md` | manual | 2ba15772 | evidence collected | — |
| T-M08-03 | device | same | playback echo test: assistant speaks at max volume, nobody talks | no `user_speech_started` | self-interruption | log | manual | both | pass | B |

### M-09 Android assistant

| Id | Level | Setup | Steps | Expected | Failure signature | Evidence | Automation | Device | Pass/fail | B |
|---|---|---|---|---|---|---|---|---|---|---|
| T-M09-01 | device | both | Settings → choose LABEEB in Android | status card "verified"; `isDefaultAssistant` true | false | screenshot | manual | both | PASS_REAL_DEVICE (Nubia 2026-10-30) | B |
| T-M09-02 | device | both | assist key over another app | panel; spoken exchange; close | no panel | screenshot/log | manual | both | PASS_REAL_DEVICE (Xiaomi 2026-10-30) | B |
| T-M09-03 | device | both | lock phone; voice assist from keyguard | gate → unlock → call; "Not now" leaves | content visible before unlock | screenshots | manual | both | NOT_TESTED | B |
| T-M09-04 | device | Xiaomi | Expand from panel | same `voice_session_id`; no second `POST /voice/sessions` | second session | log | manual | 2ba15772 | NOT_TESTED | — |
| T-M09-05 | device | both | reboot with wake on | notification; open app → listening resumes | no notification | screenshot | manual | both | NOT_TESTED | — |
| T-M09-06 | device | Xiaomi | enable wake, lock, wait 30 min | listener still running (Autostart/No restrictions documented) | killed | `dumpsys activity services`, battery | manual | 2ba15772 | NOT_TESTED | — |
| T-M09-07 | unit | mocked plugin | activation with no chat → new conversation; with chat → join (F-05) | correct reason | wrong | test | `device_assistant_test.dart` (extend) | — | pass | — |

### M-10 Wake word

| Id | Level | Setup | Steps | Expected | Failure signature | Evidence | Automation | Device | Pass/fail | B |
|---|---|---|---|---|---|---|---|---|---|---|
| T-M10-01 | device | dev benchmark page (F-01) | record ≥ 20 owner clips «يا لبيب», ≥ 20 other phrases, ≥ 10 other speakers, 1 h TV/noise | labelled WAVs under `files/wake_bench` | — | clip inventory | manual | both | collected | — |
| T-M10-02 | JVM | `tool/wake_bench.sh` | run DTW and Porcupine (F-02) on the clips | report: TA/FA per engine/threshold | — | `docs/qa/wake-benchmark-<date>.md` | script | — | numbers | — |
| T-M10-03 | device | chosen engine | 20 live attempts quiet/1 m; 20 at 3 m; 1 h TV | TA ≥ 90 % quiet; FA ≤ 1/8 h extrapolated | below | log `NexaWake decision=` | manual | both | pass | — |
| T-M10-04 | device | idle listening 30 min | `dumpsys batterystats`, `top` | ≤ 5 % one core; battery delta recorded | above | files | manual | both | numbers | — |

### M-11 Speaker verification

| Id | Level | Setup | Steps | Expected | Failure signature | Evidence | Automation | Device | Pass/fail | B |
|---|---|---|---|---|---|---|---|---|---|---|
| T-M11-01 | widget | settings page | consent → enrol → delete | consent text shown; delete clears `enrolled` | missing consent | test | `assistant_test.dart` (extend) | — | pass | — |
| T-M11-02 | device | both | re-enrol owner 5×; test owner 5×, stranger 3×, noisy owner 3× | table of `voice=s/t`; FA 0; TA ≥ 4/5 | FA > 0 | `docs/qa/speaker-calibration-<date>.md` | manual | both | numbers | — |
| T-M11-03 | JVM | existing | refractory, replay suspected, variation accepted, stranger rejected | pass | fail | test | `WakeEngineTest.kt` (8 tests) | — | pass | — |
| T-M11-04 | review | code | grep: no server action gated by speaker score | none | found | review note | manual | — | pass | B |

### M-12 Permissions and lifecycle

| Id | Level | Setup | Steps | Expected | Failure signature | Evidence | Automation | Device | Pass/fail | B |
|---|---|---|---|---|---|---|---|---|---|---|
| T-M12-01 | device | both, fresh install | deny mic → start call | capsule shows denied state + Open settings; grant → works | crash / endless connecting | screenshots | manual | both | pass | B |
| T-M12-02 | device | Xiaomi + Nubia | call, Home, 2 min (A-03) | audible both ways; notification; End action works | silence | audio note + `dumpsys` | manual | both | pass | B |
| T-M12-03 | device | Xiaomi, BT headset | call with headset connected before and after start | audio via headset; route chip correct; `BLUETOOTH_CONNECT` prompted once | speaker only | screenshots | manual | 2ba15772 | pass | — |
| T-M12-04 | device | Xiaomi | incoming phone call during LABEEB call | LABEEB muted/ended with visible state; resumes or shows Retry after | both audios mixed | log | manual | 2ba15772 | pass | — |
| T-M12-05 | device | Xiaomi | airplane 10 s during chat streaming | reconnecting banner → resumes from cursor, no duplicate text | dup | screenshot | manual | 2ba15772 | pass | B |
| T-M12-06 | static | `aapt dump permissions` | compare with allow-list §6 | identical | extra permission | diff | script in G-05 | — | pass | B |
| T-M12-07 | device | Xiaomi | notifications denied (Android 13+) → enable wake | listener starts; settings shows "notifications off" row | silent failure | screenshot | manual | 2ba15772 | pass | — |

### M-13 Performance

| Id | Level | Setup | Steps | Expected | Failure signature | Evidence | Automation | Device | Pass/fail | B |
|---|---|---|---|---|---|---|---|---|---|---|
| T-M13-01 | device | profile, `--trace-startup` | cold start ×5 | median time to interactive ≤ 2.0 s | above | `docs/qa/perf-baseline.md` | `tool/perf.sh` | both | numbers | — |
| T-M13-02 | integration | reference gateway seeded 200 messages | scroll chat | ≤ 1 % frames > 16 ms | jank | timeline export | integration_test | emulator/device | numbers | — |
| T-M13-03 | device | DevTools | 20 call start/end cycles | memory flat ±5 %; no growing subscriptions | growth | snapshot | manual | 2ba15772 | numbers | B |
| T-M13-04 | device | DevTools rebuild counter | idle call page 60 s | ≤ 10 rebuilds/s | more | screenshot | manual | 2ba15772 | numbers | — |
| T-M13-05 | device | battery stats | wake listener 30 min idle | see T-M10-04 | — | — | — | — | — | — |

### M-14 Accessibility

| Id | Level | Setup | Steps | Expected | Failure signature | Evidence | Automation | Device | Pass/fail | B |
|---|---|---|---|---|---|---|---|---|---|---|
| T-M14-01 | device | TalkBack on, Arabic | navigate list → chat → send → call → mute → end | every control announced; state changes announced via live regions | silent control | script results | manual | 2ba15772 | pass | B |
| T-M14-02 | widget | `textScaler 2.0` | list, chat, call, settings, UI docs | no overflow | overflow | goldens | tests (extend) | — | pass | B |
| T-M14-03 | unit | existing | contrast ≥ 4.5:1 both modes | pass | fail | test | `theme_contrast_test.dart` | — | pass | B |
| T-M14-04 | widget | mixed ar/en message | direction per message | correct | wrong | test | `rich_text_test.dart` (exists) | — | pass | — |

### M-15 Authentication

| Id | Level | Setup | Steps | Expected | Failure signature | Evidence | Automation | Device | Pass/fail | B |
|---|---|---|---|---|---|---|---|---|---|---|
| T-M15-01 | integration | reference gateway + `MemoryNexaLogger` | full journey | no token in logs/diagnostics | token found | test | exists ("no token in logs") | — | pass | B |
| T-M15-02 | unit | two `accountKey`s (B-02) | A chats; dispose; B loads | B sees empty cache; A's file untouched; `clearLocalData(A)` removes it | leakage | test | `history_identity_test.dart` (extend) | — | pass | B |
| T-M15-03 | integration | reference gateway 401 then 200 | mid-journey | one refresh, continues | loop | test | exists | — | pass | B |
| T-M15-04 | device | expired dev token | start call | auth state within 5 s; chat banner "access expired" | endless connecting | screenshot | manual | 2ba15772 | pass | — |

### M-16 Scope

| Id | Level | Steps | Expected | Automation | B |
|---|---|---|---|---|---|
| T-M16-01 | static | `grep -rn "model_id\|modelId\|llm_model\|stt_model\|tts_model" packages/*/lib apps/*/lib` | empty | script in G-05 | B |

## 4. Backend contract testing

| Area | Method | Status today | Owner |
|---|---|---|---|
| Conversations / messages / voice-turns | `labeeb_live_test.dart` against production (5 tests); add `messages` shape test (`channel`, `seq`, `created_at`) and `after_seq` once G-01 ships | 5/5 pass (2026-10-29) | SDK |
| Voice admission / lifecycle | 23 fixtures + live calls (QA log) | pass | SDK |
| Voice events | verification vectors + live (0 rejected) | pass | SDK |
| Tool UI actions | fixture device test + live T-M05-05 | fixture pass; live pending | SDK + AWS |
| Error codes | 14 error fixtures + contract `errors.codes` snapshot test | pass | SDK |
| Auth / quotas | 401 refresh, 402, 429 tests | pass | SDK |
| Mute commit (G-02), barge-in tuning (G-03), open tool calls (G-06) | manual device evidence until the backend publishes behaviour | BLOCKED_BACKEND | AWS |

Rule: a claim "works against AWS" needs a dated live-test run or a device log; local backend source is not evidence.

## 5. Blocking vs non-blocking

**BLOCKING Beta defects** (must be `PASS_REAL_DEVICE` or `PASS_INTEGRATION` where marked `B`): M-01 duplicate/lost conversations; M-02 double call page, root-call landing, background call survival; M-04 post-call turns missing in chat; M-05 live theme flow or an honest BLOCKED_BACKEND with evidence; M-07 cases 01–05; M-08 self-echo interruption; M-12 denied mic, background call, airplane reconnect; M-15 no token in logs, account-scoped cache; release build hardened (G-03).

**Non-blocking technical debt:** legacy surface renderer removal (D-04); older-page history (B-03); live transcript cards (C-02); wake-word model choice (M-10, Beta ships with assist-gesture entry); speaker verification default-on (M-11); performance optimisation beyond measurement (G-01); iOS.

## 6. Permission allow-list (for Q7)

`android.permission.INTERNET`, `RECORD_AUDIO`, `MODIFY_AUDIO_SETTINGS`, `BLUETOOTH` (≤30), `BLUETOOTH_CONNECT`, `CAMERA`, `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION`, `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_MICROPHONE`, `POST_NOTIFICATIONS`, `RECEIVE_BOOT_COMPLETED`, plus plugin-declared `READ_MEDIA_IMAGES`/storage from `image_picker`/`file_picker` if present (verify with `aapt`). Anything else fails Q7 until justified in `.ai/mobile.md`.

## 7. Execution checklist (copy into `MOBILE_IMPLEMENTATION_STATUS.md` evidence column)

```
[ ] Q1 analyze green (commit <hash>)
[ ] Q3 touched package tests green (log path)
[ ] Q5 integration file green on <device> (log path)
[ ] T-xx-yy device rows run, evidence at docs/qa/evidence/<date>/<id>/
[ ] Backend-dependent rows marked BLOCKED_BACKEND with the G-xx id
```
