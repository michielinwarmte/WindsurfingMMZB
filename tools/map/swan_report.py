"""The tables and maps of SWAN on Lake Silvaplana (tools/map/swan_silvaplana.py report; the report
Documentation/reports/waves/swan_silvaplana.md).

Without SWAN's results it draws what the game's own data says: the game's Hs on the lake and where the
bottom can touch the waves (deeper than half the local peak wavelength is deep water). With them it
adds, for every case run: the line down the lake's middle (the points of lake_waves_full.md's tables)
with the game's model, the SPM and CEM laws and SWAN side by side, and the maps of SWAN's Hs, SWAN
against the game and the bottom's effect (the real bottom against the same lake 50 m deep).
Everything goes to .map_data/work/swan/report/ (tables.md and the PNGs).
"""

import math
from pathlib import Path

import numpy as np

from swan_silvaplana import KTS, KNOT_MS, REPORT, RUNS, G, bilinear, cem, parse_case, spm

SCALE = 3  # pixels per 10 m cell
SURFACE = (252, 252, 251)
LAND = (231, 229, 223)
INK = (11, 11, 11)
INK_2 = (82, 81, 78)
# The sequential blue ramp (dataviz reference palette, steps 100 to 700).
BLUES = ["#cde2fb", "#b7d3f6", "#9ec5f4", "#86b6ef", "#6da7ec", "#5598e7", "#3987e5", "#2a78d6", "#256abf", "#1c5cab", "#184f95", "#104281", "#0d366b"]
# The diverging pair blue <-> red with a gray middle.
DIVERGING = ["#184f95", "#3987e5", "#86b6ef", "#f0efec", "#f3a5a5", "#e66767", "#c33a3a"]
ORANGE = (235, 104, 52)


def _rgb(hex_colour: str) -> tuple:
    return tuple(int(hex_colour[i:i + 2], 16) for i in (1, 3, 5))


def _ramp(values: np.ndarray, low: float, high: float, colours: list) -> np.ndarray:
    stops = np.array([_rgb(c) for c in colours], dtype=float)
    t = np.clip((values - low) / (high - low), 0.0, 1.0) * (len(colours) - 1)
    i = np.minimum(t.astype(int), len(colours) - 2)
    f = (t - i)[..., None]
    return stops[i] * (1 - f) + stops[i + 1] * f


def _font(size: int):
    from PIL import ImageFont
    for name in ["segoeui.ttf", "arial.ttf"]:
        try:
            return ImageFont.truetype(f"C:/Windows/Fonts/{name}", size)
        except OSError:
            continue
    return ImageFont.load_default()


def lake_map(path: Path, meta: dict, values: np.ndarray, water: np.ndarray, colours: list, low: float, high: float,
             title: str, unit_label, ticks: list, marks: list, overlay: np.ndarray = None, overlay_label: str = "") -> None:
    """A map of the lake, north up, one value per 10 m cell, with a colour scale and the marks
    (game x, y of points with labels)."""
    from PIL import Image, ImageDraw
    rows, columns = values.shape
    # Crop to the water with a margin.
    wet_rows = np.where(water.any(axis=1))[0]
    wet_cols = np.where(water.any(axis=0))[0]
    r0, r1 = max(wet_rows[0] - 5, 0), min(wet_rows[-1] + 6, rows)
    c0, c1 = max(wet_cols[0] - 5, 0), min(wet_cols[-1] + 6, columns)
    v, wmask = values[r0:r1, c0:c1], water[r0:r1, c0:c1]
    rgb = _ramp(v, low, high, colours)
    rgb[~wmask] = LAND
    if overlay is not None:
        o = overlay[r0:r1, c0:c1] & wmask
        rgb[o] = np.array(ORANGE, dtype=float)
    picture = Image.fromarray(np.flipud(rgb).astype(np.uint8)).resize(((c1 - c0) * SCALE, (r1 - r0) * SCALE), Image.NEAREST)
    margin_top, legend_w = 110, 330
    image = Image.new("RGB", (picture.width + legend_w + 40, picture.height + margin_top + 60), SURFACE)
    image.paste(picture, (20, margin_top))
    draw = ImageDraw.Draw(image)
    big, mid, small = _font(30), _font(24), _font(20)
    draw.text((20, 20), title, fill=INK, font=big)

    def to_px(x: float, y: float) -> tuple:
        col = (x - meta["x0_m"]) / meta["cell_m"] - c0
        row = (y - meta["y0_m"]) / meta["cell_m"] - r0
        return 20 + (col + 0.5) * SCALE, margin_top + ((r1 - r0) - row - 0.5) * SCALE

    for x, y, label in marks:
        px, py = to_px(x, y)
        draw.ellipse([px - 7, py - 7, px + 7, py + 7], outline=INK, width=3, fill=SURFACE)
        if label:
            draw.text((px + 12, py), label, fill=INK, font=small, anchor="lm")
    # The colour scale.
    lx, ly, lh = picture.width + 60, margin_top + 40, 400
    for i in range(lh):
        value = high - (high - low) * i / lh
        draw.line([(lx, ly + i), (lx + 30, ly + i)], fill=tuple(int(c) for c in _ramp(np.array([value]), low, high, colours)[0]))
    for tick in ticks:
        ty = ly + (high - tick) / (high - low) * lh
        draw.line([(lx + 30, ty), (lx + 38, ty)], fill=INK_2, width=2)
        draw.text((lx + 44, ty), unit_label(tick), fill=INK_2, font=small, anchor="lm")
    if overlay is not None:
        oy = ly + lh + 40
        draw.rectangle([lx, oy, lx + 30, oy + 22], fill=ORANGE)
        for j, line in enumerate(overlay_label.split("\n")):
            draw.text((lx + 44, oy + 11 + j * 26), line, fill=INK, font=small, anchor="lm")
    # North arrow and a 500 m scale bar.
    nx, ny = lx + 15, image.height - 160
    draw.polygon([(nx, ny - 30), (nx - 10, ny), (nx + 10, ny)], fill=INK)
    draw.text((nx, ny + 6), "N", fill=INK, font=mid, anchor="mt")
    bar = 500.0 / meta["cell_m"] * SCALE
    draw.line([(lx, image.height - 70), (lx + bar, image.height - 70)], fill=INK, width=4)
    draw.text((lx, image.height - 60), "500 m", fill=INK_2, font=small)
    image.save(path)


