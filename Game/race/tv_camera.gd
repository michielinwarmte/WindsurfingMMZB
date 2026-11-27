class_name TvCamera
extends RefCounted
## The TV camera of a watched race (WatchMode: T for the director, 5 to 9 for one shot by hand). Max,
## 12 November 2026: "make the tv cam in tv mode more tv like ... use only the drone/helicopter, [the]
## committee boat down the start line at the start for looking for over-earlies, but [I] can override
## [it] for the drone like camera cams. follow the front or exciting things". And 27 November 2026:
## "the drone shots trained on real data".
##
## It places the camera itself (CameraRig.Mode.DIRECTED; frame() every frame) and cuts between shots.
## Two directors (the cuts and the choice of board and shot):
## - the stream's (the default; TvStreamDirector, Game/config/tv_director.tres): the World Tour slalom
##   stream's camera work, measured on nine heats (Documentation/reports/broadcast/
##   tv_director_stream.md). Its pictures are set by the sail's and the horizon's place in the picture
##   (TvPicture, TvFraming), not in metres;
## - the one of 12 November (--tv_director=12nov; Game/config/tv_director_12nov.tres): its numbers
##   chosen by hand, kept as it was for comparing on the screen (step_12nov() and the functions after it).
## The shots (Shot), the first nine of 12 November:
## - CHASE: a drone behind and to one side of the board, travelling with it (the stream's "behind-side").
## - TRACK: a drone abeam, flying along with the board (the stream's "side").
## - ORBIT: the helicopter: high and far, circling the board and the boats round it (by hand, key 5).
## - OVERHEAD: a drone straight above, turning slowly (by hand, key 9).
## - GROUP: the pack: the boats close to the board, closer and steeper, from behind and to one side.
## - MARK: a drone waiting at the board's next mark: the boats come to it and round the mark.
## - START_WIDE: (12 November) before the start, a drone high behind the line.
## - COMMITTEE: the view down the start line from beyond the committee boat, the line drawn on the water:
##   who is over early shows at once (the stream's low drone at the end of the line).
## - FINISH_LINE: the same at the finish line (the stream's drone hovering side-on at the finish).
## - FRONT_SIDE: a drone ahead and to one side, the boards coming towards it, travelling with them.
## - BEACH_WIDE, BEACH_TIGHT: the beach cam: a long lens at water level, far off, on the lake's shore or
##   (on the open sea, or where no shore is in reach) a camera boat off the course: wide on the line and
##   the fleet before the start, tight on the leader in the race and on the winner after it.
## - PULL_OUT: after the race a drone rising and going back over the finish area.
## By hand (hold()) a shot stays on the watched board, which Tab and L change.

enum Shot { CHASE, TRACK, ORBIT, OVERHEAD, GROUP, MARK, START_WIDE, COMMITTEE, FINISH_LINE, FRONT_SIDE, BEACH_WIDE, BEACH_TIGHT, PULL_OUT }

## The drone shots the 12 November director cuts between while racing, in pick_shot()'s order.
const DRONE_SHOTS: Array[Shot] = [Shot.CHASE, Shot.TRACK, Shot.ORBIT, Shot.OVERHEAD, Shot.GROUP, Shot.MARK]
## The directors' numbers.
const STREAM_CONFIG: String = "res://config/tv_director.tres"
const CONFIG_12NOV: String = "res://config/tv_director_12nov.tres"

var runner: RaceRunner = null
var rig: CameraRig = null
var scene: SailingScene = null

## The director set to the stream and its numbers (both null with --tv_director=12nov), and the 12
## November numbers (that director's; with the stream's, the helicopter's and the overhead drone's).
var director: TvStreamDirector = null
var stream: TvDirectorConfig = null
var old: TvDirector12NovConfig = null

## The shot on the screen and the board it is about (its race number).
var shot: Shot = Shot.ORBIT
var focus: int = -1
## The stream's picture on the screen (null for a 12 November shot) and its framing for this take: the
## sail's height and the horizon's place as shares of the picture's height (0 to 1), and the number it
## was drawn with (TvPicture.take_framing()).
var picture: TvPicture = null
var sail_share: float = 0.15
var horizon_share: float = 0.3
var _framing_z: float = 0.0
## True while the TV camera has the camera (T or 5 to 9, until end()).
var active: bool = false
## True while the director cuts by itself (T); false while a shot is held by hand (5 to 9).
var auto: bool = false
## Whether the helicopter circles (5 again stops or starts it).
var circling: bool = true
## The takes written down for the check (--tv_log=<file.csv>), or null.
var take_log: TvTakeLog = null

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
## The way the boards leave the mark (the next leg), for the stream's mark drones.
var _mark_out: Vector2 = Vector2.ZERO
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
## The group of the Marker3D a map puts where its beach camera stands (its eye), for the TV director.
const SHORE_CAMERA_GROUP: StringName = &"tv_shore_camera"

## A stream picture that stands somewhere: where (the beach cam's place, the pull-out's point), what a
## static one looks at, its lens for a static take, how long the take lasts (the pull-out's pace); the
## beach cam's eye above the water, m.
var _stand_eye_m: float = 4.5
var _stand_on_marker: bool = false
var _stand: Vector3 = Vector3.ZERO
var _stand_look: Vector3 = Vector3.ZERO
var _stand_fov: Vector3 = Vector3.ZERO
var _take_s: float = 0.0
## The lens the picture has now, degrees.
var _fov_now: float = 45.0
## The heat's phase as last written down (the log splits a take at a border), and the borders.
var _log_phase: String = ""
var _phase_borders: Vector2 = Vector2(-10.0, 12.0)
## The mast of each board (its drawn mast, for framing and measuring the picture).
var _masts: Dictionary[WindsurferNode, Node3D] = {}
## The filmed board's sail top as it really stands (smoothed): its height above the water (m) and how
## far it leans from the mast foot, level (m, the world's axes). A raked, leaned rig at speed stands
## lower than its mast is long, and its top leans back: the stream's pictures were framed on that.
var _top_m: float = 4.5
var _top_lean: Vector3 = Vector3.ZERO


func setup(race_runner: RaceRunner, camera_rig: CameraRig, sailing_scene: SailingScene) -> void:
	runner = race_runner
	rig = camera_rig
	scene = sailing_scene
	_rng.randomize()
	var options: Dictionary[String, String] = LanSession.command_line_options()
	use_director(options.get("tv_director", "stream"))
	if options.has("tv_log"):
		take_log = TvTakeLog.new(options["tv_log"], maxi(options.get("tv_log_races", "0").to_int(), 0))
		# The take on the screen is written too when the game closes.
		rig.tree_exiting.connect(take_log.close)
		if options.has("tv_seed"):
			_rng.seed = options["tv_seed"].to_int()


