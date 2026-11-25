"""Automatic first pass over a downloaded windsurf video: shots, segments and labels.

  python tools/video/analyse.py <name> [--no-grids]

<name> is the video's folder in VIDEOS_ROOT (see video.py). Writes into that folder:
  analysis/frames.csv     one row per frame: every measurement below
  analysis/segments.json  the shots, the segments and their labels (also printed)
  analysis/timeline.png   the measurements over time, with the shots and segments marked
  grids/                  one standard frame grid per segment (unless --no-grids)

What it measures in every frame (on a small copy, longest side 480 px):
  - which pixels are water, foam/spray (white) and "rig" (dark or vivid colours: the sail,
    the sailor, the board); nothing above the horizon (sky and clouds) counts;
  - the rig: the biggest rig-coloured blob on the sea, followed from frame to frame; its size,
    and its lean (the angle of its long axis from upright; near 90 = the rig lies flat);
  - spray touching the rig's lower half (planing throws spray all the time; in the air none),
    and the size of the white wake attached to the rig;
  - the travel direction: from the attached wake towards the board (the wake lies behind);
  - the sea, on its nearer part: small white blobs = whitecaps (the share of the sea they
    cover) and the roughness of the water's texture.

What it labels (per segment): the manoeuvre (straight, gybe, jump = deliberate, airtime =
launched off chop while sailing on), the water state (flat,
chop, rough) and the camera distance. These are a first guess for Claude to check against the
frames; the thresholds below were set on video 01 (Sotavento) and are tuned as more videos
are checked.
Not automatic: the point of sail. It needs the wind direction, and a moving drone camera
hides it (a test with the spray's drift measured the camera's tracking, not the wind).
All angles are in the IMAGE (0 = right, 90 = up), not on the water.
"""

import argparse
import csv
import json
import math
import os
import subprocess
import sys

import cv2
import numpy as np
from PIL import Image, ImageDraw, ImageFont

sys.path.insert(0, os.path.dirname(__file__))
from video import ffmpeg, original, probe, video_dir  # noqa: E402

LONG_SIDE = 480  # analysis size: enough to see the rig and the whitecaps, fast to process

# --- Pixel classes, OpenCV HSV (H 0-179, S 0-255, V 0-255); set on video 01 -------------
WATER_HUE = (70, 125)      # cyan to blue
WATER_S_MIN, WATER_V_MIN = 45, 35
WHITE_S_MAX, WHITE_V_MIN = 75, 185   # foam, spray, whitewater (spray over turquoise is tinted)
WHITE_ABOVE_WATER = 35     # ... or this much brighter than the water around it
HORIZON_S_JUMP = 30        # the sea is this much more saturated than the sky just above it
SKY_S_MAX, SKY_V_MIN = 85, 150  # what counts as sky (or a pale beach) above a horizon
TURQUOISE_HUE = (75, 100)  # light shallow water: pale like sky, but this hue (sky is ~105-115)
DARK_V_MAX = 70            # mast, boom, wetsuit, the dark sail panels
VIVID_S_MIN = 110          # yellow, green, red, magenta sail panels (not water-coloured)
VIVID_BLUE_S, VIVID_BLUE_V = 175, 175  # blue sail panels: brighter AND more saturated than water

# --- Events -----------------------------------------------------------------------------
CUT_DIFF = 18.0            # mean grey change (0-255) a hard cut needs at least ...
CUT_RATIO = 2.5            # ... and this many times the usual change of the second before
                           # (a fast close-up changes 12-15 every frame without any cut)
COPY_DIFF = 0.5            # below this a frame is a copy of the one before
WHITECAP_MAX_BLOB = 0.0006  # white blobs smaller than this share of the frame are whitecaps
AIR_WAKE_SHARE = 0.30      # the attached wake shrinks below this share of its usual size ...
AIR_MIN_S = 0.30           # ... for at least this long = the board is in the air: a jump
AIR_JOIN_S = 0.50          # two flights closer than this are one jump (a whitecap touched)
DELIBERATE_JUMP_S = 1.0    # a flight longer than this is a deliberate jump; shorter =
                           # unavoidable airtime off chop
