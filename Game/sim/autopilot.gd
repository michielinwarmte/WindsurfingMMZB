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
## The air density the simulation sails in (kg/m3), for the sail force the pilot expects: set
## with the sail (WindsurferSim.air_density_kg_m3; thinner on a mountain lake).
var air_density_kg_m3: float = 1.225
## The sailor, when the pilot may use their weight, reach and lean rate to sheet in only
## as fast as the body can lean out against the pull.
var sailor: SailorConfig = null
## The sailor sheets in at this share of the pace they can hike out at, so the body stays
## ahead of the pull: the sail's heeling torque may rise by at most this share of the
## sailor's full righting moment per unit of lean per second.
var sheet_in_share: float = 0.5
## Rake per degree of wind-angle error, and rake per degree per second of yaw rate against
## it. Together they set the turn rate the pilot settles for: about 15 degrees per second
## for a large error. The rig has a lot of authority at planing speed (a full rake moves
## the centre of effort a metre), and a sailor who turned harder would be flung out of
## the turn. Holding a course needs a steady rake (weather helm), which a sailor finds by
## feel: the trim accumulates at rake_trim_per_deg_s per degree of error per second.
var rake_gain_per_deg: float = 0.03
var rake_yaw_damping: float = 0.05
var rake_trim_per_deg_s: float = 0.01
var _rake_trim: float = 0.0
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
## Depowering: the sheet is the throttle, and the sailor sheets in only to the pull they
## can hold. The sail is never trimmed beyond the angle of attack at which its heeling
## torque, at this apparent wind, is hike_share of what the sailor's lean holds right now
## (the weight at the body's present lever from the feet) plus ankle_share of what the
## feet can pass to the deck. A share a little over 1 is the hike-out ratchet of getting
## going: sheet in a little more than the lean holds, lean out to it, sheet in again
## (at 0.95 the sailor never got out of the upright stance: the pull allowed by a small
## lean asked for only a small lean). This is a sailor feeling the pull in the hands and
## the harness: more apparent wind, less sheet, at once and without any loop that could
## pump (an earlier version integrated the hike itself and pumped the sail against the
## sailor's own reflex at about 1 Hz).
var hike_share: float = 1.1
var ankle_share: float = 0.8
## On top of that, leeward heel beyond the deliberate bank and a small allowance is
## answered at once by depower_alpha_per_deg per degree (the board is going over), and
## the push of a hard turn, felt as leeward heel, slowly (depower_rate_per_s per second
## per unit of excess over depower_heel_span_deg, and depower_urgent_rate_per_s more
## beyond half of it): a sailor flung outward in a turn eases a little.
var depower_heel_allowance_deg: float = 5.0
var depower_heel_span_deg: float = 10.0
var depower_rate_per_s: float = 0.25
var depower_urgent_rate_per_s: float = 2.0
var depower_alpha_per_deg: float = 1.0
var _depower: float = 0.0
## Caught by the sheet: a body tipping back (the sail stopped pulling while the sailor
## was hiked out: the feet asked to pass more windward moment than they can) is caught
## by sheeting in at once, and one being pulled over the sail by letting it go at once,
## this many degrees of angle of attack per newton metre the feet could not hold, up to
## catch_alpha_max_deg (more than that pumped the sheet against the depowering). The
## oldest rule of windsurfing: when in doubt, sheet in.
var catch_alpha_per_nm: float = 0.02
var catch_alpha_max_deg: float = 4.0
var _catching: bool = false
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
var backing_force_max_n: float = 250.0
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
## A sail backed on its own side (out of irons, or just after the rig flipped in a tack)
## is kept backed until the bow is this far off the wind, unless the board already has
## way on (backing_exit_speed_ms): a filled sail on a board without speed, with the rig
## raked back, only rounds it straight back up, because the fin cannot hold the bow yet.
var backing_exit_twa_deg: float = 55.0
var backing_exit_speed_ms: float = 3.0
## Where the tack is: 0 = not tacking; 1 = the bow in the no-go zone, the rig held on the
## old side and the sail backed; 2 = the rig flipped and held on the new side until the
## bow is well round. Once begun, the sailor's hands decide which side the rig is on, not
## the wind: a rig that flipped itself in the middle of a tack backwinds and pushes the
## bow straight back.
var _tack_phase: int = 0
## Whether the pilot may back the sail through the wind when it cannot point as high as it
## is asked to (the validation's no-go check wants a pilot that keeps trying and fails).
var may_tack: bool = true
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
		# The trim only accumulates while the helm is not already at its stop (no wind-up).
		if absf(_rake_trim + rake_gain_per_deg * error_deg) < 1.0:
			_rake_trim = clampf(_rake_trim + rake_trim_per_deg_s * error_deg * dt, -0.8, 0.8)
		var head_up: float = clampf(_rake_trim + rake_gain_per_deg * error_deg - rake_yaw_damping * heading_up_rate, -1.0, 1.0)
		_hold_turn_right = signf(head_up) * tack if absf(head_up) > 0.1 else 0.0
		# Heading up is a right turn on starboard tack and a left turn on port tack.
		var pivot: bool = Helm.pivoting(telemetry, controls, 30.0)
		Helm.steer(controls, head_up * tack, tack, 0.0 if pivot else lean_share, dt, rake_rate_per_s, 0.0 if pivot else 1.0)
	if trim_sheet:
		_feel_the_pull(telemetry, dt)
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
		alpha_deg = minf(alpha_deg, _alpha_for_torque_deg(telemetry, _righting_moment_now_nm(telemetry)))
		var over_heel: float = clampf((felt_leeward_heel_deg - depower_heel_allowance_deg) / depower_heel_span_deg, -1.0, 1.0)
		var urgency: float = maxf(over_heel - 0.5, 0.0)
		_depower = clampf(_depower + (depower_rate_per_s * over_heel + depower_urgent_rate_per_s * urgency) * dt, 0.0, 1.0)
		alpha_deg = lerpf(alpha_deg, min_alpha_deg, _depower)
		if leeward_heel_deg > depower_heel_allowance_deg:
			alpha_deg = maxf(alpha_deg - depower_alpha_per_deg * (leeward_heel_deg - depower_heel_allowance_deg), min_alpha_deg)
		# The excess is positive when the body is being tipped to port; tipping back is
		# tipping to windward.
		var tipping_back_nm: float = -telemetry.feet_moment_excess_nm * windward
		_catching = tipping_back_nm > 0.0
		var catch_deg: float = clampf(catch_alpha_per_nm * tipping_back_nm, -catch_alpha_max_deg, catch_alpha_max_deg)
		alpha_deg = clampf(alpha_deg + catch_deg, min_alpha_deg, 24.0)
		var boom_angle_deg: float = clampf(absf(telemetry.awa_deg) - alpha_deg, sheet_angle_in_deg, sheet_angle_out_deg)
		var across: float = 0.0
		# The apparent and true wind measured on the sail's own windward side: negative once
		# the bow has gone through the wind while the rig is still held on the old side.
		# Inside luff_band_deg the sail luffs even fully sheeted (the no-go zone). Both are the
		# wind the sail meets where the board is: on a map the lake's mean wind can come from
		# 15 degrees elsewhere near a shore, and a tack judged on it stalls with the backed
		# sail feathered short of the flip (PHYSICS_SPEC.md 17.14, the lake's tacks).
		var awa_own_side_deg: float = telemetry.awa_deg * -float(telemetry.sail_side)
		var twa_own_side_deg: float = telemetry.twa_at_sail_deg * -float(telemetry.sail_side)
		var luff_band_deg: float = sheet_angle_in_deg + alpha_luff_deg
		controls.hold_side = 0
		controls.step_forward = 0.0
		# With the apparent wind inside the no-go zone and a turn wanted, the sail is backed:
		# across the centreline when the bow is to go away from the sail's side (a tack,
		# phase 1), on its own side when the bow is to go toward it (out of irons, phase 2).
		var wanted_turn: float = _hold_turn_right if hold_course else turn_right_wanted
		var away_from_sail: float = -float(telemetry.sail_side)
		# The no-go zone is the apparent wind within the luff band of the bow, on either side
		# (the own-side angle alone would also be small with the wind behind the sail on a
		# run by the lee, where the sail is simply eased). A little wider than that the sail
		# carries something but not enough to drive out of irons on.
		var in_no_go_zone: bool = absf(telemetry.awa_deg) < luff_band_deg
		var cannot_fill: bool = absf(telemetry.awa_deg) < luff_band_deg + fill_margin_deg
		var bow_well_off: bool = twa_own_side_deg >= backing_exit_twa_deg or telemetry.speed_ms >= backing_exit_speed_ms
		# A change of mind ends either phase; so does a bow that fell back out of the zone
		# (phase 1), or a sail that can fill on a bow well enough off the wind, or a wind
		# clearly back on the sail's side (phase 2).
		if _tack_phase == 1 and (wanted_turn * away_from_sail < 0.0 or twa_own_side_deg > tack_abandon_twa_deg):
			_tack_phase = 0
		if _tack_phase == 2 and (wanted_turn * away_from_sail > 0.0 or (not cannot_fill and bow_well_off) or twa_own_side_deg <= -tack_abandon_twa_deg):
			_tack_phase = 0
		if _tack_phase == 0 and wanted_turn != 0.0:
			if wanted_turn * away_from_sail > 0.0 and in_no_go_zone and may_tack:
				_tack_phase = 1
			elif wanted_turn * away_from_sail < 0.0 and cannot_fill:
				_tack_phase = 2
		if _tack_phase == 1:
			# The bow is clearly through the wind (the true wind at the sail, which does not
			# swing with the turning rig as the apparent wind does) and the apparent wind on the new side is
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
				var filled_alpha_deg: float = alpha_luff_deg + fill_margin_deg
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
		if _tack_phase == 0 and across <= 0.0 and not _catching:
			# Sheeting in is paced by the body: the pull may grow only as fast as the sailor
			# can lean out against it (a sailor who sheets in faster than they hike is pulled
			# over the sail). The angle of attack may rise at most by the rate at which the
			# allowed torque rise is matched by the sail's lift slope at this wind. (Not while
			# catching a fall: then the sheet comes in as fast as the hands can.)
			var alpha_now_deg: float = maxf(telemetry.alpha_deg, 0.0)
			var wanted_alpha_deg: float = absf(telemetry.awa_deg) - boom_angle_deg
			if wanted_alpha_deg > alpha_now_deg:
				var limited_alpha_deg: float = alpha_now_deg + _alpha_rise_limit_dps(telemetry) * dt
				boom_angle_deg = clampf(absf(telemetry.awa_deg) - minf(wanted_alpha_deg, limited_alpha_deg), sheet_angle_in_deg, sheet_angle_out_deg)
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


