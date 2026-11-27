extends GutTest
## The TV director set to the real stream (TvStreamDirector, TvDirectorConfig, TvFraming; Max, 27
## November 2026: "the drone shots trained on real data"): the picture's maths (a picture set by the
## sail's and the horizon's place, the camera's distance and height worked out from them), the takes'
## lengths drawn from the measured spread, the four phases, the picture choice per phase, the start's
## and the marks' timing, and the lead's measured drone positions coming out of the framing. How it
## looks is checked on the screen (tools/screenshot.sh) and how close it comes to the stream over whole
## races by the check (tools/tv_check.sh).

var config: TvDirectorConfig = load(TvCamera.STREAM_CONFIG) as TvDirectorConfig


# ---------------------------------------------------------------- the picture's maths

## A camera at a distance and height from a board heading north, looking at it with a pitch: its
## transform (a board at the origin, the camera to its south).
func _camera_at(distance_m: float, height_m: float, pitch_rad: float) -> Transform3D:
	var eye: Vector3 = Vector3(0.0, height_m, distance_m)
	return Transform3D.IDENTITY.translated(eye).looking_at(TvFraming.aim_point(eye, Vector3.ZERO, pitch_rad), Vector3.UP)


func test_the_horizon_sits_where_the_pitch_puts_it() -> void:
	assert_almost_eq(TvFraming.pitch_for_horizon(47.0, 0.5), 0.0, 1e-9, "a level camera: the horizon in the middle")
	assert_gt(TvFraming.pitch_for_horizon(47.0, 0.25), 0.0, "the horizon high in the picture: the camera looks down")
	assert_lt(TvFraming.pitch_for_horizon(47.0, 0.7), 0.0, "the horizon low: the camera looks up")
	for horizon: float in [0.1, 0.25, 0.4, 0.6]:
		var pitch: float = TvFraming.pitch_for_horizon(40.0, horizon)
		var seen: Vector3 = TvFraming.measure(_camera_at(30.0, 8.0, pitch), 40.0, Vector3.ZERO, Vector3.UP * 4.0)
		assert_almost_eq(seen.y, horizon, 1e-4, "the horizon at %.2f" % horizon)


func test_a_drone_placed_for_a_picture_shows_that_picture() -> void:
	# The stream's race pictures (sail, horizon, where the sail sits) with the game's lens and rigs.
	for case: Vector4 in [Vector4(0.15, 0.25, 0.55, 3.5), Vector4(0.10, 0.35, 0.60, 4.5), Vector4(0.20, 0.15, 0.53, 5.26), Vector4(0.05, 0.25, 0.40, 4.0)]:
		var place: Vector3 = TvFraming.drone_place(47.0, case.w, case.x, case.y, case.z, 0.5)
		var seen: Vector3 = TvFraming.measure(_camera_at(place.x, place.y, place.z), 47.0, Vector3.ZERO, Vector3.UP * case.w)
		assert_almost_eq(seen.x, case.x, 0.002, "the sail's share for %s" % case)
		assert_almost_eq(seen.y, case.y, 0.001, "the horizon for %s" % case)
		assert_almost_eq((seen.z - seen.x * 0.5), case.z, 0.01, "the sail's middle where it was asked for %s" % case)


func test_a_sail_leaning_towards_the_camera_is_framed_as_it_stands() -> void:
	# A raked sail whose top leans 1.5 m towards the camera: placed for it, the picture is still right.
	var place: Vector3 = TvFraming.drone_place(47.0, 3.8, 0.15, 0.25, 0.55, 0.5, 1.5)
	var seen: Vector3 = TvFraming.measure(_camera_at(place.x, place.y, place.z), 47.0, Vector3.ZERO, Vector3(0.0, 3.8, 1.5))
	assert_almost_eq(seen.x, 0.15, 0.003, "the leaning sail's share")
	var upright: Vector3 = TvFraming.drone_place(47.0, 3.8, 0.15, 0.25, 0.55, 0.5)
	assert_ne(snappedf(place.x, 0.01), snappedf(upright.x, 0.01), "the lean moves the drone")


