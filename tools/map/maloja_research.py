"""How the Maloja behaves once it blows: statistics from five MeteoSwiss stations along its path.

Documentation/MALOJA_WIND_RESEARCH.md explains every number this prints. Get the data first
(about 0.4 GB, not committed), then run from the repo root:

    python tools/map/download.py wind-valley
    python tools/map/maloja_research.py

It prints the tables and writes the key numbers to .map_data/work/wind_research/results.json,
which tools/map/maloja_charts.py turns into the pictures in Documentation/images/maloja/.

The stations (silvaplana_area.VALLEY_STATIONS):
    vio  Vicosoprano, down in Val Bregaglia, where the wind starts
    sia  Segl-Maria, at the south-west end of the lake: the reference
    cov  Piz Corvatsch, 3294 m: the wind above the valley ("upper wind")
    sam  Samedan, 11 km further down the valley
    biv  Bivio, behind the Julier pass

Source: MeteoSwiss Open Government Data (cite "Source: MeteoSwiss"). Timestamps in the files are
UTC; May to September is all Swiss summer time (UTC+2), so the script adds 2 hours.
"""
import csv
import json
import math
import warnings
from datetime import date, datetime, timedelta
from pathlib import Path

import numpy as np

import silvaplana_area as area

KT = 1 / 0.514444  # knots per m/s
SLOTS = 144  # 10-minute slots in a day
FIRST_YEAR = 2014  # Segl-Maria measures wind speed since March 2014
MONTHS = (5, 6, 7, 8, 9, 10)  # loaded; the statistics use June to September unless they say so
SUMMER = (6, 7, 8, 9)
# Stations on the valley floor along the Maloja's path, where a start and an end make sense.
# On Piz Corvatsch and in Bivio the afternoon wind is a different wind.
ONSET_STATIONS = ("vio", "sia", "sam")
# Station positions, LV95 east and north in metres (MeteoSwiss station list, ogd-smn_meta_stations.csv).
STATION_LV95 = {
    "vio": (2_768_487.0, 1_135_866.0),
    "sia": (2_778_576.0, 1_144_976.0),
    "cov": (2_783_156.0, 1_143_524.0),
    "sam": (2_787_251.0, 1_155_685.0),
    "biv": (2_771_283.0, 1_148_119.0),
}


def distance_km(a: str, b: str) -> float:
    (east_a, north_a), (east_b, north_b) = STATION_LV95[a], STATION_LV95[b]
    return math.hypot(east_b - east_a, north_b - north_a) / 1000.0

# The Maloja at Segl-Maria (same definition as maloja_stats.py, so the numbers can be compared):
# from 202 to 292 degrees, at least 4 m/s, and a "Maloja day" has at least 3 hours of it
# between 13:00 and 18:00 local time.
SECTOR_DEG = (202.0, 292.0)
MIN_SPEED_MS = 4.0
MIN_SLOTS_PER_DAY = 18

OUT_DIR = area.WORK_DIR / "wind_research"
COLUMNS = {
    "mean": "fkl010z0",  # 10-minute mean speed, m/s
    "gust1": "fkl010z1",  # strongest 1-second gust in the 10 minutes, m/s
    "gust3": "fkl010z3",  # strongest 3-second gust in the 10 minutes, m/s
    "dir": "dkl010z0",  # 10-minute mean direction the wind comes from, degrees
    "temp": "tre200s0",  # air temperature 2 m above the ground, C
    "sun": "gre000z0",  # global radiation, W/m2
}


# ---------------------------------------------------------------- reading the data

def station_files(station: str) -> list[Path]:
    folder = area.RAW_DIR / "meteoswiss"
    names = [f"ogd-smn_{station}_t_historical_2010-2019.csv", f"ogd-smn_{station}_t_historical_2020-2029.csv",
             f"ogd-smn_{station}_t_recent.csv"]
    files = [folder / name for name in names if (folder / name).exists()]
    if not files:
        raise SystemExit(f"No data for station {station}: run python tools/map/download.py wind-valley first.")
    return files


