class_name LanSession
extends Node
## LAN multiplayer's connection (the autoload "Lan"; Documentation/reports/multiplayer/PLAN.md). One
## PC hosts, the other joins. The host is the admin: it picks the map, free sailing or a race, the
## wind and the waves and the AI fleet (LanGame); the guest picks its own name and gear and says it
## is ready; the host presses Start and both PCs load the same scene. In the scene, NetBoards
## (net_boards.gd) sends and shows the boards; its messages travel through this node, which is at the
## same place (/root/Lan) on both PCs, as Godot's remote calls need.
##
## The pieces:
## - the connection: Godot's ENet (UDP), port GAME_PORT on the host (D1);
## - the lobby: the players (LanPlayer) and the game (LanGame), sent to the guest whenever they change;
## - finding a game: the host calls out on the LAN once a second (DISCOVERY_PORT), the Join page
##   listens (D9); an address can be typed too;
## - the check at the door: the same protocol, game version and board-state layout (BoardSnapshot), or
##   the guest is told why not;
## - the guest's settings: the host's wind and waves are sailed for the session only, the guest's
##   own come back when it ends, and nothing is saved meanwhile (D11).
##
## Command-line options for tests and for starting a game without the menus (after "--"):
##   --lan_host=<name>            host at once, under that name
##   --lan_join=<address>         join that host at once (--lan_name=<name>)
##   --lan_mode=race|free         the host's game (race by default)
##   --lan_map=open|lake          the host's map (open by default)
##   --lan_skippers=a,b|none      the host's AI fleet (the race page's default three without it)
##   --lan_prestart=<s>           the host's countdown
##   --lan_start=<s>              the host starts this long after a guest is ready (with --lan_host)
## And in the game (NetBoards): --lan_report=<s> prints every board's place that often, --lan_quit=<s>
## leaves and quits after that long.

## Something changed in the lobby (a player came, went, changed gear or got ready; the game).
signal lobby_changed
## The list of games heard on the LAN changed.
signal found_games_changed
## The game starts: the scene is being loaded.
signal game_started
## The session ended (the host left, the guest was refused, the connection failed): why, in words.
signal ended(reason: String)

const GAME_PORT: int = 47520
const DISCOVERY_PORT: int = 47521
const MAX_PLAYERS: int = 2
## Raised when the messages change, so two different builds refuse each other politely.
const PROTOCOL: int = 1
## The channels: 0 the lobby and the reliable game messages, 1 the boards' states (unreliable), 2
## the race's state (reliable, apart so it never waits behind the lobby).
const CHANNELS: int = 3
const BEACON_EVERY_S: float = 1.0
## A board's state is about 1.5 kB, a little more than one UDP packet holds on most networks (the
## MTU, about 1400 bytes): it goes in parts of at most this many bytes, joined again on arrival
## (NetBoards), so no packet is split by the network (a lost piece would lose the whole).
const STATE_PART_BYTES: int = 1100
## A game not heard for this long leaves the Join page's list.
const FORGET_AFTER_S: float = 4.0
const START_MENU_SCENE: String = "res://ui/start_menu.tscn"

enum Role { NONE, HOST, GUEST }

var role: Role = Role.NONE
## Everyone in the game, the host first (slot order).
var players: Array[LanPlayer] = []
## The game the host chose (on the guest: as the host sent it).
var game: LanGame = LanGame.new()
## True from the start message until the session ends: the scene is a network game.
var in_game: bool = false
## This PC's player's name and slot (0 the host, 1 the guest; -1 before a guest is welcomed).
var my_name: String = "Player"
var my_slot: int = -1
## The games heard on the LAN: the host's address -> {name, players, version, mode, heard_s}.
var found_games: Dictionary[String, Dictionary] = {}
## Why the last session ended or could not start ("" when nothing went wrong).
var last_error: String = ""
## The scene's NetBoards while a game runs: it gets the game's messages (see _deliver()).
var net_handler: Object = null

