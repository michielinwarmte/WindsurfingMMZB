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
## A race after a race (LAN multiplayer's race director, Documentation/reports/multiplayer/
## RACE_DIRECTOR.md R4; RaceDirector): restart(true) builds a new race with every board where it is,
## the countdown at once; the other players who joined since (remote_source) are in it, and every AI
## board takes the gear its persona chooses for the wind of the moment (R3; fleet_regeared tells the
## host's NetBoards). update_course() puts the race director's changed course into the race as it
## runs (R6).
##
## Free sailing (Course.RaceType.FREE; Max, 6 November 2026): every board is placed as for a start,
## but no countdown starts, so there is no race and no result; the AI boards sail free round the start
## line (Skipper's FREE_SAILING) and the course's marks stay on the water. The race card is hidden and
## the HUD shows the plain sailing screen. The race director switches between free sailing and a race
## by the course's race type (RaceDirector).
##
## Spectating (RaceSetup.spectate, tools/gens.sh; in a LAN game the lobby's or the menu's Spectate,
## Documentation/reports/multiplayer/spectate_6nov.md): the player's board does not race. It is
## parked where it is, hidden and not stepped, and it is not in the race; the camera, the HUD's block
## and the sounds follow another board instead, chosen by a SpectateChoice (the leader, or the board
## Tab stepped to): an AI board, another PC's player or (LAN) any racer on the water. In a LAN game
## the player's board is also parked mid-race when the player retires (spectate_now(): the race marks
## it retired) or a few seconds after it finishes (watch_after_finish), and it comes back at its spot
## behind the line at the next start, unless the player stays a spectator (stays_spectator).

const WINDSURFER_SCENE: String = "res://windsurfer/windsurfer.tscn"
## How far back from the line the boards wait per second of countdown, and the nearest and the
## farthest: 60 m for the menu's 60 s. (The race tool waits further back, 2.5 m per second, for
## its fixed-angle pilot; a player wants the line in sight: Max, 20 October 2026.)
const WAIT_M_PER_S: float = 1.0
const NEAREST_M: float = 40.0
const FARTHEST_M: float = 100.0
const PLAYER_NAME: String = "You"
## At least this many worker-thread tasks step the boards' physics side by side, each pulling the
## next board from the pool as it finishes one (32 AI boards and the player: four or five per task,
## fewer on a slow core); more on a processor with more threads (threads_for_this_pc()).
## GDScript threads wait on a global engine lock, so more than about eight threads made a fleet
## slower, not faster (Session 51: 14 threads ran 3 times slower than 1).
## --threads=<n> sets another number, --threads=0 steps the boards one after the other on this
## thread. Measured 21 October 2026 (the release build, F1): fixed batches of boards per task
## collapsed at 20 AI boards (11 fps) where the pulled boards hold 177 fps, because a task on one
## of the laptop's slow cores held the whole tick.
const MAX_THREADS: int = 8


## The tasks for this processor: three quarters of its threads, never fewer than MAX_THREADS.
## Measured 6 November 2026 (the release build, the T2 slalom on the lake's full waves, 20 boards,
## a 16-thread Ryzen 7 5800X3D): 8 tasks 17 to 23 fps (the boards' physics 10.5 to 10.8 ms a tick,
## too much for a 60 Hz frame with the rest of it), 12 tasks 57 fps (8.1 ms), 16 tasks 58 fps.
static func threads_for_this_pc() -> int:
	return maxi(MAX_THREADS, OS.get_processor_count() * 3 / 4)
## An opponent farther than this from the camera is drawn with less care (its name label is
## hidden at the same distance, WindsurferNode.set_name_label): its sailor, rig and sail are posed
## every other tick, and its fin's bend is not updated. At 300 m a sailor is a few pixels tall.
## The physics and the skipper are never leveled: only what is drawn. This is the Normal draw distance;
## Settings > Graphics > Draw distance moves it (DrawDistance.full_detail_m(), which the boards use).
const FAR_DETAIL_M: float = 300.0
## An opponent out of the camera's view is posed on every this-many ticks (_pose_boards()): when the
## camera turns or cuts to it, its sailor and rig are at most this many ticks old for one frame.
const OUT_OF_VIEW_POSE_TICKS: int = 8
## How far outside the camera's view a board still counts as seen: its mast (up to 5.4 m), its
## boom and its sailor reach out from the board's own point.
const VIEW_MARGIN_M: float = 10.0
## A board this near the camera counts as seen even out of view: its sail's shadow may fall into the
## picture (the water takes shadows), and when the camera turns the near boards come in first and
## largest.
const ALWAYS_POSED_M: float = 50.0
## A LAN player who has finished watches the others this many seconds after crossing the line (first
## the finish on the screen: the place and the time).
const WATCH_AFTER_FINISH_S: float = 4.0

