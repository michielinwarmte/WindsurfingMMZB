// A lake's look in the wind (GR, 6 November 2026): the wind's strength on the water, the short wind
// waves and the whitecaps, for water.gdshader's lake path (lake_waves_on). Shading only: nothing here
// moves the surface, so the board floats exactly as before (PHYSICS_SPEC.md 9.17). The formulas are in
// GDScript too (res://world/lake_look.gd), where the tests check them.
//
// How a sailor reads the wind on the water: a gust is a darker, rougher patch coming down the lake, a
// lull or the lee along a shore a smoother, lighter one. What makes the difference is the shortest
// waves, from a few millimetres to a few decimetres: they hold most of the surface's slope, they tilt
// the mirror away from the bright horizon sky, and they follow the wind within a second or two (the
// wave research, 1.5). So:
//
// 1. How rough the water is: Cox and Munk (1954) measured the mean square slope of the sea from
//    photographs of the sun's glitter: mss = 0.003 + 0.00512 U, with U the wind in m/s at 12.5 m
//    (Mobley, Ocean Optics Web Book, "Cox-Munk sea surface slope statistics", eq. 4). Here U is the wind
//    of this moment at this place: the lake's mean (lake_wind_ms) times the gust picture's ratio (the
//    map's wind with its pattern, gusts, lulls and lee), so a gust is rougher at once and the lee
//    smoother.
// 2. The short waves the lake's trains leave out (shorter than the 0.5 m look train): that mss minus
//    what the trains already hold, split equally over SHORT_OCTAVES octaves from 0.35 m down to about
//    2 cm (Phillips' saturation range has the same slope in every octave; that it ends near 1.7 cm, the
//    slowest ripple, below which the water's viscosity damps them, is an estimate). The first two
//    octaves (0.25 and 0.125 m) are drawn as waves where a pixel is small enough for them; the rest, and
//    what the pixels cannot show, roughens the mirror (a third drawn octave, 6 cm, cost a third of a
//    millisecond a frame at 3137 x 1263 for a glitter only the nearest metres show).
// 3. Short-crested: every train the picture draws as shading, and every short octave, is split into
//    parts turned around the wind by Donelan-Banner spreading (Donelan, Hamilton and Hui 1985, with
//    Banner's part above 1.6 times the peak frequency; Horvath 2015, eq. 38): the parts sit at equal
//    shares of that spread (its quantiles), so short waves fan out wide and waves near the peak stay
//    close to the wind. The peak frequency is the lake's typical one, fixed, so the parts' directions
//    are the same everywhere and nothing jumps. The parts never change during a run, so LakeLook works
//    them out once (directions, lengths, frequencies: lake_spread_parts, lake_short_parts) and the
//    graphics card only adds them up.
// 4. Whitecaps: a crest breaks where the surface would fold, where the waves' sideways movement squeezes
//    it most (Tessendorf's Jacobian J < 0 is a fold; "Simulating Ocean Water", 2004). How much of the
//    water is white comes from Zhao and Toba (2001): W = 3.88e-5 R_B^1.09 %, with the breaking-wave
//    parameter R_B = u*^2 / (nu omega_p) (u*^2 = C_D U10^2, C_D = 0.0008 + 0.000065 U10 after Wu; as NOAA's
//    PyGnome codes it, zhao_toba.py), and waves start to break from R_B = 1000 (Toba and Koga 1986, as
//    Zhao and Toba cite it). The peak frequency omega_p is the lake's own at that place (its fetch-limited
//    sea, LakeWaves), so the young, short waves near the upwind shore break later than the longer ones
//    downwind. With the waves of the map's 18 kt: whitecaps start at about 15 kt at the camping beach (peak
//    period 1.5 s), 16 kt in the lake's middle (1.2 s), 17.5 kt 500 m from Sils (1.0 s) and 22 kt 100 m
//    from Sils (0.6 s); in 18 kt they cover 0.06 to 0.13 % of the water, in a gust 20 % stronger 1.6 to 2
//    times as much, in a lull of 20 % almost none (lake_wind_shading.md). An ocean law
//    (Callaghan et al. 2008: W = 3.18e-3 (U10 - 3.70)^3 %, from 7.2 kt) would give 0.55 % everywhere: the
//    open sea's older, longer waves. The whitecaps are where the squeeze is above the value that just that
//    share of the water reaches (lake_whitecap()). Only the trains (0.4 m and longer) break with foam here;
//    the short ripples do not.

