# Is the user's speech in the first ~2 s of a call lost? (2026-11-21)

## Answer: yes. The code shows it, and the device record confirms the window
Nubia NX679J, debug build, record `qa_20261119-154146_voice_9edf.jsonl` (in the 2026-11-19 evidence folder):
`voice.phase connecting→listening` at 15:41:54.826, then `voice.local_track_published` (microphone) at
15:41:56.901. The screen said "listening" for **2.075 s** with no microphone track. A spoken word in that window
was not tried, so "the word is missing from the transcript" is still NOT TESTED. The record proves only that no
track existed. It is a debug build; profile or release may be faster, but the order does not change.
The order at the start of a call today:

1. `room.connect` returns and the audio session starts (`livekit_voice_transport.dart:117`). The handshake
   waits for `agent_ready` (`:127`).
2. `agent_ready` → `VoiceConnected` (`nexa_voice_controller.dart:826`). The state machine moves to
   **`listening`** right away and issues `StartCapture` (`voice_session_machine.dart:121`).
3. Only then does `StartCapture` publish the microphone (`nexa_voice_controller.dart:662`,
   `setMicrophoneEnabled(true)`). On the Nubia the first publish took **2073 ms** (panel, 2026-11-19).
4. After the track is published, the agent still has to subscribe to it (normally a few hundred ms).

So the screen says "listening" for about **2–2.5 s** while no microphone track exists yet. Anything the user
says in that window never leaves the phone. There is no buffer, so it is lost, not delayed. The debug panel shows
this as `phase listening` with `mic sending false`.

Device check (to do on the Nubia): record the times of `voice.phase → listening` and
`voice.mic_applied {enabled: true}`. Then speak a short word as soon as "listening" appears. Expected today: the
word is missing from the transcript.

## Status: IMPLEMENTED (unit tests PASS); on-device check NOT TESTED
Implemented 2026-11-21 behind `NexaVoiceOptions.earlyMicrophone` (default **on**; `false` restores the old order):
* The controller publishes the microphone right after `room.connect` (`_startEarlyMic`), unless muted or held by a
  phone call. A mute while still connecting reaches that microphone at once.
* When `agent_ready` arrives first, the call stays "connecting" until the microphone is live (at most 4 s).
  Agent events received meanwhile are replayed after it. A drop or teardown cancels the wait.
* If the early publish fails, `StartCapture` retries once and reports the error, as before.
* Diagnostics: `voice.early_mic`, `voice.early_mic_failed`, `voice.listening_after_mic {wait_ms, mic, held_events}`.
  The QA analysis has a new `listening_before_mic_ms` metric: above 0 means the gap still exists; 0 or below means
  the mic was live first.
* The early publish starts after the call-audio setup (route, focus, mode) finishes, and sends no
  `listening: true` signal: the agent has not announced yet, and listening is the server's default.
* Tests: `packages/nexa_sdk/test/features/voice_early_mic_test.dart` (10 cases: order, wait and replay, muted at
  start, phone call at start, mute while connecting, publish failure, flag off, drop during the wait, full rejoin
  with no signal before the agent's announcement, second call on the same controller).

Device check (Nubia, 15:40 UTC, `docs/qa/evidence/2026-11-21/early-mic/nubia-NX679J/`):
* **Order: PASS.** The track was published 1.38 s before "listening" (`listening_before_mic_ms` = -1381). The
  audio mode was `in_communication` on speaker before the publish. No `listening:true` signal at call start.
* **Audio delivery: BLOCKED (network).** The publisher peer connection never connected (ICE stuck in Checking), so
  no microphone packets left the phone. This morning's call with the old code had the same fault.
* **Spoken first word: NOT TESTED.** Needs a person and a working publish path.

Known limit: "listening" waits for the track to be *published*, not for the first packet to *reach the server*.
On a healthy network (2026-11-19) the publisher connected inside the publish time, but that is not guaranteed.
If the next device check shows a gap between "listening" and the first outbound packets, gate on the publisher
connection as well.

## Proposed fix (client only; no backend or contract change)
1. **Start the microphone earlier.** Publish the mic as soon as the room is connected, in parallel with waiting
   for `agent_ready`, unless the user is muted or a phone call holds the audio. The ~2 s then overlaps the
   handshake wait instead of following it. Audio sent before the agent subscribes is simply not heard. No data
   packets are sent, so contract §4 is respected. iOS is fine too: the audio module exists once the room is
   connected, which is when this runs.
2. **Show "listening" only when it is true.** Switch to `listening` only when `agent_ready` has arrived **and**
   the microphone track is published. Until then keep "connecting". The UI then never invites speech the system
   cannot hear.
3. Measure both steps with the existing diagnostics: `voice.mic_applied ms`, `voice.handshake_done`, and the
   phase times.

Risk: low. It changes only the order and the label. Put it behind a flag (`NexaVoiceOptions.earlyMicrophone`;
shipped default on, with the order verified on the device and audio delivery still to verify), with unit tests for: muted at start (no publish), a phone call at start, a
publish failure (the call still connects and shows an error), and a rejoin.

## Not recommended now
LiveKit's "pre-connect audio buffer" records before connect and sends the audio to the agent over a data stream.
That needs agent support, and contract §4 forbids client data packets. It would recover even speech said before
the room connects, but it is a contract change.
