# NEXA Flutter SDK — Live Voice (contract `nexa.voice.v1`)

Updated 2026-10-24 (Phase 5.3B). Backend contract: handoff 1.0.0, vendored in
`docs/contracts/voice-v1/handoff-1.0.0-4cd5247/` (start with `voice-contract-v1.md`).
Field-by-field comparison and migration: `docs/voice/backend-compatibility-v1.md`.

## Status (keep these categories separate)

| Category | Status |
|---|---|
| Aligned with the backend handoff (REST, grant, Ed25519 sealed events, seq rules, lifecycle, errors) | **fixture-verified**: all 23 sanitized fixtures + the published verification vectors pass in consumer tests |
| Real LiveKit room, mic publish, agent audio track, mute/unmute, end | verified on the **Android emulator** against local `livekit-server` + the reference gateway's v1 mirror (mock agent, synthetic tone) |
| `nexa.voice.resume` RPC handshake | implemented to spec; **never answered here** (reference gateway cannot serve RPCs) |
| Live NEXA backend end-to-end | **not run** (backend not reachable from this machine) |
| iOS audio path | iOS app builds; simulator CoreAudio aborts when WebRTC starts; **physical iPhone pending** |
| Assistant speech / AI inference | **none** (mock agent; no model) |

## Public API

```dart
final nexa = await Nexa.initialize(
  config: NexaConfig(..., requestedCapabilities: {NexaCapability.textChat, NexaCapability.liveVoice}),
  auth: MyBackendAuthProvider(),   // token minted WITH scope `voice:session`
  overrides: NexaOverrides(permissionHandler: MyPermissionHandler()), // must grant microphone
  voiceOptions: const NexaVoiceOptions(startMuted: false),
);

final voice = nexa.voice;                 // NexaVoiceController
await voice.start();                      // permission → POST /v1/sdk/voice/sessions → room → handshake
voice.state;                              // ValueListenable<NexaVoiceState>
voice.events;                             // Stream<NexaVoiceEvent>
await voice.setMuted(muted: true);        // or toggleMute(); local only
await voice.end();                        // DELETE, then leave the room
nexa.voiceView(onOpenSettings: ..., autoStart: false); // Live Voice Capsule widget
```

Changes from the Phase 5.2 branch API (never merged to `main`):
* `NexaVoiceController.interrupt()` removed — contract v1 has no interrupt command; the agent
  detects barge-in from the microphone and confirms with `interrupted`.
* `NexaVoiceOptions.allowUnverifiedEvents` removed — events are always verified; added
  `allowLegacyHmac` (off) for the backend's operator-enabled legacy mode.
* Voice no longer requires or starts a chat session; `chat_session_id` is sent only when one is
  active.

`NexaVoiceState.endReason`: `user`, `quota_exceeded`, `expired`, `microphone_denied`, `failed`,
`agent_lost` / `agent_unavailable`, or `server:<end_reason>` (e.g. `server:revoked`).
`NexaVoiceState.error` for "voice unavailable" is a `ServerException` with `serverCode`
`voice_unavailable` (503 at creation, `retryAfter` set) or `agent_lost`; the capsule shows a
"try again" message for both.

## Host requirements

* The SDK token must carry scope **`voice:session`** (not a default scope); the host backend
  requests it when minting. Without it the gateway answers `403 forbidden`.
* iOS: `NSMicrophoneUsageDescription`; `UIBackgroundModes: audio` if calls must survive
  backgrounding; deployment target ≥ 15.
* Android: `RECORD_AUDIO`, `MODIFY_AUDIO_SETTINGS`, `INTERNET`, `BLUETOOTH_CONNECT`.
* The SDK never calls OS permission APIs; implement `NexaPermissionHandler`.
* Production LiveKit URLs must be `wss://`; `ws://` is accepted only with
  `NexaEnvironment.development`.

## Session lifecycle (contract §3, §7, §8)

1. `start()` → `connecting`; host permission handler asked for the microphone.
2. `POST /v1/sdk/voice/sessions {language_tag}` returns **after the agent joined**.
   `503 voice_unavailable` → nothing was created; the next `start()` waits out `Retry-After`.
