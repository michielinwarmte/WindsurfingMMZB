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
// The fraying noise's size: 1 is 0.6 m and 0.2 m across (the lake's short waves); the open sea's longer
// waves need bigger rags (sea_water.tres). A choice for the look.
uniform float whitecap_fray_scale = 1.0;

// ------------------------------------------------------------------------------------------------------
// The wind's strength on the water (GR, 6 November 2026, Documentation/reports/waves/wind_on_water.md;
// Max: "Make the windstrength visable to the player ... No white stripes, but effects that happen in real
// life high winds too"). What a sailor reads, from the Beaufort scale's sea states (force 3, 7 to 10 kt:
// "perhaps scattered white horses"; force 4, 11 to 16: "fairly frequent white horses"; force 5, 17 to 21:
// "many white horses"; force 6, 22 to 27: "white foam crests more extensive everywhere, probably some
// spray"; force 7, 28 to 33: foam "blown in streaks", US National Weather Service's Beaufort table):
// 5. Whitecaps by a measured law (whitecap_cover()): how much of the water is white rises with about the
//    wind's cube (Callaghan, de Leeuw, Cohen and O'Dowd 2008, GRL 35, L23609, the open sea: 0.05 % at
//    12 kt, 0.6 % at 18, 1.4 % at 24, 2.5 % at 30), or by Zhao and Toba 2001 from the lake's own young
//    waves (above), or Monahan and O'Muircheartaigh 1980. The measured cover counts the fresh, bright foam
//    of a breaking crest (stage A) and the thinner foam it leaves behind (stage B), which lasts seconds.
// 6. The foam left behind: a whitecap's crest moves on and its foam stays, drifting downwind with the
//    surface (foam_drift_ms, a few % of the wind) and fading (half-life of seconds). Drawn without any
//    memory: the foam here now is where a crest broke a moment ago, so the shader asks whether the
//    breaking waves squeezed this water (where it was then, upwind by the drift) above the threshold at 8
//    earlier moments, foam_lag_s apart; each earlier whitecap is drawn fainter (exp(-age / foam_life_s)),
//    a little bigger (foam spreads) and lacy. Fresh water's foam goes about a third faster than sea water's
//    (2.54 against 3.85 s, Monahan and Zietlow 1969, as Wu 2000 gives it), so the lake's lasts less and,
//    as the sea's laws count the lasting foam, the lake's cover is that much smaller (whitecap_water_factor,
//    an estimate: cover in proportion to the foam's life).
// 7. Wind rows: from about 3 m/s the wind turns the top metres into long rolls along it (Langmuir
//    circulation; Leibovich 1983, Thorpe 2004: rows 2 to 300 m apart, longer than wide), whose lanes are
//    rougher or smoother: a faint pattern of darker lanes along the wind in the short waves' roughness, not
//    white lines (wind_rows()).
// Which whitecap law: 0 Zhao and Toba 2001 with the lake's own waves (lake_wind_shading.md), 1 Callaghan et
// al. 2008 (open sea; on the lake times whitecap_water_factor and none where the lake's waves are too young
// to break), 2 Monahan and O'Muircheartaigh 1980, W = 3.84e-4 U10^3.41 % (open sea).
uniform int whitecap_law = 1;
// The sea laws on fresh water: their cover times this (the lake: 0.66 = 2.54 / 3.85 s, an estimate).
uniform float whitecap_water_factor = 1.0;
// Young waves (the lake's own, near its upwind shore) break only above this breaking-wave parameter, fully
// from 1000 (Toba and Koga 1986's onset, as Zhao and Toba cite it; the softening from 500 an estimate).
uniform float whitecap_young_onset = 500.0;
// The share of the measured cover that is fresh, breaking foam on the crests (stage A): an estimate within
// the measured range (stage B, the foam left behind, covers 1.5 to 40 times stage A's area).
uniform float whitecap_active_share = 0.35;
// The foam left behind: its e-folding life (s: fresh water 2.54, the sea 3.85), the time between the 8
// earlier moments looked at (s), how fast it spreads (in the squeeze's spread a second, by eye), and how
// lacy it is (0 a sheet, 1 full of holes, by eye).
uniform float foam_life_s = 3.85;
uniform float foam_lag_s = 0.45;
uniform float foam_spread_per_s = 0.05;
uniform float foam_lace = 0.6;
// How white the foam left behind is at most: thinner than a breaking crest's (stage B foam is a thin layer
// of bubbles, greyer than stage A's; by eye).
uniform float foam_left_opacity = 0.55;
// The surface's drift (and the foam's), m/s (x east, y south), and how far it has drifted since the run
// began (m): OceanNode adds it up every frame, so the foam and the rows move smoothly downwind.
uniform vec2 foam_drift_ms = vec2(0.0);
uniform vec2 foam_offset_m = vec2(0.0);
// Wind rows: the direction they lie along (the mean wind's downwind direction, fixed for the run, so the
// pattern never swings), how strongly they change the short waves' roughness (+/- share, by eye), their
// size along and across the wind (m: an estimate within Thorpe's 2 to 300 m), and the wind (m/s at 10 m)
// from which they form (Leibovich: about 3 m/s) and at which they are full (an estimate).
uniform vec2 wind_rows_along = vec2(1.0, 0.0);
uniform float wind_rows_strength = 0.5;
uniform vec2 wind_rows_cell_m = vec2(90.0, 14.0);
uniform vec2 wind_rows_wind_ms = vec2(3.0, 12.0);

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

