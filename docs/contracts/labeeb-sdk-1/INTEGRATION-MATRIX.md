# LABEEB Flutter SDK — `labeeb.sdk/1` integration matrix

Contract: `GET /v1/sdk/contract` → `labeeb.sdk/1` v1.0.0, snapshot
`contract-1.0.0.json` in this folder (refreshed 2026-10-29: adds
`assistant.profile`, read-only Jira tools, the `voice_identity` group with
`device.microphone.record_sample` and `voice.profile.*`, Jira error codes).

Evidence:

- **Production**: `packages/nexa_sdk/test/live/labeeb_live_test.dart` (5 tests)
  against `https://52.58.22.19/nexa/api` with the developer token.
- **Reference gateway**: `test/integration/labeeb_contract_integration_test.dart`
  (real sockets, scripted tool selection). Proves wire format and state
  handling, not production results.
- **Unit/widget**: `labeeb_tool_calls_test.dart` (31),
  `labeeb_record_sample_test.dart` (5), `voice_controller_test.dart`,
  `labeeb_assistant_profile_test.dart`, `labeeb_sdk_1_test.dart`.
- **Builds**: Android debug APK and iOS (no codesign) with the new `record` /
  `audioplayers` plugins (2026-10-29).

Developer token grants today (app `app_1Atzjgrw-kFLRCyF-OojKQ`): scopes
`chat:*`, `voice:session`. Missing: `tools:use`, `assets:write`. Application
capabilities granted: `textChat` only.

## IMPLEMENTED_AND_PRODUCTION_VERIFIED

| Feature |
|---|
| Contract document |
| Conversation create, session join, send, streamed reply |
| History list / open / rename / delete (then 404) |
| Preferences read |
| Assistant profile `GET /assistant` (typed; https logo and `#RRGGBB` only) |
| Live Voice session create/end (`nexa.voice.v1`, `voice_path: realtime`); tools reported `scope_missing`, call proceeds |
| Spoken turns saved (`voice-turns` 200) |
| Tool catalogue `403 forbidden` reported as unavailable |

## IMPLEMENTED_AND_DEVICE_VERIFIED (Android, Nubia NX679J)

| Feature | Evidence |
|---|---|
| Startup: `GET /assistant` 200, `GET /tools` 403 (reported), conversation + session 201, SSE 200 | Nubia log, production, 2026-10-29 |
| Live Voice media: both LiveKit peer connections ICE connected; DELETE 200 | Nubia log, 2026-10-28 |
| Spoken turns saved and shown in History | user-confirmed, 2026-10-28 |

Unit-tested, not yet seen on a device: session expiry `410` → new session on
the same conversation; voice restart after `voice.profile.activate`.

iPhone: startup verified earlier; Live Voice failed only on the 11.111.3.x
Wi-Fi (sending connection got no STUN reply on UDP 7882 / TCP 7881). Final
iPhone acceptance is a separate phase.

## CLIENT_COMPLETE_AWAITING_AUTHORIZATION

Needs token scopes `tools:use` (+ `assets:write` for uploads) and the
application capabilities `toolCalling`, `richResults`.

