"""Scores a finished suite run's roundings again with the suite's present measures (random_suite.roundings()), from the
boards' CSV files and the logs it kept, so runs scored before a measure was corrected compare with runs after it.

  python -I tools/heads/rescore.py <run> [--dry]

Writes .sim_output/suite/<run>/results.jsonl anew; the old one is kept beside it as results_before_<time>.jsonl (never
deleted). --dry prints the old and new medians and writes nothing. Refuses a run that is still going (its status.json
lists races running)."""
import json
import os
import re
import shutil
import statistics
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import random_suite as rs  # noqa: E402


def medians(results):
    out = {}
    for key in ("exit_m", "overstand_m", "closest_m"):
        values = [x[key] for r in results for b in r["boards"] for x in b["roundings"] if x[key] is not None]
        out[key] = (statistics.median(values) if values else None, len(values))
    return out


def main(argv):
    run = argv[0]
    dry = "--dry" in argv
    folder = os.path.join(rs.ROOT, ".sim_output", "suite", run)
    status_path = os.path.join(folder, "status.json")
    if not dry and os.path.exists(status_path) and json.load(open(status_path)).get("running"):
        print("%s is still running: rescore it once it is done" % run)
        return 1
    path = os.path.join(folder, "results.jsonl")
    results = [json.loads(line) for line in open(path, encoding="utf-8") if line.strip()]
    before = medians(results)
    for r in results:
        log_path = os.path.join(folder, "logs", r["label"] + ".log")
        if not os.path.exists(log_path):
            continue
        m = re.search(r"^COURSE_JSON (.*)$", open(log_path, encoding="utf-8", errors="replace").read(), re.M)
        if not m:
            continue
        course = json.loads(m.group(1))
        for b in r["boards"]:
            csv_path = os.path.join(folder, r["label"], b["board"].lower().replace(" ", "_") + ".csv")
            if os.path.exists(csv_path):
                b["roundings"] = rs.roundings(rs.read_csv(csv_path), course, course.get("axis_deg", 0.0), r["drawn"].get("water") != "lake")
    after = medians(results)
    for key in before:
        print("%-12s before %s (n %d)  after %s (n %d)" % (key, before[key][0], before[key][1], after[key][0], after[key][1]))
    if dry:
        return 0
    shutil.copy2(path, os.path.join(folder, "results_before_%s.jsonl" % time.strftime("%Y%m%d_%H%M%S")))
    with open(path, "w", encoding="utf-8") as handle:
        for r in results:
            handle.write(json.dumps(r) + "\n")
    print("rescored %d races of %s" % (len(results), run))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
