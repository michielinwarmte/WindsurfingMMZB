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

## A point counts as fully wetted (for the wetted area) once it is this deep.
const WET_RAMP_M: float = 0.02


## Extra inertia about the yaw axis from the water the immersed hull drags along when it
## turns (added mass of a thin plate of the hull's draft, integrated over the wetted length:
## rho * pi * (draft/2)^2 per metre, times L^3/12). About 9 kg m2 at rest for the default
## board, almost nothing when planing on the tail.
func yaw_added_inertia_kgm2() -> float:
	if not is_floating:
		return 0.0
	var draft: float = minf(mean_immersion_m, board.thickness_m)
	var per_metre: float = water.density_kg_m3 * PI * 0.25 * draft * draft
	return per_metre * pow(wetted_length_m, 3.0) / 12.0


func _init(board_config: BoardConfig, water_config: WaterConfig) -> void:
	board = board_config
	water = water_config
	_build_grid()


## Builds the grid: rows from the tail (z = +L/2) to the bow (z = -L/2), with the bottom
## curving up toward both ends (rocker), the rows narrowing toward the ends (width taper)
## and the rows carrying less volume toward the ends (volume taper). Section 6.1.
func _build_grid() -> void:
	var n_len: int = maxi(board.length_samples, 2)
	var n_wid: int = maxi(board.width_samples, 1)
	var half_length: float = 0.5 * board.length_m
	var half_width: float = 0.5 * board.width_m
	var weights: PackedFloat64Array = PackedFloat64Array()
	var area_weights: PackedFloat64Array = PackedFloat64Array()
	var total_weight: float = 0.0
	var total_area_weight: float = 0.0
	sample_points.clear()
	sample_rows.clear()

	for i: int in n_len:
		var t: float = float(i) / float(n_len - 1)  # 0 at the tail, 1 at the bow
		var z: float = half_length - board.length_m * t
		var d: float = absf(t - 0.5) * 2.0  # 0 in the middle, 1 at either end
		var rocker: float = board.bottom_rise_m(board.length_m * t)
		var width_factor: float = 1.0 - board.width_taper * d * d
		var volume_factor: float = 1.0 - board.volume_taper * d
		var row_half_width: float = half_width * width_factor
		for j: int in n_wid:
			var x: float = 0.0
			if n_wid > 1:
				x = lerpf(-row_half_width, row_half_width, float(j) / float(n_wid - 1))
			sample_points.append(Vector3(x, -0.5 * board.thickness_m + rocker, z))
			sample_rows.append(i)
			weights.append(volume_factor * width_factor)
			area_weights.append(width_factor)
			total_weight += volume_factor * width_factor
			total_area_weight += width_factor
			if j == n_wid / 2:
				if i == 0:
					tail_centre_index = sample_points.size() - 1
				if i == n_len - 1:
					bow_centre_index = sample_points.size() - 1

	sample_volumes_m3.resize(sample_points.size())
	sample_areas_m2.resize(sample_points.size())
	point_depths_m.resize(sample_points.size())
	var planform: float = board.planform_area_m2()
	for k: int in sample_points.size():
		sample_volumes_m3[k] = board.volume_m3 * weights[k] / total_weight
		sample_areas_m2[k] = planform * area_weights[k] / total_area_weight


## Computes the buoyancy and damping forces for the body's current state and applies them.
func apply(body: SimRigidBody, surface: WaterSurface, time_s: float, gravity_ms2: float) -> void:
	var force_sum: Vector3 = Vector3.ZERO
	var damping_sum: Vector3 = Vector3.ZERO
	var weighted_position: Vector3 = Vector3.ZERO
	var wet_area_position: Vector3 = Vector3.ZERO
	submerged_volume_m3 = 0.0
	wetted_area_m2 = 0.0
	var wet_count: int = 0
	var depth_sum: float = 0.0
	var wet_rows: Dictionary[int, bool] = {}

	for k: int in sample_points.size():
		var point_world: Vector3 = body.point_world(sample_points[k])
		var normal: Vector3 = surface.normal_at(point_world.x, point_world.z, time_s)
		var depth: float = surface.height_at(point_world.x, point_world.z, time_s) - point_world.y
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
		# the share of the hull it has under water (section 6.9).
		var wet_share: float = volume / board.volume_m3
		var relative_velocity: Vector3 = body.point_velocity(point_world) - surface.velocity_at(point_world.x, point_world.z, time_s)
		var normal_speed: float = relative_velocity.dot(normal)
		var damping: float = -(water.damping_linear_ns_m * normal_speed
			+ water.damping_quadratic_ns2_m2 * normal_speed * absf(normal_speed)) * wet_share
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
