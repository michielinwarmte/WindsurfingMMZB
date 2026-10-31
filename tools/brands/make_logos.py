#!/usr/bin/env python3
"""Draws the logos of the game's twelve gear brands (Documentation/reports/fleet_gear/brands.md).

Every brand gets three drawings in Game/assets/brands/<slug>/:
  mark.svg      the symbol alone (the menu card, the fin, the board's tail)
  wordmark.svg  the name, wide, in the ink that reads on the brand's own cloth (the sail's panels,
                the board's deck)
  logo.svg      the mark above the wordmark on a rounded plate in the brand's main colour (square)
and a PNG of each, 1024 px on the long side with a transparent background (the game loads the PNGs).

The letters are drawn as outlines (paths), not as text: an SVG with text renders only in fonts the
machine has, so these files look the same on every computer, in Godot and in Blender. The outlines
come from free fonts (SIL Open Font License: Fira Sans, Open Sans, Noto Sans, Noto Serif Display),
which allows using their letters in artwork like this. The fonts must be installed only to run this
script, not to use its output.

Run from the repo root (it needs Python with pycairo and PyGObject's Pango, rsvg-convert and, for the
contact sheet, ImageMagick's magick):
    python -I tools/brands/make_logos.py              all twelve brands, then the contact sheet
    python -I tools/brands/make_logos.py savanna      only these (and the sheet)
The contact sheet, .screenshots/brands.png, shows per brand: the logo on the menu's dark blue, the
mark on white and on the menu's blue, the wordmark printed on the brand's cloth, and both small
(a menu card's icon, a sail seen from far away).
"""

import math
import os
import subprocess
import sys

import gi

gi.require_version("Pango", "1.0")
gi.require_version("PangoCairo", "1.0")
gi.require_foreign("cairo")
import cairo  # noqa: E402
from gi.repository import Pango, PangoCairo  # noqa: E402

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT_DIR = os.path.join(REPO, "Game", "assets", "brands")
PNG_LONG_SIDE_PX = 1024
# The logo's square plate, in drawing units.
PLATE = 1000.0
PLATE_RADIUS = 150.0


# --- Outlines --------------------------------------------------------------------------------------

class Path:
    """An outline as SVG path commands (M, L, C, Z), kept as points so it can be moved, skewed and
    measured. Several closed parts can live in one path (a ring is two circles)."""

    def __init__(self):
        self.cmds = []  # (letter, [points])

    def move(self, p):
        self.cmds.append(("M", [p]))
        return self

    def line(self, p):
        self.cmds.append(("L", [p]))
        return self

    def curve(self, c1, c2, p):
        self.cmds.append(("C", [c1, c2, p]))
        return self

    def close(self):
        self.cmds.append(("Z", []))
        return self

    def add(self, other):
        """Puts another path's parts into this one (for rings and cut-outs with evenodd)."""
        self.cmds.extend(other.cmds)
        return self

    def mapped(self, f):
        """A copy with every point passed through f (a move, a turn, a skew)."""
        result = Path()
        result.cmds = [(letter, [f(p) for p in points]) for letter, points in self.cmds]
        return result

    def points(self):
        return [p for _, pts in self.cmds for p in pts]

    def flattened(self, steps=32):
        """The outline of a one-part path as a list of points along its curves (for cutting)."""
        result = []
        for letter, pts in self.cmds:
            if letter in ("M", "L"):
                result.append(pts[0])
            elif letter == "C":
                p0, (c1, c2, p3) = result[-1], pts
                for i in range(1, steps + 1):
                    t = i / steps
                    a, b, c, d = (1 - t) ** 3, 3 * (1 - t) ** 2 * t, 3 * (1 - t) * t * t, t ** 3
                    result.append((a * p0[0] + b * c1[0] + c * c2[0] + d * p3[0],
                                   a * p0[1] + b * c1[1] + c * c2[1] + d * p3[1]))
        return result

    def bbox(self):
        pts = self.points()
        xs = [p[0] for p in pts]
        ys = [p[1] for p in pts]
        return (min(xs), min(ys), max(xs), max(ys))

    def d(self):
        parts = []
        for letter, pts in self.cmds:
            coords = " ".join(f"{_num(x)},{_num(y)}" for x, y in pts)
            parts.append(letter + coords)
        return "".join(parts)


def _num(value):
    text = f"{value:.1f}"
    return text[:-2] if text.endswith(".0") else text


def polygon(points):
    path = Path().move(points[0])
    for p in points[1:]:
        path.line(p)
    return path.close()


def circle_points(center, radius, count=360):
    cx, cy = center
    return [(cx + radius * math.cos(2 * math.pi * i / count), cy + radius * math.sin(2 * math.pi * i / count))
            for i in range(count)]


