class_name LanPage
extends MenuPage
## The start menu's "Play with a friend (LAN)" page (LAN multiplayer, Documentation/reports/
## multiplayer/PLAN.md, D2 and D9). Three views on one page:
## - the start: your name, Host a game, Join a game;
## - joining: the games heard on the network (the host calls out once a second), or the host's
##   address typed;
## - the lobby: who is in, and the game. The host chooses: the map, free sailing or a race, the race
##   (course, AI fleet, who sails it, countdown, laps, level, rules, wind shadows), the lake's time of
##   day, and the wind and the waves (the Settings page). The guest sees the host's choice, picks its
##   own gear (the Gear page) and says it is Ready. The host's Start starts the game on both PCs.
## The connection itself is LanSession's (the autoload Lan).

## The host's "Wind and waves" and anyone's "Change gear": the start menu opens that page, and this
## one again when it closes (reopen_after()).
signal settings_requested
signal gear_requested

enum View { START, JOIN, LOBBY }

const NAME_WIDTH: float = 200.0
## The host's choices sit in two columns of a name and a control (the hints are the controls'
## tooltips), so the lobby fits a 720-pixel-high window.
const CHOICE_NAME_WIDTH: float = 130.0
const CHOICE_WIDTH: float = 330.0
## The AI boards the lobby offers. Each one's state goes to the guest 30 times a second (about 45 kB/s).
const FLEET_SIZES: PackedInt32Array = [0, 3, 7, 11, 15, 19]
const COUNTDOWNS_S: PackedFloat32Array = [30.0, 60.0, 180.0]
const COUNTDOWN_NAMES: PackedStringArray = ["30 s", "60 s", "3 min"]
const LAPS: PackedInt32Array = [1, 2, 3]
const LAKE_TIMES_S: PackedFloat32Array = [43200.0, 52200.0, 61200.0]
const LAKE_TIME_NAMES: PackedStringArray = ["12:00, building", "14:30, strongest", "17:00, evening"]
const FIREWALL_HINT: String = "Both PCs on the same network (Wi-Fi or cable) with the same version of the game. The first time a PC hosts, Windows asks whether the game may use the network: allow it on private networks."

## The host's choices, kept for the session.
static var chosen_lake: bool = false
static var chosen_race: bool = true
static var chosen_course: int = 0
static var chosen_fleet: int = 1
static var chosen_who: RacePage.Who = RacePage.Who.PERSONAS
static var chosen_countdown: int = 1
static var chosen_laps: int = 0
static var chosen_level: int = 0
static var chosen_rules: bool = true
static var chosen_shadows: bool = true
static var chosen_lake_time: int = 1

var _view: View = View.START
var _ready_now: bool = false

var _title: Label
var _hint: Label
var _start_box: VBoxContainer
var _name_edit: LineEdit
var _host_button: Button
var _join_view_button: Button
var _join_box: VBoxContainer
var _found_list: ItemList
var _address_edit: LineEdit
var _join_button: Button
var _lobby_box: VBoxContainer
var _players_label: Label
var _host_rows: GridContainer
var _course_list: OptionButton
var _course_names: PackedStringArray = PackedStringArray()
var _lake_time_list: OptionButton
var _guest_summary: Label
var _gear_label: Label
var _conditions_label: Label
var _wind_button: Button
var _status: Label
var _back_button: Button
var _primary_button: Button
## The found games' addresses, in the list's order.
var _found_addresses: PackedStringArray = PackedStringArray()


func _ready() -> void:
	_build()
	Lan.lobby_changed.connect(_on_lobby_changed)
	Lan.found_games_changed.connect(_refresh_found)
	Lan.ended.connect(_on_session_ended)
	_show_view(View.START)


func first_focus() -> Control:
	match _view:
		View.JOIN:
			return _join_button
		View.LOBBY:
			return _primary_button
	return _host_button


