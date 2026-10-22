# NEXA Realtime Voice Transport — PROPOSED

**Status:** proposed, not implemented, no backend. The only implementation in
the workspace is `MockRealtimeVoiceTransport` (nexa_core/testing), which exists
to drive the voice state machine in tests and demos.

## Why this is separate from the GPU Manager contract

`gpu-manager-api.v1.2.0.json` is a **request / poll / event** job API:
`POST /v1/jobs` → `GET /v1/jobs/{id}` or `GET /v1/jobs/{id}/events?after=seq`.
It declares `streaming: [progress|tokens|partial_results]` per operation but
exposes no push channel (no SSE, WebSocket or WebRTC). It has
`speech.transcribe` (whisper models, verified) and lists `speech.synthesize`
as an operation name, but the handover notes state **no TTS operation is
runnable today**. Therefore:

* Bidirectional low-latency voice **cannot** be built by calling the GPU
  Manager from a device, and cannot be faked by polling.
* A NEXA realtime gateway must own the duplex channel, VAD, turn-taking,
  barge-in and audio framing, and call GPU Manager (or another engine) for
  STT/LLM/TTS behind it.

## Proposed channel

`wss://gw.<env>.nexa.example/v1/sdk/realtime?session=<session_id>`
Bearer session credential in the `Authorization` header (or first control frame).

| Direction | Frame | Payload |
|---|---|---|
| C→S | binary | PCM16 mono, 16 kHz, 20 ms frames, header `{seq:u32}` |
| C→S | text/JSON | `{"type":"interrupt"}`, `{"type":"mute","muted":bool}`, `{"type":"end"}` |
| S→C | text/JSON | `connected`, `user_speech_started`, `user_speech_ended`, `transcript{text,is_final}`, `assistant_thinking`, `assistant_turn_ended`, `interrupted`, `model_busy{estimated_wait_ms}`, `quota_exceeded{quota_kind}`, `network_quality{weak,rtt_ms}`, `disconnected{will_reconnect,reason}` |
| S→C | binary | assistant PCM16 chunks with `{seq:u32, transcript_delta?:utf8}` |

These map 1:1 to `RealtimeVoiceEvent` in `nexa_core` so the state machine does
not change when the transport lands.

## Open questions for the backend team

1. Codec: raw PCM16 (simplest) vs Opus (bandwidth). SDK assumes PCM16 until decided.
2. Who runs VAD: server-side (preferred for consistency) or client-side (lower latency, more battery).
3. TTS engine: GPU Manager has no runnable `speech.synthesize`; decide engine before any voice milestone.
4. Reconnect semantics: does the server keep turn state across a reconnect window?
5. Quota unit for voice (seconds streamed vs turns).
