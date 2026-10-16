"""Round-trip test of the map pipeline (MAP_SILVAPLANA_PLAN.md, M0): Blender -> .glb -> Godot.

Builds a 100 x 100 m test terrain with one hill and exports it as .glb. Godot then imports
it, and Game/tests/unit/maps/test_map_roundtrip.gd checks that the hill's top landed where
the map conventions (plan MD1) say it should.

Axes, the same for every map script:
  Blender X = east, Blender Y = north, Blender Z = up (metres).
  The glTF exporter turns Z-up into Y-up, so in Godot: X = east, Y = up, Z = -north,
  which is exactly main-plan D4 (north is -Z).

Run (from the repo root):
  tools/blender.sh tools/blender/roundtrip_test.py Game/maps/silvaplana/dev/roundtrip_hill.glb
"""
import math
import sys
from pathlib import Path

import bpy

SIZE_M = 100.0
SPACING_M = 2.0
# The hill's top, in metres east, north and up of the square's centre. Not symmetric on
# purpose, so a swapped or mirrored axis shows up in the test.
PEAK_EAST_M = 20.0
PEAK_NORTH_M = 30.0
PEAK_HEIGHT_M = 10.0
HILL_RADIUS_M = 15.0


def script_args() -> list[str]:
    """The arguments after '--' on the Blender command line."""
    return sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []


def height_at(east_m: float, north_m: float) -> float:
    """A smooth bump: PEAK_HEIGHT_M at the peak, falling off with distance."""
    distance_sq = (east_m - PEAK_EAST_M) ** 2 + (north_m - PEAK_NORTH_M) ** 2
    return PEAK_HEIGHT_M * math.exp(-distance_sq / (2.0 * HILL_RADIUS_M ** 2))


def build_terrain() -> bpy.types.Object:
    """A grid of vertices every SPACING_M metres, with the hill as its height."""
    count = int(SIZE_M / SPACING_M) + 1
    half = SIZE_M / 2.0
    vertices = []
    for row in range(count):
        north = -half + row * SPACING_M
        for column in range(count):
            east = -half + column * SPACING_M
            vertices.append((east, north, height_at(east, north)))
    faces = []
    for row in range(count - 1):
        for column in range(count - 1):
            a = row * count + column
            faces.append((a, a + 1, a + 1 + count, a + count))

    mesh = bpy.data.meshes.new("roundtrip_hill")
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    for polygon in mesh.polygons:
        polygon.use_smooth = True

    material = bpy.data.materials.new("roundtrip_grass")
    material.use_nodes = True
    material.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.25, 0.45, 0.2, 1.0)
    mesh.materials.append(material)

    terrain = bpy.data.objects.new("roundtrip_hill", mesh)
    bpy.context.scene.collection.objects.link(terrain)
    return terrain


def main() -> None:
    args = script_args()
    if len(args) != 1:
        raise SystemExit("Usage: tools/blender.sh tools/blender/roundtrip_test.py <output.glb>")
    output = Path(args[0]).resolve()
    output.parent.mkdir(parents=True, exist_ok=True)

    # Start from an empty scene (factory startup has a cube, a camera and a light).
    for obj in list(bpy.data.objects):
        bpy.data.objects.remove(obj, do_unlink=True)

    build_terrain()
    bpy.ops.export_scene.gltf(
        filepath=str(output),
        export_format="GLB",
        export_yup=True,
        export_apply=True,
        export_cameras=False,
        export_lights=False,
    )
    print(f"Exported {output}")


main()
