extends SceneTree
## The sailor figure's motion, measured (sailor polish, 6 November 2026). Max saw the figure
## glitch: the body shaking in the chop, the hands jumping along the boom and the arms snapping
## straight, tacks and gybes that look wrong, the feet sliding or popping and the knees snapping;
## and the sailor standing in the middle of the board while planing instead of in the straps.
##
## This sails the windsurfer exactly as the game does (the scene windsurfer.tscn, its node's
## sail(), step_physics() and after_step() every 1/60 s, so the figure is posed by the game's own
## code), headless, and records every joint of the figure's skeleton (FigureSkeleton) in the
## board's axes at every physics tick. For each case it reports, per joint:
## - the largest step in one tick (cm) and where it happened, and the 99th percentile step;
## - the largest change of that step from one tick to the next (cm per tick per tick, the
##   "acceleration spike": a smooth movement changes its step a few millimetres a tick at most,
##   a jump or a snap changes it by centimetres);
## and for the knees and the elbows the same for their bend angle (degrees), and in the world
## the up-and-down shake of the head, the hips and the deck under the feet (to see whether the
## body is steadier than the board, as on a real sailor whose knees take the chop).
## With --trace it also writes the physics' posture every tick (the stance, the feet, the press,
## the speed, the nose's depth, where the figure's feet stand against the footstraps).
##
## Run it (from the repo root):
##   tools/godot.sh --headless --no-header --path Game -s res://dev/figure_motion.gd -- [options]
## Options:
##   --cases=beam18,broad24,...   the cases (default: all of them; see CASES below)
##   --out=<csv>                  the per-joint table, one row per case and joint
##   --trace=<dir>                a CSV per case with the posture every tick
##   --label=<text>               a column in the CSV (before / after)
##   --top=5                      how many of the largest spikes to print per case, with context
##   --from=<s> --seconds=<s>     record from this time for this long instead of the case's window
##   --dump=<from>,<to>           print the joints named in --dump_joints (default the pelvis, the
##                                neck, the hands and the ankles) every tick between these times

const DT: float = 1.0 / 60.0
const ENVIRONMENT_PATH: String = "res://maps/silvaplana/environment_silvaplana.tres"
const MAP_CONFIG_PATH: String = "res://maps/silvaplana/map_config.tres"
## The lake scene's start (40 m off the camping beach) and a spot in the lake's middle.
const START_LV95: Vector2 = Vector2(2780880.0, 1147510.0)
const MIDDLE: Vector3 = Vector3(349.0, 0.0, -89.0)
## The lake's time of day (the Maloja is at its strongest).
const LAKE_TIME_S: float = 14.5 * 3600.0
## Below this speed the board is sailed on a reach (getting going), then on the case's course.
const POINTING_SPEED_MS: float = 10.0
const START_TWA_DEG: float = 70.0
const START_TWA_MAX_DEG: float = 90.0

const JOINT_NAMES: PackedStringArray = ["pelvis", "spine", "neck", "head", "hip_l", "hip_r",
	"knee_l", "knee_r", "ankle_l", "ankle_r", "toes_l", "toes_r", "shoulder_l", "shoulder_r",
	"elbow_l", "elbow_r", "wrist_l", "wrist_r", "hand_l", "hand_r", "mast_top", "clew"]
const ANGLE_NAMES: PackedStringArray = ["knee_l_deg", "knee_r_deg", "elbow_l_deg", "elbow_r_deg"]


