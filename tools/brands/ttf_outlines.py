"""The outlines of a line of text, read straight from a TrueType font file (.ttf), for
tools/brands/make_logos.py on a computer without Pango and cairo (Windows): the same job as its
text_path(), with plain Python and no extra packages.

A TrueType letter is a few closed outlines of points, each point on the outline or a control point
of a quadratic curve between two points on it. This reads them from the font's tables (cmap: the
letter's glyph number; loca and glyf: its points; hmtx: how far the pen moves after it; head: the
font's units), turns each quadratic curve into the cubic one SVG paths use, and lays the letters out
in a row. Kerning (the font's pair adjustments) is not applied: the wordmarks are capitals with
extra letter spacing, where it hardly shows.

    commands, advance = text_outline("START", "Open Sans", "ExtraBold", 200, tracking_em=0.05)

`commands` are ("M", [p]), ("L", [p]), ("C", [c1, c2, p]) and ("Z", []) with y pointing down and
the baseline at y = 0, as make_logos.Path keeps them.
"""

import os
import struct

# Where the fonts are looked for: Windows' own and the user's fonts, then the usual Linux folders.
FONT_DIRS = [
    os.path.join(os.environ.get("WINDIR", "C:/Windows"), "Fonts"),
    os.path.join(os.environ.get("LOCALAPPDATA", ""), "Microsoft", "Windows", "Fonts"),
    os.path.expanduser("~/.fonts"),
    os.path.expanduser("~/.local/share/fonts"),
    "/usr/share/fonts",
    "/usr/local/share/fonts",
]


def font_file(family: str, face: str) -> str:
    """The file of a font: "Open Sans" "ExtraBold" is OpenSans-ExtraBold.ttf."""
    wanted = f"{family.replace(' ', '')}-{face.replace(' ', '')}.ttf".lower()
    for folder in FONT_DIRS:
        if not folder or not os.path.isdir(folder):
            continue
        for root, _, files in os.walk(folder):
            for name in files:
                if name.lower() == wanted:
                    return os.path.join(root, name)
    raise SystemExit(f"Font not installed: {family} {face} (looked for {wanted})")


class Font:
    """The tables of one TrueType font that the outlines need."""

    def __init__(self, path: str):
        with open(path, "rb") as handle:
            self.data = handle.read()
        self.tables = {}
        count = struct.unpack_from(">H", self.data, 4)[0]
        for i in range(count):
            tag, _, offset, length = struct.unpack_from(">4sIII", self.data, 12 + 16 * i)
            self.tables[tag.decode("latin-1")] = (offset, length)
        head = self.tables["head"][0]
        self.units_per_em = struct.unpack_from(">H", self.data, head + 18)[0]
        self.long_loca = struct.unpack_from(">h", self.data, head + 50)[0] == 1
        self.glyph_count = struct.unpack_from(">H", self.data, self.tables["maxp"][0] + 4)[0]
        self.metric_count = struct.unpack_from(">H", self.data, self.tables["hhea"][0] + 34)[0]
        self.cmap = self._read_cmap()

    # --- Which glyph a letter is -------------------------------------------------------------

    def _read_cmap(self) -> dict:
        """Letter code -> glyph number, from the Windows Unicode subtable (format 4)."""
        base = self.tables["cmap"][0]
        count = struct.unpack_from(">H", self.data, base + 2)[0]
        for i in range(count):
            platform, encoding, offset = struct.unpack_from(">HHI", self.data, base + 4 + 8 * i)
            table = base + offset
            if platform == 3 and encoding == 1 and struct.unpack_from(">H", self.data, table)[0] == 4:
                return self._read_format4(table)
        raise SystemExit("The font has no Unicode letter table (cmap format 4)")

    def _read_format4(self, table: int) -> dict:
        segments = struct.unpack_from(">H", self.data, table + 6)[0] // 2
        ends_at = table + 14
        starts_at = ends_at + 2 * segments + 2
        deltas_at = starts_at + 2 * segments
        ranges_at = deltas_at + 2 * segments
        mapping = {}
        for s in range(segments):
            end = struct.unpack_from(">H", self.data, ends_at + 2 * s)[0]
            start = struct.unpack_from(">H", self.data, starts_at + 2 * s)[0]
            delta = struct.unpack_from(">h", self.data, deltas_at + 2 * s)[0]
            range_offset = struct.unpack_from(">H", self.data, ranges_at + 2 * s)[0]
            if start == 0xFFFF:
                continue
            for code in range(start, min(end, 0x2FFF) + 1):
                if range_offset == 0:
                    glyph = (code + delta) & 0xFFFF
                else:
                    at = ranges_at + 2 * s + range_offset + 2 * (code - start)
                    glyph = struct.unpack_from(">H", self.data, at)[0]
                    glyph = (glyph + delta) & 0xFFFF if glyph else 0
                mapping[code] = glyph
        return mapping

    # --- How far the pen moves after a glyph -------------------------------------------------

    def advance(self, glyph: int) -> int:
        index = min(glyph, self.metric_count - 1)
        return struct.unpack_from(">H", self.data, self.tables["hmtx"][0] + 4 * index)[0]

    # --- A glyph's outlines --------------------------------------------------------------------

    def _glyph_span(self, glyph: int):
        loca = self.tables["loca"][0]
        if self.long_loca:
            start, end = struct.unpack_from(">II", self.data, loca + 4 * glyph)
        else:
            start, end = (2 * v for v in struct.unpack_from(">HH", self.data, loca + 2 * glyph))
        return self.tables["glyf"][0] + start, end - start

    def contours(self, glyph: int) -> list:
        """The glyph's closed outlines, each a list of (x, y, on_curve) in font units (y up)."""
        at, length = self._glyph_span(glyph)
        if length == 0:
            return []  # a space
        count = struct.unpack_from(">h", self.data, at)[0]
        if count < 0:
            return self._composite(at + 10)
        ends = struct.unpack_from(f">{count}H", self.data, at + 10)
        point_count = ends[-1] + 1 if count else 0
        at += 10 + 2 * count
        instructions = struct.unpack_from(">H", self.data, at)[0]
        at += 2 + instructions
        flags = []
        while len(flags) < point_count:
            flag = self.data[at]
            at += 1
            flags.append(flag)
            if flag & 8:  # repeated
                repeat = self.data[at]
                at += 1
                flags.extend([flag] * repeat)
        xs, at = self._coordinates(flags, at, 2, 16)
        ys, at = self._coordinates(flags, at, 4, 32)
        result, first = [], 0
        for end in ends:
            result.append([(xs[i], ys[i], bool(flags[i] & 1)) for i in range(first, end + 1)])
            first = end + 1
        return result

    def _coordinates(self, flags, at, short_bit, same_bit):
        values, value = [], 0
        for flag in flags:
            if flag & short_bit:
                step = self.data[at]
                at += 1
                value += step if flag & same_bit else -step
            elif not flag & same_bit:
                value += struct.unpack_from(">h", self.data, at)[0]
                at += 2
            values.append(value)
        return values, at

    def _composite(self, at: int) -> list:
        """A glyph made of other glyphs, moved (an accented letter); scaled parts are not needed
        for the wordmarks' capitals and are drawn unscaled."""
        result = []
        while True:
            flags, part = struct.unpack_from(">HH", self.data, at)
            at += 4
            if flags & 1:
                dx, dy = struct.unpack_from(">hh", self.data, at)
                at += 4
            else:
                dx, dy = struct.unpack_from(">bb", self.data, at)
                at += 2
            if flags & 8:
                at += 2
            elif flags & 0x40:
                at += 4
            elif flags & 0x80:
                at += 8
            for contour in self.contours(part):
                result.append([(x + dx, y + dy, on) for x, y, on in contour])
            if not flags & 0x20:
                return result


