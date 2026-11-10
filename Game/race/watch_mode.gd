class_name WatchMode
extends Node
## Watching the AI race as their race director, for filming and for testing (Max, 10 November 2026:
## "a version only for AI watching and spectating, where I'm the race director. I want to video a few
## races so I can broadcast them to Michiel ... with a few features that are handy for filming and
## testing"). The sailing scene (main.gd) makes one when a race is watched on this PC alone (the Race
## page's "You: Watch", or --spectate=1; never in a LAN game): the player's board stays parked, the
## camera follows the AI boards (Tab, Shift+Tab and L as before) and M opens the race director.
## On top of that, keys for filming and for testing:
## - H: the screen: full (every card and the keys), TV (what a viewer needs: the race card, the
##   standings, the minimap, the speed card), clean (nothing: the water and the boards alone).
## - N: the names above the boards on or off.
## - T: the TV camera: it cuts by itself every SHOT_MIN_S to SHOT_MAX_S between the boards worth
##   watching (the leader, boards close together, a board coming to a mark, the start line in the
##   last half minute) and between shots (behind, beside, in front, high, overhead, the helicopter).
##   A camera key, Tab or L takes the camera back by hand.
## - 5: the helicopter: high and far, circling the board slowly (5 again: the circling stops or goes on).
## - minus and plus: slower and faster (SPEEDS), 0 the normal speed. Every physics tick stays 1/60 s
##   of the race (Engine.physics_ticks_per_second and Engine.time_scale change together, as NetBoards
##   slows a LAN guest), so the race is the same race at any speed; only the PC's work per second
##   changes. A big fleet at 4 or 8 times may be more than the PC can do: the race then goes as fast as
##   it can, and the card says how fast that is.
## - P: the race frozen (the camera still moves: the right mouse button and the wheel turn it, the
##   helicopter keeps circling); P again, Esc, R or M go on.
## - I: the AI's head of the board watched: what its skipper is doing (RaceSkipper.note, the words of
##   the training's race tool), its speed and angle to the wind, the way to its next mark.
## - Shift+R: the same race again: the same start spots and the same skippers' day (the race's dice;
##   the wind's gusts go on with their own clock). R a new race. The full screen shows the race's
##   number and dice; --seed=<dice> on the command line starts that race again.
## Command line: --tv=1 (the TV camera from the start), --screen=full|tv|clean, --speed=<x>, --head=1.

enum Screen { FULL, TV, CLEAN }
## The TV camera's shots (_apply_shot()).
enum Shot { FOLLOW, BEHIND_HIGH, BESIDE, FRONT, HELICOPTER, OVERHEAD }

## The speeds offered, times real time; NORMAL is the index of 1.
const SPEEDS: Array[float] = [0.25, 0.5, 1.0, 2.0, 4.0, 8.0]
const NORMAL: int = 2
## How long the TV camera stays on a shot, real seconds (the same pace in slow motion).
const SHOT_MIN_S: float = 6.0
const SHOT_MAX_S: float = 12.0
## The start on the TV camera: from this long before the gun until START_AFTER_S after it, one wide
## shot of the line.
const START_FROM_S: float = 30.0
const START_AFTER_S: float = 12.0
## What makes a board worth watching: another board this close (metres), its next mark this close.
const CLOSE_M: float = 25.0
const MARK_M: float = 70.0
## The helicopter (5, and the TV camera's widest shot): how far, how high (the angle above the
## water) and how fast it circles.
const HELICOPTER_M: float = 110.0
const HELICOPTER_ELEVATION_RAD: float = 0.55
const HELICOPTER_DRIFT_RAD_S: float = 0.04
## How far the orbit camera may be wheeled out while watching, metres (sailing: CameraRig's 60).
const ORBIT_MAX_M: float = 400.0
## The keys along the bottom of the full screen.
const KEYS: Array[Array] = [
	["Tab", "next board"],
	["L", "leader"],
	["1-5", "camera"],
	["T", "TV camera"],
	["- + 0", "speed"],
	["P", "freeze"],
	["H", "screen"],
	["N", "names"],
	["I", "AI's head"],
	["M", "race director"],
	["R / Shift+R", "new race / same again"],
	["Esc", "menu"],
]

