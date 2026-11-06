# The autopilot on the lake's chop: the training of 6 November 2026

(Draft, filled in as the rounds come in.)

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
120 lake cases and speeds over 40 reaches, and why a winner is checked again on more patterns.

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
