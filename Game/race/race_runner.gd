class_name RaceRunner
extends Node
## A race in a sailing scene (RACING_PLAN.md, 9A and 9B): the player's board and the AI skippers'
## boards on one start line, the race's own checks and clock (RaceSim), and the race on the screen
## (RaceHud). It steps no physics itself: every WindsurferNode runs its own simulation in its
## _physics_process, and this node, added after them so it runs after them each tick, tells the
## race where they are. The skippers sail through the beginner controller with their AiHands, as
## the player does (RD1); nothing here touches the physics.
##
## LAN multiplayer (Documentation/reports/multiplayer/PLAN.md, D8): on the host, the other players'
## boards are puppets (remote_players, set before setup_race()): in the race, the judge and the wind
## shadows like any board, but not stepped here (their PCs sail them) and judged where they are now
## (where_now()). restarted tells the host's NetBoards to send the new start to the guests.
##
## Spectating (RaceSetup.spectate, tools/gens.sh): the player's board does not race. It is parked
## where it is, hidden and not stepped, and it is not in the race; the camera, the HUD's block and
## the sounds follow one AI board instead, chosen by a SpectateChoice (the leader, or the board Tab
## stepped to).

const WINDSURFER_SCENE: String = "res://windsurfer/windsurfer.tscn"
## How far back from the line the boards wait per second of countdown, and the nearest and the
## farthest: 60 m for the menu's 60 s. (The race tool waits further back, 2.5 m per second, for
## its fixed-angle pilot; a player wants the line in sight: Max, 20 October 2026.)
const WAIT_M_PER_S: float = 1.0
const NEAREST_M: float = 40.0
const FARTHEST_M: float = 100.0
const PLAYER_NAME: String = "You"
## At most this many worker-thread tasks step the boards' physics side by side, each pulling the
## next board from the pool as it finishes one (32 AI boards and the player: four or five per task,
## fewer on a slow core). GDScript threads wait on a global engine lock, so more than about eight
## threads make a fleet slower, not faster (Session 51: 14 threads ran 3 times slower than 1).
## --threads=<n> sets another number, --threads=0 steps the boards one after the other on this
## thread. Measured 21 October 2026 (the release build, F1): fixed batches of boards per task
## collapsed at 20 AI boards (11 fps) where the pulled boards hold 177 fps, because a task on one
## of the laptop's slow cores held the whole tick.
const MAX_THREADS: int = 8
## An opponent farther than this from the camera is drawn with less care (its name label is
## hidden at the same distance, WindsurferNode.set_name_label): its sailor, rig and sail are posed
## every other tick, and its fin's bend is not updated. At 300 m a sailor is a few pixels tall.
## The physics and the skipper are never leveled: only what is drawn.
const FAR_DETAIL_M: float = 300.0

## A new start (restart()): LAN multiplayer's host sends it to the guests.
signal restarted
## A start signal is due (SO3): the start boat's horn, the start watch's beep or the gun. The sailing
## scene hands it to its sounds (GameAudio.play_race_signal()).
signal start_signal(kind: RaceStartSignals.Kind)

