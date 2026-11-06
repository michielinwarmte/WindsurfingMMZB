extends GutTest
## The race screen spread over the window (Max, 6 November 2026; Documentation/reports/ui/
## race_screen_6nov.md): every panel in its corner or along its edge, none on top of another, in
## the 1280 x 720 layout the project's stretch scales to any window (hud.gd); the mini-map as big as
## its setting says, at once when the setting changes; the standings fitting above the mini-map;
## the race card's two lines for the LAN race director; a big fleet's results in two columns.

var _percent_before: float = 0.0
## The window as the test runner has it (headless: a small square one), put back after each test.
var _window_before: Vector2i = Vector2i.ZERO


## Every test lays the HUD out in a 1280 x 720 window, the layout's own size (the stretch draws it
## bigger in a bigger window; a wider one gives it more room across).
func before_each() -> void:
	_percent_before = GameSettings.values.minimap_size_percent
	_window_before = get_window().size
	get_window().size = Vector2i(1280, 720)


func after_each() -> void:
	GameSettings.values.minimap_size_percent = _percent_before
	get_window().size = _window_before


## A HUD with a race on it, as RaceRunner makes it: the course on the small map, the race's own
## block added to the layer, the push gauge showing.
func _racing_hud() -> Array:
	var hud: Hud = Hud.new()
	add_child_autofree(hud)
	hud.show_course(RaceCourses.t1_loop(270.0, Vector2(0.0, -150.0)))
	var race_hud: RaceHud = RaceHud.new()
	hud.add_child(race_hud)
	hud.set_race_mode(true)
	var controller: PlayerController = PlayerController.new()
	controller.push_level = 0.75
	hud.update_from(Telemetry.new(), controller, "Follow", false)
	return [hud, race_hud]


func _screen() -> Rect2:
	return get_viewport().get_visible_rect()


func test_the_panels_sit_in_their_places_and_do_not_overlap() -> void:
	var made: Array = _racing_hud()
	var hud: Hud = made[0]
	var race_hud: RaceHud = made[1]
	race_hud._fleet_card.show()
	await wait_process_frames(2)  # the containers lay themselves out
	var screen: Rect2 = _screen()
	var panels: Dictionary[String, Rect2] = {
		"race card": race_hud._card.get_global_rect(),
		"standings": race_hud._fleet_card.get_global_rect(),
		"speed card": race_hud._speed_card.get_global_rect(),
		"gauges": hud._gauges.get_global_rect(),
		"mini-map": hud._mini_map.get_global_rect(),
		"compass": hud._rose.get_global_rect(),
	}
	for name: String in panels:
		assert_true(screen.encloses(panels[name]), "%s on the screen: %s" % [name, panels[name]])
	var names: Array[String] = panels.keys()
	for i: int in names.size():
		for j: int in range(i + 1, names.size()):
			assert_false(panels[names[i]].intersects(panels[names[j]]), "%s and %s apart" % [names[i], names[j]])
	# Where each one is: the race card at the top in the middle, the speed bottom left, the standings
	# and the small map on the right, the gauges at the bottom in the middle.
	assert_almost_eq(panels["race card"].get_center().x, screen.size.x * 0.5, 1.0, "the race card in the middle")
	assert_lt(panels["race card"].position.y, 20.0, "at the top")
	assert_almost_eq(panels["speed card"].position.x, Hud.MARGIN, 0.5, "the speed at the left")
	assert_almost_eq(panels["speed card"].end.y, screen.size.y - Hud.BOTTOM_INSET, 0.5, "at the bottom")
	assert_almost_eq(panels["standings"].end.x, screen.size.x - Hud.MARGIN, 0.5, "the standings at the right")
	assert_lt(panels["standings"].end.y, panels["mini-map"].position.y, "above the small map")
	assert_almost_eq(panels["mini-map"].end, screen.size - Vector2(Hud.MARGIN, Hud.BOTTOM_INSET), Vector2.ONE * 0.5, "the small map in the corner")
	assert_almost_eq(panels["gauges"].get_center().x, screen.size.x * 0.5, 1.0, "the gauges in the middle")
	# The keys along the bottom edge, below everything else, and they fit across.
	var keys: Rect2 = hud._hints.get_global_rect()
	assert_gt(keys.position.y, panels["gauges"].end.y, "the keys under the gauges")
	assert_lte(hud._hints.get_combined_minimum_size().x, screen.size.x - 2.0 * Hud.MARGIN, "the keys fit across")
	assert_string_contains(hud.help_text(), "Space tack / gybe")
	assert_string_contains(hud.help_text(), "R race again")


