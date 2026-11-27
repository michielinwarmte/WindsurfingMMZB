class_name CommentaryWords
extends RefCounted
## The words the commentary puts into a line's slots (BANK_FORMAT.md, "The slots"): a place as he says
## it ("first", "second"), which mark ("first", "last"), which leg ("penultimate"), and a sail's colour
## as a plain word, only when the colour can be named with confidence. Plain functions, for the tests.

## The places as words, first to twentieth; a place beyond is not said as a word (the slot stays empty).
const PLACE_WORDS: PackedStringArray = [
	"first", "second", "third", "fourth", "fifth", "sixth", "seventh", "eighth", "ninth", "tenth",
	"eleventh", "twelfth", "thirteenth", "fourteenth", "fifteenth", "sixteenth", "seventeenth", "eighteenth",
	"nineteenth", "twentieth",
]

## The colours named, by hue (degrees round the colour wheel: 0 red, 120 green, 240 blue). Each name
## covers [from, to); the gaps between them are hues no one would name for sure (a blue-green, a
## purple-pink), and a sail there gets no colour word. Red wraps round 0.
const HUE_NAMES: Array[Array] = [
	[345.0, 360.0, "red"], [0.0, 12.0, "red"],
	[18.0, 42.0, "orange"],
	[46.0, 66.0, "yellow"],
	[75.0, 150.0, "green"],
	[160.0, 186.0, "turquoise"],
	[196.0, 252.0, "blue"],
	[260.0, 300.0, "purple"],
	[308.0, 342.0, "pink"],
]
## How grey a colour may be and still be named by its hue (its saturation, 0 grey to 1 pure); below
## GREY_SATURATION it is white, grey or black by its brightness; between the two it is pale and not
## named at all.
const HUE_SATURATION: float = 0.38
const GREY_SATURATION: float = 0.12
## Too dark to tell a hue: black below this brightness (0 to 1), and an orange this dark is brown.
const BLACK_VALUE: float = 0.18
const BROWN_VALUE: float = 0.45
## A light blue sail is said as "light blue": paler than this saturation and brighter than this value.
const LIGHT_SATURATION: float = 0.5
const LIGHT_VALUE: float = 0.85


## "first" for 1, ..., "twentieth"; "" for a place that has no word here.
static func place_word(place: int) -> String:
	if place < 1 or place > PLACE_WORDS.size():
		return ""
	return PLACE_WORDS[place - 1]


## Which mark, as he says it: "first", "second", ... and "last" for the last mark of the race.
## `number` counts the race's marks and gates from 1; `count` is how many it has.
static func mark_word(number: int, count: int) -> String:
	if number < 1 or number > count:
		return ""
	if number == count and count > 1:
		return "last"
	return place_word(number)


## Which leg, as he says it: "first", "second", ..., "penultimate" for the one before the last (a race
## of three legs or more) and "last". `number` counts the legs from 1 (the start to the first mark).
static func leg_word(number: int, count: int) -> String:
	if number < 1 or number > count:
		return ""
	if number == count and count > 1:
		return "last"
	if number == count - 1 and count >= 3:
		return "penultimate"
	return place_word(number)


## A sail colour as a plain word ("red", "light blue", "grey"), or "" when it cannot be named with
## confidence (a hue between two names, a pale tint).
static func colour_word(colour: Color) -> String:
	if colour.a <= 0.0:
		return ""
	var saturation: float = colour.s
	var value: float = colour.v
	if value < BLACK_VALUE:
		return "black"
	if saturation < GREY_SATURATION:
		if value > 0.85:
			return "white"
		return "grey" if value > 0.3 else "black"
	if saturation < HUE_SATURATION:
		return ""
	var hue_deg: float = colour.h * 360.0
	for named: Array in HUE_NAMES:
		if hue_deg >= float(named[0]) and hue_deg < float(named[1]):
			var word: String = str(named[2])
			if word == "orange" and value < BROWN_VALUE:
				return "brown"
			if word == "blue" and saturation < LIGHT_SATURATION and value > LIGHT_VALUE:
				return "light blue"
			return word
	return ""
