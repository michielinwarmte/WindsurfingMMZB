"""A sea spot's sea from its region (backlog E02.S03 and E02.S04; first Fuerteventura, Sotavento,
Documentation/reports/spots/sotavento/PLAN.md, P3): what the game's waves need from beyond the spot's
own map, worked out once, offline.

    python -I tools/map/spot_sea.py tools/map/spots/sotavento.json [--check]

1. The region: EMODnet's heights (sea and land) over the config's sea.region box, downloaded in tiles
   into .map_data/<slug>/raw/, put on a grid of sea.cell_m in the spot's frame.
2. The far fetch: from points along the spot's near grid's edges, the open water upwind along every
   bearing (sea.bearing_step_deg apart) until land, or out of the region (then sea.open_sea_fetch_m:
   the open Atlantic, where the growth law has long stopped growing). The game's fetch map starts its
   rays with these where they leave the near grid (FetchMap.edge_fetch), so the wind sea grows over
   the whole channel, not only over the 12 km of the map.
3. The swell's exposure: at every node of a coarse grid over the near box, the share of an ocean swell
   from each direction that reaches it, from the open ocean, without crossing land: the swell's
   energy spread over directions as cos^(2s)((theta - theta0) / 2) (Mitsuyasu et al. 1975; s =
   sea.swell_spreading_s, 15 to 25 for swell), each direction open if the line back towards it runs
   over water for sea.open_water_m. Diffraction round the headlands is left out (it would add a
   little in the lee; the check against the measured climate says how much is missing).
4. --check: the numbers at the coastal study's model points (SIMAR, Marrero-Rodriguez et al. 2021) and
   at Open-Meteo's marine model point, for the plan's section on the sea's realism.

Writes Game/maps/<slug>/sea.json. Needs numpy, scipy, tifffile, pyproj.
"""
import json
import math
import sys
import urllib.request
from pathlib import Path

import numpy as np
import tifffile
from pyproj import Transformer
from scipy import ndimage

REPO = Path(__file__).resolve().parents[2]
USER_AGENT = {"User-Agent": "windsurf-game-map-builder/1.0"}
G = 9.81


def load_config(path: str) -> dict:
    return json.loads(Path(path).read_text(encoding="utf-8"))


def emodnet_tiles(config: dict, raw: Path) -> list[Path]:
    """The region's EMODnet heights in 1 x 1.5 degree tiles (the server refuses bigger pieces)."""
    south, west, north, east = config["sea"]["region_latlon"]
    paths = []
    lat = south
    while lat < north - 1e-9:
        lon = west
        while lon < east - 1e-9:
            lat1, lon1 = min(lat + 1.0, north), min(lon + 1.5, east)
            path = raw / f"emodnet_region_{lat:.2f}_{lon:.2f}.tif"
            if not path.exists() or path.stat().st_size < 10000:
                url = ("https://ows.emodnet-bathymetry.eu/wcs?service=WCS&version=2.0.1&request=GetCoverage"
                       f"&CoverageId=emodnet__mean&subset=Lat({lat},{lat1})&subset=Long({lon},{lon1})&format=image/tiff")
                with urllib.request.urlopen(urllib.request.Request(url, headers=USER_AGENT), timeout=300) as response:
                    path.write_bytes(response.read())
                print(f"  downloaded {path.name}")
            paths.append(path)
            lon = lon1
        lat = lat1
    return paths


