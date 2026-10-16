"""Charts for Documentation/MALOJA_WIND_RESEARCH.md, drawn from maloja_research.py's results.

Run from the repo root after maloja_research.py:

    python tools/map/maloja_charts.py

Writes PNG pictures to Documentation/images/maloja/, each in a light and a dark version
(<name>.png and <name>_dark.png); the document shows the one that fits the reader's theme.
The numbers behind every chart are also in the tables of the document.
"""
import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

import silvaplana_area as area

RESULTS = area.WORK_DIR / "wind_research" / "results.json"
OUT_DIR = area.REPO_ROOT / "Documentation" / "images" / "maloja"

SCALE = 2  # drawn at twice the size, so the pictures stay sharp on high-resolution screens
WIDTH, HEIGHT = 720, 380
LEFT, RIGHT, TOP, BOTTOM = 56, 160, 96, 48  # plot margins; the right margin holds end labels

# Colours by role (reference data-viz palette: categorical slots 1 to 4, light and dark steps).
THEMES = {
    "light": {"surface": "#fcfcfb", "title": "#0b0b0b", "text": "#52514e", "grid": "#e4e3df", "leader": "#a3a29c",
              "series": ["#2a78d6", "#eb6834", "#1baf7a", "#eda100"], "wash": (42, 120, 214, 30)},
    "dark": {"surface": "#1a1a19", "title": "#f0efec", "text": "#c3c2b7", "grid": "#3a3a37", "leader": "#6d6c66",
             "series": ["#3987e5", "#d95926", "#199e70", "#c98500"], "wash": (57, 135, 229, 40)},
}


def font(size: int, bold: bool = False) -> ImageFont.FreeTypeFont:
    """Segoe UI on Windows, DejaVu Sans on Linux, Pillow's own font as a last resort."""
    names = (["segoeuib.ttf", "DejaVuSans-Bold.ttf"] if bold else ["segoeui.ttf", "DejaVuSans.ttf"])
    folders = [Path("C:/Windows/Fonts"), Path("/usr/share/fonts/truetype/dejavu"), Path("/usr/share/fonts/TTF")]
    for folder in folders:
        for name in names:
            if (folder / name).exists():
                return ImageFont.truetype(str(folder / name), size * SCALE)
    return ImageFont.load_default(size * SCALE)


