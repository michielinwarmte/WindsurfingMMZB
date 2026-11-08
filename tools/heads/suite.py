#!/usr/bin/env python3
"""Scores a run of the skipper's suite (8 November 2026): reads the HEADS_RESULT lines of every log in a
folder made by tools/heads/pool.py and prints a summary and every failure.

    python -I tools/heads/suite.py <folder> [--quiet=1] [--json=<file>]

A case is CLEAN when the board reached its goal (the finish, or the drop's goal step), never ran aground,
never fell and was never stuck (under 1 m/s on the board) for more than STUCK_LIMIT_S at a time. Its cost
(lower is better): the time over the all-rounder's rough expected time (TrainingDrops.expected_leg_s), plus
COST_NOT_REACHED if it did not get there, COST_AGROUND, COST_FALL per fall, COST_STUCK_PER_S per second
stuck, and COST_OCS. A log without a result line is a CRASH and costs COST_CRASH.
"""
import glob
import json
import os
import sys

STUCK_LIMIT_S = 15.0
COST_NOT_REACHED = 3.0
COST_AGROUND = 5.0
COST_FALL = 0.5
COST_STUCK_PER_S = 0.02
COST_OCS = 1.0
COST_CRASH = 8.0


def read_options(argv):
    options, rest = {}, []
    for arg in argv:
        if arg.startswith("--") and "=" in arg:
            key, value = arg[2:].split("=", 1)
            options[key] = value
        else:
            rest.append(arg)
    return options, rest


def read_cases(folder):
    cases = []
    for path in sorted(glob.glob(os.path.join(folder, "*.log"))):
        label = os.path.basename(path)[:-4]
        with open(path, encoding="utf-8", errors="replace") as handle:
            text = handle.read()
        if "HEADS_DONE" not in text:
            continue  # still running
        results = [json.loads(line.split(" ", 1)[1]) for line in text.splitlines() if line.startswith("HEADS_RESULT ")]
        if not results:
            tail = [line for line in text.splitlines() if line.strip() and not line.startswith("   at:")
                    and "Compile Error" not in line and "Compilation failed" not in line][-4:]
            cases.append({"label": label, "crash": True, "tail": " | ".join(tail)[:300]})
            continue
        for r in results:
            r["label"] = label if len(results) == 1 else "%s/%s" % (label, r["board"])
            r["crash"] = False
            cases.append(r)
    return cases


START_LATE_S = 10.0


def judge_start(case):
    """A start (the label begins with start_): crossed within START_LATE_S of the gun, not over early, no
    penalty and no fall in the countdown and the first seconds after the gun."""
    why = []
    splits = case.get("splits", [])
    delay = splits[0] if splits else None
    cost = 0.0
    if delay is None:
        cost += 3.0
        why.append("not started (%s)" % case["note"])
    else:
        cost += delay / START_LATE_S
        if delay > START_LATE_S:
            why.append("started %.0f s late" % delay)
    if case.get("ocs"):
        cost += 2.0
        why.append("OCS")
    if case.get("penalties", 0):
        cost += case["penalties"]
        why.append("%d penalties (%s)" % (case["penalties"], case.get("penalty_note", "")))
    if case["falls"]:
        cost += 0.5 * case["falls"]
        why.append("%d falls (%d before the gun)" % (case["falls"], case.get("falls_before_gun", 0)))
    if case["aground"]:
        cost += 5.0
        why.append("AGROUND " + case["aground_note"])
    case["start_delay"] = delay
    case["clean"] = not why
    case["cost"] = cost
    case["why"] = "; ".join(why)


