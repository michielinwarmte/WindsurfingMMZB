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
##   Its hull is painted with board_deck.png and board_bottom.png (_set_up_board).
## - fin.glb: the fin root, placed at FinConfig.root_local.
## - mast.glb and sail.glb: the mast foot (SailConfig.mast_foot_local), the mast up +y, the
##   boom along +x, so the clew is at (boom_m, boom_height_m, 0).
## - boom.glb: the mast at boom height. It is a child of the sail, so it follows the sail
##   angle and the rake.
## The sail cloth bends in a vertex shader (sail_cloth.gdshader): belly to leeward, twist,
## and flutter when it has no pressure in it, from the instance uniforms that shape_sail()
## sets. The mast (mast.gdshader) and the sail bend together: the top back and, with the
## pull, to leeward. The fin bends in fin_bend.gdshader by the simulation's beam (U2): its tip
## toward the side the fin's lift points, by FinModel.bend_tip_m, set every frame (_process).
##
## The gear page's gear (GearChoice, build()'s last argument): an item's own model and pictures
## take the place of the default ones where it has them, and the sail takes the item's cloth
## colour. The default models were built for the default board and the 8.0 (MODEL_BOARD,
## MODEL_SAIL); for gear of another size they are stretched to the size the simulation sails
## (board_stretch(), fit_sail()): a first approximation until there is a model per size.

const BOARD_MODEL: PackedScene = preload("res://assets/models/board.glb")
const FIN_MODEL: PackedScene = preload("res://assets/models/fin.glb")
const MAST_MODEL: PackedScene = preload("res://assets/models/mast.glb")
const SAIL_MODEL: PackedScene = preload("res://assets/models/sail.glb")
const BOOM_MODEL: PackedScene = preload("res://assets/models/boom.glb")
const SAIL_PANELS: Texture2D = preload("res://assets/models/sail_panels.png")
const BOARD_DECK: Texture2D = preload("res://assets/models/board_deck.png")
const BOARD_BOTTOM: Texture2D = preload("res://assets/models/board_bottom.png")
const SAIL_CLOTH_SHADER: Shader = preload("res://windsurfer/sail_cloth.gdshader")
const SAIL_WINDOW_SHADER: Shader = preload("res://windsurfer/sail_window.gdshader")
const MAST_SHADER: Shader = preload("res://windsurfer/mast.gdshader")
const FIN_BEND_SHADER: Shader = preload("res://windsurfer/fin_bend.gdshader")
## The board and the sail the default models were built for (build_rig_models.py reads the same
## files). The mast and the boom models are the 8.0's too.
const MODEL_BOARD: BoardConfig = preload("res://config/board_default.tres")
const MODEL_SAIL: SailConfig = preload("res://config/sail_default.tres")

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
## The sail's load as a force coefficient (the aerodynamic force over the dynamic pressure
## of the apparent wind times the sail area): at or below FLUTTER_FULL_LOAD the cloth has no
## pressure in it and flaps all over; from FLUTTER_NONE_LOAD up it is a taut membrane and
## does not move. A powered sail (angle of attack 10 to 18 degrees) has 0.8 to 1.1; the
## luff starts to collapse below about 0.45 (angle of attack 4 to 5 degrees, on the sail's
## curve measured in the wind tunnel, PH28).
const FLUTTER_FULL_LOAD: float = 0.1
const FLUTTER_NONE_LOAD: float = 0.45
## How fast the cloth flaps per m/s of apparent wind, Hz. A flapping flag keeps a nearly
## constant Strouhal number (frequency x length / wind speed, about 0.2 to 0.3), so its
## frequency grows in step with the wind (Virot et al. 2013; arXiv 2602.06237): with the
## shader's 0.9 m ripple length that is about 0.3 Hz per m/s, 3 Hz at 10 m/s.
const FLAP_HZ_PER_MS: float = 0.3
## Twist at the head, degrees: with a light pull and with a strong pull (the leech opens in
## a gust, as a real sail's does).
const TWIST_LIGHT_DEG: float = 8.0
const TWIST_LOADED_DEG: float = 16.0
## Sail lift at which the twist reaches TWIST_LOADED_DEG, N.
const TWIST_FULL_LIFT_N: float = 1200.0
## How far the masthead is bent back (the luff curve the downhaul pulls in), m, from the boom
## up, and how far it bends to leeward with a strong pull, m. A race sail's mast bends a lot:
## the Severne HGO 8.0 rigged in the wind tunnel (Zhang et al. 2025, figure 1) has its masthead
## about 0.9 m behind the line of the mast under the boom. build_rig_models.py reads this number
## and draws the flat sail that much forward, so the rigged sail has the real outline: rebuild
## the models after changing it.
const MAST_BEND_AFT_M: float = 0.85
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
var _fin_mesh: MeshInstance3D
var _fin_material: ShaderMaterial
## The sail's materials (the cloth, the clear film, the sleeve), for a race's sail colours
## (tint_sail).
var _sail_materials: Array[ShaderMaterial] = []
# The tip's sideways movement last given to the fin's shader, m (+ toward starboard).
var _fin_tip_deflection_m: float = 0.0

