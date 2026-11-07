extends GutTest
## The feet's press (GP2, package B after Max's play-test of 6 November 2026: "the feet need to stay
## in the straps, like real life, but the pressure and rotation is different"). The mouse no longer
## only moves the targets the technique aims for: it presses with the feet in the straps, the toes
## against the heels (a roll moment) and the back foot against the front foot (the weight between
## the straps, a pitch moment). Documentation/reports/gameplay/gp2_feet_pressure.md and
## PHYSICS_SPEC.md section 7.5 ("The feet's press").

const DT: float = 1.0 / 60.0


# --- Left in the middle, exactly as before ----------------------------------------------------

## The numbers these runs gave before the feet's press was built (commit 15577e3, 6 November 2026),
## printed with every digit: position x, y, z, velocity x, y, z (the body's own single-precision
## vectors, printed to their 8 digits), heel, pitch (rad), the trim press, the lean, the hang-back, the
## bank the feet aimed for, the felt heel beyond it, the felt trim (doubles, every digit).
const BEFORE_BEAM_18: PackedFloat64Array = [53.40284, -0.030380882, 218.8905, 2.4075768, 0.14397098, 11.282923,
	-0.03281290840506981, 0.0027254446157580175, -0.17107085108726966, 0.9330797402038, 0.3523990516302733,
	0.051446205336697734, 0.08686234706421636, -0.520012082189188]
const BEFORE_BROAD_24: PackedFloat64Array = [165.11053, -0.01130816, 174.45326, 9.295016, -0.026723847, 8.468216,
	0.0024620265862072737, 0.02242283847282003, -0.2250000000000001, 0.6362137335907085, 0.4447512701388048,
	0.004133325531430691, 0.0002689158135211063, 0.5206415604932066]
## The doubles to their last few digits: the script's reading of a long decimal literal can differ
## from the printed number in the last bit, and any change of the sailing moves them by far more.
static func _last_digits(value: float) -> float:
	return absf(value) * 1e-13 + 1e-16


## The vectors' 8 printed digits: a millionth of a metre (any change of the sailing moves them by
## centimetres after 25 s of waves and gusts).
const VECTOR_DIGITS: float = 1e-5


func test_left_in_the_middle_the_board_sails_exactly_as_before() -> void:
	var beam: PackedFloat64Array = _run(18.0, 100.0, 0.75, 25.0)
	var broad: PackedFloat64Array = _run(24.0, 135.0, NAN, 25.0)
	if BEFORE_BEAM_18.is_empty():
		print("BEAM_18 ", _digits(beam))
		print("BROAD_24 ", _digits(broad))
		fail_test("the numbers from before are not filled in yet")
		return
	for i: int in beam.size():
		if i < 6:
			assert_almost_eq(beam[i], BEFORE_BEAM_18[i], VECTOR_DIGITS, "18 kt beam reach, number %d" % i)
			assert_almost_eq(broad[i], BEFORE_BROAD_24[i], VECTOR_DIGITS, "24 kt broad reach, number %d" % i)
		else:
			assert_almost_eq(beam[i], BEFORE_BEAM_18[i], _last_digits(BEFORE_BEAM_18[i]), "18 kt beam reach, number %d" % i)
			assert_almost_eq(broad[i], BEFORE_BROAD_24[i], _last_digits(BEFORE_BROAD_24[i]), "24 kt broad reach, number %d" % i)


