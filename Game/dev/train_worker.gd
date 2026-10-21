extends SceneTree
## A worker of the trainer (AI_FLEET_PLAN.md, D6b, "PPO in Python over the bridge"): one race of a
## curriculum stage, sailed headless, talking to the Python trainer (tools/train/train.py) over a
## TCP socket, one JSON line per message (TrainBridge has the messages). tools/train.sh starts one
## per core; nobody runs this by hand except to evaluate a brain (below).
##
## Arguments after "--":
##   --port=<n>           the trainer's port on this machine (the worker connects to it)
##   --host=127.0.0.1     [127.0.0.1]
##   --worker=<id>        [0] this worker's number, sent in the hello
##   --stage=S1           [S1] the curriculum stage (TrainingDrops: S1 to S6)
##   --boards=<n>         [the stage's] boards per race
##
## Or, without Python: how a brain does on a stage's drops, one line per episode and a summary
## (the morning look, and the stages' "done when" numbers):
##   --evaluate=<brain.json> [--stage=S1] [--episodes=20] [--boards=1] [--reference=allrounder]
##   [--seed=1] [--track=<file.csv>]
## With --reference the same drops are sailed by that scripted character too, for comparison (the
## all-rounder's speed made good is S1's yardstick). --track writes the first episode's track.
##
## Messages from the trainer: {"cmd": "reset", "seed": n}, {"cmd": "step", "actions": [[a, b, c],
## ...], "seed": n}, {"cmd": "close"}. The worker answers each with one line (TrainBridge.reset(),
## step()); first it sends {"hello": {...}}.

const DT: float = 1.0 / 60.0
## The worker gives up if the trainer has said nothing for this long, seconds.
const IDLE_TIMEOUT_S: float = 600.0


var _options: Dictionary[String, String] = {}
var _peer: StreamPeerTCP = null
var _pending: PackedByteArray = PackedByteArray()


func _initialize() -> void:
	_options = _read_user_args()
	if _options.has("evaluate"):
		_evaluate()
		return
	var port: int = _options.get("port", "0").to_int()
	if port <= 0:
		push_error("train_worker: --port=<n> is needed (or --evaluate=<brain.json>).")
		quit(2)
		return
	var bridge: TrainBridge = TrainBridge.new(_options.get("stage", "S1"), _options.get("boards", "0").to_int())
	_peer = StreamPeerTCP.new()
	var host: String = _options.get("host", "127.0.0.1")
	if _peer.connect_to_host(host, port) != OK:
		push_error("train_worker: cannot connect to %s:%d." % [host, port])
		quit(3)
		return
	var waited_ms: int = 0
	while _peer.get_status() == StreamPeerTCP.STATUS_CONNECTING and waited_ms < 10000:
		_peer.poll()
		OS.delay_msec(10)
		waited_ms += 10
	if _peer.get_status() != StreamPeerTCP.STATUS_CONNECTED:
		push_error("train_worker: no connection to %s:%d." % [host, port])
		quit(3)
		return
	_peer.set_no_delay(true)
	var hello: Dictionary = bridge.hello()
	hello["worker"] = _options.get("worker", "0").to_int()
	_send({"hello": hello})
	var idle_ms: int = 0
	while true:
		var line: String = _read_line()
		if line.is_empty():
			if _peer.get_status() != StreamPeerTCP.STATUS_CONNECTED:
				break
			OS.delay_msec(1)
			idle_ms += 1
			if idle_ms > IDLE_TIMEOUT_S * 1000:
				push_error("train_worker: nothing from the trainer for %.0f s; stopping." % IDLE_TIMEOUT_S)
				break
			continue
		idle_ms = 0
		var parsed: Variant = JSON.parse_string(line)
		if not parsed is Dictionary:
			_send({"error": "not a JSON object"})
			continue
		var message: Dictionary = parsed
		var command: String = str(message.get("cmd", ""))
		if command == "reset":
			_send(bridge.reset(int(message.get("seed", 0))))
		elif command == "step":
			_send(bridge.step(message.get("actions", []), int(message.get("seed", 0))))
		elif command == "close":
			break
		else:
			_send({"error": "unknown command '%s'" % command})
	_peer.disconnect_from_host()
	quit(0)