## The director: "12nov" the one of 12 November, anything else the stream's.
func use_director(which: String) -> void:
	var borders: TvDirectorConfig = load(STREAM_CONFIG) as TvDirectorConfig
	_phase_borders = Vector2(borders.start_from_s, borders.start_until_s)
	if which == "12nov":
		old = load(CONFIG_12NOV) as TvDirector12NovConfig
		stream = null
		director = null
		return
	stream = borders
	old = stream.hand_shots
	director = TvStreamDirector.new(self, stream, _rng)
	# --tv_only=<shot> (screenshots, checks): the director takes that camera wherever it has one.
	director.only_shot = Shot.keys().find(LanSession.command_line_options().get("tv_only", "").to_upper())


## The director's name in the log.
func director_name() -> String:
	return "stream" if director != null else "12nov"


## T: the director cuts by itself from now on.
func begin_auto() -> void:
	auto = true
	_start_part = -1
	_left_s = 0.0
	if director != null:
		director.begin()
	_take_the_camera()


## 5 to 9: this shot on the board watched, until a camera key, T, or another shot. With the stream's
## director the chase drone (7), the drone beside the board (8) and the view down the line (6) are its
## pictures; the helicopter (5) and the overhead drone (9) are the 12 November ones.
func hold(by_hand: Shot) -> void:
	auto = false
	_take_the_camera()
	var board: int = runner.followed_index()
	var by_hand_picture: TvPicture = director.hand_picture(by_hand) if director != null else null
	if by_hand_picture != null:
		cut_to(by_hand_picture, board, INF)
	else:
		_cut(by_hand, board)


## The TV camera gives the camera back (the rig's own mode is set by the caller).
func end() -> void:
	active = false
	auto = false
	_show_lines(false)
	if take_log != null:
		take_log.close()
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


## A new race: the start sequence again, no places gained yet. With the take log, a race filmed to its
## end counts (the game ends after --tv_log_races of them).
func new_race() -> void:
	if take_log != null:
		var filmed: bool = _log_phase == "after_race"
		take_log.new_race()
		_log_phase = ""
		if filmed and take_log.race_filmed():
			take_log.close()
			print("TV LOG: %d races filmed, the end." % take_log.races_done)
			rig.get_tree().quit()
	_start_part = -1
	_left_s = 0.0
	_places.clear()
	_gained_at.clear()
	_marks_shown.clear()
	if director != null:
		director.new_race()


func _take_the_camera() -> void:
	active = true
	# The water's speed grid is a sailing aid; a TV picture has none.
	if scene != null:
		scene.show_water_grid(false)
	rig.director = frame
	rig.set_mode(CameraRig.Mode.DIRECTED)
	_snap = true


## The take's age, seconds of the picture.
func take_age_s() -> float:
	return _age_s


## The mark a mark's take is at (game X, Z).
func mark_point() -> Vector2:
	return _mark_at


# ---------------------------------------------------------------- the director

## Every frame while the director cuts by itself (not while the race is frozen): the next cut when it
## is time. The director's seconds are the picture's: the frame's own time without the speed-up (the
## real seconds in play, a frame's 1/60 s in a headless check with --fixed-fps); `real_dt` when the rig
## is not in a scene.
func step(real_dt: float) -> void:
	var dt: float = real_dt
	if rig != null and rig.is_inside_tree():
		dt = clampf(rig.get_process_delta_time() / maxf(Engine.time_scale, 0.001), 0.0, 0.25)
	if take_log != null:
		take_log.tick(dt)
		_note_the_phase()
	if director != null:
		director.step(dt)
		return
	step_12nov(dt)


## The 12 November director's step.
func step_12nov(real_dt: float) -> void:
	var race: RaceSim = runner.race
	if race == null or runner.watch_order().is_empty():
		return
	_step_dt = real_dt
	_clock_s += real_dt
	_left_s -= real_dt
	_note_places(race)
	var part: int = start_part(race.is_started(), race.clock_s(), race.phase() == RaceSim.Phase.FINISHED, old)
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


## The start's part at a moment of the race clock (12 November): 0 the wide shot of the line, 1 the
## committee boat's view down it, 2 the leaders leaving the line; -1 outside the start. Plain numbers,
## for the tests.
static func start_part(started: bool, clock_s: float, finished: bool, numbers: TvDirector12NovConfig) -> int:
	if not started or finished:
		return -1
	if clock_s >= numbers.start_wide_from_s and clock_s < numbers.line_from_s:
		return 0
	if clock_s >= numbers.line_from_s and clock_s <= numbers.line_until_s:
		return 1
	if clock_s > numbers.line_until_s and clock_s <= numbers.after_start_until_s:
		return 2
	return -1


func _cut_to_the_start(race: RaceSim, part: int) -> void:
	if part == 2:
		# The leaders leaving the line: the leader's group if it has one, else the helicopter over it.
		var leader: int = runner.watch_order()[0]
		_cut(Shot.GROUP if _has_company(race, leader) else Shot.ORBIT, leader)
		return
	# The board nearest the middle of the line is the one the race card names.
	var best: int = board_nearest(race, runner.course.start_middle())
	runner.watch_board(best)
	_cut(Shot.START_WIDE if part == 0 else Shot.COMMITTEE, best)


## The board on the water nearest a point (-1 for none).
func board_nearest(race: RaceSim, point: Vector2) -> int:
	var best: int = -1
	var best_m: float = INF
	for index: int in runner.watch_order():
		var m: float = race.board_position(index).distance_to(point)
		if m < best_m:
			best_m = m
			best = index
	return best


## The leader near the finish: the finish line's shot, held until finish_hold_s after it finished.
## True while that shot is on.
func _finish_line(race: RaceSim) -> bool:
	if race.phase() != RaceSim.Phase.RACING or runner.course.mark(CourseMark.FINISH_BOAT) == null:
		return false
	var leader: int = runner.watch_order()[0]
	if shot == Shot.FINISH_LINE:
		if race.is_finished(focus):
			_finish_hold_s += _step_dt
			if _finish_hold_s > old.finish_hold_s:
				_left_s = 0.0
				return false
		return true
	var step_now: RaceStep = race.next_step(leader)
	if step_now != null and step_now.kind == RaceStep.Kind.FINISH and race.distance_to_next_m(leader) < old.finish_m:
		_finish_hold_s = 0.0
		runner.watch_board(leader)
		_cut(Shot.FINISH_LINE, leader)
		return true
	return false


