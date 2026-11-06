extends GutTest
## Spectating a LAN race (Documentation/reports/multiplayer/spectate_6nov.md): a board that retires
## from a race, the camera's choice over a mix of AI boards and other PCs' players on the host
## (RaceRunner) and on a guest (RaceMirror), a player who finished watching the others a few seconds
## later, the menu's Spectate and the board back at the next start, and the lobby's flags as they
## travel. The network itself is checked with game instances (tools/lan_test.sh --spectate=1).

const WINDSURFER_SCENE: String = "res://windsurfer/windsurfer.tscn"
const DT: float = 0.25


## A small race: a start line on z = 0 (boat at x = 30, pin at x = -30), mark 1 300 m upwind, a
## finish line west of the start.
func _course() -> Course:
	var course: Course = Course.new()
	course.add_mark(CourseMark.START_BOAT, Vector2(30.0, 0.0))
	course.add_mark(CourseMark.START_PIN, Vector2(-30.0, 0.0))
	course.add_mark("1", Vector2(0.0, -300.0), CourseMark.Rounding.PORT)
	course.add_mark(CourseMark.FINISH_BOAT, Vector2(-100.0, -70.0))
	course.add_mark(CourseMark.FINISH_PIN, Vector2(-100.0, -30.0))
	assert_eq(course.set_sequence("Start-1-Finish"), "")
	return course


## A race with these boards, started, the gun gone.
func _racing(names: PackedStringArray) -> RaceSim:
	var race: RaceSim = RaceSim.new(_course(), 1, 1.0)
	for board_name: String in names:
		race.add_board(board_name)
	race.start()
	for _k: int in 5:
		race.step(DT)
	assert_eq(race.phase(), RaceSim.Phase.RACING)
	return race


## The race's order set as the host has it (as a guest's copy takes it), so the tests choose it.
func _set_order(race: RaceSim, order: Array) -> void:
	race.apply_state({"order": order})


## A board's node, not in the scene (only its visibility matters here).
func _node() -> WindsurferNode:
	var node: WindsurferNode = (load(WINDSURFER_SCENE) as PackedScene).instantiate()
	autofree(node)
	return node


# ---------------------------------------------------------------- the race: retiring

func test_a_retired_board_is_last_retired_in_the_results_and_the_race_ends_without_it() -> void:
	var race: RaceSim = _racing(PackedStringArray(["Lena", "Max", "Joost"]))
	race.place_board(0, Vector2(-120.0, -50.0), race.steps().size())  # Lena finishes
	race.update_board(1, Vector2(0.0, 5.0))  # Max behind the line, Joost behind him
	race.update_board(2, Vector2(0.0, 10.0))
	race.step(DT)
	race.retire(1)  # Max spectates
	assert_true(race.is_retired(1))
	assert_eq(race.race_order(), [0, 2, 1] as Array[int], "the retired board after every board still racing")
	race.retire(0)
	assert_false(race.is_retired(0), "a finished board keeps its finish")
	race.update_board(1, Vector2(0.0, -100.0))  # over the start line
	race.step(DT)
	assert_eq(race.next_step_index(1), 0, "nothing of a retired board's moves is checked: no start")
	race.place_board(2, Vector2(-120.0, -50.0), race.steps().size())  # Joost finishes
	race.step(DT)
	assert_eq(race.phase(), RaceSim.Phase.FINISHED, "every board finished or retired: the race is over")
	var results: Array[RaceResult] = race.results()
	assert_eq(results[2].name, "Max")
	assert_true(results[2].retired)
	assert_false(results[2].finished)
	assert_string_contains(results[2].to_line(), "RET")
	assert_string_contains(RaceHud.results_table(race), "Max            retired")


func test_a_race_of_retired_boards_only_is_over() -> void:
	var race: RaceSim = _racing(PackedStringArray(["Max"]))
	race.retire(0)
	race.step(DT)
	assert_eq(race.phase(), RaceSim.Phase.FINISHED, "nobody left racing")


func test_the_retirement_travels_to_a_guests_copy_of_the_race() -> void:
	var host: RaceSim = _racing(PackedStringArray(["Host", "Guest"]))
	host.retire(1)
	var guest: RaceSim = RaceSim.new(_course(), 1, 1.0)
	guest.add_board("Host")
	guest.add_board("You")
	guest.apply_state(host.to_state())
	assert_true(guest.is_retired(1), "the guest's own board shows retired on its screen too")
	assert_eq(RaceHud.watch_place_text(guest, 1), "retired")
	# A state from an older build (six values per board) reads as not retired.
	var old_state: Dictionary = host.to_state()
	for values: Variant in old_state["boards"]:
		(values as Array).resize(6)
	var older: RaceSim = RaceSim.new(_course(), 1, 1.0)
	older.add_board("Host")
	older.add_board("You")
	older.apply_state(old_state)
	assert_false(older.is_retired(1))


# ---------------------------------------------------------------- the camera's choice

