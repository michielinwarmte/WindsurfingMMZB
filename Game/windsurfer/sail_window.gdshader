// The sail's clear windows (monofilm): see-through with a light tint and a glossy surface.
// They bend with the cloth around them (sail_cloth.gdshaderinc).
shader_type spatial;
render_mode cull_disabled, blend_mix;

#include "res://windsurfer/sail_cloth.gdshaderinc"

uniform vec4 tint : source_color = vec4(0.80, 0.86, 0.92, 0.25);


void vertex() {
	bend_sail(VERTEX, NORMAL, UV, UV2, true);
}


void fragment() {
	ALBEDO = tint.rgb;
	ALPHA = tint.a;
	ROUGHNESS = 0.08;
	SPECULAR = 0.6;
}