## A board of the front (the first mark_front) coming within mark_soon_m of its mark: the mark's
## drone, once a rounding (TV never misses the leaders at a mark). Not in the first mark_cut_after_s
## of a shot, nor while a mark shot goes on. True when it cut.
func _front_at_a_mark(race: RaceSim) -> bool:
	if race.phase() != RaceSim.Phase.RACING or _age_s < old.mark_cut_after_s:
		return false
	if shot == Shot.MARK and focus >= 0 and _mark_shot_goes_on(race):
		return false
	var order: Array[int] = runner.watch_order()
	for place: int in mini(old.mark_front, order.size()):
		var index: int = order[place]
		if race.is_finished(index) or not next_is_a_mark(race, index):
			continue
		var step_number: int = race.next_step_index(index)
		if race.distance_to_next_m(index) >= old.mark_soon_m or _marks_shown.get(index, -1) == step_number:
			continue
		# This rounding is shown, and so are the roundings of the boats close behind it at the same mark.
		for other: int in order:
			if race.next_step_index(other) == step_number and race.board_position(other).distance_to(race.board_position(index)) < old.group_m:
				_marks_shown[other] = step_number
		runner.watch_board(index)
		_cut(Shot.MARK, index)
		return true
	return false


## A mark shot goes on until the board has rounded its mark and mark_after_s more, at most mark_max_s.
func _mark_shot_goes_on(race: RaceSim) -> bool:
	if _age_s > old.mark_max_s:
		return false
	if race.next_step_index(focus) > _mark_steps:
		if _rounded_age_s < 0.0:
			_rounded_age_s = _age_s
		return _age_s - _rounded_age_s < old.mark_after_s
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
		to_mark.append(race.distance_to_next_m(index) if racing and next_is_a_mark(race, index) else INF)
		finished.append(1 if race.is_finished(index) or race.is_retired(index) else 0)
		gained.append(1 if _gained_at.has(index) and _clock_s - _gained_at[index] < old.gained_s else 0)
	var weights: PackedFloat32Array = story_weights(positions, to_mark, finished, gained, late, order.find(focus), old)
	var at: int = _rng.rand_weighted(weights)
	var pick: int = order[at]
	runner.watch_board(pick)
	var in_a_fight: bool = _has_company(race, pick)
	var next_shot: Shot = pick_shot(to_mark[at] < old.mark_m, in_a_fight, shot, _rng.randf(), old)
	_cut(next_shot, pick)
	_left_s = _rng.randf_range(old.shot_min_s, old.shot_max_s)


static func next_is_a_mark(race: RaceSim, index: int) -> bool:
	var next: RaceStep = race.next_step(index)
	return next != null and (next.kind == RaceStep.Kind.MARK or next.kind == RaceStep.Kind.GATE)


## Another racing board within close_m of this one.
func _has_company(race: RaceSim, index: int) -> bool:
	for other: int in runner.watch_order():
		if other != index and not race.is_finished(other) and race.board_position(other).distance_to(race.board_position(index)) < old.close_m:
			return true
	return false


## How much each board (in race order, the leader first) is worth a shot (12 November): the front most
## (front_worth), then a fight (far more in the front half: just after the start most boats are in
## one), a board near its next mark (more in the front three), a board that just gained a place; a
## finished board, and a board still to start after the gun (`late`: back over the line, or a late
## starter), little; the board on the screen half (the camera moves on, but may stay with a good
## story). Plain numbers in, so the tests can drive it.
static func story_weights(positions: PackedVector2Array, to_mark: PackedFloat32Array, finished: PackedByteArray, gained: PackedByteArray, late: PackedByteArray, shown: int, numbers: TvDirector12NovConfig) -> PackedFloat32Array:
	var weights: PackedFloat32Array = PackedFloat32Array()
	var count: int = positions.size()
	for i: int in count:
		var weight: float = numbers.base_worth
		if i < numbers.front_worth.size():
			weight += numbers.front_worth[i]
		for j: int in count:
			if j != i and finished[j] == 0 and positions[i].distance_to(positions[j]) < numbers.close_m:
				weight += numbers.fight_front_worth if i < count / 2.0 else numbers.fight_back_worth
				break
		if to_mark[i] < numbers.mark_m:
			weight += numbers.near_mark_front_worth if i < numbers.near_mark_places else numbers.near_mark_worth
		if gained[i] != 0:
			weight += numbers.gained_worth
		if late[i] != 0:
			weight *= numbers.late_share
		if finished[i] != 0:
			weight = numbers.finished_worth
		if i == shown and count > 1:
			weight *= numbers.shown_share
		weights.append(weight)
	return weights


## The next drone shot for a board (12 November): near its mark the mark's shot or one from above, in a
## fight the group, otherwise a chase, a tracking drone or the helicopter; never the shot just on the
## screen. `dice`: a number from 0 to 1. Plain numbers in, so the tests can drive it.
static func pick_shot(near_mark: bool, in_a_fight: bool, last: Shot, dice: float, numbers: TvDirector12NovConfig) -> Shot:
	var weights: PackedFloat32Array = numbers.shots_usual.duplicate()
	if near_mark:
		weights = numbers.shots_near_mark.duplicate()
	elif in_a_fight:
		weights = numbers.shots_in_a_fight.duplicate()
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


# ---------------------------------------------------------------- the cuts

## Cuts to a 12 November shot about a board: the camera jumps there (a TV cut) and glides from then on.
func _cut(next: Shot, board: int) -> void:
	shot = next
	picture = null
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
	_log_the_take(_shot_fields(next))


