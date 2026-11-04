# «يا أمير» wake word — status and evidence (2026-11-04)

Separate the claims:

| Level | State |
|---|---|
| Implemented | Streaming acoustic detector (mel + speech-embedding + trained head) in the Android plugin; phrase catalog; `setWakePhrase`; owner check after the wake; dry-run measurement mode. |
| Automated tests passing | Kotlin 8 new tests (head parity with Python export, hit smoothing, refractory, bounded audio, owner accept/reject, fail-closed); Dart plugin test; full `tool/check.sh`. |
| Verified on the Nubia | The detector runs as a foreground service, a played Arabic voice it never trained on triggers it (numbers below). |
| Calibrated with owner recordings | **No.** No owner clips exist yet. |
| Blocked | Owner participation (consent + recordings) for recall/false-wake numbers that mean anything. |

## What the detector is
Same 16 kHz audio -> openWakeWord `melspectrogram.onnx` -> Google `embedding_model.onnx` (96 values per 80 ms) -> 16-window head (`yaameer.bin`, 64 hidden units) -> 2 consecutive windows >= threshold (0.9) -> 3 s refractory. ONNX Runtime was already in the app; the two feature models add 2.4 MB. The old MFCC/DTW detector stays as a fallback only when no neural phrase is installed; it failed 5/5 owner attempts (docs/qa/android-voice-acceptance.md) and is not described as ready.

## Training data (all synthetic so far)
macOS `say -v Majed` (6 speeds) and Piper `ar_JO-kareem-medium` (24 prosody settings) for 6 phrasings of «يا أمير» (with/without hamza and diacritics, stretched, with «هلا»); 26 near-miss phrases (يا لبيب، يا أمين، يا أميرة، أمير، يا سمير، ...) and 38 general Iraqi/MSA sentences as negatives plus English. Augmentation: pitch/tempo warp 0.84-1.2 (other vocal tracts), loudness -28..-2 dBFS (whisper to shout), clipped shouting, reverb, muffled/thin microphones, white/pink/brown noise and babble ("TV") at SNR 2-26 dB, random placement.

## Numbers
1. Offline, trained on Piper only, tested on macOS Majed + English voices never seen (`train.py --split-engine`, 216 positives, 420 negatives, 27.7 min of adversarial near-miss audio):
   recall 0.77-0.81, false wakes 58-87 per hour of that adversarial stream (thr 0.5-0.98). Not a daily-life rate (the stream is nothing but near-misses) but it shows how weak a single-voice synthetic model is.
2. On the Nubia, same Piper-only head, Mac speaker next to the phone, dry run, Majed voice:
   12 positives at 12 speeds: **5 accepted (42 %)**. 20 negatives (10 phrases x 2: near-misses and general speech): **1 false accept (5 %)**. Android 13, app in foreground, screen on.
   Conclusion: the acoustic path works end to end, recall is **not** usable. Do not describe «يا أمير» as reliably recognised.

## What will move it (in order)
1. Owner clips (`pos_*`/`neg_*` 16 kHz WAV via the dev recorder, `Settings -> developer -> wake benchmark`) -> `train.py --final --owner-dir`. The owner must consent and speak: normal, quiet, loud, fast, slow, near/far, with TV/room noise, plus non-wake speech.
2. Clips of other family members as negatives (with their consent).
3. Re-measure on the phone with the held-out protocol below.

## Android reality (documented, not promised)
* Always-listening needs a foreground service with a visible notification; Android 13 (Nubia) accepts it only while the app was started in the foreground (the plugin refuses `not_in_foreground`). After a reboot, force-stop or "clear recents" on some OEMs it stops; the settings page says so.
* Android 14+: the `microphone` foreground-service type also requires the RECORD_AUDIO runtime permission at start and may be blocked from background starts (`background_start_blocked`). Android 15/16 tighten background FGS starts further; not run on this phone (Android 13).
* The hardware hotword path (low-power DSP) is privileged and unavailable to this app.
* Battery: the detector runs two small ONNX models every 80 ms; no measurement yet (G-01).

## Measurement protocol (to run with the owner)
Held-out, not tuned on: >= 50 owner utterances per condition (normal, quiet, loud, fast, slow, 0.3 m / 1 m / 3 m, quiet room / TV / cafe noise), >= 100 non-wake utterances (including near-misses and the owner speaking other sentences), >= 3 other speakers x 20 wake attempts each, and >= 2 h of ordinary background (TV, conversation) for false wakes/hour. Record accept/reject, score, latency from the end of the phrase to the decision. Dry-run: `adb shell touch /sdcard/Android/data/com.nexa.nexa_example/files/wake_dry_run` (decisions are logged as `NexaWake`, no call opens; remove the file to restore activation). Targets are agreed from the observed numbers, not assumed.

## Update — real-device workflow prepared (2026-11-04, evening)
Implemented and unit-tested; **not yet run with the owner and not yet shown on the phone** (the Nubia dropped off ADB after the build; the consent screen is therefore verified by widget tests only).

* Guided voice setup (consent gate -> protocol -> quality-checked takes -> calibrated profile -> deletion): `docs/qa/voice-setup-protocol.md`. Identity is learned from separate sentences, not from the wake phrase; the profile refuses to build from too few takes, sentences or conditions; the threshold is calibrated from measured scores and labelled `owner_only` (false rejection measured, false acceptance not) or `with_guests`.
* Evaluators in `tools/wake_training/`: `wake_eval.py` (leave-one-condition-out recall, false wakes per negative and per background hour, latency; synthetic-only head vs head with the owner's other conditions) and `speaker_eval.py` (leave-one-condition-out enrolment, FRR per condition, FAR against guests, EER; models compared on identical trials). Both ran on a synthetic stand-in session only (pipeline check; the folder carries a `SYNTHETIC` marker and the scripts print a banner).
* Speaker-model candidates (all take the same 80-bin mean-normalised fbank, drop-in for the app): CAM++ voxceleb (current), 3D-Speaker ERes2Net (192-d), WeSpeaker ResNet34-LM (256-d), WeSpeaker CAM++ (512-d). Choose by FRR at a fixed FAR on the owner's and guests' real clips, not by published EERs; adopting another model means bundling it and changing `OnnxSpeakerEmbedder.MODEL_ID` after that comparison.
* Speaker scoring now normalises speech level before embedding (setup and live), so loudness is not read as a different identity.
* Synthetic hint to verify with real far-field takes: a reverberant, distant, quiet condition scored far lower than the others for the same voice (CAM++ synthetic median 0.42 vs 0.8+), so the far-field takes in the protocol matter.
* Wake latency on the synthetic stand-in: 225-335 ms from the end of the phrase to the decision (real numbers come from the owner session).
