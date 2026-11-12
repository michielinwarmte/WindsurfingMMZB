#!/usr/bin/env python3
"""A random-suite run in about 20 lines, or two runs side by side (an on/off test, or tune against hold-out).
Read this instead of the logs (the efficient loop, Documentation/AI_TRAINING_METHOD.md):

    python -I tools/heads/suite_summary.py <run>                 one run
    python -I tools/heads/suite_summary.py <run_off> <run_on>    the second against the first, with the differences
    python -I tools/heads/suite_summary.py <run> --failures=5    and the newest failures with their replay commands
    python -I tools/heads/suite_summary.py <run> --wait          first wait until the run has all its races (one line when
                                                                 done: for a background command or a monitor)

    python -I tools/heads/suite_summary.py <run> --classes       phase S: the late starts by class (water and course kind,
                                                                 course, start place, countdown, R)

Two runs are compared on the races both have (the same race numbers, so the same draws when the --seed and --set match).

Phase S (the starts, Documentation/AI_TRAINING_METHOD.md): two runs are judged race by race. Per measure (the start on
time, never stuck, never aground, no fall, not over early at the gun) a race is fixed (bad in the first run, good in the
second), broken (the other way) or the same; the one-sided sign test says whether the fixed beat the broken by more than
chance ("pass", p under 5 %) or not ("chance"); for the other measures "WORSE" when the broken beat the fixed by that
test. The median seconds after the gun (never over the line counts as endless) may not go up.
Phase S3 (the starts in company, 10 November 2026): every board of a race is judged on its own (race r0007's second
board is r0007/1), with two more measures (no penalty; untangled: at most 5 s within 5 m of another board round the
start), and the start's score (metres up the course 30 s after the gun): per board better or worse by more than 5 m,
with the same sign test ("pass" when the better beat the worse beyond chance, "WORSE" the other way).
From 12 November 2026 (Max: "it's not wrong if they are close together but there is one with dirty wind") a board is
judged on clean wind instead (at most 3 s in another sail's dirty wind from 10 s before the gun to 30 s after it);
untangled is still shown, not judged. A pair is judged only on the measures both runs have (older runs have no dirty
wind numbers).
"""
import json
import math
import os
import statistics
import sys
import time

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SUITE = os.path.join(ROOT, ".sim_output", "suite")
CHECKS = ["start", "stuck", "aground", "finished", "legs", "race_time", "falls"]
LIMITS = {"exit_m": 15.0, "overstand_m": 25.0, "closest_m": 10.0, "extra_turn_deg": 120.0}


def load(run):
    path = os.path.join(SUITE, run, "results.jsonl")
    with open(path, encoding="utf-8") as handle:
        return {r["label"]: r for r in (json.loads(line) for line in handle if line.strip())}


# Phase S's measures per race, each True when good: the start on time, never stuck, never aground, no fall, not over
# early at the gun.
S_MEASURES = ["start", "stuck", "aground", "no fall", "not over early"]
# Phase S3's more: no penalty; clean wind round the start (12 November 2026); and, shown but not judged, not tangled
# up with another board round the start.
S3_MEASURES = S_MEASURES + ["no penalty", "clean wind", "untangled"]
NOT_JUDGED = ("untangled",)
TANGLED_S = 5.0
CLEAN_S = 3.0
# The start's score: a board better or worse by more than this, metres (less is the same start).
SCORE_TIE_M = 5.0
SIGN_LEVEL = 0.05


def sign_test_p(wins, losses):
    """The one-sided sign test: the chance of at least `wins` of wins + losses flips going one way if each way were
    equally likely (a fair coin)."""
    n = wins + losses
    if n == 0:
        return 1.0
    return sum(math.comb(n, k) for k in range(wins, n + 1)) / 2.0 ** n


def is_phase_s(results):
    return any("start" in b for r in results.values() for b in r["boards"])


def is_s3(results):
    return any(r["drawn"].get("phase") == "S3" for r in results.values())


def has_dirty_wind(results):
    return any("dirty_s" in b.get("start", {}) for r in results.values() for b in r["boards"] if b)


def measures_of(results):
    if not is_s3(results):
        return S_MEASURES
    return [m for m in S3_MEASURES if m != "clean wind" or has_dirty_wind(results)]


