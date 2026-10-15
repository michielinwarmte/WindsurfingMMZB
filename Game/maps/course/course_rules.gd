class_name CourseRules
extends Resource
## How big the iQFOiL's courses are (MAP_SILVAPLANA_PLAN.md, W4a): the distances, angles and line
## lengths the course templates are built from. The numbers and where each comes from are in
## iqfoil_courses.tres; most are from the iQFOiL Class Race Management Guideline (2023), and where
## it gives a range, the middle is taken.
##
## Angles "from the wind" are measured between a leg and the direction the wind comes from:
## 0 degrees is straight upwind, 90 a beam reach, 180 straight downwind.

## One nautical mile in metres.
const NAUTICAL_MILE_M: float = 1852.0

@export_group("Course racing (windward-leeward and trapezoid)")
## The wind speeds (knots) where the class's distances change: below the first, between the two,
## and above the second (10 to 13, 13 to 17 and 17 or more knots).
@export var wind_steps_kt: PackedFloat32Array = PackedFloat32Array([13.0, 17.0])
## Mark 1 from the middle of the start line, nautical miles, for each wind range.
@export var windward_leeward_mark1_nm: PackedFloat32Array = PackedFloat32Array([0.9, 1.0, 1.05])
@export var trapezoid_mark1_nm: PackedFloat32Array = PackedFloat32Array([0.85, 0.95, 1.0])
## The trapezoid's reach from mark 1 to mark 2: its length (nautical miles) and its angle from the wind.
@export var trapezoid_reach_nm: float = 0.75
@export var trapezoid_reach_deg: float = 90.0
## The reach from the last mark to the finish line on a windward-leeward course: length and angle.
@export var finish_reach_m: float = 450.0
@export var finish_reach_deg: float = 95.0
## The trapezoid's reach from the outer gate to the finish: length and angle.
@export var trapezoid_finish_m: float = 450.0
@export var trapezoid_finish_deg: float = 120.0
## How far the leeward gate (4S/4P) lies upwind of the start line, metres.
@export var gate_above_start_m: float = 150.0
## How far the trapezoid's outer gate (3S/3P) lies upwind of the start line, metres.
@export var outer_gate_above_start_m: float = 0.0
## The distance between the two marks of a gate, and the length of the finish line, metres.
@export var gate_m: float = 75.0
@export var finish_line_m: float = 35.0
## The start line: number of boards x board length x this factor.
@export var board_length_m: float = 2.2
@export var start_line_factor: float = 3.0
## Upwind sprint (US3, US4): mark 1 from the middle of the start line, metres.
@export var upwind_sprint_mark1_m: float = 1000.0

@export_group("Reaching starts (sprint slalom PD3 and SD3, medal race MR1)")
## Mark 1 from the start line's pin, metres, at 90 degrees from the wind.
@export var reaching_mark1_m: float = 600.0
## Mark 1 to mark 2, straight downwind, nautical miles.
@export var downwind_leg_nm: float = 0.45
## The two slalom legs after mark 2: their length (metres) and the angle between them (degrees).
@export var slalom_leg_m: float = 400.0
@export var slalom_turn_deg: float = 25.0
## The start line: about this many metres per board, at least the minimum and at most the maximum.
@export var reaching_start_per_board_m: float = 7.0
@export var reaching_start_min_m: float = 40.0
@export var reaching_start_max_m: float = 170.0


## Mark 1's distance from the start line on a windward-leeward course, metres, for a wind in knots.
func windward_leeward_mark1_m(wind_kt: float) -> float:
	return _for_wind(windward_leeward_mark1_nm, wind_kt) * NAUTICAL_MILE_M


## Mark 1's distance from the start line on a trapezoid course, metres, for a wind in knots.
func trapezoid_mark1_m(wind_kt: float) -> float:
	return _for_wind(trapezoid_mark1_nm, wind_kt) * NAUTICAL_MILE_M


## The length of a start line across the wind (course racing, upwind sprint), metres.
func upwind_start_line_m(boards: int) -> float:
	return boards * board_length_m * start_line_factor


## The length of a start line along the wind (reaching starts), metres.
func reaching_start_line_m(boards: int) -> float:
	return clampf(boards * reaching_start_per_board_m, reaching_start_min_m, reaching_start_max_m)


## The value for the wind range a wind speed (knots) falls in.
func _for_wind(values: PackedFloat32Array, wind_kt: float) -> float:
	var index: int = 0
	for step_kt: float in wind_steps_kt:
		if wind_kt >= step_kt:
			index += 1
	return values[mini(index, values.size() - 1)]
