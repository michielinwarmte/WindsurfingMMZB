class_name FinModel
extends RefCounted
## The fin: an underwater wing under the tail (PHYSICS_SPEC.md section 4). When the board
## slips sideways the water meets the fin at a small angle and the fin pushes back toward
## the wind, which is what turns the sail's sideways push into forward motion. The force
## acts at the fin's centre of pressure, so it also rolls and yaws the board by geometry.
##
## The fin bends (U2, section 4 "The fin bends"). It is a beam clamped in the fin box and
## loaded by its own lift. It bends toward the side its lift points, most at the slender tip,
## and each bent piece of fin pushes square to itself: partly sideways, partly up toward the
## deck. The beam is worked out once, when the fin is made (_prepare_bend); each step only
## scales it by the lift (_bend), because a beam's bend is proportional to its load.

## The fin is cut into this many strips along the span for the beam.
const BEND_STRIPS: int = 20

var config: FinConfig

# The beam, worked out once in _prepare_bend().
## S in EI(y) = S * c(y)^4: the fin's bending stiffness is this scale times the chord to the
## fourth power (N/m^2), set so that the beam repeats the flex test.
var stiffness_scale: float = 0.0
## Each strip's share of the lift (elliptic from the root; the shares add up to 1).
var strip_share: PackedFloat64Array = PackedFloat64Array()
## Each strip's slope (its turn away from straight down) per newton of lift (rad/N).
var strip_slope_per_n: PackedFloat64Array = PackedFloat64Array()
## The tip's slope and its sideways movement per newton of lift (rad/N and m/N).
var tip_slope_per_n: float = 0.0
var tip_deflection_per_n: float = 0.0

# Results of the last compute().
var slip_rad: float = 0.0
var cl: float = 0.0
var cd: float = 0.0
var lift_n: float = 0.0
var drag_n: float = 0.0
var force_world: Vector3 = Vector3.ZERO
var cop_world: Vector3 = Vector3.ZERO
var is_stalled: bool = false
var immersed_fraction: float = 1.0
var in_water: bool = false
# The bend under the last lift: the tip's slope (rad) and sideways movement (m), and the
# shares of the lift that push sideways (in the stiff fin's lift direction) and up (along the
# board's +y).
var bend_tip_rad: float = 0.0
var bend_tip_m: float = 0.0
var side_share: float = 1.0
var up_share: float = 0.0


func _init(fin_config: FinConfig) -> void:
	config = fin_config
	_prepare_bend()


func compute(body: SimRigidBody, surface: WaterSurface, time_s: float, rho_water: float) -> void:
	cop_world = body.point_world(config.cop_local())
	# The part of the span that is in the water: all of it with the root under the surface,
	# less when the tail has lifted and the root is in the air (a tack with the sailor's
	# weight forward, a bounce). The force scales with the immersed area.
	var root_world: Vector3 = body.point_world(config.root_local)
	var root_depth: float = surface.depth_at(root_world, time_s)
	immersed_fraction = clampf((root_depth + config.span_m) / config.span_m, 0.0, 1.0)
	in_water = immersed_fraction > 0.0
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
	lift_n = q * config.area_m2 * immersed_fraction * absf(cl)
	drag_n = q * config.area_m2 * immersed_fraction * cd

	# Drag along the flow; lift perpendicular to it, against the slip. A stiff fin's lift lies
	# in the board's plane; the bent fin turns a part of it up toward the deck (_bend).
	var flow_dir: Vector3 = v_plane / speed
	var lift_dir: Vector3 = signf(slip_rad) * Vector3(flow_dir.z, 0.0, -flow_dir.x)
	_bend(lift_n)
	var force_body: Vector3 = lift_dir * (lift_n * side_share) + Vector3.UP * (lift_n * up_share) - flow_dir * drag_n
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
	_bend(0.0)


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


# --- The bending fin (section 4, "The fin bends") ---------------------------------------
#
# The beam is described at the 21 edges of its 20 strips, from the root (edge 0, clamped in
# the fin box) to the tip (edge 20); y is the distance below the root. For a load on the fin,
# the bending moment M(y) is what the load beyond y does about y. The beam curves by M / EI
# there; its slope is that curvature added up from the root, and its sideways movement (the
# deflection) is the slope added up from the root (an Euler-Bernoulli cantilever).


