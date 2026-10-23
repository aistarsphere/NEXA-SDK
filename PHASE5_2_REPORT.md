# NEXA Phase 5.2 — Flutter LiveKit Voice Client: Implementation Report

Date: 2026-10-23 · Branch: `feature/phase5-2-livekit-voice` (based on `main` @ Phase 4.1) · Toolchain: Flutter 3.44.4, Dart 3.12.2, livekit_client 2.13.1 (flutter_webrtc 1.6.2), livekit-server 1.13.10 + `lk` 2.19.2 (Homebrew), Xcode 27 / iPhone 17 Pro Max simulator, Android emulator API 36.

## 1. Read this first: what could not be done as briefed

The brief names the backend at `/home/ubuntu/nexa-integration` (branch
`integration/phase4-3-phase5-voice`, commit `1b8f848`) and its
`docs/voice/security-review.md` as the source of truth. **That repository
was not reachable** from this environment: not on this machine, not on any
configured ssh host (`aws-gpu`, `c1`/`devuser`), not on GitHub under
`aistarsphere`, and nothing new on the SDK remote. Consequently:

* The real provisioning endpoint, grant fields, signed-event rules, agent
  lifecycle events and quota/termination semantics were **not read** and
  are **not implemented as the backend's**. The SDK implements a
  **PROPOSED** contract (`docs/contracts/nexa-voice-provisioning.proposed.md`),
  served by the reference gateway, with every wire mapping isolated in
  `GatewayVoiceProvisioner._parseGrant` and `SignedVoiceEvent` /
  `VoiceEventVerifier` for later realignment.
* "Backend contract tests" in this phase mean SDK ↔ reference-gateway
  tests, not tests against `nexa-integration`.
* The backend repository was not modified (it was never available).

Everything else in the brief was implemented and exercised against a real
LiveKit server.

## 2. Status vocabulary

| Term | Meaning here |
|---|---|
| **Real** | Actual LiveKit/WebRTC behaviour on a device/simulator against local `livekit-server --dev` |
| **Mock agent** | Reference gateway script: signed events via LiveKit server data API + synthetic tone published with `lk`. No model, no speech |
| **Proposed** | SDK-side contract pending backend confirmation |
| **Not verified** | Needs the unreachable backend, a physical device, or human review |

## 3. What was built

### LiveKit integration (`packages/nexa_realtime`, new)
`LiveKitVoiceTransport` implements the redesigned `RealtimeVoiceTransport`:
room connect with a room-scoped participant JWT, microphone publish /
enable-disable (mute), remote audio playback by the engine, engine
reconnect reporting, connection-quality mapping, active-speaker → user /
assistant speaking events, LiveKit transcriptions, signed data packets on
topic `nexa.voice` → `VoiceEventVerifier` → verified events only,
`interrupt` intent as a data packet, cleanup (`disconnect`, `dispose`).
`LiveKitAudioSetup` isolates platform audio options (echo cancellation,
noise suppression, speaker). No second realtime engine.

### Core contracts (`nexa_core`)
`VoiceGrant` (redacting `toString`), `VoiceProvisioner`, `SignedVoiceEvent`
+ `VoiceEventVerifier` (HMAC-SHA256, session binding, strictly increasing
sequence, ±2 min skew, constant-time compare), `realtimeEventFromSigned`,
`VoiceTranscriptEntry`, extended `RealtimeVoiceEvent` family
(agent joined/left, agent audio track, speaking started/ended, assistant
transcript, model available, session ending, event rejected). The PCM
WebSocket proposal was withdrawn. `VoiceSessionMachine` is **unchanged**.
Mocks: `MockRealtimeVoiceTransport` (rewritten), `MockVoiceProvisioner`.