func test_a_lower_limit_keeps_the_drone_off_the_water_and_the_sail_true() -> void:
	# A picture that would put the drone under 6 m: it stays at 6 m and the sail keeps its share.
	var place: Vector3 = TvFraming.drone_place(47.0, 4.0, 0.25, 0.45, 0.5, 6.0)
	assert_almost_eq(place.y, 6.0, 1e-6)
	var seen: Vector3 = TvFraming.measure(_camera_at(place.x, place.y, place.z), 47.0, Vector3.ZERO, Vector3.UP * 4.0)
	assert_almost_eq(seen.x, 0.25, 0.003, "the sail's share holds")
	assert_almost_eq(seen.y, 0.45, 0.001, "the horizon holds")


func test_the_beach_cams_zoom_gives_the_picture_from_where_it_stands() -> void:
	# The long lens 120 m and 600 m away: the zoom makes the sail its share; the horizon sits where asked.
	for distance_m: float in [120.0, 600.0]:
		var lens: Vector3 = TvFraming.lens_place(distance_m, 4.5, 0.55, 0.25, 0.5, 1.5, 8.0, 0.3, 30.0)
		assert_lt(lens.x, 10.0, "a long lens")
		var seen: Vector3 = TvFraming.measure(_camera_at(distance_m, lens.y, lens.z), lens.x, Vector3.ZERO, Vector3.UP * 4.5)
		assert_almost_eq(seen.x, 0.55, 0.01, "the sail fills 55 %% at %.0f m" % distance_m)
		assert_almost_eq(seen.y, 0.25, 0.002, "the horizon at %.0f m" % distance_m)
		assert_between(lens.y, 1.5, 8.0, "at water level or on a dune")


func test_the_beach_cam_wide_puts_the_sea_in_a_thin_band() -> void:
	# The wide picture before the start: sail 3 %, horizon at 70 % from the top. From water level the
	# boards sit near the horizon, low in the picture.
	var lens: Vector3 = TvFraming.lens_place(450.0, 4.5, 0.03, 0.70, 0.5, 1.5, 8.0, 0.3, 30.0)
	var seen: Vector3 = TvFraming.measure(_camera_at(450.0, lens.y, lens.z), lens.x, Vector3.ZERO, Vector3.UP * 4.5)
	assert_almost_eq(seen.y, 0.70, 0.002, "the horizon low")
	assert_almost_eq(seen.x, 0.03, 0.003, "a small sail")
	assert_almost_eq(lens.y, 1.5, 1e-6, "at water level")
	assert_gt(seen.z, 0.65, "the board on the horizon line, the sea below it a thin band")


func test_the_shares_are_of_the_pictures_height_in_any_window() -> void:
	# The game's camera keeps its vertical view (KEEP_HEIGHT): a 16:9 window and Max's 3137 x 1263 put
	# the sail's top and foot at the same heights of the picture.
	var camera: Transform3D = _camera_at(25.0, 8.0, TvFraming.pitch_for_horizon(47.0, 0.25))
	var heights: PackedFloat32Array = PackedFloat32Array()
	for aspect: float in [16.0 / 9.0, 3137.0 / 1263.0, 4.0 / 3.0]:
		var projection: Projection = Projection.create_perspective(47.0, aspect, 0.1, 1000.0)
		var to_camera: Transform3D = camera.affine_inverse()
		var top: Vector4 = projection * Vector4((to_camera * Vector3(0.0, 4.0, 0.0)).x, (to_camera * Vector3(0.0, 4.0, 0.0)).y, (to_camera * Vector3(0.0, 4.0, 0.0)).z, 1.0)
		var foot: Vector4 = projection * Vector4((to_camera * Vector3.ZERO).x, (to_camera * Vector3.ZERO).y, (to_camera * Vector3.ZERO).z, 1.0)
		heights.append((top.y / top.w - foot.y / foot.w) * 0.5)
	assert_almost_eq(heights[1], heights[0], 1e-6, "the wide window shows the sail as tall")
	assert_almost_eq(heights[2], heights[0], 1e-6)
	var seen: Vector3 = TvFraming.measure(camera, 47.0, Vector3.ZERO, Vector3.UP * 4.0)
	assert_almost_eq(seen.x, heights[0], 1e-5, "the check measures what the screen shows")


func test_the_wheel_zooms_the_sail_and_keeps_the_horizon() -> void:
	var near: Vector3 = TvFraming.drone_place(47.0, 4.0, 0.15, 0.25, 0.55, 0.5)
	var far: Vector3 = TvFraming.drone_place(47.0, 4.0, 0.15 / 2.0, 0.25, 0.55, 0.5)
	assert_almost_eq(far.x / near.x, 2.0, 0.1, "half the sail: twice as far")
	assert_almost_eq(far.z, near.z, 1e-9, "the horizon stays where it was")


