"""What the eye sees on the lake's water (PH44; the report
Documentation/reports/waves/swan_silvaplana.md, "What the eye sees").

The significant height Hs is a statistic: 4 times the standard deviation of the water's height
(Hm0). In a real wind sea the individual waves follow the Rayleigh distribution (Longuet-Higgins
1952): about one wave in a thousand is 1.86 x Hs, one in a hundred 1.5 x Hs. The game's lake is a
sum of four regular trains. This measures what that gives for the individual waves and compares it
with a real sea of the same spectrum.

Inputs: the game's surface recorded by Game/dev/lake_wave_record.gd (20 minutes, every 0.05 s, at
the start spot and four points down the lake's middle, at 12, 18 and 24 kt):
    tools/godot.sh --headless --path Game -s res://dev/lake_wave_record.gd -- --out=.map_data/work/wave_record
Then, from the repo root:
    python -I tools/map/wave_statistics.py [--record=.map_data/work/wave_record] [--out=.map_data/work/wave_stats]
It prints Markdown tables and writes two charts (PNG, Pillow).

The real sea: the same JONSWAP spectrum (the game model's Hs and Tp at the point, peak enhancement
3.3) as a sum of 1500 waves with random frequencies within their bands and random phases: a
Gaussian sea, linear (no second-order crest lift). 40 records of 20 minutes each, with different
seeds; the table gives the median and the 5 to 95 % range over the 40.
"""

import argparse
import json
import math
from pathlib import Path

import numpy as np

REPO = Path(__file__).resolve().parents[2]
G = 9.81
GAMMA = 3.3
REAL_RECORDS = 40
REAL_COMPONENTS = 1500


# ------------------------------------------------------------------ individual waves

def waves_of(heights: np.ndarray, step_s: float) -> dict:
    """Zero-down-crossing analysis: each wave runs from one down-crossing of the mean to the next
    (a trough, then a crest). Returns the waves' heights, crests and periods, and Hm0."""
    h = heights - heights.mean()
    hm0 = 4.0 * h.std()
    down = np.where((h[:-1] > 0.0) & (h[1:] <= 0.0))[0]
    times = (down + h[down] / (h[down] - h[down + 1])) * step_s
    wave_heights, crests, periods = [], [], []
    for a, b, ta, tb in zip(down[:-1], down[1:], times[:-1], times[1:]):
        piece = h[a + 1:b + 1]
        wave_heights.append(piece.max() - piece.min())
        crests.append(piece.max())
        periods.append(tb - ta)
    return {"hm0": hm0, "H": np.array(wave_heights), "crest": np.array(crests), "T": np.array(periods),
            "minutes": len(h) * step_s / 60.0}