## name: [place (lake / lakemap / open), wind kt, twa, body (none / press / sweep), event (none /
## tack / gybe / fall), event time s, record from s, record seconds]
const CASES: Dictionary[String, Array] = {
	"beam18": ["lake", 18.0, 90.0, "none", "none", 0.0, 25.0, 30.0],
	"beam24": ["lake", 24.0, 90.0, "none", "none", 0.0, 25.0, 30.0],
	"broad18": ["lake", 18.0, 140.0, "none", "none", 0.0, 30.0, 30.0],
	"broad24": ["lake", 24.0, 140.0, "none", "none", 0.0, 30.0, 30.0],
	"max18": ["lake", 18.0, 140.0, "press", "none", 0.0, 30.0, 30.0],
	"max24": ["lake", 24.0, 140.0, "press", "none", 0.0, 30.0, 30.0],
	"maxmap": ["lakemap", 0.0, 140.0, "press", "none", 0.0, 30.0, 30.0],
	"broadmap": ["lakemap", 0.0, 140.0, "none", "none", 0.0, 30.0, 30.0],
	"beammap": ["lakemap", 0.0, 90.0, "none", "none", 0.0, 25.0, 30.0],
	"body18": ["lake", 18.0, 120.0, "sweep", "none", 0.0, 25.0, 30.0],
	"body24": ["lake", 24.0, 120.0, "sweep", "none", 0.0, 25.0, 30.0],
	"tack18": ["lake", 18.0, 70.0, "none", "tack", 30.0, 29.0, 16.0],
	"tack12": ["lake", 12.0, 70.0, "none", "tack", 30.0, 29.0, 16.0],
	"gybe18": ["lake", 18.0, 135.0, "none", "gybe", 30.0, 29.0, 16.0],
	"gybe24": ["lake", 24.0, 135.0, "none", "gybe", 30.0, 29.0, 16.0],
	"water18": ["lake", 18.0, 90.0, "none", "fall", 25.0, 25.0, 15.0],
}

## The body's places in the sweep, one after the other (side, back; side +1 is the most rail).
const SWEEP: Array[Vector2] = [Vector2(1.0, 1.0), Vector2(-1.0, -1.0), Vector2(1.0, -1.0),
	Vector2(-1.0, 1.0), Vector2(0.0, 0.0), Vector2(0.5, 1.0), Vector2(-0.5, -0.5)]
const SWEEP_HOLD_S: float = 1.5

var _options: Dictionary[String, String] = {}
var _map_config: MapConfig
var _grid: TerrainGrid
var _started: bool = false


## The work starts at the first frame: a node added to the tree before then is not made ready.
func _process(_delta: float) -> bool:
	if not _started:
		_started = true
		_run_all()
	return false


func _run_all() -> void:
	_options = _read_user_args()
	_map_config = load(MAP_CONFIG_PATH)
	var names: PackedStringArray = _options.get("cases", ",".join(PackedStringArray(CASES.keys()))).split(",")
	var out_path: String = _options.get("out", "")
	for case_name: String in names:
		if not CASES.has(case_name):
			push_error("No case called %s" % case_name)
			continue
		_run_case(case_name, out_path)
	quit(0)


