class_name LakeWaves
extends RefCounted
## A lake's waves, grown by its wind over its fetch (PHYSICS_SPEC.md 9.17; PH44; the research,
## Documentation/reports/waves/wave_system_research.md section 1). Built once for the lake's mean
## wind of the moment (its direction and its speed) and then never changed: LakeWaveField (the
## physics) and the water shader (the picture) both read it.
##
## The steps, at every node of a grid over the lake (FetchMap):
##   1. the fetch: the open water upwind, the SPM's nine rays 6 degrees apart, cosine-weighted;
##   2. the wind along the fetch: the lake's mean wind at 10 m times the local wind's mean along
##      the rays (the map's pattern and the lee under the shore, not the gusts);
##   3. the significant height Hs and the peak period Tp from the fetch law (SPM 1984, or CEM 2002
##      as a switch), at most 0.6 of the depth in the shallows;
##   4. the JONSWAP spectrum with that Hs and Tp (peak enhancement 3.3), cut into octave bands
##      around a few fixed wavelengths: each band's share of the spectrum's energy gives the
##      amplitude of one Gerstner wave train of that length (a² / 2 = its energy).
## The trains keep one length, direction and phase over the whole lake, so their crests run on
## without a jump; only their heights change from node to node, slowly next to a wavelength (the
## nodes are 16 m apart, the longest train 8 m), as a Gerstner wave with a slowly changing envelope.
## Near the upwind shore the peak is shorter than every train, so the water there carries almost
## nothing but the picture's ripples; downwind the peak moves to the longer trains.

const G: float = 9.81
## A real wave breaks when it gets steeper than k·A = pi/7 (Michell 1893; WindWaves).
const MAX_STEEPNESS: float = PI / 7.0
## The JONSWAP spectrum's width around the peak (Hasselmann et al. 1973): 0.07 below the peak
## frequency, 0.09 above.
const SIGMA_BELOW: float = 0.07
const SIGMA_ABOVE: float = 0.09
## The table of the spectrum's shape (see _cumulative_shape()): steps of the frequency over the peak
## frequency, up to this; above it the shape's tail is s^-5 to within 0.01 %.
const SHAPE_STEP: float = 0.002
const SHAPE_END: float = 12.0
## The wind's push on a short wave: its energy grows at (0.04 ± 0.02) (u*/c)² ω (Plant 1982, as
## Polnikov's review quotes it; the research, wave_system_research.md 1.5).
const PLANT_GROWTH: float = 0.04
## How much more wind the look train's growth with the wind is measured at (a 10 % step).
const GROWTH_STEP: float = 1.1

var config: LakeWavesConfig
## The wind the waves were built for: where it comes from (degrees) and its speed at 10 m (m/s),
## the lake's mean.
var from_deg: float = 0.0
var wind_10m_ms: float = 0.0
## The grid, its nodes' fetch, wind and depth (FetchMap).
var map: FetchMap

## The lake's wave trains, longest first: length (m), wave number (rad/m), the unit direction it
## travels (x, z), and its phase at the origin at time 0 (rad). The physics floats on the first
## physics_count of them; the picture draws the others as shading only (LakeWavesConfig).
var band_count: int = 0
var physics_count: int = 0
var wavelength_m: PackedFloat64Array = PackedFloat64Array()
var wave_number: PackedFloat64Array = PackedFloat64Array()
var dir_x: PackedFloat64Array = PackedFloat64Array()
var dir_z: PackedFloat64Array = PackedFloat64Array()
var phase0: PackedFloat64Array = PackedFloat64Array()
## The picture's own shorter train (config.look_wavelength_m): direction (x, z) and phase.
var look_dir: Vector2 = Vector2(0.0, -1.0)
var look_phase0: float = 0.0

## Per node, row by row from the north: the trains' amplitudes (band_count values a node, in the
## trains' order), m.
var amplitudes: PackedFloat32Array = PackedFloat32Array()
## Per node, four values for the picture: the look train's amplitude (m), how much it grows with the
## wind there (d ln A / d ln U: the growth law and the spectrum at 10 % more wind), Hs (m) and Tp (s).
var look_data: PackedFloat32Array = PackedFloat32Array()
## How fast the look train answers a change of the wind, s: the e-folding time of its energy under
## the wind's push, 1 / (0.04 (u*/c)² ω) (Plant 1982, as Polnikov's review quotes it; u* from the
## CEM's drag, c and ω the train's in deep water; the research, 1.5), at the lake's mean wind. How
## fast it dies when the gust has passed is not measured: the same time is used (an estimate).
var look_response_s: float = 0.0
## The largest sum of the physics' trains' amplitudes anywhere: the highest crest possible.
var max_total_amplitude_m: float = 0.0

