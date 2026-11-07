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
## Space tacks or gybes for you; with A or D held the key chooses: toward the wind a tack, away
## from it a gybe (turn_key_chooses).
## Advanced mode: Q/E rake the rig forward and back, Left/Right tilt it sideways and A/D
## move the sailor's weight to port and starboard, all raw, on top of the balance reflex.
## Space still helps with the tack.
## Up/Down sheet in and out in both modes; T toggles an automatic sheet, which is on by default
## in beginner mode (Up/Down then override it for a few seconds). In beginner mode the sailor
## also eases the sheet by themselves when the pull is more than they can hold, which is
## what every sailor does before a catapult. Tab switches modes.
## W/S move the push slider (push_level): how hard the sailor commits, from standing still
## with the sail let fly to the most speed with a crash likely (PushDial, the ladder in
## PushCurveConfig; Documentation/reports/push_slider/PLAN.md).
## The mouse can be the sailor's body (package B, an experiment, the setting "Mouse body"):
## sideways the toes against the heels, forward and back the back foot against the front foot, the
## feet pressing in the straps (body, MouseBody). The push is then on the mouse as well (the setting
## "Push on the mouse"): the wheel moves it in steps and the left button held is a burst to 100 %
## (push_now); W and S still work.

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
## Shift + A/D, the carve (Max, 7 November 2026: "we press and hold shift and steer to steer more
## sharply"): with Shift held the key asks for sharp_turn_factor times the turn rate, at any speed,
## and the head-up limit at speed widens by the same factor. The rail follows the rate asked (so a
## planing board banks into the sharp turn), times sharp_rail_gain while the planing technique is in
## use. Into a Space tack or gybe with the key held toward the turn, Shift multiplies the key's rate
## by sharp_manoeuvre_factor and the manoeuvre's caps (gybe_rate_max_dps, tack_rate_max_dps) by
## sharp_cap_factor. Plain A/D is unchanged. Night of 7 November: these are tuned by
## tools/night_tuner.py (Documentation/reports/autopilot/night_7nov/).
var sharp_turn_factor: float = 2.25
var sharp_rail_gain: float = 1.0
var sharp_manoeuvre_factor: float = 1.5
var sharp_cap_factor: float = 1.25
var _sharp: bool = false
## A short A/D tap (Max, 7 November 2026: "we do taps now it disbalances the character"): the key is
## shaped into a ramp, steer_rise_s from nothing to full and steer_fall_s back (0: the key as it is),
## so a tap asks for a small, smooth turn; and the rail's share of the turn grows with how long the
## key has been held, full after tap_rail_full_s, so a tap steers with the rig and does not throw the
## sailor's weight onto a rail. An AI's stick goes through the same ramp (one controller for all).
var steer_rise_s: float = 0.2
var steer_fall_s: float = 0.0625
var tap_rail_full_s: float = 0.85
var _steer_smooth: float = 0.0
var _key_held_s: float = 0.0
## Getting on the plane (Max, 7 November 2026: "better getting on plane technique"): below planing
## speed, on a course closer to the wind than plane_bear_away_to_twa_deg, the heading hold aims up to
## plane_bear_away_deg further off the wind (a sailor bears away to a broad reach to get going, then
## comes back up): all of it below plane_help_full_ms, none from plane_help_until_ms. Only the
## heading hold does this (no key held): a key held is the player's own course. 0: off.
var plane_bear_away_deg: float = 0.0
var plane_bear_away_to_twa_deg: float = 125.0
var plane_help_full_ms: float = 4.0
var plane_help_until_ms: float = 8.5
## Steering below the plane (Max: "better non planing steering"): the turn-rate loop's gains
## (rate_gain, rate_integral_gain) and the heading hold's rate per degree (hold_rate_per_deg) times
## these below planing_steer_from_ms - 2 m/s, blending to the planing numbers at planing_steer_from_ms.
## 1: as before.
var slow_rate_gain_scale: float = 1.675
var slow_integral_scale: float = 0.325
var slow_hold_scale: float = 1.4
## In the air (Max: "more control on high speeds while flying"): while the board is light over a
## crest (see airborne_alpha_deg), the turn-rate loop's helm is held this much (0: as before, 1: the
## helm and its trim held where they are, the yaw in the air not chased).
var airborne_helm_hold: float = 0.0
## Heading up is slower at speed: the board turning toward the wind must be banked to
## windward against the centripetal force, with the hike that the sail already uses, so the
## rate is held to head_up_rate_budget over the speed (at least head_up_rate_min). At planing
## speed the floor rules (from 8.3 m/s), and it is not what made heading up there sluggish (the
## auto-sheet's easing was: Autopilot.windward_bank_to_come_deg). Measured (the steering check,
## Documentation/reports/push_slider/steering.md): a powered board in this sim hardly banks to
## windward (0 to 2 degrees where a carved head-up asked for 20 to 30), so the push of the turn is
## taken by the hike, and the sailor is pulled over the sail at a felt heel of 20 degrees
## (SailorConfig.catapult_heel_deg) once the turn is faster than g tan(20) / v: 15 degrees per
## second at 13.8 m/s, 13 at 15.7. Raised to the rate a 30 degree bank would carry (23 and 21),
## the sailor fell at 18 and 24 kt; the floor of 12 sits just under that limit, and at 12 the
## head-up at 18 and 24 kt is now as quick as at 12 kt.
var head_up_rate_budget_dps_ms: float = 160.0
var head_up_rate_min_dps: float = 12.0
var hold_rate_per_deg: float = 0.8
var hold_rate_limit_dps: float = 20.0
## When the hold re-arms the board may still be swinging; the held heading is set a little
## ahead (at most hold_lead_max_deg), where the board will be once it has settled, so the
## helm is not slammed back.
var hold_lead_s: float = 0.0
var hold_lead_max_deg: float = 10.0
var rate_gain: float = 0.01525
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
var carve_rate_dps: float = 45.75
## After a manoeuvre at planing speed (above settle_speed_ms) the board is left to
## straighten by itself (rig neutral, weight off the rails) until it turns slower than
## settle_rate_dps; only then does the heading hold take over. A hold that grabbed a board
## still carving at 60 degrees per second would throw the rig the other way and the sailor
## off. Slower, there is no carve to wait for and an eased sail only rounds the board up.
var settle_rate_dps: float = 15.0
var settle_speed_ms: float = 5.0
var _settling: bool = false
## Space tacks from a beam reach and anything closer to the wind, gybes from further off.
var tack_up_to_twa_deg: float = 100.0
## The player's turn key chooses (Max, 6 November 2026: "downwind button (a/d) while pressing space
## to gybe instead of heading. now sometimes it tacks when we want to gybe"): Space with A or D held,
## or with A or D pressed within choose_grace_s after Space, turns the way the key says, toward the
## wind a tack and away from it a gybe, from any course. With neither held the heading decides
## (tack_up_to_twa_deg). Only the player's keys: an AI skipper's hands keep the heading's rule.
var turn_key_chooses: bool = true
var choose_grace_s: float = 0.3
var _choose_grace_left_s: float = 0.0
## The interactive tacks and gybes (Max, 6 November 2026: "more interactive gybes and tacks";
## Documentation/reports/gameplay/gp_manoeuvres_6nov.md). Three parts, each a setting (Settings >
## Sailing), on by default, and each only the player's: an AI skipper's hands sail the manoeuvres
## exactly as before. A player who does nothing gets round exactly as before too.
## 1. The turn follows the hand: in a tack or gybe the turn key held toward the turn asks for
## key_gybe_rate_dps or key_tack_rate_dps instead of the manoeuvre's own rate (gybe_rate_dps,
## tack_rate_dps; a gybe's exit, once the sail is across, always at its own rate); let go, the turn goes on at its own rate; the other key (after the choosing
## window) eases the turn out and gives the manoeuvre up, the rig back to neutral as after the
## timeout, and the key then steers as on a reach.
var turn_follows_key: bool = true
var key_gybe_rate_dps: float = 40.0
var key_tack_rate_dps: float = 24.0
## 2. The body carves (with the mouse body on): in a tack or gybe the mouse sideways toward the
## inside of the turn (as seen from behind the board: the way the board turns; the rail that goes
## down in the turn, the toes in a gybe and the heels in a tack) tightens the turn by up to
## body_carve_share of its rate; toward the outside it flattens the board and widens the turn as
## much. The rail follows the rate (the simulation banks the board for the turn asked, its own
## rule). In a gybe forward and back press the feet as on a reach: the back foot lifts the nose
## through it, the front foot puts it down (the simulation presses only planing in the straps). The body stays where it is through the manoeuvre and goes back to the middle at its end.
## The turn is never asked faster than gybe_rate_max_dps or tack_rate_max_dps, key and body
## together. The limits are measured (the manoeuvre matrix with waves at 12, 18 and 24 kt, three
## wave timings, gp_manoeuvres_6nov.md): a gybe at 45 degrees a second fell 1 to 2 times in 45 (a
## catapult bearing away from a beam reach at 24 kt), at 40 none; a tack's carve at 20 none, at
## 22.5 to 30 it catapulted at 24 kt. The key and the body act only into the turn: a gybe until the sail is across, a tack
## until the rig is; the way out goes at the manoeuvre's own rate.
var body_in_manoeuvres: bool = true
var body_carve_share: float = 0.33
var gybe_rate_max_dps: float = 40.0
var tack_rate_max_dps: float = 23.75
## 3. The flip on your cue: in the window before the rig goes across by itself (a gybe: from
## gybe_cue_from_twa_deg of true wind angle on; a tack: once the bow is tack_cue_through_deg
## through the wind and the sail would fill on the new side; by itself at Autopilot.flip_twa_deg,
## 25), a second Space puts it across now. Without a cue it goes across by itself,
## as before. After a cue the rig is held on the new side (SimControls.hold_side) until the wind
## keeps it there (at most cue_hold_max_s).
var flip_on_cue: bool = true
var gybe_cue_from_twa_deg: float = 175.0
var tack_cue_through_deg: float = 18.0
var cue_hold_max_s: float = 3.0
var _cue_window_open: bool = false
var _cue_given: bool = false
var _cue_side: int = 0
var _cue_hold_left_s: float = 0.0
## The pilot's own flip angle while a tack's cue has lowered it (NaN otherwise).
var _own_flip_twa_deg: float = NAN
## The angle of attack the sail is eased to through a gybe.
var gybe_entry_alpha_deg: float = 8.0
var helm_rate_per_s: float = 2.625
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

