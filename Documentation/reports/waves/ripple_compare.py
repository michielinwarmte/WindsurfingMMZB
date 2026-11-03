"""Compares the ripples' look in the chase view: north wind (heading east) against west wind
(heading north), the wind from the camera's left in both. Minimal PNG reader (8-bit RGB/RGBA)."""
import sys, zlib, struct
import numpy as np


def read_png(path):
    data = open(path, "rb").read()
    pos, chunks, w = 8, [], 0
    while pos < len(data):
        n, kind = struct.unpack(">I4s", data[pos:pos + 8])
        body = data[pos + 8:pos + 8 + n]
        if kind == b"IHDR":
            w, h, depth, ctype = struct.unpack(">IIBB", body[:10])
            ch = {2: 3, 6: 4}[ctype]
        elif kind == b"IDAT":
            chunks.append(body)
        pos += 12 + n
    raw = zlib.decompress(b"".join(chunks))
    stride = w * ch
    img = np.zeros((h, stride), np.int32)
    prev = np.zeros(stride, np.int32)
    for y in range(h):
        f = raw[y * (stride + 1)]
        line = np.frombuffer(raw, np.uint8, stride, y * (stride + 1) + 1).astype(np.int32)
        out = np.zeros(stride, np.int32)
        if f == 0:
            out = line
        elif f == 2:
            out = (line + prev) & 255
        else:
            for i in range(stride):
                a = out[i - ch] if i >= ch else 0
                b = prev[i]
                c = prev[i - ch] if i >= ch else 0
                if f == 1:
                    p = a
                elif f == 3:
                    p = (a + b) // 2
                else:
                    pa, pb, pc = abs(b - c), abs(a - c), abs(a + b - 2 * c)
                    p = a if pa <= pb and pa <= pc else (b if pb <= pc else c)
                out[i] = (line[i] + p) & 255
        img[y] = out
        prev = out
    return img.reshape(h, w, ch)[:, :, :3].astype(float).mean(axis=2)


def patch(img):
    # The water left of the board, below the horizon, clear of the buoy and the grid's near lines.
    return img[420:520, 20:520]


def stats(img):
    p = patch(img)
    p = p - p.mean()
    gx = np.diff(p, axis=1)[:-1, :]
    gy = np.diff(p, axis=0)[:, :-1]
    share_x = (gx ** 2).sum() / ((gx ** 2).sum() + (gy ** 2).sum())
    spec = np.log1p(np.abs(np.fft.fft2(p)) ** 2)
    return share_x, spec, p.std()


names = sys.argv[1:]
res = {n: stats(read_png(n)) for n in names}
for n in names:
    print("%-28s gradient across the screen %.2f   contrast %.1f" % (n.split("/")[-1].split("\\")[-1], res[n][0], res[n][2]))
for a, b in zip(names[0::2], names[1::2]):
    c = np.corrcoef(res[a][1].ravel(), res[b][1].ravel())[0, 1]
    print("spectrum correlation %s vs %s: %.3f" % (a.split("/")[-1], b.split("/")[-1], c))
