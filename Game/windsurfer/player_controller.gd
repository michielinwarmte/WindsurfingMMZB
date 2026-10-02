class_name PlayerController
extends RefCounted
## Turns key presses into the three numbers the simulation understands: sheet, rake and
## lean (PHYSICS_SPEC.md section 10). Nothing here touches the physics; it only moves the
## sailor's hands and feet, at the speed a person can.
##
## Beginner mode: A/D turn the board left and right on the screen, whichever tack you are
## on. The controller works out whether that means raking the rig back (head up) or
## forward (bear away). With no key pressed it holds the heading with the rig, as a sailor
## does without thinking (a board left alone rounds up into the wind). Balance is
## automatic. Space tacks or gybes for you.
## Advanced mode: Q/E rake the rig forward and back as a real sailor does, A/D move the
## sailor's weight to port and starboard on top of the automatic balance reflex. Space
## still helps with the tack.
## W/S sheet in and out in both modes; T toggles an automatic sheet, which is on by default
## in beginner mode (W/S then override it for a few seconds). In beginner mode the sailor
## also eases the sheet by themselves when the pull is more than they can hold, which is
## what every sailor does before a catapult. Tab switches modes.

enum Mode { BEGINNER, ADVANCED }
enum Manoeuvre { NONE, TACK_HEADING_UP, TACK_BEARING_AWAY, GYBE_BEARING_AWAY, GYBE_HEADING_UP }

var mode: Mode = Mode.BEGINNER
var auto_sheet: bool = true
var manoeuvre: Manoeuvre = Manoeuvre.NONE
## The sheet the player (or the auto-sheet) asks for, before the overpower ease.
var wanted_sheet: float = 0.0
## How far the sailor has eased the sheet beyond the player's wish because the pull was
## too much, in sheet units.
var ease: float = 0.0

## How fast the sailor can sheet (full range per second), swing the rig (full rake per
## second), let it come back to neutral, and shift weight (full lean per second).
var sheet_rate_per_s: float = 0.6
var rake_rate_per_s: float = 2.0
var rake_return_rate_per_s: float = 2.0
var lean_rate_per_s: float = 2.0
## Beginner steering is speed-sensitive, like a car's: above this speed the rake that A/D
## command shrinks in proportion, because a full swing of the rig at planing speed turns
## the board faster than the fin can hold (a spin-out). Advanced mode has the full swing.
var full_rake_below_ms: float = 4.0
var min_rake_share: float = 0.3
## A manoeuvre that takes longer than this is abandoned (the rig goes back to neutral).
var manoeuvre_timeout_s: float = 10.0
## After a sheet key the auto-sheet stays out of the way for this long.
var manual_sheet_hold_s: float = 3.0
## Beginner mode: the sailor eases when more than this share of the hike is used, or the
## board heels more than this to leeward; the ease comes on and goes away at these rates.
var ease_when_overpowered: bool = true
var ease_hike_share: float = 0.85
var ease_heel_deg: float = 10.0
var ease_rate_per_s: float = 1.0
var ease_recovery_rate_per_s: float = 0.4

## Beginner mode holds the heading when no steering key is pressed: rake per degree of
## heading error, and per degree per second of yaw rate against overshoot.
var hold_heading: bool = true
var hold_gain_per_deg: float = 0.08
var hold_yaw_damping: float = 0.02
## The autopilot that trims the sheet when auto_sheet is on. Give it the simulation's sail
## (auto_sheet_pilot.sail) and it sheets for the most drive instead of a fixed angle.
var auto_sheet_pilot: Autopilot = Autopilot.new()

var _manual_sheet_timer_s: float = 0.0
var _scratch: SimControls = SimControls.new()
var _held_heading_deg: float = 0.0
var _heading_held: bool = false

var _manoeuvre_timer_s: float = 0.0
var _tack_sign_at_start: float = 0.0
## Which of the "press once" keys were down at the last update, for our own edge detection
## (the controller runs in the physics tick, where Godot's just-pressed flag can repeat).
var _was_down: Dictionary[String, bool] = {}


func _init() -> void:
	auto_sheet_pilot.hold_course = false
	auto_sheet_pilot.trim_sheet = true


