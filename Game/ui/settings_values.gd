class_name SettingsValues
extends RefCounted
## Everything the player can change in the settings menu, with its default, its range, how
## it is saved to a file (ConfigFile) and how it becomes the physics' own config resources
## (a WindConfig and a WaveSetConfig). Plain data with no nodes, so the unit tests can check
## it (tests/unit/test_game_settings.gd). The autoload GameSettings (game_settings.gd) holds
## the one copy the game uses.
##
## The wind and the waves start from the default config files (res://config/wind_default.tres
## and waves_default.tres) and only change the numbers the menu offers; those files are
## never written to (the tests and the validation suite load them).

## The sea states the menu offers. Flat is water without waves; Swell is the default wave
## set; the two chops are the sets used in the physics sessions (PROGRESS_LOG.md, Session 37).
enum WavePreset { FLAT, SWELL, MEDIUM_CHOP, STRONG_CHOP }

const WIND_DEFAULT_PATH: String = "res://config/wind_default.tres"
const WAVES_DEFAULT_PATH: String = "res://config/waves_default.tres"

## The chop presets change waves 2, 3 and 4 of the default set (the 7 m long chop, the 3.5 m
## chop and the 1.8 m ripple); wave 1, the 14 m swell, stays. Each steepness is the physical
## one for that wave (2 pi x amplitude / wavelength), as in the matrix runs of Session 37.
const MEDIUM_CHOP_AMPLITUDES_M: Array[float] = [0.04, 0.015, 0.006]
const MEDIUM_CHOP_STEEPNESS: Array[float] = [0.036, 0.027, 0.021]
const STRONG_CHOP_AMPLITUDES_M: Array[float] = [0.06, 0.03, 0.012]
const STRONG_CHOP_STEEPNESS: Array[float] = [0.054, 0.054, 0.042]

## The ranges the menu's sliders allow (a hand-edited file is clamped to them too).
const WIND_SPEED_MIN_KT: float = 4.0
const WIND_SPEED_MAX_KT: float = 35.0
const GUST_INTENSITY_MIN: float = 0.05
const GUST_INTENSITY_MAX: float = 0.5
const GUST_PERIOD_MIN_S: float = 3.0
const GUST_PERIOD_MAX_S: float = 30.0
const SHIFT_MIN_DEG: float = 2.0
const SHIFT_MAX_DEG: float = 45.0
const SHIFT_PERIOD_MIN_S: float = 15.0
const SHIFT_PERIOD_MAX_S: float = 300.0
const WAVE_SCALE_MIN: float = 0.5
const WAVE_SCALE_MAX: float = 2.0
const RENDER_SCALE_MIN: float = 0.5
const RENDER_SCALE_MAX: float = 1.0
## Frame-rate caps the menu offers; 0 means no cap.
const FPS_CAPS: Array[int] = [0, 30, 60, 120, 144]

# --- Wind (section "wind" in the file) ---
## Wind speed at 10 m height, knots (what a forecast says).
var wind_speed_kt: float
## Compass bearing the wind comes FROM, degrees: 0 = North, 90 = East, 270 = West.
var wind_from_deg: float
var gusts_enabled: bool
## Gust strength as a fraction of the wind speed (0.2 = up to about 20 % stronger and weaker).
var gust_intensity: float
var gust_period_s: float
var shifts_enabled: bool
## The largest swing of the wind direction, degrees either way.
var max_shift_deg: float
var shift_period_s: float

# --- Waves (section "waves") ---
var waves_enabled: bool
var wave_preset: WavePreset
## Multiplies the height (and with it the steepness) of every wave of the preset.
var wave_height_scale: float

# --- Sailing (section "sailing") ---
var control_mode: PlayerController.Mode
var auto_sheet: bool
## Compass heading of the board at the start, degrees (180 = South: a beam reach in a West wind).
var start_heading_deg: float
var start_camera: CameraRig.Mode
## The HUD's detail panel (F1) is shown when a run starts.
var show_hud_panel: bool

# --- Graphics (section "graphics") ---
var fullscreen: bool
var vsync: bool
## Anti-aliasing: 0 off, 1 = 2x, 2 = 4x, 3 = 8x (the values of Viewport.MSAA).
var msaa: int
## The 3D picture is drawn at this fraction of the window's resolution (faster below 1).
var render_scale: float
## Sun shadows: 0 off, 1 low, 2 medium, 3 high.
var shadow_quality: int
## Frames per second at most, 0 = no cap.
var max_fps: int

