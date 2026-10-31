class_name GearChoice
extends RefCounted
## The gear one board sails: a board, a sail and a fin from the catalogue (GearCatalogue). The
## sailing scene (main.gd) makes one from the player's settings and hands it to the player's
## WindsurferNode, which sails it (sim_with()) and shows it (RigVisuals.build()). The AI fleet
## keeps the default gear (ROADMAP.md, RA8).

var board: GearItem
var sail: GearItem
var fin: GearItem


## The default gear: what the game sailed before the gear page.
static func defaults() -> GearChoice:
	return from_ids(GearCatalogue.DEFAULT_BOARD_ID, GearCatalogue.DEFAULT_SAIL_ID, GearCatalogue.DEFAULT_FIN_ID)


## The gear with these ids; an unknown id (or one of the wrong kind) gives that kind's default.
static func from_ids(board_id: String, sail_id: String, fin_id: String) -> GearChoice:
	var choice: GearChoice = GearChoice.new()
	choice.board = GearCatalogue.find_or_default(board_id, GearItem.Kind.BOARD)
	choice.sail = GearCatalogue.find_or_default(sail_id, GearItem.Kind.SAIL)
	choice.fin = GearCatalogue.find_or_default(fin_id, GearItem.Kind.FIN)
	return choice


## The gear the player's settings choose (section "gear" of the settings file).
static func from_settings(settings: SettingsValues) -> GearChoice:
	return from_ids(settings.gear_board, settings.gear_sail, settings.gear_fin)


## The item of one kind.
func item(kind: GearItem.Kind) -> GearItem:
	match kind:
		GearItem.Kind.SAIL:
			return sail
		GearItem.Kind.FIN:
			return fin
	return board


## "board, sail, fin" ids in one text, to tell whether the choice changed.
func ids_text() -> String:
	return "%s, %s, %s" % [board.id(), sail.id(), fin.id()]


## The gear's names in one line, for the F1 panel and the gear page:
## "PJ New Sealand Selkie 117 L · Savanna Cheetah 8.0 m² · PJ New Sealand Whisker 38 cm".
func names_line() -> String:
	return "%s  ·  %s  ·  %s" % [board.full_name(), sail.full_name(), fin.full_name()]


## Copies of the three items' numbers for one simulation.
func board_config() -> BoardConfig:
	return board.config_copy() as BoardConfig


func sail_config() -> SailConfig:
	return sail.config_copy() as SailConfig


func fin_config() -> FinConfig:
	return fin.config_copy() as FinConfig


## A simulation like `base` (the place, the air, the water, the wind, the waves and the sailor,
## as WindsurferSim.create_for() made them) on this gear: a new WindsurferSim from copies of the
## chosen board's, sail's and fin's numbers and `base`'s own other configs. The wind field is
## `base`'s own (the map's wind on the lake), and the board is put at the origin as create_for()
## leaves it; the caller puts it at its start. Nothing in Game/sim/ changes: the physics is built
## from the configs it is handed, as for every other board.
func sim_with(base: WindsurferSim) -> WindsurferSim:
	var sim: WindsurferSim = WindsurferSim.new(board_config(), sail_config(), fin_config(), base.sailor_config,
		base.water_config, base.wind_config, base.sim_config, base.wave_set_config)
	sim.air_density_kg_m3 = base.air_density_kg_m3
	sim.wind = base.wind
	# Again, so the sail's side and the telemetry come from that wind (as create_for() does).
	sim.reset(Vector3.ZERO, 0.0)
	sim.set_waves(base.has_waves())
	return sim
