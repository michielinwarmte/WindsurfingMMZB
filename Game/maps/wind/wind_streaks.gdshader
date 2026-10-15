// Moves the wind viewer's streaks (WindStreaks, MAP_SILVAPLANA_PLAN.md W2). Every streak is a
// particle that starts somewhere in the square the camera looks at, rides the wind for a few
// seconds a little above the ground or the water, and fades in and out. Godot draws its path of the
// last moment as a ribbon (the particle trail), which is the white streak on the screen.
shader_type particles;
// The position is set here directly, not by Godot from VELOCITY.
render_mode disable_velocity, disable_force;

#include "res://maps/wind/wind_pattern.gdshaderinc"

// Where new streaks start: a square around the point the camera looks at (game X, Z), in metres.
uniform vec2 spawn_centre_m;
uniform float spawn_half_size_m = 3000.0;
// How many times faster than the real wind the streaks move, so you can follow them on the screen.
uniform float speed_up = 50.0;
// How high above the ground or the water the streaks fly, in metres.
uniform float lift_m = 5.0;
// The streaks are about the same number of pixels wide at every distance: their width in metres
// is the distance to the camera times this.
uniform vec3 camera_position;
uniform float width_per_metre = 0.002;
// Above the valley the streaks fade out: the pattern up there is not the Maloja (MALOJA_WIND_RESEARCH.md:
// a shallow wind in the valley, with a different wind on the higher slopes). Metres above the lake:
// 310 m is 2100 m above sea level, where the W1 pictures stop drawing arrows too.
uniform float valley_top_m = 310.0;
uniform float valley_fade_m = 100.0;
// Streaks in light wind are fainter: full strength from this speed (m/s) up.
uniform float full_streak_ms = 4.0;

// A random number from 0 to 1 that changes the seed (the PCG hash: fast, and good enough for this).
float random01(inout uint seed) {
	seed = seed * 747796405u + 2891336453u;
	uint word = ((seed >> ((seed >> 28u) + 4u)) ^ seed) * 277803737u;
	return float((word >> 22u) ^ word) / 4294967295.0;
}

void start() {
	uint seed = NUMBER * 1973u + RANDOM_SEED * 9277u + 26699u;
	vec2 xz = spawn_centre_m + (vec2(random01(seed), random01(seed)) * 2.0 - 1.0) * spawn_half_size_m;
	TRANSFORM = mat4(1.0);
	TRANSFORM[3].xyz = vec3(xz.x, pattern_at(xz).b + lift_m, xz.y);
	CUSTOM = vec4(0.0);  // CUSTOM.y counts the streak's age in seconds
	COLOR = vec4(1.0, 1.0, 1.0, 0.0);
}

void process() {
	CUSTOM.y += DELTA;
	vec3 position = TRANSFORM[3].xyz;
	vec3 wind = wind_at(position.xz);
	position.xz += wind.xz * speed_up * DELTA;
	vec4 here = pattern_at(position.xz);
	position.y = here.b + lift_m;

	// The ribbon is as wide as the particle's X axis: lying flat across the wind (seen from above),
	// and a second one standing up along its Z axis (seen from the side).
	vec3 along = length(wind) > 0.01 ? normalize(wind) : vec3(0.0, 0.0, -1.0);
	vec3 across = normalize(cross(vec3(0.0, 1.0, 0.0), along));
	float width_m = distance(camera_position, position) * width_per_metre;
	TRANSFORM[0] = vec4(across * width_m, 0.0);
	TRANSFORM[1] = vec4(along, 0.0);
	TRANSFORM[2] = vec4(0.0, width_m, 0.0, 0.0);
	TRANSFORM[3] = vec4(position, 1.0);

	// Fade in and out over its life (fading in hides the jump from its last life to this one),
	// fainter in light wind, out above the valley, and out at the pattern's edge.
	float life = CUSTOM.y / LIFETIME;
	float alpha = smoothstep(0.0, 0.25, life) * (1.0 - smoothstep(0.75, 1.0, life));
	alpha *= smoothstep(0.0, full_streak_ms, length(wind));
	alpha *= 1.0 - smoothstep(valley_top_m, valley_top_m + valley_fade_m, here.b);
	alpha *= smoothstep(0.0, 500.0, inside_pattern_m(position.xz));
	COLOR = vec4(1.0, 1.0, 1.0, alpha);
}
