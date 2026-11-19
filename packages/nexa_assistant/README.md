# nexa_assistant

Android default-assistant integration for NEXA host apps:

* **System assistant role.** A `VoiceInteractionService` with its session
  service and the required recognition service. The user picks the app in
  Android's own "Default digital assistant" screen
  (`openAssistantSettings()`); nothing is selected silently. The assist
  gesture, the assist button and "voice assist from the lock screen" then
  open the host's assistant screen.
* **On-device wake phrase.** A foreground service of type `microphone`
  with a permanent notification. Audio is analysed in memory and never
  stored or sent.
* **Optional owner-voice check.** Runs on the device after the phrase
  matched.
* **Activations only.** The host receives activations (`activations`) and
  opens its own voice session. The plugin never connects to a backend.

It contains no host branding: the host passes its wake phrase label
(`configure(phraseLabel:)`) and builds its own screens.

## How detection works

1. `SpeechSegmenter`: an energy detector with an adaptive noise floor runs
   on 10 ms chunks and emits isolated utterances of 0.3–2.5 s. This is the
   only part that runs continuously.
2. `WakePhraseModel`: a personal keyword spotter. MFCCs (from a
   Kaldi-compatible 80-band filterbank) are compared with the owner's own
   enrolment samples by dynamic time warping over cosine frame distances.
   The threshold is calibrated at enrolment: 3× the median
   nearest-neighbour distance between samples, clamped to 0.05–0.16.
3. Owner check (optional): the 3D-Speaker **CAM++** model (VoxCeleb,
   16 kHz) produces a 512-value voice embedding through ONNX Runtime. It is
   compared by cosine with the owner's mean embedding. The threshold is
   calibrated from the enrolment samples (leave-one-out minus 0.15,
   clamped to 0.45–0.70).
4. Safeguards:
   * 3 s refractory period after an activation;
   * an utterance that is a near-exact copy of the last accepted one is
     rejected as a replayed recording;
   * the microphone is released during the host's voice call, during
     phone calls, and right after an activation.

**Why not Android's hotword API.** `AlwaysOnHotwordDetector` and the
sandboxed `HotwordDetectionService` need privileged permissions
(preinstalled assistants) and OEM DSP keyphrase models. An installed app
cannot use them, so this plugin uses the software path. That costs more
battery than a DSP detector.

**Why not a trained wake-word model.**

* Picovoice Porcupine needs an online-licensed AccessKey, and custom Arabic
  phrases are trained in their console.
* openWakeWord's pre-trained models are non-commercial (CC BY-NC-SA), and
  there is no Arabic «يا لبيب» model.
* sherpa-onnx keyword spotting has no Arabic model.

A trained, commercially licensed Arabic model would detect the phrase from
any speaker. The engine interface (`WakeEngine`) accepts a replacement
detector when one is available. Until then, the personal template approach
works only for the enrolled person's way of saying the phrase.

## Model and licences

| Component | Licence | Size |
|---|---|---|
| 3D-Speaker CAM++ VoxCeleb 16 kHz (ONNX export by k2-fsa/sherpa-onnx) | Apache-2.0 | 29.6 MB |
| ONNX Runtime Android 1.29.0 | MIT | ~32 MB arm64 native library |

* **Model sources:** [ModelScope](https://www.modelscope.cn/models/iic/speech_campplus_sv_en_voxceleb_16k)
  and the [sherpa-onnx speaker-recognition release](https://github.com/k2-fsa/sherpa-onnx/releases/tag/speaker-recongition-models).
* **Training data:** the model was trained on VoxCeleb, which is licensed
  CC BY 4.0. Have legal review the model and data licences before release.
* **Fetching the model:** the model is not committed. Run
  `tool/fetch_models.sh`, which pins its SHA-256. Without the model the
  owner-voice check reports `model_unavailable` and cannot be turned on;
  the wake phrase still works.

**APK size.** A universal APK grows by about 93 MB of native libraries plus
the 30 MB model. With an App Bundle each phone downloads only its own ABI:
about +62 MB on arm64. Options to reduce this:

* deliver the model with Play Asset Delivery;
* use a reduced-operator ONNX Runtime build.

## Host integration

1. Add the dependency.
2. Add the assist intents to the launcher activity in the app manifest:

   ```xml
   <intent-filter>
       <action android:name="android.intent.action.ASSIST"/>
       <category android:name="android.intent.category.DEFAULT"/>
   </intent-filter>
   <intent-filter>
       <action android:name="android.intent.action.VOICE_COMMAND"/>
       <category android:name="android.intent.category.DEFAULT"/>
   </intent-filter>
   ```

3. At start-up:
   * `configure(phraseLabel: …)`;
   * listen to `activations`;
   * call `takePendingActivation()` for cold starts;
   * call `followMicrophoneUse(voiceIsActive)` so the listener releases
     the microphone during the host's own voice call.
4. When an activation has `locked: true`, the activity is shown above the
   lock screen. Cover all content until `requestUnlock()` returns
   `unlocked`, then open voice. `endLockScreenSession(moveToBack: true)`
   leaves without showing anything.

The plugin merges these permissions into the app manifest: `RECORD_AUDIO`,
`FOREGROUND_SERVICE(_MICROPHONE)`, `POST_NOTIFICATIONS` and
`RECEIVE_BOOT_COMPLETED`.

## What Android allows

| Situation | Behaviour |
|---|---|
| App open | Listening works. |
| App in background | Listening continues while its notification is shown. |
| Screen off or locked | Listening continues. Activation opens the app above the lock screen behind the host's unlock gate. |
| Swiped from Recents | Stock Android keeps the service running. Some OEMs stop it (Xiaomi needs Autostart and "No restrictions" battery). |
| Battery optimisation | May stop it. The settings screen links to battery and Autostart settings. |
| Reboot | Not restarted: Android does not allow background microphone services from boot. The app posts a notification, and opening the app once turns listening back on. |
| Force-stop | Everything stops. Nothing restarts until the user opens the app. |
| Android 14 and later | A microphone foreground service can only start while the app is visible. `setWakeEnabled` returns `not_in_foreground` otherwise. |

## Tests

* `android/src/test`: JVM unit tests on synthetic speech (`fixtures/`).
  They cover filterbank parity with kaldi-native-fbank (max difference
  1e-4), segmentation, phrase accept/reject, the owner check, refractory
  and replay rejection, and enrolment quality. Run them with
  `./gradlew :nexa_assistant:testDebugUnitTest` from an app's `android/`
  folder.
* `test/`: the Dart API with mocked channels.

Synthetic voices are far more consistent than people. Measure false accepts
and false rejects with real speakers on real devices before relying on the
defaults; the steps are in
`docs/assistant/ANDROID-ASSISTANT-REPORT.md`.

## Developer benchmark (dev builds only)

Settings → "Wake-word benchmark (dev)" records labelled clips into the app's
`files/wake_bench` folder (after consent; never uploaded) and times the
speech-embedding model on the device. It is compiled into the settings page
only when `NEXA_DEV_TOOLS` is on.
