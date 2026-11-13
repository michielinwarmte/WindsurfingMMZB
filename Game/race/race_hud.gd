class_name RaceHud
extends Control
## The race on the screen (RACING_PLAN.md, 9A), made for racing rather than for reading the
## physics, in the menus' look (HudStyle; Max, 3 November 2026: the old block looked like the
## physics panel), spread over the screen the way racing games and sailing apps do (Max, 6 November
## 2026: "in the ui everything is in the left top corner, make it more over the whole screen"):
## - top middle, the race card: the place and the race clock large (in the countdown "Start in"
##   and the time to the gun), the next mark with its distance and which way to turn for it, and
##   room for two more lines (set_card_line(): the LAN race director's next start and its news);
## - under it the countdown large, a split for a few seconds at every rounding, the warnings for
##   over the line early and the wrong side of a mark;
## - down the right side, under the compass, the standings: place, name, where each board is going,
##   its gap to you at the last mark you both rounded; as many lines as fit above the small map,
##   the leaders and the boards around you when the fleet is bigger (fleet_rows());
## - bottom left, the speed, the tack and the state, and the wind (the free-sailing card's place);
## - the results when you finish or the race is over, between the race card and the gauges, in as
##   many columns and as small a text as they need to stay inside the window (_fit_results()).
## The push slider is the HUD's gauge at the bottom (PushGauge, for the board on the screen).
## RaceRunner updates this every frame from the race (RaceSim) and the player's telemetry; the HUD's
## own card and panel are hidden meanwhile (Hud.set_race_mode), F1 brings the panel back.
## While spectating (set_watching) the cards are about the board the camera follows, with its name
## and place on a line above ("Spectating Hana, 3rd"), and the standings mark that board instead of
## "you". A LAN player who has finished and watches the others keeps the finish list (results_wanted).
## Laid out for a window 720 pixels high, like the HUD it is part of (hud.gd: any window size).

const SPLIT_SHOWN_S: float = 4.0
const GO_SHOWN_S: float = 2.0
## The fleet's lines and the results table are worked out a few times a second, not every frame.
const FLEET_REFRESH_S: float = 0.25
## The fleet table's lines: as many as fit under the compass and above the small map, between these.
## With more boards than lines, the leaders and the boards around you (fleet_rows()).
const FLEET_ROWS: int = 9
const FLEET_MIN_ROWS: int = 4
const FLEET_MAX_ROWS: int = 13
## The leaders always shown in a big fleet (fewer when the table has fewer than seven lines).
const FLEET_LEADERS: int = 3
const FLEET_FONT_SIZE: int = 15
const CARD_WIDTH: float = 440.0
## The race card's extra lines (set_card_line()).
const CARD_LINES: int = 2
## The results' text sizes, tried from the biggest down until the table fits (_fit_results()), and
## how many columns at most; the gap between the columns.
const RESULTS_FONT_SIZES: PackedInt32Array = [17, 15, 13, 11]
const RESULTS_MAX_COLUMNS: int = 3
const RESULTS_COLUMN_GAP: float = 28.0
## The results' table as last laid out, and the room it was laid out for (laid out again only when
## either changes).
var _results_lines: PackedStringArray = PackedStringArray()
var _results_room: Rect2 = Rect2()
const COUNTDOWN_COLOR: Color = Color(1.0, 0.9, 0.5)
const WARNING_COLOR: Color = Color(1.0, 0.35, 0.3)
const TEXT_COLOR: Color = HudStyle.TEXT_COLOR
const COMPASS_NAMES: PackedStringArray = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]

