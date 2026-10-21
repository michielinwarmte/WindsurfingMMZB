class_name ValidationRun
extends RefCounted
## One headless run for the validation suite (PHYSICS_SPEC.md section 14, Part B): a true
## wind of a given strength at the sail (the height gradient, gusts and shifts off, so the
## numbers settle), the pilot holding a true wind angle from rest, and a record of what
## the targets table measures. "Settled" values are the mean of the last 10 s.

const DT: float = 1.0 / 60.0
const WIND_FROM_DEG: float = 270.0
const SETTLE_WINDOW_S: float = 10.0

var twa_deg: float = 0.0
var seconds: float = 0.0
var time_s: PackedFloat64Array = PackedFloat64Array()
var speed_ms: PackedFloat64Array = PackedFloat64Array()
var vmg_ms: PackedFloat64Array = PackedFloat64Array()
var planing_ratio: PackedFloat64Array = PackedFloat64Array()
var submersion: PackedFloat64Array = PackedFloat64Array()
var pitch_deg: PackedFloat64Array = PackedFloat64Array()
var heel_deg: PackedFloat64Array = PackedFloat64Array()
var height_m: PackedFloat64Array = PackedFloat64Array()
var leeway_deg: PackedFloat64Array = PackedFloat64Array()
var sail_angle_deg: PackedFloat64Array = PackedFloat64Array()
# The wet part and the loads behind it (U1, PLAYTEST_UPGRADES.md): positions from the tail.
var wet_front_m: PackedFloat64Array = PackedFloat64Array()
var wetted_length_m: PackedFloat64Array = PackedFloat64Array()
var push_centre_m: PackedFloat64Array = PackedFloat64Array()
var trim_deg: PackedFloat64Array = PackedFloat64Array()
var friction_area_m2: PackedFloat64Array = PackedFloat64Array()
var friction_n: PackedFloat64Array = PackedFloat64Array()
var drive_n: PackedFloat64Array = PackedFloat64Array()
var harness_tension_n: PackedFloat64Array = PackedFloat64Array()
var hand_force_up_n: PackedFloat64Array = PackedFloat64Array()
var mast_foot_force_up_n: PackedFloat64Array = PackedFloat64Array()
# The fin's load and how much of its force points up (U2, PLAYTEST_UPGRADES.md).
var fin_slip_deg: PackedFloat64Array = PackedFloat64Array()
var fin_lift_n: PackedFloat64Array = PackedFloat64Array()
var fin_roll_nm: PackedFloat64Array = PackedFloat64Array()
var fin_up_n: PackedFloat64Array = PackedFloat64Array()
var fin_load_share: PackedFloat64Array = PackedFloat64Array()
var fin_tilt_deg: PackedFloat64Array = PackedFloat64Array()
var fin_bend_tip_deg: PackedFloat64Array = PackedFloat64Array()
var fell: bool = false
var nan: bool = false
var telemetry: Telemetry = null
var sim: WindsurferSim = null


## A simulation with the validation wind: steady, the same at every height.
static func make_sim(wind_kt: float, waves: bool = false) -> WindsurferSim:
	var new_sim: WindsurferSim = WindsurferSim.create_default(waves)
	new_sim.wind_config = new_sim.wind_config.duplicate()
	new_sim.wind_config.speed_kt = wind_kt
	new_sim.wind_config.from_bearing_deg = WIND_FROM_DEG
	new_sim.wind_config.height_gradient_enabled = false
	new_sim.wind_config.gusts_enabled = false
	new_sim.wind_config.shifts_enabled = false
	new_sim.wind = WindField.new(new_sim.wind_config)
	return new_sim


## The pilot of the game: it knows the sail and the sailor.
static func make_pilot(for_sim: WindsurferSim, target_twa_deg: float) -> Autopilot:
	var pilot: Autopilot = Autopilot.new()
	pilot.target_twa_deg = absf(target_twa_deg)
	pilot.sail = for_sim.sail
	pilot.sailor = for_sim.sailor_config
	return pilot


## The compass heading that gives a signed true wind angle with the wind from the West:
## positive (wind from starboard) is heading 270 - TWA, negative is 270 + TWA.
static func heading_for_twa(signed_twa_deg: float) -> float:
	return wrapf(WIND_FROM_DEG - signed_twa_deg, 0.0, 360.0)


