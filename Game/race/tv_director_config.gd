class_name TvDirectorConfig
extends Resource
## The TV director set to the real World Tour slalom stream (TvStreamDirector; Max, 27 November
## 2026: "the drone shots trained on real data"). Game/config/tv_director.tres. The numbers come from
## nine slalom heat replays, every shot written down by two readers and counted
## (Documentation/reports/broadcast/data/stream_profile.json and shot_stats_slalom.md); the few that
## are the game's own choice say so here and in the .tres. The report:
## Documentation/reports/broadcast/tv_director_stream.md.
##
## A heat has four phases (Max, 27 November 2026), by the race clock: the pre-start, the start (from
## start_from_s before the gun to start_until_s after it), the race (until the race has ended) and
## after the race (until the next countdown). Each phase has its takes' lengths and its pictures
## (TvPhaseMix); the start, the marks and the finish are sequences with their own timing.
## Seconds are seconds of the picture (real seconds, the same pace in slow motion).

@export_group("The phases")
## The start phase's borders, seconds of the race clock (the gun at 0). The stream's readers: from the
## boards' final run at the line (about 10 s before the gun) until the fleet is strung out on the
## first reach (about 10 to 15 s after it).
@export var start_from_s: float = -10.0
@export var start_until_s: float = 12.0
## Before the start: the stream shows a line-up graphic for more than half of it (the graphics are a
## later phase of the plan); the live pictures only, at their shares among themselves.
@export var pre_start: TvPhaseMix
## The race: the drones that follow the boards and the beach cam, cut to when nothing is due at a mark
## or the finish.
@export var race: TvPhaseMix
## After the race: what a game can take of it (the stream goes to interviews).
@export var after_race: TvPhaseMix

@export_group("The start")
## The beach cam wide on the line, from the start phase's beginning until the line drone.
@export var start_beach: TvPicture
## The static low drone at the end of the line, the fleet sailing at it: the committee boat's view
## down the start line that Max asked for on 12 November ("for looking for over-earlies"), the line
## drawn on the water, with the stream's timing and framing.
@export var start_line_drone: TvPicture
## The line drone stands this far round from the start line's own line, on the course side, degrees:
## seen exactly end-on from beyond the committee boat the drawn line hides behind the boat; a little
## round, the line shows as a slanted line on the water, a board over early is on the camera's side of
## it, and the fleet sails towards the camera, as at the stream's line drone (the readers saw it as
## front-side and side about equally). The game's choice, not measured.
@export var line_drone_angle_deg: float = 20.0
## The drone that runs with the fleet off the line (behind and to the side on the fleet, or ahead and to
## the side on the front), drawn by weight_pct.
@export var start_runners: Array[TvPicture] = []
## When the line drone comes, seconds before the gun; when the runner comes, seconds after it; how
## long the runner runs, seconds (each as quartiles: x p25, y the middle, z p75). Counted on the nine
## heats' start sequences.
@export var line_drone_before_gun_s: Vector3 = Vector3(2.6, 3.1, 3.7)
@export var runner_after_gun_s: Vector3 = Vector3(0.6, 0.7, 1.8)
@export var runner_take_s: Vector3 = Vector3(8.0, 9.6, 11.6)
## The runner comes at the latest this long after the gun, s (the stream's latest of nine: 4.7).
@export var runner_latest_s: float = 5.0

@export_group("The marks")
## A drone already waits at the buoy; these are its pictures (by weight_pct; angle_deg round the
## boards' way into the mark).
@export var mark_pictures: Array[TvPicture] = []
## The cut comes this many seconds before the leader arrives: drawn evenly between x and y per mark.
@export var mark_cut_before_s: Vector2 = Vector2(2.0, 5.0)
## How long a take at a mark lasts, seconds (quartiles), between mark_shortest_s and mark_longest_s;
## and at least until the board has rounded and mark_after_rounding_s more.
@export var mark_take_s: Vector3 = Vector3(5.4, 6.7, 9.4)
@export var mark_shortest_s: float = 4.0
@export var mark_longest_s: float = 16.0
@export var mark_after_rounding_s: float = 1.5
## A board has gybed round its mark once it has come this near the buoy and is going away again
## (the race counts the rounding only once the board crosses a line past the mark, a few seconds
## later than the gybe on the screen), m. The game's choice.
@export var mark_near_m: float = 25.0
## After the leader's take at a mark, the chasers at the same mark (then back to the leader): how
## often, and how soon after the leader's take they must come (seconds).
@export var chasers_at_mark_chance: float = 0.7
@export var chasers_within_s: float = 25.0