FLAT_RIG_LEAN = 55.0       # rig lean (deg from upright) above this = laid flat
TURN_DEG = 100.0           # the travel direction turns at least this much ...
TURN_WINDOW_S = 2.5        # ... within this time = a gybe (or a tack)
WATER_FLAT, WATER_ROUGH = 0.002, 0.025  # whitecap share of the sea: below = flat, above = rough
NEAR_SEA_FROM = 0.4        # the water state is measured on the nearest 60 % of the sea's rows


def frame_size(info):
    scale = LONG_SIDE / max(info["width"], info["height"])
    return int(round(info["width"] * scale / 2) * 2), int(round(info["height"] * scale / 2) * 2)


def read_frames(path, w, h):
    """All frames as small BGR pictures, one at a time (the video never sits in memory)."""
    proc = subprocess.Popen(
        [ffmpeg("ffmpeg"), "-v", "error", "-i", path, "-vf", "scale=%d:%d" % (w, h),
         "-f", "rawvideo", "-pix_fmt", "bgr24", "-"], stdout=subprocess.PIPE)
    size = w * h * 3
    while True:
        buf = proc.stdout.read(size)
        if len(buf) < size:
            break
        yield np.frombuffer(buf, np.uint8).reshape(h, w, 3)
    proc.wait()


def horizon_row(hue, sat, val):
    """The row of the horizon when the sky is in view, else 0. Just below the horizon the
    sea is much more saturated (and darker) than the sky just above it."""
    h = sat.shape[0]
    row_s = np.median(sat, axis=1).astype(np.float32)
    row_v = np.median(val, axis=1).astype(np.float32)
    row_h = np.median(hue, axis=1).astype(np.float32)
    best_y, best_jump = 0, 0.0
    for y in range(8, int(0.6 * h)):
        above_s, above_v = row_s[y - 8:y].mean(), row_v[y - 8:y].mean()
        above_turquoise = TURQUOISE_HUE[0] <= np.median(row_h[y - 8:y]) <= TURQUOISE_HUE[1]
        jump = row_s[y:y + 8].mean() - above_s
        darker = above_v - row_v[y:y + 8].mean()
        # only a real horizon: pale sky or sand above (not light turquoise water), sea below
        if jump > best_jump and darker > 0 and above_s < SKY_S_MAX and above_v > SKY_V_MIN \
                and not above_turquoise:
            best_y, best_jump = y, jump
    return best_y if best_jump >= HORIZON_S_JUMP else 0


def classify(bgr):
    """Masks for water, white (foam/spray), and rig-coloured pixels; nothing above the
    horizon counts (the sky is as blue as water and its clouds as white as foam)."""
    hsv = cv2.cvtColor(bgr, cv2.COLOR_BGR2HSV)
    hue, sat, val = hsv[..., 0], hsv[..., 1], hsv[..., 2]
    below = np.zeros(sat.shape, bool)
    below[horizon_row(hue, sat, val):] = True
    warm = (hue <= 25) | (hue >= 160)  # sand and skin are warm; foam is not
    water_hue = (hue >= WATER_HUE[0]) & (hue <= WATER_HUE[1])
    vivid_blue = water_hue & (sat >= VIVID_BLUE_S) & (val >= VIVID_BLUE_V)
    plain_water = water_hue & (sat >= WATER_S_MIN) & (val >= WATER_V_MIN) & ~vivid_blue & below
    # Foam and spray: pale, and clearly brighter than the water around it (far spray over
    # deep blue water is greyish, so a fixed brightness alone misses it).
    background = water_brightness(val, plain_water & (sat > WHITE_S_MAX))
    brighter = val.astype(np.float32) - background >= WHITE_ABOVE_WATER
    white = (sat <= WHITE_S_MAX) & ((val >= WHITE_V_MIN) | brighter) \
        & ~(warm & (sat > 25)) & below
    water = plain_water & ~white
    vivid_other = (sat >= VIVID_S_MIN) & ~water_hue
    rig = ((val <= DARK_V_MAX) | vivid_other | vivid_blue) & below
    return water, white, rig


