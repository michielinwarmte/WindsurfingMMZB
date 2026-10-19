// A faint line on the water between the two ends of a start or finish line (course_on_water.gd),
// a thin see-through strip. Its vertices are rest positions on the still water (world x, z); the
// vertex stage moves them with the same Gerstner waves as the water (gerstner.gdshaderinc), as the
// wake does, so the strip lies on the waves you see, a few centimetres above the surface.
shader_type spatial;
render_mode world_vertex_coords, blend_mix, cull_disabled, depth_draw_never, unshaded;

#include "res://world/gerstner.gdshaderinc"

uniform float base_height_m = 0.0;
// Lifted this much above the surface, so the water does not cover it.
uniform float lift_m = 0.04;
uniform vec4 line_color : source_color = vec4(1.0, 1.0, 1.0, 0.45);

void vertex() {
	vec3 displacement;
	vec3 tangent_x;
	vec3 tangent_z;
	float crest;
	float total_steepness;
	wave_surface(VERTEX.xz, displacement, tangent_x, tangent_z, crest, total_steepness);
	VERTEX = vec3(VERTEX.x, base_height_m + lift_m, VERTEX.z) + displacement;
}

void fragment() {
	// UV.y runs across the strip from 0 to 1: soft edges, so it reads as a line, not a plank.
	float across = abs(UV.y * 2.0 - 1.0);
	ALBEDO = line_color.rgb;
	ALPHA = line_color.a * (1.0 - smoothstep(0.5, 1.0, across));
}