// A whitecap's fraying at a rest point (-1 to 1): a noise 0.6 m across and a finer one 0.2 m across (times
// whitecap_fray_scale), the finer faded where a pixel is too big for it (it would sparkle). y: a second
// noise of the same sizes, for the lace of the foam left behind.
vec2 lake_whitecap_fray(vec2 rest, float pixel_m) {
	float scale = whitecap_fray_scale;
	vec2 fine = look_noise(rest / (0.2 * scale) + vec2(3.7, 1.1)) * (1.0 - smoothstep(0.03 * scale, 0.1 * scale, pixel_m));
	return 0.6 * look_noise(rest / (0.6 * scale)) + 0.4 * fine;
}

// A complex number turned by another (both as (cos, sin)).
vec2 turned(vec2 z, vec2 turn) {
	return vec2(z.x * turn.x - z.y * turn.y, z.y * turn.x + z.x * turn.y);
}

// One breaking wave's squeeze at the 8 earlier moments (6. above): the foam here now was, foam_lag_s x n
// earlier, upwind by the drift (rest - u tau), where this wave's phase was its phase now plus
// (omega - k d.u) tau: `rate`, radians a second. `cos_sin` is the phase now; one sine and cosine a wave,
// then complex products. lag_a holds moments 1 to 4, lag_b 5 to 8.
void foam_lags_add(float slope, vec2 cos_sin, float rate, inout vec4 lag_a, inout vec4 lag_b) {
	float angle = rate * foam_lag_s;
	vec2 turn = vec2(cos(angle), sin(angle));
	vec2 z = turned(cos_sin, turn);
	lag_a.x += slope * z.y;
	z = turned(z, turn);
	lag_a.y += slope * z.y;
	z = turned(z, turn);
	lag_a.z += slope * z.y;
	z = turned(z, turn);
	lag_a.w += slope * z.y;
	z = turned(z, turn);
	lag_b.x += slope * z.y;
	z = turned(z, turn);
	lag_b.y += slope * z.y;
	z = turned(z, turn);
	lag_b.z += slope * z.y;
	z = turned(z, turn);
	lag_b.w += slope * z.y;
}

// A wave's `rate` for foam_lags_add(): its angular frequency less how fast the drifting foam runs through
// its phase (k d.u), radians a second.
float foam_rate(vec2 direction, float length_m, float omega) {
	return omega - 2.0 * PI / length_m * dot(direction, foam_drift_ms);
}

