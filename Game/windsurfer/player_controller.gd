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
## The sheet the player (or the auto-sheet) asks for, before the overpower ease, and how
## far the boom is pushed across the centreline beyond it (W held past fully sheeted).
var wanted_sheet: float = 0.0
var wanted_across: float = 0.0
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
## Heading up is slower at speed: the board turning toward the wind must be banked to
## windward against the centripetal force, with the hike that the sail already uses, so the
## rate is held to head_up_rate_budget over the speed (at least head_up_rate_min).
var head_up_rate_budget_dps_ms: float = 100.0
var head_up_rate_min_dps: float = 12.0
var hold_rate_per_deg: float = 0.8
var hold_rate_limit_dps: float = 20.0
## When the hold re-arms the board may still be swinging; the held heading is set a little
## ahead (at most hold_lead_max_deg), where the board will be once it has settled, so the
## helm is not slammed back.
var hold_lead_s: float = 0.3
var hold_lead_max_deg: float = 10.0
var rate_gain: float = 0.01
var rate_integral_gain: float = 0.02
## A gybe is a carve: the sailor banks the board into the turn and the rig follows, at
## gybe_rate_dps. A tack is carved up to the wind at tack_rate_dps, then pivoted through it
## with the sailor standing over the board at the mast and no weight on a rail (a board
## spun on its rail skids and trips), the sail backed.
var gybe_rate_dps: float = 30.0
var pivot_within_deg: float = 30.0
var tack_rate_dps: float = 15.0
## The turn rate a full lean on a rail is sized for (the sim banks the board for a
## coordinated turn at lean times this rate: SailorConfig.carve_rate_dps). The rail asked
## for a wanted rate is rate / carve_rate_dps; the rig does the rest.
var carve_rate_dps: float = 57.0
## After a manoeuvre the board is left to straighten by itself (rig neutral, weight off
## the rails) until it turns slower than this; only then does the heading hold take over.
## A hold that grabbed a board still carving at 60 degrees per second would throw the
## rig the other way and the sailor off.
var settle_rate_dps: float = 15.0
var _settling: bool = false
## Space tacks from a beam reach and anything closer to the wind, gybes from further off.
var tack_up_to_twa_deg: float = 100.0
## The angle of attack the sail is eased to through a gybe, and how fast the full trim
## comes back afterwards (degrees of angle of attack per second).
var gybe_entry_alpha_deg: float = 8.0
var alpha_cap_return_dps: float = 10.0
var _alpha_cap_deg: float = 90.0
var helm_rate_per_s: float = 2.0
## The last helm, -1 (full left) to +1 (full right), the rate the loop asked for and the
## heading it holds, for the HUD and for debugging.
var helm_right: float = 0.0
## Which way the bow is wanted this frame (+1 right, -1 left, 0 none), for the pilot.
var _turn_wanted: float = 0.0
var wanted_rate_dps: float = 0.0
var held_heading_deg: float = -1.0
## A manoeuvre that takes longer than this is abandoned (the rig goes back to neutral).
## A slow tack from a standstill can take a while.
var manoeuvre_timeout_s: float = 20.0
## After a sheet key the auto-sheet stays out of the way for this long.
var manual_sheet_hold_s: float = 3.0
## Beginner mode: the sailor eases when more than this share of the hike is used, or the
## board heels more than this to leeward; the ease comes on and goes away at these rates.
var ease_when_overpowered: bool = true
## This only acts while the beginner sheets by hand: with the auto-sheet on, the pilot's
## gradual depowering does it, and an on-off ease on top of that pumps the sail.
var ease_hike_share: float = 0.85
var ease_heel_deg: float = 10.0
var ease_rate_per_s: float = 1.0
var ease_recovery_rate_per_s: float = 0.8

## Beginner mode holds the heading when no steering key is pressed.
var hold_heading: bool = true
## The trim, kept as "heading up" so that it stays right when the tack changes.
var _helm_trim_up: float = 0.0
## The autopilot that trims the sheet when auto_sheet is on. Give it the simulation's sail
## (auto_sheet_pilot.sail) and it sheets for the most drive instead of a fixed angle.
var auto_sheet_pilot: Autopilot = Autopilot.new()

