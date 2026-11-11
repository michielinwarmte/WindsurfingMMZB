"""Measure the skipper's start timing from the night's off arms: at the moment it went (from its hold, or down a
slalom's dive), the time it reckoned it needed to cross (the gun's time left less its spare, from the notes) against
the time it took (its start_s after the gun, less the clock when it went). Per kind of start (slalom / other)."""
import csv
import json
import os
import re
import statistics
import sys

SUITE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "..", ".sim_output", "suite")
SPARE = re.compile(r"\(([+-]\d+\.\d) s to spare\)")


def going(doing):
    return doing.startswith("start: go") or doing.startswith("start: slalom, reaching down")


def board_timing(path, start):
    """(kind, t_go, reckoned_s, taken_s, early_after_go, speed_at_go) or None."""
    rows = []
    with open(path, encoding="utf-8") as f:
        for r in csv.DictReader(f):
            t = float(r["race_time_s"])
            if t > 0.0:
                break
            rows.append((t, r["doing"].replace("; ", ", "), float(r["speed_ms"])))
    # The last stretch of going before the gun (or at it), and the hold row just before it.
    i_go = None
    for i in range(len(rows) - 1, -1, -1):
        if going(rows[i][1]):
            i_go = i
        elif i_go is not None:
            break
    if i_go is None:
        return None
    kind = "slalom" if rows[i_go][1].startswith("start: slalom") else "other"
    t_go = rows[i_go][0]
    early = any(", early" in d for (_t, d, _s) in rows[i_go:])
    reckoned = None
    # The skipper's spare just before it went: hold notes carry it ("+x.x s to spare"); the slalom's waiting
    # notes do not, so for a slalom the go rule is used (it goes when its spare is SLALOM_GO_SPARE_S = 1.0).
    if kind == "other":
        for j in range(i_go - 1, max(i_go - 30, -1), -1):
            m = SPARE.search(rows[j][1])
            if m:
                spare = float(m.group(1))
                reckoned = -rows[j][0] - spare
                break
        if reckoned is None:
            return None
    else:
        reckoned = -t_go - 1.0
    if reckoned <= 0.5:
        return None
    taken = start["start_s"] - t_go
    return kind, t_go, reckoned, taken, early, rows[i_go][2]


def main(runs):
    out = {"slalom": [], "other": []}
    for run in runs:
        for line in open(os.path.join(SUITE, run, "results.jsonl"), encoding="utf-8"):
            if not line.strip():
                continue
            r = json.loads(line)
            for i, b in enumerate(r["boards"]):
                s = b.get("start", {})
                if s.get("ocs") or s.get("ocs_at_gun") or b.get("falls", 0) or s.get("falls_before_gun", 0):
                    continue
                if s.get("start_s") is None or s.get("start_s") > 60:
                    continue
                path = os.path.join(SUITE, run, r["label"], "hana_%d.csv" % (i + 1))
                if not os.path.exists(path):
                    continue
                got = board_timing(path, s)
                if got:
                    out[got[0]].append(got + (s.get("score_m", 0), s.get("cross_speed_ms", 0), r["drawn"].get("water")))
    for kind, rows in out.items():
        if not rows:
            continue
        clean = [x for x in rows if not x[4]]
        ratios = sorted(x[3] / x[2] for x in clean)
        late = sorted(x[3] - x[2] for x in clean)
        q = lambda a, p: a[int(p * (len(a) - 1))]
        print("%s: %d went from a hold (%d held back early after going)" % (kind, len(rows), len(rows) - len(clean)))
        if ratios:
            print("  taken / reckoned (clean): median %.2f, quartiles %.2f to %.2f, 10-90 %% %.2f to %.2f" % (
                q(ratios, 0.5), q(ratios, 0.25), q(ratios, 0.75), q(ratios, 0.1), q(ratios, 0.9)))
            print("  taken - reckoned, s: median %.1f, quartiles %.1f to %.1f" % (q(late, 0.5), q(late, 0.25), q(late, 0.75)))
            rec = sorted(x[2] for x in clean)
            print("  reckoned s: median %.1f, quartiles %.1f to %.1f" % (q(rec, 0.5), q(rec, 0.25), q(rec, 0.75)))
            for water in ("lake", "open"):
                w = sorted(x[3] / x[2] for x in clean if x[8] == water)
                if w:
                    print("  %s: %d, median ratio %.2f" % (water, len(w), q(w, 0.5)))
            # by reckoned time
            for lo, hi in ((0, 5), (5, 10), (10, 20), (20, 99)):
                w = sorted(x[3] / x[2] for x in clean if lo <= x[2] < hi)
                d = sorted(x[3] - x[2] for x in clean if lo <= x[2] < hi)
                if w:
                    print("  reckoned %2d-%2d s: %3d, ratio median %.2f, late by median %.1f s" % (lo, hi, len(w), q(w, 0.5), q(d, 0.5)))
            sp = sorted(x[5] for x in clean)
            print("  speed when it went: median %.1f m/s, quartiles %.1f to %.1f" % (q(sp, 0.5), q(sp, 0.25), q(sp, 0.75)))


if __name__ == "__main__":
    main(sys.argv[1:])


def by_speed(runs):
    import go_timing as g
    out = {"slalom": [], "other": []}
    for run in runs:
        for line in open(os.path.join(SUITE, run, "results.jsonl"), encoding="utf-8"):
            if not line.strip():
                continue
            r = json.loads(line)
            for i, b in enumerate(r["boards"]):
                s = b.get("start", {})
                if s.get("ocs") or s.get("ocs_at_gun") or b.get("falls", 0) or s.get("falls_before_gun", 0):
                    continue
                if s.get("start_s") is None or s.get("start_s") > 60:
                    continue
                path = os.path.join(SUITE, run, r["label"], "hana_%d.csv" % (i + 1))
                got = board_timing(path, s) if os.path.exists(path) else None
                if got and not got[4]:
                    out[got[0]].append((got[5], got[3] - got[2], r["drawn"].get("water"), s.get("score_m", 0)))
    for kind, rows in out.items():
        print(kind)
        for lo, hi in ((0, 1), (1, 2), (2, 3), (3, 5), (5, 20)):
            for water in ("lake", "open"):
                d = sorted(x[1] for x in rows if lo <= x[0] < hi and x[2] == water)
                if len(d) >= 5:
                    print("  went at %d-%d m/s, %s: %3d, late by median %.1f s (quartiles %.1f to %.1f)" % (
                        lo, hi, water, len(d), d[len(d) // 2], d[len(d) // 4], d[3 * len(d) // 4]))
