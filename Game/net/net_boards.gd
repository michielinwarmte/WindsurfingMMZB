class_name NetBoards
extends Node
## LAN multiplayer in the sailing scene (Documentation/reports/multiplayer/PLAN.md, D3 to D8). The
## sailing scene (main.gd) adds it when the game is a network game (Lan.in_game).
##
## Each PC sails its own board's full physics; the host also sails the AI boards (its RaceRunner).
## Every board sailed on the other PC is a puppet here (WindsurferNode.is_puppet): a real simulation
## that is not stepped, into which the other PC's states are written (BoardSnapshot), so its rig, sail,
## sailor and spray are what the other PC's physics did.
##
## Every tick:
## 1. (before the boards step, process priority -10) the clocks: the host's boards sail on the
##    host's water clock; the guest's board sails on the host's water and wind clocks as NetClock
##    estimates them (D7). Then every puppet is given its state for the moment it is shown at: a few
##    ticks behind the newest, between the two states around it (StateBuffer, D6).
## 2. the boards step (each WindsurferNode, or the host's RaceRunner).
## 3. (after them, the Sender child, priority 100) this PC's boards' states go out: the own board's
##    every tick, the AI boards' every AI_SEND_EVERY ticks, the host's clock every tick and the race's
##    state every RACE_STATE_EVERY ticks. Each board sends its whole state once (its keyframe) and
##    after that what differs from it.
##
## The race (D8): the host's RaceRunner races every board, the guest's puppet included (not stepped;
## judged where it is now, its state moved on by its speed for its age). The guest's RaceMirror shows
## the host's race and judge.
##
## Board numbers on the network: a player's is their slot (0 the host, 1 the guest), an AI board's
## AI_ID_BASE plus its place in the fleet.

const AI_ID_BASE: int = 100
## The AI boards' states go out every this many ticks (20 a second), each on its own tick of the
## three so the load is even; the players' every tick. (Reading a board's whole state costs the host
## 0.1 to 0.2 ms and writing it into a puppet the guest as much: with 19 AI boards at 30 a second
## the host fell behind real time on Max's laptop, Session 69.)
const AI_SEND_EVERY: int = 3
## How many ticks behind the newest state a board is shown: a player's board (states every tick) and
## an AI board (every 3rd tick). Two ticks of margin for a message that comes late.
const PLAYER_SHOW_DELAY_TICKS: float = 3.0
const AI_SHOW_DELAY_TICKS: float = 5.0
## The race's state goes to the guest ten times a second.
const RACE_STATE_EVERY: int = 6
## A puppet beyond RaceRunner.FAR_DETAIL_M from the camera takes a whole new state at most every
## this many ticks (15 a second); its place moves every tick.
const FAR_STATE_EVERY: int = 4
## In free sailing the guest starts this far upwind of the host's start spot (no one on top of the
## other; upwind is open water on the lake too, where the beach is behind the start).
const FREE_SAIL_APART_M: float = 30.0
## The guest's game never runs slower than this share of real time to keep the host's pace, nor
## faster than real time; each tick it moves this share of the way to the host's pace.
const PACE_MIN: float = 0.4
const PACE_FOLLOW: float = 0.02
## How long the message stays after the other player left, before a host's race simply goes on.
const LEFT_MESSAGE_S: float = 6.0

var scene: SailingScene = null
## This PC's board.
var own: WindsurferNode = null
## Every board sailed on another PC, by its network number.
var puppets: Dictionary[int, WindsurferNode] = {}
## The host's race (null on the guest and in free sailing); the guest's mirror of it.
var runner: RaceRunner = null
var mirror: RaceMirror = null

