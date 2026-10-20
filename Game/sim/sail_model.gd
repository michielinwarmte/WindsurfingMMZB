class_name SailModel
extends RefCounted
## The sail: apparent wind, angle of attack, lift and drag, and the point on the rig where
## the force acts (PHYSICS_SPEC.md sections 1 and 2). A two-dimensional model in the
## horizontal plane: the rig stands vertically over the water and the force is horizontal.
##
## The sail side (which side of the board the boom is on) follows the wind with a little
## hysteresis, as a real sail does (section 2.14). The player steers the board through the
## wind to tack; nothing flips the sail by hand.
##
## Boards on threads (F1 no_wait): reading a field of another object, as config.area_m2 or
## rig.basis, takes a global engine lock, and boards stepped side by side on worker threads
## wait for each other there; calling a method of it does not. So compute() reads the rig once
## at its top and uses copies of the config's numbers kept in this model's own fields, taken by
## copy_config(): when the model is made and at the start of every tick (WindsurferSim.step).
## The config is never changed inside a tick, so the copies are the config's numbers. The
## coefficient curves (lift_coefficient(), drag_coefficient()) still read the config itself:
## the autopilot asks them too, from the main thread, outside the simulation's ticks.

var config: SailConfig

## The config's numbers that compute() uses (copy_config()).
var _area_m2: float = 0.0
var _luff_m: float = 0.0
var _boom_m: float = 0.0
var _mast_foot_local: Vector3 = Vector3.ZERO
var _ce_height_fraction: float = 0.0
var _ce_boom_fraction: float = 0.0
var _sheet_angle_in_deg: float = 0.0
var _sheet_angle_out_deg: float = 0.0
var _side_hysteresis_deg: float = 0.0
var _alpha_luff_deg: float = 0.0
var _boom_across_max_deg: float = 0.0
var _min_apparent_wind_ms: float = 0.0

## +1 = boom and clew on the starboard side (port tack), -1 = boom on the port side
## (starboard tack). Starts on starboard tack.
var sail_side: int = -1

# Results of the last compute().
var rake_rad: float = 0.0
## Sideways lean of the mast, positive = mast top toward starboard (the rig tips toward the sailor).
var rig_lean_rad: float = 0.0
var sheet_angle_rad: float = 0.0
var alpha_rad: float = 0.0
var cl: float = 0.0
var cd: float = 0.0
var lift_n: float = 0.0
var drag_n: float = 0.0
var force_world: Vector3 = Vector3.ZERO
var drive_n: float = 0.0
var side_force_n: float = 0.0
var ce_local: Vector3 = Vector3.ZERO
var ce_world: Vector3 = Vector3.ZERO
## Unit vector along the boom from the mast, body axes (toward the clew).
var boom_direction_local: Vector3 = Vector3.BACK
var is_luffing: bool = false
## The wind is on the sail's leeward face: the sail has inverted and pushes the other way.
var is_backwinded: bool = false
var apparent_wind_world: Vector3 = Vector3.ZERO
var aws_ms: float = 0.0
var awa_rad: float = 0.0
var true_wind_at_ce_world: Vector3 = Vector3.ZERO
## Torque of the sail force about the centre of mass, in body axes (z = heeling).
var torque_body: Vector3 = Vector3.ZERO


func _init(sail_config: SailConfig) -> void:
	config = sail_config
	copy_config()


## Copies the config's numbers that compute() uses into this model's own (see the note at the
## top).
func copy_config() -> void:
	_area_m2 = config.area_m2
	_luff_m = config.luff_m
	_boom_m = config.boom_m
	_mast_foot_local = config.mast_foot_local
	_ce_height_fraction = config.ce_height_fraction
	_ce_boom_fraction = config.ce_boom_fraction
	_sheet_angle_in_deg = config.sheet_angle_in_deg
	_sheet_angle_out_deg = config.sheet_angle_out_deg
	_side_hysteresis_deg = config.side_hysteresis_deg
	_alpha_luff_deg = config.alpha_luff_deg
	_boom_across_max_deg = config.boom_across_max_deg
	_min_apparent_wind_ms = config.min_apparent_wind_ms


## Puts the sail on the leeward side of a given apparent wind angle, keeping the current
## side when the wind is within the hysteresis band of dead ahead or dead astern.
func update_side(apparent_wind_angle_rad: float) -> void:
	var band: float = deg_to_rad(_side_hysteresis_deg)
	var magnitude: float = absf(apparent_wind_angle_rad)
	if magnitude < band or magnitude > PI - band:
		return
	sail_side = -1 if apparent_wind_angle_rad > 0.0 else 1


## Forces the side (used when the simulation is reset facing a known wind).
func set_side_for_wind(apparent_wind_angle_rad: float) -> void:
	sail_side = -1 if apparent_wind_angle_rad >= 0.0 else 1


