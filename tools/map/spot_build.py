"""Builds a sea spot's map from open data, from one config file (backlog E04.S02, the generic
pipeline; first used for Fuerteventura, Sotavento, E04.S12).

    python -I tools/map/spot_build.py tools/map/spots/sotavento.json [--stage=download|grids|photos|buildings|all]

What it makes, in Game/maps/<slug>/terrain/:
- near_heights.bin/.json: the ground and the sea bed at `near.cell_m` over the sailing area, in metres
  above mean sea level, in the TerrainGrid format the game reads (Game/maps/terrain_grid.gd). The
  game logic (the shore check, the waves' depth) and the terrain's looks (HeightTerrain draws this
  grid on the graphics card) read the same file.
- far_heights.bin/.json: the same at `far.cell_m` over a much bigger box, for the land on the
  horizon.
- near_photo.webp, detail_photo.webp, far_photo.webp: the aerial photo over the near box, a sharper
  one over the detail box (the launch and the lagoon) and a coarse one over the far box.
- preview.png in .map_data/<slug>/: the heights in colour, to look at.

Where the heights come from (Documentation/reports/spots/sotavento/PLAN.md, sections 2 and 3):
- the land from the national terrain model (IGN MDT05 near, MDT25 far, by WCS);
- the deep sea from EMODnet's bathymetry (about 115 m cells);
- the near shore, where EMODnet is blind, from a measured profile: the depth at a distance from the
  waterline (the config's shore_profile), blended into EMODnet further out;
- the lagoon and the bar shaped from the photo's colours (decision D1): the photo says where there
  is water, wet sand and dry sand, the open sea is found by spreading from deep water with the bar's
  openings closed, and each kind of ground gets the config's height.

The downloads are kept in .map_data/<slug>/raw/ and fetched only once. Needs numpy, scipy, tifffile,
Pillow and pyproj (pip install numpy scipy tifffile pillow pyproj).
"""
import json
import math
import sys
import urllib.parse
import urllib.request
from pathlib import Path

import numpy as np
import tifffile
from PIL import Image
from pyproj import Transformer
from scipy import ndimage

REPO = Path(__file__).resolve().parents[2]
USER_AGENT = {"User-Agent": "Mozilla/5.0 (windsurf game map builder)"}
NODATA_TERRAIN = -32768.0


# ---------------------------------------------------------------- the config and the folders

class Spot:
    """The config file, and the folders it writes to."""

    def __init__(self, config_path: str):
        self.config = json.loads(Path(config_path).read_text(encoding="utf-8"))
        self.slug = self.config["slug"]
        self.raw = REPO / ".map_data" / self.slug / "raw"
        self.work = REPO / ".map_data" / self.slug
        self.out = REPO / "Game" / "maps" / self.slug / "terrain"
        self.raw.mkdir(parents=True, exist_ok=True)
        self.out.mkdir(parents=True, exist_ok=True)

    def box(self, name: str) -> list[float]:
        return self.config[name]["box"] if name in ("near", "far") else self.config["photos"][name]["box"]


# ---------------------------------------------------------------- downloads

def fetch(url: str, path: Path) -> Path:
    """Downloads url to path unless the file is already there."""
    if path.exists() and path.stat().st_size > 0:
        return path
    request = urllib.request.Request(url, headers=USER_AGENT)
    with urllib.request.urlopen(request, timeout=300) as response:
        data = response.read()
    path.write_bytes(data)
    print(f"  downloaded {path.name}: {len(data) / 1e6:.1f} MB")
    return path


def idee_terrain(spot: Spot, coverage: str, box: list[float], name: str) -> Path:
    """The IGN terrain model (MDT) for a box in the spot's frame, by the national WCS."""
    x0, y0, x1, y1 = box
    url = ("https://servicios.idee.es/wcs-inspire/mdt?service=WCS&version=2.0.1&request=GetCoverage"
           f"&CoverageId={coverage}&subset=x({x0:.0f},{x1:.0f})&subset=y({y0:.0f},{y1:.0f})&format=image/tiff")
    return fetch(url, spot.raw / name)