## Sails from rest at a signed true wind angle for a number of seconds and records the run.
## may_tack = false keeps the pilot from backing the sail through the wind when it cannot
## point as high as asked (the no-go check wants to see the board fail to point, not tack).
static func sail(signed_twa_deg: float, run_seconds: float, wind_kt: float = 15.0, may_tack: bool = true, waves: bool = false) -> ValidationRun:
	var run: ValidationRun = ValidationRun.new()
	run.twa_deg = signed_twa_deg
	run.seconds = run_seconds
	run.sim = make_sim(wind_kt, waves)
	run.sim.reset(Vector3.ZERO, deg_to_rad(heading_for_twa(signed_twa_deg)))
	var pilot: Autopilot = make_pilot(run.sim, signed_twa_deg)
	pilot.may_tack = may_tack
	if not may_tack:
		# Try to hold the angle from the start instead of bearing away to get going first.
		pilot.pointing_speed_ms = 0.0
	var controls: SimControls = SimControls.new()
	controls.sheet = 0.0
	run.record_steps(pilot, controls, run_seconds)
	return run


## Steps the simulation and records the series.
func record_steps(pilot: Autopilot, controls: SimControls, run_seconds: float) -> void:
	var steps: int = int(run_seconds / DT)
	for i: int in steps:
		if pilot != null:
			pilot.update(sim.telemetry, controls, DT)
		sim.step(DT, controls)
		var t: Telemetry = sim.telemetry
		time_s.append(t.time_s)
		speed_ms.append(t.speed_ms)
		vmg_ms.append(t.vmg_ms)
		planing_ratio.append(t.planing_ratio)
		submersion.append(t.submersion_ratio)
		pitch_deg.append(t.pitch_deg)
		heel_deg.append(t.heel_deg)
		height_m.append(t.position.y)
		leeway_deg.append(t.leeway_deg)
		sail_angle_deg.append(t.sail_angle_deg)
		wet_front_m.append(t.wet_front_m)
		wetted_length_m.append(t.wetted_length_m)
		push_centre_m.append(t.push_centre_m)
		trim_deg.append(t.trim_deg)
		friction_area_m2.append(t.friction_area_m2)
		friction_n.append(t.hull_friction_n)
		drive_n.append(t.drive_n)
		harness_tension_n.append(t.harness_tension_n)
		hand_force_up_n.append(t.hand_force_up_n)
		mast_foot_force_up_n.append(t.mast_foot_force_up_n)
		fin_slip_deg.append(t.fin_slip_deg)
		fin_lift_n.append(t.fin_lift_n)
		fin_roll_nm.append(t.roll_fin_nm)
		fin_up_n.append(t.fin_up_n)
		fin_load_share.append(t.fin_load_share)
		fin_tilt_deg.append(t.fin_tilt_deg)
		fin_bend_tip_deg.append(t.fin_bend_tip_deg)
		if sim.sailor_state == WindsurferSim.SailorState.FALLEN:
			fell = true
		if is_nan(t.speed_ms) or is_nan(t.position.y):
			nan = true
	telemetry = sim.telemetry


## Mean of a series over the last SETTLE_WINDOW_S seconds.
func settled(values: PackedFloat64Array) -> float:
	var count: int = mini(int(SETTLE_WINDOW_S / DT), values.size())
	if count == 0:
		return 0.0
	var total: float = 0.0
	for i: int in range(values.size() - count, values.size()):
		total += values[i]
	return total / float(count)


## (max - min) of a series over the last SETTLE_WINDOW_S seconds.
func settled_spread(values: PackedFloat64Array) -> float:
	var count: int = mini(int(SETTLE_WINDOW_S / DT), values.size())
	if count == 0:
		return 0.0
	var lowest: float = INF
	var highest: float = -INF
	for i: int in range(values.size() - count, values.size()):
		lowest = minf(lowest, values[i])
		highest = maxf(highest, values[i])
	return highest - lowest


## The largest value of a series over the last SETTLE_WINDOW_S seconds.
func settled_max(values: PackedFloat64Array) -> float:
	var count: int = mini(int(SETTLE_WINDOW_S / DT), values.size())
	var highest: float = -INF
	for i: int in range(values.size() - count, values.size()):
		highest = maxf(highest, values[i])
	return highest


## The first time at which a series reaches a value, or -1.
func first_time_above(values: PackedFloat64Array, threshold: float) -> float:
	for i: int in values.size():
		if values[i] >= threshold:
			return time_s[i]
	return -1.0


## The first time at which a series falls to or below a value, or -1.
func first_time_below(values: PackedFloat64Array, threshold: float) -> float:
	for i: int in values.size():
		if values[i] <= threshold:
			return time_s[i]
	return -1.0


## The value of a series at a time (the nearest recorded step).
func value_at(values: PackedFloat64Array, at_s: float) -> float:
	var index: int = clampi(int(at_s / DT) - 1, 0, values.size() - 1)
	return values[index]


func settled_speed_ms() -> float:
	return settled(speed_ms)


func settled_speed_kt() -> float:
	return settled(speed_ms) / SimMath.KNOT_MS
