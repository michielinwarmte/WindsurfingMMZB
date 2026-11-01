class_name LearnedSkipper
extends RaceSkipper
## A skipper whose decisions come from a trained neural network (RACING_PLAN.md, "The learned
## skipper"). Ten times a second it builds what it sees (RaceObservation), asks the brain "what
## now?", and turns the answer into a player's controls. It drives the board through the same
## beginner controller the player uses (RD1), with the auto-sheet on, so it can do nothing a player
## could not.
##
## A brain answers in one of two ways (its action mode, written in the brain file's note):
## - "twa" (the trainer's default): the first number is the wind angle the board should sail at,
##   180 degrees times the number, positive with the wind from starboard as Telemetry.twa_deg. The
##   hands then steer for that angle every tick, with the controller's heading hold doing the steady
##   part, and ask for a tack or a gybe when the angle wanted is clearly on the other tack (and the
##   board has sailed a few seconds since the last one). A sailor thinks the same way:
##   "close-hauled on starboard", "now the other tack". The third number is not used.
## - "stick": the first number is the steering stick itself, held until the next decision, and the
##   third asks for a tack or gybe as it rises above 0.5.
## In both, the second number is the sheet, through a dead zone that leaves the auto-sheet trimming.
## In the wind-angle mode a brain whose third output is called "hold" (the trainer's brains since
## F5) uses it for the hands' hold-back skill (AI_FLEET_PLAN.md, D1): above 0 the sheet is eased
## until the board sails no faster than hold_from_output() says, down to 1.5 m/s at 1.
## A brain with an output called "push" (the trainer's brains since Session 64, ROADMAP RA12) sets
## the push slider with it at every decision (AiHands.push, from 0 at -1 to 1 at 1:
## push_from_output()): how hard the sailor commits, so a brain can push on flat water and ease in
## waves and gusts. A brain without one leaves AiHands.push at NaN: the pilot's own margin, as
## before the slider. The outputs are found by their names in the brain file, like the inputs.
##
## The tack discipline (ROADMAP RA14): after a tack or a gybe the hands ignore a wish for the other
## tack for manoeuvre_gap_s (MANOEUVRE_GAP_S for the brains trained since RA14; their note says it).
## The brains of the first nights tacked every 10 to 15 s on a beat, because their wish is a wind
## angle whose sign is the tack and they learned to point at the mark: dead upwind, their wish
## crossed the wind as the board zigzagged across the line to the mark, and the hands tacked at
## every crossing. A sailor sails one tack to the layline and tacks once. A rounding (a step of the
## course done) cuts what is left of the wait to TACK_HOLD_S: the next leg may need a manoeuvre at
## once (a gybe at a slalom mark, a tack off the gate). A brain whose note says no gap (every brain
## before RA14) keeps the old rule, TACK_HOLD_S, and sails as it did. With it, the hands never
## steer nearer the wind than closest_twa_deg (CLOSEST_TWA_DEG, the character sheets' closest beat):
## the first brains, pointing at the mark, were under 2 m/s for a third to a half of a race, most
## of it 15 to 45 degrees off the wind, pinched or in irons. A brain without the note steers as it
## did.
##
## The trainer (RaceEnv) uses the same Driver as here, so a brain sails in the game exactly as it
## sailed in training.
##
## Use: setup() once, then every tick, before controller.update(): update(telemetry, dt). Give it
## the other boards with set_others() every tick (or at least every decision) if there are any.

## How the network's numbers are read (see above).
enum ActionMode { STICK, TWA }
## The modes' names, as the brain file and the trainer's --actions write them.
const ACTION_MODE_NAMES: PackedStringArray = ["stick", "twa"]

