# NEXA client tools, attachments, places, history and deletion — proposed backend contract

Status: **proposed by the Flutter SDK** (2026-10-28). Nothing here exists on the backend yet;
the SDK implements its side and keeps every server step disabled or marked "not sent"
until AWS ships the matching endpoint/event. Contract ids: `nexa.client_tool.v1`,
`nexa.places.v1`. All paths are under the existing gateway base (`…/nexa/api`), same
auth (`Authorization: Bearer <SDK session token>`), same `X-Request-Id` handling and error
envelope (`{"error": {"code", "message", "retryable"}}`) as `/v1/sdk/sessions`.

Flutter code: `packages/nexa_core/lib/src/client_tools/`, `…/conversation/conversation_items.dart`,
`…/places/places.dart`, `packages/nexa_device/`, `packages/nexa_sdk/lib/src/features/{media,history}/`.

## 0a. Installation id (correlation only)

Every request carries `X-Nexa-Installation-Id: ins_<22 base64url chars>` (128 random bits,
generated once per app install, stored app-privately). It is **not** authentication and
not a device fingerprint; auth stays the SDK session token. Use it for rate limiting,
diagnostics and, later, account linking (the host links an installation to its own user
after its own sign-in; the SDK implements no login).

## 0. Capabilities

Session create (`POST /v1/sdk/sessions`) must grant, per tenant policy:

| capability | gates |
|---|---|
| `toolCalling` | any assistant-initiated client tool call (§1). User-initiated runs never need it. |
| `attachments` | image upload (§2) and image references in messages (§4) |
| `liveVoice` | already used; also allows §1 events on the voice data channel |

Note: today the gateway reports `liveVoice` as *not granted* while voice works. Please fix
the grant list so the SDK can rely on it.

## 1. Client tool calls (assistant → device → assistant)

Client tools run on the phone; server tools (`places.search_nearby`, …) stay on AWS.

### 1.1 Request event (SSE `events/stream` and, during a call, the LiveKit `events.topic`)

```json
{
  "type": "client_tool_call",
  "sequence": 42,
  "occurred_at": "2026-10-28T10:00:00Z",
  "payload": {
    "contract": "nexa.client_tool.v1",
    "call_id": "ctc_8f2…",                 // unique, ≤ 64 chars
    "tool_id": "device.location.get_current",
    "tool_version": 1,
    "arguments": { "accuracy": "high", "timeout_ms": 15000, "reason": "find restaurants nearby" },
    "session_id": "ses_…",
    "voice_session_id": "vs_…",            // when raised during a call
    "expires_at": "2026-10-28T10:01:00Z"   // the device drops expired calls
  }
}
```

Registered tools (only these run; anything else returns `unknown_tool`, nothing executes):

| tool_id | v | arguments | success `output` |
|---|---|---|---|
| `device.location.get_current` | 1 | `accuracy?: high\|balanced`, `timeout_ms?: 1000..30000`, `reason?` | `latitude`, `longitude`, `accuracy_m`, `timestamp` (ISO-8601 UTC), `altitude_m?`, `is_mocked` — **no address** |
| `device.camera.capture` | 1 | `reason?`, `facing?: back` | `attachment` = attachment metadata (§2.3); bytes are uploaded separately |
| `maps.open_directions` | 1 | `place_id?`, `name?`, `latitude?`, `longitude?`, `travel_mode?: driving\|walking\|bicycling\|transit` (needs coordinates, or place_id + name) | `url`, `opened_in: app\|browser` |

| `device.network.get_status` | 1 | — | `connected`, `types[]` (wifi/mobile/ethernet/vpn/…; interfaces, not reachability) · no approval |
| `device.wifi.get_current_info` | 1 | — | `on_wifi`, `ssid_available`, `ssid?`, `ssid_unavailable_reason?` (`not_on_wifi`/`permission_denied`/`not_permitted_by_os`) · never passwords |
| `device.browser.open_url` | 1 | `url` (https, no credentials, optional host allowlist), `title?` | `url`, `opened` |
| `device.app.open` | 1 | `app_id` ∈ the app's allowlist (advertised schema `enum`) | `app_id`, `opened_in: app\|browser` |
| `device.apps.query_supported` | 1 | — | `apps[{app_id,name,installed: yes\|no\|unknown\|unsupported,web_fallback}]`, `background_apps: "not_available_on_this_os"` · no approval |
| `device.share.open` | 1 | `text?`, `url?`, `attachment_id?` | `status: shared` (dismissed → `cancelled`) |
| `device.files.pick` | 1 | `reason?` | `attachment` (§2.3); errors `file_too_large`, `file_type_unsupported` |
| `device.settings.open` | 1 | `target?: app\|location` (iOS: always the app page) | `opened`, `target` |

