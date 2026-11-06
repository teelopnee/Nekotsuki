#!/usr/bin/env python3
"""SPRITE FORGE v2 - chibi HD-2D pixel-art characters for ODD-SPACE.

Characters are 3D signed-distance rigs (round cones, ellipsoids, rounded boxes)
on a small forward-kinematics skeleton.  Every frame is ray-marched at native
pixel resolution and post-processed into pixel art: banded cel shading,
selective inner outlines, dark outer contour and painted face details
(eye whites, irises, brows, mouth) plus clothing decals.

The sheets are PALETTE-INDEXED: each pixel stores (material slot, shade band)
instead of a colour:
    R = slot * 16 + 8      (16 slots: skin, hair, top, pants, boots, accent,
                            coat, gear, glow, eye-white, iris, dark, scarf,
                            cap, gloves, flash)
    G = band * 40 + 20     (0 outer contour, 1 inner line, 2 shadow, 3 base,
                            4 light, 5 highlight)
At runtime assets/shaders/indexed_sprite.gdshader looks the colour up in a
6x16 palette built by src/core/character_look.gd, so a few dozen geometry
variants become endless unique characters (random skin/hair/outfit colours).

Output (assets/sprites/characters/):
  <variant>.png + <variant>.json   (frame layout, rows per anim/direction, tags)
  variants.json                    (index of variants + tags for the randomiser)
Directions rendered: S, SE, E, NE, N (west side mirrored in-engine).

Usage:  python3 tools/sprite_forge.py [variant ...]
        python3 tools/sprite_forge.py --preview h03 h05   (coloured previews in /tmp)
"""
import colorsys
import json
import math
import os
import random
import sys

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_DIR = os.path.join(ROOT, "assets", "sprites", "characters")
FRAME_W, FRAME_H = 64, 64
FOOT_ROW = 60
ELEVATION = math.radians(22)
DIRS = {"S": 0.0, "SE": 45.0, "E": 90.0, "NE": 135.0, "N": 180.0}
LIGHT = np.array([-0.55, 0.72, 0.42])
LIGHT = LIGHT / np.linalg.norm(LIGHT)

SLOTS = {"skin": 0, "hair": 1, "top": 2, "pants": 3, "boots": 4, "accent": 5, "coat": 6, "gear": 7,
         "glow": 8, "eyewhite": 9, "iris": 10, "dark": 11, "scarf": 12, "cap": 13, "gloves": 14, "flash": 15}
FLAT = {"glow": 4, "flash": 5, "eyewhite": 4, "iris": 3, "dark": 3}  # material -> fixed band

# ---------------------------------------------------------------------------- math


def norm(v):
    n = np.linalg.norm(v)
    return v / n if n > 1e-9 else v


def v3(x, y, z):
    return np.array([x, y, z], dtype=np.float64)


def rot_axis(v, axis, ang):
    axis = norm(axis)
    c, s = math.cos(ang), math.sin(ang)
    return v * c + np.cross(axis, v) * s + axis * np.dot(axis, v) * (1 - c)


class Frame3:
    def __init__(self, facing_deg):
        p = math.radians(facing_deg)
        self.F = v3(math.sin(p), 0, math.cos(p))
        self.U = v3(0, 1, 0)
        self.R = np.cross(self.F, self.U)

    def w(self, x, y, z):
        return self.R * x + self.U * y + self.F * z


# ---------------------------------------------------------------------------- SDF


def P_sphere(c, r, mat):
    return {"k": "sph", "c": np.asarray(c, float), "r": r, "mat": mat}


def P_cone(a, b, r1, r2, mat):
    return {"k": "cone", "a": np.asarray(a, float), "b": np.asarray(b, float), "r1": r1, "r2": r2, "mat": mat}


def P_ell(c, radii, basis, mat):
    return {"k": "ell", "c": np.asarray(c, float), "rad": np.asarray(radii, float), "M": np.asarray(basis, float), "mat": mat}


def P_box(c, half, basis, rnd, mat):
    return {"k": "box", "c": np.asarray(c, float), "h": np.asarray(half, float), "M": np.asarray(basis, float), "rnd": rnd, "mat": mat}


def sdf(prim, P):
    k = prim["k"]
    if k == "sph":
        return np.linalg.norm(P - prim["c"], axis=1) - prim["r"]
    if k == "ell":
        q = (P - prim["c"]) @ prim["M"].T
        r = prim["rad"]
        k0 = np.linalg.norm(q / r, axis=1)
        k1 = np.linalg.norm(q / (r * r), axis=1)
        return k0 * (k0 - 1.0) / np.maximum(k1, 1e-9)
    if k == "box":
        q = np.abs((P - prim["c"]) @ prim["M"].T) - prim["h"]
        return np.linalg.norm(np.maximum(q, 0.0), axis=1) + np.minimum(np.max(q, axis=1), 0.0) - prim["rnd"]
    a, b, r1, r2 = prim["a"], prim["b"], prim["r1"], prim["r2"]
    ba = b - a
    l2 = float(np.dot(ba, ba))
    if l2 < 1e-6:
        return np.linalg.norm(P - a, axis=1) - max(r1, r2)
    rr = r1 - r2
    a2 = l2 - rr * rr
    il2 = 1.0 / l2
    pa = P - a
    y = pa @ ba
    z = y - l2
    x2v = pa * l2 - np.outer(y, ba)
    x2 = np.sum(x2v * x2v, axis=1)
    y2 = y * y * l2
    z2 = z * z * l2
    kk = np.sign(rr) * rr * rr * x2
    d1 = np.sqrt(x2 + z2) * il2 - r2
    d2 = np.sqrt(x2 + y2) * il2 - r1
    d3 = (np.sqrt(np.maximum(x2 * a2 * il2, 0.0)) + y * rr) * il2 - r1
    return np.where(np.sign(z) * a2 * z2 > kk, d1, np.where(np.sign(y) * a2 * y2 < kk, d2, d3))


def scene_sdf(prims, P):
    best = np.full(len(P), 1e9)
    ids = np.full(len(P), -1, dtype=np.int32)
    for i, pr in enumerate(prims):
        d = sdf(pr, P)
        m = d < best
        best = np.where(m, d, best)
        ids = np.where(m, i, ids)
    return best, ids


class Camera:
    def __init__(self):
        e = ELEVATION
        self.fwd = norm(v3(0, -math.sin(e), -math.cos(e)))
        self.right = v3(1, 0, 0)
        self.up = norm(np.cross(self.right, self.fwd))
        xs = np.arange(FRAME_W) - FRAME_W / 2 + 0.5
        ys = FOOT_ROW - (np.arange(FRAME_H) + 0.5)
        gx, gy = np.meshgrid(xs, ys)
        self.sx = gx.ravel()
        self.sy = gy.ravel()
        self.origins = np.outer(self.sx, self.right) + np.outer(self.sy, self.up) - self.fwd * 70.0


CAM = Camera()


def render(prims):
    """Ray-march one frame. Returns per-pixel (slot, band, depth)."""
    n = len(CAM.sx)
    t = np.full(n, 30.0)
    alive = np.ones(n, dtype=bool)
    hit = np.zeros(n, dtype=bool)
    ids = np.full(n, -1, dtype=np.int32)
    for _ in range(60):
        idx = np.nonzero(alive)[0]
        if len(idx) == 0:
            break
        P = CAM.origins[idx] + np.outer(t[idx], CAM.fwd)
        d, pid = scene_sdf(prims, P)
        close = d < 0.05
        hit[idx[close]] = True
        ids[idx[close]] = pid[close]
        alive[idx[close]] = False
        t[idx] += np.maximum(d, 0.04) * 0.9
        alive &= t < 140.0
    slot = np.full(n, -1, dtype=np.int32)
    band = np.zeros(n, dtype=np.int32)
    depth = np.full(n, 1e9)
    hidx = np.nonzero(hit)[0]
    if len(hidx) == 0:
        return slot, band, depth
    P = CAM.origins[hidx] + np.outer(t[hidx], CAM.fwd)
    nrm = np.zeros((len(hidx), 3))
    for ax in range(3):
        o = np.zeros(3)
        o[ax] = 0.12
        dp, _ = scene_sdf(prims, P + o)
        dm, _ = scene_sdf(prims, P - o)
        nrm[:, ax] = dp - dm
    nrm /= np.maximum(np.linalg.norm(nrm, axis=1, keepdims=True), 1e-9)
    lam = np.clip(nrm @ LIGHT, 0, 1)
    rim = np.clip(1.0 - np.abs(nrm @ (-CAM.fwd)), 0, 1) ** 3
    sl = np.array([SLOTS[prims[i]["mat"]] for i in ids[hidx]])
    s = 0.32 + 0.62 * lam + 0.16 * rim + (sl == SLOTS["skin"]) * 0.12
    b = np.where(s < 0.46, 2, np.where(s < 0.78, 3, np.where(s < 0.97, 4, 5)))
    for m, fb in FLAT.items():
        b = np.where(sl == SLOTS[m], fb, b)
    slot[hidx] = sl
    band[hidx] = b
    depth[hidx] = t[hidx]
    return slot, band, depth


def outline(slot, band, depth):
    H, W = FRAME_H, FRAME_W
    sl = slot.reshape(H, W).copy()
    bd = band.reshape(H, W).copy()
    dp = depth.reshape(H, W)
    solid = sl >= 0
    inner = np.zeros((H, W), dtype=bool)
    outer_src = np.full((H, W), -1)
    for dy, dx in ((0, 1), (0, -1), (1, 0), (-1, 0)):
        nb_solid = np.zeros((H, W), dtype=bool)
        nb_dp = np.full((H, W), 1e9)
        nb_sl = np.full((H, W), -1)
        ys = slice(max(0, -dy), H - max(0, dy))
        yd = slice(max(0, dy), H - max(0, -dy))
        xs = slice(max(0, -dx), W - max(0, dx))
        xd = slice(max(0, dx), W - max(0, -dx))
        nb_solid[ys, xs] = solid[yd, xd]
        nb_dp[ys, xs] = dp[yd, xd]
        nb_sl[ys, xs] = sl[yd, xd]
        inner |= solid & nb_solid & ((dp - nb_dp) > 2.2)
        take = (~solid) & nb_solid & (outer_src < 0)
        outer_src = np.where(take, nb_sl, outer_src)
    flat_slots = [SLOTS[m] for m in FLAT]
    inner &= ~np.isin(sl, flat_slots)
    bd[inner] = 1
    om = outer_src >= 0
    sl[om] = np.where(np.isin(outer_src[om], flat_slots), SLOTS["dark"], outer_src[om])
    bd[om] = 0
    return sl, bd


DECALS = []  # (kind, point, normal, extra) appended by builders, painted after render


def paint_decals(sl, bd, depth):
    H, W = FRAME_H, FRAME_W
    dp = depth.reshape(H, W)
    skinish = (SLOTS["skin"], SLOTS["iris"], SLOTS["eyewhite"], SLOTS["dark"])

    def put(x, y, slot, band, need=None):
        if 0 <= x < W and 0 <= y < H and sl[y, x] >= 0 and bd[y, x] > 0:
            if need is not None and sl[y, x] not in need:
                return
            sl[y, x] = slot
            bd[y, x] = band

    for kind, pt, nrm, extra in DECALS:
        if np.dot(nrm, -CAM.fwd) < 0.15:
            continue
        sx = float(np.dot(pt, CAM.right))
        sy = float(np.dot(pt, CAM.up))
        px, py = int(math.floor(sx + FRAME_W / 2)), int(math.floor(FOOT_ROW - sy))
        if not (1 <= px < W - 1 and 4 <= py < H - 1):
            continue
        t_pt = float(np.dot(pt - CAM.origins[py * W + px], CAM.fwd))
        if dp[py, px] > 1e8 or t_pt - dp[py, px] > 1.8:
            continue
        if kind == "eye":
            # Eye anchor = bottom pixel of the iris column. `outer` points away from the nose.
            side = extra["side"]
            outer = -1 if side > 0 else 1
            if np.dot(nrm, CAM.right) * side < 0:
                outer = -outer
            profile = abs(float(np.dot(nrm, CAM.right))) > 0.6
            iris_slot = SLOTS["glow"] if extra.get("cyber") else SLOTS["iris"]
            ib = 3 if iris_slot == SLOTS["iris"] else 4
            _eye(put, px, py, outer, profile, extra.get("style", "eye"), iris_slot, ib, skinish)
            _brow(put, px, py, outer, extra.get("brow", "normal"))
            if extra.get("tears"):
                _tears(put, px, py, outer, extra["tears"], extra.get("tf", 0))
            if extra.get("glasses"):
                _glasses(put, px, py, outer, profile)
        elif kind == "closed":
            put(px, py - 1, SLOTS["dark"], 3, skinish)
            put(px + 1, py - 1, SLOTS["dark"], 3, skinish)
        elif kind == "mouth":
            _mouth(put, px, py, extra.get("style", "line"), extra.get("small"))
        elif kind == "cheek":
            _cheek(put, px, py, extra.get("style", "blush"))
        elif kind == "dot":
            put(px, py, SLOTS[extra["slot"]], extra["band"])
    return sl, bd


