# NEXA Phase 5.3B — Flutter SDK Voice Contract Alignment: Report

Date: 2026-10-24 · Branch `feature/phase5-3b-voice-contract-v1` (from `feature/phase5-2-livekit-voice` @ `b9091d7`) · not pushed.

## 1. Handoff verification
* Received as an **extracted folder** `~/Downloads/nexa-voice-handoff-1.0.0-4cd5247`, not the `.tar.gz`.
  The archive SHA-256 `58802eaa…0093b9f` therefore **could not be checked**.
* All **32/32 files match the SHA-256 values in `MANIFEST.json`**; no missing or extra files;
  `contains_secrets: false`; no JWTs or private keys found. Limitation: the manifest itself is not
  anchored by the archive hash.
* Vendored byte-for-byte to `docs/contracts/voice-v1/handoff-1.0.0-4cd5247/`; a test re-verifies the hashes.
* Backend commit `4cd524780a7de74313859f5891bd1802cbe75839`, contract `nexa.voice.v1`.

## 2. What changed
| Area | Change |
|---|---|
| `nexa_core` | `VoiceGrant` / `VoiceSessionStatus` for the v1 shape; `VoiceEventVerifier` (Ed25519 over `"nexa.voice.v1\0"+e`, pinned alg, lowercase hex, schema validation, session binding; optional legacy HMAC); `VoiceReplayGuard` (gapless seq, hold ≤256, resume repair, `covers:false`); `VoiceEventPipeline` (verify→seq→map, handshake completion, caption folding); v1 event mapping; `VoiceProvisioner` = create / refreshToken / status / end; HMAC proposal removed; dependency `pinenacl` |
| `nexa_realtime` | Topic and agent identity from the grant; `nexa.voice.resume` RPC handshake (0.3 s / 25 s) and gap repair; no client data packets; interrupt local-only; LiveKit audio-level and transcription mapping removed (signed events are the single source) |
| `nexa_sdk` | `GatewayVoiceProvisioner` for `/v1/sdk/voice/sessions…` with strict parsing; controller lifecycle: GET after any disconnect, refresh + same-identity rejoin, `end_reason` mapping (`agent_lost` → "voice unavailable", quota, `server:<reason>`), DELETE before leaving on every exit, Retry-After honoured, join-token TTL no longer ends calls (bug fixed), cap backstop; `ServerException.retryAfter`; voice decoupled from chat sessions |
| `nexa_ui` | "Voice unavailable, try again" for `voice_unavailable` / `agent_lost` (English + Iraqi Arabic); no redesign |
| Reference gateway (dev) | v1 mirror: endpoints, scopes (`voice:session` opt-in), Ed25519 sealed events, Retry-After header, 409/410/429/402/503, dev end simulation; no RPC |
| Example | Host token requests `voice:session` |
| Docs | `docs/voice/backend-compatibility-v1.md` (matrix), `docs/voice/flutter-voice-sdk.md`, ADR 0004, old proposal marked superseded, architecture + blockers + README |

## 3. Tests executed
| Suite | Result | Kind |
|---|---|---|
| format, strict analyze (packages, apps, tools) | clean, 0 issues | — |
| `nexa_core` | 82 passed | incl. **backend test vectors** (2 valid, 4 must-reject, replay results), all 10 happy-path event examples, quota-in-call sequence, schema rejections, pipeline (handshake, gap/resume, covers:false, forgery, captions, rejoin), manifest hashes |
| `nexa_sdk` | 146 passed | incl. **all 6 REST + 14 error fixtures** through the real provisioner and error mapper, 30 controller lifecycle tests (mocks), 7 real-HTTP voice tests against the reference gateway |
| `nexa_ui` / `nexa_realtime` / example / reference gateway | 55 / 3 / 1 / 34 passed | widget, guards, smoke, gateway contract mirror (live `livekit-server`) |
| Android APK build | built | — |
| iOS build | **built** for the booted simulator (active arch); `flutter build ios --simulator` (universal) fails in Flutter's framework arch check under Xcode 27 — toolchain issue, not SDK code | — |
| **Android emulator voice journey** | **passed** | real LiveKit room, mic published, agent audio track subscribed, Ed25519-signed events → states, 0 rejected, mute/unmute, DELETE 200. Against the **reference gateway's v1 mirror** with a mock agent and synthetic tone |

Classification: fixture-based contract verification = done. Live backend end-to-end = **not run**
(backend unreachable). AI inference = **none**. Physical-iPhone audio = **pending**.

## 4. Remaining blockers
1. **Live backend not verified**: no reachable gateway/agent; `resume` RPC never answered (B3).
2. **Archive-level checksum unchecked** (extracted folder supplied).
3. **Owner decisions D1–D8 unapproved** (handoff `security-assessment.md`), esp. D2, D3, D4, D7, D8 (B8).
4. **iOS audio on hardware** pending; universal simulator build fails under Xcode 27 (B9).
5. Open contract questions for the backend: `assistant_text` chunk spacing; whether local playback
   should be muted on barge-in before `interrupted` arrives.
6. Security limitations carried from the handoff: in-session replay bounded only by `seq` (R-2);
   no confidentiality from LiveKit (R-3); SDK token revocation does not end a live call (R-4).
