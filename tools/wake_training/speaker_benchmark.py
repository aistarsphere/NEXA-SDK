"""Model comparison on REAL human speech (LibriSpeech dev-clean-2, 26 speakers).

Not Iraqi Arabic and not the owner: it measures how each speaker model copes
with volume, very short utterances, babble/white noise and far-field reverb
on real voices, with the app's own scoring rule and level normalisation.
    python speaker_benchmark.py [--models name=path ...]
"""
import argparse
import json
import random
import time
from pathlib import Path

import numpy as np
import soundfile as sf
from scipy.signal import lfilter

import speaker_eval as se
import train

SR = 16000
ROOT = Path(__file__).parent
rng = np.random.default_rng(3)
random.seed(3)


def load_speakers(min_utts=24):
    spk = {}
    for f in sorted((ROOT / "data/libri/LibriSpeech/dev-clean-2").rglob("*.flac")):
        spk.setdefault(f.parts[-3], []).append(f)
    return {k: v for k, v in spk.items() if len(v) >= min_utts}


def read(f):
    x, sr = sf.read(f, dtype="float32")
    assert sr == SR
    return x


def floor(x, db=-62):
    return x + 10 ** (db / 20) * rng.standard_normal(len(x)).astype(np.float32)


def condition(x, name, pool):
    if name == "clean":
        return floor(x)
    if name == "quiet":                       # whisper-level, noise floor unchanged
        return floor(x / (np.abs(x).max() + 1e-9) * 10 ** (-32 / 20))
    if name == "loud":                        # shouting into the mic: clipping
        return np.clip(floor(x / (np.abs(x).max() + 1e-9) * 4.0), -1, 1).astype(np.float32)
    if name == "short1s":
        a = rng.integers(0, max(1, len(x) - SR)); return floor(x[a : a + SR])
    if name == "short0.7s":                   # the length of «يا أمير»
        a = rng.integers(0, max(1, len(x) - int(0.7 * SR))); return floor(x[a : a + int(0.7 * SR)])
    if name == "babble10dB":
        return floor(train.mix_snr(x, train.babble(pool, len(x)), 10))
    if name == "white10dB":
        return floor(train.mix_snr(x, train.noise("white", len(x)), 10))
    if name == "far_reverb":
        y = train.reverb(lfilter([0.3], [1, -0.7], x).astype(np.float32))
        return floor(y / (np.abs(y).max() + 1e-9) * 10 ** (-20 / 20))
    raise ValueError(name)


CONDS = ["clean", "quiet", "loud", "short1s", "short0.7s", "babble10dB", "white10dB", "far_reverb"]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--models", nargs="*", default=[])
    a = ap.parse_args()
    models = {"campplus(current)": str(ROOT.parents[1] / "packages/nexa_assistant/android/src/main/assets/nexa_assistant/speaker_campplus_voxceleb_16k.onnx")}
    defaults = {
        "eres2net": "models/spk/3dspeaker_speech_eres2net_sv_en_voxceleb_16k.onnx",
        "wespeaker_resnet34": "models/spk/wespeaker_en_voxceleb_resnet34_LM.onnx",
        "wespeaker_campp": "models/spk/wespeaker_en_voxceleb_CAM++.onnx",
    }
    for k, v in defaults.items():
        if (ROOT / v).exists():
            models[k] = str(ROOT / v)
    for m in a.models:
        k, v = m.split("=", 1); models[k] = v

    spk = load_speakers()
    ids = sorted(spk)
    pool = [read(f)[: 6 * SR] for k in ids for f in spk[k][:2]]
    plan = {}
    for k in ids:
        files = spk[k][:]
        random.shuffle(files)
        plan[k] = {"enroll": files[:6], "test": files[6:6 + 12]}
    print(f"{len(ids)} speakers, {sum(len(p['test']) for p in plan.values())} test utterances per condition")
    out = {"speakers": len(ids), "note": "LibriSpeech English read speech; not Iraqi Arabic, not the owner", "models": {}}
    for name, path in models.items():
        emb = se.Embedder(path)
        t0 = time.time()
        enroll, test = {}, {k: {c: [] for c in CONDS} for k in ids}
        for k in ids:
            # enrolment like the quick protocol: 4 normal, 1 quiet, 1 loud
            tags = ["clean"] * 4 + ["quiet", "loud"]
            es = []
            for f, t in zip(plan[k]["enroll"], tags):
                x = read(f); x = x[: 8 * SR]
                e = emb(condition(x, t, pool)); es.append(e)
            enroll[k] = [e for e in es if e is not None]
            for f in plan[k]["test"]:
                x = read(f)[: 8 * SR]
                for c in CONDS:
                    e = emb(condition(x, c, pool))
                    if e is not None:
                        test[k][c].append(e)
        per = {}
        allg, alli = [], []
        for c in CONDS:
            gen, imp = [], []
            for k in ids:
                gen += [se.score(enroll[k], e) for e in test[k][c]]
                for o in ids:
                    if o != k:
                        imp += [se.score(enroll[k], e) for e in test[o][c][:6]]
            e_, thr = se.eer(gen, imp)
            f1 = se.frr_at_far(gen, imp, 0.01)
            per[c] = {"eer": e_, "eer_thr": thr, "frr_at_far_1pct": f1[0] if f1 else None,
                      "genuine_median": float(np.median(gen)), "impostor_p99": float(np.percentile(imp, 99)),
                      "n_gen": len(gen), "n_imp": len(imp)}
            allg += gen; alli += imp
        e_, thr = se.eer(allg, alli)
        out["models"][name] = {"overall_eer": e_, "overall_eer_thr": thr, "conditions": per,
                               "embed_ms_per_utt_mac": (time.time() - t0) / (len(ids) * (len(CONDS) * 12 + 6)) * 1000,
                               "size_mb": round(Path(path).stat().st_size / 1e6, 1)}
        print(f"{name}: overall EER {e_:.3f}  " + "  ".join(f"{c} {per[c]['eer']:.3f}" for c in CONDS))
    (ROOT / "data/speaker_benchmark.json").write_text(json.dumps(out, indent=1))


if __name__ == "__main__":
    main()