## The auto-sheet pilot's margin set from outside, field by field (hike_share, the depower and
## catch settings of Autopilot): GP1's push dial will write it here; until then GP0's playtest sets
## it from the command line (main.gd, --push=1 or --pilot.<field>=<n>). Applied at every update,
## because reset_controls() makes a new pilot after a waterstart. Empty: the pilot's own numbers.
var pilot_overrides: Dictionary[String, float] = {}

## The push slider (ROADMAP GP1; Documentation/reports/push_slider/PLAN.md): the level from 0
## (standing still, the sail let fly) to 1 (the most speed, a crash likely), turned into the
## pilot's margin and the sailor's technique every update through PushDial and the ladder in
## push_curve (the default curve when null). NaN = no slider: the pilot's own numbers, as before
## (the AI boards and the tests until the fleet adopts it). W and S move it at
## push_rate_per_s (a full range in 2.5 s); an AI skipper's hands set it (AiHands.push). It keeps
## its level through resets and waterstarts. Hands that set NaN again let go of it: the pilot's own
## numbers come back (_release_the_slider()), so a skipper can push where it pays and sail the
## pilot's own margin elsewhere.
var push_level: float = NAN
var push_curve: PushCurveConfig = null
var push_rate_per_s: float = 0.4
## The level the sailor is at now: what is applied to the pilot and the controls, and where the
## gauge's needle points. It is push_level, except while the body's burst is held (the left mouse
## button, MouseBody.burst_held: "push on the mouse"), when it goes to 100 %, and let go it comes
## back to push_level. It gets there at push_mouse_rate_per_s (the full range in 1 s, two and a half
## times the keys' pace: from the 75 % start to 100 % in a quarter of a second, a pump's quick
## commit), so the rig's extra lean of the top of the ladder (10 degrees) comes in over that time and
## not in one tick; a notch of the wheel likewise takes a tenth of a second. The keys move push_level
## slower than that, so with W and S it is push_level exactly. An AI skipper's hands: push_level,
## always. NaN with no slider.
var push_now: float = NAN
var push_mouse_rate_per_s: float = 1.0
## In a burst: from the button pressed until the sailor is back at push_level after it is let go
## (is_bursting(); a notch of the wheel down is not a burst).
var _in_burst: bool = false
## The legs in the beginner's turn loop (PH35, the push slider plan, round 3): how much of the
## helm the back foot carries by pushing the sideways hold against its strap (Helm), beside the
## rake, the tilt and the rail; the sim applies it only in the straps. 0 = as before.
var legs_share: float = 0.0
## The planing technique (Michiel, 31 October 2026: "when planing and standing in the footstraps
## the steering comes more from pushing and pulling of the two legs and less from moving around
## the sail"; Documentation/reports/push_slider/steering.md). The legs carry the turn first: the
## back foot (heading up) or the front foot (bearing away) pushes at once on the loop's rate error,
## legs_rate_gain of a full push per degree per second of it, as the quick part of the helm; the
## rig's trim follows only as the error lasts and carries a long turn, so the rig moves less and
## later. Pushed alone at planing speed, with the rig held, a full push turned the board at 8 to 30
## degrees per second within half a second (the steering check's probe, 18 and 24 kt), so a full
## push answers about the 12 degrees per second a head-up asks (head_up_rate_min_dps): 1 / 12. Twice
## that gain turned no faster and moved the rig more (the same check). On a steady course the
## error is nil and the back foot is the push slider's (back_foot_bias), not the steering's.
## The technique comes in between planing_steer_from_ms and planing_steer_full_ms, times how far
## the feet are in the straps (Telemetry.stance): 35 to 40 km/h, the speed from which Max pushes
## the back foot against the fin "with all the strength I have"
## (Documentation/reports/ph28/questions_for_max.md, question 2). The steering check's 12 kt reach
## sails at 8.0 m/s (29 km/h), below it, and steers exactly as before; its 18 and 24 kt reaches
## at 13.8 and 15.7 m/s. legs_rate_gain 0 turns it off.
var planing_steer_from_ms: float = 9.7
var planing_steer_full_ms: float = 11.1
var legs_rate_gain: float = 1.0 / 12.0

## Package B, an experiment: the sailor's body on the mouse (MouseBody, mouse_body.gd; ROADMAP GP2).
## Sideways the toes against the heels, forward and back the back foot against the front foot: the
## feet's press, written every update (_move_the_body()). It comes back to the middle (the technique) at every tack, gybe and
## reset. null: no body (the AI boards, the tests, and the player with the setting off), and the
## controller is exactly as before.
var body: MouseBody = null
var _body_was_on: bool = false

## Beginner mode holds the heading when no steering key is pressed.
var hold_heading: bool = true
## The trim, kept as "heading up" so that it stays right when the tack changes.
var _helm_trim_up: float = 0.0
## The autopilot that trims the sheet when auto_sheet is on. Give it the simulation's sail
## (auto_sheet_pilot.sail) and it sheets for the most drive instead of a fixed angle.
var auto_sheet_pilot: Autopilot = Autopilot.new()
## An AI skipper's hands on the controls (RACING_PLAN.md, RD1). While set, the controller
## reads steer, sheet and tack from here and ignores the keyboard.
var hands: AiHands = null
## The player's board also gets hands for a while: a network game's menu (still hands), the race
## director's view (an all-rounder sails), the LAN test's robot. The slider level the board had when
## hands took it is kept here and put back when they let go (_slider_back_after_hands()), so the
## gauge, W, S and the wheel work again (Max, 6 November 2026: "push slider is gone").
var _level_before_hands: float = NAN
var _had_hands: bool = false
## The hold-back skill (AiHands.hold_speed_ms; AI_FLEET_PLAN.md, D1): the auto-sheet is let
## trim no closer than an angle of attack that a speed loop sets (Autopilot.max_alpha_deg, the
## sailor easing on purpose). The sail eases by hold_back_gain_deg_per_ms degrees for every m/s
## the board is too fast, and the loop's trim keeps easing by hold_back_trim_dps_per_ms degrees
## per second per m/s, so that the board settles at the wanted speed. Never further out than
## hold_back_min_alpha_deg (the sail still draws a little), and never so slow that the fin
## stops gripping: below hold_back_steerage_ms the loop sheets in whatever was asked, because
## a board without way on cannot be steered and rounds up into the wind. The sailor judges the
## speed hold_back_lead_s ahead (the speed now plus how fast it is changing): a board slowing
## fast is sheeted in before it gets too slow, or it stops.
var hold_back_gain_deg_per_ms: float = 4.0
var hold_back_trim_dps_per_ms: float = 3.0
var hold_back_min_alpha_deg: float = 2.0
var hold_back_max_alpha_deg: float = 20.0
var hold_back_steerage_ms: float = 1.5
var hold_back_lead_s: float = 1.5
## The trim of the hold-back loop (degrees of angle of attack), whether it is holding back, and
## the speed at the last update and how fast it changes (m/s2, smoothed over half a second).
var _hold_trim_deg: float = 0.0
var _holding_back: bool = false
var _hold_last_speed_ms: float = 0.0
var _hold_acceleration_ms2: float = 0.0

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


