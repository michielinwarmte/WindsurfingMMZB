extends GutTest
## Fitting a course to the water (RACING_PLAN.md, T2 "Placed to fit the water"; CourseFitter). Every
## distance to land the fitter claims is checked independently on the lake's 2 m height grid, with
## rings of RING_SAMPLES points round the spot (land is where the course maker's warnings see it:
## above the lake's surface, or off the map):
## - the shore clearance: hundreds of metres in the lake's middle, a few tens off the camping beach,
##   none on land; never more than there is, anywhere on the lake, and not far less (that side is
##   checked on a denser ring, see _land_near());
## - the fitted sprint slalom (PD3, T2): every mark 200 m and every leg 50 m from land, no leg over
##   land, the template's name, order and sides;
## - an impossible fit returns nothing and says why; the fit is the same every time and from any
##   spot on the lake; an already fitting course stays where it is;
## - the committed t2_slalom.json passes the same checks;
## - the course maker's Fit to water button, on a made-up lake: one Undo step, and the reason in the
##   panel when nothing fits.

const CONFIG_PATH: String = "res://maps/silvaplana/map_config.tres"
const RULES_PATH: String = "res://maps/course/iqfoil_courses.tres"
const SHORE_GRID_PATH: String = "res://maps/silvaplana/terrain/shore_heights.json"
const ENVIRONMENT_PATH: String = "res://maps/silvaplana/environment_silvaplana.tres"
const T2_PATH: String = "res://maps/silvaplana/courses/t2_slalom.json"
## The lake scene's start, 40 m off the camping beach (SilvaplanaSailing.START_LV95), LV95 metres.
const START_LV95: Vector2 = Vector2(2780880.0, 1147510.0)
## A spot in the lake's middle with at least 300 m of water all round (run_lake.gd), game metres.
const MIDDLE: Vector2 = Vector2(349.0, -89.0)
const RING_SAMPLES: int = 32
## The independent check looks for land on rings this far apart, from the spot out to the distance.
const RING_STEP_M: float = 10.0
## The field may be this much more careful than the truth: it takes a grid step (10 m) off.
const CAUTION_M: float = 25.0
const MARK_MARGIN_M: float = 200.0
const LEG_MARGIN_M: float = 50.0
const BOARDS: int = 4

var _config: MapConfig
var _rules: CourseRules
var _grid: TerrainGrid
var _fitter: CourseFitter
var _start: Vector2
## The lake's mean wind at 14:30, where it comes from in whole degrees, and its speed in knots.
var _axis_deg: float
var _wind_kt: float


func before_all() -> void:
	_config = load(CONFIG_PATH)
	_rules = load(RULES_PATH)
	_grid = TerrainGrid.load_from(SHORE_GRID_PATH)
	var at: Vector3 = _config.lv95_to_game(START_LV95.x, START_LV95.y, _config.lake_level_m)
	_start = Vector2(at.x, at.z)
	_fitter = CourseFitter.from_heights(_grid.height_at, _start)
	var environment: EnvironmentConfig = load(ENVIRONMENT_PATH)
	var wind: MapWind = environment.map_wind()
	var time_s: float = environment.start_time_of_day_s()
	_axis_deg = roundf(fposmod(wind.lake_from_deg(time_s), 360.0))
	_wind_kt = wind.day.lake_speed_ms(time_s) / SimMath.KNOT_MS


func test_the_shore_clearance() -> void:
	var middle_m: float = _fitter.clearance_m(MIDDLE)
	assert_gt(middle_m, 250.0, "Hundreds of metres in the lake's middle")
	assert_false(_land_within(MIDDLE, middle_m), "No land within the %.0f m claimed in the middle" % middle_m)
	assert_true(_land_near(MIDDLE, middle_m + CAUTION_M), "Land a little further out: the field is not far too careful")
	var beach_m: float = _fitter.clearance_m(_start)
	assert_between(beach_m, 1.0, 60.0, "A few tens of metres 40 m off the camping beach")
	assert_false(_land_within(_start, beach_m), "No land within the %.0f m claimed off the beach" % beach_m)
	assert_true(_land_near(_start, beach_m + CAUTION_M), "Land a little further out")
	# 300 m from the start toward the beach (312 degrees) is the camping ground.
	var camping: Vector2 = _start + Course.direction_of(312.0) * 300.0
	assert_true(_is_land(camping), "The test point is on land")
	assert_eq(_fitter.clearance_m(camping), 0.0, "No clearance on land")
	assert_eq(_fitter.clearance_m(Vector2(9000.0, 9000.0)), 0.0, "None off the map")


