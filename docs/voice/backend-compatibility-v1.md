# SDK ↔ Backend voice compatibility matrix — contract `nexa.voice.v1`

Source of truth: backend handoff **1.0.0** (backend commit `4cd524780a7de74313859f5891bd1802cbe75839`,
branch `integration/phase4-3-phase5-voice`), vendored byte-for-byte in
`docs/contracts/voice-v1/handoff-1.0.0-4cd5247/` (32 files; every SHA-256 matches `MANIFEST.json`,
re-checked by `nexa_core/test/voice/voice_events_v1_test.dart`).

SDK baseline before alignment: `feature/phase5-2-livekit-voice` @ `b9091d7`. Aligned on
`feature/phase5-3b-voice-contract-v1`.

Status words: **aligned** = SDK code now matches the handoff and a fixture test proves it;
**fixture-verified** = verified against the backend's sanitized fixtures only (no live backend);
**not verifiable here** = needs the real backend or a device.

## 1. Provisioning and REST

| Item | Backend (handoff) | SDK before (b9091d7, proposed) | SDK now | Status / evidence |
|---|---|---|---|---|
| Create | `POST /v1/sdk/voice/sessions` `{language_tag, chat_session_id?}` → 201 | `POST /v1/sdk/sessions/{chat}/voice`, empty body | backend shape; `chat_session_id` only when a chat session is active | aligned, fixture `create_session.201` |
| Voice needs chat session | optional (decision D7 open) | required + client-side `liveVoice` pre-check | not required; server decides (403/404) | aligned |
| Grant shape | nested `livekit.*`, `events.*`, `limits.*`, `reconnect.*`, `join_deadline_seconds`, `contract` | flat `livekit_url`, `participant_token`, `room_name`, … | `GatewayVoiceProvisioner.parseGrant` reads the nested shape | aligned, every field asserted |
| `contract` | `"nexa.voice.v1"`, refuse otherwise | absent | refused when different | aligned |
| Agent identity | `nexa-agent-<voice_session_id>` (contract §1) | `agent_identity` field | derived from the id | aligned |
| Join token TTL | **60 s**, refresh before any rejoin | treated as **session expiry** (call ended after 60 s) | not a session limit; ±60 s skew check before join; refresh via §3.2 | aligned (bug fixed), test "60 s join token is NOT the session lifetime" |
| Session cap | `limits.max_seconds`, enforced server-side | `max_duration_seconds` timer | server cap + client backstop `max_seconds + 15 s` → `GET` decides | aligned |
| Token refresh | `POST …/{id}/token` → `{voice_session_id, livekit}`; 410 stop; 429 non-retryable = budget | absent | `refreshToken`; 410 / 429 → `VoiceSessionOverException` | aligned, fixtures `refresh_token.200`, `refresh_after_end.410`, `refresh_limit.429` |
| Status | `GET …/{id}` (`status`, `end_reason`, `agent_state`, …) | absent | `status()` + `VoiceSessionStatus` | aligned, fixtures `get_session.*` (3) |
| End | `DELETE …/{id}` → 200 + status; idempotent; required on every exit | `DELETE /v1/sdk/sessions/{chat}/voice` → 204 | `end()` on every exit path; DELETE **before** leaving the room; never throws | aligned, fixture `delete_session.200` |
| Interrupt | **no command**; agent detects barge-in | `POST …/voice/intents` + data packet | removed; `SendInterrupt` is local only; no client data packets | aligned |
| Scope | token needs `voice:session` (not default) | not modelled | host must mint with it (example + docs) | aligned (host responsibility) |

## 2. Events

