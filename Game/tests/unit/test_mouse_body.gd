extends GutTest
## Package B, the body on the mouse (MouseBody, ROADMAP GP2; Documentation/reports/gameplay/
## gp2_mouse_body.md). The mouse is set by values (no device): where the body goes, what it asks of
## the feet (inside GP0's bands), Max's choices (GD7) as settings, the controller adding it to the
## push slider, and the sailing scene switching it on and off.

const DT: float = 1.0 / 60.0

var _saved_values: SettingsValues
var _saved_path: String


func before_each() -> void:
	# The tests use their own settings and never write the player's settings file.
	_saved_values = GameSettings.values
	_saved_path = GameSettings.path
	GameSettings.values = SettingsValues.new()
	GameSettings.path = ""


func after_each() -> void:
	get_tree().paused = false
	GameSettings.values = _saved_values
	GameSettings.path = _saved_path


# --- Where the body goes ------------------------------------------------------------------

func test_the_mouse_moves_the_body_and_stops_at_the_ends() -> void:
	var body: MouseBody = MouseBody.new()
	assert_eq(body.travel_px, 300.0, "the design's 300 px from one end to the other")
	body.move(Vector2(150.0, 0.0))
	assert_almost_eq(body.side, 1.0, 1e-6, "half the travel from the middle: all the way right")
	body.move(Vector2(200.0, 0.0))
	assert_almost_eq(body.side, 1.0, 1e-6, "no further than the end")
	body.move(Vector2(-75.0, 0.0))
	assert_almost_eq(body.side, 0.5, 1e-6)
	body.move(Vector2(0.0, 75.0))
	assert_almost_eq(body.back, 0.5, 1e-6, "the mouse pulled toward you (down the screen): weight back")
	body.move(Vector2(0.0, -300.0))
	assert_almost_eq(body.back, -1.0, 1e-6, "pushed away: weight forward, to the end")
	body.travel_px = 600.0
	body.recentre()
	body.move(Vector2(150.0, 0.0))
	assert_almost_eq(body.side, 0.5, 1e-6, "a longer travel: the same hand movement goes half as far")


func test_left_in_the_middle_the_body_adds_nothing() -> void:
	var body: MouseBody = MouseBody.new()
	for base: float in [0.0, 2.0, 5.0, 9.0]:
		for tack: float in [1.0, -1.0]:
			assert_eq(body.rail_extra_deg(base, tack), 0.0, "no rail added at base %.0f" % base)
	for base: float in [0.0, 1.5, 2.0, 4.0]:
		assert_eq(body.trim_extra_deg(base), 0.0, "no trim added at base %.1f" % base)


func test_the_rail_goes_up_to_its_range_and_never_past_eight_degrees() -> void:
	var body: MouseBody = MouseBody.new()
	body.sideways = MouseBody.Sideways.RIGHT_IS_MORE_RAIL
	body.side = 1.0
	assert_almost_eq(body.rail_extra_deg(2.0, 1.0), 6.0, 1e-6, "the technique's 2 plus the design's 6: 8")
	assert_almost_eq(body.rail_extra_deg(5.0, 1.0), 3.0, 1e-6, "upwind the technique has 5: only 3 more (GP0: beyond 8 is only slower)")
	assert_eq(body.rail_extra_deg(9.0, 1.0), 0.0, "already past 8 (the slider and the sea): nothing more")
	body.side = 0.5
	assert_almost_eq(body.rail_extra_deg(2.0, 1.0), 3.0, 1e-6, "half way, half the range")
	body.rail_more_deg = 4.0
	assert_almost_eq(body.rail_extra_deg(2.0, -1.0), 2.0, 1e-6, "a smaller range (a setting)")