def water_brightness(val, water):
    """The brightness of the water around each pixel (blurred over water pixels only)."""
    sigma = 0.05 * max(val.shape)
    w = cv2.GaussianBlur(water.astype(np.float32), (0, 0), sigma)
    v = cv2.GaussianBlur(val.astype(np.float32) * water, (0, 0), sigma)
    return np.where(w > 0.02, v / np.maximum(w, 1e-6), 255.0)


def sea_area(water):
    """The main body of water as its outline (convex hull): the rig, the foam and the spray
    on it count as sea, also spray clouds that reach the edge of the picture."""
    m = cv2.morphologyEx(water.astype(np.uint8), cv2.MORPH_CLOSE, np.ones((9, 9), np.uint8))
    n, labels, stats, _ = cv2.connectedComponentsWithStats(m, connectivity=8)
    if n < 2:
        return np.zeros_like(water)
    biggest = 1 + int(np.argmax(stats[1:, cv2.CC_STAT_AREA]))
    ys, xs = np.nonzero(labels == biggest)
    hull = np.zeros(water.shape, np.uint8)
    cv2.fillConvexPoly(hull, cv2.convexHull(np.column_stack([xs, ys]).astype(np.int32)), 1)
    return hull.astype(bool)


def find_rig(rig_mask, sea, prev):
    """The rig: the biggest rig-coloured blob on the sea, preferring the one near the last."""
    h, w = rig_mask.shape
    m = cv2.morphologyEx((rig_mask & sea).astype(np.uint8), cv2.MORPH_CLOSE,
                         np.ones((9, 9), np.uint8))
    n, labels, stats, cents = cv2.connectedComponentsWithStats(m, connectivity=8)
    best, best_score = None, 0.0
    for i in range(1, n):
        area = stats[i, cv2.CC_STAT_AREA]
        if area < 0.0006 * w * h:
            continue
        score = float(area)
        if prev is not None:
            dist = math.hypot(cents[i][0] - prev["cx"], cents[i][1] - prev["cy"])
            score /= 1.0 + dist / max(prev["size"], 1.0)
        if score > best_score:
            best, best_score = i, score
    if best is None:
        return None
    x, y, bw, bh = (int(v) for v in stats[best, :4])
    mask = labels == best
    ys, xs = np.nonzero(mask)
    # The rig's outline (convex hull): the white sail windows inside it are not spray.
    hull = np.zeros(mask.shape, np.uint8)
    cv2.fillConvexPoly(hull, cv2.convexHull(np.column_stack([xs, ys]).astype(np.int32)), 1)
    return {"cx": float(cents[best][0]), "cy": float(cents[best][1]),
            "x0": x, "y0": y, "x1": x + bw, "y1": y + bh,
            "size": float(max(bw, bh)), "area": int(stats[best, cv2.CC_STAT_AREA]),
            "lean": rig_lean_deg(xs, ys), "mask": hull.astype(bool)}


def rig_lean_deg(xs, ys):
    """Angle of the blob's long axis from upright: 0 = upright, +90/-90 = flat.
    Positive = the top leans to the right of the picture."""
    if len(xs) < 5:
        return 0.0
    dx, dy = xs - xs.mean(), ys - ys.mean()
    mu20, mu02, mu11 = (dx * dx).mean(), (dy * dy).mean(), (dx * dy).mean()
    theta = 0.5 * math.atan2(2 * mu11, mu20 - mu02)  # long axis, from the x axis, y down
    # With y up the axis sits at -theta from the x axis; upright = 90, so lean = 90 - (-theta).
    lean = 90.0 + math.degrees(theta)
    return ((lean + 90.0) % 180.0) - 90.0


def box_share(mask, x0, y0, x1, y1):
    h, w = mask.shape
    x0, x1 = max(0, int(x0)), min(w, int(x1))
    y0, y1 = max(0, int(y0)), min(h, int(y1))
    if x1 <= x0 or y1 <= y0:
        return 0.0
    return float(mask[y0:y1, x0:x1].mean())


