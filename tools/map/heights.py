"""Turns the raw height data into the game terrain's height grids (Documentation/MAP_SILVAPLANA_PLAN.md,
phase M1, decisions MD4 and MD5).

All heights it writes are metres above the lake surface (the lake level in lake.json), so the
water is at 0 and the lakebed is below 0, exactly as the game's Y axis (MD1).

The land is built in four detail levels ("zones"). Close to the lake you see every metre; far away
the haze and the distance hide the detail anyway. The spacings are chosen so that one grid cell
looks about equally big from the water at every distance (about 0.3 degrees):

  zone     grid    where                                         source
  near     2 m     the shore band (25 tiles of 1 km)             swissALTI3D 0.5 m and the swissBATHY3D lakebed
  mid      10 m    visible tiles up to 3 km from the lake        swissALTIRegio 10 m
  far      20 m    visible tiles 3 to 8 km from the lake         swissALTIRegio, averaged
  distant  40 m    visible tiles further away                    swissALTIRegio, averaged

Every 1 km tile is a grid of vertices on its corners, and tiles are grouped into chunks (one 3D
mesh each, built by tools/blender/build_terrain.py). Where two zones meet, the finer tile's edge
follows the coarser tile's edge exactly ("stitching"), so the meshes join without cracks.

Inside the lake the heights come from the swissBATHY3D lakebed (MD5). Where the water was too
shallow for the survey (under about 1 m), the bottom is filled in smoothly from the shoreline (0 m)
to the first surveyed depth.

Writes:
  .map_data/work/terrain/<chunk>.npz       one height grid per chunk, for Blender
  .map_data/work/terrain/chunks.json       the list of chunks: where they lie, how much Blender thins them
  .map_data/work/terrain/zones.png         a picture of the zones, for the team
  Game/maps/silvaplana/terrain/shore_heights.bin and .json
                                           the shore band's heights at 2 m for the game logic: the
                                           depth under the board and the shoreline (M3). Generated,
                                           don't edit.

Run from the repo root, after download.py heights, lake_level.py and visible.py:
  python tools/map/heights.py
"""
import json
import math
import warnings

import numpy as np
from PIL import Image, ImageDraw

import readers
import silvaplana_area as area


class Zone:
    """One detail level of the terrain.

    keep:    the share of triangles Blender keeps when it thins out the mesh (flat ground first)
    skirt_m: how far the hidden strip around each chunk hangs down. It covers any hairline gap
             between neighbouring chunks when Godot shows a simpler version of one of them far away.
    """

    def __init__(self, name: str, cell_m: float, chunk_km: int, up_to_m: float, keep: float, skirt_m: float) -> None:
        self.name = name
        self.cell_m = cell_m
        self.chunk_km = chunk_km
        self.up_to_m = up_to_m
        self.keep = keep
        self.skirt_m = skirt_m


ZONES = [
    Zone("near", cell_m=2.0, chunk_km=1, up_to_m=0.0, keep=0.10, skirt_m=5.0),
    Zone("mid", cell_m=10.0, chunk_km=2, up_to_m=3_000.0, keep=0.35, skirt_m=25.0),
    Zone("far", cell_m=20.0, chunk_km=4, up_to_m=8_000.0, keep=0.50, skirt_m=50.0),
    Zone("distant", cell_m=40.0, chunk_km=8, up_to_m=math.inf, keep=0.60, skirt_m=100.0),
]
NEAR, MID, FAR, DISTANT = range(4)

OUT = area.WORK_DIR / "terrain"
GAME_TERRAIN = area.GAME_MAP_DIR / "terrain"

# A cell of the height data counts as lake surface when it is this close to the lake level:
# swissALTI3D and swissALTIRegio show the lakes as exactly flat.
FLAT_LAKE_TOLERANCE_M = 0.02
# Lake that the survey didn't reach is at least this deep, so the water always covers it.
MIN_DEPTH_M = 0.05
# The game grid stores heights as 16-bit numbers: height = offset + value * scale.
GAME_GRID_SCALE_M = 0.025
GAME_GRID_OFFSET_M = -100.0


# ---- Reading and combining the sources -------------------------------------------------------

def block_mean(heights: np.ndarray, factor: int) -> np.ndarray:
    """Averages blocks of factor x factor cells into one; blocks without any data stay NaN."""
    rows, columns = heights.shape[0] // factor, heights.shape[1] // factor
    blocks = heights[:rows * factor, :columns * factor].reshape(rows, factor, columns, factor)
    with warnings.catch_warnings():
        warnings.simplefilter("ignore", RuntimeWarning)
        return np.nanmean(blocks, axis=(1, 3)).astype(np.float32)


