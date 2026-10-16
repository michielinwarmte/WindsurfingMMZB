class_name SettingsMenu
extends MenuPage
## The settings, on five tabs: Wind, Waves, Sailing, Graphics and Audio. Every change goes
## straight into GameSettings.values (the graphics and the sound apply at once) and the
## file is saved when the page closes. The start menu and the pause menu each have one;
## what happens to the wind and the waves of a running game is up to the sailing scene
## (main.gd, apply_settings_live()).
##
## The frame is in settings_menu.tscn; the rows are built here, one helper per kind of
## row (a slider, a switch, a list), because 23 rows of the same shape are easier to read
## and to change as a list in code than as nodes in a scene file. Each row is: the name |
## the control | a text that shows the value or explains it.
##
## Keys: the arrows move between the rows and change a slider or a switch, Enter opens a
## list, the gamepad's shoulder buttons (or Ctrl+Tab) switch tabs, Esc goes back.

## Under the tabs: when the changes take effect. The pause menu sets its own text.
@export_multiline var note_text: String = "Changes are saved when you leave this page."

## The width of the name and the value columns, so the sliders line up on every tab.
const NAME_WIDTH: float = 230.0
const VALUE_WIDTH: float = 330.0

@onready var _tabs: TabContainer = %Tabs
@onready var _wind_rows: GridContainer = %WindRows
@onready var _wave_rows: GridContainer = %WaveRows
@onready var _sailing_rows: GridContainer = %SailingRows
@onready var _graphics_rows: GridContainer = %GraphicsRows
@onready var _audio_rows: GridContainer = %AudioRows
@onready var _conditions: Label = %Conditions
@onready var _note: Label = %Note
@onready var _reset_button: Button = %ResetButton
@onready var _back_button: Button = %BackButton

## The wave rows' texts and whether they can be changed depend on each other (the height
## depends on the preset, the swell's bearing only counts when the swell does not follow
## the wind), so they are kept to update them together (_update_wave_rows()).
var _wave_height_row: Row
var _sea_state_row: Row
var _swell_mode_row: Row
var _swell_bearing_row: Row
var _swell_height_row: Row
var _chop_direction_row: Row
var _fetch_row: Row
var _depth_row: Row


## One row of a tab: the name on the left, the control, and the text on the right.
class Row:
	var name_label: Label
	var control: Control
	var value_label: Label


func _ready() -> void:
	_reset_button.pressed.connect(_on_reset_pressed)
	_back_button.pressed.connect(close)
	_build_rows()


func open() -> void:
	# The values may have changed since the rows were built (another menu, a reset).
	_build_rows()
	_note.text = note_text
	super()


func close() -> void:
	GameSettings.save()
	super()


func first_focus() -> Control:
	return _tabs.get_tab_bar()


## Shows one tab: wind, waves, sailing, graphics or audio (for --page=settings/<tab>).
func show_tab(tab_name: String) -> void:
	for i: int in _tabs.get_tab_count():
		if _tabs.get_tab_title(i).to_lower() == tab_name.to_lower():
			_tabs.current_tab = i


func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	# Switch tabs with the gamepad's shoulder buttons or Ctrl+Tab / Ctrl+Shift+Tab.
	var step: int = 0
	var button: InputEventJoypadButton = event as InputEventJoypadButton
	if button != null and button.pressed:
		if button.button_index == JOY_BUTTON_RIGHT_SHOULDER:
			step = 1
		elif button.button_index == JOY_BUTTON_LEFT_SHOULDER:
			step = -1
	var key: InputEventKey = event as InputEventKey
	if key != null and key.pressed and key.ctrl_pressed and key.physical_keycode == KEY_TAB:
		step = -1 if key.shift_pressed else 1
	if step != 0:
		_tabs.current_tab = posmod(_tabs.current_tab + step, _tabs.get_tab_count())
		_tabs.get_tab_bar().grab_focus()
		get_viewport().set_input_as_handled()
		return
	super(event)


func _on_reset_pressed() -> void:
	GameSettings.reset_to_defaults()
	_build_rows()
	_reset_button.grab_focus()


