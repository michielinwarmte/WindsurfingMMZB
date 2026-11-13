class_name TvCamera
extends RefCounted
## The TV camera of a watched race (WatchMode: T for the director, 5 to 9 for one shot by hand). Max,
## 12 November 2026: "make the tv cam in tv mode more tv like ... use only the drone/helicopter, [the]
## committee boat down the start line at the start for looking for over-earlies, but [I] can override
## [it] for the drone like camera cams. follow the front or exciting things".
##
## It places the camera itself (CameraRig.Mode.DIRECTED; frame() every frame), as a race on TV is
## filmed: drones and a helicopter that move smoothly with the boats, a camera on the committee boat
## looking down the start line, and hard cuts between them. No low game cameras.
## The shots (Shot):
## - CHASE: a drone behind and above the board, a little to one side; it swings round with the board.
## - TRACK: a drone abeam, low, flying along with the board and slowly falling back past it.
## - ORBIT: the helicopter: high and far, circling the board and the boats round it.
## - OVERHEAD: a drone straight above, turning slowly (a mark rounding from above).
## - GROUP: a fight: the boats close to the board framed together, from behind and to one side.
## - MARK: a drone waiting beyond the board's next mark: the boats come towards it and round the mark.
## - START_WIDE: before the start, a drone high behind the line: the fleet lining up, the line, the course.
## - COMMITTEE: the committee boat's camera, a few metres up and behind the boat, looking down the line
##   to the pin with the line drawn on the water: who is over early shows at once.
## - FINISH_LINE: the same down the finish line, as the leader comes in.
## The director (step()): the start as a sequence (START_WIDE from START_WIDE_FROM_S before the gun,
## COMMITTEE from LINE_FROM_S before it until LINE_UNTIL_S after it, then the leaders leaving the line
## until AFTER_START_UNTIL_S), the finish line as the leader comes within FINISH_M of it, and between
## them a cut every SHOT_MIN_S to SHOT_MAX_S to the board worth watching (story_weights(): the front
## first, then fights, mark roundings and a board that just gained a place) with a shot that suits it
## (pick_shot()). By hand (hold()) a shot stays on the watched board, which Tab and L change.

enum Shot { CHASE, TRACK, ORBIT, OVERHEAD, GROUP, MARK, START_WIDE, COMMITTEE, FINISH_LINE }

## The drone shots the director cuts between while racing, in pick_shot()'s order.
const DRONE_SHOTS: Array[Shot] = [Shot.CHASE, Shot.TRACK, Shot.ORBIT, Shot.OVERHEAD, Shot.GROUP, Shot.MARK]
## How long a drone shot lasts, real seconds (the same pace in slow motion).
const SHOT_MIN_S: float = 7.0
const SHOT_MAX_S: float = 12.0
## A mark shot holds until the board has rounded and MARK_AFTER_S more, at most MARK_MAX_S. A board of
## the first MARK_FRONT coming within MARK_SOON_M of its mark gets one (not before a shot is
## MARK_CUT_AFTER_S old).
const MARK_AFTER_S: float = 4.0
const MARK_MAX_S: float = 22.0
const MARK_FRONT: int = 3
const MARK_SOON_M: float = 70.0
const MARK_CUT_AFTER_S: float = 2.5
## The start, seconds of the race clock (negative before the gun).
const START_WIDE_FROM_S: float = -40.0
const LINE_FROM_S: float = -12.0
const LINE_UNTIL_S: float = 7.0
const AFTER_START_UNTIL_S: float = 16.0
## The finish line's shot: from the leader this far from the finish (m) until FINISH_HOLD_S after it.
const FINISH_M: float = 140.0
const FINISH_HOLD_S: float = 5.0
## What makes a board worth watching: another racing board this close (a fight, m), its next mark this
## close (m), a place gained this recently (real seconds).
const CLOSE_M: float = 30.0
const MARK_M: float = 80.0
const GAINED_S: float = 15.0
## The extra worth of the first, second, third and fourth board (the front).
const FRONT_WORTH: PackedFloat32Array = [7.0, 4.5, 3.0, 1.5]
## The boats in a GROUP shot: within this distance of the board watched, m.
const GROUP_M: float = 35.0
## The lowest a camera flies above the water, and above the land (a lake's shore), m.
const LOWEST_M: float = 2.5
const ABOVE_LAND_M: float = 12.0