func test_the_other_way_ends_at_a_flat_board_or_at_the_windward_rail() -> void:
	var body: MouseBody = MouseBody.new()
	body.sideways = MouseBody.Sideways.RIGHT_IS_MORE_RAIL
	body.side = -1.0
	assert_almost_eq(body.rail_extra_deg(2.0, 1.0), -2.0, 1e-6, "all the way: the technique's 2 degrees taken away, flat")
	assert_almost_eq(body.rail_extra_deg(5.0, 1.0), -5.0, 1e-6, "flat from the upwind rail too")
	assert_eq(body.rail_extra_deg(0.0, 1.0), 0.0, "already flat (a broad reach): nothing to take")
	body.side = -0.5
	assert_almost_eq(body.rail_extra_deg(2.0, 1.0), -1.0, 1e-6, "half way to flat")
	body.windward_rail = true
	body.side = -1.0
	assert_almost_eq(2.0 + body.rail_extra_deg(2.0, 1.0), -MouseBody.WINDWARD_RAIL_DEG, 1e-6, "on to the windward rail down")
	body.side = -0.5
	assert_almost_eq(2.0 + body.rail_extra_deg(2.0, 1.0), -1.0, 1e-6, "half way from 2 to -4")


func test_as_seen_the_board_rolls_the_way_the_mouse_moves() -> void:
	var body: MouseBody = MouseBody.new()
	assert_eq(body.sideways, MouseBody.Sideways.AS_SEEN, "the lead's recommendation is the default (GD7 b)")
	body.side = 1.0
	# Starboard tack (tack +1): the wind from the right, the leeward rail the port one. Right puts
	# the starboard rail down, as seen from behind: the windward rail, so less leeward rail.
	assert_eq(body.more_rail(1.0), -1.0, "starboard tack: right is flatter")
	assert_eq(body.more_rail(-1.0), 1.0, "port tack: right is more leeward rail")
	body.sideways = MouseBody.Sideways.RIGHT_IS_MORE_RAIL
	assert_eq(body.more_rail(1.0), 1.0, "right is always more rail")
	assert_eq(body.more_rail(-1.0), 1.0)


func test_the_back_foot_stays_inside_gp0s_band() -> void:
	var body: MouseBody = MouseBody.new()
	assert_eq(body.trim_range_deg, 1.5, "the design's default range")
	body.back = 1.0
	assert_almost_eq(body.trim_extra_deg(2.0), 1.5, 1e-6, "2 + 1.5 = 3.5, the top of the band")
	assert_almost_eq(body.trim_extra_deg(1.5), 1.5, 1e-6, "at speed the technique's 1.5 + 1.5 = 3")
	assert_almost_eq(body.trim_extra_deg(3.0), 0.5, 1e-6, "with the slider's extra: held at 3.5")
	assert_eq(body.trim_extra_deg(4.0), 0.0, "already above the band: the body adds nothing")
	body.back = -1.0
	assert_almost_eq(body.trim_extra_deg(2.0), -1.5, 1e-6, "weight forward: 0.5, the bottom of the band")
	assert_almost_eq(body.trim_extra_deg(1.5), -1.0, 1e-6, "held at 0.5")
	assert_almost_eq(body.trim_extra_deg(4.0), -1.5, 1e-6, "above the band, forward still takes the full range")
	body.back = 0.5
	body.trim_range_deg = 1.0
	assert_almost_eq(body.trim_extra_deg(2.0), 0.5, 1e-6, "the gentler range (a setting)")


func test_left_alone_it_stays_or_springs_back() -> void:
	var body: MouseBody = MouseBody.new()
	assert_eq(body.centre, MouseBody.Centre.STAYS, "the lead's recommendation is the default (GD7 a)")
	body.side = 0.8
	body.back = -0.6
	for i: int in int(5.0 / DT):
		body.spring(DT)
	assert_almost_eq(body.side, 0.8, 1e-9, "it stays where you put it")
	body.centre = MouseBody.Centre.SPRINGS_BACK
	body.spring_back_s = 1.5
	for i: int in int(0.5 / DT):
		body.spring(DT)
	assert_between(body.side, 0.2, 0.6, "a third of the time: well on its way back")
	for i: int in int(1.0 / DT):
		body.spring(DT)
	assert_lt(absf(body.side), 0.05 * 0.8 + 1e-6, "95 % of the way back in spring_back_s")
	assert_lt(absf(body.back), 0.05 * 0.6 + 1e-6)
	body.side = 0.7
	body.recentre()
	assert_eq(body.side, 0.0, "re-centred (a tack, a gybe, a fall)")
	assert_eq(body.back, 0.0)


