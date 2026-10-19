class_name CourseFitter
extends RefCounted
## Fits a race course to a lake's water (RACING_PLAN.md, T2 "Placed to fit the water"). Max, 19
## October 2026: "The automatic course maker would place the courses in land. Make it auto adjust
## to water and space from the edge of the water minimal 200 m." A course is made smaller, turned
## and moved until every mark is at least mark_margin_m from the shore and every leg keeps
## leg_margin_m of water on both sides.
##
## Two parts:
## - The shore clearance: on a grid of points STEP_M apart over the lake, how far each is from the
##   nearest land. Built once from the map's heights (from_heights(), a fifth of a second on
##   Silvaplana, so it is not stored in a file), then clearance_m() answers for any point,
##   interpolated between the grid points. It is 3 to 11 m less than the true distance (the land
##   checked every metre round 53 spots of the lake): never more.
## - The fit (fit_template(), fit_course()): the sizes from the course's own (a template's is the
##   class's distances, 100 %) down to min_size_percent; at each size the wind's axis first, then up
##   to axis_tolerance_deg either side of it; at each, every spot on the lake. The first size where
##   something fits wins, so it is the largest course that fits; at that size the try closest to the
##   wind wins, and of those the one nearest the preferred spot.
##
## The same inputs always give the same course: every search runs in a fixed order.

## The distance between the clearance grid's points, metres.
const STEP_M: float = 10.0
## How far from the spot it starts at the lake is looked for, each way, metres. Silvaplana's shore
## grid is 5 km across; water further away than this is taken as land.
const REACH_M: float = 6000.0
## How finely a leg is checked: as the course maker's land warning does (Course.LAND_CHECK_STEP_M).
const LEG_STEP_M: float = Course.LAND_CHECK_STEP_M

## Every mark (the buoys and the ends of the start and finish lines) at least this far from land.
var mark_margin_m: float = 200.0
## Every point along every leg at least this far from land.
var leg_margin_m: float = 50.0
## The course is never made smaller than this, percent of the class's distances (Course.set_size).
var min_size_percent: float = 40.0
var size_step_percent: float = 10.0
## How far the course's axis may be turned from the wind, and in which steps, degrees.
var axis_tolerance_deg: float = 15.0
var axis_step_deg: float = 5.0
## The spots tried for the course's middle (the middle of the box round its marks): a coarse grid
## over the whole lake, then a fine grid where the coarse one looks promising, metres.
var coarse_step_m: float = 100.0
var fine_step_m: float = 25.0

## After a fit that found nothing: why, in a sentence for the course maker's panel.
var last_reason: String = ""
## How many spots the last fit tried, and how long it took (milliseconds).
var last_tries: int = 0
var last_fit_ms: float = 0.0
## How long building the clearance grid took, milliseconds.
var build_ms: float = 0.0

## The clearance grid: columns west to east, rows north to south, the first point (the north-west
## corner) at game X = x0_m, Z = z0_m. The points lie on whole multiples of STEP_M, so the grid is
## the same whichever lake spot it was started from.
var columns: int = 0
var rows: int = 0
var x0_m: float = 0.0
var z0_m: float = 0.0

## One value per grid point, row by row from the north: metres to the nearest land, 0 on land.
var _clearance: PackedFloat32Array = PackedFloat32Array()
## One byte per grid point: 1 for the lake, 0 for land.
var _lake: PackedByteArray = PackedByteArray()
## Tries in the last fit where every mark had its room but a leg came too close to the shore.
var _legs_too_close: int = 0


## One way of laying a course down: its size and axis, with the middle of the box round its marks
## at (0, 0). The marks are listed furthest from the middle first, because those are the ones that
## reach the shore; the points along the legs are LEG_STEP_M apart, the legs' ends included.
class Layout:
	var course: Course
	var mark_points: PackedVector2Array = PackedVector2Array()
	var leg_points: PackedVector2Array = PackedVector2Array()


# ---------------------------------------------------------------- the shore clearance

