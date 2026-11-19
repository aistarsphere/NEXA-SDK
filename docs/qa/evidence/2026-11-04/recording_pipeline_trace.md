# Recording pipeline — device trace (Nubia NX679J, Android 13, 2026-11-04)

Metadata only (times, levels, VAD probabilities, counts). No audio, no embeddings. A synthetic voice (macOS TTS) played from the Mac stood in for the speaker, under the owner's earlier consent; those takes were then deleted with the app's own "Delete voice data".

## Before: the "Recording too long" failure reproduced
Prompt «يا أمير» (about 0.9 s of speech), old recorder:
```
mic_open kind=wake maxMs=6000
t=159 chunk_db=-94.9 floor_db=NaN seg_end=-1      <- first chunk = mic warm-up, digital silence
t=259 chunk_db=-49.7 floor_db=-99.7 seg_end=-1    <- room noise -50 dBFS is above the -55 dB gate, floor seeded at -99.7
... 60 chunks, seg_end=-1 every time (the end of speech was never detected)
mic_closed reason=limit open_ms=6205 total_ms=6000 speech_ms=5800 speech_frames=315
rejected reason=too_long
```
Cause: (1) the recorder reused the wake-phrase segmenter, whose noise floor was seeded from the first (silent) chunk and adapts upward only 0.001/chunk during "speech", while its absolute gate (-55 dB) is below this room's noise (-50 dB): the room counted as speech for ever, so it never saw the end; (2) the clip therefore ran to the time limit; (3) the quality check measured "speech length" as first-to-last frame over a noise gate (1.5 x the 20th percentile), which in noise spans the whole clip, so it said "too long". It was never about the person speaking too long.

## After: new VAD-driven recorder (Silero VAD + state machine)
Phrase after 1.8 s of silence (VAD probabilities 0.00 warm-up, 0.10-0.01 room, then 0.33 0.89 0.95 0.99 on the phrase):
```
mic_open kind=wake vad=silero
speech_start t=2033
speech_end   t=3458 speech_ms=1024
closed open_ms=3533 take_ms=1472 speech_ms=1024 peak_db=-17.4 noise_db=-48.7 snr_db=16.5   -> accepted, next step starts by itself
```
Sentence of 5.7 s with a 0.7 s pause in the middle (identity step):
```
mic_open kind=identity vad=silero
speech_start t=2208
speech_end   t=7905 speech_ms=4352
closed open_ms=8003 take_ms=5312 speech_ms=4352 peak_db=-18.3 noise_db=-53.2 snr_db=20.3  -> accepted as one take
```
Noisy room, nobody speaking clearly (an ambient sound of 0.6 s): rejected in 6 s with "too much background noise" (`snr_db=-7.2`), not "too long". A click right after the mic opens is ignored by the 320 ms warm-up (unit test + earlier trace of a 608 ms false "speech" at 246 ms that the warm-up now removes).
The screen shows, in order: starting the microphone -> **Speak now** -> **I hear you…** with a live level meter -> finishing the take -> accepted (and the next step starts) or the exact reason with a Try again button.