// The lake's mean wind of the moment, at 10 m (the whitecaps' law) and at 12.5 m (Cox and Munk's), m/s.
uniform vec2 lake_wind_ms = vec2(0.0);
// The parts (LakeLook.shader_parameters()), each (direction x, direction z, wavelength m, frequency Hz):
// SPREAD_PARTS for each of the lake's four trains and then the look train, and SHORT_PARTS for each
// drawn short octave, longest first. A wavelength of 0 is an empty part.
uniform vec4 lake_spread_parts[25];
uniform vec4 lake_short_parts[8];
// The short waves on or off (to compare, and to measure their cost).
uniform bool lake_short_waves_on = true;
// How white a whitecap is (fresh foam covers most of the water under it), and its soft edge, in the
// crest steepness's spread.
uniform float whitecap_opacity : hint_range(0.0, 1.0) = 0.85;
uniform float whitecap_edge = 0.2;
// Real short waves and whitecaps are not straight: a short wave's crests are bent by up to this share of
// its wavelength by a noise twice its wavelength across (lake_short_bent()), so a crest runs for a
// wavelength or two, as short wind waves do (long straight ones showed as streaks toward the horizon), and
// the whitecaps' edges are frayed by this much of the squeeze's spread (lake_whitecap_fray()). Both a
// choice for the look.
uniform float lake_short_bend = 0.35;
uniform float whitecap_fray = 2.0;

// How a gust looks (water.gdshader's gust_darkening and gust_glassiness, GR2): the gust is how much
// rougher the water is here than the lake's mean by Cox and Munk (lake_gust_signal()), times this
// (7: a gust 10 % stronger than the mean, 9 % rougher, is two thirds of a full gust, as GR2's look had
// it), and a full gust's mirror is this much rougher (a lull's smoother): at a glancing view only a
// rougher mirror shows a gust darker (0.15 chosen by eye: the patches read from the follow camera and
// from high up without turning into blots).
uniform float lake_gust_contrast = 7.0;
uniform float lake_gust_roughness : hint_range(0.0, 0.5) = 0.15;

// The short waves' octaves below the look train (0.35 m down to about 2 cm), and how many are drawn.
const float SHORT_OCTAVES = 4.0;
const int SHORT_DRAWN = 2;
const float SHORT_LONGEST_M = 0.25;
// The parts of a short octave: four (their lengths within the octave are LakeLook's), each with its own
// phase, so no two parts line up; the longest is 1.12 times the octave.
const int SHORT_PARTS = 4;
const float SHORT_LONGEST_PART = 1.12;
const float SHORT_PHASES[4] = float[](0.37, 0.81, 0.13, 0.59);
// The parts of a train drawn as shading: five, the same way.
const int SPREAD_PARTS = 5;
const float SPREAD_PHASES[5] = float[](0.0, 0.38, 0.78, 0.21, 0.59);

// Two smooth random values from -1 to 1 on a grid of cells of size 1 (value noise with a 32-bit hash, the
// same hash as wind_pattern.gdshaderinc's, its two halves for the two values; it stays exact kilometres
// from the origin).
vec2 look_hash(ivec2 cell) {
	uint h = uint(cell.x) * 0x8da6b343u ^ uint(cell.y) * 0xd8163841u;
	h ^= h >> 16u;
	h *= 0x7feb352du;
	h ^= h >> 15u;
	h *= 0x846ca68bu;
	h ^= h >> 16u;
	return vec2(float(h & 0xffffu), float(h >> 16u)) / 65535.0 * 2.0 - 1.0;
}

