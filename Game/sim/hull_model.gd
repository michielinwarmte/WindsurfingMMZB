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
##
## Heel: the wet part of the bottom is taken across its width as well. A board on its rail
## is wet further forward on the low side, and each strip's force acts where that strip is
## wet (the depth-weighted centre of its wet width), so the lift moves to the low rail and
## forward. That is what makes a banked board carve: the lift tilted inward by the heel is
## the centripetal force, applied forward of the centre of mass it turns the bow into the
## bank, and applied off-centre it rights the board (Savitsky 1964 on heeled planing
## surfaces; Brown and Klosinski 1994 on the side force and yaw of heeled planing hulls).
##
## Boards on threads (F1 no_wait): reading or writing a field of another object (body.basis,
## board.length_m, buoyancy.point_depths_m), or handing an object to a function's typed
## parameter, takes a global engine lock, and boards stepped side by side on worker threads
## wait for each other there; calling a method of another object (body.point_world(),
## body.add_force_at(), board.width_at()) does not. So the model keeps copies of the configs'
## numbers in its own fields, taken by copy_config(): when it is made and at the start of every
## tick (WindsurferSim.step); the configs are never changed inside a tick. And compute() reads
## what it needs from the body and the buoyancy grid once at its top, into the fields below,
## which the helpers use instead of taking the objects as parameters. Nothing of that changes
## while compute() runs (it only adds forces to the body), and the arithmetic is the same, in
## the same order: the answers are the same to the last bit.

const MIN_SPRAY_ROOT_ANGLE_RAD: float = 0.01745  # one degree
const STRIPS: int = 12  # strips along the wet bottom
const TRANSOM_RELIEF_BEAMS: float = 0.5  # the pressure falls to nothing over this many beams before the aft end
## A section entering the water is wet pi/2 times as far out from its deepest point as the
## still surface cuts it (Wagner 1932): the still surface's cut is 2/pi of the water's reach.
const WAGNER_CUT: float = 2.0 / PI
## The rail in a skid, from NACA TN 4187 (Savitsky, Prowse and Lueders 1958, flat planing
## plates with chine edges of 0.09 and 0.18 beams at trim 6 to 30 degrees, roll -15 to 15,
## yaw 0 to 20). Level, at a trim of 6 degrees (the lowest tested, the nearest to a board's
## 3 to 5), the flow wets the leading chine edge from a yaw of about 7.5 degrees (figure
## 26a)...
const RAIL_INCEPTION_DEG: float = 7.5
## ...and from about 0.35 degree less per degree that edge is rolled down (more per degree
## it is rolled up; figure 26a, between 6 degrees down and 4 up).
const RAIL_INCEPTION_PER_HEEL: float = 0.35
## The normal force on the wetted edge rises from nothing at the inception to its plateau
## over about 3 degrees of yaw (figure 27a: at 10 degrees of yaw and no roll the trim-6
## curve is near 1.0)...
const RAIL_ENGAGE_DEG: float = 3.0
## ...where it is 1.0 to 1.3 times the dynamic pressure of the flow on the edge's wetted
## area, for every trim and yaw tested (figure 27; "Ce' lies between 1.0 and 1.3").
const RAIL_FORCE_COEFFICIENT: float = 1.15
## The semi-displacement range on the hull's length (Faltinsen 2005, chapter 1): below a
## Froude number of about 0.4 the buoyancy carries the weight, above 1.0 to 1.2 the
## water's dynamic pressure does. A planing bottom's smaller buoyancy
## (BoardConfig.planing_buoyancy_factor) is phased in between the two; the shape of the
## phase-in is an estimate.
const FROUDE_DISPLACEMENT: float = 0.4
const FROUDE_PLANING: float = 1.0

var board: BoardConfig
var water: WaterConfig

## The configs' numbers (copy_config()).
var _length_m: float = 0.0
var _thickness_m: float = 0.0
var _length_samples: int = 0
var _width_samples: int = 0
var _deadrise_deg: float = 0.0
var _rail_edge_height_m: float = 0.0
var _lateral_drag_cd: float = 0.0
var _residuary_peak_fraction: float = 0.0
var _residuary_peak_froude: float = 0.0
var _residuary_froude_width: float = 0.0
var _spray_root_factor_max: float = 0.0
var _planing_lift_lag_s: float = 0.0
var _planing_buoyancy_factor: float = 1.0
var _bow_drag_cd: float = 0.0
var _strip_suction_heads: float = 0.0
var _heel_as_rolled_plate: float = 0.0
var _density_kg_m3: float = 0.0
var _kinematic_viscosity_m2_s: float = 0.0

## What compute() reads from the other objects, once at its top: the body (its methods are
## called through this, the axis questions too: _body.to_body(), _body.heel_rad(),
## _body.starboard_axis(), which hand no Basis over), the water surface, and the buoyancy grid's
## points and their depths below the water (the grid's own arrays, not copies: a packed array
## kept in two places is the same array, and the grid writes it before compute() reads it).
var _body: SimRigidBody = null
var _surface: WaterSurface = null
var _points: PackedVector3Array = PackedVector3Array()
var _depths: PackedFloat64Array = PackedFloat64Array()
## The wet span of the bottom found by _wetted_span(), metres forward of the transom.
var _span_aft_m: float = 0.0
var _span_forward_m: float = 0.0

