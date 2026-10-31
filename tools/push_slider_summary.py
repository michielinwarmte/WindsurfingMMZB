#!/usr/bin/env python3
"""The push slider's tables (Documentation/reports/push_slider/PLAN.md), from push-check runs made
with --sweep=push.level=... or --push=<level>:

    python3 -I tools/push_slider_summary.py <run> [<run> ...]

For each run (.sim_output/push/<run>/results.csv): one table per wind, the courses down and the
slider's levels across, each cell the speed made good (m/s) and the falls ("F2"); then the means
per level over the planing courses (100 to 135 degrees at 18 and 24 kt): the speed sailing, the
sheet, the fin's slip, lift and upward part, the back foot, the wet front, the trim, the pitch SD
and the falls in all. The goal (PLAN.md section 2): the speed made good rising with the level on
the planing courses, the falls starting above 75 %, 0 % below 1 m/s.
"""
import csv
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PLANING = {(18, 100), (18, 120), (18, 135), (24, 100), (24, 120), (24, 135)}


def level_of(row):
    if "push_level" in row and row["push_level"] not in ("", "nan", "-1"):
        try:
            return float(row["push_level"])
        except ValueError:
            pass
    m = re.search(r"level=([\d.]+)", row.get("sweep", ""))
    return float(m.group(1)) if m else -1.0


def f(row, key, default=0.0):
    try:
        return float(row.get(key, default))
    except (TypeError, ValueError):
        return default


def summarise(run):
    path = os.path.join(ROOT, ".sim_output", "push", run, "results.csv")
    if not os.path.exists(path):
        print("==== %s: no results.csv" % run)
        return
    rows = list(csv.DictReader(open(path, newline="")))
    for r in rows:
        r["_level"] = level_of(r)
        r["_wind"] = int(f(r, "wind_kt"))
        r["_twa"] = int(f(r, "twa_deg"))
    levels = sorted({r["_level"] for r in rows})
    winds = sorted({r["_wind"] for r in rows})
    twas = sorted({r["_twa"] for r in rows})
    print("==== %s: %d cases, levels %s" % (run, len(rows), " ".join("%.0f%%" % (l * 100) for l in levels)))
    for wind in winds:
        print("%d kt  twa | " % wind + "  ".join("%7s" % ("%.0f%%" % (l * 100)) for l in levels))
        for twa in twas:
            cells = []
            for level in levels:
                hit = [r for r in rows if r["_wind"] == wind and r["_twa"] == twa and r["_level"] == level]
                if not hit:
                    cells.append("%7s" % "-")
                    continue
                r = hit[0]
                falls = int(f(r, "falls"))
                cells.append("%7s" % ("%.2f%s" % (f(r, "made_good_ms"), ("F%d" % falls) if falls else "")))
            print("       %3d | " % twa + "  ".join(cells))
    print("per level over the planing courses (18 and 24 kt, 100 to 135): speed sheet slip finN finUp back front trim pitchSD | falls in all cases")
    for level in levels:
        plan = [r for r in rows if (r["_wind"], r["_twa"]) in PLANING and r["_level"] == level]
        all_rows = [r for r in rows if r["_level"] == level]
        falls = sum(int(f(r, "falls")) for r in all_rows)
        if not plan:
            print("  %4.0f%%  (no planing cases)  falls %d" % (level * 100, falls))
            continue
        n = float(len(plan))
        mean = lambda key: sum(f(r, key) for r in plan) / n
        print("  %4.0f%%  %5.2f  %4.2f  %4.1f  %5.0f  %5.0f  %4.2f  %4.2f  %4.2f  %4.2f  | falls %d" % (
            level * 100, mean("speed_sailing_ms"), mean("sheet_mean"), mean("slip_mean_deg"), mean("fin_lift_mean_n"),
            mean("fin_up_mean_n"), mean("back_foot_mean"), mean("wet_front_m"), mean("trim_mean_deg"), mean("pitch_sd_deg"), falls))
    print()


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(2)
    for run in sys.argv[1:]:
        summarise(run)


if __name__ == "__main__":
    main()
