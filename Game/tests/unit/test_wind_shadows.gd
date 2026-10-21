extends GutTest
## The wind shadows of a fleet (AI_FLEET_PLAN.md, D5): behind a sail the wind is 30 % less close
## by, fading to nothing at 30 m, in a cone 2.5 m wide at the sail that widens at 8 degrees; nothing
## upwind of the sail or outside the cone; shadows add up to at most half the wind; a board's own
## sail and a sail in the water cast none; the cone lies along the wind wherever it blows from; and a
## wind field with the shadows set gives less wind at a shadowed point (the physics' hook).

## The air moving south at 10 m/s: the wind from the north.
const SOUTH_10: Vector3 = Vector3(0.0, 0.0, 10.0)


static func _shadows(xs: Array[float], zs: Array[float], casting: Array[int] = [], own: int = -1) -> WindShadows:
	var shadows: WindShadows = WindShadows.make()
	var casts: PackedByteArray = PackedByteArray()
	for i: int in xs.size():
		casts.append(1 if casting.is_empty() else casting[i])
	shadows.set_fleet(PackedFloat32Array(xs), PackedFloat32Array(zs), casts, own)
	return shadows


static func _at(x: float, z: float) -> Vector3:
	return Vector3(x, 2.0, z)


func test_nothing_without_a_fleet_or_wind() -> void:
	var none: WindShadows = WindShadows.make()
	assert_eq(none.factor_at(_at(0.0, 2.0), SOUTH_10), 1.0)
	var one: WindShadows = _shadows([0.0], [0.0])
	assert_eq(one.factor_at(_at(0.0, 2.0), Vector3.ZERO), 1.0, "no wind, no shadow")


func test_30_percent_less_close_behind_the_sail_fading_to_nothing_at_30_m() -> void:
	var one: WindShadows = _shadows([0.0], [0.0])
	assert_almost_eq(one.factor_at(_at(0.0, 2.0), SOUTH_10), 0.7, 1e-6, "2 m downwind: the full deficit")
	assert_almost_eq(one.factor_at(_at(0.0, 5.0), SOUTH_10), 0.7, 1e-6, "still full at 5 m")
	# 20 m: 15 of the remaining 25 m into the fade: 40 % of the deficit left.
	assert_almost_eq(one.factor_at(_at(0.0, 20.0), SOUTH_10), 1.0 - 0.3 * 0.4, 1e-6)
	assert_eq(one.factor_at(_at(0.0, 35.0), SOUTH_10), 1.0, "beyond 30 m: nothing")
	assert_eq(one.factor_at(_at(0.0, -2.0), SOUTH_10), 1.0, "upwind of the sail: nothing")
	assert_eq(one.factor_at(_at(0.0, 0.0), SOUTH_10), 1.0, "at the sail itself: nothing (it is not downwind)")


func test_the_cone_is_2_5_m_wide_at_the_sail_widening_at_8_degrees_with_a_smooth_profile() -> void:
	var one: WindShadows = _shadows([0.0], [0.0])
	# 2 m downwind: the half width is 2.5 + 2 tan 8 = 2.78 m; 2 m to the side is inside, 3 m is out.
	var width: float = 2.5 + 2.0 * tan(deg_to_rad(8.0))
	var share: float = 2.0 / width
	assert_almost_eq(one.factor_at(_at(2.0, 2.0), SOUTH_10), 1.0 - 0.3 * (1.0 - share * share), 1e-6, "inside, less than on the axis")
	assert_eq(one.factor_at(_at(3.0, 2.0), SOUTH_10), 1.0, "outside the cone")
	# 25 m downwind the cone is 2.5 + 25 tan 8 = 6.0 m wide either side.
	assert_true(one.factor_at(_at(5.5, 25.0), SOUTH_10) < 1.0, "inside the widened cone")
	assert_eq(one.factor_at(_at(6.5, 25.0), SOUTH_10), 1.0, "outside it")


func test_shadows_add_up_to_at_most_half_the_wind() -> void:
	var two: WindShadows = _shadows([0.0, 0.0], [0.0, 1.0])
	assert_almost_eq(two.factor_at(_at(0.0, 3.0), SOUTH_10), 0.5, 1e-6, "two full shadows: 60 % capped at 50")
	var apart: WindShadows = _shadows([0.0, 0.0], [0.0, -20.0])
	# The sail 20 m further upwind has 40 % of its deficit left at 23 m: 0.3 + 0.12.
	assert_almost_eq(apart.factor_at(_at(0.0, 3.0), SOUTH_10), 1.0 - 0.3 - 0.3 * (1.0 - 18.0 / 25.0), 1e-6)


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
