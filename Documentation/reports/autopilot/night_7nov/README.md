# The autopilot's night of 7 November 2026

Max's seven asks (00:40), built and tuned overnight by an Opus builder on branch `autopilot/night7nov`
(worktree `WindsurfingMMZB-fixes`), for the lead and Max at 10:00. Only the player's beginner
controller (`Game/windsurfer/player_controller.gd`, which every AI board and the player sail with),
`ai_hands.gd`, the input map, the key strip and the Controls page, tests and tools were changed. No
physics, no `Game/sim/` file, no SailorConfig or BoardConfig number.

## What was built

1. **Shift + A/D, the carve** (ask 3). A new key action `steer_sharp` on Shift. Held with A or D, the
   turn asked is `sharp_turn_factor` times the normal rate (2.0 to start), at any speed; the
   head-up limit at speed widens by the same factor. The rail follows the rate asked, so a planing
   board banks into the sharp turn, times `sharp_rail_gain` on the plane. Into a Space tack or gybe
   with the key held toward the turn, Shift multiplies the key's rate by `sharp_manoeuvre_factor`
   (1.5) and the manoeuvre's caps by `sharp_cap_factor` (1.25). Plain A/D is unchanged. The key
   strip and the Controls page say "Shift + A/D: carve". An AI's hands can hold Shift too
   (`AiHands.sharp`).
2. **Taps** (ask 7). The A/D key is shaped into a ramp: `steer_rise_s` (0.2 s) from nothing to full,
   `steer_fall_s` (0.15 s) back. A 0.1 s tap now asks for a small turn instead of the full rate at
   once. The rail's share of a key's turn grows with how long the key has been held, full after
   `tap_rail_full_s` (0.4 s), so a tap steers with the rig and does not throw the sailor's weight
   onto a rail. The AI's stick goes through the same ramp (one controller for all).
3. **Hooks the tuner can turn** (asks 1, 2, 4), all off or neutral by default:
   - getting on the plane: below planing speed the heading hold aims up to `plane_bear_away_deg`
     further off the wind (no further than `plane_bear_away_to_twa_deg`), fading out by
     `plane_help_until_ms`. Only the heading hold does this: a key held is the player's own course.
     No pumping (the physics does not model it).
   - steering below the plane: the turn-rate loop's gains and the heading hold's rate per degree
     times `slow_rate_gain_scale`, `slow_integral_scale` and `slow_hold_scale` below planing speed.
   - flying: `airborne_helm_hold` holds the helm while the board is light over a crest (the water no
     longer answers it).
   - The reflex (ask 5) and the tacks and gybes (ask 6) already had their numbers; the tuner turns
     them.
4. **Tests**: `Game/tests/unit/test_controller_night7nov.gd` (six tests). `test_feet_press.gd`'s
   golden trace now sails with the ramp off, because that test is about the feet, not the keys.

## The scenario suite

`tools/night_suite.sh --label=<name> [--cases=1] [--controller.<field>=<n> ...]` runs every case as
its own headless Godot process, 14 at a time; one suite takes about 1.5 minutes. The cases are in
`tools/night_suite.py`, the harness in `Game/dev/run_night.gd` (and `Game/dev/run_matrix.gd` for the
tacks and gybes). The player's controller sails each case the way the autopilot drives it: the
heading hold and the auto-sheet, the keys pressed by script. Every run is seeded and the same.

| Scenario | Cases | What counts (cost, lower is better) |
|---|---|---|
| plane | open water 10, 12, 14 kt at 90 and 130 degrees from rest; the lake at 0.6 and 0.75 of its wind | the time until the board planes for 2 s (the whole run if it never does), minus 3 x the speed made good |
| steer | 8 and 10 kt, below the plane | 2 x the heading hold's error (degrees), and for a 30 degree turn away and up with the key held until 30 degrees: overshoot, the final error, the settle time, the heel, lean and rake jumps |
| taps | 0.1, 0.2, 0.3 s taps away and up at 8 and 18 kt | the heel, lean and rake jumps, the heading carried on after the tap, too little or far too much turn |
| carve | Shift + A/D away 0.8 s and up 0.6 s at 12, 18, 24 kt (and plain A/D for comparison) | minus 0.3 x the rate turned with Shift |
| fly | 24 and 30 kt at 110 and 135 degrees in waves 1.5 times higher, 24 and 30 kt at 120 with gusts 6.5 s apart, the lake at 1.32 and 1.65 | minus 2 x the speed |
| reflex | gusty (0.3) 18 and 24 kt at 100 and 135 degrees, 24 kt with the push at 75 % and the mouse body held, the lake at 1.0 and 1.32 | 20 x the share of the time the reflex eases, minus 2 x the speed |
| turns | the matrix's tacks and gybes at 12, 18, 24 kt: plain Space, the key held, the key held with Shift; at 18 and 24 kt the key and Shift also over another wave | the seconds from Space to the new course (25 if never) |

