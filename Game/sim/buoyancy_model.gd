class_name BuoyancyModel
extends RefCounted
## Archimedes' buoyancy and the water's heave damping, sampled at a grid of points on the
## hull bottom (PHYSICS_SPEC.md section 6). Each point stands for a column of hull volume
## and a patch of bottom area. As a point goes under, its column fills up over one hull
## thickness and pushes up with the weight of the water it displaces. Because the points
## are spread over the bottom, a dipping bow or a dropping rail is pushed up harder than
## the rest, which levels and rights the board without any extra rule.
##
## Damping is applied per point from that point's own velocity through the surface, so
## one pair of coefficients damps heave, pitch and roll consistently.
##
## Besides the forces, the model reports what the hull model needs: how much of the hull
## is under water, the wetted bottom area, the wetted length and the immersion at the
## transom (section 15 decisions for Phase 2).

var board: BoardConfig
var water: WaterConfig

## Sample points in body axes relative to the board origin (x starboard, y up, z aft).
var sample_points: PackedVector3Array = PackedVector3Array()
## Volume of hull each point stands for.
var sample_volumes_m3: PackedFloat64Array = PackedFloat64Array()
## Bottom area each point stands for.
var sample_areas_m2: PackedFloat64Array = PackedFloat64Array()
## Row index (0 = tail row) of each point.
var sample_rows: PackedInt32Array = PackedInt32Array()
var tail_centre_index: int = 0
var bow_centre_index: int = 0
## Area of the bottom seen from below, from the outline (computed once with the grid).
var planform_area_m2: float = 0.0

## Results of the last apply().
var point_depths_m: PackedFloat64Array = PackedFloat64Array()
var submerged_volume_m3: float = 0.0
var submersion_ratio: float = 0.0
var is_floating: bool = false
var buoyancy_force_n: float = 0.0
var damping_force_n: float = 0.0
var wetted_area_m2: float = 0.0
var wetted_length_m: float = 0.0
var mean_immersion_m: float = 0.0
var transom_immersion_m: float = 0.0
var bow_immersion_m: float = 0.0
var centre_of_buoyancy_world: Vector3 = Vector3.ZERO
var wet_centroid_world: Vector3 = Vector3.ZERO

## The water at each sample point as the last apply() found it (WaterSurface.Sample: the
## height, the normal and the water's velocity, from one solve per point). The hull model
## reuses the centre column's samples: the same points in the same substep. And each sample
## is where its point's solve starts the next substep, since the board moves only a few
## centimetres per substep (WaveField.sample_at).
var sea_samples: Array[WaterSurface.Sample] = []
## The water surface those samples are of.
var sea_surface: WaterSurface = null

## A point counts as fully wetted (for the wetted area) once it is this deep.
const WET_RAMP_M: float = 0.02


func _init(board_config: BoardConfig, water_config: WaterConfig) -> void:
	board = board_config
	water = water_config
	_build_grid()


## Builds the grid: rows from the tail (z = +L/2) to the bow (z = -L/2), with the bottom
## curving up toward both ends (rocker) and the rows as wide as the board's outline there
## (BoardConfig.width_at). Each row carries a share of the volume in proportion to its
## cross-section, the outline's width times the board's thickness there (thickest at the
## widest point, thin at the nose and tail); the shares add up to the board's volume.
## Section 6.1.
func _build_grid() -> void:
	var n_len: int = maxi(board.length_samples, 2)
	var n_wid: int = maxi(board.width_samples, 1)
	var half_length: float = 0.5 * board.length_m
	var weights: PackedFloat64Array = PackedFloat64Array()
	var area_weights: PackedFloat64Array = PackedFloat64Array()
	var total_weight: float = 0.0
	var total_area_weight: float = 0.0
	sample_points.clear()
	sample_rows.clear()

	for i: int in n_len:
		var t: float = float(i) / float(n_len - 1)  # 0 at the tail, 1 at the bow
		var from_transom: float = board.length_m * t
		var z: float = half_length - from_transom
		var rocker: float = board.bottom_rise_m(from_transom)
		var row_width: float = board.width_at(from_transom)
		var row_section: float = row_width * board.thickness_at(from_transom)
		var row_half_width: float = 0.5 * row_width
		for j: int in n_wid:
			var x: float = 0.0
			if n_wid > 1:
				x = lerpf(-row_half_width, row_half_width, float(j) / float(n_wid - 1))
			sample_points.append(Vector3(x, -0.5 * board.thickness_m + rocker, z))
			sample_rows.append(i)
			weights.append(row_section)
			area_weights.append(row_width)
			total_weight += row_section
			total_area_weight += row_width
			if j == n_wid / 2:
				if i == 0:
					tail_centre_index = sample_points.size() - 1
				if i == n_len - 1:
					bow_centre_index = sample_points.size() - 1

	sample_volumes_m3.resize(sample_points.size())
	sample_areas_m2.resize(sample_points.size())
	point_depths_m.resize(sample_points.size())
	planform_area_m2 = board.planform_area_m2()
	sea_samples.clear()
	for k: int in sample_points.size():
		sample_volumes_m3[k] = board.volume_m3 * weights[k] / total_weight
		sample_areas_m2[k] = planform_area_m2 * area_weights[k] / total_area_weight
		sea_samples.append(WaterSurface.Sample.new())


