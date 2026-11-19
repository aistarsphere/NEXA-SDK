# LABEEB as Android assistant — implementation report

Branch `feature/phase5-3b-voice-contract-v1`, uncommitted, 2026-10-30.
Android only. No backend, AWS or GPU change. Nothing is pushed.

## 1. Files and architecture

* **New reusable plugin `packages/nexa_assistant`.** Kotlin with a Flutter
  bridge and no LABEEB branding.
  * `engine/`: pure Kotlin, unit-tested on the JVM.
    * `FilterBank`: Kaldi-compatible 80-band filterbank and MFCC.
    * `SpeechSegmenter`: energy-based utterance detector.
    * `WakePhraseModel`: personal DTW keyword spotter.
    * `WakeEngine`: decision pipeline, owner check, refractory and replay
      safeguards, sample quality.
  * `OnnxSpeakerEmbedder`: CAM++ speaker embeddings through ONNX Runtime.
  * `VoiceProfileStore`: AES-GCM with a non-exportable Android Keystore
    key, stored in `noBackupFilesDir`.
  * `WakeListenerService`: foreground service of type `microphone`, with a
    notification and a "Turn off" action.
  * `AssistantServices`:
    * `NexaVoiceInteractionService`;
    * `NexaVoiceInteractionSessionService` and its session;
    * `NexaRecognitionService`: required by Android, declines every
      request;
    * `NexaAssistantBootReceiver`.
  * `Activation` and `ActivationRouter`.
  * `NexaAssistantPlugin`: method and event channels.
  * Dart API: `NexaAssistant`, typed status, events and results, and
    `followMicrophoneUse`.
* **SDK (`nexa_sdk`).** `assistantView(voiceRequests:)`: each event opens
  the existing live-voice screen, at most one at a time. The voice
  pipeline and tool interfaces are unchanged.
* **App (`apps/nexa_example`).**
  * `DeviceAssistant`: turns activations into voice requests, gives the
    microphone to calls, and holds the lock-screen state.
  * `DeviceAssistantLockGate`: covers all content above the lock screen
    until Android unlocks.
  * `DeviceAssistantPage`: the "LABEEB as assistant" settings screen.
  * `VoiceEnrollmentPage`.
  * EN/AR strings.
  * Manifest: `ASSIST` and `VOICE_COMMAND` intent filters.
  * Settings entry and route `/settings/assistant`.

## 2. Assistant role

* Android lists `com.nexa.assistant.NexaVoiceInteractionService` next to
  Google's (verified on the Nubia NX679J, Android 13).
* The user chooses LABEEB in Android's own "Default digital assistant"
  screen. The app only opens that screen; it never changes the role
  itself.
* `isDefaultAssistant` comes from `RoleManager.isRoleHeld(ROLE_ASSISTANT)`.
* Entry points:
  * assist gesture or long-press home → session `onShow` → host activity;
  * voice assist from the lock screen → `onLaunchVoiceAssistFromKeyguard`;
  * `ASSIST` and `VOICE_COMMAND` intents.

## 3. Wake-phrase engine

A personal keyword spotter, built for this project with no third-party
model:

* MFCCs from a Kaldi-compatible filterbank;
* DTW with cosine distances against the owner's 3–5 enrolment samples;
* threshold calibrated at enrolment.

There is no licence dependency.

**Rejected alternatives:**

* Android's hotword API: needs a privileged, preinstalled app.
* Porcupine: needs an online AccessKey.
* openWakeWord: non-commercial models.
* sherpa-onnx KWS: no Arabic model.

**Limitations.** The engine is speaker-dependent: it recognises the phrase
as the enrolled person says it. An isolated phrase is needed (0.3–2.5 s
with pauses around it). A trained commercial Arabic model would be the next
step, and the engine accepts a replacement detector.

## 4. Speaker verification

* **Model:** 3D-Speaker CAM++ VoxCeleb 16 kHz, Apache-2.0, 29.6 MB,
  SHA-256 pinned, fetched by `tool/fetch_models.sh` and not committed.
* **Runtime:** ONNX Runtime Android 1.29.0 (MIT).
* **When it runs:** only after the phrase matched.
* **Threshold:** calibrated from the enrolment samples, clamped to
  0.45–0.70.
* **Kept on the device:** a 512-value embedding and the MFCC templates,
  encrypted. Never audio, never uploaded, not backed up.
* **Separate from voice cloning:** the TTS voice profile is not used.
* **Safeguards:**
  * 3 s refractory period;
  * an identical replayed clip is rejected.
