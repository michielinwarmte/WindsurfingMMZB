extends SceneTree
## The trainer of learned skippers, by neuroevolution (RACING_PLAN.md, "If PPO disappoints"): no
## Python, no backpropagation, only races. Use tools/race_evolve.sh.
##
## How it learns, in a paragraph. It starts with a population of networks with random weights.
## Each generation every network sails the same race (the same seed, so they all meet the same
## start) on its own board, and its fitness is the reward it collected (RaceEnv: progress toward the
## marks, the steps completed, the finish, minus the falls and the time). The best few (the elite)
## go into the next generation unchanged; the rest of the next generation are their children:
## copies of a randomly chosen elite with a little random noise on every weight (and now and then a
## mix of two elites). Most children are worse than their parent, a few are better, and those few
## become the next elite. The noise shrinks a little each generation, so the search goes from bold
## to careful. Over hundreds of generations this finds networks that sail the course.
##
## The episodes of a generation are independent races, so they can run side by side on all the
## cores. Two ways (--parallel):
##   processes (the default): this script starts --threads copies of Godot, each a "worker" that
##     sails races one after another until none is left, and waits for them. The networks go to the
##     workers as brain files in a work folder, and each race's result comes back as a small JSON
##     file. A worker takes a race by creating its folder claim_<n> (making a folder is all or
##     nothing, so two workers never take the same race), so a fast core sails more races than a
##     slow one.
##   threads: one Godot, the races as tasks on its WorkerThreadPool. Measured on Max's laptop on
##     20 October 2026: this does not get faster with more threads, it gets slower (in Godot 4.7.2's
##     debug build every GDScript function call from several threads at once waits on the others),
##     so it is kept only to measure that again after a Godot update.
##
## Arguments after "--" (the defaults in brackets):
##   --run=<name>          [night] the name of the run: the CSV and the brain files are named after it
##   --course=t1_loop      [t1_loop] the course (only T1 for now: it is on the open water)
##   --wind_kt=15          [15] the wind, steady, from the course's axis
##   --laps=1              [1] (T1's order already goes round mark 1 twice)
##   --episode_s=240       [240] each episode's time limit, seconds, the 10 s countdown included
##   --stall_s=0           [0: off] also end an episode when the board has gained nothing toward the
##                         course for this many seconds (saves the time of the boards going nowhere)
##   --prestart_s=10       [10] the countdown, seconds
##   --start_behind_m=150  [150] how far behind the start line the board waits at the start: the
##                         plan's pre-start spot is 150 m back, too far to reach T1's 60 m line on
##                         one tack; 25 m lets a beginner reach it on either tack
##   --population=64       [64] networks per generation
##   --actions=twa         [twa] how the networks' numbers are read: twa, the wind angle to hold (the
##                         hands steer for it and tack or gybe when it is on the other tack), or
##                         stick, the steering stick itself and a tack output (LearnedSkipper)
##   --episodes=1          [1] races per network per generation, each from another start; the fitness
##                         is their mean (more races: a fairer fitness, at that many times the cost)
##   --elite=8             [8] the best ones kept unchanged each generation
##   --sigma=0.1           [0.1] the width of the noise on the weights of a child
##   --sigma_min=0.02      [0.02] the noise shrinks by --sigma_decay per generation down to this
##   --sigma_decay=0.99    [0.99]
##   --crossover=0.2       [0.2] the share of the children that mix two elites before the noise
##   --hidden=64,64        [64,64] the hidden layers' sizes
##   --output_scale=1      [1] the first networks' last layer is this much smaller than the others
##                         (0.1: they start by sailing straight; see NeuralNet.make)
##   --generations=1000    [1000] and --hours=6 [6]: it stops at whichever comes first
##   --threads=0           [0] how many races at once; 0 is OS.get_processor_count()
##   --parallel=processes  [processes] or threads (see above)
##   --seed=1              [1] the seed of the whole run (the networks, the noise, the races)
##   --resume=<brain.json> start from this brain (and mutated copies of it) instead of random ones
##   --commit=<hash>       the physics commit, written into the brain files (race_evolve.sh gives it)
##   --save_every=10       [10] a brain file of the generation's best every this many generations
##
## Or, to see how a brain sails: --evaluate=<brain.json> [--races=5] sails it in that many races (the
## seeds 1, 2, ...) with the same race options, one line per race (the steps, the splits, the falls),
## and writes the first race's track to .sim_output/evolve/evaluate.csv (time, x, z, heading, speed,
## wind angle, next step), every tenth of a second.
##
## Output: one line per generation on the screen and in .sim_output/evolve/<run>.csv; the best
## brain so far in Game/race/brains/<run>_best.json each time it improves, and the generation's best
## in Game/race/brains/<run>_gen<N>.json for generation 1 and every save_every generations.

