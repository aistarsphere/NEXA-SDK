# Engineering assumptions and blockers

Updated 2026-10-24 (end of Phase 5.3B). Resolve or re-confirm each item before the next phase.

## Assumptions made so far

| # | Assumption | Where it lives | How to revisit |
|---|---|---|---|
| A1 | The interactive prototype and Design QA 3.1 artefacts were **not available** in this environment. Colour tokens were derived from the written contract (Coffee & Mocha, M3). | `packages/nexa_ui/lib/src/theme/mocha_palette.dart` | Export tokens from the prototype and replace the palette file; contrast tests will catch regressions. |
| A2 | Gateway event delivery is SSE (`GET /events/stream`) with long-polling as fallback, both with a `sequence` cursor. The reference gateway implements both. | `GatewayChatTransport`, `NexaConfig.eventDelivery`, contract 0.2.0 | Backend confirms which it will ship; the SDK keeps both. |
| A3 | Session credentials are minted by the host's backend and are opaque bearer tokens with an expiry. No refresh-token flow on device. The reference gateway's `/v1/dev/session-tokens` stands in for the host backend. | `NexaAuthProvider`, `CredentialManager`, `HostAuthProvider` | Confirm token format/TTL with backend security review. |
| A4 | Tool execution is server-side; the SDK only renders results and returns actions; the gateway re-validates. | `ToolResult`/`ToolAction`, reference `POST /tool-actions` | Backend to confirm it never trusts client-side action payloads. |
| A5 | Text deltas may be coarse (GPU Manager exposes no documented token stream for `llm.chat`). The reference gateway streams word-sized deltas. | reducer handles both | Backend to confirm partial text in `JobEventOut.data`. |
| A6 | Supported UI languages are exactly `en` and `ar`. | `NexaConfig.supportedLanguageTags`, ARB files | Add ARB + enum entry when more are approved. |
| A7 | Map and media results render as static summaries (no map SDK or media player approved). | `_RouteBody`, `_MediaBody` | Pick providers; add widgets behind the same `ToolResult` types. |
| A8 | `freezed 3.2.6-dev.1` is acceptable because stable 3.2.5 cannot resolve with analyzer 12 required by retrofit/injectable generators. | root lockfile | Move to freezed 3.2.6 stable when published. |
| A9 | Automatic reconnect: 5 attempts, exponential back-off from `eventPollInterval` (750 ms) capped at 15 s; auth/expiry/quota are never auto-retried. | `ChatBloc`, `NexaConfig.maxReconnectAttempts` | Tune with product once real network data exists. |
| A10 | A gateway that answers `409 assistant_busy` is a contract violation the SDK never triggers (client-side `canSend` guard). | `ChatState.canSend` | Keep the server rule as backstop. |
| A11 | Voice follows the backend-owned contract `nexa.voice.v1` (handoff 1.0.0, backend commit `4cd5247`), vendored in `docs/contracts/voice-v1/`. The SDK-side proposal is superseded. | `GatewayVoiceProvisioner`, `VoiceEventVerifier`, `VoiceEventPipeline` | Re-vendor and rerun consumer tests on every new handoff version. |
| A12 | After a disconnect the SDK always asks `GET` first, then refreshes the join token and rejoins (contract §8). | `NexaVoiceController._recover` | Confirm against the real agent's grace window. |
| A13 | Speaking/transcript state comes only from signed agent events (no client VAD, no LiveKit audio-level mapping), so the two cannot disagree. `assistant_text` chunks are concatenated in `index` order without a separator. | `VoiceEventPipeline` | Backend to confirm chunk spacing. |

## Blockers (cannot be closed by the SDK team alone)

