extends SceneTree
## The hull's planing lift in prescribed steady states: a diagnosis tool of U2 (agent 6,
## `hull_lift`; PLAYTEST_UPGRADES.md, "The hull's lift under heel: the diagnosis"). It
## changes nothing in the game and steers nothing.
##
## It builds the simulation the way the game does (WindsurferSim.create_default(): the
## default board, flat still water) and holds the hull as a rigid body that does not turn,
## moving level at a forward speed with a trim (the board's pitch, bow up) and a heel (the
## port rail down, as on the 18 kt beam reach), at the height where the wet length
## (HullModel.wetted_length_m, the low rail's) is the one asked for. Then it runs the
## buoyancy and the hull models once, as one substep of WindsurferSim.step does, and prints
## what the hull model gives. The steps between the strip theory and the force are local
## variables of HullModel._apply_planing_lift, so the probe recomputes them from the same
## inputs with the model's own helpers: Savitsky's lift, the slender reference, the 3D
## factor, the spray root's force, the strips' sum before and after the transom relief and
## the clipping. The column `chk` is the recomputed normal force over the model's own: 1.000
## says the recomputation is the model.
##
## Two what-ifs, computed here only (the model is not changed):
##   wag  the water climbs the heeled bottom pi/2 times as far from the low rail as the
##        still surface cuts it (Wagner 1932), as HullModel already does for the vee;
##   wet  the 3D factor anchored on the widest *wet* strip instead of the widest full width,
##        so the strip theory's total is Savitsky's at every heel;
##   tn   that, scaled to the lift of a rolled flat plate as NACA TN 4187 has it (Savitsky,
##        Prowse and Lueders 1958): Savitsky's lift at the mean wetted length, with the high
##        rail dry over 2 b tan(heel) / (pi tan(trim)) (its equation 2, Wagner's climb) and
##        the heel as an effective deadrise (its "effective deadrise increased").
##
## Run from the repo root (Git Bash):
##   tools/godot.sh --path Game --headless -s res://dev/hull_probe.gd
##   tools/godot.sh --path Game --headless -s res://dev/hull_probe.gd -- --speed=12.7 --trims=1.3,1.5,2 --heels=0,2,4.5,8 --lengths=1,1.4,1.76
## --slip_deg=<deg> moves the hull sideways toward its low rail at that angle (the leeway; 0
## by default, about 2 on the 18 kt beam reach), and with --load=<N> (for instance 597, the hull's load on the 18 kt beam reach) it also
## prints, per trim and heel, the wet length that carries that load (planing lift plus
## buoyancy) with today's model and with each what-if.

const STRIPS: int = HullModel.STRIPS
const WAGNER: float = 2.0 / PI  # the still-surface cut over the wetted reach

var _options: Dictionary[String, String] = {}
var _sim: WindsurferSim
var _speed_ms: float = 12.7
var _slip_rad: float = 0.0


