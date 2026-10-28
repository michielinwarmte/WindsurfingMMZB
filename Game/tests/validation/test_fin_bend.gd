extends GutTest
## U2, "the fin bends, and its size" (Documentation/PLAYTEST_UPGRADES.md, the execution
## brief): the fin on the 18 kt beam reach (flat water, a steady wind, 40 s from rest), run
## through ValidationRun and judged on the settled last 10 s.
##
## The stiff fin (checks). Today's numbers, pinned within a tolerance, so that a change that
## moves the fin's load shows up here: the slip angle, the lift, and the upward part of the
## fin's force. A stiff fin's force lies in the board's plane, so it points up only as far
## as the board heels (the leeward rail down). Measured on feature/u2-fin on 19 October 2026
## (agent 2, fin_measure). Now that the fin bends (agent 3, fin_physics), the stiff run sails
## the stiff limit of the bending fin (_stiff_fin, the bend switched off), which gives these
## numbers again: the brief's "the stiff limit gives the old force exactly".
##
## The bend (a check since agent 3). The default fin bends under its load (section 4, "The
## fin bends"): its tip turns (fin_bend_tip_deg), its force tilts toward the deck
## (fin_tilt_deg), and the bend adds an upward force: the default fin's fin_up_n less the
## stiff fin's. No size is a target (the plan's 100 to 200 N was a guess); the check asks
## that the bend is there, toward the deck on this tack, and inside the linear beam's 35
## degrees.

const RUN_S: float = 40.0
const WIND_KT: float = 18.0
const TWA_DEG: float = 100.0

## The stiff fin on the 18 kt beam reach, 19 October 2026, and how far each may move.
## Re-pinned in Session 49 (U2, the sailor's technique): the sailor banks 2 degrees instead
## of 4.5 (SailorConfig.fin_load_bank_deg), so the heel's upward part is smaller (it was
## 40.9 N at a 1.98 degree slip and 526 N of lift). Re-pinned in Session 57 (PH28, the sail
## from the wind tunnel): the sailor sheets the twisting sail further in, so it pulls harder on
## this reach and the fin carries more (it was 475 N at a 1.64 degree slip, 16 N upward; the
## numbers below are with the twist's final floor, 0.75).
const STIFF_SLIP_DEG: float = 1.74
const SLIP_TOLERANCE_DEG: float = 0.25
const STIFF_LIFT_N: float = 526.0
## A share of the lift.
const LIFT_TOLERANCE: float = 0.05
const STIFF_UP_N: float = 18.0
const UP_TOLERANCE_N: float = 10.0
## A stiff fin's force has no part out of the board's plane, and its tip does not turn.
const STIFF_TILT_MAX_DEG: float = 0.01

## The bend's tip angle: clearly there, and inside the linear beam's cap.
const BEND_TIP_MIN_DEG: float = 0.5
const BEND_TIP_MAX_DEG: float = 35.0
## The force's tilt toward the deck: clearly more than rounding.
const BEND_TILT_MIN_DEG: float = 0.1

var _stiff: ValidationRun = null
var _bending: ValidationRun = null


func before_all() -> void:
	var started: int = Time.get_ticks_msec()
	var stiff_fin: FinConfig = _stiff_fin()
	var default_fin: FinConfig = _default_fin()
	_stiff = _sail_with(stiff_fin)
	# Until the fin bends the two fins are one and the same: sail it once.
	_bending = _stiff if stiff_fin == default_fin else _sail_with(default_fin)
	gut.p("fin bend: %d run(s) of %.0f s in %.1f s" % [1 if _bending == _stiff else 2, RUN_S, (Time.get_ticks_msec() - started) / 1000.0])
	_print_table()


func test_no_fall_or_blow_up() -> void:
	for run: ValidationRun in [_stiff, _bending]:
		assert_false(run.nan, "no NaN")
		assert_false(run.fell, "no fall")


func test_stiff_fin_slip_lift_and_upward_force_as_measured() -> void:
	var slip: float = absf(_stiff.settled(_stiff.fin_slip_deg))
	var lift: float = _stiff.settled(_stiff.fin_lift_n)
	var up: float = _stiff.settled(_stiff.fin_up_n)
	assert_almost_eq(slip, STIFF_SLIP_DEG, SLIP_TOLERANCE_DEG, "the stiff fin's slip (deg)")
	assert_almost_eq(lift, STIFF_LIFT_N, LIFT_TOLERANCE * STIFF_LIFT_N, "the stiff fin's lift (N)")
	assert_almost_eq(up, STIFF_UP_N, UP_TOLERANCE_N, "the upward part of the stiff fin's force, from the heel (N)")


