extends GutTest
## Ventilation, the spin-out (PH6, E01.S03; FinConfig.ventilates; PHYSICS_SPEC.md section 4,
## "Ventilation"): the research's tests 1 to 5 (Documentation/reports/research/
## ph6_ventilation_ph15_wind_shadow.md), on the fin model's own step.

const DT: float = 1.0 / 240.0
const SPAN_M: float = 0.38


func _fin(ventilates: bool = true) -> FinModel:
	var config: FinConfig = (load("res://config/fin_default.tres") as FinConfig).duplicate()
	config.ventilates = ventilates
	return FinModel.new(config)


## Steps the fin's ventilation for this long at a steady slip and speed, fully in the water, the
## root at this depth.
func _hold(fin: FinModel, slip_deg: float, speed_ms: float, seconds: float, root_depth_m: float = 0.0) -> void:
	var cl_wetted: float = absf(fin.lift_coefficient(deg_to_rad(slip_deg)))
	for i: int in int(round(seconds / DT)):
		fin.ventilate(slip_deg, speed_ms, SPAN_M, root_depth_m, cl_wetted, DT)


func test_switched_off_nothing_ventilates() -> void:
	var fin: FinModel = _fin(false)
	_hold(fin, 20.0, 10.0, 1.0)
	assert_eq(fin.ventilated_share, 0.0, "off: the fin of before, even past the inception slip")
	assert_false(fin.ventilating)


func test_below_the_inception_slip_nothing_changes() -> void:
	var fin: FinModel = _fin()
	_hold(fin, 14.0, 10.0, 1.0)
	assert_eq(fin.ventilated_share, 0.0, "14 deg, under the 15 deg inception (stall peak 12 + 3)")


func test_past_the_inception_slip_the_air_spreads_in_three_time_constants() -> void:
	var fin: FinModel = _fin()
	var chord_m: float = fin.config.area_m2 / fin.config.span_m
	var time_constant_s: float = fin.config.vent_inception_chords * chord_m / 10.0
	_hold(fin, 16.0, 10.0, 3.0 * time_constant_s)
	assert_true(fin.ventilating, "16 deg with the root at the surface: it starts")
	assert_gt(fin.ventilated_share, 0.95, "past 0.95 within three time constants (%.0f ms)" % (3000.0 * time_constant_s))


func test_a_ventilated_fin_keeps_the_given_share_of_its_lift() -> void:
	var fin: FinModel = _fin()
	_hold(fin, 16.0, 10.0, 1.0)
	var factor: float = 1.0 - fin.ventilated_share * (1.0 - fin.config.vent_lift_ratio)
	assert_almost_eq(factor, fin.config.vent_lift_ratio, 0.001, "fully ventilated: 0.4 of the wetted lift")


func test_it_comes_back_only_when_nearly_unloaded() -> void:
	# Hysteresis: started at 16 deg, still ventilated at 5 deg (10 m/s), wetted again at 1.5 deg.
	var fin: FinModel = _fin()
	_hold(fin, 16.0, 10.0, 1.0)
	_hold(fin, 5.0, 10.0, 1.0)
	assert_true(fin.ventilating, "5 deg is above the washout at 10 m/s: it stays")
	assert_gt(fin.ventilated_share, 0.95)
	_hold(fin, 1.5, 10.0, 1.0)
	assert_false(fin.ventilating, "1.5 deg is below it: it washes out")
	assert_lt(fin.ventilated_share, 0.01)


func test_a_fin_brought_down_from_wetted_never_ventilates() -> void:
	var fin: FinModel = _fin()
	for slip_deg: float in [14.0, 10.0, 5.0, 1.0]:
		_hold(fin, slip_deg, 10.0, 0.5)
	assert_eq(fin.ventilated_share, 0.0, "the same angles on the way down, started wetted: never")


func test_the_washout_slip_falls_with_the_speed() -> void:
	# The research's table for this fin: 8.5 deg at 5 m/s, 2.1 deg at 10 m/s, worked out with the
	# linear lift slope (5.0 per rad). At 5 m/s the needed coefficient (0.746) is past the curve's
	# linear end at 8 deg (0.698), where the curve rises more slowly: 9.2 deg on the game's curve.
	var fin: FinModel = _fin()
	assert_almost_eq(fin.washout_slip_deg(5.0, SPAN_M), 9.2, 0.2, "5 m/s")
	assert_almost_eq(fin.washout_slip_deg(10.0, SPAN_M), 2.1, 0.2, "10 m/s")


func test_no_air_path_no_ventilation() -> void:
	var fin: FinModel = _fin()
	_hold(fin, 18.0, 10.0, 1.0, 0.20)
	assert_eq(fin.ventilated_share, 0.0, "the root 0.2 m deep, sealed: no ventilation before deep stall")


func test_a_loose_tail_starts_it_earlier() -> void:
	var fin: FinModel = _fin()
	var cl_wetted: float = absf(fin.lift_coefficient(deg_to_rad(13.0)))
	for i: int in 240:
		fin.ventilate(13.0, 10.0, 0.30, -0.08, cl_wetted, DT)
	assert_true(fin.ventilating, "13 deg with the root 8 cm out of the water: past the 12 deg of a loose tail")
	assert_almost_eq(fin.vent_inception_deg, 12.0, 0.001)


func test_a_reset_clears_it() -> void:
	var sim: WindsurferSim = WindsurferSim.create_default()
	sim.fin_config = sim.fin_config.duplicate()
	sim.fin_config.ventilates = true
	sim.fin = FinModel.new(sim.fin_config)
	sim.fin.ventilated_share = 0.7
	sim.fin.ventilating = true
	sim.reset(Vector3.ZERO, 0.0)
	assert_eq(sim.fin.ventilated_share, 0.0)
	assert_false(sim.fin.ventilating)
