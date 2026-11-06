class_name MouseBody
extends RefCounted
## Package B, an experiment: the sailor's body on the mouse (ROADMAP GP2; the design is
## Documentation/reports/playtest/feedback_5_november_2026.md, section 5; the first build is
## Documentation/reports/gameplay/gp2_mouse_body.md, and the feet's press after Max's play-test of
## 6 November 2026 is Documentation/reports/gameplay/gp2_feet_pressure.md).
##
## While sailing the mouse is captured and stands for the sailor's body, the feet staying in the
## straps (Max, 6 November 2026: "the feet need to stay in the straps, like real life, but the
## pressure and rotation is different"):
## - sideways is the toes against the heels: toward more rail, the feet press the leeward rail down
##   with the toes (the ankles roll the board); the other way, the heels press the windward rail
##   down and the board comes flat;
## - forward and back is the back foot against the front foot: pull the mouse back (toward you) and
##   the weight goes onto the back foot, over the back strap (the knees and hips move it), the nose
##   lifts; push it forward and the weight goes onto the front foot, the nose goes down.
## The mouse left in the middle is the sailor's own technique, exactly as in 0.1.
##
## The body writes two controls of the simulation (SimControls.feet_roll_press and
## feet_pitch_press, -1 to +1): how hard the feet press, as a share of a full press. A full press of
## the toes turns the board 10 degrees further to leeward than the technique's bank and the feet hold
## it there with all their roll moment; a full back foot puts all the weight on the back strap, the
## front foot pulling up in its strap. The simulation moves the feet there at the pace of a weight
## shift (0.4 s from the middle to an end), and its own search for the trim (the easing off on a
## bounce included) stands aside as far as the body presses. What the board then does (faster, a bounce, a catapult, a slower over-railed board) is
## the simulation's own answer. The press works only planing in the straps and not in a turn, so the
## mouse does nothing below planing or in a manoeuvre. Max's open choices (ROADMAP GD7, the design's
## "open choices") are settings, with the lead's recommendation as the default, so they can be
## switched while playing.

## What the mouse does when you leave it alone (GD7 a). STAYS: it stays where you put it (holding
## an angle is the point), and it comes back to the middle (the technique) at every tack, gybe and
## fall. SPRINGS_BACK: it also slides back to the middle by itself, over spring_back_s.
enum Centre { STAYS, SPRINGS_BACK }
## Which way sideways means more rail (GD7 b). AS_SEEN: the board rolls the way the mouse moves,
## as seen from behind the board (the follow camera): right puts the starboard rail down. On
## starboard tack (the wind from the right) the leeward rail is the port one, so there left is more
## rail; on port tack right is. RIGHT_IS_MORE_RAIL: right is always more leeward rail.
enum Sideways { AS_SEEN, RIGHT_IS_MORE_RAIL }

## Level 2: the feet's own correction of the rail slowed to this (SailorConfig.lean_feel_time_s;
## GP0 measured level 2 with 2.0 s), so a gust heels the board past the technique's rail and your
## toes and heels hold it.
const SLOW_FEEL_TIME_S: float = 2.0
## With the windward rail on, the heels press on until the windward rail is this far down (GP0's
## follow-up sailed the reach check with 4 degrees of windward rail: gp0_measure.md). Off, they stop
## at a flat board.
const WINDWARD_RAIL_DEG: float = 4.0
## The heels' press eases off over the last degrees before the board is where the far side ends (flat,
## or the windward rail), so it comes to rest there instead of pressing past it.
const FAR_SIDE_EASE_DEG: float = 2.0

