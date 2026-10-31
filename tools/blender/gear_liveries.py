"""The gear's liveries: each brand's deck, bottom and sail pictures, drawn pixel by pixel for
tools/blender/build_gear_models.py (which describes the files and their UVs).

The colours are the brands' own (Game/gear/brands/<slug>.tres: primary for the sail's cloth and
the board's deck, secondary for the second panels, the rails and the stripes, accent for the small
highlights), with a few more per brand from brand_research.md section 4 (PALETTE). The logos are
the brands' wordmark and mark PNGs (Game/assets/brands/<slug>/, drawn by tools/brands/make_logos.py),
stamped into the pictures; the model names and sizes are written with Blender's built-in font
(so nobody needs a font installed to rebuild). The layouts follow where the real brands put their
graphics (section 4: "at ten metres" and "logo placement"); every shape here is simple geometry of
our own (stripes, bands, rings, hexagons, squares), nothing traced from a real graphic, and no real
maker's or model's name.

Coordinates: a board's pictures are in metres, X across (port negative) and T from the tail; the
bottom's picture uses the same UV as the deck's (the board seen from above), so a print on the
bottom is drawn mirrored to read from below. A sail's picture is in the flat sail's metres, X back
from the mast and Y up from the mast foot, and in its (U, V): U from the luff (0) to the leech or
the foot (1) along a row, V from the tack (0) to the head (1) up the luff; the battens are rows,
so a batten is a line of constant V. The sail's front (+z, what the picture shows unmirrored) is
its port side.
"""

import math
import re
import struct
import zlib
from pathlib import Path

import bpy
import numpy as np

import build_rig_models as rig

BRANDS_DIR = rig.REPO / "Game" / "gear" / "brands"
LOGOS_DIR = rig.REPO / "Game" / "assets" / "brands"

# The pictures' sizes in pixels: a board's deck and bottom (across, along), a sail's panels (from
# the luff to the leech, from the foot to the head).
BOARD_PICTURE = (512, 2048)
SAIL_PICTURE = (1024, 2048)

# The sail picture's alpha code (sail_cloth.gdshaderinc): the brand's own cloth, which a race's
# colour may replace; a print that keeps its colours; a print on the front (port) side only; on
# the back (starboard) side only; clear film.
OWN, PRINT, FRONT_PRINT, BACK_PRINT, FILM = 255, 191, 140, 90, 0

# The fins are plain black carbon, as the default fin (no brand colours: Montag's fins).
FIN_MATERIAL = ((0.06, 0.06, 0.07), 0.3, 0.0)


def colour(code: str) -> np.ndarray:
    """A colour from its hex code, as 0 to 255 floats."""
    code = code.lstrip("#")
    return np.array([int(code[i:i + 2], 16) for i in (0, 2, 4)], dtype=float)


WHITE = colour("#F4F5F3")
BLACK = colour("#161618")
CLEAR = colour("#C8CDD4")   # under the clear film (only seen at a window's soft edge)

# What section 4 adds to each brand's three colours (estimates where the research marks them).
PALETTE = {
    "tripletone": dict(bottom="#094AC3", tones=("#0E7C78", "#2BC4B4", "#A5EFE4")),
    "savanna": dict(bottom="#3A2416", cream="#FFF1D6", dark="#9A4416"),
    "point9": dict(pearl="#F2F2EE", smoke="#2A2B2F"),
    "moonboard": dict(bottom="#05B8E8", disc="#2B4590"),
    "nielstrots": dict(),
    "pj_new_sealand": dict(slate="#14262D", grey="#C9D1D5", bottom="#F4F7F5"),
    "bmx_boards": dict(bottom="#FFD21F"),
    "southsails": dict(),
    "s3kauai": dict(cream="#FFF4E0"),
    "forbidden": dict(crimson="#7E0B10", bottom="#121212"),
    "gg_sails": dict(),
}


def read_brand(slug: str) -> dict:
    """A brand's name and colours from its .tres (Color(r, g, b, a) in 0 to 1) as 0 to 255
    floats, with the extra colours of PALETTE."""
    text = (BRANDS_DIR / f"{slug}.tres").read_text(encoding="utf-8")
    brand = {"name": re.search(r'^name = "([^"]*)"', text, re.MULTILINE).group(1), "slug": slug}
    for key in ("primary", "secondary", "accent"):
        values = re.search(rf"^{key} = Color\(([^)]*)\)", text, re.MULTILINE).group(1).split(",")
        brand[key] = np.array([float(x) for x in values[:3]]) * 255.0
    for key, value in PALETTE[slug].items():
        brand[key] = tuple(colour(v) for v in value) if isinstance(value, tuple) else colour(value)
    return brand


def material(rgb: np.ndarray, roughness: float = 0.8) -> tuple:
    """A material colour for build_rig_models.py's MATERIALS: sRGB 0 to 1, roughness, metallic."""
    return (tuple(float(c) / 255.0 for c in rgb), roughness, 0.0)


# --------------------------------------------------------------------------------------------
# Painting: soft-edged shapes, logos and text on a picture.
# --------------------------------------------------------------------------------------------

def soft(distance, pixel: float):
    """How much of a pixel a shape covers (0 to 1), from the signed distance to its edge
    (negative inside), so the edges are smooth."""
    return np.clip(0.5 - np.asarray(distance, dtype=float) / pixel, 0.0, 1.0)


def segment_distance(X, Y, a, b):
    distance, _ = rig.segment_distance(X, Y, a, b)
    return distance


def polygon_distance(X, Y, points: list):
    """The signed distance to a polygon's outline (negative inside; any polygon, even-odd)."""
    inside = np.zeros(np.shape(X), dtype=bool)
    nearest = np.full(np.shape(X), np.inf)
    for (ax, ay), (bx, by) in zip(points, points[1:] + points[:1]):
        crosses = ((ay > Y) != (by > Y)) & (X < (bx - ax) * (Y - ay) / ((by - ay) or 1e-12) + ax)
        inside ^= crosses
        nearest = np.minimum(nearest, segment_distance(X, Y, (ax, ay), (bx, by)))
    return np.where(inside, -nearest, nearest)


_images: dict = {}


def logo(slug: str, kind: str) -> np.ndarray:
    """A brand's logo PNG (kind "wordmark" or "mark") as (rows, columns, RGBA) in 0 to 1, top row
    first."""
    key = (slug, kind)
    if key not in _images:
        image = bpy.data.images.load(str(LOGOS_DIR / slug / f"{kind}.png"))
        width, height = image.size
        pixels = np.array(image.pixels[:], dtype=np.float32).reshape(height, width, 4)[::-1]
        bpy.data.images.remove(image)
        _images[key] = pixels
    return _images[key]


# Text: Blender's built-in font, turned into triangles and drawn into a picture of its own.
EM_PIXELS = 150          # the text pictures' resolution, pixels per font size
TEXT_BOTTOM, TEXT_TOP = -0.32, 1.02   # the text picture's height, in font sizes from the baseline
_texts: dict = {}
_cap_height: list = []


def text_font():
    """Inter, the font Blender ships for its own interface (SIL Open Font License), from Blender's
    data folder on any computer; Blender's built-in font if it is not there."""
    folder = bpy.utils.system_resource("DATAFILES", path="fonts")
    path = Path(folder) / "Inter.woff2" if folder else None
    if path is None or not path.exists():
        return None
    return bpy.data.fonts.load(str(path), check_existing=True)


