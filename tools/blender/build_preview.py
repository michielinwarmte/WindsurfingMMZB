"""Builds a Blender preview of the real Silvaplana valley, for the team to look at.

Not the game terrain (M1 builds that, in chunks for Godot): a quick look at the data, so you can
open it in Blender and fly around. Reads .map_data/work/preview/ (made by
tools/map/preview_data.py) and writes, in the same folder:

  silvaplana_preview.blend   open it in Blender; the cameras are views from the lake and the slopes
  renders/<camera>.png       a picture from each camera

Axes as in every map script (plan MD1): Blender X = east, Y = north, Z = up, in metres, with the
origin in the middle of the lake and Z = 0 at the lake surface.

Run (from the repo root): tools/blender.sh tools/blender/build_preview.py [--no-render]
"""
import json
import math
import sys
from pathlib import Path

import bpy
import numpy as np
from mathutils import Vector

REPO_ROOT = Path(__file__).resolve().parents[2]
PREVIEW = REPO_ROOT / ".map_data" / "work" / "preview"

# Viewpoints in LV95 (east, north, metres above the lake surface), what they look at, and the
# least clearance above the ground below them. "on_water" cameras move to the nearest water.
# The camping beach is at the north end of the lake; the Maloja blows from the south-west.
CAMERAS = {
    "launch_beach": {"at": (2_781_450.0, 1_148_000.0, 2.0), "look": (2_779_200.0, 1_145_300.0, 40.0), "on_water": True},
    "above_village": {"at": (2_781_700.0, 1_148_900.0, 120.0), "look": (2_779_600.0, 1_146_000.0, 0.0)},
    "valley_overview": {"at": (2_785_500.0, 1_152_500.0, 1_400.0), "look": (2_780_200.0, 1_146_300.0, 0.0)},
    "from_corvatsch": {"at": (2_782_600.0, 1_143_600.0, 1_500.0), "look": (2_780_300.0, 1_146_900.0, 0.0), "clearance": 150.0},
}


def script_args() -> list[str]:
    return sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []


def grid_mesh(name: str, heights: np.ndarray, west: float, north: float, cell: float,
              origin: tuple[float, float, float], skip_box: tuple[float, float, float, float] | None = None) -> bpy.types.Object:
    """A mesh with one vertex per grid cell centre and UVs that map the whole grid onto one image.
    Faces whose four corners all lie inside skip_box (west, south, east, north in LV95) are left out."""
    rows, columns = heights.shape
    east = west + (np.arange(columns) + 0.5) * cell
    northing = north - (np.arange(rows) + 0.5) * cell
    grid_east, grid_north = np.meshgrid(east, northing)
    z = np.nan_to_num(heights, nan=float(np.nanmin(heights))) - origin[2]
    vertices = np.stack([grid_east - origin[0], grid_north - origin[1], z], axis=-1).reshape(-1, 3).astype(np.float32)
    u = (grid_east - west) / (columns * cell)
    v = 1.0 - (north - grid_north) / (rows * cell)
    uv = np.stack([u, v], axis=-1).reshape(-1, 2).astype(np.float32)

    index = np.arange(rows * columns).reshape(rows, columns)
    # Counter-clockwise seen from above: row index grows to the south.
    quads = np.stack([index[1:, :-1], index[1:, 1:], index[:-1, 1:], index[:-1, :-1]], axis=-1).reshape(-1, 4)
    if skip_box is not None:
        w, s, e, n = skip_box
        corner_east = vertices[quads, 0] + origin[0]
        corner_north = vertices[quads, 1] + origin[1]
        inside = (corner_east > w) & (corner_east < e) & (corner_north > s) & (corner_north < n)
        quads = quads[~inside.all(axis=1)]

    mesh = bpy.data.meshes.new(name)
    mesh.vertices.add(len(vertices))
    mesh.vertices.foreach_set("co", vertices.ravel())
    mesh.loops.add(quads.size)
    mesh.loops.foreach_set("vertex_index", quads.ravel().astype(np.int32))
    mesh.polygons.add(len(quads))
    mesh.polygons.foreach_set("loop_start", np.arange(0, quads.size, 4, dtype=np.int32))
    uv_layer = mesh.uv_layers.new(name="UVMap")
    uv_layer.data.foreach_set("uv", uv[quads.ravel()].ravel())
    mesh.update(calc_edges=True)
    mesh.validate()
    mesh.shade_smooth()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    return obj


