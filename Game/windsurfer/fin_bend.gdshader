// The fin bends under its own lift (U2, PHYSICS_SPEC.md section 4 "The fin bends"). The
// simulation's beam (FinModel) says how far the tip moves sideways; RigVisuals sets that here
// every frame, and once, at the start, the beam's own shape along the span. Each point of the
// fin moves sideways (along the board's x) by the beam's deflection at its depth: nothing at
// the root, which is clamped in the fin box, most at the slender tip. The look is the fin
// model's own material (its colour, roughness and shine), copied in by RigVisuals, or a gear
// item's own colour, and a fin brand's colour at the tip (GearItem.fin_tip_colour).
shader_type spatial;

// The beam is described at the 21 edges of its 20 strips (FinModel.BEND_STRIPS), root to tip.
const int EDGES = 21;

// The fin's span in the model's own coordinates (m): the root is at y = 0, the tip at -span_m.
uniform float span_m = 0.38;
// How far the tip moves sideways (m), signed: + toward the board's starboard side (+x). It is
// the simulation's FinModel.bend_tip_m on the side the fin's lift points.
uniform float tip_deflection_m = 0.0;
// The beam's shape at each edge: its sideways movement as a share of the tip's (0 at the
// root, 1 at the tip), and the slope of that share along the span (per span length).
uniform float bend_shape[21];
uniform float bend_slope[21];

uniform vec4 albedo : source_color = vec4(0.06, 0.06, 0.07, 1.0);
uniform float roughness_value = 0.3;
uniform float metallic_value = 0.0;
uniform float specular_value = 0.5;
// The tip's colour (its alpha: how much of it covers the fin's own; 0: none) from this span
// fraction down to the tip (0.8: the lowest fifth of the fin).
uniform vec4 tip_colour : source_color = vec4(0.0, 0.0, 0.0, 0.0);
uniform float tip_from = 1.0;

// Where a point is along the span (0 at the root, 1 at the tip; below 0 in the fin box), for the
// tip's colour.
varying float span_fraction;


void vertex() {
	// Where this point is along the span (0 at the root, 1 at the tip), and the two edges of
	// the strip it is in. The part of the root that goes up into the board does not move.
	span_fraction = -VERTEX.y / span_m;
	float s = clamp(span_fraction, 0.0, 1.0);
	float at = s * float(EDGES - 1);
	int j = min(int(floor(at)), EDGES - 2);
	float t = at - float(j);
	float shape = mix(bend_shape[j], bend_shape[j + 1], t);
	float slope = mix(bend_slope[j], bend_slope[j + 1], t);
	VERTEX.x += tip_deflection_m * shape;
	// The surface turns with the bend: moving x by w(y) tilts the normal by the slope dw/dy
	// (y runs negative down the span, so dw/dy = -tip * slope / span).
	float dw_dy = -tip_deflection_m * slope / span_m;
	NORMAL = normalize(vec3(NORMAL.x, NORMAL.y - dw_dy * NORMAL.x, NORMAL.z));
}


void fragment() {
	float at_tip = step(tip_from, span_fraction) * tip_colour.a;
	ALBEDO = mix(albedo.rgb, tip_colour.rgb, at_tip);
	ROUGHNESS = roughness_value;
	METALLIC = metallic_value;
	SPECULAR = specular_value;
}