var race: RaceSim = null
var course: Course = null
var setup: RaceSetup = null
## The time trial (GP4): the records, this run's key (the water, the course and the wind) and
## whether this run's finish has been checked against the best.
var records: TimeTrialRecords = null
var record_key: String = ""
var _record_checked: bool = false
var player: WindsurferNode = null
var opponents: Array[WindsurferNode] = []
var hud: RaceHud = null
var _hud_layer: Hud = null
var _skippers: Array[RaceSkipper] = []
## Where the AI boards appear and sail free (SailingArea), round the start line and off the shore.
var _area: SailingArea = null
var _running: bool = false
## Every board, the player's first, for the tick.
var _boards: Array[WindsurferNode] = []
## The other sails' wind shadows on each board's wind (one per board of _boards, its own copy of
## the fleet's places each tick; AI_FLEET_PLAN.md D5), empty with the setup's shadows off.
var _shadows: Array[WindShadows] = []
## The race's one wind clock (ROADMAP RA13): every board's wind field is handed it before every
## tick, so the player and the fleet sail in the same gusts. Taken from the player's field at each
## restart (its gusts are the ones drawn on the water), then read back after every tick.
var wind_clock: RaceWindClock = null
## The start's signals of this race (SO3), new with each start.
var _start_signals: RaceStartSignals = null
## The racing rules' judge (RaceRules, F3), new with each race; null with the setup's rules off.
var rules: RaceRules = null
## What the runner's own tick costs (the physics of all boards, side by side or not, and the
## race's checks), microseconds since the last cost_text().
var _us_physics: int = 0
var _us_race: int = 0
var _ticks_counted: int = 0
## The ticks since the race was built, for posing the far boards on alternate ticks.
var _tick: int = 0
## --race_report=<s>: every this many seconds of the race clock, one line per AI board on the console
## (what its skipper is doing, its hands, its speed and heading): to see what the fleet does in an
## exported game, which shows no scene tree. 0: none.
var _report_every_s: float = 0.0
var _report_at_s: float = -INF
## The skippers' polars are printed with the first report only.
var _reported_polars: bool = false
## Spectating (RaceSetup.spectate): the player's board is parked out of the race.
var spectating: bool = false
## LAN multiplayer: the other players' boards (puppets, in slot order) and their names, set before
## setup_race(); where each waits at the last start, and where this PC's player waits.
var remote_players: Array[WindsurferNode] = []
var remote_names: PackedStringArray = PackedStringArray()
var remote_spots: PackedVector2Array = PackedVector2Array()
var player_spot: Vector2 = Vector2.ZERO
var start_heading_deg: float = 0.0
## Which AI board the camera follows while spectating.
var choice: SpectateChoice = SpectateChoice.new()
## The race's number of the first AI board: 1 after the player's, 0 while spectating.
var _first_ai: int = 1
## The AI boards that ran aground on a map's shore (ROADMAP RA2): 1 for each such board, one per
## board of _boards. They stop where they are, as the player's board does (the scene's stop,
## main.gd's _check_shore()), and wait for the next start; the physics' own version is PH13. The
## player's board is never marked here: the scene stops it.
var _aground: PackedByteArray = PackedByteArray()


func _ready() -> void:
	# The countdown and the race clock stop with the physics when the game is paused.
	process_mode = Node.PROCESS_MODE_PAUSABLE


## Builds the race: one board per skipper beside the player's, the race HUD on the scene's HUD
## layer, and the first start.
func setup_race(race_course: Course, player_node: WindsurferNode, race_setup: RaceSetup, hud_layer: Hud) -> void:
	course = race_course
	player = player_node
	setup = race_setup
	_hud_layer = hud_layer
	hud = RaceHud.new()
	hud.name = "RaceHud"
	hud_layer.add_child(hud)
	spectating = setup.spectate and remote_players.is_empty()
	_first_ai = 0 if spectating else 1
	hud_layer.set_race_mode(true, spectating)
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--race_report="):
			_report_every_s = arg.get_slice("=", 1).to_float()
	# The runner steps the player's board with the others (its own _physics_process steps nothing).
	player.stepped_by_runner = true
	_boards = [player]
	for node: WindsurferNode in remote_players:
		node.stepped_by_runner = true
		_boards.append(node)
	_first_ai = (0 if spectating else 1) + remote_players.size()
	if spectating:
		# Parked: hidden, not stepped (stepped_by_runner, and not among the boards), not in the race.
		_boards = []
		player.visible = false
	# The sailing area round the start line, kept off the shore on a map (the scene's shore grid).
	var sailing_scene: SailingScene = player.get_parent() as SailingScene
	_area = SailingArea.for_course(course, sailing_scene.shore_grid if sailing_scene != null else null)
	var scene: PackedScene = load(WINDSURFER_SCENE)
	for skipper: RaceSkipper in Skippers.make_fleet(setup.skippers):
		var node: WindsurferNode = scene.instantiate()
		node.name = "Opponent%d" % (opponents.size() + 1)
		# The same place, wind and sea as the player's board; its simulation is built in its _ready().
		node.environment = player.environment
		node.wind_config = player.wind_config
		node.wave_set_config = player.wave_set_config
		node.start_position = player.start_position
		node.start_heading_deg = player.start_heading_deg
		node.process_mode = Node.PROCESS_MODE_PAUSABLE
		node.wind_flag_wanted = false
		node.effects_wanted = setup.opponent_effects
		node.stepped_by_runner = true
		node.own_config_copies = true
		# A persona's own board, sail and fin for the wind at the start (its simulation and its
		# look are built on them in its _ready()); every other skipper the default gear.
		node.gear = Skippers.gear_for(skipper, player.sim.telemetry.tws_10m_kt) if setup.gear else null
		player.get_parent().add_child(node)
		node.hands = AiHands.new()
		node.controller.hands = node.hands
		node.skipper = skipper
		var learned: LearnedSkipper = skipper as LearnedSkipper
		if learned != null and setup.blind:
			learned.blind = true
		node.set_sail_colour(skipper.sail_colour())
		node.set_name_label(skipper.board_name())
		opponents.append(node)
		_boards.append(node)
		_skippers.append(skipper)
	# A race of one is a time trial: the player's time against the best kept for this course.
	if remote_players.is_empty() and (setup.time_trial or (opponents.is_empty() and not spectating)):
		setup.time_trial = true
		records = TimeTrialRecords.new()
		records.load_from(setup.records_path)
		record_key = _record_key()
	restart()