var _manual_sheet_timer_s: float = 0.0
var _scratch: SimControls = SimControls.new()
var _held_heading_deg: float = 0.0
var _heading_held: bool = false
var _last_sail_side: int = 0

var _manoeuvre_timer_s: float = 0.0
var _tack_sign_at_start: float = 0.0
## Which of the "press once" keys were down at the last update, for our own edge detection
## (the controller runs in the physics tick, where Godot's just-pressed flag can repeat).
var _was_down: Dictionary[String, bool] = {}


var _sail: SailModel = null


func _init() -> void:
	auto_sheet_pilot.hold_course = false
	auto_sheet_pilot.trim_sheet = true


## Gives the controller the simulation's sail, so the auto-sheet trims for the most drive.
func set_sail(sail: SailModel) -> void:
	_sail = sail
	auto_sheet_pilot.sail = sail


## Reads the keys and writes the controls: sheet, boom across, rake, rig tilt and lean.
func update(telemetry: Telemetry, controls: SimControls, dt: float) -> void:
	auto_sheet_pilot.update_tack(telemetry)
	if telemetry.sail_side != _last_sail_side:
		if _last_sail_side != 0:
			# The trim is kept as "heading up". A turn that goes through the wind keeps its
			# direction, which on the new tack is the opposite in those terms.
			if manoeuvre != Manoeuvre.NONE or absf(wanted_rate_dps) > 5.0:
				_helm_trim_up = -_helm_trim_up
			# The rig flip: the sailor sheets in on the new side and the rig arrives where
			# the helm wants it (forward, to bear away on the new tack), in the same swing.
			if wanted_across > 0.0:
				_scratch.sheet = wanted_sheet
				_scratch.boom_across = wanted_across
				Autopilot.carry_boom_across_the_flip(_scratch, auto_sheet_pilot.sheet_angle_in_deg, auto_sheet_pilot.sheet_angle_out_deg, auto_sheet_pilot.boom_across_max_deg)
				wanted_sheet = _scratch.sheet
				wanted_across = _scratch.boom_across
			controls.rake = clampf(helm_right * auto_sheet_pilot.tack, -1.0, 1.0)
		_last_sail_side = telemetry.sail_side
	if _just_pressed("toggle_mode"):
		set_mode(Mode.ADVANCED if mode == Mode.BEGINNER else Mode.BEGINNER)
	if _just_pressed("toggle_autosheet"):
		auto_sheet = not auto_sheet
	if _just_pressed("tack") and manoeuvre == Manoeuvre.NONE:
		_start_manoeuvre(telemetry)

	# Steering.
	var steer_key: float = _axis("steer_right", "steer_left")  # +1 = turn right on the screen
	var tilt_key: float = _axis("tilt_right", "tilt_left")  # +1 = mast top toward starboard
	var rake_key: float = _axis("rake_back", "rake_forward")  # +1 = rig back
	# Through a gybe the sailor keeps the sail eased: with the rig laid forward and the body
	# inside the turn, a fully powered sail would pull them over it, and coming out of the
	# turn still banked they are in no position to take the full pull. The bank does the
	# turning; the power comes back gradually once the board has settled on its course.
	var gybing: bool = manoeuvre == Manoeuvre.GYBE_BEARING_AWAY or manoeuvre == Manoeuvre.GYBE_HEADING_UP
	var cap_target: float = gybe_entry_alpha_deg if (gybing or _settling) else 90.0
	_alpha_cap_deg = minf(cap_target, _alpha_cap_deg + alpha_cap_return_dps * dt) if cap_target > _alpha_cap_deg else cap_target
	auto_sheet_pilot.max_alpha_deg = _alpha_cap_deg
	_turn_wanted = 0.0
	if manoeuvre != Manoeuvre.NONE:
		var is_gybe: bool = manoeuvre == Manoeuvre.GYBE_BEARING_AWAY or manoeuvre == Manoeuvre.GYBE_HEADING_UP
		var turn: float = _manoeuvre_turn(telemetry, dt)
		_turn_wanted = turn
		if is_gybe:
			_steer_at_rate(telemetry, controls, turn * gybe_rate_dps, true, dt)
		else:
			_steer_tack(telemetry, controls, turn, dt)
		if manoeuvre == Manoeuvre.NONE:
			_settling = true
	elif mode == Mode.BEGINNER:
		_steer_beginner(telemetry, controls, clampf(steer_key + tilt_key, -1.0, 1.0), dt)
		_turn_wanted = signf(wanted_rate_dps) if absf(wanted_rate_dps) > 5.0 else 0.0
	else:
		# Raw controls: rake comes back to neutral when Q/E are released, like the others.
		controls.rake = move_toward(controls.rake, rake_key, rake_rate_per_s * dt)
		controls.rig_tilt = move_toward(controls.rig_tilt, tilt_key, helm_rate_per_s * dt)
		controls.lean = move_toward(controls.lean, steer_key, lean_rate_per_s * dt)
		helm_right = 0.0
		_heading_held = false
	# Sheet: W pulls the boom in, S lets it out. With the auto-sheet on, the keys take over
	# for a few seconds and then the automatic trim resumes.
	var sheet_key: float = _axis("sheet_in", "sheet_out")
	if sheet_key != 0.0:
		_manual_sheet_timer_s = manual_sheet_hold_s
		# W past fully sheeted pushes the clew across the centreline; S brings it back first.
		if sheet_key > 0.0 and wanted_sheet >= 1.0:
			wanted_across = clampf(wanted_across + sheet_rate_per_s * dt, 0.0, 1.0)
		elif sheet_key < 0.0 and wanted_across > 0.0:
			wanted_across = clampf(wanted_across - sheet_rate_per_s * dt, 0.0, 1.0)
		else:
			wanted_sheet = clampf(wanted_sheet + sheet_key * sheet_rate_per_s * dt, 0.0, 1.0)
	elif (auto_sheet or manoeuvre != Manoeuvre.NONE) and _manual_sheet_timer_s <= 0.0:
		# Space does the whole manoeuvre, sheet included, in either mode.
		_scratch.sheet = wanted_sheet
		_scratch.boom_across = wanted_across
		_scratch.rake = controls.rake
		auto_sheet_pilot.turn_right_wanted = _turn_wanted
		auto_sheet_pilot.update(telemetry, _scratch, dt)
		wanted_sheet = _scratch.sheet
		wanted_across = _scratch.boom_across
		controls.hold_side = _scratch.hold_side
		controls.step_forward = _scratch.step_forward
	else:
		controls.hold_side = 0
		controls.step_forward = 0.0
	_manual_sheet_timer_s = maxf(_manual_sheet_timer_s - dt, 0.0)

	# Overpowered: the sailor lets the sail out rather than being pulled over it.
	var pilot_trimming: bool = (auto_sheet or manoeuvre != Manoeuvre.NONE) and _manual_sheet_timer_s <= 0.0
	if ease_when_overpowered and mode == Mode.BEGINNER and not pilot_trimming and controls.hold_side == 0:
		# Overpowered means the sail is pulling the sailor over: the hike is used up, or the
		# board heels to leeward while the sailor hangs out to windward. (A board heeled
		# toward a sailor who is not hiking is not the sail's doing: a tack, a carve.)
		var tack: float = tack_sign(telemetry)
		var leeward_heel_deg: float = -telemetry.heel_deg * tack
		var hiked_to_windward: bool = telemetry.lean * tack > 0.3
		var overpowered: bool = absf(telemetry.lean) > ease_hike_share or (leeward_heel_deg > ease_heel_deg and hiked_to_windward)
		var rate: float = ease_rate_per_s if overpowered else ease_recovery_rate_per_s
		ease = move_toward(ease, 1.0 if overpowered else 0.0, rate * dt)
	else:
		ease = 0.0
	controls.sheet = clampf(wanted_sheet - ease, 0.0, 1.0)
	controls.boom_across = wanted_across if ease < 0.01 else 0.0

	controls.balance_reflex = true


