"""Held-out evaluation of the «يا أمير» detector on the clips from the phone.

    python wake_eval.py DIR [--thr 0.9] [--hits 2]

Nothing is tuned on the clips it is tested on:
* every owner condition (normal, quiet, loud, fast, slow, far, close, noise,
  tone, variant) is held out in turn: the head is trained on synthetic data +
  the owner's OTHER conditions, then tested on the held-out one;
* owner negatives (phrases that must not wake) are split by phrase: half train,
  half test; background clips are split the same way (by clip);
* report A is the same test with the synthetic-only head, so the gain from
  real data is visible.
Reports recall, false wakes per test negative clip, false wakes per hour of
background audio, and latency (end of the phrase to the decision). A guest
saying the phrase is reported separately: the detector alone is expected to
fire; the owner check is what must stop it (see speaker_eval.py).
"""
import argparse
import json
from pathlib import Path

import numpy as np
import soundfile as sf

import train
import wakefeat as wf

SR = 16000


def load_session(root: Path):
    man = json.loads((root / "manifest.json").read_text())
    out = []
    for m in man:
        f = root / "clips" / m["kind"] / f"{m['id']}.wav"
        if m.get("file", True) and f.exists():
            x, sr = sf.read(f, dtype="float32")
            out.append((m, x if x.ndim == 1 else x.mean(1)))
    return out


def phrase_end(x):
    """End of speech in samples (same energy rule as the phone's clip analysis)."""
    fr = x[: len(x) // 160 * 160].reshape(-1, 160)
    rms = np.sqrt((fr**2).mean(1))
    gate = max(np.sort(rms)[int(len(rms) * 0.2)] * 1.5, 0.002)
    idx = np.where(rms >= gate)[0]
    return int((idx[-1] + 1) * 160) if len(idx) else len(x)


def test_signal(x):
    """Deterministic context around a real clip: low-noise pre-roll, the clip, a tail."""
    pre = np.zeros(int(1.6 * SR), np.float32)
    post = np.zeros(int(0.9 * SR), np.float32)
    sig = np.concatenate([pre, x, post])
    sig = sig + 10 ** (-62 / 20) * np.random.default_rng(1).standard_normal(len(sig)).astype(np.float32)
    return np.clip(sig, -1, 1), len(pre) + phrase_end(x)


def detections(clf, mu, sd, sig, thr, hits):
    """Sample index at which each wake would be decided (3 s refractory)."""
    w = wf.windows(wf.embeddings(sig))
    if not len(w):
        return []
    s = train.score(clf, mu, sd, w)
    ends = (np.arange(len(w)) + 15) * wf.HOP + train.EMB_END
    out, run, last = [], 0, -10**9
    for i, v in enumerate(s):
        run = run + 1 if v >= thr else 0
        if run >= hits and ends[i] - last >= 3 * SR:
            out.append(int(ends[i])); last = int(ends[i]); run = 0
    return out


def run_fold(clf, mu, sd, pos_test, neg_test, bg_test, thr, hits, guest_pos):
    hit, lat = 0, []
    for x in pos_test:
        sig, pe = test_signal(x)
        d = [t for t in detections(clf, mu, sd, sig, thr, hits) if pe <= t <= pe + 8000]
        if d:
            hit += 1
            lat.append((d[0] - pe) / 16)
    fa = sum(bool(detections(clf, mu, sd, test_signal(x)[0], thr, hits)) for x in neg_test)
    bg_events, bg_secs = 0, 0.0
    for x in bg_test:
        bg_events += len(detections(clf, mu, sd, np.clip(x, -1, 1).astype(np.float32), thr, hits))
        bg_secs += len(x) / SR
    gh = 0
    for x in guest_pos:
        sig, pe = test_signal(x)
        gh += any(pe <= t <= pe + 8000 for t in detections(clf, mu, sd, sig, thr, hits))
    return {
        "n_pos": len(pos_test), "recall": hit / max(1, len(pos_test)),
        "latency_ms_median": float(np.median(lat)) if lat else None,
        "latency_ms_p90": float(np.percentile(lat, 90)) if lat else None,
        "n_neg": len(neg_test), "false_wake_clips": fa,
        "bg_hours": bg_secs / 3600, "bg_false_wakes": bg_events,
        "bg_false_wakes_per_hour": (bg_events / (bg_secs / 3600)) if bg_secs else None,
        "n_guest_pos": len(guest_pos), "guest_wake_rate": gh / max(1, len(guest_pos)),
    }


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("dir")
    ap.add_argument("--thr", type=float, default=0.9)
    ap.add_argument("--hits", type=int, default=2)
    ap.add_argument("--aug", type=int, default=12)
    a = ap.parse_args()
    root = Path(a.dir)
    clips = load_session(root)
    owner_wake = [(m, x) for m, x in clips if m["speaker"] == "owner" and m["kind"] == "wake"]
    owner_neg = [(m, x) for m, x in clips if m["speaker"] == "owner" and m["kind"] == "negative"]
    bgs = [x for m, x in clips if m["kind"] == "background"]
    guest_pos = [x for m, x in clips if m["speaker"].startswith("guest") and m["kind"] == "wake"]

    data = Path(__file__).parent / "data"
    syn_pos = sorted((data / "pos").glob("*.wav"))
    syn_neg = sorted((data / "neg").glob("*.wav"))
    pool = [train.trim(train.load(f)) for f in syn_neg[:: max(1, len(syn_neg) // 60)]]

    conds = sorted({t for m, _ in owner_wake for t in m["tags"] if t not in ("near",)})
    # negatives / background: stable halves (by index, i.e. by phrase / clip)
    neg_train = [x for i, (m, x) in enumerate(owner_neg) if i % 2 == 0]
    neg_test = [x for i, (m, x) in enumerate(owner_neg) if i % 2 == 1]
    bg_train = bgs[::2]
    bg_test = bgs[1::2]

    print("synthetic-only head ...")
    Xs, Ys = train.build(syn_pos, syn_neg, pool, 8, 3, 300)
    base = train.fit(Xs, Ys)
    report = {"synthetic_data": (root / "SYNTHETIC").exists(), "thr": a.thr, "hits": a.hits, "folds": {}}
    if report["synthetic_data"]:
        print("*** SYNTHETIC session: pipeline check only, not owner numbers ***")
    for c in conds:
        test = [x for m, x in owner_wake if c in m["tags"]]
        trn = [x for m, x in owner_wake if c not in m["tags"]]
        if len(test) < 3 or len(trn) < 8:
            continue
        # report A: synthetic-only head
        ra = run_fold(*base, test, neg_test, bg_test, a.thr, a.hits, guest_pos)
        # report B: + the owner's other conditions, negatives and background
        Xr, Yr = train.build_real(trn, neg_train, pool, a.aug, 4)
        X = np.concatenate([Xs, Xr, Xr]); Y = np.concatenate([Ys, Yr, Yr])
        head = train.fit(X, Y)
        rb = run_fold(*head, test, neg_test, bg_test, a.thr, a.hits, guest_pos)
        report["folds"][c] = {"synthetic_only": ra, "with_owner_data": rb}
        print(f"[{c}] recall {ra['recall']:.2f} -> {rb['recall']:.2f}  "
              f"false-wake clips {ra['false_wake_clips']}/{ra['n_neg']} -> {rb['false_wake_clips']}/{rb['n_neg']}  "
              f"latency {rb['latency_ms_median']}")
    (root / "wake_eval.json").write_text(json.dumps(report, indent=1))
    print("wrote", root / "wake_eval.json")


if __name__ == "__main__":
    main()