## A new start (restart()): LAN multiplayer's host sends it to the guests.
signal restarted
## The player's board went off the water (parked: spectating) or came back, or the player chose to
## stay a spectator or to race again (LAN multiplayer's host tells the other PCs: NetBoards).
signal watch_changed
## A start signal is due (SO3): the start boat's horn, the start watch's beep or the gun. The sailing
## scene hands it to its sounds (GameAudio.play_race_signal()).
signal start_signal(kind: RaceStartSignals.Kind)
## These AI boards (their places in `opponents`) took other gear at the new start (R3).
signal fleet_regeared(indices: Array[int])

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
## The sails' trails of disturbed air (WindShadowTrail; the shadows lie along them), made with the shadows.
var _trail: WindShadowTrail = null
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
## The tick's parts on the main thread, for --measure (FrameBudget, 13 November 2026): the time
## spent in each since the last cost_text(), in the order of PART_NAMES.
const PART_NAMES: PackedStringArray = ["skippers (and the player's controls)", "dirty wind", "physics with the posing beside it", "clocks and shore", "telling the race", "race step", "judging"]
var _in_view_count: int = 0  ## boards in the camera's view, summed over the ticks (--measure)
var _us_parts: PackedInt64Array = PackedInt64Array([0, 0, 0, 0, 0, 0, 0])
## The ticks since the race was built, for posing the far boards on alternate ticks.
var _tick: int = 0
## --race_report=<s>: every this many seconds of the race clock, one line per AI board on the console
## (what its skipper is doing, its hands, its speed and heading): to see what the fleet does in an
## exported game, which shows no scene tree. 0: none.
var _report_every_s: float = 0.0
## --time_limit=<s>: every race ends that long after its gun (the race director's test of a race
## after a race, tools/lan_test.sh --time_limit); 0: the limit for the course and the wind.
var _time_limit_s: float = 0.0
## How many races this runner has started (the first is 1): the LAN results name it (tools/lan_test.sh).
var race_number: int = 0
var _report_at_s: float = -INF
## The skippers' polars are printed with the first report only.
var _reported_polars: bool = false
## Spectating (RaceSetup.spectate): the player's board is not in this race (decided at every start
## from stays_spectator).
var spectating: bool = false
## The player watches instead of racing, from the next start on (RaceSetup.spectate, or in a LAN game
## the lobby's or the menu's Spectate; the menu's Race again turns it off).
var stays_spectator: bool = false
## The player's board is off the water: hidden and not stepped, the camera on the board chosen. True
## while spectating, and in a LAN game after the player retired or finished, until the next start.
var player_parked: bool = false
## LAN multiplayer: a player who has finished watches the others until the next start.
var watch_after_finish: bool = false
## LAN multiplayer: the other players' boards (puppets, in slot order) and their names, set before
## setup_race(); where each waits at the last start, and where this PC's player waits.
var remote_players: Array[WindsurferNode] = []
var remote_names: PackedStringArray = PackedStringArray()
var remote_spots: PackedVector2Array = PackedVector2Array()
var player_spot: Vector2 = Vector2.ZERO
var start_heading_deg: float = 0.0
## LAN multiplayer: called at every start for the other players racing now, [their boards, their
## names] (NetBoards: a guest who joined since is in the next race, one who left is not). Not set:
## remote_players and remote_names stay as they were set.
var remote_source: Callable = Callable()
## Whether the last start left every board where it was (restart(true), a race after a race).
var kept_places: bool = false
## On a lake: the shore as the AI skippers see it while they race (ShoreLookout; Max, 6 November 2026:
## the AI races every iQFOiL course on Silvaplana without going onto the shore). Null on the open water.
var shore_lookout: ShoreLookout = null
## Which board the camera follows while the player's board is parked.
var choice: SpectateChoice = SpectateChoice.new()
## The dice of the last start (each skipper's day and the AI boards' spots); a watcher's Shift+R sets
## repeat_dice to it, and the next start (only that one) throws the same (WatchMode).
var last_dice: int = 0
var repeat_dice: int = -1
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
	hud_layer.add_part(hud)
	stays_spectator = stays_spectator or setup.spectate
	spectating = stays_spectator
	player_parked = spectating
	_first_ai = 0 if spectating else 1
	hud_layer.set_race_mode(true, spectating)
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--time_limit="):
			_time_limit_s = maxf(arg.get_slice("=", 1).to_float(), 0.0)
		if arg.begins_with("--race_report="):
			_report_every_s = arg.get_slice("=", 1).to_float()
	# The runner steps the player's board with the others (its own _physics_process steps nothing).
	player.stepped_by_runner = true
	if spectating:
		# Parked: hidden, not stepped (stepped_by_runner, and not among the boards), not in the race.
		player.visible = false
	# The sailing area round the start line, kept off the shore on a map (the scene's shore grid).
	var sailing_scene: SailingScene = player.get_parent() as SailingScene
	_area = SailingArea.for_course(course, sailing_scene.shore_grid if sailing_scene != null else null)
	if sailing_scene != null and sailing_scene.shore_grid != null:
		shore_lookout = ShoreLookout.for_lake(sailing_scene.shore_grid, course.start_middle())
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
## keep_places (a race after a race, R4): every board stays where it is (an AI board aground is
## put back at a spot in the sailing area) and the countdown starts at once.
func restart(keep_places: bool = false) -> void:
	kept_places = keep_places
	# A board that was off the water comes back at its spot behind the line, also in a race after a race.
	var was_parked: bool = player_parked
	spectating = stays_spectator
	_gather_boards()
	var regeared: Array[int] = _gear_the_fleet_for_the_wind()
	race = RaceSim.new(course, setup.laps, setup.prestart_s)
	# The time limit fits the course, its laps and the wind (RaceTimeLimit): a fixed 20 minutes ended a
	# 12 kt race on T1 before a slow board in a crowd had finished.
	race.time_limit_s = RaceTimeLimit.for_race(race, player.sim.telemetry.wind_from_bearing_deg, player.sim.telemetry.tws_10m_kt)
	if _time_limit_s > 0.0:
		race.time_limit_s = _time_limit_s
	race_number += 1
	if not spectating:
		race.add_board(PLAYER_NAME)
	for i: int in remote_players.size():
		race.add_board(remote_names[i] if i < remote_names.size() else "Player %d" % (i + 2))
	for skipper: RaceSkipper in _skippers:
		race.add_board(skipper.board_name())
	rules = RaceRules.new(race.board_count(), course.axis_deg) if setup.rules else null
	var behind_m: float = setup.wait_behind_m()
	var spots: PackedVector2Array = pre_start_spots(course, race.steps()[0], opponents.size() + 1 + remote_players.size(), behind_m)
	if course.starts_upwind_of_the_boat():
		# A slalom's row upwind of the boat, kept inside the sailing area (off a lake's shore).
		for i: int in spots.size():
			spots[i] = inside_area(_area, spots[i])
	var heading_deg: float = RaceCourses.pre_start_heading_deg(course)
	if spectating and remote_players.is_empty():
		# The AI boards in their order along the line (no player's slot in the middle).
		spots = PackedVector2Array([spots[0]]) + line_spots(course, race.steps()[0], opponents.size(), behind_m)
	if not keep_places or (was_parked and not spectating):
		_place(player, spots[0], heading_deg)
	# The other players' spots beside this PC's player's (their PCs put them there: restart_info()).
	player_spot = spots[0]
	start_heading_deg = heading_deg
	remote_spots = spots.slice(1, 1 + remote_players.size())
	spots = PackedVector2Array([spots[0]]) + spots.slice(1 + remote_players.size())
	# New dice at every start unless the setup fixes them (--seed) or the watcher asks for the last race
	# again (WatchMode, Shift+R): each skipper's day and the spots.
	var dice: int = setup.race_seed if setup.race_seed >= 0 else (repeat_dice if repeat_dice >= 0 else randi_range(1, 999999))
	repeat_dice = -1
	last_dice = dice
	if keep_places:
		# Only a board that ran aground leaves where it is: back to a spot in the sailing area.
		var aground_places: Array[Vector3] = _area.spawn_places(opponents.size(), dice, spots[0])
		for i: int in opponents.size():
			if is_aground(opponents[i]):
				_place(opponents[i], Vector2(aground_places[i].x, aground_places[i].y), aground_places[i].z)
	elif setup.spawn == RaceSetup.Spawn.RANDOM:
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
		_skippers[i].shore = shore_lookout
		_skippers[i].setup(opponents[i].sim, opponents[i].controller, opponents[i].hands, race, i + _first_ai)
	_tell_the_race()
	wind_clock = RaceWindClock.of(player.sim.wind)
	_start_signals = RaceStartSignals.new(race.prestart_s)
	if course.is_raced():
		race.start_in(0.0 if keep_places else setup.free_sail_s)
	hud.reset()
	_show_race_card(course.is_raced())
	if records != null:
		# The key again: R may bring a new wind (RA24), and the best is kept per wind.
		record_key = _record_key()
		hud.set_time_trial(true, records.best_s(record_key), records.best_splits(record_key))
	_record_checked = false
	choice = SpectateChoice.new()
	_set_player_parked(spectating)
	# Every board is afloat again at its start spot (RA2).
	_aground.resize(_boards.size())
	_aground.fill(0)
	_running = true
	restarted.emit()
	if not regeared.is_empty():
		fleet_regeared.emit(regeared)


