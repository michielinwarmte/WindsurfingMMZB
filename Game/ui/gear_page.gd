class_name GearPage
extends MenuPage
## The gear page of the start menu (Michiel, 31 October 2026): the boards, sails and fins of the
## game's brands (Brand, GearCatalogue). Three tabs, Board, Sail and Fin; on each, the brands as
## a row of cards (the mark, the name, the tagline), and the chosen brand's models as cards (the
## name and size, the line, the wind range, a line about it). Choosing a model keeps it in the
## settings at once (GameSettings, section "gear"); the sailing scene sails it from the next start
## (main.gd). On the right a 3D preview turns the chosen gear slowly (a RigVisuals built from the
## chosen gear, in a little world of its own): on the Sail tab the whole rig as it sails, on the
## Board tab the board alone, standing on its tail as boards stand in a shop, and on the Fin tab
## the board upside down with the fin up, turning about the fin.
##
## The Fin tab (Max, 6 November 2026): each fin brand has one slalom fin, and a slider sets its depth
## from 28 to 52 cm (FinSizes); the depth recommended for the chosen board's width is marked under
## the slider in orange. Moving the slider chooses that brand's fin of that depth at once (saved as
## "<brand>_slalom_<cm>"), and the preview's fin follows.
##
## Keys: the arrows (or the gamepad's stick and d-pad) move between the cards, Enter (or A)
## chooses, Ctrl+Tab and Ctrl+Shift+Tab (or the shoulder buttons) change the tab, Esc (or B) goes
## back. For screenshots: --page=gear or --page=gear/sail (start_menu.gd).

## The cards' sizes, px: three brands and two models fit side by side on a tab, also when the
## tab needs its scroll bar.
const BRAND_CARD_SIZE: Vector2 = Vector2(236.0, 64.0)
const ITEM_CARD_SIZE: Vector2 = Vector2(360.0, 100.0)
const MARK_SIZE: float = 36.0
const LOGO_SIZE: float = 46.0
## The text on a chosen card, which the theme paints orange: dark, as on the menus' pressed buttons.
const CHOSEN_TEXT: Color = Color(0.04, 0.07, 0.12)
## How fast the preview turns, radians per second (a turn in about 18 s).
const PREVIEW_TURN_RAD_S: float = 0.35
## The preview's camera on each tab (Board, Sail, Fin): where the eye is, the point it looks at
## (m; the stand turns about the vertical through the origin) and the field of view (degrees). On
## the Board tab the board stands on its tail, its middle at the origin; on the Fin tab it lies
## upside down with the fin's root at the origin (_pose_for_tab()).
const SHOTS: Array[Array] = [
	[Vector3(0.0, 0.3, 4.3), Vector3(0.0, 0.0, 0.0), 40.0],
	[Vector3(0.0, 2.7, 10.5), Vector3(0.0, 2.45, 0.0), 38.0],
	[Vector3(0.0, 0.95, 1.45), Vector3(0.0, 0.22, 0.0), 36.0],
]
const BOARD_TAB: int = 0
## The tab whose preview shows the whole rig; the others show the board alone.
const RIG_TAB: int = 1
## The line at the bottom of the page; on the Sail tab with PH14's warning.
const NOTE: String = "Kept at once and sailed from the next start. Each model sails its own real-world size."
const PH14_NOTE: String = " The sail sizes are not tuned yet (PH14): how each size sails may still change."
const FIN_TAB: int = 2
const FIN_NOTE: String = " The fin brands differ in their look: at the same depth their fins sail alike (PJ New Sealand's is wider)."
## The mark under the depth slider at the depth recommended for the chosen board (the theme's orange).
const RECOMMENDED_MARK: Color = Color(1.0, 0.62, 0.2)
## The depth slider's width, px.
const FIN_SLIDER_WIDTH: float = 420.0

@onready var _tabs: TabContainer = %Tabs
@onready var _sailing: Label = %Sailing
@onready var _viewport: SubViewport = %Viewport
@onready var _preview_name: Label = %PreviewName
@onready var _back_button: Button = %BackButton
@onready var _note: Label = %Note

