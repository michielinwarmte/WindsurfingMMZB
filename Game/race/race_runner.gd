class_name RaceRunner
extends Node
## A race in a sailing scene (RACING_PLAN.md, 9A and 9B): the player's board and the AI skippers'
## boards on one start line, the race's own checks and clock (RaceSim), and the race on the screen
## (RaceHud). It steps no physics itself: every WindsurferNode runs its own simulation in its
## _physics_process, and this node, added after them so it runs after them each tick, tells the
## race where they are. The skippers sail through the beginner controller with their AiHands, as
## the player does (RD1); nothing here touches the physics.

const WINDSURFER_SCENE: String = "res://windsurfer/windsurfer.tscn"
## How far back from the line the boards wait per second of countdown, and the nearest and the
## farthest: 60 m for the menu's 60 s. (The race tool waits further back, 2.5 m per second, for
## its fixed-angle pilot; a player wants the line in sight: Max, 20 October 2026.)
const WAIT_M_PER_S: float = 1.0
const NEAREST_M: float = 40.0
const FARTHEST_M: float = 100.0
const PLAYER_NAME: String = "You"
## At most this many worker-thread tasks step the boards' physics side by side, each a batch of
## boards one after the other (32 AI boards and the player: five or four per task). GDScript
## threads wait on a global engine lock, so more than about eight threads make a fleet slower,
## not faster (Session 51: 14 threads ran 3 times slower than 1). --threads=<n> sets another
## number, --threads=0 steps the boards one after the other on this thread.
const MAX_THREADS: int = 8
## An opponent farther than this from the camera is drawn with less care (its name label is
## hidden at the same distance, WindsurferNode.set_name_label): its sailor, rig and sail are posed
## every other tick, and its fin's bend is not updated. At 300 m a sailor is a few pixels tall.
## The physics and the skipper are never leveled: only what is drawn.
const FAR_DETAIL_M: float = 300.0

var race: RaceSim = null
var course: Course = null
var setup: RaceSetup = null
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
## What the runner's own tick costs (the physics of all boards, side by side or not, and the
## race's checks), microseconds since the last cost_text().
var _us_physics: int = 0
var _us_race: int = 0
var _ticks_counted: int = 0
## The boards' numbers (into _boards) shared over the worker-thread tasks: one batch per task, the
## player's board in the first. Worked out again when the fleet's size changes.
var _batches: Array[PackedInt32Array] = []
var _batched_boards: int = -1
## The ticks since the race was built, for posing the far boards on alternate ticks.
var _tick: int = 0


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
	hud_layer.set_race_mode(true)
	# The runner steps the player's board with the others (its own _physics_process steps nothing).
	player.stepped_by_runner = true
	_boards = [player]
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
		player.get_parent().add_child(node)
		node.hands = AiHands.new()
		node.controller.hands = node.hands
		node.skipper = skipper
		node.set_sail_colour(skipper.sail_colour())
		node.set_name_label(skipper.board_name())
		opponents.append(node)
		_boards.append(node)
		_skippers.append(skipper)
	restart()


## Everyone back to the start and a new countdown (the first start, and R): the player behind the
## line, the AI boards at their random spots in the sailing area (or behind the line too, with the
## setup's spawn LINE). The countdown starts at once, or after the setup's free sailing.
func restart() -> void:
	race = RaceSim.new(course, setup.laps, setup.prestart_s)
	race.add_board(PLAYER_NAME)
	for skipper: RaceSkipper in _skippers:
		race.add_board(skipper.board_name())
	var behind_m: float = clampf(setup.prestart_s * WAIT_M_PER_S, NEAREST_M, FARTHEST_M)
	var spots: PackedVector2Array = pre_start_spots(course, race.steps()[0], opponents.size() + 1, behind_m)
	var heading_deg: float = RaceCourses.pre_start_heading_deg(course)
	_place(player, spots[0], heading_deg)
	if setup.spawn == RaceSetup.Spawn.RANDOM:
		var places: Array[Vector3] = _area.spawn_places(opponents.size(), setup.spawn_seed, spots[0])
		for i: int in opponents.size():
			_place(opponents[i], Vector2(places[i].x, places[i].y), places[i].z)
	else:
		for i: int in opponents.size():
			_place(opponents[i], spots[i + 1], heading_deg)
	# The skippers look at the whole fleet, so they are set up once every board is in the race.
	for i: int in opponents.size():
		_skippers[i].random_seed = i + 1
		_skippers[i].sailing_area = _area
		_skippers[i].setup(opponents[i].sim, opponents[i].controller, opponents[i].hands, race, i + 1)
	_tell_the_race()
	race.start_in(setup.free_sail_s)
	hud.reset()
	_running = true


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


