class_name PushCurveConfig
extends Resource
## The push slider's ladder (ROADMAP GP1; Documentation/reports/push_slider/PLAN.md): what each
## setting of the slider asks of the sailor, as points at the levels below, straight between
## them. Michiel's ladder (31 October 2026): 0 % standing still with the sail let fly, 25 %
## slowly moving, 50 % cruising, 75 % planing with little risk, 85 % more speed and a little
## risk, 95 % very fast with some control in mind, 100 % the most speed with a crash likely.
## The numbers are the slider rounds' result (Documentation/reports/push_slider/push_slider.md);
## change them in the .tres (Game/config/push_curve_default.tres).

## The slider's levels the points below belong to, rising from 0 to 1.
@export var levels: PackedFloat64Array = [0.0, 0.25, 0.5, 0.75, 0.85, 0.95, 1.0]
## The sail trimmed between luffing (0) and the most drive (1): Autopilot.drive_share. 0.3 at
## 25 % is "slowly moving" at every wind (1.7, 6.1 and 8.1 m/s at 12, 18 and 24 kt on a beam
## reach; 0.5 already planed at 24 kt), 0.85 at 50 % cruises (6.8, 9.7, 11.7 m/s): round 1.
@export var drive_share: PackedFloat64Array = [0.0, 0.3, 0.85, 1.0, 1.0, 1.0, 1.0]
## The pull held as a share of what the hike carries: Autopilot.hike_share. The lever that pays:
## 1.3 gives +3 % and 1.6 +4 to 7 % across the wind at 18 and 24 kt on flat water and on the
## default sea without a fall (round 1); 0.8 eased, 1.0 neutral, 1.6 pushed are the autopilot
## suite's measured dial (autopilot_rework.md section 3).
@export var hike_share: PackedFloat64Array = [0.8, 0.8, 0.8, 1.0, 1.3, 1.5, 1.6]
## The rig leaned further to windward when powered, degrees on top of the sailor's
## max_rig_lean_deg (25): SimControls.rig_lean_extra_deg. 35 pushed (the photos' 15 to 35): with
## the pull it gives the beam reach +5 to 8 %; alone it falls six times in 72 cases at twice the
## wave height, so it belongs to the top (round 1).
@export var rig_lean_extra_deg: PackedFloat64Array = [0.0, 0.0, 0.0, 0.0, 3.0, 7.0, 10.0]
## The back foot against the fin as a held push, 0 to 1 of the straps' bound:
## Autopilot.back_foot_bias. Not in the ladder: held, the couple makes the fin carry less, not
## more (471 to 438 N), costs 1 to 3 % across the wind and falls in waves (round 1). It steers
## (the legs in the helm); what loads the fin is the rail below.
@export var back_foot_push: PackedFloat64Array = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
## More rail (the leeward rail down) on top of the technique's, degrees:
## SimControls.rail_bank_extra_deg. The rail is what loads the fin (at 5°: its lift +12 %, its
## upward part +44 %) and steadies the board in waves (twice the height: no falls against two),
## and it speeds the 24 kt broad reach (+18 %) but slows the beam reach (-5 %) because this hull
## rides longer railed, not shorter (ROADMAP PH27, PH31): a degree at the top only (round 1; +2 at
## 100 % made it slower than 95 % on flat water, round 2). The sea's rail is below.
@export var rail_bank_extra_deg: PackedFloat64Array = [0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 1.0]
## The rail for the sea the sailor may add when the board bounces, degrees (Autopilot.wave_rail_max_deg;
## none in flat water, all of it at twice the default sea's height): the reflex that keeps 75 %
## from falling in waves without the 5 % that a rail held always costs on flat water (round 2:
## the falls in six hours of sailing 11 to 5 at 75 %, 20 to 13 at 85 %). Not at the top: stacked
## on the ladder's rail with the pull at 1.5 it tipped the 24 kt upwind board over in waves (five
## to eight falls in 300 s, none without it; round 3), and at 100 % the sailor does not ease for
## the sea: the most speed, a crash likely (Michiel's ladder).
@export var wave_rail_deg: PackedFloat64Array = [0.0, 0.0, 3.0, 3.0, 3.0, 1.0, 0.0]
## More trim (the nose up) on top of the technique's aim, degrees: SimControls.trim_aim_extra_deg.
## +1° gives the 24 kt broad reach +10 % on flat water and two falls on the sea; +0.5 at the top
## (round 1).
@export var trim_aim_extra_deg: PackedFloat64Array = [0.0, 0.0, 0.0, 0.0, 0.0, 0.3, 0.5]


## The value of a setting at a slider level, straight between its points; held at the ends.
func at(numbers: PackedFloat64Array, level: float) -> float:
	var n: int = mini(numbers.size(), levels.size())
	if n == 0:
		return 0.0
	if level <= levels[0]:
		return numbers[0]
	for i: int in range(1, n):
		if level <= levels[i]:
			var span: float = levels[i] - levels[i - 1]
			var t: float = (level - levels[i - 1]) / span if span > 0.0 else 1.0
			return lerpf(numbers[i - 1], numbers[i], t)
	return numbers[n - 1]