## Every board of the race in its order: this PC's player's (unless spectating), the other players'
## (LAN multiplayer, as remote_source has them now), the AI boards'.
func _gather_boards() -> void:
	if remote_source.is_valid():
		var now: Array = remote_source.call()
		remote_players.assign(now[0])
		remote_names = now[1]
	_boards.clear()
	if not spectating:
		_boards.append(player)
	for node: WindsurferNode in remote_players:
		node.stepped_by_runner = true
		_boards.append(node)
	_first_ai = (0 if spectating else 1) + remote_players.size()
	_boards.append_array(opponents)


## Each AI board on the gear its persona chooses for the wind of the moment (R3: gear changes
## between starts, the AI's too), where it is. The places in `opponents` of those that changed.
func _gear_the_fleet_for_the_wind() -> Array[int]:
	var changed: Array[int] = []
	if not setup.gear:
		return changed
	var wind_kt: float = player.sim.telemetry.tws_10m_kt
	for i: int in opponents.size():
		var wanted: GearChoice = Skippers.gear_for(_skippers[i], wind_kt)
		if wanted == null:
			continue
		var node: WindsurferNode = opponents[i]
		var sailed: GearChoice = node.gear if node.gear != null else GearChoice.defaults()
		if wanted.board.id() != sailed.board.id() or wanted.sail.id() != sailed.sail.id() or wanted.fin.id() != sailed.fin.id():
			node.change_gear(wanted)
			changed.append(i)
	return changed


