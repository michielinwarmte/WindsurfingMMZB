class_name Spot
extends Resource
## One sailing spot (backlog E04.S01, the spot list; first used for Fuerteventura, Sotavento,
## E04.S12): everything the game needs to put a player on its water, in one resource, so a new spot
## is a folder with its files and this, not new code. A spot built from a height grid
## (tools/map/spot_build.py) sails with SpotSailing (spot_sailing.gd). Lake Silvaplana and the open
## water join the list later (E04.S01 T2), without changing how they sail.

## A short name for files and the command line ("sotavento").
@export var id: String = ""
## The name the menus show.
@export var display_name: String = ""
## The sailing scene.
@export_file("*.tscn") var sail_scene: String = ""
## Where the spot sits in the game (its frame's metres east and north of the game's origin).
@export var map_config: MapConfig = null
## The air, the water, the wind's height profile, the waves and the depth grid (EnvironmentConfig).
@export_file("*.tres") var environment_path: String = ""

@export_group("Start")
## The start spot in the spot's frame (metres east and north), on the water.
@export var start_east_m: float = 0.0
@export var start_north_m: float = 0.0
## The heading the board starts on, degrees (a beam reach out to the open water).
@export var start_heading_deg: float = 90.0

@export_group("Conditions")
## The direction the spot's usual wind comes from, degrees: the settings' wind blows from here (its
## strength, gusts and shifts are the player's).
@export var wind_from_deg: float = 270.0
## The session's water level above the depth grid's zero, m (the tide; a lake: 0).
@export var water_level_m: float = 0.0
## The local time the session starts at, hours (the sun stays where its scene puts it).
@export var start_hour: float = 15.0

@export_group("Credits")
## The open data's sources and licences, for the credits page.
@export_multiline var credits: String = ""


## The start spot as a game position on the water.
func start_position() -> Vector3:
	var at: Vector3 = map_config.lv95_to_game(start_east_m, start_north_m, map_config.lake_level_m)
	return Vector3(at.x, 0.0, at.z)