# Results of the last compute().
var friction_n: float = 0.0
var residuary_n: float = 0.0
var lateral_n: float = 0.0
var resistance_n: float = 0.0  # friction + residuary + pressure drag, along the flow
var planing_lift_n: float = 0.0  # vertical component of the planing force
var planing_normal_force_n: float = 0.0
## The pull the strips applied (BoardConfig.strip_suction_heads): the sum of the negative
## strip forces, normal to the bottom, as a positive number. 0 with the option off.
var planing_pull_n: float = 0.0
## What the strips were not allowed to apply: with the option off, every pull (the clip,
## A-05); with it on, the part of a pull beyond the water's head. The force as it would have
## acted (down and along the bottom's normal) and its torque about the centre of mass, in
## world axes, so a tool can say what the clip does to the pitch (Game/dev/pitch_budget.gd).
var clipped_force_world: Vector3 = Vector3.ZERO
var clipped_torque_world: Vector3 = Vector3.ZERO
## The planing lift as a share of the whole weight of board, rig and sailor: what the trim
## press, the onset check and the HUD read. The fin and the rig carry part of the weight
## too, so a planing hull can show well under 1 here.
var planing_ratio: float = 0.0
## What the hull itself carries, upward: its planing lift plus the buoyancy it keeps.
var hull_load_n: float = 0.0
## How much of what the hull carries is dynamic: planing_lift_n / hull_load_n. It says
## whether the hull planes, whoever carries the rest of the weight (U2): a hull riding on
## its planing lift alone is at 1, whether the fin and the rig carry nothing or a third.
## Reported only: tried as the trim press's scale and not kept (PHYSICS_SPEC.md section 16).
var planing_share: float = 0.0
## Savitsky's porpoising limit for the hull's load at its speed (critical_trim_deg_for),
## degrees; 90 when the hull is out of the water or still. Reported only: it does not say
## where this hull porpoises, which is well above it (PHYSICS_SPEC.md section 5 F22).
var critical_trim_deg: float = 90.0
var trim_deg: float = 0.0  # angle of the planing surface to the flow, degrees
var wetted_length_m: float = 0.0  # of the planing surface (the wet part of the centreline)
var wetted_aft_m: float = 0.0  # where the wet part starts, forward of the transom (0 = wet transom)
var planing_beam_m: float = 0.0  # mean width of the wet part of the bottom
## The area the skin friction acts on: the larger of the buoyancy grid's wetted area and the
## planing wet span times its mean width (step 1 of compute()).
var friction_area_m2: float = 0.0
## Water that moves with the hull: the heave added mass of the wet bottom (a flat plate on
## the surface carries rho pi b^2 / 8 per metre of length) and its inertia about the centre
## of mass in pitch. Strip theory (Wagner, Zarnick), the same physics as the slamming term.
var heave_added_mass_kg: float = 0.0
## The lagged planing normal force (BoardConfig.planing_lift_lag_s).
var _lagged_normal_n: float = 0.0
var pitch_added_inertia_kgm2: float = 0.0
## And in roll: a plate of width b rolling on the surface carries rho pi b^4 / 256 per metre
## (Newman, Marine Hydrodynamics, table 4.3, halved for the free surface like the heave
## term). About 5 kg m2 for the default board: little next to the sailor, but ten times
## the bare board's own roll inertia, which is what keeps a board without its sailor from
## being flipped over by the first push on its fin.
var roll_added_inertia_kgm2: float = 0.0
## And sideways: each metre of hull side under water to a draft d (the deepest point of
## that part of the bottom) carries rho pi d^2 / 2 of water when it moves sideways, a
## vertical plate of span d with its mirror image in the free surface (the low-frequency,
## rigid-lid value used for manoeuvring: Newman, Marine Hydrodynamics, 1977, section 4.13;
## Clarke, Gedling and Hine 1983, the slender-body sway derivative pi (T/L)^2). About 6 kg
## at rest, a few hundred grams when planing; the fin's water is added by WindsurferSim.
var sway_added_mass_kg: float = 0.0
## The same water about the yaw axis through the centre of mass (each strip's sway added
## mass times its lever squared): about 3 kg m2 at rest, next to nothing when planing.
var yaw_added_inertia_kgm2: float = 0.0
## The buoyancy a planing bottom does not get (BoardConfig.planing_buoyancy_factor), pushed
## down at the centre of buoyancy; zero at the default factor of 1.
var buoyancy_correction_n: float = 0.0
var spray_root_factor: float = 1.0  # unsteady lift factor from the spray root running along the hull
var lambda_ratio: float = 0.0
var froude_number: float = 0.0
var reynolds_number: float = 0.0
var cop_local: Vector3 = Vector3.ZERO
var forward_speed_ms: float = 0.0
var planing_drag_n: float = 0.0  # the part of the planing force that points against the motion
var bow_drag_n: float = 0.0  # form drag of a nose pushed under the water
var rail_grip_n: float = 0.0  # sideways force of the rails' edges in a skid, summed over the strips
var rail_yaw_nm: float = 0.0  # its moment about the centre of mass, yaw (body y)
## How much further forward the keel is wet than the chines (Savitsky's L_k - L_c): the
## front part of the wet length, where a vee bottom is wet only near the keel.
var chine_dry_length_m: float = 0.0
## The vee across the bottom (BoardConfig.deadrise_deg): how far the bottom rises per metre
## out from the keel toward a rail. Set at the start of compute().
var _vee_rise_per_m: float = 0.0
## How far the water reaches across that vee: a section entering the water piles the water
## up its sides and is wet pi/2 times as far out as the still surface would cut it (Wagner
## 1932). That is the same as a vee 2/pi as steep, wet where the still surface cuts it.
var _vee_wetting_per_m: float = 0.0
## The water at the hull's own points (WaterSurface.sample_at: the height, the normal and the
## water's velocity from one solve), one record per point, kept from substep to substep so
## that each answer is where that point's next solve starts: the wet part's centroid, the
## planing strips, the spray root, the centre of buoyancy and the rail strips. The buoyancy
## grid's points (the centre column: the lateral drag and the nose) reuse the buoyancy
## model's records of the same substep instead (_grid_sea).
var _sea_at_wet_centroid: PackedFloat64Array = WaterSurface.new_samples(1)
var _sea_at_strips: PackedFloat64Array = WaterSurface.new_samples(STRIPS)
var _sea_at_spray_root: PackedFloat64Array = WaterSurface.new_samples(1)
var _sea_at_centre_of_buoyancy: PackedFloat64Array = WaterSurface.new_samples(1)
var _sea_at_rail_strips: PackedFloat64Array = WaterSurface.new_samples(STRIPS)
## The buoyancy grid's records of this substep, set at the start of compute() (empty when the
## grid was sampled on another surface, as some tests do).
var _grid_sea: PackedFloat64Array = PackedFloat64Array()
## For a grid point the grid's records do not answer: solved from scratch.
var _sea_spare: PackedFloat64Array = WaterSurface.new_samples(1)


func _init(board_config: BoardConfig, water_config: WaterConfig) -> void:
	board = board_config
	water = water_config
	copy_config()


## Copies the configs' numbers into this model's own (see the note at the top).
func copy_config() -> void:
	_length_m = board.length_m
	_thickness_m = board.thickness_m
	_length_samples = board.length_samples
	_width_samples = board.width_samples
	_deadrise_deg = board.deadrise_deg
	_rail_edge_height_m = board.rail_edge_height_m
	_lateral_drag_cd = board.lateral_drag_cd
	_residuary_peak_fraction = board.residuary_peak_fraction
	_residuary_peak_froude = board.residuary_peak_froude
	_residuary_froude_width = board.residuary_froude_width
	_spray_root_factor_max = board.spray_root_factor_max
	_planing_lift_lag_s = board.planing_lift_lag_s
	_planing_buoyancy_factor = board.planing_buoyancy_factor
	_bow_drag_cd = board.bow_drag_cd
	_strip_suction_heads = board.strip_suction_heads
	_heel_as_rolled_plate = board.heel_as_rolled_plate
	_density_kg_m3 = water.density_kg_m3
	_kinematic_viscosity_m2_s = water.kinematic_viscosity_m2_s


## Forgets the water's last answers at the hull's own points, so that the next compute()
## solves them from scratch: for a board put somewhere new (WindsurferSim.reset), whose
## answers are then a new board's to the last bit.
func forget_the_sea() -> void:
	for samples: PackedFloat64Array in [_sea_at_wet_centroid, _sea_at_strips, _sea_at_spray_root, _sea_at_centre_of_buoyancy, _sea_at_rail_strips]:
		WaterSurface.forget_samples(samples)