# Face parts. The "flash" slot's bands 1-4 are face FX colours (only band 5 is used by
# geometry): 1 deep blush, 2 blush / tongue / hearts, 3 tear, 4 tear highlight.
def _eye(put, px, py, o, profile, style, isl, ib, sk):
    D, W, F, G = SLOTS["dark"], SLOTS["eyewhite"], SLOTS["flash"], SLOTS["glow"]

    def base(lid=-2, shine=False):
        put(px, py, isl, ib, sk)
        if lid < -1:
            put(px, py - 1, isl, ib, sk)
        put(px, py + lid, D, 3, sk)
        if not profile:
            put(px + o, py, W, 4, sk)
            if lid < -1:
                put(px + o, py - 1, W, 4, sk)
            put(px + o, py + lid, D, 3, sk)
        if shine:
            put(px, py - 1, W, 5, sk)

    if style in ("sleepy", "flat"):
        base(lid=-1)
    elif style == "teary":
        base(shine=True)
        put(px + o, py + 1, F, 3, sk)
    elif style == "star":
        base()
        put(px, py - 1, F, 5, sk)
        put(px + o, py, F, 5, sk)
    elif style == "closed":
        put(px, py - 1, D, 3, sk)
        put(px + o, py - 1, D, 3, sk)
    elif style == "happy":
        put(px - o, py, D, 3, sk)
        put(px, py - 1, D, 3, sk)
        put(px + o, py, D, 3, sk)
    elif style == "shut":
        put(px + o, py - 2, D, 3, sk)
        put(px, py - 1, D, 3, sk)
        put(px - o, py - 1, D, 3, sk)
        put(px + o, py, D, 3, sk)
    elif style == "wide":
        for dx in (-o, 0, o):
            put(px + dx, py - 2, D, 3, sk)
            put(px + dx, py - 1, W, 4, sk)
            put(px + dx, py, W, 4, sk)
        put(px, py, isl, 1, sk)
    elif style == "dead":
        for dy in (3, 4, 5):
            for dx in (-o, 0, o, 2 * o):
                put(px + dx, py - dy, SLOTS["skin"], 2, (SLOTS["skin"],))
        for dx in (0, o):
            put(px + dx, py, isl, 1, sk)
            put(px + dx, py - 1, isl, 1, sk)
            put(px + dx, py - 2, D, 3, sk)
    elif style == "cat":
        for dx in (-o, 0, o):
            put(px + dx, py - 2, D, 3, sk)
        for dy in (0, 1):
            put(px - o, py - dy, G, 4, sk)
            put(px, py - dy, D, 3, sk)
            put(px + o, py - dy, G, 4, sk)
    elif style == "heart":
        put(px - o, py - 1, F, 1, sk)
        put(px + o, py - 1, F, 1, sk)
        put(px, py - 1, F, 2, sk)
        put(px, py, F, 1, sk)
    elif style == "dizzy":
        for dx in (-o, 0, o):
            put(px + dx, py - 2, D, 3, sk)
            put(px + dx, py, D, 3, sk)
        put(px - o, py - 1, D, 3, sk)
        put(px + o, py - 1, D, 3, sk)
        put(px, py - 1, W, 4, sk)
    else:
        base()


BROWS = {"normal": (4, 4), "worried": (5, 4), "angry": (3, 4), "raised": (5, 5), "flat": (3, 3)}


def _brow(put, px, py, o, style):
    rows = BROWS.get(style)
    if rows:
        put(px, py - rows[0], SLOTS["hair"], 2, (SLOTS["skin"],))
        put(px + o, py - rows[1], SLOTS["hair"], 2, (SLOTS["skin"],))


def _tears(put, px, py, o, level, tf):
    F = SLOTS["flash"]
    if level == 1:
        put(px + o, py + 1, F, 3)
        put(px + o, py + 2, F, 4)
        return
    n = 3 if level == 2 else 7
    for c in ((px + o,) if level == 2 else (px + o, px)):
        for k in range(n):
            put(c, py + 1 + k, F, 4 if (k + tf) % 3 == 0 else 3)


def _glasses(put, px, py, o, profile):
    for dx in (-o, 0, o, 2 * o):
        put(px + dx, py - 2, SLOTS["dark"], 3)
    put(px + 2 * o, py - 1, SLOTS["dark"], 3)
    if not profile:
        put(px + o, py - 1, SLOTS["eyewhite"], 5)


# (dx, dy, code): l = soft line (skin band 1), d = dark, w = teeth, t = tongue
MOUTHS = {
    "smile": [(-1, -1, "l"), (0, 0, "l"), (1, 0, "l"), (2, -1, "l")],
    "frown": [(-1, 0, "l"), (0, -1, "l"), (1, -1, "l"), (2, 0, "l")],
    "flat": [(-1, 0, "l"), (0, 0, "l"), (1, 0, "l"), (2, 0, "l")],
    "wavy": [(-1, 0, "d"), (0, -1, "d"), (1, 0, "d"), (2, -1, "d")],
    "open": [(0, 0, "d"), (1, 0, "d"), (0, 1, "d"), (1, 1, "d")],
    "o": [(0, 0, "d")],
    "wail": [(x, y, "d") for x in (-1, 0, 1, 2) for y in (0, 1)] + [(-1, 2, "d"), (0, 2, "t"), (1, 2, "t"), (2, 2, "d")],
    "grin": [(x, 0, "w") for x in (-1, 0, 1, 2)] + [(-2, 0, "d"), (3, 0, "d"), (0, 1, "d"), (1, 1, "d")],
    "grit": [(x, 0, "w") for x in (-1, 0, 1, 2)] + [(x, y, "d") for x in (-1, 0, 1, 2) for y in (-1, 1)],
    "pout": [(0, 0, "d"), (1, 0, "d"), (0, -1, "l")],
    "yan": [(-2, -1, "l"), (-1, 0, "l"), (0, 0, "l"), (1, 0, "l"), (2, 0, "l"), (3, -1, "l")],
    "cat": [(-2, 0, "d"), (-1, 1, "d"), (0, 0, "d"), (1, 1, "d"), (2, 0, "d")],
}


def _mouth(put, px, py, style, small=False):
    if style not in MOUTHS:
        put(px, py, SLOTS["skin"], 1, (SLOTS["skin"],))
        if not small:
            put(px + 1, py, SLOTS["skin"], 1, (SLOTS["skin"],))
        return
    code = {"l": (SLOTS["skin"], 1), "d": (SLOTS["dark"], 3), "w": (SLOTS["eyewhite"], 4), "t": (SLOTS["flash"], 2)}
    for dx, dy, c in MOUTHS[style]:
        put(px + dx, py + dy, code[c][0], code[c][1], (SLOTS["skin"], SLOTS["dark"], SLOTS["eyewhite"]))


def _cheek(put, px, py, style):
    F, need = SLOTS["flash"], (SLOTS["skin"],)
    if style == "blush":
        put(px, py, F, 2, need)
        put(px + 1, py, F, 2, need)
    elif style == "blush2":
        for dx in (-1, 0, 1):
            put(px + dx, py, F, 2, need)
        put(px - 1, py - 1, F, 1, need)
        put(px + 1, py - 1, F, 1, need)


def encode(sl, bd):
    img = np.zeros((FRAME_H, FRAME_W, 4), dtype=np.uint8)
    m = sl >= 0
    img[m, 0] = sl[m] * 16 + 8
    img[m, 1] = bd[m] * 40 + 20
    img[m, 3] = 255
    return img


# ---------------------------------------------------------------------------- poses

ANIMS = [
    ("idle", 8, 7, True), ("walk", 8, 11, True), ("run", 8, 14, True), ("roll", 6, 16, False),
    ("shoot", 6, 18, False), ("slash1", 6, 18, False), ("slash2", 6, 18, False), ("slash3", 7, 16, False),
    ("guard", 4, 14, False), ("hurt", 3, 12, False), ("dead", 6, 9, False), ("talk", 8, 7, True),
    ("charge", 6, 12, True),
    # Life animations (NPC activities, crowds, surrender):
    ("sit", 8, 5, True), ("phone", 8, 6, True), ("dance", 8, 10, True), ("cheer", 6, 9, True),
    ("wave", 6, 9, True), ("surrender", 6, 6, True),
]
# Emotion animations (each carries its own face). Rendered only for variants with cfg "school".
EMOTE_ANIMS = [
    ("cry", 6, 8, True), ("wail", 6, 9, True), ("pout", 4, 4, True), ("fluster", 6, 10, True),
    ("shock", 5, 12, False), ("angry", 6, 9, True), ("sulk", 4, 4, True), ("peek", 4, 3, True),
    ("tug", 4, 5, True), ("bow", 6, 8, False), ("dogeza", 6, 6, False), ("laugh", 6, 10, True),
    ("think", 4, 3, True), ("facepalm", 4, 5, False), ("shrug", 5, 8, False), ("sneeze", 6, 10, False),
    ("yandere", 4, 3, True), ("loaf", 4, 3, True), ("pat_get", 4, 5, True), ("pat_give", 4, 5, True),
    ("offer", 4, 4, True), ("pinky", 4, 4, False), ("faint", 6, 9, False), ("happy", 6, 10, True),
    ("sad", 4, 4, True),
]


def ease(t):
    return t * t * (3 - 2 * t)