def number(text: str) -> float:
    try:
        return float(text)
    except ValueError:
        return math.nan


def load_station(station: str, days: list[date]) -> dict[str, np.ndarray]:
    """One array per measurement, shaped (day, 10-minute slot), local time, NaN where missing."""
    day_index = {d: i for i, d in enumerate(days)}
    data = {name: np.full((len(days), SLOTS), np.nan) for name in COLUMNS}
    for path in station_files(station):
        with open(path, encoding="latin-1") as f:
            for row in csv.DictReader(f, delimiter=";"):
                t = datetime.strptime(row["reference_timestamp"], "%d.%m.%Y %H:%M") + timedelta(hours=2)
                i = day_index.get(t.date())
                if i is None:
                    continue
                slot = (t.hour * 60 + t.minute) // 10
                for name, column in COLUMNS.items():
                    if column in row:
                        data[name][i, slot] = number(row[column])
    return data


# ---------------------------------------------------------------- small helpers

def slot_of(hour: float) -> int:
    return int(round(hour * 6))


def clock(slot: float) -> str:
    minutes = int(round(slot * 10))
    return f"{minutes // 60:02d}:{minutes % 60:02d}"


def angle_diff(a: np.ndarray, b: np.ndarray | float) -> np.ndarray:
    """a minus b in degrees, between -180 and 180. Positive: a is turned clockwise (veered)."""
    return (np.asarray(a) - b + 180.0) % 360.0 - 180.0


def circular_mean(degrees: np.ndarray) -> float:
    rad = np.deg2rad(degrees[np.isfinite(degrees)])
    if rad.size == 0:
        return math.nan
    return float(np.rad2deg(math.atan2(np.mean(np.sin(rad)), np.mean(np.cos(rad)))) % 360.0)


def pct(values, q=(10, 50, 90)) -> list[float]:
    values = np.asarray(values, dtype=float)
    values = values[np.isfinite(values)]
    if values.size == 0:
        return [math.nan] * len(q)
    return [float(v) for v in np.percentile(values, q)]


def fmt(values, digits=1) -> str:
    return " / ".join(f"{v:.{digits}f}" for v in values)


def in_sector(directions: np.ndarray, lo: float, hi: float) -> np.ndarray:
    with np.errstate(invalid="ignore"):
        return (directions >= lo) & (directions <= hi)


def autocorrelation(series_per_day: np.ndarray, max_lag: int) -> list[float]:
    """Correlation of a (day, slot) series with itself max_lag slots later, within each day,
    using only pairs where both values exist."""
    result = []
    for lag in range(1, max_lag + 1):
        a = series_per_day[:, :-lag].ravel()
        b = series_per_day[:, lag:].ravel()
        ok = np.isfinite(a) & np.isfinite(b)
        result.append(float(np.corrcoef(a[ok], b[ok])[0, 1]) if ok.sum() > 50 else math.nan)
    return result


# ---------------------------------------------------------------- the analyses

def maloja_days(sia: dict[str, np.ndarray], days: list[date]) -> np.ndarray:
    """True for every summer day with at least 3 hours of Maloja at Segl-Maria between 13 and 18."""
    afternoon = slice(slot_of(13), slot_of(18))
    with np.errstate(invalid="ignore"):
        maloja = in_sector(sia["dir"], *SECTOR_DEG) & (sia["mean"] >= MIN_SPEED_MS)
    count = maloja[:, afternoon].sum(axis=1)
    summer = np.array([d.month in SUMMER for d in days])
    return summer & (count >= MIN_SLOTS_PER_DAY)


def station_sector(data: dict[str, np.ndarray], mday: np.ndarray) -> tuple[float, float, float]:
    """The direction a station's afternoon wind comes from on Maloja days (13 to 17), and the
    +-45 degree sector around it."""
    afternoon = slice(slot_of(13), slot_of(17))
    dirs = data["dir"][mday, afternoon]
    speeds = data["mean"][mday, afternoon]
    with np.errstate(invalid="ignore"):
        windy = dirs[speeds >= 2.0]
    hist = np.histogram(windy[np.isfinite(windy)], bins=np.arange(0, 361, 15))[0]
    mode = int(np.argmax(hist)) * 15 + 7.5
    return mode, (mode - 45) % 360, (mode + 45) % 360