## Called after every change: the summary at the top, and the graphics and sound.
func _changed() -> void:
	GameSettings.notify_changed()
	_conditions.text = GameSettings.values.conditions_text()


# --- The rows ---------------------------------------------------------------------------

func _build_rows() -> void:
	for grid: GridContainer in [_wind_rows, _wave_rows, _sailing_rows, _graphics_rows, _audio_rows]:
		for child: Node in grid.get_children():
			grid.remove_child(child)
			child.queue_free()
	var s: SettingsValues = GameSettings.values
	_build_wind_rows(s)
	_build_wave_rows(s)
	_build_sailing_rows(s)
	_build_graphics_rows(s)
	_build_audio_rows(s)
	_conditions.text = s.conditions_text()


# In every row below, the first small function turns the value into the text on the
# right, and the second one stores a new value in the settings.

func _build_wind_rows(s: SettingsValues) -> void:
	var grid: GridContainer = _wind_rows
	_add_slider(grid, "Wind speed", SettingsValues.WIND_SPEED_MIN_KT, SettingsValues.WIND_SPEED_MAX_KT, 1.0, s.wind_speed_kt,
		func(v: float) -> String: return "%.0f knots  (%.0f km/h)" % [v, v * SimMath.KNOT_MS * 3.6],
		func(v: float) -> void: s.wind_speed_kt = v)
	_add_slider(grid, "Wind from", 0.0, 359.0, 1.0, s.wind_from_deg,
		func(v: float) -> String: return "%03.0f°  %s" % [v, SettingsValues.compass_name(v)],
		func(v: float) -> void: s.wind_from_deg = v)
	var gusts: Row = _add_switch(grid, "Gusts", s.gusts_enabled, "The wind comes and goes",
		func(on: bool) -> void: s.gusts_enabled = on)
	var gust_strength: Row = _add_slider(grid, "Gust strength", SettingsValues.GUST_INTENSITY_MIN, SettingsValues.GUST_INTENSITY_MAX, 0.05, s.gust_intensity,
		func(v: float) -> String: return "up to ± %.0f %% of the wind" % (v * 100.0),
		func(v: float) -> void: s.gust_intensity = v)
	var gust_period: Row = _add_slider(grid, "Gust period", SettingsValues.GUST_PERIOD_MIN_S, SettingsValues.GUST_PERIOD_MAX_S, 1.0, s.gust_period_s,
		func(v: float) -> String: return "%.0f s" % v,
		func(v: float) -> void: s.gust_period_s = v)
	_enable_with(gusts, [gust_strength, gust_period])
	var shifts: Row = _add_switch(grid, "Wind shifts", s.shifts_enabled, "The direction swings slowly",
		func(on: bool) -> void: s.shifts_enabled = on)
	var shift_size: Row = _add_slider(grid, "Largest shift", SettingsValues.SHIFT_MIN_DEG, SettingsValues.SHIFT_MAX_DEG, 1.0, s.max_shift_deg,
		func(v: float) -> String: return "± %.0f°" % v,
		func(v: float) -> void: s.max_shift_deg = v)
	var shift_period: Row = _add_slider(grid, "Shift period", SettingsValues.SHIFT_PERIOD_MIN_S, SettingsValues.SHIFT_PERIOD_MAX_S, 5.0, s.shift_period_s,
		func(v: float) -> String: return "%.0f s" % v,
		func(v: float) -> void: s.shift_period_s = v)
	_enable_with(shifts, [shift_size, shift_period])


