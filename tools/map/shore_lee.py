"""The lee along the south-east shore of Lake Silvaplana, measured on the satellite photos (map plan, W3).

Max (15 October 2026), about the band along the south-east (Corvatsch) shore from the Sils end to
the north-east bend: "this area has too much wind compared to real life; on competition you have
to really avoid it, and only once in every 10 or so there is a gust that is favourable and goes
down all the way". The game's fixed pattern (W1) has this band only as the photos' average, with the
gusts at full strength in it. This script measures what the photos say about it, at full 10 m
detail (W1 smoothed over 150 m):

1. The band's shape: the photos' roughness (Maloja photos / calm photos, satellite_wind.py)
   against the distance from the south-east shore, minus the same against the distance from the
   north-west shore (the control: water near both shores is about 2 % smoother, and that is not a
   lee); and along the shore, in pieces of 200 m. The lee runs from the Sils end to the north-east
   bend, as Max drew it; north of the bend, along the east shore, the photos show none.
2. The band per photo: the lee 50 to 250 m from the shore (minus the same on the north-west side of
   the same photo), and how it depends on the wind's direction and strength at the station at the
   photo's moment (a straight-line fit). A wind from further left (more off the south-east shore)
   and a stronger wind give a deeper lee.
3. What W1 already holds: the photos' average lee, put through W1's own steps (smoothing, 50 m
   cells, interpolation), so the game can replace W1's averaged band by the moving one.

The game (WindLee) then puts the band's depth at each moment from the fit (with the moment's
direction and strength), lifts it in the strongest gusts only (1 in 10, Max; the photos: 7 of 54
pieces of band on the days with a lee are as rough as the open lake, about 1 in 8), and keeps the
photos' average over time.

Run from the repo root, after satellite_wind.py and windninja_pattern.py (a few seconds):

    python tools/map/shore_lee.py

Output: Game/maps/silvaplana/wind/shore_lee.json + .bin (generated, don't edit), printed numbers.
"""
import json
import math

import numpy as np

import satellite_wind as sw
import silvaplana_area as area
import windninja_pattern as wp

NARROWS_NORTH_M = 1_147_780.0
WIND_TO_DEG = 42.0  # the lake's wind moves to 42 degrees (W1)
STRIP_M = 50.0  # strips across the lake, for which side of the lake a shore is on
BAND_M = (50.0, 250.0)  # the band measured per photo
OPEN_M = 400.0  # open lake: at least this far from both shores
MIN_WIDTH_M = 600.0  # only where the lake is this wide (not the tips)
PROFILE_EDGES_M = [25, 50, 75, 100, 150, 200, 250, 300, 400, 500]
LEE_END_ALONG_M = 1000.0  # the north-east bend: north of it, along the east shore, the photos show no lee
SEGMENT_M = 200.0  # pieces of the shore for the lee along it
LEFT_OUT = ("20230824",)  # see main(), step 2
REFERENCE_DIR_DEG = 240.0  # the fit is around these station values
REFERENCE_KT = 12.6
OUT_DIR = area.GAME_MAP_DIR / "wind"