def lakebed(bathy: readers.Grid, cell_m: float) -> readers.Grid:
    """The swissBATHY3D lakebed averaged to cell_m, on cell edges that are multiples of cell_m, so
    it can be pasted into any of the zone grids."""
    west = math.floor(bathy.west_m / cell_m) * cell_m
    north = math.ceil(bathy.north_m / cell_m) * cell_m
    east = math.ceil(bathy.east_m / cell_m) * cell_m
    south = math.floor(bathy.south_m / cell_m) * cell_m
    canvas = readers.Grid(np.full((int(north - south), int(east - west)), np.nan, dtype=np.float32), west, north, 1.0)
    readers.paste(canvas, bathy)
    return readers.Grid(block_mean(canvas.heights, int(cell_m)), west, north, cell_m)


def fill_shallows(heights: np.ndarray, lake: np.ndarray, surveyed: np.ndarray) -> int:
    """MD5: gives the lake cells the survey didn't reach a smooth bottom, from the shoreline (0 m)
    to the nearest surveyed depths. Every such cell becomes the average of its four neighbours,
    again and again, until nothing changes any more: that settles into the smoothest surface that
    touches both the shore and the survey. Changes `heights` in place, returns the cells filled."""
    todo = lake & ~surveyed
    if not todo.any():
        return 0
    # Land counts as the shoreline (0 m); outside the grid too (the zero padding).
    work = np.pad(np.where(lake, heights, 0.0), 1).astype(np.float64)
    work[1:-1, 1:-1][todo] = -MIN_DEPTH_M
    columns = work.shape[1]
    rows, cols = np.nonzero(todo)
    index = (rows + 1) * columns + (cols + 1)
    flat = work.ravel()
    for _ in range(50_000):
        new = 0.25 * (flat[index - 1] + flat[index + 1] + flat[index - columns] + flat[index + columns])
        change = float(np.max(np.abs(new - flat[index])))
        flat[index] = new
        if change < 1e-5:
            break
    heights[todo] = np.minimum(flat[index], -MIN_DEPTH_M)
    return int(todo.sum())


def add_lakebed(ground: readers.Grid, bathy: readers.Grid, lake_level: float) -> None:
    """Replaces the flat lake surface in a grid of heights above the lake by the lakebed (MD5)."""
    bed = lakebed(bathy, ground.cell_m)
    bed.heights -= lake_level
    # Only below the water: the survey also has a strip of shore, where swissALTI3D is better.
    bed.heights[bed.heights > -FLAT_LAKE_TOLERANCE_M] = np.nan
    on_ground = readers.Grid(np.full(ground.heights.shape, np.nan, dtype=np.float32), ground.west_m, ground.north_m, ground.cell_m)
    readers.paste(on_ground, bed)
    surveyed = ~np.isnan(on_ground.heights)
    flat_lake = np.abs(ground.heights) < FLAT_LAKE_TOLERANCE_M
    ground.heights[surveyed] = on_ground.heights[surveyed]
    filled = fill_shallows(ground.heights, flat_lake | surveyed, surveyed)
    print(f"  {ground.cell_m:.0f} m grid: lakebed in {surveyed.sum():,} cells, shallows filled in {filled:,} cells "
          f"({filled * ground.cell_m ** 2 / 1e6:.2f} km2)")


def near_grid(lake_level: float, bathy: readers.Grid) -> readers.Grid:
    """The shore band at 2 m (cell means of swissALTI3D 0.5 m), relative to the lake, with the lakebed."""
    cell = ZONES[NEAR].cell_m
    tiles = []
    for east_km, north_km in area.shore_tiles():
        tile = readers.read_alti3d_tile(east_km, north_km)
        tiles.append(readers.Grid(block_mean(tile.heights, int(cell / tile.cell_m)), tile.west_m, tile.north_m, cell))
    ground = readers.mosaic(tiles, cell)
    ground.heights -= lake_level
    add_lakebed(ground, bathy, lake_level)
    return ground


def regio_grid(lake_level: float, bathy: readers.Grid) -> readers.Grid:
    """The surroundings at 10 m (swissALTIRegio), relative to the lake, with the lakebed."""
    regio = readers.read_regio()
    ground = readers.Grid(regio.heights - lake_level, regio.west_m, regio.north_m, regio.cell_m)
    add_lakebed(ground, bathy, lake_level)
    return ground