# ---------------------------------------------------------------- the socket

func _send(message: Dictionary) -> void:
	_peer.put_data((JSON.stringify(message) + "\n").to_utf8_buffer())


## The next line from the trainer, without its newline; "" if none is complete yet.
func _read_line() -> String:
	_peer.poll()
	var available: int = _peer.get_available_bytes()
	if available > 0:
		var got: Array = _peer.get_data(available)
		if got[0] == OK:
			_pending.append_array(got[1])
	var newline: int = _pending.find(10)
	if newline < 0:
		return ""
	var line: String = _pending.slice(0, newline).get_string_from_utf8()
	_pending = _pending.slice(newline + 1)
	return line


# ---------------------------------------------------------------- evaluating a brain

## Sails a brain through a stage's drops, one board per episode, and prints how it did; with
## --reference, a scripted character sails the same drops after it.
func _evaluate() -> void:
	var path: String = _options["evaluate"]
	if not path.is_absolute_path() and not path.begins_with("res://"):
		path = _repository_path(path)
	var brain: NeuralNet = NeuralNet.load_file(path)
	if brain == null:
		quit(2)
		return
	var stage_name: String = _options.get("stage", "S1")
	var stage: TrainingDrops.Stage = TrainingDrops.stage_named(stage_name)
	if stage == null:
		push_error("No training stage called '%s' (the stages are %s)." % [stage_name, ", ".join(TrainingDrops.NAMES)])
		quit(2)
		return
	var episodes: int = maxi(_options.get("episodes", "20").to_int(), 1)
	var boards: int = maxi(_options.get("boards", "1").to_int(), 1)
	var seed: int = _options.get("seed", "1").to_int()
	var reference: String = _options.get("reference", "")
	var track_path: String = _options.get("track", "")
	print("%s on %s: %d episode%s of %d board%s%s" % [path.get_file(), stage.describe(), episodes, "" if episodes == 1 else "s",
		boards, "" if boards == 1 else "s", (", against the %s on the same drops" % reference) if not reference.is_empty() else ""])
	var who: Array[String] = ["brain"]
	if not reference.is_empty():
		who.append(reference)
	var summaries: Array[Dictionary] = []
	for sailor: String in who:
		var rows: Array[Dictionary] = []
		for episode: int in episodes:
			var env: RaceEnv = TrainingDrops.make_env(stage, seed + episode, boards)
			if sailor != "brain":
				for i: int in env.board_count():
					env.set_scripted(i, Skippers.make(sailor))
			var track: FileAccess = null
			if episode == 0 and sailor == "brain" and not track_path.is_empty():
				track = FileAccess.open(track_path, FileAccess.WRITE)
				if track != null:
					track.store_line("time_s,x_m,z_m,heading_deg,speed_ms,twa_deg,next_step,twa_out,sheet_out,hold_out,remaining_m")
			_sail_first_episodes(env, brain, track)
			if track != null:
				track.close()
			for i: int in env.board_count():
				var row: Dictionary = env.info(i)
				row["episode"] = episode
				row["board"] = i
				row["course"] = env.course.name
				row["wind_kt"] = env.wind_kt
				rows.append(row)
				print("  %-10s ep %3d board %d  %-34s %4.0f kt  reward %7.2f  progress %6.0f m in %5.1f s (%.2f m/s)  %s  falls %d  manoeuvres %d" % [
					sailor, episode, i, env.course.name.left(34), env.wind_kt, row["total"], row["progress_m"], row["episode_s"],
					row["progress_m"] / maxf(row["episode_s"], 0.1), _outcome(row), row["falls"], row["manoeuvres"]])
		summaries.append(_summary(sailor, rows))
	for summary: Dictionary in summaries:
		print(summary["line"])
	if summaries.size() == 2:
		var ratio: float = summaries[0]["vmg"] / maxf(summaries[1]["vmg"], 0.01)
		print("The brain's speed made good is %.0f %% of the %s's on these drops." % [100.0 * ratio, reference])
	quit(0)