| Feature | Client |
|---|---|
| Tool catalogue + availability reasons | `LabeebSdkClient.tools` |
| Device-tool declaration: host on/off per tool, host priority, ≤ 8 (`client_tools` limit), only catalogue-available tools (`client_does_not_support` kept) | `LabeebToolCallController.declaredTools` |
| Client tool lifecycle: approval, deny, expiry, answer-once, 409 closed, cancel | `LabeebToolCallController` |
| Device tools: location, camera, photos, files, Maps, browser, network, share, settings, theme, microphone sample | `labeeb_device_tools.dart`, `labeeb_record_sample.dart` |
| `device.microphone.record_sample`: approval, then a consent-first sheet (nothing captured before "Start recording"), visible indicator, min/max from the arguments (5–30 / 10–60 s), Finish/Cancel, settings guidance on denial, WAV 16 kHz mono upload, `{asset_id, duration_s}`, temp file deleted, no audio logged | `LabeebRecordSampleTool` |
| Voice identity: `voice.profile.create/preview/activate/list/delete` shown generically; preview audio plays (a result `asset_id` is adopted through `GET /assets/{id}`) | `_adoptResultAsset`, `LabeebAudioAssetTile` |
| After `voice.profile.activate` during a call: DELETE, then a new session on the same `conversation_id`; `voice_identity` shown ("Speaking in your voice" / not used / switching). Host can turn it off. | `NexaVoiceController.restartForNewVoice`, `NexaVoiceIdentityNote` |
| Delete assistant data (`DELETE /me/assistant-data`) with confirmation | example Settings → Privacy |
| Theme list → select → preview → apply/cancel → preference; reset | controller + host theme callback |
| `nexa.ui/1`: all 18 components, 4 actions, ordinals by touch / chat / voice, stale handling, host renderers for extension types | `NexaUiView`, `NexaHostCapabilities.uiComponents` |
| Attachments upload / send / view / share / delete; audio assets play | composer, `LabeebAssetView` |
| Tools in voice calls (companion shows progress and rich results) | `LabeebVoiceCompanion` |
| History restore of attachments, generated files, deleted files, tool results, documents; running-job recovery | `LabeebToolCallController.restore` |
| Jira (8 read-only server tools): titles and icons by tool family, all `jira_*` errors in plain language; results through `nexa.ui/1` | generic card and renderer |

## CLIENT_COMPLETE_AWAITING_GPU

| Feature | GPU status |
|---|---|
| OCR (`gpu_not_permitted`), image edit (`gpu_not_permitted`), image generate (`gpu_capacity`) | upload, job lifecycle, progress, cancel, recovery, artifact view/share/delete and all GPU error messages complete |

## CLIENT_COMPLETE_AWAITING_PROVIDER

| Feature | Blocker |
|---|---|
| Web search (Brave) | keyless `encyclopedia_only`, labelled as reference articles |
| News | `provider_rate_limited` |
| Sports, YouTube | `requires_configuration` |
| Places | `places_api_not_enabled` when off |
| Jira | operator Atlassian OAuth app, `jira` grant, company connection, application switch |

## NOT_PUBLISHED_BY_AWS (no Flutter work without inventing)

| Item | Note |
|---|---|
| Weather tool | not in the contract |
| Jira write actions (create, transition, approve) | the contract is read-only; once they are server tools with `approval_required` and `nexa.ui/1` forms, the generic card and renderer handle them |
| `voice_identity` in the voice-session response | named in the handoff (`{applied, voice_id?, reason?}`); the contract response omits it. The SDK reads it when present. |
| Audio upload media type | uploads list image/PDF/text only; the sample is sent as `audio/wav`. A refusal goes back to the model with the gateway's code (never faked). |

## FLUTTER_INCOMPLETE

| Item | Why |
|---|---|
| Exact `nexa.ui/1` display props and search result item shapes | `docs/sdk/examples` referenced by the contract is not served; the renderer reads common names. |
| History viewer (read-only transcript) | shows text only; images and tool results appear after **Continue**. |
| Host theme picker | still the legacy local surface renderer (not `nexa.ui/1`); works, verified on device. |

## Contract gaps (for AWS)

1. `client_tools` accepts at most **8** names (9+ → 422; re-checked 2026-10-29
   with 12 client tools in the contract); not stated in the contract.
2. Conversation ids are `conv_*` on production; the contract documents `cnv_*`.
3. `docs/sdk/examples` and `docs/sdk/FLUTTER-HANDOFF.md` are not served.
4. `voice-turns` `client_turn_id` must match `[A-Za-z0-9._-]{1,64}` (`:` and
   65+ chars → 422); not stated. The SDK sends `<voice_session_id>_<n>`.
5. `voice_identity` is missing from the documented voice-session response.
6. The asset upload media types include no audio type, although
   `device.microphone.record_sample` returns an audio asset.
