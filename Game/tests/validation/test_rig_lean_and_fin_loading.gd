extends GutTest
## U1.6 (Documentation/PLAYTEST_UPGRADES.md): the rig leaned to windward, the fin loaded, and
## the railing-out test, all on the reach check's 18 kt beam reach (flat water, a steady
## wind, 40 s from rest, judged on the last 10 s).
##
## The helm: the pilot's default helm moves the rake and the rig's sideways tilt together,
## so the heading-up helm a planing reach needs also stands the rig up. The rake-first hold
## (Autopilot.trim_with_rake_first) keeps the rig leaned as the hike leans it.
## Loading the fin: planing and hooked in, the sailor lets the board heel a few degrees to
## leeward (SailorConfig.fin_load_bank_deg), banking it only by what the heel does not give
## already, so the fin's sideways push also lifts.
## The railing-out test is information for the team (a player control is a later decision):
## the heel the sailor aims for is raised step by step and the first one at which the board
## loses control is printed. Nothing in the game depends on it.

const WIND_KT: float = 18.0
const TWA_DEG: float = 100.0
const RUN_S: float = 40.0
const SETTLE_S: float = 10.0
const DT: float = 1.0 / 60.0
## The leeward heels the sailor aims for in the railing-out test, degrees (4.5 is the
## default's placeholder).
const BANKS_DEG: Array[float] = [0.0, 4.5, 6.0, 9.0, 12.0, 15.0, 18.0, 21.0, 24.0, 27.0, 30.0]
## A run has lost control when the sailor falls, the pitch swings more than this over the
## last 10 s (a steady board is below 0.3, U1's target 2), or the speed drops below this
## share of the flat board's.
const LOST_PITCH_SD_DEG: float = 1.0
const LOST_SPEED_SHARE: float = 0.8


## The settled numbers of one run.
class Settled:
	var label: String = ""
	var speed_ms: float = 0.0
	var twa_deg: float = 0.0
	var pitch_sd_deg: float = 0.0
	var heel_deg: float = 0.0
	var trim_deg: float = 0.0
	var rig_lean_deg: float = 0.0
	var rake: float = 0.0
	var rig_tilt: float = 0.0
	var line_m: float = 0.0
	var harness_n: float = 0.0
	var hands_up_share: float = 0.0
	var sail_up_share: float = 0.0
	var fin_up_n: float = 0.0
	var wet_front_m: float = 0.0
	var fell: bool = false
	var fall_kind: String = ""
	var nan: bool = false


var _coupled: Settled = null
var _rake_first: Settled = null
## The heel aimed for (degrees) -> the run.
var _banks: Dictionary[float, Settled] = {}


func before_all() -> void:
	var started: int = Time.get_ticks_msec()
	_coupled = _run("helm: rake and tilt together", false, _default_bank())
	_rake_first = _run("helm: rake first", true, _default_bank())
	for bank: float in BANKS_DEG:
		_banks[bank] = _run("fin loading %.1f deg" % bank, false, bank)
	gut.p("rig lean and fin loading: %d runs of %.0f s in %.1f s" % [2 + BANKS_DEG.size(), RUN_S, (Time.get_ticks_msec() - started) / 1000.0])
	gut.p("run                            speed  TWA    pitchSD heel   trim  rig lean rake  tilt   line m harness hands%% sail%% fin up N wet front fell")
	for run: Settled in [_coupled, _rake_first] + _banks.values():
		gut.p(_format(run))
	var lost: float = railing_out_bank_deg()
	gut.p("railing-out test: %s" % ("the board loses control when the sailor aims for %.0f deg of leeward heel" % lost if lost >= 0.0 else "the board keeps control at every heel tried"))


func test_nothing_blows_up() -> void:
	for run: Settled in [_coupled, _rake_first] + _banks.values():
		assert_false(run.nan, "no NaN: %s" % run.label)


func test_the_default_fin_loading_keeps_the_board_steady_on_course() -> void:
	assert_false(_coupled.fell, "no fall")
	# Starboard tack: the leeward rail is port, a negative heel.
	assert_lt(_coupled.heel_deg, -(_default_bank() - 0.5), "the leeward rail at least as far down as the sailor aims")
	assert_lt(_coupled.pitch_sd_deg, 0.3, "steady")
	assert_almost_eq(_coupled.twa_deg, TWA_DEG, 3.0, "on its course")


func test_the_sailor_heels_the_board_as_far_as_aimed_and_the_fin_lifts_more() -> void:
	var lift_before: float = _banks[0.0].fin_up_n
	for bank: float in [6.0, 9.0, 12.0]:
		var run: Settled = _banks[bank]
		assert_almost_eq(run.heel_deg, -bank, 1.5, "aimed for %.0f degrees of leeward heel" % bank)
		assert_gt(run.fin_up_n, lift_before, "the tilted fin lifts more at %.0f degrees" % bank)
		lift_before = run.fin_up_n


