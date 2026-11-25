"""Front view of a sailor (camera ahead of the board, level): the rig's sideways lean and the
board's tilt, measured in every frame.

  python tools/video/front_view.py <name> --start S --end S [--board-until S] [--debug t1,t2]

Made for video 07 (a drone hovering in front of the board), so its colour choices fit that
sail: the lower luff sleeve is saturated orange, the board's underside is dark with a light rim.
  - Rig lean: a straight line fitted through the orange luff sleeve (the mast runs inside it).
    Degrees from upright; positive = the top leans to the left of the picture.
  - Board tilt: an ellipse fitted to the board's dark underside (the legs are cut off by an
    opening with a big round brush: they are thinner than the board). Degrees of the long axis
    from level; positive = the right end lower. Also the ellipse's short/long ratio: the more of
    the underside shows, the higher the nose (a relative number, not degrees).
The camera must be level (check the shoreline or horizon on the frames). Results go to
<video>/measure/front_view.csv; --debug saves pictures with the fitted line and ellipse drawn.
"""

import argparse
import csv
import math
import os
import subprocess
import sys

import cv2
import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
from video import ffmpeg, original, probe, video_dir  # noqa: E402

ORANGE_S, ORANGE_V = 170, 150          # the sleeve; skin in sunlight is less saturated
BOARD_BOX = (600, 1240, 1080, 1560)    # x0, y0, x1, y1 where the board shows in 0-8.5 s
BOARD_DARK_V = 85                      # the underside is darker than the water and the spray
OPEN_PX = 41                           # the round brush that cuts off the legs


def frames(path, start, end, w, h):
    proc = subprocess.Popen([ffmpeg("ffmpeg"), "-v", "error", "-ss", "%.3f" % start,
                             "-to", "%.3f" % end, "-i", path, "-f", "rawvideo",
                             "-pix_fmt", "bgr24", "-"], stdout=subprocess.PIPE)
    while True:
        buf = proc.stdout.read(w * h * 3)
        if len(buf) < w * h * 3:
            break
        yield np.frombuffer(buf, np.uint8).reshape(h, w, 3)
    proc.wait()


def rig_lean(hsv):
    """Line through the biggest orange blob below the boom; None if it is too small."""
    hue, sat, val = hsv[..., 0], hsv[..., 1], hsv[..., 2]
    orange = ((hue <= 22) | (hue >= 170)) & (sat >= ORANGE_S) & (val >= ORANGE_V)
    orange[:650] = False  # only below the boom's height: the lower mast
    n, labels, stats, _ = cv2.connectedComponentsWithStats(orange.astype(np.uint8), 8)
    if n < 2:
        return None
    big = 1 + int(np.argmax(stats[1:, cv2.CC_STAT_AREA]))
    if stats[big, cv2.CC_STAT_AREA] < 3000 or stats[big, cv2.CC_STAT_HEIGHT] < 250:
        return None
    ys, xs = np.nonzero(labels == big)
    vx, vy, x0, y0 = cv2.fitLine(np.column_stack([xs, ys]).astype(np.float32),
                                 cv2.DIST_HUBER, 0, 0.01, 0.01).ravel()
    if vy > 0:  # make the direction point up the picture
        vx, vy = -vx, -vy
    lean = math.degrees(math.atan2(-vx, -vy))  # top to the left = positive
    return lean, (float(x0), float(y0), float(vx), float(vy))


