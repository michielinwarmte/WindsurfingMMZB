class_name Telemetry
extends RefCounted
## A snapshot of the simulation after a step, for the HUD, the tests and the scenario CSV.
## Everything a human reads is in display units here (degrees, km/h, knots); the physics
## inside the models stays in SI units.

var time_s: float = 0.0

# Motion
var position: Vector3 = Vector3.ZERO
var speed_ms: float = 0.0
var speed_kmh: float = 0.0
var speed_kt: float = 0.0
var vmg_ms: float = 0.0
var heading_deg: float = 0.0
var pitch_deg: float = 0.0
var heel_deg: float = 0.0
var yaw_rate_dps: float = 0.0
var leeway_deg: float = 0.0

# Wind
var tws_10m_kt: float = 0.0
var tws_at_sail_kt: float = 0.0
var twa_deg: float = 0.0
var aws_kt: float = 0.0
var awa_deg: float = 0.0
var wind_from_bearing_deg: float = 0.0

# Sail
var sail_side: int = -1
var sheet: float = 0.0
var rake: float = 0.0
var rig_tilt: float = 0.0
var boom_across: float = 0.0
var is_backwinded: bool = false
var rig_lean_deg: float = 0.0
var sail_angle_deg: float = 0.0
var alpha_deg: float = 0.0
var sail_lift_n: float = 0.0
var sail_drag_n: float = 0.0
var drive_n: float = 0.0
var side_force_n: float = 0.0
## The roll torque of the sail and of the fin together about the centre of mass (N m,
## body axes): what the sailor's weight has to balance. The fin's side force under the
## board heels it the same way as the sail's above it.
var heeling_torque_nm: float = 0.0
var is_luffing: bool = false
var ce_local: Vector3 = Vector3.ZERO

# Fin
var fin_slip_deg: float = 0.0
var fin_lift_n: float = 0.0
var fin_drag_n: float = 0.0
var fin_stalled: bool = false
var fin_immersed: float = 1.0

# Hull and water
var buoyancy_n: float = 0.0
var submersion_ratio: float = 0.0
var wetted_area_m2: float = 0.0
var planing_lift_n: float = 0.0
var planing_ratio: float = 0.0
## Where the planing force acts, in body axes (z aft), for debugging the balance of a turn.
var planing_cop_z_m: float = 0.0
## Depth of the bottom at the nose below the surface (negative = the nose is clear).
var bow_immersion_m: float = 0.0
var wetted_length_m: float = 0.0
var wetted_aft_m: float = 0.0
var spray_root_factor: float = 1.0
var heave_added_mass_kg: float = 0.0
var is_planing: bool = false
var trim_deg: float = 0.0
var hull_friction_n: float = 0.0
var hull_residuary_n: float = 0.0
var hull_lateral_n: float = 0.0
var bow_drag_n: float = 0.0
## Height of the water surface under the hull's origin (the still level on flat water).
var water_height_m: float = 0.0
var hull_resistance_n: float = 0.0

# Sailor and mass
## 0 = sailing, 1 = in the water after a fall; what kind of fall, and the time to the waterstart.
var sailor_state: int = 0
var fall_kind: String = ""
var waterstart_in_s: float = 0.0
var stance: float = 0.0
var lean: float = 0.0
## The bank the sailor is deliberately holding (degrees, positive = starboard rail down).
var wanted_bank_deg: float = 0.0
## The sideways push the sailor feels (m/s2, toward starboard), see WindsurferSim.
var felt_push_ms2: float = 0.0
## The heel the sailor feels: the board's heel less the bank a coordinated turn would need
## for the push they feel (degrees, positive = tipped toward starboard).
var felt_heel_deg: float = 0.0
var hang_back_m: float = 0.0
var knee_bend_m: float = 0.0
## Where the sailor's centre of mass actually is, and where the posture wants it (body axes).
var sailor_position_body: Vector3 = Vector3.ZERO
var posture_target_body: Vector3 = Vector3.ZERO
var feet_body: Vector3 = Vector3.ZERO
var hand_grip_body: Vector3 = Vector3.ZERO
var com_offset_body: Vector3 = Vector3.ZERO
var total_mass_kg: float = 0.0
## The sailor body (section 7.5): the pull of the rig on the hands (N, and its body-axis
## components), the force the legs carry into the feet, the force at the mast foot, the
## roll moment the body passes to the deck at the feet (all of it, and the hands' share),
## and how far the body has swayed from its posture across the legs.
var hand_force_n: float = 0.0
var hand_force_body: Vector3 = Vector3.ZERO
var foot_force_n: float = 0.0
var mast_foot_force_n: float = 0.0
var feet_moment_roll_nm: float = 0.0
var hand_moment_roll_nm: float = 0.0
var feet_moment_excess_nm: float = 0.0
## Weight on a rail (-1 port, +1 starboard): where the feet press.
var rail_press: float = 0.0
var leg_sway_m: float = 0.0


