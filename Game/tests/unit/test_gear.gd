extends GutTest
## The gear page's plumbing (Game/gear/; Documentation/reports/fleet_gear/gear_page.md): the
## catalogue's items, the default gear that the game sailed before the page, the choice kept in
## the settings, the simulation and the 3D rig built from the chosen gear, and no real maker's
## name on any item.

## The real makers' names, the same list the brands' test checks.
const BrandsTest: GDScript = preload("res://tests/unit/test_brands.gd")
const SAIL_6_5_ID: String = "southsails_freerace_6_5"
const FREERACE_BOARD_ID: String = "forbidden_freerace_120"
const LAKE_SCENE: String = "res://maps/silvaplana/sail_silvaplana.tscn"

var _saved_values: SettingsValues
var _saved_path: String


func before_each() -> void:
	# The tests use their own settings and never write the player's settings file.
	_saved_values = GameSettings.values
	_saved_path = GameSettings.path
	GameSettings.values = SettingsValues.new()
	GameSettings.path = ""


func after_each() -> void:
	GameSettings.values = _saved_values
	GameSettings.path = _saved_path


# --- The catalogue -------------------------------------------------------------------------

func test_every_item_loads_with_a_brand_and_the_right_config() -> void:
	var expected: Dictionary[GearItem.Kind, String] = {
		GearItem.Kind.BOARD: "BoardConfig", GearItem.Kind.SAIL: "SailConfig", GearItem.Kind.FIN: "FinConfig"}
	assert_gt(GearCatalogue.boards().size(), 0, "some boards")
	assert_gt(GearCatalogue.sails().size(), 0, "some sails")
	assert_gt(GearCatalogue.fins().size(), 0, "some fins")
	for kind: GearItem.Kind in expected:
		for item: GearItem in GearCatalogue.items(kind):
			var what: String = item.resource_path
			assert_eq(item.kind, kind, what + " is in its kind's folder")
			assert_not_null(item.brand, what + " has a brand")
			assert_ne(item.model_name, "", what + " has a model name")
			assert_ne(item.description, "", what + " has a line for its card")
			assert_lt(item.wind_from_kt, item.wind_to_kt, what + " has a wind range")
			assert_not_null(item.config, what + " has a config")
			if item.config != null:
				assert_eq((item.config.get_script() as Script).get_global_name(), expected[kind], what + "'s config is a " + expected[kind])


func test_ids_are_unique_and_name_the_files() -> void:
	var seen: Dictionary[String, String] = {}
	for item: GearItem in GearCatalogue.all_items():
		var id: String = item.id()
		assert_false(seen.has(id), "%s is used once (also by %s)" % [id, seen.get(id, "")])
		seen[id] = item.resource_path
		assert_eq(item.resource_path.get_file(), id + ".tres", "the file is named after the id")
		assert_eq(GearCatalogue.find(id), item, "find() finds " + id)


func test_an_unknown_id_finds_nothing() -> void:
	assert_null(GearCatalogue.find("nobody_slalom_99"))
	assert_null(GearCatalogue.find(""))


func test_the_sizes_are_the_configs_sizes() -> void:
	for item: GearItem in GearCatalogue.boards():
		assert_eq(roundi(item.size), roundi((item.config as BoardConfig).volume_m3 * 1000.0), item.id() + ": litres")
	for item: GearItem in GearCatalogue.sails():
		assert_almost_eq(item.size, (item.config as SailConfig).area_m2, 1e-6, item.id() + ": square metres")
	for item: GearItem in GearCatalogue.fins():
		assert_eq(roundi(item.size), roundi((item.config as FinConfig).span_m * 100.0), item.id() + ": centimetres")


func test_size_text_and_ids() -> void:
	var sail: GearItem = GearCatalogue.find(SAIL_6_5_ID)
	assert_eq(sail.size_text(), "6.5 m²")
	assert_eq(sail.size_slug(), "6_5")
	var board: GearItem = GearCatalogue.default_board()
	assert_eq(board.size_text(), "117 L")
	assert_eq(board.id(), "pj_new_sealand_slalom_117")
	assert_eq(GearCatalogue.default_fin().size_text(), "38 cm")
	assert_eq(board.full_name(), "PJ New Sealand Selkie 117 L")