var scene: SailingScene = null
var runner: RaceRunner = null
var hud: Hud = null
var rig: CameraRig = null

var screen: Screen = Screen.FULL
var names_shown: bool = true
var speed_index: int = NORMAL
var frozen: bool = false
var tv_on: bool = false
var head_shown: bool = false

## The project's ticks a second and steps a frame, put back when the watching ends.
var _normal_ticks: int = 60
var _normal_max_steps: int = 8
## The TV camera: the shot now, how long it has left (real seconds), whether the start's shot is on.
var _shot: Shot = Shot.FOLLOW
var _shot_left_s: float = 0.0
var _start_shot: bool = false
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
## The cameras as they were before the TV camera took them (put back when it stops).
var _camera_before: Dictionary[String, Variant] = {}
## The race's real pace: the race clock and the real clock at the last look, and the pace measured.
var _pace_clock_s: float = NAN
var _pace_real_us: int = 0
var _pace_measured: float = 1.0
var _last_real_us: int = 0
## The cards at the top left: the speed (and the race's number in the full screen) and the AI's head.
var _cards: VBoxContainer = null
var _corner: Label = null
var _corner_card: PanelContainer = null
var _head: Label = null
var _head_card: PanelContainer = null


func _init() -> void:
	name = "WatchMode"
	# The keys and the cards work while the race is frozen.
	process_mode = Node.PROCESS_MODE_ALWAYS


func setup(sailing_scene: SailingScene, race_runner: RaceRunner, hud_layer: Hud, camera_rig: CameraRig) -> void:
	scene = sailing_scene
	runner = race_runner
	hud = hud_layer
	rig = camera_rig
	_rng.randomize()
	_normal_ticks = int(ProjectSettings.get_setting("physics/common/physics_ticks_per_second", 60))
	_normal_max_steps = int(ProjectSettings.get_setting("physics/common/max_physics_steps_per_frame", 8))
	rig.orbit_max_m = ORBIT_MAX_M
	_build_cards()
	hud.set_watch_keys(KEYS)
	runner.restarted.connect(_on_new_race)
	_read_options()
	_last_real_us = Time.get_ticks_usec()
	_on_new_race()


func _exit_tree() -> void:
	# The menu and the next scene run at the normal speed, unfrozen.
	Engine.physics_ticks_per_second = _normal_ticks
	Engine.time_scale = 1.0
	Engine.max_physics_steps_per_frame = _normal_max_steps
	if frozen and is_inside_tree():
		get_tree().paused = false


## --tv=1, --screen=full|tv|clean, --speed=<x>, --head=1.
func _read_options() -> void:
	for arg: String in OS.get_cmdline_user_args():
		var value: String = arg.get_slice("=", 1)
		if arg.begins_with("--tv="):
			if value == "1":
				set_tv(true)
		elif arg.begins_with("--screen="):
			set_screen(Screen.TV if value == "tv" else (Screen.CLEAN if value == "clean" else Screen.FULL))
		elif arg.begins_with("--speed="):
			set_speed(nearest_speed(value.to_float()))
		elif arg.begins_with("--head="):
			head_shown = value == "1"


# ---------------------------------------------------------------- the keys

