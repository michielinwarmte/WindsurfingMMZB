class_name FinSizes
extends Resource
## What a fin's depth brings with it: the area of a real slalom fin of that depth, the board width it
## suits and the wind it is for. The gear page's depth slider and the fins the catalogue makes for any
## depth (GearCatalogue.fin_of()) read it (Max, 6 November 2026: every fin brand with a slider from
## 28 to 52 cm). One file, Game/gear/fin_sizes.tres; the numbers' sources are given here and in
## Documentation/reports/fleet_gear/fin_brands.md.

## The slider's range, whole centimetres of depth.
@export var min_depth_cm: int = 28
@export var max_depth_cm: int = 52
## The area of a race fin at each whole depth from min_depth_cm to max_depth_cm, cm² (one value per
## centimetre: 25 for 28 to 52 cm). From 30 to 48 cm, every 2 cm, the published areas of Select's
## race fin, the Rhino Pro (brand_research.md section 1.4); the odd sizes between and 29 cm as the
## research's script put them (tools/blender/gear_set.py, RACE_FIN_AREA_CM2); 28 and 49 to 52 cm
## from a power law fitted to Select's ten sizes, area = 2.19 x depth^1.363 (cm², cm), which is
## within 3 cm² of each of them.
@export var area_cm2: PackedFloat64Array = PackedFloat64Array()

@export_group("The board it suits")
## The depth the board brands recommend grows in a straight line with the board's width
## (brand_research.md section 1.4): depth = recommend_depth_m + recommend_per_width x (width -
## recommend_width_m), 0.38 m for the default board's 72 cm.
@export var recommend_depth_m: float = 0.30
@export var recommend_width_m: float = 0.60
@export var recommend_per_width: float = 0.64

@export_group("The wind it is for")
## The wind range on a fin's card, knots: from wind_from_at_zero_kt - wind_from_per_cm_kt x depth
## (rounded) for wind_span_kt more: the deeper the fin, the lighter the wind (the rule of
## tools/gear/make_catalogue.py, which wrote Montag's five fins). A rule of thumb: any fin sails in
## any wind.
@export var wind_from_at_zero_kt: float = 52.0
@export var wind_from_per_cm_kt: float = 0.95
@export var wind_span_kt: float = 11.0
## The range never starts lower than this: a slalom board hardly planes below it, whatever its fin
## (it only matters from 49 cm, where the rule would say 3 or 4 kt).
@export var lightest_wind_kt: float = 6.0


## A depth kept inside the slider's range.
func clamp_depth(depth_cm: int) -> int:
	return clampi(depth_cm, min_depth_cm, max_depth_cm)


## Whether the slider has this depth.
func has_depth(depth_cm: int) -> bool:
	return depth_cm >= min_depth_cm and depth_cm <= max_depth_cm


## The race fin's area at a depth (m²): the table's value (the nearest end outside the range).
func area_m2(depth_cm: int) -> float:
	return area_cm2[clamp_depth(depth_cm) - min_depth_cm] / 10000.0


## The depth recommended for a board this wide (m), whole centimetres within the range.
func recommended_depth_cm(width_m: float) -> int:
	var depth_m: float = recommend_depth_m + recommend_per_width * (width_m - recommend_width_m)
	return clamp_depth(roundi(depth_m * 100.0))


## The board width a depth is recommended for (m): the rule above the other way round.
func board_width_m(depth_cm: int) -> float:
	return recommend_width_m + (depth_cm / 100.0 - recommend_depth_m) / recommend_per_width


## The lightest wind of a depth's range, knots.
func wind_from_kt(depth_cm: int) -> float:
	return maxf(_rule_start_kt(depth_cm), lightest_wind_kt)


## The strongest wind of a depth's range, knots.
func wind_to_kt(depth_cm: int) -> float:
	return _rule_start_kt(depth_cm) + wind_span_kt


## The depths (whole cm, smallest and biggest) whose wind range holds this wind; when none does,
## the end of the range nearest to it (the smallest fin for a gale, the biggest for a calm).
func depths_for_wind(wind_kt: float) -> Vector2i:
	var smallest: int = -1
	var biggest: int = -1
	for depth: int in range(min_depth_cm, max_depth_cm + 1):
		if wind_kt >= wind_from_kt(depth) and wind_kt <= wind_to_kt(depth):
			smallest = depth if smallest < 0 else smallest
			biggest = depth
	if smallest >= 0:
		return Vector2i(smallest, biggest)
	var nearest: int = min_depth_cm if wind_kt > wind_to_kt(min_depth_cm) else max_depth_cm
	return Vector2i(nearest, nearest)


func _rule_start_kt(depth_cm: int) -> float:
	return roundf(wind_from_at_zero_kt - wind_from_per_cm_kt * depth_cm)