var _buffers: Dictionary[int, StateBuffer] = {}
var _keyframes_in: Dictionary[int, BoardSnapshot] = {}
var _keyframes_out: Dictionary[int, BoardSnapshot] = {}
## Which peer sails each puppet (to drop a state for a board that is not theirs).
var _owners: Dictionary[int, int] = {}
var _clock: NetClock = NetClock.new()
## The game's own physics rate (project.godot): a tick is always 1 / NORMAL_TICKS s of game time,
## also while the guest keeps a slow host's pace (keep_the_hosts_pace()).
var _normal_ticks: int = 60
## The pace the guest follows, a share of real time (1 = real time).
var _pace: float = 1.0
## The host's tick when the scene began: its water clock counts from there.
var _start_tick: int = 0
var _dt: float = 1.0 / 60.0
## The guests whose scene is loaded (the host sends them the boards).
var _ready_peers: Array[int] = []
var _sender: Node = null
## The puppets that have shown a state (the first one also resets the smoothing between frames).
var _shown: Dictionary[int, bool] = {}
## The state each puppet's simulation holds now, and its tick (apply() writes only what changed).
var _applied: Dictionary[int, BoardSnapshot] = {}
var _applied_tick: Dictionary[int, int] = {}
## The parts of a board's state that have come so far, by board and tick (on_state_part()).
var _parts: Dictionary[Vector2i, Array] = {}
var _message_until_s: float = -1.0
## Measured traffic, bytes since the last report.
var _bytes_out: int = 0
var _bytes_in: int = 0
var _states_in: int = 0
var _states_late: int = 0
## What NetBoards costs, microseconds since the last report: showing the puppets (the tick's first
## half), reading the states that came in, and sending this PC's (the Sender); and the ticks counted.
var _us_show: int = 0
var _us_read: int = 0
var _us_send: int = 0
var _us_capture: int = 0
var _us_rpc: int = 0
## Real seconds since the scene began (the report: game time against real time).
var _real_start_ms: int = 0
var _ticks_costed: int = 0
## --lan_report=<s> / --lan_quit=<s> (LanSession's note).
var _report_every_s: float = 0.0
var _report_at_s: float = 0.0
var _quit_at_s: float = -1.0
var _clock_s: float = 0.0
## --lan_track=<n>: in the first AI_SEND_EVERY ticks of every n host ticks, a TRACK line for each
## state this PC sends and a SEEN line for each state a puppet takes (tools/lan_test.sh compares
## them: the sync check). 0: none.
var _track_every: int = 0
## --lan_robot=<skipper>: a scripted skipper sails this PC's board in a race (tools/lan_test.sh races
## two robots and the AI fleet to the finish and compares both PCs' results). Empty: the player sails.
var _robot_name: String = ""
var _results_printed: bool = false


## The after-physics half of the tick (step 3 in the note at the top).
class Sender:
	extends Node
	var owner_boards: NetBoards = null

	func _physics_process(_delta: float) -> void:
		owner_boards.send_states()


func _init() -> void:
	name = "NetBoards"
	process_physics_priority = -10


## Builds the puppets of the other players and starts listening. `sailing` is the scene, `mine`
## this PC's board, both ready.
func setup(sailing: SailingScene, mine: WindsurferNode) -> void:
	scene = sailing
	own = mine
	_normal_ticks = int(ProjectSettings.get_setting("physics/common/physics_ticks_per_second", 60))
	_dt = 1.0 / float(_normal_ticks)
	_start_tick = Engine.get_physics_frames()
	_real_start_ms = Time.get_ticks_msec()
	process_mode = Node.PROCESS_MODE_ALWAYS
	_sender = Sender.new()
	_sender.name = "Sender"
	_sender.owner_boards = self
	_sender.process_physics_priority = 100
	_sender.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_sender)
	var options: Dictionary[String, String] = LanSession.command_line_options()
	_report_every_s = options.get("lan_report", "0").to_float()
	_quit_at_s = options.get("lan_quit", "-1").to_float()
	_track_every = maxi(options.get("lan_track", "0").to_int(), 0)
	_robot_name = options.get("lan_robot", "")
	if not Lan.game.race:
		_place_for_free_sailing()
	for player: LanPlayer in Lan.game.players:
		if player.slot != Lan.my_slot:
			var puppet: WindsurferNode = _make_puppet(player.slot, player.gear(), player.name, Color.TRANSPARENT, true)
			_owners[player.slot] = player.peer_id
			puppet.visible = false
	Lan.register_handler(self)
	if Lan.is_guest():
		_send_own_keyframe(1)
		Lan.send_scene_ready()
	print("LAN: in the game as %s (slot %d), %d other player(s): %s" % [Lan.my_name, Lan.my_slot, Lan.game.players.size() - 1, Lan.game.summary()])


func _exit_tree() -> void:
	Lan.unregister_handler(self)
	restore_pace()


