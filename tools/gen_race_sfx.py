#!/usr/bin/env python3
"""Race / countdown sounds (all original, generated): hyoshigi wooden clappers for the countdown tick, a faster
double clap for the last seconds, a taiko hit + clap for "go", a bright temple bell for a win, a low drum and a
falling tone for a loss. Writes assets/audio/sfx/<name>.wav (22.05 kHz mono). python3 tools/gen_race_sfx.py"""
import os, wave
import numpy as np

SR = 22050
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "audio", "sfx")
rng = np.random.default_rng(7)


def t_of(sec):
    return np.arange(int(sec * SR)) / SR


def clap(pitch=1.0, vel=1.0):
    """Hyoshigi: two hardwood blocks struck together - a short knock with a woody ring."""
    t = t_of(0.18)
    ring = sum(a * np.sin(2 * np.pi * f * pitch * t) * np.exp(-t * d) for f, a, d in
               [(1850, 0.6, 38), (2960, 0.35, 55), (4100, 0.2, 70), (920, 0.25, 30)])
    knock = rng.standard_normal(t.size) * np.exp(-t * 260) * 0.6
    return (ring + knock) * vel


def taiko(vel=1.0):
    t = t_of(0.7)
    f = 70 * np.exp(-t * 7) + 52
    body = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 5)
    return (body + rng.standard_normal(t.size) * np.exp(-t * 80) * 0.35) * vel


def bell(f0=880.0, sec=1.6):
    t = t_of(sec)
    out = sum(a * np.sin(2 * np.pi * f0 * r * t) * np.exp(-t / tau) for r, a, tau in
              [(1.0, 1.0, 0.9), (2.76, 0.45, 0.5), (5.4, 0.2, 0.25), (0.5, 0.25, 1.2)])
    return out


def mix(*parts):
    n = max(len(p) + int(off * SR) for p, off in parts)
    buf = np.zeros(n)
    for p, off in parts:
        i = int(off * SR)
        buf[i:i + len(p)] += p
    return buf


def write(name, buf, gain=0.8):
    buf = buf / (np.max(np.abs(buf)) + 1e-9) * gain
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((buf * 32767).astype(np.int16).tobytes())
    print("wrote", name)


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    write("race_tick", clap(1.0), 0.55)
    write("race_tick_urgent", mix((clap(1.15), 0.0), (clap(1.22, 0.8), 0.09)), 0.75)
    write("race_go", mix((taiko(1.0), 0.0), (clap(1.0), 0.02), (clap(1.1, 0.7), 0.14)), 0.9)
    write("race_win", mix((bell(988.0, 1.6), 0.0), (bell(1318.5, 1.4) * 0.6, 0.12)), 0.75)
    t = t_of(0.9)
    fall = np.sin(2 * np.pi * np.cumsum(330 * np.exp(-t * 1.6) + 70) / SR) * np.exp(-t * 3) * 0.6
    write("race_lose", mix((taiko(1.0), 0.0), (fall, 0.05)), 0.85)
