# T-M07-01 — mute right after speaking (Nubia NX679J, production gateway, 2026-11-04)

Method: a sentence is injected from the Mac speaker next to the phone; Mute is tapped by adb; events are the app's own voice events (temporary trace, removed). Note: macOS `say` returns before its audio finishes playing, so it muted about 0.7 s mid-sentence in the first runs; the valid runs use `say -o` + `afplay` (blocks until the audio ends).

## Before the fix (no grace)
Sentence ends, Mute tapped 78 ms later. Final transcript arrived while muted; **no reply for 19+ s**. After unmuting, the reply arrived within ~12 s. A muted track sends no frames, so the server never closed the turn.

## Control (never muted)
`user_speech_ended` 27.784 -> `transcript final` +0.13 s -> `assistant thinking` +0.15 s -> assistant audio +1.14 s -> turn ended +3.2 s.

## After the fix (`muteGrace` 1200 ms, microphone open until the reply starts)
Mute tapped 17 ms after `user_speech_ended` (phase `transcribing`):
```
35.722 user_speech_ended
35.739 mute requested -> grace START (from transcribing)   [UI shows muted at once]
35.972 transcript final      (+0.25 s)
35.994 assistant thinking    -> mute applied (cause: reply_started)
37.416 assistant audio started (muted UI, microphone closed, reply plays)
```
Also verified: mute mid-sentence (0.7 s before the end): speech ended 0.7 s after the tap, reply started 0.18 s later, mute applied then.
Rapid toggles (E-02): 10 toggles -> at most 3 transport calls, last intent wins (unit test).

Limit: if the server needs more than 1.2 s to commit a turn, the mic closes first and the reply waits for the unmute (the earlier 1.2 s run). The server-side fix remains G-02 (commit the turn when the track is muted); filed in docs/mobile/MOBILE_IMPLEMENTATION_STATUS.md.
