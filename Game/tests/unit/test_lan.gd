extends GutTest
## LAN multiplayer's pieces that need no network (Documentation/reports/multiplayer/PLAN.md): the
## buffer of a remote board's states, the guest's estimate of the host's clock, the host's game
## choice and conditions as they travel, and the race and the judge copied to the guest's PC. The
## network itself is checked with two game instances (tools/lan_test.sh).


func _snapshot_at(x: float) -> BoardSnapshot:
	var sim: WindsurferSim = WindsurferSim.create_for(EnvironmentConfig.new(), false, true)
	sim.reset(Vector3(x, 0.0, 0.0), 0.0)
	return BoardSnapshot.capture(sim)


func _x_of(state: BoardSnapshot) -> float:
	return (state.get_field("body", "position") as Vector3).x


func test_the_buffer_shows_a_board_between_its_states_and_holds_at_the_newest() -> void:
	var buffer: StateBuffer = StateBuffer.new()
	assert_null(buffer.state_at(5.0), "nothing to show yet")
	buffer.add(10, _snapshot_at(0.0))
	buffer.add(14, _snapshot_at(4.0))
	buffer.add(12, _snapshot_at(2.0))  # a late one goes in its place
	assert_eq(buffer.size(), 3)
	assert_eq(buffer.newest_tick(), 14)
	assert_almost_eq(_x_of(buffer.state_at(11.0)), 1.0, 0.01, "halfway between ticks 10 and 12")
	assert_almost_eq(_x_of(buffer.state_at(13.5)), 3.5, 0.01)
	assert_almost_eq(_x_of(buffer.state_at(20.0)), 4.0, 0.001, "newer than all: holds the newest")
	assert_almost_eq(_x_of(buffer.state_at(2.0)), 0.0, 0.001, "older than all: the oldest")
	buffer.add(12, _snapshot_at(99.0))
	assert_almost_eq(_x_of(buffer.state_at(12.0)), 2.0, 0.001, "a tick is not taken twice")


func test_the_buffer_forgets_old_states() -> void:
	var buffer: StateBuffer = StateBuffer.new()
	var state: BoardSnapshot = _snapshot_at(0.0)
	for tick: int in 200:
		buffer.add(tick, state)
	assert_true(buffer.size() <= StateBuffer.KEEP_TICKS + 1, "kept %d" % buffer.size())


func test_the_guest_follows_the_hosts_clock_from_its_quickest_messages() -> void:
	var clock: NetClock = NetClock.new()
	assert_false(clock.is_known())
	# The host is 1000 ticks ahead; the messages take 0 to 3 ticks.
	var delays: Array[int] = [2, 0, 3, 1, 2]
	for i: int in delays.size():
		var host_tick: int = 1000 + i * 10
		clock.receive(host_tick, host_tick - 1000 + delays[i], host_tick / 60.0, host_tick / 60.0, host_tick * 0.2, -1.0)
	assert_eq(clock.host_tick_now(100), 1100, "the offset of the quickest message")
	var clocks: Vector3 = clock.clocks_at(1043, 1.0 / 60.0)
	assert_almost_eq(clocks.x, 1043 / 60.0, 1e-6, "the water's time moved on to the tick")
	assert_almost_eq(clocks.z, 1043 * 0.2, 1e-4, "the wind's travel moved on at its pace")
	assert_eq(clock.time_of_day_at(1043, 1.0 / 60.0), -1.0, "no time of day on the open water")
	# An old message does not take the clock back.
	clock.receive(900, 0, 15.0, 15.0, 180.0, -1.0)
	assert_eq(clock.host_tick, 1040)


func test_the_guests_count_of_the_hosts_ticks_goes_up_one_a_tick() -> void:
	var clock: NetClock = NetClock.new()
	clock.receive(500, 100, 0.0, 0.0, 0.0, -1.0)
	assert_eq(clock.host_tick_now(101), 501)
	assert_eq(clock.host_tick_now(101), 501, "asked twice in a tick: the same answer")
	# A quicker message raises the estimate by one: the count stays steady (within the slack).
	clock.receive(502, 101, 0.0, 0.0, 0.0, -1.0)
	assert_eq(clock.host_tick_now(102), 502, "one on from the last, not two")
	# A long frame on this PC: the estimate jumps well ahead, and the count follows it.
	clock.receive(560, 105, 0.0, 0.0, 0.0, -1.0)
	assert_eq(clock.host_tick_now(106), 561)


