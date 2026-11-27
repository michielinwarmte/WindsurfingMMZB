class_name CommentaryConfig
extends Resource
## The numbers that tune the commentary (CommentaryDirector, RaceStory): how fast he talks, how soon a
## line may come again, which moments matter most, how late a line may still come, and what the race
## story counts as a chase, a fight, a good gybe, a near miss. The values live in
## res://config/commentary_default.tres (architecture rule 3); change them there and watch a race, or
## read a race's transcript (tools/race.sh ... --commentary=1).
##
## The real pace (Documentation/reports/broadcast/BANK_FORMAT.md): in the heat the starter bank comes
## from he says about 300 short sentences in 9 minutes of racing, in bursts with pauses of 1 to 3 s.
## Times are the director's own seconds: real seconds in the game (at 2x speed he does not talk twice
## as fast; he says less of the race), race seconds in the headless race tool.

@export_group("The pace")
## The pause after a line before the next one when there is something new to say, seconds (drawn
## between the two at every line; he draws breath).
@export var pause_min_s: float = 0.4
@export var pause_max_s: float = 1.5
## The pause before small talk (a quiet moment) when nothing has happened, seconds.
@export var quiet_pause_min_s: float = 1.0
@export var quiet_pause_max_s: float = 3.0
## The pause between the lines of a rundown (one line per board, down the order), seconds.
@export var rundown_pause_s: float = 0.3

@export_group("Not twice in a short time")
## A line (by its id) is not said again within this many seconds; a line with a slot, whose words
## change with the board ("{rider}." is his most said line by far), within repeat_slotted_line_s.
@export var repeat_line_s: float = 240.0
@export var repeat_slotted_line_s: float = 40.0
## The same words (after the slots are filled, whatever the line) are not said again within this.
@export var repeat_words_s: float = 90.0
## The same board is not identified again within this many seconds.
@export var identify_again_s: float = 40.0
## A quiet moment of the same kind is not taken again within these seconds.
@export var quiet_again_s: Dictionary[String, float] = {
	"identify": 5.0, "speed": 14.0, "leader": 22.0, "rundown": 70.0, "filler": 25.0, "camera": 35.0, "unsure": 45.0,
	"tactics": 20.0, "tension": 25.0, "form": 45.0, "conditions": 60.0,
}
## How often each quiet moment is chosen when he has nothing new to say (weights, not shares).
@export var quiet_weight: Dictionary[String, float] = {
	"identify": 3.0, "speed": 2.5, "leader": 2.0, "rundown": 1.5, "filler": 0.6, "camera": 0.7, "unsure": 0.7,
	"tactics": 1.5, "tension": 2.5, "form": 1.2, "conditions": 0.8,
}

@export_group("What matters most")
## How big each moment is: the director says the biggest pending moment first. A moment's level above
## 2 adds level_bonus per level (the leader's fall is bigger than a fall at the back).
@export var priority: Dictionary[String, float] = {
	"finish_win": 10.0, "photo_finish": 9.5, "lead_change": 9.0, "start_gun": 8.5, "fall": 8.0,
	"over_early": 7.5, "near_miss": 7.5, "airtime": 6.5, "gybe_bad": 6.0, "finish_place": 6.0,
	"last_leg": 5.5, "gybe_good": 5.5, "overtake": 5.0, "start_good": 5.0, "start_bad": 5.0,
	"fight": 4.5, "after_race": 4.5, "chase": 4.0, "mark_approach": 4.0, "gybe_safe": 3.5, "pre_start": 3.0,
	"trouble": 5.5, "rundown": 2.5, "leader": 2.0, "speed": 2.0, "identify": 2.0, "unsure": 1.0, "camera": 1.0,
	"filler": 1.0, "wow": 1.0, "oh_no": 1.0, "tension": 3.0, "tactics": 2.0, "form": 2.0, "conditions": 1.5,
}
@export var level_bonus: float = 1.0
## A moment about the board on the screen counts this much more; one about a board at the back (from
## back_from_place on) that is not on the screen this much less.
@export var focus_bonus: float = 1.5
@export var back_from_place: int = 6
@export var back_penalty: float = 1.5
## A moment this big cuts the line being said short (a lead change, a fall, the finish over small
## talk), if it is at least cut_margin bigger than that line's moment.
@export var cut_in_from: float = 7.0
@export var cut_margin: float = 3.0
## How late a moment's line may still come, seconds after the moment; later it is dropped, not said
## late. Moments not listed: late_default_s.
@export var late_s: Dictionary[String, float] = {
	"start_gun": 1.5, "near_miss": 3.0, "fall": 4.0, "airtime": 4.0, "finish_win": 4.0, "photo_finish": 3.0,
	"gybe_good": 5.0, "gybe_safe": 4.0, "gybe_bad": 5.0, "lead_change": 6.0, "overtake": 6.0, "over_early": 6.0,
	"mark_approach": 5.0, "start_good": 8.0, "start_bad": 8.0, "last_leg": 8.0, "finish_place": 8.0,
	"chase": 8.0, "fight": 10.0, "pre_start": 8.0, "after_race": 20.0, "trouble": 6.0,
}
@export var late_default_s: float = 5.0
## A rundown names the boards down the order to this place at most.
@export var rundown_places: int = 6
## These moments do not come twice in a row within not_in_a_row_s (three boards at a mark are not three
## mark approaches in a row); another moment between them, or the time passed, and they may.
@export var not_in_a_row: PackedStringArray = ["mark_approach", "gybe_safe", "chase", "fight", "pre_start", "start_good", "start_bad"]
@export var not_in_a_row_s: float = 6.0

