# GP0: the push and the body, measured before they are built

**Branch:** `gp0/measure`, from `main` (d679074). Session 56, 26 October 2026. No agents. **Nothing in `Game/sim/` changed:** every number below comes from settings the autopilot and the sailor's technique already have. The item is GP0 in [ROADMAP.md](../../../ROADMAP.md), section GP.

## In short

1. **Pushing pays, but only if the pushed sailor also eases late.** Holding more pull alone (`Autopilot.hike_share`) pays upwind (VMG +9 % from 1.1 to 1.6) and hardly at all on the reaches. With the late ease as well (the ease on heel and the catch weakened), the push gives **+16 to 19 % VMG upwind**, **+12 to 15 % on the close reach** (75°) and **+4 to 5 % on the beam and broad reaches** at 18 and 24 kt.
2. **The risk is real and comes with the wind.** At 12 kt nothing changes. At 18 kt in the default gusts nothing falls, even fully pushed. At 24 kt, a board pushed all the time catapults 3 to 15 times in 200 to 400 s on the 100 to 135° reaches and ends up slower than neutral. With stronger gusts (0.3), the fully pushed board also falls upwind at 18 kt.
3. **The timing skill works.** A sailor who pushes and eases as each gust arrives sails the 24 kt beam reach at **13.00 m/s with no falls**. Neutral does 12.22 to 12.52, and pushing all the time gives 12.39 with 6 falls. Easing up to 1 s early works; 2 s is too early.
4. **Falls come with a warning, but not from the fin.** 117 of the 124 falls are catapults, and 101 of them round up just before. For a second the sail pulls harder than the feet can hold while the board speeds up in the gust; in the last half second the nose lifts and the bow swings up at 15 to 27 °/s. The fin is not part of it: before a fall it carries a tenth to a fifth of its stall, and it stalls only in the moments around a fall and the restart after it. The heel stays small until the fall itself. There are no spin-outs (PH6).
5. **Package B has something to find.** On the 18 kt broad reach the back foot is worth about 10 % over 0.1's trim (in steady wind, 20 % between the least and the most trim). On the beam reaches a flat board beats 8 to 10° of rail by 3 to 10 %. The fastest rail is always the flattest; rail buys stability at speed. More trim is faster until the board bounces, and that limit falls with speed. At 24 kt too much trim on a flat board catapults, and with 5 to 6° of rail the same trim is safe and fastest. Upwind and below planing the two do almost nothing.
6. **Neutral (GD3):** `hike_share` 1.0 with today's safety nets. It is 1 to 3 % slower than 0.1's 1.1, and it does not catapult on the 24 kt broad reach, where 1.1 falls twice in 400 s. Neutral is then 82 to 84 % of the full push upwind and 94 to 98 % on the reaches.

## How it was measured

`tools/push_check.sh` (new; the runner is `Game/dev/run_push.gd`) sails the default board the way the player's board is sailed in beginner mode: `PlayerController` with the auto-sheet, fed by `AiHands`, which hold a true wind angle with `LearnedSkipper.steer_toward_twa()`. Each case:
- **The water and the wind:** the game's open water, with the waves, the height gradient and the gusts on. The gusts are 0.2 and 8 s, the game's settings when gusts are switched on; the lake's are 0.25. There are no shifts.
- **The course:** starboard tack, starting from rest on a reach (70 to 100° until 5 m/s), then the course. Means are taken from 40 s.
- **The dial:** the settings are written into `controller.auto_sheet_pilot` every tick, before the controller runs, as GP1 will do. The pilot is a new one after every waterstart.
- **The body:** the technique's targets are written into the board's own copy of `SailorConfig` once, as GP2's mouse would.
- **Falls:** they are real. The sim waterstarts after its own 4 s, and the controller starts again, so a fall costs what it costs in the game.
- **What is kept:** the speed made good along the course (the VMG to the wind at 48°), the falls, the fin's load and slip, the heel, the pitch and the trim. Each fall also gets the 2 s before it. The CSVs are in `.sim_output/push/<run>/` (not in git); the commands are at the end.