## The free-sailing card at the bottom left: the forecast wind large and no speed with the sailor's
## view (GD6); the speed without it.
func test_the_free_sailing_card_reads_the_wind_or_the_speed() -> void:
	var hud: Hud = Hud.new()
	add_child_autofree(hud)
	var t: Telemetry = Telemetry.new()
	t.tws_10m_kt = 18.0
	t.wind_from_bearing_deg = 270.0
	t.speed_kmh = 31.5
	t.is_planing = true
	hud.update_from(t, PlayerController.new(), "Follow", false)
	assert_true(hud.status_text().begins_with("wind 18 kt from W (270°)"), hud.status_text())
	assert_false(hud.status_text().contains("km/h"), "the sailor's view: no speed")
	hud.sailor_view = false
	hud.update_from(t, PlayerController.new(), "Follow", false)
	assert_true(hud.status_text().begins_with("31.5 km/h"), hud.status_text())
	assert_string_contains(hud.help_text(), "F1 panel")


## The setting "Mini-map size": the map's longer side is that share of the window's height, and a
## change applies at once (the pause menu's settings), the map staying in its corner.
func test_the_mini_map_is_as_big_as_its_setting_at_once() -> void:
	GameSettings.values.minimap_size_percent = 35.0
	var made: Array = _racing_hud()
	var hud: Hud = made[0]
	var race_hud: RaceHud = made[1]
	var map: MiniMap = hud._mini_map
	var screen: Rect2 = _screen()
	assert_almost_eq(maxf(map.size.x, map.size.y), 0.35 * screen.size.y, 0.5, "35 % of the height by default")
	var rows_medium: int = race_hud.fleet_room_rows()
	GameSettings.values.minimap_size_percent = 50.0
	GameSettings.notify_changed()
	assert_almost_eq(maxf(map.size.x, map.size.y), 0.5 * screen.size.y, 0.5, "50 % at once")
	assert_almost_eq(map.get_global_rect().end, screen.size - Vector2(Hud.MARGIN, Hud.BOTTOM_INSET), Vector2.ONE * 0.5, "still in its corner")
	var rows_big: int = race_hud.fleet_room_rows()
	assert_lt(rows_big, rows_medium, "fewer lines of standings above a bigger map")
	assert_gte(rows_big, RaceHud.FLEET_MIN_ROWS)
	# The standings at their fewest still end above the biggest map.
	var row_px: float = HudStyle.sans(600).get_height(RaceHud.FLEET_FONT_SIZE) + 1.0
	var standings_bottom: float = Hud.RIGHT_COLUMN_TOP + 20.0 + rows_big * row_px
	assert_lt(standings_bottom, map.get_global_rect().position.y, "the standings fit above the biggest map")
	GameSettings.values.minimap_size_percent = 20.0
	GameSettings.notify_changed()
	assert_almost_eq(maxf(map.size.x, map.size.y), 0.2 * screen.size.y, 0.5)
	assert_eq(MiniMap.size_name(20.0), "small")
	assert_eq(MiniMap.size_name(35.0), "medium")
	assert_eq(MiniMap.size_name(50.0), "extra large")
	assert_almost_eq(MiniMap.size_for(90.0, 720.0), 360.0, 1e-4, "no bigger than half the height")


## The LAN race director: a moved mark shows on the small map at once; on the open water the map is
## framed anew only when a mark comes near its edge (it does not jump while a mark is dragged).
func test_the_mini_map_shows_a_changed_course_at_once() -> void:
	var hud: Hud = Hud.new()
	add_child_autofree(hud)
	var course: Course = RaceCourses.t1_loop(270.0, Vector2(0.0, -150.0))
	hud.show_course(course)
	var map: MiniMap = hud._mini_map
	var size_before: Vector2 = map.size
	var mark: CourseMark = course.mark("1")
	var on_map_before: Vector2 = map.map_point(Vector3(mark.position.x, 0.0, mark.position.y))
	mark.position += Vector2(0.0, 30.0)
	hud.show_course(course)
	assert_eq(map.size, size_before, "a small move: the same frame")
	var on_map: Vector2 = map.map_point(Vector3(mark.position.x, 0.0, mark.position.y))
	assert_gt(on_map.y, on_map_before.y, "the mark drawn further south")
	mark.position += Vector2(-600.0, 0.0)
	hud.show_course(course)
	var moved: Vector2 = map.map_point(Vector3(mark.position.x, 0.0, mark.position.y))
	assert_true(Rect2(Vector2.ZERO, map.size).has_point(moved), "a mark far off the old frame: the map frames the course anew")
	assert_almost_eq(map.get_global_rect().end, _screen().size - Vector2(Hud.MARGIN, Hud.BOTTOM_INSET), Vector2.ONE * 0.5, "and stays in its corner")


## The race card has two lines for the LAN race director (its next start, its news), hidden while
## empty; a new race (reset) leaves them.
func test_the_race_card_has_two_lines_for_the_race_director() -> void:
	var race_hud: RaceHud = RaceHud.new()
	add_child_autofree(race_hud)
	assert_eq(race_hud.card_line(0), "")
	assert_false(race_hud._card_lines[0].visible, "hidden while empty")
	race_hud.set_card_line(0, "Next start in 1:30")
	race_hud.set_card_line(1, "Mark 2 moved 40 m to the east", HudStyle.HIGHLIGHT_COLOR)
	assert_eq(race_hud.card_line(0), "Next start in 1:30")
	assert_true(race_hud._card_lines[1].visible)
	assert_true(race_hud._card_lines[0].get_parent().get_parent() == race_hud._card, "on the race card")
	race_hud.reset()
	assert_eq(race_hud.card_line(1), "Mark 2 moved 40 m to the east", "the director's, not the race's: they stay")
	race_hud.set_card_line(1, "")
	assert_false(race_hud._card_lines[1].visible)


