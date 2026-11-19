# Notes for SDK hosts — voice audio changes (2026-11-19)

Four API changes need host action. The rest is internal.

## 1. `NexaPermission.bluetooth` (new enum value)
The SDK asks for it only on Android 12+, and only when a Bluetooth headset is present during a call. It maps
to `BLUETOOTH_CONNECT`.

**What to change:**
* Any exhaustive `switch` over `NexaPermission` in your `NexaPermissionHandler` stops compiling. Add a case for it.
* Android: map it to `BLUETOOTH_CONNECT`, e.g. `Permission.bluetoothConnect` with permission_handler. Keep
  `<uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />` in the manifest.
* iOS and other platforms: **return `true` without prompting.** Calls need no Bluetooth permission there, and
  permission_handler would show the Core Bluetooth prompt.
* A refusal is fine: the call stays on the phone. The SDK asks at most once per call and gives up after 30 s.

```dart
if (permission == NexaPermission.bluetooth &&
    defaultTargetPlatform != TargetPlatform.android) {
  return true;
}
// ...
NexaPermission.bluetooth => ph.Permission.bluetoothConnect,
```

## 2. `RealtimeVoiceTransport.sendSignal` (new interface method)
`sendSignal(String method, Map<String, Object?> payload) → Future<RealtimeSignalResult>` sends one
client→agent RPC. It is used for listening control and client info, and only when the agent advertises them.

**What to change:** only hosts that **implement** `RealtimeVoiceTransport` themselves. That is custom
transports and test fakes; `MockRealtimeVoiceTransport` already implements it. Return
`RealtimeSignalResult.unsupported` if your transport cannot send. Hosts that use the built-in LiveKit transport
need no change.

## 3. `nexa_realtime` is now a native Flutter plugin (Android + iOS)
It reads the audio mode, the output route, phone calls and audio focus. It is read-only, apart from the
observer focus request during a call.

**What to change:**
* Run a full rebuild after upgrading (`flutter clean` if the plugin registrant is stale). Hot reload does not
  pick up a new plugin.
* iOS uses Swift Package Manager (`ios/nexa_realtime/Package.swift`); a podspec is included for CocoaPods
  hosts. The plugin links `CallKit`; no Info.plist keys are needed.
* Android: no new permissions in the plugin manifest. `minSdk` 24.
* Tests that build `NexaVoiceController` with the LiveKit transport and no plugin keep working: missing native
  calls are treated as "unknown". You can also inject `NexaOverrides(callAudio: NexaCallAudio(platform: fake))`.

## 4. The per-room `speakerOn` is gone
`LiveKitAudioSetup.output` no longer sets `AudioOutputOptions(speakerOn: true)`. LiveKit re-applied it on
every new Room, which reset the user's earpiece choice on each rejoin.

**What to change:**
* Do not set `speakerOn` in your own `RoomOptions`. To choose the output, use
  `client.voice.callAudio?.setSpeakerPreferred(bool)`, or the output button in the SDK call screens.
* Each call still **starts on the loudspeaker**. The choice is kept across reconnects within a call, and a
  connected headset always takes priority.

## Behaviour changes worth knowing (no code change required)
* **Mute is immediate.** `NexaVoiceOptions.muteGrace` now defaults to `Duration.zero`.
* **Speech during a reply keeps "speaking"** until the server sends `interrupted`. Two options control this:
  * `waitForInterruptConfirmation: false` restores the earlier immediate barge-in display.
  * `speakingSilenceTimeout` (default 2.5 s) returns to "listening" when the agent's audio went silent and no
    event came.
* **Platform holds.** A phone call, or on Android another app taking audio focus (e.g. a WhatsApp call), turns
  the microphone off and shows the reason in `NexaVoiceState.hold`. `controller.resumeAudio()` takes the audio
  back after a permanent loss. `holdOnPhoneCall: false` disables all of this.
* `NexaVoiceState.phoneCallHold` is now a getter (`hold != null`). New: `NexaVoiceCallStats` (`controller.stats`)
  and `NexaCallAudio` (`controller.callAudio`).
* The capsule (`NexaVoiceCapsule`) takes `output`, `onToggleOutput`, `hold` and `onResume` for custom call screens.