func compute(body: SimRigidBody, buoyancy: BuoyancyModel, surface: WaterSurface, time_s: float, gravity_ms2: float, total_mass_kg: float, dt: float = 1.0 / 240.0) -> void:
	_clear()
	# What the buoyancy grid found this substep, read once (see the note at the top).
	var grid_wetted_area_m2: float = buoyancy.wetted_area_m2
	if not buoyancy.is_floating or grid_wetted_area_m2 <= 0.0:
		return
	var grid_wetted_length_m: float = buoyancy.wetted_length_m
	var buoyancy_force_n: float = buoyancy.buoyancy_force_n
	var centre_of_buoyancy: Vector3 = buoyancy.centre_of_buoyancy_world
	_points = buoyancy.sample_points
	_depths = buoyancy.point_depths_m
	_grid_sea = buoyancy.sea_samples_of(surface)
	# The body and the water, for the helpers below.
	_body = body
	_surface = surface

	# The wet part of the bottom along the centreline. Usually it runs from the transom
	# forward; when the tail has lifted clear and the nose is down, it is the middle of the
	# hull and the nose rocker that are wet. Everything below works on this span.
	_vee_rise_per_m = tan(deg_to_rad(_deadrise_deg))
	_vee_wetting_per_m = WAGNER_CUT * _vee_rise_per_m
	_wetted_span()
	var aft: float = _span_aft_m
	var forward: float = _span_forward_m
	wetted_aft_m = aft
	wetted_length_m = forward - aft
	planing_beam_m = _mean_width(aft, forward)
	chine_dry_length_m = _chine_dry_length(aft, forward)
	_compute_added_mass(aft, forward, body.com_offset_body.z)

	# The flow relative to the wet part of the hull.
	var wet_point: Vector3 = buoyancy.wet_centroid_world
	surface.sample_at(wet_point.x, wet_point.z, time_s, _sea_at_wet_centroid, 0)
	var v_rel: Vector3 = body.point_velocity(wet_point) - WaterSurface.sample_velocity(_sea_at_wet_centroid, 0)
	var v_body: Vector3 = body.to_body(v_rel)
	forward_speed_ms = -v_body.z
	var v_h: Vector3 = SimMath.horizontal(v_rel)
	var speed_h: float = v_h.length()
	var rho: float = _density_kg_m3

	if speed_h > 0.01:
		var flow_dir: Vector3 = v_h / speed_h
		# The wetted bottom of a planing hull runs from the spray root to the transom: the
		# wet span of the strip theory times the mean width there, which at a low trim is
		# far more than the still-water grid wets (a flat bottom at 1 degree of trim wets
		# half a metre of length per centimetre of depth). Whichever is larger. On a vee
		# bottom the chines are wet over a shorter length than the keel, so the planing
		# area is the mean wetted length (the keel's, less half the chine-dry part) times
		# the width (Savitsky 1964).
		var dynamic_area_m2: float = (wetted_length_m - 0.5 * chine_dry_length_m) * planing_beam_m
		var wetted_area_m2: float = maxf(grid_wetted_area_m2, dynamic_area_m2)
		friction_area_m2 = wetted_area_m2
		var reference_length: float = maxf(maxf(grid_wetted_length_m, wetted_length_m), 0.3)

		# 1. Skin friction on the wetted bottom (ITTC 1957 line).
		reynolds_number = maxf(speed_h * reference_length / _kinematic_viscosity_m2_s, 1e5)
		var cf: float = 0.075 / pow(log(reynolds_number) / log(10.0) - 2.0, 2.0)
		var q_h: float = 0.5 * rho * speed_h * speed_h
		friction_n = cf * q_h * wetted_area_m2
		body.add_force_at(wet_point, -flow_dir * friction_n)

		# 2. Wave-making drag while the hull pushes water aside: a hump around a Froude
		# number of about 0.55, scaled by the weight that buoyancy still carries. As the
		# planing lift takes the weight over, this term fades out by itself.
		froude_number = speed_h / sqrt(gravity_ms2 * reference_length)
		var hump: float = (froude_number - _residuary_peak_froude) / _residuary_froude_width
		var residuary_coefficient: float = _residuary_peak_fraction * exp(-hump * hump)
		residuary_n = residuary_coefficient * buoyancy_force_n
		body.add_force_at(centre_of_buoyancy, -flow_dir * residuary_n)

	# 3. Sideways drag of the immersed hull, row by row along the length, so that a turning
	# board is also damped in yaw by the water (section 5 F10).
	_apply_lateral_drag(time_s, rho)

	# 4. Dynamic lift of the planing surface.
	_apply_planing_lift(aft, forward, time_s, gravity_ms2, total_mass_kg, rho, dt)

	# 4b. The buoyancy a planing bottom does not get (off at the default factor of 1).
	_apply_planing_buoyancy(time_s, gravity_ms2, buoyancy_force_n, centre_of_buoyancy)

	# 4c. What the hull carries, and how much of it is dynamic.
	hull_load_n = planing_lift_n + maxf(buoyancy_force_n - buoyancy_correction_n, 0.0)
	planing_share = clampf(planing_lift_n / hull_load_n, 0.0, 1.0) if hull_load_n > 0.0 else 0.0
	# Savitsky's porpoising limit for that load at this speed, on the wet bottom's width as
	# the planing lift sees it (narrower as the board heels) and the tail's vee.
	var lift_beam_m: float = planing_beam_m * maxf(cos(body.heel_rad()), 0.3)
	critical_trim_deg = critical_trim_deg_for(hull_load_n, forward_speed_ms, lift_beam_m, _deadrise_deg, rho)

	# 5. A nose under water meets the water face-on.
	_apply_bow_drag(time_s, rho, buoyancy.bow_immersion_m, buoyancy.bow_centre_index)

	# 6. A rail skidding sideways meets the water with its edge.
	_apply_rail_grip(aft, forward, time_s, rho, dt)

	resistance_n = friction_n + residuary_n + planing_drag_n + bow_drag_n


