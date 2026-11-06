"""Contact sheets of the board's effects on the water (board_fx.md).

Reads the pictures shoot.sh saved in .screenshots/board_fx/<tag>/ and writes, next to this script:
  sheet_<tag>_<group>.jpg   the views of one group side by side, labelled
  compare_<group>.jpg       before (left) and after (right), view by view, when both tags exist
  landing_<tag>.jpg         the twelve landing pictures on the lake at x1.65, numbered
Run from the repository's root: python Documentation/reports/waves/board_fx/sheet.py <tag> [<tag> ...]
"""
import os
import sys

from PIL import Image, ImageDraw, ImageFont

SOURCE = ".screenshots/board_fx"
HERE = os.path.dirname(os.path.abspath(__file__))
TILE_W = 640

GROUPS = {
    "open": [("open_follow_12", "open water 12 kt, follow"), ("open_follow_18", "open 18 kt, follow"),
             ("open_follow_24", "open 24 kt, follow"), ("open_side_12", "open 12 kt, leeward side"),
             ("open_side_18", "open 18 kt, leeward side"), ("open_side_24", "open 24 kt, leeward side")],
    "lake": [("lake_follow_12", "lake x0.66 (12 kt), follow"), ("lake_follow_18", "lake x1.0 (18 kt), follow"),
             ("lake_follow_24", "lake x1.32 (24 kt), follow"), ("lake_side_24", "lake x1.32 (24 kt), leeward side")],
    "moments": [("open_start_18", "start, 2.5 s from rest, 18 kt"), ("open_carve_24", "bear-away carve, 24 kt"),
                ("open_fall_18", "catapult fall, 0.9 s in, 18 kt"), ("crest_30", "open 30 kt, follow (crest spray)"),
                ("open_start_12", "start, 5 s from rest, 12 kt (bow wave)"), ("crest_30_sailing", "open 30 kt at 6.7 s, follow")],
}
TITLES = {
    "open": "Open water (Swell sea state), the autopilot on a beam reach, 10 s after the start",
    "lake": "Lake Silvaplana at 14:30, Lake wind multiplier, 10 s after the start",
    "moments": "The moments: the start, a carve, a fall, the strongest wind",
}


def font(size):
    for name in ("arialbd.ttf", "arial.ttf", "DejaVuSans-Bold.ttf"):
        try:
            return ImageFont.truetype(name, size)
        except OSError:
            continue
    return ImageFont.load_default()


def tile(path, width=TILE_W):
    image = Image.open(path).convert("RGB")
    return image.resize((width, round(image.height * width / image.width)), Image.LANCZOS)


def label(draw, x, y, text, size=22):
    w = draw.textlength(text, font=font(size))
    draw.rectangle((x + 6, y + 6, x + 18 + w, y + 14 + size), fill=(0, 0, 0))
    draw.text((x + 12, y + 8), text, fill=(255, 255, 255), font=font(size))


def group_sheet(tag, group):
    views = [(name, text) for name, text in GROUPS[group] if os.path.exists(os.path.join(SOURCE, tag, name + ".png"))]
    if not views:
        return
    tiles = [(text, tile(os.path.join(SOURCE, tag, name + ".png"))) for name, text in views]
    tile_h = tiles[0][1].height
    columns = min(3, len(tiles)) if len(tiles) != 4 else 2
    rows = (len(tiles) + columns - 1) // columns
    top = 46
    out = Image.new("RGB", (columns * TILE_W, top + rows * tile_h), (24, 24, 28))
    draw = ImageDraw.Draw(out)
    draw.text((12, 10), "%s (%s)" % (TITLES[group], tag), fill=(240, 240, 240), font=font(24))
    for i, (text, image) in enumerate(tiles):
        x = (i % columns) * TILE_W
        y = top + (i // columns) * tile_h
        out.paste(image, (x, y))
        label(draw, x, y, text)
    path = os.path.join(HERE, "sheet_%s_%s.jpg" % (tag, group))
    out.save(path, quality=86)
    print("wrote", path)


def compare_sheet(group):
    rows = []
    for name, text in GROUPS[group]:
        before = os.path.join(SOURCE, "before", name + ".png")
        after = os.path.join(SOURCE, "after", name + ".png")
        if os.path.exists(before) and os.path.exists(after):
            rows.append((text, tile(before), tile(after)))
    if not rows:
        return
    tile_h = rows[0][1].height
    top = 46
    out = Image.new("RGB", (2 * TILE_W + 8, top + len(rows) * (tile_h + 8)), (24, 24, 28))
    draw = ImageDraw.Draw(out)
    draw.text((12, 10), "Before (left) and after (right): " + TITLES[group], fill=(240, 240, 240), font=font(24))
    for i, (text, before, after) in enumerate(rows):
        y = top + i * (tile_h + 8)
        out.paste(before, (0, y))
        out.paste(after, (TILE_W + 8, y))
        label(draw, 0, y, "before: " + text)
        label(draw, TILE_W + 8, y, "after: " + text)
    path = os.path.join(HERE, "compare_%s.jpg" % group)
    out.save(path, quality=86)
    print("wrote", path)


def landing_sheet(tag):
    paths = [os.path.join(SOURCE, tag, "lake_landing_30_%d.png" % i) for i in range(1, 13)]
    paths = [p for p in paths if os.path.exists(p)]
    if not paths:
        return
    width = 480
    tiles = [tile(p, width) for p in paths]
    tile_h = tiles[0].height
    columns = 4
    rows = (len(tiles) + columns - 1) // columns
    top = 46
    out = Image.new("RGB", (columns * width, top + rows * tile_h), (24, 24, 28))
    draw = ImageDraw.Draw(out)
    draw.text((12, 10), "Lake x1.65 (30 kt), leeward side, every 0.2 s from 7 s (%s)" % tag, fill=(240, 240, 240), font=font(24))
    for i, image in enumerate(tiles):
        x = (i % columns) * width
        y = top + (i // columns) * tile_h
        out.paste(image, (x, y))
        label(draw, x, y, "%d" % (i + 1))
    path = os.path.join(HERE, "landing_%s.jpg" % tag)
    out.save(path, quality=86)
    print("wrote", path)


if __name__ == "__main__":
    tags = sys.argv[1:] or ["before", "after"]
    for tag in tags:
        for group in GROUPS:
            group_sheet(tag, group)
        landing_sheet(tag)
    if os.path.isdir(os.path.join(SOURCE, "before")) and os.path.isdir(os.path.join(SOURCE, "after")):
        for group in GROUPS:
            compare_sheet(group)
