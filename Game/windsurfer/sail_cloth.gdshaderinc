// The sail cloth's shape in the game, shared by sail_cloth.gdshader (the cloth and the luff
// sleeve) and sail_window.gdshader (the clear windows). RigVisuals (rig_visuals.gd) sets the
// instance uniforms from the simulation every physics tick (shape_sail).
//
// The mesh is res://assets/models/sail.glb (tools/blender/build_rig_models.py): the flat sail
// in its own frame, x along the boom from the mast (m), y up the mast from the mast foot (m),
// z across the sail. UV.x = u, the fraction of the way from the luff to the leech (or the
// foot) along a batten line; UV.y = 1 - v, where v runs from the tack (0) to the head (1);
// UV2.x = the length of that batten line (the chord), m.
//
// Three things bend the flat cloth:
// - the belly: a sail is cut with a curved profile. Its depth is `camber` times the chord
//   (about a tenth), deepest a bit more than a third of the way back from the mast, and it
//   bulges to the leeward side (`belly_side`), away from the wind;
// - flutter (`flutter`, 0 to 1, from the pressure in the sail: RigVisuals.flutter_for): a
//   little is a ripple just behind the mast, where a sail that is nearly luffing collapses
//   first; with no pressure left the whole cloth flaps, most at the free leech;
// - twist: above the boom the leech falls off to leeward, more toward the head (a few degrees
//   just above the boom, `twist_head_rad` at the head). It turns the cloth about the mast.
// Then the whole cloth moves with the mast's bend (mast_bend.gdshaderinc).

#include "res://windsurfer/mast_bend.gdshaderinc"

// Which way the belly bulges: +1 toward the sail's +z, -1 toward -z. RigVisuals moves it
// smoothly through 0 (a flat sail) when the sail goes over to the other side.
instance uniform float belly_side : instance_index(0) = -1.0;
// Draft depth over chord (SailConfig.camber), less while the sail luffs.
instance uniform float camber : instance_index(1) = 0.1;
// How far the head is turned to leeward of the boom, rad.
instance uniform float twist_head_rad : instance_index(2) = 0.2;
// 0 = a sail with pressure in it (no movement), 1 = no pressure at all (flapping).
instance uniform float flutter : instance_index(3) = 0.0;
// The ripples' phase, rad: RigVisuals advances it with the simulation clock.
instance uniform float flutter_phase_rad : instance_index(4) = 0.0;

// Where the draft is deepest, as a fraction of the chord from the luff.
uniform float draft_position = 0.38;
// Heights on the mast where the twist starts (the boom) and is full (the head), m.
uniform float boom_height_m = 1.4;
uniform float head_height_m = 4.58;
// Size of the ripple behind the mast, m, how far back it reaches (a fraction of the chord),
// the size of the flap at the leech per metre of chord (up to 1.2 m) when the sail has no
// pressure at all, and the length of the waves along the cloth, m.
uniform float luff_ripple_amplitude_m = 0.03;
uniform float luff_ripple_reach = 0.35;
uniform float flap_amplitude_m = 0.06;
uniform float flutter_wavelength_m = 0.9;


// The belly's profile along a batten line: 0 at the luff and at the leech, 1 at the draft.
float belly_profile(float u) {
	if (u < draft_position) {
		float a = 1.0 - u / draft_position;
		return 1.0 - a * a;
	}
	float b = (u - draft_position) / (1.0 - draft_position);
	return 1.0 - b * b;
}


// The profile's slope per unit of u.
float belly_profile_slope(float u) {
	if (u < draft_position) {
		return 2.0 * (1.0 - u / draft_position) / draft_position;
	}
	float span = 1.0 - draft_position;
	return -2.0 * (u - draft_position) / (span * span);
}


// Bends a vertex of the flat sail into its sailing shape. With `shape_normal` the normal is
// worked out from the bent shape (the cloth); without, the mesh's own normal only turns with
// the twist (the sleeve, which is a tube).
void bend_sail(inout vec3 vertex, inout vec3 normal, vec2 uv, vec2 uv2, bool shape_normal) {
	float u = clamp(uv.x, 0.0, 1.0);
	float v = 1.0 - uv.y;
	float chord = max(uv2.x, 0.0);

	// The belly, a little flatter toward the head as real sails are cut. `slope` is how
	// fast the offset grows along the batten line, per metre (u grows by 1 / chord per m).
	float depth_ratio = camber * (1.0 - 0.35 * smoothstep(0.6, 1.0, v));
	float offset = belly_side * depth_ratio * chord * belly_profile(u);
	float slope = belly_side * depth_ratio * belly_profile_slope(u);

	// Flutter: waves run back from the luff. The first part of the flutter is a ripple in
	// the front of the sail only (none at the mast, where the sleeve holds the cloth); the
	// rest is the whole cloth flapping, growing toward the leech. `size` is the waves'
	// height at this point, `size_slope` how fast it changes per unit of u.
	float k = TAU / flutter_wavelength_m;
	float phase = k * u * chord - flutter_phase_rad + 6.0 * v;
	float luff_part = luff_ripple_amplitude_m * smoothstep(0.0, 0.35, flutter);
	float flap_part = flap_amplitude_m * min(chord, 1.2) * smoothstep(0.35, 1.0, flutter);
	float in_reach = clamp(u / luff_ripple_reach, 0.0, 1.0);
	float size = luff_part * sin(PI * in_reach) + flap_part * u * u;
	float size_slope = flap_part * 2.0 * u;
	if (u < luff_ripple_reach) {
		size_slope += luff_part * PI / luff_ripple_reach * cos(PI * in_reach);
	}
	offset += size * sin(phase);
	slope += size_slope / max(chord, 0.05) * sin(phase) + size * k * cos(phase);

	// Twist about the mast (the y axis): none at the boom, the full twist at the head.
	float span_m = max(head_height_m - boom_height_m, 0.1);
	float h = clamp((vertex.y - boom_height_m) / span_m, 0.0, 1.0);
	float angle = belly_side * twist_head_rad * pow(h, 1.3);
	float angle_per_m = 0.0;
	if (h > 0.0 && h < 1.0) {
		angle_per_m = belly_side * twist_head_rad * 1.3 * pow(h, 0.3) / span_m;
	}
	float c = cos(angle);
	float s = sin(angle);
	float z = vertex.z + offset;
	vec3 bent = vec3(vertex.x * c - z * s, vertex.y, vertex.x * s + z * c);

	if (shape_normal) {
		// The surface's two directions (along the batten, up the mast); the normal is
		// square to both.
		vec3 along_batten = vec3(c - slope * s, 0.0, s + slope * c);
		vec3 up_mast = vec3(-bent.z * angle_per_m, 1.0, bent.x * angle_per_m);
		normal = normalize(cross(along_batten, up_mast));
	} else {
		normal = vec3(normal.x * c - normal.z * s, normal.y, normal.x * s + normal.z * c);
	}
	// The whole sail moves with the bent mast.
	vertex = bent + mast_bend(vertex.y);
}