| Item | Backend | SDK before | SDK now | Status |
|---|---|---|---|---|
| Topic | `nexa.voice.events` (from `events.topic`) | `nexa.voice` | from the grant | aligned |
| Envelope | `{"e": "<event json string>", "sig": "<hex>", "alg": "ed25519"}` | flat event + `sig` | sealed envelope, `e` verified as raw bytes before parsing | aligned |
| Algorithm | Ed25519, public key in REST, alg pinned; legacy HMAC opt-in | HMAC-SHA256 with a shared key | Ed25519 (`pinenacl`); HMAC only with `NexaVoiceOptions.allowLegacyHmac` | aligned, **all published test vectors pass** |
| Signed bytes | `UTF8("nexa.voice.v1") + 0x00 + UTF8(e)` | `v\|id\|seq\|type\|ts\|` + sorted JSON | as backend | aligned |
| Signature encoding | lowercase hex, 64 bytes | base64url | lowercase hex only | aligned |
| Version | `v == "nexa.voice.v1"` | `v == 1` | as backend | aligned |
| Sequencing | `seq` ≥1, gapless per session; drop `<= last`; gaps → `resume`, apply nothing past a gap | strictly increasing, gaps tolerated | `VoiceReplayGuard`: gapless, holds up to 256, `resume` repair, `covers:false` → jump | aligned, vectors `replay_rule_results` |
| Timestamps | `occurred_at` informational; **must not** reject by clock | rejected outside ±2 min | no clock check | aligned (behaviour removed per contract, not a weakening: replay is bounded by `seq`) |
| Unknown type | reject (and log) | ignored | rejected, counted, never applied | aligned |
| Required fields | `turn_id` on turn events, `is_final` bool, `cancel_id`, `session_ended.reason` enum | none | validated | aligned |
| Cross-session | reject other `voice_session_id` | rejected | rejected | aligned |
| Event names | `agent_ready`, `session_state`, `assistant_audio_started`, `assistant_text{index,final}`, `assistant_turn_ended{reason}`, `network_quality`, `error`, `session_ended{reason}`, … | `agent_joined`, `assistant_speaking_started/ended`, `assistant_transcript`, `session_ending`, … | backend names; captions folded per turn by `index` | aligned, all 10 happy-path examples |
| `interrupted` turn end | must not cause a second `listening` | n/a | `assistant_turn_ended{reason: interrupted}` dropped | aligned |
| Handshake | RPC `nexa.voice.resume {last_seq}`, retry 0.3 s for ~25 s | none | implemented; also completes on verified `agent_ready`/`session_state` (matrix §A) | aligned; RPC path **not verifiable here** (reference gateway cannot answer RPCs) |
| Sender identity | never trusted | unsigned packets from agent accepted | ignored; signature only | aligned |

## 3. Lifecycle and errors

| Situation | Backend signal | SDK behaviour now |
|---|---|---|
| No agent at creation | `503 voice_unavailable`, `Retry-After` (5/10 s), nothing created | `disconnected`, "voice unavailable, try again"; next `start()` waits out `Retry-After`; no DELETE (no id) |
| Agent lost mid-call | room deleted, no event; `GET` → `ended`, `agent_state: unavailable`, `end_reason: agent_lost` | disconnect → `GET` → `disconnected` + "voice unavailable", retry offered, DELETE (idempotent) |
| Other server end (revoke, room_closed, join_timeout, user_ended elsewhere, unknown) | room deleted, no event | disconnect → `GET` → `ended` with `endReason: server:<end_reason>`; never refresh |
| Network drop, session active | `GET` active | `POST …/token` → rejoin same identity → `resume(last_seq)` |
| Refresh refused | 410 / 429 budget | `GET` → end per reason |
| Gateway unreachable during recovery | — | retries `GET` within `reconnect.grace_seconds`, then `disconnected` + network error |
| Agent never answers `resume` (~25 s) | — | `GET`; still active → DELETE + "voice unavailable" |
| Quota in call | `quota_exceeded` → `session_ended{quota_exceeded}`; REST still `active` | `quotaExceeded`, then DELETE, then leave the room |
| Quota at creation | `402 quota_exceeded`, `voice_seconds` | `quotaExceeded`, nothing to clean up |
| Agent `session_ended{other}` | event | `ended` (`server:<reason>`) + DELETE |
| Agent `error{retryable:false}` | event | `disconnected` + DELETE; retryable errors logged only |

Error mapping (all 14 error fixtures tested): `token_expired`/`invalid_token`/`missing_token` →
`AuthenticationException` (SDK token refreshed once first); `forbidden`/`application_mismatch` →
`AuthenticationException`; `capability_not_granted` → `CapabilityNotGrantedException('liveVoice')`;
`quota_exceeded` → `QuotaExceededException('voice_seconds')`; `voice_session_not_found`,
`voice_session_active`, `bad_request`, `missing_sdk_version` → `ServerException(serverCode)`;
`validation_failed` → `ContractViolationException`; `voice_unavailable` → retryable
`ServerException(retryAfter)`; 410 → `SessionExpiredException` (voice refresh: session over);
429 → `RateLimitedException` (voice refresh: session over).

**Deviation from the catalogue's recommendation:** `forbidden` / `application_mismatch` map to
`AuthenticationException`, not `PermissionDeniedException`, because the SDK uses the latter for
the OS microphone permission and the UI would tell the user to open Settings. The catalogue marks
its mapping as a recommendation.

## 4. Remaining differences / not verifiable here

1. `nexa.voice.resume` RPC: implemented to spec but never answered in this environment (the
   reference gateway's mock agent cannot serve RPCs). Needs the real agent.
2. `assistant_text` folding concatenates chunks in `index` order with no separator; the contract
   does not say whether chunks carry their own spacing.
3. Barge-in playback stop is not done locally (LiveKit plays the agent track); the agent stops its
   own audio when it detects barge-in. If the product needs instant local silence, add a
   remote-track mute.
4. Nothing was run against the real backend, a staging gateway, or a real agent.
