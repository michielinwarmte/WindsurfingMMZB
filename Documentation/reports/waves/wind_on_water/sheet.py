"""Contact sheets of the wind on the water at five strengths (wind_on_water.md).

Reads the pictures shoot.sh saved in .screenshots/wind_on_water/ and writes, next to this script,
a sheet per water and view: the five winds side by side, each labelled with its knots.
Run from the repository's root: python -I Documentation/reports/waves/wind_on_water/sheet.py [prefix ...]
"""
import os
import sys

from PIL import Image, ImageDraw, ImageFont

SOURCE = ".screenshots/wind_on_water"
HERE = os.path.dirname(os.path.abspath(__file__))
KNOTS = [8, 12, 18, 24, 30]
# Each picture is shrunk to this width; the sheet is two rows (three and two) or one row.
TILE_W = 640


def font(size):
    for name in ("arialbd.ttf", "arial.ttf", "DejaVuSans-Bold.ttf"):
        try:
            return ImageFont.truetype(name, size)
        except OSError:
            continue
    return ImageFont.load_default()


def sheet(prefix, title):
    tiles = []
    for knots in KNOTS:
        path = os.path.join(SOURCE, "%s_%d.png" % (prefix, knots))
        if not os.path.exists(path):
            print("missing", path)
            return
        image = Image.open(path).convert("RGB")
        tile_h = round(image.height * TILE_W / image.width)
        tiles.append((knots, image.resize((TILE_W, tile_h), Image.LANCZOS)))
    tile_h = tiles[0][1].height
    columns = 3
    rows = 2
    top = 50
    out = Image.new("RGB", (columns * TILE_W, top + rows * tile_h), (24, 24, 28))
    draw = ImageDraw.Draw(out)
    draw.text((12, 10), title, fill=(240, 240, 240), font=font(26))
    for i, (knots, tile) in enumerate(tiles):
        x = (i % columns) * TILE_W
        y = top + (i // columns) * tile_h
        out.paste(tile, (x, y))
        draw.rectangle((x + 8, y + 8, x + 118, y + 48), fill=(0, 0, 0))
        draw.text((x + 16, y + 12), "%d kt" % knots, fill=(255, 255, 255), font=font(28))
    path = os.path.join(HERE, "sheet_%s.jpg" % prefix)
    out.save(path, quality=88)
    print("wrote", path)


TITLES = {
    "lake_near": "Lake Silvaplana, follow camera at the start, 14:30, Lake wind x0.44 / 0.66 / 1.0 / 1.32 / 1.65",
    "lake_high": "Lake Silvaplana from 40 m up at the camping beach, looking down the lake toward Sils",
    "open_near": "Open water, follow camera, the settings' wind speed (the other settings their defaults: Swell sea state)",
    "open_high": "Open water, the free camera above the board, the settings' wind",
}

if __name__ == "__main__":
    for prefix in sys.argv[1:] or list(TITLES):
        sheet(prefix, TITLES.get(prefix, prefix))
