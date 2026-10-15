extends GutTest
## The Maloja's moving weather (MAP_SILVAPLANA_PLAN.md, W3; WindGusts): the random numbers are exact
## 32-bit arithmetic (as on the graphics card), the noise has the spread it claims, the gusts keep
## the mean wind and add knots (so they reach full strength in a weak place), fronts reach across
## the lake and lanes lie along the wind (the satellite photos), the gusts roll down the lake with
## the air and change only slowly, the wind turns in them (0.8 times the ups and downs, Panofsky and
## Dutton), the pulses and shifts are the station's size, and the same moment gives the same wind.

const CONFIG_PATH: String = "res://maps/silvaplana/map_config.tres"
const PATTERN_PATH: String = "res://maps/silvaplana/wind/maloja_pattern.json"
const DAY_PATH: String = "res://maps/silvaplana/wind/maloja_day.tres"
const GUSTS_PATH: String = "res://maps/silvaplana/wind/maloja_gusts.tres"
const GROUND_PATH: String = "res://maps/silvaplana/wind/ground.json"
## Three places on the lake's middle line, metres along it from the middle.
const ALONG_M: Array[float] = [-1300.0, 0.0, 1300.0]

var _config: MapConfig
var _wind: MapWind


func before_all() -> void:
	_config = load(CONFIG_PATH)
	_wind = MapWind.load_from(PATTERN_PATH, DAY_PATH, _config, GUSTS_PATH)


func test_random_numbers_are_exact_32_bit_arithmetic() -> void:
	# Reference values from Python, whose whole numbers have no size limit, so (x * c) & 0xFFFFFFFF
	# is exactly what the graphics card's 32-bit numbers give.
	var hashes: Dictionary[int, int] = {1: 1753845952, 12345: 2435775735, 0xFFFFFFFF: 1734902346, 0x80000000: 3427483940}
	for x: int in hashes:
		assert_eq(WindGusts._hash32(x), hashes[x], "hash of %d" % x)
	assert_almost_eq(WindGusts._corner(0, 0, 0, 4), -0.2516488119148763, 1e-12)
	assert_almost_eq(WindGusts._corner(3, -2, 7, 5), 0.7031356496045216, 1e-12, "negative corners too")
	assert_almost_eq(WindGusts._corner(-1000, 250, -3, 6), 0.8944218381993523, 1e-12)
	assert_almost_eq(WindGusts._corner(123456, -654321, 2, 7), 0.7434927136040044, 1e-12)


func test_noise_has_a_spread_of_one_everywhere() -> void:
	# Over random places, and also exactly on the grid's corners, in the middle of the cells, and on
	# the lake's middle line (which lies on a grid line): on average zero, spread 1.
	var random: RandomNumberGenerator = RandomNumberGenerator.new()
	random.seed = 7
	for where: String in ["anywhere", "corners", "middles", "on a grid line"]:
		var values: PackedFloat32Array = PackedFloat32Array()
		for i: int in 20000:
			var p: Vector3 = Vector3(random.randf_range(-500.0, 500.0), random.randf_range(-500.0, 500.0), random.randf_range(-500.0, 500.0))
			if where == "corners":
				p = p.floor()
			elif where == "middles":
				p = p.floor() + Vector3(0.5, 0.5, 0.5)
			elif where == "on a grid line":
				p.y = 0.0
			values.append(WindGusts.noise_3d(p.x, p.y, p.z, 9))
		assert_almost_eq(_mean(values), 0.0, 0.03, "On average zero, %s: as many lulls as gusts" % where)
		assert_almost_eq(_spread(values), 1.0, 0.03, "Spread 1, %s" % where)
	var gusts: PackedFloat32Array = PackedFloat32Array()
	for i: int in 20000:
		gusts.append(_wind.gusts.gusts_at(random.randf_range(-1e5, 1e5), random.randf_range(-700.0, 700.0),
			random.randf_range(10.0, 20.0) * 3600.0).x)
	assert_almost_eq(_spread(gusts), 1.0, 0.03, "The gusts have a spread of 1 before they are scaled to knots")


