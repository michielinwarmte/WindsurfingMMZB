extends GutTest
## The board's effects on the water (Documentation/reports/waves/board_fx.md): the plume behind the
## tail only at speed, far boards' spray switched off, a landing's splash as big as the landing,
## the spray off the crests only in a strong wind with whitecaps, the bow wave's V only at
## displacement speed at Kelvin's angle, the carve's inside rail, the foam patches fading, and the
## effects of a puppet board (LAN: never stepped, its state written) following that state.


# --- Spray -------------------------------------------------------------------------------------

func test_no_spray_or_plume_below_walking_pace() -> void:
	assert_eq(WindsurferEffects.spray_intensity(1.4, 0.0), 0.0, "No spray at walking pace")
	assert_eq(WindsurferEffects.plume_intensity(1.4, 1.0), 0.0, "No plume at walking pace")
	assert_eq(WindsurferEffects.plume_intensity(10.0, 0.0), 0.0, "No plume off the plane")
	assert_gt(WindsurferEffects.plume_intensity(14.0, 1.0), 0.9, "A full plume planing at 27 knots")
	assert_gt(WindsurferEffects.plume_intensity(10.0, 1.0, 1.0), WindsurferEffects.plume_intensity(10.0, 1.0, 0.0),
		"A loaded fin throws more")


func test_nearly_all_spray_off_the_leeward_rail() -> void:
	# Wind from starboard: port to leeward.
	var shares: Vector2 = WindsurferEffects.spray_side_shares(40.0, 0.0)
	assert_gt(shares.x, 0.85, "The leeward rail throws nearly all of it")


func test_far_boards_draw_no_spray() -> void:
	assert_eq(WindsurferEffects.distance_share(10.0), 1.0, "Near the camera: all of it")
	var middle: float = WindsurferEffects.distance_share(60.0)
	assert_true(middle > 0.0 and middle < 1.0, "Fading between 40 and 80 m")
	assert_eq(WindsurferEffects.distance_share(100.0), 0.0, "None beyond 80 m")


# --- Splashes -----------------------------------------------------------------------------------

func test_a_landing_splash_grows_with_the_landing() -> void:
	var slap: float = WindsurferEffects.splash_strength(SplashTrigger.RISE_WEIGHTS, 0.0)
	assert_almost_eq(slap, 0.2, 1e-6, "A slap just over the trigger: the smallest splash")
	assert_gt(WindsurferEffects.splash_strength(4.0, 0.0), slap, "A harder landing, a bigger splash")
	assert_gt(WindsurferEffects.splash_strength(2.5, 2.0), slap, "Coming down faster, a bigger splash")
	assert_almost_eq(WindsurferEffects.splash_strength(5.5, 0.0), 1.0, 1e-6, "Full at 3 weights over the trigger")
	assert_almost_eq(WindsurferEffects.splash_strength(2.5, 3.0), 1.0, 1e-6, "Full coming down at 3 m/s")


func test_a_bigger_splash_throws_higher_and_steeper() -> void:
	var small: Vector4 = WaterParticles.splash_shape(0.2)
	var big: Vector4 = WaterParticles.splash_shape(1.0)
	assert_gt(big.x, small.x, "Faster drops")
	assert_gt(big.y, small.y, "A wider ring")
	assert_gt(big.z, small.z, "More drops")
	assert_lt(big.w, small.w, "A tall crown, not a low fan")
	# The fastest drops of the biggest splash rise about 1.8 m (v^2 / 2g).
	assert_almost_eq(big.x * big.x / (2.0 * 9.81), 1.84, 0.05, "About 1.8 m high")


# --- Spray off the crests ----------------------------------------------------------------------

func test_crest_spray_only_in_a_strong_wind() -> void:
	var area_m2: float = 600.0
	var knot: float = SimMath.KNOT_MS
	assert_eq(WindsurferEffects.crest_spray_rate(18.0 * knot, area_m2), 0.0, "None at 18 kt")
	assert_eq(WindsurferEffects.crest_spray_rate(24.9 * knot, area_m2), 0.0, "None below 25 kt")
	var at_30: float = WindsurferEffects.crest_spray_rate(30.0 * knot, area_m2)
	assert_gt(at_30, 0.5, "Some at 30 kt")
	assert_gt(WindsurferEffects.crest_spray_rate(34.0 * knot, area_m2), at_30, "More at 34 kt")
	assert_lt(WindsurferEffects.crest_spray_rate(30.0 * knot, area_m2, LakeLook.FRESH_WATER_FACTOR), at_30,
		"Less on fresh water (fewer whitecaps)")


func test_crest_spray_follows_the_whitecaps() -> void:
	# At full onset the bursts are the whitecap cover's crests: twice the area, twice the bursts.
	var wind_ms: float = 36.0 * SimMath.KNOT_MS
	var one: float = WindsurferEffects.crest_spray_rate(wind_ms, 100.0)
	assert_almost_eq(WindsurferEffects.crest_spray_rate(wind_ms, 200.0), 2.0 * one, 1e-6, "In proportion to the area")
	var cover: float = LakeLook.sea_whitecap_percent(wind_ms) / 100.0
	assert_almost_eq(one, cover * 100.0 / WindsurferEffects.WHITECAP_AREA_M2 / WindsurferEffects.WHITECAP_LIFE_S, 1e-6,
		"One burst per breaking crest")


