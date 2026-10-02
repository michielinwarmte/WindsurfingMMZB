class_name HullModel
extends RefCounted
## What the water does to the moving hull (PHYSICS_SPEC.md section 5, as decided in section 15):
## friction on the wetted bottom, wave-making drag while the hull displaces water, sideways
## drag of the immersed hull, and the dynamic (planing) lift of the bottom near the tail.
##
## The planing lift is computed strip by strip with the slender-body theory of planing,
## scaled to Savitsky's measured lift (see _apply_planing_lift). Buoyancy (BuoyancyModel)
## carries the rest, so the two are never counted twice. The wet part of the bottom comes
## from the geometry (the depths of the buoyancy grid); the strips' motion into the water
## gives the heave and pitch damping of a planing surface; the lift grows when the spray
## root runs forward along a sinking hull (the slamming part of planing); and the forces act
## normal to the bottom, so the pressure drag follows from the angles.

const MIN_SPRAY_ROOT_ANGLE_RAD: float = 0.01745  # one degree
const STRIPS: int = 12  # strips along the wet bottom
const TRANSOM_RELIEF_BEAMS: float = 0.5  # the pressure falls to nothing over this many beams before the aft end

var board: BoardConfig
var water: WaterConfig

# Results of the last compute().
var friction_n: float = 0.0
var residuary_n: float = 0.0
var lateral_n: float = 0.0
var resistance_n: float = 0.0  # friction + residuary + pressure drag, along the flow
var planing_lift_n: float = 0.0  # vertical component of the planing force
var planing_normal_force_n: float = 0.0
var planing_ratio: float = 0.0
var trim_deg: float = 0.0  # angle of the planing surface to the flow, degrees
var wetted_length_m: float = 0.0  # of the planing surface (the wet part of the centreline)
var wetted_aft_m: float = 0.0  # where the wet part starts, forward of the transom (0 = wet transom)
var planing_beam_m: float = 0.0  # mean width of the wet part of the bottom
## Water that moves with the hull: the heave added mass of the wet bottom (a flat plate on
## the surface carries rho pi b^2 / 8 per metre of length) and its inertia about the centre
## of mass in pitch. Strip theory (Wagner, Zarnick), the same physics as the slamming term.
var heave_added_mass_kg: float = 0.0
var pitch_added_inertia_kgm2: float = 0.0
var spray_root_factor: float = 1.0  # unsteady lift factor from the spray root running along the hull
var lambda_ratio: float = 0.0
var froude_number: float = 0.0
var reynolds_number: float = 0.0
var cop_local: Vector3 = Vector3.ZERO
var forward_speed_ms: float = 0.0
var planing_drag_n: float = 0.0  # the part of the planing force that points against the motion


func _init(board_config: BoardConfig, water_config: WaterConfig) -> void:
	board = board_config
	water = water_config


