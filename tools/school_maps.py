#!/usr/bin/env python3
## Regenerates data/maps/school_*.txt (overwrites hand edits!). Legend: src/world/jp_school.gd.
# Generates data/maps/school_*.txt (then hand-editable). Legend in src/world/jp_kit.gd school_cell.
import os
W, H = 40, 18
OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "data", "maps")

def blank():
    return [["#"] * W for _ in range(H)]

def room(g, x0, z0, x1, z1, floor):
    for z in range(z0, z1 + 1):
        for x in range(x0, x1 + 1):
            g[z][x] = floor

def put(g, x, z, c):
    g[z][x] = c

def row(g, z, xs, c):
    for x in xs:
        g[z][x] = c

def doors(g, z, xs, c="."):
    for x in xs:
        g[z][x] = c

def classroom(g, x0, x1):
    room(g, x0, 1, x1, 7, "_")
    cx = (x0 + x1) // 2
    row(g, 1, range(cx - 1, cx + 2), "k")
    put(g, cx, 2, "t")
    for z in (3, 4, 5, 6):
        for x in range(x0 + 1, x1, 2):
            put(g, x, z, "d")
    put(g, x0, 7, "l"); put(g, x1, 7, "l")
    put(g, x1, 1, "n")
    put(g, x0, 1, "f")
    put(g, x0 + 2, 6, "N"); put(g, x1 - 2, 4, "N"); put(g, cx, 5, "N")

def save(name, g):
    with open(os.path.join(OUT, "school_%s.txt" % name), "w") as f:
        f.write("\n".join("".join(r) for r in g) + "\n")

# ---- 1F: staff room, principal, infirmary / store, entrance, counselor, toilets
g = blank()
room(g, 1, 1, 4, 7, ";"); put(g, 2, 2, "S")                       # west stairs
room(g, 6, 1, 19, 7, "."); row(g, 1, (6, 7), "h"); put(g, 8, 1, "n"); row(g, 1, (11, 12, 13), "s"); put(g, 19, 1, "f")
for x in (8, 9, 10, 14, 15, 16):
    put(g, x, 3, "a"); put(g, x, 4, "a")
put(g, 18, 6, "z"); put(g, 7, 6, "j"); put(g, 9, 6, "N"); put(g, 15, 6, "N")
room(g, 21, 1, 26, 7, "_"); put(g, 21, 1, "r"); put(g, 23, 1, "n"); put(g, 24, 2, "a"); put(g, 26, 1, "f")
row(g, 5, (22, 23), "o"); put(g, 22, 6, "z")
room(g, 28, 1, 34, 7, ";"); row(g, 2, (29, 31, 33), "b"); put(g, 28, 6, "u"); put(g, 34, 6, "h"); put(g, 32, 6, "a"); put(g, 34, 1, "f")
room(g, 36, 1, 38, 7, ";"); put(g, 37, 2, "S")
doors(g, 8, (2, 3, 8, 9, 16, 17, 23, 30, 31, 37))
room(g, 1, 9, 38, 10, ".")
put(g, 12, 9, "j"); put(g, 26, 9, "f"); put(g, 34, 9, "y")
doors(g, 11, (4, 5, 12, 13, 14, 15, 16, 17, 18, 19, 25, 33))
room(g, 1, 12, 8, 16, ";"); row(g, 12, range(2, 7), "h"); row(g, 13, range(2, 7), "c"); put(g, 8, 12, "y")
row(g, 15, (2, 4, 6), "z"); put(g, 3, 16, "N")
room(g, 10, 12, 21, 16, ";"); row(g, 13, (11, 12, 13), "g"); row(g, 13, (18, 19, 20), "g"); row(g, 15, (11, 12, 13), "g"); row(g, 15, (18, 19, 20), "g")
put(g, 10, 12, "n"); put(g, 21, 12, "r"); put(g, 11, 16, "f"); put(g, 20, 16, "f")
doors(g, 17, (15, 16), "X")
room(g, 23, 12, 28, 16, "_"); row(g, 14, (24, 25), "o"); put(g, 24, 15, "z"); put(g, 27, 12, "s"); put(g, 28, 12, "f")
room(g, 30, 12, 38, 16, ","); row(g, 16, (31, 32, 33, 34), "w"); row(g, 12, (36, 37, 38), "u")
save("1f", g)

