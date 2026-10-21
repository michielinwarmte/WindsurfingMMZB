class_name Persona
extends Resource
## A persona of the AI fleet (AI_FLEET_PLAN.md, D3: "one strong brain, many personas"): a name, a
## colour, a home water, a short profile the menu shows, and a skill sheet of numbers from 0 to 1
## that degrade or bias one good skipper. A persona never touches the physics (RD7): it makes the
## hands clumsier or the head bolder, never the board.
##
## For a scripted skipper (Skipper) the sheet becomes a character sheet (SkipperConfig) by
## to_skipper_config(): each skill maps onto the numbers the scripted rules use, between the
## rookie's end (0) and the all-rounder's and better (1). The trained head (F5) will read the sheet
## as inputs and get its hands' noise from it the same way. Consistency draws each race's sheet a
## little differently (seeded): a persona has good days and bad days.
##
## One .tres per persona in Game/race/personas/; `persona:<file name>` names one in a race
## (tools/race.sh --skippers=persona:lena,persona:tobias; the Race page lists them).

@export var name: String = "Persona"
@export var sail_colour: Color = Color(0.6, 0.6, 0.9)
@export var home_water: String = "Lake Silvaplana"
## One line for the menu: "slalom specialist, fearless starts, loses the beat".
@export var profile: String = ""

@export_group("Skills, 0 to 1")
## The error on the start plan's clock: 0 is give or take 8 s, 1 give or take half a second.
@export_range(0.0, 1.0) var start_timing: float = 0.5
## How close to the line and how near the favoured end it dares to be.
@export_range(0.0, 1.0) var start_nerve: float = 0.5
## How well it tacks (the tacks it allows itself on a beat) and gybes.
@export_range(0.0, 1.0) var tacking: float = 0.5
@export_range(0.0, 1.0) var gybing: float = 0.5
## The hands on the trim and the heading: their reaction and their noise.
@export_range(0.0, 1.0) var boat_speed: float = 0.5
## How well it sees the shifts and uses the laylines; how deep and fast it runs.
@export_range(0.0, 1.0) var upwind_sense: float = 0.5
@export_range(0.0, 1.0) var downwind_sense: float = 0.5
## How far it goes looking for more wind (the lake's gusts).
@export_range(0.0, 1.0) var gust_appetite: float = 0.3
## The margins at marks and laylines, the OCS risk.
@export_range(0.0, 1.0) var risk: float = 0.5
## How close it sails to others.
@export_range(0.0, 1.0) var aggression: float = 0.5
## How little all of the above wander from race to race.
@export_range(0.0, 1.0) var consistency: float = 0.7

@export_group("Style")
## Where on the start line it likes to cross: 0 the pin end, 1 the boat end.
@export_range(0.0, 1.0) var start_spot: float = 0.5
@export var start_style: SkipperConfig.StartStyle = SkipperConfig.StartStyle.LOOP
## Points high (negative) or sails low and fast (positive), degrees off the polar's best angle.
@export_range(-3.0, 3.0) var pointing_offset_deg: float = 0.0

@export_group("Gear")
## The sail it rigs in a light wind (below gear_switch_kt) and in a strong one, square metres. A
## bigger sail is faster in light wind and overpowered in a strong one (F4's gear, when the game's
## sims take a sail per board; until then the number is shown, not sailed).
@export var sail_light_m2: float = 7.8
@export var sail_strong_m2: float = 6.2
@export var gear_switch_kt: float = 16.0

## The wander of a skill from race to race at consistency 0 (one standard deviation).
const WANDER_AT_ZERO: float = 0.25


## The character sheet for one race: the skills, each moved a little by the day (seeded), mapped
## onto the scripted skipper's numbers. The wind (knots) chooses the gear.
func to_skipper_config(seed: int, _wind_kt: float = 15.0) -> SkipperConfig:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed * 7919 + name.hash()
	var wander: float = (1.0 - clampf(consistency, 0.0, 1.0)) * WANDER_AT_ZERO
	var timing: float = _today(start_timing, wander, rng)
	var nerve: float = _today(start_nerve, wander, rng)
	var tacks: float = _today(tacking, wander, rng)
	var speed: float = _today(boat_speed, wander, rng)
	var upwind: float = _today(upwind_sense, wander, rng)
	var downwind: float = _today(downwind_sense, wander, rng)
	var risky: float = _today(risk, wander, rng)
	var config: SkipperConfig = SkipperConfig.new()
	config.name = name
	config.sail_colour = sail_colour
	# The hands: from the rookie's slow, wobbly stick to a steady one.
	config.reaction_time_s = clampf(lerpf(1.0, 0.2, speed), 0.2, 1.0)
	config.steering_noise_deg = clampf(lerpf(6.0, 0.3, speed), 0.0, 6.0)
	# Upwind: a poor sense sails low and tacks late; a good one points, reads the shifts and uses
	# the laylines; the risk sets the margins.
	config.pointing_offset_deg = clampf(pointing_offset_deg + lerpf(3.0, 0.0, upwind), -4.0, 6.0)
	config.layline_margin_m = clampf(lerpf(30.0, 8.0, risky) + lerpf(15.0, 0.0, upwind), 0.0, 60.0)
	config.mark_margin_m = clampf(lerpf(16.0, 5.0, risky), 4.0, 20.0)
	config.shift_sensitivity_deg = lerpf(20.0, 6.0, upwind)
	config.max_tacks_per_beat = clampi(2 + roundi(tacks * 4.0), 2, 8)
	# Downwind: a poor sense runs too deep and slow.
	config.downwind_vmg_twa_deg = clampf(lerpf(150.0, 135.0, downwind), 110.0, 170.0)
	config.gust_appetite = clampf(gust_appetite, 0.0, 1.0)
	# The start: its own spot, pulled to the favoured end by its nerve; the timing error drawn
	# from the day's spread, a risky skipper aiming early.
	config.start_spot = clampf(start_spot, 0.0, 1.0)
	config.favoured_end_bias = nerve
	config.start_style = start_style
	config.hold_speed_ms = lerpf(3.5, 2.5, nerve)
	var spread_s: float = lerpf(8.0, 0.5, timing)
	config.start_timing_error_s = clampf(rng.randfn(0.0, spread_s) + lerpf(1.5, -1.0, risky), -3.0, 6.0)
	config.keep_clear_m = clampf(lerpf(20.0, 8.0, clampf(aggression, 0.0, 1.0)), 5.0, 30.0)
	config.hold_speed_ms = clampf(config.hold_speed_ms, 1.5, 4.0)
	return config


## The sail it rigs for a wind, square metres.
func sail_m2_for(wind_kt: float) -> float:
	return sail_light_m2 if wind_kt < gear_switch_kt else sail_strong_m2


## Two lines for the menu: the name, the home water and the profile.
func card() -> String:
	return "%s (%s): %s" % [name, home_water, profile]


## A skill as it is today: moved by the day's wander, kept between 0 and 1.
static func _today(skill: float, wander: float, rng: RandomNumberGenerator) -> float:
	return clampf(skill + rng.randfn(0.0, wander), 0.0, 1.0)