var _sail_config: SailConfig
# How the sail's model is fitted to the sail sailed (fit_sail()): stretched along the boom (x, also
# across the sail) and up the mast (y), and lifted up the mast, m. (1, 1) and 0 for the sail the
# model was built for.
var _sail_stretch: Vector2 = Vector2.ONE
var _sail_lift_m: float = 0.0
# The mast's model stretched to the mast's length, and the boom's to the boom's.
var _mast_stretch: float = 1.0
var _boom_stretch: float = 1.0
# The pose at the last sailing tick, from which a fall starts, and the way the mast lay on the
# water at the last fallen tick, from which it rises at a waterstart.
var _last_mast_dir: Vector3 = Vector3.UP
var _last_boom_dir: Vector3 = Vector3.BACK
var _lying_dir: Vector3 = Vector3.RIGHT
var _lying_boom_dir: Vector3 = Vector3.BACK
# The cloth's state, eased from tick to tick (see shape_sail).
var _belly_side: float = -1.0
var _flutter: float = 0.0
var _flutter_phase_rad: float = 0.0
var _last_cloth_time_s: float = NAN
# The values last given to the cloth's shader, by name (for tests and dev views).
var _cloth_values: Dictionary[String, float] = {}


## Loads the models and puts the board and fin in place. `gear` (the gear page's choice, or null
## for the default gear) brings its items' own models, pictures and cloth colour; the configs are
## the numbers the simulation sails, which the models are stretched to.
func build(board_config: BoardConfig, sail_config: SailConfig, fin_config: FinConfig, gear: GearChoice = null) -> void:
	var board_item: GearItem = gear.board if gear != null else null
	var sail_item: GearItem = gear.sail if gear != null else null
	var fin_item: GearItem = gear.fin if gear != null else null
	_sail_config = sail_config
	_board = _add_model(_model_of(board_item, BOARD_MODEL), "Board", self)
	_board.scale = board_stretch(board_config, _board_built_for(board_item))
	_set_up_board(_deck_of(board_item), _bottom_of(board_item))
	_fin = _add_model(_model_of(fin_item, FIN_MODEL), "Fin", self)
	_fin.position = fin_config.root_local
	_set_up_fin(fin_config)
	_fit_rig(sail_config, _sail_built_for(sail_item))
	_mast = _add_model(MAST_MODEL, "Mast", self)
	_sail = _add_model(_model_of(sail_item, SAIL_MODEL), "Sail", self)
	_boom = _add_model(BOOM_MODEL, "Boom", _sail)
	# The boom on the mast at the simulation's boom height, in the fitted sail's own axes, as long
	# as the sail's boom and as thick as the model's (the sail's stretch is undone).
	_boom.position = Vector3(0.0, _sail_height(sail_config.boom_height_m), 0.0)
	_boom.scale = Vector3(_boom_stretch / _sail_stretch.x, 1.0 / _sail_stretch.y, 1.0 / _sail_stretch.x)
	_cloth = _sail.find_child("SailCloth", true, false) as MeshInstance3D
	_mast_tube = _mast.find_child("Mast", true, false) as MeshInstance3D
	_set_up_cloth(sail_config, _panels_of(sail_item))
	_set_up_mast(sail_config)
	_set_cloth(_belly_side, sail_config.camber, deg_to_rad(TWIST_LIGHT_DEG), 0.0, 0.0)
	if sail_item != null:
		tint_sail(sail_item.cloth_colour())


