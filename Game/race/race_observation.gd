class_name RaceObservation
extends RefCounted
## What a learned skipper sees (RACING_PLAN.md, "The learned skipper", "What it sees"): one list of
## numbers, always as long, always in the same order, each scaled so that it stays within about -1
## to 1. A neural network learns best from numbers of that size: a raw distance of 500 m next to a
## sheet of 0.4 would drown the sheet out.
##
## The trainer (RaceEnv) and the game (LearnedSkipper) both build it here, with build(), so the two
## never drift apart: a brain trained on one list must be given the same list in the game.
## names() gives one name per number, in order, and goes into the brain file.
##
## It sees only what a sailor on the water could know (RD1): its own board, the course, the wind on
## the water around it, and the other boards near it.
##
## Angles go in as their sine and cosine rather than in degrees, because 359 degrees and 1 degree
## are nearly the same direction but very different numbers; sine and cosine are close for both.
## Bearings are "relative": 0 degrees (sine 0, cosine 1) is straight ahead of the bow, or straight
## into the wind. The board's own frame is forward along its heading and right to starboard.

## Distances are clipped at 1 km and given in km.
const DISTANCE_SCALE_M: float = 1000.0
## Speeds (the board's, the wind's, the others') are given in units of 15 m/s (29 knots).
const SPEED_SCALE_MS: float = 15.0
const HEEL_SCALE_DEG: float = 30.0
const PITCH_SCALE_DEG: float = 10.0
const YAW_RATE_SCALE_DPS: float = 60.0
## The seconds since the last manoeuvre are clipped at a minute.
const SINCE_MANOEUVRE_SCALE_S: float = 60.0
## The countdown is given in minutes (the game's countdown is one minute long).
const COUNTDOWN_SCALE_S: float = 60.0
## How far the board is over the start line (positive on the course side), in units of 100 m.
const OVER_LINE_SCALE_M: float = 100.0
## The wind is sampled this far away, ahead, behind, left and right of the board: the gusts and
## shifts coming toward it (on the lake; the open water's wind is the same everywhere).
const WIND_PROBE_M: float = 150.0
## The wind is sampled at the height its strength is quoted at (Telemetry.tws_10m_kt).
const WIND_PROBE_HEIGHT_M: float = 10.0
## The other boards are seen out to 100 m; further away they are put at 100 m in their direction.
const OTHERS_SCALE_M: float = 100.0
const OTHERS_SEEN: int = 2
## Scaled physical numbers are clipped at this, so a board on its side (heel 90 degrees) cannot
## swamp the network with a 3.
const CLIP: float = 2.0
## The four directions the wind is sampled in, turned from the heading (degrees): ahead, behind,
## left, right.
const PROBE_TURNS_DEG: Array[float] = [0.0, 180.0, -90.0, 90.0]
const PROBE_NAMES: Array[String] = ["ahead", "behind", "left", "right"]


## One name per number of build(), in the same order. A test checks that the two are as long.
static func names() -> PackedStringArray:
	var list: PackedStringArray = PackedStringArray([
		# Itself.
		"speed", "twa_sin", "twa_cos", "heel", "pitch", "yaw_rate", "planing", "sail_side",
		"fallen", "sheet", "rake", "since_manoeuvre", "in_manoeuvre",
	])
	# The next step of the course and the one after it.
	for which: String in ["next", "after"]:
		for part: String in ["distance", "ahead_sin", "ahead_cos", "wind_sin", "wind_cos", "side",
				"end_a_sin", "end_a_cos", "end_b_sin", "end_b_cos"]:
			list.append("%s_%s" % [which, part])
	# The race.
	list.append_array(PackedStringArray(["countdown", "over_line", "ocs", "progress"]))
	# The wind here, and around.
	list.append_array(PackedStringArray(["wind_speed", "wind_shift_sin", "wind_shift_cos"]))
	for probe: String in PROBE_NAMES:
		list.append("gust_%s_speed" % probe)
		list.append("gust_%s_dir" % probe)
	# The nearest other boards.
	for n: int in OTHERS_SEEN:
		for part: String in ["present", "forward", "right", "vforward", "vright"]:
			list.append("board%d_%s" % [n + 1, part])
	# The point the course pulls toward (AI_FLEET_PLAN.md, D6b), the leg after the next step, how far
	# there is still to sail, and what the hands were last told.
	list.append_array(PackedStringArray(["aim_distance", "aim_ahead_sin", "aim_ahead_cos", "aim_wind_sin", "aim_wind_cos",
		"next_out_sin", "next_out_cos", "remaining", "wanted_twa", "holding"]))
	return list