## In free sailing each player starts at the usual spot, the guest FREE_SAIL_APART_M upwind of it.
func _place_for_free_sailing() -> void:
	if Lan.my_slot <= 0:
		return
	var upwind: Vector3 = own.sim.wind.from_direction()
	own.start_position += upwind * FREE_SAIL_APART_M * Lan.my_slot
	own.reset()


## A puppet: a board with the gear it sails on the other PC, its name above it, the same place, wind
## and sea as this PC's board, never stepped here.
func _make_puppet(id: int, gear: GearChoice, label: String, colour: Color, effects: bool) -> WindsurferNode:
	var node: WindsurferNode = (load(RaceRunner.WINDSURFER_SCENE) as PackedScene).instantiate()
	node.name = "NetBoard%d" % id
	node.is_puppet = true
	node.environment = own.environment
	node.wind_config = own.wind_config
	node.wave_set_config = own.wave_set_config
	node.start_position = own.start_position
	node.start_heading_deg = own.start_heading_deg
	node.gear = gear
	node.own_config_copies = true
	node.wind_flag_wanted = false
	node.effects_wanted = effects
	# Posed here, right after its state is written (_show_puppet()), not in its own tick.
	node.stepped_by_runner = true
	node.process_mode = Node.PROCESS_MODE_ALWAYS
	scene.add_child(node)
	if colour != Color.TRANSPARENT:
		node.set_sail_colour(colour)
	node.set_name_label(label)
	puppets[id] = node
	_buffers[id] = StateBuffer.new()
	return node


## The other players' slots, in slot order.
func remote_slots() -> Array[int]:
	var list: Array[int] = []
	for player: LanPlayer in Lan.game.players:
		if player.slot != Lan.my_slot and puppets.has(player.slot):
			list.append(player.slot)
	return list


## The other players' boards and names (for the host's RaceRunner), in slot order.
func remote_players() -> Array[WindsurferNode]:
	var list: Array[WindsurferNode] = []
	for slot: int in remote_slots():
		list.append(puppets[slot])
	return list


func remote_names() -> PackedStringArray:
	var list: PackedStringArray = PackedStringArray()
	for slot: int in remote_slots():
		list.append(Lan.game.player_in(slot).name)
	return list


## Every puppet's place, for the small map.
func puppet_positions() -> PackedVector3Array:
	var positions: PackedVector3Array = PackedVector3Array()
	for id: int in puppets:
		if puppets[id].visible:
			positions.append(puppets[id].sim.telemetry.position)
	return positions


## The host's race: its restarts go to the guests.
func attach_runner(race_runner: RaceRunner) -> void:
	runner = race_runner
	runner.restarted.connect(_on_runner_restarted)
	_put_robot_on_board(runner.race, 0, runner.rules, runner.sailing_area())


## The guest's race: a mirror of the host's.
func start_mirror(course: Course, setup: RaceSetup, hud_layer: Hud) -> void:
	mirror = RaceMirror.new()
	mirror.name = "RaceMirror"
	scene.add_child(mirror)
	mirror.setup(course, setup, hud_layer, own, self)


# ---------------------------------------------------------------- step 1: the clocks and the puppets

func _physics_process(_delta: float) -> void:
	var my_tick: int = Engine.get_physics_frames()
	_clock_s += _dt
	var now_tick: int = my_tick
	if Lan.is_host():
		_keep_host_boards_on_the_clock(my_tick)
	elif _clock.is_known():
		now_tick = _clock.host_tick_now(my_tick)
		_keep_own_board_on_the_hosts_clock(now_tick)
		_keep_the_hosts_pace()
	var t0: int = Time.get_ticks_usec()
	for id: int in puppets:
		_show_puppet(id, now_tick)
	_us_show += Time.get_ticks_usec() - t0
	_ticks_costed += 1
	_check_command_line_timers()


## The host's water clock: ticks since the scene began. Every board the host sails reads its water
## at this time (a restart resets a board's own clock; the session's clock goes on).
func host_water_time_s(tick: int) -> float:
	return (tick - _start_tick) * _dt


func _keep_host_boards_on_the_clock(tick: int) -> void:
	var water_s: float = host_water_time_s(tick)
	own.sim.time_s = water_s
	if runner != null:
		for node: WindsurferNode in runner.opponents:
			node.sim.time_s = water_s


