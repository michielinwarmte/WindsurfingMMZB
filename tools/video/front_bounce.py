"""How much the board moves up and down over the chop against how much the sailor's head moves,
seen from a camera ahead of the board (video 07). A level head over a moving board = the legs
absorb the chop (backlog E01.S07: "slam and skip under a level body").
The trustworthy number is the distance from the shoulders to the board: the drone's own
rising and sinking drops out of it, and its changes are the legs bending and stretching.

  python tools/video/front_bounce.py <name> --start S --end S [--debug t1,t2]

Per frame, all relative to the shoreline (fixed, so the drone's own up-and-down drops out):
  - board: the centre of the ellipse fitted to the board's dark underside (front_view.py);
  - head: the top of the sailor's dark hair/wetsuit blob below the shoreline, left of the mast;
  - shoreline: the dark land to blue water step, fitted across the clear columns.
Slow changes (the drone coming closer, about 1 s and longer) are taken out with a 1 s moving
average; what is left is the bounce. Prints the spread (standard deviation) of each, their
ratio, and the main bounce frequency. Pixels to centimetres: the board's long axis on screen is
taken as its width (72 cm board; the outline is the nose area, so this is rough).
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
from front_view import board_tilt, frames  # noqa: E402
from video import original, probe, video_dir  # noqa: E402

SHORE_COLUMNS = list(range(10, 260, 10)) + list(range(900, 1070, 10))
SHORE_ROWS = (700, 900)
HEAD_BOX_X = (0, 450)
BOARD_WIDTH_CM = 72.0
SHOULDER_PX = 110          # the body's width at the shoulders in video 07 (about 25 to 30 cm)


def shoreline_y(gray):
    """Row of the land-to-water step, the median over clear columns at both sides."""
    ys = []
    for x in SHORE_COLUMNS:
        col = cv2.GaussianBlur(gray[:, x:x + 4].mean(axis=1).reshape(-1, 1), (1, 7), 0).ravel()
        seg = col[SHORE_ROWS[0]:SHORE_ROWS[1]]
        step = seg[6:] - seg[:-6]  # water (below) brighter than the dark rocks and trees
        ys.append(SHORE_ROWS[0] + int(np.argmax(step)) + 3)
    return float(np.median(ys))


def head_top_y(hsv, shore):
    """Top of the sailor: the biggest dark blob (wetsuit, hair) below the shoreline in his
    columns. Dark patches of water are small; his body is by far the biggest dark shape."""
    x0, x1 = HEAD_BOX_X
    y0 = int(shore) + 25
    dark = ((hsv[y0:1500, x0:x1, 2] < 60) & (hsv[y0:1500, x0:x1, 1] < 120)).astype(np.uint8)
    dark = cv2.morphologyEx(dark, cv2.MORPH_OPEN, np.ones((5, 5), np.uint8))
    n, labels, stats, _ = cv2.connectedComponentsWithStats(dark, 8)
    if n < 2:
        return None
    big = 1 + int(np.argmax(stats[1:, cv2.CC_STAT_AREA]))
    if stats[big, cv2.CC_STAT_AREA] < 20000:  # not a body-sized blob
        return None
    # the shoulder line: the first row where the body is shoulder-wide (the hair above it is
    # sometimes joined to the body and sometimes not, so the very top would jump)
    widths = (labels == big).sum(axis=1)
    rows = np.nonzero(widths >= SHOULDER_PX)[0]
    return float(y0 + rows[0]) if len(rows) else None


def detrend(v, n):
    k = np.ones(n) / n
    pad = np.pad(v, (n // 2, n - 1 - n // 2), mode="edge")
    return v - np.convolve(pad, k, mode="valid")


def main_freq(v, fps):
    v = v - v.mean()
    spec = np.abs(np.fft.rfft(v * np.hanning(len(v))))
    freqs = np.fft.rfftfreq(len(v), 1.0 / fps)
    band = (freqs > 0.3) & (freqs < 6.0)
    return float(freqs[band][np.argmax(spec[band])])


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
        gray = cv2.cvtColor(bgr, cv2.COLOR_BGR2GRAY).astype(np.float32)
        shore = shoreline_y(gray)
        head = head_top_y(hsv, shore)
        board = board_tilt(bgr)
        rows.append({"t": f / info["fps"], "shore": shore, "head": head,
                     "board": board[2][1] if board else None,
                     "board_px": max(board[2][2], board[2][3]) if board else None})
        if f in want:
            view = bgr.copy()
            cv2.line(view, (0, int(shore)), (W, int(shore)), (0, 255, 255), 2)
            if head:
                cv2.line(view, (0, int(head)), (450, int(head)), (255, 0, 255), 2)
            if board:
                cv2.ellipse(view, ((board[2][0], board[2][1]), (board[2][2], board[2][3]),
                                   board[2][4]), (0, 255, 0), 3)
            cv2.imwrite(os.path.join(out_dir, "bounce_debug_%05.2f.png" % (f / info["fps"])),
                        cv2.resize(view, (W // 2, H // 2)))
    good = [r for r in rows if r["head"] is not None and r["board"] is not None]
    with open(os.path.join(out_dir, "bounce.csv"), "w", newline="", encoding="utf-8") as fh:
        wr = csv.DictWriter(fh, fieldnames=list(rows[0].keys()))
        wr.writeheader()
        wr.writerows(rows)
    if len(good) < 20:
        sys.exit("too few frames with both the board and the head")
    fps = info["fps"]
    n = int(fps)  # 1 s moving average
    board = detrend(np.array([r["board"] - r["shore"] for r in good]), n)
    head = detrend(np.array([r["head"] - r["shore"] for r in good]), n)
    px_per_cm = np.median([r["board_px"] for r in good]) / BOARD_WIDTH_CM
    print("frames with board and head: %d of %d" % (len(good), len(rows)))
    print("scale: %.1f px per cm (board's long axis taken as %d cm; rough)" % (px_per_cm, BOARD_WIDTH_CM))
    print("board bounce: spread %.1f px = %.1f cm, main frequency %.2f Hz" % (
        board.std(), board.std() / px_per_cm, main_freq(board, fps)))
    print("head bounce:  spread %.1f px = %.1f cm, main frequency %.2f Hz" % (
        head.std(), head.std() / px_per_cm, main_freq(head, fps)))
    print("head / board: %.2f  (0 = perfectly level head, 1 = the head moves like the board)" % (
        head.std() / board.std()))
    print("correlation board-head: %.2f" % np.corrcoef(board, head)[0, 1])
    # The drone's own rising and sinking moves the near sailor more than the far shoreline, so
    # both numbers above carry it. The distance from the shoulders to the board does not: its
    # changes are the legs bending and stretching.
    gap = np.array([r["board"] - r["head"] for r in good])
    gap_b = detrend(gap, n)
    print("shoulders-to-board distance: mean %.0f px = %.0f cm; changes (spread) %.1f px = %.1f cm, main frequency %.2f Hz" % (
        gap.mean(), gap.mean() / px_per_cm, gap_b.std(), gap_b.std() / px_per_cm, main_freq(gap_b, fps)))
    print("  middle 90 %% of the changes: %.1f to %.1f cm" % (np.percentile(gap_b, 5) / px_per_cm, np.percentile(gap_b, 95) / px_per_cm))


if __name__ == "__main__":
    main()
