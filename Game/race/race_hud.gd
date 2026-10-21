class_name RaceHud
extends Control
## The race on the screen (RACING_PLAN.md, 9A), made for racing rather than for reading the
## physics: at the top left the speed, the tack, the wind, the next mark with its distance and
## which way to turn for it, the place and the race clock, and the fleet (place, where each board
## is going, and its gap to you at the last mark you both rounded); the countdown large in the
## middle; a split for a few seconds at every rounding; the warnings for over the line early and
## the wrong side of a mark; and the results when you finish or the race is over. RaceRunner
## updates it every frame from the race (RaceSim) and the player's telemetry; the HUD's own
## telemetry strip and panel are hidden meanwhile (Hud.set_race_mode), F1 brings the panel back.
## While spectating (set_watching) the block is about the board the camera follows, with its name
## on a line above, and the fleet marks that board instead of "you".

const SPLIT_SHOWN_S: float = 4.0
const GO_SHOWN_S: float = 2.0
## The fleet's lines and the results table are worked out a few times a second, not every frame.
const FLEET_REFRESH_S: float = 0.25
const COUNTDOWN_COLOR: Color = Color(1.0, 0.9, 0.5)
const WARNING_COLOR: Color = Color(1.0, 0.35, 0.3)
const TEXT_COLOR: Color = Color(0.95, 0.97, 1.0)
const PANEL_COLOR: Color = Color(0.0, 0.0, 0.0, 0.45)
const COMPASS_NAMES: PackedStringArray = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]

## The name of the board watched while spectating, above the speed (hidden otherwise).
var _title: Label
var _speed: Label
var _info: Label
var _fleet: Label
var _countdown: Label
var _split: Label
var _warning: Label
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


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var font: SystemFont = SystemFont.new()
	font.font_names = PackedStringArray(["DejaVu Sans Mono", "Liberation Mono", "monospace"])
	# The top-left block: the speed large, the facts under it, the fleet under those.
	var block: PanelContainer = PanelContainer.new()
	block.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = PANEL_COLOR
	style.set_corner_radius_all(6)
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	block.add_theme_stylebox_override("panel", style)
	add_child(block)
	block.position = Vector2(16.0, 10.0)
	var column: VBoxContainer = VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	block.add_child(column)
	_title = _text_label(font, 20, COUNTDOWN_COLOR)
	_title.hide()
	column.add_child(_title)
	_speed = _text_label(font, 30, TEXT_COLOR)
	column.add_child(_speed)
	_info = _text_label(font, 17, TEXT_COLOR)
	column.add_child(_info)
	_fleet = _text_label(font, 17, TEXT_COLOR)
	column.add_child(_fleet)
	# The middle of the screen.
	_countdown = _centre_label(font, 96, COUNTDOWN_COLOR, 150.0, 130.0)
	_split = _centre_label(font, 26, COUNTDOWN_COLOR, 290.0, 34.0)
	_warning = _centre_label(font, 26, WARNING_COLOR, 330.0, 34.0)
	_results = PanelContainer.new()
	_results.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_results)
	_results.set_anchors_preset(Control.PRESET_CENTER)
	_results.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_results.grow_vertical = Control.GROW_DIRECTION_BOTH
	_results_text = _text_label(font, 17, TEXT_COLOR)
	_results.add_child(_results_text)
	reset()


func _text_label(font: Font, size: int, colour: Color) -> Label:
	var label: Label = Label.new()
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", colour)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


## A centred label across the screen at `top` pixels from the top.
func _centre_label(font: Font, size: int, colour: Color, top: float, height: float) -> Label:
	var label: Label = _text_label(font, size, colour)
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.7))
	label.add_theme_constant_override("outline_size", 4)
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
	_speed.text = ""
	_info.text = ""
	_fleet.text = ""


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
func update_from(race: RaceSim, index: int, t: Telemetry) -> void:
	var tack: String = "starboard tack" if t.twa_deg >= 0.0 else "port tack"
	var state: String = "planing" if t.is_planing else ("luffing" if t.is_luffing else "")
	if t.sailor_state == 1:
		state = "%s: waterstart in %d s (R: now)" % [t.fall_kind, ceili(t.waterstart_in_s)]
	_speed.text = "%4.1f km/h  %4.1f kt   %s   %s" % [t.speed_kmh, t.speed_kt, tack, state]
	var here: Vector2 = Vector2(t.position.x, t.position.z)
	var next_name: String = race.next_step_name(index)
	var distance_m: float = race.distance_to_next_m(index)
	var turn: String = turn_text(relative_bearing_deg(here, race.next_target(index), t.heading_deg))
	var lines: PackedStringArray = PackedStringArray()
	lines.append("wind %2.0f kt from %s" % [t.tws_10m_kt, compass_name(t.wind_from_bearing_deg)])
	if race.phase() == RaceSim.Phase.PRE_START:
		var left: float = race.countdown_s()
		_countdown.text = "%d" % ceili(left)
		_countdown.show()
		lines.append("start in %s   the line %d m %s" % [clock(left), roundi(distance_m), turn])
	else:
		var time_s: float = race.race_time_s()
		_countdown.text = "GO!"
		_countdown.visible = time_s < GO_SHOWN_S
		if race.is_finished(index):
			lines.append("finished %s in %s" % [ordinal(race.place(index)), clock(race.finish_time_s(index))])
		else:
			lines.append("next: %s   %d m %s" % [next_name, roundi(distance_m), turn])
			lines.append("%s of %d   race %s" % [ordinal(race.place(index)), race.board_count(), clock(time_s)])
	_info.text = "\n".join(lines)
	var refresh: bool = race.clock_s() >= _fleet_refresh_at_s
	if refresh:
		_fleet.text = fleet_text(race, index, "you" if _watching.is_empty() else "<< camera")
		_fleet_refresh_at_s = race.clock_s() + FLEET_REFRESH_S
	_show_split(race, index)
	if race.is_ocs(index):
		_warning.text = "Over the line early: go back behind it"
		_warning.show()
	elif race.wrong_side_warning(index):
		_warning.text = "Wrong side of the mark"
		_warning.show()
	else:
		_warning.hide()
	if race.phase() == RaceSim.Phase.FINISHED or race.is_finished(index):
		if refresh or not _results.visible:
			_results_text.text = results_table(race)
		_results.show()
	else:
		_results.hide()


## The time at a step just completed, for a few seconds.
func _show_split(race: RaceSim, index: int) -> void:
	var splits: PackedFloat32Array = race.splits_s(index)
	if _splits_seen < 0:
		# A board just picked by the spectator: its old splits are not news.
		_splits_seen = splits.size()
	if splits.size() > _splits_seen:
		_splits_seen = splits.size()
		var step: RaceStep = race.steps()[_splits_seen - 1]
		_split.text = "%s  %s" % [step.name, clock(splits[_splits_seen - 1])]
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
static func results_table(race: RaceSim) -> String:
	var lines: PackedStringArray = PackedStringArray(["  Results", ""])
	for result: RaceResult in race.results():
		if result.finished:
			lines.append("  %d. %-14s %s   +%s" % [result.place, result.name, clock(result.finish_time_s), clock(result.gap_s)])
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
