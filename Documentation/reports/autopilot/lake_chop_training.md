# The autopilot on the lake's chop: the training of 6 November 2026

For Max (and Michiel). Written 6 November 2026 by Claude Opus 5.5 on Max's PC, on the branch
`autopilot/lake-chop` (from `night2/combined` 6530c14: tonight's full lake waves and the feet's
press). Not pushed, not merged. Every number below is from a run of `tools/autopilot_suite.sh`
(the outputs in `.sim_output/autopilot/<round>/`, the logs in `.logs/lake_chop/`), with the number
of runs it counts; estimates are called estimates.

Max asked: *"please train the autopilot extensively on the new waves. i expect it to be harder to
sail"*, *"dont shortcut the training. better to much than to little"*, and for 1.5 times higher
waves: *"try but if it fails much skip it"*.

## In short

- **The autopilot falls far less on the lake's chop, and is as fast as before.** On the lake's
  realistic waves it fell in none of the 130 cases the rounds tuned on (before: 26: the manoeuvres in
  the map's wind 6, in a steady 18 kt 6, in a steady 24 kt 14), and on sixteen other hours of the day
  in 21 of 480 cases (before: 58). The afternoon reaches in the map's wind are exactly as fast as
  before (beam 17.9 kt, broad 10.1, over ten afternoons, no fall either way).
- **What changed is how the autopilot's sailor handles the sheet and the rail** (the beginner
  controller that every AI board and the beginner player sail with; `Game/sim/` is untouched):
  1. **It eases the sail while carving up at speed** (into a tack, or a key held toward the wind).
     Before, the tacks from planing speed catapulted 1 to 2 s into the head-up: the turn's push plus
     the chop's roll reached the catapult's 20 degrees with the sail fully sheeted.
  2. **No weight on the rail at walking pace.** Out of irons, the slow board with a luffing sail
     was rolled off its windward rail by the chop.
  3. **It sheets out when the board goes light over a crest in strong wind and short chop**, and
     back in fast on landing. In a steady 24 kt the board leaves the water about once a second; in
     the air the sail's pull rolls it and the sailor goes over the sail.
- **Not cured: the 24 kt beam reach held for a long time.** Counting each fall once (17 hours of a
  steady 24 kt): 28 fall events before, 11 after; but the beam reach sailed for 45 s still catapulted
  in 8 of the 17 hours (before: 4), now mostly after 25 s. The ease in the air buys the manoeuvres
  at 24 kt more than the long reach. It is the place to look next (and to play-test).
- **The open water and the validation are as before:** the push check in gusts and waves without a
  fall at either dial and within 1 % of the speed made good on all three samples; the manoeuvre
  matrix the same one fall (a 24 kt tack on flat water); validation 38 pass, 8 fail, 2 pending, the
  same eight known reds; unit tests 835 of 835; `tools/check.sh` 442 files, 0 failed;
  `tools/lan_test.sh --map=lake` SYNC CHECK: PASS.
- **The 1.5x waves:** two rounds ran (12 variants, 130 lake cases each); it did not fail much, so it was not
  stopped. The shipped defaults fall in 21 of 130 cases where the controller before fell in 28, with
  the afternoons' beam reach 13.3 kt against 12.5. The ease in the air from less wind (15 to 17 kt at
  the sail) brings it down to 9, but on the realistic waves it costs the afternoons' beam reach 0.9 kt
  (17.0 against 17.9) and the map's 0.8 kt, so it is not a default: it is a setting for a rough day
  (`airborne_wind_from_kt` 15, `airborne_wind_full_kt` 17).

## Before and after

"Before" is the branch as it came (round lc0, and the controller with the new settings off in later
rounds: it sails bit for bit the same); "after" is the shipped defaults (round lc7s, the rest as
named). Lake cases: falls / cases; speeds in kt (the mean of the last 15 s of a straight run, or the
12 s after a manoeuvre).