def emodnet(spot: Spot, box: list[float]) -> Path:
    """EMODnet's mean depth over a box (asked in latitude and longitude, with a margin)."""
    to_geo = Transformer.from_crs(spot.config["crs"], "EPSG:4326", always_xy=True)
    lons, lats = to_geo.transform([box[0], box[2], box[0], box[2]], [box[1], box[1], box[3], box[3]])
    lon0, lon1 = min(lons) - 0.05, max(lons) + 0.05
    lat0, lat1 = min(lats) - 0.05, max(lats) + 0.05
    url = ("https://ows.emodnet-bathymetry.eu/wcs?service=WCS&version=2.0.1&request=GetCoverage"
           f"&CoverageId=emodnet__mean&subset=Lat({lat0:.4f},{lat1:.4f})&subset=Long({lon0:.4f},{lon1:.4f})"
           "&format=image/tiff")
    return fetch(url, spot.raw / "emodnet.tif")


def pnoa_photo(spot: Spot, box: list[float], tiles: int, tile_px: int, name: str) -> Image.Image:
    """The PNOA aerial photo over a box, asked in tiles x tiles pieces and put together."""
    x0, y0, x1, y1 = box
    step_x = (x1 - x0) / tiles
    step_y = (y1 - y0) / tiles
    whole = Image.new("RGB", (tiles * tile_px, tiles * tile_px))
    for row in range(tiles):
        for column in range(tiles):
            tx0 = x0 + column * step_x
            ty1 = y1 - row * step_y
            url = ("https://www.ign.es/wms-inspire/pnoa-ma?service=WMS&version=1.3.0&request=GetMap"
                   f"&layers=OI.OrthoimageCoverage&styles=&crs={spot.config['crs']}"
                   f"&bbox={tx0:.1f},{ty1 - step_y:.1f},{tx0 + step_x:.1f},{ty1:.1f}"
                   f"&width={tile_px}&height={tile_px}&format=image/jpeg")
            path = fetch(url, spot.raw / f"{name}_{row}_{column}.jpg")
            whole.paste(Image.open(path).convert("RGB"), (column * tile_px, row * tile_px))
    return whole


def download(spot: Spot) -> None:
    print("Downloading (only what is missing):")
    idee_terrain(spot, spot.config["sources"]["terrain_near"]["coverage"], spot.box("near"), "terrain_near.tif")
    idee_terrain(spot, spot.config["sources"]["terrain_far"]["coverage"], spot.box("far"), "terrain_far.tif")
    emodnet(spot, spot.box("far"))
    for name in ("near", "detail", "far"):
        settings = spot.config["photos"][name]
        box = spot.box("near") if name == "near" else spot.box("far") if name == "far" else settings["box"]
        pnoa_photo(spot, box, settings["tiles"], settings["tile_px"], f"photo_{name}")


# ---------------------------------------------------------------- reading rasters onto a grid

def grid_centres(box: list[float], cell_m: float) -> tuple[np.ndarray, np.ndarray]:
    """The east and north coordinates of the grid's nodes: cell centres, rows from the north."""
    x0, y0, x1, y1 = box
    columns = int(round((x1 - x0) / cell_m))
    rows = int(round((y1 - y0) / cell_m))
    east = x0 + (np.arange(columns) + 0.5) * cell_m
    north = y1 - (np.arange(rows) + 0.5) * cell_m
    return east, north


def read_terrain(path: Path, box: list[float], cell_m: float) -> np.ndarray:
    """The IGN terrain model on the grid's nodes (NaN where it has no value: the sea).
    The WCS answers on exactly the asked box, so for the same cell size this is a straight read;
    otherwise the nearest value."""
    with tifffile.TiffFile(path) as tif:
        page = tif.pages[0]
        data = page.asarray().astype(np.float64)
        tags = {tag.name: tag.value for tag in page.tags.values()}
    data[data <= NODATA_TERRAIN + 1] = np.nan
    scale_x, scale_y = tags["ModelPixelScaleTag"][:2]
    tie_x, tie_y = tags["ModelTiepointTag"][3:5]
    east, north = grid_centres(box, cell_m)
    columns = np.clip(((east - tie_x) / scale_x).astype(int), 0, data.shape[1] - 1)
    rows = np.clip(((tie_y - north) / scale_y).astype(int), 0, data.shape[0] - 1)
    return data[np.ix_(rows, columns)]


