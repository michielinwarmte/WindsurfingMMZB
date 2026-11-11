"""Every board over early at the gun in the runs: what it was doing just before it went over (counts)."""
import json, os, sys
from collections import Counter
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import over_how as oh
c = Counter(); n = 0; boards = 0
for run in sys.argv[1:]:
    for lab, r in oh.load(run).items():
        for i, b in enumerate(r["boards"]):
            boards += 1
            if oh.over(b):
                n += 1
                got = oh.before_over(os.path.join(oh.SUITE, run, lab, "hana_%d.csv" % (i + 1)))
                key = got[0].split(";")[0].strip() if got else "?"
                if got and got[2] < -100 and False:
                    key = "(started over the line)"
                c[key] += 1
print("%d of %d boards over early" % (n, boards)); print(c.most_common())