def _contour_commands(points, place) -> list:
    """One closed TrueType outline as M, L, C and Z commands. Two control points in a row have an
    implied point on the curve halfway between them; each quadratic curve becomes a cubic one
    (its handles two thirds of the way to the control point)."""
    if not points:
        return []
    count = len(points)
    start = next((i for i in range(count) if points[i][2]), None)
    if start is None:  # every point a control point: start halfway between the first two
        a, b = points[0], points[1]
        ordered = [((a[0] + b[0]) / 2, (a[1] + b[1]) / 2, True)] + points[1:] + points[:1]
    else:
        ordered = points[start:] + points[:start]
    first = ordered[0]
    commands = [("M", [place(first)])]
    current = (first[0], first[1])
    control = None
    for x, y, on in ordered[1:] + [first]:
        if on:
            if control is None:
                commands.append(("L", [place((x, y))]))
            else:
                commands.append(_cubic(current, control, (x, y), place))
                control = None
            current = (x, y)
        else:
            if control is not None:
                middle = ((control[0] + x) / 2, (control[1] + y) / 2)
                commands.append(_cubic(current, control, middle, place))
                current = middle
            control = (x, y)
    commands.append(("Z", []))
    return commands


def _cubic(p0, control, p2, place):
    c1 = (p0[0] + 2 / 3 * (control[0] - p0[0]), p0[1] + 2 / 3 * (control[1] - p0[1]))
    c2 = (p2[0] + 2 / 3 * (control[0] - p2[0]), p2[1] + 2 / 3 * (control[1] - p2[1]))
    return ("C", [place(c1), place(c2), place(p2)])


_FONTS = {}


def text_outline(text: str, family: str, face: str, size: float, tracking_em: float = 0.0):
    """The outline commands of a line of text `size` units high (the font's em), its baseline at
    y = 0 and y pointing down, and the pen's advance (with `tracking_em` of the size after each
    letter, as Pango's letter spacing)."""
    key = (family, face)
    if key not in _FONTS:
        _FONTS[key] = Font(font_file(family, face))
    font = _FONTS[key]
    scale = size / font.units_per_em
    commands = []
    pen = 0.0
    for letter in text:
        glyph = font.cmap.get(ord(letter), 0)

        def place(p, dx=pen):
            return (dx + p[0] * scale, -p[1] * scale)

        for contour in font.contours(glyph):
            commands.extend(_contour_commands(contour, place))
        pen += font.advance(glyph) * scale + tracking_em * size
    return commands, pen
