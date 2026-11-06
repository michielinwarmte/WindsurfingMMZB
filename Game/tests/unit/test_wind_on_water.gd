extends GutTest
## The wind's strength on the water (wind_on_water.md; lake_look.gdshaderinc 5. to 7.; LakeLook): the
## whitecap laws give the measured cover at the five winds of the contact sheets and rise steeply with the
## wind, the two fits of Callaghan et al. 2008 meet, the lake's fresh water and young waves give less, and
## the shader carries the same coefficients.

const SHADER_INCLUDE_PATH: String = "res://world/lake_look.gdshaderinc"
const LAKE_LOOK_PATH: String = "res://maps/silvaplana/lake_water.tres"
const SEA_LOOK_PATH: String = "res://world/sea_water.tres"


func _ms(knots: float) -> float:
	return knots * SimMath.KNOT_MS


func test_the_open_seas_cover_by_callaghan_2008() -> void:
	# Percent of the water: none in 8 kt, 0.05 in 12, 0.55 in 18, 1.4 in 24, 2.5 in 30 (Albert et al. 2016's fits).
	assert_lt(LakeLook.sea_whitecap_percent(_ms(8.0)), 0.001, "8 kt: practically none")
	assert_almost_eq(LakeLook.sea_whitecap_percent(_ms(12.0)), 0.048, 0.002)
	assert_almost_eq(LakeLook.sea_whitecap_percent(_ms(18.0)), 0.547, 0.01)
	assert_almost_eq(LakeLook.sea_whitecap_percent(_ms(24.0)), 1.42, 0.02)
	assert_almost_eq(LakeLook.sea_whitecap_percent(_ms(30.0)), 2.54, 0.03)
	# The two fits meet at 10.18 m/s.
	assert_almost_eq(LakeLook.sea_whitecap_percent(10.179), LakeLook.sea_whitecap_percent(10.181), 0.005, "no step where the fits meet")


func test_monahan_and_omuircheartaigh_1980() -> void:
	var law: LakeLook.WhitecapLaw = LakeLook.WhitecapLaw.MONAHAN_1980
	assert_almost_eq(LakeLook.sea_whitecap_percent(_ms(18.0), law), 0.76, 0.01, "W = 3.84e-6 U^3.41 as a fraction")
	assert_almost_eq(LakeLook.sea_whitecap_percent(_ms(30.0), law), 4.3, 0.1)


func test_the_cover_rises_steeply_with_the_wind() -> void:
	# About the wind's cube: each step of the contact sheet at least twice the one before (from 12 kt).
	var before: float = 0.0
	for knots: float in [12.0, 18.0, 24.0, 30.0]:
		var cover: float = LakeLook.whitecap_cover(_ms(knots), 0.0, LakeLook.WhitecapLaw.CALLAGHAN_2008)
		assert_gt(cover, 1.7 * before, "%.0f kt: more whitecaps" % knots)
		before = cover


func test_the_lakes_fresh_water_and_young_waves_give_less() -> void:
	var sea: float = LakeLook.whitecap_cover(_ms(18.0), 0.0, LakeLook.WhitecapLaw.CALLAGHAN_2008)
	# At the camping beach the lake's waves in 18 kt peak at about 1.5 s: old enough to break fully.
	var beach: float = LakeLook.whitecap_cover(_ms(18.0), 1.48, LakeLook.WhitecapLaw.CALLAGHAN_2008, LakeLook.FRESH_WATER_FACTOR)
	assert_almost_eq(beach, 0.66 * sea, 1e-6, "fresh water's foam lasts two thirds as long")
	# 100 m from Sils the waves peak at about 0.6 s: in 18 kt they are only starting to break there
	# (R_B about 600): about a ninth of the beach's.
	var sils: float = LakeLook.whitecap_cover(_ms(18.0), 0.57, LakeLook.WhitecapLaw.CALLAGHAN_2008, LakeLook.FRESH_WATER_FACTOR)
	assert_lt(sils, beach / 5.0, "near Sils: few")
	assert_eq(LakeLook.whitecap_cover(_ms(15.0), 0.57, LakeLook.WhitecapLaw.CALLAGHAN_2008, LakeLook.FRESH_WATER_FACTOR), 0.0, "near Sils in 15 kt: none")
	# In 12 kt at the beach the waves are just starting to break.
	var light: float = LakeLook.whitecap_cover(_ms(12.0), 1.48, LakeLook.WhitecapLaw.CALLAGHAN_2008, LakeLook.FRESH_WATER_FACTOR)
	assert_between(light, 0.0, 0.0001, "12 kt: a few at most")
	# Zhao and Toba is still there to choose.
	assert_eq(LakeLook.whitecap_cover(_ms(18.0), 1.48, LakeLook.WhitecapLaw.ZHAO_TOBA), LakeLook.whitecap_fraction(_ms(18.0), 1.48))


func test_the_looks_choose_their_laws() -> void:
	var lake: ShaderMaterial = load(LAKE_LOOK_PATH) as ShaderMaterial
	var sea: ShaderMaterial = load(SEA_LOOK_PATH) as ShaderMaterial
	assert_eq(int(lake.get_shader_parameter("whitecap_law")), LakeLook.WhitecapLaw.CALLAGHAN_2008)
	assert_almost_eq(float(lake.get_shader_parameter("whitecap_water_factor")), LakeLook.FRESH_WATER_FACTOR, 1e-6)
	assert_almost_eq(float(lake.get_shader_parameter("foam_life_s")), 2.54, 1e-6, "fresh water's foam")
	assert_eq(int(sea.get_shader_parameter("whitecap_law")), LakeLook.WhitecapLaw.CALLAGHAN_2008)
	assert_almost_eq(float(sea.get_shader_parameter("foam_life_s")), 3.85, 1e-6, "sea water's foam")


func test_the_shader_has_the_same_numbers() -> void:
	var text: String = FileAccess.get_file_as_string(SHADER_INCLUDE_PATH)
	for number: String in ["3.18e-3", "4.82e-4", "3.84e-4", "3.41", "10.18", "3.70", "1.98"]:
		assert_true(text.contains(number), "the shader has %s" % number)
	assert_true(text.contains("uniform float whitecap_young_onset = %.1f;" % LakeLook.YOUNG_ONSET), "the same young-wave onset")
