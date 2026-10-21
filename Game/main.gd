class_name SailingScene
extends Node3D
## The sailing scene on open water: the windsurfer, the cameras, the HUD, the pause menu,
## and the keys that are not about sailing (pause, reset, camera, panels). The wind, the
## sea and the start come from the player's settings (GameSettings, ui/game_settings.gd).
##
## It runs on its own (tools/screenshot.sh res://main.tscn, or F6 in the editor), or behind
## the start menu (ui/start_menu.tscn sets start_in_menu): then the autopilot sails, a slow
## orbit camera circles the board, the HUD is hidden and the keys belong to the menu until
## the menu calls start_playing().
##
## Command line options for screenshots and demos (after "--"): --camera=1..4,
## --autopilot=1 (the test autopilot sails a beam reach), --hud=0 (no panel),
## --fall=<seconds> (the sailor is catapulted at that time), --pause=<seconds> (the pause
## menu opens at that time), --page=settings/<tab>|controls|howto (and that page of it).
## --settings=<file.cfg> or --settings=defaults: see ui/game_settings.gd.
## A race course on the water (RACING_PLAN.md, 9A): --course=<name> shows it (t1_loop on the open
## water, placed for the settings' wind; a map scene has its own, see _course_named()), starts the
## board 150 m behind its start line and puts it on the HUD and the mini-map; --lines=1 draws its
## start and finish lines on the water; --course_view=all puts a fixed camera above the whole
## course, --course_view=<mark> (1, 4S, start_boat, ...) one beside that mark (for screenshots).
## Watching a night's generations race (tools/gens.sh): --behind=<m> --wind=<kt> --blind=1
## --spectate=1 with the race (RaceSetup.read_options()); while spectating Tab and Shift+Tab pick
## the next or the previous board to watch and L follows the leader again (RaceRunner).
##
## A map scene sails with this script too (maps/silvaplana/sail_silvaplana.gd extends it): the
## map brings its own sun and sky (so Sun is optional), its own wind and start (it overrides
## _build_wind_config() and _start_heading_deg()), and a depth grid for the shore (shore_grid).

const START_MENU_SCENE: String = "res://ui/start_menu.tscn"
## How fast the camera circles the board behind the start menu, radians per second.
const MENU_ORBIT_RATE: float = 0.08
const AGROUND_TEXT: String = "Aground off the shore. R: back to the start"
const OFF_THE_MAP_TEXT: String = "The end of the map. R: back to the start"

## Set by the start menu: the scene is the menu's moving backdrop until start_playing().
@export var start_in_menu: bool = false

## A map's depth grid, for the shore (MAP_SILVAPLANA_PLAN.md, MD6); null on the open water.
## Set by the map scene's script (sail_silvaplana.gd) before the first physics tick.
var shore_grid: TerrainGrid = null

@onready var _windsurfer: WindsurferNode = $Windsurfer
@onready var _camera_rig: CameraRig = $CameraRig
@onready var _hud: Hud = $HUD
## The open water's sun; null in a map scene, which brings the map's own light.
@onready var _sun: DirectionalLight3D = get_node_or_null("Sun")
@onready var _ocean: OceanNode = $Ocean
@onready var _pause_menu: PauseMenu = $PauseMenu

var _in_menu: bool = false
var _fall_at_s: float = -1.0
var _pause_at_s: float = -1.0
var _pause_page: String = ""
## The sea the water was built for (SettingsValues.sea_signature()); when the settings say
## otherwise the water is built again at the next restart.
var _sea_signature: String = ""
## The control settings last applied, so closing the settings menu only changes what the
## player changed there (and not a mode they picked with Tab while sailing).
var _applied_mode: PlayerController.Mode = PlayerController.Mode.BEGINNER
var _applied_auto_sheet: bool = true
## The board ran into the shallows (or off the map) and waits for R (_check_shore()).
var _aground: bool = false
## The race course (--course=<name>), or null; and what shows it on the water.
var _course: Course = null
var _course_on_water: CourseOnWater = null
## The race asked for (the start menu's RaceSetup, or --skippers= on the command line), or null;
## and the node that runs it (RaceRunner).
var _race_setup: RaceSetup = null
var _race_runner: RaceRunner = null
## The sounds; they follow the board the camera follows.
var _audio: GameAudio = null


