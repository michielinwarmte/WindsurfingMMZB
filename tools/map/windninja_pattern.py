"""The Maloja's fixed pattern over Lake Silvaplana, computed with WindNinja (map plan, phase W1).

WindNinja (US Forest Service, free) works out how the terrain steers a wind: where the valley
squeezes it and it speeds up, where it widens and slows, and where it turns. Its mass-conserving
solver takes a wind from one direction and adjusts it to the mountains so that no air is lost.
How easily the air goes over a mountain instead of around it is set by "alpha": small for
stable air, which goes around and follows the valley (the Maloja is capped by an inversion, so
it is that kind of air), 1 for neutral air.

This script:
1. writes the terrain from the Maloja pass to St. Moritz as a GeoTIFF (30 m cells, Swiss LV95),
2. runs WindNinja for a few incoming directions and kinds of air,
3. compares every run with what was measured: the satellite's roughness map of the lake
   (satellite_wind.py) and the station at Segl-Maria (245 degrees when the Maloja blows),
4. reruns the best one finer and writes it for the game, with pictures for Max.

Run from the repo root (about 5 minutes; the runs are kept, --force redoes them):

    python tools/map/windninja_pattern.py

WindNinja must be installed (see the Tools table of the map plan). The script finds
WindNinja_cli.exe through $WINDNINJA, then %LOCALAPPDATA%/Programs/WindNinja/4.0.0/bin.

Output:
- .map_data/work/wind_pattern/: the terrain, every run, comparison.json and pictures,
- Game/maps/silvaplana/wind/maloja_pattern.json + .bin: the pattern for the game (generated,
  don't edit): per 50 m cell the speed relative to the lake's average and the turn in degrees.
- Documentation/images/maloja/pattern_*.png: the pictures for the research document.
"""
import argparse
import json
import math
import os
import subprocess
import warnings
from pathlib import Path

import numpy as np
import tifffile
from PIL import Image, ImageDraw, ImageFont

import satellite_wind
import silvaplana_area as area

# The area WindNinja works on: Val Bregaglia's top, the Maloja pass, the lakes, St. Moritz.
WEST, EAST, SOUTH, NORTH = 2_768_000.0, 2_790_000.0, 1_136_000.0, 1_156_000.0
DEM_CELL_M = 30
SWEEP_MESH_M = 100  # the comparison runs
FINAL_MESH_M = 50  # the run written for the game

# The incoming wind: about the station's speed at 10 m. The pattern is stored relative to the
# lake's average, so the speed itself hardly matters.
INPUT_SPEED_MS = 6.0
DIRECTIONS = (220, 230, 240, 250)
AIR = {"stable": 0.1, "slightly_stable": 0.3, "neutral": 1.0}
OUTPUT_HEIGHT_M = 5.0  # about the height of a sail
VALLEY_TOP_M = 2100.0  # pictures: arrows only below this height (the valley floor is at 1800 m)

WORK = area.WORK_DIR / "wind_pattern"
GAME_DIR = area.REPO_ROOT / "Game" / "maps" / "silvaplana" / "wind"
DOC_IMAGES = area.REPO_ROOT / "Documentation" / "images" / "maloja"
STATION_SIA = (2_778_576.0, 1_144_976.0)
STATION_DIRECTION_DEG = 245.0  # Segl-Maria, Maloja afternoons (maloja_research.py)
SATELLITE_KEY = f"pattern_{satellite_wind.BAND}"  # Maloja photos / calm photos (satellite_wind.py)
# On the lake the strength comes from the satellite. A 10 % rougher patch is taken as 10 % more
# wind: the water's mean square slope grows about in proportion to the wind (Cox and Munk 1954),
# and brightness is assumed to follow the slope. An assumption, for Max to check on the water.
ROUGHNESS_TO_WIND = 1.0
LAKE_FACTOR_LIMITS = (0.7, 1.3)
SILVAPLANA_NORTH_END_M = 1_147_780.0  # LV95 north of the narrows between Lake Silvaplana and Lake Champfèr


# ---------------------------------------------------------------- running WindNinja

def windninja_exe() -> Path:
    candidates = []
    if os.environ.get("WINDNINJA"):
        given = Path(os.environ["WINDNINJA"])
        candidates.append(given if given.suffix.lower() == ".exe" else given / "bin" / "WindNinja_cli.exe")
    local = os.environ.get("LOCALAPPDATA", "")
    candidates.append(Path(local) / "Programs" / "WindNinja" / "4.0.0" / "bin" / "WindNinja_cli.exe")
    for candidate in candidates:
        if candidate.exists():
            return candidate
    raise SystemExit("WindNinja_cli.exe not found. Install WindNinja 4.0.0 (map plan, Tools) or set WINDNINJA.")


