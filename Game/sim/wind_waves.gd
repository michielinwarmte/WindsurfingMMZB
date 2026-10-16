class_name WindWaves
extends RefCounted
## Waves made by the wind (PHYSICS_SPEC.md 9.16; the map's request R6). The longer the
## wind blows over open water (the fetch), the higher and longer the waves it makes. This
## turns the wind speed, the fetch and the water depth into a chop: two Gerstner waves the
## wave set can use. Only static functions, no state, so the tests can call them directly.
##
## The steps:
##   1. Deep water: the fetch-limited JONSWAP relations give the significant wave height
##      Hs and the peak period Tp (significant_height_m, peak_period_s).
##   2. Shallow water: breaking keeps Hs below about 0.6 of the depth, and the dispersion
##      relation with depth makes a wave of the same period shorter (wavelength_m).
##   3. Two waves for the wave set: the peak wave and one shorter wave (chop_waves).

const G: float = 9.81
## Pass this as the depth for deep water (no depth limit).
const DEEP_WATER: float = INF

## Fetch-limited growth, JONSWAP (Hasselmann et al. 1973), in the form of the Shore
## Protection Manual (SPM 1984, chapter 3):
##   g·Hs / U² = 0.0016 · (g·F / U²)^(1/2)
##   g·Tp / U  = 0.286  · (g·F / U²)^(1/3)
## U is the wind speed at 10 m (the R6 table in PHYSICS_REQUESTS_FROM_MAP.md uses U10
## directly, so this does too; the SPM corrects U for the air's stability first).
const HEIGHT_COEFFICIENT: float = 0.0016
const PERIOD_COEFFICIENT: float = 0.286
## A sea that has blown long enough stops growing: the fully developed limits of the SPM
## (1984), g·Hs / U² = 0.2433 and g·Tp / U = 8.134. Only reached at low wind over a long
## fetch (4 kt over 20 km).
const FULLY_DEVELOPED_HEIGHT: float = 0.2433
const FULLY_DEVELOPED_PERIOD: float = 8.134
## In shallow water the waves break when they get too high for the depth, so the
## significant height cannot grow past about 0.6 of the depth (a common rule of thumb for
## depth-limited waves in coastal engineering; see the Coastal Engineering Manual, 2002,
## part II). The period is left as it is.
const DEPTH_LIMITED_HEIGHT_RATIO: float = 0.6
## A real wave breaks when its height is more than 1/7 of its length (Michell 1893), which
## is a Gerstner steepness k·A of pi/7 = 0.45. Two waves at most this steep still sum
## below 1, where the Gerstner crests would fold over (section 9.8).
const MAX_WAVE_STEEPNESS: float = PI / 7.0

## The second, shorter wave: 1.5 times the peak frequency (so 1/2.25 of the length in deep
## water). The JONSWAP spectrum (peak enhancement 3.3) has about 11 % of the peak's energy
## density there, which is 0.33 of its amplitude (the square root of the energy).
const SHORT_WAVE_FREQUENCY_RATIO: float = 1.5
const SHORT_WAVE_AMPLITUDE_RATIO: float = 0.33
## Wind waves do not all travel exactly downwind: they spread out around the wind
## direction, the shorter ones more than the peak (directional spreading, Mitsuyasu et al.
## 1975). The peak wave goes straight downwind (plus the set's chop offset), the shorter one
## 30 degrees to the right of it, so the crests cross.
const SHORT_WAVE_OFFSET_DEG: float = 30.0
## The wave set's shortest wave (GerstnerWaveConfig, section 9.14).
const MIN_WAVELENGTH_M: float = 0.5


## Significant wave height (the mean of the highest third of the waves), m. depth_m is
## DEEP_WATER for no depth limit.
static func significant_height_m(wind_speed_ms: float, fetch_m: float, depth_m: float = DEEP_WATER) -> float:
	if wind_speed_ms <= 0.0 or fetch_m <= 0.0:
		return 0.0
	var u_squared_over_g: float = wind_speed_ms * wind_speed_ms / G
	var fetch_number: float = fetch_m / u_squared_over_g  # g·F / U², no unit
	var height_m: float = HEIGHT_COEFFICIENT * sqrt(fetch_number) * u_squared_over_g
	height_m = minf(height_m, FULLY_DEVELOPED_HEIGHT * u_squared_over_g)
	if not is_inf(depth_m):
		height_m = minf(height_m, DEPTH_LIMITED_HEIGHT_RATIO * depth_m)
	return height_m