# --- Audio (section "audio") ---
## Master volume, 0 (silent) to 1 (full).
var master_volume: float

# --- The start menu (section "menu") ---
## The play option chosen last time (0 open water, 1 Silvaplana terrain, 2 wind viewer).
var last_play_option: int


func _init() -> void:
	reset_to_defaults()


## Puts every setting back to its default. The wind's defaults are the ones in the default
## wind file, so the menu and the physics start from the same numbers.
func reset_to_defaults() -> void:
	var wind: WindConfig = load(WIND_DEFAULT_PATH)
	wind_speed_kt = wind.speed_kt
	wind_from_deg = wind.from_bearing_deg
	gusts_enabled = wind.gusts_enabled
	gust_intensity = wind.gust_intensity
	gust_period_s = wind.gust_period_s
	shifts_enabled = wind.shifts_enabled
	max_shift_deg = wind.max_shift_deg
	shift_period_s = wind.shift_period_s

	waves_enabled = true
	wave_preset = WavePreset.SWELL
	wave_height_scale = 1.0

	control_mode = PlayerController.Mode.BEGINNER
	auto_sheet = true
	start_heading_deg = 180.0
	start_camera = CameraRig.Mode.FOLLOW
	show_hud_panel = true

	fullscreen = false
	vsync = true
	msaa = 0
	render_scale = 1.0
	shadow_quality = 2
	max_fps = 0

	master_volume = 1.0
	last_play_option = 0


# --- The physics' config resources ---------------------------------------------------

## A new WindConfig for the simulation: the default wind file with the menu's numbers.
func build_wind_config() -> WindConfig:
	var base: WindConfig = load(WIND_DEFAULT_PATH)
	# A copy, so the default file (cached and shared by everything that loads it) is not changed.
	var config: WindConfig = base.duplicate(true)
	apply_wind_to(config)
	return config


## Writes the menu's wind numbers into an existing WindConfig (also used to change the wind
## of a running simulation from the pause menu).
func apply_wind_to(config: WindConfig) -> void:
	config.speed_kt = wind_speed_kt
	config.from_bearing_deg = wind_from_deg
	config.gusts_enabled = gusts_enabled
	config.gust_intensity = gust_intensity
	config.gust_period_s = gust_period_s
	config.shifts_enabled = shifts_enabled
	config.max_shift_deg = max_shift_deg
	config.shift_period_s = shift_period_s


## A new WaveSetConfig for the simulation and the ocean: the default wave set, changed to
## the chosen preset and height.
func build_wave_set_config() -> WaveSetConfig:
	var base: WaveSetConfig = load(WAVES_DEFAULT_PATH)
	# duplicate(true) also copies the waves inside the set, so the numbers below change the
	# copy only, never the default file's waves.
	var config: WaveSetConfig = base.duplicate(true)
	config.enable_waves = waves_enabled and wave_preset != WavePreset.FLAT
	match wave_preset:
		WavePreset.MEDIUM_CHOP:
			_set_chop(config, MEDIUM_CHOP_AMPLITUDES_M, MEDIUM_CHOP_STEEPNESS)
		WavePreset.STRONG_CHOP:
			_set_chop(config, STRONG_CHOP_AMPLITUDES_M, STRONG_CHOP_STEEPNESS)
	# A higher wave of the same length is steeper in proportion (steepness = 2 pi A / L), so
	# both scale together. At 2x the strong chop sums to a steepness of about 0.37, well
	# below the 1.0 where the crests would fold over.
	for wave: GerstnerWaveConfig in config.waves:
		wave.amplitude_m *= wave_height_scale
		wave.steepness = minf(wave.steepness * wave_height_scale, 1.0)
	return config


## Puts the chop numbers on waves 2, 3 and 4 (array index 1 to 3).
func _set_chop(config: WaveSetConfig, amplitudes_m: Array[float], steepness: Array[float]) -> void:
	for i: int in amplitudes_m.size():
		var index: int = i + 1
		if index < config.waves.size():
			config.waves[index].amplitude_m = amplitudes_m[i]
			config.waves[index].steepness = steepness[i]


