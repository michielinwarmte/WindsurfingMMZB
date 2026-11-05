extends GutTest
## The body gauge (ui/body_gauge.gd): the side that gives more rail, whether the body works, and the
## HUD showing it only for a player with the body on the mouse.


func test_the_rail_side_follows_the_tack_and_the_setting() -> void:
	var body: MouseBody = MouseBody.new()
	assert_eq(body.rail_side(), 0.0, "before the first tick the tack is not known")
	body.aim(2.0, 1.5, 1.0)
	assert_eq(body.rail_side(), -1.0, "starboard tack, as seen from behind: left puts the port (leeward) rail down")
	body.aim(2.0, 1.5, -1.0)
	assert_eq(body.rail_side(), 1.0, "port tack: right")
	body.sideways = MouseBody.Sideways.RIGHT_IS_MORE_RAIL
	assert_eq(body.rail_side(), 1.0, "right is always more rail")


func test_the_status_says_when_the_body_works() -> void:
	var body: MouseBody = MouseBody.new()
	var t: Telemetry = Telemetry.new()
	t.is_planing = true
	t.stance = 1.0
	body.aim(2.0, 1.5, 1.0)
	assert_eq(BodyGauge.status_for(body, t), "works")
	t.stance = 0.2
	assert_eq(BodyGauge.status_for(body, t), "plane in the straps", "out of the straps")
	t.stance = 1.0
	t.is_planing = false
	assert_eq(BodyGauge.status_for(body, t), "plane in the straps", "not planing")
	body.rest(2.0, 1.5)
	assert_eq(BodyGauge.status_for(body, t), "in a turn")


func test_the_hud_shows_the_gauge_for_the_body_only() -> void:
	var hud: Hud = Hud.new()
	add_child_autofree(hud)
	var controller: PlayerController = PlayerController.new()
	hud.update_from(Telemetry.new(), controller, "stern", false)
	assert_false(hud._body_gauge.visible, "no body on the mouse")
	controller.body = MouseBody.new()
	hud.update_from(Telemetry.new(), controller, "stern", false)
	assert_true(hud._body_gauge.visible)
	hud.update_from(Telemetry.new(), controller, "stern", true)
	assert_false(hud._body_gauge.visible, "the autopilot sails")
