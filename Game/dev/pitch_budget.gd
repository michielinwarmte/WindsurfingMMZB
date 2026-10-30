extends SceneTree
## The pitch budget of a steady reach (PH16): what holds the board's nose down and what lifts
## it, force by force. It changes nothing in the game and steers nothing.
##
## It sails one case of the reach check (flat water, steady wind; run_reach.gd sets it up the
## same way), and over the last seconds it takes every substep apart: it runs the same calls as
## WindsurferSim.step, in the same order, and reads the hull's torque sum after each one, so each
## model's share of the hull's pitch moment is known (the answers are the same to the last bit:
## nothing is computed twice). Two views are printed, as means over the window:
##   1. the hull alone, about its centre of mass: the water, the fin, the mast foot, the feet
##      (their force and the moment they pass), the sailor's attachment across the deck;
##   2. the whole windsurfer (hull, sailor and rig), about the centre of the water's push on
##      the hull: the sail's force, the sailor's windage, the three weights, the fin. In a
##      steady run they add up to nothing, and the size of each says what sets the trim.
## Positions are in metres forward of the tail and up from the bottom of the hull. A positive
## moment lifts the bow.
##
## Run from the repo root (Git Bash):
##   tools/godot.sh --path Game --headless -s res://dev/pitch_budget.gd -- --wind=18 --twa=100
## Section 4 of the print is the power each force model puts into the hull's oscillation over the
## window (the mean of its pitch moment's swing times the pitch rate's, and of its vertical force's
## swing times the vertical speed's): + pumps a bounce, - damps it (PH16 step 18).
## Options: --seconds=40 --window=5 and any --pilot.<field>= --sailor.<field>= --sail.<field>=
## --board.<field>= --fin.<field>= override, as in the reach check.

const DT: float = 1.0 / 60.0

var _options: Dictionary[String, String] = {}
var _stages: PackedStringArray = PackedStringArray(["gravity", "buoyancy", "hull water", "fin", "mast foot", "feet (force + moment)", "attachment"])
var _stage_pitch: PackedFloat64Array = PackedFloat64Array()
## The same, about the hull's up axis (yaw; + turns the bow to port): what the rake steers against.
var _stage_yaw: PackedFloat64Array = PackedFloat64Array()
var _samples: int = 0
var _means: Dictionary[String, float] = {}
## What feeds a bounce: per stage, the sums for the covariance of its pitch moment with the
## hull's pitch rate and of its vertical force with the hull's vertical speed. The mean of
## M' q' is the power the stage puts into the pitch oscillation (positive: it pumps the bounce,
## negative: it damps it); F' w' the same for the heave.
var _stage_m: PackedFloat64Array = PackedFloat64Array()
var _stage_mq: PackedFloat64Array = PackedFloat64Array()
var _stage_f: PackedFloat64Array = PackedFloat64Array()
var _stage_fw: PackedFloat64Array = PackedFloat64Array()
var _sum_q: float = 0.0
var _sum_qq: float = 0.0
var _sum_w: float = 0.0
var _sum_ww: float = 0.0
var _power_samples: int = 0


