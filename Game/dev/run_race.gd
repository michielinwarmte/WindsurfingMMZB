extends SceneTree
## A headless race (RACING_PLAN.md, Parts 9A and 9B): boards on a course, the countdown, the gun, the
## race's own clock and checks (RaceSim), and one line per board at the end. Each board is sailed by
## a scripted skipper (Skipper, with a character sheet from Game/race/skippers/) on the beginner
## PlayerController, the player's own controls, or by the plain Autopilot of 9A holding one wind
## angle (it starts and sails on at that angle, and does not finish). Use tools/race.sh.
##
## Arguments after "--":
##   --course=test         a small loop made by code (the default): a start line 60 m long, mark 1
##                         300 m upwind (port), the gate 4S/4P 100 m above the line, and the finish
##                         line 150 m to the left of the gate
##   --course=t1_loop      the T1 training loop on open water (RaceCourses), the start line at the origin
##   --course=template:O2  an iQFOiL template at the class's full size, or template:PD3@60 at 60 % (any of
##                         LG2, LR2, O2, I2, US3, US4, PD3, SD3, PM1, SM1): the trained head on every template
##   --course=<name>       a course saved by the course maker, by name (t2_slalom, ...)
##   --course=<file.json>  a course saved by the course maker (a res:// path, a full path, or a path
##                         from the repository's folder), placed with the Silvaplana map's frame
##   [--skippers=autopilot] who sails the boards, by name, comma-separated: allrounder, cautious,
##                         gambler, rookie (the .tres files in Game/race/skippers/), or autopilot.
##                         The names are dealt round the boards in order.
##   [--boards=<n>]        how many boards (the default: one per name in --skippers)
##   [--seed=0]            the skippers' random seed (board i gets seed + i): the same seed, the same race
##   [--spread=1]          the personas' levels (RaceSkipper.level_spread): 1 the sheets as written, the
##                         game's RaceSetup.LEVEL_CLOSE closer together
##   [--finish_window=60]  the race ends this long after the first board finishes, seconds (the game's
##                         rule; tools/race_matrix.sh waits longer, so every board gets a time)
##   [--laps=1] [--wind_kt=15]
##   [--seconds: how long the race is sailed after the gun: with skippers the race's own time limit
##                         for its course and wind (RaceTimeLimit: 2.5 times the polar's time, at least
##                         1200 s); a longer --seconds raises that limit, a shorter one stops the race
##                         early; 300 with only autopilots]
##   [--prestart: the countdown, seconds: 60 (the game's) with skippers, 10 with only autopilots]
##   [--twa=50: the wind angle the autopilot holds]
##   [--spawn=line]        where the skippers' boards appear: line (behind the start line, below) or
##                         random (at random spots in the sailing area round the start line, as the
##                         game puts them: SailingArea; on the lake kept off the shore)
##                         or anywhere (anywhere round the whole course, before the countdown: above the top
##                         mark, far below the line, out to the sides, on the lake in open water;
##                         anywhere_places())
##   [--spawn_seed=0]      the seed of the random spots: the same seed, the same spots
##   [--free_sail=0]       seconds of free sailing before the countdown starts
##   [--behind=<m>]        how far behind the start line the skippers' boards wait (the game's: 1 m
##                         per second of countdown, 40 to 100 m, RaceRunner); 150 with --prestart=30 is
##                         where the learned brains were trained (tools/gens.sh passes it)
##   [--blind=1]           the learned brains see no other boards (as in their training)
##   [--manoeuvre_gap_s=<s>] the learned brains' tack discipline (LearnedSkipper, RA14): the least time
##                         between two manoeuvres; without it each brain keeps the one it was trained
##                         with (6 s for the brains before RA14)
##   [--closest_twa_deg=<deg>] the closest to the wind the learned brains' hands steer; without it each
##                         keeps its own (none for the brains before RA14)
##   [--shadows=1]         the sails cast wind shadows on each other (F3, WindShadows); 0 turns them off
##   [--shadow_trail=1]    the shadows lie along each sail's trail of disturbed air, its apparent wind (WindShadowTrail,
##                         13 November 2026); 0: the cone straight down the true wind, as before (to compare)
##   [--rules=1]           the racing rules are kept (F3, RaceRules): a scripted skipper turns a circle for a
##                         penalty, a learned one carries 20 s to the finish; 0 turns them off
##   [--gear=1]            each persona sails its own board, sail and fin from the gear catalogue, sized
##                         for the wind (Persona.gear_for()), as in the game (RaceSetup.gear); 0: the
##                         default gear for every board. The other skippers keep the default gear. The
##                         gear is printed before the race
##   [--steady_hands=0]    1: every scripted skipper's hands as quick and steady as the all-rounder's
##                         (STEADY_REACTION_S, STEADY_NOISE_DEG), to measure what the personas' noise costs
##   [--skipper_push=1]    0: the scripted skippers leave the push slider alone and sail the pilot's own
##                         margin, as every AI board did before the skipper set it (to compare)
##   [--polar=<file.tres>] the scripted skippers sail with another polar (SkipperPolar; a res:// path or a
##                         path from the repository's folder) instead of Game/config/skipper_polar.tres
##   [--stop_after_gun=<s>] stop the race this long after the gun (to look at the start only)
##   [--race_type=<type>]  race the course as slalom, course or hybrid (Course.RaceType; a slalom's
##                         boards wait upwind of the committee boat); without it the course's own type
##   [--start_type=<type>] start as slalom or course (Course.StartType: the skippers' timed run, or waiting
##                         behind the line with lag); without it the course's own start
##   [--map=lake]          the boards sail on Lake Silvaplana as the game sails it there: the lake's
##                         air and water, the map's wind of the hour (its gusts, lulls, shifts and lee)
##                         and the lake's own waves (PHYSICS_SPEC.md 9.17, 9.18), at --time=14:30 (any
##                         hh:mm); --wind_kt is then the lake's mean wind of that hour. With a course
##                         on the lake (t2_slalom). --lake_wave_scale=<x> sets the waves' height.
##                         --lake_wind_scale=<x> the map's wind times x (and the waves grown from it).
##                         On the lake a board whose fin touches the bottom has run aground: it stops
##                         where it is (as in the game, RaceRunner) and an AGROUND line says where and
##                         what its skipper was doing; the count is printed at the end. The skippers
##                         look out for the shore (ShoreLookout); --shore_guard=0 races without.
##                         Without it every board sails the open water (below)
##   [--pilot.<field>=<n>] [--controller.<field>=<n>] a tuning number of every skipper's beginner
##                         controller (PlayerController) or its auto-sheet pilot (Autopilot, through
##                         the controller's pilot_overrides), for the autopilot's suite
##   [--trace=<board name>] that board's whole telemetry, a row every 0.05 s, to <out_dir>/trace_<name>.csv
##   [--skipper.<field>=<n>] a number of every scripted skipper's character sheet (SkipperConfig)
##   [--start_spots=a,b,c] each board's own start spot (0 the pin end, 1 the boat end), dealt round the boards:
##                         phase S3's three copies of the general head each want their own place on the line
##   [--start_tacks=a,b,c] each board's own tack for a course race's start (0 either, 1 starboard, 2 port), dealt round
##   [--drop_step=<k|random> --drop_seed=<n> --goal_steps=2] a drop instead of a race (the skipper's heads,
##                         8 November 2026): every board set down after the gun at a random open-water
##                         spot on the leg to step k (random: any leg), heading roughly along it; the run
##                         ends when the board has done goal_steps more steps (or after 2.5 times the
##                         all-rounder's expected time plus 90 s). Every run prints a HEADS_RESULT line per
##                         board (tools/heads/suite.py scores them)
##   [--restart_after=<s> --restart_spawn_seed=<n>] the game's R that long after the gun (or when the race is
##                         over): a new race with the same skippers set up again and every board at a new random
##                         spot (restart_race()); the results, the start report and --stop_after_gun are the
##                         second race's
##   [--start_only=1 --start_watch_s=60] a start-only race (the training method's phase S, 9 November 2026): the
##                         race ends once every board is over the start line (or aground), or start_watch_s after
##                         the gun (the start check's limit is 20 s after it; the extra 40 s say how late a late
##                         start was). HEADS_RESULT says start_only
##   [--start_follow_s=30] (phase S3, 10 November 2026) the start-only race goes on at least this long after the gun,
##                         so every board's start score is taken (START_SCORE_AT_S). Every race's HEADS_RESULT has
##                         the start's score: score_m (how far up the course it was 30 s after the gun, metres:
##                         start_score_m()), cross_speed_ms (its speed when its start counted), near_s (seconds
##                         within 5 m of another board from 30 s before the gun to 30 s after), and the wind at the
##                         gun: gun_mean_kt (the race's 10 m mean), gun_felt_kt, gun_felt_60s_kt, gun_felt_spread_kt
##                         (what its sail felt: FeltWind)
##   [--start_spare_s=30]  only reachable drops (phase S): a board whose way to the start line (start_need_s, the
##                         start check's own estimate) takes longer than the countdown less this, at the countdown's
##                         start or after an R, prints DROP_TOO_FAR and the tool quits (code 3), like COURSE_ILLEGAL,
##                         so the random suite draws the race again
##   [--round_drill=gybe|top --round_seed=<n> --round_from_m=<a>,<b> --round_together_s=<s>] the rounding drill (Max,
##                         12 November 2026: "training mark roundings from every angle. for slalom gybing and rounding
##                         for going from upwind to downwind ... just as the beginning of the starts"): a drop after the
##                         gun at one mark of that kind (round_drill_marks(): gybe, a slalom's gybe mark; top, a mark
##                         reached on a beat and left downwind), every board set down a random a to b metres before it
##                         from a random angle (round_drill_spot(); top: anywhere below the mark, inside or outside the
##                         laylines, on a random tack). With more boards (--boards), each one's expected time to the
##                         mark within round_together_s of the first's (the laylines in company), and with
##                         --round_group_deg=<deg> from within that angle of the first as seen from the mark (one
##                         layline, each other's dirty wind: 13 November 2026). The run ends
##                         at ROUND_SCORE_FACTOR times the first board's expected time to the mark plus ROUND_SCORE_AFTER_S, when every board's
##                         score is taken (Max: "a way to calculate which was the fastest gybe"): how far down the
##                         course past the mark it is then, metres (course_progress_m()). A course without such a mark
##                         prints DRILL_NONE and quits (code 3): the random suite draws again. HEADS_RESULT has "drill"
##   [--sailor.<field>=<n>] a number of every skipper's sailor (SailorConfig, on its own gear too):
##                         the fall rule's, for the stay-on-the-board work
##   [--out_dir=<folder>: a CSV per board: race time, x, z, heading, speed, its next step, and what
##                         its skipper is doing]
## After the results it prints each skipper's start: how long after the gun it crossed the start
## line, whether it was over the line at the gun (OCS), and the boards outside the sailing area at the
## gun.
##
## Every board is the open water's default simulation with its waves, stepped at 1/60 s. The wind
## blows from the course's axis, so the course is square to it. After every tick the race is told
## where the boards are.
##
## Where the boards wait: a skipper sails the whole countdown itself, from where the game puts the
## boards with its spawn on the line (RaceRunner: 1 m behind the start line per second of countdown,
## 40 to 100 m; spread across it, on a beam reach at rest), or --behind. An autopilot cannot sail a countdown: it is put back along its approach so that
## it reaches the line at about the gun, and waits until SET_OFF_S before it.

const DT: float = 1.0 / 60.0
const MAP_CONFIG_PATH: String = "res://maps/silvaplana/map_config.tres"
## How far back along its approach an autopilot board is put for each second of the countdown,
## metres: about what a board starting from rest sails in that time in 15 kt (it averaged 4.8 m/s
## over its first 10 s), so that it reaches the line near the gun. More wind gets it there earlier,
## less later.
const APPROACH_M_PER_S: float = 4.5
## The autopilot boards are put back as if the countdown were this much longer, seconds: a
## fixed-angle pilot cannot go back behind the line, so a little late is better than over early.
const START_MARGIN_S: float = 3.0
## The autopilot boards set off this long before the gun, seconds; until then they wait where they
## were put (their simulations are not stepped). A fixed-angle pilot sailing a long countdown would
## drift far from the spot it was aimed at.
const SET_OFF_S: float = 10.0
## --skipper.<field>=<n>: a number of every scripted skipper's character sheet (SkipperConfig), set after
## the skippers are set up (a persona's sheet is drawn in its setup()), for the skipper's tuner.
static func apply_skipper_overrides(entries: Array[Entry], options: Dictionary[String, String]) -> void:
	for key: String in options:
		if not key.begins_with("skipper."):
			continue
		var field: String = key.trim_prefix("skipper.")
		for entry: Entry in entries:
			var scripted: Skipper = entry.skipper as Skipper
			if scripted == null:
				continue
			if field in scripted.config:
				var current: Variant = scripted.config.get(field)
				var text: String = options[key].strip_edges().to_lower()
				# "true" and "false" too, for a bool: "true".to_float() is 0, which read every "=true" as off (the
				# skipper's heads, 8 November 2026: the first look-ahead A/B ran three identical arms).
				var value: float = 1.0 if text == "true" or text == "yes" else (0.0 if text == "false" or text == "no" else text.to_float())
				scripted.config.set(field, (value != 0.0) if current is bool else (int(value) if current is int else value))
			else:
				push_error("No field 'skipper.%s' to override." % field)
	# --start_spots=a,b,c: board i's own start spot (SkipperConfig.start_spot, 0 the pin end, 1 the boat end), dealt
	# round the boards. Phase S3 races three copies of the general head (Max, 10 November 2026: "we want the fastest
	# skipper"), whose sheet has one spot (0.5): without this all three aimed at the same point every race.
	var spots: PackedStringArray = options.get("start_spots", "").split(",", false)
	if not spots.is_empty():
		for i: int in entries.size():
			var scripted_board: Skipper = entries[i].skipper as Skipper
			if scripted_board != null:
				scripted_board.config.start_spot = clampf(spots[i % spots.size()].to_float(), 0.0, 1.0)
	# --start_tacks=a,b,c: board i's own tack for a course race's start (SkipperConfig.start_tack: 0 either, 1 starboard,
	# 2 port), dealt round the boards (Max, 11 November 2026: some start on starboard, others on port).
	var tacks: PackedStringArray = options.get("start_tacks", "").split(",", false)
	if not tacks.is_empty():
		for i: int in entries.size():
			var tack_board: Skipper = entries[i].skipper as Skipper
			if tack_board != null:
				tack_board.config.start_tack = clampi(tacks[i % tacks.size()].to_int(), 0, 2) as SkipperConfig.StartTack