## Sailing in chop (Documentation/reports/autopilot/lake_chop_training.md). The defaults are the lake
## training's choice (6 November 2026, round 4's c2hu10, with the rail's fade lowered for the fleet's
## start): the ease while carving up at speed (for a key or a tack), no rail at walking pace, the ease
## in the air in strong wind and short chop with the sail back in fast on landing. On Lake Silvaplana's waves it fell in none of the 130 cases the rounds tuned
## on (the controller before: 26) and in 6 of 180 on six other hours (before: 29), with the afternoon
## reaches and the open water's push check as fast as before. Less pull in chop (chop_hike_drop) and
## waiting for the wave (manoeuvre_wait_max_s) are built and off: the rounds found no gain in them.
## The rail at low speed: the weight goes on the inside rail for a turn only as the board has speed,
## faded in from rail_from_ms to rail_full_ms. A board at walking pace does not carve, and in chop a
## sailor standing on the windward rail of a slow board with a luffing sail is tipped off it (the
## lake matrix's out-of-irons case: the board rolled to 50 degrees at 2 km/h and the sailor fell
## off). Faded in from 2 to 5 m/s it also slowed the AI's turns while holding back before a start (a
## rookie over the line in the fleet's validation test); from 0.3 to 1 m/s it still keeps the board out
## of irons upright (18 lake cases, no fall) and the fleet's start is as before. Both 0: the rail at
## every speed.
var rail_from_ms: float = 0.3
var rail_full_ms: float = 1.0
## Heading up on purpose at speed (a tack's carve up to the wind, or a key held toward the wind):
## the auto-sheet trims no closer than head_up_alpha_deg of angle of attack, from head_up_ease_from_ms
## on. The turn's push is felt as heel to leeward (atan(v w / g): 15 degrees at 15 degrees per second
## and 11 m/s), and in chop the board's roll adds as much again, so a fully trimmed sail catapults
## the sailor out of the carve; a sailor carving up into a tack in chop eases a little. 90: no ease.
var head_up_alpha_deg: float = 9.0
var head_up_ease_from_ms: float = 7.0
## Whether the heading hold's own corrections toward the wind count as heading up (true), or only a
## key held (or a tack) does (false). In chop the hold corrects all the time (the waves yaw the board
## 20 to 45 degrees a second), so with true the ease also comes on in straight sailing.
var head_up_ease_on_hold: bool = false
## The turn toward the wind that counts as heading up on purpose, degrees a second. An AI skipper's
## hands steer with a stick all the time (AiHands), so small corrections toward the wind would ease
## the sheet too; a real head-up asks for more.
var head_up_ease_from_dps: float = 10.0
## The turn key held at this update (beginner mode), +1 right, -1 left, 0 none.
var _turn_key: float = 0.0
## The pull held in chop: the pilot's hike_share times (1 - chop_hike_drop) when the board bounces
## (the pitch rate's RMS that Autopilot.feel_the_sea() feels) at chop_bounce_full_dps or more, none
## at chop_bounce_from_dps or less, straight between: more margin when it gets wild, the full pull on
## flat water. 0: no drop.
var chop_hike_drop: float = 0.0
var chop_bounce_from_dps: float = 4.0
var chop_bounce_full_dps: float = 12.0
## The auto-sheet pilot's hands on the sheet (Autopilot.sheet_rate_per_s, the share of the sheet's
## whole range moved in a second), set on the pilot at every update (before the slider and the
## --pilot. overrides, which win). The pilot's own 1.5 moves the boom across its range in two thirds of
## a second; in chop the eases the pilot asks for (the felt heel, a gust, a wave's roll) came too late:
## at 2.5 the lake's 130 cases fell 8 times against 26, the map's 30 cases not at all, and the
## afternoons' reaches lost nothing (round 1 of the lake's training).
var pilot_sheet_rate_per_s: float = 1.5
## Timing a tack or gybe on the waves: at speed, Space starts the turn as the bow drops off a crest
## (the pitch rate nose-down beyond manoeuvre_wait_pitch_dps), waiting at most manoeuvre_wait_max_s.
## 0: at once, as before.
var manoeuvre_wait_max_s: float = 0.0
var manoeuvre_wait_pitch_dps: float = 5.0
var _manoeuvre_wait_s: float = 0.0
## Light over a crest: when the water carries less than airborne_support_share of the board's whole
## weight (its buoyancy and planing lift: the board is leaving the water), and for airborne_hold_s
## after it lands again, the auto-sheet trims no closer than airborne_alpha_deg. In the air nothing
## holds the board against the sail's side force, so it is pulled sideways and rolled to leeward and
## the sailor, falling with it, is pulled over the sail: the steady 24 kt beam reach on the lake left
## the water three times in 1.5 s and the third catapulted (the felt heel from 9 to 34 degrees in
## 0.3 s). A sailor sheets out on a jump. 90: no ease.
var airborne_alpha_deg: float = 12.0
var airborne_support_share: float = 0.2125
var airborne_hold_s: float = 0.05
## The ease only for a real jump, not every skip off a crest: once the board has been light for
## airborne_after_s, and only while the felt heel to leeward is beyond airborne_heel_from_deg (-90:
## whatever the heel). The ease costs drive: eased at every skip the steady 24 kt reach lost a fifth
## of its speed.
var airborne_after_s: float = 0.0
var airborne_heel_from_deg: float = -90.0
## Only in strong wind: the ease comes in as the true wind at the sail rises from
## airborne_wind_from_kt to airborne_wind_full_kt (none below: the angle of attack is then left as
## the pilot trims it). In the map's wind (up to about 18.5 kt at the sail) the lake's reaches never
## fell in 40 runs and the ease cost them 3 to 4 kt; in a steady 24 kt (about 20 kt at the sail) the
## beam reach catapulted in two of three runs without it. Both 0: at every wind.
var airborne_wind_from_kt: float = 18.0
var airborne_wind_full_kt: float = 20.0
## And only in short, steep chop: the ease comes in as the bounce felt (the pitch rate's RMS,
## Autopilot.felt_bounce_dps()) rises from airborne_bounce_from_dps to airborne_bounce_full_dps. The
## open sea's longer waves set the planing board pitching at 3.5 to 9 degrees a second (the push
## check's nine cases) and it does not fall there; the lake's chop at 10 to 17 (its telemetry). On
## the open sea the ease cost the 24 kt reaches up to 10 % of their speed made good for nothing. Both
## 0: in any sea.
var airborne_bounce_from_dps: float = 8.0
var airborne_bounce_full_dps: float = 12.0
## Back in on landing: the body stayed hiked out through the jump, so the sail may come back to where
## it was faster than the pilot's usual pace for sheeting in (Autopilot.sheet_in_share, which at 24 kt
## lets the angle of attack rise only 1 to 2 degrees a second: eased at every skip the sail never got
## back). While eased and for airborne_resheet_s after, the pilot's sheet_in_share is
## airborne_sheet_in_share. 0: the pilot's own pace.
var airborne_sheet_in_share: float = 3.0
var airborne_resheet_s: float = 1.0
var _airborne_for_s: float = 0.0
var _light_for_s: float = 0.0
var _resheet_for_s: float = 0.0
var _own_sheet_in_share: float = 0.5

## The recovery reflex (Max, 6 November 2026: "make the autopilot try harder to stay on the board";
## Documentation/reports/autopilot/stay_on_the_board.md). The sailor feels a fall coming before the
## fall rule fires: the heel to leeward, the windward tip and the body's tipping as shares of the
## limits the fall checks use now (Telemetry.lee_fall_share, windward_fall_share, tipping_share). From
## reflex_from_share of the way the hands and the feet fight it, harder the nearer the limit (all of it
## from reflex_full_share; the tipping from reflex_tip_from_share of what the hips hold):
## - pulled over the sail (to leeward): the sheet eased fast toward reflex_alpha_deg of angle of attack
##   (from reflex_last_share on reflex_last_alpha_deg, nearly let fly: the last chance), a bear-away of
##   up to reflex_bear_away_dps asked of the steering (not in a tack or a gybe, and not past
##   reflex_bear_away_max_twa_deg), and the heels pressed (reflex_heel_press) to flatten the board;
## - falling back (to windward, the pull gone on a hike): the sheet in fast, toward at least
##   reflex_catch_alpha_deg ("when in doubt, sheet in").
## The hands move the sheet at reflex_sheet_rate_per_s (a quick release of the back hand), and the
## danger felt fades over reflex_hold_s once it has passed; the pilot then sheets in again at its own
## pace from where the reflex left the sail. With the push slider above reflex_push_fade_from the
## reflex fades out, and at the top of the slider it is gone: the pushed dial keeps its risk.
## reflex_on false: the controller as before 6 November 2026, bit for bit.
var reflex_on: bool = true
var reflex_from_share: float = 0.5
var reflex_full_share: float = 0.9
var reflex_alpha_deg: float = 6.0
var reflex_last_share: float = 0.95
var reflex_last_alpha_deg: float = 1.0
var reflex_sheet_rate_per_s: float = 4.0
var reflex_bear_away_dps: float = 12.0
var reflex_bear_away_max_twa_deg: float = 130.0
var reflex_heel_press: float = 1.0
var reflex_catch_alpha_deg: float = 18.0
var reflex_tip_from_share: float = 0.7
var reflex_hold_s: float = 0.3
var reflex_push_fade_from: float = 0.8
## And the reflex fades away at low speed (Max, 6 November 2026, the night's play-test: "in low speeds
## the autopilot is moving a lot; these reflexes must fade away at low speeds"): nothing at and below
## reflex_fade_below_ms (walking pace), all of it from reflex_full_from_ms (about planing). A board at
## displacement speed is sailed calmly, as before the reflex.
var reflex_fade_below_ms: float = 3.0
var reflex_full_from_ms: float = 6.0
var _reflex_speed_share: float = 1.0
## And at walking pace: a board whose nose rises while it hardly moves (below reflex_slow_ms; the tail
## sinking under the sailor, a heavy sailor on a small board waiting for a start) gets the weight
## forward: the sailor steps toward the mast (SimControls.step_forward) from reflex_nose_up_deg of
## pitch, all the way from reflex_nose_up_full_deg. In the races of 6 November the nose of a 108 L
## board rose from 17 to 80 degrees in 7 s at 1 to 3 km/h with the sailor standing by the mast foot
## (the report, "the baseline").
## Only once the nose has stayed up past reflex_nose_up_deg for reflex_nose_up_hold_s: a board turning
## back at walking pace after being over the line early lifts its nose for a moment too, and a step
## forward then kept two of the fleet test's sixteen boards from starting again (round 3).
var reflex_slow_ms: float = 3.0
var reflex_nose_up_deg: float = 10.0
var reflex_nose_up_full_deg: float = 20.0
var reflex_nose_up_hold_s: float = 1.0
## The step forward only when asked for: off since the night of 6 November 2026, because it acts at
## walking pace, where Max wants the sailor calm. The AI's tail-stand at walking pace that it was built
## for is a buoyancy question for Michiel (stay_on_the_board.md, open question 2).
var reflex_step_forward: bool = false
var _nose_up_for_s: float = 0.0
## The danger felt now, 0 (none) to 1 (at the limit), toward the sail and away from it.
var lee_danger: float = 0.0
var windward_danger: float = 0.0

var _sail: SailModel = null
var _sailor: SailorConfig = null
var _air_density_kg_m3: float = 1.225
## The pull a fresh pilot holds (its own hike_share), for the chop's drop when no slider or override
## sets it.
var _own_hike_share: float = 1.1


func _init() -> void:
	auto_sheet_pilot.hold_course = false
	auto_sheet_pilot.trim_sheet = true
	_own_hike_share = auto_sheet_pilot.hike_share
	_own_sheet_in_share = auto_sheet_pilot.sheet_in_share


## Gives the controller the simulation's sail, so the auto-sheet trims for the most drive,
## and the air density it sails in (WindsurferSim.air_density_kg_m3).
func set_sail(sail: SailModel, sailor: SailorConfig = null, air_density_kg_m3: float = 1.225) -> void:
	_sail = sail
	_sailor = sailor
	_air_density_kg_m3 = air_density_kg_m3
	auto_sheet_pilot.sail = sail
	auto_sheet_pilot.sailor = sailor
	auto_sheet_pilot.air_density_kg_m3 = air_density_kg_m3