## Computes the sail force for the rig's state: force_world at ce_world. It is not applied
## here: the simulation carries it into the hull at the mast foot and into the sailor at the
## hands (WindsurferSim._apply_rig_forces). torque_body is its torque about the hull's
## centre of mass, in the rig's axes, for reference. The rig frame says where the mast foot
## is, which way the rig points (the axes the sailor holds it in) and how it moves.
## held_side: 0 lets the wind decide which side the sail is on; +1 or -1 is the sailor
## holding the rig on that side (through a tack, until they flip it).
func compute(rig: RigFrame, wind: WindField, sheet: float, rake: float, rho_air: float, rig_lean: float = 0.0, boom_across: float = 0.0, held_side: int = 0) -> void:
	# The hull's centre of mass, read once (see the note at the top); the rig's axes are asked
	# through its methods (rig.to_body() and so on), which hand no Basis over.
	var rig_position: Vector3 = rig.position
	rake_rad = clampf(rake, -1.0, 1.0) * config.max_rake_rad()
	rig_lean_rad = rig_lean
	# The boom angle on the sail's side; pushed across the centreline it goes negative.
	sheet_angle_rad = lerpf(deg_to_rad(_sheet_angle_out_deg), deg_to_rad(_sheet_angle_in_deg), clampf(sheet, 0.0, 1.0)) \
		- clampf(boom_across, 0.0, 1.0) * deg_to_rad(_boom_across_max_deg)

	# The apparent wind is sampled where the sail is. The side decision uses the point
	# on the mast, which does not depend on the side; the chord offset is added after.
	var ce_height: float = _ce_height_fraction * _luff_m
	var mast_point_local: Vector3 = _mast_foot_local + mast_direction() * ce_height
	var mast_point_world: Vector3 = rig.point_world(mast_point_local)
	true_wind_at_ce_world = wind.velocity_at(mast_point_world)
	var apparent_at_mast: Vector3 = true_wind_at_ce_world - rig.point_velocity(mast_point_world)
	var apparent_h: Vector3 = SimMath.horizontal(apparent_at_mast)
	if held_side != 0:
		sail_side = held_side
	elif apparent_h.length() >= _min_apparent_wind_ms:
		update_side(rig.wind_angle_rad(-apparent_h))

	# Boom direction and the centre of effort (section 2.2 and 2.13), in body axes.
	var chord_local: Vector3 = Vector3(sail_side * sin(sheet_angle_rad), 0.0, cos(sheet_angle_rad))
	boom_direction_local = chord_local
	ce_local = mast_point_local + chord_local * (_ce_boom_fraction * _boom_m)
	ce_world = rig.point_world(ce_local)

	apparent_wind_world = wind.velocity_at(ce_world) - rig.point_velocity(ce_world)
	var w: Vector3 = SimMath.horizontal(apparent_wind_world)
	aws_ms = w.length()
	if aws_ms < _min_apparent_wind_ms:
		_clear_forces()
		return
	awa_rad = rig.wind_angle_rad(-w)

	# Everything else happens in the horizontal "heading frame": f = bow, r = starboard.
	# A board standing on its nose or tail has no heading frame; then there is no sail force.
	var f: Vector3 = SimMath.horizontal(rig.forward())
	if f.length() < 0.1:
		_clear_forces()
		return
	f = f.normalized()
	var r: Vector3 = f.cross(Vector3.UP)
	var w_hat: Vector3 = w / aws_ms
	var from_hat: Vector3 = -w_hat
	# Unit normal to the chord pointing away from the sail side (toward the windward side):
	# the face the wind should hit. Body axes: (-sail_side * cos, 0, +sin) with z aft, so in
	# the heading frame the aft part is -f. (PHYSICS_SPEC.md 2.2 wrote the x sign wrongly for
	# the boom on the starboard side; the mirror-symmetry test caught it.)
	var n0: Vector3 = r * (-sail_side * cos(sheet_angle_rad)) - f * sin(sheet_angle_rad)
	var sin_alpha: float = clampf(from_hat.dot(n0), -1.0, 1.0)
	alpha_rad = asin(sin_alpha)
	is_luffing = absf(alpha_rad) < deg_to_rad(_alpha_luff_deg)
	is_backwinded = alpha_rad <= -deg_to_rad(_alpha_luff_deg)

	cl = lift_coefficient(alpha_rad)
	cd = drag_coefficient(cl, alpha_rad)
	var q: float = 0.5 * rho_air * aws_ms * aws_ms
	lift_n = q * _area_m2 * cl
	drag_n = q * _area_m2 * cd

	# Lift: perpendicular to the apparent wind, on the suction side of the sail (section 2.11).
	var force_normal: Vector3 = -signf(alpha_rad) * n0
	if absf(alpha_rad) < 1e-6:
		force_normal = -n0
	var lift_dir: Vector3 = force_normal - force_normal.dot(w_hat) * w_hat
	if lift_dir.length() > 0.1:
		lift_dir = lift_dir.normalized()
	else:
		lift_dir = Vector3.ZERO
		lift_n = 0.0
	# A rig leaned sideways tilts the sail plane, and the lift (perpendicular to the sail)
	# with it: leaned to windward the sail pulls upward as well as to leeward, which is the
	# "lift" windsurfers feel in the harness. The drag stays along the wind.
	lift_dir = lift_dir.rotated(f, rig_lean_rad)
	force_world = lift_dir * lift_n + w_hat * drag_n
	drive_n = force_world.dot(f)
	side_force_n = force_world.dot(r)

	torque_body = rig.to_body((ce_world - rig_position).cross(force_world))


