# Staying on the board: the fall's bar moved and the autopilot's recovery reflex (6 November 2026)

For Max and Michiel. Written 6 November 2026 by Claude Opus 5.5 on Max's PC, on the branch
`autopilot/stay-up` (from `play/6nov-evening` f72f565). Not pushed, not merged. Every number below is
from a run whose output is kept under `.sim_output/` (the paths are given, the logs in
`.logs/stay_up/`); estimates are called estimates.

Max asked: *"The autopilot still crashes. The detection of what a crash would be is too strict. Move
this bar and make the autopilot try harder to stay on the board."*

## In short

- **The AI fleet's lake races went from 14 falls to 1.** Two races of 11 personas on the lake at
  14:30 (iQFOiL O2 and LG2, the countdown and 7 minutes of racing each): 14 falls before, 1 after (a
  board standing on its tail at walking pace on the beat; 0 with the reflex's first, quicker step, which
  broke the fleet's start test). On six
  other hours of the lake (180 cases) 13 falls before, 1 after; on the open water's manoeuvre
  matrix 1 before, 0 after. The places where the game did not fall before still do not, at the same
  speed (the afternoon reaches 17.9 / 10.1 / 9.4 kt before and after; the open water's push check
  8.96 / 10.89 m/s before, 8.98 / 10.87 after).
- **Why it fell.** Every catapult (14 of them across the sets) happened with the board in the air or
  nearly, the sail already eased by last night's ease in the air, the pull on the hands only 0.04 to 0.33
  of the sailor's weight and the board itself heeled 11 to 24 degrees. What crossed the old 20 degree line
  was the heel *the sailor's sense of balance* reads, which swells when the body is near free fall off a
  crest. The other big group (7 of the 14 race falls) was not the bar at all: boards waiting for the
  start at walking pace raised their nose to 80 degrees in 7 s and the sailor "fell off".
- **The bar (physics, for Michiel's OK; section 2).** A catapult now needs the felt heel past **30**
  degrees (was 20) **for 0.2 s**, with a pull of **at least 0.2 of the weight**; a fall backwards past
  **32** (was 25) **for 0.3 s**; falling off past **50** (was 40); the hips hold a tipped body **0.5 s**
  (was 0.3). With the old numbers the rule is the old one bit for bit, and a sheeted sail at 24 kt still
  throws the sailor over it.
- **The reflex (the autopilot tries harder; section 3).** The sailor now feels how near the limit they
  are and, from 65 % of the way, lets the sheet go fast, bears away and presses the heels (pulled over),
  or sheets in fast (falling back with the sail drawing); at walking pace a rising nose steps the sailor
  forward. It fades out above 80 % on the push slider, so the pushed dial keeps its risk.
- **Not cured:** a board rolled to windward out of irons at walking pace (1 case in 180); the very late
  starts of a few personas stuck before the gun (in the baseline too); the felt heel's free-fall swelling
  itself (a physics question, section 8); the tail-stand once more on a beat.
- **Checks:** unit tests 886 of 886; `tools/check.sh` 461 files, 0 failed; validation the same eight
  known reds (38 pass, 8 fail, 2 pending); `tools/lan_test.sh --map=lake` SYNC CHECK: PASS (run once the
  live play-test on this PC was over).

## 1. Where and how it fell before (the baseline)

The game as it came (f72f565), sailed by the beginner controller (the autopilot every AI board and the
beginner player sail with). A new recorder (`Game/dev/fall_log.gd`) writes every fall with the 2 s
before it, and `tools/fall_detail.py` groups them: which rule fired, at what heel, with what pull,
pitch and sheet, and in what situation (`python -I tools/fall_detail.py <folder> --list=1`).

| Set | Cases | Falls | What they were |
|---|---|---|---|
| Lake, the standard set: the map's wind at 12:00, 14:30, 17:00, a steady 18 and 24 kt at those hours, the lake's waves 1x, and the ten afternoon reaches (`.sim_output/autopilot/su0/base/`) | 130 | **0** | (last night's tuning holds on these) |
| Lake, six other hours: 12:15, 12:45, 13:45, 15:15, 16:15, 16:45, the same three winds (`.sim_output/autopilot/su0b/base/`) | 180 | **13** (9 separate events: five cases share their first 25 s) | 11 catapults (7 events) on the steady 24 kt beam reach and in tacks, **every one with the board in the air and the sail already eased** (1 to 5 degrees of angle of attack), the pull on the hands 0.04 to 0.27 of the sailor's weight, the board itself heeled only 11 to 19 degrees; 2 "fell off" out of irons at walking pace (rolled 52 to 54 degrees to windward) |
| Open water, the push check in gusts and waves at 12, 18, 24 kt (`su0/base/push*`) | 15 | **0** | made good 8.96 m/s neutral, 10.89 pushed |
| Open water, the manoeuvre matrix, flat (`su0/base/matrix`) | 24 | **1** | the 24 kt gybe from a beam reach: a catapult with the board light, pull 0.21 of the weight |
| Two lake races at 14:30, 11 personas (Aiko, Bruno, Elin, Greta, Hana, Ines, Jonas, Kofi, Lena, Liv, Mara), the countdown and 7 minutes of racing: iQFOiL O2 (seed 1) and LG2 (seed 2) (`.sim_output/stay_up/su0/race_*`) | 22 boards | **14** (O2 8, LG2 6) | **6 catapults**, all with the board in the air on a close or beam reach and the sail eased, the pull 0.10 to 0.33 of the weight; **8 "fell off"**: 7 of them a board standing on its tail (pitch 75 to 88 degrees) at walking pace before the start or on the beat, 1 rolled to windward at 2 kt |

**What the falls say.**

1. **The catapults are the bar.** Every catapult in the baseline happened with the board light or in
   the air for a quarter to a half of the 2 s before, and with the sail eased by last night's ease in
   the air (1 to 7 degrees of angle of attack). The pull on the hands was 0.04 to 0.33 of the sailor's
   weight (median 0.14). The board itself was heeled only 11 to 24 degrees; what crossed the 20 degree
   line was the heel *the fall check feels*: the gravity the sailor feels, less the body's own
   acceleration, averaged over a second. With the board dropping off a crest the body is close to free
   fall, the felt "down" shrinks, and a small sideways push turns into a large felt heel (9 to 34 degrees
   in 0.3 s, last night's report). A real sailor with an eased sail in the air is not thrown over the
   boom by that.
2. **The tail-stands are not the bar.** Before the start (holding back to wait) and on the beat after
   a stop, a board at 1 to 3 km/h raised its nose from 17 to 80 degrees in 7 s while the sailor stood
   by the mast foot (Bruno on a 108 L board, Mara and Elin on 125 to 129 L; the trace:
   `.sim_output/stay_up/su0trace/race_iq_lg2/trace_bruno.csv`). The board floats 85 to 90 % under water
   at rest there and the feet's force holds 60 to 70 N·m nose-up; nothing brings the nose down, and at
   80 degrees the heel the check reads means nothing and "fell off" fires. That is a physics question for
   Michiel (section 8); the reflex below steps the sailor forward when it starts.
3. **Out of irons at walking pace** the board rolls to windward with the sail luffing (side force 8 to
   21 N) until the standing limit.

## 2. The bar moved (for Michiel's OK)

`Game/sim/windsurfer_sim.gd` (`_check_balance(dt)`), `Game/sim/config/sailor_config.gd`,
`Game/config/sailor_default.tres`; PHYSICS_SPEC.md 7.7 has the same table. Every new lever is a config
number; a fresh `SailorConfig` (the code's defaults) is the old rule, and with the old numbers in the
`.tres` the game is the old game bit for bit (`test_stay_on_the_board.gd`:
`test_the_old_numbers_throw_the_sailor_at_once_past_20_degrees`).

| Number | Before | Now | Why |
|---|---|---|---|
| `catapult_heel_deg` | 20 | **30** | A hooked-in sailor with bent knees and the feet in the straps rides a leeward heel with the ankles, the knees and the hips; 20 degrees is well inside what the ankles alone roll (an estimate: the ankle's roll is 20 to 35 degrees, more with the knees). In the baseline every catapult came with the board itself heeled 11 to 24 degrees and the sail eased; only the felt heel crossed 20 |
| `catapult_pull_share` | 0 (any pull over 120 N) | **0.2** | A catapult is the sail's pull levering the sailor over the boom. A pull under a fifth of the weight (167 N for 85 kg) a body holds by leaning back 15 cm: at the boom 1.5 m up it is 250 N·m; the feet pass 120 N·m and the weight 15 cm back 125 N·m (the model's own numbers). The baseline's catapults had 0.04 to 0.33 of the weight (median 0.14), nearly all in the air with the sail eased |
| `catapult_time_s` | 0 | **0.2 s** | A wave's roll and a landing's jolt last a tenth to a few tenths of a second (at 24 kt on the lake the board leaves the water for 0.27 s at a time); a heel that stays past the limit for 0.2 s with the pull on is a catapult. Estimate |
| `fall_back_heel_deg` | 25 | **32** | Moved with the catapult, still below the standing limit. The windward tip is measured after the pull's help (atan(pull / weight)), so it counts only what the body has to catch. Estimate |
| `fall_back_time_s` | 0 | **0.3 s** | A fall backwards needs the pull gone for longer than a jolt: a hiked sailor whose sail goes light over a crest for a moment catches it by sheeting in or bending at the hips. Estimate |
| `standing_fall_heel_deg` | 40 | **50** | Standing (no pull to hang on), the knees and the boom in the hands hold a board heeled 40 degrees; at 50 the deck is steeper than wet feet hold. The backstop for any board rolled that far, whatever the sail does. Estimate |
| `tip_time_s` | 0.3 s | **0.5 s** | The hips, the knees and the arms on the boom hold a body tipped harder than they can for a moment; half a second is a reaction (0.2 to 0.3 s) and a move (the sheet out, a step). Estimate. The front foot's brief pull in its strap, which shared this time, keeps its 0.3 s (`front_foot_pull_brief_s`), so the board's pitch is unchanged |
| `fall_feel_time_s` | 1.0 s | 1.0 s (unchanged) | No fall in the baseline was set off by a short push |

**The bar alone (round 1, the reflex off):** the six other lake hours 13 falls to 3 (no catapult
left; 2 rolled to windward at walking pace, 1 tail-stand), the two races 14 to 3 (the 3 tail-stands).

**Falls stay possible.** A sheeted sail at 24 kt, held in through a head-up, still throws the sailor
over it 0.9 s after the head-up (`test_a_sheeted_sail_at_24_kt_still_throws_the_sailor_with_the_new_bar`;
the board heels 44 degrees before the sailor goes, where it was under 30:
`test_windsurfer_sim.gd`'s catapult test now checks it stays below the standing limit), the body's
tipping rule (the hips) works as before apart from its time, and the standing limit catches any board
rolled far enough whatever the sail does. With the push slider at 100 % (the reflex off there) at 24 kt in the open water's gusts and waves
(`run_push.gd --push=1`, three courses of 120 s; `.sim_output/stay_up/push100_*`): no fall before or
after (it did not fall there before either: the pushed dial's warning test, a known red, still finds no
catapult), made good 7.95 / 15.07 / 14.22 m/s before and 7.92 / 15.07 / 13.92 after (the 135 degree
reach 2 % slower, the pilot's head-up fade reading the new catapult heel).

## 3. The recovery reflex (the autopilot tries harder)

`Game/windsurfer/player_controller.gd` (`reflex_on` and the `reflex_*` settings; `Game/sim/autopilot.gd`
is unchanged). The sailor feels the fall coming from the simulation's new sense of balance
(`Telemetry.lee_fall_share`, `windward_fall_share`, `tipping_share`: how far toward the limit the fall
check uses, 0 in balance, 1 at the limit) and fights it before the rule fires:

| Danger | What the sailor does | Settings (default) |
|---|---|---|
| Pulled over the sail (the heel to leeward, or the body tipping toward the sail) from 65 % of the way to the limit, all of it from 90 % | eases the sheet fast (4 of its range a second: a quick release of the back hand) toward 6 degrees of angle of attack, and from 95 % (the last chance) toward 1 degree, nearly let fly; bears away at up to 8 degrees a second (not in a tack or gybe, not past 130 degrees from the wind); presses the heels to flatten the board (planing in the straps; not when the body is on the mouse) | `reflex_from_share` 0.65, `reflex_full_share` 0.9, `reflex_alpha_deg` 6, `reflex_last_share` 0.95, `reflex_last_alpha_deg` 1, `reflex_sheet_rate_per_s` 4, `reflex_bear_away_dps` 8, `reflex_bear_away_max_twa_deg` 130, `reflex_heel_press` 1, `reflex_tip_from_share` 0.7 |
| Falling back (the windward tip, or the body tipping away from the sail) | sheets in fast toward 18 degrees of angle of attack ("when in doubt, sheet in"), but only with the wind on the sail's own side and faster than walking pace: a backed sail sheeted in pushes the sailor further over (round 1, below) | `reflex_catch_alpha_deg` 18 |
| The nose rising at walking pace (below 3 m/s) and staying up for a second | steps forward toward the mast from 10 degrees of pitch, all the way from 20 | `reflex_slow_ms` 3, `reflex_nose_up_deg` 10, `reflex_nose_up_full_deg` 20, `reflex_nose_up_hold_s` 1 |
| After the danger | the danger felt fades over 0.3 s; the pilot then sheets in again at its own pace from where the reflex left the sail | `reflex_hold_s` 0.3 |
| The push slider | the reflex fades out above 80 % and is gone at 100 %: the pushed dial keeps its risk (GP1, GP3) | `reflex_push_fade_from` 0.8 |

Last night's ease in the air (the sheet out over a crest in strong wind and short chop) and its quick
sheet-in on landing are kept as they were; with the pull share in the bar, an eased sail in the air no
longer throws the sailor, which is what that ease was fighting. `reflex_on` false is the controller as
before, bit for bit.

## 4. How it was tuned (the rounds)

The compute was shared with two other agents and then a live LAN play-test (at most 6, later 4
processes), so the rounds are few and each was chosen from the baseline's falls. Every round sailed a
frozen copy of the project (`tools/autopilot_suite.sh --project=`), so the code could be edited while it
ran. The variants files are in `Documentation/reports/autopilot/rounds/su*.txt`.

| Round | What | Sets | Result |
|---|---|---|---|
| su0, su0b, races su0 | the baseline | standard lake set + open water (su0), six other hours (su0b), two races | section 1 |
| race probe, su0trace | where the race falls come from | the O2 start (60 s), Bruno's trace through the LG2 pre-start | the catapults in the air with an eased sail; the tail-stand at walking pace |
| su1b, races su1_bar | **the bar alone** (`--sailor.` overrides) | six other hours; two races | 13 to 3 falls, 14 to 3: every catapult gone; left the tail-stands and two windward rolls at walking pace |
| su1trace | the reflex's step forward | the LG2 pre-start, Bruno | the nose stayed below 30 degrees (80 before), no fall |
| races su1_barreflex | **the bar and the reflex**, first version | two races | 2 falls, both Bruno falling back at 2.5 kt with the sheet pulled to 1.0 by the reflex's catch: at walking pace and with a backed sail sheeting in pushes the sailor over. **Fixed**: the catch only with the sail drawing on its own side, faster than 3 m/s |
| su2, su2b, races su2_final | **the defaults** (the bar in `sailor_default.tres`, the reflex on) | standard lake set + open water, six other hours, two races | races 0 falls, other hours 1, standard 0 (section 5); but the validation's fleet start on T1 went red: two boards over the line at the gun did not start again within 20 s. With the reflex off, or only its step forward off, green: the step at walking pace was it |
| su3 (stopped early), races su3_step1530 | the step from 15 to 30 degrees | the fleet test, two races | the fleet test still red (one board); LG2 2 falls. Not used |
| su4, races su4_final | **the shipped defaults**: the step only once the nose has stayed up for 1 s | the fleet test, Bruno's pre-start, two races, the unit tests and the validation | the fleet test green (as with the reflex off), Bruno's nose below 30 degrees, no fall; the races: section 5 |

Not tuned further, for want of time: the reflex's numbers are set from the falls' records (where the
limit was approached, how fast) and the danger shares, not swept. The rounds that would come next are in
section 7.

## 5. Before and after

"Before" is f72f565 as it came; "after" the defaults of round su2 for the lake sets and the open water,
and the shipped defaults (round su4: the same, with the step forward only after the nose has stayed up
for a second) for the races, the unit tests and the validation. The step acts only at walking pace with
the nose up, which none of the lake sets' and open-water cases except the irons cases come near. Lake speeds in kt (the mean
of the last 15 s of a straight run, or the 12 s after a manoeuvre); open water made good in m/s.

| Set | Before | After |
|---|---|---|
| **Two lake races, 11 personas, 14:30** (O2, LG2; `.sim_output/stay_up/su4_final/`) | **14 falls** (O2 8, LG2 6): 6 catapults, 8 fell off (7 tail-stands) | **1 fall** (O2 0, LG2 1: Bruno's board standing on its tail at 0.7 kt on the beat, pitch 77 degrees). Round 2's quicker step (`su2_final`): 0 and 0 |
| The races' progress (marks the 11 boards rounded in 7 min) | O2 31, LG2 10 | O2 30, LG2 10 (round 2: 27, 11). A few personas start very late in every version (section 7) |
| **Lake, six other hours** (180 cases) | **13 falls** (11 catapults, 2 fell off); the steady 24 kt beam reach 13.0 (its falls) | **1 fall** (a held turn into the wind at 16:15, rolled 61 degrees to windward at 2.7 kt); the beam reach 18.3 |
| Lake, the standard set (130 cases) | 0 falls | 0 falls |
| Open water, the manoeuvre matrix (24) | 1 fall (the 24 kt gybe from a beam reach) | **0** |
| Open water, the push check in gusts and waves (9 neutral, 6 pushed) | 0 falls; 8.96 / 10.89 | 0 falls; 8.98 / 10.87 |
| Validation (`tools/test.sh validation`) | 38 pass, 8 fail, 2 pending (last night's report: the eight known reds) | **38 pass, 8 fail, 2 pending**: the same eight reds with the same numbers (the polar sweep 11.85 / 13.53 / 14.55 / 14.67 / 7.65 m/s and its shape 5.45, the top speed 14.67 m/s, the planing onset 7.42 m/s, the fin's side force 745 N, the push warning 0 catapults, the waves' settled speed at 120 degrees 12.09 m/s), the skipper's 12 kt time 12:21.4 (last night 12:24.8; red either way, its limit 12:00). A first run with the reflex's step forward acting at once had a ninth red, the fleet's start on T1 (two boards over the line at the gun not started again within 20 s); round 4 fixed it (section 4) |
| Unit tests (`tools/test.sh`) | 872 (f72f565) | **886 of 886** (14 new in `test_stay_on_the_board.gd`) |
| `tools/matrix.sh` (open water, 24 cases) | 1 fall | **0 falls**, 0 not completed |
| `tools/lake_matrix.sh` (the map's wind, flat, 30 cases) | 0 falls, 1 not completed (the turn onto a run at 12:00) | 0 falls, the same 1 not completed |
| `tools/lan_test.sh --map=lake` | | **SYNC CHECK: PASS** (place 0.0000 m, the judge within 2 mm) |
| `tools/check.sh` | | **461 files, 0 failed** (after `pitch_budget.gd` was given the substep) |

## 6. Speed kept

| Course | Before | After | |
|---|---|---|---|
| Lake, the afternoons' beam reach (ten times of day, map's wind) | 17.9 | **17.9** | 0 % |
| Lake, the afternoons' broad reach / broad from the middle | 10.1 / 9.4 | **10.1 / 9.4** | 0 % |
| Lake, the map's beam reach (12:00, 14:30, 17:00) | 21.7 | 21.7 | 0 % |
| Lake, the steady 24 kt beam reach (the same three hours) | 18.5 | 18.3 | -1.1 % |
| Lake, the steady 24 kt beam reach (the six other hours) | 13.0 (falls) | 18.3 | |
| Open water, push check neutral / pushed (made good) | 8.96 / 10.89 | 8.98 / 10.87 | +0.2 % / -0.2 % |
| Lake, after a manoeuvre in a steady 24 kt (the standard set) | 12.1 | 11.3 | -7 %, see below |

The one loss is the 12 s after a tack or gybe in a steady 24 kt: 11.3 kt against 12.1, case by case
up and down (a tack 8.3 to 3.3, a turn onto a run 13.3 to 15.7). The trace of the worst one (`tack_stb`
17:00, `.sim_output/stay_up/tack17_on/` against `tack17_off/`) shows the reflex was not acting there
(every danger share below 0.4): the two runs part in the tack itself and the slow one stalls with the
rig raked back and the sail eased by the pilot. A small change moves every wave encounter (last night's
report says the same); it needs more hours to tell from chance.

## 7. What is still not cured

0. **The tail-stand at walking pace** still caught Bruno once on the beat (LG2, 326.7 s, the board at
   0.7 kt with the sail sheeted in and stalled): the step forward waits a second now (it had to, for the
   fleet's start), and the board's own pitch at rest is the physics question of section 8.
1. **Out of irons at walking pace** the board can still roll to windward to the standing limit with
   the sail luffing (1 case in 180 after; 2 before). The reflex leaves a luffing or backed sail alone,
   so nothing catches it. A lever to try: no weight on the windward rail and the sail sheeted to fill
   on its own side first.
2. **Very late starts.** In the races some personas wait before the start with the rig raked back and
   the sail eased, at 1.5 m/s on a broad reach, for minutes (the shipped version: Greta 192 s, Kofi 391 s,
   Jonas not at all; round 2: Jonas 358 s, Bruno 258 s, Mara 405 s; before: Elin 231 s, Ines 359 s,
   Liv 391 s, Greta not at all). The danger shares are zero there: it
   is the skipper's start and the hold-back skill, not the fall (an RA item).
3. **One turn onto a run in a steady 24 kt** turned 55 degrees in its 4 s where the check wants 60
   (`run_left` 12:00 and 12:15; the bar alone did the same): not a fall, a slower turn. The reflex was
   not acting (the trace: `.sim_output/stay_up/runleft/`).
4. **The felt heel in the air** is still swollen by the free fall; the bar now asks for a pull and a
   time, which keeps it from throwing an eased sailor, but the measure itself is Michiel's (section 8).
5. **Not tuned:** the reflex's numbers are first settings, not swept (a round of variants of
   `reflex_from_share`, `reflex_alpha_deg`, `reflex_bear_away_dps` on the six other hours and the races
   would be next, about 40 minutes on 4 cores each).

## 8. For Michiel

Every change in `Game/sim/` is in its own `[physics]` commit (section 11), with PHYSICS_SPEC.md 7.7.

1. **The bar (section 2's table).** Seven numbers in `sailor_default.tres`, each with its reason; most
   are estimates. A fresh `SailorConfig` (the code's defaults) is the old rule, so every test that
   builds one sails as before; with the old numbers in the `.tres` the game is the old game bit for bit.
2. **Two new levers in `_check_balance`**: the pull on the hands as a share of the weight for a
   catapult (`catapult_pull_share`), and the time a heel past the catapult's or the fall back's limit has
   to last (`catapult_time_s`, `fall_back_time_s`). `_check_balance` now takes the substep's `dt`.
3. **`tip_time_s` is the fall's alone**: the front foot's brief 400 N pull in its strap had shared it;
   it has its own `front_foot_pull_brief_s` (0.3 s, as before).
4. **The sense of balance** (`lee_fall_share`, `windward_fall_share`, `tipping_share` on the simulation
   and in `Telemetry`, three columns at the end of the CSV): read only, nothing in the physics uses it. It
   travels in the LAN snapshot by itself (the layout is read from the scripts).
5. **The pilot reads the bar.** `Autopilot._expected_turn_heel_deg` fades the push it expects from a
   head-up over the last 10 degrees before `catapult_heel_deg`; at 30 that window is 20 to 30 degrees of
   felt heel. Measured with everything else; the code is unchanged.
6. **Observations, not changed:**
   - *The felt heel in the air.* The fall checks read atan(sideways / down) of the felt gravity, the
     body's vertical acceleration averaged over `fall_feel_time_s`. Off a crest the body is near free
     fall, the felt "down" shrinks and a small sideways push reads as a large heel. Every catapult of the
     baseline came that way. A floor on the felt "down" for the fall checks (half of g, say) would be the
     physical fix.
   - *The tail-stand at walking pace.* A board at 1 to 3 km/h floating 85 to 90 % under water (a 108 L
     board and 125 to 129 L boards with the 85 kg sailor and the personas' big sails) raised its nose
     from 17 to 80 degrees in 7 s with the sailor by the mast foot; the feet's force held 60 to 70 N·m
     nose-up and nothing brought the nose down (`.sim_output/stay_up/su0trace/race_iq_lg2/trace_bruno.csv`).
     A board floating that deep should have a strong pitch-restoring moment from its buoyancy; worth a
     look at the buoyancy's pitch moment when nearly awash. The reflex's step forward held Bruno's nose
     below 30 degrees in the same pre-start.
   - `Autopilot.update()` still adds its rail for the sea with `+=` (last night's report); untouched.

## 9. What Max should look at on his screen

1. **The autopilot on the lake at 14:30** (`tools/play.sh lake`, the autopilot key): watch 5 minutes,
   then again with 24 kt (Settings > Wind). Over the crests the sail should still ease for a moment; the
   board should now stay on through the jumps it used to catapult on. Does it ever look like it should
   have gone over and did not (too lenient)?
2. **A race on iQFOiL O2 with 11 boards** (the Race page, the lake, 14:30): count the falls (the race
   tool counted 14 before and 1 after in two races of 7 minutes). Watch the boards waiting for the
   start: a nose rising at walking pace should come down as the sailor steps forward.
3. **The 24 kt beam reach** in beginner mode, on the open water and the lake: a minute each. Then hold
   the sheet in (Up held) and head up hard: you should still catapult (the bar moved, it did not go).
4. **The push slider at 100 %** at 24 kt across the wind: the reflex is off there, so pushing hard
   still carries its risk. At 75 % (neutral) the board should feel more forgiving than this morning.
5. **The feel of the reflex:** when it works, the sail is let out fast for a moment and the board bears
   away a little. Does that look like a sailor saving a fall, or like a twitch?

## 10. Open questions

1. **Michiel:** the seven numbers of the bar (section 2), and whether the free-fall felt heel should get
   a floor instead (or as well).
2. **Michiel:** the tail-stand at walking pace: the buoyancy's pitch moment when the board is nearly
   awash.
3. **Max:** is the bar now right, or too lenient? The tests say a sheeted sail at 24 kt still
   catapults; only your screen can say whether a board looks like it should have gone over.
4. **Max:** the reflex also works for the player in beginner mode (the beginner controller is the
   autopilot); it fades out above 80 % push. A setting to switch it off for the player is one line
   (`PlayerController.reflex_on`).
5. **The gear track:** Bruno's 108 L board for the 85 kg sailor at 17 kt (`Skippers.gear_for`) floats
   85 to 90 % under water at rest; a heavy persona in moderate wind may want a bigger board.

## 11. The commits, the tools, the token use

On `autopilot/stay-up`, in order:

1. `03869c0` The fall recorder for the harnesses (`Game/dev/fall_log.gd`, `tools/fall_detail.py`, the
   suite's `--project`, `--race_course`, `--race_skippers`, `--race_seconds`, `--afternoons`; `run_race`'s
   `--sailor.` and `--trace=`).
2. `9f5390a` **[physics]** The fall rule's new levers, all off (the game bit for bit as before), the front
   foot's own brief time, the sense of balance in `Telemetry`; PHYSICS_SPEC.md 7.7.
3. `702830b` **[physics]** The bar moved in `sailor_default.tres` (the table); PHYSICS_SPEC.md 7.7's table.
4. `50989f0` The recovery reflex in `PlayerController` (on), `test_stay_on_the_board.gd`, the catapult
   test's heel limit.
5. `e019e69` `pitch_budget.gd` passes the substep to the fall check.
6. `1bb9edc` The step forward only once the nose has stayed up for a second (the fleet's start test green
   again).
7. The report, the roadmap's PH45 and the progress log (this commit).

Tools for the next session: `tools/fall_detail.py <folder> --list=1` (every fall, grouped);
`.logs/stay_up/race.sh` and `races_round.sh` (the two lake races of a variant from a snapshot);
`.logs/stay_up/race_summary.py <round>` (one line per race). The snapshots of the code each round sailed
were temporary copies in the session's scratch folder; the code of each round is the commit named above.

Token use: about 0.5 M tokens (one Opus session, no agents; an estimate).
