"""The ground under the Maloja's fixed pattern, for the wind viewer (map plan, phase W2).

The wind viewer draws streaks that move with the wind a few metres above the ground, also over
land. For that the game needs the height of the ground (or of a lake's surface) everywhere the
pattern has wind: from the Maloja pass to St. Moritz, 22 x 20 km. The game's own height grid only
covers the shore band, so this script writes a coarse one on exactly the pattern's 50 m cells:
the mean of swissALTIRegio's 10 m heights in each cell.

Run from the repo root, after heights.py (which makes the swissALTIRegio mosaic) and
windninja_pattern.py (which fixes the pattern's grid). A few seconds:

    python tools/map/wind_ground.py

Output: Game/maps/silvaplana/wind/ground.json + .bin (generated, don't edit), in the same format
as the shore band's grid (TerrainGrid in the game reads both): metres above the lake surface,
one value per pattern cell, on the cell's centre.
"""
import json

import numpy as np

import silvaplana_area as area

WIND_DIR = area.GAME_MAP_DIR / "wind"
REGIO_CELL_M = 10.0
# 16-bit heights: -1000 m to +2276 m around the lake level. The area goes from Val Bregaglia,
# 710 m below the lake, to Piz Bernina, 2257 m above it.
SCALE_M = 0.05
OFFSET_M = -1000.0


def main() -> None:
    pattern = json.loads((WIND_DIR / "maloja_pattern.json").read_text())
    lake = json.loads((area.WORK_DIR / "lake.json").read_text())
    regio = np.load(area.WORK_DIR / "swissaltiregio_10m.npz")
    heights, regio_west, regio_north = regio["heights"], float(regio["west"]), float(regio["north"])

    cell = float(pattern["cell_m"])
    rows, columns = int(pattern["rows"]), int(pattern["columns"])
    k = int(round(cell / REGIO_CELL_M))  # 10 m cells per 50 m cell, each way
    r0 = int(round((regio_north - pattern["north_m"]) / REGIO_CELL_M))
    c0 = int(round((pattern["west_m"] - regio_west) / REGIO_CELL_M))
    window = heights[r0:r0 + rows * k, c0:c0 + columns * k].astype(np.float64)
    assert window.shape == (rows * k, columns * k), "swissALTIRegio doesn't cover the whole pattern"
    ground = window.reshape(rows, k, columns, k).mean(axis=(1, 3)) - lake["lake_level_m"]

    values = np.round((ground - OFFSET_M) / SCALE_M)
    assert values.min() >= 0 and values.max() <= 65535, "The heights don't fit the 16-bit range"
    values.astype("<u2").tofile(WIND_DIR / "ground.bin")
    # The values sit on the cells' centres, so the first one is half a cell in from the corner.
    first_east = pattern["west_m"] + cell / 2.0
    first_north = pattern["north_m"] - cell / 2.0
    (WIND_DIR / "ground.json").write_text(json.dumps({
        "about": "The ground (or a lake's surface) under the Maloja's fixed pattern, for the wind viewer, written by "
                 "tools/map/wind_ground.py: don't edit. Mean of swissALTIRegio's 10 m heights in each 50 m cell of "
                 "maloja_pattern.json. height above the lake surface (m) = height_offset_m + value * height_scale_m",
        "file": "ground.bin",
        "format": "uint16 little-endian, row by row from the north edge, each row from west to east",
        "columns": columns, "rows": rows, "cell_m": cell,
        "west_m": first_east, "north_m": first_north,
        "x0_m": first_east - lake["origin_east_m"], "z0_m": -(first_north - lake["origin_north_m"]),
        "height_scale_m": SCALE_M, "height_offset_m": OFFSET_M,
        "lake_level_m": lake["lake_level_m"],
    }, indent=1))
    print(f"Ground under the wind pattern: {columns} x {rows} at {cell:.0f} m, "
          f"{ground.min():.0f} to {ground.max():.0f} m above the lake, in {WIND_DIR / 'ground.json'}")


if __name__ == "__main__":
    main()