## The brand each tab shows the models of (by GearItem.Kind).
var _shown_brand: Dictionary[int, Brand] = {}
## Each tab's part under the brands: the brand's header and its model cards.
var _brand_parts: Dictionary[int, VBoxContainer] = {}
## The Fin tab's depth slider, the label with the depth and the area, and the place of the fin's
## card (built again when the depth changes).
var _fin_slider: HSlider = null
var _fin_value: Label = null
var _fin_card_place: HFlowContainer = null
var _camera: Camera3D
var _pivot: Node3D
var _rig: RigVisuals = null


func _ready() -> void:
	_back_button.pressed.connect(close)
	_back_button.mouse_entered.connect(_back_button.grab_focus)
	_tabs.tab_changed.connect(_on_tab_changed)
	_build_preview_world()
	_refresh()


func open() -> void:
	# The settings may have changed since the page was built (a reset in the Settings page).
	_refresh()
	super()


func close() -> void:
	GameSettings.save()
	super()


func first_focus() -> Control:
	return _tabs.get_tab_bar()


## Shows one tab: board, sail or fin (for --page=gear/<tab>).
func show_tab(tab_name: String) -> void:
	for i: int in _tabs.get_tab_count():
		if _tabs.get_tab_title(i).to_lower() == tab_name.to_lower():
			_tabs.current_tab = i


## The gear chosen in the settings.
func chosen() -> GearChoice:
	return GearChoice.from_settings(GameSettings.values)


## Keeps an item as the player's choice of its kind, at once.
func choose(item: GearItem) -> void:
	match item.kind:
		GearItem.Kind.SAIL:
			GameSettings.values.gear_sail = item.id()
		GearItem.Kind.FIN:
			GameSettings.values.gear_fin = item.id()
		_:
			GameSettings.values.gear_board = item.id()
	GameSettings.save()
	_show_choice()


func _process(delta: float) -> void:
	if is_visible_in_tree() and _pivot != null:
		_pivot.rotate_y(PREVIEW_TURN_RAD_S * delta)


func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	# Switch tabs with the gamepad's shoulder buttons or Ctrl+Tab / Ctrl+Shift+Tab (as the settings).
	var step: int = MenuFocus.tab_step(event)
	if step != 0:
		_tabs.current_tab = posmod(_tabs.current_tab + step, _tabs.get_tab_count())
		_tabs.get_tab_bar().grab_focus()
		get_viewport().set_input_as_handled()
		return
	super(event)


# ---------------------------------------------------------------- the tabs

## Builds every tab again from the catalogue and the settings, each showing its chosen item's brand.
func _refresh() -> void:
	var choice: GearChoice = chosen()
	for tab: int in _tabs.get_tab_count():
		var kind: GearItem.Kind = _kind_of_tab(tab)
		_shown_brand[kind] = choice.item(kind).brand
		_build_tab(kind)
	_show_choice()


## One tab: the brands' cards, then the shown brand's header and its models.
func _build_tab(kind: GearItem.Kind) -> void:
	var rows: VBoxContainer = _tabs.get_child(_tab_of_kind(kind)).get_node("Rows") as VBoxContainer
	for child: Node in rows.get_children():
		rows.remove_child(child)
		child.queue_free()
	rows.add_child(_small_title("Brands"))
	var brands: HFlowContainer = _flow()
	var group: ButtonGroup = ButtonGroup.new()
	for brand: Brand in GearCatalogue.brands_of(kind):
		var card: Button = _make_card(brand.name, brand.tagline, "", brand.mark, brand, BRAND_CARD_SIZE)
		card.name = "Brand_" + brand.slug
		card.button_group = group
		card.button_pressed = _shown_brand[kind] != null and brand.slug == _shown_brand[kind].slug
		card.pressed.connect(_show_brand.bind(kind, brand))
		brands.add_child(card)
	rows.add_child(brands)
	var part: VBoxContainer = VBoxContainer.new()
	part.add_theme_constant_override("separation", 8)
	rows.add_child(part)
	_brand_parts[kind] = part
	_fill_brand_part(kind)