def write_dem() -> Path:
    """The terrain as a GeoTIFF that WindNinja (GDAL) reads: 30 m block means of swissALTIRegio,
    with the Swiss LV95 coordinate system (EPSG 2056) in its GeoTIFF keys."""
    path = WORK / "dem_30m.tif"
    if path.exists():
        return path
    data = np.load(area.WORK_DIR / "swissaltiregio_10m.npz")
    heights, west, north = data["heights"], float(data["west"]), float(data["north"])
    c0, c1 = int((WEST - west) / 10), int((EAST - west) / 10)
    r0, r1 = int((north - NORTH) / 10), int((north - SOUTH) / 10)
    k = DEM_CELL_M // 10
    window = heights[r0:r1, c0:c1].astype(np.float64)
    rows, cols = window.shape[0] // k, window.shape[1] // k
    dem = window[:rows * k, :cols * k].reshape(rows, k, cols, k).mean(axis=(1, 3)).astype(np.float32)
    geokeys = (1, 1, 0, 4, 1024, 0, 1, 1, 1025, 0, 1, 1, 3072, 0, 1, 2056, 3076, 0, 1, 9001)
    WORK.mkdir(parents=True, exist_ok=True)
    tifffile.imwrite(path, dem, extratags=[
        (33550, 12, 3, (float(DEM_CELL_M), float(DEM_CELL_M), 0.0), False),  # pixel size
        (33922, 12, 6, (0.0, 0.0, 0.0, WEST, NORTH, 0.0), False),  # top-left corner
        (34735, 3, len(geokeys), geokeys, False)])  # projected, LV95, metres
    return path


def run(name: str, direction: float, alpha: float, mesh_m: int, force: bool) -> Path:
    """One WindNinja run; returns its folder. Kept between script runs unless force."""
    out = WORK / "runs" / name
    if out.exists() and list(out.glob("*_vel.asc")) and not force:
        return out
    out.mkdir(parents=True, exist_ok=True)
    exe = windninja_exe()
    env = dict(os.environ, WINDNINJA_DATA=str(exe.parent.parent / "share" / "windninja"))
    command = [str(exe), "--num_threads", str(os.cpu_count() or 4),
               "--elevation_file", str(write_dem()), "--initialization_method", "domainAverageInitialization",
               "--time_zone", "Europe/Zurich", "--vegetation", "grass",
               "--input_speed", str(INPUT_SPEED_MS), "--input_speed_units", "mps", "--output_speed_units", "mps",
               "--input_direction", str(direction), "--input_wind_height", "10", "--units_input_wind_height", "m",
               "--output_wind_height", str(OUTPUT_HEIGHT_M), "--units_output_wind_height", "m",
               "--mesh_resolution", str(mesh_m), "--units_mesh_resolution", "m",
               "--non_neutral_stability", "true", "--alpha_stability", str(alpha),
               "--write_ascii_output", "true", "--output_path", str(out)]
    result = subprocess.run(command, env=env, cwd=exe.parent, capture_output=True, text=True)
    (out / "windninja.log").write_text(result.stdout + result.stderr)
    if result.returncode != 0 or not list(out.glob("*_vel.asc")):
        raise SystemExit(f"WindNinja failed for {name}; see {out / 'windninja.log'}")
    return out


# ---------------------------------------------------------------- reading the results

class Grid:
    """A WindNinja ASCII grid (ESRI format): rows from the north edge, LV95 metres."""

    def __init__(self, path: Path) -> None:
        with open(path) as f:
            header = {}
            for _ in range(6):
                key, value = f.readline().split()
                header[key.lower()] = float(value)
            self.values = np.loadtxt(f)
        self.cell = header["cellsize"]
        self.west = header["xllcorner"]
        self.north = header["yllcorner"] + header["nrows"] * self.cell

    def sample(self, east: np.ndarray, north: np.ndarray) -> np.ndarray:
        """Bilinear between cell centres."""
        x = (east - self.west) / self.cell - 0.5
        y = (self.north - north) / self.cell - 0.5
        x0 = np.clip(np.floor(x).astype(int), 0, self.values.shape[1] - 2)
        y0 = np.clip(np.floor(y).astype(int), 0, self.values.shape[0] - 2)
        fx, fy = np.clip(x - x0, 0, 1), np.clip(y - y0, 0, 1)
        v = self.values
        return ((v[y0, x0] * (1 - fx) + v[y0, x0 + 1] * fx) * (1 - fy)
                + (v[y0 + 1, x0] * (1 - fx) + v[y0 + 1, x0 + 1] * fx) * fy)


