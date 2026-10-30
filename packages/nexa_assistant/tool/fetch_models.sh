#!/bin/sh
# Fetches the on-device speaker-verification model into the plugin's Android
# assets. Not committed: about 30 MB. Pinned by SHA-256.
#
# Model: 3D-Speaker CAM++ (VoxCeleb, 16 kHz), Apache-2.0, exported to ONNX
# by the k2-fsa/sherpa-onnx project. Source model:
# https://www.modelscope.cn/models/iic/speech_campplus_sv_en_voxceleb_16k
set -eu
cd "$(dirname "$0")/.."
DEST=android/src/main/assets/nexa_assistant/speaker_campplus_voxceleb_16k.onnx
URL=https://github.com/k2-fsa/sherpa-onnx/releases/download/speaker-recongition-models/3dspeaker_speech_campplus_sv_en_voxceleb_16k.onnx
SHA=357a834f702b80161e5b981182c038e18553c1f2ca752ed6cec2052365d4129b
mkdir -p "$(dirname "$DEST")"
if [ ! -f "$DEST" ]; then
  curl -fL --retry 3 -o "$DEST.part" "$URL"
  mv "$DEST.part" "$DEST"
fi
echo "$SHA  $DEST" | shasum -a 256 -c - || { rm -f "$DEST"; echo "checksum mismatch" >&2; exit 1; }
