extends GutTest
## The personas (AI_FLEET_PLAN.md D3, F4): twelve load with a name, a colour and a profile; a skill
## sheet maps onto a character sheet within the scripted skipper's ranges, the better the skill the
## better the number; consistency draws the day's sheet (the same seed, the same day; another seed,
## another); and persona:<name> makes a skipper that races headless with its sheet drawn for the race.

const RunRace: GDScript = preload("res://dev/run_race.gd")


func test_twelve_personas_load_with_a_name_a_colour_and_a_profile() -> void:
	var names: PackedStringArray = Skippers.persona_names()
	assert_eq(names.size(), 12, "twelve personas: %s" % ", ".join(names))
	var seen: Dictionary[String, bool] = {}
	for persona_name: String in names:
		var persona: Persona = Skippers.load_persona(persona_name)
		assert_not_null(persona, persona_name)
		assert_false(persona.name.is_empty())
		assert_false(persona.profile.is_empty(), "%s has a profile" % persona.name)
		assert_false(seen.has(persona.name), "%s is one of a kind" % persona.name)
		seen[persona.name] = true
		assert_true(persona.card().begins_with(persona.name))
	assert_null(Skippers.load_persona("nobody"))


func test_the_skills_map_onto_the_character_sheet_within_its_ranges() -> void:
	var best: Persona = Persona.new()
	best.name = "Best"
	best.consistency = 1.0
	for skill: String in ["start_timing", "start_nerve", "tacking", "gybing", "boat_speed", "upwind_sense", "downwind_sense", "risk", "aggression"]:
		best.set(skill, 1.0)
	var worst: Persona = Persona.new()
	worst.name = "Worst"
	worst.consistency = 1.0
	for skill: String in ["start_timing", "start_nerve", "tacking", "gybing", "boat_speed", "upwind_sense", "downwind_sense", "risk", "aggression"]:
		worst.set(skill, 0.0)
	var good: SkipperConfig = best.to_skipper_config(1)
	var poor: SkipperConfig = worst.to_skipper_config(1)
	assert_true(good.reaction_time_s < poor.reaction_time_s, "quicker hands")
	assert_true(good.steering_noise_deg < poor.steering_noise_deg, "a steadier line")
	assert_true(good.layline_margin_m < poor.layline_margin_m, "tighter laylines")
	assert_true(good.mark_margin_m < poor.mark_margin_m, "closer roundings")
	assert_true(good.shift_sensitivity_deg < poor.shift_sensitivity_deg, "sees smaller shifts")
	assert_true(good.max_tacks_per_beat > poor.max_tacks_per_beat, "tacks more freely")
	assert_true(good.downwind_vmg_twa_deg < poor.downwind_vmg_twa_deg, "runs at the fast angle, not too deep")
	assert_true(good.keep_clear_m < poor.keep_clear_m, "lets others closer")
	assert_true(good.favoured_end_bias > poor.favoured_end_bias)
	assert_true(absf(good.start_timing_error_s) <= 3.0, "a sharp start: %.1f s" % good.start_timing_error_s)
	for config: SkipperConfig in [good, poor]:
		assert_between(config.reaction_time_s, 0.2, 1.0)
		assert_between(config.steering_noise_deg, 0.0, 6.0)
		assert_between(config.layline_margin_m, 0.0, 60.0)
		assert_between(config.mark_margin_m, 4.0, 20.0)
		assert_between(config.start_timing_error_s, -3.0, 6.0)
		assert_between(config.hold_speed_ms, 1.5, 4.0)
		assert_between(config.keep_clear_m, 5.0, 30.0)
		assert_between(config.pointing_offset_deg, -4.0, 6.0)


func test_consistency_draws_the_days_sheet_seeded() -> void:
	var wobbly: Persona = Skippers.load_persona("kofi")  # consistency 0.2
	var steady: Persona = Skippers.load_persona("ines")  # consistency 0.95
	var marco: Persona = Skippers.load_persona("marco")  # consistency 0.35, no skill at the top of its range
	var a: SkipperConfig = marco.to_skipper_config(3)
	var b: SkipperConfig = marco.to_skipper_config(3)
	var c: SkipperConfig = marco.to_skipper_config(4)
	assert_eq(a.reaction_time_s, b.reaction_time_s, "the same seed, the same day")
	assert_ne(a.reaction_time_s, c.reaction_time_s, "another seed, another day")
	# Over many days the wobbly one wanders more than the steady one.
	var wobbly_spread: float = _spread(wobbly)
	var steady_spread: float = _spread(steady)
	assert_true(wobbly_spread > 2.0 * steady_spread, "Kofi's reaction time wanders %.3f s against Ines's %.3f" % [wobbly_spread, steady_spread])


static func _spread(persona: Persona) -> float:
	var values: PackedFloat32Array = PackedFloat32Array()
	for seed: int in range(1, 41):
		values.append(persona.to_skipper_config(seed).reaction_time_s)
	var mean: float = 0.0
	for v: float in values:
		mean += v
	mean /= values.size()
	var variance: float = 0.0
	for v: float in values:
		variance += (v - mean) * (v - mean)
	return sqrt(variance / values.size())


func test_a_persona_races_headless_with_its_sheet_drawn_for_the_race() -> void:
	var skipper: RaceSkipper = Skippers.make("persona:lena")
	assert_not_null(skipper)
	assert_eq(skipper.skipper_name(), "Lena")
	assert_true(skipper is Skipper)
	var course: Course = RaceCourses.t1_loop(270.0, Vector2.ZERO)
	var race: RaceSim = RaceSim.new(course, 1, 10.0)
	var entries: Array = RunRace.make_entries(race, course, PackedStringArray(["persona:lena", "persona:tobias"]), 15.0, 50.0, 5)
	assert_eq(entries.size(), 2)
	var lena: Skipper = entries[0].skipper as Skipper
	var tobias: Skipper = entries[1].skipper as Skipper
	assert_eq(lena.config.name, "Lena")
	assert_eq(tobias.config.name, "Tobias")
	assert_true(tobias.config.pointing_offset_deg < lena.config.pointing_offset_deg, "Tobias points higher than Lena")
	assert_true(lena.config.favoured_end_bias > tobias.config.favoured_end_bias, "Lena is keener on the favoured end")
	race.start()
	for t: int in 60 * 20:
		RunRace.step_race(race, entries)
	assert_true(entries[0].sim.telemetry.speed_ms > 1.0 or entries[1].sim.telemetry.speed_ms > 1.0, "they sail")
