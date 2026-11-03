class_name RaceHud
extends Control
## The race on the screen (RACING_PLAN.md, 9A), made for racing rather than for reading the
## physics, in the menus' look (HudStyle; Max, 3 November 2026: the old block looked like the
## physics panel). At the top left a card with the place and the race clock large, the next mark
## with its distance and which way to turn for it, and the speed and the wind small; under it the
## fleet as a table (place, name, where each board is going, its gap to you at the last mark you
## both rounded; the leaders and the boards around you when the fleet is big). The countdown large
## in the middle; a split for a few seconds at every rounding; the warnings for over the line early
## and the wrong side of a mark; and the results when you finish or the race is over. The push
## slider is the HUD's gauge at the bottom (PushGauge, for the board on the screen). RaceRunner
## updates this every frame from the race (RaceSim) and the player's telemetry; the HUD's own
## telemetry strip and panel are hidden meanwhile (Hud.set_race_mode), F1 brings the panel back.
## While spectating (set_watching) the card is about the board the camera follows, with its name
## on a line above, and the fleet marks that board instead of "you".

const SPLIT_SHOWN_S: float = 4.0
const GO_SHOWN_S: float = 2.0
## The fleet's lines and the results table are worked out a few times a second, not every frame.
const FLEET_REFRESH_S: float = 0.25
## The most lines the fleet table shows: with more boards, the leaders and the boards around you.
const FLEET_ROWS: int = 9
## The leaders always shown in a big fleet.
const FLEET_LEADERS: int = 3
const CARD_WIDTH: float = 380.0
const COUNTDOWN_COLOR: Color = Color(1.0, 0.9, 0.5)
const WARNING_COLOR: Color = Color(1.0, 0.35, 0.3)
const TEXT_COLOR: Color = HudStyle.TEXT_COLOR
const COMPASS_NAMES: PackedStringArray = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]

## The name of the board watched while spectating, above the place (hidden otherwise).
var _title: Label
## The card's big line: the place ("2nd", or "Start" in the countdown), "of 8", the clock.
var _place: Label
var _of: Label
var _clock: Label
## The next mark (or the line, or the finish), its distance and the turn to it.
var _next: Label
## Small: the speed, the tack and the state; the wind; the time trial's best.
var _status: Label
## The fleet table: one row of four labels per line (place, name, going, gap).
var _fleet_card: PanelContainer
var _fleet_cells: Array[Label] = []
var _countdown: Label
var _split: Label
var _warning: Label
## How long the penalty's reason is shown large after a breach, seconds (then the shorter line).
const PENALTY_WARNING_S: float = 8.0
var _results: PanelContainer
var _results_text: Label
## The board watched while spectating ("" when racing yourself), and whether the camera follows the
## leader by itself.
var _watching: String = ""
var _follows_leader: bool = true
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
	# The top-left column: the race card, the fleet card under it.
	var column: VBoxContainer = VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 8)
	column.position = Vector2(16.0, 12.0)
	add_child(column)
	var card: PanelContainer = _card()
	column.add_child(card)
	var lines: VBoxContainer = VBoxContainer.new()
	lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lines.add_theme_constant_override("separation", 2)
	card.add_child(lines)
	_title = HudStyle.label(HudStyle.sans(700), 16, HudStyle.HIGHLIGHT_COLOR)
	_title.hide()
	lines.add_child(_title)
	var top: HBoxContainer = HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_theme_constant_override("separation", 8)
	lines.add_child(top)
	_place = HudStyle.label(HudStyle.sans(800), 36)
	top.add_child(_place)
	_of = HudStyle.label(HudStyle.sans(500), 18, HudStyle.DIM_COLOR)
	_of.size_flags_vertical = Control.SIZE_SHRINK_END
	top.add_child(_of)
	_clock = HudStyle.label(HudStyle.mono(700), 30)
	_clock.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_clock.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(_clock)
	_next = HudStyle.label(HudStyle.sans(600), 19, HudStyle.ACCENT_COLOR)
	lines.add_child(_next)
	_status = HudStyle.label(HudStyle.sans(500), 15, HudStyle.DIM_COLOR)
	lines.add_child(_status)
	# The fleet table.
	_fleet_card = _card()
	column.add_child(_fleet_card)
	var grid: GridContainer = GridContainer.new()
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 1)
	_fleet_card.add_child(grid)
	for row: int in FLEET_ROWS:
		for column_index: int in 4:
			var cell: Label = HudStyle.label(HudStyle.mono(700) if column_index == 0 or column_index == 3 else HudStyle.sans(600 if column_index == 1 else 500), 15)
			if column_index == 3:
				cell.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
				cell.custom_minimum_size.x = 76.0
			grid.add_child(cell)
			_fleet_cells.append(cell)
	# The middle of the screen.
	_countdown = _centre_label(HudStyle.sans(800), 96, COUNTDOWN_COLOR, 150.0, 130.0)
	_split = _centre_label(HudStyle.sans(700), 26, COUNTDOWN_COLOR, 290.0, 34.0)
	_warning = _centre_label(HudStyle.sans(700), 26, WARNING_COLOR, 330.0, 34.0)
	_results = PanelContainer.new()
	_results.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_results.add_theme_stylebox_override("panel", HudStyle.card(16.0))
	add_child(_results)
	_results.set_anchors_preset(Control.PRESET_CENTER)
	_results.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_results.grow_vertical = Control.GROW_DIRECTION_BOTH
	_results_text = HudStyle.label(HudStyle.mono(700), 17)
	_results.add_child(_results_text)
	reset()


