class_name MouseBody
extends RefCounted
## Package B, an experiment: the sailor's body on the mouse (ROADMAP GP2; the design is
## Documentation/reports/playtest/feedback_5_november_2026.md, section 5, and the report of this
## build is Documentation/reports/gameplay/gp2_mouse_body.md).
##
## While sailing the mouse is captured and stands for the sailor's body:
## - sideways is the rail: how far the feet let the leeward rail go down (the bank the feet aim for
##   while hiked out in the straps and not turning);
## - forward and back is the back foot: pull the mouse back (toward you) and the weight goes onto the
##   tail, the nose lifts (more trim); push it forward and the weight goes forward (less trim).
## The mouse left in the middle is the sailor's own technique, as in 0.1.
##
## Nothing here touches the physics. The body only works out two numbers that the push slider
## already uses (SimControls.rail_bank_extra_deg and trim_aim_extra_deg, PH3: degrees on top of the
## technique's own bank and trim); PlayerController adds them to the slider's every tick. What the
## rail and the back foot then do (faster, bouncing, a catapult, a slower railed board) is the
## simulation's own answer: no new forces, nothing scripted. The simulation only aims for these
## targets while planing in the straps and not turning, so the mouse does nothing below planing or in
## a manoeuvre.
##
## The ranges stay inside what GP0 measured (Documentation/reports/gameplay/gp0_measure.md): the
## rail 0 to 8 degrees (beyond 8 is only slower), the trim 0.5 to 3.5 degrees. Max's open choices
## (ROADMAP GD7, the design's "open choices") are settings, with the lead's recommendation as the
## default, so they can be switched while playing.

## What the mouse does when you leave it alone (GD7 a). STAYS: it stays where you put it (holding
## an angle is the point), and it comes back to the middle (the technique) at every tack, gybe and
## fall. SPRINGS_BACK: it also slides back to the middle by itself, over spring_back_s.
enum Centre { STAYS, SPRINGS_BACK }
## Which way sideways means more rail (GD7 b). AS_SEEN: the board rolls the way the mouse moves,
## as seen from behind the board (the follow camera): right puts the starboard rail down. On
## starboard tack (the wind from the right) the leeward rail is the port one, so there left is more
## rail; on port tack right is. RIGHT_IS_MORE_RAIL: right is always more leeward rail.
enum Sideways { AS_SEEN, RIGHT_IS_MORE_RAIL }

## GP0's measured bands: the most rail worth having (beyond it only slower) and the trim from the
## flattest to the most nose-up tried. The mouse never asks for more than these, so it cannot ask
## for what the feet cannot hold.
const RAIL_MAX_DEG: float = 8.0
const TRIM_MIN_DEG: float = 0.5
const TRIM_MAX_DEG: float = 3.5
## Level 2: the feet's own correction of the rail slowed to this (SailorConfig.lean_feel_time_s;
## GP0 measured level 2 with 2.0 s), so a gust heels the board past the angle and your hand holds it.
const SLOW_FEEL_TIME_S: float = 2.0
## With the windward rail on, the far side's windward rail, degrees (GP0's follow-up sailed the
## reach check with 4 degrees of windward rail: Documentation/reports/gameplay/gp0_measure.md).
const WINDWARD_RAIL_DEG: float = 4.0

# --- The settings (SettingsValues, section "body"; the defaults are the lead's recommendations) ---
var centre: Centre = Centre.STAYS
## SPRINGS_BACK: the time in which the mouse comes back to the middle (95 % of the way).
var spring_back_s: float = 1.5
var sideways: Sideways = Sideways.AS_SEEN
## Whether the far side goes past a flat board to the windward rail down (to windward_rail_deg).
## Off: the far side is a flat board (the design's "the other way flat"). A windward rail is slower
## everywhere once planing (GP0's follow-up), and the hull's heeled lift is still uncertain (PH27).
var windward_rail: bool = false
var windward_rail_deg: float = WINDWARD_RAIL_DEG
## The most leeward rail the mouse adds to the technique's (the design: 0 to +6 degrees), never
## past RAIL_MAX_DEG in all.
var rail_more_deg: float = 6.0
## The back foot: the trim the mouse adds or takes away, either way (the design: 1.5; 1.0 is gentler).
var trim_range_deg: float = 1.5
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

## What the body asked for at the last update, in degrees on top of everything else (for the F1
## panel and the tests), and the totals the feet then aimed for (the technique, the slider and the
## body together).
var rail_deg: float = 0.0
var trim_deg: float = 0.0
var rail_total_deg: float = 0.0
var trim_total_deg: float = 0.0


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


## The rail the body adds, degrees, given the leeward rail the feet already aim for without it
## (the technique's on this course, the slider's and the sea's together). Toward more rail: up to
## rail_more_deg, never past RAIL_MAX_DEG in all. The other way: the whole travel takes the board to
## flat (or, with windward_rail, on to windward_rail_deg of windward rail).
func rail_extra_deg(base_deg: float, tack: float) -> float:
	var r: float = more_rail(tack)
	if r >= 0.0:
		var room: float = maxf(RAIL_MAX_DEG - base_deg, 0.0)
		return minf(r * rail_more_deg, room)
	var far_deg: float = -windward_rail_deg if windward_rail else 0.0
	return r * maxf(base_deg - far_deg, 0.0)


## The trim the back foot adds, degrees, given the trim the feet already aim for without it (the
## technique's by speed and the slider's): back * trim_range_deg, kept inside GP0's band
## TRIM_MIN_DEG to TRIM_MAX_DEG (where the base itself is outside the band, the body only brings it
## back toward the band, never further out).
func trim_extra_deg(base_deg: float) -> float:
	var lowest: float = minf(TRIM_MIN_DEG - base_deg, 0.0)
	var highest: float = maxf(TRIM_MAX_DEG - base_deg, 0.0)
	return clampf(back * trim_range_deg, lowest, highest)


## Works out and remembers the body's two numbers for this tick (see rail_extra_deg and
## trim_extra_deg). Returns nothing; read rail_deg and trim_deg.
func aim(rail_base_deg: float, trim_base_deg: float, tack: float) -> void:
	rail_deg = rail_extra_deg(rail_base_deg, tack)
	trim_deg = trim_extra_deg(trim_base_deg)
	rail_total_deg = rail_base_deg + rail_deg
	trim_total_deg = trim_base_deg + trim_deg


## No body this tick (in a manoeuvre, out of the water): nothing added.
func rest(rail_base_deg: float, trim_base_deg: float) -> void:
	rail_deg = 0.0
	trim_deg = 0.0
	rail_total_deg = rail_base_deg
	trim_total_deg = trim_base_deg


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
	rail_more_deg = values.body_rail_deg
	trim_range_deg = values.body_trim_deg
	travel_px = values.body_travel_px
	level = values.body_level


## One line for the F1 panel (the numbers are for tuning only; the strip shows nothing).
func describe() -> String:
	var how: String = "stays" if centre == Centre.STAYS else "springs back in %.1f s" % spring_back_s
	if scripted:
		how = "held by script"
	var keys: String = "" if scripted else "   Esc frees the mouse, right button or C looks around"
	return "mouse body (level %d, %s) at side %+.2f back %+.2f: rail %+.1f deg (aim %.1f)   back foot %+.1f deg (trim aim %.1f)%s" % [
		level, how, side, back, rail_deg, rail_total_deg, trim_deg, trim_total_deg, keys]


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
