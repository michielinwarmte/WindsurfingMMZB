extends GutTest
## The wind shadows of a fleet (AI_FLEET_PLAN.md, D5). The cone's shape is tested on a test cone with round numbers
## (the game's shadow until 13 November 2026): behind a sail the wind is 30 % less close by, fading to nothing at
## 20 m, in a cone 2.5 m wide at the sail that widens at 8 degrees; nothing upwind of the sail or outside the cone;
## shadows add up to at most half the wind; a board's own sail and a sail in the water cast none; the cone lies along
## the wind wherever it blows from; and a wind field with the shadows set gives less wind at a shadowed point (the
## physics' hook). The game's own numbers are the wind tunnel's (PH15): 7.5 % less right behind the sail, fading
## from 1 m to nothing at 20 m (test_the_default_is_the_wind_tunnels_shadow()).

## The air moving south at 10 m/s: the wind from the north.
const SOUTH_10: Vector3 = Vector3(0.0, 0.0, 10.0)


## The test cone: round numbers that make the shape easy to check.
static func _test_cone() -> WindShadowConfig:
	var config: WindShadowConfig = WindShadowConfig.new()
	config.deficit = 0.3
	config.full_until_m = 5.0
	config.length_m = 20.0
	config.half_width_m = 2.5
	config.spread_deg = 8.0
	config.most_deficit = 0.5
	return config


static func _shadows(xs: Array[float], zs: Array[float], casting: Array[int] = [], own: int = -1) -> WindShadows:
	var shadows: WindShadows = WindShadows.make(_test_cone())
	var casts: PackedByteArray = PackedByteArray()
	for i: int in xs.size():
		casts.append(1 if casting.is_empty() else casting[i])
	shadows.set_fleet(PackedFloat32Array(xs), PackedFloat32Array(zs), casts, own)
	return shadows


static func _at(x: float, z: float) -> Vector3:
	return Vector3(x, 2.0, z)


func test_the_default_is_the_wind_tunnels_shadow() -> void:
	# PH15 (Documentation/reports/ph15_wind_tunnel/wind_tunnel.md, option A): the wind tunnel measured about 5 % less
	# wind 5 m behind, 4 % at 10 m and 3 % at 20 m; the game's straight fade over Max's 20 m comes within 1.5 points.
	var config: WindShadowConfig = load("res://config/wind_shadow_default.tres") as WindShadowConfig
	assert_almost_eq(config.deficit, 0.075, 1e-6)
	assert_almost_eq(config.full_until_m, 1.0, 1e-6)
	assert_almost_eq(config.length_m, 20.0, 1e-6)
	assert_almost_eq(config.half_width_m, 2.5, 1e-6)
	assert_almost_eq(config.spread_deg, 8.0, 1e-6)
	assert_almost_eq(config.stern_bend_deg, 3.0, 1e-6)
	var one: WindShadows = WindShadows.make()
	one.set_fleet(PackedFloat32Array([0.0]), PackedFloat32Array([0.0]), PackedByteArray([1]), -1)
	var at_5: float = 1.0 - one.factor_at(_at(0.0, 5.0), SOUTH_10)
	var at_10: float = 1.0 - one.factor_at(_at(0.0, 10.0), SOUTH_10)
	assert_almost_eq(at_5, 0.075 * (1.0 - 4.0 / 19.0), 1e-6, "5 m behind: about 6 % less (the tunnel: 4 to 7)")
	assert_almost_eq(at_10, 0.075 * (1.0 - 9.0 / 19.0), 1e-6, "10 m behind: about 4 % less (the tunnel: 3 to 5)")


func test_nothing_without_a_fleet_or_wind() -> void:
	var none: WindShadows = WindShadows.make()
	assert_eq(none.factor_at(_at(0.0, 2.0), SOUTH_10), 1.0)
	var one: WindShadows = _shadows([0.0], [0.0])
	assert_eq(one.factor_at(_at(0.0, 2.0), Vector3.ZERO), 1.0, "no wind, no shadow")


func test_30_percent_less_close_behind_the_sail_fading_to_nothing_at_20_m() -> void:
	var one: WindShadows = _shadows([0.0], [0.0])
	assert_almost_eq(one.factor_at(_at(0.0, 2.0), SOUTH_10), 0.7, 1e-6, "2 m downwind: the full deficit")
	assert_almost_eq(one.factor_at(_at(0.0, 5.0), SOUTH_10), 0.7, 1e-6, "still full at 5 m")
	# 15 m: 10 of the remaining 15 m into the fade: a third of the deficit left.
	assert_almost_eq(one.factor_at(_at(0.0, 15.0), SOUTH_10), 1.0 - 0.3 / 3.0, 1e-6)
	assert_eq(one.factor_at(_at(0.0, 25.0), SOUTH_10), 1.0, "beyond 20 m: nothing")
	assert_eq(one.factor_at(_at(0.0, -2.0), SOUTH_10), 1.0, "upwind of the sail: nothing")
	assert_eq(one.factor_at(_at(0.0, 0.0), SOUTH_10), 1.0, "at the sail itself: nothing (it is not downwind)")