Every fall costs 100 in its scenario. The total is the sum of the seven.

## The baseline

See [baseline.md](baseline.md): the branch as it was at the tuner's start (the new features at their
starting numbers).

## What the baseline already shows

- **The reflex never eased in any case** (its share is 0.0 in all seven reflex cases and the rest):
  on these waters the fall it waits for never comes close enough. So "the autopilot opens the sail and
  stops on a reach" is not the reflex. A suspect worth a look (not proven): the ease in the air,
  which caps the sail's angle of attack at `airborne_alpha_deg` (6 degrees) whenever the board goes
  light over a crest from 18 to 20 kt up; at 18 kt on a beam reach the board goes light 26 times a
  minute (the taps case), at 24 to 30 kt 40 to 100 times. The tuner turns those numbers.
- **Light wind is slow in the physics**: at 8 and 10 kt the board makes 1.3 and 1.6 m/s on a beam
  reach; at 10 kt it never planes, at 12 kt it planes after 47 s on a beam reach and not at all on a
  broad reach in 60 s; the lake at 0.6 and 0.75 of its wind makes 1.9 and 2.7 m/s. A question for
  Michiel below.
- **Below the plane a 30 degree head-up overshoots to about 60 degrees** (the key let go at 30, the
  board turns on): the bear-away stops near 35 to 39. The tuner's slow-steering numbers test the
  controller's side of this.
- **Shift into a gybe at 24 kt with the key held falls** (gybe_beam_key, over both waves) at the
  starting numbers; plain A/D does not. The tuner may not add falls anywhere, and a fall costs 100,
  so it should take `sharp_manoeuvre_factor` or `sharp_cap_factor` down; check this in the morning.

## The tuner

`tools/night_tuner.sh` (the Python is `tools/night_tuner.py`, run with `python -I`) copies `Game/` once
to `.sim_output/night7nov/project` and sails that frozen copy, so the worktree can be edited while it
runs. It does coordinate descent: for one number at a time it scores the best set so far with that
number a step up and a step down (both in one pool), and keeps the better one when the total cost drops
by more than 0.5 and **no scenario has more falls than the baseline**. When a whole round over every
number keeps nothing, the steps are halved. The steps start at a quarter of each range. There is no AI
in the loop. A pair takes about 3 minutes, a round over the 36 numbers about 1.9 hours: about
three and a half rounds by 09:00.

The numbers and their ranges (all PlayerController fields, `--controller.<field>`):

