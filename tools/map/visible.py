"""Works out which land can be seen in the game (Documentation/MAP_SILVAPLANA_PLAN.md, MD4).

Only land that can be seen gets built, so the map stays small. "Seen" means from any of the
viewpoints in silvaplana_area.VIEWPOINTS: the sailor on the water, the orbit camera, and the
higher and shore-side shots that replays will want. From a grid of points on the lake (and on
the shore), the script looks out in thousands of directions and follows each line of sight over
the swissALTIRegio heights: a piece of land is visible when nothing closer rises above the line
to it. The Earth's curve (with normal light refraction) is included: it hides about 25 m at 20 km.

Writes to .map_data/work/:
  visible_tiles.json   the 1 km tiles with anything visible (download.py photos-far uses it)
  visible_50m.npz      the visibility grids, 50 m cells
  visible_map.png      a picture for the team: orange is seen by the sailor, yellow only by the
                       cameras, blue is the lake, red dots are viewpoints on the water, pink on land

Run from the repo root, after download.py heights and lake_level.py: python tools/map/visible.py
"""
import json

import numpy as np
from PIL import Image, ImageDraw

import readers
import silvaplana_area as area

CELL_M = 50.0             # analysis grid
OBSERVER_SPACING_M = 250.0
DIRECTIONS = 4096         # lines of sight per viewpoint, about 45 m apart at 30 km
MAX_DISTANCE_M = 30_000.0
# Samples along a line of sight: every 25 m for the first 5 km, then every 50 m (the cell size).
DISTANCES_M = np.concatenate([np.arange(25.0, 5_000.0, 25.0), np.arange(5_000.0, MAX_DISTANCE_M + 1.0, 50.0)])
EARTH_RADIUS_M = 6_371_000.0
REFRACTION = 0.13         # the usual coefficient for light bending in the air near the ground


def downsample(grid: readers.Grid, factor: int) -> readers.Grid:
    rows, columns = grid.heights.shape[0] // factor, grid.heights.shape[1] // factor
    blocks = grid.heights[:rows * factor, :columns * factor].reshape(rows, factor, columns, factor)
    return readers.Grid(np.nanmean(blocks, axis=(1, 3)).astype(np.float32), grid.west_m, grid.north_m, grid.cell_m * factor)


def lattice(east_range: tuple[float, float], north_range: tuple[float, float]) -> list[tuple[float, float]]:
    eastings = np.arange(east_range[0], east_range[1] + 1.0, OBSERVER_SPACING_M)
    northings = np.arange(north_range[0], north_range[1] + 1.0, OBSERVER_SPACING_M)
    return [(float(e), float(n)) for e in eastings for n in northings]


def lake_points(bathy: readers.Grid) -> list[tuple[float, float]]:
    """Points every OBSERVER_SPACING_M on the lake, where the lakebed survey has a depth."""
    points = []
    for east, north in lattice(area.LAKE_EAST_M, area.LAKE_NORTH_M):
        row, column = bathy.cell_of(east, north)
        inside = 0 <= row < bathy.heights.shape[0] and 0 <= column < bathy.heights.shape[1]
        if inside and not np.isnan(bathy.heights[row, column]):
            points.append((east, north))
    return points


def shore_points(terrain: readers.Grid, lake: np.ndarray) -> list[tuple[float, float]]:
    """Points every OBSERVER_SPACING_M on land in the shore band, within SHORE_VIEW_DISTANCE_M of the water."""
    rows, columns = np.nonzero(lake)
    water_east = terrain.west_m + (columns + 0.5) * terrain.cell_m
    water_north = terrain.north_m - (rows + 0.5) * terrain.cell_m
    band_east = (area.SHORE_TILES_EAST_KM[0] * 1000.0, (area.SHORE_TILES_EAST_KM[-1] + 1) * 1000.0)
    band_north = (area.SHORE_TILES_NORTH_KM[0] * 1000.0, (area.SHORE_TILES_NORTH_KM[-1] + 1) * 1000.0)
    points = []
    for east, north in lattice(band_east, band_north):
        row, column = terrain.cell_of(east, north)
        if lake[row, column]:
            continue
        nearest_water = np.min(np.hypot(water_east - east, water_north - north))
        if nearest_water <= area.SHORE_VIEW_DISTANCE_M:
            points.append((east, north))
    return points