## A short text that changes whenever the sea would come out different: the waves, and the
## wind direction they are lined up with. The sailing scene compares it to decide whether
## the water must be built again.
func sea_signature() -> String:
	return "%s/%d/%.2f/%.0f" % [waves_enabled, wave_preset, wave_height_scale, wind_from_deg]


# --- Saving and loading -------------------------------------------------------------

## Writes every setting into a ConfigFile (the caller saves it to disk).
func write_to(config: ConfigFile) -> void:
	config.set_value("wind", "speed_kt", wind_speed_kt)
	config.set_value("wind", "from_deg", wind_from_deg)
	config.set_value("wind", "gusts_enabled", gusts_enabled)
	config.set_value("wind", "gust_intensity", gust_intensity)
	config.set_value("wind", "gust_period_s", gust_period_s)
	config.set_value("wind", "shifts_enabled", shifts_enabled)
	config.set_value("wind", "max_shift_deg", max_shift_deg)
	config.set_value("wind", "shift_period_s", shift_period_s)

	config.set_value("waves", "enabled", waves_enabled)
	config.set_value("waves", "preset", int(wave_preset))
	config.set_value("waves", "height_scale", wave_height_scale)

	config.set_value("sailing", "control_mode", int(control_mode))
	config.set_value("sailing", "auto_sheet", auto_sheet)
	config.set_value("sailing", "start_heading_deg", start_heading_deg)
	config.set_value("sailing", "start_camera", int(start_camera))
	config.set_value("sailing", "show_hud_panel", show_hud_panel)

	config.set_value("graphics", "fullscreen", fullscreen)
	config.set_value("graphics", "vsync", vsync)
	config.set_value("graphics", "msaa", msaa)
	config.set_value("graphics", "render_scale", render_scale)
	config.set_value("graphics", "shadow_quality", shadow_quality)
	config.set_value("graphics", "max_fps", max_fps)

	config.set_value("audio", "master_volume", master_volume)
	config.set_value("menu", "last_play_option", last_play_option)


## Reads every setting from a ConfigFile. A missing or broken entry keeps its current value,
## and numbers are clamped to the menu's ranges, so a hand-edited file cannot break the game.
func read_from(config: ConfigFile) -> void:
	wind_speed_kt = clampf(_float(config, "wind", "speed_kt", wind_speed_kt), WIND_SPEED_MIN_KT, WIND_SPEED_MAX_KT)
	wind_from_deg = fposmod(_float(config, "wind", "from_deg", wind_from_deg), 360.0)
	gusts_enabled = _bool(config, "wind", "gusts_enabled", gusts_enabled)
	gust_intensity = clampf(_float(config, "wind", "gust_intensity", gust_intensity), GUST_INTENSITY_MIN, GUST_INTENSITY_MAX)
	gust_period_s = clampf(_float(config, "wind", "gust_period_s", gust_period_s), GUST_PERIOD_MIN_S, GUST_PERIOD_MAX_S)
	shifts_enabled = _bool(config, "wind", "shifts_enabled", shifts_enabled)
	max_shift_deg = clampf(_float(config, "wind", "max_shift_deg", max_shift_deg), SHIFT_MIN_DEG, SHIFT_MAX_DEG)
	shift_period_s = clampf(_float(config, "wind", "shift_period_s", shift_period_s), SHIFT_PERIOD_MIN_S, SHIFT_PERIOD_MAX_S)

	waves_enabled = _bool(config, "waves", "enabled", waves_enabled)
	wave_preset = clampi(_int(config, "waves", "preset", wave_preset), 0, WavePreset.size() - 1) as WavePreset
	wave_height_scale = clampf(_float(config, "waves", "height_scale", wave_height_scale), WAVE_SCALE_MIN, WAVE_SCALE_MAX)

	control_mode = clampi(_int(config, "sailing", "control_mode", control_mode), 0, PlayerController.Mode.size() - 1) as PlayerController.Mode
	auto_sheet = _bool(config, "sailing", "auto_sheet", auto_sheet)
	start_heading_deg = fposmod(_float(config, "sailing", "start_heading_deg", start_heading_deg), 360.0)
	start_camera = clampi(_int(config, "sailing", "start_camera", start_camera), 0, CameraRig.Mode.size() - 1) as CameraRig.Mode
	show_hud_panel = _bool(config, "sailing", "show_hud_panel", show_hud_panel)

	fullscreen = _bool(config, "graphics", "fullscreen", fullscreen)
	vsync = _bool(config, "graphics", "vsync", vsync)
	msaa = clampi(_int(config, "graphics", "msaa", msaa), 0, 3)
	render_scale = clampf(_float(config, "graphics", "render_scale", render_scale), RENDER_SCALE_MIN, RENDER_SCALE_MAX)
	shadow_quality = clampi(_int(config, "graphics", "shadow_quality", shadow_quality), 0, 3)
	max_fps = maxi(_int(config, "graphics", "max_fps", max_fps), 0)

	master_volume = clampf(_float(config, "audio", "master_volume", master_volume), 0.0, 1.0)
	last_play_option = clampi(_int(config, "menu", "last_play_option", last_play_option), 0, 2)


