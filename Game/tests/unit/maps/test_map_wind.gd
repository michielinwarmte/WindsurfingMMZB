extends GutTest
## The wind analyser's wind (MAP_SILVAPLANA_PLAN.md, W2): the Maloja pattern reads back as written
## by tools/map/windninja_pattern.py, the average day has the measured numbers, the wind blows the
## right way, the graphics card's copy of the pattern says the same as the game's numbers (WD1),
## and the clock and the colour scale behave.

const CONFIG_PATH: String = "res://maps/silvaplana/map_config.tres"
const PATTERN_PATH: String = "res://maps/silvaplana/wind/maloja_pattern.json"
const GROUND_PATH: String = "res://maps/silvaplana/wind/ground.json"
const DAY_PATH: String = "res://maps/silvaplana/wind/maloja_day.tres"

# LV95 east, north (as in test_silvaplana_terrain.gd).
const STATION: Vector2 = Vector2(2778576.0, 1144976.0)  # MeteoSwiss Segl-Maria, stands at 1804 m
const LAKE_MIDDLE: Vector2 = Vector2(2780500.0, 1146600.0)
const CORVATSCH: Vector2 = Vector2(2782788.5, 1142434.75)  # summit, 3451 m

var _config: MapConfig
var _wind: MapWind
var _ground: TerrainGrid


func before_all() -> void:
	_config = load(CONFIG_PATH)
	_wind = MapWind.load_from(PATTERN_PATH, DAY_PATH, _config)
	_ground = TerrainGrid.load_from(GROUND_PATH)


func test_pattern_loads() -> void:
	assert_not_null(_wind, "The Maloja pattern and day should load")
	if _wind == null:
		return
	assert_eq(_wind.pattern.columns, 440, "22 km at 50 m")
	assert_eq(_wind.pattern.rows, 400, "20 km at 50 m")
	assert_almost_eq(_wind.pattern.lake_from_deg, 221.9, 0.05, "The lake's average direction (W1)")


func test_lake_middle_is_about_average() -> void:
	var point: Vector3 = _game(LAKE_MIDDLE)
	var factor: float = _wind.pattern.speed_factor_at(point.x, point.z)
	assert_between(factor, 0.77, 1.3, "The lake's middle is within the lake's range (W1)")
	assert_between(_wind.pattern.turn_deg_at(point.x, point.z), -15.0, 15.0, "Along the lake")


func test_station_reads_as_in_the_file() -> void:
	# windninja_pattern.py wrote what the pattern says at Segl-Maria; the game must read the same.
	var info: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PATTERN_PATH))
	var station: Vector3 = _game(STATION)
	assert_almost_eq(_wind.pattern.speed_factor_at(station.x, station.z), float(info["station_segl_maria"]["speed_factor"]), 0.05)
	assert_almost_eq(_wind.pattern.turn_deg_at(station.x, station.z), float(info["station_segl_maria"]["turn_deg"]), 2.0)


func test_the_maloja_blows_down_the_lake() -> void:
	var point: Vector3 = _game(LAKE_MIDDLE)
	var afternoon_s: float = 14.5 * 3600.0
	var velocity: Vector3 = _wind.velocity_at(point, afternoon_s)
	# From the south-west, so the air moves to the north-east: east is +X, north is -Z.
	assert_gt(velocity.x, 0.0, "The air moves east")
	assert_lt(velocity.z, 0.0, "The air moves north")
	assert_eq(velocity.y, 0.0, "Horizontal")
	var from_deg: float = _wind.from_deg_at(point, afternoon_s)
	assert_between(from_deg, 210.0, 235.0, "Along the lake, about 222 degrees")
	# The velocity, the speed and the direction tell the same story.
	var from_velocity_deg: float = fposmod(rad_to_deg(atan2(-velocity.x, velocity.z)), 360.0)
	assert_almost_eq(from_velocity_deg, from_deg, 0.01, "Direction of the velocity")
	assert_almost_eq(velocity.length(), _wind.speed_ms_at(point, afternoon_s), 0.001, "Speed of the velocity")


func test_the_average_day() -> void:
	var day: WindDay = _wind.day
	# The station's 13.0 kt at 14:20, times 1.3 on the water.
	assert_almost_eq(day.lake_speed_ms(14.33 * 3600.0) / SimMath.KNOT_MS, 16.9, 0.01, "Afternoon on the water")
	assert_lt(day.lake_speed_ms(10.0 * 3600.0), day.lake_speed_ms(12.0 * 3600.0), "It builds in the morning")
	assert_lt(day.lake_speed_ms(20.0 * 3600.0), day.lake_speed_ms(17.0 * 3600.0), "It fades in the evening")
	assert_almost_eq(day.turn_deg(14.33 * 3600.0), 0.0, 0.01, "The afternoon is the reference")
	assert_lt(day.turn_deg(21.0 * 3600.0), -10.0, "It turns left in the evening")
	assert_almost_eq(day.lake_speed_ms(8.0 * 3600.0), day.lake_speed_ms(10.33 * 3600.0), 0.001, "Before the first hour: its value")


