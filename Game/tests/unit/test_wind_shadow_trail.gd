extends GutTest
## The dirty air as it is on the water (WindShadowTrail; Max, 12 November 2026: "the dirty wind is straight downwind
## even when players are moving forward. the dirty wind moves while speeding up"): a board at rest casts its shadow
## straight downwind; a board going fast on a reach casts it behind it along its apparent wind, not onto the boards
## abeam to leeward; the shadow swings as it speeds up; a board put elsewhere starts a fresh trail; a sail that falls
## leaves no new puffs and its old ones fade; a board's own trail never shades it; with follows_apparent_wind off the
## cone straight down the true wind as before.

## The wind from the north at 10 m/s: the air moves south (+Z). Ticks of 1/60 s.
const WIND_FROM_DEG: float = 0.0
const WIND_MS: float = 10.0
const DT: float = 1.0 / 60.0


## One board sailed for `seconds` from `start` at a steady velocity (m/s, X and Z), its sail up or down; where it is at
## the end.
static func _sail(trail: WindShadowTrail, start: Vector2, velocity: Vector2, heading_deg: float, seconds: float, up: bool = true) -> Vector2:
	var at: Vector2 = start
	for k: int in roundi(seconds / DT):
		at += velocity * DT
		var boards: Array[Dictionary] = [{"at": at, "velocity": velocity, "wind_from_deg": WIND_FROM_DEG, "wind_ms": WIND_MS,
			"heading_deg": heading_deg}]
		trail.update_boards(DT, boards, PackedByteArray([1 if up else 0]))
	return at


## The share of the wind left at a point next to the board (X, Z metres from where it is now), seen by another board.
static func _left_at(trail: WindShadowTrail, board_at: Vector2, offset: Vector2, config: WindShadowConfig = null) -> float:
	var shadows: WindShadows = WindShadows.make(config)
	shadows.set_trail(trail.points(), -1)
	var point: Vector2 = board_at + offset
	return shadows.factor_at(Vector3(point.x, 2.0, point.y), Vector3(0.0, 0.0, WIND_MS))


func test_a_board_at_rest_casts_its_shadow_straight_downwind() -> void:
	var trail: WindShadowTrail = WindShadowTrail.make()
	var at: Vector2 = _sail(trail, Vector2.ZERO, Vector2.ZERO, 90.0, 6.0)
	var behind: float = _left_at(trail, at, Vector2(0.0, 10.0))
	assert_true(behind < 0.85 and behind > 0.7, "10 m downwind: in the shadow (%.3f)" % behind)
	assert_eq(_left_at(trail, at, Vector2(0.0, -5.0)), 1.0, "upwind of the sail: clean")
	assert_eq(_left_at(trail, at, Vector2(4.0, 0.0)), 1.0, "beside the sail: clean")
	assert_eq(_left_at(trail, at, Vector2(0.0, 40.0)), 1.0, "beyond 30 m: clean")


func test_a_fast_board_on_a_reach_casts_its_shadow_behind_along_its_apparent_wind() -> void:
	# Going east at 15 m/s in 10 m/s from the north: its apparent wind blows toward the west-south-west, 34 degrees to
	# leeward of straight astern (27 with the wake's bend toward the stern).
	var trail: WindShadowTrail = WindShadowTrail.make()
	var at: Vector2 = _sail(trail, Vector2.ZERO, Vector2(15.0, 0.0), 90.0, 6.0)
	assert_eq(_left_at(trail, at, Vector2(0.0, 10.0)), 1.0, "10 m straight downwind, abeam to leeward: clean (Max's slalom start)")
	assert_eq(_left_at(trail, at, Vector2(5.0, 8.0)), 1.0, "ahead and to leeward: clean")
	var axis: Vector2 = Vector2(-cos(deg_to_rad(27.0)), sin(deg_to_rad(27.0)))
	var wake: float = _left_at(trail, at, axis * 10.0)
	assert_true(wake < 0.85, "10 m down its wake, behind and to leeward: in the shadow (%.3f)" % wake)