## The clearance grid for the lake that holds the point `inside` (game X, Z). height_at(x, z) gives
## the ground's height above the lake's surface, NAN off the map (as the course maker's land check
## and TerrainGrid.height_at()). A grid point is lake when the ground there is below the lake's
## surface and it is joined to `inside` through other lake points (as LakeArea finds the lake), so
## a pond or a low field elsewhere is land. If `inside` is not on the water there is no lake, and
## every fit says so.
static func from_heights(height_at: Callable, inside: Vector2) -> CourseFitter:
	var fitter: CourseFitter = CourseFitter.new()
	var start_us: int = Time.get_ticks_usec()
	fitter._find_lake(height_at, inside)
	fitter._measure_clearance()
	fitter.build_ms = (Time.get_ticks_usec() - start_us) / 1000.0
	return fitter


## True when the fitter found a lake to fit courses to.
func has_water() -> bool:
	return _lake.count(1) > 0


## How far a point (game X, Z) is from the nearest land, metres: 0 on land and off the grid. Between
## the grid's points it is interpolated, as TerrainGrid interpolates the heights.
func clearance_m(point: Vector2) -> float:
	var fx: float = (point.x - x0_m) / STEP_M
	var fz: float = (point.y - z0_m) / STEP_M
	if columns < 2 or rows < 2 or fx < 0.0 or fz < 0.0 or fx > columns - 1 or fz > rows - 1:
		return 0.0
	var column: int = mini(int(fx), columns - 2)
	var row: int = mini(int(fz), rows - 2)
	var tx: float = fx - column
	var tz: float = fz - row
	var i: int = row * columns + column
	var north: float = lerpf(_clearance[i], _clearance[i + 1], tx)
	var south: float = lerpf(_clearance[i + columns], _clearance[i + columns + 1], tx)
	return lerpf(north, south, tz)


## Whether the grid point nearest to a point (game X, Z) is in this fitter's lake.
func is_lake_at(point: Vector2) -> bool:
	var column: int = roundi((point.x - x0_m) / STEP_M)
	var row: int = roundi((point.y - z0_m) / STEP_M)
	if column < 0 or row < 0 or column >= columns or row >= rows:
		return false
	return _lake[row * columns + column] == 1


## The most open water on the lake: the largest clearance, metres.
func most_open_m() -> float:
	var most: float = 0.0
	for value: float in _clearance:
		most = maxf(most, value)
	return most


## The smallest clearance of a course's marks, metres.
func smallest_mark_clearance_m(course: Course) -> float:
	var smallest: float = INF
	for mark: CourseMark in course.marks:
		smallest = minf(smallest, clearance_m(mark.position))
	return smallest


## The smallest clearance along a course's legs, every LEG_STEP_M, metres.
func smallest_leg_clearance_m(course: Course) -> float:
	var smallest: float = INF
	for point: Vector2 in _points_along_legs(course):
		smallest = minf(smallest, clearance_m(point))
	return smallest


## The lake: a flood fill from the grid point nearest to `inside`, over a square REACH_M each way.
## Each point is asked for its height once. Then the grid is cut down to the lake's box, with one
## point of land all round.
func _find_lake(height_at: Callable, inside: Vector2) -> void:
	var reach: int = ceili(REACH_M / STEP_M)
	var side: int = 2 * reach + 1
	# The square's first point, in whole steps from the game's origin.
	var first_column: int = roundi(inside.x / STEP_M) - reach
	var first_row: int = roundi(inside.y / STEP_M) - reach
	# 0: not looked at yet, 1: lake, 2: land.
	var state: PackedByteArray = PackedByteArray()
	state.resize(side * side)
	var west: int = side
	var east: int = -1
	var north: int = side
	var south: int = -1
	# The fill starts at the grid point nearest to `inside`, if that is on the water.
	var start: int = reach * side + reach
	var to_visit: PackedInt32Array = PackedInt32Array()
	if height_at.call((first_column + reach) * STEP_M, (first_row + reach) * STEP_M) < 0.0:
		state[start] = 1
		to_visit.append(start)
	while not to_visit.is_empty():
		var index: int = to_visit[to_visit.size() - 1]
		to_visit.resize(to_visit.size() - 1)
		var column: int = index % side
		var row: int = index / side
		west = mini(west, column)
		east = maxi(east, column)
		north = mini(north, row)
		south = maxi(south, row)
		for step: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var next_column: int = column + step.x
			var next_row: int = row + step.y
			if next_column < 0 or next_row < 0 or next_column >= side or next_row >= side:
				continue
			var next: int = next_row * side + next_column
			if state[next] != 0:
				continue
			# NAN (off the map) is not below the surface, so it is land.
			var height: float = height_at.call((first_column + next_column) * STEP_M, (first_row + next_row) * STEP_M)
			state[next] = 1 if height < 0.0 else 2
			if state[next] == 1:
				to_visit.append(next)
	if east < 0:
		columns = 0
		rows = 0
		return
	# The lake's box and one point more all round, which is land (it is outside the lake's box).
	columns = east - west + 3
	rows = south - north + 3
	x0_m = (first_column + west - 1) * STEP_M
	z0_m = (first_row + north - 1) * STEP_M
	_lake.resize(columns * rows)
	for row: int in range(1, rows - 1):
		for column: int in range(1, columns - 1):
			var from: int = (north + row - 1) * side + (west + column - 1)
			_lake[row * columns + column] = 1 if state[from] == 1 else 0


