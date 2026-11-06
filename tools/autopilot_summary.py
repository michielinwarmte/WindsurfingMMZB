#!/usr/bin/env python3
"""One compact table per variant of an autopilot suite round (tools/autopilot_suite.sh).

    python3 -I tools/autopilot_summary.py <round> [<label> ...]
    python3 -I tools/autopilot_summary.py <round> --table [<label> ...]   one line per variant
    python3 -I tools/autopilot_summary.py <round>,<round2> --table          several rounds in one table

The lake (tools/autopilot_suite.sh --only=lake): lake_afternoons.txt (the reaches at ten times of
day), lake_map.txt (the lake matrix in the map's wind), lake_steady18.txt and lake_steady24.txt
(every manoeuvre in a steady wind at three times); per group the falls, the manoeuvres not
completed and the mean speed in the window (kt). The race on T2 on the lake: race_*.txt.

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


LAKE_GROUPS = ("afternoons", "map", "steady18", "steady24")


def lake_rows(path):
    """The lines of a lake file: name, time, fall text, done, window mean speed (kt) or None."""
    rows = []
    if not os.path.exists(path):
        return rows
    for line in open(path, encoding="utf-8", errors="replace"):
        if "|" not in line:
            continue
        cells = [c.strip() for c in line.rstrip("\n").split("|")]
        if len(cells) < 6:
            continue
        head = cells[0].split()
        if len(head) < 2:
            continue
        window = cells[5].split()
        mean = None
        if len(window) == 3 and window[2] != "-":
            try:
                mean = float(window[2])
            except ValueError:
                mean = None
        done = cells[3].split()[0] if cells[3].split() else "-"
        rows.append({"name": head[0], "time": head[1], "fall": cells[2], "done": done, "mean": mean})
    return rows


def lake_kind(name):
    if name in ("straight", "broad", "broad_mid"):
        return "straight"
    return name.split("_")[0]


def lake_stats(rows):
    falls = sum(1 for r in rows if r["fall"] not in ("-", ""))
    unfinished = sum(1 for r in rows if lake_kind(r["name"]) != "straight" and r["done"] == "-")
    catapults = sum(1 for r in rows if "catapult" in r["fall"])
    by_name = {}
    for r in rows:
        if r["mean"] is not None:
            by_name.setdefault(r["name"], []).append(r["mean"])
    means = {k: sum(v) / len(v) for k, v in by_name.items()}
    manoeuvres = [r["mean"] for r in rows if lake_kind(r["name"]) != "straight" and r["mean"] is not None]
    return {"n": len(rows), "falls": falls, "unfinished": unfinished, "catapults": catapults, "means": means,
            "manoeuvre_mean": sum(manoeuvres) / len(manoeuvres) if manoeuvres else 0.0}


def race_rows(path):
    import re
    rows = []
    if not os.path.exists(path):
        return rows
    for line in open(path, encoding="utf-8", errors="replace"):
        m = re.match(r"\s*(\d+)\. (.+?)\s+(DNF|\d+:\d\d\.\d)\s+.*falls (\d+)\s+tacks (\d+)\s+gybes (\d+)", line)
        if not m:
            continue
        t = None
        if m.group(3) != "DNF":
            mins, secs = m.group(3).split(":")
            t = int(mins) * 60 + float(secs)
        rows.append({"name": m.group(2).strip(), "time": t, "falls": int(m.group(4)), "tacks": int(m.group(5)), "gybes": int(m.group(6))})
    return rows


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
    for group in LAKE_GROUPS:
        rows = lake_rows(os.path.join(base, "lake_%s.txt" % group))
        if not rows:
            continue
        st = lake_stats(rows)
        means = "  ".join("%s %.1f" % (k, v) for k, v in sorted(st["means"].items()))
        print("lake %-10s %2d cases: falls %d (catapults %d), not completed %d | %s" % (
            group, st["n"], st["falls"], st["catapults"], st["unfinished"], means))
        for r in rows:
            if r["fall"] not in ("-", "") or (lake_kind(r["name"]) != "straight" and r["done"] == "-"):
                print("      %-10s %s  fall %-15s done %s" % (r["name"], r["time"], r["fall"], r["done"]))
    for name in sorted(os.listdir(base)) if os.path.isdir(base) else []:
        if name.startswith("race_") and name.endswith(".txt"):
            rows = race_rows(os.path.join(base, name))
            cells = ["%s %s F%d" % (r["name"].split()[0][:8], ("%.0f s" % r["time"]) if r["time"] is not None else "DNF", r["falls"]) for r in rows]
            print("%-24s %s" % (name[:-4], "  ".join(cells) if cells else "(no results)"))
    print()


def table_line(round_name, label):
    """One line per variant: the open water, then the lake."""
    base = os.path.join(ROOT, ".sim_output", "autopilot", round_name, label)
    cells = []
    rows = reach_rows(os.path.join(base, "reach.txt"))
    if rows:
        met = sum(1 for r in rows if (r["wind"], r["twa"]) in GOAL_CASES and 0.6 <= r["front"] <= 1.0 and 1.0 <= r["trim"] <= 2.5 and r["sd"] < 0.3)
        steady = sum(1 for r in rows if r["sd"] < 0.3 and r["fell"] == "ok")
        mean_v = sum(r["speed"] for r in rows) / len(rows)
        cells.append("reach %d/4 %d/9 %5.2f" % (met, steady, mean_v))
    elif os.path.exists(os.path.join(base, "reach_as_base.txt")):
        cells.append("reach %-12s" % "= defaults")
    else:
        cells.append("reach %-12s" % "-")
    for name in ("push_neutral.txt", "push_pushed.txt"):
        prow = push_rows(os.path.join(base, name))
        if prow:
            cells.append("F%d %5.2f" % (sum(r["falls"] for r in prow), sum(r["made"] for r in prow) / len(prow)))
        else:
            cells.append("%-8s" % "-")
    import re
    m = re.match(r"(\d+) cases: (\d+) with a fall, (\d+) with NaN, (\d+) manoeuvres", matrix_line(os.path.join(base, "matrix.txt")))
    cells.append("mx F%s U%s" % (m.group(2), m.group(4)) if m else "mx -    ")
    for group in LAKE_GROUPS:
        rows = lake_rows(os.path.join(base, "lake_%s.txt" % group))
        if not rows:
            cells.append("%-17s" % (group[:3] + " -"))
            continue
        st = lake_stats(rows)
        if group == "afternoons":
            cells.append("aft F%d %4.1f %4.1f %4.1f" % (st["falls"], st["means"].get("straight", 0), st["means"].get("broad", 0), st["means"].get("broad_mid", 0)))
        else:
            cells.append("%s F%2d C%d U%d %4.1f %4.1f" % ({"map": "map", "steady18": "s18", "steady24": "s24"}[group], st["falls"], st["catapults"], st["unfinished"],
                                                st["means"].get("straight", 0), st["manoeuvre_mean"]))
    races = []
    for name in sorted(os.listdir(base)) if os.path.isdir(base) else []:
        if name.startswith("race_") and name.endswith(".txt"):
            rr = race_rows(os.path.join(base, name))
            if rr:
                fin = [r["time"] for r in rr if r["time"] is not None]
                races.append("%d/%d %s F%d" % (len(fin), len(rr), ("%.0f" % (sum(fin) / len(fin))) if fin else "-", sum(r["falls"] for r in rr)))
    if races:
        cells.append("race " + " ".join(races))
    return "%-22s %s" % (label[:22], " | ".join(cells))


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(2)
    args = sys.argv[1:]
    table = "--table" in args
    args = [a for a in args if a != "--table"]
    for round_name in args[0].split(","):
        root = os.path.join(ROOT, ".sim_output", "autopilot", round_name)
        labels = args[1:] or sorted(d for d in os.listdir(root) if os.path.isdir(os.path.join(root, d)))
        if table:
            print("== %s: reach met/steady/mean m/s | push neutral falls, made good | pushed | matrix falls, not done | lake afternoons falls, beam/broad/mid kt | map, steady 18, steady 24: falls, catapults, not done, beam kt, after-manoeuvre kt" % round_name)
        for label in labels:
            if table:
                print(table_line(round_name, label))
            else:
                summarise(round_name, label)


if __name__ == "__main__":
    main()