## How many numbers an observation has.
static func size() -> int:
	return names().size()


## The observation of board `index` of a race.
##   telemetry: the board's own, after the last step;
##   wind: the wind field it sails in (null: the four samples around it read as calm water, zeros);
##   others_positions / others_velocities: the other boards (game X, Z, and m/s in X, Z), any order;
##   in_manoeuvre: a tack or gybe is under way (PlayerController.manoeuvre);
##   since_manoeuvre_s: the seconds since the last one ended (advance_since_manoeuvre());
##   wanted_twa_deg, hold_speed_ms: what the hands were last told (LearnedSkipper.Driver): the
##     wind angle wanted and the hold-back speed (0: none), so a brain without a memory of its own
##     knows which tack it meant to be on and whether it is holding back.
static func build(telemetry: Telemetry, race: RaceSim, index: int, wind: WindField,
		others_positions: PackedVector2Array, others_velocities: PackedVector2Array,
		in_manoeuvre: bool, since_manoeuvre_s: float, wanted_twa_deg: float = 0.0, hold_speed_ms: float = 0.0) -> PackedFloat32Array:
	var obs: PackedFloat32Array = PackedFloat32Array()
	var here: Vector2 = Vector2(telemetry.position.x, telemetry.position.z)
	var heading_deg: float = telemetry.heading_deg
	var wind_from_deg: float = telemetry.wind_from_bearing_deg

	# Itself.
	obs.append(_scaled(telemetry.speed_ms, SPEED_SCALE_MS))
	obs.append(sin(deg_to_rad(telemetry.twa_deg)))  # positive: the wind from starboard
	obs.append(cos(deg_to_rad(telemetry.twa_deg)))  # 1 head to wind, -1 dead downwind
	obs.append(_scaled(telemetry.heel_deg, HEEL_SCALE_DEG))
	obs.append(_scaled(telemetry.pitch_deg, PITCH_SCALE_DEG))
	obs.append(_scaled(telemetry.yaw_rate_dps, YAW_RATE_SCALE_DPS))
	obs.append(clampf(telemetry.planing_ratio, 0.0, 1.0))
	obs.append(float(signi(telemetry.sail_side)))
	obs.append(1.0 if telemetry.sailor_state != WindsurferSim.SailorState.SAILING else 0.0)
	obs.append(clampf(telemetry.sheet, 0.0, 1.0))
	obs.append(clampf(telemetry.rake, -1.0, 1.0))
	obs.append(clampf(since_manoeuvre_s / SINCE_MANOEUVRE_SCALE_S, 0.0, 1.0))
	obs.append(1.0 if in_manoeuvre else 0.0)

	# The course: the step it sails to, and the one after. Once it has finished it keeps looking at
	# the finish line, as the HUD's arrow does.
	var steps: Array[RaceStep] = race.steps()
	var next_number: int = mini(race.next_step_index(index), steps.size() - 1)
	_append_step(obs, steps[next_number], here, heading_deg, wind_from_deg)
	var after: RaceStep = steps[next_number + 1] if next_number + 1 < steps.size() else null
	_append_step(obs, after, here, heading_deg, wind_from_deg)

	# The race: the countdown, where it is against the start line, over early or not, how far
	# through the course.
	var start: RaceStep = steps[0]
	obs.append(clampf(race.countdown_s() / COUNTDOWN_SCALE_S, 0.0, 1.0))
	obs.append(clampf(RoundingCheck.over_line_m(here, start.points[0], start.points[1], start.in_dir) / OVER_LINE_SCALE_M, -1.0, 1.0))
	obs.append(1.0 if race.is_ocs(index) else 0.0)
	obs.append(float(race.next_step_index(index)) / float(steps.size()))

	# The wind: its strength, how far it has shifted from the course's axis, and the wind 150 m
	# away in four directions compared with the wind here.
	obs.append(_scaled(telemetry.tws_10m_kt * SimMath.KNOT_MS, SPEED_SCALE_MS))
	var shift_rad: float = deg_to_rad(Course.turn_deg(race.course.axis_deg, wind_from_deg))
	obs.append(sin(shift_rad))
	obs.append(cos(shift_rad))
	_append_wind_around(obs, wind, here, heading_deg)

	# The two nearest other boards.
	_append_others(obs, telemetry, here, heading_deg, others_positions, others_velocities)

	# The point the course pulls toward (SailingDistance: a mark's rounding point, past the mark on
	# its correct side, or the best point of a line to cross), from the bow and from the wind; the
	# way the course goes on after the next step, from the wind; how far there is still to sail
	# round the course; and what the hands were last told. The yardstick's wind is the course's axis.
	var axis_deg: float = race.course.axis_deg
	var aim: Vector2 = SailingDistance.next_point(race, index, here, axis_deg)
	obs.append(minf(here.distance_to(aim), DISTANCE_SCALE_M) / DISTANCE_SCALE_M)
	var aim_bearing_deg: float = Course.bearing_deg(here, aim)
	_append_angle(obs, Course.turn_deg(heading_deg, aim_bearing_deg))
	_append_angle(obs, Course.turn_deg(wind_from_deg, aim_bearing_deg))
	var out_dir: Vector2 = steps[next_number].out_dir
	_append_angle(obs, Course.turn_deg(wind_from_deg, Course.bearing_deg(Vector2.ZERO, out_dir)))
	obs.append(clampf(SailingDistance.remaining_m(race, index, here, axis_deg) / SailingDistance.REMAINING_SCALE_M, 0.0, CLIP))
	obs.append(clampf(wanted_twa_deg / 180.0, -1.0, 1.0))
	obs.append(clampf(hold_speed_ms / SPEED_SCALE_MS, 0.0, 1.0))
	return obs