## Reads the keys and writes the controls: sheet, boom across, rake, rig tilt and lean.
func update(telemetry: Telemetry, controls: SimControls, dt: float) -> void:
	_move_the_slider(telemetry, controls, dt)
	auto_sheet_pilot.update_tack(telemetry)
	if reflex_on:
		_feel_the_fall(telemetry, dt)
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
			# A new tack: the body comes back to the sailor's own technique (GD7 a); a body that
			# carves the manoeuvre stays where it is until the manoeuvre's end.
			if body != null and not (manoeuvre != Manoeuvre.NONE and _body_carves()):
				body.recentre()
		_last_sail_side = telemetry.sail_side
	if _just_pressed("toggle_mode"):
		set_mode(Mode.ADVANCED if mode == Mode.BEGINNER else Mode.BEGINNER)
	if _just_pressed("toggle_autosheet"):
		auto_sheet = not auto_sheet
	_cue_window_open = _in_the_flip_window(telemetry)
	var space: bool = _just_pressed("tack")
	if space and manoeuvre == Manoeuvre.NONE:
		if manoeuvre_wait_max_s > 0.0 and telemetry.speed_ms > settle_speed_ms:
			_manoeuvre_wait_s = manoeuvre_wait_max_s
		else:
			_start_manoeuvre(telemetry)
	elif space and _cue_window_open:
		_give_the_cue(telemetry)
	_wait_for_the_wave(telemetry, dt)
	_choose_by_a_late_key(dt)

	# Steering.
	var steer_key: float = _axis("steer_right", "steer_left")  # +1 = turn right on the screen
	var tilt_key: float = _axis("tilt_right", "tilt_left")  # +1 = mast top toward starboard
	_turn_key = clampf(steer_key + tilt_key, -1.0, 1.0) if mode == Mode.BEGINNER else 0.0
	_sharp = _held("steer_sharp")
	_shape_the_key(clampf(steer_key + tilt_key, -1.0, 1.0), dt)
	var rake_key: float = _axis("rake_back", "rake_forward")  # +1 = rig back
	# Through a gybe the sailor keeps the sail eased: with the rig laid forward and the body
	# inside the turn, a fully powered sail would pull them over it. The bank does the
	# turning; afterwards the pilot sheets back in at the pace the body can lean out.
	var gybing: bool = manoeuvre == Manoeuvre.GYBE_BEARING_AWAY or manoeuvre == Manoeuvre.GYBE_HEADING_UP
	auto_sheet_pilot.max_alpha_deg = gybe_entry_alpha_deg if gybing else _hold_back_alpha_deg(telemetry, dt)
	if _heading_up_at_speed(telemetry, controls):
		auto_sheet_pilot.max_alpha_deg = minf(auto_sheet_pilot.max_alpha_deg, head_up_alpha_deg)
	var light: bool = _light_over_a_crest(telemetry, dt)
	var strong: float = _airborne_wind_share(telemetry, dt)
	if light and strong > 0.0:
		# The pilot never trims beyond 24 degrees of angle of attack: from there to the full ease.
		var cap_deg: float = airborne_alpha_deg if strong >= 1.0 else lerpf(24.0, airborne_alpha_deg, strong)
		auto_sheet_pilot.max_alpha_deg = minf(auto_sheet_pilot.max_alpha_deg, cap_deg)
		_resheet_for_s = airborne_resheet_s
	else:
		_resheet_for_s = maxf(_resheet_for_s - dt, 0.0)
	if airborne_sheet_in_share > 0.0 and not pilot_overrides.has("sheet_in_share"):
		auto_sheet_pilot.sheet_in_share = airborne_sheet_in_share if _resheet_for_s > 0.0 else _own_sheet_in_share
	_turn_wanted = 0.0
	var was_in_a_manoeuvre: bool = manoeuvre != Manoeuvre.NONE
	if manoeuvre != Manoeuvre.NONE and _key_gives_up():
		# The other key: the turn eases out and the key steers as on a reach (below).
		manoeuvre = Manoeuvre.NONE
		_heading_held = false
		_settling = true
	if manoeuvre != Manoeuvre.NONE:
		var is_gybe: bool = manoeuvre == Manoeuvre.GYBE_BEARING_AWAY or manoeuvre == Manoeuvre.GYBE_HEADING_UP
		var turn: float = _manoeuvre_turn(telemetry, dt)
		_turn_wanted = turn
		var rate_dps: float = turn * _manoeuvre_rate_dps(is_gybe)
		if is_gybe:
			_steer_at_rate(telemetry, controls, rate_dps, true, dt)
		else:
			_steer_tack(telemetry, controls, turn, rate_dps, dt)
		if manoeuvre == Manoeuvre.NONE:
			_settling = true
	elif mode == Mode.BEGINNER:
		_steer_beginner(telemetry, controls, _steer_smooth, dt)
		_turn_wanted = signf(wanted_rate_dps) if absf(wanted_rate_dps) > 5.0 else 0.0
	else:
		# Raw controls: rake comes back to neutral when Q/E are released, like the others.
		controls.rake = move_toward(controls.rake, rake_key, rake_rate_per_s * dt)
		controls.rig_tilt = move_toward(controls.rig_tilt, tilt_key, helm_rate_per_s * dt)
		controls.lean = move_toward(controls.lean, steer_key, lean_rate_per_s * dt)
		controls.back_foot_push = move_toward(controls.back_foot_push, auto_sheet_pilot.back_foot_bias, helm_rate_per_s * dt)
		helm_right = 0.0
		_heading_held = false
	if was_in_a_manoeuvre and manoeuvre == Manoeuvre.NONE:
		_manoeuvre_ended()
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
	_hold_the_cued_side(telemetry, controls, dt)
	# The recovery reflex last, so near a fall its ease wins over the cue's hold.
	if reflex_on:
		_recover_with_the_sheet(telemetry, controls, pilot_trimming, dt)
		if reflex_step_forward:
			_step_forward_on_a_rising_nose(telemetry, controls, dt)

	controls.balance_reflex = true
	_move_the_body(telemetry, controls, dt)
	if reflex_on and body == null:
		# The heels against an over-railed board (planing in the straps; the sim sees to that). With
		# the body on the mouse the player's feet are their own.
		controls.feet_roll_press = -reflex_heel_press * lee_danger


## Package B, the body on the mouse (MouseBody; ROADMAP GP2): the toes against the heels and the back
## foot against the front foot, written as the feet's press (SimControls.feet_roll_press and
## feet_pitch_press) every tick; the simulation presses with them, the feet staying in the straps.
## Without a body nothing changes (the presses stay 0). In a manoeuvre the toes and heels press nothing
## (the turn's own bank rules there; with body_in_manoeuvres they carve through the turn's rate) and
## the back and front foot press only with body_in_manoeuvres. The push slider's extras are its own and are left alone:
## the simulation adds the toes' and heels' bank to the slider's rail, and the back or front foot's
## weight takes over the trim the technique and the slider search for, as far as it presses (how the
## two combine, measured: Documentation/reports/gameplay/gp2_push_on_mouse.md).
func _move_the_body(telemetry: Telemetry, controls: SimControls, dt: float) -> void:
	if body == null:
		if _body_was_on:
			# The body just went (the setting switched off): the feet press as the technique wants.
			controls.feet_roll_press = 0.0
			controls.feet_pitch_press = 0.0
		_body_was_on = false
		return
	_body_was_on = true
	body.spring(dt)
	if manoeuvre != Manoeuvre.NONE:
		body.rest()
		if _body_carves() and (manoeuvre == Manoeuvre.GYBE_BEARING_AWAY or manoeuvre == Manoeuvre.GYBE_HEADING_UP):
			# The sideways press carves through the turn's rate (_manoeuvre_rate_dps()); in a gybe the
			# back and the front foot press as on a reach. Not in a tack: the weight on the back foot
			# while carving up into the wind catapulted the sailor at 18 and 24 kt in 12 of 18 tacks
			# (the matrix), and the feet are off the straps at the mast anyway.
			body.pitch_press = body.back_foot_press()
	else:
		var tack: float = tack_sign(telemetry)
		# Starboard tack (+1): the leeward rail is the port one, a negative heel.
		body.press(tack, -telemetry.heel_deg * tack)
	controls.feet_roll_press = body.roll_press
	controls.feet_pitch_press = body.pitch_press


## The body's line for the F1 panel ("" without a body).
func body_text() -> String:
	return body.describe() if body != null else ""


## The push slider: the keys or the hands move the level, and the level sets the pilot and the
## controls; pilot_overrides then win field by field (before the sea's rail is read from the
## pilot, so an override of it counts). Without a level only the overrides are applied.
func _move_the_slider(telemetry: Telemetry, controls: SimControls, dt: float) -> void:
	auto_sheet_pilot.sheet_rate_per_s = pilot_sheet_rate_per_s
	_slider_back_after_hands(controls)
	if hands != null:
		if not is_nan(hands.push):
			push_level = clampf(hands.push, 0.0, 1.0)
		elif not is_nan(push_level):
			_release_the_slider(controls)
	elif not is_nan(push_level):
		var key: float = _axis("push_more", "push_less")
		if key != 0.0:
			push_level = clampf(push_level + key * push_rate_per_s * dt, 0.0, 1.0)
		if body != null:
			# The push on the mouse: the wheel's notches since the last update, beside the keys.
			push_level = clampf(push_level + body.take_push_change(), 0.0, 1.0)
	_follow_the_push(dt)
	if not is_nan(push_now):
		if push_curve == null:
			push_curve = PushDial.default_curve()
		PushDial.apply_level(push_now, push_curve, auto_sheet_pilot, controls)
	# The pilot's numbers set from outside win over the slider's, field by field (the game's
	# --pilot. options, the harnesses).
	for field: String in pilot_overrides:
		auto_sheet_pilot.set(field, pilot_overrides[field])
	_keep_a_margin_in_chop(telemetry, dt)
	if is_nan(push_level):
		# Without a slider the rail for the sea is the pilot's own wave rail, when it has one (0 by
		# default: then nothing changes).
		if auto_sheet_pilot.wave_rail_max_deg > 0.0:
			auto_sheet_pilot.feel_the_sea(telemetry, dt)
			controls.rail_bank_extra_deg = auto_sheet_pilot.wave_rail_deg()
		return
	# The rail for the sea (Autopilot.wave_rail_deg): the sailor rails more when the board bounces.
	auto_sheet_pilot.feel_the_sea(telemetry, dt)
	controls.rail_bank_extra_deg += auto_sheet_pilot.wave_rail_deg()