## The distance from every lake point to the nearest land point, by two sweeps over the grid (the
## "8SSEDT" distance transform): each point asks its neighbours which land point is nearest to them,
## and keeps the one nearest to itself. The first sweep goes row by row from the north, each row
## west to east and back, so what is known spreads south; the second from the south, spreading
## north. Two sweeps find the nearest land point for nearly every point, to a small fraction of a
## step.
##
## The shore lies somewhere between the last lake point and the first land point, so it can be up
## to a step nearer than the land point found: the clearance is one step less than the distance,
## so it never claims more water than there is.
func _measure_clearance() -> void:
	var count: int = columns * rows
	_clearance.resize(count)
	if count == 0:
		return
	# For every point: the nearest land point found so far (its index, -1 for none yet) and the
	# distance to it in steps.
	var nearest: PackedInt32Array = PackedInt32Array()
	nearest.resize(count)
	var steps: PackedFloat32Array = PackedFloat32Array()
	steps.resize(count)
	for i: int in count:
		nearest[i] = -1 if _lake[i] == 1 else i
		steps[i] = INF if _lake[i] == 1 else 0.0
	var from_north: Array[Vector2i] = [Vector2i(-1, 0), Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1)]
	var from_east: Array[Vector2i] = [Vector2i(1, 0)]
	var from_south: Array[Vector2i] = [Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1), Vector2i(-1, 1)]
	var from_west: Array[Vector2i] = [Vector2i(-1, 0)]
	for row: int in rows:
		for column: int in columns:
			_take_nearest(column, row, from_north, nearest, steps)
		for column: int in range(columns - 1, -1, -1):
			_take_nearest(column, row, from_east, nearest, steps)
	for row: int in range(rows - 1, -1, -1):
		for column: int in range(columns - 1, -1, -1):
			_take_nearest(column, row, from_south, nearest, steps)
		for column: int in columns:
			_take_nearest(column, row, from_west, nearest, steps)
	for i: int in count:
		_clearance[i] = maxf(steps[i] - 1.0, 0.0) * STEP_M


## One point of the sweeps: if a neighbour's nearest land point is nearer to this point than its
## own, it takes that one.
func _take_nearest(column: int, row: int, neighbours: Array[Vector2i], nearest: PackedInt32Array, steps: PackedFloat32Array) -> void:
	var i: int = row * columns + column
	if _lake[i] == 0:
		return
	for offset: Vector2i in neighbours:
		var other_column: int = column + offset.x
		var other_row: int = row + offset.y
		if other_column < 0 or other_row < 0 or other_column >= columns or other_row >= rows:
			continue
		var land: int = nearest[other_row * columns + other_column]
		if land < 0:
			continue
		var distance: float = Vector2(column - land % columns, row - land / columns).length()
		if distance < steps[i]:
			steps[i] = distance
			nearest[i] = land


# ---------------------------------------------------------------- the fit

## A new course from a template (CourseTemplates), fitted to the lake: set to a wind (where it comes
## from, degrees, and its speed in knots, which sets the class's distances), for a number of boards,
## as near to preferred_centre (game X, Z) as it fits. Null when nothing fits (see last_reason).
func fit_template(id: String, rules: CourseRules, wind_kt: float, wind_from_deg: float, preferred_centre: Vector2,
		boards: int) -> Course:
	var template: Course = CourseTemplates.build(id, rules, wind_kt, boards, wind_from_deg, Vector2.ZERO)
	if template == null:
		last_reason = "There is no course template called %s." % id
		last_tries = 0
		return null
	return _fit(template, wind_from_deg, preferred_centre)


