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
