extends GutTest
## The push on the mouse (GP2; Max, 6 November 2026: "push in combination with mouse control";
## Documentation/reports/gameplay/gp2_push_on_mouse.md). With the body on the mouse, the wheel moves
## the push in steps and the left button held is a burst to 100 % that comes back to the level the
## wheel and the keys had; W and S keep working. The wheel and the button are set by values (no
## device), as test_mouse_body.gd sets the mouse.

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
	for action: String in ["push_more", "push_less", "camera_look"]:
		Input.action_release(action)
	GameSettings.values = _saved_values
	GameSettings.path = _saved_path


## The player's controller (no AI hands) on a board on the water, one step in: the telemetry the
## updates read. The board is not stepped further: these tests are about the slider, not the sailing.
func _player_on_the_water(controller: PlayerController, controls: SimControls) -> WindsurferSim:
	var sim: WindsurferSim = WindsurferSim.create_for(EnvironmentConfig.new(), false, true)
	controller.set_sail(sim.sail, sim.sailor_config, sim.air_density_kg_m3)
	controller.reset_controls(controls)
	sim.reset(Vector3.ZERO, deg_to_rad(135.0))
	sim.step(DT, controls)
	return sim


func _updates(controller: PlayerController, sim: WindsurferSim, controls: SimControls, count: int) -> void:
	for i: int in count:
		controller.update(sim.telemetry, controls, DT)


# --- The body's part: the wheel's notches and the button ---------------------------------------

func test_the_wheel_counts_in_steps_and_the_button_holds_the_burst() -> void:
	var body: MouseBody = MouseBody.new()
	assert_eq(body.push_on_mouse, MouseBody.PushOnMouse.WHEEL_AND_BUTTON, "the lead's recommendation")
	assert_eq(body.push_step, 0.1, "10 % a notch")
	body.wheel(1.0)
	body.wheel(1.0)
	body.wheel(-0.5)
	assert_almost_eq(body.take_push_change(), 0.15, 1e-6, "one and a half notches up: 15 % more")
	assert_eq(body.take_push_change(), 0.0, "the notches are taken once")
	body.hold_burst(true)
	assert_true(body.burst_held, "the left button held")
	body.hold_burst(false)
	assert_false(body.burst_held, "let go")
	body.push_on_mouse = MouseBody.PushOnMouse.WHEEL
	body.hold_burst(true)
	assert_false(body.burst_held, "the wheel only: the button is not the push's")
	body.wheel(2.0)
	assert_almost_eq(body.take_push_change(), 0.2, 1e-6, "the wheel still steps")
	body.push_on_mouse = MouseBody.PushOnMouse.OFF
	body.wheel(3.0)
	assert_eq(body.take_push_change(), 0.0, "off: the wheel is not the push's")
	body.push_on_mouse = MouseBody.PushOnMouse.WHEEL_AND_BUTTON
	body.wheel(1.0)
	body.hold_burst(true)
	body.let_go_of_the_push()
	assert_false(body.burst_held, "the mouse freed (a menu): no burst")
	assert_eq(body.take_push_change(), 0.0, "and no notch waiting")
	assert_string_contains(body.describe(), "left button held: burst to 100 %", "the F1 panel lists the mouse's push")


# --- The controller: the level chosen and the level the sailor is at --------------------------

func test_the_wheel_steps_the_players_push_at_a_human_pace() -> void:
	var controller: PlayerController = PlayerController.new()
	controller.push_level = 0.75
	controller.body = MouseBody.new()
	var controls: SimControls = SimControls.new()
	var sim: WindsurferSim = _player_on_the_water(controller, controls)
	_updates(controller, sim, controls, 1)
	assert_eq(controller.push_now, 0.75, "the first level: at once")
	controller.body.wheel(1.0)
	_updates(controller, sim, controls, 1)
	assert_almost_eq(controller.push_level, 0.85, 1e-6, "a notch up: 10 % more, the ladder's 85 %")
	assert_lt(controller.push_now, 0.85, "the sailor gets there at a human pace, not in one tick")
	_updates(controller, sim, controls, 6)
	assert_almost_eq(controller.push_now, 0.85, 1e-6, "within a tenth of a second")
	controller.body.wheel(-3.0)
	_updates(controller, sim, controls, 1)
	assert_almost_eq(controller.push_level, 0.55, 1e-6, "three notches down")
	assert_gt(controller.push_now, controller.push_level, "the sailor still coming down")
	assert_false(controller.is_bursting(), "a notch down is not a burst (the gauge shows no BURST)")
	controller.body.wheel(9.0)
	_updates(controller, sim, controls, 1)
	assert_eq(controller.push_level, 1.0, "no further than the top")
	controller.body.wheel(-20.0)
	_updates(controller, sim, controls, 1)
	assert_eq(controller.push_level, 0.0, "nor below the bottom")