# --- The settings (SettingsValues, section "body"; the defaults are the lead's recommendations) ---
var centre: Centre = Centre.STAYS
## SPRINGS_BACK: the time in which the mouse comes back to the middle (95 % of the way).
var spring_back_s: float = 1.5
var sideways: Sideways = Sideways.AS_SEEN
## Whether the heels go on past a flat board to the windward rail down (to windward_rail_deg).
## Off: the far side ends at a flat board (the design's "the other way flat"). A windward rail is
## slower everywhere once planing (GP0's follow-up), and the hull's heeled lift is still uncertain (PH27).
var windward_rail: bool = false
var windward_rail_deg: float = WINDWARD_RAIL_DEG
## The toes and heels: how much of a full press the mouse at the end of its travel asks (1: all of it,
## the bank 10 degrees past the technique's, SailorConfig.feet_press_rail_deg; the setting "Toes and
## heels").
var toes_share: float = 1.0
## The back and front foot: how much of the weight the mouse at the end of its travel moves onto that
## foot's strap (1: all of it; the setting "Back foot").
var weight_share: float = 1.0
## Mouse travel from one end of the range to the other, in pixels (the design: about 300).
var travel_px: float = 300.0
## 1: the feet still correct the rail themselves within 0.4 s; 2: slowed to SLOW_FEEL_TIME_S.
var level: int = 1
## A body set by a script (the harness, the LAN test's --body): it stays exactly where it was put;
## the mouse, the spring and the re-centring leave it alone.
var scripted: bool = false

# --- Where the body is ---
## Sideways, -1 (the mouse all the way left) to +1 (all the way right); 0 is the middle.
var side: float = 0.0
## Fore and aft, -1 (the mouse pushed all the way forward: weight forward) to +1 (pulled all the way
## back: weight on the tail); 0 is the middle.
var back: float = 0.0

## What the body asks of the feet at the last update (SimControls.feet_roll_press and
## feet_pitch_press, -1 to +1): the toes (+, the leeward rail down) against the heels, and the back
## foot (+, the weight on the back strap) against the front foot.
var roll_press: float = 0.0
var pitch_press: float = 0.0
## Whether the body pressed at the last update (false in a manoeuvre), and the tack it last pressed
## on (+1 starboard, -1 port, 0 not yet): for the gauge (ui/body_gauge.gd).
var working: bool = false
var last_tack: float = 0.0


## The mouse moved (pixels, as Godot reports a captured mouse's motion: x to the right, y down,
## so pulling the mouse toward you is +y, the weight back).
func move(relative: Vector2) -> void:
	if scripted:
		return
	var per_px: float = 2.0 / maxf(travel_px, 1.0)
	side = clampf(side + relative.x * per_px, -1.0, 1.0)
	back = clampf(back + relative.y * per_px, -1.0, 1.0)


## Back to the middle: the sailor's own technique (at a tack, a gybe, a fall, a restart).
func recentre() -> void:
	if scripted:
		return
	side = 0.0
	back = 0.0


## SPRINGS_BACK: the body slides back toward the middle, 95 % of the way in spring_back_s
## (an exponential: quick at first, gentle at the end, like a spring with a damper).
func spring(dt: float) -> void:
	if scripted or centre != Centre.SPRINGS_BACK:
		return
	var keep: float = exp(-3.0 * dt / maxf(spring_back_s, 0.05))
	side *= keep
	back *= keep


## How much more leeward rail the body asks for, -1 (the far side) to +1 (the most), on this tack
## (tack +1: starboard tack, the wind from the right, the leeward rail the port one).
func more_rail(tack: float) -> float:
	if sideways == Sideways.RIGHT_IS_MORE_RAIL:
		return side
	# As seen from behind: right puts the starboard rail down. That is the leeward rail on port
	# tack and the windward one on starboard tack.
	return -side * signf(tack) if tack != 0.0 else 0.0


## Which way the mouse goes for more leeward rail on the last tack aimed on: +1 right, -1 left,
## 0 not known yet (the gauge marks that side).
func rail_side() -> float:
	if sideways == Sideways.RIGHT_IS_MORE_RAIL:
		return 1.0
	return -signf(last_tack)


## The toes against the heels, -1 to +1 (SimControls.feet_roll_press), on this tack and with the
## board heeled this far to leeward (degrees). Toward more rail the toes press, up to toes_share of a
## full press at the end of the travel. The other way the heels press, easing off over the
## last FAR_SIDE_EASE_DEG before the board is flat (or, with windward_rail, before the windward rail
## is windward_rail_deg down), so they bring it there and no further.
func toes_press(tack: float, leeward_heel_deg: float) -> float:
	var r: float = more_rail(tack)
	if r >= 0.0:
		return r * toes_share
	var far_deg: float = -windward_rail_deg if windward_rail else 0.0
	return r * toes_share * clampf((leeward_heel_deg - far_deg) / FAR_SIDE_EASE_DEG, 0.0, 1.0)