func _card() -> PanelContainer:
	var card: PanelContainer = PanelContainer.new()
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_theme_stylebox_override("panel", HudStyle.card())
	card.custom_minimum_size.x = CARD_WIDTH
	return card


## A centred label across the screen at `top` pixels from the top.
func _centre_label(font: Font, size: int, colour: Color, top: float, height: float) -> Label:
	var label: Label = HudStyle.label(font, size, colour)
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.7))
	label.add_theme_constant_override("outline_size", 5)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(label)
	label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	label.offset_left = -450.0
	label.offset_right = 450.0
	label.offset_top = top
	label.offset_bottom = top + height
	return label


## A new race: nothing shown yet.
func reset() -> void:
	_splits_seen = 0
	_split_until_s = -1.0
	_fleet_refresh_at_s = -INF  # the race clock reads negative in the countdown: the first frame refreshes
	_countdown.hide()
	_split.hide()
	_warning.hide()
	_results.hide()
	_place.text = ""
	_of.text = ""
	_clock.text = ""
	_next.text = ""
	_status.text = ""
	for cell: Label in _fleet_cells:
		cell.text = ""


## Spectating: the name of the board the camera follows, and whether it follows the leader by
## itself (Tab: by hand). An empty name: racing yourself, no title.
func set_watching(board_name: String, follows_leader: bool) -> void:
	if board_name == _watching and follows_leader == _follows_leader:
		return
	_watching = board_name
	_follows_leader = follows_leader
	_title.visible = not board_name.is_empty()
	_title.text = "Watching %s   %s" % [board_name, "(the leader; Tab: another board)" if follows_leader else "(L: follow the leader)"]
	# A new board: its own splits from now on, and the fleet list marks it at once.
	_splits_seen = -1
	_fleet_refresh_at_s = -INF


