extends GutTest
## The body gauge (ui/body_gauge.gd): the side where the toes press, whether the body works, how the
## feet press and the board's heel, and the HUD showing it only for a player with the body on the mouse.


func test_the_rail_side_follows_the_tack_and_the_setting() -> void:
	var body: MouseBody = MouseBody.new()
	assert_eq(body.rail_side(), 0.0, "before the first tick the tack is not known")
	body.press(1.0, 2.0)
	assert_eq(body.rail_side(), -1.0, "starboard tack, as seen from behind: left puts the port (leeward) rail down")
	body.press(-1.0, 2.0)
	assert_eq(body.rail_side(), 1.0, "port tack: right")
	body.sideways = MouseBody.Sideways.RIGHT_IS_MORE_RAIL
	assert_eq(body.rail_side(), 1.0, "right is always more rail")


func test_the_status_says_when_the_body_works() -> void:
	var body: MouseBody = MouseBody.new()
	var t: Telemetry = Telemetry.new()
	t.feet_press_reach = 1.0
	body.press(1.0, 2.0)
	assert_eq(BodyGauge.status_for(body, t), "works")
	t.feet_press_reach = 0.2
	assert_eq(BodyGauge.status_for(body, t), "plane in the straps", "out of the straps or not planing: the press does not reach the board")
	body.rest()
	assert_eq(BodyGauge.status_for(body, t), "in a turn")


func test_the_gauge_shows_how_the_feet_press_and_the_leeward_heel() -> void:
	var t: Telemetry = Telemetry.new()
	t.heel_deg = -6.0
	assert_eq(BodyGauge.leeward_heel_deg(t, 1.0), 6.0, "starboard tack: the port rail down is leeward heel")
	assert_eq(BodyGauge.leeward_heel_deg(t, -1.0), -6.0, "port tack: the same heel is the windward rail down")
	assert_eq(BodyGauge.leeward_heel_deg(t, 0.0), 6.0, "before the tack is known: its size")
	assert_eq(BodyGauge.toes_word(0.4), "TOES")
	assert_eq(BodyGauge.toes_word(-0.2), "HEELS")
	var gauge: BodyGauge = BodyGauge.new()
	add_child_autofree(gauge)
	var body: MouseBody = MouseBody.new()
	body.press(1.0, 6.0)
	t.toes_share = 0.8
	t.back_foot_share = 0.9
	t.trim_deg = 2.4
	gauge.set_body(body, t)
	assert_true(gauge.visible)
	assert_eq(gauge._toes, 0.8, "the feet's roll press, as the simulation reports it")
	assert_eq(gauge._back_foot, 0.9, "the weight on the back foot")
	assert_eq(gauge._heel_deg, 6.0)


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
