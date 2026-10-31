class_name GearItem
extends Resource
## One piece of gear the player can choose on the gear page (ui/gear_page.gd): a board, a sail or a
## fin of one of the game's brands (Brand), with the numbers the simulation sails it with and,
## for the 3D rig, its own model and pictures when it has them.
##
## One .tres per item, in Game/gear/boards/, Game/gear/sails/ or Game/gear/fins/, named after its
## id(): "<brand slug>_<line>_<size>.tres" (pj_new_sealand_slalom_117.tres, savanna_slalom_8_0.tres).
## GearCatalogue (catalogue.gd) lists the folders. How to add one is in
## Documentation/reports/fleet_gear/gear_page.md.
##
## The sizes are in the units the sport quotes on the gear:
## - a board: its volume in litres (117 for a 117 L board; BoardConfig.volume_m3 x 1000);
## - a sail: its area in square metres (7.8; SailConfig.area_m2);
## - a fin: its depth in centimetres (38 for a 38 cm fin; FinConfig.span_m x 100).
## The size is what the page shows and what the id is made of; the simulation sails `config`.

enum Kind { BOARD, SAIL, FIN }
## The gear's family. Slalom gear is built for top speed on a reach; free race gear is a little
## easier and more forgiving, for a wider range of wind.
enum Line { SLALOM, FREERACE }

@export var kind: Kind = Kind.BOARD
@export var brand: Brand
## The model's name as the page shows it, without the size: "Slalom T-SEC". A made-up name, never a
## real product's (tests/unit/test_gear.gd checks for the real makers' names).
@export var model_name: String = ""
@export var line: Line = Line.SLALOM
## Litres for a board, square metres for a sail, centimetres of depth for a fin (see above).
@export var size: float = 0.0
## One line for the gear page's card.
@export var description: String = ""
## The wind the gear is made for, knots (shown on the card).
@export var wind_from_kt: float = 0.0
@export var wind_to_kt: float = 0.0
## What the simulation sails: a BoardConfig, a SailConfig or a FinConfig (by `kind`). It may be a
## file of Game/config/ or the item's own numbers. The game always sails a copy (config_copy()),
## so the catalogue's numbers are never changed by a run.
@export var config: Resource

@export_group("Looks")
## The part's 3D model (a .glb built like tools/blender/build_rig_models.py builds the default
## ones, with the same node and material names). Null: the default model, stretched to this
## item's size by RigVisuals.
@export var model: PackedScene
## A board's deck and bottom pictures, in the hull's UV (as board_deck.png and board_bottom.png).
## Null: the default pictures.
@export var deck: Texture2D
@export var bottom: Texture2D
## A sail's panel picture, in the sail's UV, with the alpha code of sail_panels.png (1 = the cloth
## that `cloth` colours). Null: the default picture.
@export var panels: Texture2D
## A sail's cloth colour: it takes the place of the panel picture's red cloth. Leave it fully
## transparent (the default) for the brand's primary colour; white keeps the picture's own colours.
@export var cloth: Color = Color(0.0, 0.0, 0.0, 0.0)


## The id the settings keep: the brand's slug, the line and the size, "pj_new_sealand_slalom_117"
## or "savanna_slalom_8_0" (a sail's tenths after an underscore). It is also the file's name.
func id() -> String:
	var slug: String = brand.slug if brand != null else "unbranded"
	return "%s_%s_%s" % [slug, line_slug(), size_slug()]


## The size as the gear shows it: "117 L", "7.8 m²", "38 cm".
func size_text() -> String:
	match kind:
		Kind.SAIL:
			return "%.1f m²" % size
		Kind.FIN:
			return "%d cm" % roundi(size)
	return "%d L" % roundi(size)


## "Slalom T-SEC 117 L": the model's name and its size.
func title() -> String:
	return "%s %s" % [model_name, size_text()]


## "PJ New Sealand Slalom T-SEC 117 L": with the brand's name.
func full_name() -> String:
	var brand_name: String = brand.name if brand != null else ""
	return ("%s %s" % [brand_name, title()]).strip_edges()


## The line as the page shows it.
func line_name() -> String:
	return "Free race" if line == Line.FREERACE else "Slalom"


## The line in an id: "slalom" or "freerace".
func line_slug() -> String:
	return "freerace" if line == Line.FREERACE else "slalom"


## The size in an id: whole litres or centimetres, a sail's tenths after an underscore ("8_0").
func size_slug() -> String:
	if kind == Kind.SAIL:
		return ("%.1f" % size).replace(".", "_")
	return "%d" % roundi(size)


## "12 to 22 kt", for the card.
func wind_text() -> String:
	return "%d to %d kt" % [roundi(wind_from_kt), roundi(wind_to_kt)]


## The sail's cloth colour: its own, or the brand's primary when it has none.
func cloth_colour() -> Color:
	if cloth.a > 0.0:
		return cloth
	return brand.primary if brand != null else Color.WHITE


## A copy of the numbers for one simulation (deep, so nothing it changes reaches the catalogue).
func config_copy() -> Resource:
	return config.duplicate(true) if config != null else null