func _enter_tree() -> void:
	# The windsurfer builds its simulation in its _ready(), which runs before this node's:
	# hand it the wind, the sea and the start heading now.
	var windsurfer: WindsurferNode = $Windsurfer
	var settings: SettingsValues = GameSettings.values
	# With a course the board starts behind its start line (RaceCourses.pre_start_spot()), placed
	# from the scene's usual start spot (a map scene sets it before this runs). The race comes
	# first: it may bring its own wind (--wind).
	_course = _course_from_options(Vector2(windsurfer.start_position.x, windsurfer.start_position.z))
	windsurfer.wind_config = _build_wind_config()
	windsurfer.wave_set_config = settings.build_wave_set_config()
	if _course != null:
		var spot: Vector2 = RaceCourses.pre_start_spot(_course)
		windsurfer.start_position = Vector3(spot.x, 0.0, spot.y)
	windsurfer.start_heading_deg = _start_heading_deg()
	_sea_signature = settings.sea_signature()


func _ready() -> void:
	# This node, the cameras, the HUD and the menus keep running while the game is paused;
	# the windsurfer (the physics) stops.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_windsurfer.process_mode = Node.PROCESS_MODE_PAUSABLE
	# The Silvaplana map's sun (maps/silvaplana/silvaplana.tscn): mid-July, 15:00 summer time, in
	# the south-west (azimuth 225 degrees), 59 degrees up, so both scenes have the same light.
	# The lake scene has no sun of its own here (the map brings it), hence the null check.
	if _sun != null:
		_sun.rotation_degrees = Vector3(-59.0, -45.0, 0.0)
	_ocean.setup(_windsurfer.sim, _camera_rig.camera)
	_show_course()
	_start_race_runner()
	_apply_start_settings()
	_pause_menu.resume_requested.connect(_set_paused.bind(false))
	_pause_menu.restart_requested.connect(_on_restart_requested)
	_pause_menu.settings_closed.connect(apply_settings_live)
	_pause_menu.start_menu_requested.connect(_go_to_start_menu)
	if start_in_menu:
		_enter_menu_mode()
	_apply_command_line_options()
	# The sounds (audio/game_audio.gd): they follow the windsurfer's telemetry every frame.
	_audio = GameAudio.create(_windsurfer, _camera_rig, func() -> bool: return _in_menu)
	add_child(_audio)


func _unhandled_input(event: InputEvent) -> void:
	# Behind the start menu, and while paused, the menus have the keys.
	if _in_menu or get_tree().paused:
		return
	if event.is_action_pressed("pause"):
		_set_paused(true)
	elif _is_spectating() and event.is_action_pressed("toggle_mode"):
		# Tab: the next board in race order; Shift+Tab the previous one.
		var key: InputEventWithModifiers = event as InputEventWithModifiers
		_race_runner.step_followed(-1 if key != null and key.shift_pressed else 1)
	elif _is_spectating() and event is InputEventKey and event.is_pressed() and not event.is_echo() and (event as InputEventKey).physical_keycode == KEY_L:
		_race_runner.follow_leader()
	elif event.is_action_pressed("reset"):
		if _windsurfer.is_fallen() and not _aground:
			_windsurfer.waterstart_now()
		else:
			_restart_run()
	elif event.is_action_pressed("toggle_hud"):
		_hud.toggle_detail()
	elif event.is_action_pressed("camera_1"):
		_camera_rig.set_mode(CameraRig.Mode.FOLLOW)
	elif event.is_action_pressed("camera_2"):
		_camera_rig.set_mode(CameraRig.Mode.ORBIT)
	elif event.is_action_pressed("camera_3"):
		_camera_rig.set_mode(CameraRig.Mode.TOP_DOWN)
	elif event.is_action_pressed("camera_4"):
		_camera_rig.set_mode(CameraRig.Mode.FREE)


func _physics_process(_delta: float) -> void:
	_check_shore()


func _process(delta: float) -> void:
	if _in_menu:
		_camera_rig.orbit_azimuth_rad += MENU_ORBIT_RATE * delta
		return
	if _fall_at_s >= 0.0 and _windsurfer.sim.time_s >= _fall_at_s:
		_fall_at_s = -1.0
		_windsurfer.sim.force_fall("catapult")
	if _pause_at_s >= 0.0 and _windsurfer.sim.time_s >= _pause_at_s:
		_pause_at_s = -1.0
		_set_paused(true)
		if _pause_page != "":
			_pause_menu.open_page(_pause_page)
	# The board on the screen: the player's, or while spectating the AI board being watched.
	var shown: WindsurferNode = _race_runner.followed_node() if _race_runner != null else _windsurfer
	_camera_rig.set_target(shown)
	if _audio != null:
		_audio.follow(shown)
	_hud.update_from(shown.telemetry(), shown.controller, _camera_rig.mode_name(), shown.use_autopilot)
	if _race_runner != null:
		_hud.set_other_boards(_race_runner.other_positions())


