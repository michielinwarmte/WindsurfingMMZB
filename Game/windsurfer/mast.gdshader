// The mast's carbon tube, bent as mast_bend.gdshaderinc says (the sail's sleeve bends the
// same way, so the two stay together).
shader_type spatial;

#include "res://windsurfer/mast_bend.gdshaderinc"

uniform vec3 albedo : source_color = vec3(0.035, 0.035, 0.04);
uniform float roughness_value = 0.3;


void vertex() {
	VERTEX += mast_bend(VERTEX.y);
}


void fragment() {
	ALBEDO = albedo;
	ROUGHNESS = roughness_value;
}
