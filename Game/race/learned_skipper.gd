class_name LearnedSkipper
extends RefCounted
## A skipper whose decisions come from a trained neural network (RACING_PLAN.md, "The learned
## skipper"). Ten times a second it builds what it sees (RaceObservation), asks the brain "what
## now?", and puts the three answers on the controls: how hard to turn, how much to sheet, whether
## to tack or gybe now. Between two answers the last one is held, as a sailor's hands stay where they
## were. It drives the board through the same beginner controller the player uses (RD1), with the
## auto-sheet on, so it can do nothing a player could not.
##
## The trainer (RaceEnv) turns the network's numbers into the hands with the same apply_action()
## as here, so a brain sails in the game exactly as it sailed in training.
##
## Use: setup() once, then every tick, before controller.update(): update(telemetry, dt). Give it
## the other boards with set_others() every tick (or at least every decision) if there are any.

## Index of each action in the network's output.
const STEER: int = 0
const SHEET: int = 1
const TACK: int = 2
const ACTION_NAMES: PackedStringArray = ["steer", "sheet", "tack"]
## A tack or gybe is asked for when the tack output rises above this.
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

var brain: NeuralNet = null
var decision_ticks: int = DECISION_TICKS

var _sim: WindsurferSim = null
var _controller: PlayerController = null
var _hands: AiHands = null
var _race: RaceSim = null
var _index: int = 0
var _wind: WindField = null
var _others_positions: PackedVector2Array = PackedVector2Array()
var _others_velocities: PackedVector2Array = PackedVector2Array()
## Ticks until the next decision; 0 decides on the next update.
var _ticks_to_decision: int = 0
## Whether the tack output was high at the last decision: a tack is asked for only as it goes high.
var _tack_was_high: bool = false
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
	_race = race
	_index = index
	_wind = sim.wind if sim != null else null
	_controller.hands = _hands
	_ticks_to_decision = 0
	_tack_was_high = false
	_since_manoeuvre_s = RaceObservation.SINCE_MANOEUVRE_SCALE_S


## The wind field to sample the gusts around the board from.
func set_wind_field(wind: WindField) -> void:
	_wind = wind


## The other boards: where they are (game X, Z) and how fast they move (m/s in X, Z). Never given:
## the skipper sees no one.
func set_others(positions: PackedVector2Array, velocities: PackedVector2Array) -> void:
	_others_positions = positions
	_others_velocities = velocities


## Every tick, before the controller's update: a new decision every decision_ticks ticks, the last
## one held between them.
func update(telemetry: Telemetry, dt: float) -> void:
	if _controller == null or _hands == null:
		return
	var in_manoeuvre: bool = _controller.manoeuvre != PlayerController.Manoeuvre.NONE
	_ticks_to_decision -= 1
	if _ticks_to_decision <= 0:
		_ticks_to_decision = maxi(decision_ticks, 1)
		_decide(telemetry, in_manoeuvre)
	# The clock since the last manoeuvre moves on after the decision, as RaceEnv moves it in the
	# tick that follows its decision: both see the same number.
	_since_manoeuvre_s = RaceObservation.advance_since_manoeuvre(_since_manoeuvre_s, in_manoeuvre, dt)


## One decision: what the board sees, through the brain, onto the hands.
func _decide(telemetry: Telemetry, in_manoeuvre: bool) -> void:
	if brain == null or _race == null:
		return
	if telemetry.sailor_state != WindsurferSim.SailorState.SAILING:
		# In the water the hands hold nothing, and no tack is left waiting for when the sailor is
		# back up (RaceEnv.act() skips these decisions the same way).
		_hands.tack = false
		return
	var observation: PackedFloat32Array = RaceObservation.build(telemetry, _race, _index, _wind,
			_others_positions, _others_velocities, in_manoeuvre, _since_manoeuvre_s)
	last_action = brain.forward(observation)
	_tack_was_high = apply_action(_hands, last_action, _tack_was_high, in_manoeuvre)


## Puts the network's three numbers on the hands: the steer as it is (a stick from -1 to 1), the
## sheet through the dead zone (SHEET_DEAD_ZONE), and a tack or gybe asked for when the tack output
## has just risen above TACK_THRESHOLD and none is under way. Returns whether the tack output is
## high now, which the caller keeps for the next decision.
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
