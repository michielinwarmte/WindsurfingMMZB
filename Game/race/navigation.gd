class_name Navigation
extends RefCounted
## The navigation skill of a skipper's head (AI_FLEET_PLAN.md, D4): the way to a point with the
## fewest manoeuvres, as a sailor plans it.
##   - A point on a reach or a run (its bearing between the beat's track and the run's track off
##     the wind) is sailed straight: no manoeuvre on the present tack, one tack or gybe first on
##     the other.
##   - A point upwind of the beat's track (or downwind of the run's track, dead downwind) cannot
##     be sailed straight. It is reached in two legs, one on each tack, the present tack first,
##     with one tack or gybe at the corner where the board meets the other tack's layline. A leg
##     shorter than LAID_WITHIN_M needs no turn of its own: the board lays the point.
## A plain class with static functions, so the tests can check a route without a board. Bearings
## are compass degrees, wind angles are positive with the wind from starboard (CLAUDE.md, D4),
## positions are game metres, Vector2(X east, Z south), as in Course.

## A leg shorter than this needs no tack or gybe of its own, metres: the board lays the point.
const LAID_WITHIN_M: float = 10.0


## A planned way to a point.
class Route:
	## The tacks or gybes on the way: 0 or 1.
	var manoeuvres: int = 0
	## True when the way is a beat (upwind of the beat's track) or a run deeper than the run's track.
	var upwind: bool = false
	var downwind: bool = false
	## The present tack is not the tack of the first leg: the manoeuvre is made at once.
	var turn_first: bool = false
	## Where the tack or gybe is made (the layline corner), or the start when it is made at once.
	## The target itself when there is none.
	var corner: Vector2 = Vector2.ZERO
	## The lengths of the leg on the present tack and of the leg on the other, metres.
	var first_m: float = 0.0
	var second_m: float = 0.0

	## The whole way, metres.
	func distance_m() -> float:
		return first_m + second_m


## The way from one point to another in a wind (where it comes from, degrees), on a tack (+1
## starboard, -1 port), for a board whose track over the ground runs up_track_deg off the wind on
## a beat and down_track_deg on a run (the angles it sails plus its leeway).
static func route(from: Vector2, to: Vector2, wind_deg: float, tack: float, up_track_deg: float, down_track_deg: float) -> Route:
	var way: Route = Route.new()
	var needed_twa: float = wind_angle_deg(from, to, wind_deg)
	way.upwind = absf(needed_twa) < up_track_deg
	way.downwind = absf(needed_twa) > down_track_deg
	if not way.upwind and not way.downwind:
		# Straight there: on this tack if the wind comes from the side the tack says.
		way.first_m = from.distance_to(to)
		way.corner = to
		if signf(needed_twa) != tack:
			way.turn_first = true
			way.manoeuvres = 1
			way.corner = from
			way.second_m = way.first_m
			way.first_m = 0.0
		return way
	# Two legs along the two tacks' tracks, this tack first.
	var track_deg: float = up_track_deg if way.upwind else down_track_deg
	var this: Vector2 = Course.direction_of(wind_deg - tack * track_deg)
	var other: Vector2 = Course.direction_of(wind_deg + tack * track_deg)
	var legs: Vector2 = split_along(to - from, this, other)
	way.first_m = legs.x
	way.second_m = legs.y
	way.corner = from + this * legs.x
	if legs.x <= LAID_WITHIN_M and legs.y > LAID_WITHIN_M:
		# All of it on the other tack: a tack or gybe first.
		way.turn_first = true
		way.manoeuvres = 1
		way.corner = from
	elif legs.x > LAID_WITHIN_M and legs.y > LAID_WITHIN_M:
		way.manoeuvres = 1
	return way


## The true wind angle of the straight course from one point to another, degrees, positive with the
## wind from starboard: the wind's direction less the bearing.
static func wind_angle_deg(from: Vector2, to: Vector2, wind_deg: float) -> float:
	return wrapf(wind_deg - Course.bearing_deg(from, to), -180.0, 180.0)


## A way split into two legs along two directions (one metre long each): the lengths (along a,
## along b), metres, each at least 0.
static func split_along(way: Vector2, a: Vector2, b: Vector2) -> Vector2:
	var det: float = a.x * b.y - a.y * b.x
	if absf(det) < 1e-6:
		return Vector2(way.length(), 0.0)
	var along_a: float = (way.x * b.y - way.y * b.x) / det
	var along_b: float = (a.x * way.y - a.y * way.x) / det
	return Vector2(maxf(along_a, 0.0), maxf(along_b, 0.0))
