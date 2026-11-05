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

// Green: the wind here relative to the lake's mean over the last `recent_s` seconds, divided by two,
// for the lake's short wave train (PHYSICS_SPEC.md 9.17), which takes that long to follow the wind.
// The average weighs the past as e^(-s / recent_s) (a first-order lag). The gusts roll down the lake
// with the air at drift_ms and change only over minutes, so the wind here s seconds ago is the wind
// now drift_ms x s further downwind ("frozen turbulence"); the average is taken at three such points
// by the three-point Gauss-Laguerre rule (nodes and weights from any table of that rule). 0 seconds:
// green is the wind of the moment.
uniform float recent_s = 0.0;
const vec3 LAGUERRE_NODES = vec3(0.415775, 2.294280, 6.289945);
const vec3 LAGUERRE_WEIGHTS = vec3(0.711093, 0.278518, 0.0103893);

float wind_ratio_at(vec2 xz) {
	return length(wind_at(xz)) / max(lake_speed_ms, 0.1);
}

void fragment() {
	vec2 xz = area_m.xy + UV * area_m.zw;
	float ratio = wind_ratio_at(xz);
	float ripples = pow(max(ratio, 0.0), contrast);
	float recent = ratio;
	if (recent_s > 0.0) {
		vec2 back = lake_axis * drift_ms * recent_s;
		recent = LAGUERRE_WEIGHTS.x * wind_ratio_at(xz + back * LAGUERRE_NODES.x)
			+ LAGUERRE_WEIGHTS.y * wind_ratio_at(xz + back * LAGUERRE_NODES.y)
			+ LAGUERRE_WEIGHTS.z * wind_ratio_at(xz + back * LAGUERRE_NODES.z);
	}
	COLOR = vec4(clamp(ripples / 2.0, 0.0, 1.0), clamp(recent / 2.0, 0.0, 1.0), 0.0, 1.0);
}
