extends GutTest
## The gusts as patches on the open water (WindField with WindConfig.gust_patches; PHYSICS_SPEC.md
## 8.3; ROADMAP PH7): stronger and lighter patches that roll downwind with the air, with the
## settings' gust strength as their spread, the same within a few metres and new every step. The
## sines stay for the older tests and measurements.

const TOL: float = 1e-6


func _config(intensity: float = 0.2) -> WindConfig:
	var config: WindConfig = WindConfig.new()
	config.speed_kt = 18.0
	config.from_bearing_deg = 270.0  # the air moves east, +X
	config.height_gradient_enabled = false
	config.gusts_enabled = true
	config.gust_intensity = intensity
	config.gust_patches = true
	return config


## The wind relative to the mean at every point of a strip 90 km long along the wind and 9 km
## across (the fronts' cells are 900 x 4000 m, so the strip holds some 200 of them; a smaller
## window holds one or two and its average lands wherever they sit), and how often the wind is
## turned by more than 2 degrees.
func _ratios(wind: WindField, base: float) -> Dictionary[String, float]:
	var sum: float = 0.0
	var square_sum: float = 0.0
	var turned: int = 0
	var count: int = 0
	for ix: int in 60:
		for iz: int in 60:
			var velocity: Vector3 = wind.velocity_at(Vector3(ix * 1500.0 - 45000.0, 2.0, iz * 150.0 - 4500.0))
			var ratio: float = velocity.length() / base
			sum += ratio
			square_sum += ratio * ratio
			count += 1
			if absf(rad_to_deg(atan2(velocity.z, velocity.x))) > 2.0:
				turned += 1
	var mean: float = sum / count
	return {"mean": mean, "spread": sqrt(maxf(square_sum / count - mean * mean, 0.0)), "turned_share": float(turned) / count}


func test_the_patches_average_to_the_mean_and_spread_with_the_gust_strength() -> void:
	var base: float = 18.0 * SimMath.KNOT_MS
	var usual: WindField = WindField.new(_config(0.2))
	var strong: WindField = WindField.new(_config(0.4))
	var at_02: Dictionary[String, float] = _ratios(usual, base)
	var at_04: Dictionary[String, float] = _ratios(strong, base)
	assert_almost_eq(at_02["mean"], 1.0, 0.03, "over the strip the average is the settings' wind")
	assert_almost_eq(at_02["spread"], 0.2 * WindField.PATCH_SPREAD_PER_INTENSITY, 0.02, "the spread is half the gust strength: 10 % at 0.2")
	assert_almost_eq(at_04["spread"] / at_02["spread"], 2.0, 0.1, "twice the strength, twice the spread (the same patches)")
	assert_gt(at_02["turned_share"], 0.25, "the patches also turn the wind (the sideways part)")
	assert_almost_eq(usual.current_speed_ms, base, TOL, "the wind 'right now', for the HUD and the decisions, is the mean")


func test_the_patches_lie_along_the_wind() -> void:
	var config: WindConfig = _config()
	config.from_bearing_deg = 180.0  # the air moves north, -Z
	var wind: WindField = WindField.new(config)
	assert_almost_eq(wind.downwind_axis().x, 0.0, TOL)
	assert_almost_eq(wind.downwind_axis().y, -1.0, TOL, "the patches' axis is the direction the air moves in")
	assert_almost_eq(WindField.new(_config()).downwind_axis().x, 1.0, TOL, "from the west: east")


func test_the_patches_roll_downwind_with_the_air() -> void:
	var wind: WindField = WindField.new(_config())
	var speed: float = 18.0 * SimMath.KNOT_MS
	var spots: Array[Vector3] = []
	var before: PackedFloat64Array = PackedFloat64Array()
	for i: int in 20:
		spots.append(Vector3(i * 137.0 - 1000.0, 2.0, (i * 71) % 500 - 250.0))
		before.append(wind.patch_unit_at(spots[i]).x)
	for i: int in 10:
		wind.step(0.5)
	var travelled: float = wind.pattern().drift_ms(speed) * 5.0
	assert_almost_eq(wind.travel_m, travelled, TOL, "the air travels at the pattern's drift speed")
	assert_almost_eq(travelled, 1.1 * speed * 5.0, TOL, "1.1 times the wind")
	var moved_closer: int = 0
	for i: int in 20:
		var moved: float = wind.patch_unit_at(spots[i] + Vector3(travelled, 0.0, 0.0)).x
		var stayed: float = wind.patch_unit_at(spots[i]).x
		assert_almost_eq(moved, before[i], 0.2, "5 s later the patch is %.0f m downwind (spot %d)" % [travelled, i])
		if absf(moved - before[i]) < absf(stayed - before[i]):
			moved_closer += 1
	assert_gt(moved_closer, 12, "the patches move with the air rather than stay (%d of 20)" % moved_closer)


func test_the_same_patch_within_three_metres_and_a_new_one_each_step() -> void:
	var wind: WindField = WindField.new(_config())
	var at: Vector3 = Vector3(300.0, 2.0, -120.0)
	var unit: Vector2 = wind.patch_unit_at(at)
	assert_eq(wind.patch_unit_at(at + Vector3(2.0, 0.0, 1.0)), unit, "the sail, the mast and the sailor get the same patch")
	assert_ne(wind.patch_unit_at(at + Vector3(40.0, 0.0, 0.0)), unit, "40 m on it is another")
	wind.step(2.0)
	assert_ne(wind.patch_unit_at(at), unit, "after a step the patch has rolled on")
	var along: float = wind.velocity_at(at).dot(-wind.from_direction()) / wind.current_speed_ms
	assert_almost_eq(along, maxf(1.0 + wind.patch_unit_at(at).x * 0.1, WindField.LULL_FLOOR), TOL,
		"along the wind: the mean times 1 + the patch x the spread (0.1 at strength 0.2)")


func test_the_sines_stay_for_the_old_measurements_and_the_default_pattern_loads() -> void:
	var config: WindConfig = _config()
	config.gust_patches = false
	config.gust_period_s = 8.0
	var sines: WindField = WindField.new(config)
	for i: int in 100:
		sines.step(0.02)
	assert_almost_eq(sines.current_speed_ms / (18.0 * SimMath.KNOT_MS), 1.10184, 1e-3, "the sines' hand value at 2 s (test_wind_and_water.gd)")
	assert_eq(sines.velocity_at(Vector3(500.0, 2.0, 500.0)), sines.velocity_at(Vector3(-500.0, 2.0, -500.0)), "the same everywhere at once")
	assert_eq(sines.patch_unit_at(Vector3.ZERO), Vector2.ZERO, "no patch")
	assert_false(sines.uses_patches())
	assert_null(sines.pattern())
	var patches: WindField = WindField.new(_config())
	assert_true(patches.uses_patches())
	assert_not_null(patches.pattern(), "the default pattern is loaded when the config names none")
	assert_eq(patches.pattern().resource_path, WindField.DEFAULT_PATTERN_PATH)
	assert_true(WindConfig.new().gust_patches, "the game's gusts are patches")
	assert_true((load("res://config/wind_default.tres") as WindConfig).gust_patches)
	# With the gusts off nothing changes, patches or not.
	config = _config()
	config.gusts_enabled = false
	var calm: WindField = WindField.new(config)
	assert_eq(calm.velocity_at(Vector3(500.0, 2.0, 500.0)), calm.velocity_at(Vector3(-500.0, 2.0, -500.0)))
	assert_false(calm.uses_patches())
	assert_eq(calm.patch_spread_share(), 0.0)
