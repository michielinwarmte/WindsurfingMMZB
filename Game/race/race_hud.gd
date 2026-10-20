class_name RaceHud
extends Control
## The race on the screen (RACING_PLAN.md, 9A): the countdown large in the middle; a line under
## the telemetry strip with the race clock, the next mark and its distance, and the place; a split
## for a few seconds at every rounding; the OCS and wrong-side warnings; and the results when the
## race is over. RaceRunner updates it every frame from the race (RaceSim), the only thing it reads.

const SPLIT_SHOWN_S: float = 4.0
const GO_SHOWN_S: float = 2.0
const COUNTDOWN_COLOR: Color = Color(1.0, 0.9, 0.5)
const WARNING_COLOR: Color = Color(1.0, 0.35, 0.3)
const LINE_COLOR: Color = Color(0.9, 0.95, 1.0)

var _countdown: Label
var _line: Label
var _split: Label
var _warning: Label
var _results: PanelContainer
var _results_text: Label
## How many splits have been shown, so a new one is noticed.
var _splits_seen: int = 0
var _split_until_s: float = -1.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var font: SystemFont = SystemFont.new()
	font.font_names = PackedStringArray(["DejaVu Sans Mono", "Liberation Mono", "monospace"])
	_countdown = _label(font, 96, COUNTDOWN_COLOR, 240.0, 130.0)
	_line = _label(font, 18, LINE_COLOR, 0.0, 26.0)
	_line.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_line.offset_left = -450.0
	_line.offset_right = 450.0
	_line.offset_top = -66.0
	_line.offset_bottom = -40.0
	_split = _label(font, 26, COUNTDOWN_COLOR, 380.0, 34.0)
	_warning = _label(font, 26, WARNING_COLOR, 420.0, 34.0)
	_results = PanelContainer.new()
	_results.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_results)
	_results.set_anchors_preset(Control.PRESET_CENTER)
	_results.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_results.grow_vertical = Control.GROW_DIRECTION_BOTH
	_results_text = Label.new()
	_results_text.add_theme_font_override("font", font)
	_results_text.add_theme_font_size_override("font_size", 17)
	_results.add_child(_results_text)
	reset()


## A centred label across the screen at `top` pixels from the top.
func _label(font: Font, size: int, colour: Color, top: float, height: float) -> Label:
	var label: Label = Label.new()
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", colour)
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.7))
	label.add_theme_constant_override("outline_size", 4)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
	_countdown.hide()
	_split.hide()
	_warning.hide()
	_results.hide()
	_line.text = ""


## What the race says about board `index` (the player), every frame.
func update_from(race: RaceSim, index: int) -> void:
	var next_name: String = race.next_step_name(index)
	var distance: String = "%d m" % roundi(race.distance_to_next_m(index))
	if race.phase() == RaceSim.Phase.PRE_START:
		var left: float = race.countdown_s()
		_countdown.text = "%d" % ceili(left)
		_countdown.show()
		_line.text = "Start in %s     next: %s  %s" % [_clock(left), next_name, distance]
	else:
		var time_s: float = race.race_time_s()
		_countdown.text = "GO!"
		_countdown.visible = time_s < GO_SHOWN_S
		if race.is_finished(index):
			_line.text = "Finished in %s     %s" % [_clock(race.finish_time_s(index)), _ordinal(race.place(index))]
		else:
			_line.text = "Race %s     next: %s  %s     %s of %d" % [
				_clock(time_s), next_name, distance, _ordinal(race.place(index)), race.board_count()]
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
		_results_text.text = _results_table(race)
		_results.show()
	else:
		_results.hide()


## The time at a step just completed, for a few seconds.
func _show_split(race: RaceSim, index: int) -> void:
	var splits: PackedFloat32Array = race.splits_s(index)
	if splits.size() > _splits_seen:
		_splits_seen = splits.size()
		var step: RaceStep = race.steps()[_splits_seen - 1]
		_split.text = "%s  %s" % [step.name, _clock(splits[_splits_seen - 1])]
		_split.show()
		_split_until_s = race.clock_s() + SPLIT_SHOWN_S
	if _split_until_s >= 0.0 and race.clock_s() > _split_until_s:
		_split.hide()


## Place, name, time and gap for every board; the boards still sailing with their progress.
func _results_table(race: RaceSim) -> String:
	var lines: PackedStringArray = PackedStringArray(["  Results", ""])
	for result: RaceResult in race.results():
		if result.finished:
			lines.append("  %d. %-14s %s   +%s" % [result.place, result.name, _clock(result.finish_time_s), _clock(result.gap_s)])
		else:
			lines.append("  %d. %-14s sailing, %d of %d" % [result.place, result.name, result.steps_done, result.steps_total])
	lines.append("")
	lines.append("  R: race again     Esc: menu")
	return "\n".join(lines)


static func _clock(seconds: float) -> String:
	if seconds < 0.0:
		return "-"
	return "%d:%04.1f" % [int(seconds / 60.0), fmod(seconds, 60.0)]


static func _ordinal(place: int) -> String:
	match place:
		1:
			return "1st"
		2:
			return "2nd"
		3:
			return "3rd"
	return "%dth" % place
