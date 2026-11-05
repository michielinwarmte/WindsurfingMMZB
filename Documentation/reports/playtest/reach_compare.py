"""Two reach-check outputs side by side: the speed, the wet length, the trim, the pitch SD, the
fin's lift and its upward part, case by case, with the change in percent."""
import re
import sys

def parse(path):
    rows = {}
    with open(path, encoding="utf-8", errors="replace") as f:
        for line in f:
            m = re.match(r"\s*(\d+)\s+(\d+)\s+([\d.]+) \(([\d.]+)\)\s+([\d.]+)\s+([\d.]+)\s+([\d.]+)\s+([\d.]+)\s+([\d.-]+)\s+([\d.]+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+([\d.]+)\s+\|\s+([\d.-]+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+([\d.-]+)\s+\|\s+(\S+)", line)
            if m:
                g = m.groups()
                rows[(int(g[0]), int(g[1]))] = {"speed": float(g[2]), "wet": float(g[5]), "trim": float(g[8]), "sd": float(g[9]),
                                                 "fin": float(g[17]), "up": float(g[19]), "status": g[22]}
    return rows

a, b = parse(sys.argv[1]), parse(sys.argv[2])
print(f"{'wind':>4} {'TWA':>4} | {'speed before':>12} {'after':>7} {'%':>6} | {'wet':>5} {'after':>6} | {'trim':>5} {'after':>6} | {'SD':>5} {'after':>6} | {'finN':>5} {'after':>6} | {'upN':>4} {'after':>6} | status")
for key in sorted(a):
    if key not in b:
        continue
    x, y = a[key], b[key]
    pct = 100 * (y["speed"] - x["speed"]) / x["speed"]
    print(f"{key[0]:>4} {key[1]:>4} | {x['speed']:>12.2f} {y['speed']:>7.2f} {pct:>+6.1f} | {x['wet']:>5.2f} {y['wet']:>6.2f} | {x['trim']:>5.2f} {y['trim']:>6.2f} | {x['sd']:>5.2f} {y['sd']:>6.2f} | {x['fin']:>5.0f} {y['fin']:>6.0f} | {x['up']:>4.0f} {y['up']:>6.0f} | {x['status']} -> {y['status']}")