## Hands taking the board remember the slider's level; hands letting go put it back: the player's
## own level after a menu or the race director's view, or no slider again on a board that had none.
func _slider_back_after_hands(controls: SimControls) -> void:
	if hands != null and not _had_hands:
		_had_hands = true
		_level_before_hands = push_level
	elif hands == null and _had_hands:
		_had_hands = false
		if is_nan(_level_before_hands):
			if not is_nan(push_level):
				_release_the_slider(controls)
		else:
			push_level = _level_before_hands
		# The sailor at the level at once (as at the first level), with no burst left over.
		push_now = NAN
		_in_burst = false
		_level_before_hands = NAN


## The level the sailor is at (push_now): push_level, or 100 % while the body's burst is held,
## followed at push_mouse_rate_per_s (never slower than the keys move push_level, so the keys alone
## give push_level exactly). The first level, an AI skipper's hands and no slider: at once.
func _follow_the_push(dt: float) -> void:
	if is_nan(push_level):
		push_now = NAN
		return
	var bursting: bool = hands == null and body != null and body.burst_held
	var wanted: float = 1.0 if bursting else push_level
	if is_nan(push_now) or hands != null:
		push_now = wanted
	else:
		push_now = move_toward(push_now, wanted, maxf(push_mouse_rate_per_s, push_rate_per_s) * dt)
	if bursting:
		_in_burst = true
	elif push_now == push_level:
		_in_burst = false


## Whether the push is in a burst: the left button held, or the sailor still coming back from it to
## the level chosen with the keys and the wheel (the gauge shows where it comes back to).
func is_bursting() -> bool:
	return _in_burst and not is_nan(push_now)


## How much of the ease in the air applies in this wind and this sea, 0 to 1: the wind's share
## (airborne_wind_from_kt, _full_kt) times the chop's (airborne_bounce_from_dps, _full_dps).
func _airborne_wind_share(telemetry: Telemetry, dt: float) -> float:
	var share: float = 1.0
	if airborne_wind_full_kt > 0.0:
		var span: float = maxf(airborne_wind_full_kt - airborne_wind_from_kt, 0.1)
		share = clampf((telemetry.tws_at_sail_kt - airborne_wind_from_kt) / span, 0.0, 1.0)
	if airborne_bounce_full_dps > 0.0:
		auto_sheet_pilot.feel_the_sea(telemetry, dt)
		var bounce_span: float = maxf(airborne_bounce_full_dps - airborne_bounce_from_dps, 0.1)
		share *= clampf((auto_sheet_pilot.felt_bounce_dps() - airborne_bounce_from_dps) / bounce_span, 0.0, 1.0)
	return share


## True while the board is light over a crest, and for airborne_hold_s after (airborne_alpha_deg).
func _light_over_a_crest(telemetry: Telemetry, dt: float) -> bool:
	if airborne_alpha_deg >= 90.0 or telemetry.total_mass_kg <= 0.0:
		return false
	var support_n: float = telemetry.buoyancy_n + telemetry.planing_lift_n
	if support_n < airborne_support_share * telemetry.total_mass_kg * 9.81:
		_light_for_s += dt
		# The felt heel to leeward: on starboard tack (+1) the leeward rail is the port one, negative.
		var felt_leeward_deg: float = -telemetry.felt_heel_deg * tack_sign(telemetry)
		if _light_for_s >= airborne_after_s and felt_leeward_deg >= airborne_heel_from_deg:
			_airborne_for_s = airborne_hold_s
			return true
	else:
		_light_for_s = 0.0
	_airborne_for_s = maxf(_airborne_for_s - dt, 0.0)
	return _airborne_for_s > 0.0


## A tack or gybe asked for at speed waits for the bow to drop off a crest (manoeuvre_wait_max_s).
func _wait_for_the_wave(telemetry: Telemetry, dt: float) -> void:
	if _manoeuvre_wait_s <= 0.0:
		return
	if manoeuvre != Manoeuvre.NONE:
		_manoeuvre_wait_s = 0.0
		return
	_manoeuvre_wait_s -= dt
	if telemetry.pitch_rate_dps < -manoeuvre_wait_pitch_dps or _manoeuvre_wait_s <= 0.0:
		_manoeuvre_wait_s = 0.0
		_start_manoeuvre(telemetry)


## The pull held in chop (chop_hike_drop): the pilot's hike_share lowered by the bounce felt. The
## slider and the overrides set hike_share afresh every update; without them it is the pilot's own.
func _keep_a_margin_in_chop(telemetry: Telemetry, dt: float) -> void:
	if chop_hike_drop <= 0.0:
		return
	auto_sheet_pilot.feel_the_sea(telemetry, dt)
	var set_this_update: bool = not is_nan(push_level) or pilot_overrides.has("hike_share")
	var base: float = auto_sheet_pilot.hike_share if set_this_update else _own_hike_share
	auto_sheet_pilot.hike_share = base * (1.0 - chop_hike_drop * chop_share())


## How much chop the sailor feels, 0 (flat water) to 1 (wild): the bounce (the pitch rate's RMS)
## between chop_bounce_from_dps and chop_bounce_full_dps.
func chop_share() -> float:
	var span: float = maxf(chop_bounce_full_dps - chop_bounce_from_dps, 0.1)
	return clampf((auto_sheet_pilot.felt_bounce_dps() - chop_bounce_from_dps) / span, 0.0, 1.0)


## True while the sailor heads up on purpose at speed: a tack's carve up to the wind (before the
## pivot), or the beginner's wanted rate toward the wind (the last update's), above
## head_up_ease_from_ms. Off (false) while head_up_alpha_deg is 90.
func _heading_up_at_speed(telemetry: Telemetry, controls: SimControls) -> bool:
	if head_up_alpha_deg >= 90.0 or telemetry.speed_ms < head_up_ease_from_ms:
		return false
	if manoeuvre == Manoeuvre.TACK_HEADING_UP:
		return not Helm.pivoting(telemetry, controls, pivot_within_deg)
	if manoeuvre != Manoeuvre.NONE:
		return false
	# Heading up is a right turn on starboard tack (tack +1) and a left turn on port tack.
	if not head_up_ease_on_hold and _turn_key * tack_sign(telemetry) <= 0.0:
		return false
	return wanted_rate_dps * tack_sign(telemetry) > head_up_ease_from_dps


## The share of the rail a turn gets at this speed (rail_from_ms, rail_full_ms): 1 when off.
func _rail_by_speed(telemetry: Telemetry) -> float:
	if rail_full_ms <= 0.0:
		return 1.0
	return smoothstep(rail_from_ms, maxf(rail_full_ms, rail_from_ms + 0.01), telemetry.speed_ms)


## The hands let go of the slider (AiHands.push back to NaN): no level, and the pilot's margin and
## the sailor's technique back to their own numbers, as on a board that never had a slider (the
## fields PushDial.apply_level() sets: a fresh pilot's, and no extras on the controls).
func _release_the_slider(controls: SimControls) -> void:
	push_level = NAN
	var own: Autopilot = Autopilot.new()
	auto_sheet_pilot.drive_share = own.drive_share
	auto_sheet_pilot.hike_share = own.hike_share
	auto_sheet_pilot.back_foot_bias = own.back_foot_bias
	auto_sheet_pilot.wave_rail_max_deg = own.wave_rail_max_deg
	controls.rig_lean_extra_deg = 0.0
	controls.rail_bank_extra_deg = 0.0
	controls.trim_aim_extra_deg = 0.0


## The slider's line for the HUD ("" without a slider): the level the sailor is at.
func push_text() -> String:
	if is_nan(push_level):
		return ""
	if push_curve == null:
		push_curve = PushDial.default_curve()
	return PushDial.describe(push_level if is_nan(push_now) else push_now, push_curve)


## In a burst, the level it comes back to, for the F1 panel ("" otherwise).
func burst_text() -> String:
	return "burst: back to %.0f %% when let go" % (push_level * 100.0) if is_bursting() else ""


## The beginner's turn-rate loop. turn_key asks for a rate; without a key the heading hold
## asks for the rate that brings the heading back. The error against the measured yaw rate
## moves the helm now (proportional) and slowly shifts the trim (integral), so the loop
## finds by itself how much helm this speed and course need, in either direction.
func _steer_beginner(telemetry: Telemetry, controls: SimControls, turn_key: float, dt: float) -> void:
	# Coming out of a manoeuvre: let the board straighten before holding a heading.
	if _settling and turn_key == 0.0:
		if absf(telemetry.yaw_rate_dps) > settle_rate_dps and telemetry.speed_ms > settle_speed_ms:
			helm_right = 0.0
			wanted_rate_dps = 0.0
			controls.rake = move_toward(controls.rake, 0.0, helm_rate_per_s * dt)
			controls.rig_tilt = move_toward(controls.rig_tilt, 0.0, helm_rate_per_s * dt)
			controls.lean = move_toward(controls.lean, 0.0, helm_rate_per_s * dt)
			controls.back_foot_push = move_toward(controls.back_foot_push, 0.0, helm_rate_per_s * dt)
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
		controls.back_foot_push = move_toward(controls.back_foot_push, 0.0, helm_rate_per_s * dt)
		return
	var rate: float = 0.0
	if turn_key != 0.0:
		var sharp: float = sharp_turn_factor if _sharp else 1.0
		rate = turn_key * turn_rate_dps * sharp
		# A right turn heads up on starboard tack, a left turn on port tack.
		if signf(rate) == tack_sign(telemetry):
			var cap: float = clampf(head_up_rate_budget_dps_ms / maxf(telemetry.speed_ms, 0.1), head_up_rate_min_dps, turn_rate_dps) * sharp
			rate = clampf(rate, -cap, cap)
		_heading_held = false
	elif hold_heading:
		if not _heading_held:
			# A positive yaw rate turns the bow to port (the heading decreases).
			var lead_deg: float = clampf(-telemetry.yaw_rate_dps * hold_lead_s, -hold_lead_max_deg, hold_lead_max_deg)
			_held_heading_deg = wrapf(telemetry.heading_deg + lead_deg, 0.0, 360.0)
			_heading_held = true
		# Getting going: the hold aims further off the wind below the plane (plane_bear_away_deg).
		var aim_deg: float = _held_heading_deg - tack_sign(telemetry) * _plane_bear_away_now_deg(telemetry)
		var turn_right_deg: float = wrapf(aim_deg - telemetry.heading_deg, -180.0, 180.0)
		var per_deg: float = hold_rate_per_deg * lerpf(slow_hold_scale, 1.0, _planing_blend(telemetry))
		rate = clampf(per_deg * turn_right_deg, -hold_rate_limit_dps, hold_rate_limit_dps)
	held_heading_deg = _held_heading_deg if _heading_held else -1.0
	if reflex_on:
		rate = _bear_away_from_the_fall(telemetry, rate)
	# A key asks for a turn and gets the rail; the heading hold keeps the board flat and
	# steers with the rig alone. A planing board carves hard on a few degrees of bank, and
	# a hold that banked for every small correction would rock the board about its course.
	_steer_at_rate(telemetry, controls, rate, turn_key != 0.0, dt)