def read_emodnet(path: Path, spot: Spot, box: list[float], cell_m: float) -> np.ndarray:
    """EMODnet's heights (negative under the sea) on the grid's nodes, interpolated between its
    cells (bilinear). EMODnet is in latitude and longitude, so every node is turned into those."""
    with tifffile.TiffFile(path) as tif:
        page = tif.pages[0]
        data = page.asarray().astype(np.float64)
        matrix = page.tags["ModelTransformationTag"].value
    lon_step, lon0 = matrix[0], matrix[3]
    lat_step, lat0 = matrix[5], matrix[7]  # lat_step is negative: rows go south
    east, north = grid_centres(box, cell_m)
    grid_east, grid_north = np.meshgrid(east, north)
    to_geo = Transformer.from_crs(spot.config["crs"], "EPSG:4326", always_xy=True)
    lon, lat = to_geo.transform(grid_east, grid_north)
    columns = (lon - lon0) / lon_step - 0.5
    rows = (lat - lat0) / lat_step - 0.5
    return ndimage.map_coordinates(data, [rows, columns], order=1, mode="nearest")


def photo_on_grid(photo: Image.Image, columns: int, rows: int) -> np.ndarray:
    """The photo averaged onto the grid's cells, as floats 0..255 (rows, columns, 3)."""
    return np.asarray(photo.resize((columns, rows), Image.BOX), dtype=np.float64)


# ---------------------------------------------------------------- the near grid: shore, lagoon, bar

def interpolate_profile(distance_m: np.ndarray, profile: dict) -> np.ndarray:
    """Depth below mean sea level at a distance from the waterline, from the config's knots;
    beyond the last knot it keeps the last slope."""
    knots_d = np.array(profile["distance_m"], dtype=np.float64)
    knots_h = np.array(profile["depth_m"], dtype=np.float64)
    depth = np.interp(distance_m, knots_d, knots_h)
    last_slope = (knots_h[-1] - knots_h[-2]) / (knots_d[-1] - knots_d[-2])
    beyond = distance_m > knots_d[-1]
    depth[beyond] = knots_h[-1] + (distance_m[beyond] - knots_d[-1]) * last_slope
    return depth


def disk(radius_cells: int) -> np.ndarray:
    span = np.arange(-radius_cells, radius_cells + 1)
    return (span[:, None] ** 2 + span[None, :] ** 2) <= radius_cells ** 2


def classify_photo(rgb: np.ndarray) -> dict[str, np.ndarray]:
    """What the photo shows in each cell. Water is bluer than it is red (the turquoise shallows, the
    dark sea grass under the water and the deep navy alike); sand is bright and grey-yellow, redder
    than it is blue; the salt marsh's shrubs are darker sand. Black and white are the photo's empty
    parts (out at sea)."""
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    total = r + g + b
    empty = (total < 15) | (total > 750)
    water = empty | (b > r + 12)
    brightness = total / 3.0
    dry_sand = ~water & (brightness >= 195)
    wet_sand = ~water & (brightness < 195) & (brightness >= 150)
    marsh = ~water & (brightness < 150)
    return {"empty": empty, "water": water, "dry_sand": dry_sand, "wet_sand": wet_sand, "marsh": marsh}