func test_noise_is_smooth() -> void:
	# No jumps, also not at the cells' edges: ten times smaller steps give about ten times smaller
	# changes (a jump would stay the same size).
	var largest: Array[float] = [0.0, 0.0]
	for i: int in 3000:
		var x: float = i * 0.001
		for k: int in 2:
			var step: float = 0.01 if k == 0 else 0.001
			largest[k] = maxf(largest[k], absf(WindGusts.noise_3d(x + step, 0.3, 0.7, 5) - WindGusts.noise_3d(x, 0.3, 0.7, 5)))
	assert_lt(largest[1], largest[0] / 5.0, "Largest change over 0.001 of a cell (%.4f) against over 0.01 (%.4f)" % [largest[1], largest[0]])


func test_places_are_on_the_lake() -> void:
	var ground: TerrainGrid = TerrainGrid.load_from(GROUND_PATH)
	for along: float in ALONG_M:
		var place: Vector3 = _place(along, 0.0)
		assert_almost_eq(ground.height_at(place.x, place.z), 0.0, 1.0, "%.0f m along the lake is water" % along)


func test_gusts_keep_the_mean() -> void:
	for along: float in ALONG_M:
		var gusty: PackedFloat32Array = PackedFloat32Array()
		var smooth: PackedFloat32Array = PackedFloat32Array()
		for i: int in 900:
			var now: WindMoment = _wind.moment(13.0 * 3600.0 + i * 8.0)
			gusty.append(_wind.velocity_in(now, _place(along, 0.0)).length())
			smooth.append(_wind.velocity_in(_calm(now), _place(along, 0.0)).length())
		assert_almost_eq(_mean(gusty) / _mean(smooth), 1.0, 0.03, "Two afternoon hours %.0f m along the lake" % along)


func test_a_gust_adds_knots_also_in_a_weak_place() -> void:
	# Over a weak place (the south-east band) and a strong one (the middle), the gusts add their
	# knots (the spread times the noise), not a share of the local wind.
	var now: WindMoment = _wind.moment(14.5 * 3600.0)
	for lv95: Vector2 in [Vector2(2780900.0, 1146500.0), Vector2(2780300.0, 1146700.0)]:
		var place: Vector3 = _config.lv95_to_game(lv95.x, lv95.y, _config.lake_level_m)
		var xz: Vector2 = Vector2(place.x, place.z)
		var along: float = xz.dot(_wind.lake_axis)
		var across: float = xz.dot(Vector2(-_wind.lake_axis.y, _wind.lake_axis.x))
		var gust: Vector2 = _wind.gusts.gusts_at(along - now.travel_m, across, now.time_of_day_s) * now.spread_ms * _wind.gusts.gustiness(along)
		var with_gust: Vector3 = _wind.velocity_in(now, place)
		var without: Vector3 = _wind.velocity_in(_calm(now), place)
		var direction: Vector3 = without.normalized()
		assert_almost_eq(with_gust.dot(direction) - without.length(), gust.x, 0.001, "Along the wind at %s" % lv95)
		assert_almost_eq(with_gust.dot(Vector3(-direction.z, 0.0, direction.x)), gust.y * _wind.gusts.sideways_share, 0.001, "Sideways at %s" % lv95)


func test_fronts_reach_across_the_lake_and_lanes_lie_along_the_wind() -> void:
	var fronts: WindGusts = _wind.gusts.duplicate()
	fronts.front_share = 1.0
	var lanes: WindGusts = _wind.gusts.duplicate()
	lanes.front_share = 0.0
	# Fronts: 600 m across the lake (about its width) almost the same; 600 m along it, not.
	assert_gt(_correlation(fronts, Vector2(0.0, 600.0)), 0.9, "A front reaches across the lake")
	assert_lt(_correlation(fronts, Vector2(600.0, 0.0)), 0.6, "but not far along it")
	# Lanes: more alike along the wind than across it, at the same distance.
	assert_gt(_correlation(lanes, Vector2(80.0, 0.0)), _correlation(lanes, Vector2(0.0, 80.0)) + 0.1, "Lanes lie along the wind")


