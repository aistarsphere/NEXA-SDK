# GPU Manager Boundary (what is real vs. proposed)

Source of truth: `gpu-manager-api.v1.2.0.json` (copied from the 2026-10-22
export) and `GPU-Manager-Handover-2026-10-20.md`.

## Existing, documented GPU Manager operations (authoritative)

| Area | Endpoint | Notes |
|---|---|---|
| Submit job | `POST /v1/jobs` → 202 | v1 dialect (`operation` + `params` + named `inputs`) or generic (`model_id` + typed `inputs[]` + `parameters`). `Idempotency-Key` supported. `priority: interactive|normal|background`. |
| Job status | `GET /v1/jobs/{id}` | `status` (queued/running/succeeded/failed/cancelled) + fine `state`, `progress{step,total,phase}`, `result`, `error{code,message,retryable,kind}`. |
| Job events | `GET /v1/jobs/{id}/events?after=seq` | Poll with cursor. State transitions + messages. **No push.** |
| Cancel | `POST /v1/jobs/{id}/cancel` | Cooperative (between steps/tokens). 409 if finished. |
| LLM chat | operation `llm.chat` | `params.messages[]` (role: system/user/assistant; typed parts text/image), `response_format` text or `json_schema` (→ `result.structured`), `temperature`, `top_p`, `max_new_tokens` (≤4096). Result: `result.text`, `finish_reason` stop/length, `usage`. |
| Speech to text | operation `speech.transcribe` | Input: audio artifact (`POST /v1/artifacts` first). Whisper family verified runnable. |
| Text to speech | operation `speech.synthesize` | Listed in the operation enum, **not runnable** per handover (Qwen3-TTS / XTTS installed without an operation contract). |
| Discovery | `GET /v1/capabilities`, `GET /v1/models`, `GET /v1/models/{id}` | Operation specs declare input slots, typed parameters, outputs, `progress` kind, `streaming` list and cancellation granularity. |
| Artifacts | `POST /v1/artifacts`, `GET /v1/artifacts/{id}/content` | ~24 h expiry → product side must persist what matters. |
| Admin | `/v1/admin/*` | Blocked at the Nginx edge; never relevant to clients. |

Auth: service-to-service bearer API key per *client application*. There is
**no tenant concept, no end-user identity, no per-user quota** in this API.

## What the NEXA backend (gateway) must therefore own

* Tenant + application registry, session tokens, per-tenant quotas, audit.
* Mapping `ConversationEvent` ⇄ GPU Manager jobs:
  * user message → `llm.chat` job (`priority: interactive`) with the tenant's
    system prompt and the conversation window;
  * poll `/v1/jobs/{id}/events` (and/or `/v1/jobs/{id}`) and translate
    progress into `assistant_text_delta` events. **Token-level deltas are only
    possible if the runtime's event stream carries partial text**; the schema
    allows it (`JobEventOut.data`) but it is not documented for `llm.chat`.
    Until confirmed, expect coarse deltas or a single completion.
  * cancel → `POST /v1/jobs/{id}/cancel`, then emit `message_cancelled`.
  * tool calling: GPU Manager has no function-calling contract; the gateway
    must prompt for structured output (`response_format: json_schema`), parse
    the tool intent, execute the tool itself, and feed results back as a new
    `llm.chat` turn. The SDK is unaffected by this choice.
* Voice messages: upload audio artifact → `speech.transcribe` → text turn.
* Realtime voice: separate gateway (see `nexa-realtime-voice.proposed.md`).

## What the SDK must never do

* Hold a GPU Manager API key, Tailscale route or admin credential.
* Call `/v1/jobs` directly or parse `JobOut` / `JobEventOut`.
* Trust a locally supplied tenant/app id as authorisation.
