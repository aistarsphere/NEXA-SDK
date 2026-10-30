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


---

## Update 2026-10-30 22:20 (+03), Xiaomi 2ba15772, Android 16 / HyperOS 3.0

Calls are admitted again. One short call was used per check, to protect
the QA quota.

### Overall status: PARTIAL

The live checks still waiting for the owner are listed at the end.

### Mute: PASS_REAL_DEVICE

Panel call `vs_xQCtJYaJ_yE93TD97j8TUQ`, cold start from the home screen
via the assist key. Evidence is from `adb shell dumpsys audio`, for app
uid 10336:

1. **Live, unmuted:** one capture, `VOICE_COMMUNICATION` 48 kHz,
   `silenced:false`, effects `client='aec' 'ns'`, `dev='aec' 'ns'`.
2. **After Mute:** `rec stop … VOICE_COMMUNICATION` at 22:18:39. No
   capture remains for the app. The status-bar microphone dot is gone.
   The panel shows «الصوت مكتوم» and the crossed orb (screenshot
   `m2_muted.png`).
3. **Muted for 10 s:** still no capture. Background speech, which had
   been producing captions before muting, produced no new caption.
4. **After Unmute:** a new `VOICE_COMMUNICATION` capture at 22:19:07.
5. **After Close:** `user_closed`, `DELETE` 200, both peer connections
   CLOSED, no capture, no session window left.

Not yet seen on a phone:

* mute across a reconnect or Expand (code path verified);
* the server-side absence of a user turn while muted. The client sends no
  audio at all, because capture is stopped.

### Tools / dynamic UI: Flutter-owned root cause, FIXED

**Cause.** Calls started without tools. The log line read
`voice … tools=false (not_requested)`. Two app bugs combined:

1. The provisioner asked for `tools` only when device tools were also
   declared (`conversationId != null && clientTools.isNotEmpty`). The
   contract needs only a conversation.
2. A call started from the panel on a cold start runs before the chat has
   created its conversation, so no `conversation_id` was sent. The
   session manager also forgot a newly created conversation when opening
   the chat session failed (e.g. 429).

The model therefore had no tools and could only speak ("you choose").

**Fix.**

* Tools are requested whenever there is a conversation.
* A call first joins or creates the conversation.
* The conversation is kept even if opening the chat session fails.

**Device evidence after the fix.** Call `vs_MEcpxnlKfzOQ-aaAFslRKg`
(cold start, panel) reported `tools=true` and
`server_tools=54`. The device tools granted were:

* `device.location.get_current`
* `maps.open_directions`
* `device.camera.capture`
* `device.photo.pick`
* `device.file.pick`
* `browser.open_url`
* `app.theme.apply`
* `device.microphone.record_sample`

**Remaining.** One live "لبيب، غيّرلي شكل التطبيق" with the owner
(NOT_TESTED). The log will show `voice tool event:` lines.

### Cold-start panel call: FIXED, PASS_REAL_DEVICE

**Cause.** In the panel with no activity on screen, the microphone
permission plugin threw ("voice command failed") although the permission
was granted.

**Fix.** The host returns an already-granted permission without a
prompt.

**Evidence.** Cold-start calls at 22:18 and 22:23 connected.

### Noise / echo: device evidence

* One capture only during calls.
* Platform `aec` + `ns` effects are active on the device stream.
* The source is `VOICE_COMMUNICATION`.
* The wake listener is off the microphone during calls.

Background speech still produced captions and «جارٍ المقاطعة…», so the
worker's VAD treats it as user speech. Barge-in is decided by the worker
(the client sends no interrupt). Scenario runs with the owner:
NOT_TESTED.

### Setup screen

* Once Android reports LABEEB as the assistant, the setup card is replaced
  by a compact verified card with "Change".
* The setup button opens Assist & voice input. Android redirects apps'
  requests for the role chooser to Default apps (seen on Android 13 and
  16).
* The three Android signals are listed only in Checks.

### Owner voice check

Scoring now uses the better of (mean similarity) and (average of the two
closest enrolment samples), so normal variation in tone, speed and volume
is accepted. The threshold is leave-one-out calibrated with the same rule,
0.12 headroom, clamped to 0.40–0.65, and never lowered further.

**Re-enrolment needed** to store the per-sample embeddings (profile v2).
Version-1 profiles still load.

Unit test: "owner variation close to some samples passes, stranger does
not". Real owner and second-speaker tests: NOT_TESTED.

### Still needs the owner (live)

1. «لبيب، غيّرلي شكل التطبيق» once, in the panel, then once in full
   screen.
2. The six noise scenarios.
3. Re-record the voice; Test 5× (owner verification off, then on); a
   second person 3×.
4. «يا لبيب» with the app open, in the background, with the screen off,
   and locked. Each attempt logs `NexaWake decision=… phrase=d/t voice=s/t`.