func _apply_lateral_drag(time_s: float, rho: float) -> void:
	var rows: int = maxi(_length_samples, 1)
	var row_length: float = _length_m / rows
	var centre_column: int = maxi(_width_samples, 1) / 2
	var columns: int = maxi(_width_samples, 1)
	var starboard: Vector3 = _body.starboard_axis()
	lateral_n = 0.0
	for k: int in _points.size():
		if k % columns != centre_column:
			continue
		# The immersed side of a heeled board is its low rail: deeper than the centreline.
		var depth: float = _row_max_depth(k / columns)
		if depth <= 0.0:
			continue
		var point_world: Vector3 = _body.point_world(_points[k])
		var v_rel: Vector3 = _body.point_velocity(point_world) - _water_velocity_at_grid_point(k, point_world, time_s)
		var v_lat: float = v_rel.dot(starboard)
		# The hard rail's edge face is in the rail model (_apply_rail_grip); the cross-flow
		# drag takes the rest of the immersed side.
		var from_transom: float = 0.5 * _length_m - _points[k].z
		var edge: float = board.rail_hardness(from_transom) * minf(depth, _rail_edge_height_m)
		var side_area: float = row_length * maxf(minf(depth, _thickness_m) - edge, 0.0)
		var force: float = -0.5 * rho * _lateral_drag_cd * side_area * v_lat * absf(v_lat)
		_body.add_force_at(point_world, starboard * force)
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
func _apply_planing_lift(aft: float, forward: float, time_s: float, gravity_ms2: float, total_mass_kg: float, rho: float, _dt: float) -> void:
	var u: float = forward_speed_ms
	var length: float = wetted_length_m
	if u < 0.5 or length < 0.1:
		return
	var strip_length: float = length / float(STRIPS)
	var pitch: float = _body.pitch_rad()
	var heel: float = _body.heel_rad()
	# A board on its rail or upside down (after a fall) has no planing bottom facing the
	# water; the strip theory below would push it the wrong way.
	if cos(heel) <= 0.3:
		return
	var beam: float = planing_beam_m * maxf(cos(heel), 0.3)
	# Savitsky's lift and centre of pressure take the mean wetted length: on a vee bottom,
	# the keel's less half the chine-dry part.
	lambda_ratio = clampf((length - 0.5 * chine_dry_length_m) / beam, 0.2, _length_m / beam)

	# The wet bottom seen as one cambered plate, for the reference trim: its chord is
	# inclined to the board by the rocker and the bottom bulges below the chord, toward the
	# water, which is the pressure side. That is camber the wrong way up for lift: thin-
	# airfoil theory moves the zero-lift angle by two sag-over-length, so the plate lifts
	# as if trimmed that much less (Anderson, Fundamentals of Aerodynamics; a planing
	# bottom with convex buttocks, rocker, lifts less than a flat one at the same trim, and
	# a concave one, hook, more: Savitsky 1964, Savitsky and Brown 1976).
	var chord_angle: float = _chord_angle(aft, forward)
	var camber_angle: float = -2.0 * _camber_sag(aft, forward) / length
	var trim_geometric: float = pitch + chord_angle + camber_angle

	# 1. The strips: where each is, which way its bottom faces, how fast it moves into the
	#    water (V, positive into the water) and how much water a metre of it carries.
	var x_k: PackedFloat64Array = PackedFloat64Array()
	var points_world: PackedVector3Array = PackedVector3Array()
	var normals_world: PackedVector3Array = PackedVector3Array()
	var v_into: PackedFloat64Array = PackedFloat64Array()
	var m_per_m: PackedFloat64Array = PackedFloat64Array()
	var full_widths: PackedFloat64Array = PackedFloat64Array()
	var wet_fractions: PackedFloat64Array = PackedFloat64Array()
	var wet_centres: PackedFloat64Array = PackedFloat64Array()  # body x of each strip's wet centre
	var sink_ms: PackedFloat64Array = PackedFloat64Array()  # down through the surface
	var v_mean: float = 0.0
	for k: int in STRIPS:
		var x: float = aft + (float(k) + 0.5) * strip_length
		var slope: float = board.bottom_slope(x)
		var normal_local: Vector3 = Vector3(0.0, 1.0, slope).normalized()
		# Across the board: how much of this strip's width is wet and where its centre is
		# (on the low rail of a heeled board). The strip carries the added mass of its wet
		# width and its force acts at that centre.
		var wet: Vector2 = _wet_width(x)
		var point_world: Vector3 = _body.point_world(Vector3(wet.y, _bottom_y(x), 0.5 * _length_m - x))
		var normal_world: Vector3 = _body.to_world(normal_local)
		_surface.sample_at(point_world.x, point_world.z, time_s, _sea_at_strips, k)
		var v_rel: Vector3 = _body.point_velocity(point_world) - WaterSurface.sample_velocity(_sea_at_strips, k)
		var full_width: float = _width_at(x)
		var width: float = full_width * wet.x
		x_k.append(x)
		points_world.append(point_world)
		normals_world.append(normal_world)
		v_into.append(-v_rel.dot(normal_world))
		m_per_m.append(rho * PI * width * width / 8.0)
		full_widths.append(full_width)
		wet_fractions.append(wet.x)
		wet_centres.append(wet.y)
		sink_ms.append(-v_rel.dot(WaterSurface.sample_normal(_sea_at_strips, k)))
		v_mean += v_into[k] / float(STRIPS)
	trim_deg = rad_to_deg(atan2(v_mean, u))

	# 2. Along the hull: where V grows toward the stern the water gains downward momentum
	#    as it flows aft and pushes up; where V shrinks it pushes less. Where the hull widens
	#    going aft (the nose) the water column gains added mass, more push; where it narrows
	#    the water lets go instead of pulling. Over the last half beam before the aft end
	#    the pressure falls away to the air behind it (the transom relief).
	#    The added mass also grows aft where the water reaches further across the bottom:
	#    behind the spray root of a vee, or of a heeled bottom, where only part of the width
	#    is wet. That part of the root runs across a sinking strip faster and across a
	#    rising one slower, by the same factor as the root at the front (step 3; Zarnick
	#    1978: the force is the rate of change of the added mass's momentum, and a section's
	#    added mass grows with its immersion).
	#    The added mass the water gains between two neighbouring strips is shared by the two
	#    (the front strip's gain from nothing is the spray root's, step 3), so the gains add
	#    up to the added mass under the widest wet section, as the theory has it.
	#    With the strips allowed to pull (BoardConfig.strip_suction_heads), the push where the
	#    water reaches further across the bottom (the spray root running obliquely across a
	#    vee or a heeled bottom) joins the front root's push and is spread with it (step 5),
	#    for the same reason the front root's is: the pressure peaks at the root and decays
	#    aft (A-03). The convective part (dV/dx) stays on its strip.
	var strip_forces: PackedFloat64Array = PackedFloat64Array()
	var oblique_root_force: float = 0.0
	for k: int in STRIPS:
		var k0: int = maxi(k - 1, 0)
		var k1: int = mini(k + 1, STRIPS - 1)
		var dx: float = float(k1 - k0) * strip_length
		var dv_dx: float = (v_into[k1] - v_into[k0]) / dx
		var force: float = -u * m_per_m[k] * dv_dx * strip_length
		var gained: float = 0.0
		var advance: float = _root_advance_factor(sink_ms[k], u, pitch + board.bottom_slope(x_k[k]))
		for j: int in range(k - 1, k + 1):  # k - 1 and k (a range: an array literal takes the lock)
			if j < 0 or j >= STRIPS - 1:
				continue
			var gain_kg_m: float = m_per_m[j] - m_per_m[j + 1]
			# The wetting's share of it: m = rho pi (W f)^2 / 8 at this strip's outline width.
			var wetting_gain_kg_m: float = rho * PI / 8.0 * full_widths[k] * full_widths[k] * (wet_fractions[j] * wet_fractions[j] - wet_fractions[j + 1] * wet_fractions[j + 1])
			var gain: float = gain_kg_m + (advance - 1.0) * wetting_gain_kg_m
			if gain > 0.0:
				gained += 0.5 * u * v_into[k] * gain
		var relief: float = clampf((x_k[k] - aft) / (TRANSOM_RELIEF_BEAMS * beam), 0.0, 1.0)
		if _strip_suction_heads > 0.0:
			oblique_root_force += gained * relief
			strip_forces.append(force * relief)
		else:
			strip_forces.append((force + gained) * relief)

	# 3. The spray root: still water is set in motion at the rate the root sweeps along it.
	#    When the hull also sinks, the root runs forward along the hull (sinking speed over
	#    the tangent of the bottom's angle to the surface) and more water is engaged per
	#    second; when the hull rises the root retreats and the push fades, and a bottom
	#    leaving the water faster than the water can follow carries nothing. Below one
	#    degree the root would run faster than the theory allows for, so the factor is held
	#    at twice the steady value (PHYSICS_SPEC.md section 16).
	var last: int = STRIPS - 1
	var v_root: float = v_into[last] + 0.5 * (v_into[last] - v_into[last - 1])
	var root_across: float = _wet_width(forward).y
	var root_world: Vector3 = _body.point_world(Vector3(root_across, _bottom_y(forward), 0.5 * _length_m - forward))
	_surface.sample_at(root_world.x, root_world.z, time_s, _sea_at_spray_root, 0)
	var root_normal: Vector3 = WaterSurface.sample_normal(_sea_at_spray_root, 0)
	var root_down_speed: float = -(_body.point_velocity(root_world) - WaterSurface.sample_velocity(_sea_at_spray_root, 0)).dot(root_normal)
	spray_root_factor = _root_advance_factor(root_down_speed, u, pitch + board.bottom_slope(forward))
	var root_force: float = maxf(u * spray_root_factor * m_per_m[last] * v_root, 0.0) + oblique_root_force

	# 4. Three-dimensional correction: the strip theory is two-dimensional and gives a flat
	#    plate m' u^2 trim; Savitsky (1964) measured the lift of real planing plates, with
	#    the deadrise correction. Their ratio at the geometric trim (or at one degree, below
	#    that) scales everything. This is how slender-body planing models are anchored.
	var tau_ref_deg: float = maxf(rad_to_deg(trim_geometric), 1.0)
	#    The heeled bottom as a rolled flat plate (BoardConfig.heel_as_rolled_plate, NACA TN
	#    4187): Savitsky's lift at the mean wetted length of the two rails, with the heel as an
	#    added deadrise, and the strips' total anchored on the widest wet strip, since Savitsky's
	#    lambda already carries the vee's chine-dry front (the strips' narrower wet front must
	#    not count it again). Level, that is Savitsky's lift exactly at every wet length.
	var lift_lambda: float = lambda_ratio
	var lift_deadrise_deg: float = _deadrise_deg
	var anchor_on_wet_width: bool = false
	if _heel_as_rolled_plate > 0.0:
		lift_lambda = _rolled_plate_lambda(aft, forward, beam, heel)
		lift_deadrise_deg = maxf(_deadrise_deg, absf(rad_to_deg(heel)))
		anchor_on_wet_width = true
	var cl_flat: float = 0.012 * pow(minf(tau_ref_deg, 15.0), 1.1) * sqrt(lift_lambda)
	var cl_dynamic: float = maxf(cl_flat - 0.0065 * lift_deadrise_deg * pow(cl_flat, 0.6), 0.0)
	var savitsky_lift: float = cl_dynamic * 0.5 * rho * u * u * beam * beam
	# The slender-body total for the plate is the momentum flux of the water set moving
	# under its widest wet section: the root's push, plus the push where the hull widens
	# going aft (a nose), with nothing taken back where it narrows (the water lets go). So
	# the reference is the full width of the widest wet strip. (The width at the root was
	# used before; with the whole hull wet the root is in the narrow nose, and that inflated
	# the lift of a submerged or slow hull by the square of the width ratio: 6 times for
	# the 0.285 m nose tip, Session 39.) On a heeled board the forward strips are wet only
	# at the rail; the full width is still the right reference (the 2D total is the same
	# force, spread along the oblique spray root), and it keeps the scaling finite.
	var widest_full_width: float = 0.0
	for k: int in STRIPS:
		widest_full_width = maxf(widest_full_width, full_widths[k] * (wet_fractions[k] if anchor_on_wet_width else 1.0))
	var slender_lift: float = rho * PI * widest_full_width * widest_full_width / 8.0 * u * u * sin(deg_to_rad(tau_ref_deg))
	var three_d_factor: float = savitsky_lift / maxf(slender_lift, 1e-6)

	# 5. Where the root's force acts: the pressure peaks just behind the spray root and
	#    decays aft. A triangle from the root backwards whose centroid is Savitsky's centre
	#    of pressure (0.75 of the wet length from the aft end at speed) spreads it.
	var cv: float = u / sqrt(gravity_ms2 * beam)
	var cop_fraction: float = 0.75 - 1.0 / (5.21 * cv * cv / (lambda_ratio * lambda_ratio) + 2.39)
	var spread: float = maxf(3.0 * (1.0 - cop_fraction) * length, strip_length)

	# 6. What each strip may pull (BoardConfig.strip_suction_heads). The theory has the water
	#    sucking on a bottom that lifts away from it (a rocker behind the spray root). With the
	#    option off no strip may pull: the water has let go instead (A-05, the clip). With it
	#    on, a strip may pull as hard as the still water's head above its bottom (rho g depth
	#    over its wet area) times the option, and no harder: below that the air from the rails
	#    would get in. A strip wet only by the water's climb (its centre above the still
	#    surface) has no head and may not pull.
	var pull_max: PackedFloat64Array = PackedFloat64Array()
	for k: int in STRIPS:
		var head_pa: float = 0.0
		if _strip_suction_heads > 0.0:
			head_pa = rho * gravity_ms2 * maxf(_bottom_depth_at(x_k[k], wet_centres[k]), 0.0)
		pull_max.append(_strip_suction_heads * head_pa * full_widths[k] * wet_fractions[k] * strip_length)
	# With the strips allowed to pull, the strips on a rocker take back part of the root's
	# push just behind it, and the push of the whole would sit behind Savitsky's centre. So the
	# root's triangle is then spread so that the whole (the strips and the root) has its centre
	# where Savitsky measured it: the same anchor as before, on the whole instead of the root.
	if _strip_suction_heads > 0.0 and root_force > 1e-6:
		spread = _spread_for_centroid(x_k, strip_forces, pull_max, three_d_factor, root_force, forward, aft + cop_fraction * length, strip_length, spread)
	var weights: PackedFloat64Array = PackedFloat64Array()
	var weight_sum: float = 0.0
	for k: int in STRIPS:
		weights.append(maxf(1.0 - (forward - x_k[k]) / spread, 0.0))
		weight_sum += weights[k]

	# 7. Apply, each strip's push or (bounded) pull normal to its bottom.
	var flow_dir: Vector3 = SimMath.horizontal(_body.velocity)
	flow_dir = flow_dir.normalized() if flow_dir.length() > 0.01 else Vector3.ZERO
	var weighted_position: Vector3 = Vector3.ZERO
	var centre_of_mass: Vector3 = _body.position
	# The unsteady lag (BoardConfig.planing_lift_lag_s): the quasi-steady total is followed
	# with a first-order lag, and every strip is scaled by the same factor.
	var bounded: PackedFloat64Array = PackedFloat64Array()
	var quasi_steady_n: float = 0.0
	for k: int in STRIPS:
		var share_k: float = root_force * weights[k] / weight_sum if weight_sum > 0.0 else 0.0
		var wanted: float = three_d_factor * (strip_forces[k] + share_k)
		var allowed: float = maxf(wanted, -pull_max[k])
		if wanted < allowed:
			# What the strip was not allowed to pull, as it would have acted: reported only.
			var withheld: Vector3 = normals_world[k] * (wanted - allowed)
			clipped_force_world += withheld
			clipped_torque_world += (points_world[k] - centre_of_mass).cross(withheld)
		bounded.append(allowed)
		quasi_steady_n += allowed
	var lag_factor: float = 1.0
	if _planing_lift_lag_s > 0.0 and quasi_steady_n > 0.0:
		var blend: float = clampf(_dt / _planing_lift_lag_s, 0.0, 1.0)
		_lagged_normal_n = lerpf(_lagged_normal_n, quasi_steady_n, blend)
		lag_factor = _lagged_normal_n / quasi_steady_n
	else:
		_lagged_normal_n = quasi_steady_n
	for k: int in STRIPS:
		var magnitude: float = bounded[k] * lag_factor
		if magnitude == 0.0:
			continue
		var force: Vector3 = normals_world[k] * magnitude
		_body.add_force_at(points_world[k], force)
		planing_lift_n += force.y
		planing_normal_force_n += magnitude
		planing_pull_n -= minf(magnitude, 0.0)
		planing_drag_n -= force.dot(flow_dir)
		weighted_position += points_world[k] * magnitude
	if planing_normal_force_n > 0.0:
		cop_local = _body.to_body(weighted_position / planing_normal_force_n - _body.origin_world())
	planing_ratio = clampf(planing_lift_n / (total_mass_kg * gravity_ms2), 0.0, 1.0)