## The race card at the top in the middle.
var _card: PanelContainer
## The name of the board watched while spectating, above the place (hidden otherwise).
var _title: Label
## The card's big line: the place ("2nd", or "Start" in the countdown), "of 8", the clock.
var _place: Label
var _of: Label
var _clock: Label
## The next mark (or the line, or the finish), its distance and the turn to it.
var _next: Label
## The card's extra lines under the next mark (set_card_line()), hidden while empty.
var _card_lines: Array[Label] = []
## The card at the bottom left: the speed large, then the tack and the state, then the wind.
var _speed_card: PanelContainer
var _speed: Label
var _status: Label
var _wind: Label
## Whether the speed card shows a fall now (its line in orange).
var _fall_shown: bool = false
## The standings: one row of four labels per line (place, name, going, gap).
var _fleet_card: PanelContainer
var _fleet_cells: Array[Label] = []
var _countdown: Label
var _split: Label
var _warning: Label
## Where the countdown, the split and the warning sit, from the top: under the race card.
var _centre_top: float = -1.0
## How long the penalty's reason is shown large after a breach, seconds (then the shorter line).
const PENALTY_WARNING_S: float = 8.0
var _results: PanelContainer
var _results_columns: HBoxContainer
## The results' columns (as many as RESULTS_MAX_COLUMNS; the first holds the title).
var _results_texts: Array[Label] = []
## The board watched while spectating ("" when racing yourself), and whether the camera follows the
## leader by itself.
var _watching: String = ""
## The title without the spectator's keys ("Hana, 3rd"): the TV screen of a watched race (WatchMode).
var plain_title: bool = false:
	set(value):
		if value != plain_title:
			plain_title = value
			_watching = ""  # the next set_watching() writes the title again
var _follows_leader: bool = true
var _watch_place: String = ""
## The results stay on the screen while this is set, whichever board the cards are about: the
## player's own race is over and the camera watches the others (RaceRunner, RaceMirror).
var results_wanted: bool = false
## How many splits have been shown, so a new one is noticed.
var _splits_seen: int = 0
var _split_until_s: float = -1.0
var _fleet_refresh_at_s: float = -INF
## The time trial (GP4): the best kept for this course and wind (-1 without one) and its splits,
## and at the finish whether this run beat it and what the best was before.
var _time_trial: bool = false
var _best_s: float = -1.0
var _best_splits: PackedFloat32Array = PackedFloat32Array()
var _record_is_best: bool = false
var _record_best_before_s: float = -1.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_race_card()
	_build_speed_card()
	_build_fleet_card()
	# The middle of the screen, under the race card (_place_centre_labels()).
	_countdown = _centre_label(HudStyle.sans(800), 96, COUNTDOWN_COLOR, 130.0)
	_split = _centre_label(HudStyle.sans(700), 26, COUNTDOWN_COLOR, 34.0)
	_warning = _centre_label(HudStyle.sans(700), 26, WARNING_COLOR, 34.0)
	# The results: across the middle at the top, under the race card (_fit_results() places them). The
	# offsets are set with the anchors: set_anchors_preset() alone kept the panel's corner where it was
	# made, the window's top left corner, and the table grew around it out of the window (Max,
	# 6 November 2026: "ui of the finishing leaderboard is out of frame").
	_results = PanelContainer.new()
	_results.name = "Results"
	_results.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_results.add_theme_stylebox_override("panel", HudStyle.card(16.0))
	add_child(_results)
	_results.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_results.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_results.grow_vertical = Control.GROW_DIRECTION_END
	_results_columns = HBoxContainer.new()
	_results_columns.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_results_columns.add_theme_constant_override("separation", roundi(RESULTS_COLUMN_GAP))
	_results.add_child(_results_columns)
	for i: int in RESULTS_MAX_COLUMNS:
		var column: Label = HudStyle.label(HudStyle.mono(700), RESULTS_FONT_SIZES[0])
		_results_columns.add_child(column)
		_results_texts.append(column)
	reset()
	_place_centre_labels()


## The race card, anchored to the top's middle, growing downward as its lines need.
func _build_race_card() -> void:
	_card = _make_card()
	_card.name = "RaceCard"
	add_child(_card)
	_card.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_card.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_card.offset_left = 0.0
	_card.offset_right = 0.0
	_card.offset_top = 10.0
	_card.offset_bottom = 10.0
	_card.custom_minimum_size.x = CARD_WIDTH
	_card.resized.connect(_place_centre_labels)
	var lines: VBoxContainer = _lines_box(_card)
	_title = HudStyle.label(HudStyle.sans(700), 16, HudStyle.HIGHLIGHT_COLOR)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.hide()
	lines.add_child(_title)
	var top: HBoxContainer = HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_theme_constant_override("separation", 8)
	lines.add_child(top)
	_place = HudStyle.label(HudStyle.sans(800), 38)
	top.add_child(_place)
	_of = HudStyle.label(HudStyle.sans(500), 18, HudStyle.DIM_COLOR)
	_of.size_flags_vertical = Control.SIZE_SHRINK_END
	top.add_child(_of)
	_clock = HudStyle.label(HudStyle.mono(700), 34)
	_clock.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_clock.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(_clock)
	_next = HudStyle.label(HudStyle.sans(600), 20, HudStyle.ACCENT_COLOR)
	lines.add_child(_next)
	# The LAN race director's lines go here (set_card_line()): its next start, a short message.
	for i: int in CARD_LINES:
		var line: Label = HudStyle.label(HudStyle.sans(600), 17, HudStyle.DIM_COLOR)
		line.hide()
		lines.add_child(line)
		_card_lines.append(line)