def sector_mask(directions: np.ndarray, lo: float, hi: float) -> np.ndarray:
    with np.errstate(invalid="ignore"):
        if lo <= hi:
            return (directions >= lo) & (directions <= hi)
        return (directions >= lo) | (directions <= hi)


def daily_cycle(data: dict[str, np.ndarray], mday: np.ndarray, lo: float, hi: float) -> list[dict]:
    """Per hour on Maloja days: median mean speed and 1 s gust (kt), the wind direction, and the
    share of the hour the station's wind is in its Maloja-time sector."""
    hours = []
    for h in range(6, 24):
        cols = slice(slot_of(h), slot_of(h + 1))
        mean = data["mean"][mday, cols]
        gust = data["gust1"][mday, cols]
        dirs = data["dir"][mday, cols]
        valid = np.isfinite(dirs)
        share = float(sector_mask(dirs, lo, hi)[valid].mean()) if valid.any() else math.nan
        hours.append({
            "hour": h,
            "mean_kt": float(np.nanmedian(mean) * KT),
            "mean_p25_kt": float(np.nanpercentile(mean, 25) * KT),
            "mean_p75_kt": float(np.nanpercentile(mean, 75) * KT),
            "gust1_kt": float(np.nanmedian(gust) * KT),
            "dir_deg": circular_mean(dirs[sector_mask(dirs, lo, hi)]),
            "share_in_sector": share,
        })
    return hours


def onset_and_end(data: dict[str, np.ndarray], mday_rows: np.ndarray, lo: float, hi: float
                  ) -> tuple[np.ndarray, np.ndarray]:
    """Per Maloja day: the first slot from 07:00 where the station's wind is in its sector and at
    least half its own afternoon median (and 2 m/s) for 30 minutes in a row, and the last such
    slot before midnight. NaN when not found."""
    onsets = np.full(len(mday_rows), np.nan)
    ends = np.full(len(mday_rows), np.nan)
    afternoon = slice(slot_of(13), slot_of(17))
    for k, row in enumerate(mday_rows):
        mean = data["mean"][row]
        reference = np.nanmedian(mean[afternoon])
        if not np.isfinite(reference):
            continue
        with np.errstate(invalid="ignore"):
            on = sector_mask(data["dir"][row], lo, hi) & (mean >= max(0.5 * reference, 2.0))
        run = on[:-2] & on[1:-1] & on[2:]  # 30 minutes in a row
        candidates = np.nonzero(run[slot_of(7):])[0]
        if candidates.size:
            onsets[k] = candidates[0] + slot_of(7)
            ends[k] = np.nonzero(run)[0][-1] + 2
    return onsets, ends


def onset_jump(sia: dict[str, np.ndarray], mday_rows: np.ndarray, onsets: np.ndarray) -> dict:
    """How suddenly it starts: speed and temperature before and after the onset at Segl-Maria."""
    before, after, rise_minutes, temp_change = [], [], [], []
    for row, onset in zip(mday_rows, onsets):
        if not np.isfinite(onset) or onset < 6 or onset > SLOTS - 10:
            continue
        s = int(onset)
        mean = sia["mean"][row]
        b = np.nanmean(mean[s - 3:s])
        a = np.nanmean(mean[s:s + 3])
        before.append(b)
        after.append(a)
        # Minutes from the onset until the 10-minute mean first reaches 80 % of the afternoon median.
        target = 0.8 * np.nanmedian(mean[slot_of(13):slot_of(17)])
        reached = np.nonzero(mean[s:] >= target)[0]
        if reached.size:
            rise_minutes.append(reached[0] * 10)
        temp = sia["temp"][row]
        temp_change.append(np.nanmean(temp[s + 3:s + 6]) - np.nanmean(temp[s - 3:s]))
    return {
        "speed_30min_before_kt": pct(np.array(before) * KT),
        "speed_30min_after_kt": pct(np.array(after) * KT),
        "minutes_to_80pct_of_afternoon": pct(rise_minutes),
        "temperature_change_C": pct(temp_change),
    }


