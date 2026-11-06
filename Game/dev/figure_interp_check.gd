extends SceneTree
## Does the screen show the sailor figure smoothly between physics ticks? (sailor polish,
## 6 November 2026.) The physics runs 60 times a second; a monitor at 120 or 144 Hz draws two or
## more frames per tick. With physics interpolation on (project setting physics/common/
## physics_interpolation, CLAUDE.md rule 6) the engine draws every node that moved in a physics
## tick part way between its last two ticks' places. This checks that the figure's parts get that
## too: it sails the windsurfer in the normal game loop at up to 240 frames a second and, every
## frame, reads where the engine draws a hand, a foot and the head (get_global_transform_
## interpolated()) in the board's interpolated axes. A part that is interpolated takes several
## different places within one tick; one that is not stays put for the whole tick and then jumps.
##
## Run it (from the repo root):
##   tools/godot.sh --headless --no-header --path Game -s res://dev/figure_interp_check.gd

const PARTS: PackedStringArray = ["HandRight", "FootRight", "Head", "Belly"]
const SECONDS: float = 6.0

var _windsurfer: WindsurferNode
var _started: bool = false
var _frames: int = 0
var _last_tick: int = -1
## Per part: the places drawn within the current tick, and the counts.
var _distinct_in_tick: Dictionary[String, int] = {}
var _ticks_with_motion: Dictionary[String, int] = {}
var _ticks_seen: int = 0
var _last_place: Dictionary[String, Vector3] = {}
var _start_ms: int = 0


func _process(_delta: float) -> bool:
	if not _started:
		_started = true
		Engine.max_fps = 240
		_windsurfer = (load("res://windsurfer/windsurfer.tscn") as PackedScene).instantiate() as WindsurferNode
		_windsurfer.use_autopilot = true
		_windsurfer.effects_wanted = false
		root.add_child(_windsurfer)
		_start_ms = Time.get_ticks_msec()
		print("physics interpolation on: %s, ticks per second %d" % [physics_interpolation, Engine.physics_ticks_per_second])
		return false
	_frames += 1
	var tick: int = Engine.get_physics_frames()
	if tick != _last_tick:
		if _last_tick >= 0 and _windsurfer.sim.time_s > 2.0:
			_ticks_seen += 1
			for part: String in PARTS:
				if _distinct_in_tick.get(part, 0) >= 2:
					_ticks_with_motion[part] = _ticks_with_motion.get(part, 0) + 1
		_last_tick = tick
		for part: String in PARTS:
			_distinct_in_tick[part] = 0
	var board: Transform3D = _windsurfer.get_global_transform_interpolated()
	for part: String in PARTS:
		var node: Node3D = _windsurfer.find_child(part, true, false) as Node3D
		var place: Vector3 = board.affine_inverse() * node.get_global_transform_interpolated().origin
		if not _last_place.has(part) or _last_place[part].distance_to(place) > 1e-5:
			_distinct_in_tick[part] = _distinct_in_tick.get(part, 0) + 1
		_last_place[part] = place
	if Time.get_ticks_msec() - _start_ms > int(SECONDS * 1000.0):
		var seconds: float = (Time.get_ticks_msec() - _start_ms) / 1000.0
		print("%d frames in %.1f s (%.0f a second), %d physics ticks counted" % [_frames, seconds, _frames / seconds, _ticks_seen])
		for part: String in PARTS:
			print("  %-10s moved within the tick (2 or more places drawn) in %d of %d ticks" % [part, _ticks_with_motion.get(part, 0), _ticks_seen])
		return true
	return false