## One case: the board sailed from rest, the figure recorded over the case's window.
func _run_case(case_name: String, out_path: String) -> void:
	var c: Array = CASES[case_name]
	var place: String = c[0]
	var wind_kt: float = c[1]
	var twa: float = c[2]
	var body_mode: String = c[3]
	var event: String = c[4]
	var event_s: float = c[5]
	var record_from_s: float = _options.get("from", str(c[6])).to_float()
	var record_s: float = _options.get("seconds", str(c[7])).to_float()

	var ws: WindsurferNode = _make_windsurfer(place, wind_kt, twa)
	var sim: WindsurferSim = ws.sim
	var figure: SailorFigure = ws.find_child("SailorFigure", true, false) as SailorFigure
	var s: FigureSkeleton = figure.skeleton
	var hands: AiHands = AiHands.new()
	ws.controller.hands = hands
	ws.controller.push_level = 1.0
	hands.push = 1.0
	if body_mode != "none":
		var body: MouseBody = MouseBody.new()
		body.scripted = true
		body.sideways = MouseBody.Sideways.RIGHT_IS_MORE_RAIL
		ws.controller.body = body
	ws.reset()

	var trace: FileAccess = null
	if _options.has("trace"):
		DirAccess.make_dir_recursive_absolute(_options["trace"])
		trace = FileAccess.open(_options["trace"].path_join(case_name + ".csv"), FileAccess.WRITE)
		trace.store_line(_trace_header())

	var positions: Array[PackedVector3Array] = []
	var angles: Array[PackedFloat64Array] = []
	var world: Array[PackedVector3Array] = []
	var contexts: Array[String] = []
	var times: PackedFloat64Array = PackedFloat64Array()
	var pointing: bool = false
	var tack_sign: float = 1.0
	var event_done: bool = false
	var after_event: bool = false
	var aground: bool = false
	var steps: int = int((record_from_s + record_s) / DT)
	for i: int in steps:
		var t: Telemetry = sim.telemetry
		var now: float = sim.time_s
		# The course: a reach until the board is going, then the case's.
		if t.speed_ms > POINTING_SPEED_MS:
			pointing = true
		var wanted: float = twa if pointing else clampf(twa, START_TWA_DEG, START_TWA_MAX_DEG)
		if after_event and event == "gybe":
			wanted = 120.0
		if after_event and event == "tack":
			wanted = 75.0
		var turning: bool = ws.controller.manoeuvre != PlayerController.Manoeuvre.NONE
		hands.steer = 0.0 if turning else LearnedSkipper.steer_toward_twa(t.twa_deg, tack_sign, wanted)
		hands.sheet = 0.0
		# The event.
		if not event_done and now >= event_s and event != "none":
			event_done = true
			match event:
				"tack", "gybe":
					hands.tack = true
					after_event = true
					tack_sign = -tack_sign
				"fall":
					sim.force_fall("catapult")
		# The body is moved only once the board is going (as Max did: planing first, then the mouse).
		_set_body(ws.controller.body, body_mode if pointing else "none", now)
		ws.sail(DT)
		ws.step_physics(DT)
		ws.after_step()
		if _grid != null and ShoreCheck.is_aground(_grid, sim.body.origin_world(), sim.fin_config.span_m):
			aground = true
			break
		if sim.time_s < record_from_s - 0.5 * DT:
			continue
		times.append(sim.time_s)
		var joints: PackedVector3Array = _joints(s, ws)
		positions.append(joints)
		angles.append(_angles(joints))
		world.append(_world_points(ws, s, joints))
		contexts.append(_context(ws, s))
		if trace != null:
			trace.store_line(_trace_row(ws, s))
		if _options.has("dump"):
			_dump(sim.time_s, joints, contexts[contexts.size() - 1])
	if trace != null:
		trace.close()
	print("")
	print("=== %s: %s, %s kt, twa %d, body %s, event %s%s; %d ticks recorded from %.1f s; speed now %.1f m/s, state %s" % [
		case_name, place, "map" if place == "lakemap" else str(wind_kt), int(twa), body_mode, event,
		" (RAN AGROUND)" if aground else "", times.size(), record_from_s, sim.telemetry.speed_ms,
		"fallen" if sim.sailor_state == WindsurferSim.SailorState.FALLEN else "sailing"])
	_report(case_name, times, positions, angles, world, contexts, out_path)
	ws.queue_free()
	root.remove_child(ws)


## The windsurfer node as the game builds it, on the lake (a steady wind of wind_kt from the
## lake's mean direction, the lake's own waves for that wind) or in the map's own wind
## ("lakemap": the Maloja at 14:30 with its gusts, as Max sails it).
func _make_windsurfer(place: String, wind_kt: float, twa: float) -> WindsurferNode:
	var ws: WindsurferNode = (load("res://windsurfer/windsurfer.tscn") as PackedScene).instantiate() as WindsurferNode
	ws.own_config_copies = true
	ws.effects_wanted = false
	var environment: EnvironmentConfig = (load(ENVIRONMENT_PATH) as EnvironmentConfig).duplicate()
	environment.start_hour = LAKE_TIME_S / 3600.0
	ws.environment = environment
	var from_deg: float = environment.map_wind().lake_from_deg(LAKE_TIME_S)
	var start: Vector3 = _map_config.lv95_to_game(START_LV95.x, START_LV95.y, _map_config.lake_level_m)
	ws.start_position = Vector3(start.x, 0.0, start.z)
	# Starboard tack (the wind from the right): the heading is the wind's bearing less the angle.
	ws.start_heading_deg = fposmod(from_deg - clampf(twa, START_TWA_DEG, START_TWA_MAX_DEG), 360.0)
	root.add_child(ws)
	ws.set_physics_process(false)
	_grid = environment.depth_grid()
	var sim: WindsurferSim = ws.sim
	if place == "lake":
		var wind: WindConfig = (sim.wind as MapWindField).config.duplicate() as WindConfig
		wind.speed_kt = wind_kt
		wind.from_bearing_deg = from_deg
		wind.gusts_enabled = false
		wind.shifts_enabled = false
		sim.wind_config = wind
		sim.wind = WindField.new(wind)
	sim.wave_set_config = sim.wave_set_config.duplicate(true)
	sim.wave_set_config.place_waves = true
	sim.set_waves(true)
	return ws