def text_triangles(text: str, bold: float, italic: float, spacing: float) -> np.ndarray:
    """The letters of `text` as triangles (n, 3, 2), in font sizes."""
    curve = bpy.data.curves.new("label", type="FONT")
    font = text_font()
    if font is not None:
        curve.font = font
    curve.body = text
    curve.offset = bold
    curve.shear = italic
    curve.space_character = spacing
    obj = bpy.data.objects.new("label", curve)
    bpy.context.scene.collection.objects.link(obj)
    evaluated = obj.evaluated_get(bpy.context.evaluated_depsgraph_get())
    mesh = evaluated.to_mesh()
    mesh.calc_loop_triangles()
    points = np.array([v.co[:2] for v in mesh.vertices], dtype=float)
    corners = np.array([t.vertices[:] for t in mesh.loop_triangles], dtype=int)
    triangles = points[corners] if len(corners) else np.zeros((0, 3, 2))
    evaluated.to_mesh_clear()
    bpy.data.objects.remove(obj)
    bpy.data.curves.remove(curve)
    return triangles


def rasterise(triangles: np.ndarray, left: float, top: float, columns: int, rows: int, scale: float,
              samples: int = 4) -> np.ndarray:
    """How much of each pixel the triangles cover (0 to 1). Pixel (0, 0) starts at (left, top),
    `scale` pixels per unit, rows going down; each pixel is sampled samples x samples times."""
    sub = np.zeros((rows * samples, columns * samples), dtype=bool)
    step = scale * samples
    for triangle in triangles:
        cx = (triangle[:, 0] - left) * step
        cy = (top - triangle[:, 1]) * step
        c0, c1 = max(int(math.floor(cx.min())), 0), min(int(math.ceil(cx.max())), sub.shape[1])
        r0, r1 = max(int(math.floor(cy.min())), 0), min(int(math.ceil(cy.max())), sub.shape[0])
        if c1 <= c0 or r1 <= r0:
            continue
        px, py = np.meshgrid(np.arange(c0, c1) + 0.5, np.arange(r0, r1) + 0.5)
        area = (cx[1] - cx[0]) * (cy[2] - cy[0]) - (cy[1] - cy[0]) * (cx[2] - cx[0])
        if abs(area) < 1e-12:
            continue
        sign = 1.0 if area > 0 else -1.0
        inside = np.ones(px.shape, dtype=bool)
        for i in range(3):
            ax, ay, bx, by = cx[i], cy[i], cx[(i + 1) % 3], cy[(i + 1) % 3]
            inside &= sign * ((bx - ax) * (py - ay) - (by - ay) * (px - ax)) >= 0.0
        sub[r0:r1, c0:c1] |= inside
    return sub.reshape(rows, samples, columns, samples).mean(axis=(1, 3))


def text_picture(text: str, bold: float = 0.0, italic: float = 0.0, spacing: float = 1.0) -> np.ndarray:
    """The text as a white picture with its coverage in the alpha, from TEXT_BOTTOM to TEXT_TOP
    font sizes high around the baseline."""
    key = (text, bold, italic, spacing)
    if key not in _texts:
        triangles = text_triangles(text, bold, italic, spacing)
        if len(triangles) == 0:
            _texts[key] = np.zeros((4, 4, 4), dtype=np.float32)
        else:
            left = triangles[..., 0].min() - 0.05
            right = triangles[..., 0].max() + 0.05
            columns = int(math.ceil((right - left) * EM_PIXELS))
            rows = int(math.ceil((TEXT_TOP - TEXT_BOTTOM) * EM_PIXELS))
            cover = rasterise(triangles, left, TEXT_TOP, columns, rows, EM_PIXELS)
            picture = np.ones((rows, columns, 4), dtype=np.float32)
            picture[..., 3] = cover
            _texts[key] = picture
    return _texts[key]


def cap_height() -> float:
    """The height of a capital letter, in font sizes (measured once on an H)."""
    if not _cap_height:
        _cap_height.append(float(text_triangles("H", 0.0, 0.0, 1.0)[..., 1].max()))
    return _cap_height[0]


class Picture:
    """A picture being painted, with where each pixel is in metres (X, Y)."""

    def __init__(self, X, Y, base, pixel: float, alpha=None):
        self.X, self.Y = X, Y
        self.rgb = np.empty(np.shape(X) + (3,), dtype=float)
        self.rgb[:] = base
        self.alpha = None if alpha is None else np.full(np.shape(X), alpha, dtype=np.uint8)
        self.pixel = pixel   # metres per pixel, for the soft edges

    def paint(self, cover, rgb, alpha=None) -> None:
        """Paints `rgb` where `cover` (0 to 1, or True and False) says, and sets the alpha code
        where it covers more than half."""
        cover = np.asarray(cover, dtype=float)
        self.rgb += (np.asarray(rgb, dtype=float) - self.rgb) * cover[..., None]
        if alpha is not None and self.alpha is not None:
            self.alpha[cover > 0.5] = alpha

    def shape(self, distance, rgb, alpha=None) -> None:
        """Paints a shape given by its signed distance (negative inside)."""
        self.paint(soft(distance, self.pixel), rgb, alpha)

    def line(self, a, b, width: float, rgb, alpha=None) -> None:
        self.shape(segment_distance(self.X, self.Y, a, b) - 0.5 * width, rgb, alpha)

    def stamp(self, image: np.ndarray, centre, width: float, angle_deg: float = 0.0, mirror: bool = False,
              rgb=None, alpha=None) -> None:
        """Prints a picture (rows, columns, RGBA in 0 to 1) `width` metres wide, centred on
        `centre`, its rows' direction turned `angle_deg` from +X toward +Y, mirrored left to right
        if asked; in its own colours, or in `rgb` where it covers."""
        rows, columns = image.shape[:2]
        height = width * rows / columns
        angle = math.radians(angle_deg)
        dx, dy = self.X - centre[0], self.Y - centre[1]
        along = dx * math.cos(angle) + dy * math.sin(angle)
        up = -dx * math.sin(angle) + dy * math.cos(angle)
        u = along / width + 0.5
        v = 0.5 - up / height
        if mirror:
            u = 1.0 - u
        region = (u >= 0.0) & (u <= 1.0) & (v >= 0.0) & (v <= 1.0)
        if not np.any(region):
            return
        sample = bilinear(image, u[region] * columns - 0.5, v[region] * rows - 0.5)
        cover = np.zeros(np.shape(self.X))
        cover[region] = sample[:, 3]
        if rgb is None:
            colours = np.zeros(np.shape(self.X) + (3,))
            colours[region] = sample[:, :3] * 255.0
            self.rgb += (colours - self.rgb) * cover[..., None]
            if alpha is not None and self.alpha is not None:
                self.alpha[cover > 0.5] = alpha
        else:
            self.paint(cover, rgb, alpha)

    def text(self, text: str, centre, cap: float, rgb, angle_deg: float = 0.0, mirror: bool = False,
             bold: float = 0.0, italic: float = 0.0, spacing: float = 1.0, alpha=None) -> None:
        """Writes `text` with capitals `cap` metres high, centred on `centre`. `bold` thickens the
        letters by that share of the capitals' height on each side (negative thins them)."""
        picture = text_picture(text, round(bold * cap_height(), 4), italic, spacing)
        size = cap / cap_height()
        width = picture.shape[1] / EM_PIXELS * size
        # The text picture's middle is (TEXT_TOP + TEXT_BOTTOM) / 2 above the baseline; the
        # capitals' middle is half their height: shift so the capitals are centred.
        shift = (0.5 * cap_height() - 0.5 * (TEXT_TOP + TEXT_BOTTOM)) * size
        angle = math.radians(angle_deg)
        centre = (centre[0] + shift * math.sin(angle), centre[1] - shift * math.cos(angle))
        self.stamp(picture, centre, width, angle_deg, mirror, rgb, alpha)

    def text_width(self, text: str, cap: float, bold: float = 0.0, spacing: float = 1.0) -> float:
        picture = text_picture(text, round(bold * cap_height(), 4), 0.0, spacing)
        return picture.shape[1] / EM_PIXELS * cap / cap_height()

    def save(self, path: Path) -> None:
        pixels = np.clip(np.round(self.rgb), 0, 255).astype(np.uint8)
        if self.alpha is not None:
            pixels = np.concatenate([pixels, self.alpha[..., None]], axis=-1)
        write_png(path, pixels)