## The race director's changed course (R6), into the race as it runs: the sailing area round its
## start line, the skippers' too, and the race's steps (RaceSim.refresh_course(): during a race
## only the marks' places change). The next start is built on it.
func update_course(new_course: Course, shore: TerrainGrid) -> void:
	course = new_course
	_area = SailingArea.for_course(course, shore)
	for skipper: RaceSkipper in _skippers:
		skipper.sailing_area = _area
	if race != null:
		race.refresh_course(new_course)


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
## first spot) nearest the middle. The line runs from the step's first point to its second. On a
## slalom (Course.RaceType.SLALOM) in a row upwind of the committee boat instead, the player in the
## middle of it (RaceCourses.wait_spots(); Max, 6 November 2026).
static func pre_start_spots(race_course: Course, start: RaceStep, count: int, behind_m: float) -> PackedVector2Array:
	if race_course.starts_upwind_of_the_boat():
		return RaceCourses.wait_spots(race_course, count, behind_m)
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


## A point moved inside a sailing area, at least 10 m from its sides (as the skippers keep their
## points: Skipper._inside_area()).
static func inside_area(area: SailingArea, point: Vector2) -> Vector2:
	if area == null:
		return point
	var here: Vector2 = area.local(point)
	var across_m: float = maxf(area.half_across_m - 10.0, 0.0)
	var up_m: float = maxf(area.half_up_m - 10.0, 0.0)
	return area.point_at(clampf(here.x, -across_m, across_m), clampf(here.y, -up_m, up_m))


