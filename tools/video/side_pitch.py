"""The board's pitch over time from a side view, against a level line behind it (video 04).

  python tools/video/side_pitch.py <name> --start S --end S [--debug t1,t2]

Per frame:
  - the board: the long purple shape low in the picture (the board's colour in videos 04 and
    06; the sail's pink panels are higher up and not long and flat); a straight line through
    its pixels gives the board's angle in the picture;
  - the level: the beach's sand strip behind (pale, warm), a straight line through its pixels;
  - pitch = the board's angle minus the beach's angle, so the camera's roll on the boat drops
    out (both tilt together). Positive = nose up (the board sails to the right in 04).
The absolute number includes the board's rocker and the purple shape's own outline, so only
the changes over time are a clean measure: the spread after taking out changes slower than
1 s, and the main rhythm. Results to <video>/measure/side_pitch.csv; --debug saves overlays.
"""

import argparse
import csv
import math
import os
import sys

import cv2
import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
from front_view import frames  # noqa: E402
from video import original, probe, video_dir  # noqa: E402

PURPLE_HUE = (125, 160)      # the board (OpenCV hue); the sail's pink sits above 160
SAND = dict(hue=(5, 28), s=(35, 130), v_min=140)


def line_angle(xs, ys):
    """Angle (deg) of the best straight line through the points; positive = right end higher."""
    pts = np.column_stack([xs, ys]).astype(np.float32)
    vx, vy, x0, y0 = cv2.fitLine(pts, cv2.DIST_HUBER, 0, 0.01, 0.01).ravel()
    if vx < 0:
        vx, vy = -vx, -vy
    return math.degrees(math.atan2(-vy, vx)), (float(x0), float(y0), float(vx), float(vy))


def find_board(hsv):
    hue, sat, val = hsv[..., 0], hsv[..., 1], hsv[..., 2]
    mask = ((hue >= PURPLE_HUE[0]) & (hue <= PURPLE_HUE[1]) & (sat >= 70) & (val >= 50)).astype(np.uint8)
    mask = cv2.morphologyEx(mask, cv2.MORPH_CLOSE, np.ones((5, 5), np.uint8))
    n, labels, stats, cents = cv2.connectedComponentsWithStats(mask, 8)
    best, best_score = None, 0.0
    for i in range(1, n):
        w, h, area = stats[i, cv2.CC_STAT_WIDTH], stats[i, cv2.CC_STAT_HEIGHT], stats[i, cv2.CC_STAT_AREA]
        if area < 1500 or w < 3 * h or w < 250:
            continue  # the board is long and flat in a side view
        score = area * (1.0 + cents[i][1] / hsv.shape[0])  # big and low in the picture
        if score > best_score:
            best, best_score = i, score
    if best is None:
        return None
    ys, xs = np.nonzero(labels == best)
    ang, line = line_angle(xs, ys)
    return ang, line, int(stats[best, cv2.CC_STAT_WIDTH])


def find_beach(hsv, below_y):
    """The sand strip above the board: angle of the line through its pixels, or None."""
    hue, sat, val = hsv[..., 0], hsv[..., 1], hsv[..., 2]
    sand = (hue >= SAND["hue"][0]) & (hue <= SAND["hue"][1]) & (sat >= SAND["s"][0]) & \
        (sat <= SAND["s"][1]) & (val >= SAND["v_min"])
    sand[int(below_y):] = False
    ys, xs = np.nonzero(sand)
    if len(xs) < 3000 or xs.max() - xs.min() < 400:
        return None
    return line_angle(xs, ys)


def detrend(v, n):
    pad = np.pad(v, (n // 2, n - 1 - n // 2), mode="edge")
    return v - np.convolve(pad, np.ones(n) / n, mode="valid")


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("name")
    ap.add_argument("--start", type=float, default=0.0)
    ap.add_argument("--end", type=float, required=True)
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
        hsv = cv2.cvtColor(bgr, cv2.COLOR_BGR2HSV)
        board = find_board(hsv)
        beach = find_beach(hsv, board[1][1] - 150) if board else None
        pitch = board[0] - beach[0] if board and beach else None
        rows.append({"t": round(f / info["fps"], 3), "board_deg": round(board[0], 3) if board else "",
                     "beach_deg": round(beach[0], 3) if beach else "",
                     "pitch_deg": round(pitch, 3) if pitch is not None else "",
                     "board_px": board[2] if board else ""})
        if f in want:
            view = bgr.copy()
            for item, colour in ((board, (0, 255, 0)), (beach, (0, 255, 255))):
                if item:
                    x0, y0, vx, vy = item[1]
                    cv2.line(view, (int(x0 - 700 * vx), int(y0 - 700 * vy)),
                             (int(x0 + 700 * vx), int(y0 + 700 * vy)), colour, 3)
            cv2.putText(view, "t=%.2f pitch %s" % (f / info["fps"], rows[-1]["pitch_deg"]), (20, 60),
                        cv2.FONT_HERSHEY_SIMPLEX, 1.5, (255, 255, 255), 3)
            cv2.imwrite(os.path.join(out_dir, "pitch_debug_%05.2f.png" % (f / info["fps"])),
                        cv2.resize(view, (W // 2, H // 2)))
    with open(os.path.join(out_dir, "side_pitch.csv"), "w", newline="", encoding="utf-8") as fh:
        wr = csv.DictWriter(fh, fieldnames=list(rows[0].keys()))
        wr.writeheader()
        wr.writerows(rows)
    good = [r for r in rows if r["pitch_deg"] != ""]
    print("frames with board and beach: %d of %d" % (len(good), len(rows)))
    if len(good) < 25:
        return
    # only stretches without gaps longer than 2 frames count for the rhythm
    t = np.array([r["t"] for r in good])
    p = np.array([r["pitch_deg"] for r in good], float)
    n = int(info["fps"])
    d = detrend(p, n)
    print("pitch (absolute, includes rocker and outline): median %.1f deg" % np.median(p))
    print("pitch changes faster than 1 s: spread %.2f deg, middle 90%% %.2f to %.2f deg" % (
        d.std(), np.percentile(d, 5), np.percentile(d, 95)))
    gaps = np.diff(t) > 3.0 / info["fps"]
    if not gaps.any():
        spec = np.abs(np.fft.rfft((d - d.mean()) * np.hanning(len(d))))
        freqs = np.fft.rfftfreq(len(d), 1.0 / info["fps"])
        band = (freqs > 0.3) & (freqs < 6.0)
        print("main rhythm: %.2f Hz" % freqs[band][np.argmax(spec[band])])
    else:
        print("gaps in the series (%d): no rhythm computed" % int(gaps.sum()))


if __name__ == "__main__":
    main()
