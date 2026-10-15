"""Gusts seen from space: their shape, size and strength on Lake Silvaplana (map plan, phase W3).

The wind analyser's gusts were first tuned to the station at Segl-Maria (one point, on land) and
Max's description. Max found them wrong on the water: too round ("it is a front that is wider")
and too strong against the wind around them ("too much difference"). This script measures both
on the Sentinel-2 photos that satellite_wind.py already downloaded (22 clean Maloja afternoons).

How. On a photo the wind's roughness makes the water brighter. satellite_wind.py divides each
photo by its median over the open water. Here each Maloja photo is divided again by the average
of all Maloja photos, which removes the lake's fixed pattern and what is in every photo (bright
shores, the shallow lakebed). Then, per photo, on the open water (150 m or more from the shore, the
main basin only), a tilt and the day's strength of the fixed pattern are taken out by a
least-squares fit. What is left is the moving weather of that moment: gusts and lulls.
- Shape and size: the correlation of what is left with itself, shifted by every distance up to
  400 m in every direction (the autocorrelation). Where it is still above 0.3, it forms an oval;
  its long axis and its length and width (2 standard deviations of the oval) are the typical
  patch's direction, length and width.
- Strength: the spread (standard deviation) of what is left, minus the sensor noise (half the
  variance of the difference between neighbouring pixels).
- Fronts: what is left, averaged across the lake in 20 m steps along the wind. How much of the
  photo's ups and downs these across-lake bands carry, and over what distance along the wind their
  correlation halves (about how deep a front is).
A photo counts as a front day when its oval lies across the wind, as a lane day otherwise.

The same analysis on the model (--model): the wind analyser's gusts, written on the same grid by
Game/maps/silvaplana/dev/export_gusts.gd, with the photos' sensor noise added (3 %), go through the
same steps. So the model and the photos are measured the same way, including what the analysis
can't see (a front a kilometre long partly looks like a tilt and is taken out with it).

What it can't tell:
- The spread is in brightness, not knots. Rougher water reflects more, but how much more for 10 %
  more wind depends on the sun and the view. W1 took 10 % brighter as 10 % more wind; sun-glint
  theory (Cox and Munk 1954) for a sun 60 degrees up and a satellite looking straight down gives
  about 10 % brighter for 17 % more wind. So the wind's spread is 1 to 1.7 times the number here.
- All photos are from 12:28, when the Maloja is still building (about 11 kt at the station).
- 10 m pixels: patches smaller than about 30 m are lost.

Run from the repo root, after satellite_wind.py (a few seconds):

    python tools/map/gust_shapes.py
    python tools/map/gust_shapes.py --model <folder>     (after export_gusts.gd wrote <folder>)

Output: printed per photo and together; .map_data/work/wind_research/gust_shapes.json;
Documentation/images/maloja/gust_photos.png (four photos: what is left after the fixed pattern).
"""
import argparse
import json
import math
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont

import satellite_wind as sw
import silvaplana_area as area

NARROWS_NORTH_M = 1_147_780.0  # the narrows between Lake Silvaplana and Lake Champfèr
SHORE_CELLS = 15  # 150 m from the shore
MAX_LAG_CELLS = 40  # 400 m
OVAL_LEVEL = 0.3
WIND_TO_DEG = 42.0  # the lake's wind moves to 42 degrees (W1: it comes from 222)
EXAMPLES = ("20210923", "20190914", "20220625", "20200630")  # two days with fronts, two with lanes
FRONT_STEP_M = 20.0
LAKE_HALF_LENGTH_M = 1700.0
MODEL_NOISE = 0.030  # the photos' sensor noise (median of the 22 photos, from neighbouring pixels)
OUT_JSON = area.WORK_DIR / "wind_research" / "gust_shapes.json"
OUT_PICTURE = area.REPO_ROOT / "Documentation" / "images" / "maloja" / "gust_photos.png"
OUT_MODEL_PICTURE = area.REPO_ROOT / "Documentation" / "images" / "maloja" / "gust_model.png"


def leftover(photo: np.ndarray, maloja_mean: np.ndarray, pattern: np.ndarray, water: np.ndarray,
             east: np.ndarray, north: np.ndarray) -> np.ndarray:
    """What is left of a photo after the average Maloja photo, a tilt and the day's strength of
    the fixed pattern are taken out (NaN off the open water)."""
    anomaly = photo / maloja_mean - 1.0
    m = water & np.isfinite(anomaly)
    fit = np.column_stack([np.ones(m.sum()), (east[m] - 2_780_500.0) / 1000.0, (north[m] - 1_146_600.0) / 1000.0,
                           pattern[m] - 1.0])
    coefficients, *_ = np.linalg.lstsq(fit, anomaly[m], rcond=None)
    result = np.full(anomaly.shape, np.nan)
    result[m] = anomaly[m] - fit @ coefficients
    return result


