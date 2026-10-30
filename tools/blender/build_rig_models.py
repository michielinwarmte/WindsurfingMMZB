"""Builds the 3D models of the windsurf equipment for the game (plan Phase 6, "Rig visuals"):
the board, the fin, the mast, the sail and the boom, from the numbers in Game/config/, in the
shape and colours of the real gear: the JP Australia Slalom S-TEC 72 and the Severne HGO
iQFOiL 8.0 (PH28 step 19; the sources are written at each part below).

Run it from the repository root, after changing a size in Game/config/ for example:

    tools/blender.sh tools/blender/build_rig_models.py

It writes into Game/assets/models/ (one .glb file per part, so each part can be placed on
its own; RigVisuals in Game/windsurfer/rig_visuals.gd puts them together):

    board.glb   The board: "Hull" (materials board_deck and board_bottom, which the game paints
                with board_deck.png and board_bottom.png), "DeckPads" (the EVA pads and the wedge),
                "Footstraps", "FinBox", "MastTrack". Origin: the centre of the board at
                mid-thickness, where the simulation has it. The bow points to Godot -Z, the deck up
                (+Y): the deck is at y = +thickness/2 at the mast foot.
    board_deck.png, board_bottom.png  The deck's and the bottom's colours, drawn here pixel by
                pixel in the hull's UV, which is the board seen from above: u across (port on the
                left), v along it (the nose at the top of the picture, the tail at the bottom).
    fin.glb     "Fin": a swept fin with a foil section. Origin: the fin root
                (FinConfig.root_local); the fin hangs down (-Y), the leading edge forward (-Z).
    mast.glb    "Mast": the mast with the extension and the rubber joint. Origin: the mast
                foot; the mast runs up +Y.
    sail.glb    "SailCloth": the sail as a dense grid, with three materials (surfaces):
                sail_cloth, sail_window (the clear film) and sail_sleeve (the luff sleeve around the
                mast); "SailClewRing" and "TackFairing". Origin: the mast foot; the luff runs up +Y
                along the mast and the boom along +X, so the clew is at (boom_m, boom_height_m, 0).
                The cloth is flat here: res://windsurfer/sail_cloth.gdshader bends it in the game
                (belly, twist, flutter, and the mast's bend). Its UV is (u, 1 - v): u runs from the
                luff (0) to the leech or the foot (1) along a row of the grid, v from the tack (0) to
                the head (1) up the luff; the rows run along the battens. UV2.x is the length of that
                row (the chord) in metres.
    boom.glb    "Boom": the wishbone with the grip, the harness lines and the outhaul. Origin:
                the mast axis at boom height; the boom runs along +X to the clew.
    sail_panels.png  The sail's colours (panels, battens, windows, the MMZB letters), drawn here
                pixel by pixel in the sail's (u, v): the head at the top of the picture, the luff on
                the left. Its alpha says what each part is: 1 the sail's own red cloth (a race's sail
                colour replaces it), 0.75 a printed graphic that keeps its colours, 0.55 and 0.35 a
                print on one side only (the sail numbers), 0 clear film (sail_cloth.gdshaderinc).

The legacy Unity models (Legacy/WindsurfingGame/Assets/Models/Board.fbx and Sail.fbx) were
the first reference for the shapes, but they had the bow along +X, little detail and brand
photos as textures. So the shapes are built here from the configured dimensions, with the real
gear's outlines and colours and our own lettering (no brand logos).

Axes: all geometry below is written in Godot's axes (x to starboard, y up, z aft, the bow is
-z). g2b() turns a point into Blender's axes (x, y forward, z up); the glTF exporter with
export_yup=True turns Blender's axes back into Godot's.
"""

import math
import re
import struct
import sys
import zlib
from pathlib import Path

import bpy
import numpy as np

REPO = Path(__file__).resolve().parents[2]
CONFIG_DIR = REPO / "Game" / "config"
OUT_DIR = REPO / "Game" / "assets" / "models"
RIG_VISUALS = REPO / "Game" / "windsurfer" / "rig_visuals.gd"


# --------------------------------------------------------------------------------------------
# The equipment's numbers, read from the game's config files.
# --------------------------------------------------------------------------------------------

def read_config(file_name: str, defaults: dict) -> dict:
    """The values of a Godot .tres config file for the keys in `defaults` (the defaults are
    used for keys the file leaves out, as Godot does with the script's defaults)."""
    values = dict(defaults)
    for line in (CONFIG_DIR / file_name).read_text(encoding="utf-8").splitlines():
        match = re.match(r"^(\w+) = (.+)$", line.strip())
        if not match or match.group(1) not in defaults:
            continue
        raw = match.group(2)
        if raw.startswith("Vector3("):
            values[match.group(1)] = tuple(float(x) for x in raw[len("Vector3("):-1].split(","))
        else:
            values[match.group(1)] = float(raw)
    return values


def read_gd_constant(path: Path, name: str) -> float:
    """A float constant of a GDScript file (const NAME: float = value), so a number the game and
    this script share is written in one place."""
    match = re.search(rf"^const {name}: float = ([-+0-9.eE]+)", path.read_text(encoding="utf-8"), re.MULTILINE)
    if match is None:
        raise ValueError(f"const {name} not found in {path}")
    return float(match.group(1))


BOARD = read_config("board_default.tres", {
    "length_m": 2.40, "width_m": 0.72, "thickness_m": 0.12,
    "widest_point_from_tail_m": 1.10, "tail_width_m": 0.45, "nose_width_m": 0.45,
    "tail_thickness_m": 0.055, "nose_thickness_m": 0.04,
    "hard_rail_to_m": 1.2, "soft_rail_from_m": 2.0,
    "nose_rocker_m": 0.08, "nose_rocker_length_m": 0.9,
    "tail_rocker_m": 0.01, "tail_rocker_length_m": 0.35,
    # The layout (BoardConfig; Max's Patrik 115 for the default board).
    "back_strap_from_tail_m": 0.0, "front_strap_from_tail_m": 0.0,
    "back_strap_out_m": 0.0, "front_strap_out_m": 0.0,
    "fin_box_back_screw_from_tail_m": 0.0, "fin_box_front_screw_from_tail_m": 0.0,
    "mast_track_back_from_tail_m": 0.0, "mast_track_front_from_tail_m": 0.0,
})
ONE_FOOT_M = 0.3048  # where a shaper measures the nose and tail widths (BoardConfig.ONE_FOOT_M)
SAIL = read_config("sail_default.tres", {
    "area_m2": 6.5, "luff_m": 4.60, "boom_m": 1.95, "boom_height_m": 1.40,
    "mast_foot_local": (0.0, 0.06, -0.10), "mast_m": 4.60, "camber": 0.10,
})
FIN = read_config("fin_default.tres", {"area_m2": 0.0365, "span_m": 0.38, "root_local": (0.0, -0.06, 0.90)})
SAILOR = read_config("sailor_default.tres", {"hand_grip_m": 0.6})


def srgb(r: int, g: int, b: int) -> tuple:
    return (r / 255.0, g / 255.0, b / 255.0)


# Colours are sRGB, as a designer picks them: (colour, roughness, metallic). The real gear's
# colours are the medians of patches of its photos (JP's product photos of the 2026 Slalom
# S-TEC; Severne's flat drawing and studio photo of the HGO): the board's purple carbon
# (119, 93, 159) and darker (85, 62, 123), the tail's navy (50, 42, 71), the bottom's navy
# (36, 40, 75); the HGO's red (178, 15, 18) in the drawing and (190, 0, 0) in the studio.
MATERIALS = {
    # The hull's two materials are only the fallback: the game paints them with the pictures.
    "board_deck": (srgb(119, 93, 159), 0.45, 0.0),
    "board_bottom": (srgb(60, 50, 100), 0.35, 0.0),
    "deck_pad": (srgb(206, 208, 216), 0.95, 0.0),
    "pad_edge": (srgb(240, 118, 32), 0.8, 0.0),
    "strap": ((0.07, 0.08, 0.10), 0.8, 0.0),
    "hardware": ((0.12, 0.12, 0.13), 0.5, 0.0),
    "plug": ((0.03, 0.03, 0.035), 0.4, 0.0),
    "track_slot": (srgb(170, 172, 180), 0.5, 0.0),
    "metal": ((0.72, 0.73, 0.75), 0.3, 1.0),
    "carbon": ((0.035, 0.035, 0.04), 0.3, 0.0),
    "rubber": ((0.05, 0.05, 0.05), 0.85, 0.0),
    "boom_grip": ((0.30, 0.31, 0.33), 0.95, 0.0),
    "rope": ((0.86, 0.86, 0.83), 0.8, 0.0),
    "harness_hose": ((0.98, 0.45, 0.08), 0.5, 0.0),
    "fin": ((0.06, 0.06, 0.07), 0.3, 0.0),
    # The sail: RigVisuals takes the cloth's colour as the reference for a race's tint, and the
    # sleeve's colour for the luff sleeve.
    "sail_cloth": (srgb(196, 18, 24), 0.5, 0.0),
    "sail_window": ((0.85, 0.90, 0.95), 0.1, 0.0),
    "sail_sleeve": (srgb(212, 28, 34), 0.55, 0.0),
    "fairing": ((0.04, 0.04, 0.045), 0.6, 0.0),
}


# --------------------------------------------------------------------------------------------
# A small mesh builder: vertices in Godot's axes, faces with a material name each.
# --------------------------------------------------------------------------------------------

def g2b(p) -> tuple:
    """Godot axes (x, y up, z aft) to Blender axes (x, y forward, z up)."""
    return (float(p[0]), -float(p[2]), float(p[1]))


def vec(x: float, y: float, z: float) -> np.ndarray:
    return np.array([x, y, z], dtype=float)


def normalized(v: np.ndarray) -> np.ndarray:
    length = np.linalg.norm(v)
    return v / length if length > 1e-12 else v


class MeshBuilder:
    def __init__(self, name: str):
        self.name = name
        self.verts: list = []
        self.uv: list = []
        self.uv2: list = []
        self.faces: list = []
        self.materials: list = []
        self.smooth: list = []

    def vertex(self, p, uv=(0.0, 0.0), uv2=(0.0, 0.0)) -> int:
        self.verts.append(np.array(p, dtype=float))
        self.uv.append(uv)
        self.uv2.append(uv2)
        return len(self.verts) - 1

    def face(self, indices, material: str, smooth: bool = True) -> None:
        self.faces.append(list(indices))
        self.materials.append(material)
        self.smooth.append(smooth)

    def face_normal(self, index: int) -> np.ndarray:
        """Newell's method: the face's normal from its winding (right-hand rule)."""
        pts = [self.verts[i] for i in self.faces[index]]
        n = np.zeros(3)
        for a, b in zip(pts, pts[1:] + pts[:1]):
            n += np.cross(a, b)
        return normalized(n)

    def face_centre(self, index: int) -> np.ndarray:
        return np.mean([self.verts[i] for i in self.faces[index]], axis=0)

    def flip(self, first: int, last: int) -> None:
        for i in range(first, last):
            self.faces[i].reverse()

    def face_toward(self, first: int, last: int, direction: np.ndarray) -> None:
        """Turns each face from `first` to `last` so its normal points along `direction`."""
        for i in range(first, last):
            if np.dot(self.face_normal(i), direction) < 0.0:
                self.faces[i].reverse()

    def build(self, uv2: bool = False) -> bpy.types.Object:
        mesh = bpy.data.meshes.new(self.name)
        mesh.from_pydata([g2b(v) for v in self.verts], [], self.faces)
        names = list(dict.fromkeys(self.materials))
        for name in names:
            mesh.materials.append(get_material(name))
        index = {name: i for i, name in enumerate(names)}
        mesh.polygons.foreach_set("material_index", [index[m] for m in self.materials])
        mesh.polygons.foreach_set("use_smooth", self.smooth)
        loop_vertices = np.zeros(len(mesh.loops), dtype=np.int32)
        mesh.loops.foreach_get("vertex_index", loop_vertices)
        layer = mesh.uv_layers.new(name="UVMap")
        layer.data.foreach_set("uv", np.array(self.uv, dtype=np.float32)[loop_vertices].ravel())
        if uv2:
            layer2 = mesh.uv_layers.new(name="UV2")
            layer2.data.foreach_set("uv", np.array(self.uv2, dtype=np.float32)[loop_vertices].ravel())
        mesh.update()
        obj = bpy.data.objects.new(self.name, mesh)
        bpy.context.scene.collection.objects.link(obj)
        return obj