### Public API (`nexa_sdk`)
`NexaClient.voice` → `NexaVoiceController` (`start`, `end`, `setMuted`,
`toggleMute`, `interrupt`, `state: ValueListenable<NexaVoiceState>`,
`events: Stream<NexaVoiceEvent>`, `microphoneEnabled`, `currentGrant`);
`NexaClient.voiceView(showTranscript, autoStart, onEnded, onOpenSettings)`;
`Nexa.initialize(voiceOptions: NexaVoiceOptions(startMuted, keepTranscript,
maxTranscriptEntries, allowUnverifiedEvents))`;
`NexaOverrides.voiceTransport / voiceProvisioner`. Chat initialisation and
authentication are untouched; `NexaConfig` has no new secret-bearing field.
`GatewayVoiceProvisioner` talks to the proposed paths over the existing
authenticated Dio (credential renewal applies).

### State machine mapping
All 16 `VoiceState`s are reachable from real events (table in
`docs/voice/flutter-voice-sdk.md`). The machine remains the single source
of the displayed phase; `muted` is a phase, so "muted + speaking" cannot
render. Invalid, duplicate, stale and wrongly signed packets are rejected
before mapping and counted (`rejectedEvents`, `NexaVoiceEventRejected`).

### Voice event security
Per-session HMAC key delivered in the grant (proposed). Threat model and
limitations documented (contract doc §4): the key proves holder-of-key, not
agent identity to third parties, and never authorises client actions; the
gateway stays authoritative (intents are also posted over HTTP).
Development mode without a key is visible in the UI and can be forbidden
(`allowUnverifiedEvents: false` → `ContractViolationException`). No
validation was weakened for tests.

### Live Voice Capsule (`nexa_ui`)
`NexaVoiceCapsule`: Mocha tokens only; orb colour/ring per state, pulses
only while speaking/connecting (static under reduced motion); live-region
state label; waiting-for-agent hint; transcript bubbles (partial italic);
mute + end controls with semantics tooltips; error banner with
"Open settings" (microphone denied) or "Try again"; unsigned-events
banner; 32 new en/ar strings; RTL via directional widgets.

### Reference gateway (dev infrastructure)
`POST/DELETE /v1/sdk/sessions/{id}/voice`, `POST …/voice/intents`;
room-scoped participant JWT minting (dev key/secret server-side only; no
`roomAdmin`/`roomCreate` for devices — asserted by test); per-application
voice quota (402); `liveVoice` granted only when LiveKit is configured;
mock agent starts only after the SDK participant is observed via
`ListParticipants`; signed events via Twirp `SendData`; optional synthetic
audio via `lk room join --publish assets/agent_tone.ogg`;
`--livekit-public-url` for emulators.

### Example host app
`/voice` route embeds `voiceView()` under a host app bar with an event log
and a mode banner (mock vs reference gateway + LiveKit); `HostPermissionHandler`
via `permission_handler` 12 with "Open settings"; iOS
`NSMicrophoneUsageDescription` + background audio; Android `RECORD_AUDIO`,
`MODIFY_AUDIO_SETTINGS`, `BLUETOOTH_CONNECT`, cleartext (example only).
The SDK never pushes routes for voice.

## 4. Tests executed

| Suite | Result |
|---|---|
| `dart format` (sources), `flutter analyze packages apps tools` (strict) | clean, 0 issues |
| `nexa_core` | 71 passed (+13 verifier/mapping/grant) |
| `nexa_reference_gateway` | 32 passed (+8 voice: grant scope, 403/409/402/404, intents, cross-app, signer canonical) — run against a live `livekit-server --dev` |
| `nexa_ui` | 53 passed (+8 capsule: controls, all states en+ar, mute gating, error actions, unverified banner, RTL transcript, reduced motion, semantics) |
| `nexa_realtime` | 3 passed (expired-grant guard, no-room guards, audio options) |
| `nexa_sdk` | 115 passed, 1 skipped by design (+24 controller: permission denied, capability, 402, connect failure, unsigned policy, startMuted, scripted turn, agent presence/audio, barge-in, busy, rejected events, mute, reconnect, final drop, quota event, expiry, session_ending, end/restart, idle no-ops, dispose; +6 provisioner wire mapping and error mapping; +3 voice view: journey, ar+dark, autoStart; +4 real-HTTP provisioning vs reference gateway incl. credential renewal and signer↔verifier compatibility) |
| `apps/nexa_example` | 1 passed (mock) |
| `flutter build apk --debug` | built (with WebRTC) |
| iOS build | built by the simulator journey |
| **Voice journey, Android emulator** (`tool/e2e.sh emulator-5554 integration_test/voice_journey_test.dart`) | **passed**: real room join → mic track published → mock agent observed the participant and joined → remote agent audio track subscribed → signed `assistant_speaking_started` / transcript reached the capsule with 0 rejected packets → mute (track disabled) → unmute → end (`DELETE …/voice` 204) |
| **Voice journey, iOS simulator** | **did not complete** (CoreAudio abort after a successful room join; see §5) |
| Chat journey (Phase 4.1) on iOS simulator | unchanged, not rerun this phase |

