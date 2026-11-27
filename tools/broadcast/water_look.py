"""Measure how the water looks in a picture: its colour from near to far, the white water, the haze.

For matching the game's sea to the stream's (Max, 27 November 2026: "the water shader really
is off ... try to match the water look"). The water between the horizon and the picture's
bottom is cut into five bands (1 = just under the horizon, the far water; 5 = the bottom,
the near water). Per band: the water's own colour (the middle value of the pixels that are
neither white water nor a sail or a boat), how much of the band is white water, and how
much the water's brightness varies (the texture of the chop).

    python -E -P tools/broadcast/water_look.py real <media root> <follow_heights.csv> <out folder>
        the stream: one frame from the middle of every drone beat in the csv (its horizon row is there)
    python -E -P tools/broadcast/water_look.py game <out folder> <picture.png>:<horizon row as a share 0-1> [...]
        the game: screenshots, each with where its horizon sits

Writes <out folder>/water_<real|game>.json and a strip of colour swatches water_<real|game>.png
(left to right: band 1 far ... band 5 near; then the sky just above the horizon).
"""
import csv
import json
import os
import sys

import cv2
import numpy as np

BANDS = 5


def measure(frame, horizon_y):
    """Per band: the water's colour (B, G, R), white share, texture; and the sky's colour."""
    h, w = frame.shape[:2]
    hsv = cv2.cvtColor(frame, cv2.COLOR_BGR2HSV)
    hue, sat, val = cv2.split(hsv)
    white = (sat < 75) & (val > 150)
    # Water: blue to green hues with some colour in them. Everything else below the horizon
    # that isn't white is a sail, a board, a boat, a buoy or a graphic.
    water = (hue > 70) & (hue < 128) & (sat > 55) & ~white
    out = []
    edges = np.linspace(horizon_y + 4, h, BANDS + 1).astype(int)
    for i in range(BANDS):
        a, b = edges[i], edges[i + 1]
        if b - a < 4:
            out.append(None)
            continue
        wm, fm = water[a:b], white[a:b]
        n_water, n_white = int(wm.sum()), int(fm.sum())
        if n_water < 200:
            out.append(None)
            continue
        px = frame[a:b][wm]
        gray = cv2.cvtColor(frame[a:b], cv2.COLOR_BGR2GRAY).astype(np.float32)
        out.append({"bgr": [float(np.median(px[:, k])) for k in range(3)],
                    "hsv": [float(np.median(hsv[a:b][wm][:, k])) for k in range(3)],
                    "white_pct": 100.0 * n_white / max(n_water + n_white, 1),
                    "texture": float(np.std(gray[wm]) / max(np.mean(gray[wm]), 1.0))})
    sky = None
    if horizon_y > 30:
        band = frame[max(horizon_y - 28, 0):max(horizon_y - 6, 1)]
        sky = [float(np.median(band[:, :, k])) for k in range(3)]
    return out, sky


def pool(items):
    """The middle value over many pictures, per band."""
    bands = []
    for i in range(BANDS):
        got = [m[i] for m, _ in items if m[i] is not None]
        if not got:
            bands.append(None)
            continue
        mid = lambda vals: float(np.median(vals))
        bands.append({"pictures": len(got),
                      "rgb": [round(mid([g["bgr"][2 - k] for g in got])) for k in range(3)],
                      "hue_deg": round(2.0 * mid([g["hsv"][0] for g in got])),
                      "saturation_pct": round(mid([g["hsv"][1] for g in got]) / 2.55),
                      "brightness_pct": round(mid([g["hsv"][2] for g in got]) / 2.55),
                      "white_pct": round(mid([g["white_pct"] for g in got]), 1),
                      "white_pct_p25_p75": [round(float(np.percentile([g["white_pct"] for g in got], p)), 1) for p in (25, 75)],
                      "texture": round(mid([g["texture"] for g in got]), 3)})
    skies = [s for _, s in items if s is not None]
    sky = [round(float(np.median([s[2 - k] for s in skies]))) for k in range(3)] if skies else None
    return {"bands_far_to_near": bands, "sky_above_horizon_rgb": sky, "pictures": len(items)}


def swatches(result, path):
    tiles = []
    for b in result["bands_far_to_near"]:
        rgb = b["rgb"] if b else [0, 0, 0]
        tiles.append(np.full((90, 110, 3), rgb[::-1], dtype=np.uint8))
    sky = result["sky_above_horizon_rgb"] or [0, 0, 0]
    tiles.append(np.full((90, 110, 3), sky[::-1], dtype=np.uint8))
    cv2.imwrite(path, np.hstack(tiles))


def show(name, result):
    print("%s: %d pictures" % (name, result["pictures"]))
    print("  band      colour (R G B)   hue  sat%  bright%  white water %   texture")
    for i, b in enumerate(result["bands_far_to_near"], 1):
        if b:
            print("  %d %-6s  %3d %3d %3d      %3d   %3d    %3d      %4.1f (%s-%s)    %.3f"
                  % (i, "far" if i == 1 else ("near" if i == BANDS else ""), b["rgb"][0], b["rgb"][1], b["rgb"][2],
                     b["hue_deg"], b["saturation_pct"], b["brightness_pct"], b["white_pct"],
                     b["white_pct_p25_p75"][0], b["white_pct_p25_p75"][1], b["texture"]))
    print("  sky just above the horizon (R G B):", result["sky_above_horizon_rgb"])


def main():
    what = sys.argv[1]
    if what == "real":
        root, table, out = sys.argv[2], sys.argv[3], sys.argv[4]
        os.makedirs(out, exist_ok=True)
        with open(table, encoding="utf-8") as f:
            rows = list(csv.DictReader(f))
        with open(os.path.join(os.path.dirname(table), "..", "web", "heats_fuerteventura_2026.json"), encoding="utf-8") as f:
            pass
        items, caps = [], {}
        for r in rows:
            notes = os.path.join(root, r["video"], "shots", "shot_notes.csv")
            with open(notes, encoding="utf-8-sig") as f:
                beat = [n for n in csv.DictReader(f) if n["shot"] + n["part"] == r["shot"]]
            if not beat:
                continue
            t = (float(beat[0]["start_s"]) + float(beat[0]["end_s"])) / 2.0
            cap = caps.setdefault(r["video"], cv2.VideoCapture(os.path.join(root, r["video"], "video.mp4")))
            cap.set(cv2.CAP_PROP_POS_MSEC, 1000.0 * t)
            ok, frame = cap.read()
            if ok:
                frame[:80, 700:] = frame[100:180, 700:]      # the logo in the corner, painted over with sky or sea
                items.append(measure(frame, int(r["horizon_y"])))
        result = pool(items)
        name = "real"
    else:
        out = sys.argv[2]
        os.makedirs(out, exist_ok=True)
        items = []
        for arg in sys.argv[3:]:
            path, share = arg.rsplit(":", 1)
            frame = cv2.imread(path)
            items.append(measure(frame, int(float(share) * frame.shape[0])))
        result = pool(items)
        name = "game"
    with open(os.path.join(out, "water_%s.json" % name), "w", encoding="utf-8") as f:
        json.dump(result, f, indent=1)
    swatches(result, os.path.join(out, "water_%s.png" % name))
    show(name, result)


if __name__ == "__main__":
    main()
