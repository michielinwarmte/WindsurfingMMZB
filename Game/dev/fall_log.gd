class_name FallLog
extends RefCounted
## What the board and the sailor did in the 2 s before each fall, for the harnesses (run_lake.gd,
## run_matrix.gd, run_race.gd): one line per fall, "FALL_DETAIL,<the columns of HEADER>", so a
## round's outputs can be grouped by which fall rule fired, at what heel, in what situation
## (tools/fall_detail.py; Documentation/reports/autopilot/stay_on_the_board.md).
##
## Call watch() once a tick, after the simulation's step. A dev tool: it reads the simulation's own
## fields (the heel the fall checks read, the body's tipping), as run_push.gd does.

const BACK_S: float = 2.0
const DT_GUESS: float = 1.0 / 60.0
## The columns after the situation (harness, case, clock, wind): the kind and time of the fall, the
## state at the last tick before it, and the 2 s before it.
const HEADER: String = "harness,case,clock,wind,kind,time_s,lee_fall_heel_deg,lee_board_heel_deg,windward_tip_deg,deliberate_deg,pull_n,pull_share,side_n,hand_roll_nm,tip_share,tipping_s,feet_excess_nm,feet_pitch_excess_nm,pitch_deg,pitch_rate_dps,sheet,alpha_deg,speed_kt,twa_deg,tws_sail_kt,support_share,yaw_rate_dps,lean,lee_max2,tip_max2,tip_share_max2,pitch_min2,pitch_max2,support_min2,air_share2,sheet_m2,sheet_m1,sheet_m05,side_max2,pull_share_max2,yaw_abs_max2,lee_over15_s,windward_over19_s"

## The situation the harness gives (written into every line).
var harness: String = ""
var case_name: String = ""
var clock: String = ""
var wind: String = ""
var _history: Array[PackedFloat32Array] = []
var _was_fallen: bool = false

# The slots of one sample.
const LEE: int = 0
const BOARD_LEE: int = 1
const TIP: int = 2
const DELIBERATE: int = 3
const PULL: int = 4
const PULL_SHARE: int = 5
const SIDE: int = 6
const HAND_ROLL: int = 7
const TIP_SHARE: int = 8
const TIPPING_S: int = 9
const EXCESS: int = 10
const PITCH_EXCESS: int = 11
const PITCH: int = 12
const PITCH_RATE: int = 13
const SHEET: int = 14
const ALPHA: int = 15
const SPEED: int = 16
const TWA: int = 17
const TWS: int = 18
const SUPPORT: int = 19
const YAW: int = 20
const LEAN: int = 21
const SLOTS: int = 22


func _init(harness_name: String = "", case_text: String = "", clock_text: String = "", wind_text: String = "") -> void:
	harness = harness_name
	case_name = case_text
	clock = clock_text
	wind = wind_text


## One tick: the line of a fall that happened in this tick, or "".
func watch(sim: WindsurferSim) -> String:
	var fallen: bool = sim.sailor_state == WindsurferSim.SailorState.FALLEN
	var line: String = ""
	if fallen and not _was_fallen and not _history.is_empty():
		line = _line(sim)
		_history.clear()
	elif not fallen:
		_history.append(_sample(sim))
		if _history.size() > int(BACK_S / DT_GUESS) + 2:
			_history.pop_front()
	_was_fallen = fallen
	return line


