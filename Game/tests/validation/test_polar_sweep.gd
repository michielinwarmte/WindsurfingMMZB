extends GutTest
## The polar sweep of PHYSICS_SPEC.md section 14, Part B: 15 kt of true wind, the pilot
## holding each true wind angle on both tacks, and the settled speeds compared with what
## real freeride kit does (a plausibility range, never a target: plan decision D8). The
## sweep runs once (before_all); every test reads from it. The table is printed and
## written to .sim_output/polar_15kt.md for Documentation/.

const RUN_S: float = 50.0
const WIND_KT: float = 15.0

## True wind angle: [speed ratio to the wind, tolerance as a fraction]. From section 14.
const REFERENCE: Dictionary[float, Array] = {
	40.0: [0.55, 0.0],  # marginal: only positive VMG is required
	45.0: [0.75, 0.20],
	60.0: [1.00, 0.15],
	75.0: [1.20, 0.15],
	90.0: [1.33, 0.15],
	105.0: [1.43, 0.15],
	120.0: [1.47, 0.15],
	135.0: [1.40, 0.20],  # the reference assumes the peak at 120; GPS polars of fin boards peak at 125 to 135, so 135 gets the 45-degree tolerance
	150.0: [0.93, 0.30],
	165.0: [0.55, 0.30],
}
const ANGLES: Array[float] = [30.0, 40.0, 45.0, 60.0, 75.0, 90.0, 105.0, 120.0, 135.0, 150.0, 165.0]

var _runs: Dictionary[float, ValidationRun] = {}


func before_all() -> void:
	var started: int = Time.get_ticks_msec()
	for angle: float in ANGLES:
		for sign: float in [1.0, -1.0]:
			_runs[sign * angle] = ValidationRun.sail(sign * angle, RUN_S, WIND_KT, angle > 30.0)
	gut.p("polar sweep: %d runs of %.0f s in %.1f s" % [_runs.size(), RUN_S, (Time.get_ticks_msec() - started) / 1000.0])
	_print_and_save_table()


func _wind_ms() -> float:
	return WIND_KT * SimMath.KNOT_MS


func _run(signed_twa: float) -> ValidationRun:
	return _runs[signed_twa]


## The mean of both tacks' settled speeds at an angle.
func _speed(angle: float) -> float:
	return 0.5 * (_run(angle).settled_speed_ms() + _run(-angle).settled_speed_ms())


func test_no_run_fell_or_blew_up() -> void:
	for signed_twa: float in _runs:
		var run: ValidationRun = _runs[signed_twa]
		assert_false(run.nan, "no NaN at TWA %.0f" % signed_twa)
		if absf(signed_twa) > 30.0:
			assert_false(run.fell, "no fall at TWA %.0f" % signed_twa)


func test_speeds_settle() -> void:
	for signed_twa: float in _runs:
		var run: ValidationRun = _runs[signed_twa]
		if absf(signed_twa) <= 40.0:
			continue
		var spread: float = run.settled_spread(run.speed_ms) / maxf(run.settled_speed_ms(), 0.1)
		assert_lt(spread, 0.10, "speed steady within 10 %% over the last 10 s at TWA %.0f (spread %.1f %%)" % [signed_twa, spread * 100.0])


func test_speeds_are_in_the_real_world_range() -> void:
	for angle: float in REFERENCE:
		var target: float = REFERENCE[angle][0] * _wind_ms()
		var tolerance: float = REFERENCE[angle][1]
		for sign: float in [1.0, -1.0]:
			var run: ValidationRun = _run(sign * angle)
			if tolerance == 0.0:
				assert_gt(run.settled(run.vmg_ms), 0.0, "TWA %.0f: positive VMG" % (sign * angle))
			else:
				assert_between(run.settled_speed_ms(), target * (1.0 - tolerance), target * (1.0 + tolerance),
					"TWA %.0f: %.2f m/s against %.2f +/- %.0f %%" % [sign * angle, run.settled_speed_ms(), target, tolerance * 100.0])