## How the default board model is stretched to a board of another size: across by the width, up
## by the thickness, along by the length (1, 1, 1 for the board it was built for). The model's
## origin is the board's centre, as the simulation's is, so it stays in place.
static func board_stretch(board: BoardConfig, built_for: BoardConfig) -> Vector3:
	return Vector3(board.width_m / built_for.width_m, board.thickness_m / built_for.thickness_m,
		board.length_m / built_for.length_m)


## How a sail's model (built for the sail `built_for`) is fitted to the sail sailed, so that its
## clew sits at the end of the simulation's boom and its head just under the mast top: stretched
## along the boom by the boom's length (x, also across the sail, so the belly keeps its depth for
## the chord), stretched up the mast so the span from the boom to the head fits (y), and lifted up
## the mast by what is left (z, m; the foot moves up or down a little). (1, 1, 0) for the sail the
## model was built for. A first approximation: a smaller sail is not just a smaller copy of a big
## one, and the shaper builds a model per size later.
static func fit_sail(sail: SailConfig, built_for: SailConfig) -> Vector3:
	var along: float = sail.boom_m / built_for.boom_m
	var head_m: float = sail.mast_m - SAIL_HEAD_BELOW_MAST_TOP_M
	var model_head_m: float = built_for.mast_m - SAIL_HEAD_BELOW_MAST_TOP_M
	var up: float = (head_m - sail.boom_height_m) / (model_head_m - built_for.boom_height_m)
	var lift_m: float = sail.boom_height_m - up * built_for.boom_height_m
	return Vector3(along, up, lift_m)


## The default models' stretch for this sail: the sail's own (fit_sail()), the mast's to the
## mast's length and the boom's to the boom's (those two models are always the 8.0's).
func _fit_rig(sail_config: SailConfig, sail_built_for: SailConfig) -> void:
	var fit: Vector3 = fit_sail(sail_config, sail_built_for)
	_sail_stretch = Vector2(fit.x, fit.y)
	_sail_lift_m = fit.z
	_mast_stretch = sail_config.mast_m / MODEL_SAIL.mast_m
	_boom_stretch = sail_config.boom_m / MODEL_SAIL.boom_m


## A height up the mast (m from the mast foot, on the water) in the fitted sail model's own axes,
## where the cloth's shader works.
func _sail_height(height_m: float) -> float:
	return (height_m - _sail_lift_m) / _sail_stretch.y


## An item's own model, or the default part's.
static func _model_of(item: GearItem, default_model: PackedScene) -> PackedScene:
	return item.model if item != null and item.model != null else default_model


## The board a board's model was built for: the item's own numbers when it brings its own model.
static func _board_built_for(item: GearItem) -> BoardConfig:
	return item.config as BoardConfig if item != null and item.model != null else MODEL_BOARD


static func _sail_built_for(item: GearItem) -> SailConfig:
	return item.config as SailConfig if item != null and item.model != null else MODEL_SAIL


static func _deck_of(item: GearItem) -> Texture2D:
	return item.deck if item != null and item.deck != null else BOARD_DECK


static func _bottom_of(item: GearItem) -> Texture2D:
	return item.bottom if item != null and item.bottom != null else BOARD_BOTTOM


static func _panels_of(item: GearItem) -> Texture2D:
	return item.panels if item != null and item.panels != null else SAIL_PANELS


## Every frame, the fin's bend from the simulation, when this rig belongs to a sailing
## windsurfer (WindsurferNode, which holds the simulation as `sim`). It only reads.
func _process(_delta: float) -> void:
	var parent: Node = get_parent()
	var sim: WindsurferSim = parent.get("sim") as WindsurferSim if parent != null else null
	if sim != null and sim.fin != null:
		bend_fin(sim.fin, sim.body.basis)


## The fin's bend on screen: the tip moves sideways by the beam's deflection under the fin's
## lift (FinModel.bend_tip_m), toward the side the lift points. That is the windward side on
## either tack, the side the sail's pull is held against. `board_basis` is the board's
## orientation in the world (the simulation's body basis), to bring the force into the board's
## axes. The fin's drag lies along the flow, nearly fore and aft, so the force's sideways part
## has the lift's sign.
func bend_fin(fin: FinModel, board_basis: Basis) -> void:
	var side: float = signf(SimMath.to_body(board_basis, fin.force_world).x)
	_fin_tip_deflection_m = side * fin.bend_tip_m
	_fin_material.set_shader_parameter("tip_deflection_m", _fin_tip_deflection_m)


