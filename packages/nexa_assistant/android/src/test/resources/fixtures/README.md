Test clips: synthetic speech from macOS text-to-speech (`say`, 16 kHz mono).
"Owner" = the Arabic voice Majed saying "يا لبيب" at different speeds;
negatives = Majed saying other phrases; other speakers = English voices
saying "Ya Labeeb". `enroll_1_fbank.txt` = reference 80-bin filterbank of
`enroll_1.wav` from kaldi-native-fbank (k2-fsa), dither 0, high_freq Nyquist.

Synthetic voices are far more consistent than people; thresholds must be
re-measured with real recordings (see packages/nexa_assistant/README.md).
