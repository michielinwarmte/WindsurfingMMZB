class_name Brand
extends Resource
## A gear brand of the game: its name, a line in its own voice, what it makes, its colours and its
## logos (Documentation/reports/fleet_gear/brands.md). The brands are the game's own, made up after
## the sport's real makers; no real maker's name appears in the game's files (copyright).
##
## The colours dress the gear: primary is the sail's main cloth and the board's deck, secondary the
## sail's second panels and the board's rails and stripes, accent the small highlights (the luff
## sleeve's tip, the batten ends, the fin). The wordmark is printed on the sail's panels and the
## board's deck in the ink that reads on the primary colour; the mark goes on the gear page's cards.
##
## One .tres per brand in Game/gear/brands/; Brand.all() lists them. The logos are drawn by
## tools/brands/make_logos.py (SVG and PNG in Game/assets/brands/<slug>/).

## The twelve brands, in the order the gear page lists them.
const PATHS: PackedStringArray = [
	"res://gear/brands/tripletone.tres",
	"res://gear/brands/savanna.tres",
	"res://gear/brands/point9.tres",
	"res://gear/brands/moonboard.tres",
	"res://gear/brands/nielstrots.tres",
	"res://gear/brands/pj_new_sealand.tres",
	"res://gear/brands/bmx_boards.tres",
	"res://gear/brands/southsails.tres",
	"res://gear/brands/s3kauai.tres",
	"res://gear/brands/forbidden.tres",
	"res://gear/brands/gg_sails.tres",
	"res://gear/brands/montag.tres",
]

## The brand's name as the game shows it: "Point.9".
@export var name: String = ""
## The folder and file name: "point9" (Game/assets/brands/point9/, Game/gear/brands/point9.tres).
@export var slug: String = ""
## One short line in the brand's voice, for the gear page.
@export var tagline: String = ""
@export var makes_boards: bool = false
@export var makes_sails: bool = false
## The fins' brand (Montag): none of the board and sail brands makes fins.
@export var makes_fins: bool = false

@export_group("Colours")
## The sail's main cloth and the board's deck.
@export var primary: Color = Color.WHITE
## The sail's second panels, the board's rails and stripes.
@export var secondary: Color = Color.BLACK
## The small highlights: the luff sleeve's tip, the batten ends, the fin.
@export var accent: Color = Color.RED

@export_group("Logos")
## The mark above the wordmark on a rounded plate in the primary colour (square).
@export var logo: Texture2D
## The name, wide, for the sail's and the board's print (its ink reads on the primary colour).
@export var wordmark: Texture2D
## The symbol alone, for the gear page's cards.
@export var mark: Texture2D


## Every brand, in the gear page's order.
static func all() -> Array[Brand]:
	var brands: Array[Brand] = []
	for path: String in PATHS:
		brands.append(load(path) as Brand)
	return brands


## The brand with this slug ("savanna"), or null when there is none.
static func find(wanted_slug: String) -> Brand:
	for brand: Brand in all():
		if brand.slug == wanted_slug:
			return brand
	return null
