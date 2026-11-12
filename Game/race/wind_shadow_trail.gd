class_name WindShadowTrail
extends RefCounted
## The dirty air every sail leaves behind, as it is on the water (Max, 12 November 2026: "the dirty wind is a
## disappointment and is straight downwind even when players are moving forward. the dirty wind moves while speeding
## up. this way slalom starts are way more fair"; "implement it like real life"). The research is in
## Documentation/reports/racing/dirty_wind_13nov/RESEARCH.md.
##
## The air a sail has disturbed stays where the sail was and drifts off with the wind. So every puff_every_s a sail that
## is up leaves a puff of disturbed air where it is, and the puff drifts on with the wind it was left in. Seen from the
## moving board the puffs then lie along its APPARENT wind, not the true wind (Richards et al. 2012, a wind tunnel
## test of two sailing yachts: "the blanketing zone should be aligned with the apparent wind rather than the true
## wind"): a board waiting at a crawl casts its shadow straight downwind; once it is going fast on a reach the shadow
## swings back behind it, to leeward of its wake; through a gybe the trail bends; a board that falls leaves its last
## puffs drifting off. The same wind tunnel test measured the wake bent a little further toward the stern of the board
## that casts it (5 degrees upwind, 9 on a reach): stern_bend_deg.
##
## A puff's distance down the wake (how far the air has moved past the sail since, at the apparent wind speed it was
## left in) sets how strong and wide the shadow is there, as the cone of WindShadows did: the same length_m, deficit
## and widths, so the shadow keeps its length in metres (a wake's decay goes with the distance behind the sail, not its
## speed: Roncin and Kobus 2004) and a fast board's lasts fewer seconds. A puff is forgotten once it is length_m down.
##
## One of these per race, on the main thread: update() every tick before the physics, then points() into every board's
## WindShadows (set_trail(); each its own copy: the boards' physics read only their own fields, F1 no_wait).

## The board's apparent wind is taken as at least this, m/s, so a board running at the wind's own speed (its puffs
## staying with it) still forgets them.
const LEAST_APPARENT_MS: float = 2.0
## A board that moved further than this in one tick was put somewhere else (the game's R, a drop): its trail starts
## afresh, or its sail would be joined to its old puffs across the course. Metres (a board at 20 m/s moves 0.33 m a tick).
const JUMP_M: float = 10.0

## The config's numbers (copy_config()).
var _length_m: float = 30.0
var _puff_every_s: float = 0.25
var _bend_rad: float = 0.0
## The trail's own clock, and the time since the last puffs were left.
var _now_s: float = 0.0
var _since_puff_s: float = 0.0
## Per board (by its index in the race): its puffs, the oldest first: when each was left, where, the way it drifts
## (m/s, X and Z) and the apparent wind speed it was left in (m/s).
var _born_s: Array[PackedFloat32Array] = []
var _born_at: Array[PackedVector2Array] = []
var _drift: Array[PackedVector2Array] = []
var _apparent_ms: Array[PackedFloat32Array] = []
## Per board: where its sail is now, and whether it is up (1) or in the water (0).
var _now_at: PackedVector2Array = PackedVector2Array()
var _casting: PackedByteArray = PackedByteArray()


## A trail with a config's numbers (the default file when none is given).
static func make(config: WindShadowConfig = null) -> WindShadowTrail:
	var trail: WindShadowTrail = WindShadowTrail.new()
	trail.copy_config(config if config != null else load("res://config/wind_shadow_default.tres") as WindShadowConfig)
	return trail


func copy_config(config: WindShadowConfig) -> void:
	_length_m = maxf(config.length_m, 0.1)
	_puff_every_s = maxf(config.puff_every_s, 0.02)
	_bend_rad = deg_to_rad(clampf(config.stern_bend_deg, 0.0, 45.0))


## One tick: every board's place now, and every PUFF_EVERY_S a puff from each sail that is up (sims: the boards in the
## race's order, null for a board that is not there; casting: 1 for a sail that is up). A fleet of another size starts
## its trails afresh.
func update(dt_s: float, sims: Array[WindsurferSim], casting: PackedByteArray) -> void:
	var boards: Array[Dictionary] = []
	for sim: WindsurferSim in sims:
		if sim == null:
			boards.append({})
			continue
		var telemetry: Telemetry = sim.telemetry
		boards.append({"at": Vector2(telemetry.position.x, telemetry.position.z), "velocity": Vector2(sim.body.velocity.x, sim.body.velocity.z),
			"wind_from_deg": telemetry.wind_from_bearing_deg, "wind_ms": telemetry.tws_at_sail_kt * SimMath.KNOT_MS,
			"heading_deg": telemetry.heading_deg})
	update_boards(dt_s, boards, casting)