## Esc and Back: from the lobby or the join list one step back (leaving the session), from the start
## back to the start menu.
func close() -> void:
	if _view == View.START:
		Lan.stop_listening()
		super()
		return
	Lan.leave()
	Lan.stop_listening()
	_show_view(View.START)


## Back from the Settings or the Gear page: the host's new wind goes to the guest, a new gear to the
## host.
func reopen_after(_settings_changed: bool) -> void:
	show()
	if Lan.is_host():
		_send_choice()
	elif Lan.is_guest():
		Lan.update_me(_ready_now)
	_refresh_lobby()
	first_focus().grab_focus()


## For screenshots (the start menu's --page=lan/host or lan/join): that view, as if pressed.
func show_for_screenshot(view: String) -> void:
	if view == "host":
		_on_host_pressed()
	elif view == "join":
		_on_join_view_pressed()


# ---------------------------------------------------------------- the views

func _show_view(view: View) -> void:
	_view = view
	_start_box.visible = view == View.START
	_join_box.visible = view == View.JOIN
	_lobby_box.visible = view == View.LOBBY
	_status.text = ""
	match view:
		View.START:
			_title.text = "Play with a friend"
			_hint.text = FIREWALL_HINT
			_back_button.text = "Back"
			_primary_button.hide()
		View.JOIN:
			_title.text = "Join a game"
			_hint.text = "The games hosted on your network show up here by themselves. Or type the host's address (the host's lobby shows it)."
			_back_button.text = "Back"
			_primary_button.hide()
			_refresh_found()
		View.LOBBY:
			_primary_button.show()
			_refresh_lobby()
	if is_visible_in_tree():
		first_focus().grab_focus()


func _on_host_pressed() -> void:
	_remember_name()
	if Lan.host_game(_name_edit.text) != OK:
		_status.text = Lan.last_error
		return
	_ready_now = true
	_send_choice()
	_show_view(View.LOBBY)


func _on_join_view_pressed() -> void:
	_remember_name()
	if Lan.start_listening() != OK:
		_status.text = Lan.last_error
	_show_view(View.JOIN)
	if Lan.last_error != "":
		_status.text = Lan.last_error


func _on_join_pressed() -> void:
	var address: String = _address_edit.text.strip_edges()
	var selected: PackedInt32Array = _found_list.get_selected_items()
	if not selected.is_empty() and selected[0] < _found_addresses.size():
		address = _found_addresses[selected[0]]
	if address == "":
		_status.text = "Choose a game from the list, or type the host's address."
		return
	GameSettings.values.lan_address = _address_edit.text.strip_edges()
	GameSettings.save()
	Lan.stop_listening()
	if Lan.join_game(address, _name_edit.text) != OK:
		_status.text = Lan.last_error
		return
	_ready_now = false
	_status.text = "Connecting to %s..." % address


func _on_found_activated(index: int) -> void:
	_found_list.select(index)
	_on_join_pressed()


func _remember_name() -> void:
	_name_edit.text = LanPlayer.clean_name(_name_edit.text if _name_edit.text.strip_edges() != "" else default_name())
	GameSettings.values.lan_name = _name_edit.text
	GameSettings.save()


## The name the page offers first: the one used last, else the PC's user name.
static func default_name() -> String:
	if GameSettings.values.lan_name != "":
		return GameSettings.values.lan_name
	var user: String = OS.get_environment("USERNAME")
	if user == "":
		user = OS.get_environment("USER")
	return LanPlayer.clean_name(user)


func _on_lobby_changed() -> void:
	if Lan.is_guest() and _view != View.LOBBY and Lan.my_slot >= 0:
		_show_view(View.LOBBY)
	elif _view == View.LOBBY:
		_refresh_lobby()


func _on_session_ended(reason: String) -> void:
	if _view != View.START:
		_show_view(View.START)
	_status.text = reason


func _on_back_pressed() -> void:
	close()


