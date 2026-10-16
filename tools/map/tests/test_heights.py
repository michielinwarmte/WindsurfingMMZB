"""Checks of the terrain heights made by tools/map/heights.py (MAP_SILVAPLANA_PLAN.md, M1).

Plain checks with assert, no test framework needed. Run from the repo root, after heights.py:
  python tools/map/tests/test_heights.py
It prints one line per check and exits with an error if any check fails.
"""
import glob
import json
import sys
import traceback
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import readers  # noqa: E402
import silvaplana_area as area  # noqa: E402

TERRAIN = area.WORK_DIR / "terrain"
GAME_TERRAIN = area.GAME_MAP_DIR / "terrain"


def lake_level() -> float:
    return json.loads((area.WORK_DIR / "lake.json").read_text())["lake_level_m"]


def game_grid() -> tuple[np.ndarray, dict]:
    """The shore band's heights as the game reads them: metres above the lake."""
    meta = json.loads((GAME_TERRAIN / "shore_heights.json").read_text())
    values = np.fromfile(GAME_TERRAIN / meta["file"], dtype="<u2").reshape(meta["rows"], meta["columns"])
    return meta["height_offset_m"] + values * meta["height_scale_m"], meta


def grid_height(east: float, north: float) -> float:
    heights, meta = game_grid()
    row = int(round((meta["north_m"] - north) / meta["cell_m"]))
    column = int(round((east - meta["west_m"]) / meta["cell_m"]))
    return float(heights[row, column])


def chunks() -> list[dict]:
    return json.loads((TERRAIN / "chunks.json").read_text())["chunks"]


def check_lake_surface_is_at_zero() -> str:
    # In swissALTI3D the lake is flat at one height: that height must be the game's 0.
    tile = readers.read_alti3d_tile(2780, 1146)
    surface = float(np.mean(tile.heights[np.abs(tile.heights - lake_level()) < 0.05]))
    assert abs(surface - lake_level()) < 0.01, f"the lake surface is at {surface:.3f} m, the lake level at {lake_level()} m"
    return f"the flat lake surface in swissALTI3D is {surface - lake_level():+.3f} m from the lake level"


def check_water_covers_the_lake() -> str:
    # Every point the lakebed survey measured must be under water, and the water must cover
    # about as much as the flat lake surface in swissALTI3D (2.89 km2 inside the shore band).
    heights, meta = game_grid()
    bathy = readers.read_bathy()
    rows, columns = np.nonzero(~np.isnan(bathy.heights[::10, ::10]))
    east = bathy.west_m + (columns * 10 + 0.5)
    north = bathy.north_m - (rows * 10 + 0.5)
    inside = (east > meta["west_m"]) & (east < meta["west_m"] + (meta["columns"] - 1) * meta["cell_m"]) & \
             (north < meta["north_m"]) & (north > meta["north_m"] - (meta["rows"] - 1) * meta["cell_m"])
    r = np.round((meta["north_m"] - north[inside]) / meta["cell_m"]).astype(int)
    c = np.round((east[inside] - meta["west_m"]) / meta["cell_m"]).astype(int)
    above = int(np.sum(heights[r, c] >= 0.0))
    assert above == 0, f"{above} surveyed lake points are above the water"
    area_km2 = float(np.sum(heights < 0.0)) * meta["cell_m"] ** 2 / 1e6
    assert 2.7 < area_km2 < 3.1, f"the water covers {area_km2:.2f} km2"
    return f"all {inside.sum():,} surveyed points tested are under water; water area in the band {area_km2:.2f} km2"


def check_deepest_point() -> str:
    heights, _ = game_grid()
    deepest = -float(heights.min())
    assert abs(deepest - area.LAKE_MAX_DEPTH_M) < 1.0, f"deepest point {deepest:.1f} m, published {area.LAKE_MAX_DEPTH_M} m"
    return f"deepest point {deepest:.1f} m (published: {area.LAKE_MAX_DEPTH_M:.0f} m)"


