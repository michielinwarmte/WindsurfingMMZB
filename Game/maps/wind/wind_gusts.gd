class_name WindGusts
extends Resource
## The moving weather on top of the fixed pattern (MAP_SILVAPLANA_PLAN.md, W3 and WD2): the gusts
## and lulls on the lake, and the slower pulses and shifts. Everything follows from the seed and the
## time of day, so a day can be replayed exactly and looked at at any speed.
##
## Gusts and lulls. The satellite photos (MALOJA_WIND_RESEARCH.md, "Gusts seen from space") show
## the wind on the lake as one moving pattern of stronger and lighter areas, about as many lulls as
## gusts, not as separate patches. So the gusts are a smooth random pattern ("noise") made of two
## parts, both rolling down the lake with the air and slowly changing while they roll:
## - fronts: bands of more and less wind across the whole lake ("mostly fronts", Max; on the photos
##   about 40 % of the ups and downs on the days with fronts);
## - lanes: stripes along the wind, about 1.8 times as long as wide (on most photos; Max: 50 to 100 m
##   wide).
## How much the wind goes up and down (the spread) comes from the photos at 12:28. In knots it
## changes only slowly with the wind's strength (the station), so a gust also reaches full strength
## in a weak place ("the little corner", Max).
##
## The numbers were fitted by putting the model through exactly the same analysis as the photos
## (Game/maps/silvaplana/dev/export_gusts.gd, then tools/map/gust_shapes.py --model). That analysis
## can't see all of a front a kilometre long (it partly looks like a tilt and is taken out), so the
## model's true spread (about 12 % at 12:28) is bigger than what the analysis shows (8 %), on the
## photos as on the model.
## The wind also turns in the gusts: the sideways ups and downs are 0.8 times the ones along the
## wind, as measured in turbulence over flat ground (Panofsky and Dutton 1984).
##
## Pulses and shifts: the whole lake gets stronger and lighter, and turns left and right, over 10 to
## 45 minutes (the station: +-8 % and +-6 degrees typical). They travel down the lake too.
##
## MapWind uses this; the shaders compute exactly the same (wind_pattern.gdshaderinc): the same
## random numbers (noise_3d(), built from whole-number arithmetic that the graphics card does
## the same way) and the same sums.

## Which day: another seed gives other gusts, pulses and shifts.
@export var seed: int = 1

@export_group("How much the wind goes up and down")
## The spread (standard deviation) of the gusts and lulls, knots: base + per_knot x the lake's mean
## wind. The shape is the station's: its strongest 1-second gust in 10 minutes is 1.71 kt + 0.40 x
## the mean (a straight line through the 12 hourly medians, 10:00 to 21:00; it misses by at most
## 0.7 kt). The size is the photos': fitted so the model, through the same analysis, shows the
## photos' spread on the days with fronts (8.1 %), with 10 % brighter water taken as 10 % more
## wind, as in W1.
@export var spread_base_kt: float = 0.48
@export var spread_per_knot: float = 0.087
## The sideways ups and downs (which turn the wind) as a share of the ones along the wind: 0.8 in
## turbulence over flat ground (Panofsky and Dutton 1984).
@export var sideways_share: float = 0.8
## How the ups and downs are shared between fronts and lanes (the rest), as a share of the variance:
## fitted so the model, through the same analysis, shows what the photos show on the days with
## fronts (the across-lake bands carry 38 %; the photos: 39 %).
@export var front_share: float = 0.7

@export_group("Fronts: bands across the lake")
## The size of the noise's cells along the wind and across it, metres: fronts are about 500 to
## 800 m deep and the next one comes 1.6 to 1.8 km later on the photos (900 m fitted the photos best,
## of 800 and 900); across, the cells are much wider than the lake, so a front crosses all of it.
@export var front_cell_along_m: float = 900.0
@export var front_cell_across_m: float = 4000.0
## How long it takes a front to change completely, seconds: its cell along the wind divided by the
## spread of the wind (900 m / 0.92 m/s at 12:28), the usual estimate for how long a swirl of air
## lives. An estimate: not measured.
@export var front_life_s: float = 980.0

@export_group("Lanes: stripes along the wind")
## The size of the noise's cells along the wind and across it, metres: fitted so the model's lanes,
## through the same analysis, have the photos' shape on the days with lanes (107 x 56 m where the
## correlation is still 0.3; the photos: 110 x 56 m).
@export var lane_cell_along_m: float = 190.0
@export var lane_cell_across_m: float = 100.0
## How long it takes a lane to change completely, seconds (as for the fronts, 190 m / 0.92 m/s: an
## estimate).
@export var lane_life_s: float = 210.0

@export_group("Movement and place")
## How fast the gusts, pulses and shifts travel down the lake, times the lake's mean wind. Big
## eddies come from higher up, where the wind is stronger (the research, "Gusts"); how much faster
## is not measured: an estimate.
@export var drift_factor: float = 1.1
## How gusty the upwind (Sils) and the downwind end of the lake are, and where those ends are
## (metres along the lake from its middle, downwind positive). The photos show the same spread in
## both halves (7.0 and 7.5 %); Max finds the downwind end "a little" steadier.
@export var gustiness_upwind: float = 1.0
@export var gustiness_downwind: float = 1.0
@export var upwind_end_m: float = -1700.0
@export var downwind_end_m: float = 1700.0

