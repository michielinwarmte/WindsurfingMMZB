extends GutTest
## The personas (AI_FLEET_PLAN.md D3, F4; fleet_speed package 3): twenty load with a name, a colour
## and a profile; a skill sheet maps onto a character sheet within the scripted skipper's ranges, the
## better the skill the better the number; a bold persona pushes the slider and a careful one eases
## it; the wind skills make a light-wind and a strong-wind specialist; consistency draws the day's
## sheet (the same seed, the same day; another seed, another); persona:<name> makes a skipper that
## races headless with its sheet drawn for the race; and each persona sails its own gear from the
## catalogue, sized for the wind, when the race's gear is on.

const RunRace: GDScript = preload("res://dev/run_race.gd")


func test_twenty_personas_load_with_a_name_a_colour_and_a_profile() -> void:
	var names: PackedStringArray = Skippers.persona_names()
	assert_eq(names.size(), 20, "twenty personas: %s" % ", ".join(names))
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
	var gyber: Persona = _sheet("Gyber", 0.5)
	gyber.gybing = 1.0
	assert_true(gyber.to_skipper_config(1, 18.0).mark_margin_m < _sheet("Plain", 0.5).to_skipper_config(1, 18.0).mark_margin_m, "a good gyber rounds tighter")
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


func test_a_bold_persona_pushes_and_a_careful_one_eases() -> void:
	var bold: Persona = _sheet("Bold", 0.7)
	bold.risk = 1.0
	var careful: Persona = _sheet("Careful", 0.7)
	careful.risk = 0.0
	var middling: Persona = _sheet("Middling", 0.5)
	middling.risk = 0.5
	assert_true(bold.to_skipper_config(1, 18.0).push_offset > 0.05, "the bold one pushes past the pilot's margin")
	assert_true(careful.to_skipper_config(1, 18.0).push_offset < -0.05, "the careful one eases")
	assert_eq(middling.to_skipper_config(1, 18.0).push_offset, 0.0, "a middling one leaves the slider alone")
	# Good hands push a little more than poor ones, and nobody goes past the cap.
	assert_true(Persona.push_offset_for(0.9, 1.0) > Persona.push_offset_for(0.9, 0.0))
	assert_between(Persona.push_offset_for(1.0, 1.0), 0.0, Persona.PUSH_MAX)
	assert_between(Persona.push_offset_for(0.0, 0.0), -Persona.PUSH_MAX, 0.0)
	# The sheets: Marco the gambler pushes, Ines the careful one eases.
	assert_true(Skippers.load_persona("marco").to_skipper_config(1, 18.0).push_offset > 0.0, "Marco pushes")
	assert_true(Skippers.load_persona("ines").to_skipper_config(1, 18.0).push_offset < 0.0, "Ines eases")


func test_the_wind_skills_make_light_and_strong_wind_specialists() -> void:
	var light: Persona = _sheet("Light", 0.6)
	light.light_wind = 1.0
	light.strong_wind = 0.0
	assert_true(light.wind_form(12.0) > 0.0 and light.wind_form(24.0) < 0.0)
	assert_eq(light.wind_form(Persona.MIDDLE_WIND_KT), 0.0, "neither better nor worse in the middle wind")
	var in_light: SkipperConfig = light.to_skipper_config(1, 12.0)
	var in_strong: SkipperConfig = light.to_skipper_config(1, 24.0)
	assert_true(in_light.steering_noise_deg < in_strong.steering_noise_deg, "steadier in its own light wind")
	assert_true(light.light_wind_foot_deg(12.0) > 2.0, "foots off in a light wind to keep planing")
	assert_eq(light.light_wind_foot_deg(18.0), 0.0, "not in the middle wind")
	var hater: Persona = _sheet("Hater", 0.6)
	hater.light_wind = 0.0
	assert_true(hater.light_wind_foot_deg(12.0) < -2.0, "one who dislikes light wind pinches")
	assert_true(in_light.mark_margin_m < in_strong.mark_margin_m, "rounds tighter in its own wind")
	# The sheets: Liv is the light-wind sailor, Bruno the strong-wind one.
	var liv: Persona = Skippers.load_persona("liv")
	var bruno: Persona = Skippers.load_persona("bruno")
	assert_true(liv.wind_form(12.0) > bruno.wind_form(12.0), "Liv is better than Bruno in 12 kt")
	assert_true(bruno.wind_form(24.0) > liv.wind_form(24.0), "Bruno is better than Liv in 24 kt")
	assert_true(liv.rig_power() > bruno.rig_power(), "Liv rigs bigger than Bruno")


func test_from_rookie_to_pro() -> void:
	var pro: SkipperConfig = Skippers.load_persona("hana").to_skipper_config(1, 18.0)
	var rookie: SkipperConfig = Skippers.load_persona("pia").to_skipper_config(1, 18.0)
	assert_true(pro.steering_noise_deg < 1.0, "the pro's line is steady: %.1f degrees" % pro.steering_noise_deg)
	assert_true(rookie.steering_noise_deg > 4.0, "the rookie wobbles: %.1f degrees" % rookie.steering_noise_deg)
	assert_true(pro.reaction_time_s < rookie.reaction_time_s)
	assert_true(pro.pointing_offset_deg < rookie.pointing_offset_deg)
	assert_true(pro.downwind_vmg_twa_deg < rookie.downwind_vmg_twa_deg)