## The player's beginner controller with the auto-sheet on the game's open water (waves, gusts, the
## wind's height gradient), held on a true wind angle by AiHands (as the push harness sails it), with
## a body left in the middle (it writes its presses, at 0) and the push slider at `push` (NaN: none).
func _run(wind_kt: float, twa_deg: float, push: float, seconds: float) -> PackedFloat64Array:
	var sim: WindsurferSim = WindsurferSim.create_for(EnvironmentConfig.new(), true, true)
	sim.wind_config.speed_kt = wind_kt
	sim.wind_config.from_bearing_deg = 270.0
	sim.wind_config.gusts_enabled = true
	sim.wind_config.shifts_enabled = false
	sim.wind = WindField.new(sim.wind_config)
	# The stance as it was before the balance stance of 7 November 2026 (the physics realism audit,
	# finding B: the step back for the rig's pull and a nose driven down): these numbers are from before it.
	sim.sailor_config.stance_balance_share = 0.0
	sim.sailor_config.stance_dive_full_deg = 0.0
	sim.sailor_config.stance_bow_high_deg = 0.0
	var controller: PlayerController = PlayerController.new()
	# The controller as it sailed before the lake's chop technique (its defaults since the autopilot's
	# training of 6 November 2026, Documentation/reports/autopilot/lake_chop_training.md): this test
	# is about the feet's press left in the middle, and its numbers are from before that training.
	controller.head_up_alpha_deg = 90.0
	# And the key as it was before the tap smoothing of 7 November 2026 (no ramp, the rail at once).
	controller.steer_rise_s = 0.0
	controller.steer_fall_s = 0.0
	controller.tap_rail_full_s = 0.0
	controller.rail_full_ms = 0.0
	controller.airborne_alpha_deg = 90.0
	controller.push_level = push
	var hands: AiHands = AiHands.new()
	hands.push = push
	controller.hands = hands
	controller.body = MouseBody.new()
	controller.set_sail(sim.sail, sim.sailor_config, sim.air_density_kg_m3)
	var controls: SimControls = SimControls.new()
	controller.reset_controls(controls)
	sim.reset(Vector3.ZERO, deg_to_rad(fposmod(270.0 - minf(twa_deg, 100.0), 360.0)))
	for i: int in int(seconds / DT):
		var wanted_twa: float = twa_deg if sim.telemetry.speed_ms > 9.0 else minf(twa_deg, 100.0)
		hands.steer = LearnedSkipper.steer_toward_twa(sim.telemetry.twa_deg, 1.0, wanted_twa)
		if sim.sailor_state == WindsurferSim.SailorState.SAILING:
			controller.update(sim.telemetry, controls, DT)
		sim.step(DT, controls)
	var p: Vector3 = sim.body.position
	var v: Vector3 = sim.body.velocity
	return PackedFloat64Array([p.x, p.y, p.z, v.x, v.y, v.z, sim.body.heel_rad(), sim.body.pitch_rad(),
		sim.trim_press_m, sim.lean, sim.hang_back_m, sim._wanted_bank_rad, sim._felt_heel_beyond_rad, sim.felt_trim_deg])


func _digits(values: PackedFloat64Array) -> String:
	var parts: PackedStringArray = []
	for value: float in values:
		parts.append(var_to_str(value))
	return ", ".join(parts)


# --- What the press does -----------------------------------------------------------------------

## A board planing on an 18 kt beam reach (TWA 100) on flat water in a steady wind, under the
## player's controller with the auto-sheet, held on course by AiHands, for `seconds`. The feet's press
## is then written on the controls by the test (no body: the controller leaves the presses alone).
func _planing(controls: SimControls, seconds: float) -> Array:
	var sim: WindsurferSim = WindsurferSim.create_for(EnvironmentConfig.new(), false, true)
	sim.wind_config.speed_kt = 18.0
	sim.wind_config.from_bearing_deg = 270.0
	sim.wind_config.gusts_enabled = false
	sim.wind_config.shifts_enabled = false
	sim.wind = WindField.new(sim.wind_config)
	var controller: PlayerController = PlayerController.new()
	var hands: AiHands = AiHands.new()
	controller.hands = hands
	controller.set_sail(sim.sail, sim.sailor_config, sim.air_density_kg_m3)
	controller.reset_controls(controls)
	sim.reset(Vector3.ZERO, deg_to_rad(170.0))
	var run: Array = [sim, controller, hands]
	_sail(run, controls, seconds)
	return run


## Sails on for `seconds` with the controls' presses as they are; returns the means of the leeward
## heel (degrees), the trim (degrees), the feet's roll press as a share of their most
## (Telemetry.toes_share) and the weight's share on the back foot.
func _sail(run: Array, controls: SimControls, seconds: float) -> Vector4:
	var sim: WindsurferSim = run[0]
	var controller: PlayerController = run[1]
	var hands: AiHands = run[2]
	var sums: Vector4 = Vector4.ZERO
	var n: int = int(seconds / DT)
	for i: int in n:
		hands.steer = LearnedSkipper.steer_toward_twa(sim.telemetry.twa_deg, 1.0, 100.0)
		var roll: float = controls.feet_roll_press
		var pitch: float = controls.feet_pitch_press
		controller.update(sim.telemetry, controls, DT)
		controls.feet_roll_press = roll
		controls.feet_pitch_press = pitch
		sim.step(DT, controls)
		var t: Telemetry = sim.telemetry
		# Starboard tack: the leeward rail is the port one, a negative heel.
		sums += Vector4(-t.heel_deg, t.trim_deg, t.toes_share, t.back_foot_share)
	return sums / float(maxi(n, 1))