func test_the_left_button_bursts_to_the_top_and_comes_back() -> void:
	var controller: PlayerController = PlayerController.new()
	controller.push_level = 0.75
	var body: MouseBody = MouseBody.new()
	controller.body = body
	var controls: SimControls = SimControls.new()
	var sim: WindsurferSim = _player_on_the_water(controller, controls)
	_updates(controller, sim, controls, 2)
	body.hold_burst(true)
	var ticks: int = 0
	while controller.push_now < 1.0 and ticks < 120:
		controller.update(sim.telemetry, controls, DT)
		ticks += 1
	assert_eq(controller.push_now, 1.0, "the burst: the top of the ladder")
	assert_almost_eq(ticks * DT, 0.25, 2.0 * DT, "from 75 % in a quarter of a second (push_mouse_rate_per_s)")
	assert_eq(controller.push_level, 0.75, "the level chosen stays where it was")
	assert_true(controller.is_bursting())
	assert_string_contains(controller.push_text(), "push 100 %", "the F1 panel shows the level the sailor is at")
	assert_string_contains(controller.burst_text(), "back to 75 %")
	# What the sailor does is the ladder's top: the rig's extra lean of 100 %.
	var top: SimControls = SimControls.new()
	PushDial.apply_level(1.0, PushDial.default_curve(), null, top)
	assert_almost_eq(controls.rig_lean_extra_deg, top.rig_lean_extra_deg, 1e-6, "the rig leaned as at 100 %")
	assert_almost_eq(controls.trim_aim_extra_deg, top.trim_aim_extra_deg, 1e-6, "and the trim")
	body.hold_burst(false)
	_updates(controller, sim, controls, 30)
	assert_almost_eq(controller.push_now, 0.75, 1e-6, "let go: back to the level chosen")
	assert_false(controller.is_bursting())
	assert_eq(controller.burst_text(), "", "no note in the F1 panel")
	var chosen: SimControls = SimControls.new()
	PushDial.apply_level(0.75, PushDial.default_curve(), null, chosen)
	assert_almost_eq(controls.rig_lean_extra_deg, chosen.rig_lean_extra_deg, 1e-6, "the rig back as at 75 %")


func test_w_and_s_still_move_the_push_with_the_body_on_the_mouse() -> void:
	var controller: PlayerController = PlayerController.new()
	controller.push_level = 0.5
	var body: MouseBody = MouseBody.new()
	controller.body = body
	var controls: SimControls = SimControls.new()
	var sim: WindsurferSim = _player_on_the_water(controller, controls)
	_updates(controller, sim, controls, 1)
	Input.action_press("push_more")
	_updates(controller, sim, controls, 60)
	Input.action_release("push_more")
	assert_almost_eq(controller.push_level, 0.9, 1e-3, "W: 40 % a second, as without the body")
	assert_eq(controller.push_now, controller.push_level, "the keys alone: the sailor exactly at the level")
	Input.action_press("push_less")
	_updates(controller, sim, controls, 30)
	Input.action_release("push_less")
	assert_almost_eq(controller.push_level, 0.7, 1e-3, "S: 40 % a second down")
	assert_eq(controller.push_now, controller.push_level)
	# In a burst, W and S move the level the burst comes back to.
	body.hold_burst(true)
	Input.action_press("push_less")
	_updates(controller, sim, controls, 30)
	Input.action_release("push_less")
	assert_eq(controller.push_now, 1.0, "the burst holds the top")
	assert_almost_eq(controller.push_level, 0.5, 1e-3, "S moved the level it comes back to")
	# The keys and the wheel together.
	body.hold_burst(false)
	body.wheel(1.0)
	Input.action_press("push_more")
	_updates(controller, sim, controls, 15)
	Input.action_release("push_more")
	assert_almost_eq(controller.push_level, 0.7, 1e-3, "a notch (10 %) and a quarter of a second of W (10 %)")


