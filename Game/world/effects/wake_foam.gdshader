// The wake behind the board (wake_trail.gd): a ribbon of foam that lies on the water and fades.
// Its vertices are the rest positions of the trail on the still water; the vertex stage moves
// them with the same Gerstner waves as the water (gerstner.gdshaderinc), so the foam rides on
// the waves you see, a few centimetres above the surface.
//
// What a planing board leaves (photos and video of slalom boards): white churned water right
// behind the tail, two thin lines of foam from the rails that spread apart, and a smooth flat
// strip between them; all of it breaks up into patches and fades within some seconds.
//
// Vertex colour: red = the age as a share of the trail's life (0 new, 1 gone), alpha = how
// strong the wake was where it was made (speed and planing). UV.x is the distance along the
// trail in metres, UV.y runs across it from 0 to 1.
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

varying vec2 rest_position;

void vertex() {
	rest_position = VERTEX.xz;
	vec3 displacement;
	vec3 tangent_x;
	vec3 tangent_z;
	float crest;
	float total_steepness;
	wave_surface(rest_position, displacement, tangent_x, tangent_z, crest, total_steepness);
	VERTEX = vec3(VERTEX.x, base_height_m + lift_m, VERTEX.z) + displacement;
	NORMAL = normalize(cross(tangent_z, tangent_x));
}

void fragment() {
	float age = COLOR.r;
	float strength = COLOR.a;
	float across = abs(UV.y * 2.0 - 1.0);  // 0 in the middle, 1 at the edges
	float soft_edges = 1.0 - smoothstep(0.8, 1.0, across);
	// Two thin lines from the rails, and white churned water for the first metres behind the
	// tail (half a second of the trail); the strip between the lines stays clear.
	float rail_lines = smoothstep(0.4, 0.7, across) * soft_edges;
	float churn = (1.0 - across * across) * (1.0 - smoothstep(0.0, 0.07, age));
	float fade = strength * pow(1.0 - age, 2.0);
	float foam = max(rail_lines * 0.6, churn * 0.9) * fade;
	// It breaks up into patches as it fades: only where the noise beats what is left.
	float noise = texture(foam_noise, rest_position / noise_size_m).r;
	float patches = smoothstep(0.6 - foam, 0.9 - foam, noise);
	ALBEDO = foam_color;
	ALPHA = clamp(foam * patches, 0.0, 0.9);
	ROUGHNESS = 0.7;
	SPECULAR = 0.2;
}