## The spectrum's shape added up from 0 (see _cumulative_shape()), shared by every lake.
static var _shape_table: PackedFloat64Array = PackedFloat64Array()
static var _shape_table_gamma: float = -1.0

## The picture's textures, made the first time the water asks (main thread only).
var _textures: Dictionary[String, Texture2D] = {}


## Builds a lake's waves. depth_at and speed_factor_at as in FetchMap.build(); area: where to look
## for the lake (game x, z of the north-west corner and the size). wind_from_deg and wind_10m_ms:
## the lake's mean wind.
static func build(lake_config: LakeWavesConfig, depth_at: Callable, area: Rect2, wind_from_deg: float, wind_ms: float,
		speed_factor_at: Callable) -> LakeWaves:
	var lake: LakeWaves = LakeWaves.new()
	lake.config = lake_config
	lake.from_deg = wind_from_deg
	lake.wind_10m_ms = wind_ms
	lake._set_up_bands()
	lake.map = FetchMap.build(depth_at, area, lake_config.cell_m, wind_from_deg, speed_factor_at,
		lake_config.ray_count, lake_config.ray_spacing_deg)
	lake._fill_nodes()
	lake.look_response_s = lake.look_response_time_s(wind_ms)
	return lake


## The trains' amplitudes at a game position, between the four nearest nodes (bilinear), into `out`
## (band_count values). 0 off the grid.
func amplitudes_at(x: float, z: float, out: PackedFloat64Array) -> void:
	out.resize(band_count)
	var fx: float = (x - map.x0_m) / map.cell_m
	var fz: float = (z - map.z0_m) / map.cell_m
	if fx < 0.0 or fz < 0.0 or fx >= map.columns - 1.0 or fz >= map.rows - 1.0:
		out.fill(0.0)
		return
	var column: int = int(fx)
	var row: int = int(fz)
	var tx: float = fx - column
	var tz: float = fz - row
	var north: int = (row * map.columns + column) * band_count
	var south: int = north + map.columns * band_count
	for i: int in band_count:
		var top: float = lerpf(amplitudes[north + i], amplitudes[north + band_count + i], tx)
		var bottom: float = lerpf(amplitudes[south + i], amplitudes[south + band_count + i], tx)
		out[i] = lerpf(top, bottom, tz)


## The significant height (m), the peak period (s) and the fetch (m) at a game position (bilinear;
## for the measurements).
func sea_at(x: float, z: float) -> Vector3:
	var values: Vector3 = Vector3(0.0, 0.0, map.value_at(map.fetch_m, x, z))
	for part: int in 2:
		values[part] = map.value_at(look_values(2 + part), x, z)
	return values


## One of the four look values of every node (0 the look train's amplitude, 1 its growth with the
## wind, 2 Hs, 3 Tp), as one array (for the measurements).
func look_values(which: int) -> PackedFloat32Array:
	var one: PackedFloat32Array = PackedFloat32Array()
	one.resize(map.columns * map.rows)
	for i: int in one.size():
		one[i] = look_data[4 * i + which]
	return one


## The look train's response time (see look_response_s) for a wind (m/s at 10 m).
func look_response_time_s(wind_ms: float) -> float:
	var k: float = TAU / config.look_wavelength_m
	var omega: float = sqrt(G * k)
	var c: float = omega / k
	var u_star: float = WindWaves.friction_velocity_ms(wind_ms)
	var rate: float = PLANT_GROWTH * (u_star / c) * (u_star / c) * omega
	return 1.0 / rate if rate > 0.0 else INF


## The growth law's significant height (m) and peak period (s) for a wind (m/s at 10 m) over a
## fetch (m), deep water.
func height_and_period(wind_ms: float, fetch_m: float) -> Vector2:
	if config.growth_law == LakeWavesConfig.GrowthLaw.CEM:
		return Vector2(WindWaves.significant_height_cem_m(wind_ms, fetch_m), WindWaves.peak_period_cem_s(wind_ms, fetch_m))
	return Vector2(WindWaves.significant_height_m(wind_ms, fetch_m), WindWaves.peak_period_s(wind_ms, fetch_m))


