"""SYNTHETIC stand-in for a pulled `voice_setup` folder, to test the
evaluators before real recordings exist. 'Owner' = Piper kareem, 'guests' =
macOS Majed. These numbers say nothing about a real person.
"""
import json
import sys
from pathlib import Path

import numpy as np
import soundfile as sf
from scipy.signal import lfilter

import train  # reuses reverb/noise helpers

rng = np.random.default_rng(11)
SR = 16000


def cond(x, tag):
    x = x / (np.abs(x).max() + 1e-9)
    if tag == "quiet":
        x = x * 10 ** (-24 / 20)
    elif tag == "loud":
        x = np.clip(x * 0.95, -1, 1)
    elif tag == "far":
        x = train.reverb(lfilter([0.3], [1, -0.7], x).astype(np.float32)) * 10 ** (-18 / 20)
    elif tag == "noise":
        n = train.babble([x], len(x))
        x = train.mix_snr(x * 0.3, n, 8)
    else:
        x = x * 0.3
    pad = np.zeros(int(0.5 * SR), np.float32)
    nz = 0.0005 * rng.standard_normal(len(x) + 2 * len(pad)).astype(np.float32)
    return np.clip(np.concatenate([pad, x, pad]) + nz, -1, 1).astype(np.float32)


def main(out):
    out = Path(out)
    data = Path("data")
    pos = sorted((data / "pos").glob("piper_*.wav"))
    ident = sorted((data / "neg").glob("piper_*.wav"))[::3]
    guest_pos = sorted((data / "pos").glob("say_*.wav"))
    guest_ident = sorted((data / "neg").glob("say_*.wav"))[::4]
    man = []

    def add(speaker, kind, tag, src, i):
        x = train.trim(train.load(src))
        c = cond(x, tag)
        cid = f"{speaker}_{kind}_{tag}_{i}"
        f = out / "clips" / kind / f"{cid}.wav"
        f.parent.mkdir(parents=True, exist_ok=True)
        sf.write(f, (c * 32767).astype(np.int16), SR, subtype="PCM_16")
        man.append({"id": cid, "kind": kind, "prompt": "x", "tags": [tag], "speaker": speaker, "file": True})

    tags = ["normal", "quiet", "loud", "far", "noise"]
    for i, p in enumerate(pos[:60]):
        add("owner", "wake", tags[i % 5], p, i)
    for i, p in enumerate(ident[:60]):
        add("owner", "identity", tags[i % 5], p, i)
    for i, p in enumerate(guest_pos[:20]):
        add("guest_1", "wake", "normal", p, i)
    for i, p in enumerate(guest_ident[:20]):
        add("guest_1", "identity", "normal", p, i)
    negs = sorted((data / "neg").glob("piper_*.wav"))[1::5]
    for i, p in enumerate(negs[:24]):
        add("owner", "negative", "normal", p, i)
    pool = [train.trim(train.load(f)) for f in sorted((data / "neg").glob("say_*.wav"))[::10]]
    for i in range(4):
        bg = (train.babble(pool, SR * 30) * 0.05).astype(np.float32)
        f = out / "clips" / "background" / f"owner_background_{i}.wav"
        f.parent.mkdir(parents=True, exist_ok=True)
        sf.write(f, (bg * 32767).astype(np.int16), SR, subtype="PCM_16")
        man.append({"id": f"owner_background_{i}", "kind": "background", "prompt": "x", "tags": ["background"], "speaker": "owner", "file": True})
    (out / "manifest.json").write_text(json.dumps(man))
    (out / "SYNTHETIC").write_text("synthetic stand-in; not a real person\n")
    print("clips", len(man))


if __name__ == "__main__":
    main(sys.argv[1])