Upwind is 48° (the true upwind case; the board planes about a third of the time there at 18 and 24 kt). The reaches are 75, 100, 120 and 135°, and the run is 150°.

## (a) The push

### Which number makes the difference

80 s per case, gusts 0.2. Speed made good in m/s (VMG at 48°); `/n` is the number of falls.

| `hike_share` | 12/48 | 12/100 | 18/48 | 18/100 | 18/135 | 24/48 | 24/100 | 24/135 |
|---|---|---|---|---|---|---|---|---|
| 0.8 (eased) | 2.53 | 8.42 | 2.91 | 10.12 | 10.62 | 2.81 | 11.05 | 13.67 |
| 1.0 | 2.73 | 8.82 | 3.76 | 11.50 | 10.59 | 3.90 | 12.15 | 13.65 |
| **1.1 (0.1 today)** | 2.74 | 8.89 | 3.89 | 11.63 | 10.59 | 4.03 | 12.57 | 14.18 |
| 1.25 | 2.74 | 8.88 | 4.03 | 11.49 | 10.59 | 4.15 | 12.70 | 13.96 |
| 1.4 | 2.74 | 8.88 | 4.12 | 11.63 | 10.59 | 4.22 | 12.89 | 12.65/1 |
| 1.6 | 2.74 | 8.88 | 4.24 | 11.79 | 10.59 | 4.30 | 13.07 | 11.46/2 |

- `hike_share` (how much pull the sailor holds against what their weight balances) is the number.
- `ankle_share` does the same, more weakly: 0.4 to 1.6 moves 24/100 from 12.08 to 12.79.
- The heel allowance (2 to 15°) and the catch (0 to 8°) change less than 1 % on their own.
- At 12 kt nothing binds: the sailor holds the whole sail at any setting, so only easing costs speed. That is the design's rule 4.
- On the broad reach (135°) the cap hardly binds even at 24 kt, because the sail is eased out and its pull is mostly forward. Pushing there gives only falls.

### The push that also eases late

Pushing in the sense of the design ("holds more pull, eases late") is `hike_share` 1.6 with the safety nets weakened: `depower_alpha_per_deg` 1.0 → 0.3 (the ease when the board heels to leeward), `depower_rate_per_s` 0.25 → 0.05 and `depower_urgent_rate_per_s` 2.0 → 0.5 (the slow ease in a turn), and `catch_alpha_max_deg` 4 → 0 (no sheeting in to catch a fall backwards). 200 s per case:

| | 18/48 | 18/75 | 18/100 | 18/120 | 18/135 | 18/150 | 24/48 | 24/75 | 24/100 | 24/120 | 24/135 | 24/150 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1.1, today's nets | 3.89 | 9.30 | 11.66 | 12.22 | 10.58 | 5.07 | 4.02 | 9.96 | 12.54 | 14.19 | 13.48/1 | 9.61 |
| 1.6, today's nets | 4.24 | 9.86 | 11.74 | 12.49 | 10.58 | 5.20 | 4.29 | 10.36 | 13.09 | 13.64/2 | 13.62/1 | 9.61 |
| **1.6, late ease** | **4.50** | **10.44** | **12.28** | 12.72 | 10.66 | 4.97 | **4.78** | **11.44** | 12.40/3 | 11.12/7 | 13.77/1 | 9.61 |

(75° shows the speed made good along the course here, not the VMG.)

The late ease is what makes the push pay: over today's neutral, upwind +16 % at 18 kt and +19 % at 24 kt, the close reach +12 % and +15 %, and the 18 kt beam and broad reaches +4 to 5 %, with no falls at 18 kt. At 24 kt the same push falls 3 to 7 times in 200 s on the reaches.

### How often it falls (400 s per case, 24 kt)

| `hike_share`, today's nets | 24/100 | 24/120 | 24/135 | 24/150 |
|---|---|---|---|---|
| 1.0 | 12.22 | 14.04 | **14.11** | 9.61 |
| 1.1 (0.1 today) | 12.52 | 14.15 | 13.57/2 | 9.60 |
| 1.25 | — | 14.36 | 13.31/3 | 9.60 |
| 1.4 | — | 14.25/1 | 13.85/1 | 9.60 |
| 1.6 | — | 13.65/4 | 13.34/3 | 9.60 |
| 1.6, late ease | 12.39/6 | 11.01/15 | — | — |