## The guest's board on the host's clocks: the water's time and the wind's (its gusts roll where the
## host's do), and on the lake the time of day.
func _keep_own_board_on_the_hosts_clock(host_tick: int) -> void:
	var clocks: Vector3 = _clock.clocks_at(host_tick, _dt)
	own.sim.time_s = clocks.x
	var wind: WindField = own.sim.wind
	wind.time_s = clocks.y
	wind.travel_m = clocks.z
	var map_field: MapWindField = wind as MapWindField
	var day_s: float = _clock.time_of_day_at(host_tick, _dt)
	if map_field != null and day_s >= 0.0:
		map_field.clock.set_time(day_s)


## A puppet at the moment it is shown (a few ticks behind the newest state). Writing a whole state
## costs about 0.2 ms, so it is written only when a newer state than the one the puppet holds is
## due (every tick for a player's board, every 2nd for an AI board's, every FAR_STATE_EVERY for
## one far away), and only the fields that changed; on the other ticks only the board's place and
## attitude move, between the two states around the moment. The rig and the sailor keep the last
## state's pose for that tick.
## The guest's game runs at the host's pace: a host that cannot keep up with real time (a big AI
## fleet on a slow PC: Session 69 measured 66 % with 19 AI boards and two games on one laptop) would
## otherwise fall further behind the guest every second, and the guest would show its boards later
## and later. The guest then runs fewer physics ticks a second, each still 1 / 60 s of game time:
## Engine.physics_ticks_per_second lower and Engine.time_scale lower by the same share (time_scale
## alone shortens each tick and keeps 60 a second). Everything of the guest's game slows alike, as if
## the host's world were in slow motion; on two PCs that keep up both stay as they are.
func _keep_the_hosts_pace() -> void:
	var normal: float = float(_normal_ticks)
	# The host's pace, and a little slower while this PC's count of the host's ticks is ahead of
	# what the host's messages say (it never counts back: NetClock.host_tick_now()).
	var catch_up: float = 0.01 * maxf(float(_clock.lead() - NetClock.STEADY_SLACK), 0.0)
	var wanted: float = clampf(_clock.host_ticks_per_second(normal) / normal - catch_up, PACE_MIN, 1.0)
	_pace = lerpf(_pace, wanted, PACE_FOLLOW)
	var ticks: int = clampi(roundi(normal * _pace), roundi(normal * PACE_MIN), _normal_ticks)
	if ticks != Engine.physics_ticks_per_second:
		Engine.physics_ticks_per_second = ticks
		Engine.time_scale = float(ticks) / normal


## The game's own pace again (the session ends, or this node leaves the scene).
func restore_pace() -> void:
	Engine.physics_ticks_per_second = _normal_ticks
	Engine.time_scale = 1.0


func _show_puppet(id: int, now_tick: int) -> void:
	var buffer: StateBuffer = _buffers[id]
	if buffer.is_empty():
		return
	var delay: float = AI_SHOW_DELAY_TICKS if id >= AI_ID_BASE else PLAYER_SHOW_DELAY_TICKS
	var show_tick: float = float(now_tick) - delay
	var node: WindsurferNode = puppets[id]
	var camera: Camera3D = get_viewport().get_camera_3d()
	var far: bool = camera != null and node.global_position.distance_to(camera.global_position) > RaceRunner.FAR_DETAIL_M
	node.set_far_away(far)
	var newest_due: int = buffer.tick_at_or_before(show_tick)
	if newest_due < 0:
		newest_due = buffer.newest_tick() if show_tick > float(buffer.newest_tick()) else -1
	var last: int = _applied_tick.get(id, -1)
	var whole: bool = newest_due > last and (not far or last < 0 or newest_due - last >= FAR_STATE_EVERY)
	if whole:
		var state: BoardSnapshot = buffer.state_of(newest_due)
		state.apply(node.sim, _applied.get(id, null))
		_applied[id] = state
		_applied_tick[id] = newest_due
		if _track_every > 0 and newest_due % _track_every < AI_SEND_EVERY:
			print("SEEN %d %d %s" % [newest_due, id, _track_text(node)])
	# The board's place and attitude at the moment shown (the state's own at a state's tick).
	var body: Transform3D = buffer.body_at(show_tick)
	node.sim.body.position = body.origin
	node.sim.body.basis = body.basis
	# The age of the whole state it holds (its telemetry, which the race reads): the race moves the
	# board on by its speed for that long (RaceRunner.where_now()).
	node.state_age_s = maxf(float(now_tick - _applied_tick.get(id, now_tick)), 0.0) * _dt
	node.after_step(whole)
	if not _shown.has(id) and _applied.has(id):
		_shown[id] = true
		node.visible = true
		node.reset_physics_interpolation()