def wind_of(folder: Path) -> tuple[Grid, Grid, Grid, Grid]:
    """Speed, direction it comes from, and the east and north parts of the flow (m/s)."""
    speed = Grid(next(folder.glob("*_vel.asc")))
    direction = Grid(next(folder.glob("*_ang.asc")))
    # Interpolate the wind as a vector, not the angle (359 and 1 degrees average to 0, not 180).
    east = Grid.__new__(Grid)
    north = Grid.__new__(Grid)
    for g in (east, north):
        g.cell, g.west, g.north = speed.cell, speed.west, speed.north
    rad = np.deg2rad(direction.values)
    east.values = -speed.values * np.sin(rad)  # the air moves away from where it comes from
    north.values = -speed.values * np.cos(rad)
    return speed, direction, east, north


def flow_at(folder: Path, east_m: np.ndarray, north_m: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
    """Speed (m/s) and direction it comes from (degrees) at LV95 points."""
    _, _, u, v = wind_of(folder)
    ue, vn = u.sample(east_m, north_m), v.sample(east_m, north_m)
    speed = np.hypot(ue, vn)
    from_deg = (np.rad2deg(np.arctan2(-ue, -vn))) % 360.0
    return speed, from_deg


def circular_mean(degrees: np.ndarray, weights: np.ndarray | None = None) -> float:
    rad = np.deg2rad(degrees)
    w = np.ones_like(rad) if weights is None else weights
    return float(np.rad2deg(np.arctan2((w * np.sin(rad)).sum(), (w * np.cos(rad)).sum())) % 360.0)


def angle_diff(a, b):
    return (np.asarray(a) - b + 180.0) % 360.0 - 180.0


def lake_cells() -> tuple[np.ndarray, np.ndarray, np.ndarray, np.ndarray]:
    """The 10 m lake grid of satellite_wind.py: east, north, lake mask, and the open water at
    least 100 m from the shore (where the bright shore doesn't light the water in the photos)."""
    east, north = satellite_wind.grid_lv95()
    lake = satellite_wind.lake_mask()
    return east, north, lake, satellite_wind.shrink(lake, 10)


def lake_mean_direction(folder: Path, east, north, lake) -> float:
    speed, from_deg = flow_at(folder, east[lake], north[lake])
    return circular_mean(from_deg, speed)


def smooth(values: np.ndarray, mask: np.ndarray, passes: int = 3) -> np.ndarray:
    """A simple 3x3 mean inside the mask, a few times: removes the satellite's pixel noise."""
    v = np.where(mask, values, 0.0)
    w = mask.astype(float)
    for _ in range(passes):
        vs = sum(np.roll(np.roll(v, dy, 0), dx, 1) for dy in (-1, 0, 1) for dx in (-1, 0, 1))
        ws = sum(np.roll(np.roll(w, dy, 0), dx, 1) for dy in (-1, 0, 1) for dx in (-1, 0, 1))
        v = np.where(mask, vs / np.maximum(ws, 1e-9), 0.0)
        w = mask.astype(float)
    return np.where(mask, v, np.nan)


def along_lake_m(east: np.ndarray, north: np.ndarray) -> np.ndarray:
    """Distance along the lake's axis (towards 44 degrees, the Silvaplana end) from the lake's middle."""
    axis = np.deg2rad(44.0)
    return (east - 2_780_500.0) * np.sin(axis) + (north - 1_146_600.0) * np.cos(axis)


def compare(folder: Path, satellite: dict | None, east, north, lake, inner) -> dict:
    """How well a run fits the measurements."""
    speed, from_deg = flow_at(folder, east, north)
    lake_speed = float(np.median(speed[lake]))
    lake_dir = circular_mean(from_deg[lake], speed[lake])
    s_speed, s_dir = flow_at(folder, np.array([STATION_SIA[0]]), np.array([STATION_SIA[1]]))
    result = {
        "lake_direction_deg": lake_dir,
        "station_direction_deg": float(s_dir[0]),
        "station_turn_vs_lake_deg": float(angle_diff(s_dir[0], lake_dir)),
        "station_speed_vs_lake": float(s_speed[0] / lake_speed),
        "lake_speed_p10_p90": [float(v / lake_speed) for v in np.percentile(speed[lake], [10, 90])],
        "lake_turn_p10_p90_deg": [float(v) for v in np.percentile(angle_diff(from_deg[lake], lake_dir), [10, 90])],
    }
    if satellite is not None and SATELLITE_KEY in satellite:
        rough = smooth(satellite[SATELLITE_KEY], inner)
        model = smooth(speed / lake_speed, inner)
        ok = inner & np.isfinite(rough) & np.isfinite(model)
        result["satellite_correlation"] = float(np.corrcoef(rough[ok], model[ok])[0, 1])
        # The same along the lake: the mean in 250 m steps from the Sils end to the Silvaplana end.
        along = along_lake_m(east, north)
        bins = np.arange(along[ok].min(), along[ok].max() + 250, 250)
        index = np.digitize(along[ok], bins)
        steps = [k for k in np.unique(index) if (index == k).sum() > 50]
        rough_profile = np.array([rough[ok][index == k].mean() for k in steps])
        model_profile = np.array([model[ok][index == k].mean() for k in steps])
        result["along_lake_m"] = [float(bins[k - 1] + 125) for k in steps]
        result["along_lake_satellite"] = [float(v) for v in rough_profile / rough_profile.mean()]
        result["along_lake_model"] = [float(v) for v in model_profile / model_profile.mean()]
        result["along_lake_correlation"] = float(np.corrcoef(rough_profile, model_profile)[0, 1])
    return result


# ---------------------------------------------------------------- the pattern for the game

def fill_outward(values: np.ndarray, known: np.ndarray, wanted: np.ndarray) -> np.ndarray:
    """Fills the wanted cells that aren't known with the mean of their known neighbours, ring by ring."""
    v = np.where(known, values, np.nan)
    for _ in range(20):
        missing = wanted & ~np.isfinite(v)
        if not missing.any():
            break
        stack = np.array([np.roll(np.roll(v, dy, 0), dx, 1) for dy in (-1, 0, 1) for dx in (-1, 0, 1)])
        with np.errstate(invalid="ignore"), warnings.catch_warnings():
            warnings.simplefilter("ignore", RuntimeWarning)  # cells with no known neighbour yet
            neighbours = np.nanmean(stack, axis=0)
        v = np.where(missing & np.isfinite(neighbours), neighbours, v)
    return v


def lake_strength_from_satellite(satellite: dict, lake: np.ndarray) -> np.ndarray:
    """The speed factor on the 10 m lake grid from the satellite's roughness map (research
    document, "Seen from space"), on Lake Silvaplana only (north of the narrows the channel to
    Lake Champfèr is too narrow for 10 m pixels; WindNinja covers it). Smoothed twice over 150 m,
    because 22 photos leave blotches of a few hundred metres that are noise, not wind; the 30 m
    along the shore (mixed pixels) filled from the water next to it; relative to the lake's median."""
    east, north = satellite_wind.grid_lv95()
    silvaplana = lake & (north < SILVAPLANA_NORTH_END_M)
    inner = satellite_wind.shrink(silvaplana, 3)
    rough = satellite_wind.box_mean(satellite[SATELLITE_KEY], inner, 7)
    rough = satellite_wind.box_mean(rough, inner, 7)
    rough = fill_outward(rough, inner & np.isfinite(rough), silvaplana)
    relative = rough / np.nanmedian(rough[silvaplana])
    factor = np.clip(1.0 + ROUGHNESS_TO_WIND * (relative - 1.0), *LAKE_FACTOR_LIMITS)
    return np.where(silvaplana, factor, np.nan)


def write_game_pattern(folder: Path, comparison: dict, satellite: dict | None) -> None:
    """Per 50 m cell over the whole area: the speed relative to the lake's average, and the
    turn in degrees relative to the lake's average direction (positive: from further right).
    Two float32 layers, rows from the north edge, each row from west to east.

    The direction comes from WindNinja everywhere. The strength comes from WindNinja over land
    and, on Lake Silvaplana, from the satellite (which sees the forest's shelter that WindNinja,
    with one roughness for all ground, can't)."""
    speed, direction, _, _ = wind_of(folder)
    east, north, lake, _ = lake_cells()
    lake_speed = float(np.median(flow_at(folder, east[lake], north[lake])[0]))
    lake_dir = comparison["lake_direction_deg"]
    factor = (speed.values / lake_speed).astype("<f4")
    turn = angle_diff(direction.values, lake_dir).astype("<f4")
    if satellite is not None and SATELLITE_KEY in satellite:
        from_satellite = lake_strength_from_satellite(satellite, lake)
        rows, cols = factor.shape
        for r in range(rows):
            n = speed.north - (r + 0.5) * speed.cell
            gr = int((satellite_wind.GRID_NORTH - n) / satellite_wind.GRID_CELL)
            if not 2 <= gr < lake.shape[0] - 2:
                continue
            for c in range(cols):
                e = speed.west + (c + 0.5) * speed.cell
                gc = int((e - satellite_wind.GRID_WEST) / satellite_wind.GRID_CELL)
                if not 2 <= gc < lake.shape[1] - 2:
                    continue
                block = from_satellite[gr - 2:gr + 3, gc - 2:gc + 3]
                if np.isfinite(block).sum() >= 13:  # at least half of the 50 m cell is lake
                    factor[r, c] = np.nanmean(block)
    GAME_DIR.mkdir(parents=True, exist_ok=True)
    with open(GAME_DIR / "maloja_pattern.bin", "wb") as f:
        f.write(factor.tobytes())
        f.write(turn.tobytes())
    info = {
        "about": "The Maloja's fixed pattern over the terrain, from WindNinja (tools/map/windninja_pattern.py, "
                 "Documentation/MALOJA_WIND_RESEARCH.md): don't edit. Layer 1: wind speed / the lake's median speed. "
                 "Layer 2: the direction the wind comes from minus the lake's mean direction, degrees, positive = "
                 "turned clockwise (from further right).",
        "file": "maloja_pattern.bin",
        "format": "two float32 little-endian layers (speed factor, then turn), each row by row from the north edge, "
                  "each row from west to east",
        "columns": int(speed.values.shape[1]), "rows": int(speed.values.shape[0]), "cell_m": speed.cell,
        "west_m": speed.west, "north_m": speed.north, "height_above_ground_m": OUTPUT_HEIGHT_M,
        "run": folder.name, "lake_direction_deg": round(lake_dir, 1),
        "lake_strength": ("from the satellite's roughness map (satellite_wind.py), roughness taken as wind "
                          f"x {ROUGHNESS_TO_WIND}" if satellite is not None else "from WindNinja"),
        "station_segl_maria": {"speed_factor": round(comparison["station_speed_vs_lake"], 3),
                               "turn_deg": round(comparison["station_turn_vs_lake_deg"], 1)},
    }
    (GAME_DIR / "maloja_pattern.json").write_text(json.dumps(info, indent=1))


# ---------------------------------------------------------------- pictures

def font(size: int, bold: bool = False) -> ImageFont.FreeTypeFont:
    for folder in (Path("C:/Windows/Fonts"), Path("/usr/share/fonts/truetype/dejavu")):
        for name in (["segoeuib.ttf", "DejaVuSans-Bold.ttf"] if bold else ["segoeui.ttf", "DejaVuSans.ttf"]):
            if (folder / name).exists():
                return ImageFont.truetype(str(folder / name), size)
    return ImageFont.load_default(size)


# Diverging blue <-> red around a neutral grey (reference data-viz palette): blue = weaker than
# the lake's average, red = stronger.
DIVERGING = np.array([[0x18, 0x4f, 0x95], [0x2a, 0x78, 0xd6], [0x86, 0xb6, 0xef], [0xf0, 0xef, 0xec],
                      [0xf2, 0xa3, 0x9e], [0xe3, 0x49, 0x48], [0xa3, 0x2a, 0x2a]], dtype=float)


def diverging(values: np.ndarray, spread: float) -> np.ndarray:
    """values around 1.0; 1 - spread is full blue, 1 + spread full red."""
    t = np.clip((values - 1.0) / spread, -1, 1) * 3 + 3
    i = np.clip(np.floor(t).astype(int), 0, 5)
    f = (t - i)[..., None]
    return DIVERGING[i] * (1 - f) + DIVERGING[i + 1] * f


def hillshade(heights: np.ndarray, cell: float) -> np.ndarray:
    gy, gx = np.gradient(heights, cell)
    slope = np.arctan(np.hypot(gx, gy))
    aspect = np.arctan2(-gx, gy)
    sun_az, sun_alt = np.deg2rad(315.0), np.deg2rad(45.0)
    shade = np.sin(sun_alt) * np.cos(slope) + np.cos(sun_alt) * np.sin(slope) * np.cos(sun_az - aspect)
    return np.clip(shade, 0, 1)


def arrow(draw: ImageDraw.ImageDraw, x: float, y: float, dx: float, dy: float, colour, width: int) -> None:
    """An arrow from (x, y) along (dx, dy), with a small head."""
    x1, y1 = x + dx, y + dy
    draw.line([(x, y), (x1, y1)], fill=colour, width=width)
    length = math.hypot(dx, dy)
    if length < 1:
        return
    ux, uy = dx / length, dy / length
    head = max(4.0, 0.35 * length)
    for side in (-1, 1):
        hx = x1 - head * (ux * 0.87 - side * uy * 0.5)
        hy = y1 - head * (uy * 0.87 + side * ux * 0.5)
        draw.line([(x1, y1), (hx, hy)], fill=colour, width=width)


def lake_panel(values: np.ndarray, from_deg: np.ndarray | None = None) -> Image.Image:
    """The lake grid of satellite_wind.py drawn twice its size: shaded land, the lake coloured
    blue (below 1) to red (above 1) around the lake's average, and an arrow every 150 m along the
    wind (length: values) when from_deg is given."""
    east, north, lake, _ = lake_cells()
    dem = np.load(area.WORK_DIR / "swissaltiregio_10m.npz")
    c0 = int((east[0, 0] - 5 - float(dem["west"])) / 10)
    r0 = int((float(dem["north"]) - north[0, 0] - 5) / 10)
    shade = hillshade(dem["heights"][r0:r0 + east.shape[0], c0:c0 + east.shape[1]].astype(float), 10.0)
    land = (0.55 + 0.4 * shade)[..., None] * np.array([210, 208, 200])
    colour = np.where(lake[..., None], diverging(np.where(lake, values, 1.0), 0.25), land)
    image = Image.fromarray(colour.astype(np.uint8)).resize((east.shape[1] * 2, east.shape[0] * 2), Image.BILINEAR)
    if from_deg is not None:
        draw = ImageDraw.Draw(image)
        step = 15  # an arrow every 150 m
        for r in range(step // 2, east.shape[0], step):
            for c in range(step // 2, east.shape[1], step):
                if lake[r, c]:
                    length = 22 * values[r, c]
                    rad = np.deg2rad(from_deg[r, c])
                    arrow(draw, c * 2, r * 2, -length * math.sin(rad), length * math.cos(rad), (20, 20, 20), 2)
    return image


def save_sheet(panels: list[Image.Image], labels: list[str], title: str, explain: str, credit: str, path: Path) -> None:
    """Panels side by side with a title, a label each, and the colour scale with two lines of text."""
    margin_top, margin_bottom = 70, 60
    width = max(sum(p.width for p in panels) + 20 * (len(panels) - 1), 1240)
    sheet = Image.new("RGB", (width, panels[0].height + margin_top + margin_bottom), (252, 252, 251))
    d = ImageDraw.Draw(sheet)
    d.text((10, 10), title, fill=(11, 11, 11), font=font(22, bold=True))
    x = 0
    for p, label in zip(panels, labels):
        sheet.paste(p, (x, margin_top))
        d.text((x + 10, margin_top - 28), label, fill=(82, 81, 78), font=font(16))
        x += p.width + 20
    y = margin_top + panels[0].height + 18
    for k in range(300):
        colour = tuple(int(c) for c in diverging(np.array(0.75 + 0.5 * k / 299), 0.25))
        d.line([(10 + k, y), (10 + k, y + 14)], fill=colour)
    for value, text, anchor in ((0.75, "-25 %", "lm"), (1.0, "lake average", "mm"), (1.25, "+25 %", "rm")):
        d.text((10 + (value - 0.75) / 0.5 * 299, y + 28), text, fill=(82, 81, 78), font=font(14), anchor=anchor)
    d.text((330, y + 7), explain, fill=(82, 81, 78), font=font(14), anchor="lm")
    d.text((330, y + 28), credit, fill=(82, 81, 78), font=font(14), anchor="lm")
    sheet.save(path, optimize=True)


def picture_lake(folder: Path, path: Path, title: str, satellite: dict | None = None) -> None:
    """A WindNinja run over the lake, and the satellite's roughness map beside it."""
    east, north, lake, _ = lake_cells()
    speed, from_deg = flow_at(folder, east, north)
    panels = [lake_panel(speed / np.median(speed[lake]), from_deg)]
    labels = ["Computed (WindNinja): speed and direction"]
    explain = "Blue: weaker wind than the lake's average. Red: stronger."
    credit = f"North is up; the lake is about 3 km long. Wind {OUTPUT_HEIGHT_M:.0f} m above the water."
    if satellite is not None and SATELLITE_KEY in satellite:
        rough = smooth(satellite[SATELLITE_KEY], lake, passes=2)
        panels.append(lake_panel(rough / np.nanmedian(rough[lake])))
        labels.append(f"Seen from space: rough water, {satellite['n_maloja']} Maloja afternoons")
        explain = ("Left: weaker (blue) or stronger (red) wind than the lake's average. Right: smoother (blue) or "
                   "rougher (red) water than average, Maloja photos divided by calm ones.")
        credit = f"North is up; the lake is about 3 km long. Contains modified Copernicus Sentinel data {satellite['years']}."
    save_sheet(panels, labels, title, explain, credit, path)


def read_game_pattern() -> tuple[Grid, Grid, dict]:
    """The pattern as the game reads it: speed factor and turn, as grids."""
    meta = json.loads((GAME_DIR / "maloja_pattern.json").read_text())
    values = np.fromfile(GAME_DIR / meta["file"], dtype="<f4").astype(float)
    cells = meta["rows"] * meta["columns"]
    grids = []
    for layer in (values[:cells], values[cells:]):
        grid = Grid.__new__(Grid)
        grid.cell, grid.west, grid.north = meta["cell_m"], meta["west_m"], meta["north_m"]
        grid.values = layer.reshape(meta["rows"], meta["columns"])
        grids.append(grid)
    return grids[0], grids[1], meta


def picture_game(path: Path, satellite: dict | None) -> None:
    """What the game will use over the lake: strength as colour, direction as arrows."""
    factor, turn, meta = read_game_pattern()
    east, north, _, _ = lake_cells()
    from_deg = meta["lake_direction_deg"] + turn.sample(east, north)  # turns are small and smooth
    years = f" Contains modified Copernicus Sentinel data {satellite['years']}." if satellite else ""
    save_sheet([lake_panel(factor.sample(east, north), from_deg)],
               [f"Direction: WindNinja ({meta['run']}). Strength on Lake Silvaplana: the satellite. Elsewhere: WindNinja."],
               "The Maloja's fixed pattern for the game (first version)",
               "Blue: weaker wind than the lake's average. Red: stronger. Arrows: where the wind blows to.",
               f"North is up; the lake is about 3 km long.{years}", path)


def picture_valley(folder: Path, path: Path, title: str) -> None:
    """The whole valley: shaded terrain, the lakes, arrows every 600 m for the flow."""
    speed, direction, _, _ = wind_of(folder)
    dem = tifffile.imread(write_dem()).astype(float)
    shade = hillshade(dem, DEM_CELL_M)
    lake_level = 1790.6
    grey = (0.35 + 0.6 * shade) * 235
    rgb = np.stack([grey, grey, grey], axis=-1)
    # Lakes are exactly flat in swissALTIRegio; meadows never are.
    gy, gx = np.gradient(dem, DEM_CELL_M)
    water = (np.abs(gx) + np.abs(gy) < 1e-4) & (dem < lake_level + 30) & (dem > 1700)
    rgb[water] = [134, 182, 239]
    image = Image.fromarray(rgb.astype(np.uint8))
    scale = 1.4
    image = image.resize((int(image.width * scale), int(image.height * scale)), Image.BILINEAR)
    draw = ImageDraw.Draw(image)
    median = float(np.median(speed.values))
    step_m = 600.0
    for n in np.arange(NORTH - step_m / 2, SOUTH, -step_m):
        for e in np.arange(WEST + step_m / 2, EAST, step_m):
            c = int((e - speed.west) / speed.cell)
            r = int((speed.north - n) / speed.cell)
            if not (0 <= r < speed.values.shape[0] and 0 <= c < speed.values.shape[1]):
                continue
            dem_r, dem_c = int((NORTH - n) / DEM_CELL_M), int((e - WEST) / DEM_CELL_M)
            if dem[dem_r, dem_c] > VALLEY_TOP_M:
                continue  # the Maloja is a shallow valley wind; higher up blows another wind
            s = min(speed.values[r, c] / median, 2.5)
            rad = np.deg2rad(direction.values[r, c])
            x = (e - WEST) / DEM_CELL_M * scale
            y = (NORTH - n) / DEM_CELL_M * scale
            arrow(draw, x, y, -14 * s * math.sin(rad), 14 * s * math.cos(rad), (190, 40, 40), 2)
    sheet = Image.new("RGB", (image.width, image.height + 60), (252, 252, 251))
    sheet.paste(image, (0, 60))
    d = ImageDraw.Draw(sheet)
    d.text((10, 8), title, fill=(11, 11, 11), font=font(20, bold=True))
    d.text((10, 34), "Maloja pass bottom left, Lake Silvaplana in the middle, St. Moritz top right. Arrows below "
           f"{VALLEY_TOP_M:.0f} m only; length: speed. North is up, 22 km wide.", fill=(82, 81, 78), font=font(14))
    sheet.save(path, optimize=True)


# ---------------------------------------------------------------- main

def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--force", action="store_true", help="redo the WindNinja runs")
    args = parser.parse_args()

    write_dem()
    east, north, lake, inner = lake_cells()
    satellite = None
    roughness = satellite_wind.OUT_DIR / "roughness.npz"
    if roughness.exists():
        data = np.load(roughness)
        satellite = {k: data[k] for k in data.files}
        used = json.loads((satellite_wind.OUT_DIR / "used.json").read_text())
        satellite["n_maloja"] = len(used["maloja"])
        years = sorted({int(s["utc"][:4]) for kind in ("maloja", "calm") for s in used[kind]})
        satellite["years"] = f"{years[0]}-{years[-1]}"
    else:
        print("No satellite roughness map yet (run satellite_wind.py); comparing with the station only.")

    comparison = {}
    print(f"{'run':24s} {'lake from':>9s} {'station':>8s} {'turn':>6s} {'stat/lake':>9s} "
          f"{'lake p10-p90':>13s} {'satellite r':>11s}")
    for air, alpha in AIR.items():
        for direction in DIRECTIONS:
            name = f"{air}_{direction}"
            folder = run(name, direction, alpha, SWEEP_MESH_M, args.force)
            c = compare(folder, satellite, east, north, lake, inner)
            c.update({"air": air, "alpha": alpha, "input_direction_deg": direction})
            comparison[name] = c
            r = f"{c['satellite_correlation']:+.2f}" if "satellite_correlation" in c else "-"
            print(f"{name:24s} {c['lake_direction_deg']:9.0f} {c['station_direction_deg']:8.0f} "
                  f"{c['station_turn_vs_lake_deg']:+6.0f} {c['station_speed_vs_lake']:9.2f} "
                  f"{c['lake_speed_p10_p90'][0]:6.2f}-{c['lake_speed_p10_p90'][1]:.2f} {r:>11s}")

    # Runs of WindNinja's slower momentum solver (OpenFOAM), made by hand, are compared too, but
    # not chosen: the pattern for the game comes from the sweep above.
    for folder in sorted((WORK / "runs").glob("momentum_*")):
        if list(folder.glob("*_vel.asc")):
            c = compare(folder, satellite, east, north, lake, inner)
            c.update({"air": "momentum solver", "input_direction_deg": None})
            comparison[folder.name] = c
            r = f"{c['satellite_correlation']:+.2f}" if "satellite_correlation" in c else "-"
            print(f"{folder.name:24s} {c['lake_direction_deg']:9.0f} {c['station_direction_deg']:8.0f} "
                  f"{c['station_turn_vs_lake_deg']:+6.0f} {c['station_speed_vs_lake']:9.2f} "
                  f"{c['lake_speed_p10_p90'][0]:6.2f}-{c['lake_speed_p10_p90'][1]:.2f} {r:>11s}  (not chosen)")

    # Best: the station direction must match (within the input step), then the satellite.
    def score(item: tuple[str, dict]) -> float:
        c = item[1]
        miss = abs(angle_diff(c["station_direction_deg"], STATION_DIRECTION_DEG)) / 10.0
        return miss - 2.0 * c.get("satellite_correlation", 0.0)
    best_name, best = min(((n, c) for n, c in comparison.items() if not n.startswith("momentum")), key=score)
    print(f"Best fit: {best_name}")
    final_name = f"final_{best_name}_{FINAL_MESH_M}m"
    final = run(final_name, best["input_direction_deg"], best["alpha"], FINAL_MESH_M, args.force)
    final_comparison = compare(final, satellite, east, north, lake, inner)
    final_comparison.update({"from_sweep": best_name, "mesh_m": FINAL_MESH_M})
    comparison[final_name] = final_comparison
    print(f"{final_name}: lake from {final_comparison['lake_direction_deg']:.0f} deg, station "
          f"{final_comparison['station_direction_deg']:.0f} deg, satellite r "
          f"{final_comparison.get('satellite_correlation', float('nan')):+.2f}")
    (WORK / "comparison.json").write_text(json.dumps(comparison, indent=1))

    write_game_pattern(final, final_comparison, satellite)
    DOC_IMAGES.mkdir(parents=True, exist_ok=True)
    picture_lake(final, DOC_IMAGES / "pattern_lake.png", "The Maloja over Lake Silvaplana: computed, and seen from space",
                 satellite)
    picture_game(DOC_IMAGES / "pattern_game.png", satellite)
    air = best["air"].replace("_", " ")
    picture_valley(final, DOC_IMAGES / "pattern_valley.png", f"The Maloja down the valley (WindNinja, {air} air)")
    for name in comparison:
        if name.startswith("final"):
            continue
        picture_lake(WORK / "runs" / name, WORK / f"lake_{name}.png", name, satellite)
    print(f"Wrote {GAME_DIR / 'maloja_pattern.json'}, the pictures in {DOC_IMAGES} and {WORK}")


if __name__ == "__main__":
    main()