## Cuts to one of the stream's pictures about a board (TvStreamDirector): its framing for this take
## drawn from the stream's spread, the camera's side drawn (a mark's: the outside of the turn), and a
## camera that stands somewhere put there. `take_s`: how long the take lasts (the pull-out's pace).
## `mark_step`: the mark a MARK picture waits at (the board's next step when -1).
func cut_to(next: TvPicture, board: int, take_s: float, mark_step: int = -1) -> void:
	shot = next.shot
	picture = next
	focus = board
	_age_s = 0.0
	_take_s = take_s
	_side = 1.0 if _rng.randf() < 0.5 else -1.0
	_snap = true
	_rounded_age_s = -1.0
	_framing_z = _rng.randfn()
	var framing: Vector3 = next.take_framing(_framing_z)
	sail_share = framing.x
	horizon_share = framing.y
	if board >= 0:
		runner.watch_board(board)
	var node: WindsurferNode = runner.board_node(board)
	var at: Vector3 = Vector3.ZERO
	if node != null:
		var board_place: Transform3D = node.get_global_transform_interpolated()
		at = board_place.origin
		_heading = _forward_of(board_place)
		_orbit_rad = _behind_rad(_heading) + _side * PI * 0.25
	if (next.shot == Shot.MARK or mark_step >= 0) and runner.race != null and board >= 0:
		_set_the_mark(runner.race, board, mark_step)
	_show_lines(next.shot == Shot.COMMITTEE or next.shot == Shot.FINISH_LINE)
	if next.shot == Shot.BEACH_WIDE or next.shot == Shot.BEACH_TIGHT:
		_place_the_beach_cam(next, at, node)
	elif next.shot == Shot.PULL_OUT:
		_stand_look = at
	var fields: Dictionary[String, String] = {"picture": next.key(), "shot": Shot.keys()[next.shot], "camera": next.camera_kind(),
		"view": next.view, "on": next.on, "move": next.move}
	fields["sail_wanted_pct"] = "%.1f" % (sail_share * 100.0)
	fields["horizon_wanted_pct"] = "%.1f" % (horizon_share * 100.0)
	_log_the_take(fields)


## The mark a MARK picture waits at, and the side it stands on: the outside of the turn (the boards
## gybe away from it), or either side when the course goes on from there no other way.
func _set_the_mark(race: RaceSim, board: int, mark_step: int) -> void:
	var step_number: int = mark_step if mark_step >= 0 else race.next_step_index(board)
	var steps: Array[RaceStep] = race.steps()
	if step_number < 0 or step_number >= steps.size():
		return
	var mark: RaceStep = steps[step_number]
	_mark_at = mark.target()
	_mark_in = mark.in_dir
	_mark_out = steps[step_number + 1].in_dir if step_number + 1 < steps.size() else mark.in_dir
	_mark_steps = step_number
	if step_number + 1 < steps.size():
		var out: Vector2 = steps[step_number + 1].in_dir
		var turn: float = _mark_in.x * out.y - _mark_in.y * out.x
		if absf(turn) > 0.05:
			# A turn to starboard (turn > 0 on the game's ground plane) has its outside to port.
			_side = -signf(turn)


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


# ---------------------------------------------------------------- the camera

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
			if picture != null:
				cut_to(picture, watched, INF)
			else:
				_cut(shot, watched)
	var node: WindsurferNode = runner.board_node(focus) if focus >= 0 else runner.followed_node()
	if node == null:
		node = runner.followed_node()
	if node == null:
		return
	_age_s += delta
	var board: Transform3D = node.get_global_transform_interpolated()
	var turn_s: float = old.chase_turn_s if shot == Shot.CHASE and picture == null else old.turn_s
	_heading = _glide_vector(_heading, _forward_of(board), delta, turn_s)
	var wanted: PackedVector3Array
	var glide_s: float = old.glide_of(shot)
	var eye: Vector3
	if picture != null:
		_follow_the_rig(node, board, delta)
		wanted = _place_picture(board.origin)
		glide_s = picture.glide_s
		if picture.is_lens_camera():
			eye = wanted[0] if _stand_on_marker else _keep_above_ground(wanted[0], board.origin.y, stream.lens_lowest_m, stream.lens_lowest_m)
		else:
			eye = _keep_above_ground(wanted[0], board.origin.y, stream.lowest_m, stream.above_land_m)
	else:
		wanted = _place(shot, board.origin, delta)
		_fov_now = old.fov_of(shot)
		eye = _keep_above_ground(wanted[0], board.origin.y, old.lowest_m, old.above_land_m)
	var camera: Camera3D = rig.camera
	if _snap:
		_eye = eye
		_look = wanted[1]
		_snap = false
	else:
		_eye = _eye.lerp(eye, 1.0 - exp(-delta / glide_s))
		_look = _look.lerp(wanted[1], 1.0 - exp(-delta / old.look_glide_s))
	# The picture's shares are of its height: the lens keeps its height in any window shape.
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	camera.fov = _fov_now
	camera.global_position = _eye
	if _eye.distance_to(_look) < 0.01:
		return
	# Looking straight down (the overhead drone) the picture's top is the way the drone has turned to.
	var up: Vector3 = Vector3.UP
	if shot == Shot.OVERHEAD or absf((_look - _eye).normalized().dot(Vector3.UP)) > 0.995:
		up = Vector3(sin(_orbit_rad), 0.0, cos(_orbit_rad))
	camera.look_at(_look, up)
	if take_log != null and auto:
		_measure(camera, node, board)


