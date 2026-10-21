extends GutTest
## The racing rules in a headless race (F3, RaceRules in the race tool's race): the judge is fed
## every tick; a scripted skipper given a penalty turns a full circle on the first leg and the
## judge clears it (no time carried); a penalty that stands at the finish adds 20 s to the race
## time; and a race with the rules on sails on (two characters, 60 s, no errors).

const RunRace: GDScript = preload("res://dev/run_race.gd")
const DT: float = 1.0 / 60.0


static func _race_of_two(prestart_s: float) -> Dictionary:
	var course: Course = RaceCourses.t1_loop(270.0, Vector2.ZERO)
	var race: RaceSim = RaceSim.new(course, 1, prestart_s)
	var entries: Array = RunRace.make_entries(race, course, PackedStringArray(["allrounder", "cautious"]), 15.0, 50.0, 1)
	var rules: RaceRules = RunRace.give_rules(entries, race, course)
	race.start()  # the countdown (the race tool's main loop does this)
	return {"race": race, "entries": entries, "rules": rules}


func test_a_penalised_skipper_turns_a_full_circle_and_the_judge_clears_it() -> void:
	var parts: Dictionary = _race_of_two(30.0)
	var race: RaceSim = parts["race"]
	var entries: Array = parts["entries"]
	var rules: RaceRules = parts["rules"]
	var skipper: Skipper = entries[1].skipper as Skipper
	assert_eq(skipper.rules, rules, "the skipper knows the judge")
	# Through the countdown and the start and some 40 s up the beat, so it is racing with speed.
	for t: int in roundi(70.0 / DT):
		RunRace.step_race(race, entries, false, rules)
	assert_eq(race.next_step_index(1), 1, "started")
	var given_before: int = rules.penalties(1) + rules.turns_done(1)
	rules.penalise(1, RaceRules.Why.PORT_GIVES_WAY)
	assert_almost_eq(race.time_penalty_s(1), 0.0, 1e-6, "not told the race before the next tick")
	var heading_before: float = entries[1].sim.telemetry.heading_deg
	var turned_at_s: float = -1.0
	for t: int in roundi(45.0 / DT):
		RunRace.step_race(race, entries, false, rules)
		if turned_at_s < 0.0 and rules.penalties(1) == 0:
			turned_at_s = race.race_time_s()
	assert_true(rules.turns_done(1) >= 1, "the penalty is cleared by a turn (%d given before, %d standing)" % [given_before, rules.penalties(1)])
	assert_true(skipper.penalty_turns >= 1, "the skipper counts its penalty turn")
	assert_true(turned_at_s > 0.0, "cleared %.1f s into the race" % turned_at_s)
	assert_true(skipper.tacks >= 1 and skipper.gybes >= 1, "a tack and a gybe: %d tacks, %d gybes" % [skipper.tacks, skipper.gybes])
	gut.p("The penalty turn was cleared at %.1f s of race time; the heading was %.0f before and is %.0f after" % [turned_at_s, heading_before, entries[1].sim.telemetry.heading_deg])


func test_a_penalty_that_stands_adds_20_s_at_the_finish() -> void:
	var course: Course = RaceCourses.t1_loop(270.0, Vector2.ZERO)
	var race: RaceSim = RaceSim.new(course, 1, 0.0)
	race.add_board("a")
	var finish: RaceStep = race.steps()[-1]
	var before: Vector2 = finish.target() - finish.in_dir * 2.0
	var after: Vector2 = finish.target() + finish.in_dir * 2.0
	race.place_board(0, before, race.steps().size() - 1)
	race.update_board(0, before)
	race.start()
	race.set_time_penalty_s(0, 20.0)
	for t: int in 60:
		race.update_board(0, before)
		race.step(DT)
	race.update_board(0, after)
	race.step(DT)
	assert_true(race.is_finished(0))
	var crossing_s: float = race.splits_s(0)[-1]
	assert_almost_eq(race.finish_time_s(0), crossing_s + 20.0, 1e-3, "the crossing plus the penalty")
	var result: RaceResult = race.results()[0]
	assert_almost_eq(result.penalty_s, 20.0, 1e-6)
	assert_true(result.to_line().contains("(+20 s penalty)"), result.to_line())
	race.set_time_penalty_s(0, 0.0)
	assert_almost_eq(race.finish_time_s(0), crossing_s + 20.0, 1e-3, "a finished board's time stays")


func test_a_race_with_the_rules_on_sails_on() -> void:
	var parts: Dictionary = _race_of_two(30.0)
	var race: RaceSim = parts["race"]
	var entries: Array = parts["entries"]
	var rules: RaceRules = parts["rules"]
	for t: int in roundi(60.0 / DT):
		RunRace.step_race(race, entries, false, rules)
	for i: int in 2:
		assert_true(race.next_step_index(i) >= 1, "board %d started" % i)
		assert_true(rules.penalties(i) + rules.turns_done(i) <= 2, "few incidents in 60 s with two boards: %d" % (rules.penalties(i) + rules.turns_done(i)))