def lower_ring(r, width_px=9):
    """A thin ring round the rig's lower half: where the board and the sailor's feet are."""
    m = r["mask"].astype(np.uint8)
    k = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (width_px, width_px))
    ring = cv2.dilate(m, k).astype(bool) & ~m.astype(bool)
    ring[:int(r["cy"])] = False
    return ring


def spray_under_rig(white, r):
    """Spray touching the rig's lower half. Planing throws spray off the tail all the time;
    in the air there is none (the take-off spray stays behind)."""
    ring = lower_ring(r)
    n = int(ring.sum())
    return float((white & ring).sum()) / n if n else 0.0


def attached_white(white, sea, r):
    """The white blobs that touch the rig's lower half: its wake and spray, nothing else."""
    n, labels = cv2.connectedComponents((white & sea).astype(np.uint8), connectivity=8)
    touching = np.unique(labels[lower_ring(r, 13) & white])
    touching = touching[touching > 0]
    return np.isin(labels, touching) if len(touching) else np.zeros_like(white)


def spray_around_rig(white, r):
    s = r["size"]
    return box_share(white, r["cx"] - 1.5 * s, r["cy"] - 1.5 * s, r["cx"] + 1.5 * s, r["cy"] + 1.5 * s)


def wake_size(white, sea, r):
    """The attached wake's area as a multiple of the rig's area (0 in the air)."""
    wake = attached_white(white, sea, r) & ~r["mask"]
    return float(wake.sum()) / max(int(r["mask"].sum()), 1)


def wake_direction(white, sea, r):
    """Direction the board travels, in the image (deg, 0 = right, 90 = up): from the middle
    of the attached wake towards where it touches the rig (the wake lies behind the board).
    None when there is no wake (in the air) or it is too small to point anywhere."""
    wake = attached_white(white, sea, r) & ~r["mask"]
    ys, xs = np.nonzero(wake)
    contact = np.nonzero(wake & lower_ring(r, 13))
    if len(xs) < 30 or len(contact[0]) < 3:
        return None
    fx, fy = contact[1].mean() - xs.mean(), contact[0].mean() - ys.mean()  # wake -> board
    if math.hypot(fx, fy) < 0.1 * r["size"]:
        return None
    return math.degrees(math.atan2(-fy, fx))  # y is down in the picture


def sea_state(gray, water, white, sea, r):
    """Whitecap share of the sea (small white blobs only: the wake and spray are big ones)
    and the roughness of the water's texture."""
    h, w = gray.shape
    keep = sea.copy()
    if r is not None:
        s = r["size"]
        keep[int(max(0, r["cy"] - 2 * s)):int(min(h, r["cy"] + 2.5 * s)),
             int(max(0, r["cx"] - 2.5 * s)):int(min(w, r["cx"] + 2.5 * s))] = False
    rows_with_sea = np.nonzero(sea.any(axis=1))[0]
    if len(rows_with_sea):
        # the far sea is squeezed by the slant view and its whitecaps are too small to see
        near_from = rows_with_sea[0] + int(NEAR_SEA_FROM * (rows_with_sea[-1] - rows_with_sea[0]))
        keep[:near_from] = False
    sea_px = int(keep.sum())
    if sea_px < 0.05 * w * h:
        return None, None
    n, labels, stats, _ = cv2.connectedComponentsWithStats((white & keep).astype(np.uint8), 8)
    small = stats[1:, cv2.CC_STAT_AREA]
    caps = small[small <= WHITECAP_MAX_BLOB * w * h].sum()
    detail = gray.astype(np.float32) - cv2.GaussianBlur(gray, (0, 0), 3).astype(np.float32)
    water_keep = water & keep
    rough = float(np.abs(detail[water_keep]).mean() / max(gray[water_keep].mean(), 1.0)) \
        if water_keep.any() else None
    return float(caps) / sea_px, rough


