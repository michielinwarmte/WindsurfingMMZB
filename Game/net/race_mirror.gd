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
## state and shows on the race card's two lines.
##
## Spectating (Documentation/reports/multiplayer/spectate_6nov.md): while this PC's player is not in
## the race (a spectator, or a guest who joined while a race was on: my_index() -1) or has left the
## water in it (finished a few seconds ago, or retired: spectate_now()), the guest's own board is
## parked (hidden, not stepped, no states sent) and the camera, the race card and the sounds follow
## the board a SpectateChoice picks: any racer on the water, the host's and the other guests' boards
## and the AI's (Tab, Shift+Tab, L). At the next start the board comes back at its spot behind the
## line, unless the player stays a spectator (stays_spectator: the host leaves them out of it).

## A start signal is due on the host's race clock (SO3, as RaceRunner.start_signal): the guest
## hears the horns, the beeps and the gun too.
signal start_signal(kind: RaceStartSignals.Kind)
## The own board went off the water or came back, or the player chose to stay a spectator or to race
## again (NetBoards tells the host, which tells everyone through the lobby's list).
signal watch_changed

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
## The sails' trails of disturbed air (WindShadowTrail), made with the shadows.
var _trail: WindShadowTrail = null
## The start's signals of the host's current start (SO3).
var _start_signals: RaceStartSignals = null
## What the host's race director decided (RaceDirector.info()), and its line on the screen.
var director: Dictionary = {}
## The host's number of the race shown (RaceRunner.race_number).
var race_number: int = 0
var _notice: RaceNotice = null
## The player watches instead of racing, from the next start on (the lobby's or the menu's Spectate).
var stays_spectator: bool = false
## This PC's board is off the water (parked): not in this race, retired, or finished and watching.
var own_parked: bool = false
## Which board the camera follows while the own board is parked.
var choice: SpectateChoice = SpectateChoice.new()
## Whether the racing HUD is on (off while the course is sailed free, Course.RaceType.FREE).
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
	hud_layer.add_part(hud)
	hud_layer.set_race_mode(true, false)
	hud_layer.set_detail_visible(false)
	if race_setup.shadows:
		_shadows = WindShadows.make()
	_notice = RaceNotice.new()
	hud_layer.add_part(_notice)
	if stays_spectator:
		# A spectator from the lobby: no board on the water from the first moment.
		_set_own_parked(true)


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
	choice = SpectateChoice.new()
	# In this race: the board back on the water (NetBoards has put it at its spot); not in it (a
	# spectator, or joined while a race was on): off the water, watching.
	_set_own_parked(_my_index < 0)
	# Free sailing: the plain screen (race_types_6nov.md); a race: the race card, also for a watcher.
	_show_racing_hud(course.is_raced())


## The race director's changed course (R6): the race's steps take it (only the marks' places during a
## race; RaceSim.refresh_course()), and the next start is built on it.
func update_course(new_course: Course) -> void:
	course = new_course
	if not course.is_raced():
		# Free sailing (Course.RaceType.FREE): no race card.
		_show_racing_hud(false)
	if race != null:
		race.refresh_course(new_course)


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
	if index < 0 or index >= _ids.size():
		return null
	var id: int = _ids[index]
	if id == Lan.my_slot:
		return _own
	return _net.puppets.get(id, null)


## The network number of the board with a race number (-1 for none).
func board_id(index: int) -> int:
	return _ids[index] if index >= 0 and index < _ids.size() else -1


## The race number of the board with a network number (-1 when it is not in the race).
func index_of(id: int) -> int:
	return _ids.find(id)


# ---------------------------------------------------------------- spectating

## Whether the camera watches the others (this PC's board off the water).
func watching() -> bool:
	return own_parked


## The boards the camera may follow, in race order: every racer on the water (the host's, the other
## guests' and the AI boards; not a board parked off the water).
func watch_order() -> Array[int]:
	if race == null:
		return []
	return SpectateChoice.watchable(race.race_order(), func(index: int) -> bool:
		var node: WindsurferNode = _node_of(index)
		return node != null and node.visible)


## The race's number of the board the camera follows: this PC's while it races, or the one the
## SpectateChoice follows while watching; -1 for none (not in the race and nobody shown yet).
func followed_index() -> int:
	if not own_parked:
		return _my_index
	if race != null and choice.followed >= 0 and choice.followed < race.board_count():
		return choice.followed
	return -1


## The board the camera, the HUD and the sounds follow (this PC's own when there is none to watch).
func followed_node() -> WindsurferNode:
	if not own_parked:
		return _own
	var node: WindsurferNode = _node_of(followed_index())
	return node if node != null else _own


## Tab (+1) and Shift+Tab (-1) while watching: the next or the previous board in race order.
func step_followed(by: int) -> void:
	if own_parked and race != null:
		choice.step(watch_order(), by)


## L while watching: follow the leader again.
func follow_leader() -> void:
	if own_parked and race != null:
		choice.follow_leader(watch_order())


## The other boards on the water for the small map (all but the one followed, its own dot).
func other_positions() -> PackedVector3Array:
	var positions: PackedVector3Array = PackedVector3Array()
	var followed: WindsurferNode = followed_node()
	if _own.visible and _own != followed:
		positions.append(_own.sim.telemetry.position)
	for id: int in _net.puppets:
		var node: WindsurferNode = _net.puppets[id]
		if node.visible and node != followed:
			positions.append(node.sim.telemetry.position)
	return positions