## The back foot against the front foot, -1 to +1 (SimControls.feet_pitch_press): back times
## weight_share.
func back_foot_press() -> float:
	return back * weight_share


## Works out and remembers what the body asks of the feet this tick, on this tack (+1 starboard, -1
## port) with the board heeled this far to leeward (degrees). Read roll_press and pitch_press.
func press(tack: float, leeward_heel_deg: float) -> void:
	roll_press = toes_press(tack, leeward_heel_deg)
	pitch_press = back_foot_press()
	working = true
	last_tack = tack


## No body this tick (in a manoeuvre): the feet press as the technique wants.
func rest() -> void:
	working = false
	roll_press = 0.0
	pitch_press = 0.0


## The feet's correction time for this level: the sailor's own (own_s) at level 1, slowed to
## SLOW_FEEL_TIME_S at level 2 (never quicker than the sailor's own).
func feel_time_s(own_s: float) -> float:
	return maxf(own_s, SLOW_FEEL_TIME_S) if level >= 2 else own_s


## Takes the settings from the menu (the body's place stays where it is).
func configure(values: SettingsValues) -> void:
	centre = values.body_centre as Centre
	spring_back_s = values.body_spring_s
	sideways = values.body_sideways as Sideways
	windward_rail = values.body_windward_rail
	toes_share = values.body_toes_share
	weight_share = values.body_weight_share
	travel_px = values.body_travel_px
	level = values.body_level


## One line for the F1 panel (the numbers are for tuning only; the gauge shows the same in words).
func describe() -> String:
	var how: String = "stays" if centre == Centre.STAYS else "springs back in %.1f s" % spring_back_s
	if scripted:
		how = "held by script"
	var keys: String = "" if scripted else "   Esc frees the mouse, right button or C looks around"
	return "mouse body (level %d, %s) at side %+.2f back %+.2f: %s %.0f %%   %s %.0f %%%s" % [
		level, how, side, back, "toes" if roll_press >= 0.0 else "heels", absf(roll_press) * 100.0,
		"back foot" if pitch_press >= 0.0 else "front foot", absf(pitch_press) * 100.0, keys]


## The sailor's own leeward rail on this course, degrees, at a full hike in the straps: the same
## rule as the simulation's (WindsurferSim._rail_bank_deg_by_point_of_sail(), PH28 and U2), from the
## sailor's config and the true wind angle at the sail. More toward the wind (fin_load_bank_upwind_deg
## up to fin_load_twa_upwind_deg, falling to fin_load_bank_deg at a beam reach), fin_load_bank_deg
## across, fading to flat from fin_load_twa_max_deg less fin_load_twa_fade_deg. A unit test holds it
## to the simulation's own answer.
static func technique_rail_deg(sailor: SailorConfig, twa_deg: float) -> float:
	var twa: float = absf(twa_deg)
	var share: float
	if sailor.fin_load_twa_fade_deg <= 0.0:
		share = 1.0 if twa < sailor.fin_load_twa_max_deg else 0.0
	else:
		share = clampf((sailor.fin_load_twa_max_deg - twa) / sailor.fin_load_twa_fade_deg, 0.0, 1.0)
	var across_deg: float = sailor.fin_load_bank_deg * share
	if sailor.fin_load_bank_upwind_deg <= 0.0:
		return across_deg
	var toward_the_wind: float = clampf((90.0 - twa) / maxf(90.0 - sailor.fin_load_twa_upwind_deg, 1.0), 0.0, 1.0)
	return lerpf(across_deg, sailor.fin_load_bank_upwind_deg, toward_the_wind)


## The sailor's own trim while planing, degrees: the same rule as the simulation's
## (WindsurferSim._running_trim_target_deg(), U2): running_trim_deg up to running_trim_fast_speed_ms,
## falling to running_trim_fast_deg at running_trim_fastest_speed_ms. A unit test holds it to the
## simulation's own answer.
static func technique_trim_deg(sailor: SailorConfig, speed_ms: float) -> float:
	var slow: float = sailor.running_trim_fast_speed_ms
	var span: float = sailor.running_trim_fastest_speed_ms - slow
	var share: float = clampf((speed_ms - slow) / span, 0.0, 1.0) if span > 0.0 else (1.0 if speed_ms >= slow else 0.0)
	return lerpf(sailor.running_trim_deg, sailor.running_trim_fast_deg, share)
