class_name SailConfig
extends Resource
## The sail and rig: geometry, mass, the sheeting range, and the aerodynamic coefficient
## curves (PHYSICS_SPEC.md sections 2, 3 and 14). Change values in the .tres file.

@export_group("Geometry")
## Sail area.
@export var area_m2: float = 6.5
## Luff length (the mast edge of the sail). The default sail is Max's real one, the Severne
## HGO 8.0 (PH28, 30 October 2026): a 5.22 m luff and a 2.20 m boom on an Apex 490 mast with a
## 36 cm extension (Severne's HGO page, severnesails.com/sails/hgo-hyper-glide-iqfoil/, and
## Starboard's iQFOiL equipment table, iqfoil.star-board.com/equipment/iqfoil-class/). The
## luff sets the aspect ratio (luff squared over the area: 3.41 for the 8.0, the paper's 3.36)
## and with it the lift slope, so it must be the sail's, not the mast's.
@export var luff_m: float = 4.60
## Boom length from the mast to the clew (the 8.0: 2.20 m, the sources above).
@export var boom_m: float = 1.95
## Height of the boom above the mast foot, along the mast. The default 8.0 has 1.50 m, the
## middle of Max's 1.40 to 1.60 m (PH16 step 17).
@export var boom_height_m: float = 1.40
## Where the mast foot sits on the board, in the body frame (x starboard, y up, z aft).
## Real mast tracks are centred about 1.30 to 1.35 m from the tail of a 2.40 m board,
## that is 0.10 to 0.15 m forward of the centre. Max's Patrik 115 has its track from 1.245 to
## 1.405 m from the tail, and he sets the foot near the back of it for slalom ("around 1.2"):
## the default 8.0 has its pin at 1.265 m (z -0.125 on the 2.28 m board; PH16 step 17).
@export var mast_foot_local: Vector3 = Vector3(0.0, 0.06, -0.10)
## Fraction of the luff above the mast foot at which the centre of effort sits (section 2.13).
@export var ce_height_fraction: float = 0.40
## Fraction of the boom behind the mast at which the centre of effort sits (section 2.13).
@export var ce_boom_fraction: float = 0.35
## The boom is fixed square to the mast (PH16 step 16; off = level in the board's frame
## whatever the rake, as before). A sail turns with its mast: raked back, the boom points aft
## and down, so the clew, the centre of effort and the harness line's point on the boom drop
## by their distance along the boom times sin(rake): 0.24 m for the centre of effort (0.70 m
## along the boom) at the 20 degrees of rake of a planing reach. Spec 3.2 left this out as
## second order for the yaw (and wrote that it lifts the clew); it is not second order for the
## pitch, where the centre of effort's height sets the drive's moment, nor for the hooked-in
## sailor, who hangs within the harness line's length of the boom. Only the positions change:
## the angle of attack and the force's direction still come from the level chord.
@export var boom_square_to_mast: bool = false
## Camber: depth of the sail's curve divided by its chord. The full-scale iQFOiL sail in the
## wind tunnel (Zhang et al. 2025, Documentation/Science/2501.13254v1.pdf, Fig. 5d) has 6.3 to 6.6 %
## at its third batten with the outhaul on and 7.1 to 7.6 % with it eased (PH28).
@export var camber: float = 0.07

@export_group("Rig mass")
## Mass of mast, boom, sail, extension and base together. The default 8.0 keeps 9.5 kg, an
## estimate, although the published weights add up to more (PH28, 30 October 2026): the HGO
## 8.0 sail 5.5 kg (Starboard's iQFOiL equipment table; windfoilen.nl's review weighed 5.89),
## the Enigma Race 210-250 boom 3.52 kg (Severne's boom table) and the Apex 490 mast about
## 2.07 kg (Severne's table lists the Apex Team 490 at 2.07; the iQFOiL Apex 490 itself has no
## published weight), 11.1 kg together, plus about 1.3 kg for the race extension, the base and
## the lines (an estimate): 12.4 kg. With 12.4 kg the beginner's board no longer gets out of
## irons after a tack in 18 kt (the sail backs and the sailor falls off; test_windsurfer_sim.gd,
## the tack test, and tools/matrix.sh --only=tack --winds=18): the rig's weight moment goes
## through the hands (WindsurferSim._apply_rig_forces), and how the rider handles it in irons
## is the rider's model, not the sail's. For Michiel: the real rig is 12.4 kg.
@export var rig_mass_kg: float = 8.0
## Height of the rig's centre of mass above the mast foot. For the 8.0 the parts above add up
## to about 1.84 m (the sail's area centre 2.05 m up, the mast's middle 2.8 m, the boom 1.5 m,
## the extension and base 0.3 m): 1.8 m is kept.
@export var rig_com_height_m: float = 1.7
## Height of the masthead above the mast foot, used for the rig's own inertia (a thin rod) and
## by the visuals for the mast's length. The 8.0 stands on an Apex 490 with its 36 cm race
## extension (Starboard's table): 5.26 m.
@export var mast_m: float = 4.60