def pose(anim, t):
    s, c, tau = math.sin, math.cos, 2 * math.pi
    p = {"bob": 0.0, "lean": 0.0, "twist": 0.0, "head_tilt": 0.0, "crouch": 0.0, "roll": 0.0,
         "lthigh": 0.0, "lknee": 0.05, "rthigh": 0.0, "rknee": 0.05,
         "larm": (0.06, 0.18), "rarm": (0.06, 0.18), "lelbow": 0.15, "relbow": 0.15,
         "rarm_dir": None, "rfore_dir": None, "larm_dir": None, "lfore_dir": None,
         "weapon": "holster", "flash": False, "lay": 0.0, "tail": 0.0, "blink": False,
         "side": 0.0, "eyes": None, "brows": None, "mouth": None, "cheek": None, "tears": 0,
         "tf": int(t * 6), "ears": None}
    if anim == "idle":
        b = s(t * tau)
        p["bob"] = -0.5 + 0.5 * b
        p["larm"] = p["rarm"] = (0.05, 0.18 + 0.03 * b)
        p["head_tilt"] = 0.04 * s(t * tau + 1)
        p["tail"] = 0.15 * s(t * tau)
        p["blink"] = 0.8 <= t < 0.9
    elif anim in ("walk", "run"):
        run = anim == "run"
        amp = 0.8 if run else 0.5
        ph = t * tau
        p["lthigh"], p["rthigh"] = amp * s(ph), -amp * s(ph)
        p["lknee"] = 0.15 + (1.1 if run else 0.6) * max(0.0, -s(ph + 0.6))
        p["rknee"] = 0.15 + (1.1 if run else 0.6) * max(0.0, s(ph + 0.6))
        arm = 0.9 if run else 0.55
        p["larm"], p["rarm"] = (-arm * s(ph), 0.18), (arm * s(ph), 0.18)
        p["lelbow"] = p["relbow"] = 1.25 if run else 0.35
        p["bob"] = (1.6 if run else 1.0) * abs(c(ph)) - (1.4 if run else 0.8)
        p["lean"] = 0.22 if run else 0.05
        p["twist"] = 0.12 * s(ph)
        p["tail"] = (0.7 if run else 0.3) + 0.2 * s(ph * 2)
    elif anim == "roll":
        p["crouch"] = 0.75 if 0.05 < t < 0.95 else 0.35
        p["roll"] = ease(t) * tau
        p["lthigh"] = p["rthigh"] = 1.6
        p["lknee"] = p["rknee"] = 2.3
        p["larm"] = p["rarm"] = (1.3, 0.25)
        p["lelbow"] = p["relbow"] = 1.8
        p["tail"] = 0.9
        p["blink"] = True
    elif anim == "shoot":
        aim = ease(min(1.0, t * 1.6))
        p["rarm_dir"] = (0.05, -0.2 + 0.25 * aim, 0.4 + 0.6 * aim)
        p["rfore_dir"] = (0.02, 0.05 * aim, 1.0)
        p["weapon"] = "blaster"
        p["flash"] = 0.3 < t < 0.55
        p["lean"] = -0.08 if 0.3 < t < 0.6 else 0.02
        p["larm"] = (0.25, 0.22)
        p["lelbow"] = 0.9
        p["lthigh"], p["rthigh"] = 0.25, -0.2
    elif anim in ("slash1", "slash2", "slash3"):
        k = t
        if anim == "slash1":
            a = -1.6 + 3.0 * ease(min(1, max(0, (k - 0.2) / 0.45)))
            p["rarm_dir"] = (math.sin(-a) * 0.9, 0.05, math.cos(a))
            p["rfore_dir"] = (math.sin(-a - 0.2), 0.05, math.cos(a + 0.2))
            p["twist"] = -0.35 + 0.7 * ease(min(1, max(0, (k - 0.2) / 0.45)))
        elif anim == "slash2":
            a = 1.5 - 3.0 * ease(min(1, max(0, (k - 0.15) / 0.45)))
            p["rarm_dir"] = (math.sin(-a) * 0.9, -0.3 + 0.5 * k, math.cos(a))
            p["rfore_dir"] = (math.sin(-a + 0.3), -0.1 + 0.5 * k, math.cos(a))
            p["twist"] = 0.35 - 0.7 * ease(min(1, max(0, (k - 0.15) / 0.45)))
        else:
            a = -2.4 + 3.3 * ease(min(1, max(0, (k - 0.3) / 0.35)))
            p["rarm_dir"] = (0.05, math.cos(a + math.pi), -math.sin(a + math.pi) + 0.2)
            p["rfore_dir"] = (0.05, math.cos(a + math.pi - 0.2), -math.sin(a + math.pi - 0.2) + 0.3)
            p["crouch"] = 0.25 if 0.55 < k < 0.85 else 0.0
            p["lean"] = 0.25 if 0.55 < k else -0.1
        p["weapon"] = "baton"
        p["larm"] = (0.3, 0.4)
        p["lelbow"] = 1.1
        p["lthigh"], p["rthigh"] = 0.35, -0.3
        p["lknee"] = 0.35
        p["tail"] = 0.6
    elif anim == "guard":
        k = ease(min(1, t * 2.0))
        p["rarm_dir"] = (-0.4 * k, 0.3 + 0.5 * k, 0.6)
        p["rfore_dir"] = (-0.9 * k, 0.6, 0.3)
        p["larm_dir"] = (0.4 * k, 0.3 + 0.4 * k, 0.6)
        p["lfore_dir"] = (0.9 * k, 0.5, 0.3)
        p["weapon"] = "baton"
        p["crouch"] = 0.18
        p["lthigh"], p["rthigh"] = 0.3, -0.25
        p["lknee"] = p["rknee"] = 0.5
    elif anim == "hurt":
        k = math.sin(t * math.pi)
        p["lean"] = -0.35 * k
        p["head_tilt"] = -0.3 * k
        p["larm"] = p["rarm"] = (-0.3 * k, 0.5 * k + 0.14)
        p["lthigh"] = 0.2 * k
        p["bob"] = -0.5 * k
        p["blink"] = True
    elif anim == "dead":
        k = ease(min(1.0, t * 1.25))
        p["lay"] = k
        p["lean"] = -0.4 * k
        p["larm"] = (-0.4, 0.5 * k + 0.14)
        p["rarm"] = (-0.2, 0.7 * k + 0.14)
        p["lthigh"] = 0.3 * k
        p["lknee"] = 0.6 * k
        p["blink"] = k > 0.4
    elif anim == "talk":
        g = s(t * 2 * math.pi)
        p["rarm_dir"] = (0.25 + 0.15 * g, -0.35 + 0.15 * max(0, g), 0.6)
        p["rfore_dir"] = (0.1, 0.35 + 0.3 * g, 0.8)
        p["larm"] = (0.1, 0.2)
        p["head_tilt"] = 0.08 * g
        p["bob"] = -0.4 + 0.4 * abs(g)
    elif anim == "sit":
        # Perched on a bench, feet dangling and kicking a little.
        g = s(t * tau)
        p["crouch"] = 1.0
        p["bob"] = -0.2 + 0.2 * g
        p["lthigh"], p["rthigh"] = 1.42, 1.42
        p["lknee"], p["rknee"] = 1.25 + 0.25 * g, 1.25 - 0.25 * g
        p["larm"], p["rarm"] = (0.65, 0.3), (0.65, 0.3)
        p["lelbow"] = p["relbow"] = 0.7
        p["head_tilt"] = 0.05 * s(t * tau + 1.3)
        p["blink"] = 0.55 <= t < 0.65
    elif anim == "phone":
        # Head down, doom-scrolling a wristpad; thumb taps.
        g = s(t * tau * 2)
        p["bob"] = -0.3 + 0.2 * s(t * tau)
        p["rarm_dir"] = (-0.15, -0.55, 0.45)
        p["rfore_dir"] = (-0.45, 0.35 + 0.05 * g, 0.75)
        p["larm_dir"] = (0.2, -0.6, 0.35)
        p["lfore_dir"] = (0.55, 0.3, 0.7)
        p["head_tilt"] = 0.22
        p["weapon"] = "phone"
        p["blink"] = 0.3 <= t < 0.38
    elif anim == "dance":
        g = s(t * tau)
        h = s(t * tau * 2)
        p["bob"] = -0.9 + 1.2 * abs(h)
        p["twist"] = 0.35 * g
        p["lean"] = 0.06 * h
        p["rarm_dir"] = (0.5 + 0.3 * g, 0.75 + 0.2 * h, 0.2)
        p["rfore_dir"] = (0.1, 0.9, 0.2 - 0.3 * g)
        p["larm_dir"] = (-0.5 + 0.3 * g, 0.2 - 0.6 * h, 0.4)
        p["lfore_dir"] = (-0.2, 0.6, 0.5)
        p["lthigh"], p["rthigh"] = 0.35 * max(0.0, g), 0.35 * max(0.0, -g)
        p["lknee"], p["rknee"] = 0.2 + 0.6 * max(0.0, g), 0.2 + 0.6 * max(0.0, -g)
        p["head_tilt"] = 0.12 * g
        p["tail"] = 0.4 + 0.3 * h
    elif anim == "cheer":
        g = s(t * tau)
        p["bob"] = 1.2 * max(0.0, g) - 0.4
        p["rarm_dir"] = (0.45, 0.9, 0.15 + 0.15 * g)
        p["rfore_dir"] = (0.25, 1.0, 0.1)
        p["larm_dir"] = (-0.45, 0.9, 0.15 - 0.15 * g)
        p["lfore_dir"] = (-0.25, 1.0, 0.1)
        p["lthigh"] = p["rthigh"] = -0.15 * max(0.0, g)
        p["lknee"] = p["rknee"] = 0.1 + 0.4 * max(0.0, g)
        p["head_tilt"] = -0.1
        p["tail"] = 0.6
    elif anim == "wave":
        g = s(t * tau)
        p["rarm_dir"] = (0.55, 0.75, 0.3)
        p["rfore_dir"] = (0.35 * g, 1.0, 0.15)
        p["larm"] = (0.05, 0.18)
        p["head_tilt"] = 0.06 * g
        p["bob"] = -0.3 + 0.3 * abs(g)
    elif anim == "surrender":
        # Down on one knee, hands up, head bowed - the boss is begging.
        g = s(t * tau)
        p["crouch"] = 0.85
        p["lthigh"], p["lknee"] = 1.45, 1.5
        p["rthigh"], p["rknee"] = -0.15, 1.75
        p["rarm_dir"] = (0.5, 0.85, 0.25)
        p["rfore_dir"] = (0.05, 1.0, 0.0)
        p["larm_dir"] = (-0.5, 0.85, 0.25)
        p["lfore_dir"] = (-0.05, 1.0, 0.0)
        p["head_tilt"] = 0.25 + 0.04 * g
        p["bob"] = 0.15 * g
        p["blink"] = 0.4 <= t < 0.6
    elif anim == "charge":
        g = s(t * 2 * math.pi)
        p["rarm_dir"] = (0.7, 0.2, 0.6)
        p["larm_dir"] = (-0.7, 0.2, 0.6)
        p["rfore_dir"] = (0.3, 0.6, 0.7)
        p["lfore_dir"] = (-0.3, 0.6, 0.7)
        p["crouch"] = 0.2 + 0.05 * g
        p["lthigh"], p["rthigh"] = 0.35, -0.35
        p["weapon"] = "baton"
    if anim in EMOTES:
        EMOTES[anim](p, t)
    return p


def _e_cry(p, t):
    k = abs(math.sin(t * 2 * math.pi * 2))
    p["bob"] = -0.6 + 0.4 * k
    p["head_tilt"] = 0.22 + 0.05 * k
    p["rarm_dir"], p["rfore_dir"] = (-0.25, 0.45, 0.85), (-0.6, 0.78, 0.15)
    p["larm_dir"], p["lfore_dir"] = (0.25, 0.45, 0.85), (0.6, 0.78, 0.15)
    p["lknee"] = p["rknee"] = 0.25
    p.update(eyes="shut", brows="worried", mouth="wavy", cheek="blush", tears=2, ears="droop")


def _e_wail(p, t):
    k = math.sin(t * 2 * math.pi * 2)
    p["head_tilt"], p["lean"], p["bob"] = -0.28 + 0.04 * k, -0.08, -0.4 + 0.3 * abs(k)
    p["larm"], p["rarm"] = (0.05, 0.35 + 0.05 * k), (0.05, 0.35 - 0.05 * k)
    p["lelbow"] = p["relbow"] = 0.25
    p["lknee"] = p["rknee"] = 0.35
    p["crouch"] = 0.12
    p.update(eyes="shut", brows="worried", mouth="wail", cheek="blush2", tears=3, ears="flat")


def _e_pout(p, t):
    g = math.sin(t * 2 * math.pi)
    p["rarm_dir"], p["rfore_dir"] = (0.05, -0.55, 0.8), (-1.0, 0.15, 0.15)
    p["larm_dir"], p["lfore_dir"] = (-0.05, -0.5, 0.8), (1.0, 0.25, 0.1)
    p["twist"], p["side"], p["head_tilt"] = 0.3, 0.06 * g, -0.06
    p.update(eyes="flat", brows="angry", mouth="pout", cheek="blush", ears="flat")


