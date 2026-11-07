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


def pixelize(src, size, sat, bright, tint, colours, nor=None):
    """Photo -> pixel-art texture: local contrast, a baked top-left bevel light and cavity darkening from the
    normal map (stones, tiles and planks get crisp dark gaps and lit edges, like hand-pixelled HD-2D art),
    then a small palette with no dithering."""
    import numpy as np
    from PIL import ImageFilter
    big = Image.open(src).convert("RGB").resize((size * 2, size * 2), Image.LANCZOS)
    big = big.filter(ImageFilter.UnsharpMask(radius=2, percent=160, threshold=1))
    im = big.resize((size, size), Image.BOX)
    im = ImageEnhance.Color(im).enhance(sat)
    im = ImageEnhance.Brightness(im).enhance(bright)
    im = ImageEnhance.Contrast(im).enhance(1.18)
    a = np.asarray(im).astype(np.float32) / 255.0
    a *= np.array(tint, dtype=np.float32)
    if nor is not None:
        n = np.asarray(Image.open(nor).convert("RGB").resize((size, size), Image.BOX)).astype(np.float32) / 255.0
        n = n * 2.0 - 1.0
        n /= np.maximum(np.linalg.norm(n, axis=2, keepdims=True), 1e-4)
        light = np.array([-0.45, 0.45, 0.77], dtype=np.float32)  # top-left, like pixel artists shade
        shade = np.clip((n * light).sum(axis=2), 0.0, 1.0)
        cavity = np.clip((n[:, :, 2] - 0.55) / 0.4, 0.0, 1.0)      # steep slopes = gaps and edges
        k = (0.72 + 0.38 * shade) * (0.62 + 0.38 * cavity)
        a *= k[:, :, None] * 1.12
    im = Image.fromarray((np.clip(a, 0.0, 1.0) * 255).astype(np.uint8))
    return im.quantize(colors=colours, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE).convert("RGB")


def normal(src, size):
    im = Image.open(src).convert("RGB").resize((size, size), Image.BOX)
    return im


def main():
    cache = sys.argv[1] if len(sys.argv) > 1 else "/tmp/jp_textures_cache"
    os.makedirs(cache, exist_ok=True)
    for name, (pid, size, sat, bright, tint, colours) in TEX.items():
        f = fetch(pid, cache)
        pixelize(f["Diffuse"], size, sat, bright, tint, colours, f["nor_gl"]).save(os.path.join(OUT, "jp_%s.png" % name))
        normal(f["nor_gl"], size).save(os.path.join(OUT, "jp_%s_n.png" % name))
        print("jp_%s <- %s" % (name, pid))


if __name__ == "__main__":
    main()
