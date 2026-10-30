// The sail cloth and the luff sleeve: the shape comes from sail_cloth.gdshaderinc (belly,
// twist, flutter), the colours from the panel picture drawn by
// tools/blender/build_rig_models.py (res://assets/models/sail_panels.png) and a race's tint
// (sail_colour in the include).
// Drawn from both sides; sail cloth lets some light through, so it glows a little with the
// sun behind it.
shader_type spatial;
render_mode cull_disabled;

#include "res://windsurfer/sail_cloth.gdshaderinc"

// The sleeve has no panels: one colour, and its normal is the tube's own.
uniform bool is_sleeve = false;
uniform vec3 sleeve_color : source_color = vec3(0.831, 0.110, 0.133);
uniform float roughness_value = 0.55;
// How much of the light on the other side shines through.
uniform float translucency = 0.35;


void vertex() {
	bend_sail(VERTEX, NORMAL, UV, UV2, !is_sleeve);
}


void fragment() {
	vec4 panel = texture(panel_texture, UV);
	vec3 colour = sail_colour(sleeve_color, 1.0);
	if (!is_sleeve) {
		colour = print_seen_through(sail_colour(panel.rgb, panel.a), panel.a, FRONT_FACING);
	}
	ALBEDO = colour;
	ROUGHNESS = roughness_value;
	BACKLIGHT = colour * translucency;
}