func test_a_body_set_by_a_script_stays_exactly_where_it_was_put() -> void:
	var body: MouseBody = MouseBody.new()
	body.scripted = true
	body.centre = MouseBody.Centre.SPRINGS_BACK
	body.side = 0.4
	body.back = -0.3
	body.move(Vector2(100.0, 100.0))
	body.spring(1.0)
	body.recentre()
	assert_eq(body.side, 0.4)
	assert_eq(body.back, -0.3)


func test_level_two_slows_the_feet() -> void:
	var body: MouseBody = MouseBody.new()
	assert_eq(body.level, 1)
	assert_eq(body.feel_time_s(0.4), 0.4, "level 1: the sailor's own 0.4 s")
	body.level = 2
	assert_eq(body.feel_time_s(0.4), MouseBody.SLOW_FEEL_TIME_S, "level 2: 2 s, as GP0 measured it")
	assert_eq(body.feel_time_s(3.0), 3.0, "never quicker than the sailor's own")


# --- The technique, as the simulation has it --------------------------------------------

func test_the_technique_rules_are_the_simulations_own() -> void:
	var sim: WindsurferSim = WindsurferSim.create_for(EnvironmentConfig.new(), false, true)
	var checked: int = 0
	for heading: int in range(0, 360, 7):
		sim.reset(Vector3.ZERO, deg_to_rad(float(heading)))
		var twa_deg: float = rad_to_deg(sim.body.wind_angle_rad(sim._felt_true_wind_from()))
		assert_almost_eq(MouseBody.technique_rail_deg(sim.sailor_config, twa_deg), sim._rail_bank_deg_by_point_of_sail(), 1e-6,
			"the rail by point of sail at a TWA of %.0f" % twa_deg)
		checked += 1
	assert_gt(checked, 40)
	# Upwind 5, across 2, flat downwind: the config's numbers.
	assert_almost_eq(MouseBody.technique_rail_deg(sim.sailor_config, 45.0), 5.0, 1e-6)
	assert_almost_eq(MouseBody.technique_rail_deg(sim.sailor_config, 100.0), 2.0, 1e-6)
	assert_almost_eq(MouseBody.technique_rail_deg(sim.sailor_config, 170.0), 0.0, 1e-6)
	for speed_ms: float in [0.0, 5.0, 12.0, 12.3, 12.9, 13.5, 16.0]:
		assert_almost_eq(MouseBody.technique_trim_deg(sim.sailor_config, speed_ms), sim._running_trim_target_deg(speed_ms), 1e-6,
			"the trim by speed at %.1f m/s" % speed_ms)


# --- The controller adds the body to the slider -----------------------------------------

## A board planing on an 18 kt broad reach (TWA 135) under the player's controller with the slider,
## held on course by AiHands (as the push harness sails it), for `seconds`.
func _sailing(controller: PlayerController, controls: SimControls, seconds: float) -> WindsurferSim:
	var sim: WindsurferSim = WindsurferSim.create_for(EnvironmentConfig.new(), false, true)
	sim.wind_config.speed_kt = 18.0
	sim.wind_config.from_bearing_deg = 270.0
	sim.wind_config.gusts_enabled = false
	sim.wind_config.shifts_enabled = false
	sim.wind = WindField.new(sim.wind_config)
	var hands: AiHands = AiHands.new()
	# The hands hold the slider where the test put it (NaN hands would let go of it).
	hands.push = controller.push_level
	controller.hands = hands
	controller.set_sail(sim.sail, sim.sailor_config, sim.air_density_kg_m3)
	controller.reset_controls(controls)
	sim.reset(Vector3.ZERO, deg_to_rad(135.0))
	for i: int in int(seconds / DT):
		var wanted_twa: float = 135.0 if sim.telemetry.speed_ms > 5.0 else 90.0
		hands.steer = LearnedSkipper.steer_toward_twa(sim.telemetry.twa_deg, 1.0, wanted_twa)
		controller.update(sim.telemetry, controls, DT)
		sim.step(DT, controls)
	return sim