const BRAINS_DIR: String = "res://race/brains"
const T1_START: Vector2 = Vector2.ZERO
## A worker that has not finished after this long is stopped, and its races count as failed.
const WORKER_TIMEOUT_S: float = 3600.0
## The fitness of a race whose result never came back (a worker that crashed).
const FAILED_FITNESS: float = -1.0e6


## What one race (one network's episode) gave.
class Result:
	var fitness: float = FAILED_FITNESS
	var steps_done: int = 0
	var steps_total: int = 0
	var finish_s: float = -1.0
	var falls: int = 0
	var progress_m: float = 0.0
	var ticks: int = 0

	static func of(env: RaceEnv) -> Result:
		var result: Result = Result.new()
		var board: RaceEnv.Board = env.board(0)
		result.fitness = board.total
		result.steps_done = env.race.next_step_index(0)
		result.steps_total = env.race.steps().size()
		result.finish_s = env.race.finish_time_s(0)
		result.falls = board.falls
		result.progress_m = board.progress_m
		result.ticks = env.ticks
		return result

	## One network's result over several races (--episodes): the mean fitness and progress, the
	## fewest steps done, the slowest finish (-1 if it did not finish them all), all the falls.
	static func of_all(envs: Array[RaceEnv]) -> Result:
		var result: Result = Result.of(envs[0])
		for k: int in range(1, envs.size()):
			var other: Result = Result.of(envs[k])
			result.fitness += other.fitness
			result.progress_m += other.progress_m
			result.steps_done = mini(result.steps_done, other.steps_done)
			result.finish_s = -1.0 if (result.finish_s < 0.0 or other.finish_s < 0.0) else maxf(result.finish_s, other.finish_s)
			result.falls += other.falls
			result.ticks += other.ticks
		result.fitness /= envs.size()
		result.progress_m /= envs.size()
		return result

	func to_dict() -> Dictionary:
		return {"fitness": fitness, "steps_done": steps_done, "steps_total": steps_total, "finish_s": finish_s,
			"falls": falls, "progress_m": progress_m, "ticks": ticks}

	static func from_dict(data: Dictionary) -> Result:
		var result: Result = Result.new()
		result.fitness = float(data.get("fitness", FAILED_FITNESS))
		result.steps_done = int(data.get("steps_done", 0))
		result.steps_total = int(data.get("steps_total", 0))
		result.finish_s = float(data.get("finish_s", -1.0))
		result.falls = int(data.get("falls", 0))
		result.progress_m = float(data.get("progress_m", 0.0))
		result.ticks = int(data.get("ticks", 0))
		return result


## The races of one generation for --parallel=threads: a task sails one of them (race k of network n
## is number n * episodes + k); nothing in here is shared between two tasks.
class Batch:
	var envs: Array[RaceEnv] = []
	var brains: Array[NeuralNet] = []
	var episodes: int = 1

	func sail(index: int) -> void:
		envs[index].run_episode(brains[floori(float(index) / episodes)])


var _options: Dictionary[String, String] = {}
var _course: Course
var _env_options: RaceEnv.Options
var _wind_kt: float = 15.0
var _episodes: int = 1