func test_the_old_cone_shades_abeam_to_leeward_of_the_fast_board() -> void:
	var cone: WindShadowConfig = (load("res://config/wind_shadow_default.tres") as WindShadowConfig).duplicate()
	cone.follows_apparent_wind = false
	var shadows: WindShadows = WindShadows.make(cone)
	shadows.set_fleet(PackedFloat32Array([0.0]), PackedFloat32Array([0.0]), PackedByteArray([1]), -1)
	shadows.set_trail(PackedFloat32Array([0.0, 0.0, 0.0, 0.0, 0.0, -8.0, 0.0, 10.0]), -1)
	assert_true(shadows.factor_at(Vector3(0.0, 2.0, 10.0), Vector3(0.0, 0.0, WIND_MS)) < 0.85,
		"follows_apparent_wind off: the cone straight down the true wind, whatever the trail")


func test_the_shadow_swings_back_as_the_board_speeds_up() -> void:
	var trail: WindShadowTrail = WindShadowTrail.make()
	var at: Vector2 = _sail(trail, Vector2.ZERO, Vector2.ZERO, 90.0, 6.0)
	assert_true(_left_at(trail, at, Vector2(0.0, 8.0)) < 0.85, "waiting: 8 m downwind is dirty")
	at = _sail(trail, at, Vector2(6.0, 0.0), 90.0, 1.0)
	at = _sail(trail, at, Vector2(15.0, 0.0), 90.0, 4.0)
	assert_eq(_left_at(trail, at, Vector2(0.0, 8.0)), 1.0, "going fast: 8 m downwind of it is clean")


func test_a_board_put_elsewhere_starts_a_fresh_trail() -> void:
	var trail: WindShadowTrail = WindShadowTrail.make()
	_sail(trail, Vector2.ZERO, Vector2.ZERO, 90.0, 3.0)
	assert_gt(trail.puff_count(0), 5)
	var away: Vector2 = _sail(trail, Vector2(500.0, 0.0), Vector2.ZERO, 90.0, DT)
	assert_lte(trail.puff_count(0), 1, "the old puffs are forgotten")
	assert_eq(_left_at(trail, away, Vector2(-500.0, 10.0)), 1.0, "nothing left where it was")
	assert_eq(_left_at(trail, away, Vector2(-250.0, 5.0)), 1.0, "and no shadow joining the two places")


func test_a_sail_in_the_water_leaves_no_puffs_and_its_old_ones_fade() -> void:
	var trail: WindShadowTrail = WindShadowTrail.make()
	var at: Vector2 = _sail(trail, Vector2.ZERO, Vector2.ZERO, 90.0, 6.0)
	var count: int = trail.puff_count(0)
	_sail(trail, at, Vector2.ZERO, 90.0, 0.5, false)
	assert_lt(trail.puff_count(0), count, "no new puffs, the oldest forgotten")
	assert_true(_left_at(trail, at, Vector2(0.0, 15.0)) < 1.0, "just after the fall its old puffs still shade")
	_sail(trail, at, Vector2.ZERO, 90.0, 4.0, false)
	assert_eq(trail.puff_count(0), 0, "after 30 m of wind all gone")
	assert_eq(_left_at(trail, at, Vector2(0.0, 15.0)), 1.0)


func test_a_boards_own_trail_never_shades_it() -> void:
	var trail: WindShadowTrail = WindShadowTrail.make()
	var at: Vector2 = _sail(trail, Vector2.ZERO, Vector2.ZERO, 90.0, 6.0)
	var own: WindShadows = WindShadows.make()
	own.set_trail(trail.points(), 0)
	assert_eq(own.factor_at(Vector3(at.x, 2.0, at.y + 10.0), Vector3(0.0, 0.0, WIND_MS)), 1.0)
