#!/usr/bin/env python3
"""The school chime (assets/audio/sfx/chime.wav): the Westminster Quarters (public domain, 1793) that Japanese
schools ring between lessons, as soft bell tones. python3 tools/gen_chime.py"""
import os, wave
import numpy as np

OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "assets", "audio", "sfx", "chime.wav")
sr = 22050
notes = [("E5", 0), ("C5", 1), ("D5", 2), ("G4", 3), ("G4", 4.6), ("D5", 5.6), ("E5", 6.6), ("C5", 7.6)]
freq = {"C5": 523.25, "D5": 587.33, "E5": 659.25, "G4": 392.0}
beat = 0.55
total = int(sr * (8.6 * beat + 2.5))
out = np.zeros(total)
for n, t in notes:
    f = freq[n]
    start = int(t * beat * sr)
    dur = int(2.4 * sr)
    tt = np.arange(dur) / sr
    env = np.exp(-tt * 1.6) * np.minimum(1, tt * 200)
    tone = np.sin(2 * np.pi * f * tt) + 0.45 * np.sin(2 * np.pi * f * 2.76 * tt) * np.exp(-tt * 3) \
        + 0.25 * np.sin(2 * np.pi * f * 5.4 * tt) * np.exp(-tt * 6)
    end = min(total, start + dur)
    out[start:end] += (tone * env)[:end - start]
out = out / np.max(np.abs(out)) * 0.6
w = wave.open(OUT, "wb")
w.setnchannels(1)
w.setsampwidth(2)
w.setframerate(sr)
w.writeframes((out * 32767).astype(np.int16).tobytes())
w.close()
print("wrote", OUT)