func _initialize() -> void:
	_options = _read_user_args()
	if _text("course", RaceCourses.T1_NAME) != RaceCourses.T1_NAME:
		push_error("evolve: only --course=t1_loop for now (the trainer sails on the open water).")
		quit(2)
		return
	_course = RaceCourses.t1_loop(EnvironmentConfig.new().wind_or_default().from_bearing_deg, T1_START)
	_wind_kt = _number("wind_kt", 15.0)
	_env_options = RaceEnv.Options.new()
	_env_options.episode_s = _number("episode_s", 240.0)
	_env_options.stall_s = _number("stall_s", 0.0)
	_env_options.prestart_s = _number("prestart_s", _env_options.prestart_s)
	_env_options.start_behind_m = _number("start_behind_m", _env_options.start_behind_m)
	_env_options.laps = maxi(_integer("laps", 1), 1)
	_episodes = maxi(_integer("episodes", 1), 1)
	_env_options.actions = LearnedSkipper.mode_named(_text("actions", "twa"))
	if _options.has("job"):
		_work(_text("job", ""))
	elif _options.has("evaluate"):
		_evaluate(_text("evaluate", ""), maxi(_integer("races", 5), 1))
	else:
		_train()


# ---------------------------------------------------------------- the trainer

func _train() -> void:
	var run_name: String = _text("run", "night")
	var population_size: int = maxi(_integer("population", 64), 2)
	var elite_count: int = clampi(_integer("elite", 8), 1, population_size - 1)
	var sigma: float = _number("sigma", 0.1)
	var sigma_min: float = _number("sigma_min", 0.02)
	var sigma_decay: float = _number("sigma_decay", 0.99)
	var crossover_share: float = clampf(_number("crossover", 0.2), 0.0, 1.0)
	var generations: int = maxi(_integer("generations", 1000), 1)
	var hours: float = _number("hours", 6.0)
	var threads: int = _integer("threads", 0)
	if threads <= 0:
		threads = OS.get_processor_count()
	var use_threads: bool = _text("parallel", "processes") == "threads"
	var seed: int = _integer("seed", 1)
	var save_every: int = maxi(_integer("save_every", 10), 1)

	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed
	var population: Array[NeuralNet] = _first_population(population_size, sigma, rng)
	if population.is_empty():
		quit(2)
		return

	var work_dir: String = _repository_path(".sim_output/evolve/%s_work" % run_name)
	var csv_path: String = _repository_path(".sim_output/evolve/%s.csv" % run_name)
	DirAccess.make_dir_recursive_absolute(work_dir)
	var csv: FileAccess = FileAccess.open(csv_path, FileAccess.WRITE)
	if csv != null:
		csv.store_line("generation,best,mean,median,best_steps,steps_total,best_finish_s,best_falls,best_progress_m,started,seconds,ticks_per_s,sigma,elapsed_s")
	print("evolve %s: %s, %.0f kt, %d lap%s, actions %s, %d race%s of %.0f s%s per network, the start %.0f m behind the line; population %d, elite %d, sigma %.3f to %.3f, network %s (%d weights), %d %s" % [
		run_name, _course.name, _wind_kt, _env_options.laps, "" if _env_options.laps == 1 else "s",
		LearnedSkipper.mode_name(_env_options.actions),
		_episodes, "" if _episodes == 1 else "s", _env_options.episode_s,
		(" (stall %.0f s)" % _env_options.stall_s) if _env_options.stall_s > 0.0 else "", _env_options.start_behind_m,
		population_size, elite_count, sigma, sigma_min, str(population[0].sizes()), population[0].parameter_count(),
		threads, "threads" if use_threads else "processes"])

	var started_ms: int = Time.get_ticks_msec()
	var best_ever: float = -INF
	for generation: int in range(1, generations + 1):
		if Time.get_ticks_msec() - started_ms > hours * 3600.0 * 1000.0:
			print("Stopped after %.2f hours." % hours)
			break
		var generation_ms: int = Time.get_ticks_msec()
		# Every network of the generation sails the same race: the seed changes from one generation
		# to the next, so the elite must prove itself again on a new start.
		var race_seed: int = seed * 100000 + generation
		var results: Array[Result] = []
		if use_threads:
			results = _sail_in_threads(population, race_seed, threads)
		else:
			results = _sail_in_processes(population, race_seed, threads, work_dir)
		var seconds: float = (Time.get_ticks_msec() - generation_ms) / 1000.0

		var fitness: Array[float] = []
		var total_ticks: int = 0
		# How many of the population got over the start line (in every race they sailed): the
		# first thing they learn.
		var started: int = 0
		for result: Result in results:
			fitness.append(result.fitness)
			total_ticks += result.ticks
			if result.steps_done >= 1:
				started += 1
		var order: Array[int] = _ranking(fitness)
		var best: Result = results[order[0]]
		var best_brain: NeuralNet = population[order[0]]
		var elapsed_s: float = (Time.get_ticks_msec() - started_ms) / 1000.0
		print(_summary(generation, fitness, order, best, started, seconds, total_ticks, sigma))
		if csv != null:
			csv.store_line("%d,%.3f,%.3f,%.3f,%d,%d,%.2f,%d,%.1f,%d,%.2f,%.0f,%.4f,%.1f" % [
				generation, best.fitness, _mean(fitness), _median(fitness, order), best.steps_done, best.steps_total,
				best.finish_s, best.falls, best.progress_m, started, seconds, total_ticks / maxf(seconds, 0.001), sigma, elapsed_s])
			csv.flush()

		# Keep the brains worth keeping.
		_note(best_brain, run_name, generation, best, sigma)
		if best.fitness > best_ever:
			best_ever = best.fitness
			best_brain.save(_brain_path("%s_best" % run_name))
		if generation == 1 or generation % save_every == 0:
			best_brain.save(_brain_path("%s_gen%d" % [run_name, generation]))

		# The next generation: the elite unchanged, and their children. The elite race again next
		# generation, on its new seed, with everyone else, and are ranked only on that race: a brain
		# that was lucky once does not stay at the top.
		var next: Array[NeuralNet] = []
		for k: int in elite_count:
			next.append(population[order[k]])
		while next.size() < population_size:
			var parent: NeuralNet = population[order[rng.randi_range(0, elite_count - 1)]]
			if crossover_share > 0.0 and elite_count > 1 and rng.randf() < crossover_share:
				var other: NeuralNet = population[order[rng.randi_range(0, elite_count - 1)]]
				parent = parent.crossover(other, rng)
			next.append(parent.mutated(sigma, rng))
		population = next
		sigma = maxf(sigma * sigma_decay, sigma_min)
	if csv != null:
		csv.close()
	print("Done. Best fitness %.1f. The log: %s; the brains: %s" % [best_ever, csv_path, ProjectSettings.globalize_path(BRAINS_DIR)])
	quit(0)