func _initialize() -> void:
	_options = _read_user_args()
	_speed_ms = _options.get("speed", "12.7").to_float()
	_slip_rad = deg_to_rad(_options.get("slip_deg", "0").to_float())
	var trims: PackedFloat64Array = _number_list(_options.get("trims", "1.3,1.5,2"))
	var heels: PackedFloat64Array = _number_list(_options.get("heels", "0,2,4.5,8"))
	var lengths: PackedFloat64Array = _number_list(_options.get("lengths", "1,1.4,1.76"))
	_sim = WindsurferSim.create_default()
	print("Hull probe: %.2f m/s, slip %.1f deg toward the low rail, flat still water, the hull alone held at a trim and a heel; forces in N, lengths in m" % [_speed_ms, rad_to_deg(_slip_rad)])
	print("trim heel  L    | lift  buoy | lam   tauref beam  | Sav   slend  3D    | root  strip0 strip1 clip  | sum/sl chk   | chdry wmax  wwag  hidry | Lwag  Lwet  Ltn")
	for trim_deg: float in trims:
		for heel_deg: float in heels:
			for length_m: float in lengths:
				var h: float = _height_for_length(trim_deg, heel_deg, length_m)
				var r: Dictionary[String, float] = _evaluate(trim_deg, heel_deg, h)
				print(_format(trim_deg, heel_deg, r))
	print("lift/buoy = the model's planing lift (vertical) and buoyancy; lam = lambda_ratio; tauref = the reference trim (deg); beam = planing_beam_m x cos(heel); Sav = Savitsky's lift (normal) at lam, tauref and beam, the 3D anchor; slend = the slender reference (widest full width); 3D = Sav / slend; root = the spray root's 2D force; strip0 = the strips' 2D sum before the transom relief, strip1 after it; clip = what the clipping of pulling strips adds back; sum/sl = the 2D total (root + strips, relieved, clipped) over slend, so the model's normal force over Sav; chk = recomputed over the model's normal force; chdry = the vee's chine-dry length; wmax = the widest wet strip (the model's wet width); wwag = the same with Wagner's climb on the heeled bottom; hidry = how far the high rail is dry from the low rail's front (still surface); Lwag / Lwet / Ltn = the planing lift (vertical) with the what-ifs wag / wet / tn.")
	if _options.has("load"):
		_print_load_table(_options["load"].to_float(), trims, heels)
	quit(0)


## Puts the hull at a trim and heel with its origin at a height, and runs one step of the
## buoyancy and the hull models on it.
func _place_and_compute(trim_deg: float, heel_deg: float, height_m: float) -> void:
	var body: SimRigidBody = _sim.body
	# Heel about the board's own long axis (a rotation about +z by +heel puts the port rail
	# down), then the bow up by the trim.
	body.basis = Basis(Vector3.RIGHT, deg_to_rad(trim_deg)) * Basis(Vector3.BACK, deg_to_rad(heel_deg))
	body.set_origin_world(Vector3(0.0, height_m, 0.0))
	# Level motion, bow first (heading North), no rotation: the flow meets the bottom at the
	# trim. A slip moves the hull sideways toward its low rail (port), as the leeway does on
	# the beam reach.
	body.velocity = Vector3(-_speed_ms * sin(_slip_rad), 0.0, -_speed_ms * cos(_slip_rad))
	body.angular_velocity = Vector3.ZERO
	body.internal_velocity = Vector3.ZERO
	body.clear_forces()
	_sim.buoyancy.apply(body, _sim.water, 0.0, _sim.sim_config.gravity_ms2)
	_sim.hull.compute(body, _sim.buoyancy, _sim.water, 0.0, _sim.sim_config.gravity_ms2, _sim.mass_model.total_mass_kg)


## The board origin's height at which the hull model's wet length is the one asked for.
func _height_for_length(trim_deg: float, heel_deg: float, length_m: float) -> float:
	var low: float = -0.3  # deep: the whole bottom is wet
	var high: float = 0.3  # high: the bottom is dry
	for i: int in 60:
		var middle: float = 0.5 * (low + high)
		_place_and_compute(trim_deg, heel_deg, middle)
		if _sim.hull.wetted_length_m > length_m:
			low = middle
		else:
			high = middle
	return 0.5 * (low + high)


## The height at which planing lift (today's, or a what-if's) plus buoyancy is the load.
func _height_for_load(trim_deg: float, heel_deg: float, load_n: float, lift_key: String) -> float:
	var low: float = -0.1
	var high: float = 0.2
	for i: int in 50:
		var middle: float = 0.5 * (low + high)
		var r: Dictionary[String, float] = _evaluate(trim_deg, heel_deg, middle)
		if r[lift_key] + r["buoyancy"] > load_n:
			low = middle
		else:
			high = middle
	return 0.5 * (low + high)