## The skipper's heads (8 November 2026): the boards are watched every this many ticks (_watch()).
const WATCH_EVERY: int = 30
## Phase S3 (10 November 2026): the start's score is taken this long after the gun (start_score_m()); boards within
## NEAR_M of another (centre to centre; RaceRules.CONTACT_M is 2) count as tangled from START_NEAR_FROM_S before the
## gun until then (note_the_crowd()).
const START_SCORE_AT_S: float = 30.0
const NEAR_M: float = 5.0
const START_NEAR_FROM_S: float = 30.0
## Dirty wind at the start (Max, 12 November 2026: "it's not wrong if they are close together but there is one with
## dirty wind"): from START_DIRTY_FROM_S before the gun to START_SCORE_AT_S after it, a board whose sail has under
## DIRTY_FACTOR of the wind (the other sails' shadows; SkipperConfig.dirty_air_share's default 0.15) counts dt_s
## (note_dirty_wind()).
const START_DIRTY_FROM_S: float = 10.0
const DIRTY_FACTOR: float = 0.85
## Under this speed on the board is stuck, under SLOW_MS slow, m/s; the first STUCK_GRACE_S after the
## gun or a drop (getting going from rest) do not count as stuck.
const STUCK_MS: float = 1.0
const SLOW_MS: float = 2.5
const STUCK_GRACE_S: float = 20.0
## A drop's time: this many times the all-rounder's expected time (TrainingDrops.expected_leg_s())
## plus DROP_TIME_EXTRA_S, unless --seconds says otherwise.
const DROP_TIME_FACTOR: float = 2.5
const DROP_TIME_EXTRA_S: float = 90.0
## A drop's spot has at least this much open water round it (ShoreLookout.openness_m()), metres.
const DROP_OPEN_M: float = 100.0
## A drop's spot: along the leg between these shares of it, and to the side of it by a random amount
## with this spread (a share of the leg, at most DROP_SIDE_MAX_M), metres.
const DROP_ALONG_FROM: float = 0.1
const DROP_ALONG_TO: float = 0.8
const DROP_SIDE_SHARE: float = 0.25
const DROP_SIDE_MAX_M: float = 250.0
## A drop's heading: up to this far either side of the leg's course; one nearer the wind than
## DROP_IRONS_DEG is turned to DROP_CLOSE_DEG off the wind on a random side.
const DROP_HEADING_DEG: float = 70.0
const DROP_IRONS_DEG: float = 40.0
const DROP_CLOSE_DEG: float = 55.0
## The rounding drill (--round_drill; 12 November 2026). Which marks: a gybe mark's legs in and out both at least
## ROUND_REACH_TWA_DEG off the wind, on opposite tacks, the turn between them through downwind; a top mark's leg in
## within ROUND_BEAT_TWA_DEG of the wind and its leg out at least ROUND_AWAY_TWA_DEG off it (a bear-away onto a reach or
## a run).
const ROUND_REACH_TWA_DEG: float = 60.0
const ROUND_BEAT_TWA_DEG: float = 60.0
const ROUND_AWAY_TWA_DEG: float = 80.0
## How far before the mark a board is set down by default, metres (it starts from rest: far enough to be going at the
## mark), and how wide the fan it may come from: a gybe mark's either side of the leg in, a top mark's either side of
## straight downwind of it (beyond the laylines too: overstood, or from the wrong side).
const ROUND_GYBE_FROM_M: float = 120.0
const ROUND_GYBE_TO_M: float = 260.0
const ROUND_TOP_FROM_M: float = 100.0
const ROUND_TOP_TO_M: float = 300.0
const ROUND_GYBE_FAN_DEG: float = 35.0
const ROUND_TOP_FAN_DEG: float = 80.0
## A gybe mark's legs and a gybe drill's way in are reaches, this far off the wind at most (deeper is a run).
const ROUND_GYBE_DEEPEST_TWA_DEG: float = 160.0
## A drill's spot keeps this much open water round it (the marks lie nearer the shore than the legs' middles).
const ROUND_OPEN_M: float = 60.0
## A drill's spot lies no further out than this share of the leg in (it must not start behind the mark before), and a
## gybe drill's board heads at the mark give or take ROUND_GYBE_HEADING_DEG.
const ROUND_LEG_SHARE: float = 0.9
const ROUND_GYBE_HEADING_DEG: float = 15.0
## The drill in company: a board's spot is drawn again up to this many times to be together with the first board's
## and apart from the others.
const ROUND_TOGETHER_TRIES: int = 60
## The boards of a drill in company are set down at least this far apart.
const ROUND_APART_M: float = 15.0
## The score is taken at ROUND_SCORE_FACTOR times the first board's expected time to the mark plus ROUND_SCORE_AFTER_S:
## about 25 s down the next leg (the smoke drills of 12 November 2026 reached the mark at 1.2 to 1.3 times the expected
## time, starting from rest; a beat's tacks cost the most). The same moment for every arm of a pair, so a pair compares
## the same seconds.
const ROUND_SCORE_FACTOR: float = 1.3
const ROUND_SCORE_AFTER_S: float = 25.0
## Speeds round the mark: in, when it first comes within ROUND_NEAR_M of it; the least from then until ROUND_MIN_UNTIL_S
## after the rounding counted; out, ROUND_OUT_AFTER_S after it counted.
const ROUND_NEAR_M: float = 30.0
const ROUND_MIN_UNTIL_S: float = 10.0
const ROUND_OUT_AFTER_S: float = 8.0
## --spawn=anywhere (anywhere_places()): the box round the course's marks and lines is this much wider each way,
## and a spot keeps this much open water round it (metres).
const ANYWHERE_MARGIN_M: float = 300.0
const ANYWHERE_OPEN_M: float = 60.0
## The random suite's courses moved or laid on the lake (course_on_lake_problem()): a mark at least this far from the
## shore, a leg at least this far (metres; the course fitter lays the saved ones at 200 and 50).
const SUITE_MARK_ROOM_M: float = 80.0
const SUITE_LEG_ROOM_M: float = 30.0
const COURSE_RULES_PATH: String = "res://maps/course/iqfoil_courses.tres"
## The random suite's new courses (fit_course_on_lake()): the course fitter's margins from the shore (metres) and the
## smallest size it may make them (% of the class's).
const SUITE_FIT_MARK_MARGIN_M: float = 150.0
const SUITE_FIT_LEG_MARGIN_M: float = 60.0
const SUITE_FIT_MIN_SIZE_PERCENT: float = 25.0

## The lake's shore grid, for the sailing area of a course on the lake (kept off the shore).
const SHORE_GRID_PATH: String = "res://maps/silvaplana/terrain/shore_heights.json"
## The all-rounder's hands (Game/race/skippers/allrounder.tres), for --steady_hands=1.
const STEADY_REACTION_S: float = 0.25
const STEADY_NOISE_DEG: float = 0.5
## A CSV row every this many ticks (0.1 s).
const CSV_EVERY: int = 6
const LAKE_ENVIRONMENT_PATH: String = "res://maps/silvaplana/environment_silvaplana.tres"

## --map=lake: the lake's environment and the hour of its wind (null: the open water).
static var _lake: EnvironmentConfig = null
static var _lake_time_s: float = 14.5 * 3600.0
## --pilot.<field> and --controller.<field> for every skipper's controller.
static var _controller_overrides: Dictionary[String, float] = {}
## --sailor.<field> for every skipper's sailor.
static var _sailor_overrides: Dictionary[String, float] = {}
## The sails' trails of disturbed air (WindShadowTrail; the shadows lie along them), made at the first tick with shadows.
static var _trail: WindShadowTrail = null
static var _overrides_read: bool = false


## One board in the race: its simulation, who sails it, and what is counted about it.
class Entry:
	var name: String = ""
	var sim: WindsurferSim
	var controls: SimControls
	## The 9A autopilot (--skippers=autopilot), or null.
	var pilot: Autopilot = null
	## A skipper on the beginner controller, with its hands on the controls (a scripted Skipper or a
	## LearnedSkipper); null for an autopilot.
	var skipper: RaceSkipper = null
	var controller: PlayerController = null
	var hands: AiHands = null
	## The race time from which the board is sailed (before it, it waits where it was put).
	var set_off_s: float = -INF
	var falls: int = 0
	var was_fallen: bool = false
	## On the lake: it ran aground and has stopped (_check_the_bottom()).
	var aground: bool = false
	## The tacks and gybes the controller started.
	var tacks: int = 0
	var gybes: int = 0
	var last_manoeuvre: PlayerController.Manoeuvre = PlayerController.Manoeuvre.NONE
	## The other sails' wind shadows on this board's wind (--shadows=1), or null.
	var shadows: WindShadows = null
	var file: FileAccess = null
	## Every fall with the 2 s before it (FallLog; null: not watched).
	var fall_log: FallLog = null
	## The whole telemetry, a row every 3 ticks (--trace=<board name>), or null.
	var trace_file: FileAccess = null
	## What _watch() counts (the skipper's heads, 8 November 2026), from the gun until the goal: the
	## race time the goal step was done (-1: not yet), the time watched, the time stuck (on the board
	## but under STUCK_MS) in all and the longest spell with what the skipper was doing then, the time
	## slow (under SLOW_MS), the least open water under it (ShoreLookout.openness_m()), and how far
	## its heading has turned in all, degrees (circling shows as far more than its manoeuvres).
	var goal_at_s: float = -1.0
	var watch_s: float = 0.0
	var stuck_s: float = 0.0
	var stuck_run_s: float = 0.0
	var longest_stuck_s: float = 0.0
	var stuck_note: String = ""
	var slow_s: float = 0.0
	var min_open_m: float = INF
	var turn_deg: float = 0.0
	var last_heading_deg: float = NAN
	## Where and why it ran aground, if it did.
	var aground_note: String = ""
	## Its falls before the gun (the start's head).
	var falls_before_gun: int = 0
	## The penalties already printed (judge()).
	var penalties_seen: int = 0
	## Where it was when the countdown began (the random suite's start check), and at every R.
	var spawn_at: Vector2 = Vector2.INF
	## At the gun (phase S's measures): its speed, how far behind the start line it was (perpendicular to the
	## line; negative: over it), how far from the line's segment, and whether it was over early.
	var gun_speed_ms: float = NAN
	var gun_behind_m: float = NAN
	var gun_to_line_m: float = NAN
	var gun_ocs: bool = false
	## Phase S3's measures (Max, 10 November 2026: "a measuring feature that will award the players to go as fast over
	## the line as possible"): its speed when its start counted, and how far up the course it was START_SCORE_AT_S
	## after the gun (start_score_m()); the time it spent within NEAR_M of another board from START_NEAR_FROM_S before
	## the gun to START_SCORE_AT_S after it (boards tangled up in each other); and the wind at the gun: the race's 10 m
	## mean (the telemetry, on the lake the lake's mean) and what its own sail felt (FeltWind: now, the last 60 s's mean
	## and spread), to see the lulls the start was sailed in.
	var cross_speed_ms: float = NAN
	var score_m: float = NAN
	var near_s: float = 0.0
	## Seconds in dirty wind round the start, and the wind it lost there (seconds of the whole wind; note_dirty_wind()).
	var dirty_s: float = 0.0
	var wind_lost_s: float = 0.0
	var gun_mean_kt: float = NAN
	var gun_felt_kt: float = NAN
	var gun_felt_60s_kt: float = NAN
	var gun_felt_spread_kt: float = NAN
	## The rounding drill's measures (note_the_drill()): the race time the rounding counted (-1: not yet), the speeds
	## in, through (the least) and out, and the score (course_progress_m() past the mark at the drill's score time).
	var drill_rounded_s: float = -1.0
	var drill_in_ms: float = NAN
	var drill_min_ms: float = NAN
	var drill_out_ms: float = NAN
	var drill_score_m: float = NAN
	## Where it was set down, its distance to the mark then, the wind angle of the straight way in, and the tacks and
	## gybes up to the rounding.
	var drill_drop_m: float = 0.0
	var drill_approach_twa_deg: float = 0.0
	var drill_tacks_in: int = -1
	var drill_gybes_in: int = -1