def region_grid(config: dict, raw: Path) -> tuple[np.ndarray, float, float, float]:
    """The region's heights (m, negative under the sea) on a grid of sea.cell_m in the spot's frame:
    (grid rows from the north, west edge east, north edge north, cell)."""
    sea = config["sea"]
    cell = float(sea["cell_m"])
    to_frame = Transformer.from_crs("EPSG:4326", config["crs"], always_xy=True)
    to_geo = Transformer.from_crs(config["crs"], "EPSG:4326", always_xy=True)
    south, west, north, east = sea["region_latlon"]
    xs, ys = to_frame.transform([west, east, west, east], [south, south, north, north])
    x0, x1, y0, y1 = max(xs[0], xs[2]), min(xs[1], xs[3]), max(ys[0], ys[1]), min(ys[2], ys[3])
    columns, rows = int((x1 - x0) / cell), int((y1 - y0) / cell)
    east_c = x0 + (np.arange(columns) + 0.5) * cell
    north_c = y1 - (np.arange(rows) + 0.5) * cell
    grid_e, grid_n = np.meshgrid(east_c, north_c)
    lon, lat = to_geo.transform(grid_e, grid_n)
    heights = np.full(grid_e.shape, np.nan)
    for path in emodnet_tiles(config, raw):
        with tifffile.TiffFile(path) as tif:
            page = tif.pages[0]
            data = page.asarray().astype(np.float64)
            m = page.tags["ModelTransformationTag"].value
        lon0, dlon, lat0, dlat = m[3], m[0], m[7], m[5]
        cols = (lon - lon0) / dlon - 0.5
        rws = (lat - lat0) / dlat - 0.5
        inside = (cols >= 0) & (cols <= data.shape[1] - 1) & (rws >= 0) & (rws <= data.shape[0] - 1)
        values = ndimage.map_coordinates(data, [rws[inside], cols[inside]], order=1, mode="nearest")
        heights[inside] = values
    heights[np.isnan(heights)] = -1000.0  # outside every tile: open sea
    return heights, x0, y1, cell


class Region:
    """The region's water and land, and lines across it."""

    def __init__(self, heights: np.ndarray, west: float, north: float, cell: float):
        self.water = heights < 0.0
        self.west, self.north, self.cell = west, north, cell
        self.rows, self.columns = heights.shape

    def is_water(self, east: float, north: float) -> int:
        """1 water, 0 land, -1 outside the region."""
        c = int((east - self.west) / self.cell)
        r = int((self.north - north) / self.cell)
        if c < 0 or r < 0 or c >= self.columns or r >= self.rows:
            return -1
        return 1 if self.water[r, c] else 0

    def open_water_m(self, east: float, north: float, towards_deg: float, limit_m: float, step_m: float) -> tuple[float, bool]:
        """How far the water runs from a point towards a bearing (until land), and whether the line left
        the region over water (the open ocean beyond)."""
        dx, dy = math.sin(math.radians(towards_deg)), math.cos(math.radians(towards_deg))
        distance = 0.0
        while distance < limit_m:
            distance += step_m
            state = self.is_water(east + dx * distance, north + dy * distance)
            if state == 0:
                return distance - step_m / 2.0, False
            if state < 0:
                return distance, True
        return limit_m, True


def open_water_many(region: Region, easts: np.ndarray, norths: np.ndarray, towards_deg: float, limit_m: float,
                    step_m: float) -> np.ndarray:
    """open_water_m for many points at once (the same bearing): the distance to land, or limit_m where
    the line leaves the region over water or reaches the limit."""
    dx, dy = math.sin(math.radians(towards_deg)), math.cos(math.radians(towards_deg))
    result = np.full(easts.shape, float(limit_m))
    running = np.ones(easts.shape, dtype=bool)
    distance = 0.0
    while distance < limit_m and running.any():
        distance += step_m
        c = ((easts + dx * distance - region.west) / region.cell).astype(int)
        r = ((region.north - (norths + dy * distance)) / region.cell).astype(int)
        outside = (c < 0) | (r < 0) | (c >= region.columns) | (r >= region.rows)
        land = np.zeros(easts.shape, dtype=bool)
        inside = ~outside
        land[inside] = ~region.water[r[inside], c[inside]]
        hit = running & land
        result[hit] = distance - step_m / 2.0
        running &= ~(land | outside)
    return result