def bilinear(image: np.ndarray, x, y) -> np.ndarray:
    """The picture's colour between its pixels (x and y in pixels, 0 at the first pixel's
    centre)."""
    rows, columns = image.shape[:2]
    x = np.clip(x, 0.0, columns - 1.0)
    y = np.clip(y, 0.0, rows - 1.0)
    x0, y0 = np.floor(x).astype(int), np.floor(y).astype(int)
    x1, y1 = np.minimum(x0 + 1, columns - 1), np.minimum(y0 + 1, rows - 1)
    fx, fy = (x - x0)[:, None], (y - y0)[:, None]
    top = image[y0, x0] * (1 - fx) + image[y0, x1] * fx
    bottom = image[y1, x0] * (1 - fx) + image[y1, x1] * fx
    return top * (1 - fy) + bottom * fy


def write_png(path: Path, pixels: np.ndarray) -> None:
    """An 8-bit RGB or RGBA PNG, as build_rig_models.py's write_png but with each row stored as
    its difference to the row above or to the pixel before (PNG's "up" and "sub" filters,
    whichever packs smaller): flat colours and gradients take far less room. Also writes the
    texture's Godot import settings when it has none yet (mipmaps on: a print shimmers at a
    distance without them; compressed for the graphics card)."""
    height, width, channels = pixels.shape
    data = pixels.astype(np.int16)
    up = np.empty_like(data)
    up[0] = data[0]
    up[1:] = data[1:] - data[:-1]
    sub = np.empty_like(data)
    sub[:, 0] = data[:, 0]
    sub[:, 1:] = data[:, 1:] - data[:, :-1]
    best = None
    for filter_type, rows in ((2, up), (1, sub)):
        raw = b"".join(bytes([filter_type]) + (rows[r] % 256).astype(np.uint8).tobytes() for r in range(height))
        packed = zlib.compress(raw, 9)
        if best is None or len(packed) < len(best):
            best = packed

    def chunk(tag: bytes, body: bytes) -> bytes:
        return struct.pack(">I", len(body)) + tag + body + struct.pack(">I", zlib.crc32(tag + body) & 0xFFFFFFFF)

    colour_type = 6 if channels == 4 else 2
    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, colour_type, 0, 0, 0))
    png += chunk(b"IDAT", best) + chunk(b"IEND", b"")
    path.write_bytes(png)
    settings = path.with_name(path.name + ".import")
    if not settings.exists():
        settings.write_text('[remap]\n\nimporter="texture"\ntype="CompressedTexture2D"\n\n[params]\n\n'
                            'compress/mode=2\nmipmaps/generate=true\n', encoding="utf-8")
    shown = path.relative_to(rig.REPO) if path.is_relative_to(rig.REPO) else path
    print(f"Wrote {shown} ({len(png) // 1024} KB)")


# --------------------------------------------------------------------------------------------
# The boards.
# --------------------------------------------------------------------------------------------

class Board:
    """A board's picture grid and the parts of its shape the painters need, in metres."""

    def __init__(self, item: dict, geometry):
        width_px, height_px = BOARD_PICTURE
        self.item = item
        self.X, self.T = geometry.grid(width_px, height_px)
        self.length, self.width = geometry.length, geometry.width
        self.pixel = max(2.0 * geometry.uv_half_span / width_px, geometry.length / height_px)
        rows_t = self.T[:, 0]
        self.half = np.array([geometry.half_width(float(t)) for t in rows_t])[:, None]
        self.bottom_half = np.array([geometry.bottom_half_width(float(t)) for t in rows_t])[:, None]
        self.half_width = geometry.half_width
        self.bottom_half_width = geometry.bottom_half_width
        self.track = geometry.mast_track
        self.straps = geometry.straps
        self.pads = geometry.pads
        self.steps = geometry.steps
        self.front_strap_t = self.straps[0][1]
        self.back_strap_t = self.straps[2][1]

    def picture(self, base) -> Picture:
        return Picture(self.X, self.T, base, self.pixel)

    def from_rail(self):
        """How far in from the deck's rail each pixel is, m (negative outside the board)."""
        return self.half - np.abs(self.X)

    def shelf(self):
        """The cut-outs' shelves on the bottom: between the planing bottom's edge and the rail."""
        return (np.abs(self.X) > self.bottom_half - 0.003) & (self.T < self.steps[-1])

    def inboard(self, t: float, margin: float) -> float:
        """The half width at t less a margin, m."""
        return self.half_width(t) - margin

    def size_text(self) -> str:
        return f"{self.item['size']}"

    def dimensions_text(self) -> str:
        c = self.item["config"]
        return f"V{self.item['size']} L{round(c['length_m'] * 100)} W{round(c['width_m'] * 100)}"


# The deck pads' top and edge, per brand: a colour of the brand's (by name) or a hex code.
PAD_COLOURS = {
    "moonboard": ("secondary", "accent"),
    "pj_new_sealand": ("grey", "accent"),
    "tripletone": ("accent", "secondary"),
    "bmx_boards": ("#1C1C1C", "accent"),
    "forbidden": ("secondary", "accent"),
    "savanna": ("#2B2420", "accent"),
}


def board_materials(item: dict) -> dict:
    """The colours of the board's parts that are not painted with the pictures: the deck pads
    (their top and their edge) and the hull's fallback colours."""
    brand = read_brand(item["livery"])
    top, edge = PAD_COLOURS[item["livery"]]
    pads = [brand[name] if name in brand else colour(name) for name in (top, edge)]
    return {
        "deck_pad": material(pads[0], 0.95),
        "pad_edge": material(pads[1], 0.8),
        "pad_dark": material(BLACK, 0.95),
        "board_deck": material(brand["primary"], 0.45),
        "board_bottom": material(brand.get("bottom", brand["secondary"]), 0.35),
    }


def draw_board_pictures(item: dict, geometry, deck_path: Path, bottom_path: Path) -> None:
    board = Board(item, geometry)
    brand = read_brand(item["livery"])
    deck, bottom = BOARD_PAINTERS[item["livery"]]
    picture = board.picture(brand["primary"])
    deck(picture, board, brand)
    picture.save(deck_path)
    picture = board.picture(brand.get("bottom", brand["secondary"]))
    bottom(picture, board, brand)
    picture.save(bottom_path)


def streaks(board: Board, seed: float, along: float = 2.0, across: float = 38.0):
    """Smooth lengthwise veins (0 to 1), like pigment marbled in the resin: a few waves along the
    board, bent by slower ones (our own pattern, not noise, so the picture stays small)."""
    X, T = board.X, board.T
    bend = 0.035 * np.sin(T * along + seed) + 0.02 * np.sin(T * 3.7 * along + 2.0 * seed)
    wave = np.sin((X + bend) * across + seed) * np.sin((X - 0.5 * bend) * 0.61 * across + 1.7 * seed)
    return rig.smoothstep(0.55, 0.95, wave)


def tail_number(picture: Picture, board: Board, t: float, cap: float, fill, outline=None, mirror=False) -> None:
    """The board's size in big numbers across the tail, optionally outlined."""
    text = board.size_text()
    if outline is not None:
        picture.text(text, (0.0, t), cap, outline, mirror=mirror, bold=0.13)
    picture.text(text, (0.0, t), cap, fill, mirror=mirror, bold=0.05)


def along_board(picture: Picture, text: str, x: float, t: float, cap: float, rgb, mirror=False, **style) -> None:
    """Text running along the board from the tail toward the nose (read from the starboard side,
    the nose to the right) on the deck; mirrored, on the bottom (read from below)."""
    picture.text(text, (x, t), cap, rgb, angle_deg=90.0, mirror=mirror, **style)


def paint_pad_outlines(picture: Picture, board: Board, width: float, rgb) -> None:
    """A line around each deck pad, on the deck (it shows as a frame round the pad)."""
    for outline, mirrored in board.pads:
        for sign in ((-1.0, 1.0) if mirrored else (1.0,)):
            points = [(sign * x, t) for x, t in outline]
            distance = np.abs(polygon_distance(board.X, board.T, points))
            picture.shape(distance - 0.5 * width, rgb)