func _initialize() -> void:
	var options: Dictionary[String, String] = _read_user_args()
	var names: PackedStringArray = options.get("skippers", "autopilot").split(",", false)
	if names.is_empty():
		names = PackedStringArray(["autopilot"])
	var boards: int = maxi(options.get("boards", str(names.size())).to_int(), 1)
	var laps: int = maxi(options.get("laps", "1").to_int(), 1)
	var wind_kt: float = options.get("wind_kt", "15").to_float()
	# The skippers sail the game's whole countdown and the whole race (it ends when everyone is in);
	# the 9A autopilot only the last 10 s of the countdown, and it never finishes.
	var all_autopilot: bool = Array(names).all(func(skipper_name: String) -> bool: return skipper_name == "autopilot")
	var seconds: float = options.get("seconds", "300" if all_autopilot else "0").to_float()
	var prestart_s: float = maxf(options.get("prestart", "10" if all_autopilot else "60").to_float(), 0.0)
	var twa_deg: float = options.get("twa", "50").to_float()
	var random_seed: int = options.get("seed", "0").to_int()
	var level_spread: float = clampf(options.get("spread", "1").to_float(), 0.0, 1.0)
	var finish_window_s: float = options.get("finish_window", "60").to_float()
	var out_dir: String = options.get("out_dir", _repository_path(".sim_output/race"))
	var spawn: String = options.get("spawn", "line")
	var spawn_seed: int = options.get("spawn_seed", "0").to_int()
	var free_sail_s: float = maxf(options.get("free_sail", "0").to_float(), 0.0)
	var stop_after_gun_s: float = options["stop_after_gun"].to_float() if options.has("stop_after_gun") else INF
	var behind_m: float = options.get("behind", "-1").to_float()
	var blind: bool = options.get("blind", "0") != "0"
	var shadows: bool = options.get("shadows", "1") != "0"
	var with_rules: bool = options.get("rules", "1") != "0"
	var with_gear: bool = options.get("gear", "1") != "0"
	var shore_guard: bool = options.get("shore_guard", "1") != "0"
	var skipper_push: bool = options.get("skipper_push", "1") != "0"
	var steady_hands: bool = options.get("steady_hands", "0") == "1"
	var polar_path: String = options.get("polar", "")
	# A drop (--drop_step): the boards are set down on a leg after the gun, with no countdown.
	var drop_step_text: String = options.get("drop_step", "")
	# The rounding drill (--round_drill=gybe|top): a drop at one mark of that kind, scored ROUND_SCORE_AFTER_S after the
	# expected time to it.
	var drill_kind: String = options.get("round_drill", "")
	var drilling: bool = drill_kind != ""
	var drill_score_at_s: float = INF
	var dropping: bool = drop_step_text != "" or drilling
	if dropping:
		prestart_s = 0.0
	if options.get("map", "open") == "lake":
		_lake = load(LAKE_ENVIRONMENT_PATH)
		var clock: PackedStringArray = options.get("time", "14:30").split(":")
		_lake_time_s = clock[0].to_float() * 3600.0 + (clock[1].to_float() * 60.0 if clock.size() > 1 else 0.0)
		wind_kt = _lake.map_wind().moment(_lake_time_s).lake_speed_ms / SimMath.KNOT_MS
		print("On Lake Silvaplana at %s: the lake's mean wind %.1f kt from %.0f deg, its own waves" % [
			options.get("time", "14:30"), wind_kt, _lake.map_wind().lake_from_deg(_lake_time_s)])
	for key: String in options:
		if key.begins_with("pilot.") or key.begins_with("controller."):
			_controller_overrides[key] = options[key].to_float()
		elif key.begins_with("sailor."):
			_sailor_overrides[key.trim_prefix("sailor.")] = options[key].to_float()

	# --min_wind_kt=<kt> (the random suite; Max, 8 November 2026: below planing the AI's numbers say nothing): a race
	# whose wind (the lake's mean of the hour times --lake_wind_scale) is lighter is refused, to be drawn again.
	if options.has("min_wind_kt"):
		var sailed_kt: float = wind_kt * (options.get("lake_wind_scale", "1").to_float() if _lake != null else 1.0)
		if sailed_kt < options["min_wind_kt"].to_float():
			print("WIND_TOO_LOW %.1f kt" % sailed_kt)
			quit(3)
			return
	var course_name: String = options.get("course", "test")
	var course: Course = null
	if course_name.begins_with("fit:"):
		# --course=fit:<template> --fit_at=<x>,<z>: a new course laid on the lake (the random suite, 8 November 2026).
		course = fit_course_on_lake(course_name.trim_prefix("fit:"), options.get("fit_at", ""), wind_kt)
		if course == null:
			print("COURSE_ILLEGAL nothing fits")
			quit(3)
			return
	else:
		course = course_named(course_name)
	if course == null:
		quit(2)
		return
	# --course_turn=<deg> --course_shift=<dx>,<dz>: the course turned about its start and moved (the random suite:
	# the same course a little elsewhere). On the lake a course that then lies on land or near the shore is refused.
	if options.has("course_turn") or options.has("course_shift"):
		var pivot: Vector2 = course.start_middle()
		course.turn_about(pivot, options.get("course_turn", "0").to_float())
		var shift: PackedStringArray = options.get("course_shift", "0,0").split(",")
		course.move_by(Vector2(shift[0].to_float(), shift[1].to_float() if shift.size() > 1 else 0.0))
	if _lake != null and (options.has("course_turn") or options.has("course_shift") or course_name.begins_with("fit:")):
		var why: String = course_on_lake_problem(course)
		if why != "":
			print("COURSE_ILLEGAL " + why)
			quit(3)
			return
	if options.has("race_type"):
		# --race_type=slalom|course|hybrid|free: the course raced as that type (Course.RaceType).
		course.race_type = Course.race_type_from_name(options["race_type"])
	if options.has("start_type"):
		# --start_type=slalom|course: the course started that way (Course.StartType).
		course.start_type = Course.start_type_from_name(options["start_type"])
	var race: RaceSim = RaceSim.new(course, laps, prestart_s)
	race.finish_window_s = finish_window_s
	# The race's own time limit for its course and wind, as the game sets it; --seconds raises it.
	race.time_limit_s = maxf(RaceTimeLimit.for_race(race, course.axis_deg, wind_kt), seconds)
	if not all_autopilot and not options.has("seconds"):
		seconds = race.time_limit_s
	if race.steps().is_empty():
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(out_dir)
	var area: SailingArea = sailing_area_for(course_name, course)

	var who: PackedStringArray = PackedStringArray()
	for i: int in boards:
		who.append(names[i % names.size()])
	var entries: Array[Entry] = make_entries(race, course, who, wind_kt, twa_deg, random_seed, spawn, area, spawn_seed, behind_m, with_gear, level_spread)
	if entries.is_empty():
		quit(2)
		return
	if options.has("manoeuvre_gap_s"):
		for entry: Entry in entries:
			var learned: LearnedSkipper = entry.skipper as LearnedSkipper
			if learned != null:
				learned.manoeuvre_gap_s = maxf(options["manoeuvre_gap_s"].to_float(), 0.0)
	if options.has("closest_twa_deg"):
		for entry: Entry in entries:
			var learned: LearnedSkipper = entry.skipper as LearnedSkipper
			if learned != null:
				learned.closest_twa_deg = clampf(options["closest_twa_deg"].to_float(), 0.0, 90.0)
	if shadows:
		give_shadows(entries, options.get("shadow_trail", "1") != "0")
	# The lake's bottom: where a board runs aground, and what the skippers see of the shore.
	var bottom: TerrainGrid = null
	if _lake != null:
		bottom = _lake.depth_grid()
		if bottom == null:
			bottom = TerrainGrid.load_from(SHORE_GRID_PATH)
		if shore_guard:
			var lookout: ShoreLookout = ShoreLookout.for_lake(bottom, course.start_middle())
			for entry: Entry in entries:
				if entry.skipper != null:
					entry.skipper.shore = lookout
	var rules: RaceRules = give_rules(entries, race, course) if with_rules else null
	# --spawn=anywhere: every board put anywhere round the course before the countdown (anywhere_places()).
	var anywhere_lookout: ShoreLookout = ShoreLookout.for_lake(bottom, course.start_middle()) if bottom != null else null
	var anywhere_wind_deg: float = _lake.map_wind().lake_from_deg(_lake_time_s) if _lake != null else course.axis_deg
	if spawn == "anywhere" and not dropping:
		var spots: Array[Vector3] = anywhere_places(race, entries.size(), spawn_seed, anywhere_lookout, anywhere_wind_deg)
		for i: int in entries.size():
			entries[i].sim.reset(Vector3(spots[i].x, 0.0, spots[i].y), deg_to_rad(spots[i].z))
			if entries[i].controller != null:
				entries[i].controller.reset_controls(entries[i].controls)
			race.update_board(i, _where(entries[i]))
		for i: int in entries.size():
			if entries[i].skipper != null:
				entries[i].skipper.setup(entries[i].sim, entries[i].controller, entries[i].hands, race, i)
	# The drop: every board set down on the leg to the drop's step (the skipper's heads, 8 November).
	var drop_index: int = 0
	var goal_index: int = race.steps().size()
	if dropping:
		var drop_rng: RandomNumberGenerator = RandomNumberGenerator.new()
		drop_rng.seed = options.get("drop_seed", "1").to_int()
		var drop_lookout: ShoreLookout = ShoreLookout.for_lake(bottom, course.start_middle()) if bottom != null else null
		var wind_from_deg: float = _lake.map_wind().lake_from_deg(_lake_time_s) if _lake != null else course.axis_deg
		# The drill reckons its times in the wind the race is sailed in (the lake's mean times --lake_wind_scale).
		var drill_wind_kt: float = wind_kt * (options.get("lake_wind_scale", "1").to_float() if _lake != null else 1.0)
		var drill_rng: RandomNumberGenerator = RandomNumberGenerator.new()
		drill_rng.seed = options.get("round_seed", "1").to_int()
		if drilling:
			var drill_marks: Array[int] = round_drill_marks(race, wind_from_deg, drill_kind)
			if drill_marks.is_empty():
				print("DRILL_NONE no %s mark on %s" % [drill_kind, course.name])
				quit(3)
				return
			drop_index = drill_marks[drill_rng.randi_range(0, drill_marks.size() - 1)]
			goal_index = drop_index + 1
		else:
			drop_index = drop_step_text.to_int() if drop_step_text != "random" else drop_rng.randi_range(1, race.steps().size() - 1)
			drop_index = clampi(drop_index, 1, race.steps().size() - 1)
			goal_index = mini(drop_index + maxi(options.get("goal_steps", "2").to_int(), 1), race.steps().size())
		# The gun first (no countdown), then the boards set down: a board put on the course side
		# before the gun would count as over the line early.
		race.start()
		if drilling:
			var top: bool = drill_kind == "top"
			var range_m: PackedStringArray = options.get("round_from_m", "").split(",")
			var from_m: float = range_m[0].to_float() if range_m.size() == 2 else (ROUND_TOP_FROM_M if top else ROUND_GYBE_FROM_M)
			var to_m: float = range_m[1].to_float() if range_m.size() == 2 else (ROUND_TOP_TO_M if top else ROUND_GYBE_TO_M)
			place_drill(race, entries, drop_index, drill_kind, wind_from_deg, drill_rng, drop_lookout, from_m, to_m,
				options.get("round_together_s", "0").to_float(), course.axis_deg, drill_wind_kt, options.get("round_group_deg", "0").to_float())
		else:
			for i: int in entries.size():
				var spot: Vector3 = drop_spot(race, drop_index, wind_from_deg, drop_rng, drop_lookout)
				entries[i].sim.reset(Vector3(spot.x, 0.0, spot.y), deg_to_rad(spot.z))
				entries[i].controller.reset_controls(entries[i].controls)
				race.place_board(i, Vector2(spot.x, spot.y), drop_index)
		for i: int in entries.size():
			if entries[i].skipper != null:
				entries[i].skipper.setup(entries[i].sim, entries[i].controller, entries[i].hands, race, i)
		var expected_s: float = expected_time_s(race, drop_index, goal_index, Vector2(entries[0].sim.telemetry.position.x, entries[0].sim.telemetry.position.z), course.axis_deg,
			drill_wind_kt if drilling else wind_kt)
		options["expected_s"] = str(expected_s)
		if drilling:
			drill_score_at_s = ROUND_SCORE_FACTOR * expected_s + ROUND_SCORE_AFTER_S
			if not options.has("seconds"):
				seconds = drill_score_at_s + 1.0
			print("DRILL %s at step %d (%s), %d board%s, the first %.0f m out, %.0f s expected to the mark, scored at %.0f s" % [
				drill_kind, drop_index, race.steps()[drop_index].name, entries.size(), "" if entries.size() == 1 else "s",
				entries[0].drill_drop_m, expected_s, drill_score_at_s])
		else:
			if not options.has("seconds"):
				seconds = DROP_TIME_FACTOR * expected_s + DROP_TIME_EXTRA_S
			print("DROP on the way to step %d (%s), goal step %d, %.0f s expected, %.0f s allowed" % [
				drop_index, race.steps()[drop_index].name, goal_index, expected_s, seconds])
	if steady_hands:
		steady_the_hands(entries)
	if not tune_skippers(entries, skipper_push, polar_path):
		quit(2)
		return
	print_sheets(entries)
	var file_names: Dictionary[String, int] = {}
	for entry: Entry in entries:
		# One file per board, whatever the names: a second board of the same name gets _2.
		var file_name: String = _file_name(entry.name)
		file_names[file_name] = file_names.get(file_name, 0) + 1
		if file_names[file_name] > 1:
			file_name += "_%d" % file_names[file_name]
		entry.file = FileAccess.open(out_dir.path_join(file_name + ".csv"), FileAccess.WRITE)
		if entry.file != null:
			entry.file.store_line("race_time_s,x_m,z_m,heading_deg,speed_ms,next_step,doing,aim_x_m,aim_z_m")
		# Every fall with the 2 s before it and what the skipper was doing (FALL_DETAIL lines, for
		# tools/fall_detail.py).
		var clock_text: String = options.get("time", "14:30") if _lake != null else "-"
		entry.fall_log = FallLog.new("race", entry.name.replace(",", ";"), clock_text, "lake" if _lake != null else "open%.0f" % wind_kt)
		if options.get("trace", "") == entry.name:
			entry.trace_file = FileAccess.open(out_dir.path_join("trace_%s.csv" % file_name), FileAccess.WRITE)
			if entry.trace_file != null:
				entry.trace_file.store_line(Telemetry.csv_header())
	apply_skipper_overrides(entries, options)
	# Phase S (9 November 2026): start-only races from reachable drops.
	var start_only: bool = options.get("start_only", "0") != "0"
	var start_watch_s: float = options.get("start_watch_s", "60").to_float()
	# Phase S3: the start-only race goes on this long after the gun even when every board is over (the score at 30 s).
	var start_follow_s: float = options.get("start_follow_s", "0").to_float()
	var start_spare_s: float = options["start_spare_s"].to_float() if options.has("start_spare_s") and not dropping else -INF
	var timing_wind_kt: float = wind_kt * options.get("lake_wind_scale", "1").to_float()
	if start_spare_s > -INF:
		var too_far: String = drop_too_far(race, entries, course.axis_deg, timing_wind_kt, prestart_s, start_spare_s)
		if too_far != "":
			print("DROP_TOO_FAR " + too_far)
			quit(3)
			return
	race.start_in(free_sail_s)
	print("COURSE_JSON " + course_json(race, course.axis_deg))

	var outside_at_gun: PackedStringArray = PackedStringArray()
	var gun_seen: bool = false
	var ticks: int = roundi((free_sail_s + prestart_s + seconds) / DT)
	var aground_count: int = 0
	var watch_lookout: ShoreLookout = ShoreLookout.for_lake(bottom, course.start_middle()) if bottom != null else null
	# --restart_after=<s>: the game's R that long after the gun (restart_race()); what is reported is the second race.
	var restart_after_s: float = options["restart_after"].to_float() if options.has("restart_after") and not dropping else INF
	var restarted: bool = false
	var tick: int = 0
	while tick < ticks:
		tick += 1
		if tick == 1:
			for entry: Entry in entries:
				entry.spawn_at = _where(entry)
		if not restarted and race.is_started() and (race.clock_s() >= restart_after_s or race.phase() == RaceSim.Phase.FINISHED):
			restarted = true
			var restart_seed: int = options.get("restart_spawn_seed", str(spawn_seed + 1000)).to_int()
			var restart_places: Array[Vector3] = anywhere_places(race, entries.size(), restart_seed, anywhere_lookout, anywhere_wind_deg) \
				if spawn == "anywhere" else area.spawn_places(entries.size(), restart_seed)
			race = restart_race(race, course, laps, prestart_s, entries, restart_places, random_seed + 1000)
			rules = give_rules(entries, race, course) if with_rules else null
			apply_skipper_overrides(entries, options)
			aground_count = 0
			gun_seen = false
			tick = 0
			ticks = roundi((prestart_s + seconds) / DT)
			print("RESTART (the game's R) at race time %.0f s: the same skippers set up again, new random spots" % restart_after_s)
			if start_spare_s > -INF:
				var too_far_after_r: String = drop_too_far(race, entries, course.axis_deg, timing_wind_kt, prestart_s, start_spare_s)
				if too_far_after_r != "":
					print("DROP_TOO_FAR after the R: " + too_far_after_r)
					quit(3)
					return
		step_race(race, entries, blind, rules)
		if bottom != null:
			aground_count += _check_the_bottom(bottom, race, entries)
		for i: int in entries.size():
			note_the_start(entries[i], race, i)
			if drilling:
				note_the_drill(entries[i], race, i, drop_index, drill_score_at_s)
		if tick % CSV_EVERY == 0:
			for i: int in entries.size():
				_write_row(entries[i], race, i)
		if tick % WATCH_EVERY == 0:
			for i: int in entries.size():
				_watch(entries[i], race, i, goal_index, watch_lookout)
			# A drill is watched from the drop to its score; a race round its start.
			var watch_from_s: float = 0.0 if drilling else -START_NEAR_FROM_S
			var dirty_from_s: float = 0.0 if drilling else -START_DIRTY_FROM_S
			var watch_until_s: float = drill_score_at_s if drilling else START_SCORE_AT_S
			note_the_crowd(race, entries, WATCH_EVERY * DT, watch_from_s, watch_until_s)
			note_dirty_wind(race, entries, WATCH_EVERY * DT, dirty_from_s, watch_until_s)
		if not gun_seen and race.is_started() and race.clock_s() >= 0.0:
			gun_seen = true
			outside_at_gun = boards_outside(race, area)
			for i: int in entries.size():
				note_the_gun(entries[i], race, i)
		if restart_after_s < INF and not restarted:
			continue  # the first race of a restart is sailed until the R
		if race.phase() == RaceSim.Phase.FINISHED or race.clock_s() >= stop_after_gun_s:
			break
		if start_only and race.clock_s() >= 0.0 and (race.clock_s() >= start_watch_s or (all_over_the_line(race, entries) and race.clock_s() >= start_follow_s)):
			break
		if drilling and race.clock_s() >= drill_score_at_s:
			break
		if dropping and not drilling and entries.all(func(e: Entry) -> bool: return e.goal_at_s >= 0.0 or e.aground):
			break
	# A drill that ended before its score time (every board over the finish soon after the mark): the score as it is now,
	# the whole course for a board that finished.
	if drilling:
		for i: int in entries.size():
			if is_nan(entries[i].drill_score_m):
				entries[i].drill_score_m = course_progress_m(race, i) - step_progress_m(race, drop_index)
	# The goal reached on the very last tick (the race over at the finish) still counts.
	for i: int in entries.size():
		if entries[i].goal_at_s < 0.0 and race.next_step_index(i) >= goal_index:
			entries[i].goal_at_s = race.finish_time_s(i) if race.is_finished(i) else race.clock_s()
	for entry: Entry in entries:
		if entry.file != null:
			entry.file.close()

	print("Race on %s (%s, %d lap%s, %d steps): wind %.0f kt from %.0f deg, %s, seed %d, pre-start %.0f s, spawn %s (seed %d)%s" % [
		course.name, course.sequence, laps, "" if laps == 1 else "s", race.steps().size(), wind_kt, course.axis_deg,
		", ".join(who) + (" at TWA %.0f" % twa_deg if who.has("autopilot") else ""), random_seed, prestart_s, spawn, spawn_seed,
		(", wind shadows" if shadows else "") + (", the rules" if with_rules else "")])
	for result: RaceResult in race.results():
		var entry: Entry = entries[result.index]
		# An unfinished board: how far it still is from its next step, so that boards that never
		# finish can still be compared (the generations of a night, tools/gens.sh).
		var to_next: String = "" if result.finished else "  to %s %.0f m" % [race.next_step_name(result.index), race.distance_to_next_m(result.index)]
		print("%s  falls %d  tacks %d  gybes %d%s" % [result.to_line(), entry.falls, entry.tacks, entry.gybes, to_next])
	print("%s at race time %s; CSV files in %s" % [
		"Finished" if race.phase() == RaceSim.Phase.FINISHED else "Stopped", RaceResult.format_time(race.race_time_s()), out_dir])
	print(start_report(race, entries, outside_at_gun))
	if rules != null:
		print(penalty_report(rules, entries))
	if bottom != null:
		print("Aground: %d of %d boards%s" % [aground_count, entries.size(), " (the skippers look out for the shore)" if shore_guard else " (no shore lookout)"])
	var legs_expected: Array = []
	for k: int in range(1, race.steps().size()):
		legs_expected.append(snappedf(TrainingDrops.expected_leg_s(race.steps()[k - 1].target(), race.steps()[k].target(), course.axis_deg, timing_wind_kt), 0.1))
	var expected_all_s: float = expected_time_s(race, drop_index, goal_index, Vector2(INF, INF), course.axis_deg, wind_kt) if not dropping else 0.0
	for i: int in entries.size():
		var result: Dictionary = heads_result(entries[i], race, i, drop_index, goal_index, expected_all_s, options)
		result["penalties"] = rules.penalties(i) + rules.turns_done(i) if rules != null else 0
		if rules != null and result["penalties"] > 0:
			result["penalty_note"] = "last at %.0f s: %s" % [rules.last_breach_s(i), rules.breach_text(i)]
		result["falls_before_gun"] = entries[i].falls_before_gun
		# The random suite's numbers: where it began, the time it needed from there to the line, and each leg's expected
		# time (the all-rounder's, TrainingDrops.expected_leg_s()) in the wind the race was sailed in.
		result["spawn"] = [snappedf(entries[i].spawn_at.x, 0.1), snappedf(entries[i].spawn_at.y, 0.1)] if entries[i].spawn_at.x != INF else []
		result["start_need_s"] = TrainingDrops.expected_leg_s(entries[i].spawn_at, race.steps()[0].target(), course.axis_deg, timing_wind_kt) if entries[i].spawn_at.x != INF else 0.0
		result["legs_expected"] = legs_expected
		result["prestart_s"] = prestart_s
		# Phase S's measures: at the gun, and whether the race was start-only and restarted.
		result["start_only"] = start_only
		result["restarted"] = restarted
		result["gun_speed_ms"] = snappedf(entries[i].gun_speed_ms, 0.01) if not is_nan(entries[i].gun_speed_ms) else -1.0
		result["gun_behind_m"] = snappedf(entries[i].gun_behind_m, 0.1) if not is_nan(entries[i].gun_behind_m) else 0.0
		result["gun_to_line_m"] = snappedf(entries[i].gun_to_line_m, 0.1) if not is_nan(entries[i].gun_to_line_m) else -1.0
		result["ocs_at_gun"] = entries[i].gun_ocs
		# Phase S3's measures (-1 or null when not reached: the race ended before 30 s after the gun, or no start).
		result["cross_speed_ms"] = snappedf(entries[i].cross_speed_ms, 0.01) if not is_nan(entries[i].cross_speed_ms) else -1.0
		result["score_m"] = snappedf(entries[i].score_m, 0.1) if not is_nan(entries[i].score_m) else null
		result["near_s"] = snappedf(entries[i].near_s, 0.1)
		result["dirty_s"] = snappedf(entries[i].dirty_s, 0.1)
		result["wind_lost_s"] = snappedf(entries[i].wind_lost_s, 0.01)
		result["boards"] = entries.size()
		if drilling:
			result["drill"] = drill_result(entries[i], race, drop_index, drill_kind, drill_score_at_s)
		for key: String in ["gun_mean_kt", "gun_felt_kt", "gun_felt_60s_kt", "gun_felt_spread_kt"]:
			var value: float = entries[i].get(key)
			result[key] = snappedf(value, 0.1) if not is_nan(value) else null
		print("HEADS_RESULT " + JSON.stringify(result))
	quit(0)