func test_items_by_brand_and_the_brands_of_a_kind() -> void:
	var forbidden: Brand = Brand.find("forbidden")
	var boards: Array[GearItem] = GearCatalogue.by_brand(forbidden, GearItem.Kind.BOARD)
	assert_eq(boards.size(), 2, "Forbidden's two boards")
	assert_eq(boards[0].line, GearItem.Line.SLALOM, "the slalom line first")
	assert_eq(GearCatalogue.by_brand(forbidden, GearItem.Kind.SAIL).size(), 0, "Forbidden makes no sails")
	var board_brands: Array[Brand] = GearCatalogue.brands_of(GearItem.Kind.BOARD)
	assert_eq(board_brands.size(), 6, "six board brands")
	for brand: Brand in board_brands:
		assert_true(brand.makes_boards, brand.name + " makes boards")
	for brand: Brand in GearCatalogue.brands_of(GearItem.Kind.SAIL):
		assert_true(brand.makes_sails, brand.name + " makes sails")
	assert_eq(GearCatalogue.brands_of(GearItem.Kind.SAIL).size(), 7, "seven sail brands")


func test_no_real_maker_in_a_model_name_or_a_description() -> void:
	for item: GearItem in GearCatalogue.all_items():
		var text: String = (item.model_name + " | " + item.description).to_lower()
		for real: String in BrandsTest.REAL_BRANDS:
			assert_false(text.contains(real), "%s does not say '%s'" % [item.id(), real])


# --- The defaults ----------------------------------------------------------------------------

func test_the_default_items_are_the_game_config_number_for_number() -> void:
	_assert_same_numbers(GearCatalogue.default_board().config, load("res://config/board_default.tres"), "the default board")
	_assert_same_numbers(GearCatalogue.default_sail().config, load("res://config/sail_default.tres"), "the default sail")
	_assert_same_numbers(GearCatalogue.default_fin().config, load("res://config/fin_default.tres"), "the default fin")


func test_the_default_gear_sails_what_the_game_sailed() -> void:
	# The game's board before the gear page, and one built again on the default gear (each with
	# its own wind field: the field keeps the time, and each simulation steps its own).
	var before: WindsurferSim = WindsurferSim.create_for(EnvironmentConfig.new(), true, true)
	var base: WindsurferSim = WindsurferSim.create_for(EnvironmentConfig.new(), true, true)
	var sim: WindsurferSim = GearChoice.defaults().sim_with(base)
	_assert_same_numbers(sim.board_config, before.board_config, "the board")
	_assert_same_numbers(sim.sail_config, before.sail_config, "the sail")
	_assert_same_numbers(sim.fin_config, before.fin_config, "the fin")
	assert_true(sim.has_waves(), "the waves stay")
	assert_eq(sim.wind, base.wind, "the place's own wind field")
	# Sailed side by side for two seconds, the two boards do the same to the last bit.
	var controls: SimControls = SimControls.new()
	for i: int in 120:
		before.step(1.0 / 60.0, controls)
		sim.step(1.0 / 60.0, controls)
	assert_eq(sim.body.origin_world(), before.body.origin_world(), "the same place after 2 s")
	assert_eq(sim.body.velocity, before.body.velocity, "the same speed after 2 s")


# --- The choice ------------------------------------------------------------------------------

func test_the_settings_keep_the_three_ids() -> void:
	var saved: SettingsValues = SettingsValues.new()
	assert_eq(saved.gear_board, GearCatalogue.DEFAULT_BOARD_ID, "the default board to start with")
	assert_eq(saved.gear_sail, GearCatalogue.DEFAULT_SAIL_ID)
	assert_eq(saved.gear_fin, GearCatalogue.DEFAULT_FIN_ID)
	saved.gear_board = FREERACE_BOARD_ID
	saved.gear_sail = SAIL_6_5_ID
	saved.gear_fin = "pj_new_sealand_slalom_38"
	var file: ConfigFile = ConfigFile.new()
	saved.write_to(file)
	assert_eq(file.get_value("gear", "sail"), SAIL_6_5_ID, "in the section gear")
	var loaded: SettingsValues = SettingsValues.new()
	loaded.read_from(file)
	assert_eq(loaded.gear_board, FREERACE_BOARD_ID)
	assert_eq(loaded.gear_sail, SAIL_6_5_ID)
	assert_eq(loaded.gear_fin, "pj_new_sealand_slalom_38")
	loaded.reset_to_defaults()
	assert_eq(loaded.gear_sail, GearCatalogue.DEFAULT_SAIL_ID, "reset to the default")


func test_an_unknown_id_sails_the_default() -> void:
	var choice: GearChoice = GearChoice.from_ids("nobody_slalom_99", GearCatalogue.DEFAULT_BOARD_ID, "")
	assert_eq(choice.board, GearCatalogue.default_board(), "an unknown board: the default")
	assert_eq(choice.sail, GearCatalogue.default_sail(), "a board's id for the sail: the default sail")
	assert_eq(choice.fin, GearCatalogue.default_fin(), "no id: the default fin")