## Everyone back to the start and a new countdown (the first start, and R): the player behind the
## line, the AI boards at their random spots in the sailing area (or behind the line too, with the
## setup's spawn LINE). The countdown starts at once, or after the setup's free sailing.
func restart() -> void:
	race = RaceSim.new(course, setup.laps, setup.prestart_s)
	# The time limit fits the course, its laps and the wind (RaceTimeLimit): a fixed 20 minutes ended a
	# 12 kt race on T1 before a slow board in a crowd had finished.
	race.time_limit_s = RaceTimeLimit.for_race(race, player.sim.telemetry.wind_from_bearing_deg, player.sim.telemetry.tws_10m_kt)
	if not spectating:
		race.add_board(PLAYER_NAME)
	for i: int in remote_players.size():
		race.add_board(remote_names[i] if i < remote_names.size() else "Player %d" % (i + 2))
	for skipper: RaceSkipper in _skippers:
		race.add_board(skipper.board_name())
	rules = RaceRules.new(race.board_count(), course.axis_deg) if setup.rules else null
	var behind_m: float = setup.wait_behind_m()
	var spots: PackedVector2Array = pre_start_spots(course, race.steps()[0], opponents.size() + 1 + remote_players.size(), behind_m)
	var heading_deg: float = RaceCourses.pre_start_heading_deg(course)
	if spectating:
		# The AI boards in their order along the line (no player's slot in the middle).
		spots = PackedVector2Array([spots[0]]) + line_spots(course, race.steps()[0], opponents.size(), behind_m)
	_place(player, spots[0], heading_deg)
	# The other players' spots beside this PC's player's (their PCs put them there: restart_info()).
	player_spot = spots[0]
	start_heading_deg = heading_deg
	remote_spots = spots.slice(1, 1 + remote_players.size())
	spots = PackedVector2Array([spots[0]]) + spots.slice(1 + remote_players.size())
	# New dice at every start unless the setup fixes them (--seed): each skipper's day and the spots.
	var dice: int = setup.race_seed if setup.race_seed >= 0 else randi_range(1, 999999)
	if setup.spawn == RaceSetup.Spawn.RANDOM:
		var places: Array[Vector3] = _area.spawn_places(opponents.size(), setup.spawn_seed if setup.spawn_seed >= 0 else dice, spots[0])
		for i: int in opponents.size():
			_place(opponents[i], Vector2(places[i].x, places[i].y), places[i].z)
	else:
		for i: int in opponents.size():
			_place(opponents[i], spots[i + 1], heading_deg)
	# The skippers look at the whole fleet, so they are set up once every board is in the race.
	for i: int in opponents.size():
		_skippers[i].random_seed = dice + i
		_skippers[i].level_spread = setup.level_spread
		_skippers[i].sailing_area = _area
		_skippers[i].rules = rules
		_skippers[i].setup(opponents[i].sim, opponents[i].controller, opponents[i].hands, race, i + _first_ai)
	_tell_the_race()
	wind_clock = RaceWindClock.of(player.sim.wind)
	_start_signals = RaceStartSignals.new(race.prestart_s)
	race.start_in(setup.free_sail_s)
	hud.reset()
	if records != null:
		# The key again: R may bring a new wind (RA24), and the best is kept per wind.
		record_key = _record_key()
		hud.set_time_trial(true, records.best_s(record_key), records.best_splits(record_key))
	_record_checked = false
	choice = SpectateChoice.new()
	# Every board is afloat again at its start spot (RA2).
	_aground.resize(_boards.size())
	_aground.fill(0)
	_running = true
	restarted.emit()