func _build_wave_rows(s: SettingsValues) -> void:
	var grid: GridContainer = _wave_rows
	_add_switch(grid, "Waves", s.waves_enabled, "Off: flat water",
		func(on: bool) -> void: s.waves_enabled = on)
	var presets: Array[String] = []
	for preset: int in SettingsValues.WavePreset.size():
		presets.append(SettingsValues.wave_preset_name(preset as SettingsValues.WavePreset))
	_sea_state_row = _add_list(grid, "Sea state", presets, s.wave_preset, "",
		func(index: int) -> void: s.wave_preset = index as SettingsValues.WavePreset)
	# The height's text is the highest wave of the whole set, which the other rows change too.
	_wave_height_row = _add_slider(grid, "Wave height", SettingsValues.WAVE_SCALE_MIN, SettingsValues.WAVE_SCALE_MAX, 0.1, s.wave_height_scale,
		func(_v: float) -> String: return _wave_height_text(),
		func(v: float) -> void: s.wave_height_scale = v)
	# The swell: long waves from far away, from the wind's direction or from a bearing.
	_swell_mode_row = _add_list(grid, "Swell comes from", ["The wind's direction", "A compass bearing"], 0 if s.swell_follows_wind else 1, "",
		func(index: int) -> void: s.swell_follows_wind = index == 0)
	_swell_bearing_row = _add_slider(grid, "Swell from", 0.0, 355.0, 5.0, s.swell_from_deg,
		func(v: float) -> String: return "%03.0f°  %s" % [v, SettingsValues.compass_name(v)],
		func(v: float) -> void: s.swell_from_deg = v)
	_swell_height_row = _add_slider(grid, "Swell height", SettingsValues.SWELL_SCALE_MIN, SettingsValues.SWELL_SCALE_MAX, 0.1, s.swell_height_scale,
		func(_v: float) -> String: return _swell_height_text(),
		func(v: float) -> void: s.swell_height_scale = v)
	# The chop: the waves the wind makes, turned from straight downwind.
	_chop_direction_row = _add_slider(grid, "Chop direction", -SettingsValues.CHOP_OFFSET_MAX_DEG, SettingsValues.CHOP_OFFSET_MAX_DEG, 5.0, s.chop_offset_deg,
		func(v: float) -> String: return _chop_direction_text(v),
		func(v: float) -> void: s.chop_offset_deg = v)
	# From the wind: how far the wind blows over open water, and how deep it is.
	_fetch_row = _add_slider(grid, "Fetch", SettingsValues.FETCH_MIN_KM, SettingsValues.FETCH_MAX_KM, 0.1, s.fetch_km,
		func(v: float) -> String: return "%.1f km of open water upwind" % v,
		func(v: float) -> void: s.fetch_km = v)
	_depth_row = _add_slider(grid, "Water depth", SettingsValues.DEPTH_MIN_M, SettingsValues.DEPTH_DEEP_M, 0.5, s.water_depth_m,
		func(v: float) -> String: return "Deep water" if v >= SettingsValues.DEPTH_DEEP_M else "%.1f m deep: waves at most %.0f cm" % [v, 60.0 * v],
		func(v: float) -> void: s.water_depth_m = v)
	# Every change, here or on another tab (the wind's speed and direction), updates the
	# wave rows' texts and greys out the rows that do not count.
	if not GameSettings.changed.is_connected(_update_wave_rows):
		GameSettings.changed.connect(_update_wave_rows)
	_update_wave_rows()
	_add_note(grid, "The swell is long waves from far away; the chop is the short waves the wind makes here. Fetch and depth are for From the wind.")


## The texts that depend on other rows, and which rows can be changed: nothing without
## waves, the swell's bearing only when the swell does not follow the wind, the fetch and
## the depth only for From the wind.
func _update_wave_rows() -> void:
	var s: SettingsValues = GameSettings.values
	_sea_state_row.value_label.text = _sea_state_hint(s.wave_preset)
	_wave_height_row.value_label.text = _wave_height_text()
	_swell_mode_row.value_label.text = "Turns with the wind" if s.swell_follows_wind else "Stays when the wind turns"
	_swell_height_row.value_label.text = _swell_height_text()
	_chop_direction_row.value_label.text = _chop_direction_text(s.chop_offset_deg)
	var has_waves: bool = s.waves_enabled and s.wave_preset != SettingsValues.WavePreset.FLAT
	_set_wave_row_enabled(_sea_state_row, s.waves_enabled)
	for row: Row in [_wave_height_row, _swell_mode_row, _swell_height_row, _chop_direction_row]:
		_set_wave_row_enabled(row, has_waves)
	_set_wave_row_enabled(_swell_bearing_row, has_waves and not s.swell_follows_wind)
	var from_wind: bool = has_waves and s.wave_preset == SettingsValues.WavePreset.FROM_WIND
	_set_wave_row_enabled(_fetch_row, from_wind)
	_set_wave_row_enabled(_depth_row, from_wind)


