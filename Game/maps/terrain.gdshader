// The terrain of a map (Documentation/MAP_SILVAPLANA_PLAN.md, M2): the aerial photo as the colour.
//
// The photo already has light in it: the sun of the flight made bright and dark slopes and
// shadows. Lit again by the game's sun from another direction, the slopes would get two kinds of
// light at once. So the game's sun only adds part of its usual light and shade (sun_shading),
// and the photo's own light does the rest. Cast shadows (from the mountains) stay full.
shader_type spatial;
render_mode cull_back;

uniform sampler2D photo : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
// How much darker a vertical cliff is than flat ground, so the mountains don't look flat when the
// sun is high (0 = no darkening).
uniform float slope_darkening : hint_range(0.0, 1.0) = 0.25;
// How much the game's sun shades the slopes: 0 = evenly lit (only the photo's light),
// 1 = as any other object.
uniform float sun_shading : hint_range(0.0, 1.0) = 0.5;

varying float flatness;

void vertex() {
	// The terrain meshes have no rotation, so their normal is already the world normal: 1 on flat
	// ground, 0 on a vertical wall.
	flatness = clamp(NORMAL.y, 0.0, 1.0);
}

void fragment() {
	vec3 color = texture(photo, UV).rgb;
	ALBEDO = color * mix(1.0 - slope_darkening, 1.0, flatness);
	ROUGHNESS = 0.95;
	SPECULAR = 0.2;
}

void light() {
	// Lambert's law (light ~ the cosine of the angle to the sun), blended with even light.
	float facing = clamp(dot(NORMAL, LIGHT), 0.0, 1.0);
	DIFFUSE_LIGHT += mix(1.0, facing, sun_shading) * ATTENUATION * LIGHT_COLOR / PI;
}
