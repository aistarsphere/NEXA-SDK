# Voice security assessment for the handoff (v1.0.0)

Scope: review of the backend repo files docs/voice/security-review.md and docs/voice/security-decisions.md (not shipped in this archive) and the code at the handoff commit.
**Nothing here is approved.** "Recommendation" is the backend engineer's advice; every item in §3 needs an owner decision.
Evidence column = automated test that exercises it (all run against real LiveKit unless stated).

## 1. Controls as implemented
| Area | Behaviour | Evidence |
|---|---|---|
| Tenant isolation | Voice sessions are bound to tenant+application+subject. Another tenant's or user's id answers exactly like a missing one (`404 voice_session_not_found`) and is audited | contract test `foreign_session.404` (identical body to unknown id); `test_integration_43_voice.py` |
| SDK token | opaque, stored HMAC-hashed, scoped; `voice:session` is opt-in (not in default scopes); expiry/revocation enforced per request | fixtures `expired_credential`, `missing_scope`, `invalid_credential` |
| LiveKit join token | 60 s (30–300 configurable); one room, fixed identity, microphone + data publish only; room allows one human | `test_join_token_is_short_lived_by_default`, grants tests in `test_gateway_voice_e2e.py` |
| Revocation | LiveKit tokens cannot be revoked by id and are accepted ~60 s past `exp`, so ending a session **deletes the room**; the server runs `room.auto_create:false`, so an old token cannot recreate or rejoin. Failed deletes are retried by maintenance | subject-revocation e2e; `reap_rooms` tests |
| Event authenticity | Ed25519 per-session key derived from a server secret, never stored; client holds only the public key; algorithm pinned from the REST response; domain-separated; session-bound verifier | `test_event_signing.py` (10), forged-event e2e, contract test vectors |
| Replay | cross-session replay rejected (`voice_session_id`); in-session duplicates rejected by `seq` rule | contract test (`ReplayGuard`, vectors) |
| Data publishing | users may publish data only so they can call the resume RPC; the RPC answers only the bound identity and is budgeted (burst 20, 2/s); the agent ignores all other client data | `test_resume_rpc_*` |
| Quota | seconds reserved atomically under row locks (tenant then app), settled exactly once (idempotent `finalize`), refunded when unused; hard cap enforced both by the agent timer and by the server sweep; concurrent end paths settle once | `test_settlement_is_idempotent_*`, `test_maintenance_backstops_*`, fixture `quota_exceeded_on_create` / `quota_exhausted_in_call` |
| Capacity / availability | a call that cannot get an agent is refused (`503`) and fully cleaned up; a lost agent ends the call | `test_dispatch_reliability.py` |
| Secrets | LiveKit key/secret, dispatch secret and pepper never appear in responses, logs or fixtures; production refuses dev/weak LiveKit credentials and non-`wss` | `test_repo_hygiene.py`, fixture generator asserts no secret/JWT in any fixture |

## 2. Residual risks
| ID | Risk | Severity | Mitigation today |
|---|---|---|---|
| R-1 | Hostile user can send arbitrary data packets to the agent (CPU/bandwidth churn). No LiveKit-level rate limit configured | Low–Med | agent ignores them; resume RPC budgeted |
| R-2 | A valid event captured earlier in the same session can be re-delivered; only the client's `seq` rule stops it (no expiry/nonce in the envelope). Impact is limited to the capturing party's own session (events are only delivered to that user) | Low | client MUST implement step 7 of `event-verification.md` |
| R-3 | Signing is authenticity, not confidentiality. LiveKit sees audio, transcripts, dispatch metadata (contains the seed from which the session key is derived). Fine for self-hosted LiveKit; **not** for a third-party/cloud LiveKit | High if hosted externally | decision D4 |
| R-4 | Revoking an SDK token does not end a live call (only `subjects/revoke`, key revocation, tenant end-call, or the user's own DELETE do) | Med | documented; tenant end-call exists |
| R-5 | Billing starts at the user's join, not when the agent is ready; an agent lost mid-call is billed until detected (≈30 s grace + ≤60 s sweep) | Med (product) | D8 |
| R-6 | Shared worker capacity is not partitioned per tenant: one tenant can occupy capacity (bounded by its per-app concurrent cap, default 5, and per-user creation rate 6/min) and cause `503` for others | Med | caps only; no per-tenant reservation |
| R-7 | In-process rate limits (per gateway instance); multiple instances multiply them | Low–Med | ADR 0002 |
| R-8 | Compromised worker holds event seeds of the sessions it serves, the dispatch secret and the GPU key | High impact, low likelihood | isolate network segment; rotate on suspicion |
| R-9 | Capacity numbers (sessions per core) derive from mock backends | Med | needs a load test with real models |
| R-10 | The SDK compatibility could not be checked against the Phase 5.2 SDK branch (not accessible) | Med | matrix part B lists what to verify |
| R-11 | Transcripts are personal data stored in no NEXA table, but pass through LiveKit and (later) GPU services; retention/DPA not decided | Med | D4, D6 |

## 3. Decisions requiring owner approval (none made)
| # | Decision | Backend default now | Recommendation | Why it needs a human |
|---|---|---|---|---|
| D1 | Join-token TTL, per-session cap, refresh cap | 60 s; 600 s per session (per-app column); 30 refreshes | keep 60 s TTL; confirm caps against cost model | cost/abuse trade-off |
| D2 | Event verification material in the REST response | Ed25519 public key; HMAC legacy opt-in | approve Ed25519 as the contract; set a removal date for HMAC | contract commitment with SDK |
| D3 | `canPublishData` for end users (needed for RPC) | allowed, budgeted | accept for v1; if unacceptable fund proposal P1 (REST event fetch) | architectural cost |
| D4 | LiveKit hosting, TURN, region/residency, recording | self-hosted assumed; no recording; staging templates fail closed | self-host in the same trust boundary as the gateway; keep recording off | legal/compliance |
| D5 | Real STT/LLM/TTS models and Arabic quality | mocks; test tone and mocks refused in production | choose after a real-model quality + capacity test | product/quality |
| D6 | Retention of voice rows, usage records, audit | 90 days voice rows | confirm per legal requirement | legal |
| D7 | Must a voice call require an active chat session | optional `chat_session_id` | decide with SDK UX | product |
| D8 | When billing starts; refund policy for dead air | at user join; `agent_unavailable` never billed; `agent_lost` billed until detected | bill from `agent_ready`, refund `agent_lost` dead air | money |

## 4. Handoff-specific notes
* Fixtures contain no real ids, tokens, keys, tenants or timestamps; `test_vectors.json` uses a **published test seed** that
  protects nothing.
* The create-session response contains the LiveKit join token. SDK logging must redact `livekit.token` and anything under `events`.