## A row that cannot be changed now is greyed out (like the rows below a switch that is off).
func _set_wave_row_enabled(row: Row, on: bool) -> void:
	var slider: HSlider = row.control as HSlider
	if slider != null:
		slider.editable = on
	var list: OptionButton = row.control as OptionButton
	if list != null:
		list.disabled = not on
	row.control.modulate.a = 1.0 if on else 0.4
	row.value_label.modulate.a = 1.0 if on else 0.4


func _sea_state_hint(preset: SettingsValues.WavePreset) -> String:
	match preset:
		SettingsValues.WavePreset.FLAT:
			return "No waves at all"
		SettingsValues.WavePreset.MEDIUM_CHOP:
			return "Short waves on the swell"
		SettingsValues.WavePreset.STRONG_CHOP:
			return "Steep short waves: bumpy"
		SettingsValues.WavePreset.FROM_WIND:
			return _wind_chop_text()
	return "Long, gentle waves (the default)"


## "1.0 x  (crest to trough up to 23 cm)": the highest wave the set can make, where all its
## waves meet at once (twice the sum of the amplitudes).
func _wave_height_text() -> String:
	var s: SettingsValues = GameSettings.values
	var waves: WaveSetConfig = s.build_wave_set_config()
	if not waves.enable_waves:
		return "%.1f x  (flat water)" % s.wave_height_scale
	return "%.1f x  (crest to trough up to %.0f cm)" % [s.wave_height_scale, waves.total_amplitude_m() * 2.0 * 100.0]


## "1.0 x  (16 cm crest to trough)": the swell's own height, or "no swell" at 0.
func _swell_height_text() -> String:
	var s: SettingsValues = GameSettings.values
	var swell_m: float = 0.0
	for wave: GerstnerWaveConfig in s.build_wave_set_config().waves_in_group(GerstnerWaveConfig.Group.SWELL):
		swell_m += 2.0 * wave.amplitude_m
	if swell_m <= 0.0:
		return "%.1f x  (no swell)" % s.swell_height_scale
	return "%.1f x  (%.0f cm crest to trough)" % [s.swell_height_scale, swell_m * 100.0]


## "+20° off the wind: from 290° WNW": where the chop comes from with this offset.
func _chop_direction_text(offset_deg: float) -> String:
	var from_deg: float = fposmod(GameSettings.values.wind_from_deg + offset_deg, 360.0)
	if is_zero_approx(offset_deg):
		return "Straight downwind: from %03.0f° %s" % [from_deg, SettingsValues.compass_name(from_deg)]
	return "%+.0f° off the wind: from %03.0f° %s" % [offset_deg, from_deg, SettingsValues.compass_name(from_deg)]


## "16 kt: waves of 23 cm, 5.2 m long": the significant height and the peak wavelength the
## wind makes over the chosen fetch and depth.
func _wind_chop_text() -> String:
	var s: SettingsValues = GameSettings.values
	var wind_ms: float = s.wind_speed_kt * SimMath.KNOT_MS
	var depth_m: float = s.wind_wave_depth_m()
	var height_m: float = WindWaves.significant_height_m(wind_ms, s.fetch_km * 1000.0, depth_m)
	var length_m: float = WindWaves.wavelength_m(WindWaves.peak_period_s(wind_ms, s.fetch_km * 1000.0), depth_m)
	return "%.0f kt: waves of %.0f cm, %.1f m long" % [s.wind_speed_kt, height_m * 100.0, length_m]