@export_group("The lee: which gusts get through")
## The share of the gusts strong enough to reach into a lee (WindLee) and lift it there, so the
## water is as windy as the open lake: Max, about the south-east shore, "only once in every 10 or
## so there is a gust that is favourable and goes down all the way"; the photos agree (on the days
## with a lee, 7 of 54 pieces of the band were as rough as the open lake, about 1 in 8).
@export var reach_share: float = 0.1
## How gradually a strong gust lifts the lee, in the gusts' spread: it only sets how soft the edge
## of a reaching gust is. An estimate.
@export var reach_width: float = 0.5

@export_group("Pulses and shifts")
## Three slow waves each, of different lengths, so together they look irregular. Speed: a share of
## the mean (the station: half the time within +-8 %); turn: degrees (the station: 6 degrees typical).
@export var pulse_amplitudes: PackedFloat32Array = PackedFloat32Array([0.10, 0.07, 0.05])
@export var pulse_periods_s: PackedFloat32Array = PackedFloat32Array([2220.0, 1380.0, 780.0])
@export var shift_amplitudes_deg: PackedFloat32Array = PackedFloat32Array([6.0, 4.0, 2.5])
@export var shift_periods_s: PackedFloat32Array = PackedFloat32Array([2700.0, 1500.0, 840.0])


var _phases: Dictionary[int, Vector3] = {}
var _phases_seed: int = -1
var _reach_centre: float = NAN
var _reach_key: Vector4 = Vector4.ZERO


## The spread of the gusts and lulls along the wind, m/s, for the lake's mean wind.
func spread_ms(lake_speed_ms: float) -> float:
	var knots: float = spread_base_kt + spread_per_knot * lake_speed_ms / SimMath.KNOT_MS
	return knots * SimMath.KNOT_MS


## How fast the gusts, pulses and shifts travel down the lake, m/s (at least 2 m/s).
func drift_ms(lake_speed_ms: float) -> float:
	return maxf(lake_speed_ms * drift_factor, 2.0)


## How gusty a place is, from the upwind to the downwind end (along: metres from the lake's middle).
func gustiness(along_m: float) -> float:
	return lerpf(gustiness_upwind, gustiness_downwind, smoothstep(upwind_end_m, downwind_end_m, along_m))


## The gusts and lulls at a place and moment, with a spread of 1: Vector2(along the wind, sideways).
## rolled_m is the place's distance along the lake in the air's own frame (along minus how far
## the air has travelled, MapWind.travel_m()), across_m its distance across the lake.
func gusts_at(rolled_m: float, across_m: float, time_of_day_s: float) -> Vector2:
	var front_weight: float = sqrt(front_share)
	var lane_weight: float = sqrt(1.0 - front_share)
	var result: Vector2 = Vector2.ZERO
	for part: int in 2:  # 0: along the wind, 1: sideways
		var front: float = noise_3d(rolled_m / front_cell_along_m, across_m / front_cell_across_m,
			time_of_day_s / front_life_s, seed * 4 + part * 2)
		var lane: float = noise_3d(rolled_m / lane_cell_along_m, across_m / lane_cell_across_m,
			time_of_day_s / lane_life_s, seed * 4 + part * 2 + 1)
		result[part] = front_weight * front + lane_weight * lane
	return result


## How much a gust gets into a lee, from 0 (not at all) to 1 (fully): the strongest reach_share of
## the gusts do. unit_along is the gust along the wind with a spread of 1 (gusts_at().x).
func reach(unit_along: float) -> float:
	var centre: float = reach_centre()
	return smoothstep(centre - reach_width / 2.0, centre + reach_width / 2.0, unit_along)


## The gust strength (with a spread of 1) at which half of a gust gets into a lee: chosen so that on
## average reach() is reach_share. Worked out once from 4000 places and moments of this seed's gusts.
func reach_centre() -> float:
	var key: Vector4 = Vector4(seed, front_share, reach_share, reach_width)
	if not is_nan(_reach_centre) and key == _reach_key:
		return _reach_centre
	var random: RandomNumberGenerator = RandomNumberGenerator.new()
	random.seed = hash([seed, "reach"])
	var values: PackedFloat32Array = PackedFloat32Array()
	for i: int in 4000:
		values.append(gusts_at(random.randf_range(-1e6, 1e6), random.randf_range(-700.0, 700.0),
			random.randf_range(10.0, 20.0) * 3600.0).x)
	var low: float = -3.0
	var high: float = 5.0
	for step: int in 40:  # halve the range until the average reach is reach_share
		var centre: float = (low + high) / 2.0
		var total: float = 0.0
		for value: float in values:
			total += smoothstep(centre - reach_width / 2.0, centre + reach_width / 2.0, value)
		if total / values.size() > reach_share:
			low = centre
		else:
			high = centre
	_reach_centre = (low + high) / 2.0
	_reach_key = key
	return _reach_centre