## Each shot's lens (the camera's vertical field of view, degrees; a TV lens is longer than the
## game's 75) and how quickly the camera follows (seconds; a drone glides, a cut is instant).
## The far shots have the long lenses of a TV helicopter, so the boats are not specks on a wide screen.
const FOV_DEG: Dictionary[Shot, float] = {
	Shot.CHASE: 50.0, Shot.TRACK: 40.0, Shot.ORBIT: 28.0, Shot.OVERHEAD: 45.0, Shot.GROUP: 34.0,
	Shot.MARK: 42.0, Shot.START_WIDE: 38.0, Shot.COMMITTEE: 44.0, Shot.FINISH_LINE: 44.0}
const GLIDE_S: Dictionary[Shot, float] = {
	Shot.CHASE: 0.5, Shot.TRACK: 0.6, Shot.ORBIT: 1.0, Shot.OVERHEAD: 0.8, Shot.GROUP: 0.9,
	Shot.MARK: 0.4, Shot.START_WIDE: 1.2, Shot.COMMITTEE: 0.2, Shot.FINISH_LINE: 0.2}
## The drone shots' framing, metres and radians (zoomed by the wheel: CameraRig.directed_zoom).
const CHASE_BACK_M: float = 24.0
const CHASE_UP_M: float = 9.0
const CHASE_SIDE_M: float = 7.0
const CHASE_AHEAD_M: float = 10.0
const TRACK_SIDE_M: float = 32.0
const TRACK_UP_M: float = 6.0
const TRACK_ALONG_M: float = 12.0
const TRACK_PASS_S: float = 14.0
const ORBIT_M: float = 110.0
const ORBIT_ELEVATION_RAD: float = 0.5
const ORBIT_DRIFT_RAD_S: float = 0.035
const OVERHEAD_M: float = 45.0
const OVERHEAD_TURN_RAD_S: float = 0.03
const GROUP_ELEVATION_RAD: float = 0.4
const MARK_BEYOND_M: float = 38.0
const MARK_SIDE_M: float = 18.0
const MARK_UP_M: float = 22.0
const START_BACK_M: float = 70.0
const START_UP_M: float = 30.0
const START_SWAY_M: float = 35.0
## The committee boat's camera: this far behind the boat on the line's line and this high (m), so the
## boat and its flag (whose top is 5.7 m up, CourseOnWater) stay just below the picture.
const LINE_BEHIND_M: float = 10.0
const LINE_UP_M: float = 11.0
const LINE_AIM_M: float = 150.0

var runner: RaceRunner = null
var rig: CameraRig = null
var scene: SailingScene = null

## The shot on the screen and the board it is about (its race number).
var shot: Shot = Shot.ORBIT
var focus: int = -1
## True while the TV camera has the camera (T or 5 to 9, until end()).
var active: bool = false
## True while the director cuts by itself (T); false while a shot is held by hand (5 to 9).
var auto: bool = false
## Whether the helicopter circles (5 again stops or starts it).
var circling: bool = true

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
## The shot's age (s), its side (+1 or -1), how long until the next cut (real s).
var _age_s: float = 0.0
var _side: float = 1.0
var _left_s: float = 0.0
## The start's part on the screen (_start_part()), and the finish line's hold after the leader finished.
var _start_part: int = -1
var _finish_hold_s: float = 0.0
## A mark shot: the mark, the leg arriving at it, the board's steps when it began, when it rounded.
var _mark_at: Vector2 = Vector2.ZERO
var _mark_in: Vector2 = Vector2.ZERO
var _mark_steps: int = 0
var _rounded_age_s: float = -1.0
## The camera: where it is and what it looks at (smoothed), the heading it frames, the orbit's angle.
var _eye: Vector3 = Vector3.ZERO
var _look: Vector3 = Vector3.ZERO
var _heading: Vector3 = Vector3.FORWARD
var _orbit_rad: float = 0.0
var _snap: bool = true
var _last_frame_us: int = 0
## The places as last seen and when each board last gained one (real seconds of _clock_s).
var _places: Dictionary[int, int] = {}
var _gained_at: Dictionary[int, float] = {}
## The front's mark roundings shown: the board's step number at that mark, by board.
var _marks_shown: Dictionary[int, int] = {}
var _clock_s: float = 0.0
## The real seconds of the director's step now (the finish line's hold counts them).
var _step_dt: float = 0.0
## Whether the lines on the water were shown before a line shot showed them.
var _lines_before: bool = false
var _lines_ours: bool = false