func test_an_ai_skippers_push_is_its_hands_own() -> void:
	var controller: PlayerController = PlayerController.new()
	var hands: AiHands = AiHands.new()
	hands.push = 0.6
	controller.hands = hands
	var body: MouseBody = MouseBody.new()
	body.hold_burst(true)
	body.wheel(2.0)
	controller.body = body
	var controls: SimControls = SimControls.new()
	var sim: WindsurferSim = _player_on_the_water(controller, controls)
	_updates(controller, sim, controls, 3)
	assert_eq(controller.push_level, 0.6, "the hands set the level; no wheel")
	assert_eq(controller.push_now, 0.6, "and no burst")
	hands.push = 0.9
	_updates(controller, sim, controls, 1)
	assert_eq(controller.push_now, 0.9, "the hands' level at once, as before")


func test_without_a_body_the_push_is_the_keys_level() -> void:
	var controller: PlayerController = PlayerController.new()
	var controls: SimControls = SimControls.new()
	var sim: WindsurferSim = _player_on_the_water(controller, controls)
	_updates(controller, sim, controls, 1)
	assert_true(is_nan(controller.push_now), "no slider, no level")
	controller.push_level = 0.85
	_updates(controller, sim, controls, 1)
	assert_eq(controller.push_now, 0.85)
	Input.action_press("push_more")
	_updates(controller, sim, controls, 10)
	Input.action_release("push_more")
	assert_eq(controller.push_now, controller.push_level, "the keys: the level exactly")


# --- The settings, the sailing scene, the gauge, the keys -----------------------------------

func test_the_settings_default_to_the_wheel_and_the_button_and_are_clamped() -> void:
	var values: SettingsValues = SettingsValues.new()
	assert_eq(values.body_push_on_mouse, MouseBody.PushOnMouse.WHEEL_AND_BUTTON, "on whenever the body is")
	assert_eq(values.body_push_step, 0.1)
	values.body_push_on_mouse = MouseBody.PushOnMouse.WHEEL
	values.body_push_step = 0.2
	var file: ConfigFile = ConfigFile.new()
	values.write_to(file)
	var read: SettingsValues = SettingsValues.new()
	read.read_from(file)
	assert_eq(read.body_push_on_mouse, MouseBody.PushOnMouse.WHEEL)
	assert_almost_eq(read.body_push_step, 0.2, 1e-6)
	var body: MouseBody = MouseBody.new()
	body.hold_burst(true)
	body.configure(read)
	assert_eq(body.push_on_mouse, MouseBody.PushOnMouse.WHEEL, "the menu's choice reaches the body")
	assert_almost_eq(body.push_step, 0.2, 1e-6)
	assert_false(body.burst_held, "the button is no longer the push's: no burst left behind")
	file.set_value("body", "push_on_mouse", 9)
	file.set_value("body", "push_step", 3.0)
	read.read_from(file)
	assert_eq(read.body_push_on_mouse, MouseBody.PushOnMouse.size() - 1)
	assert_eq(read.body_push_step, SettingsValues.BODY_PUSH_STEP_MAX)
	# A settings file from before (the play folders' push_and_body.cfg) has no such keys: the defaults.
	var old: ConfigFile = ConfigFile.new()
	old.set_value("body", "mouse_body", true)
	var from_old: SettingsValues = SettingsValues.new()
	from_old.read_from(old)
	assert_eq(from_old.body_push_on_mouse, MouseBody.PushOnMouse.WHEEL_AND_BUTTON)