def _e_fluster(p, t):
    g = math.sin(t * 2 * math.pi)
    p["rarm_dir"], p["rfore_dir"] = (-0.05, 0.35, 0.9), (-0.5, 0.85, 0.2)
    p["larm_dir"], p["lfore_dir"] = (0.05, 0.35, 0.9), (0.5, 0.85, 0.2)
    p["twist"], p["side"], p["bob"], p["head_tilt"] = 0.18 * g, 0.1 * g, -0.3 + 0.3 * abs(g), 0.12
    p["lthigh"], p["rthigh"] = 0.1 * g, -0.1 * g
    p["lknee"] = p["rknee"] = 0.3
    p.update(eyes="shut", brows="worried", mouth="wavy", cheek="blush2", ears="up")


def _e_shock(p, t):
    k = math.sin(min(1.0, t * 1.6) * math.pi * 0.5)
    jump = math.sin(min(1.0, t * 2.2) * math.pi)
    p["bob"], p["lean"] = 2.2 * jump - 0.2, -0.25 * k
    p["rarm_dir"], p["rfore_dir"] = (0.55, 0.55 * k, 0.45), (0.15, 1.0, 0.1)
    p["larm_dir"], p["lfore_dir"] = (-0.55, 0.55 * k, 0.45), (-0.15, 1.0, 0.1)
    p["lthigh"], p["lknee"] = 0.3 * jump, 0.4 * jump
    p.update(eyes="wide", brows="raised", mouth="open", ears="up")


def _e_angry(p, t):
    g = math.sin(t * 2 * math.pi)
    p["lthigh"], p["rthigh"] = 0.55 * max(0.0, g), 0.55 * max(0.0, -g)
    p["lknee"], p["rknee"] = 0.2 + 0.7 * max(0.0, g), 0.2 + 0.7 * max(0.0, -g)
    p["larm"] = p["rarm"] = (-0.15, 0.32)
    p["lelbow"] = p["relbow"] = 0.9
    p["lean"], p["bob"], p["head_tilt"] = 0.12, -0.3 + 0.5 * abs(g), 0.05
    p.update(eyes="eye", brows="angry", mouth="grit", ears="flat")


def _e_sulk(p, t):
    g = math.sin(t * 2 * math.pi)
    p["crouch"], p["lean"], p["head_tilt"], p["bob"] = 1.4, 0.35, 0.35 + 0.03 * g, 0.1 * g
    p["lthigh"] = p["rthigh"] = 1.9
    p["lknee"] = p["rknee"] = 2.6
    p["larm"] = p["rarm"] = (1.25, 0.15)
    p["lelbow"] = p["relbow"] = 0.9
    p.update(eyes="sleepy", brows="worried", mouth="frown", ears="droop")


def _e_peek(p, t):
    g = math.sin(t * 2 * math.pi)
    p["side"], p["crouch"], p["head_tilt"] = 0.32 + 0.04 * g, 0.15, -0.04
    p["rarm_dir"], p["rfore_dir"] = (0.25, 0.35, 0.9), (-0.05, 0.5, 0.85)
    p["larm_dir"], p["lfore_dir"] = (0.1, 0.1, 0.9), (0.2, 0.6, 0.75)
    p.update(brows="worried", ears="up")


def _e_tug(p, t):
    g = math.sin(t * 2 * math.pi)
    p["rarm_dir"], p["rfore_dir"] = (-0.05, -0.25, 1.0), (-0.15, 0.05 + 0.08 * g, 1.0)
    p["larm_dir"], p["lfore_dir"] = (0.15, -0.55, 0.6), (0.85, 0.45, 0.35)
    p["head_tilt"], p["lean"], p["bob"] = 0.3, 0.08, -0.2 + 0.1 * g
    p.update(eyes="sleepy", brows="worried", mouth="wavy", cheek="blush", ears="droop")


def _e_bow(p, t):
    k = ease(min(1.0, t * 1.8))
    p["lean"], p["head_tilt"] = 0.75 * k, 0.15 * k
    p["larm"] = p["rarm"] = (0.25 * k, 0.06)
    p["lelbow"] = p["relbow"] = 0.3
    p.update(eyes="closed")


def _e_dogeza(p, t):
    k = ease(min(1.0, t * 1.5))
    p["crouch"], p["head_tilt"] = 1.43 * k, 0.25 * k
    p["lthigh"] = p["rthigh"] = 1.57 * k
    p["lknee"] = p["rknee"] = 3.0 * k
    p["lean"] = 1.3 * ease(max(0.0, min(1.0, (t - 0.3) * 1.6)))
    p["larm_dir"], p["lfore_dir"] = (-0.15, -0.55, 0.9), (0.05, -0.2, 1.0)
    p["rarm_dir"], p["rfore_dir"] = (0.15, -0.55, 0.9), (-0.05, -0.2, 1.0)
    p.update(eyes="shut", brows="worried", mouth="wavy")


def _e_laugh(p, t):
    g = math.sin(t * 2 * math.pi * 2)
    p["lean"], p["head_tilt"], p["bob"] = -0.15, -0.18, -0.2 + 0.5 * abs(g)
    p["larm_dir"], p["lfore_dir"] = (0.15, -0.5, 0.75), (0.9, 0.2, 0.3)
    p["rarm_dir"], p["rfore_dir"] = (0.35, 0.1, 0.8), (0.0, 0.8 + 0.2 * g, 0.4)
    p.update(eyes="happy", mouth="grin", cheek="blush", ears="up")


def _e_think(p, t):
    g = math.sin(t * 2 * math.pi)
    p["rarm_dir"], p["rfore_dir"] = (-0.1, -0.05, 1.0), (-0.45, 0.88, 0.1)
    p["larm_dir"], p["lfore_dir"] = (0.1, -0.6, 0.6), (0.9, 0.2, 0.3)
    p["head_tilt"], p["side"] = -0.06, 0.08 + 0.02 * g
    p.update(eyes="sleepy", brows="raised", mouth="flat")


def _e_facepalm(p, t):
    k = ease(min(1.0, t * 2.0))
    p["rarm_dir"], p["rfore_dir"] = (-0.3, 0.5 * k, 0.85), (-0.7, 0.7 * k, 0.15)
    p["head_tilt"], p["bob"] = 0.35 * k, -0.6 * k
    p.update(eyes="closed", brows="worried", mouth="frown")


def _e_shrug(p, t):
    k = math.sin(min(1.0, t * 1.4) * math.pi)
    p["larm_dir"], p["lfore_dir"] = (-0.6, -0.5 + 0.2 * k, 0.45), (-0.45, 0.45, 0.75)
    p["rarm_dir"], p["rfore_dir"] = (0.6, -0.5 + 0.2 * k, 0.45), (0.45, 0.45, 0.75)
    p["bob"], p["head_tilt"], p["side"] = 0.5 * k, -0.06, 0.12 * k
    p.update(eyes="flat", brows="raised", mouth="flat")


def _e_sneeze(p, t):
    if t < 0.55:
        k = t / 0.55
        p["lean"], p["head_tilt"] = -0.25 * k, -0.3 * k
        p.update(eyes="shut", brows="raised", mouth="open")
    else:
        k = (t - 0.55) / 0.45
        p["lean"], p["head_tilt"] = 0.35 * (1 - k * 0.5), 0.3
        p["rarm_dir"], p["rfore_dir"] = (-0.2, 0.2, 0.9), (-0.6, 0.75, 0.2)
        p.update(eyes="shut", mouth="o")


def _e_yandere(p, t):
    g = math.sin(t * 2 * math.pi)
    p["larm_dir"], p["lfore_dir"] = (0.3, -0.6, -0.55), (0.75, 0.15, -0.6)
    p["rarm_dir"], p["rfore_dir"] = (-0.3, -0.6, -0.55), (-0.75, 0.15, -0.6)
    p["head_tilt"], p["side"], p["bob"] = 0.14, 0.22 + 0.02 * g, -0.1
    p.update(eyes="dead", brows="none", mouth="yan", ears="perk")


def _e_loaf(p, t):
    _e_sulk(p, t)
    p["lean"], p["head_tilt"] = 0.6, 0.25
    p["larm"] = p["rarm"] = (1.35, 0.05)
    p["lelbow"] = p["relbow"] = 0.6
    p.update(eyes="closed", brows="none", mouth="cat", ears="up")


def _e_pat_get(p, t):
    g = math.sin(t * 2 * math.pi)
    p["head_tilt"], p["bob"] = 0.2 + 0.04 * g, -0.4 + 0.2 * abs(g)
    p["larm_dir"], p["lfore_dir"] = (0.2, -0.55, 0.65), (0.75, 0.45, 0.45)
    p["rarm_dir"], p["rfore_dir"] = (-0.2, -0.55, 0.65), (-0.75, 0.45, 0.45)
    p.update(eyes="happy", mouth="cat", cheek="blush2", ears="flat")


def _e_pat_give(p, t):
    g = math.sin(t * 2 * math.pi)
    p["rarm_dir"], p["rfore_dir"] = (-0.05, 0.25, 1.0), (-0.05, -0.35 + 0.15 * g, 1.0)
    p.update(eyes="sleepy", mouth="smile")


def _e_offer(p, t):
    g = math.sin(t * 2 * math.pi)
    p["rarm_dir"], p["rfore_dir"] = (-0.15, -0.15, 1.0), (-0.35, 0.2 + 0.05 * g, 1.0)
    p["larm_dir"], p["lfore_dir"] = (0.15, -0.15, 1.0), (0.35, 0.2 + 0.05 * g, 1.0)
    p["head_tilt"], p["lean"], p["weapon"] = 0.35, 0.12, "bento"
    p.update(eyes="shut", brows="worried", mouth="wavy", cheek="blush2", ears="droop")


def _e_pinky(p, t):
    k = ease(min(1.0, t * 1.6))
    p["rarm_dir"], p["rfore_dir"] = (0.0, -0.1 + 0.15 * k, 1.0), (-0.2, 0.5 * k, 0.85)
    p.update(mouth="smile", cheek="blush")


def _e_faint(p, t):
    k = ease(min(1.0, t * 1.2))
    p["lay"], p["lean"] = k, -0.4 * k
    p["larm"], p["rarm"] = (-0.4, 0.5 * k + 0.14), (-0.2, 0.7 * k + 0.14)
    p.update(eyes="dizzy", mouth="open")


def _e_happy(p, t):
    g = math.sin(t * 2 * math.pi)
    p["bob"] = 1.6 * max(0.0, g) - 0.3
    p["rarm_dir"], p["rfore_dir"] = (-0.05, -0.35, 0.75), (-0.35, 0.9, 0.25)
    p["larm_dir"], p["lfore_dir"] = (0.05, -0.35, 0.75), (0.35, 0.9, 0.25)
    p["lthigh"] = p["rthigh"] = -0.1 * max(0.0, g)
    p["lknee"] = p["rknee"] = 0.15 + 0.5 * max(0.0, g)
    p.update(eyes="happy", mouth="grin", cheek="blush", ears="up")


def _e_sad(p, t):
    g = math.sin(t * 2 * math.pi)
    p["head_tilt"], p["bob"], p["lean"] = 0.35, -0.8 + 0.1 * g, 0.08
    p["larm"] = p["rarm"] = (0.12, 0.06)
    p["lelbow"] = p["relbow"] = 0.1
    p.update(eyes="sleepy", brows="worried", mouth="frown", ears="droop")


EMOTES = {a[0]: globals()["_e_" + a[0]] for a in EMOTE_ANIMS}


# ---------------------------------------------------------------------------- humanoid

BODIES = {"slim": (0.97, 0.86), "normal": (1.0, 1.0), "broad": (1.06, 1.36), "short": (0.88, 1.02)}