## The body on the mouse (held by script): pressing (toes and back foot, as in Max's photo), or
## swept from place to place as a player moving the mouse about.
func _set_body(body: MouseBody, mode: String, now: float) -> void:
	if body == null:
		return
	if mode == "none":
		body.side = 0.0
		body.back = 0.0
	elif mode == "press":
		body.side = 1.0
		body.back = 1.0
	elif mode == "sweep":
		var place: Vector2 = SWEEP[int(now / SWEEP_HOLD_S) % SWEEP.size()]
		body.side = place.x
		body.back = place.y


## Every joint, board axes, in the order of JOINT_NAMES, where the figure's parts are drawn (the
## figure's root carries the fall, the swim and the getting up, and after a waterstart the parts
## unfold from how they lay in the water: SailorFigure._unfold()); and the rig as it is drawn (the
## mast's top and the boom's end, the clew), which the hands hold.
func _joints(s: FigureSkeleton, ws: WindsurferNode) -> PackedVector3Array:
	var root_node: Node3D = ws.find_child("Sailor", true, false) as Node3D
	var drawn: Transform3D = root_node.transform
	var out: PackedVector3Array = PackedVector3Array()
	out.append(_part(root_node, "Pelvis").origin)
	out.append(_part(root_node, "Ribs").origin)
	out.append(_part(root_node, "Shoulders").origin)
	out.append(_part(root_node, "Head").origin)
	for label: String in ["Left", "Right"]:
		var thigh: Transform3D = _part(root_node, "Thigh" + label)
		out.append(thigh.origin - thigh.basis.y.normalized() * (0.5 * s.thigh_m))
	for label: String in ["Left", "Right"]:
		out.append(_part(root_node, "Knee" + label).origin)
	for label: String in ["Left", "Right"]:
		out.append(_part(root_node, "Foot" + label) * Vector3(0.0, s.ankle_height_m, 0.0))
	for label: String in ["Left", "Right"]:
		out.append(_part(root_node, "Foot" + label) * Vector3(0.0, 0.0, -0.75 * s.foot_length_m))
	for label: String in ["Left", "Right"]:
		out.append(_part(root_node, "Shoulder" + label).origin)
	for label: String in ["Left", "Right"]:
		var upper_arm: Transform3D = _part(root_node, "UpperArm" + label)
		out.append(upper_arm.origin + upper_arm.basis.y.normalized() * (0.5 * s.upper_arm_m))
	for label: String in ["Left", "Right"]:
		var forearm: Transform3D = _part(root_node, "Forearm" + label)
		out.append(forearm.origin + forearm.basis.y.normalized() * (0.5 * s.forearm_m))
	for label: String in ["Left", "Right"]:
		out.append(_part(root_node, "Hand" + label).origin)
	for i: int in out.size():
		out[i] = drawn * out[i]
	var sail: Node3D = ws.find_child("Sail", true, false) as Node3D
	var foot: Vector3 = ws.sim.sail_config.mast_foot_local
	var mast_dir: Vector3 = sail.transform.basis.y.normalized()
	var boom_dir: Vector3 = sail.transform.basis.x.normalized()
	out.append(foot + mast_dir * ws.sim.sail_config.mast_m)
	out.append(foot + mast_dir * ws.sim.sail_config.boom_height_m + boom_dir * ws.sim.sail_config.boom_m)
	return out


## A part of the figure (a child of its root), as it is laid.
static func _part(root_node: Node3D, part_name: String) -> Transform3D:
	return (root_node.get_node(part_name) as Node3D).transform


