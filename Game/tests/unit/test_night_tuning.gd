extends GutTest
## The night training's set (7 November 2026): on the player's board by the setting, never on an AI
## board's fresh controller, and switched off it gives the code's own numbers back.


func test_the_set_goes_on_and_off_again() -> void:
	var fresh: PlayerController = PlayerController.new()
	var controller: PlayerController = PlayerController.new()
	controller.use_night_tuning(true)
	for field: String in PlayerController.NIGHT_TUNING:
		assert_almost_eq(float(controller.get(field)), PlayerController.NIGHT_TUNING[field], 1e-6, field + " tuned")
	controller.use_night_tuning(false)
	for field: String in PlayerController.NIGHT_TUNING:
		assert_almost_eq(float(controller.get(field)), float(fresh.get(field)), 1e-6, field + " back to the code's own")


func test_the_setting_is_on_by_default_and_the_ai_keeps_its_numbers() -> void:
	assert_true(SettingsValues.new().night_tuning, "on for the player's board by default")
	var ai: PlayerController = PlayerController.new()
	assert_almost_eq(ai.airborne_alpha_deg, 6.0, 1e-6, "a fresh controller (an AI board's) keeps the lake training's 6 degrees")
