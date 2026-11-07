#!/usr/bin/env python3
"""Suzunari ambience beds (all original, generated): seamless 24 s loops for the town by time of day.
  amb_suzunari_day   - sparrows chattering on the wires, a soft wind, a crow far off now and then
  amb_suzunari_dusk  - crows going home, frogs starting up in the paddies, a temple bell very far away
  amb_suzunari_night - tree frogs and bell crickets (suzumushi: the town's namesake "ring-ring"), a breeze
Writes assets/audio/music/<name>.ogg (ffmpeg + libvorbis; Audio.play_ambience looks there).
python3 tools/gen_ambience_suzunari.py"""
import os, subprocess, tempfile, wave
import numpy as np

SR = 22050
SEC = 24.0
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "audio", "music")
rng = np.random.default_rng(1987)


def t_of(sec):
    return np.arange(int(sec * SR)) / SR


def lowpass(x, a):
    y = np.empty_like(x)
    acc = 0.0
    for i in range(x.size):
        acc += a * (x[i] - acc)
        y[i] = acc
    return y


def wind(level=0.25):
    n = rng.standard_normal(int(SEC * SR))
    w = lowpass(lowpass(n, 0.02), 0.05)
    swell = 0.6 + 0.4 * np.sin(2 * np.pi * t_of(SEC) / 8.0 + rng.uniform(0, 6))
    return w / (np.max(np.abs(w)) + 1e-9) * level * swell


def place(buf, snd, at):
    i = int(at * SR)
    j = min(buf.size, i + snd.size)
    if i < buf.size:
        buf[i:j] += snd[: j - i]


def sparrow():
    """Tree sparrow 'chun': a quick downward FM chirp with a bright attack."""
    d = rng.uniform(0.05, 0.11)
    t = t_of(d)
    f = rng.uniform(4200, 5600) - t / d * rng.uniform(1200, 2200)
    ph = 2 * np.pi * np.cumsum(f) / SR
    env = np.sin(np.pi * t / d) ** 1.5
    return np.sin(ph + 0.8 * np.sin(ph * 0.5)) * env


def crow():
    """A distant crow: 'kaa' - a harsh, buzzy, low formant."""
    d = rng.uniform(0.35, 0.5)
    t = t_of(d)
    f0 = rng.uniform(420, 520) * (1 - 0.15 * t / d)
    ph = 2 * np.pi * np.cumsum(f0) / SR
    s = sum(np.sin(k * ph) / k for k in range(1, 9)) + 0.4 * rng.standard_normal(t.size)
    env = np.minimum(1, t / 0.03) * np.exp(-t * 2.5)
    return lowpass(s * env, 0.25)


def frog():
    """A paddy frog: 'kero' - two short pulsed croaks."""
    out = np.zeros(int(0.32 * SR))
    for k in range(2):
        d = 0.11
        t = t_of(d)
        pulses = (np.sin(2 * np.pi * 38 * t) > 0.2).astype(float)
        tone = np.sin(2 * np.pi * rng.uniform(900, 1300) * t) * pulses * np.sin(np.pi * t / d)
        place(out, tone, k * 0.16)
    return out


def bell_cricket(dur):
    """Suzumushi: a pure ~4.4 kHz 'riiin' with a fast tremolo, in phrases."""
    t = t_of(dur)
    f = rng.uniform(4200, 4600)
    trem = 0.5 + 0.5 * np.sin(2 * np.pi * rng.uniform(28, 36) * t)
    env = np.minimum(1, t / 0.05) * np.minimum(1, (dur - t) / 0.08)
    return np.sin(2 * np.pi * f * t) * trem * env


def temple_bell():
    t = t_of(6.0)
    return sum(a * np.sin(2 * np.pi * 110 * r * t) * np.exp(-t / tau) for r, a, tau in
               [(1.0, 1.0, 2.5), (2.76, 0.4, 1.4), (5.4, 0.2, 0.6), (0.5, 0.3, 3.0)])


def loopify(buf, fade=2.0):
    """Crossfade the tail into the head so the bed loops without a click."""
    n = int(fade * SR)
    head, tail = buf[:n].copy(), buf[-n:]
    k = np.linspace(0, 1, n)
    buf[:n] = head * k + tail * (1 - k)
    return buf[:-n]


def write_ogg(name, buf, gain=0.5):
    buf = buf / (np.max(np.abs(buf)) + 1e-9) * gain
    pcm = (buf * 32767).astype(np.int16)
    with tempfile.TemporaryDirectory() as d:
        wav_path = os.path.join(d, name + ".wav")
        with wave.open(wav_path, "wb") as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(SR)
            w.writeframes(pcm.tobytes())
        out = os.path.join(OUT, name + ".ogg")
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav_path, "-c:a", "libvorbis", "-q:a", "3", out], check=True)
    print("wrote", name)


def day():
    buf = wind(0.22)
    at = 0.3
    while at < SEC - 1:
        for _ in range(rng.integers(2, 7)):  # a little burst of chatter
            place(buf, sparrow() * rng.uniform(0.25, 0.6), at)
            at += rng.uniform(0.08, 0.22)
        at += rng.uniform(0.6, 2.4)
    for at in rng.uniform(2, SEC - 2, 2):
        place(buf, crow() * 0.25, at)
        place(buf, crow() * 0.2, at + 0.6)
    return loopify(buf)


def dusk():
    buf = wind(0.15)
    for at in rng.uniform(0.5, SEC - 2, 6):
        for k in range(rng.integers(2, 4)):
            place(buf, crow() * rng.uniform(0.2, 0.35), at + k * 0.55)
    at = 0.2
    while at < SEC - 1:
        place(buf, frog() * rng.uniform(0.15, 0.35), at)
        at += rng.uniform(0.35, 1.1)
    place(buf, temple_bell() * 0.18, 9.0)
    return loopify(buf)


def night():
    buf = wind(0.08)
    at = 0.1
    while at < SEC - 1:
        place(buf, frog() * rng.uniform(0.2, 0.45), at)
        at += rng.uniform(0.25, 0.7)
    for voice in range(3):  # three bell crickets, each in its own rhythm
        at = rng.uniform(0, 1.5)
        while at < SEC - 1:
            d = rng.uniform(0.25, 0.6)
            place(buf, bell_cricket(d) * rng.uniform(0.08, 0.16), at)
            at += d + rng.uniform(0.15, 0.6)
    return loopify(buf)


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    write_ogg("amb_suzunari_day", day())
    write_ogg("amb_suzunari_dusk", dusk())
    write_ogg("amb_suzunari_night", night())