## The beginner's turn-rate loop. turn_key asks for a rate; without a key the heading hold
## asks for the rate that brings the heading back. The error against the measured yaw rate
## moves the helm now (proportional) and slowly shifts the trim (integral), so the loop
## finds by itself how much helm this speed and course need, in either direction.
func _steer_beginner(telemetry: Telemetry, controls: SimControls, turn_key: float, dt: float) -> void:
	# Coming out of a manoeuvre: let the board straighten before holding a heading.
	if _settling and turn_key == 0.0:
		if absf(telemetry.yaw_rate_dps) > settle_rate_dps:
			helm_right = 0.0
			wanted_rate_dps = 0.0
			controls.rake = move_toward(controls.rake, 0.0, helm_rate_per_s * dt)
			controls.rig_tilt = move_toward(controls.rig_tilt, 0.0, helm_rate_per_s * dt)
			controls.lean = move_toward(controls.lean, 0.0, helm_rate_per_s * dt)
			return
		_settling = false
		_heading_held = false
		# The trim the loop learnt during the manoeuvre belongs to the turn, not to the new
		# course: start the hold from neutral.
		_helm_trim_up = 0.0
	elif turn_key != 0.0:
		_settling = false
	# In irons: the sail cannot fill and the auto-sheet pilot is backing it toward the
	# wanted side. A turn-rate loop has nothing to work with; the rig goes back and the
	# weight off the rails, so that the wind's push on the backed sail, aft of the centre
	# of mass, swings the bow. The moment the pilot trims the sail normally again, the loop
	# takes over and the rig goes where the turn needs it.
	if auto_sheet_pilot.is_backing() and turn_key != 0.0:
		wanted_rate_dps = turn_key * turn_rate_dps
		helm_right = turn_key
		_heading_held = false
		controls.rake = move_toward(controls.rake, 1.0, helm_rate_per_s * dt)
		controls.rig_tilt = move_toward(controls.rig_tilt, 0.0, helm_rate_per_s * dt)
		controls.lean = move_toward(controls.lean, 0.0, helm_rate_per_s * dt)
		return
	var rate: float = 0.0
	if turn_key != 0.0:
		rate = turn_key * turn_rate_dps
		# A right turn heads up on starboard tack, a left turn on port tack.
		if signf(rate) == tack_sign(telemetry):
			var cap: float = clampf(head_up_rate_budget_dps_ms / maxf(telemetry.speed_ms, 0.1), head_up_rate_min_dps, turn_rate_dps)
			rate = clampf(rate, -cap, cap)
		_heading_held = false
	elif hold_heading:
		if not _heading_held:
			# A positive yaw rate turns the bow to port (the heading decreases).
			var lead_deg: float = clampf(-telemetry.yaw_rate_dps * hold_lead_s, -hold_lead_max_deg, hold_lead_max_deg)
			_held_heading_deg = wrapf(telemetry.heading_deg + lead_deg, 0.0, 360.0)
			_heading_held = true
		var turn_right_deg: float = wrapf(_held_heading_deg - telemetry.heading_deg, -180.0, 180.0)
		rate = clampf(hold_rate_per_deg * turn_right_deg, -hold_rate_limit_dps, hold_rate_limit_dps)
	held_heading_deg = _held_heading_deg if _heading_held else -1.0
	# A key asks for a turn and gets the rail; the heading hold keeps the board flat and
	# steers with the rig alone. A planing board carves hard on a few degrees of bank, and
	# a hold that banked for every small correction would rock the board about its course.
	_steer_at_rate(telemetry, controls, rate, turn_key != 0.0, dt)