vec2 look_noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = p - cell;
	vec2 u = f * f * (3.0 - 2.0 * f);
	ivec2 c = ivec2(cell);
	return mix(mix(look_hash(c), look_hash(c + ivec2(1, 0)), u.x), mix(look_hash(c + ivec2(0, 1)), look_hash(c + ivec2(1, 1)), u.x), u.y);
}

// How far the crests of a short wave of `length_m` are bent at a rest point (see lake_short_bend).
vec2 lake_short_bent(vec2 rest, float length_m) {
	return look_noise(rest / (2.0 * length_m)) * lake_short_bend * length_m;
}

// A whitecap's fraying at a rest point (-1 to 1): a noise 0.6 m across and a finer one 0.2 m across, the
// finer faded where a pixel is too big for it (it would sparkle).
float lake_whitecap_fray(vec2 rest, float pixel_m) {
	float fine = look_noise(rest / 0.2 + vec2(3.7, 1.1)).x * (1.0 - smoothstep(0.03, 0.1, pixel_m));
	return 0.6 * look_noise(rest / 0.6).x + 0.4 * fine;
}

// Cox and Munk's mean square slope of a clean sea for a wind (m/s at 12.5 m).
float cox_munk_mss(float wind_12m_ms) {
	return 0.003 + 0.00512 * max(wind_12m_ms, 0.0);
}

// A wave's phase at a rest point, in cycles reduced to 0..1 before the sine (the lake is kilometres wide:
// a full phase in radians would be too big for the graphics card's sine).
float wave_cycles(vec2 direction, float length_m, float frequency_hz, float phase_cycles, vec2 rest) {
	return fract(dot(direction, rest) / length_m - frequency_hz * water_time_s + phase_cycles);
}

// How much of a wave a pixel of `pixel_m` shows: all of it from 6 pixels a wavelength, none below 3.
float wave_shown(float length_m, float pixel_m) {
	return 1.0 - smoothstep(length_m / 6.0, length_m / 3.0, pixel_m);
}

// One wave of the picture, `part` as lake_spread_parts' (direction, wavelength, frequency): adds its slope
// to the tangents, what the pixel cannot show to `faded_slope2`, and, if it breaks (`breaks`), its
// sideways squeeze (steepness x sin(phase), the Jacobian's first-order part, as gerstner_lake()'s crest)
// to breaking.x, the squeeze's variance to breaking.y and its steepness^4 to breaking.z.
void lake_look_wave(vec4 part, float steepness, float phase_cycles, float pixel_m, vec2 rest, bool breaks, inout vec3 tangent_x, inout vec3 tangent_z, inout float faded_slope2, inout vec3 breaking) {
	vec2 direction = part.xy;
	float length_m = part.z;
	if (pixel_m >= length_m / 3.0) {
		// Too small for the pixel (most of the far water): all of it roughens the mirror, nothing else.
		faded_slope2 += 0.5 * steepness * steepness;
		return;
	}
	float phase = 2.0 * PI * wave_cycles(direction, length_m, part.w, phase_cycles, rest);
	float shown = wave_shown(length_m, pixel_m);
	float slope = steepness * shown;
	tangent_x.y += slope * cos(phase) * direction.x;
	tangent_z.y += slope * cos(phase) * direction.y;
	faded_slope2 += 0.5 * (1.0 - shown * shown) * steepness * steepness;
	if (breaks) {
		breaking += vec3(slope * sin(phase), 0.5 * slope * slope, slope * slope * slope * slope);
	}
}

