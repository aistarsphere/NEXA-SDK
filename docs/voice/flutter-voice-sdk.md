# NEXA Flutter SDK — Live Voice (Phase 5.2)

## Status

| Layer | Status |
|---|---|
| LiveKit room join, microphone publish, remote audio playback | implemented (`nexa_realtime`); full journey verified on the Android emulator against a local `livekit-server`; the iOS simulator joins the room and then aborts in CoreAudio (simulator limitation) — iOS audio needs a physical device |
| Voice controller + state machine mapping | implemented, unit-tested with labelled mocks |
| Live Voice Capsule UI (Mocha, en/ar, RTL, reduced motion, a11y) | implemented, widget-tested |
| Gateway provisioning + signed agent events | **proposed**; validated against the reference gateway's mock agent only |
| Backend (`nexa-integration`) compatibility | **not verified** — repository unreachable from the SDK environment |
| Assistant speech | **synthetic** (mock agent publishes a tone); no model inference |

## Public API

```dart
final nexa = await Nexa.initialize(
  config: NexaConfig(..., requestedCapabilities: {NexaCapability.textChat, NexaCapability.liveVoice}),
  auth: MyBackendAuthProvider(),
  overrides: NexaOverrides(permissionHandler: MyPermissionHandler()), // must grant microphone
  voiceOptions: const NexaVoiceOptions(startMuted: false, allowUnverifiedEvents: false),
);

final voice = nexa.voice;                 // NexaVoiceController
await voice.start();                      // permission → gateway grant → LiveKit room
voice.state;                              // ValueListenable<NexaVoiceState>
voice.events;                             // Stream<NexaVoiceEvent>
await voice.setMuted(muted: true);        // or toggleMute()
await voice.interrupt();                  // explicit barge-in
await voice.end();
nexa.voiceView(onOpenSettings: ..., autoStart: false); // Live Voice Capsule widget
```

`NexaVoiceState`: `phase` (`VoiceState`), `muted`, `transcript`,
`agentIdentity`, `agentPresent`, `agentAudioActive` (remote audio track
subscribed), `eventsVerified`, `rejectedEvents`, `error`, `endReason`.

`NexaVoiceEvent`: phase changed, transcript updated, agent presence, mute
changed, error, event rejected, ended.

Hosts own navigation: the SDK never pushes a route for voice.

## Required permissions and platform setup

* iOS: `NSMicrophoneUsageDescription` in `Info.plist`; `UIBackgroundModes:
  audio` if calls must survive backgrounding; deployment target ≥ 15.
* Android: `RECORD_AUDIO`, `MODIFY_AUDIO_SETTINGS`, `INTERNET`,
  `BLUETOOTH_CONNECT`; minSdk as required by `flutter_webrtc` (24 with
  Flutter 3.44 defaults).
* The SDK never calls OS permission APIs; implement `NexaPermissionHandler`
  (the example uses `permission_handler`). Denied → `microphoneDenied` state
  with an "Open settings" action (`voiceView(onOpenSettings:)`).
* Audio session: `LiveKitAudioSetup` (echo cancellation, noise suppression,
  speaker output). Platform specifics live only in `nexa_realtime`.

Supported platforms: iOS and Android (via `livekit_client` 2.13 /
`flutter_webrtc`). Web/desktop not validated.

## Session lifecycle

1. `start()` → `connecting`; host permission handler is asked for the microphone.
2. Chat session is started if needed (`SessionManager.start`), `liveVoice` must be granted.
3. `VoiceProvisioner.provision` → `VoiceGrant` (room-scoped LiveKit token, per-session event key, expiry, max duration).
4. `LiveKitVoiceTransport.connect(grant)` → room joined → `listening`; microphone published (or muted when `startMuted`).
5. Agent joins (`agentPresent`), its audio track subscribes (`agentAudioActive`), signed events drive `thinking / aiSpeaking / bargeIn / modelBusy / …`.
6. Interruptions: the LiveKit engine reconnects on its own → `reconnecting` → `listening`; final loss → `disconnected` with a retryable error and a Retry action.
7. `end()`, grant expiry, `max_duration`, quota (`quotaExceeded`) or `session_ending` → room left, `DELETE …/voice` sent, `ended`.
8. `NexaClient.dispose()` ends any active call.

## Voice state mapping (LiveKit / agent → `VoiceSessionMachine`)

| Source | `RealtimeVoiceEvent` | `VoiceEvent` |
|---|---|---|
| `Room.connect` resolved / `RoomReconnectedEvent` | `RealtimeConnected` | `VoiceConnected` |
| `RoomReconnectingEvent` | `RealtimeReconnecting` | `VoiceDisconnected(willReconnect: true)` |
| `RoomDisconnectedEvent` | `RealtimeDisconnected(false)` | `VoiceDisconnected(false)` |
| `ActiveSpeakersChangedEvent` (local) | user speech started/ended | `VoiceUserSpeechStarted/Ended` |
| `ActiveSpeakersChangedEvent` (agent) or signed `assistant_speaking_*` | assistant speaking started/ended | `VoiceAssistantAudioStarted` / `VoiceAssistantTurnEnded` |
| `TranscriptionEvent` or signed `transcript` | `RealtimeTranscript` | `VoiceTranscriptFinal` when final |
| signed `assistant_thinking` | `RealtimeAssistantThinking` | `VoiceAssistantThinking` |
| signed `interrupted` | `RealtimeInterrupted` | `VoiceInterruptAcknowledged` |
| signed `model_busy` / `model_available` | … | `VoiceModelBusy` / `VoiceModelAvailable` |
| signed `quota_exceeded` | `RealtimeQuotaExceeded` | `VoiceQuotaExceeded` |
| signed `session_ending` | `RealtimeSessionEnding` | `VoiceEndRequested` |
| `ParticipantConnectionQualityUpdatedEvent` (local, poor/lost) | `RealtimeNetworkQuality` | `VoiceNetworkQualityChanged` |
| `TrackSubscribed/Unsubscribed` (agent audio) | `RealtimeAgentAudioTrack` | state flag only |

The machine is total and pure, so impossible combinations (e.g. `muted` and
`aiSpeaking` at once) cannot be displayed: there is exactly one phase.

## Event verification

See `docs/contracts/nexa-voice-provisioning.proposed.md` §3–§4. Every agent
packet is verified (signature, session, sequence, skew) before it can affect
state; rejections are counted in `rejectedEvents` and surfaced as
`NexaVoiceEventRejected`. Unverified mode is visible in the UI.

## Host integration example

`apps/nexa_example/lib/pages/voice_page.dart` embeds `voiceView()` under a
host app bar, logs typed events, shows the mode banner (mock vs reference
gateway + local LiveKit), and wires `permission_handler`.

Local run: `make gateway` is not enough for voice; use
`tool/e2e.sh <device>` which also starts `livekit-server --dev` and the mock
agent, or start them manually:

```bash
livekit-server --dev --bind 127.0.0.1
dart run tools/nexa_reference_gateway/bin/nexa_reference_gateway.dart \
  --livekit-url ws://127.0.0.1:7880 --agent-audio tools/nexa_reference_gateway/assets/agent_tone.ogg
```

## Known backend dependencies (blockers)

* The real provisioning endpoint, grant fields and signing scheme of
  `nexa-integration` must be mapped in `GatewayVoiceProvisioner` /
  `SignedVoiceEvent`.
* The backend's agent lifecycle events, quota semantics and reconnection
  behaviour must be confirmed against the state mapping above.
* Security review of the per-session key design (threat model in the
  contract document) requires human approval.