## A new wind and sea for the race, at R (ROADMAP RA24): every AI board takes the wind and the waves
## the player's board now sails, each its own copy (own_config_copies), as when the race was built.
## Call restart() afterwards: the water changes under the boards. The other players' boards (LAN)
## are sailed on their own PCs and are left alone.
func give_the_fleet_the_sea_of(source: WindsurferNode) -> void:
	for node: WindsurferNode in opponents:
		node.set_sea(source.wind_config, source.wave_set_config)


## The race's course laid again (for a turned wind, RA24): the sailing area round its start line
## with it, kept off the scene's shore (its depth grid; null on the open water). restart() then
## builds the race, the rules and the start on it.
func lay_course(new_course: Course, shore: TerrainGrid) -> void:
	course = new_course
	_area = SailingArea.for_course(course, shore)


## The sailing area of this race (where the AI boards appear and sail free).
func sailing_area() -> SailingArea:
	return _area


## Where the boards wait: `behind_m` behind the start line, spread evenly along it, the player (the
## first spot) nearest the middle. The line runs from the step's first point to its second.
static func pre_start_spots(race_course: Course, start: RaceStep, count: int, behind_m: float) -> PackedVector2Array:
	var spots: PackedVector2Array = PackedVector2Array()
	var along: Vector2 = start.points[0] - start.points[1]
	var middle: Vector2 = RaceCourses.pre_start_spot(race_course) + start.in_dir * (RaceCourses.PRE_START_BEHIND_M - behind_m)
	var shares: PackedFloat32Array = PackedFloat32Array()
	for i: int in count:
		shares.append(float(i + 1) / float(count + 1))
	# The player's slot is the middle one, and it goes first.
	var player_slot: int = count / 2
	spots.append(middle + along * (shares[player_slot] - 0.5))
	for i: int in count:
		if i != player_slot:
			spots.append(middle + along * (shares[i] - 0.5))
	return spots


## Where `count` boards wait `behind_m` behind the start line, spread evenly along it in their
## order, from the line's second point to its first (as the race tool puts them).
static func line_spots(race_course: Course, start: RaceStep, count: int, behind_m: float) -> PackedVector2Array:
	var spots: PackedVector2Array = PackedVector2Array()
	var along: Vector2 = start.points[0] - start.points[1]
	var middle: Vector2 = RaceCourses.pre_start_spot(race_course) + start.in_dir * (RaceCourses.PRE_START_BEHIND_M - behind_m)
	for i: int in count:
		spots.append(middle + along * (float(i + 1) / float(count + 1) - 0.5))
	return spots


func _place(node: WindsurferNode, spot: Vector2, heading_deg: float) -> void:
	node.start_position = Vector3(spot.x, 0.0, spot.y)
	node.start_heading_deg = heading_deg
	node.reset()


