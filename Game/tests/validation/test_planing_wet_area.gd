extends GutTest
## U1, "planing on a smaller wet area" (Documentation/PLAYTEST_UPGRADES.md, the execution
## brief's targets 2 to 4): the reach check's nine cases (12, 18 and 24 kt; true wind angles
## of 60, 100 and 135 degrees; flat water, a steady wind), run through ValidationRun and
## judged on the settled last 10 s.
##
## Target 2: steady, a pitch standard deviation below 0.3 degrees in every case.
## Target 3: at 18 and 24 kt on the beam and broad reach, the front of the wet part 0.6 to
##           1.0 m from the tail (real boards are wet from the front footstraps back).
## Target 4: in the same four cases, the centre of the water's push 0.45 to 0.75 m from the
##           tail (Savitsky 1964; Gourlay & Martellotta 2011) and the trim 1.5 to 4 degrees.
##
## Until U1's physics meets them (agent 4), an unmet target calls pending() with the measured
## numbers: the suite stays green and the numbers stay in the output. Agent 4 sets
## TARGETS_ARE_CHECKS to true, and an unmet target then fails.
const TARGETS_ARE_CHECKS: bool = false

const RUN_S: float = 40.0
const WINDS_KT: Array[float] = [12.0, 18.0, 24.0]
const TWAS_DEG: Array[float] = [60.0, 100.0, 135.0]

const MAX_PITCH_SD_DEG: float = 0.3
const WET_FRONT_MIN_M: float = 0.6
const WET_FRONT_MAX_M: float = 1.0
const PUSH_CENTRE_MIN_M: float = 0.45
const PUSH_CENTRE_MAX_M: float = 0.75
const TRIM_MIN_DEG: float = 1.5
const TRIM_MAX_DEG: float = 4.0

## "<wind>_<twa>" -> the run.
var _runs: Dictionary[String, ValidationRun] = {}


func before_all() -> void:
	var started: int = Time.get_ticks_msec()
	for wind_kt: float in WINDS_KT:
		for twa_deg: float in TWAS_DEG:
			_runs[_key(wind_kt, twa_deg)] = ValidationRun.sail(twa_deg, RUN_S, wind_kt)
	gut.p("planing wet area: %d runs of %.0f s in %.1f s" % [_runs.size(), RUN_S, (Time.get_ticks_msec() - started) / 1000.0])
	_print_table()


func test_no_case_fell_or_blew_up() -> void:
	for key: String in _runs:
		assert_false(_runs[key].nan, "no NaN at %s" % key)
		assert_false(_runs[key].fell, "no fall at %s" % key)


func test_target_2_steady_in_every_case() -> void:
	var misses: PackedStringArray = PackedStringArray()
	for key: String in _runs:
		var sd: float = _settled_sd(_runs[key].pitch_deg)
		if sd >= MAX_PITCH_SD_DEG:
			misses.append("%s: pitch SD %.2f deg" % [key, sd])
	_judge("target 2, pitch SD below %.1f deg" % MAX_PITCH_SD_DEG, misses)


func test_target_3_wet_front_on_the_planing_reaches() -> void:
	var misses: PackedStringArray = PackedStringArray()
	for key: String in _planing_reach_keys():
		var front: float = _runs[key].settled(_runs[key].wet_front_m)
		if front < WET_FRONT_MIN_M or front > WET_FRONT_MAX_M:
			misses.append("%s: front %.2f m" % [key, front])
	_judge("target 3, front of the wet part %.1f to %.1f m from the tail" % [WET_FRONT_MIN_M, WET_FRONT_MAX_M], misses)


func test_target_4_push_centre_and_trim_on_the_planing_reaches() -> void:
	var misses: PackedStringArray = PackedStringArray()
	for key: String in _planing_reach_keys():
		var push: float = _runs[key].settled(_runs[key].push_centre_m)
		var trim: float = _runs[key].settled(_runs[key].trim_deg)
		if push < PUSH_CENTRE_MIN_M or push > PUSH_CENTRE_MAX_M:
			misses.append("%s: push %.2f m" % [key, push])
		if trim < TRIM_MIN_DEG or trim > TRIM_MAX_DEG:
			misses.append("%s: trim %.2f deg" % [key, trim])
	_judge("target 4, push %.2f to %.2f m from the tail and trim %.1f to %.1f deg" % [PUSH_CENTRE_MIN_M, PUSH_CENTRE_MAX_M, TRIM_MIN_DEG, TRIM_MAX_DEG], misses)


## A met target passes. An unmet one fails once TARGETS_ARE_CHECKS is on; before that it is
## pending, with the numbers that miss.
func _judge(target: String, misses: PackedStringArray) -> void:
	if misses.is_empty():
		pass_test("%s: met" % target)
	elif TARGETS_ARE_CHECKS:
		fail_test("%s not met: %s" % [target, "; ".join(misses)])
	else:
		pending("%s not met yet: %s" % [target, "; ".join(misses)])


## The cases of targets 3 and 4: 18 and 24 kt on the beam and broad reach.
func _planing_reach_keys() -> Array[String]:
	var keys: Array[String] = []
	for wind_kt: float in [18.0, 24.0]:
		for twa_deg: float in [100.0, 135.0]:
			keys.append(_key(wind_kt, twa_deg))
	return keys


func _key(wind_kt: float, twa_deg: float) -> String:
	return "%d kt %d deg" % [int(wind_kt), int(twa_deg)]


## Standard deviation of a series over the settled window (ValidationRun.SETTLE_WINDOW_S).
func _settled_sd(values: PackedFloat64Array) -> float:
	var count: int = mini(int(ValidationRun.SETTLE_WINDOW_S / ValidationRun.DT), values.size())
	if count == 0:
		return 0.0
	var mean: float = 0.0
	for i: int in range(values.size() - count, values.size()):
		mean += values[i]
	mean /= float(count)
	var square_sum: float = 0.0
	for i: int in range(values.size() - count, values.size()):
		square_sum += (values[i] - mean) * (values[i] - mean)
	return sqrt(square_sum / float(count))


## The reach check's numbers for every case, so they stay visible in the test output.
func _print_table() -> void:
	gut.p("case          speed  front  wet   push  trim  pitchSD  harness  rig%  mast  fric  drive  area")
	for key: String in _runs:
		var run: ValidationRun = _runs[key]
		var weight_n: float = run.sim.sailor_config.mass_kg * run.sim.sim_config.gravity_ms2
		gut.p("%-12s  %5.2f  %5.2f  %4.2f  %4.2f  %4.2f  %5.2f    %5.0f    %3.0f   %4.0f  %4.0f  %5.0f  %4.2f" % [
			key, run.settled(run.speed_ms), run.settled(run.wet_front_m), run.settled(run.wetted_length_m),
			run.settled(run.push_centre_m), run.settled(run.trim_deg), _settled_sd(run.pitch_deg),
			run.settled(run.harness_tension_n), 100.0 * run.settled(run.hand_force_up_n) / weight_n,
			-run.settled(run.mast_foot_force_up_n), run.settled(run.friction_n), run.settled(run.drive_n),
			run.settled(run.friction_area_m2)])
