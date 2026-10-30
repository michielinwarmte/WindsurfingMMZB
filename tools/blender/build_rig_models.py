"""Builds the 3D models of the windsurf equipment for the game (plan Phase 6, "Rig visuals"):
the board, the fin, the mast, the sail and the boom, from the numbers in Game/config/.

Run it from the repository root, after changing a size in Game/config/ for example:

    tools/blender.sh tools/blender/build_rig_models.py

It writes into Game/assets/models/ (one .glb file per part, so each part can be placed on
its own; RigVisuals in Game/windsurfer/rig_visuals.gd puts them together):

    board.glb   The board: "Hull" (with the deck, the deck pad, the bow accent and the
                coloured bottom as materials), "Footstraps", "MastTrack". Origin: the centre
                of the board at mid-thickness, where the simulation has it. The bow points to
                Godot -Z, the deck up (+Y): the deck is at y = +thickness/2 at the mast foot.
    fin.glb     "Fin": a swept fin with a foil section. Origin: the fin root
                (FinConfig.root_local); the fin hangs down (-Y), the leading edge forward (-Z).
    mast.glb    "Mast": the mast with the extension and the rubber joint. Origin: the mast
                foot; the mast runs up +Y.
    sail.glb    "SailCloth": the sail as a dense grid, with three materials (surfaces):
                sail_cloth, sail_window and sail_sleeve (the luff sleeve around the mast), and
                "SailClewRing". Origin: the mast foot; the luff runs up +Y along the mast and
                the boom along +X, so the clew is at (boom_m, boom_height_m, 0). The cloth is
                flat here: res://windsurfer/sail_cloth.gdshader bends it in the game (belly,
                twist, flutter). Its UV is (u, 1 - v): u runs from the luff (0) to the leech or
                the foot (1) along a batten line, v from the tack (0) to the head (1). UV2.x is
                the length of that batten line (the chord) in metres.
    boom.glb    "Boom": the wishbone with the grip, the harness lines and the outhaul. Origin:
                the mast axis at boom height; the boom runs along +X to the clew.
    sail_panels.png  The sail's colours (panels, battens, window border, the MMZB letters),
                drawn here pixel by pixel in the sail's (u, v) coordinates: the head at the top
                of the picture, the luff on the left.

The legacy Unity models (Legacy/WindsurfingGame/Assets/Models/Board.fbx and Sail.fbx) were
the reference for the shapes, but they had the bow along +X, little detail (the sail had 140
vertices, the mast no faces), a stray camera and brand photos as textures. So the shapes are
rebuilt here from the configured dimensions, with our own colours.

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


BOARD = read_config("board_default.tres", {
    "length_m": 2.40, "width_m": 0.72, "thickness_m": 0.12,
    "widest_point_from_tail_m": 1.10, "tail_width_m": 0.45, "nose_width_m": 0.45,
    "tail_thickness_m": 0.055, "nose_thickness_m": 0.04,
    "hard_rail_to_m": 1.2, "soft_rail_from_m": 2.0,
    "nose_rocker_m": 0.08, "nose_rocker_length_m": 0.9,
    "tail_rocker_m": 0.01, "tail_rocker_length_m": 0.35,
})
ONE_FOOT_M = 0.3048  # where a shaper measures the nose and tail widths (BoardConfig.ONE_FOOT_M)
SAIL = read_config("sail_default.tres", {
    "area_m2": 6.5, "luff_m": 4.60, "boom_m": 1.95, "boom_height_m": 1.40,
    "mast_foot_local": (0.0, 0.06, -0.10), "mast_m": 4.60, "camber": 0.10,
})
FIN = read_config("fin_default.tres", {"area_m2": 0.0365, "span_m": 0.38, "root_local": (0.0, -0.06, 0.90)})
SAILOR = read_config("sailor_default.tres", {"hand_grip_m": 0.6})

# Colours are sRGB, as a designer picks them: (colour, roughness, metallic).
MATERIALS = {
    "board_deck": ((0.94, 0.94, 0.92), 0.4, 0.0),
    "board_bottom": ((0.05, 0.26, 0.50), 0.3, 0.0),
    "board_accent": ((0.98, 0.45, 0.08), 0.4, 0.0),
    "deck_pad": ((0.10, 0.10, 0.11), 0.95, 0.0),
    "strap": ((0.07, 0.08, 0.10), 0.8, 0.0),
    "hardware": ((0.12, 0.12, 0.13), 0.5, 0.0),
    "metal": ((0.72, 0.73, 0.75), 0.3, 1.0),
    "carbon": ((0.035, 0.035, 0.04), 0.3, 0.0),
    "rubber": ((0.05, 0.05, 0.05), 0.85, 0.0),
    "boom_grip": ((0.30, 0.31, 0.33), 0.95, 0.0),
    "rope": ((0.86, 0.86, 0.83), 0.8, 0.0),
    "harness_hose": ((0.98, 0.45, 0.08), 0.5, 0.0),
    "fin": ((0.06, 0.06, 0.07), 0.3, 0.0),
    "sail_cloth": ((0.93, 0.94, 0.96), 0.55, 0.0),
    "sail_window": ((0.85, 0.90, 0.95), 0.1, 0.0),
    "sail_sleeve": ((0.13, 0.13, 0.15), 0.6, 0.0),
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
    """Closes a ring with a fan around its centre. With `flat`, the cap gets its own vertices,
    so it has a sharp edge with the surface around it."""
    if flat:
        ring = [builder.vertex(builder.verts[i]) for i in ring]
    centre = builder.vertex(np.mean([builder.verts[i] for i in ring], axis=0))
    first = len(builder.faces)
    for k in range(len(ring)):
        builder.face([centre, ring[k], ring[(k + 1) % len(ring)]], material, not flat)
    if np.dot(builder.face_normal(first), outward) < 0.0:
        builder.flip(first, len(builder.faces))


def point_cap(builder: MeshBuilder, ring: list, tip: np.ndarray, material: str) -> None:
    """Closes a ring with a fan to a tip point (a nose or a fin tip), smooth shaded."""
    tip_index = builder.vertex(tip)
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


# --------------------------------------------------------------------------------------------
# The board.
# --------------------------------------------------------------------------------------------

BOARD_L = BOARD["length_m"]
BOARD_HALF_W = 0.5 * BOARD["width_m"]
BOARD_THICK = BOARD["thickness_m"]
MAST_FOOT = np.array(SAIL["mast_foot_local"], dtype=float)

# Where the deck pad and the bow colour start and end, metres forward of the transom.
PAD_START_T = 0.08
PAD_END_T = BOARD_L / 2 - MAST_FOOT[2] - 0.20  # 0.20 m behind the mast foot
ACCENT_START_T = 0.82 * BOARD_L
RING_POINTS = 48


def board_z(t: float) -> float:
    """Godot z of a point `t` metres forward of the transom (the bow is -z)."""
    return 0.5 * BOARD_L - t


def bottom_rise(t: float) -> float:
    """The rocker: the same formula as BoardConfig.bottom_rise_m."""
    if t < BOARD["tail_rocker_length_m"]:
        a = (BOARD["tail_rocker_length_m"] - t) / BOARD["tail_rocker_length_m"]
        return BOARD["tail_rocker_m"] * a * a
    nose_start = BOARD_L - BOARD["nose_rocker_length_m"]
    if t > nose_start:
        n = (t - nose_start) / BOARD["nose_rocker_length_m"]
        return BOARD["nose_rocker_m"] * n * n
    return 0.0


def outline_width(t: float) -> float:
    """The physics' outline, the same formula as BoardConfig.width_at: a parabola from the
    widest point to the widths one foot off the tail and the nose, straight on along its
    tangent from there to the tips."""
    widest = BOARD["widest_point_from_tail_m"]
    if t <= widest:
        reference_width, reference_distance, distance = BOARD["tail_width_m"], widest - ONE_FOOT_M, widest - t
    else:
        reference_width, reference_distance, distance = BOARD["nose_width_m"], BOARD_L - ONE_FOOT_M - widest, t - widest
    reference_distance = max(reference_distance, 0.01)
    narrowing = BOARD["width_m"] - reference_width
    if distance <= reference_distance:
        return BOARD["width_m"] - narrowing * (distance / reference_distance) ** 2
    slope = 2.0 * narrowing / reference_distance
    return max(reference_width - slope * (distance - reference_distance), 0.0)


def half_width(t: float) -> float:
    """The outline seen from above: the physics' outline (a square pin tail, widest at
    widest_point_from_tail_m), with the tail's corners rounded and the nose closing to a
    rounded point over its last foot. (The physics runs the outline straight on from the
    one-foot point to a 0.285 m nose tip, its coarsest row; a real nose curves to a point
    there, out of the water when planing. The cap times the physics' width is 1, with no
    kink, at the one-foot point and 0 at the tip.)"""
    w = 0.5 * outline_width(t)
    cap_start = BOARD_L - ONE_FOOT_M
    if t > cap_start:
        a = (t - cap_start) / ONE_FOOT_M
        w *= max(0.0, 1.0 - a * a)
    corner = 0.04
    if t < corner:
        w = w - corner + math.sqrt(max(0.0, corner * corner - (corner - t) ** 2))
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
    deck centre, half round the port rail, three quarters the bottom centre."""
    w, y_bottom, y_rail, y_deck = section(t)
    low = bottom_exponent(t)
    pts = []
    for k in range(RING_POINTS):
        a = 2 * math.pi * k / RING_POINTS
        c, s = math.cos(a), math.sin(a)
        n = DECK_EXPONENT if s >= 0 else low
        x = w * math.copysign(abs(c) ** (2 / n), c)
        if s >= 0:
            y = y_rail + (y_deck - y_rail) * abs(s) ** (2 / n)
        else:
            y = y_rail - (y_rail - y_bottom) * abs(s) ** (2 / n)
        pts.append(vec(x, y, board_z(t)))
    return pts


