#!/usr/bin/env python3
"""Contact sheet of cast emotions straight from the sprite rig (no sheets written).

Usage: python3 tools/cast_preview.py <out.png> [--cast amane,toru] [--anims idle,cry] [--dir S] [--scale 3] [--frame 0.4] [--cols N]
Colours come from data/cast_looks.json. Handy for checking new poses/faces before a full forge run.
"""
import json
import os
import sys

import numpy as np
from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import sprite_forge as sf  # noqa: E402

LOOKS = json.load(open(os.path.join(sf.ROOT, "data", "cast_looks.json")))


def frame(variant, anim, t, deg):
    kind, cfg, _ = sf.variant_list()[variant]
    sf.DECALS.clear()
    prims = sf.BUILDERS[kind](cfg, deg, anim, t)
    slot, band, depth = sf.render(prims)
    sl, bd = sf.outline(slot, band, depth)
    sl, bd = sf.paint_decals(sl, bd, depth)
    return sf.encode(sl, bd)


def colour(img, colors):
    pal = sf.palette(colors)
    out = np.zeros_like(img)
    m = img[..., 3] > 0
    out[m, :3] = (pal[img[..., 0][m] // 16, np.clip(img[..., 1][m] // 40, 0, 5)] * 255).astype(np.uint8)
    out[m, 3] = 255
    return out


def main():
    a = sys.argv[1:]
    out = a[0]
    opt = {a[i]: a[i + 1] for i in range(1, len(a) - 1, 2)}
    cast = opt.get("--cast", ",".join(k for k in LOOKS if not k.startswith("_"))).split(",")
    anims = opt.get("--anims", "idle,happy,cry,wail,fluster,pout,angry,shock,yandere").split(",")
    deg = sf.DIRS[opt.get("--dir", "S")]
    sc = int(opt.get("--scale", "3"))
    tf = float(opt.get("--frame", "0.4"))
    cw, ch = 64 * sc, 64 * sc + 14
    cells = [(who, an) for who in cast for an in anims]
    cols = int(opt.get("--cols", str(len(anims))))
    rows = (len(cells) + cols - 1) // cols
    sheet = Image.new("RGBA", (cw * cols, ch * rows), (52, 50, 66, 255))
    d = ImageDraw.Draw(sheet)
    for i, (who, an) in enumerate(cells):
        look = LOOKS[who]
        x, y = (i % cols) * cw, (i // cols) * ch
        img = Image.fromarray(colour(frame(look["variant"], an, tf, deg), look["colors"]), "RGBA")
        sheet.alpha_composite(img.resize((64 * sc, 64 * sc), Image.NEAREST), (x, y + 14))
        d.text((x + 4, y + 1), f"{who} {an}", fill=(230, 226, 240, 255))
    sheet.save(out)
    print("wrote", out, sheet.size)


if __name__ == "__main__":
    main()