## Whether a race is on with the player's board parked (--spectate=1).
func _is_spectating() -> bool:
	return _race_runner != null and _race_runner.spectating


## The start menu's "Sail on open water": the board goes back to the start and the player
## gets the keys, the HUD and the camera from the settings.
func start_playing() -> void:
	_in_menu = false
	_windsurfer.use_autopilot = false
	_camera_rig.camera.h_offset = 0.0
	_hud.visible = true
	_restart_run()
	_apply_start_settings()
	# A key still held from the menu (Space, Enter) must not count as a press in the game.
	for action: String in ["tack", "toggle_mode", "toggle_autosheet", "reset", "pause"]:
		Input.action_release(action)


## After the settings menu closes: the new wind blows at once (with its gusts and shifts),
## a changed control mode or auto-sheet applies at once, and new waves wait for the next
## restart (behind the start menu they come at once).
func apply_settings_live() -> void:
	var settings: SettingsValues = GameSettings.values
	_apply_wind_settings_live()
	if settings.control_mode != _applied_mode or settings.auto_sheet != _applied_auto_sheet:
		_apply_control_settings()
	if _sun != null:
		_sun.shadow_enabled = settings.shadow_quality > 0
	if _in_menu and settings.sea_signature() != _sea_signature:
		_restart_run()
	_pause_menu.set_note(_waiting_for_restart_text())


## What the player changed that only a restart brings (empty when nothing).
func _waiting_for_restart_text() -> String:
	var settings: SettingsValues = GameSettings.values
	var waiting: Array[String] = []
	if settings.sea_signature() != _sea_signature:
		waiting.append("the new waves")
	if not is_equal_approx(_start_heading_deg(), _windsurfer.start_heading_deg):
		waiting.append("the new start heading")
	if waiting.is_empty():
		return ""
	return "Restart (R) to sail with %s." % " and ".join(waiting)


## Puts the board back at the start; builds the water again first if the waves changed.
func _restart_run() -> void:
	var settings: SettingsValues = GameSettings.values
	_windsurfer.start_heading_deg = _start_heading_deg()
	if settings.sea_signature() != _sea_signature:
		_rebuild_sea()
	_windsurfer.reset()
	if _race_runner != null:
		_race_runner.restart()
	_set_aground(false)
	_pause_menu.set_note("")


## A new wind and wave set from the settings, for the physics and for the water you see.
func _rebuild_sea() -> void:
	var settings: SettingsValues = GameSettings.values
	_windsurfer.set_sea(_build_wind_config(), settings.build_wave_set_config())
	_sea_signature = settings.sea_signature()
	# OceanNode.setup() adds new water meshes, so the old ones go first. (They are plain
	# meshes without scripts, so they can be freed at once.)
	for child: Node in _ocean.get_children():
		child.free()
	_ocean.setup(_windsurfer.sim, _camera_rig.camera)
	_put_course_lines_on_the_waves()


## The settings that set up a run: the controls, the camera, the HUD panel, the shadows.
func _apply_start_settings() -> void:
	var settings: SettingsValues = GameSettings.values
	_apply_control_settings()
	_camera_rig.set_mode(settings.start_camera)
	# In a race the racing block takes the panel's place (F1 brings the panel back).
	_hud.set_detail_visible(settings.show_hud_panel and _race_runner == null)
	if _sun != null:
		_sun.shadow_enabled = settings.shadow_quality > 0


## The wind the board sails in: the settings' wind, or a race's own (--wind: a steady wind of that
## strength from the settings' direction, no gusts or shifts, as the brains were trained). A map
## scene has its own (sail_silvaplana.gd).
func _build_wind_config() -> WindConfig:
	var config: WindConfig = GameSettings.values.build_wind_config()
	if _race_setup != null and _race_setup.wind_kt > 0.0:
		config.speed_kt = _race_setup.wind_kt
		config.gusts_enabled = false
		config.shifts_enabled = false
	return config


## The start heading: the settings' one, or with a course a beam reach behind its start line
## (RaceCourses.pre_start_heading_deg()). A map scene has its own (sail_silvaplana.gd).
func _start_heading_deg() -> float:
	if _course != null:
		return RaceCourses.pre_start_heading_deg(_course)
	return GameSettings.values.start_heading_deg