## Where `count` boards wait `behind_m` behind the start line, spread evenly along it in their
## order, from the line's second point to its first (as the race tool puts them); on a slalom in the
## row upwind of the committee boat, from its far end in.
static func line_spots(race_course: Course, start: RaceStep, count: int, behind_m: float) -> PackedVector2Array:
	var spots: PackedVector2Array = PackedVector2Array()
	if race_course.starts_upwind_of_the_boat():
		for i: int in count:
			spots.append(RaceCourses.slalom_slot(race_course, float(i + 1) / float(count + 1)))
		return spots
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
## so (each simulation touches only its own objects; at most setup.threads tasks pulling the
## boards), then the visuals (the far opponents' on alternate ticks), then the race is told where
## everyone is. A board that has run aground (the scene stops the player's, the shore check below
## the AI boards') is not stepped.
func _physics_process(delta: float) -> void:
	if not _running:
		return
	var scene: SailingScene = get_parent() as SailingScene
	var player_stopped: bool = not spectating and (player_parked or (scene != null and scene.is_aground()))
	var stopped: PackedByteArray = _stopped_boards(player_stopped)
	_hand_the_wind_clock()
	var p0: int = Time.get_ticks_usec()
	# The skippers think here, one after the other: they read the race and the other boards. An AI
	# board's controller then sets its controls on its own worker thread, just before its physics
	# (_step_board); the player's on this thread now.
	var controls_there: PackedByteArray = _controls_on_worker_threads(stopped)
	for i: int in _boards.size():
		if stopped[i] == 0:
			_boards[i].think(delta)
			if controls_there[i] == 0:
				_boards[i].set_the_controls(delta)
	var p1: int = Time.get_ticks_usec()
	_cast_shadows(delta)
	var t0: int = Time.get_ticks_usec()
	# The physics, and the visuals beside it: each board's step is a task of its own on the worker
	# threads, and this thread poses each board as soon as its step is done, while the threads go
	# on with the others (13 November 2026; before, this thread waited for all of them and then
	# posed every board). Posing reads only the board's own simulation.
	var steps: PackedInt64Array = PackedInt64Array()
	if setup.threads > 0:
		steps = _start_the_steps(delta, stopped, controls_there)
	else:
		for i: int in _boards.size():
			_step_board(i, delta, stopped, controls_there)
	_pose_boards(player_stopped, steps)
	var t1: int = Time.get_ticks_usec()
	_keep_the_parked_boards_clock(stopped, delta)
	_read_the_wind_clock(stopped, delta)
	_check_the_shore(scene.shore_grid if scene != null else null)
	var p4: int = Time.get_ticks_usec()
	_tell_the_race()
	var p5: int = Time.get_ticks_usec()
	race.step(delta)
	for kind: RaceStartSignals.Kind in _start_signals.update(race.is_started(), race.clock_s()):
		start_signal.emit(kind)
	var p6: int = Time.get_ticks_usec()
	_judge(delta)
	var p7: int = Time.get_ticks_usec()
	_add_part_times([p0, p1, t0, t1, p4, p5, p6, p7])
	_us_physics += t1 - t0
	_us_race += Time.get_ticks_usec() - t1
	_ticks_counted += 1
	_tick += 1
	if _report_every_s > 0.0 and race.clock_s() >= _report_at_s:
		_report_at_s = race.clock_s() + _report_every_s
		_print_report()


## Adds the time between each pair of the tick's marks to its part (PART_NAMES).
func _add_part_times(marks: Array[int]) -> void:
	for i: int in PART_NAMES.size():
		_us_parts[i] += marks[i + 1] - marks[i]


## The parked board's simulation is not stepped, but the water on the screen runs on its clock
## (main.gd gives the ocean the player's board's simulation): while it is parked it takes the clock of
## a board that sails, so the waves drawn move, and are the waves the AI boards float on (before, they
## stood still while watching; found for Max's films, 10 November 2026). No board sailing here (a LAN
## race of other PCs' boards only): its clock runs on by itself.
func _keep_the_parked_boards_clock(stopped: PackedByteArray, delta: float) -> void:
	if not player_parked or player == null:
		return
	for i: int in _boards.size():
		if stopped[i] == 0 and not _boards[i].is_puppet and _boards[i] != player:
			player.sim.time_s = _boards[i].sim.time_s
			return
	player.sim.time_s += delta


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
## the same); unchanged if none did (the player alone and aground, or every board aground). A player
## who watches a race of other PCs' boards only (no AI board steps here) keeps the clock going with
## the parked board's own wind field, so the gusts still roll on every PC.
func _read_the_wind_clock(stopped: PackedByteArray, delta: float) -> void:
	for i: int in _boards.size():
		if stopped[i] == 1 or _boards[i].is_puppet:
			continue
		wind_clock = RaceWindClock.of(_boards[i].sim.wind)
		return
	if player_parked and player != null:
		player.sim.wind.step(delta)
		wind_clock = RaceWindClock.of(player.sim.wind)


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
## gives a board a new field, so it is told every tick: one field write). The sails' trails move on
## by the tick's time first (WindShadowTrail: the shadows lie along them).
func _cast_shadows(delta: float) -> void:
	if not setup.shadows:
		return
	if _shadows.size() != _boards.size():
		_shadows.clear()
		for _node: WindsurferNode in _boards:
			_shadows.append(WindShadows.make())
	if _trail == null:
		_trail = WindShadowTrail.make()
	var xs: PackedFloat32Array = PackedFloat32Array()
	var zs: PackedFloat32Array = PackedFloat32Array()
	var casts: PackedByteArray = PackedByteArray()
	var sims: Array[WindsurferSim] = []
	for node: WindsurferNode in _boards:
		var position: Vector3 = node.sim.telemetry.position
		xs.append(position.x)
		zs.append(position.z)
		casts.append(1 if node.sim.sailor_state == WindsurferSim.SailorState.SAILING and node.visible else 0)
		sims.append(node.sim)
	_trail.update(delta, sims, casts)
	var points: PackedFloat32Array = _trail.points()
	for i: int in _boards.size():
		_shadows[i].set_fleet(xs, zs, casts, i)
		_shadows[i].set_trail(points, i)
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
func _step_board(i: int, delta: float, stopped: PackedByteArray, controls_there: PackedByteArray) -> void:
	if stopped[i] == 1:
		return
	if controls_there[i] == 1:
		_boards[i].set_the_controls(delta)
	_boards[i].step_physics(delta)