def visibility(terrain: readers.Grid, eyes: list[tuple[float, float, float]]) -> np.ndarray:
    """Which cells can be seen from at least one eye (east, north, eye height above sea level)."""
    seen = np.zeros(terrain.heights.shape, dtype=bool)
    heights = np.nan_to_num(terrain.heights, nan=-1e6)
    bearings = np.linspace(0.0, 2.0 * np.pi, DIRECTIONS, endpoint=False)[:, None]
    distances = DISTANCES_M[None, :]
    drop = distances ** 2 * (1.0 - REFRACTION) / (2.0 * EARTH_RADIUS_M)
    for east, north, eye_level_m in eyes:
        sample_east = east + distances * np.sin(bearings)
        sample_north = north + distances * np.cos(bearings)
        rows = ((terrain.north_m - sample_north) // terrain.cell_m).astype(int)
        columns = ((sample_east - terrain.west_m) // terrain.cell_m).astype(int)
        inside = (rows >= 0) & (rows < heights.shape[0]) & (columns >= 0) & (columns < heights.shape[1])
        rows = np.clip(rows, 0, heights.shape[0] - 1)
        columns = np.clip(columns, 0, heights.shape[1] - 1)
        # The slope of the line from the eye to each sample; visible if no closer sample is steeper.
        slope = (heights[rows, columns] - drop - eye_level_m) / distances
        slope[~inside] = -np.inf
        highest_before = np.maximum.accumulate(slope, axis=1)
        highest_before = np.concatenate([np.full((DIRECTIONS, 1), -np.inf), highest_before[:, :-1]], axis=1)
        visible = inside & (slope >= highest_before)
        seen[rows[visible], columns[visible]] = True
    return seen


def relief(heights: np.ndarray, cell_m: float) -> np.ndarray:
    """Grey hillshade, light from the north-west, values 0 to 1."""
    dz_dy, dz_dx = np.gradient(np.nan_to_num(heights, nan=np.nanmean(heights)), cell_m)
    light = np.array([-1.0, 1.0, 1.0]) / np.sqrt(3.0)   # from the north-west and above (x east, y north)
    normal = np.dstack([-dz_dx, dz_dy, np.ones_like(heights)])  # row index runs south, so flip dz/dy
    normal /= np.linalg.norm(normal, axis=2, keepdims=True)
    return np.clip(normal @ light, 0.0, 1.0)


def save_picture(terrain: readers.Grid, by_sailor: np.ndarray, by_any: np.ndarray, lake: np.ndarray,
                 points: dict[str, list[tuple[float, float]]], path) -> None:
    shade = relief(terrain.heights, terrain.cell_m)[..., None]
    rgb = (60 + 170 * shade) * np.ones(3)
    rgb = np.where(by_any[..., None], np.array([250.0, 215.0, 60.0]) * (0.45 + 0.55 * shade), rgb)
    rgb = np.where(by_sailor[..., None], np.array([235.0, 130.0, 30.0]) * (0.45 + 0.55 * shade), rgb)
    rgb[lake] = (40, 110, 210)
    image = Image.fromarray(rgb.astype(np.uint8))
    draw = ImageDraw.Draw(image)

    def pixel(east: float, north: float) -> tuple[float, float]:
        return (east - terrain.west_m) / terrain.cell_m, (terrain.north_m - north) / terrain.cell_m

    for kind, colour in (("lake", (220, 30, 30)), ("shore", (230, 60, 200))):
        for east, north in points[kind]:
            x, y = pixel(east, north)
            draw.ellipse([x - 1.5, y - 1.5, x + 1.5, y + 1.5], fill=colour)
    west, north = pixel(area.SHORE_TILES_EAST_KM[0] * 1000.0, (area.SHORE_TILES_NORTH_KM[-1] + 1) * 1000.0)
    east, south = pixel((area.SHORE_TILES_EAST_KM[-1] + 1) * 1000.0, area.SHORE_TILES_NORTH_KM[0] * 1000.0)
    draw.rectangle([west, north, east, south], outline=(255, 255, 255))
    for km in range(0, 100, 10):  # a 10 km grid
        x, _ = pixel(2_750_000.0 + km * 1000.0, 0.0)
        _, y = pixel(0.0, 1_120_000.0 + km * 1000.0)
        draw.line([x, 0, x, image.height], fill=(255, 255, 255))
        draw.line([0, y, image.width, y], fill=(255, 255, 255))
    draw.rectangle([0, 0, 610, 34], fill=(0, 0, 0))
    draw.text((6, 4), "North is up. Grid: 10 km. White box: shore band (full detail).", fill=(255, 255, 255))
    draw.text((6, 19), "Orange: the sailor sees it. Yellow: only the cameras see it. Blue: lake.", fill=(255, 255, 255))
    image.save(path)


def describe(name: str, seen: np.ndarray, terrain: readers.Grid) -> set[tuple[int, int]]:
    rows, columns = np.nonzero(seen)
    east = terrain.west_m + (columns + 0.5) * terrain.cell_m
    north = terrain.north_m - (rows + 0.5) * terrain.cell_m
    distance_km = np.hypot(east - sum(area.LAKE_EAST_M) / 2.0, north - sum(area.LAKE_NORTH_M) / 2.0) / 1000.0
    tiles = {(int(e // 1000), int(n // 1000)) for e, n in zip(east, north)}
    print(f"  {name:22s} {seen.sum() * CELL_M ** 2 / 1e6:5.0f} km2 in {len(tiles):3d} tiles of 1 km, "
          f"farthest {distance_km.max():4.1f} km, 90 % within {np.percentile(distance_km, 90):4.1f} km")
    return tiles


def main() -> None:
    lake_level = json.loads((area.WORK_DIR / "lake.json").read_text())["lake_level_m"]
    terrain = downsample(readers.read_regio(), int(CELL_M / 10.0))
    lake = np.abs(terrain.heights - lake_level) < 0.5
    points = {"lake": lake_points(readers.read_bathy()), "shore": shore_points(terrain, lake)}
    print(f"Viewpoints: {len(points['lake'])} on the lake, {len(points['shore'])} on the shore")

    seen_by: dict[str, np.ndarray] = {}
    for name, on, height_m in area.VIEWPOINTS:
        eyes = []
        for east, north in points[on]:
            ground = lake_level if on == "lake" else terrain.height_at(east, north)
            eyes.append((east, north, ground + height_m))
        seen_by[name] = visibility(terrain, eyes)

    print("Visible land and water:")
    for name, _, height_m in area.VIEWPOINTS:
        describe(f"{name} ({height_m:.0f} m)", seen_by[name], terrain)
    by_any = np.logical_or.reduce(list(seen_by.values()))
    tiles = describe("all together", by_any, terrain) | set(area.shore_tiles())
    edge = by_any[0, :].any() or by_any[-1, :].any() or by_any[:, 0].any() or by_any[:, -1].any()
    if edge:
        print("WARNING: visible land reaches the edge of the swissALTIRegio area; add tiles in silvaplana_area.py.")

    area.WORK_DIR.mkdir(parents=True, exist_ok=True)
    (area.WORK_DIR / "visible_tiles.json").write_text(json.dumps({"tiles_1km": sorted(tiles), "cell_m": CELL_M}, indent=0))
    np.savez_compressed(area.WORK_DIR / "visible_50m.npz", west=terrain.west_m, north=terrain.north_m, cell=CELL_M,
                        any=by_any, **{name.replace(" ", "_"): seen for name, seen in seen_by.items()})
    save_picture(terrain, seen_by["sailor"], by_any, lake, points, area.WORK_DIR / "visible_map.png")
    print(f"Picture: {(area.WORK_DIR / 'visible_map.png').relative_to(area.REPO_ROOT)}")


if __name__ == "__main__":
    main()
