class_name DrawDistance
extends RefCounted
## Settings > Graphics > Draw distance (Max, 6 November 2026: "draw distance increase option"): how far
## the game draws things in full, in four steps. "Normal" is exactly what the game drew before the
## setting, so nothing changes unless the player moves it. What each step sets:
## - the camera's far plane (CameraRig): nothing beyond it is drawn;
## - the detail of far meshes (the terrain's and the gear's automatic LODs, Viewport.mesh_lod_threshold:
##   how many pixels a simpler mesh may be off before the finer one is drawn; 1 is Godot's own);
## - on the open water, how far the waves have their shape (OceanNode.near_size_m, the wave mesh
##   around the camera; past its edge the far water is flat and drawn as shading). The lake's wave
##   mesh is not changed: its waves are 1 to 8 m long and too small to see as shape past its 240 m;
## - how far the other boards are drawn with full care and carry their name (RaceRunner and NetBoards:
##   past it a board is posed every other tick and its fin's bend is not updated, its name hidden).
## The course's marks are drawn at every distance, at every step: a racer must never lose a mark.
##
## The command line's --draw_distance=near|normal|far|very_far (or 0 to 3) sets it for that run
## (GameSettings).

enum Level { NEAR, NORMAL, FAR, VERY_FAR }

const NAMES: PackedStringArray = ["Near", "Normal", "Far", "Very far"]
## The camera's far plane, metres. Normal: 35 km, past the farthest land seen from Lake Silvaplana
## (32 km, MAP_SILVAPLANA_PLAN.md M2). Near cuts the farthest mountains (and the fog hides them less).
const CAMERA_FAR_M: PackedFloat32Array = [15000.0, 35000.0, 50000.0, 80000.0]
## Viewport.mesh_lod_threshold, pixels: lower draws finer meshes farther away (slower).
const LOD_THRESHOLD_PX: PackedFloat32Array = [2.0, 1.0, 0.5, 0.25]
## The open water's wave mesh, metres across (1 m cells: 90 000 to 640 000 vertices); the waves keep
## their shape out to half of it.
const OPEN_WAVES_M: PackedFloat32Array = [300.0, 400.0, 600.0, 800.0]
## The other boards drawn with full care and named out to this distance from the camera, metres.
const FULL_DETAIL_M: PackedFloat32Array = [200.0, 300.0, 500.0, 800.0]

## The step in use (GameSettings sets it from the settings each time they apply). A static, so the
## camera, the water and the race runner read it without a reference to the settings.
static var level: Level = Level.NORMAL


## A step from a word or a number: "near", "normal", "far", "very_far" (or "very far"), 0 to 3.
## Anything else is Normal.
static func level_of(text: String) -> Level:
	var word: String = text.strip_edges().to_lower().replace(" ", "_")
	match word:
		"near":
			return Level.NEAR
		"far":
			return Level.FAR
		"very_far", "veryfar":
			return Level.VERY_FAR
	if word.is_valid_int():
		return clampi(word.to_int(), 0, Level.size() - 1) as Level
	return Level.NORMAL


static func clamp_level(value: int) -> Level:
	return clampi(value, 0, Level.size() - 1) as Level


## A step's index: `value`, or the step in use for -1.
static func _step(value: int) -> int:
	return clamp_level(level if value < 0 else value)


static func name_of(value: int) -> String:
	return NAMES[clamp_level(value)]


static func camera_far_m(value: int = -1) -> float:
	return CAMERA_FAR_M[_step(value)]


static func lod_threshold_px(value: int = -1) -> float:
	return LOD_THRESHOLD_PX[_step(value)]


static func open_waves_m(value: int = -1) -> float:
	return OPEN_WAVES_M[_step(value)]


static func full_detail_m(value: int = -1) -> float:
	return FULL_DETAIL_M[_step(value)]


## The step in plain words for the settings' row.
static func describe(value: int) -> String:
	var step: Level = clamp_level(value)
	var text: String = "%s: land %.0f km, waves %.0f m, boards %.0f m" % [
		NAMES[step], CAMERA_FAR_M[step] / 1000.0, OPEN_WAVES_M[step] * 0.5, FULL_DETAIL_M[step]]
	if step == Level.NORMAL:
		text += " (as before)"
	elif step == Level.NEAR:
		text += " (faster)"
	else:
		text += " (slower)"
	return text
