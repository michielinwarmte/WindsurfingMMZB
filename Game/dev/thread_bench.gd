class_name ThreadBench
extends RefCounted
## Where do boards stepped side by side on worker threads wait for each other? (F1 `fleet_wait`,
## AI_FLEET_PLAN.md.) This script times small pieces of GDScript work, each run on 1, 4, 8 and 16
## worker threads at once, every thread doing the same amount of work on its own objects. Work that
## takes no engine lock takes the same time on 16 threads as on 1 (the laptop has 14 cores); work
## that takes a global lock gets slower with every thread added. The "slowdown" column is the wall
## time with n threads divided by the wall time with 1 thread: 1.0 is perfect, 8 means the threads
## run one after the other.
##
## The start menu runs it and quits when the game is started with --bench=thread (the release
## engine runs no script of its own): tools/thread_bench.sh [--release] runs it on the editor
## engine or on the release engine (after tools/release.sh build); they lock differently.
##
## Options (after "--"): [--threads=1,4,8,16] [--iterations=100000] [--only=basis,arrays]
##
## The last case, "board_step", is a whole board: WindsurferSim.step on n boards side by side,
## the way the race steps them (RaceRunner): every tick each board's sailor (the autopilot) sets
## its controls on this thread, then the boards' physics steps on the worker threads, one task
## per board, each with its own copies of the configs. On the waves, a beam reach in 18 kt,
## sailed BOARD_TICKS ticks to get going before BOARD_TICKS are timed. Its numbers are
## milliseconds per tick for all n boards together (the workers' wall time, the sailors not
## counted), and the slowdown is how much longer n boards side by side take than one alone: a
## board's step beside the others against its cost alone.

const DEFAULT_THREADS: String = "1,4,8,16"
const DEFAULT_ITERATIONS: int = 100000
## "board_step": the ticks sailed to get going, and then the ticks timed.
const BOARD_TICKS: int = 300
const DT: float = 1.0 / 60.0

## A plain object, one per thread, so that reading its fields shares nothing between threads.
class Other extends RefCounted:
	var f: float = 1.5
	var g: float = 0.25
	var v: Vector3 = Vector3(1.0, 2.0, 3.0)
	var b: Basis = Basis(Vector3.UP, 0.3)
	var t: Transform3D = Transform3D(Basis(Vector3.UP, 0.3), Vector3(1.0, 2.0, 3.0))
	var samples: PackedFloat64Array = PackedFloat64Array()

	func add(x: float) -> float:
		return f + x

	func get_f() -> float:
		return f

	func get_g() -> float:
		return g

	func xform(p: Vector3) -> Vector3:
		return b * p + v

	func first_of(list: PackedFloat64Array) -> float:
		return list[0]

	func itself() -> Other:
		return self


## A config-like resource, read by every thread (shared) or one per thread (own).
class Config extends Resource:
	var mass_kg: float = 90.0
	var area_m2: float = 7.8


var _owns: Array[Other] = []
var _shared: Other = Other.new()
var _own_configs: Array[Config] = []
var _shared_config: Config = Config.new()
var _sinks: PackedFloat64Array = PackedFloat64Array()
var _iterations: int = DEFAULT_ITERATIONS

const CASES: PackedStringArray = [
	"floats",            # local float arithmetic: no engine object at all
	"vectors",           # Vector3 arithmetic: values that fit inside a Variant
	"basis",             # Basis values made and multiplied: Variants kept in the engine's shared pool
	"transform",         # Transform3D values: the same pool, bigger bucket
	"arrays",            # a small Array made and filled: heap memory
	"packed_write",      # writing into a PackedFloat64Array made beforehand: no new memory
	"dictionary",        # a small Dictionary made and filled: heap memory
	"string",            # a formatted String: heap memory
	"new_object",        # a RefCounted made and dropped: the engine's object table
	"read_float_own",    # reading floats of another object owned by this thread
	"write_float_own",   # writing a float of another object owned by this thread
	"getter_own",        # the same float through a method of that object
	"pass_object",       # passing that object as a typed argument to a static function
	"read_float_shared", # reading floats of one object all threads share
	"read_vector_own",   # reading a Vector3 field of another object
	"read_basis_own",    # reading a Basis field of another object (a copy from the pool)
	"call_method_own",   # calling a method of another object owned by this thread
	"call_method_shared",# calling a method of one object all threads share
	"call_static",       # calling a static function of this script
	"resource_own",      # reading floats of a Resource owned by this thread
	"resource_shared",   # reading floats of one Resource all threads share
	# Added for F1 no_wait: the other things the physics does in its substeps.
	"self_field",        # reading a field of this object itself (the bench, shared by all threads)
	"call_static_other", # calling a static function of another class (SimMath.horizontal)
	"const_other",       # reading a constant of another class (SimMath.KNOT_MS)
	"typed_local",       # putting an object into a typed local variable
	"null_check",        # comparing an object with null
	"return_object",     # calling a method that gives back an object (a typed return)
	"call_self_method",  # calling a method of this object itself
	"packed_new",        # a PackedFloat64Array made and appended to (as a model's scratch list)
	"array_literal_for", # a loop over a two-element array literal (for j in [a, b])
	"vector_method_own", # a method of another object taking and giving a Vector3
	"packed_argument",   # handing a PackedFloat64Array to a method of another object
	"board_step",        # a whole board's physics tick, n boards side by side (see the top)
]