# --- The wake -----------------------------------------------------------------------------------

func test_bow_wave_only_at_displacement_speed() -> void:
	assert_eq(WakeTrail.bow_wave_strength(0.0, 0.0), 0.0, "None at rest")
	assert_gt(WakeTrail.bow_wave_strength(2.0, 0.0), 0.9, "Full about the hull speed")
	assert_eq(WakeTrail.bow_wave_strength(2.0, 1.0), 0.0, "None planing")
	assert_eq(WakeTrail.bow_wave_strength(8.0, 0.0), 0.0, "None at speed")


func test_bow_wave_opens_at_kelvins_angle() -> void:
	# 19.47 degrees either side: 3 m behind the bow an arm is 1.06 m out.
	assert_almost_eq(WakeTrail.arm_offset_m(3.0), 3.0 * tan(deg_to_rad(19.47)), 1e-6, "Kelvin's angle")
	assert_almost_eq(WakeTrail.arm_offset_m(3.0), 1.06, 0.01, "1.06 m out at 3 m")
	assert_eq(WakeTrail.arm_offset_m(-1.0), 0.0, "Nothing ahead of the bow")


func test_the_carve_is_the_inside_rail() -> void:
	assert_gt(WakeTrail.carve_of(12.0, 20.0, 8.0), 0.7, "Starboard rail down in a turn: starboard in")
	assert_lt(WakeTrail.carve_of(-12.0, -20.0, 8.0), -0.7, "Port rail down: port in")
	assert_eq(WakeTrail.carve_of(12.0, 0.0, 8.0), 0.0, "Heeled but not turning: no carve")
	assert_eq(WakeTrail.carve_of(12.0, 20.0, 0.5), 0.0, "Not moving: no carve")


func test_foam_patches_fade_and_are_kept_few() -> void:
	var sim: WindsurferSim = WindsurferSim.create_default(true)
	var wake: WakeTrail = WakeTrail.new()
	add_child_autofree(wake)
	wake.setup(sim)
	for i: int in WakeTrail.MAX_PATCHES + 3:
		wake.add_foam_patch(Vector3(float(i), 0.0, 0.0), 2.0, 1.0)
	assert_eq(wake.patch_count(), WakeTrail.MAX_PATCHES, "At most MAX_PATCHES at once")
	sim.time_s += WakeTrail.FOAM_LIFE_SEA_S * WakeTrail.FOAM_LIVES + 0.1
	wake.add_tail(Vector3.ZERO, 0.0)
	assert_eq(wake.patch_count(), 0, "Gone after their life")


func test_the_wake_draws_the_trail_the_v_and_the_patches() -> void:
	var sim: WindsurferSim = WindsurferSim.create_default(true)
	var wake: WakeTrail = WakeTrail.new()
	add_child_autofree(wake)
	wake.setup(sim)
	# A slow board moving north (-Z): a trail, the bow wave's V, and a patch.
	for i: int in 12:
		sim.time_s += 0.25
		wake.add_tail(Vector3(0.0, 0.0, -0.5 * float(i)), 0.3, 0.0, 2.0, 1.0)
	wake.add_foam_patch(Vector3.ZERO, 2.0, 1.0)
	wake.follow_tail(Vector3(0.0, 0.0, -6.0), Vector2(0.0, -1.0), 2.4, sim.time_s)
	var mesh: ImmediateMesh = wake.mesh as ImmediateMesh
	assert_eq(mesh.get_surface_count(), 4, "The trail, two arms of the V and the patches")


# --- A puppet (LAN) -----------------------------------------------------------------------------

func test_a_puppets_effects_follow_its_written_state() -> void:
	var windsurfer: WindsurferNode = (load("res://windsurfer/windsurfer.tscn") as PackedScene).instantiate() as WindsurferNode
	windsurfer.is_puppet = true
	windsurfer.wind_flag_wanted = false
	add_child_autofree(windsurfer)
	var effects: WindsurferEffects = windsurfer.get_node("Effects") as WindsurferEffects
	# The other PC's state, written: planing at 12 m/s on starboard tack (wind from starboard).
	var t: Telemetry = windsurfer.sim.telemetry
	for i: int in 20:
		windsurfer.sim.time_s += 1.0 / 60.0
		windsurfer.sim.body.set_origin_world(Vector3(0.0, 0.0, -0.2 * float(i)))
		t.speed_ms = 12.0
		t.planing_ratio = 1.0
		t.awa_deg = 40.0
		windsurfer.step_physics(1.0 / 60.0)
		windsurfer.after_step()
	var amounts: Vector3 = effects.spray_amounts()
	assert_gt(amounts.x, 0.5, "The leeward (port) rail throws spray")
	assert_gt(amounts.z, 0.0, "The tail throws a plume")
	assert_gt(effects.wake().point_count(), 5, "The puppet leaves a wake")
	# Stopped: no spray.
	t.speed_ms = 0.0
	t.planing_ratio = 0.0
	windsurfer.sim.time_s += 1.0 / 60.0
	windsurfer.after_step()
	assert_eq(effects.spray_amounts(), Vector3.ZERO, "No spray at rest")