def units(results):
    """The judged starts: phase S a race's first board (by the race's label), phase S3 every board (label/index)."""
    out = {}
    for label, r in results.items():
        if not r["boards"]:
            out[label] = None
        elif r["drawn"].get("phase") == "S3":
            for i, b in enumerate(r["boards"]):
                out["%s/%d" % (label, i)] = b
        else:
            out[label] = r["boards"][0]
    return out


def board_measures(b):
    """A board's start measures, each True when good."""
    if b is None:
        return {m: False for m in S3_MEASURES}
    st = b.get("start", {})
    return {"start": b["checks"]["start"]["ok"], "stuck": b["checks"]["stuck"]["ok"], "aground": b["checks"]["aground"]["ok"],
            "no fall": b["falls"] == 0, "not over early": not st.get("ocs_at_gun", False),
            "no penalty": st.get("penalties", 0) == 0, "untangled": st.get("near_s", 0.0) <= TANGLED_S,
            "clean wind": st.get("dirty_s", 0.0) <= CLEAN_S}


def s_measures(race):
    """A phase S race's measures (its first board's), each True when good."""
    return board_measures(race["boards"][0] if race["boards"] else None)


def board_start_s(b):
    """Seconds after the gun it crossed the line; endless when it never did."""
    value = b.get("start", {}).get("start_s") if b else None
    return value if value is not None else float("inf")


def start_s(race):
    """A phase S race's first board: seconds after the gun it crossed the line; endless when it never did."""
    return board_start_s(race["boards"][0] if race["boards"] else None)


def board_score(b):
    """The start's score, metres up the course 30 s after the gun (None: not measured)."""
    return b.get("start", {}).get("score_m") if b else None


def s_numbers(results):
    races = list(results.values())
    boards = list(units(results).values())
    measures = measures_of(results)
    out = {"races": len(races), "boards": len(boards)}
    for m in measures:
        out[m + " %"] = 100.0 * sum(board_measures(b)[m] for b in boards) / max(len(boards), 1)
    out["start median s"] = statistics.median([board_start_s(b) for b in boards]) if boards else float("nan")
    starts = [b["start"] for b in boards if b]
    speeds = [st["gun_speed_ms"] for st in starts if st["gun_speed_ms"] >= 0.0]
    out["gun speed median"] = statistics.median(speeds) if speeds else float("nan")
    behind = [st["gun_behind_m"] for st in starts]
    out["gun behind median m"] = statistics.median(behind) if behind else float("nan")
    if is_s3(results):
        scores = [board_score(b) for b in boards if board_score(b) is not None]
        out["score median m"] = statistics.median(scores) if scores else float("nan")
        out["score mean m"] = statistics.fmean(scores) if scores else float("nan")
        crossing = [st.get("cross_speed_ms", -1.0) for st in starts if st.get("cross_speed_ms", -1.0) >= 0.0]
        out["cross speed median"] = statistics.median(crossing) if crossing else float("nan")
        out["near s mean"] = statistics.fmean([st.get("near_s", 0.0) for st in starts]) if starts else float("nan")
        if has_dirty_wind(results):
            out["dirty s mean"] = statistics.fmean([st.get("dirty_s", 0.0) for st in starts]) if starts else float("nan")
            out["wind lost s mean"] = statistics.fmean([st.get("wind_lost_s", 0.0) for st in starts]) if starts else float("nan")
        out["penalties"] = sum(st.get("penalties", 0) for st in starts)
        felt = [st["gun_felt_60s_kt"] / st["gun_mean_kt"] for st in starts if st.get("gun_felt_60s_kt") and st.get("gun_mean_kt")]
        out["felt/mean wind"] = statistics.median(felt) if felt else float("nan")
    return out


def s_flips(off, on):
    """Per measure: the starts fixed and broken going from `off` to `on` (the labels)."""
    a_units, b_units = units(off), units(on)
    measures = [m for m in measures_of(on) if m in measures_of(off)]
    flips = {m: ([], []) for m in measures}
    for label in sorted(set(a_units) & set(b_units)):
        a, b = board_measures(a_units[label]), board_measures(b_units[label])
        for m in measures:
            if not a[m] and b[m]:
                flips[m][0].append(label)
            elif a[m] and not b[m]:
                flips[m][1].append(label)
    return flips


