"""Builds the game terrain of the Silvaplana map in Blender (MAP_SILVAPLANA_PLAN.md, M1 and MD3).

Reads the height grids that tools/map/heights.py wrote to .map_data/work/terrain/ and, for each
chunk:
  1. builds a mesh with one vertex per grid point (2 m near the lake, up to 40 m far away),
  2. thins it out with Blender's Decimate modifier: flat ground (the deep lakebed, meadows) loses
     most of its triangles, ridges and banks keep theirs. The chunk's border is locked, so the
     neighbouring chunks still meet exactly,
  3. hangs a "skirt" around it: a strip that goes straight down from the border, under the ground.
     You never see it, unless Godot's far-away version of a chunk opens a hairline gap to its
     neighbour: then you see the skirt instead of the sky. It is a second mesh in the .glb,
     "<chunk>_skirt", which Godot keeps from casting shadows (MapTerrain),
  4. sets the shading normals from the height grid, so the light doesn't show the chunk borders,
  5. exports it as .glb to Game/maps/silvaplana/terrain/.
At the end it writes terrain.tscn (all chunks in one Godot scene) and renders two pictures from
above to .screenshots/: terrain_blender.png (everything) and terrain_blender_band.png (the lake).

Generated files: never edit them by hand, the next build overwrites them (MD3).

Axes as in every map script (plan MD1): Blender X = east, Y = north, Z = up, in metres, with the
origin in the middle of the lake and Z = 0 at the lake surface. The glTF export turns this into
Godot's X = east, Y = up, Z = -north.

Run (from the repo root): tools/blender.sh tools/blender/build_terrain.py [--only=<chunk name part>] [--no-render]
"""
import json
import sys
import time
from pathlib import Path

import bmesh
import bpy
import numpy as np

REPO_ROOT = Path(__file__).resolve().parents[2]
DATA = REPO_ROOT / ".map_data" / "work" / "terrain"
OUT = REPO_ROOT / "Game" / "maps" / "silvaplana" / "terrain"
SCREENSHOTS = REPO_ROOT / ".screenshots"
GODOT_DIR = "res://maps/silvaplana/terrain"

# The grey of the terrain until the aerial photos come (M2). Linear colour values: 0.17 shows as
# a middle grey on screen (lighter, and the sunny slopes look like snow).
TERRAIN_GREY = (0.17, 0.17, 0.16, 1.0)
# When thinning, any edge that touches the border costs this much extra, so the border stays.
BORDER_LOCK = 1000.0


def script_args() -> list[str]:
    return sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []


class ChunkGrid:
    """One chunk's heights from heights.py: its vertex grid, and where it lies in map coordinates."""

    def __init__(self, chunk: dict, origin_east: float, origin_north: float) -> None:
        data = np.load(DATA / chunk["file"])
        self.halo = data["heights"]          # vertices plus one extra ring, for the slopes at the border
        self.cells = data["cells"]           # which grid cells belong to this chunk
        self.heights = self.halo[1:-1, 1:-1]
        self.cell = chunk["cell_m"]
        self.size = chunk["size_m"]
        self.west = chunk["west_m"] - origin_east    # map X of the first vertex column
        self.north = chunk["north_m"] - origin_north  # map Y of the first vertex row

    def normals(self) -> np.ndarray:
        """The surface normal at every vertex, from the slope to its neighbours (rows x columns x 3)."""
        h = self.halo
        slope_east = (h[1:-1, 2:] - h[1:-1, :-2]) / (2.0 * self.cell)
        slope_north = (h[:-2, 1:-1] - h[2:, 1:-1]) / (2.0 * self.cell)  # row 0 is the north edge
        normals = np.stack([-slope_east, -slope_north, np.ones_like(slope_east)], axis=-1)
        return normals / np.linalg.norm(normals, axis=-1, keepdims=True)

    def normal_at(self, x: np.ndarray, y: np.ndarray, normals: np.ndarray) -> np.ndarray:
        """Normals at any map positions, interpolated between the grid's vertices."""
        last = self.heights.shape[0] - 1
        fx = np.clip((x - self.west) / self.cell, 0.0, last)
        fy = np.clip((self.north - y) / self.cell, 0.0, last)
        x0 = np.minimum(np.floor(fx).astype(int), last - 1)
        y0 = np.minimum(np.floor(fy).astype(int), last - 1)
        tx, ty = (fx - x0)[:, None], (fy - y0)[:, None]
        top = normals[y0, x0] * (1.0 - tx) + normals[y0, x0 + 1] * tx
        bottom = normals[y0 + 1, x0] * (1.0 - tx) + normals[y0 + 1, x0 + 1] * tx
        result = top * (1.0 - ty) + bottom * ty
        return result / np.linalg.norm(result, axis=-1, keepdims=True)


