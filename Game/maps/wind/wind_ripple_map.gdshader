// The gust picture for the water (MAP_SILVAPLANA_PLAN.md W5; PHYSICS_REQUESTS_FROM_MAP.md R9): the
// map's wind over an area, drawn into a small texture that the game's water shader reads as its
// wind_ripple_map. Red is the strength of the ripples there divided by two: the wind there
// relative to the lake's mean of the moment (to the power `contrast`), so 0.5 is the lake's normal
// ripples, a gust 20 % stronger than the mean gives 0.72 (more, darker ripples), a lull or the lee
// less.
// The wind is wind_at() of wind_pattern.gdshaderinc, the same sums as MapWind.velocity_in() in
// GDScript, so the patches on the water are where the physics feels the gusts (WD1).
shader_type canvas_item;

#include "res://maps/wind/wind_pattern.gdshaderinc"

// The area the texture covers in the game: x and z of its north-west corner, its width and depth (m).
uniform vec4 area_m = vec4(0.0, 0.0, 1.0, 1.0);
// How strongly the ripples follow the wind: ripples = (wind / lake mean) ^ contrast. 1 would be
// in proportion to the wind (as the map's satellite roughness was read, satellite_wind.py); the
// smallest ripples, which make a gust look dark, grow faster than the wind, and in the game's
// water the ripples only tilt the surface, so with 1 the patches were hard to see. 2 is set by eye.
uniform float contrast = 2.0;

void fragment() {
	vec2 xz = area_m.xy + UV * area_m.zw;
	float ratio = length(wind_at(xz)) / max(lake_speed_ms, 0.1);
	float ripples = pow(max(ratio, 0.0), contrast);
	COLOR = vec4(clamp(ripples / 2.0, 0.0, 1.0), 0.0, 0.0, 1.0);
}