def near_heights(spot: Spot) -> tuple[np.ndarray, dict]:
    """The near grid's heights above mean sea level, and the masks (for the preview)."""
    config = spot.config
    box = spot.box("near")
    cell = config["near"]["cell_m"]
    lagoon = config["lagoon"]
    terrain = read_terrain(spot.raw / "terrain_near.tif", box, cell)
    rows, columns = terrain.shape
    sea_bed = read_emodnet(spot.raw / "emodnet.tif", spot, box, cell)
    photo = pnoa_photo(spot, box, config["photos"]["near"]["tiles"], config["photos"]["near"]["tile_px"], "photo_near")
    seen = classify_photo(photo_on_grid(photo, columns, rows))

    # Land the terrain model is sure of: 3 m and higher (it has whole metres only: the lagoon floor
    # and the beach read 0 or 1, and sand strips inside the lagoon 2, where its older LiDAR caught
    # the moving bar; the dunes pass 3 m within a few metres of their foot).
    high_land = np.nan_to_num(terrain, nan=-1.0) >= 3.0
    # Only high land joined to the real land (the dunes, the hills) or big on its own (10 ha): the
    # terrain model's LiDAR is older than the photos, and a sand strip it measured at 2 m inside the
    # lagoon has since moved (the bar moves landward about 2.3 m a year and its tip changes a lot,
    # Marrero-Rodriguez et al. 2021); the photo decides there.
    land_labels, _count = ndimage.label(high_land)
    land_sizes = np.bincount(land_labels.ravel()) * cell * cell
    land_sizes[0] = 0.0
    high_land = (land_labels > 0) & (land_sizes[land_labels] >= 100000.0)
    water = seen["water"] & ~high_land
    # Specks of "sand" out at sea (whitecaps, boats, the photo's seams) are water: keep only the dry
    # ground that touches the high land or is big (the bar, a sand bank: more than 0.5 ha).
    dry_labels, _count = ndimage.label(~water)
    sizes = np.bincount(dry_labels.ravel())
    touching_land = np.unique(dry_labels[high_land])
    keep = sizes * cell * cell >= 5000.0
    keep[touching_land] = True
    keep[0] = False
    water |= ~keep[dry_labels] & ~high_land & (dry_labels > 0)

    # The open sea: water reached from deep water without crossing sand, with gaps in the sand up
    # to inlet_close_m wide closed first (the bar's openings), so the lagoon behind the bar is not
    # counted as sea. The closed gaps are the inlets.
    close_cells = max(1, int(round(lagoon["inlet_close_m"] / (2 * cell))))
    barrier = ndimage.binary_closing(~water, structure=disk(close_cells), border_value=0)
    passable = water & ~barrier
    labels, _count = ndimage.label(passable)
    deep = passable & (sea_bed < -15.0)
    open_ids = np.unique(labels[deep])
    open_sea = np.isin(labels, open_ids[open_ids > 0])
    # Give back the open sea's edge that the closing took (within the closing's reach of open sea).
    open_sea |= water & ndimage.binary_dilation(open_sea, structure=disk(close_cells)) & ~barrier
    inlets = water & barrier
    lagoon_water = water & ~open_sea

    # Distance from the waterline, in metres: for the sea, from the nearest cell that is not open
    # sea; for the beach and the bar, from the nearest open sea.
    distance_offshore = ndimage.distance_transform_edt(open_sea) * cell
    distance_inland = ndimage.distance_transform_edt(~open_sea) * cell

    heights = np.where(np.isnan(terrain), 0.0, terrain)
    # The photo was flown at some tide: its sea's waterline is this high above mean sea level
    # (Sotavento's PNOA photo: near low water, the lagoon drained but for its channels, like the
    # morning photo of 24 September 2021). Every height measured from that waterline starts here.
    waterline = config.get("photo_waterline_m", 0.0)

    # The sea: the measured profile near the shore (depths below the photo's waterline), blended
    # into the profile below mean sea level within 400 m and into EMODnet further out. EMODnet is
    # never allowed to be shallower than 0.5 m below the sea level at sea.
    profile_depth = interpolate_profile(distance_offshore, config["shore_profile"])
    near_share = 1.0 - np.clip(distance_offshore / 400.0, 0.0, 1.0)
    profile_height = -profile_depth + waterline * near_share
    blend = np.clip((distance_offshore - config["shore_profile"]["blend_from_m"])
                    / (config["shore_profile"]["blend_to_m"] - config["shore_profile"]["blend_from_m"]), 0.0, 1.0)
    blend = blend * blend * (3.0 - 2.0 * blend)  # smoothstep
    sea_height = (1.0 - blend) * profile_height + blend * np.minimum(sea_bed, -0.5)
    heights[open_sea] = np.minimum(sea_height[open_sea], waterline - 0.2)

    # The lagoon's low ground: its water and its wet sand away from the sea (the outer beach's
    # swash zone is wet too, but that is the beach face).
    sand = ~water & ~high_land
    lagoon_low = lagoon_water | (seen["wet_sand"] & (distance_inland > 40.0))
    distance_to_low = ndimage.distance_transform_edt(~lagoon_low) * cell
    # The lagoon's side of the shore: near its low ground, or far from the dunes (an ordinary beach
    # has the dunes right behind it; the bar has the wide flats).
    distance_to_dunes = ndimage.distance_transform_edt(~high_land) * cell
    behind_is_low = (distance_to_low <= 60.0) | (distance_to_dunes > 80.0)

    # The beach and the bar facing the open sea, within bar_reach_m of the photo's (low-water)
    # waterline. Where the lagoon is behind, the bar is a ridge: its sea face rises from the
    # waterline at bar_face_slope, its back falls at bar_back_slope to the lagoon floor at the reach's
    # inner edge, and its crest is never higher than bar_crest_m. So the bar is one continuous thin
    # strip just above spring high water, broken only where the photo shows water crossing it (the
    # inlets), as the high-tide photos of 24 September 2021 (15:20) and from Playa Barca show; the
    # sand further inside, even where the photo saw it dry, is the lagoon's floor (a dry ridge in the
    # lagoon is drowned at spring high water). Where no lagoon is behind, an ordinary beach face up
    # to beach_top_m, and the terrain model takes over landward.
    reach = lagoon["bar_reach_m"]
    near_sea = sand & (distance_inland <= reach)
    sea_face = waterline + lagoon["bar_face_slope"] * distance_inland
    back_face = lagoon["wet_sand_m"] + lagoon["bar_back_slope"] * (reach - distance_inland)
    bar = np.minimum(np.minimum(sea_face, back_face), lagoon["bar_crest_m"])
    beach = np.minimum(waterline + lagoon["beach_face_slope"] * distance_inland, lagoon["beach_top_m"])
    strip = np.where(behind_is_low, bar, beach)
    terrain_or_zero = np.nan_to_num(terrain, nan=0.0)
    heights[near_sea] = np.where(behind_is_low[near_sea], strip[near_sea],
                                 np.maximum(terrain_or_zero[near_sea], strip[near_sea]))

    # The lagoon floor and the flats behind the bar, by what the photo sees (it saw them drained).
    flats = sand & ~near_sea & (terrain_or_zero < 2.0)
    floor = np.full(heights.shape, lagoon["dry_sand_m"])
    floor[seen["wet_sand"]] = lagoon["wet_sand_m"]
    # Dark ground in the lagoon is mostly wet weed and sea grass on its floor (the low-tide photos);
    # only by the dune foot is it the salt marsh's shrubs, which stand higher.
    by_the_dunes = ndimage.binary_dilation(high_land, structure=disk(int(round(60 / cell))))
    floor[seen["marsh"]] = lagoon["wet_sand_m"]
    floor[seen["marsh"] & by_the_dunes] = lagoon["salt_marsh_m"]
    heights[flats] = floor[flats]
    heights[lagoon_water] = lagoon["channel_m"]
    heights[inlets] = np.minimum(heights[inlets], lagoon["channel_m"] - 0.2)

    # Smooth the low ground (the terrain model's whole-metre steps, the photo's speckle) without
    # touching the hills or the deep sea.
    smooth = ndimage.gaussian_filter(heights, sigma=1.5)
    low = (heights > -6.0) & (heights < 6.0)
    heights[low] = smooth[low]
    # Open sea stays under the photo's waterline after smoothing.
    heights[open_sea] = np.minimum(heights[open_sea], waterline - 0.2)

    masks = {"open_sea": open_sea, "lagoon_water": lagoon_water, "inlets": inlets, "high_land": high_land}
    print(f"  near grid {columns} x {rows} at {cell} m: open sea {open_sea.mean():.0%}, lagoon water "
          f"{lagoon_water.sum() * cell * cell / 1e4:.0f} ha, inlets {inlets.sum()} cells; heights {heights.min():.1f} .. {heights.max():.1f} m")
    return heights, masks