## The scene hands every key here first while watching (also while frozen). True when it was taken.
func handle_input(event: InputEvent) -> bool:
	var key: InputEventKey = event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return false
	match key.physical_keycode:
		KEY_H:
			set_screen(((screen + 1) % 3) as Screen)
		KEY_N:
			names_shown = not names_shown
			_say("Names above the boards: %s" % ("on" if names_shown else "off"))
		KEY_T:
			set_tv(not tv_on)
			_say("TV camera on: it picks the boards and the shots. A camera key, Tab or L: back to your own." if tv_on else "TV camera off.")
		KEY_P:
			set_frozen(not frozen)
		KEY_MINUS, KEY_KP_SUBTRACT:
			set_speed(speed_index - 1)
		KEY_EQUAL, KEY_KP_ADD:
			set_speed(speed_index + 1)
		KEY_0, KEY_KP_0:
			set_speed(NORMAL)
		KEY_I:
			head_shown = not head_shown
		KEY_5, KEY_KP_5:
			_stop_tv_by_hand()
			if rig.mode == CameraRig.Mode.ORBIT and rig.orbit_distance_m >= HELICOPTER_M * 0.9:
				# The helicopter already: 5 stops or starts its circling.
				rig.orbit_drift_rad_s = 0.0 if rig.orbit_drift_rad_s != 0.0 else HELICOPTER_DRIFT_RAD_S
			else:
				_helicopter(_followed_yaw() + PI * 0.25, HELICOPTER_DRIFT_RAD_S)
		KEY_R:
			set_frozen(false)
			if not key.shift_pressed:
				return false  # the scene's R: a new race
			same_race_again()
		KEY_1, KEY_2, KEY_3, KEY_4, KEY_TAB, KEY_L:
			# The camera by hand again; the scene does the rest.
			_stop_tv_by_hand()
			rig.orbit_drift_rad_s = 0.0
			return false
		KEY_ESCAPE, KEY_M:
			# The menu or the race director: the race goes on first.
			set_frozen(false)
			return false
		_:
			return false
	return true


## The screen: full, TV or clean.
func set_screen(level: Screen) -> void:
	screen = level
	hud.set_tv_screen(screen == Screen.TV)
	runner.hud.plain_title = screen != Screen.FULL
	_apply_screen()


func _apply_screen() -> void:
	if not scene.director_view_open():
		hud.visible = screen != Screen.CLEAN


## Slower or faster: SPEEDS[index] times real time, each tick still 1/60 s of the race.
func set_speed(index: int) -> void:
	speed_index = clampi(index, 0, SPEEDS.size() - 1)
	var pace: Vector2 = pace_for(SPEEDS[speed_index], _normal_ticks)
	Engine.physics_ticks_per_second = int(pace.x)
	Engine.time_scale = pace.y
	# Enough steps a frame for the speed at 30 frames a second (the race still goes no faster than the
	# PC can step it).
	Engine.max_physics_steps_per_frame = maxi(_normal_max_steps, ceili(pace.x / 30.0))
	_pace_clock_s = NAN


## The physics ticks a second and the time scale for a speed: the ticks scaled, and the time scale the
## same share, so each tick is 1 / normal_ticks s of the race (NetBoards' way).
static func pace_for(speed: float, normal_ticks: int) -> Vector2:
	var ticks: int = maxi(roundi(normal_ticks * speed), 1)
	return Vector2(ticks, float(ticks) / float(normal_ticks))


## The index of the offered speed nearest to `speed` (NORMAL for nonsense).
static func nearest_speed(speed: float) -> int:
	if speed <= 0.0:
		return NORMAL
	var best: int = NORMAL
	for i: int in SPEEDS.size():
		if absf(log(SPEEDS[i] / speed)) < absf(log(SPEEDS[best] / speed)):
			best = i
	return best


## "1/4", "1/2", "2", ... times.
static func speed_name(speed: float) -> String:
	if speed < 1.0:
		return "1/%d" % roundi(1.0 / speed)
	return "%d" % roundi(speed)


## The race frozen (the scene tree paused, no menu) or going on.
func set_frozen(on: bool) -> void:
	if on == frozen:
		return
	frozen = on
	get_tree().paused = on


func set_tv(on: bool) -> void:
	if on == tv_on:
		return
	tv_on = on
	if on:
		_camera_before = {"mode": rig.mode, "azimuth": rig.orbit_azimuth_rad, "elevation": rig.orbit_elevation_rad,
			"distance": rig.orbit_distance_m, "height": rig.top_down_height_m}
		_shot_left_s = 0.0
		_start_shot = false
	else:
		rig.orbit_drift_rad_s = 0.0
		if not _camera_before.is_empty():
			rig.orbit_azimuth_rad = _camera_before["azimuth"]
			rig.orbit_elevation_rad = _camera_before["elevation"]
			rig.orbit_distance_m = _camera_before["distance"]
			rig.top_down_height_m = _camera_before["height"]
			rig.set_mode(_camera_before["mode"])
		runner.follow_leader()


