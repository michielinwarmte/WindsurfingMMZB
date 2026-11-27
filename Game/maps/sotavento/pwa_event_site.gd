class_name PwaEventSite
extends Node3D
## The PWA World Tour's event site at Sotavento, so the spot is recognisable from the water (backlog
## E04.S12 T6 and T7), laid out from the event's own zone map of 2026 (fuerteventura-worldcup.org;
## Documentation/reports/spots/sotavento/PLAN.md, section 6): on the beach north-east of the René
## Egli Center the judges' tower with its grandstand, a row of beach flags and the riders' sails on
## the sand, the riders' tent by the hotels, palms in the hotels' garden; on the water the Slalom X
## course's buoys (red start and finish, yellow gybe marks, the committee boats at the line ends) and
## the freestyle box's red corner buoys. The big day-and-night tent comes with the buildings (it is
## in OpenStreetMap). Simple shapes in plain colours (no real logos, as for the gear's brands); the
## regional props library (E04.S16) replaces them later.
##
## Positions are in the spot's frame (REGCAN95 / UTM 28N metres); the ground under each prop comes
## from the near height grid at the session's water level (water_level_m, set by SpotSailing).

## The judges' tower on the beach top (from the zone map, between the René Egli Center and the big
## tent), and the beach's directions there: along it up the coast (013 degrees), out to sea (103).
const TOWER: Vector2 = Vector2(574470.0, 3112700.0)
const ALONG_DEG: float = 13.0
const OUT_DEG: float = 103.0
## The riders' tent ("carpa de competidores"), by the hotels; the hotels' palm garden.
const RIDERS_TENT: Vector2 = Vector2(574255.0, 3112615.0)
const GARDEN: Vector2 = Vector2(574170.0, 3112540.0)
const BUOY_HEIGHT_M: float = 2.4
const BUOY_DRAFT_M: float = 0.5
## The PWA stream's beach camera, for the game's TV director (TvCamera.SHORE_CAMERA_GROUP): on the
## seaward edge of the rocky headland up the coast from the judges' tower (this far along the beach and
## out), its eye this high above the water (the stream's measured: 3.5 to 5 m on 41 shots,
## Documentation/reports/broadcast/drone_position.md), or standing height on the rock there when the
## rock is higher. From the tower's foot the headland hides the start pin; from here every mark and both
## lines are clear (checked along the sight lines on the depth grid, 27 November 2026).
const TV_CAMERA_ALONG_M: float = 130.0
const TV_CAMERA_OUT_M: float = 150.0
const TV_CAMERA_EYE_M: float = 4.5
const STANDING_EYE_M: float = 1.7

@export var map_config: MapConfig = null
@export_file("*.json") var heights_json: String = ""
@export_file("*.json") var course_json: String = ""
## The session's water level above mean sea level, m (the sailing scene sets it).
@export var water_level_m: float = 0.0

var _grid: TerrainGrid = null
var _course_buoys: Node3D = null
var _materials: Dictionary[String, StandardMaterial3D] = {}


func _ready() -> void:
	_grid = TerrainGrid.load_from(heights_json)
	if _grid != null:
		_grid.lower_by(water_level_m)
	_build_tower()
	_build_tv_shore_camera()
	_build_grandstand()
	_build_flags()
	_build_sails_on_the_beach()
	_build_riders_tent()
	_build_palms()
	_course_buoys = Node3D.new()
	_course_buoys.name = "CourseBuoys"
	add_child(_course_buoys)
	_build_course_buoys()


## The course's buoys off (a race on the same course draws its own marks) or on.
func show_course_buoys(shown: bool) -> void:
	if _course_buoys != null:
		_course_buoys.visible = shown


## How many buoys the course has on the water (for the tests).
func buoy_count() -> int:
	return _course_buoys.get_child_count() if _course_buoys != null else 0


# ---------------------------------------------------------------- where things go

## A point in the spot's frame as a game position on the ground (or on the water: never below it).
func _on_ground(east_north: Vector2, above_m: float = 0.0) -> Vector3:
	var at: Vector3 = map_config.lv95_to_game(east_north.x, east_north.y, 0.0)
	var ground: float = _grid.height_at(at.x, at.z) if _grid != null else 0.0
	if is_nan(ground):
		ground = 0.0
	return Vector3(at.x, maxf(ground, 0.0) + above_m, at.z)