## One tick of the race: every board's sailor sets its controls (on this thread: the skippers read
## the race), then every board's physics steps, side by side on worker threads when the setup says
## so (each simulation touches only its own objects; at most MAX_THREADS tasks pulling the
## boards), then the visuals (the far opponents' on alternate ticks), then the race is told where
## everyone is. A board that has run aground (the scene stops the player's, the shore check below
## the AI boards') is not stepped.
func _physics_process(delta: float) -> void:
	if not _running:
		return
	var scene: SailingScene = get_parent() as SailingScene
	var player_stopped: bool = not spectating and scene != null and scene.is_aground()
	var stopped: PackedByteArray = _stopped_boards(player_stopped)
	_hand_the_wind_clock()
	for i: int in _boards.size():
		if stopped[i] == 0:
			_boards[i].sail(delta)
	_cast_shadows()
	var t0: int = Time.get_ticks_usec()
	if setup.threads > 0:
		# One element per board, pulled by at most setup.threads worker tasks as each finishes its
		# board (the pool hands out the elements one by one), so a task on a slow core takes fewer
		# boards and the tick waits for nobody's fixed share.
		var group: int = WorkerThreadPool.add_group_task(_step_board.bind(delta, stopped), _boards.size(), setup.threads, true, "race physics")
		WorkerThreadPool.wait_for_group_task_completion(group)
	else:
		for i: int in _boards.size():
			_step_board(i, delta, stopped)
	var t1: int = Time.get_ticks_usec()
	_read_the_wind_clock(stopped)
	_check_the_shore(scene.shore_grid if scene != null else null)
	_pose_boards(player_stopped)
	_tell_the_race()
	race.step(delta)
	for kind: RaceStartSignals.Kind in _start_signals.update(race.is_started(), race.clock_s()):
		start_signal.emit(kind)
	_judge(delta)
	_us_physics += t1 - t0
	_us_race += Time.get_ticks_usec() - t1
	_ticks_counted += 1
	_tick += 1
	if _report_every_s > 0.0 and race.clock_s() >= _report_at_s:
		_report_at_s = race.clock_s() + _report_every_s
		_print_report()


## The race's wind clock onto every board's wind field (RA13), on this thread before the sailors
## look at the wind and the physics steps. A field that shows it already is left as it was; one
## made later (a new board, a new sea from the pause menu) joins the others' gusts.
func _hand_the_wind_clock() -> void:
	if wind_clock == null:
		return
	for node: WindsurferNode in _boards:
		wind_clock.hand_to(node.sim.wind)
	if spectating and player != null:
		wind_clock.hand_to(player.sim.wind)


## The clock one tick on, read from the first board that stepped (every field that stepped shows
## the same); unchanged if none did (the player alone and aground, or every board aground).
func _read_the_wind_clock(stopped: PackedByteArray) -> void:
	for i: int in _boards.size():
		if stopped[i] == 1 or _boards[i].is_puppet:
			continue
		wind_clock = RaceWindClock.of(_boards[i].sim.wind)
		return


## Which boards are not stepped this tick, 1 for each (one per board of _boards): the player's board
## when the scene has stopped it at the shore, and the AI boards that ran aground (RA2).
func _stopped_boards(player_stopped: bool) -> PackedByteArray:
	var stopped: PackedByteArray = _aground.duplicate()
	stopped.resize(_boards.size())
	if player_stopped and not _boards.is_empty():
		stopped[0] = 1
	return stopped


## The lake's shore for the AI boards (ROADMAP RA2), the same check as the player's (main.gd's
## _check_shore(), ShoreCheck): where the water under a board is shallower than its fin plus a
## margin, or off the map, the board has run aground and stops where it is until the next start
## (restart(): R, or the host's R in a LAN game). No collision physics: nothing pushes on the board.
## On the open water (no shore grid: grid is null) nothing is checked. The other players' boards
## (LAN) are checked on their own PCs.
func _check_the_shore(grid: TerrainGrid) -> void:
	if grid == null:
		return
	_aground.resize(_boards.size())
	for i: int in range(_boards.size() - opponents.size(), _boards.size()):
		if _aground[i] == 1:
			continue
		var sim: WindsurferSim = _boards[i].sim
		if ShoreCheck.is_aground(grid, sim.body.origin_world(), sim.fin_config.span_m):
			_aground[i] = 1