func test_a_persona_picks_its_gear_for_the_wind_from_the_catalogue() -> void:
	var liv: Persona = Skippers.load_persona("liv")
	var bruno: Persona = Skippers.load_persona("bruno")
	for wind_kt: float in [12.0, 18.0, 24.0]:
		for persona: Persona in [liv, bruno]:
			var gear: GearChoice = persona.gear_for(wind_kt)
			assert_eq(gear.sail.brand.slug, persona.sail_brand, "%s's sail is of its brand" % persona.name)
			assert_eq(gear.board.brand.slug, persona.board_brand, "%s's board is of its brand" % persona.name)
			for item: GearItem in [gear.board, gear.sail, gear.fin]:
				assert_between(wind_kt, item.wind_from_kt, item.wind_to_kt, "%s's %s fits %d kt" % [persona.name, item.title(), wind_kt])
		assert_true(liv.gear_for(wind_kt).sail.size >= bruno.gear_for(wind_kt).sail.size, "the light-wind sailor rigs no smaller")
	assert_true(liv.gear_for(12.0).sail.size > liv.gear_for(24.0).sail.size, "a smaller sail in a strong wind")
	# Of the items that fit, power 0 takes the smallest and power 1 the biggest.
	var sails: Array[GearItem] = Persona.brand_items(GearItem.Kind.SAIL, "savanna")
	assert_eq(Persona.pick_for_wind(sails, 18.0, 0.0).size, 6.5)
	assert_eq(Persona.pick_for_wind(sails, 18.0, 1.0).size, 8.5)
	# A wind beyond every range: the nearest one.
	assert_eq(Persona.pick_for_wind(sails, 40.0, 0.5).size, 5.5)
	# A brand without a slalom board: its free race board (Pia's beginner board).
	var pia: GearChoice = Skippers.load_persona("pia").gear_for(12.0)
	assert_eq(pia.board.brand.slug, "savanna")
	assert_eq(pia.board.line, GearItem.Line.FREERACE)


func test_with_the_gear_on_a_persona_sails_its_own_gear_and_a_character_the_default() -> void:
	var course: Course = RaceCourses.t1_loop(270.0, Vector2.ZERO)
	var race: RaceSim = RaceSim.new(course, 1, 10.0)
	var entries: Array = RunRace.make_entries(race, course, PackedStringArray(["persona:bruno", "allrounder"]), 24.0, 50.0, 2,
		"line", null, 0, -1.0, true)
	var wanted: GearChoice = Skippers.load_persona("bruno").gear_for(24.0)
	var bruno: WindsurferSim = entries[0].sim
	assert_almost_eq(bruno.sail_config.area_m2, wanted.sail.size, 1e-4, "Bruno's own sail")
	assert_almost_eq(bruno.board_config.volume_m3, (wanted.board.config as BoardConfig).volume_m3, 1e-6, "Bruno's own board")
	assert_eq(bruno.sail.config, bruno.sail_config, "the sail model holds that sail")
	var plain: SailConfig = load("res://config/sail_default.tres") as SailConfig
	assert_almost_eq(entries[1].sim.sail_config.area_m2, plain.area_m2, 1e-6, "the all-rounder keeps the default sail")
	assert_null(Skippers.gear_for(entries[1].skipper, 24.0), "a character has no gear of its own")
	# Off (the default), the persona sails the default gear too.
	var off: Array = RunRace.make_entries(RaceSim.new(course, 1, 10.0), course, PackedStringArray(["persona:bruno"]), 24.0, 50.0, 2)
	assert_almost_eq(off[0].sim.sail_config.area_m2, plain.area_m2, 1e-6)
	# They sail on their gear.
	race.start()
	for t: int in 60 * 10:
		RunRace.step_race(race, entries)
	assert_true(bruno.telemetry.speed_ms > 1.0, "Bruno sails on his own gear: %.1f m/s" % bruno.telemetry.speed_ms)


func test_the_race_page_lists_the_twenty() -> void:
	var fleet: PackedStringArray = RacePage.fleet_names(RacePage.Who.PERSONAS, 20)
	for persona_name: String in Skippers.persona_names():
		assert_true(fleet.has("persona:" + persona_name), "%s sails in a fleet of twenty" % persona_name)
	assert_eq(RacePage._persona_cards().split("\n").size(), 20, "a card per persona")


## A sheet with every sailing skill at one level and no wander from day to day.
static func _sheet(sheet_name: String, level: float) -> Persona:
	var persona: Persona = Persona.new()
	persona.name = sheet_name
	persona.consistency = 1.0
	for skill: String in ["start_timing", "start_nerve", "tacking", "gybing", "boat_speed", "upwind_sense", "downwind_sense", "risk", "aggression"]:
		persona.set(skill, level)
	return persona
