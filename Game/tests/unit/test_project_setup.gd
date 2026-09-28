extends GutTest
## Checks that the project is set up the way CLAUDE.md describes.


func test_godot_version_is_4_7() -> void:
	var version: Dictionary = Engine.get_version_info()
	assert_eq(version["major"], 4, "Godot major version")
	assert_eq(version["minor"], 7, "Godot minor version (see tools/common.sh)")


func test_untyped_code_is_an_error() -> void:
	var level: int = ProjectSettings.get_setting("debug/gdscript/warnings/untyped_declaration")
	assert_eq(level, 2, "Untyped declarations must stay errors, so all code is statically typed")


func test_physics_interpolation_is_on() -> void:
	assert_true(ProjectSettings.get_setting("physics/common/physics_interpolation"))


func test_main_scene_loads() -> void:
	var main_scene_path: String = ProjectSettings.get_setting("application/run/main_scene")
	var scene: PackedScene = load(main_scene_path)
	assert_not_null(scene, "Main scene should load: " + main_scene_path)
