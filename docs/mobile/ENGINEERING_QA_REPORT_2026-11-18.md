# AMEER Flutter — Engineering audit, feature QA and blocked-test resume (2026-11-18, round 2)

Branch `feature/phase5-3b-voice-contract-v1` (local only, never pushed). Code under test: `9289ec6`
(the profile build on the phone was made from the same tree before that commit).
Device: Nubia NX679J, Android 13 (API 33), adb `bf5c6761`. No other device was available.
Evidence: `docs/qa/evidence/2026-11-18/` (round 1) and `docs/qa/evidence/2026-11-18/round2/`.
This report supersedes `FULL_QA_AND_FIX_PLAN_2026-11-18.md`; section 9 gives the status of every item of that file.

Labels: **PASS** (seen on the device), **FAIL** (seen on the device), **BLOCKED** (cannot run, reason given),
**NOT TESTED**, **NOT IMPLEMENTED**. "Unit" means automated tests only and is never counted as PASS.
"Code" means confirmed by reading the code, not reproduced on the device.

## 1. Executive summary

**Realtime voice is still blocked by the backend.** Eight admission requests between 14:10 and 14:30
all failed: the gateway answered `503 voice_model_preparing — STT trained-whisper-09849ed0dad3 is being
prepared by the GPU` after 33–36 s each time. No call reached `listening`, so nothing inside a call
(audio, transcription, barge-in, mute, voice tools, reconnect, background) could be tested. This is
reported as BLOCKED, not passed. Authentication, chat, tools and the contract endpoint work.

**The same failure exposed a real app defect.** The app waits 30 s for admission; the gateway answers
after 33–36 s. The app therefore never sees the real reason and tells the user "You are offline"
while Wi-Fi is fine (REL-01).

**Engineering quality.** The SDK is layered sensibly (core / ui / realtime / device / assistant / sdk),
the gates are green (0 analyzer issues, 752 Dart tests, 53 Kotlin tests), secrets handling is sound
(token in memory only, HTTPS only, voice profile encrypted with a Keystore key, consent enforced in
native code for the voice setup). The weak points are concentrated, not spread out:

1. two 1000-line controller classes (voice call, tool calls) where the lifecycle defects live;
2. the Android plugin: raw threads, no single owner of the microphone, no error containment in the wake loop;
3. the wake listener's constant CPU use (28 % of one core; target in the requirements is 5 %);
4. almost no tests on the LiveKit transport (11 % line coverage) and none on the largest app page;
5. several user-facing gaps found on the device this round (picked file silently dropped, no way to
   rename or delete one conversation, large-font breakage, misleading errors).

**Beta readiness: not ready.** Blocking: voice backend (BE-01), admission timeout (REL-01), wake CPU
(PERF-01), APK packaging (PERF-02), wake-loop crash containment (REL-03), call lifecycle (REL-02, REL-04),
attachment and conversation-management defects (COR-01, COR-12), no production sign-in and no release key
(MISS-01, MISS-02). Everything that needs the owner's real voice is NOT TESTED.

## 2. Backend readiness (checked first)

| Check | Result | Evidence |
|---|---|---|
| Gateway reachable, contract served | PASS: `GET /v1/sdk/contract` 200 in 0.5 s, `labeeb.sdk/1.0.0` | direct request with the dev token |
| Authentication | PASS: `GET /v1/sdk/assistant` 200, `GET /v1/sdk/tools` 200 | same |
| Chat session, message, events | PASS on device (tool request after 8 s, reply after 7 s) | `chat-tool-declined.png` |
| Voice admission | **BLOCKED**: 8 × `503 voice_model_preparing`, 33–36 s each, `retry_after_seconds: 15` | `round2/voice-admission-probes.txt` |
| GPU Realtime READY | **Not ready** by the gateway's own answer (STT model still "being prepared" for at least 18 minutes) | same |
| Expected global STT / LLM / TTS configuration | NOT TESTED. No session was granted, so no grant or diagnostics exist. The only model name seen is the STT id in the error. No document in the repo states the expected ids, so none is asserted here | — |
| Errors reported accurately by the app | **FAIL**: shown as "offline" (REL-01, UX-01) | `voice-call-log.txt`, round 2 log |

The app never sends model ids (requirement M-16.1); nothing was changed on the backend.
Note: the owner's own conversation from today contains voice turns, so voice worked at some point today;
it did not work at any time during this test window.

## 3. Requirements baseline

Sources: `MOBILE_BETA_REQUIREMENTS.md` (M-01…M-16, v1.0 2026-11-03), `MOBILE_QA_MASTER_PLAN.md` (T-Mxx rows),
`AMEER_CURRENT_IMPLEMENTATION_STATUS.md` (2026-11-04) and the later owner briefs (AMEER branding, «يا أمير»
and custom wake phrases, quick voice setup, assistant setup checklist). Where a brief replaced a
requirement the row says "superseded by brief". Nothing below is an invented requirement.

Ambiguous or missing in the documents: expected model ids for a call; a target for memory; whether
single-conversation rename/delete must be in the root list (M-01 lists it for history; the app's
settings text promises it); the supported minimum for text scale on the assistant pages (M-14 says 200 %).

## 4. Feature completeness and traceability matrix

Device = this round on the Nubia unless a date is given. Earlier device evidence is cited, not re-counted.

### Chat and conversations