def judge(case):
    if not case["crash"] and case["label"].startswith("start_"):
        judge_start(case)
        return
    if case["crash"]:
        case["clean"] = False
        case["cost"] = COST_CRASH
        case["why"] = "CRASH " + case["tail"]
        return
    why = []
    expected = max(case.get("expected_s", 0.0), 1.0)
    cost = 0.0
    if case["reached"]:
        cost += case["time_s"] / expected
    else:
        cost += COST_NOT_REACHED + 1.0
        why.append("not reached (step %d of %d, %.0f m to go: %s)" % (case["next_step"], case["goal_step"], case["to_next_m"], case["note"]))
    if case["aground"]:
        cost += COST_AGROUND
        why.append("AGROUND " + case["aground_note"])
    if case["falls"]:
        cost += COST_FALL * case["falls"]
        why.append("%d falls" % case["falls"])
    if case["longest_stuck_s"] > STUCK_LIMIT_S:
        why.append("stuck %.0f s (%s)" % (case["longest_stuck_s"], case["stuck_note"]))
    cost += COST_STUCK_PER_S * case["stuck_s"]
    if case.get("penalties", 0):
        cost += 0.5 * case["penalties"]
        why.append("%d penalties (%s)" % (case["penalties"], case.get("penalty_note", "")))
    if case.get("ocs") and case["drop_step"] == 0:
        cost += COST_OCS
        why.append("OCS")
    case["clean"] = not why
    case["cost"] = cost
    case["why"] = "; ".join(why)


def summary(cases):
    n = len(cases)
    clean = sum(1 for c in cases if c["clean"])
    starts = [c for c in cases if not c["crash"] and c["label"].startswith("start_")]
    races = [c for c in cases if not c["crash"] and c["drop_step"] == 0 and not c["label"].startswith("start_")]
    drops = [c for c in cases if not c["crash"] and c["drop_step"] > 0]
    def ratio(group):
        done = [c["time_s"] / max(c["expected_s"], 1.0) for c in group if c["reached"]]
        return sum(done) / len(done) if done else float("nan")
    return {
        "cases": n, "clean": clean, "cost": sum(c["cost"] for c in cases) / max(n, 1),
        "crashes": sum(1 for c in cases if c["crash"]),
        "aground": sum(1 for c in cases if not c["crash"] and c["aground"]),
        "not_reached": sum(1 for c in cases if not c["crash"] and not c["reached"] and not c["label"].startswith("start_")),
        "falls": sum(c.get("falls", 0) for c in cases if not c["crash"]),
        "stuck": sum(1 for c in cases if not c["crash"] and c["longest_stuck_s"] > STUCK_LIMIT_S),
        "races": len(races), "race_ratio": ratio(races), "drops": len(drops), "drop_ratio": ratio(drops),
        "starts": len(starts), "start_median_s": sorted([c["start_delay"] for c in starts if c["start_delay"] is not None] or [float("nan")])[
            len([c for c in starts if c["start_delay"] is not None]) // 2],
        "start_late": sum(1 for c in starts if c["start_delay"] is None or c["start_delay"] > START_LATE_S),
        "penalties": sum(c.get("penalties", 0) for c in starts),
        "ocs": sum(1 for c in starts if c.get("ocs")),
    }


def main():
    options, rest = read_options(sys.argv[1:])
    folder = rest[0]
    cases = read_cases(folder)
    for case in cases:
        judge(case)
    s = summary(cases)
    print("%s: %d cases, %d clean, cost %.3f | crashes %d, aground %d, not reached %d, falls %d, stuck %d | races %d at %.2f x expected, drops %d at %.2f x" % (
        os.path.basename(os.path.normpath(folder)), s["cases"], s["clean"], s["cost"], s["crashes"], s["aground"], s["not_reached"],
        s["falls"], s["stuck"], s["races"], s["race_ratio"], s["drops"], s["drop_ratio"]))
    if s["starts"]:
        print("  starts: %d boards, median %.1f s after the gun, %d late (> %.0f s), %d OCS, %d penalties" % (
            s["starts"], s["start_median_s"], s["start_late"], START_LATE_S, s["ocs"], s["penalties"]))
    if options.get("quiet", "0") != "1":
        for case in sorted(cases, key=lambda c: -c["cost"]):
            if not case["clean"]:
                extra = "" if case["crash"] else " [%s %s x%s step %d]" % (case["course"], case["time"], case["wind_scale"], case["drop_step"])
                print("  %-34s %5.2f%s %s" % (case["label"], case["cost"], extra, case["why"]))
    if "json" in options:
        with open(options["json"], "w", encoding="utf-8") as handle:
            json.dump({"summary": s, "cases": cases}, handle, indent=1)


if __name__ == "__main__":
    main()
