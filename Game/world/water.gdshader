// The water: the same Gerstner waves as res://sim/wave_field.gd (plan decision D5), with the
// displacement of PHYSICS_SPEC.md 9.4 and the exact normal of 9.6a in the vertex stage, so
// the board floats on exactly the surface you see. Change one, change the other: the wave
// formulas are in res://world/gerstner.gdshaderinc, shared with the wake behind the board.
//
// One shader for every water in the game, the open sea and a map's lake. Each scene hands
// it a look: a material with only the colours and the ripples (res://world/sea_water.tres,
// res://maps/silvaplana/lake_water.tres). The look comes from the map's lake shader
// (Documentation/PHYSICS_REQUESTS_FROM_MAP.md, R9), now on top of the waves:
//   1. You see into the water, and it swallows light with depth: red first, then green, so
//      shallow water shows the bottom and deep water turns blue (Beer-Lambert: what gets
//      through after d metres is exp(-absorption x d)). The depth comes from what lies behind
//      the water on the screen: a map's lakebed, the fin and the hull under the surface. On
//      the open sea only sky lies behind it: no bottom, so the water's own colour.
//   2. It bends what lies under it (refraction): the picture behind the water is read a
//      little off to the side, by how much the ripples tilt the surface.
//   3. It mirrors the sky, little when you look straight down (2 %) and almost fully at a
//      glancing angle (Fresnel). Godot's own lighting draws that mirror and the sun's glints.
//   4. Small wind ripples, drifting downwind, tilt the wave's surface: they break up the
//      mirror and catch the sun. They only change the shading and never move the surface.
//   5. Foam on the steepest crests, and an optional grid for speed on flat water.
//
// The mesh this runs on must only be translated (never rotated or scaled): the vertex
// positions are taken as world rest positions and the normal is written as a world normal.
// The node is placed at the still-water height, so VERTEX.y is the wave's height above it.
//
// It reads the screen, so Godot draws it with the see-through things, which do not block
// each other. It writes its depth, so whatever comes after it (the sail, spray, the wake) is
// hidden behind a wave and under the surface, and the scene draws it first (render_priority
// -1 on the material, ocean.gd): otherwise a big water plane sorted after the see-through
// sail would paint over it.
shader_type spatial;
render_mode cull_back, depth_draw_always;

#include "res://world/gerstner.gdshaderinc"

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap, repeat_disable;
uniform sampler2D depth_texture : hint_depth_texture, filter_nearest, repeat_disable;
// A seamless normal map of small bumps (a NoiseTexture2D as a normal map), for the ripples.
// Without one the surface has no ripples.
uniform sampler2D ripple_normals : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;

// The colour the water itself sends back where it is too deep to see the bottom, and a
// lighter one toward the wave crests (thinner water over the light scattered up), mixed in
// by this much.
uniform vec3 deep_color : source_color = vec3(0.02, 0.13, 0.26);
uniform vec3 shallow_color : source_color = vec3(0.05, 0.36, 0.44);
uniform float crest_lightening : hint_range(0.0, 1.0) = 0.6;
// How much of the light the water swallows per metre, for red, green and blue.
uniform vec3 absorption_per_m = vec3(0.45, 0.07, 0.035);
// Where only sky lies behind the water (the open sea), the view is taken to go this deep.
uniform float no_bottom_depth_m = 200.0;
// How far the picture under the water is moved by the ripples, as a share of the screen.
uniform float refraction_strength = 0.03;
// The ripples: their size in metres, how strongly they tilt the surface (the wind's
// strength; ocean.gd raises it with the wind), the direction they drift (downwind, on the
// water: x east, y south) and how fast, and the distance over which they fade (far away the
// surface looks smooth).
uniform float ripple_size_m = 7.0;
uniform float ripple_strength : hint_range(0.0, 2.0) = 0.7;
uniform vec2 ripple_drift_direction = vec2(1.0, 0.0);
uniform float ripple_speed_ms = 0.8;
uniform float ripple_fade_m = 1500.0;
// Gust patches (a hook for a map's wind that differs from place to place): a picture of the
// wind over an area of the water, x0, z0, width and depth in metres (width 0 = none). Its red
// channel is the ripple strength there divided by two: 0.5 is the normal strength, 1.0 a
// gust with twice the ripples (darker, rougher water), 0 a calm patch.
uniform sampler2D wind_ripple_map : hint_default_white, filter_linear, repeat_disable;
uniform vec4 wind_ripple_map_area = vec4(0.0);
// How rough the mirror is near by, and far away. Far away the ripples are smaller than a
// pixel: they no longer show as bumps, but they still scatter the mirror, so the surface gets
// rougher (otherwise far water turns into a flat mirror of the pale horizon).
uniform float roughness_value : hint_range(0.0, 1.0) = 0.05;
uniform float roughness_far : hint_range(0.0, 1.0) = 0.22;
uniform float roughness_far_m = 2000.0;
// A thin light line where the water meets the shore (or a hull), this deep and this strong.
uniform float shore_line_depth_m = 0.15;
uniform float shore_line_strength : hint_range(0.0, 1.0) = 0.0;

