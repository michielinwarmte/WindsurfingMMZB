extends GutTest
## The game's gear brands (gear/brand.gd; Documentation/reports/fleet_gear/brands.md): the twelve
## load with their three logos, each makes boards, sails or fins, and no real maker's name
## appears in a brand's name, its tagline or its drawings (the game may not use them: copyright).

## The sport's real makers, lower case: none may appear in the game's brand files.
const REAL_BRANDS: PackedStringArray = [
	"duotone", "severne", "point-7", "point 7", "starboard", "neilpryde", "neil pryde", "jp australia",
	"fmx", "north sails", "northsails", "s2maui", "tabou", "gaastra", "ga sails", "fanatic",
]
const SLUGS: PackedStringArray = [
	"tripletone", "savanna", "point9", "moonboard", "nielstrots", "pj_new_sealand", "bmx_boards",
	"southsails", "s3kauai", "forbidden", "gg_sails", "montag",
]
const DRAWINGS: PackedStringArray = ["logo.svg", "wordmark.svg", "mark.svg"]


func test_the_twelve_brands_load() -> void:
	var brands: Array[Brand] = Brand.all()
	assert_eq(brands.size(), SLUGS.size(), "twelve brands")
	var names: Dictionary[String, bool] = {}
	for i: int in brands.size():
		var brand: Brand = brands[i]
		assert_not_null(brand, Brand.PATHS[i] + " loads as a Brand")
		if brand == null:
			continue
		assert_eq(brand.slug, SLUGS[i], "the brands come in the gear page's order")
		assert_true(Brand.PATHS[i].ends_with(brand.slug + ".tres"), brand.slug + ": the file is named after the slug")
		assert_ne(brand.name, "", brand.slug + " has a name")
		assert_ne(brand.tagline, "", brand.slug + " has a tagline")
		assert_false(names.has(brand.name), brand.name + " is used once")
		names[brand.name] = true
	assert_eq(Brand.find("savanna").name, "Savanna", "a brand is found by its slug")
	assert_null(Brand.find("nobody"), "an unknown slug finds nothing")


func test_every_brand_has_its_three_logos() -> void:
	for brand: Brand in Brand.all():
		var logos: Dictionary[String, Texture2D] = {"logo": brand.logo, "wordmark": brand.wordmark, "mark": brand.mark}
		for kind: String in logos:
			var texture: Texture2D = logos[kind]
			assert_not_null(texture, "%s has its %s" % [brand.name, kind])
			if texture == null:
				continue
			assert_gt(texture.get_width(), 1, "%s's %s is a real picture" % [brand.name, kind])
			assert_gt(texture.get_height(), 1, "%s's %s is a real picture" % [brand.name, kind])
			assert_true(texture.resource_path.contains("/" + brand.slug + "/"), "%s's %s is its own" % [brand.name, kind])
		if brand.wordmark != null:
			assert_gt(brand.wordmark.get_width(), brand.wordmark.get_height(), brand.name + "'s wordmark is wide, for the print")


func test_every_brand_makes_boards_sails_or_fins() -> void:
	var board_makers: int = 0
	var sail_makers: int = 0
	var fin_makers: int = 0
	for brand: Brand in Brand.all():
		assert_true(brand.makes_boards or brand.makes_sails or brand.makes_fins, brand.name + " makes boards, sails or fins")
		board_makers += 1 if brand.makes_boards else 0
		sail_makers += 1 if brand.makes_sails else 0
		fin_makers += 1 if brand.makes_fins else 0
	assert_eq(board_makers, 6, "six brands make boards (Michiel's table)")
	assert_eq(sail_makers, 7, "seven brands make sails")
	assert_eq(fin_makers, 1, "one brand makes fins (Montag, the lead's decision)")


func test_no_real_brand_in_a_name_or_a_tagline() -> void:
	for brand: Brand in Brand.all():
		var text: String = (brand.name + " | " + brand.tagline).to_lower()
		for real: String in REAL_BRANDS:
			assert_false(text.contains(real), "%s's name and tagline do not say '%s'" % [brand.slug, real])


func test_no_real_brand_in_the_drawings() -> void:
	for slug: String in SLUGS:
		for drawing: String in DRAWINGS:
			var path: String = "res://assets/brands/%s/%s" % [slug, drawing]
			var text: String = FileAccess.get_file_as_string(path).to_lower()
			assert_true(text.begins_with("<svg"), path + " is an SVG drawing")
			for real: String in REAL_BRANDS:
				assert_false(text.contains(real), "%s does not say '%s'" % [path, real])
