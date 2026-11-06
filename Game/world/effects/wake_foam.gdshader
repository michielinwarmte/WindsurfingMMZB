// The wake behind the board (wake_trail.gd): foam that lies on the water and fades. Its vertices
// are rest positions on the still water; the vertex stage moves them with the same Gerstner waves
// as the water (gerstner.gdshaderinc), so the foam rides on the waves you see, a few centimetres
// above the surface.
//
// What a planing board leaves (photos and video of slalom boards): white churned water right
// behind the tail, two thin lines of foam from the rails that spread apart and break up, and a
// smooth flat strip between them; in a carve the inside (low) rail's line is the whiter. All of it
// breaks up into patches and fades within some seconds.
//
// Three kinds, by the vertex colour's blue (wake_trail.gd's KIND_*):
// - 0, the trail: red = the age as a share of the trail's life (0 new, 1 gone), green = the carve
//   (0.5 none, 1 the starboard rail in, 0 the port rail in), alpha = how strong the wake was where it
//   was made. UV.x is the distance along the trail in metres, UV.y runs across it from 0 (starboard)
//   to 1 (port).
// - 0.5, an arm of the bow wave's V: red = age share, green = how far along the arm (0 at the bow),
//   alpha = the bow wave's strength; UV.y across the line.
// - 1, a patch of foam where a splash came down: red = age share, alpha = strength; UV across it.
shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_never;

#include "res://world/gerstner.gdshaderinc"

uniform float base_height_m = 0.0;
// Lifted this much above the surface, so the water does not cover it.
uniform float lift_m = 0.03;
// A seamless noise picture that breaks the foam into patches, this many metres across.
uniform sampler2D foam_noise : repeat_enable, filter_linear_mipmap;
uniform float noise_size_m = 2.5;
uniform vec3 foam_color : source_color = vec3(0.92, 0.95, 0.97);
// How white the rail lines and the churn behind the tail are at full strength (by eye, the photos:
// the lines are fainter than the churn and thin out within a few seconds).
uniform float rail_line_opacity = 0.42;
uniform float churn_opacity = 0.9;
// The bow wave's lines: faint (a low wave catching the light and a little foam at the bow).
uniform float arm_opacity = 0.3;
uniform float patch_opacity = 0.6;

varying vec2 rest_position;

void vertex() {
	rest_position = VERTEX.xz;
	vec3 displacement;
	vec3 tangent_x;
	vec3 tangent_z;
	float crest;
	float total_steepness;
	water_surface(rest_position, displacement, tangent_x, tangent_z, crest, total_steepness);
	VERTEX = vec3(VERTEX.x, base_height_m + lift_m, VERTEX.z) + displacement;
	NORMAL = normalize(cross(tangent_z, tangent_x));
}

// Breaks foam of this amount into patches: where the noise beats what is left. `stretch` draws the
// noise out along the trail (streaks, as foam drawn out behind a moving board).
float broken(float foam, vec2 at, float stretch) {
	float noise = texture(foam_noise, at / noise_size_m * vec2(1.0, stretch)).r;
	return foam * smoothstep(0.6 - foam, 0.9 - foam, noise);
}

float trail_foam(vec2 uv, float age, float strength, float carve) {
	float signed_across = 1.0 - 2.0 * uv.y;  // +1 on the starboard edge, -1 on the port edge
	float across = abs(signed_across);  // 0 in the middle, 1 at the edges
	float soft_edges = 1.0 - smoothstep(0.82, 1.0, across);
	// The inside rail of a carve whiter, the outside one fainter.
	float inside = clamp(1.0 + 0.8 * carve * sign(signed_across), 0.2, 1.8);
	// Two thin lines from the rails, fading faster than the trail; the strip between them clear.
	float rail_lines = smoothstep(0.55, 0.8, across) * soft_edges * inside * pow(1.0 - age, 3.0);
	// White churned water for the first metres behind the tail (half a second of the trail),
	// leaning to the inside rail in a carve.
	float churn_across = abs(signed_across - 0.35 * carve);
	float churn = (1.0 - churn_across * churn_across) * (1.0 - smoothstep(0.0, 0.07, age));
	float fade = strength * pow(1.0 - age, 2.0);
	return max(rail_lines * rail_line_opacity, churn * churn_opacity) * fade;
}

float arm_foam(vec2 uv, float age, float along, float strength) {
	float across = abs(uv.y * 2.0 - 1.0);
	float line = 1.0 - smoothstep(0.3, 1.0, across);
	// Strongest at the bow (a little white water there), fading along the arm and with age.
	float bow = 1.0 + 1.5 * (1.0 - smoothstep(0.0, 0.2, along));
	return arm_opacity * line * bow * strength * (1.0 - along) * pow(1.0 - age, 2.0);
}

float patch_foam(vec2 uv, float age, float strength) {
	vec2 p = uv * 2.0 - 1.0;
	float r = length(p);
	// A ring at first (the water pushed out round the splash), filling in and fading.
	float disc = 1.0 - smoothstep(0.3, 1.0, r);
	float ring = mix(0.55 + 0.45 * smoothstep(0.2, 0.7, r), 1.0, age);
	return patch_opacity * disc * ring * strength * pow(1.0 - age, 1.5);
}

void fragment() {
	float age = COLOR.r;
	float kind = COLOR.b;
	float strength = COLOR.a;
	float foam;
	if (kind < 0.25) {
		float carve = COLOR.g * 2.0 - 1.0;
		foam = broken(trail_foam(UV, age, strength, carve), rest_position, 1.0);
	} else if (kind < 0.75) {
		foam = broken(arm_foam(UV, age, COLOR.g, strength), rest_position * 1.7, 1.0);
	} else {
		// A patch thins into lace as it ages: finer noise, which breaks it up more as it fades.
		foam = broken(patch_foam(UV, age, strength), rest_position * 2.2, 1.0);
	}
	ALBEDO = foam_color;
	ALPHA = clamp(foam, 0.0, 0.9);
	ROUGHNESS = 0.7;
	SPECULAR = 0.2;
}