## Shows a brand's models on its tab (a brand card was chosen).
func _show_brand(kind: GearItem.Kind, brand: Brand) -> void:
	_shown_brand[kind] = brand
	_fill_brand_part(kind)


## The shown brand's header (its logo, name and tagline) and its models' cards, the chosen one lit.
func _fill_brand_part(kind: GearItem.Kind) -> void:
	var part: VBoxContainer = _brand_parts[kind]
	for child: Node in part.get_children():
		part.remove_child(child)
		child.queue_free()
	var brand: Brand = _shown_brand[kind]
	if brand == null:
		return
	part.add_child(_brand_header(brand))
	if kind == GearItem.Kind.FIN:
		_fill_fin_part(part, brand)
		return
	var items: HFlowContainer = _flow()
	var group: ButtonGroup = ButtonGroup.new()
	var chosen_id: String = chosen().item(kind).id()
	for item: GearItem in GearCatalogue.by_brand(brand, kind):
		var details: String = "%s  ·  %s" % [item.line_name(), item.wind_text()]
		var card: Button = _make_card(item.title(), details, item.description, null, brand, ITEM_CARD_SIZE)
		card.name = "Item_" + item.id()
		card.button_group = group
		card.button_pressed = item.id() == chosen_id
		card.pressed.connect(choose.bind(item))
		items.add_child(card)
	part.add_child(items)


## The Fin tab's brand part under its header: the brand's fin as a card (lit when it is the chosen
## fin; pressing it chooses the fin at the slider's depth), and the depth slider with the depth and
## the area, the depth recommended for the chosen board marked under it.
func _fill_fin_part(part: VBoxContainer, brand: Brand) -> void:
	var sizes: FinSizes = GearCatalogue.FIN_SIZES
	var depth: int = sizes.clamp_depth(roundi(chosen().fin.size))
	_fin_card_place = _flow()
	part.add_child(_fin_card_place)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	var title: Label = Label.new()
	title.text = "Depth"
	title.theme_type_variation = &"CardTitleLabel"
	row.add_child(title)
	_fin_slider = HSlider.new()
	_fin_slider.name = "FinDepth"
	_fin_slider.min_value = sizes.min_depth_cm
	_fin_slider.max_value = sizes.max_depth_cm
	_fin_slider.step = 1.0
	_fin_slider.value = depth
	_fin_slider.tick_count = sizes.max_depth_cm - sizes.min_depth_cm + 1
	_fin_slider.custom_minimum_size = Vector2(FIN_SLIDER_WIDTH, 30.0)
	_fin_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_fin_slider.mouse_entered.connect(_fin_slider.grab_focus)
	var board_width_m: float = (chosen().board.config as BoardConfig).width_m
	var recommended: int = sizes.recommended_depth_cm(board_width_m)
	_fin_slider.draw.connect(_draw_recommended_mark.bind(_fin_slider, recommended))
	row.add_child(_fin_slider)
	_fin_value = Label.new()
	_fin_value.name = "FinDepthValue"
	_fin_value.theme_type_variation = &"CardTitleLabel"
	row.add_child(_fin_value)
	part.add_child(row)
	var hint: Label = Label.new()
	hint.text = "The orange mark: %d cm, the depth for your board (%d cm wide). Deeper for lighter wind, shorter for more." % [
		recommended, roundi(board_width_m * 100.0)]
	hint.theme_type_variation = &"HintLabel"
	part.add_child(hint)
	_show_fin_card(brand, depth)
	_fin_slider.value_changed.connect(_on_fin_depth_changed.bind(brand))


## The slider moved: the brand's fin of the new depth is chosen at once.
func _on_fin_depth_changed(value: float, brand: Brand) -> void:
	var fin: GearItem = GearCatalogue.fin_of(brand.slug, roundi(value))
	if fin == null:
		return
	choose(fin)
	_show_fin_card(brand, roundi(value))


