class_name RaceSetup
extends RefCounted
## What a sailing scene is asked to race (RACING_PLAN.md, 9A): the course, who is on the start
## line, the laps and the countdown. The start menu fills `pending` before it starts a scene; the
## scene takes it in its _enter_tree() (SailingScene) and clears it, so a plain sail afterwards is
## a plain sail. The command line asks for the same with --course=<name> --skippers=<name,name,...>
## [--laps=<n>] [--prestart=<s>] (tools/play.sh res://main.tscn --course=t1_loop --skippers=rookie),
## and [--spawn=random|line] [--spawn_seed=<n>] [--free_sail=<s>] for where the AI boards appear
## (read_spawn_options()). For watching a night's generations race (tools/gens.sh, F5):
## [--behind=<m>] [--wind=<kt>] [--blind=1] [--spectate=1] (read_options()).

## The opponents of a race from the menu: three characters of different skill and style.
const DEFAULT_SKIPPERS: PackedStringArray = ["allrounder", "gambler", "rookie"]
const DEFAULT_PRESTART_S: float = 60.0

## Where the AI boards appear (spawn below).
enum Spawn { RANDOM, LINE }

## The race the next scene should set up; null when none.
static var pending: RaceSetup = null

var course_name: String = ""
## The characters (Game/race/skippers/<name>.tres) or brains (brain:<name>) on the line.
var skippers: PackedStringArray = PackedStringArray()
var laps: int = 1
var prestart_s: float = DEFAULT_PRESTART_S
## Whether the opponents' boards get spray, wake and splashes (off: they cost frame time).
var opponent_effects: bool = false
## How many worker-thread tasks step the boards' physics side by side, each a batch of boards
## (eight by default, RaceRunner.MAX_THREADS); 0: one after the other on the main thread.
var threads: int = RaceRunner.MAX_THREADS
## Where the AI boards appear (AI_FLEET_PLAN.md, F2): RANDOM, at random spots in the sailing area
## round the start line (SailingArea), sailing free until the countdown gathers them; LINE, spread
## along the start line behind it, as before. The player's board always starts behind the line.
var spawn: Spawn = Spawn.RANDOM
## The seed of the random spots: the same seed, the same spots, so a race replays.
var spawn_seed: int = 0
## How long the boards sail free before the countdown starts, seconds (0: the countdown starts at
## once, as the menu's races do).
var free_sail_s: float = 0.0
## How far behind the start line the boards wait, metres; 0: by the countdown, 1 m per second
## between 40 and 100 m (RaceRunner). --behind=<m>; the night's brains learned from 150 m.
var behind_m: float = 0.0
## The wind for the race, knots: a steady wind of that strength from the settings' direction, no
## gusts and no shifts, as the brains were trained; 0: the settings' wind as it is. --wind=<kt>.
var wind_kt: float = 0.0
## The learned skippers see no other board (LearnedSkipper.blind), as in their training. --blind=1.
var blind: bool = false
## Spectating: the player's board does not race (it is parked, hidden and not stepped) and the
## camera follows the AI boards, the leader first (RaceRunner, SpectateChoice). --spectate=1.
var spectate: bool = false


## The spawn option's value from its name ("random" or "line"; anything else is RANDOM).
static func spawn_named(spawn_name: String) -> Spawn:
	return Spawn.LINE if spawn_name == "line" else Spawn.RANDOM


## The thread count from a --threads=<n> option: empty keeps the usual eight, 0 one after the other.
static func threads_from_option(text: String) -> int:
	return RaceRunner.MAX_THREADS if text.is_empty() else maxi(text.to_int(), 0)


## A race on a course against these skippers.
static func race(course: String, who: PackedStringArray = DEFAULT_SKIPPERS, lap_count: int = 1, countdown_s: float = DEFAULT_PRESTART_S) -> RaceSetup:
	var setup: RaceSetup = RaceSetup.new()
	setup.course_name = course
	setup.skippers = who.duplicate()
	setup.laps = maxi(lap_count, 1)
	setup.prestart_s = maxf(countdown_s, 5.0)
	return setup


## Takes --spawn=random|line, --spawn_seed=<n> and --free_sail=<s> from the command line's user
## arguments (after "--"), for the menu's races and the sailing scene's.
func read_spawn_options() -> void:
	for arg: String in OS.get_cmdline_user_args():
		var value: String = arg.get_slice("=", 1)
		if arg.begins_with("--spawn="):
			spawn = spawn_named(value)
		elif arg.begins_with("--spawn_seed="):
			spawn_seed = value.to_int()
		elif arg.begins_with("--free_sail="):
			free_sail_s = maxf(value.to_float(), 0.0)


## Takes the spawn options and --behind=<m>, --wind=<kt>, --blind=1 and --spectate=1 from the
## command line's user arguments (after "--").
func read_options() -> void:
	read_spawn_options()
	read_options_from(OS.get_cmdline_user_args())


## --behind=<m>, --wind=<kt>, --blind=1 and --spectate=1 from a list of arguments; others are left.
func read_options_from(args: PackedStringArray) -> void:
	for arg: String in args:
		var value: String = arg.get_slice("=", 1)
		if arg.begins_with("--behind="):
			behind_m = maxf(value.to_float(), 0.0)
		elif arg.begins_with("--wind="):
			wind_kt = maxf(value.to_float(), 0.0)
		elif arg.begins_with("--blind="):
			blind = value == "1"
		elif arg.begins_with("--spectate="):
			spectate = value == "1"


## How far behind the start line the boards wait, metres: behind_m when it is set, else 1 m per
## second of countdown between 40 and 100 m (a player wants the line in sight).
func wait_behind_m() -> float:
	if behind_m > 0.0:
		return behind_m
	return clampf(prestart_s * RaceRunner.WAIT_M_PER_S, RaceRunner.NEAREST_M, RaceRunner.FARTHEST_M)


## The pending race, and clears it: whoever takes it runs it.
static func take() -> RaceSetup:
	var setup: RaceSetup = pending
	pending = null
	return setup