## The first generation: networks with random weights, or (--resume) a saved brain and mutated
## copies of it. Empty if the brain to resume from cannot be read.
func _first_population(size: int, sigma: float, rng: RandomNumberGenerator) -> Array[NeuralNet]:
	var population: Array[NeuralNet] = []
	if _options.has("resume"):
		var path: String = _text("resume", "")
		if not path.is_absolute_path() and not path.begins_with("res://"):
			path = _repository_path(path)
		var brain: NeuralNet = NeuralNet.load_file(path)
		if brain == null:
			return population
		if brain.input_count() != RaceObservation.size():
			push_error("evolve: %s takes %d inputs, the observation has %d." % [path, brain.input_count(), RaceObservation.size()])
			return population
		# Its children answer the way it learnt to.
		_env_options.actions = LearnedSkipper.mode_of(brain)
		population.append(brain)
		while population.size() < size:
			population.append(brain.mutated(sigma, rng))
		return population
	var sizes: Array[int] = [RaceObservation.size()]
	for part: String in _text("hidden", "64,64").split(",", false):
		sizes.append(maxi(part.to_int(), 1))
	sizes.append(LearnedSkipper.ACTION_NAMES.size())
	var output_scale: float = _number("output_scale", 1.0)
	for n: int in size:
		population.append(NeuralNet.make(sizes, rng, output_scale))
	return population