def autocorrelation(values: np.ndarray) -> np.ndarray:
    """The correlation of the values with themselves shifted by up to MAX_LAG_CELLS each way, only
    where both are on the water (computed with Fourier transforms). Row 0 is north, column 0 west;
    the middle is no shift, and it is 1 there."""
    known = np.isfinite(values)
    filled = np.where(known, values, 0.0)
    rows, cols = values.shape
    size = (2 * rows, 2 * cols)
    f = np.fft.rfft2(filled, s=size)
    g = np.fft.rfft2(known.astype(float), s=size)
    products = np.fft.fftshift(np.fft.irfft2(f * np.conj(f), s=size))
    pairs = np.fft.fftshift(np.fft.irfft2(g * np.conj(g), s=size))
    window = (slice(rows - MAX_LAG_CELLS, rows + MAX_LAG_CELLS + 1), slice(cols - MAX_LAG_CELLS, cols + MAX_LAG_CELLS + 1))
    c = products[window] / np.maximum(pairs[window], 1.0)
    return c / c[MAX_LAG_CELLS, MAX_LAG_CELLS]


def oval(correlation: np.ndarray) -> dict:
    """The oval where the correlation is above OVAL_LEVEL: the bearing of its long axis (0 to 180),
    its length and width (2 standard deviations, metres), weighted by how far above the level."""
    rows, cols = np.where(correlation > OVAL_LEVEL)
    north_m = -(rows - MAX_LAG_CELLS) * sw.GRID_CELL
    east_m = (cols - MAX_LAG_CELLS) * sw.GRID_CELL
    weights = correlation[rows, cols] - OVAL_LEVEL
    values, vectors = np.linalg.eigh(np.cov(np.vstack([east_m, north_m]), aweights=weights))
    long_axis = vectors[:, 1]
    bearing = math.degrees(math.atan2(long_axis[0], long_axis[1])) % 180.0
    return {"axis_deg": round(bearing, 1), "length_m": round(2 * math.sqrt(values[1])),
            "width_m": round(2 * math.sqrt(values[0])), "ratio": round(math.sqrt(values[1] / values[0]), 2)}


def spread(values: np.ndarray) -> float:
    """The spread (standard deviation) of the values without the sensor noise. Noise doesn't
    repeat from one pixel to the next, so half the variance of neighbour differences is noise."""
    neighbours = values[:, 1:] - values[:, :-1]
    noise = np.nanvar(neighbours) / 2.0
    return math.sqrt(max(np.nanvar(values) - noise, 0.0))


