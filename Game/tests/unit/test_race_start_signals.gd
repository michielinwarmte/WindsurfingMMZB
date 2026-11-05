extends GutTest
## The start's signals (ROADMAP SO3, RaceStartSignals): which horn, beep or gun is due as a race's
## countdown runs. The sounds themselves are in test_audio.gd; how they sound, the team checks by ear.

const TICK_S: float = 1.0 / 60.0


## Runs a countdown tick by tick as RaceSim's clock does (from -countdown_s to `until_s`) and
## returns every signal with the clock it was due at: [[clock_s, kind], ...].
func _run(signals: RaceStartSignals, countdown_s: float, until_s: float) -> Array[Array]:
	var heard: Array[Array] = []
	var clock_s: float = -countdown_s
	while clock_s <= until_s:
		for kind: RaceStartSignals.Kind in signals.update(true, clock_s):
			heard.append([clock_s, kind])
		clock_s += TICK_S
	return heard


func test_a_one_minute_countdown_has_the_horns_the_beeps_and_the_gun_each_once_on_time() -> void:
	var heard: Array[Array] = _run(RaceStartSignals.new(60.0), 60.0, 5.0)
	var expected_s: PackedFloat64Array = [-60.0, -30.0, -10.0, -5.0, -4.0, -3.0, -2.0, -1.0, 0.0]
	var expected_kinds: Array[RaceStartSignals.Kind] = [RaceStartSignals.Kind.LONG_HORN, RaceStartSignals.Kind.SHORT_HORN,
		RaceStartSignals.Kind.BEEP, RaceStartSignals.Kind.BEEP, RaceStartSignals.Kind.BEEP, RaceStartSignals.Kind.BEEP,
		RaceStartSignals.Kind.BEEP, RaceStartSignals.Kind.BEEP, RaceStartSignals.Kind.GUN]
	assert_eq(heard.size(), expected_s.size(), "nine signals, each once")
	for i: int in mini(heard.size(), expected_s.size()):
		assert_eq(heard[i][1], expected_kinds[i], "signal %d" % i)
		assert_between(float(heard[i][0]) - expected_s[i], -1e-6, TICK_S, "on the tick of its moment, not before")


func test_a_three_minute_countdown_has_a_long_horn_at_every_minute() -> void:
	assert_eq(RaceStartSignals.new(180.0).times_s(), PackedFloat64Array([180.0, 120.0, 60.0, 30.0, 10.0, 5.0, 4.0, 3.0, 2.0, 1.0, 0.0]))
	assert_eq(RaceStartSignals.new(30.0).times_s(), PackedFloat64Array([30.0, 10.0, 5.0, 4.0, 3.0, 2.0, 1.0, 0.0]), "30 s: the short horn starts it")
	assert_eq(RaceStartSignals.new(0.0).times_s(), PackedFloat64Array([0.0]), "no countdown: the gun alone")


func test_a_countdown_that_is_no_whole_minute_starts_with_a_long_horn() -> void:
	var heard: Array[Array] = _run(RaceStartSignals.new(45.0), 45.0, -44.0)
	assert_eq(heard.size(), 1)
	assert_eq(heard[0][1], RaceStartSignals.Kind.LONG_HORN, "the countdown's first moment")


func test_nothing_sounds_before_the_countdown() -> void:
	var signals: RaceStartSignals = RaceStartSignals.new(60.0)
	assert_eq(signals.update(false, 0.0).size(), 0, "free sailing before the countdown: silence")
	assert_eq(signals.update(true, -60.0).size(), 1, "the long horn when it starts")


## A LAN guest's clock is set to the host's ten times a second and may step back a little: a signal
## never sounds twice. A guest that comes in late does not hear the signals it missed all at once.
func test_a_clock_that_jumps_back_or_starts_late_plays_no_signal_twice_or_late() -> void:
	var signals: RaceStartSignals = RaceStartSignals.new(60.0)
	assert_eq(signals.update(true, -29.99).size(), 1, "the short horn (the long one was missed: too late)")
	assert_eq(signals.update(true, -30.02).size(), 0, "the clock steps back")
	assert_eq(signals.update(true, -29.98).size(), 0, "and on again: not a second time")
	var late: RaceStartSignals = RaceStartSignals.new(60.0)
	assert_eq(late.update(true, -20.0).size(), 0, "joined at 20 s: the horns are not played late")
	assert_eq(late.update(true, -9.99), [RaceStartSignals.Kind.BEEP] as Array[RaceStartSignals.Kind], "the 10 s beep is")
