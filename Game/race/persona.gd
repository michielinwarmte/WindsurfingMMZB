class_name Persona
extends Resource
## A persona of the AI fleet (AI_FLEET_PLAN.md, D3: "one strong brain, many personas"): a name, a
## colour, a home water, a short profile the menu shows, and a skill sheet of numbers from 0 to 1
## that degrade or bias one good skipper. A persona never touches the physics (RD7): it makes the
## hands clumsier or the head bolder, and it rigs gear from the game's catalogue, which the player
## can sail too; nobody gets a lighter board or more wind.
##
## For a scripted skipper (Skipper) the sheet becomes a character sheet (SkipperConfig) by
## to_skipper_config(): each skill maps onto the numbers the scripted rules use, between the
## rookie's end (0) and the all-rounder's and better (1): the angles, the margins, the hands'
## reaction and noise, the start, and the push slider (a bold sailor pushes, a careful one eases).
## Two wind skills make a light-wind or a strong-wind specialist: in its wind its sailing skills are
## better, out of it worse (wind_form()). Consistency draws each race's sheet a little differently
## (seeded): a persona has good days and bad days. gear_for() is its board, sail and fin for the
## wind, from its brands' slalom lines (package 3 of fleet_speed/PLAN.md, characters.md).
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

@export_group("Wind")
## How well it sails in a light wind (LIGHT_WIND_KT and less): feel, patience, pumping onto the
## plane. 0.5 sails as well there as anywhere; more is a light-wind specialist, less one who is
## bored and slow when it is light.
@export_range(0.0, 1.0) var light_wind: float = 0.5
## How well it sails in a strong wind (STRONG_WIND_KT and more): control and nerve when overpowered.
## 0.5 as anywhere; more is a strong-wind specialist, less one who hangs on when it blows.
@export_range(0.0, 1.0) var strong_wind: float = 0.5

@export_group("Gear")
## The brands it sails (the slug of a brand in Game/gear/brands/): its sail and its board come from
## their slalom lines in the gear catalogue, sized for the wind (gear_for()). The look and the brand
## are part of the character. A brand that makes no such item gives the default item.
@export var sail_brand: String = "savanna"
@export var board_brand: String = "pj_new_sealand"

## The wander of a skill from race to race at consistency 0 (one standard deviation).
const WANDER_AT_ZERO: float = 0.25

## The winds of the race matrix: the wind skills count fully at LIGHT_WIND_KT and below and at
## STRONG_WIND_KT and above, and not at all at MIDDLE_WIND_KT (in between, part of the way).
const LIGHT_WIND_KT: float = 12.0
const MIDDLE_WIND_KT: float = 18.0
const STRONG_WIND_KT: float = 24.0
## How much a wind skill moves its sailing skills (tacking, boat speed, upwind and downwind sense)
## in its own wind: a wind skill of 1 adds half of this, 0 takes half of it away.
const WIND_FORM_WEIGHT: float = 0.6

## The push slider (SkipperConfig.push_offset, a share of the slider): its risk moves it up to this
## far either way from the pilot's own margin (a bold sailor pushes, a careful one eases)...
const PUSH_FROM_RISK: float = 0.1
## ...and its hands (boat speed) up to this far: good hands hold a pushed board, poor ones do not.
const PUSH_FROM_HANDS: float = 0.05
## Never more than this either way. Package 1 measured 95 % (an offset of about +0.17) on the 24 kt
## reaches: two to seven falls a race (skipper_speed.md, lever 3).
const PUSH_MAX: float = 0.15
## An offset smaller than this is no offset: a middling sailor leaves the slider alone and sails
## the pilot's own margin (a slider taken at all sails a little differently from the pilot's margin).
const PUSH_DEAD_ZONE: float = 0.02

## How big a rig it chooses (gear_for()): a light-wind sailor rigs big, a strong-wind sailor small,
## and a risk-taker a size up. 0.5 is the middle of what the catalogue says fits the wind.
const RIG_FROM_WIND_SKILLS: float = 0.5
const RIG_FROM_RISK: float = 0.4


## The character sheet for one race: the skills, each moved by its form in this wind (wind_form())
## and a little by the day (seeded), mapped onto the scripted skipper's numbers.
func to_skipper_config(seed: int, wind_kt: float = 15.0) -> SkipperConfig:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed * 7919 + name.hash()
	var wander: float = (1.0 - clampf(consistency, 0.0, 1.0)) * WANDER_AT_ZERO
	var form: float = wind_form(wind_kt)
	var timing: float = _today(start_timing, wander, rng)
	var nerve: float = _today(start_nerve, wander, rng)
	var tacks: float = _today(clampf(tacking + form, 0.0, 1.0), wander, rng)
	var speed: float = _today(clampf(boat_speed + form, 0.0, 1.0), wander, rng)
	var upwind: float = _today(clampf(upwind_sense + form, 0.0, 1.0), wander, rng)
	var downwind: float = _today(clampf(downwind_sense + form, 0.0, 1.0), wander, rng)
	var risky: float = _today(risk, wander, rng)
	var config: SkipperConfig = SkipperConfig.new()
	config.name = name
	config.sail_colour = sail_colour
	# The hands: from the rookie's slow, wobbly stick to a steady one.
	config.reaction_time_s = clampf(lerpf(1.0, 0.2, speed), 0.2, 1.0)
	config.steering_noise_deg = clampf(lerpf(6.0, 0.3, speed), 0.0, 6.0)
	config.push_offset = push_offset_for(risky, speed)
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