## How far back from the spray root the root's push is spread (the triangle of step 5) so
## that the whole push, the strips' pushes and pulls (each pull bounded as in step 6) plus
## the root's, has its centre at the target: Savitsky's centre of pressure. Found by halving
## between the shortest triangle (one strip) and a nearly even spread over the wet part: a
## longer triangle moves the root's push aft. Where no spread reaches the target (the strips'
## pulls would need the root's push ahead of the root, or behind the middle of the wet
## part), the nearest end is taken. With the strips' sum at zero (a flat plate) the answer is
## the old spread, so a flat plate is unchanged.
func _spread_for_centroid(x_k: PackedFloat64Array, strip_forces: PackedFloat64Array, pull_max: PackedFloat64Array, three_d_factor: float, root_force: float, forward: float, target: float, strip_length: float, fallback: float) -> float:
	var low: float = strip_length
	var high: float = 50.0 * (forward - x_k[0])
	for i: int in 30:
		var middle: float = 0.5 * (low + high)
		var weight_sum: float = 0.0
		for k: int in STRIPS:
			weight_sum += maxf(1.0 - (forward - x_k[k]) / middle, 0.0)
		var total: float = 0.0
		var moment: float = 0.0
		for k: int in STRIPS:
			var share: float = root_force * maxf(1.0 - (forward - x_k[k]) / middle, 0.0) / weight_sum
			var bounded: float = maxf(three_d_factor * (strip_forces[k] + share), -pull_max[k])
			total += bounded
			moment += bounded * x_k[k]
		if total <= 1e-6:
			return fallback
		if moment / total > target:
			low = middle  # the push sits too far forward: spread the root further aft
		else:
			high = middle
	return 0.5 * (low + high)


## Still-water depth of the bottom at a point of it (metres forward of the transom, metres
## across in body x), between the rail points of the two nearest grid rows: the same plane
## across the section as _wet_width takes, less the vee's rise toward the rail. Negative
## above the still surface.
func _bottom_depth_at(from_transom: float, across: float) -> float:
	var rows: int = maxi(_length_samples, 2)
	var columns: int = maxi(_width_samples, 1)
	var spacing: float = _length_m / float(rows - 1)
	var position: float = clampf(from_transom / spacing, 0.0, float(rows - 1))
	var i0: int = mini(int(floor(position)), rows - 2)
	var t: float = position - float(i0)
	var port: float = lerpf(_depths[i0 * columns], _depths[(i0 + 1) * columns], t)
	var starboard: float = lerpf(_depths[i0 * columns + columns - 1], _depths[(i0 + 1) * columns + columns - 1], t)
	var half_width: float = 0.5 * _width_at(from_transom)
	var middle: float = 0.5 * (port + starboard)
	if columns < 3 or half_width < 1e-6:
		return middle
	var slope: float = (starboard - port) / (2.0 * half_width)
	return middle + slope * across - absf(across) * _vee_rise_per_m