## The card at the bottom left: the speed, the tack and the state, the wind.
func _build_speed_card() -> void:
	_speed_card = _make_card()
	_speed_card.name = "SpeedCard"
	add_child(_speed_card)
	Hud.place_bottom_left(_speed_card)
	var lines: VBoxContainer = _lines_box(_speed_card)
	_speed = HudStyle.label(HudStyle.sans(700), 22)
	lines.add_child(_speed)
	_status = HudStyle.label(HudStyle.sans(500), 16)
	lines.add_child(_status)
	_wind = HudStyle.label(HudStyle.sans(500), 15, HudStyle.DIM_COLOR)
	lines.add_child(_wind)


## The standings down the right side, under the compass (Hud.RIGHT_COLUMN_TOP).
func _build_fleet_card() -> void:
	_fleet_card = _make_card()
	_fleet_card.name = "Standings"
	add_child(_fleet_card)
	_fleet_card.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_fleet_card.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_fleet_card.offset_left = -Hud.MARGIN
	_fleet_card.offset_right = -Hud.MARGIN
	_fleet_card.offset_top = Hud.RIGHT_COLUMN_TOP
	_fleet_card.offset_bottom = Hud.RIGHT_COLUMN_TOP
	var grid: GridContainer = GridContainer.new()
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 1)
	_fleet_card.add_child(grid)
	for row: int in FLEET_MAX_ROWS:
		for column_index: int in 4:
			var cell: Label = HudStyle.label(HudStyle.mono(700) if column_index == 0 or column_index == 3 else HudStyle.sans(600 if column_index == 1 else 500), FLEET_FONT_SIZE)
			if column_index == 3:
				cell.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
				cell.custom_minimum_size.x = 76.0
			grid.add_child(cell)
			_fleet_cells.append(cell)


func _make_card() -> PanelContainer:
	var card: PanelContainer = PanelContainer.new()
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_theme_stylebox_override("panel", HudStyle.card())
	return card


func _lines_box(card: PanelContainer) -> VBoxContainer:
	var lines: VBoxContainer = VBoxContainer.new()
	lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lines.add_theme_constant_override("separation", 2)
	card.add_child(lines)
	return lines


## A centred label across the screen, `height` pixels high (placed by _place_centre_labels()).
func _centre_label(font: Font, size: int, colour: Color, height: float) -> Label:
	var label: Label = HudStyle.label(font, size, colour)
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.7))
	label.add_theme_constant_override("outline_size", 5)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(label)
	label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	label.offset_left = -450.0
	label.offset_right = 450.0
	label.offset_bottom = height
	return label


## The countdown, the split and the warning just under the race card (it grows with its lines).
func _place_centre_labels() -> void:
	if _countdown == null:
		return
	var top: float = _card.offset_top + _card.size.y + 8.0
	if is_equal_approx(top, _centre_top):
		return
	_centre_top = top
	for placed: Array in [[_countdown, 0.0, 130.0], [_split, 134.0, 34.0], [_warning, 170.0, 34.0]]:
		var label: Label = placed[0]
		label.offset_top = top + float(placed[1])
		label.offset_bottom = label.offset_top + float(placed[2])


## One of the race card's extra lines under the next mark (index 0 or 1): the LAN race director's
## "Next start in 1:30" and its short news. An empty text hides the line. Cheap to call every frame:
## nothing is laid out again when the text and the colour are the same.
func set_card_line(index: int, text: String, colour: Color = HudStyle.DIM_COLOR) -> void:
	var line: Label = _card_lines[index]
	if line.text == text and line.visible == (text != "") and line.get_theme_color("font_color") == colour:
		return
	line.text = text
	line.visible = text != ""
	line.add_theme_color_override("font_color", colour)


## The race card's extra line's text ("" when hidden).
func card_line(index: int) -> String:
	return _card_lines[index].text if _card_lines[index].visible else ""