## The tip's sideways movement last given to the fin's shader (m, + toward starboard), for
## tests and dev views.
func fin_tip_deflection_m() -> float:
	return _fin_tip_deflection_m


## The fin's mesh, for tests and dev views.
func fin_mesh() -> MeshInstance3D:
	return _fin_mesh


## The bending fin's shape along the span, from the simulation's own beam (FinModel): at each
## of its 21 strip edges, root to tip, the sideways movement as a share of the tip's, and the
## slope of that share per span length. A beam's deflection is its load over its stiffness, so
## the shape is the same whatever the load and the stiffness scale S: it is worked out with
## S = 1, and the simulation's tip movement scales it.
static func fin_bend_shape(fin_config: FinConfig) -> Array[PackedFloat32Array]:
	var beam: FinModel = FinModel.new(fin_config)
	var span: float = fin_config.span_m
	var step: float = span / FinModel.BEND_STRIPS
	var stiffness: PackedFloat64Array = beam.edge_stiffness(span, fin_config.root_chord_m(), 1.0)
	var slopes: PackedFloat64Array = FinModel.beam_slopes(FinModel.elliptic_moments_per_n(span), stiffness, step)
	var deflections: PackedFloat64Array = FinModel.beam_deflections(slopes, step)
	var tip: float = deflections[FinModel.BEND_STRIPS]
	var shape: PackedFloat32Array = PackedFloat32Array()
	var slope: PackedFloat32Array = PackedFloat32Array()
	for j: int in FinModel.BEND_STRIPS + 1:
		shape.append(deflections[j] / tip)
		slope.append(slopes[j] * span / tip)
	return [shape, slope]


## The rig while sailing: the mast from the mast foot along `mast_dir`, the sail and the
## boom in the plane of the mast and `boom_dir`. Both directions are unit vectors in the
## board's axes.
func pose_sailing(mast_dir: Vector3, boom_dir: Vector3) -> void:
	_pose_rig(mast_dir, boom_dir)
	_last_mast_dir = mast_dir
	_last_boom_dir = boom_dir


## The sail's cloth from the simulation: the belly on the leeward side (the side the boom is
## on, or the other side when the wind is on the sail's back), the twist from the pull, and
## flutter when there is little pressure in the sail. `time_s` is the simulation clock.
func shape_sail(sail: SailModel, time_s: float) -> void:
	var dt: float = _cloth_time_step(time_s)
	var target_side: float = belly_side_for(sail.sail_side, sail.is_backwinded)
	_belly_side = move_toward(_belly_side, target_side, BELLY_SWITCH_RATE * dt)
	_flutter = move_toward(_flutter, flutter_for(sail), FLUTTER_RATE * dt)
	# A sail flaps faster in more wind.
	var flap_hz: float = FLAP_HZ_PER_MS * sail.aws_ms
	_flutter_phase_rad = fposmod(_flutter_phase_rad + TAU * flap_hz * dt, TAU)
	var pull: float = clampf(absf(sail.lift_n) / TWIST_FULL_LIFT_N, 0.0, 1.0)
	var twist_rad: float = deg_to_rad(lerpf(TWIST_LIGHT_DEG, TWIST_LOADED_DEG, pull))
	# A luffing sail loses most of its belly.
	var camber: float = sail.config.camber * (1.0 - 0.6 * _flutter)
	_set_cloth(_belly_side, camber, twist_rad, _flutter, pull)