3. Join the LiveKit room with `livekit.url` / `livekit.token` / fixed `livekit.identity`;
   publish the microphone only; the agent's audio arrives as a remote track.
4. Handshake: RPC `nexa.voice.resume {last_seq}` every ~0.3 s for ~25 s; it also completes on a
   verified `agent_ready` / `session_state`. Then `listening`.
5. Events on `nexa.voice.events` are verified (Ed25519 over `"nexa.voice.v1\0" + e`), applied in
   gapless `seq` order; gaps are repaired with `resume`.
6. Disconnect → `GET` the session: `ended` → stop (map `end_reason`); `active` →
   `POST …/token` → rejoin with the same identity → `resume(last_seq)`.
7. Every exit path sends `DELETE` (idempotent) **before** leaving the room.

## Voice state mapping (v1 events → `VoiceSessionMachine`)

| Source | Machine event |
|---|---|
| handshake complete (resume answer / `agent_ready` / first `session_state`) | `VoiceConnected` |
| `RoomReconnectingEvent` (engine) | `VoiceDisconnected(willReconnect: true)` |
| room disconnected (server end or network) | `VoiceDisconnected(willReconnect: true)` then `GET` decides |
| `session_state{state}` | reconciled: `ai_speaking`→AudioStarted, `thinking`→Thinking, `user_speaking`→SpeechStarted, `listening`→TurnEnded/ModelAvailable when applicable |
| `user_speech_started` / `user_speech_ended` | `VoiceUserSpeechStarted/Ended` |
| `transcript{is_final:true}` | `VoiceTranscriptFinal` (+ transcript line; interim shown italic) |
| `assistant_thinking` | `VoiceAssistantThinking` |
| `assistant_audio_started` | `VoiceAssistantAudioStarted` |
| `assistant_text{index,final}` | caption line only (folded per turn) |
| `assistant_turn_ended` (not `interrupted`) | `VoiceAssistantTurnEnded` |
| `interrupted` | `VoiceInterruptAcknowledged` |
| `model_busy` / `model_available` | `VoiceModelBusy` / `VoiceModelAvailable` |
| `quota_exceeded` | `VoiceQuotaExceeded` (then DELETE) |
| `session_ended{reason}` | quota → `VoiceQuotaExceeded`; other → `VoiceEndRequested` |
| `network_quality{weak}` | `VoiceNetworkQualityChanged` |
| `error{retryable:false}` | `VoiceFailed` |
| `GET` `end_reason: agent_lost` / `agent_state: unavailable` | `VoiceFailed` → `disconnected` + "voice unavailable" |
| `GET` `end_reason: quota_exceeded` | `VoiceQuotaExceeded` |
| `GET` other `end_reason` | `VoiceEndRequested` → `ended` |

The machine is pure and total; snapshots and late events can only produce transitions it allows,
so the UI cannot show contradictory states.

## Event verification

`VoiceEventVerifier` (nexa_core) implements `event-verification.md` steps 1–6 exactly and
`VoiceReplayGuard` step 7. Verified against `fixtures/verification/test_vectors.json`: both valid
envelopes decode to the published events; `tampered_body`, `algorithm_substitution`,
`signed_by_another_key` and `not_json` are rejected; the replay results match. Rejected packets
are counted (`rejectedEvents`) and surfaced as `NexaVoiceEventRejected`; they never change state.
Security limitations: `docs/voice/backend-compatibility-v1.md` §4 and the handoff's
`security-assessment.md` (R-1…R-11, decisions D1…D8, none approved).

## Local run

```bash
livekit-server --dev --bind 127.0.0.1
dart run tools/nexa_reference_gateway/bin/nexa_reference_gateway.dart \
  --livekit-url ws://127.0.0.1:7880 --agent-audio tools/nexa_reference_gateway/assets/agent_tone.ogg
tool/e2e.sh emulator-5554 integration_test/voice_journey_test.dart   # starts both itself
```

The reference gateway is a dev mirror of `nexa.voice.v1` (no RPC, scripted events, synthetic tone);
it is not the NEXA backend.
