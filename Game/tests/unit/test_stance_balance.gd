extends GutTest
## The balance stance (the physics realism audit, 7 November 2026,
## Documentation/reports/physics/realism_audit_7nov2026.md, finding B): the sailor feels the nose driven
## down by the rig's pull and steps back at any speed (stance_dive_from_deg to stance_dive_full_deg, the
## pitch felt over stance_feel_time_s), and lets the weight forward when the board stands on its tail
## (stance_bow_high_deg); the anticipation (stance_balance_share) is off by default. Switched off, the
## stance follows the speed alone as before.

const DT: float = 1.0 / 60.0


## A start from rest in a steady wind on flat water at a true wind angle, the player's controller
## with the auto-sheet held on the angle by AiHands; returns the lowest pitch (deg), the stance at
## 1 s and the speed at the end (m/s).
func _start(wind_kt: float, twa_deg: float, seconds: float, balance_on: bool) -> Vector3:
	# Flat water, and the sim's own copies of the configs (so switching the balance off here does not
	# reach the shared resources other tests load).
	var sim: WindsurferSim = WindsurferSim.create_for(EnvironmentConfig.new(), false, true)
	sim.wind_config.speed_kt = wind_kt
	sim.wind_config.from_bearing_deg = 270.0
	sim.wind_config.gusts_enabled = false
	sim.wind_config.shifts_enabled = false
	sim.wind = WindField.new(sim.wind_config)
	# The felt step on as the player's switch puts it (off by default for every board).
	sim.sailor_config.stance_dive_full_deg = SailorConfig.BALANCE_STANCE_FULL_DEG if balance_on else 0.0
	var controller: PlayerController = PlayerController.new()
	var hands: AiHands = AiHands.new()
	controller.hands = hands
	controller.set_sail(sim.sail, sim.sailor_config, sim.air_density_kg_m3)
	var controls: SimControls = SimControls.new()
	controller.reset_controls(controls)
	sim.reset(Vector3.ZERO, deg_to_rad(fposmod(270.0 - twa_deg, 360.0)))
	var lowest_deg: float = 0.0
	var stance_half_s: float = 0.0
	for i: int in int(seconds / DT):
		hands.steer = LearnedSkipper.steer_toward_twa(sim.telemetry.twa_deg, 1.0, twa_deg)
		if sim.sailor_state == WindsurferSim.SailorState.SAILING:
			controller.update(sim.telemetry, controls, DT)
		sim.step(DT, controls)
		lowest_deg = minf(lowest_deg, rad_to_deg(sim.body.pitch_rad()))
		if i == int(1.0 / DT):
			stance_half_s = sim.stance
	return Vector3(lowest_deg, stance_half_s, sim.telemetry.speed_ms)


func test_a_strong_wind_start_buries_the_nose_less_with_the_balance() -> void:
	var before: Vector3 = _start(24.0, 130.0, 4.0, false)
	var now: Vector3 = _start(24.0, 130.0, 4.0, true)
	assert_gt(now.y, before.y + 0.2, "the sailor is further back a second after the start (%.2f against %.2f)" % [now.y, before.y])
	assert_gt(now.x, before.x + 2.0, "the nose goes down at least 2 degrees less (%.1f against %.1f)" % [now.x, before.x])


func test_a_light_wind_broad_reach_keeps_the_weight_forward() -> void:
	# At 12 kt the pull is small: the anticipated half of its moment must not send the weight to the
	# straps of a board that is not planing (at the full moment the reach check's 12 kt broad reach
	# sank its tail and fell).
	var run: Vector3 = _start(12.0, 135.0, 6.0, true)
	assert_lt(run.y, 0.5, "the weight stays forward of the straps (stance %.2f)" % run.y)
	assert_gt(run.x, -6.0, "and the board does not pitch far (lowest %.1f deg)" % run.x)


func test_off_by_default_and_the_setting_too() -> void:
	assert_almost_eq(SailorConfig.new().stance_dive_full_deg, 0.0, 1e-9, "off for every board by default")
	assert_false(SettingsValues.new().balance_stance, "the player's switch is off by default")


func test_switched_off_the_stance_follows_the_speed_alone() -> void:
	var off: Vector3 = _start(24.0, 130.0, 1.0, false)
	assert_almost_eq(off.y, 0.0, 0.05, "below stance_speed_start_ms the stance stays at rest with the balance off")
