extends GutTest
## slalom_dive_gybes (Skipper._slalom_dive_deg(); the training method's phase S, 9 November 2026): on a slalom's dive
## down onto the line, with its crossing on the other tack, from a reach or deeper it bears away and gybes instead of
## asking for the turn at once (the controller tacks up to 100 deg: r0024 of baseline_S tacked at 6 m/s on T2, stopped
## in the wind's eye and started 52 s late).

const RunRace: GDScript = preload("res://dev/run_race.gd")
const WIND_DEG: float = 0.0


## A skipper on T2's stand-in, on a beam reach on the tack away from its crossing, 50 m from it.
func _diving_skipper() -> Array:
	var course: Course = RaceCourses.t2_stand_in(WIND_DEG, Vector2.ZERO)
	var race: RaceSim = RaceSim.new(course, 1, 60.0)
	var entries: Array = RunRace.make_entries(race, course, PackedStringArray(["allrounder"]), 17.0, 50.0, 1)
	var skipper: Skipper = entries[0].skipper as Skipper
	var spot: Vector2 = skipper._start_spot(race.steps()[0])
	# The crossing a broad reach away (120 deg off the wind), on one side.
	var position: Vector2 = spot - Course.direction_of(WIND_DEG + 240.0) * 50.0
	var needed: float = Navigation.wind_angle_deg(position, skipper._through(position, spot), WIND_DEG)
	var tack: float = -signf(needed)  # on the other tack
	var telemetry: Telemetry = skipper._sim.telemetry
	telemetry.position = Vector3(position.x, 0.0, position.y)
	telemetry.wind_from_bearing_deg = WIND_DEG
	telemetry.twa_deg = tack * 90.0
	telemetry.heading_deg = wrapf(WIND_DEG - tack * 90.0, 0.0, 360.0)
	telemetry.speed_ms = 6.0
	telemetry.sail_side = 0
	return [skipper, spot, tack]


func test_it_is_off_unless_switched_on() -> void:
	assert_false(SkipperConfig.new().slalom_dive_gybes, "off by default until the suite says it wins")


func test_off_it_asks_for_the_turn_at_once() -> void:
	var setup: Array = _diving_skipper()
	var skipper: Skipper = setup[0]
	skipper._slalom_dive_deg(skipper._sim.telemetry, setup[1])
	assert_gte(skipper._tack_due_s, 0.0, "the turn asked for at a beam reach (the controller makes it a tack)")


func test_on_it_bears_away_for_a_gybe_first() -> void:
	var setup: Array = _diving_skipper()
	var skipper: Skipper = setup[0]
	skipper.config.slalom_dive_gybes = true
	var heading: float = skipper._slalom_dive_deg(skipper._sim.telemetry, setup[1])
	assert_lt(skipper._tack_due_s, 0.0, "no turn asked for yet at a beam reach")
	var twa: float = absf(wrapf(WIND_DEG - heading, -180.0, 180.0))
	assert_gt(twa, skipper._controller.tack_up_to_twa_deg, "it bears away past the controller's tacking angle")
	# Borne away that far, it asks for the turn: a gybe.
	skipper._sim.telemetry.twa_deg = setup[2] * (skipper._controller.tack_up_to_twa_deg + 8.0)
	skipper._slalom_dive_deg(skipper._sim.telemetry, setup[1])
	assert_gte(skipper._tack_due_s, 0.0, "the gybe asked for")