def sample(grid: readers.Grid, east: np.ndarray, north: np.ndarray) -> np.ndarray:
    """Heights at the points (east[j], north[i]) by bilinear interpolation between the cell centres.
    Points outside the grid get the nearest edge value. Returns an array of len(north) x len(east)."""
    rows, columns = grid.heights.shape
    fx = np.clip((east - grid.west_m) / grid.cell_m - 0.5, 0.0, columns - 1.0)
    fy = np.clip((grid.north_m - north) / grid.cell_m - 0.5, 0.0, rows - 1.0)
    x0 = np.minimum(np.floor(fx).astype(int), columns - 2)
    y0 = np.minimum(np.floor(fy).astype(int), rows - 2)
    tx = (fx - x0)[None, :]
    ty = (fy - y0)[:, None]
    h = grid.heights
    top = h[np.ix_(y0, x0)] * (1.0 - tx) + h[np.ix_(y0, x0 + 1)] * tx
    bottom = h[np.ix_(y0 + 1, x0)] * (1.0 - tx) + h[np.ix_(y0 + 1, x0 + 1)] * tx
    return (top * (1.0 - ty) + bottom * ty).astype(np.float32)


# ---- Which tile gets which detail ------------------------------------------------------------

def lake_points(bathy: readers.Grid, spacing_m: float = 50.0) -> tuple[np.ndarray, np.ndarray]:
    """Points every spacing_m where the lakebed survey has a depth: where the lake is."""
    factor = int(spacing_m / bathy.cell_m)
    blocks = block_mean(bathy.heights, factor)
    rows, columns = np.nonzero(~np.isnan(blocks))
    return bathy.west_m + (columns + 0.5) * spacing_m, bathy.north_m - (rows + 0.5) * spacing_m


def tile_zones(bathy: readers.Grid) -> dict[tuple[int, int], int]:
    """The zone of every tile that gets built: the shore band, plus every visible tile by its
    distance from the lake (the nearest lake point to any part of the tile)."""
    visible = json.loads((area.WORK_DIR / "visible_tiles.json").read_text())["tiles_1km"]
    lake_east, lake_north = lake_points(bathy)
    zones = {tile: NEAR for tile in area.shore_tiles()}
    for east_km, north_km in visible:
        if (east_km, north_km) in zones:
            continue
        dx = np.maximum(0.0, np.abs(lake_east - (east_km * 1000.0 + 500.0)) - 500.0)
        dy = np.maximum(0.0, np.abs(lake_north - (north_km * 1000.0 + 500.0)) - 500.0)
        distance = float(np.min(np.hypot(dx, dy)))
        zones[(east_km, north_km)] = next(i for i in (MID, FAR, DISTANT) if distance <= ZONES[i].up_to_m)
    return zones


# ---- Vertex grids, stitched ------------------------------------------------------------------

class ZoneMosaic:
    """The vertices of all tiles of one zone, in one array, with one extra ring of vertices around
    it (the "halo", only used by Blender to work out the slope at the edge). Vertices sit on the
    grid corners, so tile edges fall exactly on the kilometre lines and neighbours share them."""

    def __init__(self, zone: Zone, tiles: list[tuple[int, int]], base) -> None:
        self.zone = zone
        # base(east, north): the zone's source heights at any vertex positions.
        self.base = base
        self.cell_m = zone.cell_m
        self.per_tile = int(round(1000.0 / zone.cell_m))
        self.west_km = min(e for e, _ in tiles)
        self.north_km = max(n for _, n in tiles) + 1
        east_km = max(e for e, _ in tiles) + 1
        south_km = min(n for _, n in tiles)
        count_east = (east_km - self.west_km) * self.per_tile + 1
        count_north = (self.north_km - south_km) * self.per_tile + 1
        # Positions of the vertices, halo included.
        self.east = self.west_km * 1000.0 + (np.arange(count_east + 2) - 1) * zone.cell_m
        self.north = self.north_km * 1000.0 - (np.arange(count_north + 2) - 1) * zone.cell_m
        self.heights = base(self.east, self.north)

    def tile(self, east_km: int, north_km: int) -> np.ndarray:
        """The vertices of one tile, as a view: changing it changes the mosaic."""
        row = 1 + (self.north_km - (north_km + 1)) * self.per_tile
        column = 1 + (east_km - self.west_km) * self.per_tile
        return self.heights[row:row + self.per_tile + 1, column:column + self.per_tile + 1]