## Every board's step (_step_board) as a task of its own on the worker threads, in the boards' order;
## the ids, for _wait_for_steps(). The pool's threads take the tasks in turn as each finishes one,
## so a thread on a slow core takes fewer boards and the tick waits for nobody's fixed share.
func _start_the_steps(delta: float, stopped: PackedByteArray, controls_there: PackedByteArray) -> PackedInt64Array:
	var steps: PackedInt64Array = PackedInt64Array()
	for i: int in _boards.size():
		steps.append(WorkerThreadPool.add_task(_step_board.bind(i, delta, stopped, controls_there), true, "race physics"))
	return steps


## Waits until the steps of the boards from `first` up to (not including) `end` are done (each task
## is waited for once). No steps (the boards stepped on this thread): nothing to wait for.
func _wait_for_steps(steps: PackedInt64Array, first: int, end: int) -> void:
	for i: int in range(first, mini(end, steps.size())):
		WorkerThreadPool.wait_for_task_completion(steps[i])


## Which boards' controllers run in _step_board (1) rather than on this thread before it (0): the AI
## boards' when the boards are stepped on worker threads (WindsurferNode.controls_on_worker_thread()).
## Each board still runs its skipper, its controller and its physics in that order, with the same
## inputs, so the race is the same to the last bit (checked with --race_report's state hash).
func _controls_on_worker_threads(stopped: PackedByteArray) -> PackedByteArray:
	var there: PackedByteArray = PackedByteArray()
	there.resize(_boards.size())
	for i: int in _boards.size():
		there[i] = 1 if setup.threads > 0 and stopped[i] == 0 and _boards[i].controls_on_worker_thread() else 0
	return there



## After the physics, on this thread: every board's visuals. An opponent farther than
## FAR_DETAIL_M from the camera is posed on alternate ticks (half of them on the even ticks, half
## on the odd, so the cost is even); its place on the water is set every tick. An opponent out of the
## camera's view, and farther than ALWAYS_POSED_M, is posed on every OUT_OF_VIEW_POSE_TICKS-th tick
## only (13 November 2026): nobody sees its sailor and rig, and the board itself still moves every tick.
func _pose_boards(player_stopped: bool, steps: PackedInt64Array) -> void:
	# The opponents are the last boards (the player's, when it sails here, the first).
	var first_opponent: int = _boards.size() - opponents.size()
	_wait_for_steps(steps, 0, first_opponent)
	if not player_stopped and not spectating and not player_parked:
		player.after_step()
	# The other players' boards (LAN multiplayer) are posed by NetBoards as their states come in.
	var camera: Camera3D = get_viewport().get_camera_3d()
	var eye: Vector3 = camera.global_position if camera != null else player.global_position
	var view: Array[Plane] = []
	if camera != null:
		view = camera.get_frustum()
	for i: int in opponents.size():
		_wait_for_steps(steps, first_opponent + i, first_opponent + i + 1)
		var node: WindsurferNode = opponents[i]
		var distance_m: float = node.global_position.distance_to(eye)
		var far: bool = distance_m > DrawDistance.full_detail_m()
		var seen: bool = distance_m < ALWAYS_POSED_M or in_view(view, node.global_position)
		# Out of view the rig's frame-by-frame work (the fin's bend) stops too, as far away.
		node.set_far_away(far or not seen)
		var pose: bool = (not far or (_tick + i) % 2 == 0) if seen else (_tick + i) % OUT_OF_VIEW_POSE_TICKS == 0
		node.after_step(pose)
		_in_view_count += 1 if seen else 0


## Whether a board at `at` may show in the picture: inside the camera's view (its six planes,
## Camera3D.get_frustum(), facing out) or within VIEW_MARGIN_M of it, so a mast, a sail or a
## sailor reaching in from a board just outside counts as seen. No view (no camera): seen.
static func in_view(view: Array[Plane], at: Vector3) -> bool:
	for plane: Plane in view:
		if plane.distance_to(at) > VIEW_MARGIN_M:
			return false
	return true