## Index of each action in the network's output.
const STEER: int = 0
const SHEET: int = 1
const TACK: int = 2
const ACTION_NAMES: PackedStringArray = ["steer", "sheet", "tack"]
## The names of the outputs in the wind-angle mode: the wind angle, the sheet, and the hold-back
## speed (the night's first brains had "unused" there and never hold back).
const HOLD: int = 2
## The fourth output in the trainer's brains since Session 64: the push slider (RA12).
const PUSH: int = 3
const TWA_ACTION_NAMES: PackedStringArray = ["twa", "sheet", "hold", "push"]
## The name of the push output (a brain's outputs are found by name: push_index_of()).
const PUSH_NAME: String = "push"
## The hold-back speed for a hold output just above 0 (as good as no hold) and at 1 (the controller's
## slowest, where the board still steers), m/s.
const HOLD_FASTEST_MS: float = 8.0
const HOLD_SLOWEST_MS: float = 1.5
## Stick mode: a tack or gybe is asked for when the tack output rises above this.
const TACK_THRESHOLD: float = 0.5
## The sheet output only takes the sheet over from the auto-sheet beyond this, either way. The
## beginner controller reads any sheet value that is not exactly 0 as a hand on the sheet and stops
## the auto-sheet for three seconds, and a network's output is never exactly 0: without this dead
## zone the auto-sheet would never trim, not even through a tack or a gybe (where it backs the sail
## and steps the sailor forward). Inside the dead zone the auto-sheet trims; beyond it the output is
## stretched back to the full -1 to 1, so a full answer is still a full sheet key.
const SHEET_DEAD_ZONE: float = 0.5
## The network decides every this many ticks of 1/60 s: ten times a second.
const DECISION_TICKS: int = 6
## Wind-angle mode: an output of 1 asks for this angle (dead downwind on starboard tack).
const TWA_FULL_SCALE_DEG: float = 180.0
## An error of this many degrees from the angle wanted is a full stick; less is a part of it.
const TWA_FULL_STICK_DEG: float = 20.0
## Within this many degrees of the angle wanted the stick is let go, and the controller's heading
## hold keeps the board where it is.
const TWA_DEAD_BAND_DEG: float = 2.0
## A tack or gybe is asked for at most this often, so a manoeuvre that did not take does not have
## the sailor asking non-stop.
const TACK_REQUEST_EVERY_S: float = 3.0
## And not until this long after the last manoeuvre ended: the board needs its speed back, and a
## network whose wish flips as the board turns would otherwise tack it to a standstill (the first
## wind-angle brains did, every 2.5 s).
const TACK_HOLD_S: float = 6.0
## The tack discipline (RA14, above): the least time from the end of one manoeuvre to the next ask,
## seconds, for the brains trained since RA14. The scripted all-rounder tacks about every 90 s on a
## beat; a tack costs 10 to 20 m. The trainer and the evaluation can set another (--manoeuvre_gap_s);
## the brain's note keeps the one it learned with.
const MANOEUVRE_GAP_S: float = 20.0
## The brain note's key for its gap; a brain without it keeps TACK_HOLD_S (gap_of()).
const GAP_NOTE: String = "manoeuvre_gap_s"
## The closest to the wind the hands steer for the brains trained since RA14, degrees: a wish nearer
## the wind means close-hauled at this angle on the tack the board is on (the scripted skippers'
## upwind_vmg_twa_deg goes no lower: SkipperConfig). The brain note's key; without it, no floor.
const CLOSEST_TWA_DEG: float = 35.0
const CLOSEST_NOTE: String = "closest_twa_deg"
## Between these wind angles (either side) the sign of the wind angle says the tack. Nearer head to
## wind (in irons) or dead downwind (by the lee) it flickers, and the side the sail is on says it.
const CLEAR_TACK_FROM_DEG: float = 25.0
const CLEAR_TACK_TO_DEG: float = 165.0