## The largest pull (as a moment about the feet) the sailor can hold: their weight at full
## lean, measured from the feet on the rail, plus what the feet and ankles can pass to the
## deck (section 7.5). Infinite without a sailor.
func _max_righting_moment_nm() -> float:
	if sailor == null:
		return INF
	return sailor.mass_kg * 9.81 * (sailor.lean_max_m - sailor.feet_rail_m) + sailor.feet_moment_max_nm


## The pull the sailor can hold right now: hike_share of the weight at the body's present
## lever from the feet (toward windward), plus ankle_share of the feet's moment. As the
## body goes out the sheet comes in; it never runs ahead of the body.
func _righting_moment_now_nm(telemetry: Telemetry) -> float:
	if sailor == null:
		return INF
	var windward: float = 1.0 if telemetry.twa_deg >= 0.0 else -1.0
	var lever_m: float = maxf((telemetry.sailor_position_body.x - telemetry.feet_body.x) * windward, 0.0)
	return hike_share * sailor.mass_kg * 9.81 * lever_m + ankle_share * sailor.feet_moment_max_nm


## The heeling torque per newton of the sail's side force, as it is now: the hands' pull
## as a moment about the feet (the sail's lever about the mast foot, carried to the
## sailor by the boom), or heeling_arm_default_m when the sail carries nothing yet.
var heeling_arm_default_m: float = 2.1
## The heeling lever (the torque per newton of side force, sail and fin together) is felt
## averaged over this long: on chop the fin's load jumps every wave, and a sailor holds
## the sheet through that rather than re-trimming at every jolt. The apparent wind itself
## is taken as it is (a gust is answered at once; a lag there made the sheet hunt upwind,
## and so did 0.5 s on the lever: 0.15 s keeps the 45 degree course steady).
var trim_feel_time_s: float = 0.15
var _felt_side_force_n: float = 0.0
var _felt_heeling_torque_nm: float = 0.0