## A new race: nothing shown yet. (The race card's extra lines are the LAN race director's: they stay.)
func reset() -> void:
	_splits_seen = 0
	_split_until_s = -1.0
	_fleet_refresh_at_s = -INF  # the race clock reads negative in the countdown: the first frame refreshes
	_countdown.hide()
	_split.hide()
	_warning.hide()
	_results.hide()
	_results_lines = PackedStringArray()
	_place.text = ""
	_of.text = ""
	_clock.text = ""
	_next.text = ""
	_speed.text = ""
	_status.text = ""
	_wind.text = ""
	for cell: Label in _fleet_cells:
		cell.text = ""


## Spectating: the name of the board the camera follows, its place (watch_place_text()), and
## whether it follows the leader by itself (Tab: by hand). An empty name: racing yourself, no title.
func set_watching(board_name: String, follows_leader: bool, place_text: String = "") -> void:
	if board_name == _watching and follows_leader == _follows_leader and place_text == _watch_place:
		return
	var new_board: bool = board_name != _watching
	_watching = board_name
	_follows_leader = follows_leader
	_watch_place = place_text
	_title.visible = not board_name.is_empty()
	_title.text = watch_title(board_name, place_text, follows_leader, plain_title)
	if new_board:
		# A new board: its own splits from now on, and the fleet list marks it at once.
		_splits_seen = -1
		_fleet_refresh_at_s = -INF


## The line above the race card while spectating: "Spectating Hana, 3rd   ·   Tab: next   L: the leader";
## plain (the TV screen of a watched race, WatchMode): "Hana, 3rd".
static func watch_title(board_name: String, place_text: String, follows_leader: bool, plain: bool = false) -> String:
	var who: String = board_name if place_text.is_empty() else "%s, %s" % [board_name, place_text]
	if plain:
		return who
	var keys: String = "the leader   ·   Tab: next board" if follows_leader else "Tab: next   L: the leader"
	return "Spectating %s   ·   %s" % [who, keys]


## A watched board's place for the title: "3rd", "finished 2nd" or "retired".
static func watch_place_text(race: RaceSim, index: int) -> String:
	if race.is_retired(index):
		return "retired"
	if race.is_finished(index):
		return "finished %s" % ordinal(race.place(index))
	return ordinal(race.place(index))