## Saves to a file (for example user://settings.cfg). Returns OK or the error.
func save_file(path: String) -> Error:
	var config: ConfigFile = ConfigFile.new()
	write_to(config)
	return config.save(path)


## Loads from a file. A missing file is not an error: the values stay as they are.
func load_file(path: String) -> Error:
	if not FileAccess.file_exists(path):
		return ERR_FILE_NOT_FOUND
	var config: ConfigFile = ConfigFile.new()
	var error: Error = config.load(path)
	if error == OK:
		read_from(config)
	return error


# A number read from the file, or the fallback when it is missing or not a number.
func _float(config: ConfigFile, section: String, key: String, fallback: float) -> float:
	var value: Variant = config.get_value(section, key, fallback)
	if value is float or value is int:
		return float(value)
	return fallback


func _int(config: ConfigFile, section: String, key: String, fallback: int) -> int:
	var value: Variant = config.get_value(section, key, fallback)
	if value is float or value is int:
		return int(value)
	return fallback


func _bool(config: ConfigFile, section: String, key: String, fallback: bool) -> bool:
	var value: Variant = config.get_value(section, key, fallback)
	if value is bool:
		return value
	return fallback


# --- Text for the menus ---------------------------------------------------------------

## The 16-point compass name of a bearing: 0 N, 22.5 NNE, ... 270 W.
static func compass_name(bearing_deg: float) -> String:
	var names: Array[String] = ["N", "NNE", "NE", "ENE", "E", "ESE", "SE", "SSE",
		"S", "SSW", "SW", "WSW", "W", "WNW", "NW", "NNW"]
	var index: int = int(round(fposmod(bearing_deg, 360.0) / 22.5)) % 16
	return names[index]


## What a heading means in this wind, in sailors' words (for the start heading setting).
static func point_of_sail(heading_deg: float, wind_from_deg: float) -> String:
	# The angle between where the board points and where the wind comes from, 0 to 180.
	var off_wind_deg: float = absf(wrapf(heading_deg - wind_from_deg, -180.0, 180.0))
	if off_wind_deg < 40.0:
		return "into the wind (you will stop)"
	if off_wind_deg < 70.0:
		return "close-hauled (upwind)"
	if off_wind_deg < 110.0:
		return "beam reach (across the wind)"
	if off_wind_deg < 150.0:
		return "broad reach"
	return "run (downwind)"


## The name of a wave preset as the menu shows it.
static func wave_preset_name(preset: WavePreset) -> String:
	match preset:
		WavePreset.FLAT:
			return "Flat water"
		WavePreset.MEDIUM_CHOP:
			return "Medium chop"
		WavePreset.STRONG_CHOP:
			return "Strong chop"
	return "Swell"


## A one-line summary of the wind and the sea, for the menus ("18 kt from W (270), swell").
func conditions_text() -> String:
	var sea: String = "flat water"
	if waves_enabled and wave_preset != WavePreset.FLAT:
		sea = wave_preset_name(wave_preset).to_lower()
		if not is_equal_approx(wave_height_scale, 1.0):
			sea += " x%.1f" % wave_height_scale
	var extras: String = ""
	if gusts_enabled:
		extras += ", gusty"
	if shifts_enabled:
		extras += ", shifty"
	return "%.0f kt from %s (%03.0f)%s, %s" % [wind_speed_kt, compass_name(wind_from_deg), wind_from_deg, extras, sea]