def photo_material(name: str, image_path: Path) -> bpy.types.Material:
    material = bpy.data.materials.new(name)
    material.use_nodes = True
    nodes = material.node_tree.nodes
    shader = nodes["Principled BSDF"]
    shader.inputs["Roughness"].default_value = 0.9
    texture = nodes.new("ShaderNodeTexImage")
    texture.image = bpy.data.images.load(str(image_path))
    texture.extension = "EXTEND"
    material.node_tree.links.new(texture.outputs["Color"], shader.inputs["Base Color"])
    return material


def water(size_m: float) -> None:
    bpy.ops.mesh.primitive_plane_add(size=size_m, location=(0.0, 0.0, 0.0))
    plane = bpy.context.active_object
    plane.name = "lake_surface"
    material = bpy.data.materials.new("lake_water")
    material.use_nodes = True
    shader = material.node_tree.nodes["Principled BSDF"]
    shader.inputs["Base Color"].default_value = (0.03, 0.18, 0.22, 1.0)
    shader.inputs["Roughness"].default_value = 0.05
    shader.inputs["Alpha"].default_value = 0.75
    if hasattr(material, "surface_render_method"):
        material.surface_render_method = "BLENDED"
    plane.data.materials.append(material)


class Ground:
    """Terrain heights of the preview, for placing cameras: the 5 m grid near the lake, else the 100 m grid."""

    def __init__(self, info: dict) -> None:
        self.grids = []
        for key in ("near", "far"):
            part = info[key]
            self.grids.append((np.load(PREVIEW / part["heights"]), part["west_m"], part["north_m"], part["cell_m"]))

    def height_at(self, east: float, north: float) -> float:
        for heights, west, north_edge, cell in self.grids:
            row, column = int((north_edge - north) // cell), int((east - west) // cell)
            if 0 <= row < heights.shape[0] and 0 <= column < heights.shape[1]:
                return float(heights[row, column])
        return -1e9

    def nearest_water(self, east: float, north: float, lake_level: float) -> tuple[float, float]:
        """The nearest cell of the 5 m grid that is more than 1 m under water."""
        heights, west, north_edge, cell = self.grids[0]
        rows, columns = np.nonzero(heights < lake_level - 1.0)
        water_east = west + (columns + 0.5) * cell
        water_north = north_edge - (rows + 0.5) * cell
        i = int(np.argmin(np.hypot(water_east - east, water_north - north)))
        return float(water_east[i]), float(water_north[i])


def place_cameras(ground: Ground, lake_level: float) -> dict[str, tuple]:
    """Each camera's final position: on the water if asked, and never closer to the ground than its clearance."""
    placed = {}
    for name, view in CAMERAS.items():
        east, north, above_lake = view["at"]
        if view.get("on_water"):
            east, north = ground.nearest_water(east, north, lake_level)
        clearance = view.get("clearance", 2.0)
        ground_above_lake = ground.height_at(east, north) - lake_level
        placed[name] = ((east, north, max(above_lake, ground_above_lake + clearance)), view["look"])
    return placed


def add_camera(name: str, at: tuple[float, float, float], look: tuple[float, float, float], origin) -> bpy.types.Object:
    data = bpy.data.cameras.new(name)
    data.lens = 24.0
    data.clip_start = 0.5
    data.clip_end = 60_000.0
    camera = bpy.data.objects.new(name, data)
    camera.location = Vector((at[0] - origin[0], at[1] - origin[1], at[2]))
    target = Vector((look[0] - origin[0], look[1] - origin[1], look[2]))
    camera.rotation_euler = (target - camera.location).to_track_quat("-Z", "Y").to_euler()
    bpy.context.scene.collection.objects.link(camera)
    return camera


def light_and_sky() -> None:
    sun_data = bpy.data.lights.new("sun", "SUN")
    sun_data.energy = 4.0
    sun = bpy.data.objects.new("sun", sun_data)
    # A summer afternoon: the sun high in the south-west.
    sun.rotation_euler = (math.radians(35.0), 0.0, math.radians(-135.0))
    bpy.context.scene.collection.objects.link(sun)
    world = bpy.data.worlds.new("sky")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.45, 0.62, 0.85, 1.0)
    world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.8
    bpy.context.scene.world = world


