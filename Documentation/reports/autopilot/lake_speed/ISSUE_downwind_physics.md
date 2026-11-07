# Issue: the board cannot hold planing speed downwind in Silvaplana's conditions

**Found:** 7 November 2026, by the lead's downwind probe during the lake-speed training (Max's ask: crosswind
50 to 55 km/h, downwind 55 to 60 km/h in the gusts with a 7 to 8 m sail and a medium to big board).
**Owner:** Michiel (core physics, `Game/sim/`). The lead builds the test tools; nothing in `Game/sim/` changes
without Michiel.
**Priority (Max):** "this is the core physics so it needs to be 100% right." Check upwind as well.
**Backlog:** E01.S17 in `Documentation/backlog/epics/E01-physics.md` (branch `docs/backlog-1.0`).

## What Max sees

Across the wind the autopilot gets close to the target. Downwind the board stays at about 30 km/h, and in the
normal afternoon wind it often does not plane at all. Real sailors at Silvaplana do 55 to 60 km/h downwind in
the gusts on this gear (Max's experience; no measured track yet, see test P5).

## The evidence (flat water, the 117 L slalom with the 7.5 m slalom sail and the 38 cm fin, the lake's middle at 14:30)

The polar the sim gives today (from rest, the speed from 40 s on; x1.3 is the strong afternoon wind, 19 to 21 kt
at 10 m at the board, 17 to 19 kt at the sail):

| course (true wind angle) | mean km/h | gust km/h | planes? | apparent wind |
|---|---:|---:|---|---|
| 45 (x1.3) | cannot hold it: one fall, ends at 98 degrees | | | |
| 55 (x1.3) | 23 | 30 | after 17 s | 27 kt from 25 deg |
| 65 (x1.3) | 40 | 39 | after 9 s | 33 kt from 28 deg |
| 90 (x1.3, lake suite reference) | | 52 to 56 | yes | |
| 120 (x1.3) | 45 | **56** | after 4 s | 20 kt from 45 deg |
| 135 (x1.3) | 28 to 31 | **31 to 33** | just | 15 to 18 kt |
| 150 (x1.3) | 21 | 21 | never | 9 kt from 123 deg |
| 55 (x1.0, 16 kt at 10 m) | 14 | 7 | never | 19 kt from 26 deg |

**The symptom:** a cliff between 120 and 135 degrees. 120 makes 56 km/h in the gusts; 15 degrees deeper the
board loses 40 % of its speed. Slalom racing and speed sailing are done on broad reaches, so a real polar
should not have that cliff (Michiel to confirm the shape against his sources).

The force balance after a flying start (the reach at 100 degrees, then bearing away to 135 at 25 s):

| moment | speed | wind at the sail | apparent wind | sail's drive | hull + fin drag |
|---|---:|---:|---|---:|---:|
| on the reach, 100 deg | 56 km/h | 18.5 kt | 32 kt from 33 deg | 291 N | 244 N |
| just after the bear-away, 135 deg | 47 km/h | 16.8 kt | 18 kt from 40 deg | 157 N | 243 N |
| 4 s later | 42 km/h | 16.8 kt | 16 kt from 46 deg | 159 N | 203 N |
| 20 s later | 26 km/h | 16.7 kt | 10 kt from 85 deg | 108 N | 127 N |

The board decelerates all the way, because the drive stays below the drag at every speed on the way down. With
more wind (x1.5, 20 to 24 kt at the sail) the board holds 46 to 55 km/h at 135 degrees while the wind at the
sail is 23 to 24 kt, and slows at 20 kt. Sea-level air (1.225 instead of 0.98 kg/m3) helps a little (from rest:
max 33 -> 45 km/h), the same shape.

## Why downwind is the hard case

Across the wind the board's own speed builds the apparent wind (32 to 35 kt at 56 km/h). At 135 degrees the
board runs away from the wind: the apparent wind is weakest at about 0.7 times the wind's speed (about 22 to
29 km/h here) and only grows again above that. So downwind is where the balance of the sail's drive against
the board's drag decides everything, and a small error in either shows there first.

## Checked and not the cause

- **The wind's height profile:** the sail gets 0.84 of the 10 m wind (power law, exponent 0.11 from the
  pattern's 5 m height; `maps/silvaplana/wind_silvaplana.tres`). A normal profile over water.
- **The map's wind turning along the lake** (18 degrees in 350 m sailing east from the middle): real (Max).
- **The autopilot holding a compass heading:** kept (Max: fine for downwind tactics).
- **The map's gusts:** fine (Max).
- **The bear-away in a lull:** the probe's own fixed timing; the lake suite's downwind case will wait for a gust
  (`PLAN_downwind_case.md`).
- **The sail's drive at 16 kt from 46 degrees (159 N)** is close to a simple textbook estimate (lift 1.1, drag
  0.25 on 7.5 m2 at 0.98 kg/m3: about 160 N). That estimate is the lead's, not a measurement: test P2 decides.

## The suspects, each with the test that decides it