## What the race says about board `index` (the player, or the board watched), and that board's
## telemetry, every frame.
## shadow_deficit: the share of the wind the other sails' shadows take from this board right now
## (RaceRunner.shadow_deficit(); 0: none), shown on the wind line when it is more than a few percent.
## rules: the judge (RaceRules), for the penalty warning and the penalty carried; null for none.
func update_from(race: RaceSim, index: int, t: Telemetry, shadow_deficit: float = 0.0, rules: RaceRules = null) -> void:
	var state: String = "   ·   planing" if t.is_planing else ("   ·   luffing" if t.is_luffing else "")
	var fallen: bool = t.sailor_state == 1
	if fallen:
		state = "   ·   %s: waterstart in %d s (R: now)" % [t.fall_kind, ceili(t.waterstart_in_s)]
	var here: Vector2 = Vector2(t.position.x, t.position.z)
	var distance_m: float = race.distance_to_next_m(index)
	var turn: String = turn_text(relative_bearing_deg(here, race.next_target(index), t.heading_deg)).replace(" deg ", "° ")
	_speed.text = "%.1f km/h   ·   %.1f kt" % [t.speed_kmh, t.speed_kt]
	_status.text = "%s tack%s" % ["starboard" if t.twa_deg >= 0.0 else "port", state]
	if fallen != _fall_shown:
		_fall_shown = fallen
		_status.add_theme_color_override("font_color", HudStyle.HIGHLIGHT_COLOR if fallen else TEXT_COLOR)
	# Shown from 2 % (3 % with the 30 % shadow before the wind tunnel, PH15; it now takes at most 7.5 %).
	var shadow: String = "   ·   in a wind shadow: %d %% less" % roundi(100.0 * shadow_deficit) if shadow_deficit >= 0.02 else ""
	_wind.text = "wind %.0f kt from %s%s" % [t.tws_10m_kt, compass_name(t.wind_from_bearing_deg), shadow]
	if race.phase() == RaceSim.Phase.PRE_START:
		var left: float = race.countdown_s()
		_countdown.text = "%d" % ceili(left)
		_countdown.show()
		_place.text = "Start"
		_of.text = "in"
		_clock.text = clock(left)
		_next.text = "The line   %d m   %s" % [roundi(distance_m), turn]
	else:
		var time_s: float = race.race_time_s()
		_countdown.text = "GO!"
		_countdown.visible = time_s < GO_SHOWN_S
		if race.is_finished(index):
			if _time_trial:
				_place.text = "Finished"
				_of.text = ""
				_clock.text = clock(race.finish_time_s(index) + race.time_penalty_s(index))
				_next.text = time_trial_finish_text(race.finish_time_s(index) + race.time_penalty_s(index), _record_is_best, _record_best_before_s)
			else:
				_place.text = ordinal(race.place(index))
				_of.text = "of %d" % race.board_count()
				_clock.text = clock(race.finish_time_s(index))
				_next.text = "Finished"
		else:
			_next.text = "Next   %s   %d m   %s" % [race.next_step_name(index), roundi(distance_m), turn]
			_clock.text = clock(time_s)
			if _time_trial:
				_place.text = "Time trial"
				_of.text = ("best %s" % clock(_best_s)) if _best_s >= 0.0 else "no best yet"
			else:
				_place.text = ordinal(race.place(index))
				_of.text = "of %d" % race.board_count()
	var refresh: bool = race.clock_s() >= _fleet_refresh_at_s
	if refresh:
		if not _time_trial:
			_fill_fleet(race, index, "you" if _watching.is_empty() else "camera")
		_fleet_refresh_at_s = race.clock_s() + FLEET_REFRESH_S
	_show_split(race, index)
	var penalised_s: float = race.race_time_s() - rules.last_breach_s(index) if rules != null else INF
	if race.is_ocs(index):
		_warning.text = "Over the line early: go back behind it"
		_warning.show()
	elif race.wrong_side_warning(index):
		_warning.text = "Wrong side of the mark"
		_warning.show()
	elif rules != null and penalised_s < PENALTY_WARNING_S and rules.penalties(index) > 0:
		_warning.text = "Penalty: %s. Turn a full circle, or +%.0f s at the finish" % [rules.breach_text(index), RaceRules.TIME_PENALTY_S]
		_warning.show()
	elif rules != null and rules.penalties(index) > 0 and not race.is_finished(index):
		_warning.text = "A penalty stands: turn a full circle, or +%.0f s" % rules.time_penalty_s(index)
		_warning.show()
	else:
		_warning.hide()
	if race.phase() == RaceSim.Phase.FINISHED or race.is_finished(index) or results_wanted:
		if refresh or not _results.visible:
			_show_results(time_trial_table(race, index) if _time_trial else results_table(race))
		_results.show()
		# The results say all the standings say: one table, not two side by side; and the finish time
		# is on it and on the race card, so the split and the countdown give it the room.
		_fleet_card.hide()
		_split.hide()
		_countdown.hide()
	else:
		_results.hide()


## The results (the table's lines, its title first): laid out to fit the room under the race card
## (_fit_results()), again when the table or the room changes.
func _show_results(text: String) -> void:
	var lines: PackedStringArray = text.split("\n")
	var room: Rect2 = results_room()
	if lines == _results_lines and room.is_equal_approx(_results_room):
		return
	_results_lines = lines
	_results_room = room
	_fit_results(lines, room)


## The space the results may fill, in the HUD's pixels: across the middle from under the race card down
## to the gauges at the bottom, as wide as the window less its margins and, where it reaches down past
## the top of the small map in the corner, less the small map on either side.
## (Its height and width: room.size; room.position.y is its top.)
func results_room() -> Rect2:
	var layer: Hud = _layer()
	var screen: Vector2 = size if layer == null else layer.screen_size()
	var top: float = _card.offset_top + _card.get_combined_minimum_size().y + 10.0
	var bottom: float = screen.y - 180.0 if layer == null else layer.bottom_middle_top() - 10.0
	return Rect2(Hud.MARGIN, top, screen.x - 2.0 * Hud.MARGIN, maxf(bottom - top, 100.0))