func _build_sailing_rows(s: SettingsValues) -> void:
	var grid: GridContainer = _sailing_rows
	_add_list(grid, "Controls", ["Beginner", "Advanced"], s.control_mode, "Tab switches while sailing",
		func(index: int) -> void: s.control_mode = index as PlayerController.Mode)
	_add_switch(grid, "Auto-sheet", s.auto_sheet, "The sail is trimmed for you (T)",
		func(on: bool) -> void: s.auto_sheet = on)
	_add_slider(grid, "Start heading", 0.0, 355.0, 5.0, s.start_heading_deg,
		func(v: float) -> String: return "%03.0f° %s: %s" % [v, SettingsValues.compass_name(v), SettingsValues.point_of_sail(v, GameSettings.values.wind_from_deg)],
		func(v: float) -> void: s.start_heading_deg = v)
	_add_list(grid, "Camera at the start", ["Follow", "Orbit", "Top-down", "Free"], s.start_camera, "Keys 1 to 4 while sailing",
		func(index: int) -> void: s.start_camera = index as CameraRig.Mode)
	_add_switch(grid, "Detail panel", s.show_hud_panel, "The forces and the key help (F1)",
		func(on: bool) -> void: s.show_hud_panel = on)


func _build_graphics_rows(s: SettingsValues) -> void:
	var grid: GridContainer = _graphics_rows
	_add_list(grid, "Window", ["Windowed", "Fullscreen"], 1 if s.fullscreen else 0, "",
		func(index: int) -> void: s.fullscreen = index == 1)
	_add_switch(grid, "VSync", s.vsync, "No tearing; caps the frame rate to the screen",
		func(on: bool) -> void: s.vsync = on)
	_add_list(grid, "Anti-aliasing", ["Off", "MSAA 2x", "MSAA 4x", "MSAA 8x"], s.msaa, "Smoother edges, slower",
		func(index: int) -> void: s.msaa = index)
	_add_slider(grid, "Resolution scale", SettingsValues.RENDER_SCALE_MIN, SettingsValues.RENDER_SCALE_MAX, 0.05, s.render_scale,
		func(v: float) -> String: return "%.0f %%  (lower is faster)" % (v * 100.0),
		func(v: float) -> void: s.render_scale = v)
	_add_list(grid, "Shadows", ["Off", "Low", "Medium", "High"], s.shadow_quality, "",
		func(index: int) -> void: s.shadow_quality = index)
	var caps: Array[String] = []
	for fps: int in SettingsValues.FPS_CAPS:
		caps.append("No cap" if fps == 0 else "%d fps" % fps)
	_add_list(grid, "Frame-rate cap", caps, maxi(SettingsValues.FPS_CAPS.find(s.max_fps), 0), "",
		func(index: int) -> void: s.max_fps = SettingsValues.FPS_CAPS[index])


func _build_audio_rows(s: SettingsValues) -> void:
	var grid: GridContainer = _audio_rows
	var percent: Callable = func(v: float) -> String: return "%.0f %%" % (v * 100.0)
	_add_slider(grid, "Master volume", 0.0, 1.0, 0.05, s.master_volume, percent,
		func(v: float) -> void: s.master_volume = v)
	_add_slider(grid, "Wind", 0.0, 1.0, 0.05, s.wind_volume, percent,
		func(v: float) -> void: s.wind_volume = v)
	_add_slider(grid, "Water", 0.0, 1.0, 0.05, s.water_volume, percent,
		func(v: float) -> void: s.water_volume = v)
	_add_slider(grid, "Sail", 0.0, 1.0, 0.05, s.sail_volume, percent,
		func(v: float) -> void: s.sail_volume = v)
	_add_note(grid, "Wind: the apparent wind in your ears. Water: lapping, the planing hiss and splashes. Sail: flapping when it luffs, the crack when it fills and the swoosh in a tack. All sounds are made by the game itself, from noise.")


# --- Row helpers ------------------------------------------------------------------------

