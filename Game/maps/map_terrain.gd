@tool
class_name MapTerrain
extends Node3D
## The terrain of a map (Documentation/MAP_SILVAPLANA_PLAN.md, M1 and M2). Its children are the
## chunks that tools/blender/build_terrain.py exported, and this script puts each chunk's aerial
## photo on it: <photo_dir>/<chunk name>.webp, made by tools/map/photos.py, drawn with
## res://maps/terrain.gdshader. It also runs in the editor (@tool), so the editor shows the photos.

const SHADER: Shader = preload("res://maps/terrain.gdshader")

## The folder with one photo per chunk, named like the chunk.
@export_dir var photo_dir: String = ""
## How much darker a vertical cliff is than flat ground (see terrain.gdshader).
@export_range(0.0, 1.0) var slope_darkening: float = 0.25
## How much the game's sun shades the slopes on top of the light in the photo (see terrain.gdshader).
@export_range(0.0, 1.0) var sun_shading: float = 0.5


func _ready() -> void:
	apply_photos()


## Gives every chunk a material with its photo. Returns the number of chunks that got one.
func apply_photos() -> int:
	var count: int = 0
	for chunk: Node in get_children():
		var path: String = photo_dir.path_join(String(chunk.name) + ".webp")
		if not ResourceLoader.exists(path):
			push_warning("MapTerrain: no photo for chunk %s (%s)" % [chunk.name, path])
			continue
		var material: ShaderMaterial = ShaderMaterial.new()
		material.shader = SHADER
		material.set_shader_parameter("photo", load(path))
		material.set_shader_parameter("slope_darkening", slope_darkening)
		material.set_shader_parameter("sun_shading", sun_shading)
		for node: Node in chunk.find_children("*", "MeshInstance3D", true, false):
			var mesh: MeshInstance3D = node as MeshInstance3D
			mesh.material_override = material
			# The skirt hangs under the ground along the border and only fills hairline gaps;
			# its shadow would fall across the slopes as a dark band.
			if mesh.name.ends_with("_skirt"):
				mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		count += 1
	return count