## Turns the network's answers into the hands: at each decision (decide()), and in the wind-angle
## mode also every tick in between (steer()), because the stick that holds a wind angle has to
## follow the board. One for each board; RaceEnv and LearnedSkipper both use it.
class Driver:
	var mode: ActionMode = ActionMode.TWA
	var hands: AiHands
	## Wind-angle mode: whether the third output is the hold-back speed (uses_hold_of()).
	var uses_hold: bool = false
	## Wind-angle mode: which output is the push slider (push_index_of()); -1 for none, and then
	## the hands' push is left alone (NaN: the pilot's own margin).
	var push_index: int = -1
	## Wind-angle mode: the angle the last decision asked for (degrees, positive from starboard),
	## and whether there has been a decision yet.
	var wanted_twa_deg: float = 0.0
	var has_wish: bool = false
	## Stick mode: whether the tack output was high at the last decision.
	var tack_was_high: bool = false
	## Seconds since the last tack or gybe this driver asked for, and since the last manoeuvre ended.
	var since_tack_request_s: float = 1.0e9
	var since_manoeuvre_s: float = 1.0e9
	## The least time from the end of a manoeuvre to the next ask, seconds (the tack discipline:
	## MANOEUVRE_GAP_S, or TACK_HOLD_S for a brain from before it).
	var manoeuvre_gap_s: float = TACK_HOLD_S
	## The closest to the wind it steers, degrees (CLOSEST_TWA_DEG; 0 for a brain from before RA14).
	var closest_twa_deg: float = 0.0

	func _init(the_hands: AiHands, action_mode: ActionMode = ActionMode.TWA) -> void:
		hands = the_hands
		mode = action_mode

	## A decision: the network's three numbers.
	func decide(action: PackedFloat32Array, in_manoeuvre: bool) -> void:
		if mode == ActionMode.STICK:
			tack_was_high = LearnedSkipper.apply_action(hands, action, tack_was_high, in_manoeuvre)
			return
		wanted_twa_deg = TWA_FULL_SCALE_DEG * clampf(action[STEER], -1.0, 1.0)
		hands.sheet = LearnedSkipper.sheet_from_output(action[SHEET])
		if uses_hold:
			hands.hold_speed_ms = LearnedSkipper.hold_from_output(action[HOLD]) if action.size() > HOLD else 0.0
		if push_index >= 0 and action.size() > push_index:
			hands.push = LearnedSkipper.push_from_output(action[push_index])
		has_wish = true

	## A step of the course was done (a mark rounded, a gate, the start): what is left of the wait
	## for the next manoeuvre is cut to TACK_HOLD_S, because the next leg may need one at once. With
	## the old rule (a gap of TACK_HOLD_S) nothing changes.
	func leg_done() -> void:
		since_manoeuvre_s = maxf(since_manoeuvre_s, manoeuvre_gap_s - TACK_HOLD_S)

	## Every tick, before the controller's update (wind-angle mode only; the stick mode's hands stay
	## as the last decision left them). The angle wanted is clearly on the other tack: ask for a tack
	## or gybe (the controller picks which), unless one is under way, ended less than
	## manoeuvre_gap_s ago (the tack discipline; until then the board holds the angle wanted on the
	## tack it is on), or was asked for less than TACK_REQUEST_EVERY_S ago. Otherwise steer toward the angle
	## wanted on this tack. "Clearly" is the rule tack_of() uses for the board: between
	## CLEAR_TACK_FROM_DEG and CLEAR_TACK_TO_DEG off the wind. A wish nearer head to wind or dead
	## downwind means "as high (or as deep) as it goes" on the tack the board is on.
	func steer(telemetry: Telemetry, in_manoeuvre: bool, dt: float) -> void:
		since_tack_request_s += dt
		since_manoeuvre_s = 0.0 if in_manoeuvre else since_manoeuvre_s + dt
		if mode != ActionMode.TWA or not has_wish:
			return
		var tack: float = LearnedSkipper.tack_of(telemetry)
		var off_wind_deg: float = absf(wanted_twa_deg)
		var clearly_other_tack: bool = signf(wanted_twa_deg) == -tack and off_wind_deg > CLEAR_TACK_FROM_DEG and off_wind_deg < CLEAR_TACK_TO_DEG
		if clearly_other_tack and not in_manoeuvre and since_manoeuvre_s >= manoeuvre_gap_s and since_tack_request_s >= TACK_REQUEST_EVERY_S:
			hands.tack = true
			hands.steer = 0.0
			since_tack_request_s = 0.0
			return
		hands.steer = LearnedSkipper.steer_toward_twa(telemetry.twa_deg, tack, maxf(off_wind_deg, closest_twa_deg))


## pilot_margin_level() on the game's ladder, once worked out.
static var _default_pilot_margin_level: float = NAN


## The brain, and with it how often it decides (its note's decision_ticks, if it has one) and its
## tack discipline (gap_of()).
var brain: NeuralNet = null:
	set(value):
		brain = value
		if value != null and value.meta.has("decision_ticks"):
			decision_ticks = maxi(int(value.meta["decision_ticks"]), 1)
		if value != null:
			manoeuvre_gap_s = gap_of(value)
			closest_twa_deg = closest_of(value)
## The least time between two manoeuvres, seconds (the tack discipline): the brain's own (gap_of());
## the race tool's --manoeuvre_gap_s sets another after the brain, to compare.
var manoeuvre_gap_s: float = TACK_HOLD_S
## The closest to the wind the hands steer, degrees: the brain's own (closest_of()); the race tool's
## --closest_twa_deg sets another after the brain, to compare.
var closest_twa_deg: float = 0.0
## The brain file's name (night_best, ...), shown on the results and the labels.
var brain_name: String = "brain"
## Named by its generation alone ("gen 40", "best"), not with its run: in a race of one run's
## generations only (Skippers.make_fleet(), tools/gens.sh), where the run says nothing.
var short_label: bool = false
var decision_ticks: int = DECISION_TICKS
## The sail's colour (sail_colour()).
var sail: Color = Color(0.6, 0.35, 0.9)
## Blind: the skipper sees no other board, whatever set_others() gives it, as the night's brains
## were trained (alone on the course: the others' inputs were zeros). --blind=1 (RaceSetup, the
## race tool) sets it, so generations can be compared in the conditions they learned in.
var blind: bool = false

