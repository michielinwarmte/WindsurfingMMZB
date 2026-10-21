class_name WindShadows
extends WindDisturbance
## The wind shadows of a fleet's sails (AI_FLEET_PLAN.md, D5, the first thing that makes a fleet
## feel real): behind every sail that is up lies a cone of slower air, half_width_m wide at the
## sail and widening at spread_deg, deficit of the wind missing close behind it (within
## full_until_m) and fading to nothing at length_m, with a smooth profile across the cone (full
## on its axis, nothing at its edge). Several shadows add up, to at most most_deficit. The numbers
## are a WindShadowConfig (Game/config/wind_shadow_default.tres), Michiel's to set.
##
## One of these per board: the race gives it to the board's wind field (WindField.disturbance)
## and, every tick before the physics, every board's place and whether its sail is up
## (set_fleet()), each board's shadows getting its own copy (a board on a worker thread reads only
## its own fields here: F1 no_wait). The board's own sail casts no shadow on itself.
##
## Positions are game metres (X east, Z south); the cone lies along the wind at the point
## (the direction the undisturbed air moves there, which on the lake varies from place to place).

## The config's numbers, copied once (copy_config()).
var _length_m: float = 30.0
var _deficit: float = 0.3
var _half_width_m: float = 2.5
var _tan_spread: float = 0.14
var _full_until_m: float = 5.0
var _most_deficit: float = 0.5
## The fleet: every board's place and whether its sail is up (1) or in the water (0), and this
## board's own number among them (-1: none).
var _x: PackedFloat32Array = PackedFloat32Array()
var _z: PackedFloat32Array = PackedFloat32Array()
var _casts: PackedByteArray = PackedByteArray()
var _own: int = -1


## The shadows with a config's numbers (the default file when none is given).
static func make(config: WindShadowConfig = null) -> WindShadows:
	var shadows: WindShadows = WindShadows.new()
	shadows.copy_config(config if config != null else load("res://config/wind_shadow_default.tres") as WindShadowConfig)
	return shadows


## Takes a config's numbers into this object's own fields (read on a thread without a lock).
func copy_config(config: WindShadowConfig) -> void:
	_length_m = maxf(config.length_m, 0.1)
	_deficit = clampf(config.deficit, 0.0, 1.0)
	_half_width_m = maxf(config.half_width_m, 0.1)
	_tan_spread = tan(deg_to_rad(clampf(config.spread_deg, 0.0, 80.0)))
	_full_until_m = clampf(config.full_until_m, 0.0, _length_m)
	_most_deficit = clampf(config.most_deficit, 0.0, 1.0)


## Where every board of the fleet is (X, Z) and whether its sail is up, and which of them this
## board is. The arrays are copied, so each board's shadows keep their own.
func set_fleet(xs: PackedFloat32Array, zs: PackedFloat32Array, casting: PackedByteArray, own: int) -> void:
	_x = xs.duplicate()
	_z = zs.duplicate()
	_casts = casting.duplicate()
	_own = own


## How many of the fleet's sails are up (for the tests and the tools).
func casting_count() -> int:
	var count: int = 0
	for i: int in _casts.size():
		if _casts[i] != 0 and i != _own:
			count += 1
	return count


## The share of the wind left at a point: 1 less the shadows of the sails upwind of it.
func factor_at(point: Vector3, undisturbed: Vector3) -> float:
	var count: int = _x.size()
	if count == 0:
		return 1.0
	var flow: Vector2 = Vector2(undisturbed.x, undisturbed.z)
	if flow.length_squared() < 1e-6:
		return 1.0
	# Downwind is the way the air moves; across is square to it.
	var downwind: Vector2 = flow.normalized()
	var across: Vector2 = Vector2(-downwind.y, downwind.x)
	var px: float = point.x
	var pz: float = point.z
	var deficit: float = 0.0
	for i: int in count:
		if i == _own or _casts[i] == 0:
			continue
		var dx: float = px - _x[i]
		var dz: float = pz - _z[i]
		var along: float = dx * downwind.x + dz * downwind.y
		if along <= 0.0 or along >= _length_m:
			continue
		var width: float = _half_width_m + along * _tan_spread
		var side: float = absf(dx * across.x + dz * across.y)
		if side >= width:
			continue
		var strength: float = 1.0
		if along > _full_until_m:
			strength = 1.0 - (along - _full_until_m) / (_length_m - _full_until_m)
		var share: float = side / width
		deficit += _deficit * strength * (1.0 - share * share)
	return 1.0 - minf(deficit, _most_deficit)