## What the race says about board `index` (the player, or the board watched), and that board's
## telemetry, every frame.
## shadow_deficit: the share of the wind the other sails' shadows take from this board right now
## (RaceRunner.shadow_deficit(); 0: none), shown on the wind line when it is more than a few percent.
## rules: the judge (RaceRules), for the penalty warning and the penalty carried; null for none.
func update_from(race: RaceSim, index: int, t: Telemetry, shadow_deficit: float = 0.0, rules: RaceRules = null) -> void:
	var state: String = "   ·   planing" if t.is_planing else ("   ·   luffing" if t.is_luffing else "")
	if t.sailor_state == 1:
		state = "   ·   %s: waterstart in %d s (R: now)" % [t.fall_kind, ceili(t.waterstart_in_s)]
	var here: Vector2 = Vector2(t.position.x, t.position.z)
	var distance_m: float = race.distance_to_next_m(index)
	var turn: String = turn_text(relative_bearing_deg(here, race.next_target(index), t.heading_deg)).replace(" deg ", "° ")
	var status: PackedStringArray = PackedStringArray()
	status.append("%.1f km/h   ·   %.1f kt   ·   %s tack%s" % [t.speed_kmh, t.speed_kt, "starboard" if t.twa_deg >= 0.0 else "port", state])
	var shadow: String = "   ·   in a wind shadow: %d %% less" % roundi(100.0 * shadow_deficit) if shadow_deficit >= 0.03 else ""
	status.append("wind %.0f kt from %s%s" % [t.tws_10m_kt, compass_name(t.wind_from_bearing_deg), shadow])
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
				_of.text = ""
				status.append(("best %s" % clock(_best_s)) if _best_s >= 0.0 else "no best yet")
			else:
				_place.text = ordinal(race.place(index))
				_of.text = "of %d" % race.board_count()
	_status.text = "\n".join(status)
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
	if race.phase() == RaceSim.Phase.FINISHED or race.is_finished(index):
		if refresh or not _results.visible:
			_results_text.text = time_trial_table(race, index) if _time_trial else results_table(race)
		_results.show()
	else:
		_results.hide()


## The fleet table: the rows fleet_rows() picks, the board followed (`player`) in orange with `mark`
## in place of a gap.
func _fill_fleet(race: RaceSim, player: int, mark: String) -> void:
	var rows: Array[int] = fleet_rows(race.race_order(), player, FLEET_ROWS)
	_fleet_card.visible = rows.size() > 1
	for row: int in FLEET_ROWS:
		var cells: Array[Label] = _fleet_cells.slice(row * 4, row * 4 + 4)
		var board: int = rows[row] if row < rows.size() else -2
		var texts: PackedStringArray = PackedStringArray(["", "", "", ""])
		if board == -1:
			texts = PackedStringArray(["", "...", "", ""])
		elif board >= 0:
			var going: String = "finished" if race.is_finished(board) else "to " + race.next_step_name(board)
			texts = PackedStringArray(["%d" % race.place(board), race.board_name(board).left(14), going,
				mark if board == player else gap_text(race.splits_s(board), race.splits_s(player))])
		var colour: Color = HudStyle.HIGHLIGHT_COLOR if board == player else TEXT_COLOR
		for i: int in 4:
			cells[i].text = texts[i]
			cells[i].visible = board != -2
			cells[i].add_theme_color_override("font_color", HudStyle.DIM_COLOR if i == 2 and board != player else colour)


## The boards the fleet table shows, in race order: all of them up to `rows`; in a bigger fleet the
## leaders, then -1 for the boards left out, then the boards around `player` (or the first `rows`
## when the player is among them).
static func fleet_rows(order: Array[int], player: int, rows: int) -> Array[int]:
	if order.size() <= rows:
		return order
	var at: int = order.find(player)
	if at < rows - 1:
		return order.slice(0, rows)
	var around: int = rows - FLEET_LEADERS - 1
	var start: int = clampi(at - floori(around * 0.5), FLEET_LEADERS, order.size() - around)
	var shown: Array[int] = order.slice(0, FLEET_LEADERS)
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


## The fleet in race order: place, name, where it is going, and its gap to the player at the last
## step both have completed (negative: it got there first); the player's own line says `mark`
## ("you", or "<< camera" for the board watched while spectating). The race works its order out once
## per tick (RaceSim.race_order), so this costs a line per board, not a sort per line.
static func fleet_text(race: RaceSim, player: int, mark: String = "you") -> String:
	var lines: PackedStringArray = PackedStringArray()
	for i: int in race.race_order():
		var going: String = "finished" if race.is_finished(i) else "to " + race.next_step_name(i)
		var gap: String = mark if i == player else gap_text(race.splits_s(i), race.splits_s(player))
		lines.append("%d. %-12s %-16s %s" % [race.place(i), race.board_name(i).left(12), going, gap])
	return "\n".join(lines)


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
