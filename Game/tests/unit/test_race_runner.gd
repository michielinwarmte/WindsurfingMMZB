extends GutTest
## The race in a scene (RaceRunner): where the boards wait before the start, and the start menu's
## hand-over (RaceSetup). The runner itself needs the scene tree and the windsurfer scenes, and is
## checked with screenshots (RACING_PLAN.md, 9A).


func test_boards_wait_behind_the_line_spread_along_it_with_the_player_in_the_middle() -> void:
	var course: Course = RaceCourses.t1_loop(270.0, Vector2.ZERO)
	var race: RaceSim = RaceSim.new(course, 1, 30.0)
	var start: RaceStep = race.steps()[0]
	var spots: PackedVector2Array = RaceRunner.pre_start_spots(course, start, 4, 75.0)
	assert_eq(spots.size(), 4, "one spot per board")
	var middle: Vector2 = course.start_middle()
	var line_dir: Vector2 = (start.points[0] - start.points[1]).normalized()
	for spot: Vector2 in spots:
		var behind_m: float = (middle - spot).dot(start.in_dir)
		assert_almost_eq(behind_m, 75.0, 2.0, "75 m behind the line")
		var along_m: float = absf((spot - middle).dot(line_dir))
		assert_true(along_m <= 30.0, "within the 60 m line: %.1f m from its middle" % along_m)
	for i: int in range(1, spots.size()):
		assert_true(spots[0].distance_to(middle) <= spots[i].distance_to(middle) + 0.01, "the player nearest the middle")
	# Two boards are apart along the line.
	assert_true(spots[0].distance_to(spots[1]) > 5.0, "the boards do not share a spot")


func test_a_pending_race_setup_is_taken_once() -> void:
	RaceSetup.pending = RaceSetup.race("t1_loop")
	var taken: RaceSetup = RaceSetup.take()
	assert_eq(taken.course_name, "t1_loop")
	assert_eq(taken.skippers.size(), 3, "three opponents by default")
	assert_eq(taken.prestart_s, 60.0)
	assert_null(RaceSetup.take(), "taken once")


func test_the_race_hud_tells_the_gap_the_turn_and_the_wind() -> void:
	assert_eq(RaceHud.gap_text(PackedFloat32Array([10.0, 100.0]), PackedFloat32Array([12.0])), "-2.0 s", "they crossed the start 2 s before you")
	assert_eq(RaceHud.gap_text(PackedFloat32Array([15.0]), PackedFloat32Array([12.0, 90.0])), "+3.0 s", "you crossed 3 s before them")
	assert_eq(RaceHud.gap_text(PackedFloat32Array(), PackedFloat32Array([12.0])), "", "nothing to compare yet")
	# Heading north, a mark to the east is 90 degrees to starboard; to the west, 90 to port.
	assert_almost_eq(RaceHud.relative_bearing_deg(Vector2.ZERO, Vector2(100.0, 0.0), 0.0), 90.0, 0.01)
	assert_almost_eq(RaceHud.relative_bearing_deg(Vector2.ZERO, Vector2(-100.0, 0.0), 0.0), -90.0, 0.01)
	assert_eq(RaceHud.turn_text(-12.4), "12 deg to port")
	assert_eq(RaceHud.turn_text(1.0), "ahead")
	assert_eq(RaceHud.compass_name(270.0), "W")
	assert_eq(RaceHud.compass_name(222.0), "SW")
	assert_eq(RaceHud.clock(65.2), "1:05.2")


## The exported game must ship the .tres files as text: the export's conversion to binary dropped
## every number of the skippers' polar (Game/config/skipper_polar.tres; its defaults are empty), and
## in the released game the whole fleet pointed into the wind at the start (Session 68).
func test_the_export_keeps_the_resources_as_text() -> void:
	assert_false(ProjectSettings.get_setting("editor/export/convert_text_resources_to_binary", true),
		"project.godot: [editor] export/convert_text_resources_to_binary=false")
	var polar: SkipperPolar = SkipperPolar.default_polar()
	assert_eq(polar.winds_kt.size(), 3, "the polar's winds")
	assert_eq(polar.speed_ms.size(), polar.winds_kt.size() * polar.twa_deg.size(), "a speed for every wind and angle")