def game_maps(lake: dict) -> list:
    """The game's own Hs and where the bottom can touch the waves, with no SWAN."""
    meta = lake["meta"]
    depth = lake["depth"]
    water = depth > 0.05
    start = (meta["start_xy"][0], meta["start_xy"][1], "start")
    lines = []
    for kt in [18, 24]:
        hs = lake[f"game_hs_{kt}"]
        tp = lake[f"game_tp_{kt}"]
        wavelength = G * tp ** 2 / (2 * math.pi)
        touches = water & (depth < 0.5 * wavelength) & (hs > 0)
        share = touches.sum() / water.sum()
        middle = [(p["x"], p["y"], f"{p['distance_m'] / 1000:.1f} km" if p["distance_m"] in (600.0, 1000.0, 1500.0, 2000.0) else "")
                  for p in meta["lines"][f"middle_{kt}"] if p["distance_m"] in (100.0, 300.0, 600.0, 1000.0, 1500.0, 2000.0)]
        name = f"game_hs_{kt}kt.png"
        lake_map(REPORT / name, meta, hs, water, BLUES, 0.0, 0.32,
                 f"The game's Hs, {kt} kt at 10 m from {meta['from_deg']:.0f} deg (the map's wind along the fetch)",
                 lambda t: f"{t * 100:.0f} cm", [0.0, 0.05, 0.10, 0.15, 0.20, 0.25, 0.30], [start] + middle,
                 overlay=touches, overlay_label="water shallower than half\nthe local peak wavelength:\nthe bottom touches the waves")
        lines.append(f"- {name}: the bottom can touch the peak waves (depth < half the peak wavelength of the game's model at {kt} kt) on {share * 100:.1f} % of the lake's 10 m cells.")
    shallow = {d: float(((depth > 0.05) & (depth < d)).sum() / water.sum()) for d in [0.5, 1.0, 2.0, 3.5]}
    lines.append("- The lake's cells shallower than 0.5 / 1 / 2 / 3.5 m: " + " / ".join(f"{shallow[d] * 100:.1f} %" for d in shallow) + ".")
    return lines


# ------------------------------------------------------------------ with SWAN's results

def swan_field(name: str, field: str, shape: tuple) -> np.ndarray:
    values = np.loadtxt(RUNS / name / f"{field.lower()}.txt")
    return values.reshape(shape)


def check_orientation(lake: dict, name: str) -> None:
    """SWAN's depth output must lie on the input depth (the same rows from the south)."""
    depth = lake["depth"]
    out = swan_field(name, "DEPTH", depth.shape)
    wet = (depth > 1.0) & (out > 0)
    error = np.abs(out[wet] - depth[wet]).mean()
    flipped = np.abs(np.flipud(out)[wet] - depth[wet]).mean() if wet.any() else 0
    if not wet.any() or error > 0.5:
        raise SystemExit(f"{name}: SWAN's depth does not lie on the input (mean difference {error:.2f} m, flipped {flipped:.2f} m): check the layout")


