class_name RaceMirror
extends Node
## The host's race on the guest's PC (LAN multiplayer, Documentation/reports/multiplayer/PLAN.md, D8).
## The host's RaceRunner races and judges every board; this node shows that race on the guest's HUD
## exactly as the host has it: the same RaceSim and RaceRules, filled from the host's state ten times
## a second (take_state()) and moved on in between (RaceSim.mirror_step(): the clock runs, the
## places follow the boards, nothing is judged here).
##
## It also gives the guest's board the other sails' wind shadows, from where every board is on this
## PC, as the host's RaceRunner does for its boards (before the board steps: process priority -5).
##
## The race director (RACE_DIRECTOR.md): the host's course changes come in as a course
## (update_course()); what the director decided (the next countdown, a note) comes with the race's
## state and shows on the RaceNotice line. A guest who joined while a race was on is not in it
## (my_index() -1): it sails with the plain HUD and the line says it races from the next start.

## A start signal is due on the host's race clock (SO3, as RaceRunner.start_signal): the guest
## hears the horns, the beeps and the gun too.
signal start_signal(kind: RaceStartSignals.Kind)

var race: RaceSim = null
var rules: RaceRules = null
var hud: RaceHud = null
var course: Course = null
var race_setup: RaceSetup = null
var _hud_layer: Hud = null
var _own: WindsurferNode = null
var _net: NetBoards = null
## The race's boards in the host's order (their network numbers), and the guest's own place in it.
var _ids: Array[int] = []
var _my_index: int = -1
var _shadows: WindShadows = null
## The start's signals of the host's current start (SO3).
var _start_signals: RaceStartSignals = null
## What the host's race director decided (RaceDirector.info()), and its line on the screen.
var director: Dictionary = {}
## The host's number of the race shown (RaceRunner.race_number).
var race_number: int = 0
var _notice: RaceNotice = null
## Whether the race HUD is on the screen (off while this PC's player is not in the race).
var _racing_hud: bool = true


func _init() -> void:
	process_physics_priority = -5


## The race on this PC's HUD, waiting for the host's first start (restart()).
func setup(race_course: Course, setup_of_race: RaceSetup, hud_layer: Hud, own: WindsurferNode, net: NetBoards) -> void:
	course = race_course
	race_setup = setup_of_race
	_hud_layer = hud_layer
	_own = own
	_net = net
	process_mode = Node.PROCESS_MODE_ALWAYS
	hud = RaceHud.new()
	hud.name = "RaceHud"
	hud_layer.add_child(hud)
	hud_layer.set_race_mode(true, false)
	hud_layer.set_detail_visible(false)
	if race_setup.shadows:
		_shadows = WindShadows.make()
	_notice = RaceNotice.new()
	hud_layer.add_child(_notice)


## The host's new start: its boards in its order, a new race and judge.
func restart(info: Dictionary) -> void:
	race = RaceSim.new(course, int(info.get("laps", race_setup.laps)), float(info.get("prestart_s", race_setup.prestart_s)))
	race_number = int(info.get("race_no", 0))
	race.time_limit_s = float(info.get("time_limit_s", race.time_limit_s))
	var names: PackedStringArray = PackedStringArray(info.get("names", PackedStringArray()))
	_ids.clear()
	for id: Variant in info.get("ids", []):
		_ids.append(int(id))
	_my_index = _ids.find(Lan.my_slot)
	for i: int in names.size():
		# This PC's player is "You" on its own screen, as in a race alone.
		race.add_board(RaceRunner.PLAYER_NAME if i == _my_index else names[i])
	rules = RaceRules.new(race.board_count(), course.axis_deg) if bool(info.get("rules", race_setup.rules)) else null
	_start_signals = RaceStartSignals.new(race.prestart_s)
	hud.reset()
	_show_racing_hud(_my_index >= 0)


## The race director's changed course (R6): the race's steps take it (only the marks' places during a
## race; RaceSim.refresh_course()), and the next start is built on it.
func update_course(new_course: Course) -> void:
	course = new_course
	if race != null:
		race.refresh_course(new_course)


## The race HUD while this PC's player races; the plain HUD (speed, wind) while it waits for the next
## start.
func _show_racing_hud(on: bool) -> void:
	if on == _racing_hud:
		return
	_racing_hud = on
	hud.visible = on
	_hud_layer.set_race_mode(on, false)


## This PC's board's number in the race (-1 before the host's first start).
func my_index() -> int:
	return _my_index


## The host's race and judge as they stand.
func take_state(race_state: Dictionary, rules_state: Dictionary) -> void:
	if race == null:
		return
	race.apply_state(race_state)
	if rules != null and not rules_state.is_empty():
		rules.apply_state(rules_state)
	director = race_state.get("director", director)


## The board with a race number: this PC's, or a puppet (null when it has not come yet).
func _node_of(index: int) -> WindsurferNode:
	var id: int = _ids[index]
	if id == Lan.my_slot:
		return _own
	return _net.puppets.get(id, null)


func _physics_process(delta: float) -> void:
	if race == null:
		return
	for i: int in _ids.size():
		var node: WindsurferNode = _node_of(i)
		if node != null:
			race.update_board(i, RaceRunner.where_now(node))
	race.mirror_step(delta)
	for kind: RaceStartSignals.Kind in _start_signals.update(race.is_started(), race.clock_s()):
		start_signal.emit(kind)
	_cast_shadows_on_own_board()


## Every other sail's shadow on this PC's board (WindShadows, AI_FLEET_PLAN.md D5).
func _cast_shadows_on_own_board() -> void:
	if _shadows == null or _my_index < 0:
		return
	var xs: PackedFloat32Array = PackedFloat32Array()
	var zs: PackedFloat32Array = PackedFloat32Array()
	var casts: PackedByteArray = PackedByteArray()
	for i: int in _ids.size():
		var node: WindsurferNode = _node_of(i)
		var at: Vector3 = node.sim.telemetry.position if node != null else Vector3.INF
		xs.append(at.x)
		zs.append(at.z)
		casts.append(1 if node != null and node.visible and node.sim.sailor_state == WindsurferSim.SailorState.SAILING else 0)
	_shadows.set_fleet(xs, zs, casts, _my_index)
	_own.sim.wind.disturbance = _shadows


## How much wind this PC's board misses to the shadows now (the HUD's "in a wind shadow").
func shadow_deficit() -> float:
	if _shadows == null:
		return 0.0
	var position: Vector3 = _own.sim.telemetry.position
	var point: Vector3 = Vector3(position.x, 3.0, position.z)
	var clear: Vector3 = -_own.sim.wind.from_direction() * _own.sim.wind.speed_at_height(3.0)
	return 1.0 - _shadows.factor_at(point, clear)


func _process(_delta: float) -> void:
	if race == null:
		return
	_notice.show_text(RaceDirector.notice_text(director, _my_index >= 0, race))
	if _my_index < 0:
		return
	hud.set_watching("", true)
	hud.update_from(race, _my_index, _own.telemetry(), shadow_deficit(), rules)
	var here: Vector3 = _own.sim.telemetry.position
	_hud_layer.set_next_mark_bearing(Course.bearing_deg(Vector2(here.x, here.z), race.next_target(_my_index)))
