// The sail's clear film (monofilm): the clear panel around the boom and the action window.
// See-through with a light tint and a glossy surface where the panel picture says clear film
// (alpha 0); where something is printed or sewn over it (a batten pocket, the stripe, the
// window's border) it is drawn as the cloth is. It bends with the cloth around it
// (sail_cloth.gdshaderinc).
shader_type spatial;
render_mode cull_disabled, blend_mix;

#include "res://windsurfer/sail_cloth.gdshaderinc"

uniform vec4 tint : source_color = vec4(0.80, 0.86, 0.92, 0.25);
// How much of the light on the other side shines through the cloth parts (as the cloth's).
uniform float translucency = 0.35;


void vertex() {
	bend_sail(VERTEX, NORMAL, UV, UV2, true);
}


void fragment() {
	vec4 panel = texture(panel_texture, UV);
	float cloth = smoothstep(0.1, 0.25, panel.a);
	vec3 printed = print_seen_through(sail_colour(panel.rgb, panel.a), panel.a, FRONT_FACING);
	vec3 colour = mix(tint.rgb, printed, cloth);
	ALBEDO = colour;
	ALPHA = mix(tint.a, 1.0, cloth);
	ROUGHNESS = mix(0.08, 0.55, cloth);
	SPECULAR = mix(0.6, 0.5, cloth);
	BACKLIGHT = colour * translucency * cloth;
}