var _peer: ENetMultiplayerPeer = null
var _beacon: PacketPeerUDP = null
var _beacon_in_s: float = 0.0
var _listener: PacketPeerUDP = null
## The guest's own settings while it sails the host's conditions (D11), and its settings file's path.
var _own_settings: ConfigFile = null
var _own_settings_path: String = ""
## Reliable game messages that came before the scene's NetBoards was there: delivered when it comes.
var _waiting_messages: Array[Array] = []
## --lan_start: seconds after a guest is ready until the host starts (-1: not from the command line).
var _auto_start_after_s: float = -1.0
var _auto_start_in_s: float = -1.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	_start_from_command_line.call_deferred()


func _process(delta: float) -> void:
	if _beacon != null:
		_beacon_in_s -= delta
		if _beacon_in_s <= 0.0:
			_beacon_in_s = BEACON_EVERY_S
			_send_beacon()
	if _listener != null:
		_listen()
	if _auto_start_in_s >= 0.0:
		_auto_start_in_s -= delta
		if _auto_start_in_s < 0.0 and can_start():
			host_start()


# ---------------------------------------------------------------- who we are

func is_active() -> bool:
	return role != Role.NONE


func is_host() -> bool:
	return role == Role.HOST


func is_guest() -> bool:
	return role == Role.GUEST


## The player in a slot, or null.
func player_in(slot: int) -> LanPlayer:
	for player: LanPlayer in players:
		if player.slot == slot:
			return player
	return null


## The game's version, as the start menu shows it.
static func game_version() -> String:
	return str(ProjectSettings.get_setting("application/config/version", ""))


## This PC's addresses on the LAN (IPv4, not the loopback), for the host's page: what the guest
## types when the game does not show up on its list.
static func local_addresses() -> PackedStringArray:
	var list: PackedStringArray = PackedStringArray()
	for address: String in IP.get_local_addresses():
		if address.count(".") == 3 and not address.begins_with("127.") and not address.begins_with("169.254."):
			list.append(address)
	return list


# ---------------------------------------------------------------- hosting and joining

## Hosts a game under this name: the lobby opens with this PC's player in it, and the game is called
## out on the LAN. Returns an error when the port is taken (another game hosting on this PC).
func host_game(player_name: String) -> Error:
	leave()
	_peer = ENetMultiplayerPeer.new()
	var error: Error = _peer.create_server(GAME_PORT, MAX_PLAYERS - 1, CHANNELS)
	if error != OK:
		_peer = null
		last_error = "Could not host on port %d (error %d). Is a game already hosting on this PC?" % [GAME_PORT, error]
		return error
	_peer.host.compress(ENetConnection.COMPRESS_RANGE_CODER)
	multiplayer.multiplayer_peer = _peer
	role = Role.HOST
	my_name = LanPlayer.clean_name(player_name)
	my_slot = 0
	last_error = ""
	players = [_me(0, 1)]
	game = LanGame.new()
	game.conditions_text = LanGame.conditions_of(GameSettings.values)
	_start_beacon()
	lobby_changed.emit()
	return OK


## Joins the game hosted at this address under this name. The answer comes later: lobby_changed
## once the host has welcomed this PC, or ended() with the reason it could not.
func join_game(address: String, player_name: String) -> Error:
	leave()
	_peer = ENetMultiplayerPeer.new()
	var error: Error = _peer.create_client(address.strip_edges(), GAME_PORT, CHANNELS)
	if error != OK:
		_peer = null
		last_error = "Could not reach %s (error %d)." % [address, error]
		return error
	_peer.host.compress(ENetConnection.COMPRESS_RANGE_CODER)
	multiplayer.multiplayer_peer = _peer
	role = Role.GUEST
	my_name = LanPlayer.clean_name(player_name)
	my_slot = -1
	last_error = ""
	players = []
	return OK


## Ends the session: the connection closes, the guest's own settings come back, the lists empty.
## Safe to call when there is none.
func leave() -> void:
	_stop_beacon()
	if _peer != null:
		_peer.close()
		_peer = null
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	_restore_own_settings()
	role = Role.NONE
	in_game = false
	players = []
	my_slot = -1
	net_handler = null
	_waiting_messages.clear()
	_auto_start_in_s = -1.0


