// The ocean: the same Gerstner waves as res://sim/wave_field.gd (plan decision D5), with the
// displacement of PHYSICS_SPEC.md 9.4 and the exact normal of 9.6a in the vertex stage, so
// the board floats on exactly the surface you see. Change one, change the other.
//
// The mesh this runs on must only be translated (never rotated or scaled): the vertex
// positions are taken as world rest positions and the normal is written as a world normal.
// The node is placed at the still-water height, so VERTEX.y is the wave's height above it.
shader_type spatial;

// Per wave: travel direction (x, z), steepness, wavelength in m. An empty slot has amplitude 0.
uniform vec4 wave_a = vec4(0.0, -1.0, 0.0, 10.0);
uniform vec4 wave_b = vec4(0.0, -1.0, 0.0, 10.0);
uniform vec4 wave_c = vec4(0.0, -1.0, 0.0, 10.0);
uniform vec4 wave_d = vec4(0.0, -1.0, 0.0, 10.0);
uniform vec4 wave_amplitudes = vec4(0.0);
// The simulation clock (never the engine clock): set every frame by the ocean node.
uniform float water_time_s = 0.0;

uniform vec3 deep_color : source_color = vec3(0.02, 0.13, 0.26);
uniform vec3 shallow_color : source_color = vec3(0.05, 0.36, 0.44);
uniform vec3 foam_color : source_color = vec3(0.93, 0.96, 0.98);
// Foam appears where the local steepness (the sum of steepness x sin(phase), which is the
// slope of the surface at a crest) is above this: real waves whitecap from a steepness of
// about 0.3 and break at 0.44, so a gentle swell shows no foam at all.
uniform float foam_threshold = 0.3;
uniform float roughness_value = 0.06;
// A faint grid in world coordinates so that speed and heading show on flat water.
uniform vec3 line_color : source_color = vec3(0.6, 0.8, 0.9);
uniform float grid_strength = 0.12;
uniform float cell_m = 5.0;
uniform float line_width_m = 0.08;
uniform float grid_fade_distance_m = 120.0;

varying vec3 world_position;
varying float crest_factor;  // -1 in a trough to +1 on a crest
varying float crest_steepness;  // the sum of steepness x sin(phase): the surface slope at a crest

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

void vertex() {
	vec2 rest = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
	vec3 displacement = vec3(0.0);
	vec3 tangent_x = vec3(1.0, 0.0, 0.0);
	vec3 tangent_z = vec3(0.0, 0.0, 1.0);
	float crest = 0.0;
	float total_steepness = 0.0;
	gerstner(wave_a, wave_amplitudes.x, rest, water_time_s, displacement, tangent_x, tangent_z, crest, total_steepness);
	gerstner(wave_b, wave_amplitudes.y, rest, water_time_s, displacement, tangent_x, tangent_z, crest, total_steepness);
	gerstner(wave_c, wave_amplitudes.z, rest, water_time_s, displacement, tangent_x, tangent_z, crest, total_steepness);
	gerstner(wave_d, wave_amplitudes.w, rest, water_time_s, displacement, tangent_x, tangent_z, crest, total_steepness);
	VERTEX = VERTEX + displacement;
	NORMAL = normalize(cross(tangent_z, tangent_x));
	crest_factor = total_steepness > 0.0 ? crest / total_steepness : -1.0;
	crest_steepness = crest;
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float grid_line(vec2 p, float cell, float width) {
	vec2 to_line = abs(fract(p / cell - 0.5) - 0.5) * cell;
	float d = min(to_line.x, to_line.y);
	float soft = fwidth(d) + 0.001;
	return 1.0 - smoothstep(width * 0.5, width * 0.5 + soft, d);
}

void fragment() {
	// Water seen steeply is dark and deep; seen at a glancing angle it mirrors the sky
	// (Fresnel), which Godot's specular term does with a low roughness.
	float facing = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	float fresnel = pow(1.0 - facing, 4.0);
	// Lighter toward the crests, where the water is thinner over the light scattered up.
	vec3 color = mix(deep_color, shallow_color, clamp(0.5 + 0.5 * crest_factor, 0.0, 1.0) * 0.6);
	float foam = smoothstep(foam_threshold, foam_threshold + 0.15, crest_steepness);
	color = mix(color, foam_color, foam * 0.7);
	float distance_fade = clamp(1.0 - length(world_position - CAMERA_POSITION_WORLD) / grid_fade_distance_m, 0.0, 1.0);
	float lines = grid_line(world_position.xz, cell_m, line_width_m) * distance_fade * grid_strength;
	ALBEDO = mix(color, line_color, lines);
	ROUGHNESS = mix(roughness_value, 0.5, foam);
	METALLIC = 0.0;
	SPECULAR = mix(0.35, 1.0, fresnel);
}