func setup(race_runner: RaceRunner, camera_rig: CameraRig, sailing_scene: SailingScene) -> void:
	runner = race_runner
	rig = camera_rig
	scene = sailing_scene
	_rng.randomize()


## T: the director cuts by itself from now on.
func begin_auto() -> void:
	auto = true
	_start_part = -1
	_left_s = 0.0
	_take_the_camera()


## 5 to 9: this shot on the board watched, until a camera key, T, or another shot.
func hold(by_hand: Shot) -> void:
	auto = false
	_take_the_camera()
	_cut(by_hand, runner.followed_index())


## The TV camera gives the camera back (the rig's own mode is set by the caller).
func end() -> void:
	active = false
	auto = false
	_show_lines(false)
	if scene != null:
		scene.show_water_grid(true)
	if rig.director == frame:
		rig.director = Callable()


## Whether the TV camera has the camera now.
func is_on() -> bool:
	return active


## Every frame: while on, the camera stays the TV camera's. The scene sets its start camera when a race
## is set up (after --tv=1 took it, and at every R); only a camera key (end()) gives the camera back.
func keep_the_camera() -> void:
	if active and (rig.mode != CameraRig.Mode.DIRECTED or rig.director != frame):
		_take_the_camera()


## A new race: the start sequence again, no places gained yet.
func new_race() -> void:
	_start_part = -1
	_left_s = 0.0
	_places.clear()
	_gained_at.clear()
	_marks_shown.clear()


func _take_the_camera() -> void:
	active = true
	# The water's speed grid is a sailing aid; a TV picture has none.
	if scene != null:
		scene.show_water_grid(false)
	rig.director = frame
	rig.set_mode(CameraRig.Mode.DIRECTED)
	_snap = true


# ---------------------------------------------------------------- the director

## Every frame while the director cuts by itself (not while the race is frozen): the next cut when it
## is time. `real_dt`: real seconds since the last frame.
func step(real_dt: float) -> void:
	var race: RaceSim = runner.race
	if race == null or runner.watch_order().is_empty():
		return
	_step_dt = real_dt
	_clock_s += real_dt
	_left_s -= real_dt
	_note_places(race)
	var part: int = start_part(race.is_started(), race.clock_s(), race.phase() == RaceSim.Phase.FINISHED)
	if part != _start_part:
		_start_part = part
		if part >= 0:
			_cut_to_the_start(race, part)
			return
		_left_s = 0.0
	if part >= 0:
		return  # the start's shots hold until their time is up
	if _finish_line(race):
		return
	if _front_at_a_mark(race):
		return
	var gone: bool = focus < 0 or not runner.watch_order().has(focus)
	if shot == Shot.MARK and not gone and _mark_shot_goes_on(race):
		return
	if _left_s > 0.0 and not gone:
		return
	_cut_to_a_story(race)


## The start's part at a moment of the race clock: 0 the wide shot of the line, 1 the committee boat's
## view down it, 2 the leaders leaving the line; -1 outside the start. Plain numbers, for the tests.
static func start_part(started: bool, clock_s: float, finished: bool = false) -> int:
	if not started or finished:
		return -1
	if clock_s >= START_WIDE_FROM_S and clock_s < LINE_FROM_S:
		return 0
	if clock_s >= LINE_FROM_S and clock_s <= LINE_UNTIL_S:
		return 1
	if clock_s > LINE_UNTIL_S and clock_s <= AFTER_START_UNTIL_S:
		return 2
	return -1


