"""The day's "safer at no cost" measure: per board, safe = no fall and not over early at the gun; fixed (unsafe in the
off run, safe in the on run) against broken, one-sided sign test, on the races both runs have.
python -I safe_test.py <off> <on>"""
import json, math, os, sys
SUITE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "..", ".sim_output", "suite")

def load(run):
    d = {}
    for l in open(os.path.join(SUITE, run, "results.jsonl"), encoding="utf-8"):
        if l.strip():
            r = json.loads(l); d[r["label"]] = r
    return d

def unsafe(b):
    return b["falls"] > 0 or bool(b.get("start", {}).get("ocs_at_gun", False))

def sign_p(k, n):
    """One-sided: P(X >= k) for X ~ Binomial(n, 0.5)."""
    return sum(math.comb(n, i) for i in range(k, n + 1)) / 2.0 ** n if n else 1.0

a, b = load(sys.argv[1]), load(sys.argv[2])
fixed = broken = n = 0
for lab in sorted(set(a) & set(b)):
    for x, y in zip(a[lab]["boards"], b[lab]["boards"]):
        n += 1
        if unsafe(x) and not unsafe(y):
            fixed += 1
        elif unsafe(y) and not unsafe(x):
            broken += 1
pf, pb = sign_p(fixed, fixed + broken), sign_p(broken, fixed + broken)
print("%s -> %s: %d boards; falls or over early: fixed %d, broken %d; p %.3f %s (the other way p %.3f%s)" % (
    sys.argv[1], sys.argv[2], n, fixed, broken, pf, "pass" if pf < 0.05 else "chance", pb, ", WORSE" if pb < 0.05 else ""))
