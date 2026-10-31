# GP11: the beginner's broad reach from rest does not plane

31 October 2026, Session 63, on `gp1/push-slider`. The item came from the steering agent (Session 62): the player's beginner controller on a 135° course at 18 kt sails 8 m/s for 90 s, where the autopilot's reach check does 12.6, so "the start on a reach and the bear-away are the beginner's, not the physics'". Measured here: it is the physics, the hull's hump, and the comparison was not like for like.

## 1. In short

- The autopilot's reach check never starts on a broad reach: its scenario (`Game/dev/scenarios/beam_reach.gd`) starts heading south with the wind from the west, a beam reach, and the pilot only then holds 135°. A board that is already planing keeps planing through the bear-away; a board at rest on 135° does not get planing at all. The player's controller does the same as the autopilot when started the same way.
- From rest on flat water in a steady wind, the beginner's board planes on every course up to 120° at 18 kt and up to 110° at 12 kt. Deeper, it sits on the hump: 7.7 m/s at 135° in 18 kt, 1.9 m/s in 12 kt.
- Nothing in the sailor's technique moves it over the hump: the stance, the hump's trim and the slider change the speed by less than 1.5 %. The one lever is the heading, as in real windsurfing in marginal wind: get planing across the wind, then bear away.
- The cause is the hull's hump (the planing onset at 14.4 kn where a real board of this size planes at 8 to 10 kn; PH16, the validation check that is red on purpose) meeting the weak apparent wind of a slow board on a broad reach. At 12 kt the boom's 85° stop adds to it: with the apparent wind from 114° the sail cannot be eased below 29° of attack and stalls.

Nothing was changed in the controller. The follow-ups are at the end.

## 2. The measurement

`tools/steer_check.sh` sails the beginner controller (the auto-sheet on, an AI's hands holding the true wind angle) from rest on the game's open water, flat and steady, and reports the speed at the moment the stick would go over (`--from`). Runs `gp11_*` in `.sim_output/steer/`.

**The speed at 60 s from rest, by course** (`--twa=<deg> --from=60 --hold=1`):

| Course (TWA) | 12 kt | 18 kt |
|---|---|---|
| 80° | 7.44 m/s | 12.03 m/s |
| 90° | 7.93 | 13.14 |
| 100° | 8.00 | 13.77 |
| 110° | 7.13 | 14.34 |
| 120° | 2.59 | 13.99 |
| 127° | 2.30 | 10.01 |
| 135° | 1.89 | 7.71 |

**The technique at 135° in 18 kt** (`--from=40`, the speed at 40 s; the board is steady from 20 s on):

| Variant | Speed | Note |
|---|---|---|
| as it is | 7.69 m/s | sheet 0.46, the sail at 18° (the auto-sheet's best drive), 144 N of drive, the stance in the straps, 55 % planing, 1.65 m wet |
| stance back later (`stance_speed_full_ms` 10, 14) | 7.69 | the same to the hundredth: over the hump speed the stance goes aft on its own, and the feet trim the board to the same target |
| the straps further forward (`stance_planing_z_m` 0.4, 0.2) | 7.69 | the same: the feet's press reaches the same trim |
| the hump's attitude (`hump_trim_deg` 0, 1.5, 5) | 7.69 | the same |
| the running trim 1 / 3 / 4 / 5 / 6 / 8° (default 2) | 7.71 / 7.80 / 7.81 / 7.40 / 6.88 / 5.70 | the one lever, +1.5 % at best |
| the slider at 100 % / 50 % | 7.72 / 7.21 | the pull is small here (290 N in the hands), so holding more does nothing |
| the rig's lean 35° / 10° | 7.69 / 7.69 | |

At 12 kt on 135°: the boom at its stop (sheet 0.00), the sail at 29° of attack on an apparent wind from 114°, 71 N of drive, the rig raked fully forward to hold the course, the stance out of the straps, 1.9 m/s.

## 3. What follows

- **The physics (Michiel):** this is PH16's hump seen from the broad reach. The gameplay cost: a player who starts, waterstarts or ends a gybe on a deep course in 18 kt has to head up to get going; the game gives no hint of that. A real sailor's other lever over the hump, pumping the sail, does not exist in the simulation; if the hump stays where it is, pumping would be the honest way to get planing on a broad reach (a physics item, proposed as PH39).
- **The how-to text (UI2):** "to get planing, point across the wind, then bear away once the board flies" belongs on the How to sail page.
- **The controller:** nothing to change. The reach check's start is a beam reach on purpose, and the push check's start (70 to 100°, then the bear-away) is the right technique.
- **The time trial (GP4) and the courses:** a start line reached on a beam reach, not a broad one.

## 4. To repeat

```
tools/steer_check.sh --winds=12,18 --twa=135 --from=60 --hold=1 --run=gp11
tools/steer_check.sh --winds=18 --twa=135 --from=40 --hold=1 --sailor.running_trim_deg=3 --run=gp11_rtrim3
tools/steer_check.sh --winds=18 --twa=135 --from=90 --hold=1 --trace=1 --trace_from=0 --run=gp11_trace   (the per-tick CSV)
```