## The host's Start, the guest's Ready (or Not ready).
func _on_primary_pressed() -> void:
	if Lan.is_host():
		if Lan.can_start():
			Lan.host_start()
	elif Lan.is_guest():
		_ready_now = not _ready_now
		Lan.update_me(_ready_now)
		_refresh_lobby()


# ---------------------------------------------------------------- the lobby

func _refresh_lobby() -> void:
	if _view != View.LOBBY:
		return
	var host: LanPlayer = Lan.player_in(0)
	var lines: PackedStringArray = PackedStringArray()
	for player: LanPlayer in Lan.players:
		var role: String = "host" if player.slot == 0 else ("ready" if player.ready else "not ready yet")
		var you: String = "  (you)" if player.slot == Lan.my_slot else ""
		lines.append("%s%s  ·  %s  ·  %s" % [player.name, you, role, player.gear_text()])
	if Lan.is_host() and Lan.players.size() < LanSession.MAX_PLAYERS:
		lines.append("Waiting for a friend to join... (you can also start alone)")
	_players_label.text = "\n".join(lines)
	_host_rows.visible = Lan.is_host()
	_wind_button.visible = Lan.is_host()
	_guest_summary.visible = Lan.is_guest()
	_lake_time_list.disabled = not chosen_lake
	_conditions_label.text = "Wind and waves: %s" % _conditions_text()
	var me: LanPlayer = Lan.player_in(Lan.my_slot)
	if Lan.is_guest() and me != null:
		_ready_now = me.ready  # the host's record is the one that counts
	_gear_label.text = "Your gear: %s" % (me.gear_text() if me != null else GearChoice.from_settings(GameSettings.values).names_line())
	_back_button.text = "Leave"
	if Lan.is_host():
		var addresses: String = ", ".join(LanSession.local_addresses())
		_title.text = "Your game"
		_hint.text = "Hosting on %s (port %d). Your friend chooses Join a game; if it does not show up there, they type %s." % [
			addresses if addresses != "" else "this PC", LanSession.GAME_PORT, LanSession.local_addresses()[0] if not LanSession.local_addresses().is_empty() else "this PC's address"]
		_primary_button.text = "Start" if Lan.players.size() > 1 else "Start alone"
		_primary_button.disabled = not Lan.can_start()
		if not Lan.can_start() and Lan.players.size() > 1:
			_status.text = "Waiting for your friend to be ready."
		else:
			_status.text = ""
	else:
		_title.text = "%s's game" % (host.name if host != null else "The host")
		_hint.text = "The host chooses the water, the race and the wind. Choose your gear and say you are ready."
		_guest_summary.text = Lan.game.summary()
		_primary_button.text = "Not ready" if _ready_now else "Ready"
		_primary_button.disabled = false
		_status.text = "Waiting for the host to start." if _ready_now else ""


## The wind and waves the game sails: the host's settings, as the guest will sail them.
func _conditions_text() -> String:
	if Lan.game.map == LanGame.Map.LAKE:
		return "the lake's own Maloja wind at %s (the settings' waves)" % LAKE_TIME_NAMES[clampi(_lake_time_index(Lan.game.lake_time_s), 0, LAKE_TIME_NAMES.size() - 1)].get_slice(",", 0)
	var values: SettingsValues = SettingsValues.new()
	Lan.game.apply_conditions(values)
	return values.conditions_text()


static func _lake_time_index(seconds: float) -> int:
	for i: int in LAKE_TIMES_S.size():
		if absf(LAKE_TIMES_S[i] - seconds) < 60.0:
			return i
	return 1


