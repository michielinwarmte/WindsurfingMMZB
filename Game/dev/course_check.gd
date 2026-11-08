extends SceneTree
## How close the lake's saved courses come to the shore and the shallows (the skipper's heads, Max, 8
## November 2026: "change the courses so they are not too close to the shore"). For every course in
## Game/maps/silvaplana/courses/: each mark's room to the land and to water shallower than SHALLOW_M
## (CourseFitter's clearance grid on the lake's heights, the shallows counted as land), and the least
## room along each leg and in each beat's or run's tacking zone (the diamond between the laylines at
## TACK_HALF_DEG either side of the leg, where the boards really sail).
##
##   tools/godot.sh --headless --path Game -s res://dev/course_check.gd [-- --shallow_m=2]

const GRID_PATH: String = "res://maps/silvaplana/terrain/shore_heights.json"
const MAP_CONFIG_PATH: String = "res://maps/silvaplana/map_config.tres"
const COURSES_FOLDER: String = "res://maps/silvaplana/courses"
## Water shallower than this counts as land for the "shallow" numbers, metres (ShoreLookout.DEEP_M).
const SHALLOW_M: float = 2.0
## A beat or a run is sailed inside the diamond between the laylines this far either side of the
## leg's line, degrees (about the polar's beat angle with the leeway).
const TACK_HALF_DEG: float = 48.0
## A leg is a beat or a run when it is within this of the wind, degrees.
const BEAT_RUN_WITHIN_DEG: float = 40.0
const STEP_M: float = 20.0


func _initialize() -> void:
	var shallow_m: float = SHALLOW_M
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--shallow_m="):
			shallow_m = argument.split("=")[1].to_float()
	var grid: TerrainGrid = TerrainGrid.load_from(GRID_PATH)
	var config: MapConfig = load(MAP_CONFIG_PATH)
	var files: PackedStringArray = DirAccess.get_files_at(COURSES_FOLDER)
	var land: CourseFitter = null
	var shallow: CourseFitter = null
	for file: String in files:
		if not file.ends_with(".json"):
			continue
		var course: Course = Course.load_from(COURSES_FOLDER.path_join(file), config)
		if course == null:
			continue
		if land == null:
			land = CourseFitter.from_heights(grid.height_at, course.start_middle())
			var offset_height: Callable = func(x: float, z: float) -> float: return grid.height_at(x, z) + shallow_m
			shallow = CourseFitter.from_heights(offset_height, course.start_middle())
		var race: RaceSim = RaceSim.new(course, 1, 0.0)
		print("%s (%s, %s, axis %.0f, size %.0f %%)" % [file, course.name, course.sequence, course.axis_deg, course.size_percent])
		var worst_mark: float = INF
		for mark: CourseMark in course.marks:
			var p: Vector2 = Vector2(mark.position.x, mark.position.y)
			worst_mark = minf(worst_mark, shallow.clearance_m(p))
			print("  mark %-12s (%6.0f, %6.0f)  land %4.0f m  shallow %4.0f m  depth %5.1f m" % [mark.id, p.x, p.y,
				land.clearance_m(p), shallow.clearance_m(p), -grid.height_at(p.x, p.y)])
		var steps: Array[RaceStep] = race.steps()
		var worst_leg: float = INF
		var worst_zone: float = INF
		for k: int in range(1, steps.size()):
			var a: Vector2 = steps[k - 1].target()
			var b: Vector2 = steps[k].target()
			var line_m: float = _least_along(shallow, a, b)
			var off_wind: float = absf(Course.turn_deg(course.axis_deg, Course.bearing_deg(a, b)))
			var zone_text: String = ""
			if off_wind < BEAT_RUN_WITHIN_DEG or off_wind > 180.0 - BEAT_RUN_WITHIN_DEG:
				var zone_m: float = _least_in_diamond(shallow, a, b)
				worst_zone = minf(worst_zone, zone_m)
				zone_text = "  tacking zone %4.0f m" % zone_m
			worst_leg = minf(worst_leg, line_m)
			print("  leg %d %-10s -> %-10s %5.0f m, %3.0f deg off the wind, line %4.0f m%s" % [k, steps[k - 1].name, steps[k].name,
				a.distance_to(b), off_wind, line_m, zone_text])
		print("  WORST shallow room: marks %.0f m, legs %.0f m, tacking zones %.0f m" % [worst_mark, worst_leg, worst_zone])
	quit(0)


## The least room to the shallows along a straight line, metres.
static func _least_along(fitter: CourseFitter, a: Vector2, b: Vector2) -> float:
	var least: float = INF
	var count: int = maxi(ceili(a.distance_to(b) / STEP_M), 1)
	for i: int in count + 1:
		least = minf(least, fitter.clearance_m(a.lerp(b, float(i) / count)))
	return least


## The least room to the shallows inside the diamond between the laylines from a to b (the beat's or
## the run's tacking zone), metres: points on a grid across the diamond.
static func _least_in_diamond(fitter: CourseFitter, a: Vector2, b: Vector2) -> float:
	var least: float = INF
	var half_width: float = 0.5 * a.distance_to(b) * tan(deg_to_rad(TACK_HALF_DEG))
	var along_dir: Vector2 = (b - a).normalized()
	var across: Vector2 = along_dir.orthogonal()
	var count: int = maxi(ceili(a.distance_to(b) / STEP_M), 1)
	for i: int in count + 1:
		var share: float = float(i) / count
		var width: float = half_width * (1.0 - absf(2.0 * share - 1.0))
		var middle: Vector2 = a.lerp(b, share)
		var across_count: int = maxi(ceili(width / STEP_M), 0)
		for j: int in range(-across_count, across_count + 1):
			var offset: float = width * (float(j) / across_count) if across_count > 0 else 0.0
			least = minf(least, fitter.clearance_m(middle + across * offset))
	return least