## One case: the model's results and the recomputed steps.
func _evaluate(trim_deg: float, heel_deg: float, height_m: float) -> Dictionary[String, float]:
	_place_and_compute(trim_deg, heel_deg, height_m)
	var hull: HullModel = _sim.hull
	var r: Dictionary[String, float] = {}
	r["lift"] = hull.planing_lift_n
	r["normal"] = hull.planing_normal_force_n
	r["buoyancy"] = _sim.buoyancy.buoyancy_force_n
	r["length"] = hull.wetted_length_m
	r["aft"] = hull.wetted_aft_m
	r["lambda"] = hull.lambda_ratio
	r["chine_dry"] = hull.chine_dry_length_m
	r["high_dry"] = _high_rail_dry_length()
	var today: Dictionary[String, float] = _strip_theory(false, false)
	for key: String in today:
		r[key] = today[key]
	r["chk"] = today["normal_sum"] / hull.planing_normal_force_n if hull.planing_normal_force_n > 0.0 else 0.0
	var wagner: Dictionary[String, float] = _strip_theory(true, false)
	r["lift_wag"] = wagner["vertical_sum"]
	r["wmax_wag"] = wagner["wmax"]
	r["lift_wet"] = _strip_theory(false, true)["vertical_sum"]
	r["lift_tn"] = r["lift_wet"] * _rolled_plate_ratio(r["tau_ref"], r["beam"])
	return r