func test_tab_on_the_host_cycles_ai_boards_and_other_players_in_race_order_and_skips_parked_ones() -> void:
	var runner: RaceRunner = RaceRunner.new()
	autofree(runner)
	# The race's boards: the host's (0), two guests' (1 and 2), two AI boards (3 and 4).
	runner.player = _node()
	runner.remote_players.assign([_node(), _node()])
	runner.opponents.assign([_node(), _node()])
	runner.race = _racing(PackedStringArray(["You", "Hana", "Pieter", "Lena", "Tobias"]))
	_set_order(runner.race, [3, 1, 0, 4, 2])
	# The host has finished and watches (its board off the water); Pieter retired (off the water too).
	runner.player_parked = true
	runner.player.visible = false
	runner.remote_players[1].visible = false
	assert_eq(runner.watch_order(), [3, 1, 4] as Array[int], "every racer on the water, in race order")
	runner._process(0.0)  # no HUD: _running is false, nothing drawn; the choice starts on the leader
	runner.choice.update(runner.watch_order(), 0.0)
	assert_eq(runner.followed_index(), 3, "the leader first: the AI board Lena")
	assert_eq(runner.followed_node(), runner.opponents[0])
	runner.step_followed(1)
	assert_eq(runner.followed_index(), 1, "Tab: the guest Hana's board")
	assert_eq(runner.followed_node(), runner.remote_players[0], "the other PC's puppet")
	runner.step_followed(1)
	assert_eq(runner.followed_index(), 4, "Tab: Tobias")
	runner.step_followed(1)
	assert_eq(runner.followed_index(), 3, "Tab: round the end to the leader")
	runner.step_followed(-1)
	assert_eq(runner.followed_index(), 4, "Shift+Tab: back")
	runner.follow_leader()
	assert_eq(runner.followed_index(), 3, "L: the leader")
	assert_true(runner.choice.follows_leader)


func test_a_spectating_host_numbers_the_other_players_from_the_first_board() -> void:
	var runner: RaceRunner = RaceRunner.new()
	autofree(runner)
	runner.player = _node()
	runner.spectating = true
	runner.remote_players.assign([_node()])
	runner.opponents.assign([_node()])
	assert_eq(runner.board_node(0), runner.remote_players[0], "no host's board in the race: the guest is first")
	assert_eq(runner.board_node(1), runner.opponents[0])
	assert_null(runner.board_node(2))
	assert_eq(runner.player_index(), -1)


func test_tab_on_a_guest_cycles_the_hosts_board_the_ai_and_the_other_guests() -> void:
	var saved_slot: int = Lan.my_slot
	Lan.my_slot = 1
	var net: NetBoards = NetBoards.new()
	autofree(net)
	var mirror: RaceMirror = RaceMirror.new()
	autofree(mirror)
	var own: WindsurferNode = _node()
	var host: WindsurferNode = _node()
	var lena: WindsurferNode = _node()
	var pieter: WindsurferNode = _node()
	net.puppets = {0: host, 100: lena, 2: pieter}
	mirror._net = net
	mirror._own = own
	mirror._ids.assign([0, 1, 100, 2])  # the host's race: the host, this guest, Lena, Pieter
	mirror._my_index = 1
	mirror.race = _racing(PackedStringArray(["Host", "You", "Lena", "Pieter"]))
	_set_order(mirror.race, [2, 1, 0, 3])
	# This guest watches; Pieter's board is off the water (he spectates).
	mirror._set_own_parked(true)
	pieter.visible = false
	assert_false(own.visible, "the own board off the water")
	assert_true(own.stepped_by_runner, "and not stepped")
	assert_eq(mirror.watch_order(), [2, 0] as Array[int], "Lena (AI) and the host's board")
	mirror.choice.update(mirror.watch_order(), 0.0)
	assert_eq(mirror.followed_node(), lena, "the leader")
	assert_eq(mirror.board_id(mirror.followed_index()), 100)
	mirror.step_followed(1)
	assert_eq(mirror.followed_node(), host, "Tab: the host's board")
	assert_eq(mirror.board_id(mirror.followed_index()), 0)
	mirror.step_followed(1)
	assert_eq(mirror.followed_node(), lena, "Tab: round the end")
	Lan.my_slot = saved_slot


# ---------------------------------------------------------------- finished, then watching

func test_a_player_who_finished_watches_the_others_a_few_seconds_later() -> void:
	var runner: RaceRunner = RaceRunner.new()
	autofree(runner)
	runner.player = _node()
	runner.opponents.assign([_node()])
	runner.watch_after_finish = true
	runner.race = _racing(PackedStringArray(["You", "Lena"]))
	runner.race.place_board(0, Vector2(-120.0, -50.0), runner.race.steps().size())
	runner._watch_when_finished()
	assert_false(runner.player_parked, "first the finish on the screen")
	for _k: int in ceili(RaceRunner.WATCH_AFTER_FINISH_S / DT):
		runner.race.step(DT)
	runner._watch_when_finished()
	assert_true(runner.player_parked, "then the board leaves the water")
	assert_false(runner.player.visible)
	assert_eq(runner.watch_order(), [1] as Array[int], "and the camera has the others to watch")
	assert_false(runner.race.is_retired(0), "a finisher is not retired")