## --start_spare_s (phase S, Max's choice of 9 November 2026: only drops that can reach the line with 30 s to spare):
## the first board whose way to the start line (the start check's own estimate, TrainingDrops.expected_leg_s(), from
## where it is now) takes longer than the countdown less spare_s, as "<board> needs <n> s of <countdown>"; "" when
## every board can make it.
static func drop_too_far(race: RaceSim, entries: Array[Entry], axis_deg: float, wind_kt: float, countdown_s: float, spare_s: float) -> String:
	for entry: Entry in entries:
		var need_s: float = TrainingDrops.expected_leg_s(_where(entry), race.steps()[0].target(), axis_deg, wind_kt)
		if not start_reachable(need_s, countdown_s, spare_s):
			return "%s needs %.0f s of %.0f (spare %.0f)" % [entry.name.replace(" ", "_"), need_s, countdown_s, spare_s]
	return ""


## A drop can reach the start line in time: its start need at most the countdown less the spare seconds.
static func start_reachable(need_s: float, countdown_s: float, spare_s: float) -> bool:
	return need_s <= countdown_s - spare_s


## At the gun (phase S): the board's speed, how far behind the start line it is (negative: over it), how far from the
## line's segment, and whether it is over early.
static func note_the_gun(entry: Entry, race: RaceSim, index: int) -> void:
	var line: RaceStep = race.steps()[0]
	var at: Vector2 = _where(entry)
	entry.gun_speed_ms = entry.sim.telemetry.speed_ms
	entry.gun_behind_m = -RoundingCheck.over_line_m(at, line.points[0], line.points[1], line.in_dir)
	entry.gun_to_line_m = Geometry2D.get_closest_point_to_segment(at, line.points[0], line.points[1]).distance_to(at)
	entry.gun_ocs = race.is_ocs(index)
	entry.gun_mean_kt = entry.sim.telemetry.tws_10m_kt
	var scripted: Skipper = entry.skipper as Skipper
	if scripted != null and scripted.felt.count() > 0:
		entry.gun_felt_kt = scripted.felt.now_kt()
		entry.gun_felt_60s_kt = scripted.felt.mean_kt(60.0)
		entry.gun_felt_spread_kt = scripted.felt.spread_kt(60.0)


## The start's score (phase S3, Max, 10 November 2026: "award the players to go as fast over the line as possible ...
## this way you have the best start"): how far up the course the board is START_SCORE_AT_S after the gun, metres: how
## much nearer the first mark (or gate) it is than the start line's middle. A late start, a slow crossing, a crossing
## at the far end, dirty air or a tangle after the gun all cost metres; over early it must come back, which costs more.
## Not started yet (late, or over early and not back): minus its distance from the line, whichever side it is on.
static func start_score_m(race: RaceSim, index: int, at: Vector2) -> float:
	var steps: Array[RaceStep] = race.steps()
	var line: RaceStep = steps[0]
	if race.next_step_index(index) == 0 or steps.size() < 2:
		return -absf(RoundingCheck.over_line_m(at, line.points[0], line.points[1], line.in_dir))
	return steps[1].distance_from(line.target()) - steps[1].distance_from(at)


## The start's measures each tick after the gun (phase S3): the speed when its start counted, and the score at
## START_SCORE_AT_S.
static func note_the_start(entry: Entry, race: RaceSim, index: int) -> void:
	var now_s: float = race.clock_s()
	if now_s < 0.0:
		return
	if is_nan(entry.cross_speed_ms) and race.next_step_index(index) > 0:
		entry.cross_speed_ms = entry.sim.telemetry.speed_ms
	if is_nan(entry.score_m) and now_s >= START_SCORE_AT_S:
		entry.score_m = start_score_m(race, index, _where(entry))


## Boards tangled up in each other round the start (phase S3; Max, 10 November 2026: "sometimes in testing they get
## stuck in each other"; the boards pass through each other, so a tangle shows as time spent close): each board within
## NEAR_M of another from START_NEAR_FROM_S before the gun to START_SCORE_AT_S after it counts dt_s.
static func note_the_crowd(race: RaceSim, entries: Array[Entry], dt_s: float, from_s: float = -START_NEAR_FROM_S,
		until_s: float = START_SCORE_AT_S) -> void:
	var now_s: float = race.clock_s()
	if not race.is_started() or now_s < from_s or now_s > until_s or entries.size() < 2:
		return
	for i: int in entries.size():
		var here: Vector2 = _where(entries[i])
		for j: int in entries.size():
			if j != i and here.distance_to(_where(entries[j])) <= NEAR_M:
				entries[i].near_s += dt_s
				break


## Dirty wind round the start (phase S3; Max, 12 November 2026): each board with its sail up whose wind the other sails'
## shadows leave under DIRTY_FACTOR, from START_DIRTY_FROM_S before the gun to START_SCORE_AT_S after it, counts dt_s;
## and every board adds the wind it lost (1 less the shadows' factor) times dt_s. Read only: the races stay the same.
static func note_dirty_wind(race: RaceSim, entries: Array[Entry], dt_s: float, from_s: float = -START_DIRTY_FROM_S,
		until_s: float = START_SCORE_AT_S) -> void:
	var now_s: float = race.clock_s()
	if not race.is_started() or now_s < from_s or now_s > until_s or entries.size() < 2:
		return
	for entry: Entry in entries:
		if entry.shadows == null or entry.sim.sailor_state != WindsurferSim.SailorState.SAILING:
			continue
		var telemetry: Telemetry = entry.sim.telemetry
		var downwind: Vector2 = Course.direction_of(telemetry.wind_from_bearing_deg + 180.0)
		var factor: float = entry.shadows.factor_at(telemetry.position, Vector3(downwind.x, 0.0, downwind.y))
		entry.wind_lost_s += (1.0 - factor) * dt_s
		if factor < DIRTY_FACTOR:
			entry.dirty_s += dt_s


