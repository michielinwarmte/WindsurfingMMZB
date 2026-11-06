// The droplets of the spray, the splashes and the spray blown off the crests (water_particles.gd).
// Each particle is a small soft blob of water that always faces the camera:
// - lit by the sun and the sky (light() below): a wrapped light, because spray is a cloud of tiny
//   drops that scatters light all round, and brighter when the sun shines through it toward the
//   camera (spray glows against the light in the photos);
// - kept within a size on the screen: a blob may look at most max_view_share of its distance across
//   (so a droplet passing the camera never becomes a big flat card) and at least min_view_share (so a
//   far one does not flicker as a sub-pixel dot); when it is drawn bigger than it is, it is drawn
//   fainter in proportion, so the spray as a whole keeps its brightness;
// - faded out within near_fade_m of the camera (gone at 0.4 of it).
// - drawn out along its own motion (stretch): fast water is seen as streaks, as in the photos, and a
//   sheet of streaks reads as a sheet where round blobs read as single dots. The emitters line each
//   particle's Y axis up with its velocity (ParticleProcessMaterial.particle_flag_align_y), so the
//   particle's transform carries the direction of its motion.
// The particle's colour (the emitter's colour ramp) gives its fading.
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, skip_vertex_transform, shadows_disabled;

uniform vec3 tint : source_color = vec3(0.94, 0.96, 1.0);
// The largest and the smallest a blob may look, as a share of its distance from the camera
// (0.05 is about 3 degrees; 0.002 about 1.5 pixels at 1280 x 720 and 75 degrees of view). By eye.
uniform float max_view_share = 0.04;
uniform float min_view_share = 0.002;
// Blobs closer than this to the camera fade out (metres): the follow camera is 4.4 m behind the board,
// and the spray left behind passes close by it.
uniform float near_fade_m = 2.5;
// How much brighter the spray is with the sun behind it (looking toward the sun through it). By eye.
uniform float forward_scatter = 1.2;
// A little light of its own, so white water stays white in the shade of the sail. By eye.
uniform float self_light = 0.12;
// How much longer than wide a blob is drawn along its motion. By eye.
uniform float stretch = 2.6;

varying float drawn_alpha;

void vertex() {
	vec3 centre = MODEL_MATRIX[3].xyz;
	float size_m = length(MODEL_MATRIX[0].xyz);
	float distance_m = length(centre - CAMERA_POSITION_WORLD);
	float drawn_m = clamp(size_m, min_view_share * distance_m, max_view_share * distance_m);
	float coverage = clamp((size_m * size_m) / max(drawn_m * drawn_m, 1e-6), 0.0, 1.0);
	drawn_alpha = coverage * smoothstep(0.4 * near_fade_m, near_fade_m, distance_m);
	// Face the camera, drawn out along the motion as the camera sees it (round when it moves
	// straight toward or away from the camera).
	vec3 motion_view = (VIEW_MATRIX * vec4(normalize(MODEL_MATRIX[1].xyz), 0.0)).xyz;
	float across_view = length(motion_view.xy);
	vec2 along = across_view > 1e-3 ? motion_view.xy / across_view : vec2(0.0, 1.0);
	vec2 side = vec2(along.y, -along.x);
	float length_factor = mix(1.0, stretch, clamp(across_view, 0.0, 1.0));
	vec2 corner = side * VERTEX.x + along * VERTEX.y * length_factor;
	VERTEX = (VIEW_MATRIX * vec4(centre, 1.0)).xyz + vec3(corner * drawn_m, 0.0);
	NORMAL = vec3(0.0, 0.0, 1.0);
}

void fragment() {
	// A soft round blob, densest in the middle.
	vec2 p = UV * 2.0 - 1.0;
	float r2 = dot(p, p);
	float blob = exp(-3.0 * r2) * (1.0 - smoothstep(0.6, 1.0, r2));
	ALBEDO = tint * COLOR.rgb;
	EMISSION = tint * self_light;
	ALPHA = clamp(blob * COLOR.a * drawn_alpha, 0.0, 1.0);
	ROUGHNESS = 1.0;
}

void light() {
	// Wrapped light: the side away from the sun is lit too (light scattered through the drops).
	float wrapped = clamp((dot(NORMAL, LIGHT) + 0.7) / 1.7, 0.0, 1.0);
	float through = forward_scatter * pow(clamp(dot(VIEW, -LIGHT), 0.0, 1.0), 6.0);
	DIFFUSE_LIGHT += (wrapped + through) * ATTENUATION * LIGHT_COLOR / PI;
}
