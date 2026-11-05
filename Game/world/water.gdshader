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
// How a gust looks (GR2): a gust's small ripples tilt the surface away from the bright horizon
// sky toward the darker zenith and scatter the sky's mirror image, so a sailor sees a gust as
// a darker, matt patch coming down the water, and a lull as a pale, glassy one. The ripple
// factor from the picture (1 at the mean wind) is turned into a gust from -1 (a deep lull) to
// 1 (a full gust) by gust_look_contrast (3: a gust with 1.33 times the mean's ripples is full);
// gust_darkening is how much darker a full gust is, gust_glassiness how much more mirror a full
// lull has.
uniform float gust_look_contrast = 3.0;
uniform float gust_darkening : hint_range(0.0, 1.0) = 0.4;
uniform float gust_glassiness : hint_range(0.0, 2.0) = 0.6;
// The mirror's roughness in a full gust. At a grazing angle water mirrors the sky whatever its
// strength (Fresnel), so far away only a rougher mirror, which blurs the bright horizon sky into
// the darker sky above, makes a gust show as a darker patch.
uniform float gust_roughness : hint_range(0.0, 1.0) = 0.35;
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
// A lake's own waves (PHYSICS_SPEC.md 9.17; lake_waves_on and the grid are in gerstner.gdshaderinc).
// Only the trains the physics floats on (lake_shape_trains) move the surface, so the board floats on
// exactly the shape you see. The near mesh shows such a train as shape where its cells are small
// enough for it (OceanNode's lake mesh: 0.25 m cells near the camera, doubling outward): train i keeps
// its full shape out to 0.45 x lake_lod_reach x its wavelength from lake_lod_centre (the camera's x
// and z) and none from 0.85 x that on. Every pixel then draws every train's slope (its exact Gerstner
// normal at the pixel's rest point; the shorter trains the physics does not ride as slope only),
// faded out where a wavelength covers fewer than 3 to 6 pixels; the slopes faded out roughen the
// mirror instead. The far plane (lake_displace off) shows them all as slope only.
uniform bool lake_displace = true;
uniform vec2 lake_lod_centre = vec2(0.0);
uniform float lake_lod_height_m = 0.0;
uniform float lake_lod_reach = 20.0;
// The picture's own shorter train (the physics never sees it): (direction x, direction z, phase,
// wavelength), and per node (texelFetch, as lake_envelope) R its amplitude, G how much it grows with
// the wind (d ln A / d ln U at the node), B Hs and A Tp.
uniform vec4 lake_look_band = vec4(0.0, -1.0, 0.0, 0.5);
uniform sampler2D lake_look_data : filter_nearest, repeat_disable;

// A faint grid in world coordinates so that speed and heading show on flat water.
uniform vec3 line_color : source_color = vec3(0.6, 0.8, 0.9);
uniform float grid_strength = 0.12;
uniform float cell_m = 5.0;
uniform float line_width_m = 0.08;
uniform float grid_fade_distance_m = 120.0;

varying vec3 world_position;
varying float crest_factor;  // -1 in a trough to +1 on a crest
varying float crest_steepness;  // the sum of steepness x sin(phase): the surface slope at a crest
varying vec2 rest_xz;  // the rest point of what is drawn here (the lake's per-pixel slopes)

// How much of each lake train the mesh shows as shape at a rest point (see lake_displace).
vec4 lake_shape_weights(vec2 rest) {
	if (!lake_displace) {
		return vec4(0.0);
	}
	vec2 off = abs(rest - lake_lod_centre);
	float reach_m = max(max(off.x, off.y), lake_lod_height_m);
	vec4 lengths = vec4(wave_a.w, wave_b.w, wave_c.w, wave_d.w) * lake_lod_reach;
	return (vec4(1.0) - smoothstep(0.45 * lengths, 0.85 * lengths, vec4(reach_m))) * lake_shape_mask();
}