0.1's own setting catapults twice in 400 s on the 24 kt broad reach. This is PH17's finding (catapults at 24 kt on broad reaches at 13.6 to 14.1 m/s), measured. 1.0 does not fall and is faster there.

### Easing before each gust

The open sea's gusts are a known function of time (`WindField`), so the script knows them. It pushes (1.6 with the late ease) and goes back to neutral (1.0 with today's nets) while the gust, now or `lead` seconds ahead, is more than 30 % of the way up its swing. That is about 27 % of the time at lead 0 and 52 % at lead 2. 400 s per case, 24 kt:

| | 24/100 | 24/120 |
|---|---|---|
| Neutral 1.0 / 1.1 | 12.22 / 12.52 | 14.04 / 14.15 |
| Pushed all the time | 12.39/6 | 11.01/15 |
| **Pushed, eased for each gust, lead 0 s** | **13.00** | 14.08/1 |
| lead 0.5 s | 12.82 | 13.81/2 |
| lead 1 s | 12.66 | **14.37** |
| lead 2 s | 12.65 | 13.93/1 |

So the skill the design wants exists in the physics: push in the lulls and ease for the gusts, and you beat both the safe sailor and the reckless one. With a broad reach that pushing does not speed up (135°, first try with 1.6 and today's nets), the timing only avoids the falls (14.15 against a constant 1.0's 14.11). It cannot beat neutral there, because there is nothing to gain.

The falls follow the gusts. Of the 42 falls in the first runs, 24 came in the second after the gust's peak (2 to 3 s into the 8 s period, where the peak is at 1.5 s), as the board speeds up in the gust.

### Stronger gusts (0.3, 200 s per case)

| | 18/48 | 18/100 | 18/120 | 18/135 | 24/48 | 24/100 | 24/120 | 24/135 |
|---|---|---|---|---|---|---|---|---|
| 1.0 | 3.72 | 11.43 | 12.09 | 10.74 | 3.83 | 11.95 | 12.76/2 | 13.31/1 |
| 1.1 | 3.83 | 11.66 | 12.20 | 10.74 | 3.96 | 12.26 | 13.91 | 12.89/2 |
| 1.6, late ease | 4.00/2 | 12.30 | 12.80 | 10.67 | 4.68 | 9.89/8 | 8.67/11 | 11.79/5 |

The risk moves down the wind range as the gusts grow: at 18 kt the fully pushed board now falls upwind. At 24 kt even neutral falls once or twice in 200 s on the broad reaches, so in strong gusty wind neutral wants to sit a little lower (GP3).

### The warning signs (for SO1 and GR1)

All 124 falls of the runs above: 117 catapults and 7 "fell off". 122 were at 24 kt (24 on the 100° reach, 48 at 120°, 50 at 135°) and 2 at 18 kt upwind. Medians:

| Before the fall | 2 s | 1 s | 0.5 s | 0.25 s | at it |
|---|---|---|---|---|---|
| The feet's overload (N m the feet cannot pass) | 129 | 136 | 32 | 30 | — |
| Speed (m/s) | 14.3 | 14.9 | 14.9 | 14.8 | — |
| Pitch (°, nose up) | 0.8 | 1.3 | 2.0 | 4.5 | 5.3 |
| Yaw rate (°/s) | 3 | 7 | 15 | 22 | 27 |
| Leeward heel (°) | 1.8 | 1.5 | 0.8 | 0.3 | 22 |
| The fin's load (share of its stall) | 0.16 | 0.13 | 0.09 | 0.19 | 0.24 |
| The sail's angle of attack (°) | 12.5 | 8.9 | 8.5 | 4.2 | — |

