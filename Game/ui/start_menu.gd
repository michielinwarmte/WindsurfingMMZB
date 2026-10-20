extends Node
## The start menu, the game's main scene (project.godot). Behind it the sailing scene runs as
## a moving backdrop (main.tscn with start_in_menu: the autopilot sails, the camera circles).
## The four ways to play:
##   Sail on open water: the backdrop becomes the game (main.gd, start_playing()).
##   Sail on Lake Silvaplana: the real lake in a Maloja wind (maps/silvaplana/sail_silvaplana.tscn).
##   Silvaplana wind viewer, with the race course maker (the map track's wind viewer).
##   Lake Silvaplana: fly over the map (the map track's terrain view).
## And Settings, Controls, How to sail and Quit. The menu remembers the play option chosen
## last time and puts the focus on it.
##
## Keys: arrows (or the gamepad's stick/d-pad) move, Enter (or A) chooses, Esc (or B) goes
## back, and on the main page asks whether to quit.
## For screenshots (after "--"): --page=settings/<tab>|controls|howto|quit opens that page.

const SAIL_SILVAPLANA_SCENE: String = "res://maps/silvaplana/sail_silvaplana.tscn"
const FLY_OVER_SCENE: String = "res://maps/silvaplana/dev/terrain_view.tscn"
const WIND_VIEWER_SCENE: String = "res://maps/silvaplana/wind_viewer.tscn"

## The play options, as last_play_option in the settings saves them (new ones go at the end, so
## a saved choice keeps its meaning; the menu shows them in its own order).
enum PlayOption { OPEN_WATER, FLY_OVER, WIND_VIEWER, SAIL_SILVAPLANA, RACE_OPEN_WATER, RACE_LAKE }

@onready var _sailing: SailingScene = $Sailing
@onready var _menu: CanvasLayer = $Menu
@onready var _main_page: Control = %MainPage
@onready var _open_water_button: Button = %OpenWaterButton
@onready var _sail_silvaplana_button: Button = %SailSilvaplanaButton
@onready var _race_open_water_button: Button = %RaceOpenWaterButton
@onready var _race_lake_button: Button = %RaceLakeButton
@onready var _silvaplana_button: Button = %SilvaplanaButton
@onready var _wind_button: Button = %WindButton
@onready var _settings_button: Button = %SettingsButton
@onready var _controls_button: Button = %ControlsButton
@onready var _howto_button: Button = %HowToButton
@onready var _quit_button: Button = %QuitButton
@onready var _conditions: Label = %OpenWaterHint
@onready var _status: Label = %Status
@onready var _version: Label = %Version
@onready var _settings: SettingsMenu = %Settings
@onready var _controls: ControlsPage = %Controls
@onready var _howto: HowToPage = %HowTo
@onready var _quit_confirm: ConfirmDialog = %QuitConfirm


func _ready() -> void:
	_open_water_button.pressed.connect(_on_open_water_pressed)
	_sail_silvaplana_button.pressed.connect(_open_map_scene.bind(PlayOption.SAIL_SILVAPLANA, SAIL_SILVAPLANA_SCENE, "Lake Silvaplana"))
	_race_open_water_button.pressed.connect(_on_race_open_water_pressed)
	_race_lake_button.pressed.connect(_on_race_lake_pressed)
	_silvaplana_button.pressed.connect(_open_map_scene.bind(PlayOption.FLY_OVER, FLY_OVER_SCENE, "the map of Lake Silvaplana"))
	_wind_button.pressed.connect(_open_map_scene.bind(PlayOption.WIND_VIEWER, WIND_VIEWER_SCENE, "the wind viewer"))
	_settings_button.pressed.connect(_open_page.bind(_settings))
	_controls_button.pressed.connect(_open_page.bind(_controls))
	_howto_button.pressed.connect(_open_page.bind(_howto))
	_quit_button.pressed.connect(_open_page.bind(_quit_confirm))
	_quit_confirm.confirmed.connect(_on_quit_confirmed)
	for page: MenuPage in [_settings, _controls, _howto, _quit_confirm]:
		page.closed.connect(_on_page_closed.bind(page))
	MenuFocus.setup_buttons([_open_water_button, _sail_silvaplana_button, _race_open_water_button, _race_lake_button, _wind_button, _silvaplana_button,
		_settings_button, _controls_button, _howto_button, _quit_button])
	_version.text = _version_text()
	_show_main_page(_play_buttons()[GameSettings.values.last_play_option])
	_apply_command_line_options()
	if _run_bench_from_options():
		return
	_start_race_from_options()


func _unhandled_input(event: InputEvent) -> void:
	# Esc on the main page asks whether to quit (the pages handle their own Esc first).
	if _main_page.is_visible_in_tree() and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_open_page(_quit_confirm)


## The play buttons in the order of PlayOption.
func _play_buttons() -> Array[Button]:
	return [_open_water_button, _silvaplana_button, _wind_button, _sail_silvaplana_button, _race_open_water_button, _race_lake_button]


## Sail on open water: the menu goes away and the backdrop becomes the game.
func _on_open_water_pressed() -> void:
	_remember_choice(PlayOption.OPEN_WATER)
	set_process_unhandled_input(false)
	_menu.queue_free()
	_sailing.start_playing()


## Race on open water: the backdrop becomes a race on the T1 training loop against three AI
## skippers (RACING_PLAN.md, 9A and 9B).
func _on_race_open_water_pressed() -> void:
	_remember_choice(PlayOption.RACE_OPEN_WATER)
	set_process_unhandled_input(false)
	_menu.queue_free()
	_sailing.start_race(RaceSetup.race(RaceCourses.T1_NAME))


