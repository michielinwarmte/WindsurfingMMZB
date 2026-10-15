"""The Maloja seen from space: where Lake Silvaplana's water is rough, on Sentinel-2 photos.

Documentation/MALOJA_WIND_RESEARCH.md, "Seen from space". Sentinel-2 photographs the lake every
few days at 12:28 local time, when the Maloja is usually blowing. Rough water reflects more of
the bright sky than smooth water, so in the near-infrared band (where the water itself is
almost black) a windy lake looks lighter, and a lee or a wind hole looks darker.

This script:
1. finds every summer photo of the lake since 2017 (Earth Search STAC, Sentinel-2 L2A, free),
2. reads Segl-Maria's wind at the moment of each photo (run download.py wind-valley first),
3. downloads only the lake's corner of the photos taken in a Maloja (>= 10 kt) or a calm
   (<= 4 kt): about 10 MB per photo instead of 1 GB,
4. averages them on the map's own grid (Swiss LV95, 10 m cells), so step 2 of the wind
   analyser can compare its computed wind with what the satellite saw.

Run from the repo root (about 10 minutes the first time, then it uses the saved cut-outs):

    python tools/map/satellite_wind.py

Output in .map_data/work/wind_research/satellite/: one cut-out per photo (.npz and a colour
.png), scenes.json (every photo with the wind at the station), roughness.npz (the averages)
and roughness_*.png (pictures of them).

Source: Copernicus Sentinel-2 data, processed by ESA; the cloud-optimised copies are the
"Sentinel-2 Cloud-Optimized GeoTIFFs" on AWS (Element 84 Earth Search).
"""
import json
import math
import urllib.request
from datetime import date, datetime, timedelta
from pathlib import Path

import numpy as np
import tifffile
from PIL import Image

import maloja_research as research
import silvaplana_area as area

SEARCH = "https://earth-search.aws.element84.com/v1/search"
TILE = "32TNS"  # the Sentinel-2 tile (UTM zone 32) the lake lies in
FIRST_YEAR = 2017
OUT_DIR = area.WORK_DIR / "wind_research" / "satellite"

# Thresholds at Segl-Maria for the 10 minutes of the photo.
MALOJA_MIN_MS = 10 * 0.514444  # a Maloja photo: at least 10 kt from the Maloja sector
CALM_MAX_MS = 4 * 0.514444  # a calm photo: at most 4 kt

# The map grid the results are put on: LV95, 10 m cells, around the lake.
GRID_WEST, GRID_EAST = 2_778_400.0, 2_782_600.0
GRID_SOUTH, GRID_NORTH = 1_144_200.0, 1_148_700.0
GRID_CELL = 10.0

# Sentinel-2 scene classification (SCL band): cloud shadow, clouds, cirrus, snow.
SCL_BAD = (3, 8, 9, 10, 11)

# A photo is used only when it is clean (the first run in Session 42 showed the cloud mask alone
# lets cloud shadows and haze through):
CLOUD_RING_CELLS = 50  # no clouds or cloud shadows within 500 m of the lake...
MAX_CLOUD_NEAR = 0.005  # ...on more than 0.5 % of that area,
MAX_NIR_OPEN_P95 = 450  # no haze or sun glint over the water (near-infrared, 0 to 10000 scale),
RED_OPEN_RANGE = (50, 700)  # and a usable red signal on the water: not crushed to 0, not washed out.
# The red band is used: in the near-infrared the atmospheric correction leaves the water at
# almost exactly 0, too little to see the wind in.
BAND = "red"


# ---------------------------------------------------------------- reading only part of a big file