## The bend under a lift of `lift` newtons. The beam is linear, so each strip turns by the lift
## times its turn per newton, capped where the linear beam stops being right. A strip turned
## by theta pushes square to itself: cos(theta) of its share sideways and sin(theta) of it up.
## On either tack the fin bends toward its lift, so the up part always points to the deck.
func _bend(lift: float) -> void:
	side_share = 1.0
	up_share = 0.0
	bend_tip_rad = 0.0
	bend_tip_m = 0.0
	if not config.bends or lift <= 0.0:
		return
	var cap: float = deg_to_rad(config.max_bend_deg)
	var side: float = 0.0
	for i: int in BEND_STRIPS:
		var theta: float = minf(lift * strip_slope_per_n[i], cap)
		side += strip_share[i] * cos(theta)
		up_share += strip_share[i] * sin(theta)
	side_share = side
	bend_tip_rad = minf(lift * tip_slope_per_n, cap)
	bend_tip_m = lift * tip_deflection_per_n


## Works out the beam once for this fin: the stiffness scale from the flex test, then each
## strip's slope and the tip's movement under one newton of lift spread elliptically.
func _prepare_bend() -> void:
	strip_share = elliptic_shares(BEND_STRIPS)
	strip_slope_per_n.resize(BEND_STRIPS)
	strip_slope_per_n.fill(0.0)
	if not config.bends:
		return
	stiffness_scale = calibrated_stiffness_scale()
	var step: float = config.span_m / BEND_STRIPS
	var stiffness: PackedFloat64Array = edge_stiffness(config.span_m, config.root_chord_m(), stiffness_scale)
	var slopes: PackedFloat64Array = beam_slopes(elliptic_moments_per_n(config.span_m), stiffness, step)
	var deflections: PackedFloat64Array = beam_deflections(slopes, step)
	for i: int in BEND_STRIPS:
		strip_slope_per_n[i] = 0.5 * (slopes[i] + slopes[i + 1])  # at the strip's middle
	tip_slope_per_n = slopes[BEND_STRIPS]
	tip_deflection_per_n = deflections[BEND_STRIPS]


## The stiffness scale S that makes the beam repeat the flex test. The test fin's beam is
## worked out with S = 1; the deflection goes as 1 / S, so S is that deflection at the load
## point over the measured one. A fin of another size keeps this S: the same material.
func calibrated_stiffness_scale() -> float:
	var span: float = config.flex_test_span_m
	var step: float = span / BEND_STRIPS
	var root_chord: float = config.root_chord_for_m(span, config.flex_test_area_m2)
	var moments: PackedFloat64Array = point_load_moments(span, config.flex_test_load_n, config.flex_test_position)
	var slopes: PackedFloat64Array = beam_slopes(moments, edge_stiffness(span, root_chord, 1.0), step)
	var deflection_with_s1: float = value_at(beam_deflections(slopes, step), config.flex_test_position)
	return deflection_with_s1 / config.flex_test_deflection_m


## How far this fin's load point moves under `load_n` hung at span fraction `position` (m):
## a flex test done on this fin, with its own stiffness.
func point_load_deflection_m(load_n: float, position: float) -> float:
	var step: float = config.span_m / BEND_STRIPS
	var stiffness: PackedFloat64Array = edge_stiffness(config.span_m, config.root_chord_m(), stiffness_scale)
	var slopes: PackedFloat64Array = beam_slopes(point_load_moments(config.span_m, load_n, position), stiffness, step)
	return value_at(beam_deflections(slopes, step), position)


## The bending stiffness EI = S * c^4 at each strip edge (N m^2). A thin section's second
## moment of area goes as its chord times its thickness cubed, and the thickness is a fixed
## share of the chord: so c^4, with that share, the section's constant and the material in S.
func edge_stiffness(span: float, root_chord: float, scale: float) -> PackedFloat64Array:
	var stiffness: PackedFloat64Array = PackedFloat64Array()
	for j: int in BEND_STRIPS + 1:
		var chord: float = root_chord * config.chord_shape(float(j) / BEND_STRIPS)
		stiffness.append(scale * pow(chord, 4.0))
	return stiffness