def summary(w: dict) -> dict:
    H = np.sort(w["H"])[::-1]
    n = len(H)
    hm0 = w["hm0"]
    steep = w["H"] / (G * w["T"] ** 2 / (2 * math.pi))
    biggest = int(np.argmax(w["H"]))
    return {
        "hm0": hm0,
        "waves": n,
        "tz": float(w["T"].mean()),
        "h_mean": float(H.mean()) / hm0,
        "h13": float(H[: max(n // 3, 1)].mean()) / hm0,
        "h110": float(H[: max(n // 10, 1)].mean()) / hm0,
        "hmax": float(H[0]) / hm0,
        "crest_max": float(w["crest"].max()) / hm0,
        "over_12": int((H > 1.2 * hm0).sum()),
        "over_15": int((H > 1.5 * hm0).sum()),
        "steep_mean": float(steep.mean()),
        "steep_max": float(steep.max()),
        "steep_of_biggest": float(steep[biggest]),
    }


# ------------------------------------------------------------------ a real sea of the same spectrum

def jonswap_shape(f: np.ndarray, fp: float) -> np.ndarray:
    sigma = np.where(f <= fp, 0.07, 0.09)
    r = np.exp(-((f - fp) ** 2) / (2 * sigma ** 2 * fp ** 2))
    return f ** -5.0 * np.exp(-1.25 * (fp / f) ** 4) * GAMMA ** r


def real_sea(hs: float, tp: float, minutes: float, step_s: float, seed: int) -> np.ndarray:
    """A linear Gaussian sea at one point with the JONSWAP spectrum of this Hs and Tp."""
    rng = np.random.default_rng(seed)
    fp = 1.0 / tp
    edges = np.linspace(0.4 * fp, 8.0 * fp, REAL_COMPONENTS + 1)
    f = edges[:-1] + rng.random(REAL_COMPONENTS) * np.diff(edges)
    energy = jonswap_shape(f, fp) * np.diff(edges)
    energy *= (hs / 4.0) ** 2 / energy.sum()
    amplitude = np.sqrt(2.0 * energy)
    phase = rng.random(REAL_COMPONENTS) * 2 * math.pi
    t = np.arange(int(round(minutes * 60.0 / step_s))) * step_s
    h = np.zeros_like(t)
    for start in range(0, REAL_COMPONENTS, 100):
        part = slice(start, start + 100)
        h += (amplitude[part, None] * np.cos(2 * math.pi * f[part, None] * t[None, :] + phase[part, None])).sum(axis=0)
    return h


def real_summary(hs: float, tp: float, minutes: float, step_s: float) -> dict:
    runs = [summary(waves_of(real_sea(hs, tp, minutes, step_s, seed), step_s)) for seed in range(REAL_RECORDS)]
    out = {}
    for key in runs[0]:
        values = np.array([run[key] for run in runs], dtype=float)
        out[key] = (float(np.median(values)), float(np.percentile(values, 5)), float(np.percentile(values, 95)))
    return out


# ------------------------------------------------------------------ charts (Pillow)

SURFACE = (252, 252, 251)
INK = (11, 11, 11)
INK_2 = (82, 81, 78)
GRID = (226, 225, 220)
BLUE = (42, 120, 214)    # the game (categorical slot 1)
ORANGE = (235, 104, 52)  # the real sea (categorical slot 2)


def _font(size: int):
    from PIL import ImageFont
    for name in ["segoeui.ttf", "arial.ttf"]:
        try:
            return ImageFont.truetype(f"C:/Windows/Fonts/{name}", size)
        except OSError:
            continue
    return ImageFont.load_default()


def _dashed(draw, points, colour, width, dash=12, gap=8):
    """A dashed polyline: the dashes run on along the whole line, not per segment."""
    travelled = 0.0
    for (x0, y0), (x1, y1) in zip(points[:-1], points[1:]):
        length = math.hypot(x1 - x0, y1 - y0)
        for i in range(max(int(length), 1)):
            a, b = i / max(length, 1e-9), min((i + 1) / max(length, 1e-9), 1.0)
            if (travelled + i) % (dash + gap) < dash:
                draw.line([(x0 + (x1 - x0) * a, y0 + (y1 - y0) * a), (x0 + (x1 - x0) * b, y0 + (y1 - y0) * b)], fill=colour, width=width)
        travelled += length


def exceedance_chart(path: Path, game: dict, real_runs: list, title: str) -> None:
    """P(a wave is higher than h) against h / Hm0, log scale: the game, a real sea, Rayleigh."""
    from PIL import Image, ImageDraw
    w, h = 1400, 860
    left, right, top, bottom = 170, 380, 110, 120
    image = Image.new("RGB", (w, h), SURFACE)
    draw = ImageDraw.Draw(image)
    x_max, y_min = 2.2, 1e-3

    def px(x, p):
        X = left + x / x_max * (w - left - right)
        Y = top + (math.log10(p) / math.log10(y_min)) * (h - top - bottom)
        return X, Y

    small, mid, big = _font(24), _font(28), _font(36)
    draw.text((left, 30), title, fill=INK, font=big)
    for p in [1, 0.1, 0.01, 0.001]:
        X0, Y = px(0, p)
        X1, _ = px(x_max, p)
        draw.line([(X0, Y), (X1, Y)], fill=GRID, width=1)
        label = {1: "every wave", 0.1: "1 in 10", 0.01: "1 in 100", 0.001: "1 in 1000"}[p]
        draw.text((X0 - 12, Y), label, fill=INK_2, font=small, anchor="rm")
    for x in [0.0, 0.5, 1.0, 1.5, 2.0]:
        X, Y0 = px(x, 1)
        _, Y1 = px(x, y_min)
        draw.line([(X, Y0), (X, Y1)], fill=GRID, width=1)
        draw.text((X, Y1 + 12), f"{x:.1f}", fill=INK_2, font=small, anchor="mt")
    draw.text(((left + w - right) / 2, h - 50), "wave height / Hs  (Hs = 4 x the standard deviation of the surface)", fill=INK_2, font=mid, anchor="mm")

    xs = np.linspace(0.0, x_max, 200)
    rayleigh = [px(x, math.exp(-2 * x * x)) for x in xs if math.exp(-2 * x * x) >= y_min]
    _dashed(draw, rayleigh, INK_2, 2)

    def curve(values, hm0):
        H = np.sort(values / hm0)
        n = len(H)
        points = []
        for i, x in enumerate(H):
            p = (n - i) / n
            if p >= y_min and x <= x_max:
                points.append(px(x, p))
        return points

    real_pooled = np.concatenate([r["H"] / r["hm0"] for r in real_runs])
    draw.line(curve(real_pooled, 1.0), fill=ORANGE, width=3)
    draw.line(curve(game["H"], game["hm0"]), fill=BLUE, width=3)
    # Direct labels at the right end of each line, a legend box beside the plot.
    lx = w - right + 30
    entries = [(BLUE, "The game (this point, 20 min)", False), (ORANGE, "A real sea, same spectrum (40 x 20 min)", False), (INK_2, "Rayleigh (Longuet-Higgins 1952)", True)]
    for i, (colour, text, dashed) in enumerate(entries):
        y = top + 20 + i * 70
        if dashed:
            _dashed(draw, [(lx, y), (lx + 50, y)], colour, 3)
        else:
            draw.line([(lx, y), (lx + 50, y)], fill=colour, width=4)
        lines = text.split(", ") if len(text) > 26 else [text]
        for j, line in enumerate(_wrap(text, 26)):
            draw.text((lx + 62, y - 14 + j * 28), line, fill=INK, font=small)
    image.save(path)


def _wrap(text: str, width: int) -> list:
    words, lines, line = text.split(), [], ""
    for word in words:
        if len(line) + len(word) + 1 > width and line:
            lines.append(line)
            line = word
        else:
            line = f"{line} {word}".strip()
    lines.append(line)
    return lines


def surface_chart(path: Path, game_h: np.ndarray, real_h: np.ndarray, step_s: float, hs: float, title: str) -> None:
    """60 s of the surface at one point: the game above, a real sea of the same spectrum below."""
    from PIL import Image, ImageDraw
    w, h = 1400, 900
    left, right = 130, 40
    image = Image.new("RGB", (w, h), SURFACE)
    draw = ImageDraw.Draw(image)
    small, mid, big = _font(24), _font(28), _font(36)
    draw.text((left, 30), title, fill=INK, font=big)
    seconds = 60.0
    n = int(seconds / step_s)
    limit = max(np.abs(game_h[:n]).max(), np.abs(real_h[:n]).max()) * 1.1
    panels = [(game_h[:n], BLUE, "The game (the four trains the board floats on; the picture draws the same shape)"), (real_h[:n], ORANGE, "A real sea with the same spectrum (random phases)")]
    for k, (series, colour, label) in enumerate(panels):
        top = 120 + k * 380
        height = 300
        mid_y = top + height / 2
        draw.text((left, top - 40), label, fill=INK, font=mid)

        def py(v):
            return mid_y - v / limit * height / 2

        for v in [-hs / 2, 0.0, hs / 2]:
            draw.line([(left, py(v)), (w - right, py(v))], fill=GRID, width=1)
            draw.text((left - 12, py(v)), f"{v * 100:+.0f} cm" if v else "0", fill=INK_2, font=small, anchor="rm")
        points = [(left + i / n * (w - left - right), py(v)) for i, v in enumerate(series)]
        draw.line(points, fill=colour, width=2)
        if k == 1:
            for s in range(0, 61, 10):
                X = left + s / seconds * (w - left - right)
                draw.text((X, top + height + 12), f"{s} s", fill=INK_2, font=small, anchor="mt")
    draw.text((left, h - 40), f"Grid lines at plus and minus Hs / 2 = {hs * 50:.0f} cm (the height of a wave of exactly Hs, crest to trough)", fill=INK_2, font=small)
    image.save(path)


# ------------------------------------------------------------------ main

def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--record", default=str(REPO / ".map_data" / "work" / "wave_record"))
    parser.add_argument("--out", default=str(REPO / ".map_data" / "work" / "wave_stats"))
    args = parser.parse_args()
    record_dir, out = Path(args.record), Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    record = json.loads((record_dir / "record.json").read_text())
    step_s = record["step_s"]
    results = []
    print("| Wind | Point | Fetch | Model Hs / Tp | View | Surface Hm0 | Waves (Tz) | H1/3 | Highest wave | Highest crest | Waves over 1.2 / 1.5 Hs | Steepness: mean / max |")
    print("|---|---|---|---|---|---|---|---|---|---|---|---|")
    for wind in record["winds"]:
        for point in wind["points"]:
            for view, name in point["files"].items():
                heights = np.fromfile(record_dir / name, dtype="<f4").astype(np.float64)
                waves = waves_of(heights, step_s)
                s = summary(waves)
                results.append({"kt": wind["kt"], "point": point["name"], "view": view, "summary": s, "model_hs": point["model_hs_m"],
                                "model_tp": point["model_tp_s"], "fetch": point["fetch_m"], "amplitudes": point["amplitudes_m"]})
                print(f"| {wind['kt']:.0f} kt | {point['name']} | {point['fetch_m']:.0f} m | {point['model_hs_m']:.3f} m / {point['model_tp_s']:.2f} s | {view} | "
                      f"{s['hm0']:.3f} m | {s['waves']} ({s['tz']:.2f} s) | {s['h13']:.2f} Hs | {s['hmax']:.2f} Hs ({s['hmax'] * s['hm0']:.3f} m) | "
                      f"{s['crest_max']:.2f} Hs | {s['over_12']} / {s['over_15']} | {s['steep_mean']:.3f} / {s['steep_max']:.3f} |")
    print("\nA real sea of the same spectrum (the model's Hs and Tp at the point), median and 5-95 % over 40 records of 20 minutes:")
    print("| Wind | Point | Hs / Tp | Waves (Tz) | H1/3 | Highest wave | Highest crest | Waves over 1.2 / 1.5 Hs | Steepness: mean / max |")
    print("|---|---|---|---|---|---|---|---|---|")
    real = {}
    for r in results:
        if r["view"] != "lake" or r["point"] not in ("start", "middle_2000"):
            continue
        q = real_summary(r["model_hs"], r["model_tp"], record["samples"] * step_s / 60.0, step_s)
        real[(r["kt"], r["point"])] = q
        fmt = lambda key, d=2: f"{q[key][0]:.{d}f} ({q[key][1]:.{d}f}-{q[key][2]:.{d}f})"
        print(f"| {r['kt']:.0f} kt | {r['point']} | {r['model_hs']:.3f} m / {r['model_tp']:.2f} s | {q['waves'][0]:.0f} ({q['tz'][0]:.2f} s) | {fmt('h13')} Hs | "
              f"{fmt('hmax')} Hs | {fmt('crest_max')} Hs | {q['over_12'][0]:.0f} / {q['over_15'][0]:.0f} | {q['steep_mean'][0]:.3f} / {fmt('steep_max', 3)} |")
    (out / "results.json").write_text(json.dumps({"game": results, "real": {f"{k[0]:.0f}_{k[1]}": v for k, v in real.items()}}, indent=1))

    # The charts: the start spot at 18 kt.
    pick = next(r for r in results if r["kt"] == 18 and r["point"] == "start" and r["view"] == "lake")
    point = next(p for wind in record["winds"] if wind["kt"] == 18 for p in wind["points"] if p["name"] == "start")
    game_h = np.fromfile(record_dir / point["files"]["lake"], dtype="<f4").astype(np.float64)
    game_waves = waves_of(game_h, step_s)
    real_runs = [waves_of(real_sea(pick["model_hs"], pick["model_tp"], 20.0, step_s, seed), step_s) for seed in range(REAL_RECORDS)]
    exceedance_chart(out / "wave_heights_exceedance.png", game_waves, real_runs,
                     f"How often a wave is higher than h: the start spot, 18 kt (Hs {pick['model_hs'] * 100:.0f} cm)")
    real_h = real_sea(pick["model_hs"], pick["model_tp"], 1.0, step_s, 7)
    surface_chart(out / "surface_60s.png", game_h - game_h.mean(), real_h, step_s, pick["model_hs"],
                  f"One minute of water at the start spot, 18 kt (the model's Hs {pick['model_hs'] * 100:.0f} cm, Tp {pick['model_tp']:.2f} s)")
    print(f"\ncharts: {out / 'wave_heights_exceedance.png'}, {out / 'surface_60s.png'}")


if __name__ == "__main__":
    main()
