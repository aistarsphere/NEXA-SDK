"""Train the «يا أمير» head on top of the mel + speech-embedding features.

    python train.py --split-engine      # honesty check: train piper, test say (+english)
    python train.py --final             # train on everything, write model + report

Optional: --owner-dir DIR adds consented owner clips (16 kHz mono WAVs named
pos_*.wav / neg_*.wav, e.g. from the app's dev recorder). Synthetic metrics
are NOT owner metrics; see docs/qa for the on-phone numbers.
"""
import argparse
import json
from fractions import Fraction
from pathlib import Path

import numpy as np
import soundfile as sf
from scipy.signal import fftconvolve, lfilter, resample_poly
from sklearn.neural_network import MLPClassifier

import wakefeat as wf

ROOT = Path(__file__).parent
SR = 16000
rng = np.random.default_rng(7)
EMB_END = 12400          # samples an embedding "looks back"
POS_ZONE = (0, 5120)      # window end - phrase end, samples
IGNORE = (5120, 10240)


def load(p):
    x, sr = sf.read(p, dtype="float32")
    assert sr == SR, p
    return x if x.ndim == 1 else x.mean(1)


def trim(x, thr_db=-42):
    a = np.abs(x)
    if a.max() < 1e-4:
        return x
    idx = np.where(a > a.max() * 10 ** (thr_db / 20))[0]
    s, e = max(0, idx[0] - 800), min(len(x), idx[-1] + 800)
    return x[s:e]


def noise(kind, n):
    w = rng.standard_normal(n).astype(np.float32)
    if kind == "white":
        y = w
    elif kind == "pink":
        y = lfilter([0.049922035, -0.095993537, 0.050612699, -0.004408786], [1, -2.494956002, 2.017265875, -0.522189400], w)
    else:  # brown / rumble
        y = np.cumsum(w); y -= y.mean()
    return (y / (np.abs(y).max() + 1e-9)).astype(np.float32)


