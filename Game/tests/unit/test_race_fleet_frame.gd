extends GutTest
## The frame's work with a big fleet (F1 fleet_frame, AI_FLEET_PLAN.md D2): the measure's summary
## of the AI boards' costs, and the race order worked out once per tick instead of a sort per
## question (RaceSim.race_order, place; RaceHud.fleet_text).

const BOARDS: int = 33


# ---------------------------------------------------------------- the measure's summary

func test_the_median_and_the_worst() -> void:
	assert_eq(RaceRunner.median(PackedFloat64Array([3.0, 1.0, 2.0])), 2.0)
	assert_eq(RaceRunner.median(PackedFloat64Array([4.0, 1.0, 2.0, 3.0])), 2.5)
	assert_eq(RaceRunner.median(PackedFloat64Array()), 0.0)
	assert_eq(RaceRunner.worst(PackedFloat64Array([3.0, 7.5, 2.0])), 7.5)


# ---------------------------------------------------------------- the race order

func test_the_order_is_by_distance_on_the_same_step_and_follows_the_boards() -> void:
	var race: RaceSim = _big_race()
	var order: Array[int] = race.race_order()
	assert_eq(order.size(), BOARDS)
	for rank: int in order.size():
		assert_eq(race.place(order[rank]), rank + 1, "place() and race_order() agree")
		if rank > 0:
			assert_true(race.distance_to_next_m(order[rank - 1]) <= race.distance_to_next_m(order[rank]), "nearer the line first")
	# The last board moves to the front: the order is worked out again.
	var last: int = order[BOARDS - 1]
	var first: int = order[0]
	race.update_board(last, race.board_position(first) + race.steps()[0].in_dir * 0.5)
	assert_eq(race.place(last), 1, "moved to the front")
	assert_eq(race.place(first), 2)


func test_the_fleet_lines_at_33_boards_are_cheap() -> void:
	var race: RaceSim = _big_race()
	var t0: int = Time.get_ticks_usec()
	var text: String = RaceHud.fleet_text(race, 0)
	var fleet_ms: float = (Time.get_ticks_usec() - t0) / 1000.0
	t0 = Time.get_ticks_usec()
	for frame: int in 60:
		race.place(0)
	var places_ms: float = (Time.get_ticks_usec() - t0) / 1000.0
	# Before fleet_frame the lines took about 320 ms here (a sort for every comparison of the sort)
	# and a place() 0.6 ms; generous limits, for a busy machine.
	gut.p("the fleet's lines %.2f ms; the player's place 60 times %.2f ms" % [fleet_ms, places_ms])
	assert_lt(fleet_ms, 20.0, "the fleet's lines at 33 boards")
	assert_lt(places_ms, 5.0, "a second of frames asking for the place, the order worked out once")
	var lines: PackedStringArray = text.split("\n")
	assert_eq(lines.size(), BOARDS)
	assert_true(lines[0].begins_with("1. "), "the leader first")


## A race on T1 with BOARDS boards spread behind the start line, in the countdown.
func _big_race() -> RaceSim:
	var course: Course = RaceCourses.t1_loop(270.0, Vector2.ZERO)
	var race: RaceSim = RaceSim.new(course, 1, 30.0)
	var start: RaceStep = race.steps()[0]
	var along: Vector2 = (start.points[0] - start.points[1]).normalized()
	for i: int in BOARDS:
		race.add_board("Board %d" % i)
		var behind_m: float = 20.0 + float((i * 7) % 13)
		race.update_board(i, course.start_middle() + along * (float(i) - 16.0) - start.in_dir * behind_m)
	race.start()
	race.step(0.1)
	return race


# ---------------------------------------------------------------- the boards in the camera's view

# An opponent out of the camera's view is posed only now and then (RaceRunner._pose_boards(),
# 13 November 2026); one just outside the picture still counts as seen, as its mast may reach in.
func test_a_board_ahead_is_seen_and_one_behind_is_not() -> void:
	var view: Array[Plane] = _view_along_minus_z()
	assert_true(RaceRunner.in_view(view, Vector3(0.0, 0.0, -50.0)), "ahead of the camera")
	assert_false(RaceRunner.in_view(view, Vector3(0.0, 0.0, 50.0)), "behind the camera")


func test_a_board_just_outside_the_edge_counts_as_seen() -> void:
	var view: Array[Plane] = _view_along_minus_z()
	var left: Plane = view[2]  # Camera3D.get_frustum(): near, far, left, top, right, bottom
	var on_the_edge: Vector3 = left.project(Vector3(0.0, 0.0, -50.0))
	var inside_margin: Vector3 = on_the_edge + left.normal * (RaceRunner.VIEW_MARGIN_M - 2.0)
	var outside_margin: Vector3 = on_the_edge + left.normal * (RaceRunner.VIEW_MARGIN_M + 2.0)
	assert_true(RaceRunner.in_view(view, inside_margin), "within the margin outside the edge")
	assert_false(RaceRunner.in_view(view, outside_margin), "beyond the margin")


func test_without_a_camera_every_board_is_seen() -> void:
	var no_view: Array[Plane] = []
	assert_true(RaceRunner.in_view(no_view, Vector3(1000.0, 0.0, 1000.0)))


## A camera at the origin looking along -Z (Godot's forward), its view's six planes.
func _view_along_minus_z() -> Array[Plane]:
	var camera: Camera3D = Camera3D.new()
	add_child_autofree(camera)
	return camera.get_frustum()
