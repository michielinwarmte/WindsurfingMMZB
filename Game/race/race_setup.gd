class_name RaceSetup
extends RefCounted
## What a sailing scene is asked to race (RACING_PLAN.md, 9A): the course, who is on the start
## line, the laps and the countdown. The start menu fills `pending` before it starts a scene; the
## scene takes it in its _enter_tree() (SailingScene) and clears it, so a plain sail afterwards is
## a plain sail. The command line asks for the same with --course=<name> --skippers=<name,name,...>
## [--laps=<n>] [--prestart=<s>] (tools/play.sh res://main.tscn --course=t1_loop --skippers=rookie).

## The opponents of a race from the menu: three characters of different skill and style.
const DEFAULT_SKIPPERS: PackedStringArray = ["allrounder", "gambler", "rookie"]
const DEFAULT_PRESTART_S: float = 60.0

## The race the next scene should set up; null when none.
static var pending: RaceSetup = null

var course_name: String = ""
## The characters (Game/race/skippers/<name>.tres) or brains (brain:<name>) on the line.
var skippers: PackedStringArray = PackedStringArray()
var laps: int = 1
var prestart_s: float = DEFAULT_PRESTART_S


## A race on a course against these skippers.
static func race(course: String, who: PackedStringArray = DEFAULT_SKIPPERS, lap_count: int = 1, countdown_s: float = DEFAULT_PRESTART_S) -> RaceSetup:
	var setup: RaceSetup = RaceSetup.new()
	setup.course_name = course
	setup.skippers = who.duplicate()
	setup.laps = maxi(lap_count, 1)
	setup.prestart_s = maxf(countdown_s, 5.0)
	return setup


## The pending race, and clears it: whoever takes it runs it.
static func take() -> RaceSetup:
	var setup: RaceSetup = pending
	pending = null
	return setup