def hexagon_outline(picture: Picture, centre, radius: float, width: float, rgb) -> None:
    points = [(centre[0] + radius * math.cos(math.radians(a)), centre[1] + radius * math.sin(math.radians(a)))
              for a in range(0, 360, 60)]
    picture.shape(np.abs(polygon_distance(picture.X, picture.Y, points)) - 0.5 * width, rgb)


def rounded_box(picture: Picture, centre, half_x: float, half_t: float, radius: float):
    """The signed distance to a rounded rectangle."""
    qx = np.abs(picture.X - centre[0]) - (half_x - radius)
    qt = np.abs(picture.Y - centre[1]) - (half_t - radius)
    outside = np.hypot(np.maximum(qx, 0.0), np.maximum(qt, 0.0))
    return outside + np.minimum(np.maximum(qx, qt), 0.0) - radius


# --- Moonboard: sporty midnight blue, two cream racing stripes from the nose, a yellow tail with
# the size in big outlined numbers, the mark on a yellow tab on the nose's port side; a sky-blue
# bottom with yellow tips and the name along it.
def moonboard_deck(p: Picture, b: Board, c: dict) -> None:
    X, T = b.X, b.T
    band = rig.smoothstep(0.30, 0.42, T) * (1.0 - rig.smoothstep(0.70, 0.82, T))
    p.paint(0.45 * band, c["primary"] * 0.55)
    start, end = b.track[1] + 0.05, b.length - 0.07
    share = np.clip((T - start) / (end - start), 0.0, 1.0)
    for side in (-1.0, 1.0):
        centre = side * (0.032 + 0.055 * (1.0 - share))
        half = 0.010 + 0.016 * (1.0 - share)
        inside = (T > start) & (T < end)
        p.shape(np.where(inside, np.abs(X - centre) - half, 1.0), c["secondary"])
    edge = 0.60 + 0.08 * (X / np.maximum(b.half, 0.05)) ** 2
    p.shape(T - edge, c["accent"])
    tail_number(p, b, 0.505, 0.085, c["primary"], outline=c["secondary"])
    tab = (-0.055, b.length - 0.21)
    p.shape(rounded_box(p, tab, 0.05, 0.07, 0.015), c["accent"])
    p.stamp(logo("moonboard", "mark"), tab, 0.085)
    p.stamp(logo("moonboard", "wordmark"), (0.0, b.track[1] + 0.31), 0.44, angle_deg=90.0)
    along_board(p, b.item["model_name"], -0.06, 1.10, 0.03, c["secondary"], bold=0.04)


def moonboard_bottom(p: Picture, b: Board, c: dict) -> None:
    T = b.T
    p.shape(b.length - 0.26 - T, c["accent"])
    p.shape(T - 0.05, c["accent"])
    p.paint(b.shelf(), c["accent"])
    # The small triangle between the cut-outs (the 2026 boards' stabiliser), darker.
    triangle = [(-0.035, 0.0), (0.035, 0.0), (0.0, 0.16)]
    p.shape(polygon_distance(b.X, T, triangle), c["disc"])
    p.stamp(logo("moonboard", "wordmark"), (0.0, b.length - 0.80), 0.62, angle_deg=90.0, mirror=True)
    p.stamp(logo("moonboard", "mark"), (0.0, b.length - 0.15), 0.11, mirror=True)
    tail_number(p, b, 0.28, 0.07, c["primary"], mirror=True)


# --- PJ New Sealand: a white deck, the tail split teal (port) and fern green (starboard) as the
# brand it is named after splits its tail; a pale recess round the mast track; "PJ" on the nose;
# the model's name and its numbers on the tail; a white bottom with teal rails and the name
# along it.
def pj_deck(p: Picture, b: Board, c: dict) -> None:
    X, T = b.X, b.T
    p.paint(0.5 * rig.smoothstep(1.6, b.length, T), c["grey"] * 0.97)
    tail = 1.0 - rig.smoothstep(0.68, 0.80, T)
    halves = np.where((X < 0.0)[..., None], c["secondary"], c["accent"])
    halves = halves + (c["secondary"] * 0.7 - halves) * (1.0 - rig.smoothstep(0.08, 0.16, T))[..., None]
    p.rgb += (halves - p.rgb) * tail[..., None]
    middle = 0.5 * (b.track[0] + b.track[1])
    ring = np.hypot(X / 0.11, (T - middle) / 0.21)
    p.paint(1.0 - rig.smoothstep(0.92, 1.0, ring), c["grey"])
    p.paint(rig.smoothstep(0.93, 1.0, ring) * (1.0 - rig.smoothstep(1.0, 1.07, ring)), c["secondary"])
    p.text("PJ", (0.0, b.length - 0.36), 0.10, c["secondary"], bold=0.05, italic=0.25)
    along_board(p, b.item["model_name"].upper(), -0.075, 0.57, 0.032, WHITE, bold=0.04)
    along_board(p, b.dimensions_text(), 0.075, 0.57, 0.024, c["slate"], bold=0.03)
    p.stamp(logo("pj_new_sealand", "wordmark"), (b.inboard(1.75, 0.13), 1.75), 0.42, angle_deg=90.0)


def pj_bottom(p: Picture, b: Board, c: dict) -> None:
    T = b.T
    p.paint(1.0 - rig.smoothstep(0.5, 0.9, T), c["secondary"])
    p.paint((b.from_rail() < 0.03) * (1.0 - rig.smoothstep(0.8, 1.4, T)), c["secondary"])
    p.paint(b.shelf(), c["accent"])
    p.shape(T - 0.045, c["accent"])
    p.stamp(logo("pj_new_sealand", "wordmark"), (0.0, b.length - 0.72), 0.62, angle_deg=90.0, mirror=True)


# --- Tripletone: carbon with aqua veins along the board, the tail stepped in the mark's three
# tones (light at the very tail), white diamonds under the front straps and one black wedge across
# the tail, the three-tone mark big on the nose; a royal-blue bottom with the name along it and
# aqua steps.
def tripletone_deck(p: Picture, b: Board, c: dict) -> None:
    X, T = b.X, b.T
    p.paint(0.55 * streaks(b, 1.3), c["tones"][0])
    p.paint(0.35 * streaks(b, 4.1, across=61.0), c["secondary"])
    # The three tones, each a band with a stepped front edge ("pixels" 6 cm wide).
    steps = 0.035 * (np.floor(np.abs(X) / 0.06) % 2)
    for front, tone in ((0.98, c["tones"][0]), (0.68, c["tones"][1]), (0.38, c["tones"][2])):
        p.shape(T - (front + steps), tone)
    p.stamp(logo("tripletone", "mark"), (0.0, b.length - 0.26), 0.16)
    p.stamp(logo("tripletone", "wordmark"), (0.0, b.track[1] + 0.32), 0.36, angle_deg=90.0)
    along_board(p, b.item["model_name"], 0.085, 0.5 * (b.track[0] + b.track[1]), 0.028, c["accent"])
    p.text(b.size_text(), (0.0, 0.52), 0.07, c["primary"], bold=0.03)


def tripletone_bottom(p: Picture, b: Board, c: dict) -> None:
    p.paint(b.shelf(), c["secondary"])
    p.shape(b.T - 0.03, c["secondary"])
    p.stamp(logo("tripletone", "wordmark"), (0.0, 0.5 * b.length + 0.05), 0.80, angle_deg=90.0, mirror=True)
    p.stamp(logo("tripletone", "mark"), (0.0, b.length - 0.30), 0.14, mirror=True)


