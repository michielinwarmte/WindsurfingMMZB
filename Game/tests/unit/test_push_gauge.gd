extends GutTest
## The push gauge (ui/push_gauge.gd): Michiel's ladder in words and colours, the half circle, and
## the HUD showing it for a board with a slider only.


func test_the_ladder_words_follow_the_push_curve() -> void:
	var curve: PushCurveConfig = PushDial.default_curve()
	assert_eq(Array(PushGauge.STEP_LEVELS), Array(curve.levels), "the gauge's steps are the ladder's levels")
	assert_eq(PushGauge.word_for(0.0), "sail let fly")
	assert_eq(PushGauge.word_for(0.5), "cruising")
	assert_eq(PushGauge.word_for(0.75), "planing, little risk", "the game's start level")
	assert_eq(PushGauge.word_for(0.84), "planing, little risk")
	assert_eq(PushGauge.word_for(0.85), "more speed, a little risk")
	assert_eq(PushGauge.word_for(1.0), "most speed, crash likely")


func test_the_colours_turn_red_at_the_top() -> void:
	assert_eq(PushGauge.colour_for(0.8), PushGauge.ZONE_COLORS[3], "green while planing with little risk")
	assert_eq(PushGauge.colour_for(0.97), PushGauge.ZONE_COLORS[5])
	assert_eq(PushGauge.colour_for(1.0), PushGauge.ZONE_COLORS[5], "100 % is in the last zone")


func test_the_half_circle_runs_from_the_left_over_the_top() -> void:
	assert_almost_eq(PushGauge.angle_for(0.0), PI, 1e-6)
	assert_almost_eq(PushGauge.angle_for(0.5), 1.5 * PI, 1e-6, "the top of the screen (y points down)")
	assert_almost_eq(PushGauge.angle_for(1.0), TAU, 1e-6)
	assert_lt(Vector2.from_angle(PushGauge.angle_for(0.5)).y, -0.99)


func test_the_hud_shows_the_gauge_for_a_slider_only() -> void:
	var hud: Hud = Hud.new()
	add_child_autofree(hud)
	var controller: PlayerController = PlayerController.new()
	controller.push_level = 0.9
	hud.update_from(Telemetry.new(), controller, "stern", false)
	assert_true(hud._push_gauge.visible)
	assert_almost_eq(hud._push_gauge.level, 0.9, 1e-6)
	hud.update_from(Telemetry.new(), controller, "stern", true)
	assert_false(hud._push_gauge.visible, "the autopilot has no slider for the player")
	controller.push_level = NAN
	hud.update_from(Telemetry.new(), controller, "stern", false)
	assert_false(hud._push_gauge.visible)
