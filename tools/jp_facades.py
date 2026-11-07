#!/usr/bin/env python3
"""Pixel-art facade panels for Suzunari's buildings (32 px per metre, like the ground textures).

Each panel has a colour sheet and an emission mask (`_e`, lit glass / paper / lamps after dusk):
  jp_f_koshi    4x3 m  machiya wooden lattice front with a sliding door
  jp_f_shop     4x3 m  shop front: glass sliding doors, shelves of goods
  jp_f_shutter  4x3 m  rolled-down shutter with a paper notice
  jp_f_win      2x1.5  upper-floor window: wooden frame, curtains, rail
  jp_f_shoji    2x1.5  paper sliding window (warm at night)
  jp_f_alu      2x1.5  modern aluminium window with blinds
  jp_f_door     2x3 m  house entrance: lattice glass door, lamp, name plate
  jp_f_school   4x3 m  old school windows (blackboard and desks inside)
    python3 tools/jp_facades.py
"""
import os, random
from PIL import Image, ImageDraw

OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "assets", "textures")
WOOD = [(92, 58, 38), (120, 78, 50), (146, 98, 62)]
DARK = (38, 26, 22)


def new(w, h, bg=(0, 0, 0, 0)):
    im = Image.new("RGBA", (w, h), bg)
    em = Image.new("RGB", (w, h), (0, 0, 0))
    return im, ImageDraw.Draw(im), em, ImageDraw.Draw(em)


def wood_rect(d, box, base=1):
    x0, y0, x1, y1 = box
    d.rectangle(box, fill=WOOD[base])
    d.line([(x0, y0), (x1, y0)], fill=WOOD[min(2, base + 1)])
    d.line([(x0, y1), (x1, y1)], fill=WOOD[max(0, base - 1)])