func compute(body: SimRigidBody, buoyancy: BuoyancyModel, surface: WaterSurface, time_s: float, gravity_ms2: float, total_mass_kg: float, dt: float = 1.0 / 240.0) -> void:
	_clear()
	if not buoyancy.is_floating or buoyancy.wetted_area_m2 <= 0.0:
		return

	# The wet part of the bottom along the centreline. Usually it runs from the transom
	# forward; when the tail has lifted clear and the nose is down, it is the middle of the
	# hull and the nose rocker that are wet. Everything below works on this span.
	var span: PackedFloat64Array = _wetted_span(buoyancy)
	wetted_aft_m = span[0]
	wetted_length_m = span[1] - span[0]
	planing_beam_m = _mean_width(span[0], span[1])
	_compute_added_mass(span[0], span[1], body)

	# The flow relative to the wet part of the hull.
	var wet_point: Vector3 = buoyancy.wet_centroid_world
	var v_rel: Vector3 = body.point_velocity(wet_point) - surface.velocity_at(wet_point.x, wet_point.z, time_s)
	var v_body: Vector3 = SimMath.to_body(body.basis, v_rel)
	forward_speed_ms = -v_body.z
	var v_h: Vector3 = SimMath.horizontal(v_rel)
	var speed_h: float = v_h.length()
	var rho: float = water.density_kg_m3

	if speed_h > 0.01:
		var flow_dir: Vector3 = v_h / speed_h
		var reference_length: float = maxf(buoyancy.wetted_length_m, 0.3)

		# 1. Skin friction on the wetted bottom (ITTC 1957 line).
		reynolds_number = maxf(speed_h * reference_length / water.kinematic_viscosity_m2_s, 1e5)
		var cf: float = 0.075 / pow(log(reynolds_number) / log(10.0) - 2.0, 2.0)
		var q_h: float = 0.5 * rho * speed_h * speed_h
		friction_n = cf * q_h * buoyancy.wetted_area_m2
		body.add_force_at(wet_point, -flow_dir * friction_n)

		# 2. Wave-making drag while the hull pushes water aside: a hump around a Froude
		# number of about 0.55, scaled by the weight that buoyancy still carries. As the
		# planing lift takes the weight over, this term fades out by itself.
		froude_number = speed_h / sqrt(gravity_ms2 * reference_length)
		var hump: float = (froude_number - board.residuary_peak_froude) / board.residuary_froude_width
		var residuary_coefficient: float = board.residuary_peak_fraction * exp(-hump * hump)
		residuary_n = residuary_coefficient * buoyancy.buoyancy_force_n
		body.add_force_at(buoyancy.centre_of_buoyancy_world, -flow_dir * residuary_n)

	# 3. Sideways drag of the immersed hull, row by row along the length, so that a turning
	# board is also damped in yaw by the water (section 5 F10).
	_apply_lateral_drag(body, buoyancy, surface, time_s, rho)

	# 4. Dynamic lift of the planing surface.
	_apply_planing_lift(body, span[0], span[1], surface, time_s, gravity_ms2, total_mass_kg, rho, dt)

	resistance_n = friction_n + residuary_n + planing_drag_n


func _apply_lateral_drag(body: SimRigidBody, buoyancy: BuoyancyModel, surface: WaterSurface, time_s: float, rho: float) -> void:
	var rows: int = maxi(board.length_samples, 1)
	var row_length: float = board.length_m / rows
	var centre_column: int = maxi(board.width_samples, 1) / 2
	var columns: int = maxi(board.width_samples, 1)
	lateral_n = 0.0
	for k: int in buoyancy.sample_points.size():
		if k % columns != centre_column:
			continue
		var depth: float = buoyancy.point_depths_m[k]
		if depth <= 0.0:
			continue
		var point_world: Vector3 = body.point_world(buoyancy.sample_points[k])
		var v_rel: Vector3 = body.point_velocity(point_world) - surface.velocity_at(point_world.x, point_world.z, time_s)
		var v_lat: float = v_rel.dot(body.basis.x)
		var side_area: float = row_length * minf(depth, board.thickness_m)
		var force: float = -0.5 * rho * board.lateral_drag_cd * side_area * v_lat * absf(v_lat)
		body.add_force_at(point_world, body.basis.x * force)
		lateral_n += absf(force)