var _sim: WindsurferSim = null
var _controller: PlayerController = null
var _hands: AiHands = null
var _driver: Driver = null
var _race: RaceSim = null
var _index: int = 0
var _wind: WindField = null
var _others_positions: PackedVector2Array = PackedVector2Array()
var _others_velocities: PackedVector2Array = PackedVector2Array()
## Ticks until the next decision; 0 decides on the next update.
var _ticks_to_decision: int = 0
## The step of the course the board sailed to at the last tick (-1 before the first), to see a
## rounding (Driver.leg_done()).
var _last_step: int = -1
## The sea's height where this board sails (RaceObservation.sea_height_m()), taken at setup().
var _sea_height_m: float = 0.0
var _since_manoeuvre_s: float = RaceObservation.SINCE_MANOEUVRE_SCALE_S
## The last answer of the brain, for the HUD and the tests.
var last_action: PackedFloat32Array = PackedFloat32Array([0.0, 0.0, 0.0])


## The board this skipper sails: its simulation, its controller (set to these hands), the race and
## the board's number in it. The wind it looks around in is the simulation's own until
## set_wind_field() gives another (a shared field, in a race with several boards).
func setup(sim: WindsurferSim, controller: PlayerController, hands: AiHands, race: RaceSim, index: int) -> void:
	_sim = sim
	_controller = controller
	_hands = hands
	_driver = Driver.new(hands)
	_race = race
	_index = index
	_wind = sim.wind if sim != null else null
	_sea_height_m = RaceObservation.sea_height_m(sim) if sim != null else 0.0
	_controller.hands = _hands
	_ticks_to_decision = 0
	_last_step = -1
	_since_manoeuvre_s = RaceObservation.SINCE_MANOEUVRE_SCALE_S


## A night's brain by its run and generation ("all_s3 best", "night2b gen 40": Generations), so the
## brains of several runs in one race have names of their own (ROADMAP RA15: they were all "best",
## and their tracks went to one best.csv); by its generation alone with short_label. Any other
## brain by its file name.
func skipper_name() -> String:
	var generation_label: String = Generations.label_of(brain_name)
	if generation_label.is_empty():
		return brain_name
	if short_label:
		return generation_label
	return "%s %s" % [Generations.run_of(brain_name), generation_label]


## A learned skipper sails under a purple sail, or the colour of its generation in a race of
## several generations (Generations.colour_fleet()).
func sail_colour() -> Color:
	return sail


## The wind field to sample the gusts around the board from.
func set_wind_field(wind: WindField) -> void:
	_wind = wind


## The other boards: where they are (game X, Z) and how fast they move (m/s in X, Z). Never given:
## the skipper sees no one.
func set_others(positions: PackedVector2Array, velocities: PackedVector2Array) -> void:
	if blind:
		return
	_others_positions = positions
	_others_velocities = velocities


## Every tick, before the controller's update: a new decision every decision_ticks ticks, and the
## hands steered toward it (in the wind-angle mode) in between.
func update(telemetry: Telemetry, dt: float) -> void:
	if _controller == null or _hands == null:
		return
	var in_manoeuvre: bool = _controller.manoeuvre != PlayerController.Manoeuvre.NONE
	_see_rounding()
	_ticks_to_decision -= 1
	if _ticks_to_decision <= 0:
		_ticks_to_decision = maxi(decision_ticks, 1)
		_decide(telemetry, in_manoeuvre)
	if telemetry.sailor_state == WindsurferSim.SailorState.SAILING:
		_driver.steer(telemetry, in_manoeuvre, dt)
	# The clock since the last manoeuvre moves on after the decision, as RaceEnv moves it in the
	# tick that follows its decision: both see the same number.
	_since_manoeuvre_s = RaceObservation.advance_since_manoeuvre(_since_manoeuvre_s, in_manoeuvre, dt)


## The hands' driver (for the tests).
func driver() -> Driver:
	return _driver