## The fall on screen: the rig pivots about the mast foot until it lies on the water on the
## side of the fall. `eased` runs from 0 (the fall starts) to 1 (the rig is down), `side`
## is -1 for port and +1 for starboard. The cloth goes slack. Then, as the sailor swims to the
## windward side to waterstart (`swim` 0 to 1, `windward` the side: +1 starboard), a rig that fell
## to leeward is pulled round the front of the board onto the water on the windward side, where
## it rises from at the waterstart (pose_rising).
func pose_fallen(eased: float, side: float, swim: float = 0.0, windward: float = 0.0) -> void:
	var flat: Vector3 = Vector3(side, 0.03, 0.0).normalized()
	if swim > 0.0 and windward != 0.0 and signf(windward) != signf(side):
		flat = flat.rotated(Vector3.UP, signf(side) * PI * smoothstep(0.0, 1.0, swim))
	_lying_dir = flat
	_lying_boom_dir = _last_boom_dir
	var mast_dir: Vector3 = _last_mast_dir.slerp(flat, eased).normalized()
	_pose_rig(mast_dir, _last_boom_dir)
	var camber: float = _sail_config.camber * lerpf(1.0, 0.3, eased)
	_set_cloth(_belly_side, camber, deg_to_rad(TWIST_LIGHT_DEG) * (1.0 - eased), 0.0, 0.0)
	_flutter = 0.0
	_last_cloth_time_s = NAN


## A waterstart on screen: the rig rises from where it lay on the water up to the sailing pose
## (`mast_dir` and `boom_dir`, as pose_sailing takes them), `raised` from 0 (lying) to 1 (up).
func pose_rising(mast_dir: Vector3, boom_dir: Vector3, raised: float) -> void:
	var eased: float = smoothstep(0.0, 1.0, raised)
	var drawn_mast: Vector3 = _lying_dir.slerp(mast_dir, eased).normalized()
	var drawn_boom: Vector3 = _lying_boom_dir.slerp(boom_dir, eased).normalized() if _lying_boom_dir.dot(boom_dir) > -0.99 else boom_dir
	_pose_rig(drawn_mast, drawn_boom)
	_last_mast_dir = drawn_mast
	_last_boom_dir = drawn_boom


## Which way the belly bulges in the sail's frame (z = boom direction x mast direction).
## That z points to port whichever side the boom is on, so a sail on the starboard side
## (sail_side +1, the wind from port) bulges toward -z, away from the wind. A backwinded sail
## has the wind on its leeward face and is pushed inside out.
static func belly_side_for(sail_side: int, backwinded: bool) -> float:
	var leeward: float = -float(sail_side)
	return -leeward if backwinded else leeward


## How much the sail's cloth flutters (0 to 1) from the simulation's sail. Sail cloth is a
## membrane: the pressure difference across it is what pulls it tight (like the skin of a
## balloon), so a sail with lift in it holds its shape and does not move. It flaps when that
## pressure is gone: when the sail is eased until the wind runs along both faces, the luff
## collapses first (the "bubble" behind the mast that sailors trim by), and with no pressure
## left the whole cloth flogs like a flag (https://en.wikipedia.org/wiki/Luffing).
## The shader shows a small flutter value as ripples near the luff only and a large one as
## the whole cloth flapping. In very light air the cloth just hangs.
static func flutter_for(sail: SailModel) -> float:
	var air: float = clampf(sail.aws_ms / 3.0, 0.0, 1.0)
	return flutter_for_load(sail_load(sail.cl, sail.cd)) * air


## The sail's load as a force coefficient: the lift and drag together over the dynamic
## pressure of the apparent wind times the area (the simulation's cl and cd are exactly
## that: lift_n = 0.5 rho aws^2 area cl). It compares the pull with what the apparent wind
## could give, so it means the same in light air and in a gale.
static func sail_load(cl: float, cd: float) -> float:
	return Vector2(cl, cd).length()


## The flutter (0 to 1) at a load coefficient: all over at FLUTTER_FULL_LOAD and below, none
## from FLUTTER_NONE_LOAD.
static func flutter_for_load(load_coefficient: float) -> float:
	return 1.0 - smoothstep(FLUTTER_FULL_LOAD, FLUTTER_NONE_LOAD, load_coefficient)


## From the boom's centre line to the windward arm at the hand grip, in the board's axes:
## where the hands hold the wishbone (the simulation's grip is on the centre line). When the sail
## changes sides the windward arm changes over with the belly (it shrinks through the centre line
## as the belly goes over), so a hand holding on near the mast moves across smoothly; taken by the
## belly's sign alone it jumped half a metre in one tick in the middle of the flip.
func windward_arm_offset() -> Vector3:
	var leeward_dir: Vector3 = _sail.transform.basis.z.normalized() * clampf(_belly_side, -1.0, 1.0)
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
	# Both models are stretched to the sail sailed (fit_sail(), 1 for the 8.0).
	var sail_basis: Basis = Basis(boom_dir * _sail_stretch.x, mast_dir * _sail_stretch.y, sail_normal * _sail_stretch.x)
	_sail.transform = Transform3D(sail_basis, foot + mast_dir * _sail_lift_m)
	var mast_up: Vector3 = mast_dir.normalized()
	_mast.transform = Transform3D(Basis(mast_up.cross(sail_normal).normalized(), mast_up * _mast_stretch, sail_normal), foot)


