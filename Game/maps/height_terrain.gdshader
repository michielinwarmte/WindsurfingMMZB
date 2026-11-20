// A spot's terrain drawn straight from its height grid (HeightTerrain, height_terrain.gd): flat grid
// meshes lifted here, on the graphics card, to the heights of the TerrainGrid the game logic reads,
// and coloured with the aerial photos. No terrain meshes are built or stored: the same few grid
// meshes serve every chunk, and the same file serves the looks and the logic (MD3).
//
// The grid's 16-bit heights arrive as they are in the file: a two-channel 8-bit texture, the low
// byte in red and the high byte in green, read without filtering (filtering the two bytes apart
// would mix the low byte across a carry). So the heights between the nodes are interpolated here,
// the same bilinear way as TerrainGrid.height_at().
//
// The photo's light: as terrain.gdshader (the photo already has the flight's sun in it, so the
// game's sun adds only part of its usual shading).
shader_type spatial;
render_mode cull_back;

uniform sampler2D heights : filter_nearest, repeat_disable;
// The game position (x, z) of the grid's first node (north-west), the nodes' spacing, and the
// number of nodes (columns, rows).
uniform vec2 grid_origin = vec2(0.0);
uniform float grid_cell_m = 5.0;
uniform vec2 grid_nodes = vec2(2.0);
// height (m above the water) = height_offset_m + value * height_scale_m
uniform float height_offset_m = 0.0;
uniform float height_scale_m = 0.01;
// Nothing is drawn deeper than this (m): nobody sees the sea bed far under the water, and the
// chunks' boxes stay small.
uniform float lowest_m = -60.0;
// The skirt: the chunk's border hangs this far down (vertices marked with UV2.x = 1), so no gap
// shows where a fine chunk meets a coarse one.
uniform float skirt_m = 25.0;

uniform sampler2D photo : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
// The photo's area: game x, z of its north-west corner, its width and depth (m).
uniform vec4 photo_rect = vec4(0.0, 0.0, 1.0, 1.0);
uniform sampler2D detail_photo : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform vec4 detail_rect = vec4(0.0);
uniform bool has_detail = false;
// The far terrain leaves out the near terrain's area (x, z, width, depth).
uniform vec4 hole_rect = vec4(0.0);
uniform bool has_hole = false;

// Under the sea the photo shows the water's surface (its waves, the sun's glitter), not the bottom:
// from photo_depth_m below mean sea level it fades over 3 m into the sea bed's own colour (sand). The
// shallows, the beach and the lagoon keep the photo. water_level_m: the session's water above mean sea
// level (the game's height 0 is the water).
uniform vec3 seabed_color : source_color = vec3(0.72, 0.68, 0.56);
uniform float photo_depth_m = 2.0;
uniform float water_level_m = 0.0;
// The photo's colours times this: an aerial photo is exposed for the ground, so white sand comes out
// near pure white, brighter than sand in the game's sun.
uniform float photo_brightness : hint_range(0.0, 1.5) = 1.0;
// The photo's colours times this tint: an aerial survey's photo is colour-balanced to a pale grey;
// the ground seen from the beach is warmer (Sotavento's sand is beige, not white).
uniform vec3 photo_tint : source_color = vec3(1.0);
uniform float slope_darkening : hint_range(0.0, 1.0) = 0.25;
uniform float sun_shading : hint_range(0.0, 1.0) = 0.5;

varying vec3 world_position;

float node_height(ivec2 node) {
	node = clamp(node, ivec2(0), ivec2(grid_nodes) - 1);
	vec2 bytes = round(texelFetch(heights, node, 0).rg * 255.0);
	return height_offset_m + (bytes.r + bytes.g * 256.0) * height_scale_m;
}

// The height at a game position, bilinear between the four nodes around it (TerrainGrid.height_at()).
float height_at(vec2 xz) {
	vec2 f = (xz - grid_origin) / grid_cell_m;
	vec2 corner = floor(f);
	vec2 t = f - corner;
	ivec2 c = ivec2(corner);
	float north = mix(node_height(c), node_height(c + ivec2(1, 0)), t.x);
	float south = mix(node_height(c + ivec2(0, 1)), node_height(c + ivec2(1, 1)), t.x);
	return max(mix(north, south, t.y), lowest_m);
}

bool inside(vec2 xz, vec4 rect) {
	return all(greaterThanEqual(xz, rect.xy)) && all(lessThanEqual(xz, rect.xy + rect.zw));
}

void vertex() {
	// The chunks are placed without rotation or scale, so the world position is the vertex plus the
	// chunk's position.
	vec2 xz = VERTEX.xz + MODEL_MATRIX[3].xz;
	VERTEX.y = height_at(xz) - UV2.x * skirt_m - MODEL_MATRIX[3].y;
	world_position = vec3(xz.x, VERTEX.y + MODEL_MATRIX[3].y, xz.y);
}

void fragment() {
	if (has_hole && inside(world_position.xz, hole_rect)) {
		discard;
	}
	// The normal from the heights one node to each side: sharper than the mesh's own, and the same
	// on a fine and a coarse chunk.
	float e = grid_cell_m;
	float dx = height_at(world_position.xz + vec2(e, 0.0)) - height_at(world_position.xz - vec2(e, 0.0));
	float dz = height_at(world_position.xz + vec2(0.0, e)) - height_at(world_position.xz - vec2(0.0, e));
	vec3 world_normal = normalize(vec3(-dx, 2.0 * e, -dz));
	NORMAL = normalize((VIEW_MATRIX * vec4(world_normal, 0.0)).xyz);

	vec3 color = texture(photo, (world_position.xz - photo_rect.xy) / photo_rect.zw).rgb;
	if (has_detail && inside(world_position.xz, detail_rect)) {
		vec2 uv = (world_position.xz - detail_rect.xy) / detail_rect.zw;
		// A soft edge, 5 % of the detail photo's width, so its border does not show.
		vec2 edge = min(uv, 1.0 - uv);
		float weight = smoothstep(0.0, 0.05, min(edge.x, edge.y));
		color = mix(color, texture(detail_photo, uv).rgb, weight);
	}
	float below_sea_level_m = -(world_position.y + water_level_m);
	color = mix(color, seabed_color, smoothstep(photo_depth_m, photo_depth_m + 3.0, below_sea_level_m));
	float flatness = clamp(world_normal.y, 0.0, 1.0);
	ALBEDO = color * photo_brightness * photo_tint * mix(1.0 - slope_darkening, 1.0, flatness);
	ROUGHNESS = 0.95;
	SPECULAR = 0.2;
}

void light() {
	// Lambert's law (light ~ the cosine of the angle to the sun), blended with even light.
	float facing = clamp(dot(NORMAL, LIGHT), 0.0, 1.0);
	DIFFUSE_LIGHT += mix(1.0, facing, sun_shading) * ATTENUATION * LIGHT_COLOR / PI;
}