## Every board over the start line (its start counted) or aground: a start-only race is over.
static func all_over_the_line(race: RaceSim, entries: Array[Entry]) -> bool:
	for i: int in entries.size():
		if race.splits_s(i).is_empty() and not entries[i].aground:
			return false
	return true


## The boards whose fin has touched the lake's bottom this tick (ShoreCheck, as the game's): stopped
## where they are, each with an AGROUND line. How many ran aground now.
static func _check_the_bottom(bottom: TerrainGrid, race: RaceSim, entries: Array[Entry]) -> int:
	var count: int = 0
	for i: int in entries.size():
		var entry: Entry = entries[i]
		if entry.aground or race.is_finished(i) and race.phase() == RaceSim.Phase.FINISHED:
			continue
		if ShoreCheck.is_aground(bottom, entry.sim.body.origin_world(), entry.sim.fin_config.span_m):
			entry.aground = true
			count += 1
			var at: Vector2 = _where(entry)
			entry.aground_note = "%.0f s (%.0f, %.0f) to %s: %s" % [race.clock_s(), at.x, at.y, race.next_step_name(i),
				entry.skipper.note if entry.skipper != null else "autopilot"]
			print("AGROUND %s at race time %.1f s, (%.0f, %.0f), heading %.0f deg, %.1f m/s, sailing to %s: %s" % [
				entry.name.replace(" ", "_"), race.clock_s(), at.x, at.y, entry.sim.telemetry.heading_deg, entry.sim.telemetry.speed_ms,
				race.next_step_name(i), entry.skipper.note if entry.skipper != null else "autopilot"])
	return count


## --restart_after (Max, 8 November 2026: "if I press R the AI lost their minds"): what the game's R does
## (RaceRunner.restart()), for the tool. A new race on the same course, the same boards and the same skipper
## objects set up again on it (skipper.setup(), as the game does: every race before this tool's only ever had
## fresh skippers), each board at a new random spot of the sailing area, at rest, and the countdown at once.
## The boards' counts start again, so the results are the second race's.
static func restart_race(old: RaceSim, course: Course, laps: int, prestart_s: float, entries: Array[Entry], places: Array[Vector3],
		skipper_seed: int) -> RaceSim:
	var race: RaceSim = RaceSim.new(course, laps, prestart_s)
	race.finish_window_s = old.finish_window_s
	race.time_limit_s = old.time_limit_s
	for i: int in entries.size():
		var entry: Entry = entries[i]
		entry.sim.reset(Vector3(places[i].x, 0.0, places[i].y), deg_to_rad(places[i].z))
		if entry.controller != null:
			entry.controller.reset_controls(entry.controls)
		entry.falls = 0
		entry.was_fallen = false
		entry.aground = false
		entry.aground_note = ""
		entry.tacks = 0
		entry.gybes = 0
		entry.last_manoeuvre = PlayerController.Manoeuvre.NONE
		entry.goal_at_s = -1.0
		entry.watch_s = 0.0
		entry.stuck_s = 0.0
		entry.stuck_run_s = 0.0
		entry.longest_stuck_s = 0.0
		entry.stuck_note = ""
		entry.slow_s = 0.0
		entry.min_open_m = INF
		entry.turn_deg = 0.0
		entry.last_heading_deg = NAN
		entry.falls_before_gun = 0
		entry.penalties_seen = 0
		# The start's measures are the new race's (the gun's are taken again at its gun).
		entry.cross_speed_ms = NAN
		entry.score_m = NAN
		entry.near_s = 0.0
		entry.dirty_s = 0.0
		entry.wind_lost_s = 0.0
		race.add_board(entry.name)
		race.update_board(i, _where(entry))
	for i: int in entries.size():
		if entries[i].skipper != null:
			entries[i].skipper.random_seed = skipper_seed + i
			entries[i].skipper.setup(entries[i].sim, entries[i].controller, entries[i].hands, race, i)
	race.start_in(0.0)
	return race


## --course=fit:<template> (the random suite, 8 November 2026): an iQFOiL template laid on Lake Silvaplana by the
## course fitter (as tools/fit_courses.sh lays the saved ones), square to the lake's mean wind of the hour and sized
## for it, for 12 boards, as near to `fit_at` ("x,z", game metres; the lake scene's start when empty) as it fits.
## Null when nothing fits.
func fit_course_on_lake(template_id: String, fit_at: String, lake_wind_kt: float) -> Course:
	if _lake == null:
		push_error("--course=fit: needs --map=lake")
		return null
	var grid: TerrainGrid = _lake.depth_grid()
	if grid == null:
		grid = TerrainGrid.load_from(SHORE_GRID_PATH)
	var at: Vector2 = Vector2.ZERO
	if fit_at != "":
		var parts: PackedStringArray = fit_at.split(",")
		at = Vector2(parts[0].to_float(), parts[1].to_float() if parts.size() > 1 else 0.0)
	var fitter: CourseFitter = CourseFitter.from_heights(grid.height_at, at)
	# The saved lake courses were laid down to 25 % of the class's size (fit_courses_8nov.txt): so are these, with
	# room enough from the shore for the AI's lookout.
	fitter.mark_margin_m = SUITE_FIT_MARK_MARGIN_M
	fitter.leg_margin_m = SUITE_FIT_LEG_MARGIN_M
	fitter.min_size_percent = SUITE_FIT_MIN_SIZE_PERCENT
	var rules: CourseRules = load(COURSE_RULES_PATH)
	var wind_from_deg: float = _lake.map_wind().lake_from_deg(_lake_time_s)
	var course: Course = fitter.fit_template(template_id.to_upper(), rules, lake_wind_kt, wind_from_deg, at, 12)
	if course != null:
		course.name = "fit %s at (%.0f, %.0f)" % [template_id.to_upper(), at.x, at.y]
	else:
		print("FIT_FAILED %s at (%.0f, %.0f): %s" % [template_id.to_upper(), at.x, at.y, fitter.last_reason])
	return course


## Why a course does not belong on the lake as it is ("" when it does): a mark or a leg on land (Course.problems()),
## or a mark nearer the shore than SUITE_MARK_ROOM_M, or a leg nearer than SUITE_LEG_ROOM_M (the course fitter's
## clearance).
func course_on_lake_problem(course: Course) -> String:
	var grid: TerrainGrid = _lake.depth_grid()
	if grid == null:
		grid = TerrainGrid.load_from(SHORE_GRID_PATH)
	var problems: PackedStringArray = course.problems(grid.height_at)
	if not problems.is_empty():
		return "; ".join(problems)
	var fitter: CourseFitter = CourseFitter.from_heights(grid.height_at, course.start_middle())
	if not fitter.has_water():
		return "the start is not on the lake"
	var mark_room_m: float = fitter.smallest_mark_clearance_m(course)
	if mark_room_m < SUITE_MARK_ROOM_M:
		return "a mark %.0f m from the shore" % mark_room_m
	var leg_room_m: float = fitter.smallest_leg_clearance_m(course)
	if leg_room_m < SUITE_LEG_ROOM_M:
		return "a leg %.0f m from the shore" % leg_room_m
	return ""


## The course for the random suite's scorer: every step's kind, name, points, rounding side and directions, one line.
static func course_json(race: RaceSim, axis_deg: float) -> String:
	var steps: Array = []
	for step: RaceStep in race.steps():
		var points: Array = []
		for point: Vector2 in step.points:
			points.append([snappedf(point.x, 0.1), snappedf(point.y, 0.1)])
		steps.append({"kind": RaceStep.Kind.keys()[step.kind], "name": step.name, "points": points, "side": int(step.side),
			"in": [snappedf(step.in_dir.x, 0.001), snappedf(step.in_dir.y, 0.001)], "out": [snappedf(step.out_dir.x, 0.001), snappedf(step.out_dir.y, 0.001)]})
	return JSON.stringify({"axis_deg": axis_deg, "steps": steps})


## --spawn=anywhere (Max, 8 November 2026: "drop the AI anywhere on the field before the start and they always
## try to be the fastest at the finish"): `count` spots, Vector3(x, z, heading in degrees), each at a random place
## anywhere round the course (the box round all its marks and lines, ANYWHERE_MARGIN_M wider each way: above
## the top mark, far below the line, out to the sides), in open water (ANYWHERE_OPEN_M round it, when there is a
## lookout), SailingArea.SPAWN_APART_M from the others where it can, heading any way but into the wind.
static func anywhere_places(race: RaceSim, count: int, random_seed: int, lookout: ShoreLookout, wind_from_deg: float) -> Array[Vector3]:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = random_seed
	var low: Vector2 = Vector2(INF, INF)
	var high: Vector2 = Vector2(-INF, -INF)
	for step: RaceStep in race.steps():
		for point: Vector2 in step.points:
			low = low.min(point)
			high = high.max(point)
	low -= Vector2.ONE * ANYWHERE_MARGIN_M
	high += Vector2.ONE * ANYWHERE_MARGIN_M
	var places: Array[Vector3] = []
	for i: int in count:
		var spot: Vector2 = (low + high) * 0.5
		for attempt: int in SailingArea.SPAWN_TRIES:
			var candidate: Vector2 = Vector2(rng.randf_range(low.x, high.x), rng.randf_range(low.y, high.y))
			if lookout != null and lookout.openness_m(candidate) < ANYWHERE_OPEN_M:
				continue
			var apart: bool = attempt > SailingArea.SPAWN_TRIES / 2 or places.all(func(p: Vector3) -> bool:
				return Vector2(p.x, p.y).distance_to(candidate) >= SailingArea.SPAWN_APART_M)
			spot = candidate
			if apart:
				break
		var heading_deg: float = rng.randf_range(0.0, 360.0)
		var off_wind_deg: float = Course.turn_deg(wind_from_deg, heading_deg)
		if absf(off_wind_deg) < DROP_IRONS_DEG:
			heading_deg = wind_from_deg + (signf(off_wind_deg) if off_wind_deg != 0.0 else 1.0) * DROP_CLOSE_DEG
		places.append(Vector3(spot.x, spot.y, fposmod(heading_deg, 360.0)))
	return places


## A drop's spot and heading (--drop_step; the skipper's heads, 8 November 2026): somewhere on the leg
## to step `step_index` (between DROP_ALONG_FROM and DROP_ALONG_TO of it, to the side of it by a random
## amount), in open water (DROP_OPEN_M round it, when there is a lookout), heading roughly along the
## leg but never in irons. Vector3(x, z, heading in degrees). Every seed gives another spot, so the
## skipper is never tuned on one place (Max: "so they are not doing a one trick pony").
static func drop_spot(race: RaceSim, step_index: int, wind_from_deg: float, rng: RandomNumberGenerator, lookout: ShoreLookout) -> Vector3:
	var steps: Array[RaceStep] = race.steps()
	var from: Vector2 = steps[step_index - 1].target()
	var to: Vector2 = steps[step_index].target()
	var leg: Vector2 = to - from
	var across: Vector2 = leg.normalized().orthogonal()
	var spot: Vector2 = from + leg * 0.5
	for attempt: int in 80:
		var side_m: float = clampf(rng.randfn(0.0, minf(DROP_SIDE_SHARE * leg.length(), DROP_SIDE_MAX_M)), -2.0 * DROP_SIDE_MAX_M, 2.0 * DROP_SIDE_MAX_M)
		var candidate: Vector2 = from + leg * rng.randf_range(DROP_ALONG_FROM, DROP_ALONG_TO) + across * side_m
		if lookout == null or lookout.openness_m(candidate) >= DROP_OPEN_M:
			spot = candidate
			break
	var heading_deg: float = Course.bearing_deg(from, to) + rng.randf_range(-DROP_HEADING_DEG, DROP_HEADING_DEG)
	var off_wind_deg: float = Course.turn_deg(wind_from_deg, heading_deg)
	if absf(off_wind_deg) < DROP_IRONS_DEG:
		var side: float = signf(off_wind_deg) if off_wind_deg != 0.0 else (1.0 if rng.randf() < 0.5 else -1.0)
		heading_deg = wind_from_deg + side * DROP_CLOSE_DEG
	return Vector3(spot.x, spot.y, fposmod(heading_deg, 360.0))


## The marks a rounding drill of `kind` can be sailed at (--round_drill), as step indexes; never the start or the
## finish. "gybe": a slalom's gybe mark, its legs in and out both reaches (ROUND_REACH_TWA_DEG to
## ROUND_GYBE_DEEPEST_TWA_DEG off the wind: a leg out nearer dead downwind is a run, sailed at the run's angle with a
## gybe on its layline, not at the mark), on opposite tacks, the shorter turn between them through downwind. "top": reached on a beat (the leg in within ROUND_BEAT_TWA_DEG
## of the wind) and left downwind (the leg out at least ROUND_AWAY_TWA_DEG off it): the bear-away.
static func round_drill_marks(race: RaceSim, wind_from_deg: float, kind: String) -> Array[int]:
	var steps: Array[RaceStep] = race.steps()
	var marks: Array[int] = []
	for k: int in range(1, steps.size() - 1):
		if steps[k].kind != RaceStep.Kind.MARK and steps[k].kind != RaceStep.Kind.GATE:
			continue
		var in_deg: float = Course.turn_deg(wind_from_deg, Course.bearing_deg(steps[k - 1].target(), steps[k].target()))
		var out_deg: float = Course.turn_deg(wind_from_deg, Course.bearing_deg(steps[k].target(), steps[k + 1].target()))
		var gybe: bool = absf(in_deg) >= ROUND_REACH_TWA_DEG and absf(out_deg) >= ROUND_REACH_TWA_DEG \
			and absf(in_deg) <= ROUND_GYBE_DEEPEST_TWA_DEG and absf(out_deg) <= ROUND_GYBE_DEEPEST_TWA_DEG \
			and signf(in_deg) != signf(out_deg) and absf(in_deg) + absf(out_deg) > 180.0
		var top: bool = absf(in_deg) <= ROUND_BEAT_TWA_DEG and absf(out_deg) >= ROUND_AWAY_TWA_DEG
		if (kind == "gybe" and gybe) or (kind == "top" and top):
			marks.append(k)
	return marks


