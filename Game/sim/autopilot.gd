class_name Autopilot
extends RefCounted
## A simple sailor for tests, scenarios and (later) the AI opponents: holds a wind angle
## with the rig, and trims the sheet to a chosen angle of attack. Everything it does is
## something a real sailor does with their arms; it never touches the physics directly.
##
## Steering: raking the mast back makes the board head up, raking it forward makes it
## bear away (PHYSICS_SPEC.md section 3). So when the board sails too far off the wind
## (the wind angle is larger than wanted) the rig goes back, and the other way round.

## Wanted true wind angle, in degrees, as a magnitude (the tack is whatever it is).
var target_twa_deg: float = 90.0
## Wanted angle of attack of the sail, in degrees, when the pilot does not know the sail.
var target_alpha_deg: float = 15.0
## The simulation's sail, when the pilot may use its lift and drag curves to sheet for the
## most drive at the current apparent wind angle, which is what a sailor does by feel:
## close to the wind that is a modest angle (drag costs), on a reach it is near the stall.
var sail: SailModel = null
## Rake per degree of wind-angle error, and rake per degree per second of yaw rate against
## it. Together they set the turn rate the pilot settles for: about 15 degrees per second
## for a large error. The rig has a lot of authority at planing speed (a full rake moves
## the centre of effort a metre), and a sailor who turned harder would be flung out of
## the turn.
var rake_gain_per_deg: float = 0.03
var rake_yaw_damping: float = 0.05
## How much weight the pilot puts on the inside rail per unit of helm (see Helm). None by
## default: holding a course is done with the rig and a flat board; a planing board carves
## hard on a few degrees of bank, so a rail used for every small correction rocks it.
var lean_share: float = 0.0
## How fast the sailor moves the rig and the sheet (units per second).
var rake_rate_per_s: float = 3.0
var sheet_rate_per_s: float = 1.5
## Sheet and boom angle limits of the sail (from SailConfig).
var sheet_angle_in_deg: float = 12.0
var sheet_angle_out_deg: float = 85.0
var trim_sheet: bool = true
var hold_course: bool = true
## A real sailor does not try to point high from standstill: the fin only works with
## speed. Below this speed the pilot sails no closer than bear_away_twa_deg, then heads up.
var pointing_speed_ms: float = 5.0
var bear_away_twa_deg: float = 70.0
var _pointing: bool = false
## Depowering: the sheet is the throttle. While the sailor is out of hike (lean beyond
## depower_lean_start) or the board heels to leeward past a small allowance, the sailor
## eases, gradually, toward min_alpha_deg; while there is hike in reserve they sheet back
## in. The rate is depower_rate_per_s per second per unit of excess. A trim that answered
## the lean instantly would pump the sail at several hertz against the sailor's own
## reflex (the lean follows the pull, the trim follows the lean); a real sailor eases a
## little and holds. Leeward heel beyond the allowance is answered at once as well, by
## depower_alpha_per_deg per degree: the board rolls slowly, so that loop is calm.
var depower_lean_start: float = 0.75
var depower_heel_allowance_deg: float = 5.0
var depower_heel_span_deg: float = 10.0
var depower_rate_per_s: float = 0.25
## Near the limits the sailor moves much faster: with the hike more than seven eighths
## used, or the felt leeward heel well past the allowance, they let the sail out at once;
## standing nearly upright with the sail eased, they sheet back in at once. This much
## more per second per unit beyond the half-way marks.
var depower_urgent_rate_per_s: float = 2.0
var depower_alpha_per_deg: float = 1.0
var _depower: float = 0.0
## Nearly let fly when the hike is used up: a luffing sail carries next to nothing, and
## that is the sailor's last resort before being pulled over.
var min_alpha_deg: float = 1.0
## The sailor may also ease on purpose: the trim never asks for more than this angle of
## attack (the player controller lowers it while entering a gybe at speed).
var max_alpha_deg: float = 90.0
## Tacking. In the no-go zone (the apparent wind so close that the sail luffs even fully
## sheeted), heading up hard, the sailor holds the rig on its side and pushes the clew
## across the centreline (backing the sail, up to boom_across_max_deg): the wind on the
## backed sail pushes it to the old leeward side and aft, which swings the bow through the
## wind. The sail is held at backing_alpha_deg, well into the stall: head to wind there is
## no drive to be had, only the push. Once the apparent wind is flip_awa_deg across on the
## new side, the sailor flips the rig and sheets in for the new tack.
var boom_across_max_deg: float = 47.0
var alpha_luff_deg: float = 5.0
var backing_alpha_deg: float = 25.0
## A sailor standing at the mast can push a backed sail with the arms, bracing with the
## body, about this hard (half their weight); a faster board or stronger wind means a
## smaller backing angle, and the sailor who wants a snappier tack slows down first.
var backing_force_max_n: float = 350.0
## A sailor backing the sail lets it go the moment the board tips to leeward past this:
## the push on the backed sail is what makes a skidding board trip over its fin.
var backing_release_heel_deg: float = 25.0
## The rig is flipped once the bow is this far through the true wind.
var flip_twa_deg: float = 25.0
## A tack is given up (the sailor sails on where the bow points) when the bow is this far
## from head to wind on the old side.
var tack_abandon_twa_deg: float = 35.0
## The sail fills and drives once the apparent wind is this much wider than the luff band
## (about 20 degrees off the bow, 8 degrees of angle of attack fully sheeted). Between the
## band and this the sheeted sail carries too little to sail out of irons on; the sailor
## backs it instead.
var fill_margin_deg: float = 3.0
## Where the tack is: 0 = not tacking; 1 = the bow in the no-go zone, the rig held on the
## old side and the sail backed; 2 = the rig flipped and held on the new side until the
## bow is well round. Once begun, the sailor's hands decide which side the rig is on, not
## the wind: a rig that flipped itself in the middle of a tack backwinds and pushes the
## bow straight back.
var _tack_phase: int = 0
## Which way the bow is wanted to turn, +1 right, -1 left, 0 none: set by the player
## controller (the key or the manoeuvre) before update(), or by the course hold. In the
## no-go zone it decides how the sail is backed: pushed across the centreline the wind on
## it carries the bow away from the sail's side (a tack); eased on its own side and
## backwinded it carries the bow toward the sail's side (the way out of irons).
var turn_right_wanted: float = 0.0
var _hold_turn_right: float = 0.0
## Which tack the helm works on: the side the rig is on decides it (the boom is on the
## leeward side), so the helm flips when the rig flips, not while the bow wavers head to
## wind. The sail keeps its side until the wind is clearly across (SailConfig
## side_hysteresis_deg).
var tack: float = 1.0
var _last_sail_side: int = 0