## A float of the bench itself, for "self_field".
var _own_number: float = 0.75
## "board_step": the boards and their sailors.
var _boards: Array[WindsurferSim] = []
var _sailors: Array[SimScenario] = []


func _half(x: float) -> float:
	return x * 0.5


## Runs every case and prints the table.
func run(options: Dictionary[String, String]) -> void:
	var thread_counts: PackedInt32Array = PackedInt32Array()
	for part: String in options.get("threads", DEFAULT_THREADS).split(","):
		thread_counts.append(part.to_int())
	_iterations = options.get("iterations", str(DEFAULT_ITERATIONS)).to_int()
	var only: PackedStringArray = PackedStringArray()
	if options.has("only"):
		only = options["only"].split(",")
	var most: int = 1
	for n: int in thread_counts:
		most = maxi(most, n)
	for i: int in most:
		var other: Other = Other.new()
		other.samples.resize(64)
		_owns.append(other)
		_own_configs.append(Config.new())
	_shared.samples.resize(64)
	_sinks.resize(most)
	print("thread bench: %s engine, %d processors, %d iterations per thread; wall time in ms per thread run, then the slowdown against 1 thread" % [
		"editor" if OS.has_feature("editor") else "release", OS.get_processor_count(), _iterations])
	var header: String = "%-20s" % "case"
	for n: int in thread_counts:
		header += "%10s" % ("%d thr" % n)
	for n: int in thread_counts:
		header += "%8s" % ("x%d" % n)
	print(header)
	for case_name: String in CASES:
		if not only.is_empty() and not only.has(case_name):
			continue
		var times_ms: PackedFloat64Array = PackedFloat64Array()
		for n: int in thread_counts:
			times_ms.append(_time_boards(n) if case_name == "board_step" else _time_case(case_name, n))
		var line: String = "%-20s" % case_name
		for ms: float in times_ms:
			line += "%10.1f" % ms
		for ms: float in times_ms:
			line += "%8.1f" % (ms / maxf(times_ms[0], 0.001))
		print(line)


## Wall milliseconds for n threads each running the case once (the best of three runs).
func _time_case(case_name: String, n: int) -> float:
	var best_us: int = 0
	for run: int in 3:
		var t0: int = Time.get_ticks_usec()
		var group: int = WorkerThreadPool.add_group_task(_run_case.bind(case_name), n, -1, true, "thread bench")
		WorkerThreadPool.wait_for_group_task_completion(group)
		var us: int = Time.get_ticks_usec() - t0
		if run == 0 or us < best_us:
			best_us = us
	return float(best_us) / 1000.0


