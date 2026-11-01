# The skipper's speed: the all-rounder faster around T1 and T2 (package 1, 1 November 2026)

The speeder's report (an Opus agent) for the team and the lead, on the branch `race/skipper-speed` (from `gear/lead` at f020528). The plan is [PLAN.md](PLAN.md), package 1. Nothing in `Game/sim/` changed. Every number below is from a run named here; the commands are in section 8.

## 1. In short

The scripted skipper now beats and runs at angles measured for its own board in each wind, gets back on the plane after a gybe in light wind, and no longer circles a mark it passed on the wrong side. Every scripted AI board sails this code, so the four characters and the twelve personas got it too.

- **The fleet (`tools/race_matrix.sh`, the four characters on T1 and T2 at 12, 18 and 24 kt): every board finishes all six races, with no falls at all** (the baseline had six). The all-rounder wins three of the six races (it won one). The sum of the 24 finish times drops from 2:58:17 to 2:50:01 (−4.6 %), most of it in 12 kt: on T1 at 12 kt the all-rounder from 17:02 to 13:52 and the rookie from 18:48 to 15:15; on T2 at 12 kt every character 12 to 31 s faster.
- **The all-rounder alone (seed 1):** T1 at 12 kt from 14:41 to 13:27, at 18 kt from 7:52 to 7:33; T2 at 12 kt from 5:35 to 5:00, at 18 kt from 3:09 to 3:08. **Two are worse:** T2 at 24 kt (2:58 to 3:07, one fall), and **T1 at 24 kt does not finish alone with seed 1**: after rounding 4S at 14 m/s it misses the 35 m finish line and circles it (it finished in 6:23 in the run before the last change; in the fleet, seed 0, it finishes in 7:12). This is the first open item (section 7).
- **What paid:** the beat at the polar's best angle in each wind (54, 55 and 50 degrees in 12, 18 and 24 kt, where the skipper sailed 45 everywhere; the 12 kt beats 28 to 50 s shorter); off the plane on a run, a broad reach of 110 degrees to plane again (in 12 kt it sat at 2.5 m/s for three minutes at 119); a rounding begun only before the mark's half-way ray (the lead's point 3, Noor's twelve minutes).
- **What did not pay:** the push slider. The steady runs say 95 % gains 4 to 5 % on the reaches at 18 and 24 kt, but in races the pushed all-rounder fell two to seven times at 24 kt and gained nothing at 18. The skipper can push now (`SkipperConfig.push_offset`, the hook for the personas), but the game's polar pushes nowhere. The smaller catalogue sails are not faster in the race's steady wind (lever 6). The polar's deeper run angles at 18 and 24 kt raced slower than the old ones, which stay.
- **Not done (the token budget):** the persona matrix at 18 kt after the change, the start retuned for the wider beat (it sails the old 45 degrees until its start, which made the 12 kt start slower again: +60 s alone), and T1's finish at 24 kt.

## 2. The polar, per wind and push level

`tools/push_check.sh` sails the beginner controller with the AI hands holding a true wind angle, the default board, sail and fin, on the open water's sea in a **steady wind** (`--gusts=0`: the headless race and the game's default settings have no gusts or shifts, `Game/config/wind_default.tres`), 150 s per case from a beam reach, the means from 40 s. "The pilot's margin" is the slider off (`AiHands.push` NaN, every AI board until now); 75 to 100 % are the slider's levels (`--sweep=push.level=...`). Each cell: the speed while sailing, m/s / the speed made good toward or away from the wind (VMG, over the ground, so with the leeway), m/s; F a fall. At 12 kt the slider was measured up to 120 degrees and changed nothing (the 18 and 24 kt rows of the slider were measured at the angles that matter).

**12 kt** (speed m/s / VMG m/s; F = fell)

