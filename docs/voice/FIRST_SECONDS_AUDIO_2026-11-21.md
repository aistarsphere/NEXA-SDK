# Is the user's speech in the first ~2 s of a call lost? (2026-11-21)

## Answer: yes. The code shows it; a device measurement is still NOT TESTED
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

Risk: low. It changes only the order and the label. Put it behind a flag (`NexaVoiceOptions.earlyMicrophone`,
default on after a device check), with unit tests for: muted at start (no publish), a phone call at start, a
publish failure (the call still connects and shows an error), and a rejoin.

## Not recommended now
LiveKit's "pre-connect audio buffer" records before connect and sends the audio to the agent over a data stream.
That needs agent support, and contract §4 forbids client data packets. It would recover even speech said before
the room connects, but it is a contract change.