## A point of the beach's own frame: metres along the beach from the tower (up the coast) and out.
static func beach_point(along_m: float, out_m: float) -> Vector2:
	var along: float = deg_to_rad(ALONG_DEG)
	var out: float = deg_to_rad(OUT_DEG)
	return TOWER + Vector2(along_m * sin(along) + out_m * sin(out), along_m * cos(along) + out_m * cos(out))


## The yaw that turns a prop's front (its local -Z) to face a compass bearing.
static func _facing(bearing_deg: float) -> float:
	return -deg_to_rad(bearing_deg)


func _material(colour: Color, double_sided: bool = false) -> StandardMaterial3D:
	var key: String = "%s/%s" % [colour.to_html(), double_sided]
	if not _materials.has(key):
		var material: StandardMaterial3D = StandardMaterial3D.new()
		material.albedo_color = colour
		material.roughness = 0.8
		if double_sided:
			material.cull_mode = BaseMaterial3D.CULL_DISABLED
		_materials[key] = material
	return _materials[key]


func _box(parent: Node3D, size: Vector3, at: Vector3, colour: Color) -> MeshInstance3D:
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	return _instance(parent, mesh, at, _material(colour))


func _instance(parent: Node3D, mesh: Mesh, at: Vector3, material: Material) -> MeshInstance3D:
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = at
	parent.add_child(instance)
	return instance


func _group(group_name: String, at: Vector3, bearing_deg: float) -> Node3D:
	var group: Node3D = Node3D.new()
	group.name = group_name
	group.position = at
	group.rotation.y = _facing(bearing_deg)
	add_child(group)
	return group


# ---------------------------------------------------------------- the beach

## The judges' tower: a scaffold of four legs, a deck 7 m up with a railing, a white roof and
## banners round it, its front to the sea.
func _build_tower() -> void:
	var tower: Node3D = _group("JudgesTower", _on_ground(TOWER), OUT_DEG)
	var steel: Color = Color(0.55, 0.57, 0.6)
	for corner: Vector2 in [Vector2(-2.4, -2.4), Vector2(2.4, -2.4), Vector2(-2.4, 2.4), Vector2(2.4, 2.4)]:
		_box(tower, Vector3(0.18, 10.0, 0.18), Vector3(corner.x, 5.0, corner.y), steel)
	_box(tower, Vector3(5.4, 0.3, 5.4), Vector3(0.0, 7.0, 0.0), Color(0.35, 0.35, 0.38))
	_box(tower, Vector3(6.4, 0.25, 6.4), Vector3(0.0, 10.1, 0.0), Color(0.96, 0.96, 0.95))
	_box(tower, Vector3(5.4, 1.0, 0.08), Vector3(0.0, 7.65, -2.7), Color(0.95, 0.85, 0.1))  # railing banner, front
	# Banners below the deck on three sides: blue and yellow (the event's colours, no logos).
	_box(tower, Vector3(5.0, 2.2, 0.06), Vector3(0.0, 5.2, -2.5), Color(0.1, 0.32, 0.75))
	_box(tower, Vector3(0.06, 2.2, 5.0), Vector3(-2.5, 5.2, 0.0), Color(0.95, 0.85, 0.1))
	_box(tower, Vector3(0.06, 2.2, 5.0), Vector3(2.5, 5.2, 0.0), Color(0.95, 0.85, 0.1))


## Where the stream's beach camera stands: a marker the TV director finds by its group.
func _build_tv_shore_camera() -> void:
	var marker: Marker3D = Marker3D.new()
	marker.name = "TvShoreCamera"
	var ground: Vector3 = _on_ground(beach_point(TV_CAMERA_ALONG_M, TV_CAMERA_OUT_M))
	marker.position = Vector3(ground.x, maxf(TV_CAMERA_EYE_M, ground.y + STANDING_EYE_M), ground.z)
	marker.add_to_group("tv_shore_camera")
	add_child(marker)