def board_stations() -> list:
    special = [PAD_START_T, PAD_END_T, ACCENT_START_T]
    tip = [BOARD_L - d for d in (0.03, 0.02, 0.013, 0.008, 0.004, 0.0015)]
    stations = list(np.linspace(0.0, BOARD_L - 0.04, 96)) + special + tip
    stations.sort()
    kept = []
    for t in stations:
        if kept and t - kept[-1] < 0.004:
            if t in special:
                kept[-1] = t
            continue
        kept.append(t)
    return kept


PAD_EDGE_POINTS = 3  # the pad stops this many ring points in from the rail (about 0.9 of the half width)


def hull_material(stations: list):
    def material(i: int, k: int) -> str:
        t = 0.5 * (stations[i] + stations[i + 1])
        if k >= RING_POINTS // 2:
            return "board_bottom"
        if PAD_START_T <= t <= PAD_END_T and PAD_EDGE_POINTS <= k < RING_POINTS // 2 - PAD_EDGE_POINTS:
            return "deck_pad"
        if t >= ACCENT_START_T:
            return "board_accent"
        return "board_deck"
    return material


def build_hull() -> bpy.types.Object:
    b = MeshBuilder("Hull")
    stations = board_stations()
    rings = [[b.vertex(p) for p in hull_ring_points(t)] for t in stations]
    loft(b, rings, hull_material(stations))
    # The transom: a flat face at the tail. The nose: the rings close to a point.
    cap(b, rings[0], vec(0, 0, 1), "board_bottom")
    _, _, y_rail, _ = section(BOARD_L)
    point_cap(b, rings[-1], vec(0, y_rail, board_z(BOARD_L)), "board_accent")
    return b.build()


