class_name LanPlayer
extends RefCounted
## One person in a LAN game (LAN multiplayer, Documentation/reports/multiplayer/PLAN.md, D2): their
## connection, their place in the game (slot 0 is the host), their name, the gear they sail and
## whether they are ready. Plain data, sent in the lobby and in the game's start message.

## The connection's number (Godot's peer id): 1 is always the host.
var peer_id: int = 1
## The place in the game: 0 the host, 1 the guest. Also the board's number on the network.
var slot: int = 0
var name: String = "Player"
var gear_board: String = ""
var gear_sail: String = ""
var gear_fin: String = ""
var ready: bool = false


## The player's gear as the game sails and shows it (an unknown id sails that kind's default).
func gear() -> GearChoice:
	return GearChoice.from_ids(gear_board, gear_sail, gear_fin)


## The gear's names in one short line, for the lobby.
func gear_text() -> String:
	var choice: GearChoice = gear()
	return "%s · %s" % [choice.board.full_name(), choice.sail.full_name()]


func to_dict() -> Dictionary:
	return {"peer": peer_id, "slot": slot, "name": name, "board": gear_board, "sail": gear_sail, "fin": gear_fin, "ready": ready}


static func from_dict(data: Dictionary) -> LanPlayer:
	var player: LanPlayer = LanPlayer.new()
	player.peer_id = int(data.get("peer", 1))
	player.slot = int(data.get("slot", 0))
	player.name = clean_name(String(data.get("name", "Player")))
	player.gear_board = String(data.get("board", ""))
	player.gear_sail = String(data.get("sail", ""))
	player.gear_fin = String(data.get("fin", ""))
	player.ready = bool(data.get("ready", false))
	return player


## A name fit for the screen: no line breaks, at most 16 characters, "Player" when empty.
static func clean_name(text: String) -> String:
	var cleaned: String = text.replace("\n", " ").replace("\t", " ").strip_edges().left(16)
	return cleaned if cleaned != "" else "Player"