## The tack: carved up to the wind at tack_rate_dps on the windward rail; then, within
## pivot_within_deg of the wind or with the rig held by the auto-sheet pilot, the rig fully
## back and no weight on a rail while the backed sail swings the bow through. On the new
## tack the rig stays back as long as the sail is backwinded or luffing: a sail that cannot
## fill cannot drive the bow off the wind, but the wind on its wrong side, aft of the
## centre of mass, pushes the stern round (the way out of irons). Once it fills, full helm
## away from the wind until the manoeuvre ends.
func _steer_tack(telemetry: Telemetry, controls: SimControls, turn: float, dt: float) -> void:
	var pivot: bool = Helm.pivoting(telemetry, controls, pivot_within_deg)
	var on_new_tack: bool = tack_sign(telemetry) == -_tack_sign_at_start
	var stuck: bool = on_new_tack and auto_sheet_pilot.is_backing()
	if (not on_new_tack and pivot) or stuck:
		helm_right = turn
		wanted_rate_dps = turn * tack_rate_dps
		controls.rake = move_toward(controls.rake, 1.0, helm_rate_per_s * dt)
		controls.rig_tilt = move_toward(controls.rig_tilt, 0.0, helm_rate_per_s * dt)
		controls.lean = move_toward(controls.lean, 0.0, helm_rate_per_s * dt)
		return
	_steer_at_rate(telemetry, controls, turn * tack_rate_dps, true, dt)


