class_name SailingArea
extends RefCounted
## Where the fleet sails when it is not racing (AI_FLEET_PLAN.md, D4 and F2): the water round a
## course's start line, where the AI boards appear, sail free before the countdown and come back
## to after the finish. A rectangle set square to the course's wind (its axis): across the wind
## either side of the line, and up and down the wind from it.
##
## It is sized for the menu's race, whose 60 s countdown starts as the boards appear: from every
## spot in it a board must get to the line by the gun. A board makes 5 to 9 m/s on a reach but
## only 3 to 4 m/s toward the wind (and a run down the wind is no faster), so the area reaches
## far across the wind and little up and down it. Above the line (the course side of an upwind
## start) is the dearest: a board there must run down behind the line and beat back up to it. So
## the area is around the start line, not round the whole course: T1's mark 1 is 556 m upwind,
## ten minutes' sailing from the line. Sizes in metres, from the line's ends:
##   ACROSS_M across the wind beyond each end of the line (a reach: fast);
##   DOWNWIND_M down the wind of the line (a beat back up);
##   UPWIND_M up the wind of it (a run down and a beat back).
## On a lake the area is then made smaller where the shore is near (_fitted_to_water()), so that every
## part of it keeps SHORE_ROOM_M of water to the shore.
##
## Positions are game metres, Vector2(X east, Z south), as in Course; bearings compass degrees.

const ACROSS_M: float = 150.0
const DOWNWIND_M: float = 100.0
const UPWIND_M: float = 50.0
## On a lake every part of the area keeps at least this much water to the shore, metres: the AI
## boards are not stopped by the shallows the way the player's board is.
const SHORE_ROOM_M: float = 80.0
## The shore is looked for on a grid this fine over the area, metres, and a side too near it is
## moved in this much at a time.
const SHORE_CHECK_STEP_M: float = 20.0
const SHORE_SHRINK_STEP_M: float = 10.0
## A board appears at least this far from every other board, metres (fewer if the area is too
## small for that many boards).
const SPAWN_APART_M: float = 30.0
## How many random spots are tried for each board before the boards may be closer.
const SPAWN_TRIES: int = 200

## The middle of the rectangle, and the two directions it is set along (one metre long each):
## across the wind (to the right looking upwind) and up the wind (toward where it comes from).
var centre: Vector2 = Vector2.ZERO
var across_dir: Vector2 = Vector2.RIGHT
var upwind_dir: Vector2 = Vector2.UP
## Half its size across the wind and up the wind, metres.
var half_across_m: float = 0.0
var half_up_m: float = 0.0
## The wind it is set to, where it comes from, degrees (the course's axis).
var wind_from_deg: float = 0.0


## The area round a course's start line, fitted to the water of a map's shore grid (null on the open
## water). The shore's clearance is CourseFitter's (a fifth of a second to build on Silvaplana).
static func for_course(course: Course, shore: TerrainGrid = null) -> SailingArea:
	if shore == null:
		return around_start(course)
	var fitter: CourseFitter = CourseFitter.from_heights(shore.height_at, course.start_middle())
	if not fitter.has_water():
		return around_start(course)
	return around_start(course, fitter.clearance_m)


## The area round a course's start line, set to the course's axis. With a clearance (a Callable
## taking a game point and giving the metres of water to the shore there, as
## CourseFitter.clearance_m does) it is then fitted to the water.
static func around_start(course: Course, clearance: Callable = Callable()) -> SailingArea:
	var area: SailingArea = SailingArea.new()
	area.wind_from_deg = course.axis_deg
	area.upwind_dir = Course.direction_of(course.axis_deg)
	area.across_dir = Course.direction_of(course.axis_deg + 90.0)
	var middle: Vector2 = course.start_middle()
	# The line's ends in the wind's frame, from its middle.
	var ends: Array[Vector2] = []
	for id: String in [CourseMark.START_BOAT, CourseMark.START_PIN]:
		var offset: Vector2 = course.mark(id).position - middle
		ends.append(Vector2(offset.dot(area.across_dir), offset.dot(area.upwind_dir)))
	# The sides: left and right across the wind, down and up the wind, from the line's middle.
	var line: PackedFloat32Array = PackedFloat32Array([minf(ends[0].x, ends[1].x), maxf(ends[0].x, ends[1].x),
		minf(ends[0].y, ends[1].y), maxf(ends[0].y, ends[1].y)])
	var sides: PackedFloat32Array = PackedFloat32Array([line[0] - ACROSS_M, line[1] + ACROSS_M, line[2] - DOWNWIND_M, line[3] + UPWIND_M])
	if clearance.is_valid():
		sides = area._fitted_to_water(clearance, middle, sides, line)
	area._set_sides(middle, sides[0], sides[1], sides[2], sides[3])
	return area