## How far the planing technique is in use, 0 to 1: the speed between planing_steer_from_ms and
## planing_steer_full_ms, times how far the feet are in the straps.
func _planing_technique(telemetry: Telemetry) -> float:
	var fast: float = smoothstep(planing_steer_from_ms, planing_steer_full_ms, telemetry.speed_ms)
	return fast * clampf(telemetry.stance, 0.0, 1.0)


## The hold-back skill: the most angle of attack the auto-sheet may trim to, degrees (90, no
## limit, unless the hands ask for a wanted speed; never during a manoeuvre, which needs the
## sail). See hold_back_gain_deg_per_ms.
func _hold_back_alpha_deg(telemetry: Telemetry, dt: float) -> float:
	var wanted_ms: float = hands.hold_speed_ms if hands != null else 0.0
	if wanted_ms <= 0.0 or manoeuvre != Manoeuvre.NONE:
		_holding_back = false
		return 90.0
	if not _holding_back:
		# It starts from the trim the sail has now, so the sheet does not jump.
		_holding_back = true
		_hold_trim_deg = clampf(telemetry.alpha_deg, hold_back_min_alpha_deg, hold_back_max_alpha_deg)
		_hold_last_speed_ms = telemetry.speed_ms
		_hold_acceleration_ms2 = 0.0
	var acceleration_ms2: float = (telemetry.speed_ms - _hold_last_speed_ms) / maxf(dt, 1e-6)
	_hold_acceleration_ms2 = lerpf(_hold_acceleration_ms2, acceleration_ms2, clampf(dt / 0.5, 0.0, 1.0))
	_hold_last_speed_ms = telemetry.speed_ms
	# Positive when the board is (about to be) too fast; slower than the steerage speed counts as
	# too slow whatever was asked.
	var ahead_ms: float = telemetry.speed_ms + _hold_acceleration_ms2 * hold_back_lead_s
	var excess_ms: float = ahead_ms - maxf(wanted_ms, hold_back_steerage_ms)
	var alpha_deg: float = _hold_trim_deg - hold_back_gain_deg_per_ms * excess_ms
	# The trim keeps easing only while the sail is not already eased as far as it goes (and
	# sheeting in only while it is not fully trimmed): a trim run on past its stop would hold
	# the sail out long after the board has slowed.
	var at_stop: bool = (excess_ms > 0.0 and alpha_deg <= hold_back_min_alpha_deg) or (excess_ms < 0.0 and alpha_deg >= hold_back_max_alpha_deg)
	if not at_stop:
		_hold_trim_deg = clampf(_hold_trim_deg - hold_back_trim_dps_per_ms * excess_ms * dt, hold_back_min_alpha_deg, hold_back_max_alpha_deg)
	return clampf(alpha_deg, hold_back_min_alpha_deg, hold_back_max_alpha_deg)


## True while the hold-back skill is easing the sail (for the tools and the tests).
func is_holding_back() -> bool:
	return _holding_back


## The tack: carved up to the wind at tack_rate_dps on the windward rail; then, within
## pivot_within_deg of the wind or with the rig held by the auto-sheet pilot, the rig fully
## back and no weight on a rail while the backed sail swings the bow through. On the new
## tack the rig stays back as long as the sail is backwinded or luffing: a sail that cannot
## fill cannot drive the bow off the wind, but the wind on its wrong side, aft of the
## centre of mass, pushes the stern round (the way out of irons). Once it fills, full helm
## away from the wind until the manoeuvre ends. rate_dps is the carve's rate (turn times
## tack_rate_dps, or what the player's key and body make of it).
func _steer_tack(telemetry: Telemetry, controls: SimControls, turn: float, rate_dps: float, dt: float) -> void:
	var pivot: bool = Helm.pivoting(telemetry, controls, pivot_within_deg)
	var on_new_tack: bool = tack_sign(telemetry) == -_tack_sign_at_start
	var stuck: bool = on_new_tack and auto_sheet_pilot.is_backing()
	if (not on_new_tack and pivot) or stuck:
		helm_right = turn
		wanted_rate_dps = rate_dps
		controls.rake = move_toward(controls.rake, 1.0, helm_rate_per_s * dt)
		controls.rig_tilt = move_toward(controls.rig_tilt, 0.0, helm_rate_per_s * dt)
		controls.lean = move_toward(controls.lean, 0.0, helm_rate_per_s * dt)
		controls.back_foot_push = move_toward(controls.back_foot_push, 0.0, helm_rate_per_s * dt)
		return
	_steer_at_rate(telemetry, controls, rate_dps, true, dt)


## The turn-rate loop: the error against the measured yaw rate moves the helm now
## (proportional) and slowly shifts the trim (integral), so the loop finds by itself how
## much helm this speed and course need, in either direction and on either tack.
func _steer_at_rate(telemetry: Telemetry, controls: SimControls, rate_dps: float, rail_on: bool, dt: float) -> void:
	wanted_rate_dps = rate_dps
	# A positive yaw rate turns the bow to port, so the rate of turning right is its negative.
	var error_dps: float = wanted_rate_dps - (-telemetry.yaw_rate_dps)
	var tack: float = tack_sign(telemetry)
	# Below the plane the loop's own gains (slow_rate_gain_scale, slow_integral_scale); in the air the
	# helm held (airborne_helm_hold): the water no longer answers it.
	var planing: float = _planing_blend(telemetry)
	var held: float = airborne_helm_hold if _airborne_for_s > 0.0 else 0.0
	var integral_gain: float = rate_integral_gain * lerpf(slow_integral_scale, 1.0, planing) * (1.0 - held)
	var gain: float = rate_gain * lerpf(slow_rate_gain_scale, 1.0, planing)
	_helm_trim_up = clampf(_helm_trim_up + integral_gain * error_dps * tack * dt, -1.0, 1.0)
	var helm_now: float = clampf(_helm_trim_up * tack + gain * error_dps, -1.0, 1.0)
	helm_right = lerpf(helm_now, helm_right, held)
	var pivot: bool = Helm.pivoting(telemetry, controls, pivot_within_deg)
	# The rig closes the loop. The rail is not in the loop: weight goes on the inside rail
	# in proportion to the wanted rate (the sim banks the board for a coordinated turn at
	# that rate), and none while pivoting through the wind, where a board on its rail skids.
	var rail: float = 0.0 if (pivot or not rail_on) else clampf(wanted_rate_dps / carve_rate_dps, -1.0, 1.0) * _rail_by_speed(telemetry)
	if manoeuvre == Manoeuvre.NONE:
		rail *= _key_rail_share(telemetry)
	var lean_before: float = controls.lean
	# The legs (PH35): the back foot carries legs_share of the helm, and the slider's push on top;
	# none while pivoting, where the feet are out of the straps. Planing in the straps they also
	# push on the rate error (legs_rate_gain), heading up with the back foot on either tack.
	var legs_bias: float = 0.0
	if not pivot:
		legs_bias = auto_sheet_pilot.back_foot_bias + _legs_for_rate(telemetry, error_dps * tack)
	Helm.steer(controls, helm_right, tack, 0.0, dt, helm_rate_per_s, 0.0 if pivot else 1.0,
		0.0 if pivot else legs_share, legs_bias)
	controls.lean = move_toward(lean_before, rail, helm_rate_per_s * dt)


## The legs' push for a turn (planing technique): head_up_error_dps is how much faster the board
## should turn toward the wind than it does (negative: away from it); none below the plane.
func _legs_for_rate(telemetry: Telemetry, head_up_error_dps: float) -> float:
	return clampf(head_up_error_dps * legs_rate_gain, -1.0, 1.0) * _planing_technique(telemetry)


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
## The recovery reflex's sense of the fall coming (reflex_on): lee_danger and windward_danger from the
## shares of the fall checks' limits, faded over reflex_hold_s once the danger has passed, and weaker
## with the push slider near its top.
func _feel_the_fall(telemetry: Telemetry, dt: float) -> void:
	var span: float = maxf(reflex_full_share - reflex_from_share, 0.01)
	var lee: float = clampf((telemetry.lee_fall_share - reflex_from_share) / span, 0.0, 1.0)
	var windward: float = clampf((telemetry.windward_fall_share - reflex_from_share) / span, 0.0, 1.0)
	# The body tipping off its feet: toward the sail or away from it (the excess is positive when the
	# body is tipped to port, which is leeward on starboard tack, tack +1).
	var tip: float = clampf((telemetry.tipping_share - reflex_tip_from_share) / maxf(1.0 - reflex_tip_from_share, 0.01), 0.0, 1.0)
	if tip > 0.0:
		if telemetry.feet_moment_excess_nm * tack_sign(telemetry) > 0.0:
			lee = maxf(lee, tip)
		else:
			windward = maxf(windward, tip)
	_reflex_speed_share = smoothstep(reflex_fade_below_ms, reflex_full_from_ms, telemetry.speed_ms)
	var strength: float = reflex_strength()
	var fade: float = dt / maxf(reflex_hold_s, dt)
	lee_danger = maxf(lee * strength, lee_danger - fade)
	windward_danger = maxf(windward * strength, windward_danger - fade)