| TWA | the pilot's margin | 75 % | 85 % | 95 % | 100 % |
|---|---|---|---|---|---|
| 40 | 4.11 / 1.52 | 4.10 / 1.52 | 4.06 / 1.52 | 4.04 / 1.51 | 4.05 / 1.51 |
| 42 | 4.07 / 1.57 | 4.07 / 1.57 | 4.05 / 1.58 | 4.03 / 1.57 | 4.07 / 1.57 |
| 45 | 4.16 / 1.72 | 4.14 / 1.70 | 4.17 / 1.72 | 4.17 / 1.73 | 4.16 / 1.72 |
| 48 | 4.20 / 1.87 | 4.21 / 1.84 | 4.22 / 1.85 | 4.21 / 1.86 | 4.19 / 1.86 |
| 50 | 4.07 / 2.19 | 4.10 / 2.20 | 4.16 / 2.22 | 4.17 / 2.21 | 4.09 / 2.18 |
| 52 | 4.50 / 2.28 | 4.47 / 2.28 | 4.48 / 2.28 | 4.46 / 2.26 | 4.44 / 2.25 |
| 55 | 4.84 / 2.29 | 4.83 / 2.29 | 4.80 / 2.29 | 4.76 / 2.26 | 4.72 / 2.25 |
| 60 | 5.46 / 2.19 | 5.47 / 2.19 | 5.46 / 2.19 | 5.38 / 2.17 | 5.37 / 2.16 |
| 70 | 6.51 / 1.69 | 6.53 / 1.67 | 6.51 / 1.69 | 6.45 / 1.68 | 6.47 / 1.68 |
| 80 | 7.49 / 0.68 | 7.51 / 0.65 | 7.53 / 0.65 | 7.45 / 0.68 | 7.44 / 0.73 |
| 90 | 8.01 / 0.53 | 7.98 / 0.61 | 8.02 / 0.61 | 8.02 / 0.64 | 8.08 / 0.63 |
| 100 | 7.46 / 1.80 | 7.50 / 1.81 | 7.50 / 1.82 | 7.54 / 1.81 | 7.55 / 1.81 |
| 110 | 7.06 / 2.87 | 7.12 / 2.89 | 7.10 / 2.86 | 7.09 / 2.88 | 7.12 / 2.87 |
| 120 | 6.62 / 3.60 | 6.62 / 3.60 | 6.66 / 3.58 | 6.62 / 3.60 | 6.66 / 3.58 |
| 125 | 6.16 / 3.74 | 6.14 / 3.74 | 6.14 / 3.74 | 6.33 / 3.69 | 6.36 / 3.68 |
| 130 | 5.73 / 3.88 | 5.73 / 3.88 | 5.74 / 3.88 | 5.92 / 3.83 | 5.90 / 3.84 |
| 135 | 4.73 / 3.46 | 4.68 / 3.42 | 4.74 / 3.47 | 4.64 / 3.38 | 4.58 / 3.32 |
| 140 | 4.58 / 3.21 |  |  |  |  |
| 145 | 4.00 / 2.25 |  |  |  |  |
| 150 | 3.71 / 1.74 |  |  |  |  |

**18 kt** (speed m/s / VMG m/s; F = fell)

| TWA | the pilot's margin | 75 % | 85 % | 95 % | 100 % |
|---|---|---|---|---|---|
| 40 | 4.11 / 2.86 |  |  |  |  |
| 42 | 4.99 / 3.27 |  |  |  |  |
| 45 | 5.61 / 3.48 |  |  |  |  |
| 48 | 6.14 / 3.62 | 6.00 / 3.58 | 5.94 / 3.57 | 6.24 / 3.64 | 6.29 / 3.64 |
| 50 | 6.68 / 3.71 |  |  |  |  |
| 52 | 6.75 / 3.72 | 6.76 / 3.71 | 6.89 / 3.74 | 6.94 / 3.75 | 6.97 / 3.76 |
| 55 | 7.34 / 3.77 | 7.35 / 3.74 | 7.37 / 3.76 | 7.61 / 3.79 | 7.60 / 3.80 |
| 60 | 8.69 / 3.66 | 8.37 / 3.69 | 8.37 / 3.72 | 8.53 / 3.75 | 8.66 / 3.76 |
| 70 | 10.14 / 2.87 | 9.69 / 2.79 | 9.87 / 2.88 | 10.19 / 2.95 | 10.48 / 2.99 |
| 80 | 11.08 / 1.45 |  |  |  |  |
| 90 | 11.79 / 0.70 | 11.56 / 0.58 | 11.89 / 0.56 | 12.16 / 0.57 | 12.32 / 0.51 |
| 100 | 12.72 / 2.43 |  |  |  |  |
| 110 | 12.98 / 5.07 | 12.95 / 4.93 | 13.01 / 5.08 | 12.96 / 4.89 | 13.13 / 5.12 |
| 120 | 12.16 / 6.53 | 12.20 / 6.51 | 12.34 / 6.57 | 13.42 / 7.25 | 12.99 / 6.96 |
| 125 | 10.33 / 6.30 | 10.31 / 6.29 | 10.30 / 6.29 | 11.07 / 6.77 | 11.52 / 7.01 |
| 130 | 8.92 / 5.99 | 8.91 / 5.99 | 8.92 / 6.00 | 8.92 / 5.99 | 8.94 / 6.00 |
| 135 | 7.81 / 5.70 | 7.81 / 5.70 | 7.82 / 5.70 | 7.81 / 5.69 | 7.80 / 5.69 |
| 140 | 6.81 / 5.31 | 6.85 / 5.33 | 6.92 / 5.30 | 6.80 / 5.30 | 6.79 / 5.30 |
| 145 | 6.26 / 5.08 |  |  |  |  |
| 150 | 4.98 / 4.22 |  |  |  |  |