class Chart:
    """One chart with a linear x and y axis, drawn in both themes at once."""

    def __init__(self, title: str, subtitle: str, x_range: tuple[float, float], y_range: tuple[float, float]) -> None:
        self.x0, self.x1 = x_range
        self.y0, self.y1 = y_range
        self.title, self.subtitle = title, subtitle
        self.steps: list = []  # drawing steps, replayed for each theme

    def x(self, value: float) -> float:
        return LEFT + (value - self.x0) / (self.x1 - self.x0) * (WIDTH - LEFT - RIGHT)

    def y(self, value: float) -> float:
        return HEIGHT - BOTTOM - (value - self.y0) / (self.y1 - self.y0) * (HEIGHT - TOP - BOTTOM)

    # Each method below records what to draw; save() draws it.
    def axes(self, x_ticks: list[tuple[float, str]], y_ticks: list[float], y_unit: str, x_title: str) -> None:
        for value in y_ticks:
            self.steps.append(("line", "grid", [(LEFT, self.y(value)), (WIDTH - RIGHT, self.y(value))], 1))
            self.steps.append(("text", "text", (LEFT - 8, self.y(value)), f"{value:g}", "rm", 11))
        self.steps.append(("text", "text", (LEFT - 8, TOP - 16), y_unit, "rm", 11))
        for value, text in x_ticks:
            self.steps.append(("text", "text", (self.x(value), HEIGHT - BOTTOM + 14), text, "mm", 11))
        self.steps.append(("text", "text", ((LEFT + WIDTH - RIGHT) / 2, HEIGHT - 12), x_title, "mm", 11))

    def legend(self, entries: list[tuple[int, str]]) -> None:
        x = LEFT
        for series, text in entries:
            self.steps.append(("line", series, [(x, 66), (x + 16, 66)], 2))
            self.steps.append(("text", "text", (x + 22, 66), text, "lm", 12))
            x += 34 + 6.6 * len(text)

    def line(self, series: int, points: list[tuple[float, float]], dots: bool = False) -> None:
        xy = [(self.x(px), self.y(py)) for px, py in points]
        if len(xy) > 1:
            self.steps.append(("line", series, xy, 2))
        if dots:
            for p in xy:
                self.steps.append(("dot", series, p))

    def band(self, lower: list[tuple[float, float]], upper: list[tuple[float, float]]) -> None:
        points = upper + list(reversed(lower))
        self.steps.append(("wash", [(self.x(px), self.y(py)) for px, py in points]))

    def end_labels(self, entries: list[tuple[float, str]], at_x: float) -> None:
        """Labels to the right of the plot, spread apart, with a thin leader to each line's end."""
        placed: list[float] = []
        for value, text in sorted(entries, key=lambda e: -e[0]):
            want = self.y(value)
            y = max(want, placed[-1] + 16) if placed else want
            placed.append(y)
            self.steps.append(("line", "leader", [(self.x(at_x) + 4, want), (WIDTH - RIGHT + 10, y)], 1))
            self.steps.append(("text", "text", (WIDTH - RIGHT + 14, y), text, "lm", 12))

    def label(self, x: float, y: float, text: str, anchor: str = "lm") -> None:
        self.steps.append(("text", "text", (self.x(x), self.y(y)), text, anchor, 12))

    def hline(self, value: float, text: str) -> None:
        self.steps.append(("line", "leader", [(LEFT, self.y(value)), (WIDTH - RIGHT, self.y(value))], 1))
        self.steps.append(("text", "text", (WIDTH - RIGHT + 6, self.y(value)), text, "lm", 12))

    def save(self, name: str) -> None:
        OUT_DIR.mkdir(parents=True, exist_ok=True)
        for theme_name, theme in THEMES.items():
            image = Image.new("RGBA", (WIDTH * SCALE, HEIGHT * SCALE), theme["surface"])
            wash = Image.new("RGBA", image.size, (0, 0, 0, 0))
            draw = ImageDraw.Draw(image)
            draw.text((LEFT * SCALE, 14 * SCALE), self.title, fill=theme["title"], font=font(15, bold=True))
            draw.text((LEFT * SCALE, 36 * SCALE), self.subtitle, fill=theme["text"], font=font(12))
            for step in self.steps:
                kind = step[0]
                if kind == "wash":
                    ImageDraw.Draw(wash).polygon([(px * SCALE, py * SCALE) for px, py in step[1]], fill=theme["wash"])
                    image.alpha_composite(wash)
                    wash = Image.new("RGBA", image.size, (0, 0, 0, 0))
                elif kind == "line":
                    colour = theme["series"][step[1]] if isinstance(step[1], int) else theme[step[1]]
                    draw.line([(px * SCALE, py * SCALE) for px, py in step[2]], fill=colour,
                              width=step[3] * SCALE, joint="curve")
                elif kind == "dot":
                    cx, cy = step[2][0] * SCALE, step[2][1] * SCALE
                    ring, r = 6 * SCALE, 4 * SCALE  # a 2 px ring in the surface colour around the dot
                    draw.ellipse((cx - ring, cy - ring, cx + ring, cy + ring), fill=theme["surface"])
                    draw.ellipse((cx - r, cy - r, cx + r, cy + r), fill=theme["series"][step[1]])
                elif kind == "text":
                    (tx, ty), text, anchor, size = step[2], step[3], step[4], step[5]
                    draw.text((tx * SCALE, ty * SCALE), text, fill=theme[step[1]], font=font(size), anchor=anchor)
            suffix = "" if theme_name == "light" else "_dark"
            image.convert("RGB").save(OUT_DIR / f"{name}{suffix}.png", optimize=True)
        print(f"wrote {OUT_DIR / name}.png and {name}_dark.png")