class HttpFile:
    """A read-only file over HTTP range requests. tifffile asks for the header and the tiles it
    needs, and only those bytes are downloaded."""

    BLOCK = 1 << 16

    def __init__(self, url: str) -> None:
        self.url = url
        self.pos = 0
        self.cache: dict[int, bytes] = {}
        self.bytes_read = 0
        with urllib.request.urlopen(urllib.request.Request(url, method="HEAD"), timeout=60) as response:
            self.size = int(response.headers["Content-Length"])

    def _get(self, start: int, end: int) -> bytes:
        request = urllib.request.Request(self.url, headers={"Range": f"bytes={start}-{end - 1}"})
        for attempt in range(3):
            try:
                with urllib.request.urlopen(request, timeout=60) as response:
                    data = response.read()
                self.bytes_read += len(data)
                return data
            except OSError:
                if attempt == 2:
                    raise
        raise AssertionError("unreachable")

    def read(self, n: int = -1) -> bytes:
        if n < 0:
            n = self.size - self.pos
        if n > 4 * self.BLOCK:  # a tile: fetch it in one go
            data = self._get(self.pos, min(self.pos + n, self.size))
        else:  # small header reads: fetch and keep 64 KB blocks
            first, last = self.pos // self.BLOCK, (self.pos + n - 1) // self.BLOCK
            for block in range(first, last + 1):
                if block not in self.cache:
                    self.cache[block] = self._get(block * self.BLOCK, min((block + 1) * self.BLOCK, self.size))
            joined = b"".join(self.cache[b] for b in range(first, last + 1))
            data = joined[self.pos - first * self.BLOCK:][:n]
        self.pos += len(data)
        return data

    def seek(self, offset: int, whence: int = 0) -> int:
        self.pos = offset if whence == 0 else self.pos + offset if whence == 1 else self.size + offset
        return self.pos

    def tell(self) -> int:
        return self.pos

    def seekable(self) -> bool:
        return True

    def readable(self) -> bool:
        return True

    def close(self) -> None:
        pass

    @property
    def closed(self) -> bool:
        return False