def build_human(cfg, facing, anim, t):
    fr = Frame3(facing)
    p = pose(anim, t)
    S, Wd = BODIES[cfg.get("body", "normal")]
    acc = set(cfg.get("acc", []))
    outfit = cfg.get("outfit", "jacket")
    robot = cfg.get("robot", False)
    prims = []
    hip_h = 13.6 * S
    thigh_l, shin_l = 6.5 * S, 6.3 * S
    torso_h = 10.6 * S
    head_r = 9.6
    shoulder_w = 6.3 * Wd
    hip_w = 2.9 * Wd
    pelvis = fr.w(0, hip_h - p["crouch"] * 6.0 + p["bob"], 0)
    up = rot_axis(fr.U, fr.R, -p["lean"])
    fwd = rot_axis(fr.F, fr.R, -p["lean"])
    if p["side"]:
        up = rot_axis(up, fwd, p["side"])
    fwd_t = rot_axis(fwd, up, p["twist"])
    right_t = np.cross(fwd_t, up)
    basis = [right_t, up, fwd_t]
    tail = p["tail"]

    def bp(x, y, z):
        return pelvis + right_t * x + up * y + fwd_t * z

    chest = bp(0, torso_h * 0.66, 0.2)
    neck = bp(0, torso_h + 0.6, 0.3)
    head_c = neck + rot_axis(up, right_t, -p["head_tilt"]) * (head_r * 0.86) + fwd_t * 0.3
    pants = "gear" if robot else "pants"
    top = "gear" if robot else "top"

    # legs
    for side, th, kn in ((-1, p["lthigh"], p["lknee"]), (1, p["rthigh"], p["rknee"])):
        hip = pelvis + fr.R * (side * hip_w) + up * 0.4
        d1 = norm(-fr.U * math.cos(th) + fr.F * math.sin(th))
        knee = hip + d1 * thigh_l
        a2 = th - kn
        d2 = norm(-fr.U * math.cos(a2) + fr.F * math.sin(a2))
        ankle = knee + d2 * shin_l
        leg = "skin" if cfg.get("skirt") == "short" else pants
        prims.append(P_cone(hip, knee, 3.2 * min(Wd, 1.25), 2.8, leg))
        prims.append(P_cone(knee, ankle, 2.8, 2.6, leg))
        prims.append(P_cone(knee + (ankle - knee) * 0.4, ankle, 3.0, 2.9, "boots"))
        prims.append(P_ell(ankle + fr.F * 1.7 - fr.U * 1.0, [2.7, 2.0, 3.9], [fr.R, fr.U, fr.F], "boots"))

    # torso / outfit
    prims.append(P_ell(bp(0, 2.0, 0), [5.0 * Wd, 3.6, 3.7], basis, pants))
    prims.append(P_ell(chest, [6.4 * Wd, 6.6, 4.4], basis, top))
    if cfg.get("skirt"):
        hem = -3.0 if cfg["skirt"] == "short" else -10.8
        prims.append(P_cone(bp(0, 3.0, 0), bp(0, hem, -0.3), 4.9 * Wd, (6.1 if cfg["skirt"] == "short" else 6.4) * Wd, pants))
    if outfit not in ("hoodie", "coat", "suit", "blazer", "teacher", "track", "miko", "apron") or robot:
        prims.append(P_ell(bp(0, 3.5, 0.1), [5.5 * Wd, 1.8, 4.0], basis, "accent"))
        DECALS.append(("dot", bp(0, 3.6, 4.15), fwd_t, {"slot": "accent", "band": 5}))
    if outfit in ("jacket", "coat", "suit", "blazer", "track") and not robot:
        prims.append(P_ell(chest + fwd_t * -0.4, [6.8 * Wd, 6.9, 4.7], basis, "coat"))
        if outfit == "coat":
            prims.append(P_cone(bp(0, torso_h * 0.5, -0.3), bp(0, -8.0, -1.0 - 2.4 * tail), 6.5 * Wd, 6.4 * Wd, "coat"))
        else:
            prims.append(P_ell(bp(0, 2.6, -0.2), [5.9 * Wd, 2.6, 4.4], basis, "coat"))
        prims.append(P_ell(chest + fwd_t * 3.7, [2.1, 5.4, 1.4], basis, top))
        if outfit == "blazer":
            prims.append(P_box(chest + fwd_t * 4.4 + up * 0.2, [0.75, 3.4, 0.35], basis, 0.25, "accent"))
        if outfit == "suit":
            for k in range(3):
                DECALS.append(("dot", chest + fwd_t * 5.05 + up * (2.4 - k * 1.2), fwd_t, {"slot": "accent", "band": 3}))
    elif outfit == "teacher" and not robot:
        prims.append(P_ell(chest + fwd_t * -0.1, [6.9 * Wd, 6.6, 4.9], basis, "coat"))
        prims.append(P_ell(chest + fwd_t * 4.0 + up * 1.6, [2.0, 3.6, 1.2], basis, top))
        prims.append(P_box(chest + fwd_t * 4.9 + up * 1.2, [0.7, 2.6, 0.3], basis, 0.25, "accent"))
    elif outfit == "apron" and not robot:
        prims.append(P_box(bp(0, 3.5, 3.6), [4.3 * Wd, 6.8, 0.5], basis, 0.6, "accent"))
    elif outfit == "vest" and not robot:
        prims.append(P_ell(chest + fwd_t * -0.3, [6.7 * Wd, 6.5, 4.6], basis, "coat"))
        for k in range(3):
            DECALS.append(("dot", chest + fwd_t * 4.65 + up * (2.2 - k * 2.0), fwd_t, {"slot": "accent", "band": 5}))
    elif outfit == "hoodie" and not robot:
        prims.append(P_ell(neck - fwd_t * 3.0 + up * 0.5, [5.0, 3.0, 3.0], basis, top))
        prims.append(P_ell(bp(0, 3.0, 2.4), [4.0 * Wd, 2.0, 2.2], basis, top))
        for sd in (-1, 1):
            DECALS.append(("dot", chest + fwd_t * 4.45 + up * 3.0 + right_t * sd * 1.0, fwd_t, {"slot": "accent", "band": 4}))
    elif outfit == "armor":
        prims.append(P_box(chest + fwd_t * 0.4, [5.8 * Wd, 5.2, 4.4], basis, 1.6, "gear"))
        prims.append(P_box(chest + fwd_t * 4.4 + up * 0.5, [3.0, 2.8, 0.4], basis, 0.5, "accent"))
        DECALS.append(("dot", chest + fwd_t * 5.05 + up * 1.2, fwd_t, {"slot": "glow", "band": 4}))
    elif outfit == "overalls" and not robot:
        prims.append(P_box(bp(0, 6.0, 0.2), [4.6 * Wd, 4.4, 4.0], basis, 1.0, pants))
        for sd in (-1, 1):
            DECALS.append(("dot", chest + fwd_t * 4.45 + right_t * sd * 2.6 + up * 3.0, fwd_t, {"slot": "accent", "band": 5}))
    if "pads" in acc or outfit == "armor":
        for sd in (-1, 1):
            prims.append(P_sphere(bp(sd * shoulder_w, torso_h * 0.95, 0), 3.0, "gear" if outfit == "armor" else "accent"))
    if "scarf" in acc:
        prims.append(P_ell(neck - up * 0.4, [5.6, 2.5, 4.9], basis, "scarf"))
        prims.append(P_cone(neck - fwd_t * 2.8, neck - fwd_t * (5 + 4 * tail) - up * (6 - 3 * tail) + right_t * 2, 1.7, 1.2, "scarf"))
    if "backpack" in acc or "jetpack" in acc:
        pc = chest - fwd_t * 5.4 + up * 0.5
        if "jetpack" in acc:
            prims.append(P_box(pc, [3.4, 4.4, 1.9], basis, 1.0, "gear"))
            for sd in (-1, 1):
                noz = pc + right_t * sd * 2.5 - up * 5.0
                prims.append(P_cone(pc + right_t * sd * 2.5 - up * 2.0, noz, 1.4, 1.2, "accent"))
                prims.append(P_sphere(noz - up * 0.8, 0.9, "glow"))
        else:
            prims.append(P_ell(pc, [4.0, 4.6, 2.5], basis, "gear"))

    # arms
    sleeve = "coat" if outfit in ("jacket", "coat", "suit", "blazer", "track") else ("skin" if outfit in ("tank", "vest", "overalls") else top)
    if robot:
        sleeve = "gear"

    def arm(side, swing, elbow, adir, fdir):
        sh = bp(side * shoulder_w, torso_h * 0.9, 0)
        if adir is not None:
            d1 = norm(fr.R * adir[0] + fr.U * adir[1] + fr.F * adir[2])
        else:
            d1 = norm(-fr.U * math.cos(swing[0]) + fr.F * math.sin(swing[0]))
            d1 = norm(d1 * math.cos(swing[1]) + fr.R * side * math.sin(swing[1]))
        el = sh + d1 * 5.0 * S
        if fdir is not None:
            d2 = norm(fr.R * fdir[0] + fr.U * fdir[1] + fr.F * fdir[2])
        else:
            pitch = swing[0] + elbow
            d2 = norm(-fr.U * math.cos(pitch) + fr.F * math.sin(pitch))
            d2 = norm(d2 * math.cos(swing[1] * 0.6) + fr.R * side * math.sin(swing[1] * 0.6))
        return sh, el, el + d2 * 4.7 * S, d2

    lsh, lel, lhand, _ = arm(-1, p["larm"], p["lelbow"], p["larm_dir"], p["lfore_dir"])
    if "armband" in acc:
        prims.append(P_cone(lsh + (lel - lsh) * 0.35, lsh + (lel - lsh) * 0.7, 2.95, 2.7, "accent"))
    rsh, rel, rhand, rd = arm(1, p["rarm"], p["relbow"], p["rarm_dir"], p["rfore_dir"])
    hand_mat = "gloves" if ("gloves" in acc or outfit == "armor" or robot) else "skin"
    for sh, el, hand in ((lsh, lel, lhand), (rsh, rel, rhand)):
        prims.append(P_cone(sh, el, 2.6 * min(Wd, 1.3), 2.35, sleeve))
        prims.append(P_cone(el, hand, 2.35, 2.1, sleeve))
        prims.append(P_sphere(hand, 2.25, hand_mat))

    # weapons
    w = p["weapon"]
    if w == "holster":
        prims.append(P_box(fr.w(3.4 * Wd, hip_h - 3.0, 0.4), [1.0, 2.4, 1.6], [fr.R, fr.U, fr.F], 0.4, "gear"))
    elif w == "blaster":
        gx = norm(np.cross(rd, fr.U)) if abs(np.dot(rd, fr.U)) < 0.95 else fr.R
        prims.append(P_box(rhand + rd * 3.2, [1.0, 1.4, 3.4], [gx, np.cross(rd, gx), rd], 0.4, "gear"))
        prims.append(P_sphere(rhand + rd * 6.8, 0.8, "glow"))
        if p["flash"]:
            prims.append(P_sphere(rhand + rd * 9.0, 2.2, "flash"))
    elif w == "baton":
        prims.append(P_cone(rhand - rd * 1.5, rhand + rd * 2.5, 1.0, 1.0, "gear"))
        prims.append(P_cone(rhand + rd * 2.5, rhand + rd * 12.0, 1.2, 0.9, "flash"))
    elif w == "bento":
        bc = (lhand + rhand) * 0.5 + fwd_t * 1.2 + up * 0.8
        prims.append(P_box(bc, [3.2, 1.7, 2.3], basis, 0.5, "accent"))
        prims.append(P_sphere(bc + up * 1.9, 1.0, "scarf"))
    elif w == "phone":
        # A glowing wristpad screen held between the hands.
        pc = (lhand + rhand) * 0.5 + fwd_t * 0.6 + up * 0.6
        prims.append(P_box(pc, [2.2, 1.5, 0.35], [right_t, norm(up * 0.6 + fwd_t * 0.8), norm(fwd_t * 0.6 - up * 0.8)], 0.3, "gear"))
        prims.append(P_box(pc + norm(up * 0.8 + fwd_t * 0.2) * 0.4, [1.8, 1.2, 0.2], [right_t, norm(up * 0.6 + fwd_t * 0.8), norm(fwd_t * 0.6 - up * 0.8)], 0.2, "glow"))

    # head
    hb = [right_t, up, fwd_t]
    if robot:
        prims.append(P_box(head_c, [head_r * 0.82, head_r * 0.78, head_r * 0.74], hb, 1.8, "gear"))
        prims.append(P_box(head_c + fwd_t * head_r * 0.66, [head_r * 0.62, head_r * 0.36, 0.6], hb, 0.6, "glow"))
        prims.append(P_cone(head_c + up * head_r * 0.7, head_c + up * head_r * 1.3, 0.5, 0.4, "accent"))
        prims.append(P_sphere(head_c + up * head_r * 1.4, 1.0, "glow"))
    else:
        prims.append(P_ell(head_c, [head_r, head_r * 0.96, head_r * 0.94], hb, "skin"))
        prims.append(P_ell(head_c + fwd_t * head_r * 0.2 - up * head_r * 0.42, [head_r * 0.62, head_r * 0.46, head_r * 0.6], hb, "skin"))
        for sd in (-1, 1):
            prims.append(P_ell(head_c + right_t * sd * head_r * 0.95 - up * head_r * 0.05, [1.0, 1.8, 1.4], hb, "skin"))
        eyes = "closed" if p["blink"] and not p["eyes"] else (p["eyes"] or cfg.get("eyes", "eye"))
        face = {"style": eyes, "brow": p["brows"] or cfg.get("brows", "normal"), "tears": p["tears"],
                "tf": p["tf"], "glasses": "glasses" in acc}
        for sd in (-1, 1):
            ln = norm(fwd_t * 0.86 + right_t * sd * 0.40 - up * 0.04)
            DECALS.append(("eye", head_c + ln * head_r * 0.985, ln, dict(face, side=sd, cyber="cybereye" in acc and sd == 1)))
        mn = norm(fwd_t * 0.9 - up * 0.42)
        DECALS.append(("mouth", head_c + mn * head_r * 0.92, mn, {"small": "mustache" in acc, "style": p["mouth"] or cfg.get("mouth", "line")}))
        cheek = p["cheek"] or cfg.get("cheek")
        if cheek:
            for sd in (-1, 1):
                cn = norm(fwd_t * 0.8 + right_t * sd * 0.56 - up * 0.3)
                DECALS.append(("cheek", head_c + cn * head_r * 0.98, cn, {"style": cheek}))
        if "catears" in acc and p["ears"]:
            for sd in (-1, 1):
                eb = head_c + up * head_r * 0.66 + right_t * sd * head_r * 0.56 - fwd_t * head_r * 0.08
                ed = {"up": up + right_t * sd * 0.35, "perk": up + right_t * sd * 0.25 + fwd_t * 0.35,
                      "droop": up * 0.15 + right_t * sd * 1.0 - fwd_t * 0.1,
                      "flat": up * 0.35 + right_t * sd * 0.45 - fwd_t * 0.85}[p["ears"]]
                tip = eb + norm(ed) * head_r * 0.8
                prims.append(P_cone(eb, tip, 3.3, 0.45, "hair"))
                prims.append(P_cone(eb + fwd_t * 1.4 + (tip - eb) * 0.1, eb + fwd_t * 1.0 + (tip - eb) * 0.75, 1.9, 0.3, "scarf"))
        if "ahoge" in acc:
            a0 = head_c + up * head_r * 0.98 + fwd_t * 1.0
            a1 = a0 + norm(up + right_t * 0.45 + fwd_t * 0.2) * 3.6
            prims.append(P_cone(a0, a1, 1.0, 0.6, "hair"))
            prims.append(P_cone(a1, a1 + norm(fwd_t * 0.7 - up * 0.4 + right_t * 0.3) * 2.6, 0.6, 0.25, "hair"))
        if "choker" in acc:
            prims.append(P_ell(neck - up * 0.7, [3.3, 0.9, 3.1], basis, "accent"))
            prims.append(P_sphere(neck - up * 1.4 + fwd_t * 3.0, 1.15, "glow"))
        if "headphones" in acc:
            prims.append(P_ell(neck - up * 0.3, [4.4, 1.0, 4.0], basis, "gear"))
            for sd in (-1, 1):
                prims.append(P_sphere(neck + right_t * sd * 3.4 + fwd_t * 1.6 - up * 0.6, 1.5, "accent"))
        if "camera" in acc:
            cc = chest + fwd_t * 4.9 - up * 1.8
            prims.append(P_box(cc, [1.9, 1.3, 0.9], basis, 0.3, "gear"))
            prims.append(P_sphere(cc + fwd_t * 1.0, 0.7, "dark"))
        hair = cfg.get("hair", "short")
        hc = "hair"
        if "helmet" in acc:
            prims.append(P_ell(head_c + up * 1.0 - fwd_t * 0.3, [head_r * 1.12, head_r * 1.06, head_r * 1.12], hb, "cap"))
            prims.append(P_ell(head_c + fwd_t * head_r * 0.62 + up * 0.4, [head_r * 0.86, head_r * 0.3, head_r * 0.45], hb, "glow"))
        elif hair == "hood":
            prims.append(P_ell(head_c + up * head_r * 0.25 - fwd_t * head_r * 0.25, [head_r * 1.18, head_r * 1.12, head_r * 1.12], hb, "coat"))
            prims.append(P_ell(head_c + up * head_r * 0.55 + fwd_t * head_r * 0.62, [head_r * 0.7, head_r * 0.2, head_r * 0.3], hb, hc))
        elif hair != "bald":
            prims.append(P_ell(head_c + up * head_r * 0.44 - fwd_t * head_r * 0.30, [head_r * 1.08, head_r * 0.8, head_r * 1.0], hb, hc))
            if hair not in ("sidecut", "messy", "bob", "hime"):
                prims.append(P_ell(head_c + up * head_r * 0.66 + fwd_t * head_r * 0.48, [head_r * 0.84, head_r * 0.24, head_r * 0.38], hb, hc))
            for sd in (-1, 1):
                prims.append(P_ell(head_c + right_t * sd * head_r * 0.88 + up * head_r * 0.18 - fwd_t * head_r * 0.12, [head_r * 0.22, head_r * 0.5, head_r * 0.42], hb, hc))
            if hair == "spiky":
                for ax, ay in ((-0.7, 0.6), (-0.25, 0.95), (0.25, 0.9), (0.7, 0.55), (0.0, 0.75), (-0.45, 0.3)):
                    base = head_c + up * head_r * 0.55 + right_t * ax * head_r * 0.7 - fwd_t * 1.5
                    tipd = norm(up * ay + right_t * ax * 0.8 - fwd_t * (0.6 + 0.4 * tail))
                    prims.append(P_cone(base, base + tipd * head_r * 0.9, 2.7, 0.3, hc))
            elif hair == "long":
                prims.append(P_cone(head_c - fwd_t * head_r * 0.5, head_c - fwd_t * (head_r * 0.6 + 1.5 * tail) - up * head_r * 1.8, head_r * 0.86, head_r * 0.55, hc))
            elif hair == "messy":
                for ax in (-0.62, -0.3, 0.02, 0.34, 0.62):
                    base = head_c + up * head_r * 0.86 + fwd_t * head_r * 0.4 + right_t * ax * head_r * 0.8
                    tipd = norm(-up * 0.7 + fwd_t * 0.6 + right_t * ax * 0.4)
                    prims.append(P_cone(base, base + tipd * head_r * (0.44 if abs(ax) < 0.5 else 0.7), 2.5, 0.35, hc))
                for k in range(7):
                    a = -2.3 + k * 0.77
                    d = right_t * math.sin(a) - fwd_t * math.cos(a)
                    base = head_c + d * head_r * 0.82 + up * head_r * 0.25
                    prims.append(P_cone(base, base + norm(d * 0.9 - up * 0.45) * head_r * 0.55, 2.8, 0.3, hc))
                for ax in (-0.4, 0.15):
                    base = head_c + up * head_r * 0.85 + right_t * ax * head_r - fwd_t * 1.0
                    prims.append(P_cone(base, base + norm(up + right_t * ax - fwd_t * 0.4) * head_r * 0.45, 2.4, 0.3, hc))
            elif hair == "neat":
                c0 = head_c + up * head_r * 0.74 + fwd_t * head_r * 0.5 + right_t * head_r * 0.45
                prims.append(P_cone(c0, head_c + up * head_r * 0.22 + fwd_t * head_r * 0.86 - right_t * head_r * 0.2, 2.6, 0.7, hc))
            elif hair == "bob":
                prims.append(P_ell(head_c + up * head_r * 0.5 + fwd_t * head_r * 0.56, [head_r * 0.9, head_r * 0.3, head_r * 0.4], hb, hc))
                prims.append(P_ell(head_c - fwd_t * head_r * 0.3 - up * head_r * 0.12, [head_r * 1.02, head_r * 0.86, head_r * 0.78], hb, hc))
                for sd in (-1, 1):
                    prims.append(P_ell(head_c + right_t * sd * head_r * 0.82 - up * head_r * 0.22 + fwd_t * head_r * 0.08, [head_r * 0.32, head_r * 0.76, head_r * 0.66], hb, hc))
            elif hair == "hime":
                prims.append(P_cone(head_c - fwd_t * head_r * 0.5, head_c - fwd_t * (head_r * 0.6 + 1.5 * tail) - up * head_r * 2.0, head_r * 0.9, head_r * 0.6, hc))
                prims.append(P_ell(head_c + up * head_r * 0.45 + fwd_t * head_r * 0.6, [head_r * 0.88, head_r * 0.28, head_r * 0.36], hb, hc))
                for sd in (-1, 1):
                    prims.append(P_cone(head_c + right_t * sd * head_r * 0.78 + fwd_t * head_r * 0.22 + up * head_r * 0.1,
                                        head_c + right_t * sd * head_r * 0.86 + fwd_t * head_r * 0.32 - up * head_r * 1.55, head_r * 0.24, head_r * 0.18, hc))
            elif hair == "fluffy":
                for ax, ay, az in ((-0.6, 0.62, 0.1), (0.6, 0.6, 0.0), (0.0, 0.92, -0.05), (0.32, 0.8, 0.42), (-0.36, 0.74, 0.46), (0.0, 0.45, -0.72), (-0.75, 0.2, -0.2), (0.75, 0.2, -0.2)):
                    prims.append(P_sphere(head_c + right_t * ax * head_r + up * ay * head_r + fwd_t * az * head_r, head_r * 0.38, hc))
            elif hair == "mohawk":
                for i in range(6):
                    a = -0.6 + i * 0.26
                    base = head_c + up * head_r * 0.75 + fwd_t * a * head_r * 0.9
                    prims.append(P_cone(base, base + up * (4.0 - abs(a) * 2) - fwd_t * 1.2, 1.9, 0.3, hc))
            elif hair == "bun":
                prims.append(P_sphere(head_c + up * head_r * 0.85 - fwd_t * head_r * 0.7, head_r * 0.42, hc))
            elif hair == "ponytail":
                prims.append(P_cone(head_c + up * head_r * 0.5 - fwd_t * head_r * 0.8, head_c - fwd_t * (head_r * 1.5 + 2 * tail) - up * head_r * 0.6, 2.4, 1.2, hc))
            elif hair == "curly":
                for ax, ay, az in ((-0.6, 0.6, -0.2), (0.6, 0.6, -0.2), (0.0, 0.9, -0.1), (-0.3, 0.75, 0.3), (0.3, 0.75, 0.3), (0.0, 0.5, -0.7)):
                    prims.append(P_sphere(head_c + right_t * ax * head_r + up * ay * head_r + fwd_t * az * head_r, head_r * 0.42, hc))
            elif hair == "sidecut":
                prims.append(P_ell(head_c + up * head_r * 0.35 + fwd_t * head_r * 0.62 + right_t * head_r * 0.28, [head_r * 0.62, head_r * 0.55, head_r * 0.3], hb, hc))
                prims.append(P_cone(head_c - fwd_t * head_r * 0.4 + right_t * head_r * 0.6, head_c - up * head_r * 1.2 + right_t * head_r * 0.7, head_r * 0.45, head_r * 0.3, hc))
        if "cap" in acc and "helmet" not in acc and hair != "hood":
            prims.append(P_ell(head_c + up * head_r * 0.55, [head_r * 1.1, head_r * 0.55, head_r * 1.06], hb, "cap"))
            prims.append(P_ell(head_c + up * head_r * 0.45 + fwd_t * head_r * 0.95, [head_r * 0.72, 0.6, head_r * 0.6], hb, "cap"))
        if "visor" in acc:  # wrap-around shades at eye level
            prims.append(P_ell(head_c + fwd_t * head_r * 0.06 - up * head_r * 0.04, [head_r * 1.03, head_r * 0.19, head_r * 1.0], hb, "glow"))
        if "goggles" in acc and "helmet" not in acc:
            prims.append(P_ell(head_c + up * head_r * 0.95 + fwd_t * head_r * 0.2, [head_r * 0.98, head_r * 0.22, head_r * 0.5], hb, "glow"))
        if "mask" in acc:
            prims.append(P_ell(head_c + fwd_t * head_r * 0.55 - up * head_r * 0.42, [head_r * 0.82, head_r * 0.42, head_r * 0.55], hb, "gear"))
            DECALS.append(("dot", head_c + fwd_t * head_r * 1.02 - up * head_r * 0.42, fwd_t, {"slot": "glow", "band": 4}))
        if "beard" in acc:
            prims.append(P_ell(head_c - up * head_r * 0.6 + fwd_t * head_r * 0.42, [head_r * 0.64, head_r * 0.42, head_r * 0.42], hb, hc))
        if "mustache" in acc:
            prims.append(P_ell(head_c - up * head_r * 0.3 + fwd_t * head_r * 0.9, [head_r * 0.42, head_r * 0.12, head_r * 0.14], hb, hc))

    # whole-body transforms
    pivot = fr.w(0, 8.0, 0)
    if p["roll"] != 0.0:
        prims = [_rotate_prim(pr, pivot, fr.R, -p["roll"]) for pr in prims]
        DECALS[:] = [(k, _rot_pt(pt, pivot, fr.R, -p["roll"]), rot_axis(n, fr.R, -p["roll"]), e) for k, pt, n, e in DECALS]
    if p["lay"] > 0.0:
        foot = fr.w(0, 0, 0)
        ang = -p["lay"] * math.pi / 2 * 0.98
        off = fr.U * (2.5 * p["lay"]) + fr.F * 13.0 * p["lay"]
        prims = [_translate(_rotate_prim(pr, foot, fr.R, ang), off) for pr in prims]
        DECALS[:] = [(k, _rot_pt(pt, foot, fr.R, ang) + off, rot_axis(n, fr.R, ang), e) for k, pt, n, e in DECALS]
    return prims


