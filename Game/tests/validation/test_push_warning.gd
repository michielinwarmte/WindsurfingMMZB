extends GutTest
## GP0, point 4 of the report (Documentation/reports/gameplay/gp0_measure.md, "The warning
## signs"): before a catapult it is the sailor who strains, not the fin. The case is one that
## catapults: 24 kt on a 120 degree reach, gusts 0.2 every 8 s, waves and the height gradient
## on, starboard tack, the board sailed by the player's beginner controller (AiHands holding the
## wind angle) with the push the report proposes for the top of the dial (hike_share 1.6 and the
## late ease), written into the autopilot every tick as GP1 will. The same case as
## `tools/push_check.sh --winds=24 --twas=120 --pilot.hike_share=1.6
## --pilot.depower_alpha_per_deg=0.3 --pilot.depower_rate_per_s=0.05
## --pilot.depower_urgent_rate_per_s=0.5 --pilot.catch_alpha_max_deg=0`.
##
## For every catapult after the spin-up, the last WARNING_S before it is read tick by tick:
## 1. the fin is not near its stall while there is still time to act: until the last
##    ROUND_UP_WITHIN_S its lift coefficient's share of the peak stays below FIN_SHARE_MAX, so a
##    fin's hum would not have warned. In the round-up itself the spinning board can load it
##    (0.89 of its stall 0.07 s before one catapult, measured 26 October 2026), but that is the
##    fall, not a warning of it;
## 2. the sailor was overloaded first: the feet were asked to pass more moment toward the sail
##    than they can (feet_moment_excess_nm above OVERLOAD_NM) for at least OVERLOAD_MIN_S, in
##    the time up to LAST_MOMENT_S before the fall;
## 3. the board rounded up at the end: in the last ROUND_UP_WITHIN_S the bow turned toward the
##    wind faster than ROUND_UP_DPS.
## 1 must hold for every catapult; 2 and 3 for most (MOST_SHARE), as in the report (76 and 101
## of 124 falls). Check 2 is not a warning on its own: the pushed sailor is overloaded in about half
## of all sailing time here (printed; 52 % on 26 October 2026), and in 66 to 89 % of the time before a
## catapult, so the overload marks the edge rather than the fall. To see it for yourself, sail
## tools/play_push.sh: the detail panel (F1) shows the overload and the fin live, and freezes them
## from 1 s and 0.5 s before each fall. Nothing here sets a physics number: if the physics changes so that the fin
## warns, or the sailor no longer strains first, this test says so, and the feedback (SO1, GR1)
## must follow. Takes about half a minute.

const DT: float = 1.0 / 60.0
const RUN_S: float = 150.0
const SPIN_UP_S: float = 30.0
const WIND_KT: float = 24.0
const TWA_DEG: float = 120.0
const WIND_FROM_DEG: float = 270.0
## The push at the top of the dial (the report's table, "Pushed").
const PUSH: Dictionary[String, float] = {
	"hike_share": 1.6, "depower_alpha_per_deg": 0.3, "depower_rate_per_s": 0.05,
	"depower_urgent_rate_per_s": 0.5, "catch_alpha_max_deg": 0.0}
## Below this speed the board is sailed on a beam reach, getting going (as run_push.gd).
const POINTING_SPEED_MS: float = 5.0
const START_TWA_DEG: float = 90.0

const WARNING_S: float = 2.0
const LAST_MOMENT_S: float = 0.25
const MIN_CATAPULTS: int = 2
const FIN_SHARE_MAX: float = 0.6
const OVERLOAD_NM: float = 50.0
const OVERLOAD_MIN_S: float = 0.25
const ROUND_UP_WITHIN_S: float = 0.5
const ROUND_UP_DPS: float = 10.0
const MOST_SHARE: float = 0.5


## What the board did at one tick.
class Sample:
	var fin_share: float = 0.0
	var feet_excess_nm: float = 0.0
	var heading_up_dps: float = 0.0


## One catapult and what came before it.
class Warning:
	var time_s: float = 0.0
	var fin_share_max: float = 0.0
	var fin_share_early_max: float = 0.0
	var fin_peak_before_s: float = 0.0
	var overload_s: float = 0.0
	var heading_up_max_dps: float = 0.0


func test_the_sailor_strains_before_a_catapult_and_the_fin_does_not_warn() -> void:
	var warnings: Array[Warning] = _sail_and_read_the_catapults()
	var overloaded: int = 0
	var rounded_up: int = 0
	for w: Warning in warnings:
		gut.p("catapult at %.1f s: fin %.2f of its stall at most (%.2f s before; %.2f before the last 0.5 s), overloaded %.2f s, heading up at %.0f deg/s at most" % [
			w.time_s, w.fin_share_max, w.fin_peak_before_s, w.fin_share_early_max, w.overload_s, w.heading_up_max_dps])
		assert_lt(w.fin_share_early_max, FIN_SHARE_MAX, "the fin was not near its stall while there was time to act, before the catapult at %.1f s" % w.time_s)
		if w.overload_s >= OVERLOAD_MIN_S:
			overloaded += 1
		if w.heading_up_max_dps > ROUND_UP_DPS:
			rounded_up += 1
	assert_gte(warnings.size(), MIN_CATAPULTS, "the pushed board catapults on the 24 kt reach")
	var most: int = ceili(MOST_SHARE * warnings.size())
	assert_gte(overloaded, most, "the sailor was overloaded first before most catapults (%d of %d)" % [overloaded, warnings.size()])
	assert_gte(rounded_up, most, "the board rounded up at the end of most catapults (%d of %d)" % [rounded_up, warnings.size()])