- **How a fall goes:** for one to two seconds the sail pulls harder than the feet can hold (76 of 124 falls show the overload toward leeward a second before), and the board accelerates in the gust. The autopilot eases (the angle of attack halves), too late. In the last half second the nose lifts and the board rounds up into the wind (101 of 124), and the sailor goes over the sail.
- **What warns:** the sailor's strain (how much of the hike and the feet is used), the board speeding up in a gust, then the nose lifting and the round-up.
- **What does not warn:** the fin's load, which stays at a tenth to a fifth of its stall before the falls (its 95th percentile peaks at 0.82 of the stall upwind, where nothing falls; it stalled only in the 44 cases with falls, around the fall or the restart), and the heel, which stays small until the fall.
- **Checked tick by tick** (the test `tests/validation/test_push_warning.gd`, the 24 kt 120° reach fully pushed, five catapults in 150 s): until the last half second the fin carried at most 0.21 to 0.30 of its stall before every catapult, while the sailor was overloaded for 1.15 to 1.57 s and the board rounded up at 25 to 102 °/s. Inside the round-up itself the spinning board can load the fin (0.89 of its stall 0.07 s before one catapult), but that is the fall, not a warning of it.
- So SO1's "hum rising as the fin nears its stall" would be silent before every fall today. The rig's strain that SO1 also lists, and GR1's chatter, should follow the sailor's overload (`Telemetry.feet_moment_excess_nm`, `lean`) and the pitch, until PH6 gives the fin a real spin-out to warn of.

## (b) The body: the rail and the back foot

The rail is `SailorConfig.fin_load_bank_deg`: the leeward rail down, as aimed for by the feet while hiked in the straps and not turning. The back foot is a constant trim target, `running_trim_deg` and `running_trim_fast_deg` set together, which replaces 0.1's rule of 2.0° falling to 1.5° at speed. Both act only while planing in the straps, as in the game.

### Steady wind, flat water (as U2's map; 50 s per case)

Speed made good in m/s (VMG at 48°); the pitch SD in brackets where the board bounces (0.3° or more):

| Bank°, trim° | 12/48 | 12/100 | 12/135 | 18/48 | 18/100 | 18/135 | 24/48 | 24/100 | 24/135 |
|---|---|---|---|---|---|---|---|---|---|
| 0, 0.5 | 3.05 | 8.76 | 5.07 | 3.99 | 11.60 | 9.39 | 4.17 | 13.28 | 14.70 |
| 0, 1.5 | 3.07 | 8.83 | 5.08 | 4.03 | 11.86 | 9.52 | 4.22 | 13.52 | 14.40 |
| 0, 2.5 | 3.00 | 8.83 | 5.09 | 4.06 | 12.14 | 10.70 | 4.22 | 13.92 | 14.60 (1.2) |
| 0, 3.5 | 2.86 | 8.83 | 4.66 | 3.95 | **12.30** | 11.36 (1.0) | 4.22 | 13.92 (0.3) | 13.78 (1.5) |
| 2, 0.5 | 3.04 | 8.78 | 5.09 | 4.02 | 11.11 | 9.28 | 4.18 | 12.88 | 13.28 |
| 2, 1.5 | 3.05 | 8.80 | 5.09 | 4.07 | 11.61 | 9.36 | 4.22 | 13.10 | 13.99 (0.4) |
| 2, 2.5 | 2.99 | 8.80 | 5.07 | 3.93 | 11.81 (0.4) | 10.62 | 4.22 | 13.42 (0.4) | 14.45 (0.6) |
| 2, 3.5 | 2.86 | 8.80 | 4.66 | 3.97 | 11.92 (0.4) | 11.06 (1.2) | 4.22 | 13.52 (0.4) | 11.79/1 (1.7) |
| 4, 2.5 | 2.76 | 8.94 (0.6) | 5.06 | 3.92 | 11.39 (0.5) | 10.50 (0.6) | 4.12 | 12.74 | 14.24 (0.8) |
| 4, 3.5 | 2.71 | 9.24 (0.6) | 4.66 | 3.94 | 11.46 (0.4) | 11.29 (0.9) | 4.13 | 12.94 | 11.35/1 (1.5) |
| 6, 2.5 | 2.60 | 8.73 | 5.04 | 3.92 | 11.24 | 10.48 | 4.09 | 12.64 | 14.15 (0.9) |
| 6, 3.5 | 2.60 | 8.89 (0.5) | 4.66 | 3.94 | 11.29 (0.3) | **11.38** | 4.08 | 12.73 | **14.35** (0.9) |
| 8, 2.5 | 2.50 | 8.46 | 5.02 | 3.94 | 11.15 | 10.42 | 4.11 | 12.62 | 14.02 (0.9) |
| 8, 3.5 | 2.50 | 8.66 | 4.65 | 3.97 | 11.20 | 11.35 (0.3) | 4.12 | 12.67 | 14.24 (0.9) |
| 10, 2.5 | 2.45 | 8.30 | 5.01 | 4.00 | 11.12 | 10.42 | 4.13 | 12.61 | 13.99 (0.9) |
| 10, 3.5 | 2.45 | 8.45 | 4.66 | 4.04 | 11.19 | 11.37 (0.3) | 4.15 | 12.64 | 13.72 |