def ellipse(center, rx, ry, turn_deg=0.0):
    """An ellipse as four cubic curves (the usual 0.5523 handle length gives a near-perfect circle)."""
    k = 0.5523
    unit = Path().move((1, 0))
    unit.curve((1, k), (k, 1), (0, 1)).curve((-k, 1), (-1, k), (-1, 0))
    unit.curve((-1, -k), (-k, -1), (0, -1)).curve((k, -1), (1, -k), (1, 0)).close()
    return unit.mapped(lambda p: turned(center, (center[0] + p[0] * rx, center[1] + p[1] * ry), turn_deg))


def circle(center, radius):
    return ellipse(center, radius, radius)


def ring(center, outer, inner):
    """A ring: two circles, the inner one cut out by fill-rule evenodd."""
    return circle(center, outer).add(circle(center, inner))


def rounded_rect(x0, y0, x1, y1, r):
    k = 0.5523 * r
    path = Path().move((x0 + r, y0)).line((x1 - r, y0))
    path.curve((x1 - r + k, y0), (x1, y0 + r - k), (x1, y0 + r)).line((x1, y1 - r))
    path.curve((x1, y1 - r + k), (x1 - r + k, y1), (x1 - r, y1)).line((x0 + r, y1))
    path.curve((x0 + r - k, y1), (x0, y1 - r + k), (x0, y1 - r)).line((x0, y0 + r))
    path.curve((x0, y0 + r - k), (x0 + r - k, y0), (x0 + r, y0))
    return path.close()


def bar(p1, p2, width1, width2):
    """A straight limb from p1 to p2 that tapers from width1 to width2 (a tree's branch, a mast)."""
    dx, dy = p2[0] - p1[0], p2[1] - p1[1]
    length = math.hypot(dx, dy)
    nx, ny = -dy / length, dx / length
    return polygon([(p1[0] + nx * width1 / 2, p1[1] + ny * width1 / 2), (p2[0] + nx * width2 / 2, p2[1] + ny * width2 / 2),
                    (p2[0] - nx * width2 / 2, p2[1] - ny * width2 / 2), (p1[0] - nx * width1 / 2, p1[1] - ny * width1 / 2)])


def turned(center, p, angle_deg):
    """p turned about center by angle_deg (clockwise on screen, where y points down)."""
    a = math.radians(angle_deg)
    x, y = p[0] - center[0], p[1] - center[1]
    return (center[0] + x * math.cos(a) - y * math.sin(a), center[1] + x * math.sin(a) + y * math.cos(a))


def quad_points(p0, control, p2, count=48):
    """Points along a quadratic curve (for outlines that get cut afterwards)."""
    result = []
    for i in range(count + 1):
        t = i / count
        a, b, c = (1 - t) ** 2, 2 * (1 - t) * t, t * t
        result.append((a * p0[0] + b * control[0] + c * p2[0], a * p0[1] + b * control[1] + c * p2[1]))
    return result


def keep_side(points, a, b, c):
    """Cuts a polygon along a straight line and keeps the part where a*x + b*y + c >= 0
    (one step of the Sutherland-Hodgman clipping algorithm)."""
    result = []
    for i, current in enumerate(points):
        previous = points[i - 1]
        cur_in = a * current[0] + b * current[1] + c >= 0
        prev_in = a * previous[0] + b * previous[1] + c >= 0
        if cur_in != prev_in:
            fp = a * previous[0] + b * previous[1] + c
            fc = a * current[0] + b * current[1] + c
            t = fp / (fp - fc)
            result.append((previous[0] + t * (current[0] - previous[0]), previous[1] + t * (current[1] - previous[1])))
        if cur_in:
            result.append(current)
    return result


def inside_convex(points, convex):
    """The part of a polygon inside a convex shape (a disc as many points), cut edge by edge."""
    area = sum(convex[i - 1][0] * convex[i][1] - convex[i][0] * convex[i - 1][1] for i in range(len(convex)))
    sign = 1.0 if area > 0 else -1.0
    result = points
    for i in range(len(convex)):
        (x0, y0), (x1, y1) = convex[i - 1], convex[i]
        # Inside is on the left of each edge for a counter-clockwise outline (the sign flips it otherwise).
        a, b = -(y1 - y0) * sign, (x1 - x0) * sign
        result = keep_side(result, a, b, -(a * x0 + b * y0))
        if not result:
            break
    return result


def wave_points(x0, x1, y, height, waves, count=120):
    return [(x0 + (x1 - x0) * i / count, y + height * math.sin(2 * math.pi * waves * i / count)) for i in range(count + 1)]