func test_stiff_fin_force_lies_in_the_boards_plane() -> void:
	assert_lt(absf(_stiff.settled(_stiff.fin_tilt_deg)), STIFF_TILT_MAX_DEG, "a stiff fin's force is not tilted out of the board's plane")
	assert_eq(_stiff.settled(_stiff.fin_bend_tip_deg), 0.0, "a stiff fin's tip does not turn")


func test_the_bend_tilts_the_force_toward_the_deck() -> void:
	var tip: float = _bending.settled(_bending.fin_bend_tip_deg)
	var tilt: float = _bending.settled(_bending.fin_tilt_deg)
	var up_from_bend: float = _bending.settled(_bending.fin_up_n) - _stiff.settled(_stiff.fin_up_n)
	var misses: PackedStringArray = PackedStringArray()
	if tip < BEND_TIP_MIN_DEG or tip > BEND_TIP_MAX_DEG:
		misses.append("tip %.1f deg (%.1f to %.0f)" % [tip, BEND_TIP_MIN_DEG, BEND_TIP_MAX_DEG])
	if tilt < BEND_TILT_MIN_DEG:
		misses.append("tilt %.2f deg (at least %.1f)" % [tilt, BEND_TILT_MIN_DEG])
	if up_from_bend <= 0.0:
		misses.append("upward force from the bend %.0f N (above 0)" % up_from_bend)
	var target: String = "the fin bends: its tip turns, its force tilts toward the deck and lifts"
	if misses.is_empty():
		pass_test("%s: tip %.1f deg, tilt %.1f deg, %.0f N from the bend" % [target, tip, tilt, up_from_bend])
	else:
		fail_test("%s, not met: %s" % [target, "; ".join(misses)])


## The fin of the game.
func _default_fin() -> FinConfig:
	return load("res://config/fin_default.tres") as FinConfig


## The stiff fin: a copy of the game's fin with the bend switched off (its stiff limit), so
## that this run keeps pinning the old force.
func _stiff_fin() -> FinConfig:
	var stiff: FinConfig = _default_fin().duplicate() as FinConfig
	stiff.bends = false
	return stiff


## ValidationRun.sail(TWA_DEG, RUN_S, WIND_KT) with a fin of our choice: the same steady
## wind, start and pilot, on a simulation built with that fin.
func _sail_with(fin: FinConfig) -> ValidationRun:
	var base: WindsurferSim = ValidationRun.make_sim(WIND_KT)
	var run: ValidationRun = ValidationRun.new()
	run.twa_deg = TWA_DEG
	run.seconds = RUN_S
	run.sim = WindsurferSim.new(base.board_config, base.sail_config, fin, base.sailor_config,
		base.water_config, base.wind_config, base.sim_config, base.wave_set_config)
	run.sim.air_density_kg_m3 = base.air_density_kg_m3
	run.sim.reset(Vector3.ZERO, deg_to_rad(ValidationRun.heading_for_twa(TWA_DEG)))
	var controls: SimControls = SimControls.new()
	controls.sheet = 0.0
	run.record_steps(ValidationRun.make_pilot(run.sim, TWA_DEG), controls, RUN_S)
	return run


## The numbers of both runs, so they stay visible in the test output.
func _print_table() -> void:
	gut.p("fin       slip  lift  roll   up  stall%  tilt  tip   heel  speed")
	for entry: Array in [["stiff", _stiff], ["default", _bending]]:
		var run: ValidationRun = entry[1]
		gut.p("%-8s  %4.2f  %4.0f  %4.0f  %4.1f   %3.0f   %4.1f  %4.1f  %5.2f  %5.2f" % [
			entry[0], absf(run.settled(run.fin_slip_deg)), run.settled(run.fin_lift_n),
			absf(run.settled(run.fin_roll_nm)), run.settled(run.fin_up_n),
			100.0 * run.settled(run.fin_load_share), run.settled(run.fin_tilt_deg),
			run.settled(run.fin_bend_tip_deg), run.settled(run.heel_deg), run.settled(run.speed_ms)])