func test_gusts_roll_down_the_lake_with_the_air() -> void:
	# A minute later, as far down the lake as the air travelled, the gusts are mostly the same (they
	# change slowly while they roll); at the same place they are other gusts.
	var t: float = 14.5 * 3600.0
	var later_s: float = 60.0
	var moved_m: float = _wind.travel_m(t + later_s) - _wind.travel_m(t)
	assert_almost_eq(moved_m, later_s * _wind.gusts.drift_ms(_wind.day.lake_speed_ms(t)), 3.0, "The air moves at the drift speed")
	var rolled: Array[PackedFloat32Array] = [PackedFloat32Array(), PackedFloat32Array()]
	var still: Array[PackedFloat32Array] = [PackedFloat32Array(), PackedFloat32Array()]
	var before: WindMoment = _wind.moment(t)
	var after: WindMoment = _wind.moment(t + later_s)
	for i: int in 300:
		for across: float in [-300.0, 0.0, 300.0]:
			var place: Vector3 = _place(-1500.0 + i * 5.0, across)
			var gust_before: float = _gust_ms(before, place)
			rolled[0].append(gust_before)
			rolled[1].append(_gust_ms(after, place + Vector3(_wind.lake_axis.x, 0.0, _wind.lake_axis.y) * moved_m))
			still[0].append(gust_before)
			still[1].append(_gust_ms(after, place))
	var followed: float = _pair_correlation(rolled[0], rolled[1])
	var same_place: float = _pair_correlation(still[0], still[1])
	assert_gt(followed, 0.8, "Followed down the lake: mostly the same gusts")
	assert_lt(same_place, followed - 0.3, "At the same place: other gusts (%.2f against %.2f)" % [same_place, followed])


func test_the_wind_turns_in_the_gusts() -> void:
	# At random places on the lake and random afternoon moments: the gusts' part of the wind along
	# the wind has the set spread, and sideways (which turns the wind) 0.8 times that (Panofsky and
	# Dutton). Turned into degrees that is about 0.8 x spread / wind speed.
	var random: RandomNumberGenerator = RandomNumberGenerator.new()
	random.seed = 11
	var along_parts: PackedFloat32Array = PackedFloat32Array()
	var side_parts: PackedFloat32Array = PackedFloat32Array()
	for i: int in 3000:
		var now: WindMoment = _wind.moment(random.randf_range(13.0, 17.0) * 3600.0)
		var place: Vector3 = _place(random.randf_range(-1200.0, 1200.0), random.randf_range(-300.0, 300.0))
		var without: Vector3 = _wind.velocity_in(_calm(now), place)
		var gust: Vector3 = _wind.velocity_in(now, place) - without
		var direction: Vector3 = without.normalized()
		along_parts.append(gust.dot(direction) / now.spread_ms)
		side_parts.append(gust.dot(Vector3(-direction.z, 0.0, direction.x)) / now.spread_ms)
	assert_almost_eq(_spread(along_parts), 1.0, 0.08, "Along the wind: the set spread")
	assert_almost_eq(_spread(side_parts) / _spread(along_parts), _wind.gusts.sideways_share, 0.08, "Sideways: 0.8 times as much")