func test_the_angle_round_the_board_and_the_place_round_it() -> void:
	var north: Vector3 = Vector3.FORWARD
	assert_almost_eq(TvFraming.angle_round(north, Vector3.ZERO, Vector3(0.0, 5.0, 20.0)), 0.0, 1e-4, "dead behind")
	assert_almost_eq(TvFraming.angle_round(north, Vector3.ZERO, Vector3(20.0, 5.0, 0.0)), 90.0, 1e-4, "abeam")
	assert_almost_eq(TvFraming.angle_round(north, Vector3.ZERO, Vector3(0.0, 5.0, -20.0)), 180.0, 1e-4, "dead ahead")
	var starboard: Vector3 = TvFraming.offset_round(north, 90.0, 1.0, 30.0, 8.0)
	assert_almost_eq(starboard.x, 30.0, 1e-4, "abeam to starboard (east for a board heading north)")
	assert_almost_eq(starboard.y, 8.0, 1e-4)
	for angle: float in [45.0, 90.0, 135.0]:
		var offset: Vector3 = TvFraming.offset_round(north, angle, -1.0, 25.0, 6.0)
		assert_almost_eq(TvFraming.angle_round(north, Vector3.ZERO, offset), angle, 1e-3, "at %.0f round" % angle)


func test_a_take_length_drawn_from_the_spread_has_the_streams_quarters() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 11
	var spread: Vector3 = config.race.take_s
	var lengths: PackedFloat32Array = PackedFloat32Array()
	for i: int in 6000:
		lengths.append(TvFraming.from_spread(spread, rng.randfn(), true, config.race.shortest_s, config.race.longest_s))
	lengths.sort()
	assert_almost_eq(lengths[1500], spread.x, spread.x * 0.06, "a quarter under the first quarter")
	assert_almost_eq(lengths[3000], spread.y, spread.y * 0.05, "half under the middle")
	assert_almost_eq(lengths[4500], spread.z, spread.z * 0.06, "a quarter over the third quarter")
	assert_gte(lengths[0], config.race.shortest_s)
	assert_lte(lengths[5999], config.race.longest_s)
	assert_gt(lengths[5940], spread.z * 1.6, "a few long takes, as the stream has")


func test_the_old_even_spread_is_gone() -> void:
	# The 12 November director drew every shot evenly between 7 and 12 s; the stream's middle half runs
	# from 5 to 12 s and a quarter of its takes are shorter than 5 s.
	assert_lt(config.race.take_s.x, 7.0)
	assert_gt(config.race.longest_s, 12.0)


# ---------------------------------------------------------------- the phases

func test_the_four_phases_by_the_race_clock() -> void:
	var from_s: float = config.start_from_s
	var until_s: float = config.start_until_s
	assert_eq(from_s, -10.0, "the start begins 10 s before the gun")
	assert_eq(until_s, 12.0, "and ends 12 s after it")
	assert_eq(TvStreamDirector.heat_phase(false, -60.0, false, from_s, until_s), TvStreamDirector.Phase.PRE_START, "sailing free before the countdown")
	assert_eq(TvStreamDirector.heat_phase(true, -40.0, false, from_s, until_s), TvStreamDirector.Phase.PRE_START, "the countdown")
	assert_eq(TvStreamDirector.heat_phase(true, -10.0, false, from_s, until_s), TvStreamDirector.Phase.START, "the final run at the line")
	assert_eq(TvStreamDirector.heat_phase(true, 0.0, false, from_s, until_s), TvStreamDirector.Phase.START, "the gun")
	assert_eq(TvStreamDirector.heat_phase(true, 12.0, false, from_s, until_s), TvStreamDirector.Phase.START)
	assert_eq(TvStreamDirector.heat_phase(true, 12.1, false, from_s, until_s), TvStreamDirector.Phase.RACE, "strung out on the first reach")
	assert_eq(TvStreamDirector.heat_phase(true, 400.0, true, from_s, until_s), TvStreamDirector.Phase.AFTER_RACE, "the race has ended")
	assert_eq(TvStreamDirector.PHASE_NAMES[TvStreamDirector.Phase.AFTER_RACE], "after_race", "the readers' word")


# ---------------------------------------------------------------- the pictures