## HullModel._apply_planing_lift's steps 1 to 6 on the state of the last compute(), with the
## model's own helpers. wagner_heel: the what-if of Wagner's climb on the heeled bottom;
## wet_reference: the what-if of the slender reference on the widest wet strip.
func _strip_theory(wagner_heel: bool, wet_reference: bool) -> Dictionary[String, float]:
	var hull: HullModel = _sim.hull
	var body: SimRigidBody = _sim.body
	var buoyancy: BuoyancyModel = _sim.buoyancy
	var board: BoardConfig = _sim.board_config
	var water: WaterSurface = _sim.water
	var rho: float = _sim.water_config.density_kg_m3
	var out: Dictionary[String, float] = {}
	var u: float = hull.forward_speed_ms
	var length: float = hull.wetted_length_m
	var aft: float = hull.wetted_aft_m
	var forward: float = aft + length
	var strip_length: float = length / float(STRIPS)
	var pitch: float = SimMath.pitch_rad(body.basis)
	var heel: float = SimMath.heel_rad(body.basis)
	var beam: float = hull.planing_beam_m * maxf(cos(heel), 0.3)
	out["beam"] = beam
	var trim_geometric: float = pitch + hull._chord_angle(aft, forward) + 2.0 * hull._camber_sag(aft, forward) / length

	# Step 1, the strips.
	var x_k: PackedFloat64Array = PackedFloat64Array()
	var normals: PackedVector3Array = PackedVector3Array()
	var v_into: PackedFloat64Array = PackedFloat64Array()
	var m_per_m: PackedFloat64Array = PackedFloat64Array()
	var full_widths: PackedFloat64Array = PackedFloat64Array()
	var fractions: PackedFloat64Array = PackedFloat64Array()
	var sink: PackedFloat64Array = PackedFloat64Array()
	var wmax: float = 0.0
	for k: int in STRIPS:
		var x: float = aft + (float(k) + 0.5) * strip_length
		var normal_world: Vector3 = SimMath.to_world(body.basis, Vector3(0.0, 1.0, board.bottom_slope(x)).normalized())
		var wet: Vector2 = hull._wet_width(buoyancy, x)
		if wagner_heel:
			wet.x = _wagner_wet_fraction(x)
		var point_world: Vector3 = body.point_world(Vector3(wet.y, hull._bottom_y(x), 0.5 * board.length_m - x))
		var v_rel: Vector3 = body.point_velocity(point_world) - water.velocity_at(point_world.x, point_world.z, 0.0)
		var full_width: float = board.width_at(x)
		var width: float = full_width * wet.x
		wmax = maxf(wmax, width)
		x_k.append(x)
		normals.append(normal_world)
		v_into.append(-v_rel.dot(normal_world))
		m_per_m.append(rho * PI * width * width / 8.0)
		full_widths.append(full_width)
		fractions.append(wet.x)
		sink.append(-v_rel.dot(water.normal_at(point_world.x, point_world.z, 0.0)))
	out["wmax"] = wmax

	# Step 2, along the hull: the strips' 2D forces before and after the transom relief.
	var strip_forces: PackedFloat64Array = PackedFloat64Array()
	var strip0: float = 0.0
	var strip1: float = 0.0
	for k: int in STRIPS:
		var k0: int = maxi(k - 1, 0)
		var k1: int = mini(k + 1, STRIPS - 1)
		var dv_dx: float = (v_into[k1] - v_into[k0]) / (float(k1 - k0) * strip_length)
		var force: float = -u * m_per_m[k] * dv_dx * strip_length
		var advance: float = hull._root_advance_factor(sink[k], u, pitch + board.bottom_slope(x_k[k]))
		for j: int in [k - 1, k]:
			if j < 0 or j >= STRIPS - 1:
				continue
			var gain_kg_m: float = m_per_m[j] - m_per_m[j + 1]
			var wetting_gain_kg_m: float = rho * PI / 8.0 * full_widths[k] * full_widths[k] * (fractions[j] * fractions[j] - fractions[j + 1] * fractions[j + 1])
			var gain: float = gain_kg_m + (advance - 1.0) * wetting_gain_kg_m
			if gain > 0.0:
				force += 0.5 * u * v_into[k] * gain
		var relief: float = clampf((x_k[k] - aft) / (HullModel.TRANSOM_RELIEF_BEAMS * beam), 0.0, 1.0)
		strip0 += force
		strip1 += force * relief
		strip_forces.append(force * relief)
	out["strip0"] = strip0
	out["strip1"] = strip1

	# Step 3, the spray root.
	var last: int = STRIPS - 1
	var v_root: float = v_into[last] + 0.5 * (v_into[last] - v_into[last - 1])
	var root_world: Vector3 = body.point_world(Vector3(hull._wet_width(buoyancy, forward).y, hull._bottom_y(forward), 0.5 * board.length_m - forward))
	var root_down: float = -(body.point_velocity(root_world) - water.velocity_at(root_world.x, root_world.z, 0.0)).dot(water.normal_at(root_world.x, root_world.z, 0.0))
	var root_factor: float = hull._root_advance_factor(root_down, u, pitch + board.bottom_slope(forward))
	var root_force: float = maxf(u * root_factor * m_per_m[last] * v_root, 0.0)
	out["root"] = root_force

	# Step 4, the 3D anchor.
	var tau_ref_deg: float = maxf(rad_to_deg(trim_geometric), 1.0)
	out["tau_ref"] = tau_ref_deg
	var cl_flat: float = 0.012 * pow(minf(tau_ref_deg, 15.0), 1.1) * sqrt(hull.lambda_ratio)
	var cl_dynamic: float = maxf(cl_flat - 0.0065 * board.deadrise_deg * pow(cl_flat, 0.6), 0.0)
	var savitsky: float = cl_dynamic * 0.5 * rho * u * u * beam * beam
	var reference_width: float = 0.0
	for k: int in STRIPS:
		reference_width = maxf(reference_width, full_widths[k] * fractions[k] if wet_reference else full_widths[k])
	var slender: float = rho * PI * reference_width * reference_width / 8.0 * u * u * sin(deg_to_rad(tau_ref_deg))
	var three_d: float = savitsky / maxf(slender, 1e-6)
	out["savitsky"] = savitsky
	out["slender"] = slender
	out["three_d"] = three_d

	# Steps 5 and 6: the root's force spread behind it, and no strip pulling.
	var cv: float = u / sqrt(_sim.sim_config.gravity_ms2 * beam)
	var cop_fraction: float = 0.75 - 1.0 / (5.21 * cv * cv / (hull.lambda_ratio * hull.lambda_ratio) + 2.39)
	var spread: float = maxf(3.0 * (1.0 - cop_fraction) * length, strip_length)
	var weights: PackedFloat64Array = PackedFloat64Array()
	var weight_sum: float = 0.0
	for k: int in STRIPS:
		weights.append(maxf(1.0 - (forward - x_k[k]) / spread, 0.0))
		weight_sum += weights[k]
	var unclipped: float = 0.0
	var clipped: float = 0.0
	var vertical: float = 0.0
	for k: int in STRIPS:
		var share: float = root_force * weights[k] / weight_sum if weight_sum > 0.0 else 0.0
		var two_d: float = strip_forces[k] + share
		unclipped += two_d
		clipped += maxf(two_d, 0.0)
		vertical += three_d * maxf(two_d, 0.0) * normals[k].y
	out["clip"] = clipped - unclipped
	out["two_d_sum"] = clipped
	out["normal_sum"] = three_d * clipped
	out["vertical_sum"] = vertical
	out["sum_over_slender"] = clipped / maxf(slender, 1e-6)
	return out