## The sides (left, right, down, up, metres from the start line's middle in the wind's frame)
## moved in until every point of the area, looked at every SHORE_CHECK_STEP_M, keeps SHORE_ROOM_M
## of water to the shore; never so far that the start line (its own sides, `line`) is left out.
func _fitted_to_water(clearance: Callable, middle: Vector2, sides: PackedFloat32Array, line: PackedFloat32Array) -> PackedFloat32Array:
	var left: float = sides[0]
	var right: float = sides[1]
	var down: float = sides[2]
	var up: float = sides[3]
	var line_left: float = line[0]
	var line_right: float = line[1]
	var line_down: float = line[2]
	var line_up: float = line[3]
	for _try: int in 200:
		# The point nearest the shore of those with less than the room, on a grid from side to side.
		var worst: Vector2 = Vector2.INF
		var worst_m: float = SHORE_ROOM_M
		var columns: int = ceili((right - left) / SHORE_CHECK_STEP_M) + 1
		var rows: int = ceili((up - down) / SHORE_CHECK_STEP_M) + 1
		for i: int in columns:
			var x: float = lerpf(left, right, float(i) / maxf(columns - 1, 1))
			for j: int in rows:
				var y: float = lerpf(down, up, float(j) / maxf(rows - 1, 1))
				var room_m: float = clearance.call(middle + across_dir * x + upwind_dir * y)
				if room_m < worst_m:
					worst_m = room_m
					worst = Vector2(x, y)
		if worst == Vector2.INF:
			break
		# The side nearest the point too near the shore moves in (a side that has reached the start
		# line stays).
		var gaps: Array[float] = [worst.x - left, right - worst.x, worst.y - down, up - worst.y]
		var room: Array[bool] = [left + SHORE_SHRINK_STEP_M <= line_left, right - SHORE_SHRINK_STEP_M >= line_right,
			down + SHORE_SHRINK_STEP_M <= line_down, up - SHORE_SHRINK_STEP_M >= line_up]
		var side: int = -1
		for i: int in 4:
			if room[i] and (side < 0 or gaps[i] < gaps[side]):
				side = i
		if side < 0:
			push_warning("The sailing area cannot keep %.0f m from the shore round this start line." % SHORE_ROOM_M)
			break
		match side:
			0:
				left += SHORE_SHRINK_STEP_M
			1:
				right -= SHORE_SHRINK_STEP_M
			2:
				down += SHORE_SHRINK_STEP_M
			3:
				up -= SHORE_SHRINK_STEP_M
	return PackedFloat32Array([left, right, down, up])


func _set_sides(middle: Vector2, left: float, right: float, down: float, up: float) -> void:
	half_across_m = (right - left) / 2.0
	half_up_m = (up - down) / 2.0
	centre = middle + across_dir * (left + right) / 2.0 + upwind_dir * (down + up) / 2.0


## A point in the area's own frame: metres across the wind and up the wind from its middle.
func local(point: Vector2) -> Vector2:
	var offset: Vector2 = point - centre
	return Vector2(offset.dot(across_dir), offset.dot(upwind_dir))


## The game point of a point in the area's frame.
func point_at(across_m: float, up_m: float) -> Vector2:
	return centre + across_dir * across_m + upwind_dir * up_m


## How far inside the area a point is, metres: the distance to the nearest side, negative outside.
func inside_m(point: Vector2) -> float:
	var here: Vector2 = local(point)
	return minf(half_across_m - absf(here.x), half_up_m - absf(here.y))


func contains(point: Vector2) -> bool:
	return inside_m(point) >= 0.0


## The four corners, game points.
func corners() -> PackedVector2Array:
	return PackedVector2Array([point_at(-half_across_m, -half_up_m), point_at(half_across_m, -half_up_m),
		point_at(half_across_m, half_up_m), point_at(-half_across_m, half_up_m)])


## A random point at least `margin_m` inside the area.
func random_point(rng: RandomNumberGenerator, margin_m: float = 0.0) -> Vector2:
	var across_m: float = maxf(half_across_m - margin_m, 0.0)
	var up_m: float = maxf(half_up_m - margin_m, 0.0)
	return point_at(rng.randf_range(-across_m, across_m), rng.randf_range(-up_m, up_m))


## Spots for `count` boards to appear at, seeded (the same seed, the same spots), at least
## SPAWN_APART_M from each other and from the points in `taken` (the player's board), and 20 m
## inside the area; closer together when there is no room for that many.
func spawn_spots(count: int, random_seed: int, taken: PackedVector2Array = PackedVector2Array()) -> PackedVector2Array:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = random_seed
	var spots: PackedVector2Array = PackedVector2Array()
	var apart_m: float = SPAWN_APART_M
	while spots.size() < count:
		var found: bool = false
		for _try: int in SPAWN_TRIES:
			var spot: Vector2 = random_point(rng, 20.0)
			if _far_from(spot, spots, apart_m) and _far_from(spot, taken, apart_m):
				spots.append(spot)
				found = true
				break
		if not found:
			apart_m *= 0.8
	return spots


## Where `count` boards appear, seeded (the same seed, the same race): one place per board, as
## (x, z, heading in degrees), at spawn_spots() clear of `taken` (the player's spot; Vector2.INF for
## none), each on a reach on either tack (spawn_heading_deg()).
func spawn_places(count: int, random_seed: int, taken: Vector2 = Vector2.INF) -> Array[Vector3]:
	var others: PackedVector2Array = PackedVector2Array()
	if taken != Vector2.INF:
		others.append(taken)
	var spots: PackedVector2Array = spawn_spots(count, random_seed, others)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = random_seed + 1
	var places: Array[Vector3] = []
	for spot: Vector2 in spots:
		places.append(Vector3(spot.x, spot.y, spawn_heading_deg(rng)))
	return places


## A heading for a board appearing in the area, seeded: a reach (70 to 110 degrees off the wind)
## on either tack, so that it gets going at once.
func spawn_heading_deg(rng: RandomNumberGenerator) -> float:
	var tack: float = 1.0 if rng.randf() < 0.5 else -1.0
	return fposmod(wind_from_deg - tack * rng.randf_range(70.0, 110.0), 360.0)


static func _far_from(spot: Vector2, others: PackedVector2Array, apart_m: float) -> bool:
	for other: Vector2 in others:
		if spot.distance_to(other) < apart_m:
			return false
	return true