func test_the_clearance_is_never_more_than_there_is() -> void:
	# Every 150 m over the lake's box: no land within the distance claimed, and land not much further.
	var checked: int = 0
	var too_much: PackedStringArray = PackedStringArray()
	var too_careful: PackedStringArray = PackedStringArray()
	var west: int = roundi(_fitter.x0_m)
	var north: int = roundi(_fitter.z0_m)
	for z: int in range(north, north + roundi((_fitter.rows - 1) * CourseFitter.STEP_M), 150):
		for x: int in range(west, west + roundi((_fitter.columns - 1) * CourseFitter.STEP_M), 150):
			# Not on the grid's points: the spots in between are interpolated.
			var spot: Vector2 = Vector2(x + 3.0, z + 7.0)
			var claimed_m: float = _fitter.clearance_m(spot)
			if claimed_m <= 0.0:
				continue
			checked += 1
			if _land_within(spot, claimed_m):
				too_much.append("%s: %.0f m" % [spot, claimed_m])
			if not _land_near(spot, claimed_m + CAUTION_M):
				too_careful.append("%s: %.0f m" % [spot, claimed_m])
	assert_gt(checked, 100, "Enough of the lake checked")
	assert_eq(too_much, PackedStringArray(), "Land nearer than the field claims")
	assert_eq(too_careful, PackedStringArray(), "No land within %.0f m beyond the field's distance" % CAUTION_M)


func test_the_fitted_sprint_slalom() -> void:
	var course: Course = _fitter.fit_template("PD3", _rules, _wind_kt, _axis_deg, _start, BOARDS)
	assert_not_null(course, "The sprint slalom fits: " + _fitter.last_reason)
	if course == null:
		return
	_assert_on_open_water(course, "The fitted PD3")
	var template: Course = CourseTemplates.build("PD3", _rules, _wind_kt, BOARDS, _axis_deg, Vector2.ZERO)
	assert_eq(course.name, template.name, "The template's name")
	assert_eq(course.template, "PD3")
	assert_eq(course.sequence, template.sequence, "The template's order")
	assert_eq(course.boards, BOARDS)
	assert_eq(course.marks.size(), template.marks.size())
	for mark: CourseMark in template.marks:
		assert_not_null(course.mark(mark.id), mark.id)
		if course.mark(mark.id) != null:
			assert_eq(course.mark(mark.id).side, mark.side, mark.id + " keeps its side")
	assert_between(course.size_percent, 40.0, 100.0, "Between the smallest size allowed and the class's distances")
	assert_lte(absf(Course.turn_deg(_axis_deg, course.axis_deg)), 15.0, "At most 15 degrees off the wind")
	var scale: float = course.size_percent / 100.0
	assert_almost_eq(course.mark("1").position.distance_to(course.mark("2").position),
		template.mark("1").position.distance_to(template.mark("2").position) * scale, 0.01, "Only made smaller, not bent")
	assert_lt(_fitter.last_fit_ms, 3000.0, "The fit takes less than 3 s")


func test_an_impossible_fit_says_why() -> void:
	var strict: CourseFitter = CourseFitter.from_heights(_grid.height_at, _start)
	strict.min_size_percent = 300.0
	assert_null(strict.fit_template("PD3", _rules, _wind_kt, _axis_deg, _start, BOARDS), "A sprint slalom three times the class's size")
	assert_string_contains(strict.last_reason, "300 %")
	assert_gt(strict.last_tries, 0, "It did try")
	strict.min_size_percent = 40.0
	strict.mark_margin_m = 700.0
	assert_null(strict.fit_template("LG2", _rules, _wind_kt, _axis_deg, _start, BOARDS), "Marks 700 m from the shore")
	assert_string_contains(strict.last_reason, "most open water")
	var on_land: CourseFitter = CourseFitter.from_heights(_grid.height_at, _start + Course.direction_of(312.0) * 300.0)
	assert_false(on_land.has_water(), "Started on land: no lake")
	assert_null(on_land.fit_template("PD3", _rules, _wind_kt, _axis_deg, _start, BOARDS))
	assert_ne(on_land.last_reason, "", "It says why")


