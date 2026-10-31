extends GutTest
## RaceWindClock, the race's one clock for every board's wind (ROADMAP RA13): two fields made ten
## seconds apart see the gusts in different places; handed one clock they show the same time, the
## same air travelled and the same gust at every spot, and after a step of the same length still
## do. The lake's field takes the time of day too.

const DT: float = 1.0 / 60.0


static func _gusty_config() -> WindConfig:
	var wind: WindConfig = (load(SettingsValues.WIND_DEFAULT_PATH) as WindConfig).duplicate()
	wind.gusts_enabled = true
	wind.gust_patches = true
	wind.gust_intensity = 0.3
	wind.shifts_enabled = true
	return wind


func test_two_fields_handed_one_clock_see_the_same_gusts_and_keep_seeing_them() -> void:
	var first: WindField = WindField.new(_gusty_config())
	for t: int in 600:
		first.step(DT)
	var later: WindField = WindField.new(_gusty_config())
	var spot: Vector3 = Vector3(250.0, 3.0, -80.0)
	assert_ne(later.patch_unit_at(spot), first.patch_unit_at(spot), "made 10 s later: another gust at the spot")
	var clock: RaceWindClock = RaceWindClock.of(first)
	assert_almost_eq(clock.time_s, 10.0, 1e-6)
	assert_eq(clock.travel_m, first.travel_m)
	assert_eq(clock.time_of_day_s, -1.0, "the open water has no time of day")
	clock.hand_to(later)
	clock.hand_to(first)
	for t: int in 3:
		first.step(DT / 3.0)
		later.step(DT / 3.0)
	assert_eq(later.time_s, first.time_s)
	assert_eq(later.travel_m, first.travel_m)
	assert_eq(later.current_from_bearing_rad, first.current_from_bearing_rad, "the same shift")
	for k: int in 5:
		var at: Vector3 = spot + Vector3(37.0 * k, 0.0, -53.0 * k)
		assert_eq(later.velocity_at(at), first.velocity_at(at), "the same wind %d" % k)
	# Handing a field the clock it shows changes nothing.
	var before: Vector3 = first.velocity_at(spot)
	RaceWindClock.of(first).hand_to(first)
	assert_eq(first.velocity_at(spot), before)


func test_the_lakes_field_takes_the_time_of_day_too() -> void:
	if not TrainingDrops.lake_available():
		pending("the lake's data is not here (Git LFS)")
		return
	var environment: EnvironmentConfig = load(TrainingDrops.LAKE_ENVIRONMENT_PATH)
	var map_wind: MapWind = environment.map_wind()
	var a: MapWindField = MapWindField.new(map_wind, environment.wind_or_default(), 14.5 * 3600.0, environment.map_wind_height_m)
	var b: MapWindField = MapWindField.new(map_wind, environment.wind_or_default(), 15.0 * 3600.0, environment.map_wind_height_m)
	for t: int in 60:
		a.step(DT)
	var clock: RaceWindClock = RaceWindClock.of(a)
	assert_almost_eq(clock.time_of_day_s, 14.5 * 3600.0 + 1.0, 1e-3, "the lake's time of day")
	clock.hand_to(b)
	b.step(DT)
	a.step(DT)
	assert_eq(b.time_of_day_s(), a.time_of_day_s())
	assert_eq(b.time_s, a.time_s)
	var on_the_lake: Vector3 = Vector3(300.0, 2.0, -600.0)
	assert_eq(b.velocity_at(on_the_lake), a.velocity_at(on_the_lake), "the same wind on the lake")