## The pulse at a moment: how much stronger (or, negative, lighter) the wind is, as a share.
## tau is the time of day minus the time the pulse needs to travel to this place (MapWind).
func pulse(tau_s: float) -> float:
	return _waves(tau_s, pulse_amplitudes, pulse_periods_s, 1)


## The shift at a moment, radians, positive turned clockwise (the wind from further right).
func shift_rad(tau_s: float) -> float:
	return deg_to_rad(_waves(tau_s, shift_amplitudes_deg, shift_periods_s, 2))


## The phases of the slow waves (radians), fixed by the seed: kind 1 the pulses, kind 2 the shifts.
## Worked out once per seed (this is asked for at every place the wind is computed).
func phases(kind: int) -> Vector3:
	if _phases_seed != seed or not _phases.has(kind):
		if _phases_seed != seed:
			_phases.clear()
			_phases_seed = seed
		var random: RandomNumberGenerator = RandomNumberGenerator.new()
		random.seed = hash([seed, "waves", kind])
		_phases[kind] = Vector3(random.randf() * TAU, random.randf() * TAU, random.randf() * TAU)
	return _phases[kind]


func _waves(tau_s: float, amplitudes: PackedFloat32Array, periods_s: PackedFloat32Array, kind: int) -> float:
	var phase: Vector3 = phases(kind)
	var sum: float = 0.0
	for i: int in 3:
		sum += amplitudes[i] * sin(TAU * tau_s / periods_s[i] + phase[i])
	return sum


# ---------------------------------------------------------------- the noise, the same on the graphics card

## Smooth random values in 3D ("value noise") with a spread of 1 everywhere: a random number between
## -1 and 1 on every corner of a grid of cells of size 1, blended smoothly in between. The same x, y,
## z and stream always give the same value; different streams give unrelated patterns.
## wind_pattern.gdshaderinc has the same.
##
## A blend of random numbers varies less than the numbers themselves, and how much less depends on
## where in the cell the point is: on a corner it is the corner's own number, in the middle an
## average of 8. Left like that, the gusts would be stronger along the grid's lines and on its
## moments than in between, a rhythm that isn't weather. So the blend is divided by its own spread
## at that point: the corners' spread (1 / sqrt(3)) times the square root of the sum of the squared
## weights. Then the spread is exactly 1 at every place and moment.
static func noise_3d(x: float, y: float, z: float, stream: int) -> float:
	var ix: int = floori(x)
	var iy: int = floori(y)
	var iz: int = floori(z)
	var fx: float = _fade(x - ix)
	var fy: float = _fade(y - iy)
	var fz: float = _fade(z - iz)
	var result: float = 0.0
	for corner: int in 8:
		var cx: int = corner & 1
		var cy: int = (corner >> 1) & 1
		var cz: int = (corner >> 2) & 1
		var weight: float = (fx if cx == 1 else 1.0 - fx) * (fy if cy == 1 else 1.0 - fy) * (fz if cz == 1 else 1.0 - fz)
		result += weight * _corner(ix + cx, iy + cy, iz + cz, stream)
	var squared_weights: float = (fx * fx + (1.0 - fx) * (1.0 - fx)) * (fy * fy + (1.0 - fy) * (1.0 - fy)) 		* (fz * fz + (1.0 - fz) * (1.0 - fz))
	return result / sqrt(squared_weights / 3.0)


## The smooth blend: 0 at 0, 1 at 1, flat at both ends (so the cells' edges don't show).
static func _fade(t: float) -> float:
	return t * t * t * (t * (t * 6.0 - 15.0) + 10.0)


## The random value of a grid corner, between -1 and 1.
static func _corner(ix: int, iy: int, iz: int, stream: int) -> float:
	var h: int = _hash32(_add32(ix, _hash32(_add32(iy, _hash32(_add32(iz, _hash32(stream & 0xFFFFFFFF)))))))
	return float(h) / 4294967295.0 * 2.0 - 1.0


## A well-mixed 32-bit hash ("lowbias32", C. Wellons). GDScript's whole numbers have 64 bits, so
## everything is kept to 32 bits by hand, to get exactly what the graphics card's 32-bit numbers give.
static func _hash32(x: int) -> int:
	x ^= x >> 16
	x = _mul32(x, 0x7feb352d)
	x ^= x >> 15
	x = _mul32(x, 0x846ca68b)
	x ^= x >> 16
	return x


static func _add32(a: int, b: int) -> int:
	return (a + b) & 0xFFFFFFFF


## a x b, keeping only the lowest 32 bits, without ever going over 48 bits (a and b below 2^32).
static func _mul32(a: int, b: int) -> int:
	return ((((a >> 16) * b & 0xFFFF) << 16) + (a & 0xFFFF) * b) & 0xFFFFFFFF