func test_the_stream_never_looks_straight_down_nor_circles() -> void:
	for mix: TvPhaseMix in [config.pre_start, config.race, config.after_race]:
		for picture: TvPicture in mix.pictures:
			assert_ne(picture.shot, TvCamera.Shot.OVERHEAD, "no overhead drone in the mix")
			assert_ne(picture.shot, TvCamera.Shot.ORBIT, "no helicopter in the mix")
	for picture: TvPicture in config.mark_pictures:
		assert_ne(picture.shot, TvCamera.Shot.OVERHEAD)
	var director: TvStreamDirector = TvStreamDirector.new(null, config, RandomNumberGenerator.new())
	assert_null(director.hand_picture(TvCamera.Shot.ORBIT), "the helicopter by hand is the 12 November one (key 5)")
	assert_null(director.hand_picture(TvCamera.Shot.OVERHEAD), "and the overhead drone (key 9)")
	assert_eq(director.hand_picture(TvCamera.Shot.COMMITTEE), config.start_line_drone, "key 6: the view down the start line")
	assert_eq(director.hand_picture(TvCamera.Shot.CHASE).on, "front", "key 7: the chase drone on the board")
	assert_not_null(config.hand_shots, "the helicopter's and the overhead drone's numbers")


func test_every_drone_has_the_wide_lens_and_every_picture_a_sane_framing() -> void:
	var all: Array[TvPicture] = []
	for mix: TvPhaseMix in [config.pre_start, config.race, config.after_race]:
		all.append_array(mix.pictures)
	all.append_array(config.mark_pictures)
	all.append_array(config.start_runners)
	all.append_array([config.start_beach, config.start_line_drone, config.finish_picture, config.after_winner])
	for picture: TvPicture in all:
		if picture.is_lens_camera():
			assert_true(picture.shot == TvCamera.Shot.BEACH_WIDE or picture.shot == TvCamera.Shot.BEACH_TIGHT, "only the beach cam zooms")
		else:
			assert_eq(picture.lens_deg, 47.0, "%s: the drones' wide lens" % picture.key())
		assert_true(picture.sail_pct.x <= picture.sail_pct.y and picture.sail_pct.y <= picture.sail_pct.z, "%s: the sail's quarters in order" % picture.key())
		assert_true(picture.horizon_pct.x <= picture.horizon_pct.y and picture.horizon_pct.y <= picture.horizon_pct.z, "%s: the horizon's quarters in order" % picture.key())
		assert_between(picture.subject_pct, 40.0, 70.0, "%s: the sail well inside the picture" % picture.key())
		if not picture.is_lens_camera() and picture.shot != TvCamera.Shot.COMMITTEE:
			assert_between(picture.height_in_sails, 2.3, 3.1, "%s: the drone's height in sail heights as measured" % picture.key())


func test_the_races_pictures_carry_the_streams_subjects() -> void:
	# Of the race's free takes (the marks and the finish come by themselves), the stream: on the front
	# 51.9 %, the pack 12.1 %, the fleet 7.2 % of the race; the drone 90 % and the beach cam 10 %.
	var on: Dictionary[String, float] = {}
	var beach: float = 0.0
	var total: float = 0.0
	for picture: TvPicture in config.race.pictures:
		on[picture.on] = on.get(picture.on, 0.0) + picture.weight_pct
		total += picture.weight_pct
		if picture.camera_kind() == "shore_long_lens":
			beach += picture.weight_pct
	assert_almost_eq(on["front"], 51.8, 0.5)
	assert_almost_eq(on["pack"], 12.1, 0.5)
	assert_almost_eq(on["fleet"], 7.2, 0.5)
	assert_almost_eq(on["front"] / total, 51.9 / (51.9 + 12.1 + 7.2), 0.01, "the front's share of the free takes")
	assert_gt(beach, 0.0, "the beach cam is in the race")


func test_a_drawn_picture_follows_the_weights_and_is_never_the_last() -> void:
	var pictures: Array[TvPicture] = config.race.pictures
	var counts: Dictionary[TvPicture, int] = {}
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 3
	var total: float = 0.0
	for picture: TvPicture in pictures:
		total += picture.weight_pct
	for i: int in 20000:
		var drawn: TvPicture = TvStreamDirector.draw_picture(pictures, null, rng.randf())
		counts[drawn] = counts.get(drawn, 0) + 1
	for picture: TvPicture in pictures:
		assert_almost_eq(100.0 * counts.get(picture, 0) / 20000.0, 100.0 * picture.weight_pct / total, 1.0, "%s by its share" % picture.key())
	for picture: TvPicture in pictures:
		for step: int in 50:
			assert_ne(TvStreamDirector.draw_picture(pictures, picture, step / 50.0), picture, "never the picture on the screen again")
	for step: int in 50:
		assert_eq(TvStreamDirector.draw_picture(pictures, null, step / 50.0, "front").on, "front", "back to the leader after the chasers")