## Where a 12 November shot wants the camera and what it looks at: [eye, look].
func _place(which: Shot, at: Vector3, delta: float) -> PackedVector3Array:
	var zoom: float = rig.directed_zoom
	var forward: Vector3 = _heading
	var right: Vector3 = forward.cross(Vector3.UP)
	var up: Vector3 = Vector3.UP
	match which:
		Shot.CHASE:
			var eye: Vector3 = at - forward * old.chase_back_m * zoom + right * _side * old.chase_side_m * zoom + up * old.chase_up_m * zoom
			return PackedVector3Array([eye, at + forward * old.chase_ahead_m + up * old.look_up_m])
		Shot.TRACK:
			var along: float = lerpf(old.track_along_m, -old.track_along_m, clampf(_age_s / old.track_pass_s, 0.0, 1.0))
			var eye: Vector3 = at + right * _side * old.track_side_m * zoom + forward * along + up * old.track_up_m * zoom
			return PackedVector3Array([eye, at + up * old.look_up_m])
		Shot.ORBIT:
			if circling:
				_orbit_rad += _side * old.orbit_drift_rad_s * delta
			var middle: Vector3 = _group_middle(at)
			return PackedVector3Array([middle + orbit_offset(_orbit_rad, old.orbit_elevation_rad, old.orbit_m * zoom), middle + up * old.orbit_look_up_m])
		Shot.OVERHEAD:
			_orbit_rad += _side * old.overhead_turn_rad_s * delta
			return PackedVector3Array([at + up * old.overhead_m * zoom, at])
		Shot.GROUP:
			var group: Vector4 = _group(at)
			var middle: Vector3 = Vector3(group.x, group.y, group.z)
			# The group well inside the picture (the lens's 34 degrees: some 70 degrees across on 16:9).
			var distance_m: float = clampf(group.w * old.group_reach_times + old.group_extra_m, old.group_nearest_m, old.group_farthest_m) * zoom
			var side_rad: float = _behind_rad(forward) + _side * old.group_side_rad
			return PackedVector3Array([middle + orbit_offset(side_rad, old.group_elevation_rad, distance_m), middle + up * old.look_up_m])
		Shot.MARK:
			var mark: Vector3 = Vector3(_mark_at.x, at.y, _mark_at.y)
			var into: Vector3 = Vector3(_mark_in.x, 0.0, _mark_in.y)
			if into.length() < 0.01:
				into = forward
			into = into.normalized()
			var beside: Vector3 = into.cross(Vector3.UP)
			var eye: Vector3 = mark + into * old.mark_beyond_m * zoom + beside * _side * old.mark_side_m * zoom + up * old.mark_up_m * zoom
			return PackedVector3Array([eye, mark.lerp(at, old.mark_look_share) + up * 1.0])
		Shot.START_WIDE:
			var line: PackedVector3Array = _line(CourseMark.START_BOAT, CourseMark.START_PIN, at.y)
			if line.is_empty():
				return _place(Shot.ORBIT, at, delta)
			var middle: Vector3 = (line[0] + line[1]) * 0.5
			var course_way: Vector3 = _first_leg()
			var along_line: Vector3 = (line[0] - line[1]).normalized()
			var eye: Vector3 = middle - course_way * old.start_back_m * zoom + along_line * sin(_age_s * old.start_sway_rad_s) * old.start_sway_m + up * old.start_up_m * zoom
			return PackedVector3Array([eye, middle + course_way * old.start_look_past_m])
		Shot.COMMITTEE, Shot.FINISH_LINE:
			var ends: PackedVector3Array = _line(CourseMark.START_BOAT if which == Shot.COMMITTEE else CourseMark.FINISH_BOAT,
				CourseMark.START_PIN if which == Shot.COMMITTEE else CourseMark.FINISH_PIN, at.y)
			if ends.is_empty():
				return _place(Shot.ORBIT, at, delta)
			return line_view(ends[0], ends[1], old)
	return PackedVector3Array([at + up * 10.0, at])


## Where one of the stream's pictures wants the camera and what it looks at: [eye, look]; it sets the
## lens (_fov_now). The framing comes from the take's sail and horizon shares (the wheel's zoom makes
## the sail smaller or bigger; the horizon stays), the lens and the board's real mast.
func _place_picture(at: Vector3) -> PackedVector3Array:
	var top_m: float = _top_m
	var wanted: float = sail_share / maxf(rig.directed_zoom, 0.05)
	var subject: float = picture.subject_share(wanted, horizon_share)
	match picture.shot:
		Shot.MARK:
			var place: Vector3 = TvFraming.drone_place(picture.lens_deg, top_m, wanted, horizon_share, subject, stream.lowest_m, _lean_toward(_eye - at))
			_fov_now = picture.lens_deg
			var mark: Vector3 = Vector3(_mark_at.x, at.y, _mark_at.y)
			# A drone ahead of the boards or abeam of them stands round their way into the mark; one behind
			# them round their way out: there the leader comes towards it, gybes at the buoy and sails away
			# (round the way in it would see the leader only once it had passed).
			var leg: Vector2 = _mark_in if picture.angle_deg >= 90.0 else _mark_out
			var way: Vector3 = Vector3(leg.x, 0.0, leg.y)
			if way.length() < 0.01:
				way = _heading
			var eye: Vector3 = mark + TvFraming.offset_round(way, picture.angle_deg, _side, place.x, place.y)
			# Panning keeps the buoy and the board in the picture; a static drone looks at the buoy.
			var toward: Vector3 = mark.lerp(at, old.mark_look_share) if picture.move == "pan" else mark
			return PackedVector3Array([eye, TvFraming.aim_point(eye, toward, place.z)])
		Shot.COMMITTEE, Shot.FINISH_LINE:
			var ends: PackedVector3Array = _line(CourseMark.START_BOAT if picture.shot == Shot.COMMITTEE else CourseMark.FINISH_BOAT,
				CourseMark.START_PIN if picture.shot == Shot.COMMITTEE else CourseMark.FINISH_PIN, at.y)
			if ends.is_empty():
				return _follow(at, top_m, wanted, subject)
			var round_deg: float = stream.line_drone_angle_deg if picture.shot == Shot.COMMITTEE else 0.0
			return _line_end_view(ends[0], ends[1], top_m, wanted, subject, _lean_toward(_eye - at), round_deg)
		Shot.BEACH_WIDE, Shot.BEACH_TIGHT:
			return _beach_view(at, top_m, wanted, subject)
		Shot.PULL_OUT:
			# Rising and going back over the spot it began at: the horizon stays, the scene grows.
			var progress: float = clampf(_age_s / maxf(_take_s, 1.0), 0.0, 1.0)
			var place: Vector3 = TvFraming.drone_place(picture.lens_deg, top_m, wanted, horizon_share, subject, stream.lowest_m)
			_fov_now = picture.lens_deg
			var grow: float = lerpf(1.0, stream.pull_out_times, progress)
			var eye: Vector3 = _stand_look + TvFraming.offset_round(_heading, picture.angle_deg, _side, place.x * grow, (place.y - top_m * 0.5) * grow + top_m * 0.5)
			return PackedVector3Array([eye, TvFraming.aim_point(eye, _stand_look, place.z)])
	return _follow(at, top_m, wanted, subject)


## A drone that travels with the board at the picture's angle round it.
func _follow(at: Vector3, top_m: float, wanted: float, subject: float) -> PackedVector3Array:
	var toward: float = _lean_toward(TvFraming.offset_round(_heading, picture.angle_deg, _side, 1.0, 0.0))
	var place: Vector3 = TvFraming.drone_place(picture.lens_deg, top_m, wanted, horizon_share, subject, stream.lowest_m, toward)
	_fov_now = picture.lens_deg
	var eye: Vector3 = at + TvFraming.offset_round(_heading, picture.angle_deg, _side, place.x, place.y)
	return PackedVector3Array([eye, TvFraming.aim_point(eye, at, place.z)])


