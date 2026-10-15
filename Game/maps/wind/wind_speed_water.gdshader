// The wind speed as colour on the water (the wind viewer, MAP_SILVAPLANA_PLAN.md W2): a flat layer
// just above the lake, coloured by the wind there, gusts included, with WindColors' scale
// (Windfinder's). The legend uses the same colours. The terrain covers the layer on land.
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

#include "res://maps/wind/wind_pattern.gdshaderinc"

// WindColors.texture(): the colour for 0 knots on the left, for max_knots on the right.
uniform sampler2D speed_colors : source_color, filter_linear, repeat_disable;
uniform float max_knots = 53.0;
// Fully covering, so the colours are exactly the legend's (C in the viewer shows the water itself).
uniform float opacity : hint_range(0.0, 1.0) = 1.0;

const float KNOT_MS = 1852.0 / 3600.0;

varying vec2 world_xz;

void vertex() {
	world_xz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

void fragment() {
	float knots = length(wind_at(world_xz)) / KNOT_MS;
	ALBEDO = texture(speed_colors, vec2(knots / max_knots, 0.5)).rgb;
	ALPHA = opacity;
}