def far_heights(spot: Spot) -> np.ndarray:
    """The far grid: the terrain model on land, EMODnet at sea (no shore detail: it is far away)."""
    box = spot.box("far")
    cell = spot.config["far"]["cell_m"]
    terrain = read_terrain(spot.raw / "terrain_far.tif", box, cell)
    sea_bed = read_emodnet(spot.raw / "emodnet.tif", spot, box, cell)
    land = np.nan_to_num(terrain, nan=0.0) > 0.0
    heights = np.where(land, terrain, np.minimum(sea_bed, -1.0))
    print(f"  far grid {heights.shape[1]} x {heights.shape[0]} at {cell} m; heights {heights.min():.0f} .. {heights.max():.0f} m")
    return heights


# ---------------------------------------------------------------- writing for the game

def write_grid(spot: Spot, heights: np.ndarray, box: list[float], cell_m: float, name: str) -> None:
    """A height grid in the TerrainGrid format: 16-bit numbers and a .json that says how to read
    them (Game/maps/terrain_grid.gd). Heights are above mean sea level; the game lowers them by the
    session's water level."""
    low, high = float(heights.min()) - 1.0, float(heights.max()) + 1.0
    scale = (high - low) / 65535.0
    values = np.clip(np.round((heights - low) / scale), 0, 65535).astype("<u2")
    (spot.out / f"{name}.bin").write_bytes(values.tobytes())
    east, north = grid_centres(box, cell_m)
    origin_east, origin_north = spot.config["origin_east_m"], spot.config["origin_north_m"]
    info = {
        "about": f"{spot.config['name']}: heights for the game, written by tools/map/spot_build.py: don't edit. "
                 "height above mean sea level (m) = height_offset_m + value * height_scale_m",
        "file": f"{name}.bin",
        "format": "uint16 little-endian, row by row from the north edge, each row from west to east",
        "columns": int(heights.shape[1]),
        "rows": int(heights.shape[0]),
        "cell_m": float(cell_m),
        "crs": spot.config["crs"],
        "west_m": float(east[0]),
        "north_m": float(north[0]),
        "x0_m": float(east[0] - origin_east),
        "z0_m": float(-(north[0] - origin_north)),
        "height_scale_m": scale,
        "height_offset_m": low,
        "lake_level_m": 0.0,
    }
    (spot.out / f"{name}.json").write_text(json.dumps(info, indent=1), encoding="utf-8")
    print(f"  wrote {name}.bin ({values.nbytes / 1e6:.1f} MB) and {name}.json: steps of {100 * scale:.1f} cm")