## Every board's first episode: a decision for each twice a second, until all are done.
func _sail_first_episodes(env: RaceEnv, brain: NeuralNet, track: FileAccess) -> void:
	var names: PackedStringArray = RaceObservation.names()
	var guard: int = 0
	while not env.all_done() and guard < 100000:
		guard += 1
		for i: int in env.board_count():
			if env.done(i) or env.board(i).scripted != null:
				continue
			var observation: PackedFloat32Array = env.observe(i)
			var action: PackedFloat32Array = brain.forward(brain.select_inputs(observation, names))
			env.act(i, action)
			if track != null and i == 0:
				var t: Telemetry = env.board(0).sim.telemetry
				track.store_line("%.1f,%.2f,%.2f,%.1f,%.2f,%.1f,%d,%.3f,%.3f,%.3f,%.0f" % [env.time_s, t.position.x, t.position.z, t.heading_deg,
					t.speed_ms, t.twa_deg, env.race.next_step_index(0), action[0], action[1], action[2] if action.size() > 2 else 0.0, env.board(0).remaining_m])
		for t: int in env.decision_ticks:
			env.tick()
			if env.all_done():
				break


static func _outcome(row: Dictionary) -> String:
	if row["finished"]:
		return "goal at %5.1f s" % row["episode_s"]
	if row["out_of_bounds"]:
		return "out of bounds   "
	if row["stalled"]:
		return "stalled         "
	return "time up         "


## One line for a sailor over its episodes: the mean reward, the share that reached the goal (and
## their mean time), the speed made good (progress over time), falls and manoeuvres per episode.
static func _summary(sailor: String, rows: Array[Dictionary]) -> Dictionary:
	var count: float = maxf(rows.size(), 1.0)
	var reward: float = 0.0
	var goals: int = 0
	var goal_time_s: float = 0.0
	var progress_m: float = 0.0
	var time_s: float = 0.0
	var falls: int = 0
	var manoeuvres: int = 0
	for row: Dictionary in rows:
		reward += row["total"]
		progress_m += row["progress_m"]
		time_s += row["episode_s"]
		falls += row["falls"]
		manoeuvres += row["manoeuvres"]
		if row["finished"]:
			goals += 1
			goal_time_s += row["episode_s"]
	var vmg: float = progress_m / maxf(time_s, 0.1)
	# The starts, where the episodes had one: how long after the gun on average, and how many OCS.
	var starts: int = 0
	var start_delay_s: float = 0.0
	var ocs: int = 0
	var with_start: int = 0
	for row: Dictionary in rows:
		if row.get("start_s", -1.0) >= 0.0:
			starts += 1
			start_delay_s += row["start_s"]
		if row.get("ocs", 0) > 0:
			ocs += 1
		if row.get("had_start", false):
			with_start += 1
	var start_text: String = ""
	if with_start > 0:
		start_text = ", started in %d of %d (mean %.1f s after the gun), OCS %d (%.0f %%)" % [starts, with_start, start_delay_s / maxf(starts, 1), ocs, 100.0 * ocs / with_start]
	return {"vmg": vmg, "line": "%s: %d episodes, mean reward %.2f, goal reached in %d (%.0f %%, mean %.1f s), speed made good %.2f m/s, %.2f falls and %.1f manoeuvres per episode%s" % [
		sailor, rows.size(), reward / count, goals, 100.0 * goals / count, goal_time_s / maxf(goals, 1), vmg, falls / count, manoeuvres / count, start_text]}


# ---------------------------------------------------------------- arguments and paths

static func _repository_path(relative: String) -> String:
	return ProjectSettings.globalize_path("res://").path_join("..").path_join(relative).simplify_path()


func _read_user_args() -> Dictionary[String, String]:
	var options: Dictionary[String, String] = {}
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--") and arg.contains("="):
			var parts: PackedStringArray = arg.trim_prefix("--").split("=", true, 1)
			options[parts[0]] = parts[1]
	return options
