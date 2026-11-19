"""Speaker-verification evaluation on the clips pulled from the phone.

    adb pull /sdcard/Android/data/com.nexa.nexa_example/files/voice_setup DIR
    python speaker_eval.py DIR [--models campplus=PATH wespeaker=PATH ...]

Protocol (no tuning on the test clips):
* Enrollment = owner `identity` + `wake` takes from every condition EXCEPT the
  one being tested (leave-one-condition-out), so "quiet", "loud", "far",
  "noise", ... are each tested as conditions the profile has never heard.
* Genuine trials = the held-out condition's owner takes.
* Impostor trials = every guest take (consented non-owners), scored against
  the same enrollment. Without guests only false rejection is measured and
  the report says so.
* Score = the app's rule: max(cosine to the mean, mean of the two best
  per-sample cosines). Level is normalised like the app (speech RMS 0.06).

Reports FRR per condition at the threshold, EER, FRR at fixed FAR targets
(limited by the number of impostor trials: stated), and a recommended
threshold. Models are compared on identical trials.
"""
import argparse
import json
from pathlib import Path

import kaldi_native_fbank as knf
import numpy as np
import onnxruntime as ort
import soundfile as sf

SR = 16000
TARGET_RMS = 0.06


def fbank(x: np.ndarray) -> np.ndarray:
    o = knf.FbankOptions()
    o.frame_opts.dither = 0.0
    o.frame_opts.samp_freq = SR
    o.mel_opts.num_bins = 80
    f = knf.OnlineFbank(o)
    f.accept_waveform(SR, (x * 32768.0).tolist())
    f.input_finished()
    rows = np.stack([f.get_frame(i) for i in range(f.num_frames_ready)])
    return rows - rows.mean(0, keepdims=True)


def speech_rms(x):
    fr = x[: len(x) // 160 * 160].reshape(-1, 160)
    rms = np.sqrt((fr**2).mean(1))
    noise = np.sort(rms)[int(len(rms) * 0.2)]
    gate = max(noise * 1.5, 0.002)
    s = rms[rms >= gate]
    return float(np.sqrt((s**2).mean())) if len(s) else 0.0


def normalise(x):
    r = speech_rms(x)
    if r < 1e-4:
        return x
    return np.clip(x * min(20.0, TARGET_RMS / r), -1, 1).astype(np.float32)


class Embedder:
    def __init__(self, path):
        o = ort.SessionOptions()
        o.intra_op_num_threads = 2
        self.s = ort.InferenceSession(str(path), o, providers=["CPUExecutionProvider"])
        self.inp = self.s.get_inputs()[0].name

    def __call__(self, x):
        f = fbank(normalise(x))
        if len(f) < 30:
            return None
        return self.s.run(None, {self.inp: f[None].astype(np.float32)})[0][0]


def cos(a, b):
    return float(a @ b / (np.linalg.norm(a) * np.linalg.norm(b) + 1e-12))


def score(profile, e):
    mean = np.mean(profile, 0)
    m = cos(mean, e)
    if len(profile) < 2:
        return m
    top = sorted((cos(p, e) for p in profile), reverse=True)
    return max(m, (top[0] + top[1]) / 2)


def eer(gen, imp):
    ths = np.unique(np.concatenate([gen, imp]))
    best = (1.0, 0.0, 0.5)
    for t in ths:
        frr = float(np.mean(np.array(gen) < t))
        far = float(np.mean(np.array(imp) >= t))
        d = abs(frr - far)
        if d < best[0]:
            best = (d, t, (frr + far) / 2)
    return best[2], float(best[1])


def frr_at_far(gen, imp, far_target):
    """Lowest FRR whose FAR is <= target (None when impostor trials are too few)."""
    if len(imp) < 1 / far_target:
        return None
    t = np.sort(imp)[int(np.ceil((1 - far_target) * len(imp))) - 1] + 1e-9
    return float(np.mean(np.array(gen) < t)), float(t)


def load_clips(root: Path):
    man = json.loads((root / "manifest.json").read_text())
    out = []
    for m in man:
        f = root / "clips" / m["kind"] / f"{m['id']}.wav"
        if m.get("file", True) and f.exists() and m["kind"] in ("wake", "identity"):
            x, sr = sf.read(f, dtype="float32")
            assert sr == SR
            out.append((m, x if x.ndim == 1 else x.mean(1)))
    return out


def evaluate(root: Path, models: dict, thresholds=None) -> dict:
    clips = load_clips(root)
    owner = [(m, x) for m, x in clips if m["speaker"] == "owner"]
    guests = [(m, x) for m, x in clips if m["speaker"].startswith("guest")]
    conds = sorted({t for m, _ in owner for t in m["tags"] if t not in ("near",)})
    report = {"owner_clips": len(owner), "guest_clips": len(guests), "models": {}}
    for name, path in models.items():
        emb = Embedder(path)
        oe = [(m, emb(x)) for m, x in owner]
        oe = [(m, e) for m, e in oe if e is not None]
        ge = [e for e in (emb(x) for _, x in guests) if e is not None]
        per = {}
        all_gen, all_imp = [], []
        for c in conds:
            test = [e for m, e in oe if c in m["tags"]]
            train = [e for m, e in oe if c not in m["tags"]]
            if len(test) < 3 or len(train) < 6:
                continue
            gen = [score(train, e) for e in test]
            imp = [score(train, e) for e in ge]
            all_gen += gen
            all_imp += imp
            per[c] = {
                "n": len(test),
                "median": float(np.median(gen)),
                "p05": float(np.percentile(gen, 5)),
                "impostor_max": float(max(imp)) if imp else None,
            }
        r = {"conditions": per, "genuine_trials": len(all_gen), "impostor_trials": len(all_imp)}
        if all_gen and all_imp:
            e, t = eer(all_gen, all_imp)
            r["eer"] = e
            r["eer_threshold"] = t
            r["frr_at_far_1pct"] = frr_at_far(all_gen, all_imp, 0.01)
            r["frr_at_far_0.1pct"] = frr_at_far(all_gen, all_imp, 0.001)
            if thresholds:
                r["at_thresholds"] = {
                    str(t): {
                        "frr": float(np.mean(np.array(all_gen) < t)),
                        "far": float(np.mean(np.array(all_imp) >= t)),
                    }
                    for t in thresholds
                }
        else:
            r["note"] = "no guest trials: false acceptance NOT measured"
        report["models"][name] = r
    return report


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("dir")
    ap.add_argument("--models", nargs="*", default=[])
    ap.add_argument("--thresholds", nargs="*", type=float, default=[0.4, 0.5, 0.6])
    a = ap.parse_args()
    models = {"campplus": str(Path(__file__).parents[2] / "packages/nexa_assistant/android/src/main/assets/nexa_assistant/speaker_campplus_voxceleb_16k.onnx")}
    for m in a.models:
        k, v = m.split("=", 1)
        models[k] = v
    rep = evaluate(Path(a.dir), models, a.thresholds)
    print(json.dumps(rep, indent=1, ensure_ascii=False))
    (Path(a.dir) / "speaker_eval.json").write_text(json.dumps(rep, indent=1, ensure_ascii=False))


if __name__ == "__main__":
    main()