## The host's choices as a LanGame, to the guest at once.
func _send_choice() -> void:
	if not Lan.is_host():
		return
	var choice: LanGame = LanGame.new()
	choice.map = LanGame.Map.LAKE if chosen_lake else LanGame.Map.OPEN_WATER
	choice.race = chosen_race
	choice.course_name = _course_names[clampi(chosen_course, 0, _course_names.size() - 1)] if not _course_names.is_empty() else choice.courses()[0]
	choice.skippers = RacePage.fleet_names(chosen_who, FLEET_SIZES[clampi(chosen_fleet, 0, FLEET_SIZES.size() - 1)])
	choice.prestart_s = COUNTDOWNS_S[clampi(chosen_countdown, 0, COUNTDOWNS_S.size() - 1)]
	choice.laps = LAPS[clampi(chosen_laps, 0, LAPS.size() - 1)]
	choice.level_spread = RaceSetup.LEVEL_CLOSE if chosen_level == 0 else 1.0
	choice.rules = chosen_rules
	choice.shadows = chosen_shadows
	choice.lake_time_s = LAKE_TIMES_S[clampi(chosen_lake_time, 0, LAKE_TIMES_S.size() - 1)]
	Lan.host_set_game(choice)
	_refresh_lobby()


func _fill_courses() -> void:
	var choices: Array[PackedStringArray] = RacePage.course_choices(chosen_lake)
	_course_names = choices[0]
	_course_list.clear()
	for title: String in choices[1]:
		_course_list.add_item(title)
	chosen_course = clampi(chosen_course, 0, _course_names.size() - 1)
	_course_list.select(chosen_course)


func _refresh_found() -> void:
	if _found_list == null:
		return
	_found_list.clear()
	_found_addresses.clear()
	for address: String in Lan.found_games:
		var entry: Dictionary = Lan.found_games[address]
		var full: bool = int(entry.get("players", 0)) >= int(entry.get("max", LanSession.MAX_PLAYERS))
		var state: String = "started" if bool(entry.get("started", false)) else ("full" if full else "open")
		var version: String = String(entry.get("version", "?"))
		var other_version: String = "" if version == LanSession.game_version() else "  ·  version %s (yours is %s)" % [version, LanSession.game_version()]
		_found_list.add_item("%s's game  ·  %s  ·  %s  ·  %s%s" % [entry.get("name", "?"), address, state, entry.get("summary", ""), other_version])
		_found_addresses.append(address)
	if _found_addresses.is_empty():
		_found_list.add_item("No game heard yet... (is the host's lobby open?)")
		_found_list.set_item_disabled(0, true)


# ---------------------------------------------------------------- building the page

func _build() -> void:
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = Vector2(1060.0, 0.0)
	center.add_child(panel)
	var layout: VBoxContainer = VBoxContainer.new()
	layout.add_theme_constant_override("separation", 8)
	panel.add_child(layout)
	_title = _label(layout, "Play with a friend", &"HeaderLabel")
	_hint = _label(layout, FIREWALL_HINT, &"HintLabel")
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.custom_minimum_size = Vector2(1000.0, 0.0)
	_build_start(layout)
	_build_join(layout)
	_build_lobby(layout)
	_status = _label(layout, "", &"HintLabel")
	_status.add_theme_color_override("font_color", Color(1.0, 0.72, 0.3))
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size = Vector2(1000.0, 0.0)
	var buttons: HBoxContainer = HBoxContainer.new()
	layout.add_child(buttons)
	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.add_child(spacer)
	_back_button = _button(buttons, "Back", 180.0, _on_back_pressed)
	_primary_button = _button(buttons, "Start", 220.0, _on_primary_pressed)