func _initialize() -> void:
	_options = _read_user_args()
	var wind_kt: float = _options.get("wind", "18").to_float()
	var twa_deg: float = _options.get("twa", "100").to_float()
	var seconds: float = _options.get("seconds", "40").to_float()
	var window_s: float = _options.get("window", "5").to_float()
	_stage_pitch.resize(_stages.size())
	_stage_pitch.fill(0.0)
	_stage_yaw.resize(_stages.size())
	_stage_yaw.fill(0.0)
	# Each on its own: a packed array in an array literal is a copy.
	_stage_m.resize(_stages.size())
	_stage_m.fill(0.0)
	_stage_mq.resize(_stages.size())
	_stage_mq.fill(0.0)
	_stage_f.resize(_stages.size())
	_stage_f.fill(0.0)
	_stage_fw.resize(_stages.size())
	_stage_fw.fill(0.0)

	var scenario: SimScenario = (load("res://dev/scenarios/beam_reach.gd") as GDScript).new()
	scenario.seconds = seconds
	scenario.wind_kt = wind_kt
	scenario.pilot.target_twa_deg = twa_deg
	var sim: WindsurferSim = _make_sim()
	sim.wind_config = sim.wind_config.duplicate()
	sim.wind_config.speed_kt = wind_kt
	scenario.pilot.sail = sim.sail
	scenario.pilot.sailor = sim.sailor_config
	_apply_overrides({"pilot": scenario.pilot, "sailor": sim.sailor_config, "sail": sim.sail_config})
	sim.wind_config.height_gradient_enabled = false
	sim.wind_config.gusts_enabled = false
	sim.wind_config.shifts_enabled = false
	sim.wind = WindField.new(sim.wind_config)
	sim.set_waves(false)
	sim.reset(Vector3.ZERO, deg_to_rad(scenario.start_heading_deg))
	scenario.setup(sim)

	var steps: int = int(seconds / DT)
	var window_from: int = steps - int(window_s / DT)
	for i: int in steps:
		scenario.update(sim, DT)
		if i < window_from:
			sim.step(DT, scenario.controls)
		else:
			_step_taken_apart(sim, DT, scenario.controls)
		if sim.sailor_state == WindsurferSim.SailorState.FALLEN:
			print("The sailor fell at %.1f s: no budget." % sim.time_s)
			quit(1)
			return
	_print_budget(sim, wind_kt, twa_deg)
	quit(0)


## WindsurferSim.step, call for call, with the hull's torque sum read after each force model.
func _step_taken_apart(sim: WindsurferSim, dt: float, controls: SimControls) -> void:
	sim._copy_configs()
	sim._read_controls(controls)
	var substeps: int = maxi(sim.sim_config.substeps, 1)
	var sub_dt: float = dt / substeps
	for i: int in substeps:
		var body: SimRigidBody = sim.body
		var sailing: bool = sim.sailor_state == WindsurferSim.SailorState.SAILING
		if sailing:
			sim._update_sailor(sub_dt)
		sim.wind.step(sub_dt)
		var marks: Array[Vector3] = [body.torque_sum()]
		var force_marks: Array[Vector3] = [body._force_sum]
		body.add_force(Vector3(0.0, -sim._gravity_ms2 * body.mass_kg, 0.0))
		if sailing:
			sim.sailor.add_force(Vector3(0.0, -sim._gravity_ms2 * sim.sailor.mass_kg, 0.0))
		marks.append(body.torque_sum())
		force_marks.append(body._force_sum)
		sim.buoyancy.apply(body, sim.water, sim.time_s, sim._gravity_ms2, sub_dt)
		marks.append(body.torque_sum())
		force_marks.append(body._force_sum)
		sim.hull.compute(body, sim.buoyancy, sim.water, sim.time_s, sim._gravity_ms2, sim.mass_model.total_mass_kg, sub_dt)
		marks.append(body.torque_sum())
		force_marks.append(body._force_sum)
		var heave_added_mass_kg: float = sim.hull.heave_added_mass_kg
		var inertia_with_water: Basis = sim._inertia_with_added_water(sim._hull_inertia_body)
		body.take_water_along(heave_added_mass_kg, inertia_with_water)
		body.set_added_mass_up(heave_added_mass_kg)
		var sway_added_mass_kg: float = sim._sway_added_mass_kg()
		body.take_water_along_sideways(sway_added_mass_kg)
		body.set_added_mass_sway(sway_added_mass_kg)
		body.set_mass_properties(sim._hull_mass_kg, inertia_with_water, Vector3.ZERO)
		sim.fin.compute(body, sim.water, sim.time_s, sim._water_density_kg_m3)
		marks.append(body.torque_sum())
		force_marks.append(body._force_sum)
		if sailing:
			sim._hold_the_rig()
			sim.sail.compute(sim.rig, sim.wind, sim._controls_sheet, sim._controls_rake, sim.air_density_kg_m3, sim._rig_lean_now_rad, sim._controls_boom_across, sim._controls_hold_side)
			sim._apply_rig_forces()
			marks.append(body.torque_sum())
			force_marks.append(body._force_sum)
			sim._apply_windage()
			sim._apply_leg_forces(sub_dt)
			marks.append(body.torque_sum())
			force_marks.append(body._force_sum)
			sim._attach_sailor_across_the_deck()
			marks.append(body.torque_sum())
			force_marks.append(body._force_sum)
			_sample_system(sim)
			sim._feel_the_turn(sub_dt)
			sim.sailor.integrate(sub_dt)
		else:
			sim._apply_rig_in_water_drag(sub_dt)
		var pitch_axis: Vector3 = body.starboard_axis()
		var q: float = body.angular_velocity.dot(pitch_axis)
		var w: float = body.velocity.y
		for s: int in mini(marks.size() - 1, _stages.size()):
			_stage_pitch[s] += (marks[s + 1] - marks[s]).dot(pitch_axis)
			_stage_yaw[s] += (marks[s + 1] - marks[s]).dot(body.up_axis())
			var m: float = (marks[s + 1] - marks[s]).dot(pitch_axis)
			var f: float = (force_marks[s + 1] - force_marks[s]).y
			_stage_m[s] += m
			_stage_mq[s] += m * q
			_stage_f[s] += f
			_stage_fw[s] += f * w
		if sailing:
			_sum_q += q
			_sum_qq += q * q
			_sum_w += w
			_sum_ww += w * w
			_power_samples += 1
		sim._net_torque_world = body.torque_sum()
		body.integrate(sub_dt)
		if sailing:
			sim._ride_the_hull(sub_dt)
		sim.time_s += sub_dt
		if sailing:
			sim._check_balance()
		else:
			sim.fallen_for_s += sub_dt
			if sim.fallen_for_s >= sim._waterstart_time_s:
				sim.waterstart()
	sim._fill_telemetry(controls)


