#!/usr/bin/env bash
# Downloads what training needs (not committed): the two feature models
# (Apache-2.0, openWakeWord release v0.5.1) and the Piper Arabic voice.
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p models voices
R=https://github.com/dscripka/openWakeWord/releases/download/v0.5.1
curl -sL -o models/melspectrogram.onnx $R/melspectrogram.onnx
curl -sL -o models/embedding_model.onnx $R/embedding_model.onnx
echo "ba2b0e0f8b7b875369a2c89cb13360ff53bac436f2895cced9f479fa65eb176f  models/melspectrogram.onnx" | shasum -a 256 -c
echo "70d164290c1d095d1d4ee149bc5e00543250a7316b59f31d056cff7bd3075c1f  models/embedding_model.onnx" | shasum -a 256 -c
B=https://huggingface.co/rhasspy/piper-voices/resolve/main/ar/ar_JO/kareem/medium
curl -sL -o voices/ar_JO-kareem-medium.onnx $B/ar_JO-kareem-medium.onnx
curl -sL -o voices/ar_JO-kareem-medium.onnx.json $B/ar_JO-kareem-medium.onnx.json