def crescent(outer_center, outer_r, inner_center, inner_r, count=720):
    """The part of the outer disc that the inner disc does not cover (a moon)."""
    def inside(p, c, r):
        return math.hypot(p[0] - c[0], p[1] - c[1]) < r

    outer = circle_points(outer_center, outer_r, count)
    inner = circle_points(inner_center, inner_r, count)
    outer_flags = [not inside(p, inner_center, inner_r) for p in outer]
    inner_flags = [inside(p, outer_center, outer_r) for p in inner]
    outer_arc = _run(outer, outer_flags)
    inner_arc = _run(inner, inner_flags)
    # Walk back along the inner arc from where the outer arc ended.
    if math.dist(inner_arc[0], outer_arc[-1]) < math.dist(inner_arc[-1], outer_arc[-1]):
        return outer_arc + inner_arc
    return outer_arc + inner_arc[::-1]


def _run(points, flags):
    """The one unbroken run of flagged points around a closed loop, in order."""
    count = len(points)
    start = next(i for i in range(count) if flags[i] and not flags[i - 1])
    result = []
    i = start
    while flags[i % count] and len(result) < count:
        result.append(points[i % count])
        i += 1
    return result


# --- Letters ---------------------------------------------------------------------------------------

_FONT_MAP = PangoCairo.FontMap.get_default()


def _face(family, face_name):
    for fam in _FONT_MAP.list_families():
        if fam.get_name() == family:
            for face in fam.list_faces():
                if face.get_face_name() == face_name:
                    return face.describe()
    raise SystemExit(f"Font not installed: {family} {face_name} (see fc-list)")


def text_path(text, family, face_name, size, tracking_em=0.0):
    """The outline of a line of text with its baseline at y = 0, and its advance width.
    Pango lays the letters out (with the font's kerning); cairo hands back the outlines."""
    surface = cairo.RecordingSurface(cairo.CONTENT_COLOR_ALPHA, None)
    ctx = cairo.Context(surface)
    layout = PangoCairo.create_layout(ctx)
    options = cairo.FontOptions()
    options.set_hint_style(cairo.HINT_STYLE_NONE)
    options.set_hint_metrics(cairo.HINT_METRICS_OFF)
    PangoCairo.context_set_font_options(layout.get_context(), options)
    layout.get_context().set_round_glyph_positions(False)
    layout.context_changed()
    desc = _face(family, face_name)
    desc.set_absolute_size(size * Pango.SCALE)
    layout.set_font_description(desc)
    if tracking_em:
        attrs = Pango.AttrList()
        attrs.insert(Pango.attr_letter_spacing_new(int(tracking_em * size * Pango.SCALE)))
        layout.set_attributes(attrs)
    layout.set_text(text, -1)
    baseline = layout.get_baseline() / Pango.SCALE
    PangoCairo.layout_path(ctx, layout)
    path = Path()
    for kind, pts in ctx.copy_path():
        if kind == cairo.PATH_MOVE_TO:
            path.move((pts[0], pts[1] - baseline))
        elif kind == cairo.PATH_LINE_TO:
            path.line((pts[0], pts[1] - baseline))
        elif kind == cairo.PATH_CURVE_TO:
            path.curve((pts[0], pts[1] - baseline), (pts[2], pts[3] - baseline), (pts[4], pts[5] - baseline))
        elif kind == cairo.PATH_CLOSE_PATH:
            path.close()
    _, logical = layout.get_extents()
    return path, logical.width / Pango.SCALE


def skewed(path, degrees):
    """Leans a path to the right by degrees (italic), about the baseline y = 0."""
    lean = math.tan(math.radians(degrees))
    return path.mapped(lambda p: (p[0] - p[1] * lean, p[1]))


class Shape:
    """One filled outline with its colours (and an optional outline stroke)."""

    def __init__(self, path, fill, stroke=None, stroke_width=0.0, evenodd=False):
        self.path = path
        self.fill = fill
        self.stroke = stroke
        self.stroke_width = stroke_width
        self.evenodd = evenodd

    def bbox(self):
        x0, y0, x1, y1 = self.path.bbox()
        w = self.stroke_width / 2
        return (x0 - w, y0 - w, x1 + w, y1 + w)

    def svg(self):
        attrs = f'd="{self.path.d()}" fill="{self.fill}"'
        if self.evenodd:
            attrs += ' fill-rule="evenodd"'
        if self.stroke:
            attrs += f' stroke="{self.stroke}" stroke-width="{_num(self.stroke_width)}" stroke-linejoin="round"'
        return f"<path {attrs}/>"


def word(runs, size, skew_deg=0.0, x=0.0):
    """Shapes for a line of text in coloured runs: [(text, family, face, colour, tracking_em), ...].
    Returns the shapes and the x where the next run would start."""
    shapes = []
    for text, family, face, colour, tracking in runs:
        path, advance = text_path(text, family, face, size, tracking)
        path = path.mapped(lambda p, dx=x: (p[0] + dx, p[1]))
        shapes.append(Shape(skewed(path, skew_deg), colour))
        x += advance
    return shapes, x