def _rot_pt(pt, pivot, axis, ang):
    return pivot + rot_axis(pt - pivot, axis, ang)


def _rotate_prim(pr, pivot, axis, ang):
    q = dict(pr)
    if pr["k"] in ("sph", "ell", "box"):
        q["c"] = _rot_pt(pr["c"], pivot, axis, ang)
        if "M" in pr:
            q["M"] = np.array([rot_axis(row, axis, ang) for row in pr["M"]])
    else:
        q["a"] = _rot_pt(pr["a"], pivot, axis, ang)
        q["b"] = _rot_pt(pr["b"], pivot, axis, ang)
    return q


def _translate(pr, off):
    q = dict(pr)
    if pr["k"] == "cone":
        q["a"] = pr["a"] + off
        q["b"] = pr["b"] + off
    else:
        q["c"] = pr["c"] + off
    return q


# ---------------------------------------------------------------------------- creatures


def build_drone(cfg, facing, anim, t):
    fr = Frame3(facing)
    bob = math.sin(t * 2 * math.pi) * 1.2
    tilt = 0.3 if anim in ("walk", "run") else (-0.4 if anim == "hurt" else 0.0)
    y = 30.0 + bob
    eye = "flash" if anim in ("shoot", "slash1", "slash2", "slash3", "charge") and t > 0.3 else "glow"
    if anim == "dead":
        y = 30 - 24 * ease(min(1, t * 1.3))
        tilt = 1.2 * t
    c = fr.w(0, y, 0)
    fwd = rot_axis(fr.F, fr.R, -tilt)
    up = rot_axis(fr.U, fr.R, -tilt)
    b = [fr.R, up, fwd]
    quad = cfg.get("quad", False)
    prims = [P_ell(c, [8.5, 7.0 if quad else 7.5, 8.5], b, "top"), P_ell(c, [9.8, 2.0, 9.8], b, "gear"),
             P_ell(c + fwd * 6.6 + up * 0.8, [3.6, 3.6, 2.2], b, "accent"), P_sphere(c + fwd * 7.8 + up * 0.8, 2.4, eye),
             P_cone(c + up * 6.5, c + up * 11.0 - fwd * 2.0, 0.6, 0.4, "gear"), P_sphere(c + up * 11.4 - fwd * 2.0, 1.0, "glow")]
    for sx, sz in ([(-1, 0), (1, 0)] if not quad else [(-1, -1), (1, -1), (-1, 1), (1, 1)]):
        pod = c + fr.R * sx * 10.0 + fwd * sz * 6.0 - up * 1.0
        prims.append(P_ell(pod, [2.4, 3.0, 3.0], b, "coat"))
        prims.append(P_sphere(pod - up * 3.0, 1.3, "glow"))
    return prims