## The settings' wind blows at once, with its gusts and shifts. A map scene keeps its own wind.
func _apply_wind_settings_live() -> void:
	if _race_setup != null and _race_setup.wind_kt > 0.0:
		return  # the race's own wind (--wind) stays
	var settings: SettingsValues = GameSettings.values
	var wind: WindField = _windsurfer.sim.wind
	settings.apply_wind_to(wind.config)
	wind.set_wind(deg_to_rad(settings.wind_from_deg), settings.wind_speed_kt * SimMath.KNOT_MS)


## The shore on a map (MD6): where the water under the board is shallower than the fin plus a
## margin, or off the map, the board has run aground. The simulation stops and R takes the board
## back to the start. No collision physics: nothing pushes on the board (rule 2).
func _check_shore() -> void:
	if shore_grid == null or _aground or _in_menu:
		return
	var at: Vector3 = _windsurfer.sim.body.origin_world()
	if not ShoreCheck.is_aground(shore_grid, at, _windsurfer.sim.fin_config.span_m):
		return
	_set_aground(true)
	_hud.set_message(AGROUND_TEXT if shore_grid.contains(at.x, at.z) else OFF_THE_MAP_TEXT)


## Stops the board (the simulation no longer steps), or lets it sail again.
func _set_aground(aground: bool) -> void:
	_aground = aground
	_windsurfer.set_physics_process(not aground)
	if not aground:
		_hud.set_message("")


func is_aground() -> bool:
	return _aground


func _apply_control_settings() -> void:
	var settings: SettingsValues = GameSettings.values
	# set_mode() also sets the auto-sheet to the mode's default, so the setting comes after.
	_windsurfer.controller.set_mode(settings.control_mode)
	_windsurfer.controller.auto_sheet = settings.auto_sheet
	_applied_mode = settings.control_mode
	_applied_auto_sheet = settings.auto_sheet


## Behind the start menu: the autopilot sails, the camera circles, no HUD.
func _enter_menu_mode() -> void:
	_in_menu = true
	_windsurfer.use_autopilot = true
	_hud.visible = false
	_camera_rig.set_mode(CameraRig.Mode.ORBIT)
	_camera_rig.orbit_distance_m = 12.0
	_camera_rig.orbit_elevation_rad = 0.22
	# Shift the picture so the board sails to the right of the menu, not behind it.
	_camera_rig.camera.h_offset = -2.6


func _set_paused(paused: bool) -> void:
	get_tree().paused = paused
	if paused:
		_pause_menu.open(_waiting_for_restart_text())
	else:
		_pause_menu.close()


func _on_restart_requested() -> void:
	_restart_run()
	_set_paused(false)


func _go_to_start_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(START_MENU_SCENE)


func _apply_command_line_options() -> void:
	var options: Dictionary[String, String] = {}
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--") and arg.contains("="):
			var parts: PackedStringArray = arg.trim_prefix("--").split("=", true, 1)
			options[parts[0]] = parts[1]
	if _in_menu:
		return
	if options.has("camera"):
		var index: int = clampi(options["camera"].to_int() - 1, 0, 3)
		_camera_rig.set_mode(index as CameraRig.Mode)
	if options.get("autopilot", "0") == "1":
		_windsurfer.use_autopilot = true
	if options.get("hud", "1") == "0":
		_hud.set_detail_visible(false)
	if options.has("fall"):
		_fall_at_s = options["fall"].to_float()
	if options.has("pause"):
		_pause_at_s = options["pause"].to_float()
		_pause_page = options.get("page", "")
	if _course_on_water != null:
		_course_on_water.set_lines_visible(options.get("lines", "0") == "1")
		if options.has("course_view"):
			_look_at_the_course(options["course_view"])
	if options.has("measure"):
		_measure_frame_rate(options["measure"].to_float())


# ---------------------------------------------------------------- the race course (RACING_PLAN.md, 9A)