func test_the_chosen_gear_is_what_the_simulation_sails() -> void:
	var base: WindsurferSim = WindsurferSim.create_for(EnvironmentConfig.new(), false, true)
	var choice: GearChoice = GearChoice.from_ids(FREERACE_BOARD_ID, SAIL_6_5_ID, "")
	var sim: WindsurferSim = choice.sim_with(base)
	assert_almost_eq(sim.sail_config.area_m2, 6.5, 1e-6, "the 6.5")
	assert_almost_eq(sim.board_config.length_m, 2.4, 1e-6, "the 240 board")
	assert_ne(sim.sail_config, choice.sail.config, "a copy, not the catalogue's own")
	assert_ne(sim.board_config, choice.board.config, "a copy, not the catalogue's own")
	assert_eq(sim.sail.config, sim.sail_config, "the sail model sails it")
	assert_false(sim.has_waves(), "flat water stays flat")
	var controls: SimControls = SimControls.new()
	for i: int in 60:
		sim.step(1.0 / 60.0, controls)
	assert_true(sim.body.origin_world().is_finite(), "it sails")


func test_the_sailing_scene_sails_the_settings_gear() -> void:
	GameSettings.values.gear_sail = SAIL_6_5_ID
	GameSettings.values.gear_board = FREERACE_BOARD_ID
	var scene: SailingScene = (load("res://main.tscn") as PackedScene).instantiate()
	add_child_autofree(scene)
	var windsurfer: WindsurferNode = scene.get_node("Windsurfer")
	assert_almost_eq(windsurfer.sim.sail_config.area_m2, 6.5, 1e-6, "the chosen sail")
	assert_almost_eq(windsurfer.sim.board_config.volume_m3, 0.12, 1e-6, "the chosen board")
	assert_ne(windsurfer.sim.sail_config, GearCatalogue.find(SAIL_6_5_ID).config, "on its own copy")
	assert_true(windsurfer.sim.has_waves(), "on the settings' sea")
	var hud: Hud = scene.get_node("HUD")
	assert_true(hud.gear_text.begins_with("Forbidden Curfew 120 L  ·  SouthSails Due South 6.5 m²"), "the names on the F1 panel: " + hud.gear_text)


func test_the_lake_sails_the_settings_gear() -> void:
	GameSettings.values.gear_sail = SAIL_6_5_ID
	var scene: SailingScene = (load(LAKE_SCENE) as PackedScene).instantiate()
	add_child_autofree(scene)
	var windsurfer: WindsurferNode = scene.get_node("Windsurfer")
	assert_almost_eq(windsurfer.sim.sail_config.area_m2, 6.5, 1e-6, "the chosen sail on the lake")
	assert_true(windsurfer.sim.wind is MapWindField, "in the map's own wind")
	assert_almost_eq(windsurfer.sim.air_density_kg_m3, 0.98, 1e-9, "in the thin air")


# --- The 3D rig ------------------------------------------------------------------------------

func test_the_rig_shows_the_items_pictures_and_cloth() -> void:
	var deck: Texture2D = _picture(Color.RED)
	var bottom: Texture2D = _picture(Color.GREEN)
	var panels: Texture2D = _picture(Color.BLUE)
	var choice: GearChoice = GearChoice.defaults()
	choice.board = choice.board.duplicate() as GearItem
	choice.board.deck = deck
	choice.board.bottom = bottom
	choice.sail = choice.sail.duplicate() as GearItem
	choice.sail.panels = panels
	choice.sail.cloth = Color(0.2, 0.4, 0.6)
	var rig: RigVisuals = RigVisuals.new()
	add_child_autofree(rig)
	rig.build(choice.board_config(), choice.sail_config(), choice.fin_config(), choice)
	var hull: MeshInstance3D = rig.get_node("Board").find_child("Hull", true, false) as MeshInstance3D
	var painted: Array[Texture2D] = []
	for surface: int in hull.mesh.get_surface_count():
		var material: BaseMaterial3D = hull.get_surface_override_material(surface) as BaseMaterial3D
		if material != null:
			painted.append(material.albedo_texture)
	assert_true(deck in painted, "the item's deck")
	assert_true(bottom in painted, "the item's bottom")
	var cloth: MeshInstance3D = rig.sail_cloth()
	for surface: int in cloth.mesh.get_surface_count():
		var material: ShaderMaterial = cloth.get_surface_override_material(surface) as ShaderMaterial
		assert_eq(material.get_shader_parameter("panel_texture"), panels, "the item's panels")
		assert_eq(material.get_shader_parameter("sail_tint"), Color(0.2, 0.4, 0.6), "the item's cloth colour")