def score_flips(off, on):
    """The start's score per board: the labels better and worse by more than SCORE_TIE_M, and every (difference,
    label)."""
    a_units, b_units = units(off), units(on)
    better, worse, diffs = [], [], []
    for label in sorted(set(a_units) & set(b_units)):
        a, b = board_score(a_units[label]), board_score(b_units[label])
        if a is None or b is None:
            continue
        diffs.append((b - a, label))
        if b - a > SCORE_TIE_M:
            better.append(label)
        elif a - b > SCORE_TIE_M:
            worse.append(label)
    return better, worse, diffs


def s_verdict(measure, fixed, broken):
    """The sign test's verdict for one measure: for the start "pass" (fixed beat broken beyond chance), "chance" or
    "no gain"; for the others "WORSE" (broken beat fixed beyond chance) or "ok"."""
    if measure in NOT_JUDGED:
        return sign_test_p(broken, fixed), "not judged"
    if measure == "start":
        p = sign_test_p(fixed, broken)
        if fixed <= broken:
            return p, "no gain"
        return p, "pass" if p < SIGN_LEVEL else "chance"
    p = sign_test_p(broken, fixed)
    return p, "WORSE" if p < SIGN_LEVEL else "ok"


def s_main(runs, data, flags):
    nums = [s_numbers(d) for d in data]
    for key in nums[0]:
        vals = [n[key] for n in nums]
        print("%-22s" % key + "".join("%10.1f" % v for v in vals) + ("   %+8.1f" % (vals[1] - vals[0]) if len(vals) == 2 else ""))
    if len(data) == 2:
        flips = s_flips(data[0], data[1])
        print("\nrace by race (fixed / broken, one-sided sign test):")
        for m in flips:
            fixed, broken = flips[m]
            p, verdict = s_verdict(m, len(fixed), len(broken))
            print("  %-16s fixed %3d  broken %3d   p %.3f  %s" % (m, len(fixed), len(broken), p, verdict))
        med = [n["start median s"] for n in nums]
        print("  %-16s %.1f -> %.1f s  %s" % ("median after gun", med[0], med[1], "WORSE" if med[1] > med[0] else "ok"))
        print("  start fixed:  %s" % (" ".join(flips["start"][0]) or "-"))
        print("  start broken: %s" % (" ".join(flips["start"][1]) or "-"))
        for m in list(flips)[1:]:
            if flips[m][1]:
                print("  %s broken: %s" % (m, " ".join(flips[m][1])))
        if is_s3(data[1]):
            better, worse, diffs = score_flips(data[0], data[1])
            p = sign_test_p(len(better), len(worse))
            verdict = ("pass" if p < SIGN_LEVEL else "chance") if len(better) > len(worse) else (
                "WORSE" if sign_test_p(len(worse), len(better)) < SIGN_LEVEL else "no gain")
            changes = [d for d, _ in diffs]
            print("\nthe start's score, board by board (better / worse by more than %.0f m):" % SCORE_TIE_M)
            print("  better %3d  worse %3d   p %.3f  %s;  mean change %+.1f m, median %+.1f m" % (
                len(better), len(worse), p, verdict, statistics.fmean(changes) if changes else 0.0,
                statistics.median(changes) if changes else 0.0))
            print("  most worse: %s" % " ".join("%s %+.0f" % (l, d) for d, l in sorted(diffs)[:6] if d < -SCORE_TIE_M))
            print("  most better: %s" % " ".join("%s %+.0f" % (l, d) for d, l in sorted(diffs, reverse=True)[:6] if d > SCORE_TIE_M))
    if "classes" in flags:
        print_classes(data[-1])
    if "failures" in flags:
        late = [(label, b) for label, b in units(data[-1]).items() if not board_measures(b)["start"]][-int(flags["failures"]):]
        for label, b in late:
            r = data[-1][label.split("/")[0]]
            print("\n%s %s %s\n  %s\n  %s" % (label, b["board"] if b else "-", json.dumps(r["drawn"]), json.dumps(b.get("start") if b else None), r.get("replay", "")))


def course_of(drawn):
    kind = drawn.get("course_kind")
    course = drawn.get("course", "?")
    if kind in ("saved", "shifted"):
        return course.split(" ")[0]
    if kind == "new":
        return "new " + course.split(" ")[1]
    return course.split(" ")[0]