@export_group("His reactions")
## A big moment (its level at least reaction_from_level) may get his reaction first, on its own, with
## the line about what happened straight after (BANK_FORMAT.md: "Wow." then the pass; "Oh no." then the
## fall): which reaction each moment takes, and how often (0 never, 1 always, when a reaction line fits).
@export var reaction: Dictionary[String, String] = {
	"lead_change": "wow", "overtake": "wow", "airtime": "wow", "gybe_good": "wow", "photo_finish": "wow",
	"finish_win": "wow", "chase": "wow", "fall": "oh_no", "near_miss": "oh_no", "trouble": "oh_no",
	"gybe_bad": "oh_no", "over_early": "oh_no",
}
@export var reaction_from_level: int = 3
@export var reaction_chance: float = 0.5
## The gap between the two lines of a pair (a reaction and its line, a place and its rider in a
## rundown), seconds: no breath between them.
@export var pair_gap_s: float = 0.15

@export_group("The race story: the order")
## The race is looked at this often, seconds of the race clock (airtime needs a quick eye).
@export var look_every_s: float = 0.05
## A new place counts once it has held this long, seconds (the smart order moves a little all the time).
@export var order_hold_s: float = 2.5
## No overtakes or lead changes are told this soon after the gun, seconds (the start's shuffle).
@export var order_from_s: float = 15.0
## The fleet counts as many (the `many` need) from this many boards.
@export var many_boards: int = 6
## Boards this close count as close together (the `close` need), metres.
@export var close_m: float = 15.0
## The leader is clear (the `big_lead` need) this far ahead of the second, metres.
@export var big_lead_m: float = 60.0

@export_group("The race story: the start")
## The fleet lining up (pre_start) is told at these race clock times in the countdown, seconds.
@export var pre_start_at_s: PackedFloat32Array = [-50.0, -28.0, -12.0]
## The start is judged this long after the gun, seconds: a good start crossed the line within
## good_start_within_s of the gun, planing; a bad start had not crossed by then (and was not over early).
@export var start_judge_s: float = 8.0
@export var good_start_within_s: float = 3.0

@export_group("The race story: on a leg")
## A chase: a board closing on the one ahead, within chase_near_m of it, at least chase_gain_m nearer
## than chase_window_s ago. Not again for the same two within chase_again_s.
@export var chase_near_m: float = 50.0
@export var chase_gain_m: float = 8.0
@export var chase_window_s: float = 8.0
@export var chase_again_s: float = 40.0
## A fight: two boards next to each other in the order within fight_m for fight_after_s. Not again for
## the same two within fight_again_s.
@export var fight_m: float = 15.0
@export var fight_after_s: float = 6.0
@export var fight_again_s: float = 45.0
## Fast (the `speed` small talk): planing at this share of the fleet's median planing speed or more.
@export var fast_share: float = 1.04
## A near miss: two racing boards this close, metres, closing on each other faster than near_speed_ms
## (two boards side by side in a fight are close but not closing). Not before near_from_s after the
## gun; not again for the same two within near_again_s.
@export var near_miss_m: float = 4.0
@export var near_speed_ms: float = 3.0
@export var near_from_s: float = 8.0
@export var near_again_s: float = 30.0
## Airtime: the water carries less than air_share of the board's weight for at least air_min_s, and
## the board lands and is still sailing air_land_s later.
@export var air_share: float = 0.08
@export var air_min_s: float = 0.25
@export var air_land_s: float = 1.0

