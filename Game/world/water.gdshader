// Flat water with a grid drawn in world coordinates, so that speed and heading show.
// Phase 5 replaces this with the wave surface.
shader_type spatial;

uniform vec3 deep_color : source_color = vec3(0.03, 0.22, 0.38);
uniform vec3 line_color : source_color = vec3(0.6, 0.8, 0.9);
uniform float cell_m = 5.0;
uniform float major_every = 5.0;
uniform float line_width_m = 0.08;
uniform float fade_distance_m = 300.0;

varying vec3 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float grid_line(vec2 p, float cell, float width) {
	vec2 to_line = abs(fract(p / cell - 0.5) - 0.5) * cell;
	float d = min(to_line.x, to_line.y);
	float soft = fwidth(d) + 0.001;
	return 1.0 - smoothstep(width * 0.5, width * 0.5 + soft, d);
}

void fragment() {
	float minor = grid_line(world_position.xz, cell_m, line_width_m);
	float major = grid_line(world_position.xz, cell_m * major_every, line_width_m * 2.5);
	float distance_fade = clamp(1.0 - length(world_position - CAMERA_POSITION_WORLD) / fade_distance_m, 0.0, 1.0);
	float lines = max(minor * 0.45, major * 0.8) * distance_fade;
	ALBEDO = mix(deep_color, line_color, lines);
	ROUGHNESS = 0.12;
	METALLIC = 0.0;
	SPECULAR = 0.6;
}