def gust_factors(data: dict[str, np.ndarray], maloja: np.ndarray) -> dict:
    """Gust factors (strongest gust / 10-minute mean) in Maloja periods."""
    mean = data["mean"][maloja]
    g1 = data["gust1"][maloja] / mean
    g3 = data["gust3"][maloja] / mean
    # How much of a 1 s gust is still there over 3 s: near 1 means gusts last well over 3 seconds.
    keep = (data["gust3"][maloja] - mean) / (data["gust1"][maloja] - mean)
    by_speed = []
    for lo_kt, hi_kt in ((8, 10), (10, 12), (12, 14), (14, 16), (16, 20), (20, 30)):
        with np.errstate(invalid="ignore"):
            sel = (mean * KT >= lo_kt) & (mean * KT < hi_kt)
        if sel.sum() > 30:
            excess_kt = (data["gust1"][maloja] - mean)[sel] * KT
            by_speed.append({"from_kt": lo_kt, "to_kt": hi_kt, "n": int(sel.sum()), "gust1_factor": pct(g1[sel]),
                             "gust1_excess_kt": pct(excess_kt)})
    return {"n": int(np.isfinite(g1).sum()), "gust1_factor": pct(g1), "gust3_factor": pct(g3),
            "gust3_over_gust1_excess": pct(keep), "by_speed": by_speed}


def gust_factor_by_hour(data: dict[str, np.ndarray], mday: np.ndarray, lo: float, hi: float) -> list[dict]:
    rows = []
    for h in range(10, 21):
        cols = slice(slot_of(h), slot_of(h + 1))
        mean = data["mean"][mday, cols]
        with np.errstate(invalid="ignore"):
            ok = sector_mask(data["dir"][mday, cols], lo, hi) & (mean >= 3.0)
        g1 = (data["gust1"][mday, cols] / mean)[ok]
        rows.append({"hour": h, "gust1_factor": pct(g1)})
    return rows


def direction_behaviour(sia: dict[str, np.ndarray], mday: np.ndarray) -> dict:
    """The 10-minute direction at Segl-Maria in the afternoon of Maloja days, against that day's
    afternoon average: how far it swings, how long a swing lasts, and whether stronger wind comes
    from further right or left."""
    cols = slice(slot_of(13), slot_of(18))
    dirs = sia["dir"][mday, cols].copy()
    speed = sia["mean"][mday, cols].copy()
    with np.errstate(invalid="ignore"):
        maloja = in_sector(dirs, *SECTOR_DEG) & (speed >= MIN_SPEED_MS)
    dirs[~maloja] = np.nan
    speed[~maloja] = np.nan
    day_dir = np.array([circular_mean(d) for d in dirs])
    anomaly = angle_diff(dirs, day_dir[:, None])
    speed_anomaly = (speed - np.nanmean(speed, axis=1, keepdims=True)) * KT
    ok = np.isfinite(anomaly) & np.isfinite(speed_anomaly)
    slope = float(np.polyfit(speed_anomaly[ok], anomaly[ok], 1)[0])
    corr = float(np.corrcoef(speed_anomaly[ok], anomaly[ok])[0, 1])
    # Direction swing within one hour (max minus min of six 10-minute means), and the change
    # from one 10-minute period to the next.
    swings = []
    for d in range(anomaly.shape[0]):
        for start in range(0, anomaly.shape[1] - 5, 6):
            window = anomaly[d, start:start + 6]
            if np.isfinite(window).all():
                swings.append(window.max() - window.min())
    steps = np.abs(angle_diff(dirs[:, 1:], dirs[:, :-1]))
    # Does the direction drift through the afternoon? Average anomaly per hour.
    drift = []
    for h in range(13, 18):
        c = slice(slot_of(h) - slot_of(13), slot_of(h + 1) - slot_of(13))
        drift.append({"hour": h, "mean_offset_deg": float(np.nanmean(anomaly[:, c]))})
    return {
        "day_direction_deg": pct(day_dir),
        "offset_from_day_mean_deg": pct(anomaly, (5, 10, 25, 50, 75, 90, 95)),
        "offset_std_deg": float(np.nanstd(anomaly)),
        "change_per_10min_deg": pct(steps, (50, 75, 90, 95)),
        "swing_within_an_hour_deg": pct(swings, (25, 50, 75, 90)),
        "autocorrelation_per_10min": autocorrelation(anomaly, 9),
        "deg_per_kt_stronger": slope,
        "speed_direction_correlation": corr,
        "drift_by_hour": drift,
    }