def build_grub(cfg, facing, anim, t):
    fr = Frame3(facing)
    tau = 2 * math.pi
    prims, pts = [], []
    n = 6
    speed = 1.0 if anim in ("walk", "run") else 0.3
    lunge = math.sin(min(1, t * 1.4) * math.pi) * 6 if anim in ("shoot", "slash1", "slash2", "slash3") else 0.0
    curl = ease(min(1, t * 1.3)) if anim == "dead" else 0.0
    for i in range(n):
        z = (n / 2 - i) * 4.2 + lunge * (1 - i / n)
        x = math.sin(t * tau * speed * 2 + i * 0.9) * 1.6 * (1 - curl)
        y = 4.5 + abs(math.sin(t * tau * speed * 2 + i * 0.9)) * 1.2 + (i == 0) * 1.5
        if curl:
            ang = i / n * math.pi * 1.4 * curl
            z = z * (1 - curl) + math.cos(ang) * 8 * curl
            y = y + math.sin(ang) * 6 * curl
        pts.append(fr.w(x, y, z))
    for i, pt in enumerate(pts):
        prims.append(P_sphere(pt, max(2.4, 4.8 - abs(i - 1.5) * 0.45), "top" if i % 2 == 0 else "coat"))
        if 0 < i < n - 1 and not curl:
            for sd in (-1, 1):
                prims.append(P_cone(pt, pt + fr.R * sd * 5.5 - fr.U * 4.0 + fr.F * math.sin(t * tau * 2 + i) * 1.4, 0.9, 0.5, "gear"))
    head = pts[0]
    jaw = 0.8 if anim in ("shoot", "slash1", "slash2", "slash3", "charge") else 0.25
    for sd in (-1, 1):
        base = head + fr.F * 3.4 + fr.R * sd * 1.8
        prims.append(P_cone(base, base + fr.F * 3.5 + fr.R * sd * jaw * 3.5 - fr.U * 0.5, 1.1, 0.3, "accent"))
        prims.append(P_sphere(head + fr.F * 3.2 + fr.R * sd * 2.0 + fr.U * 1.6, 0.9, "glow"))
    return prims


CAT_ANIMS = [("idle", 6, 6, True), ("walk", 6, 10, True), ("run", 6, 14, True), ("sit", 6, 5, True),
             ("wash", 6, 8, True), ("loaf", 4, 3, True)]


def build_cat(cfg, facing, anim, t):
    """Town cats (NEKOTSUKI): fur = hair slot, patches = scarf, eyes = iris. ~1/3 of a human."""
    fr = Frame3(facing)
    tau = 2 * math.pi
    s = 1.25 if cfg.get("chonk") else 1.0
    prims = []
    g = math.sin(t * tau)
    run = anim == "run"
    sit = anim in ("sit", "wash")
    loaf = anim == "loaf"
    lift = 0.6 * abs(math.sin(t * tau * 2)) if anim in ("walk", "run") else 0.0
    pitch = -0.55 if sit else 0.0
    up = rot_axis(fr.U, fr.R, pitch)
    fw = rot_axis(fr.F, fr.R, pitch)
    basis = [fr.R, up, fw]
    by = (2.6 if loaf else (4.6 if sit else 4.2)) + lift
    body = fr.w(0, by, -0.8 if sit else 0)
    prims.append(P_ell(body, [2.6 * s, 2.3 * s, 4.4], basis, "hair"))
    prims.append(P_ell(body - up * 0.7 + fw * 0.6, [1.9 * s, 1.5, 3.0], basis, "scarf"))
    head = (body + fw * 4.2 + up * 2.2) if not loaf else body + fw * 3.6 + up * 0.6
    if anim == "wash":
        head = head - fr.U * 0.4
    prims.append(P_sphere(head, 2.8, "hair"))
    prims.append(P_ell(head + fr.F * 2.1 - fr.U * 0.8, [1.2, 0.9, 0.8], [fr.R, fr.U, fr.F], "scarf"))
    for sd in (-1, 1):
        eb = head + fr.R * sd * 1.4 + fr.U * 1.9
        prims.append(P_cone(eb, eb + fr.R * sd * 0.6 + fr.U * 2.2 + fr.F * 0.3, 1.1, 0.2, "hair"))
        closed = loaf or (anim == "idle" and 0.7 <= t < 0.8) or anim == "wash"
        DECALS.append(("dot", head + fr.F * 2.55 + fr.R * sd * 1.0 + fr.U * 0.35, fr.F,
                       {"slot": "dark" if closed else "iris", "band": 3 if closed else 4}))
    if not loaf:
        for i, (sx, sz) in enumerate(((-1, 1), (1, 1), (-1, -1), (1, -1))):
            ph = t * tau * (2 if run else 1) + (0 if i in (0, 3) else math.pi)
            swing = (math.sin(ph) * (1.6 if run else 1.0)) if anim in ("walk", "run") else 0.0
            if sit and sz < 0:
                top = body + fr.R * sx * 1.6 - fw * 2.4
                prims.append(P_cone(top, fr.w(sx * 1.9, 0.6, -2.0), 1.3, 0.9, "hair"))
                continue
            top = body + fr.R * sx * 1.4 + fw * sz * 2.6 - up * 1.2
            foot = fr.w(sx * 1.4, 0.5, (body - fr.w(0, 0, 0)).dot(fr.F) + sz * 2.6 + swing)
            if anim == "wash" and i == 0:
                foot = head + fr.F * 1.6 - fr.U * 0.6 + fr.R * 0.4 * math.sin(t * tau * 2)
            prims.append(P_cone(top, foot, 1.0, 0.8, "hair"))
    tb = body - fw * 4.0 + up * 0.8
    if cfg.get("tail") == "bob":
        prims.append(P_sphere(tb, 1.4, "hair"))
    else:
        sway = 0.9 * g if not run else 0.3 * g
        mid = tb - fr.F * 1.6 + fr.U * 3.2 + fr.R * sway
        prims.append(P_cone(tb, mid, 0.9, 0.75, "hair"))
        prims.append(P_cone(mid, mid + fr.U * 2.6 + fr.R * sway * 1.6 - fr.F * 0.6, 0.75, 0.45, "hair"))
    return prims


BUILDERS = {"human": build_human, "drone": build_drone, "grub": build_grub, "cat": build_cat}

# ---------------------------------------------------------------------------- variants

OUTFITS = ["jacket", "coat", "vest", "tank", "hoodie", "suit", "overalls"]
HAIRS = ["short", "spiky", "long", "mohawk", "bun", "ponytail", "bald", "curly", "sidecut", "hood"]
ACCS = ["visor", "goggles", "mask", "cybereye", "cap", "scarf", "backpack", "pads", "gloves", "beard", "mustache"]


