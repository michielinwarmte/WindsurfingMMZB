extends GutTest
## The look of the Silvaplana map (MAP_SILVAPLANA_PLAN.md, M2): every terrain chunk wears its
## aerial photo, the skirts cast no shadows, the sun stands where a mid-July 15:00 sun stands,
## and the game camera draws far enough for the mountains.

const MAP_SCENE: String = "res://maps/silvaplana/silvaplana.tscn"
## The lake's colours for the game's water shader, and the map's own see-through lake water.
const LAKE_WATER: String = "res://maps/silvaplana/lake_water.tres"
const LAKE: String = "res://maps/silvaplana/lake.tres"
## The farthest land that can be seen from the lake (visible.py): 32 km.
const FARTHEST_VISIBLE_M: float = 32000.0


func test_every_chunk_wears_its_photo() -> void:
	var map: Node3D = (load(MAP_SCENE) as PackedScene).instantiate()
	add_child_autofree(map)  # MapTerrain puts the photos on in _ready
	var terrain: MapTerrain = map.get_node("Terrain") as MapTerrain
	assert_not_null(terrain, "The map's Terrain node should be a MapTerrain")
	if terrain == null:
		return
	var chunks: int = 0
	for chunk: Node in terrain.get_children():
		chunks += 1
		for node: Node in chunk.find_children("*", "MeshInstance3D", true, false):
			var mesh: MeshInstance3D = node as MeshInstance3D
			var material: ShaderMaterial = mesh.material_override as ShaderMaterial
			assert_not_null(material, "%s should have the terrain material" % mesh.name)
			if material == null:
				continue
			var photo: Texture2D = material.get_shader_parameter("photo") as Texture2D
			assert_not_null(photo, "%s should have a photo" % mesh.name)
			if photo != null:
				assert_string_contains(photo.resource_path, String(chunk.name) + ".webp", false)
			if mesh.name.ends_with("_skirt"):
				assert_eq(mesh.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,
					"The skirt %s must not cast shadows (dark bands across the slopes)" % mesh.name)
	assert_eq(chunks, 80, "All terrain chunks")


func test_sun_of_a_july_afternoon() -> void:
	# Mid-July, 15:00 summer time at 46.45 N, 9.8 E: azimuth about 225 degrees, 59 degrees up.
	var map: Node3D = (load(MAP_SCENE) as PackedScene).instantiate()
	var sun: DirectionalLight3D = map.get_node("Sun") as DirectionalLight3D
	var shines_toward: Vector3 = -sun.transform.basis.z
	var from_sun: Vector3 = -shines_toward
	var elevation_deg: float = rad_to_deg(asin(from_sun.y))
	# Compass bearing of the sun: north is -Z, east is +X.
	var azimuth_deg: float = fposmod(rad_to_deg(atan2(from_sun.x, -from_sun.z)), 360.0)
	assert_almost_eq(elevation_deg, 59.0, 1.0, "The sun's height")
	assert_almost_eq(azimuth_deg, 225.0, 1.0, "The sun's compass bearing (south-west)")
	assert_true(sun.shadow_enabled, "The mountains cast shadows")
	map.free()


func test_game_camera_sees_the_far_mountains() -> void:
	var rig: CameraRig = CameraRig.new()
	add_child_autofree(rig)
	assert_gt(rig.camera.far, FARTHEST_VISIBLE_M, "The game camera must draw the farthest visible land")


func test_lake_water_is_see_through_with_ripples() -> void:
	# The map's own lake water (res://maps/lake.gdshader): see-through, darker with depth, ripples.
	var lake: ShaderMaterial = load(LAKE) as ShaderMaterial
	assert_not_null(lake)
	if lake == null:
		return
	assert_eq(lake.shader.resource_path, "res://maps/lake.gdshader")
	assert_not_null(lake.get_shader_parameter("ripple_normals"), "The ripples need their normal map")
	var absorption: Vector3 = lake.get_shader_parameter("absorption_per_m")
	assert_gt(absorption.x, absorption.y, "Water swallows red faster than green")
	assert_gt(absorption.y, absorption.z * 0.9, "and green about as fast as or faster than blue")


func test_lake_mirrors_the_mountains() -> void:
	# The reflection probe photographs the terrain (layer 1) and only the lake water (layer 2)
	# uses it, without changing the terrain's own light.
	var map: Node3D = (load(MAP_SCENE) as PackedScene).instantiate()
	var probe: ReflectionProbe = map.get_node("LakeReflections") as ReflectionProbe
	assert_not_null(probe, "The map should have the LakeReflections probe")
	if probe != null:
		assert_eq(probe.cull_mask, 1, "It photographs the terrain (render layer 1)")
		assert_eq(probe.reflection_mask, 2, "Only the lake water (render layer 2) mirrors it")
		assert_eq(probe.ambient_mode, ReflectionProbe.AMBIENT_DISABLED, "It doesn't change the terrain's light")
		assert_gt(probe.max_distance, FARTHEST_VISIBLE_M, "It sees the far mountains")
		assert_gt(probe.size.x, 5000.0, "It covers the whole lake")
		assert_gt(probe.size.z, 5000.0, "It covers the whole lake")
	map.free()


func test_lake_uses_the_game_water_shader() -> void:
	# MD6: the map only sets the water's colours, it doesn't bring its own water shader.
	var water: ShaderMaterial = load(LAKE_WATER) as ShaderMaterial
	assert_not_null(water)
	if water == null:
		return
	assert_eq(water.shader.resource_path, "res://world/water.gdshader")
	assert_eq(water.get_shader_parameter("grid_strength"), 0.0, "No grid lines on the lake")
