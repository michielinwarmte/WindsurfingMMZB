class_name RaceWindClock
extends RefCounted
## One clock for the wind of every board in a race (ROADMAP RA13). Every board has its own wind
## field (a board stepped on a thread must not share one), and a field's gusts run on the field's
## own clock: the patches roll downwind by how far the field's air has travelled (travel_m), the
## sines and the shifts follow its time (time_s), and the lake's wind follows its time of day. A
## field made later than the others (a board made after the player's, a board set down again in
## training) would see the gusts somewhere else. So the race keeps one clock: before the physics of
## a tick it hands the clock to every board's field (hand_to()); every field then steps the same
## time from the same clock, so after the step they all agree, and the race reads the clock back
## from any of them (of()). Nothing in the physics changes: the fields' own numbers are set, as the
## field would have counted them had it been made with the first.

## The field's time since it was made (WindField.time_s), seconds.
var time_s: float = 0.0
## How far the air has travelled downwind (WindField.travel_m), metres.
var travel_m: float = 0.0
## The time of day of a map's wind (MapWindField's clock), seconds since midnight; -1 for the open
## water's wind, which has none.
var time_of_day_s: float = -1.0


## The clock a field shows now.
static func of(field: WindField) -> RaceWindClock:
	var clock: RaceWindClock = RaceWindClock.new()
	if field == null:
		return clock
	clock.time_s = field.time_s
	clock.travel_m = field.travel_m
	var map_field: MapWindField = field as MapWindField
	if map_field != null:
		clock.time_of_day_s = map_field.time_of_day_s()
	return clock


## Sets a field to this clock. A field that already shows it is left as it is; one that does not
## (just made) is moved to it, and its gusts are where the others' are from its next step on.
func hand_to(field: WindField) -> void:
	if field == null:
		return
	field.time_s = time_s
	field.travel_m = travel_m
	var map_field: MapWindField = field as MapWindField
	if map_field != null and time_of_day_s >= 0.0:
		map_field.clock.set_time(time_of_day_s)