def speed_behaviour(sia: dict[str, np.ndarray], mday: np.ndarray) -> dict:
    """The 10-minute mean speed in the afternoon against the day's afternoon mean: how strong the
    stronger and weaker spells are, and how long they last."""
    cols = slice(slot_of(13), slot_of(18))
    speed = sia["mean"][mday, cols].copy()
    with np.errstate(invalid="ignore"):
        maloja = in_sector(sia["dir"][mday, cols], *SECTOR_DEG) & (speed >= MIN_SPEED_MS)
    speed[~maloja] = np.nan
    ratio = speed / np.nanmean(speed, axis=1, keepdims=True)
    anomaly = speed - np.nanmean(speed, axis=1, keepdims=True)
    return {
        "ratio_to_day_mean": pct(ratio, (5, 10, 25, 50, 75, 90, 95)),
        "autocorrelation_per_10min": autocorrelation(anomaly, 9),
    }


def day_types(sia: dict, cov: dict, sam: dict, mday: np.ndarray, sia_onset: np.ndarray, sam_share: np.ndarray
              ) -> dict:
    """Maloja days split into light, medium and strong thirds by the afternoon mean at Segl-Maria,
    with what goes with them: gustiness, direction, start time, and the upper wind on Corvatsch."""
    cols = slice(slot_of(13), slot_of(17))
    rows = np.nonzero(mday)[0]
    strength = np.nanmedian(sia["mean"][rows, cols], axis=1) * KT
    g1 = np.nanmedian(sia["gust1"][rows, cols] / sia["mean"][rows, cols], axis=1)
    peak_gust = np.nanmax(sia["gust1"][rows, cols], axis=1) * KT
    direction = np.array([circular_mean(sia["dir"][r, cols]) for r in rows])
    upper_cols = slice(slot_of(12), slot_of(15))
    upper_speed = np.nanmean(cov["mean"][rows, upper_cols], axis=1) * KT
    upper_dir = np.array([circular_mean(cov["dir"][r, upper_cols]) for r in rows])
    edges = np.nanpercentile(strength, [33.3, 66.7])
    types = []
    for name, sel in (("light", strength < edges[0]),
                      ("medium", (strength >= edges[0]) & (strength < edges[1])),
                      ("strong", strength >= edges[1])):
        types.append({
            "type": name, "days": int(sel.sum()),
            "afternoon_mean_kt": pct(strength[sel]),
            "strongest_gust_13_17_kt": pct(peak_gust[sel]),
            "gust1_factor": pct(g1[sel]),
            "direction_deg": circular_mean(direction[sel]),
            "onset": [clock(v) for v in pct(sia_onset[sel])],
            "upper_wind_kt": pct(upper_speed[sel]),
            "upper_wind_from_deg": circular_mean(upper_dir[sel]),
            "share_reaching_samedan": float(np.nanmean(sam_share[sel] >= 0.5)),
        })
    # Strength by the upper wind's direction (Corvatsch 12 to 15).
    by_upper = []
    names = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
    for k, name in enumerate(names):
        centre = k * 45.0
        with np.errstate(invalid="ignore"):
            sel = np.abs(angle_diff(upper_dir, centre)) < 22.5
        if sel.sum() >= 10:
            by_upper.append({"upper_from": name, "days": int(sel.sum()), "afternoon_mean_kt": pct(strength[sel]),
                             "gust1_factor": pct(g1[sel]), "direction_deg": circular_mean(direction[sel])})
    corr_upper_speed = float(np.corrcoef(upper_speed[np.isfinite(upper_speed) & np.isfinite(strength)],
                                         strength[np.isfinite(upper_speed) & np.isfinite(strength)])[0, 1])
    return {"edges_kt": [float(e) for e in edges], "types": types, "by_upper_wind": by_upper,
            "corr_upper_speed_vs_strength": corr_upper_speed}