## update() from plain numbers (the tests): per board {"at": Vector2, "velocity": Vector2 (m/s, X and Z),
## "wind_from_deg", "wind_ms" (the true wind at its sail), "heading_deg"}, or {} for a board that is not there.
func update_boards(dt_s: float, boards: Array[Dictionary], casting: PackedByteArray) -> void:
	if boards.size() != _born_s.size():
		_start_afresh(boards.size())
	_now_s += dt_s
	_since_puff_s += dt_s
	var leave_puffs: bool = _since_puff_s >= _puff_every_s
	if leave_puffs:
		_since_puff_s = 0.0
	for i: int in boards.size():
		var board: Dictionary = boards[i]
		var up: bool = not board.is_empty() and i < casting.size() and casting[i] != 0
		_casting[i] = 1 if up else 0
		if board.is_empty():
			_now_at[i] = Vector2.INF
			continue
		var here: Vector2 = board["at"]
		if _now_at[i] != Vector2.INF and here.distance_to(_now_at[i]) > JUMP_M:
			_forget_all(i)
		_now_at[i] = here
		if leave_puffs and up:
			_leave_puff(i, board)
		_forget_old(i)


## Every board's trail as one flat list for WindShadows.set_trail(): four numbers a point (the board's index, X, Z, and
## how far down the wake the point is, metres), each board's points together, from its sail now (when it is up, at 0 m)
## to its oldest puff.
func points() -> PackedFloat32Array:
	var out: PackedFloat32Array = PackedFloat32Array()
	for i: int in _born_s.size():
		if _casting[i] != 0 and _now_at[i] != Vector2.INF:
			out.append_array(PackedFloat32Array([float(i), _now_at[i].x, _now_at[i].y, 0.0]))
		for k: int in range(_born_s[i].size() - 1, -1, -1):
			var age_s: float = _now_s - _born_s[i][k]
			var at: Vector2 = _born_at[i][k] + _drift[i][k] * age_s
			out.append_array(PackedFloat32Array([float(i), at.x, at.y, _apparent_ms[i][k] * age_s]))
	return out


## How many puffs a board has left behind now (for the tests and the tools).
func puff_count(index: int) -> int:
	return _born_s[index].size() if index < _born_s.size() else 0


func _start_afresh(count: int) -> void:
	_born_s.clear()
	_born_at.clear()
	_drift.clear()
	_apparent_ms.clear()
	for i: int in count:
		_born_s.append(PackedFloat32Array())
		_born_at.append(PackedVector2Array())
		_drift.append(PackedVector2Array())
		_apparent_ms.append(PackedFloat32Array())
	_now_at.resize(count)
	_now_at.fill(Vector2.INF)
	_casting.resize(count)
	_casting.fill(0)


func _forget_all(i: int) -> void:
	_born_s[i].clear()
	_born_at[i].clear()
	_drift[i].clear()
	_apparent_ms[i].clear()


## A puff left where the board is now. It drifts with the wind it was left in (the true wind at the sail), turned by up
## to stern_bend_deg toward the board's stern as seen from the board (drift = the board's velocity plus its apparent
## wind turned toward the stern; unturned, that is the true wind itself).
func _leave_puff(i: int, board: Dictionary) -> void:
	var velocity: Vector2 = board["velocity"]
	var wind: Vector2 = Course.direction_of(float(board["wind_from_deg"]) + 180.0) * float(board["wind_ms"])
	var apparent: Vector2 = wind - velocity
	var drift: Vector2 = wind
	if _bend_rad > 0.0 and apparent.length() > LEAST_APPARENT_MS:
		var stern: Vector2 = -Course.direction_of(float(board["heading_deg"]))
		drift = velocity + apparent.rotated(clampf(apparent.angle_to(stern), -_bend_rad, _bend_rad))
	_born_s[i].append(_now_s)
	_born_at[i].append(board["at"])
	_drift[i].append(drift)
	_apparent_ms[i].append(maxf(apparent.length(), LEAST_APPARENT_MS))


## The board's oldest puffs forgotten once they are length_m down the wake.
func _forget_old(i: int) -> void:
	while _born_s[i].size() > 0 and _apparent_ms[i][0] * (_now_s - _born_s[i][0]) >= _length_m:
		_born_s[i].remove_at(0)
		_born_at[i].remove_at(0)
		_drift[i].remove_at(0)
		_apparent_ms[i].remove_at(0)