## Savitsky's lift coefficient of a rolled flat plate (NACA TN 4187) over the one the model
## anchors to, at the same low-rail wet length and trim. The rolled plate's high rail is dry
## over 2 b tan(heel) / (pi tan(trim)) more than its low rail (TN 4187 equation 2, Wagner's
## climb; the trim of the wet span's chord, as HullModel's chine-dry length), added to the
## vee's chine-dry length; its mean wetted length is the wet area over the beam (a
## trapezoid, or a triangle once the high rail is dry to the transom); and the heel acts as
## a deadrise (TN 4187: "the effective deadrise of the surface is increased").
func _rolled_plate_ratio(tau_ref_deg: float, beam: float) -> float:
	var hull: HullModel = _sim.hull
	var board: BoardConfig = _sim.board_config
	var heel_deg: float = absf(rad_to_deg(SimMath.heel_rad(_sim.body.basis)))
	var length: float = hull.wetted_length_m
	var trim: float = maxf(SimMath.pitch_rad(_sim.body.basis) + hull._chord_angle(hull.wetted_aft_m, hull.wetted_aft_m + length), deg_to_rad(1.0))
	var dry: float = hull.chine_dry_length_m + 2.0 * beam * tan(deg_to_rad(heel_deg)) / (PI * tan(trim))
	var mean_length: float = length - 0.5 * dry if dry < length else 0.5 * length * length / dry
	var lambda_rolled: float = clampf(mean_length / beam, 0.2, board.length_m / beam)
	var rolled: float = _savitsky_cl(tau_ref_deg, lambda_rolled, maxf(board.deadrise_deg, heel_deg))
	var anchored: float = _savitsky_cl(tau_ref_deg, hull.lambda_ratio, board.deadrise_deg)
	return rolled / anchored if anchored > 0.0 else 0.0


## Savitsky's (1964) dynamic lift coefficient, as HullModel's step 4.
func _savitsky_cl(tau_deg: float, lambda_value: float, deadrise_deg: float) -> float:
	var cl_flat: float = 0.012 * pow(minf(tau_deg, 15.0), 1.1) * sqrt(lambda_value)
	return maxf(cl_flat - 0.0065 * deadrise_deg * pow(cl_flat, 0.6), 0.0)


## The wet fraction of a strip's width if the water climbs the heeled bottom pi/2 times as
## far from its deepest point as the still surface cuts it (Wagner 1932): the depth across
## the bottom, d(y), becomes (1 - 2/pi) d_max + 2/pi d(y), wet where it is positive. On a
## level vee that is HullModel's own vee wetting exactly; on a heeled flat bottom it is the
## water climbing from the low rail. The same rail depths as HullModel._wet_width.
func _wagner_wet_fraction(from_transom: float) -> float:
	var hull: HullModel = _sim.hull
	var board: BoardConfig = _sim.board_config
	var depths: PackedFloat64Array = _sim.buoyancy.point_depths_m
	var rows: int = maxi(board.length_samples, 2)
	var columns: int = maxi(board.width_samples, 1)
	var spacing: float = board.length_m / float(rows - 1)
	var position: float = clampf(from_transom / spacing, 0.0, float(rows - 1))
	var i0: int = mini(int(floor(position)), rows - 2)
	var t: float = position - float(i0)
	var port: float = lerpf(depths[i0 * columns], depths[(i0 + 1) * columns], t)
	var starboard: float = lerpf(depths[i0 * columns + columns - 1], depths[(i0 + 1) * columns + columns - 1], t)
	var half_width: float = 0.5 * board.width_at(from_transom)
	if half_width < 1e-6:
		return 1.0
	var middle: float = 0.5 * (port + starboard)
	var slope: float = (starboard - port) / (2.0 * half_width)
	var vee: float = hull._vee_rise_per_m
	var deepest: float = maxf(middle, maxf(middle - (slope + vee) * half_width, middle + (slope - vee) * half_width))
	var climbed_middle: float = (1.0 - WAGNER) * deepest + WAGNER * middle
	var port_half: Vector3 = hull._wet_part(climbed_middle, WAGNER * (slope + vee), -half_width, 0.0)
	var starboard_half: Vector3 = hull._wet_part(climbed_middle, WAGNER * (slope - vee), 0.0, half_width)
	return clampf((port_half.x + starboard_half.x) / (2.0 * half_width), 0.0, 1.0)


