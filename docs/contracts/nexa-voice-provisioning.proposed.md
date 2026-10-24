> **SUPERSEDED (2026-10-24).** This SDK-side proposal is replaced by the backend-owned contract
> `nexa.voice.v1`, handoff 1.0.0, vendored in `docs/contracts/voice-v1/handoff-1.0.0-4cd5247/`
> (start with `voice-contract-v1.md`). Differences and the migration are in
> `docs/voice/backend-compatibility-v1.md`. Kept for history only; do not code against it.

# NEXA Voice Provisioning & Signed Agent Events — PROPOSED (SDK side)

**Status: PROPOSED by the SDK team; implemented by the reference gateway
only.** The backend repository (`nexa-integration`, branch
`integration/phase4-3-phase5-voice`, commit `1b8f848`) and its
`docs/voice/security-review.md` were **not reachable** from the SDK
environment when Phase 5.2 was executed, so the real provisioning response,
event-signing rules and lifecycle events could not be read. This document is
the contract the SDK is built and tested against; **it must be reconciled
with the backend before any claim of backend compatibility.** All wire
mapping is isolated in `GatewayVoiceProvisioner._parseGrant` and
`SignedVoiceEvent` / `VoiceEventVerifier` so realignment does not touch the
controller or UI.

Supersedes `nexa-realtime-voice.proposed.md` (the PCM-over-WebSocket
proposal): audio now moves through LiveKit (WebRTC); the gateway only
provisions and signals.

## 1. Endpoints (bearer = chat session credential)

| Method | Path | Purpose |
|---|---|---|
| POST | `/v1/sdk/sessions/{session_id}/voice` | provision a voice session → grant (201) |
| POST | `/v1/sdk/sessions/{session_id}/voice/intents` | client intent `{type: "interrupt"}` (202) |
| DELETE | `/v1/sdk/sessions/{session_id}/voice` | end voice session (204, idempotent) |

Errors reuse the gateway envelope: 401 token codes, 402 `quota_exceeded`
(`quota_kind: voice_minutes`), 403 `capability_not_granted` (liveVoice not
granted), 403 `forbidden` (other application), 404 `voice_session_not_found`,
409 `voice_session_active`, 410 session ended, 503 `voice_unavailable`.

## 2. Grant (201 body)

```json
{
  "voice_session_id": "vs_…",
  "livekit_url": "wss://…",
  "participant_token": "<room-scoped LiveKit participant JWT>",
  "room_name": "nexa-…",
  "participant_identity": "user-…",
  "agent_identity": "nexa-agent",
  "expires_at": "2026-10-23T10:00:00Z",
  "event_verification_key": "<per-session secret>",
  "event_signature_alg": "HMAC-SHA256",
  "max_duration_seconds": 300
}
```

Rules the SDK enforces: `livekit_url` must be `ws`/`wss`; `expires_at` is
required and the SDK refuses expired grants; `event_signature_alg` other than
`HMAC-SHA256` is a contract violation; a missing key is accepted only when
`NexaVoiceOptions.allowUnverifiedEvents` is true (development) and the UI
then shows an "unsigned events" banner. The participant token must carry
`roomJoin`, `canPublish`, `canSubscribe`, `canPublishData` for one room and
**no** admin or create rights (verified in the reference gateway tests).

## 3. Signed agent events (LiveKit data packets, topic `nexa.voice`)

```json
{"v":1,"type":"assistant_speaking_started","seq":7,
 "voice_session_id":"vs_…","issued_at":1760000000000,
 "payload":{…},"sig":"<base64url HMAC-SHA256>"}
```

`canonical = "v|voice_session_id|seq|type|issued_at_ms|" + JSON(payload, keys sorted, no spaces)`
`sig = base64url(HMAC-SHA256(event_verification_key, canonical))` without padding.

Verifier rules (`VoiceEventVerifier`): version must be 1; session must match
the grant; signature required when a key was issued; `seq` strictly
increasing (duplicates/replays rejected); `issued_at` within ±2 min; rejected
packets are reported (`NexaVoiceEventRejected`) and never change state.
Unsigned packets from a participant other than the agent are always dropped.

Event types → SDK events: `agent_joined`, `agent_left`, `user_speech_started`,
`user_speech_ended`, `transcript{text,is_final}`, `assistant_transcript`,
`assistant_thinking`, `assistant_speaking_started`, `assistant_speaking_ended`,
`interrupted`, `model_busy{estimated_wait_ms}`, `model_available`,
`quota_exceeded{quota_kind}`, `session_ending{reason}`. Unknown types are
ignored (forward compatible).

Client → agent intents (data packet, same topic, unsigned):
`{"v":1,"type":"interrupt","voice_session_id":…,"issued_at":…}`; also posted
to the gateway over HTTP so the server stays authoritative.

## 4. Threat model of the per-session verification key (needs human approval)

* The key is delivered to the client, so it proves "produced by a holder of
  this session's key" (gateway/agent, or the client itself). It is an
  integrity/replay defence for the client's own UI, **not** proof of agent
  identity to third parties and **not** client authorisation.
* The gateway must never accept client-originated events as authorisation
  for quota, billing or session decisions; the SDK only sends intents.
* Compromise scope: one voice session; the key rotates with each grant.
* Replay bounded by `seq`; staleness bounded by the skew window.
* Development mode without a key is visibly flagged and can be disabled.
* Open for the backend security review: whether the key should instead be
  an asymmetric public key (client verifies, cannot sign), and whether
  LiveKit participant metadata/attributes should carry the agent identity.