# The four sides of a tile: the neighbour's offset in km, and how to cut the side out of the
# tile's vertices (north and south run west to east, west and east run north to south).
SIDES = {
    "north": ((0, 1), lambda v: v[0, :]),
    "south": ((0, -1), lambda v: v[-1, :]),
    "west": ((-1, 0), lambda v: v[:, 0]),
    "east": ((1, 0), lambda v: v[:, -1]),
}
OPPOSITE = {"north": "south", "south": "north", "west": "east", "east": "west"}


def set_side(vertices: np.ndarray, side: str, values: np.ndarray) -> None:
    if side == "north":
        vertices[0, :] = values
    elif side == "south":
        vertices[-1, :] = values
    elif side == "west":
        vertices[:, 0] = values
    else:
        vertices[:, -1] = values


def stitch(zones: dict[tuple[int, int], int], mosaics: list[ZoneMosaic]) -> int:
    """Makes neighbouring tiles of different zones meet exactly.

    1. Each corner shared by several tiles takes the value of the coarsest of them.
    2. Along a side where a tile meets a coarser neighbour, the tile's vertices are put on the
       straight lines between the neighbour's vertices.
    Tiles of the same zone already agree: they share their vertices in the zone's mosaic.
    Returns the number of sides stitched."""
    def vertices(tile: tuple[int, int]) -> np.ndarray:
        return mosaics[zones[tile]].tile(*tile)

    corner_value: dict[tuple[int, int], tuple[float, float]] = {}
    for (e, n), zone in zones.items():
        v = vertices((e, n))
        for corner, value in (((e, n + 1), v[0, 0]), ((e + 1, n + 1), v[0, -1]), ((e, n), v[-1, 0]), ((e + 1, n), v[-1, -1])):
            cell = ZONES[zone].cell_m
            if corner not in corner_value or cell > corner_value[corner][0]:
                corner_value[corner] = (cell, float(value))
    for (e, n) in zones:
        v = vertices((e, n))
        v[0, 0] = corner_value[(e, n + 1)][1]
        v[0, -1] = corner_value[(e + 1, n + 1)][1]
        v[-1, 0] = corner_value[(e, n)][1]
        v[-1, -1] = corner_value[(e + 1, n)][1]

    stitched = 0
    for (e, n), zone in zones.items():
        for side, ((de, dn), _) in SIDES.items():
            neighbour = (e + de, n + dn)
            if neighbour not in zones or ZONES[zones[neighbour]].cell_m <= ZONES[zone].cell_m:
                continue
            coarse = SIDES[OPPOSITE[side]][1](vertices(neighbour))
            step = int(round(ZONES[zones[neighbour]].cell_m / ZONES[zone].cell_m))
            fine_count = (len(coarse) - 1) * step + 1
            set_side(vertices((e, n)), side, np.interp(np.arange(fine_count), np.arange(len(coarse)) * step, coarse))
            stitched += 1
    return stitched


def check_seams(zones: dict[tuple[int, int], int], mosaics: list[ZoneMosaic]) -> float:
    """The largest height difference between neighbouring tiles where they share a vertex, and
    between a fine tile's side and the straight lines of its coarser neighbour. Should be 0."""
    worst = 0.0
    for (e, n), zone in zones.items():
        for side, ((de, dn), cut) in SIDES.items():
            neighbour = (e + de, n + dn)
            if neighbour not in zones or ZONES[zones[neighbour]].cell_m < ZONES[zone].cell_m:
                continue
            mine = cut(mosaics[zone].tile(e, n))
            theirs = SIDES[OPPOSITE[side]][1](mosaics[zones[neighbour]].tile(*neighbour))
            step = int(round(ZONES[zones[neighbour]].cell_m / ZONES[zone].cell_m))
            expected = np.interp(np.arange(len(mine)), np.arange(len(theirs)) * step, theirs)
            worst = max(worst, float(np.max(np.abs(mine - expected))))
    return worst


# ---- Output ----------------------------------------------------------------------------------