## A drill's spot and heading before the mark of step k, as Vector3(x, z, heading in degrees): from_m to to_m metres
## from the mark (no further than ROUND_LEG_SHARE of the leg in), from a random angle. A gybe mark: within
## ROUND_GYBE_FAN_DEG either side of the leg in, the straight way in a reach on the leg in's tack (not deeper than
## ROUND_GYBE_DEEPEST_TWA_DEG), heading at the mark give or take ROUND_GYBE_HEADING_DEG. A top mark: within
## ROUND_TOP_FAN_DEG either side of straight downwind of it (so beyond the laylines too: overstood, or from the wrong
## side), close-hauled on a random tack (half of them heading away: "coming from the wrong way"). In open water
## (ROUND_OPEN_M round it, when there is a lookout).
static func round_drill_spot(race: RaceSim, k: int, kind: String, wind_from_deg: float, rng: RandomNumberGenerator, lookout: ShoreLookout,
		from_m: float, to_m: float) -> Vector3:
	var steps: Array[RaceStep] = race.steps()
	var mark: Vector2 = steps[k].target()
	var before: Vector2 = steps[k - 1].target()
	var in_deg: float = Course.turn_deg(wind_from_deg, Course.bearing_deg(before, mark))
	var far_m: float = maxf(minf(to_m, before.distance_to(mark) * ROUND_LEG_SHARE), from_m * 0.5)
	var near_m: float = minf(from_m, far_m)
	var spot: Vector2 = mark + (before - mark).normalized() * near_m
	for attempt: int in 80:
		var out_deg: float = wind_from_deg + 180.0 + rng.randf_range(-ROUND_TOP_FAN_DEG, ROUND_TOP_FAN_DEG) if kind == "top" \
			else Course.bearing_deg(mark, before) + rng.randf_range(-ROUND_GYBE_FAN_DEG, ROUND_GYBE_FAN_DEG)
		var candidate: Vector2 = mark + Course.direction_of(out_deg) * rng.randf_range(near_m, far_m)
		if kind != "top":
			var way_in_deg: float = Course.turn_deg(wind_from_deg, Course.bearing_deg(candidate, mark))
			if signf(way_in_deg) != signf(in_deg) or absf(way_in_deg) < ROUND_REACH_TWA_DEG or absf(way_in_deg) > ROUND_GYBE_DEEPEST_TWA_DEG:
				continue
		if lookout != null and lookout.openness_m(candidate) < ROUND_OPEN_M:
			continue
		spot = candidate
		break
	var heading_deg: float = Course.bearing_deg(spot, mark) + rng.randf_range(-ROUND_GYBE_HEADING_DEG, ROUND_GYBE_HEADING_DEG)
	if kind == "top":
		var side: float = 1.0 if rng.randf() < 0.5 else -1.0
		heading_deg = wind_from_deg + side * DROP_CLOSE_DEG
	return Vector3(spot.x, spot.y, fposmod(heading_deg, 360.0))


## The rounding drill's boards set down after the gun (--round_drill): each at its own round_drill_spot() before the
## mark of step mark_index, at least ROUND_APART_M from the others, and, with together_s above 0 (the laylines in
## company), each one's expected time to the mark within together_s of the first board's. Each board's distance to the
## mark and the wind angle of its straight way in are kept for its HEADS_RESULT.
static func place_drill(race: RaceSim, entries: Array[Entry], mark_index: int, kind: String, wind_from_deg: float, rng: RandomNumberGenerator,
		lookout: ShoreLookout, from_m: float, to_m: float, together_s: float, axis_deg: float, wind_kt: float, group_deg: float = 0.0) -> void:
	var mark: Vector2 = race.steps()[mark_index].target()
	var first_s: float = -1.0
	var first_from_deg: float = 0.0
	var placed: PackedVector2Array = PackedVector2Array()
	for i: int in entries.size():
		var spot: Vector3 = round_drill_spot(race, mark_index, kind, wind_from_deg, rng, lookout, from_m, to_m)
		for attempt: int in ROUND_TOGETHER_TRIES:
			var at: Vector2 = Vector2(spot.x, spot.y)
			var apart: bool = true
			for other: Vector2 in placed:
				apart = apart and at.distance_to(other) >= ROUND_APART_M
			var together: bool = first_s < 0.0 or together_s <= 0.0 \
				or absf(TrainingDrops.expected_leg_s(at, mark, axis_deg, wind_kt) - first_s) <= together_s
			# --round_group_deg: the boards come in from one side, within group_deg of the first as seen from the mark
			# (the laylines in company: the same layline, each other's dirty wind).
			if first_s >= 0.0 and group_deg > 0.0:
				together = together and absf(Course.turn_deg(first_from_deg, Course.bearing_deg(mark, at))) <= group_deg
			if apart and together:
				break
			spot = round_drill_spot(race, mark_index, kind, wind_from_deg, rng, lookout, from_m, to_m)
		var where: Vector2 = Vector2(spot.x, spot.y)
		if first_s < 0.0:
			first_s = TrainingDrops.expected_leg_s(where, mark, axis_deg, wind_kt)
			first_from_deg = Course.bearing_deg(mark, where)
		placed.append(where)
		entries[i].sim.reset(Vector3(spot.x, 0.0, spot.y), deg_to_rad(spot.z))
		entries[i].controller.reset_controls(entries[i].controls)
		race.place_board(i, where, mark_index)
		entries[i].drill_drop_m = where.distance_to(mark)
		entries[i].drill_approach_twa_deg = Course.turn_deg(wind_from_deg, Course.bearing_deg(where, mark))


## The rounding drill's measures each tick: the speed when the board first comes within ROUND_NEAR_M of the mark, the
## least from then until ROUND_MIN_UNTIL_S after its rounding counted, the speed ROUND_OUT_AFTER_S after it, the race
## time it counted with the tacks and gybes up to it, and the score at score_at_s (course_progress_m() past the mark:
## Max, "a way to calculate which was the fastest gybe"; minus the way still to the mark when it has not rounded yet).
static func note_the_drill(entry: Entry, race: RaceSim, index: int, mark_index: int, score_at_s: float) -> void:
	var now_s: float = race.clock_s()
	var speed_ms: float = entry.sim.telemetry.speed_ms
	var next: int = race.next_step_index(index)
	if next == mark_index and is_nan(entry.drill_in_ms) and race.distance_to_next_m(index) <= ROUND_NEAR_M:
		entry.drill_in_ms = speed_ms
		entry.drill_min_ms = speed_ms
	if next > mark_index and entry.drill_rounded_s < 0.0:
		entry.drill_rounded_s = now_s
		entry.drill_tacks_in = entry.tacks
		entry.drill_gybes_in = entry.gybes
	if not is_nan(entry.drill_min_ms) and (entry.drill_rounded_s < 0.0 or now_s <= entry.drill_rounded_s + ROUND_MIN_UNTIL_S):
		entry.drill_min_ms = minf(entry.drill_min_ms, speed_ms)
	if entry.drill_rounded_s >= 0.0 and is_nan(entry.drill_out_ms) and now_s >= entry.drill_rounded_s + ROUND_OUT_AFTER_S:
		entry.drill_out_ms = speed_ms
	if is_nan(entry.drill_score_m) and now_s >= score_at_s:
		entry.drill_score_m = course_progress_m(race, index) - step_progress_m(race, mark_index)


## How far along the course a board is, metres: the straight legs between the steps' targets up to its next step, less
## its distance to that step. Past the finish: the whole course.
static func course_progress_m(race: RaceSim, index: int) -> float:
	var next: int = race.next_step_index(index)
	if next >= race.steps().size():
		return step_progress_m(race, race.steps().size() - 1)
	return step_progress_m(race, next) - race.distance_to_next_m(index)


## The straight legs between the steps' targets from the start to step k, metres.
static func step_progress_m(race: RaceSim, k: int) -> float:
	var steps: Array[RaceStep] = race.steps()
	var total: float = 0.0
	for j: int in range(1, mini(k, steps.size() - 1) + 1):
		total += steps[j - 1].target().distance_to(steps[j].target())
	return total


## A board's rounding drill for its HEADS_RESULT line (tools/heads/random_suite.py reads it). Numbers not reached are
## null (no rounding, never near the mark).
static func drill_result(entry: Entry, race: RaceSim, mark_index: int, kind: String, score_at_s: float) -> Dictionary:
	return {"kind": kind, "mark_step": mark_index, "mark": race.steps()[mark_index].name,
		"drop_m": snappedf(entry.drill_drop_m, 0.1), "approach_twa_deg": snappedf(entry.drill_approach_twa_deg, 0.1),
		"score_at_s": snappedf(score_at_s, 0.1), "score_m": _snapped_or_null(entry.drill_score_m, 0.1),
		"rounded_s": snappedf(entry.drill_rounded_s, 0.1) if entry.drill_rounded_s >= 0.0 else null,
		"in_ms": _snapped_or_null(entry.drill_in_ms, 0.01), "min_ms": _snapped_or_null(entry.drill_min_ms, 0.01),
		"out_ms": _snapped_or_null(entry.drill_out_ms, 0.01),
		"tacks_in": entry.drill_tacks_in if entry.drill_tacks_in >= 0 else entry.tacks,
		"gybes_in": entry.drill_gybes_in if entry.drill_gybes_in >= 0 else entry.gybes,
		"tacks": entry.tacks, "gybes": entry.gybes}


## A number for a JSON line, or null when it was never measured (NAN).
static func _snapped_or_null(value: float, step: float) -> Variant:
	return null if is_nan(value) else snappedf(value, step)


## The all-rounder's expected time from a point (or, with Vector2(INF, INF), from the start line) through
## the steps from `from_index` up to (not including) `goal_index`, seconds (TrainingDrops.expected_leg_s()).
static func expected_time_s(race: RaceSim, from_index: int, goal_index: int, from: Vector2, axis_deg: float, wind_kt: float) -> float:
	var steps: Array[RaceStep] = race.steps()
	var at: Vector2 = from
	var first: int = from_index
	if from.x == INF:
		at = steps[0].target()
		first = 1
	var total_s: float = 0.0
	for k: int in range(first, mini(goal_index, steps.size())):
		total_s += TrainingDrops.expected_leg_s(at, steps[k].target(), axis_deg, wind_kt)
		at = steps[k].target()
	return total_s


## Every WATCH_EVERY ticks: whether the board has done its goal step, and, from the gun until then, how
## long it is stuck and slow, the least open water under it and how far it has turned.
static func _watch(entry: Entry, race: RaceSim, index: int, goal_index: int, lookout: ShoreLookout) -> void:
	var now_s: float = race.clock_s()
	if entry.goal_at_s < 0.0 and race.next_step_index(index) >= goal_index:
		entry.goal_at_s = now_s
	if entry.goal_at_s >= 0.0 or entry.aground or now_s < 0.0:
		return
	var dt: float = WATCH_EVERY * DT
	var t: Telemetry = entry.sim.telemetry
	entry.watch_s += dt
	if entry.sim.sailor_state == WindsurferSim.SailorState.SAILING:
		if t.speed_ms < STUCK_MS and entry.watch_s > STUCK_GRACE_S:
			entry.stuck_s += dt
			entry.stuck_run_s += dt
			if entry.stuck_run_s > entry.longest_stuck_s:
				entry.longest_stuck_s = entry.stuck_run_s
				entry.stuck_note = entry.skipper.note if entry.skipper != null else "autopilot"
		else:
			entry.stuck_run_s = 0.0
		if t.speed_ms < SLOW_MS:
			entry.slow_s += dt
	if lookout != null:
		entry.min_open_m = minf(entry.min_open_m, lookout.openness_m(_where(entry)))
	if not is_nan(entry.last_heading_deg):
		entry.turn_deg += absf(wrapf(t.heading_deg - entry.last_heading_deg, -180.0, 180.0))
	entry.last_heading_deg = t.heading_deg


## One board's run as a dictionary for the HEADS_RESULT line (tools/heads/suite.py reads it).
static func heads_result(entry: Entry, race: RaceSim, index: int, drop_index: int, goal_index: int, expected_all_s: float,
		options: Dictionary[String, String]) -> Dictionary:
	var reached: bool = entry.goal_at_s >= 0.0
	var steps: Array[RaceStep] = race.steps()
	var next_index: int = race.next_step_index(index)
	return {
		"course": options.get("course", "test"), "time": options.get("time", "-"), "wind_scale": options.get("lake_wind_scale", "1"),
		"seed": options.get("seed", "0"), "spawn_seed": options.get("spawn_seed", "0"), "drop_seed": options.get("drop_seed", "-"),
		"board": entry.name, "drop_step": drop_index, "goal_step": goal_index, "steps": steps.size(),
		"reached": reached, "time_s": entry.goal_at_s if reached else -1.0,
		"expected_s": expected_all_s if drop_index == 0 else options.get("expected_s", "0").to_float(),
		"watched_s": entry.watch_s, "falls": entry.falls, "aground": entry.aground, "aground_note": entry.aground_note,
		"stuck_s": entry.stuck_s, "longest_stuck_s": entry.longest_stuck_s, "stuck_note": entry.stuck_note,
		"slow_s": entry.slow_s, "min_open_m": entry.min_open_m if entry.min_open_m != INF else -1.0, "turn_deg": entry.turn_deg,
		"tacks": entry.tacks, "gybes": entry.gybes, "next_step": next_index,
		"to_next_m": race.distance_to_next_m(index) if next_index < steps.size() else 0.0,
		"splits": Array(race.splits_s(index)), "note": entry.skipper.note if entry.skipper != null else "autopilot",
		"ocs": race.is_ocs(index) or (entry.skipper is Skipper and (entry.skipper as Skipper).was_ocs)}


