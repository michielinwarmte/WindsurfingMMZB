"""One board's race track read for what it did: the wind angle it held (from its heading and the
wind's direction), how often it changed tack, its speed, and when it passed each step."""
import csv, glob, sys
WIND_FROM_DEG = 270.0  # T1 at 18 kt: the race log says "wind 18 kt from 270 deg"

def twa(heading):
    # The wind angle: positive with the wind from starboard (heading east of the wind's source).
    return (heading - WIND_FROM_DEG + 540.0) % 360.0 - 180.0

for folder in sys.argv[1:]:
    print("==", folder.split("/")[-1])
    for path in sorted(glob.glob(folder + "/*.csv")):
        rows = [r for r in csv.DictReader(open(path)) if float(r["race_time_s"]) >= 0.0]
        if not rows:
            continue
        angles = [twa(float(r["heading_deg"])) for r in rows]
        speeds = [float(r["speed_ms"]) for r in rows]
        bands = {"close-hauled (<60)": 0, "reach (60-120)": 0, "run (>120)": 0}
        for a in angles:
            key = "close-hauled (<60)" if abs(a) < 60 else ("reach (60-120)" if abs(a) < 120 else "run (>120)")
            bands[key] += 1
        tacks = sum(1 for a, b in zip(angles, angles[1:]) if (a > 0) != (b > 0) and abs(a) < 150 and abs(b) < 150)
        gybes = sum(1 for a, b in zip(angles, angles[1:]) if (a > 0) != (b > 0) and (abs(a) >= 150 or abs(b) >= 150))
        n = len(rows)
        steps = {}
        for r in rows:
            s = int(r["next_step"])
            steps.setdefault(s, float(r["race_time_s"]))
        slow = sum(1 for v in speeds if v < 2.0) / n
        print(f"  {path.split('/')[-1]:18s} {rows[-1]['race_time_s']:>6s} s  mean speed {sum(speeds)/n:4.1f} m/s  under 2 m/s {100*slow:3.0f}%  "
              f"tack changes {tacks:3d}  gybe changes {gybes:3d}  " + "  ".join(f"{k} {100*v/n:.0f}%" for k, v in bands.items())
              + "  steps reached at " + ", ".join(f"{s}:{t:.0f}s" for s, t in sorted(steps.items())))
        # The wind angle by minute: its mean of the absolute value and the share on starboard
        by_min = {}
        for r, a in zip(rows, angles):
            m = int(float(r["race_time_s"]) // 60)
            by_min.setdefault(m, []).append(a)
        print("     minute: mean |twa| / starboard share:", "  ".join(f"{m}: {sum(abs(x) for x in v)/len(v):3.0f} / {100*sum(1 for x in v if x > 0)/len(v):3.0f}%" for m, v in sorted(by_min.items())))