## The turn-rate loop: the error against the measured yaw rate moves the helm now
## (proportional) and slowly shifts the trim (integral), so the loop finds by itself how
## much helm this speed and course need, in either direction and on either tack.
func _steer_at_rate(telemetry: Telemetry, controls: SimControls, rate_dps: float, rail_on: bool, dt: float) -> void:
	wanted_rate_dps = rate_dps
	# A positive yaw rate turns the bow to port, so the rate of turning right is its negative.
	var error_dps: float = wanted_rate_dps - (-telemetry.yaw_rate_dps)
	var tack: float = tack_sign(telemetry)
	_helm_trim_up = clampf(_helm_trim_up + rate_integral_gain * error_dps * tack * dt, -1.0, 1.0)
	helm_right = clampf(_helm_trim_up * tack + rate_gain * error_dps, -1.0, 1.0)
	var pivot: bool = Helm.pivoting(telemetry, controls, pivot_within_deg)
	# The rig closes the loop. The rail is not in the loop: weight goes on the inside rail
	# in proportion to the wanted rate (the sim banks the board for a coordinated turn at
	# that rate), and none while pivoting through the wind, where a board on its rail skids.
	var rail: float = 0.0 if (pivot or not rail_on) else clampf(wanted_rate_dps / carve_rate_dps, -1.0, 1.0)
	var lean_before: float = controls.lean
	Helm.steer(controls, helm_right, tack, 0.0, dt, helm_rate_per_s, 0.0 if pivot else 1.0)
	controls.lean = move_toward(lean_before, rail, helm_rate_per_s * dt)


## +1 when the wind comes from starboard (starboard tack), -1 from port, with hysteresis
## (see Autopilot.update_tack). Heading up is a right turn on starboard tack and a left turn
## on port tack, which is why the steering needs it (section 10, formula 2a).
func tack_sign(_telemetry: Telemetry) -> float:
	return auto_sheet_pilot.tack


## Switches modes; the auto-sheet follows the mode's default (on for beginners).
func set_mode(new_mode: Mode) -> void:
	mode = new_mode
	auto_sheet = mode == Mode.BEGINNER


## Forgets the sheet and the manoeuvre (after a reset or a waterstart).
func reset_controls(controls: SimControls) -> void:
	_settling = false
	_alpha_cap_deg = 90.0
	wanted_sheet = 0.0
	ease = 0.0
	manoeuvre = Manoeuvre.NONE
	_manual_sheet_timer_s = 0.0
	_heading_held = false
	_helm_trim_up = 0.0
	helm_right = 0.0
	wanted_across = 0.0
	_last_sail_side = 0
	auto_sheet_pilot = Autopilot.new()
	auto_sheet_pilot.hold_course = false
	auto_sheet_pilot.trim_sheet = true
	auto_sheet_pilot.sail = _sail
	controls.sheet = 0.0
	controls.boom_across = 0.0
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
	# From a beam reach (and a little beyond) the quicker way onto the other tack is up
	# through the wind; from a broad reach it is round through the gybe.
	manoeuvre = Manoeuvre.TACK_HEADING_UP if absf(telemetry.twa_deg) <= tack_up_to_twa_deg else Manoeuvre.GYBE_BEARING_AWAY


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