## The biggest text, in the fewest columns, that keeps the table inside results_room(): first as wide
## as the room where it ends above the small map, else narrow enough to pass beside it. The smallest
## text in the most columns when nothing fits (a fleet far beyond the LAN's 8 players and 20 AI boards).
func _fit_results(lines: PackedStringArray, room: Rect2) -> void:
	var layer: Hud = _layer()
	var map_top: float = room.end.y if layer == null else layer.right_column_bottom()
	var beside_map: float = room.size.x if layer == null else room.size.x - 2.0 * (layer.mini_map_width() + 12.0)
	for font_size: int in RESULTS_FONT_SIZES:
		for columns: int in RESULTS_MAX_COLUMNS:
			_lay_out_results(lines, columns + 1, font_size)
			var table: Vector2 = _results.get_combined_minimum_size()
			var fits_above_map: bool = table.x <= room.size.x and room.position.y + table.y <= map_top
			var fits_beside_map: bool = table.x <= beside_map and table.y <= room.size.y
			if fits_above_map or fits_beside_map:
				_place_results(room, table)
				return
	_place_results(room, _results.get_combined_minimum_size())


## The table's lines in `columns` columns at `font_size`: the first column has the title, the others
## start level with its first board (the title's two lines left blank).
func _lay_out_results(lines: PackedStringArray, columns: int, font_size: int) -> void:
	var title: int = mini(2, lines.size())
	var rows: int = ceili(float(lines.size() - title) / float(columns))
	for i: int in RESULTS_MAX_COLUMNS:
		var column: Label = _results_texts[i]
		column.add_theme_font_size_override("font_size", font_size)
		var from: int = title + i * rows
		column.visible = i < columns and (i == 0 or from < lines.size())
		if not column.visible:
			column.text = ""
			continue
		var part: PackedStringArray = lines.slice(from, mini(from + rows, lines.size()))
		column.text = "\n".join(lines.slice(0, title) + part) if i == 0 else "\n".repeat(title) + "\n".join(part)
	# The panel takes its new size at once (it does not shrink by itself when the text gets smaller).
	_results.reset_size()


## The table centred across the room, in the middle of its height.
func _place_results(room: Rect2, table: Vector2) -> void:
	var top: float = room.position.y + maxf((room.size.y - table.y) * 0.5, 0.0)
	_results.offset_left = 0.0
	_results.offset_right = 0.0
	_results.offset_top = top
	_results.offset_bottom = top


## The results' lines as laid out now, column after column (for the tests).
func results_columns() -> PackedStringArray:
	var shown: PackedStringArray = PackedStringArray()
	for column: Label in _results_texts:
		if column.visible:
			shown.append(column.text)
	return shown


## The standings: the rows fleet_rows() picks, as many as fit (fleet_room_rows()), the board followed
## (`player`) in orange with `mark` in place of a gap.
func _fill_fleet(race: RaceSim, player: int, mark: String) -> void:
	var room: int = fleet_room_rows()
	var rows: Array[int] = fleet_rows(race.race_order(), player, room)
	_fleet_card.visible = rows.size() > 1 and not _results.visible
	for row: int in FLEET_MAX_ROWS:
		var cells: Array[Label] = _fleet_cells.slice(row * 4, row * 4 + 4)
		var board: int = rows[row] if row < rows.size() else -2
		var texts: PackedStringArray = PackedStringArray(["", "", "", ""])
		if board == -1:
			texts = PackedStringArray(["", "...", "", ""])
		elif board >= 0:
			var going: String = "finished" if race.is_finished(board) else ("retired" if race.is_retired(board) else "to " + race.next_step_name(board))
			texts = PackedStringArray(["%d" % race.place(board), race.board_name(board).left(14), going,
				mark if board == player else gap_between(race, board, player)])
		var colour: Color = HudStyle.HIGHLIGHT_COLOR if board == player else TEXT_COLOR
		for i: int in 4:
			cells[i].text = texts[i]
			cells[i].visible = board != -2
			cells[i].add_theme_color_override("font_color", HudStyle.DIM_COLOR if i == 2 and board != player else colour)


## How many lines of the standings fit between the compass and the small map (the HUD says where
## the map begins: Hud.right_column_bottom()), from FLEET_MIN_ROWS to FLEET_MAX_ROWS.
func fleet_room_rows() -> int:
	var layer: Hud = _layer()
	if layer == null:
		return FLEET_ROWS
	var style: StyleBox = _fleet_card.get_theme_stylebox("panel")
	var room: float = layer.right_column_bottom() - Hud.RIGHT_COLUMN_TOP - style.get_minimum_size().y
	var row_px: float = HudStyle.sans(600).get_height(FLEET_FONT_SIZE) + 1.0
	return clampi(floori(room / row_px), FLEET_MIN_ROWS, FLEET_MAX_ROWS)