def maloja_days_per_month(sia: dict, days: list[date]) -> list[dict]:
    """The same 3-hour rule, but for every month loaded (May to October)."""
    afternoon = slice(slot_of(13), slot_of(18))
    with np.errstate(invalid="ignore"):
        maloja = in_sector(sia["dir"], *SECTOR_DEG) & (sia["mean"] >= MIN_SPEED_MS)
    has_data = np.isfinite(sia["mean"][:, afternoon]).sum(axis=1) >= 24
    is_day = (maloja[:, afternoon].sum(axis=1) >= MIN_SLOTS_PER_DAY) & has_data
    result = []
    for month in MONTHS:
        sel = np.array([d.month == month for d in days]) & has_data
        result.append({"month": month, "days": int(sel.sum()), "share": float(is_day[sel].mean())})
    return result


# ---------------------------------------------------------------- main

def main() -> None:
    warnings.filterwarnings("ignore", "Mean of empty slice")
    warnings.filterwarnings("ignore", "All-NaN slice")
    today = date.today()
    days = [d for d in (date(FIRST_YEAR, 1, 1) + timedelta(n) for n in range((today - date(FIRST_YEAR, 1, 1)).days))
            if d.month in MONTHS]
    print(f"Loading {len(area.VALLEY_STATIONS)} stations, {len(days)} days (May to October {FIRST_YEAR} to {today.year})...")
    stations = {s: load_station(s, days) for s in area.VALLEY_STATIONS}
    sia = stations["sia"]
    mday = maloja_days(sia, days)
    rows = np.nonzero(mday)[0]
    summer_days = sum(1 for d in days if d.month in SUMMER and np.isfinite(sia["mean"][days.index(d)]).sum() > 100)
    years = sorted({days[r].year for r in rows})
    print(f"Maloja days at Segl-Maria (>= 3 h of {SECTOR_DEG[0]:.0f}-{SECTOR_DEG[1]:.0f} deg, >= 4 m/s, 13-18): "
          f"{mday.sum()} of {summer_days} June-September days with data ({100 * mday.sum() / summer_days:.0f} %), "
          f"{years[0]}-{years[-1]}")
    results: dict = {"maloja_days": int(mday.sum()), "summer_days_with_data": summer_days,
                     "years": [years[0], years[-1]], "stations": {}}

    print("\nShare of Maloja days per month (May and October for comparison):")
    results["per_month"] = maloja_days_per_month(sia, days)
    for m in results["per_month"]:
        print(f"  month {m['month']:2d}: {100 * m['share']:4.0f} %  of {m['days']} days")

    # Each station's own afternoon direction on Maloja days, its daily cycle, start and end.
    print("\nEach station on the Maloja days of Segl-Maria:")
    onsets = {}
    for s, data in stations.items():
        mode, lo, hi = station_sector(data, mday)
        cycle = daily_cycle(data, mday, lo, hi)
        results["stations"][s] = {"name": area.VALLEY_STATIONS[s], "afternoon_mode_deg": mode,
                                  "sector_deg": [lo, hi], "daily_cycle": cycle}
        print(f"\n  {s.upper()} {area.VALLEY_STATIONS[s]}")
        print(f"    afternoon wind from {mode:.0f} deg (sector {lo:.0f}-{hi:.0f})")
        if s in ONSET_STATIONS:
            on, end = onset_and_end(data, rows, lo, hi)
            onsets[s] = on
            results["stations"][s].update({"onset": pct(on), "end": pct(end),
                                           "found_onset_share": float(np.isfinite(on).mean())})
            print(f"    start p10/p50/p90 {' / '.join(clock(v) for v in pct(on))}, "
                  f"end {' / '.join(clock(v) for v in pct(end))} (found on {100 * np.isfinite(on).mean():.0f} % of days)")
        print("    hour  mean kt (p25-p75)  1s gust kt  dir  in sector")
        for c in cycle:
            print(f"    {c['hour']:02d}:00 {c['mean_kt']:5.1f} ({c['mean_p25_kt']:4.1f}-{c['mean_p75_kt']:4.1f})"
                  f"   {c['gust1_kt']:5.1f}   {c['dir_deg']:5.0f}  {100 * c['share_in_sector']:4.0f} %")

    # How the start travels: delays between stations on the same day.
    print("\nHow the start travels down the valley (minutes, p10/p50/p90, same day):")
    results["delays_min"] = {}
    for a, b in (("vio", "sia"), ("sia", "sam")):
        km = round(distance_km(a, b), 1)  # straight line; the valley is close to straight here
        delay = (onsets[b] - onsets[a]) * 10
        ok = np.isfinite(delay)
        results["delays_min"][f"{a}_to_{b}"] = {"km": km, "minutes": pct(delay), "n": int(ok.sum())}
        median = np.nanmedian(delay)
        results["delays_min"][f"{a}_to_{b}"]["later_share"] = float(np.mean(delay[ok] > 0))
        line = f"  {a.upper()} -> {b.upper()} ({km} km): {fmt(pct(delay), 0)} min (n={ok.sum()}), "                f"{b.upper()} later on {100 * np.mean(delay[ok] > 0):.0f} % of days"
        if median > 0:
            speed = km * 1000 / (median * 60)
            line += f", median front speed {speed:.1f} m/s = {speed * KT:.0f} kt"
        print(line)

    # Does the Maloja reach Samedan? Share of the afternoon Samedan is in its own sector.
    s_lo, s_hi = results["stations"]["sam"]["sector_deg"]
    afternoon = slice(slot_of(13), slot_of(17))
    sam_share = np.array([np.nanmean(sector_mask(stations["sam"]["dir"][r, afternoon], s_lo, s_hi)) for r in rows])

    print("\nThe start at Segl-Maria:")
    results["onset_jump"] = onset_jump(sia, rows, onsets["sia"])
    for k, v in results["onset_jump"].items():
        print(f"  {k}: {fmt(v)}")

    print("\nGust factors in Maloja periods (13-18, in sector, >= 4 m/s at Segl-Maria):")
    with np.errstate(invalid="ignore"):
        maloja_periods = (in_sector(sia["dir"], *SECTOR_DEG) & (sia["mean"] >= MIN_SPEED_MS)
                          & mday[:, None] & (np.arange(SLOTS) >= slot_of(13)) & (np.arange(SLOTS) < slot_of(18)))
    results["gusts_sia"] = gust_factors(sia, maloja_periods)
    g = results["gusts_sia"]
    print(f"  n={g['n']}; 1 s gust factor {fmt(g['gust1_factor'], 2)}; 3 s {fmt(g['gust3_factor'], 2)}; "
          f"3 s excess / 1 s excess {fmt(g['gust3_over_gust1_excess'], 2)}")
    for b in g["by_speed"]:
        print(f"    {b['from_kt']:2d}-{b['to_kt']:2d} kt (n={b['n']:5d}): 1 s gust factor {fmt(b['gust1_factor'], 2)}, "
              f"gust minus mean {fmt(b['gust1_excess_kt'])} kt")
    results["gust_by_hour_sia"] = gust_factor_by_hour(sia, mday, *SECTOR_DEG)
    print("  by hour (1 s gust factor p10/p50/p90):")
    for r in results["gust_by_hour_sia"]:
        print(f"    {r['hour']:02d}:00  {fmt(r['gust1_factor'], 2)}")
    print("  other stations, 13-17 on Maloja days, in their own sector, >= 3 m/s:")
    results["gusts_other"] = {}
    for s in ("vio", "sam", "cov"):
        lo, hi = results["stations"][s]["sector_deg"]
        with np.errstate(invalid="ignore"):
            sel = (sector_mask(stations[s]["dir"], lo, hi) & (stations[s]["mean"] >= 3.0) & mday[:, None]
                   & (np.arange(SLOTS) >= slot_of(13)) & (np.arange(SLOTS) < slot_of(17)))
        results["gusts_other"][s] = gust_factors(stations[s], sel)
        print(f"    {s.upper()}: 1 s gust factor {fmt(results['gusts_other'][s]['gust1_factor'], 2)} "
              f"(n={results['gusts_other'][s]['n']})")

    print("\nDirection at Segl-Maria, afternoon of Maloja days (10-minute means):")
    results["direction_sia"] = direction_behaviour(sia, mday)
    d = results["direction_sia"]
    print(f"  the day's mean direction p10/p50/p90: {fmt(d['day_direction_deg'], 0)}")
    print(f"  offset from the day's mean p5/p10/p25/p50/p75/p90/p95: {fmt(d['offset_from_day_mean_deg'], 0)}  "
          f"(std {d['offset_std_deg']:.1f})")
    print(f"  change per 10 minutes p50/p75/p90/p95: {fmt(d['change_per_10min_deg'], 0)}")
    print(f"  swing within an hour p25/p50/p75/p90: {fmt(d['swing_within_an_hour_deg'], 0)}")
    print(f"  autocorrelation after 10, 20, ... 90 min: {fmt(d['autocorrelation_per_10min'], 2)}")
    print(f"  stronger wind turns {d['deg_per_kt_stronger']:+.2f} deg per kt (correlation {d['speed_direction_correlation']:+.2f};"
          f" + is clockwise/veered)")
    print("  drift through the afternoon (mean offset per hour): "
          + ", ".join(f"{x['hour']}h {x['mean_offset_deg']:+.1f}" for x in d["drift_by_hour"]))

    print("\nSpeed at Segl-Maria, afternoon of Maloja days (10-minute means):")
    results["speed_sia"] = speed_behaviour(sia, mday)
    sp = results["speed_sia"]
    print(f"  ratio to the day's mean p5/p10/p25/p50/p75/p90/p95: {fmt(sp['ratio_to_day_mean'], 2)}")
    print(f"  autocorrelation after 10, 20, ... 90 min: {fmt(sp['autocorrelation_per_10min'], 2)}")

    print("\nDay types (thirds by the 13-17 median at Segl-Maria):")
    results["day_types"] = day_types(sia, stations["cov"], stations["sam"], mday, onsets["sia"], sam_share)
    dt = results["day_types"]
    print(f"  edges {dt['edges_kt'][0]:.1f} and {dt['edges_kt'][1]:.1f} kt; upper wind speed vs strength "
          f"correlation {dt['corr_upper_speed_vs_strength']:+.2f}")
    for t in dt["types"]:
        print(f"  {t['type']:6s} ({t['days']} days): mean {fmt(t['afternoon_mean_kt'])} kt, strongest gust "
              f"{fmt(t['strongest_gust_13_17_kt'])} kt, gust factor {fmt(t['gust1_factor'], 2)}, from "
              f"{t['direction_deg']:.0f}, start {' / '.join(t['onset'])}, upper wind {fmt(t['upper_wind_kt'])} kt "
              f"from {t['upper_wind_from_deg']:.0f}, reaches Samedan on {100 * t['share_reaching_samedan']:.0f} %")
    print("  by the upper wind's direction (Corvatsch, 12-15):")
    for u in dt["by_upper_wind"]:
        print(f"    from {u['upper_from']:2s} ({u['days']:3d} days): mean {fmt(u['afternoon_mean_kt'])} kt, "
              f"gust factor {fmt(u['gust1_factor'], 2)}, Maloja from {u['direction_deg']:.0f}")

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    (OUT_DIR / "results.json").write_text(json.dumps(results, indent=1))
    print(f"\nWrote {OUT_DIR / 'results.json'}")


if __name__ == "__main__":
    main()
