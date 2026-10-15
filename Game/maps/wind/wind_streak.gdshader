// Draws one wind streak (WindStreaks): a white ribbon along the particle's recent path, bright at
// the head, fading toward the tail, with soft edges.
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled, particle_trails;

uniform vec4 streak_color : source_color = vec4(1.0, 1.0, 1.0, 0.9);

void fragment() {
	// UV.y runs along the ribbon, from the head (0) to the tail (1); UV.x across it.
	float tail = UV.y;
	float edge = abs(UV.x * 2.0 - 1.0);
	ALBEDO = streak_color.rgb;
	ALPHA = streak_color.a * COLOR.a * (1.0 - tail) * (1.0 - edge * edge);
}
