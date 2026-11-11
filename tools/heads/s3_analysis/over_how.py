"""Boards over early in run B but not in run A (same race and board): what it was doing just before it crossed
the line early (the note without numbers), its speed then, and the clock; counts by what it was doing."""
import csv, json, os, re, sys
from collections import Counter
SUITE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "..", ".sim_output", "suite")

def load(run):
    out = {}
    for line in open(os.path.join(SUITE, run, "results.jsonl"), encoding="utf-8"):
        if line.strip():
            r = json.loads(line); out[r["label"]] = r
    return out

def over(b):
    return bool(b.get("start", {}).get("ocs_at_gun", False))

def _old_over(b):
    return not b["checks"].get("not over early", {"ok": True})["ok"] if "not over early" in b["checks"] else bool(b.get("start", {}).get("ocs") or b.get("start", {}).get("ocs_at_gun"))

def before_over(path):
    """What it was doing just before it last went over the line before the gun (the last entry into going back)."""
    prev, last = None, None
    for row in csv.DictReader(open(path, encoding="utf-8")):
        d = row["doing"]
        if float(row["race_time_s"]) > 1.0:
            break
        is_over = "back behind the line" in d or "OCS" in d
        if is_over and prev is not None and not prev[3]:
            last = prev
        prev = (re.sub(r"\([^)]*\)", "", d).strip(), float(row["speed_ms"]), float(row["race_time_s"]), is_over)
    return last[:3] if last else None


if __name__ != "__main__":
    pass
else:
  a, b = load(sys.argv[1]), load(sys.argv[2])
  c = Counter()
  for lab, rb in sorted(b.items()):
      ra = a.get(lab)
      if not ra:
          continue
      for i, (ba, bb) in enumerate(zip(ra["boards"], rb["boards"])):
          if over(bb) and not over(ba):
              got = before_over(os.path.join(SUITE, sys.argv[2], lab, "hana_%d.csv" % (i + 1)))
              key = got[0] if got else "?"
              c[key] += 1
              print("%s/%d  %s" % (lab, i, ("%-50s v %.1f at %.1f s" % got) if got else "?"))
  print(c.most_common())
