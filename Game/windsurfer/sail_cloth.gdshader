// The sail cloth and the luff sleeve: the shape comes from sail_cloth.gdshaderinc (belly,
// twist, flutter), the colours from the panel picture drawn by
// tools/blender/build_rig_models.py (res://assets/models/sail_panels.png).
// Drawn from both sides; sail cloth lets some light through, so it glows a little with the
// sun behind it.
shader_type spatial;
render_mode cull_disabled;

#include "res://windsurfer/sail_cloth.gdshaderinc"

uniform sampler2D panel_texture : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
// The sleeve has no panels: one colour, and its normal is the tube's own.
uniform bool is_sleeve = false;
uniform vec3 sleeve_color : source_color = vec3(0.13, 0.13, 0.15);
uniform float roughness_value = 0.55;
// How much of the light on the other side shines through.
uniform float translucency = 0.35;


void vertex() {
	bend_sail(VERTEX, NORMAL, UV, UV2, !is_sleeve);
}


void fragment() {
	vec3 colour = is_sleeve ? sleeve_color : texture(panel_texture, UV).rgb;
	ALBEDO = colour;
	ROUGHNESS = roughness_value;
	BACKLIGHT = colour * translucency;
}
