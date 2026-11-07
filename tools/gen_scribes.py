#!/usr/bin/env python3
"""Domyo and Dosho (docs/CAST.md), the thumb-sized scribes who write Enma's Ledger, as small pixel figures for the
ledger page (src/ui/ledger_page.gd). Domyo: white robe, tall black court cap, closed smiling eyes, neat scroll.
Dosho: black robe, red sash, messy hair, a grin with one fang, ink dripping off his brush. Two frames each (brush up,
brush down on the scroll) -> assets/ui/scribe_domyo.png / scribe_dosho.png (96x64 strips, 48x64 frames).
All original, generated. python3 tools/gen_scribes.py"""
import os
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "ui")
W, H = 48, 64
OUTLINE = (26, 16, 24, 255)
SKIN, SKIN_D = (247, 220, 196, 255), (226, 186, 156, 255)
INK = (20, 14, 18, 255)


def figure(kind, frame):
    im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    if kind == "domyo":
        robe, fold, collar, sash = (244, 240, 232, 255), (196, 190, 182, 255), (150, 190, 220, 255), (214, 170, 70, 255)
    else:
        robe, fold, collar, sash = (34, 30, 40, 255), (70, 58, 86, 255), (120, 40, 60, 255), (200, 40, 50, 255)
    # robe (wide sleeves, kneeling silhouette)
    d.polygon([(15, 31), (33, 31), (41, 60), (7, 60)], fill=robe)
    d.polygon([(7, 38), (15, 31), (17, 50), (6, 52)], fill=robe)       # left sleeve
    d.polygon([(41, 38), (33, 31), (31, 50), (42, 52)], fill=robe)     # right sleeve
    for x0 in (13, 20, 28, 35):
        d.line([(x0, 44), (x0 - 2 if x0 < 24 else x0 + 2, 59)], fill=fold)
    d.polygon([(20, 31), (24, 38), (28, 31)], fill=collar)
    d.rectangle([14, 41, 34, 43], fill=sash)
    # scroll in the lap
    d.rectangle([12, 46, 36, 51], fill=(238, 226, 196, 255))
    d.line([(12, 46), (36, 46)], fill=(200, 184, 150, 255))
    for x0 in range(15, 34, 4):
        d.point((x0, 48 + (x0 // 4) % 2), fill=INK)
    # head
    d.ellipse([13, 10, 35, 31], fill=SKIN)
    d.arc([13, 10, 35, 31], 20, 160, fill=SKIN_D)
    if kind == "domyo":
        d.rectangle([16, 1, 32, 11], fill=INK)                          # tall court cap
        d.rectangle([14, 10, 34, 13], fill=INK)
        d.line([(18, 4), (30, 4)], fill=(70, 70, 90, 255))
        d.arc([16, 18, 22, 23], 200, 340, fill=INK)                     # closed smiling eyes
        d.arc([26, 18, 32, 23], 200, 340, fill=INK)
        d.arc([21, 23, 27, 28], 20, 160, fill=(180, 80, 80, 255))       # small smile
        d.point((17, 25), fill=(240, 160, 160, 255))
        d.point((31, 25), fill=(240, 160, 160, 255))
    else:
        d.polygon([(12, 16), (16, 6), (19, 11), (23, 4), (26, 10), (31, 5), (32, 12), (37, 15), (35, 19), (13, 19)], fill=INK)
        d.rectangle([17, 20, 20, 22], fill=(255, 255, 255, 255))         # open, mischievous eyes
        d.rectangle([28, 20, 31, 22], fill=(255, 255, 255, 255))
        d.point((19, 21), fill=(200, 30, 40, 255))
        d.point((29, 21), fill=(200, 30, 40, 255))
        d.line([(16, 18), (21, 19)], fill=INK)
        d.line([(27, 19), (32, 18)], fill=INK)
        d.line([(20, 26), (28, 25)], fill=INK)                           # grin
        d.point((27, 26), fill=(255, 255, 255, 255))                     # fang
    # brush hand + brush: up (frame 0) or touching the scroll (frame 1)
    hand_y = 36 if frame == 0 else 42
    d.ellipse([31, hand_y - 2, 35, hand_y + 2], fill=SKIN)
    tip_y = hand_y + 6 if frame == 1 else hand_y + 4
    d.line([(34, hand_y - 8), (33, tip_y)], fill=(150, 100, 60, 255), width=1)
    d.line([(33, tip_y - 2), (33, tip_y)], fill=INK)
    if kind == "dosho":
        d.point((33, tip_y + 2), fill=INK)                               # a drip
    # outline
    px = im.load()
    mask = [[px[x, y][3] > 0 for x in range(W)] for y in range(H)]
    for y in range(H):
        for x in range(W):
            if mask[y][x]:
                continue
            if any(0 <= x + dx < W and 0 <= y + dy < H and mask[y + dy][x + dx] for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                px[x, y] = OUTLINE
    return im


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    for kind in ("domyo", "dosho"):
        strip = Image.new("RGBA", (W * 2, H), (0, 0, 0, 0))
        for f in range(2):
            strip.paste(figure(kind, f), (W * f, 0))
        strip.save(os.path.join(OUT, "scribe_%s.png" % kind))
        print("wrote", kind)
