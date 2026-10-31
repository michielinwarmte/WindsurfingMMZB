# The autopilot on the new physics: what the suite found and what changed

For Michiel and Max. Written 31 October 2026 by the lead (Fable 5.1) at the end of the rounds in [PLAN.md](PLAN.md) and [PROGRESS.md](PROGRESS.md). The physics is `ph28/sail-and-hull` after Session 61's merge; nothing in `Game/sim/`'s physics changed in this work. What changed is the sailor's technique settings (the rail, the couple), the pilot's course hold and luff band, and a dial helper. Every number is from the suite's runs (`.sim_output/autopilot/r0` to `r5`, `.sim_output/push/r4_*`), each labelled with its source or called an estimate.

## 1. In short

The merged physics already rides the beam reaches the way the goal asks (0.9 m wet at 1.3 to 1.5 degrees, steady), and the rake is off its stop on every planing reach. What the rounds found and fixed:

1. **The rail's shape was the big lever, and it is the hull's, not the rider's.** Max's rail as built (10 degrees upwind, flat by the broad reach) bounced the close reaches and made the 24 kt broad reach bounce and fall, because this hull does not reward a railed board at short wet parts (PH27, PH31). The rail is now the most of Max's that the hull carries: 5 degrees upwind, 2 crosswind, 2 kept to a run. With it all nine flat-water reaches are steady and upright and the 24 kt broad reach does 19.4 m/s on 0.9 m at 1.2 degrees.
2. **The front foot's couple at the low end of Max's range (150 N)** takes away the one fall the 24 kt broad reach still had in gusts and waves at both dial settings, and makes the beam reaches steadier, at the cost of the push's centre sitting 5 to 8 cm further forward than wanted.
3. **The push dial works on this physics, without GP0's "late ease".** Pushed pays +4 % at 18 kt and +7 % at 24 kt across the wind and +5 % upwind at 24 kt with no falls at 18 kt; the 24 kt broad reach falls when pushed: the physics' own failure, as the design wants. The rig's lean to windward belongs to the pushed setting (35 degrees; +2 to 3 % across the wind). GP0's weakened safety nets add nothing here and catapult the 24 kt close reach, so they are not part of the dial. `PushDial` maps eased / neutral / pushed onto these numbers for GP1 to use; `tools/push_check.sh --dial=` runs them.
4. **Steering with the rail instead of the rake does not do what the plan hoped.** The weight on the inside rail as the steady helm shortens the close reaches but cancels the leeward rail Max asks for there, and off the wind it broke the broad reaches; limited to upwind and across it still costs the 18 kt beam reach its steadiness. It is built (by point of sail) and off. The feet's steering lever is the back foot's push against the fin (PH35), not the rail.
5. **At 12 kt the dial changes nothing:** the 85 kg rider is never overpowered by the 8.0, pushed or eased (PH26, the physics).

What is not reached: the broad reaches at 18 kt (1.05 m wet, just outside 1.0) and the push's centre (0.8 m against 0.45 to 0.75); the 12 kt close reach is slow (6.4 m/s); the skipper's 12 kt race takes 14:39 against the test's 12:00 (the light-wind pace and the start's scoring, section 6).

## 2. The goal's table, before and after

The reach check (flat water, steady wind, 90 s, the means from 60 s); "before" is round 0, the merged physics as it came; "after" is the final defaults (round 5, `couple150`). Speed m/s, the wet front and the push's centre m from the tail, the trim and the pitch SD in degrees.

| Case | Before: speed, front, push, trim, SD | After: speed, front, push, trim, SD | The goal (front 0.6 to 1.0, trim 1 to 2.5, SD < 0.3, push 0.45 to 0.75) |
|---|---|---|---|
| 18 kt 60° | 9.65, 1.49, 1.23, 2.31, **1.55** | 10.59, 1.25, 1.07, 2.25, 0.00 | steady now; not a goal case |
| 18 kt 100° | 15.44, 0.95, 0.77, 1.46, 0.24 | 15.44, 0.96, 0.82, 1.44, **0.10** | front, trim, SD met; the push 7 cm forward |
| 18 kt 135° | 11.76, 1.18, 0.84, 2.39, 0.33 | 12.58, 1.05, 0.85, 2.09, 0.17 | the front 5 cm long; trim and SD met |
| 24 kt 60° | 10.50, 1.45, 1.21, 2.32, **0.93** | 11.29, 1.23, 1.02, 2.21, 0.03 | steady now |
| 24 kt 100° | 17.25, 0.89, 0.71, 1.34, 0.22 | 17.13, 0.95, 0.82, 1.31, **0.06** | front, trim, SD met; the push 7 cm forward |
| 24 kt 135° | 13.99, 1.32, 0.92, 1.90, **1.07, fell** | **19.43, 0.96, 0.82, 1.05, 0.10** | front, trim, SD met; the push 7 cm forward |
| 12 kt 60 / 100 / 135° | 6.37, 11.73, 5.73 | 6.5, 11.7, 5.7 | not goal cases; the 12 kt close reach slow (PH26) |

