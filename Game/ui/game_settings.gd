extends Node
## The player's settings for the whole game. An autoload: any script reaches it as
## GameSettings (registered in project.godot). It loads user://settings.cfg when the game
## starts, applies the graphics and the sound, and saves the file when a settings menu
## closes. The values themselves, their defaults and how they become the physics' config
## resources are in SettingsValues (settings_values.gd), which the unit tests check.
##
## Options after "--" on the command line:
##   --settings=<file.cfg>   read (and save) this file instead of user://settings.cfg
##   --settings=defaults     ignore the file and use the defaults; nothing is saved
## A screenshot run (tools/screenshot.sh) uses the defaults unless --settings is given, so
## screenshots do not depend on what the team last chose in the menu, and it never changes
## the window mode, vsync or the frame-rate cap.

## Sent after a setting changed (the menus and the sailing scene listen).
signal changed

const DEFAULT_PATH: String = "user://settings.cfg"

## The settings in use. Change them, then call notify_changed() (and save() when done).
var values: SettingsValues = SettingsValues.new()
## Where the settings are saved; empty = never saved (--settings=defaults).
var path: String = DEFAULT_PATH

var _screenshot_run: bool = false
## The graphics settings as last applied to the picture (apply_display()), so a change of
## the wind or the waves does not set the picture again.
var _applied_display: String = ""
## Whether the window was maximized when Fullscreen was switched on, so switching it off restores it.
var _maximized_before_fullscreen: bool = false


# The file is read as soon as this autoload is made, before any scene: the first scene's
# nodes enter the tree (and the sailing scene reads the wind and the waves) before the
# autoloads' _ready() runs.
func _init() -> void:
	var options: Dictionary[String, String] = _read_user_args()
	_screenshot_run = options.has("screenshot")
	path = DEFAULT_PATH
	if options.has("settings"):
		path = "" if options["settings"] == "defaults" else options["settings"]
	elif _screenshot_run:
		path = ""
	if path != "":
		values.load_file(path)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	apply_display()


## Saves the settings to the file (unless running on the defaults).
func save() -> void:
	if path == "":
		return
	var error: Error = values.save_file(path)
	if error != OK:
		push_warning("Could not save the settings to %s (error %d)." % [path, error])


## Tells everyone listening that a setting changed and applies the graphics and the sound.
func notify_changed() -> void:
	apply_display()
	changed.emit()


## Puts every setting back to its default.
func reset_to_defaults() -> void:
	values.reset_to_defaults()
	notify_changed()


## Applies the graphics and the sound settings to the running game. In headless runs (the
## tests) there is no window or picture, so only the sound is set. The picture is only set
## when a graphics setting changed: every slider of the menu (the wind, the waves) comes
## through here, and setting the shadow atlas, the scaling and the window again at each
## step made the menu stutter (Session 67).
func apply_display() -> void:
	_apply_audio()
	if DisplayServer.get_name() == "headless":
		return
	var wanted: String = "%d/%.2f/%d/%s/%s/%d" % [values.msaa, values.render_scale, values.shadow_quality, values.fullscreen, values.vsync, values.max_fps]
	if wanted == _applied_display:
		return
	_applied_display = wanted
	var root: Window = get_tree().root
	# Anti-aliasing smooths the jagged edges of the 3D picture (0 off to 3 = 8x).
	root.msaa_3d = values.msaa as Viewport.MSAA
	# Below 1 the 3D picture is drawn smaller and stretched to the window: faster, softer.
	root.scaling_3d_scale = values.render_scale
	_apply_shadow_quality()
	if _screenshot_run:
		return
	var mode: DisplayServer.WindowMode = window_mode_to_set(DisplayServer.window_get_mode(), values.fullscreen, _maximized_before_fullscreen)
	if mode != DisplayServer.window_get_mode():
		if mode == DisplayServer.WINDOW_MODE_FULLSCREEN:
			_maximized_before_fullscreen = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_MAXIMIZED
		DisplayServer.window_set_mode(mode)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if values.vsync else DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = values.max_fps


## The window mode the Fullscreen setting asks for, given the window's mode now. A maximized (or
## minimized) window is a window too: setting WINDOWED on it made it small again whenever a graphics
## setting changed (Max, 3 November 2026). Out of fullscreen the window goes back to maximized if it
## was before.
static func window_mode_to_set(current: DisplayServer.WindowMode, fullscreen: bool, was_maximized: bool) -> DisplayServer.WindowMode:
	var is_fullscreen: bool = current == DisplayServer.WINDOW_MODE_FULLSCREEN or current == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	if fullscreen == is_fullscreen:
		return current
	if fullscreen:
		return DisplayServer.WINDOW_MODE_FULLSCREEN
	return DisplayServer.WINDOW_MODE_MAXIMIZED if was_maximized else DisplayServer.WINDOW_MODE_WINDOWED


## The sun's shadow map: bigger is sharper and slower; the filter softens the edges.
## "Off" is applied by each scene to its own sun (main.gd), since a scene owns its light.
func _apply_shadow_quality() -> void:
	match values.shadow_quality:
		1:
			RenderingServer.directional_shadow_atlas_set_size(2048, true)
			RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_HARD)
		3:
			RenderingServer.directional_shadow_atlas_set_size(8192, true)
			RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_HIGH)
		_:
			# Medium (and Off) keep Godot's own defaults.
			RenderingServer.directional_shadow_atlas_set_size(4096, true)
			RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_LOW)


## The master volume on the Master bus (bus 0). There is no sound yet (plan, Phase 8), but
## everything that plays later goes through this bus.
func _apply_audio() -> void:
	var master_bus: int = 0
	AudioServer.set_bus_mute(master_bus, values.master_volume <= 0.001)
	AudioServer.set_bus_volume_db(master_bus, linear_to_db(maxf(values.master_volume, 0.001)))


## Turns arguments like --settings=defaults into {"settings": "defaults"}.
func _read_user_args() -> Dictionary[String, String]:
	var options: Dictionary[String, String] = {}
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--") and arg.contains("="):
			var parts: PackedStringArray = arg.trim_prefix("--").split("=", true, 1)
			options[parts[0]] = parts[1]
	return options
