"""Cuts the aerial photos (SWISSIMAGE) into one texture per terrain chunk (Documentation/MAP_SILVAPLANA_PLAN.md, M2).

Every chunk of tools/map/heights.py gets one image that covers its square exactly, north at the
top, so the chunk's UVs from tools/blender/build_terrain.py map it straight on. How sharp:

  where                                         per km     metres per pixel   source
  the camping, the launch beach, the lake's
  north end (two tiles, SHARP_CHUNKS)           8192 px    0.12 m             SWISSIMAGE 10 cm
  the rest of the shore band (near)             2048 px    0.49 m             SWISSIMAGE 10 cm
  up to 8 km from the lake (mid, far)            512 px    1.95 m             SWISSIMAGE 2 m
  further away (distant)                         128 px    7.8 m              SWISSIMAGE 2 m

Further away the screen shows less detail than that anyway: from the water, 2 m at 3 km and 8 m
at 8 km are about one screen pixel.

Where there is no Swiss photo (22 visible tiles in Italy, and the holes in a chunk where nothing
is built), the colour comes from the height and the slope instead: the script learns which
colour the Swiss photos have at each height, steepness and lighting, and paints that.

Writes Game/maps/silvaplana/terrain/photos/<chunk>.webp, with a .import file that tells Godot to
make far-away versions (mipmaps) and compress the texture for the graphics card. Generated,
don't edit. Also writes .map_data/work/terrain/photo_fallback.png, a picture of the learned
colours for the team.

Run from the repo root, after download.py photos-near photos-far and heights.py:
  python tools/map/photos.py [--only=<chunk name part>]
"""
import glob
import json
import sys
import warnings

import numpy as np
import tifffile
from PIL import Image

import heights
import readers
import silvaplana_area as area

OUT = area.GAME_MAP_DIR / "terrain" / "photos"
TERRAIN = area.WORK_DIR / "terrain"

PIXELS_PER_KM = {"near": 2048, "mid": 512, "far": 512, "distant": 128}
# The launch: Camping Silvaplana and its beach lie on the border of these two tiles (the camping
# reaches from LV95 east 2780.69 to 2781.03 km), and the second one has the lake's north end.
SHARP_CHUNKS = {"near_2780_1147": 8192, "near_2781_1147": 8192}
WEBP_QUALITY = 82

# The light in the photos: the shadows of the trees and houses fall to the north-west, so the
# 2025 flight was in the morning, with the sun in the south-east, about 50 degrees up.
PHOTO_SUN_AZIMUTH_DEG = 140.0
PHOTO_SUN_ELEVATION_DEG = 50.0
# The colour table's steps: height in 100 m, slope in 5 degrees, lighting in 6 steps.
HEIGHT_STEP_M, LOWEST_M, HEIGHT_STEPS = 100.0, 1000.0, 35
SLOPE_STEP_DEG, SLOPE_STEPS = 5.0, 18
LIGHT_STEPS = 6
# Flatter than this, a 20 m cell of the height data is a lake surface (land is never this flat).
LAKE_SLOPE_DEG = 0.05
# How strongly the small ridges and gullies of the 10 m heights lighten and darken the painted
# colour, so painted ground has some of the texture of a photo.
PAINT_DETAIL = 1.2

IMPORT_SETTINGS = """[remap]

importer="texture"
type="CompressedTexture2D"

[params]

compress/mode=2
compress/high_quality=false
mipmaps/generate=true
mipmaps/limit=-1
detect_3d/compress_to=0
"""


# ---- The photos ------------------------------------------------------------------------------

def photo_tile(east_km: int, north_km: int, pixels: int) -> np.ndarray | None:
    """The photo of one 1 km tile at `pixels` x `pixels`. When more than the 2 m photo's 500
    pixels are needed, the 10 cm photo is used if there is one. None where there is no Swiss photo."""
    sources = [("swissimage_10cm", "0.1"), ("swissimage_2m", "2")] if pixels > 500 else [("swissimage_2m", "2")]
    for folder, resolution in sources:
        files = sorted(glob.glob(str(area.RAW_DIR / folder / f"swissimage-dop10_*_{east_km}-{north_km}_{resolution}_2056.tif")))
        if files:
            image = tifffile.imread(files[-1])[..., :3]
            return np.asarray(Image.fromarray(image).resize((pixels, pixels), Image.LANCZOS, reducing_gap=3.0))
    return None


# ---- Colours where there is no photo ---------------------------------------------------------

