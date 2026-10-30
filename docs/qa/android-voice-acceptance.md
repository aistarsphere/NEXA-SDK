# LABEEB Android voice assistant — mobile acceptance

Status values:

| Value | Meaning |
|---|---|
| PASS_REAL_DEVICE | Seen on a phone |
| FAIL_REPRODUCED | Reproduced on a phone |
| BLOCKED_BACKEND | Needs the live voice service |
| NOT_IMPLEMENTED | Not built yet |
| NOT_TESTED | Built, not tried on a phone |

Unit, widget and mock tests are listed as evidence for the code only. They
are never counted as a device pass.

## Devices and builds

| Device | OS | Serial |
|---|---|---|
| Xiaomi 25010PN30G | Android 16, HyperOS 3.0 | 2ba15772 |
| Nubia NX679J (RedMagic) | Android 13 | bf5c6761 |

* **Build:** profile, `--dart-define-from-file=~/.nexa/nexa_dev.json`,
  `NEXA_DEV_TOOLS=true`.
* **Gateway:** `https://52.58.22.19/nexa/api`.
* **Date:** 2026-10-30.

## Backend state during this pass

These are not mobile defects. Tests that depend on the live service are
marked BLOCKED_BACKEND.

| Time (+03) | `POST /v1/sdk/voice/sessions` |
|---|---|
| 06:30–06:58 | 503 "No voice capacity is available right now", also from the Mac |
| 18:57–19:48 | 201 several times (calls connected); one receive timeout |
| 19:53 | Call refused with `quotaExceeded` |
| 18:57 call | Agent stayed on "thinking…" and never replied to either request |

## A. Mute (P0)

**Root cause (FIXED).** `VoiceSessionMachine` applied `VoiceMuteToggled`
only in some states: listening, user speaking, AI speaking, weak network
and muted. In transcribing, thinking, barge-in and model busy, the button
changed its flag but the microphone stayed published. The owner saw the
assistant keep hearing them.

**Fix.** A mute toggle now reaches the transport in every live state
(`nexa_core/lib/src/voice/voice_session_machine.dart`):

* mute → state `muted` + `SetTransportMuted(true)`, which calls
  `setMicrophoneEnabled(false)`;
* unmute → `SetTransportMuted(false)`.

**Capture.** LiveKit `AudioCaptureOptions.stopAudioCaptureOnMute`
defaults to true in livekit_client 2.13.1 and is not overridden. Muting
therefore stops capture: no frames are sent, and Android's microphone
indicator should go off.

**Reconnect.** `StartCapture` on (re)connect calls
`setMicrophoneEnabled(enabled: !muted)` and re-applies mute, so a
reconnect cannot silently unmute. Expand keeps the same controller and
state, so it cannot unmute either.

**Where speech events come from.** User-speech and interrupt events come
only from the agent (`user_speaking`, `interrupted`). With capture stopped
the server receives no audio, so a muted microphone cannot cause a
barge-in.

**Mic vs speaker mute.** The panel and voice screen have Microphone Mute
only. There is no speaker mute, so the two cannot be confused.

| Case | Expected | Actual | Evidence | Status |
|---|---|---|---|---|
| Mute in every live state | Microphone unpublished | Unit test passes: all 8 states → `muted` + `SetTransportMuted(true)` | `voice_session_machine_test.dart` "mute reaches the microphone in every live state" | Code verified |
| Mute on a live call, device | No frames sent, mic indicator off, no new turns | Not run: calls were refused (`quotaExceeded`) | xiaomi_qa.log 19:53 | BLOCKED_BACKEND |
| Unmute restores speech | Speech recognised again | — | — | BLOCKED_BACKEND |
| Mute across reconnect / expand | Stays muted | Code path verified (above) | — | NOT_TESTED |
| Wake listener while panel open | Listener does not take the mic | FIXED: `DeviceAssistant` treats "panel open" as mic in use | `device_assistant_test.dart` | Code verified; device NOT_TESTED |

**Live mute test** (run when the service admits calls):

1. Open the panel and say a phrase. It should appear as a caption.
2. Tap Mute. Check `adb shell dumpsys audio`: the `VOICE_COMMUNICATION`
   recording for uid `com.nexa.nexa_example` should stop. The status bar
   microphone indicator should go off.
3. Say three distinct phrases. No captions should appear, and no
   `voice-turns` POST should be logged for them.
4. Tap Unmute and speak. The caption should appear again.

## B. Dynamic UI and device tools (P0)

**Path.**

1. A voice data packet `tool_call_*` / `ui_presented` arrives.
2. `voice_events_v1` → `RealtimeToolEvent` → `NexaVoiceController.toolEvents`.
3. `NexaClient` → `LabeebToolCallController.ingestVoice`.
4. The card is rendered (`LabeebToolCallCard` in the voice companion, or
   the compact panel buttons).
5. The user approves → `POST …/approval` → `LabeebThemeApplyTool`
   applies the theme → `POST …/result`, once, keyed by the
   `tool_call_id` path.

**Flutter-owned failure (FIXED).** The compact panel had no approval UI
and ignored `ui_presented`. A tool needing approval waited invisibly
("thinking…").

Now:

* `awaiting_approval`: the panel shows the tool name with Allow / Not now
  (`controller.decide`).
* `awaiting_client` needing a screen: "Open to continue", which expands
  into the same call.
* `ui_presented`: "Show options", which expands; the voice companion
  renders the nexa.ui/1 choices.