def measure(name):
    path = original(name)
    info = probe(path)
    w, h = frame_size(info)
    rows, prev_gray, prev_rig, recent = [], None, None, []
    for i, bgr in enumerate(read_frames(path, w, h)):
        gray = cv2.cvtColor(bgr, cv2.COLOR_BGR2GRAY)
        diff = 0.0 if prev_gray is None else float(np.abs(gray.astype(np.int16) - prev_gray).mean())
        usual = float(np.median(recent)) if recent else 0.0
        cut = diff > CUT_DIFF and diff > CUT_RATIO * usual
        recent = (recent + [diff])[-int(info["fps"]):]  # the last second's changes
        water, white, rig_mask = classify(bgr)
        sea = sea_area(water)
        if cut:
            prev_rig = None  # a new shot: look for the rig from scratch
        r = find_rig(rig_mask, sea, prev_rig)
        caps, rough = sea_state(gray, water, white, sea, r)
        rows.append({
            "frame": i, "t": i / info["fps"], "diff": diff, "cut": cut,
            "sea_share": float(sea.mean()),
            "rig": r is not None,
            "rig_cx": r["cx"] / w if r else None, "rig_cy": r["cy"] / h if r else None,
            "rig_size": r["size"] / h if r else None, "rig_lean": r["lean"] if r else None,
            "spray_under": spray_under_rig(white, r) if r else None,
            "spray_around": spray_around_rig(white, r) if r else None,
            "wake_rel": wake_size(white, sea, r) if r else None,
            "travel_deg": wake_direction(white, sea, r) if r else None,
            "whitecaps": caps, "roughness": rough,
        })
        prev_gray = gray.astype(np.int16)
        prev_rig = r
    return info, rows


# --- From frames to shots and segments ----------------------------------------------------

def shots_from(rows, fps):
    cuts = [0] + [r["frame"] for r in rows if r["cut"]] + [len(rows)]
    shots = []
    for a, b in zip(cuts[:-1], cuts[1:]):
        if b - a >= 0.5 * fps:  # ignore flashes shorter than half a second
            shots.append((a, b))
    return shots


def real_frames(rows):
    """Frames that are not copies of the one before (the editor's padding)."""
    return [r for r in rows if r["frame"] == 0 or r["diff"] > COPY_DIFF]


def angle_diff(a, b):
    return (a - b + 180.0) % 360.0 - 180.0


def find_jumps(rows, a, b, fps):
    """Jumps in one shot: the wake attached to the rig drops below AIR_WAKE_SHARE of its usual
    size in this shot (the board has left its spray behind) for at least AIR_MIN_S.
    The usual size = the median over the frames where the rig is upright (the wake's size
    depends on the camera's distance, so a fixed number would not work)."""
    real = [r for r in real_frames(rows[a:b]) if r.get("wake_rel") is not None]
    upright = [r["wake_rel"] for r in real if r["rig_lean"] is not None
               and abs(r["rig_lean"]) < FLAT_RIG_LEAN]
    if len(upright) < 5:
        return []
    limit = AIR_WAKE_SHARE * float(np.median(upright))
    jumps, start = [], None
    for r in real + [{"frame": b, "wake_rel": None}]:
        dry = r["wake_rel"] is not None and r["wake_rel"] < limit
        if dry and start is None:
            start = r["frame"]
        elif not dry and start is not None:
            if (r["frame"] - start) / fps >= AIR_MIN_S:
                jumps.append((start, r["frame"]))
            start = None
    # One flight can show a short gap when a whitecap touches the rig: join the pieces.
    merged = []
    for s, e in jumps:
        if merged and (s - merged[-1][1]) / fps < AIR_JOIN_S:
            merged[-1] = (merged[-1][0], e)
        else:
            merged.append((s, e))
    return merged


def find_turns(rows, a, b, fps):
    """Where the travel direction turns by TURN_DEG within TURN_WINDOW_S: a gybe or tack."""
    pts = [(r["frame"], r["travel_deg"]) for r in rows[a:b] if r["travel_deg"] is not None]
    if len(pts) < 5:
        return []
    # unwrap the angles so a turn through 180 does not jump
    frames = np.array([p[0] for p in pts])
    ang = np.degrees(np.unwrap(np.radians([p[1] for p in pts])))
    ang = np.convolve(ang, np.ones(5) / 5, mode="same")  # smooth over 5 samples
    win = int(TURN_WINDOW_S * fps)
    turns, i = [], 2
    while i < len(frames) - 2:
        j = np.searchsorted(frames, frames[i] + win)
        seg = ang[i:min(j, len(ang) - 2)]
        if len(seg) > 2 and abs(seg[-1] - seg[0]) >= TURN_DEG:
            k = i + len(seg) - 1
            turns.append((int(frames[i]), int(frames[k]), float(seg[-1] - seg[0])))
            i = k + 1
        else:
            i += 1
    return turns


