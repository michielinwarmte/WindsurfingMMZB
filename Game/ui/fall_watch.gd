class_name FallWatch
extends RefCounted
## What came before the last fall, for the HUD's detail panel (GP0's playtest; point 4 of
## Documentation/reports/gameplay/gp0_measure.md: before a catapult the sailor strains and the
## board rounds up, and the fin does not warn). It keeps the last KEEP_S seconds of the numbers
## that warn, or do not, and when the sailor falls it freezes them as a small table, so the player
## can read in the water what the board did 1 s and 0.5 s before. It only reads the telemetry.

const KEEP_S: float = 1.5
## How long before the fall each row of the table is; 0 is the last tick before it.
const BACK_S: PackedFloat64Array = [1.0, 0.5, 0.0]


## One tick, measured on the sail's side, so it reads the same on either tack.
class Sample:
	var time_s: float = 0.0
	## The moment the feet are asked to pass beyond what they can, toward the sail: the pull
	## that tips the sailor over it (Telemetry.feet_moment_excess_nm).
	var overload_nm: float = 0.0
	## The fin's lift coefficient as a share of its peak.
	var fin_share: float = 0.0
	## How fast the bow turns toward the wind.
	var heading_up_dps: float = 0.0
	var pitch_deg: float = 0.0
	var heel_to_leeward_deg: float = 0.0


## The frozen table of the last fall, or empty before the first.
var last_fall_text: String = ""
var _samples: Array[Sample] = []
var _was_sailing: bool = true


## Called with every tick's telemetry.
func add(t: Telemetry) -> void:
	var sailing: bool = t.sailor_state == WindsurferSim.SailorState.SAILING
	if sailing:
		_samples.append(sample_of(t))
		while _samples.size() > 1 and _samples[-1].time_s - _samples[0].time_s > KEEP_S:
			_samples.pop_front()
	elif _was_sailing and not _samples.is_empty():
		last_fall_text = _describe(t.fall_kind, t.time_s)
		_samples.clear()
	_was_sailing = sailing


## The numbers of one tick. On starboard tack (wind from starboard) the sail is to port: a
## positive excess (the body tipped to port) is toward the sail, a negative yaw rate (the bow to
## starboard) is heading up, and a negative heel is to leeward. On port tack all three flip.
static func sample_of(t: Telemetry) -> Sample:
	var windward: float = 1.0 if t.twa_deg >= 0.0 else -1.0
	var s: Sample = Sample.new()
	s.time_s = t.time_s
	s.overload_nm = t.feet_moment_excess_nm * windward
	s.fin_share = t.fin_load_share
	s.heading_up_dps = -t.yaw_rate_dps * windward
	s.pitch_deg = t.pitch_deg
	s.heel_to_leeward_deg = -t.heel_deg * windward
	return s


func _describe(kind: String, time_s: float) -> String:
	var lines: PackedStringArray = ["LAST FALL: %s at %.0f s      feet overload   fin load      bow heading up   nose up   heel to leeward" % [kind.to_upper(), time_s]]
	for back_s: float in BACK_S:
		var s: Sample = _sample_before(back_s)
		var when: String = "just before" if back_s <= 0.0 else "%.1f s before" % back_s
		lines.append("  %-12s              %5.0f N m    %3.0f %% of stall   %5.0f deg/s    %5.1f deg   %5.1f deg" % [
			when, maxf(s.overload_nm, 0.0), s.fin_share * 100.0, s.heading_up_dps, s.pitch_deg, s.heel_to_leeward_deg])
	return "\n".join(lines)


## The kept tick nearest to back_s before the last one.
func _sample_before(back_s: float) -> Sample:
	var wanted_s: float = _samples[-1].time_s - back_s
	for s: Sample in _samples:
		if s.time_s >= wanted_s - 0.001:
			return s
	return _samples[-1]