## Averages what the trim feels: the side force and the heeling torque.
func _feel_the_pull(telemetry: Telemetry, dt: float) -> void:
	var blend: float = clampf(dt / maxf(trim_feel_time_s, dt), 0.0, 1.0)
	_felt_side_force_n = lerpf(_felt_side_force_n, telemetry.side_force_n, blend)
	_felt_heeling_torque_nm = lerpf(_felt_heeling_torque_nm, telemetry.heeling_torque_nm, blend)


func _heeling_arm_m(_telemetry: Telemetry) -> float:
	# A sail eased far out on a broad reach pulls almost straight forward through hands
	# held well to leeward: its side force heels the sailor hardly at all, so the arm may
	# be nearly nothing (a fixed arm eased the sail right off at 135 degrees).
	if absf(_felt_side_force_n) > 15.0:
		return clampf(absf(_felt_heeling_torque_nm) / absf(_felt_side_force_n), 0.2, 4.0)
	return heeling_arm_default_m


## The largest angle of attack (up to 24 degrees) at which the sail's heeling torque at
## this apparent wind stays within limit_nm: side force q A (Cl cos AWA + Cd sin AWA)
## times the lever arm. Down to a quarter of a degree, where the sail flaps and carries
## next to nothing. Unlimited without a sail or a limit.
func _alpha_for_torque_deg(telemetry: Telemetry, limit_nm: float) -> float:
	if sail == null or limit_nm == INF:
		return INF
	var aws_ms: float = telemetry.aws_kt * SimMath.KNOT_MS
	var q_area: float = 0.5 * air_density_kg_m3 * aws_ms * aws_ms * sail.config.area_m2
	var awa: float = deg_to_rad(absf(telemetry.awa_deg))
	var arm_m: float = _heeling_arm_m(telemetry)
	var alpha_deg: float = 24.0
	while alpha_deg > 0.25:
		var alpha: float = deg_to_rad(alpha_deg)
		var cl: float = sail.lift_coefficient(alpha)
		var cd: float = sail.drag_coefficient(cl, alpha)
		var side_n: float = q_area * absf(cl * cos(awa) + cd * sin(awa))
		if side_n * arm_m <= limit_nm:
			return alpha_deg
		alpha_deg -= 0.25
	return 0.25