(Bank 4, 6, 8 and 10 at trims 0.5 and 1.5 are in the CSV; they follow the same pattern.)

### Gusts 0.2 and waves, the sailor's correction at 0.4 s (0.1) and slowed to 2 s (level 2; 110 s per case)

| Bank°, trim° | 18/48 | 18/100 | 18/135 | 24/48 | 24/100 | 24/135 | 24/135 at 2 s |
|---|---|---|---|---|---|---|---|
| 0, 1 | 3.85 | 11.52 | 10.15 | 3.98 | 12.28 | 13.81 | 10.99/3 |
| 0, 2 | 3.84 | 11.72 | 10.58 | 4.00 | 12.55 | 13.81 | 10.59/2 |
| 0, 3 | 3.85 | **11.81** | 11.47 | 4.00 | 11.15/2 | 12.15/1 | 9.28/5 |
| 2, 1 | 3.89 | 11.53 | 10.09 | 4.02 | 12.28 | 14.07 | 14.15 |
| **2, 2 (≈ 0.1)** | 3.89 | 11.65 | 10.54 | 4.03 | 12.53 | 14.16 | 10.26/3 |
| 2, 3 | 3.88 | 11.79 | 11.65 | 4.03 | 12.59 | 11.60/3 | 9.38/4 |
| 5, 1 | 3.83 | 11.43 | 9.91 | 3.94 | 12.18 | 13.79 | 13.79 |
| 5, 2 | 3.83 | 11.57 | 10.54 | 3.94 | 12.23 | 14.05 | 14.04 |
| 5, 3 | 3.82 | 11.65 | **11.67** | 3.94 | 12.43 | **14.17** | 12.94/1 |
| 8, 1 | 3.85 | 11.31 | 9.92 | 3.94 | 12.18 | 13.56 | 13.56 |
| 8, 2 | 3.86 | 11.38 | 10.56 | 3.95 | 12.17 | 13.76 | 13.73 |
| 8, 3 | 3.84 | 11.42 | 11.39 | 3.95 | 12.21 | 13.92 | 13.86 |

The slowed correction changes the other columns by about 2 % or less, apart from the cases that fall in both; only the 24 kt broad reach changes, so it is the only one shown at 2 s. There the boards with little rail bounce hard (pitch SD 5 to 7°) and fall 2 to 5 times in 110 s. On waves the pitch SD is about 1° everywhere (the swell), so it does not tell a bounce apart there.

### What the map says