Tests against the mock agent are reported as mock-model tests, never as AI
inference tests.

## 5. Platform audio findings

* **Android emulator: full path verified** (capture + publish + remote
  playback track + mute).
* **iOS simulator (Xcode 27, iOS 26.2 runtime): the process aborts in
  CoreAudio as soon as the WebRTC audio unit starts**, with and without the
  microphone (`coreaudio SetProperty: RPC timeout. Apparently deadlocked.
  Aborting now.` in the simulator log, reproduced in three runs; the muted
  variant is selected automatically via `SIMULATOR_UDID`). What the iOS
  runs do prove: the iOS build with LiveKit, host token mint, session,
  voice provisioning (201) and the **real room join** (the gateway observed
  the SDK participant and started the agent) before the abort. What they
  do not prove on iOS: remote audio playback, signed-event delivery,
  mute/unmute, end. These need a **physical iPhone** (none attached in
  developer mode this session); the same journey test runs unchanged there
  (`tool/e2e.sh <device-id> integration_test/voice_journey_test.dart`).
* No physical device, Bluetooth or earpiece routing test was possible.

## 6. Acceptance criteria

| Criterion | Status |
|---|---|
| SDK joins a real LiveKit room | **Yes** (Android emulator fully; iOS simulator joins, then the simulator's CoreAudio aborts) |
| Microphone audio published | **Yes on Android**; iOS not verifiable on the simulator (needs a physical device) |
| Agent audio received and played | **Yes**: remote audio track from `nexa-agent` subscribed (synthetic tone, mock agent) |
| Voice states reflect real connection/agent events | Yes: engine events + verified signed packets; no timer-driven UI state |
| Mute, interruption, reconnect, end | Mute/end real on device; reconnect and barge-in covered by controller tests with the mock transport (engine reconnect wiring real, not fault-injected on device) |
| Tenant/session authorisation server-controlled | Yes: grant minted by gateway after session auth + quota; device holds only a room-scoped JWT; intents also go to the gateway |
| Mocha Live Voice UI in en/ar | Yes (tests) |
| Existing text chat + tests green | Yes (`./tool/check.sh`) |
| Embeddable without taking over navigation | Yes (`voiceView` is a plain widget) |
| Backend contract compatibility | **Not verified** (repository unreachable) |

## 7. Remaining blockers (owner)

B3 backend voice contract unverified / `nexa-integration` unreachable
(Backend: share or push the repo) · B8 security sign-off on the
per-session key design (Security) · B9 iOS microphone path on a physical
device; Bluetooth/earpiece routing (SDK + QA) · B1/B2/B4–B7 unchanged from
Phase 4.1 (`.ai/assumptions-and-blockers.md`).

## 8. Next steps

1. Obtain `nexa-integration`; realign `_parseGrant` and `SignedVoiceEvent` to its grant/signing scheme; rerun `voice_provisioning_integration_test` and the device journeys against it.
2. Run the voice journey on a physical iPhone (developer mode) for the microphone path.
3. Security review of the threat model; decide HMAC vs asymmetric signing.
4. Replace the mock agent with the real agent in a staging LiveKit; keep the journey test as the acceptance checklist.