func test_shape_of_the_polar() -> void:
	var fastest_angle: float = 0.0
	var fastest: float = 0.0
	for angle: float in REFERENCE:
		if _speed(angle) > fastest:
			fastest = _speed(angle)
			fastest_angle = angle
	assert_between(fastest_angle, 105.0, 135.0, "the fastest point of sail is a broad reach (found %.0f)" % fastest_angle)
	var previous: float = 0.0
	for angle: float in REFERENCE:
		if angle > fastest_angle:
			break
		assert_gt(_speed(angle), previous - 0.05, "speed rises from 40 degrees to the fastest angle (%.0f: %.2f after %.2f)" % [angle, _speed(angle), previous])
		previous = _speed(angle)
	# Section 14 reasoned 85 %; GPS polars of freeride fin boards (The Windsurf Loop, "Fun
	# With Polar Plots") show the beam reach at 80 to 85 % of the broad-reach maximum.
	assert_gt(_speed(90.0), 0.80 * fastest, "the beam reach makes at least 80 %% of the top speed")
	assert_lt(_speed(165.0), _speed(135.0), "the run is slower than the broad reach")
	assert_gt(fastest, _wind_ms(), "faster than the wind when planing")


func test_top_speed() -> void:
	var fastest: float = 0.0
	for angle: float in REFERENCE:
		fastest = maxf(fastest, _speed(angle))
	assert_between(fastest, 11.32 * 0.85, 11.32 * 1.15, "top speed %.2f m/s (%.1f km/h) against 11.3 +/- 15 %%" % [fastest, fastest * 3.6])


func test_both_tacks_are_mirror_images() -> void:
	for angle: float in [45.0, 90.0, 120.0]:
		var starboard: ValidationRun = _run(angle)
		var port: ValidationRun = _run(-angle)
		var speed: float = starboard.settled_speed_ms()
		assert_almost_eq(port.settled_speed_ms(), speed, 0.02 * speed, "speed at +/-%.0f within 2 %%" % angle)
		assert_almost_eq(absf(port.settled(port.heel_deg)), absf(starboard.settled(starboard.heel_deg)), 0.02 * absf(starboard.settled(starboard.heel_deg)) + 0.2, "heel at +/-%.0f" % angle)
		assert_almost_eq(absf(port.settled(port.sail_angle_deg)), absf(starboard.settled(starboard.sail_angle_deg)), 0.02 * absf(starboard.settled(starboard.sail_angle_deg)) + 0.2, "sail angle at +/-%.0f" % angle)
		assert_almost_eq(absf(port.settled(port.leeway_deg)), absf(starboard.settled(starboard.leeway_deg)), 0.02 * absf(starboard.settled(starboard.leeway_deg)) + 0.2, "leeway at +/-%.0f" % angle)


func test_upwind_vmg_at_45_degrees() -> void:
	var starboard: float = _run(45.0).settled(_run(45.0).vmg_ms)
	var port: float = _run(-45.0).settled(_run(-45.0).vmg_ms)
	assert_gt(starboard, 3.0, "VMG on starboard tack %.2f m/s (target 4.1)" % starboard)
	assert_gt(port, 3.0, "VMG on port tack %.2f m/s" % port)
	assert_almost_eq(port, starboard, 0.02 * starboard + 0.02, "the tacks agree")


func test_no_go_zone() -> void:
	for sign: float in [1.0, -1.0]:
		var at_30: ValidationRun = _run(sign * 30.0)
		var speed: float = at_30.settled_speed_ms()
		var vmg: float = at_30.settled(at_30.vmg_ms)
		assert_true(speed < 1.5 or vmg < 0.5, "no lasting progress at TWA %.0f (speed %.2f, VMG %.2f)" % [sign * 30.0, speed, vmg])
		var at_40: ValidationRun = _run(sign * 40.0)
		assert_gt(at_40.settled_speed_ms(), 2.6, "still sailing at TWA %.0f (%.2f m/s)" % [sign * 40.0, at_40.settled_speed_ms()])
		assert_gt(at_40.settled(at_40.vmg_ms), 0.0, "with positive VMG at TWA %.0f" % (sign * 40.0))