## Updates the helm (rake, rig tilt, weight) and the sheet from the last telemetry.
func update(telemetry: Telemetry, controls: SimControls, dt: float) -> void:
	update_tack(telemetry)
	if telemetry.sail_side != _last_sail_side:
		if _last_sail_side != 0:
			carry_boom_across_the_flip(controls, sheet_angle_in_deg, sheet_angle_out_deg, boom_across_max_deg)
		_last_sail_side = telemetry.sail_side
	if hold_course:
		if telemetry.speed_ms > pointing_speed_ms:
			_pointing = true
		elif telemetry.speed_ms < pointing_speed_ms - 1.5:
			_pointing = false
		var wanted_twa: float = target_twa_deg if _pointing else maxf(target_twa_deg, bear_away_twa_deg)
		var error_deg: float = absf(telemetry.twa_deg) - wanted_twa
		# A positive yaw rate turns the bow to port. On starboard tack (positive TWA) that is
		# bearing away, on port tack it is heading up: turn it into "rate of heading up".
		var heading_up_rate: float = -telemetry.yaw_rate_dps * signf(telemetry.twa_deg) if telemetry.twa_deg != 0.0 else 0.0
		var head_up: float = clampf(rake_gain_per_deg * error_deg - rake_yaw_damping * heading_up_rate, -1.0, 1.0)
		_hold_turn_right = signf(head_up) * tack if absf(head_up) > 0.1 else 0.0
		# Heading up is a right turn on starboard tack and a left turn on port tack.
		var pivot: bool = Helm.pivoting(telemetry, controls, 30.0)
		Helm.steer(controls, head_up * tack, tack, 0.0 if pivot else lean_share, dt, rake_rate_per_s, 0.0 if pivot else 1.0)
	if trim_sheet:
		var alpha_deg: float = minf(best_alpha_deg(deg_to_rad(telemetry.awa_deg)), max_alpha_deg)
		# Leeward heel is heel away from the wind: negative on starboard tack (wind from
		# starboard). The bank the sailor holds on purpose (carving) is not overpowering:
		# only the heel beyond it counts. The felt version adds the push of a sustained
		# turn, which flings the sailor to leeward like extra heel would; it feeds only the
		# slow part of the trim below, because the push answers the sail's own pull within
		# a fraction of a second and a quick trim on it would pump the sail.
		var windward: float = signf(telemetry.twa_deg) if telemetry.twa_deg != 0.0 else 1.0
		var deliberate_leeward_deg: float = maxf(-telemetry.wanted_bank_deg * windward, 0.0)
		var leeward_heel_deg: float = -telemetry.heel_deg * windward - deliberate_leeward_deg
		var felt_leeward_heel_deg: float = -telemetry.felt_heel_deg * windward - deliberate_leeward_deg
		var over_hike: float = clampf((absf(telemetry.lean) - depower_lean_start) / (1.0 - depower_lean_start), -1.0, 1.0)
		var over_heel: float = clampf((felt_leeward_heel_deg - depower_heel_allowance_deg) / depower_heel_span_deg, 0.0, 1.0)
		var urgency: float = maxf(over_hike - 0.5, 0.0) + maxf(over_heel - 0.5, 0.0) - maxf(-over_hike - 0.5, 0.0)
		_depower = clampf(_depower + (depower_rate_per_s * (over_hike + over_heel) + depower_urgent_rate_per_s * urgency) * dt, 0.0, 1.0)
		alpha_deg = lerpf(alpha_deg, min_alpha_deg, _depower)
		if leeward_heel_deg > depower_heel_allowance_deg:
			alpha_deg = maxf(alpha_deg - depower_alpha_per_deg * (leeward_heel_deg - depower_heel_allowance_deg), min_alpha_deg)
		var boom_angle_deg: float = clampf(absf(telemetry.awa_deg) - alpha_deg, sheet_angle_in_deg, sheet_angle_out_deg)
		var across: float = 0.0
		# The apparent and true wind measured on the sail's own windward side: negative once
		# the bow has gone through the wind while the rig is still held on the old side.
		# Inside luff_band_deg the sail luffs even fully sheeted (the no-go zone).
		var awa_own_side_deg: float = telemetry.awa_deg * -float(telemetry.sail_side)
		var twa_own_side_deg: float = telemetry.twa_deg * -float(telemetry.sail_side)
		var luff_band_deg: float = sheet_angle_in_deg + alpha_luff_deg
		controls.hold_side = 0
		controls.step_forward = 0.0
		# With the apparent wind inside the no-go zone and a turn wanted, the sail is backed:
		# across the centreline when the bow is to go away from the sail's side (a tack,
		# phase 1), on its own side when the bow is to go toward it (out of irons, phase 2).
		# Without a stated wish, a rig raked back counts as heading up.
		var wanted_turn: float = _hold_turn_right if hold_course else turn_right_wanted
		if wanted_turn == 0.0 and controls.rake > 0.5:
			wanted_turn = tack
		var away_from_sail: float = -float(telemetry.sail_side)
		# The no-go zone is the apparent wind within the luff band of the bow, on either side
		# (the own-side angle alone would also be small with the wind behind the sail on a
		# run by the lee, where the sail is simply eased). A little wider than that the sail
		# carries something but not enough to drive out of irons on.
		var in_no_go_zone: bool = absf(telemetry.awa_deg) < luff_band_deg
		var cannot_fill: bool = absf(telemetry.awa_deg) < luff_band_deg + fill_margin_deg
		# A change of mind ends either phase; so does a bow that fell back out of the zone
		# (phase 1), or a sail that fills or a wind clearly back on the sail's side (phase 2).
		if _tack_phase == 1 and (wanted_turn * away_from_sail < 0.0 or twa_own_side_deg > tack_abandon_twa_deg):
			_tack_phase = 0
		if _tack_phase == 2 and (wanted_turn * away_from_sail > 0.0 or not cannot_fill or twa_own_side_deg <= -tack_abandon_twa_deg):
			_tack_phase = 0
		if _tack_phase == 0 and wanted_turn != 0.0:
			if wanted_turn * away_from_sail > 0.0 and in_no_go_zone:
				_tack_phase = 1
			elif wanted_turn * away_from_sail < 0.0 and cannot_fill:
				_tack_phase = 2
		if _tack_phase == 1:
			# The bow is clearly through the wind (the true wind, which does not swing with the
			# turning rig as the apparent wind does) and the apparent wind on the new side is
			# wide enough for the sail to fill the moment it is sheeted in there: flip the rig.
			# Flipped earlier, the sail would luff on the new side and the fin would weathervane
			# the bow straight back.
			var fills_on_new_side: bool = -awa_own_side_deg >= luff_band_deg
			var bow_through: bool = twa_own_side_deg <= -flip_twa_deg and fills_on_new_side
			if bow_through:
				# The bow is round: flip the rig and sheet in on the new side in one motion, to
				# the boom angle that fills the sail at this apparent wind (the sailor is
				# stepping across, not hiked out, so the trim is not depowered here).
				_tack_phase = 2
				controls.hold_side = -telemetry.sail_side
				controls.boom_across = 0.0
				var filled_alpha_deg: float = best_alpha_deg(deg_to_rad(telemetry.awa_deg))
				var filled_boom_deg: float = clampf(absf(telemetry.awa_deg) - filled_alpha_deg, sheet_angle_in_deg, sheet_angle_out_deg)
				controls.sheet = 1.0 - (filled_boom_deg - sheet_angle_in_deg) / (sheet_angle_out_deg - sheet_angle_in_deg)
				return
			else:
				# In the no-go zone: the sailor steps round the front of the mast (the tail and
				# the fin lift, the board pivots on its nose), holds the rig on this side and
				# pushes the clew across until the wind meets the sail at the backing angle.
				# The backed sail is eased as the board heels to leeward, like any other trim:
				# a sailor standing at the mast cannot hike against it.
				controls.hold_side = telemetry.sail_side
				controls.step_forward = 1.0
				var backed_alpha_deg: float = _backing_alpha_deg(telemetry)
				if leeward_heel_deg > depower_heel_allowance_deg:
					backed_alpha_deg = maxf(backed_alpha_deg - depower_alpha_per_deg * (leeward_heel_deg - depower_heel_allowance_deg), 0.0)
				var backed_boom_deg: float = awa_own_side_deg - backed_alpha_deg
				across = clampf((sheet_angle_in_deg - backed_boom_deg) / boom_across_max_deg, 0.0, 1.0)
				if leeward_heel_deg > backing_release_heel_deg:
					across = 0.0
				boom_angle_deg = sheet_angle_in_deg
		elif _tack_phase == 2:
			# The bow is to go toward the sail's side (just after the rig flipped in a tack,
			# or out of irons): the rig is held on this side and the sail eased so that the
			# wind backs it here. With the rig raked back (the player controller sees to that)
			# the push on the backed sail, aft of the centre of mass, carries the stern the
			# other way and the bow round, until the apparent wind is wide enough for the sail
			# to fill.
			controls.hold_side = telemetry.sail_side
			boom_angle_deg = clampf(awa_own_side_deg + _backing_alpha_deg(telemetry), sheet_angle_in_deg, sheet_angle_out_deg)
		var wanted_sheet: float = 1.0 - (boom_angle_deg - sheet_angle_in_deg) / (sheet_angle_out_deg - sheet_angle_in_deg)
		controls.sheet = move_toward(controls.sheet, wanted_sheet, sheet_rate_per_s * dt)
		controls.boom_across = move_toward(controls.boom_across, across, sheet_rate_per_s * dt)