def swan_tables(lake: dict, names: list) -> list:
    meta = lake["meta"]
    shape = lake["depth"].shape
    done = [n for n in names if (RUNS / n / "hsign.txt").exists()]
    if not done:
        return ["(SWAN has not been run yet.)"]
    check_orientation(lake, done[0])
    out = []
    for kt in KTS:
        wind_ms = kt * KNOT_MS
        cases = {n: parse_case(n) for n in done if parse_case(n)["kt"] == kt}
        fields = {n: (swan_field(n, "HSIGN", shape), swan_field(n, "TPS", shape)) for n in cases}
        out.append(f"\n**{kt} kt** (10 m, from {meta['from_deg']:.0f} deg): Hs (m) / Tp (s)\n")
        header = ["From the upwind shore", "9-ray fetch", "Depth", "Game (map wind)", "SPM law (one wind)", "CEM law (one wind)"] + [n.replace(f"{kt}_", " ") for n in cases]
        out.append("| " + " | ".join(header) + " |")
        out.append("|" + "---|" * len(header))
        for p in meta["lines"][f"middle_{kt}"]:
            s, c = spm(wind_ms, p["fetch_m"]), cem(wind_ms, p["fetch_m"])
            cells = [f"{p['distance_m']:.0f} m", f"{p['fetch_m']:.0f} m", f"{p['depth_m']:.0f} m", f"{p['game_hs_m']:.3f} / {p['game_tp_s']:.2f}",
                     f"{s[0]:.3f} / {s[1]:.2f}", f"{c[0]:.3f} / {c[1]:.2f}"]
            for n in cases:
                hs, tp = fields[n]
                cells.append(f"{bilinear(hs, meta, p['x'], p['y']):.3f} / {bilinear(tp, meta, p['x'], p['y']):.2f}")
            out.append("| " + " | ".join(cells) + " |")
    return out


def swan_maps(lake: dict, names: list) -> list:
    meta = lake["meta"]
    shape = lake["depth"].shape
    depth = lake["depth"]
    water = depth > 0.05
    notes = []
    start = (meta["start_xy"][0], meta["start_xy"][1], "start")
    for kt in KTS:
        real, deep, mapped = f"u{kt}_westh_real", f"u{kt}_westh_deep", f"map{kt}_westh_real"
        if (RUNS / mapped / "hsign.txt").exists():
            hs = swan_field(mapped, "HSIGN", shape)
            ok = water & (hs > 0)
            lake_map(REPORT / f"swan_hs_{kt}kt.png", meta, np.where(ok, hs, 0), water, BLUES, 0.0, 0.32,
                     f"SWAN's Hs, {kt} kt at 10 m, the map's wind", lambda t: f"{t * 100:.0f} cm", [0.0, 0.05, 0.10, 0.15, 0.20, 0.25, 0.30], [start])
            game = lake[f"game_hs_{kt}"]
            both = ok & (game > 0.02)
            ratio = np.where(both, hs / np.maximum(game, 1e-6), 1.0)
            lake_map(REPORT / f"swan_vs_game_{kt}kt.png", meta, ratio, water, DIVERGING, 0.5, 1.5,
                     f"SWAN's Hs over the game's, {kt} kt (the map's wind)", lambda t: f"x {t:.2f}", [0.5, 0.75, 1.0, 1.25, 1.5], [start])
            inner = both & (depth > 2.0)
            notes.append(f"- {kt} kt, the map's wind: SWAN's Hs / the game's over the lake deeper than 2 m (where the game has over 2 cm): "
                         f"median {np.median(ratio[inner]):.2f}, 10-90 % {np.percentile(ratio[inner], 10):.2f}-{np.percentile(ratio[inner], 90):.2f}.")
        if (RUNS / real / "hsign.txt").exists() and (RUNS / deep / "hsign.txt").exists():
            hr, hd = swan_field(real, "HSIGN", shape), swan_field(deep, "HSIGN", shape)
            ok = water & (hd > 0.01)
            effect = np.where(ok, hr / np.maximum(hd, 1e-6), 1.0)
            lake_map(REPORT / f"bottom_effect_{kt}kt.png", meta, effect, water, DIVERGING, 0.5, 1.5,
                     f"The bottom's effect on SWAN's Hs, {kt} kt (real bottom / 50 m deep)", lambda t: f"x {t:.2f}", [0.5, 0.75, 1.0, 1.25, 1.5], [start])
            for limit in [0.05, 0.10]:
                share = (ok & (np.abs(effect - 1) > limit)).sum() / ok.sum()
                notes.append(f"- {kt} kt: the bottom changes SWAN's Hs by more than {limit * 100:.0f} % on {share * 100:.1f} % of the lake.")
    return notes


def make(lake: dict, names: list) -> None:
    REPORT.mkdir(parents=True, exist_ok=True)
    lines = ["# SWAN on Lake Silvaplana: tables (tools/map/swan_report.py)", "", "## The game's own data", ""]
    lines += game_maps(lake)
    lines += ["", "## SWAN along the lake's middle", ""]
    lines += swan_tables(lake, names)
    lines += ["", "## SWAN on the whole lake", ""]
    lines += swan_maps(lake, names)
    text = "\n".join(lines) + "\n"
    (REPORT / "tables.md").write_text(text, encoding="utf-8")
    print(text)
