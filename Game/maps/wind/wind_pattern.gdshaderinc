// The map's wind on the graphics card (MAP_SILVAPLANA_PLAN.md, W2 and W3). wind_at() computes the
// same as MapWind.velocity_in() in GDScript, step by step, with the same random numbers
// (WindGusts.noise_3d()), so what the viewer draws is what the game's numbers say (WD1). The script
// fills these from WindPattern.set_shader_pattern(), MapWind.shader_constants() and, every frame,
// WindMoment.shader_parameters().

// The fixed pattern, one pixel per 50 m cell (WindPattern.to_image()): red is the arrow along the
// lake's average wind, green its part turned clockwise, blue the ground height (m above the lake).
uniform sampler2D wind_pattern : filter_linear, repeat_disable;
// Game X and Z of the first cell's centre (the north-west one), the cell size, and the number of
// cells west to east and north to south.
uniform vec2 pattern_origin_m;
uniform float pattern_cell_m = 50.0;
uniform vec2 pattern_cells = vec2(1.0);

// The day's wind at the moment: the lake's mean speed (m/s), the compass bearing its air moves to
// (radians), the time of day (s), how fast gusts, pulses and shifts travel down the lake (m/s), how
// far the air has travelled since midnight (m), and the spread of the gusts and lulls (m/s).
uniform float lake_speed_ms = 0.0;
uniform float lake_to_rad = 0.0;
uniform float time_of_day_s = 0.0;
uniform float drift_ms = 8.0;
uniform float travel_m = 0.0;
uniform float gust_spread_ms = 0.0;
// The lake's downwind direction (game X, Z), fixed: "along" and "across" the lake refer to it.
uniform vec2 lake_axis = vec2(0.0, -1.0);

// Pulses and shifts (WindGusts): three slow waves each.
uniform vec3 pulse_amplitudes = vec3(0.0);
uniform vec3 pulse_periods_s = vec3(1.0);
uniform vec3 pulse_phases = vec3(0.0);
uniform vec3 shift_amplitudes_rad = vec3(0.0);
uniform vec3 shift_periods_s = vec3(1.0);
uniform vec3 shift_phases = vec3(0.0);

// The gusts and lulls (WindGusts): how gusty the lake's ends are (upwind, downwind, and where those
// ends are along the lake); the sideways share; the weights of the fronts and the lanes; their
// noise cells (along m, across m, life s); and the first of the noise's four streams.
uniform vec4 gustiness_ends = vec4(1.0, 1.0, -1.0, 1.0);
uniform float gust_sideways_share = 0.8;
uniform vec2 gust_weights = vec2(0.0);
uniform vec3 front_cells = vec3(1.0);
uniform vec3 lane_cells = vec3(1.0);
uniform int gust_stream = 4;

// The lee along the shore (WindLee): its texture (red the shape, green what the fixed pattern
// already holds of it), where its cells lie, the photos' fit (the band's lee at the reference, per
// degree from further right, per knot), the reference (where the lake's wind comes from, degrees;
// its speed, knots), the ranges the photos cover (degrees low, high; knots low, high), which gusts
// get through (WindGusts.reach_centre(), reach_width, reach_share), and whether there is a lee at all.
uniform sampler2D shore_lee : filter_linear, repeat_disable;
uniform vec2 lee_origin_m;
uniform float lee_cell_m = 10.0;
uniform vec2 lee_cells = vec2(1.0);
uniform vec3 lee_fit = vec3(0.0);
uniform vec2 lee_reference = vec2(0.0);
uniform vec4 lee_ranges = vec4(0.0);
uniform vec3 lee_reach = vec3(1.0, 0.5, 0.1);
uniform float lee_enabled = 0.0;

// The pattern at a game position (X, Z). Between the cell centres the graphics card interpolates,
// like WindPattern.arrow_at(); outside, it keeps the edge (repeat_disable).
vec4 pattern_at(vec2 xz) {
	vec2 uv = ((xz - pattern_origin_m) / pattern_cell_m + 0.5) / pattern_cells;
	return textureLod(wind_pattern, uv, 0.0);
}

// How far a game position is inside the pattern, in metres (negative outside).
float inside_pattern_m(vec2 xz) {
	vec2 from_start = xz - pattern_origin_m;
	vec2 to_end = pattern_origin_m + (pattern_cells - 1.0) * pattern_cell_m - xz;
	return min(min(from_start.x, from_start.y), min(to_end.x, to_end.y));
}

// Three slow waves added up (WindGusts._waves()).
float wind_waves(float tau_s, vec3 amplitudes, vec3 periods_s, vec3 phases) {
	return dot(amplitudes, sin(TAU * tau_s / periods_s + phases));
}

// WindGusts._hash32(): the same 32-bit hash ("lowbias32").
uint wind_hash(uint x) {
	x ^= x >> 16u;
	x *= 0x7feb352du;
	x ^= x >> 15u;
	x *= 0x846ca68bu;
	x ^= x >> 16u;
	return x;
}

// WindGusts._corner(): a grid corner's random value, -1 to 1.
float wind_corner(ivec3 c, uint stream) {
	uint h = wind_hash(uint(c.x) + wind_hash(uint(c.y) + wind_hash(uint(c.z) + wind_hash(stream))));
	return float(h) / 4294967295.0 * 2.0 - 1.0;
}

