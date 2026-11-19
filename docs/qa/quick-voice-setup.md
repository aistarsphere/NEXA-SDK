# Quick voice setup (default journey) — design, evidence, limits (2026-11-04)

## Journey
Settings → AMEER as assistant → **Voice recognition** card → **Set up my voice**:
1. Consent (three short lines; no recording is kept; nothing uploaded).
2. **Record**: one natural sentence (Silero VAD stops it; quality check; CAM++ embedding; saved encrypted at once).
3. **Verify**: a DIFFERENT sentence, scored against the first.
4. **One more sentence only if** the check is not conclusive.
5. **Try the assistant**: the installed wake model is run for 10 s; "phrase heard" and "voice matches / not sure / does not match" are two separate results; the Android assistant state is read from the system.
6. Status: Ready (provisional) / Needs improvement / Not configured. After a restart the state is restored from the encrypted profile.
The card offers: Test my voice, Set up again, Delete, "Respond only to my voice". No counts, scores or thresholds are shown.

## How many recordings
Normal path: **2** (enrolment + verification). Extra sentences (up to 4 in total) are requested when the verification score is under the "strong" level (not sure / different voice) or the 3+ takes do not agree. After 4 inconsistent takes the state is **Needs improvement**: owner check is off, tap-to-talk stays. Poor takes (speech under 2 s, noise gap under 8 dB, clipping, too quiet) are refused with a precise reason and are not counted.

## Evidence behind the rule (real speech, English, 19 LibriSpeech speakers; NOT Iraqi Arabic, NOT the owner)
`tools/wake_training/enroll_policy_benchmark.py`, enrolment sentence 3-6 s, a different 2-4 s sentence for verification, CAM++ with the app's level normalisation and scoring:
| enrolment sentences | clean | quiet | babble 10 dB | far-field | stranger p99 | strangers' maximum |
|---|---|---|---|---|---|---|
| 1 | genuine median 0.70, p5 0.49 | 0.60 / 0.41 | 0.62 / 0.39 | 0.54 / 0.33 | 0.38-0.41 | 0.52-0.54 |
| 2 | 0.75 / 0.55 | 0.65 / 0.46 | 0.66 / 0.45 | 0.57 / 0.36 | 0.39-0.42 | 0.49-0.56 |
| 3 | 0.78 / 0.61 | 0.66 / 0.48 | 0.67 / 0.46 | 0.58 / 0.38 | 0.40-0.43 | 0.50-0.57 |
Reading: with one 3-6 s sentence a stranger's best score in ~4000 trials was 0.54. A verification of **0.58 or more** exceeded every stranger seen, so it finishes the setup (STRONG); **0.45-0.58** cannot separate a noisy owner from a similar stranger, so one more sentence is asked for; **below 0.45** says "that did not sound like the first" and asks again. The live acceptance level for sentence-length speech is 0.50 (stranger p99 0.38-0.43), scaled down for short speech by the length rule (0.7 s of speech: 12 points lower, the "uncertain" band offers tap-to-talk). FRR at 1 % false acceptance on this data: 0.7 % clean, 5-9 % in quiet/noise/far-field with one enrolment sentence, 0-6 % with three. Two enrolment recordings do not give the owner a measured error rate: all of this must be repeated on the owner's and guests' real Iraqi Arabic speech.

## Model and storage
CAM++ (`speaker_campplus_voxceleb_16k.onnx`, 512-d) and Silero VAD are unchanged and run on the phone. The profile (the accepted embeddings, a mean and a threshold, never audio) is AES-GCM encrypted under a non-exportable Keystore key in the no-backup folder, written after every accepted take, so a restart or crash loses nothing and nothing biometric exists in plain text. Delete removes the profile, its key, the consent and the progress. Nothing is uploaded; no network permission is used by this flow. Logs carry timings, levels and the verdict word only.

## What changed in the screens
Moved to **Developer: voice tools** (visible only with the dev-tools build): the 15-take guided protocol, the older template enrolment and its delete, the sensitivity control, the older test card, the wake benchmark. Standard users see: the voice card, the assistant checklist, the wake phrase screen.

## Verified on the Nubia (2026-11-04, synthetic Arabic voice, deleted afterwards)
Step 1: preparing → speak now → listening → saved (5.6 s of speech, embed 453 ms first call); step 2: different sentence, 4.5 s of speech, embed 137 ms, decision ready (two recordings); step 3: the real wake model heard «أمير» and the voice result was "not sure" (0.5 s of speech is a weak identity signal, as designed); app restart: the card still says Ready; delete: "Voice profile deleted". Screens in `docs/qa/evidence/2026-11-04/quick_setup_*.png`. The test used a text-to-speech voice, not the owner's.

## Still needs the owner
Independent genuine/impostor testing on real Iraqi speakers; the owner's own FRR in quiet, loud and noisy conditions; consented guests for the false-accept rate; a held-out wake-phrase measurement. Speaker similarity is not authentication, has no liveness or replay protection, and never unlocks the phone or authorises a sensitive action.