## The bend of the knees and the elbows as drawn, degrees (0 = straight).
func _angles(joints: PackedVector3Array) -> PackedFloat64Array:
	var out: PackedFloat64Array = PackedFloat64Array()
	for side: String in ["l", "r"]:
		out.append(_bend_deg(joints[JOINT_NAMES.find("hip_" + side)], joints[JOINT_NAMES.find("knee_" + side)], joints[JOINT_NAMES.find("ankle_" + side)]))
	for side: String in ["l", "r"]:
		out.append(_bend_deg(joints[JOINT_NAMES.find("shoulder_" + side)], joints[JOINT_NAMES.find("elbow_" + side)], joints[JOINT_NAMES.find("wrist_" + side)]))
	return out


static func _bend_deg(a: Vector3, middle: Vector3, b: Vector3) -> float:
	var u: Vector3 = (a - middle).normalized()
	var v: Vector3 = (b - middle).normalized()
	return 180.0 - rad_to_deg(acos(clampf(u.dot(v), -1.0, 1.0)))


## In the world, where the deck under the feet, the hips, the head, a hand and the mast's top are
## (m): what a camera that follows the board smoothly sees move.
const WORLD_NAMES: PackedStringArray = ["deck", "hips", "head", "hand_r", "mast_top"]


func _world_points(ws: WindsurferNode, s: FigureSkeleton, joints: PackedVector3Array) -> PackedVector3Array:
	var board: Transform3D = ws.global_transform
	return PackedVector3Array([board * s.feet_centre, board * joints[JOINT_NAMES.find("pelvis")],
		board * joints[JOINT_NAMES.find("head")], board * joints[JOINT_NAMES.find("hand_r")],
		board * joints[JOINT_NAMES.find("mast_top")]])


## A few words on what the sailor was doing, for the largest spikes.
func _context(ws: WindsurferNode, s: FigureSkeleton) -> String:
	var sim: WindsurferSim = ws.sim
	var state: String = "fallen" if sim.sailor_state == WindsurferSim.SailorState.FALLEN else "sailing"
	# What each hand holds (FigureHands; the figure before the sailor polish had none).
	var holds: String = ""
	var grips: FigureHands = s.get("grips") as FigureHands
	for side: int in 2:
		if grips != null:
			holds += "%s%s%.2f%s " % ["L" if side == 0 else "R", ["boom", "mast", "free"][grips.holds[side]], grips.along_m[side],
				"*" if grips.is_reaching(side) else ""]
	var drawn_rig: DrawnRig = ws.get("_drawn_rig") as DrawnRig
	return "%s v=%.1f stance=%.2f lean=%+.2f facing=%+.2f yaw=%+.0f manoeuvre=%d hooked=%s press=%+.2f/%+.2f straps=%s flip=%s %s" % [
		state, sim.telemetry.speed_ms, sim.stance, sim.lean, s.facing_side, sim.telemetry.yaw_rate_dps,
		ws.controller.manoeuvre, s.hooked, sim.feet_roll_press, sim.feet_pitch_press, s.get("in_straps"),
		drawn_rig.flipping if drawn_rig != null else false, holds]