def median_of(rows, key):
    vals = [r[key] for r in rows if r.get(key) is not None]
    return float(np.median(vals)) if vals else None


def water_label(caps):
    if caps is None:
        return "unknown"
    if caps < WATER_FLAT:
        return "flat"
    return "chop" if caps < WATER_ROUGH else "rough"


def camera_label(size):
    if size is None:
        return "no rig"
    return "close" if size > 0.35 else ("medium" if size > 0.15 else "wide")


def segments(info, rows):
    fps = info["fps"]
    shots = shots_from(rows, fps)
    out = []
    for n, (a, b) in enumerate(shots):
        jumps = find_jumps(rows, a, b, fps)
        for s, e in jumps:  # in the air there is no wake to point the way
            for r in rows[s:e]:
                r["travel_deg"] = None
        events = [("jump", s, e) for s, e in jumps]
        events += [("gybe", s, e) for s, e, _ in find_turns(rows, a, b, fps)
                   if not any(s < je and e > js for _, js, je in events)]
        events.sort(key=lambda ev: ev[1])
        cursor, pieces = a, []
        for kind, s, e in events:
            if s > cursor:
                pieces.append(("straight", cursor, s))
            pieces.append((kind, s, min(e, b)))
            cursor = min(e, b)
        if cursor < b:
            pieces.append(("straight", cursor, b))
        for kind, s, e in pieces:
            if (e - s) < 0.3 * fps and kind == "straight":
                continue  # slivers between events
            part = rows[s:e]
            travel = circular_median([r["travel_deg"] for r in part if r["travel_deg"] is not None])
            lean = median_of(part, "rig_lean")
            if kind == "jump":
                kind = jump_kind(part, (e - s) / fps)
            out.append({
                "shot": "ABCDEFGHIJKLMNOPQRSTUVWXYZ"[n] if n < 26 else str(n),
                "t0": round(s / fps, 2), "t1": round(e / fps, 2), "manoeuvre": kind,
                "water": water_label(median_of(part, "whitecaps"))
                if camera_label(median_of(part, "rig_size")) != "close" else "unknown",
                "whitecaps_pct": pct(median_of(part, "whitecaps")),
                "roughness": rnd(median_of(part, "roughness"), 3),
                "camera": camera_label(median_of(part, "rig_size")),
                "rig_seen_pct": round(100.0 * sum(r["rig"] for r in part) / max(len(part), 1)),
                "rig_lean_deg": rnd(lean, 0),
                "rig_flat_pct": round(100.0 * sum(1 for r in part if r["rig_lean"] is not None
                                                  and abs(r["rig_lean"]) > FLAT_RIG_LEAN)
                                      / max(len(part), 1)),
                "travel_deg": rnd(travel, 0),
            })
    return shots, out


def jump_kind(part, seconds):
    """A deliberate jump (a long flight) or unavoidable airtime: the board launched off chop
    while the sailor keeps sailing (short). Max, 25 Nov 2026: deliberate jumps are for later;
    unavoidable airtime matters now. Decided by the flight's length only: seen from the side,
    a raked race sail looks "laid flat" (videos 04 and 06), so the rig's angle cannot decide.
    In a close-up the wake is out of the picture, so no flight can be seen at all."""
    if camera_label(median_of(part, "rig_size")) == "close":
        return "unknown (close-up)"
    return "jump" if seconds > DELIBERATE_JUMP_S else "airtime"


def circular_median(angles):
    if not angles:
        return None
    rad = np.radians(angles)
    return float(np.degrees(math.atan2(np.median(np.sin(rad)), np.median(np.cos(rad)))))


def pct(v):
    return None if v is None else round(100.0 * v, 2)


def rnd(v, d):
    return None if v is None else round(v, d)