FRONT_STRAP_T = BOARD_L / 2 - MAST_FOOT[2] - 0.34
BACK_STRAP_T = 0.22 * BOARD_L
STRAPS = [  # (x, t): two front straps either side, two back straps further out
    (-0.17, FRONT_STRAP_T), (0.17, FRONT_STRAP_T),
    (-0.21, BACK_STRAP_T), (0.21, BACK_STRAP_T),
]


def build_footstraps() -> bpy.types.Object:
    """Padded arches over the deck, screwed down in front of and behind the foot."""
    b = MeshBuilder("Footstraps")
    profile = [(math.copysign(abs(c) ** 0.4, c), math.copysign(abs(s) ** 0.4, s)) for c, s in circle(16)]
    half_span = 0.085
    height = 0.065
    for x, t in STRAPS:
        base_y = deck_y(x, t)
        path = []
        scales = []
        for i in range(25):
            phi = math.radians(-12.0 + 204.0 * i / 24)
            path.append(vec(x, base_y + height * math.sin(phi), board_z(t) - half_span * math.cos(phi)))
            pad = 0.5 + 0.5 * math.sin(max(0.0, min(math.pi, phi)))  # thicker padding on top
            scales.append((0.028, 0.006 + 0.007 * pad))
        sweep(b, path, profile, scales, "strap", up_hint=vec(1, 0, 0))
        # The screw plugs at both ends.
        for end in (-1, 1):
            z = board_z(t) + end * half_span
            plug = [vec(x, base_y - 0.002, z), vec(x, base_y + 0.004, z)]
            tube(b, plug, 0.014, "hardware", sides=10)
    return b.build()


