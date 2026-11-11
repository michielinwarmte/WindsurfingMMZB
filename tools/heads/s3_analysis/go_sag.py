"""At the go from a hold: the angle between the bearing to its aim point and the track it made good over the next
SECS seconds (absolute, degrees), for goes that tacked later on the way and for straight goes."""
import csv, json, math, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import go_timing as g
SECS = 6.0
res = {"tacked later": [], "straight": []}
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
            if not got or got[0] != "other" or got[4] or got[5] >= 3.0:
                continue
            p0, aim, p1, other_first, turned = None, None, None, None, False
            for row in csv.DictReader(open(path, encoding="utf-8")):
                t = float(row["race_time_s"])
                if t < got[1]:
                    continue
                if t > s["start_s"]:
                    break
                if p0 is None:
                    p0 = (float(row["x_m"]), float(row["z_m"]))
                    aim = (float(row["aim_x_m"]), float(row["aim_z_m"]))
                    other_first = "other tack" in row["doing"]
                if p1 is None and t >= got[1] + SECS:
                    p1 = (float(row["x_m"]), float(row["z_m"]))
                if "other tack" in row["doing"]:
                    turned = True
                    break
            if p0 is None or p1 is None or other_first:
                continue
            a1 = math.atan2(aim[0] - p0[0], aim[1] - p0[1])
            a2 = math.atan2(p1[0] - p0[0], p1[1] - p0[1])
            d = abs((math.degrees(a2 - a1) + 180.0) % 360.0 - 180.0)
            res["tacked later" if turned else "straight"].append(d)
            if turned and 25 < d < 45 and len(sys.argv) > 0: print("  ", run, r["label"], i, "%.0f" % d, r["drawn"].get("course"), r["drawn"].get("water"))
for k, a in res.items():
    a.sort()
    if a:
        print("%-13s n %4d  off its aim by median %.1f deg (quartiles %.1f to %.1f, 90 %% %.1f)" % (k, len(a), a[len(a)//2], a[len(a)//4], a[3*len(a)//4], a[int(0.9*(len(a)-1))]))