## The tables: per joint the largest step and spike, and the world's shake.
func _report(case_name: String, times: PackedFloat64Array, positions: Array[PackedVector3Array],
		angles: Array[PackedFloat64Array], world: Array[PackedVector3Array], contexts: Array[String], out_path: String) -> void:
	var n: int = positions.size()
	if n < 3:
		print("  too few ticks")
		return
	print("  %-11s %8s %7s %8s %9s %7s %8s" % ["joint", "step_max", "at_s", "step_p99", "spike_max", "at_s", "spike_p99"])
	var spikes: Array[Array] = []
	var label: String = _options.get("label", "")
	for j: int in JOINT_NAMES.size():
		var steps: PackedFloat64Array = PackedFloat64Array()
		var accs: PackedFloat64Array = PackedFloat64Array()
		var step_max: float = 0.0
		var step_at: int = 0
		var acc_max: float = 0.0
		var acc_at: int = 0
		for i: int in range(1, n):
			var step: float = 100.0 * (positions[i][j] - positions[i - 1][j]).length()
			steps.append(step)
			if step > step_max:
				step_max = step
				step_at = i
			if i >= 2:
				var acc: float = 100.0 * (positions[i][j] - 2.0 * positions[i - 1][j] + positions[i - 2][j]).length()
				accs.append(acc)
				if acc > acc_max:
					acc_max = acc
					acc_at = i
				spikes.append([acc, JOINT_NAMES[j], i])
		var row: Array = [JOINT_NAMES[j], step_max, times[step_at], _percentile(steps, 0.99), acc_max, times[acc_at], _percentile(accs, 0.99)]
		print("  %-11s %8.2f %7.2f %8.2f %9.2f %7.2f %8.2f" % row)
		if out_path != "":
			_append(out_path, "label,case,joint,step_max_cm,step_max_at_s,step_p99_cm,spike_max_cm,spike_max_at_s,spike_p99_cm",
				"%s,%s,%s,%.3f,%.2f,%.3f,%.3f,%.2f,%.3f" % [label, case_name, row[0], row[1], row[2], row[3], row[4], row[5], row[6]])
	for k: int in ANGLE_NAMES.size():
		var steps: PackedFloat64Array = PackedFloat64Array()
		var accs: PackedFloat64Array = PackedFloat64Array()
		var step_max: float = 0.0
		var step_at: int = 0
		var acc_max: float = 0.0
		var acc_at: int = 0
		for i: int in range(1, n):
			var step: float = absf(angles[i][k] - angles[i - 1][k])
			steps.append(step)
			if step > step_max:
				step_max = step
				step_at = i
			if i >= 2:
				var acc: float = absf(angles[i][k] - 2.0 * angles[i - 1][k] + angles[i - 2][k])
				accs.append(acc)
				if acc > acc_max:
					acc_max = acc
					acc_at = i
		var row: Array = [ANGLE_NAMES[k], step_max, times[step_at], _percentile(steps, 0.99), acc_max, times[acc_at], _percentile(accs, 0.99)]
		print("  %-11s %8.2f %7.2f %8.2f %9.2f %7.2f %8.2f" % row)
		if out_path != "":
			_append(out_path, "label,case,joint,step_max_cm,step_max_at_s,step_p99_cm,spike_max_cm,spike_max_at_s,spike_p99_cm",
				"%s,%s,%s,%.3f,%.2f,%.3f,%.3f,%.2f,%.3f" % [label, case_name, row[0], row[1], row[2], row[3], row[4], row[5], row[6]])
	# The shake in the world: the root mean square and the largest change of step (cm per tick per
	# tick) of the deck under the feet, the hips, the head, a hand and the mast's top. A body that
	# rides the chop on its knees shakes less than the deck it stands on.
	var line: String = "  world shake rms/max (cm/tick^2):"
	for m: int in WORLD_NAMES.size():
		var square_sum: float = 0.0
		var largest: float = 0.0
		for i: int in range(2, n):
			var a: float = 100.0 * (world[i][m] - 2.0 * world[i - 1][m] + world[i - 2][m]).length()
			square_sum += a * a
			largest = maxf(largest, a)
		var rms: float = sqrt(square_sum / float(n - 2))
		line += "  %s %.2f/%.1f" % [WORLD_NAMES[m], rms, largest]
		if out_path != "":
			_append(out_path, "label,case,joint,step_max_cm,step_max_at_s,step_p99_cm,spike_max_cm,spike_max_at_s,spike_p99_cm",
				"%s,%s,world_%s,0,0,0,%.3f,0,%.3f" % [label, case_name, WORLD_NAMES[m], largest, rms])
	print(line)
	spikes.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
	var top: int = _options.get("top", "5").to_int()
	var shown: Dictionary[int, bool] = {}
	var printed: int = 0
	for spike: Array in spikes:
		if printed >= top:
			break
		var tick: int = spike[2]
		if shown.has(tick):
			continue
		shown[tick] = true
		printed += 1
		print("  spike %.1f cm %s at %.2f s: %s" % [spike[0], spike[1], times[tick], contexts[tick]])


## One tick's joints, for --dump.
func _dump(time_s: float, joints: PackedVector3Array, context: String) -> void:
	var window: PackedStringArray = _options["dump"].split(",")
	if window.size() < 2 or time_s < window[0].to_float() or time_s > window[1].to_float():
		return
	var names: PackedStringArray = _options.get("dump_joints", "pelvis,neck,hand_l,hand_r,ankle_l,ankle_r").split(",")
	var line: String = "  %.3f" % time_s
	for joint_name: String in names:
		var p: Vector3 = joints[JOINT_NAMES.find(joint_name)]
		line += "  %s (%.2f %.2f %.2f)" % [joint_name, p.x, p.y, p.z]
	print(line + "  " + context)


