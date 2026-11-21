# Voice call audio — manual test sheet (T1–T6), 2026-11-19

For the human tester. One copy of the tables per device. Nothing here has been run yet: every row starts as
**NOT TESTED**. A row passes only with the evidence it asks for.

## Before you start
* **Build:** a **debug** build (`flutter run --debug` or `flutter build apk --debug`) of the commit under test,
  with the dev token from `--dart-define-from-file=$HOME/.nexa/nexa_dev.json`. Never type a token into the app.
  The **audio debug panel** appears only in debug builds, at the top-left during a call. Tap it to collapse it.
* **Use a QA account and test conversations only.** Do not use the owner's real conversations.
* **Record per run:** device, OS version, build commit, route, start time, and the panel values the step asks
  for. Take a screenshot of the panel at the end of every run.
* **Evidence folder:** `docs/qa/evidence/<date>/voice-audio/<device>/`. Put screenshots there, plus the QA
  recorder export when the step asks for it (debug builds record `voice.*` diagnostics; no audio or text).
* **What the panel shows:**

| Panel row | Meaning |
|---|---|
| `phase` | Client state: listening / thinking / aiSpeaking / userSpeaking / muted … |
| `muted (user)` / `mic sending` | The user's mute choice / whether the microphone track is actually sending. |
| `phone call hold` | A phone call holds the audio. The mic is off until the phone call ends. |
| `route` / `choice` | Output actually in use / the user's speaker-or-earpiece choice. |
| `mode (actual)` | Android: must be `in_communication` during the call. iOS: `videoChat` (speaker) or `voiceChat` (earpiece). |
| `mode (requested)` | iOS only: what the app asked for. |
| `AEC / NS / AGC` | What the audio engine actually applied (`platform`, `software`, `disabled`). |
| `interruptions (server)` | `interrupted` events from the server in this call. |
| `speech starts (server)` | `user_speech_started` events from the server: times the server thought the user spoke. |
| `last unmute / mute` | How long the last unmute / mute took in the audio engine. |

**T1 is scored from server events (the two counters), not from what the tester hears.**

**Stop rule:** if the panel shows `mode (actual): n/a` or `route: unknown` during a call, stop and report it.
The native part did not answer, and a broken plugin looks the same as "unknown". Do not score anything on that
device until it is fixed.

## Devices
The device list was not given (the answer was a placeholder). Fill these in:

| Slot | Model | OS | Notes |
|---|---|---|---|
| Low-end Android | | | |
| Mid/high Android | nubia NX679J (adb bf5c6761) | Android 13 | Smoke check 2026-11-19: panel values real (see `docs/qa/evidence/2026-11-19/voice-audio/nubia-NX679J/`). T1–T6 not run yet. |
| iPhone | | | |

Routes for each device: **speaker**, **earpiece**, **wired headset**, **Bluetooth headset**.

---

## T1 — Echo (agent speaks 30 s+, user silent)
For each route, 10 runs:
1. Start a call. Set the route: use the output button for speaker/earpiece, or connect the headset before the call.
2. Set the media/call volume to **maximum**.
3. Check `mode (actual)` (Android `in_communication`) and `AEC` (not `disabled`). Note both values.
4. Ask for a long answer, for example "Tell me a detailed story of at least one minute". Then **stay silent**, in a quiet room with no one else talking.
5. When the answer ends, read `interruptions (server)` and `speech starts (server)`. Take a screenshot.
6. End the call. Start a new call for the next run, so the counters reset.

**Pass:** `interruptions (server)` = 0 in **all 10** runs for that route. Record `speech starts`: more than 0 while
silent means the server heard echo or noise even if it did not interrupt. That is a warning; note it.
**iOS:** compare speaker (`videoChat`) against earpiece (`voiceChat`) using the same counters.

| Device | Route | mode / AEC | Runs | Interruptions per run (10 values) | Speech starts per run | Pass/Fail |
|---|---|---|---|---|---|---|
| | speaker | | /10 | | | NOT TESTED |
| | earpiece | | /10 | | | NOT TESTED |
| | wired | | /10 | | | NOT TESTED |
| | bluetooth | | /10 | | | NOT TESTED |

If T1 fails on the speaker, stop and report the numbers. The owner then decides the default route from them.

## T2 — Mute
For each route:
1. During a call, while the agent is listening, tap **Mute**. Check that `muted (user)` = true and `mic sending` = false.
2. Talk loudly and make noise (clap, knock on the table) for 15 s.
3. Check that `speech starts (server)` did not increase and the agent did not answer or react.
4. Tap **Unmute** and speak at once. Read `last unmute`. The agent should hear you normally.
5. (The app has no "start the call muted" setting, so that case is covered by unit tests only.)

**Pass:** no server speech starts and no reaction while muted; `last unmute` ≤ 1000 ms; normal behaviour after unmute.

