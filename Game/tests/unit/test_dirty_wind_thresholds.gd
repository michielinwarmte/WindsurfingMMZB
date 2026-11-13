extends GutTest
## The thresholds that read the wind shadows' factor follow the shadow's strength (PH15, 13 November 2026). The
## skipper, the start suite's dirty-wind seconds and the HUD read the share of the wind a board has left against fixed
## numbers; when the shadow went from 30 % to the wind tunnel's 7.5 % they were all scaled with it. If the shadow's
## `deficit` in Game/config/wind_shadow_default.tres changes again, these fail until the thresholds are moved too:
## dirty is half a shadow's full strength, clean about a quarter of it, the poor sense notices only a full shadow.


func _deficit() -> float:
	return (load("res://config/wind_shadow_default.tres") as WindShadowConfig).deficit


func test_dirty_is_half_a_full_shadow() -> void:
	var deficit: float = _deficit()
	var run_race: GDScript = load("res://dev/run_race.gd") as GDScript
	assert_almost_eq(1.0 - float(run_race.get_script_constant_map()["DIRTY_FACTOR"]), 0.5 * deficit, 1e-6,
		"the start suite's dirty wind (run_race.gd DIRTY_FACTOR)")
	assert_almost_eq(1.0 - Skipper.SLALOM_GAP_DIRTY, 0.5 * deficit, 1e-6, "the slalom start's dirty spot")
	assert_almost_eq(SkipperConfig.new().dirty_air_share, 0.5 * deficit, 1e-6, "the skipper tacking out of dirty air")


func test_clean_is_about_a_quarter_of_a_full_shadow() -> void:
	var share: float = (1.0 - Skipper.SLALOM_GAP_CLEAN) / _deficit()
	assert_between(share, 0.2, 0.3, "the slalom start's clean spot (%.2f of a full shadow)" % share)


func test_the_personas_sense_spans_a_full_shadow_to_two_fifths_of_one() -> void:
	var deficit: float = _deficit()
	assert_almost_eq(Persona.DIRTY_AIR_SHARE_POOR, deficit, 1e-6, "the poor sense notices only a full shadow")
	assert_almost_eq(Persona.DIRTY_AIR_SHARE_BEST, 0.4 * deficit, 1e-6, "the best sense two fifths of one")
