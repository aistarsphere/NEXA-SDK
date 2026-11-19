"""Offline simulation: would an energy gate in front of the wake models lose detections?

    python vad_gate_sim.py [--reps 2]

Today the phone runs the mel model, the embedding model and the head on every
80 ms of audio (EmbeddingWakeDetector.process), also in silence. The gate
modelled here keeps the cheap mel model running all the time (so the 76-frame
mel context stays warm) and runs the embedding model and the head only while
the gate is open. When the gate opens, the last 16 embeddings are computed from
the retained mel frames in one batch, so scores are identical to the ungated
detector for every window in which the gate is open. A detection is therefore
lost only when the gate is CLOSED at the moment the ungated detector would
have decided. That is what this script counts.

Gate: 80 ms chunk RMS above max(noise_floor * RATIO, ABS_MIN); the noise floor
is the 20th percentile of the last 3 s of chunk RMS; the gate stays open for
HANG chunks after the last loud chunk.

Data: the synthetic clips the head was trained on (data/pos, data/neg) with the
training augmentation (level -28..-2 dBFS peak, noise or babble at 2..26 dB
SNR, some reverb). Synthetic only: this is NOT a measurement on real voices or
on the phone's microphone, and the positives are the head's own training
clips, so absolute recall is optimistic. Only the difference gated vs ungated
is meaningful.
"""
import argparse
import json
import time
from pathlib import Path

import numpy as np

import train
import wakefeat as wf

ROOT = Path(__file__).parent
THR, HITS = 0.9, 2  # phrases.json, yaameer


def load_head(p: Path):
    b = p.read_bytes()
    assert b[:5] == b"AMRW\x01"
    n, h = np.frombuffer(b[5:13], "<i4")
    f = np.frombuffer(b[13:], "<f4")
    o = 0
    def take(k):
        nonlocal o
        v = f[o : o + k]; o += k
        return v
    mu, sd = take(n), take(n)
    w1 = take(n * h).reshape(n, h); b1 = take(h)
    w2 = take(h); b2 = take(1)[0]
    def score(X):
        z = np.maximum(((X.reshape(len(X), -1) - mu) / sd) @ w1 + b1, 0) @ w2 + b2
        return 1 / (1 + np.exp(-z))
    return score


def gate_open(sig, ratio, abs_min, hang):
    """Per 80 ms chunk: is the gate open?"""
    n = len(sig) // wf.HOP
    rms = np.sqrt((sig[: n * wf.HOP].reshape(n, wf.HOP) ** 2).mean(1))
    out = np.zeros(n, bool)
    last = -10**9
    for i in range(n):
        hist = rms[max(0, i - 37) : i + 1]  # 3 s
        floor = np.sort(hist)[int(len(hist) * 0.2)]
        if rms[i] > max(floor * ratio, abs_min):
            last = i
        out[i] = i - last <= hang
    return out


def first_detection(s):
    run = 0
    for i, v in enumerate(s):
        run = run + 1 if v >= THR else 0
        if run >= HITS:
            return i
    return None


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--reps", type=int, default=2)
    a = ap.parse_args()
    score = load_head(ROOT / "models/yaameer_head.bin")
    pos = sorted((ROOT / "data/pos").glob("*.wav"))
    neg = sorted((ROOT / "data/neg").glob("*.wav"))
    pool = [train.trim(train.load(f)) for f in neg[:: max(1, len(neg) // 60)]]
    gates = {
        "ratio2.0_hang12": (2.0, 0.0015, 12),
        "ratio1.5_hang12": (1.5, 0.0010, 12),
        "ratio1.5_hang25": (1.5, 0.0010, 25),
        "ratio1.3_hang25": (1.3, 0.0008, 25),
    }
    base_hit = 0
    kept = {k: 0 for k in gates}
    open_frac = {k: [] for k in gates}
    total = 0
    for f in pos:
        for _ in range(a.reps):
            sig, pe = train.compose(train.load(f), pool, True)
            w = wf.windows(wf.embeddings(sig))
            if not len(w):
                continue
            total += 1
            i = first_detection(score(w))
            ends = (np.arange(len(w)) + 15) * wf.HOP + train.EMB_END
            if i is None or not (pe <= ends[i] <= pe + 16000):
                for k, g in gates.items():
                    open_frac[k].append(gate_open(sig, *g).mean())
                continue
            base_hit += 1
            chunk = min(int(ends[i] // wf.HOP), len(sig) // wf.HOP - 1)
            for k, g in gates.items():
                go = gate_open(sig, *g)
                open_frac[k].append(go.mean())
                # both hit windows must fall while the gate is open
                if go[chunk] and go[max(0, chunk - 1)]:
                    kept[k] += 1
    # Quiet room: how often is the gate open with no speech at all?
    rng = np.random.default_rng(3)
    quiet = {}
    for db in (-70, -60, -50):
        nz = (10 ** (db / 20) * rng.standard_normal(60 * wf.SR)).astype(np.float32)
        quiet[str(db)] = {k: float(gate_open(nz, *g).mean()) for k, g in gates.items()}
    # Relative cost of the two feature models on this machine (proxy only).
    x = (0.01 * rng.standard_normal(10 * wf.SR)).astype(np.float32)
    t = time.perf_counter(); m = wf.mel_frames(x * 32767.0); t_mel = time.perf_counter() - t
    n = (len(m) - 76) // 8 + 1
    t = time.perf_counter()
    for i in range(n):
        wf._emb.run(None, {wf._emb.get_inputs()[0].name: m[i * 8 : i * 8 + 76][None, ..., None].astype(np.float32)})
    t_emb = time.perf_counter() - t
    rep = {
        "data": "synthetic training positives with training augmentation; NOT real voices",
        "positives": total,
        "ungated_detected": base_hit,
        "gates": {
            k: {
                "ratio": g[0], "abs_min": g[1], "hang_chunks": g[2],
                "detections_kept": kept[k],
                "lost_vs_ungated": base_hit - kept[k],
                "gate_open_fraction_in_test_clips": float(np.mean(open_frac[k])),
            }
            for k, g in gates.items()
        },
        "gate_open_fraction_stationary_noise_60s": quiet,
        "desktop_cost_10s_audio_ms": {"mel_one_pass": round(t_mel * 1000, 1), "embedding_per_chunk_calls": round(t_emb * 1000, 1)},
    }
    print(json.dumps(rep, indent=1))
    (ROOT / "data/vad_gate_sim.json").write_text(json.dumps(rep, indent=1))


if __name__ == "__main__":
    main()