# ---- 2F: 2-A, 2-B, library / art, newspaper club, student council, toilets, storage
g = blank()
room(g, 1, 1, 4, 7, ";"); put(g, 2, 2, "D"); put(g, 3, 5, "S")
classroom(g, 6, 14); classroom(g, 16, 24)
room(g, 26, 1, 34, 7, "_"); row(g, 1, range(26, 35), "s"); row(g, 3, (27, 28, 29), "s"); row(g, 3, (31, 32, 33), "s")
row(g, 5, (27, 29, 31, 33), "z"); put(g, 34, 7, "c"); put(g, 26, 7, "f"); put(g, 30, 6, "N")
room(g, 36, 1, 38, 7, ";"); put(g, 37, 2, "D"); put(g, 37, 5, "S")
doors(g, 8, (2, 3, 7, 13, 17, 23, 28, 29, 37))
room(g, 1, 9, 38, 10, "."); put(g, 10, 9, "n"); put(g, 22, 9, "j"); put(g, 30, 9, "f")
doors(g, 11, (5, 6, 13, 21, 28, 35))
room(g, 1, 12, 10, 16, "_"); put(g, 1, 12, "m"); row(g, 12, (3, 4, 5), "h"); row(g, 14, (2, 4, 6, 8), "e"); row(g, 16, (3, 5, 7), "e"); put(g, 9, 12, "s"); put(g, 7, 15, "N")
room(g, 12, 12, 16, 16, ":"); row(g, 12, (12, 13), "n"); put(g, 16, 12, "h"); put(g, 14, 14, "z"); put(g, 15, 16, "a")
room(g, 18, 12, 24, 16, "_"); row(g, 14, (19, 20, 21, 22, 23), "z"); put(g, 18, 12, "r"); put(g, 21, 12, "n"); put(g, 24, 12, "f")
room(g, 26, 12, 31, 16, ","); row(g, 16, (27, 28, 29), "w"); row(g, 12, (29, 30, 31), "u")
room(g, 33, 12, 38, 16, "."); row(g, 12, range(33, 39), "h"); row(g, 14, (34, 36), "h")
save("2f", g)

# ---- 3F: 1-A, 1-B, 3-A / music, science, girls' toilet (Hanako), storage
g = blank()
room(g, 1, 1, 4, 7, ";"); put(g, 3, 5, "D"); put(g, 2, 2, "K")
classroom(g, 6, 14); classroom(g, 16, 24); classroom(g, 26, 34)
room(g, 36, 1, 38, 7, ";"); put(g, 37, 5, "D")
doors(g, 8, (2, 3, 7, 13, 17, 23, 27, 33, 37))
room(g, 1, 9, 38, 10, "."); put(g, 14, 9, "f"); put(g, 25, 9, "j"); put(g, 35, 9, "n")
doors(g, 11, (5, 6, 18, 27, 34))
room(g, 1, 12, 12, 16, "="); put(g, 3, 13, "p"); row(g, 12, (7, 8, 9), "k"); row(g, 15, (6, 8, 10), "d"); row(g, 16, (6, 8, 10), "d"); put(g, 12, 12, "h"); put(g, 1, 16, "f")
room(g, 14, 12, 22, 16, ","); row(g, 13, (15, 16), "v"); row(g, 13, (19, 20), "v"); row(g, 15, (15, 16), "v"); row(g, 15, (19, 20), "v"); put(g, 22, 12, "x"); row(g, 12, (14, 15, 16), "h"); put(g, 18, 12, "u")
room(g, 24, 12, 30, 16, ","); row(g, 16, (25, 26, 27), "w"); row(g, 12, (28, 29, 30), "u"); put(g, 24, 12, "m")
room(g, 32, 12, 38, 16, "."); row(g, 12, range(32, 39), "h"); row(g, 14, (33, 35, 37), "h")
save("3f", g)

# ---- roof: water tank, benches, gardening pots, the door hut
g = blank()
room(g, 1, 1, 38, 16, ";")
room(g, 1, 1, 4, 4, ";"); put(g, 2, 2, "D")
row(g, 2, (20, 21, 22), "Y"); row(g, 6, (8, 9), "i"); row(g, 6, (30, 31), "i"); row(g, 12, (14, 15), "i")
for x in (6, 7, 10, 26, 28, 33, 34):
    put(g, x, 15, "f")
row(g, 9, (36, 37), "q")
row(g, 9, (16, 17), "i"); row(g, 11, (22, 23), "i"); put(g, 19, 10, "z"); put(g, 26, 8, "j")
for x in range(12, 28, 3):
    put(g, x, 13, "f")
row(g, 5, (12, 13), "q"); put(g, 30, 10, "y")
save("roof", g)
print("ok")