## A big fleet's results (8 players and 20 AI boards on a LAN race) fit in the window: under the race
## card, above the gauges, clear of the small map, in columns and a smaller text as they need (Max,
## 6 November 2026: "ui of the finishing leaderboard is out of frame": the table was centred on the
## window's top left corner). Also with penalties and long names, and in a wide window.
func test_a_big_fleet_s_results_stay_inside_the_window() -> void:
	for window: Vector2i in [Vector2i(1280, 720), Vector2i(1788, 720), Vector2i(1280, 960)]:
		get_window().size = window
		var made: Array = _racing_hud()
		var hud: Hud = made[0]
		var race_hud: RaceHud = made[1]
		await wait_process_frames(2)
		for long_names: bool in [false, true]:
			var lines: PackedStringArray = PackedStringArray(["  Results", ""])
			for i: int in 28:
				var who: String = ("A Long Player Name %d" % (i + 1)) if long_names else ("Board %d" % (i + 1))
				lines.append("  %d. %-14s 12:34.5   +1:02.3%s" % [i + 1, who, "   (30 s penalty)" if i % 4 == 3 else ""])
			lines.append_array(["", "  R: race again     Esc: menu"])
			race_hud._show_results("\n".join(lines))
			race_hud._results.show()
			await wait_process_frames(2)
			var screen: Rect2 = _screen()
			var table: Rect2 = race_hud._results.get_global_rect()
			var at: String = "%s, long names %s: %s" % [window, long_names, table]
			assert_true(screen.encloses(table), "the results inside the window, " + at)
			assert_gt(table.position.y, race_hud._card.get_global_rect().end.y, "under the race card, " + at)
			assert_lt(table.end.y, hud._gauges.get_global_rect().position.y, "above the gauges, " + at)
			assert_false(table.intersects(hud._mini_map.get_global_rect()), "clear of the small map, " + at)
			assert_almost_eq(table.get_center().x, screen.size.x * 0.5, 1.0, "in the middle, " + at)
			var shown: String = "\n".join(race_hud.results_columns())
			assert_string_contains(shown, "1. ")
			assert_string_contains(shown, "28. ", "every board is on it, " + at)
		race_hud._show_results("  Results\n\n  1. You  4:01.2\n\n  R: race again     Esc: menu")
		await wait_process_frames(1)
		assert_eq(race_hud.results_columns().size(), 1, "a small fleet: one column")
		var small: Rect2 = race_hud._results.get_global_rect()
		assert_lt(small.size.x, 400.0, "and the panel as small as its text again")
		hud.queue_free()
		await wait_process_frames(1)


## A short standings table (a big small map) keeps the leader, a gap, you and your neighbours.
func test_a_short_standings_table_keeps_you_and_the_leader() -> void:
	var big: Array[int] = []
	for i: int in 28:
		big.append(i)
	var rows: Array[int] = RaceHud.fleet_rows(big, 15, 4)
	assert_eq(rows.size(), 4)
	assert_eq(rows[0], 0, "the leader")
	assert_eq(rows[1], -1, "the gap")
	assert_true(rows.has(15), "you")
	var six: Array[int] = RaceHud.fleet_rows(big, 15, 6)
	assert_eq(six.slice(0, 3), [0, 1, -1] as Array[int], "two leaders in six lines")
	assert_true(six.has(14) and six.has(15) and six.has(16), "you and either side")


## The settings' Sailing tab has the row "Mini-map size"; moving its slider resizes a running HUD's
## small map at once (as from the pause menu while sailing).
func test_the_settings_slider_resizes_the_mini_map_at_once() -> void:
	GameSettings.values.minimap_size_percent = 35.0
	var made: Array = _racing_hud()
	var hud: Hud = made[0]
	var settings: SettingsMenu = (load("res://ui/settings_menu.tscn") as PackedScene).instantiate()
	add_child_autofree(settings)
	settings.open()
	var rows: GridContainer = settings.get_node("%SailingRows")
	var slider: HSlider = null
	var children: Array[Node] = rows.get_children()
	for i: int in children.size():
		if children[i] is Label and (children[i] as Label).text == "Mini-map size":
			slider = children[i + 1] as HSlider
	assert_not_null(slider, "a row called Mini-map size with a slider")
	if slider == null:
		return
	assert_almost_eq(slider.value, 35.0, 1e-6)
	slider.value = 45.0
	assert_almost_eq(GameSettings.values.minimap_size_percent, 45.0, 1e-6, "into the settings")
	var map: MiniMap = hud._mini_map
	assert_almost_eq(maxf(map.size.x, map.size.y), 0.45 * _screen().size.y, 0.5, "the map is that big at once")
	await wait_process_frames(1)  # the settings page built its rows twice (open()): the first ones go
