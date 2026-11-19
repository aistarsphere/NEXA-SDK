# ADR 0004 — Phase 5.3B: align the voice client to backend contract `nexa.voice.v1`

Date: 2026-10-24 · Status: accepted (SDK side) · Supersedes the provisioning/signing parts of ADR 0003

## Context
Phase 5.2 built the LiveKit client against an SDK-proposed contract because the backend was
unreachable. The backend team has now published handoff 1.0.0 (backend commit `4cd5247`). It differs
in endpoints, grant shape, event envelope, algorithm, event names, sequencing, handshake, interrupt
semantics, token lifetime and termination signalling.

## Decisions
1. **The handoff is the source of truth.** Vendored byte-for-byte under
   `docs/contracts/voice-v1/handoff-1.0.0-4cd5247/`; a test re-verifies every SHA-256 against its
   `MANIFEST.json`. Consumer tests read the backend's fixtures directly.
2. **Ed25519 via `pinenacl`** (pure Dart, synchronous, so per-packet verification stays ordered).
   HMAC legacy mode only behind `NexaVoiceOptions.allowLegacyHmac` (default off).
3. **`VoiceEventPipeline` in `nexa_core`** owns verify → seq → map → handshake completion → caption
   folding, so it is unit-tested without WebRTC; `LiveKitVoiceTransport` only feeds it packets and
   RPC answers.
4. **Server is authoritative on termination.** Any unexpected room disconnect triggers `GET`; the
   SDK never infers "ended" or "reconnect" locally. `DELETE` runs before leaving the room on every
   exit path.
5. **No client-originated data** (no interrupt intent, no packets); barge-in is the agent's.
6. **Voice is decoupled from chat sessions** (optional `chat_session_id`, decision D7 open).
7. **The reference gateway mirrors v1** (REST, Ed25519, scopes, Retry-After, dev end simulation),
   documented as a mirror without the RPC.

## Consequences
* Phase 5.2's public voice API changed before ever reaching `main` (`interrupt()` and
  `allowUnverifiedEvents` removed).
* The join token's 60 s TTL no longer ends calls (a real bug in 5.2).
* Live-backend verification and the resume RPC path remain open until the SDK can reach the
  backend or a staging gateway.