## The whole windsurfer's external forces this substep, their moments about the water's push.
func _sample_system(sim: WindsurferSim) -> void:
	var body: SimRigidBody = sim.body
	var hull: HullModel = sim.hull
	var g: float = sim._gravity_ms2
	var pitch_axis: Vector3 = body.starboard_axis()
	var push: Vector3 = body.point_world(hull.cop_local) if hull.planing_normal_force_n > 0.0 else body.position
	var rig_com: Vector3 = sim.rig.foot_world + sim.rig.to_world(sim.sail.mast_direction() * sim._rig_com_height_m)
	var hull_weight: Vector3 = Vector3(0.0, -g * sim._hull_mass_kg, 0.0)
	var sailor_weight: Vector3 = Vector3(0.0, -g * sim.sailor.mass_kg, 0.0)
	var rig_weight: Vector3 = Vector3(0.0, -g * sim._rig_mass_kg, 0.0)
	var total_mass: float = sim._hull_mass_kg + sim.sailor.mass_kg + sim._rig_mass_kg
	var system_com: Vector3 = (body.position * sim._hull_mass_kg + sim.sailor.position * sim.sailor.mass_kg + rig_com * sim._rig_mass_kg) / total_mass
	var sail_force: Vector3 = sim.sail.force_world
	var forward: Vector3 = body.forward()
	var up: Vector3 = body.up_axis()
	_add("sys: sail", (sim.sail.ce_world - push).cross(sail_force).dot(pitch_axis))
	_add("sys: windage", (sim.sailor.position - push).cross(sim.windage_force_world).dot(pitch_axis))
	_add("sys: hull weight", (body.position - push).cross(hull_weight).dot(pitch_axis))
	_add("sys: sailor weight", (sim.sailor.position - push).cross(sailor_weight).dot(pitch_axis))
	_add("sys: rig weight", (rig_com - push).cross(rig_weight).dot(pitch_axis))
	_add("sys: fin", (sim.fin.cop_world - push).cross(sim.fin.force_world).dot(pitch_axis))
	_add("sail forward N", sail_force.dot(forward))
	_add("sail up N", sail_force.dot(up))
	_add("sail side N", sail_force.dot(body.starboard_axis()))
	_add("windage forward N", sim.windage_force_world.dot(forward))
	_add("mast foot down N", -sim.mast_foot_force_world.dot(up))
	_add("mast foot forward N", sim.mast_foot_force_world.dot(forward))
	_add("legs down N", sim.leg_force_world.dot(up))
	_add("feet moment pitch Nm", sim.feet_moment_world.dot(pitch_axis))
	_add("harness N", sim.harness_tension_n)
	_add("hands up N", sim.hand_force_world.dot(up))
	_add("hands forward N", sim.hand_force_world.dot(forward))
	var line: Vector3 = sim._hands_world - sim.sailor.position
	_add("line forward m", line.dot(forward))
	_add("line up m", line.dot(up))
	_add("line starboard m", line.dot(body.starboard_axis()))
	_add("line length m", line.length())
	_add("sailor above deck m", (sim.sailor.position - body.point_world(sim.feet_body)).dot(up))
	_add("hands above deck m", (sim._hands_world - body.point_world(sim.feet_body)).dot(up))
	_add("hands starboard N", sim.hand_force_world.dot(body.starboard_axis()))
	_add("sailor starboard m", (sim.sailor.position - body.position).dot(body.starboard_axis()))
	_add("ce starboard m", (sim.sail.ce_world - body.position).dot(body.starboard_axis()))
	_add("rig lean deg", rad_to_deg(sim._rig_lean_now_rad))
	_add("rake control", sim._controls_rake)
	_add("hang back m", sim.hang_back_m)
	_add("trim press m", sim.trim_press_m)
	_add("pitch deg", rad_to_deg(body.pitch_rad()))
	_add("heel deg", rad_to_deg(body.heel_rad()))
	_add("speed m/s", body.velocity.length())
	_add("planing lift N", hull.planing_lift_n)
	_add("buoyancy N", sim.buoyancy.buoyancy_force_n)
	_add("fin up N", sim.fin.force_world.dot(Vector3.UP))
	_add("friction N", hull.friction_n)
	_add("planing drag N", hull.planing_drag_n)
	_add("residuary N", hull.residuary_n)
	_add("fin drag N", sim.fin.drag_n)
	# The wetted area as the strips see it: the wet share of each section's width (the vee's
	# keel-only front, the heeled board's dry high rail), integrated along the wet span.
	var wet_area: float = 0.0
	var span: float = hull.wetted_length_m
	for k: int in 48:
		var x: float = hull.wetted_aft_m + (float(k) + 0.5) * span / 48.0
		wet_area += hull._wet_width(x).x * sim.board_config.width_at(x) * span / 48.0
	_add("friction area m2", hull.friction_area_m2)
	_add("wet-width area m2", wet_area)
	_add("grid wet area m2", sim.buoyancy.wetted_area_m2)
	_add("chine dry m", hull.chine_dry_length_m)
	_add("wet aft m", hull.wetted_aft_m)
	_add("wet length m", hull.wetted_length_m)
	_add("x push", _from_tail(sim, push))
	_add("x hull com", _from_tail(sim, body.position))
	_add("x sailor", _from_tail(sim, sim.sailor.position))
	_add("x rig com", _from_tail(sim, rig_com))
	_add("x system com", _from_tail(sim, system_com))
	_add("x ce", _from_tail(sim, sim.sail.ce_world))
	_add("x mast foot", _from_tail(sim, sim.rig.foot_world))
	_add("x feet", _from_tail(sim, body.point_world(sim.feet_body)))
	_add("x fin", _from_tail(sim, sim.fin.cop_world))
	_add("x hands", _from_tail(sim, sim._hands_world))
	_add("z ce", _height(sim, sim.sail.ce_world))
	_add("z sailor", _height(sim, sim.sailor.position))
	_add("z system com", _height(sim, system_com))
	_add("z fin", _height(sim, sim.fin.cop_world))
	_samples += 1


