# NEXA Voice API — canonical contract for the Flutter SDK

| | |
|---|---|
| Document version | **1.0.0** (handoff of backend `nexa.voice.v1`) |
| Owner | NEXA Backend. **The implemented code is the source of truth**; this file is verified against it by `tests/voice_gateway/test_contract_fixtures.py` |
| Wire contract id | `nexa.voice.v1` (value of `contract` and of every event's `v`) |
| Generated from | see `MANIFEST.json` → `backend_commit` |
| Status | Everything in §1–§9 is **implemented and tested**. Anything not yet implemented is only in §10 and is labelled PROPOSED. |

Fixtures referenced below live in `fixtures/` (sanitized: `vs_<id>`, `<livekit-join-jwt>`, `<iso8601-utc>`, `<number>`
are placeholders for volatile values; every other value is literal).

## 1. Transport overview
1. The app calls the **REST gateway** to create a voice session. The response carries a LiveKit URL, a short-lived
   join token, and an Ed25519 **public** key.
2. The app joins the LiveKit room with the join token and publishes the **microphone** only.
3. The server-side agent (identity `nexa-agent-<voice_session_id>`) publishes **signed events** as reliable data
   packets on topic `nexa.voice.events` and answers the RPC `nexa.voice.resume`. Assistant audio arrives as an
   ordinary audio track.
4. The app ends the call with `DELETE`. Ending deletes the LiveKit room (that is how access is revoked).

## 2. Authentication and common headers (all `/v1/sdk/*` calls)
| Header | Required | Notes |
|---|---|---|
| `Authorization: Bearer <sdk token>` | yes | Opaque SDK session token issued by the tenant's backend. Must carry scope **`voice:session`** (NOT in the default token scopes; the tenant must request it when minting) |
| `X-Nexa-App-Id: <application id>` | yes | Must equal the application the token was issued for |
| `X-Nexa-Sdk-Version: <semver>` | yes | any non-empty string |
| `X-Request-Id` | optional | 8–64 chars `[A-Za-z0-9._-]`, echoed back |
| `Content-Type: application/json` | on POST with body | |

Every response has `Cache-Control: no-store` and `X-Request-Id`. Error envelope for **all** errors:
```json
{"error": {"code": "<string>", "message": "<developer text, not for UI>", "retryable": false,
           "retry_after_seconds": 5, "quota_kind": "voice_seconds"}}
```
`retry_after_seconds` and `quota_kind` are present only when applicable. A `Retry-After` HTTP header (seconds) is sent
whenever `retry_after_seconds` is. Messages are English developer text and may change; **switch on `code`**.
The full catalogue is `error-catalogue.md`.

## 3. Endpoints

### 3.1 `POST /v1/sdk/voice/sessions` → `201`
Request body (unknown fields are ignored):
| Field | Type | Required | Rule |
|---|---|---|---|
| `language_tag` | `"en"` \| `"ar"` | yes | anything else → `422 validation_failed` |
| `chat_session_id` | string ≤128 | no | if given must be the caller's own chat session, else `404 session_not_found` |

Response (`fixtures/rest/create_session.201.json`):
| Field | Type | Meaning |
|---|---|---|
| `voice_session_id` | string `vs_…` | the id for every later call |
| `contract` | `"nexa.voice.v1"` | refuse to continue if different |
| `livekit.url` | string | LiveKit signalling URL (`wss://…`) |
| `livekit.room` | string | room to join |
| `livekit.identity` | string | **join with exactly this identity** (`nexa-user-<voice_session_id>`) |
| `livekit.token` | string (JWT) | join token. Secret; never log it |
| `livekit.token_expires_at` | ISO-8601 UTC | see §6 |
| `events.topic` | `"nexa.voice.events"` | data-packet topic |
| `events.resume_rpc` | `"nexa.voice.resume"` | RPC method name |
| `events.format` | `"sealed"` | every packet is a signed envelope (`event-verification.md`) |
| `events.alg` | `"ed25519"` | algorithm to verify with. Pin it from here. (`"hmac-sha256"` only if the operator enabled the legacy mode; then the block has `key` instead of `public_key`) |
| `events.public_key` | base64url, 43 chars | Ed25519 public key for this session only |
| `limits.max_seconds` | int | seconds the call may last (may be **less than the app's usual cap** when monthly quota is nearly used) |
| `limits.reserved_seconds` | int | equals `max_seconds` today |
| `reconnect.grace_seconds` | int | how long the agent keeps the call after the user's connection drops |
| `reconnect.token_refresh_path` | string | path of the refresh endpoint (§3.2) |
| `reconnect.max_refreshes` | int | refresh budget per session |
| `join_deadline_seconds` | int | the user must join within this many seconds or the session ends (`join_timeout`) |

The call returns **after the agent has joined the room** (it waits up to ~5 s for it). Therefore a `201` means an agent
is present or arriving within moments; `agent_state` (§3.3) is already `joined` when the response arrives.
**If no agent could be provided the call fails with `503 voice_unavailable` and nothing is issued** (no id, no token,
no quota consumed, nothing to clean up). Measured locally: a `201` takes about 0.3–1 s; a refusal takes up to the 5 s agent wait (operator-configurable) plus overhead.

Errors: `400 missing_sdk_version | bad_request`, `401 missing_token | invalid_token | token_expired`,
`402 quota_exceeded`, `403 forbidden | application_mismatch | capability_not_granted`, `404 session_not_found`,
`409 voice_session_active`, `422 validation_failed`, `429 rate_limited`, `503 voice_unavailable`.

### 3.2 `POST /v1/sdk/voice/sessions/{voice_session_id}/token` → `200`
No body. Issues a **fresh join token for the same identity** (use after a network drop, or before the old token's
`token_expires_at` if you must (re)join). Response (`fixtures/rest/refresh_token.200.json`):
`{"voice_session_id", "livekit": {"url","room","identity","token","token_expires_at"}}`.
It never re-sends the event key. Errors: `410 voice_session_ended` (stop; do not retry), `429 rate_limited` with
`retryable:false` (refresh budget used up), `404 voice_session_not_found`, plus the auth errors.

### 3.3 `GET /v1/sdk/voice/sessions/{voice_session_id}` → `200`
Authoritative status. Use it after any disconnect before deciding between "ended" and "reconnect".
Response (`fixtures/rest/get_session.*.json`):
| Field | Type | Notes |
|---|---|---|
| `voice_session_id` | string | |
| `status` | `provisioning` \| `active` \| `ended` | `provisioning` until the user has joined |
| `end_reason` | string \| null | null until ended. Values in §7 |
| `max_seconds`, `reserved_seconds` | int | |
| `used_seconds` | int \| null | null until ended |
| `language_tag` | `"en"` \| `"ar"` | |
| `agent_state` | `pending` \| `dispatched` \| `joined` \| `unavailable` \| `ended` | §3.3.1 |
| `remaining_seconds` | int | **only** when `status == "active"` |

#### 3.3.1 `agent_state`
| Value | Meaning | Client action |
|---|---|---|
| `pending` | no agent accepted yet | not observed after a `201`; treat as "wait" |
| `dispatched` | a worker accepted the job; agent not yet seen | not observed after a `201` today; treat as "wait" |
| `joined` | agent is in the room | normal |
| `unavailable` | `end_reason` is `agent_lost` (the agent disappeared mid-call; real flow, fixture `get_session.agent_lost.200.json`) or `agent_unavailable` (reserved: no agent ever joined; **not observable by the SDK today** because creation then fails with `503` and returns no id) | show "voice unavailable, try again". `agent_lost` is billed until the loss was detected; `agent_unavailable` is never billed |
| `ended` | ended for any other reason | normal end |

### 3.4 `DELETE /v1/sdk/voice/sessions/{voice_session_id}` → `200`
Ends the call: settles usage, **deletes the LiveKit room**. Idempotent (a second call returns the same body,
`end_reason` stays the first one). Response is the §3.3 object (`fixtures/rest/delete_session.200.json`).
**The client must call this on every exit path** (user hang-up, app teardown, after `session_ended`, after a fatal error);
otherwise the server only ends the call via its backstops (its sweep runs every 60 s, so up to about a minute after the cap, and the user keeps consuming reserved seconds meanwhile).

### 3.5 Tenant-backend and internal endpoints (NOT for the SDK)
`GET /v1/server/voice/usage`, `POST /v1/server/voice/sessions/{id}/end`, `POST /v1/internal/livekit/webhook` exist but need
tenant API keys / LiveKit signatures. The mobile app must never call them.

## 4. The LiveKit room (what the client may do)
* Join with `livekit.url` + `livekit.token`; identity is fixed. The room allows **one human** (`max_participants = 1`);
  the agent is not counted.
* Grants in the token: join this one room; publish **microphone** only; subscribe; publish **data** (only needed for
  the `nexa.voice.resume` RPC). No camera/screen, no metadata updates, no room admin/list/create, not hidden, not recorder.
* Do not publish data packets yourself. The agent ignores them; the server rate-limits the RPC (burst 20, then 2/s,
  refused with RPC error `rate_limited`).
* The data packet's *sender* can be `null` and must not be used as trust. Trust only the signature (§5).

## 5. Events (`nexa.voice.v1`)
Delivery: reliable data packets, topic `nexa.voice.events`, each packet = one **sealed envelope**
(`{"e":"<json string>","sig":"<hex>","alg":"ed25519"}`) verified per `event-verification.md`, then `e` is parsed.
Packets are best-effort at join time; the **`nexa.voice.resume` RPC is the source of truth** (§8).

Common fields on every event: `v` (`"nexa.voice.v1"`), `type`, `seq` (int ≥1), `event_id` (`vev_…`),
`voice_session_id`, `occurred_at` (ISO-8601 UTC, ms precision, `…Z`), `mono_ms` (agent-process monotonic clock in ms;
**only for latency diagnostics, not comparable across sessions and not an ordering key**). `turn_id` (`turn_<n>`) is
present on turn-scoped events.

| `type` | Extra fields | Turn id | Notes |
|---|---|---|---|
| `session_state` | `state`, `current_turn_id`, `last_seq`, `elapsed_s`, `max_seconds` | – | snapshot; pushed on every (re)join; reconciles client state |
| `agent_ready` | `state`, `capabilities` | – | once per session, when the user is present and the pipeline is up |
| `user_speech_started` / `user_speech_ended` | – | yes | |
| `transcript` | `text`, `is_final` (bool), `language` | yes | interim only if the STT really produced it |
| `assistant_thinking` | – | yes | |
| `assistant_audio_started` | – | yes | exactly once per turn; audio is on the track |
| `assistant_text` | `text`, `index`, `final` | yes | caption chunks, ordered by `index` |
| `assistant_turn_ended` | `reason` (`completed`\|`interrupted`\|`failed`\|`no_transcript`\|`no_response`), `cancel_id` when interrupted | yes | |
| `interrupted` | `cancel_id`, `by_turn_id`, `audio_started` | yes | barge-in took effect |
| `model_busy` | `estimated_wait_ms` (int\|null) | yes | |
| `model_available` | – | yes | |
| `quota_exceeded` | `quota_kind` (`voice_seconds`) | – | followed by `session_ended` |
| `network_quality` | `weak` (bool), `quality` | – | |
| `error` | `code`, `component`, `retryable` | – | |
| `session_ended` | `reason` — allowed by the schema: `user_ended`\|`quota_exceeded`\|`expired`\|`revoked`\|`server_ended`\|`agent_error`\|`idle_timeout`; **emitted by today's agent: only `quota_exceeded`, `idle_timeout` (user did not return within the grace window) and `server_ended`**. Accept any allowed value | – | terminal; nothing follows |

Real sequences: `fixtures/events/happy_path.json`, `fixtures/events/quota_exhausted_in_call.json`.

**Ordering rules (tested):**
* `seq` is strictly increasing and gapless per session. Apply each `seq` at most once; drop `seq <= last applied`.
* `session_state` and `network_quality` may appear at any point; do not assume their position.
* Per turn: `user_speech_started` → `user_speech_ended` → `transcript` → `assistant_thinking` →
  `assistant_audio_started` → `assistant_text`* → `assistant_turn_ended`. After `interrupted` for a turn, nothing
  further arrives for that turn except its `assistant_turn_ended`.
* `assistant_audio_started` never precedes `assistant_thinking` for the same turn.
* `session_ended` is last. Events for another `voice_session_id` must be rejected.

**Timestamp rules.** `occurred_at` is the agent's wall clock (UTC). It is informational: the client must not reject
events by comparing it with its own clock and must not order by it. Order by `seq` only.
`token_expires_at` is UTC wall clock of the gateway; compare with a clock-skew allowance of ±60 s.

## 6. Token lifetimes and expiry
| Credential | Lifetime | Behaviour |
|---|---|---|
| SDK session token | set by the tenant when minting (default 900 s, min 60 s, max 3600 s) | after expiry → `401 token_expired` (`retryable:true`): obtain a new one from the tenant's backend, then retry |
| LiveKit join token | **60 s** (operator-configurable 30–300 s) | needed to *join/rejoin*. LiveKit still accepts it up to ~60 s after `exp` (measured). Whether LiveKit drops an already-connected client at expiry was not tested: do not rely on either behaviour; fetch a fresh token (§3.2) before any reconnect. Never store it. Call §3.2 before reconnecting |
| Event public key | session lifetime | not secret; useless after the session |
| Session | `limits.max_seconds` | hard-capped server-side (see §7) |
| Join deadline | `join_deadline_seconds` (60) | user must have joined by then |
| Reconnect grace | `reconnect.grace_seconds` (30) | agent waits this long after the user drops |

## 7. Termination, cleanup and quota
`end_reason` values on REST (`GET`/`DELETE`): `user_ended`, `room_closed`, `quota_exceeded`, `join_timeout`,
`provision_failed`, `revoked`, `room_missing`, `agent_lost`, `agent_unavailable`.
| `end_reason` | Cause | Billed |
|---|---|---|
| `user_ended` | client called DELETE | seconds from the user's join to now, capped at reserved |
| `quota_exceeded` | `max_seconds` reached | up to reserved |
| `room_closed` | room finished (e.g. everyone left, empty timeout) | join→finish |
| `join_timeout` | user never joined within the deadline | 0 |
| `provision_failed`, `agent_unavailable` | no room/agent could be provided | 0 |
| `revoked` | tenant revoked the user/key or ended the call | join→now |
| `room_missing`, `agent_lost` | room vanished / agent vanished mid-call | join→now |

* Quota is in **seconds**, reserved at creation and settled when the session ends; the unused part is refunded.
  Exhaustion at creation → `402 quota_exceeded` with `quota_kind:"voice_seconds"` (nothing created). Exhaustion
  inside a call → event `quota_exceeded` then `session_ended{reason:"quota_exceeded"}`.
* **After the agent's `session_ended`, REST still reports `active` until the client calls `DELETE`** (the user is still
  in the room; fixture `quota_exhausted_in_call.json`). Call DELETE, then disconnect. Backstop: the server ends it itself
  after `started + max_seconds + 10 s`, on its next sweep (every 60 s).
* After DELETE (or any server-side end) the room is deleted: the client is disconnected and the old join token is useless.
  No `session_ended` event is delivered in that case (the room is gone) — treat the LiveKit disconnect, then `GET`
  to learn `end_reason`.
* Agent unavailable: at creation it is a `503` (no id issued, nothing billed, nothing to clean up). After a `201` the agent was
  seen in the room; if it later disappears the server ends the call as `agent_lost` after ~30 s of confirmed absence, the room is
  deleted, the client sees a LiveKit disconnect (no event), and `GET` → `agent_state:"unavailable"`, `end_reason:"agent_lost"`.

## 8. Handshake, reconnect, gap repair
1. Connect → call RPC `nexa.voice.resume` with payload `{"last_seq": <highest applied seq, 0 at start>}` (retry every
   ~0.3 s for up to ~25 s while it fails with an RPC error: the agent may not be ready; this loop is the handshake).
2. Response (JSON string): `{"state", "last_seq", "covers", "has_more", "events": [<sealed envelope strings>]}`.
   Verify and apply `events` in order. If `has_more` is true, call again with the new cursor. If `covers` is false the
   replay buffer (last 256 events) no longer reaches back: rely on `state`.
3. On disconnect: `GET` the session. If `status == "ended"` → stop, do not refresh. Else `POST …/token`, rejoin with the
   **same identity**, repeat 1. A fresh `session_state` snapshot is pushed on every rejoin.
4. If `resume` keeps failing past ~25 s (agent gone) → `GET`. The server declares the agent lost only after ~30 s of confirmed
   absence and its sweep (60 s cadence), so `GET` may still say `active` for up to about a minute: end the call yourself
   with `DELETE` and surface "voice unavailable".
Real response: `fixtures/events/resume_rpc_response.json`.

## 9. Error handling summary for the SDK
Retry only when `retryable:true`, honouring `Retry-After`. `503 voice_unavailable` (`retry_after_seconds` 5 or 10) is the
only voice-specific transient error: show a "try again" state, never loop faster than `Retry-After`. Details and
fixtures for every code: `error-catalogue.md`.

## 10. PROPOSED, NOT IMPLEMENTED (separate from everything above)
None of these exist in the backend today; do not code against them.
* P1. A REST `GET …/events?after=` fallback so end users need no data-publish permission (security decision 3).
* P2. Remove the legacy `hmac-sha256` mode after the SDK ships Ed25519 (decision 2; owner sets a date).
* P3. An `agent_unavailable`-style *event* — impossible by construction (no agent to send it); the REST `agent_state` is the signal.
* P4. Replay hardening inside a session beyond `seq` dedupe (an expiry/nonce in the envelope). See `security-assessment.md` §R-2.
* P5. Billing start at `agent_ready` instead of the user's join (decision 8).
