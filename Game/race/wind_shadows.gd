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
##
## From 13 November 2026 (Max: "implement it like real life"): with follows_apparent_wind and a trail given
## (set_trail(), from the race's WindShadowTrail) the shadow lies along each sail's trail of disturbed air instead:
## along its apparent wind, swinging back as the board speeds up, bending through its gybes. The same strength and
## widths, by how far down the wake a point is. Without a trail (the tests, an old caller) the cone as before.

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
## The shadow along the sails' trails (follows_apparent_wind), and the trails' points: four numbers each (the board's
## index, X, Z, metres down its wake), each board's together from its sail to its oldest puff (WindShadowTrail.points()).
var _follows_apparent_wind: bool = true
var _trail: PackedFloat32Array = PackedFloat32Array()
var _has_trail: bool = false


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
	_follows_apparent_wind = config.follows_apparent_wind


## Every sail's trail of disturbed air (WindShadowTrail.points(), copied) and which board this is: from now on the
## shadows lie along the trails (when the config follows the apparent wind).
func set_trail(points: PackedFloat32Array, own: int) -> void:
	_trail = points.duplicate()
	_own = own
	_has_trail = true


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
	if _follows_apparent_wind and _has_trail:
		return _trail_factor_at(point.x, point.z)
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


## The share of the wind left at a point along the trails: each other board's shadow from the stretch of its trail
## nearest the point (_trail_deficit()), the boards' shadows added up to at most most_deficit.
func _trail_factor_at(px: float, pz: float) -> float:
	var count: int = _trail.size() / 4
	var reach_m: float = _length_m + _half_width_m + _length_m * _tan_spread
	var deficit: float = 0.0
	var first: int = 0
	while first < count:
		var board: int = int(_trail[first * 4])
		var end: int = first + 1
		while end < count and int(_trail[end * 4]) == board:
			end += 1
		# A board's trail is never further from its newest point than its length (a quick look before the stretches).
		var near: bool = Vector2(px - _trail[first * 4 + 1], pz - _trail[first * 4 + 2]).length() <= reach_m
		if board != _own and end - first >= 2 and near:
			deficit += _trail_deficit(px, pz, first, end)
		first = end
	return 1.0 - minf(deficit, _most_deficit)


## One board's shadow at a point: over the stretches between its trail's points (first to end - 1), the strongest. On a
## stretch the point's nearest place on it says how far down the wake it is (between the two points') and how far to
## the side; the strength and the width by that distance, as the cone's (full within full_until_m, fading to nothing at
## length_m; half_width_m wide at the sail, widening at spread_deg; full on the trail, nothing at its edge). Nothing
## beside or ahead of the sail itself (the first stretch from it counts only behind it), nor beyond the last puff.
func _trail_deficit(px: float, pz: float, first: int, end: int) -> float:
	var strongest: float = 0.0
	var point: Vector2 = Vector2(px, pz)
	for k: int in range(first, end - 1):
		var a: Vector2 = Vector2(_trail[k * 4 + 1], _trail[k * 4 + 2])
		var b: Vector2 = Vector2(_trail[k * 4 + 5], _trail[k * 4 + 6])
		var ab: Vector2 = b - a
		var length_sq: float = ab.length_squared()
		var t: float = (point - a).dot(ab) / length_sq if length_sq > 1e-6 else 0.0
		if (k == first and t <= 0.0) or (k == end - 2 and t >= 1.0):
			continue
		t = clampf(t, 0.0, 1.0)
		var along: float = lerpf(_trail[k * 4 + 3], _trail[k * 4 + 7], t)
		if along >= _length_m:
			continue
		var width: float = _half_width_m + along * _tan_spread
		var side: float = point.distance_to(a + ab * t)
		if side >= width:
			continue
		var strength: float = 1.0
		if along > _full_until_m:
			strength = 1.0 - (along - _full_until_m) / (_length_m - _full_until_m)
		var share: float = side / width
		strongest = maxf(strongest, _deficit * strength * (1.0 - share * share))
	return strongest


## The share of the wind left at a point (X, Z) from sails at other places than the fleet's now, all up, the air moving
## along `downwind` (a skipper's guess where the boards coming in will be: Skipper.clean_gap_m()). The same cone as
## factor_at().
func factor_from(point: Vector2, downwind: Vector2, sails: PackedVector2Array) -> float:
	if downwind.length_squared() < 1e-6:
		return 1.0
	var along_dir: Vector2 = downwind.normalized()
	var across: Vector2 = Vector2(-along_dir.y, along_dir.x)
	var deficit: float = 0.0
	for sail: Vector2 in sails:
		var apart: Vector2 = point - sail
		var along: float = apart.dot(along_dir)
		if along <= 0.0 or along >= _length_m:
			continue
		var width: float = _half_width_m + along * _tan_spread
		var side: float = absf(apart.dot(across))
		if side >= width:
			continue
		var strength: float = 1.0
		if along > _full_until_m:
			strength = 1.0 - (along - _full_until_m) / (_length_m - _full_until_m)
		var share: float = side / width
		deficit += _deficit * strength * (1.0 - share * share)
	return 1.0 - minf(deficit, _most_deficit)