## Whether an AI board has run aground and stopped (RA2).
func is_aground(node: WindsurferNode) -> bool:
	var i: int = _boards.find(node)
	return i >= 0 and i < _aground.size() and _aground[i] == 1


## Every board's place and whether its sail is up, into every board's shadows (each its own copy),
## on this thread before the physics; and each board's wind field told its shadows (set_sea()
## gives a board a new field, so it is told every tick: one field write).
func _cast_shadows() -> void:
	if not setup.shadows:
		return
	if _shadows.size() != _boards.size():
		_shadows.clear()
		for _node: WindsurferNode in _boards:
			_shadows.append(WindShadows.make())
	var xs: PackedFloat32Array = PackedFloat32Array()
	var zs: PackedFloat32Array = PackedFloat32Array()
	var casts: PackedByteArray = PackedByteArray()
	for node: WindsurferNode in _boards:
		var position: Vector3 = node.sim.telemetry.position
		xs.append(position.x)
		zs.append(position.z)
		casts.append(1 if node.sim.sailor_state == WindsurferSim.SailorState.SAILING and node.visible else 0)
	for i: int in _boards.size():
		_shadows[i].set_fleet(xs, zs, casts, i)
		_boards[i].sim.wind.disturbance = _shadows[i]


## The judge told where everyone is, this tick's breaches, and every board's time penalty as it
## stands handed to the race (a scripted skipper turns a circle and clears its own; the player and
## the learned skippers carry theirs to the finish unless they turn one).
func _judge(delta: float) -> void:
	if rules == null:
		return
	var marks: PackedVector2Array = PackedVector2Array()
	for i: int in _boards.size():
		var t: Telemetry = _boards[i].sim.telemetry
		var in_race: int = i if spectating else i  # the boards' order is the race's order
		rules.set_board(in_race, where_now(_boards[i]), t.heading_deg, 1.0 if t.twa_deg >= 0.0 else -1.0, t.speed_ms,
			t.sailor_state == WindsurferSim.SailorState.SAILING and _boards[i].visible)
		var step: RaceStep = race.next_step(in_race)
		marks.append(step.points[0] if step != null and step.kind == RaceStep.Kind.MARK else Vector2.INF)
	if _boards.size() > 0:
		rules.wind_from_deg = _boards[0].sim.telemetry.wind_from_bearing_deg
	rules.step(delta, marks, race.clock_s() >= 0.0)
	for i: int in _boards.size():
		race.set_time_penalty_s(i, rules.time_penalty_s(i))


## How much of the wind a board is missing to the other sails' shadows right now, 0 to 1 (for the
## HUD: "in a wind shadow"); 0 with the shadows off.
func shadow_deficit(node: WindsurferNode) -> float:
	var i: int = _boards.find(node)
	if i < 0 or i >= _shadows.size():
		return 0.0
	var position: Vector3 = node.sim.telemetry.position
	var point: Vector3 = Vector3(position.x, 3.0, position.z)
	var clear: Vector3 = -node.sim.wind.from_direction() * node.sim.wind.speed_at_height(3.0)
	return 1.0 - _shadows[i].factor_at(point, clear)


## Board i's physics (a worker task's element, or the loop's); not for a stopped board.
func _step_board(i: int, delta: float, stopped: PackedByteArray) -> void:
	if stopped[i] == 1:
		return
	_boards[i].step_physics(delta)



## After the physics, on this thread: every board's visuals. An opponent farther than
## FAR_DETAIL_M from the camera is posed on alternate ticks (half of them on the even ticks, half
## on the odd, so the cost is even); its place on the water is set every tick.
func _pose_boards(player_stopped: bool) -> void:
	if not player_stopped and not spectating:
		player.after_step()
	# The other players' boards (LAN multiplayer) are posed by NetBoards as their states come in.
	var camera: Camera3D = get_viewport().get_camera_3d()
	var eye: Vector3 = camera.global_position if camera != null else player.global_position
	for i: int in opponents.size():
		var node: WindsurferNode = opponents[i]
		var far: bool = node.global_position.distance_to(eye) > FAR_DETAIL_M
		node.set_far_away(far)
		node.after_step(not far or (_tick + i) % 2 == 0)


