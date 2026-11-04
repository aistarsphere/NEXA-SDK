# Voice setup on the phone — owner protocol, privacy and measurement

> **Two modes.** The default for every user is the **quick setup**: 15 short takes, about 2 minutes (the wake phrase in a normal, a quiet and a loud voice + 6 sentences for identity), a three-line consent with the details one tap away, and "keep my recordings" **off**. The long protocol below (about 15 minutes, many conditions, negatives, background, guests) is **advanced calibration for testing**, opt-in from the same screen. A quick profile is a lighter, less calibrated profile; it needs 12 takes, 4 sentences and 3 conditions.

Applies to: Settings -> AMEER as assistant -> **Guided voice setup** (build with the guided setup, 2026-11-04).

## Consent (nothing records before this)
The first screen explains what is recorded, what is stored and where, what it is not (not a password), and how to delete. Recording starts only after the box is ticked and **Agree and start** is tapped; the plugin also refuses to record without a stored consent (`consent_required`). "Keep my recordings on this phone" is a separate switch (default on, because the wake model needs real clips to be trained and tested); with it off only measurements and the profile are kept. Guests are recorded only after the owner confirms that the guest is present and agrees; no names are stored.

## What is recorded (about 15 minutes)
| Part | Takes | Why |
|---|---|---|
| «يا أمير», normal voice | 10 | baseline |
| quiet / loud / fast / slow | 6 / 6 / 5 / 5 | natural vocal variation |
| from 1.5-2 m / 10 cm | 6 / 4 | microphone distance |
| with TV / fan / talking in the background | 8 | noise |
| other ways of saying it (هلا يا أمير, يا أمير شلونك) | 6 | pronunciations |
| different moods | 6 | tone |
| 12 sentences x conditions (NOT the wake phrase) | 24 | **identity, not tied to the phrase** |
| 20 phrases that must not wake (يا لبيب, يا أمين, أمير, ...) | 20 | false wakes |
| 3 x 30 s background (TV, talking, house/street) | 3 | false wakes per hour |
| Guest: «يا أمير» x10 + 6 sentences, per guest | 16 | strangers (false accept) |
Each take is checked on the phone (speech present, not clipped, level and noise gap) and can be repeated. The needed minimum for a profile: 24 takes, 8 different identity sentences, 4 conditions.

## Where the data is
* Profile: encrypted (AES-GCM, non-exportable Keystore key), no-backup folder.
* Recordings (only if kept): `/sdcard/Android/data/com.nexa.nexa_example/files/voice_setup/` (`clips/<kind>/*.wav`, `manifest.json` with levels and tags, no embeddings). Never uploaded by the app.
* Delete everything (recordings, profile, key, calibration, consent): trash icon on the setup screen, or **Delete voice profile** in the assistant settings.
* Never logged: audio, embeddings. Logged: counts, scores, levels.

## Offline evaluation (engineer, after the owner finishes)
```
adb pull /sdcard/Android/data/com.nexa.nexa_example/files/voice_setup DIR
cd tools/wake_training
.venv/bin/python speaker_eval.py DIR [--models name=model.onnx ...]   # FRR / FAR / EER per condition, CAM++ vs alternatives
.venv/bin/python wake_eval.py DIR                                     # recall, false wakes, background false wakes/hour, latency; leave-one-condition-out
.venv/bin/python train.py --final --owner-dir DIR/clips/wake          # retrain the head with the owner's clips (copy pos_*/neg_* names)
```
`wake_eval.py` holds each condition out in turn (the head is trained on synthetic + the owner's OTHER conditions) and compares with the synthetic-only head. `speaker_eval.py` enrols on all conditions except the tested one. Both print a banner when the folder is synthetic. Results go to `docs/qa/evidence/<date>/`.

## What gets reported (only with real data)
Recall per condition; false wakes per negative phrase and per hour of background; wake latency (end of the phrase to the decision, median and p90); speaker FRR per condition, FAR against guests (with the number of guest trials, because FAR below 1/trials cannot be claimed), EER, the chosen threshold and whether strangers were separable. A guest-free profile is labelled **owner-only** (FRR measured, FAR not).

## Physical interaction (the only part that needs the owner)
1. Open the setup, read the consent, tick, **Agree and start**.
2. Complete the owner stages. Guests: **Add a guest speaker**, confirm the guest agrees.
3. Tap **Build my voice profile**; the summary states what was and was not measured.
4. Plug the phone in so the engineer can pull the folder (or delete it).