def write_chunks(zones: dict[tuple[int, int], int], mosaics: list[ZoneMosaic], lake: dict) -> list[dict]:
    """Groups each zone's tiles into square chunks and writes one height grid per chunk:
      heights  the chunk's vertices with the halo ring around them (rows + 2 by columns + 2)
      cells    which grid cells belong to the chunk (tiles of other zones, or not built, are holes)
    """
    OUT.mkdir(parents=True, exist_ok=True)
    chunks = []
    for index, zone in enumerate(ZONES):
        mosaic = mosaics[index]
        groups: dict[tuple[int, int], list[tuple[int, int]]] = {}
        for (e, n), z in zones.items():
            if z == index:
                key = (e // zone.chunk_km * zone.chunk_km, n // zone.chunk_km * zone.chunk_km)
                groups.setdefault(key, []).append((e, n))
        for (west_km, south_km), tiles in sorted(groups.items()):
            per_chunk = zone.chunk_km * mosaic.per_tile
            north_km = south_km + zone.chunk_km
            # Where the chunk's halo starts in the mosaic; it may reach outside the mosaic, so
            # sample those vertices from the same source the mosaic was made of.
            row0 = (mosaic.north_km - north_km) * mosaic.per_tile
            column0 = (west_km - mosaic.west_km) * mosaic.per_tile
            east = west_km * 1000.0 + (np.arange(per_chunk + 3) - 1) * zone.cell_m
            north = north_km * 1000.0 - (np.arange(per_chunk + 3) - 1) * zone.cell_m
            heights = np.full((per_chunk + 3, per_chunk + 3), np.nan, dtype=np.float32)
            r0, c0 = max(row0, 0), max(column0, 0)
            r1 = min(row0 + per_chunk + 3, mosaic.heights.shape[0])
            c1 = min(column0 + per_chunk + 3, mosaic.heights.shape[1])
            heights[r0 - row0:r1 - row0, c0 - column0:c1 - column0] = mosaic.heights[r0:r1, c0:c1]
            missing = np.isnan(heights)
            if missing.any():
                heights[missing] = mosaic.base(east, north)[missing]
            cells = np.zeros((per_chunk, per_chunk), dtype=bool)
            for e, n in tiles:
                r = (north_km - (n + 1)) * mosaic.per_tile
                c = (e - west_km) * mosaic.per_tile
                cells[r:r + mosaic.per_tile, c:c + mosaic.per_tile] = True
            name = f"{zone.name}_{west_km}_{south_km}"
            np.savez_compressed(OUT / f"{name}.npz", heights=heights, cells=cells)
            chunks.append({
                "name": name, "zone": zone.name, "file": f"{name}.npz", "tiles": len(tiles),
                "cell_m": zone.cell_m, "size_m": zone.chunk_km * 1000.0,
                "west_m": west_km * 1000.0, "north_m": north_km * 1000.0,
                "keep": zone.keep, "skirt_m": zone.skirt_m,
            })
    (OUT / "chunks.json").write_text(json.dumps({
        "about": "Terrain chunks for tools/blender/build_terrain.py, written by tools/map/heights.py. "
                 "west_m/north_m: LV95 of the chunk's north-west corner (the first vertex after the halo).",
        "origin_east_m": lake["origin_east_m"], "origin_north_m": lake["origin_north_m"],
        "lake_level_m": lake["lake_level_m"], "chunks": chunks,
    }, indent=1))
    return chunks


def write_game_grid(near: ZoneMosaic, lake: dict) -> None:
    """The shore band's vertices (the same heights the near meshes are made of, before thinning)
    as 16-bit numbers, for the game logic (MD3: grids for the logic, meshes for the looks)."""
    heights = near.heights[1:-1, 1:-1]
    values = np.round((heights - GAME_GRID_OFFSET_M) / GAME_GRID_SCALE_M)
    assert values.min() >= 0 and values.max() <= 65535, "The shore band's heights don't fit the 16-bit range"
    GAME_TERRAIN.mkdir(parents=True, exist_ok=True)
    values.astype("<u2").tofile(GAME_TERRAIN / "shore_heights.bin")
    west_m, north_m = float(near.east[1]), float(near.north[1])
    (GAME_TERRAIN / "shore_heights.json").write_text(json.dumps({
        "about": "The shore band's heights for the game logic, written by tools/map/heights.py: don't edit. "
                 "height above the lake surface (m) = height_offset_m + value * height_scale_m",
        "file": "shore_heights.bin",
        "format": "uint16 little-endian, row by row from the north edge, each row from west to east",
        "columns": int(heights.shape[1]), "rows": int(heights.shape[0]), "cell_m": near.cell_m,
        "west_m": west_m, "north_m": north_m,
        "x0_m": west_m - lake["origin_east_m"], "z0_m": -(north_m - lake["origin_north_m"]),
        "height_scale_m": GAME_GRID_SCALE_M, "height_offset_m": GAME_GRID_OFFSET_M,
        "lake_level_m": lake["lake_level_m"],
    }, indent=1))
    print(f"Game grid: {heights.shape[1]} x {heights.shape[0]} at {near.cell_m:.0f} m, "
          f"{(GAME_TERRAIN / 'shore_heights.bin').stat().st_size / 1e6:.1f} MB")


def zone_picture(zones: dict[tuple[int, int], int], bathy: readers.Grid) -> None:
    """A picture of which tile has which detail: dark = near (2 m) to light = distant (40 m)."""
    colours = [(200, 60, 40), (235, 140, 50), (240, 200, 90), (245, 235, 170)]
    pixels = 12
    west, north = min(area.REGIO_TILES_EAST_KM), max(area.REGIO_TILES_NORTH_KM) + 10
    size = 50 * pixels
    image = Image.new("RGB", (size, size), (235, 235, 235))
    draw = ImageDraw.Draw(image)
    for (e, n), zone in zones.items():
        x, y = (e - west) * pixels, (north - 1 - n) * pixels
        draw.rectangle([x, y, x + pixels - 1, y + pixels - 1], fill=colours[zone])
    lake_east, lake_north = lake_points(bathy, 100.0)
    for e, n in zip(lake_east, lake_north):
        x, y = (e / 1000.0 - west) * pixels, (north - n / 1000.0) * pixels
        draw.point((x, y), fill=(30, 90, 200))
    for i, zone in enumerate(ZONES):
        draw.rectangle([8, 8 + i * 16, 20, 20 + i * 16], fill=colours[i])
        draw.text((26, 8 + i * 16), f"{zone.name}: {zone.cell_m:.0f} m", fill=(0, 0, 0))
    image.save(OUT / "zones.png")


def main() -> None:
    lake = json.loads((area.WORK_DIR / "lake.json").read_text())
    lake_level = lake["lake_level_m"]
    bathy = readers.read_bathy()

    print("Height grids:")
    near = near_grid(lake_level, bathy)
    regio = regio_grid(lake_level, bathy)
    far = readers.Grid(block_mean(regio.heights, 2), regio.west_m, regio.north_m, 20.0)
    distant = readers.Grid(block_mean(regio.heights, 4), regio.west_m, regio.north_m, 40.0)

    band_west, band_north = near.west_m, near.north_m
    band_east, band_south = near.east_m, near.south_m

    def near_base(east: np.ndarray, north: np.ndarray) -> np.ndarray:
        """The shore band's 2 m data inside the band, swissALTIRegio around it (for the halo)."""
        result = sample(regio, east, north)
        inside_east = (east >= band_west) & (east <= band_east)
        inside_north = (north >= band_south) & (north <= band_north)
        inside = inside_north[:, None] & inside_east[None, :]
        result[inside] = sample(near, east, north)[inside]
        return result

    bases = [near_base,
             lambda e, n: sample(regio, e, n),
             lambda e, n: sample(far, e, n),
             lambda e, n: sample(distant, e, n)]

    assert not np.isnan(regio.heights).any(), "swissALTIRegio has holes: run tools/map/download.py heights"
    zones = tile_zones(bathy)
    mosaics = []
    for index, zone in enumerate(ZONES):
        tiles = [t for t, z in zones.items() if z == index]
        mosaics.append(ZoneMosaic(zone, tiles, bases[index]))
        print(f"  {zone.name}: {len(tiles)} tiles at {zone.cell_m:.0f} m")

    stitched = stitch(zones, mosaics)
    worst = check_seams(zones, mosaics)
    print(f"Stitched {stitched} tile sides between zones; largest step at a seam: {worst * 1000:.2f} mm")
    assert worst < 0.001, "Neighbouring tiles don't meet: the stitching is broken"

    for mosaic in mosaics:
        for tile, zone in zones.items():
            if mosaic.zone is ZONES[zone]:
                assert not np.isnan(mosaic.tile(*tile)).any(), f"Tile {tile} has holes (NaN) in its heights"

    chunks = write_chunks(zones, mosaics, lake)
    vertices = sum(c["tiles"] * (1000.0 / c["cell_m"] + 1) ** 2 for c in chunks)
    print(f"Wrote {len(chunks)} chunks to {OUT.relative_to(area.REPO_ROOT)} ({vertices / 1e6:.1f} million vertices before thinning)")
    write_game_grid(mosaics[NEAR], lake)
    zone_picture(zones, bathy)
    band = mosaics[NEAR].heights[1:-1, 1:-1]
    print(f"Shore band: lakebed down to {float(band.min()):.1f} m, land up to {float(band.max()):.0f} m above the lake")


if __name__ == "__main__":
    main()
