extends GutTest
## The lee along Lake Silvaplana's south-east shore (MAP_SILVAPLANA_PLAN.md, W3; WindLee, measured by
## tools/map/shore_lee.py): it lies along the south-east shore from the Sils end to the north-east
## bend and not elsewhere, it deepens when the wind comes from further left and when it is stronger,
## only the strongest 1 in 10 gusts get into it (Max), such a gust lifts it to the open lake's wind,
## and away from the band the wind is untouched.

const CONFIG_PATH: String = "res://maps/silvaplana/map_config.tres"
const PATTERN_PATH: String = "res://maps/silvaplana/wind/maloja_pattern.json"
const DAY_PATH: String = "res://maps/silvaplana/wind/maloja_day.tres"
const GUSTS_PATH: String = "res://maps/silvaplana/wind/maloja_gusts.tres"
const LEE_PATH: String = "res://maps/silvaplana/wind/shore_lee.json"

# LV95 east, north. In the band: 75 m out from the south-east shore in the north-east stretch, and
# in the Sils stretch. Not in it: the same distance from the north-west shore, the open lake, and
# the east shore north of the bend (no lee on the photos).
const BAND_NORTH_EAST: Vector2 = Vector2(2781419.0, 1146565.0)
const BAND_SILS: Vector2 = Vector2(2779984.0, 1145600.0)
const NORTH_WEST_SHORE: Vector2 = Vector2(2780050.0, 1146700.0)
const OPEN_LAKE: Vector2 = Vector2(2780500.0, 1146600.0)
const EAST_SHORE_NORTH: Vector2 = Vector2(2781790.0, 1147050.0)

var _config: MapConfig
var _wind: MapWind
var _without_lee: MapWind


func before_all() -> void:
	_config = load(CONFIG_PATH)
	_wind = MapWind.load_from(PATTERN_PATH, DAY_PATH, _config, GUSTS_PATH, LEE_PATH)
	_without_lee = MapWind.new(_wind.pattern, _wind.day, _wind.gusts)


func test_the_lee_lies_along_the_south_east_shore() -> void:
	assert_not_null(_wind.lee, "The lee should load: " + LEE_PATH)
	if _wind.lee == null:
		return
	assert_gt(_shape(BAND_NORTH_EAST), 1.0, "75 m from the south-east shore, north-east stretch: deeper than the band's average")
	assert_gt(_shape(BAND_SILS), 0.5, "Sils stretch: in the band")
	assert_almost_eq(_shape(NORTH_WEST_SHORE), 0.0, 0.05, "Not along the north-west shore")
	assert_almost_eq(_shape(OPEN_LAKE), 0.0, 0.2, "Hardly in the middle of the lake")
	assert_almost_eq(_shape(EAST_SHORE_NORTH), 0.0, 0.05, "Not north of the bend")


func test_the_lee_deepens_when_the_wind_backs_or_blows_harder() -> void:
	var lee: WindLee = _wind.lee
	var reference: float = lee.band_lee(lee.reference_from_deg, lee.reference_kt)
	assert_almost_eq(reference, lee.band_lee_at_reference, 1e-6)
	assert_gt(lee.band_lee(lee.reference_from_deg - 6.0, lee.reference_kt), reference + 0.05, "6 degrees further left: deeper")
	assert_lt(lee.band_lee(lee.reference_from_deg + 6.0, lee.reference_kt), reference - 0.05, "6 degrees further right: shallower")
	assert_gt(lee.band_lee(lee.reference_from_deg, lee.reference_kt + 2.0), reference, "Stronger wind: deeper")
	assert_eq(lee.band_lee(lee.reference_from_deg + 40.0, lee.reference_kt), lee.band_lee(lee.reference_from_deg + lee.degrees_measured.y, lee.reference_kt),
		"Beyond the photos' directions the fit keeps its last value")
	assert_gte(lee.band_lee(lee.reference_from_deg + 40.0, lee.reference_kt - 10.0), 0.0, "Never below zero")


func test_one_in_ten_gusts_gets_through() -> void:
	var random: RandomNumberGenerator = RandomNumberGenerator.new()
	random.seed = 21
	var total: float = 0.0
	for i: int in 4000:
		total += _wind.gusts.reach(_wind.gusts.gusts_at(random.randf_range(-1e5, 1e5), random.randf_range(-700.0, 700.0),
			random.randf_range(11.0, 19.0) * 3600.0).x)
	assert_almost_eq(total / 4000.0, _wind.gusts.reach_share, 0.015, "On average 1 in 10 (Max; the photos: about 1 in 8)")


