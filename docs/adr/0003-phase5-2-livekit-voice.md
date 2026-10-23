# ADR 0003 — Phase 5.2 LiveKit voice client

Date: 2026-10-23 · Status: accepted (Phase 5.2) · Supersedes ADR 0001 §7 and `nexa-realtime-voice.proposed.md`

## Context

Phase 5.2 asks for a real Flutter LiveKit voice client against the NEXA
Voice Gateway. The backend repository named in the brief
(`/home/ubuntu/nexa-integration`) was not reachable from the SDK
environment (not on this machine, not on any configured ssh host, not on
GitHub under `aistarsphere`), so its provisioning contract, signing rules
and security review could not be read.

## Decisions

1. **Build everything that does not depend on the unseen contract, isolate
   what does.** LiveKit room join, microphone publish/mute, remote audio,
   engine reconnect handling, the voice controller, state mapping, the
   capsule UI, tests and the example are real. Provisioning
   (`VoiceProvisioner` / `GatewayVoiceProvisioner._parseGrant`) and signed
   events (`SignedVoiceEvent` / `VoiceEventVerifier`) are PROPOSED,
   implemented by the reference gateway, and documented as the single
   realignment points. No backend field was invented as "the backend's".
2. **New package `nexa_realtime`** holds `LiveKitVoiceTransport` and the
   platform audio setup, as ADR 0001 foresaw once a transport brought native
   dependencies. `nexa_sdk` depends on it so hosts get `NexaClient.voice`
   from one package; text-only hosts pay the WebRTC dependency (accepted
   for now; a split SDK is possible later without API change).
3. **`RealtimeVoiceTransport` redesigned around LiveKit**: no PCM frames in
   Dart; the transport reports connection, speaking, transcripts and
   verified agent signals. The PCM/WebSocket proposal is withdrawn.
4. **Reuse `VoiceSessionMachine` unchanged.** The controller maps engine and
   agent events to the existing `VoiceEvent`s; the machine remains the only
   source of the displayed phase, so impossible state combinations cannot
   occur.
5. **Agent events as signed LiveKit data packets** verified client-side
   (HMAC-SHA256 with a per-session key, monotonic sequence, skew window).
   The threat model is written down; the key never authorises server-side
   actions. Development gateways may omit the key; this is visible in the
   UI and can be forbidden with `NexaVoiceOptions.allowUnverifiedEvents`.
6. **Reference gateway gains voice**: room-scoped participant JWT minting
   (dev key/secret stay server-side), Twirp `SendData`-based signed events,
   a scripted mock agent that starts only after the SDK participant is
   observed in the room, and optional synthetic agent audio published with
   the `lk` CLI. It remains development infrastructure.
7. **Microphone permission stays host-owned** (`NexaPermissionHandler`); the
   example uses `permission_handler`.

## Consequences

* "Joins a real LiveKit room / publishes mic / receives agent audio" is
  proven on the iOS simulator against a local `livekit-server` with a mock
  agent and synthetic audio. Nothing is proven against the NEXA backend or
  a real model.
* When `nexa-integration` becomes reachable, the expected work is: map the
  grant fields, align the canonical signing string and event names, and run
  the same tests against it.
