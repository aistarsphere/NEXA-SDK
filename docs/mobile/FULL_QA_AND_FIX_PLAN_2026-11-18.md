# AMEER Android — Full QA, benchmarks, defects and fix plan (2026-11-18)

Branch `feature/phase5-3b-voice-contract-v1`, HEAD `48eadff` plus four uncommitted files
(the speaker-mismatch tap-to-talk fix). Device: Nubia NX679J, Android 13, profile build.
Evidence: `docs/qa/evidence/2026-11-18/`.

## 1. Verdict

The code base is healthy at the gate level (0 analyzer issues, 724 Dart tests and 52 Kotlin
tests pass). It is **not ready for Beta users**, for five reasons:

1. **Voice calls did not connect today.** The backend answered `503 — The GPU Realtime plan is
   FAILED`, and the retry timed out after 30 s. This is a backend state, not an app bug, but
   nothing inside a call (barge-in, mute, voice tools) could be tested.
2. **The wake listener uses 25–40 % of one CPU core all the time.** It will drain the battery.
3. **The test APK is 242 MB** because it carries three CPU architectures.
4. **Ending or recovering a call is not tied to that call.** Recovery applies its result without
   checking that the same call is still current, and End waits for a network request before it
   releases the microphone.
5. **Several native safety gaps**: one model error in the wake loop crashes the app, and two
   recording paths rely only on a Dart flag for consent.

Chat was slow in the first run (60–85 s per reply) and normal in the second (tool request
after 8 s, reply after 7 s). The slow run happened while the voice backend was failing, so it is
recorded as a backend incident, not an app defect. The app still gives no "still working"
feedback when that happens.

## 2. What was tested

| Area | Result | Notes |
|---|---|---|
| Analyzer + all Dart tests (`tool/check.sh`) | Pass | 0 issues, 724 tests |
| Kotlin unit tests | Pass | 52 tests |
| Coverage per package | Measured | section 3.1 |
| APK size and contents | Measured | section 3.2 |
| Start-up, memory, background CPU | Measured | `runtime-benchmarks.txt` |
| Chat send and reply | Pass (run 2); slow in run 1 | `chat-slow-reply.png`, `chat-tool-declined.png` |
| Tool call in chat (location request, declined) | Pass | card shown, decline recorded, assistant answered |
| Conversation list (history) | Pass | list loads; no screenshot kept because it shows the owner's conversation titles |
| Settings: Arabic / English switch | Pass | `settings-ar-dark.png`, `settings-en-light.png` |
| Settings: light theme | Pass | same |
| Large font (system scale 1.3) | **Defect** | "System" breaks in the middle of the word, `settings-en-light-font1.3-wrap.png` |
| Assistant page, voice card, setup checklist, wake-phrase page | Open and render | three screenshots; nothing was recorded, no consent tapped |
| Voice call | **Blocked by backend** | `voice-call-log.txt`, `voice-call-503.png` |
| Barge-in, mute, voice tools | **Not tested** | need a working voice backend |
| Tool approval path, other tool types | **Not tested this round** | approving would send the owner's location |
| Wake try-out, voice test, enrolment | **Not tested** | need the owner's voice and consent |
| Xiaomi (HyperOS 3 / Android 16) | **Not tested** | stopped at the owner's request |
| iOS | **Not tested** | no build was made |
| Frame timing (jank) | **Not measured** | `gfxinfo` gives no data for Flutter here |
| Code audit: SDK / core / realtime | Done by a review agent | items marked Confirmed were re-read by me |
| Code audit: app UI | Done by a review agent | same |
| Code audit: Android plugin (Kotlin) | **Partial**, by me | read: `WakeListenerService`, `EmbeddingWakeDetector`, `OnnxWakeFeatures`, parts of `NexaAssistantPlugin` and `VoiceSetup`. Not read: `AssistantServices`, `Activation`, `VoiceProfileStore`, `CallForegroundService`, `UtteranceRecorder`. Foreground-service rules and key storage were not reviewed |

## 3. Benchmarks

### 3.1 Tests and coverage

| Package | Tests | Line coverage |
|---|---|---|
| nexa_core | 126 | 66.0 % |
| nexa_sdk | 329 | 74.6 % |
| nexa_ui | 82 | 78.2 % |
| nexa_realtime | 4 | **11.1 %** |
| nexa_device | 18 | 56.6 % |
| nexa_assistant (Dart) | 49 | 76.8 % |
| app | 116 | 64.4 % |