# NEKOTSUKI cast (docs/CAST.md). Colours live in data/cast_looks.json.
CAST = {
    "c_amane": {"body": "slim", "outfit": "hoodie", "hair": "messy", "acc": ["catears", "ahoge", "choker"], "eyes": "sleepy"},
    "c_toru": {"body": "normal", "outfit": "blazer", "hair": "neat", "acc": ["headphones"], "eyes": "sleepy", "brows": "flat"},
    "c_hayate": {"body": "normal", "outfit": "track", "hair": "spiky", "acc": []},
    "c_hina": {"body": "short", "outfit": "blazer", "hair": "bob", "acc": ["glasses", "camera"], "skirt": "short"},
    "c_reiji": {"body": "slim", "outfit": "blazer", "hair": "neat", "acc": ["armband"], "brows": "flat"},
    "c_mio": {"body": "slim", "outfit": "blazer", "hair": "hime", "acc": [], "skirt": "short", "mouth": "smile"},
    "c_makabe": {"body": "normal", "outfit": "teacher", "hair": "fluffy", "acc": ["glasses"]},
    "c_haruka": {"body": "short", "outfit": "apron", "hair": "ponytail", "acc": [], "skirt": "long", "mouth": "smile"},
    "c_chiyo": {"body": "short", "outfit": "miko", "hair": "bun", "acc": [], "skirt": "long", "eyes": "sleepy"},
}
STUDENTS = [
    ("s00", {"body": "normal", "outfit": "blazer", "hair": "neat", "acc": []}, ["student", "boy"]),
    ("s01", {"body": "slim", "outfit": "blazer", "hair": "messy", "acc": []}, ["student", "boy"]),
    ("s02", {"body": "normal", "outfit": "blazer", "hair": "spiky", "acc": []}, ["student", "boy"]),
    ("s03", {"body": "broad", "outfit": "blazer", "hair": "short", "acc": ["glasses"]}, ["student", "boy"]),
    ("s04", {"body": "short", "outfit": "hoodie", "hair": "curly", "acc": []}, ["student", "boy"]),
    ("s05", {"body": "short", "outfit": "blazer", "hair": "bob", "acc": [], "skirt": "short"}, ["student", "girl"]),
    ("s06", {"body": "slim", "outfit": "blazer", "hair": "long", "acc": [], "skirt": "short"}, ["student", "girl"]),
    ("s07", {"body": "normal", "outfit": "blazer", "hair": "ponytail", "acc": [], "skirt": "short"}, ["student", "girl"]),
    ("s08", {"body": "slim", "outfit": "blazer", "hair": "hime", "acc": ["glasses"], "skirt": "short"}, ["student", "girl"]),
    ("s09", {"body": "short", "outfit": "blazer", "hair": "bun", "acc": [], "skirt": "short"}, ["student", "girl"]),
]


def variant_list():
    """Curated + seeded-random geometry variants. Tags drive the runtime randomiser."""
    vs = {}
    curated = [
        ("h00", {"body": "normal", "outfit": "jacket", "hair": "spiky", "acc": ["scarf", "goggles"]}, ["hero", "civilian"]),
        ("h01", {"body": "normal", "outfit": "armor", "hair": "short", "acc": ["helmet", "jetpack", "gloves"]}, ["cop"]),
        ("h02", {"body": "broad", "outfit": "armor", "hair": "short", "acc": ["helmet", "pads", "gloves"]}, ["cop", "heavy"]),
        ("h03", {"body": "normal", "outfit": "coat", "hair": "mohawk", "acc": ["jetpack", "gloves"]}, ["punk"]),
        ("h04", {"body": "broad", "outfit": "tank", "hair": "bald", "acc": ["beard", "pads", "gloves"]}, ["heavy", "punk"]),
        ("h05", {"body": "normal", "outfit": "coat", "hair": "short", "acc": ["mask", "cybereye", "scarf"]}, ["punk", "hero"]),
        ("h06", {"body": "slim", "outfit": "tank", "hair": "sidecut", "acc": ["gloves"]}, ["civilian", "hero", "punk"]),
        ("h07", {"body": "normal", "outfit": "vest", "hair": "short", "acc": ["visor", "mustache"]}, ["civilian", "hero"]),
        ("h08", {"body": "slim", "outfit": "hoodie", "hair": "hood", "acc": []}, ["civilian", "punk", "hero"]),
        ("h09", {"body": "short", "outfit": "overalls", "hair": "bun", "acc": ["goggles", "gloves"]}, ["worker", "civilian", "hero"]),
        ("h10", {"body": "normal", "outfit": "suit", "hair": "short", "acc": ["visor"]}, ["corporate"]),
        ("h11", {"body": "slim", "outfit": "suit", "hair": "ponytail", "acc": []}, ["corporate", "hero"]),
        ("h12", {"body": "broad", "outfit": "overalls", "hair": "curly", "acc": ["cap", "beard"]}, ["worker", "civilian"]),
        ("h13", {"body": "normal", "outfit": "coat", "hair": "long", "acc": ["scarf"]}, ["civilian", "hero"]),
        ("r00", {"robot": True, "body": "normal", "outfit": "tank", "acc": []}, ["robot", "civilian"]),
        ("r01", {"robot": True, "body": "broad", "outfit": "armor", "acc": ["pads"]}, ["robot", "heavy", "cop"]),
    ]
    for name, cfg, tags in curated:
        vs[name] = ("human", cfg, tags)
    rnd = random.Random(3032)
    i = 14
    while i < 34:
        body = rnd.choice(["slim", "normal", "normal", "broad", "short"])
        outfit = rnd.choice(OUTFITS)
        hair = rnd.choice(HAIRS)
        acc = rnd.sample(ACCS, rnd.choice([0, 1, 1, 2, 2, 3]))
        if hair == "hood" and "cap" in acc:
            acc.remove("cap")
        tags = ["civilian", "hero"]
        if hair in ("mohawk", "spiky", "sidecut") or "mask" in acc:
            tags.append("punk")
        if outfit == "suit":
            tags = ["corporate", "hero"]
        if outfit == "overalls":
            tags.append("worker")
        if body == "broad":
            tags.append("heavy")
        vs["h%02d" % i] = ("human", {"body": body, "outfit": outfit, "hair": hair, "acc": acc}, tags)
        i += 1
    for name, cfg in CAST.items():
        vs[name] = ("human", dict(cfg, school=True), ["cast"])
    for name, cfg, tags in STUDENTS:
        vs[name] = ("human", dict(cfg, school=True), tags)
    vs["cat_a"] = ("cat", {"tail": "long"}, ["cat"])
    vs["cat_b"] = ("cat", {"tail": "bob"}, ["cat"])
    vs["cat_c"] = ("cat", {"tail": "long", "chonk": True}, ["cat"])
    vs["drone"] = ("drone", {}, ["drone"])
    vs["drone_quad"] = ("drone", {"quad": True}, ["drone"])
    vs["grub"] = ("grub", {}, ["bug"])
    return vs


def forge(name, spec):
    kind, cfg, tags = spec
    rows = []
    meta = {"frame_w": FRAME_W, "frame_h": FRAME_H, "foot_row": FOOT_ROW, "indexed": True,
            "dirs": list(DIRS.keys()), "tags": tags, "cfg": cfg, "anims": {}}
    anims = CAT_ANIMS if kind == "cat" else ANIMS + (EMOTE_ANIMS if cfg.get("school") else [])
    max_frames = max(a[1] for a in anims)
    for (aname, nframes, fps, loop) in anims:
        meta["anims"][aname] = {"fps": fps, "loop": loop, "frames": nframes, "rows": {}}
        for dname, deg in DIRS.items():
            row = []
            for f in range(nframes):
                DECALS.clear()
                prims = BUILDERS[kind](cfg, deg, aname, f / nframes)
                slot, band, depth = render(prims)
                sl, bd = outline(slot, band, depth)
                sl, bd = paint_decals(sl, bd, depth)
                row.append(encode(sl, bd))
            meta["anims"][aname]["rows"][dname] = len(rows)
            rows.append(row)
    sheet = Image.new("RGBA", (FRAME_W * max_frames, FRAME_H * len(rows)), (0, 0, 0, 0))
    for r, row in enumerate(rows):
        for c, arr in enumerate(row):
            sheet.paste(Image.fromarray(arr, "RGBA"), (c * FRAME_W, r * FRAME_H))
    os.makedirs(OUT_DIR, exist_ok=True)
    sheet.save(os.path.join(OUT_DIR, name + ".png"), optimize=True)
    with open(os.path.join(OUT_DIR, name + ".json"), "w") as f:
        json.dump(meta, f, indent=1)
    return sheet.size


# ---------------------------------------------------------------------------- preview colouring

PREVIEW = {"skin": "#f0c09a", "hair": "#2cc9c0", "top": "#3a3a52", "pants": "#2a2a3a", "boots": "#5a3a22",
           "accent": "#ffd23e", "coat": "#e8742a", "gear": "#6a6a80", "glow": "#3ee6ff", "eyewhite": "#f4f4f4",
           "iris": "#3a6aff", "dark": "#1a1030", "scarf": "#ff3ec8", "cap": "#a03030", "gloves": "#2a2236", "flash": "#bff8ff"}


def ramp6(hexc):
    h = hexc.lstrip("#")
    r, g, b = (int(h[i:i + 2], 16) / 255 for i in (0, 2, 4))
    hh, ss, vv = colorsys.rgb_to_hsv(r, g, b)

    def shift(x, to, a):
        d = ((to - x + 0.5) % 1.0) - 0.5
        return (x + d * a) % 1.0
    tones = [(shift(hh, 0.72, 0.35), min(1, ss * 1.2 + 0.15), vv * 0.16),
             (shift(hh, 0.72, 0.3), min(1, ss * 1.15 + 0.12), vv * 0.34),
             (shift(hh, 0.72, 0.16), min(1, ss * 1.08 + 0.05), vv * 0.68), (hh, ss, vv),
             (shift(hh, 0.13, 0.1), ss * 0.85, min(1, vv * 1.15 + 0.05)),
             (shift(hh, 0.13, 0.18), ss * 0.55, min(1, vv * 1.3 + 0.14))]
    return [colorsys.hsv_to_rgb(*t) for t in tones]


FACE_FX = ["#1a1030", "#d9455f", "#ff8fa8", "#5fb4ee", "#d4f0ff"]  # flash slot bands 0-4


def palette(colors=None):
    pal = np.zeros((16, 6, 3))
    for mat, slot in SLOTS.items():
        pal[slot] = ramp6((colors or {}).get(mat, PREVIEW[mat]))
    for b, hx in enumerate(FACE_FX):
        pal[SLOTS["flash"], b] = [int(hx[i:i + 2], 16) / 255 for i in (1, 3, 5)]
    return pal


def colorize(img_path, out_path, scale=3, colors=None):
    im = np.array(Image.open(img_path).convert("RGBA"))
    pal = palette(colors)
    out = np.zeros_like(im)
    m = im[..., 3] > 0
    out[m, :3] = (pal[im[..., 0][m] // 16, np.clip(im[..., 1][m] // 40, 0, 5)] * 255).astype(np.uint8)
    out[m, 3] = 255
    Image.fromarray(out, "RGBA").resize((im.shape[1] * scale, im.shape[0] * scale), Image.NEAREST).save(out_path)


def _job(item):
    name, spec = item
    return name, forge(name, spec)


if __name__ == "__main__":
    args = sys.argv[1:]
    allv = variant_list()
    if args and args[0] == "--preview":
        for n in args[1:]:
            colorize(os.path.join(OUT_DIR, n + ".png"), "/tmp/preview_%s.png" % n)
        sys.exit(0)
    names = args or list(allv.keys())
    from multiprocessing import Pool
    with Pool(os.cpu_count() or 2) as pool:
        for n, size in pool.imap_unordered(_job, [(n, allv[n]) for n in names]):
            print("forged", n, size, flush=True)
    index = {n: {"kind": allv[n][0], "tags": allv[n][2], "cfg": allv[n][1]} for n in allv}
    with open(os.path.join(OUT_DIR, "variants.json"), "w") as f:
        json.dump(index, f, indent=1)