// WindGusts.noise_3d(): smooth random values, blended between the 8 corners of a cell, with a
// spread of 1 at every point.
float wind_noise(vec3 p, uint stream) {
	vec3 cell = floor(p);
	ivec3 i = ivec3(cell);
	vec3 f = p - cell;
	f = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
	float result = 0.0;
	for (int corner = 0; corner < 8; corner++) {
		ivec3 c = ivec3(corner & 1, (corner >> 1) & 1, (corner >> 2) & 1);
		vec3 w = mix(1.0 - f, f, vec3(c));
		result += w.x * w.y * w.z * wind_corner(i + c, stream);
	}
	vec3 squared = f * f + (1.0 - f) * (1.0 - f);
	return result / sqrt(squared.x * squared.y * squared.z / 3.0);
}

// WindGusts.gusts_at(): the gusts and lulls with a spread of 1, along the wind and sideways.
float wind_gust_part(float rolled_m, float across_m, uint stream) {
	float front = wind_noise(vec3(rolled_m / front_cells.x, across_m / front_cells.y, time_of_day_s / front_cells.z), stream);
	float lane = wind_noise(vec3(rolled_m / lane_cells.x, across_m / lane_cells.y, time_of_day_s / lane_cells.z), stream + 1u);
	return gust_weights.x * front + gust_weights.y * lane;
}

vec2 wind_gusts_at(float rolled_m, float across_m) {
	uint stream = uint(gust_stream);
	return vec2(wind_gust_part(rolled_m, across_m, stream), wind_gust_part(rolled_m, across_m, stream + 2u));
}

// WindLee.at(): the lee's shape and what the fixed pattern holds of it; 0 outside its grid.
vec2 wind_lee_at(vec2 xz) {
	vec2 f = (xz - lee_origin_m) / lee_cell_m;
	if (f.x < 0.0 || f.y < 0.0 || f.x > lee_cells.x - 1.0 || f.y > lee_cells.y - 1.0) {
		return vec2(0.0);
	}
	return textureLod(shore_lee, (f + 0.5) / lee_cells, 0.0).rg;
}

// MapWind.lee_factor(): how much of the wind is left in the lee.
float wind_lee_factor(vec2 xz, float from_deg, float lake_kt, float unit_along) {
	vec2 shape_held = wind_lee_at(xz);
	if (lee_enabled < 0.5 || (shape_held.x == 0.0 && shape_held.y == 0.0)) {
		return 1.0;
	}
	float degrees_right = clamp(mod(from_deg - lee_reference.x + 180.0, 360.0) - 180.0, lee_ranges.x, lee_ranges.y);
	float knots = clamp(lake_kt - lee_reference.y, lee_ranges.z, lee_ranges.w);
	float band_lee = max(lee_fit.x + lee_fit.y * degrees_right + lee_fit.z * knots, 0.0);
	float depth = band_lee / (1.0 - lee_reach.z);
	float reach = smoothstep(lee_reach.x - lee_reach.y / 2.0, lee_reach.x + lee_reach.y / 2.0, unit_along);
	float left = 1.0 - shape_held.x * depth * (1.0 - reach);
	return max(left, 0.05) / (1.0 - shape_held.y);
}

// The air's velocity at a game position (X, Z): where it moves to, m/s (MapWind.velocity_in()).
vec3 wind_at(vec2 xz) {
	// 1. The pulse and the shift, which travel down the lake.
	float along_m = dot(xz, lake_axis);
	float tau_s = time_of_day_s - along_m / drift_ms;
	float speed_ms = lake_speed_ms * (1.0 + wind_waves(tau_s, pulse_amplitudes, pulse_periods_s, pulse_phases));
	float to_rad = lake_to_rad + wind_waves(tau_s, shift_amplitudes_rad, shift_periods_s, shift_phases);

	// 2. The pattern, carried by the lake's mean wind.
	vec4 pattern = pattern_at(xz);
	vec2 downwind = vec2(sin(to_rad), -cos(to_rad));
	vec2 clockwise = vec2(-downwind.y, downwind.x);
	vec2 flow = (downwind * pattern.r + clockwise * pattern.g) * speed_ms;
	float base_ms = length(flow);
	if (base_ms < 0.001) {
		return vec3(flow.x, 0.0, flow.y);
	}

	// 3. The gusts and lulls, rolling down the lake with the air.
	float across_m = dot(xz, vec2(-lake_axis.y, lake_axis.x));
	float gustiness = mix(gustiness_ends.x, gustiness_ends.y, smoothstep(gustiness_ends.z, gustiness_ends.w, along_m));
	vec2 unit = wind_gusts_at(along_m - travel_m, across_m);
	vec2 gust = unit * gust_spread_ms * gustiness;
	vec2 direction = flow / base_ms;
	vec2 side = vec2(-direction.y, direction.x);
	float new_speed_ms = max(base_ms + gust.x, 0.05 * base_ms);
	vec2 result = direction * new_speed_ms + side * gust.y * gust_sideways_share;

	// 4. The lee along the shore, except where a strong gust gets into it.
	result *= wind_lee_factor(xz, degrees(to_rad) - 180.0, speed_ms / (1852.0 / 3600.0), unit.x);
	return vec3(result.x, 0.0, result.y);
}