func _cut_to_the_start(race: RaceSim, part: int) -> void:
	if part == 2:
		# The leaders leaving the line: the leader's group if it has one, else the helicopter over it.
		var leader: int = runner.watch_order()[0]
		_cut(Shot.GROUP if _has_company(race, leader) else Shot.ORBIT, leader)
		return
	# The board nearest the middle of the line is the one the race card names.
	var middle: Vector2 = runner.course.start_middle()
	var best: int = -1
	var best_m: float = INF
	for index: int in runner.watch_order():
		var m: float = race.board_position(index).distance_to(middle)
		if m < best_m:
			best_m = m
			best = index
	runner.watch_board(best)
	_cut(Shot.START_WIDE if part == 0 else Shot.COMMITTEE, best)


## The leader near the finish: the finish line's shot, held until FINISH_HOLD_S after it finished.
## True while that shot is on.
func _finish_line(race: RaceSim) -> bool:
	if race.phase() != RaceSim.Phase.RACING or runner.course.mark(CourseMark.FINISH_BOAT) == null:
		return false
	var leader: int = runner.watch_order()[0]
	if shot == Shot.FINISH_LINE:
		if race.is_finished(focus):
			_finish_hold_s += _step_dt
			if _finish_hold_s > FINISH_HOLD_S:
				_left_s = 0.0
				return false
		return true
	var step_now: RaceStep = race.next_step(leader)
	if step_now != null and step_now.kind == RaceStep.Kind.FINISH and race.distance_to_next_m(leader) < FINISH_M:
		_finish_hold_s = 0.0
		runner.watch_board(leader)
		_cut(Shot.FINISH_LINE, leader)
		return true
	return false


## A board of the front (the first MARK_FRONT) coming within MARK_SOON_M of its mark: the mark's drone,
## once a rounding (TV never misses the leaders at a mark). Not in the first MARK_CUT_AFTER_S of a shot,
## nor while a mark shot goes on. True when it cut.
func _front_at_a_mark(race: RaceSim) -> bool:
	if race.phase() != RaceSim.Phase.RACING or _age_s < MARK_CUT_AFTER_S:
		return false
	if shot == Shot.MARK and focus >= 0 and _mark_shot_goes_on(race):
		return false
	var order: Array[int] = runner.watch_order()
	for place: int in mini(MARK_FRONT, order.size()):
		var index: int = order[place]
		if race.is_finished(index) or not _next_is_a_mark(race, index):
			continue
		var step_number: int = race.next_step_index(index)
		if race.distance_to_next_m(index) >= MARK_SOON_M or _marks_shown.get(index, -1) == step_number:
			continue
		# This rounding is shown, and so are the roundings of the boats close behind it at the same mark.
		for other: int in order:
			if race.next_step_index(other) == step_number and race.board_position(other).distance_to(race.board_position(index)) < GROUP_M:
				_marks_shown[other] = step_number
		runner.watch_board(index)
		_cut(Shot.MARK, index)
		return true
	return false


## A mark shot goes on until the board has rounded its mark and MARK_AFTER_S more, at most MARK_MAX_S.
func _mark_shot_goes_on(race: RaceSim) -> bool:
	if _age_s > MARK_MAX_S:
		return false
	if race.next_step_index(focus) > _mark_steps:
		if _rounded_age_s < 0.0:
			_rounded_age_s = _age_s
		return _age_s - _rounded_age_s < MARK_AFTER_S
	return true


