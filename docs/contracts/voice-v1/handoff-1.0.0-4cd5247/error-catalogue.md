# Voice error catalogue (v1.0.0)

Envelope: `{"error": {"code", "message", "retryable", ["retry_after_seconds"], ["quota_kind"]}}` + HTTP `Retry-After`
when `retry_after_seconds` is present. Switch on `code`; `message` is developer text. "Fixture" = a file in `fixtures/errors/`
generated from real behaviour; "code-derived" = read from the source, not yet exercised by a fixture.

| HTTP | `code` | Where | retryable | Extra | Cause → what the SDK should do | Evidence |
|---|---|---|---|---|---|---|
| 400 | `bad_request` | all | no | | header `X-Nexa-App-Id` missing → SDK bug | fixture `missing_app_id.400` |
| 400 | `missing_sdk_version` | all | no | | header `X-Nexa-Sdk-Version` missing → SDK bug | fixture `missing_sdk_version.400` |
| 401 | `missing_token` | all | no | | no bearer token → ask host app for a session token | fixture `missing_credential.401` |
| 401 | `invalid_token` | all | no | | unknown/revoked token → `authenticationFailed`; re-authenticate via host app | fixture `invalid_credential.401` |
| 401 | `token_expired` | all | **yes** | | SDK session token expired → fetch a new token from the tenant backend, retry once | fixture `expired_credential.401` |
| 402 | `quota_exceeded` | create | no | `quota_kind:"voice_seconds"` | monthly voice seconds exhausted (tenant or app). Nothing was created → `quotaExceeded` | fixture `quota_exceeded_on_create.402` |
| 403 | `forbidden` | all | no | | token lacks scope `voice:session`, or tenant/app inactive → `permissionDenied` | fixture `missing_scope.403` (tenant/app inactive: code-derived) |
| 403 | `application_mismatch` | all | no | | token was issued for another application → SDK/host misconfiguration | code-derived |
| 403 | `capability_not_granted` | create | no | `quota_kind:"liveVoice"` (the capability name is carried in this field) | application has no voice capability/profile → `capabilityNotGranted` | fixture `capability_not_granted.403` |
| 404 | `voice_session_not_found` | get/token/delete | no | | unknown id **or another user's/tenant's** (indistinguishable by design) | fixture `foreign_session.404` |
| 404 | `session_not_found` | create | no | | `chat_session_id` is not the caller's | code-derived |
| 409 | `voice_session_active` | create | no | | this user already has a live voice session → `GET`/`DELETE` the old one (id is not in this error) or wait for it to end | fixture `session_already_active.409` |
| 410 | `voice_session_ended` | token | no | message names the `end_reason` | session is over → stop; do **not** refresh again | fixture `refresh_after_end.410` |
| 413 | `payload_too_large` | all | no | | body over the gateway limit → SDK bug | code-derived |
| 422 | `validation_failed` | create | no | message lists field names | e.g. `language_tag` not `en`/`ar` | fixture `invalid_language.422` |
| 429 | `rate_limited` | create | **yes** | `retry_after_seconds` | per-user creation rate (6/min default) or too many concurrent voice sessions for the app (message "Too many concurrent voice sessions.", retry 30 s) → wait `Retry-After` | code-derived |
| 429 | `rate_limited` | token | **no** | | refresh budget (`reconnect.max_refreshes`, 30) used up → treat as ended; start a new session | fixture `refresh_limit.429` |
| 500 | `internal_error` | all | yes | | unexpected server error → bounded retry with backoff | code-derived |
| 503 | `voice_unavailable` | create | **yes** | `retry_after_seconds: 5` | **no voice capacity / no agent could join** (this is the `agent_unavailable` outcome at creation). Quota refunded, nothing issued | fixture `voice_unavailable_no_capacity.503` |
| 503 | `voice_unavailable` | create/token/webhook | **yes** | `retry_after_seconds: 10`, message "Realtime voice is not available." | voice disabled, LiveKit unreachable, provisioning failure, or failed production posture check | code-derived |

## Which signal means what (create path)
| What the user sees | Backend signal |
|---|---|
| "Try again in a moment" | `503 voice_unavailable`, `Retry-After` header present |
| Out of minutes | `402 quota_exceeded` + `quota_kind:"voice_seconds"` |
| Feature not enabled | `403 capability_not_granted` |
| Connected, but the agent vanished | LiveKit disconnect, then `GET` → `status:"ended"`, `agent_state:"unavailable"`, `end_reason:"agent_lost"` (billed until loss) |
| Agent never arrived | only at creation: `503 voice_unavailable` (nothing billed). `end_reason:"agent_unavailable"` exists server-side but is not visible to the SDK |
| Call over, over the time limit | event `quota_exceeded` → `session_ended` → client `DELETE` |

## Mapping to the SDK's `NexaErrorCode` (existing enum on SDK `main`)
`token_expired`→`sessionExpired`; `invalid_token`/`missing_token`→`authenticationFailed`; `quota_exceeded`→`quotaExceeded`;
`capability_not_granted`→`capabilityNotGranted`; `forbidden`/`application_mismatch`→`permissionDenied`;
`rate_limited`→`rateLimited`; `voice_unavailable`/`internal_error`→`server` (retryable); `voice_session_ended`→ end the machine
(`VoiceDisconnected(willReconnect:false)`); `validation_failed`/`bad_request`/`missing_sdk_version`→`contractViolation`.
This table is a recommendation, not backend behaviour.