func _build_start(layout: VBoxContainer) -> void:
	_start_box = VBoxContainer.new()
	_start_box.add_theme_constant_override("separation", 10)
	layout.add_child(_start_box)
	var row: HBoxContainer = HBoxContainer.new()
	_start_box.add_child(row)
	var name_label: Label = Label.new()
	name_label.text = "Your name"
	name_label.custom_minimum_size = Vector2(NAME_WIDTH, 0.0)
	row.add_child(name_label)
	_name_edit = LineEdit.new()
	_name_edit.text = default_name()
	_name_edit.max_length = 16
	_name_edit.custom_minimum_size = Vector2(300.0, 0.0)
	row.add_child(_name_edit)
	var choices: HBoxContainer = HBoxContainer.new()
	choices.add_theme_constant_override("separation", 16)
	_start_box.add_child(choices)
	_host_button = _button(choices, "Host a game", 300.0, _on_host_pressed)
	_host_button.theme_type_variation = &"BigButton"
	_join_view_button = _button(choices, "Join a game", 300.0, _on_join_view_pressed)
	_join_view_button.theme_type_variation = &"BigButton"
	_label(_start_box, "Host: you choose the water, the race, the wind and the AI fleet, and press Start. Join: your friend's game.", &"HintLabel")


func _build_join(layout: VBoxContainer) -> void:
	_join_box = VBoxContainer.new()
	_join_box.add_theme_constant_override("separation", 10)
	layout.add_child(_join_box)
	_label(_join_box, "Games on your network", &"")
	_found_list = ItemList.new()
	_found_list.custom_minimum_size = Vector2(1000.0, 160.0)
	_found_list.item_activated.connect(_on_found_activated)
	_join_box.add_child(_found_list)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	_join_box.add_child(row)
	var label: Label = Label.new()
	label.text = "Or the host's address"
	label.custom_minimum_size = Vector2(NAME_WIDTH, 0.0)
	row.add_child(label)
	_address_edit = LineEdit.new()
	_address_edit.placeholder_text = "192.168.1.20"
	_address_edit.text = GameSettings.values.lan_address
	_address_edit.custom_minimum_size = Vector2(300.0, 0.0)
	_address_edit.text_submitted.connect(func(_text: String) -> void:
		_found_list.deselect_all()
		_on_join_pressed())
	row.add_child(_address_edit)
	_join_button = _button(row, "Join", 160.0, _on_join_pressed)