## A fresh race for one network: race number `episode` of the generation's seed, the same for
## every network of the generation.
func _new_env(race_seed: int, episode: int = 0) -> RaceEnv:
	var env: RaceEnv = RaceEnv.new(_course, 1, _wind_kt, _env_options)
	env.reset(race_seed + 1000003 * episode)
	return env


## --parallel=threads: the races as tasks of one group on the WorkerThreadPool. The races are built
## here on the main thread (building a simulation loads its configuration files), each task only
## steps its own race, and the results are read here after.
func _sail_in_threads(population: Array[NeuralNet], race_seed: int, threads: int) -> Array[Result]:
	var batch: Batch = Batch.new()
	batch.episodes = _episodes
	for brain: NeuralNet in population:
		for k: int in _episodes:
			batch.envs.append(_new_env(race_seed, k))
		batch.brains.append(brain)
	# A high-priority task: Godot gives low-priority tasks only 30 % of its threads
	# (threading/worker_pool/low_priority_thread_ratio).
	var group: int = WorkerThreadPool.add_group_task(batch.sail, batch.envs.size(), threads, true, "evolve")
	WorkerThreadPool.wait_for_group_task_completion(group)
	var results: Array[Result] = []
	for n: int in population.size():
		results.append(Result.of_all(batch.envs.slice(n * _episodes, (n + 1) * _episodes)))
	return results


## --parallel=processes: the networks into the work folder as brain files, `workers` copies of
## Godot started on them, and their results read back once they have all finished.
func _sail_in_processes(population: Array[NeuralNet], race_seed: int, workers: int, work_dir: String) -> Array[Result]:
	_clear_folder(work_dir)
	for n: int in population.size():
		population[n].save(work_dir.path_join("brain_%d.json" % n))
	var arguments: PackedStringArray = PackedStringArray([
		"--headless", "--no-header", "--path", ProjectSettings.globalize_path("res://"), "-s", "res://dev/evolve.gd", "--",
		"--job=%s" % work_dir, "--population=%d" % population.size(), "--race_seed=%d" % race_seed,
		"--wind_kt=%s" % _wind_kt, "--episode_s=%s" % _env_options.episode_s, "--stall_s=%s" % _env_options.stall_s,
		"--laps=%d" % _env_options.laps, "--episodes=%d" % _episodes, "--prestart_s=%s" % _env_options.prestart_s,
		"--actions=%s" % LearnedSkipper.mode_name(_env_options.actions),
		"--start_behind_m=%s" % _env_options.start_behind_m])
	var pids: Array[int] = []
	for k: int in mini(workers, population.size()):
		var pid: int = OS.create_process(OS.get_executable_path(), arguments)
		if pid > 0:
			pids.append(pid)
		else:
			push_error("evolve: could not start worker %d." % k)
	var waited_ms: int = 0
	while _any_running(pids):
		OS.delay_msec(100)
		waited_ms += 100
		if waited_ms > WORKER_TIMEOUT_S * 1000.0:
			push_error("evolve: the workers took over %.0f s; stopping them." % WORKER_TIMEOUT_S)
			for pid: int in pids:
				if OS.is_process_running(pid):
					OS.kill(pid)
			break
	var results: Array[Result] = []
	var missing: int = 0
	for n: int in population.size():
		var path: String = work_dir.path_join("result_%d.json" % n)
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
		if parsed is Dictionary:
			results.append(Result.from_dict(parsed))
		else:
			results.append(Result.new())
			missing += 1
	if missing > 0:
		push_error("evolve: %d race result%s did not come back; they count as failed." % [missing, "" if missing == 1 else "s"])
	return results


static func _any_running(pids: Array[int]) -> bool:
	for pid: int in pids:
		if OS.is_process_running(pid):
			return true
	return false


## Empties the work folder of the last generation's files and claims.
static func _clear_folder(folder: String) -> void:
	for file: String in DirAccess.get_files_at(folder):
		DirAccess.remove_absolute(folder.path_join(file))
	for sub: String in DirAccess.get_directories_at(folder):
		DirAccess.remove_absolute(folder.path_join(sub))