@export_group("Controls")
## Boom angle from the centreline when the sheet is fully in.
@export var sheet_angle_in_deg: float = 12.0
## Boom angle from the centreline when the sheet is fully out.
@export var sheet_angle_out_deg: float = 85.0
## Mast rake at full input, positive = raked back. Sailors swing the rig through about
## 25 degrees each way from upright when steering hard.
@export var max_rake_deg: float = 25.0
## The sail keeps its side until the wind is this close to dead ahead or dead astern.
@export var side_hysteresis_deg: float = 15.0

@export_group("Lift coefficient curve")
## Share of the finite-wing lift slope 2 pi AR / (AR + 2) the sail keeps before it twists.
## The wind-tunnel sail at 4 m/s, where it barely twists, has the full slope (0.069 per
## degree against the formula's 0.068 for its aspect ratio of 3.36; PH28). 1.0 on every sail:
## Session 58's 1.03 on the 8.0 only made up for a luff of 4.9 m (the mast's length) where
## the real sail's is 5.22 m; with the real luff the formula gives the measured slope itself.
@export var lift_slope_factor: float = 1.0
## Zero-lift angle in degrees per unit of camber (a cambered sail lifts at zero angle). The
## wind-tunnel sail, flexible at full scale and rigid at a quarter scale alike, still lifts
## 0.12 to 0.18 at 1 degree: its lift starts at about -2 degrees at 6.4 % camber, so 28 here
## (the legacy 60 started it at -6 degrees and made twice the measured lift at small angles).
@export var zero_lift_deg_per_camber: float = 28.0
## End of the linear part of the curve.
@export var cl_linear_end_deg: float = 12.0
## Angle of maximum lift (the rigid quarter-scale model stalls at about 17 to 18 degrees).
@export var cl_peak_deg: float = 18.0
## Extra lift gained between the linear end and the peak: a peak of about 1.1 untwisted,
## between the rigid model's 1.21 and the full-scale sail's 0.98 to 1.08 in light wind.
@export var cl_transition_gain: float = 0.15
## End of the stall drop; lift there is stall_retention times the peak.
@export var cl_stall_end_deg: float = 25.0
@export var stall_retention: float = 0.85
## Angle from which the sail acts as a flat plate.
@export var cl_deep_stall_deg: float = 45.0
@export var deep_stall_cl: float = 0.5
## Below this angle of attack the sail is luffing and its lift fades to zero (section 2.9).
## The wind-tunnel sail still carries 0.15 to 0.18 at 1.3 degrees, so the fade is narrow.
@export var alpha_luff_deg: float = 2.0
## A backwinded sail (the wind on its leeward face) inverts its camber against the battens
## and still works, less well: its lift is this share of the normal sail's at the same angle.
@export var backwind_efficiency: float = 0.7
## How far the sailor can push the clew across the centreline toward the windward side
## beyond the fully sheeted position (backing the sail to get through a tack), degrees.
@export var boom_across_max_deg: float = 47.0

@export_group("Twist under load (PH28)")
## A real sail's top twists open as the wind pushes harder: the leech is loose on purpose and
## the mast bends, so the upper sections meet the wind at a smaller angle and the sail carries
## less than a rigid one at the same boom angle. In the wind tunnel (Zhang et al. 2025, Fig. 6
## and 8) the twist grows with the angle and the wind, and the lift at a fixed angle falls by
## about the same share at every angle below the stall between one wind and the next: the
## measured lift at 6 and 8 m/s is 0.85 and 0.75 of the model's untwisted line (nothing was
## measured without wind; the untwisted curve is the model's own). A one-parameter formula,
## 1 / (1 + q / q_twist) with q the apparent wind's dynamic pressure, was fitted through the
## three winds: 125 Pa for the 8.0 gives 0.93, 0.85 and 0.76 at 4, 6 and 8 m/s (the 4 m/s data
## sit at about 0.97). It is a fit, not a measurement. The 6.5 (sail_6_5.tres) keeps 140 Pa,
## an estimate: a smaller sail loads its mast less at the same pressure (about 154 Pa scaled by
## area) on a softer mast (back toward 125). The share is twist_factor() in the sail model.
## 0 switches the twist off: a rigid sail, as before PH28.
@export var twist_pressure_pa: float = 125.0
## A numerical guard only, not a physics floor: the share is never below this. The tunnel
## stopped at 39 Pa (15.5 kt of apparent wind) and the game's planing reaches meet 50 to
## 160 Pa, where the formula gives 0.70 at 18 kt and 0.57 at 24 kt of apparent wind. Session
## 57 held the share at the tunnel's last measured 0.75 there instead, because at 0.5 a pushed
## sailor could not catapult at 24 kt; both are extrapolations, and Max chose the formula
## (30 October 2026). The formula only reaches 0.1 at about 83 kt of apparent wind (1120 Pa).
@export var twist_min_factor: float = 0.1
## Near the stall the twisted top carries the load the bottom has lost, so less of the lift is
## lost: this share (0.45) of the linear part's loss remains at the peak and beyond. Read off
## the eased sail's 20 degree points (its peak fell to 0.88 of the light-wind peak from 4 to
## 8 m/s where the linear part fell to 0.75); the rest of the fit is the outhaul-on sail,
## which has no points past 16.5 degrees. A mixed source.
@export var twist_peak_share: float = 0.45
## The twisted top carries less, so the centre of effort comes down. The height is
## ce_height_fraction times (1 - this times (1 - the twist's share)): about 6 % lower at 8 m/s
## than at 4 m/s. An average: in the tunnel (Fig. 8d) the drop from 4 to 8 m/s runs from 10 %
## at 5 degrees through 8 % at 9 and 6 % at 12 to 2 % at 16.5 degrees.
@export var twist_ce_drop: float = 0.32