## What a tick of the runner costs on average since the last call, milliseconds (--measure).
func cost_text() -> String:
	var ticks: float = maxf(float(_ticks_counted), 1.0)
	var how: String = "side by side, %d tasks" % setup.threads if setup.threads > 0 else "one after the other"
	var text: String = "all boards' physics %.2f ms (%s), the race's checks and the visuals %.2f ms per tick" % [
		_us_physics / ticks / 1000.0, how, _us_race / ticks / 1000.0]
	_us_physics = 0
	_us_race = 0
	_ticks_counted = 0
	return text


## The AI boards' costs since the last call, in one line (--measure): their number, and the median
## and the worst of their own sailor, physics and visuals per tick (milliseconds; each board's
## average over the ticks). How many are far from the camera now, too.
func opponents_cost_text() -> String:
	var sailor: PackedFloat64Array = PackedFloat64Array()
	var physics: PackedFloat64Array = PackedFloat64Array()
	var visuals: PackedFloat64Array = PackedFloat64Array()
	var far: int = 0
	for node: WindsurferNode in opponents:
		var cost: Vector3 = node.take_cost_ms()
		sailor.append(cost.x)
		physics.append(cost.y)
		visuals.append(cost.z)
		if node.is_far_away():
			far += 1
	return "%d, %d of them beyond %d m: physics median %.2f, worst %.2f; sailor median %.2f, worst %.2f; visuals median %.2f, worst %.2f ms per tick" % [
		opponents.size(), far, roundi(FAR_DETAIL_M), median(physics), worst(physics), median(sailor), worst(sailor), median(visuals), worst(visuals)]


## The middle value (the mean of the two middle ones for an even count); 0 for none.
static func median(values: PackedFloat64Array) -> float:
	if values.is_empty():
		return 0.0
	var sorted: PackedFloat64Array = values.duplicate()
	sorted.sort()
	var middle: int = sorted.size() / 2
	if sorted.size() % 2 == 1:
		return sorted[middle]
	return (sorted[middle - 1] + sorted[middle]) * 0.5


static func worst(values: PackedFloat64Array) -> float:
	var largest: float = 0.0
	for value: float in values:
		largest = maxf(largest, value)
	return largest


func _process(delta: float) -> void:
	if not _running:
		return
	if spectating and not opponents.is_empty():
		choice.update(race.race_order(), delta)
	var index: int = followed_index()
	var node: WindsurferNode = followed_node()
	hud.set_watching(node.skipper.board_name() if spectating and node.skipper != null else "", choice.follows_leader)
	hud.update_from(race, index, node.telemetry(), shadow_deficit(node), rules)
	_check_record()
	_hud_layer.set_next_mark_bearing(Course.bearing_deg(_where(node), race.next_target(index)))


## The race's number of the board the camera follows: the player's (0), or while spectating the
## AI board the SpectateChoice follows.
func followed_index() -> int:
	if not spectating or opponents.is_empty():
		return 0
	return choice.followed if choice.followed >= 0 else 0


## The board the camera, the HUD's block and the sounds follow (the player's when not spectating).
func followed_node() -> WindsurferNode:
	if not spectating or opponents.is_empty():
		return player
	return opponents[followed_index() - _first_ai]


## Tab (+1) and Shift+Tab (-1) while spectating: the next or the previous board in race order.
func step_followed(by: int) -> void:
	if spectating and race != null:
		choice.step(race.race_order(), by)


## L while spectating: follow the leader again.
func follow_leader() -> void:
	if spectating and race != null:
		choice.follow_leader(race.race_order())


## The race is told where every board is (the player first, unless spectating).
func _tell_the_race() -> void:
	if not spectating:
		race.update_board(0, _where(player))
	for i: int in remote_players.size():
		# Not before its first state has come (the puppet shows then): until then it is nowhere.
		if remote_players[i].visible:
			race.update_board(1 + i, where_now(remote_players[i]))
	for i: int in opponents.size():
		race.update_board(i + _first_ai, _where(opponents[i]))


