class_name SailorConfig
extends Resource
## The sailor: mass, where they stand, how far they lean, and how the automatic balance
## of beginner mode behaves (PHYSICS_SPEC.md sections 7 and 15). Change values in the .tres.

@export_group("Body")
## Mass of the sailor with wetsuit and harness.
@export var mass_kg: float = 75.0
## Height of the sailor's centre of mass above the board origin when standing upright
## (about 0.55 times body height above the feet, plus the deck height).
@export var com_height_m: float = 1.0
## Radius and height of the cylinder that stands in for the sailor's own inertia.
@export var torso_radius_m: float = 0.2
@export var height_m: float = 1.75

@export_group("Stance (fore and aft)")
## Where the sailor's weight is at rest and at low speed, in the body frame (z aft): the
## front foot by the mast foot, the back foot half a metre behind it.
@export var stance_rest_z_m: float = 0.15
## Where the weight is when planing: in the back footstraps, about 0.6 m from the tail.
@export var stance_planing_z_m: float = 0.60
## Where the weight is in a tack, the front foot just ahead of the mast: the nose dips, the
## tail and the fin lift a little, and the board pivots more easily. Further forward than
## this a 120 L board buries its nose.
@export var stance_tack_z_m: float = -0.20
## How fast the sailor steps in a tack (fraction of the full stance per second).
@export var step_rate_per_s: float = 2.5
## The sailor stops stepping forward as the bottom at the nose sinks to within this
## distance of deck depth (the nose about to go under), and is back at the rest stance
## when it reaches it: a board that still carries speed buries its nose under a sailor
## who steps forward too soon.
@export var nose_dive_ramp_m: float = 0.06
## The sailor starts stepping back at this forward speed and is in the straps at the second.
@export var stance_speed_start_ms: float = 3.5
@export var stance_speed_full_ms: float = 7.0
## Getting through the hump: once the board makes its hump speed (the Froude number of
## the hull's wave-making peak, BoardConfig.residuary_peak_froude, 2.7 m/s for the
## default board) the sailor moves the weight aft as long as the bow is below
## hump_trim_deg of bow-up pitch, all the way to the back straps at hump_trim_deg below
## it. The sail's drive, high up, pushes the nose down; the tail has to be pressed for the
## bottom to meet the water at the angle that lifts it onto the plane. Every sailor learns
## this as "step back to get planing".
@export var hump_trim_deg: float = 3.0
## How fast the sailor can move fore and aft (fraction of the full stance per second).
@export var stance_rate_per_s: float = 1.0
## Trimming with the feet once over the hump: the sailor presses the back foot to free the
## nose when the bow is below running_trim_deg and the front foot when it rises above it,
## moving the feet's pressure this far aft or forward of the stance (the two feet are
## half a metre apart) without moving the body. The weight that goes into the board at
## the feet is what sets a planing board's trim; without this the board ran nose-down
## at a degree of trim and, with next to no induced drag, far too fast off the wind.
@export var trim_press_max_m: float = 0.3
## The running trim the feet hold while planing, degrees of pitch bow up. A planing
## bottom porpoises above a critical trim that falls as the load coefficient falls with
## speed (Savitsky 1964): about 2 degrees for this board at 10 m/s. Held at 3 the board
## launched and splashed once a second.
@export var running_trim_deg: float = 2.0
## The press is full this many degrees of pitch away from hump_trim_deg, and it moves at
## trim_press_rate_ms: slowly, for the running trim, never chasing a bounce (a quick press
## lags a 1 Hz bounce by a quarter of a cycle and pumps it; the pitch reflex of the
## hang-back is what damps a bounce).
@export var trim_press_band_deg: float = 1.0
@export var trim_press_rate_ms: float = 0.1
## Hanging back against the sail's pull: the boom pulls the sailor forward, and the sailor
## leans back until their weight's moment about the feet balances the pull's (the same
## balance as the sideways lean, fore and aft). The furthest the weight can hang back
## behind the feet: a sailor hanging back hard against a strong pull is nearly horizontal
## (at 0.5 m the drive of a powered sail at the hump could not be balanced, and the rest
## went bow-down into the deck: the board planed late).
@export var hang_back_max_m: float = 0.8

@export_group("Legs")
## The legs are the sailor's suspension. A person standing still on a moving floor behaves
## like a mass on a damped spring at about 2 Hz with a damping ratio of about 0.4
## (Matsumoto and Griffin 1998, standing posture); a sailor planing with bent knees
## absorbs actively, softer and far more damped. With 2 Hz legs the body bounced against a
## porpoising hull at 1 Hz (near resonance, the body moved more than the stern) and the
## foot force pumped the board right out of the water in the gybes; at 1.2 Hz and 0.9 the
## body rides over it (Session 37's matrix: no falls in the beam gybes at 12 to 24 kt).
@export var leg_natural_frequency_hz: float = 1.2
@export var leg_damping_ratio: float = 0.9
## How far the knees can flex either way from the normal stance before the legs reach a stop.
@export var leg_travel_m: float = 0.25
## Across the deck the body goes where the posture puts it and rides the hull: loaded legs
## are struts, and the knees, the ankles and the hips give little sideways (a sideways
## spring in the legs, at 1 to 4 Hz, let the body swing, and with the feet aft of the
## board's centre that steered the board: the course hunted at every wind). The sailor's
## mass counts in the hull's sideways, fore-and-aft and yaw inertia.

