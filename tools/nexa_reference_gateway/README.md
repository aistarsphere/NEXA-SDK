# nexa_reference_gateway — DEVELOPMENT INFRASTRUCTURE

**This is not the NEXA backend.** It is a small, local, in-memory HTTP server
that implements the *proposed* SDK ↔ Gateway contract
(`docs/contracts/nexa-gateway-api.proposed.yaml`, v0.2.0-proposed) with
deterministic scripted replies, so that:

* the Flutter SDK's real HTTP + SSE/long-poll transport can be exercised
  end-to-end (contract tests in `packages/nexa_sdk/test/integration`);
* the example host app can run a full chat journey on a device without any
  cloud dependency.

It contains **no model, no GPU Manager connection, no persistence and no
multi-tenant security**. Responses are canned text generated from keywords.
Nothing here must be deployed or described as production behaviour.

## Run

```bash
dart run tools/nexa_reference_gateway/bin/nexa_reference_gateway.dart --port 8080
# or: make gateway
```

Options: `--host` (default 127.0.0.1), `--port` (8080), `--token-ttl` seconds
(900), `--session-ttl` seconds (3600), `--quota` messages per application (50),
`--delta-ms` delay between streamed deltas (40), `--verbose`.

## Endpoints

Contract endpoints (`/v1/sdk/...`) follow the OpenAPI document exactly,
including the SSE stream `GET /v1/sdk/sessions/{id}/events/stream`.

Development-only endpoints that stand in for the **host backend** (they do
not exist in the real contract and the SDK never calls them):

| Method | Path | Purpose |
|---|---|---|
| POST | `/v1/dev/session-tokens` | mint a short-lived session token for an `application_id` (`ttl_seconds` optional) |
| POST | `/v1/dev/applications/{id}/reset` | reset the application's message quota |
| GET | `/healthz` | liveness + contract version |

## Scripted scenarios (keyword anywhere in the user text)

| keyword | behaviour |
|---|---|
| *(none)* | echo-style reply streamed word by word; `full_text` on completion |
| `long` | ~120 word reply |
| `slow` | long reply with 250 ms between deltas (for Stop) |
| `fail` | reply starts, then `message_failed` (retryable) |
| `reject` | `user_message_rejected` (policy_violation) |
| `interrupt` | SSE connection dropped after the 3rd delta; long-poll answers 503 once — the SDK must reconnect with `after=` |
| `duplicate` | every event of the reply is delivered twice (dedupe test) |
| `ratelimit` | first attempt answers 429 with `retry_after_seconds: 1`; retry succeeds |
| `quota` | application quota set to 0 → `quota_updated(exceeded)`, reply, `session_ended(quota_exceeded)`; new sessions answer 402 until reset |
| `expire` | reply, then `session_ended(expired)`; further calls answer 410 |
| `weather` | tool call → progress → weather tool result → text |
| `book` / `confirm` | tool call requiring explicit confirmation; `confirmed` → text result, `declined` → cancelled |
| `mic` | `permission_requested(microphone)` |

Language: when the session's `language_tag` is `ar` the canned text is Arabic.