func test_graphics_card_pattern_matches_the_numbers() -> void:
	# wind_pattern.gdshaderinc samples the texture at uv = ((xz - origin) / cell + 0.5) / cells,
	# and the graphics card interpolates between pixel centres. Do the same here by hand.
	var image: Image = _wind.pattern.to_image(_ground)
	assert_eq(image.get_size(), Vector2i(440, 400))
	var pattern: WindPattern = _wind.pattern
	for lv95: Vector2 in [LAKE_MIDDLE, STATION, Vector2(2779400.0, 1145600.0), Vector2(2781600.0, 1147500.0)]:
		var point: Vector3 = _game(lv95)
		var uv: Vector2 = ((Vector2(point.x, point.z) - Vector2(pattern.x0_m, pattern.z0_m)) / pattern.cell_m + Vector2(0.5, 0.5)) \
			/ Vector2(pattern.columns, pattern.rows)
		var sampled: Color = _bilinear(image, uv)
		var arrow: Vector2 = pattern.arrow_at(point.x, point.z)
		assert_almost_eq(sampled.r, arrow.x, 0.0001, "Along, at %s" % lv95)
		assert_almost_eq(sampled.g, arrow.y, 0.0001, "Clockwise, at %s" % lv95)


func test_ground_under_the_wind() -> void:
	assert_not_null(_ground, "The ground grid should load: " + GROUND_PATH)
	if _ground == null:
		return
	var lake: Vector3 = _game(LAKE_MIDDLE)
	assert_almost_eq(_ground.height_at(lake.x, lake.z), 0.0, 1.0, "The lake's surface")
	var station: Vector3 = _game(STATION)
	assert_almost_eq(_ground.height_at(station.x, station.z), 1804.0 - _config.lake_level_m, 5.0, "The station's ground")
	var corvatsch: Vector3 = _game(CORVATSCH)
	assert_gt(_ground.height_at(corvatsch.x, corvatsch.z), 1500.0, "Piz Corvatsch, 1660 m above the lake (a 50 m mean)")


func test_clock() -> void:
	var clock: WindClock = WindClock.new()
	clock.set_time(14.0 * 3600.0)
	clock.rate = 60.0
	clock.advance(1.0)
	assert_almost_eq(clock.time_of_day_s, 14.0 * 3600.0 + 60.0, 0.001, "60x: a minute per second")
	assert_eq(clock.text(), "14:01:00")
	clock.paused = true
	clock.advance(1.0)
	assert_almost_eq(clock.time_of_day_s, 14.0 * 3600.0 + 60.0, 0.001, "Paused")
	clock.set_time(5.0 * 3600.0)
	assert_eq(clock.time_of_day_s, WindClock.DAY_START_S, "Kept within the day")
	clock.set_time(WindClock.DAY_END_S - 10.0)
	clock.paused = false
	clock.advance(1.0)
	assert_eq(clock.time_of_day_s, WindClock.DAY_END_S, "Stops at the end of the day")
	assert_true(clock.paused, "and pauses there")


func test_colours_are_windfinders() -> void:
	# Each stop has exactly its colour (read from Windfinder's legend), beyond the top the last one,
	# and the water's texture is the same scale as the legend's.
	for i: int in WindColors.STOP_KNOTS.size():
		var colour: Color = WindColors.color_for(WindColors.STOP_KNOTS[i])
		assert_almost_eq(colour.r, WindColors.STOP_COLORS[i].r, 0.002, "%d kt" % WindColors.STOP_KNOTS[i])
		assert_almost_eq(colour.g, WindColors.STOP_COLORS[i].g, 0.002, "%d kt" % WindColors.STOP_KNOTS[i])
		assert_almost_eq(colour.b, WindColors.STOP_COLORS[i].b, 0.002, "%d kt" % WindColors.STOP_KNOTS[i])
	assert_eq(WindColors.color_for(80.0), WindColors.STOP_COLORS[WindColors.STOP_COLORS.size() - 1], "53 kt and more")
	var between: Color = WindColors.color_for(17.0)
	assert_almost_eq(between.g, (WindColors.STOP_COLORS[4].g + WindColors.STOP_COLORS[5].g) / 2.0, 0.002, "17 kt: halfway between 15 and 19")
	assert_eq(WindColors.texture().gradient.colors, WindColors.STOP_COLORS, "The water uses the legend's colours")


func _game(lv95: Vector2) -> Vector3:
	return _config.lv95_to_game(lv95.x, lv95.y, _config.lake_level_m)


## What a graphics card returns for a linear-filtered texture at a uv: the four nearest pixel
## centres, interpolated; the edge pixel beyond the edge.
func _bilinear(image: Image, uv: Vector2) -> Color:
	var size: Vector2 = Vector2(image.get_size())
	var p: Vector2 = uv * size - Vector2(0.5, 0.5)
	var x0: int = clampi(floori(p.x), 0, image.get_width() - 1)
	var y0: int = clampi(floori(p.y), 0, image.get_height() - 1)
	var x1: int = mini(x0 + 1, image.get_width() - 1)
	var y1: int = mini(y0 + 1, image.get_height() - 1)
	var tx: float = clampf(p.x - x0, 0.0, 1.0)
	var ty: float = clampf(p.y - y0, 0.0, 1.0)
	var top: Color = image.get_pixel(x0, y0).lerp(image.get_pixel(x1, y0), tx)
	var bottom: Color = image.get_pixel(x0, y1).lerp(image.get_pixel(x1, y1), tx)
	return top.lerp(bottom, ty)
