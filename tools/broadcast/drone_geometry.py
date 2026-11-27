"""The drone's lens and the boards' speed, from sails followed through still-drone shots.

Works on the tracks.csv files of sail_track.py. Everything is in pixels and in "sail
heights" (the height of a sail in the picture, from the board to the mast top, is the
ruler), so no length in metres is needed for the lens.

Two kinds of shot, both with the drone hanging in one place and land on the horizon, which
sail_track.py follows to take out the camera's turning:

  speed   boards crossing the picture: how many sail heights a board travels per second.
          For a board that keeps its distance this needs no lens:
              speed = the change of (x - the land's shift) / sail height, per second.
  lens    boards sailing towards the drone: a board on a straight course at that speed
          grows in the picture at a rate that depends on the lens. The fit finds the focal
          length (in pixels) for which one straight, steady course explains both the sail's
          growth and its move across the picture.

    python -E -P tools/broadcast/drone_geometry.py speed <tracks.csv>
    python -E -P tools/broadcast/drone_geometry.py lens <tracks.csv> --speed=<sail heights per s>
        [--min-seconds=1.5] [--width=854] [--height=480]

Prints one line per sail followed and the middle value over all.
"""
import argparse
import csv
import math
import os

import numpy as np
from scipy.optimize import least_squares


def load(path, min_seconds):
    """Clean stretches of each track: the box's height changing smoothly. The camera's turning
    (cam_dx, measured on the land at the horizon) comes along as the place of a fixed point."""
    by = {}
    with open(path, encoding="utf-8") as f:
        for r in csv.DictReader(f):
            by.setdefault(int(r["track"]), []).append(
                (int(r["frame"]), float(r["t"]), 0.5 * (float(r["x_left"]) + float(r["x_right"])),
                 float(r["y_top"]), float(r["y_bottom"]), float(r["cam_dx"]), float(r["cam_dy"]),
                 float(r["horizon_y"])))
    out = []
    for tid, rows in by.items():
        rows.sort()
        if len(rows) < 2:
            continue
        runs, run = [], [rows[0]]
        for a, b in zip(rows, rows[1:]):
            ha, hb = a[4] - a[3], b[4] - b[3]
            if b[0] - a[0] > 3 or abs(hb - ha) > 0.25 * max(ha, hb) + 3.0:
                runs.append(run)
                run = []
            run.append(b)
        runs.append(run)
        best = max(runs, key=len)
        if best[-1][1] - best[0][1] >= min_seconds:
            # columns: t, x, y_top, y_bottom, fixed_x (a far point that began at the middle), fixed_y, horizon
            out.append((tid, np.array([[r[1], r[2], r[3], r[4], r[5], r[6], r[7]] for r in best])))
    return out


def smooth(v, n=5):
    k = np.ones(n) / n
    pad = np.pad(v, (n // 2, n // 2), mode="edge")
    return np.convolve(pad, k, mode="valid")


def speed_of(track):
    """Sail heights per second across the picture, for a board keeping its distance."""
    t = track[:, 0] - track[0, 0]
    s = smooth(track[:, 3] - track[:, 2])
    u = (track[:, 1] - track[:, 4]) / s
    slope = np.polyfit(t, u, 1)[0]
    grow = (s[-1] - s[0]) / s.mean()
    return abs(slope), grow, s.mean()


def fit_lens(track, w, width, height_px):
    """The focal length (pixels) for which a straight course at speed w explains the track."""
    t = track[:, 0] - track[0, 0]
    s = smooth(track[:, 3] - track[:, 2])
    cx = width / 2.0
    x = smooth(track[:, 1]) - cx
    xb = smooth(track[:, 4])            # a far fixed point that began at the picture's middle

    def model(p):
        f, r0, psi0, heading = p
        px = r0 * math.cos(psi0) + w * math.cos(heading) * t
        py = r0 * math.sin(psi0) + w * math.sin(heading) * t
        r = np.hypot(px, py)
        psi = np.arctan2(py, px)                 # the board's bearing; the buoy's is 0
        axis = -np.arctan(xb / f)                # where the camera points, from the buoy's place
        return f / r, f * np.tan(psi - axis)

    def resid(p):
        ms, mx = model(p)
        return np.concatenate([(ms - s) / s, (mx - x) / max(s.mean(), 1.0) * 0.5])

    best = None
    for f0 in (300.0, 500.0, 800.0, 1400.0):
        for heading0 in (math.pi, math.pi * 0.75, math.pi * 1.25, math.pi * 0.5, math.pi * 1.5):
            r0 = f0 / s[0]
            psi0 = math.atan((x[0] - xb[0]) / f0)
            try:
                sol = least_squares(resid, [f0, r0, psi0, heading0], loss="soft_l1", f_scale=0.1,
                                    bounds=([120.0, 0.5, -1.5, 0.0], [6000.0, 500.0, 1.5, 2.0 * math.pi]))
            except ValueError:
                continue
            if best is None or sol.cost < best.cost:
                best = sol
    f = best.x[0]
    rms = math.sqrt(2.0 * best.cost / len(best.fun))
    return f, 2.0 * math.degrees(math.atan(height_px / 2.0 / f)), rms, s[0], s[-1]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("what", choices=["speed", "lens"])
    ap.add_argument("tracks", nargs="+")
    ap.add_argument("--speed", type=float, default=0.0)
    ap.add_argument("--min-seconds", type=float, default=1.5)
    ap.add_argument("--only", default="")
    ap.add_argument("--width", type=int, default=854)
    ap.add_argument("--height", type=int, default=480)
    a = ap.parse_args()
    only = set(int(x) for x in a.only.split(",") if x)
    values = []
    for path in a.tracks:
        name = os.path.basename(os.path.dirname(path))
        for tid, tr in load(path, a.min_seconds):
            if only and tid not in only:
                continue
            secs = tr[-1, 0] - tr[0, 0]
            if a.what == "speed":
                w, grow, size = speed_of(tr)
                print("%s #%d  %.1f s  sail %.0f px  size change %+.0f %%  speed %.2f sail heights/s"
                      % (name, tid, secs, size, 100.0 * grow, w))
                values.append(w)
            else:
                f, fov, rms, s0, s1 = fit_lens(tr, a.speed, a.width, a.height)
                print("%s #%d  %.1f s  sail %.0f -> %.0f px  focal %.0f px  vertical view %.0f deg  (misfit %.3f)"
                      % (name, tid, secs, s0, s1, f, fov, rms))
                values.append(fov)
    if values:
        v = sorted(values)
        print("middle value %.2f (of %d; from %.2f to %.2f)" % (v[len(v) // 2], len(v), v[0], v[-1]))


if __name__ == "__main__":
    main()