## The grandstand beside the tower (down the coast): four steps of seats facing the sea.
func _build_grandstand() -> void:
	var stand: Node3D = _group("Grandstand", _on_ground(beach_point(-14.0, -3.0)), OUT_DEG)
	for step: int in 4:
		var depth_z: float = 1.5 - step * 1.4
		_box(stand, Vector3(14.0, 0.15, 1.4), Vector3(0.0, 0.7 + step * 0.65, depth_z), Color(0.12, 0.3, 0.72))
		_box(stand, Vector3(14.0, 0.7 + step * 0.65, 0.12), Vector3(0.0, (0.7 + step * 0.65) / 2.0, depth_z + 0.7), Color(0.6, 0.62, 0.65))


## A row of feather flags along the beach top either side of the tower (the beach ends in a rocky point
## about 120 m up the coast).
func _build_flags() -> void:
	var colours: Array[Color] = [Color(0.1, 0.32, 0.75), Color(0.95, 0.85, 0.1), Color(0.0, 0.7, 0.8), Color(0.85, 0.15, 0.15), Color(0.97, 0.97, 0.97)]
	var pole: CylinderMesh = CylinderMesh.new()
	pole.top_radius = 0.03
	pole.bottom_radius = 0.04
	pole.height = 4.6
	var cloth: QuadMesh = QuadMesh.new()
	cloth.size = Vector2(0.9, 3.4)
	for k: int in 12:
		var flag: Node3D = _group("Flag%d" % k, _on_ground(beach_point(-45.0 + 9.0 * k, -6.0)), OUT_DEG)
		_instance(flag, pole, Vector3(0.0, 2.3, 0.0), _material(Color(0.8, 0.8, 0.82)))
		# The cloth streams downwind of its pole (the trade wind from the north-north-east).
		var banner: MeshInstance3D = _instance(flag, cloth, Vector3(0.0, 2.8, 0.5), _material(colours[k % colours.size()], true))
		banner.rotation.y = PI / 2.0


## The riders' sails rigged and lying on the sand along the beach top either side of the tower.
func _build_sails_on_the_beach() -> void:
	var colours: Array[Color] = [Color(0.9, 0.15, 0.1), Color(0.95, 0.8, 0.1), Color(0.1, 0.1, 0.12), Color(0.95, 0.5, 0.05),
		Color(0.15, 0.6, 0.25), Color(0.9, 0.9, 0.92), Color(0.2, 0.35, 0.8)]
	var random: RandomNumberGenerator = RandomNumberGenerator.new()
	random.seed = 2026
	var sail_mesh: PrismMesh = PrismMesh.new()
	sail_mesh.size = Vector3(2.4, 5.0, 0.04)
	sail_mesh.left_to_right = 0.0
	for k: int in 30:
		var along: float = -60.0 + (k % 15) * 10.0 + random.randf_range(-1.5, 1.5)
		var out: float = -14.0 + floorf(k / 15.0) * 6.0 + random.randf_range(-1.0, 1.0)
		var sail: Node3D = _group("Sail%d" % k, _on_ground(beach_point(along, out), 0.25), random.randf_range(0.0, 360.0))
		var cloth: MeshInstance3D = _instance(sail, sail_mesh, Vector3.ZERO, _material(colours[random.randi() % colours.size()], true))
		# Lying on the sand, the mast side a little up (on the boom), as rigged sails wait on a beach.
		cloth.rotation.x = -PI / 2.0 + 0.12


## The riders' tent by the hotels: a white marquee with a peaked roof.
func _build_riders_tent() -> void:
	var tent: Node3D = _group("RidersTent", _on_ground(RIDERS_TENT), OUT_DEG)
	var white: Color = Color(0.97, 0.97, 0.96)
	_box(tent, Vector3(16.0, 2.6, 10.0), Vector3(0.0, 1.3, 0.0), white)
	var roof: PrismMesh = PrismMesh.new()
	roof.size = Vector3(10.0, 2.2, 16.0)
	var top: MeshInstance3D = _instance(tent, roof, Vector3(0.0, 3.7, 0.0), _material(white))
	top.rotation.y = PI / 2.0