## How much of the reflex the sailor uses: all of it at speed (from reflex_full_from_ms) and none at
## walking pace (_reflex_speed_share, set as the fall is felt); and by the push: all of it without a
## slider and up to reflex_push_fade_from, none at the top of the slider (the pushed dial keeps its risk).
func reflex_strength() -> float:
	if is_nan(push_level):
		return _reflex_speed_share
	return _reflex_speed_share * (1.0 - smoothstep(reflex_push_fade_from, 1.0, push_level))


## The reflex on the sheet: pulled over, eased fast toward reflex_alpha_deg (the last chance:
## reflex_last_alpha_deg); falling back, sheeted in fast toward reflex_catch_alpha_deg. Not while the
## sail is backed in a tack (the pilot holds the rig then). The pilot carries on from where the reflex
## left the sheet.
func _recover_with_the_sheet(telemetry: Telemetry, controls: SimControls, pilot_trimming: bool, dt: float) -> void:
	if lee_danger <= 0.0 and windward_danger <= 0.0:
		return
	if controls.hold_side != 0 or controls.boom_across > 0.0:
		return
	var awa_deg: float = absf(telemetry.awa_deg)
	var step: float = reflex_sheet_rate_per_s * dt
	if lee_danger > 0.0:
		var alpha_cap_deg: float = lerpf(24.0, reflex_alpha_deg, lee_danger)
		if telemetry.lee_fall_share >= reflex_last_share:
			alpha_cap_deg = lerpf(alpha_cap_deg, reflex_last_alpha_deg, reflex_strength())
		var cap_sheet: float = _sheet_for_alpha(awa_deg, alpha_cap_deg)
		controls.sheet = minf(controls.sheet, maxf(cap_sheet, telemetry.sheet - step))
	elif windward_danger > 0.0 and _sail_draws(telemetry):
		var floor_sheet: float = lerpf(controls.sheet, _sheet_for_alpha(awa_deg, reflex_catch_alpha_deg), windward_danger)
		if floor_sheet > controls.sheet:
			controls.sheet = minf(floor_sheet, maxf(telemetry.sheet, controls.sheet) + step)
	if pilot_trimming:
		wanted_sheet = controls.sheet


## True while sheeting in would bring the pull back: the wind on the sail's own side (not backed: in
## irons a backed sail sheeted in pushes the sailor further over backwards; round 1 of the races, a fall
## back at 40.7 s with the sheet at 0.99) and the board moving faster than walking pace.
func _sail_draws(telemetry: Telemetry) -> bool:
	return not telemetry.is_backwinded and telemetry.alpha_deg > 0.0 and telemetry.speed_ms > reflex_slow_ms


## The reflex at walking pace: the weight forward when the nose rises on a board that hardly moves
## (reflex_nose_up_deg). Not while the sail is backed in a tack, which steps round the mast already.
func _step_forward_on_a_rising_nose(telemetry: Telemetry, controls: SimControls, dt: float) -> void:
	if controls.hold_side != 0 or telemetry.speed_ms > reflex_slow_ms or telemetry.pitch_deg <= reflex_nose_up_deg:
		_nose_up_for_s = 0.0
		return
	_nose_up_for_s += dt
	if _nose_up_for_s < reflex_nose_up_hold_s:
		return
	var span: float = maxf(reflex_nose_up_full_deg - reflex_nose_up_deg, 0.1)
	var share: float = clampf((telemetry.pitch_deg - reflex_nose_up_deg) / span, 0.0, 1.0)
	controls.step_forward = maxf(controls.step_forward, share)


## The sheet (0 out, 1 in) that sets this angle of attack at this apparent wind angle, degrees.
func _sheet_for_alpha(awa_deg: float, alpha_deg: float) -> float:
	var sheet_in_deg: float = auto_sheet_pilot.sheet_angle_in_deg
	var sheet_out_deg: float = auto_sheet_pilot.sheet_angle_out_deg
	var boom_deg: float = clampf(awa_deg - alpha_deg, sheet_in_deg, sheet_out_deg)
	return 1.0 - (boom_deg - sheet_in_deg) / (sheet_out_deg - sheet_in_deg)


## The reflex on the steering: pulled over, a head-up asked for is taken back and the board borne away
## at up to reflex_bear_away_dps (the push of a bear-away throws the sailor to windward, and the
## apparent wind drops); rate_dps is the turn to the right the steering wants, degrees a second.
func _bear_away_from_the_fall(telemetry: Telemetry, rate_dps: float) -> float:
	if lee_danger <= 0.0 or reflex_bear_away_dps <= 0.0 or absf(telemetry.twa_deg) > reflex_bear_away_max_twa_deg:
		return rate_dps
	var tack: float = tack_sign(telemetry)
	# Heading up is a right turn on starboard tack (+1).
	var up_dps: float = rate_dps * tack
	if up_dps > 0.0:
		up_dps *= 1.0 - lee_danger
	up_dps = minf(up_dps, -lee_danger * reflex_bear_away_dps)
	return up_dps * tack


func reset_controls(controls: SimControls) -> void:
	_settling = false
	_holding_back = false
	lee_danger = 0.0
	windward_danger = 0.0
	_nose_up_for_s = 0.0
	wanted_sheet = 0.0
	ease = 0.0
	manoeuvre = Manoeuvre.NONE
	_manoeuvre_wait_s = 0.0
	_choose_grace_left_s = 0.0
	_cue_given = false
	_cue_side = 0
	_cue_window_open = false
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
	auto_sheet_pilot.sailor = _sailor
	auto_sheet_pilot.air_density_kg_m3 = _air_density_kg_m3
	controls.sheet = 0.0
	controls.boom_across = 0.0
	controls.rake = 0.0
	controls.rig_tilt = 0.0
	controls.lean = 0.0
	controls.back_foot_push = 0.0
	controls.rail_bank_extra_deg = 0.0
	controls.trim_aim_extra_deg = 0.0
	controls.rig_lean_extra_deg = 0.0
	controls.feet_roll_press = 0.0
	controls.feet_pitch_press = 0.0
	# After a fall or a restart the body starts from the sailor's own technique again.
	if body != null:
		body.recentre()


func mode_name() -> String:
	return "Beginner" if mode == Mode.BEGINNER else "Advanced"


func manoeuvre_name() -> String:
	match manoeuvre:
		Manoeuvre.TACK_HEADING_UP, Manoeuvre.TACK_BEARING_AWAY:
			return "tacking"
		Manoeuvre.GYBE_BEARING_AWAY, Manoeuvre.GYBE_HEADING_UP:
			return "gybing"
	return ""


## Space: with A or D held, a tack when the key turns toward the wind and a gybe when it turns away
## from it (turn_key_chooses); with neither, a tack when sailing upwind of a beam reach and a gybe
## when sailing downwind of it, and A or D pressed within choose_grace_s still decides.
func _start_manoeuvre(telemetry: Telemetry) -> void:
	_tack_sign_at_start = tack_sign(telemetry)
	_manoeuvre_timer_s = 0.0
	_cue_given = false
	_cue_side = 0
	# A body that carves the manoeuvre keeps its place (it goes back to the middle at the end).
	if body != null and not _body_carves():
		body.recentre()
	var key: float = _choosing_key()
	if key != 0.0:
		manoeuvre = manoeuvre_for_turn(key, _tack_sign_at_start)
		_choose_grace_left_s = 0.0
		return
	# From a beam reach (and a little beyond) the quicker way onto the other tack is up
	# through the wind; from a broad reach it is round through the gybe.
	manoeuvre = Manoeuvre.TACK_HEADING_UP if absf(telemetry.twa_deg) <= tack_up_to_twa_deg else Manoeuvre.GYBE_BEARING_AWAY
	_choose_grace_left_s = choose_grace_s if _player_chooses() else 0.0


## The manoeuvre a turn asks for on this tack: turning toward the wind (a right turn on starboard
## tack, +1, a left turn on port tack) is a tack; turning away from it is a gybe.
static func manoeuvre_for_turn(turn_right: float, tack: float) -> Manoeuvre:
	return Manoeuvre.TACK_HEADING_UP if turn_right * tack > 0.0 else Manoeuvre.GYBE_BEARING_AWAY


## Whether the player's turn key may choose the manoeuvre: the setting, and never an AI's hands.
func _player_chooses() -> bool:
	return turn_key_chooses and hands == null


## The turn key that chooses the manoeuvre, +1 D (right), -1 A (left), 0 neither or both.
func _choosing_key() -> float:
	return _axis("steer_right", "steer_left") if _player_chooses() else 0.0


## A or D pressed just after Space (within choose_grace_s): the key decides after all, as long as
## the turn has not yet gone through the wind.
func _choose_by_a_late_key(dt: float) -> void:
	if _choose_grace_left_s <= 0.0:
		return
	_choose_grace_left_s = maxf(_choose_grace_left_s - dt, 0.0)
	var first_half: bool = manoeuvre == Manoeuvre.TACK_HEADING_UP or manoeuvre == Manoeuvre.GYBE_BEARING_AWAY
	if not first_half or auto_sheet_pilot.tack != _tack_sign_at_start:
		_choose_grace_left_s = 0.0
		return
	var key: float = _choosing_key()
	if key != 0.0:
		manoeuvre = manoeuvre_for_turn(key, _tack_sign_at_start)
		_choose_grace_left_s = 0.0


## Which way the manoeuvre turns, +1 right, -1 left, 0 none: a tack toward the wind of the tack it
## started on, a gybe away from it (for the harnesses and the player's hands).
func manoeuvre_turn_right() -> float:
	match manoeuvre:
		Manoeuvre.TACK_HEADING_UP, Manoeuvre.TACK_BEARING_AWAY:
			return _tack_sign_at_start
		Manoeuvre.GYBE_BEARING_AWAY, Manoeuvre.GYBE_HEADING_UP:
			return -_tack_sign_at_start
	return 0.0


## How long the manoeuvre has been going, seconds.
func manoeuvre_time_s() -> float:
	return _manoeuvre_timer_s


## The player's turn key along the manoeuvre's turn: +1 held toward the turn, -1 the other key, 0
## neither (or the setting off, or an AI's hands).
func _turn_key_along() -> float:
	if not turn_follows_key or hands != null:
		return 0.0
	return _axis("steer_right", "steer_left") * manoeuvre_turn_right()


