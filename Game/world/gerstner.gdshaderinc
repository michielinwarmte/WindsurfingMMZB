// The Gerstner waves of res://sim/wave_field.gd (plan decision D5), for every shader that lies
// on the water: the water itself (res://world/water.gdshader) and the wake behind the board
// (res://world/effects/wake_foam.gdshader), so the wake rides exactly on the waves you see.
// The displacement of PHYSICS_SPEC.md 9.4 and the exact normal of 9.6a. Change one, change
// the other: wave_field.gd and this file must always compute the same surface.
//
// The parameters come from WaveField.shader_parameters() (ocean.gd sets them), and the clock
// is the simulation's, never the engine's.

// Per wave: travel direction (x, z), steepness, wavelength in m. An empty slot has amplitude 0.
uniform vec4 wave_a = vec4(0.0, -1.0, 0.0, 10.0);
uniform vec4 wave_b = vec4(0.0, -1.0, 0.0, 10.0);
uniform vec4 wave_c = vec4(0.0, -1.0, 0.0, 10.0);
uniform vec4 wave_d = vec4(0.0, -1.0, 0.0, 10.0);
uniform vec4 wave_amplitudes = vec4(0.0);
// The simulation clock (never the engine clock): set every frame by the ocean node.
uniform float water_time_s = 0.0;

const float G = 9.81;

// Accumulates one wave: the displacement of 9.4, the tangent vectors of 9.6a and the
// rendering-only crest factor. `rest` is the world (x, z) of the undisplaced vertex.
void gerstner(vec4 wave, float amplitude, vec2 rest, float t, inout vec3 displacement, inout vec3 tangent_x, inout vec3 tangent_z, inout float crest, inout float total_steepness) {
	if (amplitude <= 0.0) {
		return;
	}
	vec2 d = wave.xy;
	float s = wave.z;
	float k = 2.0 * PI / max(wave.w, 0.5);
	float omega = sqrt(G * k);
	float phase = k * dot(d, rest) - omega * t;
	float sp = sin(phase);
	float cp = cos(phase);
	float horizontal = s / k * cp;
	displacement += vec3(d.x * horizontal, amplitude * sp, d.y * horizontal);
	tangent_x += vec3(-d.x * d.x * s * sp, amplitude * k * d.x * cp, -d.x * d.y * s * sp);
	tangent_z += vec3(-d.x * d.y * s * sp, amplitude * k * d.y * cp, -d.y * d.y * s * sp);
	crest += s * sp;
	total_steepness += s;
}

// All four waves at the rest point `rest` at the simulation time: how far the surface point
// moved, the surface's two directions along x and z (their cross product is the normal), the
// sum of steepness x sin(phase) (the slope at a crest) and the total steepness.
void wave_surface(vec2 rest, out vec3 displacement, out vec3 tangent_x, out vec3 tangent_z, out float crest, out float total_steepness) {
	displacement = vec3(0.0);
	tangent_x = vec3(1.0, 0.0, 0.0);
	tangent_z = vec3(0.0, 0.0, 1.0);
	crest = 0.0;
	total_steepness = 0.0;
	gerstner(wave_a, wave_amplitudes.x, rest, water_time_s, displacement, tangent_x, tangent_z, crest, total_steepness);
	gerstner(wave_b, wave_amplitudes.y, rest, water_time_s, displacement, tangent_x, tangent_z, crest, total_steepness);
	gerstner(wave_c, wave_amplitudes.z, rest, water_time_s, displacement, tangent_x, tangent_z, crest, total_steepness);
	gerstner(wave_d, wave_amplitudes.w, rest, water_time_s, displacement, tangent_x, tangent_z, crest, total_steepness);
}

// ---------------------------------------------------------------------------------------------
// A lake's own waves (PHYSICS_SPEC.md 9.17; res://sim/lake_wave_field.gd, res://sim/lake_waves.gd):
// with lake_waves_on, wave_a to wave_d are the lake's trains as (direction x, direction z, phase at
// the origin, wavelength), and each train's amplitude comes from the lake's grid (lake_envelope, one
// texel per node, RGBA = the four trains), read with texelFetch and mixed between the four nearest
// nodes exactly as LakeWaveField.amplitudes_for() does; the steepness is the physical one, k·A, at
// most pi/7. The physics floats on the first lake_shape_trains trains (the longest): only those
// move the surface (water_surface(); the water shader draws the others as shading). The physics
// reads the grid at the asked point, this at the vertex's rest point: they differ by a fraction of
// a millimetre (the heights change over 16 m, a rest point moves about 0.1 m at most).
uniform bool lake_waves_on = false;
uniform int lake_shape_trains = 4;
uniform sampler2D lake_envelope : filter_nearest, repeat_disable;
// x and z of the first node, 1 / the nodes' spacing; the number of nodes west to east, north to south.
uniform vec4 lake_grid = vec4(0.0, 0.0, 1.0, 0.0);
uniform ivec2 lake_grid_size = ivec2(0);

