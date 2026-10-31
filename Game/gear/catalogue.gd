class_name GearCatalogue
extends RefCounted
## The gear the player can choose: every GearItem in Game/gear/boards/, Game/gear/sails/ and
## Game/gear/fins/ (one .tres per item). A new item needs no code: put its file in the folder and
## the gear page lists it. The folders are listed when asked (ResourceLoader.list_directory, which
## also finds the files in an exported game, where they are stored under other names).
##
## The default items are the gear the game sailed before the gear page existed (the default
## board, the 8.0 and the default fin in Game/config/), so a player who never opens the page sails
## exactly what they did. tests/unit/test_gear.gd checks that, number for number.

const BOARDS_FOLDER: String = "res://gear/boards"
const SAILS_FOLDER: String = "res://gear/sails"
const FINS_FOLDER: String = "res://gear/fins"

## The default choice (the settings start with these ids).
const DEFAULT_BOARD_ID: String = "pj_new_sealand_slalom_117"
const DEFAULT_SAIL_ID: String = "savanna_slalom_8_0"
const DEFAULT_FIN_ID: String = "pj_new_sealand_slalom_38"


static func boards() -> Array[GearItem]:
	return items(GearItem.Kind.BOARD)


static func sails() -> Array[GearItem]:
	return items(GearItem.Kind.SAIL)


static func fins() -> Array[GearItem]:
	return items(GearItem.Kind.FIN)


## Every item of one kind, sorted by the file name (so by the brand, the line and the size).
static func items(kind: GearItem.Kind) -> Array[GearItem]:
	var folder: String = folder_of(kind)
	var files: PackedStringArray = PackedStringArray()
	for file: String in ResourceLoader.list_directory(folder):
		if file.get_extension() == "tres":
			files.append(file)
	files.sort()
	var found: Array[GearItem] = []
	for file: String in files:
		var item: GearItem = load(folder.path_join(file)) as GearItem
		if item != null:
			found.append(item)
		else:
			push_warning("%s is not a GearItem." % folder.path_join(file))
	return found


## Every item: the boards, the sails, the fins.
static func all_items() -> Array[GearItem]:
	var found: Array[GearItem] = boards()
	found.append_array(sails())
	found.append_array(fins())
	return found


## The item with this id ("savanna_slalom_8_0"), or null when there is none.
static func find(wanted_id: String) -> GearItem:
	if wanted_id.is_empty():
		return null
	for item: GearItem in all_items():
		if item.id() == wanted_id:
			return item
	return null


## A brand's items of one kind, the slalom line first, each line from small to big.
static func by_brand(brand: Brand, kind: GearItem.Kind) -> Array[GearItem]:
	var found: Array[GearItem] = []
	for item: GearItem in items(kind):
		if item.brand != null and brand != null and item.brand.slug == brand.slug:
			found.append(item)
	found.sort_custom(func(a: GearItem, b: GearItem) -> bool:
		if a.line != b.line:
			return a.line < b.line
		return a.size < b.size)
	return found


## The brands that have items of one kind, in the brands' own order (Brand.all()).
static func brands_of(kind: GearItem.Kind) -> Array[Brand]:
	var slugs: Dictionary[String, bool] = {}
	for item: GearItem in items(kind):
		if item.brand != null:
			slugs[item.brand.slug] = true
	var found: Array[Brand] = []
	for brand: Brand in Brand.all():
		if slugs.has(brand.slug):
			found.append(brand)
	return found


static func default_board() -> GearItem:
	return find(DEFAULT_BOARD_ID)


static func default_sail() -> GearItem:
	return find(DEFAULT_SAIL_ID)


static func default_fin() -> GearItem:
	return find(DEFAULT_FIN_ID)


## The default item of one kind.
static func default_item(kind: GearItem.Kind) -> GearItem:
	match kind:
		GearItem.Kind.SAIL:
			return default_sail()
		GearItem.Kind.FIN:
			return default_fin()
	return default_board()


## The item with this id if it is of this kind, else the kind's default (an unknown id in the
## settings, or a sail's id where a board's belongs).
static func find_or_default(wanted_id: String, kind: GearItem.Kind) -> GearItem:
	var item: GearItem = find(wanted_id)
	if item != null and item.kind == kind:
		return item
	return default_item(kind)


## The folder of one kind's files.
static func folder_of(kind: GearItem.Kind) -> String:
	match kind:
		GearItem.Kind.SAIL:
			return SAILS_FOLDER
		GearItem.Kind.FIN:
			return FINS_FOLDER
	return BOARDS_FOLDER