## The other key, once the choosing window is over, gives the manoeuvre up.
func _key_gives_up() -> bool:
	return _choose_grace_left_s <= 0.0 and _turn_key_along() < 0.0


## Whether the body on the mouse carves the manoeuvre (the setting; never an AI's hands).
func _body_carves() -> bool:
	return body != null and body_in_manoeuvres and hands == null


## The body's press toward the inside of the turn, -1 (the outside: flatten) to +1 (carve harder),
## as a share of the toes' and heels' range (MouseBody.toes_share). The inside rail of a right turn is
## the starboard one; the mouse's "more rail" is the leeward rail of the tack the manoeuvre started on
## (the port rail on starboard tack, +1).
func body_carve() -> float:
	if not _body_carves() or manoeuvre == Manoeuvre.NONE:
		return 0.0
	var starboard_rail_down: float = -body.more_rail(_tack_sign_at_start) * _tack_sign_at_start
	return clampf(starboard_rail_down * manoeuvre_turn_right() * body.toes_share, -1.0, 1.0)


## The manoeuvre's turn rate, degrees a second (positive; the turn's sign is applied by the caller):
## its own rate (gybe_rate_dps, tack_rate_dps), or the key's when it is held toward the turn, times
## what the body's carve adds or takes, never beyond gybe_rate_max_dps or tack_rate_max_dps; the way
## out of the turn at its own rate.
func _manoeuvre_rate_dps(is_gybe: bool) -> float:
	var rate: float = gybe_rate_dps if is_gybe else tack_rate_dps
	# Only into the turn: the gybe until the sail is across, the tack until the rig is across. Out of
	# it (the board heading up onto the new reach after a gybe, bearing away after a tack) the turn
	# goes at its own rate whatever the hands do: carried on faster the board rounded up past a gybe's
	# exit at walking pace and the sailor fell, and a tack's quicker exit at 24 kt spun the board on
	# into a catapult (the matrix, gp_manoeuvres_6nov.md).
	if manoeuvre == Manoeuvre.GYBE_HEADING_UP or manoeuvre == Manoeuvre.TACK_BEARING_AWAY:
		return rate
	var sharp: bool = false
	if _turn_key_along() > 0.0:
		rate = key_gybe_rate_dps if is_gybe else key_tack_rate_dps
		# Shift held with the key: the carve into the turn (sharp_manoeuvre_factor, sharp_cap_factor).
		sharp = _sharp
		if sharp:
			rate *= sharp_manoeuvre_factor
	var carve: float = body_carve()
	if carve != 0.0:
		rate *= 1.0 + body_carve_share * carve
	# A head-up at planing speed faster than about 20 degrees a second pulls the sailor over the sail
	# (head_up_rate_min_dps; the matrix's tacks at 24 kt with the key and the body together).
	var cap: float = gybe_rate_max_dps if is_gybe else tack_rate_max_dps
	return minf(rate, cap * (sharp_cap_factor if sharp else 1.0))


## The manoeuvre is over (done, given up or timed out): the cue is forgotten, and a body that carved
## it goes back to the middle, the sailor's own technique (GD7 a).
func _manoeuvre_ended() -> void:
	if not is_nan(_own_flip_twa_deg):
		auto_sheet_pilot.flip_twa_deg = _own_flip_twa_deg
		_own_flip_twa_deg = NAN
	_cue_given = false
	_cue_side = 0
	_cue_window_open = false
	if _body_carves():
		body.recentre()


## Whether the "flip now" window is open: the cue is the player's (the setting, no AI's hands), not
## given yet, and the rig not yet across. A gybe: the bow within gybe_cue_from_twa_deg of dead
## downwind, or past it. A tack: the bow tack_cue_through_deg through the wind (the true wind at the
## sail), in the turn's first half.
func _in_the_flip_window(telemetry: Telemetry) -> bool:
	if not flip_on_cue or hands != null or _cue_given or auto_sheet_pilot.tack != _tack_sign_at_start:
		return false
	match manoeuvre:
		Manoeuvre.GYBE_BEARING_AWAY:
			var past_downwind: bool = telemetry.twa_deg * _tack_sign_at_start < 0.0
			return past_downwind or absf(telemetry.twa_deg) >= gybe_cue_from_twa_deg
		Manoeuvre.TACK_HEADING_UP:
			# As the pilot's own flip (Autopilot.update()): only once the sail would fill on the new side
			# (the apparent wind wider than the luff band there); flipped earlier it luffs and the fin
			# turns the bow back.
			var through: bool = telemetry.twa_at_sail_deg * _tack_sign_at_start <= -tack_cue_through_deg
			var awa_own_side_deg: float = telemetry.awa_deg * -float(telemetry.sail_side)
			var luff_band_deg: float = auto_sheet_pilot.sheet_angle_in_deg + auto_sheet_pilot.alpha_luff_deg
			return through and -awa_own_side_deg >= luff_band_deg
	return false


## True while a second Space puts the rig across (for the HUD's "flip now" and the harnesses).
func flip_cue_open() -> bool:
	return _cue_window_open


## The cue: the rig goes onto the new side now and is held there (_hold_the_cued_side()).
func _give_the_cue(telemetry: Telemetry) -> void:
	_cue_given = true
	_cue_window_open = false
	if manoeuvre == Manoeuvre.TACK_HEADING_UP:
		# A tack: the pilot's own flip, now (Autopilot.flip_twa_deg lowered to where the bow is): it
		# takes the boom back from across the centreline and sheets in on the new side in the same
		# motion. Held on the new side by hand instead, the boom stayed pushed across and the tack
		# took a second longer (the matrix).
		_own_flip_twa_deg = auto_sheet_pilot.flip_twa_deg
		auto_sheet_pilot.flip_twa_deg = minf(_own_flip_twa_deg, absf(telemetry.twa_at_sail_deg) - 0.1)
		return
	_cue_side = -telemetry.sail_side
	_cue_hold_left_s = cue_hold_max_s


## After a cue the sailor holds the rig on the new side until the wind keeps it there by itself (the
## sail's own rule: the apparent wind on the new side's windward side, or within the side's
## hysteresis of dead ahead or dead astern, SailModel.update_side()), or the manoeuvre is over.
func _hold_the_cued_side(telemetry: Telemetry, controls: SimControls, dt: float) -> void:
	if _cue_side == 0:
		return
	_cue_hold_left_s -= dt
	var across: bool = telemetry.sail_side == _cue_side
	if manoeuvre == Manoeuvre.NONE or _cue_hold_left_s <= 0.0 or (across and _wind_keeps_the_side(telemetry, _cue_side)):
		_cue_side = 0
		return
	controls.hold_side = _cue_side


## Whether the apparent wind would leave the sail on this side by itself (SailModel.update_side()).
func _wind_keeps_the_side(telemetry: Telemetry, side: int) -> bool:
	var band_deg: float = _sail.config.side_hysteresis_deg if _sail != null else 15.0
	var awa: float = absf(telemetry.awa_deg)
	if awa < band_deg or awa > 180.0 - band_deg:
		return true
	return (-1 if telemetry.awa_deg > 0.0 else 1) == side


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


## +1 while the first action is held, -1 for the second, 0 for neither or both. An AI
## skipper's hands give the value instead (a stick from -1 to 1).
func _axis(positive: String, negative: String) -> float:
	if hands != null:
		return hands.axis(positive)
	var value: float = 0.0
	if Input.is_action_pressed(positive):
		value += 1.0
	if Input.is_action_pressed(negative):
		value -= 1.0
	return value


## True while the key is held (an AI's hands: what they hold, AiHands.held()).
func _held(action: String) -> bool:
	if hands != null:
		return hands.held(action)
	return InputMap.has_action(action) and Input.is_action_pressed(action)


## The turn key shaped into a ramp (steer_rise_s, steer_fall_s), and how long it has been held
## (_key_held_s, for the rail's share): a short tap becomes a small, smooth turn.
func _shape_the_key(raw: float, dt: float) -> void:
	var rising: bool = absf(raw) > absf(_steer_smooth) or signf(raw) * signf(_steer_smooth) < 0.0
	var time_s: float = steer_rise_s if rising else steer_fall_s
	if time_s <= 0.0:
		_steer_smooth = raw
	else:
		_steer_smooth = move_toward(_steer_smooth, raw, dt / time_s)
	if raw != 0.0:
		_key_held_s += dt
	elif _steer_smooth == 0.0:
		_key_held_s = 0.0


## The share of the rail a key's turn gets: growing with how long the key has been held (a tap gets
## little), and in a sharp turn on the plane times sharp_rail_gain. 1 for the heading hold.
func _key_rail_share(telemetry: Telemetry) -> float:
	var share: float = 1.0
	if tap_rail_full_s > 0.0 and _steer_smooth != 0.0:
		share = smoothstep(0.0, tap_rail_full_s, _key_held_s)
	if _sharp and _steer_smooth != 0.0:
		share *= lerpf(1.0, sharp_rail_gain, _planing_technique(telemetry))
	return share


## 0 below planing_steer_from_ms - 2 m/s, 1 from planing_steer_from_ms: where the slow steering's
## numbers give way to the planing ones.
func _planing_blend(telemetry: Telemetry) -> float:
	return smoothstep(planing_steer_from_ms - 2.0, planing_steer_from_ms, telemetry.speed_ms)


## How much further off the wind the heading hold aims to get going, degrees (plane_bear_away_deg).
func _plane_bear_away_now_deg(telemetry: Telemetry) -> float:
	if plane_bear_away_deg <= 0.0 or telemetry.is_planing:
		return 0.0
	var room_deg: float = clampf(plane_bear_away_to_twa_deg - absf(telemetry.twa_deg), 0.0, plane_bear_away_deg)
	var slow: float = 1.0 - smoothstep(plane_help_full_ms, maxf(plane_help_until_ms, plane_help_full_ms + 0.01), telemetry.speed_ms)
	return room_deg * slow


## True on the update in which the key went down, and not again until it is released.
func _just_pressed(action: String) -> bool:
	if hands != null:
		return hands.take_press(action)
	var down: bool = Input.is_action_pressed(action)
	var was_down: bool = _was_down.get(action, false)
	_was_down[action] = down
	return down and not was_down