The other rows of the goal: the rake on the planing reaches 0.62 to 0.85 of its stop (the photos' 15 to 25 degrees at the 25 degree stop; the merged physics gave this, not the rounds); the rig's lean 22 to 25 degrees at neutral (the photos' 15 to 35), 32 to 35 pushed; the sheet 0.81 to 0.91 on the planing reaches (closed, the top spilling); the harness 740 to 810 N on the planing reaches (Walls & Gale's 300 to 500 N for 85 kg is not reached: the hooked-in posture's open item, review_sim 3.5 and 4.5).

## 3. Gusts and waves: the push check and the dial

`tools/push_check.sh`, 120 s per case, the open sea's gusts (0.2, 8 s) and waves; the speed made good in m/s and the falls. "Before" is round 0, "after" the final defaults.

| Dial | 18 kt 48° / 100° / 135° | 24 kt 48° / 100° / 135° | Falls (18 and 24 kt, six cases) |
|---|---|---|---|
| Neutral, before | 5.96 / 12.45 / 8.23 | 6.58 / 13.94 / 12.36 | 2 (24 kt 48° and 135°) |
| **Neutral, after** | 6.07 / 12.50 / 8.13 | 7.43 / 14.04 / 13.08 | **0** |
| Pushed (1.6), before | 5.97 / 12.75 / 8.23 | 6.79 / 14.68 / 12.85 | 1 (24 kt 48°) |
| **Pushed (1.6), after** | 6.11 / 12.71 / 8.13 | 7.69 / 14.69 / 13.28 | **0** |
| Eased (0.8), round 4 (the rail fixed, the couple 200) | 5.42 / 9.78 / 8.16 | 5.72 / 11.73 / 12.72 | 0 |

The dial's effect at the rig's lean 25 (round 4, the couple 200): neutral to pushed +4 % at 18 kt 100°, +7 % at 24 kt 100°, +5 % at 24 kt 48°, nothing on the broad reaches at 18 kt (the sail is at its stall there) and a fall on the 24 kt broad reach when pushed. The rig's lean 20 / 25 / 35: 12.08 / 12.25 / 12.59 at 18 kt 100° neutral and 13.60 / 13.71 / 14.10 at 24 kt: more lean pays across the wind, so the pushed setting leans 35. GP0's late ease (the depower and catch nets weakened) with the pushed dial: no gain at 18 kt or on the 24 kt beam reach, and 2 to 3 catapults on the 24 kt close reach: left out of the dial. The 12 kt dial: 3.97 / 7.69 / 4.79 at every setting, no falls.

## 4. The levers, one by one (round 1, single changes against round 0)

| Lever | What it did | Kept? |
|---|---|---|
| The rail: no upwind extra (`fin_load_bank_upwind_deg` 0) | the close reaches steady (SD 0.00) and 12 % faster; nothing else | at 5°: Max's direction at the amount the hull carries (5 costs 2 % against 0) |
| The rail kept to 160° (`fin_load_twa_max_deg` 160, fade 20) | the 24 kt broad reach from 13.99 bouncing to 19.38 steady on 0.91 m; the 18 kt broad reach steadier | yes (U2's numbers) |
| `lean_share` 0.3 (the rail as the steady helm) | the close reaches to 0.94 to 0.99 m, steady, but the 12 kt broad reach collapses (2.35 m/s) and the 24 kt one bounces | no; built by point of sail (full to 110°, gone by 135°), off: even then it cancels Max's rail and costs the 18 kt beam reach its steadiness |
| `max_rake_deg` 18 | the 24 kt broad reach falls hard; pushed 4 falls | no |
| `running_trim_deg` 3 | the 24 kt broad reach falls; mixed elsewhere | no |
| The couple 250 N | slightly less steady; the 24 kt broad reach bounces harder | no; 150 kept (round 5) |
| `max_rig_lean_deg` 35 | 18 kt 100° fully met (0.90 m, push 0.71) but the 24 kt broad reach falls and the pushed dial falls twice (with the old rail) | as the pushed setting's lean (with the rail fixed the broad reaches do not mind it at neutral: round 3) |
| `alpha_luff_deg` 2 (the pilot's luff band from the sail) | no change on the reaches, the tacks and the irons complete | yes: a consistency fix |

## 5. What changed in the code and the configs

- `Game/config/sailor_default.tres`: `fin_load_bank_upwind_deg` 10 → 5, `fin_load_twa_max_deg` 135 → 160, `fin_load_twa_fade_deg` 35 → 20, `front_foot_pull_held_n` 200 → 150 (the tuning log has the rows; the tests `test_sailor_body.gd` and `test_front_foot.gd` pin them with the reasons).
- `Game/sim/autopilot.gd`: the luff band read from the sail (`luff_from_sail`); the rail steering applied by point of sail (`lean_share_twa_max_deg` 110, `lean_share_fade_deg` 25, `_rail_share_by_point_of_sail`; `lean_share` stays 0). `test_helm.gd` pins the share by angle.
- `Game/sim/push_dial.gd` (`PushDial`): the dial's three settings onto `hike_share` and the sailor's `max_rig_lean_deg`, straight between; `test_push_dial.gd`. `Game/dev/run_push.gd`: `--dial=eased|neutral|pushed`.
- From Session 61's merge, before the rounds: the rest stance 4 cm forward (PH32, a labelled stand-in).
- The suite itself: `tools/autopilot_suite.sh`, `tools/autopilot_summary.py`, the rounds in `rounds/`.

## 6. Regression on the final defaults

- The manoeuvre matrix: 24 cases, no fall, every manoeuvre completed. The lake matrix: no fall; the 12:00 run turn is the one manoeuvre not completed, as on the merged branch before the rounds.
- The skipper's races (`tools/race.sh --course=t1_loop --skippers=allrounder`, on the rail defaults, the couple 200): the all-rounder finishes T1 without a fall at 24 kt in 6:27, at 18 kt in 7:58 (the test's limit 8:00) and at 12 kt in 14:39 (the limit 12:00). At 12 kt the race scores the start at +31 s where the board's track shows the line crossed within a second of the gun at 7 m/s, and the first beat takes five minutes at 7 m/s: the light-wind pace of this gear (PH26) and the start's scoring (RA).
- Validation on the final defaults: **35 pass, 9 fail, 2 pending** (the merged branch before the rounds: 33 / 11 / 2; its base: 37 / 7 / 2). The steadiness target (target 2) is green again. The nine reds by cause: the polar's speed band and the top speed (the band was drawn for the old gear: faster across, 7.65 m/s at 135° against 10.8); the planing onset 14.4 kn against 8 to 10 (12.1 before the rail and the couple changed: the 5° upwind rail and the lighter couple slow the start from rest, an onset item of PH16); the fin's side force 743 N against a 100 to 650 N band with no source (PH36); the push warning (the pushed board no longer catapults on the 24 kt beam reach, where it wants two: round 4 found the pushed falls on the broad reach, so the test's case has moved; GP3); the skipper's 12 kt race 14:11 against 12:00 (14:39 with the couple at 200; PH26 and RA11); the waves at 120° (−18 % against flat water, PH11); the fleet's start (one board late, a different one each run, RA11); and one new small red, the polar's shape: the 45° point is slower than the 40° one (5.46 against 5.80 m/s) with the 5° upwind rail, which the hull does not reward (PH27). The two pending targets are the 18 kt broad reach's wet front (1.05 m) and the push's centre (0.8 m).
- Unit tests: 586 of 586; `tools/check.sh` green.

## 7. For Michiel's play-test

- `tools/play.sh res://main.tscn --autopilot=1 --camera=2`: the autopilot on open water at the game's wind; watch the beam reach ride on its tail with the nose up and the rig leaned, and the broad reach at 24 kt not bounce.
- `tools/play_push.sh`: the dial's playtest: 24 kt from the West with gusts and waves, beginner mode with the auto-sheet, the dial pushed (`--dial=neutral` or `--dial=eased` to compare; the F1 panel's second line says which, and its bottom freezes what came before each fall). Pushed should pay across the wind (heading 150 to 180 on starboard) and catapult on the broad reach (heading 210 to 225, or `--heading=220`).
- `tools/play.sh lake`: Silvaplana in the map's wind.
- What to judge by feel, which no run can: whether 5 degrees of rail upwind looks like your sailing, whether the pushed board's falls come where you would expect them, and whether the 12 kt sailing is too tame (PH26).

## 8. Open, in order

1. PH35, the back foot's push against the fin: the feet's real steering lever, so the rake can leave its course hold to the feet (the rail cannot do it: section 4).
2. PH27 and PH31, the hull's heeled lift at short wet parts: until the hull rewards a railed board, Max's full rail (10 upwind, flat downwind) costs steadiness and the rail steering fights it.
3. PH26, light wind too weak: the 12 kt dial does nothing and the 12 kt close reach does 6.4 m/s.
4. PH32, the weight forward until the board has way on: the tack's exit technique behind the rest stance's stand-in.
5. The harness tension (740 to 810 N against 300 to 500 wanted) and the push's centre (0.8 m against 0.45 to 0.75): the hooked-in posture and the hull's clip (PH30).
6. RA: the race's start scoring at 12 kt (+31 s for a board over the line within a second), and the fleet's flaky start test.
7. GP1: the dial's key on the keyboard and the gamepad, using `PushDial`.

## Sources

[PLAN.md](PLAN.md) section 1's table (Gourlay & Martellotta 2011, Savitsky 1964, Sutherland 1993, the shapers, Walls & Gale 2001, the photos, Max's answers); the suite's runs under `.sim_output/autopilot/` and `.sim_output/push/r4_*`; [rider_feet_body.md](../ph28/rider_feet_body.md) (the rail and the couple as built); [gp0_measure.md](../gameplay/gp0_measure.md) (the dial's settings and the late ease).