@export_group("Hands and feet")
## Where the hands hold the boom: this far along the boom from the mast, at boom height
## (the harness lines sit about here, between the two hands). The pull of the sail reaches
## the sailor through this point; the rest of the sail force goes into the mast foot.
@export var hand_grip_m: float = 0.6
## How far outboard the feet stand at full lean (the rail of a 60 cm wide board is 0.3 m
## out; the straps are a little inside it). The feet stay on the centreline while the
## sailor leans against a light pull (up to feet_out_from_lean of full lean) and move
## out to the rail as the sailor hooks in and hikes (at feet_out_full_lean): a hiked
## sailor stands on the windward rail, and that is what holds the board flat against
## the sail.
@export var feet_rail_m: float = 0.22
@export var feet_out_from_lean: float = 0.3
@export var feet_out_full_lean: float = 0.7
## Weight on a rail (the lean the controls ask for) moves the feet's pressure toward the
## pressed rail, all the way onto it at a full press (the back foot steps onto the rail:
## a carving gybe is entered that way): the pressure goes from where the feet stand to
## this far out on the pressed side. It banks the board without moving the body. A planing
## hull resists heel with its lift only as far as the lift can move across the wet bottom,
## about 270 Nm on the tail; the whole weight on a rail (220 Nm) with the feet's moment
## (120 Nm) is what gets past that and carves.
@export var rail_step_m: float = 0.3
## How fast the feet's pressure moves to a rail (fraction of the full press per second):
## a foot presses in a third of a second, where the hips take a second.
@export var rail_press_rate_per_s: float = 3.0
## A change in the pull of the sail is taken up by the body over this time (a reflex): a
## gust yanks the sailor toward the sail before the legs and the hips have set themselves
## against it.
@export var hold_feel_time_s: float = 0.1
## The harness line as a rope (off at zero): it would pull when the boom moves away from
## the hips (the board rising under a hooked-in sailor) and go slack when the boom comes
## closer. Tried in Session 37 against the launching of the hull on chop: its pull lands
## on the mast foot, a metre forward, and slammed the bow into the next wave (the pitch
## swing on 6 cm chop doubled), and the rig flip in a tack made the line length jump.
## The steady hanging in the line is in the rig balance already. Kept for a later look
## with a rig that has mass of its own.
@export var harness_line_stiffness_n_m: float = 0.0
@export var harness_line_damping_ns_m: float = 800.0
## The lean follows the pull averaged over this longer time: the hike answers the mean
## pull, the brace and the hips take the ripple of every wave and wobble (a hike that
## chased the ripple swung the body at 1 Hz and yawed the board with it).
@export var lean_feel_time_s: float = 0.4
## The largest roll moment the feet can pass to the deck: pressing the toes or the heels
## moves the foot's pressure about 0.1 m either way from the ankle (a foot is 0.25 m long
## and stands across the board), 75 Nm at the body's weight; the straps and the second
## foot add some. It is shared between holding the board's heel and holding the body's
## balance. What the feet cannot pass tips the body (section 7.5).
@export var feet_moment_max_nm: float = 120.0
## The feet hold the board at the bank the sailor wants (flat, or the bank of the turn
## asked for): this many newton metres per radian of heel away from it and per radian per
## second of heel rate, within feet_moment_max_nm. A standing person's ankles stiffen
## against a tilting floor within a tenth of a second, and answer the rate of the tilt
## first of all: the rate term gives the whole feet_moment_max_nm at 0.2 rad/s (11 degrees
## a second). With less (150) the board rolled, lost its planing lift on the heel, carved,
## and the helm chased it: a 1 Hz wobble of 2 degrees of heel at 18 kt on flat water.
@export var feet_roll_stiffness_nm_per_rad: float = 1500.0
@export var feet_roll_damping_nms_per_rad: float = 600.0
## Balance from the hips: bending at the hips and swinging the arms moves the body's centre
## back over the feet without pressing the deck any harder on one side (the hip strategy
## of standing balance, Horak and Nashner 1986), and so do bending the knees and pulling
## on the boom (a handrail anchored to the board at the mast foot: yanking the rig over
## pulls the body in by the rig's inertia). Together they can hold the body against at
## most this force across the legs; a body tipped harder than that, for longer than
## tip_time_s, goes.
@export var hip_force_max_n: float = 400.0
## Hooked in, the harness line and the arms hold the hips to the boom as well: this much
## more, at full lean.
@export var harness_hold_max_n: float = 400.0
## How long the body can be tipped harder than the hips can hold before it is gone (a
## jolt shorter than this is ridden out).
@export var tip_time_s: float = 0.3