## Forgets the last forces (the rig is in the water).
func clear() -> void:
	_clear_forces()


func _clear_forces() -> void:
	alpha_rad = 0.0
	cl = 0.0
	cd = 0.0
	lift_n = 0.0
	drag_n = 0.0
	force_world = Vector3.ZERO
	drive_n = 0.0
	side_force_n = 0.0
	is_luffing = true
	is_backwinded = false
	torque_body = Vector3.ZERO


## Signed boom angle for the visuals: positive when the clew is to starboard.
func sail_angle_rad() -> float:
	return sail_side * sheet_angle_rad


## Unit vector along the mast in body axes: raked back by rake_rad, tipped sideways by
## rig_lean_rad (positive toward starboard).
func mast_direction() -> Vector3:
	return Vector3(sin(rig_lean_rad), cos(rig_lean_rad) * cos(rake_rad), cos(rig_lean_rad) * sin(rake_rad))


## Size of the lift coefficient against the angle of attack: the legacy curve made
## continuous, with the luff fade within alpha_luff of zero (section 2.7 and 2.9). The
## direction of the force is decided in compute(): a backwinded sail (negative angle) pushes
## the other way with backwind_efficiency of the lift, as an inverted cambered sail does.
func lift_coefficient(alpha: float) -> float:
	var a_deg: float = rad_to_deg(absf(alpha))
	var slope: float = lift_slope_per_rad()
	var alpha_zero_lift: float = -deg_to_rad(config.zero_lift_deg_per_camber * config.camber)
	var cl_linear_end: float = slope * (deg_to_rad(config.cl_linear_end_deg) - alpha_zero_lift)
	var cl_max: float = cl_linear_end + config.cl_transition_gain
	var value: float
	if a_deg < config.cl_linear_end_deg:
		value = slope * (deg_to_rad(a_deg) - alpha_zero_lift)
	elif a_deg < config.cl_peak_deg:
		value = cl_linear_end + config.cl_transition_gain * (a_deg - config.cl_linear_end_deg) / (config.cl_peak_deg - config.cl_linear_end_deg)
	elif a_deg < config.cl_stall_end_deg:
		value = lerpf(cl_max, config.stall_retention * cl_max, (a_deg - config.cl_peak_deg) / (config.cl_stall_end_deg - config.cl_peak_deg))
	elif a_deg < config.cl_deep_stall_deg:
		value = lerpf(config.stall_retention * cl_max, config.deep_stall_cl, (a_deg - config.cl_stall_end_deg) / (config.cl_deep_stall_deg - config.cl_stall_end_deg))
	else:
		value = config.deep_stall_cl * cos(deg_to_rad(a_deg - config.cl_deep_stall_deg))
	var backwinded: float = config.backwind_efficiency if alpha < 0.0 else 1.0
	return value * luff_factor(alpha) * backwinded


## Near zero angle of attack the luff collapses and the sail flaps: the lift fades out
## within alpha_luff of zero on either side.
func luff_factor(alpha: float) -> float:
	var a: float = absf(alpha)
	var alpha_luff: float = deg_to_rad(config.alpha_luff_deg)
	if a < alpha_luff:
		return a / alpha_luff
	return 1.0


## Parasitic, induced, separation and flat-plate drag, capped at cd_max (section 2.8).
func drag_coefficient(lift_coeff: float, alpha: float) -> float:
	var a_deg: float = rad_to_deg(absf(alpha))
	# The induced drag sees the aspect ratio with the deck's end-plate effect.
	var induced: float = lift_coeff * lift_coeff / (PI * config.aspect_ratio() * config.oswald_e)
	var separation: float = 0.0
	if a_deg > config.cd_separation_start_deg:
		var x: float = (a_deg - config.cd_separation_start_deg) / config.cd_separation_span_deg
		separation = config.cd_separation_gain * x * x
	var form: float = 0.0
	if a_deg > config.cl_deep_stall_deg:
		form = config.cd_form_gain * sin(deg_to_rad(a_deg))
	return minf(config.cd_parasitic + induced + separation + form, config.cd_max)


## Lift per radian of angle of attack for this sail's aspect ratio (section 2.4).
func lift_slope_per_rad() -> float:
	# The geometric aspect ratio: the lift curve of section 2 is the measured one of a sail
	# in a wind tunnel, which the deck's end plate (config.aspect_ratio()) must not inflate;
	# that end plate only cuts the induced drag.
	var ar: float = config.geometric_aspect_ratio()
	return 2.0 * PI * ar / (ar + 2.0) * config.lift_slope_factor