# ---------------------------------------------------------------- step 3: the states out

## This PC's boards' states, the host's clock and the race (the Sender, after the physics).
func send_states() -> void:
	var t0: int = Time.get_ticks_usec()
	_send_states_now()
	_us_send += Time.get_ticks_usec() - t0


func _send_states_now() -> void:
	var my_tick: int = Engine.get_physics_frames()
	if Lan.is_host():
		if _ready_peers.is_empty():
			return
		_send_clock(my_tick)
		_send_board(Lan.my_slot, own, my_tick)
		if _track_every > 0 and my_tick % _track_every == 0 and runner != null:
			# Where the judge has the other players now (the sync check compares it with their own PCs').
			for slot: int in remote_slots():
				if not _applied.has(slot):
					continue  # no state of theirs yet
				var judged: Vector2 = RaceRunner.where_now(puppets[slot])
				print("JUDGED %d %d %.4f %.4f" % [my_tick, slot, judged.x, judged.y])
		if runner != null:
			for i: int in runner.opponents.size():
				if (my_tick + i) % AI_SEND_EVERY == 0:
					_send_board(AI_ID_BASE + i, runner.opponents[i], my_tick)
			if my_tick % RACE_STATE_EVERY == 0 and runner.race != null:
				Lan.send_race_state(runner.race.to_state(), runner.rules.to_state() if runner.rules != null else {})
	elif _clock.is_known():
		# The guest's states carry the host's tick they belong to.
		_send_board(Lan.my_slot, own, _clock.host_tick_now(my_tick))


## The clock at the start of this tick's step: the water's time the boards used and the wind's
## clock before it stepped (the next tick's start, less one tick).
func _send_clock(tick: int) -> void:
	var wind: WindField = own.sim.wind
	var map_field: MapWindField = wind as MapWindField
	var day_s: float = map_field.time_of_day_s() if map_field != null else -1.0
	Lan.send_clock(tick + 1, host_water_time_s(tick + 1), wind.time_s, wind.travel_m, day_s, Time.get_ticks_usec() / 1e6)


func _send_board(id: int, node: WindsurferNode, tick: int) -> void:
	if _track_every > 0 and tick % _track_every < AI_SEND_EVERY:
		print("TRACK %d %d %s" % [tick, id, _track_text(node)])
	if not _keyframes_out.has(id):
		return  # its keyframe goes out first (to a guest when its scene is ready)
	var t0: int = Time.get_ticks_usec()
	var bytes: PackedByteArray = BoardSnapshot.capture(node.sim).encode_diff(_keyframes_out[id])
	var t1: int = Time.get_ticks_usec()
	_bytes_out += bytes.size()
	Lan.send_state(tick, id, bytes)
	_us_capture += t1 - t0
	_us_rpc += Time.get_ticks_usec() - t1


## A board's keyframe (made once; a later guest gets the same one) to a peer.
func _send_keyframe(id: int, node: WindsurferNode, peer: int) -> void:
	if not _keyframes_out.has(id):
		_keyframes_out[id] = BoardSnapshot.capture(node.sim)
	var bytes: PackedByteArray = _keyframes_out[id].encode_full()
	_bytes_out += bytes.size()
	Lan.send_keyframe(id, bytes, peer)


func _send_own_keyframe(peer: int) -> void:
	_send_keyframe(Lan.my_slot, own, peer)


# ---------------------------------------------------------------- the messages in (from LanSession)

func on_keyframe(sender: int, id: int, bytes: PackedByteArray) -> void:
	if not _may_send(sender, id):
		return
	var state: BoardSnapshot = BoardSnapshot.decode_full(bytes)
	if state == null:
		return
	_bytes_in += bytes.size()
	_keyframes_in[id] = state


