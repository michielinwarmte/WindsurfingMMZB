// Lake water for a map (Documentation/MAP_SILVAPLANA_PLAN.md, M2): water you can see into.
//
// What makes it look like water, and how this shader does each part:
//   1. You see into it, and it swallows light with depth: red first, then green, so the shallows
//      show the lakebed and deep water turns blue-green (Beer-Lambert: what gets through after
//      d metres is exp(-absorption x d)). The depth comes from the scene behind the water: the
//      map's lakebed is real terrain, so the shallows come out by themselves.
//   2. It bends what lies under it (refraction): the picture behind the water is read a little
//      off to the side, by how much the ripples tilt the surface.
//   3. It mirrors the sky, little when you look straight down (2 %) and almost fully at a
//      glancing angle (Fresnel). Godot's own lighting draws that mirror and the sun's glints.
//   4. Small wind ripples, drifting downwind, tilt the surface: they break up the mirror and
//      catch the sun.
//
// A look only. The physics floats on the waves of res://world/water.gdshader (the physics
// track's); these ripples only change the shading and never move the surface.
//
// The mesh must lie flat at the water level (a plane, only moved, never rotated).
shader_type spatial;
render_mode cull_back;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap, repeat_disable;
uniform sampler2D depth_texture : hint_depth_texture, filter_nearest, repeat_disable;
// A seamless normal map of small bumps (a NoiseTexture2D as a normal map), used for the ripples.
uniform sampler2D ripple_normals : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;

// How much of the light the water swallows per metre, for red, green and blue.
uniform vec3 absorption_per_m = vec3(0.40, 0.10, 0.08);
// The colour the water itself sends back: what you see where it is too deep to see the bottom.
uniform vec3 deep_color : source_color = vec3(0.05, 0.22, 0.28);
// How far the picture under the water is moved by the ripples, as a share of the screen.
uniform float refraction_strength = 0.03;
// The ripples: their size in metres, how strongly they tilt the surface, the direction they
// drift (downwind, on the water: x east, y south) and how fast, and the distance over which
// they fade (far away the surface looks smooth).
uniform float ripple_size_m = 7.0;
uniform float ripple_strength : hint_range(0.0, 2.0) = 0.7;
uniform vec2 ripple_drift_direction = vec2(0.9, -0.44);
uniform float ripple_speed_ms = 0.8;
uniform float ripple_fade_m = 1500.0;
// How rough the mirror is near by, and far away. Far away the ripples are smaller than a pixel:
// they no longer show as bumps, but they still scatter the mirror, so the surface gets rougher
// (otherwise far water turns into a flat mirror of the pale horizon).
uniform float roughness_value : hint_range(0.0, 1.0) = 0.05;
uniform float roughness_far : hint_range(0.0, 1.0) = 0.22;
uniform float roughness_far_m = 2000.0;
// A thin light line where the water meets the shore, this deep and this strong.
uniform float shore_line_depth_m = 0.15;
uniform float shore_line_strength : hint_range(0.0, 1.0) = 0.35;

varying vec3 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

// The world position of what is drawn at a screen point, from the depth buffer (Forward+:
// Vulkan-style depth from 0 to 1, reversed, so the sky is at 0).
vec3 world_from_depth(vec2 screen_uv, mat4 inv_projection, mat4 inv_view) {
	float raw = texture(depth_texture, screen_uv).r;
	vec4 view = inv_projection * vec4(screen_uv * 2.0 - 1.0, raw, 1.0);
	view.xyz /= view.w;
	return (inv_view * vec4(view.xyz, 1.0)).xyz;
}

// One layer of ripples: the normal map, stretched along the crests (wind ripples are longer
// than they are wide), drifting downwind.
vec3 ripple_layer(vec2 position, float size_m, float speed_ms, vec2 along) {
	vec2 across = vec2(-along.y, along.x);
	vec2 local = vec2(dot(position, along), dot(position, across) * 0.5);
	vec2 uv = (local - vec2(speed_ms * TIME, 0.0)) / size_m;
	return texture(ripple_normals, uv).rgb;
}

void fragment() {
	float distance_m = length(VERTEX);
	float near = clamp(1.0 - distance_m / ripple_fade_m, 0.0, 1.0);
	vec2 along = normalize(ripple_drift_direction);

	// 4. Two layers of ripples, a big and a small one, at slightly different angles.
	vec3 big = ripple_layer(world_position.xz, ripple_size_m, ripple_speed_ms, along);
	vec3 small = ripple_layer(world_position.xz, ripple_size_m * 0.35, ripple_speed_ms * 0.6,
		normalize(along + vec2(-along.y, along.x) * 0.4));
	vec3 ripple = normalize((big + small) * 0.5 * 2.0 - 1.0);
	NORMAL_MAP = ripple * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = ripple_strength * near;

	// 1. How much water the view passes through before it reaches the lakebed.
	vec3 bed = world_from_depth(SCREEN_UV, INV_PROJECTION_MATRIX, INV_VIEW_MATRIX);
	float straight_path_m = length(bed - world_position);

	// 2. Look a little to the side, more where the water is deeper (no bending at the very edge).
	vec2 bent_uv = SCREEN_UV + ripple.xy * refraction_strength * near * clamp(straight_path_m / 3.0, 0.0, 1.0);
	vec3 bent_bed = world_from_depth(bent_uv, INV_PROJECTION_MATRIX, INV_VIEW_MATRIX);
	if (bent_bed.y > world_position.y) {
		// The bent look would land on something above the water (the shore, the board): don't bend.
		bent_uv = SCREEN_UV;
		bent_bed = bed;
	}
	float path_m = length(bent_bed - world_position);
	vec3 through = exp(-absorption_per_m * path_m);
	vec3 bed_color = textureLod(screen_texture, bent_uv, 0.0).rgb;

	// 3. The share that is mirrored (Schlick's Fresnel, 2 % straight down for water); the rest
	// is what comes out of the water: the lakebed seen through it, and the water's own colour.
	float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float mirrored = 0.02 + 0.98 * pow(1.0 - facing, 5.0);
	float shore = (1.0 - smoothstep(0.0, shore_line_depth_m, world_position.y - bed.y)) * shore_line_strength;

	ALBEDO = mix(deep_color * (vec3(1.0) - through), vec3(0.9), shore) * (1.0 - mirrored);
	EMISSION = bed_color * through * (1.0 - shore) * (1.0 - mirrored);
	ROUGHNESS = mix(roughness_value, roughness_far, smoothstep(0.0, roughness_far_m, distance_m));
	METALLIC = 0.0;
	// Godot's mirror strength: 0.25 gives water's 2 % reflection straight on.
	SPECULAR = 0.25;
}