func _add(key: String, value: float) -> void:
	_means[key] = _means.get(key, 0.0) + value


## Metres forward of the tail along the hull, of a world point.
func _from_tail(sim: WindsurferSim, point: Vector3) -> float:
	var local: Vector3 = sim.body.to_body(point - sim.body.origin_world())
	return 0.5 * sim.board_config.length_m - local.z


## Metres up from the bottom of the hull (its reference plane), of a world point.
func _height(sim: WindsurferSim, point: Vector3) -> float:
	var local: Vector3 = sim.body.to_body(point - sim.body.origin_world())
	return local.y + 0.5 * sim.board_config.thickness_m


func _print_budget(sim: WindsurferSim, wind_kt: float, twa_deg: float) -> void:
	var n: float = float(maxi(_samples, 1))
	print("Pitch budget, %.0f kt, TWA %.0f, flat water, steady wind; means over %d substeps. + lifts the bow." % [wind_kt, twa_deg, _samples])
	print("")
	print("1. The hull alone, pitch moment about its centre of mass (N m):")
	var hull_sum: float = 0.0
	for s: int in _stages.size():
		var value: float = _stage_pitch[s] / n
		hull_sum += value
		print("   %-24s %8.1f   yaw %8.1f" % [_stages[s], value, _stage_yaw[s] / n])
	print("   %-24s %8.1f" % ["sum", hull_sum])
	print("")
	print("2. The whole windsurfer, pitch moment about the centre of the water's push (N m):")
	var system_sum: float = 0.0
	for key: String in _means:
		if key.begins_with("sys: "):
			var value: float = _means[key] / n
			system_sum += value
			print("   %-24s %8.1f" % [key.substr(5), value])
	print("   %-24s %8.1f   (the hull's water forces act at the push: nothing about it but the friction's small lever)" % ["sum", system_sum])
	print("")
	print("3. The numbers:")
	for key: String in _means:
		if not key.begins_with("sys: "):
			print("   %-24s %8.2f" % [key, _means[key] / n])
	print("")
	var np: float = float(maxi(_power_samples, 1))
	var q_mean: float = _sum_q / np
	var w_mean: float = _sum_w / np
	var q_rms: float = sqrt(maxf(_sum_qq / np - q_mean * q_mean, 0.0))
	var w_rms: float = sqrt(maxf(_sum_ww / np - w_mean * w_mean, 0.0))
	print("4. What feeds the bounce: each stage's power into the hull's oscillation, the mean of")
	print("   M' q' (pitch) and F' w' (heave) over the window, in W. + pumps it, - damps it.")
	print("   The pitch rate's RMS %.2f deg/s, the vertical speed's RMS %.3f m/s." % [rad_to_deg(q_rms), w_rms])
	var pitch_total: float = 0.0
	var heave_total: float = 0.0
	for s: int in _stages.size():
		var pitch_power: float = _stage_mq[s] / np - (_stage_m[s] / np) * q_mean
		var heave_power: float = _stage_fw[s] / np - (_stage_f[s] / np) * w_mean
		pitch_total += pitch_power
		heave_total += heave_power
		print("   %-24s pitch %8.2f   heave %8.2f" % [_stages[s], pitch_power, heave_power])
	print("   %-24s pitch %8.2f   heave %8.2f" % ["sum", pitch_total, heave_total])


