# gust_contrast.py look.png flat.png classes.png : how much the gusts change the water's brightness, per wind class.
# look: the water as drawn; flat: the same frame with the gust picture read as 1 everywhere (no gusts, lulls
# or lee in the look); classes: the same frame with the water drawn as 9 grey levels of the wind ratio
# r = wind here / lake's mean (class c: r from 0.80 + 0.05 c to 0.85 + 0.05 c). Prints, per class, the
# brightness (luminance) change the gusts make, in %.
import sys
import numpy as np
from PIL import Image

LEVELS = [50, 89, 115, 135, 151, 164, 175, 185, 193]


def load(p):
    return np.asarray(Image.open(p).convert("RGB")).astype(float)


look, flat, dbg = load(sys.argv[1]), load(sys.argv[2]), load(sys.argv[3])
h, w, _ = look.shape
grey = (np.abs(dbg[..., 0] - dbg[..., 1]) < 6) & (np.abs(dbg[..., 1] - dbg[..., 2]) < 12)
mask = grey.copy()
mask[:40, :] = False
mask[470:690, 1110:1270] = False
mask[20:150, 1130:1260] = False
lum = lambda a: 0.2126 * a[..., 0] + 0.7152 * a[..., 1] + 0.0722 * a[..., 2]
L, F = lum(look), lum(flat)
level = dbg[..., 0]
cls = np.argmin(np.abs(level[..., None] - np.array(LEVELS)[None, None, :]), axis=2)
near = np.min(np.abs(level[..., None] - np.array(LEVELS)[None, None, :]), axis=2) <= 3
mask &= near & (F > 3)
rows = []
for c in range(9):
    m = mask & (cls == c)
    if m.sum() < 1500:
        continue
    r0 = 0.80 + 0.05 * c
    label = f"{r0:.2f}-{r0 + 0.05:.2f}" if 0 < c < 8 else ("below 0.85" if c == 0 else "1.20 and more")
    rows.append((label, int(m.sum()), 100.0 * (L[m].mean() / F[m].mean() - 1.0)))
for label, n, change in rows:
    print(f"{label:>14} {n:8d} {change:+6.1f} %")