def read_window(url: str, box: tuple[float, float, float, float]) -> tuple[np.ndarray, tuple[float, float, float]]:
    """The part of a cloud-optimised GeoTIFF inside box = (min x, min y, max x, max y) in UTM.
    Returns the pixels and (x of the left edge, y of the top edge, pixel size)."""
    fh = HttpFile(url)
    with tifffile.TiffFile(fh) as tif:
        page = tif.pages[0]
        x0, y0 = page.tags["ModelTiepointTag"].value[3:5]
        size = page.tags["ModelPixelScaleTag"].value[0]
        c0, c1 = int((box[0] - x0) // size), int(math.ceil((box[2] - x0) / size))
        r0, r1 = int((y0 - box[3]) // size), int(math.ceil((y0 - box[1]) / size))
        tw, tl, samples = page.tilewidth, page.tilelength, page.samplesperpixel
        across = math.ceil(page.imagewidth / tw)
        out = np.zeros((r1 - r0, c1 - c0, samples), dtype=page.dtype)
        for ty in range(r0 // tl, (r1 - 1) // tl + 1):
            for tx in range(c0 // tw, (c1 - 1) // tw + 1):
                index = ty * across + tx
                fh.seek(page.dataoffsets[index])
                segment, _, _ = page.decode(fh.read(page.databytecounts[index]), index, jpegtables=page.jpegtables)
                segment = segment.reshape(tl, tw, samples)
                a0, a1 = max(r0, ty * tl), min(r1, ty * tl + tl)
                b0, b1 = max(c0, tx * tw), min(c1, tx * tw + tw)
                out[a0 - r0:a1 - r0, b0 - c0:b1 - c0] = segment[a0 - ty * tl:a1 - ty * tl, b0 - tx * tw:b1 - tx * tw]
    return out, (x0 + c0 * size, y0 - r0 * size, size)


# ---------------------------------------------------------------- coordinates

def wgs84_to_utm32(lon: float, lat: float) -> tuple[float, float]:
    """WGS84 longitude and latitude to UTM zone 32 north (the standard series; millimetres here)."""
    a, f = 6378137.0, 1 / 298.257223563
    e2 = f * (2 - f)
    ep2 = e2 / (1 - e2)
    k0 = 0.9996
    phi, lam = math.radians(lat), math.radians(lon)
    n = a / math.sqrt(1 - e2 * math.sin(phi) ** 2)
    t = math.tan(phi) ** 2
    c = ep2 * math.cos(phi) ** 2
    aa = math.cos(phi) * (lam - math.radians(9.0))
    m = a * ((1 - e2 / 4 - 3 * e2 ** 2 / 64 - 5 * e2 ** 3 / 256) * phi
             - (3 * e2 / 8 + 3 * e2 ** 2 / 32 + 45 * e2 ** 3 / 1024) * math.sin(2 * phi)
             + (15 * e2 ** 2 / 256 + 45 * e2 ** 3 / 1024) * math.sin(4 * phi)
             - (35 * e2 ** 3 / 3072) * math.sin(6 * phi))
    x = k0 * n * (aa + (1 - t + c) * aa ** 3 / 6 + (5 - 18 * t + t * t + 72 * c - 58 * ep2) * aa ** 5 / 120)
    y = k0 * (m + n * math.tan(phi) * (aa * aa / 2 + (5 - t + 9 * c + 4 * c * c) * aa ** 4 / 24
                                       + (61 - 58 * t + t * t + 600 * c - 330 * ep2) * aa ** 6 / 720))
    return x + 500_000.0, y


def grid_lv95() -> tuple[np.ndarray, np.ndarray]:
    """Cell centres of the result grid: east and north (LV95), rows from the north edge."""
    east = np.arange(GRID_WEST + GRID_CELL / 2, GRID_EAST, GRID_CELL)
    north = np.arange(GRID_NORTH - GRID_CELL / 2, GRID_SOUTH, -GRID_CELL)
    return np.meshgrid(east, north)


def grid_in_utm() -> tuple[np.ndarray, np.ndarray]:
    east, north = grid_lv95()
    xs, ys = np.zeros_like(east), np.zeros_like(east)
    for index in np.ndindex(east.shape):
        xs[index], ys[index] = wgs84_to_utm32(*area.lv95_to_wgs84(east[index], north[index]))
    return xs, ys


def lake_mask() -> np.ndarray:
    """Lake Silvaplana (and the bit of Lake Champfèr in the box) on the result grid, from the
    game's shore heights: water where the ground is more than 0.3 m below the lake surface."""
    info = json.loads((area.REPO_ROOT / "Game/maps/silvaplana/terrain/shore_heights.json").read_text())
    raw = np.fromfile(area.REPO_ROOT / "Game/maps/silvaplana/terrain" / info["file"], dtype="<u2")
    heights = raw.reshape(info["rows"], info["columns"]) * info["height_scale_m"] + info["height_offset_m"]
    east, north = grid_lv95()
    col = np.round((east - info["west_m"]) / info["cell_m"]).astype(int)
    row = np.round((info["north_m"] - north) / info["cell_m"]).astype(int)
    inside = (col >= 0) & (col < info["columns"]) & (row >= 0) & (row < info["rows"])
    mask = np.zeros(east.shape, dtype=bool)
    mask[inside] = heights[row[inside], col[inside]] < -0.3
    return mask


# ---------------------------------------------------------------- the photos

def search_scenes() -> list[dict]:
    lon0, lat0 = area.lv95_to_wgs84(2_779_500, 1_145_500)
    lon1, lat1 = area.lv95_to_wgs84(2_781_500, 1_147_500)
    scenes = []
    for year in range(FIRST_YEAR, date.today().year + 1):
        body = {"collections": ["sentinel-2-l2a"], "bbox": [lon0, lat0, lon1, lat1], "limit": 200,
                "datetime": f"{year}-06-01T00:00:00Z/{year}-09-30T23:59:59Z",
                "query": {"eo:cloud_cover": {"lt": 60}}}
        request = urllib.request.Request(SEARCH, data=json.dumps(body).encode(),
                                         headers={"Content-Type": "application/json"})
        with urllib.request.urlopen(request, timeout=60) as response:
            for feature in json.load(response)["features"]:
                if TILE not in feature["id"]:
                    continue
                assets = feature["assets"]
                properties = feature["properties"]
                # Since processing baseline 04.00 (2022) the values carry +1000, unless Earth
                # Search already took it off.
                baseline = float(properties.get("s2:processing_baseline", "0") or 0)
                offset = 1000 if baseline >= 4.0 and not properties.get("earthsearch:boa_offset_applied") else 0
                scenes.append({"id": feature["id"], "utc": properties["datetime"][:19],
                               "tile_cloud_pct": properties["eo:cloud_cover"], "offset": offset,
                               "nir": assets["nir"]["href"], "red": assets["red"]["href"],
                               "scl": assets["scl"]["href"], "visual": assets["visual"]["href"]})
    # Some days are listed twice (reprocessed); keep the newest version of each.
    newest: dict[str, dict] = {}
    for s in sorted(scenes, key=lambda s: s["id"]):
        newest[s["utc"][:10]] = s
    return sorted(newest.values(), key=lambda s: s["utc"])


def add_station_wind(scenes: list[dict]) -> None:
    """Segl-Maria's 10-minute values for the period that holds the photo's moment.
    MeteoSwiss stamps a 10-minute value with the end of its period."""
    days = sorted({(datetime.fromisoformat(s["utc"]) + timedelta(hours=2)).date() for s in scenes})
    sia = research.load_station("sia", days)
    for s in scenes:
        local = datetime.fromisoformat(s["utc"]) + timedelta(hours=2)
        row = days.index(local.date())
        slot = (local.hour * 60 + local.minute) // 10 + 1
        s["station"] = {k: (None if not np.isfinite(sia[k][row, slot]) else float(sia[k][row, slot]))
                        for k in ("mean", "gust1", "dir")}


def kind_of(scene: dict) -> str | None:
    wind = scene["station"]
    if wind["mean"] is None or wind["dir"] is None:
        return None
    if wind["mean"] >= MALOJA_MIN_MS and research.SECTOR_DEG[0] <= wind["dir"] <= research.SECTOR_DEG[1]:
        return "maloja"
    if wind["mean"] <= CALM_MAX_MS:
        return "calm"
    return None


def cut_out(scene: dict, box: tuple[float, float, float, float]) -> Path:
    """Downloads the lake's corner of one photo (near-infrared, red, scene classes, colour)."""
    path = OUT_DIR / f"{scene['id']}.npz"
    if path.exists():
        return path
    nir, nir_geo = read_window(scene["nir"], box)
    red, _ = read_window(scene["red"], box)
    scl, scl_geo = read_window(scene["scl"], box)
    rgb, rgb_geo = read_window(scene["visual"], box)
    np.savez_compressed(path, nir=nir[..., 0], red=red[..., 0], scl=scl[..., 0], rgb=rgb[..., :3],
                        nir_geo=nir_geo, scl_geo=scl_geo, rgb_geo=rgb_geo)
    Image.fromarray(rgb[..., :3]).save(OUT_DIR / f"{scene['id']}.png")
    return path


def sample(image: np.ndarray, geo, xs: np.ndarray, ys: np.ndarray) -> np.ndarray:
    """Nearest pixel of a cut-out at UTM points."""
    left, top, size = geo
    col = np.floor((xs - left) / size).astype(int)
    row = np.floor((top - ys) / size).astype(int)
    col = np.clip(col, 0, image.shape[1] - 1)
    row = np.clip(row, 0, image.shape[0] - 1)
    return image[row, col]


def grow(mask: np.ndarray, cells: int) -> np.ndarray:
    grown = mask.copy()
    for _ in range(cells):
        grown[1:-1, 1:-1] |= grown[:-2, 1:-1] | grown[2:, 1:-1] | grown[1:-1, :-2] | grown[1:-1, 2:]
    return grown


def quality(path: Path, xs: np.ndarray, ys: np.ndarray, lake: np.ndarray, offset: int) -> dict:
    """How clean a photo is over the lake: clouds and their shadows within 500 m, haze or glint on
    the open water (near-infrared), and the red signal on the open water."""
    data = np.load(path)
    near = grow(lake, CLOUD_RING_CELLS)
    open_water = shrink(lake, 10)
    classes = sample(data["scl"], data["scl_geo"], xs, ys)
    nir = sample(data["nir"], data["nir_geo"], xs, ys).astype(float) - offset
    red = sample(data["red"], data["nir_geo"], xs, ys).astype(float) - offset
    result = {"cloud_near": float(np.isin(classes[near], SCL_BAD).mean()),
              "nir_open_p95": float(np.percentile(nir[open_water], 95)),
              "red_open_p50": float(np.median(red[open_water]))}
    result["clean"] = (result["cloud_near"] <= MAX_CLOUD_NEAR and result["nir_open_p95"] <= MAX_NIR_OPEN_P95
                       and RED_OPEN_RANGE[0] <= result["red_open_p50"] <= RED_OPEN_RANGE[1])
    return result


def relative_brightness(path: Path, xs: np.ndarray, ys: np.ndarray, lake: np.ndarray, band: str,
                        offset: int) -> np.ndarray:
    """A photo's brightness on the lake divided by its median over the open water, on the map grid."""
    data = np.load(path)
    value = sample(data[band], data["nir_geo"], xs, ys).astype(float) - offset
    result = np.full(value.shape, np.nan)
    result[lake] = value[lake] / np.median(value[shrink(lake, 10)])
    return result


# ---------------------------------------------------------------- the direction of the streaks

def box_mean(values: np.ndarray, mask: np.ndarray, radius: int) -> np.ndarray:
    """Mean over a (2 radius + 1) square inside the mask (summed-area table, so any size is fast)."""
    def window_sum(a: np.ndarray) -> np.ndarray:
        s = np.pad(a, ((1, 0), (1, 0))).cumsum(0).cumsum(1)
        rows, cols = a.shape
        r0 = np.clip(np.arange(rows) - radius, 0, rows)
        r1 = np.clip(np.arange(rows) + radius + 1, 0, rows)
        c0 = np.clip(np.arange(cols) - radius, 0, cols)
        c1 = np.clip(np.arange(cols) + radius + 1, 0, cols)
        return s[r1][:, c1] - s[r0][:, c1] - s[r1][:, c0] + s[r0][:, c0]
    total = window_sum(np.where(mask, values, 0.0))
    count = window_sum(mask.astype(float))
    return np.where(mask, total / np.maximum(count, 1), np.nan)


def shrink(mask: np.ndarray, cells: int) -> np.ndarray:
    inner = mask.copy()
    for _ in range(cells):
        inner[1:-1, 1:-1] &= inner[:-2, 1:-1] & inner[2:, 1:-1] & inner[1:-1, :-2] & inner[1:-1, 2:]
        inner[0, :] = inner[-1, :] = inner[:, 0] = inner[:, -1] = False
    return inner


def streak_tensor(relative: np.ndarray, calm_mean: np.ndarray, lake: np.ndarray) -> np.ndarray:
    """The summed structure tensor [ee, nn, en] of a photo's streaks on the open lake.

    Streaks on a windy lake lie along the wind. Brightness changes fastest across them, so the
    main direction of the brightness gradient is across the wind. To see only the streaks:
    divide by the calm photos (what is in every photo), keep only patterns smaller than about
    300 m, and stay 100 m away from the shore."""
    open_water = shrink(lake, 10)
    x = relative / calm_mean
    x = x - box_mean(x, lake, 15)  # remove patterns larger than ~300 m
    x = box_mean(x, lake, 1)  # and the pixel noise
    x = np.where(np.isfinite(x), x, 0.0)
    grad_east = (np.roll(x, -1, 1) - np.roll(x, 1, 1)) / 2  # columns go east
    grad_north = (np.roll(x, 1, 0) - np.roll(x, -1, 0)) / 2  # rows go south
    ok = open_water & np.isfinite(relative)
    return np.array([(grad_east ** 2)[ok].sum(), (grad_north ** 2)[ok].sum(), (grad_east * grad_north)[ok].sum()])


def streak_direction(tensor: np.ndarray) -> tuple[float, float]:
    """The streaks' direction as the bearing the wind would come from (180 to 360 degrees, as
    the Maloja comes from the south-west half), and how clearly the streaks line up (0 to 1)."""
    ee, nn, en = tensor
    across = 0.5 * math.degrees(math.atan2(2 * en, ee - nn))  # gradient, counter-clockwise from east
    along = across + 90.0
    bearing = (90.0 - along) % 180.0  # compass bearing of the streak line, 0 to 180
    coherence = math.sqrt((ee - nn) ** 2 + 4 * en ** 2) / (ee + nn)
    return bearing + 180.0, coherence


# ---------------------------------------------------------------- pictures

def ramp_picture(values: np.ndarray, lake: np.ndarray, lo: float, hi: float, path: Path, scale: int = 3) -> None:
    """Lake cells on a one-hue blue ramp (light = smooth, dark blue = rough), land grey."""
    stops = np.array([[0xcd, 0xe2, 0xfb], [0x86, 0xb6, 0xef], [0x39, 0x87, 0xe5],
                      [0x25, 0x6a, 0xbf], [0x18, 0x4f, 0x95], [0x0d, 0x36, 0x6b]], dtype=float)
    t = np.clip((values - lo) / (hi - lo), 0, 1) * (len(stops) - 1)
    i = np.clip(np.floor(t).astype(int), 0, len(stops) - 2)
    frac = (t - i)[..., None]
    colour = stops[i] * (1 - frac) + stops[i + 1] * frac
    picture = np.full(values.shape + (3,), 0xe6, dtype=float)
    ok = lake & np.isfinite(values)
    picture[ok] = colour[ok]
    image = Image.fromarray(picture.astype(np.uint8))
    image.resize((image.width * scale, image.height * scale), Image.NEAREST).save(path)


def example_picture(windy: dict, calm: dict, path: Path) -> None:
    """Two photos side by side: the lake in a Maloja and in a calm, for the research document."""
    from PIL import ImageDraw, ImageFont

    def font(size: int) -> ImageFont.FreeTypeFont:
        for candidate in (Path("C:/Windows/Fonts/segoeui.ttf"), Path("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf")):
            if candidate.exists():
                return ImageFont.truetype(str(candidate), size)
        return ImageFont.load_default(size)

    photos = [Image.open(OUT_DIR / f"{s['id']}.png") for s in (windy, calm)]
    w, h = photos[0].size
    scale = 2
    sheet = Image.new("RGB", (2 * w * scale + 20, h * scale + 70), (252, 252, 251))
    draw = ImageDraw.Draw(sheet)
    for k, (scene, photo) in enumerate(zip((windy, calm), photos)):
        x = k * (w * scale + 20)
        sheet.paste(photo.resize((w * scale, h * scale), Image.BILINEAR), (x, 36))
        kt = scene["station"]["mean"] / 0.514444
        draw.text((x + 4, 8), f"{scene['utc'][:10]}, 12:28: {kt:.0f} kt at Segl-Maria", fill=(11, 11, 11), font=font(18))
    years = sorted({windy["utc"][:4], calm["utc"][:4]})
    draw.text((4, h * scale + 44), f"Sentinel-2, true colour, north up. Contains modified Copernicus Sentinel data "
              f"{' and '.join(years)}.", fill=(82, 81, 78), font=font(14))
    sheet.save(path, quality=88, optimize=True)  # a photo: JPEG is a fifth of the PNG's size


def contact_sheet(paths: list[Path], path: Path, columns: int = 6) -> None:
    pictures = [Image.open(p) for p in paths]
    if not pictures:
        return
    w, h = pictures[0].size
    rows = math.ceil(len(pictures) / columns)
    sheet = Image.new("RGB", (columns * (w + 4), rows * (h + 4)), (255, 255, 255))
    for k, picture in enumerate(pictures):
        sheet.paste(picture.resize((w, h)), ((k % columns) * (w + 4), (k // columns) * (h + 4)))
    sheet.save(path)


# ---------------------------------------------------------------- main

def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    scenes = search_scenes()
    add_station_wind(scenes)
    for s in scenes:
        s["kind"] = kind_of(s)
    (OUT_DIR / "scenes.json").write_text(json.dumps(scenes, indent=1))
    chosen = [s for s in scenes if s["kind"]]
    print(f"{len(scenes)} summer photos of tile {TILE} since {FIRST_YEAR} (tile cloud < 60 %); "
          f"{sum(s['kind'] == 'maloja' for s in chosen)} in a Maloja, {sum(s['kind'] == 'calm' for s in chosen)} calm")

    xs, ys = grid_in_utm()
    box = (xs.min() - 50, ys.min() - 50, xs.max() + 50, ys.max() + 50)
    lake = lake_mask()
    stacks: dict[str, dict[str, list[np.ndarray]]] = {"maloja": {"nir": [], "red": []}, "calm": {"nir": [], "red": []}}
    used: dict[str, list[dict]] = {"maloja": [], "calm": []}
    for number, s in enumerate(chosen, 1):
        path = cut_out(s, box)
        s["quality"] = quality(path, xs, ys, lake, s["offset"])
        q = s["quality"]
        w = s["station"]
        line = (f"  [{number}/{len(chosen)}] {s['id']}: {s['kind']}, {w['mean'] / 0.514444:.1f} kt from {w['dir']:.0f}; "
                f"clouds near {100 * q['cloud_near']:.1f} %, haze {q['nir_open_p95']:.0f}, red {q['red_open_p50']:.0f}")
        if not q["clean"]:
            print(line + " -> not clean, skipped")
            continue
        print(line)
        for band in ("nir", "red"):
            stacks[s["kind"]][band].append(relative_brightness(path, xs, ys, lake, band, s["offset"]))
        used[s["kind"]].append(s)
    (OUT_DIR / "scenes.json").write_text(json.dumps(scenes, indent=1))

    result = {"east": grid_lv95()[0], "north": grid_lv95()[1], "lake": lake}
    for kind in stacks:
        for band in ("nir", "red"):
            if stacks[kind][band]:
                stack = np.array(stacks[kind][band])
                result[f"{kind}_{band}_mean"] = np.nanmean(stack, axis=0)
                result[f"{kind}_{band}_count"] = np.isfinite(stack).sum(axis=0)
    # The Maloja's own pattern: Maloja photos divided by calm ones, which removes what is there
    # in every photo (bright shores lighting the water next to them, the shallow lakebed).
    for band in ("nir", "red"):
        if f"maloja_{band}_mean" in result and f"calm_{band}_mean" in result:
            result[f"pattern_{band}"] = result[f"maloja_{band}_mean"] / result[f"calm_{band}_mean"]
    np.savez_compressed(OUT_DIR / "roughness.npz", **result)

    # The streaks' direction on the open lake, per photo and for all Maloja photos together.
    streaks: dict[str, list] = {"maloja": [], "calm": []}
    totals = {"maloja": np.zeros(3), "calm": np.zeros(3)}
    if f"calm_{BAND}_mean" in result:
        for kind in used:
            for s, relative in zip(used[kind], stacks[kind][BAND]):
                tensor = streak_tensor(relative, result[f"calm_{BAND}_mean"], lake)
                totals[kind] += tensor / (tensor[0] + tensor[1])  # every photo counts the same
                streaks[kind].append(streak_direction(tensor))
        print("Streaks on the open lake (bearing the wind would come from, and how clearly they line up):")
        for kind in used:
            if streaks[kind]:
                bearing, coherence = streak_direction(totals[kind])
                print(f"  {kind}: all {len(streaks[kind])} photos together {bearing:.0f} deg, coherence {coherence:.2f}")
        pairs = [(s["station"]["dir"], b, c) for s, (b, c) in zip(used["maloja"], streaks["maloja"])]
        for station_dir, bearing, coherence in sorted(pairs):
            print(f"    station {station_dir:5.0f}  lake streaks {bearing:5.0f}  coherence {coherence:.2f}")

    summary = {kind: [{"id": s["id"], "utc": s["utc"], "kt": s["station"]["mean"] / 0.514444, "quality": s["quality"],
                       "gust_kt": s["station"]["gust1"] / 0.514444, "from_deg": s["station"]["dir"],
                       "streaks_from_deg": streaks[kind][k][0] if streaks[kind] else None,
                       "streak_coherence": streaks[kind][k][1] if streaks[kind] else None}
                      for k, s in enumerate(used[kind])] for kind in used}
    if streaks["maloja"]:
        summary["streaks_all_maloja"] = dict(zip(("from_deg", "coherence"), streak_direction(totals["maloja"])))
        summary["streaks_all_calm"] = dict(zip(("from_deg", "coherence"), streak_direction(totals["calm"])))
    (OUT_DIR / "used.json").write_text(json.dumps(summary, indent=1))

    for name in [k for k in result if k.endswith("_mean") or k.startswith("pattern_")]:
        values = result[name]
        lo, hi = np.nanpercentile(values[lake], [2, 98])
        ramp_picture(values, lake, lo, hi, OUT_DIR / f"roughness_{name}.png")
        print(f"  {name}: 2-98 % range {lo:.2f}-{hi:.2f} -> roughness_{name}.png")
    for kind in used:
        contact_sheet([OUT_DIR / f"{s['id']}.png" for s in used[kind]], OUT_DIR / f"photos_{kind}.png")
    if used["maloja"] and used["calm"]:
        windiest = max(used["maloja"], key=lambda s: s["station"]["mean"])
        calmest = min(used["calm"], key=lambda s: s["station"]["mean"])
        example_picture(windiest, calmest, area.REPO_ROOT / "Documentation" / "images" / "maloja" / "satellite_example.jpg")
    print(f"Used {len(used['maloja'])} Maloja photos and {len(used['calm'])} calm ones. Wrote {OUT_DIR}")


if __name__ == "__main__":
    main()