## The dynamic lift of the wet bottom, strip by strip (slender-body or "2D+t" theory of
## planing: Wagner, Zarnick 1978). Each metre of bottom of width b carries an added mass of
## water of rho pi b^2 / 8. The water flows aft under the hull at the forward speed u, and
## the force on each strip is the rate at which the water under it gains downward
## momentum: u m' V at the spray root where still water first meets the bottom, and
## -u m' dV/dx along the hull where the bottom's normal velocity V changes from strip to
## strip. That second part is what a point model misses: a bow-up pitch rate pushes the
## stern down, V grows toward the stern, the water under the hull gains momentum and pushes
## back up, and the board is damped in pitch and heave as a real planing hull is.
## The theory is two-dimensional; its total for a flat plate (m' u^2 trim) is scaled to
## Savitsky's measured lift at the same trim and wetted length-to-beam ratio, and the spray
## root's force is spread over the bottom behind it so that the centre of pressure sits
## where Savitsky measured it. The water leaves the bottom at the aft end of the wet part as
## it would at a transom, so the same applies when the tail has lifted clear and the middle
## of the hull and the nose rocker are what planes.
func _apply_planing_lift(body: SimRigidBody, aft: float, forward: float, surface: WaterSurface, time_s: float, gravity_ms2: float, total_mass_kg: float, rho: float, _dt: float) -> void:
	var u: float = forward_speed_ms
	var length: float = wetted_length_m
	if u < 0.5 or length < 0.1:
		return
	var strip_length: float = length / float(STRIPS)
	var pitch: float = SimMath.pitch_rad(body.basis)
	var heel: float = SimMath.heel_rad(body.basis)
	var beam: float = planing_beam_m * maxf(cos(heel), 0.3)
	lambda_ratio = clampf(length / beam, 0.2, board.length_m / beam)

	# The wet bottom seen as one cambered plate, for the reference trim: its chord is
	# inclined to the board by the rocker and the bottom bulges below the chord, which acts
	# like camber on a wing (two sag-over-length of extra angle, thin-airfoil theory).
	var chord_angle: float = _chord_angle(aft, forward)
	var camber_angle: float = 2.0 * _camber_sag(aft, forward) / length
	var trim_geometric: float = pitch + chord_angle + camber_angle

	# 1. The strips: where each is, which way its bottom faces, how fast it moves into the
	#    water (V, positive into the water) and how much water a metre of it carries.
	var x_k: PackedFloat64Array = PackedFloat64Array()
	var points_world: PackedVector3Array = PackedVector3Array()
	var normals_world: PackedVector3Array = PackedVector3Array()
	var v_into: PackedFloat64Array = PackedFloat64Array()
	var m_per_m: PackedFloat64Array = PackedFloat64Array()
	var v_mean: float = 0.0
	for k: int in STRIPS:
		var x: float = aft + (float(k) + 0.5) * strip_length
		var slope: float = board.bottom_slope(x)
		var normal_local: Vector3 = Vector3(0.0, 1.0, slope).normalized()
		var point_world: Vector3 = body.point_world(Vector3(0.0, _bottom_y(x), 0.5 * board.length_m - x))
		var normal_world: Vector3 = SimMath.to_world(body.basis, normal_local)
		var v_rel: Vector3 = body.point_velocity(point_world) - surface.velocity_at(point_world.x, point_world.z, time_s)
		var width: float = _width_at(x)
		x_k.append(x)
		points_world.append(point_world)
		normals_world.append(normal_world)
		v_into.append(-v_rel.dot(normal_world))
		m_per_m.append(rho * PI * width * width / 8.0)
		v_mean += v_into[k] / float(STRIPS)
	trim_deg = rad_to_deg(atan2(v_mean, u))

	# 2. Along the hull: where V grows toward the stern the water gains downward momentum
	#    as it flows aft and pushes up; where V shrinks it pushes less. Where the hull widens
	#    going aft (the nose) the water column gains added mass, more push; where it narrows
	#    the water lets go instead of pulling. Over the last half beam before the aft end
	#    the pressure falls away to the air behind it (the transom relief).
	var strip_forces: PackedFloat64Array = PackedFloat64Array()
	for k: int in STRIPS:
		var k0: int = maxi(k - 1, 0)
		var k1: int = mini(k + 1, STRIPS - 1)
		var dx: float = float(k1 - k0) * strip_length
		var dv_dx: float = (v_into[k1] - v_into[k0]) / dx
		var dm_dx: float = (m_per_m[k1] - m_per_m[k0]) / dx
		var force: float = -u * m_per_m[k] * dv_dx * strip_length
		if dm_dx < 0.0:
			force -= u * v_into[k] * dm_dx * strip_length
		var relief: float = clampf((x_k[k] - aft) / (TRANSOM_RELIEF_BEAMS * beam), 0.0, 1.0)
		strip_forces.append(force * relief)

	# 3. The spray root: still water is set in motion at the rate the root sweeps along it.
	#    When the hull also sinks, the root runs forward along the hull (sinking speed over
	#    the tangent of the bottom's angle to the surface) and more water is engaged per
	#    second; when the hull rises the root retreats and the push fades, and a bottom
	#    leaving the water faster than the water can follow carries nothing. Below one
	#    degree the root would run faster than the theory allows for, so the factor is held
	#    at twice the steady value (PHYSICS_SPEC.md section 16).
	var last: int = STRIPS - 1
	var v_root: float = v_into[last] + 0.5 * (v_into[last] - v_into[last - 1])
	var root_world: Vector3 = body.point_world(Vector3(0.0, _bottom_y(forward), 0.5 * board.length_m - forward))
	var root_normal: Vector3 = surface.normal_at(root_world.x, root_world.z, time_s)
	var root_down_speed: float = -(body.point_velocity(root_world) - surface.velocity_at(root_world.x, root_world.z, time_s)).dot(root_normal)
	var bottom_angle: float = pitch + board.bottom_slope(forward)
	var advance_ms: float = root_down_speed / tan(maxf(bottom_angle, MIN_SPRAY_ROOT_ANGLE_RAD))
	spray_root_factor = clampf(1.0 + advance_ms / u, 0.0, 2.0)
	var root_force: float = maxf(u * spray_root_factor * m_per_m[last] * v_root, 0.0)

	# 4. Three-dimensional correction: the strip theory is two-dimensional and gives a flat
	#    plate m' u^2 trim; Savitsky (1964) measured the lift of real planing plates, with
	#    the deadrise correction. Their ratio at the geometric trim (or at one degree, below
	#    that) scales everything. This is how slender-body planing models are anchored.
	var tau_ref_deg: float = maxf(rad_to_deg(trim_geometric), 1.0)
	var cl_flat: float = 0.012 * pow(minf(tau_ref_deg, 15.0), 1.1) * sqrt(lambda_ratio)
	var cl_dynamic: float = maxf(cl_flat - 0.0065 * board.deadrise_deg * pow(cl_flat, 0.6), 0.0)
	var savitsky_lift: float = cl_dynamic * 0.5 * rho * u * u * beam * beam
	var slender_lift: float = m_per_m[last] * u * u * sin(deg_to_rad(tau_ref_deg))
	var three_d_factor: float = savitsky_lift / maxf(slender_lift, 1e-6)

	# 5. Where the root's force acts: the pressure peaks just behind the spray root and
	#    decays aft. A triangle from the root backwards whose centroid is Savitsky's centre
	#    of pressure (0.75 of the wet length from the aft end at speed) spreads it.
	var cv: float = u / sqrt(gravity_ms2 * beam)
	var cop_fraction: float = 0.75 - 1.0 / (5.21 * cv * cv / (lambda_ratio * lambda_ratio) + 2.39)
	var spread: float = maxf(3.0 * (1.0 - cop_fraction) * length, strip_length)
	var weights: PackedFloat64Array = PackedFloat64Array()
	var weight_sum: float = 0.0
	for k: int in STRIPS:
		weights.append(maxf(1.0 - (forward - x_k[k]) / spread, 0.0))
		weight_sum += weights[k]

	# 6. Apply. No strip may pull: where the theory would have the water sucking on a
	#    bottom that lifts away, the water has let go instead.
	var flow_dir: Vector3 = SimMath.horizontal(body.velocity)
	flow_dir = flow_dir.normalized() if flow_dir.length() > 0.01 else Vector3.ZERO
	var weighted_position: Vector3 = Vector3.ZERO
	for k: int in STRIPS:
		var share: float = root_force * weights[k] / weight_sum if weight_sum > 0.0 else 0.0
		var magnitude: float = three_d_factor * (strip_forces[k] + share)
		if magnitude <= 0.0:
			continue
		var force: Vector3 = normals_world[k] * magnitude
		body.add_force_at(points_world[k], force)
		planing_lift_n += force.y
		planing_normal_force_n += magnitude
		planing_drag_n -= force.dot(flow_dir)
		weighted_position += points_world[k] * magnitude
	if planing_normal_force_n > 0.0:
		cop_local = SimMath.to_body(body.basis, weighted_position / planing_normal_force_n - body.origin_world())
	planing_ratio = clampf(planing_lift_n / (total_mass_kg * gravity_ms2), 0.0, 1.0)