@export_group("Falling and getting back up")
## The board heels toward the sail only when the sailor can no longer balance the sail's
## pull. Past this leeward heel a standing person is pulled over the sail: a catapult.
@export var catapult_heel_deg: float = 20.0
## Past this windward heel the sailor falls in backwards (the pull vanished while hiked out).
@export var fall_back_heel_deg: float = 25.0
## A catapult needs a sail that pulls: below this side force the sailor is standing, not
## hanging, and only falls off a board heeled past standing_fall_heel_deg either way.
@export var catapult_min_sail_force_n: float = 120.0
@export var standing_fall_heel_deg: float = 40.0
## Seconds in the water before the sailor is back on the board (a waterstart).
@export var waterstart_time_s: float = 4.0
## Drag area (cd times area) of the rig in the water, pulling on the mast foot. A sail that
## hits the water at speed is a sea anchor: it stops the board within a fraction of a second
## (and often flips it), which is what a catapult looks like.
@export var rig_in_water_drag_m2: float = 0.3

@export_group("Lean (sideways)")
## Sideways distance of the sailor's centre of mass from the centreline at full lean:
## hooked in with the feet on the windward rail and the body stretched out, the body's
## centre is about a metre outboard.
@export var lean_max_m: float = 1.0
## The centre of mass drops by this much at full lean (the body goes nearly horizontal).
@export var lean_height_drop_m: float = 0.5
## How fast the sailor means to change the lean (fraction of full lean per second): the
## hips move about a metre a second. The body follows as the legs, the ankles and the
## pull in the hands let it (it is an inverted pendulum on the feet).
@export var lean_rate_per_s: float = 1.0
## The rig tips toward the sailor who hangs on it: mast lean toward the sailor's side at
## full lean. Raking the rig to windward is what real sailors do when hooked in; it brings
## the sail's centre of effort back over the board and gives the sail an upward component.
@export var max_rig_lean_deg: float = 25.0
## How far the sailor can tilt the rig sideways with the arms and shoulders on top of that
## (the mast foot is a free joint; what limits the tilt is the reach of the arms and, at
## speed, the pull in the sail). At 20 degrees a board on a run in light wind could not
## be turned against the push of its own eased sail; 30 turns it.
@export var rig_tilt_range_deg: float = 30.0
## The rig cannot lean further than this either way without the boom touching the water.
@export var max_total_rig_lean_deg: float = 45.0

@export_group("Windage")
## Frontal area times drag coefficient of the sailor's body in the apparent wind (a hiked
## sailor shows about half a square metre; a standing body about 0.7 m2 with Cd near 1).
@export var windage_area_cd_m2: float = 0.5

@export_group("Automatic balance (beginner mode)")
## Weight on a rail asks for a turn: at full lean the sailor banks the board for a
## coordinated turn at this rate, as much bank as that needs at the current speed
## (atan(v w / g)) and never more than bank_max_deg, taking the bank up at bank_rate_dps.
## A carved gybe is sailed at 25 to 35 degrees of bank, a course change at speed at 10
## to 15, and at rest a lean is just a lean.
@export var carve_rate_dps: float = 57.0
@export var bank_max_deg: float = 30.0
@export var bank_rate_dps: float = 12.0
## Loading the fin (U1.6): planing and hooked in, the sailor pushes on the rail and tips
## the board a little away from them, the leeward rail down. The fin then meets the water
## tilted, so its sideways push also lifts the board. This many degrees of leeward bank at
## full hike and in the back straps (the planing stance), less in proportion to either, and
## none while the controls ask for a turn. No source gives the angle: 3 to 6 degrees is an estimate from "a few
## degrees of heel" (Sutherland 1993; PHYSICS_SPEC.md section 14, "U1: the harness, the
## feet and the rail angle"), and Max will give his own. 3, the low end, because the feet
## hold the bank softly and a powered board already heels a few degrees past what they aim
## for. Too much and the board rails out (about 15 to 20 degrees on the 18 kt beam reach).
@export var fin_load_bank_deg: float = 3.0
## The sailor leans against the pull in the hands: this many times the lean that balances
## the hands' moment about the feet with the body's weight (1 = exactly in balance). The
## posture is held in the apparent gravity (gravity less the body's own felt acceleration,
## see WindsurferSim._posture_frame), never in the deck's axes: a standing person stays
## upright when the floor tilts, and leans into a turn with its push. The lean the
## controls ask for goes to the feet instead (weight on a rail, MassModel.feet_position_body):
## that is what banks the board.
@export var balance_moment_gain: float = 1.0
## Fore-and-aft weight shift against the pitch rate (metres per radian per second): the
## sailor's answer to a bouncing nose.
@export var pitch_reflex_m_per_rad_s: float = 0.5
## The body's own acceleration that sets the apparent gravity the posture is held in is
## felt averaged over this time: a sustained turn is leaned into, a quick jolt is ridden out.
@export var balance_feel_time_s: float = 0.3
## The fall checks use the push averaged over this longer time: a jolt of a few tenths
## of a second (a slam on a wave) is taken by the knees and does not throw a sailor; a
## push that lasts does.
@export var fall_feel_time_s: float = 1.0