uniform vec3 foam_color : source_color = vec3(0.93, 0.96, 0.98);
// Foam appears where the local steepness (the sum of steepness x sin(phase), which is the
// slope of the surface at a crest) is above this: real waves whitecap from a steepness of
// about 0.3 and break at 0.44, so a gentle swell shows no foam at all.
uniform float foam_threshold = 0.3;
// A faint grid in world coordinates so that speed and heading show on flat water.
uniform vec3 line_color : source_color = vec3(0.6, 0.8, 0.9);
uniform float grid_strength = 0.12;
uniform float cell_m = 5.0;
uniform float line_width_m = 0.08;
uniform float grid_fade_distance_m = 120.0;

varying vec3 world_position;
varying float crest_factor;  // -1 in a trough to +1 on a crest
varying float crest_steepness;  // the sum of steepness x sin(phase): the surface slope at a crest

void vertex() {
	vec2 rest = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
	vec3 displacement;
	vec3 tangent_x;
	vec3 tangent_z;
	float crest;
	float total_steepness;
	wave_surface(rest, displacement, tangent_x, tangent_z, crest, total_steepness);
	VERTEX = VERTEX + displacement;
	NORMAL = normalize(cross(tangent_z, tangent_x));
	// The ripples' normal map tilts this wave normal, so Godot needs the wave's own surface
	// directions too. On flat water these are a plane's: tangent +x, binormal -z.
	TANGENT = normalize(tangent_x);
	BINORMAL = -normalize(tangent_z);
	crest_factor = total_steepness > 0.0 ? crest / total_steepness : -1.0;
	crest_steepness = crest;
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

// The world position of what lies behind the water at a screen point, from the depth buffer
// (Forward+, Godot 4.3 and later: Vulkan-style depth from 0 to 1, reversed, so the sky is at
// 0). Where only sky lies behind (the open sea) it returns a point no_bottom_depth_m down.
vec3 bed_behind(vec2 screen_uv, vec3 surface, mat4 inv_projection, mat4 inv_view) {
	float raw = texture(depth_texture, screen_uv).r;
	if (raw <= 0.0) {
		return surface - vec3(0.0, no_bottom_depth_m, 0.0);
	}
	vec4 view = inv_projection * vec4(screen_uv * 2.0 - 1.0, raw, 1.0);
	view.xyz /= view.w;
	return (inv_view * vec4(view.xyz, 1.0)).xyz;
}

// One layer of ripples: the normal map, stretched along the crests (wind ripples are longer
// than they are wide), drifting downwind.
vec3 ripple_layer(vec2 position, float size_m, float speed_ms, vec2 along, float time_s) {
	vec2 across = vec2(-along.y, along.x);
	vec2 local = vec2(dot(position, along), dot(position, across) * 0.5);
	vec2 uv = (local - vec2(speed_ms * time_s, 0.0)) / size_m;
	return texture(ripple_normals, uv).rgb;
}

// How strong the wind's ripples are here, from the gust picture (1 without one).
float wind_ripple_factor(vec2 position) {
	if (wind_ripple_map_area.z <= 0.0 || wind_ripple_map_area.w <= 0.0) {
		return 1.0;
	}
	vec2 uv = (position - wind_ripple_map_area.xy) / wind_ripple_map_area.zw;
	return 2.0 * texture(wind_ripple_map, uv).r;
}

float grid_line(vec2 p, float cell, float width) {
	vec2 to_line = abs(fract(p / cell - 0.5) - 0.5) * cell;
	float d = min(to_line.x, to_line.y);
	float soft = fwidth(d) + 0.001;
	return 1.0 - smoothstep(width * 0.5, width * 0.5 + soft, d);
}

void fragment() {
	float distance_m = length(VERTEX);
	float near = clamp(1.0 - distance_m / ripple_fade_m, 0.0, 1.0);
	float wind = wind_ripple_factor(world_position.xz);

	// 4. Two layers of ripples, a big and a small one, at slightly different angles. They
	// drift on the engine's clock: they are only a look, and keep moving in the menus.
	vec2 along = normalize(ripple_drift_direction + vec2(1e-6, 0.0));
	vec3 big = ripple_layer(world_position.xz, ripple_size_m, ripple_speed_ms, along, TIME);
	vec3 small = ripple_layer(world_position.xz, ripple_size_m * 0.35, ripple_speed_ms * 0.6,
		normalize(along + vec2(-along.y, along.x) * 0.4), TIME);
	vec3 ripple = normalize(big + small - 1.0);
	NORMAL_MAP = ripple * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = ripple_strength * wind * near;

	// 1. How much water the view passes through before it reaches what lies behind it.
	vec3 bed = bed_behind(SCREEN_UV, world_position, INV_PROJECTION_MATRIX, INV_VIEW_MATRIX);
	float straight_path_m = length(bed - world_position);

	// 2. Look a little to the side, more where the water is deeper (no bending at the edge).
	vec2 bent_uv = SCREEN_UV + ripple.xy * refraction_strength * near * clamp(straight_path_m / 3.0, 0.0, 1.0);
	vec3 bent_bed = bed_behind(bent_uv, world_position, INV_PROJECTION_MATRIX, INV_VIEW_MATRIX);
	if (bent_bed.y > world_position.y) {
		// The bent look would land on something above the water (the shore, the board): don't bend.
		bent_uv = SCREEN_UV;
		bent_bed = bed;
	}
	float path_m = length(bent_bed - world_position);
	vec3 through = exp(-absorption_per_m * path_m);
	vec3 bed_color = textureLod(screen_texture, bent_uv, 0.0).rgb;

	// 3. The share that is mirrored (Schlick's Fresnel, 2 % straight down for water); the rest
	// comes out of the water: what lies under it seen through it, and the water's own colour.
	float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float mirrored = 0.02 + 0.98 * pow(1.0 - facing, 5.0);
	vec3 own_color = mix(deep_color, shallow_color, clamp(0.5 + 0.5 * crest_factor, 0.0, 1.0) * crest_lightening);
	float shore = (1.0 - smoothstep(0.0, shore_line_depth_m, world_position.y - bed.y)) * shore_line_strength;
	vec3 albedo = mix(own_color * (vec3(1.0) - through), vec3(0.9), shore) * (1.0 - mirrored);
	vec3 emission = bed_color * through * (1.0 - shore) * (1.0 - mirrored);

	// 5. Foam on the steep crests covers the rest; the grid lines lie on top.
	float foam = smoothstep(foam_threshold, foam_threshold + 0.15, crest_steepness) * 0.7;
	albedo = mix(albedo, foam_color, foam);
	emission *= 1.0 - foam;
	float distance_fade = clamp(1.0 - distance_m / grid_fade_distance_m, 0.0, 1.0);
	float lines = grid_line(world_position.xz, cell_m, line_width_m) * distance_fade * grid_strength;

	ALBEDO = mix(albedo, line_color, lines);
	EMISSION = emission * (1.0 - lines);
	float roughness = mix(roughness_value, roughness_far, smoothstep(0.0, roughness_far_m, distance_m));
	// A gust's rougher water mirrors the bright sky less: it looks darker.
	roughness *= mix(1.0, wind, 0.5);
	ROUGHNESS = clamp(mix(roughness, 0.5, foam), 0.0, 1.0);
	METALLIC = 0.0;
	// Godot's mirror strength: 0.25 gives water's 2 % reflection straight on.
	SPECULAR = 0.25;
}
