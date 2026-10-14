"""Maloja wind and air statistics from MeteoSwiss station Segl-Maria (SIA).

The numbers in Documentation/PHYSICS_REQUESTS_FROM_MAP.md ("The Maloja, measured") come
from this script. Get the 10-minute data first (about 40 MB, not committed):

    mkdir -p .map_data/raw/meteoswiss
    cd .map_data/raw/meteoswiss
    curl -O https://data.geo.admin.ch/ch.meteoschweiz.ogd-smn/sia/ogd-smn_sia_t_historical_2020-2029.csv
    cd ../../..

Then, from the repo root:

    python tools/map/maloja_stats.py .map_data/raw/meteoswiss/ogd-smn_sia_t_historical_2020-2029.csv

Source: MeteoSwiss Open Government Data (cite "Source: MeteoSwiss").
Timestamps in the OGD files are UTC; Swiss summer time is UTC+2, so the script adds 2 hours.
"""
import csv
import math
import sys
from collections import defaultdict
from datetime import datetime, timedelta

import numpy as np

KT = 1 / 0.514444
RD, RV = 287.05, 461.5


def num(s):
    try:
        return float(s)
    except ValueError:
        return math.nan


rows = []
with open(sys.argv[1], encoding="latin-1") as f:
    r = csv.DictReader(f, delimiter=";")
    for d in r:
        t = datetime.strptime(d["reference_timestamp"], "%d.%m.%Y %H:%M") + timedelta(hours=2)
        if t.month < 6 or t.month > 9:
            continue
        rows.append((t, num(d["fkl010z0"]), num(d["fkl010z1"]), num(d["fkl010z3"]), num(d["dkl010z0"]),
                     num(d["prestas0"]), num(d["tre200s0"]), num(d["pva200s0"])))

print(f"Jun-Sep 10-min rows 2020-2025: {len(rows)}")

# Direction histogram for afternoons with some wind, to find the Maloja sector.
aft = [x for x in rows if 13 <= x[0].hour < 18 and x[1] >= 4 and not math.isnan(x[4])]
hist = np.histogram([x[4] for x in aft], bins=np.arange(0, 361, 15))[0]
print("\nAfternoon (13-18 local) direction histogram, mean >= 4 m/s, 15-deg bins:")
for i, n in enumerate(hist):
    print(f"  {i*15:3d}-{i*15+15:3d}: {n:5d} {'#' * (n // 40)}")
mode = (int(np.argmax(hist)) * 15) + 7.5
lo, hi = mode - 45, mode + 45
print(f"Mode bin centre {mode} deg; Maloja sector taken as {lo:.0f}-{hi:.0f} deg")


def in_sector(d):
    return lo <= d <= hi


# Maloja periods: afternoon, in the sector, mean >= 4 m/s (about 8 kt).
mal = [x for x in aft if in_sector(x[4])]
spd = np.array([x[1] for x in mal]) * KT
g1 = np.array([x[2] / x[1] for x in mal if not math.isnan(x[2])])
g3 = np.array([x[3] / x[1] for x in mal if not math.isnan(x[3])])
dirs = np.array([x[4] for x in mal])
print(f"\nMaloja periods (13-18 local, {lo:.0f}-{hi:.0f} deg, >= 4 m/s): {len(mal)}")
pc = lambda a: " / ".join(f"{v:.2f}" for v in np.nanpercentile(a, [10, 50, 90]))
print(f"  10-min mean speed, kt   p10/p50/p90: {pc(spd)}")
print(f"  1 s gust / mean         p10/p50/p90: {pc(g1)}")
print(f"  3 s gust / mean         p10/p50/p90: {pc(g3)}")
print(f"  direction, deg          p10/p50/p90: {pc(dirs)}")

# Direction change between consecutive 10-min periods inside Maloja spells.
by_t = {x[0]: x for x in mal}
dd = []
for t, x in by_t.items():
    y = by_t.get(t + timedelta(minutes=10))
    if y:
        dd.append(abs((y[4] - x[4] + 180) % 360 - 180))
print(f"  |direction change| per 10 min, deg p50/p90: {np.percentile(dd, 50):.0f} / {np.percentile(dd, 90):.0f}  (n={len(dd)})")

# Maloja days: at least 18 Maloja periods (3 h) between 13 and 18 local.
per_day = defaultdict(int)
for x in mal:
    per_day[x[0].date()] += 1
days = {d for d, n in per_day.items() if n >= 18}
n_days_all = len({x[0].date() for x in rows})
print(f"\nMaloja days (>= 3 h of Maloja between 13 and 18): {len(days)} of {n_days_all} Jun-Sep days ({100*len(days)/n_days_all:.0f} %)")

# Daily cycle on Maloja days: median mean speed and median 1 s gust per hour.
print("  Daily cycle on Maloja days (local time): median mean kt / median 1 s gust kt / share in sector")
hour_s = defaultdict(list)
hour_g = defaultdict(list)
hour_in = defaultdict(list)
for x in rows:
    if x[0].date() in days and 9 <= x[0].hour < 21 and not math.isnan(x[1]):
        hour_s[x[0].hour].append(x[1] * KT)
        if not math.isnan(x[2]):
            hour_g[x[0].hour].append(x[2] * KT)
        hour_in[x[0].hour].append(1 if (not math.isnan(x[4]) and in_sector(x[4])) else 0)
for h in range(9, 21):
    print(f"    {h:02d}:00  {np.median(hour_s[h]):5.1f}  {np.median(hour_g[h]):5.1f}  {100*np.mean(hour_in[h]):4.0f} %")

# Air density in Maloja periods (moist air, station pressure).
rho = []
for x in mal:
    p, T, e = x[5], x[6], x[7]
    if any(math.isnan(v) for v in (p, T, e)):
        continue
    Tk = T + 273.15
    rho.append((p - e) * 100 / (RD * Tk) + e * 100 / (RV * Tk))
rho = np.array(rho)
temps = np.array([x[6] for x in mal if not math.isnan(x[6])])
press = np.array([x[5] for x in mal if not math.isnan(x[5])])
print(f"\nAir in Maloja periods: pressure hPa p10/p50/p90: {pc(press)}; temperature C: {pc(temps)}")
print(f"  air density kg/m3 p10/p50/p90: {pc(rho)}  -> {100*(1-np.median(rho)/1.225):.1f} % below 1.225")