## The brand's fin of this depth as a card (lit when it is the chosen fin), and its depth and area
## beside the slider: "38 cm  ·  311 cm²".
func _show_fin_card(brand: Brand, depth: int) -> void:
	var fin: GearItem = GearCatalogue.fin_of(brand.slug, depth)
	if fin == null:
		return
	for child: Node in _fin_card_place.get_children():
		_fin_card_place.remove_child(child)
		child.queue_free()
	var details: String = "%s  ·  %s" % [fin.line_name(), fin.wind_text()]
	var card: Button = _make_card(fin.title(), details, fin.description, null, brand, ITEM_CARD_SIZE)
	card.name = "Item_" + fin.id()
	card.button_pressed = fin.id() == chosen().fin.id()
	card.pressed.connect(func() -> void:
		var wanted: GearItem = GearCatalogue.fin_of(brand.slug, roundi(_fin_slider.value))
		if wanted != null:
			choose(wanted)
			_show_fin_card(brand, roundi(_fin_slider.value)))
	_fin_card_place.add_child(card)
	_fin_value.text = "%d cm  ·  %d cm²" % [depth, roundi((fin.config as FinConfig).area_m2 * 10000.0)]


## A small orange triangle under the slider's track at the recommended depth (drawn on the slider,
## where its grabber's middle would be at that value).
func _draw_recommended_mark(slider: HSlider, depth: int) -> void:
	var fraction: float = (depth - slider.min_value) / (slider.max_value - slider.min_value)
	var grabber: Texture2D = slider.get_theme_icon("grabber")
	var half: float = grabber.get_width() / 2.0 if grabber != null else 0.0
	var x: float = half + fraction * (slider.size.x - 2.0 * half)
	var y: float = slider.size.y
	slider.draw_colored_polygon(PackedVector2Array([Vector2(x, y - 6.0), Vector2(x - 7.0, y + 5.0), Vector2(x + 7.0, y + 5.0)]),
		RECOMMENDED_MARK)


## The brand's logo (on a thin light frame, so a navy plate shows on the menu's dark blue), its
## name and its tagline.
func _brand_header(brand: Brand) -> HBoxContainer:
	var header: HBoxContainer = HBoxContainer.new()
	header.add_theme_constant_override("separation", 14)
	var frame: PanelContainer = PanelContainer.new()
	var border: StyleBoxFlat = StyleBoxFlat.new()
	border.bg_color = brand.primary
	border.set_border_width_all(1)
	border.border_color = Color(1.0, 1.0, 1.0, 0.45)
	border.set_corner_radius_all(8)
	border.set_content_margin_all(2.0)
	frame.add_theme_stylebox_override("panel", border)
	var logo: TextureRect = TextureRect.new()
	logo.texture = brand.logo
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.custom_minimum_size = Vector2(LOGO_SIZE, LOGO_SIZE)
	frame.add_child(logo)
	header.add_child(frame)
	var lines: VBoxContainer = VBoxContainer.new()
	lines.alignment = BoxContainer.ALIGNMENT_CENTER
	lines.add_theme_constant_override("separation", 0)
	var name_label: Label = Label.new()
	name_label.text = brand.name
	name_label.theme_type_variation = &"SectionLabel"
	lines.add_child(name_label)
	var tagline: Label = Label.new()
	tagline.text = brand.tagline
	tagline.theme_type_variation = &"HintLabel"
	lines.add_child(tagline)
	header.add_child(lines)
	return header


