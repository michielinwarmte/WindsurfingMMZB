class_name SkipperPolar
extends Resource
## What a scripted skipper knows of its board (Skipper): how fast it sails at each true wind angle
## in 12, 18 and 24 kt, and where on the push slider (PlayerController.push_level, 0 to 1) a good
## sailor sets it there, and the best angles to beat and to run at in each wind. The skipper times its
## legs and its start with the speeds, sets the push from the second table every tick (AiHands.push),
## and sails the best angles (the most way toward or away from the wind, VMG).
##
## Measured with the very board an AI sails: the beginner controller with the auto-sheet, the AI
## hands holding the wind angle, the default board, sail and fin, on the race's open water (its waves,
## a steady wind as the headless race and the game's default settings have it), 150 s per case from a
## beam reach, the means from 40 s (tools/push_check.sh; Documentation/reports/fleet_speed/
## skipper_speed.md has the commands and the whole table). One row of twa_deg's angles per wind.
## Edit the numbers in Game/config/skipper_polar.tres.

## The winds the rows were measured in, knots, rising. Between two rows the numbers are straight
## between them; below the first and above the last, the first and the last row.
@export var winds_kt: PackedFloat32Array = []
## The true wind angles of the columns, degrees off the wind, rising.
@export var twa_deg: PackedFloat32Array = []
## The settled speed through the water at each angle, m/s, one row per wind.
@export var speed_ms: PackedFloat32Array = []
## The push slider's level at each angle, 0 to 1, one row per wind, where pushing paid in the
## measurement without a fall (Michiel's ladder: 75 % planing with little risk, 85 % more speed and a
## little risk, 95 % very fast, 100 % the most speed with a crash likely); 0 where it did not: there
## the board sails the pilot's own margin, without the slider (see push_at()).
@export var push_level: PackedFloat32Array = []
## The best wind angle to beat at, degrees, one per wind: where the board made the most way toward
## the wind (its VMG, measured over the ground, so with the leeway, which is large when it pinches
## in light wind).
@export var best_upwind_twa_deg: PackedFloat32Array = []
## The best wind angle to run at, degrees, one per wind. In 12 kt the most way away from the wind
## measured (129). In 18 and 24 kt the angles that raced fastest (130 and 140): the steady runs' best
## (120 and 130, 9 and 19 % more way away from the wind) raced 1 to 10 s slower on every run leg of
## T1 and T2, because a run leg starts from a rounding and has its gybes, which a steady run has not
## (skipper_speed.md, section 3).
@export var best_downwind_twa_deg: PackedFloat32Array = []

const DEFAULT_PATH: String = "res://config/skipper_polar.tres"


## The game's polar.
static func default_polar() -> SkipperPolar:
	return load(DEFAULT_PATH) as SkipperPolar


## A value from one of the tables (speed_ms or push_level) at a wind (knots) and a wind angle
## (degrees, either tack), straight between the measured winds and angles. Static, on arrays the
## caller owns: a skipper keeps its own copies, because skippers sailed side by side on threads
## slowed each other down reading shared data (CLAUDE.md, the engine lock).
static func value_at(winds: PackedFloat32Array, angles: PackedFloat32Array, table: PackedFloat32Array, wind_kt: float, twa: float) -> float:
	var rows: int = winds.size()
	if rows == 0 or angles.is_empty() or table.size() < rows * angles.size():
		return 0.0
	if rows == 1:
		return _row_value(angles, table, 0, twa)
	var kt: float = clampf(wind_kt, winds[0], winds[rows - 1])
	var row: int = 0
	while row < rows - 2 and kt > winds[row + 1]:
		row += 1
	var share: float = (kt - winds[row]) / (winds[row + 1] - winds[row])
	return lerpf(_row_value(angles, table, row, twa), _row_value(angles, table, row + 1, twa), share)


## The value in one wind's row at a wind angle, straight between the table's angles (held at the
## first and the last angle beyond them).
static func _row_value(angles: PackedFloat32Array, table: PackedFloat32Array, row: int, twa: float) -> float:
	var count: int = angles.size()
	var base: int = row * count
	var angle: float = clampf(absf(twa), angles[0], angles[count - 1])
	for i: int in range(1, count):
		if angle <= angles[i]:
			var share: float = (angle - angles[i - 1]) / (angles[i] - angles[i - 1])
			return lerpf(table[base + i - 1], table[base + i], share)
	return table[base + count - 1]


## The push slider's level (push_level) at a wind (knots) and a wind angle (degrees, either tack),
## straight between the measured ones; NAN where the table says 0 at any measured point around it
## (the angles and winds on either side, those that count at all): there the board sails the
## pilot's own margin without the slider. So a board pushes only where the measurement says pushing
## paid on both sides of its angle and wind.
static func push_at(winds: PackedFloat32Array, angles: PackedFloat32Array, table: PackedFloat32Array, wind_kt: float, twa: float) -> float:
	var rows: int = winds.size()
	var count: int = angles.size()
	if rows == 0 or count == 0 or table.size() < rows * count:
		return NAN
	var used_rows: Array[int] = [0]
	if rows > 1:
		var kt: float = clampf(wind_kt, winds[0], winds[rows - 1])
		var row: int = 0
		while row < rows - 2 and kt > winds[row + 1]:
			row += 1
		var share: float = (kt - winds[row]) / (winds[row + 1] - winds[row])
		used_rows = _used(row, share)
	var angle: float = clampf(absf(twa), angles[0], angles[count - 1])
	var column: int = 0
	while column < count - 2 and angle > angles[column + 1]:
		column += 1
	var used_columns: Array[int] = [0]
	if count > 1:
		used_columns = _used(column, (angle - angles[column]) / (angles[column + 1] - angles[column]))
	for row: int in used_rows:
		for col: int in used_columns:
			if table[row * count + col] <= 0.0:
				return NAN
	return value_at(winds, angles, table, wind_kt, twa)


## Of a cell and the next, the ones a share between them (0 at the cell, 1 at the next) leans on.
static func _used(index: int, share: float) -> Array[int]:
	var used: Array[int] = []
	if share < 1.0:
		used.append(index)
	if share > 0.0:
		used.append(index + 1)
	return used


## A per-wind number (best_upwind_twa_deg, best_downwind_twa_deg) at a wind, knots: straight between
## the measured winds, held beyond them.
static func per_wind(winds: PackedFloat32Array, table: PackedFloat32Array, wind_kt: float) -> float:
	var rows: int = mini(winds.size(), table.size())
	if rows == 0:
		return 0.0
	var kt: float = clampf(wind_kt, winds[0], winds[rows - 1])
	for i: int in range(1, rows):
		if kt <= winds[i]:
			return lerpf(table[i - 1], table[i], (kt - winds[i - 1]) / (winds[i] - winds[i - 1]))
	return table[rows - 1]