func test_the_controller_adds_the_body_to_the_sliders_extras() -> void:
	var controller: PlayerController = PlayerController.new()
	controller.push_level = 1.0
	var controls: SimControls = SimControls.new()
	var sim: WindsurferSim = _sailing(controller, controls, 3.0)
	# The same telemetry twice: first without a body, then with one.
	controller.update(sim.telemetry, controls, DT)
	var slider_rail: float = controls.rail_bank_extra_deg
	var slider_trim: float = controls.trim_aim_extra_deg
	assert_gt(slider_rail, 0.5, "the slider at the top asks for rail of its own")
	assert_gt(slider_trim, 0.3, "and trim")
	var body: MouseBody = MouseBody.new()
	body.scripted = true
	body.sideways = MouseBody.Sideways.RIGHT_IS_MORE_RAIL
	body.side = 1.0
	body.back = 1.0
	controller.body = body
	controller.update(sim.telemetry, controls, DT)
	assert_ne(body.rail_deg, 0.0, "the body asks for rail")
	assert_almost_eq(controls.rail_bank_extra_deg, slider_rail + body.rail_deg, 1e-6, "added to the slider's")
	assert_almost_eq(controls.trim_aim_extra_deg, slider_trim + body.trim_deg, 1e-6)
	var technique_rail: float = MouseBody.technique_rail_deg(sim.sailor_config, sim.telemetry.twa_at_sail_deg)
	var technique_trim: float = MouseBody.technique_trim_deg(sim.sailor_config, sim.telemetry.speed_ms)
	assert_almost_eq(body.rail_total_deg, minf(technique_rail + slider_rail + 6.0, MouseBody.RAIL_MAX_DEG), 1e-6, "the rail in all, at most 8")
	assert_almost_eq(body.trim_total_deg, minf(technique_trim + slider_trim + 1.5, MouseBody.TRIM_MAX_DEG), 1e-6, "the trim in all, at most 3.5")
	assert_string_contains(controller.body_text(), "mouse body")
	# In a manoeuvre the body adds nothing.
	controller.manoeuvre = PlayerController.Manoeuvre.GYBE_BEARING_AWAY
	controller.update(sim.telemetry, controls, DT)
	assert_eq(body.rail_deg, 0.0, "nothing in a gybe")
	assert_eq(body.trim_deg, 0.0)


func test_without_a_slider_the_body_alone_sets_the_extras_and_leaves_none_behind() -> void:
	var controller: PlayerController = PlayerController.new()
	var controls: SimControls = SimControls.new()
	var sim: WindsurferSim = _sailing(controller, controls, 2.0)
	assert_true(is_nan(controller.push_level), "no slider")
	var body: MouseBody = MouseBody.new()
	body.scripted = true
	body.sideways = MouseBody.Sideways.RIGHT_IS_MORE_RAIL
	body.side = 0.5
	body.back = 0.5
	controller.body = body
	for i: int in 3:
		controller.update(sim.telemetry, controls, DT)
	assert_almost_eq(controls.rail_bank_extra_deg, body.rail_deg, 1e-6, "written afresh every tick, not added up")
	assert_almost_eq(controls.trim_aim_extra_deg, body.trim_deg, 1e-6)
	assert_almost_eq(body.trim_deg, 0.75, 1e-6, "half of the 1.5 range")
	controller.body = null
	controller.update(sim.telemetry, controls, DT)
	assert_eq(controls.rail_bank_extra_deg, 0.0, "the body switched off: nothing left")
	assert_eq(controls.trim_aim_extra_deg, 0.0)


func test_the_body_comes_back_to_the_middle_at_a_tack_and_a_restart() -> void:
	var controller: PlayerController = PlayerController.new()
	controller.push_level = 0.75
	var controls: SimControls = SimControls.new()
	var sim: WindsurferSim = _sailing(controller, controls, 1.0)
	var body: MouseBody = MouseBody.new()
	controller.body = body
	body.side = 0.6
	body.back = 0.4
	controller.update(sim.telemetry, controls, DT)
	assert_eq(body.side, 0.6, "it stays while sailing on")
	# The rig flips to the other side: a new tack.
	sim.telemetry.sail_side = -sim.telemetry.sail_side
	controller.update(sim.telemetry, controls, DT)
	assert_eq(body.side, 0.0, "a new tack: back to the technique")
	assert_eq(body.back, 0.0)
	body.side = -0.5
	controller.reset_controls(controls)
	assert_eq(body.side, 0.0, "a restart or a waterstart: back to the technique")