func _stop_tv_by_hand() -> void:
	if tv_on:
		tv_on = false
		_camera_before = {}
		_say("TV camera off (T: on again).")


## Shift+R: this race again with the same dice.
func same_race_again() -> void:
	runner.repeat_dice = runner.last_dice
	scene.restart_race()


func _on_new_race() -> void:
	_start_shot = false
	_shot_left_s = 0.0
	_pace_clock_s = NAN
	print("WATCH: race %d, dice %d (--seed=%d repeats its start spots and the skippers' day)" % [runner.race_number, runner.last_dice, runner.last_dice])


## A line in the middle of the full screen for a few seconds (the TV and clean screens keep quiet).
func _say(text: String) -> void:
	if screen == Screen.FULL:
		scene.show_net_message(text, 4.0)


# ---------------------------------------------------------------- every frame

func _process(_delta: float) -> void:
	var now_us: int = Time.get_ticks_usec()
	var real_dt: float = clampf((now_us - _last_real_us) / 1e6, 0.0, 0.25)
	_last_real_us = now_us
	_apply_screen()
	_show_names()
	_measure_pace(now_us)
	if tv_on and not frozen and not scene.director_view_open():
		_tv_step(real_dt)
	_update_cards()


## The names above the boards, as N says (the board watched never: the race card names it).
func _show_names() -> void:
	var watched: WindsurferNode = runner.followed_node()
	for node: WindsurferNode in runner.opponents:
		var label: Node3D = node.get_node_or_null("NameLabel") as Node3D
		if label != null:
			label.visible = names_shown and node != watched


## How fast the race really goes (race seconds a real second), over the last second or so.
func _measure_pace(now_us: int) -> void:
	var race: RaceSim = runner.race
	if race == null or frozen:
		_pace_clock_s = NAN
		return
	if is_nan(_pace_clock_s):
		_pace_clock_s = race.clock_s()
		_pace_real_us = now_us
		return
	var real_s: float = (now_us - _pace_real_us) / 1e6
	if real_s < 1.0:
		return
	_pace_measured = (race.clock_s() - _pace_clock_s) / real_s
	_pace_clock_s = race.clock_s()
	_pace_real_us = now_us


# ---------------------------------------------------------------- the cards

func _build_cards() -> void:
	_cards = VBoxContainer.new()
	_cards.name = "WatchCards"
	_cards.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cards.add_theme_constant_override("separation", 8)
	hud.add_part(_cards)
	_cards.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_cards.offset_left = Hud.MARGIN
	_cards.offset_top = Hud.MARGIN
	_corner_card = _card()
	_corner = HudStyle.label(HudStyle.sans(700), 15)
	_corner_card.add_child(_corner)
	_head_card = _card()
	_head = HudStyle.label(HudStyle.sans(500), 13)
	_head_card.add_child(_head)


func _card() -> PanelContainer:
	var card: PanelContainer = PanelContainer.new()
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_theme_stylebox_override("panel", HudStyle.card(10.0))
	card.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_cards.add_child(card)
	return card


func _update_cards() -> void:
	var lines: PackedStringArray = PackedStringArray()
	var speed: float = SPEEDS[speed_index]
	if frozen:
		lines.append("FROZEN   (P: go on)")
	elif speed_index != NORMAL:
		var pace: String = "%s× %s" % [speed_name(speed), "slow motion" if speed < 1.0 else "fast forward"]
		if speed > 1.0 and _pace_measured < speed * 0.9:
			pace += "   (this PC manages %.1f×)" % _pace_measured
		lines.append(pace)
	if screen == Screen.FULL:
		if tv_on:
			lines.append("TV camera")
		lines.append("Race %d   ·   dice %d" % [runner.race_number, runner.last_dice])
	_corner.text = "\n".join(lines)
	_corner_card.visible = not lines.is_empty()
	_head_card.visible = head_shown
	if head_shown:
		_head.text = head_text()


