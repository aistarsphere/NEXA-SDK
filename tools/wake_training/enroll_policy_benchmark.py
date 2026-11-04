"""How much does one natural sentence tell? (LibriSpeech, 19 speakers; English read speech.)

Enrol with 1 / 2 / 3 sentences (3-6 s of speech each), verify with a DIFFERENT sentence of
2-4 s, in clean / quiet / babble / far-field conditions. Reports genuine and stranger score
percentiles with the app's scoring rule and level normalisation, and the threshold that
gives <=1 % stranger acceptance. These numbers choose the decision rule of the quick setup;
they are not Iraqi-Arabic or owner accuracy.
"""
import json, random
from pathlib import Path
import numpy as np, soundfile as sf
import speaker_eval as se, speaker_benchmark as sb, train

SR = 16000
ROOT = Path(__file__).parent
rng = np.random.default_rng(5); random.seed(5)

def seg(x, lo, hi):
    n = int(random.uniform(lo, hi) * SR)
    n = min(n, len(x)); a = random.randint(0, len(x) - n)
    return x[a:a + n]

def main():
    spk = sb.load_speakers(min_utts=14)
    ids = sorted(spk)
    pool = [sb.read(f)[: 6 * SR] for k in ids for f in spk[k][:2]]
    emb = se.Embedder(str(ROOT.parents[1] / "packages/nexa_assistant/android/src/main/assets/nexa_assistant/speaker_campplus_voxceleb_16k.onnx"))
    conds = ["clean", "quiet", "babble10dB", "far_reverb"]
    enroll = {k: [] for k in ids}
    ver = {k: {c: [] for c in conds} for k in ids}
    for k in ids:
        files = spk[k][:]; random.shuffle(files)
        for f in files[:3]:
            e = emb(sb.condition(seg(sb.read(f), 3, 6), "clean", pool))
            if e is not None: enroll[k].append(e)
        for f in files[3:9]:
            x = seg(sb.read(f), 2, 4)
            for c in conds:
                e = emb(sb.condition(x, c, pool))
                if e is not None: ver[k][c].append(e)
    out = {}
    for n in (1, 2, 3):
        for c in conds:
            gen, imp = [], []
            for k in ids:
                prof = enroll[k][:n]
                gen += [se.score(prof, e) for e in ver[k][c]]
                for o in ids:
                    if o != k: imp += [se.score(prof, e) for e in ver[o][c][:3]]
            g, i = np.array(gen), np.array(imp)
            t = float(np.sort(i)[int(np.ceil(0.99 * len(i))) - 1])
            out[f"n{n}_{c}"] = dict(gen_p05=float(np.percentile(g, 5)), gen_p25=float(np.percentile(g, 25)), gen_med=float(np.median(g)),
                                    imp_p99=t, imp_max=float(i.max()), frr_at_far1=float(np.mean(g < t)), n_gen=len(g), n_imp=len(i))
            print(f"n={n} {c:11s} genuine med {np.median(g):.2f} p05 {np.percentile(g,5):.2f} | stranger p99 {t:.2f} max {i.max():.2f} | FRR@FAR1% {np.mean(g<t):.3f}")
    (ROOT / "data/enroll_policy_benchmark.json").write_text(json.dumps(out, indent=1))

if __name__ == "__main__":
    main()