func test_a_strong_gust_lifts_the_lee() -> void:
	# In the band: without a reaching gust the wind is the lee's share less; in a reaching gust it is
	# as windy as the open lake (the fixed pattern's averaged lee taken out too).
	var place: Vector3 = _game(BAND_NORTH_EAST)
	var found: Array[bool] = [false, false]
	for i: int in 3000:
		var now: WindMoment = _wind.moment(14.0 * 3600.0 + i * 3.0)
		var unit: float = _unit_gust(now, place)
		var reach: float = _wind.gusts.reach(unit)
		var ratio: float = _wind.velocity_in(now, place).length() / _without_lee.velocity_in(now, place).length()
		var shape_held: Vector2 = _wind.lee.at(place.x, place.z)
		var from_deg: float = rad_to_deg(now.lake_to_rad) - 180.0
		if reach < 0.001 and not found[0]:
			found[0] = true
			# the lake's speed with its pulse and its direction with its shift, as MapWind uses them
			var expected: float = _lee_left(now, place, unit) / (1.0 - shape_held.y)
			assert_almost_eq(ratio, expected, 0.01, "No reaching gust: the lee's share less")
			# Against the open lake (the old model already had the photos' average lee in it):
			assert_lt(ratio * (1.0 - shape_held.y), 0.85, "a real lee: at least 15 % less than the open lake")
		elif reach > 0.999 and not found[1]:
			found[1] = true
			assert_almost_eq(ratio, 1.0 / (1.0 - shape_held.y), 0.001, "A reaching gust: as windy as the open lake")
		if found[0] and found[1]:
			break
	assert_true(found[0] and found[1], "Found moments with and without a reaching gust")


func test_a_reaching_gust_goes_down_all_the_way() -> void:
	# Max: a favourable gust "goes down all the way". A gust that gets into the band still gets in
	# 30 s later, as far down the band as the air travelled, most of the time.
	var place: Vector3 = _game(BAND_SILS)
	var axis: Vector3 = Vector3(_wind.lake_axis.x, 0.0, _wind.lake_axis.y)
	var reaching: int = 0
	var still: int = 0
	for i: int in 4000:
		var t: float = 13.0 * 3600.0 + i * 4.0
		var now: WindMoment = _wind.moment(t)
		if _wind.gusts.reach(_unit_gust(now, place)) < 0.9:
			continue
		reaching += 1
		var later: WindMoment = _wind.moment(t + 30.0)
		var down: Vector3 = place + axis * (later.travel_m - now.travel_m)
		if _wind.gusts.reach(_unit_gust(later, down)) > 0.5:
			still += 1
	assert_gt(reaching, 50, "Reaching gusts found")
	assert_gt(float(still) / reaching, 0.6, "%d of %d still reach 30 s later, further down the band" % [still, reaching])


func test_away_from_the_band_practically_nothing_changes() -> void:
	# W1's smoothing and its division by the lake's median spread a trace of the lee's average over
	# the lake (well under 0.1 %); nothing more.
	for lv95: Vector2 in [NORTH_WEST_SHORE, EAST_SHORE_NORTH]:
		var place: Vector3 = _game(lv95)
		for i: int in 20:
			var now: WindMoment = _wind.moment(14.0 * 3600.0 + i * 97.0)
			var with_lee: Vector3 = _wind.velocity_in(now, place)
			var without: Vector3 = _without_lee.velocity_in(now, place)
			assert_almost_eq(with_lee.length() / without.length(), 1.0, 0.001, "Speed at %s" % lv95)
			assert_almost_eq(with_lee.normalized().dot(without.normalized()), 1.0, 1e-6, "Direction at %s" % lv95)


func _game(lv95: Vector2) -> Vector3:
	return _config.lv95_to_game(lv95.x, lv95.y, _config.lake_level_m)


func _shape(lv95: Vector2) -> float:
	var place: Vector3 = _game(lv95)
	return _wind.lee.at(place.x, place.z).x


## The gust along the wind with a spread of 1 at a place and moment (as MapWind computes it).
func _unit_gust(now: WindMoment, place: Vector3) -> float:
	var xz: Vector2 = Vector2(place.x, place.z)
	var along: float = xz.dot(_wind.lake_axis)
	var across: float = xz.dot(Vector2(-_wind.lake_axis.y, _wind.lake_axis.x))
	return _wind.gusts.gusts_at(along - now.travel_m, across, now.time_of_day_s).x


## What is left of the wind in the lee for a gust (before W1's held share is taken out), with the
## lake's direction and speed as MapWind uses them (shifted and pulsed at this place).
func _lee_left(now: WindMoment, place: Vector3, unit: float) -> float:
	var along: float = Vector2(place.x, place.z).dot(_wind.lake_axis)
	var tau: float = now.time_of_day_s - along / now.drift_ms
	var from_deg: float = rad_to_deg(now.lake_to_rad + _wind.gusts.shift_rad(tau)) - 180.0
	var kt: float = now.lake_speed_ms * (1.0 + _wind.gusts.pulse(tau)) / SimMath.KNOT_MS
	var depth: float = _wind.lee.band_lee(from_deg, kt) / (1.0 - _wind.gusts.reach_share)
	return 1.0 - _wind.lee.at(place.x, place.z).x * depth * (1.0 - _wind.gusts.reach(unit))