## The default open-water simulation, built again on copies with any --board. or --fin.
## override, as run_reach.gd does.
func _make_sim() -> WindsurferSim:
	var sim: WindsurferSim = WindsurferSim.create_default(false)
	var board: BoardConfig = sim.board_config.duplicate() as BoardConfig
	var fin: FinConfig = sim.fin_config.duplicate() as FinConfig
	if not _apply_overrides({"board": board, "fin": fin}):
		return sim
	var rebuilt: WindsurferSim = WindsurferSim.new(board, sim.sail_config, fin, sim.sailor_config,
		sim.water_config, sim.wind_config, sim.sim_config, sim.wave_set_config)
	rebuilt.air_density_kg_m3 = sim.air_density_kg_m3
	return rebuilt


func _apply_overrides(targets: Dictionary) -> bool:
	var changed: bool = false
	for key: String in _options:
		var parts: PackedStringArray = key.split(".", true, 1)
		if parts.size() != 2 or not targets.has(parts[0]):
			continue
		var target: Object = targets[parts[0]]
		if not (parts[1] in target):
			push_error("No field '%s' to override." % key)
			continue
		var current: Variant = target.get(parts[1])
		var number: float = _options[key].to_float()
		target.set(parts[1], (number != 0.0) if current is bool else (int(number) if current is int else number))
		changed = true
	return changed


func _read_user_args() -> Dictionary[String, String]:
	var options: Dictionary[String, String] = {}
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--") and arg.contains("="):
			var parts: PackedStringArray = arg.substr(2).split("=", true, 1)
			options[parts[0]] = parts[1]
	return options
