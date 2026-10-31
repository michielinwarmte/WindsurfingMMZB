extends GutTest
## The front foot's couple (PH28, P1.1; SailorConfig.front_foot_pull_held_n and _brief_n): in the
## straps and planing, while the board rides below the trim aimed for, the rider hangs further
## back than the pull in the hands holds and the front foot, pulling up in its strap, holds the
## body there. The pitch part of the feet's moment is what the two straps can pass (Max: 150 to
## 250 N held, about 400 N briefly, "correct"; times the straps' spread, 0.59 m).

const DT: float = 1.0 / 180.0


func _sim() -> WindsurferSim:
	var sim: WindsurferSim = WindsurferSim.create_default()
	sim.sailor_config = sim.sailor_config.duplicate()
	sim.reset(Vector3.ZERO, deg_to_rad(180.0))
	sim.step(1.0 / 60.0, SimControls.new())
	return sim


## The held couple's bound: the held pull times the straps' spread read from the board.
func _held_nm(sim: WindsurferSim) -> float:
	var spread_m: float = sim.board_config.front_strap_from_tail_m - sim.board_config.back_strap_from_tail_m
	return sim.sailor_config.front_foot_pull_held_n * spread_m


func test_the_straps_spread_and_the_pulls_come_from_the_configs() -> void:
	var sim: WindsurferSim = _sim()
	var spread_m: float = sim.board_config.front_strap_from_tail_m - sim.board_config.back_strap_from_tail_m
	assert_almost_eq(spread_m, 0.59, 1e-6, "Max's Patrik 115: the front straps 0.59 m ahead of the back straps")
	# 150 N: the low end of Max's 150 to 250 N held (the autopilot suite, rounds 4 and 5: with 200
	# the 24 kt broad reach in gusts and waves fell at both dials, with 150 not at all).
	assert_eq(sim.sailor_config.front_foot_pull_held_n, 150.0, "the low end of Max's 150 to 250 N held")
	assert_eq(sim.sailor_config.front_foot_pull_brief_n, 400.0, "about 400 N briefly")
	assert_almost_eq(_held_nm(sim), 88.5, 1e-3, "88.5 N m held: 150 N times the straps' 0.59 m")


func test_the_rider_pulls_only_in_the_straps_planing_and_with_the_nose_below_the_aim() -> void:
	var sim: WindsurferSim = _sim()
	sim.stance = 1.0
	sim.felt_trim_deg = -2.0  # far below the aim of about 2 degrees
	assert_almost_eq(sim._front_foot_couple_nm(true, 13.0), _held_nm(sim), 1e-6, "far below the aim: the held pull, no more")
	sim.felt_trim_deg = sim._running_trim_target_deg(13.0) - 0.5 * sim.sailor_config.trim_press_band_deg
	assert_almost_eq(sim._front_foot_couple_nm(true, 13.0), 0.5 * _held_nm(sim), 1e-6, "half a band below: half the pull")
	sim.felt_trim_deg = 6.0
	assert_eq(sim._front_foot_couple_nm(true, 13.0), 0.0, "the nose above the aim: no pull")
	sim.felt_trim_deg = -2.0
	assert_eq(sim._front_foot_couple_nm(false, 13.0), 0.0, "below the hump (not trimming): no pull")
	sim.stance = 0.5
	assert_eq(sim._front_foot_couple_nm(true, 13.0), 0.0, "not yet in the straps: no pull")