# --- BMX Boards: one bold yellow, a forward-pointing chevron of thin black lines meeting ahead of
# the mast track, a black arrow panel behind the track under the front pads, the chainring on the
# nose's port side, the name beside the track, the model and its numbers on the tail, a red tail
# tip; a yellow bottom with the mark big at the nose, the name along it and the cut-out plates in
# black carbon with their screws.
def bmx_deck(p: Picture, b: Board, c: dict) -> None:
    X, T = b.X, b.T
    apex = b.track[1] + 0.30
    for offset in (0.0, 0.035, 0.07):
        for side in (-1.0, 1.0):
            back = apex - 0.62
            p.line((0.0, apex - offset), (side * b.half_width(back - offset), back - offset), 0.007, c["secondary"])
    tip, shoulder, tail_end = b.track[0] - 0.04, 0.99, 0.57
    arrow = [(0.0, tip), (b.inboard(shoulder, 0.02), shoulder), (b.inboard(tail_end, 0.02), tail_end),
             (0.0, tail_end + 0.08), (-b.inboard(tail_end, 0.02), tail_end), (-b.inboard(shoulder, 0.02), shoulder)]
    p.shape(polygon_distance(X, T, arrow), c["secondary"])
    p.shape(T - 0.045, c["accent"])
    p.stamp(logo("bmx_boards", "mark"), (-0.07, b.length - 0.40), 0.20)
    p.stamp(logo("bmx_boards", "wordmark"), (0.12, 0.5 * (b.track[0] + b.track[1])), 0.38, angle_deg=90.0)
    p.text(b.item["model_name"].upper(), (0.0, 0.505), 0.034, c["secondary"], bold=0.04, italic=0.2)
    c_ = b.item["config"]
    dims = f"{round(c_['length_m'] * 100)} - {round(c_['width_m'] * 100)} - {b.item['size']}"
    p.text(dims, (0.0, 0.455), 0.022, c["secondary"], bold=0.02)


def bmx_bottom(p: Picture, b: Board, c: dict) -> None:
    X, T = b.X, b.T
    shelf = b.shelf()
    p.paint(shelf, colour("#1E1F22"))
    # The plates' screws: a row along the middle of each shelf.
    for t in np.arange(0.03, b.steps[-1] - 0.02, 0.07):
        for side in (-1.0, 1.0):
            x = side * 0.5 * (b.half_width(float(t)) + b.bottom_half_width(float(t)))
            p.shape(np.hypot(X - x, T - t) - 0.006, colour("#9A9EA6"))
    p.shape(T - 0.03, c["accent"])
    p.stamp(logo("bmx_boards", "mark"), (0.0, b.length - 0.48), 0.34, mirror=True)
    p.stamp(logo("bmx_boards", "wordmark"), (0.0, 0.5 * b.length - 0.05), 0.72, angle_deg=90.0, mirror=True)


# --- Forbidden: signal red, deeper across the middle, black hexagon pads framed in bone, bone
# hexagon outlines on the nose and between the front straps, the no-entry mark on the nose, the
# model and its size by the tail rail; a red bottom with the name big near the nose and bone
# cut-out steps.
def forbidden_deck(p: Picture, b: Board, c: dict) -> None:
    X, T = b.X, b.T
    centre = (1.0 - np.abs(X) / np.maximum(b.half, 0.05)) * np.exp(-((T - 0.48 * b.length) / (0.32 * b.length)) ** 2)
    p.paint(0.75 * rig.smoothstep(0.1, 0.9, centre), c["crimson"])
    paint_pad_outlines(p, b, 0.012, c["accent"])
    nose = b.length - 0.40
    for dx, dt, radius in ((0.115, 0.05, 0.045), (-0.11, -0.03, 0.04), (0.085, -0.10, 0.03), (-0.07, 0.10, 0.03)):
        hexagon_outline(p, (dx, nose + dt), radius, 0.006, c["accent"])
    for dx, dt, radius in ((0.0, 0.0, 0.045), (0.0, 0.10, 0.03)):
        hexagon_outline(p, (dx, b.front_strap_t + dt), radius, 0.006, c["accent"])
    p.stamp(logo("forbidden", "mark"), (0.0, nose), 0.17)
    p.stamp(logo("forbidden", "wordmark"), (0.0, b.track[1] + 0.22), 0.32, angle_deg=90.0)
    text = f"{b.item['model_name'].upper()} {b.size_text()}"
    along_board(p, text, -b.inboard(1.25, 0.05), 1.25, 0.036, c["accent"], bold=0.05)


def forbidden_bottom(p: Picture, b: Board, c: dict) -> None:
    p.paint(b.shelf(), c["accent"])
    p.shape(b.T - 0.03, c["secondary"])
    p.stamp(logo("forbidden", "wordmark"), (0.0, b.length - 0.62), 0.58, angle_deg=90.0, mirror=True)
    for dx, dt, radius in ((0.0, 0.0, 0.07), (0.11, 0.09, 0.05), (-0.10, 0.11, 0.045)):
        hexagon_outline(p, (dx, 0.55 + dt), radius, 0.008, c["accent"])


# --- Savanna: terracotta with darker veins, the model's name in big outlined gold letters along
# the deck ahead of the mast track, the mark on a brown tab on the nose's port side, an acacia-
# brown tail with the size in gold; a brown bottom with a striped gold chevron on the nose and the
# name along it.
def savanna_deck(p: Picture, b: Board, c: dict) -> None:
    X, T = b.X, b.T
    p.paint(0.45 * streaks(b, 2.2, along=1.5, across=30.0), c["dark"])
    p.shape(T - 0.50, c["secondary"])
    name = b.item["model_name"].upper()
    cap = 0.08
    middle = 0.5 * (b.track[1] + 0.08 + b.length - 0.30)
    along_board(p, name, 0.0, middle, cap, c["accent"], bold=0.09)
    along_board(p, name, 0.0, middle, cap, c["primary"], bold=0.0)
    tab = (-0.05, b.length - 0.19)
    p.shape(rounded_box(p, tab, 0.05, 0.065, 0.015), c["secondary"])
    p.stamp(logo("savanna", "mark"), tab, 0.085)
    p.text(b.size_text(), (0.0, 0.45), 0.07, c["accent"], bold=0.03)
    p.stamp(logo("savanna", "wordmark"), (0.0, 1.07), 0.34, angle_deg=90.0)


def savanna_bottom(p: Picture, b: Board, c: dict) -> None:
    T = b.T
    p.paint(b.shelf(), c["primary"])
    p.shape(T - 0.03, c["primary"])
    apex = b.length - 0.22
    for offset in (0.0, 0.07, 0.14):
        for side in (-1.0, 1.0):
            back = apex - 0.30
            p.line((0.0, apex - offset), (side * b.inboard(back - offset, 0.03), back - offset), 0.03, c["accent"])
    p.stamp(logo("savanna", "wordmark"), (0.0, 0.5 * b.length + 0.05), 0.62, angle_deg=90.0, mirror=True)
    p.text(b.size_text(), (0.0, 0.30), 0.08, c["accent"], mirror=True, bold=0.03)


BOARD_PAINTERS = {
    "moonboard": (moonboard_deck, moonboard_bottom),
    "pj_new_sealand": (pj_deck, pj_bottom),
    "tripletone": (tripletone_deck, tripletone_bottom),
    "bmx_boards": (bmx_deck, bmx_bottom),
    "forbidden": (forbidden_deck, forbidden_bottom),
    "savanna": (savanna_deck, savanna_bottom),
}


# --------------------------------------------------------------------------------------------
# The sails.
# --------------------------------------------------------------------------------------------

