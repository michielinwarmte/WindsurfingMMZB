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
	var controller: PlayerController = PlayerController.new()
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