## The amplitude (m) of a train of length `length_m` (one octave of the spectrum around it) in a sea
## of significant height hs_m and peak period tp_s: the train's energy a² / 2 is its octave's share
## of the spectrum's energy m0 = (Hs / 4)².
static func band_amplitude_m(length_m: float, hs_m: float, tp_s: float, gamma: float = 3.3) -> float:
	if hs_m <= 0.0 or tp_s <= 0.0:
		return 0.0
	var share: float = band_share(length_m / sqrt(2.0), length_m * sqrt(2.0), tp_s, gamma)
	return hs_m * sqrt(share / 8.0)


## The share of a JONSWAP spectrum's energy between two wavelengths (deep water), for a peak period.
## The spectrum (Hasselmann et al. 1973; the three-parameter form of SINTEF's SIMA documentation):
##   S(ω) = α g² ω⁻⁵ exp(−1.25 (ωp/ω)⁴) γ^r,  r = exp(−(ω − ωp)² / (2 σ² ωp²))
## With s = ω / ωp the shape is s⁻⁵ exp(−1.25 s⁻⁴) γ^r(s) times a constant; the share is the shape
## added up over the band divided by the whole. The wavelengths become frequencies by deep water's
## ω² = g·k.
static func band_share(short_m: float, long_m: float, tp_s: float, gamma: float = 3.3) -> float:
	var peak: float = TAU / tp_s
	var low: float = sqrt(G * TAU / long_m) / peak
	var high: float = sqrt(G * TAU / short_m) / peak
	return (_shape_up_to(high, gamma) - _shape_up_to(low, gamma)) / _shape_up_to(INF, gamma)


# ---------------------------------------------------------------- building

func _set_up_bands() -> void:
	band_count = mini(config.wavelengths_m.size(), WaveSetConfig.MAX_WAVES)
	physics_count = clampi(config.physics_trains, 0, band_count)
	var downwind_deg: float = from_deg + 180.0
	for i: int in band_count:
		var length: float = maxf(config.wavelengths_m[i], WindWaves.MIN_WAVELENGTH_M)
		var offset: float = config.offsets_deg[i] if i < config.offsets_deg.size() else 0.0
		var direction: Vector2 = WaveField.direction_for_bearing(downwind_deg + offset)
		wavelength_m.append(length)
		wave_number.append(TAU / length)
		dir_x.append(direction.x)
		dir_z.append(direction.y)
		phase0.append(_phase_of(i))
	look_dir = WaveField.direction_for_bearing(downwind_deg + config.look_offset_deg)
	look_phase0 = _phase_of(band_count)


## A fixed phase for train i at the origin at time 0, spread over the circle by the golden ratio,
## so the trains' crests do not all meet at the lake's middle at the start. Any spread would do.
static func _phase_of(i: int) -> float:
	return TAU * fposmod(0.6180339887 * (i + 1), 1.0)


## Every node's waves (steps 2 to 4 of the top of this file).
func _fill_nodes() -> void:
	var nodes: int = map.columns * map.rows
	amplitudes.resize(nodes * band_count)
	amplitudes.fill(0.0)
	look_data.resize(nodes * 4)
	look_data.fill(0.0)
	max_total_amplitude_m = 0.0
	for i: int in nodes:
		var depth: float = map.depth_m[i]
		if depth <= 0.0:
			continue
		var fetch: float = map.fetch_m[i]
		var sea: Vector2 = height_and_period(wind_10m_ms * map.wind_factor[i], fetch)
		var hs: float = sea.x
		var tp: float = sea.y
		# Shallow water: the waves break until Hs is at most this share of the depth (all trains
		# lowered alike).
		var depth_factor: float = 1.0
		if hs > 0.0:
			depth_factor = minf(1.0, config.depth_limited_height_ratio * depth / hs)
		var scale: float = depth_factor * config.height_scale
		var total: float = 0.0
		for band: int in band_count:
			var amplitude: float = band_amplitude_m(wavelength_m[band], hs, tp, config.peak_enhancement) * scale
			amplitudes[i * band_count + band] = amplitude
			if band < physics_count:
				total += amplitude
		max_total_amplitude_m = maxf(max_total_amplitude_m, total)
		var look: float = band_amplitude_m(config.look_wavelength_m, hs, tp, config.peak_enhancement) * scale
		look_data[4 * i] = look
		look_data[4 * i + 1] = _look_growth(look, wind_10m_ms * map.wind_factor[i], fetch, depth)
		look_data[4 * i + 2] = hs * scale
		look_data[4 * i + 3] = tp