def build_mast_track() -> bpy.types.Object:
    """The mast track (a slot in the deck the mast base slides in) and the base plate."""
    b = MeshBuilder("MastTrack")
    foot_z = MAST_FOOT[2]
    half_length = 0.17
    half_width_track = 0.024
    # A stadium shape seen from above: two half circles joined by straight sides.
    front_centre = foot_z - half_length + half_width_track
    back_centre = foot_z + half_length - half_width_track
    outline = []
    for i in range(10):
        a = math.pi + math.pi * i / 9   # the front half circle, from port round to starboard
        outline.append((half_width_track * math.cos(a), front_centre + half_width_track * math.sin(a)))
    for i in range(10):
        a = math.pi * i / 9             # the back half circle, from starboard round to port
        outline.append((half_width_track * math.cos(a), back_centre + half_width_track * math.sin(a)))
    deck = 0.5 * BOARD_THICK
    bottom = [b.vertex(vec(x, deck - 0.004, z)) for x, z in outline]
    top = [b.vertex(vec(x, deck + 0.0025, z)) for x, z in outline]
    loft(b, [bottom, top], "hardware", smooth=False)
    cap(b, top, vec(0, 1, 0), "hardware")
    # The base plate in the track, which the mast's rubber joint stands on.
    plate = [vec(0, deck - 0.002, foot_z), vec(0, MAST_FOOT[1] + 0.012, foot_z)]
    tube(b, plate, 0.04, "rubber", sides=20)
    return b.build()


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
    # The extension: an aluminium tube with the downhaul pulley block on top.
    tube(b, [vec(0, 0.065, 0), vec(0, 0.25, 0)], 0.0185, "metal", sides=16)
    superellipsoid(b, (0.0, 0.275, 0.0), (0.032, 0.035, 0.03), "hardware", roundness=0.5)
    # The mast itself, with a rounded top.
    ys = list(np.linspace(0.29, MAST_M - 0.015, 40))
    radii = [mast_radius(y) for y in ys]
    for i in range(1, 5):
        a = i / 5 * math.pi / 2
        ys.append(MAST_M - 0.015 + 0.015 * math.sin(a))
        radii.append(MAST_TOP_RADIUS * math.cos(a) + 0.002)
    rings = tube(b, [vec(0, y, 0) for y in ys], radii, "carbon", sides=16, caps=False)
    point_cap(b, rings[-1], vec(0, MAST_M, 0), "carbon")
    return b.build()


# --------------------------------------------------------------------------------------------
# The sail: outline, grid, luff sleeve, and the panel picture.
# --------------------------------------------------------------------------------------------

BOOM_M = SAIL["boom_m"]
BOOM_H = SAIL["boom_height_m"]
TACK_Y = 0.30       # the bottom of the luff (the extension's pulley block is below it)
TOP_Y = MAST_M - 0.02
HEAD_WIDTH = 0.14
FOOT_ROWS = 10      # grid rows from the tack up to the boom
UPPER_ROWS = 30     # grid rows from the boom to the head
COLUMNS = 24        # grid columns from the luff to the leech
BOOM_V = (BOOM_H - TACK_Y) / (TOP_Y - TACK_Y)
BATTEN_ROWS = [8, 15, 21, 27, 32, 37]
WINDOWS = [  # (first row, last row + 1, first column, last column + 1)
    (11, 15, 2, 11),   # the main window just above the boom
    (3, 8, 3, 12),     # the lower window, to see under the boom
]