Largest untested files: `device_assistant_page.dart` (519 of 520 lines), `nexa_surface_view.dart`
(418 of 713), `nexa_tool_card.dart` (0 %). The LiveKit transport, which carries every call, is
almost untested.

### 3.2 Size and structure

- APK 242 MB (profile, universal). Native libraries for arm64 (69.9 MB), x86_64 (52.4 MB) and
  armeabi-v7a (28.3 MB) are all inside; `libonnxruntime.so` alone is about 89 MB across the
  three. The speaker model is 28 MB. Removing the two unneeded architectures takes out about
  80 MB; a release build split per architecture has not been measured yet.
- 180 Dart files, 23 of them over 500 lines. Largest: `nexa_surface_view.dart` 1469,
  `labeeb_tool_calls.dart` 1119, `nexa_voice_capsule.dart` 1087, `nexa_ui_view.dart` 1059,
  `nexa_voice_controller.dart` 1034, `nexa_media_widgets.dart` 1025, `device_assistant_page.dart` 1000.
  Kotlin: `NexaAssistantPlugin.kt` 991, `VoiceSetup.kt` 632.
- 74 broad `catch` blocks, 116 `unawaited` calls, about 405 inline `_t(en, ar)` strings in the
  app instead of ARB files, 43 public names still called `Labeeb*`.

### 3.3 Runtime (Nubia)

| Measure | Value |
|---|---|
| Start after force-stop | 354–377 ms (3 runs); 377–491 ms in the first run |
| Warm start | 95–104 ms |
| Memory, foreground idle | 314–338 MB PSS |
| Memory, background | 226 MB PSS |
| Wake listener thread, app idle | **25–31 % of one core (run 2), 33–40 % (run 1), continuous** |
| Chat reply | run 1: 60–85 s; run 2: 8 s to the tool request, 7 s to the reply |
| Voice session | 503 in 1.4 s; retry timed out at 30 s |

## 4. Defects

"Confirmed" means I read the code or saw it on the device. "Reported" means a review agent
found it and I have not re-read it line by line.

### P0 — blocks Beta

| # | Defect | Where | Status |
|---|---|---|---|
| B-1 | Voice backend returns 503 "GPU Realtime plan is FAILED" | backend | Confirmed on device. Not an app change; needs the AWS team |
| B-2 | Chat replies took 60–85 s in one run, normal in the next | backend incident; the app shows only typing dots meanwhile | Seen once, did not reproduce |
| W-1 | Wake listener runs the mel and embedding models on every 80 ms of audio, including silence | `engine/EmbeddingWakeDetector.kt:64-82` | Confirmed (code and CPU measurement) |
| S-1 | APK ships three architectures; no `abiFilters` or split | `apps/nexa_example/android/app/build.gradle.kts` | Confirmed |

### P1 — wrong behaviour a user will meet