## How much better (positive) or worse (negative) it sails in this wind (knots) than its sheet
## says: its light-wind skill below MIDDLE_WIND_KT, its strong-wind skill above, each counting
## fully at the matrix's light and strong wind; at most WIND_FORM_WEIGHT / 2 either way.
func wind_form(wind_kt: float) -> float:
	if wind_kt <= MIDDLE_WIND_KT:
		var light_share: float = clampf((MIDDLE_WIND_KT - wind_kt) / (MIDDLE_WIND_KT - LIGHT_WIND_KT), 0.0, 1.0)
		return (clampf(light_wind, 0.0, 1.0) - 0.5) * WIND_FORM_WEIGHT * light_share
	var strong_share: float = clampf((wind_kt - MIDDLE_WIND_KT) / (STRONG_WIND_KT - MIDDLE_WIND_KT), 0.0, 1.0)
	return (clampf(strong_wind, 0.0, 1.0) - 0.5) * WIND_FORM_WEIGHT * strong_share


## Its hand on the push slider (SkipperConfig.push_offset) from the day's risk and boat speed, 0 to
## 1 each: a bold skipper with good hands pushes past the pilot's own margin (faster on a reach in
## a breeze, and more falls), a careful one or poor hands ease it (slower, safer); a middling one
## leaves it alone. In 12 kt the slider changes nothing (PH26), whatever the offset.
static func push_offset_for(risk_today: float, speed_today: float) -> float:
	var offset: float = lerpf(-PUSH_FROM_RISK, PUSH_FROM_RISK, risk_today) + lerpf(-PUSH_FROM_HANDS, PUSH_FROM_HANDS, speed_today)
	if absf(offset) < PUSH_DEAD_ZONE:
		return 0.0
	return clampf(offset, -PUSH_MAX, PUSH_MAX)


## How big a rig it chooses, 0 (the smallest that fits the wind: in control) to 1 (the biggest:
## all the power it can hold): a light-wind sailor rigs big, a strong-wind sailor small, a
## risk-taker a size up.
func rig_power() -> float:
	return clampf(0.5 + (light_wind - strong_wind) * RIG_FROM_WIND_SKILLS + (risk - 0.5) * RIG_FROM_RISK, 0.0, 1.0)


## The gear it sails in a wind (knots), from the gear catalogue (GE5): its sail brand's sail and its
## board brand's board whose wind ranges (the catalogue's own) cover the wind, from the slalom line
## (a brand without one, its free race line: a beginner's wider board), and a slalom fin of any
## maker, each of a size by its rig_power(). The race tool and the race scene build its board's
## simulation and its look on this gear (GearChoice.sim_with()) when the race's gear is on.
func gear_for(wind_kt: float) -> GearChoice:
	var power: float = rig_power()
	var choice: GearChoice = GearChoice.defaults()
	var board: GearItem = pick_for_wind(brand_items(GearItem.Kind.BOARD, board_brand), wind_kt, power)
	var sail: GearItem = pick_for_wind(brand_items(GearItem.Kind.SAIL, sail_brand), wind_kt, power)
	var fin: GearItem = pick_for_wind(brand_items(GearItem.Kind.FIN, ""), wind_kt, power)
	if board != null:
		choice.board = board
	if sail != null:
		choice.sail = sail
	if fin != null:
		choice.fin = fin
	return choice


## Of some items, the one for a wind (knots): among those whose wind range covers the wind (or, if
## none does, those whose range comes nearest), from the smallest (power 0) to the biggest (power
## 1). null if there are no items.
static func pick_for_wind(items: Array[GearItem], wind_kt: float, power: float) -> GearItem:
	if items.is_empty():
		return null
	var nearest_kt: float = INF
	for item: GearItem in items:
		nearest_kt = minf(nearest_kt, _outside_range_kt(item, wind_kt))
	var fitting: Array[GearItem] = []
	for item: GearItem in items:
		if _outside_range_kt(item, wind_kt) <= nearest_kt + 1e-3:
			fitting.append(item)
	fitting.sort_custom(func(a: GearItem, b: GearItem) -> bool: return a.size < b.size)
	return fitting[roundi(clampf(power, 0.0, 1.0) * (fitting.size() - 1))]


## How far a wind (knots) is outside an item's wind range: 0 inside it.
static func _outside_range_kt(item: GearItem, wind_kt: float) -> float:
	return maxf(maxf(item.wind_from_kt - wind_kt, wind_kt - item.wind_to_kt), 0.0)


## The catalogue's items of one kind from one brand (its slug; "" for every brand): its slalom
## line, or all its lines when it has no slalom item of that kind.
static func brand_items(kind: GearItem.Kind, brand_slug: String) -> Array[GearItem]:
	var slalom: Array[GearItem] = []
	var every: Array[GearItem] = []
	for item: GearItem in GearCatalogue.items(kind):
		if not brand_slug.is_empty() and (item.brand == null or item.brand.slug != brand_slug):
			continue
		every.append(item)
		if item.line == GearItem.Line.SLALOM:
			slalom.append(item)
	return slalom if not slalom.is_empty() else every


## Two lines for the menu: the name, the home water and the profile.
func card() -> String:
	return "%s (%s): %s" % [name, home_water, profile]


## A skill as it is today: moved by the day's wander, kept between 0 and 1.
static func _today(skill: float, wander: float, rng: RandomNumberGenerator) -> float:
	return clampf(skill + rng.randfn(0.0, wander), 0.0, 1.0)