def build_mesh(name: str, grid: ChunkGrid) -> bpy.types.Object:
    """A mesh with a vertex at every grid point that a cell of this chunk touches, and a vertex
    group "inner" with the vertices that are not on the border (only those may be thinned)."""
    cells = grid.cells
    rows, columns = grid.heights.shape
    used = np.zeros((rows, columns), dtype=bool)
    inner = np.zeros((rows, columns), dtype=bool)
    for dr in (0, 1):
        for dc in (0, 1):
            used[dr:dr + cells.shape[0], dc:dc + cells.shape[1]] |= cells
    inner[1:-1, 1:-1] = cells[:-1, :-1] & cells[1:, :-1] & cells[:-1, 1:] & cells[1:, 1:]

    index = np.full((rows, columns), -1, dtype=np.int64)
    index[used] = np.arange(int(used.sum()))
    x = grid.west + np.arange(columns) * grid.cell
    y = grid.north - np.arange(rows) * grid.cell
    xx, yy = np.meshgrid(x, y)
    vertices = np.stack([xx[used], yy[used], grid.heights[used]], axis=-1).astype(np.float32)

    r, c = np.nonzero(cells)
    # Counter-clockwise seen from above (rows run to the south): south-west, south-east, north-east, north-west.
    quads = np.stack([index[r + 1, c], index[r + 1, c + 1], index[r, c + 1], index[r, c]], axis=-1)

    mesh = bpy.data.meshes.new(name)
    mesh.vertices.add(len(vertices))
    mesh.vertices.foreach_set("co", vertices.ravel())
    mesh.loops.add(quads.size)
    mesh.loops.foreach_set("vertex_index", quads.ravel().astype(np.int32))
    mesh.polygons.add(len(quads))
    mesh.polygons.foreach_set("loop_start", np.arange(0, quads.size, 4, dtype=np.int32))
    mesh.update(calc_edges=True)
    mesh.validate()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)

    group = obj.vertex_groups.new(name="inner")
    group.add(index[inner].tolist(), 1.0, "REPLACE")
    return obj


def thin_out(obj: bpy.types.Object, keep: float) -> None:
    """Blender's Decimate (collapse) keeps `keep` of the triangles, removing those that change the
    shape least. Vertices outside the "inner" group (the border) are as good as locked: every edge
    that touches them gets BORDER_LOCK times its length added to its cost."""
    modifier = obj.modifiers.new("thin_out", "DECIMATE")
    modifier.decimate_type = "COLLAPSE"
    modifier.ratio = keep
    modifier.use_collapse_triangulate = True
    modifier.vertex_group = "inner"
    modifier.vertex_group_factor = BORDER_LOCK
    depsgraph = bpy.context.evaluated_depsgraph_get()
    thinned = bpy.data.meshes.new_from_object(obj.evaluated_get(depsgraph))
    old = obj.data
    name = old.name
    obj.modifiers.remove(modifier)
    obj.data = thinned
    bpy.data.meshes.remove(old)
    thinned.name = name  # after removing the old mesh, or Blender would call it "name.001"