## A new shot: a board worth watching and a shot that suits what it is doing.
func _cut_to_a_story(race: RaceSim) -> void:
	var order: Array[int] = runner.watch_order()
	var positions: PackedVector2Array = PackedVector2Array()
	var to_mark: PackedFloat32Array = PackedFloat32Array()
	var finished: PackedByteArray = PackedByteArray()
	var gained: PackedByteArray = PackedByteArray()
	var late: PackedByteArray = PackedByteArray()
	var racing: bool = race.phase() == RaceSim.Phase.RACING
	for index: int in order:
		var next: RaceStep = race.next_step(index)
		late.append(1 if racing and next != null and next.kind == RaceStep.Kind.START else 0)
		positions.append(race.board_position(index))
		to_mark.append(race.distance_to_next_m(index) if racing and _next_is_a_mark(race, index) else INF)
		finished.append(1 if race.is_finished(index) or race.is_retired(index) else 0)
		gained.append(1 if _gained_at.has(index) and _clock_s - _gained_at[index] < GAINED_S else 0)
	var weights: PackedFloat32Array = story_weights(positions, to_mark, finished, gained, late, order.find(focus))
	var at: int = _rng.rand_weighted(weights)
	var pick: int = order[at]
	runner.watch_board(pick)
	var in_a_fight: bool = _has_company(race, pick)
	var next_shot: Shot = pick_shot(to_mark[at] < MARK_M, in_a_fight, shot, _rng.randf())
	_cut(next_shot, pick)
	_left_s = _rng.randf_range(SHOT_MIN_S, SHOT_MAX_S)


func _next_is_a_mark(race: RaceSim, index: int) -> bool:
	var next: RaceStep = race.next_step(index)
	return next != null and (next.kind == RaceStep.Kind.MARK or next.kind == RaceStep.Kind.GATE)


## Another racing board within CLOSE_M of this one.
func _has_company(race: RaceSim, index: int) -> bool:
	for other: int in runner.watch_order():
		if other != index and not race.is_finished(other) and race.board_position(other).distance_to(race.board_position(index)) < CLOSE_M:
			return true
	return false


## How much each board (in race order, the leader first) is worth a shot: the front most (FRONT_WORTH),
## then a fight (far more in the front half: just after the start most boats are in one), a board near
## its next mark (more in the front three), a board that just gained a place; a finished board, and a
## board still to start after the gun (`late`: back over the line, or a late starter), little; the board
## on the screen half (the camera moves on, but may stay with a good story). Plain numbers in, so the
## tests can drive it.
static func story_weights(positions: PackedVector2Array, to_mark: PackedFloat32Array, finished: PackedByteArray, gained: PackedByteArray, late: PackedByteArray, shown: int) -> PackedFloat32Array:
	var weights: PackedFloat32Array = PackedFloat32Array()
	var count: int = positions.size()
	for i: int in count:
		var weight: float = 0.3
		if i < FRONT_WORTH.size():
			weight += FRONT_WORTH[i]
		for j: int in count:
			if j != i and finished[j] == 0 and positions[i].distance_to(positions[j]) < CLOSE_M:
				weight += 3.0 if i < count / 2.0 else 0.8
				break
		if to_mark[i] < MARK_M:
			weight += 4.0 if i < 3 else 2.0
		if gained[i] != 0:
			weight += 3.0
		if late[i] != 0:
			weight *= 0.3
		if finished[i] != 0:
			weight = 0.1
		if i == shown and count > 1:
			weight *= 0.5
		weights.append(weight)
	return weights


## The next drone shot for a board: near its mark the mark's shot or one from above, in a fight the
## group, otherwise a chase, a tracking drone or the helicopter; never the shot just on the screen.
## `dice`: a number from 0 to 1. Plain numbers in, so the tests can drive it.
static func pick_shot(near_mark: bool, in_a_fight: bool, last: Shot, dice: float) -> Shot:
	# CHASE, TRACK, ORBIT, OVERHEAD, GROUP, MARK (DRONE_SHOTS' order).
	var weights: PackedFloat32Array = PackedFloat32Array([3.0, 3.0, 2.5, 1.5, 0.0, 0.0])
	if near_mark:
		weights = PackedFloat32Array([1.0, 0.5, 1.5, 2.5, 0.0, 4.5])
	elif in_a_fight:
		weights = PackedFloat32Array([2.0, 2.5, 1.0, 1.0, 3.5, 0.0])
	var at_last: int = DRONE_SHOTS.find(last)
	if at_last >= 0:
		weights[at_last] = 0.0
	var total: float = 0.0
	for weight: float in weights:
		total += weight
	var left: float = clampf(dice, 0.0, 0.999999) * total
	for i: int in weights.size():
		left -= weights[i]
		if left < 0.0:
			return DRONE_SHOTS[i]
	return Shot.ORBIT