## The start of every skipper's board, one line each: how long after the gun it crossed the start
## line (its start delay; "-" if it has not started), whether it was over the line at the gun (OCS),
## and a summary: the longest delay, the OCS count, and the boards outside the area at the gun.
static func start_report(race: RaceSim, entries: Array[Entry], outside_at_gun: PackedStringArray) -> String:
	var lines: PackedStringArray = PackedStringArray(["Starts:"])
	var longest_s: float = 0.0
	var not_started: int = 0
	var ocs: int = 0
	for i: int in entries.size():
		var skipper: Skipper = entries[i].skipper as Skipper
		if skipper == null:
			continue
		var started: bool = race.next_step_index(i) > 0
		var delay_s: float = race.splits_s(i)[0] if started else NAN
		if started:
			longest_s = maxf(longest_s, delay_s)
		else:
			not_started += 1
		if skipper.was_ocs:
			ocs += 1
		lines.append("  %-16s start %s%s" % [entries[i].name, "%+6.1f s" % delay_s if started else "   -   ", "  OCS" if skipper.was_ocs else ""])
	lines.append("  longest start delay %.1f s, %d not started, %d OCS, %d outside the sailing area at the gun%s" % [
		longest_s, not_started, ocs, outside_at_gun.size(), (": " + ", ".join(outside_at_gun)) if not outside_at_gun.is_empty() else ""])
	return "\n".join(lines)


## The penalties: one line per board that got any (how many, how many it cleared by turning, the
## time it carried), and the total.
static func penalty_report(rules: RaceRules, entries: Array[Entry]) -> String:
	var lines: PackedStringArray = PackedStringArray()
	var total: int = 0
	for i: int in entries.size():
		var given: int = rules.penalties(i) + rules.turns_done(i)
		total += given
		if given > 0:
			lines.append("  %-16s %d penalt%s, %d turned, %.0f s carried" % [entries[i].name, given, "y" if given == 1 else "ies", rules.turns_done(i), rules.time_penalty_s(i)])
	lines.insert(0, "Penalties: %d" % total)
	return "\n".join(lines)


## The boards outside the sailing area now (by name).
static func boards_outside(race: RaceSim, area: SailingArea) -> PackedStringArray:
	var outside: PackedStringArray = PackedStringArray()
	if area == null:
		return outside
	for i: int in race.board_count():
		if not area.contains(race.board_position(i)):
			outside.append(race.board_name(i))
	return outside


## The sailing area of a course: round its start line, kept off the lake's shore for a course on the
## lake (any course but the test loop and T1).
static func sailing_area_for(course_name: String, course: Course) -> SailingArea:
	if course_name == "test" or course_name == "t1_loop":
		return SailingArea.for_course(course)
	return SailingArea.for_course(course, TerrainGrid.load_from(SHORE_GRID_PATH))


# ---------------------------------------------------------------- the race, for this tool and the tests

## The boards of a race, one per name (a character, or "autopilot"), added to the race in order and
## placed for its countdown; board i's skipper gets the seed random_seed + i. With spawn "random"
## the skippers' boards appear at random spots of the sailing area (SailingArea.spawn_places(), as
## in the game), seeded by spawn_seed; with "line" behind the start line. Every skipper sails free in
## the area (one round the start line when none is given). Empty if a name is not a skipper.
static func make_entries(race: RaceSim, course: Course, who: PackedStringArray, wind_kt: float, twa_deg: float = 50.0, random_seed: int = 0,
		spawn: String = "line", area: SailingArea = null, spawn_seed: int = 0, behind_m: float = -1.0, gear: bool = false,
		level_spread: float = 1.0) -> Array[Entry]:
	var entries: Array[Entry] = []
	var used: Dictionary[String, int] = {}
	if area == null:
		area = SailingArea.for_course(course)
	var places: Array[Vector3] = []
	if spawn == "random":
		places = area.spawn_places(who.size(), spawn_seed)
	for i: int in who.size():
		var share: float = float(i + 1) / (who.size() + 1)
		var entry: Entry
		if who[i] == "autopilot":
			entry = _make_autopilot_board(race, course.axis_deg, wind_kt, twa_deg, share)
			entry.name = "board%d" % (i + 1)
		else:
			entry = _make_skipper_board(who[i], race, course, wind_kt, share, behind_m, gear)
			if entry == null:
				var none: Array[Entry] = []
				return none
			if not places.is_empty():
				entry.sim.reset(Vector3(places[i].x, 0.0, places[i].y), deg_to_rad(places[i].z))
				entry.controller.reset_controls(entry.controls)
			entry.skipper.sailing_area = area
			entry.skipper.random_seed = random_seed + i
			entry.skipper.level_spread = level_spread
			# Two of the same character are told apart by their number.
			used[entry.name] = used.get(entry.name, 0) + 1
			if who.count(who[i]) > 1:
				entry.name = "%s %d" % [entry.name, used[entry.name]]
		race.add_board(entry.name)
		race.update_board(i, _where(entry))
		entries.append(entry)
	# The skippers look at the whole fleet, so they are set up once every board is in the race.
	for i: int in entries.size():
		if entries[i].skipper != null:
			entries[i].skipper.setup(entries[i].sim, entries[i].controller, entries[i].hands, race, i)
	return entries


## The other sails' wind shadows on every board's wind (F3): one WindShadows per board, its own
## copy of the fleet's places each tick (cast_shadows()).
static func give_shadows(entries: Array[Entry], trail: bool = true) -> void:
	var config: WindShadowConfig = (load("res://config/wind_shadow_default.tres") as WindShadowConfig).duplicate()
	config.follows_apparent_wind = config.follows_apparent_wind and trail
	# A new race: new trails.
	_trail = null
	for entry: Entry in entries:
		entry.shadows = WindShadows.make(config)
		entry.sim.wind.disturbance = entry.shadows


## Each scripted skipper's sheet for this race, one line each (a persona's is drawn for the race's
## seed and wind): its hands (reaction and noise), its push offset, its beat and run angles as
## differences from the polar's best, and its layline margin.
static func print_sheets(entries: Array[Entry]) -> void:
	for entry: Entry in entries:
		var scripted: Skipper = entry.skipper as Skipper
		if scripted == null:
			continue
		var c: SkipperConfig = scripted.config
		print("sheet %-12s hands %.2f s %.1f deg  push %+.2f  beat %+.1f deg  run %+.0f deg  layline %.0f m" % [entry.name,
			c.reaction_time_s, c.steering_noise_deg, c.push_offset, c.upwind_vmg_twa_deg - Skipper.POLAR_15KT_UPWIND_TWA_DEG + c.pointing_offset_deg,
			c.downwind_vmg_twa_deg - Skipper.POLAR_15KT_DOWNWIND_TWA_DEG, c.layline_margin_m])


## Every scripted skipper's hands as quick and steady as the all-rounder's (--steady_hands=1): the
## rest of its sheet (drawn for the race in its setup()) stays.
static func steady_the_hands(entries: Array[Entry]) -> void:
	for entry: Entry in entries:
		var scripted: Skipper = entry.skipper as Skipper
		if scripted != null:
			scripted.config.reaction_time_s = STEADY_REACTION_S
			scripted.config.steering_noise_deg = STEADY_NOISE_DEG


## The scripted skippers' push and polar from the options (--skipper_push, --polar): false if the
## polar file cannot be loaded.
static func tune_skippers(entries: Array[Entry], skipper_push: bool, polar_path: String) -> bool:
	var polar: SkipperPolar = null
	if polar_path != "":
		var path: String = polar_path
		if not (path.begins_with("res://") or path.is_absolute_path()):
			path = _repository_path(path)
		polar = load(path) as SkipperPolar if ResourceLoader.exists(path) else null
		if polar == null:
			push_error("No skipper polar at %s." % path)
			return false
	for entry: Entry in entries:
		var scripted: Skipper = entry.skipper as Skipper
		if scripted == null:
			continue
		scripted.push_wanted = skipper_push
		if polar != null:
			scripted.take_polar(polar)
	return true


## The racing rules' judge for the race, given to every scripted skipper (it keeps clear by the
## rules and turns a circle for a penalty).
static func give_rules(entries: Array[Entry], race: RaceSim, course: Course) -> RaceRules:
	var rules: RaceRules = RaceRules.new(race.board_count(), course.axis_deg)
	for entry: Entry in entries:
		if entry.skipper != null:
			entry.skipper.rules = rules
	return rules


## The judge told where everyone is after the tick, and every board's time penalty as it stands
## handed to the race.
static func judge(rules: RaceRules, race: RaceSim, entries: Array[Entry]) -> void:
	var marks: PackedVector2Array = PackedVector2Array()
	for i: int in entries.size():
		var t: Telemetry = entries[i].sim.telemetry
		rules.set_board(i, Vector2(t.position.x, t.position.z), t.heading_deg, 1.0 if t.twa_deg >= 0.0 else -1.0, t.speed_ms,
			t.sailor_state == WindsurferSim.SailorState.SAILING)
		var step: RaceStep = race.next_step(i)
		marks.append(step.points[0] if step != null and step.kind == RaceStep.Kind.MARK else Vector2.INF)
	rules.step(DT, marks, race.clock_s() >= 0.0)
	for i: int in entries.size():
		race.set_time_penalty_s(i, rules.time_penalty_s(i))
		# Every new penalty as a PENALTY line: who, against whom, why, and both boards as they were (the
		# skipper's heads, 8 November 2026: the rules' incidents read one by one).
		var given: int = rules.penalties(i) + rules.turns_done(i)
		if given > entries[i].penalties_seen:
			entries[i].penalties_seen = given
			var j: int = rules.burdened_by(i)
			var a: Telemetry = entries[i].sim.telemetry
			var line: String = "PENALTY %.1f s %s: %s | %s at (%.0f, %.0f) hdg %.0f twa %.0f %.1f m/s %s" % [race.clock_s(), entries[i].name,
				rules.breach_text(i), entries[i].name, a.position.x, a.position.z, a.heading_deg, a.twa_deg, a.speed_ms,
				entries[i].skipper.note if entries[i].skipper != null else ""]
			if j >= 0:
				var b: Telemetry = entries[j].sim.telemetry
				line += " | %s at (%.0f, %.0f) hdg %.0f twa %.0f %.1f m/s %s" % [entries[j].name, b.position.x, b.position.z, b.heading_deg,
					b.twa_deg, b.speed_ms, entries[j].skipper.note if entries[j].skipper != null else ""]
			print(line)


## Every board's place and whether its sail is up, into every board's shadows, before the physics.
static func cast_shadows(entries: Array[Entry]) -> void:
	var xs: PackedFloat32Array = PackedFloat32Array()
	var zs: PackedFloat32Array = PackedFloat32Array()
	var casts: PackedByteArray = PackedByteArray()
	var sims: Array[WindsurferSim] = []
	for entry: Entry in entries:
		var position: Vector3 = entry.sim.telemetry.position
		xs.append(position.x)
		zs.append(position.z)
		casts.append(1 if entry.sim.sailor_state == WindsurferSim.SailorState.SAILING else 0)
		sims.append(entry.sim)
	# The sails' trails of disturbed air (WindShadowTrail): the shadows lie along them.
	if _trail == null:
		_trail = WindShadowTrail.make()
	_trail.update(DT, sims, casts)
	var points: PackedFloat32Array = _trail.points()
	for i: int in entries.size():
		if entries[i].shadows != null:
			entries[i].shadows.set_fleet(xs, zs, casts, i)
			entries[i].shadows.set_trail(points, i)


## One tick of the race: every board (its sailor, the physics, the falls and the manoeuvres
## counted), the race told where each one is, and the race clock moved on. With `blind` the
## skippers are not told where the others are (the learned brains were trained alone).
static func step_race(race: RaceSim, entries: Array[Entry], blind: bool = false, rules: RaceRules = null) -> void:
	if entries.size() > 1 and entries[0].shadows != null:
		cast_shadows(entries)
	for i: int in entries.size():
		if entries[i].skipper != null and entries.size() > 1 and not blind:
			_tell_others(entries, i)
		if race.clock_s() >= entries[i].set_off_s and not entries[i].aground:
			_sail(entries[i], not race.is_finished(i))
		race.update_board(i, _where(entries[i]))
	race.step(DT)
	if rules != null:
		judge(rules, race, entries)


## The course to race: the test loop, T1, or a course file.
static func course_named(name: String) -> Course:
	if name == "test":
		return _test_course(EnvironmentConfig.new().wind_or_default().from_bearing_deg)
	# The built-in courses and the team's saved ones, by name (RaceCourses); anything else is a path.
	if name == "t1_loop":
		return RaceCourses.t1_loop(EnvironmentConfig.new().wind_or_default().from_bearing_deg, Vector2.ZERO)
	if name.begins_with("template:"):
		return RaceCourses.template_named(name, EnvironmentConfig.new().wind_or_default().from_bearing_deg, Vector2.ZERO)
	var named: Course = RaceCourses.load_named(name, load(MAP_CONFIG_PATH))
	if named != null:
		return named
	var path: String = name
	if not (path.begins_with("res://") or path.begins_with("user://") or path.is_absolute_path()):
		path = _repository_path(path)
	var course: Course = Course.load_from(path, load(MAP_CONFIG_PATH))
	if course == null:
		push_error("No course file at %s (--course=test, or the path of a course maker's .json file)." % path)
	return course


# ---------------------------------------------------------------- the course

## The small loop of --course=test, set for a wind direction (where it comes from), with the middle of
## its start line at the origin. Drawn in the frame of the course diagrams, as CourseTemplates does:
## up toward the wind, right to the right looking upwind.
static func _test_course(axis_deg: float) -> Course:
	var course: Course = Course.new()
	course.name = "the test loop"
	course.axis_deg = axis_deg
	course.boards = 4
	course.add_mark(CourseMark.START_BOAT, Vector2(30.0, 0.0))
	course.add_mark(CourseMark.START_PIN, Vector2(-30.0, 0.0))
	course.add_mark("1", Vector2(0.0, 300.0), CourseMark.Rounding.PORT)
	course.add_mark("4S", Vector2(-20.0, 100.0), CourseMark.Rounding.STARBOARD)
	course.add_mark("4P", Vector2(20.0, 100.0), CourseMark.Rounding.PORT)
	# The finish line along the wind, crossed going left from the gate; its boat at the upwind end.
	course.add_mark(CourseMark.FINISH_BOAT, Vector2(-150.0, 120.0))
	course.add_mark(CourseMark.FINISH_PIN, Vector2(-150.0, 80.0))
	var problem: String = course.set_sequence("Start-1-4S/4P-Finish")
	if problem != "":
		push_error(problem)
	var up: Vector2 = Course.direction_of(axis_deg)
	var right: Vector2 = Course.direction_of(axis_deg + 90.0)
	for mark: CourseMark in course.marks:
		mark.position = right * mark.position.x + up * mark.position.y
	return course