## What a tick of the runner costs on average since the last call, milliseconds (--measure).
func cost_text() -> String:
	var ticks: float = maxf(float(_ticks_counted), 1.0)
	var how: String = "side by side, %d tasks" % setup.threads if setup.threads > 0 else "one after the other"
	var text: String = "all boards' physics %.2f ms (%s), the race's checks and the visuals %.2f ms per tick" % [
		_us_physics / ticks / 1000.0, how, _us_race / ticks / 1000.0]
	var parts: PackedStringArray = PackedStringArray()
	for i: int in PART_NAMES.size():
		parts.append("%s %.2f" % [PART_NAMES[i], _us_parts[i] / ticks / 1000.0])
		_us_parts[i] = 0
	text += "\n  the tick's parts (ms per tick): " + ", ".join(parts)
	text += "\n  AI boards in the camera's view: %.1f of %d on average" % [_in_view_count / ticks, opponents.size()]
	_in_view_count = 0
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
	return "%d, %d of them beyond %d m or out of view: physics median %.2f, worst %.2f; sailor median %.2f, worst %.2f; visuals median %.2f, worst %.2f ms per tick" % [
		opponents.size(), far, roundi(DrawDistance.full_detail_m()), median(physics), worst(physics), median(sailor), worst(sailor), median(visuals), worst(visuals)]


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
	if not _running or not course.is_raced():
		return
	_watch_when_finished()
	if player_parked:
		choice.update(watch_order(), delta)
	var index: int = followed_index()
	if index < 0:
		return  # nobody on the water to watch yet
	var node: WindsurferNode = followed_node()
	hud.set_watching(race.board_name(index) if player_parked else "", choice.follows_leader, RaceHud.watch_place_text(race, index) if player_parked else "")
	# While a player who finished watches the others, the finish list stays on the screen.
	hud.results_wanted = player_parked and not spectating and race.is_finished(0)
	hud.update_from(race, index, node.telemetry(), shadow_deficit(node), rules)
	_check_record()
	_hud_layer.set_next_mark_bearing(Course.bearing_deg(_where(node), race.next_target(index)))


## The race card and the race's keys while racing; the plain sailing screen while sailing free
## (Course.RaceType.FREE).
func _show_race_card(racing: bool) -> void:
	hud.visible = racing
	_hud_layer.set_race_mode(racing, spectating)


## Whether the boards are sailing free on the course (its race type FREE): no countdown, no race.
func is_free_sailing() -> bool:
	return course != null and not course.is_raced()


## The race's number of the board the camera follows: the player's (0), or while the player's board
## is parked the board the SpectateChoice follows; -1 while there is nobody on the water to watch.
func followed_index() -> int:
	if not player_parked:
		return 0
	if race != null and choice.followed >= 0 and choice.followed < race.board_count():
		return choice.followed
	return -1


## The board the camera, the HUD's block and the sounds follow (the player's when not watching, and
## while there is nobody to watch).
func followed_node() -> WindsurferNode:
	var index: int = followed_index()
	if not player_parked or index < 0:
		return player
	var node: WindsurferNode = board_node(index)
	return node if node != null else player


## The board with a race number: the player's (first, unless spectating), the other players' (LAN
## multiplayer), the AI boards'; null for none.
func board_node(index: int) -> WindsurferNode:
	var at: int = index
	if not spectating:
		if at == 0:
			return player
		at -= 1
	if at >= 0 and at < remote_players.size():
		return remote_players[at] if is_instance_valid(remote_players[at]) else null
	at -= remote_players.size()
	if at >= 0 and at < opponents.size():
		return opponents[at]
	return null


## The player's board's number in the race, -1 while spectating.
func player_index() -> int:
	return -1 if spectating else 0


## The boards the camera may follow, in race order: every board on the water (a parked board, the
## player's own or another PC's, is not; nor another PC's before its first state has come).
func watch_order() -> Array[int]:
	if race == null:
		return []
	return SpectateChoice.watchable(race.race_order(), func(index: int) -> bool:
		var node: WindsurferNode = board_node(index)
		return node != null and node.visible)


## Tab (+1) and Shift+Tab (-1) while watching: the next or the previous board in race order.
func step_followed(by: int) -> void:
	if player_parked and race != null:
		choice.step(watch_order(), by)


## L while watching: follow the leader again.
func follow_leader() -> void:
	if player_parked and race != null:
		choice.follow_leader(watch_order())


