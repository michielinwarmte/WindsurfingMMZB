"""Measure colours in a video frame: the median colour inside named boxes.

The median ignores the odd whitecap or speck, so a box over water gives the water's colour.
Writes a copy of the frame with the boxes drawn and labelled (to check WHERE each sample
came from) and prints one line per box: name, median RGB, hex, and the box.

  python tools/video/sample_colours.py <frame.png> <out.png> name=x,y,w,h [name=x,y,w,h ...]

Boxes are in the frame's own pixels (x, y = top-left corner).
Camera caveat: these are the colours the camera recorded (white balance, exposure, grading
by the uploader), not the true colour of the water. Compare boxes within one frame first.
"""

import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont


def parse_box(arg):
    name, nums = arg.split("=", 1)
    x, y, w, h = (int(v) for v in nums.split(","))
    return name, (x, y, w, h)


def main():
    if len(sys.argv) < 4:
        sys.exit(__doc__)
    frame = Image.open(sys.argv[1]).convert("RGB")
    pixels = np.asarray(frame)
    marked = frame.copy()
    draw = ImageDraw.Draw(marked)
    try:
        font = ImageFont.truetype("C:/Windows/Fonts/consola.ttf", 16)
    except OSError:
        font = ImageFont.load_default()
    for arg in sys.argv[3:]:
        name, (x, y, w, h) = parse_box(arg)
        patch = pixels[y:y + h, x:x + w].reshape(-1, 3)
        r, g, b = (int(v) for v in np.median(patch, axis=0))
        hexcol = "#%02x%02x%02x" % (r, g, b)
        print("%-22s rgb(%3d,%3d,%3d)  %s   box %d,%d,%d,%d" % (name, r, g, b, hexcol, x, y, w, h))
        draw.rectangle([x, y, x + w, y + h], outline=(255, 0, 255), width=2)
        draw.rectangle([x, y - 20, x + 20, y - 2], fill=(r, g, b), outline=(0, 0, 0))
        draw.text((x + 24, y - 20), name, fill=(255, 0, 255), font=font)
    marked.save(sys.argv[2])


if __name__ == "__main__":
    main()