func test_planing_onset_and_fully_planing() -> void:
	# On a beam reach from rest the dynamic lift carries half the weight between 8 and
	# 10 kn of board speed; at 25 km/h the board is well clear of the water.
	for sign: float in [1.0, -1.0]:
		var run: ValidationRun = _run(sign * 90.0)
		var onset_s: float = run.first_time_above(run.planing_ratio, 0.5)
		assert_gt(onset_s, 0.0, "the board planes at TWA %.0f" % (sign * 90.0))
		var speed_at_onset: float = run.value_at(run.speed_ms, onset_s)
		# Real boards (PHYSICS_SPEC.md section 14, Part B; DECISION FOR MICHIEL, Session 39):
		# GPS tracks put the planing threshold of slalom and freeride boards at 9 to 10 kn
		# of board speed (seabreeze.com.au forum, "GPS and speed talk: Planning": a 75 cm
		# wide 122 L iSonic at 9 to 10 kn, a 94 L board at about 10; "most boards get
		# planing at roughly the same board speed"), and a planing board drops off the
		# plane below about 8 kn (The Windsurf Loop, "Maximum speed", 2015), which bounds
		# getting onto it from below: 8 to 10 kn, 4.12 to 5.14 m/s. The old band, 14 to
		# 17 km/h, came from the legacy game's documents (PHYSICS_DESIGN.md:384-392,
		# Legacy/README.md:214), not from measurements.
		assert_between(speed_at_onset, 4.12, 5.14, "planing onset at %.2f m/s = %.1f kn (8 to 10)" % [speed_at_onset, speed_at_onset / SimMath.KNOT_MS])
		var fast_s: float = run.first_time_above(run.speed_ms, 6.94)
		assert_gt(fast_s, 0.0, "reaches 25 km/h")
		assert_lt(run.value_at(run.submersion, fast_s + 2.0), 0.25, "submersion below 25 %% two seconds after reaching 25 km/h (%.2f)" % run.value_at(run.submersion, fast_s + 2.0))
		assert_lt(run.settled(run.submersion), 0.25, "and when settled (%.2f)" % run.settled(run.submersion))


func test_acceleration_from_rest() -> void:
	var run: ValidationRun = _run(90.0)
	var to_15_kmh: float = run.first_time_above(run.speed_ms, 4.17)
	assert_between(to_15_kmh, 0.0, 10.0, "15 km/h within 10 s (%.1f s)" % to_15_kmh)
	var to_90_percent: float = run.first_time_above(run.speed_ms, 0.9 * run.settled_speed_ms())
	assert_between(to_90_percent, 0.0, 25.0, "90 %% of the settled speed within 25 s (%.1f s)" % to_90_percent)


func test_stable_at_speed_on_the_broad_reach() -> void:
	# Above 20 kt of boat speed, over the last 10 s: no porpoising, no trampoline.
	var run: ValidationRun = _run(120.0)
	assert_gt(run.settled_speed_ms(), 10.3, "above 20 kt at TWA 120 (%.2f m/s)" % run.settled_speed_ms())
	assert_lt(run.settled_spread(run.pitch_deg), 2.0, "pitch peak to peak below 2 degrees (%.2f)" % run.settled_spread(run.pitch_deg))
	assert_lt(run.settled_spread(run.height_m), 0.05, "heave peak to peak below 5 cm (%.3f m)" % run.settled_spread(run.height_m))
	assert_lt(run.settled_spread(run.submersion), 0.10, "submersion within a 0.10 band (%.3f)" % run.settled_spread(run.submersion))
	assert_lt(run.settled_max(run.submersion), 0.35, "and never above 0.35")
	# A sailor hanging in the harness presses the mast foot down (Session 37): the board
	# runs flat at speed, as the fast ones do, so the floor is half a degree.
	assert_between(run.settled(run.pitch_deg), 0.5, 6.0, "trim at speed between 0.5 and 6 degrees bow up (%.1f)" % run.settled(run.pitch_deg))