def make_skirt(obj: bpy.types.Object, depth: float) -> tuple[bpy.types.Object, int]:
    """A separate mesh "<chunk>_skirt": a strip that hangs `depth` straight down from the border
    edges. Its faces face outward (away from the chunk), because that is the side you would see
    them from through a gap. It is a mesh of its own so that Godot can keep it from casting
    shadows (MapTerrain): a skirt sticking out of a simpler far-away neighbour threw long dark
    bands across the slopes."""
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    vertices: list[tuple[float, float, float]] = []
    top_index: dict[int, int] = {}  # border vertex -> its top vertex in the skirt; the bottom one follows it

    def index_of(v: bmesh.types.BMVert) -> int:
        if v.index not in top_index:
            top_index[v.index] = len(vertices)
            vertices.append((v.co.x, v.co.y, v.co.z))
            vertices.append((v.co.x, v.co.y, v.co.z - depth))
        return top_index[v.index]

    faces = []
    for e in bm.edges:
        if not e.is_boundary:
            continue
        a, b = e.verts
        outward = (a.co + b.co) / 2.0 - e.link_faces[0].calc_center_median()
        # The quad a, b, b below, a below faces to the left of the direction a -> b.
        along = b.co - a.co
        if along.y * outward.x - along.x * outward.y > 0.0:  # outward is to the right: go b -> a
            a, b = b, a
        ia, ib = index_of(a), index_of(b)
        faces.append((ia, ib, ib + 1, ia + 1))
    bm.free()

    mesh = bpy.data.meshes.new(obj.name + "_skirt")
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    skirt = bpy.data.objects.new(obj.name + "_skirt", mesh)
    bpy.context.scene.collection.objects.link(skirt)
    return skirt, len(faces)


def finish_surface(obj: bpy.types.Object, grid: ChunkGrid) -> None:
    """Normals from the height grid (so neighbouring chunks agree at their border) and UVs that
    map the chunk's square onto one image (for the aerial photo in M2): u to the east, v to the north."""
    mesh = obj.data
    count = len(mesh.vertices)
    co = np.empty(count * 3, dtype=np.float32)
    mesh.vertices.foreach_get("co", co)
    co = co.reshape(-1, 3)
    normals = grid.normal_at(co[:, 0], co[:, 1], grid.normals())
    mesh.shade_smooth()
    mesh.normals_split_custom_set_from_vertices(normals.tolist())

    loop_vertices = np.empty(len(mesh.loops), dtype=np.int32)
    mesh.loops.foreach_get("vertex_index", loop_vertices)
    u = (co[loop_vertices, 0] - grid.west) / grid.size
    v = (co[loop_vertices, 1] - (grid.north - grid.size)) / grid.size
    uv_layer = mesh.uv_layers.new(name="UVMap")
    uv_layer.data.foreach_set("uv", np.stack([u, v], axis=-1).astype(np.float32).ravel())


def grey_material() -> bpy.types.Material:
    material = bpy.data.materials.new("terrain")
    material.use_nodes = True
    shader = material.node_tree.nodes["Principled BSDF"]
    shader.inputs["Base Color"].default_value = TERRAIN_GREY
    shader.inputs["Roughness"].default_value = 1.0
    material.diffuse_color = TERRAIN_GREY
    return material


def export_glb(objects: list[bpy.types.Object], path: Path) -> None:
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


def write_godot_scene(names: list[str]) -> None:
    """terrain.tscn: every chunk as an instance of its .glb, at the origin (the vertices are
    already in map coordinates). The MapTerrain script puts the aerial photos on them (M2)."""
    lines = ["[gd_scene format=3]", "",
             "; Generated by tools/blender/build_terrain.py: all terrain chunks of the map. Don't edit.", "",
             '[ext_resource type="Script" path="res://maps/map_terrain.gd" id="0_script"]']
    for i, name in enumerate(names, start=1):
        lines.append(f'[ext_resource type="PackedScene" path="{GODOT_DIR}/{name}.glb" id="{i}_{name}"]')
    lines += ["", '[node name="Terrain" type="Node3D"]', 'script = ExtResource("0_script")',
              f'photo_dir = "{GODOT_DIR}/photos"', ""]
    for i, name in enumerate(names, start=1):
        lines.append(f'[node name="{name}" parent="." instance=ExtResource("{i}_{name}")]')
    (OUT / "terrain.tscn").write_text("\n".join(lines) + "\n", encoding="utf-8")