## The course asked for with --course=<name>, placed for this scene; null without the option, or
## when there is no such course (it says so).
func _course_from_options(usual_start: Vector2) -> Course:
	# The start menu's race first; else the command line's course, raced when it names skippers.
	_race_setup = RaceSetup.take()
	var course_name: String = _race_setup.course_name if _race_setup != null else _user_option("course")
	if course_name.is_empty():
		return null
	if _race_setup == null and not _user_option("skippers").is_empty():
		var prestart: String = _user_option("prestart")
		_race_setup = RaceSetup.race(course_name, _user_option("skippers").split(","), maxi(_user_option("laps").to_int(), 1),
			prestart.to_float() if not prestart.is_empty() else RaceSetup.DEFAULT_PRESTART_S)
		_race_setup.opponent_effects = _user_option("opponent_effects") == "1"
		_race_setup.threads = RaceSetup.threads_from_option(_user_option("threads"))
		_race_setup.read_options()
	var found: Course = _course_named(course_name, usual_start)
	if found == null:
		push_warning("No course called \"%s\" in this scene. The open water has %s; Lake Silvaplana has %s and the courses saved in %s." % [
			course_name, RaceCourses.T1_NAME, RaceCourses.T2_NAME, RaceCourses.SAVED_FOLDER])
	return found


## A course by name for this scene. The open water knows T1, placed for the settings' wind with the
## middle of its start line 150 m upwind of the usual start, so the board starts that far behind it;
## and courses saved in game metres. A map scene knows its own (sail_silvaplana.gd).
func _course_named(course_name: String, usual_start: Vector2) -> Course:
	if course_name == RaceCourses.T1_NAME:
		var wind_from_deg: float = GameSettings.values.wind_from_deg
		var start_middle: Vector2 = usual_start + Course.direction_of(wind_from_deg) * RaceCourses.PRE_START_BEHIND_M
		return RaceCourses.t1_loop(wind_from_deg, start_middle)
	return RaceCourses.load_named(course_name, null)


## The course on the water, and its name and marks on the HUD.
func _show_course() -> void:
	if _course == null:
		return
	_course_on_water = CourseOnWater.new()
	_course_on_water.name = "CourseOnWater"
	add_child(_course_on_water)
	_course_on_water.build(_course, _water_height_at, _water_clock, _true_wind_at)
	_put_course_lines_on_the_waves()
	_hud.show_course(_course)


## The lines on the water ride the same waves as the water (again after new water is built).
func _put_course_lines_on_the_waves() -> void:
	if _course_on_water == null:
		return
	var parameters: Dictionary[String, Variant] = {}
	var field: WaveField = _windsurfer.sim.water as WaveField
	if field != null:
		parameters = field.shader_parameters()
	_course_on_water.set_wave_parameters(parameters, _windsurfer.sim.water_config.base_height_m)


## The height of the water you see, for the course's buoys: the simulation's water, asked each
## time because new waves bring new water (_rebuild_sea()).
func _water_height_at(x: float, z: float, time_s: float) -> float:
	return _windsurfer.sim.water.height_at(x, z, time_s)


func _water_clock() -> float:
	return _windsurfer.sim.time_s


## The true wind for the boats' flags: the wind over the whole water at a height, as the flag at
## the start shows it (windsurfer/effects.gd). Not WindField.velocity_at(): on a map that asks the
## map's wind, which remembers the last spot it was asked for the simulation, and asking it here
## would change what the simulation gets (rule 2).
func _true_wind_at(at: Vector3) -> Vector3:
	var wind: WindField = _windsurfer.sim.wind
	return -wind.from_direction() * wind.speed_at_height(at.y)


## --course_view: a fixed camera for screenshots. "all": straight above the whole course, north up,
## high enough to see all of it. "start": up high behind the start line, on the side where the
## board waits, looking across the line at the course. A mark's name (start_boat for "start
## boat"): beside that mark, across the wind, so its flag is seen side on (a boat a little from
## behind, to see its deck).
func _look_at_the_course(view: String) -> void:
	var camera: Camera3D = _camera_rig.camera
	var across: Vector2 = Course.direction_of(_course.axis_deg + 90.0)
	var downwind: Vector2 = -Course.direction_of(_course.axis_deg)
	if view == "all":
		var box: Rect2 = _course.bounds().grow(80.0)
		var window: Vector2 = get_viewport().get_visible_rect().size
		# The camera's fov is from the top of the picture to the bottom; across it sees more.
		var half_view: float = tan(deg_to_rad(camera.fov * 0.5))
		var height_m: float = maxf(box.size.y, box.size.x * window.y / window.x) * 0.5 / half_view
		var centre: Vector2 = box.get_center()
		camera.global_transform = Transform3D(Basis.looking_at(Vector3.DOWN, Vector3.FORWARD), Vector3(centre.x, height_m, centre.y))
	elif view == "start":
		var middle: Vector2 = _course.start_middle()
		var behind: Vector2 = (RaceCourses.pre_start_spot(_course) - middle).normalized()
		var eye: Vector2 = middle + behind * 50.0
		camera.global_position = Vector3(eye.x, 18.0, eye.y)
		camera.look_at(Vector3(middle.x, 0.0, middle.y) - Vector3(behind.x, 0.0, behind.y) * 40.0, Vector3.UP)
	else:
		var mark: CourseMark = _course.mark(view.replace("_", " "))
		if mark == null:
			push_warning("--course_view: the course has no mark called \"%s\"." % view)
			return
		var eye: Vector2 = mark.position + across * 9.0
		var eye_height_m: float = 2.5
		if mark.is_boat():
			eye = mark.position + across * 14.0 + downwind * 9.0
			eye_height_m = 5.0
		camera.global_position = Vector3(eye.x, eye_height_m, eye.y)
		camera.look_at(Vector3(mark.position.x, 1.0, mark.position.y), Vector3.UP)
	_camera_rig.set_process(false)