## The wet part of the bottom along the centreline as [aft, forward] in metres from the
## transom, from the depths of the row centre points, with both ends interpolated between
## the last wet row and the first dry one. [0, 0] when the centreline is dry.
func _wetted_span(buoyancy: BuoyancyModel) -> PackedFloat64Array:
	var rows: int = maxi(board.length_samples, 2)
	var columns: int = maxi(board.width_samples, 1)
	var centre: int = columns / 2
	var spacing: float = board.length_m / float(rows - 1)
	var aft: float = -1.0
	var forward: float = 0.0
	var previous_depth: float = -1.0
	for i: int in rows:
		var depth: float = buoyancy.point_depths_m[i * columns + centre]
		var x: float = spacing * float(i)
		if depth > 0.0:
			if aft < 0.0:
				aft = 0.0 if i == 0 else x - spacing * depth / (depth - previous_depth)
			forward = x
		elif aft >= 0.0:
			forward = (x - spacing) + spacing * previous_depth / (previous_depth - depth)
			break
		previous_depth = depth
	if aft < 0.0:
		return PackedFloat64Array([0.0, 0.0])
	return PackedFloat64Array([aft, forward])


## Width of the bottom at a distance forward of the transom: the same taper as the
## buoyancy grid (full width in the middle, (1 - width_taper) of it at the ends).
func _width_at(from_transom: float) -> float:
	var d: float = absf(from_transom / board.length_m - 0.5) * 2.0
	return board.width_m * (1.0 - board.width_taper * d * d)