## The view down a line from beyond its boat's end, the line's middle framed: the stream's low drone at
## the end of the start line (Max's committee boat view), and its drone side-on at the finish.
## `round_deg`: how far round from the line's own line it stands, towards the course side (the start's
## line drone: TvDirectorConfig.line_drone_angle_deg). It stays beyond the boat (the line never runs
## under it), so on a long line a sail at the middle may be smaller than asked.
func _line_end_view(boat: Vector3, pin: Vector3, top_m: float, wanted: float, subject: float, toward_m: float, round_deg: float) -> PackedVector3Array:
	var place: Vector3 = TvFraming.drone_place(picture.lens_deg, top_m, wanted, horizon_share, subject, stream.lowest_m, toward_m)
	_fov_now = picture.lens_deg
	var middle: Vector3 = (boat + pin) * 0.5
	var along: Vector3 = Vector3(boat.x - pin.x, 0.0, boat.z - pin.z)
	var half_m: float = along.length() * 0.5
	along = along.normalized() if along.length() > 0.01 else Vector3.BACK
	# The course side: the way the boards cross the start line, square to the line.
	var course: Vector3 = _first_leg()
	course = (course - along * course.dot(along))
	course = course.normalized() if course.length() > 0.01 else along.cross(Vector3.UP)
	var round_rad: float = deg_to_rad(round_deg)
	var away: Vector3 = along * cos(round_rad) + course * sin(round_rad)
	var distance_m: float = maxf(place.x, (half_m + stream.lowest_m * 4.0) / maxf(cos(round_rad), 0.2))
	var eye: Vector3 = middle + away * distance_m + Vector3.UP * place.y
	return PackedVector3Array([eye, TvFraming.aim_point(eye, middle, place.z)])


## The beach cam: it stands where it was put at the cut (_place_the_beach_cam()); its zoom and height
## follow the board (a pan), or stay as they were at the cut on what it looked at then (a static one).
func _beach_view(at: Vector3, top_m: float, wanted: float, subject: float) -> PackedVector3Array:
	var toward: Vector3 = at if picture.move == "pan" else _stand_look
	var level_m: float = Vector2(toward.x - _stand.x, toward.z - _stand.z).length()
	var lens: Vector3 = _stand_fov
	if picture.move == "pan" or rig.directed_zoom != 1.0 or lens.x <= 0.0:
		lens = TvFraming.lens_place(level_m, top_m, wanted, horizon_share, subject, _stand_eye_m, _stand_eye_m, stream.lens_min_deg, stream.lens_max_deg)
	_fov_now = lens.x
	var eye: Vector3 = Vector3(_stand.x, at.y + lens.y, _stand.z)
	return PackedVector3Array([eye, TvFraming.aim_point(eye, toward, lens.z)])


## The beach cam's place for this take: on a map with land (its shore_grid) the water's edge of the
## nearest shore round what it films, a side view preferred; where no shore is in reach (the open sea,
## a coast too far off) a camera boat off the course; never with a board close in front of it (it
## would fill the picture). What it films: the board, the start line's middle (on the line), the
## fleet's middle (on the fleet). `directions`: the views it prefers, best first.
func _place_the_beach_cam(next: TvPicture, at: Vector3, node: WindsurferNode) -> void:
	var subject: Vector3 = at
	var directions: Array[Vector3] = []
	var line: PackedVector3Array = _line(CourseMark.START_BOAT, CourseMark.START_PIN, at.y)
	if next.on == "line" and not line.is_empty():
		subject = (line[0] + line[1]) * 0.5
		var along: Vector3 = (line[1] - line[0]).normalized()
		# Along the line from beyond the pin first (the long lens stacks the boards on it), then the boat's
		# end; a little round from the line's own line, so the mark at its end is not in front of its middle.
		directions = [along.rotated(Vector3.UP, 0.4), along.rotated(Vector3.UP, -0.4), -along.rotated(Vector3.UP, 0.4), -along.rotated(Vector3.UP, -0.4)]
	elif next.on == "fleet" and runner.race != null:
		subject = fleet_middle(at.y)
		var across: Vector3 = _first_leg().cross(Vector3.UP)
		directions = [across, -across, across.rotated(Vector3.UP, 0.6), -across.rotated(Vector3.UP, 0.6)]
	else:
		# The board from the side (both sides), then further round.
		var beam: Vector3 = _heading.cross(Vector3.UP) * _side
		for turn_rad: float in [0.0, PI, 0.5, PI + 0.5, -0.5, PI - 0.5, 1.0, PI + 1.0]:
			directions.append(beam.rotated(Vector3.UP, turn_rad))
	_stand_look = subject
	var marker: Node3D = _shore_camera_marker(subject)
	var grid: TerrainGrid = scene.shore_grid if scene != null else null
	if marker != null and grid != null and view_blocked(grid, marker.global_position, subject):
		# The map's camera can't see the water where the subject is (a point of land in the way): this take
		# from the nearest shore with a clear view instead.
		marker = null
	_stand_on_marker = marker != null
	if marker != null:
		# Where the map says its beach camera stands: its eye there, as high as the marker.
		_stand = marker.global_position
		_stand_eye_m = marker.global_position.y - at.y
	else:
		var boat_m: float = stream.boat_wide_m if next.shot == Shot.BEACH_WIDE else stream.boat_tight_m
		_stand = _shore_or_boat(subject, directions, boat_m)
		_stand_eye_m = stream.beach_eye_m
	_stand_fov = Vector3.ZERO
	if next.move != "pan" and node != null:
		var level_m: float = Vector2(subject.x - _stand.x, subject.z - _stand.z).length()
		_stand_fov = TvFraming.lens_place(level_m, _rig_top(node).y, sail_share, horizon_share, next.subject_share(sail_share, horizon_share),
			_stand_eye_m, _stand_eye_m, stream.lens_min_deg, stream.lens_max_deg)


## The map's beach camera nearest a point (a Marker3D in the group SHORE_CAMERA_GROUP), or null.
func _shore_camera_marker(near: Vector3) -> Node3D:
	if rig == null or not rig.is_inside_tree():
		return null
	var best: Node3D = null
	for node: Node in rig.get_tree().get_nodes_in_group(SHORE_CAMERA_GROUP):
		var marker: Node3D = node as Node3D
		if marker != null and (best == null or marker.global_position.distance_to(near) < best.global_position.distance_to(near)):
			best = marker
	return best