func test_the_fit_is_the_same_every_time() -> void:
	var first: Course = _fitter.fit_template("PD3", _rules, _wind_kt, _axis_deg, _start, BOARDS)
	var again: Course = _fitter.fit_template("PD3", _rules, _wind_kt, _axis_deg, _start, BOARDS)
	# A fitter started from another spot of the lake has the same grid.
	var other: CourseFitter = CourseFitter.from_heights(_grid.height_at, MIDDLE)
	var from_elsewhere: Course = other.fit_template("PD3", _rules, _wind_kt, _axis_deg, _start, BOARDS)
	assert_not_null(first)
	assert_not_null(from_elsewhere)
	if first == null or from_elsewhere == null:
		return
	for i: int in first.marks.size():
		assert_eq(again.marks[i].position, first.marks[i].position, "The same again: " + first.marks[i].id)
		assert_eq(from_elsewhere.marks[i].position, first.marks[i].position, "The same from the lake's middle: " + first.marks[i].id)
	assert_eq(again.size_percent, first.size_percent)
	assert_eq(again.axis_deg, first.axis_deg)


func test_a_placed_course_keeps_its_shape_and_a_fitting_one_stays() -> void:
	# A full-size sprint slalom put down at the start, half on land, as the course maker would.
	var placed: Course = CourseTemplates.build("PD3", _rules, _wind_kt, BOARDS, _axis_deg, _start)
	placed.add_mark("4", placed.mark("2").position.lerp(placed.mark("3").position, 0.5), CourseMark.Rounding.PORT)
	placed.insert_into_legs("4", [2] as Array[int])
	assert_false(placed.problems(_grid.height_at).is_empty(), "The placed course is partly on land")
	var fitted: Course = _fitter.fit_course(placed, _axis_deg)
	assert_not_null(fitted, _fitter.last_reason)
	if fitted == null:
		return
	_assert_on_open_water(fitted, "The fitted course")
	assert_eq(fitted.sequence, placed.sequence, "The added mark stays in the order")
	assert_not_null(fitted.mark("4"), "and on the course")
	assert_eq(placed.size_percent, 100.0, "The course given is not changed")
	var refit: Course = _fitter.fit_course(fitted, fitted.axis_deg)
	assert_not_null(refit)
	if refit == null:
		return
	for i: int in fitted.marks.size():
		assert_almost_eq(refit.marks[i].position.distance_to(fitted.marks[i].position), 0.0, 0.001,
			"A course that fits stays where it is: " + fitted.marks[i].id)


func test_the_saved_t2_slalom() -> void:
	var course: Course = Course.load_from(T2_PATH, _config)
	assert_not_null(course, "t2_slalom.json loads")
	if course == null:
		return
	assert_eq(course.name, "T2 sprint slalom")
	assert_eq(course.template, "PD3")
	assert_eq(course.sequence, CourseTemplates.build("PD3", _rules, 15.0, BOARDS, 0.0, Vector2.ZERO).sequence)
	assert_eq(course.boards, BOARDS)
	_assert_on_open_water(course, "t2_slalom.json")
	assert_eq(course.problems(_grid.height_at), PackedStringArray(), "No warnings in the course maker")