## Peak period (the period of the waves that carry the most energy), s.
static func peak_period_s(wind_speed_ms: float, fetch_m: float) -> float:
	if wind_speed_ms <= 0.0 or fetch_m <= 0.0:
		return 0.0
	var fetch_number: float = G * fetch_m / (wind_speed_ms * wind_speed_ms)
	var period_s: float = PERIOD_COEFFICIENT * pow(fetch_number, 1.0 / 3.0) * wind_speed_ms / G
	return minf(period_s, FULLY_DEVELOPED_PERIOD * wind_speed_ms / G)


## The length of a wave with this period, m. In deep water L = g·T² / 2π. In water of
## depth d the dispersion relation is ω² = g·k·tanh(k·d) (any text on water waves, e.g.
## Dean & Dalrymple 1991): the wave feels the bottom, slows down and gets shorter. That
## equation has no closed solution for k, so it is solved by Newton's method, starting
## from Eckart's (1952) approximation k ≈ ω² / (g·sqrt(tanh(ω²·d / g))).
static func wavelength_m(period_s: float, depth_m: float = DEEP_WATER) -> float:
	if period_s <= 0.0:
		return 0.0
	var omega: float = TAU / period_s
	if is_inf(depth_m):
		return G * period_s * period_s / TAU
	var k: float = omega * omega / (G * sqrt(tanh(omega * omega * depth_m / G)))
	for i: int in 20:
		# f(k) = g·k·tanh(k·d) - ω², and its slope f'(k) = g·tanh(k·d) + g·k·d / cosh²(k·d).
		var tanh_kd: float = tanh(k * depth_m)
		var cosh_kd: float = cosh(k * depth_m)
		var error: float = G * k * tanh_kd - omega * omega
		var slope: float = G * tanh_kd + G * k * depth_m / (cosh_kd * cosh_kd)
		var step: float = error / slope
		k -= step
		if absf(step) < 1e-9 * k:
			break
	return TAU / k


## The chop for the wave set: the peak wave and one shorter wave, both in the chop group
## (so they follow the wind), as new GerstnerWaveConfig resources. Empty without wind or
## fetch. Amplitudes: a regular wave of height Hs (amplitude Hs/2) is the usual stand-in
## for a sea of significant height Hs; its energy is split over the two waves, so
## a_peak² + a_short² = (Hs/2)². Each steepness is the physical one, k·A, capped at the
## breaking limit.
static func chop_waves(wind_speed_ms: float, fetch_m: float, depth_m: float = DEEP_WATER) -> Array[GerstnerWaveConfig]:
	var waves: Array[GerstnerWaveConfig] = []
	var height_m: float = significant_height_m(wind_speed_ms, fetch_m, depth_m)
	var period_s: float = peak_period_s(wind_speed_ms, fetch_m)
	if height_m <= 0.0 or period_s <= 0.0:
		return waves
	var ratio: float = SHORT_WAVE_AMPLITUDE_RATIO
	var peak_amplitude_m: float = 0.5 * height_m / sqrt(1.0 + ratio * ratio)
	var peak_length_m: float = wavelength_m(period_s, depth_m)
	var short_length_m: float = wavelength_m(period_s / SHORT_WAVE_FREQUENCY_RATIO, depth_m)
	waves.append(_chop_wave(peak_length_m, peak_amplitude_m, 0.0))
	waves.append(_chop_wave(short_length_m, peak_amplitude_m * ratio, SHORT_WAVE_OFFSET_DEG))
	return waves


## One wave of the chop group with the physical steepness k·A (capped).
static func _chop_wave(length_m: float, amplitude_m: float, offset_deg: float) -> GerstnerWaveConfig:
	var wave: GerstnerWaveConfig = GerstnerWaveConfig.new()
	wave.group = GerstnerWaveConfig.Group.CHOP
	wave.direction_offset_deg = offset_deg
	wave.wavelength_m = maxf(length_m, MIN_WAVELENGTH_M)
	wave.amplitude_m = amplitude_m
	wave.steepness = minf(wave.physical_steepness(), MAX_WAVE_STEEPNESS)
	return wave
