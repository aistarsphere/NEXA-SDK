# Event verification specification (v1.0.0) — Ed25519

Verified by `fixtures/verification/test_vectors.json` (executed by `test_signature_test_vectors_are_stable_and_reject_forgeries`)
and by real calls (`tests/voice_gateway/test_gateway_voice_e2e.py`, `tests/voice/test_event_signing.py`).

## Inputs (from the authenticated `POST /v1/sdk/voice/sessions` response — never from a packet)
`events.alg` (pin it; expect `"ed25519"`), `events.public_key` (base64url without padding, 32 bytes → 43 chars), `voice_session_id`.

## Envelope
A data packet's payload (UTF-8 JSON text) is `{"e": "<string>", "sig": "<hex>", "alg": "ed25519"}`.
`e` is itself a **string containing the event JSON** (do not re-serialize it).

## Algorithm
1. Parse the packet as JSON; `e` and `sig` must be strings, else reject.
2. `envelope.alg` must equal the pinned `events.alg` (otherwise reject: no algorithm negotiation).
3. `message = UTF8("nexa.voice.v1") + 0x00 + UTF8(e)` (13 ASCII bytes, one NUL byte, then the exact bytes of the string `e`).
4. `signature = hex-decode(sig)` (lowercase hex of a 64-byte Ed25519 signature). Verify with the public key. Any failure → reject.
5. Only now parse `e` as JSON. Require: `v == "nexa.voice.v1"`, `type` known, `seq` int ≥ 1, `event_id`, `voice_session_id`,
   `occurred_at`; turn-scoped types need `turn_id`; `transcript.is_final` is bool; `interrupted` needs `cancel_id`;
   `session_ended.reason` is one of the allowed values. Unknown `type` → reject (and log); do not crash the call.
6. `event.voice_session_id` must equal the session id you created; else reject (cross-session replay).
7. Replay/ordering: keep `lastApplied`; apply only `seq > lastApplied`; a duplicate or older `seq` is dropped silently.
   Gaps (`seq > lastApplied + 1`) are repaired by calling `nexa.voice.resume` (see contract §8); do not apply past a gap.
Never use the data packet's sender identity as trust (it can be null).

## Same rules for `resume` RPC results
`events[]` entries are the same sealed-envelope strings; verify each identically.

## Test vectors
`fixtures/verification/test_vectors.json`: a public TEST seed (protects nothing), its public key, two valid envelopes with the
verified events, and four envelopes that **must be rejected** (`tampered_body`, `algorithm_substitution`, `signed_by_another_key`,
`not_json`) plus the replay results. Passing these vectors is the acceptance test for the Dart verifier. The `must_reject` entries
include the backend's error text for information only.

## Limits (be aware, not a defect)
* The signature proves the event came from the session's agent; it provides **no confidentiality** (LiveKit sees the content).
* A valid event captured earlier in the *same* session and re-delivered is stopped only by the `seq` rule in step 7 (no expiry/nonce in the envelope; proposal P4).
* Legacy mode (`alg:"hmac-sha256"`, `events.key` instead of `public_key`): signature = HMAC-SHA256(key=base64url-decoded `events.key`, message=UTF8(e)) as lowercase hex, **no** domain prefix. The default is Ed25519; implement HMAC only if the operator enables it.
