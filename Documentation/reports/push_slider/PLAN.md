# The push slider: one dial from standing still to the catapult, and the back foot that flies the board

For Michiel and Max. Written 31 October 2026 by the lead (Fable 5.1) at Michiel's request, after his play-test of the three-setting dial: "I want the amount of push to be changeable in game, maybe with the up and down arrows, ideally a dynamic slider: at 0 % the rider is standing still, fully sheeted out; 25 % slowly moving; 50 % cruising; 75 % planing with little risk; 85 % getting speed, taking a bit more risk; 95 % very fast with a bit of control in mind; 100 % going for maximum speed, a crash or catapult likely. In real windsurfing, pushing while planing comes mostly from pushing on the back foot in the footstrap to rail the board and put more pressure on the fin, so the board flies more. Test and optimise in many conditions: pushing hard in higher waves is riskier. The autopilot must crash very little in all conditions at 75 %; from there on improve the speed with the right technique. Fully powered and fully pushing, the sail is closed; only when overpowered you open it: see whether that works in the simulation. And the steering: fine at moderate speed, sluggish when planing; in the straps the steering comes more from pushing and pulling with the two legs and less from moving the sail. Keep testing until the autopilot is really good at railing and flying the board, in chop too." The branch is `gp1/push-slider`, from `ph28/sail-and-hull` after the autopilot rounds ([autopilot_rework.md](../autopilot/autopilot_rework.md)). The progress and the token ledger are in [PROGRESS.md](PROGRESS.md).

## 1. What is built

**The slider** (`PlayerController.push_level`, 0 to 1): Up pushes more, Down eases, at a pace of a full range in about 2.5 s; it stays where it is left, through resets and waterstarts, and the HUD strip shows it ("push 75 %"). An AI skipper's hands can set it (`AiHands.push`); hands that do not leave the controller sailing as today, so the fleet and every existing test are unchanged until the fleet adopts it (an RA item). The game starts the player at 75 %: "easy to just go" (Max's direction). The beginner's W/S keys keep their meaning (a few seconds of hand sheeting over the auto-sheet); Up/Down move from the sheet to the slider.

**The ladder** (`PushCurveConfig`, `Game/config/push_curve_default.tres`, read by `PushDial`): what each setting of the slider asks of the sailor, straight between the points. The numbers are the rounds' result, not a guess; the table in section 4 is the starting point.

| Level | The sail | The pull held (`hike_share`) | The rig's lean | The back foot against the fin | The rail and the trim aimed for |
|---|---|---|---|---|---|
| 0 % | let fly: the sail luffs, the board stops | 0.8 | 25° | none | the technique's own |
| 25 % | half the drive the sail could give | 0.8 | 25° | none | the technique's own |
| 50 % | the full drive, within the eased pull | 0.8 | 25° | none | the technique's own |
| 75 % | the full drive | 1.0 (neutral) | 25° | none | the technique's own |
| 85 % | the full drive | about 1.2 | about 30° | a third | a little more rail, a little more trim |
| 95 % | the full drive | about 1.45 | about 34° | two thirds | more |
| 100 % | the full drive | 1.6 | 35° | all of it | the most the rounds find fast |