// Train `train` (0 to 3 the lake's trains, 4 the look train) drawn as shading (away from the board), as
// its SPREAD_PARTS short-crested parts, which share its energy. `phase` is the train's phase (radians,
// gerstner_lake()'s wave.z).
void lake_spread_train(int train, float phase, float amplitude, float pixel_m, vec2 rest, inout vec3 tangent_x, inout vec3 tangent_z, inout float faded_slope2, inout vec3 breaking) {
	if (amplitude <= 0.0) {
		return;
	}
	float part_a = amplitude * inversesqrt(float(SPREAD_PARTS));
	for (int j = 0; j < SPREAD_PARTS; j++) {
		vec4 part = lake_spread_parts[train * SPREAD_PARTS + j];
		if (part.z <= 0.0) {
			continue;
		}
		float steepness = min(part_a * 2.0 * PI / part.z, PI / 7.0);
		lake_look_wave(part, steepness, phase / (2.0 * PI) + SPREAD_PHASES[j], pixel_m, rest, true, tangent_x, tangent_z, faded_slope2, breaking);
	}
}

// The short waves' mean square slope for the wind here (m/s at 12.5 m), less what the lake's trains
// already hold (`trains_mss`): never below zero.
float lake_short_mss(float wind_12m_ms, float trains_mss) {
	return max(cox_munk_mss(wind_12m_ms) - trains_mss, 0.0);
}

// The short waves at a pixel (see 2 and 3 above): the drawn octaves as waves, the rest of `short_mss` to
// `faded_slope2`.
void lake_short_waves(vec2 rest, float pixel_m, float short_mss, inout vec3 tangent_x, inout vec3 tangent_z, inout float faded_slope2) {
	float per_octave = short_mss / SHORT_OCTAVES;
	faded_slope2 += per_octave * (SHORT_OCTAVES - float(SHORT_DRAWN));
	if (!lake_short_waves_on) {
		faded_slope2 += per_octave * float(SHORT_DRAWN);
		return;
	}
	// Each part holds a quarter of its octave's slope: 0.5 s^2 = per_octave / SHORT_PARTS.
	float steepness = sqrt(2.0 * per_octave / float(SHORT_PARTS));
	vec3 no_breaking = vec3(0.0);
	float band_m = SHORT_LONGEST_M;
	for (int band = 0; band < SHORT_DRAWN; band++) {
		if (pixel_m >= band_m * SHORT_LONGEST_PART / 3.0) {
			// The whole octave is too small for the pixel: it roughens the mirror (the octaves get
			// shorter, so the rest do too).
			faded_slope2 += per_octave * float(SHORT_DRAWN - band);
			break;
		}
		vec2 bent = rest + lake_short_bent(rest, band_m);
		for (int j = 0; j < SHORT_PARTS; j++) {
			float phase = SHORT_PHASES[j] + 0.29 * float(band);
			lake_look_wave(lake_short_parts[band * SHORT_PARTS + j], steepness, phase, pixel_m, bent, false, tangent_x, tangent_z, faded_slope2, no_breaking);
		}
		band_m *= 0.5;
	}
}

// How much rougher the water is where the wind is `wind_ratio` times the lake's mean than at the mean
// (Cox and Munk's mss, relative): about the wind's own ratio less one.
float lake_gust_signal(float wind_ratio) {
	if (lake_wind_ms.y <= 0.0) {
		return 0.0;
	}
	return cox_munk_mss(lake_wind_ms.y * wind_ratio) / cox_munk_mss(lake_wind_ms.y) - 1.0;
}

// The kinematic viscosity of the lake's air, m^2/s: 1.76e-5 Pa s at about 10 degrees C over the lake's
// 0.98 kg/m^3 (environment_silvaplana.tres): thinner air than at sea (1.5e-5), so R_B is smaller.
const float AIR_VISCOSITY = 1.8e-5;

