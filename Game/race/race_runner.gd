class_name RaceRunner
extends Node
## A race in a sailing scene (RACING_PLAN.md, 9A and 9B): the player's board and the AI skippers'
## boards on one start line, the race's own checks and clock (RaceSim), and the race on the screen
## (RaceHud). It steps no physics itself: every WindsurferNode runs its own simulation in its
## _physics_process, and this node, added after them so it runs after them each tick, tells the
## race where they are. The skippers sail through the beginner controller with their AiHands, as
## the player does (RD1); nothing here touches the physics.

const WINDSURFER_SCENE: String = "res://windsurfer/windsurfer.tscn"
## How far back from the line a board waits per second of countdown (about what a board starting
## from rest sails in that time), and the nearest it is put: the race tool's numbers
## (dev/run_race.gd), so the game and the tool start the same way.
const WAIT_M_PER_S: float = 2.5
const NEAREST_M: float = 40.0
const PLAYER_NAME: String = "You"

var race: RaceSim = null
var course: Course = null
var setup: RaceSetup = null
var player: WindsurferNode = null
var opponents: Array[WindsurferNode] = []
var hud: RaceHud = null
var _skippers: Array[RaceSkipper] = []
var _running: bool = false


func _ready() -> void:
	# The countdown and the race clock stop with the physics when the game is paused.
	process_mode = Node.PROCESS_MODE_PAUSABLE


## Builds the race: one board per skipper beside the player's, the race HUD on the scene's HUD
## layer, and the first start.
func setup_race(race_course: Course, player_node: WindsurferNode, race_setup: RaceSetup, hud_layer: Node) -> void:
	course = race_course
	player = player_node
	setup = race_setup
	hud = RaceHud.new()
	hud.name = "RaceHud"
	hud_layer.add_child(hud)
	var scene: PackedScene = load(WINDSURFER_SCENE)
	for skipper_name: String in setup.skippers:
		var skipper: RaceSkipper = Skippers.make(skipper_name)
		if skipper == null:
			continue
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
		player.get_parent().add_child(node)
		node.hands = AiHands.new()
		node.controller.hands = node.hands
		node.skipper = skipper
		node.set_sail_colour(skipper.sail_colour())
		node.set_name_label(skipper.skipper_name())
		opponents.append(node)
		_skippers.append(skipper)
	restart()


## Everyone back behind the line and a new countdown (the first start, and R).
func restart() -> void:
	race = RaceSim.new(course, setup.laps, setup.prestart_s)
	race.add_board(PLAYER_NAME)
	for skipper: RaceSkipper in _skippers:
		race.add_board(skipper.skipper_name())
	var behind_m: float = clampf(setup.prestart_s * WAIT_M_PER_S, NEAREST_M, RaceCourses.PRE_START_BEHIND_M)
	var spots: PackedVector2Array = pre_start_spots(course, race.steps()[0], opponents.size() + 1, behind_m)
	var heading_deg: float = RaceCourses.pre_start_heading_deg(course)
	_place(player, spots[0], heading_deg)
	for i: int in opponents.size():
		_place(opponents[i], spots[i + 1], heading_deg)
	# The skippers look at the whole fleet, so they are set up once every board is in the race.
	for i: int in opponents.size():
		_skippers[i].random_seed = i + 1
		_skippers[i].setup(opponents[i].sim, opponents[i].controller, opponents[i].hands, race, i + 1)
	_tell_the_race()
	race.start()
	hud.reset()
	_running = true


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


func _physics_process(delta: float) -> void:
	if not _running:
		return
	_tell_the_race()
	race.step(delta)


func _process(_delta: float) -> void:
	if _running:
		hud.update_from(race, 0)


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