**The back foot against the fin** (PH35, in `Game/sim/`, Michiel's by rule and asked for by him here). The sailor's sideways hold against the sail's pull goes into the hull through the feet. Today it enters at the feet's pressure point, between the straps. A rider in the straps chooses which foot carries it: pushing the back foot to leeward against its strap while the front foot pulls to windward moves the sideways force's entry aft, to the back strap; the other way round moves it forward. That is a yaw couple on the hull with no new force: the tail is pushed to leeward, the bow to windward, and the fin, right under the back foot, carries more of the side force and the rails less, so the fin's angle of attack rises with its lift and the upward part of its lift (the bend and the heel). Too far and the fin stalls (the soft spin-out of today; PH6 is the sudden one). `SimControls.back_foot_push` runs from -1 (the front foot) to +1 (the back foot), 0 = as today, bit for bit. Its bound is the straps: the whole sideways hold on one foot and no more.

**The technique as controls** (PH3, in `Game/sim/`): three fields of `SimControls` that override the technique's own targets when set and leave everything bit for bit when not (NaN): `rail_bank_deg` (the bank the feet aim for, in place of `_rail_bank_deg_by_point_of_sail`), `trim_aim_deg` (the trim the feet press for, in place of `_running_trim_target_deg`) and `rig_lean_max_deg` (the rig's lean at full hike, in place of the config's). The slider sets them on the player's controls, so nothing writes a config while playing, and an AI board on a thread gets its own by construction. Proven by a test that hashes the state every tick with the fields unset against the branch before.

**The autopilot** (`Game/sim/autopilot.gd`, `helm.gd`): `drive_share` (the sail trimmed between luffing and the most drive, for the slider's lower half; 1 is bit for bit today); the back foot in the course hold: in the straps the legs carry the steady helm as far as they reach and the rake the rest and the quick part, so the rake leaves its stop on a reach (P6.1, measured, kept only if it pays or steadies); the push's fin loading as a bias on the legs over the helm.

**The steering when planing** (`player_controller.gd`): the beginner's turn loop gets the legs as a fourth lever in the straps, measured with a steering check before and after (the yaw rate reached and the time to turn 30 and 60 degrees from a planing reach at 12, 18 and 24 kt, both ways). What the loop's caps do (`head_up_rate_budget_dps_ms`: heading up at speed held to 100 over the speed, 6.7°/s at 15 m/s) is measured too and said plainly.

## 2. The goal, in numbers

| What | Target | How it is measured |
|---|---|---|
| The ladder is a ladder | the speed made good rises with the level on every planing course at 18 and 24 kt, and the falls start above 75 % | the slider check, levels 0 to 100 % |
| 0 % stands still | below 1 m/s within 20 s from a planing reach | the slider check |
| 75 % crashes very little | at most one fall in 600 s per case at 12, 18 and 24 kt on 48 to 150°, with the default sea and gusts, and with the waves at twice the height and gusts of 0.3 | the slider check, 600 s, the hard conditions |
| 100 % goes faster and falls | faster than 75 % on the planing reaches where the pull binds (18 and 24 kt), and falls at 24 kt (the catapult, the spin-out) | the slider check |
| The back foot flies the board | with the push on, the fin carries more (its slip and lift up, within its stall), the wet front at or below 75 %'s, the speed not below it; over the bound the fin stalls | the slider check's fin columns; a unit test |
| The sail closes when pushed | at 100 % on the 18 and 24 kt reaches the sheet's mean is above 75 %'s and nearer 1; it opens only as the pull passes what is held (the heel, the hike used up) | the push check's `sheet` column by level |
| The steering in the straps | at 18 and 24 kt from a planing reach the turn to 30 degrees takes no longer than at 12 kt by more than a third, both ways, without a fall | the steering check |
| Nothing else gets worse | the matrix, the lake, the races and validation as on the branch before; unit tests green; the AI boards bit for bit | the regression round |

## 3. The suite

- `tools/push_check.sh` gains `--push=<0..1>` (the slider's level, applied through the controller as the game does), the sweep group `push.level`, `--wave_scale=<f>` (every wave's height and steepness times f) and the slider's columns (the sheet, the fin's slip and lift, the back foot). `--jobs=12` on this machine (16 cores): a 120 s case costs 18 s on one core, so 400 cases are about 12 minutes.
- `tools/push_slider_summary.py <run>`: one table per condition (wind, waves, gusts): the levels across, the courses down, each cell the speed made good and the falls; the goal's rows marked.
- `tools/steer_check.sh` (`Game/dev/steer_check.gd`): the beginner controller asked to turn at its full rate from a planing reach, the yaw rate and the times, with the legs on and off.
- The reach check, the matrix, the lake matrix, the races and validation as before, for the regression.

## 4. The rounds

| Round | What | Code | CPU |
|---|---|---|---|
| 0 | The levers built and tested; the slider's first curve; the baseline sweep: levels 0 / 25 / 50 / 75 / 85 / 95 / 100 at 12, 18 and 24 kt on 48, 75, 100, 120, 135 and 150°, the sea flat, default and twice the height, gusts 0.2, 150 s | `sim_controls.gd`, `windsurfer_sim.gd`, `autopilot.gd`, `helm.gd`, `push_dial.gd`, `push_curve_config.gd`, `player_controller.gd`, `ai_hands.gd`, `hud.gd`, `main.gd`, `project.godot`, `run_push.gd` | 15 min |
| 1 | The levers one by one at 85 and 100 %: the back foot 0 / 0.5 / 1, the trim extra 0 / 0.5 / 1°, the rail extra 0 / 2 / 4°, the lean 25 / 35, the pull 1.0 / 1.3 / 1.6; which pay, which fall, which steady | none (overrides) | 30 min |
| 2 | 75 % in every condition, 600 s: waves ×1 and ×2, gusts 0.2 and 0.3, 12 to 24 kt; if it falls, the sailor's ease on the chatter and the gust (the pilot easing the level itself when the board bounces or the hike is used up) | `autopilot.gd` if needed | 45 min |
| 3 | The steering: the check before and after the legs in the beginner's loop; the course hold with the legs | `player_controller.gd`, `autopilot.gd`, `helm.gd` | 15 min |
| 4 | The sheet by level, the curve's final numbers, the sweep again | the `.tres` | 15 min |
| 5 | Regression: unit tests, check, matrix, lake, races, validation; the spec and the report; Michiel's play-test list | none | 30 min |

Each round is one launch and one read. A variant that makes 75 % fall is reported, not tuned around; nothing is fitted to a number without its reason written down.

## 5. Agents

One Opus agent (xhigh) in a worktree for round 3's steering investigation, briefed with the lever and the steering check, once round 0's code is in; the lead builds the rest and reads every physics diff. Cost ledger in PROGRESS.md.

## 6. Hand-over

The report `push_slider.md` (the ladder's numbers, the falls by condition, the back foot's effect, the steering before and after, the sheet, what is open), the spec's rows (section 7.5: the back foot's entry point and the three overrides; the tuning log), the roadmap (GP1, GP3, PH3, PH35), the progress log, and the play-test: `tools/play.sh res://main.tscn` with Up/Down, `tools/play_push.sh --push=<percent>`.