## Race on Lake Silvaplana: the sprint slalom T2 against three AI skippers; the lake scene takes
## the race from RaceSetup.pending when it starts.
func _on_race_lake_pressed() -> void:
	RaceSetup.pending = RaceSetup.race(RaceCourses.T2_NAME)
	_open_map_scene(PlayOption.RACE_LAKE, SAIL_SILVAPLANA_SCENE, "Lake Silvaplana")


## One of the map track's scenes. Loading the terrain takes a moment, so a line says so
## first; when it fails (the big map files come with Git LFS) the line says why.
func _open_map_scene(choice: PlayOption, path: String, title: String) -> void:
	_remember_choice(choice)
	_status.text = "Loading %s..." % title
	_status.show()
	# Two frames, so the line is on the screen before the loading holds everything up.
	await get_tree().process_frame
	await get_tree().process_frame
	var error: Error = get_tree().change_scene_to_file(path)
	if error != OK:
		_status.text = "Could not open %s (error %d). Its files come with Git LFS: see CLAUDE.md." % [title, error]


func _remember_choice(choice: PlayOption) -> void:
	GameSettings.values.last_play_option = choice
	GameSettings.save()


func _on_quit_confirmed() -> void:
	get_tree().quit()


func _open_page(page: MenuPage) -> void:
	_main_page.hide()
	page.open()


func _on_page_closed(page: MenuPage) -> void:
	if page == _settings:
		# The new wind and waves show behind the menu at once.
		_sailing.apply_settings_live()
	var buttons: Dictionary[MenuPage, Button] = {
		_settings: _settings_button, _controls: _controls_button, _howto: _howto_button, _quit_confirm: _quit_button}
	_show_main_page(buttons[page])


func _show_main_page(focus: Button) -> void:
	_conditions.text = "%s  ·  change it in Settings" % GameSettings.values.conditions_text()
	_main_page.show()
	focus.grab_focus()


## "v0.5  ·  Godot 4.7.2  ·  feature/ui @ 3d9a8d6" in the bottom right corner.
func _version_text() -> String:
	var version: String = str(ProjectSettings.get_setting("application/config/version", ""))
	var godot: Dictionary = Engine.get_version_info()
	var text: String = "v%s  ·  Godot %d.%d.%d" % [version, godot["major"], godot["minor"], godot["patch"]]
	var git: String = _git_description()
	if git != "":
		text += "  ·  " + git
	return text


## The git branch and commit when the game runs from the team's repository with the editor's
## Godot (tools/play.sh); empty in an exported game, which has no repository.
func _git_description() -> String:
	if not OS.has_feature("editor"):
		return ""
	var folder: String = ProjectSettings.globalize_path("res://")
	var output: Array = []
	if OS.execute("git", ["-C", folder, "rev-parse", "--abbrev-ref", "HEAD"], output) != 0 or output.is_empty():
		return ""
	var branch: String = str(output[0]).strip_edges()
	output.clear()
	if OS.execute("git", ["-C", folder, "rev-parse", "--short", "HEAD"], output) != 0 or output.is_empty():
		return branch
	return "%s @ %s" % [branch, str(output[0]).strip_edges()]


func _apply_command_line_options() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if not arg.begins_with("--page="):
			continue
		var parts: PackedStringArray = arg.trim_prefix("--page=").split("/")
		match parts[0]:
			"settings":
				_open_page(_settings)
				if parts.size() > 1:
					_settings.show_tab(parts[1])
			"controls":
				_open_page(_controls)
			"howto":
				_open_page(_howto)
			"quit":
				_open_page(_quit_confirm)


## --race=t1_loop|t2_slalom [--skippers=a,b,c] [--prestart=<s>] [--spawn=random|line]
## [--spawn_seed=<n>] [--free_sail=<s>] (RaceSetup.read_spawn_options()): the menu starts that race at once,
## for measuring and screenshots, and for exported builds, which take no scene on the command line.
func _start_race_from_options() -> void:
	var course: String = _race_option("race")
	if course.is_empty():
		return
	var who: PackedStringArray = RaceSetup.DEFAULT_SKIPPERS
	if not _race_option("skippers").is_empty():
		who = _race_option("skippers").split(",")
	var prestart: float = RaceSetup.DEFAULT_PRESTART_S
	if not _race_option("prestart").is_empty():
		prestart = _race_option("prestart").to_float()
	var setup: RaceSetup = RaceSetup.race(course, who, 1, prestart)
	setup.threads = RaceSetup.threads_from_option(_race_option("threads"))
	setup.read_spawn_options()
	if course == RaceCourses.T1_NAME:
		set_process_unhandled_input(false)
		_menu.queue_free()
		_sailing.start_race(setup)
	else:
		RaceSetup.pending = setup
		_open_map_scene(PlayOption.RACE_LAKE, SAIL_SILVAPLANA_SCENE, "Lake Silvaplana")


## --bench=thread [--threads=1,4,8,16] [--iterations=<n>] [--only=a,b]: runs the thread bench
## (Game/dev/thread_bench.gd) and quits; the way to run it on the release engine, which runs no
## script of its own. Returns true when it ran.
func _run_bench_from_options() -> bool:
	if _race_option("bench") != "thread":
		return false
	var options: Dictionary[String, String] = {}
	for name: String in ["threads", "iterations", "only"]:
		if not _race_option(name).is_empty():
			options[name] = _race_option(name)
	ThreadBench.new().run(options)
	get_tree().quit()
	return true


static func _race_option(option: String) -> String:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--%s=" % option):
			return arg.get_slice("=", 1)
	return ""