def daily_cycle(results: dict) -> None:
    stations = results["stations"]
    hours = [c["hour"] for c in stations["sia"]["daily_cycle"]]
    chart = Chart("The Maloja's day", f"Median of {results['maloja_days']} Maloja days, {results['years'][0]} "
                  f"to {results['years'][1]}. Shaded: the middle half of the days at Segl-Maria.",
                  (hours[0], hours[-1]), (0, 22))
    chart.axes([(h, f"{h:02d}:00") for h in range(6, 24, 2)], [0, 5, 10, 15, 20], "kt", "local time (summer)")
    sia = stations["sia"]["daily_cycle"]
    chart.band([(c["hour"], c["mean_p25_kt"]) for c in sia], [(c["hour"], c["mean_p75_kt"]) for c in sia])
    series = [(0, "sia", "mean_kt", "Segl-Maria, mean"), (1, "sia", "gust1_kt", "Segl-Maria, gusts"),
              (2, "sam", "mean_kt", "Samedan, mean"), (3, "vio", "mean_kt", "Vicosoprano, mean")]
    for number, station, key, _ in series:
        chart.line(number, [(c["hour"], c[key]) for c in stations[station]["daily_cycle"]])
    chart.legend([(number, text) for number, _, _, text in series])
    chart.end_labels([(stations[st]["daily_cycle"][-1][key], text) for _, st, key, text in series], hours[-1])
    chart.save("daily_cycle")


def gusts(results: dict) -> None:
    classes = results["gusts_sia"]["by_speed"]
    chart = Chart("How much stronger the gusts are", "Strongest 1-second gust minus the 10-minute mean, Segl-Maria. "
                  "Dot: median. Line: 8 in 10 periods.", (-0.5, len(classes) - 0.5), (0, 12))
    chart.axes([(k, f"{c['from_kt']}-{c['to_kt']}") for k, c in enumerate(classes)], [0, 3, 6, 9, 12], "kt",
               "10-minute mean (kt)")
    for k, c in enumerate(classes):
        p10, p50, p90 = c["gust1_excess_kt"]
        chart.line(0, [(k, p10), (k, p90)])
        chart.line(0, [(k, p50)], dots=True)
        chart.label(k + 0.1, p50, f"+{p50:.1f}")
    chart.save("gusts")


def persistence(results: dict) -> None:
    direction = results["direction_sia"]["autocorrelation_per_10min"]
    speed = results["speed_sia"]["autocorrelation_per_10min"]
    minutes = [0] + [10 * (k + 1) for k in range(len(direction))]
    chart = Chart("How long a shift or a pulse lasts", "How much of a 10-minute shift (direction) or pulse (speed) "
                  "is still there later. Segl-Maria, Maloja afternoons.", (0, minutes[-1]), (-0.2, 1.0))
    chart.axes([(m, str(m)) for m in minutes], [-0.2, 0, 0.2, 0.4, 0.6, 0.8, 1.0], "share", "minutes later")
    chart.line(0, list(zip(minutes, [1.0] + direction)), dots=True)
    chart.line(1, list(zip(minutes, [1.0] + speed)), dots=True)
    chart.legend([(0, "direction shift"), (1, "speed pulse")])
    chart.label(26, 0.62, "half gone after about 20 minutes")
    chart.save("persistence")


def direction_by_hour(results: dict) -> None:
    cycle = [c for c in results["stations"]["sia"]["daily_cycle"] if 10 <= c["hour"] <= 21]
    chart = Chart("Where the Maloja comes from, through the day", "Segl-Maria, median of the Maloja days, "
                  "10-minute means from the Maloja sector.", (10, 21), (215, 255))
    chart.axes([(h, f"{h:02d}:00") for h in range(10, 22)], [215, 225, 235, 245, 255], "deg", "local time (summer)")
    chart.hline(224, "lake axis 224°")
    chart.line(0, [(c["hour"], c["dir_deg"]) for c in cycle], dots=True)
    chart.save("direction_by_hour")


def main() -> None:
    results = json.loads(RESULTS.read_text())
    daily_cycle(results)
    gusts(results)
    persistence(results)
    direction_by_hour(results)


if __name__ == "__main__":
    main()