func test_the_sailing_scene_hands_the_wheel_and_the_left_button_to_the_push() -> void:
	var scene: SailingScene = (load("res://main.tscn") as PackedScene).instantiate()
	add_child_autofree(scene)
	var windsurfer: WindsurferNode = scene.get_node("Windsurfer")
	var wheel: InputEventMouseButton = InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	wheel.factor = 1.0
	assert_false(scene.push_with_the_mouse(wheel), "no body on the mouse: the wheel is the camera's")
	GameSettings.values.mouse_body = true
	scene.apply_settings_live()
	var body: MouseBody = windsurfer.controller.body
	assert_true(scene.push_with_the_mouse(wheel), "the body on: the wheel is the push's")
	assert_almost_eq(body.take_push_change(), 0.1, 1e-6, "a notch up")
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	wheel.factor = 0.5
	scene.push_with_the_mouse(wheel)
	assert_almost_eq(body.take_push_change(), -0.05, 1e-6, "half a notch down (a smooth wheel)")
	wheel.pressed = false
	assert_true(scene.push_with_the_mouse(wheel), "the wheel's release is taken too (the camera does not zoom)")
	assert_eq(body.take_push_change(), 0.0, "but counts nothing")
	var left: InputEventMouseButton = InputEventMouseButton.new()
	left.button_index = MOUSE_BUTTON_LEFT
	left.pressed = true
	assert_true(scene.push_with_the_mouse(left))
	assert_true(body.burst_held, "the left button held: the burst")
	left.pressed = false
	scene.push_with_the_mouse(left)
	assert_false(body.burst_held, "let go")
	# Looking around (the right button or C held): the wheel zooms the orbit camera.
	Input.action_press("camera_look")
	wheel.pressed = true
	assert_false(scene.push_with_the_mouse(wheel), "with the look key held the wheel is the camera's")
	Input.action_release("camera_look")
	# A headless run never captures the mouse: the scene lets go of a burst by itself (as in a menu).
	body.hold_burst(true)
	scene._update_mouse_capture()
	assert_false(body.burst_held, "the mouse not the body's: no burst")
	GameSettings.values.body_push_on_mouse = MouseBody.PushOnMouse.OFF
	scene.apply_settings_live()
	assert_false(scene.push_with_the_mouse(wheel), "Push on the mouse off: the wheel is the camera's again")
	assert_false(scene.push_with_the_mouse(left))


func test_the_gauge_shows_a_burst_and_the_level_it_comes_back_to() -> void:
	var gauge: PushGauge = autofree(PushGauge.new())
	gauge.set_level(0.75, 0.75)
	assert_false(gauge.is_burst(), "at the level chosen: no burst")
	gauge.set_level(1.0, 0.75)
	assert_true(gauge.is_burst())
	assert_eq(gauge.chosen, 0.75, "the marker at the level it comes back to")
	gauge.set_level(0.8)
	assert_false(gauge.is_burst(), "no level chosen given: the plain gauge")
	gauge.set_level(NAN, 0.5)
	assert_false(gauge.visible)


func test_the_keys_along_the_bottom_list_the_mouse() -> void:
	assert_eq(Hud.with_mouse_keys(Hud.FREE_KEYS, -1), Hud.FREE_KEYS, "no body: as before")
	var shown: Array[Array] = Hud.with_mouse_keys(Hud.FREE_KEYS, MouseBody.PushOnMouse.WHEEL_AND_BUTTON)
	assert_has(shown, ["W S  Wheel", "push"])
	assert_has(shown, ["Hold left", "burst"])
	assert_has(shown, ["Mouse", "body"])
	var wheel_only: Array[Array] = Hud.with_mouse_keys(Hud.RACE_KEYS, MouseBody.PushOnMouse.WHEEL)
	assert_has(wheel_only, ["W S  Wheel", "push"])
	assert_does_not_have(wheel_only, ["Hold left", "burst"])
	var off: Array[Array] = Hud.with_mouse_keys(Hud.FREE_KEYS, MouseBody.PushOnMouse.OFF)
	assert_has(off, ["W S", "push"])
	assert_has(off, ["Mouse", "body"])
	assert_eq(Hud.with_mouse_keys(Hud.SPECTATE_KEYS, MouseBody.PushOnMouse.WHEEL_AND_BUTTON), Hud.SPECTATE_KEYS, "spectating: no push")


func test_the_controls_page_and_the_body_tab_list_the_push_on_the_mouse() -> void:
	var texts: Array[String] = []
	for row: Array in ControlsPage.KEY_ROWS:
		texts.append(str(row[1]))
	var joined: String = " | ".join(texts)
	assert_string_contains(joined, "Mouse body: push in steps, burst to 100 %")
	var settings: SettingsMenu = (load("res://ui/settings_menu.tscn") as PackedScene).instantiate()
	add_child_autofree(settings)
	settings.show_tab("body")
	var grid: GridContainer = settings.get_node("%BodyRows")
	var names: Array[String] = []
	for child: Node in grid.get_children():
		if child is Label:
			names.append((child as Label).text)
	assert_has(names, "Push on the mouse")
	assert_has(names, "Wheel step")