## The value of a command line option --name=value after "--" ("" when it is not given).
static func _user_option(option: String) -> String:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--%s=" % option):
			return arg.get_slice("=", 1)
	return ""


# ---------------------------------------------------------------- the race (RACING_PLAN.md, 9A and 9B)

## The start menu's race on open water: the course goes on the water, the board behind its start
## line, the opponents beside it, and the player gets the keys (start_playing()).
func start_race(setup: RaceSetup) -> void:
	_race_setup = setup
	var usual: Vector2 = Vector2(_windsurfer.start_position.x, _windsurfer.start_position.z)
	_course = _course_named(setup.course_name, usual)
	if _course == null:
		push_warning("No course called \"%s\": sailing without a race." % setup.course_name)
		_race_setup = null
		start_playing()
		return
	var spot: Vector2 = RaceCourses.pre_start_spot(_course)
	_windsurfer.start_position = Vector3(spot.x, 0.0, spot.y)
	if setup.wind_kt > 0.0:
		# The race's own wind (--wind); the opponents take the player's.
		_windsurfer.set_sea(_build_wind_config(), null)
	_show_course()
	start_playing()
	_start_race_runner()
	# The command-line options (--measure, --camera, ...) apply to the race, not to the menu's backdrop.
	_apply_command_line_options()


## The race (RaceRunner), when one is asked for and its course is on the water.
func _start_race_runner() -> void:
	if _race_setup == null or _course == null or _race_runner != null:
		return
	_race_runner = RaceRunner.new()
	_race_runner.name = "RaceRunner"
	add_child(_race_runner)
	_race_runner.setup_race(_course, _windsurfer, _race_setup, _hud)


## --measure=<seconds>: the frame rate without vsync, the frame on average and at worst, and how
## much of a frame the physics and the rest take, over that many seconds after a warm-up; then
## quits. For finding frame drops (a race with four boards, Session 51).
func _measure_frame_rate(seconds: float) -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	for i: int in 180:
		await get_tree().process_frame
	var frames: int = 0
	var worst_ms: float = 0.0
	var physics_ms: float = 0.0
	var process_ms: float = 0.0
	_windsurfer.cost_text()  # the warm-up's numbers are dropped
	if _race_runner != null:
		_race_runner.cost_text()
		_race_runner.opponents_cost_text()
	var start_us: int = Time.get_ticks_usec()
	var last_us: int = start_us
	while (Time.get_ticks_usec() - start_us) / 1e6 < seconds:
		await get_tree().process_frame
		var now_us: int = Time.get_ticks_usec()
		worst_ms = maxf(worst_ms, (now_us - last_us) / 1000.0)
		last_us = now_us
		physics_ms += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
		process_ms += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
		frames += 1
	var total_s: float = (Time.get_ticks_usec() - start_us) / 1e6
	var boards: int = 1 + (_race_runner.opponents.size() if _race_runner != null else 0)
	print("Measured %.0f s with %d boards: %.0f fps; a frame %.1f ms on average, %.1f ms at worst; physics %.1f ms and the rest %.1f ms of a frame" % [
		total_s, boards, frames / total_s, 1000.0 * total_s / frames, worst_ms, physics_ms / frames, process_ms / frames])
	print("  the player's board: %s" % _windsurfer.cost_text())
	if _race_runner != null and not _race_runner.opponents.is_empty():
		# One line for the whole fleet, not one per board.
		print("  the AI boards: %s" % _race_runner.opponents_cost_text())
	if _race_runner != null:
		print("  the race runner: %s" % _race_runner.cost_text())
	get_tree().quit()