def fronts(rest: np.ndarray, along: np.ndarray) -> tuple[float, float]:
    """The across-lake bands of what is left: the share of its variance they carry, and the distance
    along the wind (metres) over which their correlation halves."""
    edges = np.arange(-LAKE_HALF_LENGTH_M, LAKE_HALF_LENGTH_M + 1.0, FRONT_STEP_M)
    profile = np.full(len(edges) - 1, np.nan)
    for i, start in enumerate(edges[:-1]):
        m = np.isfinite(rest) & (along >= start) & (along < start + FRONT_STEP_M)
        if m.sum() > 30:
            profile[i] = np.nanmean(rest[m])
    m = np.isfinite(rest)
    step = np.clip(((along[m] + LAKE_HALF_LENGTH_M) // FRONT_STEP_M).astype(int), 0, len(profile) - 1)
    share = float(np.nanvar(profile[step]) / np.nanvar(rest[m]))
    p = profile[np.isfinite(profile)] - np.nanmean(profile)
    correlation = np.correlate(p, p, "full")[len(p) - 1:]
    correlation /= correlation[0]
    half = next((i for i, c in enumerate(correlation) if c < 0.5), len(correlation)) * FRONT_STEP_M
    return share, float(half)


def measure(rests: list[np.ndarray], along: np.ndarray) -> dict:
    """Everything this script measures, for a group of photos (or model moments): the oval of their
    average correlation, and the medians of the spread and of the two front numbers."""
    correlation = sum(autocorrelation(r) for r in rests) / len(rests)
    front_numbers = [fronts(r, along) for r in rests]
    return {**oval(correlation),
            "spread_pct": round(float(np.median([100 * spread(r) for r in rests])), 1),
            "front_share_pct": round(float(np.median([100 * f[0] for f in front_numbers]))),
            "front_half_m": round(float(np.median([f[1] for f in front_numbers])))}


def describe(label: str, numbers: dict) -> str:
    return (f"{label:24s} oval {numbers['length_m']:4d} x {numbers['width_m']:3d} m, axis {numbers['axis_deg']:5.1f}; "
            f"spread {numbers['spread_pct']:4.1f} %; across-lake bands carry {numbers['front_share_pct']:3d} %, "
            f"their correlation halves at {numbers['front_half_m']:4d} m")


def across_wind(axis_deg: float) -> bool:
    """Whether an oval's long axis lies closer to across the wind than along it."""
    difference = abs((axis_deg - WIND_TO_DEG + 90.0) % 180.0 - 90.0)
    return difference > 45.0


def font(size: int) -> ImageFont.ImageFont:
    for name in ("segoeui.ttf", "DejaVuSans.ttf", "arial.ttf"):
        try:
            return ImageFont.truetype(name, size)
        except OSError:
            continue
    return ImageFont.load_default()


def picture(leftovers: dict[str, np.ndarray], ovals: dict[str, dict], water: np.ndarray, path,
            title: str = "Gusts seen from space: the water's roughness left after the lake's fixed pattern",
            note: str = "Contains modified Copernicus Sentinel data.") -> None:
    """Four photos (or model moments) side by side: what is left after the fixed pattern,
    bright = rougher = windier. leftovers and ovals are keyed by the panel's name (a date)."""
    rows, cols = np.where(water)
    box = (rows.min(), rows.max() + 1, cols.min(), cols.max() + 1)
    scale = 2
    panels = []
    for day in list(leftovers)[:4]:
        values = leftovers[day][box[0]:box[1], box[2]:box[3]]
        grey = np.clip((np.nan_to_num(values, nan=0.0) + 0.15) / 0.3, 0.0, 1.0) * 255.0
        rgb = np.stack([grey] * 3, axis=-1).astype(np.uint8)
        rgb[~water[box[0]:box[1], box[2]:box[3]]] = (225, 228, 222)
        image = Image.fromarray(rgb).resize((rgb.shape[1] * scale, rgb.shape[0] * scale), Image.NEAREST)
        canvas = Image.new("RGB", (image.width, image.height + 46), (255, 255, 255))
        canvas.paste(image, (0, 46))
        draw = ImageDraw.Draw(canvas)
        o = ovals[day]
        kind = "fronts across the wind" if across_wind(o["axis_deg"]) else "lanes along the wind"
        draw.text((4, 2), f"{day[:4]}-{day[4:6]}-{day[6:]}" if day.isdigit() else day, fill=(20, 20, 20), font=font(18))
        draw.text((4, 24), f"{kind}: {o['length_m']} x {o['width_m']} m", fill=(70, 70, 70), font=font(14))
        # 500 m scale bar and the wind's direction
        bar = 500 / sw.GRID_CELL * scale
        draw.line((10, canvas.height - 14, 10 + bar, canvas.height - 14), fill=(20, 20, 20), width=3)
        draw.text((14 + bar, canvas.height - 24), "500 m", fill=(20, 20, 20), font=font(14))
        panels.append(canvas)
    gap = 12
    sheet = Image.new("RGB", (sum(p.width for p in panels) + gap * (len(panels) - 1), panels[0].height + 70), (255, 255, 255))
    draw = ImageDraw.Draw(sheet)
    draw.text((4, 4), title, fill=(20, 20, 20), font=font(20))
    draw.text((4, 32), "Bright: rougher, more wind. Dark: smoother, less wind. North is up; the Maloja blows from bottom left to top right. "
              + note, fill=(90, 90, 90), font=font(14))
    x = 0
    for p in panels:
        sheet.paste(p, (x, 62))
        x += p.width + gap
    path.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(path)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("--model", type=Path, help="also measure the model's gusts written to this folder by export_gusts.gd")
    options = parser.parse_args()
    scenes = json.loads((sw.OUT_DIR / "scenes.json").read_text())
    photos = [s for s in scenes if s.get("kind") == "maloja" and s.get("quality", {}).get("clean")]
    xs, ys = sw.grid_in_utm()
    lake = sw.lake_mask()
    east, north = sw.grid_lv95()
    water = sw.shrink(lake, SHORE_CELLS) & (north < NARROWS_NORTH_M)
    pattern = np.load(sw.OUT_DIR / "roughness.npz")["pattern_red"]
    relative = [sw.relative_brightness(sw.OUT_DIR / f"{s['id']}.npz", xs, ys, lake, sw.BAND, s["offset"]) for s in photos]
    maloja_mean = np.nanmean(np.array(relative), axis=0)

    per_photo = []
    leftovers: dict[str, np.ndarray] = {}
    ovals: dict[str, dict] = {}
    together = np.zeros((2 * MAX_LAG_CELLS + 1, 2 * MAX_LAG_CELLS + 1))
    print(f"{len(photos)} Maloja photos; the oval where the correlation is above {OVAL_LEVEL}:")
    for s, photo in zip(photos, relative):
        day = s["id"].split("_")[2]
        rest = leftover(photo, maloja_mean, pattern, water, east, north)
        correlation = autocorrelation(rest)
        together += correlation / len(photos)
        o = oval(correlation)
        row = {"day": day, "station_kt": round(s["station"]["mean"] / 0.514444, 1), **o,
               "spread_pct": round(100 * spread(rest), 1)}
        per_photo.append(row)
        leftovers[day] = rest
        ovals[day] = o
        print(f"  {day}  {row['station_kt']:4.1f} kt  axis {o['axis_deg']:5.1f}  {o['length_m']:3d} x {o['width_m']:3d} m "
              f"(ratio {o['ratio']:.2f}, {'ACROSS' if across_wind(o['axis_deg']) else 'along '} the wind)  spread {row['spread_pct']:4.1f} %")
    overall = oval(together)
    spreads = np.array([r["spread_pct"] for r in per_photo])
    across = sum(across_wind(r["axis_deg"]) for r in per_photo)
    summary = {
        "photos": len(photos),
        "all_together": overall,
        "photos_along_the_wind": len(photos) - across,
        "photos_across_the_wind": across,
        "spread_pct_median": float(np.median(spreads)),
        "spread_pct_middle_half": [float(np.percentile(spreads, 25)), float(np.percentile(spreads, 75))],
        "per_photo": per_photo,
    }
    print(f"All photos together: axis {overall['axis_deg']} degrees (the wind moves to {WIND_TO_DEG:.0f}), "
          f"{overall['length_m']} x {overall['width_m']} m (ratio {overall['ratio']}).")
    print(f"Long axis along the wind on {len(photos) - across} photos, across it on {across}.")
    print(f"Spread of the water's roughness at one moment: median {summary['spread_pct_median']:.1f} %, "
          f"middle half {summary['spread_pct_middle_half'][0]:.1f} to {summary['spread_pct_middle_half'][1]:.1f} %.")
    to = math.radians(WIND_TO_DEG)
    along = (east - 2_780_500.0) * math.sin(to) + (north - 1_146_600.0) * math.cos(to)
    front_days = [d for d in leftovers if across_wind(ovals[d]["axis_deg"])]
    groups = {"all photos": list(leftovers),
              "lane days": [d for d in leftovers if d not in front_days],
              "front days": front_days}
    summary["groups"] = {}
    print("Per group (medians):")
    for name, days in groups.items():
        summary["groups"][name] = {"days": days, **measure([leftovers[d] for d in days], along)}
        print("  " + describe(f"photos, {name} ({len(days)})", summary["groups"][name]))

    if options.model:
        summary["model"] = {}
        rows, cols = water.shape
        noise = np.random.default_rng(1)
        for path in sorted(options.model.glob("model_*.bin")):
            fields = np.fromfile(path, dtype="<f4").reshape(-1, rows, cols).astype(float)
            # The model's moments with the photos' sensor noise, through the same steps (no average
            # photo to divide by: the model's gusts are already what is left over the fixed pattern).
            rests = [leftover(1.0 + f + noise.normal(0.0, MODEL_NOISE, f.shape), np.ones_like(f), pattern, water, east, north)
                     for f in fields]
            name = path.stem.removeprefix("model_")
            summary["model"][name] = measure(rests, along)
            print("  " + describe(f"model, {name} ({len(fields)})", summary["model"][name]))
            if name == "both":
                # Four moments 15 minutes apart, drawn like the photos.
                shown = {f"model, 12:28 {'+' if k >= 0 else '-'} {abs(k) * 15} min": rests[len(rests) // 2 + 3 * k] for k in (-1, 0, 1, 2)}
                picture(shown, {k: oval(autocorrelation(v)) for k, v in shown.items()}, water, OUT_MODEL_PICTURE,
                        "The model's gusts, through the same steps as the photos (with the photos' sensor noise)",
                        "Made by tools/map/gust_shapes.py --model.")
                print(f"  Wrote {OUT_MODEL_PICTURE}")

    OUT_JSON.write_text(json.dumps(summary, indent=1))
    picture({d: leftovers[d] for d in EXAMPLES}, ovals, water, OUT_PICTURE)
    print(f"Wrote {OUT_JSON} and {OUT_PICTURE}")


if __name__ == "__main__":
    main()
