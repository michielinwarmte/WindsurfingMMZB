"""Frames with a labelled pixel grid, side by side, for reading positions by eye.

  python tools/video/grid_overlay.py <name> <out.png> --times 1,3,5 [--crop x,y,w,h]
                                     [--step 100] [--scale 0.5]

Grid lines every --step pixels of the ORIGINAL frame (labelled in original pixels), so points
read off the picture can be used directly for angles and lengths. --crop limits the view to one
part of the frame (still labelled in original pixels); --scale shrinks each frame for viewing.
Angles from points read this way are good to about 1 to 2 degrees on features a few hundred
pixels long.
"""

import argparse
import os
import subprocess
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont

sys.path.insert(0, os.path.dirname(__file__))
from video import ffmpeg, original, probe  # noqa: E402


def frame_at(path, t, w, h):
    raw = subprocess.run([ffmpeg("ffmpeg"), "-v", "error", "-ss", "%.3f" % t, "-i", path,
                          "-frames:v", "1", "-f", "rawvideo", "-pix_fmt", "rgb24", "-"],
                         capture_output=True, check=True).stdout
    return Image.fromarray(np.frombuffer(raw, np.uint8).reshape(h, w, 3))


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("name")
    ap.add_argument("out")
    ap.add_argument("--times", required=True)
    ap.add_argument("--crop")
    ap.add_argument("--step", type=int, default=100)
    ap.add_argument("--scale", type=float, default=0.5)
    a = ap.parse_args()
    path = original(a.name)
    info = probe(path)
    W, H = info["width"], info["height"]
    x0, y0, cw, ch = (int(v) for v in a.crop.split(",")) if a.crop else (0, 0, W, H)
    try:
        font = ImageFont.truetype("C:/Windows/Fonts/consola.ttf", 14)
    except OSError:
        font = ImageFont.load_default()
    tiles = []
    for t in (float(v) for v in a.times.split(",")):
        img = frame_at(path, t, W, H).crop((x0, y0, x0 + cw, y0 + ch))
        img = img.resize((int(cw * a.scale), int(ch * a.scale)), Image.LANCZOS)
        d = ImageDraw.Draw(img)
        for gx in range((x0 // a.step + 1) * a.step, x0 + cw, a.step):
            px = (gx - x0) * a.scale
            d.line([px, 0, px, img.height], fill=(255, 255, 0), width=1)
            d.text((px + 2, 2), str(gx), fill=(255, 255, 0), font=font)
        for gy in range((y0 // a.step + 1) * a.step, y0 + ch, a.step):
            py = (gy - y0) * a.scale
            d.line([0, py, img.width, py], fill=(0, 255, 255), width=1)
            d.text((2, py + 2), str(gy), fill=(0, 255, 255), font=font)
        d.rectangle([0, img.height - 20, 110, img.height], fill=(0, 0, 0))
        d.text((4, img.height - 18), "t=%.2fs" % t, fill=(255, 255, 255), font=font)
        tiles.append(img)
    sheet = Image.new("RGB", (sum(t.width for t in tiles) + 6 * (len(tiles) - 1), tiles[0].height),
                      (20, 20, 20))
    x = 0
    for t in tiles:
        sheet.paste(t, (x, 0))
        x += t.width + 6
    sheet.save(a.out)
    print(a.out, sheet.size)


if __name__ == "__main__":
    main()