def print_classes(results):
    """The late starts by class, the biggest first."""
    races = list(results.values())
    classes = {
        "water / course kind": lambda d: "%s / %s" % (d.get("water"), d.get("course_kind")),
        "course": course_of,
        "start place": lambda d: d.get("start", "?"),
        "countdown": lambda d: "%d s" % d.get("countdown_s", 0),
        "R": lambda d: d.get("restart", "-").split(" ")[0] if d.get("restart", "-") != "-" else "no R",
    }
    for name, key_of in classes.items():
        groups = {}
        for label, b in units(results).items():
            r = results[label.split("/")[0]]
            g = groups.setdefault(key_of(r["drawn"]), [0, 0])
            g[0] += 1
            g[1] += 0 if board_measures(b)["start"] else 1
        print("\nlate starts by %s:" % name)
        for k, (n, late) in sorted(groups.items(), key=lambda kv: (-kv[1][1], -kv[1][0])):
            print("  %-26s %3d late of %3d  (%3.0f %%)" % (k, late, n, 100.0 * late / n))


def numbers(results):
    """The run's numbers: the pass rates, the roundings' medians and shares over the limits, falls, the legs' ratio."""
    races = list(results.values())
    boards = [b for r in races for b in r["boards"]]
    out = {"races": len(races), "pass": 100.0 * sum(r["pass"] for r in races) / max(len(races), 1)}
    for check in CHECKS:
        vals = [b["checks"][check]["ok"] for b in boards if check in b["checks"]]
        out["check " + check] = 100.0 * sum(vals) / len(vals) if vals else float("nan")
    rounds = [x for b in boards for x in b["roundings"]]
    for key, limit in LIMITS.items():
        vals = [x[key] for x in rounds if x.get(key) is not None]
        out[key + " median"] = statistics.median(vals) if vals else float("nan")
        out[key + " over %"] = 100.0 * sum(v > limit for v in vals) / len(vals) if vals else float("nan")
    out["roundings"] = len(rounds)
    out["falls per race"] = sum(b["falls"] for b in boards) / max(len(races), 1)
    ratios = [lg["ratio"] for b in boards for lg in b["legs"]]
    out["leg/expected median"] = statistics.median(ratios) if ratios else float("nan")
    return out


# For each number: which way is better (+1 higher, -1 lower).
BETTER = {"pass": 1, "falls per race": -1, "leg/expected median": -1}
for check in CHECKS:
    BETTER["check " + check] = 1
for key in LIMITS:
    BETTER[key + " median"] = -1
    BETTER[key + " over %"] = -1


def wait(run):
    status = os.path.join(SUITE, run, "status.json")
    while True:
        try:
            with open(status, encoding="utf-8") as handle:
                s = json.load(handle)
            if s["done"] >= s["count"] and not s["running"]:
                return
        except (OSError, ValueError, KeyError):
            pass
        time.sleep(60)


def main(argv):
    runs = [a for a in argv if not a.startswith("--")]
    flags = dict(a[2:].split("=", 1) if "=" in a else (a[2:], "1") for a in argv if a.startswith("--"))
    if "wait" in flags:
        for run in runs:
            wait(run)
    data = [load(run) for run in runs]
    if len(data) == 2:
        common = sorted(set(data[0]) & set(data[1]))
        data = [{k: d[k] for k in common} for d in data]
        print("%s against %s, on the %d races both have" % (runs[1], runs[0], len(common)))
    if data and all(is_phase_s(d) for d in data):
        s_main(runs, data, flags)
        return
    nums = [numbers(d) for d in data]
    keys = ["races", "pass"] + ["check " + c for c in CHECKS] + ["roundings"] + [k + s for k in LIMITS for s in (" median", " over %")] + ["falls per race", "leg/expected median"]
    for key in keys:
        vals = [n[key] for n in nums]
        line = "%-24s" % key + "".join("%10.1f" % v for v in vals)
        if len(vals) == 2 and key in BETTER and vals[0] == vals[0] and vals[1] == vals[1]:
            diff = vals[1] - vals[0]
            verdict = "better" if diff * BETTER[key] > 0 else ("worse" if diff * BETTER[key] < 0 else "same")
            line += "   %+8.1f  %s" % (diff, verdict if abs(diff) > 1e-9 else "same")
        print(line)
    if "failures" in flags:
        newest = [r for r in data[-1].values() if not r["pass"]][-int(flags["failures"]):]
        for r in newest:
            what = "; ".join("%s: %s" % (k, c["what"]) for b in r["boards"] for k, c in b["checks"].items() if not c["ok"])
            print("\n%s %s\n  %s\n  %s" % (r["label"], json.dumps(r["drawn"]), what, r.get("replay", "")))


if __name__ == "__main__":
    main(sys.argv[1:])