def babble(pool, n):
    out = np.zeros(n, np.float32)
    for _ in range(rng.integers(3, 6)):
        c = pool[rng.integers(len(pool))]
        off = rng.integers(0, max(1, n))
        seg = np.tile(c, 1 + n // max(1, len(c)))[off : off + n] if len(c) else out
        seg = np.pad(seg, (0, n - len(seg)))
        out += seg / (np.abs(seg).max() + 1e-9) * rng.uniform(0.3, 1)
    return out / (np.abs(out).max() + 1e-9)


def reverb(x):
    t60 = rng.uniform(0.1, 0.7)
    n = int(SR * t60)
    ir = rng.standard_normal(n).astype(np.float32) * np.exp(-6.9 * np.arange(n) / n)
    ir[0] = 1.0
    y = fftconvolve(x, ir / np.abs(ir).sum() * 4)[: len(x)]
    return y.astype(np.float32)


def speaker_warp(x):
    r = rng.uniform(0.84, 1.2)      # pitch + tempo together: another vocal tract
    f = Fraction(r).limit_denominator(50)
    return resample_poly(x, f.denominator, f.numerator).astype(np.float32)


def mic_color(x):
    if rng.random() < 0.3:
        a = rng.uniform(0.5, 0.95)          # darker, far / muffled
        return lfilter([1 - a], [1, -a], x).astype(np.float32)
    if rng.random() < 0.3:
        return (x - 0.9 * np.concatenate([[0], x[:-1]])).astype(np.float32)   # thin, tinny
    return x


def mix_snr(x, n, snr_db):
    px = np.mean(x**2) + 1e-12
    pn = np.mean(n**2) + 1e-12
    return x + n * np.sqrt(px / (pn * 10 ** (snr_db / 10)))


def compose(clip, pool, positive):
    """(signal, phrase_end_sample or None)."""
    x = trim(clip)
    x = speaker_warp(x)
    x = mic_color(x)
    if rng.random() < 0.35:
        x = reverb(x)
    peak = 10 ** (rng.uniform(-28, -2) / 20)           # whisper ... shout
    x = x / (np.abs(x).max() + 1e-9) * peak
    if rng.random() < 0.1:
        x = np.clip(x * 6, -peak * 2, peak * 2)        # clipped shout
    pre = int(SR * rng.uniform(1.2, 2.4))
    post = int(SR * rng.uniform(0.4, 1.0))
    sig = np.concatenate([np.zeros(pre, np.float32), x, np.zeros(post, np.float32)])
    kind = rng.choice(["white", "pink", "brown", "babble", "babble"])
    nz = babble(pool, len(sig)) if kind == "babble" else noise(kind, len(sig))
    if rng.random() < 0.85:
        sig = mix_snr(sig + 1e-5 * rng.standard_normal(len(sig)).astype(np.float32), nz, rng.uniform(2, 26))
    sig = np.clip(sig, -1, 1).astype(np.float32)
    return sig, (pre + len(x) if positive else None)


def compose_real(clip, pool, positive, rng_=None):
    """Mild augmentation for REAL recordings: level and conditions are kept
    (a real quiet or far take must stay quiet or far)."""
    r = rng_ or rng
    x = trim(clip)
    if r.random() < 0.5:
        f = Fraction(r.uniform(0.95, 1.05)).limit_denominator(50)
        x = resample_poly(x, f.denominator, f.numerator).astype(np.float32)
    x = np.clip(x * 10 ** (r.uniform(-3, 3) / 20), -1, 1).astype(np.float32)
    pre = int(SR * r.uniform(1.4, 2.2))
    post = int(SR * r.uniform(0.5, 1.0))
    sig = np.concatenate([np.zeros(pre, np.float32), x, np.zeros(post, np.float32)])
    floor = 10 ** (-60 / 20)
    sig = sig + floor * r.standard_normal(len(sig)).astype(np.float32)
    if r.random() < 0.4:
        kind = r.choice(["pink", "babble"])
        nz = babble(pool, len(sig)) if kind == "babble" else noise(kind, len(sig))
        sig = mix_snr(sig, nz, r.uniform(12, 30))
    return np.clip(sig, -1, 1).astype(np.float32), (pre + len(x) if positive else None)


def labelled_windows(sig, phrase_end):
    w = wf.windows(wf.embeddings(sig))
    if not len(w):
        return w, np.zeros(0, np.int8)
    ends = (np.arange(len(w)) + 15) * wf.HOP + EMB_END
    if phrase_end is None:
        return w, np.zeros(len(w), np.int8)
    d = ends - phrase_end
    y = np.full(len(w), 0, np.int8)
    y[(d >= POS_ZONE[0]) & (d <= POS_ZONE[1])] = 1
    keep = ~((d > IGNORE[0]) & (d <= IGNORE[1]))
    return w[keep], y[keep]


def build(pos_files, neg_files, pool, n_pos_aug, n_neg_aug, n_noise):
    X, Y = [], []
    for f in pos_files:
        c = load(f)
        for _ in range(n_pos_aug):
            w, y = labelled_windows(*compose(c, pool, True))
            X.append(w); Y.append(y)
    for f in neg_files:
        c = load(f)
        for _ in range(n_neg_aug):
            w, y = labelled_windows(*compose(c, pool, False))
            X.append(w); Y.append(y)
    for _ in range(n_noise):
        n = int(SR * rng.uniform(3, 6))
        k = rng.choice(["white", "pink", "brown", "babble"])
        sig = (babble(pool, n) if k == "babble" else noise(k, n)) * 10 ** (rng.uniform(-45, -8) / 20)
        w, y = labelled_windows(sig.astype(np.float32), None)
        X.append(w); Y.append(y)
    return np.concatenate(X), np.concatenate(Y)


def build_real(pos, neg, pool, n_pos, n_neg):
    """Windows from real clip arrays (already loaded), mildly augmented."""
    X, Y = [], []
    for c in pos:
        for _ in range(n_pos):
            w, y = labelled_windows(*compose_real(c, pool, True))
            X.append(w); Y.append(y)
    for c in neg:
        for _ in range(n_neg):
            w, y = labelled_windows(*compose_real(c, pool, False))
            X.append(w); Y.append(y)
    return np.concatenate(X), np.concatenate(Y)


def fit(X, Y):
    F = X.reshape(len(X), -1)
    mu, sd = F.mean(0), F.std(0) + 1e-6
    clf = MLPClassifier((64,), alpha=1e-3, max_iter=60, early_stopping=True, random_state=1)
    clf.fit((F - mu) / sd, Y)
    return clf, mu, sd


def score(clf, mu, sd, X):
    return clf.predict_proba((X.reshape(len(X), -1) - mu) / sd)[:, 1]


def evaluate(clf, mu, sd, pos_files, neg_files, pool, label, reps=6):
    """Per-utterance recall, and false wakes per hour on negative audio."""
    rows = {}
    pos_scores = []
    for f in pos_files:
        for _ in range(reps):
            sig, pe = compose(load(f), pool, True)
            w = wf.windows(wf.embeddings(sig))
            ends = (np.arange(len(w)) + 15) * wf.HOP + EMB_END
            s = score(clf, mu, sd, w)
            zone = (ends - pe >= POS_ZONE[0]) & (ends - pe <= POS_ZONE[1] + 3840)
            pos_scores.append(s[zone].max() if zone.any() else 0.0)
    neg_max, neg_secs = [], 0.0
    for f in neg_files:
        for _ in range(2):
            sig, _ = compose(load(f), pool, False)
            w = wf.windows(wf.embeddings(sig))
            s = score(clf, mu, sd, w)
            neg_max.append(s.max() if len(s) else 0.0)
            neg_secs += len(sig) / SR
    pos_scores = np.array(pos_scores); neg_max = np.array(neg_max)
    for thr in (0.5, 0.7, 0.8, 0.9, 0.95, 0.98):
        rows[thr] = dict(
            recall=float((pos_scores >= thr).mean()),
            false_wakes_per_hour=float((neg_max >= thr).sum() / (neg_secs / 3600)),
        )
    print(f"[{label}] positives={len(pos_scores)} negatives={len(neg_max)} ({neg_secs/60:.1f} min)")
    for thr, r in rows.items():
        print(f"  thr {thr}: recall {r['recall']:.3f}  false wakes/h {r['false_wakes_per_hour']:.1f}")
    return rows


def export(clf, mu, sd, path):
    W1, W2 = clf.coefs_
    b1, b2 = clf.intercepts_
    blob = np.concatenate([mu, sd, W1.ravel(), b1, W2.ravel(), b2]).astype("<f4")
    path.write_bytes(b"AMRW\x01" + np.array([len(mu), W1.shape[1]], "<i4").tobytes() + blob.tobytes())
    print("exported", path, path.stat().st_size, "bytes")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--split-engine", action="store_true")
    ap.add_argument("--final", action="store_true")
    ap.add_argument("--owner-dir")
    ap.add_argument("--pos-aug", type=int, default=16)
    a = ap.parse_args()
    data = ROOT / "data"
    pos = sorted((data / "pos").glob("*.wav"))
    neg = sorted((data / "neg").glob("*.wav"))
    pool = [trim(load(f)) for f in neg[:: max(1, len(neg) // 60)]]
    report = {}
    if a.split_engine:
        tr_p = [f for f in pos if "piper" in f.name]; te_p = [f for f in pos if "say" in f.name]
        tr_n = [f for f in neg if "piper" in f.name]; te_n = [f for f in neg if "piper" not in f.name]
        X, Y = build(tr_p, tr_n, pool, a.pos_aug, 3, 300)
        print("train windows", X.shape, "pos", int(Y.sum()))
        clf, mu, sd = fit(X, Y)
        report["train_piper_test_say"] = evaluate(clf, mu, sd, te_p, te_n, pool, "train piper -> test macOS say/English")
        export(clf, mu, sd, ROOT / "models/yaameer_head_piper_only.bin")
    if a.final:
        extra_p = extra_n = []
        if a.owner_dir:
            d = Path(a.owner_dir); extra_p = sorted(d.glob("pos_*.wav")); extra_n = sorted(d.glob("neg_*.wav"))
        X, Y = build(pos + extra_p * 3, neg + extra_n, pool, a.pos_aug, 3, 400)
        print("final windows", X.shape, "pos", int(Y.sum()))
        clf, mu, sd = fit(X, Y)
        export(clf, mu, sd, ROOT / "models/yaameer_head.bin")
        report["final_train_set_resubstitution"] = evaluate(clf, mu, sd, pos[::3], neg[::6], pool, "resubstitution (optimistic)")
    (ROOT / "data/report.json").write_text(json.dumps(report, indent=1))


if __name__ == "__main__":
    main()