## How much the look train grows with the wind at a node: d ln A / d ln U, from the same growth law
## and spectrum at 10 % more wind (0 where there is none).
func _look_growth(look_m: float, wind_ms: float, fetch_m: float, depth_m: float) -> float:
	if look_m <= 0.0:
		return 0.0
	var more: Vector2 = height_and_period(wind_ms * GROWTH_STEP, fetch_m)
	var depth_factor: float = minf(1.0, config.depth_limited_height_ratio * depth_m / more.x) if more.x > 0.0 else 1.0
	var look_more: float = band_amplitude_m(config.look_wavelength_m, more.x, more.y, config.peak_enhancement) * depth_factor * config.height_scale
	if look_more <= 0.0:
		return 0.0
	return log(look_more / look_m) / log(GROWTH_STEP)


# ---------------------------------------------------------------- the spectrum's shape

## The JONSWAP shape s⁻⁵ exp(−1.25 s⁻⁴) γ^r(s) added up from s = 0 to s (s = ω / ωp), from a table
## made once (steps of 0.002, the trapezium rule), with the s⁻⁵ tail added in closed form above its
## end: the sum from s to infinity of s⁻⁵ is 1 / (4 s⁴).
static func _shape_up_to(s: float, gamma: float) -> float:
	if _shape_table.is_empty() or _shape_table_gamma != gamma:
		_make_shape_table(gamma)
	var last: int = _shape_table.size() - 1
	var tail_from_end: float = 1.0 / (4.0 * pow(SHAPE_END, 4.0))
	if is_inf(s):
		return _shape_table[last] + tail_from_end
	if s >= SHAPE_END:
		return _shape_table[last] + tail_from_end - 1.0 / (4.0 * pow(s, 4.0))
	if s <= 0.0:
		return 0.0
	var f: float = s / SHAPE_STEP
	var i: int = mini(int(f), last - 1)
	return lerpf(_shape_table[i], _shape_table[i + 1], f - i)


static func _make_shape_table(gamma: float) -> void:
	var steps: int = int(round(SHAPE_END / SHAPE_STEP))
	var table: PackedFloat64Array = PackedFloat64Array()
	table.resize(steps + 1)
	table[0] = 0.0
	var before: float = 0.0
	for i: int in range(1, steps + 1):
		var now: float = _shape(i * SHAPE_STEP, gamma)
		table[i] = table[i - 1] + 0.5 * (before + now) * SHAPE_STEP
		before = now
	_shape_table = table
	_shape_table_gamma = gamma


## The JONSWAP shape at s = ω / ωp.
static func _shape(s: float, gamma: float) -> float:
	if s < 0.2:
		return 0.0  # exp(-1.25 / 0.0016) = 0 to every digit a double has
	var sigma: float = SIGMA_BELOW if s <= 1.0 else SIGMA_ABOVE
	var r: float = exp(-(s - 1.0) * (s - 1.0) / (2.0 * sigma * sigma))
	return pow(s, -5.0) * exp(-1.25 * pow(s, -4.0)) * pow(gamma, r)


# ---------------------------------------------------------------- for the picture

## The physics trains' amplitudes as a picture, one pixel per node (RGBA = the first four trains),
## and the look data (R the look train, G its growth with the wind, B Hs, A Tp): the water shader reads both with
## texelFetch, at exactly the nodes the physics reads. Made once, on the main thread.
func textures() -> Dictionary[String, Texture2D]:
	if _textures.is_empty():
		var four: PackedFloat32Array = PackedFloat32Array()
		var nodes: int = map.columns * map.rows
		four.resize(nodes * 4)
		four.fill(0.0)
		for i: int in nodes:
			for band: int in mini(band_count, 4):
				four[4 * i + band] = amplitudes[i * band_count + band]
		_textures["lake_envelope"] = _texture_of(four)
		_textures["lake_look_data"] = _texture_of(look_data)
	return _textures


func _texture_of(values: PackedFloat32Array) -> ImageTexture:
	var image: Image = Image.create_from_data(map.columns, map.rows, false, Image.FORMAT_RGBAF, values.to_byte_array())
	return ImageTexture.create_from_image(image)