## The fleet table: everyone in a small fleet; in a big one the leaders, a gap, and the boards
## around you (RaceHud.FLEET_ROWS lines at most).
func test_the_fleet_table_keeps_the_leaders_and_the_boards_around_you() -> void:
	var small: Array[int] = [3, 0, 1, 2]
	assert_eq(RaceHud.fleet_rows(small, 0, 9), small)
	var big: Array[int] = []
	for i: int in 21:
		big.append(20 - i)  # board 20 leads, board 0 is last
	assert_eq(RaceHud.fleet_rows(big, 17, 9), big.slice(0, 9), "you are among the first: no gap")
	var middle: Array[int] = RaceHud.fleet_rows(big, 10, 9)
	assert_eq(middle.size(), 9)
	assert_eq(middle.slice(0, 4), [20, 19, 18, -1] as Array[int], "the leaders, then the gap")
	assert_true(middle.has(10) and middle.has(11) and middle.has(9), "you and the boards either side")
	var last: Array[int] = RaceHud.fleet_rows(big, 0, 9)
	assert_eq(last.back(), 0, "the last board's own line is the bottom one")
	assert_eq(last.size(), 9)


## A depth grid for the shore test: deep water west of a straight north-south shore, land east of it.
class ShoreAtX:
	extends TerrainGrid
	var shore_x: float = 0.0

	func _init(x: float) -> void:
		shore_x = x

	func contains(x: float, z: float) -> bool:
		return absf(x) <= 5000.0 and absf(z) <= 5000.0

	func height_at(x: float, z: float) -> float:
		if not contains(x, z):
			return NAN
		return -5.0 if x < shore_x else 2.0


## ROADMAP RA2: an AI board that runs onto the shore stops there, as the player's board does (the
## scene's stop: its simulation no longer steps), and sails again after the next start.
func test_an_ai_board_stops_at_the_shore_like_the_player() -> void:
	var saved_values: SettingsValues = GameSettings.values
	var saved_path: String = GameSettings.path
	GameSettings.values = SettingsValues.new()
	GameSettings.path = ""
	RaceSetup.pending = RaceSetup.race("t1_loop", PackedStringArray(["allrounder"]))
	var scene: SailingScene = (load("res://main.tscn") as PackedScene).instantiate()
	add_child_autofree(scene)
	var runner: RaceRunner = scene.get_node("RaceRunner")
	var player: WindsurferNode = scene.get_node("Windsurfer")
	var ai: WindsurferNode = runner.opponents[0]
	# The AI board 300 m east of the player, the shore half way: it is on land, the player afloat.
	var player_at: Vector3 = player.sim.body.origin_world()
	ai.start_position = player_at + Vector3(300.0, 0.0, 0.0)
	ai.reset()
	scene.shore_grid = ShoreAtX.new(player_at.x + 150.0)
	await wait_physics_frames(3)
	assert_true(runner.is_aground(ai), "the AI board on land has run aground")
	assert_false(runner.is_aground(player), "the player's board is the scene's to stop")
	assert_false(scene.is_aground(), "the player is afloat")
	var ai_time_s: float = ai.sim.time_s
	var ai_at: Vector3 = ai.sim.body.origin_world()
	var player_time_s: float = player.sim.time_s
	await wait_physics_frames(5)
	assert_eq(ai.sim.time_s, ai_time_s, "the AI board's simulation has stopped")
	assert_eq(ai.sim.body.origin_world(), ai_at, "and it stays where it ran aground")
	assert_gt(player.sim.time_s, player_time_s, "the player sails on")
	assert_gt(runner.wind_clock.time_s, 0.0, "the race's wind clock goes on with the boards that sail")

	# The next start (R): every board is afloat at its start spot and sails again.
	scene.shore_grid = null
	scene.get_node("PauseMenu").restart_requested.emit()
	assert_false(runner.is_aground(ai), "afloat again after R")
	await wait_physics_frames(3)
	assert_gt(ai.sim.time_s, 0.0, "the AI board sails again")
	GameSettings.values = saved_values
	GameSettings.path = saved_path
	get_tree().paused = false