## The state of the board and the sailor now, as the fall checks see it (WindsurferSim._check_balance).
func _sample(sim: WindsurferSim) -> PackedFloat32Array:
	var t: Telemetry = sim.telemetry
	var s: PackedFloat32Array = PackedFloat32Array()
	s.resize(SLOTS)
	var tack: float = 1.0 if t.twa_deg >= 0.0 else -1.0
	var lee_rad: float = -sim._fall_heel_rad() * tack
	var weight_n: float = sim.sailor_config.mass_kg * sim.sim_config.gravity_ms2
	var pull_n: float = SimMath.horizontal(sim.hand_force_world).length()
	s[LEE] = rad_to_deg(lee_rad)
	s[BOARD_LEE] = -t.heel_deg * tack
	s[TIP] = rad_to_deg(-lee_rad - atan2(pull_n, weight_n))
	s[DELIBERATE] = rad_to_deg(maxf(-sim._wanted_bank_rad * tack, 0.0))
	s[PULL] = pull_n
	s[PULL_SHARE] = pull_n / weight_n
	s[SIDE] = absf(t.side_force_n)
	s[HAND_ROLL] = t.hand_moment_roll_nm
	var hip_max: float = sim.sailor_config.hip_force_max_n + sim.sailor_config.harness_hold_max_n * clampf(absf(sim.lean), 0.0, 1.0)
	s[TIP_SHARE] = sim._tipping_force_world.length() / maxf(hip_max, 1.0)
	s[TIPPING_S] = sim._tipping_for_s
	s[EXCESS] = t.feet_moment_excess_nm
	s[PITCH_EXCESS] = sim.feet_pitch_excess_nm
	s[PITCH] = t.pitch_deg
	s[PITCH_RATE] = t.pitch_rate_dps
	s[SHEET] = t.sheet
	s[ALPHA] = t.alpha_deg
	s[SPEED] = t.speed_kt
	s[TWA] = t.twa_deg
	s[TWS] = t.tws_at_sail_kt
	s[SUPPORT] = (t.buoyancy_n + t.planing_lift_n) / maxf(t.total_mass_kg * sim.sim_config.gravity_ms2, 1.0)
	s[YAW] = t.yaw_rate_dps
	s[LEAN] = t.lean
	return s


func _line(sim: WindsurferSim) -> String:
	var last: PackedFloat32Array = _history[_history.size() - 1]
	var cells: PackedStringArray = [harness, case_name, clock, wind, sim.fall_kind, "%.2f" % sim.time_s]
	for slot: int in SLOTS:
		cells.append("%.3f" % last[slot])
	var lee_max: float = -INF
	var tip_max: float = -INF
	var tip_share_max: float = 0.0
	var pitch_min: float = INF
	var pitch_max: float = -INF
	var support_min: float = INF
	var air: int = 0
	var side_max: float = 0.0
	var pull_share_max: float = 0.0
	var yaw_max: float = 0.0
	for s: PackedFloat32Array in _history:
		lee_max = maxf(lee_max, s[LEE])
		tip_max = maxf(tip_max, s[TIP])
		tip_share_max = maxf(tip_share_max, s[TIP_SHARE])
		pitch_min = minf(pitch_min, s[PITCH])
		pitch_max = maxf(pitch_max, s[PITCH])
		support_min = minf(support_min, s[SUPPORT])
		if s[SUPPORT] < 0.3:
			air += 1
		side_max = maxf(side_max, s[SIDE])
		pull_share_max = maxf(pull_share_max, s[PULL_SHARE])
		yaw_max = maxf(yaw_max, absf(s[YAW]))
	cells.append_array(["%.3f" % lee_max, "%.3f" % tip_max, "%.3f" % tip_share_max, "%.3f" % pitch_min, "%.3f" % pitch_max,
		"%.3f" % support_min, "%.3f" % (float(air) / float(_history.size())),
		"%.3f" % _back(SHEET, 2.0), "%.3f" % _back(SHEET, 1.0), "%.3f" % _back(SHEET, 0.5),
		"%.1f" % side_max, "%.3f" % pull_share_max, "%.1f" % yaw_max,
		"%.2f" % _time_above(LEE, 15.0), "%.2f" % _time_above(TIP, 19.0)])
	return "FALL_DETAIL," + ",".join(cells)


## A slot's value back_s before the last sample.
func _back(slot: int, back_s: float) -> float:
	var index: int = clampi(_history.size() - 1 - int(round(back_s / DT_GUESS)), 0, _history.size() - 1)
	return _history[index][slot]


## How long, up to the fall, a slot had stayed above a value without a break (s).
func _time_above(slot: int, value: float) -> float:
	var count: int = 0
	for i: int in range(_history.size() - 1, -1, -1):
		if _history[i][slot] <= value:
			break
		count += 1
	return float(count) * DT_GUESS