* **Not an authentication factor.** There is no liveness model, so a good
  recording of the owner can pass. Sensitive data still needs the device
  unlocked (lock gate) and the existing server approvals.

## 5. Offline

| Runs without a network | Needs a network |
|---|---|
| Listening, segmentation, phrase match, owner check, enrolment, test, settings | Only the conversation after activation (existing SDK voice session) |

No AWS traffic and no LiveKit connection happen before an activation; the
SDK starts its voice session only after a voice request.

## 6. Background and lock screen (by design; device results below)

See `packages/nexa_assistant/README.md` → "What Android allows".

* **Android 14+:** listening can only be started while the app is
  visible.
* **Reboot and force-stop:** listening is not resumed automatically.
* **Lock screen:**
  * the activity is shown above the keyguard only for that activation;
  * the app content is offstage and excluded from semantics until
    `requestDismissKeyguard` succeeds;
  * "Not now" leaves without showing anything.

## 7. Tests

| Suite | Result |
|---|---|
| Kotlin engine (JVM, synthetic speech) | 8/8. Filterbank vs kaldi-native-fbank max difference 9.9e-5. Wake phrase matches at 0.036/0.049 against a 0.060 threshold; closest other phrase «يا حبيبي» at 0.100; other voices ≥ 0.134. |
| Speaker model (Python, same features) | Same TTS voice, same phrase: 0.95–0.98. Same voice, other phrases: 0.44–0.56. Other voices: 0.09–0.19. |
| Plugin Dart API | 6/6 |
| App (activation → voice, lock gate, "Not now", cold start, mic hand-over) | 4/4 (25/25 app total) |
| SDK (incl. `voiceRequests`) | 237 + 5 skipped |
| Android build (profile, all ABIs) | OK. APK 254 MB (was 87.6 MB): ONNX Runtime ~93 MB across 3 ABIs + model 30 MB. |
| Nubia install | OK: Android lists LABEEB as an assistant service. |

**Not yet measured on a phone** (needs a person speaking):

* role selection and the assist gesture;
* wake phrase with the app visible, in the background, with the screen
  off, and locked;
* owner vs. other people;
* far-field speech, noise and playback;
* CPU and battery while idle;
* deletion;
* Xiaomi.

All of these are UNVERIFIED until run.

## 8. Device test steps (Nubia, then Xiaomi)

1. Settings → LABEEB as assistant → **Choose in Android settings** → pick
   LABEEB. Back in the app, the status should read "LABEEB is your default
   assistant".
2. Long-press home, or use the assist gesture. LABEEB should open on live
   voice.
3. Lock the phone and repeat. The lock gate should show; unlock, and voice
   should open. Try "Not now" as well.
4. **Record my voice:** say «يا لبيب» five times.
5. **Test:**
   * the phrase 5×;
   * other phrases («يا حبيبي», «يا طبيب», a sentence);
   * another person saying the phrase.

   Note the distance and voice scores against their thresholds.
6. Turn on the wake phrase. The notification should show, and Android's
   microphone indicator should be on. Then say «يا لبيب»:
   * with the app open;
   * with the app in the background;
   * with the screen off;
   * with the phone locked.
7. **Only respond to my voice:** repeat step 6 with another person.
8. **Microphone hand-over:** during a live-voice call, saying the phrase
   must not trigger anything. After hanging up, the notification should
   return to "listening".
9. **Offline:** in airplane mode, saying the phrase still activates; the
   voice call then reports no network.
10. **Idle cost:** leave it listening for 30 minutes and record
    `adb shell dumpsys batterystats com.nexa.nexa_example` and
    `top -n 1 | grep nexa`.
11. **Lifecycle:**
    * swipe away from Recents;
    * reboot (expect the "turn back on" notification);
    * force-stop (expect off until the app is opened).
12. **Deletion:** Delete my voice data, then confirm that `enrolled` is
    false and listening is off.
13. **Xiaomi:** repeat steps 6 and 11. Record the HyperOS version and
    whether Autostart and "No restrictions" were needed.

## 9. Blockers and risks

* **Size:** +62 MB per arm64 device. Options: Play Asset Delivery for the
  model, or a reduced ONNX Runtime build.
* **Model licence:** CAM++ is Apache-2.0, trained on VoxCeleb (CC BY 4.0).
  Get legal confirmation before release.
* **Thresholds:** measured on synthetic speech only. Real speakers need
  calibration (step 5).
* **Battery:** a software listener keeps the microphone path active. Not
  measured yet (step 10).
* **OEM behaviour:** Xiaomi and Nubia background policies are unverified.
