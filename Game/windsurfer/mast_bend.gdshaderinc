// The mast bends, and the sail's luff sleeve with it: shared by mast.gdshader and
// sail_cloth.gdshaderinc. The top falls back (a sail is cut with a curved luff, and the
// downhaul bends the mast into it) and, with the pull of the sail, to leeward. The bend
// grows with the square of the height above where it starts. Both meshes have the mast foot
// at their origin and the mast along +y; x points back along the boom, z across the sail.
// RigVisuals (rig_visuals.gd) sets the instance uniforms on the mast and the sail, and the
// start at the boom: the boom's clamp and the clew stay where the simulation has them. The
// flat sail in sail.glb is drawn forward by this bend (build_rig_models.py), so the rigged
// sail has the real outline.

// How far the masthead is bent back and across (toward the sail's +z), m.
instance uniform float mast_bend_aft_m : instance_index(5) = 0.0;
instance uniform float mast_bend_across_m : instance_index(6) = 0.0;
uniform float mast_length_m = 4.6;
// The mast bends above this height; below it is straight, m.
uniform float mast_bend_start_m = 0.3;


// How far the mast at height y has moved from straight.
vec3 mast_bend(float y) {
	float s = clamp((y - mast_bend_start_m) / (mast_length_m - mast_bend_start_m), 0.0, 1.0);
	return vec3(mast_bend_aft_m, 0.0, mast_bend_across_m) * s * s;
}