def lake_frame(east: np.ndarray, north: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
    """Metres along the lake (downwind positive) and across it (south-east positive), from its middle."""
    to = math.radians(WIND_TO_DEG)
    along = (east - 2_780_500.0) * math.sin(to) + (north - 1_146_600.0) * math.cos(to)
    across = (east - 2_780_500.0) * math.cos(to) - (north - 1_146_600.0) * math.sin(to)
    return along, across


def shore_distances(basin: np.ndarray, along: np.ndarray, across: np.ndarray, east: np.ndarray,
                    north: np.ndarray) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    """Per water cell: the distance (m) to the south-east shore, to the north-west shore (both along
    lines across the lake, in strips), and the true distance to the nearest south-east shore cell."""
    strips = np.floor(along / STRIP_M).astype(int)
    se = np.full(basin.shape, np.nan)
    nw = np.full(basin.shape, np.nan)
    middle = np.full(basin.shape, np.nan)
    for s in np.unique(strips[basin]):
        m = basin & (strips == s)
        se[m] = across[m].max() - across[m]
        nw[m] = across[m] - across[m].min()
        middle[m] = (across[m].max() + across[m].min()) / 2.0
    # The south-east shore: water cells next to land, on the south-east half of their strip.
    land = ~basin
    edge = basin & (np.roll(land, 1, 0) | np.roll(land, -1, 0) | np.roll(land, 1, 1) | np.roll(land, -1, 1))
    shore = edge & (across > middle)
    se_true = np.full(basin.shape, np.nan)
    se_east, se_north = east[shore], north[shore]
    cells = np.argwhere(basin)
    for start in range(0, len(cells), 4000):
        part = cells[start:start + 4000]
        de = east[part[:, 0], part[:, 1]][:, None] - se_east[None, :]
        dn = north[part[:, 0], part[:, 1]][:, None] - se_north[None, :]
        se_true[part[:, 0], part[:, 1]] = np.sqrt(de * de + dn * dn).min(axis=1)
    return se, nw, se_true


def w1_chain(field: np.ndarray, lake: np.ndarray, east: np.ndarray, north: np.ndarray) -> np.ndarray:
    """A roughness field (on the satellite grid) put through W1's steps into the game's pattern, and
    sampled back at the satellite grid's cells: smoothing (windninja_pattern.lake_strength_from_satellite),
    the 50 m cells of maloja_pattern (only those at least half lake), then the game's interpolation
    between the 50 m cell centres. Outside the satellite's cells the pattern is WindNinja's: 1 here."""
    strength = wp.lake_strength_from_satellite({wp.SATELLITE_KEY: field}, lake)
    meta = json.loads((wp.GAME_DIR / "maloja_pattern.json").read_text())
    rows, cols, cell = meta["rows"], meta["columns"], meta["cell_m"]
    grid = np.ones((rows, cols))
    for r in range(rows):
        n = meta["north_m"] - (r + 0.5) * cell
        gr = int((sw.GRID_NORTH - n) / sw.GRID_CELL)
        if not 2 <= gr < lake.shape[0] - 2:
            continue
        for c in range(cols):
            e = meta["west_m"] + (c + 0.5) * cell
            gc = int((e - sw.GRID_WEST) / sw.GRID_CELL)
            if not 2 <= gc < lake.shape[1] - 2:
                continue
            block = strength[gr - 2:gr + 3, gc - 2:gc + 3]
            if np.isfinite(block).sum() >= 13:
                grid[r, c] = np.nanmean(block)
    sampler = wp.Grid.__new__(wp.Grid)
    sampler.cell, sampler.west, sampler.north, sampler.values = cell, meta["west_m"], meta["north_m"], grid
    return sampler.sample(east, north)


def main() -> None:
    east, north = sw.grid_lv95()
    lake = sw.lake_mask()
    basin = lake & (north < NARROWS_NORTH_M)
    along, across = lake_frame(east, north)
    se, nw, se_true = shore_distances(basin, along, across, east, north)
    wide = basin & (se + nw > MIN_WIDTH_M)
    open_lake = basin & (se > OPEN_M) & (nw > OPEN_M)
    band = wide & (se >= BAND_M[0]) & (se < BAND_M[1])
    rough = np.load(sw.OUT_DIR / "roughness.npz")
    pattern = rough["pattern_red"] / np.nanmedian(rough["pattern_red"][open_lake])

    stretch = along < LEE_END_ALONG_M
    band_nw = wide & stretch & (nw >= BAND_M[0]) & (nw < BAND_M[1])
    band = band & stretch

    # 1. The shape across (south-east minus north-west at the same distance), and along the shore.
    print("1. Roughness against the distance from the shore (relative to the open lake), Sils end to the bend:")
    by_distance = {}
    for name, distance in (("south-east", se), ("north-west", nw)):
        by_distance[name] = []
        for a, b in zip(PROFILE_EDGES_M[:-1], PROFILE_EDGES_M[1:]):
            m = wide & stretch & (distance >= a) & (distance < b)
            by_distance[name].append(float(np.nanmean(pattern[m]) - 1.0))
        print(f"   {name}: " + "  ".join(f"{a}-{b} m {100 * v:+.0f} %" for a, b, v in zip(PROFILE_EDGES_M[:-1], PROFILE_EDGES_M[1:], by_distance[name])))
    across_lee = [nw_value - se_value for se_value, nw_value in zip(by_distance["south-east"], by_distance["north-west"])]
    profile_m = [(a + b) / 2.0 for a, b in zip(PROFILE_EDGES_M[:-1], PROFILE_EDGES_M[1:])]
    control = float(np.nanmean(pattern[band_nw]) - 1.0)
    segments = np.arange(-1600.0, LEE_END_ALONG_M + 600.0, SEGMENT_M)
    along_lee = []
    for a in segments:
        m = wide & (se >= BAND_M[0]) & (se < BAND_M[1]) & (along >= a) & (along < a + SEGMENT_M)
        along_lee.append(max(control - (float(np.nanmean(pattern[m])) - 1.0), 0.0) if m.sum() > 100 else np.nan)
    along_lee = np.array(along_lee)
    known = np.isfinite(along_lee)
    along_lee = np.interp(segments, segments[known], along_lee[known])
    along_lee = np.convolve(np.pad(along_lee, 1, mode="edge"), [0.25, 0.5, 0.25], mode="valid")  # about 400 m
    along_lee[segments + SEGMENT_M / 2.0 > LEE_END_ALONG_M] = 0.0
    print("   along the shore (lee 50 to 250 m out, minus the north-west side): " + "  ".join(
        f"{a + SEGMENT_M / 2.0:+.0f} m {100 * v:.0f} %" for a, v in zip(segments, along_lee)))
    band_lee_average = control - float(np.nanmean(pattern[band]) - 1.0)
    print(f"   the band ({BAND_M[0]:.0f} to {BAND_M[1]:.0f} m, Sils end to the bend) on average: {100 * band_lee_average:.1f} % less rough "
          f"than the same distance from the north-west shore")

    # 2. Per photo, against the station's direction and speed.
    scenes = json.loads((sw.OUT_DIR / "scenes.json").read_text())
    photos = [s for s in scenes if s.get("kind") == "maloja" and s.get("quality", {}).get("clean")]
    xs, ys = sw.grid_in_utm()
    calm = rough["calm_red_mean"]
    rows = []
    for s in photos:
        r = sw.relative_brightness(sw.OUT_DIR / f"{s['id']}.npz", xs, ys, lake, sw.BAND, s["offset"]) / calm
        lee_here = float(np.nanmean(r[band_nw]) - np.nanmean(r[band])) / float(np.nanmedian(r[open_lake]))
        rows.append((s["id"].split("_")[2], s["station"]["dir"], s["station"]["mean"] / 0.514444, lee_here))
    # 2023-08-24 is left out: its whole Sils end is bright (+29 % in the band, +61 % at Sils), most
    # likely haze or sun glint the cleanliness check (satellite_wind.py) didn't catch.
    used = [r for r in rows if r[0] not in LEFT_OUT]
    d = np.array([r[1] for r in used]) - REFERENCE_DIR_DEG
    k = np.array([r[2] for r in used]) - REFERENCE_KT
    y = np.array([r[3] for r in used])
    fit = np.column_stack([np.ones(len(y)), d, k])
    coefficients, *_ = np.linalg.lstsq(fit, y, rcond=None)
    residual = y - fit @ coefficients
    errors = np.sqrt(residual @ residual / (len(y) - 3) * np.diag(np.linalg.inv(fit.T @ fit)))
    r2 = 1.0 - residual @ residual / np.sum((y - y.mean()) ** 2)
    print(f"2. The band's lee per photo ({len(used)} photos): {100 * coefficients[0]:.1f} % (+-{100 * errors[0]:.1f}) "
          f"{100 * coefficients[1]:+.2f} % per degree (+-{100 * errors[1]:.2f}) {100 * coefficients[2]:+.1f} % per knot "
          f"(+-{100 * errors[2]:.1f}) at the station (station 240 degrees, 12.6 kt); R2 {r2:.2f}")
    for day, direction, knots, value in sorted(rows, key=lambda r: r[1]):
        print(f"   {day}  from {direction:4.0f}  {knots:4.1f} kt  lee {100 * value:5.1f} %{'  (left out)' if day in LEFT_OUT else ''}")

    # 3. The lee's shape on the grid (1 = the band's average): across (by the distance from the
    # south-east shore; the first 25 m take the next piece's value, as mixed pixels make them
    # unreliable) times along the shore (by the place along the lake). And what W1 holds of it.
    distance = np.where(basin, se_true, np.nan)
    across_shape = np.interp(distance, [0.0] + profile_m[1:] + [PROFILE_EDGES_M[-1] + 50.0],
                             [max(across_lee[0], across_lee[1])] + across_lee[1:] + [0.0])
    along_shape = np.interp(along, segments + SEGMENT_M / 2.0, along_lee)
    shape = np.where(basin & np.isfinite(across_shape), across_shape * along_shape, 0.0)
    shape = np.maximum(shape, 0.0)
    shape /= float(np.mean(shape[band]))
    average_lee = band_lee_average * shape  # the photos' average lee, as a share of the wind
    with_lee = w1_chain(np.where(lake, 1.0 - average_lee, np.nan), lake, east, north)
    without = w1_chain(np.where(lake, 1.0, np.nan), lake, east, north)
    held = np.where(lake & np.isfinite(with_lee), 1.0 - with_lee / without, 0.0)
    print(f"3. What W1 holds of the average lee, 25 to 100 m from the shore: {100 * np.nanmean(held[wide & (se >= 25) & (se < 100)]):.1f} % "
          f"(the photos: {100 * np.nanmean(average_lee[wide & (se >= 25) & (se < 100)]):.1f} %)")

    # The station's direction and speed in the game's terms: the lake's mean wind comes from 19.1
    # degrees further left than the station reads (W1), and is 1.3 times as strong (maloja_day.tres).
    station = json.loads((wp.GAME_DIR / "maloja_pattern.json").read_text())["station_segl_maria"]
    water_vs_station = 1.3
    rows_n, cols_n = basin.shape
    data = np.stack([shape, held]).astype("<f4")
    data.tofile(OUT_DIR / "shore_lee.bin")
    lake_level = json.loads((area.WORK_DIR / "lake.json").read_text())
    info = {
        "about": "The lee along Lake Silvaplana's south-east shore, measured on the satellite photos by "
                 "tools/map/shore_lee.py: don't edit. Layer 1: the lee's shape (its share of the band's "
                 "lee, 1 = the band 50 to 250 m from the shore on average). Layer 2: the share of the wind "
                 "the game's fixed pattern (W1) already takes off there (the photos' average lee).",
        "file": "shore_lee.bin",
        "format": "two float32 little-endian layers, each row by row from the north edge, each row from west to east",
        "columns": cols_n, "rows": rows_n, "cell_m": sw.GRID_CELL,
        "west_m": sw.GRID_WEST, "north_m": sw.GRID_NORTH,
        "band_lee_at_reference": round(float(coefficients[0]), 4),
        "band_lee_per_degree_right": round(float(coefficients[1]), 5),
        "band_lee_per_lake_knot": round(float(coefficients[2]) / water_vs_station, 5),
        "reference_lake_from_deg": round(REFERENCE_DIR_DEG - station["turn_deg"], 1),
        "reference_lake_kt": round(REFERENCE_KT * water_vs_station, 2),
        "degrees_measured": [round(float(d.min()), 1), round(float(d.max()), 1)],
        "lake_knots_measured": [round(float(k.min()) * water_vs_station, 2), round(float(k.max()) * water_vs_station, 2)],
        "band_lee_average": round(band_lee_average, 4),
        "photos": len(used), "r2": round(float(r2), 2),
    }
    (OUT_DIR / "shore_lee.json").write_text(json.dumps(info, indent=1))
    print(f"Wrote {OUT_DIR / 'shore_lee.json'} and .bin ({cols_n} x {rows_n} at {sw.GRID_CELL:.0f} m)")


if __name__ == "__main__":
    main()