def bezier(ctrl: np.ndarray, t: np.ndarray) -> np.ndarray:
    t = np.asarray(t, dtype=float)[..., None]
    p0, p1, p2, p3 = ctrl
    return (1 - t) ** 3 * p0 + 3 * (1 - t) ** 2 * t * p1 + 3 * (1 - t) * t ** 2 * p2 + t ** 3 * p3


class Curve:
    """A cubic Bezier curve walked at an even speed: at(f) is the point a fraction f of the
    way along it."""

    def __init__(self, ctrl):
        self.ctrl = np.array(ctrl, dtype=float)
        ts = np.linspace(0.0, 1.0, 4001)
        pts = bezier(self.ctrl, ts)
        cumulative = np.concatenate([[0.0], np.cumsum(np.linalg.norm(np.diff(pts, axis=0), axis=1))])
        self.length = cumulative[-1]
        self.ts = ts
        self.fractions = cumulative / cumulative[-1]

    def at(self, f):
        return bezier(self.ctrl, np.interp(f, self.fractions, self.ts))


# The foot drops from the tack to close to the deck, then rises to the clew (cut away under
# the clew). The leech is convex (the roach the battens hold out) up to a narrow head.


def foot_curve(depth: float) -> Curve:
    """The foot. At depth 0 it rises from near the deck to the clew along the sail's diagonal
    (a 6.5's cut); at 1 it runs low along the deck to 90 % of the boom and rises to the clew
    there, as a race sail's foot closes the gap to the deck."""
    return Curve([(0.0, TACK_Y), (0.18 * BOOM_M, TACK_Y - 0.42),
                  ((0.74 + 0.16 * depth) * BOOM_M, 0.42 * (1.0 - depth) * BOOM_H), (BOOM_M, BOOM_H)])


FOOT = foot_curve(0.0)


def leech_curve(roach: float) -> Curve:
    """The leech, its two middle control points held out by `roach` times their place for a
    6.5 (1.0): the roach the battens hold out, which is what gives a slalom sail its area for
    its luff and boom."""
    return Curve([(BOOM_M, BOOM_H), (1.01 * roach * BOOM_M, BOOM_H + 0.36 * (TOP_Y - BOOM_H)),
                  (0.62 * roach * BOOM_M, TOP_Y - 0.10), (HEAD_WIDTH, TOP_Y - 0.03)])


LEECH = leech_curve(1.0)


def row_v(r: int) -> float:
    if r <= FOOT_ROWS:
        return BOOM_V * r / FOOT_ROWS
    return BOOM_V + (1.0 - BOOM_V) * (r - FOOT_ROWS) / UPPER_ROWS


def luff_point(v) -> np.ndarray:
    v = np.asarray(v, dtype=float)
    return np.stack([np.zeros_like(v), TACK_Y + v * (TOP_Y - TACK_Y)], axis=-1)


def outer_point(v) -> np.ndarray:
    """The end of the batten line at v: on the foot below the boom, on the leech above it."""
    v = np.asarray(v, dtype=float)
    on_foot = FOOT.at(np.clip(v / BOOM_V, 0.0, 1.0))
    on_leech = LEECH.at(np.clip((v - BOOM_V) / (1.0 - BOOM_V), 0.0, 1.0))
    return np.where((v <= BOOM_V)[..., None], on_foot, on_leech)


def sail_point(u, v) -> np.ndarray:
    """A point of the flat sail (x along the boom, y up the mast) from its (u, v)."""
    u = np.asarray(u, dtype=float)[..., None]
    return luff_point(v) + u * (outer_point(v) - luff_point(v))


def sail_outline() -> np.ndarray:
    """The flat sail's outline: down the luff, then along the foot and up the leech."""
    outline = [luff_point(row_v(r)) for r in range(FOOT_ROWS + UPPER_ROWS, -1, -1)]
    outline += [outer_point(row_v(r)) for r in range(0, FOOT_ROWS + UPPER_ROWS + 1)]
    return np.array(outline)


def sail_area() -> float:
    x, y = sail_outline()[:, 0], sail_outline()[:, 1]
    return 0.5 * abs(np.dot(x, np.roll(y, -1)) - np.dot(y, np.roll(x, -1)))