## How fast the angle of attack may rise (degrees per second) so that the sail's heeling
## torque rises no faster than sheet_in_share of what the sailor's lean can add per
## second: torque rate / (q A x lever arm x lift slope). The lever arm is the one the
## sail has now (its torque over its side force), or the centre of effort's height when
## the sail carries nothing yet. Unlimited without a sailor or a sail to ask.
func _alpha_rise_limit_dps(telemetry: Telemetry) -> float:
	if sail == null or sailor == null:
		return INF
	var aws_ms: float = telemetry.aws_kt * SimMath.KNOT_MS
	var q_area: float = 0.5 * air_density_kg_m3 * aws_ms * aws_ms * sail.config.area_m2
	if q_area < 1.0:
		return INF
	var slope_per_deg: float = sail.lift_slope_per_rad() * PI / 180.0
	var torque_rate_nm_s: float = sheet_in_share * sailor.lean_rate_per_s * _max_righting_moment_nm()
	return torque_rate_nm_s / (q_area * _heeling_arm_m(telemetry) * slope_per_deg)


## The angle a backed sail is held at: the backing angle, or less when the wind is strong
## enough that the sail would push harder than the sailor can hold, down to a sail that
## is nearly in line with the wind and flaps (the luff fade of the sail model).
func _backing_alpha_deg(telemetry: Telemetry) -> float:
	if sail == null:
		return backing_alpha_deg
	var aws_ms: float = telemetry.aws_kt * SimMath.KNOT_MS
	var q: float = 0.5 * air_density_kg_m3 * aws_ms * aws_ms
	var cl_allowed: float = backing_force_max_n / maxf(q * sail.config.area_m2, 1e-6)
	var alpha_deg: float = backing_alpha_deg
	while alpha_deg > 0.5 and sail.lift_coefficient(deg_to_rad(alpha_deg)) > cl_allowed:
		alpha_deg -= 0.5
	return alpha_deg
