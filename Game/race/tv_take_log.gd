class_name TvTakeLog
extends RefCounted
## The TV director's takes written down, for the check that sets the director beside the real stream
## (tools/tv_check.sh, tools/broadcast/director_check.py): one row per take, and one per part of a
## take that runs over a phase's border (each part counts in its own phase's time, the take's length
## in the phase it began in, as the stream's readers counted it). Started by --tv_log=<file.csv>;
## --tv_log_races=<n> ends the game once n races have been filmed to their end (the next countdown).
##
## The framing is measured, not taken from the settings: every frame the camera's real place and lens
## and the filmed board's real mast give the sail's share of the picture's height and the horizon's
## share from the top (TvFraming.measure()), the camera's height above the water, its level distance
## to the board and its angle round it (0 behind, 90 abeam, 180 ahead). A row holds their middle values
## over the take (the horizon's middle over the frames it was in the picture, and how often it was not).

const HEADER: String = "race,take,part,phase,take_phase,director,picture,shot,camera,view,on,move,place,board,clock_s,length_s,to_mark_s,sail_wanted_pct,horizon_wanted_pct,sail_pct,horizon_pct,horizon_out_pct,sail_heights,height_m,distance_m,look_down_deg,angle_deg,lens_deg,samples"

## How many races to film before the game ends (0: no end).
var races_wanted: int = 0
var races_done: int = 0
## The race on the screen (counts from 1 with each new race).
var race_number: int = 0

var _file: FileAccess = null
var _open: bool = false
var _take: int = 0
var _part: int = 0
## The take's fields, the part's phase, its start on the race clock and its length in picture seconds.
var _fields: Dictionary[String, String] = {}
var _phase: String = ""
var _clock_s: float = 0.0
var _length_s: float = 0.0
var _sail: PackedFloat32Array = PackedFloat32Array()
var _horizon: PackedFloat32Array = PackedFloat32Array()
var _horizon_out: int = 0
var _sail_heights: PackedFloat32Array = PackedFloat32Array()
var _height: PackedFloat32Array = PackedFloat32Array()
var _distance: PackedFloat32Array = PackedFloat32Array()
var _look_down: PackedFloat32Array = PackedFloat32Array()
var _angle: PackedFloat32Array = PackedFloat32Array()
var _lens: PackedFloat32Array = PackedFloat32Array()


func _init(path: String, races: int) -> void:
	races_wanted = races
	_file = FileAccess.open(path, FileAccess.WRITE)
	if _file == null:
		push_error("The TV director's log could not be written to %s." % path)
		return
	_file.store_line(HEADER)
	print("TV LOG: the director's takes go to %s" % path)


## A new take: its phase and its fields (director, picture, shot, camera, view, on, move, place, board,
## sail_wanted_pct, horizon_wanted_pct), on the race clock at clock_s.
func begin(phase: String, clock_s: float, fields: Dictionary[String, String]) -> void:
	_close_part()
	_take += 1
	_part = 1
	_fields = fields
	_fields["take_phase"] = phase
	_start_part(phase, clock_s)


## The take runs over a phase's border: what came before is a part of its own.
func split(phase: String, clock_s: float) -> void:
	if not _open or phase == _phase:
		return
	_close_part()
	_part += 1
	_start_part(phase, clock_s)


## The picture's seconds go on (every step of the director).
func tick(dt: float) -> void:
	if _open:
		_length_s += dt


## One frame's measurement: the sail's, the horizon's and the sail foot's shares (0 to 1; the sail and
## its foot NAN when they are not in front of the camera), the camera's height above the water and
## level distance to the board (m),
## its angle round the board (degrees) and its lens (degrees). The angle it looks down at the board
## follows from the height and the distance.
func sample(sail_share: float, horizon_share: float, foot_share: float, height_m: float, distance_m: float, angle_deg: float, lens_deg: float) -> void:
	if not _open:
		return
	if not is_nan(sail_share):
		_sail.append(sail_share * 100.0)
	if horizon_share >= 0.0 and horizon_share <= 1.0:
		_horizon.append(horizon_share * 100.0)
	else:
		_horizon_out += 1
	if not is_nan(sail_share) and not is_nan(foot_share) and sail_share > 0.001:
		# The camera's height in sail heights: how far the sail's foot stands below the horizon.
		_sail_heights.append((foot_share - horizon_share) / sail_share)
	_height.append(height_m)
	_distance.append(distance_m)
	_look_down.append(rad_to_deg(atan2(height_m, maxf(distance_m, 0.01))))
	_angle.append(angle_deg)
	_lens.append(lens_deg)


## A race has been filmed to its end: true when that was the last one wanted.
func race_filmed() -> bool:
	races_done += 1
	return races_wanted > 0 and races_done >= races_wanted


## A new race on the screen.
func new_race() -> void:
	_close_part()
	race_number += 1


func close() -> void:
	_close_part()
	if _file != null:
		_file.flush()



func _start_part(phase: String, clock_s: float) -> void:
	_open = true
	_phase = phase
	_clock_s = clock_s
	_length_s = 0.0
	_sail.clear()
	_horizon.clear()
	_horizon_out = 0
	_sail_heights.clear()
	_height.clear()
	_distance.clear()
	_look_down.clear()
	_angle.clear()
	_lens.clear()


func _close_part() -> void:
	if not _open or _file == null:
		_open = false
		return
	_open = false
	var frames: int = _height.size()
	var row: PackedStringArray = PackedStringArray([str(race_number), str(_take), str(_part), _phase, _fields.get("take_phase", ""),
		_fields.get("director", ""), _fields.get("picture", ""), _fields.get("shot", ""), _fields.get("camera", ""),
		_fields.get("view", ""), _fields.get("on", ""), _fields.get("move", ""), _fields.get("place", "0"), _fields.get("board", "-1"),
		"%.2f" % _clock_s, "%.2f" % _length_s, _fields.get("to_mark_s", "") if _part == 1 else "", _fields.get("sail_wanted_pct", ""), _fields.get("horizon_wanted_pct", ""),
		_middle_text(_sail), _middle_text(_horizon), "%.0f" % (100.0 * _horizon_out / maxi(frames, 1)),
		_middle_text(_sail_heights), _middle_text(_height), _middle_text(_distance), _middle_text(_look_down), _middle_text(_angle), _middle_text(_lens), str(frames)])
	_file.store_line(",".join(row))
	_file.flush()


static func middle(values: PackedFloat32Array) -> float:
	if values.is_empty():
		return NAN
	var sorted: PackedFloat32Array = values.duplicate()
	sorted.sort()
	return sorted[sorted.size() / 2]


static func _middle_text(values: PackedFloat32Array) -> String:
	var value: float = middle(values)
	return "" if is_nan(value) else "%.2f" % value
