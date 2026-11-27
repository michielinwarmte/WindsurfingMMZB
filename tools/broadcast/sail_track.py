"""Follow the sails through one stretch of a drone shot and write their size and place per frame.

For the drone study: how tall a sail is in the picture and where it stands, frame by frame,
is what the drone's height, its lens and the boards' speed are worked out from
(drone_geometry.py). A sail is found by its colour: everything below the horizon that is
neither the colour of the water nor white like foam. Each sail is then followed from frame
to frame. The land on the horizon is followed too (how far the picture shifts from frame to
frame), so a camera that turns a little can be told from a board that moves.

    python -E -P tools/broadcast/sail_track.py <video.mp4> <start_s> <end_s> <out folder>
        [--horizon=205]      the row of the sea's far edge (default: found per frame)
        [--min-height=14]    the smallest sail, in pixels
        [--show=6]           frames on the check picture

Writes tracks.csv (frame, t, track, x_left, x_right, y_top, y_bottom, horizon_y, and cam_dx,
cam_dy: how far the picture has shifted since the first frame, measured on the land at the
horizon, with cam_sure: how well that was seen)
and check.jpg: frames with every followed sail boxed and numbered, to be looked at before
any number is used.
"""
import argparse
import csv
import os

import cv2
import numpy as np


def find_horizon(hsv):
    """The row where the sea begins: going down each column, the first long run of water blue."""
    h, s, v = cv2.split(hsv)
    water = ((h > 85) & (h < 125) & (s > 70)).astype(np.uint8)
    rows = water.mean(axis=1)
    smooth = np.convolve(rows, np.ones(5) / 5.0, mode="same")
    for y in range(5, len(smooth) - 20):
        if smooth[y] > 0.6 and smooth[y:y + 20].mean() > 0.6:
            return y
    return 0


def sail_mask(hsv, horizon):
    h, s, v = cv2.split(hsv)
    water = (h > 85) & (h < 125) & (s > 60)
    foam = (s < 70) & (v > 140)
    mask = ~(water | foam)
    mask[:max(horizon + 3, 0), :] = False
    m = mask.astype(np.uint8) * 255
    m = cv2.morphologyEx(m, cv2.MORPH_CLOSE, cv2.getStructuringElement(cv2.MORPH_RECT, (3, 9)))
    m = cv2.morphologyEx(m, cv2.MORPH_OPEN, cv2.getStructuringElement(cv2.MORPH_RECT, (2, 2)))
    return m


def find_buoy(hsv, horizon):
    """The biggest round orange thing below the horizon, or None."""
    h, s, v = cv2.split(hsv)
    orange = ((h < 14) | (h > 172)) & (s > 150) & (v > 150)
    orange[:horizon + 3, :] = False
    n, _, stats, cents = cv2.connectedComponentsWithStats(orange.astype(np.uint8), 8)
    best = None
    for i in range(1, n):
        x, y, w, hh, area = stats[i]
        if area >= 40 and 0.5 < w / max(hh, 1) < 1.6 and area > 0.55 * w * hh:
            if best is None or area > best[2]:
                best = (float(cents[i][0]), float(cents[i][1]), area, hh)
    return best


