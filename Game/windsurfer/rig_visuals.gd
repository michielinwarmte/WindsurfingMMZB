class_name RigVisuals
extends Node3D
## What the board and the rig look like: the board, the fin, the mast, the sail and the boom.
## It only draws: the windsurfer node tells it where the simulation holds the mast and the
## boom (pose_sailing), what the sail's cloth is doing (shape_sail) or how far a fall has got
## (pose_fallen). Everything is in the board's own axes (x starboard, y up, z aft; the bow is
## -z). Nothing here feeds back into the physics (CLAUDE.md, rule 2).
##
## The parts are 3D models built in Blender by tools/blender/build_rig_models.py from the
## numbers in Game/config/ (run it again after changing a size there). One .glb per part in
## res://assets/models/, each with its origin where it is fixed:
## - board.glb: the board's centre at mid-thickness, which is the simulation's board origin.
## - fin.glb: the fin root, placed at FinConfig.root_local.
## - mast.glb and sail.glb: the mast foot (SailConfig.mast_foot_local), the mast up +y, the
##   boom along +x, so the clew is at (boom_m, boom_height_m, 0).
## - boom.glb: the mast at boom height. It is a child of the sail, so it follows the sail
##   angle and the rake.
## The sail cloth bends in a vertex shader (sail_cloth.gdshader): belly to leeward, twist,
## and flutter when luffing, from the instance uniforms that shape_sail() sets. The mast
## (mast.gdshader) and the sail bend together: the top back and, with the pull, to leeward.

const BOARD_MODEL: PackedScene = preload("res://assets/models/board.glb")
const FIN_MODEL: PackedScene = preload("res://assets/models/fin.glb")
const MAST_MODEL: PackedScene = preload("res://assets/models/mast.glb")
const SAIL_MODEL: PackedScene = preload("res://assets/models/sail.glb")
const BOOM_MODEL: PackedScene = preload("res://assets/models/boom.glb")
const SAIL_PANELS: Texture2D = preload("res://assets/models/sail_panels.png")
const SAIL_CLOTH_SHADER: Shader = preload("res://windsurfer/sail_cloth.gdshader")
const SAIL_WINDOW_SHADER: Shader = preload("res://windsurfer/sail_window.gdshader")
const MAST_SHADER: Shader = preload("res://windsurfer/mast.gdshader")

## The sail's head sits this far below the mast top (TOP_Y in build_rig_models.py), m.
const SAIL_HEAD_BELOW_MAST_TOP_M: float = 0.02
## How far out the boom's arms are at the hand grip (0.6 m back), m from the boom's centre
## line (the arm shape in build_rig_models.py; a test checks it against boom.glb).
const BOOM_ARM_HALF_WIDTH_AT_GRIP_M: float = 0.285
## How fast the belly goes over to the other side when the sail flips: per second, where 1 is
## from full to flat. 2.5 takes 0.8 s from one side to the other.
const BELLY_SWITCH_RATE: float = 2.5
## How fast the flutter comes and goes, per second.
const FLUTTER_RATE: float = 3.0
## Twist at the head, degrees: with a light pull and with a strong pull (the leech opens in
## a gust, as a real sail's does).
const TWIST_LIGHT_DEG: float = 8.0
const TWIST_LOADED_DEG: float = 16.0
## Sail lift at which the twist reaches TWIST_LOADED_DEG, N.
const TWIST_FULL_LIFT_N: float = 1200.0
## How far the masthead is bent back (the luff curve the downhaul pulls in), m, and how far
## it bends to leeward with a strong pull, m.
const MAST_BEND_AFT_M: float = 0.22
const MAST_BEND_LEEWARD_M: float = 0.12
## A time step long enough for the cloth to reach its shape in one go, s.
const SNAP_STEP_S: float = 10.0

var _board: Node3D
var _fin: Node3D
var _mast: Node3D
var _sail: Node3D
var _boom: Node3D
var _cloth: MeshInstance3D
var _mast_tube: MeshInstance3D

var _sail_config: SailConfig
# The pose at the last sailing tick, from which a fall starts.
var _last_mast_dir: Vector3 = Vector3.UP
var _last_boom_dir: Vector3 = Vector3.BACK
# The cloth's state, eased from tick to tick (see shape_sail).
var _belly_side: float = -1.0
var _flutter: float = 0.0
var _flutter_phase_rad: float = 0.0
var _last_cloth_time_s: float = NAN
# The values last given to the cloth's shader, by name (for tests and dev views).
var _cloth_values: Dictionary[String, float] = {}