## The AI's head of the board watched (I): its name, what its skipper is doing, its speed and angle
## to the wind, the way to its next mark, its tacks, gybes and penalty turns.
func head_text() -> String:
	var race: RaceSim = runner.race
	var index: int = runner.followed_index()
	if race == null or index < 0:
		return "Nobody on the water to watch."
	var node: WindsurferNode = runner.followed_node()
	var t: Telemetry = node.telemetry()
	var lines: PackedStringArray = PackedStringArray()
	lines.append("%s: the AI's head" % race.board_name(index))
	var skipper: RaceSkipper = node.skipper
	lines.append(skipper.note if skipper != null and skipper.note != "" else "-")
	lines.append("%.1f kt   ·   %.0f° off the wind   ·   %s" % [t.speed_kt, absf(t.twa_deg), "planing" if t.is_planing else "not planing"])
	if race.is_finished(index):
		lines.append("Finished, %s" % RaceHud.watch_place_text(race, index))
	else:
		lines.append("To %s: %.0f m" % [race.next_step_name(index), race.distance_to_next_m(index)])
	var scripted: Skipper = skipper as Skipper
	if scripted != null:
		lines.append("Tacks %d   ·   gybes %d   ·   penalty turns %d" % [scripted.tacks, scripted.gybes, scripted.penalty_turns])
	return "\n".join(lines)


# ---------------------------------------------------------------- the TV camera

func _tv_step(real_dt: float) -> void:
	var race: RaceSim = runner.race
	if race == null or runner.watch_order().is_empty():
		return
	_shot_left_s -= real_dt
	var at_start: bool = race.is_started() and race.clock_s() >= -START_FROM_S and race.clock_s() <= START_AFTER_S
	if at_start and not _start_shot:
		_start_shot = true
		_cut_to_the_start(race)
		return
	if at_start:
		return  # the start's shot holds until START_AFTER_S after the gun
	var watched: int = runner.followed_index()
	var gone: bool = watched < 0 or not runner.watch_order().has(watched)
	if _shot_left_s > 0.0 and not gone:
		return
	_cut(race)


## The start: the board nearest the middle of the line, from high behind the line (the fleet and the
## line in the picture), until just after the gun.
func _cut_to_the_start(race: RaceSim) -> void:
	var middle: Vector2 = runner.course.start_middle()
	var best: int = -1
	var best_m: float = INF
	for index: int in runner.watch_order():
		var m: float = race.board_position(index).distance_to(middle)
		if m < best_m:
			best_m = m
			best = index
	if best < 0:
		return
	runner.watch_board(best)
	_shot = Shot.HELICOPTER
	_helicopter(_yaw_of(runner.board_node(best)) + PI * 0.2, HELICOPTER_DRIFT_RAD_S * 0.5)
	rig.orbit_distance_m = HELICOPTER_M * 0.8
	# It holds while the start is on (_tv_step()); the next shot comes as soon as it is over.
	_shot_left_s = 0.0


## A new shot: a board worth watching (story_weights()) and a way to look at it.
func _cut(race: RaceSim) -> void:
	var order: Array[int] = runner.watch_order()
	var positions: PackedVector2Array = PackedVector2Array()
	var to_mark: PackedFloat32Array = PackedFloat32Array()
	var finished: PackedByteArray = PackedByteArray()
	for index: int in order:
		positions.append(race.board_position(index))
		to_mark.append(race.distance_to_next_m(index) if race.phase() == RaceSim.Phase.RACING else INF)
		finished.append(1 if race.is_finished(index) or race.is_retired(index) else 0)
	var weights: PackedFloat32Array = story_weights(positions, to_mark, finished, order.find(runner.followed_index()))
	var pick: int = order[_rng.rand_weighted(weights)]
	runner.watch_board(pick)
	var at: int = order.find(pick)
	var near_mark: bool = to_mark[at] < MARK_M
	_shot = _pick_shot(near_mark, _shot)
	_apply_shot(_shot, runner.board_node(pick))
	_shot_left_s = _rng.randf_range(SHOT_MIN_S, SHOT_MAX_S)


