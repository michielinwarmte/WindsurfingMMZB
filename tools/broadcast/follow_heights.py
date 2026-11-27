"""How high the drone flies in the follow shots, measured without knowing its lens.

A thing standing on the water reaches up to the horizon in the picture exactly when its top
is as high as the camera. So for a sail whose foot is at row y_foot and whose top is at
y_top, with the horizon at y_horizon:

    camera height / sail height = (y_foot - y_horizon) / (y_foot - y_top)

For every drone beat of the shot notes that follows boards in the race, this runs
sail_track.py on a short stretch from the beat's middle, takes the sail that agrees with
the reader's own estimate of the sail's size (so a wrong box is thrown out), and writes the
ratio. With a lens given (--fov), it also works out the camera's tilt, its distance and its
height in metres, using the height a raked sail really shows from that side (SAIL below).

    python -E -P tools/broadcast/follow_heights.py <media root> --ids=<id,...> --heats=<json>
        --work=<folder> --out=<csv> [--fov=47] [--formats=regular,obstacle]
        [--camera=drone] [--phases=race] [--min-sail=8]     which beats (the beach cam: shore_long_lens)
"""
import argparse
import collections
import csv
import json
import math
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
W, H = 854, 480

# The sail top against the mast foot, metres, for a slalom rig at speed: up, back (towards the
# tail) and to windward. From the game team's own measurements on drone videos (rake 33 to 36
# degrees from the side, 23 to 29 degrees of lean to windward, Documentation/reports/video/)
# and a mast tip about 4.5 m up the mast from the deck. An estimate.
SAIL_UP_M, SAIL_BACK_M, SAIL_WINDWARD_M = 3.5, 2.3, 1.6
# Where the camera is round the board for each view word, degrees (0 dead behind, 180 dead ahead).
VIEW_DEG = {"behind": 10.0, "behind_side": 45.0, "side": 90.0, "front_side": 135.0, "front": 170.0}