## The menu's Spectate: this PC's player stops racing and watches. A board in the race under way
## retires (the host marks it, and every PC's results show it); the board leaves the water and comes
## back at the next start, unless the player also chooses to stay a spectator.
func spectate_now() -> void:
	if race != null and _my_index >= 0 and race.phase() != RaceSim.Phase.FINISHED and not race.is_finished(_my_index) \
			and not race.is_retired(_my_index):
		Lan.send_retire()
	_set_own_parked(true)


## Whether the player watches from now on (true) or races again from the next start (false).
func set_stays_spectator(stays: bool) -> void:
	if stays == stays_spectator:
		return
	stays_spectator = stays
	watch_changed.emit()


## This PC's player has finished: RaceRunner.WATCH_AFTER_FINISH_S after the line (or when the race is
## over), the board leaves the water and the camera goes to the others.
func _watch_when_finished() -> void:
	if own_parked or race == null or _my_index < 0 or not race.is_finished(_my_index):
		return
	var splits: PackedFloat32Array = race.splits_s(_my_index)
	var crossed_s: float = splits[splits.size() - 1] if not splits.is_empty() else race.finish_time_s(_my_index)
	if race.phase() == RaceSim.Phase.FINISHED or race.race_time_s() - crossed_s >= RaceRunner.WATCH_AFTER_FINISH_S:
		_set_own_parked(true)


## This PC's board off the water (hidden, not stepped: its own tick steps nothing while a runner
## would; NetBoards sends no states of it) or back on it; the HUD's keys follow.
## The race card and the race's keys on (a race) or off (free sailing: the plain sailing screen).
func _show_racing_hud(on: bool) -> void:
	if on == _racing_hud:
		return
	_racing_hud = on
	hud.visible = on
	_hud_layer.set_race_mode(on, false)


func _set_own_parked(parked: bool) -> void:
	_own.stepped_by_runner = parked
	_own.visible = not parked
	if hud != null:
		hud.visible = true
		_hud_layer.set_race_mode(true, parked)
	if parked == own_parked:
		return
	own_parked = parked
	if not parked:
		_own.reset_physics_interpolation()
	choice = SpectateChoice.new()
	watch_changed.emit()


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
	_cast_shadows_on_own_board(delta)


## Every other sail's shadow on this PC's board (WindShadows, AI_FLEET_PLAN.md D5).
func _cast_shadows_on_own_board(delta: float) -> void:
	if _shadows == null or _my_index < 0:
		return
	if _trail == null:
		_trail = WindShadowTrail.make()
	var xs: PackedFloat32Array = PackedFloat32Array()
	var zs: PackedFloat32Array = PackedFloat32Array()
	var casts: PackedByteArray = PackedByteArray()
	var sims: Array[WindsurferSim] = []
	for i: int in _ids.size():
		var node: WindsurferNode = _node_of(i)
		var at: Vector3 = node.sim.telemetry.position if node != null else Vector3.INF
		xs.append(at.x)
		zs.append(at.z)
		casts.append(1 if node != null and node.visible and node.sim.sailor_state == WindsurferSim.SailorState.SAILING else 0)
		sims.append(node.sim if node != null else null)
	_shadows.set_fleet(xs, zs, casts, _my_index)
	# The sails' trails of disturbed air (WindShadowTrail): every board's, from its puppet's place, speed and wind.
	_trail.update(delta, sims, casts)
	_shadows.set_trail(_trail.points(), _my_index)
	_own.sim.wind.disturbance = _shadows


## How much wind this PC's board misses to the shadows now (the HUD's "in a wind shadow").
func shadow_deficit() -> float:
	if _shadows == null:
		return 0.0
	var position: Vector3 = _own.sim.telemetry.position
	var point: Vector3 = Vector3(position.x, 3.0, position.z)
	var clear: Vector3 = -_own.sim.wind.from_direction() * _own.sim.wind.speed_at_height(3.0)
	return 1.0 - _shadows.factor_at(point, clear)


func _process(delta: float) -> void:
	if race == null:
		return
	if not course.is_raced():
		# Free sailing: the plain screen, and what the director says.
		_notice.show_text(RaceDirector.notice_text(director, true, race))
		return
	_watch_when_finished()
	if own_parked:
		choice.update(watch_order(), delta)
	var index: int = followed_index()
	# The director's lines on the race card: the next start, and for a player not in this race that
	# they race from the next one (a spectator who stays one is not told so).
	var lines: PackedStringArray = RaceDirector.notice_lines(director, _my_index >= 0 or stays_spectator, race)
	if index < 0:
		# Nobody on the water to watch yet (the boards' first states are on their way).
		_notice.show_text("\n".join(lines).strip_edges())
		hud.visible = false
		return
	_notice.show_text("")
	hud.visible = true
	RaceDirector.show_on_card(hud, lines)
	var node: WindsurferNode = followed_node()
	hud.set_watching(race.board_name(index) if own_parked else "", choice.follows_leader, RaceHud.watch_place_text(race, index) if own_parked else "")
	# While a player who finished watches the others, the finish list stays on the screen.
	hud.results_wanted = own_parked and _my_index >= 0 and race.is_finished(_my_index)
	hud.update_from(race, index, node.telemetry(), shadow_deficit() if node == _own else 0.0, rules)
	var here: Vector3 = node.sim.telemetry.position
	_hud_layer.set_next_mark_bearing(Course.bearing_deg(Vector2(here.x, here.z), race.next_target(index)))