func _add_model(model: PackedScene, node_name: String, parent: Node3D) -> Node3D:
	var instance: Node3D = model.instantiate() as Node3D
	instance.name = node_name
	parent.add_child(instance)
	return instance


## Gives the cloth's three surfaces (cloth, clear film, sleeve) their shader materials, with the
## panel picture and the colours the model was built with (the cloth's red is the reference for
## a race's tint, the sleeve has its own red). `panels` is the panel picture (an item's own or
## sail_panels.png).
func _set_up_cloth(sail_config: SailConfig, panels: Texture2D) -> void:
	var cloth_material: ShaderMaterial = _cloth_material(SAIL_CLOTH_SHADER, sail_config, panels)
	var sleeve_material: ShaderMaterial = _cloth_material(SAIL_CLOTH_SHADER, sail_config, panels)
	sleeve_material.set_shader_parameter("is_sleeve", true)
	var window_material: ShaderMaterial = _cloth_material(SAIL_WINDOW_SHADER, sail_config, panels)
	var by_name: Dictionary[String, ShaderMaterial] = {
		"sail_cloth": cloth_material, "sail_window": window_material, "sail_sleeve": sleeve_material,
	}
	_sail_materials = [cloth_material, window_material, sleeve_material]
	var mesh: Mesh = _cloth.mesh
	for surface: int in mesh.get_surface_count():
		var imported: BaseMaterial3D = mesh.surface_get_material(surface) as BaseMaterial3D
		var surface_name: String = imported.resource_name if imported != null else ""
		if by_name.has(surface_name):
			_cloth.set_surface_override_material(surface, by_name[surface_name])
		else:
			push_warning("sail.glb has an unexpected surface '%s'." % surface_name)
		if surface_name == "sail_cloth":
			for material: ShaderMaterial in _sail_materials:
				material.set_shader_parameter("main_colour", imported.albedo_color)
		elif surface_name == "sail_sleeve":
			sleeve_material.set_shader_parameter("sleeve_color", imported.albedo_color)
	# The shader moves the cloth up to about 0.3 m off its flat shape, and the mast's bend
	# moves the head back by MAST_BEND_AFT_M: widen the box the engine uses to decide whether
	# the sail is on screen.
	_cloth.extra_cull_margin = 0.3 + MAST_BEND_AFT_M


## Gives the fin the shader that bends it (fin_bend.gdshader), with the model's own colour and
## shine. The model was built for the default fin; another span (a 44 cm fin from the command
## line) stretches it down to that span, so the bend is drawn on a fin of the right length.
## Its chord stays the model's (2.6 % wider at the root than a 44 cm fin's chord law).
func _set_up_fin(fin_config: FinConfig) -> void:
	_fin_mesh = _fin.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var model_span_m: float = -_fin_mesh.get_aabb().position.y
	_fin.scale = Vector3(1.0, fin_config.span_m / model_span_m, 1.0)
	_fin_material = ShaderMaterial.new()
	_fin_material.shader = FIN_BEND_SHADER
	_fin_material.set_shader_parameter("span_m", model_span_m)
	var shape: Array[PackedFloat32Array] = fin_bend_shape(fin_config)
	_fin_material.set_shader_parameter("bend_shape", shape[0])
	_fin_material.set_shader_parameter("bend_slope", shape[1])
	_fin_material.set_shader_parameter("tip_deflection_m", 0.0)
	var imported: BaseMaterial3D = _fin_mesh.mesh.surface_get_material(0) as BaseMaterial3D
	if imported != null:
		_fin_material.set_shader_parameter("albedo", imported.albedo_color)
		_fin_material.set_shader_parameter("roughness_value", imported.roughness)
		_fin_material.set_shader_parameter("metallic_value", imported.metallic)
		_fin_material.set_shader_parameter("specular_value", imported.metallic_specular)
	_fin_mesh.material_override = _fin_material
	# The shader moves the tip up to about 0.15 m sideways (a 44 cm fin under a hard push):
	# widen the box the engine uses to decide whether the fin is on screen.
	_fin_mesh.extra_cull_margin = 0.2