func test_the_rake_first_hold_keeps_the_rig_leaned_and_the_course() -> void:
	assert_false(_rake_first.fell, "no fall")
	assert_almost_eq(_rake_first.twa_deg, TWA_DEG, 3.0, "the rake alone (to its stop) holds the beam reach")
	assert_gt(_rake_first.rig_lean_deg, 20.0, "the rig leans as the hike leans it (real: 10 to 25 degrees)")
	assert_lt(_coupled.rig_lean_deg, 12.0, "where the default helm stands it up")
	assert_lt(_rake_first.line_m, _coupled.line_m - 0.2, "the hips are closer to the boom")
	assert_gt(_rake_first.sail_up_share, _coupled.sail_up_share, "and the sail's own lift carries more of the weight")


func test_railing_out_is_reported() -> void:
	# Information only (the team decides on a player control later): the flat board and
	# the default bank keep control, and the angle where it is lost is in the output.
	assert_true(_in_control(_banks[0.0]), "the flat board is in control")
	assert_true(_in_control(_banks[4.5]), "the default 4.5 degrees is in control")
	pass_test("railing out at %.0f deg (-1: not found)" % railing_out_bank_deg())


## The first wanted bank at which the board loses control, or -1.
func railing_out_bank_deg() -> float:
	for bank: float in BANKS_DEG:
		if not _in_control(_banks[bank]):
			return bank
	return -1.0


func _in_control(run: Settled) -> bool:
	return not run.fell and not run.nan and run.pitch_sd_deg < LOST_PITCH_SD_DEG and run.speed_ms > LOST_SPEED_SHARE * _banks[0.0].speed_ms


func _default_bank() -> float:
	return (load("res://config/sailor_default.tres") as SailorConfig).fin_load_bank_deg


## Sails the 18 kt beam reach from rest with this helm and this wanted fin-loading bank.
func _run(label: String, rake_first: bool, bank_deg: float) -> Settled:
	var sim: WindsurferSim = ValidationRun.make_sim(WIND_KT)
	sim.sailor_config = sim.sailor_config.duplicate()
	sim.sailor_config.fin_load_bank_deg = bank_deg
	sim.reset(Vector3.ZERO, deg_to_rad(ValidationRun.heading_for_twa(TWA_DEG)))
	var pilot: Autopilot = ValidationRun.make_pilot(sim, TWA_DEG)
	pilot.trim_with_rake_first = rake_first
	var controls: SimControls = SimControls.new()
	controls.sheet = 0.0
	var weight_n: float = sim.sailor_config.mass_kg * sim.sim_config.gravity_ms2
	var result: Settled = Settled.new()
	result.label = label
	var steps: int = int(RUN_S / DT)
	var settle_from: int = steps - int(SETTLE_S / DT)
	var pitches: PackedFloat64Array = PackedFloat64Array()
	for i: int in steps:
		pilot.update(sim.telemetry, controls, DT)
		sim.step(DT, controls)
		var t: Telemetry = sim.telemetry
		if is_nan(t.speed_ms) or is_nan(t.position.y):
			result.nan = true
			break
		if sim.sailor_state == WindsurferSim.SailorState.FALLEN and not result.fell:
			result.fell = true
			result.fall_kind = sim.fall_kind
		if i < settle_from:
			continue
		pitches.append(t.pitch_deg)
		result.speed_ms += t.speed_ms
		result.twa_deg += absf(t.twa_deg)
		result.heel_deg += t.heel_deg
		result.trim_deg += t.trim_deg
		result.rig_lean_deg += t.rig_lean_deg
		result.rake += controls.rake
		result.rig_tilt += controls.rig_tilt
		result.line_m += (sim.body.point_world(sim.hand_grip_body) - sim.sailor.position).length()
		result.harness_n += sim.harness_tension_n
		result.hands_up_share += sim.hand_force_world.y / weight_n
		result.sail_up_share += sim.sail.force_world.y / weight_n
		result.fin_up_n += sim.fin.force_world.y
		result.wet_front_m += t.wet_front_m
	var count: float = maxf(float(pitches.size()), 1.0)
	for field: String in ["speed_ms", "twa_deg", "heel_deg", "trim_deg", "rig_lean_deg", "rake", "rig_tilt", "line_m", "harness_n", "hands_up_share", "sail_up_share", "fin_up_n", "wet_front_m"]:
		result.set(field, float(result.get(field)) / count)
	result.pitch_sd_deg = _standard_deviation(pitches)
	return result


func _standard_deviation(values: PackedFloat64Array) -> float:
	if values.is_empty():
		return 0.0
	var mean: float = 0.0
	for v: float in values:
		mean += v
	mean /= values.size()
	var square_sum: float = 0.0
	for v: float in values:
		square_sum += (v - mean) * (v - mean)
	return sqrt(square_sum / values.size())


func _format(r: Settled) -> String:
	return "%-30s %5.2f  %5.1f  %5.2f  %6.1f  %4.2f  %6.1f  %5.2f %5.2f  %5.2f  %6.0f  %5.0f  %4.0f  %6.0f  %5.2f    %s" % [
		r.label, r.speed_ms, r.twa_deg, r.pitch_sd_deg, r.heel_deg, r.trim_deg, r.rig_lean_deg, r.rake, r.rig_tilt,
		r.line_m, r.harness_n, r.hands_up_share * 100.0, r.sail_up_share * 100.0, r.fin_up_n, r.wet_front_m,
		(r.fall_kind if r.fell else "-") + (" NaN" if r.nan else "")]
