"""What the board does after a wave crest: reads the matrix CSVs and prints, for each crest
the board passes, the pitch, the pitch rate and the pitch moments in the second after it."""
import csv
import sys
import math

path = sys.argv[1]
t_max = float(sys.argv[2]) if len(sys.argv) > 2 else 1e9
rows = []
with open(path, newline="") as f:
    reader = csv.DictReader(f)
    for r in reader:
        t = float(r["time_s"])
        if t > t_max:
            break
        rows.append({k: (float(v) if v not in ("", "nan") and k not in ("sailor_state", "fall_kind") else v) for k, v in r.items()})

print(f"{path}: {len(rows)} rows, {rows[0]['time_s']:.2f} to {rows[-1]['time_s']:.2f} s")
dt = rows[1]["time_s"] - rows[0]["time_s"]
print(f"row step {dt:.4f} s")

# A crest: the water height under the board at a local maximum, higher than its neighbours over 0.5 s.
half = int(round(0.5 / dt))
crests = []
for i in range(half, len(rows) - half):
    h = rows[i]["water_height_m"]
    if h <= 0.05:
        continue
    window = rows[i - half:i + half + 1]
    if all(h >= w["water_height_m"] for w in window) and h > window[0]["water_height_m"] + 0.02 and h > window[-1]["water_height_m"] + 0.02:
        crests.append(i)

print(f"{len(crests)} crests over 5 cm\n")
cols = ["time_s", "water_height_m", "y", "speed_ms", "pitch_deg", "planing_lift_n", "buoyancy_n", "wetted_length_m",
        "bow_immersion_m", "foot_force_n", "mast_foot_force_n", "pitch_from_mast_foot_nm", "pitch_from_feet_force_nm",
        "pitch_from_feet_moment_nm", "feet_z_m", "hang_back_m", "fin_lift_n", "fin_immersed", "sailor_state"]
short = {"time_s": "t", "water_height_m": "wave", "y": "y", "speed_ms": "v", "pitch_deg": "pitch", "planing_lift_n": "plane",
         "buoyancy_n": "buoy", "wetted_length_m": "wet", "bow_immersion_m": "bow", "foot_force_n": "feet",
         "mast_foot_force_n": "mfoot", "pitch_from_mast_foot_nm": "M_mast", "pitch_from_feet_force_nm": "M_feetF",
         "pitch_from_feet_moment_nm": "M_feetM", "feet_z_m": "feet_z", "hang_back_m": "hang", "fin_lift_n": "fin",
         "fin_immersed": "finIm", "sailor_state": "state"}

def fmt(v):
    if isinstance(v, float):
        return f"{v:8.2f}"
    return f"{str(v):>8}"

shown = 0
for i in crests:
    if shown >= 6:
        break
    t0 = rows[i]["time_s"]
    # pitch before the crest and the lowest pitch within 1.5 s after it
    after = rows[i:i + int(1.5 / dt)]
    before = rows[max(0, i - int(0.5 / dt)):i]
    p_before = max(r["pitch_deg"] for r in before) if before else float("nan")
    p_min = min(after, key=lambda r: r["pitch_deg"])
    print(f"--- crest at t={t0:.2f} s, wave {rows[i]['water_height_m']:.2f} m; pitch {p_before:.1f} -> min {p_min['pitch_deg']:.1f} deg at +{p_min['time_s'] - t0:.2f} s")
    print(" ".join(f"{short[c]:>8}" for c in cols))
    step = max(1, int(round(0.1 / dt)))
    for r in rows[max(0, i - 3 * step):i + 12 * step:step]:
        print(" ".join(fmt(r[c]) for c in cols))
    # the pitch rate in the first 0.3 s after the crest
    r0, r1 = rows[i], rows[min(len(rows) - 1, i + int(0.3 / dt))]
    print(f"pitch rate over the 0.3 s after the crest: {(r1['pitch_deg'] - r0['pitch_deg']) / 0.3:+.1f} deg/s\n")
    shown += 1

# Summary over all crests
drops = []
for i in crests:
    after = rows[i:i + int(1.5 / dt)]
    before = rows[max(0, i - int(0.5 / dt)):i]
    if not after or not before:
        continue
    drops.append(max(r["pitch_deg"] for r in before) - min(r["pitch_deg"] for r in after))
if drops:
    drops.sort()
    print(f"pitch drop from the crest to the trough after it, over {len(drops)} crests: median {drops[len(drops)//2]:.1f}, max {drops[-1]:.1f} deg")
airborne = sum(1 for r in rows if r["planing_lift_n"] < 1.0 and r["buoyancy_n"] < 50.0 and r["speed_ms"] > 5.0)
print(f"rows with the hull out of the water (no planing lift, buoyancy < 50 N) at speed: {airborne} ({airborne * dt:.2f} s)")
