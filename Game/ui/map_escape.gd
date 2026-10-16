extends CanvasLayer
## Esc back to the start menu from the Silvaplana scenes (the terrain view and the wind
## viewer). Those scenes belong to the map track and have no menu of their own, so this
## autoload (registered in project.godot) does it for them without changing their code: in
## those scenes only, it shows a small "Esc: menu" hint in the top right corner and
## goes back to the start menu when Esc (or the gamepad's B) is pressed and the scene did
## not use the key itself. In every other scene it does nothing.

const START_MENU_SCENE: String = "res://ui/start_menu.tscn"
const MAP_SCENES: Array[String] = [
	"res://maps/silvaplana/dev/terrain_view.tscn",
	"res://maps/silvaplana/wind_viewer.tscn",
]

var _hint: Label


func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	_hint = Label.new()
	_hint.text = "Esc: menu"
	_hint.add_theme_font_size_override("font_size", 14)
	_hint.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.75))
	_hint.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.7))
	_hint.add_theme_constant_override("outline_size", 4)
	_hint.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 10)
	_hint.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	add_child(_hint)
	get_tree().scene_changed.connect(_update_hint)
	# The first scene is not the current scene yet while the autoloads get ready.
	_update_hint.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	if _in_map_scene() and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		get_tree().paused = false
		get_tree().change_scene_to_file(START_MENU_SCENE)


func _update_hint() -> void:
	_hint.visible = _in_map_scene()


func _in_map_scene() -> bool:
	var scene: Node = get_tree().current_scene
	return scene != null and scene.scene_file_path in MAP_SCENES