func test_each_phase_has_its_own_pictures() -> void:
	var shots_before: Array[TvCamera.Shot] = []
	for picture: TvPicture in config.pre_start.pictures:
		shots_before.append(picture.shot)
	assert_true(shots_before.has(TvCamera.Shot.BEACH_WIDE), "before the start: the beach cam wide")
	assert_false(shots_before.has(TvCamera.Shot.BEACH_TIGHT), "not tight")
	var beach_share: float = 0.0
	var total: float = 0.0
	for picture: TvPicture in config.pre_start.pictures:
		total += picture.weight_pct
		if picture.shot == TvCamera.Shot.BEACH_WIDE:
			beach_share += picture.weight_pct
	assert_gt(beach_share / total, 0.75, "mostly the beach cam, wide and still")
	assert_eq(config.start_beach.shot, TvCamera.Shot.BEACH_WIDE, "the start opens wide on the line")
	assert_eq(config.start_line_drone.shot, TvCamera.Shot.COMMITTEE, "then Max's view down the line")
	assert_eq(config.start_line_drone.move, "static")
	assert_eq(config.finish_picture.shot, TvCamera.Shot.FINISH_LINE, "the finish: a drone side-on at the line")
	assert_eq(config.after_winner.shot, TvCamera.Shot.BEACH_TIGHT, "after the race: the long lens on the winner")
	assert_between(config.after_winner.sail_pct.y, 55.0, 70.0)
	var after: Array[TvCamera.Shot] = []
	for picture: TvPicture in config.after_race.pictures:
		after.append(picture.shot)
	assert_true(after.has(TvCamera.Shot.PULL_OUT), "and a high drone pulling out")


func test_the_lead_group_and_the_pack() -> void:
	# Race order: two together in front, then a fight for third and fourth, then one alone, one finished.
	var positions: PackedVector2Array = PackedVector2Array([Vector2(0, -900), Vector2(10, -890), Vector2(0, -600), Vector2(8, -598), Vector2(0, -200), Vector2(0, 0)])
	var finished: PackedByteArray = PackedByteArray([0, 0, 0, 0, 0, 1])
	var front: int = TvStreamDirector.lead_group_size(positions, finished, config.lead_group_m, config.lead_group_most)
	assert_eq(front, 2, "the lead group: the first two together")
	var none: PackedByteArray = PackedByteArray([0, 0, 0, 0, 0, 0])
	var weights: PackedFloat32Array = TvStreamDirector.pack_weights(positions, finished, none, front, config.close_m)
	assert_eq(weights[0], 0.0, "the lead group is not the pack")
	assert_eq(weights[1], 0.0)
	assert_eq(weights[5], 0.0, "nor a finished board")
	assert_gt(weights[2], weights[4], "a fight more than a board alone")
	var gained: PackedFloat32Array = TvStreamDirector.pack_weights(positions, finished, PackedByteArray([0, 0, 0, 0, 1, 0]), front, config.close_m)
	assert_gt(gained[4], weights[4], "a place gained counts")
	var all_finished_but_one: int = TvStreamDirector.lead_group_size(positions, PackedByteArray([1, 1, 0, 1, 1, 1]), 40.0, 4)
	assert_eq(all_finished_but_one, 3, "the first still racing leads the group")


# ---------------------------------------------------------------- the start and the marks

func test_the_start_is_the_beach_then_the_line_drone_then_the_runner() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 5
	var lines: PackedFloat32Array = PackedFloat32Array()
	var runners: PackedFloat32Array = PackedFloat32Array()
	for i: int in 2000:
		var times: Vector3 = TvStreamDirector.start_times(config, rng)
		assert_lt(times.x, 0.0, "the line drone comes before the gun")
		assert_gt(times.x, config.start_from_s, "inside the start phase")
		assert_gt(times.y, 0.0, "the runner after the gun")
		assert_between(times.z, 4.0, 18.0, "it runs for some seconds")
		lines.append(-times.x)
		runners.append(times.y)
	lines.sort()
	runners.sort()
	assert_between(lines[1000], 1.0, 4.0, "the line drone 1 to 4 s before the gun (the stream: 3.1 in the middle)")
	assert_almost_eq(runners[1000], config.runner_after_gun_s.y, 0.1, "the runner just after the gun")


