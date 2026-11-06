class_name LakeLook
extends RefCounted
## A lake's look in the wind (res://world/lake_look.gdshaderinc, which explains the model and its
## sources): the water shader's numbers for a lake's own waves (the short-crested parts it draws, worked
## out once here), and the look's formulas that the shader works out per pixel (Cox and Munk, Zhao and
## Toba) in GDScript too, for the tests and the report's tables. Only the picture: nothing here reaches
## the physics.

## Cox and Munk's wind height (m) and the whitecaps' law's (m).
const COX_MUNK_HEIGHT_M: float = 12.5
const WHITECAP_HEIGHT_M: float = 10.0
## Nodes with less sea than this (Hs, m) are left out of the lake's typical peak (the calm shore band).
const PEAK_MIN_HS_M: float = 0.01
## The shader's parts (lake_look.gdshaderinc): five per train drawn as shading (the lake's four trains,
## then the look train), each this much longer or shorter than its train; four per short octave, three
## octaves from 0.25 m down, halving (lake_look.gdshaderinc's SHORT_DRAWN).
const SPREAD_PARTS: int = 5
const SPREAD_STRETCH: Array[float] = [1.0, 1.15, 0.87, 1.07, 0.93]
const SPREAD_TRAINS: int = 5
const SHORT_PARTS: int = 4
const SHORT_STRETCH: Array[float] = [1.12, 0.90, 1.05, 0.94]
const SHORT_OCTAVES_DRAWN: int = 2
const SHORT_LONGEST_M: float = 0.25
## Surface tension over the density of water, m^3/s^2: short waves run faster (w^2 = g k + T k^3).
const WATER_TENSION: float = 7.4e-5
const G: float = 9.81


## The water shader's numbers for a lake's waves: the parts the picture draws (lake_spread_parts and
## lake_short_parts, each a direction, a wavelength and a frequency, spread around their train or the
## lake's wind by Donelan-Banner for the lake's typical peak), and a first lake_wind_ms (the wind the
## waves were built for at 10 m, and at 12.5 m with a 1/7 profile; the lake scene sets the wind of every
## moment).
static func shader_parameters(lake: LakeWaves) -> Dictionary[String, Variant]:
	var parameters: Dictionary[String, Variant] = {}
	var peak_omega: float = typical_peak_omega(lake)
	parameters["lake_spread_parts"] = spread_parts(lake, peak_omega)
	parameters["lake_short_parts"] = short_parts(WaveField.direction_for_bearing(lake.from_deg + 180.0), peak_omega)
	var wind_12m_ms: float = lake.wind_10m_ms * pow(COX_MUNK_HEIGHT_M / WHITECAP_HEIGHT_M, 1.0 / 7.0)
	parameters["lake_wind_ms"] = Vector2(lake.wind_10m_ms, wind_12m_ms)
	return parameters


## The parts of the trains drawn as shading: SPREAD_PARTS for each of the lake's trains (as many as the
## shader has slots for; an empty slot's parts have wavelength 0) and then the look train, each at
## Donelan-Banner's equal shares of the spread for its train's frequency.
static func spread_parts(lake: LakeWaves, peak_omega: float) -> PackedVector4Array:
	var parts: PackedVector4Array = PackedVector4Array()
	for train: int in SPREAD_TRAINS:
		var along: Vector2 = Vector2.ZERO
		var length_m: float = 0.0
		if train < SPREAD_TRAINS - 1 and train < lake.band_count:
			along = Vector2(lake.dir_x[train], lake.dir_z[train])
			length_m = lake.wavelength_m[train]
		elif train == SPREAD_TRAINS - 1:
			along = lake.look_dir
			length_m = lake.config.look_wavelength_m
		parts.append_array(_fanned_parts(along, length_m, SPREAD_STRETCH, peak_omega))
	return parts


## The parts of the short octaves: SHORT_PARTS each, spread around the lake's wind (`downwind`).
static func short_parts(downwind: Vector2, peak_omega: float) -> PackedVector4Array:
	var parts: PackedVector4Array = PackedVector4Array()
	var length_m: float = SHORT_LONGEST_M
	for octave: int in SHORT_OCTAVES_DRAWN:
		parts.append_array(_fanned_parts(downwind, length_m, SHORT_STRETCH, peak_omega))
		length_m *= 0.5
	return parts


## One train's parts: one per stretch, at Donelan-Banner's quantiles (equal shares of the spread) for the
## train's frequency against `peak_omega`, each (direction x, direction z, wavelength, frequency in Hz).
## A train of wavelength 0 gives empty parts.
static func _fanned_parts(along: Vector2, length_m: float, stretch: Array[float], peak_omega: float) -> PackedVector4Array:
	var parts: PackedVector4Array = PackedVector4Array()
	var count: int = stretch.size()
	if length_m <= 0.0:
		for j: int in count:
			parts.append(Vector4.ZERO)
		return parts
	var beta: float = donelan_banner_beta(angular_frequency(TAU / length_m) / peak_omega)
	for j: int in count:
		var u: float = (2.0 * j + 1.0) / count - 1.0
		var direction: Vector2 = along.rotated(donelan_banner_angle(u, beta))
		var part_m: float = length_m * stretch[j]
		parts.append(Vector4(direction.x, direction.y, part_m, angular_frequency(TAU / part_m) / TAU))
	return parts