## A course already on the map, fitted to the lake: it keeps its shape (its marks, the order, any
## marks added by hand) and is only made smaller, turned to the wind (where it comes from, degrees,
## give or take axis_tolerance_deg) and moved, as near to where it is now as it fits. Its own size
## is tried first. Null when nothing fits (see last_reason); the course itself is not changed.
func fit_course(course: Course, wind_from_deg: float) -> Course:
	return _fit(course, wind_from_deg, course.bounds().get_center())


func _fit(original: Course, wind_from_deg: float, preferred: Vector2) -> Course:
	var start_us: int = Time.get_ticks_usec()
	last_reason = ""
	last_tries = 0
	_legs_too_close = 0
	var fitted: Course = null
	var sizes: Array[float] = _sizes_to_try(original.size_percent)
	if not has_water():
		last_reason = "There is no lake here to fit the course to: the fit starts from a spot on the water."
	else:
		for size: float in sizes:
			fitted = _fit_at_size(original, size, wind_from_deg, preferred)
			if fitted != null:
				break
		if fitted == null:
			last_reason = _reason_nothing_fits(sizes)
	last_fit_ms = (Time.get_ticks_usec() - start_us) / 1000.0
	return fitted


## The sizes to try, largest first: the course's own (but never under min_size_percent), then
## size_step_percent smaller each time, and min_size_percent itself last.
func _sizes_to_try(own_percent: float) -> Array[float]:
	var first: float = maxf(own_percent, min_size_percent)
	var sizes: Array[float] = [first]
	var step: float = maxf(size_step_percent, 1.0)
	var size: float = first - step
	while size > min_size_percent + 0.001:
		sizes.append(size)
		size -= step
	if first > min_size_percent + 0.001:
		sizes.append(min_size_percent)
	return sizes


## The axis offsets to try, by how far they are off the wind: [[0], [5, -5], [10, -10], ...].
func _axis_offsets() -> Array[PackedFloat32Array]:
	var offsets: Array[PackedFloat32Array] = [PackedFloat32Array([0.0])]
	if axis_step_deg <= 0.0:
		return offsets
	var off: float = axis_step_deg
	while off <= axis_tolerance_deg + 0.001:
		offsets.append(PackedFloat32Array([off, -off]))
		off += axis_step_deg
	return offsets


## The course at one size: the wind's axis first, then further off it. Of two axes as far off the
## wind (5 degrees right and left), the one whose spot is nearer the preferred spot.
func _fit_at_size(original: Course, size: float, wind_from_deg: float, preferred: Vector2) -> Course:
	for pair: PackedFloat32Array in _axis_offsets():
		var best: Course = null
		var best_distance: float = INF
		for offset: float in pair:
			var layout: Layout = _layout(original, size, wind_from_deg + offset)
			var spot: Vector2 = _best_spot(layout, preferred)
			if spot.is_finite() and spot.distance_to(preferred) < best_distance:
				best_distance = spot.distance_to(preferred)
				best = layout.course.copy()
				best.move_by(spot)
		if best != null:
			return best
	return null


## The course at a size and axis, with the middle of the box round its marks at (0, 0).
func _layout(original: Course, size: float, axis_deg: float) -> Layout:
	var layout: Layout = Layout.new()
	layout.course = original.copy()
	layout.course.set_size(size)
	layout.course.set_axis(axis_deg)
	layout.course.move_by(-layout.course.bounds().get_center())
	var marks: Array[CourseMark] = layout.course.marks.duplicate()
	marks.sort_custom(func(a: CourseMark, b: CourseMark) -> bool: return a.position.length() > b.position.length())
	for mark: CourseMark in marks:
		layout.mark_points.append(mark.position)
	layout.leg_points = _points_along_legs(layout.course)
	return layout