void vertex() {
	vec2 rest = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
	rest_xz = rest;
	vec3 displacement;
	vec3 tangent_x;
	vec3 tangent_z;
	float crest;
	float total_steepness;
	if (lake_waves_on) {
		lake_wave_surface(rest, lake_shape_weights(rest), displacement, tangent_x, tangent_z, crest, total_steepness);
	} else {
		wave_surface(rest, displacement, tangent_x, tangent_z, crest, total_steepness);
	}
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
// than they are wide), drifting downwind. Returns the unpacked normal in the water's own frame
// (x along TANGENT, the world's +x; y along BINORMAL, the world's -z).
// The map's tilt is turned with the pattern: its x tilts toward rising u (here downwind), its y
// toward falling v (here against `across`), and the stretch halves the slope across. Without the
// turn the pattern drifted downwind but its slopes, which make the light and the sky's mirror,
// kept the map's own axes: right only for a wind from the West (the default), 90 degrees off for
// a wind from the North or the South (Max's play-test, ROADMAP GR8).
vec3 ripple_layer(vec2 position, float size_m, float speed_ms, vec2 along, float time_s) {
	vec2 across = vec2(-along.y, along.x);
	vec2 local = vec2(dot(position, along), dot(position, across) * 0.5);
	vec2 uv = (local - vec2(speed_ms * time_s, 0.0)) / size_m;
	vec3 n = texture(ripple_normals, uv).rgb * 2.0 - 1.0;
	vec2 tilt = n.x * along - 0.5 * n.y * across;
	return vec3(tilt.x, -tilt.y, n.z);
}

// How strong the wind's ripples are here, from the gust picture (1 without one).
float wind_ripple_factor(vec2 position) {
	if (wind_ripple_map_area.z <= 0.0 || wind_ripple_map_area.w <= 0.0) {
		return 1.0;
	}
	vec2 uv = (position - wind_ripple_map_area.xy) / wind_ripple_map_area.zw;
	return 2.0 * texture(wind_ripple_map, uv).r;
}

// The wind here relative to the lake's mean, averaged over the last few tens of seconds (the gust
// picture's green channel, WindRippleMap; 1 without one): what the short train answers to.
float wind_recent_ratio(vec2 position) {
	if (wind_ripple_map_area.z <= 0.0 || wind_ripple_map_area.w <= 0.0) {
		return 1.0;
	}
	vec2 uv = (position - wind_ripple_map_area.xy) / wind_ripple_map_area.zw;
	return 2.0 * texture(wind_ripple_map, uv).g;
}

// A train the picture shows as shading only (the physics does not ride it), as three short-crested
// parts that share its energy (each a / sqrt(3)): turned 26 degrees either way and stretched over
// its octave (x 1.14, 1, 0.88), each with its own phase. Real short wind waves spread about 40
// degrees either side of the wind at 1.6 times the peak frequency (Donelan-Banner spreading, as
// Horvath 2015 gives it; the research, 4.1), so one long-crested train looks like brushed metal. The
// parts' turn and stretch are a choice for the look, within that spread. Adds the parts' slopes to
// the tangents (as a height field) and the mean square slope of what the pixels cannot show to
// `faded_slope2`.
const vec3 SHADING_TURNS_RAD = vec3(-0.45, 0.0, 0.45);
const vec3 SHADING_STRETCH = vec3(1.14, 1.0, 0.88);
const vec3 SHADING_PHASES = vec3(1.7, 0.0, 4.1);

void lake_shading_train(vec4 wave, float amplitude, float pixel_m, vec2 rest, inout vec3 tangent_x, inout vec3 tangent_z, inout float faded_slope2) {
	if (amplitude <= 0.0) {
		return;
	}
	float part_a = amplitude * 0.57735;
	for (int j = 0; j < 3; j++) {
		float turn_c = cos(SHADING_TURNS_RAD[j]);
		float turn_s = sin(SHADING_TURNS_RAD[j]);
		vec2 d = vec2(wave.x * turn_c - wave.y * turn_s, wave.x * turn_s + wave.y * turn_c);
		float length_m = wave.w * SHADING_STRETCH[j];
		float k = 2.0 * PI / length_m;
		float shown = 1.0 - smoothstep(length_m / 6.0, length_m / 3.0, pixel_m);
		float phase = k * dot(d, rest) - wave_omega(k) * water_time_s + wave.z + SHADING_PHASES[j];
		float slope = part_a * k * cos(phase) * shown;
		tangent_x.y += slope * d.x;
		tangent_z.y += slope * d.y;
		faded_slope2 += 0.5 * (1.0 - shown) * (part_a * k) * (part_a * k);
	}
}

// How much of each train a pixel shades exactly (the rest short-crested): all of it within two
// wavelengths of the camera, none from six on (counting the camera's height), smoothly, and none for
// the trains the physics does not ride. That is the water round the board seen from the follow
// camera, where the shading must match the shape the board pitches on. Farther out and from high up
// a regular train shows as stripes far more than the same energy short-crested does, so there the
// shading is short-crested (an edge of a wider exact zone showed as an arc on the water from 45 m up).
vec4 lake_pixel_exact(vec2 rest) {
	if (!lake_displace) {
		return vec4(0.0);
	}
	float reach_m = max(length(rest - lake_lod_centre), lake_lod_height_m);
	vec4 lengths = vec4(wave_a.w, wave_b.w, wave_c.w, wave_d.w);
	return (vec4(1.0) - smoothstep(2.0 * lengths, 6.0 * lengths, vec4(reach_m))) * lake_shape_mask();
}

// The lake's surface at a pixel: near the camera, where the board floats on them, the exact Gerstner
// tangents of the trains the physics rides at the pixel's rest point, faded where a wavelength
// covers too few pixels; elsewhere (farther out, from high up, on the far water) and for the trains
// the physics does not ride, short-crested shading (lake_shading_train()), so few long trains do not
// show as regular stripes from afar. The two are blended by the square roots of the exact share
// (lake_pixel_exact()), which keeps the slopes' energy. The picture's short train (raised by the
// recent wind) as shading too. `faded_slope2` gets the mean square slope of what was faded out.
void lake_pixel_surface(vec2 rest, float pixel_m, out vec3 tangent_x, out vec3 tangent_z, out float crest, out float total_steepness, out float faded_slope2) {
	vec4 lengths = vec4(wave_a.w, wave_b.w, wave_c.w, wave_d.w);
	vec4 shown = vec4(1.0) - smoothstep(lengths / 6.0, lengths / 3.0, vec4(pixel_m));
	vec4 near_shape = lake_pixel_exact(rest);
	vec3 displacement;
	lake_wave_surface(rest, shown * sqrt(near_shape), displacement, tangent_x, tangent_z, crest, total_steepness);
	vec4 amplitudes = lake_amplitudes(rest);
	vec4 slopes = amplitudes * 2.0 * PI / lengths;
	faded_slope2 = dot((vec4(1.0) - shown) * near_shape * slopes * slopes, vec4(0.5));
	vec4 waves[4] = vec4[](wave_a, wave_b, wave_c, wave_d);
	vec4 elsewhere = sqrt(max(vec4(1.0) - near_shape, vec4(0.0)));
	for (int i = 0; i < 4; i++) {
		lake_shading_train(waves[i], amplitudes[i] * elsewhere[i], pixel_m, rest, tangent_x, tangent_z, faded_slope2);
	}
	// The short train: nodes as lake_envelope; its amplitude at the recent wind (9.17, the gusts).
	vec2 f = (rest - lake_grid.xy) * lake_grid.z;
	if (f.x < 0.0 || f.y < 0.0 || f.x >= float(lake_grid_size.x - 1) || f.y >= float(lake_grid_size.y - 1)) {
		return;
	}
	ivec2 node = ivec2(f);
	vec2 t = f - vec2(node);
	vec4 look = mix(mix(texelFetch(lake_look_data, node, 0), texelFetch(lake_look_data, node + ivec2(1, 0), 0), t.x),
		mix(texelFetch(lake_look_data, node + ivec2(0, 1), 0), texelFetch(lake_look_data, node + ivec2(1, 1), 0), t.x), t.y);
	float a = look.r * pow(max(wind_recent_ratio(rest), 0.0), look.g);
	lake_shading_train(lake_look_band, a, pixel_m, rest, tangent_x, tangent_z, faded_slope2);
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
	// A lake's waves: the surface's normal and directions per pixel (see lake_displace).
	float waves_faded_slope2 = 0.0;
	float pixel_crest_factor = crest_factor;
	float pixel_crest_steepness = crest_steepness;
	if (lake_waves_on) {
		vec2 footprint = fwidth(rest_xz);
		vec3 tangent_x;
		vec3 tangent_z;
		float crest;
		float total_steepness;
		lake_pixel_surface(rest_xz, max(footprint.x, footprint.y), tangent_x, tangent_z, crest, total_steepness, waves_faded_slope2);
		mat3 to_view = mat3(VIEW_MATRIX);
		NORMAL = normalize(to_view * normalize(cross(tangent_z, tangent_x)));
		TANGENT = normalize(to_view * normalize(tangent_x));
		BINORMAL = normalize(to_view * -normalize(tangent_z));
		pixel_crest_factor = total_steepness > 0.0 ? crest / total_steepness : -1.0;
		pixel_crest_steepness = crest;
	}
	float wind = wind_ripple_factor(world_position.xz);
	float gust = clamp((wind - 1.0) * gust_look_contrast, -1.0, 1.0);
	float darker = 1.0 - gust_darkening * max(gust, 0.0);
	float glassier = 1.0 + gust_glassiness * max(-gust, 0.0);

	// 4. Two layers of ripples, a big and a small one, at slightly different angles. They
	// drift on the engine's clock: they are only a look, and keep moving in the menus.
	vec2 along = normalize(ripple_drift_direction + vec2(1e-6, 0.0));
	vec3 big = ripple_layer(world_position.xz, ripple_size_m, ripple_speed_ms, along, TIME);
	vec3 small = ripple_layer(world_position.xz, ripple_size_m * 0.35, ripple_speed_ms * 0.6,
		normalize(along + vec2(-along.y, along.x) * 0.4), TIME);
	vec3 ripple = normalize(big + small);
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
	vec3 own_color = mix(deep_color, shallow_color, clamp(0.5 + 0.5 * pixel_crest_factor, 0.0, 1.0) * crest_lightening);
	float shore = (1.0 - smoothstep(0.0, shore_line_depth_m, world_position.y - bed.y)) * shore_line_strength;
	vec3 albedo = mix(own_color * (vec3(1.0) - through), vec3(0.9), shore) * (1.0 - mirrored) * darker;
	vec3 emission = bed_color * through * (1.0 - shore) * (1.0 - mirrored);

	// 5. Foam on the steep crests covers the rest; the grid lines lie on top.
	float foam = smoothstep(foam_threshold, foam_threshold + 0.15, pixel_crest_steepness) * 0.7;
	albedo = mix(albedo, foam_color, foam);
	emission *= 1.0 - foam;
	float distance_fade = clamp(1.0 - distance_m / grid_fade_distance_m, 0.0, 1.0);
	float lines = grid_line(world_position.xz, cell_m, line_width_m) * distance_fade * grid_strength;

	ALBEDO = mix(albedo, line_color, lines);
	EMISSION = emission * (1.0 - lines);
	float roughness = mix(roughness_value, roughness_far, smoothstep(0.0, roughness_far_m, distance_m));
	// A gust's rougher water mirrors the bright sky less and more diffusely: darker and matt;
	// a lull's is glassier.
	roughness = max(roughness * wind, gust_roughness * max(gust, 0.0));
	// A lake's wave slopes too small for the pixels roughen the mirror instead (a GGX alpha of
	// roughness squared, widened by their mean square slope).
	if (lake_waves_on) {
		float alpha = roughness * roughness;
		roughness = sqrt(sqrt(alpha * alpha + waves_faded_slope2));
	}
	ROUGHNESS = clamp(mix(roughness, 0.5, foam), 0.0, 1.0);
	METALLIC = 0.0;
	// Godot's mirror strength: 0.25 gives water's 2 % reflection straight on; less in a gust,
	// more in a lull (the glassy patch).
	SPECULAR = 0.25 * darker * glassier;
}