## The HUD this is part of: its parent, or its parent's parent (Hud.add_part() puts it in the HUD's
## scaled screen); null outside a HUD.
func _layer() -> Hud:
	var parent: Node = get_parent()
	if parent is Hud:
		return parent as Hud
	return parent.get_parent() as Hud if parent != null else null


## The boards the fleet table shows, in race order: all of them up to `rows`; in a bigger fleet the
## leaders (FLEET_LEADERS; in a short table fewer, so at least three lines are about you), then -1
## for the boards left out, then the boards around `player` (or the first `rows` when the player is
## among them).
static func fleet_rows(order: Array[int], player: int, rows: int) -> Array[int]:
	if order.size() <= rows:
		return order
	var at: int = order.find(player)
	if at < rows - 1:
		return order.slice(0, rows)
	var leaders: int = clampi(rows - 4, 1, FLEET_LEADERS)
	var around: int = rows - leaders - 1
	var start: int = clampi(at - floori(around * 0.5), leaders, order.size() - around)
	var shown: Array[int] = order.slice(0, leaders)
	shown.append(-1)
	shown.append_array(order.slice(start, start + around))
	return shown


## The time at a step just completed, for a few seconds.
func _show_split(race: RaceSim, index: int) -> void:
	var splits: PackedFloat32Array = race.splits_s(index)
	if _splits_seen < 0:
		# A board just picked by the spectator: its old splits are not news.
		_splits_seen = splits.size()
	if splits.size() > _splits_seen:
		_splits_seen = splits.size()
		var step: RaceStep = race.steps()[_splits_seen - 1]
		var gap: String = TimeTrialRecords.gap_text(splits, _best_splits) if _time_trial else ""
		_split.text = "%s  %s%s" % [step.name, clock(splits[_splits_seen - 1]), ("   best %s" % gap) if gap != "" else ""]
		_split.show()
		_split_until_s = race.clock_s() + SPLIT_SHOWN_S
	if _split_until_s >= 0.0 and race.clock_s() > _split_until_s:
		_split.hide()


## The fleet in race order: place, name, where it is going, and its gap to the player (gap_between();
## negative: ahead of the player); the player's own line says `mark`
## ("you", or "<< camera" for the board watched while spectating). The race works its order out once
## per tick (RaceSim.race_order), so this costs a line per board, not a sort per line.
static func fleet_text(race: RaceSim, player: int, mark: String = "you") -> String:
	var lines: PackedStringArray = PackedStringArray()
	for i: int in race.race_order():
		var going: String = "finished" if race.is_finished(i) else ("retired" if race.is_retired(i) else "to " + race.next_step_name(i))
		var gap: String = mark if i == player else gap_between(race, i, player)
		lines.append("%d. %-12s %-16s %s" % [race.place(i), race.board_name(i).left(12), going, gap])
	return "\n".join(lines)


## A board's gap to the player (or the board watched): once the race ranks by time (the smart order,
## RaceSim.ranks_by_time()), the difference of their expected finishes (RaceSim.expected_finish_s():
## the polar's time still to sail, with the laylines, and the standing penalty; the finish time once
## in): "-12.3 s" ahead of the player, "+12.3 s" behind. Otherwise (the countdown, a LAN guest's copy
## of the race, a race that does not know the wind) at the last step both completed (gap_text()).
static func gap_between(race: RaceSim, board: int, player: int) -> String:
	if player < 0:
		return ""
	var theirs: float = race.expected_finish_s(board)
	var yours: float = race.expected_finish_s(player)
	if not is_nan(theirs) and not is_nan(yours):
		return "%+.1f s" % (theirs - yours)
	return gap_text(race.splits_s(board), race.splits_s(player))


## A board's gap to the player at the last step both have completed: "-12.3 s" when it got there
## first, "+12.3 s" when the player did; empty before either has completed one.
static func gap_text(theirs: PackedFloat32Array, yours: PackedFloat32Array) -> String:
	var both: int = mini(theirs.size(), yours.size())
	if both == 0:
		return ""
	var gap_s: float = theirs[both - 1] - yours[both - 1]
	return "%+.1f s" % gap_s