# ---------------------------------------------------------------- a worker

## A worker (--job=<folder>): sails the folder's races one after another, each one it can claim,
## and writes each result next to its brain. It prints nothing; the trainer reports.
func _work(work_dir: String) -> void:
	var population: int = _integer("population", 0)
	var race_seed: int = _integer("race_seed", 1)
	for n: int in population:
		# Making the folder is the claim: only one worker can make it.
		if DirAccess.make_dir_absolute(work_dir.path_join("claim_%d" % n)) != OK:
			continue
		var brain: NeuralNet = NeuralNet.load_file(work_dir.path_join("brain_%d.json" % n))
		if brain == null:
			continue
		var envs: Array[RaceEnv] = []
		for k: int in _episodes:
			envs.append(_new_env(race_seed, k))
			envs[k].run_episode(brain)
		# Written under another name and then renamed, so the trainer never reads half a file.
		var path: String = work_dir.path_join("result_%d.json" % n)
		var file: FileAccess = FileAccess.open(path + ".part", FileAccess.WRITE)
		if file == null:
			continue
		file.store_string(JSON.stringify(Result.of_all(envs).to_dict()))
		file.close()
		DirAccess.rename_absolute(path + ".part", path)
	quit(0)


# ---------------------------------------------------------------- how a brain sails

## Sails one brain in a few races and prints how each went; the first race's track goes to a CSV.
func _evaluate(path: String, races: int) -> void:
	if not path.is_absolute_path() and not path.begins_with("res://"):
		path = _repository_path(path)
	var brain: NeuralNet = NeuralNet.load_file(path)
	if brain == null:
		quit(2)
		return
	_env_options.actions = LearnedSkipper.mode_of(brain)
	var csv_path: String = _repository_path(".sim_output/evolve/evaluate.csv")
	DirAccess.make_dir_recursive_absolute(csv_path.get_base_dir())
	var track: FileAccess = FileAccess.open(csv_path, FileAccess.WRITE)
	if track != null:
		track.store_line("time_s,x_m,z_m,heading_deg,speed_ms,twa_deg,next_step,action_1,action_2,action_3,hands_steer")
	print("%s (generation %s of run %s, actions %s): %d race%s of %.0f s on %s" % [path.get_file(), str(brain.meta.get("generation", "?")),
		str(brain.meta.get("run", "?")), LearnedSkipper.mode_name(_env_options.actions), races, "" if races == 1 else "s",
		_env_options.episode_s, _course.name])
	for race_number: int in range(1, races + 1):
		var env: RaceEnv = _new_env(race_number)
		var total: float = 0.0
		while not env.done(0):
			var action: PackedFloat32Array = brain.forward(env.observe(0))
			if race_number == 1 and track != null:
				var t: Telemetry = env.board(0).sim.telemetry
				track.store_line("%.1f,%.2f,%.2f,%.1f,%.2f,%.1f,%d,%.3f,%.3f,%.3f,%.3f" % [env.time_s, t.position.x, t.position.z,
					t.heading_deg, t.speed_ms, t.twa_deg, env.race.next_step_index(0), action[0], action[1], action[2], env.board(0).hands.steer])
			env.act(0, action)
			for k: int in env.decision_ticks:
				env.tick()
				if env.done(0):
					break
			total += env.reward(0)
		var result: RaceResult = env.race.results()[0]
		print("race %d: fitness %7.1f  falls %d  progress %5.0f m  %s" % [race_number, total, env.board(0).falls, env.board(0).progress_m, result.to_line()])
	if track != null:
		track.close()
	print("The first race's track: %s" % csv_path)
	quit(0)


# ---------------------------------------------------------------- the results

## The individuals' numbers from the best fitness to the worst.
static func _ranking(fitness: Array[float]) -> Array[int]:
	var order: Array[int] = []
	for n: int in fitness.size():
		order.append(n)
	order.sort_custom(func(a: int, b: int) -> bool: return fitness[a] > fitness[b])
	return order