## This PC's player for the lobby, from the settings' gear.
func _me(slot: int, peer_id: int) -> LanPlayer:
	var me: LanPlayer = LanPlayer.new()
	me.peer_id = peer_id
	me.slot = slot
	me.name = my_name
	me.gear_board = GameSettings.values.gear_board
	me.gear_sail = GameSettings.values.gear_sail
	me.gear_fin = GameSettings.values.gear_fin
	me.ready = slot == 0
	return me


func _on_connected_to_server() -> void:
	_hello.rpc_id(1, PROTOCOL, game_version(), BoardSnapshot.layout_hash(), my_name,
		[GameSettings.values.gear_board, GameSettings.values.gear_sail, GameSettings.values.gear_fin])


func _on_connection_failed() -> void:
	_end_with("Could not reach the host. Is the game hosting, and does the firewall allow it?")


func _on_server_disconnected() -> void:
	_end_with("The host has left the game.")


func _on_peer_connected(_id: int) -> void:
	pass  # the guest says hello first (_hello)


func _on_peer_disconnected(id: int) -> void:
	if not is_host():
		return
	for player: LanPlayer in players:
		if player.peer_id == id:
			players.erase(player)
			break
	_deliver("on_peer_left", [id], false)
	_send_lobby()
	lobby_changed.emit()


## The session is over: why, for the menus, and back to the start menu if a game was running.
func _end_with(reason: String) -> void:
	var was_in_game: bool = in_game
	last_error = reason
	leave()
	ended.emit(reason)
	if was_in_game:
		get_tree().paused = false
		get_tree().change_scene_to_file(START_MENU_SCENE)


# ---------------------------------------------------------------- the lobby

## The guest's hello (on the host): the check at the door, then a place in the game.
@rpc("any_peer", "call_remote", "reliable", 0)
func _hello(protocol: int, version: String, layout: int, player_name: String, gear: Array) -> void:
	if not is_host():
		return
	var sender: int = multiplayer.get_remote_sender_id()
	var refusal: String = ""
	if protocol != PROTOCOL or version != game_version():
		refusal = "The host runs version %s and this PC %s: both need the same version." % [game_version(), version]
	elif layout != BoardSnapshot.layout_hash():
		refusal = "The two PCs run different builds of version %s (the physics differ): both need the same build." % version
	elif in_game:
		refusal = "The game has already started."
	elif players.size() >= MAX_PLAYERS:
		refusal = "The game is full."
	if refusal != "":
		_refused.rpc_id(sender, refusal)
		return
	var guest: LanPlayer = LanPlayer.new()
	guest.peer_id = sender
	guest.slot = _free_slot()
	guest.name = LanPlayer.clean_name(player_name)
	if gear.size() == 3:
		guest.gear_board = String(gear[0])
		guest.gear_sail = String(gear[1])
		guest.gear_fin = String(gear[2])
	players.append(guest)
	players.sort_custom(func(a: LanPlayer, b: LanPlayer) -> bool: return a.slot < b.slot)
	_welcome.rpc_id(sender, guest.slot)
	_send_lobby()
	lobby_changed.emit()


func _free_slot() -> int:
	var slot: int = 0
	while player_in(slot) != null:
		slot += 1
	return slot


@rpc("authority", "call_remote", "reliable", 0)
func _welcome(slot: int) -> void:
	my_slot = slot


@rpc("authority", "call_remote", "reliable", 0)
func _refused(reason: String) -> void:
	_end_with(reason)


## The lobby to every guest (the host, whenever it changes).
func _send_lobby() -> void:
	if not is_host() or _peer == null:
		return
	var people: Array = []
	for player: LanPlayer in players:
		people.append(player.to_dict())
	_lobby.rpc(people, game.to_dict())


@rpc("authority", "call_remote", "reliable", 0)
func _lobby(people: Array, game_data: Dictionary) -> void:
	players = []
	for entry: Variant in people:
		if entry is Dictionary:
			players.append(LanPlayer.from_dict(entry))
	game = LanGame.from_dict(game_data)
	lobby_changed.emit()


