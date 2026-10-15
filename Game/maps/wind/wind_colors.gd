class_name WindColors
extends RefCounted
## The wind viewer's colours for wind speed (MAP_SILVAPLANA_PLAN.md, W2): the water's colour and
## the legend come from here, so they always match.
##
## Windfinder's scale, as Max asked (the colours read from a screenshot of Windfinder's legend,
## 15 October 2026): purple for calm, blue, cyan and green up to 23 knots, yellow at 27, then brown,
## red and pink up to 53. Between two stops the colour changes evenly.

## The knots of the stops, and their colours.
const STOP_KNOTS: PackedFloat32Array = [0.0, 3.0, 7.0, 11.0, 15.0, 19.0, 23.0, 27.0, 31.0, 35.0, 39.0, 43.0, 47.0, 51.0, 53.0]
const STOP_COLORS: PackedColorArray = [
	Color("#793ea3"), Color("#663ea3"), Color("#3d51a3"), Color("#3e7aa3"), Color("#3d999b"),
	Color("#449344"), Color("#41a13d"), Color("#a3a33d"), Color("#a38d3e"), Color("#a3793d"),
	Color("#99653e"), Color("#8d5049"), Color("#823e4b"), Color("#8e3e66"), Color("#a23d78"),
]
## The top of the scale: 53 knots and more get the last colour.
const MAX_KNOTS: float = 53.0


## The colour scale, from 0 (no wind) to 1 (MAX_KNOTS).
static func gradient() -> Gradient:
	var scale: Gradient = Gradient.new()
	var offsets: PackedFloat32Array = PackedFloat32Array()
	for knots: float in STOP_KNOTS:
		offsets.append(knots / MAX_KNOTS)
	scale.offsets = offsets
	scale.colors = STOP_COLORS
	return scale


## The colour of a wind speed in knots.
static func color_for(knots: float) -> Color:
	return gradient().sample(clampf(knots / MAX_KNOTS, 0.0, 1.0))


## The scale as a texture for wind_speed_water.gdshader: 0 knots on the left, MAX_KNOTS on the right.
static func texture() -> GradientTexture1D:
	var scale_texture: GradientTexture1D = GradientTexture1D.new()
	scale_texture.gradient = gradient()
	scale_texture.width = 1024
	return scale_texture