## The spot for a layout's middle nearest the preferred spot where it fits, or Vector2.INF.
## - The coarse grid runs through the preferred spot and covers the lake. A coarse spot is worth a
##   closer look when every mark there has at least the margin less half a coarse cell's diagonal:
##   moving the course anywhere in the cell round the spot moves no mark further than that, so a
##   course that only just fits between two coarse spots is not missed.
## - Then, nearest the preferred spot first, the fine grid over each such cell: the first cell where
##   something fits gives the spot nearest the preferred one in it.
func _best_spot(layout: Layout, preferred: Vector2) -> Vector2:
	var slack_m: float = coarse_step_m * sqrt(2.0) / 2.0
	var lake_west: float = x0_m
	var lake_north: float = z0_m
	var lake_east: float = x0_m + (columns - 1) * STEP_M
	var lake_south: float = z0_m + (rows - 1) * STEP_M
	var promising: Array[Vector2] = []
	for j: int in range(ceili((lake_north - preferred.y) / coarse_step_m), floori((lake_south - preferred.y) / coarse_step_m) + 1):
		for i: int in range(ceili((lake_west - preferred.x) / coarse_step_m), floori((lake_east - preferred.x) / coarse_step_m) + 1):
			var spot: Vector2 = preferred + Vector2(i, j) * coarse_step_m
			last_tries += 1
			if _marks_have_room(layout, spot, mark_margin_m - slack_m):
				promising.append(spot)
	# Nearest the preferred spot first; of two as near, the more northern, then the more western.
	promising.sort_custom(func(a: Vector2, b: Vector2) -> bool:
		var a_m: float = a.distance_squared_to(preferred)
		var b_m: float = b.distance_squared_to(preferred)
		if a_m != b_m:
			return a_m < b_m
		return a.y < b.y if a.y != b.y else a.x < b.x)
	var half: int = floori(coarse_step_m / 2.0 / fine_step_m)
	for spot: Vector2 in promising:
		var best: Vector2 = Vector2.INF
		var best_m: float = INF
		for j: int in range(-half, half + 1):
			for i: int in range(-half, half + 1):
				var fine: Vector2 = spot + Vector2(i, j) * fine_step_m
				var distance_m: float = fine.distance_to(preferred)
				if distance_m >= best_m:
					continue
				last_tries += 1
				if _fits(layout, fine):
					best = fine
					best_m = distance_m
		if best.is_finite():
			return best
	return Vector2.INF


## Whether every mark has at least this much room with the layout's middle at a spot.
func _marks_have_room(layout: Layout, spot: Vector2, room_m: float) -> bool:
	for point: Vector2 in layout.mark_points:
		if clearance_m(spot + point) < room_m:
			return false
	return true


## Whether the layout fits with its middle at a spot: the marks first, and only when they all have
## their room the legs, which take many more points to check.
func _fits(layout: Layout, spot: Vector2) -> bool:
	if not _marks_have_room(layout, spot, mark_margin_m):
		return false
	for point: Vector2 in layout.leg_points:
		if clearance_m(spot + point) < leg_margin_m:
			_legs_too_close += 1
			return false
	return true


## The points along a course's legs, LEG_STEP_M apart, both ends of each leg included. A leg sailed
## twice (the beats of two laps) is listed once.
func _points_along_legs(course: Course) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	var done: Dictionary[String, bool] = {}
	for leg: Course.Leg in course.legs():
		var key: String = leg.from_name + ">" + leg.to_name
		if done.has(key):
			continue
		done[key] = true
		var count: int = maxi(ceili(leg.length_m() / LEG_STEP_M), 1)
		for i: int in count + 1:
			points.append(leg.from_point.lerp(leg.to_point, float(i) / count))
	return points


func _reason_nothing_fits(sizes: Array[float]) -> String:
	var sizes_text: String = "at %.0f %% of the class's size" % sizes[0]
	if sizes.size() > 1:
		sizes_text = "from %.0f %% down to %.0f %% of the class's size" % [sizes[0], sizes[-1]]
	var legs_text: String = ""
	if _legs_too_close > 0:
		legs_text = " (in %d of them every mark had its room, but a leg came too close)" % _legs_too_close
	return "Nothing fits: %s, up to %.0f° off the wind, every spot on the lake puts a mark nearer than %.0f m or a leg nearer than %.0f m to the shore%s. The most open water here is %.0f m from the shore. %d tries." % [
		sizes_text, axis_tolerance_deg, mark_margin_m, leg_margin_m, legs_text, most_open_m(), last_tries]