## A part of a board's state (LanSession.send_state()): kept until all its parts are here, then the
## state is read. Parts of a tick that never completes are dropped after a second.
func on_state_part(sender: int, tick: int, id: int, part: int, parts: int, bytes: PackedByteArray) -> void:
	if parts <= 1:
		on_state(sender, tick, id, bytes)
		return
	var key: Vector2i = Vector2i(id, tick)
	if not _parts.has(key):
		var empty: Array = []
		empty.resize(parts)
		_parts[key] = empty
	var held: Array = _parts[key]
	if part < 0 or part >= held.size():
		return
	held[part] = bytes
	if held.has(null):
		if _parts.size() > 64:
			_drop_old_parts(tick)
		return
	_parts.erase(key)
	var whole: PackedByteArray = PackedByteArray()
	for piece: Variant in held:
		whole.append_array(piece as PackedByteArray)
	on_state(sender, tick, id, whole)


func _drop_old_parts(tick: int) -> void:
	for key: Vector2i in _parts.keys():
		if key.y < tick - 60:
			_parts.erase(key)


func on_state(sender: int, tick: int, id: int, bytes: PackedByteArray) -> void:
	if not _keyframes_in.has(id) or not _buffers.has(id) or not _may_send(sender, id):
		return
	var t0: int = Time.get_ticks_usec()
	var state: BoardSnapshot = BoardSnapshot.decode_diff(bytes, _keyframes_in[id])
	_us_read += Time.get_ticks_usec() - t0
	if state == null:
		return
	_bytes_in += bytes.size()
	_states_in += 1
	if tick < _buffers[id].newest_tick():
		_states_late += 1
	_buffers[id].add(tick, state)


## A board's states come from the PC that sails it: a guest sends only its own; the host the rest.
func _may_send(sender: int, id: int) -> bool:
	if Lan.is_host():
		return _owners.get(id, -1) == sender
	return sender == 1


func on_clock(tick: int, water_s: float, wind_s: float, travel_m: float, day_s: float, host_real_s: float) -> void:
	_clock.receive(tick, Engine.get_physics_frames(), water_s, wind_s, travel_m, day_s, host_real_s)


## A guest's scene is loaded (the host): it gets the AI fleet, every board's keyframe and a new
## start of the race, so everyone starts the countdown together.
func on_scene_ready(peer: int) -> void:
	if not Lan.is_host():
		return
	if not _ready_peers.has(peer):
		_ready_peers.append(peer)
	if runner != null:
		Lan.send_fleet(_fleet_description(), peer)
		for i: int in runner.opponents.size():
			_send_keyframe(AI_ID_BASE + i, runner.opponents[i], peer)
	_send_own_keyframe(peer)
	if runner != null:
		runner.restart()


## Who sails the AI boards, for the guest's puppets: name, sail colour and gear.
func _fleet_description() -> Array:
	var fleet: Array = []
	for i: int in runner.opponents.size():
		var node: WindsurferNode = runner.opponents[i]
		var gear: GearChoice = node.gear if node.gear != null else GearChoice.defaults()
		var colour: Color = node.skipper.sail_colour() if node.skipper != null else Color.WHITE
		fleet.append({"id": AI_ID_BASE + i, "name": node.skipper.board_name() if node.skipper != null else node.name,
			"colour": colour, "board": gear.board.id(), "sail": gear.sail.id(), "fin": gear.fin.id()})
	return fleet


## The host's AI fleet (the guest): a puppet for each board.
func on_fleet(fleet: Array) -> void:
	for entry: Variant in fleet:
		var data: Dictionary = entry
		var id: int = int(data["id"])
		if puppets.has(id):
			continue
		var gear: GearChoice = GearChoice.from_ids(String(data["board"]), String(data["sail"]), String(data["fin"]))
		var puppet: WindsurferNode = _make_puppet(id, gear, String(data["name"]), data["colour"] as Color, false)
		puppet.visible = false
		_owners[id] = 1


## The host's race starts again (on the host, from its RaceRunner): where each player waits.
func _on_runner_restarted() -> void:
	_put_robot_on_board(runner.race, 0, runner.rules, runner.sailing_area())
	if _ready_peers.is_empty():
		return
	Lan.send_race_restart(restart_info())