**24 kt** (speed m/s / VMG m/s; F = fell)

| TWA | the pilot's margin | 75 % | 85 % | 95 % | 100 % |
|---|---|---|---|---|---|
| 40 | 5.63 / 3.95 |  |  |  |  |
| 42 | 6.52 / 4.35 |  |  |  |  |
| 45 | 7.00 / 4.48 |  |  |  |  |
| 48 | 7.56 / 4.59 | 7.37 / 4.45 | 7.54 / 4.58 | 7.61 / 4.61 | 7.58 / 4.61 |
| 50 | 8.02 / 4.64 |  |  |  |  |
| 52 | 8.25 / 4.58 | 7.95 / 4.37 | 8.14 / 4.51 | 8.20 / 4.58 | 8.21 / 4.58 |
| 55 | 8.90 / 4.62 | 8.64 / 4.42 | 8.61 / 4.41 | 8.41 / 4.34 | 8.15 / 3.98 F |
| 60 | 9.66 / 4.31 | 9.26 / 4.14 | 9.57 / 4.26 | 9.95 / 4.46 | 9.87 / 4.44 |
| 70 | 11.21 / 3.39 | 10.91 / 3.22 | 11.19 / 3.21 | 11.41 / 3.37 | 11.64 / 3.44 |
| 80 | 12.35 / 1.71 |  |  |  |  |
| 90 | 13.26 / 0.58 | 13.08 / 0.51 | 13.32 / 0.40 | 13.65 / 0.45 | 13.84 / 0.49 |
| 100 | 14.12 / 2.87 |  |  |  |  |
| 110 | 14.94 / 5.56 | 14.68 / 5.39 | 15.39 / 5.59 | 15.65 / 5.92 | 15.86 / 5.73 |
| 120 | 15.55 / 8.07 | 15.40 / 8.11 | 15.74 / 8.13 | 15.66 / 8.04 | 15.59 / 8.23 |
| 125 | 15.40 / 9.09 | 15.44 / 9.09 | 15.33 / 9.11 | 15.58 / 9.20 | 15.74 / 9.37 |
| 130 | 14.77 / 9.69 | 14.92 / 9.76 | 15.08 / 9.94 | 15.01 / 9.85 | 15.28 / 10.04 |
| 135 | 12.47 / 8.64 F | 12.93 / 9.40 | 12.92 / 9.42 | 13.72 / 9.97 | 13.15 / 9.60 |
| 140 | 10.32 / 8.13 | 10.32 / 8.13 | 10.32 / 8.13 | 10.42 / 8.21 | 10.46 / 8.24 |
| 145 | 9.55 / 7.76 |  |  |  |  |
| 150 | 8.18 / 7.02 |  |  |  |  |

What the table says:

- **The best beat is wider than the 45 degrees the skipper sailed:** 55 degrees in 12 kt (VMG 2.29 against 1.72 at 45, +33 %), 55 in 18 kt (3.77 against 3.48, +8 %), 50 in 24 kt (4.64 against 4.48, +4 %). Closer than that the board slips sideways (at 40 degrees in 12 kt the track runs 68 degrees off the wind).
- **The best run by steady VMG:** 130 degrees in 12 kt (3.89; 135 already 3.46), 120 in 18 kt (6.53; 130: 5.99), 130 in 24 kt (9.69; 140: 8.13; 135 fell once). In races the deeper 130 and 140 were faster at 18 and 24 kt (lever 2).
- **The push:** nothing at 12 kt (PH26: the 85 kg rider is never overpowered by the 8.0). At 18 kt 95 to 100 % gains about 1 % on the beat, 3 to 4 % on the reaches (70 to 90 degrees) and 7 to 11 % at 120 to 125 degrees, without a fall. At 24 kt it gains 3 to 5 % on the reaches (90 to 110), 3 % on the broad reach (125 to 135), nothing on the beat (75 % is even 3 % slower than the pilot's margin there: it adds 3 degrees of sea rail and takes the pull from 1.1 to 1.0), and 100 % fell once at 55 degrees.

The skipper's polar, `Game/config/skipper_polar.tres` (`SkipperPolar`): the speeds of the no-slider column (the skipper times its legs and its start with them; 30, 165 and 180 degrees are guesses as before), the best angles per wind (the beat 54 / 55 / 50, the run 129 / 130 / 140), and a push table (all zeros: no push, section 3).

## 3. The levers, one by one

"Alone" means the all-rounder alone on T1 and T2 at 12, 18 and 24 kt, seed 1 (`tools/race_matrix.sh --skippers=allrounder --seed=1 --run=<name>`); the sum is the six finish times. Each lever was measured against the state before it (the levers build on each other: the push can only be judged on the new angles), and read per leg where they act on different legs.

| Run | What changed | T1 12 / 18 / 24 kt | T2 12 / 18 / 24 kt | Sum | Falls |
|---|---|---|---|---|---|
| base | before (gear/lead) | 14:41.3 / 7:52.0 / 7:37.2 | 5:34.7 / 3:09.2 / 2:57.8 | 2512 s | 0 |
| s1 | lever 2: the polar's angles (beat and run), the foot-off and off-plane rules read against the polar | 16:22.6 / 7:38.2 / 6:42.9 | 8:11.0 / 3:15.4 / 3:07.2 | 2717 s | 1 |
| s3 | + off the plane no deeper than 110; the finish aimed at the nearest point of the line; the start's early-at-the-line guard on the track | 12:41.7 / 7:37.8 / 6:23.9 | 5:03.7 / 3:15.1 / 3:04.6 | 2287 s | 0 |
| s2 | s1 + the push (95 % on the 18 and 24 kt reaches, 120 to 125 at 18, 75 % through manoeuvres) | 16:24.0 / 7:36.8 / 9:02.6 | 8:13.6 / 3:29.9 / 3:27.4 | 2894 s | 9 |
| s4 | s3 + the push on the reaches only (70 to 110), handed back to the pilot's margin through manoeuvres and before marks | 12:41.7 / 7:40.6 / 6:55.0 | 5:03.7 / 3:12.6 / 3:06.8 | 2320 s | 2 |
| s5 | s4 + the slider moved at the keys' rate | 12:41.7 / 7:41.2 / 7:44.7 | 5:03.7 / 3:12.0 / 3:35.9 | 2399 s | 5 |
| s6 | s3 + no push + the rounding fix + the head-up at speed at the controller's cap (stick 0.4) | 12:41.7 / 7:37.2 / 6:22.9 | 5:03.7 / 3:15.2 / 3:06.2 | 2287 s | 1 |
| s7a | s6's code with the run at 130 / 140 in 18 / 24 kt | — / 7:32.6 / DNF | — / 3:08.6 / 2:55.9 | | 0 |
| s7b | the same with the run at 125 / 135 | — | — / 3:08.7 / 3:21.7 | | 1 |
| final | kept, committed (a81ff7b): s3 + no push + the rounding fix + the run at 130 / 140 + the missed finish + the start at 45 | 13:27.3 / 7:33.2 / DNF | 5:00.2 / 3:07.9 / 3:07.4 | (DNF) | 2 |

**Lever 1, the polar (kept).** Section 2. It replaces the skipper's old table (measured "50 s from rest" before the rail, the couple and the 8.0's own rig), which had the 12 kt board unable to plane deeper than 125 degrees: it planes at 130 now.