### 1.0 Advertising

`POST /v1/sdk/sessions` gains `client_tools`: the descriptors of the tools this app
installation can run **now** (enabled by the host, supported on this platform, not
unavailable), each with `id`, `version`, `title`, `input_schema`, `output_schema`,
`required_permissions`, `requires_approval`, `platforms`, `timeout_ms`, `sensitivity`,
`availability`. The orchestrator must only call advertised tools. The SDK sends this field
(and message `context`, and results) only with `NexaConfig.clientToolProtocol` on — today
for the reference gateway only.

Every run is approved by the user on the device; the user can decline.

### 1.2 Result (new endpoint)

`POST /v1/sdk/sessions/{session_id}/client-tool-results` → `202 {"accepted": true}`

```json
{
  "contract": "nexa.client_tool.v1",
  "call_id": "ctc_8f2…",
  "tool_id": "device.location.get_current",
  "tool_version": 1,
  "status": "succeeded" | "failed" | "cancelled",
  "output": { … },                                         // when succeeded
  "error": { "code": "permission_denied", "message": "…",  // when failed/cancelled
             "retryable": true, "can_open_settings": false },
  "completed_at": "2026-10-28T10:00:07Z"
}
```

Error codes: `unknown_tool`, `unsupported_version`, `invalid_arguments`, `disabled_by_host`,
`not_granted`, `user_declined`, `permission_denied`, `permission_blocked`, `service_disabled`,
`unsupported`, `timeout`, `cancelled`, `expired`, `device_error`, `file_too_large`,
`file_type_unsupported`.

Wire event as implemented by the SDK and the reference gateway:
`{"type": "client_tool_call", "event_id", "session_id", "sequence", "occurred_at", "call": {…§1.1 payload}}`;
places: `{"type": "server_tool_result", …, "result": {…§3}}`.

Server rules: accept each `call_id` once (409 on repeat), reject unknown `call_id`
(404), 410 after `expires_at`. The model must treat `user_declined`/`cancelled` as a
user choice, not an error to retry.

## 2. Attachments (images now, files later)

### 2.1 Upload — `POST /v1/sdk/sessions/{session_id}/attachments`

`multipart/form-data`: `file` (image/jpeg|png|heic|webp, ≤ 10 MB), `metadata` (JSON, §2.3
without `asset_id`). → `201 {"asset_id": "ast_…", "expires_at": "…", "mime_type": "image/jpeg",
"width": 3024, "height": 4032}`. Errors: `413 too_large`, `415 unsupported_type`,
`403 capability_not_granted`.

### 2.2 Delete — `DELETE /v1/sdk/sessions/{session_id}/attachments/{asset_id}` → `204`.

### 2.3 Attachment metadata (what the SDK sends/expects — no device paths, no bytes)

```json
{ "attachment_id": "att_…", "asset_id": "ast_…", "kind": "image", "origin": "uploaded|captured|generated|edited",
  "mime_type": "image/jpeg", "byte_length": 812345, "width": 3024, "height": 4032,
  "edit_of": "ast_…", "tool_call_id": "ctc_…", "created_at": "…" }
```

### 2.4 Assistant-produced images (generation / editing)

New event `assistant_attachment` on the stream:
`{"type": "assistant_attachment", "payload": {"message_id": "msg_…", "attachment": {…§2.3, "origin": "generated"|"edited", "url": "https://… (signed, short-lived)"}}}`.
Progress: `attachment_progress {asset_id, progress: 0..1}`; failure: `attachment_failed {asset_id, error}`.

## 3. Places (server tool `places.search_nearby`)

The provider (e.g. Google Places) and its key live on AWS only. The backend gets the
device location through §1 (`device.location.get_current`) and then emits:

