extends GutTest
## The HUD (ui/hud.gd) shows what the simulation's telemetry says.


func test_fin_line_shows_the_load_the_bend_and_the_push_up() -> void:
	var hud: Hud = Hud.new()
	add_child_autofree(hud)
	var t: Telemetry = Telemetry.new()
	t.fin_lift_n = 484.0
	t.fin_load_share = 0.18
	t.fin_bend_tip_deg = 14.0
	t.fin_up_n = 76.0
	hud.update_from(t, PlayerController.new(), "stern", true)
	var fin_line: String = ""
	for line: String in hud._detail.text.split("\n"):
		if line.begins_with("fin "):
			fin_line = line
	assert_string_contains(fin_line, "lift   484 N")
	assert_string_contains(fin_line, "load  18 % of stall")
	assert_string_contains(fin_line, "bend 14.0 deg")
	assert_string_contains(fin_line, "up   76 N")