## Each strip's share of a lift spread elliptically from the root: l(y) goes as
## sqrt(1 - (y/L)^2), with the hull as the end plate (the root is the middle of the mirrored
## wing). The shares are the exact areas under that curve, so they add up to 1.
static func elliptic_shares(strips: int) -> PackedFloat64Array:
	var shares: PackedFloat64Array = PackedFloat64Array()
	for i: int in strips:
		shares.append(_ellipse_area(float(i + 1) / strips) - _ellipse_area(float(i) / strips))
	return shares


## The bending moment at each strip edge for one newton of lift spread elliptically (N m per
## N): each strip beyond the edge, its share times its distance from the edge. A strip's lift
## acts at its own centroid (worked out exactly), so the root's moment is 4 L / (3 pi).
static func elliptic_moments_per_n(span: float) -> PackedFloat64Array:
	var moments: PackedFloat64Array = PackedFloat64Array()
	for j: int in BEND_STRIPS + 1:
		var y: float = span * j / BEND_STRIPS
		var moment: float = 0.0
		for i: int in range(j, BEND_STRIPS):
			var share: float = _ellipse_area(float(i + 1) / BEND_STRIPS) - _ellipse_area(float(i) / BEND_STRIPS)
			var first_moment: float = span * (_ellipse_moment(float(i + 1) / BEND_STRIPS) - _ellipse_moment(float(i) / BEND_STRIPS))
			moment += first_moment - share * y  # the share times (its centroid - y)
		moments.append(moment)
	return moments


## The bending moment at each strip edge for a point load at span fraction `position` (N m):
## the load times its distance beyond the edge, and nothing beyond the load.
static func point_load_moments(span: float, load_n: float, position: float) -> PackedFloat64Array:
	var moments: PackedFloat64Array = PackedFloat64Array()
	for j: int in BEND_STRIPS + 1:
		var y: float = span * j / BEND_STRIPS
		moments.append(load_n * maxf(position * span - y, 0.0))
	return moments


## The slope at each strip edge (rad): the curvature M / EI added up from the clamped root,
## where the slope is zero (the trapezoid rule). Where the chord, and so EI, is zero (the very
## tip) there is no moment either, and no curvature.
static func beam_slopes(moments: PackedFloat64Array, stiffness: PackedFloat64Array, step: float) -> PackedFloat64Array:
	var slopes: PackedFloat64Array = PackedFloat64Array([0.0])
	for j: int in BEND_STRIPS:
		var curvature_here: float = moments[j] / stiffness[j] if stiffness[j] > 0.0 else 0.0
		var curvature_next: float = moments[j + 1] / stiffness[j + 1] if stiffness[j + 1] > 0.0 else 0.0
		slopes.append(slopes[j] + step * 0.5 * (curvature_here + curvature_next))
	return slopes


## The sideways movement at each strip edge (m): the slope added up from the root, which does
## not move (the trapezoid rule).
static func beam_deflections(slopes: PackedFloat64Array, step: float) -> PackedFloat64Array:
	var deflections: PackedFloat64Array = PackedFloat64Array([0.0])
	for j: int in BEND_STRIPS:
		deflections.append(deflections[j] + step * 0.5 * (slopes[j] + slopes[j + 1]))
	return deflections


## A value at span fraction `position`, read between the two strip edges around it.
static func value_at(values: PackedFloat64Array, position: float) -> float:
	var at: float = clampf(position, 0.0, 1.0) * BEND_STRIPS
	var j: int = mini(floori(at), BEND_STRIPS - 1)
	return lerpf(values[j], values[j + 1], at - j)


## The share of an elliptic load between the root and span fraction x: (4 / pi) times the
## area under sqrt(1 - x^2) from 0 to x, which is 1 at the tip.
static func _ellipse_area(x: float) -> float:
	return 2.0 / PI * (x * sqrt(maxf(0.0, 1.0 - x * x)) + asin(minf(x, 1.0)))


## The first moment of that share about the root, in span lengths: (4 / pi) times the
## integral of x * sqrt(1 - x^2) from 0 to x.
static func _ellipse_moment(x: float) -> float:
	return 4.0 / (3.0 * PI) * (1.0 - pow(maxf(0.0, 1.0 - x * x), 1.5))