## A step of the course done since the last tick cuts the wait for the next manoeuvre
## (Driver.leg_done()), as RaceEnv does at the end of the tick in which the step was done: both
## between the same two ticks.
func _see_rounding() -> void:
	if _race == null:
		return
	var step_now: int = _race.next_step_index(_index)
	if _last_step >= 0 and step_now > _last_step:
		_driver.leg_done()
	_last_step = step_now


## One decision: what the board sees, through the brain, onto the hands, read in the mode the brain
## was trained in.
func _decide(telemetry: Telemetry, in_manoeuvre: bool) -> void:
	if brain == null or _race == null:
		return
	if telemetry.sailor_state != WindsurferSim.SailorState.SAILING:
		# In the water the hands hold nothing, and no tack is left waiting for when the sailor is
		# back up (RaceEnv.act() skips these decisions the same way).
		_hands.tack = false
		return
	_driver.mode = mode_of(brain)
	_driver.uses_hold = uses_hold_of(brain)
	_driver.push_index = push_index_of(brain) if _driver.mode == ActionMode.TWA else -1
	_driver.manoeuvre_gap_s = manoeuvre_gap_s
	_driver.closest_twa_deg = closest_twa_deg
	var observation: PackedFloat32Array = RaceObservation.build(telemetry, _race, _index, _wind,
			_others_positions, _others_velocities, in_manoeuvre, _since_manoeuvre_s, _driver.wanted_twa_deg, _hands.hold_speed_ms,
			_hands.push, _sea_height_m)
	# The brain's inputs by name: a brain from before a number was added still sails.
	last_action = brain.forward(brain.select_inputs(observation, RaceObservation.names()))
	_driver.decide(last_action, in_manoeuvre)


# ---------------------------------------------------------------- the two ways of answering

## The mode a brain was trained in, from its note ("actions"); a brain without one is a stick brain
## (the first brains were).
static func mode_of(net: NeuralNet) -> ActionMode:
	return mode_named(str(net.meta.get("actions", "stick")))


## The mode for a name ("twa" or "stick"); anything else is the wind-angle mode.
static func mode_named(name: String) -> ActionMode:
	return ActionMode.STICK if name == "stick" else ActionMode.TWA


static func mode_name(mode: ActionMode) -> String:
	return ACTION_MODE_NAMES[mode]


## The least time between two manoeuvres a brain was trained with (the tack discipline, RA14): its
## note's manoeuvre_gap_s; TACK_HOLD_S for a brain from before RA14, so it sails as it did.
static func gap_of(net: NeuralNet) -> float:
	if net == null or not net.meta.has(GAP_NOTE):
		return TACK_HOLD_S
	return maxf(float(net.meta[GAP_NOTE]), 0.0)


## The closest to the wind a brain was trained to be steered (RA14): its note's closest_twa_deg; 0
## (no floor) for a brain from before RA14.
static func closest_of(net: NeuralNet) -> float:
	if net == null or not net.meta.has(CLOSEST_NOTE):
		return 0.0
	return clampf(float(net.meta[CLOSEST_NOTE]), 0.0, CLEAR_TACK_TO_DEG)


## Whether a brain's third output is the hold-back speed: its outputs' names say so.
static func uses_hold_of(net: NeuralNet) -> bool:
	return net.action_names.size() > HOLD and net.action_names[HOLD] == "hold"


## Which output of a brain is the push slider: the one called PUSH_NAME; -1 when it has none (the
## brains made before Session 64), and then the hands' push stays NaN.
static func push_index_of(net: NeuralNet) -> int:
	return net.action_names.find(PUSH_NAME)


## The push slider's level (0 to 1, PlayerController.push_level) for a push output (-1 to 1, as
## every output): straight from 0 at -1 to 1 at 1, so 0 is the slider's middle (cruising).
static func push_from_output(output: float) -> float:
	return clampf(0.5 * (output + 1.0), 0.0, 1.0)


## The push output that gives a slider level (push_from_output() turned round).
static func output_for_push(level: float) -> float:
	return 2.0 * clampf(level, 0.0, 1.0) - 1.0