def paint_empty(photo: Image.Image, heights_for_photo: np.ndarray | None = None) -> Image.Image:
    """The photo's empty parts (black or white, out at sea) painted the deep sea's blue."""
    pixels = np.asarray(photo, dtype=np.int32).copy()
    total = pixels.sum(axis=2)
    empty = (total < 15) | (total > 750)
    pixels[empty] = (18, 46, 78)
    return Image.fromarray(pixels.astype(np.uint8))


def write_photos(spot: Spot) -> None:
    photos = spot.config["photos"]
    near = pnoa_photo(spot, spot.box("near"), photos["near"]["tiles"], photos["near"]["tile_px"], "photo_near")
    near = paint_empty(near).resize((photos["near"]["out_px"], photos["near"]["out_px"]), Image.LANCZOS)
    near.save(spot.out / "near_photo.webp", quality=88, method=6)
    detail = pnoa_photo(spot, photos["detail"]["box"], photos["detail"]["tiles"], photos["detail"]["tile_px"], "photo_detail")
    paint_empty(detail).save(spot.out / "detail_photo.webp", quality=88, method=6)
    far = pnoa_photo(spot, spot.box("far"), photos["far"]["tiles"], photos["far"]["tile_px"], "photo_far")
    paint_empty(far).save(spot.out / "far_photo.webp", quality=85, method=6)
    detail_box = photos["detail"]["box"]
    info = {
        "about": "The photos' boxes in game metres (x east, z south of the origin), for HeightTerrain. Written by tools/map/spot_build.py.",
        "near": game_rect(spot, spot.box("near")),
        "detail": game_rect(spot, detail_box),
        "far": game_rect(spot, spot.box("far")),
    }
    (spot.out / "photos.json").write_text(json.dumps(info, indent=1), encoding="utf-8")
    print("  wrote near_photo.webp, detail_photo.webp, far_photo.webp and photos.json")


