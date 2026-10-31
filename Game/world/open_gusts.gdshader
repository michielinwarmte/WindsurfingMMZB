// The gust picture for the open water (ROADMAP GR2 and PH7): the wind's patches over an area
// around the board, drawn into a small texture every frame that the water shader reads as its
// wind_ripple_map (the same hook as the lake's WindRippleMap). Red is the strength of the ripples
// there divided by two: the wind relative to the mean, to the power `contrast`, so 0.5 is the
// mean's ripples, a gust 20 % stronger than the mean gives 0.72 (more, darker ripples), a lull less.
// The patches are wind_gusts_at() of wind_pattern.gdshaderinc, the same sums and random numbers as
// WindGusts.gusts_at() in GDScript, so the patches on the water are where the physics feels them
// (WindField.patch_unit_at(); main.gd --check-gusts=1 compares the two).
shader_type canvas_item;

#include "res://maps/wind/wind_pattern.gdshaderinc"

// The area the texture covers in the game: x and z of its north-west corner, its width and depth (m).
uniform vec4 area_m = vec4(0.0, 0.0, 1.0, 1.0);
// The patches' spread as a share of the mean wind (WindField.patch_spread_share()).
uniform float spread_share = 0.1;
// How strongly the ripples follow the wind: ripples = (wind / mean) ^ contrast. The lake's 2, set
// by eye there: the smallest ripples, which make a gust look dark, grow faster than the wind.
uniform float contrast = 2.0;

// WindField._in_the_patches(): the wind over a point relative to the mean. Of the include's
// uniforms, lake_axis is the direction the air moves in, travel_m how far it has come and
// time_of_day_s the field's time; the pattern, the lee and the pulses are not used.
float wind_ratio_at(vec2 xz) {
	float along_m = dot(xz, lake_axis);
	float across_m = dot(xz, vec2(-lake_axis.y, lake_axis.x));
	vec2 unit = wind_gusts_at(along_m - travel_m, across_m);
	float along = max(1.0 + unit.x * spread_share, 0.05);
	float side = unit.y * spread_share * gust_sideways_share;
	return length(vec2(along, side));
}

void fragment() {
	vec2 xz = area_m.xy + UV * area_m.zw;
	float ripples = pow(wind_ratio_at(xz), contrast);
	COLOR = vec4(clamp(ripples / 2.0, 0.0, 1.0), 0.0, 0.0, 1.0);
}