## The places in race order now; a board that moved up while racing has gained a place.
func _note_places(race: RaceSim) -> void:
	if race.phase() != RaceSim.Phase.RACING:
		_places.clear()
		return
	var order: Array[int] = race.race_order()
	for place: int in order.size():
		var index: int = order[place]
		if _places.has(index) and place < _places[index] and not race.is_finished(index):
			_gained_at[index] = _clock_s
		_places[index] = place


# ---------------------------------------------------------------- the shots

## Cuts to a shot about a board: the camera jumps there (a TV cut) and glides from then on.
func _cut(next: Shot, board: int) -> void:
	shot = next
	focus = board
	_age_s = 0.0
	_side = 1.0 if _rng.randf() < 0.5 else -1.0
	_snap = true
	_rounded_age_s = -1.0
	var node: WindsurferNode = runner.board_node(board)
	if node != null:
		_heading = _forward_of(node.get_global_transform_interpolated())
		_orbit_rad = _behind_rad(_heading) + _side * PI * 0.25
	if next == Shot.MARK and runner.race != null and board >= 0:
		var mark: RaceStep = runner.race.next_step(board)
		if mark != null:
			_mark_at = mark.target()
			_mark_in = mark.in_dir
			_mark_steps = runner.race.next_step_index(board)
	_show_lines(next == Shot.COMMITTEE or next == Shot.FINISH_LINE)


## The lines on the water for the line shots (and as they were after them).
func _show_lines(shown: bool) -> void:
	if scene == null:
		return
	if shown and not _lines_ours:
		_lines_before = scene.course_lines_shown()
		_lines_ours = true
		scene.show_course_lines(true)
	elif not shown and _lines_ours:
		_lines_ours = false
		scene.show_course_lines(_lines_before)


## Every frame while the TV camera has the camera (CameraRig.director): where the shot wants the camera,
## reached by gliding (or at once after a cut).
func frame(delta: float) -> void:
	var now_us: int = Time.get_ticks_usec()
	if now_us - _last_frame_us > 300000:
		_snap = true  # the first frame after a pause of the camera (the race director's view): no glide
	_last_frame_us = now_us
	if not auto:
		# By hand the shot stays on the board watched (Tab and L change it).
		var watched: int = runner.followed_index()
		if watched != focus and watched >= 0:
			var held: Shot = shot
			_cut(held, watched)
	var node: WindsurferNode = runner.board_node(focus) if focus >= 0 else runner.followed_node()
	if node == null:
		node = runner.followed_node()
	if node == null:
		return
	_age_s += delta
	var board: Transform3D = node.get_global_transform_interpolated()
	_heading = _glide_vector(_heading, _forward_of(board), delta, 1.5 if shot == Shot.CHASE else 2.5)
	var wanted: PackedVector3Array = _place(shot, board.origin, delta)
	var eye: Vector3 = _keep_above_ground(wanted[0], board.origin.y)
	var camera: Camera3D = rig.camera
	if _snap:
		_eye = eye
		_look = wanted[1]
		_snap = false
	else:
		_eye = _eye.lerp(eye, 1.0 - exp(-delta / GLIDE_S[shot]))
		_look = _look.lerp(wanted[1], 1.0 - exp(-delta / 0.3))
	camera.fov = FOV_DEG[shot]
	camera.global_position = _eye
	if _eye.distance_to(_look) < 0.01:
		return
	# Looking straight down (the overhead drone) the picture's top is the way the drone has turned to.
	var up: Vector3 = Vector3.UP
	if shot == Shot.OVERHEAD or absf((_look - _eye).normalized().dot(Vector3.UP)) > 0.995:
		up = Vector3(sin(_orbit_rad), 0.0, cos(_orbit_rad))
	camera.look_at(_look, up)


