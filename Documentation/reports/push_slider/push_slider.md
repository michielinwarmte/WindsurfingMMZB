# The push slider: what the rounds found and what was built

For Michiel and Max. Written 31 October 2026 by the lead (Fable 5.1) at the end of the rounds in [PLAN.md](PLAN.md) and [PROGRESS.md](PROGRESS.md), on the branch `gp1/push-slider` (from `ph28/sail-and-hull`). Every number is from the runs under `.sim_output/push/r0_*`, `r1_*`, `r2_*` and `.sim_output/push_reach/`, each named where it is used; a number without a run behind it is called an estimate. The steering is in [steering.md](steering.md).

## 1. In short

1. **The slider is built and works as a ladder.** Up and Down move it (a full range in 2.5 s), the strip shows "push 75 %", the F1 panel shows what the level asks of the sailor. 0 % lets the sail fly and the board drifts at 0.3 to 2.4 m/s (the boom can be eased only to 85°), 25 % moves slowly at every wind (1.7, 6.1 and 8.1 m/s at 12, 18 and 24 kt on a beam reach), 50 % cruises, 75 % planes, and above 75 % the pull held rises to the measured "pushed" dial with the rig leaned to 35°. The AI boards are untouched until the fleet adopts it: with no level set, the controller sails the pilot's own numbers as before.
2. **The pull held is the lever that pays, and the risk rises with it as the design asks.** Against 75 %, 85 % gives +3 to 4 % and 100 % +4 to 5 % on the flat-water beam reaches, +7 to 9 % on the sea at 24 kt and +7 % upwind. The falls in six hours of sailing per rung (300 s cases at 18 and 24 kt on six courses, three seas, two gust strengths): 75 % 5, 85 % 13, 95 % 21, 100 % 34, none on flat water but one, all in waves. At 75 % nothing falls at 18 kt or on flat water; what remains is the 24 kt broad reach in waves, the sim's known catapult case. The sailor's reflex that made 75 % that safe is the rail for the sea (section 5).
3. **"Pushing on the back foot" splits in two in this physics.** The rail (the leeward rail down, the heeled fin) is what loads the fin: at 5° its lift rises 12 % and its upward part 44 %, the 24 kt broad reach gains 18 % and twice-height waves stop causing falls. But this hull rides longer railed, not shorter, so the beam reach loses 5 % (the hull's heeled lift, PH27 and PH31). The sideways couple between the feet (built, `SimControls.back_foot_push`) does not load the fin: held, it makes the fin carry less and costs speed. It is a steering lever (section 6), not a push lever.
4. **The sail closes as far as the drive asks, not further.** At 100 % the sheet sits at 83 % on the beam reaches (the boom 13° off its stop) because the sail's best drive at the sim's speeds is at an angle of attack of about 15°; sheeted fully in it would stall. When the pull passes what is held the pilot eases it further (78 % at 75 % on the sea). So "closed when fully powered, open only when overpowered" holds in the sense the sim's sail allows (section 5).
5. **The steering when planing**: see [steering.md](steering.md) (the agent's measurement and change).

## 2. What was built

- **Four controls in `Game/sim/`** (PH35, PH3; every one 0 by default and bit for bit as before: the reach check's nine CSVs and the manoeuvre matrix were identical before and after): `SimControls.back_foot_push` (the two feet pushing against each other sideways in their straps, a yaw couple of `SailorConfig.back_foot_push_n` 150 N times the straps' spread, 88.5 N m), `rail_bank_extra_deg`, `trim_aim_extra_deg` and `rig_lean_extra_deg` (degrees on top of the technique's own targets). PHYSICS_SPEC.md section 7.5 has the two paragraphs and section 16 the row.
- **The ladder** `Game/config/push_curve_default.tres` (`PushCurveConfig`), read by `PushDial`, which sets the pilot's `drive_share`, `hike_share` and `back_foot_bias` and the controls' three extras every update from `PlayerController.push_level`.
- **The game**: Up/Down (`push_more` / `push_less`, moved from the sheet), the strip and the F1 panel, `main.gd --push=<level>` (a share, a percentage, or eased / neutral / pushed), the player's start at 75 %, `tools/play_push.sh --push=<percent>`; with `--autopilot=1` the board's own autopilot sails at the level.
- **The harness**: `tools/push_check.sh --push=` and `--sweep=push.level=...`, `--wave_scale=<f>` (the sea at another height), the fin's columns (its slip, lift and upward part, the back foot, the trim's aim); `tools/push_slider_summary.py`; `tools/reach_check.sh --push=`; `tools/steer_check.sh` (the steering check).
- **Tests**: `test_push_controls.gd` (the couple's size and sense on both tacks, its bound, the stance's share; the extras), `test_push_dial.gd` (the ladder), `test_player_controller.gd` (the keys, the hands, the level through a waterstart, the legs in the helm), `test_helm.gd` (the legs' sense on both tacks).

## 3. The ladder, in numbers

The speed made good (m/s) by level, `tools/push_check.sh`, 150 s per case, gusts 0.2 (round 0's sweep, `r0_*`, with the ladder as first guessed; the top rungs were then changed by round 1, so the 85 to 100 % columns here are the first guess's: the pull 1.2 / 1.45 / 1.6 with the lean +5 / +9 / +10 and +1 to +3° of rail and +0.3 to +1° of trim). The final ladder's numbers are in section 4 (round 2, 300 s).

Flat water:

| kt / TWA | 0 % | 25 % | 50 % | 75 % | 85 % | 95 % | 100 % |
|---|---|---|---|---|---|---|---|
| 12 / 100 | 1.25 | 2.11 | 7.96 | 7.96 | 7.90 | 8.04 | 8.18 |
| 18 / 48 | 0.52 | 5.22 | 5.70 | 6.28 | 6.39 | 6.42 | 6.42 |
| 18 / 100 | 1.82 | 8.46 | 10.16 | 13.47 | 13.65 | 13.50 | 13.29 |
| 18 / 135 | 1.59 | 6.13 | 8.33 | 8.33 | 8.40 | 8.39 | 8.50 |
| 24 / 48 | 0.47 | 6.09 | 6.33 | 7.99 | 8.27 | 8.35 | 8.40 |
| 24 / 100 | 2.43 | 11.98 | 12.28 | 15.43 | 15.52 | 15.35 | 15.02 |
| 24 / 135 | 2.12 | 8.67 | 13.90 | 13.45 | 13.98 | 15.08 | 13.33 F1 |

The default sea: 24 / 100: 2.22, 10.79, 11.71, 13.88, 14.31, 14.58, 14.58; 24 / 135: 1.92, 8.66, 12.90, 13.26, 13.04, 11.01 F2, 9.91 F3. Twice the wave height: 75 % falls twice at 24 / 120 and the 95 and 100 % rungs fall 11 and 18 times in 126 cases.

What round 0 said: the lower half is a ladder at every wind; the 25 % rung still planed at 24 kt with half the drive, so the drive share went to 0.3 there (round 1: 1.7 / 6.1 / 8.1 m/s at 12 / 18 / 24 kt on the beam reach) and to 0.85 at 50 % (6.8 / 9.7 / 11.7); above 75 % the first guess gave nothing across the wind on flat water, so round 1 separated the levers.

**The final ladder on flat water with the autopilot's own course hold** (`tools/reach_check.sh --push=`, 90 s, the means from 60 s, on the merged code, `.sim_output/push_reach/`): the speed (m/s), the wet front (m), the trim (degrees) and the pitch SD:

| kt / TWA | 50 % | 75 % | 85 % | 95 % | 100 % |
|---|---|---|---|---|---|
| 18 / 100 | 11.72, 1.03, 2.33, 0.01 | 15.20, 0.93, 1.46, 0.01 | 15.74, 0.97, 1.34, 0.01 | 15.98, 1.03, 1.37, 0.16 | 16.17, 1.01, 1.33, 0.11 |
| 18 / 135 | 9.72, 1.45, 3.14, 0.01 | 12.58, 1.05, 2.09, 0.17 | 12.60, 1.04, 2.07, 0.18 | 13.56, 1.01, 1.80, 0.44 | 14.45, 0.96, 1.63, 0.43 |
| 24 / 100 | 13.34, 1.00, 1.86, 0.01 | 16.82, 0.94, 1.29, 0.08 | 17.51, 0.97, 1.13, 0.15 | 17.79, 0.99, 1.27, 0.10 | 17.99, 0.98, 1.23, 0.06 |
| 24 / 135 | 16.19, 0.87, 1.58, 0.03 | 19.12, 0.93, 1.12, 0.04 | 19.76, 0.96, 0.95, 0.08 | 19.44, 1.00, 1.21, 0.09 | 19.40, 1.01, 1.20, 0.10 |

The ladder rises rung by rung on the beam reaches (+6 to 7 % from 75 to 100 %) and on the 18 kt broad reach (+15 %, the trim at the top); the 24 kt broad reach is fastest at 85 %. The wet front stays at 0.93 to 1.01 m (the goal's 0.6 to 1.0), the trim at 0.95 to 1.63°, the pitch steady except the 18 kt broad reach at the top (SD 0.43: the extra trim makes it bounce a little). The rig leans 25° at 75 % and 35° at 100 %; the fin carries 600 N at 75 % and 720 N at the top, its upward part 110 to 165 N (the heel, 1.5 to 2.7° to leeward). The push's centre stays at 0.75 to 0.86 m (the goal's 0.45 to 0.75: the hull's clip, PH30).

## 4. The levers one by one (round 1, `r1_*`)

Each lever alone on top of 75 %, 150 s per case, at 18 and 24 kt. The speed made good on the beam and broad reaches, the falls in the 12 cases of each sea, and the fin's lift and upward part (the means over the six planing courses):

| Lever | Flat: 18/100, 24/100, 24/120, 24/135 | The default sea: 18/100, 24/100, 24/135 | Twice the height: falls / 12 | Fin lift, up (N, flat) |
|---|---|---|---|---|
| 75 % as it is | 13.47, 15.43, 16.05, 13.45 | 12.37, 13.88, 13.26 | 2 | 471, 79 |
| the pull 1.3 | 13.82, 15.83, 16.81, 14.40 | 12.72, 14.38, 13.32 | 2 | 510, 92 |
| the pull 1.6 | 13.91, 16.03, 17.07, 14.40 | 12.70, 14.71, 13.32 | 3 | 526, 96 |
| the pull 1.6 and the lean 35 (the old pushed dial) | 14.08, 16.28, 17.26, 13.49 | 12.90, 14.99, 13.37 | 5 | 520, 97 |
| the lean 35 alone | 13.67, 15.40, 16.25, 13.28 F1 | 12.59, 14.15, 13.48 | 6 | 475, 81 |
| the rail +1° (3°) | 13.25, 15.03, 16.16, 14.38 | 12.43, 13.87, 11.92 F1 | 2 | 489, 90 |
| the rail +3° (5°) | 12.75, 14.67, 15.93, 15.82 | 12.15, 13.85, 13.23 | **0** | 530, 114 |
| the trim +0.5° | 13.53, 15.38, 16.08, 14.52 | 12.46, 14.06, 11.88 F1 | 2 | 476, 80 |
| the trim +1° | 13.53, 15.38, 16.08, 14.86 | 12.47, 14.00, 10.58 F2 | 2 | 480, 80 |
| the back foot held at 0.5 | 13.43, 15.37, 16.01, 12.43 F1 | 12.26, 13.68, 12.07 F1 | 3 | 457, 75 |
| the back foot held at 1 | 13.38, 15.01, 15.82, 11.10 F2 | 12.19, 13.61, 13.41 | 6 | 438, 72 |
| the back foot held at 1, 300 N | 13.30, 14.85, 15.09, 9.39 F3 | 12.13, 13.50, 12.59 | 10 | 387, 57 |
| the first ladder's 100 % | 13.20, 14.81, 15.64, 12.53 F1 | 12.64, 14.71, 9.24 F3 | 18 | 501, 109 |

So the ladder above 75 % is the pull with the lean, a little rail and trim at the top for the broad reaches, and no held fin push. The 24 kt broad reach is the one course the rail and the trim help and the pull does not (the sail is eased there, its pull mostly forward; the autopilot suite found the same).

## 5. The rungs' safety, the rail for the sea, and the sheet

`tools/push_check.sh`, 300 s per case, 18 and 24 kt on 48 to 150°, flat water, the default sea and the sea at twice its height, at gusts 0.2 and 0.3: 72 cases a rung, six hours of sailing each. The falls, flat / the default sea / twice the height:

| Rung | Round 2: the ladder alone (`r2_*`) | Round 3: with the rail for the sea (`r3_*`, the merged code) | Final (`r4_*`, the sea rail 1° at 95 %, none at 100 %) |
|---|---|---|---|
| 75 % | 0 / 3 / 8 = 11 | **0 / 2 / 3 = 5** | as round 3 |
| 85 % | 1 / 2 / 17 = 20 | **0 / 1 / 12 = 13** | as round 3 |
| 95 % | 0 / 3 / 19 = 22 | 1 / 10 / 37 = 48 | **0 / 5 / 16 = 21** |
| 100 % | 0 / 7 / 37 = 44 | 0 / 7 / 48 = 55 | **1 / 3 / 30 = 34** |
| 75 % with the rail at 5° held always | 0 / 2 / 3 = 5, and -5 % on flat water | | |

**The rail for the sea.** A rail held always makes 75 % safe in waves but costs 5 % on flat water (round 2's last row), so the sailor rails only when it gets wild: the bounce felt is the pitch rate's RMS over 3 s (measured at 75 %: 1 to 3°/s on flat water, 6 to 8 on the default sea, 12 to 14 at twice its height), no extra rail below 4°/s, 3° from 12°/s (`Autopilot.wave_rail_deg`, the ladder's `wave_rail_deg`). It halves the falls at 75 and 85 % and costs nothing on flat water (the 75 % flat-water speeds the same to 0.1 m/s). What remains at 75 %: the 24 kt broad reach on the default sea, one fall in 300 s at each gust strength, and three falls at twice the height (the 24 kt beam reach and broad reach in gusts of 0.3); nothing at 18 kt, nothing on flat water. The goal's "at most one fall in 600 s per case" is met everywhere but that 24 kt broad reach in waves, the sim's known catapult case (PH17).

**Stacked on the top rungs it did the opposite.** At 95 % the sea's 3° on top of the ladder's degree, with the pull at 1.5 and the rig leaned 32°, tipped the 24 kt upwind board over in waves: five falls in 300 s on the default sea and eight at twice the height, none with the sea rail off, and 20 % faster without it (`.sim_output/push/p95_*`). So the sea rail is 3° up to 85 %, 1° at 95 % and none at 100 %: fully pushing, the sailor does not ease for the sea, which is Michiel's ladder ("a crash likely"; "pushing hard in higher waves is riskier").

**The sheet.** On the planing courses the sheet's mean is 0.81 at 75 % and 0.85 at 100 % on flat water (the boom 13 to 11° off its stop), 0.78 to 0.81 on the default sea, 0.72 to 0.75 at twice the height. The sail is trimmed to its best drive (an angle of attack of about 15° at the sim's 14 to 16 m/s, where the apparent wind is 40 to 45° off the bow); sheeted fully in it would meet the wind at 28°, past its stall, and the pull cap of the pulled rungs lets it come further in, not less. When the pull passes what the sailor holds (the sea, the gusts) the pilot eases it: the sheet falls with the waves at every rung. So "closed when fully powered, opened only when overpowered" holds as far as the sim's sail allows; a sail that is fastest fully sheeted at these speeds would be a faster board (PH8) with a smaller apparent wind angle.

## 6. The steering when planing

Measured and changed by the steering agent on `gp1/steering`, merged here; the whole story is [steering.md](steering.md). `tools/steer_check.sh`: the beginner's controller holds a 100° reach until it planes, then the stick goes hard over; the time to turn 30° and the speed at 30°:

| | 18 kt, head up | 24 kt, head up | 18 kt, bear away | 24 kt, bear away |
|---|---|---|---|---|
| Before, flat water | 4.35 s, 7.1 m/s left of 13.8 | 5.38 s, 7.5 of 15.7 | 1.17 s | 0.98 s |
| After, flat water | 2.53 s, 11.3 m/s | 2.28 s, 12.1 m/s | 1.15 s | 1.00 s |
| After, waves and gusts | 2.77 s, 10.8 m/s | 2.53 s, 10.9 m/s | 1.28 s | 1.30 s |

At 12 kt nothing changed (2.92 s). What was wrong, lever by lever: not the physics (the same board bears away in a second), not the loop's gains, not the head-up rate cap (`head_up_rate_min_dps` 12: lifted to what a 30° bank would carry, the sailor was catapulted at 18 and 24 kt, because a powered, hiked board in this sim banks to windward only 0 to 2° where 20 to 30 are asked), but **the auto-sheet**: a head-up at speed pushes the sailor to leeward (the speed times the turn rate, 2.9 m/s² at 12°/s), the felt heel reached 10 to 16°, and the pilot's urgent easing read that as being pulled over and dumped the sail within a second (the angle of attack from 15° to 3°, the drive from 261 to 50 N), so the board fell to 7 m/s and the rig, which steers through the sail, lost its grip. Two changes:

- **The pilot expects the push of a head-up it was asked for** (`Autopilot._expected_turn_heel_deg`): the urgent easing counts only the felt heel beyond the push of the turn the board really makes (atan(v w / g)), no more than the windward bank still to come, faded out over the last 10° before the catapult heel. No new numbers; nothing changes without a windward bank asked for (straight sailing, bearing away, the course hold).
- **The planing technique, the legs first** (`PlayerController.legs_rate_gain` 1/12 per degree per second of rate error, between `planing_steer_from_ms` 9.7 and `planing_steer_full_ms` 11.1 m/s, Max's 35 to 40 km/h, times the stance): in the straps the back foot pushes at once to head up and the front foot to bear away, as the quick part of the helm; the rig's trim follows only as the error lasts. The rig moves less (0.15 and 0.30 of its range on average, from 0.33 and 0.44). Below 9.7 m/s the steering is as before.

The manoeuvre matrix with it: 24 of 24 without a fall; the 18 and 24 kt tacks reach the new course 0.4 to 0.5 s sooner and leave 0.2 to 0.9 m/s faster, the 24 kt gybes come out 1.5 to 2.4 m/s faster. Two things the agent found for Michiel: the powered board does not bank to windward because the feet hold the body first (`_apply_leg_forces`), which is what limits the head-up rate; and a 30 Hz yaw flutter on the steady 18 kt reach (±0.4°/s every tick, the fin's yaw moment alternating 602 / 716 N m), there before this work.

## 7. Regression (the merged code, with the steering)

- Unit tests 602 of 602; `tools/check.sh` 298 files green.
- The manoeuvre matrix: 24 of 24, no fall, every manoeuvre completed (the 18 and 24 kt tacks a little quicker and faster out, the 24 kt gybes 1.5 to 2.4 m/s faster out: the steering's legs).
- The lake matrix: no fall; the 12:00 run turn not completed, as before this work.
- Validation: **35 pass, 9 fail, 2 pending**, the same count and the same nine reds as the autopilot suite left them ([autopilot_rework.md](../autopilot/autopilot_rework.md) section 6): the polar's band and the top speed (the band is the old gear's), the planing onset (14.4 kn), the fin's side force (743 N against a band without a source, PH36), the push-warning test (its catapult case moved to the broad reach, GP3), the skipper's 12 kt race (14:11 against 12:00; PH26, RA11), the waves at 135° (PH11), the fleet's start (one board late, RA11), the polar's 45° point (PH27). One line inside the already-red skipper test moved: the 18 kt T1 race takes 8:01 against its 8:00 limit (7:58 before; the agent read it as race-to-race noise: on other seeds the new steering won by up to 26 s, and the 24 kt race here is 7:37 against 6:27 with three tacks stalled head to wind on one seed). The AI boards sail without the slider, so their change is the steering's legs in the heading hold alone.
- Bit for bit: with the four new controls at 0 and no slider, the reach check's nine CSVs and the matrix were identical before and after the physics step; the steering's change to the auto-sheet acts only when a windward bank is asked for.

## 8. For Michiel's play-test

- `tools/play.sh res://main.tscn`: Up and Down move the slider (the strip shows it); it starts at 75 %. Try 25 % (slowly moving), 50 % (cruising), 75 % (planing, little risk), then 85, 95 and 100 % on a beam reach and a broad reach in 18 and 24 kt, with the waves on.
- `tools/play_push.sh` (24 kt, gusts, waves, the slider at 100 %) and `tools/play_push.sh --push=75` to compare; `--wind=18`.
- What to judge by feel: whether the rungs feel like your ladder; whether 0 % drifting at 1 to 2 m/s is "standing still" enough (the boom's 85° stop); whether the rail at the top (2° more) looks like your sailing or should be more, knowing the hull's cost (PH27); the steering in the straps (section 6).

## 9. Open

1. PH27 and PH31: the hull does not reward the rail (the wet front longer, the beam reach slower); until it does, the slider's "back foot" is a modest rail and the fin's push is only a steering lever.
2. PH37 (new, the steering agent): the powered board does not bank to windward because the feet hold the body first, which is what caps the head-up rate at 12°/s; PH38: a 30 Hz yaw flutter on the steady 18 kt reach.
3. PH6, the sudden spin-out: the fin's slip stays at 1.5 to 2.3° on every course; nothing pushed it near its stall.
4. RA12: the AI fleet on the slider (`AiHands.push`); GP11: the beginner's broad reach at 12 and 18 kt never planes (the controller's start, not the physics).
5. GP3: the ladder tuned by play (Max and Tarpie); the gamepad and the spring-back (GD1, GD2).
6. PH26: at 12 kt the slider above 75 % changes nothing; PH17: the 24 kt broad reach in waves, the one case 75 % still falls on.
