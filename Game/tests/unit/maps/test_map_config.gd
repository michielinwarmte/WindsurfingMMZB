extends GutTest
## The Silvaplana map's position settings (Documentation/MAP_SILVAPLANA_PLAN.md, MD1):
## LV95 east -> game +X, north -> game -Z, height above the lake -> game +Y.

const CONFIG_PATH: String = "res://maps/silvaplana/map_config.tres"

var _config: MapConfig


func before_each() -> void:
	_config = load(CONFIG_PATH)


func test_config_loads() -> void:
	assert_not_null(_config, "The map config should load: " + CONFIG_PATH)


func test_lake_level_is_about_1790_m() -> void:
	# Silvaplanersee lies at about 1790 to 1791 m (swissALTI3D, BAFU station 2073).
	assert_between(_config.lake_level_m, 1789.5, 1791.5)


func test_origin_on_the_lake_surface_is_zero() -> void:
	var point: Vector3 = _config.lv95_to_game(_config.origin_east_m, _config.origin_north_m, _config.lake_level_m)
	assert_almost_eq(point.length(), 0.0, 0.001)


func test_weather_station_is_south_west_and_above_the_lake() -> void:
	# MeteoSwiss Segl-Maria (SIA): LV95 2778576 / 1144976, 1804 m.
	var station: Vector3 = _config.lv95_to_game(2778576.0, 1144976.0, 1804.0)
	assert_almost_eq(station.x, 2778576.0 - _config.origin_east_m, 0.01, "west of the origin is -X")
	assert_almost_eq(station.z, _config.origin_north_m - 1144976.0, 0.01, "south of the origin is +Z")
	assert_lt(station.x, 0.0, "The station is west of the lake centre")
	assert_gt(station.z, 0.0, "The station is south of the lake centre")
	assert_almost_eq(station.y, 1804.0 - _config.lake_level_m, 0.01)


func test_village_is_north_east() -> void:
	# Silvaplana village, around LV95 2781074 / 1148017.
	var village: Vector3 = _config.lv95_to_game(2781074.0, 1148017.0, _config.lake_level_m)
	assert_gt(village.x, 0.0, "The village is east of the lake centre")
	assert_lt(village.z, 0.0, "The village is north of the lake centre (north is -Z)")


func test_round_trip_keeps_centimetres() -> void:
	var lv95: PackedFloat64Array = _config.game_to_lv95(_config.lv95_to_game(2783156.0, 1143524.0, 3294.0))
	assert_almost_eq(lv95[0], 2783156.0, 0.01, "east")
	assert_almost_eq(lv95[1], 1143524.0, 0.01, "north")
	assert_almost_eq(lv95[2], 3294.0, 0.01, "height")