## The angle of attack that gives the most drive at this apparent wind angle, from the
## sail's own lift and drag curves (drive = lift along the course minus drag against it).
func best_alpha_deg(awa_rad: float) -> float:
	if sail == null:
		return target_alpha_deg
	var awa: float = absf(awa_rad)
	var best_alpha: float = target_alpha_deg
	var best_drive: float = -INF
	var alpha_deg: float = 4.0
	while alpha_deg <= 24.0:
		var alpha: float = deg_to_rad(alpha_deg)
		var cl: float = sail.lift_coefficient(alpha)
		var cd: float = sail.drag_coefficient(cl, alpha)
		var drive: float = cl * sin(awa) - cd * cos(awa)
		if drive > best_drive:
			best_drive = drive
			best_alpha = alpha_deg
		alpha_deg += 1.0
	return best_alpha


## True while the sail is being backed (a tack in the no-go zone, or getting out of
## irons): the rig belongs aft then, and the helm has nothing to steer with.
func is_backing() -> bool:
	return _tack_phase != 0


## Keeps `tack` (+1 wind from starboard, -1 from port): the opposite of the sail's side.
func update_tack(telemetry: Telemetry) -> void:
	if telemetry.sail_side != 0:
		tack = -float(telemetry.sail_side)
	else:
		tack = 1.0 if telemetry.twa_deg >= 0.0 else -1.0