## The guest's name, gear and readiness, to the host (the host's own change at once).
func update_me(ready: bool) -> void:
	var gear: Array = [GameSettings.values.gear_board, GameSettings.values.gear_sail, GameSettings.values.gear_fin]
	if is_host():
		var me: LanPlayer = player_in(0)
		if me != null:
			me.gear_board = String(gear[0])
			me.gear_sail = String(gear[1])
			me.gear_fin = String(gear[2])
		_send_lobby()
		lobby_changed.emit()
	elif is_guest() and _peer != null:
		_player_update.rpc_id(1, my_name, gear, ready)


@rpc("any_peer", "call_remote", "reliable", 0)
func _player_update(player_name: String, gear: Array, ready: bool) -> void:
	if not is_host():
		return
	var sender: int = multiplayer.get_remote_sender_id()
	for player: LanPlayer in players:
		if player.peer_id == sender:
			player.name = LanPlayer.clean_name(player_name)
			if gear.size() == 3:
				player.gear_board = String(gear[0])
				player.gear_sail = String(gear[1])
				player.gear_fin = String(gear[2])
			player.ready = ready
			if ready and _auto_start_after_s >= 0.0:
				_auto_start_in_s = _auto_start_after_s
	_send_lobby()
	lobby_changed.emit()


## The host's new choice of game (the lobby's controls): the guest sees it at once.
func host_set_game(choice: LanGame) -> void:
	if not is_host():
		return
	game = choice
	game.conditions_text = LanGame.conditions_of(GameSettings.values)
	_send_lobby()
	lobby_changed.emit()


## Whether the host may press Start: every guest is ready (a host alone may sail on its own too).
func can_start() -> bool:
	if not is_host() or in_game:
		return false
	for player: LanPlayer in players:
		if not player.ready:
			return false
	return true


## The host's Start: both PCs load the game's scene.
func host_start() -> void:
	if not can_start():
		return
	game.players = players.duplicate()
	game.conditions_text = LanGame.conditions_of(GameSettings.values)
	# call_local: the host loads the scene too.
	_start.rpc(game.to_dict())


@rpc("authority", "call_local", "reliable", 0)
func _start(game_data: Dictionary) -> void:
	game = LanGame.from_dict(game_data)
	in_game = true
	_waiting_messages.clear()
	if is_guest():
		_sail_the_hosts_conditions()
	RaceSetup.pending = game.race_setup()
	game_started.emit()
	get_tree().paused = false
	get_tree().change_scene_to_file(game.scene_path())


# ---------------------------------------------------------------- the guest's settings (D11)

## The guest sails the host's wind and waves for the session; its own are kept to come back, and its
## settings file is not written meanwhile.
func _sail_the_hosts_conditions() -> void:
	if _own_settings == null:
		_own_settings = ConfigFile.new()
		GameSettings.values.write_to(_own_settings)
		_own_settings_path = GameSettings.path
		GameSettings.path = ""  # nothing is saved while the host's conditions are in the settings
	game.apply_conditions(GameSettings.values)


func _restore_own_settings() -> void:
	if _own_settings == null:
		return
	GameSettings.values.read_from(_own_settings)
	GameSettings.path = _own_settings_path
	_own_settings = null


# ---------------------------------------------------------------- the game's messages (NetBoards)

## The scene's NetBoards takes the game's messages from now on (and those that came before it).
func register_handler(handler: Object) -> void:
	net_handler = handler
	var waiting: Array[Array] = _waiting_messages.duplicate()
	_waiting_messages.clear()
	for message: Array in waiting:
		net_handler.callv(message[0], message[1])


func unregister_handler(handler: Object) -> void:
	if net_handler == handler:
		net_handler = null


## A message to the scene's NetBoards: at once, or kept until it is there (reliable messages only;
## a board's state that comes too early is simply dropped).
func _deliver(method: String, arguments: Array, keep: bool = true) -> void:
	if net_handler != null:
		net_handler.callv(method, arguments)
	elif keep and in_game:
		_waiting_messages.append([method, arguments])