def shown_sail_m(view, alpha_rad):
    """The height a sail shows in the picture from this side, looking down at this angle: its
    top leans back, so from behind it looks lower and from ahead taller. The windward lean is
    left out: the notes don't say which side the drone is on, and it cancels on average."""
    towards = SAIL_BACK_M * math.cos(math.radians(VIEW_DEG.get(view, 90.0)))
    return SAIL_UP_M * math.cos(alpha_rad) - towards * math.sin(alpha_rad)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("root")
    ap.add_argument("--ids", required=True)
    ap.add_argument("--heats", required=True)
    ap.add_argument("--formats", default="regular,obstacle")
    ap.add_argument("--work", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--fov", type=float, default=47.0)
    ap.add_argument("--skip-tracking", action="store_true")
    ap.add_argument("--camera", default="drone")
    ap.add_argument("--phases", default="race")
    ap.add_argument("--min-sail", type=float, default=8.0)
    a = ap.parse_args()
    with open(a.heats, encoding="utf-8") as f:
        heats = json.load(f)
    formats = set(a.formats.split(","))
    focal = (H / 2.0) / math.tan(math.radians(a.fov) / 2.0)
    out_rows = []
    for vid in a.ids.split(","):
        if heats.get(vid, {}).get("format") not in formats:
            continue
        with open(os.path.join(a.root, vid, "shots", "shot_notes.csv"), encoding="utf-8-sig") as f:
            notes = list(csv.DictReader(f))
        for r in notes:
            if r["camera"] != a.camera or r["phase"] not in a.phases.split(",") or r["horizon_pct"] in ("none", "", "na"):
                continue
            if r["sail_pct"] in ("", "na") or float(r["sail_pct"]) < a.min_sail:
                continue
            start, end = float(r["start_s"]), float(r["end_s"])
            if end - start < 2.0:
                continue
            mid = (start + end) / 2.0
            horizon = int(round(float(r["horizon_pct"]) * H / 100.0))
            folder = os.path.join(a.work, "%s_%s%s" % (vid[:5], r["shot"], r["part"]))
            if not a.skip_tracking or not os.path.exists(os.path.join(folder, "tracks.csv")):
                subprocess.call([sys.executable, "-E", "-P", os.path.join(HERE, "sail_track.py"),
                                 os.path.join(a.root, vid, "video.mp4"), "%.2f" % (mid - 0.6), "%.2f" % (mid + 0.6),
                                 folder, "--horizon=%d" % horizon, "--show=1"], stdout=subprocess.DEVNULL)
            by = collections.defaultdict(list)
            with open(os.path.join(folder, "tracks.csv"), encoding="utf-8") as f:
                for t in csv.DictReader(f):
                    by[t["track"]].append(t)
            want = float(r["sail_pct"]) * H / 100.0
            best = None
            for tid, g in by.items():
                if len(g) < 12:
                    continue
                med = lambda k: sorted(float(x[k]) for x in g)[len(g) // 2]
                top, foot = med("y_top"), med("y_bottom")
                x = 0.5 * (med("x_left") + med("x_right"))
                size = foot - top
                if not (0.65 * want <= size <= 1.5 * want) or foot <= horizon + 5:
                    continue
                off = abs(x - W / 2.0) / W + abs(0.5 * (top + foot) - H / 2.0) / H
                if best is None or off < best[0]:
                    best = (off, tid, top, foot, x, size)
            if best is None:
                continue
            _, tid, top, foot, x, size = best
            ratio = (foot - horizon) / size
            # With the lens: the camera's tilt, the look-down angle to the board, the distances.
            tilt = math.atan((H / 2.0 - horizon) / focal)
            alpha = tilt + math.atan((foot - H / 2.0) / focal)
            sail_m = shown_sail_m(r["view"], alpha)
            height_m = ratio * sail_m
            ground_m = height_m / math.tan(alpha) if alpha > 0.02 else float("nan")
            out_rows.append({"video": vid, "shot": r["shot"] + r["part"], "view": r["view"], "subject": r["subject"],
                             "move": r["move"], "phase": r["phase"], "moment": r["moment"], "seconds": round(end - start, 1),
                             "track": tid, "horizon_y": horizon, "top_y": round(top), "foot_y": round(foot),
                             "x": round(x), "sail_px": round(size), "reader_sail_px": round(want),
                             "height_in_sails": round(ratio, 2), "tilt_deg": round(math.degrees(tilt), 1),
                             "look_down_deg": round(math.degrees(alpha), 1), "sail_shown_m": round(sail_m, 2),
                             "height_m": round(height_m, 1), "ground_distance_m": round(ground_m, 1)})
    with open(a.out, "w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=list(out_rows[0].keys()))
        w.writeheader()
        w.writerows(out_rows)

    def mid(vals):
        v = sorted(vals)
        return v[len(v) // 4], v[len(v) // 2], v[(3 * len(v)) // 4]
    print("%d beats measured (lens taken as %.0f degrees for the last three columns)" % (len(out_rows), a.fov))
    print("%-12s %-7s %3s  %-22s %-18s %-18s %-18s" % ("view", "on", "n", "height in sails", "look-down deg", "height m", "ground distance m"))
    groups = collections.defaultdict(list)
    on = {"leader": "front", "lead_group": "front", "duel": "pack", "chasers": "pack", "one_rider": "pack",
          "fleet": "fleet", "mark": "mark", "finish_line": "line", "start_line": "line"}
    for r in out_rows:
        groups[(r["view"].replace("behind", "behind_side").replace("behind_side_side", "behind_side")
                .replace("front", "front_side").replace("front_side_side", "front_side"), on.get(r["subject"], "other"))].append(r)
    for key, g in sorted(groups.items(), key=lambda kv: -len(kv[1])):
        if len(g) < 3:
            continue
        q = lambda k: "%.1f (%.1f-%.1f)" % tuple(mid([x[k] for x in g])[i] for i in (1, 0, 2))
        print("%-12s %-7s %3d  %-22s %-18s %-18s %-18s" % (key[0], key[1], len(g), q("height_in_sails"), q("look_down_deg"),
                                                         q("height_m"), q("ground_distance_m")))


if __name__ == "__main__":
    main()