New event `server_tool_result` (also `server_tool_started` with `status: "loading"` first):

```json
{
  "type": "server_tool_result",
  "payload": {
    "contract": "nexa.places.v1",
    "result_id": "pr_…",
    "tool": "places.search_nearby",
    "status": "loading" | "ok" | "zero_results" | "location_denied" | "error",
    "query": "Restaurants nearby",
    "origin": { "lat": 33.3152, "lng": 44.3661 },
    "places": [
      { "place_id": "ChIJ…", "name": "…", "category": "Restaurant",
        "rating": 4.5, "user_rating_count": 812, "distance_m": 350,
        "location": { "lat": 33.31, "lng": 44.36 },
        "address": "…", "open_now": true }
    ],
    "attribution": "Google",            // shown under the results
    "error": { "code": "provider_unavailable", "retryable": true }
  }
}
```

Required per place: `place_id`, `name`, `location.lat/lng`. Invalid places are skipped by
the SDK (never patched). `address` only from the provider. A later event with the same
`result_id` replaces the earlier one (loading → ok).

## 4. Message context (follow-ups like "take me to the second restaurant")

Extend `POST /v1/sdk/sessions/{id}/messages` with an optional `context`:

```json
{ "client_message_id": "…", "text": "Take me to the second one", "language_tag": "ar",
  "context": {
    "places": { "result_id": "pr_…", "places": [ {"ordinal": 1, "place_id": "ChIJ…", "name": "…"}, {"ordinal": 2, …} ] },
    "attachments": [ { "asset_id": "ast_…", "role": "reference" } ]
  } }
```

The model resolves the ordinal and answers with a `client_tool_call` for
`maps.open_directions` carrying that `place_id`. The SDK keeps the ordinals of the latest
result (`NexaConversationMedia.placesContext`); image references come from "Ask about this
image".

## 5. Shared Chat/Voice conversation

* §1 calls raised while a voice call is active arrive on the voice data channel with
  `voice_session_id`; results go to the same endpoint (§1.2).
* Voice turns should be written into the chat session's history (`chat_session_id` is
  already sent on voice create) as `voice_transcript` items: `{voice_session_id, turn_id,
  speaker, text, final: true}`, so history (§6) shows one conversation.

## 6. History

| endpoint | purpose |
|---|---|
| `GET /v1/sdk/conversations?cursor=&limit=&q=` | list: `[{session_id, title, kind: chat\|voice\|mixed, started_at, updated_at, message_count}]`, `next_cursor` |
| `GET /v1/sdk/conversations/{session_id}/events?after=0` | full replay for read-only view |
| `POST /v1/sdk/conversations/{session_id}/resume` | new live session continuing the conversation → `SessionHandle` |
| `PATCH /v1/sdk/conversations/{session_id}` `{title}` | rename |

## 7. Deletion

| endpoint | result |
|---|---|
| `DELETE /v1/sdk/conversations/{session_id}` | `200 {"deleted": ["messages","attachments","voice_transcripts","voice_recordings"], "retained": [{"kind": "audit_log", "until": "…", "reason": "…"}]}` |
| `POST /v1/sdk/user-data/deletion` `{"scope": "all_chats"\|"all_voice"\|"assets"\|"everything"}` (async) | `202 {"deletion_id": "del_…", "state": "requested"}` |
| `GET /v1/sdk/user-data/deletion/{deletion_id}` | `{"state": "requested\|running\|completed\|partial\|failed", "failed_items": 2, "retryable": true, "categories": {"conversations": "deleted", "assets": "deleted", "voice": "deleted", "retention": "retained_by_policy"}}` |
| `POST /v1/sdk/user-data/deletion/{deletion_id}/retry` | retries failed items of a `partial`/`failed` request |

The SDK reports each category separately and **never** claims server deletion without a
`deleted` confirmation. Today all server rows show "Not deleted: the server has no
deletion API yet"; local data (history cache, captured images, host data) is deleted on
the device.

## 8. History ownership

The service is the system of record. The SDK keeps only a bounded UI cache (≤ 50
conversations, ≤ 100 messages each) for fast/offline rendering, labels it as a cache when
the service has no history API, and sends only the conversation id and the new input on
each turn (`POST /v1/sdk/sessions/{id}/messages`) — never the full history.