func test_the_course_makers_button() -> void:
	# A made-up lake 2.8 km square, land round it, nothing beyond 4 km.
	var height_at: Callable = func(x: float, z: float) -> float:
		if absf(x) > 4000.0 or absf(z) > 4000.0:
			return NAN
		return -10.0 if absf(x) < 1400.0 and absf(z) < 1400.0 else 5.0
	var world: Node3D = Node3D.new()
	add_child_autofree(world)
	var layer: CanvasLayer = CanvasLayer.new()
	world.add_child(layer)
	var panels: Control = Control.new()
	layer.add_child(panels)
	var editor: CourseEditor = CourseEditor.new()
	world.add_child(editor)
	var wind_now: Callable = func() -> Vector2: return Vector2(222.0, 15.0)
	var view_centre: Callable = func() -> Vector2: return Vector2.ZERO
	editor.setup(layer, panels, _config, height_at, "user://test_fit_courses", wind_now, view_centre)
	# Its middle 1300 m east of the lake's: the eastern marks are on land.
	editor.place_template("PD3", Vector2(1300.0, 0.0))
	var before: Course = editor.course.copy()
	assert_false(before.problems(height_at).is_empty(), "Placed partly on land")
	editor._panel.fit_to_water_pressed.emit()
	assert_eq(editor.course.problems(height_at), PackedStringArray(), "Fitted: no warnings")
	for mark: CourseMark in editor.course.marks:
		var to_shore_m: float = 1400.0 - maxf(absf(mark.position.x), absf(mark.position.y))
		assert_gte(to_shore_m, MARK_MARGIN_M, mark.id + " is 200 m from the made-up shore")
	assert_eq(editor.course.size_percent, 100.0, "The lake has room for the class's size")
	assert_almost_eq(editor.course.axis_deg, 222.0, 0.001, "Square to the wind")
	editor._on_undo()
	for i: int in before.marks.size():
		assert_eq(editor.course.marks[i].position, before.marks[i].position, "Undo puts it back: " + before.marks[i].id)
	# Marks 2 km from the shore of a 2.8 km lake: nothing fits, the panel says why.
	editor._fitter.mark_margin_m = 2000.0
	assert_false(editor.fit_to_water(), "Nothing fits")
	assert_eq(editor._panel._message.text, editor._fitter.last_reason, "The panel shows the reason")
	for i: int in before.marks.size():
		assert_eq(editor.course.marks[i].position, before.marks[i].position, "The course stays as it was: " + before.marks[i].id)


# ---------------------------------------------------------------- the independent checks

## Every mark has no land within 200 m, the legs don't cross land, and every point along every leg
## (every 10 m) has no land within 50 m.
func _assert_on_open_water(course: Course, what: String) -> void:
	for mark: CourseMark in course.marks:
		assert_false(_land_within(mark.position, MARK_MARGIN_M), "%s: no land within %.0f m of %s" % [what, MARK_MARGIN_M, mark.id])
	assert_eq(course.legs_over_land(_grid.height_at), [] as Array[Course.Leg], what + ": no leg over land")
	var close: PackedStringArray = PackedStringArray()
	for leg: Course.Leg in course.legs():
		var steps: int = maxi(ceili(leg.length_m() / Course.LAND_CHECK_STEP_M), 1)
		for i: int in steps + 1:
			var point: Vector2 = leg.from_point.lerp(leg.to_point, float(i) / steps)
			if _land_within(point, LEG_MARGIN_M):
				close.append("%s → %s at %.0f m" % [leg.from_name, leg.to_name, point.distance_to(leg.from_point)])
	assert_eq(close, PackedStringArray(), "%s: no land within %.0f m of a leg" % [what, LEG_MARGIN_M])


## Land anywhere within a distance of a spot: the spot itself and rings every RING_STEP_M out to the
## distance, the last ring at the distance itself.
func _land_within(centre: Vector2, distance_m: float) -> bool:
	if _is_land(centre):
		return true
	var radius_m: float = distance_m
	while radius_m > 0.0:
		if _land_on_ring(centre, radius_m):
			return true
		radius_m -= RING_STEP_M
	return false


func _land_on_ring(centre: Vector2, radius_m: float, samples: int = RING_SAMPLES) -> bool:
	for k: int in samples:
		var angle: float = TAU * k / samples
		if _is_land(centre + radius_m * Vector2(cos(angle), sin(angle))):
			return true
	return false


## Land on a ring at a distance, looked for every 2 m round it. The other way round from
## _land_within(): the land just beyond the field's distance can be a narrow point of the shore,
## which RING_SAMPLES points on a ring of a few hundred metres would step over.
func _land_near(centre: Vector2, radius_m: float) -> bool:
	return _land_on_ring(centre, radius_m, ceili(TAU * radius_m / 2.0))


## Land as the course maker's warnings see it: above the lake's surface, or off the map.
func _is_land(point: Vector2) -> bool:
	var height: float = _grid.height_at(point.x, point.y)
	return is_nan(height) or height > 0.0
