# Speaker verification review — what AMEER does, what was wrong, what is proven

Date: 2026-11-04. Phone: Nubia NX679J (Android 13). Nothing here is production-ready until real owner and non-owner testing says so.

## 1. How AMEER identifies the speaker
A **pretrained text-independent speaker-embedding model** (3D-Speaker **CAM++**, VoxCeleb, 16 kHz) turns a stretch of speech into a 512-number vector. Identity = cosine similarity between that vector and the owner's stored vectors. It is not MFCC/DTW (that older template matcher was only used for the legacy wake detector and is not used for identity).

## 2. Exact model
`packages/nexa_assistant/android/src/main/assets/nexa_assistant/speaker_campplus_voxceleb_16k.onnx`, 29.6 MB, SHA-256 `357a834f...4129b` (pinned in `tool/fetch_models.sh`), ONNX Runtime on the CPU, 2 threads. Input: 80-bin Kaldi filterbank (25 ms / 10 ms, 16 kHz mono) with per-utterance mean subtraction, at least 30 frames (0.3 s). Audio is captured at 16 kHz (no resampling) and scaled to a fixed speech level (RMS 0.06) before the model.

## 3. What is stored from the owner
Up to 64 embeddings (512 floats each) of the owner's takes, their mean, and one threshold, encrypted with AES-GCM under a non-exportable Android Keystore key in the no-backup folder. **No audio** unless the person switches on "keep my recordings" (WAV in the app's private folder, with a manifest of levels and tags, never embeddings). Delete removes recordings, profile, key, calibration and consent.

## 4. Samples needed and why
Quick setup: 15 short takes (9 of «يا أمير» in normal/quiet/loud voice, 6 sentences). The profile is built from at least 12 takes, 4 different sentences, 3 conditions; full calibration 24 / 8 / 4. Reasons: identity must come from sentences (not the wake phrase alone), and at least three levels of voice so the profile is not one tone. Additional sentences are requested **only** when the takes disagree with each other (median leave-one-out score under 0.55), not by default. Quick profiles are labelled **provisional** until strangers are measured.

## 5. Why a short phrase was "too long" (root cause)
See `docs/qa/evidence/2026-11-04/recording_pipeline_trace.md`. In short: the recorder never detected the end of speech (noise floor seeded from the mic's silent first chunk plus an absolute gate under the room's noise), ran to the time limit, and a span-based quality check then called the whole clip speech.

## 6. What was corrected
* New `UtteranceRecorder` state machine (waiting -> speaking -> done) driven by **Silero VAD** (MIT, 2.3 MB; energy fallback with a minimum-tracking floor), 320 ms warm-up, hysteresis (start >= 0.5 for 3 frames, stay >= 0.35), per-kind timing: wake (min 0.25 s, max 3.5 s of real speech, ends after 0.5 s of silence), sentence (min 1 s, max 12 s, 0.9 s of silence so pauses do not end it), no-speech timeout 7-8 s, hard cap. "Too long" now means real speech beyond the limit.
* Quality measured with the VAD's speech labels (speech vs non-speech frames), not a noise gate.
* Live status events (opening, speak now, hearing, finishing), level meter, hands-free advance after a good take, exact reasons in Arabic/English, retry, stop/cancel.
* Identity separated from the wake phrase: sentences (>= 1 s of speech) and wake takes (>= 0.6 s) are embedded; outlier takes are dropped; consistency is checked before building.
* Threshold no longer a bare constant: calibrated from the owner's leave-one-out scores and, when guests exist, from measured stranger scores; owner-only profiles never go under the measured stranger level (0.47 + 0.02); the threshold now **follows the length of the verified speech** (below), and an uncertain score offers "tap to talk" instead of opening or silently rejecting.
* Regression tests: Kotlin 11 recorder tests (short phrase in steady -50 dB room noise, no speech, too short, too long only when real, pause inside a sentence, loud/quiet, click at start, cancellation, independent attempts), 13 calibration/quality tests, 9 neural-wake tests; Dart 14 screen tests.

## 7. Phrase-dependent or independent?
CAM++ is **text-independent** (trained on free speech). The enrolment mixes the wake phrase and different sentences on purpose. But a short wake phrase carries little identity (next section), so «يا أمير» alone is a weak identity signal.

## 8. Natural voice variation
Level is normalised before the model; quiet and loud takes are enrolled; the score is the better of cosine-to-mean and the average of the two closest takes, so one tone does not dominate; outlier takes are dropped. How well it holds on **Iraqi Arabic from the owner** is not yet measured.

## 9. Evidence (real human speech, not the owner)
`speaker_benchmark.py` on LibriSpeech dev-clean-2 (19 speakers, 6 enrolment takes each: 4 normal, 1 quiet, 1 loud; 228 genuine and ~2000 impostor trials per condition; English read speech; **not Iraqi Arabic**):

| Condition | CAM++ EER | strangers' p99 | owner median |
|---|---|---|---|
| clean | 0.0% | 0.46 | 0.85 |
| quiet | 1.3% | 0.47 | 0.75 |
| loud/clipped | 0.9% | 0.45 | 0.79 |
| 1 s utterance | 2.2% | 0.40 | 0.60 |
| 0.7 s (wake phrase length) | **3.9%** | 0.37 | **0.52** |
| babble 10 dB | 1.3% | 0.45 | 0.76 |
| white noise 10 dB | 1.7% | 0.47 | 0.73 |
| far-field reverb | 3.1% | 0.46 | 0.68 |
| overall | 2.7% | | |
Consequences: (a) the wake phrase alone is a weak identity signal; (b) normal speech needs a threshold above about 0.47 to keep strangers out; (c) short speech needs a lower one. Hence the length-aware threshold: normal speech = calibrated T, 1 s = T-0.07, 0.7 s or less = T-0.12, and a score within 0.08 under that is "uncertain".

## 10. Is CAM++ enough? Alternatives measured on the same trials
| Model | size | overall EER | 0.7 s EER | far-field EER |
|---|---|---|---|---|
| CAM++ (current) | 29.6 MB | 2.7% | 3.9% | 3.1% |
| 3D-Speaker ERes2Net | 26.5 MB | 2.5% | 3.9% | 2.2% |
| WeSpeaker ResNet34-LM | 26.5 MB | 2.2% | 2.6% | 2.2% |
| WeSpeaker CAM++ | 29.3 MB | 2.9% | 5.3% | 3.1% |
With 228 genuine trials per condition the differences are inside the noise (about +-1%). **Decision: keep CAM++** (no material improvement from any alternative; ECAPA-TDNN was not run because the bundle needs a non-ONNX toolchain and it is larger). Re-run on the owner's and guests' real Iraqi Arabic clips (`speaker_eval.py`) before changing anything. On the Mac CAM++ takes about 22 ms per utterance; the on-phone embedding time is logged (`embed_ms`) at the first consented recording and is not measured yet.

## 11. Still requires the owner's voice (and consent)
Genuine-vs-impostor separation on Iraqi Arabic, false rejection across the owner's own volume/distance/noise, false acceptance against consented guests (the number of guest trials limits what can be claimed), activation latency end to end, false wakes per hour of background audio, and the on-phone embedding time. Speaker similarity is not strong authentication and is not replay-resistant (no liveness); sensitive actions keep their own confirmation.

## 12. Commits
Recorder fix `f3eed4d`; quality-aware profile, length-aware threshold, evaluation: see the next commit on this branch. Tests: `./tool/check.sh` passes (Dart 92 + plugin 15 + Kotlin 42).