def bbox_of(shapes):
    boxes = [s.bbox() for s in shapes]
    return (min(b[0] for b in boxes), min(b[1] for b in boxes), max(b[2] for b in boxes), max(b[3] for b in boxes))


def moved(shapes, dx, dy, scale=1.0):
    result = []
    for s in shapes:
        path = s.path.mapped(lambda p: (p[0] * scale + dx, p[1] * scale + dy))
        result.append(Shape(path, s.fill, s.stroke, s.stroke_width * scale, s.evenodd))
    return result


def fitted(shapes, box):
    """The shapes scaled and moved to fit inside box (x0, y0, x1, y1), centred, keeping their shape."""
    bx0, by0, bx1, by1 = bbox_of(shapes)
    x0, y0, x1, y1 = box
    scale = min((x1 - x0) / (bx1 - bx0), (y1 - y0) / (by1 - by0))
    dx = (x0 + x1) / 2 - (bx0 + bx1) / 2 * scale
    dy = (y0 + y1) / 2 - (by0 + by1) / 2 * scale
    return moved(shapes, dx, dy, scale)


# --- The eleven brands -----------------------------------------------------------------------------
# Every mark is drawn in a 1000 x 1000 box (y points down). Colours are the brand's palette in
# brands.md: primary is the sail's main cloth and the board's deck, secondary the second panels,
# accent the small highlights.

def tripletone():
    """A sail in three tones: the luff, the leech and the foot of a windsurf sail, cut into three
    panels from dark to light (a 'tritone' print)."""
    head, tack, clew = (470, 60), (270, 930), (870, 820)
    outline = quad_points(head, (285, 420), tack) + quad_points(clew, (915, 360), head)[:-1]
    gap = 16.0
    slope = 0.14  # the panel seams rise toward the leech like battens

    def seam(y0, side):
        # keep y >= line + gap (side = 1) or y <= line - gap (side = -1); line: y = y0 - slope (x - 270)
        return (side * slope, side * 1.0, -side * (y0 + slope * 270) - gap)

    low = keep_side(outline, *seam(650, 1))
    middle = keep_side(keep_side(outline, *seam(650, -1)), *seam(375, 1))
    top = keep_side(outline, *seam(375, -1))
    mark = [Shape(polygon(low), "#0E7C78"), Shape(polygon(middle), "#2BC4B4"), Shape(polygon(top), "#A5EFE4")]
    font = ("Fira Sans", "ExtraBold")
    wordmark, _ = word([("TRIPLE", *font, "#EEF3F2", 0.05), ("TONE", *font, "#2BC4B4", 0.05)], 200)
    return mark, wordmark


def savanna():
    """A low sun over the plain with an umbrella-topped acacia in front of it."""
    sun = keep_side(circle_points((500, 470), 330), 0, -1, 690)  # cut flat at the horizon
    brown, gold = "#3A2416", "#FFC548"
    mark = [Shape(polygon(sun), gold), Shape(rounded_rect(90, 702, 910, 752, 25), brown)]
    canopy_bottom = 468.0
    for center, rx, ry in [((410, 452), 105, 42), ((530, 436), 132, 54), ((650, 452), 110, 40)]:
        lobe = [(center[0] + p[0] * rx, center[1] + p[1] * ry) for p in circle_points((0, 0), 1)]
        mark.append(Shape(polygon(keep_side(lobe, 0, -1, canopy_bottom)), brown))
    for p1, p2, w1, w2 in [((560, 706), (552, 575), 40, 28), ((552, 585), (438, 462), 26, 14),
                           ((552, 585), (652, 458), 26, 14), ((554, 590), (560, 455), 18, 10)]:
        mark.append(Shape(bar(p1, p2, w1, w2), brown))
    wordmark, _ = word([("savanna", "Noto Serif Display", "Black Italic", "#FFF1D6", 0.0)], 200)
    return mark, wordmark


def point9():
    """A 9 whose bowl holds a point, on a slanted racing tile."""
    lean = math.tan(math.radians(10))

    def slant(path):
        return path.mapped(lambda p: (p[0] + lean * (500 - p[1]), p[1]))

    center = (495, 385)
    mark = [
        Shape(slant(rounded_rect(200, 110, 800, 890, 70)), "#111215"),
        Shape(slant(ring(center, 195, 92)), "#C8F21C", evenodd=True),
        Shape(slant(polygon([(587, 385), (690, 385), (690, 800), (587, 800)])), "#C8F21C"),
        Shape(slant(circle(center, 52)), "#FF2E88"),
    ]
    font = ("Fira Sans Condensed", "Heavy Italic")
    wordmark, _ = word([("POINT", *font, "#F4F4F4", 0.02), (".", *font, "#FF2E88", 0.02),
                        ("9", *font, "#C8F21C", 0.0)], 200)
    return mark, wordmark