## The seconds since the last manoeuvre, one tick on: back to 0 while one is under way, counting up
## after it (and from the start of the race, as if the last one were long ago).
static func advance_since_manoeuvre(since_s: float, in_manoeuvre: bool, dt: float) -> float:
	if in_manoeuvre:
		return 0.0
	return minf(since_s + dt, SINCE_MANOEUVRE_SCALE_S)


# ---------------------------------------------------------------- the parts

## A step of the course, as ten numbers: the distance to it; the bearing to it from the bow and from
## the wind (the second says whether the leg is a beat, a reach or a run); the side the mark is left
## on (-1 port, +1 starboard, 0 for a line or a gate); and the bearings from the bow to its two ends
## (a line's or a gate's two ends; a mark's own position twice). No step (after the finish): zeros.
static func _append_step(obs: PackedFloat32Array, step: RaceStep, here: Vector2, heading_deg: float, wind_from_deg: float) -> void:
	if step == null:
		for k: int in 10:
			obs.append(0.0)
		return
	# Toward the nearest point of a line (where its distance is measured to), or toward the mark.
	var toward: Vector2 = step.points[0]
	if step.is_line():
		toward = Geometry2D.get_closest_point_to_segment(here, step.points[0], step.points[1])
	obs.append(minf(here.distance_to(toward), DISTANCE_SCALE_M) / DISTANCE_SCALE_M)
	var bearing_deg: float = Course.bearing_deg(here, toward)
	_append_angle(obs, Course.turn_deg(heading_deg, bearing_deg))
	_append_angle(obs, Course.turn_deg(wind_from_deg, bearing_deg))
	match step.side:
		CourseMark.Rounding.PORT:
			obs.append(-1.0)
		CourseMark.Rounding.STARBOARD:
			obs.append(1.0)
		_:
			obs.append(0.0)
	var end_b: Vector2 = step.points[1] if step.points.size() > 1 else step.points[0]
	_append_angle(obs, Course.turn_deg(heading_deg, Course.bearing_deg(here, step.points[0])))
	_append_angle(obs, Course.turn_deg(heading_deg, Course.bearing_deg(here, end_b)))