// The four trains' amplitudes at a world (x, z): bilinear between the four nearest nodes, 0 off the
// grid (LakeWaveField.amplitudes_for()).
vec4 lake_amplitudes(vec2 xz) {
	vec2 f = (xz - lake_grid.xy) * lake_grid.z;
	if (f.x < 0.0 || f.y < 0.0 || f.x >= float(lake_grid_size.x - 1) || f.y >= float(lake_grid_size.y - 1)) {
		return vec4(0.0);
	}
	ivec2 node = ivec2(f);
	vec2 t = f - vec2(node);
	vec4 north = mix(texelFetch(lake_envelope, node, 0), texelFetch(lake_envelope, node + ivec2(1, 0), 0), t.x);
	vec4 south = mix(texelFetch(lake_envelope, node + ivec2(0, 1), 0), texelFetch(lake_envelope, node + ivec2(1, 1), 0), t.x);
	return mix(north, south, t.y);
}

// One lake train, as gerstner() but with its own phase and the physical steepness, scaled by
// `weight` (the share of the train the mesh shows as shape: 1 near the camera, less where the mesh's
// cells are too big for it; water.gdshader adds the rest as shading).
void gerstner_lake(vec4 wave, float amplitude, float weight, vec2 rest, float t, inout vec3 displacement, inout vec3 tangent_x, inout vec3 tangent_z, inout float crest, inout float total_steepness) {
	if (amplitude <= 0.0 || weight <= 0.0) {
		return;
	}
	vec2 d = wave.xy;
	float k = 2.0 * PI / max(wave.w, 0.5);
	float omega = sqrt(G * k);
	float a = amplitude * weight;
	float s = min(k * amplitude, PI / 7.0) * weight;
	float phase = k * dot(d, rest) - omega * t + wave.z;
	float sp = sin(phase);
	float cp = cos(phase);
	float horizontal = s / k * cp;
	displacement += vec3(d.x * horizontal, a * sp, d.y * horizontal);
	tangent_x += vec3(-d.x * d.x * s * sp, a * k * d.x * cp, -d.x * d.y * s * sp);
	tangent_z += vec3(-d.x * d.y * s * sp, a * k * d.y * cp, -d.y * d.y * s * sp);
	crest += s * sp;
	total_steepness += s;
}

// The lake's four trains at a rest point, each scaled by its weight (vec4(1.0): all of it).
void lake_wave_surface(vec2 rest, vec4 weights, out vec3 displacement, out vec3 tangent_x, out vec3 tangent_z, out float crest, out float total_steepness) {
	displacement = vec3(0.0);
	tangent_x = vec3(1.0, 0.0, 0.0);
	tangent_z = vec3(0.0, 0.0, 1.0);
	crest = 0.0;
	total_steepness = 0.0;
	vec4 amplitudes = lake_amplitudes(rest);
	gerstner_lake(wave_a, amplitudes.x, weights.x, rest, water_time_s, displacement, tangent_x, tangent_z, crest, total_steepness);
	gerstner_lake(wave_b, amplitudes.y, weights.y, rest, water_time_s, displacement, tangent_x, tangent_z, crest, total_steepness);
	gerstner_lake(wave_c, amplitudes.z, weights.z, rest, water_time_s, displacement, tangent_x, tangent_z, crest, total_steepness);
	gerstner_lake(wave_d, amplitudes.w, weights.w, rest, water_time_s, displacement, tangent_x, tangent_z, crest, total_steepness);
}

// 1 for each lake train that moves the surface (the physics' trains), 0 for the others.
vec4 lake_shape_mask() {
	return vec4(lessThan(vec4(0.0, 1.0, 2.0, 3.0), vec4(float(lake_shape_trains))));
}

// The surface any shader on the water rides: the lake's trains the physics floats on, or the wave
// set's.
void water_surface(vec2 rest, out vec3 displacement, out vec3 tangent_x, out vec3 tangent_z, out float crest, out float total_steepness) {
	if (lake_waves_on) {
		lake_wave_surface(rest, lake_shape_mask(), displacement, tangent_x, tangent_z, crest, total_steepness);
	} else {
		wave_surface(rest, displacement, tangent_x, tangent_z, crest, total_steepness);
	}
}