func _place(node: WindsurferNode, spot: Vector2, heading_deg: float) -> void:
	node.start_position = Vector3(spot.x, 0.0, spot.y)
	node.start_heading_deg = heading_deg
	node.reset()


## One tick of the race: every board's sailor sets its controls (on this thread: the skippers read
## the race), then every board's physics steps, side by side on worker threads when the setup says
## so (each simulation touches only its own objects; at most MAX_THREADS tasks, each a batch of
## boards), then the visuals (the far opponents' on alternate ticks), then the race is told where
## everyone is. A board that has run aground (the scene stops it) is not stepped.
func _physics_process(delta: float) -> void:
	if not _running:
		return
	var scene: SailingScene = get_parent() as SailingScene
	var player_stopped: bool = scene != null and scene.is_aground()
	for node: WindsurferNode in _boards:
		if not (player_stopped and node == player):
			node.sail(delta)
	var t0: int = Time.get_ticks_usec()
	if setup.threads > 0:
		if _batched_boards != _boards.size():
			_batches = batches(_boards.size(), setup.threads)
			_batched_boards = _boards.size()
		var group: int = WorkerThreadPool.add_group_task(_step_batch.bind(delta, player_stopped), _batches.size(), -1, true, "race physics")
		WorkerThreadPool.wait_for_group_task_completion(group)
	else:
		for i: int in _boards.size():
			_step_board(i, delta, player_stopped)
	var t1: int = Time.get_ticks_usec()
	_pose_boards(player_stopped)
	_tell_the_race()
	race.step(delta)
	_us_physics += t1 - t0
	_us_race += Time.get_ticks_usec() - t1
	_ticks_counted += 1
	_tick += 1


## Task `task`'s batch of boards, one after the other (a worker thread's task).
func _step_batch(task: int, delta: float, player_stopped: bool) -> void:
	for i: int in _batches[task]:
		_step_board(i, delta, player_stopped)


## Board i's physics (a batch's, or the loop's).
func _step_board(i: int, delta: float, player_stopped: bool) -> void:
	if player_stopped and i == 0:
		return
	_boards[i].step_physics(delta)


## `count` boards' numbers shared over at most `max_batches` batches as evenly as can be, in order
## (board 0, the player's, in the first; the first batches take one more when it does not share
## out evenly): 33 boards over 8 are 5, 4, 4, 4, 4, 4, 4, 4. Fewer boards than batches: one each.
static func batches(count: int, max_batches: int) -> Array[PackedInt32Array]:
	var shared: Array[PackedInt32Array] = []
	var batch_count: int = mini(count, maxi(max_batches, 1))
	var next: int = 0
	for b: int in batch_count:
		var size: int = count / batch_count + (1 if b < count % batch_count else 0)
		var batch: PackedInt32Array = PackedInt32Array()
		for k: int in size:
			batch.append(next)
			next += 1
		shared.append(batch)
	return shared


## After the physics, on this thread: every board's visuals. An opponent farther than
## FAR_DETAIL_M from the camera is posed on alternate ticks (half of them on the even ticks, half
## on the odd, so the cost is even); its place on the water is set every tick.
func _pose_boards(player_stopped: bool) -> void:
	if not player_stopped:
		player.after_step()
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
	var how: String = "side by side, %d tasks" % _batches.size() if setup.threads > 0 else "one after the other"
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


func _process(_delta: float) -> void:
	if _running:
		hud.update_from(race, 0, player.telemetry())
		_hud_layer.set_next_mark_bearing(Course.bearing_deg(_where(player), race.next_target(0)))


## The race is told where every board is (the player first).
func _tell_the_race() -> void:
	race.update_board(0, _where(player))
	for i: int in opponents.size():
		race.update_board(i + 1, _where(opponents[i]))


## The other boards' places, for the small map.
func other_positions() -> PackedVector3Array:
	var positions: PackedVector3Array = PackedVector3Array()
	for node: WindsurferNode in opponents:
		positions.append(node.sim.telemetry.position)
	return positions


static func _where(node: WindsurferNode) -> Vector2:
	var position: Vector3 = node.sim.telemetry.position
	return Vector2(position.x, position.z)