## The wind WIND_PROBE_M away ahead, behind, left and right, each as two numbers: how much stronger
## it is than here (0.2 for 20 % more), and how far it has turned (the sine; positive is clockwise
## seen from above, a veer). Calm water or no wind field: zeros.
static func _append_wind_around(obs: PackedFloat32Array, wind: WindField, here: Vector2, heading_deg: float) -> void:
	if wind == null:
		for k: int in PROBE_TURNS_DEG.size() * 2:
			obs.append(0.0)
		return
	var at_board: Vector3 = wind.velocity_at(Vector3(here.x, WIND_PROBE_HEIGHT_M, here.y))
	var flow_here: Vector2 = Vector2(at_board.x, at_board.z)
	for turn_deg: float in PROBE_TURNS_DEG:
		var point: Vector2 = here + Course.direction_of(heading_deg + turn_deg) * WIND_PROBE_M
		var at_point: Vector3 = wind.velocity_at(Vector3(point.x, WIND_PROBE_HEIGHT_M, point.y))
		var flow_there: Vector2 = Vector2(at_point.x, at_point.z)
		var speed_here: float = flow_here.length()
		if speed_here < 0.1 or flow_there.length() < 0.1:
			obs.append(0.0)
			obs.append(0.0)
			continue
		obs.append(clampf(flow_there.length() / speed_here - 1.0, -1.0, 1.0))
		# With X east and Z south, a positive angle_to turns from east toward south: clockwise on
		# the map. The air's direction and the direction it comes from turn together.
		obs.append(sin(flow_here.angle_to(flow_there)))


## The OTHERS_SEEN nearest other boards, nearest first, five numbers each: 1 (it is there), where it
## is (forward and to the right of this board, clipped at OTHERS_SCALE_M), and how fast it moves
## compared with this board (forward and right). Fewer boards: zeros for the missing ones.
static func _append_others(obs: PackedFloat32Array, telemetry: Telemetry, here: Vector2, heading_deg: float,
		positions: PackedVector2Array, velocities: PackedVector2Array) -> void:
	var forward: Vector2 = Course.direction_of(heading_deg)
	var right: Vector2 = Course.direction_of(heading_deg + 90.0)
	# Its own velocity, taken along its heading (the leeway is a few degrees).
	var own_velocity: Vector2 = forward * telemetry.speed_ms
	var nearest: Array[int] = _nearest(here, positions, OTHERS_SEEN)
	for n: int in OTHERS_SEEN:
		if n >= nearest.size():
			for k: int in 5:
				obs.append(0.0)
			continue
		var other: int = nearest[n]
		var offset: Vector2 = (positions[other] - here).limit_length(OTHERS_SCALE_M)
		var velocity: Vector2 = velocities[other] if other < velocities.size() else Vector2.ZERO
		var closing: Vector2 = velocity - own_velocity
		obs.append(1.0)
		obs.append(offset.dot(forward) / OTHERS_SCALE_M)
		obs.append(offset.dot(right) / OTHERS_SCALE_M)
		obs.append(_scaled(closing.dot(forward), SPEED_SCALE_MS))
		obs.append(_scaled(closing.dot(right), SPEED_SCALE_MS))


## The indices of the `count` positions nearest to a point, nearest first.
static func _nearest(here: Vector2, positions: PackedVector2Array, count: int) -> Array[int]:
	var order: Array[int] = []
	for i: int in positions.size():
		order.append(i)
	order.sort_custom(func(a: int, b: int) -> bool: return here.distance_squared_to(positions[a]) < here.distance_squared_to(positions[b]))
	return order.slice(0, count)


## An angle (degrees) as its sine and its cosine.
static func _append_angle(obs: PackedFloat32Array, degrees: float) -> void:
	var radians: float = deg_to_rad(degrees)
	obs.append(sin(radians))
	obs.append(cos(radians))


static func _scaled(value: float, scale: float) -> float:
	return clampf(value / scale, -CLIP, CLIP)