## When the rig flips during a tack (the sail changes side while the boom is pushed
## across), the sailor sheets in on the new side in the same motion: the boom goes to the
## fully sheeted position, where the sail luffs until the bow is far enough round and then
## fills on the new tack. Left where it was, the sail would back-fill on the new side and
## push the bow straight back into the wind.
static func carry_boom_across_the_flip(controls: SimControls, _in_deg: float, _out_deg: float, _across_max_deg: float) -> void:
	if controls.boom_across <= 0.0:
		return
	controls.sheet = 1.0
	controls.boom_across = 0.0


## The angle a backed sail is held at: the backing angle, or less when the wind is strong
## enough that the sail would push harder than the sailor can hold, down to a sail that
## is nearly in line with the wind and flaps (the luff fade of the sail model).
func _backing_alpha_deg(telemetry: Telemetry) -> float:
	if sail == null:
		return backing_alpha_deg
	var aws_ms: float = telemetry.aws_kt * SimMath.KNOT_MS
	var q: float = 0.5 * 1.225 * aws_ms * aws_ms
	var cl_allowed: float = backing_force_max_n / maxf(q * sail.config.area_m2, 1e-6)
	var alpha_deg: float = backing_alpha_deg
	while alpha_deg > 0.5 and sail.lift_coefficient(deg_to_rad(alpha_deg)) > cl_allowed:
		alpha_deg -= 0.5
	return alpha_deg