def slope_and_light(h: np.ndarray, cell_m: float) -> tuple[np.ndarray, np.ndarray]:
    """The slope in degrees, and how much the photo's morning sun lights each cell (0 to 1)."""
    d_north, d_east = np.gradient(h, cell_m)
    d_north = -d_north  # row 0 is the north edge
    normal = np.stack([-d_east, -d_north, np.ones_like(h)], axis=-1)
    normal /= np.linalg.norm(normal, axis=-1, keepdims=True)
    azimuth, elevation = np.radians(PHOTO_SUN_AZIMUTH_DEG), np.radians(PHOTO_SUN_ELEVATION_DEG)
    sun = np.array([np.sin(azimuth) * np.cos(elevation), np.cos(azimuth) * np.cos(elevation), np.sin(elevation)])
    return np.degrees(np.arccos(normal[..., 2])), np.clip(normal @ sun, 0.0, 1.0)


def table_index(h: np.ndarray, slope: np.ndarray, light: np.ndarray) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    e = np.clip(((h - LOWEST_M) / HEIGHT_STEP_M).astype(int), 0, HEIGHT_STEPS - 1)
    s = np.clip((slope / SLOPE_STEP_DEG).astype(int), 0, SLOPE_STEPS - 1)
    l = np.clip((light * LIGHT_STEPS).astype(int), 0, LIGHT_STEPS - 1)
    return e, s, l


class ColourTable:
    """The average photo colour for each height, slope and lighting, learned from the 2 m photos
    of every visible Swiss tile. Combinations seen fewer than MIN_SAMPLES times fall back to the
    average over all lighting, then over all slopes, then to the overall average."""

    MIN_SAMPLES = 20

    def __init__(self, regio20: readers.Grid) -> None:
        self.regio20 = regio20
        slope, light = slope_and_light(regio20.heights, 20.0)
        sums = np.zeros((HEIGHT_STEPS, SLOPE_STEPS, LIGHT_STEPS, 3))
        counts = np.zeros((HEIGHT_STEPS, SLOPE_STEPS, LIGHT_STEPS))
        visible = json.loads((area.WORK_DIR / "visible_tiles.json").read_text())["tiles_1km"]
        for east_km, north_km in visible:
            photo = photo_tile(east_km, north_km, 500)
            if photo is None:
                continue
            colour = photo.astype(np.float32).reshape(50, 10, 50, 10, 3).mean(axis=(1, 3))
            row = int(round((regio20.north_m - (north_km + 1) * 1000.0) / 20.0))
            column = int(round((east_km * 1000.0 - regio20.west_m) / 20.0))
            cut = (slice(row, row + 50), slice(column, column + 50))
            # Leave out the lakes: they are exactly flat in the height data, and their dark blue
            # would end up on flat ground in the painted areas.
            land = slope[cut] > LAKE_SLOPE_DEG
            e, s, l = table_index(regio20.heights[cut][land], slope[cut][land], light[cut][land])
            np.add.at(sums, (e, s, l), colour[land])
            np.add.at(counts, (e, s, l), 1)
        self.full = self._average(sums, counts)
        self.no_light = self._average(sums.sum(axis=2), counts.sum(axis=2))
        self.height_only = self._average(sums.sum(axis=(1, 2)), counts.sum(axis=(1, 2)))
        self.overall = sums.sum(axis=(0, 1, 2)) / counts.sum()
        self.counts = counts
        print(f"Colour table learned from {int(counts.sum()):,} photo cells of 20 m")

    def _average(self, sums: np.ndarray, counts: np.ndarray) -> np.ndarray:
        with np.errstate(invalid="ignore", divide="ignore"):
            average = sums / counts[..., None]
        average[counts < self.MIN_SAMPLES] = np.nan
        return average

    def colour(self, h: np.ndarray, slope: np.ndarray, light: np.ndarray) -> np.ndarray:
        e, s, l = table_index(h, slope, light)
        result = self.full[e, s, l]
        for fallback in (self.no_light[e, s], self.height_only[e]):
            missing = np.isnan(result[..., 0])
            result[missing] = fallback[missing]
        result[np.isnan(result[..., 0])] = self.overall
        return result

    def prepare_painting(self, regio: readers.Grid) -> None:
        """Works out once, for the whole area, what paint() needs: the table's colour of every
        20 m cell, and the small ridges and gullies (the light of the 10 m heights minus that of
        the 20 m heights)."""
        g20 = self.regio20
        slope20, light20 = slope_and_light(g20.heights, 20.0)
        colour20 = self.colour(g20.heights, slope20, light20).astype(np.float32)
        self.colour_grids = [readers.Grid(colour20[..., c].copy(), g20.west_m, g20.north_m, 20.0) for c in range(3)]
        _, light10 = slope_and_light(regio.heights, 10.0)
        self.light10 = readers.Grid(light10.astype(np.float32), regio.west_m, regio.north_m, 10.0)
        self.light20 = readers.Grid(light20.astype(np.float32), g20.west_m, g20.north_m, 20.0)
        self.extent = (regio.west_m, regio.east_m, regio.south_m, regio.north_m)

    def paint(self, west_m: float, north_m: float, size_m: float, pixels: int) -> np.ndarray:
        """An image of a square from the table: the colour from the 20 m heights, made lighter and
        darker by the small ridges and gullies of the 10 m heights so the ground doesn't look
        smooth. Outside the height data: the overall average colour."""
        centres = (np.arange(pixels) + 0.5) * size_m / pixels
        east, north = west_m + centres, north_m - centres
        image = np.stack([heights.sample(grid, east, north) for grid in self.colour_grids], axis=-1)
        detail = heights.sample(self.light10, east, north) - heights.sample(self.light20, east, north)
        image *= np.clip(1.0 + PAINT_DETAIL * detail, 0.5, 1.6)[..., None]
        west, east_edge, south, north_edge = self.extent
        outside = ((north > north_edge) | (north < south))[:, None] | ((east < west) | (east > east_edge))[None, :]
        image[outside] = self.overall
        return np.clip(image, 0, 255).astype(np.uint8)