func test_a_sail_without_its_own_colour_takes_the_brands() -> void:
	var sail: GearItem = GearCatalogue.find(SAIL_6_5_ID)
	assert_eq(sail.cloth_colour(), sail.brand.primary)
	assert_eq(GearCatalogue.default_sail().cloth_colour(), Color.WHITE, "the default sail keeps its own colours")


func test_the_default_models_are_stretched_to_a_smaller_sail() -> void:
	var sail: SailConfig = load("res://config/sail_6_5.tres")
	var model: SailConfig = RigVisuals.MODEL_SAIL
	assert_eq(RigVisuals.fit_sail(model, model), Vector3(1.0, 1.0, 0.0), "the 8.0 is not stretched")
	var rig: RigVisuals = RigVisuals.new()
	add_child_autofree(rig)
	rig.build(load("res://config/board_default.tres"), sail, load("res://config/fin_default.tres"))
	var foot: Vector3 = sail.mast_foot_local
	var mast_dir: Vector3 = Vector3(0.0, 1.0, 0.15).normalized()
	var boom_dir: Vector3 = Vector3(0.4, 0.0, 1.0).normalized()
	rig.pose_sailing(mast_dir, boom_dir)
	var sail_node: Node3D = rig.get_node("Sail") as Node3D
	var boom: Node3D = rig.get_node("Sail/Boom") as Node3D
	var mast: Node3D = rig.get_node("Mast") as Node3D
	var clew: Vector3 = sail_node.transform * Vector3(model.boom_m, model.boom_height_m, 0.0)
	var expected_clew: Vector3 = foot + mast_dir * sail.boom_height_m + boom_dir * sail.boom_m
	assert_almost_eq(clew, expected_clew, Vector3.ONE * 1e-4, "the model's clew at the 6.5's boom end")
	var boom_transform: Transform3D = sail_node.transform * boom.transform
	assert_almost_eq(boom_transform.origin, foot + mast_dir * sail.boom_height_m, Vector3.ONE * 1e-4, "the boom on the mast at the 6.5's height")
	assert_almost_eq(boom_transform * Vector3(model.boom_m, 0.0, 0.0), expected_clew, Vector3.ONE * 1e-4, "the boom's end at the clew")
	var head: Vector3 = sail_node.transform * Vector3(0.0, model.mast_m - RigVisuals.SAIL_HEAD_BELOW_MAST_TOP_M, 0.0)
	assert_almost_eq(head, foot + mast_dir * (sail.mast_m - RigVisuals.SAIL_HEAD_BELOW_MAST_TOP_M), Vector3.ONE * 1e-4, "the head under the mast top")
	var mast_top: Vector3 = mast.transform * Vector3(0.0, model.mast_m, 0.0)
	assert_almost_eq(mast_top, foot + mast_dir * sail.mast_m, Vector3.ONE * 1e-4, "the mast as long as the 6.5's")


func test_the_default_board_model_is_stretched_to_another_board() -> void:
	var board: BoardConfig = load("res://config/board_freeride_240.tres")
	var rig: RigVisuals = RigVisuals.new()
	add_child_autofree(rig)
	rig.build(board, load("res://config/sail_default.tres"), load("res://config/fin_default.tres"))
	var model: BoardConfig = RigVisuals.MODEL_BOARD
	var expected: Vector3 = Vector3(board.width_m / model.width_m, board.thickness_m / model.thickness_m, board.length_m / model.length_m)
	assert_almost_eq((rig.get_node("Board") as Node3D).scale, expected, Vector3.ONE * 1e-6)


# --- The page --------------------------------------------------------------------------------

func test_the_page_shows_the_brands_and_keeps_a_choice_at_once() -> void:
	var page: GearPage = (load("res://ui/gear_page.tscn") as PackedScene).instantiate()
	add_child_autofree(page)
	page.open()
	page.show_tab("sail")
	assert_eq(page.find_children("Brand_*", "Button", true, false).size(), 6 + 7 + 1, "the brands of every tab")
	var chosen_card: Button = page.find_child("Item_" + GearCatalogue.DEFAULT_SAIL_ID, true, false) as Button
	assert_not_null(chosen_card, "the chosen sail's brand is shown")
	assert_true(chosen_card.button_pressed, "the chosen sail is lit")
	# Another brand, then its sail.
	(page.find_child("Brand_southsails", true, false) as Button).pressed.emit()
	await wait_process_frames(1)
	var card: Button = page.find_child("Item_" + SAIL_6_5_ID, true, false) as Button
	assert_not_null(card, "the brand's models are shown")
	card.pressed.emit()
	assert_eq(GameSettings.values.gear_sail, SAIL_6_5_ID, "kept in the settings at once")
	var rig: RigVisuals = page.preview_rig()
	assert_not_null(rig, "a preview")
	var cloth: ShaderMaterial = rig.sail_cloth().get_surface_override_material(0) as ShaderMaterial
	assert_eq(cloth.get_shader_parameter("sail_tint"), Brand.find("southsails").primary, "the preview in the brand's cloth")
	page.close()