## Where a shot wants the camera and what it looks at: [eye, look].
func _place(which: Shot, at: Vector3, delta: float) -> PackedVector3Array:
	var zoom: float = rig.directed_zoom
	var forward: Vector3 = _heading
	var right: Vector3 = forward.cross(Vector3.UP)
	var up: Vector3 = Vector3.UP
	match which:
		Shot.CHASE:
			var eye: Vector3 = at - forward * CHASE_BACK_M * zoom + right * _side * CHASE_SIDE_M * zoom + up * CHASE_UP_M * zoom
			return PackedVector3Array([eye, at + forward * CHASE_AHEAD_M + up * 1.5])
		Shot.TRACK:
			var along: float = lerpf(TRACK_ALONG_M, -TRACK_ALONG_M, clampf(_age_s / TRACK_PASS_S, 0.0, 1.0))
			var eye: Vector3 = at + right * _side * TRACK_SIDE_M * zoom + forward * along + up * TRACK_UP_M * zoom
			return PackedVector3Array([eye, at + up * 1.5])
		Shot.ORBIT:
			if circling:
				_orbit_rad += _side * ORBIT_DRIFT_RAD_S * delta
			var middle: Vector3 = _group_middle(at)
			return PackedVector3Array([middle + orbit_offset(_orbit_rad, ORBIT_ELEVATION_RAD, ORBIT_M * zoom), middle + up * 2.0])
		Shot.OVERHEAD:
			_orbit_rad += _side * OVERHEAD_TURN_RAD_S * delta
			return PackedVector3Array([at + up * OVERHEAD_M * zoom, at])
		Shot.GROUP:
			var group: Vector4 = _group(at)
			var middle: Vector3 = Vector3(group.x, group.y, group.z)
			# The group well inside the picture (the lens's 34 degrees: some 70 degrees across on 16:9).
			var distance_m: float = clampf(group.w * 2.2 + 18.0, 28.0, 110.0) * zoom
			var side_rad: float = _behind_rad(forward) + _side * 0.7
			return PackedVector3Array([middle + orbit_offset(side_rad, GROUP_ELEVATION_RAD, distance_m), middle + up * 1.5])
		Shot.MARK:
			var mark: Vector3 = Vector3(_mark_at.x, at.y, _mark_at.y)
			var into: Vector3 = Vector3(_mark_in.x, 0.0, _mark_in.y)
			if into.length() < 0.01:
				into = forward
			into = into.normalized()
			var beside: Vector3 = into.cross(Vector3.UP)
			var eye: Vector3 = mark + into * MARK_BEYOND_M * zoom + beside * _side * MARK_SIDE_M * zoom + up * MARK_UP_M * zoom
			return PackedVector3Array([eye, mark.lerp(at, 0.45) + up * 1.0])
		Shot.START_WIDE:
			var line: PackedVector3Array = _line(CourseMark.START_BOAT, CourseMark.START_PIN, at.y)
			if line.is_empty():
				return _place(Shot.ORBIT, at, delta)
			var middle: Vector3 = (line[0] + line[1]) * 0.5
			var course_way: Vector3 = _first_leg()
			var along_line: Vector3 = (line[0] - line[1]).normalized()
			var eye: Vector3 = middle - course_way * START_BACK_M * zoom + along_line * sin(_age_s * 0.08) * START_SWAY_M + up * START_UP_M * zoom
			return PackedVector3Array([eye, middle + course_way * 10.0])
		Shot.COMMITTEE, Shot.FINISH_LINE:
			var ends: PackedVector3Array = _line(CourseMark.START_BOAT if which == Shot.COMMITTEE else CourseMark.FINISH_BOAT,
				CourseMark.START_PIN if which == Shot.COMMITTEE else CourseMark.FINISH_PIN, at.y)
			if ends.is_empty():
				return _place(Shot.ORBIT, at, delta)
			return line_view(ends[0], ends[1])
	return PackedVector3Array([at + up * 10.0, at])


## The committee boat's view down a line: from LINE_BEHIND_M behind the boat on the line's line,
## LINE_UP_M up, at the far end's mark (half a metre above the water), or on a line shorter than
## LINE_AIM_M at a point that far down it: aimed at a near pin the camera tilts down and the boat's
## flag comes into the picture. [eye, look].
static func line_view(boat: Vector3, pin: Vector3) -> PackedVector3Array:
	var along: Vector3 = Vector3(pin.x - boat.x, 0.0, pin.z - boat.z)
	var length_m: float = along.length()
	along = along.normalized()
	var eye: Vector3 = boat - along * LINE_BEHIND_M + Vector3.UP * LINE_UP_M
	var aim: Vector3 = boat + along * maxf(length_m, LINE_AIM_M) + Vector3.UP * 0.5
	return PackedVector3Array([eye, aim])