func test_pulses_and_shifts_like_the_station() -> void:
	# Over a day, every 30 s: the station's 10-minute means are within +-8 % half the time (a spread
	# of about 12 %) and turn with a spread of 6 degrees.
	var pulses: PackedFloat32Array = PackedFloat32Array()
	var shifts: PackedFloat32Array = PackedFloat32Array()
	for i: int in 2880:
		pulses.append(_wind.gusts.pulse(i * 30.0))
		shifts.append(rad_to_deg(_wind.gusts.shift_rad(i * 30.0)))
	assert_between(_spread(pulses), 0.07, 0.14, "Pulses")
	assert_between(_spread(shifts), 4.0, 8.0, "Shifts, degrees")


func test_the_same_moment_gives_the_same_wind() -> void:
	var t: float = 15.0 * 3600.0 + 12.3
	assert_eq(_wind.velocity_at(_place(200.0, 100.0), t), _wind.velocity_at(_place(200.0, 100.0), t))


func test_no_jumps_from_one_moment_to_the_next() -> void:
	# A tenth of a second later the wind is almost the same.
	var largest_kt: float = 0.0
	var previous: float = _wind.speed_ms_at(_place(0.0, 0.0), 13.0 * 3600.0)
	for i: int in range(1, 600):
		var speed: float = _wind.speed_ms_at(_place(0.0, 0.0), 13.0 * 3600.0 + i * 0.1)
		largest_kt = maxf(largest_kt, absf(speed - previous) / SimMath.KNOT_MS)
		previous = speed
	assert_lt(largest_kt, 0.3, "The largest change in 0.1 s, knots")


## A place on the lake, metres along its middle line from the middle (downwind positive) and across.
func _place(along_m: float, across_m: float) -> Vector3:
	var axis: Vector2 = _wind.lake_axis
	var xz: Vector2 = axis * along_m + Vector2(-axis.y, axis.x) * across_m
	return Vector3(xz.x, 0.0, xz.y)


## The same moment without the gusts and lulls (the pulses and shifts stay).
func _calm(now: WindMoment) -> WindMoment:
	var calm: WindMoment = _wind.moment(now.time_of_day_s)
	calm.spread_ms = 0.0
	return calm


## The gusts' part of the speed at a place, m/s.
func _gust_ms(now: WindMoment, place: Vector3) -> float:
	return _wind.velocity_in(now, place).length() - _wind.velocity_in(_calm(now), place).length()


## How alike a gust pattern is at two places a distance apart (along the lake, across it), over many places.
func _correlation(gusts: WindGusts, offset: Vector2) -> float:
	var first: PackedFloat32Array = PackedFloat32Array()
	var second: PackedFloat32Array = PackedFloat32Array()
	var random: RandomNumberGenerator = RandomNumberGenerator.new()
	random.seed = 3
	for i: int in 3000:
		var along: float = random.randf_range(-1e5, 1e5)
		var across: float = random.randf_range(-300.0, 300.0)
		var t: float = random.randf_range(10.0, 20.0) * 3600.0
		first.append(gusts.gusts_at(along, across, t).x)
		second.append(gusts.gusts_at(along + offset.x, across + offset.y, t).x)
	return _pair_correlation(first, second)


func _pair_correlation(a: PackedFloat32Array, b: PackedFloat32Array) -> float:
	var mean_a: float = _mean(a)
	var mean_b: float = _mean(b)
	var ab: float = 0.0
	var aa: float = 0.0
	var bb: float = 0.0
	for i: int in a.size():
		ab += (a[i] - mean_a) * (b[i] - mean_b)
		aa += (a[i] - mean_a) * (a[i] - mean_a)
		bb += (b[i] - mean_b) * (b[i] - mean_b)
	return ab / sqrt(aa * bb)


func _mean(values: PackedFloat32Array) -> float:
	var total: float = 0.0
	for value: float in values:
		total += value
	return total / values.size()


## The standard deviation: how far the values typically are from their mean.
func _spread(values: PackedFloat32Array) -> float:
	var mean: float = _mean(values)
	var total: float = 0.0
	for value: float in values:
		total += (value - mean) * (value - mean)
	return sqrt(total / values.size())