def game_rect(spot: Spot, box: list[float]) -> list[float]:
    """A box [west, south, east, north] as the game's rectangle [x, z, width, depth] (north-west corner)."""
    x0, y0, x1, y1 = box
    return [x0 - spot.config["origin_east_m"], -(y1 - spot.config["origin_north_m"]), x1 - x0, y1 - y0]


def write_preview(spot: Spot, heights: np.ndarray, masks: dict) -> None:
    """The near grid in colour: the sea by depth in blues, the lagoon's water cyan, the inlets red,
    the low ground by height in yellows and the hills in greys."""
    rgb = np.zeros(heights.shape + (3,), np.float64)
    sea = heights < 0
    depth = np.clip(-heights / 40.0, 0, 1)[..., None]
    rgb[sea] = ((1 - depth) * np.array([90, 200, 220]) + depth * np.array([10, 30, 90]))[sea]
    low = (heights >= 0) & (heights < 3)
    t = np.clip(heights / 3.0, 0, 1)[..., None]
    rgb[low] = ((1 - t) * np.array([200, 180, 90]) + t * np.array([250, 240, 200]))[low]
    hill = heights >= 3
    grey = np.clip(140 + heights / 4.0, 0, 255)[..., None]
    rgb[hill] = np.repeat(grey, 3, axis=2)[hill]
    rgb[masks["lagoon_water"]] = (60, 230, 230)
    rgb[masks["inlets"]] = (230, 40, 40)
    Image.fromarray(rgb.astype(np.uint8)).save(spot.work / "preview.png")
    print(f"  wrote {spot.work / 'preview.png'}")


# ---------------------------------------------------------------- buildings (OpenStreetMap)

def overpass_buildings(spot: Spot) -> dict:
    """OpenStreetMap's building outlines in the config's latitude-longitude box (cached)."""
    path = spot.raw / "osm_buildings.json"
    if not (path.exists() and path.stat().st_size > 1000):
        south, west, north, east = spot.config["buildings"]["box_latlon"]
        query = f'[out:json][timeout:60];way["building"]({south},{west},{north},{east});out tags geom;'
        data = urllib.parse.urlencode({"data": query}).encode()
        # Overpass turns away browser-like user agents: a plain tool name.
        request = urllib.request.Request("https://overpass-api.de/api/interpreter", data=data,
                                         headers={"User-Agent": "windsurf-game-map-builder/1.0"})
        with urllib.request.urlopen(request, timeout=180) as response:
            path.write_bytes(response.read())
        print(f"  downloaded {path.name}")
    return json.loads(path.read_text(encoding="utf-8"))


def building_levels(tags: dict, area_m2: float, centre: tuple, settings: dict) -> float:
    """How many floors: the config's overrides (the landmarks, from photos), then OSM's
    building:levels, then a guess by kind and size (low-rise Canarian building otherwise)."""
    for override in settings["overrides"]:
        if math.hypot(centre[0] - override["near"][0], centre[1] - override["near"][1]) <= override["radius_m"]:
            return float(override["levels"])
    if tags.get("building:levels", "").replace(".", "", 1).isdigit():
        return float(tags["building:levels"])
    kind = tags.get("building", "yes")
    if kind == "tent":
        return 2.5
    if kind == "hotel":
        return 4.0 if area_m2 > 1500 else 3.0
    if area_m2 > 1500:
        return 3.0
    return float(settings["default_levels"])