## Trouble without a fall: off the plane for trouble_off_plane_s while most of the fleet planes (not
## round a mark), or down trouble_places places within trouble_window_s. Not again for the same board
## within trouble_again_s.
@export var trouble_off_plane_s: float = 3.0
@export var trouble_places: int = 2
@export var trouble_window_s: float = 15.0
@export var trouble_again_s: float = 30.0

@export_group("The race story: the small talk")
## Tactics: in dirty wind when the other sails' shadows take at least dirty_air_share of its wind (the
## race's own threshold: about half a full shadow, Skipper's dirty_air_share and the race tool's
## DIRTY_FACTOR, PH15); to windward or to leeward of the board next to it in the order within
## tactics_near_m when at least tactics_side_m up or down the wind from it; else of its straight line to
## the mark when at least tactics_line_m off it.
@export var dirty_air_share: float = 0.0375
@export var tactics_near_m: float = 25.0
@export var tactics_side_m: float = 4.0
@export var tactics_line_m: float = 25.0
## Tension: a place that matters (the lead, the last place on the podium) on its last tension_legs legs,
## the board behind within tension_s of it.
@export var tension_places: PackedInt32Array = [1, 3]
@export var tension_legs: int = 2
@export var tension_s: float = 3.0
## Form: up form_places places or more within form_window_s, or leading for form_lead_s.
@export var form_places: int = 2
@export var form_window_s: float = 60.0
@export var form_lead_s: float = 60.0
## The day (conditions and the needs): the wind's mean and the sea's height are smoothed over
## day_smooth_s of the race. The `wind_strong` need holds from wind_strong_kt (the mean true wind at
## 10 m), `wind_light` up to wind_light_kt; `choppy` from choppy_hs_m of significant wave height (m),
## `flat` up to flat_hs_m. The game's own numbers: the boards plane from about 10 kt and the matrix
## sails 12, 18 and 24 kt; the open water's waves are a fixed set of about 0.2 m, the lake's grow with
## the wind over its 3 km (PHYSICS_SPEC 9.17: about 0.17 m at 12 kt, 0.23 m at 16 kt, 0.34 m at 24 kt).
@export var day_smooth_s: float = 20.0
@export var wind_strong_kt: float = 22.0
@export var wind_light_kt: float = 13.0
@export var choppy_hs_m: float = 0.3
@export var flat_hs_m: float = 0.12

@export_group("The race story: the marks")
## A board of the front this near its next mark or gate is coming up to it (mark_approach), metres.
@export var mark_approach_m: float = 70.0
@export var mark_front: int = 3
## A rounding is watched from rounding_from_m before the mark (metres) until gybe_exit_s after the
## board's stern went through the wind (its wind angle changing sides beyond gybe_twa_deg), or, without
## a gybe, gybe_wait_s after the race counted the mark (seconds): the speed going in, the least speed
## through it, the time off the plane, how near the mark it went, a fall. Measured on the T2 slalom (27
## November 2026): the race counts the mark 3.3 to 4.8 s before the AI's stern goes through the wind,
## and its least speed comes about 4 s after that.
@export var rounding_from_m: float = 35.0
@export var gybe_wait_s: float = 8.0
@export var gybe_exit_s: float = 4.0
@export var gybe_twa_deg: float = 150.0
## Judged good: kept at least good_kept of its speed at its slowest, off the plane at most
## good_off_plane_s, within tight_m of the mark (a planing gybe, tight). Judged bad: it all but stopped
## (less than bad_kept of its speed) or went wider than wide_m. Safe otherwise. A fall is told as a fall.
## The AI's six gybes at the last mark of a T2 slalom at 18 kt (27 November 2026) went in at 23 to 24
## kt and slowed to 3 to 4 kt (13 to 18 % kept), 4 to 6 m from the mark, planing again 8 s later: none
## is good by these numbers, the three that kept less than 15 % are bad, the rest safe.
@export var good_kept: float = 0.5
@export var good_off_plane_s: float = 1.0
@export var tight_m: float = 8.0
@export var bad_kept: float = 0.15
@export var wide_m: float = 20.0