| What | Before | After |
|---|---|---|
| **Lake 1x**, the afternoon reaches (ten times of day in the map's wind, 40 runs) | beam 17.9, broad 10.1, broad from the middle 9.4, after the gybe 13.2; 0 falls | **17.9, 10.1, 9.4, 12.9; 0 falls** |
| Lake 1x, the manoeuvre matrix in the map's wind (12:00, 14:30, 17:00) | 6 falls / 30 (4 catapults in tacks and a held turn, 2 out of irons) | **0 / 30** |
| Lake 1x, every manoeuvre in a steady 18 kt (three hours) | 6 / 30 | **0 / 30** |
| Lake 1x, every manoeuvre in a steady 24 kt (three hours) | 14 / 30; the beam reach 18.1 kt, catapulted in 2 of 3 (after 19 and 21 s) | **0 / 30; the beam reach 18.5 kt, no fall** |
| Lake 1x, the same 90 cases on sixteen other hours (rounds 4, 5, 7) | 58 / 480 | **21 / 480** (rounds 4 and 5 with the rail's earlier fade) |
| Lake 1x, a steady 24 kt on seventeen hours, each fall counted once | 28 fall events; the 45 s beam reach fell in 4 | **11; the 45 s beam reach fell in 8** |
| Lake 1x, the T2 race (the all-rounder, cautious, gambler, rookie) | 14:30 all in, mean 4:26, 0 falls; 16:00 all in, 11:26, 2 falls; 13:00 all in, 5:05, 0; 15:00 all in, 5:12, 4 | 14:30 all in, 4:38, 1; 16:00 all in, 8:51, 1; 13:00 all in, 5:06, 0; 15:00 all in, 3:39, 1 (13:00 and 15:00 with the rail's earlier fade) |
| **Lake 1.5x** (130 cases: the afternoons and the three sets) | 28 falls; the afternoons' beam reach 12.5 | 21 falls (the 24 kt set 8 of 30, the map's 8, 18 kt 1, the afternoons 4); the beam reach 13.3. With the ease in the air from 15 kt (not shipped, it slows 1x): 9 falls, 13.8 |
| **Open water**, the push check (gusts and waves; 9 cases neutral, 6 pushed), m/s made good | 9.05 / 10.87, no fall | 8.96 / 10.89, no fall |
| Open water, the second sample (75 and 120 degrees, gusts 6.5 s apart) | 12.80 / 13.20, no fall | 12.81 / 13.21, no fall |
| Open water, the third sample (60 and 135 degrees, gusts 9.5 s apart) | 10.35 / 10.48, no fall | 10.27 / 10.48, no fall (c2hu10, the rail's earlier fade) |
| Open water, the manoeuvre matrix (24 cases, flat water) | 1 fall (24 kt, a tack from a beam reach) | 1 fall (the same) |
| Open water, the reach check (nine flat-water reaches) | 3 of 4 goal cases, 8 of 9 steady | the same (it sails the pilot itself, which did not change) |
| **Validation** (`tools/test.sh validation`, 48 tests) | 38 pass, 8 fail, 2 pending | **38 pass, 8 fail, 2 pending**: the same eight; the skipper's 12 kt time 12:21.2 before, 12:24.8 now (its limit 12:00, red either way); the others' numbers identical |
| Unit tests (`tools/test.sh`) | 822 of 822 | 835 of 835 (13 new) |

## What changed in the autopilot

All in `Game/windsurfer/player_controller.gd` (PlayerController: the beginner player's controls and
the hands every AI skipper sails with). New settings, with the defaults the training chose:

| Setting | Default | What it does |
|---|---|---|
| `head_up_alpha_deg` | 9 | while carving up at speed (from `head_up_ease_from_ms` 7 m/s), the auto-sheet trims no closer than 9 degrees of angle of attack |
| `head_up_ease_on_hold` | false | only for a key held toward the wind or a tack, not for the heading hold's small corrections |
| `head_up_ease_from_dps` | 10 | a turn toward the wind of at least 10 degrees a second counts (an AI's stick steers all the time) |
| `rail_from_ms`, `rail_full_ms` | 0.3, 1.0 | the weight on the inside rail for a turn fades in from 0.3 to 1 m/s |
| `airborne_alpha_deg` | 6 | while the water carries less than `airborne_support_share` (0.3) of the board's weight, and `airborne_hold_s` (0.3 s) after, the sail is trimmed no closer than 6 degrees |
| `airborne_wind_from_kt`, `airborne_wind_full_kt` | 18, 20 | that ease only in strong wind (the true wind at the sail) |
| `airborne_bounce_from_dps`, `airborne_bounce_full_dps` | 8, 12 | and only in short chop (the pitch rate's RMS the sailor feels): the open sea's swell pitches the board at 3.5 to 9 degrees a second and it does not fall there; the lake's chop at 10 to 17 |
| `airborne_sheet_in_share` | 3 | for 1 s after landing the sail comes back in three times as fast as the pilot's usual pace (the body stayed hiked out) |
| `chop_hike_drop`, `manoeuvre_wait_max_s`, `airborne_after_s`, `airborne_heel_from_deg`, `pilot_sheet_rate_per_s` | off (0, 0, 0, -90, 1.5) | built and measured, not used: less pull in chop cost the afternoons 2.6 kt; waiting for the wave before a tack changed nothing; the faster sheet (2.5) took the open-water matrix's fall but cost the pushed 24 kt broad reach 7 to 8 % in every sample |

The tests: `Game/tests/unit/test_controller_chop.gd` (13: each setting on its own, and the defaults).
Two older tests were adjusted because they measure something the defaults now change, with the
reason written in them: `test_feet_press.gd`'s "exactly as before" sails the controller with the new
settings off (its numbers are from before tonight), and `test_player_controller.gd`'s helm
directions test keeps the rail at every speed (its board is at rest).

The tools: `tools/autopilot_suite.sh` now runs every case as its own Godot process in one pool
(`tools/autopilot_suite.py`, `--cores=`), with the new parts `lake`, `race`, `push2`/`pushed2` and
the options `--lake_wave_scale`, `--matrix_times`, `--race_times`, `--push2_twas`, `--push2_gust`;
`tools/autopilot_summary.py <round> --table` prints one line per variant; `Game/dev/run_lake.gd`
takes `--pilot./--controller./--sailor./--sail.` settings and several `--only` parts;
`Game/dev/run_race.gd --map=lake --time=hh:mm` races on the lake's wind and waves, and reads
`WSIM_CONTROLLER` so a setting can be tried on a validation test; `tools/fall_trace.py` prints the
seconds before a fall from a telemetry CSV.

## What Max should look at

1. **`tools/play.sh lake`, Settings > Wind 24 kt, beginner mode:** sail a beam reach for a minute.
   Over the crests the sail should now ease for a moment and come back; does it look and feel like a
   sailor sheeting out on a jump, or like flapping? And the long reach can still catapult (8 of 17
   hours in the tests): how often does it for you?
2. **A tack from a planing beam reach in chop (Space, or a key held into the wind):** the sail eases
   a little while the board carves up. Does the tack still feel quick?
3. **Out of irons on the lake** (stop, hold a key): the board should no longer roll you off.
4. **A race on T2 on the lake with the AI fleet:** fewer falls, and the start (the fleet's
   validation test caught a rookie over the line with the first version of the rail's fade; fixed).
5. **The open water at 24 kt:** it should sail exactly as before.

## For Michiel (nothing in `Game/sim/` was changed)

- `Autopilot.update()` adds its rail for the sea to `rail_bank_extra_deg` at every update (`+=`)
  when `wave_rail_max_deg > 0` and no slider sets the controls afresh: the rail then grows without
  end (the reach check's `waverail3` variant: 0 of 4 goal cases, 5.3 m/s). Nothing in the game hits
  it today (only the slider sets the wave rail, and it resets the controls); a one-line fix there.
- The catapult in the air: while the board is light, the felt heel the fall check reads grows from
  the board's own heel (the sail rolls it with nothing under it) and the sideways push, over a body
  in free fall: 9 to 34 degrees in 0.3 s on the 24 kt reach. The controller can only ease the sail;
  whether a sailor in the air should be thrown that easily is a physics question (and PH9, the legs
  in pitch, may change how often the board flies).
- `test_push_warning.gd` (a known red) wants the pushed board to catapult at 24 kt: still 0 now.

## How it was tested

Max asked to train the autopilot extensively on the lake's new waves (`ph44/lake-full`, the full
waves on Lake Silvaplana), first on the realistic waves (1x), then on waves 1.5 times higher. This
is the rule-based autopilot: the beginner controller (`Game/windsurfer/player_controller.gd`) with
its auto-sheet pilot, which every AI board and the beginner player sail with. Not the neural
network, not the evolution trainer. Nothing in `Game/sim/` (Michiel's physics) changed: the
auto-sheet pilot's own code lives there (`Game/sim/autopilot.gd`) and was left alone; its numbers
were only set from the controller.

Every round is a file of variants (`rounds/lc<n>.txt`), each a label and its settings, scored by
`tools/autopilot_suite.sh` in one pool of 13 to 14 Godot processes:

- **The lake at 1x** (new part `--only=lake`, Game/dev/run_lake.gd on the lake's own waves):
  - the reaches in the map's wind at ten times of day (12:30 to 17:00): the beam reach and the
    broad reach from the start, the broad reach from the lake's middle and the gybe from a broad
    reach: 40 runs;
  - the lake's manoeuvre matrix in the map's wind at 12:00, 14:30 and 17:00: 30 cases (the beam
    and broad reaches, two tacks, a held turn up through the wind, two gybes, a turn onto a run,
    out of irons);
  - the same 30 cases in a steady 18 kt and in a steady 24 kt (the lake's mean direction of those
    three hours, so three wave patterns each).
- **The open water** (as before): the reach check (nine flat-water reaches; it sails the pilot
  itself, so a variant of controller settings only sails it as the defaults do and it is not rerun),
  the push check in gusts and waves at the neutral dial (nine cases) and the pushed dial (six), and
  the manoeuvre matrix (24 cases).
- **The race on T2 on the lake** (new part `--only=race`, `Game/dev/run_race.gd --map=lake`): the
  all-rounder, the cautious, the gambler and the rookie at 14:30 and at 16:00.
- **Validation** (`tools/test.sh validation`) on the baseline and on the final defaults.

Each run is deterministic (the same settings give the same run), but a small change moves every
wave encounter, so one case can fall or not by chance. That is why each round counts falls over
130 lake cases and speeds over 40 reaches, and why a winner is checked again on more patterns.

## The baseline (round lc0)

Branch `autopilot/lake-chop` from `night2/combined` 6530c14, as it came.

- `tools/test.sh validation`: 48 tests, 38 pass, 8 fail, 2 pending: the eight known reds with the same numbers as before (the polar sweep's speeds and shape, the top speed 14.67 m/s, the planing onset 7.42 m/s, the fin's side force 745 N, the push warning, the skipper's 12 kt limit 12:21.2, the settled speed on waves at TWA 120 12.09 against 14.67 m/s). 14 min 19 s.
- The lake at 1x: the reaches over ten afternoons (40 runs: beam 17.9 kt, broad 10.1, broad from the middle 9.4, after the gybe 13.2; no fall); the lake matrix in the map's wind (30 cases, 6 falls: 4 catapults, 2 fell off); every case in a steady 18 kt (30 cases, 6 falls) and 24 kt (30 cases, 14 falls, 12 of them catapults).
- The open water: the reach check 3 of 4 goal cases, 8 of 9 steady; the push check neutral and pushed without a fall; the matrix 24 cases, 1 fall (24 kt, the tack from a beam reach catapulted on flat water).
- The race on T2 on the lake (four AI skippers): 14:30 all four finished, no fall (4:10 to 4:38); 16:00 (a lull at the start) the rookie finished in 7:53, the other three were still on the course when the race closed 60 s later.

**Why they fall** (`tools/fall_trace.py` on the falling cases' telemetry):

1. **Carving up at speed** (the tacks, the held turn, and the "gybe from a beam reach", which the
   controller sails as a tack because the board is at 98 degrees): 1 to 2 s into the head-up the
   sailor is pulled over the sail. The turn's push is felt as heel to leeward (about 15 degrees at
   15 degrees a second and 11 m/s; the board hardly banks into the turn), and the chop's roll adds
   up to 8 degrees each way on top: the catapult's 20 degrees are reached with the sail fully
   sheeted (0.97, 15 degrees of angle of attack).
2. **Out of irons** the board is at walking pace (2 km/h) with the sail luffing, the key held
   toward the wind puts the weight on the windward rail (a carve's rail), and the chop rolls the
   board to windward until the sailor falls off (51 degrees).
3. **The steady 24 kt reach** leaves the water over the crests about once a second (light 29 % of
   the time, 0.27 s at a time). In the air nothing holds the board against the sail's side force:
   it is rolled to leeward and the sailor, falling with it, feels the heel grow from 9 to 34
   degrees in 0.3 s: a catapult.

## Round 1 (lc1): the levers one at a time, on the lake

`rounds/lc1.txt`, 18 variants, 130 lake cases each (42 min on 13 processes); the open water of
the same variants after it. Falls in the 130 lake cases (the baseline 26), and the afternoons'
mean speeds (beam / broad / broad from the middle, kt; the baseline 17.9 / 10.1 / 9.4):

| Variant | Falls | Fixed / new against the baseline | Afternoons | What it is |
|---|---|---|---|---|
| `chophike30` | 6 | 20 / 0 | **15.3** / 10.1 / 9.4 | 30 % less pull held when the board bounces: safe but 2.6 kt slower on the beam reach |
| `sheetrate25` | **8** | 21 / 3 | 17.9 / 10.0 / 9.4 | the pilot's hands faster on the sheet (2.5 of its range a second against 1.5): the map's 30 cases without a fall, no speed lost |
| `hualpha6` | **8** | 18 / **0** | 17.8 / 10.1 / 9.4 | the sheet eased to 6 degrees of angle of attack while carving up at speed: every carve-up catapult in the map's wind and at 18 kt gone |
| `combo1` | 10 | 24 / 8 | 17.4 / 10.1 / 9.4 | the ease at 9 degrees, no rail at walking pace, 15 % less pull in chop |
| `hike10` | 11 | 17 / 2 | 17.5 / 10.1 / 9.4 | the pilot's pull held 1.0 against 1.1 (two catapults on the afternoons) |
| `hualpha12` | 13 | 13 / 0 | 17.9 / 10.1 / 9.4 | the ease at 12 degrees |
| `depallow3` | 15 | 15 / 4 | 17.9 / 10.0 / 9.3 | the pilot eases from 3 degrees of heel beyond the bank (5) |
| `railfade37`, `railfade25` | 17, 18 | 9 / 0, 8 / 0 | as the baseline | no rail below 3 (2) m/s, full from 7 (5): every fall out of irons gone, nothing else changes |
| `slider75` | 18 | 9 / 1 | 17.6 / 10.1 / 9.3 | the player's slider at its start (75 %: pull held 1.0, the rail for the sea 3 degrees) |
| `depurgent4` | 18 | 11 / 3 | 18.2 / 10.1 / 9.4 | the pilot's urgent ease twice as fast |
| `hualpha9` | 19 | 14 / 7 | 17.8 / 10.1 / 9.4 | the ease at 9 degrees: the carve-ups fixed, but seven new falls at 24 kt (chance: a changed sheet moves every wave encounter) |
| `chophike15` | 20 | 15 / 9 | 17.5 / 10.1 / 9.4 | 15 % less pull in chop |
| `waverail3` | 21 | 11 / 6 | 17.9 / 10.1 / 9.3 | the pilot's rail for the sea (3 degrees more when it bounces) |
| `tackrate12`, `tackrate10`, `humin9` | 23, 24, 24 | few | as the baseline | a slower carve into the tack or a slower head-up: not the lever |

Kept for round 3: the faster sheet, the ease while carving up at 6 degrees, no rail at walking pace.
The 24 kt beam reach still catapults with all of them (it is the board in the air: round 2).

The open water for the same variants (`.logs/lake_chop/lc1_open.log`): no fall in the push check
at either dial for any of them; the speed made good over the nine neutral cases 8.97 to 9.08 m/s
against the baseline's 9.05, except `chophike30` (8.70, 4 % slower); the matrix's one fall (the
24 kt tack from a beam reach on flat water) is gone with every head-up ease, the faster sheet and
less pull. The reach check (it sails the pilot itself) changes only with the pilot's own numbers:
`hike10` and `depallow3` make all nine reaches steady (the 24 kt close reach's pitch SD from 0.31
to below 0.3), `sheetrate25` changes nothing. `waverail3` wrecks it (0 of 4 goal cases, 5.3 m/s):
the pilot's own course hold adds its rail for the sea to the controls every update instead of
setting it, so the rail grows without end. That is in `Game/sim/autopilot.gd` (not changed here;
written down for Michiel, see the end); the controller sets it, so the AI boards are not affected.

## Round 2 (lc2): the board in the air, the helm in chop, the timing

`rounds/lc2.txt`, 15 variants (a few left out after round 1 to keep it short), the lake and the
open water. A first look at the steady 24 kt reach had shown the ease in the air at work (the
three 24 kt beam reaches without a fall) but 20 % slower; the round tried lighter and gated eases.

| Variant | Lake falls (of 130) | Afternoons beam / broad / mid | Map beam, s24 beam | Push check neutral (pushed), m/s made good | What it is |
|---|---|---|---|---|---|
| baseline | 26 | 17.9 / 10.1 / 9.4 | 21.8, 18.1 | 9.05 (10.87), no fall | |
| **`c1`** | **0** | **18.1 / 10.1 / 9.4** | 21.7, 18.6 | 8.76 (10.24), no fall | the ease while carving up (9 degrees, a key or a tack only), no rail at walking pace, the ease in the air (6 degrees) from 18 to 20 kt at the sail with the sail back in on landing at 3 |
| `air6rs3` | 4 | 15.6 / 9.9 / 9.3 | 17.9, 18.6 | 8.42 (9.72), 1 fall | the ease in the air at every wind, back in at 3: safe and slow |
| `air6`, `air6a01` | 6, 6 | 14.8, 15.6 / ... | 16.9, 18.5 | 8.53, 8.64 | the ease in the air at every wind (after 0.1 s light) |
| `air6rs3g` | 14 | 18.1 / 10.1 / 9.4 | 21.7, 18.6 | 8.63 (10.27), 1 fall | the ease in the air from 18 to 20 kt only: the 24 kt falls go (14 to 2) and the afternoons keep their speed |
| `helmrate1`, `trimfeel04`, `holdrate05`, `hu9key`, `legs0`, `rategain005` | 15 to 19 | 16.9 to 18.0 | | 9.0 to 9.1 | a calmer helm or sheet: some help, no pattern, and new falls appear where old ones go |
| `air6s15h1`, `air9s15`, `wait08`, `gybealpha6` | 18 to 26 | | | | a lighter ease (only when nearly nothing carries the board) lets the 24 kt reach fall again; waiting for the bow to drop before a tack changes nothing |

`c1` is the first variant that fell in none of the 130 lake cases. But on the open water it lost
speed made good where the baseline does not fall: the push check's 24 kt reaches (beam 13.99 to
12.61 m/s, broad 14.21 to 13.41; pushed 14.65 to 12.20). The open sea's longer swell also lifts the
board off the water, and the ease came on there for nothing. The open sea pitches the board at 3.5
to 9 degrees a second (the push check's nine cases), the lake's chop at 10 to 17 (its telemetry):
that is round 3's gate.

## Round 3 (lc3): only in short chop, and round 1's winners on top

`rounds/lc3.txt`, 13 variants around `c2` = `c1` with the ease in the air only when the board
bounces at 8 to 12 degrees a second or more (`airborne_bounce_from_dps`, `_full_dps`; added for
this round). The open water's push check is 9 cases neutral, 6 pushed; m/s made good, the mean.

| Variant | Lake falls (of 130) | Afternoons | Push neutral / pushed | Open water matrix | |
|---|---|---|---|---|---|
| baseline | 26 | 17.9 / 10.1 / 9.4 | 9.05 / 10.87 | 1 fall | |
| **`c2`** | **0** | 17.9 / 10.1 / 9.4 | **9.08 / 10.83** | 1 fall | the gate gives the open sea its speed back |
| **`c2hu10`** | **0** | 17.9 / 10.1 / 9.4 | 9.05 / 10.91 | 1 fall | the head-up ease only from 10 degrees a second (the AI's stick) |
| `c2hu6` | 0 | 17.9 / 10.1 / 9.4 | 9.07 / 10.94 | 1 fall | the ease while carving up at 6 degrees |
| **`c2s25hu10`**, `c2s25` | **0** | 18.0 / 10.1 / 9.4 | 8.97 / 10.71 | **no fall** | and the pilot's faster hands (2.5): the matrix's last fall goes; the push check's 24 kt broad reach 5 to 8 % slower (one run each) |
| `c2b1014`, `c2g1719` | 1 | | about the baseline | 1 fall | the gates moved: 10 to 14 degrees a second, 17 to 19 kt |
| `c2dep4` | 3 (2 on the afternoons) | 17.5 / 10.1 / 9.4 | 9.05 / 10.70 | 1 fall | the pilot's urgent ease twice as fast |
| `c2hold`, `c2hike12` | 3 | 17.8, 18.2 | 9.08, 9.10 | no fall | the ease also on the hold's corrections; more pull (1.2): faster on the map's beam reach (22.1 kt) and on the reach check (9 of 9 steady), but 2 falls at 24 kt |
| `c2b710`, `c2a9` | 5, 6 | | | | the gate from 7 degrees a second, or the ease in the air only to 9 degrees: the 24 kt reach falls again |
| `c2g1921` | 16 | | | | the ease in the air only from 19 to 21 kt: too late for the steady 24 kt (about 20 kt at the sail) |

The remaining open-water matrix fall (24 kt, a tack from a beam reach on flat water) comes 0.3 s
after Space, while the heading hold is turning the board back up after the case's bear-away: only
the ease on the hold's corrections (`c2hold`) or the faster sheet takes it.

## Round 4 (lc4): the candidates on six new hours, the open water's second sample, the race

`rounds/lc4.txt`. The same 30 lake cases at six other hours (12:00 to 17:00 every hour: 180
manoeuvre cases in the map's wind and in a steady 18 and 24 kt) and the 40 afternoon reaches; the
push check at 75 and 120 degrees with the gusts 6.5 s apart (18 and 24 kt, neutral and pushed); the
race on T2 on the lake at 14:30 and 16:00 with the four AI skippers.

| Variant | Lake falls (of 180) | of them at 24 kt | Push2 neutral / pushed | Race 14:30: finished, mean time, falls | Race 16:00 |
|---|---|---|---|---|---|
| baseline | 29 | 16 | 12.80 / 13.20 | 4 of 4, 4:26, 0 | 4 of 4, 11:26, 2 |
| `c2hu10` | **6** | 6 (two catapults) | 12.78 / 13.21 | 4 of 4, 4:18, 1 | 4 of 4, 8:00, 0 |
| `c2s20hu10` | **4** | 4 | 12.83 / 13.20 | 4 of 4, 4:44, 0 | 4 of 4, 7:50, 1 |
| `c2s25hu10` | 8 | 7 | 12.77 / 13.18 | 4 of 4, 4:35, 0 | 4 of 4, 7:28, 0 |
| `c2hu6` | 6 | 6 | 12.65 / 12.58 | 4 of 4, 4:40, 0 | 4 of 4, 7:51, 3 |

On new hours the candidates are not perfect: what is left is the steady 24 kt beam reach's
catapult in the air (the eased sail still pulls 200 N, and a slam that knocks the board sideways
on landing tips the sailor over in 0.2 s). The race on the lake: every board finished in every race;
at 16:00 (a lull at the start) the candidates' fleets were three to four minutes quicker on average
(one race each: partly chance).

## Round 5 (lc5, lc5d): four more hours, a third open-water sample, two more races

`rounds/lc5.txt`: the lake at 12:30, 13:30, 15:30 and 16:30 (120 manoeuvre cases and the 40
afternoon reaches), the push check at 60 and 135 degrees with the gusts 9.5 s apart, the race at
13:00 and 15:00. `rounds/lc5d.txt`: `c2s20hu10` on round 3's standard set.

| Variant | Lake falls (of 120) | Push3 neutral / pushed | Race 13:00 | Race 15:00 |
|---|---|---|---|---|
| baseline | 14 (12 at 24 kt) | 10.35 / 10.48 | 4 of 4, 5:05, 0 falls | 4 of 4, 5:12, 4 falls |
| **`c2hu10`** | **2** (a catapult in a tack at 24 kt, one on the 24 kt beam reach) | 10.27 / 10.48 | 4 of 4, 5:06, 0 | 4 of 4, **3:39**, 1 |
| `c2s20hu10` | 5 (one catapult on the 24 kt reach, in five cases) | 10.39 / 10.18 | 4 of 4, 5:34, 1 | 4 of 4, 5:02, 2 |
| `c2s25hu10` | 9 | 10.12 / 10.16 | 4 of 4, 4:54, 0 | 4 of 4, 3:40, 1 |

`c2s20hu10` on the standard set: 1 fall in 130, the matrix without a fall, the push check 9.10 /
10.73 (its pushed 24 kt broad reach 13.17 against 14.21: the faster sheet costs that case in every
sample). **Chosen: `c2hu10`.** It falls least on every set of patterns (0 of 130, 6 of 180, 2 of
120; the baseline 26, 29, 14), it is as fast as the baseline on the afternoon reaches and on all
three open-water samples (within 1 %), its AI fleet finished every race with fewer falls (2 against
6 in the four races at 13:00, 14:30, 15:00 and 16:00), and it changes nothing on flat water or in light wind. The faster sheet would
also take the last open-water matrix fall, but costs the pushed 24 kt broad reach 7 to 8 % in every
sample: left as a setting (`pilot_sheet_rate_per_s`), not a default.

## Round 6 (lc6): the shipped defaults on their own, and the last refinements

`rounds/lc6.txt`. `final` is `c2hu10` as the controller's defaults with no overrides at all: it sailed
every case exactly as `c2hu10` had (the same falls, speeds and races to the digit), so the defaults
are set as measured. On top of it:

| Variant | Lake falls (of 130) | Afternoons | Push neutral / pushed | Push2 neutral / pushed | Matrix | Races (falls) |
|---|---|---|---|---|---|---|
| `final` | 0 | 17.9 / 10.1 / 9.4 | 9.05 / 10.91 | 12.78 / 13.21 | 1 fall | 4:18, 8:00 (1) |
| `f_air5` | 1 | 18.1 / 10.1 / 9.4 | 9.09 / 10.83 | 12.78 / 13.21 | 1 fall | (2) |
| `f_hike115` | 2 | 17.9 / 10.1 / 9.4 | 8.96 / 10.57 | 12.89 / 12.89 | 1 fall | (0) |
| `f_hu7` | 1 | 17.9 / 10.1 / 9.4 | 9.05 / 10.92 | 12.78 / 13.21 | 1 fall | (1) |

None is better than `final`: more pull (1.15) is not faster on the open water and falls twice on the
lake; a stronger ease in the air or a carve-up ease at 7 degrees each fall once.

**The validation of the defaults found one new red**, the AI fleet's start
(`test_living_skipper_fleet.gd`, T1, 16 boards from random spots): a rookie over the line at the
gun and not started again within 20 s. Trying each setting on the test (`WSIM_CONTROLLER`, read by
`Game/dev/run_race.gd`) showed it is the rail's fade from 2 to 5 m/s: the boards holding back before
the start turn more slowly without the rail. From 0.3 to 1 m/s the fleet starts as before (every
board within 8 s of the gun) and the 18 lake cases out of irons and the held turns still do not
fall. The defaults now fade the rail in from 0.3 to 1 m/s; rounds 7 and 7s measure them.

## Round 7 (lc7, lc7s): the shipped defaults, before and after

`rounds/lc7s.txt`: `final` (the defaults with the rail's fade at 0.3 to 1 m/s) on the whole
standard set. `rounds/lc7.txt`: `before` (the chop technique off: the controller as it was) and
`final` on six more hours (12:15, 12:45, 13:45, 15:15, 16:15, 16:45).

- The standard set: no fall in the 130 lake cases; the afternoons 17.9 / 10.1 / 9.4 kt; the push
  check 8.96 / 10.89 m/s (the baseline 9.05 / 10.87: the neutral mean 1 % lower, the size of the
  chaos between near-identical variants), the second sample 12.81 / 13.21 (12.80 / 13.20); the matrix
  one fall, as before; both races finished by all four boards (one fall in each).
- The six more hours: `before` 15 falls in 180 (map 5, 18 kt 4, 24 kt 6), `final` 13 (map 2, 18 kt 0,
  24 kt 11). On these hours the 24 kt beam reach caught `final` five times out of six after 26 to 37
  s, where `before` did not fall once.

The 24 kt sets of all four hour sets together (17 hours: rounds 0 or 7s, 4, 5 and 7; each fall
counted once, since the beam reach, the tacks, the held turn and the two gybes sail the same first
25 s from the start; `final` here is `c2hu10` on the hours of rounds 4 and 5), with a third
controller run for it on the same 17 hours: the defaults without the ease in the air
(`.sim_output/lake_chop/noair/`):

| Controller | The beam reach from the start fell before 25 s | The 45 s beam reach fell after 25 s | Other falls (manoeuvres, out of irons, broad reaches) | Fall events |
|---|---|---|---|---|
| before | 3 | 1 | 24 | 28 |
| the defaults without the ease in the air | 3 | 1 | 14 | 18 |
| **the defaults** | 2 | 6 | 3 | **11** |

So the ease while carving up and the rail's fade take ten of the 24 kt falls, and the ease in the air
seven more; but the board that keeps sailing the 24 kt beam reach for 45 s still catapults, and in
these runs more often late (6 of 17 hours against 1): the ease keeps it going through the first
crests and then a slam on landing tips the sailor over in 0.2 s with the eased sail still pulling
200 N. An open item (see "What Max should look at" and "For Michiel").

## Round 8 (lc8): the 1.5x finding on the realistic waves

`rounds/lc8.txt`. The 1.5x round A (below) found that the ease in the air from less wind falls far
less on the higher waves. On the realistic waves and the open water (the standard set):

| Variant | Lake falls (of 130) | Afternoons beam / broad / mid | Map's beam reach | Push neutral / pushed | Push2 | Matrix |
|---|---|---|---|---|---|---|
| the defaults (18 to 20 kt) | 0 | 17.9 / 10.1 / 9.4 | 21.7 | 8.96 / 10.89 | 12.81 / 13.21 | 1 fall |
| `w1517` (15 to 17 kt) | 0 | **17.0** / 9.9 / 9.4 | 20.9 | 8.96 / 10.85 | 12.80 / 13.14 | 1 fall |
| `w1618` (16 to 18 kt) | 0 | 17.6 / 10.1 / 9.4 | 20.6 | 8.96 / 10.85 | 12.80 / 13.23 | 1 fall |
| `w1517b1014` (and the chop gate 10 to 14) | 1 | 16.9 / 10.0 / 9.4 | 20.7 | 9.03 / 10.67 | 12.80 / 13.16 | 1 fall |

On the realistic waves the defaults already fall in none of these, and a lower gate only costs
speed (the afternoons' beam reach 0.3 to 0.9 kt): the 1.5x finding is not used (Max's rule: only
if it also helps or does not hurt 1x). It stays a setting for a rough day.

## The 1.5x waves (lc15a, lc15b)

`--lake_wave_scale=1.5`, the lake only (130 cases a variant: the 40 afternoon reaches and the three
sets of 30), two rounds, 12 variants. It did not fail much, so it was not stopped early.

| Variant | Falls (of 130) | Afternoons beam / broad / mid | Map / 18 kt / 24 kt sets | What it is |
|---|---|---|---|---|
| before | 28 | 12.5 / 8.9 / 8.0 (3 falls) | 10 / 2 / 13 | the controller as it was |
| **final** (the shipped defaults) | **21** | 13.3 / 8.9 / 8.0 (4 falls) | 8 / 1 / 8 | |
| `f_wind1517`, `w1517hu6` | **9**, 9 | **13.8** / 8.8 / 8.0 (0 falls) | 0 / 1 / 8 | the ease in the air from 15 to 17 kt at the sail (and the carve-up ease at 6) |
| `w1517chop15` | 10 | 13.8 / 8.8 / 8.0 (1) | 0 / 2 / 7 | and 15 % less pull in chop |
| `w1618`, `w1517b1014` | 12, 12 | 11.8, 12.9 | 0 / 1 / 8, 0 / 1 / 11 | the gate at 16 to 18 kt; the chop gate higher |
| `f_chop15`, `f_hike10`, `f_hu6` | 19, 21, 22 | 12.1 to 13.3 | | less pull in chop, less pull, the carve-up ease at 6 |
| `f_air4`, `f_s25` | 25, 28 | 12.5, 13.6 | | a stronger ease in the air; the faster sheet |

At 1.5x the map's wind (15 to 18.5 kt at the sail) is already strong enough to throw the board off
the higher crests, so the ease in the air pays from less wind there; the steady 24 kt set stays at
7 to 13 falls in 30 for every variant (before 13; the long beam reach, as at 1x). The report on the waves
(`Documentation/reports/waves/lake_waves_full.md`) called 1.5x "a rough day"; the autopilot gets
through it with a quarter fewer falls than before, and with the lower gate with two thirds fewer.

## The checks on the final code

- `tools/test.sh validation`: 48 tests, 38 pass, 8 fail, 2 pending, the same eight known reds (the
  polar sweep's speeds and shape, the top speed 14.67 m/s, the planing onset 7.42 m/s, the fin's
  side force 745 N, the push warning, the skipper's 12 kt limit 12:24.8 (before 12:21.2), the settled
  speed on waves at TWA 120 12.09 m/s). 19 min (the PC busy with the rounds).
- `tools/test.sh`: 835 of 835 (822 before; 13 new in `test_controller_chop.gd`).
- `tools/check.sh`: 442 files, 0 failed.
- `tools/lan_test.sh --map=lake`: SYNC CHECK: PASS.
- `Game/default_bus_layout.tres` and `Game/project.godot` restored after every round (the suite does it).

## The rounds, in files

`Documentation/reports/autopilot/rounds/`: `lc0.txt` (the baseline), `lc1.txt`, `lc1b.txt` (merged
into lc2, not run on its own), `lc2.txt`, `lc3.txt`, `lc4.txt`, `lc5.txt`, `lc5d.txt`, `lc6.txt`,
`lc7.txt`, `lc7s.txt`, `lc8.txt`, `lc15a.txt`, `lc15b.txt`. Each round's outputs:
`.sim_output/autopilot/<round>/<variant>/` (not committed); `python -I tools/autopilot_summary.py
<round> --table` prints them. Two rounds were stopped a minute or three in and started again with
better settings (`lc3_stopped`, `lc7_stopped`, kept, not used). The rounds ran from 02:43 to 07:30
on 13 to 14 Godot processes at a time.