class Sail:
    """A sail's picture grid and the parts of its shape the painters need."""

    def __init__(self, item: dict, geometry):
        width_px, height_px = SAIL_PICTURE
        self.item = item
        self.g = geometry
        self.X, self.Y, self.U, chord = geometry.grid(width_px, height_px)
        self.V = np.broadcast_to((1.0 - (np.arange(height_px) + 0.5) / height_px)[:, None], self.X.shape)
        self.chord = chord                        # the row's length, m (one value per pixel row)
        self.from_edge = (1.0 - self.U) * chord   # m from the leech or the foot along the row
        self.pixel = 2.5 * geometry.luff_h / height_px
        self.batten_v = [luff for luff, _ in geometry.shape["battens"]]
        self.boom_m, self.boom_height = geometry.boom_m, geometry.boom_height
        self.clew = (geometry.boom_m, geometry.boom_height)
        self.luff_h = geometry.luff_h

    def picture(self, base) -> Picture:
        return Picture(self.X, self.Y, base, self.pixel, alpha=OWN)

    def height(self, share: float) -> float:
        """The height on the luff of a share of it, m."""
        return self.g.drawing_y(share)

    def leech_x(self, y: float) -> float:
        return float(self.g.leech_x(np.array([y]))[0])

    def size_text(self) -> str:
        return f"{self.item['size']:.1f}"

    def scale(self) -> float:
        """The sail's luff over a 4.9 m luff: graphics grow with the sail."""
        return self.luff_h / 4.69


def sail_materials(item: dict) -> dict:
    """The cloth's own colour (the brand's primary: the reference a race's tint replaces) and the
    luff sleeve's colour."""
    brand = read_brand(item["livery"])
    sleeve = {"tripletone": brand["secondary"], "savanna": brand["primary"] * 0.85, "point9": brand["primary"],
              "nielstrots": brand["primary"], "southsails": brand["primary"], "s3kauai": BLACK,
              "gg_sails": brand["secondary"]}[item["livery"]]   # (every value is a ready colour)
    return {"sail_cloth": material(brand["primary"], 0.5), "sail_sleeve": material(sleeve, 0.55)}


def sail_clear_film(geometry):
    """The sail's clear film as a function of (U, V) arrays (True where clear): what the cloth's
    mesh makes of window cells and what the picture paints clear."""
    windows = SAIL_WINDOWS[geometry.item["livery"]]

    def clear(U, V):
        U, V = np.asarray(U, dtype=float), np.asarray(V, dtype=float)
        film = np.zeros(np.broadcast(U, V).shape, dtype=bool)
        for u0, u1, v0, v1 in windows(geometry):
            film |= (U > u0) & (U < u1) & (V > v0) & (V < v1)
        return film
    return clear


def boom_v(geometry, below: float = 0.0) -> float:
    """The clew's batten's share of the luff (the row that ends at the clew), less `below`."""
    for luff, leech in geometry.shape["battens"]:
        if leech == "clew":
            return luff - below
    return 0.24 - below


# Each brand's windows: (U from, U to, V from, V to) boxes of clear film.
SAIL_WINDOWS = {
    "tripletone": lambda g: [(0.17, 0.60, 0.09, boom_v(g, 0.035))],
    "savanna": lambda g: [(0.12, 0.27, 0.13, boom_v(g, -0.08))],
    "point9": lambda g: [(0.16, 0.56, 0.12, boom_v(g, 0.04))],
    "nielstrots": lambda g: [(0.27, 0.93, 0.172, boom_v(g, 0.012))],
    "southsails": lambda g: [(0.16, 0.42, 0.12, boom_v(g, 0.04)), (0.48, 0.80, 0.12, boom_v(g, 0.04))],
    "s3kauai": lambda g: [(0.15, 0.78, 0.168, boom_v(g, 0.045))],
    "gg_sails": lambda g: [(0.86, 0.985, 0.17, boom_v(g, -0.10)), (0.16, 0.42, 0.17, boom_v(g, 0.04))],
}


def draw_sail_picture(item: dict, geometry, path: Path) -> None:
    sail = Sail(item, geometry)
    brand = read_brand(item["livery"])
    picture = sail.picture(brand["primary"])
    SAIL_PAINTERS[item["livery"]](picture, sail, brand)
    picture.save(path)


def paint_clear_film(p: Picture, s: Sail, frame: float = 0.0, frame_rgb=None) -> None:
    """The windows: clear film, with a printed frame `frame` m wide round each if asked."""
    film = sail_clear_film(s.g)
    clear = film(s.U, s.V)
    if frame > 0.0:
        du, dv = frame / np.maximum(s.chord, 0.1), frame / s.luff_h
        grown = film(s.U + du, s.V) | film(s.U - du, s.V) | film(s.U, s.V + dv) | film(s.U, s.V - dv)
        p.paint(grown & ~clear, frame_rgb, PRINT)
    p.paint(clear, CLEAR, FILM)


def batten_pockets(p: Picture, s: Sail, rgb, width: float = 0.032, tip_rgb=None) -> None:
    """The full battens' pockets from just behind the sleeve to the leech, with a cap at the
    leech end."""
    for a, b in s.g.battens:
        start = a + np.array([0.20, 0.0])
        p.line(start, b, width, rgb, PRINT)
        if tip_rgb is not None:
            direction = (b - start) / np.linalg.norm(b - start)
            p.line(b - 0.07 * direction, b, width + 0.008, tip_rgb, PRINT)


def leech_tape(p: Picture, s: Sail, rgb, width: float = 0.03) -> None:
    p.paint(s.from_edge < width, rgb, PRINT)


def clew_and_head(p: Picture, s: Sail, rgb) -> None:
    """The clew's reinforcing patch, the head's cap and the tack's patch."""
    p.shape(np.hypot(s.X - s.clew[0], s.Y - s.clew[1]) - 0.15, rgb, PRINT)
    p.shape(np.hypot(s.X, s.Y - s.g.top_y) - 0.10, rgb, PRINT)
    p.shape(np.hypot(s.X, s.Y - s.g.tack_y) - 0.12, rgb, PRINT)


def number_boxes(p: Picture, s: Sail, box_rgb, letter_rgb, start: float = 0.36) -> None:
    """The sail numbers' boxes, as on the default sail (build_rig_models.py: a race sail carries
    them on both sides, the starboard one higher): each printed on its own side, the starboard one
    mirrored to read from behind. Ours say MMZB, as large as fits the box. `start` is the boxes'
    front edge, m from the mast, on a 2.2 m boom."""
    chord_scale = s.boom_m / 2.2
    for low, high, alpha, mirrored in ((0.433, 0.513, FRONT_PRINT, False), (0.565, 0.645, BACK_PRINT, True)):
        x0, x1 = start * chord_scale, 1.28 * chord_scale
        y0, y1 = s.height(low), s.height(high)
        x1 = min(x1, s.leech_x(y1) - 0.12)
        box = np.maximum(np.maximum(x0 - s.X, s.X - x1), np.maximum(y0 - s.Y, s.Y - y1))
        p.shape(box, box_rgb, alpha)
        cap = 0.62 * (y1 - y0)
        cap *= min(1.0, 0.88 * (x1 - x0) / p.text_width("MMZB", cap, bold=0.04))
        p.text("MMZB", (0.5 * (x0 + x1), 0.5 * (y0 + y1)), cap, letter_rgb, mirror=mirrored, bold=0.04, alpha=alpha)


def leech_direction(s: Sail, y0: float, y1: float) -> float:
    """The angle (degrees from +X toward +Y) of the leech from y1 down to y0."""
    dx = s.leech_x(y0) - s.leech_x(y1)
    return math.degrees(math.atan2(y0 - y1, dx))


def size_near_clew(p: Picture, s: Sail, rgb, below: float = 0.24, cap: float = 0.10, inset: float = 0.32) -> None:
    """The sail's size, printed just under the clew."""
    y = s.boom_height - below * s.scale()
    p.text(s.size_text(), (s.leech_x(y) - inset * s.scale(), y), cap * s.scale(), rgb, bold=0.03, alpha=PRINT)


# Where the low prints go: just above the lowest batten. Under it the cloth's rows fan out from
# the tack (build_rig_models.py), so the picture has few pixels across the foot and a print there
# blurs; above it the rows run from the luff to the leech and the picture is sharp.
LOW_PRINT_V = 0.137