def far_fetch(config: dict, region: Region) -> dict:
    """Along the near grid's edges, every edge_step_m: the open water upwind along every bearing (the
    wind comes FROM the bearing, so the water upwind lies towards it)."""
    sea = config["sea"]
    x0, y0, x1, y1 = config["near"]["box"]
    step = float(sea["edge_step_m"])
    points = []
    for x in np.arange(x0, x1 + 1, step):
        points += [(x, y1), (x, y0)]
    for y in np.arange(y0 + step, y1, step):
        points += [(x0, y), (x1, y)]
    easts = np.array([p[0] for p in points])
    norths = np.array([p[1] for p in points])
    on_land = np.array([region.is_water(e, n) == 0 for e, n in points])
    bearings = np.arange(0.0, 360.0, float(sea["bearing_step_deg"]))
    columns = []
    for b in bearings:
        f = open_water_many(region, easts, norths, b, sea["open_sea_fetch_m"], sea["ray_step_m"])
        f[on_land] = 0.0
        columns.append(f)
    fetch = np.round(np.stack(columns, axis=1)).astype(int)
    origin_e, origin_n = config["origin_east_m"], config["origin_north_m"]
    return {"bearing_step_deg": float(sea["bearing_step_deg"]),
            "points": [[round(e - origin_e, 1), round(-(n - origin_n), 1)] for e, n in points],
            "fetch_m": fetch.tolist()}


def spreading_weights(s: float, step_deg: float) -> tuple[np.ndarray, np.ndarray]:
    """The cos^(2s)(dtheta / 2) spread of a swell's energy over directions, normalised."""
    offsets = np.arange(-90.0, 90.0 + step_deg / 2, step_deg)
    w = np.cos(np.radians(offsets) / 2.0) ** (2.0 * s)
    return offsets, w / w.sum()


def exposure_at(region: Region, east: float, north: float, from_deg: float, sea: dict) -> float:
    """The share of an ocean swell from from_deg that reaches a point over water from the open ocean."""
    offsets, weights = spreading_weights(sea["swell_spreading_s"], sea["swell_ray_step_deg"])
    total = 0.0
    for off, w in zip(offsets, weights):
        distance, left = region.open_water_m(east, north, from_deg + off, sea["open_water_m"], sea["ray_step_m"])
        if left or distance >= sea["open_water_m"]:
            total += w
    return total


def exposure_grid(config: dict, region: Region) -> dict:
    """The swell's exposure at the nodes of a coarse grid over the near box, for every direction: first
    which bearings are open (water all the way to the open ocean) from each node, then each swell
    direction's spread over them."""
    sea = config["sea"]
    x0, y0, x1, y1 = config["near"]["box"]
    cell = float(sea["exposure_cell_m"])
    easts = np.arange(x0 + cell / 2, x1, cell)
    norths = np.arange(y1 - cell / 2, y0, -cell)
    grid_e, grid_n = np.meshgrid(easts, norths)
    flat_e, flat_n = grid_e.ravel(), grid_n.ravel()
    water = np.array([region.is_water(e, n) == 1 for e, n in zip(flat_e, flat_n)])
    ray_step = float(sea["swell_ray_step_deg"])
    bearings = np.arange(0.0, 360.0, ray_step)
    open_by_bearing = np.zeros((len(bearings), flat_e.size), dtype=bool)
    for k, b in enumerate(bearings):
        d = open_water_many(region, flat_e[water], flat_n[water], b, sea["open_water_m"], sea["ray_step_m"])
        open_by_bearing[k, water] = d >= sea["open_water_m"] - 1e-6
    offsets, weights = spreading_weights(sea["swell_spreading_s"], ray_step)
    directions = np.arange(0.0, 360.0, float(sea["exposure_direction_step_deg"]))
    values = np.zeros((len(directions), flat_e.size), dtype=np.uint8)
    for j, d in enumerate(directions):
        share = np.zeros(flat_e.size)
        for off, w in zip(offsets, weights):
            k = int(round(((d + off) % 360.0) / ray_step)) % len(bearings)
            share += w * open_by_bearing[k]
        values[j] = np.round(255 * np.clip(share, 0.0, 1.0)).astype(np.uint8)
    origin_e, origin_n = config["origin_east_m"], config["origin_north_m"]
    return {"cell_m": cell, "x0_m": float(easts[0] - origin_e), "z0_m": float(-(norths[0] - origin_n)),
            "columns": len(easts), "rows": len(norths), "direction_step_deg": float(sea["exposure_direction_step_deg"]),
            "exposure_255": values.tolist()}