@export_group("The race story: the finish")
## A photo finish: two boards next to each other in the order, both within photo_m of the finish and
## within photo_close_m of each other; or crossing within photo_s of each other.
@export var photo_m: float = 50.0
@export var photo_close_m: float = 6.0
@export var photo_s: float = 1.0
## The verdict on the race (after_race) comes this long after the winner crossed, seconds, and again
## when the race is over.
@export var after_win_s: float = 8.0

@export_group("The subtitles")
## A subtitle stays this much longer than the line takes to say, and at least subtitle_min_s, seconds
## (time to read it).
@export var subtitle_linger_s: float = 1.2
@export var subtitle_min_s: float = 1.8

@export_group("The voice")
## The computer voice that speaks the lines (CommentaryVoice, SpeechEngine; commentary_voice.md): a
## ready-made Piper voice, NOT the commentator's. Its files are voices/<voice_name>.onnx and .onnx.json
## in the speech program's folder (tools/tts/fetch_tts.py fetches them).
@export var voice_name: String = "en_GB-northern_english_male-medium"
## Piper's own numbers, for every line: length_scale (above 1 slower, below 1 faster), the pause after
## each sentence (s), and how much the voice (noise_scale) and its timing (noise_w) vary. Changing one
## makes every line again (they are part of a line's name on the disk). Measured 28 November 2026 on
## the 76 starter lines: at 1.0 (and 0.2 s between sentences) the voice took 1.15 to 1.17 times his
## seconds (he talks fast); at 0.9 (and 0.15 s) 1.04 times, and Whisper read the lines back as well
## (word errors 9 % against 11 %). So 0.9.
@export var voice_length_scale: float = 0.9
@export var voice_sentence_silence_s: float = 0.15
@export var voice_noise_scale: float = 0.667
@export var voice_noise_w: float = 0.8
## How each level (1 calm, 2 his race voice, 3 lifted, 4 shouting) is said: the rate the sound is
## played at (faster and higher together, like a tape played faster: 1.06 is 6 % faster and one
## semitone higher) and its loudness (dB). Modest on purpose: a shout a little faster, higher and louder.
@export var voice_rate_by_level: PackedFloat32Array = [0.97, 1.0, 1.03, 1.06]
@export var voice_db_by_level: PackedFloat32Array = [-2.0, 0.0, 1.5, 3.0]
## How long a line's sound may be waited for: this share of his seconds, at least voice_wait_min_s and
## at most voice_wait_max_s. Later, the line stays silent (its subtitle shows): too late is dropped,
## not said late.
@export var voice_wait_share: float = 0.3
@export var voice_wait_min_s: float = 0.3
@export var voice_wait_max_s: float = 0.8
## A line cut short (or followed at once by the next) fades out in this many seconds: no click.
@export var voice_fade_s: float = 0.06
## The bank's lines without a slot made ahead in the background, the most said first, at most this
## many (each about 40 to 150 kB on the disk; 0: none).
@export var voice_warm_up_lines: int = 400
## Names the voice says badly, spelled the way it says them well (the written name -> what the voice
## is given). Only the sound changes; the subtitle keeps the name. Checked by reading the voice's
## sound back with Whisper (tools/tts/read_back.py).
@export var voice_spellings: Dictionary[String, String] = {}


## The moment's priority with its size and the camera counted (see priority, focus_bonus).
func weight_of(moment: RaceMoment, focus: int, place: int) -> float:
	var weight: float = priority.get(moment.moment, 1.0) + maxf(moment.level - 2, 0) * level_bonus
	if moment.board >= 0 and (moment.board == focus or moment.board2 == focus):
		weight += focus_bonus
	elif place >= back_from_place:
		weight -= back_penalty
	return weight


func late_of(moment: String) -> float:
	return late_s.get(moment, late_default_s)
