#!/usr/bin/env python3
"""One compact table per variant of an autopilot suite round (tools/autopilot_suite.sh).

    python3 -I tools/autopilot_summary.py <round> [<label> ...]

Reads .sim_output/autopilot/<round>/<label>/: reach.txt and reach/*.csv (the rake, the rig's lean,
the sheet and the angle of attack over the measured window), push_neutral.txt, push_pushed.txt (the
printed tables) and matrix.txt (the last line). Marks the goal's rows of PLAN.md section 1: the
wet front 0.6 to 1.0 m, the trim 1.0 to 2.5 deg and the pitch SD below 0.3 on the 18 and 24 kt
beam and broad reaches; the push's centre 0.45 to 0.75 m.
"""
import csv
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GOAL_CASES = {(18, 100), (18, 135), (24, 100), (24, 135)}


def reach_rows(path):
    rows = []
    if not os.path.exists(path):
        return rows
    for line in open(path, encoding="utf-8", errors="replace"):
        m = re.match(r"\s*(\d+)\s+(\d+)\s+([\d.]+)\s+\(\s*([\d.]+)\)\s+([-\d.]+)\s+([-\d.]+)\s+([-\d.]+)\s+([-\d.]+)\s+([-\d.]+)\s+([-\d.]+)\s+(\d+)", line)
        if not m:
            continue
        rest = line.split("|")
        fell = rest[-1].strip() if len(rest) >= 3 else "?"
        heel = "?"
        if len(rest) >= 3:
            fin = rest[1].split()
            if len(fin) >= 6:
                heel = fin[5]
        rows.append({
            "wind": int(m.group(1)), "twa": int(m.group(2)), "speed": float(m.group(3)),
            "plan": float(m.group(5)), "front": float(m.group(6)), "wet": float(m.group(7)),
            "push": float(m.group(8)), "trim": float(m.group(9)), "sd": float(m.group(10)),
            "harness": int(m.group(11)), "heel": heel, "fell": fell,
        })
    return rows


def reach_csv_means(csv_dir, wind, twa, from_s=60.0):
    """Means over t >= from_s of the columns the printed table does not have."""
    path = os.path.join(csv_dir, "reach_%d_%d.csv" % (wind, twa))
    if not os.path.exists(path):
        return {}
    sums = {}
    n = 0
    with open(path, newline="") as f:
        for r in csv.DictReader(f):
            try:
                if float(r["time_s"]) < from_s:
                    continue
            except (KeyError, ValueError):
                continue
            n += 1
            for key in ("rake", "rig_lean_deg", "sheet", "alpha_deg", "hang_back_m", "lean"):
                try:
                    sums[key] = sums.get(key, 0.0) + float(r[key])
                except (KeyError, ValueError):
                    pass
    return {k: v / n for k, v in sums.items()} if n else {}


def push_rows(path):
    rows = []
    if not os.path.exists(path):
        return rows
    for line in open(path, encoding="utf-8", errors="replace"):
        tokens = line.split()
        if len(tokens) < 21 or not re.match(r"^\d+$", tokens[0]) or not re.match(r"^\d+$", tokens[1]):
            continue
        # The sweep column is blank for a run without a sweep: then the third token is a number.
        try:
            float(tokens[2])
            rest = tokens[2:]
        except ValueError:
            rest = tokens[3:]
        try:
            rows.append({"wind": int(tokens[0]), "twa": int(tokens[1]), "made": float(rest[0]),
                         "vmg": float(rest[1]), "falls": int(rest[3]), "speed": float(rest[4])})
        except (ValueError, IndexError):
            continue
    return rows


def matrix_line(path):
    if not os.path.exists(path):
        return "(no matrix)"
    last = ""
    for line in open(path, encoding="utf-8", errors="replace"):
        if " cases: " in line:
            last = line.strip()
    return last or "(matrix: no summary line)"


def mark(ok):
    return "ok " if ok else "NO "


def summarise(round_name, label):
    base = os.path.join(ROOT, ".sim_output", "autopilot", round_name, label)
    over = open(os.path.join(base, "overrides.txt")).read().strip() if os.path.exists(os.path.join(base, "overrides.txt")) else ""
    print("==== %s / %s: %s" % (round_name, label, over or "(the defaults)"))
    rows = reach_rows(os.path.join(base, "reach.txt"))
    if rows:
        print("reach  wind twa  speed  front  push  trim   sd    harn  heel  rake  lean  sheet alpha | goal(front trim sd push)  fell")
        met = 0
        for r in rows:
            extra = reach_csv_means(os.path.join(base, "reach"), r["wind"], r["twa"])
            goal = ""
            if (r["wind"], r["twa"]) in GOAL_CASES:
                ok_front = 0.6 <= r["front"] <= 1.0
                ok_trim = 1.0 <= r["trim"] <= 2.5
                ok_sd = r["sd"] < 0.3
                ok_push = 0.45 <= r["push"] <= 0.75
                goal = mark(ok_front) + mark(ok_trim) + mark(ok_sd) + mark(ok_push)
                met += int(ok_front and ok_trim and ok_sd)
            print("       %3d  %3d  %5.2f  %5.2f  %4.2f  %5.2f  %4.2f  %4d  %5s  %4s  %5s  %5s %5s | %-24s %s" % (
                r["wind"], r["twa"], r["speed"], r["front"], r["push"], r["trim"], r["sd"], r["harness"], r["heel"],
                ("%.2f" % extra["rake"]) if "rake" in extra else "?",
                ("%.1f" % extra["rig_lean_deg"]) if "rig_lean_deg" in extra else "?",
                ("%.2f" % extra["sheet"]) if "sheet" in extra else "?",
                ("%.1f" % extra["alpha_deg"]) if "alpha_deg" in extra else "?",
                goal, r["fell"]))
        steady = sum(1 for r in rows if r["sd"] < 0.3 and r["fell"] == "ok")
        print("       goal cases met (front, trim, sd): %d of 4; steady and upright: %d of %d" % (met, steady, len(rows)))
    else:
        print("reach: no rows")
    for name, title in (("push_neutral.txt", "push neutral"), ("push_pushed.txt", "push pushed (hike 1.6)")):
        prow = push_rows(os.path.join(base, name))
        if prow:
            falls = sum(r["falls"] for r in prow)
            cells = ["%d/%d %.2f%s" % (r["wind"], r["twa"], r["made"], (" F%d" % r["falls"]) if r["falls"] else "") for r in prow]
            print("%-24s falls %d | %s" % (title, falls, "  ".join(cells)))
        else:
            print("%-24s (no rows)" % title)
    print("matrix  %s" % matrix_line(os.path.join(base, "matrix.txt")))
    print()


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(2)
    round_name = sys.argv[1]
    root = os.path.join(ROOT, ".sim_output", "autopilot", round_name)
    labels = sys.argv[2:] or sorted(d for d in os.listdir(root) if os.path.isdir(os.path.join(root, d)))
    for label in labels:
        summarise(round_name, label)


if __name__ == "__main__":
    main()