def moonboard():
    """A crescent moon on a night-blue disc."""
    moon = crescent((470, 520), 300, (595, 415), 255)
    mark = [Shape(circle((500, 500), 420), "#2B4590"), Shape(polygon(moon), "#FFC93D")]
    font = ("Fira Sans", "Heavy")
    wordmark, _ = word([("m", *font, "#F2EAD3", 0.0), ("oo", *font, "#FFC93D", 0.0),
                        ("nboard", *font, "#F2EAD3", 0.0)], 200)
    return mark, wordmark


def nielstrots():
    """A swallow-tailed pennant flying proudly from its mast, red over Dutch orange."""
    hoist_x, length, notch = 262.0, 620.0, 0.8

    def edge(u, side):
        """A point of the flag u of the way from the mast to the fly: side -1 the top edge, 0 the
        middle, +1 the bottom edge. The flag rises toward its end, waves once and tapers."""
        middle = 300 - 70 * u + 28 * math.sin(2 * math.pi * 0.9 * u)
        half_height = 170 - 45 * u
        return (hoist_x + length * u, middle + side * half_height)

    steps = [i / 40 for i in range(41)]
    inner = [s * notch for s in steps]
    upper = [edge(u, -1) for u in steps] + [edge(notch, 0)] + [edge(u, 0) for u in reversed(inner)]
    lower = [edge(u, 0) for u in inner] + [edge(1.0, 1)] + [edge(u, 1) for u in reversed(steps)]
    mark = [
        Shape(rounded_rect(213, 110, 267, 890, 27), "#D3202F"),
        Shape(polygon(upper), "#D3202F"),
        Shape(polygon(lower), "#FF8A00"),
    ]
    font = ("Open Sans", "Condensed ExtraBold Italic")
    wordmark, _ = word([("Niels", *font, "#F4F4F4", 0.0), ("Trots", *font, "#D3202F", 0.0)], 200)
    return mark, wordmark


def pj_new_sealand():
    """A seal coming up through the surf with a ball on its nose."""
    disc = circle_points((500, 500), 405)
    teal, seal, white = "#0A6670", "#14262D", "#F4F7F5"
    body = Path().move((290, 990))
    body.curve((300, 760), (340, 560), (430, 470)).line((610, 520))
    body.curve((660, 640), (700, 820), (720, 990)).close()
    body_points = body.flattened()
    water = wave_points(0, 1000, 742, 24, 2) + [(1000, 1000), (0, 1000)]
    stripe = wave_points(0, 1000, 812, 24, 2) + wave_points(1000, 0, 836, -24, 2)
    mark = [
        Shape(circle((500, 500), 440), teal),
        Shape(polygon(inside_convex(body_points, disc)), seal),
        Shape(ellipse((505, 430), 118, 100, -20), seal),
        Shape(ellipse((615, 358), 82, 50, -35), seal),
        Shape(circle((674, 316), 21), "#05090B"),
        Shape(circle((522, 398), 18), white),
        Shape(circle((598, 380), 8), white),
        Shape(circle((618, 368), 8), white),
        Shape(circle((606, 396), 8), white),
        Shape(circle((714, 238), 64), "#8DC63F"),
        Shape(polygon(inside_convex(water, disc)), white),
        Shape(polygon(inside_convex(stripe, disc)), teal),
    ]
    big, _ = word([("PJ", "Noto Sans", "Black Italic", teal, 0.0)], 300)
    small, _ = word([("NEW SEALAND", "Fira Sans Condensed", "Bold", seal, 0.12)], 112)
    # "NEW SEALAND" to the right of "PJ", centred on its height.
    bx0, by0, bx1, by1 = bbox_of(big)
    sx0, sy0, sx1, sy1 = bbox_of(small)
    small = moved(small, bx1 + 50 - sx0, (by0 + by1) / 2 - (sy0 + sy1) / 2)
    return mark, big + small


