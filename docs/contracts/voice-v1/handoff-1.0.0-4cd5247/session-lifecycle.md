# Voice session lifecycle (v1.0.0)

```
 SDK                                   Gateway                          LiveKit / Agent
  | POST /v1/sdk/voice/sessions ------->| reserve seconds (tenant+app)
  |                                     | create room (1 human seat) ----> room
  |                                     | dispatch agent --------------->  worker accepts, agent joins (~0.3-1 s)
  |                                     | wait <= ~5 s for the agent
  |<-- 201 {token, public key, ...} ----| (agent present)      -- or --
  |<-- 503 voice_unavailable ----------| (no agent: room deleted, reservation refunded, nothing issued)
  | join room (token, identity, mic)    |                                   agent: pipeline ready
  | RPC nexa.voice.resume(last_seq=0) ------------------------------------>  returns state + sealed events
  | <== data packets: agent_ready, session_state, transcript, ... (signed, seq-ordered) ==
  | ... conversation (barge-in: client stops playback locally and the agent confirms with `interrupted`) ...
  | network drop -> GET session -> POST .../token -> rejoin same identity -> resume(last_seq)
  | DELETE /v1/sdk/voice/sessions/{id} ->| settle seconds, refund unused, DELETE ROOM -> everyone disconnected
```

## Server-side states (`status` / `agent_state`)
`provisioning/pending` (row created; internal, the SDK normally never sees it) → `provisioning/joined` (create returned: agent seen in the room) →
`active/joined` (`status` becomes `active` on the user's join; billing starts then) → `ended/…`.
(`dispatched` exists as a value but the gateway currently records the agent as joined at the moment it observes it, before returning `201`.)
Terminal for the SDK: `status == "ended"`.

## Who ends a session, and how the client finds out
| Ender | Trigger | Client observes |
|---|---|---|
| Client | `DELETE` | HTTP 200; room deleted |
| Agent | `max_seconds` reached | events `quota_exceeded` → `session_ended` (REST stays `active` until the client `DELETE`s, or the sweep) |
| Agent | user absent past `reconnect.grace_seconds` | `session_ended{idle_timeout}` if still deliverable |
| Gateway | user never joined within `join_deadline_seconds` | disconnect/`GET`: `end_reason: join_timeout` |
| Gateway | agent vanished mid-call (30 s grace, only on positive absence) | disconnect → `GET`: `agent_lost` |
| Tenant backend | revoke subject/key, or end one call | disconnect → `GET`: `revoked` |
| LiveKit | room finished | webhook → `GET`: `room_closed` |

## Cleanup obligations (every exit path)
1. Stop capture and playback. 2. `DELETE` the voice session (ignore errors other than network; it is idempotent).
3. Disconnect the LiveKit room and dispose tracks. 4. Drop the join token and public key from memory.

## Reconnect policy (as implemented)
Same identity, new token via `POST …/token` (budget 30), user must return within `grace_seconds` (30) or the agent ends the
call. A reconnect that arrives after the call ended gets `410 voice_session_ended`.