func test_force_sanity_on_the_beam_reach() -> void:
	var t: Telemetry = _run(90.0).telemetry
	var sail_force: float = sqrt(t.sail_lift_n * t.sail_lift_n + t.sail_drag_n * t.sail_drag_n)
	assert_between(sail_force, 300.0, 800.0, "total sail force %.0f N" % sail_force)
	# With the harness lift helping the balance the sailor holds a little more sail than
	# the one-body model did; the fin carries it (Session 37).
	assert_between(t.fin_lift_n, 100.0, 650.0, "fin side force %.0f N" % t.fin_lift_n)
	assert_between(absf(t.leeway_deg), 1.0, 8.0, "leeway %.1f degrees" % t.leeway_deg)


func _print_and_save_table() -> void:
	var lines: PackedStringArray = PackedStringArray()
	lines.append("# Polar diagram, %.0f kt of true wind at the sail (flat water, 75 kg sailor, 120 L board, 6.5 m2 sail, 38 cm fin)" % WIND_KT)
	lines.append("")
	lines.append("Generated by `tools/test.sh validation` (test_polar_sweep.gd): the settled boat speed (mean of the last 10 s of a %.0f s run from rest) with the pilot holding each true wind angle, the mean of both tacks. The reference is the real-world plausibility range of PHYSICS_SPEC.md section 14, Part B, not a target (plan decision D8)." % RUN_S)
	lines.append("")
	lines.append("| TWA (deg) | Speed (kt) | Speed (km/h) | Speed (m/s) | Ratio to wind | Reference (kt) | VMG (kt) | Planing | Heel (deg) | Leeway (deg) | Sail angle (deg) |")
	lines.append("|---|---|---|---|---|---|---|---|---|---|---|")
	var chart: PackedStringArray = PackedStringArray()
	for angle: float in ANGLES:
		var starboard: ValidationRun = _run(angle)
		var port: ValidationRun = _run(-angle)
		var speed: float = 0.5 * (starboard.settled_speed_ms() + port.settled_speed_ms())
		var vmg: float = 0.5 * (starboard.settled(starboard.vmg_ms) + port.settled(port.vmg_ms))
		var reference: String = "-"
		if REFERENCE.has(angle) and REFERENCE[angle][1] > 0.0:
			var target_kt: float = REFERENCE[angle][0] * WIND_KT
			reference = "%.1f +/- %.0f %%" % [target_kt, REFERENCE[angle][1] * 100.0]
		elif REFERENCE.has(angle):
			reference = "6 to 10, VMG > 0"
		lines.append("| %.0f | %.1f | %.1f | %.2f | %.2f | %s | %.1f | %.2f | %.1f | %.1f | %.0f |" % [
			angle, speed / SimMath.KNOT_MS, speed * 3.6, speed, speed / _wind_ms(), reference, vmg / SimMath.KNOT_MS,
			starboard.settled(starboard.planing_ratio), absf(starboard.settled(starboard.heel_deg)),
			absf(starboard.settled(starboard.leeway_deg)), absf(starboard.settled(starboard.sail_angle_deg))])
		var bar: String = ""
		for i: int in int(speed / SimMath.KNOT_MS * 2.0):
			bar += "#"
		chart.append("%4.0f deg |%-50s %.1f kt" % [angle, bar, speed / SimMath.KNOT_MS])
	lines.append("")
	lines.append("```")
	lines.append("boat speed, 2 characters per knot; the wind is %.0f kt" % WIND_KT)
	for line: String in chart:
		lines.append(line)
	lines.append("```")
	var text: String = "\n".join(lines) + "\n"
	print(text)
	var directory: String = ProjectSettings.globalize_path("res://").path_join("../.sim_output")
	DirAccess.make_dir_recursive_absolute(directory)
	var file: FileAccess = FileAccess.open(directory.path_join("polar_15kt.md"), FileAccess.WRITE)
	if file != null:
		file.store_string(text)
		file.close()
