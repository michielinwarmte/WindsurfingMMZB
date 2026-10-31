# The steering when planing: why heading up was sluggish, and the legs first

For Michiel and Max. Written 31 October 2026 by an Opus agent for round 3 of the [push slider plan](PLAN.md), on the branch `gp1/steering` (from `gp1/push-slider`). Michiel's play-test: "While going at moderate speeds the steering is fine, but when planing at high speeds the steering becomes very sluggish. This is sort of realistic, but it is more that the technique for steering changes when planing and standing in the footstraps: the steering comes more from pushing and pulling of the two legs and less from moving around the sail."

Every number here comes from the steering check (`tools/steer_check.sh`), run on this branch; the run names are the folders in `.sim_output/steer/`. Nothing in the physics (`Game/sim/` other than the sailor's brain, `autopilot.gd`) was changed.

## 1. In short

- **Heading up at speed was slow for one main reason: the auto-sheet let the sail go.** A turn toward the wind at planing speed pushes the sailor outward, to leeward, like a car pushes you outward in a bend. The auto-sheet pilot felt that push as "I am being pulled over the sail" and, within a second, eased the sail nearly to luffing (its "urgent" easing). With no drive the board slowed from 14 to 16 m/s to 7 m/s, and the rig, which steers through the sail's force, lost its grip: the turn nearly stopped for about two seconds between 15 and 28 degrees. Switching only that easing off took the 30 degree head-up from 4.35 to 3.03 s at 18 kt and from 5.38 to 3.20 s at 24 kt, with the board still at 11.5 to 12.5 m/s at 30 degrees instead of 7.
- **The rate limit on heading up (12 degrees per second at planing speed) is the second reason, and it is not wrong.** With the sail kept drawing it makes heading up at 18 and 24 kt about as quick as at 12 kt (the 12 kt reach is held to 12.5 degrees per second too). Faster than that, this simulated board hardly banks into the turn, and the sailor is pulled over the sail: measured, at 18 and 24 kt. It stays.
- **The loop's gains and the physics are not the cause.** Twice the gains changed nothing (4.65 and 4.90 s). The rig has plenty of authority at speed: the same board bears away 30 degrees in 1.0 to 1.2 s and turns at up to 53 degrees per second.
- **The legs** (the back foot pushing the tail to leeward, the new lever PH35) help: alone, a full push turns the planing board at 8 to 30 degrees per second within half a second. In the old loop they shortened the head-up to 3.45 / 3.77 s (all the helm on the legs as well) but could not stop the sail from being let go.
- **What changed** (two pieces, both in the sailor's brain, none in the physics):
  1. `autopilot.gd`: the push of a head-up the sailor asked for is expected. The sailor still eases a little while it lasts (as before), but no longer lets go urgently for it, unless the felt heel nears the catapult or comes from something else (a gust).
  2. `player_controller.gd`: the planing technique. Above 35 to 40 km/h with the feet in the straps, the legs push first, on the turn rate the loop has not reached yet; the rig follows only as the turn goes on. Below that speed nothing changes.
- **After:** on the planing beam reach the 30 degree head-up takes 2.53 s at 18 kt and 2.28 s at 24 kt (it took 4.35 and 5.38; 12 kt: 2.92 before and after), the board keeps 11.3 and 12.1 m/s at 30 degrees (7.1 and 7.5 before), the rig is moved about half as far while the legs push (on average 0.15 and 0.30 of the rake's range from where it was, against 0.33 and 0.44), bearing away is as quick as before, and nothing falls in the turns of the steering check at any wind, flat or with waves and gusts, from a beam or a broad reach, at the slider's 85 and 100 % (one fall in a condition I added: on the 24 kt broad reach with waves and gusts the sailor was catapulted during a 90 s run-up, before the turn; section 7). The plan's goal (no more than a third slower than at 12 kt) is met both ways, flat and on the waves (18 kt on the waves: 2.62 before, when a wave happened to swing the board round at 55 degrees per second, 2.77 now). **Close to the catapult the sailor still lets go:** on the 24 kt broad reach with waves and gusts, and at the slider's 100 % on the waves, the felt heel of a head-up reaches the catapult's neighbourhood, the pilot eases the sail as before (on purpose, section 6.1), and those head-ups stay about as slow as they were (the 24 kt broad reach on the waves: 4.43 s before, 5.72 now). The first version, without that safety, turned them in 2.5 s but catapulted the all-rounder in the 24 kt race.

The steering check before (the branch as it came) and after, flat water and steady wind, the beam reach (100 degrees). Times in s, speeds in m/s; "rig" is how far the rig was moved on average, "sail eased" the auto-sheet's largest easing for the felt heel (0.9 is nearly luffing):

| Wind | Turn | v0 | t30 | t60 | v30 | vmin | rig | legs (after) | sail eased | falls |
|---|---|---|---|---|---|---|---|---|---|---|
| 12 kt | head up | 8.0 → 8.0 | 2.92 → 2.92 | 5.27 → 5.27 | 7.3 → 7.3 | 4.7 → 4.7 | 0.19 → 0.19 | 0.00 | 0.04 → 0.04 | ok → ok |
| 12 kt | bear away | 8.0 → 8.0 | 1.72 → 1.72 | 3.48 → 3.48 | 7.3 → 7.3 | 5.2 → 5.2 | 0.58 → 0.58 | 0.00 | 0.00 → 0.00 | ok → ok |
| 18 kt | head up | 13.8 → 13.8 | 4.35 → 2.53 | 6.53 → 5.90 | 7.1 → 11.3 | 3.7 → 6.8 | 0.33 → 0.15 | 0.08 | 0.91 → 0.57 | ok → ok |
| 18 kt | bear away | 13.8 → 13.8 | 1.17 → 1.15 | 2.63 → 2.45 | 13.7 → 13.6 | 11.8 → 12.0 | 0.23 → 0.17 | 0.39 | 0.00 → 0.00 | ok → ok |
| 24 kt | head up | 15.7 → 15.7 | 5.38 → 2.28 | 7.67 → 6.65 | 7.5 → 12.1 | 4.3 → 5.0 | 0.44 → 0.30 | 0.10 | 0.93 → 0.86 | ok → ok |
| 24 kt | bear away | 15.7 → 15.7 | 0.98 → 1.00 | 2.05 → 2.02 | 16.2 → 16.2 | 14.7 → 15.5 | 0.09 → 0.05 | 0.25 | 0.00 → 0.00 | ok → ok |

The same with the default waves and gusts (`--waves=1 --gusts=1`):

| Wind | Turn | v0 | t30 | t60 | v30 | vmin | rig | legs (after) | sail eased | falls |
|---|---|---|---|---|---|---|---|---|---|---|
| 12 kt | head up | 6.9 → 6.9 | 2.75 → 2.75 | 5.13 → 5.13 | 7.0 → 7.0 | 4.1 → 4.1 | 0.26 → 0.26 | 0.00 | 0.03 → 0.03 | ok → ok |
| 12 kt | bear away | 6.9 → 6.9 | 1.83 → 1.83 | 3.65 → 3.65 | 6.7 → 6.7 | 4.2 → 4.2 | 0.62 → 0.62 | 0.00 | 0.00 → 0.00 | ok → ok |
| 18 kt | head up | 12.4 → 12.3 | 2.62 → 2.77 | 5.68 → 5.98 | 9.7 → 10.8 | 4.2 → 5.6 | 0.19 → 0.17 | 0.07 | 0.77 → 0.55 | ok → ok |
| 18 kt | bear away | 12.4 → 12.3 | 1.35 → 1.28 | 2.75 → 2.65 | 12.8 → 12.9 | 11.5 → 11.3 | 0.33 → 0.25 | 0.46 | 0.00 → 0.00 | ok → ok |
| 24 kt | head up | 13.6 → 13.9 | 5.02 → 2.53 | 6.92 → 5.65 | 7.1 → 10.9 | 4.2 → 5.7 | 0.47 → 0.12 | 0.09 | 0.85 → 0.68 | ok → ok |
| 24 kt | bear away | 13.6 → 13.9 | 1.28 → 1.30 | 2.77 → 2.73 | 14.7 → 14.2 | 13.2 → 12.7 | 0.21 → 0.30 | 0.53 | 0.00 → 0.00 | ok → ok |

## 2. How it is measured

`tools/steer_check.sh` sails the player's beginner controller (the same controller every AI board uses) on the game's open water. The board holds a 100 degree reach (a beam reach) until 40 s, steered by the same stick an AI skipper uses; then the stick goes hard over for 8 s, one way (heading up) or the other (bearing away). One line per wind and direction:

| Column | Meaning |
|---|---|
| v0 | the speed when the stick goes over, m/s |
| t30, t60 | the time to turn 30 and 60 degrees, s |
| v30 | the speed at 30 degrees, m/s |
| peakYaw | the fastest turn rate, degrees per second |
| rake | the mean rake over the turn (1 = the rig fully back, -1 fully forward) |
| legs | the mean push of the legs (0 to 1) |
| rig | how far the rig was moved from where it was when the stick went over, on average (rake units): how much the sail is moved around |
| y1s | the turn rate one second after the stick went over |
| vmin | the lowest speed in the turn (to 60 degrees) |
| dep | how far the auto-sheet eased the sail for the felt heel at most (0 to 1; 0.9 is nearly luffing) |

New in this round (in `Game/dev/steer_check.gd`): the columns rig, y1s, vmin and dep, the kind of fall, `--trace=1` (a CSV per case, every tick from 2 s before the turn or from `--trace_from=<s>`: the helm, the yaw moments by source, the heel, the felt heel, the sail), and `--probe=<rake|legs|rail>:<step>` (the helm frozen where the loop left it, one lever stepped, the sheet still trimmed: what one lever does on its own). The `--pilot.` settings now go through the controller (`pilot_overrides`), so they also hold with `--push` (the lead's fix on `gp1/push-slider`, the same here).

## 3. The baseline

The controller as it was on `gp1/push-slider` (run `baseline`; flat water, steady wind, the beam reach at 100 degrees, the slider off):

| Wind | Turn | v0 | t30 | t60 | v30 | peakYaw | rake |
|---|---|---|---|---|---|---|---|
| 12 kt | head up | 7.99 | 2.92 | 5.27 | 7.28 | 17.4 | 0.52 |
| 12 kt | bear away | 7.99 | 1.72 | 3.48 | 7.31 | 29.4 | -0.26 |
| 18 kt | head up | 13.77 | **4.35** | 6.53 | **7.10** | 22.6 | 0.78 |
| 18 kt | bear away | 13.77 | 1.17 | 2.63 | 13.67 | 31.0 | 0.21 |
| 24 kt | head up | 15.69 | **5.38** | 7.67 | **7.52** | 17.1 | 0.85 |
| 24 kt | bear away | 15.69 | 0.98 | 2.05 | 16.21 | 53.2 | 0.40 |

What happens in the 18 kt head-up, second by second (`--trace=1`, run `trace0`):

| Time after the stick | Turned | Turn rate °/s | Speed m/s | Felt heel to leeward | Sail eased (dep) | Sail's angle of attack | Drive N |
|---|---|---|---|---|---|---|---|
| 0 s | 0° | 0 | 13.8 | 1° | 0 | 15° | 261 |
| 0.5 s | 4° | 13 | 13.7 | 10° | 0.03 | 14° | 242 |
| 1.0 s | 9° | 16 | 13.4 | 9° | 0.42 | 14° | 228 |
| 1.5 s | 16° | 4 | 12.8 | 16° | **0.79** | 6° | 102 |
| 2.0 s | 20° | 10 | 11.8 | -1° | 0.88 | 5° | 74 |
| 3.0 s | 25° | **-6** | 9.3 | 2° | 0.71 | 3° | 53 |
| 4.0 s | 28° | 4 | 7.7 | 0° | 0.61 | 3° | 55 |
| 4.5 s | 31° | 7 | 6.9 | 1° | 0.55 | 3° | 59 |

The board answers the stick at once (13 to 16 degrees per second within a second), so the rig is not short of authority. Then the turn's push tips the felt heel 10 to 16 degrees to leeward, because the board banks into the turn only slowly (the bank asked for climbs at 12 degrees per second; the board's heel lags further behind, at 1 to 2 degrees after 1.5 s). The pilot's urgent easing (it starts at 10 degrees of felt heel) lets the sail go: the angle of attack drops from 15 to 3 degrees and the drive from 261 to 50 N. The board slows, the rig (which steers through the sail's side force) has nothing to push with, and the turn stops between 20 and 28 degrees for two seconds, with the rig fully back. The easing then fades at its slow rate (about 0.1 per second), so the board crawls round at 4 to 7 m/s.

At 12 kt the same turn pushes only half as hard (the push is the speed times the turn rate: 8 m/s against 14), the felt heel stays under 10 degrees, the pilot eases 0.04 at most, and the turn goes through at 9 to 16 degrees per second.

## 4. Each lever, one at a time

Each row changes one thing with an override (no code), flat water, steady wind. The head-up at 18 and 24 kt: the time to 30 degrees, the speed there, the time to 60 degrees; and the 12 kt head-up's time to 30 degrees, which must not change.

| Lever | Override | 18 kt: t30, v30, t60 | 24 kt: t30, v30, t60 | 12 kt t30 | Falls |
|---|---|---|---|---|---|
| none (baseline) | | 4.35, 7.10, 6.53 | 5.38, 7.52, 7.67 | 2.92 | 0 |
| **the sail's urgent easing off** | `--pilot.depower_urgent_rate_per_s=0` | **3.03, 11.51**, 6.27 | **3.20, 12.55**, 6.75 | 2.92 | 0 |
| all the easing for the felt heel off | and `--pilot.depower_rate_per_s=0` | 3.03, 12.13, 5.45 | 3.18, 13.83, 5.82 | 2.93 | 0 |
| the head-up rate floor 20 instead of 12 | `--controller.head_up_rate_min_dps=20` | 2.60, 8.53, 5.37 | 4.20, 7.14, 6.32 | **2.05** | 0 |
| no rate limit (30) | `--controller.head_up_rate_min_dps=30` | 2.15, 9.15, 4.23 | 2.82, 8.53, 5.23 | **1.57** | 0 |
| the loop's gains doubled | `--controller.rate_gain=0.02 --controller.rate_integral_gain=0.04` | 4.65, 6.69, 6.63 | 4.90, 6.99, 6.82 | 2.63 | 0 |
| the legs carry half the helm | `--legs=0.5` | 3.95, 7.73, 6.28 | 4.32, 7.69, 6.60 | 2.88 | 0 |
| the legs carry all the helm | `--legs=1.0` | 3.45, 8.20, 6.77 | 3.77, 8.35, 6.15 | 2.83 | 0 |
| the same, the legs twice as strong | `--legs=1.0 --sailor.back_foot_push_n=300` | 2.82, 9.48, 5.30 | 3.40, 8.67, 5.62 | 2.83 | 0 |
| urgent easing off and the floor 20 | both | 1.98, 12.17, 3.43 | 2.22, 13.29, 4.57 | 2.03 | 0 |
| urgent easing off and the legs on all the helm | both | 2.88, 11.50, 5.92 | 3.10, 12.58, 6.53 | 2.83 | 0 |

What this says:

1. **The sail's easing is the cause.** The urgent easing alone is nine tenths of the extra time over the 12 kt head-up and all of the lost speed; with it off the board is at 11.5 to 12.5 m/s at 30 degrees instead of 7, and the 12 kt turn does not change. Nothing fell, flat or with waves and gusts (run `nu_wg`).
2. **The rate limit is the rest, and it is the same as at 12 kt.** The limit is "100 over the speed, at least 12 degrees per second": at the 12 kt reach (8.0 m/s) that is 12.5, at 18 and 24 kt the floor of 12. Lifting the floor makes heading up faster at every wind, the 12 kt one too (2.05 and 1.57 s), so the slow steering would change; and with the easing still on, the board still slows to 7 to 9 m/s.
3. **The loop's gains are not it.** Doubled, the head-up gets no faster (the loop already reaches the asked rate within half a second).
4. **The physics is not it either.** Bearing away, the same planing board turns 30 degrees in 1.0 to 1.2 s and reaches 31 to 53 degrees per second; heading up it reaches the asked 12 to 16 degrees per second within a second, until the sail is let go. With no rate limit it turned at 23 to 35 degrees per second. (The probe below gives the levers one by one.)
5. **The legs help, but cannot fix the easing.** Carrying the helm on top of the rig, they cut the head-up time by a fifth to a third and the rig's mean rake from 0.78 / 0.85 to 0.70 / 0.62 (0.48 / 0.50 with 300 N), but the board still lost 40 % of its speed by 30 degrees, because the sail was still let go.

**The levers alone (the probe).** `--probe=<lever>:<step> --hold=1.5`: the helm frozen where the loop left it on the steady reach, one lever stepped toward the turn, the sheet still trimmed by the pilot; the turn rate half a second later (runs `p_none`, `p_legs1`, `p_rake01`, `p_rail02`). The board left alone already drifts at 0.4 (18 kt) and 1.4 (24 kt) degrees per second.

| Lever | 12 kt up / away | 18 kt up / away | 24 kt up / away |
|---|---|---|---|
| the legs, a full push (88.5 N m) | 14.8 / 3.2 | 10.7 / 12.1 | 30.1 / 7.7 |
| the weight on the inside rail, 0.2 | 2.7 / 0.3 | 4.1 / 9.5 | 2.7 / 1.6 |
| the rake alone, 0.1 of its range | 2.1 / 2.4 | 0.0 / 0.3 | -4.2 / -1.1 |

The legs are a strong, quick lever at planing speed: a full push turns the board at 8 to 30 degrees per second within half a second, either way (and already at 12 kt, where the steering is left as it was because Michiel finds it fine there). The rake stepped on its own does almost nothing in the first half second at speed (the rig is a heavy body that has to swing, and the sheet's trim moves with it); its authority shows in the loop, where it moves together with the rig's tilt and the rail. These open-loop numbers are rough: a planing board left to itself is not steady in yaw, and they differ by a factor of three between the two directions.

## 5. What did not work

Two things were built and measured and then taken out:

- **A faster head-up at planing speed, "carved"** (the floor lifted to the rate that the deepest bank the sailor uses, 30 degrees, would carry: g tan(30°) / v, 23 degrees per second at 13.8 m/s and 21 at 15.7), with the pilot not easing at all for the bank still to come. The turn took 1.6 to 2.0 s, but **the sailor was pulled over the sail** at 24 kt on flat water and at 18 and 24 kt with waves and gusts (runs `pt1`, `pt1_nolegs`, `pt1_wg`, `pt1_nolegs_wg`). The trace shows why: the bank asked for climbed to 24 to 30 degrees, but the board's heel stayed at 0 to 2 degrees; the felt heel reached 20 to 24 degrees, past the catapult's 20. In this simulation a powered, hiked board hardly banks to windward (the feet hold the body first, and what they have left does not bank the board against the sail), so the turn's push lands on the hike. An unbanked board can be turned toward the wind only as fast as g tan(20°) / v before the catapult: 15 degrees per second at 13.8 m/s, 13 at 15.7. The old floor of 12 sits just under that, which is why it stays (the comment at `head_up_rate_min_dps` says so now).
- **The legs pushing on the turn asked, open loop** (a full push for any turn of 12 degrees per second or more, whatever the board did). Quick (2.2 and 2.5 s), but the push overshot the turn to 20 degrees per second on the waves and the sailor was catapulted at 24 kt (run `a2_wg`, 2.4 s into the turn); and when the board slowed below the technique's speed mid-turn, the legs let go all at once and the turn stalled. In the loop instead (on the rate error, below), the legs damp an overshoot as well as start the turn.

## 6. What changed, and why

### 6.1 The pilot expects the push of a head-up it was asked for (`Game/sim/autopilot.gd`)

The auto-sheet eases the sail for the "felt heel": how far the sailor feels tipped to leeward, the board's heel plus the sideways push of a turn. It has two parts: a slow one (a sailor flung outward in a turn eases a little; 0.25 per second at most) and an urgent one (two per second more once the felt heel passes 10 degrees: "I am going over, let go"). Both read the turn's own push as being overpowered.

When the player heads up, the controller puts weight on the windward rail and the sailor banks the board to windward as far as a turn at that rate needs (`Telemetry.wanted_bank_deg`, the sim's own balance). Until the board has that bank, the push is felt as heel to leeward. The sailor asked for the turn and expects that push. So now:

- the slow part is unchanged: the sailor still eases a little while the push lasts;
- the urgent part counts only the felt heel **beyond the push the sailor expects** (`Autopilot._expected_turn_heel_deg`), which is, in three steps: the push of the turn the board is really making toward the wind (the heel a turn at this speed and yaw rate needs to feel level, atan(v w / g)); of that, only what the windward bank still to come does not carry yet (`Autopilot.windward_bank_to_come_deg`: the bank wanted to windward less the board's heel, nothing when the bank wanted is to leeward or none); and only while the felt heel is clear of the catapult: over the last 10 degrees before `SailorConfig.catapult_heel_deg` (20) it fades to nothing, so near the catapult the urgent ease acts as it always did, whatever the cause.

The first version expected the whole bank still to come. On the 24 kt race (T1, the validation's seed) the all-rounder was then catapulted once on its broad reach, where it had not fallen before. The likely mechanism (the race keeps no trace of the heel, so this is inferred, not seen): a small head-up asked by the skipper's stick put a windward bank on the books, and a gust's pull hid behind it. With the expected push limited to the turn the board really makes and faded near the catapult, a small correction expects next to nothing (section 7, the races).

Without a windward bank asked for, the pilot's trim is as before, bit for bit (the same formula with the bank to come at 0): straight sailing, bearing away, and the course hold with its rail off (`lean_share` 0, the default). The 12 kt turns are unchanged to the hundredth of a second without the slider (their felt heel stays under the urgent mark); with the slider at 100 % on the waves, where the 12 kt head-up does reach it, the time to 60 degrees moves by 0.01 s.

A variant that also left the slow part out (the sailor not easing at all for the expected push; runs `c_v1`, `c_v1_wg`) turned to 60 degrees a little sooner (5.5 against 5.6 s at 18 kt, 5.7 against 6.4 at 24 kt) and kept more speed in the turn (at least 8.4 and 10.2 m/s against 6.7 and 6.5), but it changed the 12 kt head-up (by 0.01 s), and with the rate floor lifted it let the sailor be catapulted (section 5): with nothing easing the sail, the rate limit alone keeps the sailor on the board. The slow ease stays as the safety: a push that lasts still eases the sail. Whether a real sailor eases at all for the push of a head-up at speed is a question for Michiel and Max (section 8).

### 6.2 The planing technique: the legs first (`Game/windsurfer/player_controller.gd`)

Above 35 to 40 km/h (9.7 to 11.1 m/s), as far as the feet are in the straps, the beginner's turn loop now steers with the legs first. The loop measures how much faster (or slower) the board should be turning than it is (the rate error). That error goes at once to the legs, `legs_rate_gain` (1/12) of a full push per degree per second: the back foot pushes the tail to leeward to head up, the front foot to bear away, on either tack. The rig's part of the loop is unchanged: its quick part and its trim, which grows as long as an error lasts and so carries a long turn. The result is that the legs start a turn and catch an overshoot, and the rig moves less and later.

Why these numbers:

- **35 to 40 km/h** is Max's speed for "all the strength I have" in the back foot (`questions_for_max.md`, question 2). The 12 kt reach (8.0 m/s, 29 km/h) is below it and steers exactly as before; the 18 and 24 kt reaches (13.8 and 15.7 m/s) are above it.
- **1/12 of a full push per degree per second**: a full push alone turns the planing board at 8 to 30 degrees per second within half a second (the probe), so a full push answers about the 12 degrees per second a head-up asks. Twice that gain (1/6, run `c_lg6`) was no quicker to 30 degrees (2.73 / 2.80 s against 2.72 / 2.87), slower to 60 and moved the rig more (rake 0.58 / 0.67 against 0.53 / 0.59).
- **On the rate error, not on the turn asked**: the open-loop version catapulted the sailor on the waves (section 5).
- On a steady course the error is nil, so the back foot is the push slider's (`back_foot_bias`, its "load the fin"), not the steering's.

The existing `legs_share` (the legs carrying a share of the whole helm, the steady trim included) stays at 0, so the existing tests and the slider's ladder keep their meaning.

### 6.3 The rate limit on heading up stays

`head_up_rate_min_dps` (12) and `head_up_rate_budget_dps_ms` (100) are unchanged; the comment now says why, with the numbers of section 5: faster, a powered board in this simulation does not bank into the turn and the sailor is pulled over the sail.

### 6.4 The tools

`Game/dev/steer_check.gd`: the columns rig, y1s, vmin and dep, the fall's kind and time, `--trace=1` and `--trace_from=`, `--probe=`, and the `--pilot.` settings through `pilot_overrides` (section 2).

### 6.5 The tests

- `test_helm.gd`, `test_the_pilot_does_not_let_go_for_the_push_of_a_head_up_it_was_asked_for`: half a second at 14 degrees of felt heel eases the sail by the slow and the urgent part on a flat board, and by the slow part only while 14 degrees of windward bank are still to come; the bank to come on both tacks and none for a leeward bank.
- `test_helm.gd`, `test_the_pilot_expects_only_the_push_of_the_turn_made_and_lets_go_near_the_catapult`: the expected push is the whole bank to come for a 12 degree per second head-up 10 degrees short of the catapult, half of it 5 degrees short, none at the catapult; for a board hardly turning only its own small push; none bearing away.
- `test_player_controller.gd`, `test_planing_in_the_straps_the_legs_push_the_turn_first`: at 14 m/s in the straps a turn key gives a full push, the back foot heading up and the front foot bearing away, on both tacks; at 8 m/s nothing.

## 7. After, in every condition asked for

Each table is the steering check before → after; the runs are `B_*` (the controller and pilot of `gp1/push-slider`, the same steering check) and `G_*` (this branch). Flat water and the beam reach are in section 1.

**From a broad reach (135 degrees)**, flat (`--twa=135`):

| Wind | Turn | v0 | t30 | t60 | v30 | vmin | rig | legs (after) | sail eased | falls |
|---|---|---|---|---|---|---|---|---|---|---|
| 12 kt | head up | 1.9 → 1.9 | 2.68 → 2.68 | 4.17 → 4.17 | 2.3 → 2.3 | 1.9 → 1.9 | 0.94 → 0.94 | 0.00 | 0.00 → 0.00 | ok → ok |
| 12 kt | bear away | 1.9 → 1.9 | - → - | - → - | 0.0 → 0.0 | 1.9 → 1.9 | 0.05 → 0.05 | 0.00 | 0.00 → 0.00 | ok → ok |
| 18 kt | head up | 7.7 → 7.7 | 3.48 → 3.48 | 7.42 → 7.25 | 9.2 → 9.2 | 7.6 → 7.6 | 0.36 → 0.35 | 0.09 | 0.11 → 0.14 | ok → ok |
| 18 kt | bear away | 7.7 → 7.7 | 2.30 → 2.30 | 3.47 → 3.47 | 5.7 → 5.7 | 4.1 → 4.1 | 0.73 → 0.73 | 0.00 | 0.00 → 0.00 | ok → ok |
| 24 kt | head up | 13.7 → 13.9 | 4.75 → 3.10 | 7.98 → 7.87 | 8.7 → 12.3 | 5.7 → 6.6 | 0.44 → 0.36 | 0.15 | 0.88 → 0.75 | ok → ok |
| 24 kt | bear away | 13.7 → 13.9 | 1.73 → 1.50 | 4.58 → 4.50 | 11.9 → 12.2 | 6.9 → 7.1 | 0.63 → 0.30 | 0.40 | 0.01 → 0.01 | ok → ok |

With waves and gusts:

| Wind | Turn | v0 | t30 | t60 | v30 | vmin | rig | legs (after) | sail eased | falls |
|---|---|---|---|---|---|---|---|---|---|---|
| 12 kt | head up | 1.8 → 1.8 | 2.55 → 2.55 | 3.85 → 3.85 | 2.7 → 2.7 | 1.7 → 1.7 | 0.84 → 0.84 | 0.00 | 0.00 → 0.00 | ok → ok |
| 12 kt | bear away | 1.8 → 1.8 | - → - | - → - | 0.0 → 0.0 | 1.7 → 1.7 | 0.08 → 0.08 | 0.00 | 0.00 → 0.00 | ok → ok |
| 18 kt | head up | 7.7 → 7.7 | 2.95 → 2.95 | 7.23 → 6.95 | 9.9 → 9.9 | 7.7 → 7.7 | 0.32 → 0.28 | 0.14 | 0.55 → 0.39 | ok → ok |
| 18 kt | bear away | 7.7 → 7.7 | 2.58 → 2.58 | 3.65 → 3.65 | 5.5 → 5.5 | 4.1 → 4.1 | 0.76 → 0.76 | 0.00 | 0.00 → 0.00 | ok → ok |
| 24 kt | head up | 12.2 → 12.9 | 4.43 → 5.72 | 7.28 → 7.87 | 8.1 → 6.8 | 5.0 → 4.9 | 0.48 → 0.46 | 0.16 | 1.00 → 1.00 | ok → ok |
| 24 kt | bear away | 12.2 → 12.9 | 1.88 → 1.75 | 4.40 → 4.37 | 11.6 → 12.0 | 7.1 → 7.7 | 0.67 → 0.45 | 0.52 | 0.02 → 0.05 | ok → ok |

**The broad reach after 90 s** (`--twa=135 --from=90`, 18 and 24 kt), flat and with waves and gusts:

| Wind | Turn | v0 | t30 | t60 | v30 | vmin | rig | legs (after) | sail eased | falls |
|---|---|---|---|---|---|---|---|---|---|---|
| 18 kt | head up | 7.7 → 7.7 | 3.48 → 3.48 | 7.47 → 7.25 | 9.2 → 9.2 | 7.6 → 7.6 | 0.36 → 0.34 | 0.09 | 0.12 → 0.14 | ok → ok |
| 18 kt | bear away | 7.7 → 7.7 | 2.30 → 2.30 | 3.47 → 3.47 | 5.7 → 5.7 | 4.1 → 4.1 | 0.73 → 0.73 | 0.00 | 0.00 → 0.00 | ok → ok |
| 24 kt | head up | 15.7 → 15.2 | 4.53 → 4.28 | 7.93 → - | 9.3 → 9.8 | 6.0 → 5.9 | 0.39 → 0.40 | 0.14 | 0.95 → 0.96 | ok → ok |
| 24 kt | bear away | 15.7 → 15.2 | 2.43 → 1.50 | 4.07 → 3.80 | 8.4 → 10.5 | 6.5 → 6.9 | 0.56 → 0.32 | 0.26 | 0.27 → 0.03 | ok → ok |

| Wind | Turn | v0 | t30 | t60 | v30 | vmin | rig | legs (after) | sail eased | falls |
|---|---|---|---|---|---|---|---|---|---|---|
| 18 kt | head up | 8.4 → 8.4 | 4.17 → 4.17 | 7.35 → 7.37 | 9.7 → 9.7 | 8.4 → 8.4 | 0.40 → 0.40 | 0.04 | 0.26 → 0.16 | ok → ok |
| 18 kt | bear away | 8.4 → 8.4 | 2.28 → 2.28 | 3.77 → 3.77 | 6.7 → 6.7 | 4.0 → 4.0 | 0.72 → 0.72 | 0.00 | 0.00 → 0.00 | ok → ok |
| 24 kt | head up | 14.0 → 0.1 | 5.08 → - | 7.87 → - | 8.6 → 0.0 | 6.1 → 0.0 | 0.52 → 0.00 | 0.00 | 0.82 → 0.00 | ok → **fell** |
| 24 kt | bear away | 14.0 → 0.1 | 1.68 → - | 4.85 → - | 12.5 → 0.0 | 5.8 → 0.0 | 0.68 → 0.00 | 0.00 | 0.00 → 0.00 | ok → **fell** |

The after run's fall in the second table came in the run-up, 86.9 s into it and before the stick went over (both 24 kt lines share the run-up): the board was thrown round by the waves at up to 58 degrees per second of yaw, the felt heel swung from 20 degrees one way to 23 the other within a second, and the sailor was pulled over the sail (`--trace=1 --trace_from=40`, run `G_long_trace`). The board was not heading up then, so the pilot eased as the old one would; the same run-up sailed through before and with the first version. To see whether it is the change or the sea, the push check sailed the 24 kt broad reach with waves and gusts for 300 s at 125, 135 and 145 degrees on both: 125 degrees 15.11 → 15.52 m/s made good, 0 → 0 falls; 135 degrees 12.64 → 13.22 m/s made good, 1 → 0 falls; 145 degrees 9.45 → 9.48 m/s made good, 0 → 0 falls (before → after). 1 fall in 900 s before, 0 after: the 24 kt broad reach on the waves is at the edge before and after, and the change does not make it worse.

**The push slider at 85 %** (`--push=0.85`), flat and with waves and gusts:

| Wind | Turn | v0 | t30 | t60 | v30 | vmin | rig | legs (after) | sail eased | falls |
|---|---|---|---|---|---|---|---|---|---|---|
| 12 kt | head up | 7.7 → 7.7 | 2.73 → 2.73 | 5.07 → 5.07 | 7.1 → 7.1 | 4.8 → 4.8 | 0.17 → 0.17 | 0.33 | 0.04 → 0.04 | ok → ok |
| 12 kt | bear away | 7.7 → 7.7 | 1.83 → 1.83 | 3.72 → 3.72 | 7.1 → 7.1 | 4.7 → 4.7 | 0.66 → 0.66 | 0.33 | 0.00 → 0.00 | ok → ok |
| 18 kt | head up | 13.8 → 13.8 | 4.28 → 2.78 | 6.38 → 6.07 | 7.1 → 11.7 | 3.3 → 5.9 | 0.30 → 0.12 | 0.37 | 0.98 → 0.66 | ok → ok |
| 18 kt | bear away | 13.8 → 13.8 | 1.10 → 1.10 | 2.58 → 2.38 | 13.9 → 13.8 | 12.0 → 12.3 | 0.21 → 0.14 | 0.23 | 0.00 → 0.00 | ok → ok |
| 24 kt | head up | 15.6 → 15.7 | 3.75 → 2.58 | 6.48 → 6.65 | 9.0 → 12.0 | 5.0 → 4.9 | 0.26 → 0.27 | 0.41 | 0.85 → 0.85 | ok → ok |
| 24 kt | bear away | 15.6 → 15.7 | 0.93 → 0.95 | 2.12 → 2.02 | 16.2 → 16.2 | 14.6 → 15.4 | 0.10 → 0.05 | 0.41 | 0.00 → 0.00 | ok → ok |

| Wind | Turn | v0 | t30 | t60 | v30 | vmin | rig | legs (after) | sail eased | falls |
|---|---|---|---|---|---|---|---|---|---|---|
| 12 kt | head up | 7.2 → 7.2 | 2.82 → 2.82 | 5.23 → 5.23 | 7.3 → 7.3 | 4.4 → 4.4 | 0.19 → 0.19 | 0.33 | 0.03 → 0.03 | ok → ok |
| 12 kt | bear away | 7.2 → 7.2 | 1.88 → 1.88 | 3.88 → 3.88 | 7.0 → 7.0 | 4.1 → 4.1 | 0.71 → 0.71 | 0.33 | 0.00 → 0.00 | ok → ok |
| 18 kt | head up | 12.5 → 12.2 | 4.35 → 3.37 | 6.15 → 5.88 | 6.1 → 8.9 | 2.8 → 5.1 | 0.26 → 0.23 | 0.38 | 1.00 → 0.69 | ok → ok |
| 18 kt | bear away | 12.5 → 12.2 | 1.40 → 1.32 | 2.85 → 2.68 | 13.0 → 12.9 | 12.1 → 12.1 | 0.40 → 0.25 | 0.23 | 0.01 → 0.00 | ok → ok |
| 24 kt | head up | 14.2 → 14.0 | 3.10 → 3.53 | 5.87 → 6.47 | 8.9 → 9.6 | 4.6 → 4.7 | 0.24 → 0.24 | 0.38 | 0.83 → 0.77 | ok → ok |
| 24 kt | bear away | 14.2 → 14.0 | 1.23 → 1.22 | 2.55 → 2.52 | 15.0 → 15.2 | 14.2 → 14.0 | 0.20 → 0.26 | 0.25 | 0.01 → 0.00 | ok → ok |

**The push slider at 100 %** (`--push=1`), flat and with waves and gusts:

| Wind | Turn | v0 | t30 | t60 | v30 | vmin | rig | legs (after) | sail eased | falls |
|---|---|---|---|---|---|---|---|---|---|---|
| 12 kt | head up | 7.7 → 7.7 | 2.63 → 2.63 | 4.88 → 4.88 | 7.3 → 7.3 | 5.3 → 5.3 | 0.13 → 0.13 | 1.00 | 0.06 → 0.05 | ok → ok |
| 12 kt | bear away | 7.7 → 7.7 | 1.83 → 1.83 | 5.07 → 5.07 | 7.0 → 7.0 | 2.5 → 2.5 | 0.81 → 0.81 | 1.00 | 0.00 → 0.00 | ok → ok |
| 18 kt | head up | 12.7 → 13.6 | 2.90 → 2.50 | 5.13 → 5.35 | 8.3 → 11.0 | 3.6 → 4.5 | 0.13 → 0.11 | 0.91 | 1.00 → 1.00 | ok → ok |
| 18 kt | bear away | 12.7 → 13.6 | 1.35 → 1.07 | 3.08 → 2.37 | 12.7 → 13.7 | 10.8 → 12.3 | 0.41 → 0.14 | 0.64 | 0.01 → 0.00 | ok → ok |
| 24 kt | head up | 15.6 → 15.6 | 3.25 → 2.83 | 5.93 → 5.88 | 9.5 → 10.8 | 3.4 → 3.7 | 0.24 → 0.22 | 0.93 | 1.00 → 1.00 | ok → ok |
| 24 kt | bear away | 15.6 → 15.6 | 0.92 → 0.92 | 2.57 → 2.30 | 16.3 → 16.3 | 14.1 → 14.3 | 0.18 → 0.10 | 0.78 | 0.00 → 0.00 | ok → ok |

| Wind | Turn | v0 | t30 | t60 | v30 | vmin | rig | legs (after) | sail eased | falls |
|---|---|---|---|---|---|---|---|---|---|---|
| 12 kt | head up | 7.5 → 7.5 | 2.73 → 2.73 | 4.72 → 4.73 | 7.4 → 7.4 | 5.3 → 5.3 | 0.12 → 0.12 | 1.00 | 0.17 → 0.08 | ok → ok |
| 12 kt | bear away | 7.5 → 7.5 | 1.87 → 1.87 | 5.47 → 5.47 | 7.1 → 7.1 | 1.9 → 1.9 | 0.86 → 0.86 | 1.00 | 0.00 → 0.00 | ok → ok |
| 18 kt | head up | 12.5 → 12.1 | 2.83 → 2.72 | 6.13 → 6.83 | 7.4 → 9.7 | 0.9 → 1.0 | 0.20 → 0.21 | 0.95 | 1.00 → 0.96 | ok → ok |
| 18 kt | bear away | 12.5 → 12.1 | 1.43 → 1.40 | 3.17 → 2.80 | 13.2 → 12.5 | 11.5 → 11.9 | 0.44 → 0.32 | 0.44 | 0.00 → 0.00 | ok → ok |
| 24 kt | head up | 14.6 → 14.7 | 1.68 → 3.08 | 4.62 → 6.60 | 11.2 → 9.8 | 4.9 → 1.7 | 0.11 → 0.22 | 0.93 | 0.92 → 1.00 | ok → ok |
| 24 kt | bear away | 14.6 → 14.7 | 1.43 → 1.37 | 2.92 → 2.68 | 15.7 → 15.9 | 14.2 → 14.6 | 0.33 → 0.30 | 0.51 | 0.02 → 0.00 | ok → ok |

**The legs twice as strong** (`--sailor.back_foot_push_n=300`, after only; against the after table of section 1), flat and with waves and gusts:

| Wind | Turn | v0 | t30 | t60 | v30 | vmin | rig | legs (after) | sail eased | falls |
|---|---|---|---|---|---|---|---|---|---|---|
| 12 kt | head up | 8.0 → 8.0 | 2.92 → 2.92 | 5.27 → 5.27 | 7.3 → 7.3 | 4.7 → 4.7 | 0.19 → 0.19 | 0.00 | 0.04 → 0.04 | ok → ok |
| 12 kt | bear away | 8.0 → 8.0 | 1.72 → 1.72 | 3.48 → 3.48 | 7.3 → 7.3 | 5.2 → 5.2 | 0.58 → 0.58 | 0.00 | 0.00 → 0.00 | ok → ok |
| 18 kt | head up | 13.8 → 13.8 | 2.53 → 2.73 | 5.90 → 6.03 | 11.3 → 11.7 | 6.8 → 6.0 | 0.15 → 0.14 | 0.04 | 0.57 → 0.57 | ok → ok |
| 18 kt | bear away | 13.8 → 13.8 | 1.15 → 1.13 | 2.45 → 2.33 | 13.6 → 13.6 | 12.0 → 12.2 | 0.17 → 0.14 | 0.30 | 0.00 → 0.00 | ok → ok |
| 24 kt | head up | 15.7 → 15.7 | 2.28 → 2.98 | 6.65 → 7.43 | 12.1 → 12.2 | 5.0 → 4.2 | 0.30 → 0.33 | 0.12 | 0.86 → 0.78 | ok → ok |
| 24 kt | bear away | 15.7 → 15.7 | 1.00 → 1.02 | 2.02 → 2.02 | 16.2 → 16.1 | 15.5 → 15.5 | 0.05 → 0.04 | 0.19 | 0.00 → 0.00 | ok → ok |

| Wind | Turn | v0 | t30 | t60 | v30 | vmin | rig | legs (after) | sail eased | falls |
|---|---|---|---|---|---|---|---|---|---|---|
| 12 kt | head up | 6.9 → 6.9 | 2.75 → 2.75 | 5.13 → 5.13 | 7.0 → 7.0 | 4.1 → 4.1 | 0.26 → 0.26 | 0.00 | 0.03 → 0.03 | ok → ok |
| 12 kt | bear away | 6.9 → 6.9 | 1.83 → 1.83 | 3.65 → 3.65 | 6.7 → 6.7 | 4.2 → 4.2 | 0.62 → 0.62 | 0.00 | 0.00 → 0.00 | ok → ok |
| 18 kt | head up | 12.3 → 12.4 | 2.77 → 2.87 | 5.98 → 6.15 | 10.8 → 10.6 | 5.6 → 5.2 | 0.17 → 0.18 | 0.07 | 0.55 → 0.59 | ok → ok |
| 18 kt | bear away | 12.3 → 12.4 | 1.28 → 1.28 | 2.65 → 2.63 | 12.9 → 12.4 | 11.3 → 11.1 | 0.25 → 0.30 | 0.54 | 0.00 → 0.00 | ok → ok |
| 24 kt | head up | 13.9 → 13.8 | 2.53 → 2.75 | 5.65 → 6.37 | 10.9 → 11.8 | 5.7 → 6.0 | 0.12 → 0.20 | 0.07 | 0.68 → 0.61 | ok → ok |
| 24 kt | bear away | 13.9 → 13.8 | 1.30 → 1.28 | 2.73 → 2.65 | 14.2 → 14.7 | 12.7 → 12.7 | 0.30 → 0.27 | 0.48 | 0.00 → 0.00 | ok → ok |

**The manoeuvre matrix** (`tools/matrix.sh`: the beginner's tacks, gybes, a turn on a run, out of irons and straight sailing at 12, 18 and 24 kt; before → after where they differ). Every case completes, before and after, with no fall:

| Case | kt | fall | course reached (s) | speed after (m/s) | heading range (°) | end speed (m/s) | end TWA (°) |
|---|---|---|---|---|---|---|---|
| tack_stb | 12 | - | 31.9 | 3.97 | 23.2 | 6.46 | -71.8 |
| tack_stb | 18 | - | 32.6 → 32.2 | 6.82 → 6.98 | 35.8 → 33.9 | 10.76 → 10.67 | -72.5 → -71.4 |
| tack_stb | 24 | - | 33.3 → 32.8 | 7.16 → 7.99 | 39.7 → 32.9 | 11.76 → 12.03 | -72.2 → -72.4 |
| tack_port | 12 | - | 31.9 | 3.97 | 23.2 | 6.46 | 71.8 |
| tack_port | 18 | - | 32.6 → 32.2 | 6.82 → 7.02 | 35.8 → 33.8 | 10.76 → 10.74 | 72.5 → 72.1 |
| tack_port | 24 | - | 33.3 → 32.8 | 7.08 → 7.98 | 40.2 → 33.0 | 11.77 → 12.01 | 72.3 |
| tack_held | 12 | - | 31.5 | 2.03 | 16.1 | 2.06 | -129.8 |
| tack_held | 18 | - | 32.3 → 33.4 | 2.94 → 4.21 | 359.5 → 151.8 | 5.90 → 9.10 | 56.5 → 109.2 |
| tack_held | 24 | - | 33.4 → 33.8 | 4.81 → 4.78 | 142.2 → 138.0 | 6.50 → 6.26 | 109.1 → 110.8 |
| gybe_broad | 12 | - | 34.6 | 2.85 | 4.8 | 3.83 | -111.2 |
| gybe_broad | 18 | - | 34.8 → 34.6 | 9.20 → 9.26 | 8.0 | 12.04 → 12.17 | -112.0 → -111.5 |
| gybe_broad | 24 | - | 35.1 → 34.9 | 10.81 → 12.26 | 8.2 → 9.4 | 14.28 → 14.59 | -107.3 → -108.4 |
| gybe_beam | 12 | - | 32.7 | 2.73 | 3.9 | 3.29 | -110.1 |
| gybe_beam | 18 | - | 33.7 → 33.4 | 8.52 → 8.63 | 8.1 → 8.0 | 10.91 → 11.07 | -112.3 → -112.1 |
| gybe_beam | 24 | - | 34.5 → 33.6 | 9.28 → 11.70 | 7.8 → 9.5 | 12.94 → 14.34 | -109.1 → -109.9 |
| run_left | 12 | - | 28.7 | 3.97 | 27.0 | 6.27 | -101.8 |
| run_left | 18 | - | 27.3 | 5.12 | 43.3 | 9.90 | -67.5 |
| run_left | 24 | - | 27.9 → 27.8 | 8.55 → 9.14 | 20.3 → 12.3 | 14.18 → 13.93 | -108.4 → -102.2 |
| irons | 12 | - | 4.8 | 2.12 | 10.6 | 2.03 | -131.5 |
| irons | 18 | - | 4.5 | 1.94 | 359.6 | 2.28 | 136.9 |
| irons | 24 | - | 3.7 | 2.91 → 3.10 | 359.4 → 359.5 | 5.83 → 5.86 | 120.5 |
| straight | 12 | - | - | 7.95 | 0.0 | 7.98 | 90.0 |
| straight | 18 | - | - | 13.02 | 0.1 | 13.01 → 13.02 | 90.0 |
| straight | 24 | - | - | 14.73 | 0.0 | 14.73 | 90.0 |

The 12 kt cases are the same to the last digit. At 18 and 24 kt the tacks reach the new course 0.4 to 0.5 s sooner, hold a narrower heading range (33 to 34 degrees against 36 to 40) and sail away faster (7.0 to 8.0 m/s against 6.8 to 7.2); the 24 kt gybes come out 1.5 to 2.4 m/s faster and the turn on a run 0.6 m/s; straight sailing is unchanged within 0.01 m/s. The "tack_held" cases (the turn key held for 15 s, through the wind and on) end on other headings than before, because the board is still turning when the key is let go; they complete without a fall either way.

**Tests and checks.** `tools/test.sh`: 600 of 600 (three new). `tools/check.sh`: 298 files, 0 failed. `tools/test.sh validation`: 35 pass, 9 fail, 2 pending, the same counts and the same nine red tests the autopilot rounds left on this physics ([autopilot_rework.md](../autopilot/autopilot_rework.md), section 6): the polar's speed band, its shape and the top speed (bit for bit: the course hold does not use the new parts), the planing onset (14.4 kn), the fin's side force (743 N), the push warning (no catapult on the 24 kt reach), the skipper's T1 times (12 kt 14:11.2, and now also 18 kt, below), the waves at 120 degrees (-18 %), and the fleet's start (Cautious 3 over the line and not back within 20 s on T1: the same board and the same 5.6 s longest delay with the old controller and pilot, run on the swapped-in files with `tools/test.sh validation -gselect=skipper`).

**The races.** The AI fleet sails this controller, so its races change too. At 24 kt the result of one race swings with any change to the steering (the boards' paths differ from the first tack on), so one race says little. On the validation's own race (T1, 24 kt, seed 0, one all-rounder): before, 6:20.9 without a fall; with the first version of the pilot change (the whole bank still to come expected) 6:26.3 and a catapult on the broad reach, the fall that led to the expected push being limited; with only the fade near the catapult, 7:55.1 and two catapults on bearing away toward a gybe; with the final version, 7:37.1 without a fall (a messy last beat: three tacks stalled head to wind). Four all-rounders on other seeds (10 to 13, each alone on the course, `--shadows=0 --rules=0`): before, one fall in four (falling off at the entry of a gybe on the broad reach) and finishes in 6:56, 7:17, 7:18 and 7:39; after, no fall, finishes in 6:30 and 6:38, and two boards still racing when the race closed 60 s after the first. The boards stalled about as often in tacks before as after (19 against 20 stops below 1 m/s). The same stalled tacks and the same gybe-entry falls show before and after: the 24 kt race is at the edge of what the all-rounder holds, with or without this change.

| The validation's races (one skipper alone, its seed) | Before: time, falls | After: time, falls |
|---|---|---|
| t1 12 | 14:11.2, 0 | 14:11.2, 0 |
| t1 18 | 7:55.4, 0 | 8:01.0, 0 |
| t1 18 again | 7:55.4, 0 | 8:01.0, 0 |
| t1 24 | 6:20.9, 0 | 7:37.1, 0 |
| rookie t1 18 | 8:14.1, 0 | 8:14.1, 0 |
| t2 18 | 3:08.5, 0 | 3:05.7, 0 |

At 18 kt on T1 the all-rounder is 5.6 s slower (8:01.0 against 7:55.4), and that crosses the skipper test's limit of 8:00 by a second: the test (`test_the_allrounder_finishes_t1_without_a_fall_in_12_18_and_24_kt`) was already red for its 12 kt time (14:11.2 against 12:00) and is now red for 18 kt as well. The 18 kt race's legs are the same until the second reach (6:16.5 → 6:21.8 at the fourth mark). Whether that is the change or the race's chaos (the 24 kt race was 1:16 slower on one seed and 0:26 faster on another) one race cannot say; the slider's race round should look at it.

## 8. What I could not do, and what is open

- **How it feels** I could not judge: the turn times, speeds and falls are measured, the feel is for the play-test. To try it: `tools/play.sh res://main.tscn`, plane on a reach at 18 to 24 kt and hold the key that heads up (D on starboard tack, the wind from the right). Before, the sail went soft a second into the turn and the board bogged down; now it should keep driving and come round at about the pace of a 12 kt head-up, with the rig swinging less. Bearing away is as quick as before, with the front foot doing part of it.
- **Straight sailing at planing speed is not bit for bit.** The legs also steer the heading hold (the hold's own small corrections are rate errors too), so the board's speed after the 40 s run-up moves by up to 0.4 m/s either way (and by 0.9 at 18 kt with the slider at 100 %: 12.7 → 13.6 m/s, flat water). With the slider's back foot near a full push (`back_foot_bias` 1 at 100 %) the legs can only ease it to bear away; heading up they have nothing left. The slider's sweep (plan rounds 4 and 5) should be run on this branch before its numbers are fixed.
- **The AI fleet** sails the same controller, so its boards now head up the same way at planing speed. The skipper's races and the fleet's start in the validation are compared in section 7; the learned brains (trained on the old steering), the race matrix and the persona matrix were not re-run here (the regression round, plan round 5).
- **Proposal for Michiel (physics, not changed): the windward bank.** A powered, hiked board in this simulation does not bank to windward when the sailor asks for it (0 to 2 degrees where a carved head-up asked for 20 to 30), because the feet hold the body first (`_apply_leg_forces`: "the body's balance comes first; the bank is held with what the feet have left") and the hike already uses them. That is what limits a planing head-up to about 12 to 15 degrees per second before the catapult. Whether a real rider can rail a planing board to windward while hooked in and fully powered is Michiel's and Max's call; if yes, the feet's bank against the hike is the place, and the head-up floor could then rise with it (the carved limit of section 5 was ready to measure).
- **Proposal: the legs' strength.** `SailorConfig.back_foot_push_n` stays at 150 N: I found no source for a sideways push in a strap, and Max's "all the strength I have" gives no number. In the old loop, twice as strong (300 N) shortened the head-up from 3.45 / 3.77 to 2.82 / 3.40 s with less rig; in the new one it is, if anything, a little slower (2.73 / 2.98 s against 2.53 / 2.28 on flat water, section 7), because the rate limit, not the legs, now sets the pace. So the steering does not need a stronger push; the slider's fin loading might. A number would need Max to estimate it (for instance, how hard he can push a bathroom scale sideways with the back foot while standing on the other leg) or a source on the hip's sideways strength.
- **The head-up rides closer to the catapult than before, up to a point.** Without the fade near the catapult (the version of runs `c_v2`), the felt heel in the 18 and 24 kt head-ups peaked at 17.8 and 18.3 degrees on flat water (16.5 and 16.0 before, when the sail was let go) and touched 20.7 for a moment on the waves at 24 kt; the catapult is at 20 on the slower felt heel the fall check uses (averaged over a second). With the fade, the pilot lets go as before over the last 10 degrees, which is why the hardest head-ups (the 24 kt broad reach on the waves, the slider at 100 % on the waves) stay slow. Where exactly the sailor should hold on and where let go is the play-test's question: the fade's width is `depower_heel_span_deg` (10), the pilot's own number, not a new one.
- **Does a sailor ease for the push of a head-up at all?** The slow ease stays (section 6.1); without it the turn keeps more speed. A question for Max.
- **A flutter in the physics, seen in passing.** On the steady 18 kt reach the yaw rate flips between +0.4 and -0.4 degrees per second every tick (30 Hz), the fin's yaw moment between 602 and 716 N m (the trace); at 24 kt it jitters by up to 1 degree per second from tick to tick, at 12 kt not at all. It was there before this work and is small next to the turn rates measured here; it looks like a numerical oscillation, for Michiel to look at.
- **The broad reach at 12 and 18 kt** does not get planing with the beginner controller from a standstill, within the check's 40 s or within 90 s (1.9 and 7.7 m/s at 135 degrees; the autopilot's course hold makes 12.6 m/s at 18 kt), so those lines are not planing turns; it is the same before and after (section 7). Worth a look on its own (the beginner's broad reach at 18 kt).