| Device | Route | Speech starts while muted | Agent reacted? | Last unmute (ms) | Pass/Fail |
|---|---|---|---|---|---|
| | speaker | | | | NOT TESTED |
| | earpiece | | | | NOT TESTED |
| | wired | | | | NOT TESTED |
| | bluetooth | | | | NOT TESTED |

**Mute mid-sentence (listening control, backend release d42c1ba):** start a sentence, tap **Mute** in the
middle of it, wait 3 s, tap **Unmute**, and say a new, different sentence. Pass: the transcript shows the new
sentence on its own. The cut-off half is dropped and never joined to it, and the agent answers only the new
sentence. Check the panel's `signals` rows (listening control = `nexa.voice.listening`), and that the QA export has
`voice.signal` with result `sent` for each mute and unmute.

## T3 — Route switching mid-call
1. Start on the speaker. While the agent is speaking, connect the **Bluetooth** headset. Check that `route` = bluetooth within about 2 s and the audio moves to the headset.
2. Disconnect it. Check that the route goes back to the **previous choice** (speaker).
3. Switch to the earpiece with the button, then plug in a **wired** headset and unplug it. Check that the route goes back to earpiece.
4. Toggle speaker ⇄ earpiece 5 times while the agent speaks.
5. After each change, stay silent through one full answer. `interruptions (server)` must not increase.
6. Android 12+ without Bluetooth permission: connect the headset during a call. The app asks for "Nearby devices" once. Test both **Allow** and **Deny**. With Deny the call must continue on the phone without errors.

**Pass:** audio continues, the mic stays in the state the UI shows, no new interruptions after any switch, `mode (actual)` stays `in_communication` (Android).

| Device | Step | Route shown | Audio OK? | Interruptions after | Pass/Fail |
|---|---|---|---|---|---|
| | BT connect / disconnect | | | | NOT TESTED |
| | wired plug / unplug | | | | NOT TESTED |
| | speaker⇄earpiece ×5 | | | | NOT TESTED |
| | BT permission allow / deny | | | | NOT TESTED |

## T4 — Lifecycle
1. **Incoming phone call** (call the test phone from another phone) during a call:
   * The label must say "Paused for a phone call" and `mic sending` = false.
   * Answer, talk 10 s, hang up. Check that `phone call hold` = false, `mode (actual)` is back to `in_communication`, and the mic is back unless the user had muted before.
   * Repeat once while already muted. It must stay muted after the phone call.
   * Android: have someone call the test phone on **WhatsApp** (or another VoIP app) during the call. Check that
     the label reads "Paused: another app is using the audio", `hold` = otherApp, `focus` = lost/lost_transient,
     and `mic sending` = false. After it ends, the mic comes back by itself, or a **Resume** button appears;
     tapping it must bring the mic back.
2. **Background / foreground:** press Home for 10 s, then return. The call should continue, or it ends cleanly after the 25 s background grace if nothing holds it. Check that the UI matches the mic state.
3. **Network drop 10 s:** turn on airplane mode for 10 s, then off. The call recovers (reconnecting → listening) or ends with a clear message. Check that `muted (user)` and `mic sending` match the UI afterwards.

| Device | Case | Result | UI matches mic? | Pass/Fail |
|---|---|---|---|---|
| | incoming phone call | | | NOT TESTED |
| | WhatsApp (or other VoIP) call during the call: label "Paused: another app is using the audio", mic off; after it ends the mic is back (or Resume shown and works) | | | NOT TESTED |
| | phone call while muted | | | NOT TESTED |
| | background 10 s | | | NOT TESTED |
| | network drop 10 s | | | NOT TESTED |

## T5 — Performance (low-end Android)
Use a **profile** build (`flutter build apk --profile`, dev token from the secrets file). Debug builds are slow
and do not measure performance. The panel is not needed; this test uses adb only.

1. Start a **10-minute** call on the speaker with normal conversation.
2. In parallel, record from a computer: `adb shell top -b -d 5 -n 120 | grep nexa > top.txt` and
   `adb shell dumpsys meminfo com.nexa.nexa_example` at minutes 0, 5 and 10. Optionally also
   `adb shell dumpsys thermalservice` at the end.
3. Note audio glitches (cuts, robot voice) with the minute, and any overheating warning.

**Pass:** no glitches, no thermal warning, CPU and memory flat (no steady growth).

| Device | Glitches | Thermal | CPU avg / max | PSS at 0 / 5 / 10 min | Pass/Fail |
|---|---|---|---|---|---|
| | | | | | NOT TESTED |

## T6 — Agent state UI
During T1–T4 watch the label: **listening** when waiting for you, **thinking** after you finish, **speaking**
while the agent talks. "Interrupted" appears only when the server confirmed the interruption. Noise or echo
during an answer must leave "speaking" on screen.

| Device | Mismatch seen (when, what label, what actually happened) | Pass/Fail |
|---|---|---|
| | | NOT TESTED |

---

## Summary to report
For each device and route: Pass / Fail / NOT TESTED, each with the reason. Say plainly if any test failed. Do
not mark a row passed without the screenshot or recorder export.
