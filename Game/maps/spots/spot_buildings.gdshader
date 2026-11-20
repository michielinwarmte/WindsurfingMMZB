// A spot's buildings (SpotBuildings): white walls with rows of windows, light roofs, tents in plain
// white fabric. The mesh's UV is in metres (along the wall, up from its foot) and its colour says
// what a face is: red 1 = a wall, green 1 = a tent.
shader_type spatial;
render_mode cull_disabled;

uniform vec3 wall_color : source_color = vec3(0.93, 0.91, 0.86);
uniform vec3 roof_color : source_color = vec3(0.78, 0.74, 0.68);
uniform vec3 window_color : source_color = vec3(0.16, 0.2, 0.24);
uniform vec3 tent_color : source_color = vec3(0.97, 0.97, 0.96);
// One window every window_spacing_m along a wall, one row a floor.
uniform float window_spacing_m = 3.2;
uniform float floor_m = 3.0;

void fragment() {
	bool is_wall = COLOR.r > 0.5;
	bool is_tent = COLOR.g > 0.5;
	vec3 color = is_wall ? wall_color : roof_color;
	float roughness = 0.9;
	if (is_tent) {
		color = tent_color;
	} else if (is_wall) {
		vec2 cell = fract(UV / vec2(window_spacing_m, floor_m));
		// No windows at the very foot of the wall (the ground floor's plinth).
		bool window = cell.x > 0.22 && cell.x < 0.78 && cell.y > 0.28 && cell.y < 0.78 && UV.y > 0.9;
		if (window) {
			color = window_color;
			roughness = 0.15;
		}
	}
	ALBEDO = color;
	ROUGHNESS = roughness;
}