## The other boards' places, for the small map (all but the one followed).
func other_positions() -> PackedVector3Array:
	var positions: PackedVector3Array = PackedVector3Array()
	var followed: WindsurferNode = followed_node()
	for node: WindsurferNode in remote_players:
		positions.append(node.sim.telemetry.position)
	for node: WindsurferNode in opponents:
		if node != followed:
			positions.append(node.sim.telemetry.position)
	return positions


static func _where(node: WindsurferNode) -> Vector2:
	var position: Vector3 = node.sim.telemetry.position
	return Vector2(position.x, position.z)


## Where a board is now: its place, and for a puppet (LAN multiplayer) its shown state's place moved
## on by its speed for the state's age, so the judge times the other player's start and finish as
## their own PC sailed them (D8).
static func where_now(node: WindsurferNode) -> Vector2:
	var position: Vector3 = node.sim.telemetry.position
	if node.state_age_s > 0.0:
		position += node.sim.body.velocity * node.state_age_s
	return Vector2(position.x, position.z)


## The time trial's key (TimeTrialRecords): the water, the course and the wind the player's board
## sails in: the hour on the lake (its wind is the hour's), the settings' knots on the open water.
func _record_key() -> String:
	var field: MapWindField = player.sim.wind as MapWindField
	if field != null:
		return TimeTrialRecords.make_key("lake", course.name, field.time_of_day_text().left(5))
	return TimeTrialRecords.make_key("open", course.name, "%d kt" % roundi(player.sim.wind_config.speed_kt))


## The time trial's finish, once: the time with any penalty against the best, kept if faster,
## and the HUD told what it was.
func _check_record() -> void:
	if records == null or _record_checked or spectating or not race.is_finished(0):
		return
	_record_checked = true
	var best_before_s: float = records.best_s(record_key)
	var time_s: float = race.finish_time_s(0) + race.time_penalty_s(0)
	var is_best: bool = records.remember(record_key, time_s, race.splits_s(0))
	hud.set_record(is_best, best_before_s)


## The --race_report lines: the race clock, then per AI board its name, its skipper's note, whether
## it sails, its speed, heading and wind angle, the hands' steer and the controls' sheet; the first
## time also what each skipper knows of its board (its polar's sizes).
func _print_report() -> void:
	print("race %s (%s)" % [RaceHud.clock(race.race_time_s()) if race.phase() != RaceSim.Phase.PRE_START else "-" + RaceHud.clock(race.countdown_s()), RaceSim.Phase.keys()[race.phase()]])
	for node: WindsurferNode in opponents:
		var t: Telemetry = node.sim.telemetry
		var note: String = str(node.skipper.get("note")) if node.skipper != null and "note" in node.skipper else ""
		if not _reported_polars and node.skipper != null and "_polar_winds" in node.skipper:
			# What the skipper knows of its board: empty in the exported game before Session 68 (the
			# export's binary conversion dropped the polar's numbers; project.godot's
			# editor/export/convert_text_resources_to_binary), and the fleet pointed into the wind.
			print("  %s's polar: %d winds, %d angles, %d speeds, beat %s" % [node.skipper.board_name(), node.skipper.get("_polar_winds").size(),
				node.skipper.get("_polar_twa").size(), node.skipper.get("_polar_speeds").size(), node.skipper.get("_polar_upwind")])
		print("  %-10s %-9s %5.1f m/s  heading %3.0f  twa %4.0f  steer %+.2f  sheet %.2f  autopilot %s  hands %s  | %s" % [
			node.skipper.board_name().left(10) if node.skipper != null else node.name, WindsurferSim.SailorState.keys()[node.sim.sailor_state],
			t.speed_ms, t.heading_deg, t.twa_deg, node.hands.steer if node.hands != null else NAN, node.controls.sheet,
			node.use_autopilot, node.controller.hands != null, note])
	_reported_polars = true