## The slider level that asks the autopilot for its own margin, the one the AI boards sail with
## AiHands.push at NaN: where the push curve's pull held (hike_share) reaches the pilot's default
## (1.1, between "neutral" at 75 % and 85 %: about 78 %). A fresh policy's push starts here, so
## the training begins where the fleet sails today. The slider also sets what the pilot leaves at
## its defaults (at 78 % about 1 degree more rig lean and up to 3 degrees of rail for the sea); the
## pull is the lever that pays (push_curve_default.tres).
static func pilot_margin_level(curve: PushCurveConfig = null) -> float:
	if curve == null:
		# The game's ladder: worked out once (every observation asks for it).
		if is_nan(_default_pilot_margin_level):
			_default_pilot_margin_level = pilot_margin_level(PushDial.default_curve())
		return _default_pilot_margin_level
	var ladder: PushCurveConfig = curve
	var wanted: float = Autopilot.new().hike_share
	var n: int = mini(ladder.levels.size(), ladder.hike_share.size())
	for i: int in range(1, n):
		var low: float = ladder.hike_share[i - 1]
		var high: float = ladder.hike_share[i]
		if wanted >= low and wanted <= high and high > low:
			return lerpf(ladder.levels[i - 1], ladder.levels[i], (wanted - low) / (high - low))
	return PushDial.NEUTRAL


## The hold-back speed (m/s) for a hold output: none at 0 or below; from HOLD_FASTEST_MS just above
## 0 (as good as no hold on a beat) down to HOLD_SLOWEST_MS at 1.
static func hold_from_output(output: float) -> float:
	if output <= 0.0:
		return 0.0
	return lerpf(HOLD_FASTEST_MS, HOLD_SLOWEST_MS, clampf(output, 0.0, 1.0))


## Stick mode: puts the network's three numbers on the hands: the steer as it is (a stick from -1 to
## 1), the sheet through the dead zone (SHEET_DEAD_ZONE), and a tack or gybe asked for when the tack
## output has just risen above TACK_THRESHOLD and none is under way. Returns whether the tack output
## is high now, which the caller keeps for the next decision.
static func apply_action(hands: AiHands, action: PackedFloat32Array, tack_was_high: bool, in_manoeuvre: bool) -> bool:
	hands.steer = clampf(action[STEER], -1.0, 1.0)
	hands.sheet = sheet_from_output(action[SHEET])
	var tack_high: bool = action[TACK] > TACK_THRESHOLD
	if tack_high and not tack_was_high and not in_manoeuvre:
		hands.tack = true
	return tack_high


## The sheet stick for a sheet output: 0 (the auto-sheet trims) inside the dead zone, and beyond it
## the rest of the way stretched to the full stick.
static func sheet_from_output(output: float) -> float:
	var size: float = absf(output)
	if size <= SHEET_DEAD_ZONE:
		return 0.0
	return signf(output) * clampf((size - SHEET_DEAD_ZONE) / (1.0 - SHEET_DEAD_ZONE), 0.0, 1.0)


## The tack the board is on: +1 starboard (the wind from starboard), -1 port. Away from head to wind
## and dead downwind the wind angle's sign says it; near them the sail's side does (it is on the
## leeward side: on port, -1, on starboard tack).
static func tack_of(telemetry: Telemetry) -> float:
	var off_wind_deg: float = absf(telemetry.twa_deg)
	if off_wind_deg > CLEAR_TACK_FROM_DEG and off_wind_deg < CLEAR_TACK_TO_DEG:
		return signf(telemetry.twa_deg)
	if telemetry.sail_side != 0:
		return -float(signi(telemetry.sail_side))
	return 1.0 if telemetry.twa_deg >= 0.0 else -1.0


## The stick that brings a board on a tack (+1 starboard, -1 port) to a wind angle off the wind
## (degrees, 0 to 180): a full stick for an error of TWA_FULL_STICK_DEG, none within
## TWA_DEAD_BAND_DEG (the heading hold keeps it there). Further off the wind than wanted, the board
## heads up: a right turn (+) on starboard tack, a left turn on port tack, which is the tack's sign.
## The angle is measured on the board's own tack, so a board just past head to wind (in irons) reads
## a little below 0 and bears away, and one by the lee reads a little over 180 and heads up.
static func steer_toward_twa(twa_deg: float, tack: float, wanted_off_wind_deg: float) -> float:
	var on_tack_deg: float = twa_deg * tack
	if on_tack_deg < -90.0:
		on_tack_deg += 360.0  # by the lee: past dead downwind, not past head to wind
	var error_deg: float = on_tack_deg - wanted_off_wind_deg
	if absf(error_deg) < TWA_DEAD_BAND_DEG:
		return 0.0
	return clampf(tack * error_deg / TWA_FULL_STICK_DEG, -1.0, 1.0)
