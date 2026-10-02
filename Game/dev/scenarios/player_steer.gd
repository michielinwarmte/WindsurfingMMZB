extends SimScenario
## The beginner controller instead of the pilot: sails off by itself, then from press_from_s
## to press_until_s holds one key (steer_right by default), or presses Space once at
## space_at_s. Shows what the player gets when they try to tack or gybe.

var controller: PlayerController = PlayerController.new()
var press_action: String = "steer_right"
var press_from_s: float = 25.0
var press_until_s: float = 40.0
var space_at_s: float = -1.0
var debug_from_s: float = -1.0
var debug_until_s: float = 0.0
var _space_done: bool = false


func _init() -> void:
	super()
	start_heading_deg = 180.0
	seconds = 45.0


func setup(sim: WindsurferSim) -> void:
	controller.auto_sheet_pilot.sail = sim.sail
	var options: Dictionary[String, String] = {}
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--") and arg.contains("="):
			var parts: PackedStringArray = arg.trim_prefix("--").split("=", true, 1)
			options[parts[0]] = parts[1]
	press_action = options.get("press", press_action)
	press_from_s = options.get("from", str(press_from_s)).to_float()
	press_until_s = options.get("until", str(press_until_s)).to_float()
	space_at_s = options.get("space", str(space_at_s)).to_float()
	debug_from_s = options.get("debug_from", str(debug_from_s)).to_float()
	debug_until_s = options.get("debug_until", str(debug_until_s)).to_float()


func update(sim: WindsurferSim, dt: float) -> void:
	var t: float = sim.time_s
	if press_action != "none":
		if t >= press_from_s and t < press_until_s:
			Input.action_press(press_action)
		else:
			Input.action_release(press_action)
	if space_at_s >= 0.0 and t >= space_at_s and not _space_done:
		Input.action_press("tack")
		_space_done = true
	elif _space_done:
		Input.action_release("tack")
	controller.update(sim.telemetry, controls, dt)
	if debug_from_s >= 0.0 and t >= debug_from_s and t <= debug_until_s and fmod(t + 1e-6, 0.5) < dt:
		print("  t %.1f manoeuvre %d held %.1f wanted %.1f helm %.2f trim %.2f tack %.0f keys %.0f/%.0f" % [t, controller.manoeuvre, controller.held_heading_deg, controller.wanted_rate_dps, controller.helm_right, controller._helm_trim_up, controller.auto_sheet_pilot.tack, Input.get_action_strength("steer_left"), Input.get_action_strength("steer_right")])


func describe() -> String:
	return "beginner controller; %s from %.0f to %.0f s; space at %.0f s" % [press_action, press_from_s, press_until_s, space_at_s]
