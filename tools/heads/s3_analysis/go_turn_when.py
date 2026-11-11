"""Of the starts from a hold that tacked or gybed on the way: was the line already on the other tack when it went,
or did that come later (and how long after it went)? Lateness for each."""
import csv, json, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import go_timing as g
at_go, later, later_after = [], [], []
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
            first, t_turn = None, None
            for row in csv.DictReader(open(path, encoding="utf-8")):
                t = float(row["race_time_s"])
                if t < got[1]:
                    continue
                if t > s["start_s"]:
                    break
                if first is None:
                    first = row["doing"]
                if "other tack" in row["doing"]:
                    t_turn = t
                    break
            if t_turn is None:
                continue
            late = got[3] - got[2]
            if "other tack" in (first or ""):
                at_go.append(late)
            else:
                later.append(late)
                later_after.append(t_turn - got[1])
q = lambda a: "n %d, median %.1f (quartiles %.1f to %.1f)" % (len(a), sorted(a)[len(a)//2], sorted(a)[len(a)//4], sorted(a)[3*len(a)//4]) if a else "none"
print("line on the other tack already at the go:", q(at_go))
print("found on the other tack later:          ", q(later))
print("  seconds after the go it found that:     ", q(later_after))
