extends GutTest
## The AI's lookout for Lake Silvaplana's shore (ShoreLookout; Max, 6 November 2026: the AI races
## every iQFOiL course on the lake without going onto the shore): open water in the middle of the
## lake, none on land or off the grid, and a look along a heading that ends before the shore. And the
## iQFOiL courses laid on the lake (tools/fit_courses.sh --all=1): every one there, every mark on open
## water with room to the shore.

const GRID_PATH: String = "res://maps/silvaplana/terrain/shore_heights.json"
const MAP_CONFIG_PATH: String = "res://maps/silvaplana/map_config.tres"
## Mark 1 of the lake's windward-leeward course (iq_lg2.json), in the middle of the lake, LV95.
const MID_LAKE_LV95: Vector2 = Vector2(2780086.68, 1146083.6)

var _grid: TerrainGrid
var _config: MapConfig
var _lookout: ShoreLookout


func before_all() -> void:
	_grid = TerrainGrid.load_from(GRID_PATH)
	_config = load(MAP_CONFIG_PATH)
	_lookout = ShoreLookout.for_lake(_grid, _mid_lake())


func test_the_middle_of_the_lake_is_open_and_the_land_is_not() -> void:
	assert_true(_lookout.is_open(_mid_lake()), "mid-lake")
	assert_false(_lookout.is_open(_mid_lake() + Vector2(5000.0, 0.0)), "5 km east is the mountain")
	assert_false(_lookout.is_open(Vector2(1.0e6, 1.0e6)), "off the grid")


func test_a_look_toward_the_shore_ends_before_it_and_one_along_the_lake_goes_on() -> void:
	# Across the lake (to the south-east, the lake runs south-west to north-east) the shore is a few
	# hundred metres away; along it, to the north-east, there is open water far ahead.
	var across_m: float = _lookout.water_ahead_m(_mid_lake(), 132.0, 2000.0)
	assert_true(across_m > 50.0 and across_m < 2000.0, "the shore across the lake: %.0f m" % across_m)
	var position_there: Vector2 = _mid_lake() + Course.direction_of(132.0) * (across_m + ShoreLookout.STEP_M)
	assert_false(_lookout.is_open(position_there), "and just past it the open water has ended")
	assert_almost_eq(_lookout.water_ahead_m(_mid_lake(), 42.0, 150.0), 150.0, 0.01, "open water ahead along the lake")


func test_every_iqfoil_course_is_on_the_lake_with_its_marks_on_open_water() -> void:
	for id: String in CourseTemplates.ALL:
		var course: Course = RaceCourses.load_named("iq_%s" % id.to_lower(), _config)
		assert_not_null(course, "the lake has %s" % id)
		if course == null:
			continue
		assert_eq(course.template, id)
		for mark: CourseMark in course.marks:
			assert_true(_lookout.is_open(mark.position), "%s's %s on open water" % [id, mark.id])
		var title: String = RaceCourses.saved_title("iq_%s" % id.to_lower())
		assert_true(title.begins_with("iQFOiL"), "the menus show its name: " + title)


func _mid_lake() -> Vector2:
	var at: Vector3 = _config.lv95_to_game(MID_LAKE_LV95.x, MID_LAKE_LV95.y, _config.lake_level_m)
	return Vector2(at.x, at.z)
