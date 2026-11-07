#!/usr/bin/env python3
"""Suzunari ground/wall/roof textures from Poly Haven (CC0, https://polyhaven.com/license).

Downloads the 1k diffuse + OpenGL normal maps into a cache dir, then pixelizes them to match the
HD-2D chibi sprites (128 px per 4 m = 32 texels per metre, quantized palette, gentle colour grade)
and writes assets/textures/jp_<name>.png + jp_<name>_n.png. Commit the PNGs; the cache is throwaway.

    python3 tools/jp_textures.py [cache_dir]          # needs network for the first run
"""
import json, os, subprocess, sys
from PIL import Image, ImageEnhance, ImageOps

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "textures")

# name: (Poly Haven id, size px, saturation, brightness, tint RGB multiplier, colours)
TEX = {
    "gravel":     ("gravel_floor_02", 128, 0.9, 1.05, (1.0, 1.0, 1.03), 20),
    "sando":      ("precast_stone_paving", 128, 0.8, 1.05, (1.0, 1.0, 1.02), 24),
    "stonepath":  ("grey_stone_path", 128, 0.9, 1.1, (1.0, 1.0, 1.0), 24),
    "paving":     ("rectangular_paving", 128, 1.05, 1.08, (1.03, 1.0, 0.97), 24),
    "asphalt":    ("asphalt_02", 128, 0.9, 0.95, (0.98, 0.99, 1.04), 20),
    "grass":      ("leafy_grass", 128, 1.45, 1.05, (0.92, 1.08, 0.82), 24),
    "schoolyard": ("playground_sand", 128, 1.0, 1.12, (1.04, 1.0, 0.94), 20),
    "beach":      ("coast_sand_01", 128, 1.1, 1.18, (1.04, 1.01, 0.94), 20),
    "woodfloor":  ("wood_floor_worn", 128, 0.9, 1.05, (1.0, 0.97, 0.94), 24),
    "kawara":     ("grey_roof_tiles_02", 128, 0.6, 0.95, (0.95, 0.98, 1.06), 20),
    "kawara_old": ("grey_roof_tiles", 128, 0.8, 0.95, (0.95, 1.0, 1.0), 24),
    "cedar":      ("japanese_cedar_planks", 128, 0.75, 0.9, (1.0, 0.92, 0.85), 24),
    "hinoki":     ("hinoki_planks", 128, 0.9, 1.08, (1.02, 1.0, 0.96), 24),
    "yakisugi":   ("weathered_plank_siding", 128, 0.6, 0.85, (0.95, 0.95, 1.0), 20),
    "plaster":    ("white_plaster_02", 128, 0.7, 1.15, (1.02, 1.0, 0.97), 16),
    "ishigaki":   ("japanese_stone_wall", 128, 0.85, 1.05, (1.0, 1.0, 1.02), 24),
    "concrete":   ("concrete_wall_005", 128, 0.6, 1.2, (1.0, 1.0, 1.0), 16),
    "bark":       ("japanese_cedar_bark", 64, 0.9, 1.1, (1.0, 0.95, 0.9), 16),
    "moss":       ("mossy_rock", 128, 1.25, 1.0, (0.95, 1.05, 0.9), 24),
    "forest":     ("forest_leaves_02", 128, 1.1, 0.9, (0.95, 1.03, 0.9), 24),
    # props: every flat-coloured thing in town gets one of these (LevelBuilder._jp_mat / _flat -> JPKit)
    "lacquer":    ("rusty_painted_metal", 128, 1.0, 1.05, (1.18, 0.78, 0.58), 24),   # weathered vermilion paint
    "patina":     ("green_metal_rust", 128, 0.9, 1.05, (0.85, 1.0, 1.0), 20),         # copper roof
    "paint":      ("distressed_painted_planks", 128, 0.45, 1.2, (1.0, 1.0, 1.0), 24), # chipped paint, tinted per object
    "granite":    ("old_sandstone_02", 128, 0.12, 1.05, (1.0, 1.0, 1.02), 20),        # carved stone
    "indigo":     ("denim_fabric", 128, 0.9, 0.8, (0.9, 0.95, 1.0), 20),               # noren cloth
    "sheet":      ("corrugated_iron_02", 128, 0.6, 1.1, (1.0, 1.0, 1.02), 16),         # metal sheet, AC units
    "darkwood":   ("lacquered_cherry_wood", 128, 0.9, 1.35, (1.0, 0.95, 0.9), 20),     # dark lacquer, benches
}


def fetch(pid, cache):
    files = {}
    meta_path = os.path.join(cache, pid + ".files.json")
    if not os.path.exists(meta_path):
        subprocess.run(["curl", "-s", "-m", "30", "-o", meta_path, "https://api.polyhaven.com/files/" + pid], check=True)
    meta = json.load(open(meta_path))
    for key in ("Diffuse", "nor_gl"):
        path = os.path.join(cache, "%s_%s.jpg" % (pid, key))
        if not os.path.exists(path):
            url = meta[key]["1k"]["jpg"]["url"]
            subprocess.run(["curl", "-s", "-m", "120", "-o", path, url], check=True)
        files[key] = path
    return files


def pixelize(src, size, sat, bright, tint, colours):
    im = Image.open(src).convert("RGB").resize((size, size), Image.BOX)
    im = ImageEnhance.Color(im).enhance(sat)
    im = ImageEnhance.Brightness(im).enhance(bright)
    im = ImageEnhance.Contrast(im).enhance(1.08)
    r, g, b = im.split()
    r = r.point(lambda v: min(255, int(v * tint[0])))
    g = g.point(lambda v: min(255, int(v * tint[1])))
    b = b.point(lambda v: min(255, int(v * tint[2])))
    im = Image.merge("RGB", (r, g, b))
    # A small shared palette per texture = crisp pixel-art clusters, no dithering noise.
    return im.quantize(colors=colours, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE).convert("RGB")


def normal(src, size):
    im = Image.open(src).convert("RGB").resize((size, size), Image.BOX)
    return im


def main():
    cache = sys.argv[1] if len(sys.argv) > 1 else "/tmp/jp_textures_cache"
    os.makedirs(cache, exist_ok=True)
    for name, (pid, size, sat, bright, tint, colours) in TEX.items():
        f = fetch(pid, cache)
        pixelize(f["Diffuse"], size, sat, bright, tint, colours).save(os.path.join(OUT, "jp_%s.png" % name))
        normal(f["nor_gl"], size).save(os.path.join(OUT, "jp_%s_n.png" % name))
        print("jp_%s <- %s" % (name, pid))


if __name__ == "__main__":
    main()