func test_a_take_at_a_mark_holds_on_the_gybe() -> void:
	var take_s: float = 6.7
	var longest_s: float = config.mark_longest_s
	var after_s: float = config.mark_after_rounding_s
	assert_true(TvStreamDirector.mark_take_goes_on(10.0, -1.0, take_s, longest_s, after_s), "not rounded yet: it holds")
	assert_true(TvStreamDirector.mark_take_goes_on(5.0, 4.0, take_s, longest_s, after_s), "rounded, its time not up")
	assert_true(TvStreamDirector.mark_take_goes_on(7.0, 6.5, take_s, longest_s, after_s), "rounded just now: a little more")
	assert_false(TvStreamDirector.mark_take_goes_on(8.0, 4.0, take_s, longest_s, after_s), "rounded and its time up")
	assert_false(TvStreamDirector.mark_take_goes_on(longest_s, -1.0, take_s, longest_s, after_s), "never past the longest")
	assert_between(config.mark_shortest_s, 3.0, 5.0, "the stream holds 4 to 16 s on the gybe")
	assert_eq(config.mark_longest_s, 16.0)
	assert_eq(config.mark_cut_before_s, Vector2(2.0, 5.0), "the cut 2 to 5 s before the leader arrives")


# ---------------------------------------------------------------- the lead's measured drone positions

func test_the_framing_puts_the_drones_where_the_stream_flies_them() -> void:
	# The lead's measurement (drone_position.md): the drone's height in sail heights, lens-free, the firm
	# part; and with the 47-degree lens and a raked sail 3.5 m tall, its height and distance (the middle
	# half). The game's framing of the same picture (its middle sail, horizon and sail place) must land
	# inside them.
	var measured: Dictionary[TvPicture, Array] = {
		config.race.picture_of(TvCamera.Shot.CHASE, "front"): [Vector2(2.3, 3.0), Vector2(6.1, 8.9), Vector2(17.0, 29.0)],
		config.race.picture_of(TvCamera.Shot.FRONT_SIDE, "front"): [Vector2(1.9, 2.7), Vector2(7.0, 10.2), Vector2(22.0, 43.0)],
		config.race.picture_of(TvCamera.Shot.TRACK, "front"): [Vector2(2.0, 3.2), Vector2(6.7, 10.6), Vector2(20.0, 48.0)],
		config.race.picture_of(TvCamera.Shot.GROUP, "pack"): [Vector2(2.0, 3.4), Vector2(4.8, 8.8), Vector2(12.0, 21.0)],
	}
	for picture: TvPicture in measured:
		var ranges: Array = measured[picture]
		var framing: Vector3 = picture.take_framing(0.0)
		var place: Vector3 = TvFraming.drone_place(picture.lens_deg, 3.5, framing.x, framing.y, framing.z, config.lowest_m)
		var seen: Vector3 = TvFraming.measure(_camera_at(place.x, place.y, place.z), picture.lens_deg, Vector3.ZERO, Vector3.UP * 3.5)
		var sail_heights: float = (seen.z - seen.y) / seen.x
		assert_between(sail_heights, (ranges[0] as Vector2).x, (ranges[0] as Vector2).y, "%s: the height in sail heights" % picture.key())
		assert_between(place.y, (ranges[1] as Vector2).x, (ranges[1] as Vector2).y, "%s: the height, m" % picture.key())
		assert_between(place.x, (ranges[2] as Vector2).x * 0.85, (ranges[2] as Vector2).y * 1.15, "%s: the distance, m (+-15 %%)" % picture.key())