**Evidence added.** Each call now logs:

* tools enabled or not;
* the reason;
* the device tools the server accepted;
* every tool event (type, tool name, status, id; no payloads).

These lines separate TOOL_NOT_EMITTED from TOOL_NOT_RECEIVED.

| Case | Expected | Actual | Evidence | Status |
|---|---|---|---|---|
| Theme tool → card → Allow → theme applied → one result (full view) | Theme changes, one `/result` | Passed | `integration_test/assistant_tools_device_test.dart` on 2ba15772, real `LabeebThemeController` | PASS_REAL_DEVICE (fixture events) |
| Same in the compact panel | Allow in the panel applies | Passed | same test, case 2 | PASS_REAL_DEVICE (fixture events) |
| Malformed payload | Controlled: no card, no crash, no result | Passed | same test, case 3 | PASS_REAL_DEVICE (fixture events) |
| `ui_presented` in the panel | "Show options" → full view | Passed (widget test) | `compact_voice_panel_test.dart` | Code verified; device NOT_TESTED |
| Live "لبيب، غيّرلي شكل التطبيق" | Options appear; selection changes the theme | Owner (18:57, before the fixes): the agent said something like "you choose" and nothing appeared. The log of that build has no tool-event lines, so emitted vs received cannot be told apart. | xiaomi_panel4.log, session started 18:57 | Panel part FIXED; live path BLOCKED_BACKEND until a call runs with the new tool-event log |

## C. Noise and false barge-in

**Ownership.** Barge-in is decided by the voice agent (server VAD). The
client sends no interrupt command: `LiveKitVoiceTransport.interrupt()`
is local-only and does nothing. `user_speaking` and `interrupted` come
from the agent. TV, other people and room noise interrupting the
assistant is therefore a worker-side (VAD / turn detection) behaviour.

**Client side (verified in code).**

* Capture options: echo cancellation, noise suppression, auto gain,
  high-pass filter and typing-noise detection
  (`livekit_audio_setup.dart`).
* Android source: `VOICE_COMMUNICATION`, seen in `dumpsys audio` during
  calls; it enables the platform echo canceller.
* One capture at a time: the wake listener releases the microphone during
  calls (seen on device in `dumpsys audio` rec stop / start sequences).
* No duplicate listeners found.

| Scenario | Status |
|---|---|
| Quiet room, fan/AC, TV, other person, assistant through the speaker, owner interrupting, owner over noise | BLOCKED_BACKEND. Each needs a live call. Record for each: local `user_speaking` / `interrupted` events from the log, and whether the assistant stopped. |

**Upstream evidence to collect** (for AWS later, not now):

* `voice_session_id`;
* time of each false interruption;
* the `interrupted` / `user_speaking` events from the log.

The owning fix is in the worker's VAD or turn detection. The optional
on-device owner-voice model is not used to gate call audio: it is
unvalidated for that use, and it would block legitimate speech.

## D. Native assistant regression list

| Behaviour | Status | Evidence |
|---|---|---|
| Default-assistant status refreshes on return from settings | PASS_REAL_DEVICE | Nubia: role switched to com.nexa.nexa_example and the app showed it (owner confirmed) |
| Chooser opens the right screen | Fixed. Nubia's "Assist & voice input" page made Voice input easy to pick by mistake; the button now opens the Digital-assistant chooser where available, else Default apps. | Nubia screenshots |
| Voice input stays usable for other apps | Fixed: LABEEB's recognition service forwards to the device recogniser | code |
| Assist key opens the compact panel over the home screen | PASS_REAL_DEVICE | Xiaomi + Nubia screenshots |
| Close (X) | PASS_REAL_DEVICE | Xiaomi log `panel conversation ended: user_closed` |
| 60 s idle timeout, also after a failed start | PASS_REAL_DEVICE | Nubia log `idle_timeout` |
| Microphone back to «يا لبيب» after close | PASS_REAL_DEVICE | `dumpsys audio` rec stop → update after close |
| Errors shown with Retry, no endless "connecting" | Code verified | `compact_voice_panel_test.dart` "no voice capacity" |
| Live call in the panel (caption shows speech) | PASS_REAL_DEVICE | Xiaomi 18:57, ICE connected, caption «أريدك تغير لي تصميم التطبيق» |
| Expand keeps the same session | Code verified (same `voiceSessionId`) | `device_assistant_test.dart` |
| Expand on a phone | NOT_TESTED | — |
| Top / left / right positions | NOT_TESTED on a phone | — |
| Wake phrase by voice, owner check | NOT_TESTED (needs the owner's enrolment) | — |
| Lock screen gate | Code verified | `device_assistant_test.dart` |

## Deferred live tests (run when calls are admitted)

1. Spoken exchange in the panel.
2. Mute / unmute (section A).
3. «لبيب، غيّرلي شكل التطبيق». Read the log for `voice … tools=` and
   `voice tool event:` lines, then classify:
   * TOOL_NOT_EMITTED: no tool-event lines;
   * TOOL_NOT_RENDERED: events but no buttons;
   * ACTION_NOT_EXECUTED: Allow tapped but the theme did not change;
   * RESULT_NOT_ACKNOWLEDGED: no `/result` POST.
4. Barge-in and noise (section C).
5. Expand → same `voice_session_id`, no second `POST /voice/sessions`.
6. Orb movement with real speech levels.
7. Five calls in a row; after each, check `dumpsys audio` for a single
   capture and confirm no LiveKit room remains.
