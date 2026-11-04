"""Synthetic TTS clips for the wake word «يا أمير» (positives) and hard negatives.

Every clip is 16 kHz mono int16 WAV under data/{pos,neg}/. This is SYNTHETIC
data only (macOS 'Majed' + Piper ar_JO-kareem). It cannot stand in for the
owner's voice; real, consented owner clips are added with `--owner-dir` in
train.py. Provenance goes to data/manifest.json.
"""
import json
import subprocess
import sys
import tempfile
from pathlib import Path

import numpy as np
import soundfile as sf
from piper import PiperVoice, SynthesisConfig
from scipy.signal import resample_poly

ROOT = Path(__file__).parent
OUT = ROOT / "data"
SR = 16000

POSITIVE = [
    "يا أمير",
    "يَا أَمِير",
    "يا امير",
    "يا أميير",
    "يا أَمير",
    "هلا يا أمير",
]

# Near-misses first: these are what a sloppy detector fires on.
NEAR_MISS = [
    "يا لبيب", "يا أمين", "يا أمل", "يا أمي", "أمير", "يا سمير", "يا منير",
    "يا كبير", "يا وزير", "يا أخي", "يا أحمد", "يا أمان", "يا عمير",
    "أمير المؤمنين", "الأمير", "يا إمام", "يا رئيس", "يا سيدي", "يا محمد",
    "يا حسين", "يا علي", "أمر", "يا أمر", "إمارة", "يا أميرة", "أميرة",
]
GENERAL = [
    "مرحبا كيف حالك اليوم", "شلونك شخبارك", "شنو تسوي هسه", "اريد اعرف الطقس",
    "افتح الكاميرا من فضلك", "ما اكدر اسمعك زين", "شكرا جزيلا لك",
    "اتصل بالمكتب الان", "وين اكو مطعم قريب", "الساعة كم هسه",
    "غير لون التطبيق", "اعرض لي الصور", "كلمني بعدين", "ابو حسين وصل",
    "الخبر الرئيسي اليوم عن الاقتصاد", "اليوم الجو حار جدا في بغداد",
    "هذا البرنامج يعرض الاخبار الرياضية", "رجاء اغلق الباب خلفك",
    "المباراة تبدأ بعد ساعة", "نحتاج اجتماع قبل الظهر", "سأرسل لك الملف غدا",
    "وين راح الولد", "تعال بسرعة", "لا تنسى المفاتيح", "الشاي جاهز",
    "السلام عليكم ورحمة الله", "ان شاء الله خير", "ما شاء الله عليك",
    "يعطيك العافية", "الله يسلمك", "خلينا نروح", "شكو ماكو",
    "اني اسمع صوت غريب", "افتح الباب لو سمحت", "ابي اطلب طعام",
    "هل تستطيع مساعدتي", "ما هو موعد الرحلة", "اين تقع المحطة",
]
ENGLISH = ["hey assistant", "okay what time is it", "play some music please",
           "good morning everyone", "call mom", "what is the weather"]


def to16k(x, sr):
    x = np.asarray(x, dtype=np.float32)
    if sr != SR:
        g = np.gcd(sr, SR)
        x = resample_poly(x, SR // g, sr // g).astype(np.float32)
    return x


def save(path, x):
    path.parent.mkdir(parents=True, exist_ok=True)
    x = np.clip(x, -1, 1)
    sf.write(path, (x * 32767).astype(np.int16), SR, subtype="PCM_16")


def piper_clips(voice, text, grid):
    for i, (ls, ns, nw) in enumerate(grid):
        cfg = SynthesisConfig(length_scale=ls, noise_scale=ns, noise_w_scale=nw)
        a = np.concatenate([c.audio_float_array for c in voice.synthesize(text, syn_config=cfg)])
        yield i, to16k(a, voice.config.sample_rate)


def say_clip(text, voice="Majed", rate=170):
    with tempfile.TemporaryDirectory() as d:
        aiff, wav = Path(d) / "a.aiff", Path(d) / "a.wav"
        subprocess.run(["say", "-v", voice, "-r", str(rate), "-o", str(aiff), text], check=True)
        subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-i", str(aiff), "-ar", str(SR), "-ac", "1", str(wav)], check=True)
        x, _ = sf.read(wav, dtype="float32")
        return x


def main():
    voice = PiperVoice.load(str(ROOT / "voices/ar_JO-kareem-medium.onnx"))
    pos_grid = [(ls, ns, nw) for ls in (0.8, 0.95, 1.1, 1.3) for ns in (0.4, 0.667, 0.9) for nw in (0.5, 0.8)]
    neg_grid = [(ls, ns, nw) for ls in (0.85, 1.0, 1.2) for ns in (0.5, 0.8) for nw in (0.6,)]
    manifest = {"positives": [], "negatives": []}
    n = 0
    for pi, text in enumerate(POSITIVE):
        for i, x in piper_clips(voice, text, pos_grid):
            save(OUT / f"pos/piper_{pi}_{i}.wav", x); n += 1
        for r in (130, 150, 170, 190, 210, 240):
            save(OUT / f"pos/say_{pi}_{r}.wav", say_clip(text, rate=r)); n += 1
        manifest["positives"].append(text)
    for ti, text in enumerate(NEAR_MISS + GENERAL):
        for i, x in piper_clips(voice, text, neg_grid):
            save(OUT / f"neg/piper_{ti}_{i}.wav", x); n += 1
        for r in (140, 180, 220):
            save(OUT / f"neg/say_{ti}_{r}.wav", say_clip(text, rate=r)); n += 1
    for ti, text in enumerate(ENGLISH):
        for v in ("Samantha", "Daniel", "Karen"):
            try:
                save(OUT / f"neg/en_{v}_{ti}.wav", say_clip(text, voice=v)); n += 1
            except Exception as e:  # voice not installed
                print("skip", v, e, file=sys.stderr)
    manifest["negatives"] = NEAR_MISS + GENERAL + ENGLISH
    manifest["engines"] = ["macOS say Majed (ar)", "Piper ar_JO-kareem-medium", "macOS en voices"]
    (OUT / "manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=1))
    print("clips:", n)


if __name__ == "__main__":
    main()
