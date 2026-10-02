class_name PlayerController
extends RefCounted
## Turns key presses into the three numbers the simulation understands: sheet, rake and
## lean (PHYSICS_SPEC.md section 10). Nothing here touches the physics; it only moves the
## sailor's hands and feet, at the speed a person can.
##
## Beginner mode: A/D turn the board left and right on the screen, whichever tack you are
## on and however fast you go. The keys ask for a turn rate, and a feedback loop on the
## measured yaw rate finds the helm that gives it, the way a sailor steers by feel: rig
## back or forward, rig tilted toward the outside of the turn, weight on the inside rail,
## all together (see Helm). With no key pressed the loop holds the heading, as a sailor does
## without thinking (a board left alone rounds up into the wind). Balance is automatic.
## Space tacks or gybes for you.
## Advanced mode: Q/E rake the rig forward and back, Left/Right tilt it sideways and A/D
## move the sailor's weight to port and starboard, all raw, on top of the balance reflex.
## Space still helps with the tack.
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
var lean_rate_per_s: float = 2.0
## Beginner steering: the turn rate a held key asks for, the rate the heading hold asks for
## per degree of error (up to the same limit), the loop gains (helm per degree per second
## of rate error now, and per degree of accumulated error: the trim that holds a course,
## which at planing speed is a lot of rake back), the share of weight put on the inside
## rail, and how fast the sailor moves the helm.
var turn_rate_dps: float = 30.0
var hold_rate_per_deg: float = 1.0
var rate_gain: float = 0.01
var rate_integral_gain: float = 0.05
var lean_share: float = 0.4
var helm_rate_per_s: float = 2.0
## The last helm, -1 (full left) to +1 (full right), for the HUD.
var helm_right: float = 0.0
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

## Beginner mode holds the heading when no steering key is pressed.
var hold_heading: bool = true
var _helm_trim: float = 0.0
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

	# Steering.
	var steer_key: float = _axis("steer_right", "steer_left")  # +1 = turn right on the screen
	var tilt_key: float = _axis("tilt_right", "tilt_left")  # +1 = mast top toward starboard
	var rake_key: float = _axis("rake_back", "rake_forward")  # +1 = rig back
	if manoeuvre != Manoeuvre.NONE:
		var turn: float = _manoeuvre_turn(telemetry, dt)
		Helm.steer(controls, turn, tack_sign(telemetry), lean_share, dt, helm_rate_per_s)
		helm_right = turn
	elif mode == Mode.BEGINNER:
		_steer_beginner(telemetry, controls, clampf(steer_key + tilt_key, -1.0, 1.0), dt)
	else:
		# Raw controls: rake comes back to neutral when Q/E are released, like the others.
		controls.rake = move_toward(controls.rake, rake_key, rake_rate_per_s * dt)
		controls.rig_tilt = move_toward(controls.rig_tilt, tilt_key, helm_rate_per_s * dt)
		controls.lean = move_toward(controls.lean, steer_key, lean_rate_per_s * dt)
		helm_right = 0.0
		_heading_held = false
	controls.balance_reflex = true


## The beginner's turn-rate loop. turn_key asks for a rate; without a key the heading hold
## asks for the rate that brings the heading back. The error against the measured yaw rate
## moves the helm now (proportional) and slowly shifts the trim (integral), so the loop
## finds by itself how much helm this speed and course need, in either direction.
func _steer_beginner(telemetry: Telemetry, controls: SimControls, turn_key: float, dt: float) -> void:
	var wanted_rate_dps: float = 0.0
	if turn_key != 0.0:
		wanted_rate_dps = turn_key * turn_rate_dps
		_heading_held = false
	elif hold_heading:
		if not _heading_held:
			_held_heading_deg = telemetry.heading_deg
			_heading_held = true
		var turn_right_deg: float = wrapf(_held_heading_deg - telemetry.heading_deg, -180.0, 180.0)
		wanted_rate_dps = clampf(hold_rate_per_deg * turn_right_deg, -turn_rate_dps, turn_rate_dps)
	# A positive yaw rate turns the bow to port, so the rate of turning right is its negative.
	var error_dps: float = wanted_rate_dps - (-telemetry.yaw_rate_dps)
	_helm_trim = clampf(_helm_trim + rate_integral_gain * error_dps * dt, -1.0, 1.0)
	helm_right = clampf(_helm_trim + rate_gain * error_dps, -1.0, 1.0)
	Helm.steer(controls, helm_right, tack_sign(telemetry), lean_share, dt, helm_rate_per_s)


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
	_helm_trim = 0.0
	helm_right = 0.0
	controls.sheet = 0.0
	controls.rake = 0.0
	controls.rig_tilt = 0.0
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


## A tack is one continuous turn toward the wind and through it (a right turn from
## starboard tack), a gybe one continuous turn away from the wind and through it. The
## helm keeps the turn going; the rake flips by itself when the tack changes (see Helm).
## Returns the turn, -1 to +1, or 0 when the manoeuvre is over.
func _manoeuvre_turn(telemetry: Telemetry, dt: float) -> float:
	_manoeuvre_timer_s += dt
	if _manoeuvre_timer_s > manoeuvre_timeout_s:
		manoeuvre = Manoeuvre.NONE
		_heading_held = false
		return 0.0
	var twa: float = absf(telemetry.twa_deg)
	var on_new_tack: bool = tack_sign(telemetry) == -_tack_sign_at_start
	var toward_the_wind: float = _tack_sign_at_start  # a right turn heads up on starboard tack
	match manoeuvre:
		Manoeuvre.TACK_HEADING_UP:
			if on_new_tack and twa > 5.0:
				manoeuvre = Manoeuvre.TACK_BEARING_AWAY
			return toward_the_wind
		Manoeuvre.TACK_BEARING_AWAY:
			if on_new_tack and twa > 60.0:
				manoeuvre = Manoeuvre.NONE
				_heading_held = false
			return toward_the_wind
		Manoeuvre.GYBE_BEARING_AWAY:
			if on_new_tack and twa < 175.0:
				manoeuvre = Manoeuvre.GYBE_HEADING_UP
			return -toward_the_wind
		Manoeuvre.GYBE_HEADING_UP:
			if on_new_tack and twa < 120.0:
				manoeuvre = Manoeuvre.NONE
				_heading_held = false
			return -toward_the_wind
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