func test_without_a_body_the_controller_is_as_before() -> void:
	var with_nothing: PlayerController = PlayerController.new()
	with_nothing.push_level = 0.9
	var controls_a: SimControls = SimControls.new()
	var sim_a: WindsurferSim = _sailing(with_nothing, controls_a, 4.0)
	var with_a_centred_body: PlayerController = PlayerController.new()
	with_a_centred_body.push_level = 0.9
	with_a_centred_body.body = MouseBody.new()
	var controls_b: SimControls = SimControls.new()
	var sim_b: WindsurferSim = _sailing(with_a_centred_body, controls_b, 4.0)
	assert_eq(sim_b.telemetry.position, sim_a.telemetry.position, "a body left in the middle sails bit for bit as no body")
	assert_eq(controls_b.rail_bank_extra_deg, controls_a.rail_bank_extra_deg)
	assert_eq(controls_b.trim_aim_extra_deg, controls_a.trim_aim_extra_deg)


# --- The settings ---------------------------------------------------------------------

func test_the_settings_default_to_off_and_to_the_leads_recommendations() -> void:
	var values: SettingsValues = SettingsValues.new()
	assert_false(values.mouse_body, "an experiment: off unless switched on")
	assert_eq(values.body_centre, MouseBody.Centre.STAYS)
	assert_eq(values.body_sideways, MouseBody.Sideways.AS_SEEN)
	assert_false(values.body_windward_rail, "the other way ends flat")
	assert_eq(values.body_rail_deg, 6.0)
	assert_eq(values.body_trim_deg, 1.5)
	assert_eq(values.body_travel_px, 300.0)
	assert_eq(values.body_spring_s, 1.5)
	assert_eq(values.body_level, 1)


func test_the_body_settings_are_saved_read_and_clamped() -> void:
	var values: SettingsValues = SettingsValues.new()
	values.mouse_body = true
	values.body_centre = MouseBody.Centre.SPRINGS_BACK
	values.body_spring_s = 2.25
	values.body_sideways = MouseBody.Sideways.RIGHT_IS_MORE_RAIL
	values.body_windward_rail = true
	values.body_rail_deg = 4.5
	values.body_trim_deg = 1.0
	values.body_travel_px = 450.0
	values.body_level = 2
	var file: ConfigFile = ConfigFile.new()
	values.write_to(file)
	var read: SettingsValues = SettingsValues.new()
	read.read_from(file)
	assert_true(read.mouse_body)
	assert_eq(read.body_centre, MouseBody.Centre.SPRINGS_BACK)
	assert_eq(read.body_spring_s, 2.25)
	assert_eq(read.body_sideways, MouseBody.Sideways.RIGHT_IS_MORE_RAIL)
	assert_true(read.body_windward_rail)
	assert_eq(read.body_rail_deg, 4.5)
	assert_eq(read.body_trim_deg, 1.0)
	assert_eq(read.body_travel_px, 450.0)
	assert_eq(read.body_level, 2)
	var body: MouseBody = MouseBody.new()
	body.configure(read)
	assert_eq(body.centre, MouseBody.Centre.SPRINGS_BACK, "the menu's choices reach the body")
	assert_eq(body.travel_px, 450.0)
	assert_eq(body.level, 2)
	assert_true(body.windward_rail)
	# A hand-edited file cannot ask for more than the menu allows.
	file.set_value("body", "rail_deg", 20.0)
	file.set_value("body", "trim_deg", 5.0)
	file.set_value("body", "travel_px", 10.0)
	file.set_value("body", "level", 7)
	file.set_value("body", "centre", 9)
	read.read_from(file)
	assert_eq(read.body_rail_deg, SettingsValues.BODY_RAIL_MAX_DEG)
	assert_eq(read.body_trim_deg, SettingsValues.BODY_TRIM_MAX_DEG)
	assert_eq(read.body_travel_px, SettingsValues.BODY_TRAVEL_MIN_PX)
	assert_eq(read.body_level, 2)
	assert_eq(read.body_centre, MouseBody.Centre.size() - 1)