## How much each board (in the watch order, the leader first) is worth a shot: the leader, a board
## close to another, a board near its next mark more; a finished board little; the board on the screen
## now little (the camera moves on). Plain numbers in, so the tests can drive it.
static func story_weights(positions: PackedVector2Array, to_mark: PackedFloat32Array, finished: PackedByteArray, shown: int) -> PackedFloat32Array:
	var weights: PackedFloat32Array = PackedFloat32Array()
	for i: int in positions.size():
		var weight: float = 1.0
		if i == 0:
			weight += 2.0
		for j: int in positions.size():
			if j != i and finished[j] == 0 and positions[i].distance_to(positions[j]) < CLOSE_M:
				weight += 3.0
				break
		if to_mark[i] < MARK_M:
			weight += 4.0
		if finished[i] != 0:
			weight = 0.2
		if i == shown and positions.size() > 1:
			weight *= 0.15
		weights.append(weight)
	return weights


## The next shot, not the same as the last; near a mark one that shows the mark too (from high or above).
func _pick_shot(near_mark: bool, last: Shot) -> Shot:
	var shots: Array[Shot] = [Shot.FOLLOW, Shot.BEHIND_HIGH, Shot.BESIDE, Shot.FRONT, Shot.HELICOPTER, Shot.OVERHEAD]
	var weights: PackedFloat32Array = PackedFloat32Array([2.0, 2.0, 3.0, 1.5, 1.0, 1.0])
	if near_mark:
		weights = PackedFloat32Array([0.5, 3.0, 1.0, 0.5, 2.0, 2.0])
	weights[shots.find(last)] = 0.0
	return shots[_rng.rand_weighted(weights)]


func _apply_shot(shot: Shot, node: WindsurferNode) -> void:
	var yaw: float = _yaw_of(node)
	var side: float = 1.0 if _rng.randf() < 0.5 else -1.0
	rig.orbit_drift_rad_s = 0.0
	match shot:
		Shot.FOLLOW:
			rig.set_mode(CameraRig.Mode.FOLLOW)
		Shot.BEHIND_HIGH:
			_orbit(yaw + side * _rng.randf_range(0.2, 0.6), 0.45, 30.0, side * 0.04)
		Shot.BESIDE:
			_orbit(yaw + side * PI * 0.5, 0.12, 16.0, side * 0.03)
		Shot.FRONT:
			_orbit(yaw + PI + side * _rng.randf_range(0.3, 0.7), 0.18, 14.0, 0.0)
		Shot.HELICOPTER:
			_helicopter(yaw + side * PI * 0.25, side * HELICOPTER_DRIFT_RAD_S)
		Shot.OVERHEAD:
			rig.top_down_height_m = 80.0
			rig.set_mode(CameraRig.Mode.TOP_DOWN)


func _orbit(azimuth_rad: float, elevation_rad: float, distance_m: float, drift_rad_s: float) -> void:
	rig.set_mode(CameraRig.Mode.ORBIT)
	rig.orbit_azimuth_rad = azimuth_rad
	rig.orbit_elevation_rad = elevation_rad
	rig.orbit_distance_m = distance_m
	rig.orbit_drift_rad_s = drift_rad_s


func _helicopter(azimuth_rad: float, drift_rad_s: float) -> void:
	_orbit(azimuth_rad, HELICOPTER_ELEVATION_RAD, HELICOPTER_M, drift_rad_s)


## The board's heading as the orbit camera's azimuth: this azimuth puts the camera right behind it.
static func _yaw_of(node: WindsurferNode) -> float:
	if node == null:
		return 0.0
	var forward: Vector3 = -node.global_transform.basis.z
	return atan2(-forward.x, -forward.z)


func _followed_yaw() -> float:
	return _yaw_of(runner.followed_node())