## Gives the mast's carbon tube the shader that bends it (the extension below stays straight).
## The heights are in the mast model's own axes (stretched to the mast's length).
func _set_up_mast(sail_config: SailConfig) -> void:
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = MAST_SHADER
	material.set_shader_parameter("mast_length_m", sail_config.mast_m / _mast_stretch)
	material.set_shader_parameter("mast_bend_start_m", sail_config.boom_height_m / _mast_stretch)
	var mesh: Mesh = _mast_tube.mesh
	for surface: int in mesh.get_surface_count():
		var imported: Material = mesh.surface_get_material(surface)
		if imported != null and imported.resource_name == "carbon":
			_mast_tube.set_surface_override_material(surface, material)
	_mast_tube.extra_cull_margin = 0.1 + MAST_BEND_AFT_M


## The cloth's material. Its heights are in the fitted sail model's own axes (_sail_height()), so
## the cloth bends with the mast at the same heights on the water.
func _cloth_material(shader: Shader, sail_config: SailConfig, panels: Texture2D) -> ShaderMaterial:
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("panel_texture", panels)
	material.set_shader_parameter("mast_length_m", _sail_height(sail_config.mast_m))
	material.set_shader_parameter("mast_bend_start_m", _sail_height(sail_config.boom_height_m))
	material.set_shader_parameter("boom_height_m", _sail_height(sail_config.boom_height_m))
	material.set_shader_parameter("head_height_m", _sail_height(sail_config.mast_m - SAIL_HEAD_BELOW_MAST_TOP_M))
	return material


## Sets the cloth's shape, and the mast's bend: back by the luff curve, and to leeward (the
## belly's side) by `pull` (0 to 1) of the full sideways bend.
func _set_cloth(belly_side: float, camber: float, twist_head_rad: float, flutter: float, pull: float) -> void:
	var bend_across_m: float = belly_side * MAST_BEND_LEEWARD_M * pull
	# The sail's model may be stretched along the boom and across (fit_sail()): its bend is given
	# in its own axes, so that on the water it bends as far as the mast.
	_cloth_values = {
		"belly_side": belly_side, "camber": camber, "twist_head_rad": twist_head_rad,
		"flutter": flutter, "flutter_phase_rad": _flutter_phase_rad,
		"mast_bend_aft_m": MAST_BEND_AFT_M / _sail_stretch.x, "mast_bend_across_m": bend_across_m / _sail_stretch.x,
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


## Gives the sail a race colour, so the boards of a race tell apart: the colour takes the place
## of the sail's own red; the prints (the flag, the number, the stripe) and the clear film stay
## (white keeps the sail as it is; sail_colour in sail_cloth.gdshaderinc).
func tint_sail(colour: Color) -> void:
	for material: ShaderMaterial in _sail_materials:
		material.set_shader_parameter("sail_tint", colour)


## Paints the hull with the deck's and the bottom's pictures (board_deck.png and
## board_bottom.png, drawn by build_rig_models.py in the hull's UV: the board seen from above, or
## a gear item's own).
func _set_up_board(deck: Texture2D, bottom: Texture2D) -> void:
	var hull: MeshInstance3D = _board.find_child("Hull", true, false) as MeshInstance3D
	if hull == null:
		push_warning("The board's model has no mesh called Hull: its pictures are not painted on.")
		return
	var pictures: Dictionary[String, Texture2D] = {"board_deck": deck, "board_bottom": bottom}
	for surface: int in hull.mesh.get_surface_count():
		var imported: BaseMaterial3D = hull.mesh.surface_get_material(surface) as BaseMaterial3D
		if imported == null or not pictures.has(imported.resource_name):
			continue
		var material: BaseMaterial3D = imported.duplicate() as BaseMaterial3D
		material.albedo_color = Color.WHITE
		material.albedo_texture = pictures[imported.resource_name]
		material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		hull.set_surface_override_material(surface, material)