## The host's start for the guests: the race's boards in its order (names and network numbers),
## where each player waits and heads, and the race's numbers.
func restart_info() -> Dictionary:
	var names: PackedStringArray = PackedStringArray()
	for i: int in runner.race.board_count():
		names.append(runner.race.board_name(i))
	names[0] = Lan.my_name
	var ids: Array = [Lan.my_slot]
	var spots: Dictionary = {Lan.my_slot: runner.player_spot}
	var slots: Array[int] = remote_slots()
	for i: int in slots.size():
		ids.append(slots[i])
		spots[slots[i]] = runner.remote_spots[i]
	for i: int in runner.opponents.size():
		ids.append(AI_ID_BASE + i)
	return {"names": names, "ids": ids, "spots": spots, "heading_deg": runner.start_heading_deg, "laps": runner.setup.laps,
		"prestart_s": runner.setup.prestart_s, "time_limit_s": runner.race.time_limit_s, "rules": runner.rules != null}


## The host's race starts again (on the guest): this PC's board to its spot, the mirror anew.
func on_race_restart(info: Dictionary) -> void:
	var spots: Dictionary = info.get("spots", {})
	if spots.has(Lan.my_slot):
		var spot: Vector2 = spots[Lan.my_slot]
		own.start_position = Vector3(spot.x, 0.0, spot.y)
		own.start_heading_deg = float(info.get("heading_deg", own.start_heading_deg))
		own.reset()
	if mirror != null:
		mirror.restart(info)
		_put_robot_on_board(mirror.race, mirror.my_index(), mirror.rules, SailingArea.for_course(mirror.course, scene.shore_grid))


func on_race_state(race_state: Dictionary, rules_state: Dictionary) -> void:
	if mirror != null:
		mirror.take_state(race_state, rules_state)


## The other player left (the host): their board stays where it was, without its name, and the
## HUD says so for a while.
func on_peer_left(peer: int) -> void:
	for id: int in _owners:
		if _owners[id] == peer and puppets.has(id):
			puppets[id].set_name_label("(left)")
			_buffers[id] = StateBuffer.new()
	_ready_peers.erase(peer)
	var who: String = "The other player"
	for player: LanPlayer in Lan.game.players:
		if player.peer_id == peer:
			who = player.name
	scene.show_net_message("%s has left the game." % who, LEFT_MESSAGE_S)


# ---------------------------------------------------------------- reports and tests

func _check_command_line_timers() -> void:
	if _report_every_s > 0.0 and _clock_s >= _report_at_s:
		_report_at_s = _clock_s + _report_every_s
		print(report_line())
	_print_results_once()
	if _quit_at_s > 0.0 and _clock_s >= _quit_at_s:
		_quit_at_s = -1.0
		print(report_line())
		print("LAN: quitting after %.0f s" % _clock_s)
		Lan.leave()
		get_tree().quit()


## One line: the tick, this PC's board and every puppet (place, heading, speed), the traffic.
func report_line() -> String:
	var my_tick: int = Engine.get_physics_frames()
	var host_tick: int = my_tick if Lan.is_host() else _clock.host_tick_now(my_tick)
	var parts: PackedStringArray = PackedStringArray()
	parts.append("LAN %s t=%.1f real=%.1f speed=%.2f host_tick=%d water=%.2f" % ["host" if Lan.is_host() else "guest", _clock_s,
		(Time.get_ticks_msec() - _real_start_ms) / 1000.0, Engine.time_scale, host_tick, own.sim.time_s])
	var robot_note: String = (" robot: %s" % str(own.skipper.get("note"))) if own.skipper != null and "note" in own.skipper else ""
	parts.append("me[%d] %s%s" % [Lan.my_slot, _board_text(own), robot_note])
	var ids: Array[int] = puppets.keys()
	ids.sort()
	for id: int in ids:
		parts.append("p[%d] %s age=%.0fms buf=%d" % [id, _board_text(puppets[id]), puppets[id].state_age_s * 1000.0, _buffers[id].size()])
	var seconds: float = maxf(_report_every_s, 1.0)
	parts.append("out=%.1fkB/s in=%.1fkB/s states_in=%d late=%d" % [_bytes_out / 1000.0 / seconds, _bytes_in / 1000.0 / seconds, _states_in, _states_late])
	var ticks: float = maxf(float(_ticks_costed), 1.0)
	parts.append("net ms/tick: show %.2f read %.2f send %.2f (capture %.2f, rpc %.2f)" % [_us_show / ticks / 1000.0, _us_read / ticks / 1000.0,
		_us_send / ticks / 1000.0, _us_capture / ticks / 1000.0, _us_rpc / ticks / 1000.0])
	_us_capture = 0
	_us_rpc = 0
	_us_show = 0
	_us_read = 0
	_us_send = 0
	_ticks_costed = 0
	_bytes_out = 0
	_bytes_in = 0
	_states_in = 0
	_states_late = 0
	var race: RaceSim = runner.race if runner != null else (mirror.race if mirror != null else null)
	if race != null:
		# Each board's next step, * when over the line early, +n its penalties.
		var steps: PackedStringArray = PackedStringArray()
		var rules: RaceRules = runner.rules if runner != null else mirror.rules
		for i: int in race.board_count():
			var penalties: int = rules.penalties(i) if rules != null else 0
			steps.append("%d%s%s" % [race.next_step_index(i), "*" if race.is_ocs(i) else "", ("+%d" % penalties) if penalties > 0 else ""])
		parts.append("race %s clock=%.1f steps=%s" % [RaceSim.Phase.keys()[race.phase()], race.clock_s(), ",".join(steps)])
	return " | ".join(parts)


