extends GutTest
## Phase 5: the validation sailed again on the default sea (a 14 m swell of 8 cm with a
## little 7 m chop, crests about 0.1 m above the still level). On and off the wind the
## numbers stay close to flat water, upwind too since the rig stopped rolling with the hull
## (PHYSICS_SPEC.md 7.5: a rig fixed to the deck swung through the wind on every wave and
## lost a quarter of the speed upwind). The board must sit on the surface and nobody falls.

const RUN_S: float = 50.0


func _sail_flat_and_on_waves(angle: float, speed_tolerance: float = 0.15) -> void:
	var flat: ValidationRun = ValidationRun.sail(angle, RUN_S, 15.0, true, false)
	var waves: ValidationRun = ValidationRun.sail(angle, RUN_S, 15.0, true, true)
	assert_false(waves.fell, "no fall on waves at TWA %.0f" % angle)
	assert_false(waves.nan, "no NaN on waves at TWA %.0f" % angle)
	var flat_speed: float = flat.settled_speed_ms()
	var wave_speed: float = waves.settled_speed_ms()
	gut.p("TWA %.0f: flat %.2f m/s, waves %.2f m/s (%.1f %%), heel spread %.1f deg, pitch spread %.1f deg" % [
		angle, flat_speed, wave_speed, 100.0 * (wave_speed / flat_speed - 1.0), waves.settled_spread(waves.heel_deg), waves.settled_spread(waves.pitch_deg)])
	assert_almost_eq(wave_speed, flat_speed, speed_tolerance * flat_speed, "the settled speed on waves is within %.0f %% of flat water at TWA %.0f" % [speed_tolerance * 100.0, angle])
	assert_lt(waves.settled_spread(waves.pitch_deg), 12.0, "the board pitches less than 12 degrees peak to peak on the swell")
	# The board stays on the surface: the hull's origin within a thickness of the water
	# height under it, on average over the last 10 s.
	var field: WaveField = waves.sim.water as WaveField
	assert_not_null(field, "the run was on waves")
	var origin: Vector3 = waves.sim.body.origin_world()
	var surface: float = field.height_at(origin.x, origin.z, waves.sim.time_s)
	assert_lt(absf(origin.y - surface), 0.3, "the hull sits at the surface (origin %.2f m from the water)" % (origin.y - surface))


func test_beam_reach_on_waves() -> void:
	_sail_flat_and_on_waves(90.0)


func test_broad_reach_on_waves() -> void:
	_sail_flat_and_on_waves(120.0)


func test_upwind_on_waves() -> void:
	# Into the swell the hull slams on every face; with the rig held still by the sailor it
	# loses only a few percent (it lost a quarter when the rig rolled with the hull).
	_sail_flat_and_on_waves(60.0, 0.15)