## Where the beach cam can stand: on a map with land, the water's edge of the shore round the subject
## (looked for all the way round, every 30 degrees: a lake's shore, or a coast on one side only), the
## nearest one counting a view off the preferred `directions` as farther (half as far again at the
## opposite side); else a camera boat boat_m off in the first preferred direction that is on the water
## with a clear view. A place with a board close in front of it is passed over.
func _shore_or_boat(subject: Vector3, directions: Array[Vector3], boat_m: float) -> Vector3:
	var grid: TerrainGrid = scene.shore_grid if scene != null else null
	if grid != null:
		var best: Vector3 = Vector3(NAN, NAN, NAN)
		var best_score: float = INF
		for step: int in 12:
			var direction: Vector3 = directions[0].rotated(Vector3.UP, step * PI / 6.0)
			var shore: Vector3 = shore_along(grid, subject, direction, stream.shore_nearest_m, stream.shore_farthest_m)
			if is_nan(shore.x) or _board_in_the_way(shore, subject) or view_blocked(grid, shore + Vector3.UP * stream.beach_eye_m, subject):
				continue
			var score: float = subject.distance_to(shore) * (1.0 + 0.5 * view_off(direction, directions) / PI)
			if score < best_score:
				best_score = score
				best = shore
		if not is_nan(best.x):
			return best
	var first: Vector3 = Vector3(NAN, NAN, NAN)
	for direction: Vector3 in directions:
		var boat: Vector3 = subject + direction.normalized() * boat_m
		if grid != null and (_is_land(grid, boat) or land_between(grid, boat, subject)):
			continue
		if is_nan(first.x):
			first = boat
		if not _board_in_the_way(boat, subject):
			return boat
	return first if not is_nan(first.x) else subject + directions[0].normalized() * boat_m


## How far a direction is from the nearest of the preferred ones, radians (0 to PI).
static func view_off(direction: Vector3, preferred: Array[Vector3]) -> float:
	var least: float = PI
	for wanted: Vector3 in preferred:
		least = minf(least, absf(Vector2(direction.x, direction.z).angle_to(Vector2(wanted.x, wanted.z))))
	return least


## The water's edge from a point along a direction: the last water before the first land, between
## nearest_m and farthest_m; NAN when the land comes nearer, or not at all, or the map ends first.
static func shore_along(grid: TerrainGrid, from: Vector3, direction: Vector3, nearest_m: float, farthest_m: float) -> Vector3:
	var way: Vector3 = Vector3(direction.x, 0.0, direction.z).normalized()
	var step_m: float = 8.0
	var reach_m: float = step_m
	while reach_m <= farthest_m:
		var point: Vector3 = from + way * reach_m
		if not grid.contains(point.x, point.z):
			return Vector3(NAN, NAN, NAN)
		if _is_land(grid, point):
			if reach_m - step_m < nearest_m:
				return Vector3(NAN, NAN, NAN)
			return from + way * (reach_m - step_m)
		reach_m += step_m
	return Vector3(NAN, NAN, NAN)


## Whether land hides the water at a subject from a camera's eye (heights above the water): the ground
## anywhere on the way (every 8 m, the camera's own first 15 m left out: it stands on it) higher than
## the line from the eye down to the water at the subject.
static func view_blocked(grid: TerrainGrid, eye: Vector3, subject: Vector3) -> bool:
	var length_m: float = Vector2(subject.x - eye.x, subject.z - eye.z).length()
	var steps: int = ceili(length_m / 8.0)
	for i: int in range(1, steps):
		var share: float = float(i) / steps
		if share * length_m < 15.0:
			continue
		var at: Vector3 = eye.lerp(subject, share)
		var ground_m: float = grid.height_at(at.x, at.z)
		if not is_nan(ground_m) and ground_m > (eye.y - subject.y) * (1.0 - share):
			return true
	return false


## Land anywhere on the line from a camera to what it films (looked at every 8 m), on a lake's map.
static func land_between(grid: TerrainGrid, eye: Vector3, subject: Vector3) -> bool:
	var length_m: float = Vector2(subject.x - eye.x, subject.z - eye.z).length()
	var steps: int = ceili(length_m / 8.0)
	for i: int in range(1, steps):
		if _is_land(grid, eye.lerp(subject, float(i) / steps)):
			return true
	return false


static func _is_land(grid: TerrainGrid, point: Vector3) -> bool:
	var land_m: float = grid.height_at(point.x, point.z)
	return not is_nan(land_m) and land_m > 0.0


## A board close in front of a camera that films a subject: nearer the camera than blocking_share of
## the way and within blocking_m of the line of sight.
func _board_in_the_way(eye: Vector3, subject: Vector3) -> bool:
	var sight: Vector2 = Vector2(subject.x - eye.x, subject.z - eye.z)
	var length_m: float = sight.length()
	if length_m < 1.0 or runner.race == null:
		return false
	sight /= length_m
	for index: int in runner.watch_order():
		if index == focus:
			continue
		var there: Vector2 = runner.race.board_position(index) - Vector2(eye.x, eye.z)
		var along_m: float = there.dot(sight)
		if along_m > 0.0 and along_m < length_m * stream.blocking_share and absf(there.cross(sight)) < stream.blocking_m:
			return true
	return false


## The middle of the boards on the water, at the water's height.
func fleet_middle(water_y: float) -> Vector3:
	var sum: Vector2 = Vector2.ZERO
	var order: Array[int] = runner.watch_order()
	for index: int in order:
		sum += runner.race.board_position(index)
	sum /= maxf(order.size(), 1.0)
	return Vector3(sum.x, water_y, sum.y)


## The board's mast as it is drawn now: [its foot, its top] in the world (straight up from the board
## when the board has no drawn mast).
func _mast_points(node: WindsurferNode, board: Transform3D) -> PackedVector3Array:
	var mast: Node3D = _masts.get(node, null)
	if mast == null or not is_instance_valid(mast):
		mast = node.find_child("Mast", true, false) as Node3D
		_masts[node] = mast
	var mast_m: float = node.sim.sail_config.mast_m
	if mast == null:
		return PackedVector3Array([board.origin, board.origin + Vector3.UP * mast_m])
	var drawn: Transform3D = mast.get_global_transform_interpolated()
	return PackedVector3Array([drawn.origin, drawn.origin + drawn.basis.y.normalized() * mast_m])