| # | Defect | Where | Status |
|---|---|---|---|
| V-1 | Recovery awaits the gateway, then applies "ended" or rejoins without checking the call id is still the current one; the only guard is the phase | `nexa_voice_controller.dart:752-810` | Confirmed in code; not reproduced on device |
| V-2 | End waits for the server `DELETE` before it disconnects, so the microphone stays published until that request returns or times out | `nexa_voice_controller.dart:978-1004` | Confirmed in code |
| V-3 | Audio levels are only sent when diagnostics are on, and the default diagnostics object is off, so a host that does not pass one gets no levels | `livekit_voice_transport.dart:275, 336-390`; `nexa_diagnostics.dart:28` | Confirmed in code |
| V-4 | A server 503 is shown with a "no Wi-Fi" icon and "connection lost", and a request timeout as "You are offline", although the phone is online | voice error mapping | Confirmed on device |
| V-5 | The voice session request can hang for 30 s; what the screen shows meanwhile was not captured | call page | To check |
| T-1 | Tool calls do not check that the session is still the same after each `await` | `labeeb_tool_calls.dart:495, 506, 556` | Reported |
| T-2 | A tool result that fails to post is never retried; the assistant waits for ever | `labeeb_tool_calls.dart:555-587` | Reported |
| C-1 | History `refresh()` races an in-flight `loadMore` | `nexa_history.dart:399-430` | Reported |
| C-2 | `resumePending` is cleared before the load and not retried on failure | `chat_bloc.dart:201-215` | Reported |
| C-3 | Typed text is lost when an attachment upload fails: the composer has already cleared and the handler returns after a snackbar | `nexa_composer.dart:62-68`, `nexa_chat_view.dart:219-246` | Confirmed in code |
| C-4 | The chat stream has no idle watchdog; a stalled stream shows typing dots for ever | `gateway_chat_transport.dart:132` | Reported, fits B-2 |
| U-1 | "Set up again" does not start a new voice enrolment | `voice_wizard_page.dart:83-92` | Reported |
| U-2 | Wake try-out shows every failure as "allow the microphone" and prints raw scores | `wake_phrase_page.dart:150-156` | Reported |
| U-3 | Checks card and permission sheet show developer text and raw enum names to normal users | `device_assistant_page.dart:181, 285-293, 340-342` | Reported |
| U-4 | Server-sent UI properties are cast without validation inside `build` | `nexa_ui_view.dart:298, 324, 356-357` | Reported |
| U-5 | Chat header still says «لبيب»; iOS is still branded LABEEB, English only | company profile; `ios/Runner/Info.plist` | Confirmed (Android header) |
| K-1 | No `try/catch` in the wake loop, the detector or the model wrapper: one model error ends the app process | `WakeListenerService.kt:258-318`, `OnnxWakeFeatures.kt` | Confirmed in code; crash not reproduced |
| K-2 | Stopping the listener waits on the main thread (up to 1.5 s), then closes the models while the worker may still use them | `WakeListenerService.kt:161-172` | Confirmed (code); crash not reproduced |
| K-3 | Two separate "busy" flags (`busyRecording` in the plugin, `busy` in `VoiceSetup`): a plugin recording and a setup recording do not exclude each other | `NexaAssistantPlugin.kt:75`, `VoiceSetup.kt:62` | Confirmed |
| K-4 | `benchRecord` (writes WAV files) and legacy `enrollmentRecord` check only the microphone permission, not the recorded consent; only the Dart developer flag hides them. `wakeTest` with the owner check also runs the voice comparison without a consent check (it stores nothing) | `NexaAssistantPlugin.kt:238, 281, 317, 826` | Confirmed in code |
| U-6 | At system font scale 1.3 the theme selector breaks "System" in the middle of the word | settings page | Confirmed on device |
| R-1 | No production sign-in: a release build against the real backend has an empty token | `main.dart` | Reported |
| R-2 | Start-up has no error path and release uses `NoopCrashSink`, so field crashes are invisible | `main.dart:55-171` | Reported |

"History screen unreachable in list mode" was reported but is by design (the list is the
history, `nexa_assistant_view.dart:357-359`). Only the settings text needs to match.

### P2 — quality, privacy hygiene, robustness

- Wake scores and decisions are logged in release builds (`WakeListenerService.kt:224-231, 313`). Scores only, no audio, but they should be debug-only.
- The `wake_dry_run` marker file works in release builds (`WakeListenerService.kt:219`).
- When no phrase model is installed the listener stops without closing its models (`WakeListenerService.kt:284-289`).
- Resume RPC fields are trusted without a signature (`voice_event_pipeline.dart:84-99`).
- `asset_id` from the server is used in a temp file path without cleaning (`labeeb_device_tools.dart:387-403`).
- History cache is plain text, written non-atomically and rewritten on every change (`nexa_history.dart:175, 187`).
- Polling continues after dispose (`_follow`); session can start after logout; `_injector` used after dispose (`nexa.dart:289-292`).
- Static `Set _opened` shared by all views (`nexa_ui_view.dart:982`); `setState` after `await` without a mounted check (`device_assistant_page.dart:81, 88`); double taps push a page twice; camera can open twice (`camera_capture.dart:156-195`).
- Unconditional `debugPrint` in release; plugin errors rethrown and leave endless spinners.
- Dead code: legacy `VoiceEnrollmentPage`, probably `voice_setup/`, the older `WakeEngine` template path.
- After the user taps "Not now" on a location request, the assistant says the permission is missing and to change it in device settings; the decline should be reported as a decline (tool result wording or backend prompt).
- Dependencies behind (for example `permission_handler` 12 → 13).