func _run_case(index: int, case_name: String) -> void:
	var sink: float = 0.0
	var k: int = _iterations
	var own: Other = _owns[index]
	var shared: Other = _shared
	var config: Config = _own_configs[index]
	var shared_config: Config = _shared_config
	match case_name:
		"floats":
			var x: float = float(index) + 0.5
			for i: int in k:
				x = x * 0.999 + sin(x) * 0.01 + 0.001
			sink = x
		"vectors":
			var a: Vector3 = Vector3(1.0, float(index), 0.5)
			var c: Vector3 = Vector3(0.2, 0.3, 0.9)
			for i: int in k:
				a = (a.cross(c) + c * a.dot(c)).normalized() + Vector3(0.001, 0.0, 0.0)
			sink = a.x
		"basis":
			var b: Basis = Basis(Vector3.UP, 0.1)
			var r: Basis = Basis(Vector3.RIGHT, 0.001)
			for i: int in k:
				b = b * r
			sink = b.x.x
		"transform":
			var t: Transform3D = Transform3D(Basis(Vector3.UP, 0.1), Vector3.ZERO)
			var r: Transform3D = Transform3D(Basis(Vector3.RIGHT, 0.001), Vector3(0.001, 0.0, 0.0))
			for i: int in k:
				t = t * r
			sink = t.origin.x
		"arrays":
			for i: int in k:
				var a: Array[float] = []
				a.append(1.0)
				a.append(2.0)
				a.append(3.0)
				sink += a[2]
		"packed_write":
			var samples: PackedFloat64Array = own.samples
			for i: int in k:
				samples[i % 64] = float(i)
				sink += samples[(i + 7) % 64]
		"dictionary":
			for i: int in k:
				var d: Dictionary[String, float] = {}
				d["a"] = 1.0
				d["b"] = 2.0
				sink += d["b"]
		"string":
			for i: int in k:
				var s: String = "%d" % i
				sink += float(s.length())
		"new_object":
			for i: int in k:
				var o: RefCounted = RefCounted.new()
				sink += 1.0 if o != null else 0.0
		"read_float_own":
			for i: int in k:
				sink += own.f * own.g + own.f
		"write_float_own":
			for i: int in k:
				own.g = float(i)
				sink += 1.0
		"getter_own":
			for i: int in k:
				sink += own.get_f() * own.get_g()
		"pass_object":
			for i: int in k:
				sink += _take(own)
		"read_float_shared":
			for i: int in k:
				sink += shared.f * shared.g + shared.f
		"read_vector_own":
			for i: int in k:
				sink += own.v.x + own.v.z
		"read_basis_own":
			for i: int in k:
				sink += own.b.x.x + own.b.z.z
		"call_method_own":
			for i: int in k:
				sink += own.add(0.5)
		"call_method_shared":
			for i: int in k:
				sink += shared.add(0.5)
		"call_static":
			for i: int in k:
				sink += _twice(0.5)
		"resource_own":
			for i: int in k:
				sink += config.mass_kg * config.area_m2
		"resource_shared":
			for i: int in k:
				sink += shared_config.mass_kg * shared_config.area_m2
		"self_field":
			for i: int in k:
				sink += _own_number * _own_number + _own_number
		"call_static_other":
			var v: Vector3 = Vector3(1.0, 2.0, 3.0)
			for i: int in k:
				sink += SimMath.horizontal(v).x
		"const_other":
			for i: int in k:
				sink += SimMath.KNOT_MS
		"typed_local":
			for i: int in k:
				var o: Other = own
				sink += 1.0
		"null_check":
			for i: int in k:
				sink += 1.0 if own != null else 0.0
		"return_object":
			for i: int in k:
				own.itself()
				sink += 1.0
		"call_self_method":
			for i: int in k:
				sink += _half(0.5)
		"packed_new":
			for i: int in k:
				var list: PackedFloat64Array = PackedFloat64Array()
				list.append(1.0)
				list.append(2.0)
				sink += list[1]
		"array_literal_for":
			for i: int in k:
				for j: int in [i, i + 1]:
					sink += float(j)
		"vector_method_own":
			var p: Vector3 = Vector3(0.5, 0.5, 0.5)
			for i: int in k:
				sink += own.xform(p).y
		"packed_argument":
			var samples: PackedFloat64Array = own.samples
			for i: int in k:
				sink += own.first_of(samples)
	_sinks[index] = sink


## "board_step": milliseconds per tick for n boards stepped side by side (see the top).
func _time_boards(n: int) -> float:
	_boards.clear()
	_sailors.clear()
	for i: int in n:
		var sailor: SimScenario = load("res://dev/scenarios/beam_reach.gd").new()
		sailor.wind_kt = 18.0
		var sim: WindsurferSim = WindsurferSim.create_for(EnvironmentConfig.new(), true, true)
		sim.wind_config.speed_kt = sailor.wind_kt
		sim.wind = WindField.new(sim.wind_config)
		sailor.pilot.sail = sim.sail
		sailor.pilot.sailor = sim.sailor_config
		sim.set_waves(true)
		sim.reset(Vector3(30.0 * i, 0.0, 0.0), deg_to_rad(sailor.start_heading_deg))
		sailor.setup(sim)
		_boards.append(sim)
		_sailors.append(sailor)
	var us: int = 0
	for tick: int in 2 * BOARD_TICKS:
		for i: int in n:
			_sailors[i].update(_boards[i], DT)
		var t0: int = Time.get_ticks_usec()
		var group: int = WorkerThreadPool.add_group_task(_step_board, n, -1, true, "thread bench boards")
		WorkerThreadPool.wait_for_group_task_completion(group)
		if tick >= BOARD_TICKS:
			us += Time.get_ticks_usec() - t0
	_boards.clear()
	_sailors.clear()
	return float(us) / 1000.0 / float(BOARD_TICKS)


func _step_board(index: int) -> void:
	_boards[index].step(DT, _sailors[index].controls)


static func _twice(x: float) -> float:
	return x * 2.0


static func _take(_other: Other) -> float:
	return 1.0

