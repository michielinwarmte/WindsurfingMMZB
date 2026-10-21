extends GutTest
## The countdown gathers the fleet (AI_FLEET_PLAN.md, F2): 16 boards (the four characters, four of
## each) appear at random spots of the sailing area round the start line, the menu's 60 s countdown
## starts at once, and every skipper sails to the line and starts. Sailed the way tools/race.sh
## sails them (the open water's default simulation with its waves, the beginner controller with the
## skipper's hands on it), at 15 kt, on T1 (an upwind start on the open water) and on T2 (the lake's
## reaching start; the area kept off the lake's shore):
##   - every board starts within 20 s after the gun;
##   - at most 2 boards are over the line at the gun (OCS);
##   - nobody is outside the sailing area at the gun.
## The two races are sailed side by side on worker threads (before_all()), each stopped 20 s after
## the gun. They take several minutes: 16 boards are 16 simulations.

const RunRace: GDScript = preload("res://dev/run_race.gd")
const DT: float = 1.0 / 60.0
const PRESTART_S: float = 60.0
const WIND_KT: float = 15.0
const BOARDS: int = 16
const CHARACTERS: PackedStringArray = ["allrounder", "cautious", "gambler", "rookie"]
## Every board must have started this long after the gun, seconds.
const START_WITHIN_S: float = 20.0
const MOST_OCS: int = 2


## One race of the fleet and what is watched in it.
class Run:
	var course_name: String = ""
	var course: Course
	var area: SailingArea
	var race: RaceSim
	var entries: Array[RunRace.Entry] = []
	var outside_at_gun: PackedStringArray = PackedStringArray()
	var report: String = ""

	## Set up on the main thread (it loads the configuration files).
	func setup(spawn_seed: int) -> void:
		course = RunRace.course_named(course_name)
		area = RunRace.sailing_area_for(course_name, course)
		race = RaceSim.new(course, 1, PRESTART_S)
		var who: PackedStringArray = PackedStringArray()
		for i: int in BOARDS:
			who.append(CHARACTERS[i % CHARACTERS.size()])
		entries = RunRace.make_entries(race, course, who, WIND_KT, 50.0, 0, "random", area, spawn_seed)
		race.start()

	## Sails the countdown and START_WITHIN_S after the gun: on a worker thread.
	func sail() -> void:
		var gun_seen: bool = false
		for _tick: int in roundi((PRESTART_S + START_WITHIN_S) / DT):
			RunRace.step_race(race, entries)
			if not gun_seen and race.clock_s() >= 0.0:
				gun_seen = true
				outside_at_gun = RunRace.boards_outside(race, area)
			if race.clock_s() >= START_WITHIN_S:
				break
		report = RunRace.start_report(race, entries, outside_at_gun)

	func not_started() -> PackedStringArray:
		var names: PackedStringArray = PackedStringArray()
		for i: int in entries.size():
			if race.next_step_index(i) == 0:
				names.append(entries[i].name)
		return names

	func ocs_count() -> int:
		var count: int = 0
		for entry: RunRace.Entry in entries:
			if (entry.skipper as Skipper).was_ocs:
				count += 1
		return count


var _runs: Dictionary[String, Run] = {}


func before_all() -> void:
	for course_name: String in [RaceCourses.T1_NAME, RaceCourses.T2_NAME]:
		var run: Run = Run.new()
		run.course_name = course_name
		run.setup(1)
		_runs[course_name] = run
	var tasks: Array[int] = []
	for key: String in _runs:
		tasks.append(WorkerThreadPool.add_task(_runs[key].sail, true, key))
	for task: int in tasks:
		WorkerThreadPool.wait_for_task_completion(task)
	for key: String in _runs:
		print("%s, 16 boards from random spots at 15 kt:\n%s" % [key, _runs[key].report])


func test_the_fleet_gathers_and_starts_on_t1() -> void:
	_check(_runs[RaceCourses.T1_NAME])


func test_the_fleet_gathers_and_starts_on_the_lake() -> void:
	_check(_runs[RaceCourses.T2_NAME])


func _check(run: Run) -> void:
	assert_eq(run.entries.size(), BOARDS, "16 boards")
	assert_eq(run.not_started(), PackedStringArray(), "Every board started within %.0f s after the gun" % START_WITHIN_S)
	assert_true(run.ocs_count() <= MOST_OCS, "At most %d over the line at the gun: %d" % [MOST_OCS, run.ocs_count()])
	assert_eq(run.outside_at_gun, PackedStringArray(), "Nobody outside the sailing area at the gun")