### Architecture weaknesses

- Seven files over 1000 lines mix UI, state and transport.
- Two tool-call stacks and two dynamic-UI renderers do the same job.
- Wiring through mutable public fields and a `Nexa._client` singleton; `nexa.dart` imports Material.
- Two string systems (ARB in the SDK, inline `_t(en, ar)` in the app).
- One 991-line Kotlin plugin class owns channels, recording, enrolment, benchmarks and services, with raw threads and no single owner of the microphone.

## 5. Plan

One commit per task, tests first, device evidence for every device claim. Nothing is pushed.

### Phase 0 — unblock (owner / AWS, no app code)

1. Send the realtime 503 and the one slow chat run to the AWS team with `voice-call-log.txt`.
2. Decide on the four uncommitted files (speaker-mismatch tap-to-talk fix): commit or drop.

### Phase 1 — Beta blockers in the app (about 3–4 days)

| Task | Change | Done when |
|---|---|---|
| P1-1 (W-1) | Gate the wake models behind a cheap energy/VAD check; keep feeding the mel context so detection quality does not change | Idle CPU under 5 % on the Nubia; `wake_eval.py` recall and false-accept unchanged |
| P1-2 (S-1) | `abiFilters` arm64-v8a (+ armeabi-v7a if needed) or split per ABI; R8 on | Release arm64 APK size measured and recorded |
| P1-3 | Wrap the wake loop in `try/catch`, stop cleanly with an `error` state; stop the worker off the main thread and close models only after it exits | Kotlin tests for a throwing engine and stop/start in quick succession |
| P1-4 | One `MicrophoneOwner` (atomic) used by plugin, `VoiceSetup` and wake service | Test: second recorder gets `busy` |
| P1-5 | Native consent check on every path that stores audio or compares the owner's voice; the plain phrase try-out stays free. Compile `benchRecord` and legacy enrolment out of release | Test: each guarded method returns `consent_required` without consent |
| P1-6 | Timeout shown as "server is slow", not "offline"; progress and cancel on the connecting state; "still working" hint in chat after 10 s; chat stream idle watchdog | Widget tests; device screenshot |
| P1-7 | Emit audio levels regardless of diagnostics | Unit test on the transport |

### Phase 2 — call and chat correctness (about 4–5 days)

Every item marked Reported starts with a failing test that proves it; if the test cannot be
made to fail, the item is closed as not a defect.

| Task | Change |
|---|---|
| P2-1 | Generation token in the voice controller; every async step checks it (V-1), microphone unpublished first on End (V-2) |
| P2-2 | Same guard in tool calls; retry the tool-result post with backoff (T-1, T-2) |
| P2-3 | History refresh/loadMore serialised; `resumePending` restored on failure (C-1, C-2) |
| P2-4 | Keep the draft until the upload succeeds (C-3) |
| P2-5 | Validate server UI properties before build (U-4) |
| P2-6 | Tests for `nexa_realtime` with a fake room: target 60 % |

### Phase 3 — user-facing polish (about 3 days)

U-1, U-2, U-3, U-6, U-5 (AMEER naming on Android header and iOS), settings text about history,
debug-only logs, double-tap guards, mounted checks, crash sink for release (R-2).
Then the device pass that was not done this round: both languages, light theme, large font,
tool calls, barge-in, mute, on the Nubia and the Xiaomi.

### Phase 4 — refactor (about 1–2 weeks, after Beta blockers)

1. Split the seven 1000-line files by responsibility (view / controller / transport).
2. Merge the two tool stacks and the two dynamic-UI renderers into one each.
3. Split `NexaAssistantPlugin.kt` into channel handlers, a recording service and the dev tools.
4. Move the app's inline strings to ARB; rename `Labeeb*` to neutral names with deprecated aliases.
5. Delete the dead enrolment code and the old template wake engine.
6. Replace public mutable wiring with constructor injection; remove Material from `nexa.dart`.

### Still needs the owner

- The real quick voice setup (consent in the app, two sentences) and guest recordings for calibration.
- Approval to send the AWS requests and the Beta `assets:write` credential request.
- Production sign-in design (R-1).
