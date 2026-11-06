extends GutTest
## The recovery reflex as a setting of Settings > Sailing (Max, 6 November 2026, the night's play-test:
## with the body on the mouse the autopilot "out of nowhere opens up the sail and stops" and would not
## get on the plane; the cure is the fade at low speed, test_stay_on_the_board.gd). The player's board
## gets the reflex by the setting, on by default so Max can compare; an AI board's controller keeps it.


func test_the_setting_is_on_by_default_and_round_trips() -> void:
	var values: SettingsValues = SettingsValues.new()
	assert_true(values.recovery_reflex, "on by default; it fades away at low speed")
	values.recovery_reflex = false
	var config: ConfigFile = ConfigFile.new()
	values.write_to(config)
	assert_false(config.get_value("sailing", "recovery_reflex"), "written in the sailing section")
	var read: SettingsValues = SettingsValues.new()
	read.read_from(config)
	assert_false(read.recovery_reflex, "read back")


func test_a_fresh_controller_keeps_the_reflex_for_the_ai() -> void:
	var controller: PlayerController = PlayerController.new()
	assert_true(controller.reflex_on, "the AI fleet's controllers are made without the setting and keep the reflex")