func test_the_hosts_game_travels_whole() -> void:
	var game: LanGame = LanGame.new()
	game.map = LanGame.Map.LAKE
	game.course_name = "t2_slalom"
	game.skippers = PackedStringArray(["persona:hana", "rookie"])
	game.laps = 2
	game.prestart_s = 45.0
	game.rules = false
	game.lake_time_s = 16.0 * 3600.0
	var host: LanPlayer = LanPlayer.new()
	host.name = "Max"
	host.gear_sail = "some_sail"
	var guest: LanPlayer = LanPlayer.new()
	guest.peer_id = 1234
	guest.slot = 1
	guest.name = "Michiel"
	game.players = [host, guest]
	var back: LanGame = LanGame.from_dict(game.to_dict())
	assert_eq(back.map, LanGame.Map.LAKE)
	assert_eq(back.scene_path(), LanGame.LAKE_SCENE)
	assert_eq(back.course_name, "t2_slalom")
	assert_eq(back.skippers, PackedStringArray(["persona:hana", "rookie"]))
	assert_eq(back.laps, 2)
	assert_eq(back.prestart_s, 45.0)
	assert_false(back.rules)
	assert_eq(back.lake_time_s, 16.0 * 3600.0)
	assert_eq(back.players.size(), 2)
	assert_eq(back.player_in(1).name, "Michiel")
	assert_eq(back.player_in(1).peer_id, 1234)
	assert_eq(back.player_in(0).gear_sail, "some_sail")
	var setup: RaceSetup = back.race_setup()
	assert_eq(setup.course_name, "t2_slalom")
	assert_eq(setup.laps, 2)
	assert_false(setup.rules)
	back.race = false
	assert_null(back.race_setup(), "free sailing has no race")


func test_the_guest_sails_the_hosts_wind_and_waves_but_keeps_its_own_controls() -> void:
	var host: SettingsValues = SettingsValues.new()
	host.wind_speed_kt = 24.0
	host.wind_from_deg = 0.0
	host.gusts_enabled = true
	host.wave_height_scale = 1.5
	host.start_heading_deg = 90.0
	host.control_mode = PlayerController.Mode.BEGINNER
	var game: LanGame = LanGame.new()
	game.conditions_text = LanGame.conditions_of(host)
	var guest: SettingsValues = SettingsValues.new()
	guest.wind_speed_kt = 10.0
	guest.camera_close = true
	guest.gear_sail = "guest_sail"
	game.apply_conditions(guest)
	assert_eq(guest.wind_speed_kt, 24.0, "the host's wind")
	assert_eq(guest.wind_from_deg, 0.0)
	assert_true(guest.gusts_enabled)
	assert_eq(guest.wave_height_scale, 1.5, "the host's waves")
	assert_eq(guest.start_heading_deg, 90.0)
	assert_true(guest.camera_close, "the guest's own camera")
	assert_eq(guest.gear_sail, "guest_sail", "the guest's own gear")
	assert_eq(guest.sea_signature(), host.sea_signature(), "the same sea on both PCs")


func test_names_are_cleaned() -> void:
	assert_eq(LanPlayer.clean_name("  Max\n"), "Max")
	assert_eq(LanPlayer.clean_name(""), "Player")
	assert_eq(LanPlayer.clean_name("A name far too long for the label"), "A name far too l")


func test_the_race_on_the_guests_pc_is_the_hosts() -> void:
	var course: Course = RaceCourses.t1_loop(270.0, Vector2.ZERO)
	var host: RaceSim = RaceSim.new(course, 1, 10.0)
	var guest: RaceSim = RaceSim.new(course, 1, 10.0)
	for race: RaceSim in [host, guest]:
		race.add_board("You")
		race.add_board("Guest")
	var start: RaceStep = host.steps()[0]
	var behind: Vector2 = start.target() - start.in_dir * 30.0
	var over: Vector2 = start.target() + start.in_dir * 10.0
	host.start()
	for i: int in 700:
		# Behind the line until after the gun (10 s, tick 600), then over it.
		var t: float = clampf((i - 620) / 80.0, 0.0, 1.0)
		host.update_board(0, behind.lerp(over, t))
		host.update_board(1, behind)
		host.step(1.0 / 60.0)
	assert_eq(host.next_step_index(0), 1, "the host's race saw board 0 start")
	guest.apply_state(host.to_state())
	assert_eq(guest.phase(), host.phase())
	assert_almost_eq(guest.clock_s(), host.clock_s(), 1e-6)
	assert_eq(guest.next_step_index(0), 1, "the guest's copy too")
	assert_eq(guest.splits_s(0), host.splits_s(0))
	assert_eq(guest.next_step_index(1), 0)
	# Between the host's states the guest's clock runs on, and it judges nothing itself.
	guest.update_board(1, over)
	guest.mirror_step(0.5)
	assert_almost_eq(guest.clock_s(), host.clock_s() + 0.5, 1e-6)
	assert_eq(guest.next_step_index(1), 0, "the guest does not judge")


func test_the_judge_on_the_guests_pc_is_the_hosts() -> void:
	var host: RaceRules = RaceRules.new(3, 0.0)
	host.penalise(2, RaceRules.Why.PORT_GIVES_WAY)
	var guest: RaceRules = RaceRules.new(3, 0.0)
	guest.apply_state(host.to_state())
	assert_eq(guest.penalties(2), 1)
	assert_eq(guest.time_penalty_s(2), RaceRules.TIME_PENALTY_S)
	assert_eq(guest.breach_text(2), host.breach_text(2))
	assert_eq(guest.penalties(0), 0)