## At planing speed the water leaves the transom and the rails clear of the bottom, so the
## pressure there is the air's instead of the weight of the water above it: the bottom gets
## only part of the buoyancy the still-water grid gives it (Shuford 1958, Zarnick 1978;
## BoardConfig.planing_buoyancy_factor). What it keeps acts where the grid's buoyancy acts:
## the dynamic term at 0.75 of the wet length and the buoyant term at one third (the
## centroid of the wet wedge) reproduce Savitsky's (1964) centre of pressure exactly. The
## loss is phased in across the semi-displacement range, where the dynamic lift takes the
## weight over from the buoyancy (Faltinsen 2005).
func _apply_planing_buoyancy(time_s: float, gravity_ms2: float, buoyancy_force_n: float, centre: Vector3) -> void:
	var lost_share: float = 1.0 - _planing_buoyancy_factor
	if lost_share <= 0.0 or forward_speed_ms <= 0.0 or buoyancy_force_n <= 0.0:
		return
	var froude_on_length: float = forward_speed_ms / sqrt(gravity_ms2 * _length_m)
	var planing: float = smoothstep(FROUDE_DISPLACEMENT, FROUDE_PLANING, froude_on_length)
	buoyancy_correction_n = lost_share * planing * buoyancy_force_n
	_surface.sample_at(centre.x, centre.z, time_s, _sea_at_centre_of_buoyancy, 0)
	_body.add_force_at(centre, -WaterSurface.sample_normal(_sea_at_centre_of_buoyancy, 0) * buoyancy_correction_n)


## When the deck at the bow goes under (a nose dive, a wave over the nose), the water
## meets the nose and the deck face-on: a blunt body of the hull's section at the nose
## (its width there times the depth of the deck, at most the thickness) with bow_drag_cd.
## The force acts at the nose, against the flow there, which is below the centre of mass:
## it slows the board hard and pitches it over the nose, as a pearling board does. A bow
## whose bottom is wet but whose deck is dry (the hump, a chop) is a knife, not a face,
## and its wave-making is in the residuary drag already; it feels nothing here.
func _apply_bow_drag(time_s: float, rho: float, bow_immersion_m: float, bow_index: int) -> void:
	bow_drag_n = 0.0
	var deck_immersion: float = bow_immersion_m - _thickness_m
	var immersed_height: float = clampf(deck_immersion, 0.0, _thickness_m)
	if immersed_height <= 0.0:
		return
	var nose_world: Vector3 = _body.point_world(_points[bow_index])
	var v_rel: Vector3 = _body.point_velocity(nose_world) - _water_velocity_at_grid_point(bow_index, nose_world, time_s)
	var aft: Vector3 = _body.aft_axis()
	var along: float = v_rel.dot(-aft)  # forward speed through the water at the nose
	if along <= 0.05:
		return
	var area: float = _width_at(_length_m) * immersed_height
	bow_drag_n = 0.5 * rho * _bow_drag_cd * area * along * along
	_body.add_force_at(nose_world, aft * bow_drag_n)


## The rails in a skid. A flat planing bottom moving at a yaw angle to the flow carries no
## sideways force of its own: the pressure acts normal to the bottom (the strips above
## already tilt it with the board), and the measured side force of a flat plate with sharp
## chines is nothing but that tilt (NACA TN 4187, equation 1: "the side-force coefficient
## in the body axis is nearly zero for all test combinations"). What grips is the rail:
## the edge where the bottom meets the side. Once the sideways flow under a skidding
## bottom reaches the leading edge (the rail on the side the hull moves toward), it meets
## the edge face and pushes on it with about the full dynamic pressure of the flow (Ce' 1.0
## to 1.3, TN 4187 figure 27, "positive pressure on leading chine edge"). Below the
## inception angle the flow breaks clear of the edge and the rail carries nothing.
##
## Strip by strip along the wet length, each strip with its own slip (the hull's sideways
## speed plus the yaw rate times the strip's distance from the centre of mass), so a
## spinning hull grips with its tail one way and its nose the other, and the moment
## opposes the spin. The edge face is the rail's near-vertical lower face
## (BoardConfig.rail_edge_height_m), wetted to the depth of that rail below the surface;
## a soft (tucked) rail lets the flow wrap round it instead (BoardConfig.rail_hardness).
## The force acts on the edge, normal to it, against the slip; no more than what stops
## the strip's sideways motion within the step (the exact result for a damper integrated
## implicitly), shared among the gripping strips.
func _apply_rail_grip(aft: float, forward: float, time_s: float, rho: float, dt: float) -> void:
	rail_grip_n = 0.0
	rail_yaw_nm = 0.0
	var length: float = forward - aft
	var heel: float = _body.heel_rad()
	if length < 0.05 or cos(heel) <= 0.3:
		return
	var strip_length: float = length / float(STRIPS)
	var starboard: Vector3 = _body.starboard_axis()
	var magnitudes: PackedFloat64Array = PackedFloat64Array()
	var points: PackedVector3Array = PackedVector3Array()
	var directions: PackedVector3Array = PackedVector3Array()
	var slips_ms: PackedFloat64Array = PackedFloat64Array()
	var gripping: int = 0
	for k: int in STRIPS:
		var x: float = aft + (float(k) + 0.5) * strip_length
		var z: float = 0.5 * _length_m - x
		var hardness: float = board.rail_hardness(x)
		var centre_world: Vector3 = _body.point_world(Vector3(0.0, _bottom_y(x), z))
		_surface.sample_at(centre_world.x, centre_world.z, time_s, _sea_at_rail_strips, k)
		var v_rel: Vector3 = _body.point_velocity(centre_world) - WaterSurface.sample_velocity(_sea_at_rail_strips, k)
		var v_body: Vector3 = _body.to_body(v_rel)
		var slip_ms: float = v_body.x  # sideways through the water, positive to starboard
		var side: float = 1.0 if slip_ms >= 0.0 else -1.0  # the leading rail
		var edge_wet_m: float = clampf(_rail_depth(x, side), 0.0, _rail_edge_height_m)
		var magnitude: float = 0.0
		if hardness > 0.0 and edge_wet_m > 0.0:
			var slip_deg: float = rad_to_deg(atan2(absf(slip_ms), absf(v_body.z)))
			var rail_down_deg: float = rad_to_deg(heel) * side
			var inception: float = clampf(RAIL_INCEPTION_DEG - RAIL_INCEPTION_PER_HEEL * rail_down_deg, 3.0, 15.0)
			var grip: float = smoothstep(inception, inception + RAIL_ENGAGE_DEG, slip_deg)
			var q: float = 0.5 * rho * (v_body.x * v_body.x + v_body.z * v_body.z)
			magnitude = hardness * RAIL_FORCE_COEFFICIENT * grip * q * edge_wet_m * strip_length
		if magnitude > 0.0:
			gripping += 1
		magnitudes.append(magnitude)
		points.append(_body.point_world(Vector3(side * 0.5 * _width_at(x), _bottom_y(x) + 0.5 * edge_wet_m, z)))
		directions.append(-side * starboard)
		slips_ms.append(absf(slip_ms))
	if gripping == 0:
		return
	var torque: Vector3 = Vector3.ZERO
	var centre_of_mass: Vector3 = _body.position
	for k: int in STRIPS:
		if magnitudes[k] <= 0.0:
			continue
		var stopping: float = _body.effective_mass_at(points[k], directions[k]) * slips_ms[k] / maxf(dt, 1e-4) / float(gripping)
		var force: Vector3 = directions[k] * minf(magnitudes[k], stopping)
		_body.add_force_at(points[k], force)
		rail_grip_n += force.length()
		torque += (points[k] - centre_of_mass).cross(force)
	rail_yaw_nm = torque.dot(_body.up_axis())


## The water's velocity at point k of the buoyancy grid: from the grid's own record when it
## answers the same question (the simulation calls buoyancy.apply() just before compute(), so
## the point and the time are the same), otherwise from a solve from scratch.
func _water_velocity_at_grid_point(k: int, point_world: Vector3, time_s: float) -> Vector3:
	if not _grid_sea.is_empty() and WaterSurface.sample_answers(_grid_sea, k, point_world.x, point_world.z, time_s):
		return WaterSurface.sample_velocity(_grid_sea, k)
	WaterSurface.forget_samples(_sea_spare)
	_surface.sample_at(point_world.x, point_world.z, time_s, _sea_spare, 0)
	return WaterSurface.sample_velocity(_sea_spare, 0)