func test_a_takes_framing_keeps_the_sail_and_the_horizon_together() -> void:
	var picture: TvPicture = config.race.picture_of(TvCamera.Shot.CHASE, "front")
	var middle: Vector3 = picture.take_framing(0.0)
	assert_almost_eq(middle.x, picture.sail_pct.y / 100.0, 1e-6, "the middle draw: the stream's middle sail")
	assert_almost_eq(middle.y, picture.horizon_pct.y / 100.0, 1e-6, "and its middle horizon")
	var close: Vector3 = picture.take_framing(-1.0)
	var far: Vector3 = picture.take_framing(1.0)
	assert_true(far.x >= middle.x and middle.x >= close.x, "the sail grows with the draw")
	assert_true(far.y <= middle.y and middle.y <= close.y, "and the horizon climbs as it does")
	assert_eq(picture.take_framing(5.0), far, "never past about the middle half")
	# The sail's foot stands the drone's height in sail heights below the horizon.
	assert_almost_eq((middle.z + middle.x * 0.5 - middle.y) / middle.x, picture.height_in_sails, 1e-4)
	var zoomed: Vector3 = picture.take_framing(0.0, 2.0)
	assert_almost_eq(zoomed.x, middle.x / 2.0, 1e-6, "the wheel: half the sail")
	assert_almost_eq(zoomed.y, middle.y, 1e-6, "the horizon stays")


# ---------------------------------------------------------------- the beach cam on a map's shore

## A map's ground grid with a straight coast (a sea coast like Sotavento, not a lake): open water 10 m
## deep up to x = 400 m, land 5 m high from x = 450 m (the grid's points are 50 m apart and the ground
## between them is interpolated: the waterline at x = 433 m), 2 km square round the origin.
func _coast() -> TerrainGrid:
	var grid: TerrainGrid = TerrainGrid.new()
	grid.columns = 41
	grid.rows = 41
	grid.cell_m = 50.0
	grid.x0_m = -1000.0
	grid.z0_m = -1000.0
	grid._offset_m = -20.0
	grid._scale_m = 0.01
	var values: PackedByteArray = PackedByteArray()
	values.resize(grid.columns * grid.rows * 2)
	for row: int in grid.rows:
		for column: int in grid.columns:
			var x_m: float = grid.x0_m + column * grid.cell_m
			values.encode_u16(2 * (row * grid.columns + column), 2500 if x_m > 400.0 else 1000)
	grid._values = values
	return grid


func test_the_beach_cam_finds_a_coast_on_one_side_only() -> void:
	var grid: TerrainGrid = _coast()
	var shore: Vector3 = TvCamera.shore_along(grid, Vector3.ZERO, Vector3.RIGHT, 60.0, 1200.0)
	assert_between(shore.x, 400.0, 434.0, "towards the coast: the water's edge (the waterline at 433 m)")
	assert_false(TvCamera._is_land(grid, shore), "it stands on the water")
	assert_true(is_nan(TvCamera.shore_along(grid, Vector3.ZERO, Vector3.LEFT, 60.0, 1200.0).x), "out to sea: no shore")
	assert_true(is_nan(TvCamera.shore_along(grid, Vector3.ZERO, Vector3.RIGHT, 60.0, 200.0).x), "a coast out of reach: none")
	assert_true(is_nan(TvCamera.shore_along(grid, Vector3(400.0, 0.0, 0.0), Vector3.RIGHT, 60.0, 1200.0).x), "a coast too near: none")
	assert_true(TvCamera.land_between(grid, Vector3(600.0, 2.0, 0.0), Vector3(-200.0, 0.0, 0.0)), "a camera inland looks across the land")
	assert_false(TvCamera.land_between(grid, Vector3(-600.0, 2.0, 0.0), Vector3(-200.0, 0.0, 0.0)), "a camera boat at sea does not")
	assert_almost_eq(TvCamera.view_off(Vector3.BACK, [Vector3.RIGHT, Vector3.LEFT] as Array[Vector3]), PI / 2.0, 1e-5, "a quarter turn off both views")


# ---------------------------------------------------------------- the 12 November director stays

func test_the_12_november_director_keeps_its_numbers() -> void:
	var old: TvDirector12NovConfig = load(TvCamera.CONFIG_12NOV) as TvDirector12NovConfig
	assert_eq(old.shot_min_s, 7.0)
	assert_eq(old.shot_max_s, 12.0)
	assert_eq(old.start_wide_from_s, -40.0)
	assert_eq(old.line_from_s, -12.0)
	assert_eq(old.fov_of(TvCamera.Shot.ORBIT), 28.0)
	assert_eq(old.fov_of(TvCamera.Shot.COMMITTEE), 44.0)
	assert_eq(old.shots_usual, PackedFloat32Array([3.0, 3.0, 2.5, 1.5, 0.0, 0.0]))
	assert_eq(config.hand_shots.resource_path, old.resource_path, "the stream's director takes the helicopter from it")
