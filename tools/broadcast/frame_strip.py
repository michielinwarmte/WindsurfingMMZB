"""Full-size frames of one stretch of a video, side by side with a pixel grid, for measuring by eye.

    python -E -P tools/broadcast/frame_strip.py <video.mp4> <start_s> <step_s> <count> <out.jpg>
        [--cols=2] [--grid=40] [--crop=x0,y0,x1,y1] [--zoom=1]

Each frame carries its time; the grid lines are every --grid pixels of the ORIGINAL frame,
labelled with their pixel number, so a point can be read off as (x, y) in video pixels.
"""
import argparse

import cv2
import numpy as np


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("video")
    ap.add_argument("start", type=float)
    ap.add_argument("step", type=float)
    ap.add_argument("count", type=int)
    ap.add_argument("out")
    ap.add_argument("--cols", type=int, default=2)
    ap.add_argument("--grid", type=int, default=40)
    ap.add_argument("--crop", default="")
    ap.add_argument("--zoom", type=float, default=1.0)
    a = ap.parse_args()
    cap = cv2.VideoCapture(a.video)
    tiles = []
    for i in range(a.count):
        t = a.start + i * a.step
        cap.set(cv2.CAP_PROP_POS_MSEC, 1000.0 * t)
        ok, frame = cap.read()
        if not ok:
            break
        h, w = frame.shape[:2]
        x0, y0, x1, y1 = (int(v) for v in a.crop.split(",")) if a.crop else (0, 0, w, h)
        tile = frame[y0:y1, x0:x1]
        if a.zoom != 1.0:
            tile = cv2.resize(tile, None, fx=a.zoom, fy=a.zoom, interpolation=cv2.INTER_CUBIC)
        for gx in range((x0 // a.grid + 1) * a.grid, x1, a.grid):
            px = int((gx - x0) * a.zoom)
            cv2.line(tile, (px, 0), (px, tile.shape[0]), (0, 255, 255), 1)
            cv2.putText(tile, str(gx), (px + 2, 10), cv2.FONT_HERSHEY_SIMPLEX, 0.32, (0, 255, 255), 1)
        for gy in range((y0 // a.grid + 1) * a.grid, y1, a.grid):
            py = int((gy - y0) * a.zoom)
            cv2.line(tile, (0, py), (tile.shape[1], py), (0, 255, 255), 1)
            cv2.putText(tile, str(gy), (2, py - 2), cv2.FONT_HERSHEY_SIMPLEX, 0.32, (0, 255, 255), 1)
        cv2.putText(tile, "t=%.1f s" % t, (8, tile.shape[0] - 8), cv2.FONT_HERSHEY_SIMPLEX, 0.5, (255, 255, 255), 2)
        tiles.append(tile)
    cap.release()
    rows = []
    for r in range(0, len(tiles), a.cols):
        row = tiles[r:r + a.cols]
        while len(row) < a.cols:
            row.append(np.zeros_like(tiles[0]))
        rows.append(np.hstack(row))
    cv2.imwrite(a.out, np.vstack(rows), [cv2.IMWRITE_JPEG_QUALITY, 90])
    print(a.out, np.vstack(rows).shape)


if __name__ == "__main__":
    main()