def glass(d, e, box, rnd, warm=(255, 214, 150), goods=False):
    x0, y0, x1, y1 = box
    d.rectangle(box, fill=(122, 162, 176))
    e.rectangle(box, fill=(int(warm[0] * 0.55), int(warm[1] * 0.55), int(warm[2] * 0.55)))
    if goods:
        for sy in range(y0 + 4, y1 - 2, 7):
            d.line([(x0, sy + 5), (x1, sy + 5)], fill=(70, 60, 56))
            x = x0 + 1
            while x < x1 - 2:
                gw = rnd.randint(2, 4)
                col = rnd.choice([(230, 90, 80), (250, 200, 80), (90, 170, 220), (240, 240, 230), (120, 200, 120), (240, 140, 180)])
                d.rectangle((x, sy + 5 - rnd.randint(2, 4), x + gw - 1, sy + 4), fill=col)
                e.rectangle((x, sy + 5 - rnd.randint(2, 4), x + gw - 1, sy + 4), fill=warm)
                x += gw + 1
    for k in range(2):  # sky reflection streaks, kept inside the pane
        sx = rnd.randint(x0, max(x0, x1 - 8))
        n = min(x1 - sx, (y1 - y0) // 3)
        d.line([(sx, y0 + 2), (sx + n, y0 + 2 + n * 2)], fill=(176, 206, 214))


def koshi(rnd):
    im, d, em, e = new(128, 96, (*DARK, 255))
    d.rectangle((0, 0, 127, 9), fill=WOOD[0])
    d.rectangle((0, 88, 127, 95), fill=(120, 118, 112))
    for x in range(2, 126, 4):
        d.rectangle((x, 10, x + 2, 87), fill=WOOD[1])
        d.point((x, 10), fill=WOOD[2])
    d.rectangle((0, 40, 127, 42), fill=WOOD[0])
    # sliding entrance door (frosted glass behind the lattice)
    dx = rnd.choice([8, 76])
    d.rectangle((dx, 12, dx + 40, 87), fill=(214, 206, 186))
    e.rectangle((dx, 12, dx + 40, 87), fill=(150, 118, 70))
    for x in range(dx + 2, dx + 40, 5):
        d.line([(x, 12), (x, 87)], fill=WOOD[1])
    d.line([(dx + 20, 12), (dx + 20, 87)], fill=DARK)
    d.rectangle((dx - 2, 10, dx + 42, 12), fill=WOOD[0])
    return im, em


def shop(rnd):
    im, d, em, e = new(128, 96, (*WOOD[0], 255))
    d.rectangle((0, 0, 127, 13), fill=(240, 236, 226))  # signboard band (label goes over it)
    d.rectangle((0, 12, 127, 13), fill=DARK)
    for i, x in enumerate(range(2, 126, 31)):
        glass(d, e, (x + 2, 16, x + 28, 84), rnd, goods=True)
        d.rectangle((x, 14, x + 1, 87), fill=WOOD[0])
    d.rectangle((0, 85, 127, 95), fill=(132, 128, 120))
    d.rectangle((60, 30, 67, 36), fill=(230, 60, 50))  # "OPEN" tag
    e.rectangle((60, 30, 67, 36), fill=(255, 90, 70))
    return im, em


def shutter(rnd):
    im, d, em, e = new(128, 96, (150, 154, 158, 255))
    for y in range(4, 92, 3):
        d.line([(0, y), (127, y)], fill=(118, 122, 128))
    d.rectangle((0, 0, 127, 5), fill=(90, 92, 98))
    d.rectangle((0, 90, 127, 95), fill=(80, 82, 88))
    nx = rnd.randint(20, 90)
    d.rectangle((nx, 34, nx + 14, 52), fill=(244, 240, 228))
    for y in range(37, 50, 3):
        d.line([(nx + 2, y), (nx + 11, y)], fill=(70, 70, 80))
    return im, em


def window(rnd, kind):
    im, d, em, e = new(64, 48, (0, 0, 0, 0))
    d.rectangle((2, 2, 61, 41), fill=WOOD[0] if kind != "alu" else (172, 176, 180))
    if kind == "shoji":
        d.rectangle((5, 5, 58, 38), fill=(238, 232, 214))
        e.rectangle((5, 5, 58, 38), fill=(255, 196, 120))
        for x in range(5, 59, 7):
            d.line([(x, 5), (x, 38)], fill=WOOD[1])
        for y in range(5, 39, 8):
            d.line([(5, y), (58, y)], fill=WOOD[1])
    else:
        glass(d, e, (5, 5, 30, 38), rnd)
        glass(d, e, (33, 5, 58, 38), rnd)
        cur = rnd.choice([(236, 226, 200), (240, 190, 200), (170, 200, 230), (200, 220, 170)])
        if kind == "alu":
            for y in range(5, rnd.randint(12, 30), 2):
                d.line([(5, y), (58, y)], fill=(220, 222, 224))
        else:
            d.rectangle((5, 5, 12, 38), fill=cur)
            d.rectangle((51, 5, 58, 38), fill=cur)
            e.rectangle((5, 5, 12, 38), fill=(150, 110, 70))
            e.rectangle((51, 5, 58, 38), fill=(150, 110, 70))
        d.line([(31, 5), (31, 38)], fill=WOOD[0] if kind != "alu" else (150, 152, 156))
    # sill + little rail (tesuri)
    d.rectangle((0, 40, 63, 42), fill=WOOD[0] if kind != "alu" else (140, 142, 146))
    for x in range(1, 63, 5):
        d.line([(x, 34), (x, 46)], fill=(60, 62, 66))
    d.line([(0, 34), (63, 34)], fill=(60, 62, 66))
    return im, em


def door(rnd):
    im, d, em, e = new(64, 96, (0, 0, 0, 0))
    d.rectangle((6, 22, 57, 95), fill=WOOD[0])
    d.rectangle((10, 26, 53, 92), fill=(200, 196, 182))
    e.rectangle((10, 26, 53, 92), fill=(110, 86, 52))
    for x in range(12, 53, 4):
        d.line([(x, 26), (x, 92)], fill=WOOD[1])
    for y in range(30, 92, 12):
        d.line([(10, y), (53, y)], fill=WOOD[1])
    d.line([(31, 26), (31, 92)], fill=DARK)
    d.rectangle((24, 8, 39, 18), fill=(250, 236, 196))  # porch lamp
    e.rectangle((24, 8, 39, 18), fill=(255, 220, 150))
    d.rectangle((44, 50, 50, 64), fill=(226, 218, 196))  # name plate
    d.line([(46, 52), (46, 62)], fill=(40, 40, 40))
    d.rectangle((0, 18, 63, 22), fill=(96, 100, 108))  # little canopy
    return im, em


def school(rnd):
    im, d, em, e = new(128, 96, (0, 0, 0, 0))
    for x in (4, 66):
        d.rectangle((x, 14, x + 57, 70), fill=(70, 52, 40))
        d.rectangle((x + 3, 17, x + 54, 67), fill=(64, 92, 72))  # blackboard seen through glass
        for c in range(4):
            gx = x + 3 + c * 13
            d.rectangle((gx, 17, gx + 11, 67), outline=(70, 52, 40))
        e.rectangle((x + 3, 17, x + 54, 67), fill=(180, 190, 160))
        for k in range(5):  # chalk scribbles
            cy = rnd.randint(22, 50)
            d.line([(x + 6 + k * 9, cy), (x + 12 + k * 9, cy + rnd.randint(-2, 2))], fill=(226, 230, 220))
        for k in range(4):  # desks
            d.rectangle((x + 6 + k * 13, 58, x + 14 + k * 13, 64), fill=(160, 120, 80))
    return im, em


def blossom(rnd):
    """Sakura crown texture: clusters of five-petal flowers with holes (alpha) for a fluffy crown."""
    im = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    em = Image.new("RGB", (64, 64), (0, 0, 0))
    pinks = [(255, 214, 226), (252, 188, 206), (246, 160, 186), (255, 236, 240), (232, 140, 168)]
    for k in range(260):
        x, y = rnd.randrange(64), rnd.randrange(64)
        c = rnd.choice(pinks)
        r = rnd.choice([1, 1, 2])
        for dx in range(-r, r + 1):
            for dy in range(-r, r + 1):
                if abs(dx) + abs(dy) <= r:
                    d.point(((x + dx) % 64, (y + dy) % 64), fill=c + (255,))
        d.point((x, y), fill=(200, 90, 120, 255))
    for k in range(40):  # a few dark twig gaps
        x, y = rnd.randrange(64), rnd.randrange(64)
        d.point((x, y), fill=(120, 80, 80, 255))
    return im, em


def leaves(rnd):
    """Foliage crown texture (bamboo, camphor, pine): leaf clusters with holes."""
    im = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    greens = [(118, 170, 84), (92, 146, 70), (150, 192, 98), (70, 118, 60), (178, 210, 120)]
    for k in range(300):
        x, y = rnd.randrange(64), rnd.randrange(64)
        c = rnd.choice(greens)
        ln = rnd.choice([2, 3, 3, 4])
        dx = rnd.choice([-1, 1])
        for i in range(ln):  # little slanted leaf strokes
            d.point(((x + i * dx) % 64, (y + i // 2) % 64), fill=c + (255,))
            d.point(((x + i * dx) % 64, (y + i // 2 + 1) % 64), fill=c + (255,))
    return im, Image.new("RGB", (64, 64), (0, 0, 0))


def clouds(rnd):
    """Tileable cloud-shadow mask (alpha = cloud) for the invisible shadow-casting cloud layer."""
    import math
    n = 128
    grid = [[rnd.random() for _ in range(8)] for _ in range(8)]
    def val(x, y, f):
        gx, gy = x * f / n, y * f / n
        x0, y0 = int(gx) % f, int(gy) % f
        tx, ty = gx - int(gx), gy - int(gy)
        tx, ty = tx * tx * (3 - 2 * tx), ty * ty * (3 - 2 * ty)
        g = lambda i, j: grid[(i % f) % 8][(j % f) % 8]
        a = g(x0, y0) * (1 - tx) + g(x0 + 1, y0) * tx
        b = g(x0, y0 + 1) * (1 - tx) + g(x0 + 1, y0 + 1) * tx
        return a * (1 - ty) + b * ty
    im = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    px = im.load()
    for y in range(n):
        for x in range(n):
            v = val(x, y, 4) * 0.65 + val(x, y, 8) * 0.35
            px[x, y] = (255, 255, 255, 255 if v > 0.56 else 0)
    return im, Image.new("RGB", (n, n), (0, 0, 0))


def grime(rnd):
    """Shared weathering (detail multiply on walls, roofs and props, not floors): soft tileable dirt + rain streaks."""
    n = 128
    grid = [[rnd.random() for _ in range(16)] for _ in range(16)]
    def val(x, y, f):
        gx, gy = x * f / n, y * f / n
        x0, y0 = int(gx), int(gy)
        tx, ty = gx - x0, gy - y0
        tx, ty = tx * tx * (3 - 2 * tx), ty * ty * (3 - 2 * ty)
        g = lambda i, j: grid[i % f][j % f]
        a = g(x0, y0) * (1 - tx) + g(x0 + 1, y0) * tx
        c = g(x0, y0 + 1) * (1 - tx) + g(x0 + 1, y0 + 1) * tx
        return a * (1 - ty) + c * ty
    im = Image.new("RGB", (n, n))
    px = im.load()
    for y in range(n):
        for x in range(n):
            v = val(x, y, 4) * 0.6 + val(x, y, 16) * 0.4
            k = 1.0 - max(0.0, v - 0.45) * 0.22  # 0.88 .. 1.0, soft
            c = int(255 * k)
            px[x, y] = (c, c, max(0, c - 3))
    for k in range(34):  # rain streaks running down from edges
        x, y, ln = rnd.randrange(n), rnd.randrange(n), rnd.randint(8, 34)
        for i in range(ln):
            r, g, bb = px[x, (y + i) % n]
            f = 0.93 + 0.05 * i / ln
            px[x, (y + i) % n] = (int(r * f), int(g * f), int(bb * f))
    return im, Image.new("RGB", (n, n), (0, 0, 0))


# --- School interior panels (32 px per metre) ---

def blackboard(rnd):
    """4 x 1.5 m green board: chalk scribbles, a date column, the duty names, an eraser on the ledge."""
    im, d, em, e = new(128, 48, (*WOOD[0], 255))
    d.rectangle((3, 3, 124, 42), fill=(46, 82, 62))
    for k in range(260):  # chalk dust haze
        x, y = rnd.randint(4, 123), rnd.randint(4, 41)
        d.point((x, y), fill=(58, 96, 74))
    for line in range(5):
        y = 8 + line * 7
        x = rnd.randint(14, 30)
        while x < rnd.randint(70, 110):
            ln = rnd.randint(2, 6)
            d.line([(x, y), (x + ln, y + rnd.choice([-1, 0, 0, 1]))], fill=(222, 228, 214))
            x += ln + rnd.randint(1, 3)
    d.line([(112, 6), (112, 38)], fill=(200, 206, 196))  # date column
    for y in range(8, 36, 5):
        d.line([(115, y), (121, y)], fill=(222, 228, 214))
    d.rectangle((0, 43, 127, 47), fill=WOOD[1])  # chalk ledge
    d.rectangle((40, 42, 48, 45), fill=(60, 70, 120))  # eraser
    for x, c in ((60, (240, 240, 230)), (63, (250, 200, 80)), (66, (240, 120, 140))):
        d.line([(x, 44), (x + 2, 44)], fill=c)
    return im, em


def corkboard(rnd):
    """2 x 1.5 m notice board: cork, pinned papers, a club poster, a lost cat flyer."""
    im, d, em, e = new(64, 48, (*WOOD[0], 255))
    d.rectangle((2, 2, 61, 45), fill=(176, 132, 84))
    for k in range(120):
        d.point((rnd.randint(2, 61), rnd.randint(2, 45)), fill=(150, 108, 66))
    for k in range(7):
        w, h = rnd.randint(8, 14), rnd.randint(9, 16)
        x, y = rnd.randint(3, 60 - w), rnd.randint(3, 44 - h)
        col = rnd.choice([(244, 240, 228), (250, 236, 170), (230, 240, 250), (250, 210, 220)])
        d.rectangle((x, y, x + w, y + h), fill=col)
        for yy in range(y + 3, y + h - 1, 2):
            d.line([(x + 2, yy), (x + w - 2 - rnd.randint(0, 4), yy)], fill=(110, 110, 120))
        d.point((x + w // 2, y + 1), fill=rnd.choice([(220, 40, 40), (40, 90, 220), (240, 200, 40)]))
    return im, em


def lockers(rnd):
    """2 x 2 m grey steel locker bank: four doors, vents, name tags, one with a sticker."""
    im, d, em, e = new(64, 64, (120, 126, 132, 255))
    for i in range(4):
        x = 1 + i * 16
        d.rectangle((x, 1, x + 14, 62), fill=(150, 156, 162))
        d.rectangle((x, 1, x + 14, 2), fill=(176, 182, 188))
        for y in range(6, 14, 2):
            d.line([(x + 3, y), (x + 11, y)], fill=(96, 100, 108))
        d.rectangle((x + 4, 18, x + 10, 21), fill=(236, 236, 228))
        d.rectangle((x + 11, 30, x + 12, 36), fill=(70, 72, 78))
    d.ellipse((38, 44, 44, 50), fill=(250, 180, 200))
    return im, em


def getabako(rnd):
    """2 x 2 m shoe cubbies: rows of wooden boxes, white indoor shoes, street shoes, little name cards."""
    im, d, em, e = new(64, 64, (*WOOD[0], 255))
    for row in range(5):
        for col in range(4):
            x, y = 2 + col * 15, 2 + row * 12
            d.rectangle((x, y, x + 13, y + 10), fill=(58, 40, 28))
            d.rectangle((x + 1, y + 9, x + 12, y + 10), fill=WOOD[2])
            if rnd.random() < 0.8:
                shoe = (238, 238, 232) if rnd.random() < 0.6 else rnd.choice([(40, 36, 40), (90, 60, 40), (60, 70, 120)])
                d.rectangle((x + 2, y + 5, x + 6, y + 8), fill=shoe)
                d.rectangle((x + 7, y + 5, x + 11, y + 8), fill=shoe)
            d.rectangle((x + 4, y + 1, x + 9, y + 2), fill=(240, 236, 220))
    return im, em


def books(rnd):
    """2 x 2 m bookshelf: four shelves of coloured spines, a few leaning, one gap."""
    im, d, em, e = new(64, 64, (*WOOD[0], 255))
    for row in range(4):
        y0 = 2 + row * 16
        d.rectangle((2, y0, 61, y0 + 13), fill=(40, 28, 22))
        x = 3
        while x < 60:
            w = rnd.randint(2, 4)
            h = rnd.randint(9, 13)
            if rnd.random() < 0.06:
                x += w + 2
                continue
            col = rnd.choice([(150, 40, 40), (40, 70, 130), (60, 110, 60), (200, 170, 90), (120, 70, 40), (230, 225, 210), (90, 50, 110)])
            d.rectangle((x, y0 + 13 - h, x + w - 1, y0 + 13), fill=col)
            d.point((x, y0 + 15 - h), fill=(240, 220, 150))
            x += w
        d.rectangle((2, y0 + 14, 61, y0 + 15), fill=WOOD[2])
    return im, em


def window_out(rnd):
    """2 x 2 m classroom window looking out: spring sky, clouds, a sakura crown, the hills; frame and a curtain."""
    im, d, em, e = new(64, 64, (0, 0, 0, 0))
    for y in range(4, 60):
        t = (y - 4) / 56.0
        col = (int(150 + 70 * t), int(196 + 30 * t), int(240 - 10 * t))
        d.line([(4, y), (59, y)], fill=col)
        e.line([(4, y), (59, y)], fill=(int(col[0] * 0.55), int(col[1] * 0.55), int(col[2] * 0.55)))
    for k in range(3):
        cx, cy = rnd.randint(10, 50), rnd.randint(8, 22)
        d.ellipse((cx - 8, cy - 3, cx + 8, cy + 3), fill=(250, 250, 255))
    d.polygon([(4, 50), (20, 40), (34, 46), (48, 38), (59, 44), (59, 59), (4, 59)], fill=(90, 130, 110))
    for k in range(40):  # sakura crown in the corner
        x, y = rnd.randint(36, 59), rnd.randint(30, 52)
        d.point((x, y), fill=rnd.choice([(250, 200, 214), (246, 170, 196), (255, 228, 236)]))
    d.rectangle((0, 0, 63, 3), fill=(200, 204, 208))
    d.rectangle((0, 60, 63, 63), fill=(200, 204, 208))
    d.rectangle((0, 0, 3, 63), fill=(200, 204, 208))
    d.rectangle((60, 0, 63, 63), fill=(200, 204, 208))
    d.rectangle((30, 0, 33, 63), fill=(200, 204, 208))
    d.rectangle((4, 4, 12, 59), fill=(236, 230, 210))  # gathered curtain
    for y in range(4, 60, 3):
        d.point((8, y), fill=(210, 204, 186))
    return im, em


def stairs_sign(rnd):
    im, d, em, e = new(32, 16, (40, 120, 70, 255))
    d.polygon([(4, 12), (10, 4), (16, 12)], fill=(240, 250, 240))
    d.rectangle((19, 5, 28, 11), fill=(240, 250, 240))
    e.rectangle((0, 0, 31, 15), fill=(60, 180, 100))
    return im, em


GEN = {"blackboard": blackboard, "cork": corkboard, "lockers": lockers, "getabako": getabako, "books": books,
       "window_out": window_out, "exit": stairs_sign, "grime": grime, "blossom": blossom, "leaves": leaves, "clouds": clouds, "koshi": koshi, "shop": shop, "shutter": shutter, "door": door, "school": school,
       "win": lambda r: window(r, "win"), "shoji": lambda r: window(r, "shoji"), "alu": lambda r: window(r, "alu")}


if __name__ == "__main__":
    for name, fn in GEN.items():
        im, em = fn(random.Random(name))
        im.save(os.path.join(OUT, "jp_f_%s.png" % name))
        em.save(os.path.join(OUT, "jp_f_%s_e.png" % name))
        print("jp_f_" + name)