## How far aft of the low rail's wet front the high rail is still dry (still surface, the
## buoyancy grid's rail depths with the vee's rise): the low rail's wet length less the high
## rail's. Zero for a level board.
func _high_rail_dry_length() -> float:
	var hull: HullModel = _sim.hull
	if absf(SimMath.heel_rad(_sim.body.basis)) < 1e-4:
		return 0.0
	var high_side: float = 1.0 if SimMath.heel_rad(_sim.body.basis) < 0.0 else -1.0
	var forward: float = hull.wetted_aft_m + hull.wetted_length_m
	var x: float = forward
	while x > hull.wetted_aft_m and hull._rail_depth(_sim.buoyancy, x, high_side) <= 0.0:
		x -= 0.005
	return forward - maxf(x, hull.wetted_aft_m)


func _format(trim_deg: float, heel_deg: float, r: Dictionary[String, float]) -> String:
	return "%4.2f %4.1f %4.2f | %4.0f %4.0f | %5.2f %5.2f %5.3f | %5.0f %5.0f %5.3f | %4.0f %6.1f %6.1f %5.1f | %5.3f %5.3f | %5.3f %5.3f %5.3f %5.2f | %4.0f %4.0f %4.0f" % [
		trim_deg, heel_deg, r["length"], r["lift"], r["buoyancy"],
		r["lambda"], r["tau_ref"], r["beam"],
		r["savitsky"], r["slender"], r["three_d"],
		r["root"], r["strip0"], r["strip1"], r["clip"],
		r["sum_over_slender"], r["chk"],
		r["chine_dry"], r["wmax"], r["wmax_wag"], r["high_dry"],
		r["lift_wag"], r["lift_wet"], r["lift_tn"]]


## Per trim and heel: the wet length that carries the load, today and with the what-ifs.
func _print_load_table(load_n: float, trims: PackedFloat64Array, heels: PackedFloat64Array) -> void:
	print("Wet length (m) that carries %.0f N (planing lift + buoyancy), and the split there (lift/buoyancy, N):" % load_n)
	print("trim heel | today            | wag (Wagner on the heel) | wet (3D on the wet width) | tn (rolled plate, TN 4187)")
	for trim_deg: float in trims:
		for heel_deg: float in heels:
			var line: String = "%4.2f %4.1f" % [trim_deg, heel_deg]
			for key: String in ["lift", "lift_wag", "lift_wet", "lift_tn"]:
				var h: float = _height_for_load(trim_deg, heel_deg, load_n, key)
				var r: Dictionary[String, float] = _evaluate(trim_deg, heel_deg, h)
				line += " | %4.2f m %4.0f/%4.0f" % [r["length"], r[key], r["buoyancy"]]
			print(line)


func _number_list(text: String) -> PackedFloat64Array:
	var values: PackedFloat64Array = PackedFloat64Array()
	for part: String in text.split(",", false):
		values.append(part.to_float())
	return values


func _read_user_args() -> Dictionary[String, String]:
	var options: Dictionary[String, String] = {}
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--") and arg.contains("="):
			var parts: PackedStringArray = arg.trim_prefix("--").split("=", true, 1)
			options[parts[0]] = parts[1]
	return options