- **The back foot is the big one.** On the 18 kt broad reach a trim of 3 to 3.5° is 10 % faster than 0.1's 2° in gusts and waves (11.67 against 10.54) and 20 % faster than 0.5° in steady wind. On the beam reaches it is worth 1 to 6 %. 0.1's trim was chosen in U2 for a steady ride, not for speed ([fin_technique.md](../u2/fin_technique.md)), so a player who learns the back foot really does go faster.
- **The rail has no sweet spot in the middle.** The flattest board is always the fastest on the reaches: 3 to 10 % over 8 to 10° of rail. Rail buys stability: at 24 kt, 3° of trim on a flat board catapults (0 and 2° of bank: 1 to 3 falls), and with 5 to 6° of rail the same trim is safe and the fastest of all (14.17 in gusts, 14.35 steady). The edge to play is "as flat and as far back as you dare, more rail when it gets wild". It does not sit at a fixed angle.
- **The peak's sharpness:** on the trim, about 1 m/s (8 to 10 %) between 2° and 3° on the 18 kt broad reach, and at 24 kt the bounce or the fall within 1° beyond the best. On the rail, 0.1 to 0.4 m/s per 2° on the 18 kt beam reach.
- **What too much does:** too much trim bounces (in steady wind the pitch SD rises to 1 to 1.7° first), and at 24 kt it catapults. Too much rail is only slower. The fin did not let go in any of these cases.
- **Where it does nothing:** upwind (the board planes a third of the time at 48°, and the targets act only planing in the straps; ±3 %) and below planing. At 12 kt the broad reach stays at 5 m/s whatever is set, and rail upwind at 12 kt costs up to 20 % (3.05 → 2.45). The roadmap's "below planing the mouse does nothing yet" holds.
- **Level 2** matters only where it gets wild: with the correction slowed, the 24 kt broad reach needs 5° of rail or more to stay up. That is a real difficulty step, and it belongs to strong wind.
- **Not tried:** a rail to windward (negative `fin_load_bank_deg`), and the 60° close reach.

## (c) The gybe's timing

Not measured. GP8 is for 0.3, and measuring the flip needs the gybe sailed with `SimControls.hold_side` held to a chosen moment, which is a harness of its own. It is a new item, GP9 (PH4 waits on it).

## What this means for the build

**The dial (GP1), from these numbers** (GP3 tunes them by playing):

| Dial | `hike_share` | `ankle_share` | `depower_alpha_per_deg` | `depower_rate_per_s` | `depower_urgent_rate_per_s` | `catch_alpha_max_deg` |
|---|---|---|---|---|---|---|
| Eased (S held) | 0.8 | 0.8 | 1.0 | 0.25 | 2.0 | 4 |
| **Neutral (nothing pressed)** | **1.0** | 0.8 | 1.0 | 0.25 | 2.0 | 4 |
| Pushed (W held) | 1.6 | 0.8 | 0.3 | 0.05 | 0.5 | 0 |

In between, every number moves in a straight line with the dial. What the player gets:
- Eased costs 13 % on the reaches and 25 to 30 % upwind.
- Pushed gains 16 to 19 % upwind, 12 to 15 % on the close reach and 4 to 6 % on the beam and broad reaches, and at 24 kt (or 18 kt in strong gusts) it catapults unless the player eases for the gusts.
- Neutral is a little slower than 0.1's autopilot (1 to 3 %) and falls less.
- The other margin settings (the heel allowance, the sheet-in pace) stay as they are: alone they changed less than 1 %.

**The feedback (SO1, GR1):** warn on the sailor's overload (`feet_moment_excess_nm` and the hike used), the gust's acceleration, the nose lifting and the round-up. The fin's load warns of nothing yet.

**The mouse (GP2):**
- **The rail:** 0 to 8° of bank; the centre (mouse left alone) is 0.1's 2°. Beyond 8° is only slower.
- **The back foot:** a constant trim target from 0.5 to 3.5°; the centre is 0.1's rule (2.0° falling to 1.5° at speed).
- Both act only while planing, as now. GD7's choices stay settings to try.

## Findings for Michiel