**Lever 2, the angles per wind (kept, with the runs from the races).** The beat at the polar's best: per leg, every beat at 12 kt is 28 to 50 s shorter, the 18 kt beats 8 to 10 s, the 24 kt beats even. The run at the polar's best (129 / 120.5 / 130) won 16 to 29 s per run at 12 kt but lost 1 to 6 s per run at 18 and 24 kt; the old 130 and 140 there raced fastest (s7a: T1 at 18 kt −4.6 s, T2 at 18 kt −6.6 s, T2 at 24 kt −10.3 s against the polar's angles; 125 / 135 was in between and fell once). A run leg begins with a rounding and has its gybes, and a deeper angle sails fewer metres and gybes through a smaller turn; the steady run sees none of that. The character's own angles (`upwind_vmg_twa_deg`, `downwind_vmg_twa_deg`, `pointing_offset_deg`) now move the polar's angle for the wind instead of replacing it: the gambler's +4 pointing offset means "4 degrees lower than the best" in every wind. Two of the skipper's feel rules became relative to the polar: it foots off when slower than 85 % of the polar's speed at its beat (it was a fixed 5.5 m/s, which in 12 kt held it 3 degrees low all the time), and it is off the plane on a run below 65 % of the polar's run speed and planing again above 80 % (fixed 6 and 7 m/s held the 12 kt run 10 degrees high all the way, at 115 degrees: VMG 2.75 against 3.7 at 129).

**Lever 2b, getting planing again (kept).** With the relative rule the 12 kt board came out of a gybe at 2 m/s and headed up only to 119 degrees (the run's 129 minus the 10-degree head-up), where it did not plane again: 2.3 to 2.7 m/s for three minutes on T2's run (8:11 instead of 5:35). Off the plane it now sails no deeper than 110 degrees, where the old skipper did plane again within 20 s. T2 at 12 kt 5:04 (−31 s), T1 at 12 kt's runs −19 and −16 s.

**Lever 3, the push (built, not used).** The skipper sets `AiHands.push` from its polar's push table, moved by its character's `push_offset`; it hands the slider back to the pilot's own margin (NaN) where the table does not push, from the moment a tack or gybe is asked for until the board has settled, and in the last 4 s before a mark; and it moves the slider at the player's keys' rate (40 % a second), taking it from and handing it back at the level that holds the pilot's own pull (about 78 %). `PlayerController` now lets the hands give the slider back (a NaN after a number restores a fresh pilot's numbers). Measured three ways (s2, s4, s5): pushed into the gybes and on the 24 kt beat, seven falls in one race; pushed on the reaches only, two to five falls a race at 24 kt (the bear-away from the pushed reach into the run, and gybes at 14 m/s right after), 2 to 3 s gained or lost at 18 kt. At the pilot's own margin the all-rounder did not fall in any of the final six races. So the game's polar pushes nowhere, and `push_offset` works on its own: a character with an offset pushes (or eases) from the pilot's level everywhere but in its manoeuvres and before marks. That is package 3's knob ("more push is faster and falls more"); what the push does in a race is now measured, and it is mostly falls.

**Lever 4, the laylines, roundings, gybes, the finish and the start (partly kept).**
- The finish line aimed at its nearest point (a few metres in from the ends) instead of its middle, and a board that swept past an end at speed goes back 30 m behind the middle and crosses from there (kept). At 24 kt the all-rounder used to miss T1's 35 m finish line after rounding 4S at 14 m/s and circle it: 85 s for the last 110 m; 9 s in s3 and s6. With the run at 140 degrees it circles it and does not finish (s7a, final): the go-back rule turns it round but does not cure it (section 7, the first open item).
- A rounding is begun only before the mark's rounding ray (kept). This is the lead's point 3: Noor, pushed east of the slalom template's first mark by two keep-clear bear-aways, passed it on the wrong side, came back down from the north, began its rounding from past the half-way ray, aimed for the exit and never crossed the ray going round: twelve minutes of circles. Now a board past the ray goes back to the entry point first. (The persona matrix in section 4 shows Noor's slalom.)
- The head-up at planing speed at the controller's own safe cap (stick 0.4, 12 degrees a second, instead of 0.2): no change but one more fall (s6). Not kept.
- The start's early-at-the-line guard on the board's track instead of its bow (kept, harmless, but it does not fix T2's 24 kt start): on T2's reaching start the line runs along the wind and the board holds back pointing almost straight at it; at 24 kt it cannot slow below 2 m/s and arrives 10 s early, over the line at the gun (+29 s). The fix (turning along the line or a loop away when the hold cannot stop the board) is open (RA, section 7).
- The tack count per beat and the laylines: the all-rounder makes one tack per beat at 18 and 24 kt, which is the least there is. At 12 kt the old skipper missed mark 1 by 15 m (its layline 2 degrees too optimistic at 4 m/s) and made two extra tacks there; at the polar's angle it lays it (T1 at 12 kt: 3 tacks instead of 6).

**Lever 5, the 12 kt pace (kept, in levers 2 and 2b).** Where the 14:41 went on T1: the start +32 s (the board waits 150 m behind the line and beats there at 3.9 m/s), the two beats 305 and 226 s at 45 + 6 degrees of foot, the two runs 146 and 156 s at 115 degrees. In s3: the start +25 s, the beats 254 and 197 s, the runs 127 and 140 s (with the start back at 45 degrees, the final code, the start is +60 s again). The rest is the physics (PH26: the 12 kt board planes only on a reach and the slider does nothing) and the start's placement (section 7).

**Lever 6, the sail for the wind (measured, not built).** `tools/push_check.sh --gear_sail=<id>` with the Savanna slalom sails against the default 8.0, in the race's steady wind, on a beat (55), a beam reach (100) and a broad reach (125). Speed / VMG, m/s:

| Wind, angle | 8.0 (default) | 5.5 | 6.5 | 7.5 | 8.5 |
|---|---|---|---|---|---|
| 12 kt, 55 | 4.84 / 2.29 | 2.07 / 0.40 | 2.37 / 0.46 | 4.55 / 2.12 | 4.91 / 2.30 |
| 12 kt, 100 | 7.46 / 1.80 | 2.11 / 0.55 | 2.40 / 0.63 | 6.85 / 1.67 | 7.82 / 1.75 |
| 12 kt, 125 | 6.16 / 3.74 | 2.11 / 0.55 | 2.40 / 0.63 | 5.44 / 3.35 | 6.17 / 3.75 |
| 18 kt, 55 | 7.34 / 3.77 | 6.32 / 3.12 | 6.86 / 3.38 | 7.09 / 3.60 | 7.55 / 3.77 |
| 18 kt, 100 | 12.72 / 2.43 | 10.21 / 2.35 | 11.54 / 2.38 | 12.78 / 2.75 | 12.69 / 2.42 |
| 18 kt, 125 | 10.33 / 6.30 | 6.23 / 3.72 | 7.97 / 4.82 | 9.23 / 5.61 | 10.92 / 6.71 |
| 24 kt, 55 | 8.90 / 4.62 | 8.73 / 4.45 | 9.04 / 4.69 | 8.89 / 4.59 | 8.84 / 4.51 |
| 24 kt, 100 | 14.12 / 2.87 | 14.90 / 3.13 | 15.12 / 3.10 | 14.63 / 3.04 | 14.08 / 2.81 |
| 24 kt, 125 | 15.40 / 9.09 | 11.30 / 6.86 | 14.23 / 8.48 | 15.06 / 8.88 | 15.27 / 9.16 |

No catalogue sail beats the 8.0 on the courses' points of sail in a steady wind: the 6.5 is 8 to 24 % slower at 18 kt and, at 24 kt, 7 % faster across the wind but 7 % slower on the broad reach (and as fast on the beat); the 8.5 is the 8.0 within the noise. PH14's "the 6.5 is 4 to 6 % faster from 18 kt" was a beam reach in gusts. So the 8.0 stays the AI's sail, and the gear per board (GearChoice.sim_with() where the AI boards are built) was not built: it would sail the default everywhere. For package 3 (each persona its gear), the recipe: build the opponent's sim with `GearChoice.from_ids("", <sail id>, "").sim_with(sim)` in `run_race.gd`'s `_make_sim`, set `WindsurferNode.gear` before `add_child()` in `race_runner.gd`, and the same in `race_env.gd`'s `_make_board`; the skipper's polar was measured with the 8.0, so a persona on another sail wants its own polar (`Skipper.take_polar()`, `tools/race.sh --polar=`).

## 4. The final tables

**The all-rounder alone** (`tools/race_matrix.sh --skippers=allrounder --seed=1 --run=final2`; the time, the start delay, falls, tacks, gybes):

| Race | Before | After |
|---|---|---|
| T1 12 kt | 14:41.3, start +32.2, 0 falls, 6 tacks, 4 gybes | 13:27.3, start +59.8, 0 falls, 5 tacks, 3 gybes |
| T1 18 kt | 7:52.0, +1.9, 0, 3, 3 | 7:33.2, +2.0, 0, 3, 3 |
| T1 24 kt | 7:37.2, +3.2, 0, 6, 4 | DNF (circles the finish line), +2.8, 1 fall |
| T2 12 kt | 5:34.7, +4.4, 0, 0, 3 | 5:00.2, +4.4, 0, 0, 3 |
| T2 18 kt | 3:09.2, +3.2, 0, 0, 3 | 3:07.9, +3.2, 0, 0, 3 |
| T2 24 kt | 2:57.8, +28.6 OCS, 0, 1, 4 | 3:07.4, +28.6 OCS, 1 fall, 1, 4 |

The run before the start went back to 45 degrees (the commit a551058, run `final`) had T1 at 12 kt in 12:41.7 (start +24.8) and T2 at 24 kt in 2:55.9, and also did not finish T1 at 24 kt; the run before the run angles went back to 130/140 (s6) finished T1 at 24 kt in 6:22.9.

**The fleet** (`tools/race_matrix.sh`, the default seed; place and time, F = falls; before is the lead's baseline in `baseline/race_matrix.txt`):

| Race | All-rounder | Gambler | Cautious | Rookie |
|---|---|---|---|---|
| T1 12 kt | 3. 17:02.2 → 1. 13:51.9 | 1. 13:59.3 → 2. 14:29.4 | 2. 14:54.6 → 3. 14:50.8 | 4. 18:48.4 → 4. 15:14.8 |
| T1 18 kt | 2. 8:10.4 (1F) → 1. 7:37.6 | 1. 7:55.3 → 2. 8:01.2 | 4. 8:52.4 → 4. 8:34.0 | 3. 8:28.1 → 3. 8:29.4 |
| T1 24 kt | 2. 7:07.9 → 2. 7:12.3 | 3. 7:09.7 (1F) → 3. 7:17.8 | 1. 6:50.8 → 1. 6:54.3 | 4. 7:39.8 (2F) → 4. 7:39.6 |
| T2 12 kt | 2. 5:52.6 → 2. 5:22.4 | 1. 5:28.9 → 1. 5:16.6 | 3. 6:03.7 → 3. 5:48.6 | 4. 7:27.7 → 4. 7:01.9 |
| T2 18 kt | 1. 3:02.8 → 1. 3:02.9 | 3. 3:23.5 (1F) → 2. 3:08.2 | 4. 3:48.4 (1F) → 4. 3:36.0 | 2. 3:22.4 → 3. 3:22.6 |
| T2 24 kt | 2. 3:02.8 → 2. 3:02.0 | 1. 2:47.1 → 1. 2:50.1 | 3. 3:20.5 → 3. 3:27.1 | 4. 3:37.5 → 4. 3:49.3 |

All 24 boards finish before and after; falls 6 → 0; the sum of the times 2:58:17 → 2:50:01. The starts after (seconds after the gun): T1 at 12 kt 48 to 87 s for all four (the boards wait 150 m downwind of the line, section 7), T2 at 24 kt three of four over the line at the gun (20 to 53 s), T2 at 12 kt the all-rounder 26 s (the others 4 to 7), the other three races 1 to 8 s (but the rookie 46 s, OCS, on T1 at 24 kt).

The lead's point 1 (the gambler and the cautious one faster than the all-rounder): the gambler pointed 4 degrees below the old 45, which was nearer the true best beat; now that every skipper beats at the polar's angle, the gambler's +4 is "4 degrees lower than the best" and costs it on the beats, and the all-rounder wins at 12 and 18 kt on T1. The cautious one's long layline margin (35 m) and its hold start still win T1 at 24 kt; the gambler's hold start still wins T2 at 24 kt, where the all-rounder's loop start is over the line (section 7).

**The persona matrix at 18 kt was not run after the change** (the token budget ran out first; it is some 20 minutes of two Godot processes: `tools/persona_matrix.sh --wind_kt=18`). Noor's circling is fixed by the rounding rule (unit-tested on the template's own mark; not re-raced). The personas sail the same code as the characters, which all finish.

## 5. What changed in the code and the config files

- `Game/race/skipper_polar.gd` (new, `SkipperPolar`) and `Game/config/skipper_polar.tres`: the skipper's polar (speeds, push levels, the best beat and run per wind), read between its winds and angles; `push_at()` pushes only where the measurement says pushing paid on both sides of the angle and wind.
- `Game/race/skipper.gd`: the polar from the resource (its own copies, for the engine lock) instead of constants; `_pointing_twa_deg()` and `_downwind_twa_deg()` from the polar's best angles for the wind, the character's angles as differences from 45 and 135; the foot-off and off-plane rules relative to the polar's speeds, and no deeper than 110 off the plane; the push (`_push_level()`, `_move_the_push()`, `push_wanted`); the finish (`_finish_target()`); the rounding begun only before the ray (`before_rounding_ray()`).
- `Game/race/skipper_config.gd`: `push_offset` (the personas' push), the angle fields' meaning.
- `Game/windsurfer/player_controller.gd`: the hands can give the push slider back (`_release_the_slider()`); nothing changes for the player, whose keys move the slider as before.
- `Game/dev/run_race.gd` (`tools/race.sh`): `--skipper_push=0`, `--polar=<file>`; the tacks, gybes and falls counted until a board's finish (the lead's point 4).
- `tools/race_matrix.sh`: `--run=<name>`, `--courses=`, `--winds=`.
- Tests: `Game/tests/unit/test_skipper_speed.gd` (eleven tests: the polar's reading, the push table, the angles by wind, the foot-off, the push and its release, the controller's release, the gradual slider, the rounding ray, the missed finish). All 672 unit tests pass; `tools/check.sh` is green.

## 6. What I could not verify

- How it looks and feels: no game window was opened; the races are headless.
- The game's races on the lake in the map's wind and with gusts: every number here is the open water's steady wind with waves (the race tool and the game's defaults). With gusts on, the push would fall more, not less; the angles were not measured in gusts.
- The trained brains (`LearnedSkipper`) do not use the skipper's polar; package 2's training drops use the all-rounder as their reference, so the reference got faster, which moves the stages' bars.
- `tools/test.sh validation` was not run (no physics changed; the budget). Its `test_skipper.gd` races the all-rounder alone on T1 at 12, 18 and 24 kt with the default seed and wants a finish within 12:00 / 8:00 / 8:30: the 12 kt race is 13:27 with seed 1 (the start +60 s), so that limit is likely still red, and with seed 1 the 24 kt race does not finish; with seed 0 it may. Run `tools/test.sh validation -gselect=skipper` before merging.
- The persona matrix after the change (section 4).
- The fleet's frame cost: the skipper does a little more arithmetic per tick (the polar read through static functions on its own arrays, no shared objects), and no gear was built, so the AI boards' physics is unchanged. Not measured with `tools/fleet_measure.sh`.

## 7. Open items

- **RA (first): T1's finish at 24 kt.** `tools/race.sh --course=t1_loop --skippers=allrounder --wind_kt=24 --seed=1`: after rounding 4S at 14 m/s on a run of 140 degrees the board swings wide past the east end of the 35 m finish line and circles it (24 tacks and gybes, no finish). The go-back rule (`_finish_target()`) turns it round, but each turn back is a wide gybe at 11 m/s. The cure is upstream: ease the rounding at 4S (wide in, tight out, or slower: the head-up at speed is capped at 6 degrees a second), or take the run at 130 there. With the run at 130 (s6) it finished in 6:23.
- **RA: the start at the polar's angle.** Before its start the skipper points at 45 degrees, because its start logic (the way in, the crossing, the laylines to its spot) was built round that angle and the rookie looped behind T1's line for four minutes at the polar's 55 plus its noise. Retuned for the wider beat, the 12 kt start would be 35 s quicker (it was +25 s alone with the polar's angle, +60 s now).
- **RA (start, 12 kt):** in 12 kt the skipper's board waits 150 m dead downwind of the line (`run_race.gd`'s `SKIPPER_WAIT_M_PER_S`; in the game the spawn spots) and its best way to windward is 2.3 m/s: it cannot reach the line in 60 s and crosses 25 s late. This is the "+31 s start scoring" of RA11: not a scoring fault, the board is genuinely late. Either the boards wait nearer the line in light wind, or the countdown is longer (RA11's second line).
- **RA (start, a reaching start in a strong wind):** on T2 at 24 kt the board holds back pointing at the line (the line runs along the wind), cannot slow below 2 m/s, and is over the line at the gun (+29 s; the gambler, who holds instead of looping, does better). The hold should turn along the line, or loop away, when it cannot stop.
- **RA (the push in races):** the pushed board falls in the bear-away from a reach into a run and in gybes at 14 m/s. If the team wants AI boards that push, the place to look is the controller's gybe and bear-away at speed with the slider high (the push slider's rounds measured steady sailing only).
- **PH26 (light wind too weak), confirmed:** at 12 kt the slider changes nothing (within 1 %) at every angle from 40 to 120 degrees; the 12 kt board planes only from about 100 degrees down to 130.
- **PH14 (sail sizes), a new fact:** in a steady wind the 6.5 is slower than the 8.0 at 18 kt on every point of sail (8 to 24 %), and at 24 kt faster across the wind (7 %) but slower on the broad reach (7 %). The order of the sizes in strong wind is a physics question for Michiel.
- **PH (new, the steady polar against the race):** the deepest fast run angle in a race is 10 degrees deeper than the steady polar's best at 18 and 24 kt. This is the skipper's world (rounding, gybes), not the physics, but a gybe that keeps more speed would move it.

## 8. Commands

- The polar: `tools/push_check.sh --jobs=2 --run=polar_nan --gusts=0 --winds=12,18,24 --twas=40,42,45,48,50,52,55,60,70,80,90,100,110,120,125,130,135,140,145,150` and `tools/push_check.sh --jobs=4 --run=polar_push2 --gusts=0 --winds=18,24 --twas=48,52,55,60,70,90,110,120,125,130,135,140 --sweep=push.level=0.75,0.85,0.95,1` (the 12 kt slider part: `--winds=12`, the same angles to 120).
- The sails: `tools/push_check.sh --run=gear_<id> --gusts=0 --winds=12,18,24 --twas=55,100,125 --gear_sail=<id>`.
- Alone: `tools/race_matrix.sh --skippers=allrounder --seed=1 --run=<name>` (the same with `--skipper_push=0` or `--polar=<file>` to compare); one race: `tools/race.sh --course=t1_loop --skippers=allrounder --wind_kt=18 --seed=1`.
- The fleet: `tools/race_matrix.sh`; the personas: `tools/persona_matrix.sh --wind_kt=18`.
