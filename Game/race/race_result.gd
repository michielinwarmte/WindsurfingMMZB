class_name RaceResult
extends RefCounted
## One board's line in a race's results (RACING_PLAN.md, "The flow", step 4): its place, its time,
## its gap to the winner and its split at every step it completed. Made by RaceSim.results().

var name: String = ""
## The board's number in the race (RaceSim.add_board()).
var index: int = 0
## 1 for the winner.
var place: int = 0
var finished: bool = false
## Race time at the finish line, seconds; -1 for a board that did not finish.
var finish_time_s: float = -1.0
## Seconds behind the winner (0 for the winner); -1 for a board that did not finish.
var gap_s: float = -1.0
## The race time at each completed step, seconds: the start, every mark and gate, the finish.
var splits: PackedFloat32Array = PackedFloat32Array()
## Race time added for penalties (RaceRules), already in finish_time_s; 0 for none.
var penalty_s: float = 0.0
var steps_done: int = 0
var steps_total: int = 0


## One line for the tools' output: place, name, time (or DNF), gap, steps done, the splits.
func to_line() -> String:
	var time_text: String = format_time(finish_time_s) if finished else "DNF"
	var gap_text: String = ("+" + format_time(gap_s)) if finished else "-"
	var split_texts: PackedStringArray = PackedStringArray()
	for split: float in splits:
		split_texts.append(format_time(split))
	var penalty_text: String = "  (+%.0f s penalty)" % penalty_s if penalty_s > 0.0 else ""
	return "%d. %-12s %9s %10s  %d/%d steps  splits %s%s" % [
		place, name, time_text, gap_text, steps_done, steps_total,
		" ".join(split_texts) if not split_texts.is_empty() else "-", penalty_text]


## A race time as minutes, seconds and tenths: 102.34 is "1:42.3". "-" for a negative time.
static func format_time(seconds: float) -> String:
	if seconds < 0.0:
		return "-"
	# Rounded to the tenth first, so 59.96 reads 1:00.0 and not 0:60.0.
	var tenths: int = roundi(seconds * 10.0)
	var minutes: int = floori(tenths / 600.0)
	var rest: int = tenths - minutes * 600
	return "%d:%02d.%d" % [minutes, floori(rest / 10.0), rest % 10]