func _build_lobby(layout: VBoxContainer) -> void:
	_lobby_box = VBoxContainer.new()
	_lobby_box.add_theme_constant_override("separation", 8)
	layout.add_child(_lobby_box)
	_players_label = _label(_lobby_box, "", &"")
	_players_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_players_label.custom_minimum_size = Vector2(1000.0, 0.0)
	_lobby_box.add_child(HSeparator.new())
	_host_rows = GridContainer.new()
	_host_rows.columns = 4
	_host_rows.add_theme_constant_override("h_separation", 16)
	_host_rows.add_theme_constant_override("v_separation", 4)
	_lobby_box.add_child(_host_rows)
	_add_list("Water", PackedStringArray(["Open water", "Lake Silvaplana"]), 1 if chosen_lake else 0, "The lake loads for a few seconds on both PCs.",
		func(index: int) -> void:
			chosen_lake = index == 1
			chosen_course = 0
			_fill_courses()
			_send_choice())
	_add_list("Game", PackedStringArray(["A race", "Free sailing together"]), 0 if chosen_race else 1, "Free sailing: no course, no AI boards.",
		func(index: int) -> void:
			chosen_race = index == 0
			_send_choice())
	_course_list = _add_list("Course", PackedStringArray(["T1 training loop"]), 0, "", func(index: int) -> void:
		chosen_course = index
		_send_choice())
	_fill_courses()
	var sizes: PackedStringArray = PackedStringArray()
	for size: int in FLEET_SIZES:
		sizes.append(("%d AI boards" % size) if size > 0 else "No AI boards: just the two of you")
	_add_list("AI fleet", sizes, chosen_fleet, "Sailed on the host's PC; 19 or fewer.", func(index: int) -> void:
		chosen_fleet = index
		_send_choice())
	_add_list("Who", RacePage.WHO_NAMES, chosen_who, "", func(index: int) -> void:
		chosen_who = index as RacePage.Who
		_send_choice())
	_add_list("Countdown", COUNTDOWN_NAMES, chosen_countdown, "", func(index: int) -> void:
		chosen_countdown = index
		_send_choice())
	var lap_names: PackedStringArray = PackedStringArray()
	for laps: int in LAPS:
		lap_names.append("%d lap%s" % [laps, "" if laps == 1 else "s"])
	_add_list("Laps", lap_names, chosen_laps, "", func(index: int) -> void:
		chosen_laps = index
		_send_choice())
	_add_list("Level", RacePage.LEVEL_NAMES, chosen_level, "", func(index: int) -> void:
		chosen_level = index
		_send_choice())
	_add_switch("The rules", chosen_rules, "A penalty is a turn or 20 s, for the players too.", func(on: bool) -> void:
		chosen_rules = on
		_send_choice())
	_add_switch("Wind shadows", chosen_shadows, "Every sail's shadow on every board, the players' too.", func(on: bool) -> void:
		chosen_shadows = on
		_send_choice())
	_lake_time_list = _add_list("Lake's time", LAKE_TIME_NAMES, chosen_lake_time, "On Lake Silvaplana only.", func(index: int) -> void:
		chosen_lake_time = index
		_send_choice())
	_guest_summary = _label(_lobby_box, "", &"")
	_guest_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_guest_summary.custom_minimum_size = Vector2(1000.0, 0.0)
	var wind_row: HBoxContainer = HBoxContainer.new()
	wind_row.add_theme_constant_override("separation", 12)
	_lobby_box.add_child(wind_row)
	_conditions_label = _label(wind_row, "", &"HintLabel")
	_conditions_label.custom_minimum_size = Vector2(760.0, 0.0)
	_conditions_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_wind_button = _button(wind_row, "Wind and waves", 220.0, func() -> void: settings_requested.emit())
	var gear_row: HBoxContainer = HBoxContainer.new()
	gear_row.add_theme_constant_override("separation", 12)
	_lobby_box.add_child(gear_row)
	_gear_label = _label(gear_row, "", &"HintLabel")
	_gear_label.custom_minimum_size = Vector2(760.0, 0.0)
	_gear_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_button(gear_row, "Change gear", 220.0, func() -> void: gear_requested.emit())


func _label(parent: Control, text: String, variation: StringName) -> Label:
	var label: Label = Label.new()
	label.text = text
	if variation != &"":
		label.theme_type_variation = variation
	parent.add_child(label)
	return label


func _button(parent: Control, text: String, width: float, action: Callable) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(width, 0.0)
	button.pressed.connect(action)
	parent.add_child(button)
	return button


func _add_list(title: String, items: PackedStringArray, selected: int, hint: String, store: Callable) -> OptionButton:
	_add_name(title)
	var list: OptionButton = OptionButton.new()
	for item: String in items:
		list.add_item(item)
	list.select(clampi(selected, 0, maxi(items.size() - 1, 0)))
	list.fit_to_longest_item = false
	list.clip_text = true
	list.custom_minimum_size = Vector2(CHOICE_WIDTH, 0.0)
	list.tooltip_text = hint
	_host_rows.add_child(list)
	list.item_selected.connect(func(index: int) -> void: store.call(index))
	return list


func _add_switch(title: String, on: bool, hint: String, store: Callable) -> CheckButton:
	_add_name(title)
	var switch: CheckButton = CheckButton.new()
	switch.button_pressed = on
	switch.text = "On" if on else "Off"
	switch.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	switch.tooltip_text = hint
	_host_rows.add_child(switch)
	switch.toggled.connect(func(now_on: bool) -> void:
		switch.text = "On" if now_on else "Off"
		store.call(now_on))
	return switch


func _add_name(title: String) -> void:
	var label: Label = Label.new()
	label.text = title
	label.custom_minimum_size = Vector2(CHOICE_NAME_WIDTH, 0.0)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_host_rows.add_child(label)