## The peers to send the game's messages to: from the host every guest, from a guest the host.
func send_keyframe(board_id: int, bytes: PackedByteArray, to_peer: int = 0) -> void:
	if to_peer != 0:
		_keyframe.rpc_id(to_peer, board_id, bytes)
	else:
		_keyframe.rpc(board_id, bytes)


@rpc("any_peer", "call_remote", "reliable", 0)
func _keyframe(board_id: int, bytes: PackedByteArray) -> void:
	_deliver("on_keyframe", [multiplayer.get_remote_sender_id(), board_id, bytes])


## A board's state for a tick, in parts of at most STATE_PART_BYTES.
func send_state(tick: int, board_id: int, bytes: PackedByteArray) -> void:
	var parts: int = maxi(ceili(bytes.size() / float(STATE_PART_BYTES)), 1)
	for part: int in parts:
		_state.rpc(tick, board_id, part, parts, bytes.slice(part * STATE_PART_BYTES, (part + 1) * STATE_PART_BYTES))


@rpc("any_peer", "call_remote", "unreliable", 1)
func _state(tick: int, board_id: int, part: int, parts: int, bytes: PackedByteArray) -> void:
	_deliver("on_state_part", [multiplayer.get_remote_sender_id(), tick, board_id, part, parts, bytes], false)


## The host's clock, every tick: its tick, the water's clock and the wind's (RaceWindClock).
func send_clock(tick: int, water_time_s: float, wind_time_s: float, wind_travel_m: float, time_of_day_s: float) -> void:
	_clock.rpc(tick, water_time_s, wind_time_s, wind_travel_m, time_of_day_s)


@rpc("authority", "call_remote", "unreliable", 1)
func _clock(tick: int, water_time_s: float, wind_time_s: float, wind_travel_m: float, time_of_day_s: float) -> void:
	_deliver("on_clock", [tick, water_time_s, wind_time_s, wind_travel_m, time_of_day_s], false)


## The guest's scene is loaded and its NetBoards is listening (to the host).
func send_scene_ready() -> void:
	if is_guest():
		_scene_ready.rpc_id(1)


@rpc("any_peer", "call_remote", "reliable", 0)
func _scene_ready() -> void:
	_deliver("on_scene_ready", [multiplayer.get_remote_sender_id()])


## The host's AI fleet (who sails which board and gear, D8), to one guest or all.
func send_fleet(fleet: Array, to_peer: int = 0) -> void:
	if to_peer != 0:
		_fleet.rpc_id(to_peer, fleet)
	else:
		_fleet.rpc(fleet)


@rpc("authority", "call_remote", "reliable", 0)
func _fleet(fleet: Array) -> void:
	_deliver("on_fleet", [fleet])


## A new start of the race (the host's restart): where each player waits, and the race's numbers.
func send_race_restart(info: Dictionary) -> void:
	_race_restart.rpc(info)


@rpc("authority", "call_remote", "reliable", 0)
func _race_restart(info: Dictionary) -> void:
	_deliver("on_race_restart", [info])


## The race and the judge as they stand (the host, ten times a second).
func send_race_state(race_state: Dictionary, rules_state: Dictionary) -> void:
	_race_state.rpc(race_state, rules_state)


@rpc("authority", "call_remote", "reliable", 2)
func _race_state(race_state: Dictionary, rules_state: Dictionary) -> void:
	_deliver("on_race_state", [race_state, rules_state], false)


# ---------------------------------------------------------------- finding a game on the LAN (D9)

func _start_beacon() -> void:
	_beacon = PacketPeerUDP.new()
	_beacon.set_broadcast_enabled(true)
	_beacon.bind(0)
	_beacon_in_s = 0.0


func _stop_beacon() -> void:
	if _beacon != null:
		_beacon.close()
		_beacon = null