| # | suspect | decided by |
|---|---|---|
| H1 | the board's drag at 40 to 60 km/h (hull friction + residuary + fin) too high: 200 N at 42 km/h, 220 to 260 N at 50 to 55 | P1 |
| H2 | the sail's force at an apparent wind of 30 to 60 degrees too low, or the angle of attack the controller holds (18 deg) not the sail's best drive | P2 |
| H3 | the planing hull's lift and trim at speed downwind (nose 2 deg up, the wetted length) giving more residuary drag than a real board | P1 |
| H4 | not physics: the controller's trim downwind (sheet, angle of attack, stance, the mast foot's pressure). Excluded first, so the physics is judged with the best technique | P2, P3 |
| H5 | the air density: 0.98 kg/m3 (plausible for a warm afternoon at 1,800 m; confirm the number used and its source) | P3 |
| H6 | **the fin lifts the tail at speed (Max, 7 November 2026: "in real life the fin will never lift up the back of the board while the nose is still in the water; only fins over 60 cm in weird cases")**. Measured on flat water: the fin's upward force grows with the speed, 40 N at 30 km/h, 113 N at 48, 150 to 185 N at 55 to 60; the nose drops with it, from 3.3 degrees up to 0.8 to 1.3. The source: the fin's bend (U2, `fin_model.gd` `_bend`, 19 October 2026) tilts its lift 10 to 11 degrees toward the deck, so about a fifth of the fin's sideways force pushes the tail up. A flat board wets more of its bottom: a likely part of H1 | P1, P7 |
| H7 | **the sailor's stance pushes the nose under getting going.** In the first 0.5 to 2 s from rest the body passes 150 to 200 N m nose-down through the feet (x1.3, 130 degrees: the nose 14 degrees down, the bow 0.43 m under) while the fin pushes nothing (0 to 9 N). The sim puts the sailor forward at low speed and steps back with the speed; a sailor starting in a strong wind stands back | P7 |

## The tests to implement (the full check)

Every test is a headless dev script that writes a table (and a CSV) into `Documentation/reports/physics/`;
none changes `Game/sim/`.

**P1 The tow test: the board's drag curve.** The board with the sailor's mass and stance towed at fixed speeds
15, 20, 25 ... 70 km/h on flat water, the fin carrying the side force of a beam reach and of a broad reach.
Logged per speed: hull friction, residuary, bow drag, fin drag, the trim (pitch), the wetted length, the
planing lift. For the three lake-suite gear combos. Compare with a reference drag curve for a planing
windsurf board (Michiel's sources in PHYSICS_SPEC, or published tow measurements; the source written down).

**P2 The sail sweep: drive against the apparent wind.** The sail alone at fixed apparent winds (10, 15, 20,
25, 30 kt) and apparent wind angles 20 to 150 degrees, angle of attack 5 to 40 degrees: lift, drag, drive
along the board, side force, the heeling moment. Find the angle of attack with the most drive per apparent
wind angle and compare with what the controller holds (18 deg today; `--pilot.target_alpha_deg` does not reach
it, so the controller's own number must be found and made settable). Compare the coefficients with the sail
model's source data.

**P3 The polar at Silvaplana.** Three gear combos x true wind angle 45 to 165 in steps of 15 x the wind at 10 m
14, 18, 22, 26 kt x flat water and the lake's waves x air 0.98 and 1.225. Each from rest and with a flying start
(a reach at 100 degrees, then bearing away in a gust; and for the upwind angles, a reach, then heading up).
Logged: the settled speed, the gust speed, planing yes/no, the apparent wind, the forces. The result: the polar
table and plot per gear. The cliff between 120 and 135 must be explained or gone.

**P4 The upwind check (Max's ask).** Pointing (the smallest true wind angle held without stalling or falling),
the speed and the speed made good to windward at 45, 50, 55, 60, 65 degrees, from rest and from a reach,
x1.0 and x1.3, the three gears. Today: 45 degrees cannot be held (a fall, the board ends at 98), 55 degrees
23 km/h (made good 13 km/h), 65 degrees 40 km/h, and at x1.0 55 degrees does not plane (14 km/h). Needs a
real reference (P5).

**P5 The real reference.** Max's GPS tracks at Silvaplana with the gear, the time and the wind at the
nearest station at that time; speed by heading gives a measured polar: crosswind, downwind and upwind.
Without it the targets are Max's numbers (crosswind 50 to 55, downwind 55 to 60 km/h in the gusts, 7 to 8 m,
medium to big board). The acceptance below is written from those until the tracks exist.

**P7 The fin's lift and the board's trim.** The fin's bend against real flex data (the flex test the model is calibrated to, the tip's deflection under sailing loads, sources written down); the fin's upward force and its pitch moment against the speed; the board's trim at 30 to 70 km/h against planing-hull science (the trim angle of least drag); the sailor's stance and the body's pitch moment from rest to the plane in 14 to 26 kt against how a sailor starts (back foot, weight back in a strong wind).

**P6 Regression after any physics change.** `tools/test.sh` (unit), `tools/check.sh`, `tools/test.sh
validation` (the 8 known reds: the polar sweep's numbers will move and are re-baselined with Michiel), the
night suite and the lake suite, the AI fleet's race tests (the start, the skipper's 12 kt race time),
`tools/lan_test.sh`. Then the autopilot is retuned: all its tuned numbers depend on this physics.

## Acceptance (draft; Max and Michiel confirm)

With the 117 L slalom and the 7.5 m slalom sail at Silvaplana's air on flat water, in a gust of 24 kt at
10 m (about 20 kt at the sail):
- crosswind (90 degrees) 50 to 55 km/h, and 55 to 60 km/h at 120 to 135 degrees after a flying start;
- the polar's top between about 110 and 140 degrees, falling off smoothly beyond, with no cliff;
- upwind pointing and speed within Max's reference (P5);
- on the lake's waves the loss across the wind stays within what Max sees (to be measured; 20 to 25 % today);
- every number traced to a source (P1, P2) or to Max's tracks (P5): no tuning the physics to a target.

## How to rerun the probe

`.sim_output/downwind_probe/run.sh` (the runs and their CSVs are in that folder, not in git). The harness's
options: `--twa_start`, `--bear_away_at`, `--bear_away_steer`, `--forces=1` (`Game/dev/run_lake_speed.gd`).