func test_a_guest_who_finished_watches_the_others_too() -> void:
	var saved_slot: int = Lan.my_slot
	Lan.my_slot = 1
	var mirror: RaceMirror = RaceMirror.new()
	autofree(mirror)
	var own: WindsurferNode = _node()
	mirror._own = own
	mirror._net = NetBoards.new()
	autofree(mirror._net)
	mirror._ids.assign([0, 1])
	mirror._my_index = 1
	mirror.race = _racing(PackedStringArray(["Host", "You"]))
	mirror.race.place_board(1, Vector2(-120.0, -50.0), mirror.race.steps().size())
	mirror._watch_when_finished()
	assert_false(mirror.own_parked)
	for _k: int in ceili(RaceRunner.WATCH_AFTER_FINISH_S / DT):
		mirror.race.step(DT)
	mirror._watch_when_finished()
	assert_true(mirror.own_parked)
	assert_false(own.visible)
	Lan.my_slot = saved_slot


# ---------------------------------------------------------------- spectate, then race again (a real race)

func test_spectate_retires_the_board_and_the_next_start_takes_it_back_unless_it_stays_a_spectator() -> void:
	var saved_values: SettingsValues = GameSettings.values
	var saved_path: String = GameSettings.path
	GameSettings.values = SettingsValues.new()
	GameSettings.path = ""
	RaceSetup.pending = RaceSetup.race("t1_loop", PackedStringArray(["allrounder", "rookie"]))
	var scene: SailingScene = (load("res://main.tscn") as PackedScene).instantiate()
	add_child_autofree(scene)
	var runner: RaceRunner = scene.get_node("RaceRunner")
	var player: WindsurferNode = scene.get_node("Windsurfer")
	await wait_physics_frames(2)
	assert_false(runner.player_parked)
	runner.spectate_now()
	assert_true(runner.race.is_retired(0), "the board in the race under way retires")
	assert_true(runner.player_parked)
	assert_false(player.visible, "off the water")
	assert_true(scene._is_spectating())
	assert_eq(scene.spectate_entry_text(), "Stay a spectator (also the next races)")
	var time_s: float = player.sim.time_s
	await wait_physics_frames(3)
	await wait_process_frames(2)
	assert_eq(player.sim.time_s, time_s, "not stepped")
	assert_true(runner.opponents.has(scene._shown_board()), "the camera on an AI board")
	scene.step_watched(1)
	assert_true(runner.opponents.has(scene._shown_board()), "Tab: the other AI board")
	# The next start (a race after a race: every board where it is): the player's board is back at its
	# spot behind the line, in the race and not retired.
	runner.restart(true)
	assert_false(runner.player_parked, "back on the water")
	assert_true(player.visible)
	assert_false(runner.race.is_retired(0))
	assert_eq(runner.race.board_name(0), RaceRunner.PLAYER_NAME)
	var spot: Vector3 = player.sim.body.origin_world()
	assert_almost_eq(Vector2(spot.x, spot.z).distance_to(runner.player_spot), 0.0, 0.5, "at its spot behind the line")
	# Spectate again and stay a spectator: the next start leaves the player out.
	scene.spectate_or_race_again()
	scene.spectate_or_race_again()
	assert_true(runner.stays_spectator)
	assert_eq(scene.spectate_entry_text(), "Race again at the next start")
	runner.restart(true)
	assert_true(runner.spectating, "not in this race")
	assert_eq(runner.race.board_count(), 2, "the two AI boards only")
	assert_true(runner.player_parked)
	scene.spectate_or_race_again()
	assert_false(runner.stays_spectator, "Race again: from the next start")
	GameSettings.values = saved_values
	GameSettings.path = saved_path
	get_tree().paused = false


# ---------------------------------------------------------------- the lobby's flags

func test_a_spectators_flags_travel_in_the_lobby() -> void:
	var player: LanPlayer = LanPlayer.new()
	player.name = "Michiel"
	player.spectator = true
	player.parked = true
	var copy: LanPlayer = LanPlayer.from_dict(player.to_dict())
	assert_true(copy.spectator)
	assert_true(copy.parked)
	assert_eq(copy.gear_text(), "spectating", "the lobby shows a spectator without gear")
	var older: LanPlayer = LanPlayer.from_dict({"name": "Max"})
	assert_false(older.spectator)
	assert_false(older.parked)


func test_the_watch_title_names_the_board_and_its_place() -> void:
	assert_eq(RaceHud.watch_title("Hana", "3rd", false), "Spectating Hana, 3rd   ·   Tab: next   L: the leader")
	assert_eq(RaceHud.watch_title("Lena", "1st", true), "Spectating Lena, 1st   ·   the leader   ·   Tab: next board")
