# SDK compatibility matrix (v1.0.0)

**What was and was not available for this comparison.** The backend session could read the SDK repository at
`aistarsphere/NEXA-SDK` **`main` @ `9bec0b3`** (local clone) only. The feature branch `feature/phase5-2-livekit-voice`
(`b9091d7`) and therefore `parseGrant`, `SignedVoiceEvent` and the Phase 5.2 transport are **not readable here**.
Rows about those are written from the backend side as *requirements*, marked **UNVERIFIED against SDK code**; the macOS
team should confirm each against its code using the fixtures. Rows marked **verified** compare against SDK `main` source.

## A. Verified against SDK `main` (`packages/nexa_core`)
| SDK element | Backend reality | Match | Required SDK change |
|---|---|---|---|
| `VoiceState` (idle, connecting, listening, userSpeaking, transcribing, thinking, aiSpeaking, bargeIn, muted, weakNetwork, disconnected, reconnecting, modelBusy, microphoneDenied, quotaExceeded, ended) | Server state strings are snake_case of these (`user_speaking`, `ai_speaking`, `barge_in`, `model_busy`, `quota_exceeded`…). Server sends only `idle, listening, user_speaking, transcribing, thinking, ai_speaking, barge_in, model_busy, quota_exceeded, ended` in `state` fields | ✅ | map snake_case→enum; the other six states are client-derived |
| `VoiceConnected` | `agent_ready` event (and the `session_state` snapshot) | ✅ | derive `VoiceConnected` from `agent_ready` **or** a first `session_state` (a late joiner may only get the snapshot) |
| `VoiceUserSpeechStarted/Ended` | `user_speech_started/ended` | ✅ | |
| `VoiceTranscriptFinal` | `transcript` with `is_final:true` (non-final transcripts are interim; ignore or show as partial) | ✅ | only final → machine event |
| `VoiceAssistantThinking` / `AudioStarted` / `TurnEnded` | `assistant_thinking` / `assistant_audio_started` / `assistant_turn_ended` | ✅ | `assistant_turn_ended.reason` has 5 values; `interrupted` must not trigger a second `listening` transition |
| `VoiceInterruptAcknowledged` | `interrupted` (with `cancel_id`) | ✅ | the machine sends `SendInterrupt` on barge-in. **The backend has no "interrupt" command channel**: the agent detects barge-in itself from the microphone. `SendInterrupt` must be a local no-op (stop playback only) |
| `VoiceModelBusy/Available` | `model_busy` / `model_available` | ✅ | |
| `VoiceQuotaExceeded` | event `quota_exceeded` then `session_ended{quota_exceeded}`; also REST `402` at creation | ✅ | after `session_ended` call `DELETE` (REST stays `active` until then) |
| `VoiceNetworkQualityChanged(weak)` | `network_quality{weak}` | ✅ | |
| `VoiceDisconnected(willReconnect)` | **no event**: a deleted room just disconnects the client | ⚠️ | client decides `willReconnect` by calling `GET` (ended → false; active → true) then `POST …/token` |
| `VoiceFailed` | event `error{code,component,retryable}` and REST errors | ✅ | |
| `VoiceMuteToggled` | local only (mute the mic track); backend has no mute event | ✅ | |
| `NexaErrorCode` / `NexaException` | see `error-catalogue.md` mapping | ✅ | add voice codes to the mapper: `voice_unavailable`(retryable), `voice_session_ended`, `voice_session_active`, `capability_not_granted`(carries `quota_kind:"liveVoice"`) |
| Gateway error DTO `{error:{code,message,retryable,retry_after_seconds,quota_kind}}` | identical | ✅ | |
| Voice REST client / `/v1/sdk/voice/*` | **absent in SDK `main`** (no voice DTOs) | ❌ | implement the four calls in `voice-contract-v1.md` §3 |

## B. Phase 5.2 branch items — UNVERIFIED against SDK code (requirements from the backend)
| SDK item | What the backend requires / provides | Check on the macOS side |
|---|---|---|
| `parseGrant` | Must read exactly: `voice_session_id`, `contract`, `livekit.{url,room,identity,token,token_expires_at}`, `events.{topic,resume_rpc,format,alg,public_key}`, `limits.{max_seconds,reserved_seconds}`, `reconnect.{grace_seconds,token_refresh_path,max_refreshes}`, `join_deadline_seconds`. Reject `contract != "nexa.voice.v1"`, `events.alg` other than `ed25519` (unless legacy supported), `public_key` not 43 base64url chars. **There is no `events.key` in the default mode.** Token refresh response has only `voice_session_id` and `livekit.*` | parse `fixtures/rest/create_session.201.json` and `refresh_token.200.json` |
| `SignedVoiceEvent` | Envelope `{e,sig,alg}`; verify per `event-verification.md` **before** parsing `e`; pin alg from REST | pass `fixtures/verification/test_vectors.json` (valid + 4 must-reject) |
| VoiceSessionMachine ↔ transport | transport must deliver `VoiceConnected` from `agent_ready`/first snapshot and apply `seq` dedupe before feeding the machine | replay `fixtures/events/happy_path.json` |
| Reconnect handling | `GET` first, then `POST …/token` (same identity), then `resume(last_seq)`; stop on `410`/`status:"ended"`; never refresh on `429 rate_limited retryable:false` | follow contract §8 |
| Error mapping | table in `error-catalogue.md` | one test per file in `fixtures/errors/` |
| Handshake timeout | resume retry loop ≈ 25 s, 0.3 s interval | |
| Cleanup | `DELETE` on every exit path, after `session_ended`, and on app teardown | |

## C. Mismatches the macOS team must resolve (known from the backend side)
1. **Interrupt command**: `SendInterrupt` has no backend counterpart (see A).
2. **`VoiceDisconnected(willReconnect)`**: not event-driven (see A).
3. **`session_ended` is not guaranteed** to arrive (room deletion removes it); the terminal signal is the disconnect + `GET`.
4. **`agent_state` / `end_reason` `agent_lost`** are new to any older client: map unknown `end_reason` to a generic "ended"; show "voice unavailable" for `agent_state:"unavailable"`.
5. Event `seq` is per voice session, not global, and the buffer replays only the last 256 events.