# --- Outputs -------------------------------------------------------------------------------

def write_csv(path, rows):
    with open(path, "w", newline="", encoding="utf-8") as f:
        wr = csv.DictWriter(f, fieldnames=list(rows[0].keys()))
        wr.writeheader()
        for r in rows:
            wr.writerow({k: ("" if v is None else (round(v, 5) if isinstance(v, float) else v))
                         for k, v in r.items()})


KIND_COLOUR = {"straight": (90, 90, 90), "gybe": (230, 160, 40), "jump": (60, 170, 230),
               "airtime": (150, 90, 210), "unknown (close-up)": (200, 200, 200)}


def draw_timeline(path, info, rows, segs):
    """The measurements over time, one strip each, with the segments as coloured bands."""
    strips = [("spray under rig", "spray_under", 0.0, 0.6),
              ("wake / rig area", "wake_rel", 0.0, 3.0),
              ("spray around rig", "spray_around", 0.0, 0.5),
              ("rig lean (deg)", "rig_lean", -90.0, 90.0),
              ("travel dir (deg)", "travel_deg", -180.0, 180.0),
              ("whitecaps (share)", "whitecaps", 0.0, 0.04),
              ("roughness", "roughness", 0.0, 0.15),
              ("rig size", "rig_size", 0.0, 0.8)]
    W, left, sh, gap = 1600, 170, 90, 14
    H = 60 + len(strips) * (sh + gap) + 30
    img = Image.new("RGB", (W, H), (250, 250, 250))
    d = ImageDraw.Draw(img)
    try:
        font = ImageFont.truetype("C:/Windows/Fonts/consola.ttf", 14)
    except OSError:
        font = ImageFont.load_default()
    dur = rows[-1]["t"] + 1.0 / info["fps"]
    X = lambda t: left + (W - left - 20) * t / dur
    d.text((10, 10), "Segments: grey straight, orange gybe, blue jump, purple airtime; black lines = cuts",
           fill=(0, 0, 0), font=font)
    for s in segs:
        d.rectangle([X(s["t0"]), 34, X(s["t1"]), 50], fill=KIND_COLOUR[s["manoeuvre"]])
        d.text((X(s["t0"]) + 2, 34), s["shot"], fill=(255, 255, 255), font=font)
    for k, (label, key, lo, hi) in enumerate(strips):
        y0 = 60 + k * (sh + gap)
        d.rectangle([left, y0, W - 20, y0 + sh], outline=(180, 180, 180))
        d.text((10, y0 + sh / 2 - 7), label, fill=(0, 0, 0), font=font)
        if lo < 0 < hi:
            yz = y0 + sh * (hi / (hi - lo))
            d.line([left, yz, W - 20, yz], fill=(210, 210, 210))
        last = None
        for r in rows:
            v = r.get(key)
            if v is None or r["cut"]:
                last = None
                continue
            p = (X(r["t"]), y0 + sh * (1 - (min(max(v, lo), hi) - lo) / (hi - lo)))
            if last is not None and abs(p[0] - last[0]) < 10:
                d.line([last, p], fill=(30, 90, 200), width=2)
            last = p
    for r in rows:
        if r["cut"]:
            d.line([X(r["t"]), 30, X(r["t"]), H - 20], fill=(0, 0, 0))
    for t in range(int(dur) + 1):
        d.text((X(t) - 4, H - 20), str(t), fill=(0, 0, 0), font=font)
    img.save(path)


def make_grids(name, segs):
    """One standard grid per segment: about 24 frames, so every segment reads the same way."""
    tool = os.path.join(os.path.dirname(__file__), "video.py")
    for s in segs:
        length = max(s["t1"] - s["t0"], 0.1)
        fps = min(25.0, max(2.0, 24.0 / length))
        subprocess.run([sys.executable, tool, "grid", name, "--start", "%.2f" % s["t0"],
                        "--end", "%.2f" % s["t1"], "--fps", "%g" % round(fps, 1),
                        "--cols", "8", "--thumb", "240"], check=True,
                       stdout=subprocess.DEVNULL)


