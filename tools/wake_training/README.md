# Wake word «يا أمير» — training

Detector = openWakeWord's two feature models (mel + Google speech-embedding, Apache-2.0)
+ a small head (16x96 embeddings -> 64 -> 1) trained here. On the phone the same pipeline
runs in `EmbeddingWakeDetector.kt`; the head ships as
`packages/nexa_assistant/android/src/main/assets/nexa_assistant/wake/<id>.bin` and is listed
in `phrases.json`. A phrase exists only if its head file ships; text alone does nothing.

    python3 -m venv .venv && .venv/bin/pip install numpy scipy onnxruntime scikit-learn soundfile piper-tts
    ./fetch.sh
    .venv/bin/python gen_data.py                 # SYNTHETIC clips (macOS Majed + Piper kareem)
    .venv/bin/python train.py --split-engine     # honest check: train on Piper, test on macOS voice
    .venv/bin/python train.py --final --owner-dir DIR   # DIR = consented owner clips pos_*.wav / neg_*.wav (16 kHz mono)

Synthetic data cannot represent the owner. Numbers from `--split-engine` and
`--final` (resubstitution) are NOT owner accuracy. See `docs/qa/wake-word-yaameer.md`.