def write_buildings(spot: Spot) -> None:
    """Game/maps/<slug>/buildings.json: each building's outline in game metres (x east, z south of
    the origin), the ground under it (m above mean sea level, the lowest corner on the near grid) and
    its height; drawn by SpotBuildings (Game/maps/spots/spot_buildings.gd). OpenStreetMap's data is
    © OpenStreetMap contributors (ODbL): the credits name it."""
    settings = spot.config["buildings"]
    data = overpass_buildings(spot)
    to_frame = Transformer.from_crs("EPSG:4326", spot.config["crs"], always_xy=True)
    info = json.loads((spot.out / "near_heights.json").read_text(encoding="utf-8"))
    values = np.frombuffer((spot.out / "near_heights.bin").read_bytes(), dtype="<u2").reshape(info["rows"], info["columns"])
    origin_east, origin_north = spot.config["origin_east_m"], spot.config["origin_north_m"]

    def ground_at(east: float, north: float) -> float:
        column = int(round((east - info["west_m"]) / info["cell_m"]))
        row = int(round((info["north_m"] - north) / info["cell_m"]))
        column = min(max(column, 0), info["columns"] - 1)
        row = min(max(row, 0), info["rows"] - 1)
        return info["height_offset_m"] + float(values[row, column]) * info["height_scale_m"]

    buildings = []
    for element in data.get("elements", []):
        geometry = element.get("geometry")
        if not geometry or len(geometry) < 4:
            continue
        easts, norths = to_frame.transform([p["lon"] for p in geometry], [p["lat"] for p in geometry])
        points = list(zip(easts, norths))[:-1]  # the outline closes on its first point
        area = 0.5 * abs(sum(points[i][0] * points[(i + 1) % len(points)][1] - points[(i + 1) % len(points)][0] * points[i][1]
                             for i in range(len(points))))
        if area < 12.0:
            continue
        centre = (sum(p[0] for p in points) / len(points), sum(p[1] for p in points) / len(points))
        tags = element.get("tags", {})
        levels = building_levels(tags, area, centre, settings)
        base = min(ground_at(e, n) for e, n in points)
        if base < 0.5:  # an outline that reaches into the water: skip (a pier, a mapping slip)
            continue
        buildings.append({
            "kind": "tent" if tags.get("building") == "tent" else "building",
            "base_m": round(base, 2),
            "height_m": round(levels * settings["level_m"], 2),
            "outline": [[round(e - origin_east, 2), round(-(n - origin_north), 2)] for e, n in points],
        })
    out = REPO / "Game" / "maps" / spot.slug / "buildings.json"
    out.write_text(json.dumps({
        "about": f"{spot.config['name']}: buildings from OpenStreetMap (© OpenStreetMap contributors, ODbL), written by tools/map/spot_build.py: don't edit. "
                 "outline in game metres (x east, z south of the origin), base_m and height_m in metres (base above mean sea level).",
        "level_m": settings["level_m"],
        "buildings": buildings,
    }), encoding="utf-8")
    print(f"  wrote {out.name}: {len(buildings)} buildings")


def main() -> None:
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    stage = next((a.split("=", 1)[1] for a in sys.argv[1:] if a.startswith("--stage=")), "all")
    if not args:
        print(__doc__)
        sys.exit(1)
    spot = Spot(args[0])
    print(f"{spot.config['name']} ({spot.slug})")
    if stage in ("download", "all"):
        download(spot)
    if stage in ("grids", "all"):
        print("Height grids:")
        heights, masks = near_heights(spot)
        write_grid(spot, heights, spot.box("near"), spot.config["near"]["cell_m"], "near_heights")
        write_preview(spot, heights, masks)
        write_grid(spot, far_heights(spot), spot.box("far"), spot.config["far"]["cell_m"], "far_heights")
    if stage in ("photos", "all"):
        print("Photos:")
        write_photos(spot)
    if stage in ("buildings", "all") and "buildings" in spot.config:
        print("Buildings:")
        write_buildings(spot)


if __name__ == "__main__":
    main()