func test_the_feet_pass_no_more_pitch_than_the_straps_hold() -> void:
	var sim: WindsurferSim = _sim()
	sim.stance = 1.0
	# All the weight on the back strap: the feet's pressure point at the back strap.
	sim.feet_body = Vector3(0.0, 0.065, sim._back_strap_z_m)
	var legs: Vector3 = sim.body.up_axis() * 800.0
	var held: float = _held_nm(sim)
	var brief: float = sim.sailor_config.front_foot_pull_brief_n / sim.sailor_config.front_foot_pull_held_n * held
	# Nose-up beyond the held pull: the brief pull for tip_time_s, then the held pull only.
	var passed: Array[float] = []
	for i: int in int(0.5 / DT):
		passed.append(sim._feet_pitch_within_straps(1000.0, legs, DT))
	assert_almost_eq(passed[0], brief, 1e-3, "at first the brief pull: 400 N times the spread")
	assert_almost_eq(passed[passed.size() - 1], held, 1e-3, "after tip_time_s the held pull: 200 N times the spread")
	assert_eq(sim._feet_pitch_within_straps(50.0, legs, DT), 50.0, "within the held pull all of it passes")
	# Nose-down: all the weight on the front foot and the back foot's pull (the same strength).
	sim._front_foot_hard_s = 0.0
	var spread_m: float = sim._back_strap_z_m - sim._front_strap_z_m
	var down_held: float = 800.0 * spread_m + held
	sim._front_foot_hard_s = 1.0
	assert_almost_eq(sim._feet_pitch_within_straps(-5000.0, legs, DT), -down_held, 1e-3, "the weight on the front foot and the back foot's pull")
	# Out of the straps the feet stand where they like: all of it, as before PH28.
	sim.stance = 0.5
	assert_eq(sim._feet_pitch_within_straps(1000.0, legs, DT), 1000.0, "out of the straps nothing is capped")


## Sails the 18 kt beam reach with the test autopilot; returns the mean pitch (degrees, bow up),
## speed and the largest pitch moment the feet passed over the last seconds.
func _beam_reach(pull_n: float) -> Dictionary:
	var sim: WindsurferSim = WindsurferSim.create_default()
	sim.sailor_config = sim.sailor_config.duplicate()
	sim.sailor_config.front_foot_pull_held_n = pull_n
	sim.sailor_config.front_foot_pull_brief_n = 2.0 * pull_n
	sim.wind_config = sim.wind_config.duplicate()
	sim.wind_config.speed_kt = 18.0
	sim.wind = WindField.new(sim.wind_config)
	sim.reset(Vector3.ZERO, deg_to_rad(180.0))
	var pilot: Autopilot = Autopilot.new()
	pilot.sail = sim.sail
	var controls: SimControls = SimControls.new()
	var step: float = 1.0 / 60.0
	var pitch_sum: float = 0.0
	var speed_sum: float = 0.0
	var feet_max: float = 0.0
	var count: int = 0
	for i: int in int(30.0 / step):
		pilot.update(sim.telemetry, controls, step)
		sim.step(step, controls)
		if sim.time_s > 22.0:
			pitch_sum += rad_to_deg(sim.body.pitch_rad())
			speed_sum += sim.telemetry.speed_ms
			feet_max = maxf(feet_max, sim.body.to_body(sim.feet_moment_world).x)
			count += 1
	return {"pitch_deg": pitch_sum / count, "speed_ms": speed_sum / count, "feet_max_nm": feet_max, "couple_nm": sim.front_foot_couple_nm, "fallen": sim.sailor_state != WindsurferSim.SailorState.SAILING}


func test_the_front_foot_lifts_the_nose_at_speed_within_its_bound() -> void:
	var without: Dictionary = _beam_reach(0.0)
	var pulled: Dictionary = _beam_reach(200.0)
	gut.p("18 kt beam reach, 22 to 30 s: without the pull %.2f deg at %.2f m/s; pulling %.2f deg at %.2f m/s, the couple %.0f N m, the feet's pitch moment at most %.0f N m" % [
		without.pitch_deg, without.speed_ms, pulled.pitch_deg, pulled.speed_ms, pulled.couple_nm, pulled.feet_max_nm])
	assert_false(without.fallen or pulled.fallen, "both sailing")
	# Not slower: a planing board rides flatter as it goes faster (Savitsky; Gourlay & Martellotta's
	# trim falls with the speed squared), so a nose riding higher at the same or a higher speed is
	# the pull's doing, not the speed's.
	assert_gt(pulled.speed_ms, 0.98 * without.speed_ms, "at the same speed or faster")
	assert_gt(pulled.pitch_deg, without.pitch_deg + 0.3, "the front foot's pull lifts the nose")
	# The weight on the back foot plus at most the brief pull: never more than the board's own
	# numbers allow (here the pressure point is at or near the back strap).
	assert_lt(pulled.feet_max_nm, 800.0 * 0.59 + 2.0 * 118.0, "bounded")