## Sails the case and returns what came before each catapult after the spin-up.
func _sail_and_read_the_catapults() -> Array[Warning]:
	var sim: WindsurferSim = WindsurferSim.create_for(EnvironmentConfig.new(), true, true)
	var wind: WindConfig = sim.wind_config
	wind.speed_kt = WIND_KT
	wind.from_bearing_deg = WIND_FROM_DEG
	wind.height_gradient_enabled = true
	wind.gusts_enabled = true
	wind.gust_intensity = 0.2
	wind.gust_period_s = 8.0
	wind.shifts_enabled = false
	sim.wind = WindField.new(wind)
	var controller: PlayerController = PlayerController.new()
	var hands: AiHands = AiHands.new()
	controller.hands = hands
	controller.set_sail(sim.sail, sim.sailor_config, sim.air_density_kg_m3)
	var controls: SimControls = SimControls.new()
	controller.reset_controls(controls)
	sim.reset(Vector3.ZERO, deg_to_rad(WIND_FROM_DEG - START_TWA_DEG))

	var warnings: Array[Warning] = []
	var history: Array[Sample] = []
	var keep: int = int(WARNING_S / DT) + 1
	var pointing: bool = false
	var was_sailing: bool = true
	var sailing_ticks: int = 0
	var overloaded_ticks: int = 0
	for i: int in int(RUN_S / DT):
		var t: Telemetry = sim.telemetry
		for field: String in PUSH:
			controller.auto_sheet_pilot.set(field, PUSH[field])
		if t.speed_ms > POINTING_SPEED_MS:
			pointing = true
		elif t.speed_ms < POINTING_SPEED_MS - 1.5:
			pointing = false
		hands.steer = LearnedSkipper.steer_toward_twa(t.twa_deg, 1.0, TWA_DEG if pointing else START_TWA_DEG)
		var sailing: bool = sim.sailor_state == WindsurferSim.SailorState.SAILING
		if sailing:
			controller.update(t, controls, DT)
		sim.step(DT, controls)
		t = sim.telemetry
		var sailing_now: bool = sim.sailor_state == WindsurferSim.SailorState.SAILING
		if sailing_now and not sailing:
			controller.reset_controls(controls)
		if was_sailing and not sailing_now and sim.fall_kind == "catapult" and t.time_s > SPIN_UP_S:
			warnings.append(_read_warning(history, t.time_s))
		was_sailing = sailing_now
		if sailing_now and t.time_s > SPIN_UP_S:
			sailing_ticks += 1
			if t.feet_moment_excess_nm > OVERLOAD_NM:
				overloaded_ticks += 1
		history.append(_sample(t))
		if history.size() > keep:
			history.pop_front()
	gut.p("overloaded in %.0f %% of all sailing time after the spin-up" % (100.0 * overloaded_ticks / maxi(sailing_ticks, 1)))
	return warnings


## On starboard tack the sail is to port: a positive excess (the body tipped to port) is toward
## the sail, and a negative yaw rate (the bow to starboard) is heading up.
func _sample(t: Telemetry) -> Sample:
	var s: Sample = Sample.new()
	s.fin_share = t.fin_load_share
	s.feet_excess_nm = t.feet_moment_excess_nm
	s.heading_up_dps = -t.yaw_rate_dps
	return s


## The history holds the ticks before the fall, the last one just before it.
func _read_warning(history: Array[Sample], time_s: float) -> Warning:
	var w: Warning = Warning.new()
	w.time_s = time_s
	var count: int = history.size()
	var last_moment: int = int(LAST_MOMENT_S / DT)
	var round_up_from: int = count - int(ROUND_UP_WITHIN_S / DT)
	for i: int in count:
		var s: Sample = history[i]
		if s.fin_share > w.fin_share_max:
			w.fin_share_max = s.fin_share
			w.fin_peak_before_s = (count - i) * DT
		if i < round_up_from:
			w.fin_share_early_max = maxf(w.fin_share_early_max, s.fin_share)
		if i < count - last_moment and s.feet_excess_nm > OVERLOAD_NM:
			w.overload_s += DT
		if i >= round_up_from:
			w.heading_up_max_dps = maxf(w.heading_up_max_dps, s.heading_up_dps)
	return w
