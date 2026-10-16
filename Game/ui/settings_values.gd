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
## set; the two chops are the sets used in the physics sessions (PROGRESS_LOG.md, Session 37);
## From the wind makes the chop from the wind speed, the fetch and the depth (WindWaves).
## New presets go at the end: the settings file stores the number.
enum WavePreset { FLAT, SWELL, MEDIUM_CHOP, STRONG_CHOP, FROM_WIND }

const WIND_DEFAULT_PATH: String = "res://config/wind_default.tres"
const WAVES_DEFAULT_PATH: String = "res://config/waves_default.tres"

## The chop presets change the chop waves of the default set (the 7 m long chop, the 3.5 m
## chop and the 1.8 m ripple, in that order); the 14 m swell stays. Each steepness is the
## physical one for that wave (2 pi x amplitude / wavelength), as in the matrix runs of
## Session 37.
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
## The swell's own height scale: 0 is no swell (a lake), 3 a big one.
const SWELL_SCALE_MIN: float = 0.0
const SWELL_SCALE_MAX: float = 3.0
## How far the chop may be turned from straight downwind, degrees either way.
const CHOP_OFFSET_MAX_DEG: float = 90.0
## The fetch of the From the wind sea: the open water upwind, km.
const FETCH_MIN_KM: float = 0.2
const FETCH_MAX_KM: float = 20.0
## The water depth of the From the wind sea, m. The top of the range means deep water:
## 20 m is deep for every wave this menu can make.
const DEPTH_MIN_M: float = 0.5
const DEPTH_DEEP_M: float = 20.0
## The sum of the steepness of all waves is kept below this, so the crests never fold over
## (section 9.8), however the menu's scales are set.
const MAX_TOTAL_STEEPNESS: float = 0.9
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
## true: the swell follows the wind (at the default file's offset); false: it comes from
## swell_from_deg.
var swell_follows_wind: bool
## Compass bearing the swell comes FROM when it does not follow the wind, degrees.
var swell_from_deg: float
## Multiplies the height (and the steepness) of the swell only, on top of wave_height_scale.
var swell_height_scale: float
## The chop's direction as an offset from straight downwind, degrees (positive = clockwise).
var chop_offset_deg: float
## From the wind: the open water upwind (km) and the depth (m; DEPTH_DEEP_M = deep water).
var fetch_km: float
var water_depth_m: float

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
## The play option chosen last time (0 open water, 1 Silvaplana fly-over, 2 wind viewer,
## 3 sailing on Lake Silvaplana: StartMenu.PlayOption).
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

	var waves: WaveSetConfig = load(WAVES_DEFAULT_PATH)
	waves_enabled = true
	wave_preset = WavePreset.SWELL
	wave_height_scale = 1.0
	swell_follows_wind = waves.swell_relative_to_wind
	swell_from_deg = waves.swell_from_deg
	swell_height_scale = 1.0
	chop_offset_deg = waves.chop_offset_deg
	fetch_km = 3.0
	water_depth_m = DEPTH_DEEP_M

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
## the chosen preset, directions and heights.
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
		WavePreset.FROM_WIND:
			_set_chop_from_wind(config)
	# The directions: the swell from the wind (at the file's offset) or from a bearing, the
	# chop turned from downwind.
	config.swell_relative_to_wind = swell_follows_wind
	config.swell_from_deg = swell_from_deg
	config.chop_offset_deg = chop_offset_deg
	# A higher wave of the same length is steeper in proportion (steepness = 2 pi A / L), so
	# both scale together.
	for wave: GerstnerWaveConfig in config.waves_in_group(GerstnerWaveConfig.Group.SWELL):
		_scale_wave(wave, swell_height_scale)
	for wave: GerstnerWaveConfig in config.waves:
		_scale_wave(wave, wave_height_scale)
	_keep_crests_from_folding(config)
	return config


## Puts the chop numbers on the chop waves of the set, in order.
func _set_chop(config: WaveSetConfig, amplitudes_m: Array[float], steepness: Array[float]) -> void:
	var chop: Array[GerstnerWaveConfig] = config.waves_in_group(GerstnerWaveConfig.Group.CHOP)
	for i: int in mini(amplitudes_m.size(), chop.size()):
		chop[i].amplitude_m = amplitudes_m[i]
		chop[i].steepness = steepness[i]


