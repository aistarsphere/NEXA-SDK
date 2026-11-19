"""Mel + speech-embedding features, identical to what the phone computes.

melspectrogram.onnx   : (1, n_samples float32 in int16 scale) -> (1,1,frames,32), then x/10 + 2
embedding_model.onnx  : (b, 76, 32, 1) -> (b,1,1,96); one embedding per 8 mel frames (80 ms)
Both models are Apache-2.0 (openWakeWord feature extractors; Google speech_embedding).
"""
from pathlib import Path

import numpy as np
import onnxruntime as ort

ROOT = Path(__file__).parent
SR = 16000
HOP = 1280            # 80 ms per embedding
WINDOW_EMB = 16       # classifier looks at the last 16 embeddings (1.28 s)


def _session(name):
    o = ort.SessionOptions()
    o.intra_op_num_threads = 2
    return ort.InferenceSession(str(ROOT / "models" / name), o, providers=["CPUExecutionProvider"])


_mel = _session("melspectrogram.onnx")
_emb = _session("embedding_model.onnx")


def mel_frames(audio_int16_scale: np.ndarray) -> np.ndarray:
    """(frames, 32) mel features for the whole clip."""
    x = audio_int16_scale.astype(np.float32)[None, :]
    out = _mel.run(None, {_mel.get_inputs()[0].name: x})[0]
    return out.reshape(-1, 32) / 10.0 + 2.0


def embeddings(audio_float: np.ndarray) -> np.ndarray:
    """(T, 96) embeddings, one per 80 ms, from float audio in [-1, 1]."""
    m = mel_frames(audio_float * 32767.0)
    n = (len(m) - 76) // 8 + 1
    if n <= 0:
        return np.zeros((0, 96), np.float32)
    batch = np.stack([m[i * 8 : i * 8 + 76] for i in range(n)])[..., None].astype(np.float32)
    out = _emb.run(None, {_emb.get_inputs()[0].name: batch})[0]
    return out.reshape(n, 96)


def windows(emb: np.ndarray) -> np.ndarray:
    """(T-15, 16, 96): every window of 16 consecutive embeddings."""
    if len(emb) < WINDOW_EMB:
        return np.zeros((0, WINDOW_EMB, 96), np.float32)
    idx = np.arange(WINDOW_EMB)[None, :] + np.arange(len(emb) - WINDOW_EMB + 1)[:, None]
    return emb[idx]