The stop rule was "if more push gives no speed, or the risk comes with no warning". Neither is quite the case, but:
1. **The push gives speed only with the late ease.** Holding more pull alone gives little on the reaches: the sailor is already fully hiked, and the extra pull is turned into heel and eased away. The dial therefore weakens the autopilot's safety nets. That is the sailor's own reflex, set by the player, and not physics, but Michiel may want to see it.
2. **The risk is all catapults.** There are no spin-outs: the fin stalls only around falls that have already begun, never before them. So the second risk the design names needs PH6.
3. **0.1's neutral catapults at 24 kt on the broad reach** (twice in 400 s at 135°, PH17), and at 24 kt in gusts of 0.3 so does `hike_share` 1.0.
4. **The open sea's gusts jump.** `WindField` takes the gust's phase modulo one period, but its second and third waves (2.3 and 5.7 times the period's frequency) do not restart there, so the wind drops by 3.8 % in one tick every 8 s at intensity 0.2. The gusts also repeat exactly every 8 s, so a player could learn their rhythm by ear. This belongs with PH7, moving gust patches.
5. **The run is slow:** at 150° the board makes 5.0 to 5.2 m/s at 18 kt and 9.6 m/s at 24 kt, against 10.6 and 14.1 m/s at 135° (PH17).
6. **The technique's trim** (U2: 2.0° to 1.5° at speed) is 10 to 20 % slow on the 18 kt broad reach against 3 to 3.5°, at the cost of a bounce in steady wind. That was chosen for steadiness; with package B the player chooses.

## The commands

```
C="--winds=12,18,24 --twas=48,100,135 --seconds=120 --from=40 --jobs=4"
tools/push_check.sh $C --run=a1_hike --sweep=pilot.hike_share=0.8,0.9,1.0,1.1,1.25,1.4,1.6
tools/push_check.sh $C --run=a2_ankle --sweep=pilot.ankle_share=0.4,1.2,1.6
tools/push_check.sh $C --run=a3_heel --sweep=pilot.depower_heel_allowance_deg=2,10,15
tools/push_check.sh $C --run=a4_catch --sweep=pilot.catch_alpha_max_deg=0,8
LATE="--pilot.hike_share=1.6 --pilot.depower_alpha_per_deg=0.3 --pilot.depower_rate_per_s=0.05 --pilot.depower_urgent_rate_per_s=0.5 --pilot.catch_alpha_max_deg=0"
tools/push_check.sh --winds=18,24 --twas=48,75,100,120,135,150 --seconds=240 --from=40 --jobs=4 --run=b1_push --sweep=pilot.hike_share=1.1,1.6
NETS="--pilot.depower_alpha_per_deg=0.3 --pilot.depower_rate_per_s=0.05 --pilot.depower_urgent_rate_per_s=0.5 --pilot.catch_alpha_max_deg=0"
tools/push_check.sh --winds=18,24 --twas=48,75,100,120,135,150 --seconds=240 --from=40 --jobs=4 --run=b1_late $NETS --sweep=pilot.hike_share=1.1,1.6
tools/push_check.sh --winds=24 --twas=120,135,150 --seconds=440 --from=40 --jobs=4 --run=b2_long --sweep=pilot.hike_share=1.0,1.1,1.25,1.4,1.6
tools/push_check.sh --winds=24 --twas=100,120 --seconds=440 --from=40 --jobs=4 --run=c1_timing $LATE --timing=1 \
  "--timing_ease=pilot.hike_share:1.0;pilot.depower_alpha_per_deg:1.0;pilot.depower_rate_per_s:0.25;pilot.depower_urgent_rate_per_s:2.0;pilot.catch_alpha_max_deg:4" \
  --sweep=timing.lead_s=0,0.5,1,2
tools/push_check.sh --winds=18,24 --twas=48,100,120,135 --seconds=240 --from=40 --jobs=4 --gust_intensity=0.3 --run=c2_g3_late $LATE
tools/push_check.sh --winds=12,18,24 --twas=48,100,135 --seconds=90 --from=40 --gusts=0 --waves=0 --jobs=4 --run=d1_map_steady \
  --sweep=sailor.fin_load_bank_deg=0,2,4,6,8,10 --sweep2=sailor.running_trim_deg+sailor.running_trim_fast_deg=0.5,1.5,2.5,3.5
tools/push_check.sh --winds=18,24 --twas=48,100,135 --seconds=150 --from=40 --jobs=4 --run=d2_map_gusty \
  --sweep=sailor.fin_load_bank_deg=0,2,5,8 --sweep2=sailor.running_trim_deg+sailor.running_trim_fast_deg=1,2,3   # and d3 with --sailor.lean_feel_time_s=2.0
```

All in all about 600 cases, run four processes at a time (the laptop crashed under full load before; four never came close).