func test_level_two_slows_only_the_boards_own_sailor() -> void:
	var node: WindsurferNode = autofree(WindsurferNode.new())
	node.own_config_copies = true
	node.sim = WindsurferSim.create_for(EnvironmentConfig.new(), false, true)
	var own_s: float = node.sim.sailor_config.lean_feel_time_s
	var body: MouseBody = MouseBody.new()
	body.level = 2
	node.use_body_level(body)
	assert_eq(node.sim.sailor_config.lean_feel_time_s, MouseBody.SLOW_FEEL_TIME_S, "level 2 on the board's own copy")
	body.level = 1
	node.use_body_level(body)
	assert_eq(node.sim.sailor_config.lean_feel_time_s, own_s, "level 1: the sailor's own again")
	body.level = 2
	node.use_body_level(body)
	node.use_body_level(null)
	assert_eq(node.sim.sailor_config.lean_feel_time_s, own_s, "the body switched off: the sailor's own")
	var shared: WindsurferNode = autofree(WindsurferNode.new())
	shared.sim = WindsurferSim.create_for(EnvironmentConfig.new(), false, false)
	var shared_s: float = shared.sim.sailor_config.lean_feel_time_s
	shared.use_body_level(body)
	assert_eq(shared.sim.sailor_config.lean_feel_time_s, shared_s, "a shared config is never written")


# --- The sailing scene ------------------------------------------------------------------

func test_the_setting_switches_the_body_on_and_off_in_the_sailing_scene() -> void:
	var scene: SailingScene = (load("res://main.tscn") as PackedScene).instantiate()
	add_child_autofree(scene)
	var windsurfer: WindsurferNode = scene.get_node("Windsurfer")
	assert_null(windsurfer.controller.body, "off by default")
	GameSettings.values.mouse_body = true
	GameSettings.values.body_level = 2
	GameSettings.values.body_travel_px = 500.0
	scene.apply_settings_live()
	assert_not_null(windsurfer.controller.body, "on from the menu, at once")
	assert_eq(windsurfer.controller.body.travel_px, 500.0)
	assert_eq(windsurfer.sim.sailor_config.lean_feel_time_s, MouseBody.SLOW_FEEL_TIME_S, "level 2 on the player's own sailor")
	assert_ne(Input.mouse_mode, Input.MOUSE_MODE_CAPTURED, "a headless run never captures the mouse")
	var body: MouseBody = windsurfer.controller.body
	body.side = 0.3
	GameSettings.values.body_level = 1
	scene.apply_settings_live()
	assert_eq(windsurfer.controller.body, body, "a setting changed: the same body, in the same place")
	assert_eq(body.side, 0.3)
	assert_almost_eq(windsurfer.sim.sailor_config.lean_feel_time_s, 0.4, 1e-6, "level 1: the sailor's own 0.4 s")
	GameSettings.values.mouse_body = false
	scene.apply_settings_live()
	assert_null(windsurfer.controller.body, "off again")


func test_the_body_tab_has_the_switch_and_the_choices() -> void:
	var settings: SettingsMenu = (load("res://ui/settings_menu.tscn") as PackedScene).instantiate()
	add_child_autofree(settings)
	settings.show_tab("body")
	var tabs: TabContainer = settings.get_node("%Tabs")
	assert_eq(tabs.get_tab_title(tabs.current_tab), "Body")
	var grid: GridContainer = settings.get_node("%BodyRows")
	var names: Array[String] = []
	for child: Node in grid.get_children():
		if child is Label and (child as Label).theme_type_variation != &"HintLabel" and (child as Label).text != "":
			names.append((child as Label).text)
	for wanted: String in ["Mouse body (experiment)", "Mouse left alone", "Spring-back time", "Sideways", "Rail", "Windward rail", "Back foot", "Mouse travel", "Level"]:
		assert_has(names, wanted, "the row %s" % wanted)
	# The switch turns it on in the settings at once.
	var switch: CheckButton = null
	for child: Node in grid.get_children():
		if child is CheckButton:
			switch = child as CheckButton
			break
	switch.button_pressed = true
	assert_true(GameSettings.values.mouse_body)
