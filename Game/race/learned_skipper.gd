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
## The names of the outputs in the wind-angle mode (the third is not used).
const TWA_ACTION_NAMES: PackedStringArray = ["twa", "sheet", "unused"]
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
	## Wind-angle mode: the angle the last decision asked for (degrees, positive from starboard),
	## and whether there has been a decision yet.
	var wanted_twa_deg: float = 0.0
	var has_wish: bool = false
	## Stick mode: whether the tack output was high at the last decision.
	var tack_was_high: bool = false
	## Seconds since the last tack or gybe this driver asked for, and since the last manoeuvre ended.
	var since_tack_request_s: float = 1.0e9
	var since_manoeuvre_s: float = 1.0e9

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
		has_wish = true

	## Every tick, before the controller's update (wind-angle mode only; the stick mode's hands stay
	## as the last decision left them). The angle wanted is clearly on the other tack: ask for a tack
	## or gybe (the controller picks which), unless one is under way, ended less than TACK_HOLD_S
	## ago, or was asked for less than TACK_REQUEST_EVERY_S ago. Otherwise steer toward the angle
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
		if clearly_other_tack and not in_manoeuvre and since_manoeuvre_s >= TACK_HOLD_S and since_tack_request_s >= TACK_REQUEST_EVERY_S:
			hands.tack = true
			hands.steer = 0.0
			since_tack_request_s = 0.0
			return
		hands.steer = LearnedSkipper.steer_toward_twa(telemetry.twa_deg, tack, off_wind_deg)


var brain: NeuralNet = null
## The brain file's name (night_best, ...), shown on the results and the labels.
var brain_name: String = "brain"
var decision_ticks: int = DECISION_TICKS

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
	_controller.hands = _hands
	_ticks_to_decision = 0
	_since_manoeuvre_s = RaceObservation.SINCE_MANOEUVRE_SCALE_S


func skipper_name() -> String:
	return brain_name


## A learned skipper sails under a purple sail.
func sail_colour() -> Color:
	return Color(0.6, 0.35, 0.9)


## The wind field to sample the gusts around the board from.
func set_wind_field(wind: WindField) -> void:
	_wind = wind


## The other boards: where they are (game X, Z) and how fast they move (m/s in X, Z). Never given:
## the skipper sees no one.
func set_others(positions: PackedVector2Array, velocities: PackedVector2Array) -> void:
	_others_positions = positions
	_others_velocities = velocities


## Every tick, before the controller's update: a new decision every decision_ticks ticks, and the
## hands steered toward it (in the wind-angle mode) in between.
func update(telemetry: Telemetry, dt: float) -> void:
	if _controller == null or _hands == null:
		return
	var in_manoeuvre: bool = _controller.manoeuvre != PlayerController.Manoeuvre.NONE
	_ticks_to_decision -= 1
	if _ticks_to_decision <= 0:
		_ticks_to_decision = maxi(decision_ticks, 1)
		_decide(telemetry, in_manoeuvre)
	if telemetry.sailor_state == WindsurferSim.SailorState.SAILING:
		_driver.steer(telemetry, in_manoeuvre, dt)
	# The clock since the last manoeuvre moves on after the decision, as RaceEnv moves it in the
	# tick that follows its decision: both see the same number.
	_since_manoeuvre_s = RaceObservation.advance_since_manoeuvre(_since_manoeuvre_s, in_manoeuvre, dt)


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
	var observation: PackedFloat32Array = RaceObservation.build(telemetry, _race, _index, _wind,
			_others_positions, _others_velocities, in_manoeuvre, _since_manoeuvre_s)
	last_action = brain.forward(observation)
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