| Feature (requirement) | Implemented | Automated | Device result | Notes |
|---|---|---|---|---|
| Send and receive (M-01) | yes | bloc and view tests | **PASS** | 7–8 s per step in run 2 |
| Conversation creation, stable `client_ref` (M-01.3) | yes | 9 coordinator tests | **PASS** (new conversation created and listed) | offline-then-online case NOT TESTED |
| Root list from the server (M-01.1) | yes | 8 list tests | **PASS** with defect COR-07 (list not refreshed on return; pull-to-refresh fixes it) | |
| Message count in the list | yes | — | **FAIL** (COR-08): a 2-message conversation shows "1" | cause not established |
| Open an old conversation, history loads (M-01.2) | yes | bloc tests | **PASS** | declined tool card restored with its state |
| Rename / delete one conversation | code exists (`NexaHistoryView`) | history tests | **NOT IMPLEMENTED in the default list mode** (COR-12) | no action on the list or in the chat; Settings says it exists |
| Delete all assistant data | yes | — | NOT TESTED (destructive on the owner's data) | |
| Persistence across restart | yes | cache tests | **PASS** after force-stop (round 1) | `am kill` does not end the process while the wake service runs |
| Arabic and English UI | yes | l10n tests | **PASS** both languages, RTL and LTR | |
| Streaming | yes | transport tests | NOT TESTED as such (replies arrived whole within the 2–5 s polling of the test) | |
| Cancel generation | yes | bloc tests | **PASS** before the first token (cancel request sent, composer re-enabled); mid-text cancel NOT TESTED | no "stopped" marker (COR-11) |
| Attach: choose a file | yes | — | **FAIL** (COR-01): the picked PNG was dropped silently, no chip, no upload, no error | 1 of 1 attempt |
| Attach: camera, gallery, share location | yes | device-tool tests | NOT TESTED (would use the owner's photos or location) | |
| Upload failure keeps the typed text | no | — | Code: text is lost (COR-02) | not reproduced: the upload never started |
| Retry and recovery | partly | reliability tests | NOT TESTED on device | resume failure has no retry (COR-05) |
| Tool request, card, denial (M-05, M-06) | yes | 31 + UI tests | **PASS**: location request card, "Not now", state "declined", assistant continued | wording defect COR-10 |
| Tool approval and execution | yes | same | NOT TESTED this round (would send the owner's location); typed theme flow PASS on 2026-11-04 | |
| Structured envelopes, no duplicates | yes | parser + reducer tests | **PASS** for the flows above (each message once) | malformed input: unit only |

### Realtime voice (M-02, M-03, M-04, M-07, M-08)

| Feature | Implemented | Automated | Device result |
|---|---|---|---|
| Call start and connection | yes | controller + provisioner tests | **BLOCKED** (BE-01) |
| Microphone capture, playback, transcription, reply, TTS | yes | journey test (reference gateway) | **BLOCKED**. Last device PASS: 2026-11-04 |
| Barge-in | client honest; decision is server-side | machine tests | **BLOCKED**; false barge-in from background speech reproduced 2026-10-30 (backend, G-03) |
| Mute / unmute | yes | "every live state" test | **BLOCKED**; final-utterance delivery (E-01) NOT IMPLEMENTED |
| End call, immediate microphone release | yes | tests | **BLOCKED**; Code: release waits for the server request (REL-04) |
| Reconnect and recovery | yes | tests | **BLOCKED**; Code: race (REL-02) |
| Background / foreground during a call | yes (call service) | tests | **BLOCKED**; PASS for 40 s on 2026-11-04 |
| Network loss, timeout | partly | tests | Timeout path **FAIL** (REL-01, UX-01) |
| Voice tool calls | yes (V-01 fixed 2026-11-04) | 12 pipeline tests | **BLOCKED**; PASS on 2026-11-04 |
| Rapid start / end | double-push guard | router tests | **BLOCKED** |
| Model ids and session diagnostics | app never selects models | — | NOT TESTED (no session) |
| Turns appear in the chat after a call (M-04) | yes | merge tests | **BLOCKED** |

### Wake word and activation (M-09, M-10; phrases superseded by brief: «يا أمير», «أمير», «عباس»)

| Feature | Implemented | Automated | Device result |
|---|---|---|---|
| Three phrases, each with its own model | yes, all marked "experimental" (synthetic training only) | head parity + detector tests | Page renders, **PASS** |
| Detection in the foreground, synthetic voice | yes | — | **PASS** 4 of 4 plays of «يا أمير» (scores 0.91–0.999) |
| Detection of the owner's real voice | — | — | **NOT TESTED** (needs the owner). No reliability is claimed |
| Background / screen-off detection | yes | — | NOT TESTED this round; PASS with synthetic voice on 2026-11-04 |
| False positives on speech | — | — | 60 s of non-wake Arabic TTS: no decision logged. Too short to give a rate: NOT TESTED as a rate |
| CPU in silence | — | — | **FAIL**: 27.9 % of one core (target ≤ 5 %, M-10.1) |
| Battery | — | — | NOT TESTED (phone was charging over USB) |
| Recovery after a native model error | no | 1 test pins the gap | Code: the process ends (REL-03) |
| Force-stop and reboot limits | handled by design (not sticky; boot notification) | — | Force-stop then open: listener restarts, **PASS**. Reboot NOT TESTED |
| Default-assistant invocation | yes | tests | Role held and shown as verified, **PASS**; gesture not re-run (PASS 2026-10-30 / 11-04) |
| Lock-screen behaviour | hands over to the app's unlock gate | policy tests | NOT TESTED this round (PASS 2026-11-04 on this phone) |
| Tap-to-talk when the voice is not accepted | yes (commit `9289ec6`) | none for the new branch | **PASS**: 4 mismatches → one tap-to-talk notification, no call opened |

### Voice identity and enrolment (M-11; flow superseded by brief: quick setup)

| Feature | Implemented | Automated | Device result |
|---|---|---|---|
| Consent before any recording | yes, checked natively in the four `VoiceSetup` recording and build entry points | wizard tests | NOT TESTED on device (I must not tap consent for the owner) |
| Quick guided flow, VAD recording, quality checks | yes | recorder + policy tests | **NOT TESTED** (owner's voice) |
| Owner verification | yes | synthetic tests | **NOT TESTED** (owner's voice) |
| Rejection of another speaker | yes | tests | **PASS** for a synthetic voice only: 4 of 4 rejected (score −0.02…0.14, threshold about 0.46) |
| Low-confidence handling → tap-to-talk | yes | tests | PASS for mismatch; the "uncertain" band NOT TESTED |
| Encrypted on-device storage | yes: AES-GCM, non-exportable Keystore key, no-backup directory, atomic write | — | Code PASS |
| Retry / cancel, permission handling | yes | tests | NOT TESTED |
| No recording without consent | yes for the setup; **no native check** on two developer paths (SEC-01) | — | Code |
| "Set up again" | opens the wizard, which resumes at "try it" for a ready profile | — | Code: does not re-record (UX-03). Not tapped: it could alter the owner's profile |

### Android integration (M-09, M-12)

| Feature | Device result |
|---|---|
| Assistant role, setup checklist with real signals | **PASS** (role, microphone, notifications, listening shown "verified"; battery "to do"; maker screen "set, not tested") |
| Wake listener foreground service, type microphone, notification | **PASS** (`dumpsys`: foreground, started while the app was on top) |
| Call foreground service | **BLOCKED** this round; PASS 2026-11-04 |
| Permission lifecycle (revoke while running) | NOT TESTED |
| Background execution limits, battery restrictions | NOT TESTED beyond the above |
| Process death | `am kill` cannot end the process while the wake service runs (expected); force-stop PASS |
| Android 14+ rules | **NOT TESTED** (no device). Code review only: services are started only while the app is visible, not sticky; one risk noted (REL-08) |
| Xiaomi / HyperOS | **NOT TESTED** (not connected) |
| Bluetooth permission and audio routes (M-12.1, .3) | NOT IMPLEMENTED (E-03 not started, per status document) |

### App-wide UX (M-14 and briefs)

| Feature | Device result |
|---|---|
| Arabic RTL and English LTR | **PASS** |
| Dark / light / system theme | **PASS** |
| Text scale 200 % | **FAIL** (UX-02): assistant page selectors break words and clip; chat header truncates the name. Chat body and settings are fine |
| TalkBack | NOT TESTED |
| Navigation and back | **PASS** for list → chat → call → close → chat, settings → assistant → sub-pages → back |
| Empty / loading / error states | Error state for voice is misleading (UX-01); others NOT TESTED |
| AMEER branding | App title, theme name, pages: PASS. Assistant name in the chat header is «لبيب»: it comes from the company profile on the backend (BE-03). iOS branding NOT TESTED |
| State persistence (language, theme) | **PASS** (changed and restored) |
| Onboarding and setup checklist | **PASS** (renders with correct states) |

### Other implemented features found in the repository

Dynamic UI renderer (18 components), theme tool, places/maps cards, media viewer, QA recorder and
developer pages (dev builds only), reference gateway for integration tests, crash sink hook
(no vendor), wake benchmark page. None of these was device-tested this round except the tool card above.

## 5. Automated tests

| Suite | Result |
|---|---|
| `tool/check.sh` (format, analyze, all Dart tests) | **ALL CHECKS PASSED**, 0 analyzer issues |
| nexa_core / reference gateway / nexa_ui / nexa_realtime / nexa_device / nexa_assistant / nexa_sdk / app | 126 / 28 (+6 skipped) / 82 / 4 / 18 / 49 / 329 (+12 skipped) / 116 |
| Kotlin `:nexa_assistant:testDebugUnitTest` | 53 pass (1 added this round: `aModelErrorIsNotContainedByTheEngine`) |
| Line coverage (measured in round 1, same code) | core 66.0 %, sdk 74.6 %, ui 78.2 %, **realtime 11.1 %**, device 56.6 %, assistant 76.8 %, app 64.4 % |
| Device integration tests (`tool/e2e.sh`) | NOT RUN this round |

Coverage gaps that matter: `livekit_voice_transport.dart` (every call goes through it),
`device_assistant_page.dart` (519 of 520 lines uncovered), `nexa_surface_view.dart` (418 of 713),
`nexa_tool_card.dart` (0 %), the Kotlin services (`WakeListenerService`, `CallForegroundService`,
`ActivationRouter`: no tests), and the two new branches of commit `9289ec6`.
Only one regression test was added this round; the register names the test each fix needs.

## 6. Device test records (round 2)

Environment for all rows: Nubia NX679J, Android 13, profile build with developer tools, Wi-Fi, Arabic UI.

| # | Feature | Steps | Expected | Actual | Result | Evidence | Repeats |
|---|---|---|---|---|---|---|---|
| D1 | Voice admission | tap the call button | call connects or a truthful error | request sent 14:10:05, client timeout 14:10:36, screen says "You are offline" | **FAIL** (app) / **BLOCKED** (backend) | `round2/voice-admission-probes.txt` | 3 of 3 today (1 × 503 shown, 2 × timeout) |
| D2 | Open old conversation | tap an entry in the list | messages load before typing | session created, messages fetched, shown | PASS | log lines in this report only (owner's text not stored) | 2 of 2 |
| D3 | List refresh | create a chat, go back | new chat listed | not listed until pull-to-refresh | **FAIL** | observed via accessibility dump | 1 of 1 |
| D4 | Cancel generation | send a long request, tap stop after 6 s | reply stops, composer usable | cancel request sent, no reply text, composer usable | PASS (before first token) | `round2/chat-stop-generation.png` | 1 |
| D5 | Attach a file | attach → choose a file → pick a 64×64 test PNG → type → send | attachment chip, upload, message with file | no chip, no upload request, text sent alone, no error | **FAIL** | `round2/chat-attach-file-dropped.png` | 1 of 1 |
| D6 | Rename / delete a conversation | long-press an entry; look for actions in the chat | rename and delete offered | long-press opens the chat; no action anywhere | **NOT IMPLEMENTED** (list mode) | code: `nexa_conversation_list_page.dart` has only open | — |
| D7 | Process kill | Home, `am kill`, reopen | state kept | process survives (foreground service), chat still open | PASS | — | 1 |
| D8 | Font scale 2.0, Arabic | chat, settings, assistant page | no clipping | selectors on the assistant page break and clip; header truncates | **FAIL** | `round2/f2_assistant_ar2.png`, `round2/f2_chat_ar.png` | 1 |
| D9 | Wake CPU, silent room | 120 s, per-thread CPU ticks | ≤ 5 % of a core | 27.9 % (`nexa-wake`), 35.7 % whole process | **FAIL** | section 7 | 3 measurements today: 25–31 %, 33–40 %, 27.9 % |
| D10 | Wake CPU during speech | 60 s of Arabic TTS | — | 28.5 % | same cost as silence | section 7 | 1 |
| D11 | Wake phrase, synthetic voice | play «يا أمير» 4 times | phrase detected; voice not accepted; tap-to-talk offered; no call | 4 detected, 4 `speaker_mismatch`, one notification, no call | PASS | `round2/wake-synthetic-mismatch-tap-to-talk.txt` | 4 of 4 |
| D12 | Dry-run marker absent | list the app's external files | no `wake_dry_run` | absent | PASS | — | — |

The phone was restored afterwards: font scale 1.0, Arabic, system theme, test file removed.
Two test conversations of mine remain in the list ("hello what can you do", "show my current location on a map")
because single deletion is not available (D6).

## 7. Performance

| Measure | Value | Target (M-13 / M-10) | Verdict |
|---|---|---|---|
| Start after force-stop | 354–377 ms (3 runs), 377–491 ms earlier | ≤ 2.0 s | PASS |
| Warm start | 95–104 ms | — | fine |
| Memory, foreground idle | 314–338 MB PSS | none set | noted; ONNX sessions and the Flutter engine dominate |
| Wake thread, silent room, 120 s | **27.9 % of one core** | ≤ 5 % | **FAIL** |
| Wake thread, 72 minutes since start | 1338 CPU-seconds ≈ 31 % average | ≤ 5 % | **FAIL** |
| Wake thread during speech | 28.5 % | — | identical to silence: the cost is unconditional |
| Universal profile APK | 254 MB (three architectures) | budget "to be documented" | **FAIL** as packaged |
| arm64-only profile APK (built this round) | 117 MB | — | measured |
| arm64-only release APK (build of 2026-11-04) | 97.7 MB | — | measured earlier, not rebuilt |
| Chat reply | 7–8 s (run 2); 60–85 s once (run 1, backend incident) | none | noted |
| Voice latency, audio latency | — | — | **BLOCKED** |
| Frame timing / jank | — | 60 fps list | NOT MEASURED (`gfxinfo` gives no Flutter data; `tool/perf.sh` named in the QA plan does not exist) |
| Leaks over 20 call cycles | — | flat ± 5 % | **BLOCKED** |
| Battery | — | — | NOT TESTED (USB power) |
| Network usage, audio buffer allocations | — | — | NOT MEASURED |

**Why the wake listener is expensive.** `EmbeddingWakeDetector.process()` runs the mel model, the
speech-embedding model and the classifier on every 80 ms chunk, with no check for silence. On a desktop
proxy the embedding model is about 96 % of that cost (68.9 ms versus 2.9 ms for the mel pass per 10 s of audio).

**Can it be gated without losing detections?** Offline simulation (`tools/wake_training/vad_gate_sim.py`,
no app change): keep the cheap mel model running so the context stays warm, run the embedding model and
the classifier only while a simple energy gate is open, and compute the last 16 embeddings in one batch
when the gate opens (scores are then identical while the gate is open).
Result on 360 augmented synthetic positives (levels −28…−2 dBFS, noise or babble at 2–26 dB SNR):
the ungated detector found 342; **all four gate settings kept all 342 (0 lost)**; in steady noise at
−70, −60 and −50 dBFS the gate stayed closed 100 % of the time. Detection latency does not change with
back-fill. Limits: synthetic clips that the classifier was trained on, not the phone's microphone and
not real voices. It supports doing the change; it does not prove recall on the owner's voice.
Expected effect on the phone: silence cost falls to roughly the mel pass plus audio reading (a few percent);
this must be measured after the change (PERF-01).

## 8. Security and privacy

Good, confirmed in code:
- SDK token is kept in memory only; no token, key or text in logs (tests assert it); HTTPS only, cleartext disabled in the manifest, `wss` enforced, voice events signature-checked.
- Voice profile: embeddings only, AES-GCM with a non-exportable Android Keystore key, stored in the no-backup directory, deleted together with its key.
- Raw audio is not kept by default. Clips are written only when the person chose "keep clips" in the guided setup.
- Consent is enforced in native code at the four `VoiceSetup` entry points that record or build a profile (`record`, `enrollRecord`, `voiceTest`, `finish`).
- Microphone services are not sticky, start only while the app is visible, and stop on task removal (call service).
- The owner-voice result only shows a badge; it authorises nothing (checked: the only reader is the compact panel's badge).
- Lock screen: an activation while locked goes to the app's unlock gate, never straight into a call.

Findings (details in the register):

| ID | Finding |
|---|---|
| SEC-01 | `benchRecord` (writes WAV files) and the legacy `enrollmentRecord` check only the microphone permission in native code. Consent for them exists only as a Dart developer flag. In a release build the Dart entry is hidden, but the native methods remain callable from Dart |
| SEC-02 | `android:allowBackup` is not set, so Android's default (on) applies: the conversation cache (plain JSON), pending tool state and preferences can go into the device backup. The voice profile is excluded (no-backup directory) |
| SEC-03 | Kept clips and benchmark WAVs live in the app's external files folder. On Android 10 and older, other apps with storage permission can read that folder (minimum supported version is Android 7) |
| SEC-04 | Wake scores and decisions are logged in release builds, and the `wake_dry_run` marker file is honoured in release builds |
| SEC-05 | Activation extras (`source`, `verified`) are read from any intent that launches the main activity. Another app could make the "verified" badge appear. No authorisation depends on it |
| SEC-06 | Conversation cache is plain text and written non-atomically |
| SEC-07 | Speaker verification has no liveness check (a recording of the owner can pass). By design it is a convenience gate only; keep it that way |
| SEC-08 | `NexaRecognitionService` is exported without its own permission (required by Android for a recognition service) and relays to the device recogniser. The framework checks the caller's microphone permission; low risk, noted |

Not reviewed: iOS, the reference gateway, dependency CVEs, permission revocation at run time. No penetration testing was done.

## 9. Status of every item in the 2026-11-18 plan

| Old ID | New ID | Status now |
|---|---|---|
| B-1 voice 503 | BE-01 | **Reproduced again** (different message: STT model preparing). Blocked |
| B-2 slow chat | BE-05 | Not reproducible in round 2 |
| W-1 wake CPU | PERF-01 | **Reproduced and confirmed** (27.9 %; root cause in code; gating simulated) |
| S-1 APK size | PERF-02 | **Confirmed and measured** (254 → 117 MB with arm64 only) |
| V-1 recovery race | REL-02 | Confirmed by code inspection; not reproducible on device (blocked) |
| V-2 End waits for DELETE | REL-04 | Confirmed by code inspection; device blocked |
| V-3 audio levels | REL-11 | Confirmed by code inspection (default diagnostics object is disabled) |
| V-4 misleading errors | UX-01 | **Reproduced** (third time) |
| V-5 30 s without feedback | REL-01 | **Reproduced**; screen during the wait still not captured |
| T-1 tool calls after `await` | COR-04 | Confirmed by code inspection (force-unwrap after an awaited request) |
| T-2 tool result not retried | COR-03 | Confirmed by code inspection |
| C-1 history race | COR-06 | Confirmed by code inspection |
| C-2 resume not retried | COR-05 | Confirmed by code inspection |
| C-3 text lost on upload failure | COR-02 | Confirmed by code inspection; device attempt hit COR-01 first |
| C-4 no stream watchdog | REL-09 | Confirmed by code inspection (no client idle detection); whether the server sends heartbeats is unverified |
| U-1 "Set up again" | UX-03 | Confirmed by code inspection; not tapped |
| U-2 wake try-out text | UX-04 | Confirmed by code inspection |
| U-3 developer text for users | UX-05 | Still unverified (not re-read this round) |
| U-4 unvalidated UI props | COR-09 | Confirmed by code inspection that casts exist; whether the parser already rejects wrong types is unverified |
| U-5 «لبيب», iOS branding | BE-03, UX-07 | Android header: reproduced, source is backend data. iOS: still unverified |
| U-6 large-font break | UX-02 | **Reproduced**, worse at 200 % |
| K-1 wake loop crash | REL-03 | Confirmed by code inspection and pinned by a unit test; crash not provoked on device |
| K-2 stop on main thread | REL-06 | Confirmed by code inspection |
| K-3 two busy flags | REL-07 | Confirmed by code inspection |
| K-4 consent on dev paths | SEC-01 | Confirmed by code inspection; `VoiceSetup` paths are correctly guarded |
| R-1 no production sign-in | MISS-01 | Confirmed (status document) |
| R-2 no crash reporting | MISS-03 | Still unverified (not re-read) |
| "History unreachable" | COR-12 | **Corrected**: the list is the history, but rename and delete of one conversation are unreachable. Confirmed on device and in code |
| P2 list (logs, dry-run, cache, asset path, …) | SEC-04, SEC-06, others | Logs and dry-run confirmed by code; `asset_id` path, polling after dispose, session after logout, `_opened` set, double-tap, camera twice: **still unverified** |
| Uncommitted tap-to-talk fix | — | **Fixed and verified**: committed `9289ec6`, device-checked with a synthetic voice (D11) |

## 10. Defect register

Severity: P0 blocks Beta, P1 required before Beta, P2 quality, P3 later. "Refactor" says whether the fix needs one.

### 10.1 Correctness and functional

| ID | Sev | Feature | Where | Root cause | User impact | Evidence | Fix | Regression test | Depends on | Refactor |
|---|---|---|---|---|---|---|---|---|---|---|
| COR-01 | P1 | Attach a file | attach sheet → file picker → `nexa_chat_view.dart` media reference | not established (picked file never became a reference) | the file is ignored without a word | D5 | trace the picker result; show the chip or an error | widget test with a fake picker result | — | no |
| COR-02 | P1 | Send with attachment | `nexa_composer.dart:62-68`, `nexa_chat_view.dart:219-246` | composer clears before the upload result; handler returns after a snackbar | typed text is lost when the upload fails | Code | keep the draft until the send is accepted | widget test: failing upload keeps the text | COR-01 | no |
| COR-03 | P1 | Tool result | `labeeb_tool_calls.dart:556-587` | a failed result post marks the call failed and keeps it in the answered set | the assistant waits until the server deadline; the user cannot retry (M-06.3 asks for retry on network errors) | Code | retry with back-off on network errors only; allow manual retry | unit: first post fails, second succeeds, exactly one result | — | part of ARCH-02 |
| COR-04 | P2 | Tool approval | `labeeb_tool_calls.dart:486-512` | `_calls[id]!` after an awaited request | crash if the session was reset meanwhile | Code | null-check and session check after each `await` | unit: clear during approve | — | part of ARCH-02 |
| COR-05 | P1 | Resume a conversation | `chat_bloc.dart:198-216` | `resumePending` cleared before the load; error only recorded | an old conversation opens empty after one network error, with no message and no retry | Code | restore the flag on failure, show retry | bloc test: load fails then succeeds | — | no |
| COR-06 | P2 | Conversation list | `nexa_history.dart:399-430` | `refresh()` during an in-flight `loadMore` resets the list but the old page still lands | wrong or missing entries after a quick refresh | Code | serialise, or tag requests with a generation | unit: refresh during loadMore | — | no |
| COR-07 | P2 | Conversation list | list page / router return path | list is not refreshed when returning from a chat | a new conversation is missing until pull-to-refresh | D3 | refresh on return or upsert locally | widget test | — | no |
| COR-08 | P2 | Conversation list | count shown per entry | not established (server value or client mapping) | "1 message" for a conversation with a question and an answer | device | compare with `GET /conversations`; fix the side that is wrong | unit on the mapper, or backend ticket | — | no |
| COR-09 | P2 | Dynamic UI | `nexa_ui_view.dart:298, 324, 356-357` | server props cast with `as` inside `build` | a wrong type from the server throws in `build` | Code (parser check unverified) | validate types in the parser, read safely | unit: wrong types → dropped document | — | no |
| COR-10 | P2 | Tool denial | tool result / backend prompt | a user decline is reported like a missing permission | assistant says "enable it in device settings" after "Not now" | device, `chat-tool-declined.png` | send a distinct "declined by user" code; backend wording | integration with the reference gateway | BE | no |
| COR-11 | P3 | Cancel | chat timeline | no marker for a cancelled reply | user message stays unanswered with no hint | D4 | small "stopped" row | widget test | — | no |
| COR-12 | P1 | Rename / delete a conversation | `nexa_conversation_list_page.dart` (only "open"); actions exist only in `nexa_history_view.dart` | the list replaced the history screen without its actions | no way to remove or rename one conversation; Settings promises it | D6, code | add the actions to the list rows (the controller methods exist) | widget test | — | no |

### 10.2 Reliability and call lifecycle

| ID | Sev | Feature | Where | Root cause | User impact | Evidence | Fix | Regression test | Depends on | Refactor |
|---|---|---|---|---|---|---|---|---|---|---|
| REL-01 | P0 | Voice admission | `nexa_config.dart:44` (30 s), `gateway_voice_provisioner.dart` create | client timeout shorter than the gateway's own wait (33–36 s) | truthful server answer never seen; "offline" shown; a late `201` would leave a session nobody ends | D1 + 8 probes | longer timeout for this one request, progress and cancel while waiting, end a late session | unit: 35 s answer is mapped; widget: waiting state | BE-02 | no |
| REL-02 | P1 | Reconnect | `nexa_voice_controller.dart:752-810` | after each `await` the result is applied with only a phase check, not "is this still the same call" | an old recovery can end or rejoin a new call | Code | per-call generation token checked after every `await` | unit: end + start during recovery | — | ARCH-01 |
| REL-03 | P1 | Wake listener | `WakeListenerService.kt:258-318`, `OnnxWakeFeatures.kt` | no error containment around inference | one model error ends the app process while listening | Code + unit test | catch in the loop, release the microphone, publish `error`, rebuild the engine once | Kotlin: throwing engine → state `error`, no crash | — | no |
| REL-04 | P1 | End call | `nexa_voice_controller.dart:978-1004` | `DELETE` is awaited before `disconnect()` | microphone stays published until the request returns or times out | Code | disconnect (or unpublish) first, then `DELETE` | unit: slow `end` → transport disconnected first | — | ARCH-01 |
| REL-05 | P1 | Voice errors | `nexa_voice_controller.dart:506-508`, capsule mapping | only `voice_unavailable` is treated as "try again"; `voice_model_preparing` and "GPU Realtime plan is FAILED" are unknown | no "try again in 15 s" for the cases that actually occur | probes, code | treat any retryable 503 with `retry_after_seconds` the same way | unit with both bodies | BE-02 | no |
| REL-06 | P2 | Wake listener stop | `WakeListenerService.kt:161-172` | joins the worker on the main thread (1.5 s), then closes the models even if the worker is still alive | possible freeze or native crash on stop | Code | stop off the main thread; close after the worker exits | Kotlin: stop during model load | REL-03 | no |
| REL-07 | P2 | Microphone ownership | `NexaAssistantPlugin.kt:75`, `VoiceSetup.kt:62` | two independent busy flags | a plugin recording and a setup recording can overlap | Code | one owner object | Kotlin: second request gets `busy` | — | ARCH-04 |
| REL-08 | P2 | Service start | `WakeListenerService.kt:105,138-141`, `CallForegroundService.kt:81-93` | `startForegroundService` followed by `stopSelf()` without `startForeground` on refusal | Android can kill the app for not starting the foreground in time | Code inspection only, unverified | check permission before starting the service | instrumented test | — | no |
| REL-09 | P2 | Chat stream | `gateway_chat_transport.dart:118-150` | no idle watchdog on the event stream | typing dots for ever on a stalled connection | Code (server heartbeats unverified) | idle timer → reconnect with `after` | unit with a silent stream | — | no |
| REL-10 | P3 | Notifications | `Activation.kt` and `CallForegroundService.kt` both use id `0x4E41` | same id for tap-to-talk and the call notification | one can replace the other | Code | distinct ids | — | — | no |
| REL-11 | P2 | Voice animation | `livekit_voice_transport.dart:275,336-390`; `nexa_diagnostics.dart:28` | audio levels are emitted inside the diagnostics-only handler | hosts without diagnostics get no levels | Code | emit levels always | unit on the transport | — | no |

### 10.3 Performance and battery

| ID | Sev | Finding | Where | Evidence | Fix | Verification |
|---|---|---|---|---|---|---|
| PERF-01 | P0 | Wake listener 28 % of a core, constant | `engine/EmbeddingWakeDetector.kt:64-82` | D9, D10, section 7 | energy gate with warm mel context and back-fill | idle CPU < 5 % on the phone; `wake_eval.py` and the simulation unchanged; owner recall test |
| PERF-02 | P1 | Universal APK 254 MB | `apps/nexa_example/android/app/build.gradle.kts` (no ABI split) | section 7 | ship per-ABI builds or an app bundle; consider downloading the 28 MB speaker model on demand | size recorded per ABI |
| PERF-03 | P2 | 314–338 MB idle memory | ONNX sessions held while listening | meminfo | load the speaker model only when "only my voice" is on (already lazy) and release after use | meminfo before/after |
| PERF-04 | P2 | No frame, leak or battery measurements; `tool/perf.sh` missing | — | — | write the script; run with a working backend | numbers in `docs/qa/perf-baseline.md` |

### 10.4 Security and privacy

SEC-01 **P1** (compile the two developer recording methods out of release and add the native consent check),
SEC-02 P2 (set `allowBackup="false"` or backup rules), SEC-03 P2 (move kept clips to internal storage),
SEC-04 P2 (debug-only logs and marker), SEC-06 P2 (atomic write; decide on encryption), SEC-05 P3, SEC-07 note, SEC-08 note.
Regression tests: Kotlin test that each recording method answers `consent_required`; manifest test for the backup flag.

### 10.5 Architecture and maintainability (see section 11)

ARCH-01 voice controller, ARCH-02 tool controller, ARCH-03 two tool stacks, ARCH-04 Android plugin,
ARCH-05 legacy enrolment and wake code, ARCH-06 two string systems, ARCH-07 test gaps.

### 10.6 UI/UX and accessibility

| ID | Sev | Finding | Evidence | Fix |
|---|---|---|---|---|
| UX-01 | P1 | Server failure shown with a "no Wi-Fi" icon; timeout shown as "You are offline" | `voice-call-503.png`, D1 | separate "server busy / preparing" state with the retry time |
| UX-02 | P1 | 200 % text: selectors on the assistant page break and clip; "System" breaks at 130 % in English; header truncates the assistant name | D8, round 1 screenshot | wrap or stack the segmented controls at large scale; M-14 AC2 test for these pages |
| UX-03 | P2 | "Set up again" does not re-record | Code | explicit re-enrol step |
| UX-04 | P2 | Wake try-out: every failure says "allow the microphone"; raw scores shown | Code | map reasons; hide scores outside dev builds |
| UX-05 | P2 | Developer text and raw states in the checks card | unverified | re-read, then gate |
| UX-07 | P2 | iOS still branded LABEEB | unverified | — |
| UX-08 | P3 | Notification icon on the Nubia | earlier finding | — |

### 10.7 Missing or incomplete against the requirements

| ID | Sev | Item |
|---|---|---|
| MISS-01 | P0 | Production sign-in / token source (M-15; status document row 2) |
| MISS-02 | P0 | Release signing key; no release build has run on a device |
| MISS-03 | P1 | Crash reporting vendor (hook exists) — unverified this round |
| MISS-04 | P1 | Bluetooth permission request and audio-route handling (M-12, task E-03 not started) |
| MISS-05 | P1 | Final utterance on mute (M-07.2/.4, tasks E-01/E-02) |
| MISS-06 | P1 | Wake word and speaker verification measured on real voices (M-10.2, M-11.5) |
| MISS-07 | P2 | TalkBack pass, performance baseline script, CI workflow enabled |
| MISS-08 | P3 | iOS acceptance (out of Beta scope by M-16.3) |

### 10.8 Backend and infrastructure

| ID | Sev | Item | Evidence |
|---|---|---|---|
| BE-01 | P0 | Voice admission fails: `voice_model_preparing` (STT model) for the whole window; earlier today "GPU Realtime plan is FAILED" | probes |
| BE-02 | P1 | Admission holds the request 33–36 s before answering; both error codes are not in the contract documents in this repository | probes; `grep` of `docs/contracts` |
| BE-03 | P2 | Company profile still says «لبيب» (`GET /v1/sdk/assistant`) | request |
| BE-04 | P1 | G-02 (commit turn on mute) and G-03 (barge-in tuning): requests written, not sent | `docs/handoff/` |
| BE-05 | P2 | One chat run with 60–85 s replies | round 1 |
| BE-06 | P2 | Decline wording (with COR-10) | device |

## 11. Architecture assessment and which refactors are justified

What is sound: package boundaries; contract types and state machine in `nexa_core` with no Flutter UI;
bloc for chat; a coordinator for conversation identity; transports behind interfaces with mocks and a
reference gateway; typed exceptions with stable codes; injectable clocks in the newer code.

What is weak:
- Wiring through public mutable fields and one `Nexa._client` singleton (reported in round 1, not re-read).
- Broad `catch` blocks (74) and fire-and-forget futures (116 `unawaited`) make failures quiet.
- The Android plugin uses raw threads and shared flags instead of one recording owner.

The seven large files:

| File | Lines | Shape | Refactor needed? | Why |
|---|---|---|---|---|
| `nexa_voice_controller.dart` | 1034 | one class | **Yes** (ARCH-01) | Call state is spread over fields of a long-lived object, so "is this still my call" cannot be asked. Move per-call state into a call object created per `connect`. This is the fix for REL-02 and REL-04, not a cosmetic split |
| `labeeb_tool_calls.dart` | 1119 | one class | **Yes** (ARCH-02) | Approval, answering, restore and polling share maps and flags; COR-03 and COR-04 come from that. Split answering (with retry) and restore/follow into units that can be tested alone |
| `device_assistant_page.dart` | 1000 | one 700-line state + a dead page | **Partly** | Delete the legacy `VoiceEnrollmentPage` (170 lines, developer-only entry); extract the checks card so it can be tested (0 % coverage today). No rewrite |
| `nexa_ui_view.dart` | 1059 | one 650-line state | **Small** | Only the prop validation (COR-09) and the static `_opened` set. Otherwise leave |
| `nexa_surface_view.dart` | 1469 | 18 small stateless widgets | **No** | Long but flat and cohesive: one widget per component. A file split is optional tidying |
| `nexa_voice_capsule.dart` | 1087 | several widgets | **No** | Pure UI with tests. Leave |
| `nexa_media_widgets.dart` | 1025 | cards incl. the older tool card | **Only with ARCH-03** | Contains `NexaToolRunCard` of the older tool path |

Duplicates:
- **Two tool stacks (ARCH-03).** The older "tool-actions" path (`ChatBloc`, `NexaToolRunCard`/`NexaToolCard`, `/tool-actions`) and the newer "tool-calls" path (`labeeb_tool_calls.dart`, `LabeebToolCallCard`). First confirm with the backend that the older events are no longer sent; then delete the older path. Problem solved: two places to fix every tool bug, and a 0 %-covered card.
- **Two UI renderers.** `nexa_ui_view` renders `nexa.ui/1` documents (interactive); `nexa_surface_view` renders tool-result surfaces (display). Their component sets differ; this is overlap in helpers, not a duplicate. No merge recommended now.
- **Three enrolment UIs and two wake engines (ARCH-05).** Quick wizard (current), guided 15-minute setup (developer), legacy five-sample page (developer); neural detector (current) and the older template detector (fallback, failed on the owner's voice on 2026-10-30). Delete the legacy page and its native `enrollmentRecord` path (also closes half of SEC-01); keep the guided setup as the calibration tool; remove the template engine once the owner's profile no longer depends on it.
- **Android plugin (ARCH-04).** One 991-line class owns channels, three recorders, benchmarks and services. Extract one recording owner (closes REL-07) and move developer methods to a debug-only source set (closes SEC-01).
- **Strings (ARCH-06).** About 405 inline `_t(en, ar)` strings in the app next to ARB files in the SDK. Optional; do it when the app pages are next touched.

Not recommended: any framework migration, a rewrite of the renderer, or renaming the 43 `Labeeb*` types before Beta.

## 12. Remediation plan (incremental; no timelines)

**Phase 0 — owner / backend.** BE-01, BE-02 report to the AWS team (evidence file ready); decide MISS-01 and MISS-02; send the G-02/G-03 requests.

**Phase 1 — essential before Beta, small and independent.**
1. REL-01 + REL-05 + UX-01: admission timeout, retryable 503s, truthful waiting and error states.
2. PERF-01: gated wake detector; measure on the phone.
3. REL-03, REL-06, REL-08, REL-10: wake service containment and clean stop.
4. PERF-02: per-ABI packaging.
5. SEC-01, SEC-02, SEC-04: consent in native code, backup flag, debug-only logs.
6. COR-01, COR-02, COR-12, COR-05, COR-07: attachment, draft, rename/delete, resume retry, list refresh.
7. UX-02: large-text layout of the assistant pages.

**Phase 2 — essential, needs the two refactors.**
8. ARCH-01 with REL-02, REL-04, REL-11, and transport tests to at least the call lifecycle (ARCH-07).
9. ARCH-02 with COR-03, COR-04; then ARCH-03 after the backend confirms.
10. ARCH-04 with REL-07.

**Phase 3 — verification that was blocked or needs the owner.** Full call script (connect time, turn, barge-in, mute, End with `dumpsys audio`, rapid start/end, 2 minutes in background, network drop, voice tool, 20-cycle memory), the T-M07 mute rows, wake and speaker tests with the owner's voice and guests, Xiaomi, an Android 14+ device, TalkBack, release build.

**Optional cleanup (after Beta).** ARCH-05, ARCH-06, file splits, renames, P3 items.

Each item marked "Code" starts with a failing test; if the test cannot be made to fail, close the item.

## 13. Remaining test gaps (explicit)

- Everything inside a voice call: BLOCKED by the backend.
- Owner voice: wake recall, false accepts, enrolment quality, verification thresholds: NOT TESTED.
- Devices: Xiaomi / HyperOS, any Android 14+ phone, iOS: NOT TESTED.
- Battery, frame timing, leaks, network usage: NOT MEASURED.
- Camera, gallery, location sharing, tool approval with real data, delete-all: NOT TESTED (would use or destroy the owner's data).
- TalkBack, permission revocation at run time, reboot: NOT TESTED.
- Round-1 items still unverified: developer text in the checks card, crash sink, `asset_id` path, polling after dispose, session after logout, double-tap pushes, camera opening twice, iOS branding.

## 14. Commits of this round (local only)

| Commit | Content |
|---|---|
| `9289ec6` | Tap-to-talk on an unrecognised voice; voice card shows an older or locked-out profile as needing attention (reviewed, gate green, later device-checked with a synthetic voice) |
| `8133f01` | Kotlin test pinning REL-03; `tools/wake_training/vad_gate_sim.py` |
| this commit | this report and `docs/qa/evidence/2026-11-18/round2/` |

No application behaviour was changed apart from `9289ec6`. Nothing was changed on the backend. Nothing was pushed.