## From the wind: the default set's swell, and in place of its chop the waves this wind
## makes over this fetch and depth (WindWaves, PHYSICS_SPEC.md 9.16).
func _set_chop_from_wind(config: WaveSetConfig) -> void:
	var waves: Array[GerstnerWaveConfig] = config.waves_in_group(GerstnerWaveConfig.Group.SWELL)
	waves.append_array(WindWaves.chop_waves(wind_speed_kt * SimMath.KNOT_MS, fetch_km * 1000.0, wind_wave_depth_m()))
	config.waves = waves


## The depth WindWaves gets: the slider's value, or deep water at the top of its range.
func wind_wave_depth_m() -> float:
	return WindWaves.DEEP_WATER if water_depth_m >= DEPTH_DEEP_M else water_depth_m


func _scale_wave(wave: GerstnerWaveConfig, scale: float) -> void:
	wave.amplitude_m *= scale
	wave.steepness = minf(wave.steepness * scale, 1.0)


## Scales every steepness down when their sum is above MAX_TOTAL_STEEPNESS: the crests get
## a bit rounder, the heights stay. Only the extremes need it (a strong wind over a short
## fetch at twice the height); the presets at 2x sum to about 0.4.
func _keep_crests_from_folding(config: WaveSetConfig) -> void:
	var total: float = config.total_steepness()
	if total <= MAX_TOTAL_STEEPNESS:
		return
	for wave: GerstnerWaveConfig in config.waves:
		wave.steepness *= MAX_TOTAL_STEEPNESS / total


## A short text that changes whenever the sea would come out different: the waves, their
## directions, and the wind they are lined up with (and made by, for From the wind). The
## sailing scene compares it to decide whether the water must be built again.
func sea_signature() -> String:
	var signature: String = "%s/%d/%.2f/%.0f" % [waves_enabled, wave_preset, wave_height_scale, wind_from_deg]
	signature += "/swell %s %.0f %.2f/chop %.0f" % [swell_follows_wind, swell_from_deg, swell_height_scale, chop_offset_deg]
	if wave_preset == WavePreset.FROM_WIND:
		signature += "/made by %.0f kt over %.1f km, %.1f m deep" % [wind_speed_kt, fetch_km, water_depth_m]
	return signature


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
	config.set_value("waves", "swell_follows_wind", swell_follows_wind)
	config.set_value("waves", "swell_from_deg", swell_from_deg)
	config.set_value("waves", "swell_height_scale", swell_height_scale)
	config.set_value("waves", "chop_offset_deg", chop_offset_deg)
	config.set_value("waves", "fetch_km", fetch_km)
	config.set_value("waves", "depth_m", water_depth_m)

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
	swell_follows_wind = _bool(config, "waves", "swell_follows_wind", swell_follows_wind)
	swell_from_deg = fposmod(_float(config, "waves", "swell_from_deg", swell_from_deg), 360.0)
	swell_height_scale = clampf(_float(config, "waves", "swell_height_scale", swell_height_scale), SWELL_SCALE_MIN, SWELL_SCALE_MAX)
	chop_offset_deg = clampf(_float(config, "waves", "chop_offset_deg", chop_offset_deg), -CHOP_OFFSET_MAX_DEG, CHOP_OFFSET_MAX_DEG)
	fetch_km = clampf(_float(config, "waves", "fetch_km", fetch_km), FETCH_MIN_KM, FETCH_MAX_KM)
	water_depth_m = clampf(_float(config, "waves", "depth_m", water_depth_m), DEPTH_MIN_M, DEPTH_DEEP_M)

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
	last_play_option = clampi(_int(config, "menu", "last_play_option", last_play_option), 0, 3)


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
		WavePreset.FROM_WIND:
			return "From the wind"
	return "Swell"


## A one-line summary of the wind and the sea, for the menus ("18 kt from W (270), swell").
func conditions_text() -> String:
	var sea: String = "flat water"
	if waves_enabled and wave_preset != WavePreset.FLAT:
		sea = wave_preset_name(wave_preset).to_lower()
		if wave_preset == WavePreset.FROM_WIND:
			sea = "wind chop over %.1f km" % fetch_km
		if not is_equal_approx(wave_height_scale, 1.0):
			sea += " x%.1f" % wave_height_scale
		if not swell_follows_wind and swell_height_scale > 0.0:
			sea += ", swell from %s" % compass_name(swell_from_deg)
	var extras: String = ""
	if gusts_enabled:
		extras += ", gusty"
	if shifts_enabled:
		extras += ", shifty"
	return "%.0f kt from %s (%03.0f)%s, %s" % [wind_speed_kt, compass_name(wind_from_deg), wind_from_deg, extras, sea]