_material_cache: dict = {}


def get_material(name: str) -> bpy.types.Material:
    if name in _material_cache:
        return _material_cache[name]
    color, roughness, metallic = MATERIALS[name]
    linear = [c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4 for c in color]
    material = bpy.data.materials.new(name)
    if bpy.app.version < (5, 0, 0):
        material.use_nodes = True  # Blender 5 materials always use nodes
    shader = material.node_tree.nodes["Principled BSDF"]
    shader.inputs["Base Color"].default_value = (*linear, 1.0)
    shader.inputs["Roughness"].default_value = roughness
    shader.inputs["Metallic"].default_value = metallic
    material.diffuse_color = (*linear, 1.0)
    _material_cache[name] = material
    return material


# --------------------------------------------------------------------------------------------
# Shape helpers: lofts (rings joined into a surface), tubes, caps.
# --------------------------------------------------------------------------------------------

def loft(builder: MeshBuilder, rings: list, material, closed: bool = True, smooth: bool = True) -> None:
    """Joins rings of vertex indices (all the same length) into quads, facing outward: away
    from each ring's centre. `material` is a name or a function (ring index, point index)."""
    first = len(builder.faces)
    count = len(rings[0])
    for i in range(len(rings) - 1):
        for k in range(count if closed else count - 1):
            k2 = (k + 1) % count
            name = material(i, k) if callable(material) else material
            builder.face([rings[i][k], rings[i + 1][k], rings[i + 1][k2], rings[i][k2]], name, smooth)
    # Flip the whole loft if its faces point into the rings instead of out of them.
    votes = 0.0
    for f in range(first, len(builder.faces), max(1, (len(builder.faces) - first) // 50)):
        ring = rings[min((f - first) // (count if closed else count - 1), len(rings) - 1)]
        centre = np.mean([builder.verts[i] for i in ring], axis=0)
        votes += np.dot(builder.face_normal(f), builder.face_centre(f) - centre)
    if votes < 0.0:
        builder.flip(first, len(builder.faces))


def cap(builder: MeshBuilder, ring: list, outward: np.ndarray, material: str, flat: bool = True) -> None:
    """Closes a ring with a fan around its centre. With `flat`, the cap gets its own vertices
    (with the ring's UVs), so it has a sharp edge with the surface around it."""
    if flat:
        ring = [builder.vertex(builder.verts[i], builder.uv[i]) for i in ring]
    centre_uv = tuple(np.mean([builder.uv[i] for i in ring], axis=0))
    centre = builder.vertex(np.mean([builder.verts[i] for i in ring], axis=0), centre_uv)
    first = len(builder.faces)
    for k in range(len(ring)):
        builder.face([centre, ring[k], ring[(k + 1) % len(ring)]], material, not flat)
    if np.dot(builder.face_normal(first), outward) < 0.0:
        builder.flip(first, len(builder.faces))


def point_cap(builder: MeshBuilder, ring: list, tip: np.ndarray, material: str, tip_uv=(0.0, 0.0)) -> None:
    """Closes a ring with a fan to a tip point (a nose or a fin tip), smooth shaded."""
    tip_index = builder.vertex(tip, tip_uv)
    first = len(builder.faces)
    for k in range(len(ring)):
        builder.face([tip_index, ring[k], ring[(k + 1) % len(ring)]], material, True)
    centre = np.mean([builder.verts[i] for i in ring], axis=0)
    if np.dot(builder.face_normal(first), tip - centre) < 0.0:
        builder.flip(first, len(builder.faces))


def path_frames(path: list, up_hint: np.ndarray) -> list:
    """A frame (point, normal, binormal) at each point of a path, turning as little as
    possible from one point to the next (parallel transport)."""
    frames = []
    normal = None
    for i, p in enumerate(path):
        tangent = normalized(path[min(i + 1, len(path) - 1)] - path[max(i - 1, 0)])
        if normal is None:
            normal = up_hint - np.dot(up_hint, tangent) * tangent
            if np.linalg.norm(normal) < 1e-6:
                normal = np.cross(tangent, vec(1, 0, 0))
        normal = normalized(normal - np.dot(normal, tangent) * tangent)
        frames.append((p, normal, np.cross(tangent, normal)))
    return frames


def circle(sides: int) -> list:
    return [(math.cos(2 * math.pi * k / sides), math.sin(2 * math.pi * k / sides)) for k in range(sides)]


def sweep(builder: MeshBuilder, path: list, profile: list, scales: list, material: str,
          up_hint=None, caps: bool = True) -> list:
    """Sweeps a 2D profile along a path. `scales` gives (a, b) sizes per path point for the
    profile's two axes. Returns the rings."""
    up = vec(0, 1, 0) if up_hint is None else up_hint
    rings = []
    for (p, n, b), (sa, sb) in zip(path_frames(path, up), scales):
        rings.append([builder.vertex(p + a * sa * n + c * sb * b) for (a, c) in profile])
    loft(builder, rings, material)
    if caps:
        cap(builder, rings[0], path[0] - path[1], material)
        cap(builder, rings[-1], path[-1] - path[-2], material)
    return rings


def tube(builder: MeshBuilder, path: list, radii, material: str, sides: int = 12, caps: bool = True) -> list:
    if not isinstance(radii, (list, tuple, np.ndarray)):
        radii = [radii] * len(path)
    return sweep(builder, path, circle(sides), [(r, r) for r in radii], material, caps=caps)


def superellipsoid(builder: MeshBuilder, centre, half, material: str, roundness: float = 0.35,
                   rings_count: int = 10, sides: int = 16) -> None:
    """A rounded box: half sizes `half` along x, y, z; roundness 1 is an ellipsoid, small
    numbers make it boxy."""
    def signed_pow(value: float, power: float) -> float:
        return math.copysign(abs(value) ** power, value)
    rings = []
    for i in range(1, rings_count):
        phi = -math.pi / 2 + math.pi * i / rings_count
        ring = []
        for k in range(sides):
            theta = 2 * math.pi * k / sides
            x = half[0] * signed_pow(math.cos(phi), roundness) * signed_pow(math.cos(theta), roundness)
            z = half[2] * signed_pow(math.cos(phi), roundness) * signed_pow(math.sin(theta), roundness)
            y = half[1] * signed_pow(math.sin(phi), roundness)
            ring.append(builder.vertex(np.array(centre) + vec(x, y, z)))
        rings.append(ring)
    loft(builder, rings, material)
    point_cap(builder, rings[0], np.array(centre) + vec(0, -half[1], 0), material)
    point_cap(builder, rings[-1], np.array(centre) + vec(0, half[1], 0), material)


def catmull_rom(points: list, samples_per_span: int) -> list:
    """A smooth curve through the points."""
    pts = [points[0]] + list(points) + [points[-1]]
    out = []
    for i in range(1, len(pts) - 2):
        p0, p1, p2, p3 = pts[i - 1], pts[i], pts[i + 1], pts[i + 2]
        for s in range(samples_per_span):
            t = s / samples_per_span
            out.append(0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t * t
                              + (-p0 + 3 * p1 - 3 * p2 + p3) * t * t * t))
    out.append(np.array(points[-1], dtype=float))
    return out


def rounded_polygon(points: list, iterations: int = 3) -> list:
    """Rounds a polygon's corners by cutting them (Chaikin): each pass replaces every edge by
    the points a quarter and three quarters along it."""
    pts = [np.array(p, dtype=float) for p in points]
    for _ in range(iterations):
        new = []
        for a, b in zip(pts, pts[1:] + pts[:1]):
            new.append(0.75 * a + 0.25 * b)
            new.append(0.25 * a + 0.75 * b)
        pts = new
    return pts


def smoothstep(edge0: float, edge1: float, x):
    t = np.clip((np.asarray(x, dtype=float) - edge0) / (edge1 - edge0), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def segment_distance(X, Y, a, b):
    """Distance from the points (X, Y) to the segment from a to b, and how far along it (0 to 1)
    the nearest point is."""
    d = np.array(b, dtype=float) - np.array(a, dtype=float)
    t = np.clip(((X - a[0]) * d[0] + (Y - a[1]) * d[1]) / max(float(np.dot(d, d)), 1e-12), 0.0, 1.0)
    return np.hypot(X - (a[0] + t * d[0]), Y - (a[1] + t * d[1])), t


def convex_distance(X, Y, polygon: list):
    """How far the points are outside a convex polygon (given counter-clockwise), m; negative
    inside. Exact along the edges, a little short near the corners, which is all the borders and
    margins here need."""
    out = np.full(np.shape(X), -np.inf)
    for a, b in zip(polygon, polygon[1:] + polygon[:1]):
        edge = np.array(b, dtype=float) - np.array(a, dtype=float)
        normal = np.array([edge[1], -edge[0]]) / np.linalg.norm(edge)   # outward for a CCW polygon
        out = np.maximum(out, (X - a[0]) * normal[0] + (Y - a[1]) * normal[1])
    return out


# The letters for our lettering, in strokes in a unit box: (0, 0) bottom left, (1, 1) top right.
GLYPHS = {
    "M": [((0, 0), (0, 1)), ((0, 1), (0.5, 0.45)), ((0.5, 0.45), (1, 1)), ((1, 1), (1, 0))],
    "Z": [((0, 1), (1, 1)), ((1, 1), (0, 0)), ((0, 0), (1, 0))],
    "B": [((0, 0), (0, 1)), ((0, 1), (0.7, 1)), ((0.7, 1), (0.9, 0.88)), ((0.9, 0.88), (0.9, 0.64)),
          ((0.9, 0.64), (0.7, 0.52)), ((0, 0.52), (0.72, 0.52)), ((0.72, 0.52), (1, 0.38)),
          ((1, 0.38), (1, 0.14)), ((1, 0.14), (0.75, 0)), ((0.75, 0), (0, 0))],
    "0": [((0.2, 0), (0.8, 0)), ((0.8, 0), (1, 0.2)), ((1, 0.2), (1, 0.8)), ((1, 0.8), (0.8, 1)),
          ((0.8, 1), (0.2, 1)), ((0.2, 1), (0, 0.8)), ((0, 0.8), (0, 0.2)), ((0, 0.2), (0.2, 0))],
    "8": [((0.2, 0), (0.8, 0)), ((0.8, 0), (1, 0.18)), ((1, 0.18), (1, 0.36)), ((1, 0.36), (0.8, 0.52)),
          ((0.8, 0.52), (0.2, 0.52)), ((0.2, 0.52), (0, 0.36)), ((0, 0.36), (0, 0.18)), ((0, 0.18), (0.2, 0)),
          ((0.25, 0.52), (0.1, 0.66)), ((0.1, 0.66), (0.1, 0.86)), ((0.1, 0.86), (0.25, 1)),
          ((0.25, 1), (0.75, 1)), ((0.75, 1), (0.9, 0.86)), ((0.9, 0.86), (0.9, 0.66)), ((0.9, 0.66), (0.75, 0.52))],
    ".": [((0.5, 0.06), (0.5, 0.06))],
}


def lettering_mask(X, Y, text: str, origin, height: float, stroke: float, along=(1.0, 0.0), up=(0.0, 1.0)):
    """Where the letters of `text` are: strokes `stroke` wide, letters `height` tall, starting at
    `origin` and running along `along` with their tops toward `up` (unit vectors in (X, Y))."""
    width = 0.62 * height
    gap = 0.2 * height
    mask = np.zeros(np.shape(X), dtype=bool)
    along, up = np.array(along, dtype=float), np.array(up, dtype=float)
    for i, letter in enumerate(text):
        x0 = i * (width + gap) if letter != "." else i * (width + gap) - 0.3 * width
        for (ax, ay), (bx, by) in GLYPHS[letter]:
            a = np.array(origin) + (x0 + ax * width) * along + ay * height * up
            b = np.array(origin) + (x0 + bx * width) * along + by * height * up
            distance, _ = segment_distance(X, Y, a, b)
            mask |= distance < 0.5 * stroke
    return mask


def text_length(text: str, height: float) -> float:
    return len(text) * 0.62 * height + (len(text) - 1) * 0.2 * height


# --------------------------------------------------------------------------------------------
# The board: the JP Australia Slalom S-TEC 72.
# --------------------------------------------------------------------------------------------

BOARD_L = BOARD["length_m"]
BOARD_HALF_W = 0.5 * BOARD["width_m"]
BOARD_THICK = BOARD["thickness_m"]
MAST_FOOT = np.array(SAIL["mast_foot_local"], dtype=float)


def pchip(xs, ys, x: float) -> float:
    """A smooth curve through the points that never overshoots them (monotone cubic
    Hermite, Fritsch and Carlson): a traced outline stays inside its own measurements."""
    xs, ys = np.asarray(xs, dtype=float), np.asarray(ys, dtype=float)
    if x <= xs[0]:
        return float(ys[0])
    if x >= xs[-1]:
        return float(ys[-1])
    h = np.diff(xs)
    delta = np.diff(ys) / h
    slopes = np.zeros_like(ys)
    for i in range(1, len(xs) - 1):
        if delta[i - 1] * delta[i] > 0:
            w1, w2 = 2 * h[i] + h[i - 1], h[i] + 2 * h[i - 1]
            slopes[i] = (w1 + w2) / (w1 / delta[i - 1] + w2 / delta[i])
    slopes[0], slopes[-1] = delta[0], delta[-1]
    i = int(np.searchsorted(xs, x) - 1)
    s = (x - xs[i]) / h[i]
    h00, h10, h01, h11 = 2 * s ** 3 - 3 * s ** 2 + 1, s ** 3 - 2 * s ** 2 + s, -2 * s ** 3 + 3 * s ** 2, s ** 3 - s ** 2
    return float(h00 * ys[i] + h10 * h[i] * slopes[i] + h01 * ys[i + 1] + h11 * h[i] * slopes[i + 1])


# The JP Slalom S-TEC 72 (jp-australia.com/p/windsurfing/boards/slalom-s-tec: the 2026 board is
# 229 x 72 cm and 119 l; the SL 72 of 2025, the configured board, 228 x 72 cm and 117 l). Its
# deck outline, traced from JP's top view of the 2026 board (JP_SLALOM-S-TEC_261224_1, 1499 px
# long; the width over the length 0.312 against JP's 72/229 = 0.314): full width in metres at
# metres from the tail, scaled to the configured length and width. Widest (0.72 m) at 1.14 to
# 1.2 m, within 1 cm of it from 0.95 to 1.45 m (the parallel middle); one foot from the tail
# 0.50 m (BoardConfig.tail_width_m 0.49), one foot from the nose 0.55 m (nose_width_m 0.56). The
# tail ends in a rounded point 5 to 10 cm wide on the photo; the model ends in a 14 cm transom
# with 1.5 cm corners (a visuals test checks for a transom of at least 10 cm).
JP_OUTLINE = [(0.0, 0.14), (0.03, 0.18), (0.05, 0.222), (0.1, 0.322), (0.15, 0.383), (0.2, 0.428),
              (0.3, 0.502), (0.4, 0.558), (0.5, 0.603), (0.6, 0.637), (0.7, 0.666), (0.8, 0.686),
              (0.9, 0.702), (1.0, 0.711), (1.1, 0.718), (1.17, 0.72), (1.3, 0.718), (1.4, 0.712),
              (1.5, 0.702), (1.6, 0.689), (1.7, 0.666), (1.8, 0.635), (1.9, 0.592), (2.0, 0.528),
              (2.08, 0.458), (2.16, 0.355), (2.2, 0.285), (2.22, 0.237), (2.25, 0.158), (2.27, 0.083),
              (2.28, 0.0)]
JP_LENGTH, JP_WIDTH = 2.28, 0.72
TRANSOM_CORNER = 0.015
# The nose rocker beyond 1.8 m from the tail (the rise of the bottom above the flat tail), traced
# from JP's side view (report hull_balance.md section 7). JP's side view of the 2026 board
# (JP_SLALOM-S-TEC_261224_3) gives the same within 4 mm: 6, 13, 25, 40, 63, 97, 158 and 205 mm at
# 1.0, 1.2, 1.4, 1.6, 1.8, 2.0, 2.2 and 2.28 m. The nose is higher than the physics' parabola,
# which was fitted from 1.0 to 1.9 m where the board meets the water (the model keeps the
# parabola there).
JP_NOSE_ROCKER = [(2.0, 0.093), (2.2, 0.156), (2.28, 0.208)]
NOSE_TRACE_FROM = 1.8
# JP's tail cut-outs ("Dual tail outlines use cut-outs that reduce bottom width and wetted
# surface. The deck outline above the cut-outs is wider, which moves the rear strap outboard";
# double steps on the 62.5 to 76). On JP's bottom view (JP_SLALOM-S-TEC_261224_2) the planing
# bottom steps in about 0.20 m from the tail, to 0.19 m wide there and about 0.11 m at the tail;
# the step's underside between it and the deck's rail is the orange-red there. Here the step is
# one shelf at the rail's height. Visual only: the physics has no cut-outs (BoardConfig.cutout_*
# are off).
CUTOUT_LENGTH = 0.20
CUTOUT_BOTTOM_HALF_W = (0.055, 0.095)   # the planing bottom's half width at the tail and at the step

# The mast track's ends (Max's board, BoardConfig) and the deck's layout, metres from the tail.
MAST_TRACK_BACK = BOARD["mast_track_back_from_tail_m"] or (BOARD_L / 2 - MAST_FOOT[2] - 0.05)
MAST_TRACK_FRONT = BOARD["mast_track_front_from_tail_m"] or (BOARD_L / 2 - MAST_FOOT[2] + 0.12)
RING_POINTS = 48


def board_z(t: float) -> float:
    """Godot z of a point `t` metres forward of the transom (the bow is -z)."""
    return 0.5 * BOARD_L - t


def physics_bottom_rise(t: float) -> float:
    """The physics' rocker, the same formula as BoardConfig.bottom_rise_m."""
    if t < BOARD["tail_rocker_length_m"]:
        a = (BOARD["tail_rocker_length_m"] - t) / BOARD["tail_rocker_length_m"]
        return BOARD["tail_rocker_m"] * a * a
    nose_start = BOARD_L - BOARD["nose_rocker_length_m"]
    if t > nose_start:
        n = (t - nose_start) / BOARD["nose_rocker_length_m"]
        return BOARD["nose_rocker_m"] * n * n
    return 0.0


def bottom_rise(t: float) -> float:
    """The rocker: the physics' where the board meets the water, JP's traced nose beyond."""
    if t <= NOSE_TRACE_FROM:
        return physics_bottom_rise(t)
    scale = BOARD_L / JP_LENGTH
    xs = [NOSE_TRACE_FROM] + [x * scale for x, _ in JP_NOSE_ROCKER]
    ys = [physics_bottom_rise(NOSE_TRACE_FROM)] + [y for _, y in JP_NOSE_ROCKER]
    return pchip(xs, ys, t)


def outline_width(t: float) -> float:
    """JP's traced outline, scaled to the configured length and width."""
    sx, sw = BOARD_L / JP_LENGTH, BOARD["width_m"] / JP_WIDTH
    return sw * pchip([x * sx for x, _ in JP_OUTLINE], [w for _, w in JP_OUTLINE], t)


def half_width(t: float) -> float:
    """The deck's outline seen from above, with the transom's corners rounded."""
    w = 0.5 * outline_width(t)
    if t < TRANSOM_CORNER:
        w = w - TRANSOM_CORNER + math.sqrt(max(0.0, TRANSOM_CORNER ** 2 - (TRANSOM_CORNER - t) ** 2))
    return w


def thickness(t: float) -> float:
    """The physics' thickness profile (BoardConfig.thickness_at): full at the widest point,
    a parabola down to the tail and nose thicknesses at the tips."""
    widest = BOARD["widest_point_from_tail_m"]
    if t <= widest:
        s = min(1.0, max(0.0, (widest - t) / max(widest, 0.01)))
        return BOARD_THICK - (BOARD_THICK - BOARD["tail_thickness_m"]) * s * s
    n = min(1.0, max(0.0, (t - widest) / max(BOARD_L - widest, 0.01)))
    return BOARD_THICK - (BOARD_THICK - BOARD["nose_thickness_m"]) * n * n


def tip_factor(t: float) -> float:
    """Rounds the nose in side view: the last few centimetres get thinner."""
    radius = 0.03
    if t <= BOARD_L - radius:
        return 1.0
    a = (t - (BOARD_L - radius)) / radius
    return math.sqrt(max(0.0, 1.0 - a * a))


def bottom_exponent(t: float) -> float:
    """The shape of the lower rail: hard (boxy, 6) where the physics' rail is hard (up to
    hard_rail_to_m from the tail), soft (3) from soft_rail_from_m (BoardConfig.rail_hardness)."""
    hard, soft = BOARD["hard_rail_to_m"], BOARD["soft_rail_from_m"]
    a = min(1.0, max(0.0, (t - hard) / max(soft - hard, 0.01)))
    return 6.0 - 3.0 * a


def bottom_half_width(t: float) -> float:
    """The planing bottom's half width: the deck's, except under the tail cut-outs."""
    w = half_width(t)
    if t >= CUTOUT_LENGTH:
        return w
    tail, step = CUTOUT_BOTTOM_HALF_W
    return min(w, tail + (step - tail) * t / CUTOUT_LENGTH)


DECK_EXPONENT = 2.6
RAIL_FRACTION = 0.35  # the rail line (the widest point of a cross-section), up from the bottom


def section(t: float) -> tuple:
    """(half width, bottom y, rail y, deck y at the centreline) of the cross-section at t."""
    th = thickness(t)
    y_bottom = -0.5 * BOARD_THICK + bottom_rise(t)
    y_rail = y_bottom + RAIL_FRACTION * th
    f = tip_factor(t)
    return half_width(t), y_rail - (y_rail - y_bottom) * f, y_rail, y_rail + (th - RAIL_FRACTION * th) * f


def deck_y(x: float, t: float) -> float:
    """Height of the deck surface at (x, t)."""
    w, _, y_rail, y_deck = section(t)
    a = min(1.0, abs(x) / max(w, 1e-6))
    return y_rail + (y_deck - y_rail) * (1.0 - a ** DECK_EXPONENT) ** (1.0 / DECK_EXPONENT)


def hull_ring_points(t: float) -> list:
    """The cross-section as RING_POINTS points: a superellipse, domed on the deck and flat
    with a tighter edge on the bottom. Point 0 is the starboard rail, a quarter round is the
    deck centre, half round the port rail, three quarters the bottom centre. Under the tail
    cut-outs the bottom half is narrower than the deck: between the rail and the bottom's
    edge there is a shelf at the rail's height (the step)."""
    w, y_bottom, y_rail, y_deck = section(t)
    w_low = max(bottom_half_width(t), 0.01)
    low = bottom_exponent(t)
    pts = []
    for k in range(RING_POINTS):
        a = 2 * math.pi * k / RING_POINTS
        c, s = math.cos(a), math.sin(a)
        if s >= 0:
            x = w * math.copysign(abs(c) ** (2 / DECK_EXPONENT), c)
            y = y_rail + (y_deck - y_rail) * abs(s) ** (2 / DECK_EXPONENT)
        else:
            x = w_low * math.copysign(abs(c) ** (2 / low), c)
            y = y_rail - (y_rail - y_bottom) * abs(s) ** (2 / low)
        pts.append(vec(x, y, board_z(t)))
    return pts


# The hull's UV: the board seen from above, u across (0.5 on the centreline), v along it from the
# tail (0) to the nose (1). The deck's and the bottom's pictures use the same mapping.
UV_HALF_SPAN = BOARD_HALF_W + 0.02


def hull_uv(x: float, t: float) -> tuple:
    return (0.5 + x / (2.0 * UV_HALF_SPAN), t / BOARD_L)


def board_stations() -> list:
    """Where the hull's cross-sections are, metres from the tail: evenly spaced, with the two
    sides of the cut-outs' step close together and more toward the nose's point."""
    special = [CUTOUT_LENGTH - 0.003, CUTOUT_LENGTH, 0.005, 0.01]
    tip = [BOARD_L - d for d in (0.03, 0.02, 0.013, 0.008, 0.004, 0.0015)]
    stations = sorted(set(list(np.linspace(0.0, BOARD_L - 0.04, 120)) + special + tip))
    kept = []
    for t in stations:
        if kept and t - kept[-1] < 0.002:
            continue
        if kept and t - kept[-1] < 0.006 and t not in special and kept[-1] in special:
            continue
        kept.append(t)
    return kept


def build_hull() -> bpy.types.Object:
    b = MeshBuilder("Hull")
    stations = board_stations()
    rings = []
    for t in stations:
        rings.append([b.vertex(p, hull_uv(p[0], t)) for p in hull_ring_points(t)])
    loft(b, rings, lambda i, k: "board_bottom" if k >= RING_POINTS // 2 else "board_deck")
    # The transom: a flat face at the tail. The nose: the rings close to a point.
    cap(b, rings[0], vec(0, 0, 1), "board_bottom")
    _, _, y_rail, _ = section(BOARD_L)
    point_cap(b, rings[-1], vec(0, y_rail, board_z(BOARD_L)), "board_deck", tip_uv=(0.5, 1.0))
    return b.build()


# The deck pads: JP's "compact pads" (minimal EVA), white with a diamond grip and an orange edge
# (the 2026 photos): one under each front strap, one under each back strap reaching in to the
# centreline, and an orange wedge between the back pads, where the fin box's screws are. Their
# outlines are traced from JP's top view around JP's straps and placed here around the configured
# straps (Max's layout): (x out from the centreline, metres from the tail), for the starboard
# side, mirrored for port. `rail` means the rail minus 1.2 cm.
PAD_THICK = 0.007     # an estimate: deck pads are 5 to 8 mm of EVA
WEDGE_THICK = 0.014   # an estimate
BACK_STRAP_T = BOARD["back_strap_from_tail_m"] or 0.22 * BOARD_L
FRONT_STRAP_T = BOARD["front_strap_from_tail_m"] or (BOARD_L / 2 - MAST_FOOT[2] - 0.34)
BACK_STRAP_OUT = BOARD["back_strap_out_m"] or 0.15
FRONT_STRAP_OUT = BOARD["front_strap_out_m"] or 0.17
WEDGE_HALF_W = 0.045
WEDGE_T = (0.085, 0.265)


def rail_in(t: float) -> float:
    return half_width(t) - 0.012


def front_pad_outline() -> list:
    t = FRONT_STRAP_T
    return [(0.152, t - 0.17), (rail_in(t - 0.18), t - 0.18), (rail_in(t + 0.10), t + 0.10), (0.206, t + 0.125)]


def back_pad_outline() -> list:
    front = BACK_STRAP_T + 0.17
    back = 0.075
    return [(0.015, front), (rail_in(front + 0.01), front + 0.01), (rail_in(back + 0.02), back + 0.015),
            (WEDGE_HALF_W + 0.01, back), (WEDGE_HALF_W + 0.01, WEDGE_T[1] - 0.01), (0.015, WEDGE_T[1] + 0.01)]


def wedge_outline() -> list:
    (t0, t1), w = WEDGE_T, WEDGE_HALF_W
    return [(-w, t0), (w, t0), (w, t1), (-w, t1)]


def add_raised_pad(b: MeshBuilder, outline: list, height: float, top: str, side: str) -> None:
    """A pad of `height` on the deck within `outline` ((x, t) points, corners rounded here): its
    top follows the deck's dome, its edge runs down into the deck."""
    pts = rounded_polygon(outline, iterations=2)
    centre = np.mean(pts, axis=0)
    def at(p, lift):
        x, t = float(p[0]), float(p[1])
        return vec(x, deck_y(x, t) + lift, board_z(t))
    bottom = [b.vertex(at(p, -0.002)) for p in pts]
    edge_top = [b.vertex(at(p, height)) for p in pts]
    loft(b, [bottom, edge_top], side, smooth=False)
    # The top: rings shrinking to the centre, each point on the dome, so the pad hugs the deck.
    rings = [[b.vertex(at(p, height)) for p in pts]]
    for s in (0.75, 0.5, 0.25):
        rings.append([b.vertex(at(centre + s * (p - centre), height)) for p in pts])
    first = len(b.faces)
    for i in range(len(rings) - 1):
        for k in range(len(pts)):
            k2 = (k + 1) % len(pts)
            b.face([rings[i][k], rings[i + 1][k], rings[i + 1][k2], rings[i][k2]], top)
    middle = b.vertex(at(centre, height))
    for k in range(len(pts)):
        b.face([middle, rings[-1][k], rings[-1][(k + 1) % len(pts)]], top)
    b.face_toward(first, len(b.faces), vec(0, 1, 0))


def build_deck_pads() -> bpy.types.Object:
    b = MeshBuilder("DeckPads")
    for side in (-1.0, 1.0):
        for outline in (front_pad_outline(), back_pad_outline()):
            pts = [(side * x, t) for x, t in outline]
            if side < 0:
                pts.reverse()
            add_raised_pad(b, pts, PAD_THICK, "deck_pad", "pad_edge")
    add_raised_pad(b, wedge_outline(), WEDGE_THICK, "pad_edge", "pad_edge")
    return b.build()


# The footstraps: (across, from the tail, the angle of the strap's line to the board's, degrees,
# + its front end turned toward the rail). Max's Patrik 115: the middle of each back strap over
# the fin box's front screw, 0.15 m out; the front straps 0.825 m from the tail, 0.25 m out. The
# heel is at the rail and the toes point inboard and forward, so a strap, which crosses the foot,
# turns its front end out: about along the rail, which narrows fast toward the tail. They stand
# on the pads.
STRAPS = [(side * FRONT_STRAP_OUT, FRONT_STRAP_T, 10.0) for side in (-1.0, 1.0)] + \
         [(side * BACK_STRAP_OUT, BACK_STRAP_T, 18.0) for side in (-1.0, 1.0)]
STRAP_HALF_SPAN = 0.085  # half the distance between a strap's two screws
STRAP_HEIGHT = 0.065


def build_footstraps() -> bpy.types.Object:
    """Padded arches over the pads, screwed down in front of and behind the foot, each centred
    on its configured place and turned by its angle."""
    b = MeshBuilder("Footstraps")
    profile = [(math.copysign(abs(c) ** 0.4, c), math.copysign(abs(s) ** 0.4, s)) for c, s in circle(16)]
    for x, t, angle in STRAPS:
        a = math.radians(angle)
        outboard = math.copysign(1.0, x)
        # Along the strap, toward the bow, turned so its front end points toward the rail.
        forward = vec(outboard * math.sin(a), 0.0, -math.cos(a))
        across = vec(math.cos(a), 0.0, outboard * math.sin(a))
        centre = vec(x, 0.0, board_z(t))
        path = []
        scales = []
        for i in range(25):
            phi = math.radians(-12.0 + 204.0 * i / 24)
            p = centre + forward * (STRAP_HALF_SPAN * math.cos(phi))
            ground = deck_y(float(p[0]), BOARD_L / 2 - float(p[2])) + PAD_THICK
            path.append(vec(p[0], ground + STRAP_HEIGHT * math.sin(phi), p[2]))
            pad = 0.5 + 0.5 * math.sin(max(0.0, min(math.pi, phi)))  # thicker padding on top
            scales.append((0.028, 0.006 + 0.007 * pad))
        sweep(b, path, profile, scales, "strap", up_hint=across)
        # The screw plugs at both ends.
        for end in (-1, 1):
            p = centre + forward * (end * STRAP_HALF_SPAN)
            ground = deck_y(float(p[0]), BOARD_L / 2 - float(p[2])) + PAD_THICK
            tube(b, [vec(p[0], ground - 0.002, p[2]), vec(p[0], ground + 0.004, p[2])], 0.014, "hardware", sides=10)
    return b.build()


def build_fin_box() -> bpy.types.Object:
    """The fin box: its two screws on the deck (a Tuttle box is screwed from the deck; on the JP
    they sit in black oval plugs on the wedge), and the box's slot in the bottom the fin's head
    sits in."""
    b = MeshBuilder("FinBox")
    back = BOARD["fin_box_back_screw_from_tail_m"] or 0.12
    front = BOARD["fin_box_front_screw_from_tail_m"] or 0.235
    for t in (back, front):
        on_wedge = WEDGE_T[0] <= t <= WEDGE_T[1]
        ground = deck_y(0.0, t) + (WEDGE_THICK if on_wedge else 0.0)
        superellipsoid(b, (0.0, ground, board_z(t)), (0.011, 0.0025, 0.018), "plug", roundness=0.5,
                       rings_count=6, sides=16)
        tube(b, [vec(0, ground, board_z(t)), vec(0, ground + 0.0035, board_z(t))], 0.0055, "metal", sides=10)
    # The slot: from just behind the back screw to just ahead of the front one, flush with the
    # bottom (2 mm proud, so it shows).
    t0, t1 = back - 0.035, front + 0.03
    half = 0.018
    bottom_back, bottom_front = section(t0)[1], section(t1)[1]
    corners = [vec(-half, 0, board_z(t0)), vec(half, 0, board_z(t0)), vec(half, 0, board_z(t1)), vec(-half, 0, board_z(t1))]
    low = [b.vertex(c + vec(0, (bottom_back if i < 2 else bottom_front) + 0.001, 0)) for i, c in enumerate(corners)]
    high = [b.vertex(c + vec(0, (bottom_back if i < 2 else bottom_front) - 0.002, 0)) for i, c in enumerate(corners)]
    loft(b, [low, high], "hardware", smooth=False)
    cap(b, high, vec(0, -1, 0), "hardware")
    return b.build()


def deck_stadium(b: MeshBuilder, t_back: float, t_front: float, half: float, lift: float, depth: float,
                 material: str, sides_material: str) -> None:
    """A flat stadium (two half circles joined by straight sides) on the deck, from `depth` under
    it to `lift` over it."""
    front_centre = board_z(t_front) + half
    back_centre = board_z(t_back) - half
    outline = []
    for i in range(10):
        a = math.pi + math.pi * i / 9   # the front half circle, from port round to starboard
        outline.append((half * math.cos(a), front_centre + half * math.sin(a)))
    for i in range(10):
        a = math.pi * i / 9             # the back half circle, from starboard round to port
        outline.append((half * math.cos(a), back_centre + half * math.sin(a)))
    bottom = [b.vertex(vec(x, deck_y(x, BOARD_L / 2 - z) - depth, z)) for x, z in outline]
    top = [b.vertex(vec(x, deck_y(x, BOARD_L / 2 - z) + lift, z)) for x, z in outline]
    loft(b, [bottom, top], sides_material, smooth=False)
    cap(b, top, vec(0, 1, 0), material)


def build_mast_track() -> bpy.types.Object:
    """The mast track: JP's black plate in the deck with the slot the mast base slides in (the
    slot between the configured ends), and the base plate at the mast foot."""
    b = MeshBuilder("MastTrack")
    deck_stadium(b, MAST_TRACK_BACK - 0.045, MAST_TRACK_FRONT + 0.045, 0.032, 0.0015, 0.004, "plug", "plug")
    deck_stadium(b, MAST_TRACK_BACK, MAST_TRACK_FRONT, 0.008, 0.0025, 0.004, "track_slot", "track_slot")
    # The base plate in the track, which the mast's rubber joint stands on.
    foot_z = MAST_FOOT[2]
    deck = deck_y(0.0, BOARD_L / 2 - foot_z)
    plate = [vec(0, deck - 0.002, foot_z), vec(0, MAST_FOOT[1] + 0.012, foot_z)]
    tube(b, plate, 0.04, "rubber", sides=20)
    return b.build()


# --- The board's pictures ---------------------------------------------------------------------
# The deck of the 2026 JP Slalom S-TEC (JP's photos): purple carbon with darker streaks along
# the board; over the back third a dark navy port half (with JP's "SLALOM S-TEC" letters; ours
# say MMZB) and an orange-red starboard half with purple streaks, red-orange at the very tail;
# the mast track in a darker oval recess. The bottom: purple at the front, darkening to navy with
# purple streaks toward the tail, orange-red along the rails over the tail third and under the
# cut-outs' steps.
DECK_PURPLE = np.array([100, 74, 142], dtype=float)
DECK_PURPLE_DARK = np.array([44, 34, 62], dtype=float)
TAIL_NAVY = np.array([50, 42, 71], dtype=float)
TAIL_ORANGE = np.array([228, 82, 50], dtype=float)
TAIL_RED = np.array([205, 48, 38], dtype=float)
LETTER_ORANGE = np.array([242, 112, 40], dtype=float)
BOTTOM_PURPLE = np.array([81, 62, 116], dtype=float)
BOTTOM_NAVY = np.array([36, 40, 75], dtype=float)
RAIL_RED = np.array([232, 72, 52], dtype=float)
TAIL_GRAPHIC_FROM = 0.80   # metres from the tail where the tail graphic has faded in (JP's top view)


def value_noise(X, T, seed: int, cells_across: int, cells_along: int):
    """Smooth random values, 0 to 1, from a grid of random numbers over the board (cells_across
    by cells_along cells), blended between the grid's points."""
    grid = np.random.default_rng(seed).random((cells_along + 2, cells_across + 2))
    gx = np.clip((X + UV_HALF_SPAN) / (2.0 * UV_HALF_SPAN), 0.0, 1.0) * cells_across
    gt = np.clip(T / BOARD_L, 0.0, 1.0) * cells_along
    ix, it = np.minimum(np.floor(gx).astype(int), cells_across), np.minimum(np.floor(gt).astype(int), cells_along)
    fx, ft = smoothstep(0.0, 1.0, gx - ix), smoothstep(0.0, 1.0, gt - it)
    low = grid[it, ix] * (1 - fx) + grid[it, ix + 1] * fx
    high = grid[it + 1, ix] * (1 - fx) + grid[it + 1, ix + 1] * fx
    return low * (1 - ft) + high * ft


def streaks(X, T, seed: int, stretch: float = 2.5, scale: float = 1.0):
    """The S-TEC carbon's look, 0 (light) to 1 (dark): cloudy dark patches at three sizes, each
    `stretch` times longer along the board than across it (`scale` makes them smaller)."""
    total = np.zeros_like(X)
    for i, (weight, across) in enumerate(zip((0.5, 0.32, 0.18), (5, 12, 34))):
        n = max(1, int(across * scale))
        along = max(1, int(n * BOARD_L / (stretch * 2.0 * UV_HALF_SPAN)))
        total = total + weight * value_noise(X, T, seed + i, n, along)
    return smoothstep(0.38, 0.72, total)


def board_picture_grid(width: int, height: int):
    """(X, T) in metres for every pixel of a board picture."""
    u = (np.arange(width) + 0.5) / width
    v_image = (np.arange(height) + 0.5) / height
    X = np.broadcast_to(((u - 0.5) * 2.0 * UV_HALF_SPAN)[None, :], (height, width))
    T = np.broadcast_to(((1.0 - v_image) * BOARD_L)[:, None], (height, width))
    return X, T


def draw_board_pictures(deck_path: Path, bottom_path: Path, width: int = 512, height: int = 2048) -> None:
    X, T = board_picture_grid(width, height)
    # The deck.
    carbon = streaks(X, T, seed=72)
    image = DECK_PURPLE + (DECK_PURPLE_DARK - DECK_PURPLE) * (0.85 * carbon)[..., None]
    nose_dark = smoothstep(1.6, 2.28, T)[..., None] * 0.25   # the front is a little darker
    image = image + (DECK_PURPLE_DARK - image) * nose_dark
    # The tail graphic, fading in over 12 cm.
    tail = (1.0 - smoothstep(TAIL_GRAPHIC_FROM - 0.12, TAIL_GRAPHIC_FROM, T))[..., None]
    fine = streaks(X, T, seed=7, stretch=8.0, scale=2.5)[..., None]
    navy = TAIL_NAVY + (DECK_PURPLE_DARK - TAIL_NAVY) * 0.3 * fine
    orange = TAIL_ORANGE + (np.array([150, 70, 130], dtype=float) - TAIL_ORANGE) * 0.55 * fine
    half = np.where((X < 0.0)[..., None], navy, orange)
    half = half + (TAIL_RED - half) * (1.0 - smoothstep(0.06, 0.14, T))[..., None]
    image = image + (half - image) * tail
    # Our letters where JP has "SLALOM S-TEC": orange on the navy half, across the board.
    letters = lettering_mask(X, T, "MMZB", origin=(-0.27, 0.55), height=0.05, stroke=0.009)
    image[letters] = LETTER_ORANGE
    # The mast track's recess: a darker oval with a dark rim (about 0.42 by 0.22 m on the photos).
    track_t = 0.5 * (MAST_TRACK_BACK + MAST_TRACK_FRONT)
    r = np.hypot(X / 0.11, (T - track_t) / 0.21)
    rim = smoothstep(0.75, 0.95, r) * (1.0 - smoothstep(1.0, 1.12, r))
    image = image + (np.array([78, 52, 118]) - image) * (1.0 - smoothstep(0.9, 1.0, r))[..., None] * 0.6
    image = image + (DECK_PURPLE_DARK * 0.7 - image) * rim[..., None] * 0.7
    write_png(deck_path, np.clip(image, 0, 255).astype(np.uint8))

    # The bottom.
    carbon = streaks(X, T, seed=117)
    image = BOTTOM_PURPLE + (DECK_PURPLE_DARK - BOTTOM_PURPLE) * (0.7 * carbon)[..., None]
    to_navy = (1.0 - smoothstep(0.7, 1.4, T))[..., None]
    lines = streaks(X, T, seed=3, stretch=12.0, scale=3.0)[..., None]
    navy = BOTTOM_NAVY + (np.array([95, 60, 140], dtype=float) - BOTTOM_NAVY) * 0.35 * lines
    image = image + (navy - image) * to_navy
    half_widths = np.array([half_width(float(t)) for t in T[:, 0]])[:, None]
    bottom_halves = np.array([bottom_half_width(float(t)) for t in T[:, 0]])[:, None]
    rail_band = (np.abs(X) > half_widths - 0.025) & (T < 0.55)
    shelf = (np.abs(X) > bottom_halves - 0.002) & (T < CUTOUT_LENGTH)
    image[rail_band | shelf] = RAIL_RED
    write_png(bottom_path, np.clip(image, 0, 255).astype(np.uint8))


# --------------------------------------------------------------------------------------------
# The fin.
# --------------------------------------------------------------------------------------------

FIN_SPAN = FIN["span_m"]
FIN_ROOT_CHORD = 0.14 * (FIN["area_m2"] / 0.0365) ** 0.5
FIN_TIP_CHORD = 0.37 * FIN_ROOT_CHORD
FIN_SWEEP = 0.30 * FIN_SPAN
FIN_EMBED = 0.015  # the root goes this far up into the board


def naca_thickness(x: float, ratio: float) -> float:
    """Half thickness of a symmetric NACA 4-digit foil (closed trailing edge), per chord."""
    return 5 * ratio * (0.2969 * math.sqrt(x) - 0.1260 * x - 0.3516 * x ** 2 + 0.2843 * x ** 3 - 0.1036 * x ** 4)


def fin_chord(s: float) -> float:
    """Chord at span fraction s (0 = root, 1 = tip), with a rounded tip."""
    chord = FIN_ROOT_CHORD + (FIN_TIP_CHORD - FIN_ROOT_CHORD) * s ** 1.1
    if s > 0.82:
        a = (s - 0.82) / 0.18
        chord *= math.sqrt(max(0.0, 1.0 - a * a))
    return chord


def build_fin() -> bpy.types.Object:
    b = MeshBuilder("Fin")
    chord_points = [0.5 - 0.5 * math.cos(math.pi * i / 14) for i in range(15)]  # LE to TE
    rings = []
    area = 0.0
    spans = [i / 30 for i in range(30)] + [0.985, 0.995]
    for s in spans:
        chord = max(fin_chord(s), 0.006)
        y = FIN_EMBED - s * (FIN_SPAN + FIN_EMBED)
        z_le = -0.45 * FIN_ROOT_CHORD + FIN_SWEEP * s ** 1.4
        ratio = 0.10 - 0.02 * s
        upper = [vec(naca_thickness(x, ratio) * chord, y, z_le + x * chord) for x in chord_points]
        lower = [vec(-p[0], p[1], p[2]) for p in upper[-2:0:-1]]
        rings.append([b.vertex(p) for p in upper + lower])
    loft(b, rings, "fin")
    cap(b, rings[0], vec(0, 1, 0), "fin")
    point_cap(b, rings[-1], vec(0, -FIN_SPAN, -0.45 * FIN_ROOT_CHORD + FIN_SWEEP + 0.004), "fin")
    for i in range(200):
        area += fin_chord((i + 0.5) / 200) * FIN_SPAN / 200
    print(f"Fin: span {FIN_SPAN:.2f} m, root chord {FIN_ROOT_CHORD:.3f} m, area {area:.4f} m2 "
          f"(config {FIN['area_m2']:.4f})")
    return b.build()


# --------------------------------------------------------------------------------------------
# The mast.
# --------------------------------------------------------------------------------------------

MAST_M = SAIL["mast_m"]
MAST_BOTTOM_RADIUS = 0.0245
MAST_TOP_RADIUS = 0.0135
MAST_START_Y = 0.165  # the mast's foot, on the extension's pulley block


def mast_radius(y: float) -> float:
    """The mast tapers, mostly in its top half (a constant-curve mast)."""
    s = min(1.0, max(0.0, (y - 0.3) / (MAST_M - 0.3)))
    return MAST_BOTTOM_RADIUS - (MAST_BOTTOM_RADIUS - MAST_TOP_RADIUS) * s ** 1.6


def build_mast() -> bpy.types.Object:
    b = MeshBuilder("Mast")
    # The rubber joint (tendon) on the base plate: it lets the rig tip any way.
    joint_y = [0.0, 0.012, 0.03, 0.048, 0.07]
    joint_r = [0.024, 0.024, 0.0185, 0.0185, 0.023]
    tube(b, [vec(0, y, 0) for y in joint_y], joint_r, "rubber", sides=16)
    # A short extension with the downhaul pulley block on top: a race sail's luff is as long
    # as its mast, so the tack sits low, close to the deck.
    tube(b, [vec(0, 0.065, 0), vec(0, 0.13, 0)], 0.0185, "metal", sides=16)
    superellipsoid(b, (0.0, 0.15, 0.0), (0.032, 0.025, 0.03), "hardware", roundness=0.5)
    # The mast itself, with a rounded top.
    ys = list(np.linspace(MAST_START_Y, MAST_M - 0.015, 40))
    radii = [mast_radius(y) for y in ys]
    for i in range(1, 5):
        a = i / 5 * math.pi / 2
        ys.append(MAST_M - 0.015 + 0.015 * math.sin(a))
        radii.append(MAST_TOP_RADIUS * math.cos(a) + 0.002)
    rings = tube(b, [vec(0, y, 0) for y in ys], radii, "carbon", sides=16, caps=False)
    point_cap(b, rings[-1], vec(0, MAST_M, 0), "carbon")
    return b.build()


# --------------------------------------------------------------------------------------------
# The sail: the Severne HGO iQFOiL 8.0.
# --------------------------------------------------------------------------------------------
# What is measured, and where:
# - Severne's own table (severnesails.com/sails/hgo-hyper-glide-iqfoil/): the 8.0 has a 522 cm
#   luff and a 220 cm boom, 7 battens, cams on the lower four (#4 an SDM cam, #5 to #7 XL), a
#   fixed head, on the Apex 490 mast with a 36 cm race extension. The battens' lengths, top (#1)
#   to bottom (#7): 720, 992, 1342, 1737, 1965, 2112 and 1780 mm.
# - Zhang et al. 2025 (Documentation/Science/2501.13254v1.pdf): the largest chord 2 m, seven full
#   battens and five short ones in the leech between the upper six; their figure 1 shows the
#   sail rigged in the wind tunnel.
# - Severne's flat drawing of the 8.0 (on windfoilen.nl), traced row by row: the heights of the
#   battens, the panels and the windows as fractions of the luff from the tack (DRAWING_H), and
#   the chords as fractions of the clew's chord. It is to scale: the batten lengths above plus
#   0.12 m for a cam (or 0.18 m of sleeve without one) match it within 3 %.
# - Max's photo (Documentation/images/Real life photos/IMG_4743.jpeg), the paper's figure 1 and
#   Severne's studio photo: red monofilm; a clear panel around the boom between the luff panel
#   and the leech; a narrow "action window" by the luff, across the boom; a black and white
#   graphic in the leech above the boom (Severne's logo, here a plain stripe); the national flag
#   in the head and the sail number on a black box (Max's NED 61; ours says MMZB).
# What the config binds: the sail's head is 0.02 m under the masthead at SailConfig.mast_m (4.9 m,
# where the real 8.0's luff is 5.22 m) and its clew at boom_m (2.0 m from the mast, where the
# real chord at the clew is about 2.15 m) and boom_height_m (1.5 m), with the boom square to the
# mast. So the model is the HGO's outline at about 0.94 of its height and 0.93 of its width, and
# its area comes out under the configured 8.0 m2 (printed when this runs). With the real 8.0's
# luff, mast and boom in the config, the same code builds the full-size sail.
# The game bends the mast (mast_bend.gdshaderinc, by RigVisuals.MAST_BEND_AFT_M from the boom
# up) and moves every height of the sail back with it. The cloth here is flat, so it is drawn
# that much forward of the outline the rigged sail should show: the leech below is straight when
# rigged, as on the photos.

BOOM_M = SAIL["boom_m"]
BOOM_H = SAIL["boom_height_m"]
TACK_Y = 0.19       # the bottom of the luff, just above the pulley block
TOP_Y = MAST_M - 0.02   # RigVisuals.SAIL_HEAD_BELOW_MAST_TOP_M
LUFF_H = TOP_Y - TACK_Y
MAST_BEND_AFT_M = read_gd_constant(RIG_VISUALS, "MAST_BEND_AFT_M")
BEND_START_Y = BOOM_H   # RigVisuals sets the shader's mast_bend_start_m to the boom's height


def drawing_y(h: float) -> float:
    """The height on the game's luff of a fraction h of the drawing's luff (tack 0, head 1)."""
    return TACK_Y + h * LUFF_H


# The drawing's chord at 0.28 of the luff, the game's clew height, is 0.963 of its clew's: that
# chord is the game's boom_m.
CHORD_PER_DRAWING = BOOM_M / 0.963


def mast_bend(y):
    """How far the game bends the mast back at height y (the same formula as mast_bend.gdshaderinc)."""
    s = np.clip((np.asarray(y, dtype=float) - BEND_START_Y) / (MAST_M - BEND_START_Y), 0.0, 1.0)
    return MAST_BEND_AFT_M * s * s


# The head's aft corner (the drawing: 0.952 of the luff up, 0.384 of the clew's chord back from
# the mast) and the foot. The foot's aft corner is 0.865 of the clew's chord back (the drawing);
# how high it sits differs between the sources (the drawing about 0.2 m over the tack, the studio
# photo more, seen from below): an estimate, chosen so the area stays near the configured one.
HEAD_Y = drawing_y(0.952)
HEAD_X = 0.384 * CHORD_PER_DRAWING
FOOT_AFT_X = 0.865 * CHORD_PER_DRAWING
FOOT_AFT_Y = TACK_Y + 0.21          # estimate
FOOT_SAG = 0.03                     # estimate: the foot bows down a little between its corners
LOWER_LEECH_BULGE = 0.05            # estimate: the leech under the clew bows out a little
ROACH_M = 0.03                      # estimate: the leech bows out this much behind the straight line, rigged
# The full battens, #1 (top) to #7: their luff end and leech end heights. From the drawing, except
# where the game's square boom binds them: #6 ends at the clew (it does on the drawing and in the
# wind tunnel), #7 just over the foot's aft corner.
FULL_BATTENS = [
    (drawing_y(0.919), HEAD_Y - 0.01),
    (drawing_y(0.814), drawing_y(0.823)),
    (drawing_y(0.686), drawing_y(0.675)),
    (drawing_y(0.551), drawing_y(0.519)),
    (drawing_y(0.401), drawing_y(0.353)),
    (drawing_y(0.241), BOOM_H),
    (drawing_y(0.114), FOOT_AFT_Y + 0.12),
]
SHORT_BATTEN_M = 0.35   # the short leech battens' length (the drawing: about 0.3 to 0.4 m)
CAMBERED_BELOW_Y = FULL_BATTENS[3][0]   # the cams are on #4 to #7: the sleeve is deep below #4


def bezier2(p0, p1, p2, count: int) -> np.ndarray:
    t = np.linspace(0.0, 1.0, count)[:, None]
    return (1 - t) ** 2 * np.array(p0) + 2 * (1 - t) * t * np.array(p1) + t ** 2 * np.array(p2)


def build_outer_edge():
    """The sail's free edge in the flat cloth, from the tack along the foot, up the leech under
    the clew, through the clew and up the leech to the head's aft corner. Returns the points and
    the index where the foot ends."""
    tack, aft, clew = np.array([0.0, TACK_Y]), np.array([FOOT_AFT_X, FOOT_AFT_Y]), np.array([BOOM_M, BOOM_H])
    d = aft - tack
    down = np.array([d[1], -d[0]]) / np.linalg.norm(d)
    foot = bezier2(tack, 0.5 * (tack + aft) + 2 * FOOT_SAG * down, aft, 80)
    d = clew - aft
    out = np.array([d[1], -d[0]]) / np.linalg.norm(d)
    lower = bezier2(aft, 0.5 * (aft + clew) + 2 * LOWER_LEECH_BULGE * out, clew, 60)
    ys = np.linspace(BOOM_H, HEAD_Y, 240)
    f = (ys - BOOM_H) / (HEAD_Y - BOOM_H)
    head_rigged_x = HEAD_X + float(mast_bend(HEAD_Y))
    rigged_x = BOOM_M + f * (head_rigged_x - BOOM_M) + ROACH_M * np.sin(np.pi * f)
    leech = np.stack([rigged_x - mast_bend(ys), ys], axis=1)
    return np.concatenate([foot, lower[1:], leech[1:]]), len(foot) - 1


OUTER, FOOT_END = build_outer_edge()
OUTER_P = np.concatenate([[0.0], np.cumsum(np.linalg.norm(np.diff(OUTER, axis=0), axis=1))])
CLIMB = OUTER[FOOT_END:]          # the edge from the foot's aft corner up: its height only grows
CLIMB_P = OUTER_P[FOOT_END:]


def outer_at(p) -> np.ndarray:
    p = np.asarray(p, dtype=float)
    return np.stack([np.interp(p, OUTER_P, OUTER[:, 0]), np.interp(p, OUTER_P, OUTER[:, 1])], axis=-1)


def leech_x(y) -> np.ndarray:
    """Where the sail's aft edge is at a height y (above the foot's aft corner)."""
    return np.interp(y, CLIMB[:, 1], CLIMB[:, 0])


def p_at_height(y: float) -> float:
    return float(np.interp(y, CLIMB[:, 1], CLIMB_P))


# The rows of the grid run along the battens: a row starting at a height on the luff ends at the
# point of the free edge these anchors give (linear between them), so every full batten is a row.
ANCHOR_LUFF_Y = [TACK_Y] + [luff for luff, _ in reversed(FULL_BATTENS)] + [TOP_Y]
ANCHOR_P = [0.0] + [p_at_height(leech) for _, leech in reversed(FULL_BATTENS)] + [float(OUTER_P[-1])]
ROW_SPACING = 0.085   # m up the luff
COLUMNS = 40          # grid columns from the luff to the leech


def row_heights() -> list:
    """The rows' heights on the luff: about ROW_SPACING apart at the luff and at the free edge
    (under #7 the rows fan out from the luff over the whole foot, so there are more)."""
    ys = [TACK_Y]
    for a, b, pa, pb in zip(ANCHOR_LUFF_Y, ANCHOR_LUFF_Y[1:], ANCHOR_P, ANCHOR_P[1:]):
        n = max(3, int(math.ceil(max(b - a, 0.6 * (pb - pa)) / ROW_SPACING)))
        ys += list(np.linspace(a, b, n + 1)[1:])
    return ys


ROW_VS = [(y - TACK_Y) / LUFF_H for y in row_heights()]


def luff_point(v) -> np.ndarray:
    v = np.asarray(v, dtype=float)
    return np.stack([np.zeros_like(v), TACK_Y + v * LUFF_H], axis=-1)


def outer_point(v) -> np.ndarray:
    """The end of the grid row starting at v on the luff: on the foot, the leech or the head's
    aft corner."""
    luff_y = TACK_Y + np.asarray(v, dtype=float) * LUFF_H
    return outer_at(np.interp(luff_y, ANCHOR_LUFF_Y, ANCHOR_P))


def sail_point(u, v) -> np.ndarray:
    """A point of the flat sail (x along the boom, y up the mast) from its (u, v)."""
    u = np.asarray(u, dtype=float)[..., None]
    return luff_point(v) + u * (outer_point(v) - luff_point(v))


def sail_outline() -> np.ndarray:
    """The flat sail's outline: down the luff, along the free edge to the head's corner, and
    along the head back to the masthead."""
    luff = np.stack([np.zeros(50), np.linspace(TOP_Y, TACK_Y, 50)], axis=1)
    return np.concatenate([luff, OUTER[1:]])


def polygon_area_centroid(pts: np.ndarray) -> tuple:
    x, y = pts[:, 0], pts[:, 1]
    x1, y1 = np.roll(x, -1), np.roll(y, -1)
    cross = x * y1 - x1 * y
    area = 0.5 * np.sum(cross)
    return abs(area), float(np.sum((x + x1) * cross) / (6 * area)), float(np.sum((y + y1) * cross) / (6 * area))


# --- The panels, in the flat sail's metres (x back from the mast, y up from the mast foot) ---

def batten_line(index: int):
    """The full batten `index` (0 is #1 at the top) as a segment from the luff to the leech."""
    luff_y, leech_y = FULL_BATTENS[index]
    return np.array([0.0, luff_y]), np.array(outer_at(p_at_height(leech_y)))


def batten_y(index: int, X):
    """The height of batten `index`'s line over x (held level beyond its ends)."""
    a, b = batten_line(index)
    s = np.clip(X / max(b[0], 1e-6), 0.0, 1.0)
    return a[1] + s * (b[1] - a[1])


# The luff panel (the darker red band with a fine mesh along the luff sleeve, the action window in
# it): its aft edge from the drawing, (height fraction, x as a fraction of the clew's chord).
LUFF_PANEL_EDGE = [(0.0, 0.17), (0.103, 0.182), (0.222, 0.242), (0.276, 0.247), (0.388, 0.252),
                   (0.543, 0.207), (0.684, 0.155), (0.816, 0.095), (0.926, 0.065), (1.0, 0.04)]


def luff_panel_x(Y):
    return CHORD_PER_DRAWING * np.interp((Y - TACK_Y) / LUFF_H, [h for h, _ in LUFF_PANEL_EDGE],
                                         [x for _, x in LUFF_PANEL_EDGE])


# The foot panel's top seam (the drawing: 0.109 of the luff at the luff panel, 0.121 aft).
def foot_panel_y(X):
    return drawing_y(0.109) + (drawing_y(0.121) - drawing_y(0.109)) * np.clip(X / FOOT_AFT_X, 0.0, 1.0)


# The action window: a narrow slanted window by the luff, across the boom (the drawing: from 0.17
# to 0.36 of the luff, 0.17 to 0.22 of the clew's chord back; about 0.1 m wide). Its clear part,
# counter-clockwise, and its dark border.
WINDOW = [(0.305, drawing_y(0.166)), (0.395, drawing_y(0.178)), (0.445, drawing_y(0.361)), (0.355, drawing_y(0.353))]
WINDOW_BORDER = 0.025
SEAM = 0.02             # the red seam around the clear panel
LEECH_STRIP = 0.06      # the red along the leech, outside the clear panel
# The stripe in the leech above the boom, where the HGO has Severne's black and white logo: from
# the leech at 0.48 of the luff to 0.56 of the clew's chord at 0.35 of the luff (the logo's upper
# arm on the drawing).
STRIPE_FROM = (None, drawing_y(0.48))
STRIPE_TO = (0.559 * CHORD_PER_DRAWING, drawing_y(0.347))
STRIPE_HALF_W = 0.085
STRIPE_WHITE_HALF_W = 0.035
# The sail numbers' black boxes (Max's photo: NED 61 on a black box between two battens over half
# way up, from the luff panel to well into the sail): ours say MMZB. A race sail carries them on
# both sides, the starboard side's higher (the racing rules, appendix G), each printed on its
# own side: the mesh's front (+z) is the sail's port side, so the port box reads from the front
# and the starboard box is drawn mirrored, to read from the back. The shader shows a box faintly
# from its other side, as it shows through the cloth.
NUMBER_BOX_STARBOARD = (0.36, drawing_y(0.565), 1.28, drawing_y(0.645))   # x0, y0, x1, y1
NUMBER_BOX_PORT = (0.36, drawing_y(0.433), 1.28, drawing_y(0.513))
# The national flag in the head panel, between #2 and #1 (Max's sail has the Dutch flag there;
# iQFOiL sails carry their nation's flag). None leaves the head red.
HEAD_FLAG = ((174, 28, 40), (245, 245, 245), (33, 70, 139))


def stripe_ends():
    y0 = STRIPE_FROM[1]
    start = np.array([float(leech_x(y0)) + 0.15, y0 + 0.06])   # it runs out over the leech
    return start, np.array(STRIPE_TO)


def clear_film(X, Y):
    """Where the sail is clear film: the clear panel around the boom and the action window."""
    # The red along the leech widens around the clew, where the sail has its clew patch.
    leech_red = LEECH_STRIP + 0.22 * np.exp(-((Y - BOOM_H) / 0.22) ** 2)
    panel = ((X > luff_panel_x(Y) + SEAM) & (Y > foot_panel_y(X) + SEAM) & (Y < batten_y(4, X) - SEAM)
             & (X < leech_x(np.maximum(Y, FOOT_AFT_Y)) - leech_red))
    window = convex_distance(X, Y, WINDOW) < 0.0
    return panel | window


def near_clear_film(x: float, y: float, margin: float = 0.05) -> bool:
    offsets = [(dx, dy) for dx in (-margin, 0.0, margin) for dy in (-margin, 0.0, margin)]
    X = np.array([x + dx for dx, _ in offsets])
    Y = np.array([y + dy for _, dy in offsets])
    return bool(np.any(clear_film(X, Y)))


def build_sail_cloth() -> bpy.types.Object:
    b = MeshBuilder("SailCloth")
    rows = []
    points = []
    for r, v in enumerate(ROW_VS):
        chord = float(np.linalg.norm(outer_point(v) - luff_point(v)))
        if r == 0:  # the tack: every row starts here
            rows.append([b.vertex(vec(0.0, TACK_Y, 0.0), (0.0, 0.0), (0.0, 0.0))] * (COLUMNS + 1))
            points.append([np.array([0.0, TACK_Y])] * (COLUMNS + 1))
            continue
        row = []
        row_points = []
        for k in range(COLUMNS + 1):
            u = k / COLUMNS
            x, y = sail_point(u, v)
            row.append(b.vertex(vec(x, y, 0.0), (u, v), (chord, 0.0)))
            row_points.append(np.array([x, y]))
        rows.append(row)
        points.append(row_points)
    windows = 0
    for r in range(len(rows) - 1):
        for k in range(COLUMNS):
            corners = [points[r][k], points[r][k + 1], points[r + 1][k + 1], points[r + 1][k]]
            centre = np.mean(corners, axis=0)
            clear = any(near_clear_film(float(p[0]), float(p[1])) for p in corners + [centre])
            material = "sail_window" if clear else "sail_cloth"
            windows += clear
            if r == 0:  # a fan of triangles from the tack
                b.face([rows[0][0], rows[1][k], rows[1][k + 1]], material)
            else:
                b.face([rows[r][k], rows[r][k + 1], rows[r + 1][k + 1], rows[r + 1][k]], material)
    # Front face toward +z (it is drawn from both sides, but keep it tidy).
    b.face_toward(0, len(b.faces), vec(0, 0, 1))
    build_sleeve(b)
    area, centre_x, centre_y = polygon_area_centroid(sail_outline())
    print(f"Sail: {len(ROW_VS)} rows x {COLUMNS} columns, {windows} cells of clear film")
    print(f"Sail: outline area {area:.2f} m2 (config {SAIL['area_m2']:.2f}); head's corner {HEAD_X:.2f} m "
          f"back at {HEAD_Y:.2f} m, foot's aft corner {FOOT_AFT_X:.2f} m back at {FOOT_AFT_Y:.2f} m")
    print(f"Sail: area centre {centre_y:.2f} m up the mast ({centre_y / SAIL['luff_m']:.2f} of the luff) and "
          f"{centre_x:.2f} m back ({centre_x / BOOM_M:.2f} of the boom), flat; the mast's bend moves it "
          f"{float(mast_bend(centre_y)):.2f} m back when rigged")
    for i, (luff_y, leech_y) in enumerate(FULL_BATTENS):
        a, b_end = batten_line(i)
        print(f"Sail: batten #{i + 1} from {luff_y:.2f} m at the mast to {leech_y:.2f} m at the leech, "
              f"{float(np.linalg.norm(b_end - a)):.2f} m")
    return b.build(uv2=True)


def build_sleeve(b: MeshBuilder) -> None:
    """The luff sleeve: a teardrop tube around the mast that runs into the sail, deep where the
    battens have cams (#4 to #7). It is part of the cloth (same (u, v) and chord), so the shader
    bends it with the sail."""
    radius = 0.034
    rings = []
    for v in ROW_VS:
        chord = float(np.linalg.norm(outer_point(v) - luff_point(v)))
        y = float(luff_point(v)[1])
        depth = 0.20 if y <= CAMBERED_BELOW_Y else 0.20 - 0.09 * (y - CAMBERED_BELOW_Y) / (TOP_Y - CAMBERED_BELOW_Y)
        tail_x = max(0.05, min(depth, 0.7 * chord))
        tangent_angle = math.acos(radius / tail_x)
        pts = [(tail_x, 0.0)]
        for i in range(13):
            a = tangent_angle + (2 * math.pi - 2 * tangent_angle) * i / 12
            pts.append((radius * math.cos(a), radius * math.sin(a)))
        ring = []
        for x, z in pts:
            u = max(x, 0.0) / chord if chord > 0.01 else 0.0
            ring.append(b.vertex(vec(x, y, z), (u, v), (chord, 0.0)))
        rings.append(ring)
    loft(b, rings, "sail_sleeve")
    point_cap(b, rings[-1], vec(0.0, TOP_Y + 0.012, 0.0), "sail_sleeve", tip_uv=(0.0, 1.0))


def build_clew_ring() -> bpy.types.Object:
    """The eyelet at the clew the outhaul is tied to."""
    b = MeshBuilder("SailClewRing")
    path = [vec(BOOM_M - 0.02 + 0.02 * math.cos(a), BOOM_H + 0.02 * math.sin(a), 0.0)
            for a in np.linspace(0, 2 * math.pi, 17)]
    tube(b, path[:-1] + [path[0] + vec(0, 1e-4, 0)], 0.005, "metal", sides=8)
    return b.build()


def build_tack_fairing() -> bpy.types.Object:
    """Severne's thermoformed tack fairing: the black moulded cover at the bottom of the luff,
    over the tack and the top of the extension (its size an estimate from the photos)."""
    b = MeshBuilder("TackFairing")
    superellipsoid(b, (0.045, TACK_Y + 0.03, 0.0), (0.09, 0.075, 0.04), "fairing", roundness=0.6, sides=20)
    return b.build()


# --- The sail's picture ---------------------------------------------------------------------
HGO_RED = (196, 18, 24)        # the cloth (MATERIALS["sail_cloth"])
LUFF_RED = (172, 14, 22)       # the luff panel, darker, with a fine mesh
MESH_RED = (150, 10, 18)
HEAD_RED = (210, 30, 34)       # the seamless head panel, a little lighter
FOOT_RED = (204, 26, 30)
FOOT_LETTERS = (228, 66, 64)   # the big outlined letters in the foot (the HGO's "GO"; ours 8.0)
POCKET_RED = (140, 10, 16)     # the batten pockets
TAPE_RED = (120, 8, 14)        # the leech tape and the clew patch
BLACK = (24, 24, 28)
WHITE = (240, 240, 243)
CLEAR = (200, 205, 212)        # under the clear film (only seen if the film ends on a cloth cell)
# The alpha (sail_cloth.gdshaderinc reads it): the sail's own cloth, a print seen from both sides,
# a print on the front (port) side only, on the back (starboard) side only, clear film.
OWN, PRINT, FRONT_PRINT, BACK_PRINT, FILM = 255, 191, 140, 90, 0


def draw_sail_panels(path: Path, width: int = 1024, height: int = 2048) -> None:
    """The sail's colours as a picture in (u, v): pixel column = u (luff on the left), pixel
    row = 1 - v (head at the top). Everything is placed in metres on the flat sail."""
    u = (np.arange(width) + 0.5) / width
    v = 1.0 - (np.arange(height) + 0.5) / height
    luff = luff_point(v)                      # (H, 2)
    outer = outer_point(v)                    # (H, 2)
    chord = np.linalg.norm(outer - luff, axis=-1)[:, None]          # (H, 1)
    U = np.broadcast_to(u[None, :], (height, width))
    P = luff[:, None, :] + U[..., None] * (outer - luff)[:, None, :]
    X, Y = P[..., 0], P[..., 1]
    from_edge = (1 - U) * chord      # metres from the leech or the foot along the row

    image = np.empty((height, width, 4), dtype=np.uint8)

    def paint(mask, colour, alpha=OWN):
        image[mask] = (*colour, alpha)

    image[:] = (*HGO_RED, OWN)
    # The head panel above #1, the foot panel under its seam, the luff panel with its mesh.
    paint(Y > batten_y(0, X), HEAD_RED)
    foot = Y < foot_panel_y(X)
    paint(foot, FOOT_RED)
    luff_panel = X < luff_panel_x(Y)
    paint(luff_panel, LUFF_RED)
    mesh = ((np.mod(X + Y, 0.03) < 0.004) | (np.mod(X - Y, 0.03) < 0.004)) & luff_panel
    paint(mesh, MESH_RED)
    # Big outlined letters in the foot panel, low on contrast, as the HGO's "GO".
    letters = lettering_mask(X, Y, "8.0", origin=(0.62, FOOT_AFT_Y + 0.02), height=0.30, stroke=0.035)
    inner = lettering_mask(X, Y, "8.0", origin=(0.62, FOOT_AFT_Y + 0.02), height=0.30, stroke=0.012)
    paint(foot & letters & ~inner, FOOT_LETTERS)
    # The flag in the head panel.
    if HEAD_FLAG is not None:
        low, high = batten_y(1, X), batten_y(0, X)
        f = (Y - low) / np.maximum(high - low, 1e-6)
        between = (f >= 0.0) & (f <= 1.0) & (X > 0.06)
        paint(between & (f >= 2 / 3), HEAD_FLAG[0], PRINT)
        paint(between & (f >= 1 / 3) & (f < 2 / 3), HEAD_FLAG[1], PRINT)
        paint(between & (f < 1 / 3), HEAD_FLAG[2], PRINT)
    # The sail numbers' boxes, one printed on each side.
    for (x0, y0, x1, y1), alpha, mirrored in ((NUMBER_BOX_PORT, FRONT_PRINT, False),
                                              (NUMBER_BOX_STARBOARD, BACK_PRINT, True)):
        paint((X > x0) & (X < x1) & (Y > y0) & (Y < y1), BLACK, alpha)
        letter_h = 0.7 * (y1 - y0)
        half_text = 0.5 * text_length("MMZB", letter_h)
        middle = 0.5 * (x0 + x1)
        origin = (middle + half_text if mirrored else middle - half_text, y0 + 0.15 * (y1 - y0))
        letters = lettering_mask(X, Y, "MMZB", origin=origin, height=letter_h, stroke=0.045,
                                 along=(-1.0, 0.0) if mirrored else (1.0, 0.0))
        paint(letters, WHITE, alpha)
    # The clear film, then the stripe printed over the panel and the red over the leech.
    paint(clear_film(X, Y), CLEAR, FILM)
    window_distance = convex_distance(X, Y, WINDOW)
    paint((window_distance >= 0.0) & (window_distance < WINDOW_BORDER), BLACK, PRINT)
    start, end = stripe_ends()
    distance, _ = segment_distance(X, Y, start, end)
    paint(distance < STRIPE_HALF_W, BLACK, PRINT)
    paint(distance < STRIPE_WHITE_HALF_W, WHITE, PRINT)
    # The batten pockets (full ones from the sleeve to the leech, the short ones in from the
    # leech between the upper six), with the tensioners' black caps at the leech.
    pockets = []
    for i in range(len(FULL_BATTENS)):
        a, b_end = batten_line(i)
        pockets.append((a + np.array([0.06, 0.0]), b_end))
    for i in range(5):
        _, upper = batten_line(i)
        _, lower = batten_line(i + 1)
        end = outer_at(p_at_height(0.5 * (upper[1] + lower[1])))
        direction = (upper - batten_line(i)[0]) + (lower - batten_line(i + 1)[0])
        direction = direction / np.linalg.norm(direction)
        pockets.append((end - SHORT_BATTEN_M * direction, end))
    for a, b_end in pockets:
        distance, along = segment_distance(X, Y, a, b_end)
        length = float(np.linalg.norm(b_end - a))
        paint(distance < 0.016, POCKET_RED)
        paint((distance < 0.02) & (along * length > length - 0.07), BLACK, PRINT)
    # The leech tape and the clew's patch, the foot's black moulded edge, the head's cap.
    above_foot = Y > FOOT_AFT_Y - 0.02
    paint(above_foot & (from_edge < 0.014), TAPE_RED)
    paint(~above_foot & (from_edge < 0.015), BLACK, PRINT)
    paint(np.hypot(X - BOOM_M, Y - BOOM_H) < 0.16, TAPE_RED)
    paint(np.hypot(X, Y - TOP_Y) < 0.10, BLACK, PRINT)
    write_png(path, image)


def write_png(path: Path, pixels: np.ndarray) -> None:
    """A plain 8-bit RGB or RGBA PNG (top row first)."""
    height, width, channels = pixels.shape
    raw = b"".join(b"\x00" + pixels[row].tobytes() for row in range(height))

    def chunk(tag: bytes, data: bytes) -> bytes:
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

    colour_type = 6 if channels == 4 else 2
    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, colour_type, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b"")
    path.write_bytes(png)


# --------------------------------------------------------------------------------------------
# The boom.
# --------------------------------------------------------------------------------------------

GRIP_START = 0.12
GRIP_END = 0.68 * BOOM_M
BOOM_TUBE_RADIUS = 0.0145
BOOM_GRIP_RADIUS = 0.0165


def boom_arm_path(side: float) -> list:
    """One arm of the wishbone in the boom's plane (y = 0), z = side x half width: out from
    the boom head in front of the mast, widest about a third back, in to the tail end."""
    xs = [-0.12, -0.07, 0.05, 0.25, 0.32 * BOOM_M, 0.52 * BOOM_M, 0.75 * BOOM_M, 0.95 * BOOM_M, BOOM_M + 0.10]
    zs = [0.02, 0.10, 0.185, 0.25, 0.285, 0.272, 0.205, 0.105, 0.035]
    return catmull_rom([vec(x, 0.0, side * z) for x, z in zip(xs, zs)], 12)


def arm_half_width(x: float) -> float:
    path = boom_arm_path(1.0)
    return float(np.interp(x, [p[0] for p in path], [p[2] for p in path]))


def split_path(path: list, x0: float, x1: float) -> list:
    """The part of a path between x0 and x1 (the arm runs steadily aft, so x orders it)."""
    xs = np.array([p[0] for p in path])
    inside = [p for p in path if x0 < p[0] < x1]
    start = np.array([np.interp(x0, xs, [p[i] for p in path]) for i in range(3)])
    end = np.array([np.interp(x1, xs, [p[i] for p in path]) for i in range(3)])
    return [start] + inside + [end]


def build_boom() -> bpy.types.Object:
    b = MeshBuilder("Boom")
    # The boom head in front of the mast, and the clamp around the mast.
    superellipsoid(b, (-0.105, 0.0, 0.0), (0.07, 0.034, 0.045), "hardware", roundness=0.45)
    tube(b, [vec(0, -0.04, 0), vec(0, 0.04, 0)], 0.036, "hardware", sides=20)
    # The tail end behind the clew, where the arms meet.
    superellipsoid(b, (BOOM_M + 0.13, 0.0, 0.0), (0.065, 0.022, 0.042), "carbon", roundness=0.5)
    for side in (-1.0, 1.0):
        arm = boom_arm_path(side)
        tube(b, split_path(arm, -0.2, GRIP_START + 0.01), BOOM_TUBE_RADIUS, "carbon", caps=False)
        tube(b, split_path(arm, GRIP_START, GRIP_END), BOOM_GRIP_RADIUS, "boom_grip")
        tube(b, split_path(arm, GRIP_END - 0.01, BOOM_M + 0.2), BOOM_TUBE_RADIUS, "carbon", caps=False)
        build_harness_line(b, side)
    # The outhaul: two strands from the clew to the tail end.
    for dy in (-0.006, 0.006):
        tube(b, [vec(BOOM_M - 0.005, dy, 0.0), vec(BOOM_M + 0.09, dy, 0.0)], 0.0035, "rope", sides=6)
    return b.build()


def build_harness_line(b: MeshBuilder, side: float) -> None:
    """A harness line loop hanging under one arm, centred on the hand grip."""
    grip = SAILOR["hand_grip_m"]
    x_front, x_back = grip - 0.17, grip + 0.17
    sag = 0.30
    path = []
    for i in range(29):
        s = i / 28
        x = x_front + (x_back - x_front) * s
        y = -BOOM_GRIP_RADIUS - sag * math.sin(math.pi * s) ** 0.8
        path.append(vec(x, y, side * arm_half_width(x)))
    tube(b, path, 0.004, "rope", sides=6)
    tube(b, path[8:21], 0.0085, "harness_hose", sides=10)


# --------------------------------------------------------------------------------------------
# Export.
# --------------------------------------------------------------------------------------------

def export_glb(objects: list, path: Path) -> None:
    for other in bpy.context.scene.objects:
        other.select_set(False)
    for obj in objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    bpy.ops.export_scene.gltf(
        filepath=str(path),
        export_format="GLB",
        use_selection=True,
        export_yup=True,
        export_apply=False,
        export_normals=True,
        export_texcoords=True,
        export_materials="EXPORT",
        export_cameras=False,
        export_lights=False,
    )
    print(f"Wrote {path.relative_to(REPO)}")


def main() -> None:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    export_glb([build_hull(), build_deck_pads(), build_footstraps(), build_fin_box(), build_mast_track()],
               OUT_DIR / "board.glb")
    draw_board_pictures(OUT_DIR / "board_deck.png", OUT_DIR / "board_bottom.png")
    print("Wrote Game/assets/models/board_deck.png and board_bottom.png")
    export_glb([build_fin()], OUT_DIR / "fin.glb")
    export_glb([build_mast()], OUT_DIR / "mast.glb")
    export_glb([build_sail_cloth(), build_clew_ring(), build_tack_fairing()], OUT_DIR / "sail.glb")
    export_glb([build_boom()], OUT_DIR / "boom.glb")
    draw_sail_panels(OUT_DIR / "sail_panels.png")
    print(f"Wrote {(OUT_DIR / 'sail_panels.png').relative_to(REPO)}")


if __name__ == "__main__":
    main()
    sys.stdout.flush()
