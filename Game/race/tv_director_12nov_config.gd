class_name TvDirector12NovConfig
extends Resource
## The TV director's numbers as they were chosen by hand on 12 November 2026
## (Documentation/reports/racing/tv_camera_12nov.md), kept for comparing on the screen with the
## director set to the real stream (TvDirectorConfig): Game/config/tv_director_12nov.tres, started
## with --tv_director=12nov. The stream's director also takes the helicopter (key 5) and the overhead
## drone (key 9) from here: the stream does not use them, so they stay as they were, by hand.
## Metres, seconds, radians, degrees.

@export_group("The cuts")
## How long a drone shot lasts, real seconds: drawn evenly between these two.
@export var shot_min_s: float = 7.0
@export var shot_max_s: float = 12.0
## A mark shot holds until the board has rounded and mark_after_s more, at most mark_max_s. A board of
## the first mark_front coming within mark_soon_m of its mark gets one (not before a shot is
## mark_cut_after_s old).
@export var mark_after_s: float = 4.0
@export var mark_max_s: float = 22.0
@export var mark_front: int = 3
@export var mark_soon_m: float = 70.0
@export var mark_cut_after_s: float = 2.5
## The start, seconds of the race clock (negative before the gun): the wide shot from
## start_wide_from_s, the committee boat from line_from_s until line_until_s, the leaders leaving the
## line until after_start_until_s.
@export var start_wide_from_s: float = -40.0
@export var line_from_s: float = -12.0
@export var line_until_s: float = 7.0
@export var after_start_until_s: float = 16.0
## The finish line's shot: from the leader this far from the finish (m) until finish_hold_s after it.
@export var finish_m: float = 140.0
@export var finish_hold_s: float = 5.0

@export_group("The boards worth watching")
## Another racing board this close is a fight (m); its next mark this close (m); a place gained this
## recently (real seconds).
@export var close_m: float = 30.0
@export var mark_m: float = 80.0
@export var gained_s: float = 15.0
## The extra worth of the first, second, third and fourth board (the front).
@export var front_worth: PackedFloat32Array = PackedFloat32Array([7.0, 4.5, 3.0, 1.5])
## Every board's own worth; a fight's in the front half of the fleet and in the back half; a mark's
## for the first near_mark_places and for the rest; a place gained.
@export var base_worth: float = 0.3
@export var fight_front_worth: float = 3.0
@export var fight_back_worth: float = 0.8
@export var near_mark_front_worth: float = 4.0
@export var near_mark_worth: float = 2.0
@export var near_mark_places: int = 3
@export var gained_worth: float = 3.0
## A board still to start after the gun counts this share; a finished board this much; the board on
## the screen this share.
@export var late_share: float = 0.3
@export var finished_worth: float = 0.1
@export var shown_share: float = 0.5
## The drone shots' weights in TvCamera.DRONE_SHOTS' order (CHASE, TRACK, ORBIT, OVERHEAD, GROUP,
## MARK): usually, near a mark, in a fight.
@export var shots_usual: PackedFloat32Array = PackedFloat32Array([3.0, 3.0, 2.5, 1.5, 0.0, 0.0])
@export var shots_near_mark: PackedFloat32Array = PackedFloat32Array([1.0, 0.5, 1.5, 2.5, 0.0, 4.5])
@export var shots_in_a_fight: PackedFloat32Array = PackedFloat32Array([2.0, 2.5, 1.0, 1.0, 3.5, 0.0])
## The boats in a GROUP shot: within this distance of the board watched, m.
@export var group_m: float = 35.0

@export_group("The cameras")
## The lowest a camera flies above the water, and above the land (a lake's shore), m.
@export var lowest_m: float = 2.5
@export var above_land_m: float = 12.0
## Each shot's lens: the camera's vertical field of view, degrees (a TV lens is longer than the
## game's 75; the far shots have a TV helicopter's long lens, so the boats are no specks).
@export var chase_fov_deg: float = 50.0
@export var track_fov_deg: float = 40.0
@export var orbit_fov_deg: float = 28.0
@export var overhead_fov_deg: float = 45.0
@export var group_fov_deg: float = 34.0
@export var mark_fov_deg: float = 42.0
@export var start_wide_fov_deg: float = 38.0
@export var line_fov_deg: float = 44.0
## How quickly each shot's camera follows, seconds (a drone glides, a cut is instant).
@export var chase_glide_s: float = 0.5
@export var track_glide_s: float = 0.6
@export var orbit_glide_s: float = 1.0
@export var overhead_glide_s: float = 0.8
@export var group_glide_s: float = 0.9
@export var mark_glide_s: float = 0.4
@export var start_wide_glide_s: float = 1.2
@export var line_glide_s: float = 0.2
## How quickly the look follows, and the board's heading turns the chase drone and the others, s.
@export var look_glide_s: float = 0.3
@export var chase_turn_s: float = 1.5
@export var turn_s: float = 2.5