def render_previews(objects: list[bpy.types.Object], band: tuple[float, float, float, float]) -> None:
    """Pictures from straight above with Blender's quick Workbench renderer: grey relief with
    shadows, and the lake as a blue plane at the water level."""
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    shading = scene.display.shading
    shading.light = "STUDIO"
    shading.color_type = "MATERIAL"
    shading.show_shadows = True
    shading.show_cavity = True
    shading.cavity_type = "WORLD"
    scene.display.light_direction = (-0.5, 0.4, 0.75)  # sun from the north-west, as on Swiss maps

    west, south, east, north = band
    bpy.ops.mesh.primitive_plane_add(size=1.0, location=((west + east) / 2, (south + north) / 2, 0.0))
    water = bpy.context.active_object
    water.scale = (east - west, north - south, 1.0)
    water_material = bpy.data.materials.new("water")
    water_material.diffuse_color = (0.12, 0.3, 0.55, 1.0)
    water.data.materials.append(water_material)

    corners = np.array([[o.bound_box[i][0], o.bound_box[i][1]] for o in objects for i in range(8)])
    views = {
        "terrain_blender": (corners.min(axis=0), corners.max(axis=0), 2000),
        "terrain_blender_band": (np.array([west, south]), np.array([east, north]), 1600),
    }
    camera_data = bpy.data.cameras.new("top")
    camera_data.type = "ORTHO"
    camera_data.clip_start = 1.0
    camera_data.clip_end = 20_000.0
    camera = bpy.data.objects.new("top", camera_data)
    scene.collection.objects.link(camera)
    scene.camera = camera
    SCREENSHOTS.mkdir(exist_ok=True)
    for name, (low, high, pixels) in views.items():
        span = high - low
        camera.location = ((low[0] + high[0]) / 2, (low[1] + high[1]) / 2, 10_000.0)
        camera.rotation_euler = (0.0, 0.0, 0.0)
        camera_data.ortho_scale = float(span.max())
        scene.render.resolution_x = int(pixels * span[0] / span.max())
        scene.render.resolution_y = int(pixels * span[1] / span.max())
        scene.render.filepath = str(SCREENSHOTS / f"{name}.png")
        bpy.ops.render.render(write_still=True)
        print(f"Rendered {scene.render.filepath}")


def main() -> None:
    args = script_args()
    only = next((a.split("=", 1)[1] for a in args if a.startswith("--only=")), "")
    info = json.loads((DATA / "chunks.json").read_text())
    origin_east, origin_north = info["origin_east_m"], info["origin_north_m"]
    for obj in list(bpy.data.objects):
        bpy.data.objects.remove(obj, do_unlink=True)
    OUT.mkdir(parents=True, exist_ok=True)
    material = grey_material()

    objects, names = [], []
    vertex_total, start = 0, time.time()
    for chunk in info["chunks"]:
        names.append(chunk["name"])
        if only and only not in chunk["name"]:
            continue
        grid = ChunkGrid(chunk, origin_east, origin_north)
        obj = build_mesh(chunk["name"], grid)
        before = len(obj.data.vertices)
        thin_out(obj, chunk["keep"])
        skirt, border = make_skirt(obj, chunk["skirt_m"])
        for part in (obj, skirt):
            finish_surface(part, grid)
            part.data.materials.append(material)
        export_glb([obj, skirt], OUT / f"{chunk['name']}.glb")
        objects.append(obj)
        vertex_total += len(obj.data.vertices) + len(skirt.data.vertices)
        print(f"Chunk {chunk['name']}: {before:,} -> {len(obj.data.vertices):,} vertices "
              f"({border:,} border edges with skirt), {time.time() - start:.0f} s")

    write_godot_scene(names)
    size_mb = sum((OUT / f"{n}.glb").stat().st_size for n in names if (OUT / f"{n}.glb").exists()) / 1e6
    print(f"Exported {len(objects)} chunks, {vertex_total:,} vertices; all {len(names)} .glb files: {size_mb:.1f} MB")
    stale = sorted(p.name for p in OUT.glob("*.glb") if p.stem not in names)
    if stale:
        print(f"Not part of the terrain any more (left in place, remove by hand if not needed): {', '.join(stale)}")

    if "--no-render" not in args and not only:
        band_west = min(c["west_m"] for c in info["chunks"] if c["zone"] == "near") - origin_east
        band_north = max(c["north_m"] for c in info["chunks"] if c["zone"] == "near") - origin_north
        band_east = max(c["west_m"] + c["size_m"] for c in info["chunks"] if c["zone"] == "near") - origin_east
        band_south = min(c["north_m"] - c["size_m"] for c in info["chunks"] if c["zone"] == "near") - origin_north
        render_previews(objects, (band_west, band_south, band_east, band_north))


main()