## Loads the models and puts the board and fin in place.
func build(_board_config: BoardConfig, sail_config: SailConfig, fin_config: FinConfig) -> void:
	_sail_config = sail_config
	_board = _add_model(BOARD_MODEL, "Board", self)
	_fin = _add_model(FIN_MODEL, "Fin", self)
	_fin.position = fin_config.root_local
	_mast = _add_model(MAST_MODEL, "Mast", self)
	_sail = _add_model(SAIL_MODEL, "Sail", self)
	_boom = _add_model(BOOM_MODEL, "Boom", _sail)
	_boom.position = Vector3(0.0, sail_config.boom_height_m, 0.0)
	_cloth = _sail.find_child("SailCloth", true, false) as MeshInstance3D
	_mast_tube = _mast.find_child("Mast", true, false) as MeshInstance3D
	_set_up_cloth(sail_config)
	_set_up_mast(sail_config)
	_set_cloth(_belly_side, sail_config.camber, deg_to_rad(TWIST_LIGHT_DEG), 0.0, 0.0)


## The rig while sailing: the mast from the mast foot along `mast_dir`, the sail and the
## boom in the plane of the mast and `boom_dir`. Both directions are unit vectors in the
## board's axes.
func pose_sailing(mast_dir: Vector3, boom_dir: Vector3) -> void:
	_pose_rig(mast_dir, boom_dir)
	_last_mast_dir = mast_dir
	_last_boom_dir = boom_dir


## The sail's cloth from the simulation: the belly on the leeward side (the side the boom is
## on, or the other side when the wind is on the sail's back), the twist from the pull, and
## flutter when the angle of attack is close to zero. `time_s` is the simulation clock.
func shape_sail(sail: SailModel, time_s: float) -> void:
	var dt: float = _cloth_time_step(time_s)
	var target_side: float = belly_side_for(sail.sail_side, sail.is_backwinded)
	_belly_side = move_toward(_belly_side, target_side, BELLY_SWITCH_RATE * dt)
	# In very light air the cloth just hangs: little flutter.
	var air: float = clampf(sail.aws_ms / 3.0, 0.0, 1.0)
	var target_flutter: float = luff_amount(rad_to_deg(sail.alpha_rad), sail.config.alpha_luff_deg) * air
	_flutter = move_toward(_flutter, target_flutter, FLUTTER_RATE * dt)
	# Ripples run faster in more wind.
	var ripple_hz: float = 1.0 + 0.3 * sail.aws_ms
	_flutter_phase_rad = fposmod(_flutter_phase_rad + TAU * ripple_hz * dt, TAU)
	var pull: float = clampf(absf(sail.lift_n) / TWIST_FULL_LIFT_N, 0.0, 1.0)
	var twist_rad: float = deg_to_rad(lerpf(TWIST_LIGHT_DEG, TWIST_LOADED_DEG, pull))
	# A luffing sail loses most of its belly.
	var camber: float = sail.config.camber * (1.0 - 0.6 * _flutter)
	_set_cloth(_belly_side, camber, twist_rad, _flutter, pull)


## The fall on screen: the rig pivots about the mast foot until it lies on the water on the
## side of the fall. `eased` runs from 0 (the fall starts) to 1 (the rig is down), `side`
## is -1 for port and +1 for starboard. The cloth goes slack.
func pose_fallen(eased: float, side: float) -> void:
	var flat: Vector3 = Vector3(side, 0.03, 0.0).normalized()
	var mast_dir: Vector3 = _last_mast_dir.slerp(flat, eased).normalized()
	_pose_rig(mast_dir, _last_boom_dir)
	var camber: float = _sail_config.camber * lerpf(1.0, 0.3, eased)
	_set_cloth(_belly_side, camber, deg_to_rad(TWIST_LIGHT_DEG) * (1.0 - eased), 0.0, 0.0)
	_flutter = 0.0
	_last_cloth_time_s = NAN


## Which way the belly bulges in the sail's frame (z = boom direction x mast direction).
## That z points to port whichever side the boom is on, so a sail on the starboard side
## (sail_side +1, the wind from port) bulges toward -z, away from the wind. A backwinded sail
## has the wind on its leeward face and is pushed inside out.
static func belly_side_for(sail_side: int, backwinded: bool) -> float:
	var leeward: float = -float(sail_side)
	return -leeward if backwinded else leeward


## How much the sail flutters (0 to 1) at an angle of attack: fully within alpha_luff of
## zero, where the simulation's lift fades out (SailModel.luff_factor), none from 2.5 times
## that.
static func luff_amount(alpha_deg: float, alpha_luff_deg: float) -> float:
	return 1.0 - smoothstep(alpha_luff_deg, 2.5 * alpha_luff_deg, absf(alpha_deg))


## From the boom's centre line to the windward arm at the hand grip, in the board's axes:
## where the hands hold the wishbone (the simulation's grip is on the centre line).
func windward_arm_offset() -> Vector3:
	var leeward_dir: Vector3 = _sail.transform.basis.z.normalized() * signf(_belly_side)
	return -leeward_dir * BOOM_ARM_HALF_WIDTH_AT_GRIP_M


## The sail's cloth, for tests and dev views.
func sail_cloth() -> MeshInstance3D:
	return _cloth


## A value last given to the cloth's shader ("belly_side", "camber", "twist_head_rad",
## "flutter", "flutter_phase_rad", "mast_bend_aft_m", "mast_bend_across_m"), for tests and
## dev views.
func cloth_value(parameter: String) -> float:
	return _cloth_values.get(parameter, NAN)


