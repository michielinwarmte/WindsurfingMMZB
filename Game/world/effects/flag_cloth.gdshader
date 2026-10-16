// A flag's cloth waving in the wind (wind_flag.gd), by moving the vertices: no cloth physics.
// The mesh lies in the flag's x-y plane, the pole edge at x = 0 and the free end at x = width
// (UV.x from 0 at the pole to 1 at the free end). A wave runs from the pole to the free end
// and grows along the way, as on a real flag; it runs faster in more wind. In a calm the cloth
// hangs down along the pole.
shader_type spatial;
render_mode cull_disabled;

uniform vec3 cloth_color : source_color = vec3(0.95, 0.35, 0.05);
// The true wind at the flag, m/s (set by wind_flag.gd).
uniform float wind_speed_ms = 8.0;
uniform float flag_width_m = 0.9;

void vertex() {
	float along = UV.x;
	// Flat out from about 6 m/s (12 knots); hanging almost straight down in a calm.
	float streaming = clamp(wind_speed_ms / 6.0, 0.0, 1.0);
	float hang = mix(1.35, 0.08, streaming);
	float x = VERTEX.x;
	VERTEX.x = x * cos(hang);
	VERTEX.y = VERTEX.y - x * sin(hang);
	// The wave: about one and a half waves on the cloth, a few times a second.
	float frequency_hz = 1.0 + 0.25 * wind_speed_ms;
	float phase = 2.0 * PI * (along * 1.4 - frequency_hz * TIME);
	float amplitude_m = (0.04 + 0.006 * wind_speed_ms) * along;
	VERTEX.z += amplitude_m * sin(phase);
	// The tilted surface's normal, from the slope of the wave along the cloth.
	float slope = amplitude_m * 2.0 * PI * 1.4 / flag_width_m * cos(phase);
	NORMAL = normalize(vec3(-slope, 0.0, 1.0));
}

void fragment() {
	ALBEDO = cloth_color;
	ROUGHNESS = 0.8;
	// The cloth lets a little sunlight through: both sides look lit.
	BACKLIGHT = cloth_color * 0.5;
}