## A card: a toggle button with the brand's two colours as a stripe down its left edge (a navy or
## black primary alone would vanish on the menu's dark blue), an optional picture, a title and one
## or two lines of text. The theme paints a chosen card orange; its text then turns dark.
func _make_card(title: String, details: String, text: String, picture: Texture2D, brand: Brand, card_size: Vector2) -> Button:
	var card: Button = Button.new()
	card.toggle_mode = true
	card.custom_minimum_size = card_size
	card.mouse_entered.connect(card.grab_focus)
	_add_stripe(card, brand.primary, 7.0)
	_add_stripe(card, brand.secondary, 12.0)
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_bottom", 4)
	card.add_child(margin)
	var row: HBoxContainer = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 10)
	margin.add_child(row)
	if picture != null:
		var mark: TextureRect = TextureRect.new()
		mark.texture = picture
		mark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		mark.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		mark.custom_minimum_size = Vector2(MARK_SIZE, MARK_SIZE)
		mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(mark)
	var lines: VBoxContainer = VBoxContainer.new()
	lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lines.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lines.alignment = BoxContainer.ALIGNMENT_CENTER
	lines.add_theme_constant_override("separation", 0)
	row.add_child(lines)
	var labels: Array[Label] = []
	for part: Array in [[title, &"CardTitleLabel"], [details, &"CardTextLabel"], [text, &"CardTextLabel"]]:
		if (part[0] as String).is_empty():
			continue
		var label: Label = Label.new()
		label.text = part[0]
		label.theme_type_variation = part[1]
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lines.add_child(label)
		labels.append(label)
	card.toggled.connect(_paint_card.bind(labels))
	return card


## A chosen card's text turns dark on its orange; the others keep the theme's colours.
func _paint_card(chosen_now: bool, labels: Array[Label]) -> void:
	for label: Label in labels:
		if chosen_now:
			label.add_theme_color_override("font_color", CHOSEN_TEXT)
		else:
			label.remove_theme_color_override("font_color")


## A colour band down a card's left edge, `from_x` px in.
func _add_stripe(card: Button, colour: Color, from_x: float) -> void:
	var stripe: ColorRect = ColorRect.new()
	stripe.color = colour
	stripe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stripe.anchor_bottom = 1.0
	stripe.offset_left = from_x
	stripe.offset_right = from_x + 5.0
	stripe.offset_top = 10.0
	stripe.offset_bottom = -10.0
	card.add_child(stripe)


func _flow() -> HFlowContainer:
	var flow: HFlowContainer = HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 10)
	flow.add_theme_constant_override("v_separation", 10)
	return flow


func _small_title(text: String) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.theme_type_variation = &"HintLabel"
	return label


## The tabs' order: Board, Sail, Fin.
static func _kind_of_tab(tab: int) -> GearItem.Kind:
	match tab:
		1:
			return GearItem.Kind.SAIL
		2:
			return GearItem.Kind.FIN
	return GearItem.Kind.BOARD


static func _tab_of_kind(kind: GearItem.Kind) -> int:
	match kind:
		GearItem.Kind.SAIL:
			return 1
		GearItem.Kind.FIN:
			return 2
	return 0


func _on_tab_changed(tab: int) -> void:
	_aim_camera(tab)
	_show_preview_name()
	_note.text = NOTE + (PH14_NOTE if tab == RIG_TAB else (FIN_NOTE if tab == FIN_TAB else ""))


# ---------------------------------------------------------------- the choice and the preview

## The chosen gear's names at the top, and the preview built from it.
func _show_choice() -> void:
	_sailing.text = "You sail:  " + chosen().names_line()
	_build_rig()
	_on_tab_changed(_tabs.current_tab)


## Under the preview: the current tab's chosen item and its main numbers.
func _show_preview_name() -> void:
	var item: GearItem = chosen().item(_kind_of_tab(_tabs.current_tab))
	_preview_name.text = "%s\n%s" % [item.full_name(), gear_numbers(item)]


## An item's main numbers, as the simulation sails them.
static func gear_numbers(item: GearItem) -> String:
	match item.kind:
		GearItem.Kind.SAIL:
			var sail: SailConfig = item.config as SailConfig
			return "luff %.2f m  ·  boom %.2f m  ·  mast %.2f m" % [sail.luff_m, sail.boom_m, sail.mast_m]
		GearItem.Kind.FIN:
			var fin: FinConfig = item.config as FinConfig
			return "%.0f cm deep  ·  %.0f cm²" % [fin.span_m * 100.0, fin.area_m2 * 10000.0]
	var board: BoardConfig = item.config as BoardConfig
	return "%.2f x %.2f m  ·  %.0f L  ·  %.1f kg" % [board.length_m, board.width_m, board.volume_m3 * 1000.0, board.mass_kg]