## Palms in the hotels' garden by the René Egli Center (on dry ground a little above the beach).
func _build_palms() -> void:
	var random: RandomNumberGenerator = RandomNumberGenerator.new()
	random.seed = 28
	var trunk: CylinderMesh = CylinderMesh.new()
	trunk.top_radius = 0.16
	trunk.bottom_radius = 0.26
	trunk.height = 1.0
	var frond: BoxMesh = BoxMesh.new()
	frond.size = Vector3(0.7, 0.04, 3.4)
	var bark: StandardMaterial3D = _material(Color(0.45, 0.36, 0.26))
	var leaf: StandardMaterial3D = _material(Color(0.22, 0.42, 0.16))
	var planted: int = 0
	var tries: int = 0
	while planted < 28 and tries < 400:
		tries += 1
		var spot: Vector2 = GARDEN + Vector2(random.randf_range(-90.0, 90.0), random.randf_range(-70.0, 90.0))
		var ground: Vector3 = _on_ground(spot)
		if ground.y < 0.8 or ground.y > 14.0:
			continue
		var height: float = random.randf_range(6.0, 10.0)
		var palm: Node3D = _group("Palm%d" % planted, ground, random.randf_range(0.0, 360.0))
		var stem: MeshInstance3D = _instance(palm, trunk, Vector3(0.0, height / 2.0, 0.0), bark)
		stem.scale = Vector3(1.0, height, 1.0)
		for f: int in 9:
			var blade: MeshInstance3D = _instance(palm, frond, Vector3.ZERO, leaf)
			var turn: float = TAU * f / 9.0
			blade.rotation = Vector3(0.45, turn, 0.0)
			blade.position = Vector3(sin(turn) * 1.5, height - 0.6, cos(turn) * 1.5)
		planted += 1


# ---------------------------------------------------------------- the water

## The Slalom X course's buoys from its course file, and the freestyle box's corners.
func _build_course_buoys() -> void:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(course_json)) if course_json != "" else null
	if not data is Dictionary:
		return
	var pillar: CylinderMesh = CylinderMesh.new()
	pillar.top_radius = 0.75
	pillar.bottom_radius = 0.8
	pillar.height = BUOY_HEIGHT_M
	for mark: Dictionary in (data as Dictionary)["marks"]:
		var id: String = String(mark["id"])
		var at: Vector3 = map_config.lv95_to_game(float(mark["east"]), float(mark["north"]), 0.0)
		if id.ends_with("boat"):
			_add_committee_boat(id, Vector3(at.x, 0.0, at.z))
			continue
		var colour: Color = Color(0.9, 0.12, 0.1) if id.begins_with("start") or id.begins_with("finish") else Color(1.0, 0.82, 0.05)
		var buoy: MeshInstance3D = _instance(_course_buoys, pillar, Vector3(at.x, BUOY_HEIGHT_M / 2.0 - BUOY_DRAFT_M, at.z), _material(colour))
		buoy.name = "Buoy_" + id.replace(" ", "_")
	var ball: SphereMesh = SphereMesh.new()
	ball.radius = 0.6
	ball.height = 1.2
	var corner_number: int = 0
	for corner: Dictionary in (data as Dictionary).get("freestyle_box", []):
		var at: Vector3 = map_config.lv95_to_game(float(corner["east"]), float(corner["north"]), 0.0)
		var buoy: MeshInstance3D = _instance(_course_buoys, ball, Vector3(at.x, 0.3, at.z), _material(Color(0.9, 0.12, 0.1)))
		buoy.name = "FreestyleBox%d" % corner_number
		corner_number += 1


## A committee boat at a line's end: a white hull with a small console and a flag.
func _add_committee_boat(id: String, at: Vector3) -> void:
	var boat: Node3D = Node3D.new()
	boat.name = "Boat_" + id.replace(" ", "_")
	boat.position = at
	boat.rotation.y = _facing(25.0)  # head to the wind (the trade wind from 25 degrees)
	_course_buoys.add_child(boat)
	_box(boat, Vector3(2.4, 0.9, 6.5), Vector3(0.0, 0.25, 0.0), Color(0.95, 0.95, 0.96))
	_box(boat, Vector3(1.2, 1.0, 1.2), Vector3(0.0, 1.2, 0.6), Color(0.3, 0.3, 0.33))
	_box(boat, Vector3(0.05, 3.0, 0.05), Vector3(0.0, 2.2, 2.2), Color(0.8, 0.8, 0.8))
	_box(boat, Vector3(0.05, 0.6, 0.9), Vector3(0.0, 3.3, 2.65), Color(0.9, 0.12, 0.1))