// Wind rows (7. above) at a world point, as a factor on the short waves' roughness (1 without): a smooth
// noise stretched along the wind, drifting with the surface, as strong as the wind (m/s at 10 m) makes
// them, and faded out where a pixel is too big for the lanes (they would shimmer).
float wind_rows(vec2 xz, float wind_10m_ms, float pixel_m) {
	if (wind_rows_strength <= 0.0) {
		return 1.0;
	}
	vec2 along = normalize(wind_rows_along + vec2(1e-6, 0.0));
	vec2 drifted = xz - foam_offset_m;
	vec2 p = vec2(dot(drifted, along) / wind_rows_cell_m.x, dot(drifted, vec2(-along.y, along.x)) / wind_rows_cell_m.y);
	float rows = 0.7 * look_noise(p + vec2(17.3, 5.1)).x + 0.3 * look_noise(p * vec2(1.7, 2.3) + vec2(-3.1, 9.7)).y;
	float formed = smoothstep(wind_rows_wind_ms.x, wind_rows_wind_ms.y, wind_10m_ms);
	float seen = 1.0 - smoothstep(0.25 * wind_rows_cell_m.y, 0.5 * wind_rows_cell_m.y, pixel_m);
	return 1.0 + wind_rows_strength * formed * seen * rows;
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
// to breaking.x, the squeeze's variance to breaking.y and its steepness^4 to breaking.z, and its squeeze
// at the 8 earlier moments to lag_a and lag_b (foam_lags_add()).
void lake_look_wave(vec4 part, float steepness, float phase_cycles, float pixel_m, vec2 rest, bool breaks, inout vec3 tangent_x, inout vec3 tangent_z, inout float faded_slope2, inout vec3 breaking, inout vec4 lag_a, inout vec4 lag_b) {
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
	vec2 cos_sin = vec2(cos(phase), sin(phase));
	tangent_x.y += slope * cos_sin.x * direction.x;
	tangent_z.y += slope * cos_sin.x * direction.y;
	faded_slope2 += 0.5 * (1.0 - shown * shown) * steepness * steepness;
	if (breaks) {
		breaking += vec3(slope * cos_sin.y, 0.5 * slope * slope, slope * slope * slope * slope);
		foam_lags_add(slope, cos_sin, foam_rate(direction, length_m, 2.0 * PI * part.w), lag_a, lag_b);
	}
}

// Train `train` (0 to 3 the lake's trains, 4 the look train) drawn as shading (away from the board), as
// its SPREAD_PARTS short-crested parts, which share its energy. `phase` is the train's phase (radians,
// gerstner_lake()'s wave.z).
void lake_spread_train(int train, float phase, float amplitude, float pixel_m, vec2 rest, inout vec3 tangent_x, inout vec3 tangent_z, inout float faded_slope2, inout vec3 breaking, inout vec4 lag_a, inout vec4 lag_b) {
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
		lake_look_wave(part, steepness, phase / (2.0 * PI) + SPREAD_PHASES[j], pixel_m, rest, true, tangent_x, tangent_z, faded_slope2, breaking, lag_a, lag_b);
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
	vec4 no_lags = vec4(0.0);
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
			lake_look_wave(lake_short_parts[band * SHORT_PARTS + j], steepness, phase, pixel_m, bent, false, tangent_x, tangent_z, faded_slope2, no_breaking, no_lags, no_lags);
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

// Zhao and Toba's breaking-wave parameter R_B = u*^2 / (nu omega_p), u*^2 = C_D U10^2 with Wu's C_D
// (LakeLook.breaking_wave_parameter()); 0 without wind or waves.
float breaking_wave_parameter(float wind_10m_ms, float peak_period_s) {
	if (wind_10m_ms <= 0.0 || peak_period_s <= 0.0) {
		return 0.0;
	}
	float drag = 0.0008 + 0.000065 * wind_10m_ms;
	return drag * wind_10m_ms * wind_10m_ms / (AIR_VISCOSITY * 2.0 * PI / peak_period_s);
}

// Zhao and Toba (2001): the share of the water covered by whitecaps (0 to 1) in a wind of U10 m/s over
// waves whose peak period is `peak_period_s` (none from a breaking-wave parameter below about 1000).
float whitecap_fraction(float wind_10m_ms, float peak_period_s) {
	float breaking_parameter = breaking_wave_parameter(wind_10m_ms, peak_period_s);
	if (breaking_parameter <= 0.0) {
		return 0.0;
	}
	float percent = 3.88e-5 * pow(breaking_parameter, 1.09) * smoothstep(800.0, 1200.0, breaking_parameter);
	return min(percent / 100.0, 0.2);
}


// The open sea's measured whitecap cover, percent, for U10 (m/s): Callaghan et al. 2008 (GRL 35, L23609;
// as Albert et al. 2016, ACP 16, 13725, eqs. 2 and 3 give the two fits, which meet at 10.18 m/s), or
// with whitecap_law 2 Monahan and O'Muircheartaigh 1980 (J. Phys. Oceanogr. 10, 2094).
float sea_whitecap_percent(float wind_10m_ms) {
	if (whitecap_law == 2) {
		return 3.84e-4 * pow(max(wind_10m_ms, 0.0), 3.41);
	}
	if (wind_10m_ms <= 3.70) {
		return 0.0;
	}
	if (wind_10m_ms < 10.18) {
		return 3.18e-3 * pow(wind_10m_ms - 3.70, 3.0);
	}
	return 4.82e-4 * pow(wind_10m_ms + 1.98, 3.0);
}

// The share of the water white with whitecaps and their foam (0 to 1) in a wind of U10 m/s, by
// whitecap_law (5. above). `peak_period_s`: the lake's own waves' peak period here (0: no such waves, the
// open sea's set). With a sea law on the lake: times whitecap_water_factor, and none where the lake's own
// waves are too young to break (Zhao and Toba's parameter below whitecap_young_onset, near the upwind shore).
float whitecap_cover(float wind_10m_ms, float peak_period_s) {
	if (whitecap_law == 0) {
		return whitecap_fraction(wind_10m_ms, peak_period_s);
	}
	float cover = sea_whitecap_percent(wind_10m_ms) / 100.0 * whitecap_water_factor;
	if (peak_period_s > 0.0) {
		cover *= smoothstep(whitecap_young_onset, 1000.0, breaking_wave_parameter(wind_10m_ms, peak_period_s));
	}
	return min(cover, 0.2);
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

// The foam left by a whitecap `lags` x foam_lag_s ago, where the squeeze then was `squeeze_then`: as white
// as it is still (exp(-age / foam_life_s)), and bigger by how far it has spread since (the threshold lower
// by spread_per_lag a moment), with a softer edge.
float foam_left(float squeeze_then, float lags, float threshold, float spread_per_lag, float edge, float moved) {
	float age_s = lags * foam_lag_s;
	float grown = threshold - spread_per_lag * lags;
	return exp(-age_s / foam_life_s) * smoothstep(grown - 1.5 * edge, grown + 1.5 * edge, squeeze_then + moved);
}

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
// The fresh, breaking crests take whitecap_active_share of the cover; the foam they leave (6. above) the
// rest: `lag_a` and `lag_b` hold the squeeze at the 8 earlier moments (foam_lags_add()), and each earlier
// whitecap shows fainter, bigger and lacier by its age. The noise drifts with the foam (foam_offset_m).
float lake_whitecap(vec3 breaking, vec4 lag_a, vec4 lag_b, float full_variance, float fraction, vec2 rest, float pixel_m, out float fray) {
	fray = 0.0;
	if (fraction <= 0.0 || full_variance <= 0.0) {
		return 0.0;
	}
	float squeeze = breaking.x;
	float spread = sqrt(breaking.y);
	float frayed = whitecap_fray * spread;
	float variance = spread * spread + frayed * frayed * FRAY_SPREAD * FRAY_SPREAD;
	float active = clamp(fraction * whitecap_active_share, 1e-6, 0.5);
	float threshold = sqrt(variance) * sines_exceeded(active, variance, breaking.z);
	float edge = whitecap_edge * spread;
	float drawn = clamp(breaking.y / full_variance, 0.0, 1.0);
	// The lowest threshold any of the moments can have (the oldest foam has spread most): below it, no foam.
	float spread_per_lag = foam_spread_per_s * foam_lag_s * spread;
	float lowest = threshold - 8.0 * spread_per_lag - 1.5 * edge;
	vec4 most = max(lag_a, lag_b);
	float highest = max(squeeze, max(max(most.x, most.y), max(most.z, most.w)));
	float foam = 0.0;
	if (highest + frayed > lowest) {
		vec2 noise = lake_whitecap_fray(rest - foam_offset_m, pixel_m);
		fray = noise.x;
		float moved = noise.x * frayed;
		float cap = smoothstep(threshold - edge, threshold + edge, squeeze + moved);
		float left = foam_left(lag_a.x, 1.0, threshold, spread_per_lag, edge, moved);
		left = max(left, foam_left(lag_a.y, 2.0, threshold, spread_per_lag, edge, moved));
		left = max(left, foam_left(lag_a.z, 3.0, threshold, spread_per_lag, edge, moved));
		left = max(left, foam_left(lag_a.w, 4.0, threshold, spread_per_lag, edge, moved));
		left = max(left, foam_left(lag_b.x, 5.0, threshold, spread_per_lag, edge, moved));
		left = max(left, foam_left(lag_b.y, 6.0, threshold, spread_per_lag, edge, moved));
		left = max(left, foam_left(lag_b.z, 7.0, threshold, spread_per_lag, edge, moved));
		left = max(left, foam_left(lag_b.w, 8.0, threshold, spread_per_lag, edge, moved));
		// Old foam is a lace with holes, not a sheet: a finer noise (0.15 m, times whitecap_fray_scale),
		// faded where a pixel is too big for it (it would sparkle).
		float fine = 1.0 - smoothstep(0.02, 0.06, pixel_m / whitecap_fray_scale);
		float lace = look_noise((rest - foam_offset_m) / (0.15 * whitecap_fray_scale) + vec2(-7.3, 2.9)).y;
		left *= foam_left_opacity * mix(1.0, smoothstep(-0.3, 0.3, mix(noise.y, lace, fine)), foam_lace);
		foam = max(cap, left);
	}
	return drawn * foam + (1.0 - drawn) * fraction;
}

