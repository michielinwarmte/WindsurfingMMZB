class_name RaceTimeLimit
extends RefCounted
## How long a race may run after the gun (RaceSim.time_limit_s), from its course and its wind
## (Documentation/reports/fleet_speed/start.md, RA20): LIMIT_SHARE times the time the skipper's
## polar says the course takes, and never less than FLOOR_S. A fixed 20 minutes ended a 12 kt race
## on T1 before a slow board in a fleet of twenty had finished (Ravi, 126 m from the line after four
## penalty circles), and would end a race of two laps there before anyone finished.
##
## The polar's time for a leg: on a beat the board zigzags at the polar's best upwind angle, so it
## takes the way the leg goes toward the wind over its speed toward the wind there (its VMG); on a
## run the same with the best downwind angle; on a reach it sails straight at the polar's speed. No
## time for the tacks, gybes and roundings: the share covers them (the all-rounder alone on T1 takes
## about 1.4 times the polar's time, the slowest of twenty in a fleet about 2).

## The limit is never shorter than this, seconds (the race's old fixed limit).
const FLOOR_S: float = 1200.0
## The limit is this many times the polar's time for the course.
const LIMIT_SHARE: float = 2.5


## The time limit for a race on its course in a wind (where it blows from, degrees; its strength,
## knots), seconds after the gun. The polar is the skippers' (SkipperPolar's default when null).
static func for_race(race: RaceSim, wind_from_deg: float, wind_kt: float, polar: SkipperPolar = null) -> float:
	return maxf(FLOOR_S, LIMIT_SHARE * course_time_s(race.steps(), wind_from_deg, wind_kt, polar))


## The polar's time for a race's steps, seconds: from each step's target (a mark, or the middle of a
## line) to the next one's, the start's to the finish's.
static func course_time_s(steps: Array[RaceStep], wind_from_deg: float, wind_kt: float, polar: SkipperPolar = null) -> float:
	if polar == null:
		polar = SkipperPolar.default_polar()
	var total_s: float = 0.0
	for i: int in range(1, steps.size()):
		total_s += leg_time_s(steps[i - 1].target(), steps[i].target(), wind_from_deg, wind_kt, polar)
	return total_s


## The polar's time for one leg, seconds (see the top of this file).
static func leg_time_s(from: Vector2, to: Vector2, wind_from_deg: float, wind_kt: float, polar: SkipperPolar) -> float:
	var distance_m: float = from.distance_to(to)
	if distance_m < 0.01:
		return 0.0
	var leg_twa: float = absf(wrapf(wind_from_deg - Course.bearing_deg(from, to), -180.0, 180.0))
	var up_deg: float = SkipperPolar.per_wind(polar.winds_kt, polar.best_upwind_twa_deg, wind_kt)
	var down_deg: float = SkipperPolar.per_wind(polar.winds_kt, polar.best_downwind_twa_deg, wind_kt)
	var sail_twa: float = clampf(leg_twa, up_deg, down_deg)
	var speed_ms: float = maxf(SkipperPolar.value_at(polar.winds_kt, polar.twa_deg, polar.speed_ms, wind_kt, sail_twa), 0.5)
	if leg_twa < up_deg or leg_twa > down_deg:
		# The way toward (or away from) the wind over the speed made that way.
		var made_good: float = absf(cos(deg_to_rad(sail_twa)))
		return distance_m * absf(cos(deg_to_rad(leg_twa))) / (speed_ms * maxf(made_good, 0.05))
	return distance_m / speed_ms
