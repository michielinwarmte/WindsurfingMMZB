class_name FinModel
extends RefCounted
## The fin: an underwater wing under the tail (PHYSICS_SPEC.md section 4). When the board
## slips sideways the water meets the fin at a small angle and the fin pushes back toward
## the wind, which is what turns the sail's sideways push into forward motion. The force
## acts at the fin's centre of pressure, so it also rolls and yaws the board by geometry.

var config: FinConfig

# Results of the last compute().
var slip_rad: float = 0.0
var cl: float = 0.0
var cd: float = 0.0
var lift_n: float = 0.0
var drag_n: float = 0.0
var force_world: Vector3 = Vector3.ZERO
var cop_world: Vector3 = Vector3.ZERO
var is_stalled: bool = false
var in_water: bool = false


func _init(fin_config: FinConfig) -> void:
	config = fin_config


func compute(body: SimRigidBody, surface: WaterSurface, time_s: float, rho_water: float) -> void:
	cop_world = body.point_world(config.cop_local())
	var root_world: Vector3 = body.point_world(config.root_local)
	in_water = surface.depth_at(root_world, time_s) > 0.0
	if not in_water:
		_clear()
		return

	# The flow the fin sees: its own motion (including the board's rotation) minus the water's.
	var v_rel: Vector3 = body.point_velocity(cop_world) - surface.velocity_at(cop_world.x, cop_world.z, time_s)
	var v_body: Vector3 = SimMath.to_body(body.basis, v_rel)
	var v_plane: Vector3 = Vector3(v_body.x, 0.0, v_body.z)  # flow in the fin's plane
	var speed: float = v_plane.length()
	if speed < config.min_speed_ms:
		_clear()
		return

	slip_rad = SimMath.slip_angle_rad(v_plane)
	cl = lift_coefficient(slip_rad)
	cd = drag_coefficient(cl, slip_rad)
	is_stalled = rad_to_deg(absf(slip_rad)) > config.stall_peak_deg

	var q: float = 0.5 * rho_water * speed * speed
	lift_n = q * config.area_m2 * absf(cl)
	drag_n = q * config.area_m2 * cd

	# Drag along the flow; lift perpendicular to it, in the fin's plane, against the slip.
	var flow_dir: Vector3 = v_plane / speed
	var lift_dir: Vector3 = signf(slip_rad) * Vector3(flow_dir.z, 0.0, -flow_dir.x)
	var force_body: Vector3 = lift_dir * lift_n - flow_dir * drag_n
	force_world = SimMath.to_world(body.basis, force_body)
	body.add_force_at(cop_world, force_world)


func _clear() -> void:
	slip_rad = 0.0
	cl = 0.0
	cd = 0.0
	lift_n = 0.0
	drag_n = 0.0
	force_world = Vector3.ZERO
	is_stalled = false


## Lift per radian for a finite wing: 2 pi AR / (AR + 2), with the hull acting as an end plate.
func lift_slope_per_rad() -> float:
	var ar: float = config.effective_aspect_ratio()
	return 2.0 * PI * ar / (ar + 2.0)


## Signed lift coefficient: linear, then a slower rise to the peak, a stall drop, a fade
## toward a flat plate, and a floor (section 4.4, continuous at every breakpoint).
func lift_coefficient(slip: float) -> float:
	var a_deg: float = rad_to_deg(absf(slip))
	var slope: float = lift_slope_per_rad()
	var cl_linear_end: float = slope * deg_to_rad(config.stall_linear_end_deg)
	var cl_max: float = cl_linear_end + config.stall_bump_cl
	var value: float
	if a_deg < config.stall_linear_end_deg:
		value = slope * absf(slip)
	elif a_deg < config.stall_peak_deg:
		value = cl_linear_end + config.stall_bump_cl * (a_deg - config.stall_linear_end_deg) / (config.stall_peak_deg - config.stall_linear_end_deg)
	elif a_deg < config.stall_drop_end_deg:
		value = lerpf(cl_max, config.post_stall_fraction * cl_max, (a_deg - config.stall_peak_deg) / (config.stall_drop_end_deg - config.stall_peak_deg))
	elif a_deg < config.deep_stall_deg:
		value = lerpf(config.post_stall_fraction * cl_max, config.deep_stall_cl, (a_deg - config.stall_drop_end_deg) / (config.deep_stall_deg - config.stall_drop_end_deg))
	else:
		value = maxf(config.deep_stall_cl * cos(deg_to_rad(2.0 * (a_deg - config.deep_stall_deg))), config.min_cl)
	return value * signf(slip)


## Profile drag plus induced drag (quadratic in lift) plus a small viscous term (section 4.5),
## plus the drag of a flat plate once the flow comes from the side: a fin swept sideways
## through the water (a drifting or spinning board) resists like a plate, with a drag
## coefficient of about 1.2 when square to the flow.
func drag_coefficient(lift_coeff: float, slip: float = 0.0) -> float:
	var induced: float = lift_coeff * lift_coeff / (PI * config.effective_aspect_ratio() * config.oswald_e)
	var plate: float = config.cd_plate * sin(slip) * sin(slip)
	return config.cd_profile + induced + config.cd_profile * absf(lift_coeff) * config.cd_viscous_factor + plate