## Mast and sail from the mast foot, both directions in the board's axes.
func _pose_rig(mast_dir: Vector3, boom_dir: Vector3) -> void:
	var foot: Vector3 = _sail_config.mast_foot_local
	var sail_normal: Vector3 = boom_dir.cross(mast_dir)
	if sail_normal.length() < 0.05:
		sail_normal = Vector3.UP
	sail_normal = sail_normal.normalized()
	# The sail keeps the boom where the simulation has it (the frame is skewed when the
	# mast rakes); the mast is a round tube, so it gets a square frame with the same up.
	_sail.transform = Transform3D(Basis(boom_dir, mast_dir, sail_normal), foot)
	var mast_up: Vector3 = mast_dir.normalized()
	_mast.transform = Transform3D(Basis(mast_up.cross(sail_normal).normalized(), mast_up, sail_normal), foot)


func _add_model(model: PackedScene, node_name: String, parent: Node3D) -> Node3D:
	var instance: Node3D = model.instantiate() as Node3D
	instance.name = node_name
	parent.add_child(instance)
	return instance


## Gives the cloth's three surfaces (cloth, windows, sleeve) their shader materials.
func _set_up_cloth(sail_config: SailConfig) -> void:
	var cloth_material: ShaderMaterial = _cloth_material(SAIL_CLOTH_SHADER, sail_config)
	cloth_material.set_shader_parameter("panel_texture", SAIL_PANELS)
	var sleeve_material: ShaderMaterial = _cloth_material(SAIL_CLOTH_SHADER, sail_config)
	sleeve_material.set_shader_parameter("is_sleeve", true)
	var window_material: ShaderMaterial = _cloth_material(SAIL_WINDOW_SHADER, sail_config)
	var by_name: Dictionary[String, ShaderMaterial] = {
		"sail_cloth": cloth_material, "sail_window": window_material, "sail_sleeve": sleeve_material,
	}
	var mesh: Mesh = _cloth.mesh
	for surface: int in mesh.get_surface_count():
		var imported: Material = mesh.surface_get_material(surface)
		var surface_name: String = imported.resource_name if imported != null else ""
		if by_name.has(surface_name):
			_cloth.set_surface_override_material(surface, by_name[surface_name])
		else:
			push_warning("sail.glb has an unexpected surface '%s'." % surface_name)
	# The shader moves the cloth up to about 0.3 m off its flat shape: widen the box the
	# engine uses to decide whether the sail is on screen.
	_cloth.extra_cull_margin = 0.5


## Gives the mast's carbon tube the shader that bends it (the extension below stays straight).
func _set_up_mast(sail_config: SailConfig) -> void:
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = MAST_SHADER
	material.set_shader_parameter("mast_length_m", sail_config.mast_m)
	var mesh: Mesh = _mast_tube.mesh
	for surface: int in mesh.get_surface_count():
		var imported: Material = mesh.surface_get_material(surface)
		if imported != null and imported.resource_name == "carbon":
			_mast_tube.set_surface_override_material(surface, material)
	_mast_tube.extra_cull_margin = 0.3


func _cloth_material(shader: Shader, sail_config: SailConfig) -> ShaderMaterial:
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("mast_length_m", sail_config.mast_m)
	material.set_shader_parameter("boom_height_m", sail_config.boom_height_m)
	material.set_shader_parameter("head_height_m", sail_config.mast_m - SAIL_HEAD_BELOW_MAST_TOP_M)
	return material


## Sets the cloth's shape, and the mast's bend: back by the luff curve, and to leeward (the
## belly's side) by `pull` (0 to 1) of the full sideways bend.
func _set_cloth(belly_side: float, camber: float, twist_head_rad: float, flutter: float, pull: float) -> void:
	var bend_across_m: float = belly_side * MAST_BEND_LEEWARD_M * pull
	_cloth_values = {
		"belly_side": belly_side, "camber": camber, "twist_head_rad": twist_head_rad,
		"flutter": flutter, "flutter_phase_rad": _flutter_phase_rad,
		"mast_bend_aft_m": MAST_BEND_AFT_M, "mast_bend_across_m": bend_across_m,
	}
	for parameter: String in _cloth_values:
		_cloth.set_instance_shader_parameter(parameter, _cloth_values[parameter])
	_mast_tube.set_instance_shader_parameter("mast_bend_aft_m", MAST_BEND_AFT_M)
	_mast_tube.set_instance_shader_parameter("mast_bend_across_m", bend_across_m)


## The time since the last shape_sail call by the simulation clock, so the cloth eases at the
## same speed whatever the frame rate. On the first call, after a fall and after a reset (the
## clock went back) it returns a long step, so the cloth takes its shape at once.
func _cloth_time_step(time_s: float) -> float:
	var snap: bool = is_nan(_last_cloth_time_s) or time_s < _last_cloth_time_s
	var dt: float = SNAP_STEP_S if snap else minf(time_s - _last_cloth_time_s, 0.1)
	_last_cloth_time_s = time_s
	return dt