## Forgets the water's last answers, so that the next apply() solves every point from
## scratch: for a board put somewhere new (WindsurferSim.reset), whose answers are then a new
## board's to the last bit.
func forget_the_sea() -> void:
	for sea: WaterSurface.Sample in sea_samples:
		sea.forget()


## The water at sample point k as the last apply() found it, if that is the answer at
## world_point on this surface at this time: the hull model asks the same points in the same
## substep, after apply(). Null if it is not (another surface or time, or the body has moved).
func sea_sample_for(k: int, surface: WaterSurface, world_point: Vector3, time_s: float) -> WaterSurface.Sample:
	var sea: WaterSurface.Sample = sea_samples[k]
	if surface == sea_surface and sea.answers(world_point.x, world_point.z, time_s):
		return sea
	return null


## Computes the buoyancy and damping forces for the body's current state and applies them.
func apply(body: SimRigidBody, surface: WaterSurface, time_s: float, gravity_ms2: float, dt: float = 1.0 / 240.0) -> void:
	var force_sum: Vector3 = Vector3.ZERO
	var damping_sum: Vector3 = Vector3.ZERO
	var weighted_position: Vector3 = Vector3.ZERO
	var wet_area_position: Vector3 = Vector3.ZERO
	submerged_volume_m3 = 0.0
	wetted_area_m2 = 0.0
	var wet_count: int = 0
	var depth_sum: float = 0.0
	var wet_rows: Dictionary[int, bool] = {}
	sea_surface = surface

	for k: int in sample_points.size():
		var point_world: Vector3 = body.point_world(sample_points[k])
		# The height, the normal and the water's velocity here, from one solve.
		var sea: WaterSurface.Sample = sea_samples[k]
		surface.sample_at(point_world.x, point_world.z, time_s, sea)
		var normal: Vector3 = sea.normal
		var depth: float = sea.height_m - point_world.y
		point_depths_m[k] = depth
		if depth <= 0.0:
			continue
		wet_count += 1
		depth_sum += depth
		wet_rows[sample_rows[k]] = true

		# Archimedes for this column: the column fills over one hull thickness.
		var fraction: float = clampf(depth / board.thickness_m, 0.0, 1.0)
		var volume: float = sample_volumes_m3[k] * fraction
		var magnitude: float = water.density_kg_m3 * gravity_ms2 * volume
		var force: Vector3 = normal * magnitude
		body.add_force_at(point_world, force)
		submerged_volume_m3 += volume
		force_sum += force
		weighted_position += point_world * magnitude

		# Heave damping from this point's own motion through the surface, in proportion to
		# the share of the bottom's area that this point has in the water (section 6.9). The
		# damping stands in for the waves a heaving hull radiates, which depend on how much
		# surface it works against, not on how deep it sits; a light hull floating high is
		# damped like a loaded one as long as its bottom is wet.
		var wet_share: float = sample_areas_m2[k] * clampf(depth / WET_RAMP_M, 0.0, 1.0) / planform_area_m2
		var relative_velocity: Vector3 = body.point_velocity(point_world) - sea.velocity_ms
		var normal_speed: float = relative_velocity.dot(normal)
		var damping: float = -(water.damping_linear_ns_m * normal_speed
			+ water.damping_quadratic_ns2_m2 * normal_speed * absf(normal_speed)) * wet_share
		# A damper can only take away the momentum there is: in one step this point's share
		# of the force may not exceed what stops its motion (the exact answer for a damper
		# integrated implicitly). Without this a light hull slamming down at a few metres per
		# second can be thrown back out by the quadratic term (A-16). The momentum a point has
		# is its effective mass (translation and rotation about the centre of mass) times its
		# speed: a rail of a light board rolling fast carries little, and a damper that took
		# more would spin the board the other way instead of stopping it.
		var stopping_force: float = body.effective_mass_at(point_world, normal) * absf(normal_speed) / dt * wet_share
		damping = clampf(damping, -stopping_force, stopping_force)
		body.add_force_at(point_world, normal * damping)
		damping_sum += normal * damping

		var wet_fraction: float = clampf(depth / WET_RAMP_M, 0.0, 1.0)
		wetted_area_m2 += sample_areas_m2[k] * wet_fraction
		wet_area_position += point_world * sample_areas_m2[k] * wet_fraction

	buoyancy_force_n = force_sum.length()
	damping_force_n = damping_sum.length()
	is_floating = wet_count > 0
	submersion_ratio = submerged_volume_m3 / board.volume_m3
	if buoyancy_force_n > 1e-6:
		centre_of_buoyancy_world = weighted_position / buoyancy_force_n
	else:
		centre_of_buoyancy_world = body.origin_world()
	if wetted_area_m2 > 1e-9:
		wet_centroid_world = wet_area_position / wetted_area_m2
	else:
		wet_centroid_world = body.origin_world()
	mean_immersion_m = depth_sum / wet_count if wet_count > 0 else 0.0
	wetted_length_m = board.length_m * float(wet_rows.size()) / float(maxi(board.length_samples, 1))
	transom_immersion_m = maxf(point_depths_m[tail_centre_index], 0.0)
	bow_immersion_m = maxf(point_depths_m[bow_centre_index], 0.0)