## Reads the keys and writes controls.sheet, controls.rake and controls.lean.
func update(telemetry: Telemetry, controls: SimControls, dt: float) -> void:
	if _just_pressed("toggle_mode"):
		set_mode(Mode.ADVANCED if mode == Mode.BEGINNER else Mode.BEGINNER)
	if _just_pressed("toggle_autosheet"):
		auto_sheet = not auto_sheet
	if _just_pressed("tack") and manoeuvre == Manoeuvre.NONE:
		_start_manoeuvre(telemetry)

	# Sheet: W pulls the boom in, S lets it out. With the auto-sheet on, the keys take over
	# for a few seconds and then the automatic trim resumes.
	var sheet_key: float = _axis("sheet_in", "sheet_out")
	if sheet_key != 0.0:
		_manual_sheet_timer_s = manual_sheet_hold_s
		wanted_sheet = clampf(wanted_sheet + sheet_key * sheet_rate_per_s * dt, 0.0, 1.0)
	elif auto_sheet and _manual_sheet_timer_s <= 0.0:
		_scratch.sheet = wanted_sheet
		auto_sheet_pilot.update(telemetry, _scratch, dt)
		wanted_sheet = _scratch.sheet
	_manual_sheet_timer_s = maxf(_manual_sheet_timer_s - dt, 0.0)

	# Overpowered: the sailor lets the sail out rather than being pulled over it.
	if ease_when_overpowered and mode == Mode.BEGINNER:
		var leeward_heel_deg: float = -telemetry.heel_deg * tack_sign(telemetry)
		var overpowered: bool = absf(telemetry.lean) > ease_hike_share or leeward_heel_deg > ease_heel_deg
		var rate: float = ease_rate_per_s if overpowered else ease_recovery_rate_per_s
		ease = move_toward(ease, 1.0 if overpowered else 0.0, rate * dt)
	else:
		ease = 0.0
	controls.sheet = clampf(wanted_sheet - ease, 0.0, 1.0)

	# Rake: positive = rig back = head up (toward the wind), on either tack.
	var steer_key: float = _axis("steer_right", "steer_left")  # +1 = turn right on the screen
	var rake_key: float = _axis("rake_back", "rake_forward")  # +1 = rig back
	var rake_command: float = 0.0
	if manoeuvre != Manoeuvre.NONE:
		rake_command = _manoeuvre_rake(telemetry, dt)
	elif mode == Mode.BEGINNER:
		var authority: float = clampf(full_rake_below_ms / maxf(telemetry.speed_ms, 0.1), min_rake_share, 1.0)
		if rake_key != 0.0:
			rake_command = rake_key
			_heading_held = false
		elif steer_key != 0.0:
			rake_command = steer_key * tack_sign(telemetry) * authority
			_heading_held = false
		elif hold_heading:
			rake_command = _heading_hold_rake(telemetry)
	else:
		rake_command = rake_key
		_heading_held = false
	var rate: float = rake_rate_per_s if rake_command != 0.0 else rake_return_rate_per_s
	controls.rake = move_toward(controls.rake, rake_command, rate * dt)

	# Weight: in advanced mode A/D move the sailor to port and starboard (right on the
	# screen is starboard, because the follow camera looks forward); the balance reflex
	# adds what is needed to stay upright in both modes.
	var lean_command: float = steer_key if mode == Mode.ADVANCED else 0.0
	controls.lean = move_toward(controls.lean, lean_command, lean_rate_per_s * dt)
	controls.balance_reflex = true


## The rake that brings the board back to the heading it had when the keys were released.
## A right turn is heading up on starboard tack and bearing away on port tack, hence the
## tack sign; the yaw-rate term stops it overshooting.
func _heading_hold_rake(telemetry: Telemetry) -> float:
	if not _heading_held:
		_held_heading_deg = telemetry.heading_deg
		_heading_held = true
	var turn_right_deg: float = wrapf(_held_heading_deg - telemetry.heading_deg, -180.0, 180.0)
	var heading_up_rate: float = -telemetry.yaw_rate_dps * tack_sign(telemetry)
	return clampf(hold_gain_per_deg * turn_right_deg * tack_sign(telemetry) - hold_yaw_damping * heading_up_rate, -1.0, 1.0)


## +1 when the wind comes from starboard (starboard tack), -1 from port. Heading up is a
## right turn on starboard tack and a left turn on port tack, which is why the beginner
## steering needs it (section 10, formula 2a).
static func tack_sign(telemetry: Telemetry) -> float:
	return 1.0 if telemetry.twa_deg >= 0.0 else -1.0


## Switches modes; the auto-sheet follows the mode's default (on for beginners).
func set_mode(new_mode: Mode) -> void:
	mode = new_mode
	auto_sheet = mode == Mode.BEGINNER


## Forgets the sheet and the manoeuvre (after a reset or a waterstart).
func reset_controls(controls: SimControls) -> void:
	wanted_sheet = 0.0
	ease = 0.0
	manoeuvre = Manoeuvre.NONE
	_manual_sheet_timer_s = 0.0
	_heading_held = false
	controls.sheet = 0.0
	controls.rake = 0.0
	controls.lean = 0.0


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
		_heading_held = false
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
				_heading_held = false
			return -1.0
		Manoeuvre.GYBE_BEARING_AWAY:
			if on_new_tack and twa < 175.0:
				manoeuvre = Manoeuvre.GYBE_HEADING_UP
			return -1.0
		Manoeuvre.GYBE_HEADING_UP:
			if on_new_tack and twa < 120.0:
				manoeuvre = Manoeuvre.NONE
				_heading_held = false
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
