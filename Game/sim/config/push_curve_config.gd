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
## The sail trimmed between luffing (0) and the most drive (1): Autopilot.drive_share.
@export var drive_share: PackedFloat64Array = [0.0, 0.5, 1.0, 1.0, 1.0, 1.0, 1.0]
## The pull held as a share of what the hike carries: Autopilot.hike_share (0.8 eased, 1.0
## neutral, 1.6 pushed: the autopilot suite's measured dial, autopilot_rework.md section 3).
@export var hike_share: PackedFloat64Array = [0.8, 0.8, 0.8, 1.0, 1.2, 1.45, 1.6]
## The rig leaned further to windward when powered, degrees on top of the sailor's
## max_rig_lean_deg (25): SimControls.rig_lean_extra_deg (35 pushed: the photos' 15 to 35).
@export var rig_lean_extra_deg: PackedFloat64Array = [0.0, 0.0, 0.0, 0.0, 5.0, 9.0, 10.0]
## The back foot against the fin, 0 to 1 of the straps' bound: Autopilot.back_foot_bias.
@export var back_foot_push: PackedFloat64Array = [0.0, 0.0, 0.0, 0.0, 0.33, 0.67, 1.0]
## More rail (the leeward rail down) on top of the technique's, degrees:
## SimControls.rail_bank_extra_deg.
@export var rail_bank_extra_deg: PackedFloat64Array = [0.0, 0.0, 0.0, 0.0, 1.0, 2.0, 3.0]
## More trim (the nose up) on top of the technique's aim, degrees: SimControls.trim_aim_extra_deg.
@export var trim_aim_extra_deg: PackedFloat64Array = [0.0, 0.0, 0.0, 0.0, 0.3, 0.7, 1.0]


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