## A point round a middle at an angle round it (radians; the CameraRig orbit's azimuth: 0 is to the
## south, +Z), an angle above the water, and a distance.
static func orbit_offset(azimuth_rad: float, elevation_rad: float, distance_m: float) -> Vector3:
	return Vector3(cos(elevation_rad) * sin(azimuth_rad), sin(elevation_rad), cos(elevation_rad) * cos(azimuth_rad)) * distance_m


## The azimuth (orbit_offset()) of the point behind a heading.
static func _behind_rad(forward: Vector3) -> float:
	return atan2(-forward.x, -forward.z)


## The board's heading, level, one metre long.
static func _forward_of(board: Transform3D) -> Vector3:
	var forward: Vector3 = -board.basis.z
	forward.y = 0.0
	return forward.normalized() if forward.length() > 0.01 else Vector3.FORWARD


static func _glide_vector(from: Vector3, to: Vector3, delta: float, seconds: float) -> Vector3:
	var mixed: Vector3 = from.lerp(to, 1.0 - exp(-delta / seconds))
	return mixed.normalized() if mixed.length() > 0.01 else to


## The boats round the board watched (within GROUP_M, racing): their middle (x, y, z) and how far the
## farthest is from it (w), metres.
func _group(at: Vector3) -> Vector4:
	var points: PackedVector3Array = PackedVector3Array([at])
	var race: RaceSim = runner.race
	if race != null:
		for index: int in runner.watch_order():
			var node: WindsurferNode = runner.board_node(index)
			if index == focus or node == null or race.is_finished(index):
				continue
			var there: Vector3 = node.get_global_transform_interpolated().origin
			if Vector2(there.x - at.x, there.z - at.z).length() < GROUP_M:
				points.append(there)
	var middle: Vector3 = Vector3.ZERO
	for point: Vector3 in points:
		middle += point
	middle /= float(points.size())
	var reach_m: float = 0.0
	for point: Vector3 in points:
		reach_m = maxf(reach_m, Vector2(point.x - middle.x, point.z - middle.z).length())
	return Vector4(middle.x, at.y, middle.z, reach_m)


func _group_middle(at: Vector3) -> Vector3:
	var group: Vector4 = _group(at)
	return Vector3(group.x, group.y, group.z)


## A line's two ends on the water (the boat's end first), or nothing when the course has no such line.
func _line(boat_id: String, pin_id: String, water_y: float) -> PackedVector3Array:
	var boat: CourseMark = runner.course.mark(boat_id) if runner.course != null else null
	var pin: CourseMark = runner.course.mark(pin_id) if runner.course != null else null
	if boat == null or pin == null:
		return PackedVector3Array()
	return PackedVector3Array([Vector3(boat.position.x, water_y, boat.position.y), Vector3(pin.position.x, water_y, pin.position.y)])


## The way the first leg goes from the start, level, one metre long.
func _first_leg() -> Vector3:
	var race: RaceSim = runner.race
	if race != null and not race.steps().is_empty():
		var way: Vector2 = race.steps()[0].in_dir
		if way.length() > 0.01:
			return Vector3(way.x, 0.0, way.y).normalized()
	return Vector3.FORWARD


## Never under the water, nor into a lake's shore: at least LOWEST_M above the water and ABOVE_LAND_M
## above the land under it.
func _keep_above_ground(eye: Vector3, water_y: float) -> Vector3:
	var lowest: float = water_y + LOWEST_M
	var grid: TerrainGrid = scene.shore_grid if scene != null else null
	if grid != null:
		var land_m: float = grid.height_at(eye.x, eye.z)
		if not is_nan(land_m) and land_m > 0.0:
			lowest = maxf(lowest, water_y + land_m + ABOVE_LAND_M)
	return Vector3(eye.x, maxf(eye.y, lowest), eye.z)
