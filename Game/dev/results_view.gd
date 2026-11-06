extends Node
## The race screen at the end of a race, for screenshots (the finish list Max saw run out of the
## window on 6 November 2026): the sailing scene with a race of AI boards, and a moment later every
## board given a finish time (some still sailing, some with a penalty), so the results table shows
## as it does after a real race, without sailing one to the end.
##
##   tools/screenshot.sh res://dev/results_view.tscn out.png 200 --boards=27 [--sailing=3]
##       [--long_names=1] [--resolution=3137x1263] [--settings=<file.cfg>]
##
## --boards: the AI boards (the player's board comes on top); --sailing: how many of them have not
## finished; --long_names=1 gives the AI boards long names (a LAN game's players can type any name).
## Changes nothing in the game: it only writes finish times into this scene's own race.

const SKIPPERS: PackedStringArray = ["allrounder", "gambler", "rookie", "cautious"]


func _ready() -> void:
	var boards: int = maxi(_option("boards", "11").to_int(), 1)
	var who: PackedStringArray = PackedStringArray()
	for i: int in boards:
		who.append(SKIPPERS[i % SKIPPERS.size()])
	RaceSetup.pending = RaceSetup.race(RaceCourses.T1_NAME, who, 1, 5.0)
	var scene: SailingScene = (load("res://main.tscn") as PackedScene).instantiate()
	add_child(scene)
	for i: int in 30:
		await get_tree().process_frame
	var runner: RaceRunner = scene.get_node("RaceRunner")
	_finish(runner.race, _option("sailing", "2").to_int(), _option("long_names", "0") == "1")


## Every board a finish time 4 to 9 s after the one before, the last `sailing` still out on the
## course; every fourth finisher with a penalty. Then the race is over.
func _finish(race: RaceSim, sailing: int, long_names: bool) -> void:
	var steps: int = race.steps().size()
	var finish_s: float = 512.3
	for i: int in race.board_count():
		var board: RaceSim.Board = race._boards[i]
		if long_names and i > 0:
			board.name = "Long Player Name %d" % i
		var done: int = maxi(steps - 2, 1) if i >= race.board_count() - sailing else steps
		board.next_step = done
		board.splits = PackedFloat32Array()
		for step: int in done:
			board.splits.append(finish_s * float(step + 1) / float(steps))
		if done < steps:
			continue
		board.finish_time_s = finish_s
		board.penalty_s = 30.0 if i % 4 == 3 else 0.0
		finish_s += 4.0 + float(i % 5)
	race._first_finish_s = 512.3
	race._order_stale = true
	race.end_now()


static func _option(option: String, default: String) -> String:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--%s=" % option):
			return arg.get_slice("=", 1)
	return default