## Depth below the water of one rail (side +1 starboard, -1 port) at a distance forward of
## the transom, between the rail points of the two nearest grid rows.
func _rail_depth(from_transom: float, side: float) -> float:
	var rows: int = maxi(_length_samples, 2)
	var columns: int = maxi(_width_samples, 1)
	var spacing: float = _length_m / float(rows - 1)
	var position: float = clampf(from_transom / spacing, 0.0, float(rows - 1))
	var i0: int = mini(int(floor(position)), rows - 2)
	var column: int = columns - 1 if side > 0.0 else 0
	return lerpf(_point_depth(i0 * columns + column), _point_depth((i0 + 1) * columns + column), position - float(i0))


## Depth below the water of a point of the buoyancy grid on the vee bottom. The grid's
## points lie on a flat bottom at the keel's height; the vee lifts a rail's point by its
## distance out from the keel times the deadrise's tangent (a few millimetres).
func _point_depth(index: int) -> float:
	return _depths[index] - absf(_points[index].x) * _vee_rise_per_m


## The wet part of the bottom as [aft, forward] in metres from the transom, from the
## deepest point of each row (the centre of a level board, the low rail of a heeled one),
## with both ends interpolated between the last wet row and the first dry one. [0, 0] when
## the bottom is dry. Into _span_aft_m and _span_forward_m (two numbers, not a new array: making
## an array from a list takes the engine's lock).
func _wetted_span() -> void:
	var rows: int = maxi(_length_samples, 2)
	var spacing: float = _length_m / float(rows - 1)
	var aft: float = -1.0
	var forward: float = 0.0
	var previous_depth: float = -1.0
	for i: int in rows:
		var depth: float = _row_max_depth(i)
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
		_span_aft_m = 0.0
		_span_forward_m = 0.0
		return
	_span_aft_m = aft
	_span_forward_m = forward


## The deepest point of a row of the buoyancy grid on the vee bottom (row 0 is the tail
## row): the keel of a level board, the low rail of a heeled one.
func _row_max_depth(row: int) -> float:
	var columns: int = maxi(_width_samples, 1)
	var deepest: float = -INF
	for j: int in columns:
		deepest = maxf(deepest, _point_depth(row * columns + j))
	return deepest


## The wet part of the bottom across the board at a distance forward of the transom:
## x = the wet fraction of the width (0 to 1), y = the depth-weighted centre of the wet
## part in body x (metres, positive to starboard). The depth across the width is taken as
## linear between the rail points of the two nearest grid rows (a flat bottom heeled is a
## plane), less the vee's rise from the keel toward each rail. The water does not stop
## where the still surface cuts that section: entering the water it piles up the bottom's
## sides and wets pi/2 times as far out from the deepest point (Wagner 1932). Across a
## level vee that is from the keel; across a heeled bottom it is from the low rail up
## toward the high one, which NACA TN 4187 measured on rolled flat plates (Savitsky,
## Prowse and Lueders 1958, equation 2: the high chine is dry over 2 b tan(roll) /
## (pi tan(trim)) of the length, not the still surface's b tan(roll) / tan(trim)). So the
## section's depth is flattened by 2/pi about its deepest point. A level flat board gives
## (1, 0); a board heeled to starboard gives a centre on the starboard side and, toward the
## bow, a strip wet only near that rail; a level vee is wet only near the keel just behind
## the spray root, and across its whole width further aft, where the keel is deep enough
## for the water to reach the chines.
func _wet_width(from_transom: float) -> Vector2:
	var rows: int = maxi(_length_samples, 2)
	var columns: int = maxi(_width_samples, 1)
	if columns < 3:
		return Vector2(1.0, 0.0)
	var spacing: float = _length_m / float(rows - 1)
	var position: float = clampf(from_transom / spacing, 0.0, float(rows - 1))
	var i0: int = mini(int(floor(position)), rows - 2)
	var t: float = position - float(i0)
	var port: float = lerpf(_depths[i0 * columns], _depths[(i0 + 1) * columns], t)
	var starboard: float = lerpf(_depths[i0 * columns + columns - 1], _depths[(i0 + 1) * columns + columns - 1], t)
	var half_width: float = 0.5 * _width_at(from_transom)
	if half_width < 1e-6:
		return Vector2(1.0, 0.0)
	# depth(y) = middle + slope * y across the flat bottom, from the two rail depths, less
	# the vee's rise toward the rail on each half: two planes that meet at the keel.
	var middle: float = 0.5 * (port + starboard)
	var slope: float = (starboard - port) / (2.0 * half_width)
	# The deepest point of the section: the keel, or the low rail when the heel is more
	# than the vee. The water climbs from there: the depth the water sees is the deepest
	# depth less 2/pi of how far each point is above it (WAGNER_CUT), which is the same two
	# planes with 2/pi of their slopes. On a level vee that is the keel's depth and the
	# vee's wetting slope (_vee_wetting_per_m) exactly, as before.
	var port_rail: float = middle - (slope + _vee_rise_per_m) * half_width
	var starboard_rail: float = middle + (slope - _vee_rise_per_m) * half_width
	var deepest: float = maxf(middle, maxf(port_rail, starboard_rail))
	var climbed_middle: float = deepest - WAGNER_CUT * (deepest - middle)
	var climbed_slope: float = WAGNER_CUT * slope
	var port_half: Vector3 = _wet_part(climbed_middle, climbed_slope + _vee_wetting_per_m, -half_width, 0.0)
	var starboard_half: Vector3 = _wet_part(climbed_middle, climbed_slope - _vee_wetting_per_m, 0.0, half_width)
	var wet_width: float = port_half.x + starboard_half.x
	var area: float = port_half.y + starboard_half.y
	if wet_width <= 0.0 or area <= 1e-9:
		return Vector2(0.0, 0.0)
	return Vector2(wet_width / (2.0 * half_width), (port_half.z + starboard_half.z) / area)


## The wet part of one piece of a section, from a to b across the board (body x), whose
## depth below the water is middle + slope * y: x = its wet width, y = the integral of the
## depth over it, z = that integral's moment about the keel.
func _wet_part(middle: float, slope: float, a: float, b: float) -> Vector3:
	if absf(slope) > 1e-9:
		var waterline: float = -middle / slope  # where the depth crosses zero
		if slope > 0.0:
			a = maxf(a, waterline)
		else:
			b = minf(b, waterline)
	if b <= a:
		return Vector3.ZERO
	var area: float = middle * (b - a) + 0.5 * slope * (b * b - a * a)
	if area <= 0.0:
		return Vector3.ZERO
	var moment: float = 0.5 * middle * (b * b - a * a) + slope * (b * b * b - a * a * a) / 3.0
	return Vector3(b - a, area, moment)


## Width of the bottom at a distance forward of the transom: the board's outline less any
## tail cut-outs, the same one the buoyancy grid uses (BoardConfig.bottom_width_at).
func _width_at(from_transom: float) -> float:
	return board.bottom_width_at(from_transom)


## Mean width of the bottom between two points along the length (9-point average).
func _mean_width(aft: float, forward: float) -> float:
	var total: float = 0.0
	for k: int in 9:
		total += _width_at(lerpf(aft, forward, float(k) / 8.0))
	return total / 9.0