## A row with a slider. describe turns a value into the text on the right; store puts a
## new value into the settings.
func _add_slider(grid: GridContainer, title: String, min_value: float, max_value: float, step: float,
		value: float, describe: Callable, store: Callable) -> Row:
	var row: Row = Row.new()
	row.name_label = _add_name(grid, title)
	var slider: HSlider = HSlider.new()
	slider.min_value = min_value
	slider.max_value = max_value
	slider.step = step
	slider.value = value
	slider.custom_minimum_size = Vector2(300.0, 30.0)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	grid.add_child(slider)
	row.control = slider
	row.value_label = _add_value(grid, str(describe.call(value)))
	var when_moved: Callable = func(new_value: float) -> void:
		store.call(new_value)
		row.value_label.text = str(describe.call(new_value))
		_changed()
	slider.value_changed.connect(when_moved)
	_highlight_on_focus(row)
	return row


## A row with an on/off switch and a hint on the right.
func _add_switch(grid: GridContainer, title: String, on: bool, hint: String, store: Callable) -> Row:
	var row: Row = Row.new()
	row.name_label = _add_name(grid, title)
	var switch: CheckButton = CheckButton.new()
	switch.button_pressed = on
	switch.text = "On" if on else "Off"
	switch.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	grid.add_child(switch)
	row.control = switch
	row.value_label = _add_value(grid, hint)
	var when_toggled: Callable = func(now_on: bool) -> void:
		store.call(now_on)
		switch.text = "On" if now_on else "Off"
		_changed()
	switch.toggled.connect(when_toggled)
	_highlight_on_focus(row)
	return row


## A row with a list to choose from and a hint on the right.
func _add_list(grid: GridContainer, title: String, items: Array[String], selected: int, hint: String, store: Callable) -> Row:
	var row: Row = Row.new()
	row.name_label = _add_name(grid, title)
	var list: OptionButton = OptionButton.new()
	for item: String in items:
		list.add_item(item)
	list.select(selected)
	list.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	list.custom_minimum_size = Vector2(220.0, 0.0)
	grid.add_child(list)
	row.control = list
	row.value_label = _add_value(grid, hint)
	var when_chosen: Callable = func(index: int) -> void:
		store.call(index)
		_changed()
	list.item_selected.connect(when_chosen)
	_highlight_on_focus(row)
	return row


## A line of text across the whole row (three cells: the text and two empty ones).
func _add_note(grid: GridContainer, text: String) -> void:
	_add_name(grid, "")
	var note: Label = Label.new()
	note.theme_type_variation = &"HintLabel"
	note.text = text
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size = Vector2(300.0, 0.0)
	grid.add_child(note)
	grid.add_child(Control.new())


func _add_name(grid: GridContainer, title: String) -> Label:
	var label: Label = Label.new()
	label.text = title
	label.custom_minimum_size = Vector2(NAME_WIDTH, 0.0)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	grid.add_child(label)
	return label


func _add_value(grid: GridContainer, text: String) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.theme_type_variation = &"HintLabel"
	label.custom_minimum_size = Vector2(VALUE_WIDTH, 0.0)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	grid.add_child(label)
	return label


## The row's name lights up (orange, like the focus outline) while its control has the
## keyboard or gamepad focus, because a slider has no outline of its own.
func _highlight_on_focus(row: Row) -> void:
	row.control.focus_entered.connect(func() -> void: row.name_label.add_theme_color_override("font_color", Color(1.0, 0.63, 0.2)))
	row.control.focus_exited.connect(func() -> void: row.name_label.remove_theme_color_override("font_color"))


## The rows below a switch only work while it is on (the gust sliders need gusts) and are
## greyed out while it is off.
func _enable_with(switch_row: Row, rows: Array[Row]) -> void:
	var switch: CheckButton = switch_row.control as CheckButton
	var update: Callable = func(on: bool) -> void:
		for row: Row in rows:
			var slider: HSlider = row.control as HSlider
			if slider != null:
				slider.editable = on
			var list: OptionButton = row.control as OptionButton
			if list != null:
				list.disabled = not on
			row.control.modulate.a = 1.0 if on else 0.4
			row.value_label.modulate.a = 1.0 if on else 0.4
	switch.toggled.connect(update)
	update.call(switch.button_pressed)