# The configured area (PH16 step 17: the 8.0's 4.9 m luff and 2.0 m boom with a 6.5's cut drew
# 7.0 m2). A race sail gets its area from a foot close to the deck, so the foot is filled
# first, then the roach grows (a roach alone made the leech a D, Max: "this is not the 8.0?").
# Bisections: the area grows with each.
def _solve(make, low: float, high: float) -> float:
    for _ in range(40):
        middle = 0.5 * (low + high)
        make(middle)
        if sail_area() < SAIL["area_m2"]:
            low = middle
        else:
            high = middle
    make(high)
    return high


def _set_foot(depth: float) -> None:
    global FOOT
    FOOT = foot_curve(depth)


def _set_roach(roach: float) -> None:
    global LEECH
    LEECH = leech_curve(roach)


FOOT_DEPTH, ROACH = 0.0, 1.0
_set_foot(FOOT_DEPTH)
_set_roach(ROACH)
if sail_area() < SAIL["area_m2"]:
    _set_foot(1.0)
    if sail_area() >= SAIL["area_m2"]:
        FOOT_DEPTH = _solve(_set_foot, 0.0, 1.0)
    else:
        FOOT_DEPTH = 1.0
        ROACH = _solve(_set_roach, 1.0, 1.8)
print(f"Sail: foot depth {FOOT_DEPTH:.2f}, roach {ROACH:.3f} times a 6.5's")


def sail_centroid() -> tuple:
    """The centre of the sail's area (x along the boom, y up the mast), m: where the wind's
    push acts on a flat sail (PHYSICS_SPEC.md, OPEN 2.4 asks for it)."""
    pts = sail_outline()
    x, y = pts[:, 0], pts[:, 1]
    x1, y1 = np.roll(x, -1), np.roll(y, -1)
    cross = x * y1 - x1 * y
    area = 0.5 * np.sum(cross)
    return float(np.sum((x + x1) * cross) / (6 * area)), float(np.sum((y + y1) * cross) / (6 * area))


def in_window(r: int, k: int) -> bool:
    return any(r0 <= r < r1 and k0 <= k < k1 for r0, r1, k0, k1 in WINDOWS)


def build_sail_cloth() -> bpy.types.Object:
    b = MeshBuilder("SailCloth")
    rows = []
    for r in range(FOOT_ROWS + UPPER_ROWS + 1):
        v = row_v(r)
        chord = float(np.linalg.norm(outer_point(v) - luff_point(v)))
        if r == 0:  # the tack: every batten line starts here
            rows.append([b.vertex(vec(0.0, TACK_Y, 0.0), (0.0, 0.0), (0.0, 0.0))] * (COLUMNS + 1))
            continue
        row = []
        for k in range(COLUMNS + 1):
            u = k / COLUMNS
            x, y = sail_point(u, v)
            row.append(b.vertex(vec(x, y, 0.0), (u, v), (chord, 0.0)))
        rows.append(row)
    for r in range(len(rows) - 1):
        for k in range(COLUMNS):
            material = "sail_window" if in_window(r, k) else "sail_cloth"
            if r == 0:  # a fan of triangles from the tack
                b.face([rows[0][0], rows[1][k], rows[1][k + 1]], material)
            else:
                b.face([rows[r][k], rows[r][k + 1], rows[r + 1][k + 1], rows[r + 1][k]], material)
    # Front face toward +z (it is drawn from both sides, but keep it tidy).
    for f in range(len(b.faces)):
        if b.face_normal(f)[2] < 0.0:
            b.faces[f].reverse()
    build_sleeve(b)
    centre_x, centre_y = sail_centroid()
    print(f"Sail: area centre {centre_y:.2f} m up the mast ({centre_y / SAIL['luff_m']:.2f} of the luff) and "
          f"{centre_x:.2f} m back ({centre_x / BOOM_M:.2f} of the boom)")
    print(f"Sail: outline area {sail_area():.2f} m2 (config {SAIL['area_m2']:.2f}), "
          f"lowest point of the foot {float(np.min(FOOT.at(np.linspace(0, 1, 200))[:, 1])):.2f} m above the deck")
    return b.build(uv2=True)


