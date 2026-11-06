#!/usr/bin/env python3
"""Every fall a round's harnesses wrote (the FALL_DETAIL lines of Game/dev/fall_log.gd), grouped:
which rule fired (the kind), at what heel, in what situation, with what the sail, the pitch and the
sheet did in the 2 s before. For the stay-on-the-board work
(Documentation/reports/autopilot/stay_on_the_board.md).

    python -I tools/fall_detail.py <folder or file> [...] [--list=1] [--csv=<out.csv>]

Every *.txt file under the folders is read (the suite's job outputs, the race logs). --list=1 prints
one line per fall; --csv writes them all to one CSV.
"""
import csv
import os
import statistics
import sys

HEADER = ("harness,case,clock,wind,kind,time_s,lee_fall_heel_deg,lee_board_heel_deg,windward_tip_deg,deliberate_deg,pull_n,"
          "pull_share,side_n,hand_roll_nm,tip_share,tipping_s,feet_excess_nm,feet_pitch_excess_nm,pitch_deg,pitch_rate_dps,sheet,"
          "alpha_deg,speed_kt,twa_deg,tws_sail_kt,support_share,yaw_rate_dps,lean,lee_max2,tip_max2,tip_share_max2,pitch_min2,"
          "pitch_max2,support_min2,air_share2,sheet_m2,sheet_m1,sheet_m05,side_max2,pull_share_max2,yaw_abs_max2,lee_over15_s,"
          "windward_over19_s").split(",")


def read_falls(paths):
    falls = []
    for path in paths:
        files = []
        if os.path.isdir(path):
            for root, _dirs, names in os.walk(path):
                files.extend(os.path.join(root, n) for n in names if n.endswith(".txt") or n.endswith(".log"))
        else:
            files.append(path)
        for f in sorted(files):
            for line in open(f, encoding="utf-8", errors="replace"):
                if not line.startswith("FALL_DETAIL,"):
                    continue
                cells = line.strip().split(",")[1:]
                row = dict(zip(HEADER, cells))
                row["doing"] = ",".join(cells[len(HEADER):]) if len(cells) > len(HEADER) else ""
                row["file"] = os.path.relpath(f, path) if os.path.isdir(path) else f
                for key in HEADER[5:]:
                    try:
                        row[key] = float(row[key])
                    except (KeyError, ValueError):
                        row[key] = float("nan")
                falls.append(row)
    return falls


def situation(row):
    """A short name for what the board was doing."""
    if row["harness"] == "race":
        doing = row.get("doing", "").lower()
        for word in ("tack", "gybe", "start", "penalt", "round", "beat", "run", "reach", "shore", "free"):
            if word in doing:
                return "race:" + word
        return "race:other"
    name = row["case"]
    if name.startswith("tack"):
        return "tack/head-up"
    if name.startswith("gybe") or name.startswith("run"):
        return "gybe/bear-away"
    if name.startswith("irons"):
        return "out of irons"
    return "straight reach"


def airborne(row):
    return row["air_share2"] > 0.05 or row["support_min2"] < 0.3


def summary(falls, title):
    print("=== %s: %d falls" % (title, len(falls)))
    if not falls:
        return
    by_kind = {}
    for r in falls:
        by_kind.setdefault(r["kind"], []).append(r)
    print("%-12s %4s | %-21s | %-17s | %-13s | %-17s | %-17s | %-5s" % (
        "kind", "n", "lee heel at/max2", "windward tip", "side N at/max", "pitch min/max2", "sheet -2/-1/-.5/0", "air"))
    for kind, rows in sorted(by_kind.items(), key=lambda kv: -len(kv[1])):
        def med(key):
            values = [r[key] for r in rows if r[key] == r[key]]
            return statistics.median(values) if values else float("nan")
        n_air = sum(1 for r in rows if airborne(r))
        print("%-12s %4d | %5.1f %5.1f (%4.1f-%4.1f) | %5.1f (max %5.1f) | %5.0f %5.0f | %5.1f %5.1f | %4.2f %4.2f %4.2f %4.2f | %d/%d" % (
            kind, len(rows), med("lee_fall_heel_deg"), med("lee_max2"), min(r["lee_fall_heel_deg"] for r in rows),
            max(r["lee_fall_heel_deg"] for r in rows), med("windward_tip_deg"), med("tip_max2"), med("side_n"), med("side_max2"),
            med("pitch_min2"), med("pitch_max2"), med("sheet_m2"), med("sheet_m1"), med("sheet_m05"), med("sheet"), n_air, len(rows)))
    print("  (medians; the lee heel is the heel the fall check reads, leeward positive; air = falls with the board light in the 2 s before)")
    by_situation = {}
    for r in falls:
        by_situation.setdefault((situation(r), r["kind"]), []).append(r)
    print("  by situation and kind:")
    for (sit, kind), rows in sorted(by_situation.items(), key=lambda kv: -len(kv[1])):
        winds = {}
        for r in rows:
            winds[r["wind"]] = winds.get(r["wind"], 0) + 1
        print("    %-18s %-12s %3d   (%s)" % (sit, kind, len(rows), ", ".join("%s %d" % kv for kv in sorted(winds.items()))))


def main():
    paths = [a for a in sys.argv[1:] if not a.startswith("--")]
    options = dict(a[2:].split("=", 1) for a in sys.argv[1:] if a.startswith("--") and "=" in a)
    if not paths:
        print(__doc__)
        sys.exit(2)
    falls = read_falls(paths)
    summary(falls, " ".join(paths))
    if options.get("list") == "1":
        print("  harness case clock wind kind t | lee fall/board, tip, side, pull share, tip share/s, pitch, sheet -1/0, alpha, kt, twa, support min, air")
        for r in falls:
            print("  %-6s %-14s %5s %-9s %-11s %6.1f | %5.1f %5.1f %5.1f %5.0f %4.2f %4.2f/%4.2f %5.1f %4.2f/%4.2f %5.1f %5.1f %6.1f %4.2f %4.2f %s" % (
                r["harness"], r["case"][:14], r["clock"], r["wind"], r["kind"], r["time_s"], r["lee_fall_heel_deg"], r["lee_board_heel_deg"],
                r["windward_tip_deg"], r["side_n"], r["pull_share"], r["tip_share"], r["tipping_s"], r["pitch_deg"], r["sheet_m1"], r["sheet"],
                r["alpha_deg"], r["speed_kt"], r["twa_deg"], r["support_min2"], r["air_share2"], r.get("doing", "")[:30]))
    if options.get("csv"):
        with open(options["csv"], "w", newline="", encoding="utf-8") as handle:
            writer = csv.DictWriter(handle, fieldnames=HEADER + ["doing", "file"])
            writer.writeheader()
            for r in falls:
                writer.writerow(r)


if __name__ == "__main__":
    main()