func test_the_page_can_be_walked_with_the_keyboard() -> void:
	var page: GearPage = (load("res://ui/gear_page.tscn") as PackedScene).instantiate()
	add_child_autofree(page)
	page.open()
	var back: Button = page.get_node("%BackButton")
	for tab: String in ["board", "sail", "fin"]:
		page.show_tab(tab)
		await wait_process_frames(2)
		var at: Control = page.first_focus()
		var steps: int = 0
		var passed_a_card: bool = false
		while at != null and at != back and steps < 20:
			at = at.find_valid_focus_neighbor(SIDE_BOTTOM)
			passed_a_card = passed_a_card or (at != null and at.name.begins_with("Item_"))
			steps += 1
		assert_eq(at, back, tab + ": Down from the tabs reaches Back")
		assert_true(passed_a_card, tab + ": past a model's card")


func test_the_start_menu_sails_the_gear_chosen_on_its_page() -> void:
	var menu: Node = (load("res://ui/start_menu.tscn") as PackedScene).instantiate()
	add_child_autofree(menu)
	(menu.get_node("%GearButton") as Button).pressed.emit()
	var page: GearPage = menu.get_node("%Gear")
	assert_true(page.visible, "the Gear button opens the page")
	(page.find_child("Brand_southsails", true, false) as Button).pressed.emit()
	(page.find_child("Item_" + SAIL_6_5_ID, true, false) as Button).pressed.emit()
	page.close()
	await wait_process_frames(1)
	var windsurfer: WindsurferNode = menu.get_node("Sailing/Windsurfer")
	assert_almost_eq(windsurfer.sim.sail_config.area_m2, 6.5, 1e-6, "the scene behind the menu sails the new sail")
	assert_true(windsurfer.use_autopilot, "still behind the menu")
	assert_eq(menu.get_node("Sailing").get_index(), 0, "in the old one's place, under the menu")
	(menu.get_node("%OpenWaterButton") as Button).pressed.emit()
	assert_false(windsurfer.use_autopilot, "and the player sails it")


func test_a_reset_of_the_settings_puts_the_default_gear_behind_the_menu() -> void:
	GameSettings.values.gear_sail = SAIL_6_5_ID
	var menu: Node = (load("res://ui/start_menu.tscn") as PackedScene).instantiate()
	add_child_autofree(menu)
	assert_almost_eq((menu.get_node("Sailing/Windsurfer") as WindsurferNode).sim.sail_config.area_m2, 6.5, 1e-6)
	(menu.get_node("%SettingsButton") as Button).pressed.emit()
	var settings: SettingsMenu = menu.get_node("%Settings")
	(settings.get_node("%ResetButton") as Button).pressed.emit()
	settings.close()
	await wait_process_frames(1)
	assert_almost_eq((menu.get_node("Sailing/Windsurfer") as WindsurferNode).sim.sail_config.area_m2, 8.0, 1e-6, "the default 8.0 again")


# --- Helpers ---------------------------------------------------------------------------------

## Every stored number of two configs is the same.
func _assert_same_numbers(actual: Resource, expected: Resource, what: String) -> void:
	assert_not_null(actual, what)
	if actual == null:
		return
	assert_eq(actual.get_script(), expected.get_script(), what + ": the same kind of config")
	var compared: int = 0
	for property: Dictionary in expected.get_property_list():
		var usage: int = property["usage"]
		if usage & PROPERTY_USAGE_SCRIPT_VARIABLE == 0 or usage & PROPERTY_USAGE_STORAGE == 0:
			continue
		var name: String = property["name"]
		assert_eq(actual.get(name), expected.get(name), "%s: %s" % [what, name])
		compared += 1
	assert_gt(compared, 10, what + ": its numbers were compared")


## A small one-colour picture.
func _picture(colour: Color) -> Texture2D:
	var image: Image = Image.create(4, 4, false, Image.FORMAT_RGBA8)
	image.fill(colour)
	return ImageTexture.create_from_image(image)