def bmx_boards():
    """A chainring: the toothed sprocket of a BMX bike."""
    teeth, root_r, tip_r = 22, 385.0, 440.0
    pitch = 2 * math.pi / teeth
    outline = []
    for i in range(teeth):
        a = i * pitch
        for angle, r in [(a - 0.31 * pitch, root_r), (a - 0.17 * pitch, tip_r), (a + 0.17 * pitch, tip_r),
                         (a + 0.31 * pitch, root_r)]:
            outline.append((500 + r * math.cos(angle), 500 + r * math.sin(angle)))
    # The spider: a black disc with five curved windows (the yellow ring shows through them).
    spider = circle((500, 500), 300)
    for i in range(5):
        start = -90 + 18 / 2 + i * 72  # five windows of 54 degrees between arms of 18 degrees
        angles = [math.radians(start + 54 * k / 30) for k in range(31)]
        window = [(500 + 255 * math.cos(a), 500 + 255 * math.sin(a)) for a in angles]
        window += [(500 + 135 * math.cos(a), 500 + 135 * math.sin(a)) for a in reversed(angles)]
        spider.add(polygon(window))
    mark = [Shape(polygon(outline), "#FFD21F", stroke="#141414", stroke_width=24),
            Shape(spider, "#141414", evenodd=True),
            Shape(circle((500, 500), 78), "#E8352B", stroke="#141414", stroke_width=14)]
    big, end = word([("BMX", "Fira Sans", "Ultra Italic", "#141414", 0.0)], 300)
    tag_text, _ = word([("BOARDS", "Fira Sans Condensed", "Heavy Italic", "#F4F4F4", 0.08)], 110)
    bx0, by0, bx1, by1 = bbox_of(big)
    tx0, ty0, tx1, ty1 = bbox_of(tag_text)
    pad = 26.0
    tag_text = moved(tag_text, bx1 + 50 + pad - tx0, by1 - pad - ty1)  # sits on the baseline of BMX
    tx0, ty0, tx1, ty1 = bbox_of(tag_text)
    lean = math.tan(math.radians(12))
    y0, y1 = ty0 - pad, ty1 + pad
    tag = polygon([(tx0 - pad + lean * (y1 - y0), y0), (tx1 + pad + lean * (y1 - y0), y0), (tx1 + pad, y1), (tx0 - pad, y1)])
    return mark, big + [Shape(tag, "#E8352B")] + tag_text


def southsails():
    """A compass whose painted half of the needle points the other way: south."""
    navy, coral, white = "#0F2A4A", "#FF5A47", "#F6F4EE"
    mark = [
        Shape(circle((500, 500), 430), navy),
        Shape(circle((500, 500), 362), white),
        Shape(rounded_rect(168, 488, 236, 512, 10), navy),
        Shape(rounded_rect(764, 488, 832, 512, 10), navy),
        Shape(polygon([(430, 500), (500, 175), (570, 500)]), navy),
        Shape(polygon([(430, 500), (570, 500), (500, 840)]), coral),
        Shape(circle((500, 500), 26), white, stroke=navy, stroke_width=10),
    ]
    wordmark, _ = word([("SOUTH", "Fira Sans", "Heavy", white, 0.03), ("SAILS", "Fira Sans", "SemiBold", coral, 0.03)], 200)
    return mark, wordmark


def s3kauai():
    """Three green peaks of a garden island over the lagoon, with a coral sun."""
    inner = circle_points((500, 500), 405)
    peaks = [(60, 760), (300, 400), (400, 540), (505, 245), (615, 520), (725, 425), (950, 740), (950, 1000),
             (60, 1000)]
    water = wave_points(0, 1000, 745, 20, 2.5) + [(1000, 1000), (0, 1000)]
    foam = wave_points(0, 1000, 815, 20, 2.5) + wave_points(1000, 0, 837, -20, 2.5)
    cream = "#FFF4E0"
    mark = [
        Shape(circle((500, 500), 440), "#0B8FA0"),
        Shape(circle((500, 500), 420), cream),
        Shape(circle((680, 300), 100), "#FF5B5B"),
        Shape(polygon(inside_convex(peaks, inner)), "#17804A"),
        Shape(polygon(inside_convex(water, inner)), "#13A9C0"),
        Shape(polygon(inside_convex(foam, inner)), cream),
    ]
    font = ("Fira Sans", "Heavy")
    wordmark, _ = word([("s", *font, "#F4F4F4", 0.0), ("3", *font, "#FF5B5B", 0.0), ("kauai", *font, "#F4F4F4", 0.0)], 200)
    return mark, wordmark


def _board(center, length, width, angle_deg):
    """A windsurf board seen from above: pointed nose, square tail (the nose toward +x before turning)."""
    half, w = length / 2, width / 2
    board = Path().move((-half, -0.78 * w))
    board.curve((-0.75 * half, -0.92 * w), (-0.45 * half, -w), (-0.15 * half, -w))
    board.curve((0.35 * half, -w), (0.8 * half, -0.5 * w), (half, 0))
    board.curve((0.8 * half, 0.5 * w), (0.35 * half, w), (-0.15 * half, w))
    board.curve((-0.45 * half, w), (-0.75 * half, 0.92 * w), (-half, 0.78 * w)).close()
    return board.mapped(lambda p: turned((0, 0), p, angle_deg)).mapped(lambda p: (p[0] + center[0], p[1] + center[1]))