@export_group("The framing")
## The chase drone: behind, up, to the side, and looking this far ahead of the board (m), at this
## height above it.
@export var chase_back_m: float = 24.0
@export var chase_up_m: float = 9.0
@export var chase_side_m: float = 7.0
@export var chase_ahead_m: float = 10.0
## The drone beside the board: out, up, starting this far ahead and falling back past it over
## track_pass_s.
@export var track_side_m: float = 32.0
@export var track_up_m: float = 6.0
@export var track_along_m: float = 12.0
@export var track_pass_s: float = 14.0
## The helicopter: this far out, this high an angle, circling this fast.
@export var orbit_m: float = 110.0
@export var orbit_elevation_rad: float = 0.5
@export var orbit_drift_rad_s: float = 0.035
@export var orbit_look_up_m: float = 2.0
## The overhead drone: this high, turning this fast.
@export var overhead_m: float = 45.0
@export var overhead_turn_rad_s: float = 0.03
## The group: from behind and to one side (rad), this high an angle, at a distance of the group's
## reach times group_reach_times plus group_extra_m, between group_nearest_m and group_farthest_m.
@export var group_side_rad: float = 0.7
@export var group_elevation_rad: float = 0.4
@export var group_reach_times: float = 2.2
@export var group_extra_m: float = 18.0
@export var group_nearest_m: float = 28.0
@export var group_farthest_m: float = 110.0
## The mark drone: beyond the mark, to the side, up; it looks at a point this share of the way from
## the mark to the board.
@export var mark_beyond_m: float = 38.0
@export var mark_side_m: float = 18.0
@export var mark_up_m: float = 22.0
@export var mark_look_share: float = 0.45
## The wide start: behind the line, up, swaying along it (m, and how fast, rad/s), looking this far
## past the line.
@export var start_back_m: float = 70.0
@export var start_up_m: float = 30.0
@export var start_sway_m: float = 35.0
@export var start_sway_rad_s: float = 0.08
@export var start_look_past_m: float = 10.0
## The committee boat's camera: this far behind the boat on the line's line and this high (m), so the
## boat and its flag (whose top is 5.7 m up, CourseOnWater) stay just below the picture; aimed at the
## pin or, on a line shorter than line_aim_m, at a point that far down it.
@export var line_behind_m: float = 10.0
@export var line_up_m: float = 11.0
@export var line_aim_m: float = 150.0
## The boards' look point: this high above the board (m).
@export var look_up_m: float = 1.5


## The lens of a shot, degrees.
func fov_of(shot: TvCamera.Shot) -> float:
	match shot:
		TvCamera.Shot.CHASE:
			return chase_fov_deg
		TvCamera.Shot.TRACK:
			return track_fov_deg
		TvCamera.Shot.ORBIT:
			return orbit_fov_deg
		TvCamera.Shot.OVERHEAD:
			return overhead_fov_deg
		TvCamera.Shot.GROUP:
			return group_fov_deg
		TvCamera.Shot.MARK:
			return mark_fov_deg
		TvCamera.Shot.START_WIDE:
			return start_wide_fov_deg
	return line_fov_deg


## How quickly a shot's camera follows, seconds.
func glide_of(shot: TvCamera.Shot) -> float:
	match shot:
		TvCamera.Shot.CHASE:
			return chase_glide_s
		TvCamera.Shot.TRACK:
			return track_glide_s
		TvCamera.Shot.ORBIT:
			return orbit_glide_s
		TvCamera.Shot.OVERHEAD:
			return overhead_glide_s
		TvCamera.Shot.GROUP:
			return group_glide_s
		TvCamera.Shot.MARK:
			return mark_glide_s
		TvCamera.Shot.START_WIDE:
			return start_wide_glide_s
	return line_glide_s
