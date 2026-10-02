class_name PlayerController
extends RefCounted
## Turns key presses into the three numbers the simulation understands: sheet, rake and
## lean (PHYSICS_SPEC.md section 10). Nothing here touches the physics; it only moves the
## sailor's hands and feet, at the speed a person can.
##
## Beginner mode: A/D turn the board left and right on the screen, whichever tack you are
## on. The controller works out whether that means raking the rig back (head up) or
## forward (bear away). Balance is automatic. Space tacks or gybes for you.
## Advanced mode: Q/E rake the rig forward and back as a real sailor does, A/D move the
## sailor's weight to port and starboard on top of the automatic balance reflex. Space
## still helps with the tack.
## W/S sheet in and out in both modes; T toggles an automatic sheet. Tab switches modes.

enum Mode { BEGINNER, ADVANCED }
enum Manoeuvre { NONE, TACK_HEADING_UP, TACK_BEARING_AWAY, GYBE_BEARING_AWAY, GYBE_HEADING_UP }

var mode: Mode = Mode.BEGINNER
var auto_sheet: bool = false
var manoeuvre: Manoeuvre = Manoeuvre.NONE

## How fast the sailor can sheet (full range per second), swing the rig (full rake per
## second), let it come back to neutral, and shift weight (full lean per second).
var sheet_rate_per_s: float = 0.6
var rake_rate_per_s: float = 3.0
var rake_return_rate_per_s: float = 2.0
var lean_rate_per_s: float = 2.0
## A manoeuvre that takes longer than this is abandoned (the rig goes back to neutral).
var manoeuvre_timeout_s: float = 10.0

var _manoeuvre_timer_s: float = 0.0
var _tack_sign_at_start: float = 0.0
var _auto_sheet_pilot: Autopilot = Autopilot.new()
## Which of the "press once" keys were down at the last update, for our own edge detection
## (the controller runs in the physics tick, where Godot's just-pressed flag can repeat).
var _was_down: Dictionary[String, bool] = {}


func _init() -> void:
	_auto_sheet_pilot.hold_course = false
	_auto_sheet_pilot.trim_sheet = true


## Reads the keys and writes controls.sheet, controls.rake and controls.lean.
func update(telemetry: Telemetry, controls: SimControls, dt: float) -> void:
	if _just_pressed("toggle_mode"):
		mode = Mode.ADVANCED if mode == Mode.BEGINNER else Mode.BEGINNER
	if _just_pressed("toggle_autosheet"):
		auto_sheet = not auto_sheet
	if _just_pressed("tack") and manoeuvre == Manoeuvre.NONE:
		_start_manoeuvre(telemetry)

	# Sheet: W pulls the boom in, S lets it out.
	var sheet_key: float = _axis("sheet_in", "sheet_out")
	if auto_sheet and sheet_key == 0.0:
		_auto_sheet_pilot.update(telemetry, controls, dt)
	else:
		controls.sheet = clampf(controls.sheet + sheet_key * sheet_rate_per_s * dt, 0.0, 1.0)

	# Rake: positive = rig back = head up (toward the wind), on either tack.
	var steer_key: float = _axis("steer_right", "steer_left")  # +1 = turn right on the screen
	var rake_key: float = _axis("rake_back", "rake_forward")  # +1 = rig back
	var rake_command: float = 0.0
	if manoeuvre != Manoeuvre.NONE:
		rake_command = _manoeuvre_rake(telemetry, dt)
	elif mode == Mode.BEGINNER:
		rake_command = steer_key * tack_sign(telemetry)
		if rake_key != 0.0:
			rake_command = rake_key
	else:
		rake_command = rake_key
	var rate: float = rake_rate_per_s if rake_command != 0.0 else rake_return_rate_per_s
	controls.rake = move_toward(controls.rake, rake_command, rate * dt)

	# Weight: in advanced mode A/D move the sailor to port and starboard (right on the
	# screen is starboard, because the follow camera looks forward); the balance reflex
	# adds what is needed to stay upright in both modes.
	var lean_command: float = steer_key if mode == Mode.ADVANCED else 0.0
	controls.lean = move_toward(controls.lean, lean_command, lean_rate_per_s * dt)
	controls.balance_reflex = true


## +1 when the wind comes from starboard (starboard tack), -1 from port. Heading up is a
## right turn on starboard tack and a left turn on port tack, which is why the beginner
## steering needs it (section 10, formula 2a).
static func tack_sign(telemetry: Telemetry) -> float:
	return 1.0 if telemetry.twa_deg >= 0.0 else -1.0


func mode_name() -> String:
	return "Beginner" if mode == Mode.BEGINNER else "Advanced"


func manoeuvre_name() -> String:
	match manoeuvre:
		Manoeuvre.TACK_HEADING_UP, Manoeuvre.TACK_BEARING_AWAY:
			return "tacking"
		Manoeuvre.GYBE_BEARING_AWAY, Manoeuvre.GYBE_HEADING_UP:
			return "gybing"
	return ""


## Space: a tack when sailing upwind of a beam reach, a gybe when sailing downwind of it.
func _start_manoeuvre(telemetry: Telemetry) -> void:
	_tack_sign_at_start = tack_sign(telemetry)
	_manoeuvre_timer_s = 0.0
	manoeuvre = Manoeuvre.TACK_HEADING_UP if absf(telemetry.twa_deg) < 90.0 else Manoeuvre.GYBE_BEARING_AWAY


## The rig movements of a tack (head up through the wind, then bear away on the new tack)
## and a gybe (bear away through dead downwind, then head up on the new tack).
func _manoeuvre_rake(telemetry: Telemetry, dt: float) -> float:
	_manoeuvre_timer_s += dt
	if _manoeuvre_timer_s > manoeuvre_timeout_s:
		manoeuvre = Manoeuvre.NONE
		return 0.0
	var twa: float = absf(telemetry.twa_deg)
	var on_new_tack: bool = tack_sign(telemetry) == -_tack_sign_at_start
	match manoeuvre:
		Manoeuvre.TACK_HEADING_UP:
			if on_new_tack and twa > 5.0:
				manoeuvre = Manoeuvre.TACK_BEARING_AWAY
			return 1.0
		Manoeuvre.TACK_BEARING_AWAY:
			if on_new_tack and twa > 60.0:
				manoeuvre = Manoeuvre.NONE
			return -1.0
		Manoeuvre.GYBE_BEARING_AWAY:
			if on_new_tack and twa < 175.0:
				manoeuvre = Manoeuvre.GYBE_HEADING_UP
			return -1.0
		Manoeuvre.GYBE_HEADING_UP:
			if on_new_tack and twa < 120.0:
				manoeuvre = Manoeuvre.NONE
			return 1.0
	return 0.0


## +1 while the first action is held, -1 for the second, 0 for neither or both.
func _axis(positive: String, negative: String) -> float:
	var value: float = 0.0
	if Input.is_action_pressed(positive):
		value += 1.0
	if Input.is_action_pressed(negative):
		value -= 1.0
	return value


## True on the update in which the key went down, and not again until it is released.
func _just_pressed(action: String) -> bool:
	var down: bool = Input.is_action_pressed(action)
	var was_down: bool = _was_down.get(action, false)
	_was_down[action] = down
	return down and not was_down