@export_group("The finish")
## The drone hovering side-on at the finish line, holding the finish area while the places come in.
@export var finish_picture: TvPicture
## The cut comes this many seconds before the leader finishes (drawn evenly between x and y), unless
## the drone that follows the leader flies through the line with it (finish_follow_through_chance);
## then the hover comes once the leader is in.
@export var finish_cut_before_s: Vector2 = Vector2(2.0, 5.0)
@export var finish_follow_through_chance: float = 0.5
## How long the hover holds, seconds (quartiles), between finish_shortest_s and finish_longest_s.
@export var finish_take_s: Vector3 = Vector3(5.4, 12.4, 25.0)
@export var finish_shortest_s: float = 8.0
@export var finish_longest_s: float = 30.0

@export_group("After the race")
## The first take after the race: the long lens close on the winner sailing in.
@export var after_winner: TvPicture
@export var after_winner_take_s: Vector3 = Vector3(20.0, 25.0, 30.0)

@export_group("The boards")
## The lead group: the leader and the boards within lead_group_m of it, at most lead_group_most.
@export var lead_group_m: float = 40.0
@export var lead_group_most: int = 4
## The fleet is together while every board still racing is within fleet_together_m of their middle:
## only then is a picture on the fleet drawn (the stream's are on the first reach). The game's choice.
@export var fleet_together_m: float = 150.0
## A fight: another racing board this close, m. A place gained this recently counts, s.
@export var close_m: float = 30.0
@export var gained_s: float = 15.0
## No cut to the chasers at a mark before a take is this old, s.
@export var shortest_take_s: float = 2.0

@export_group("The cameras")
## The lowest a drone flies above the water, and above the land under it (a lake's shore), m.
@export var lowest_m: float = 2.5
@export var above_land_m: float = 12.0
## The beach cam: its eye this high above the water, m (the lead's measurement of the stream's beach
## camera on the PWA's beach at Sotavento, drone_position.md: about 4.5 m, 3.5 to 5 on 41 shots: a
## camera standing on the beach, not on the judges' tower), never lower than lens_lowest_m above the
## ground under it; its zoom between these lenses (vertical field of view, degrees; the stream's: 8 to
## 10 wide on the start line, 2 to 4 half close, 1 to 1.5 tight on the leaders; Godot's camera takes
## nothing narrower than 1).
@export var beach_eye_m: float = 4.5
@export var lens_lowest_m: float = 1.5
@export var lens_min_deg: float = 1.0
@export var lens_max_deg: float = 30.0
## Where the beach cam stands: where the map says (a Marker3D in the group "tv_shore_camera" anywhere
## in its scene: the eye's place; one place for the whole heat, it only pans and zooms; with several,
## the nearest to what it films); else the water's edge of the nearest shore of the map's land
## (shore_grid) between shore_nearest_m and shore_farthest_m from what it films; where no shore is in
## reach (the open sea) a camera boat this far off, close for the tight picture and far for the wide
## one, m.
@export var shore_nearest_m: float = 60.0
@export var shore_farthest_m: float = 1200.0
@export var boat_tight_m: float = 150.0
@export var boat_wide_m: float = 450.0
## A board between the beach cam and its subject, nearer the camera than this share of the way and
## within this distance of the line of sight, would fill the picture: the camera stands elsewhere.
@export var blocking_share: float = 0.7
@export var blocking_m: float = 6.0
## The pull-out after the race goes this many times farther over its take.
@export var pull_out_times: float = 4.0
## The helicopter (key 5) and the overhead drone (key 9), by hand only: the 12 November numbers.
@export var hand_shots: TvDirector12NovConfig


## The phase's mix of pictures (null for the start, which is a sequence).
func mix_of(phase: int) -> TvPhaseMix:
	match phase:
		TvStreamDirector.Phase.PRE_START:
			return pre_start
		TvStreamDirector.Phase.RACE:
			return race
		TvStreamDirector.Phase.AFTER_RACE:
			return after_race
	return null
