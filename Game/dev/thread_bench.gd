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

const DEFAULT_THREADS: String = "1,4,8,16"
const DEFAULT_ITERATIONS: int = 100000

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
]


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
			times_ms.append(_time_case(case_name, n))
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
	_sinks[index] = sink


static func _twice(x: float) -> float:
	return x * 2.0


static func _take(_other: Other) -> float:
	return 1.0