def build_sleeve(b: MeshBuilder) -> None:
    """The luff sleeve: a teardrop tube around the mast that runs into the sail. It is part
    of the cloth (same (u, v) and chord), so the shader bends it with the sail."""
    radius = 0.034
    rings = []
    for r in range(FOOT_ROWS + UPPER_ROWS + 1):
        v = row_v(r)
        chord = float(np.linalg.norm(outer_point(v) - luff_point(v)))
        y = float(luff_point(v)[1])
        tail_x = max(0.05, min(0.11, 0.7 * chord))
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
    point_cap(b, rings[-1], vec(0.0, TOP_Y + 0.012, 0.0), "sail_sleeve")
    # The cap's tip vertex needs the sail's (u, v) too: it sits on the luff at the head.
    b.uv[-1] = (0.0, 1.0)


def build_clew_ring() -> bpy.types.Object:
    """The eyelet at the clew the outhaul is tied to."""
    b = MeshBuilder("SailClewRing")
    path = [vec(BOOM_M - 0.02 + 0.02 * math.cos(a), BOOM_H + 0.02 * math.sin(a), 0.0)
            for a in np.linspace(0, 2 * math.pi, 17)]
    tube(b, path[:-1] + [path[0] + vec(0, 1e-4, 0)], 0.005, "metal", sides=8)
    return b.build()


# The colours of the panels, sRGB 0..255.
WHITE = (236, 238, 242)
NAVY = (18, 40, 92)
BLUE = (22, 86, 168)
ICE = (150, 200, 225)
ORANGE = (250, 115, 22)
CHARCOAL = (34, 35, 40)
POCKET = (52, 54, 62)
PATCH = (150, 154, 165)


