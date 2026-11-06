extends GutTest
## The push slider comes back after hands held the player's board for a while (Max, 6 November
## 2026, LAN play-test: "host and joined player after changing things in racedirector or gear menu
## push slider is gone"). A network game's menu (Esc, and Change gear from it) gives the board still
## hands, and the race director's view (M) an all-rounder's; hands that say nothing about the push let
## go of the slider (PlayerController._release_the_slider() sets it to NaN), and nothing put the
## player's level back when the hands went: the gauge stayed hidden and W, S and the wheel did nothing.

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
	GameSettings.values = _saved_values
	GameSettings.path = _saved_path


## The player's controller on a board on the water, one step in (as test_push_on_mouse.gd).
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


func test_the_players_level_comes_back_when_still_hands_let_go() -> void:
	var controller: PlayerController = PlayerController.new()
	var controls: SimControls = SimControls.new()
	var sim: WindsurferSim = _player_on_the_water(controller, controls)
	controller.push_level = 0.85
	_updates(controller, sim, controls, 2)
	# A network game's menu: still hands that say nothing about the push.
	controller.hands = AiHands.new()
	_updates(controller, sim, controls, 5)
	assert_true(is_nan(controller.push_level), "hands that say nothing still let go of the slider (the AI's way)")
	controller.hands = null
	_updates(controller, sim, controls, 1)
	assert_almost_eq(controller.push_level, 0.85, 1e-9, "the player's own level back on the slider")
	assert_almost_eq(controller.push_now, 0.85, 1e-9, "and the sailor at it at once")
	Input.action_press("push_more")
	_updates(controller, sim, controls, 15)
	Input.action_release("push_more")
	assert_gt(controller.push_level, 0.85, "W moves the slider again")


func test_the_players_level_comes_back_after_a_skipper_pushed() -> void:
	var controller: PlayerController = PlayerController.new()
	var controls: SimControls = SimControls.new()
	var sim: WindsurferSim = _player_on_the_water(controller, controls)
	controller.push_level = 0.6
	_updates(controller, sim, controls, 1)
	# The race director's autopilot: a skipper whose hands push at its own level.
	var hands: AiHands = AiHands.new()
	hands.push = 0.95
	controller.hands = hands
	_updates(controller, sim, controls, 3)
	assert_almost_eq(controller.push_level, 0.95, 1e-9, "the skipper's level while it sails")
	controller.hands = null
	_updates(controller, sim, controls, 1)
	assert_almost_eq(controller.push_level, 0.6, 1e-9, "the player's own level, not the skipper's")


func test_an_ai_board_without_a_slider_stays_without_one() -> void:
	var controller: PlayerController = PlayerController.new()
	var controls: SimControls = SimControls.new()
	var sim: WindsurferSim = _player_on_the_water(controller, controls)
	var hands: AiHands = AiHands.new()
	hands.push = 0.9
	controller.hands = hands
	_updates(controller, sim, controls, 2)
	controller.hands = null
	_updates(controller, sim, controls, 1)
	assert_true(is_nan(controller.push_level), "a board that never had a level of its own gets none")


## The sailing scene's network-game menu (main.gd _set_net_menu_open(), the menu of the host and the
## guest alike): the gauge, the level and the body gauge are there again once the menu closes.
func test_the_gauge_comes_back_after_a_network_games_menu() -> void:
	GameSettings.values.mouse_body = true
	var scene: SailingScene = (load("res://main.tscn") as PackedScene).instantiate()
	add_child_autofree(scene)
	var windsurfer: WindsurferNode = scene.get_node("Windsurfer")
	var hud: Hud = scene.get_node("HUD")
	await wait_physics_frames(3)
	await wait_process_frames(2)
	windsurfer.controller.push_level = 0.8
	await wait_process_frames(2)
	assert_true(_push_gauge_of(hud).visible, "the gauge is up while sailing")
	scene._set_net_menu_open(true)
	await wait_physics_frames(10)
	scene._set_net_menu_open(false)
	await wait_physics_frames(3)
	await wait_process_frames(2)
	assert_almost_eq(windsurfer.controller.push_level, 0.8, 1e-6, "the level the player had before the menu")
	assert_true(_push_gauge_of(hud).visible, "the push gauge is back")
	assert_true(_body_gauge_of(hud).visible, "and the body gauge beside it")
	assert_not_null(windsurfer.controller.body, "the body is still on the mouse")


## The race director's view (M in a race): an all-rounder races the board while it is open; closed,
## the player's own level, the gauges and the body are back.
func test_the_gauge_comes_back_after_the_race_directors_view() -> void:
	GameSettings.values.mouse_body = true
	RaceSetup.pending = RaceSetup.race("t1_loop", PackedStringArray(["allrounder"]))
	var scene: SailingScene = (load("res://main.tscn") as PackedScene).instantiate()
	add_child_autofree(scene)
	var windsurfer: WindsurferNode = scene.get_node("Windsurfer")
	var hud: Hud = scene.get_node("HUD")
	await wait_physics_frames(3)
	windsurfer.controller.push_level = 0.7
	await wait_process_frames(2)
	assert_true(_push_gauge_of(hud).visible, "the gauge is up in the race")
	scene.open_race_director()
	await wait_physics_frames(20)
	assert_not_null(windsurfer.controller.hands, "the all-rounder's hands sail the board meanwhile")
	scene.close_race_director()
	await wait_physics_frames(3)
	await wait_process_frames(2)
	assert_null(windsurfer.controller.hands, "the board is the player's again")
	assert_almost_eq(windsurfer.controller.push_level, 0.7, 1e-6, "the level the player had before the view")
	assert_true(hud.visible, "the HUD is back")
	assert_true(_push_gauge_of(hud).visible, "the push gauge is back")
	assert_true(_body_gauge_of(hud).visible, "and the body gauge beside it")


func _push_gauge_of(hud: Hud) -> PushGauge:
	return hud.get("_push_gauge") as PushGauge


func _body_gauge_of(hud: Hud) -> BodyGauge:
	return hud.get("_body_gauge") as BodyGauge