@export_group("Centre of effort by angle of attack (PH28)")
## Eased, the sail's force sits low. In the wind tunnel (Zhang et al. 2025, Fig. 8d) the
## centre of effort climbed from about 1.0 m above the board at 1 degree of attack through
## 1.7 m at 5 and 1.95 m at 9 to 2.0 m from 12 degrees up, at every wind speed, on the 8.0
## whose masthead stands 5.26 m up. ce_height_fraction is the powered height (12 degrees and
## more); at smaller angles it is multiplied by the share from this table (those heights over
## 2.0 m), straight between the angles and held at both ends (ce_height_share()). So a sail
## that is eased, luffing or backed heels and pitches the board less, as the real one does.
## Measured on the 8.0; the 6.5 takes the same table, an assumption. Empty: the height fixed.
@export var ce_height_table_deg: Array[float] = [1.0, 5.0, 9.0, 12.0]
@export var ce_height_table_share: Array[float] = [0.5, 0.85, 0.975, 1.0]

@export_group("Drag coefficient")
## Drag with no lift: cloth friction, mast, boom and battens. Rig coefficient sets in the
## yacht-design literature (Larsson and Eliasson, Marchaj) put this at about 0.04 for a
## complete rig; the legacy 0.015 was a bare clean sail.
@export var cd_parasitic: float = 0.04
## Span efficiency of the induced drag term.
@export var oswald_e: float = 0.75
## The deck and the water under the sail's foot act as a partial end plate: a wing with
## one end on a wall behaves like a wing of twice the aspect ratio, and a sail whose foot
## runs a few percent of its span above the deck keeps roughly half of that gain (Larsson
## and Eliasson, Principles of Yacht Design, ch. 7, the "gap" effect; Marchaj, Sail
## Performance: why racers pull the foot down to the deck). The fin has the same factor
## of 2 for the hull above it (FinConfig.end_plate_factor).
@export var end_plate_factor: float = 1.4
## Separation drag grows as ((alpha - start) / span)^2 times this gain.
@export var cd_separation_start_deg: float = 15.0
@export var cd_separation_span_deg: float = 30.0
@export var cd_separation_gain: float = 0.5
## Flat-plate drag above the deep-stall angle: cd_form_gain * sin(alpha).
@export var cd_form_gain: float = 1.2
## A sail square to the wind has a drag coefficient of about 1.2 to 1.5 (section 2.8).
@export var cd_max: float = 1.3

@export_group("Limits")
## Below this apparent wind speed the sail produces no force (avoids dividing by zero).
@export var min_apparent_wind_ms: float = 0.5


## Geometric aspect ratio: luff squared over area (3.26 for the default sail).
func geometric_aspect_ratio() -> float:
	return luff_m * luff_m / area_m2


## The aspect ratio the induced drag sees: the geometric one times the end-plate factor
## of the deck under the foot. The lift slope keeps the geometric one (the measured curves
## of section 2 are of a sail in a tunnel, and the lift data stand as measured).
func aspect_ratio() -> float:
	return geometric_aspect_ratio() * end_plate_factor


func max_rake_rad() -> float:
	return deg_to_rad(max_rake_deg)


## The share of the powered centre-of-effort height at this angle of attack (degrees, either
## sign; see "Centre of effort by angle of attack"): straight between the table's angles, the
## first share below the first angle, the last share beyond the last. 1 with an empty table.
func ce_height_share(alpha_deg: float) -> float:
	var count: int = mini(ce_height_table_deg.size(), ce_height_table_share.size())
	if count == 0:
		return 1.0
	var a: float = absf(alpha_deg)
	if a <= ce_height_table_deg[0]:
		return ce_height_table_share[0]
	for i: int in range(1, count):
		if a <= ce_height_table_deg[i]:
			var t: float = (a - ce_height_table_deg[i - 1]) / (ce_height_table_deg[i] - ce_height_table_deg[i - 1])
			return lerpf(ce_height_table_share[i - 1], ce_height_table_share[i], t)
	return ce_height_table_share[count - 1]