## The sail's top against the board: Vector3(its lean level along the world's x, its height above the
## board's waterline, its lean along z), metres; the height kept between half the mast and the mast
## (a fallen rig does not bring the drone down to the water).
func _rig_top(node: WindsurferNode) -> Vector3:
	var board: Transform3D = node.get_global_transform_interpolated()
	var points: PackedVector3Array = _mast_points(node, board)
	var mast_m: float = node.sim.sail_config.mast_m
	return Vector3(points[1].x - points[0].x, clampf(points[1].y - board.origin.y, mast_m * 0.5, mast_m), points[1].z - points[0].z)


## The filmed sail's top, smoothed over about a second (a gybe flips the rig; the drone glides).
func _follow_the_rig(node: WindsurferNode, board: Transform3D, delta: float) -> void:
	var top: Vector3 = _rig_top(node)
	var blend: float = 1.0 if _snap else 1.0 - exp(-delta / 0.8)
	_top_m = lerpf(_top_m, top.y, blend)
	_top_lean = _top_lean.lerp(Vector3(top.x, 0.0, top.z), blend)


## How far the sail's top leans towards a camera that is this way from the board, m.
func _lean_toward(to_camera: Vector3) -> float:
	var level: Vector3 = Vector3(to_camera.x, 0.0, to_camera.z)
	return _top_lean.dot(level.normalized()) if level.length() > 0.01 else 0.0


## The picture's real framing this frame, for the take log: the sail of the board filmed, the horizon,
## the camera's height, distance and angle round the board.
func _measure(camera: Camera3D, node: WindsurferNode, board: Transform3D) -> void:
	var points: PackedVector3Array = _mast_points(node, board)
	var foot: Vector3 = points[0]
	var top: Vector3 = points[1]
	var shares: Vector3 = TvFraming.measure(camera.global_transform, camera.fov, foot, top)
	var eye: Vector3 = camera.global_position
	take_log.sample(shares.x, shares.y, shares.z, eye.y - board.origin.y, Vector2(eye.x - board.origin.x, eye.z - board.origin.z).length(),
		TvFraming.angle_round(_forward_of(board), board.origin, eye), camera.fov)


# ---------------------------------------------------------------- the take log

## A new take in the log: its fields, its phase and the filmed board's place.
func _log_the_take(fields: Dictionary[String, String]) -> void:
	if take_log == null or not auto:
		return
	var race: RaceSim = runner.race
	fields["director"] = director_name()
	fields["board"] = str(focus)
	fields["place"] = str(race.race_order().find(focus) + 1) if race != null and focus >= 0 else "0"
	if shot == Shot.MARK and race != null and focus >= 0 and next_is_a_mark(race, focus):
		# How long before its board reaches the mark the mark's take began (the stream: 2 to 5 s).
		var node: WindsurferNode = runner.board_node(focus)
		var speed_ms: float = maxf(node.telemetry().speed_ms if node != null else 0.0, 3.0)
		fields["to_mark_s"] = "%.2f" % (race.distance_to_next_m(focus) / speed_ms)
	_log_phase = _heat_phase_name()
	take_log.begin(_log_phase, race.clock_s() if race != null else 0.0, fields)


## The heat's phase now; a take that runs over a border is split there in the log.
func _note_the_phase() -> void:
	var now: String = _heat_phase_name()
	if now != _log_phase and _log_phase != "":
		take_log.split(now, runner.race.clock_s() if runner.race != null else 0.0)
	_log_phase = now


func _heat_phase_name() -> String:
	var race: RaceSim = runner.race
	if race == null:
		return "pre_start"
	var phase: int = TvStreamDirector.heat_phase(race.is_started(), race.clock_s(), race.phase() == RaceSim.Phase.FINISHED, _phase_borders.x, _phase_borders.y)
	return TvStreamDirector.PHASE_NAMES[phase]


## How a 12 November shot is written down in the readers' words: camera, view, what it is on, move.
func _shot_fields(which: Shot) -> Dictionary[String, String]:
	var view: String = "behind_side"
	var move: String = "follows"
	var on: String = "front"
	match which:
		Shot.TRACK:
			view = "side"
		Shot.ORBIT:
			view = "na"
			move = "orbit"
		Shot.OVERHEAD:
			view = "top_down"
		Shot.MARK:
			view = "front_side"
			move = "pan"
			on = "mark"
		Shot.START_WIDE:
			move = "static"
			on = "line"
		Shot.COMMITTEE, Shot.FINISH_LINE:
			view = "side"
			move = "static"
			on = "line"
	if on == "front" and runner.race != null and focus >= 0:
		# The leader, or a board of the lead group, is the front; any other board the pack.
		var order: Array[int] = runner.race.race_order()
		var place: int = order.find(focus)
		if place > 0 and runner.race.board_position(focus).distance_to(runner.race.board_position(order[0])) > old.group_m:
			on = "pack"
	return {"picture": "drone %s %s" % [view, on], "shot": Shot.keys()[which], "camera": "drone", "view": view, "on": on, "move": move,
		"sail_wanted_pct": "", "horizon_wanted_pct": ""}


# ---------------------------------------------------------------- helpers

## The committee boat's view down a line (12 November): from line_behind_m behind the boat on the
## line's line, line_up_m up, at the far end's mark (half a metre above the water), or on a line
## shorter than line_aim_m at a point that far down it: aimed at a near pin the camera tilts down and
## the boat's flag comes into the picture. [eye, look].
static func line_view(boat: Vector3, pin: Vector3, numbers: TvDirector12NovConfig) -> PackedVector3Array:
	var along: Vector3 = Vector3(pin.x - boat.x, 0.0, pin.z - boat.z)
	var length_m: float = along.length()
	along = along.normalized()
	var eye: Vector3 = boat - along * numbers.line_behind_m + Vector3.UP * numbers.line_up_m
	var aim: Vector3 = boat + along * maxf(length_m, numbers.line_aim_m) + Vector3.UP * 0.5
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


## The boats round the board watched (within group_m, racing): their middle (x, y, z) and how far the
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
			if Vector2(there.x - at.x, there.z - at.z).length() < old.group_m:
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


## Never under the water, nor into a lake's shore: at least lowest_m above the water and above_land_m
## above the land under it.
func _keep_above_ground(eye: Vector3, water_y: float, lowest_m: float, above_land_m: float) -> Vector3:
	var lowest: float = water_y + lowest_m
	var grid: TerrainGrid = scene.shore_grid if scene != null else null
	if grid != null:
		var land_m: float = grid.height_at(eye.x, eye.z)
		if not is_nan(land_m) and land_m > 0.0:
			lowest = maxf(lowest, water_y + land_m + above_land_m)
	return Vector3(eye.x, maxf(eye.y, lowest), eye.z)