## A short wave's angular frequency (rad/s) from its wave number: gravity and surface tension.
static func angular_frequency(k: float) -> float:
	return sqrt(G * k + WATER_TENSION * k * k * k)


## The lake's typical peak frequency, rad/s: 2 pi / the median peak period over the nodes with some sea.
static func typical_peak_omega(lake: LakeWaves) -> float:
	var heights: PackedFloat32Array = lake.look_values(2)
	var periods: PackedFloat32Array = lake.look_values(3)
	var chosen: PackedFloat32Array = PackedFloat32Array()
	for i: int in periods.size():
		if heights[i] >= PEAK_MIN_HS_M and periods[i] > 0.0:
			chosen.append(periods[i])
	if chosen.is_empty():
		return TAU / 1.0
	chosen.sort()
	return TAU / chosen[chosen.size() / 2]


## Cox and Munk (1954): the mean square slope of a clean sea in a wind of `wind_12m_ms` (m/s at 12.5 m).
static func cox_munk_mss(wind_12m_ms: float) -> float:
	return 0.003 + 0.00512 * maxf(wind_12m_ms, 0.0)


## The kinematic viscosity of the lake's air (m^2/s), as the shader's AIR_VISCOSITY.
const AIR_VISCOSITY: float = 1.8e-5


## Zhao and Toba (2001): the share of the water covered by whitecaps (0 to 1) in a wind of U10 m/s over
## waves whose peak period is `peak_period_s`; none from a breaking-wave parameter below about 1000.
static func whitecap_fraction(wind_10m_ms: float, peak_period_s: float) -> float:
	var parameter: float = breaking_wave_parameter(wind_10m_ms, peak_period_s)
	if parameter <= 0.0:
		return 0.0
	var percent: float = 3.88e-5 * pow(parameter, 1.09) * smoothstep(800.0, 1200.0, parameter)
	return minf(percent / 100.0, 0.2)


## Zhao and Toba's breaking-wave parameter R_B = u*^2 / (nu omega_p), with u*^2 = C_D U10^2 and Wu's
## C_D = 0.0008 + 0.000065 U10 (as NOAA's PyGnome codes it); 0 without wind or waves.
static func breaking_wave_parameter(wind_10m_ms: float, peak_period_s: float) -> float:
	if wind_10m_ms <= 0.0 or peak_period_s <= 0.0:
		return 0.0
	var drag: float = 0.0008 + 0.000065 * wind_10m_ms
	return drag * wind_10m_ms * wind_10m_ms / (AIR_VISCOSITY * TAU / peak_period_s)


## The wind (U10, m/s) at which waves of `peak_period_s` start to whitecap: R_B = 1000 (Toba and Koga).
static func whitecap_onset_ms(peak_period_s: float) -> float:
	var low: float = 0.0
	var high: float = 40.0
	for i: int in 50:
		var middle: float = 0.5 * (low + high)
		if breaking_wave_parameter(middle, peak_period_s) < 1000.0:
			low = middle
		else:
			high = middle
	return 0.5 * (low + high)


## Donelan-Banner's spreading parameter beta at `ratio` times the peak frequency (Horvath 2015, eq. 38).
static func donelan_banner_beta(ratio: float) -> float:
	var r: float = maxf(ratio, 0.2)
	if r < 0.95:
		return 2.61 * pow(r, 1.3)
	if r < 1.6:
		return 2.28 * pow(r, -1.3)
	return pow(10.0, -0.4 + 0.8393 * exp(-0.567 * log(r * r)))


## The direction (radians off the wind) of Donelan-Banner's quantile u (-1 to 1): the share (u + 1) / 2
## of the waves travels at a smaller angle.
static func donelan_banner_angle(u: float, beta: float) -> float:
	return atanh(u * tanh(beta * PI)) / beta


## The share of Donelan-Banner's waves within `angle` radians either side of the wind.
static func donelan_banner_share_within(angle: float, beta: float) -> float:
	return tanh(beta * angle) / tanh(beta * PI)


## The value a Gaussian with spread 1 exceeds with probability p (Abramowitz and Stegun 26.2.23).
static func gaussian_exceeded(p: float) -> float:
	var t: float = sqrt(-2.0 * log(p))
	return t - (2.515517 + 0.802853 * t + 0.010328 * t * t) / (1.0 + 1.432788 * t + 0.189269 * t * t + 0.001308 * t * t * t)


## The same for a sum of sine waves (the shader's sines_exceeded()): the Cornish-Fisher correction for
## its excess kurtosis; `variance` is the sum's (0.5 s^2 each), `fourth` the sum of the steepnesses^4.
static func sines_exceeded(p: float, variance: float, fourth: float) -> float:
	var z: float = gaussian_exceeded(p)
	var kurtosis: float = -0.375 * fourth / maxf(variance * variance, 1e-12)
	return z + (z * z * z - 3.0 * z) * kurtosis / 24.0
