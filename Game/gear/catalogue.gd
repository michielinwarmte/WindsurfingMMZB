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
##
## The fins (Max, 6 November 2026): every fin brand has one slalom fin that the player sets to any
## depth from 28 to 52 cm (the gear page's slider). A fin's id stays "<brand slug>_slalom_<cm>". The
## folder holds each brand's 38 cm fin (and Montag's five sizes, which stay as they were); any other
## depth is made from the brand's 38 cm fin when it is first asked for (fin_of(), make_fin()): the
## same fin, its depth and its area those of a real race fin of that depth (FinSizes). find() finds
## those too, so the settings, the LAN and the AI fleet name them by their ids as any other item.

const BOARDS_FOLDER: String = "res://gear/boards"
const SAILS_FOLDER: String = "res://gear/sails"
const FINS_FOLDER: String = "res://gear/fins"

## The default choice (the settings start with these ids).
const DEFAULT_BOARD_ID: String = "pj_new_sealand_slalom_117"
const DEFAULT_SAIL_ID: String = "savanna_slalom_8_0"
const DEFAULT_FIN_ID: String = "pj_new_sealand_slalom_38"
## The fins' depths and what goes with a depth: the area, the board, the wind (fin_sizes.gd).
const FIN_SIZES: FinSizes = preload("res://gear/fin_sizes.tres")
## The depth of each fin brand's file that its other depths are made from (its template).
const FIN_TEMPLATE_DEPTH_CM: int = 38


static func boards() -> Array[GearItem]:
	return items(GearItem.Kind.BOARD)


static func sails() -> Array[GearItem]:
	return items(GearItem.Kind.SAIL)


static func fins() -> Array[GearItem]:
	return items(GearItem.Kind.FIN)


## The items already loaded, by kind, kept for the session. Every lookup (find(), a persona's
## gear) used to load the whole catalogue again, its models and textures with it, and a race's
## fleet of personas did that some thirty times in one frame: the graphics card ran out of memory
## ("Can't create buffer", Session 68) and the race took long to appear. Loaded once, the
## textures (compressed) hold about 110 MB of the card's memory.
static var _loaded: Dictionary[int, Array] = {}
## The fins made for a depth without a file (fin_of()), by id, kept for the session: every board of
## a race that sails the same fin sails the same item.
static var _made_fins: Dictionary[String, GearItem] = {}


## Every item of one kind, sorted by the file name (so by the brand, the line and the size). A new
## array each call (the items themselves are shared).
static func items(kind: GearItem.Kind) -> Array[GearItem]:
	if not _loaded.has(kind):
		_loaded[kind] = _load_items(kind)
	var found: Array[GearItem] = []
	found.assign(_loaded[kind])
	return found


static func _load_items(kind: GearItem.Kind) -> Array[GearItem]:
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


## The item with this id ("savanna_slalom_8_0"; a fin of any depth, "nt8_slalom_44"), or null when
## there is none.
static func find(wanted_id: String) -> GearItem:
	if wanted_id.is_empty():
		return null
	for item: GearItem in all_items():
		if item.id() == wanted_id:
			return item
	return _fin_from_id(wanted_id)


## A fin from its id, "<brand slug>_slalom_<cm>", made for its depth (fin_of()); null when the id
## names no fin brand or no depth of the slider.
static func _fin_from_id(wanted_id: String) -> GearItem:
	var at: int = wanted_id.rfind("_slalom_")
	if at <= 0:
		return null
	var depth_text: String = wanted_id.substr(at + "_slalom_".length())
	if not depth_text.is_valid_int():
		return null
	var fin: GearItem = fin_of(wanted_id.left(at), depth_text.to_int())
	return fin if fin != null and fin.id() == wanted_id else null


# ---------------------------------------------------------------- the fins of any depth

## The fin brands (those with a fin in the folder: Montag, PJ New Sealand's default fin, the five fin
## makers), in the brands' order.
static func fin_brands() -> Array[Brand]:
	return brands_of(GearItem.Kind.FIN)


## A brand's slalom fin of a depth (whole cm, FinSizes' range): its file when there is one (each
## brand's 38 cm fin, Montag's five sizes: their numbers exactly as before), else the brand's 38 cm
## fin made to that depth (make_fin()), once, then kept. Null for a brand without fins or a depth
## outside the range.
static func fin_of(brand_slug: String, depth_cm: int) -> GearItem:
	if not FIN_SIZES.has_depth(depth_cm):
		return null
	var wanted_id: String = "%s_slalom_%d" % [brand_slug, depth_cm]
	if _made_fins.has(wanted_id):
		return _made_fins[wanted_id]
	for item: GearItem in fins():
		if item.id() == wanted_id:
			return item
	var template: GearItem = fin_template(brand_slug)
	if template == null:
		return null
	var made: GearItem = make_fin(template, depth_cm)
	_made_fins[wanted_id] = made
	return made


## A brand's 38 cm slalom fin, the one its other depths are made from; null for a brand without.
static func fin_template(brand_slug: String) -> GearItem:
	for item: GearItem in fins():
		if item.brand != null and item.brand.slug == brand_slug and item.line == GearItem.Line.SLALOM 				and roundi(item.size) == FIN_TEMPLATE_DEPTH_CM:
			return item
	return null


## A fin like `template` (a brand's 38 cm fin) at another depth: the same planform, section, flex
## test (the same material: the beam's stiffness then follows the depth and the chord by itself,
## FinModel) and looks; the depth asked for; the area of a race fin of that depth (FinSizes) times
## the template's own share of its depth's race area (1 for every brand but PJ New Sealand, whose
## default fin is 17 % bigger than a race fin of its depth and stays so at every depth); the wind
## range and the card's line of that depth. Its model is the template's, stretched to it by
## RigVisuals (model_built_for).
static func make_fin(template: GearItem, depth_cm: int) -> GearItem:
	var template_fin: FinConfig = template.config as FinConfig
	var share: float = template_fin.area_m2 / FIN_SIZES.area_m2(roundi(template.size))
	var fin: FinConfig = template_fin.duplicate() as FinConfig
	fin.span_m = depth_cm / 100.0
	fin.area_m2 = FIN_SIZES.area_m2(depth_cm) * share
	var item: GearItem = template.duplicate() as GearItem
	item.size = float(depth_cm)
	item.config = fin
	item.wind_from_kt = FIN_SIZES.wind_from_kt(depth_cm)
	item.wind_to_kt = FIN_SIZES.wind_to_kt(depth_cm)
	item.description = fin_description(fin)
	item.model_built_for = template_fin if template.model != null else null
	return item


## The card's line of a fin: "Carbon slalom fin, 44 cm deep, 378 cm²: for boards about 82 cm wide."
## (the line tools/gear/make_catalogue.py wrote for Montag's fins).
static func fin_description(fin: FinConfig) -> String:
	var depth_cm: int = roundi(fin.span_m * 100.0)
	return "Carbon slalom fin, %d cm deep, %d cm²: for boards about %d cm wide." % [
		depth_cm, roundi(fin.area_m2 * 10000.0), _round_half_even(FIN_SIZES.board_width_m(depth_cm) * 100.0)]


## A number rounded to a whole one, a half to the even one (72.5 to 72), as Python's round() does:
## the catalogue's writer rounded Montag's cards so (the 38 cm fin's board is 72.5 cm wide).
static func _round_half_even(value: float) -> int:
	var below: float = floorf(value)
	if value - below == 0.5:
		return int(below) if int(below) % 2 == 0 else int(below) + 1
	return roundi(value)


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