# ---------------------------------------------------------------- the boards

## The open water's default simulation with its waves (as WindsurferSim.create_default(true)
## builds it), in a wind of some knots from a direction. Every board gets copies of the
## configuration files of its own: boards stepped side by side on threads (tests/unit/
## test_skipper.gd) would otherwise all read the same objects, and that slowed each of them down
## several times over. The numbers are the same.
static func _make_sim(wind_from_deg: float, wind_kt: float) -> WindsurferSim:
	if _lake != null:
		return _make_lake_sim()
	var environment: EnvironmentConfig = EnvironmentConfig.new()
	var wind_config: WindConfig = environment.wind_or_default().duplicate(true)
	wind_config.speed_kt = wind_kt
	wind_config.from_bearing_deg = wind_from_deg
	var sim: WindsurferSim = WindsurferSim.new(
		load("res://config/board_default.tres").duplicate(true),
		load("res://config/sail_default.tres").duplicate(true),
		load("res://config/fin_default.tres").duplicate(true),
		load("res://config/sailor_default.tres").duplicate(true),
		environment.water_or_default().duplicate(true),
		wind_config,
		load("res://config/sim_default.tres").duplicate(true),
		environment.waves_or_default().duplicate(true))
	sim.air_density_kg_m3 = environment.air_density_kg_m3
	sim.set_waves(true)
	return sim


## A board on Lake Silvaplana (--map=lake), as the AI's training builds one there (RaceEnv with the
## lake's environment): its own copies of every config, the map's wind at the hour, and the menu's
## default sea with the lake's own waves on (TrainingDrops.lake_sea()).
static func _make_lake_sim() -> WindsurferSim:
	var sim: WindsurferSim = WindsurferSim.create_for(_lake, true, true)
	var map_field: MapWindField = sim.wind as MapWindField
	if map_field != null:
		map_field.set_time_of_day(_lake_time_s)
	sim.wave_set_config = TrainingDrops.lake_sea()
	sim.set_waves(true)
	return sim


## The --pilot. and --controller. settings on a skipper's controller.
static func _apply_controller_overrides(controller: PlayerController) -> void:
	if not _overrides_read:
		# Also when the harness is used by a test (test_living_skipper_fleet.gd uses make_entries()):
		# the environment variable WSIM_CONTROLLER ("controller.rail_full_ms=0;pilot.hike_share=1.0"),
		# to try a setting on a validation test (GUT refuses options it does not know).
		_overrides_read = true
		for item: String in OS.get_environment("WSIM_CONTROLLER").split(";", false):
			if (item.begins_with("pilot.") or item.begins_with("controller.")) and item.contains("="):
				var parts: PackedStringArray = item.split("=", true, 1)
				_controller_overrides[parts[0]] = parts[1].to_float()
	for key: String in _controller_overrides:
		var parts: PackedStringArray = key.split(".", true, 1)
		if parts[0] == "pilot":
			if parts[1] in controller.auto_sheet_pilot:
				controller.pilot_overrides[parts[1]] = _controller_overrides[key]
			else:
				push_error("No field '%s' to override." % key)
		elif parts[1] in controller:
			var current: Variant = controller.get(parts[1])
			var value: float = _controller_overrides[key]
			controller.set(parts[1], (value != 0.0) if current is bool else (int(value) if current is int else value))
		else:
			push_error("No field '%s' to override." % key)


## A skipper's board: at the pre-start spot (brought nearer the line for a short countdown), at
## `share` of the way across the line's width, on the pre-start's beam reach, at rest. Its skipper
## drives the beginner controller (auto-sheet on), as the player's board is set up in the game.
## With `gear` a persona sails its own board, sail and fin for the wind (Skippers.gear_for()).
static func _make_skipper_board(skipper_name: String, race: RaceSim, course: Course, wind_kt: float, share: float, behind_m: float = -1.0,
		gear: bool = false) -> Entry:
	var skipper: RaceSkipper = Skippers.make(skipper_name)
	if skipper == null:
		return null
	var entry: Entry = Entry.new()
	entry.name = skipper.skipper_name()
	entry.skipper = skipper
	entry.sim = _make_sim(course.axis_deg, wind_kt)
	var own_gear: GearChoice = Skippers.gear_for(skipper, wind_kt) if gear else null
	if own_gear != null:
		# The same wind and sea on its own gear (copies of the items' numbers); before the
		# controller is given the sail, so that it trims this one.
		entry.sim = own_gear.sim_with(entry.sim)
		print("%s sails %s" % [entry.name, own_gear.names_line()])
	for field: String in _sailor_overrides:
		if field in entry.sim.sailor_config:
			entry.sim.sailor_config.set(field, _sailor_overrides[field])
		else:
			push_error("No field 'sailor.%s' to override." % field)
	entry.controller = PlayerController.new()
	entry.controller.set_sail(entry.sim.sail, entry.sim.sailor_config, entry.sim.air_density_kg_m3)
	_apply_controller_overrides(entry.controller)
	entry.hands = AiHands.new()
	entry.controller.hands = entry.hands
	entry.controls = _fresh_controls()
	var start: RaceStep = race.steps()[0]
	# Where it waits: --behind, or where the game puts the boards on the line (RaceRunner: 1 m per
	# second of countdown, 40 to 100 m; 60 m for the 60 s countdown). It waited 150 m back before
	# (2.5 m per second), which in 12 kt no board could sail to the line in a minute: its best way to
	# windward is 2.3 m/s (fleet_speed/start.md).
	var behind: float = behind_m if behind_m > 0.0 else wait_behind_m(race.prestart_s)
	var along: Vector2 = start.points[0] - start.points[1]
	var at: Vector2 = RaceCourses.pre_start_spot(course) + start.in_dir * (RaceCourses.PRE_START_BEHIND_M - behind) + along * (share - 0.5)
	if course.starts_upwind_of_the_boat():
		# A slalom: in the row upwind of the committee boat (RaceCourses.slalom_slot()).
		at = RaceCourses.slalom_slot(course, share)
	entry.sim.reset(Vector3(at.x, 0.0, at.y), deg_to_rad(RaceCourses.pre_start_heading_deg(course)))
	entry.controller.reset_controls(entry.controls)
	return entry


## How far behind the start line a skipper's board waits for a countdown of this many seconds, metres:
## as the game puts them (RaceSetup.wait_behind_m() with no --behind).
static func wait_behind_m(prestart_s: float) -> float:
	return clampf(prestart_s * RaceRunner.WAIT_M_PER_S, RaceRunner.NEAREST_M, RaceRunner.FARTHEST_M)


## A 9A autopilot board behind the start line at `share` of the way along it (from the pin to the
## boat), on the tack that points nearer the first leg, far enough back to reach the line at about
## the gun.
static func _make_autopilot_board(race: RaceSim, wind_from_deg: float, wind_kt: float, twa_deg: float, share: float) -> Entry:
	var entry: Entry = Entry.new()
	entry.sim = _make_sim(wind_from_deg, wind_kt)
	entry.pilot = Autopilot.new()
	entry.pilot.target_twa_deg = twa_deg
	entry.pilot.sail = entry.sim.sail
	entry.pilot.sailor = entry.sim.sailor_config
	entry.pilot.air_density_kg_m3 = entry.sim.air_density_kg_m3
	entry.controls = _fresh_controls()
	entry.set_off_s = -SET_OFF_S
	# From standstill the pilot sails no closer than bear_away_twa_deg until it has speed, so the
	# board comes up to the line along that angle: put it back along that line from its spot.
	var start: RaceStep = race.steps()[0]
	var approach_twa_deg: float = maxf(twa_deg, entry.pilot.bear_away_twa_deg)
	var heading_deg: float = _heading_toward(Course.bearing_deg(Vector2.ZERO, start.in_dir), wind_from_deg, approach_twa_deg)
	var on_line: Vector2 = start.points[1].lerp(start.points[0], share)
	var sailing_s: float = minf(race.prestart_s, SET_OFF_S) + START_MARGIN_S
	var at: Vector2 = on_line - Course.direction_of(heading_deg) * sailing_s * APPROACH_M_PER_S
	entry.sim.reset(Vector3(at.x, 0.0, at.y), deg_to_rad(heading_deg))
	return entry


## One tick of a board: the sailor (while on the board), the physics, the falls and the manoeuvres
## counted until it has finished (after the finish it sails free while the others finish, and that is
## not the race's).
static func _sail(entry: Entry, counting: bool = true) -> void:
	var sailing: bool = entry.sim.sailor_state == WindsurferSim.SailorState.SAILING
	if entry.skipper != null:
		# The skipper keeps watching from the water too (its clock runs, its hands come off).
		entry.skipper.update(entry.sim.telemetry, DT)
		if sailing:
			entry.controller.update(entry.sim.telemetry, entry.controls, DT)
		if counting:
			_count_manoeuvres(entry)
		else:
			entry.last_manoeuvre = entry.controller.manoeuvre
	elif sailing:
		entry.pilot.update(entry.sim.telemetry, entry.controls, DT)
	entry.sim.step(DT, entry.controls)
	if entry.trace_file != null and roundi(entry.sim.time_s / DT) % 3 == 0:
		entry.trace_file.store_line(entry.sim.telemetry.to_csv_row())
	if entry.fall_log != null and counting:
		var fall_line: String = entry.fall_log.watch(entry.sim)
		if fall_line != "":
			var doing: String = entry.skipper.note if entry.skipper != null else "autopilot"
			print(fall_line + "," + doing.replace(",", ";"))
	var fallen: bool = entry.sim.sailor_state == WindsurferSim.SailorState.FALLEN
	if fallen and not entry.was_fallen and counting:
		entry.falls += 1
		var scripted: Skipper = entry.skipper as Skipper
		if scripted != null and scripted.state == Skipper.State.PRE_START:
			entry.falls_before_gun += 1
	elif entry.was_fallen and not fallen:
		# Up again after the waterstart (the simulation does it after a while): the sail eased, as at
		# the start, and the controller starts afresh, as the game's board does (windsurfer.gd).
		if entry.controller != null:
			entry.controller.reset_controls(entry.controls)
		else:
			entry.controls = _fresh_controls()
	entry.was_fallen = fallen


## Counts a tack or a gybe when the controller starts one.
static func _count_manoeuvres(entry: Entry) -> void:
	var now: PlayerController.Manoeuvre = entry.controller.manoeuvre
	if now != entry.last_manoeuvre and entry.last_manoeuvre == PlayerController.Manoeuvre.NONE:
		if now == PlayerController.Manoeuvre.TACK_HEADING_UP or now == PlayerController.Manoeuvre.TACK_BEARING_AWAY:
			entry.tacks += 1
		else:
			entry.gybes += 1
	entry.last_manoeuvre = now


## The compass heading that holds a wind angle on the tack that points nearer a bearing. On
## starboard tack the wind comes over the right side, so the heading is the wind's direction less
## the angle; on port tack, plus it.
static func _heading_toward(bearing_deg: float, wind_from_deg: float, twa_deg: float) -> float:
	var starboard: float = fposmod(wind_from_deg - twa_deg, 360.0)
	var port: float = fposmod(wind_from_deg + twa_deg, 360.0)
	if absf(Course.turn_deg(starboard, bearing_deg)) <= absf(Course.turn_deg(port, bearing_deg)):
		return starboard
	return port


## A sailor starts with the sail eased and sheets in as the board gets going (as SimScenario does).
static func _fresh_controls() -> SimControls:
	var controls: SimControls = SimControls.new()
	controls.sheet = 0.0
	return controls


## Where a board is, game X and Z.
static func _where(entry: Entry) -> Vector2:
	var position: Vector3 = entry.sim.telemetry.position
	return Vector2(position.x, position.z)


## Board i's skipper is told where the other boards are and how they move (a learned skipper looks
## at the nearest two; a scripted one reads the race instead and ignores this).
static func _tell_others(entries: Array[Entry], i: int) -> void:
	var positions: PackedVector2Array = PackedVector2Array()
	var velocities: PackedVector2Array = PackedVector2Array()
	for j: int in entries.size():
		if j == i:
			continue
		positions.append(_where(entries[j]))
		var v: Vector3 = entries[j].sim.body.velocity
		velocities.append(Vector2(v.x, v.z))
	entries[i].skipper.set_others(positions, velocities)


func _write_row(entry: Entry, race: RaceSim, index: int) -> void:
	if entry.file == null:
		return
	var t: Telemetry = entry.sim.telemetry
	var doing: String = entry.skipper.note if entry.skipper != null else "autopilot"
	var scripted: Skipper = entry.skipper as Skipper
	var aim: Vector2 = scripted.aim_point if scripted != null and scripted.aim_point.is_finite() else Vector2(NAN, NAN)
	entry.file.store_line("%.2f,%.2f,%.2f,%.1f,%.2f,%d,%s,%.1f,%.1f" % [race.clock_s(), t.position.x, t.position.z, t.heading_deg, t.speed_ms,
		race.next_step_index(index), doing.replace(",", ";"), aim.x, aim.y])


## A board's name as a file name: "All-rounder 2" is all-rounder_2.
static func _file_name(board_name: String) -> String:
	return board_name.to_lower().replace(" ", "_")


# ---------------------------------------------------------------- arguments and paths

## A path in the repository's folder (the one above Game/).
static func _repository_path(relative: String) -> String:
	return ProjectSettings.globalize_path("res://").path_join("..").path_join(relative).simplify_path()


func _read_user_args() -> Dictionary[String, String]:
	var options: Dictionary[String, String] = {}
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--") and arg.contains("="):
			var parts: PackedStringArray = arg.trim_prefix("--").split("=", true, 1)
			options[parts[0]] = parts[1]
	return options