def draw_sail_panels(path: Path, width: int = 1024, height: int = 2048) -> None:
    """The sail's colours as a picture in (u, v): pixel column = u (luff on the left), pixel
    row = 1 - v (head at the top). Widths are worked out in metres on the sail."""
    u = (np.arange(width) + 0.5) / width
    v = 1.0 - (np.arange(height) + 0.5) / height
    luff = luff_point(v)                      # (H, 2)
    outer = outer_point(v)                    # (H, 2)
    chord = np.linalg.norm(outer - luff, axis=-1)[:, None]          # (H, 1)
    U = np.broadcast_to(u[None, :], (height, width))
    P = luff[:, None, :] + U[..., None] * (outer - luff)[:, None, :]
    X, Y = P[..., 0], P[..., 1]
    # Metres per unit of v on the sail at each pixel (to draw bands of a given width).
    dv = 1e-3
    d_luff = (luff_point(v + dv) - luff_point(v - dv)) / (2 * dv)
    d_outer = (outer_point(np.clip(v + dv, 0, 1)) - outer_point(np.clip(v - dv, 0, 1))) / (2 * dv)
    dP = (1 - U)[..., None] * d_luff[:, None, :] + U[..., None] * d_outer[:, None, :]
    metres_per_v = np.linalg.norm(dP, axis=-1)
    from_luff = U * chord            # metres from the luff along the batten line
    from_edge = (1 - U) * chord      # metres from the leech or foot

    image = np.empty((height, width, 3), dtype=np.uint8)
    image[:] = WHITE

    def paint(mask, colour):
        image[mask] = colour

    # Panels fanning out from the clew, as the cloth is laid out on a real sail.
    angle = np.degrees(np.arctan2(Y - BOOM_H, X - BOOM_M))
    above = Y >= BOOM_H - 0.02
    paint(above & (angle > 92) & (angle < 106), BLUE)
    paint(above & (angle >= 106) & (angle < 111), ORANGE)
    paint(above & (angle >= 111) & (angle < 119), ICE)
    paint(Y > TOP_Y - 0.75, NAVY)
    paint((Y > TOP_Y - 0.80) & (Y <= TOP_Y - 0.75), ORANGE)
    # Below the boom: a blue band along the foot and an orange line above it.
    below = ~above
    paint(below & (from_edge < 0.30), BLUE)
    paint(below & (from_edge >= 0.30) & (from_edge < 0.36), ORANGE)

    # The letters MMZB on the upper sail, in strokes (x, y in metres on the sail), in the white
    # part between the luff sleeve and the coloured panels.
    letter_h = 0.28
    letter_w = 0.62 * letter_h
    gap = 0.065
    stroke = 0.045
    base_y = TACK_Y + 0.52 * (TOP_Y - TACK_Y)
    base_x = 0.22
    glyphs = {  # strokes in a unit box: (0, 0) bottom left, (1, 1) top right
        "M": [((0, 0), (0, 1)), ((0, 1), (0.5, 0.45)), ((0.5, 0.45), (1, 1)), ((1, 1), (1, 0))],
        "Z": [((0, 1), (1, 1)), ((1, 1), (0, 0)), ((0, 0), (1, 0))],
        "B": [((0, 0), (0, 1)), ((0, 1), (0.7, 1)), ((0.7, 1), (0.9, 0.88)), ((0.9, 0.88), (0.9, 0.64)),
              ((0.9, 0.64), (0.7, 0.52)), ((0, 0.52), (0.72, 0.52)), ((0.72, 0.52), (1, 0.38)),
              ((1, 0.38), (1, 0.14)), ((1, 0.14), (0.75, 0)), ((0.75, 0), (0, 0))],
    }
    for i, letter in enumerate("MMZB"):
        x0 = base_x + i * (letter_w + gap)
        for (ax, ay), (bx, by) in glyphs[letter]:
            a = np.array([x0 + ax * letter_w, base_y + ay * letter_h])
            d = np.array([(bx - ax) * letter_w, (by - ay) * letter_h])
            t = np.clip(((X - a[0]) * d[0] + (Y - a[1]) * d[1]) / max(np.dot(d, d), 1e-9), 0, 1)
            dist = np.hypot(X - (a[0] + t * d[0]), Y - (a[1] + t * d[1]))
            paint(dist < 0.5 * stroke, NAVY)

    # Reinforcement patches at the clew and the tack.
    paint(np.hypot(X - BOOM_M, Y - BOOM_H) < 0.22, PATCH)
    paint(np.hypot(X, Y - TACK_Y) < 0.30, PATCH)

    # The windows' borders (the windows themselves are a clear material on the mesh).
    for r0, r1, k0, k1 in WINDOWS:
        v0, v1 = row_v(r0), row_v(r1)
        u0, u1 = k0 / COLUMNS, k1 / COLUMNS
        inside = (U >= u0) & (U <= u1) & (v[:, None] >= v0) & (v[:, None] <= v1)
        border_u = 0.025 / chord
        border_v = 0.025 / metres_per_v
        grown = ((U >= u0 - border_u) & (U <= u1 + border_u)
                 & (v[:, None] >= v0 - border_v) & (v[:, None] <= v1 + border_v))
        paint(grown & ~inside, CHARCOAL)
        paint(inside, (200, 205, 212))

    # Batten pockets along the batten lines, with the tensioner caps at the leech.
    for r in BATTEN_ROWS:
        distance = np.abs(v[:, None] - row_v(r)) * metres_per_v
        pocket = (distance < 0.022) & (from_luff > 0.10)
        paint(pocket, POCKET)
        paint((distance < 0.028) & (from_edge < 0.08), CHARCOAL)

    # Tape along the leech and the foot, the head, and the luff sleeve (hidden by the sleeve).
    paint(from_edge < 0.014, CHARCOAL)
    paint(Y > TOP_Y - 0.06, CHARCOAL)
    paint(from_luff < 0.10, CHARCOAL)

    write_png(path, image)


def write_png(path: Path, rgb: np.ndarray) -> None:
    """A plain 8-bit RGB PNG (top row first)."""
    height, width, _ = rgb.shape
    raw = b"".join(b"\x00" + rgb[row].tobytes() for row in range(height))

    def chunk(tag: bytes, data: bytes) -> bytes:
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0))
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
    export_glb([build_hull(), build_footstraps(), build_mast_track()], OUT_DIR / "board.glb")
    export_glb([build_fin()], OUT_DIR / "fin.glb")
    export_glb([build_mast()], OUT_DIR / "mast.glb")
    export_glb([build_sail_cloth(), build_clew_ring()], OUT_DIR / "sail.glb")
    export_glb([build_boom()], OUT_DIR / "boom.glb")
    draw_sail_panels(OUT_DIR / "sail_panels.png")
    print(f"Wrote {(OUT_DIR / 'sail_panels.png').relative_to(REPO)}")


if __name__ == "__main__":
    main()
    sys.stdout.flush()