## Heave added mass and pitch added inertia of the wet bottom, from strip theory: each metre
## of a flat bottom of width b on the surface drags rho pi b^2 / 8 of water with it when it
## moves up or down. Summed over the wet length, and with the lever arm squared about the
## centre of mass for pitch. Sideways, the hull's immersed side to its draft d drags
## rho pi d^2 / 2 per metre (sway_added_mass_kg), and about the yaw axis that water times
## the lever squared.
func _compute_added_mass(aft: float, forward: float, com_offset_z_m: float) -> void:
	heave_added_mass_kg = 0.0
	pitch_added_inertia_kgm2 = 0.0
	roll_added_inertia_kgm2 = 0.0
	sway_added_mass_kg = 0.0
	yaw_added_inertia_kgm2 = 0.0
	var length: float = forward - aft
	if length <= 0.0:
		return
	var com_from_transom: float = 0.5 * _length_m - com_offset_z_m
	var strips: int = 8
	var strip_length: float = length / float(strips)
	for k: int in strips:
		var x: float = aft + (float(k) + 0.5) * strip_length
		var width: float = _width_at(x)
		var lever: float = x - com_from_transom
		var strip_mass: float = _density_kg_m3 * PI * width * width / 8.0 * strip_length
		heave_added_mass_kg += strip_mass
		pitch_added_inertia_kgm2 += strip_mass * lever * lever
		roll_added_inertia_kgm2 += _density_kg_m3 * PI * pow(width, 4.0) / 256.0 * strip_length
		var draft: float = clampf(_draft_at(x), 0.0, _thickness_m)
		var side_mass: float = _density_kg_m3 * PI * draft * draft / 2.0 * strip_length
		sway_added_mass_kg += side_mass
		yaw_added_inertia_kgm2 += side_mass * lever * lever


## How deep the hull is at a distance forward of the transom: the deepest point of the
## buoyancy grid's rows there (the low rail of a heeled board), between the two nearest
## rows.
func _draft_at(from_transom: float) -> float:
	var rows: int = maxi(_length_samples, 2)
	var spacing: float = _length_m / float(rows - 1)
	var position: float = clampf(from_transom / spacing, 0.0, float(rows - 1))
	var i0: int = mini(int(floor(position)), rows - 2)
	return lerpf(_row_max_depth(i0), _row_max_depth(i0 + 1), position - float(i0))


## Height of the bottom in body axes at a distance forward of the transom (the same rocker
## line the buoyancy grid uses).
func _bottom_y(from_transom: float) -> float:
	return -0.5 * _thickness_m + board.bottom_rise_m(from_transom)


## Angle of the chord of the wet bottom to the board's reference plane, positive when the
## forward end is higher (bow up).
func _chord_angle(aft: float, forward: float) -> float:
	return atan((board.bottom_rise_m(forward) - board.bottom_rise_m(aft)) / maxf(forward - aft, 0.05))


## How much faster than in steady planing the spray root runs onto the bottom when that
## part of the hull also sinks (down_speed_ms > 0, through the surface) or rises: a
## bottom at an angle to the water wets a further sink / tan(angle) of its length. Held
## between 0 (rising faster than the water follows) and spray_root_factor_max, and the
## angle at one degree or more (PHYSICS_SPEC.md section 16).
func _root_advance_factor(down_speed_ms: float, u: float, bottom_angle: float) -> float:
	var advance_ms: float = down_speed_ms / tan(maxf(bottom_angle, MIN_SPRAY_ROOT_ANGLE_RAD))
	return clampf(1.0 + advance_ms / u, 0.0, _spray_root_factor_max)


## How much further forward the keel of a vee bottom is wet than its chines, Savitsky's
## (1964) L_k - L_c = b tan(beta) / (pi tan(tau)): the water piled up the vee reaches the
## chines where the keel is b tan(beta) / pi deep. At the trim of the wet span's chord, at
## least one degree (as the lift's reference trim), and no longer than the wet span.
func _chine_dry_length(aft: float, forward: float) -> float:
	var length: float = forward - aft
	if length <= 0.0 or _vee_rise_per_m <= 0.0:
		return 0.0
	var trim: float = maxf(_body.pitch_rad() + _chord_angle(aft, forward), MIN_SPRAY_ROOT_ANGLE_RAD)
	var beam: float = planing_beam_m * maxf(cos(_body.heel_rad()), 0.3)
	return minf(beam * _vee_rise_per_m / (PI * tan(trim)), length)


## Savitsky's wetted length-to-beam ratio for the bottom as a rolled flat plate (NACA TN
## 4187, Savitsky, Prowse and Lueders 1958): the mean wetted length of the two rails over the
## beam. The high rail is dry over 2 b tan(heel) / (pi tan(trim)) more of the length than the
## low one (equation 2, figure 23: Wagner's climb across the heeled bottom), on top of the
## vee's chine-dry part; the wet bottom is then a trapezoid, or a triangle once the high rail
## is dry back to the transom. The trim is the wet chord's, at least one degree, as for the
## chine-dry length.
func _rolled_plate_lambda(aft: float, forward: float, beam: float, heel: float) -> float:
	var length: float = forward - aft
	var trim: float = maxf(_body.pitch_rad() + _chord_angle(aft, forward), MIN_SPRAY_ROOT_ANGLE_RAD)
	var dry: float = chine_dry_length_m + 2.0 * beam * tan(absf(heel)) / (PI * tan(trim))
	var mean_length: float = length - 0.5 * dry if dry < length else 0.5 * length * length / dry
	return clampf(mean_length / beam, 0.2, _length_m / beam)


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


## Savitsky's porpoising limit: the trim (degrees) above which a planing hull starts to
## porpoise, for its load coefficient C_L = load / (0.5 rho V^2 b^2) and its deadrise.
## A planing hull porpoises above a critical trim that falls as the load coefficient falls,
## so as the speed rises (Day and Haag 1952, Savitsky 1964 figure 21). The chart as fitted
## in OpenPlaning (Castro-Feliciano, python-openplaning, `check_porpoising`): one cubic in
## x = sqrt(C_L / 2) for each of 0, 10 and 20 degrees of deadrise, and a quadratic through
## the three for the deadrise in between. The chart covers x = 0.13 to 0.3. A planing
## board is lighter for its width than any boat on the chart (x = 0.09 to 0.13 on the
## reaches), so there the fit is extrapolated as OpenPlaning does it, down to x = 0.07,
## where the cubic for a flat bottom has its lowest point and would turn up again (which
## the chart does not show). Above x = 0.3 (a slow, heavy hull) it is held at x = 0.3.
static func critical_trim_deg_for(load_n: float, speed_ms: float, beam_m: float, deadrise_deg: float, rho: float) -> float:
	if speed_ms <= 0.0 or beam_m <= 0.0:
		return 90.0
	var c_l: float = load_n / (0.5 * rho * speed_ms * speed_ms * beam_m * beam_m)
	var x: float = clampf(sqrt(maxf(c_l, 0.0) / 2.0), 0.07, 0.3)
	var tau_0: float = ((-376.37 * x + 329.74) * x - 38.485) * x + 1.3415
	var tau_10: float = ((-356.05 * x + 314.36) * x - 41.674) * x + 3.5786
	var tau_20: float = ((-254.51 * x + 239.65) * x - 23.936) * x + 3.0195
	# The quadratic through the three deadrises (0, 10 and 20 degrees), at this one.
	var b: float = deadrise_deg
	return tau_0 * (b - 10.0) * (b - 20.0) / 200.0 - tau_10 * b * (b - 20.0) / 100.0 + tau_20 * b * (b - 10.0) / 200.0


func _clear() -> void:
	friction_n = 0.0
	residuary_n = 0.0
	lateral_n = 0.0
	resistance_n = 0.0
	planing_lift_n = 0.0
	planing_normal_force_n = 0.0
	planing_pull_n = 0.0
	clipped_force_world = Vector3.ZERO
	clipped_torque_world = Vector3.ZERO
	planing_drag_n = 0.0
	bow_drag_n = 0.0
	rail_grip_n = 0.0
	rail_yaw_nm = 0.0
	planing_ratio = 0.0
	hull_load_n = 0.0
	planing_share = 0.0
	critical_trim_deg = 90.0
	trim_deg = 0.0
	wetted_length_m = 0.0
	wetted_aft_m = 0.0
	planing_beam_m = 0.0
	friction_area_m2 = 0.0
	heave_added_mass_kg = 0.0
	pitch_added_inertia_kgm2 = 0.0
	roll_added_inertia_kgm2 = 0.0
	sway_added_mass_kg = 0.0
	yaw_added_inertia_kgm2 = 0.0
	spray_root_factor = 1.0
	buoyancy_correction_n = 0.0
	chine_dry_length_m = 0.0
	lambda_ratio = 0.0
	froude_number = 0.0
	reynolds_number = 0.0
	forward_speed_ms = 0.0
