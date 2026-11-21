# Client → agent signals: listening control and client info (ACCEPTED, 2026-11-19 / 2026-11-21)

Status: **accepted by the backend as proposed and released (backend release d42c1ba, reported 2026-11-21).**
Names: `nexa.voice.listening` and `nexa.voice.client_info`. The agent announces them in `agent_ready`, in every
`session_state` and in the `resume` answer. `listening: false` stops input, discards the cut-off utterance and
resets the VAD. The client reads all three places (2026-11-21). End-to-end device test: see the QA evidence
folder for its result; until it is recorded there, end to end is **NOT TESTED**.

## Why
* **Listening control.** When the user mutes, the app stops sending audio at once. Without a signal, the server
  keeps the half-sentence open and joins it with whatever the user says after unmuting. The backend's
  "listening control" item covers this: stop listening and drop the cut-off utterance while muted, resume on
  unmute. The same applies while a phone call holds the microphone.
* **Client info.** The server needs to tell app calls from dashboard calls and see the device, route and mute
  state in the call trace.

## Transport (why RPC)
Contract v1 §4 allows the client no data packets (the agent ignores them) and no metadata/attribute updates (the
token does not grant them). The only client→agent path is an RPC to `nexa-agent-<voice_session_id>`, the
same mechanism as `nexa.voice.resume`. The client therefore sends each signal as an RPC with a JSON payload.
Each signal keeps only its newest value, has one request in flight, and waits at least 600 ms between sends.
This keeps the server's RPC limit (burst 20, then 2/s), which `resume` shares, free for `resume`.

## Opt-in: `agent_ready.capabilities.client_signals`
The agent declares what it accepts in `agent_ready` (and, ideally, in the `session_state` snapshot as well, so a
client that missed `agent_ready` still learns it):

```json
"capabilities": {
  "client_signals": {
    "listening_control": "nexa.voice.listening",
    "client_info": "nexa.voice.client_info"
  }
}
```

* A string is the RPC method name the client must call, so the backend chooses the names.
* `true` means "accepted under the default name above".
* Absent or `false` means the client sends nothing for that signal.
* If the RPC answers `UNSUPPORTED_METHOD` (1400), the client stops sending that signal for the session.
* Any other error is retried once. Mute itself never waits for the RPC: the microphone is already off.

The client reads `capabilities` from `agent_ready` (a new agent starts afresh), and from every `session_state` and
`resume` answer (a signal whose method is unchanged keeps its state; a newly learned one gets the current state
at once). `client_signals` missing from a later snapshot turns the signals off.

## `listening_control` payload
```json
{"listening": false, "reason": "mute"}
```
* `listening`: `false` when the microphone stopped sending, `true` when it resumed.
* `reason`: `mute` | `unmute` | `phone_call` | `phone_call_ended`. On Android, another app's call (WhatsApp, VoIP)
  that takes the audio is sent as `phone_call` / `phone_call_ended`, so the client stays within the agreed set.
* Sent after the microphone state actually changed. A call that is already muted when `agent_ready`
  arrives sends `{"listening": false}` immediately.
* Requested server behaviour while `false`: stop VAD/STT for the user, discard the partial utterance, and do
  not treat silence as end-of-turn. If the assistant is speaking, it may finish.

## `client_info` payload (no audio, no text)
```json
{
  "source": "app",
  "sdk": "nexa_flutter",
  "platform": "android",
  "os_version": "Android 13 (API 33)",
  "device_model": "nubia NX679J",
  "route": "speaker",
  "speaker_preferred": true,
  "audio_mode": "in_communication",
  "muted": false,
  "microphone_on": true,
  "phone_call": false
}
```
* `phone_call`: true while a phone call or another app's call holds the microphone.
* `route`: `speaker` | `earpiece` | `wired` | `bluetooth` | `usb` | `other` | `unknown` (the output actually in use).
* `audio_mode`: Android `in_communication` / `normal` / `in_call` …; iOS `videoChat` / `voiceChat` …
* Sent on `agent_ready` and whenever route, mode, mute or phone-call state changes (coalesced).

## What the backend needs to confirm
1. Method names (or accept the defaults).
2. The `capabilities.client_signals` shape, and whether it also appears in `session_state`.
3. The listening-control semantics above (discard the partial utterance while muted).
4. Whether any `client_info` field is unwanted. Device model and OS version are personal-ish metadata and should
   be kept with the same retention as the call trace.

Client code: `packages/nexa_sdk/lib/src/features/voice/nexa_voice_signals.dart`, transport
`LiveKitVoiceTransport.sendSignal`.