def forbidden():
    """A 'not allowed' sign whose bar is a windsurf board."""
    red, white, black = "#D7141A", "#F5F1E8", "#121212"
    mark = [
        Shape(circle((500, 500), 440), red),
        Shape(circle((500, 500), 345), white),
        Shape(_board((500, 500), 720, 150, 45), red),
        Shape(bar(turned((500, 500), (230, 500), 45), turned((500, 500), (735, 500), 45), 12, 12), white),
    ]
    font = ("Fira Sans Condensed", "Heavy")
    size = 200
    f, x = word([("F", *font, white, 0.04)], size)
    o_path, o_advance = text_path("O", *font, size, 0.04)
    ox0, oy0, ox1, oy1 = o_path.bbox()
    center, radius = ((ox0 + ox1) / 2 + x, (oy0 + oy1) / 2), (oy1 - oy0) / 2
    o_sign = [Shape(ring(center, radius, radius * 0.66), white, evenodd=True),
              Shape(_board(center, radius * 1.75, radius * 0.42, 45), black)]
    rest, _ = word([("RBIDDEN", *font, white, 0.04)], size, x=x + o_advance)
    return mark, f + o_sign + rest


def _letter_g(center, outer, inner, bar_from):
    """A round G: an arc open at the upper right, and a crossbar into the middle from bar_from."""
    cx, cy = center
    thickness = outer - inner
    angles = [math.radians(40 + 320 * i / 160) for i in range(161)]  # 40 to 360 degrees, y up
    arc = [(cx + outer * math.cos(a), cy - outer * math.sin(a)) for a in angles]
    arc += [(cx + inner * math.cos(a), cy - inner * math.sin(a)) for a in reversed(angles)]
    crossbar = polygon([(cx + bar_from, cy - thickness), (cx + outer, cy - thickness), (cx + outer, cy), (cx + bar_from, cy)])
    return [polygon(arc), crossbar]


def gg_sails():
    """Two Gs, one inside the other ('good game')."""
    gold, white = "#F5B800", "#FFFFFF"
    mark = [Shape(circle((500, 500), 440), "#5B2BD1")]
    mark += [Shape(p, gold) for p in _letter_g((500, 500), 340, 255, 232)]
    mark += [Shape(p, white) for p in _letter_g((500, 500), 212, 138, 40)]
    font = ("Fira Sans", "Heavy")
    wordmark, _ = word([("GG", *font, gold, 0.04), (" SAILS", *font, white, 0.04)], 200)
    return mark, wordmark


def montag():
    """A swept race fin on a silver disc: the brand of the game's own fins (Monday after Sunday)."""
    carbon, silver, blue = "#1E2329", "#C9D0D8", "#2F80ED"
    fin = Path().move((335, 300)).line((640, 300))
    fin.curve((600, 490), (655, 690), (752, 805))
    fin.curve((768, 826), (742, 842), (716, 826))
    fin.curve((590, 715), (385, 520), (335, 300)).close()
    mark = [
        Shape(circle((500, 500), 440), blue),
        Shape(circle((500, 500), 410), silver),
        Shape(rounded_rect(290, 238, 690, 300, 16), carbon),
        Shape(fin, carbon),
    ]
    font = ("Fira Sans", "Heavy")
    wordmark, _ = word([("MON", *font, "#E8ECF0", 0.06), ("TAG", *font, "#4C9BFF", 0.06)], 200)
    return mark, wordmark


# slug: (name for the SVG title, drawing function, plate colour = the brand's primary)
BRANDS = {
    "tripletone": ("Tripletone", tripletone, "#16191E"),
    "savanna": ("Savanna", savanna, "#C2581F"),
    "point9": ("Point.9", point9, "#111215"),
    "moonboard": ("Moonboard", moonboard, "#14224F"),
    "nielstrots": ("NielsTrots", nielstrots, "#151515"),
    "pj_new_sealand": ("PJ New Sealand", pj_new_sealand, "#F4F7F5"),
    "bmx_boards": ("BMX Boards", bmx_boards, "#FFD21F"),
    "southsails": ("SouthSails", southsails, "#0F2A4A"),
    "s3kauai": ("s3kauai", s3kauai, "#0B8FA0"),
    "forbidden": ("Forbidden", forbidden, "#D7141A"),
    "gg_sails": ("GG Sails", gg_sails, "#5B2BD1"),
    "montag": ("Montag", montag, "#1E2329"),
}


# --- Files -----------------------------------------------------------------------------------------

def svg_document(title, view_box, body):
    x0, y0, x1, y1 = view_box
    w, h = x1 - x0, y1 - y0
    scale = PNG_LONG_SIDE_PX / max(w, h)
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="{_num(x0)} {_num(y0)} {_num(w)} {_num(h)}" '
            f'width="{round(w * scale)}" height="{round(h * scale)}">\n<title>{title}</title>\n'
            + "\n".join(body) + "\n</svg>\n")


def padded(box, fraction, square=False):
    x0, y0, x1, y1 = box
    pad = fraction * max(x1 - x0, y1 - y0)
    x0, y0, x1, y1 = x0 - pad, y0 - pad, x1 + pad, y1 + pad
    if square:
        side = max(x1 - x0, y1 - y0)
        cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
        x0, x1, y0, y1 = cx - side / 2, cx + side / 2, cy - side / 2, cy + side / 2
    return (x0, y0, x1, y1)