## Mean width of the bottom between two points along the length (9-point average).
func _mean_width(aft: float, forward: float) -> float:
	var total: float = 0.0
	for k: int in 9:
		total += _width_at(lerpf(aft, forward, float(k) / 8.0))
	return total / 9.0


## Heave added mass and pitch added inertia of the wet bottom, from strip theory: each metre
## of a flat bottom of width b on the surface drags rho pi b^2 / 8 of water with it when it
## moves up or down. Summed over the wet length, and with the lever arm squared about the
## centre of mass for pitch.
func _compute_added_mass(aft: float, forward: float, body: SimRigidBody) -> void:
	heave_added_mass_kg = 0.0
	pitch_added_inertia_kgm2 = 0.0
	var length: float = forward - aft
	if length <= 0.0:
		return
	var com_from_transom: float = 0.5 * board.length_m - body.com_offset_body.z
	var strips: int = 8
	var strip_length: float = length / float(strips)
	for k: int in strips:
		var x: float = aft + (float(k) + 0.5) * strip_length
		var width: float = _width_at(x)
		var strip_mass: float = water.density_kg_m3 * PI * width * width / 8.0 * strip_length
		heave_added_mass_kg += strip_mass
		pitch_added_inertia_kgm2 += strip_mass * (x - com_from_transom) * (x - com_from_transom)


## Height of the bottom in body axes at a distance forward of the transom (the same rocker
## line the buoyancy grid uses).
func _bottom_y(from_transom: float) -> float:
	return -0.5 * board.thickness_m + board.bottom_rise_m(from_transom)


## Angle of the chord of the wet bottom to the board's reference plane, positive when the
## forward end is higher (bow up).
func _chord_angle(aft: float, forward: float) -> float:
	return atan((board.bottom_rise_m(forward) - board.bottom_rise_m(aft)) / maxf(forward - aft, 0.05))


## How far the wet bottom bulges below its chord, at most (zero if it does not).
func _camber_sag(aft: float, forward: float) -> float:
	var length: float = maxf(forward - aft, 0.05)
	var rise_aft: float = board.bottom_rise_m(aft)
	var rise_forward: float = board.bottom_rise_m(forward)
	var sag: float = 0.0
	for k: int in 9:
		var s: float = float(k) / 8.0
		var chord: float = rise_aft + (rise_forward - rise_aft) * s
		sag = maxf(sag, chord - board.bottom_rise_m(aft + length * s))
	return sag


func _clear() -> void:
	friction_n = 0.0
	residuary_n = 0.0
	lateral_n = 0.0
	resistance_n = 0.0
	planing_lift_n = 0.0
	planing_normal_force_n = 0.0
	planing_drag_n = 0.0
	planing_ratio = 0.0
	trim_deg = 0.0
	wetted_length_m = 0.0
	wetted_aft_m = 0.0
	planing_beam_m = 0.0
	heave_added_mass_kg = 0.0
	pitch_added_inertia_kgm2 = 0.0
	spray_root_factor = 1.0
	lambda_ratio = 0.0
	froude_number = 0.0
	reynolds_number = 0.0
	forward_speed_ms = 0.0