static func _median(fitness: Array[float], order: Array[int]) -> float:
	var count: int = order.size()
	var middle: int = floori(count / 2.0)
	if count % 2 == 1:
		return fitness[order[middle]]
	return 0.5 * (fitness[order[middle - 1]] + fitness[order[middle]])


static func _mean(fitness: Array[float]) -> float:
	var sum: float = 0.0
	for value: float in fitness:
		sum += value
	return sum / maxf(fitness.size(), 1.0)


## The generation's line: its best, mean and median fitness, how far its best got (steps completed,
## the race time if it finished, its falls and its progress), how many of the population started,
## the wall time and the ticks per second.
static func _summary(generation: int, fitness: Array[float], order: Array[int], best: Result, started: int, seconds: float, total_ticks: int, sigma: float) -> String:
	return "gen %4d  best %7.1f  mean %7.1f  median %7.1f  steps %d/%d  time %7s  falls %d  progress %5.0f m  started %2d/%d  %6.1f s  %6.0f ticks/s  sigma %.3f" % [
		generation, best.fitness, _mean(fitness), _median(fitness, order), best.steps_done, best.steps_total,
		RaceResult.format_time(best.finish_s), best.falls, best.progress_m, started, fitness.size(), seconds, total_ticks / maxf(seconds, 0.001), sigma]


## Writes where a brain came from into its note (NeuralNet.meta), and the names of its inputs and
## outputs, before it is saved.
func _note(brain: NeuralNet, run_name: String, generation: int, result: Result, sigma: float) -> void:
	brain.obs_names = RaceObservation.names()
	var twa_mode: bool = _env_options.actions == LearnedSkipper.ActionMode.TWA
	brain.action_names = LearnedSkipper.TWA_ACTION_NAMES if twa_mode else LearnedSkipper.ACTION_NAMES
	brain.meta = {
		"course": RaceCourses.T1_NAME,
		"run": run_name,
		"generation": generation,
		"fitness": snappedf(result.fitness, 0.001),
		"steps_done": result.steps_done,
		"steps_total": result.steps_total,
		"finish_time_s": snappedf(result.finish_s, 0.01),
		"date": Time.get_datetime_string_from_system(),
		"physics_commit": _text("commit", "unknown"),
		"trainer": "neuroevolution (Game/dev/evolve.gd)",
		"wind_kt": _wind_kt,
		"laps": _env_options.laps,
		"episode_s": _env_options.episode_s,
		"stall_s": _env_options.stall_s,
		"episodes": _episodes,
		"actions": LearnedSkipper.mode_name(_env_options.actions),
		"prestart_s": _env_options.prestart_s,
		"start_behind_m": _env_options.start_behind_m,
		"seed": _integer("seed", 1),
		"sigma": snappedf(sigma, 0.0001),
		"sheet_dead_zone": LearnedSkipper.SHEET_DEAD_ZONE,
		"tack_threshold": LearnedSkipper.TACK_THRESHOLD,
		"decision_ticks": _env_options.decision_ticks,
	}


static func _brain_path(file_name: String) -> String:
	return ProjectSettings.globalize_path(BRAINS_DIR).path_join(file_name + ".json")


# ---------------------------------------------------------------- arguments and paths

func _text(key: String, default: String) -> String:
	return _options.get(key, default)


func _number(key: String, default: float) -> float:
	return _options[key].to_float() if _options.has(key) else default


func _integer(key: String, default: int) -> int:
	return _options[key].to_int() if _options.has(key) else default


## A path in the repository's folder (the one above Game/).
static func _repository_path(relative: String) -> String:
	return ProjectSettings.globalize_path("res://").path_join("..").path_join(relative).simplify_path()


func _read_user_args() -> Dictionary[String, String]:
	var options: Dictionary[String, String] = {}
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--") and arg.contains("="):
			var parts: PackedStringArray = arg.trim_prefix("--").split("=", true, 1)
			options[parts[0]] = parts[1]
	return options