def logo_shapes(mark, wordmark, plate_colour):
    """The square lockup: the plate, the mark in the upper part, the wordmark below it."""
    plate = Shape(rounded_rect(0, 0, PLATE, PLATE, PLATE_RADIUS), plate_colour)
    mark_box = (190, 80, 810, 630)
    # A long name fills the width; a short one (POINT.9) is limited by the box's height.
    word_box = (90, 680, 910, 900)
    return [plate] + fitted(mark, mark_box) + fitted(wordmark, word_box)


def write_brand(slug):
    title, draw, plate_colour = BRANDS[slug]
    mark, wordmark = draw()
    folder = os.path.join(OUT_DIR, slug)
    os.makedirs(folder, exist_ok=True)
    files = {
        "mark": svg_document(title, padded(bbox_of(mark), 0.03, square=True), [s.svg() for s in mark]),
        "wordmark": svg_document(title, padded(bbox_of(wordmark), 0.04), [s.svg() for s in wordmark]),
        "logo": svg_document(title, (0, 0, PLATE, PLATE), [s.svg() for s in logo_shapes(mark, wordmark, plate_colour)]),
    }
    for name, text in files.items():
        svg_path = os.path.join(folder, name + ".svg")
        with open(svg_path, "w", encoding="utf-8") as handle:
            handle.write(text)
        # The SVG's width and height already put the long side at 1024 px.
        subprocess.run(["rsvg-convert", "--keep-aspect-ratio", "-o", os.path.join(folder, name + ".png"), svg_path],
                       check=True)
    print(f"{slug}: mark, wordmark, logo")


MENU_BLUE = "#12263F"  # the menu panels' colour (Game/ui/theme.tres)
SHEET = os.path.join(REPO, ".screenshots", "brands.png")


def _magick(*args):
    subprocess.run(["magick", *args], check=True)


def contact_sheet():
    """One row per brand: what the team needs to judge the logos at a glance."""
    work = os.path.join(REPO, ".screenshots", "brands")
    os.makedirs(work, exist_ok=True)
    rows = []
    for slug, (title, _, plate_colour) in BRANDS.items():
        folder = os.path.join(OUT_DIR, slug)
        logo, mark, wordmark = (os.path.join(folder, n + ".png") for n in ("logo", "mark", "wordmark"))
        tiles = []

        def tile(name, background, width, height, image, fit, gravity="center"):
            out = os.path.join(work, f"{slug}_{name}.png")
            _magick("-size", f"{width}x{height}", f"xc:{background}", "(", image, "-resize", fit, ")",
                    "-gravity", gravity, "-composite", out)
            tiles.append(out)
            return out

        label = os.path.join(work, f"{slug}_label.png")
        _magick("-size", "190x280", "xc:#F2F2F2", "-font", "DejaVu-Sans-Bold", "-pointsize", "22", "-fill", "#222222",
                "-gravity", "center", "-annotate", "+0+0", title, label)
        tiles.append(label)
        tile("logo", MENU_BLUE, 280, 280, logo, "250x250")
        tile("mark_white", "#FFFFFF", 280, 280, mark, "220x220")
        tile("mark_blue", MENU_BLUE, 280, 280, mark, "220x220")
        tile("cloth", plate_colour, 560, 280, wordmark, "500x200")
        # Small: the mark as a menu card's 40 px icon, the wordmark as a sail's print seen from afar.
        small = os.path.join(work, f"{slug}_small.png")
        _magick("-size", "220x280", f"xc:{MENU_BLUE}", "(", mark, "-resize", "40x40", ")", "-gravity", "north",
                "-geometry", "+0+30", "-composite", "(", "-size", "200x70", f"xc:{plate_colour}", "(", wordmark,
                "-resize", "150x40", ")", "-gravity", "center", "-composite", ")", "-gravity", "south",
                "-geometry", "+0+40", "-composite", small)
        tiles.append(small)
        row = os.path.join(work, f"{slug}_row.png")
        _magick(*tiles, "-background", "#DDDDDD", "-splice", "8x0", "+append", row)
        rows.append(row)
    os.makedirs(os.path.dirname(SHEET), exist_ok=True)
    _magick(*rows, "-background", "#DDDDDD", "-splice", "0x8", "-append", "-bordercolor", "#DDDDDD",
            "-border", "8", "+repage", SHEET)
    print(f"contact sheet: {SHEET}")


def main(argv):
    slugs = argv or list(BRANDS)
    for slug in slugs:
        if slug not in BRANDS:
            raise SystemExit(f"Unknown brand '{slug}'. Known: {', '.join(BRANDS)}")
        write_brand(slug)
    contact_sheet()


if __name__ == "__main__":
    main(sys.argv[1:])