def debug_frames(name, times):
    """Pictures of what the detectors see at the given times: water tinted blue, white
    tinted red, rig pixels green, the rig's box, the spray-under band and the travel arrow."""
    path = original(name)
    info = probe(path)
    w, h = frame_size(info)
    want = {int(round(t * info["fps"])) for t in times}
    out_dir = os.path.join(video_dir(name), "analysis", "debug")
    os.makedirs(out_dir, exist_ok=True)
    prev = None
    for i, bgr in enumerate(read_frames(path, w, h)):
        water, white, rig_mask = classify(bgr)
        sea = sea_area(water)
        r = find_rig(rig_mask, sea, prev)
        prev = r
        if i not in want:
            continue
        view = bgr.copy()
        view[water] = (0.5 * view[water] + [120, 40, 0]).astype(np.uint8)
        view[white & sea] = (0.4 * view[white & sea] + [0, 0, 150]).astype(np.uint8)
        view[rig_mask & sea] = (0.4 * view[rig_mask & sea] + [0, 150, 0]).astype(np.uint8)
        if r:
            cv2.rectangle(view, (r["x0"], r["y0"]), (r["x1"], r["y1"]), (0, 255, 255), 1)
            wake = attached_white(white, sea, r)
            view[wake] = (0.3 * view[wake] + [180, 0, 180]).astype(np.uint8)  # wake: magenta
            view[lower_ring(r)] = (0, 255, 255)                              # contact ring
            tdeg = wake_direction(white, sea, r)
            if tdeg is not None:
                bx, by = (r["x0"] + r["x1"]) // 2, r["y1"]
                ex = int(bx + 40 * math.cos(math.radians(tdeg)))
                ey = int(by - 40 * math.sin(math.radians(tdeg)))
                cv2.arrowedLine(view, (bx, by), (ex, ey), (0, 255, 255), 2)
            cv2.putText(view, "lean %.0f under %.2f" % (r["lean"], spray_under_rig(white, r)),
                        (4, h - 8), cv2.FONT_HERSHEY_SIMPLEX, 0.4, (255, 255, 255), 1)
        cv2.putText(view, "t=%.2f" % (i / info["fps"]), (4, 14), cv2.FONT_HERSHEY_SIMPLEX, 0.45,
                    (255, 255, 255), 1)
        cv2.imwrite(os.path.join(out_dir, "t%06.2f.png" % (i / info["fps"])), view)
    print(out_dir)


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("name")
    ap.add_argument("--no-grids", action="store_true")
    ap.add_argument("--debug", help="comma-separated times (s): save what the detectors see")
    a = ap.parse_args()
    if a.debug:
        debug_frames(a.name, [float(t) for t in a.debug.split(",")])
        return
    info, rows = measure(a.name)
    shots, segs = segments(info, rows)
    out_dir = os.path.join(video_dir(a.name), "analysis")
    os.makedirs(out_dir, exist_ok=True)
    write_csv(os.path.join(out_dir, "frames.csv"), rows)
    copies = sum(1 for r in rows[1:] if r["diff"] <= COPY_DIFF)
    result = {"video": a.name, "info": info, "copied_frames": copies,
              "real_fps": round(info["fps"] * (1 - copies / max(len(rows) - 1, 1)), 1),
              "shots": [{"t0": round(s / info["fps"], 2), "t1": round(e / info["fps"], 2)}
                        for s, e in shots],
              "segments": segs}
    with open(os.path.join(out_dir, "segments.json"), "w", encoding="utf-8") as f:
        json.dump(result, f, indent=1)
    draw_timeline(os.path.join(out_dir, "timeline.png"), info, rows, segs)
    if not a.no_grids:
        make_grids(a.name, segs)
    print("real fps %.1f (%d copied frames of %d)" % (result["real_fps"], copies, len(rows)))
    keys = ["shot", "t0", "t1", "manoeuvre", "water", "whitecaps_pct", "roughness", "camera",
            "rig_seen_pct", "rig_lean_deg", "rig_flat_pct", "travel_deg"]
    print("  ".join(keys))
    for s in segs:
        print("  ".join(str(s[k]) for k in keys))


if __name__ == "__main__":
    main()