## The preview's little world: a light from the front, a softer one from behind, an even ambient
## light, no sky (the page's panel shows through), the camera and the turning stand for the rig.
func _build_preview_world() -> void:
	var environment: Environment = Environment.new()
	environment.background_mode = Environment.BG_CLEAR_COLOR
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.72, 0.8, 0.9)
	environment.ambient_light_energy = 0.8
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world: WorldEnvironment = WorldEnvironment.new()
	world.environment = environment
	_viewport.add_child(world)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35.0, 30.0, 0.0)
	sun.light_energy = 1.3
	_viewport.add_child(sun)
	var back_light: DirectionalLight3D = DirectionalLight3D.new()
	back_light.rotation_degrees = Vector3(-20.0, -150.0, 0.0)
	back_light.light_energy = 0.45
	_viewport.add_child(back_light)
	_camera = Camera3D.new()
	_viewport.add_child(_camera)
	_camera.current = true
	_pivot = Node3D.new()
	_pivot.name = "Stand"
	_viewport.add_child(_pivot)


## The chosen board, sail and fin as the sailing scene shows them, the sail sheeted in on the
## starboard tack (the boom to starboard, the mast raked back a little).
func _build_rig() -> void:
	if _pivot == null:
		return
	if _rig != null:
		# Freed at once: nothing else holds it, and the new one takes its name.
		_pivot.remove_child(_rig)
		_rig.free()
	var choice: GearChoice = chosen()
	_rig = RigVisuals.new()
	_rig.name = "Rig"
	_pivot.add_child(_rig)
	_rig.build(choice.board.config as BoardConfig, choice.sail.config as SailConfig, choice.fin.config as FinConfig, choice)
	var mast_dir: Vector3 = Vector3(0.0, 1.0, 0.12).normalized()
	var boom_dir: Vector3 = Vector3(0.35, 0.0, 1.0)
	boom_dir = (boom_dir - mast_dir * boom_dir.dot(mast_dir)).normalized()
	_rig.pose_sailing(mast_dir, boom_dir)


## The preview's camera for a tab (SHOTS), and the gear posed for it (_pose_for_tab()).
func _aim_camera(tab: int) -> void:
	if _camera == null:
		return
	var shot: Array = SHOTS[clampi(tab, 0, SHOTS.size() - 1)]
	_camera.fov = shot[2]
	_camera.look_at_from_position(shot[0], shot[1])
	_pose_for_tab(tab)


## What the preview shows on a tab: the whole rig as it sails on the Sail tab; on the Board tab the
## board alone stood on its tail (turned 90 degrees about its width: the nose up, the deck toward
## the camera); on the Fin tab the board alone upside down (turned 180 degrees about its length, the
## fin up), moved so the stand turns about the fin's root.
func _pose_for_tab(tab: int) -> void:
	if _rig == null:
		return
	var whole_rig: bool = tab == RIG_TAB
	for part: String in ["Mast", "Sail"]:
		(_rig.get_node(part) as Node3D).visible = whole_rig
	_rig.position = Vector3.ZERO
	if whole_rig:
		_rig.rotation = Vector3.ZERO
	elif tab == BOARD_TAB:
		_rig.rotation = Vector3(deg_to_rad(90.0), 0.0, 0.0)
	else:
		_rig.rotation = Vector3(0.0, 0.0, deg_to_rad(180.0))
		var fin_root: Vector3 = (chosen().fin.config as FinConfig).root_local
		_rig.position = Vector3(fin_root.x, 0.0, -fin_root.z)


## The rig in the preview, for tests.
func preview_rig() -> RigVisuals:
	return _rig