## The TV camera's cut while watching (WatchMode): the camera to this board, which it keeps following
## (not the leader by itself) until told otherwise. A board not on the water is not taken.
func watch_board(index: int) -> void:
	if player_parked and race != null and watch_order().has(index):
		choice.followed = index
		choice.follows_leader = false


## The menu's Spectate (LAN multiplayer): the player stops racing and watches. A board in the race
## under way retires from it (the results say so on every PC); the board leaves the water and comes
## back at the next start, unless the player also chooses to stay a spectator.
func spectate_now() -> void:
	if race != null and not spectating and race.phase() != RaceSim.Phase.FINISHED and not race.is_finished(0):
		race.retire(0)
	_set_player_parked(true)


## Whether the player watches from now on (true) or races again from the next start (false).
func set_stays_spectator(stays: bool) -> void:
	if stays == stays_spectator:
		return
	stays_spectator = stays
	watch_changed.emit()


## A LAN player who has finished: WATCH_AFTER_FINISH_S after the line (or when the race is over), the
## board leaves the water and the camera goes to the others.
func _watch_when_finished() -> void:
	if not watch_after_finish or player_parked or spectating or race == null or not race.is_finished(0):
		return
	var splits: PackedFloat32Array = race.splits_s(0)
	var crossed_s: float = splits[splits.size() - 1] if not splits.is_empty() else race.finish_time_s(0)
	if race.phase() == RaceSim.Phase.FINISHED or race.race_time_s() - crossed_s >= WATCH_AFTER_FINISH_S:
		_set_player_parked(true)


## The player's board off the water (hidden, not stepped, out of the wind shadows and the judge's
## view) or back on it; the HUD's keys follow.
func _set_player_parked(parked: bool) -> void:
	var changed: bool = parked != player_parked or player.visible == parked
	player_parked = parked
	player.visible = not parked
	if not changed:
		return
	if not parked:
		player.reset_physics_interpolation()
	choice = SpectateChoice.new()
	if _hud_layer != null:
		_hud_layer.set_race_mode(true, parked)
	watch_changed.emit()


## The race is told where every board is (the player first, unless spectating).
func _tell_the_race() -> void:
	if not spectating:
		race.update_board(0, _where(player))
	var first_remote: int = 0 if spectating else 1
	for i: int in remote_players.size():
		# Not before its first state has come (the puppet shows then): until then it is nowhere. Nor
		# while it is off the water (that player watches).
		if remote_players[i].visible:
			race.update_board(first_remote + i, where_now(remote_players[i]))
	for i: int in opponents.size():
		race.update_board(i + _first_ai, _where(opponents[i]))
	_tell_the_race_the_wind()


## The wind of the moment for the race's smart order (RaceSim.set_wind(): the boards ranked by the
## polar's time to the finish, with the laylines): where it blows from and how strong it is at 10 m,
## the wind field's own (on the lake the lake's mean, not a gust at one board), read from an AI board
## that sails (the parked player's board is not stepped while watching), else from the player's.
func _tell_the_race_the_wind() -> void:
	var source: WindsurferNode = opponents[0] if not opponents.is_empty() else player
	if source == null or source.sim == null or source.sim.wind == null:
		return
	var wind: WindField = source.sim.wind
	race.set_wind(rad_to_deg(wind.current_from_bearing_rad), wind.speed_at_height(10.0) / SimMath.KNOT_MS)


## The other boards' places, for the small map: every board of the race on the water but the one
## followed (which is the map's own dot).
func other_positions() -> PackedVector3Array:
	var positions: PackedVector3Array = PackedVector3Array()
	var followed: WindsurferNode = followed_node()
	for node: WindsurferNode in _boards:
		if node != followed and is_instance_valid(node) and node.visible:
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
	print("  the fleet's state: %d" % _fleet_state_hash())
	_reported_polars = true


## One number for every board's exact state (place, speed, attitude, turn, controls), so two runs
## can be compared to the last bit: the same number, the same race (a change that should leave the
## race alone, such as where a board's controller runs, 13 November 2026).
func _fleet_state_hash() -> int:
	var numbers: PackedFloat64Array = PackedFloat64Array()
	for node: WindsurferNode in _boards:
		var body: SimRigidBody = node.sim.body
		for v: Vector3 in [body.position, body.velocity, body.angular_velocity, body.basis.x, body.basis.y, body.basis.z]:
			numbers.append_array([v.x, v.y, v.z])
		numbers.append_array([node.controls.sheet, node.controls.rake, node.controls.lean, node.controls.boom_across, node.sim.time_s])
	return hash(numbers)