def board_tilt(bgr):
    """Ellipse fitted to the dark underside inside BOARD_BOX; None if no board-sized blob."""
    x0, y0, x1, y1 = BOARD_BOX
    roi = cv2.cvtColor(bgr[y0:y1, x0:x1], cv2.COLOR_BGR2HSV)
    dark = (roi[..., 2] <= BOARD_DARK_V).astype(np.uint8)
    brush = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (OPEN_PX, OPEN_PX))
    dark = cv2.morphologyEx(dark, cv2.MORPH_OPEN, brush)
    n, labels, stats, _ = cv2.connectedComponentsWithStats(dark, 8)
    if n < 2:
        return None
    big = 1 + int(np.argmax(stats[1:, cv2.CC_STAT_AREA]))
    if stats[big, cv2.CC_STAT_AREA] < 12000:
        return None
    if stats[big, cv2.CC_STAT_LEFT] == 0 or stats[big, cv2.CC_STAT_LEFT] + \
            stats[big, cv2.CC_STAT_WIDTH] >= x1 - x0 or stats[big, cv2.CC_STAT_TOP] + \
            stats[big, cv2.CC_STAT_HEIGHT] >= y1 - y0:
        return None  # cut by the box's edge: the outline is not whole
    contours, _ = cv2.findContours((labels == big).astype(np.uint8), cv2.RETR_EXTERNAL,
                                   cv2.CHAIN_APPROX_NONE)
    (cx, cy), (a, b), ang = cv2.fitEllipse(max(contours, key=len))
    # OpenCV's angle belongs to the first axis; turn it into the long axis' angle from level
    long_ang = ang if a >= b else ang + 90.0
    tilt = ((long_ang + 90.0) % 180.0) - 90.0  # y is down, so positive = right end lower
    return tilt, min(a, b) / max(a, b), (cx + x0, cy + y0, a, b, ang)


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("name")
    ap.add_argument("--start", type=float, default=0.0)
    ap.add_argument("--end", type=float, required=True)
    ap.add_argument("--board-until", type=float, default=8.5)
    ap.add_argument("--debug", default="")
    a = ap.parse_args()
    path = original(a.name)
    info = probe(path)
    W, H = info["width"], info["height"]
    out_dir = os.path.join(video_dir(a.name), "measure")
    os.makedirs(out_dir, exist_ok=True)
    want = {round(float(t) * info["fps"]) for t in a.debug.split(",") if t}
    first = int(math.ceil(a.start * info["fps"] - 1e-6))
    rows = []
    for k, bgr in enumerate(frames(path, a.start, a.end, W, H)):
        f = first + k
        t = f / info["fps"]
        hsv = cv2.cvtColor(bgr, cv2.COLOR_BGR2HSV)
        lean = rig_lean(hsv)
        board = board_tilt(bgr) if t <= a.board_until else None
        rows.append({"t": round(t, 3), "rig_lean_deg": round(lean[0], 2) if lean else "",
                     "board_tilt_deg": round(board[0], 2) if board else "",
                     "board_ratio": round(board[1], 3) if board else ""})
        if f in want:
            view = bgr.copy()
            if lean:
                x0, y0, vx, vy = lean[1]
                cv2.line(view, (int(x0 - 600 * vx), int(y0 - 600 * vy)),
                         (int(x0 + 600 * vx), int(y0 + 600 * vy)), (0, 255, 0), 3)
            if board:
                cx, cy, ea, eb, eang = board[2]
                cv2.ellipse(view, ((cx, cy), (ea, eb), eang), (255, 0, 255), 3)
            cv2.rectangle(view, BOARD_BOX[:2], BOARD_BOX[2:], (0, 255, 255), 2)
            cv2.putText(view, "t=%.2f lean %s tilt %s" % (t, rows[-1]["rig_lean_deg"],
                        rows[-1]["board_tilt_deg"]), (20, 60), cv2.FONT_HERSHEY_SIMPLEX, 1.4,
                        (255, 255, 255), 3)
            cv2.imwrite(os.path.join(out_dir, "front_debug_%05.2f.png" % t),
                        cv2.resize(view, (W // 2, H // 2)))
    with open(os.path.join(out_dir, "front_view.csv"), "w", newline="", encoding="utf-8") as fh:
        wr = csv.DictWriter(fh, fieldnames=list(rows[0].keys()))
        wr.writeheader()
        wr.writerows(rows)
    for key in ("rig_lean_deg", "board_tilt_deg", "board_ratio"):
        vals = np.array([r[key] for r in rows if r[key] != ""], float)
        if len(vals):
            print("%-15s n=%3d  median %6.2f  middle half %6.2f to %6.2f  range %6.2f to %6.2f" % (
                key, len(vals), np.median(vals), np.percentile(vals, 25), np.percentile(vals, 75),
                vals.min(), vals.max()))
    print("per second (median): t, rig lean, board tilt, board ratio")
    for s in range(int(a.start), int(math.ceil(a.end))):
        part = [r for r in rows if s <= r["t"] < s + 1]
        def med(key):
            v = [r[key] for r in part if r[key] != ""]
            return "%6.1f" % np.median(v) if v else "     -"
        print("  %2d s  %s  %s  %s" % (s, med("rig_lean_deg"), med("board_tilt_deg"),
                                       med("board_ratio")))


if __name__ == "__main__":
    main()