func _percentile(values: PackedFloat64Array, share: float) -> float:
	if values.is_empty():
		return 0.0
	var sorted: PackedFloat64Array = values.duplicate()
	sorted.sort()
	return sorted[clampi(int(share * float(sorted.size() - 1)), 0, sorted.size() - 1)]


func _trace_header() -> String:
	return "time_s,speed_fwd_ms,planing_ratio,stance,body_stance,feet_x,feet_z,trim_press_m,feet_pitch_press,feet_roll_press,press_point_m,nose_depth_m,lean,com_z,pelvis_z,front_ankle_z,back_ankle_z,front_strap_z,back_strap_z,facing,hooked,heel_deg,pitch_deg,sheet,manoeuvre,com_x,com_y,pelvis_x,pelvis_y,yaw_dps,grip_x,grip_y,grip_z,hand_r_x,hand_r_y,hand_r_z,pelvis_offset_m,knee_bend_m,harness_n"


func _trace_row(ws: WindsurferNode, s: FigureSkeleton) -> String:
	var sim: WindsurferSim = ws.sim
	var forward: float = -sim.body.to_body(sim.body.velocity).z
	var com: Vector3 = sim.body.to_body(sim.sailor.position - sim.body.origin_world())
	var half: float = 0.5 * sim.board_config.length_m
	var front_strap_z: float = half - sim.board_config.front_strap_from_tail_m
	var back_strap_z: float = half - sim.board_config.back_strap_from_tail_m
	var nose_depth: float = sim.buoyancy.point_depths_m[sim.buoyancy.bow_centre_index]
	return "%.3f,%.2f,%.3f,%.3f,%.3f,%.3f,%.3f,%.3f,%.3f,%.3f,%.3f,%.3f,%.3f,%.3f,%.3f,%.3f,%.3f,%.3f,%.3f,%.3f,%d,%.2f,%.2f,%.3f,%d" % [
		sim.time_s, forward, sim.hull.planing_ratio, sim.stance, sim.body_stance, sim.feet_body.x, sim.feet_body.z,
		sim.trim_press_m, sim.feet_pitch_press, sim.feet_roll_press, sim.feet_body.z - sim.mass_model.stance_z_m(sim.stance),
		nose_depth, sim.lean, com.z, s.pelvis.z, minf(s.ankles[0].z, s.ankles[1].z), maxf(s.ankles[0].z, s.ankles[1].z),
		front_strap_z, back_strap_z, s.facing_side, 1 if s.hooked else 0, sim.telemetry.heel_deg, sim.telemetry.pitch_deg,
		sim.telemetry.sheet, ws.controller.manoeuvre] + ",%.3f,%.3f,%.3f,%.3f,%.1f,%.3f,%.3f,%.3f,%.3f,%.3f,%.3f,%.3f,%.3f,%.0f" % [
		com.x, com.y, s.pelvis.x, s.pelvis.y, sim.telemetry.yaw_rate_dps, sim.hand_grip_body.x, sim.hand_grip_body.y,
		sim.hand_grip_body.z, s.hands[1].x, s.hands[1].y, s.hands[1].z, s.pelvis_offset_m, sim.knee_bend_m, sim.harness_tension_n]


func _append(path: String, header: String, row: String) -> void:
	var exists: bool = FileAccess.file_exists(path)
	var file: FileAccess = FileAccess.open(path, FileAccess.READ_WRITE if exists else FileAccess.WRITE)
	if file == null:
		push_error("Cannot write %s" % path)
		return
	if exists:
		file.seek_end()
	else:
		file.store_line(header)
	file.store_line(row)
	file.close()


func _read_user_args() -> Dictionary[String, String]:
	var options: Dictionary[String, String] = {}
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--"):
			var parts: PackedStringArray = arg.substr(2).split("=", true, 1)
			options[parts[0]] = parts[1] if parts.size() > 1 else "1"
	return options
