"""Train heads for further wake phrases on the same speech-embedding features.

    python phrase_models.py amir abbas

SYNTHETIC data only (macOS Majed + Piper kareem), so a head made here is
shipped as `experimental`, never `validated`: it needs consented real-device
recordings (see docs/qa/wake-word-yaameer.md) before it can be called ready.
"""
import json
import sys
from pathlib import Path

import numpy as np

import gen_data as gd
import train as tr
from piper import PiperVoice

ROOT = Path(__file__).parent

PHRASES = {
    # «أمير» alone. «يا أمير» contains it, so the existing «يا أمير» clips count as positives.
    "amir": dict(
        label="أمير",
        pos=["أمير", "أَمِير", "امير", "أميير", "أمـير"],
        reuse_pos=True,
        near=["أمين", "أميرة", "سمير", "منير", "أمل", "أمي", "أمان", "عمير", "أمر", "يا لبيب",
              "كبير", "وزير", "أميركا", "الأمير"],
        drop_neg={"أمير", "أمير المؤمنين", "الأمير"},  # in the older negative list: now positives/ambiguous
    ),
    "abbas": dict(
        label="عباس",
        pos=["عباس", "عَبَّاس", "عباااس", "عبّاس", "عبـاس"],
        reuse_pos=False,
        near=["عبد", "عباد", "عيسى", "ياسين", "عباية", "عبود", "عبدالله", "علاس", "ناس",
              "عباسي", "رباس", "حساس", "أساس", "عمار"],
        drop_neg=set(),
    ),
}


def main(ids):
    voice = PiperVoice.load(str(ROOT / "voices/ar_JO-kareem-medium.onnx"))
    pos_grid = [(ls, ns, nw) for ls in (0.8, 1.0, 1.25) for ns in (0.4, 0.8) for nw in (0.5, 0.8)]
    neg_grid = [(ls, ns, 0.6) for ls in (0.9, 1.15) for ns in (0.5, 0.8)]
    base_neg = sorted((ROOT / "data/neg").glob("*.wav"))
    texts = gd.NEAR_MISS + gd.GENERAL
    old_pos = sorted((ROOT / "data/pos").glob("*.wav"))
    report = {}
    for pid in ids:
        cfg = PHRASES[pid]
        out = ROOT / f"data_{pid}"
        n = 0
        if not (out / "pos").exists():
            for pi, text in enumerate(cfg["pos"]):
                for i, x in gd.piper_clips(voice, text, pos_grid):
                    gd.save(out / f"pos/piper_{pi}_{i}.wav", x); n += 1
                for r in (130, 160, 190, 220):
                    gd.save(out / f"pos/say_{pi}_{r}.wav", gd.say_clip(text, rate=r)); n += 1
            for ti, text in enumerate(cfg["near"]):
                for i, x in gd.piper_clips(voice, text, neg_grid):
                    gd.save(out / f"neg/piper_{ti}_{i}.wav", x); n += 1
                for r in (150, 200):
                    gd.save(out / f"neg/say_{ti}_{r}.wav", gd.say_clip(text, rate=r)); n += 1
            print(pid, "generated", n)
        pos = sorted((out / "pos").glob("*.wav")) + (old_pos if cfg["reuse_pos"] else [])
        neg = sorted((out / "neg").glob("*.wav"))
        for f in base_neg:  # the shared negatives, minus entries that are positives here
            kind, idx = f.stem.split("_")[0], f.stem.split("_")[1]
            if kind in ("piper", "say") and idx.isdigit() and texts[int(idx)] in cfg["drop_neg"]:
                continue
            neg.append(f)
        if not cfg["reuse_pos"]:
            neg += old_pos  # «يا أمير» is a negative for «عباس»
        pool = [tr.trim(tr.load(f)) for f in neg[:: max(1, len(neg) // 60)]]
        # honest check: train on Piper, test on the macOS voice
        tr_p = [f for f in pos if "piper" in f.name]; te_p = [f for f in pos if "say" in f.name]
        tr_n = [f for f in neg if "piper" in f.name]; te_n = [f for f in neg if "piper" not in f.name]
        X, Y = tr.build(tr_p, tr_n, pool, 10, 3, 300)
        clf, mu, sd = tr.fit(X, Y)
        report[pid] = tr.evaluate(clf, mu, sd, te_p, te_n, pool, f"{pid}: train piper -> test macOS say")
        tr.export(clf, mu, sd, ROOT / f"models/{pid}_head_piper_only.bin")
        # shipped head: everything
        X, Y = tr.build(pos, neg, pool, 10, 3, 400)
        clf, mu, sd = tr.fit(X, Y)
        tr.export(clf, mu, sd, ROOT / f"models/{pid}_head.bin")
    (ROOT / "data/phrase_models_report.json").write_text(json.dumps(report, indent=1))


if __name__ == "__main__":
    main(sys.argv[1:] or list(PHRASES))