// Zhao and Toba (2001): the share of the water covered by whitecaps (0 to 1) in a wind of U10 m/s over
// waves whose peak period is `peak_period_s` (none from a breaking-wave parameter below about 1000).
float whitecap_fraction(float wind_10m_ms, float peak_period_s) {
	if (wind_10m_ms <= 0.0 || peak_period_s <= 0.0) {
		return 0.0;
	}
	float drag = 0.0008 + 0.000065 * wind_10m_ms;
	float breaking_parameter = drag * wind_10m_ms * wind_10m_ms / (AIR_VISCOSITY * 2.0 * PI / peak_period_s);
	float percent = 3.88e-5 * pow(breaking_parameter, 1.09) * smoothstep(800.0, 1200.0, breaking_parameter);
	return min(percent / 100.0, 0.2);
}

// The value a Gaussian with spread 1 exceeds with probability p (0 < p <= 0.5): Abramowitz and Stegun
// 26.2.23, accurate to 4.5e-4.
float gaussian_exceeded(float p) {
	float t = sqrt(-2.0 * log(p));
	return t - (2.515517 + 0.802853 * t + 0.010328 * t * t) / (1.0 + 1.432788 * t + 0.189269 * t * t + 0.001308 * t * t * t);
}

// The same for a sum of sine waves, whose tails are a little shorter than a Gaussian's: the Cornish-Fisher
// correction for its excess kurtosis (a sine wave of steepness s adds -3/8 s^4 to the fourth cumulant;
// `variance` is the sum's, `fourth` the sum of s^4).
float sines_exceeded(float p, float variance, float fourth) {
	float z = gaussian_exceeded(p);
	float kurtosis = -0.375 * fourth / max(variance * variance, 1e-12);
	return z + (z * z * z - 3.0 * z) * kurtosis / 24.0;
}

// The spread of lake_whitecap_fray()'s noise (measured: 0.31 for its mix of two value noises).
const float FRAY_SPREAD = 0.31;

// How much of a pixel is whitecap: where the breaking waves squeeze the surface most (`breaking`, the
// sums of lake_look_wave()), as much of the water as `fraction`. The squeeze is the Jacobian's first-order
// part, 1 - J to first order (Tessendorf 2004): a sum of sine waves, so the share above its spread x
// sines_exceeded(fraction) is `fraction` (checked numerically for the lake's trains at the start spot:
// 0.049, 0.089, 0.19, 0.50 and 0.99 % of the water for 0.05, 0.1, 0.2, 0.5 and 1 %; a plain Gaussian
// gave a third too few at 0.1 %). The full J folds less where the waves cross at angles (half as many
// at 0.5 %), so it is not used. `fray` (-1 to 1, a noise) moves the edge so a whitecap is ragged,
// not a smooth oval; the threshold allows for its spread, so the share stays the same. The noise is only
// worked out near a crest that can whiten (most of the water is far below the threshold): `fray` gets it
// (0 elsewhere), for the foam's froth. `full_variance` is the squeeze's variance if every breaking wave
// were drawn: the share the pixel cannot draw is foam spread evenly (the far water's faint whitening in a
// strong wind).
float lake_whitecap(vec3 breaking, float full_variance, float fraction, vec2 rest, float pixel_m, out float fray) {
	fray = 0.0;
	if (fraction <= 0.0 || full_variance <= 0.0) {
		return 0.0;
	}
	float squeeze = breaking.x;
	float spread = sqrt(breaking.y);
	float frayed = whitecap_fray * spread;
	float variance = spread * spread + frayed * frayed * FRAY_SPREAD * FRAY_SPREAD;
	float threshold = sqrt(variance) * sines_exceeded(fraction, variance, breaking.z);
	float edge = whitecap_edge * spread;
	float drawn = clamp(breaking.y / full_variance, 0.0, 1.0);
	float cap = 0.0;
	if (squeeze + frayed > threshold - edge) {
		fray = lake_whitecap_fray(rest, pixel_m);
		cap = smoothstep(threshold - edge, threshold + edge, squeeze + fray * frayed);
	}
	return drawn * cap + (1.0 - drawn) * fraction;
}
