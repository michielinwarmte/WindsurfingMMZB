class_name CreditsPage
extends MenuPage
## The credits (ROADMAP MA2), from the start menu's Credits button: who made the game, the open data
## Lake Silvaplana is built from with the source each provider asks to be named, and the licence
## notices the shipped game must carry: Godot Engine's, those of the parts Godot is made of, and those
## of the test framework that ships inside the game's package with its fonts.
##
## The providers' wording was checked on their terms pages on 5 November 2026 (the sources are in
## Documentation/reports/ui/small_fixes_6nov.md):
##   swisstopo: "©swisstopo" or "Federal Office of Topography swisstopo"; swissALTIRegio, the
##     distant mountains, has a longer reference of its own (SWISSALTIREGIO_SOURCE);
##   MeteoSwiss: "Source: MeteoSwiss", licence CC BY 4.0;
##   BAFU: its terms page could not be opened, so the map plan's line stands.
## Godot's texts come from the engine itself (Engine.get_license_text(), get_copyright_info() and
## get_license_info()), so they always match the Godot the game is built with. The text is put
## together the first time the page opens (it is long: every licence text is in it).

## The credits line of the map plan (MAP_SILVAPLANA_PLAN.md, "The open data we use").
const DATA_LINE: String = "Terrain, aerial photos and lakebed: © swisstopo. Wind data: MeteoSwiss. Lake level: BAFU."
## swissALTIRegio's own source reference (swisstopo.admin.ch/en/height-model-swissaltiregio, for
## the versions of 2025 and later).
const SWISSALTIREGIO_SOURCE: String = "Bundesamt für Landestopografie swisstopo; Tarquini S., I. Isola, M. Favalli, A. Battistini, G. Dotta (2023). TINITALY, a digital elevation model of Italy with a 10 meters cell size (Version 1.1). Istituto Nazionale di Geofisica e Vulcanologia (INGV). https://doi.org/10.13127/tinitaly/1.1; DGM Österreich, geoland.at; DGM1, Bayerische Vermessungsverwaltung – www.geodaten.bayern.de; DGM1, Baden-Württemberg: LGL, www.lgl-bw.de, dl-de/by-2-0; RGEAlti, Institut National de l'information géographique et forestière, données originales téléchargées sur https://geoservices.ign.fr/rgealti#telechargement5m, mise à jour du juillet 2023."

## The sections before Godot's: a heading and its text.
const SECTIONS: Array[Array] = [
	["Windsurfing Simulator", "Made by the MMZB team. The boards, sails and fins, the sailor and the brands are the game's own, built by the team's Blender scripts. Every sound is made by the game from numbers: there are no recordings in it. The text is drawn in your computer's own fonts."],
	["Lake Silvaplana: the open data", DATA_LINE
		+ "\n\nTerrain, aerial photos and lakebed (swissALTI3D, SWISSIMAGE, swissBATHY3D): Federal Office of Topography swisstopo, ©swisstopo."
		+ "\n\nThe distant mountains (swissALTIRegio): " + SWISSALTIREGIO_SOURCE
		+ "\n\nWind data: Source: MeteoSwiss. The measurements of its weather stations, under the Creative Commons Attribution 4.0 licence (CC BY 4.0, https://creativecommons.org/licenses/by/4.0/); the game's wind is made from them. MeteoSwiss does not endorse this game."
		+ "\n\nLake level: BAFU, the Federal Office for the Environment."],
]
## The test framework (GUT, Game/addons/gut/) is in the game's package, with its fonts.
const GUT_NOTICE: String = "GUT, the framework the team tests the game with, is in the game's package: Copyright (c) 2018 Tom \"Butch\" Wesley, under the MIT licence (its text is \"Expat\" below).\n\nGUT's fonts, under the SIL Open Font License 1.1 (its text is \"OFL-1.1\" below):\nAnonymous Pro: Copyright (c) 2009, Mark Simonson (http://www.ms-studio.com), with Reserved Font Name Anonymous Pro.\nCourier Prime: Copyright 2015 The Courier Prime Project Authors (https://github.com/quoteunquoteapps/CourierPrime).\nLobster Two: Copyright (c) 2011, Pablo Impallari (www.impallari.com), with Reserved Font Name Lobster.\nSource Code Pro (a bitmap font made from it): Copyright Adobe (http://www.adobe.com/), with Reserved Font Name 'Source'."
## The size of the body text, pixels (the theme's default is for buttons and labels).
const BODY_FONT_SIZE: int = 16

@onready var _text: RichTextLabel = %Text
@onready var _back_button: Button = %BackButton
var _filled: bool = false


func _ready() -> void:
	_back_button.pressed.connect(close)


## Shows the page; its text is put together the first time.
func open() -> void:
	if not _filled:
		_fill()
	super()


## The text has the focus, so the arrow keys and Page Up/Down scroll it; Esc goes back.
func first_focus() -> Control:
	return _text


## Everything the page shows, as plain text (for the tests).
func text() -> String:
	if not _filled:
		_fill()
	return _text.get_parsed_text()


func _fill() -> void:
	_filled = true
	_text.clear()
	for section: Array in SECTIONS:
		_add_section(section[0], section[1])
	_add_section("Made with Godot Engine", "This game uses Godot Engine, available under the following license:\n\n" + Engine.get_license_text())
	_add_section("The parts Godot is made of", "Godot Engine includes the following, each under its own licence (the texts are at the end).\n\n" + godot_parts_text())
	_add_section("Shipped inside the game", GUT_NOTICE)
	var licenses: Dictionary = Engine.get_license_info()
	var names: Array = licenses.keys()
	names.sort()
	for license_name: Variant in names:
		_add_section("Licence text: %s" % license_name, str(licenses[license_name]))
	_text.scroll_to_line(0)


## Each part of Godot with its copyright holders and licence, one line each (from the engine).
static func godot_parts_text() -> String:
	var lines: PackedStringArray = PackedStringArray()
	for component: Dictionary in Engine.get_copyright_info():
		var seen: PackedStringArray = PackedStringArray()
		for part: Dictionary in component["parts"]:
			var line: String = "%s: © %s (%s)" % [component["name"], "; ".join(PackedStringArray(part["copyright"])), part["license"]]
			if not seen.has(line):
				seen.append(line)
				lines.append(line)
	return "\n".join(lines)


## A heading in the theme's section style and its text; the text is added as it is (no markup is
## read from it: licence texts have brackets).
func _add_section(heading: String, body: String) -> void:
	_text.push_font(get_theme_font("font", &"SectionLabel"))
	_text.push_font_size(get_theme_font_size("font_size", &"SectionLabel"))
	_text.push_color(get_theme_color("font_color", &"SectionLabel"))
	_text.add_text(heading)
	_text.pop()
	_text.pop()
	_text.pop()
	_text.newline()
	_text.push_font_size(BODY_FONT_SIZE)
	_text.add_text(body.strip_edges())
	_text.pop()
	_text.newline()
	_text.newline()