def row_place(s: Sail, u: float, v: float) -> tuple:
    """The point `u` of the way along the row that starts `v` up the luff, and the row's angle in
    degrees (prints placed with it run along the battens)."""
    luff, outer = rig.luff_point(v), rig.outer_point(v)
    point = luff + u * (outer - luff)
    return (float(point[0]), float(point[1])), math.degrees(math.atan2(outer[1] - luff[1], outer[0] - luff[0]))


# --- Tripletone: an aqua luff sleeve, leech and foot; a carbon upper body with a staircase of
# square "pixels" in the mark's three tones; a white lower body with a clear window; the name in
# tall letters down the leech; the model low by the leech, the size under the clew.
def tripletone_sail(p: Picture, s: Sail, c: dict) -> None:
    X, Y, V = s.X, s.Y, s.V
    lower = V < s.batten_v[4]
    p.paint(lower, c["accent"], PRINT)
    paint_clear_film(p, s, 0.03, c["primary"])
    # The pixels: squares climbing toward the head, in the three tones from dark to light.
    q, gap = 0.17 * s.scale(), 0.025 * s.scale()
    base_y = s.height(0.665)
    for row in range(6):
        for col in range(row + 1):
            x0 = 0.30 + col * (q + gap)
            y0 = base_y + row * (q + gap)
            if x0 + q > s.leech_x(y0 + q) - 0.10 or y0 + q > s.height(0.93):
                continue
            tone = c["tones"][min(2, (row + col) // 3)]
            box = np.maximum(np.maximum(x0 - X, X - (x0 + q)), np.maximum(y0 - Y, Y - (y0 + q)))
            p.shape(box, tone, PRINT)
    number_boxes(p, s, c["accent"], c["primary"])
    batten_pockets(p, s, c["tones"][0])
    leech_tape(p, s, c["secondary"], 0.035)
    clew_and_head(p, s, c["secondary"])
    top, bottom = s.height(0.86), s.boom_height + 0.25
    middle = 0.5 * (top + bottom)
    length = min(0.92 * (top - bottom), 1.6 * s.scale())
    p.stamp(logo("tripletone", "wordmark"), (s.leech_x(middle) - 0.21 * s.scale(), middle), length,
            angle_deg=leech_direction(s, bottom, top), alpha=PRINT)
    place, angle = row_place(s, 0.78, LOW_PRINT_V)
    p.text(s.item["model_name"], place, 0.07 * s.scale(), c["primary"], angle_deg=angle, bold=0.04, alpha=PRINT)
    size_near_clew(p, s, c["primary"])


# --- Savanna: all terracotta, translucent, with thin dark strips in the luff panel and dark
# battens; the name big over the leech above the boom; the mark on a brown badge mid-sail by the
# luff; the size in huge outlined figures low in the sail with the model's name beside it.
def savanna_sail(p: Picture, s: Sail, c: dict) -> None:
    X, Y = s.X, s.Y
    for x in np.arange(0.24, 0.48, 0.045):
        p.paint((np.abs(X - x) < 0.0045) & (Y > s.g.tack_y + 0.1) & (s.V < 0.86), c["secondary"], PRINT)
    paint_clear_film(p, s, 0.025, c["secondary"])
    number_boxes(p, s, BLACK, c["cream"])
    batten_pockets(p, s, c["secondary"])
    leech_tape(p, s, c["secondary"], 0.025)
    clew_and_head(p, s, c["secondary"])
    y = s.boom_height + 0.52 * s.scale()
    width = 1.15 * s.scale()
    p.stamp(logo("savanna", "wordmark"), (s.leech_x(y) - 0.5 * width - 0.08, y), width, angle_deg=12.0, alpha=PRINT)
    badge = (0.42, s.height(0.72))
    p.shape(rounded_box(p, badge, 0.14 * s.scale(), 0.14 * s.scale(), 0.03), c["secondary"], PRINT)
    p.stamp(logo("savanna", "mark"), badge, 0.22 * s.scale(), alpha=PRINT)
    place, angle = row_place(s, 0.58, 0.5 * (s.batten_v[-1] + s.batten_v[-2]))
    cap = 0.26 * s.scale()
    p.text(s.size_text(), place, cap, c["secondary"], angle_deg=angle, bold=0.06, alpha=PRINT)
    p.text(s.size_text(), place, cap, c["primary"], angle_deg=angle, bold=-0.005, alpha=OWN)
    place, angle = row_place(s, 0.86, LOW_PRINT_V)
    p.text(s.item["model_name"].upper(), place, 0.05 * s.scale(), c["secondary"], angle_deg=angle, bold=0.03,
           alpha=PRINT)


# --- Point.9: smoke black film, pearl blocks stepping down toward the leech near the head, a
# pearl strip along the foot, a grey window, a lime line along the luff panel and magenta batten
# caps; the name near the clew, the model low by the leech, the size under the clew.
def point9_sail(p: Picture, s: Sail, c: dict) -> None:
    U, V = s.U, s.V
    v = s.batten_v
    for (u0, v0, v1) in ((0.10, v[1] + 0.012, 0.985), (0.42, v[2] + 0.012, v[1] - 0.012)):
        p.paint((U > u0) & (U < 0.97) & (V > v0) & (V < v1), c["pearl"], PRINT)
    p.paint((s.from_edge < 0.07) & (V < v[-1]), c["pearl"], PRINT)
    paint_clear_film(p, s, 0.02, c["smoke"])
    p.paint(np.abs(s.X - 0.30) < 0.005, c["secondary"], PRINT)
    number_boxes(p, s, c["pearl"], c["primary"])
    batten_pockets(p, s, c["smoke"], tip_rgb=c["accent"])
    leech_tape(p, s, c["smoke"], 0.02)
    clew_and_head(p, s, c["smoke"])
    y = s.boom_height + 0.33 * s.scale()
    width = 0.80 * s.scale()
    p.stamp(logo("point9", "wordmark"), (s.leech_x(y) - 0.5 * width - 0.15, y), width, alpha=PRINT)
    place, angle = row_place(s, 0.72, LOW_PRINT_V)
    p.text(s.item["model_name"], place, 0.06 * s.scale(), c["pearl"], angle_deg=angle, bold=0.03, alpha=PRINT)
    size_near_clew(p, s, c["pearl"])


# --- NielsTrots: black, the upper body printed with crimson rings like a target that turn orange
# toward the boom; the name in big letters up the black luff panel from the boom; a clear window
# band under the boom with the model's name; an orange foot, clew and head; the size on the foot.
# (The foot's prints sit just over the lowest batten: see LOW_PRINT_V.)
def nielstrots_sail(p: Picture, s: Sail, c: dict) -> None:
    X, Y, V = s.X, s.Y, s.V
    panel_x = 0.66 * s.scale()
    centre = (0.62 * s.boom_m, s.boom_height + 0.55 * (s.g.top_y - s.boom_height))
    radius = np.hypot(X - centre[0], (Y - centre[1]) * 0.9)
    rings = np.abs(((radius + 0.03) % 0.15) - 0.075) < 0.028
    warm = rig.smoothstep(s.boom_height + 1.6, s.boom_height + 0.2, Y)[..., None]
    ring_rgb = c["secondary"] + (c["accent"] - c["secondary"]) * warm
    fade = 1.0 - rig.smoothstep(s.g.top_y - 1.2, s.g.top_y - 0.2, Y)
    p.paint(rings * (X > panel_x) * (V > boom_v(s.g, 0.0)) * fade, ring_rgb[..., :], PRINT)
    p.paint(V < LOW_PRINT_V + 0.017, c["accent"], PRINT)
    paint_clear_film(p, s, 0.025, WHITE)
    number_boxes(p, s, WHITE, c["primary"], start=panel_x + 0.08)
    batten_pockets(p, s, c["secondary"])
    leech_tape(p, s, c["secondary"], 0.025)
    clew_and_head(p, s, c["accent"])
    # The name up the luff panel, as tall as the panel is wide (behind the sleeve, which hides the
    # first 0.2 m of the cloth).
    mark = logo("nielstrots", "wordmark")
    bottom, top = s.boom_height + 0.15, s.height(0.80)
    height = panel_x - 0.27
    length = min(1.7 * s.scale(), top - bottom, height * mark.shape[1] / mark.shape[0])
    height = length * mark.shape[0] / mark.shape[1]
    p.stamp(mark, (0.235 + 0.5 * height, bottom + 0.5 * length), length, angle_deg=90.0, alpha=PRINT)
    place, angle = row_place(s, 0.52, boom_v(s.g, 0.04))
    p.text(s.item["model_name"].upper(), place, 0.065 * s.scale(), c["primary"], angle_deg=angle, bold=0.03,
           italic=0.15, alpha=PRINT)
    place, angle = row_place(s, 0.72, LOW_PRINT_V)
    p.text(s.size_text(), place, 0.075 * s.scale(), c["primary"], angle_deg=angle, bold=0.04, alpha=PRINT)


# --- SouthSails: one smooth navy membrane with lighter fibre lines fanning from the clew and the
# head, no seams; coral lines along the battens; the compass mark on a white disc high by the
# luff; the name across the upper sail and the model small in the middle; white-framed windows in
# the lower panel; the size under the clew.
def southsails_sail(p: Picture, s: Sail, c: dict) -> None:
    X, Y = s.X, s.Y
    fibre = c["primary"] + (WHITE - c["primary"]) * 0.14
    for origin, angles in ((s.clew, np.linspace(100, 200, 7)), ((s.g.head[0], s.g.head[1]), np.linspace(210, 285, 5))):
        for angle in angles:
            a = math.radians(angle)
            end = (origin[0] + 6.0 * math.cos(a), origin[1] + 6.0 * math.sin(a))
            p.line(origin, end, 0.008, fibre, OWN)
    for a, b in s.g.battens:
        p.line(a + np.array([0.20, 0.0]), b, 0.010, c["secondary"], PRINT)
    paint_clear_film(p, s, 0.03, WHITE)
    number_boxes(p, s, WHITE, c["primary"])
    leech_tape(p, s, c["secondary"], 0.012)
    clew_and_head(p, s, c["primary"] * 0.7)
    disc = (0.42 * s.scale() + 0.12, s.height(0.80))
    p.shape(np.hypot(X - disc[0], Y - disc[1]) - 0.17 * s.scale(), WHITE, PRINT)
    p.stamp(logo("southsails", "mark"), disc, 0.30 * s.scale(), alpha=PRINT)
    y = s.height(0.71)
    width = min(0.95 * s.scale(), 0.75 * s.leech_x(y))
    p.stamp(logo("southsails", "wordmark"), (0.20 + 0.5 * width + 0.05, y), width, alpha=PRINT)
    y = s.boom_height + 0.42 * s.scale()
    p.text(s.item["model_name"].upper(), (0.5 * s.leech_x(y) + 0.1, y), 0.05 * s.scale(), WHITE, bold=0.03,
           spacing=1.2, alpha=PRINT)
    size_near_clew(p, s, WHITE)


# --- s3kauai: lagoon above, a coral band round the boom and a jungle-green band over it carrying
# the name; a white lower body with a clear window outlined in black; coral battens; a black
# strip behind the sleeve; the model's name across the foot; the size under the clew.
def s3kauai_sail(p: Picture, s: Sail, c: dict) -> None:
    X, V = s.X, s.V
    v_boom = boom_v(s.g, 0.0)
    p.paint(V < v_boom - 0.03, WHITE, PRINT)
    p.paint((V >= v_boom - 0.03) & (V < v_boom + 0.045), c["accent"], PRINT)
    p.paint((V >= v_boom + 0.06) & (V < v_boom + 0.17), c["secondary"], PRINT)
    p.paint(np.abs(V - (v_boom - 0.03)) < 0.0025, BLACK, PRINT)
    paint_clear_film(p, s, 0.02, BLACK)
    p.paint((X > 0.20) & (X < 0.25), BLACK, PRINT)
    number_boxes(p, s, BLACK, WHITE)
    batten_pockets(p, s, c["accent"])
    leech_tape(p, s, BLACK, 0.015)
    clew_and_head(p, s, BLACK)
    y = 0.5 * (s.height(v_boom + 0.06) + s.height(v_boom + 0.17)) + 0.04
    width = min(1.05 * s.scale(), 0.62 * s.leech_x(y))
    p.stamp(logo("s3kauai", "wordmark"), (0.30 + 0.5 * width, y), width, alpha=PRINT)
    place, angle = row_place(s, 0.45, LOW_PRINT_V)
    p.text(s.item["model_name"].upper(), place, 0.08 * s.scale(), BLACK, angle_deg=angle, bold=0.06, italic=0.2,
           alpha=PRINT)
    size_near_clew(p, s, BLACK)


# --- GG Sails: violet with a charcoal luff panel carrying the mark big under the head, seams
# radiating from the sail's middle, gold battens and gold tape along the leech and the foot, a
# clear strip along the lower leech, the name down the leech; a white foot panel with the model's
# name and three colour bars; the size under the clew.
def gg_sail(p: Picture, s: Sail, c: dict) -> None:
    X, Y, V = s.X, s.Y, s.V
    panel_x = 0.62 * s.scale()
    p.paint(X < panel_x, c["secondary"], PRINT)
    middle = (0.42 * s.boom_m, s.boom_height + 0.9 * s.scale())
    for angle in range(0, 360, 40):
        a = math.radians(angle + 7)
        p.line(middle, (middle[0] + 6 * math.cos(a), middle[1] + 6 * math.sin(a)), 0.006, c["primary"] * 0.78, OWN)
    p.paint((V < LOW_PRINT_V + 0.02) & (X > panel_x), WHITE, PRINT)
    paint_clear_film(p, s, 0.025, c["accent"])
    number_boxes(p, s, WHITE, c["secondary"])
    batten_pockets(p, s, c["accent"])
    leech_tape(p, s, c["accent"], 0.03)
    p.paint((s.from_edge < 0.03) & (V < s.batten_v[-1]), c["accent"], PRINT)
    clew_and_head(p, s, c["secondary"])
    y = s.height(0.80)
    diameter = 0.95 * s.scale()
    while 0.16 + diameter > s.leech_x(y + 0.5 * diameter) - 0.06 and diameter > 0.3:
        diameter *= 0.95
    p.stamp(logo("gg_sails", "mark"), (0.16 + 0.5 * diameter, y), diameter, alpha=PRINT)
    top, bottom = s.height(0.66), s.boom_height + 0.30
    middle_y = 0.5 * (top + bottom)
    length = min(0.95 * (top - bottom), 1.5 * s.scale())
    p.stamp(logo("gg_sails", "wordmark"), (s.leech_x(middle_y) - 0.20 * s.scale(), middle_y), length,
            angle_deg=leech_direction(s, bottom, top), alpha=PRINT)
    place, angle = row_place(s, 0.55, LOW_PRINT_V)
    p.text(s.item["model_name"].upper(), place, 0.07 * s.scale(), c["secondary"], angle_deg=angle, bold=0.04,
           alpha=PRINT)
    for i, rgb in enumerate((c["primary"], c["secondary"], c["accent"])):
        (bx, by), _ = row_place(s, 0.80 + 0.04 * i, LOW_PRINT_V)
        p.shape(np.maximum(np.abs(X - bx) - 0.018, np.abs(Y - by) - 0.05 * s.scale()), rgb, PRINT)
    size_near_clew(p, s, WHITE)


SAIL_PAINTERS = {
    "tripletone": tripletone_sail,
    "savanna": savanna_sail,
    "point9": point9_sail,
    "nielstrots": nielstrots_sail,
    "southsails": southsails_sail,
    "s3kauai": s3kauai_sail,
    "gg_sails": gg_sail,
}