func test_the_press_moves_at_the_pace_of_a_weight_shift() -> void:
	var controls: SimControls = SimControls.new()
	var run: Array = _planing(controls, 20.0)
	var sim: WindsurferSim = run[0]
	assert_true(sim.telemetry.is_planing, "planing on the 18 kt beam reach")
	assert_almost_eq(sim.stance, 1.0, 1e-6, "in the straps")
	assert_eq(sim.feet_pitch_press, 0.0, "nothing pressed yet")
	var time_s: float = sim.sailor_config.feet_press_time_s
	assert_almost_eq(time_s, 0.4, 1e-9, "the default: 0.4 s from the middle to an end")
	controls.feet_pitch_press = 1.0
	controls.feet_roll_press = -1.0
	_sail(run, controls, 0.5 * time_s)
	assert_almost_eq(sim.feet_pitch_press, 0.5, 0.03, "half way in half the time")
	assert_almost_eq(sim.feet_roll_press, -0.5, 0.03)
	_sail(run, controls, 0.6 * time_s)
	assert_eq(sim.feet_pitch_press, 1.0, "all the way in feet_press_time_s")
	assert_eq(sim.feet_roll_press, -1.0)
	assert_eq(sim.telemetry.feet_pitch_press, 1.0, "the telemetry reports it")
	controls.feet_pitch_press = 0.0
	controls.feet_roll_press = 0.0
	_sail(run, controls, 1.1 * time_s)
	assert_eq(sim.feet_pitch_press, 0.0, "back to the technique at the same pace")
	assert_eq(sim.feet_roll_press, 0.0)


func test_the_back_foot_puts_the_weight_on_the_back_strap_and_lifts_the_nose() -> void:
	var controls: SimControls = SimControls.new()
	var run: Array = _planing(controls, 20.0)
	var sim: WindsurferSim = run[0]
	var middle: Vector4 = _sail(run, controls, 4.0)
	controls.feet_pitch_press = 1.0
	_sail(run, controls, 2.0)
	var technique_press_m: float = sim.trim_press_m
	var back: Vector4 = _sail(run, controls, 4.0)
	assert_eq(sim.trim_press_m, technique_press_m, "pressed all the way, the technique's own search waits")
	assert_gt(back.w, 0.98, "all the weight on the back foot (the back strap)")
	assert_almost_eq(sim.feet_body.z, sim._back_strap_z_m, 1e-3, "the feet's pressure at the back strap")
	controls.feet_pitch_press = -1.0
	_sail(run, controls, 2.0)
	var front: Vector4 = _sail(run, controls, 4.0)
	assert_lt(front.w, 0.02, "all the weight on the front foot (the front strap)")
	assert_gt(back.y, middle.y + 0.1, "the back foot lifts the nose: trim %.2f against %.2f in the middle" % [back.y, middle.y])
	assert_lt(front.y, middle.y - 0.1, "the front foot puts it down: trim %.2f" % front.y)


func test_the_toes_rail_the_board_and_the_heels_flatten_it() -> void:
	var controls: SimControls = SimControls.new()
	var run: Array = _planing(controls, 20.0)
	var middle: Vector4 = _sail(run, controls, 4.0)
	controls.feet_roll_press = 1.0
	_sail(run, controls, 2.0)
	var toes: Vector4 = _sail(run, controls, 4.0)
	controls.feet_roll_press = -1.0
	_sail(run, controls, 2.0)
	var heels: Vector4 = _sail(run, controls, 4.0)
	assert_gt(toes.x, middle.x + 4.0, "the toes put the leeward rail down: %.1f against %.1f degrees" % [toes.x, middle.x])
	# (Across the wind the fin rails the board too: the feet need little more of their moment for it.)
	assert_lt(heels.z, -0.8, "the heels press with nearly all the feet have: %.2f" % heels.z)
	assert_lt(heels.x, middle.x - 1.0, "and bring the board flatter: %.1f degrees" % heels.x)


func test_the_press_waits_below_planing_and_in_a_turn() -> void:
	var sim: WindsurferSim = WindsurferSim.create_for(EnvironmentConfig.new(), false, true)
	sim.reset(Vector3.ZERO, deg_to_rad(180.0))
	var controls: SimControls = SimControls.new()
	controls.sheet = 0.0
	controls.feet_roll_press = 1.0
	controls.feet_pitch_press = 1.0
	for i: int in int(1.0 / DT):
		sim.step(DT, controls)
	assert_eq(sim.feet_roll_press, 0.0, "at rest, out of the straps: no press")
	assert_eq(sim.feet_pitch_press, 0.0)
	var planing: SimControls = SimControls.new()
	var run: Array = _planing(planing, 20.0)
	var board: WindsurferSim = run[0]
	planing.feet_roll_press = 1.0
	planing.feet_pitch_press = 1.0
	planing.lean = 1.0
	# The controller writes the lean every tick; held here for a step at a time.
	for i: int in int(0.5 / DT):
		board.step(DT, planing)
	assert_eq(board.feet_roll_press, 0.0, "asking for a turn: the toes and heels are the turn's")
	assert_gt(board.feet_pitch_press, 0.3, "the weight between the feet still moves (as far as the carving board still planes)")