# ---------------------------------------------------------------- the checks

def spm_height_period(wind_ms: float, fetch_m: float) -> tuple[float, float]:
    """The game's growth law (WindWaves, PHYSICS_SPEC.md 9.16 and 9.17): the Shore Protection Manual's
    (1984) fetch-limited JONSWAP growth with the wind at 10 m as it is, capped at full development."""
    x = G * fetch_m / wind_ms ** 2
    hs = min(0.0016 * x ** 0.5, 0.2433) * wind_ms ** 2 / G
    tp = min(0.286 * x ** (1.0 / 3.0), 8.134) * wind_ms / G
    return hs, tp


def effective_fetch(region: Region, east: float, north: float, from_deg: float, sea: dict) -> float:
    """The SPM's averaged fetch (nine rays six degrees apart, weighted by the cosine)."""
    total, weights = 0.0, 0.0
    for j in range(-4, 5):
        angle = 6.0 * j
        distance, left = region.open_water_m(east, north, from_deg + angle, sea["open_sea_fetch_m"], sea["ray_step_m"])
        f = float(sea["open_sea_fetch_m"]) if left else distance
        w = math.cos(math.radians(angle))
        total += f * w * w
        weights += w
    return total / weights


def check(config: dict, region: Region) -> None:
    sea = config["sea"]
    to_frame = Transformer.from_crs("EPSG:4326", config["crs"], always_xy=True)
    print("\nThe fetch and the wind sea (SPM, deep water) at the checkpoints:")
    for point in sea["checkpoints"]:
        e, n = to_frame.transform(point["lon"], point["lat"])
        line = []
        for b in (0, 25, 45, 65, 90):
            f = effective_fetch(region, e, n, b, sea)
            hs, tp = spm_height_period(10.3, f)  # 20 kt
            line.append(f"{b:3d}deg {f / 1000:5.1f} km -> Hs {hs:.2f} m Tp {tp:.1f} s")
        print(f"  {point['name']}: " + "; ".join(line))
    print("\nThe swell's exposure (share of an ocean swell reaching the point):")
    for point in sea["checkpoints"]:
        e, n = to_frame.transform(point["lon"], point["lat"])
        values = [f"{d:3d}: {exposure_at(region, e, n, d, sea):.2f}" for d in range(0, 360, 30)]
        print(f"  {point['name']}: " + ", ".join(values))


def main() -> None:
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    config = load_config(args[0])
    raw = REPO / ".map_data" / config["slug"] / "raw"
    raw.mkdir(parents=True, exist_ok=True)
    heights, west, north, cell = region_grid(config, raw)
    region = Region(heights, west, north, cell)
    print(f"region {region.columns} x {region.rows} cells of {cell:.0f} m, water {region.water.mean():.0%}")
    if "--check" in sys.argv:
        check(config, region)
        return
    out = {"about": f"{config['name']}: the sea from its region, written by tools/map/spot_sea.py: don't edit. far_fetch: the open water upwind "
                    "(m) along each bearing the wind comes from, at points (game x, z) along the near grid's edges; swell_exposure: the share "
                    "(of 255) of an ocean swell from each direction reaching each node of a coarse grid over the near box.",
           "far_fetch": far_fetch(config, region),
           "swell_exposure": exposure_grid(config, region)}
    path = REPO / "Game" / "maps" / config["slug"] / "sea.json"
    path.write_text(json.dumps(out), encoding="utf-8")
    print(f"wrote {path} ({path.stat().st_size / 1e6:.1f} MB)")


if __name__ == "__main__":
    main()