def check_piz_corvatsch() -> str:
    east, north, published = area.KNOWN_POINTS["Piz Corvatsch"]
    regio = readers.read_regio()
    row, column = regio.cell_of(east, north)
    summit = float(np.nanmax(regio.heights[row - 15:row + 16, column - 15:column + 16]))
    assert abs(summit - published) < 3.0, f"Corvatsch at {summit:.0f} m, published {published:.0f} m"
    # And in the terrain chunk that has it (20 m or 40 m vertices, so a little lower). Chunks of
    # different zones can overlap; the tiles a chunk doesn't have are holes in its "cells".
    relative = None
    for chunk in chunks():
        size, cell = chunk["size_m"], chunk["cell_m"]
        if not (chunk["west_m"] <= east < chunk["west_m"] + size and chunk["north_m"] - size < north <= chunk["north_m"]):
            continue
        data = np.load(TERRAIN / chunk["file"])
        r = int(round((chunk["north_m"] - north) / cell))
        c = int(round((east - chunk["west_m"]) / cell))
        if not data["cells"][min(r, data["cells"].shape[0] - 1), min(c, data["cells"].shape[1] - 1)]:
            continue
        reach = int(150 / cell)
        relative = float(data["heights"][r + 1 - reach:r + reach + 2, c + 1 - reach:c + reach + 2].max())
        terrain_name = chunk["name"]
    assert relative is not None, "no terrain chunk contains Piz Corvatsch"
    assert abs(relative - (published - lake_level())) < 20.0, f"Corvatsch is {relative:.0f} m above the lake in the terrain"
    return (f"summit {summit:.0f} m in swissALTIRegio (published {published:.0f} m); "
            f"{relative:.0f} m above the lake in {terrain_name} (expected about {published - lake_level():.0f} m)")


def check_weather_station() -> str:
    east, north, published = area.KNOWN_POINTS["weather station Segl-Maria"]
    height = grid_height(east, north)
    assert abs(height - (published - lake_level())) < 2.0, f"station ground {height:.1f} m above the lake"
    return f"ground at the station {height + lake_level():.1f} m (published {published:.0f} m)"


def check_camping_is_at_the_lake() -> str:
    east, north, _ = area.KNOWN_POINTS["camping Silvaplana"]
    heights, meta = game_grid()
    rows, columns = np.nonzero(heights < 0.0)
    distance = np.hypot(meta["west_m"] + columns * meta["cell_m"] - east, meta["north_m"] - rows * meta["cell_m"] - north)
    nearest = float(distance.min())
    height = grid_height(east, north)
    assert nearest < 150.0, f"the nearest water is {nearest:.0f} m from the camping"
    assert 0.0 < height < 10.0, f"the camping is {height:.1f} m above the lake"
    return f"camping {height:.1f} m above the lake, water {nearest:.0f} m away"


def check_no_holes() -> str:
    heights, _ = game_grid()
    assert not np.isnan(heights).any(), "the game grid has holes"
    for chunk in chunks():
        data = np.load(TERRAIN / chunk["file"])
        core = data["heights"][1:-1, 1:-1]
        cells = data["cells"]
        used = np.zeros(core.shape, dtype=bool)
        for dr in (0, 1):
            for dc in (0, 1):
                used[dr:dr + cells.shape[0], dc:dc + cells.shape[1]] |= cells
        assert not np.isnan(core[used]).any(), f"{chunk['name']} has holes (NaN)"
        assert not np.isnan(data["heights"]).any(), f"{chunk['name']} has holes (NaN) in its halo"
    return f"no NaN in the game grid or in any of the {len(chunks())} chunks"


def check_chunks_meet() -> str:
    # Where two chunks have a vertex at the same place, it must have the same height in both,
    # or there would be a crack between the meshes.
    seen: dict[tuple[int, int], tuple[float, str]] = {}
    worst, pairs = 0.0, 0
    for chunk in chunks():
        data = np.load(TERRAIN / chunk["file"])
        cells, core, cell = data["cells"], data["heights"][1:-1, 1:-1], chunk["cell_m"]
        used = np.zeros(core.shape, dtype=bool)
        for dr in (0, 1):
            for dc in (0, 1):
                used[dr:dr + cells.shape[0], dc:dc + cells.shape[1]] |= cells
        inner = np.zeros(core.shape, dtype=bool)
        inner[1:-1, 1:-1] = cells[:-1, :-1] & cells[1:, :-1] & cells[:-1, 1:] & cells[1:, 1:]
        rows, columns = np.nonzero(used & ~inner)
        for r, c in zip(rows, columns):
            key = (int(round((chunk["west_m"] + c * cell) * 100)), int(round((chunk["north_m"] - r * cell) * 100)))
            value = float(core[r, c])
            if key in seen and seen[key][1] != chunk["name"]:
                worst = max(worst, abs(seen[key][0] - value))
                pairs += 1
            else:
                seen[key] = (value, chunk["name"])
    assert pairs > 1000, f"only {pairs} shared border vertices found"
    assert worst < 0.001, f"chunks differ by {worst:.3f} m at a shared vertex"
    return f"{pairs:,} shared border vertices, largest difference {worst * 1000:.2f} mm"


def main() -> None:
    checks = [check_lake_surface_is_at_zero, check_water_covers_the_lake, check_deepest_point, check_piz_corvatsch,
              check_weather_station, check_camping_is_at_the_lake, check_no_holes, check_chunks_meet]
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