func test_the_cone_is_2_5_m_wide_at_the_sail_widening_at_8_degrees_with_a_smooth_profile() -> void:
	var one: WindShadows = _shadows([0.0], [0.0])
	# 2 m downwind: the half width is 2.5 + 2 tan 8 = 2.78 m; 2 m to the side is inside, 3 m is out.
	var width: float = 2.5 + 2.0 * tan(deg_to_rad(8.0))
	var share: float = 2.0 / width
	assert_almost_eq(one.factor_at(_at(2.0, 2.0), SOUTH_10), 1.0 - 0.3 * (1.0 - share * share), 1e-6, "inside, less than on the axis")
	assert_eq(one.factor_at(_at(3.0, 2.0), SOUTH_10), 1.0, "outside the cone")
	# 15 m downwind the cone is 2.5 + 15 tan 8 = 4.6 m wide either side.
	assert_true(one.factor_at(_at(4.3, 15.0), SOUTH_10) < 1.0, "inside the widened cone")
	assert_eq(one.factor_at(_at(4.9, 15.0), SOUTH_10), 1.0, "outside it")


func test_shadows_add_up_to_at_most_half_the_wind() -> void:
	var two: WindShadows = _shadows([0.0, 0.0], [0.0, 1.0])
	assert_almost_eq(two.factor_at(_at(0.0, 3.0), SOUTH_10), 0.5, 1e-6, "two full shadows: 60 % capped at 50")
	var apart: WindShadows = _shadows([0.0, 0.0], [0.0, -10.0])
	# The sail 10 m further upwind has 7 of 15 m of its fade left at 13 m.
	assert_almost_eq(apart.factor_at(_at(0.0, 3.0), SOUTH_10), 1.0 - 0.3 - 0.3 * (1.0 - 8.0 / 15.0), 1e-6)


func test_a_boards_own_sail_and_a_sail_in_the_water_cast_no_shadow() -> void:
	var own: WindShadows = _shadows([0.0, 50.0], [0.0, 0.0], [], 0)
	assert_eq(own.factor_at(_at(0.0, 2.0), SOUTH_10), 1.0, "its own sail")
	assert_eq(own.casting_count(), 1)
	var fallen: WindShadows = _shadows([0.0], [0.0], [0])
	assert_eq(fallen.factor_at(_at(0.0, 2.0), SOUTH_10), 1.0, "a sail in the water")
	assert_eq(fallen.casting_count(), 0)


func test_the_cone_lies_along_the_wind_wherever_it_blows_from() -> void:
	var one: WindShadows = _shadows([0.0], [0.0])
	var east_10: Vector3 = Vector3(10.0, 0.0, 0.0)  # the wind from the west
	assert_almost_eq(one.factor_at(_at(3.0, 0.0), east_10), 0.7, 1e-6, "3 m east of the sail, in its shadow")
	assert_eq(one.factor_at(_at(-3.0, 0.0), east_10), 1.0, "west of it: upwind")
	assert_eq(one.factor_at(_at(0.0, 3.0), east_10), 1.0, "south of it: beside the cone")
	# Twice the wind: the same share.
	assert_almost_eq(one.factor_at(_at(3.0, 0.0), east_10 * 2.0), 0.7, 1e-6)


func test_a_wind_field_with_the_shadows_gives_less_wind_at_a_shadowed_point() -> void:
	var config: WindConfig = WindConfig.new()
	config.speed_kt = 20.0
	config.from_bearing_deg = 0.0  # from the north
	config.gusts_enabled = false
	config.shifts_enabled = false
	config.height_gradient_enabled = false
	var field: WindField = WindField.new(config)
	var clear: Vector3 = field.velocity_at(Vector3(0.0, 3.0, 2.0))
	assert_true(clear.z > 9.0, "the air moves south at about 10 m/s: %s" % clear)
	field.disturbance = _shadows([0.0], [0.0])
	var shadowed: Vector3 = field.velocity_at(Vector3(0.0, 3.0, 2.0))
	assert_almost_eq(shadowed.z, 0.7 * clear.z, 1e-4, "30 % less 2 m behind the sail")
	assert_eq(field.velocity_at(Vector3(0.0, 3.0, -2.0)), clear, "the same as before upwind of it")
	field.disturbance = null
	assert_eq(field.velocity_at(Vector3(0.0, 3.0, 2.0)), clear, "and with none set")
