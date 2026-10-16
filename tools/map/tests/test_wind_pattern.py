"""Checks of the Maloja's fixed pattern made by tools/map/windninja_pattern.py (MAP_SILVAPLANA_PLAN.md, W1).

Plain checks with assert, no test framework needed. Run from the repo root, after windninja_pattern.py:
  python tools/map/tests/test_wind_pattern.py
It prints one line per check and exits with an error if any check fails.
"""
import json
import sys
import traceback
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import satellite_wind  # noqa: E402
import silvaplana_area as area  # noqa: E402

WIND_DIR = area.GAME_MAP_DIR / "wind"
LAKE_AXIS_DEG = 224.0  # the lake's long axis, from the Sils end to the Silvaplana end
STATION_SIA = (2_778_576.0, 1_144_976.0)
STATION_DIRECTION_DEG = 245.0  # Segl-Maria in a Maloja (MALOJA_WIND_RESEARCH.md)


def pattern() -> tuple[np.ndarray, np.ndarray, dict]:
    """The speed factor and the turn (degrees), shaped (rows, columns), and the metadata."""
    meta = json.loads((WIND_DIR / "maloja_pattern.json").read_text())
    values = np.fromfile(WIND_DIR / meta["file"], dtype="<f4")
    cells = meta["rows"] * meta["columns"]
    assert values.size == 2 * cells, f"{values.size} values, expected {2 * cells}"
    return values[:cells].reshape(meta["rows"], meta["columns"]), values[cells:].reshape(meta["rows"], meta["columns"]), meta


def at(east: np.ndarray, north: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
    factor, turn, meta = pattern()
    row = np.clip(((meta["north_m"] - north) / meta["cell_m"]).astype(int), 0, meta["rows"] - 1)
    column = np.clip(((east - meta["west_m"]) / meta["cell_m"]).astype(int), 0, meta["columns"] - 1)
    return factor[row, column], turn[row, column]


def lake_points() -> tuple[np.ndarray, np.ndarray]:
    east, north = satellite_wind.grid_lv95()
    lake = satellite_wind.lake_mask()
    return east[lake], north[lake]


def check_file_is_complete() -> str:
    factor, turn, meta = pattern()
    assert np.isfinite(factor).all() and np.isfinite(turn).all(), "the pattern has missing values"
    return f"{meta['columns']} x {meta['rows']} cells of {meta['cell_m']:.0f} m, from run {meta['run']}"


def check_covers_the_valley() -> str:
    # From the Maloja pass (about 2773.7 / 1141.4) to St. Moritz (about 2784.5 / 1152.5).
    _, _, meta = pattern()
    east = meta["west_m"] + meta["columns"] * meta["cell_m"]
    south = meta["north_m"] - meta["rows"] * meta["cell_m"]
    assert meta["west_m"] < 2_773_000 and east > 2_785_000, "the pattern doesn't reach from the pass to St. Moritz"
    assert south < 1_141_000 and meta["north_m"] > 1_153_000, "the pattern doesn't reach from the pass to St. Moritz"
    return f"east {meta['west_m']:.0f} to {east:.0f}, north {south:.0f} to {meta['north_m']:.0f}"


def check_relative_to_the_lake() -> str:
    # The factors are relative to the lake's median speed and its mean direction.
    factor, turn = at(*lake_points())
    median = float(np.median(factor))
    mean_turn = float(np.degrees(np.arctan2(np.mean(np.sin(np.radians(turn))), np.mean(np.cos(np.radians(turn))))))
    assert abs(median - 1.0) < 0.03, f"the lake's median speed factor is {median:.3f}, not 1"
    assert abs(mean_turn) < 3.0, f"the lake's mean turn is {mean_turn:.1f} degrees, not 0"
    return f"lake median factor {median:.3f}, mean turn {mean_turn:+.1f} degrees"


def check_no_extremes_on_the_lake() -> str:
    factor, turn = at(*lake_points())
    low, high = np.percentile(factor, [1, 99])
    assert low > 0.4 and high < 1.8, f"speed factors from {low:.2f} to {high:.2f} on the lake"
    assert np.percentile(np.abs(turn), 99) < 45, "turns of more than 45 degrees on the lake"
    return f"speed factor {low:.2f} to {high:.2f} (1 to 99 %), turns up to {np.percentile(np.abs(turn), 99):.0f} degrees"


def check_lake_wind_follows_the_lake() -> str:
    _, _, meta = pattern()
    lake_dir = meta["lake_direction_deg"]
    off = (lake_dir - LAKE_AXIS_DEG + 180) % 360 - 180
    assert abs(off) < 12, f"the lake's wind comes from {lake_dir:.0f} degrees, {off:+.0f} from the lake's axis"
    return f"from {lake_dir:.0f} degrees, {off:+.0f} from the lake's axis"


def check_station_reads_like_the_real_one() -> str:
    # Segl-Maria reads 245 degrees in a Maloja; the pattern must turn the lake's wind about that much there.
    _, _, meta = pattern()
    _, turn = at(np.array([STATION_SIA[0]]), np.array([STATION_SIA[1]]))
    station = (meta["lake_direction_deg"] + float(turn[0])) % 360
    off = (station - STATION_DIRECTION_DEG + 180) % 360 - 180
    assert abs(off) < 10, f"the station would read {station:.0f} degrees, the real one reads {STATION_DIRECTION_DEG:.0f}"
    return f"the station would read {station:.0f} degrees (real: {STATION_DIRECTION_DEG:.0f})"


def main() -> None:
    checks = [check_file_is_complete, check_covers_the_valley, check_relative_to_the_lake, check_no_extremes_on_the_lake,
              check_lake_wind_follows_the_lake, check_station_reads_like_the_real_one]
    failed = 0
    for check in checks:
        name = check.__name__.removeprefix("check_").replace("_", " ")
        try:
            print(f"ok    {name}: {check()}")
        except Exception as error:  # report every check, then fail at the end
            failed += 1
            print(f"FAIL  {name}: {error}")
            if not isinstance(error, AssertionError):
                traceback.print_exc()
    print(f"{len(checks) - failed} of {len(checks)} checks passed")
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
