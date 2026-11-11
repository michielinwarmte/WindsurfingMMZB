"""The night's starts from a hold, late by (taken - reckoned), by the speed it went at and the time it reckoned it
needed, and whether it tacked or gybed on the way ("the line is on the other tack")."""
import csv, json, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import go_timing as g
rows = []
for run in sys.argv[1:]:
    for line in open(os.path.join(g.SUITE, run, "results.jsonl"), encoding="utf-8"):
        if not line.strip():
            continue
        r = json.loads(line)
        for i, b in enumerate(r["boards"]):
            s = b.get("start", {})
            if s.get("ocs") or s.get("ocs_at_gun") or b.get("falls", 0) or s.get("falls_before_gun", 0):
                continue
            if s.get("start_s") is None or s.get("start_s") > 60:
                continue
            path = os.path.join(g.SUITE, run, r["label"], "hana_%d.csv" % (i + 1))
            if not os.path.exists(path):
                continue
            got = g.board_timing(path, s)
            if not got or got[0] != "other" or got[4]:
                continue
            turned = False
            for row in csv.DictReader(open(path, encoding="utf-8")):
                t = float(row["race_time_s"])
                if t >= got[1] and t <= s["start_s"] and "other tack" in row["doing"]:
                    turned = True
                    break
            rows.append((got[5], got[2], got[3] - got[2], turned))
print("all clean goes from a hold:", len(rows), " tacked/gybed on the way:", sum(1 for x in rows if x[3]))
for turned in (False, True):
    print("tacked/gybed on the way" if turned else "straight")
    for slo, shi in ((0, 3), (3, 5), (5, 20)):
        for rlo, rhi in ((0, 6), (6, 12), (12, 99)):
            d = sorted(x[2] for x in rows if x[3] == turned and slo <= x[0] < shi and rlo <= x[1] < rhi)
            if len(d) >= 5:
                print("  went at %d-%d m/s, reckoned %2d-%2d s: %4d, late by median %4.1f s (quartiles %4.1f to %4.1f)" % (
                    slo, shi, rlo, rhi, len(d), d[len(d) // 2], d[len(d) // 4], d[3 * len(d) // 4]))