def land_band(frame, horizon):
    """The strip of land and far shore just above the sea's edge, as a float picture."""
    top = max(horizon - 44, 0)
    band = cv2.cvtColor(frame[top:horizon + 4, :], cv2.COLOR_BGR2GRAY).astype(np.float32)
    return band


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("video")
    ap.add_argument("start", type=float)
    ap.add_argument("end", type=float)
    ap.add_argument("out")
    ap.add_argument("--horizon", type=int, default=-1)
    ap.add_argument("--min-height", type=int, default=14)
    ap.add_argument("--show", type=int, default=6)
    a = ap.parse_args()
    os.makedirs(a.out, exist_ok=True)
    cap = cv2.VideoCapture(a.video)
    fps = cap.get(cv2.CAP_PROP_FPS) or 25.0
    cap.set(cv2.CAP_PROP_POS_MSEC, 1000.0 * a.start)
    tracks, next_id, rows, keep = {}, 1, [], []
    first_band, prev_band, cam = None, None, [0.0, 0.0]
    n_frames = int((a.end - a.start) * fps)
    show_at = set(int(i * (n_frames - 1) / max(a.show - 1, 1)) for i in range(a.show))
    for k in range(n_frames):
        ok, frame = cap.read()
        if not ok:
            break
        t = a.start + k / fps
        hsv = cv2.cvtColor(frame, cv2.COLOR_BGR2HSV)
        horizon = a.horizon if a.horizon >= 0 else find_horizon(hsv)
        buoy = find_buoy(hsv, horizon)
        # How far the picture has shifted since the first frame (the camera turning), from the
        # land on the horizon: frame-to-frame shifts added up. `sure` near 0 = no land to go by.
        band = land_band(frame, horizon)
        sure = 1.0
        if prev_band is not None and band.shape == prev_band.shape and band.shape[0] >= 16:
            (dx, dy), sure = cv2.phaseCorrelate(prev_band, band, cv2.createHanningWindow(band.shape[::-1], cv2.CV_32F))
            cam[0] += dx
            cam[1] += dy
        prev_band = band
        m = sail_mask(hsv, horizon)
        n, _, stats, _ = cv2.connectedComponentsWithStats(m, 8)
        boxes = []
        for i in range(1, n):
            x, y, w, h, area = stats[i]
            if h < a.min_height or h / max(w, 1) < 0.6 or area < 0.18 * w * h:
                continue
            if buoy is not None and x <= buoy[0] <= x + w and y <= buoy[1] <= y + h and h < 2.2 * buoy[3]:
                continue
            boxes.append((x, y, x + w, y + h))
        # Each box goes on with the track whose last box it overlaps most.
        used, now = set(), {}
        for b in sorted(boxes, key=lambda b: -(b[3] - b[1])):
            best, best_o = None, 0.0
            for tid, (pb, pk) in tracks.items():
                if tid in used or k - pk > 5:
                    continue
                ox = min(b[2], pb[2]) - max(b[0], pb[0])
                oy = min(b[3], pb[3]) - max(b[1], pb[1])
                if ox > 0 and oy > 0:
                    o = ox * oy / float((b[2] - b[0]) * (b[3] - b[1]))
                    if o > best_o:
                        best, best_o = tid, o
            if best is None or best_o < 0.25:
                best = next_id
                next_id += 1
            used.add(best)
            now[best] = b
            tracks[best] = (b, k)
            rows.append([k, "%.2f" % t, best, b[0], b[2], b[1], b[3], horizon,
                         "%.2f" % cam[0], "%.2f" % cam[1], "%.2f" % sure])
        if k in show_at:
            vis = frame.copy()
            cv2.line(vis, (0, horizon), (vis.shape[1], horizon), (0, 255, 255), 1)
            for tid, b in now.items():
                cv2.rectangle(vis, (b[0], b[1]), (b[2], b[3]), (0, 255, 0), 1)
                cv2.putText(vis, str(tid), (b[0], b[1] - 2), cv2.FONT_HERSHEY_SIMPLEX, 0.4, (0, 255, 0), 1)
            if buoy:
                cv2.circle(vis, (int(buoy[0]), int(buoy[1])), 6, (255, 255, 255), 1)
            cv2.putText(vis, "t=%.2f" % t, (8, vis.shape[0] - 8), cv2.FONT_HERSHEY_SIMPLEX, 0.5, (255, 255, 255), 2)
            keep.append(vis)
    cap.release()
    with open(os.path.join(a.out, "tracks.csv"), "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(["frame", "t", "track", "x_left", "x_right", "y_top", "y_bottom", "horizon_y", "cam_dx", "cam_dy", "cam_sure"])
        w.writerows(rows)
    if keep:
        cols = 2
        grid = [np.hstack(keep[i:i + cols] + [np.zeros_like(keep[0])] * (cols - len(keep[i:i + cols])))
                for i in range(0, len(keep), cols)]
        cv2.imwrite(os.path.join(a.out, "check.jpg"), np.vstack(grid), [cv2.IMWRITE_JPEG_QUALITY, 88])
    lengths = {}
    for r in rows:
        lengths[r[2]] = lengths.get(r[2], 0) + 1
    long = sorted(((n, tid) for tid, n in lengths.items() if n >= fps), reverse=True)
    print("%d frames, %d tracks, %d of at least 1 s: %s" % (n_frames, len(lengths), len(long),
                                                            " ".join("#%d:%d" % (tid, n) for n, tid in long[:12])))


if __name__ == "__main__":
    main()