| Ask | Number | Default | Range |
|---|---|---:|---|
| 3 carve | sharp_turn_factor | 2.0 | 1.5 to 2.5 |
| | sharp_rail_gain | 1.0 | 0.4 to 1.6 |
| | sharp_manoeuvre_factor | 1.5 | 1.0 to 2.0 |
| | sharp_cap_factor | 1.25 | 1.0 to 1.6 |
| 7 taps | steer_rise_s | 0.2 | 0 to 0.45 |
| | steer_fall_s | 0.15 | 0 to 0.35 |
| | tap_rail_full_s | 0.4 | 0 to 0.9 |
| | helm_rate_per_s | 2.0 | 1.0 to 3.5 |
| 1 plane | plane_bear_away_deg | 0 | 0 to 25 |
| | plane_bear_away_to_twa_deg | 125 | 100 to 145 |
| | plane_help_until_ms | 8.5 | 6.0 to 9.6 |
| 2 slow steering | slow_rate_gain_scale | 1.0 | 0.3 to 3.0 |
| | slow_integral_scale | 1.0 | 0.3 to 3.0 |
| | slow_hold_scale | 1.0 | 0.4 to 2.0 |
| | hold_lead_s | 0.3 | 0 to 0.8 |
| | hold_rate_per_deg | 0.8 | 0.3 to 1.5 |
| | hold_rate_limit_dps | 20 | 8 to 30 |
| | rate_gain | 0.01 | 0.004 to 0.025 |
| | rate_integral_gain | 0.02 | 0.005 to 0.05 |
| | carve_rate_dps | 57 | 35 to 80 |
| | head_up_rate_budget_dps_ms | 100 | 60 to 160 |
| 4 flying | airborne_helm_hold | 0 | 0 to 1 |
| | airborne_alpha_deg | 6 | 2 to 14 |
| | airborne_support_share | 0.3 | 0.15 to 0.5 |
| | airborne_hold_s | 0.3 | 0.05 to 0.8 |
| 5 reflex | reflex_from_share | 0.65 | 0.5 to 0.85 (always below reflex_full_share) |
| | reflex_full_share | 0.9 | 0.75 to 0.99 |
| | reflex_alpha_deg | 6 | 2 to 14 |
| | reflex_bear_away_dps | 8 | 0 to 16 |
| | reflex_hold_s | 0.3 | 0.1 to 0.8 |
| 6 tacks, gybes | key_gybe_rate_dps | 40 | 28 to 60 |
| | key_tack_rate_dps | 20 | 14 to 30 |
| | gybe_rate_max_dps | 40 | 32 to 60 |
| | tack_rate_max_dps | 20 | 15 to 30 |
| | gybe_entry_alpha_deg | 8 | 3 to 15 |
| | settle_rate_dps | 15 | 6 to 25 |

### Reading its output

- `.sim_output/night7nov/tuner.log`: one line per candidate (the number changed, its total, KEPT when
  it became the best).
- `.sim_output/night7nov/leaderboard.md`: the 40 best candidates by total, then every candidate in
  order, with each scenario's cost and the falls; at the end the numbers of every kept candidate.
- `Documentation/reports/autopilot/night_7nov/best.txt`: the best set's overrides (only the numbers
  that differ from the code's defaults), with its scores against the baseline in the comment lines.
  It is rewritten whenever the best improves.
- Each candidate's logs: `.sim_output/night7nov/candidates/<cNNNN>/` (one log per case,
  `results.json`, `scores.json`).

### Stopping and resuming

It stops by itself at 09:00. To stop it sooner: `touch .sim_output/night7nov/STOP` (it stops after the
pair it is scoring, within about 3 minutes), or end the Godot and Python processes. To resume: run
`tools/night_tuner.sh --until=<hh:mm>` again; it carries on from `.sim_output/night7nov/tuner_state.json`
(`--fresh=1` starts over). Detached from a terminal, as it was started at night (PowerShell):

    Start-Process -FilePath "C:\Program Files\Git\usr\bin\bash.exe" -ArgumentList @('-l', '<a launcher .sh in a path without spaces>') -WindowStyle Minimized

where the launcher sets `PATH="/usr/bin:/mingw64/bin:/bin:$PATH"` and `GODOT`, cds into the worktree
and runs `exec tools/night_tuner.sh --until=09:00`.

## What the morning must do

1. Read `best.txt` and the leaderboard. Check that the best set's gains are spread over the
   scenarios and not one lucky case (the suite has one wave and gust pattern per case).
2. Apply the best set as the defaults: write each `--controller.<field>=<value>` of `best.txt` as the
   field's default in `Game/windsurfer/player_controller.gd`, then update the defaults in
   `tools/night_tuner.py`'s PARAMS (if the tuner is ever run again) and any unit test that pins an
   old number.
3. Run `tools/test.sh`, `tools/check.sh`, `tools/test.sh validation` (8 known reds),
   `tools/matrix.sh`, `tools/lake_matrix.sh`, and `tools/lan_test.sh --map=lake --seconds=40`.
4. Max plays it: Shift + A/D on the plane and into a gybe, short taps, light wind on the lake.
   Things the harness could not check: how the ramp feels on the keyboard, and whether Shift + A
   and Shift + D reach the A/D actions in the real game window (Godot matches an action's key with
   extra modifiers held, so it should).