## The column names of to_csv_row(), in the same order.
static func csv_header() -> String:
	return "time_s,x,y,z,speed_ms,speed_kmh,vmg_ms,heading_deg,pitch_deg,heel_deg,yaw_rate_dps,leeway_deg," \
		+ "tws_at_sail_kt,twa_deg,aws_kt,awa_deg,sail_side,sheet,rake,sail_angle_deg,alpha_deg," \
		+ "sail_lift_n,sail_drag_n,drive_n,side_force_n,fin_slip_deg,fin_lift_n,fin_drag_n," \
		+ "buoyancy_n,submersion_ratio,wetted_area_m2,planing_lift_n,planing_ratio,trim_deg," \
		+ "hull_friction_n,hull_residuary_n,hull_lateral_n,stance,lean,hang_back_m,knee_bend_m," \
		+ "wetted_length_m,wetted_aft_m,spray_root_factor,heave_added_mass_kg,rig_tilt,rig_lean_deg,sailor_state,boom_across,fin_immersed," \
		+ "bow_immersion_m,planing_cop_z_m,fall_kind,wanted_bank_deg,felt_push_ms2,felt_heel_deg,bow_drag_n,water_height_m," \
		+ "hand_force_n,foot_force_n,mast_foot_force_n,feet_moment_roll_nm,hand_moment_roll_nm,leg_sway_m,feet_moment_excess_nm,rail_press,sailor_x_m,sailor_y_m,target_x_m,target_y_m,feet_x_m"


func to_csv_row() -> String:
	var values: Array = [time_s, position.x, position.y, position.z, speed_ms, speed_kmh, vmg_ms,
		heading_deg, pitch_deg, heel_deg, yaw_rate_dps, leeway_deg,
		tws_at_sail_kt, twa_deg, aws_kt, awa_deg, sail_side, sheet, rake, sail_angle_deg, alpha_deg,
		sail_lift_n, sail_drag_n, drive_n, side_force_n, fin_slip_deg, fin_lift_n, fin_drag_n,
		buoyancy_n, submersion_ratio, wetted_area_m2, planing_lift_n, planing_ratio, trim_deg,
		hull_friction_n, hull_residuary_n, hull_lateral_n, stance, lean, hang_back_m, knee_bend_m,
		wetted_length_m, wetted_aft_m, spray_root_factor, heave_added_mass_kg, rig_tilt, rig_lean_deg, sailor_state, boom_across, fin_immersed,
		bow_immersion_m, planing_cop_z_m, fall_kind, wanted_bank_deg, felt_push_ms2, felt_heel_deg, bow_drag_n, water_height_m,
		hand_force_n, foot_force_n, mast_foot_force_n, feet_moment_roll_nm, hand_moment_roll_nm, leg_sway_m, feet_moment_excess_nm, rail_press,
		sailor_position_body.x, sailor_position_body.y, posture_target_body.x, posture_target_body.y, feet_body.x]
	var parts: PackedStringArray = PackedStringArray()
	for value: Variant in values:
		if value is float:
			parts.append("%.4f" % value)
		else:
			parts.append(str(value))
	return ",".join(parts)