| # | Blocker | Impact | Owner |
|---|---|---|---|
| B1 | ~~No NEXA gateway exists.~~ **Partly closed 2026-10-27:** real gateway `https://52.58.22.19/nexa/api` (test app `app_wsyCTDpZNf2yfwbROBcPqQ`) reached from the Mac; voice create `201`, LiveKit `wss://52.58.22.19/nexa/livekit` joined, agent joined, Ed25519 events verified (0 rejected), `resume` RPC answered. Chat against the real backend not exercised. | No production claim; no completed real conversation yet. | Backend |
| B2 | **No customer host backend.** SDK tokens are minted server-side with the tenant API key (`POST /v1/server/session-tokens`, not public). Until a host backend exists, the example uses the development-only `DevTokenAuthProvider` (token pasted at runtime, memory only; no refresh: a fresh token must be pasted when it expires). | Automatic token refresh untested against the real issuer. | Customer host / Backend |
| B3 | **Live backend partly verified (see B1).** Remaining: The SDK is aligned to handoff 1.0.0 and passes all 23 fixtures + verification vectors, but has never talked to the real gateway or agent; the `nexa.voice.resume` RPC has never been answered (reference gateway cannot serve RPCs). Handoff received as an extracted folder: per-file SHA-256s match `MANIFEST.json`, the archive-level SHA-256 `58802eaa…` could not be checked. | No backend end-to-end claim. | Backend (staging URL or reachable host) |
| B8 | **Owner decisions D1–D8 (handoff `security-assessment.md`) unapproved**, notably D2 (Ed25519 as contract, HMAC removal date), D3 (end users need data-publish for the RPC), D4 (LiveKit hosting: transcripts and key seeds visible to LiveKit), D7 (voice without chat), D8 (billing start). | SDK follows backend defaults. | Product / Security / Legal |
| B9 | **iOS audio path unverified on hardware.** iOS app builds (active-arch simulator build); the simulator's CoreAudio aborts when WebRTC starts; `flutter build ios --simulator` (universal arm64+x86_64) fails in Flutter's framework arch check under Xcode 27 (toolchain issue). Physical-iPhone validation pending. | No iOS audio claim. | SDK + QA |
| B10 | **ICE prefers the backend's NetBird address.** LiveKit advertises a private NetBird IPv6 host candidate (`fdbc:be4b:46f7:a389::/64`). A client that is itself on NetBird (the dev Mac, `utun20`) switches from the working public pair (`srflx → 52.58.22.19:7882/udp`, DTLS complete) to the NetBird pair, which stopped carrying media after ~19 s (ICE `disconnected` → `failed`). Public clients should never be offered the private address. SDK mitigation: server-reported `poor`/`lost` media quality now shows *weak network* instead of *listening*. | Real conversation from NetBird-connected machines unreliable. | Backend (LiveKit ICE interface/IP filtering) |
| B11 | **Real Arabic conversation PASSED on a physical Android phone (2026-10-27, NX679J, Android 13, Wi-Fi, no NetBird).** Session `vs_MeTpIQqi7O1QKBAmSOTVJA`: create 201 in 1.7 s, WebRTC connected in ~4.6 s, ~62 s recorded mic (no all-zero frames), ~64 s agent playout, at least 5 user turns with Arabic transcripts and spoken Arabic replies, events verified (0 rejected), user End → DELETE 200. Still open: barge-in (speaking over the assistant) was not observed; backend STT produced classic Whisper hallucinations on noise/silence ("ترجمة نانسي قنقر", repeated "جزيلا") — backend item; iPhone hardware untested. | Interruption + iPhone unverified. | Owner + Backend |
| B4 | **Prototype export missing.** Tokens, motion specs and component states are reconstructed from the written contract. | Visual fidelity unverified against QA 3.1. | Design |
| B5 | **Accessibility validation incomplete.** Automated baseline (contrast, semantics labels, live-region announcements, tap targets) exists; screen-reader and dynamic-type passes on devices are not done. | A11y certification pending. | Design + QA |
| B6 | No CI definition in this repository. `tool/check.sh` is the intended CI entry point; `tool/e2e.sh` needs a simulator. | Quality gates are manual. | Platform |
| B7 | Android: the example was built (`apk --debug`) but the e2e journey was executed on the iOS simulator only this session. | Android runtime behaviour verified by build + unit/widget tests, not by the on-device journey. | SDK |

| B12 | **Production assistant UI (2026-10-27).** `apps/nexa_example` is now the NEXA assistant (chat home, live voice, settings) built to the Claude Design project (tokens v2.2, Assistant Phone, SDK Screens L1); developer tools are compiled in only with `devTools` (debug or `NEXA_DEV_TOOLS`), verified absent from a release binary. Not available because the backend has no API for them: conversation history/list, transcript of a voice call saved into the chat, audio-route switching, message feedback/regenerate. A production build has no token source until a customer host backend implements `NexaAuthProvider`. | History and production sign-in pending. | Backend + host |

## Explicit non-claims

* Not production ready. * Real backend: session API, LiveKit join, agent join and signed events verified; one real Arabic voice conversation completed on a physical Android phone (B11); barge-in and iPhone not yet verified. * Reference-gateway runs: real LiveKit networking, mock agent, synthetic audio, no model inference.
* The reference gateway is development infrastructure: no model, no GPU Manager, no persistence, no multi-tenant security.
* Mocks are labelled `MockChatTransport` / `MockRealtimeVoiceTransport` / `MockAuthProvider` and live in `package:nexa_core/testing.dart`.

## Phase QA-1: real-device session diagnostics (2026-10-27)

Development builds record one JSONL record per chat session / voice call
(`apps/nexa_example/lib/dev/qa/`, CLI `apps/nexa_example/tool/qa.dart`), via the new SDK sink
`NexaOverrides.diagnostics` (`NexaDiagnostics`, no-op by default). Verified locally by
`test/qa_recorder_test.dart` (mock transports): index + records written, no token / join token /
message text on disk. Not yet run against the real backend on the phone. Not measurable from
Flutter: STT/LLM/TTS stage durations (agent events carry only `mono_ms`), backend queue/model
time for chat, agent VAD decision time.

## B13: client tools, multimodal, places, history (2026-10-28)

Flutter side implemented and unit/widget-tested (core 91, device 9, SDK 154, app 13 tests):
client tool registry (`nexa.client_tool.v1`; allow-list, schema validation, user approval,
structured errors), `device.location.get_current`, `device.camera.capture` (preview → capture →
Retake/Use/Cancel, no audio so a voice call continues), photo library, image viewer + share,
"ask about this image" reference, `maps.open_directions` (validated Google Maps `api=1` URL,
native app then browser), `nexa.places.v1` places cards with ordinals, local history cache with
rename/delete/clear and an itemised "Clear all" report. **Backend-dependent and therefore not
connected:** client-tool call/result transport, attachment upload, assistant images, places
search, message `context`, server history/resume/rename, server deletion — contract in
`docs/contracts/nexa-client-tools.proposed.md`. iOS fix in the same period: every voice call
after the first was silent (voice-processing mute set at call end survived into the next call);
fixed by not muting at call end and using LiveKit's `inputMixer` mute mode; verified on an
iPhone 15 (second and third calls heard the user).