## The sync check's numbers of a board: its place, heading, speed, the mast's direction (the rig)
## and the sailor's lean (the body), to four decimals; then the board's heel and pitch, the rail and
## the trim the sailor's feet aim for (Telemetry.wanted_bank_deg, trim_aim_deg), and how the feet
## press (Telemetry.toes_share, back_foot_share), which carry the body on the mouse (package B, GP2:
## the feet's press) when the player sails with it.
static func _track_text(node: WindsurferNode) -> String:
	var t: Telemetry = node.sim.telemetry
	var mast: Vector3 = node.sim.sail.mast_direction()
	return "%.4f %.4f %.4f %.4f %.4f %.4f %.4f %.4f %d %.4f %.4f %.4f %.4f %.4f %.4f" % [t.position.x, t.position.y, t.position.z, t.heading_deg, t.speed_ms,
		mast.x, mast.z, node.sim.lean, node.sim.sailor_state, t.heel_deg, t.pitch_deg, t.wanted_bank_deg, t.trim_aim_deg,
		t.toes_share, t.back_foot_share]


## Once the race is over (--lan_report or --lan_track): every board's place, name, finish and
## penalty, as this PC has the race (the host its own, the guest its mirror).
func _print_results_once() -> void:
	if _results_printed or (_report_every_s <= 0.0 and _track_every <= 0):
		return
	var race: RaceSim = runner.race if runner != null else (mirror.race if mirror != null else null)
	if race == null or race.phase() != RaceSim.Phase.FINISHED:
		return
	_results_printed = true
	for result: RaceResult in race.results():
		var who: String = Lan.my_name if result.name == RaceRunner.PLAYER_NAME else result.name
		print("RESULT %d %s %s %.2f %.1f %d/%d" % [result.place, who.replace(" ", "_"), "finished" if result.finished else "dnf",
			result.finish_time_s, result.penalty_s, result.steps_done, result.steps_total])


## --lan_robot: a scripted skipper on this PC's board for the race just started (again at every
## start: the race is new). Its hands sail the board through the controller, as the AI's do.
func _put_robot_on_board(race: RaceSim, index: int, rules: RaceRules, area: SailingArea) -> void:
	if _robot_name == "" or race == null or index < 0:
		return
	var robot: RaceSkipper = Skippers.make(_robot_name)
	if robot == null:
		return
	own.hands = AiHands.new()
	own.controller.hands = own.hands
	own.skipper = robot
	robot.random_seed = 7 + Lan.my_slot
	robot.sailing_area = area
	robot.rules = rules
	robot.setup(own.sim, own.controller, own.hands, race, index)


static func _board_text(node: WindsurferNode) -> String:
	var t: Telemetry = node.sim.telemetry
	return "(%.2f, %.2f) hdg %.1f %.2f m/s %s" % [t.position.x, t.position.z, t.heading_deg, t.speed_ms,
		"fallen" if node.sim.sailor_state == WindsurferSim.SailorState.FALLEN else "sailing"]