def set_render_engine(scene: bpy.types.Scene) -> str:
    for engine in ("BLENDER_EEVEE_NEXT", "BLENDER_EEVEE"):
        try:
            scene.render.engine = engine
            return engine
        except TypeError:
            continue
    scene.render.engine = "BLENDER_WORKBENCH"
    return "BLENDER_WORKBENCH"


def main() -> None:
    info = json.loads((PREVIEW / "preview.json").read_text())
    origin = (info["origin_east_m"], info["origin_north_m"], info["lake_level_m"])
    for obj in list(bpy.data.objects):
        bpy.data.objects.remove(obj, do_unlink=True)

    near_info, far_info = info["near"], info["far"]
    near_heights = np.load(PREVIEW / near_info["heights"])
    near = grid_mesh("shore_band_5m", near_heights, near_info["west_m"], near_info["north_m"], near_info["cell_m"], origin)
    near.data.materials.append(photo_material("shore_band_photo", PREVIEW / near_info["photo"]))

    rows, columns = near_heights.shape
    box = (near_info["west_m"], near_info["north_m"] - rows * near_info["cell_m"],
           near_info["west_m"] + columns * near_info["cell_m"], near_info["north_m"])
    far = grid_mesh("surroundings_100m", np.load(PREVIEW / far_info["heights"]), far_info["west_m"], far_info["north_m"],
                    far_info["cell_m"], origin, skip_box=box)
    far.data.materials.append(photo_material("surroundings_photo", PREVIEW / far_info["photo"]))

    water(box[2] - box[0])
    light_and_sky()
    placed = place_cameras(Ground(info), info["lake_level_m"])
    cameras = {name: add_camera(name, at, look, origin) for name, (at, look) in placed.items()}
    for name, (at, _) in placed.items():
        print(f"Camera {name}: LV95 {at[0]:.0f} / {at[1]:.0f}, {at[2]:.0f} m above the lake")

    scene = bpy.context.scene
    scene.camera = cameras["launch_beach"]
    scene.unit_settings.system = "METRIC"
    engine = set_render_engine(scene)
    scene.render.resolution_x, scene.render.resolution_y = 1280, 720
    if hasattr(scene, "eevee"):
        scene.eevee.taa_render_samples = 16
        if hasattr(scene.eevee, "shadow_pool_size"):
            scene.eevee.shadow_pool_size = "1024"
    scene.view_settings.view_transform = "AgX" if "AgX" in [i.identifier for i in scene.view_settings.bl_rna.properties["view_transform"].enum_items] else "Filmic"

    # No .blend1 backup copies: the preview is rebuilt from the data anyway.
    bpy.context.preferences.filepaths.save_version = 0
    blend = PREVIEW / "silvaplana_preview.blend"
    bpy.ops.wm.save_as_mainfile(filepath=str(blend))
    print(f"Saved {blend}")

    if "--no-render" in script_args():
        return
    renders = PREVIEW / "renders"
    renders.mkdir(exist_ok=True)
    for name, camera in cameras.items():
        scene.camera = camera
        scene.render.filepath = str(renders / f"{name}.png")
        bpy.ops.render.render(write_still=True)
        print(f"Rendered {name} with {engine}")
    scene.camera = cameras["launch_beach"]
    bpy.ops.wm.save_as_mainfile(filepath=str(blend))


main()