## The host's call: who hosts, which version, how many play, whether the game has started. Sent to
## the whole LAN (255.255.255.255) and to each network's own broadcast address (a.b.c.255), because
## a PC with several networks sends the first on one of them only.
func _send_beacon() -> void:
	var text: String = JSON.stringify({"game": "windsurfing-mmzb", "protocol": PROTOCOL, "version": game_version(),
		"name": my_name, "players": players.size(), "max": MAX_PLAYERS, "started": in_game, "summary": game.summary()})
	var packet: PackedByteArray = text.to_utf8_buffer()
	var targets: PackedStringArray = PackedStringArray(["255.255.255.255", "127.0.0.1"])
	for address: String in local_addresses():
		var parts: PackedStringArray = address.split(".")
		targets.append("%s.%s.%s.255" % [parts[0], parts[1], parts[2]])
	for target: String in targets:
		_beacon.set_dest_address(target, DISCOVERY_PORT)
		_beacon.put_packet(packet)


## The Join page listens for hosts while it is open.
func start_listening() -> Error:
	stop_listening()
	_listener = PacketPeerUDP.new()
	var error: Error = _listener.bind(DISCOVERY_PORT)
	if error != OK:
		_listener = null
		last_error = "Could not listen for games on port %d (error %d); type the host's address instead." % [DISCOVERY_PORT, error]
	return error


func stop_listening() -> void:
	if _listener != null:
		_listener.close()
		_listener = null
	found_games.clear()


func _listen() -> void:
	var changed: bool = false
	var now_s: float = Time.get_ticks_msec() / 1000.0
	while _listener.get_available_packet_count() > 0:
		var packet: PackedByteArray = _listener.get_packet()
		var address: String = _listener.get_packet_ip()
		var data: Variant = JSON.parse_string(packet.get_string_from_utf8())
		if not (data is Dictionary) or (data as Dictionary).get("game", "") != "windsurfing-mmzb":
			continue
		var entry: Dictionary = data
		entry["heard_s"] = now_s
		changed = changed or not found_games.has(address)
		found_games[address] = entry
	# A host on this PC is heard twice, on its LAN address and on the loopback: the LAN one is kept.
	if found_games.has("127.0.0.1"):
		for address: String in found_games.keys():
			if address != "127.0.0.1" and found_games[address].get("name") == found_games["127.0.0.1"].get("name"):
				found_games.erase("127.0.0.1")
				changed = true
				break
	for address: String in found_games.keys():
		if now_s - float(found_games[address]["heard_s"]) > FORGET_AFTER_S:
			found_games.erase(address)
			changed = true
	if changed:
		found_games_changed.emit()


# ---------------------------------------------------------------- the command line

## --lan_host / --lan_join: a game without the menus (see the note at the top).
func _start_from_command_line() -> void:
	var options: Dictionary[String, String] = command_line_options()
	if options.has("lan_host"):
		if host_game(options["lan_host"]) != OK:
			push_error(last_error)
			return
		var choice: LanGame = LanGame.new()
		choice.race = options.get("lan_mode", "race") != "free"
		choice.map = LanGame.Map.LAKE if options.get("lan_map", "open") == "lake" else LanGame.Map.OPEN_WATER
		choice.course_name = choice.courses()[0]
		if options.has("lan_skippers"):
			choice.skippers = PackedStringArray() if options["lan_skippers"] == "none" else options["lan_skippers"].split(",")
		if options.has("lan_prestart"):
			choice.prestart_s = maxf(options["lan_prestart"].to_float(), 5.0)
		host_set_game(choice)
		_auto_start_after_s = maxf(options.get("lan_start", "1").to_float(), 0.0)
		print("LAN: hosting as %s on %s, port %d: %s" % [my_name, ", ".join(local_addresses()), GAME_PORT, game.summary()])
	elif options.has("lan_join"):
		if join_game(options["lan_join"], options.get("lan_name", "Guest")) != OK:
			push_error(last_error)
			return
		lobby_changed.connect(_ready_from_command_line, CONNECT_ONE_SHOT)
		print("LAN: joining %s as %s" % [options["lan_join"], my_name])


func _ready_from_command_line() -> void:
	update_me(true)


## The command line's --name=value options after "--".
static func command_line_options() -> Dictionary[String, String]:
	var options: Dictionary[String, String] = {}
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--") and arg.contains("="):
			var parts: PackedStringArray = arg.trim_prefix("--").split("=", true, 1)
			options[parts[0]] = parts[1]
	return options