def table_picture(table: ColourTable) -> None:
    """The learned colours, for the team: height upward, slope to the right, lighting averaged."""
    cell = 16
    image = np.full((HEIGHT_STEPS * cell, SLOPE_STEPS * cell, 3), 255, dtype=np.uint8)
    for e in range(HEIGHT_STEPS):
        for s in range(SLOPE_STEPS):
            colour = table.no_light[e, s]
            if not np.isnan(colour[0]):
                image[(HEIGHT_STEPS - 1 - e) * cell:(HEIGHT_STEPS - e) * cell, s * cell:(s + 1) * cell] = colour.astype(np.uint8)
    Image.fromarray(image).resize((image.shape[1] * 2, image.shape[0] * 2), Image.NEAREST).save(TERRAIN / "photo_fallback.png")


# ---- Per chunk -------------------------------------------------------------------------------

def chunk_photo(chunk: dict, table: ColourTable) -> tuple[np.ndarray, int, int]:
    """The image of one chunk, and how many of its tiles have a real photo and how many are painted."""
    size_km = int(chunk["size_m"] // 1000)
    per_km = SHARP_CHUNKS.get(chunk["name"], PIXELS_PER_KM[chunk["zone"]])
    pixels = size_km * per_km
    west_km, north_km = int(chunk["west_m"] // 1000), int(chunk["north_m"] // 1000)
    cells = np.load(TERRAIN / chunk["file"])["cells"]
    cells_per_km = cells.shape[0] // size_km
    # The photos of the tiles this chunk has; (i, j) is the tile's column (west to east) and row
    # (north to south) inside the chunk. Tiles the chunk doesn't have (holes) need no photo.
    photos: dict[tuple[int, int], np.ndarray] = {}
    built = 0
    for i in range(size_km):
        for j in range(size_km):
            if cells[j * cells_per_km, i * cells_per_km]:
                built += 1
                tile = photo_tile(west_km + i, north_km - 1 - j, per_km)
                if tile is not None:
                    photos[(i, j)] = tile
    if len(photos) == size_km * size_km:
        image = np.zeros((pixels, pixels, 3), dtype=np.uint8)
    else:
        image = table.paint(chunk["west_m"], chunk["north_m"], chunk["size_m"], pixels)
    for (i, j), tile in photos.items():
        image[j * per_km:(j + 1) * per_km, i * per_km:(i + 1) * per_km] = tile
    return image, len(photos), built - len(photos)


def main() -> None:
    only = next((a.split("=", 1)[1] for a in sys.argv[1:] if a.startswith("--only=")), "")
    info = json.loads((TERRAIN / "chunks.json").read_text())
    regio = readers.read_regio()
    with warnings.catch_warnings():
        warnings.simplefilter("ignore", RuntimeWarning)
        regio20 = readers.Grid(heights.block_mean(regio.heights, 2), regio.west_m, regio.north_m, 20.0)
    table = ColourTable(regio20)
    table.prepare_painting(regio)
    table_picture(table)
    OUT.mkdir(parents=True, exist_ok=True)
    total_bytes, painted_tiles = 0, 0
    for chunk in info["chunks"]:
        if only and only not in chunk["name"]:
            continue
        image, photographed, painted = chunk_photo(chunk, table)
        path = OUT / f"{chunk['name']}.webp"
        Image.fromarray(image).save(path, quality=WEBP_QUALITY, method=4)
        import_file = path.with_name(path.name + ".import")
        if not import_file.exists():
            import_file.write_text(IMPORT_SETTINGS, encoding="utf-8")
        total_bytes += path.stat().st_size
        painted_tiles += painted
        print(f"{chunk['name']}: {image.shape[1]} px, {photographed} tiles photographed, {painted} painted, "
              f"{path.stat().st_size / 1e6:.1f} MB")
    print(f"Wrote {OUT.relative_to(area.REPO_ROOT)}: {total_bytes / 1e6:.1f} MB; "
          f"{painted_tiles} built tiles without a Swiss photo were painted from the heights")


if __name__ == "__main__":
    main()
