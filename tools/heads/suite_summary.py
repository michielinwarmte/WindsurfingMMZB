#!/usr/bin/env python3
"""A random-suite run in about 20 lines, or two runs side by side (an on/off test, or tune against hold-out).
Read this instead of the logs (the efficient loop, Documentation/AI_TRAINING_METHOD.md):

    python -I tools/heads/suite_summary.py <run>                 one run
    python -I tools/heads/suite_summary.py <run_off> <run_on>    the second against the first, with the differences
    python -I tools/heads/suite_summary.py <run> --failures=5    and the newest failures with their replay commands
    python -I tools/heads/suite_summary.py <run> --wait          first wait until the run has all its races (one line when
                                                                 done: for a background command or a monitor)

Two runs are compared on the races both have (the same race numbers, so the same draws when the --seed and --set match).
"""
import json
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