## The bearing to a point relative to the heading: negative to port (left), positive to starboard.
static func relative_bearing_deg(from: Vector2, to: Vector2, heading_deg: float) -> float:
	return wrapf(Course.bearing_deg(from, to) - heading_deg, -180.0, 180.0)


## "12 deg to port", "ahead" within a few degrees.
static func turn_text(relative_deg: float) -> String:
	if absf(relative_deg) < 3.0:
		return "ahead"
	return "%d deg to %s" % [roundi(absf(relative_deg)), "port" if relative_deg < 0.0 else "starboard"]


## Place, name, time and gap for every board; the boards still sailing with their progress.
## The time trial (GP4): the best to beat and its splits, from the runner's records; set after
## reset() at every start.
func set_time_trial(on: bool, best_s: float, best_splits: PackedFloat32Array) -> void:
	_time_trial = on
	_best_s = best_s
	_best_splits = best_splits
	_record_is_best = false
	_record_best_before_s = -1.0
	_fleet_card.visible = not on


## The time trial's finish: whether this run is the new best, and the best before it.
func set_record(is_best: bool, best_before_s: float) -> void:
	_record_is_best = is_best
	_record_best_before_s = best_before_s


## The time trial's line while racing: the clock and the best to beat.
static func time_trial_race_text(time_s: float, best_s: float) -> String:
	return "time trial   %s   %s" % [clock(time_s), ("best %s" % clock(best_s)) if best_s >= 0.0 else "no best yet"]


## The time trial's line at the finish: the time, and how it stands against the best.
static func time_trial_finish_text(time_s: float, is_best: bool, best_before_s: float) -> String:
	if is_best:
		if best_before_s < 0.0:
			return "finished in %s   your first time here: the one to beat" % clock(time_s)
		return "finished in %s   a new best! (was %s)" % [clock(time_s), clock(best_before_s)]
	return "finished in %s   %+.1f s on your best %s" % [clock(time_s), time_s - best_before_s, clock(best_before_s)]


## The time trial's results: the finish against the best, then every step's split with its gap to
## the best run's.
func time_trial_table(race: RaceSim, index: int) -> String:
	var lines: PackedStringArray = PackedStringArray(["  Time trial", ""])
	lines.append("  " + time_trial_finish_text(race.finish_time_s(index) + race.time_penalty_s(index), _record_is_best, _record_best_before_s))
	if race.time_penalty_s(index) > 0.0:
		lines.append("  (%.0f s of penalty included)" % race.time_penalty_s(index))
	lines.append("")
	var splits: PackedFloat32Array = race.splits_s(index)
	var steps: Array[RaceStep] = race.steps()
	for i: int in splits.size():
		var gap: String = TimeTrialRecords.gap_text(splits.slice(0, i + 1), _best_splits)
		lines.append("  %-16s %s%s" % [steps[i].name if i < steps.size() else "", clock(splits[i]), ("   best %s" % gap) if gap != "" else ""])
	lines.append("")
	lines.append("  R: again     Esc: menu")
	return "\n".join(lines)


static func results_table(race: RaceSim) -> String:
	var lines: PackedStringArray = PackedStringArray(["  Results", ""])
	for result: RaceResult in race.results():
		if result.finished:
			var penalty: String = "   (%.0f s penalty)" % result.penalty_s if result.penalty_s > 0.0 else ""
			lines.append("  %d. %-14s %s   +%s%s" % [result.place, result.name, clock(result.finish_time_s), clock(result.gap_s), penalty])
		elif result.retired:
			lines.append("  %d. %-14s retired" % [result.place, result.name])
		else:
			lines.append("  %d. %-14s sailing, %d of %d" % [result.place, result.name, result.steps_done, result.steps_total])
	lines.append("")
	lines.append("  R: race again     Esc: menu")
	return "\n".join(lines)


static func clock(seconds: float) -> String:
	if seconds < 0.0:
		return "-"
	return "%d:%04.1f" % [int(seconds / 60.0), fmod(seconds, 60.0)]


static func ordinal(place: int) -> String:
	match place:
		1:
			return "1st"
		2:
			return "2nd"
		3:
			return "3rd"
	return "%dth" % place


## N, NE, E, ... for a bearing (where the wind comes from).
static func compass_name(bearing_deg: float) -> String:
	return COMPASS_NAMES[wrapi(roundi(bearing_deg / 45.0), 0, 8)]
