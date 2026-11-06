# Lake Silvaplana's full waves (PH44 stage 2, 6 November 2026)

Built on `ph44/lake-full` (from `ph44/lake-waves` e9f3709) for Michiel's review, by Claude Opus 5.5 on Max's PC (Ryzen 7 5800X3D). Not pushed, not merged. The physics is [PHYSICS_SPEC.md](../../PHYSICS_SPEC.md) section 9.18 (new) on top of 9.17; last night's build is [lake_waves.md](lake_waves.md); the research is `wave_system_research.md` (on `docs/photos-and-roadmap-5nov`, not on this branch), sections 1, 3, 5 and 6.

Max asked: *"please implement the full waves in silvaplana"*, *"make the waves as you documented from the studies"*, *"i expect it to be harder to sail"*. His choices: the board's physics feels all the lake's waves, the hull is fixed so it takes short chop realistically, and the lake's waves are the standard on Silvaplana everywhere.

## In short

- **The board now floats on all four of the lake's wave trains** (8, 4, 2 and 1 m long). Last night it felt only the 8 m and 4 m ones, because with the short ones the hull stopped dead (the beam reach fell from 20 to 11 kt).
- **The hull fix:** a real planing board bridges waves shorter than the part of its bottom that is in the water. The hull now feels each wave averaged over its wet bottom (about 1.1 m long and 0.55 m wide when planing), worked out from the wave's pressure under a flat bottom, not tuned to a speed. A 1 m wave running along the board is felt at a sixth of its height, an 8 m wave almost whole. The fin feels the water's movement where the fin is, 15 cm down, where short waves move the water much less.
- **It is harder to sail, not halved:** over ten afternoons in the map's own gusty wind the beam reach is 18 % slower than on flat water (17.9 against 21.8 kt) and the broad reach 23 %, with no fall in 40 runs; in a steady 18 kt the beam reach is 28 % slower (18.5 against 25.8 kt). The board pitches about ±3° and now and then leaves the water. In the matrix of manoeuvres there are now falls: 6 in 30 cases (last night none). The biggest part of the speed loss comes from the 4 m waves, which were already in last night's physics (see "Are the waves correct?"). Last night's hull with all four trains: 5.9 kt in a steady 18 kt.
- **At 1.5 times the realistic height** (for tomorrow's autopilot training) it is much harder: a steady 18 kt beam reach drops to about half the flat-water speed, and the strong-wind runs end in catapults. No wave train gets near the breaking steepness, so nothing had to be cut off. **The lead should read the section "Are the waves correct?" before choosing 1.5.**
- **The lake's waves are the standard on Silvaplana:** free sailing, races (the player and every AI board), the AI training's races on the lake, LAN (both PCs the same sea: SYNC CHECK PASS, also with the release build and at 1.5 times). The "Lake waves" switch stays, on by default, and now works whatever the open-water sea is set to.
- **A wave-height setting:** Settings > Waves > *Lake wave height* (×0.5 to ×2), and `--lake_wave_scale=1.5` on the command line of any tool, which `tools/train.sh` (through `train.py`) and `tools/lan_test.sh` hand on.
- **Cost:** the sea now costs about half a millisecond more per board per tick than last night's two trains (1.42 against 0.93 to 0.99 ms in the editor engine, measured back to back); in the game's release build with 20 boards the physics of a tick is 11 % dearer than with the lake's old waves (11.0 against 9.9 ms). **The frame rate could not be measured cleanly tonight**: the PC was about 30 % slower than last night (the old waves gave 44 to 46 fps where they gave 88 last night, with other branches' tests and builds running), which puts both seas near the point where the physics no longer fits in a frame, and there the frame rate falls off a cliff (16 to 22 fps with the full waves, 44 to 46 with the old). Last night's 88 fps scaled by the 11 % gives about 80 fps (an estimate). See "Cost".

## What Max should look at on his screen

`tools/play.sh lake` (or the start menu's Lake Silvaplana).

1. **The water round the board at the start (camping beach):** the 1 and 2 m chop is now real shape on the water near the board, not only shading. The board skims over the short chop: its tips cut through the small crests a little, as a real planing board's do. Does it look right, or does the board look like it sinks into the chop?
2. **The feel on a beam reach in the afternoon wind:** a little slower, the board pitching and bumping over the 4 m waves, now and then airborne for a moment in a gust. Is it the right amount of "harder"? (This is the one thing no measurement here can tell.)
3. **Strong wind (Settings > Wind, 24 kt):** expect falls in the gusts. Too many?
4. **Settings > Waves, last row:** *Lake wave height*. Try 1.5 (the training's waves) and say if it looks like a rough day on the lake or like too much.
5. **From high up** (`--overview=2781300,1148000,250`): no stripes or seams on the water (checked in a screenshot, `lake_waves_full/720_3_high_toward_sils.png`).

Screenshots in [lake_waves_full/](lake_waves_full/): `720_1_start.png` (the start, 1×), `720_2_start_x15.png` (the start at 1.5×: the board heeled hard in a gust), `720_3_high_toward_sils.png`, `720_settings_waves_end.png` (the new row), `wide_1_start.jpg` (3137×1263). Not verified: how it looks while moving at 60 fps on Max's screen, and how it feels to sail.

## What was built (plain language)

1. **All four trains in the physics** (`physics_trains` 4 in `lake_waves_silvaplana.tres`). The 0.5 m train stays picture-only (the research's 1 m cut-off: the hull's buoyancy rows are 0.38 m apart).
2. **The hull's own view of the waves.** Each simulation now has two views of the same lake: the whole sea (for the fin, the sail's rig in the water, the effects, the picture) and the hull's view, where every train's height is multiplied by how much of it a flat bottom of the hull's wet size feels. For a wave of length λ under a bottom of length l the pressure averages out as sin(πl/λ)/(πl/λ) (the wave's pressure integrated over the bottom); the code uses the smooth bell-shaped version of the same width so it never turns negative. The bottom's size comes from the hull itself every substep (its wet length along the bow and its wet width across), so a board floating still bridges more than a planing one, and a wave crossing the board is averaged over the board's width, a wave running along it over its length. This is the "smooth the surface the strips see" fix the spec proposed for PH10, derived from the wave's pressure rather than fitted to a speed.
3. **The fin feels the water at its depth.** Under a wave the water moves less the deeper you go, by e^(−k·depth) for each train. At the fin's centre of pressure (about 15 cm down) the 1 m train's motion is 39 % of the surface's, the 8 m train's 89 %.
4. **The waves travel at the speed of the lake's depth** (ω² = g·k·tanh(k·h)), with the lake's median depth, 47 m: for these trains that is deep water, so nothing changes on Silvaplana, but a shallow lake's long waves would slow down. The picture uses the same formula.
5. **Seeded phases:** where each train's crests are at the start comes from a fixed random seed (44), the same on every PC and in every run.
6. **The breaking limit:** a train can never be steeper than a real wave can be (H/L = 1/7); at 1.5× none comes near it.
7. **The lake's waves everywhere on Silvaplana**, the AI's `sea_height` on the lake (last night's question 5: it now reads the lake's crest where the board starts), and the height multiplier.

## Are the waves correct?

### Height and period along the lake

`tools/godot.sh --headless --path Game -s res://dev/lake_waves_table.gd -- --check=1 --through=middle`: points along the line through the lake's middle in the wind from 222°, measured from the upwind (Sils) shore, at the lake's mean wind of 12, 18 and 24 kt (at 10 m). **Surface Hs** is measured on the surface the physics floats on: 4 × the standard deviation of its height at that point over 20 minutes. **Surface period** is the period of the train with the most energy there (the trains are the spectrum's octaves, so the period comes in steps). **Model** is what the lake's grid holds (the SPM law at that point's 9-ray fetch and wind). The **laws** are evaluated for the same fetch and wind: SPM 1984 and CEM 2002 (the research's 1.3).

**12 kt** (the lake's mean at 10 m, from 222°):

| From the upwind shore | 9-ray fetch | Wind there | Surface Hs | Surface period | Model Hs / Tp | SPM law Hs / Tp | CEM law Hs / Tp |
|---|---|---|---|---|---|---|---|
| 100 m | 103 m | 12.6 kt | 0.006 m | 0.80 s | 0.034 m / 0.55 s | 0.034 m / 0.55 s | 0.032 m / 0.41 s |
| 300 m | 322 m | 12.2 kt | 0.047 m | 0.80 s | 0.058 m / 0.79 s | 0.058 m / 0.79 s | 0.054 m / 0.60 s |
| 600 m | 611 m | 12.2 kt | 0.072 m | 0.80 s | 0.079 m / 0.98 s | 0.079 m / 0.98 s | 0.074 m / 0.74 s |
| 1000 m | 884 m | 12.2 kt | 0.090 m | 1.13 s | 0.095 m / 1.10 s | 0.095 m / 1.10 s | 0.089 m / 0.83 s |
| 1500 m | 1213 m | 12.3 kt | 0.109 m | 1.13 s | 0.113 m / 1.23 s | 0.113 m / 1.23 s | 0.106 m / 0.93 s |
| 2000 m | 1510 m | 12.3 kt | 0.123 m | 1.13 s | 0.126 m / 1.33 s | 0.126 m / 1.33 s | 0.118 m / 1.00 s |

**18 kt** (the lake's mean at 10 m, from 222°):

| From the upwind shore | 9-ray fetch | Wind there | Surface Hs | Surface period | Model Hs / Tp | SPM law Hs / Tp | CEM law Hs / Tp |
|---|---|---|---|---|---|---|---|
| 100 m | 103 m | 15.6 kt | 0.012 m | 0.80 s | 0.042 m / 0.59 s | 0.042 m / 0.59 s | 0.040 m / 0.45 s |
| 300 m | 322 m | 16.2 kt | 0.067 m | 0.80 s | 0.077 m / 0.87 s | 0.077 m / 0.87 s | 0.074 m / 0.66 s |
| 600 m | 611 m | 16.7 kt | 0.102 m | 1.13 s | 0.109 m / 1.09 s | 0.109 m / 1.09 s | 0.105 m / 0.83 s |
| 1000 m | 884 m | 17.2 kt | 0.129 m | 1.13 s | 0.134 m / 1.24 s | 0.134 m / 1.24 s | 0.130 m / 0.94 s |
| 1500 m | 1213 m | 17.7 kt | 0.159 m | 1.60 s | 0.162 m / 1.39 s | 0.162 m / 1.39 s | 0.158 m / 1.06 s |
| 2000 m | 1510 m | 18.0 kt | 0.181 m | 1.60 s | 0.184 m / 1.50 s | 0.184 m / 1.50 s | 0.179 m / 1.15 s |

**24 kt** (the lake's mean at 10 m, from 222°):

| From the upwind shore | 9-ray fetch | Wind there | Surface Hs | Surface period | Model Hs / Tp | SPM law Hs / Tp | CEM law Hs / Tp |
|---|---|---|---|---|---|---|---|
| 100 m | 103 m | 16.9 kt | 0.015 m | 0.80 s | 0.045 m / 0.60 s | 0.045 m / 0.60 s | 0.044 m / 0.46 s |
| 300 m | 322 m | 19.1 kt | 0.080 m | 0.80 s | 0.090 m / 0.92 s | 0.090 m / 0.92 s | 0.088 m / 0.70 s |
| 600 m | 611 m | 20.5 kt | 0.126 m | 1.13 s | 0.133 m / 1.16 s | 0.133 m / 1.16 s | 0.131 m / 0.89 s |
| 1000 m | 884 m | 21.6 kt | 0.164 m | 1.13 s | 0.169 m / 1.34 s | 0.169 m / 1.34 s | 0.168 m / 1.03 s |
| 1500 m | 1213 m | 22.6 kt | 0.204 m | 1.60 s | 0.207 m / 1.51 s | 0.207 m / 1.51 s | 0.207 m / 1.16 s |
| 2000 m | 1510 m | 23.3 kt | 0.236 m | 1.60 s | 0.238 m / 1.64 s | 0.238 m / 1.64 s | 0.239 m / 1.26 s |

How to read it:
- **The model is the SPM law**, by construction. The surface the board floats on carries 91 to 98 % of the law's Hs from 600 m of fetch on, and 81 to 89 % at 300 m: the rest is the 0.5 m octave and the shorter tail, which are picture-only.
- **Within 100 m of the upwind shore** the sea's peak is shorter than 1 m, so the physics' trains carry only 0.6 to 1.5 cm of a 3 to 4.5 cm sea; the rest is the 0.5 m train and the ripples in the picture. Near Sils the board feels nearly flat water. That is the cut-off the research chose; it is a small effect where the board sails (the start has 1.4 km of 9-ray fetch).
- **SPM against CEM:** the same height within 5 %, the CEM period 25 % shorter (so its waves are 40 % shorter). Which is right for Silvaplana is still Max's eye on the water (the research's question 8.1).
- No measurement of waves on Silvaplana exists (the research, 1.6). The one Swiss lake campaign the research found (Lake Neuchâtel, 1996) found the laws right in strong steady wind and too high in light wind.

### Steepness of each train, 1× and 1.5×

The breaking limit: a wave breaks when it gets steeper than H/L = 1/7 (coastalwiki, "Shallow-water wave theory": "Steepness H/L < 1/7 ... normally limits the height of deep water waves"; Michell 1893), which is k·a = π/7 = 0.449 for one regular train. The Gerstner surface folds when the trains' k·a add up to 1 (spec 9.8). The steepest each train gets **anywhere on the lake** (that is the short trains near the upwind shore):

| Wind | Train | k·a at 1× (H/L) | k·a at 1.5× (H/L) |
|---|---|---|---|
| 12 kt | 8 m | 0.005 (0.002) | 0.008 (0.003) |
| 12 kt | 4 m | 0.059 (0.019) | 0.089 (0.028) |
| 12 kt | 2 m | 0.102 (0.033) | 0.153 (0.049) |
| 12 kt | 1 m | 0.133 (0.042) | 0.200 (0.064) |
| 12 kt | all four summed (folds at 1) | 0.253 | 0.380 |
| 18 kt | 8 m | 0.017 (0.005) | 0.025 (0.008) |
| 18 kt | 4 m | 0.095 (0.030) | 0.142 (0.045) |
| 18 kt | 2 m | 0.124 (0.040) | 0.187 (0.059) |
| 18 kt | 1 m | 0.168 (0.053) | 0.252 (0.080) |
| 18 kt | all four summed (folds at 1) | 0.332 | 0.498 |
| 24 kt | 8 m | 0.035 (0.011) | 0.053 (0.017) |
| 24 kt | 4 m | 0.119 (0.038) | 0.178 (0.057) |
| 24 kt | 2 m | 0.149 (0.048) | 0.224 (0.071) |
| 24 kt | 1 m | 0.194 (0.062) | 0.291 (0.093) |
| 24 kt | all four summed (folds at 1) | 0.402 | 0.603 |
| | breaking limit (one train) | 0.449 (0.143) | 0.449 (0.143) |

At 1.5× the steepest single train is at 65 % of the breaking limit and the sum at 60 % of the fold, so **nothing is clamped**; the code would hold a train at k·a = π/7 if a larger multiplier reached it (`LakeWaves.held_at_breaking`, 0 here). For the sea as a whole: Hs/Lp at the start at 18 kt is 0.18/3.5 = 0.05 at 1× and 0.08 at 1.5×, a steep but ordinary wind sea.

### Speeds and falls, before and after

`tools/lake_matrix.sh`, the beginner controller (the player's), from the start spot off the camping beach; "map 14:30" is the map's wind with its gusts and lee (18.2 kt at 10 m), "steady" the lake's mean wind of 14:30 at that speed, no gusts. The mean speed in the 12 s window at the end of the run (kt), and the falls. One run per cell: a single fall in the window pulls a mean down a lot.

| Case | Flat water | Last night: 8 m + 4 m trains | Last night's hull with all 4 trains | **Now: all 4, the hull's view** | Now at 1.5× |
|---|---|---|---|---|---|
| Beam reach, map 14:30 | 21.7 | 20.3 | 10.7 | **20.4** | 12.8 (catapult at 35 s) |
| Beam reach, steady 18 kt | 25.8 | 21.2 | 5.9 | **18.5** | 13.2 |
| Beam reach, steady 24 kt | 29.5 | 24.8 | 8.7 | **13.0 (catapult at 21 s)** | 9.2 (catapult at 20 s) |
| Broad reach, map 14:30 | 24.7 | 19.2 | 12.2 | **18.0** | 14.1 |
| Broad reach, steady 18 kt | 13.6 (not planing) | 11.6 | 8.7 | **11.7** | 8.4 |
| Broad reach, steady 24 kt | 22.2 | 17.6 | 16.1 (fell at 2 s) | **17.3** | 15.2 |
| Broad reach from the middle, map 14:30 | 11.0 | 10.5 | 7.4 | **9.6** | 8.1 |
| Broad reach from the middle, steady 24 kt | 22.2 | 18.8 | 16.3 | **17.7** | 13.5 |

**Ten afternoons instead of one.** One run is one gust pattern, so the same cases were sailed in the map's wind at ten times of day, 12:30 to 17:00 every half hour (16.2 to 18.2 kt at 10 m; `tools/lake_matrix.sh --times=12:30,...,17:00 --only=straight` and `--only=broad`), on flat water, on the lake's full waves and on them at 1.5×. The mean of the ten window speeds (kt), and the falls in the ten runs:

| Case | Flat water | **The lake's full waves** | At 1.5× |
|---|---|---|---|
| Beam reach from the start | 21.8, no fall | **17.9 (−18 %), no fall** | 12.5 (−43 %), 2 catapults |
| Broad reach from the start | 13.1, no fall | **10.1 (−23 %), no fall** | 8.9 (−32 %), no fall |
| Broad reach from the middle | 10.0, no fall | **9.4 (−6 %), no fall** | 8.0 (−20 %), no fall |
| Gybe from a broad reach (the 12 s after it) | 14.3, no fall | **13.2 (−8 %), no fall** | 10.5 (−27 %), 1 catapult |

At 16:00 the start is in a lull on every sea (3 to 4 kt on all three); the broad reach at this wind often does not plane at all (on flat water too: 3 to 25 kt). The logs: `.logs/batch_flat.log`, `batch_lake1.log`, `batch_lake15.log` (not committed).

**The whole matrix of manoeuvres** (`tools/lake_matrix.sh --lake_waves=1`, 12:00, 14:30 and 17:00, 30 cases): 6 falls (a held turn and two tacks catapulted, a gybe catapulted, two boards stuck in irons fell off), every manoeuvre completed. Last night, on the 8 m and 4 m trains, 24 cases, no falls. `.logs/lake_matrix_full.log` (not committed).

**Where the loss comes from** (the steady 18 kt beam reach; flat 25.8 kt): only the 2 m and 1 m trains: 22.8 kt (−12 %; last night's hull: 5.6 kt); only the 8 m and 4 m trains: 21.4 kt (−17 %); all four 18.5 kt (−28 %). With the hull seeing flat water and the fin feeling the whole sea: 25.8 kt, so the fin's part is nothing and the loss is the hull's. On the 8 m and 4 m trains the board pitches ±2.9° (0 on flat water), its planing lift swings ±530 N around 770 N, and its wet area grows on average from 0.57 to 0.81 m², so the friction stays up while the speed drops; the hull's resistance is 203 N at 11.0 m/s against 176 N at 13.3 m/s on flat water. The board crosses the 4 m crests about once a second, the same period as its own pitch near the porpoising boundary (spec 17.12, open item 4), so they excite it. That is the part that PH9 (the sailor's legs in pitch) and the stance address, not the sea.

**A real-world reference.** No controlled measurement of a windsurfer's speed in chop was found; these are what the searches gave (the forum pages refused to open, so the quotes are from the search engine's summaries of them, not checked against the pages):
- An experienced GPS speed sailer ("boardsurfr", seabreeze.com.au forum, "What's needed gear conditions to break 40"): every session over 36 kt was on perfectly flat water; the top speed in mild chop was 35.3 kt, where 38 to 41 kt were easy on flat water: **7 to 14 % less top speed in mild chop, for an expert**. In the same forum: "40 knots is certainly doable in 1ft chop, but flatter will be easier", and going deep downwind in chop "takes big balls and excellent technique".
- Others in "How Fast in Chop?" (seabreeze.com.au) report their top speed in harbour chop as high as or higher than on flat water (32 against 31 kt), which they put down to the fin and the board's set-up.
- Planing boats: the systematic tests in irregular waves are Fridsma (1971, Davidson Laboratory, "A systematic study of the rough-water performance of planing boats", added resistance, heave and pitch and the accelerations); the papers could not be opened here (403). So the planing-hull numbers are **not sourced** in this report.

So: for an expert in mild (about 30 cm) chop the reference is a top speed 7 to 14 % lower. The game's beginner controller in the map's gusty wind loses 18 % of its mean speed on the beam reach and 23 % on the broad reach over ten afternoons, in a steady 18 kt 28 % on the beam reach: more than the reference (which is an expert's top speed, not a beginner's mean), mostly from the 4 m waves and the pitch they excite (above). **Estimate:** a beginner-level sailor losing a fifth to a quarter of the speed in a choppy afternoon is plausible; a third or more, as at 1.5× or in a steady 24 kt, is "a rough day", and falls there are expected.

### Artefacts seen

- **The near water vanished (fixed):** with the dispersion formula in the shader, `tanh` of a large number came out as NaN on this graphics card (it computes tanh from exponentials, which overflow for the 0.5 m train in 47 m of water), and the water round the board was drawn as flat blue. The argument is now held at 10 (tanh(10) = 1 − 4·10⁻⁹). Seen in the first screenshot; the shots in `lake_waves_full/` are after the fix.
- **The board cuts through the short crests:** the picture shows the whole sea, the hull feels the averaged one, so a 1 m crest can be drawn a centimetre or two over the board's tip. That is what a planing board does on real chop; Max should say if it looks wrong.
- From high up: no stripes, seams or arcs on the water.
- Not checked: the look while moving at 60 fps; the race's AI boards in the picture.

### For the lead: may the autopilot be trained on these waves?

What the measurements say, for the lead to decide (the physics is not yet approved by Michiel):
- **The waves at 1× are what the studies give:** the growth law's height and period at every point (by construction), 91 to 98 % of it in the physics where the board sails, no train anywhere near breaking, no artefact left on screen, the same sea on both PCs. Sailing on them: 6 to 23 % slower on the reaches over ten afternoons, no fall in 40 runs in the map's wind, 6 falls in the 30 manoeuvre cases, and one catapult in a steady 24 kt beam reach (after 21 s). **In my view fit for training** (as realistic as the studies allow without a measurement on Silvaplana).
- **At 1.5×** the steepest train is at 65 % of the breaking limit, so the sea is physically possible, but it is a rough day for the hull as it is now: the beam reach loses 43 % over ten afternoons, 3 catapults in 40 runs, and in a steady 24 kt the board catapults within about 20 s. A brain trained there learns to survive waves the lake gives rarely (if at all: the one Swiss lake measurement found the laws too high in light wind, none was found for Silvaplana). **Suggestion (an estimate, not a measurement):** train on 1×, or give 1.5× only to part of the lake races, and wait with 1.5× as the standard until PH9 (the legs in pitch) has answered the pitching on the 4 m waves.
- The lake is 30 % of the races from S4 on (`TrainingDrops`); the open water's drops are unchanged.

## Cost

All on this PC (Ryzen 7 5800X3D), back to back. Tonight the PC was slower than last night for the same code (the flat-water tick 1.8 to 2.4 ms against 1.5; the old waves' 20-board race 46 fps against 88), with other branches' tests, screenshots and release builds running now and then; the comparisons below are each made in one sitting.

**The sea's cost** (`tools/sea_bench.sh --lake=old|2|4`, the editor engine, a board on its beam reach at the start in the map's 14:30 wind, two runs each):

| | The lake's old waves (Lake waves off) | Last night's lake (8 m and 4 m trains) | **The full lake (4 trains, the hull's view)** |
|---|---|---|---|
| A warm sea sample | 6.9 to 7.7 µs | 5.5 to 5.8 µs | **9.6 to 9.7 µs** |
| A board's physics per tick on the waves | 2.71 to 2.98 ms | 2.90 to 2.95 ms | **3.32 to 3.35 ms** |
| The sea's share of it (minus the same board on flat water) | 1.0 ms (one run 0.34: the flat run was slow) | 0.93 to 0.99 ms (last night 0.889) | **1.41 to 1.44 ms** |
| 8 boards side by side on threads, a tick | 9.13 ms | 8.85 ms | **9.91 to 9.95 ms** |

Two speed-ups went in on the way (each train's time term once per substep, the sample's solve written out in place; both give the same answers to the last bit): the warm sample went from 12.2 to 9.6 µs.

**The game: 20 boards on the lake, the release build** (`tools/fleet_measure.sh --sizes=19 --course=t2_slalom --seconds=20`, the settings file choosing the waves; at 3137×1263 the release engine started by hand with `--resolution 3137x1263`; measured once the PC had been quiet for 10 s):

| | The lake's old waves | **The full lake** | Last night (old / two trains) |
|---|---|---|---|
| 1280×720: fps | 46, 44 | **16, 22** | 88 / 88 |
| 1280×720: all boards' physics per tick, side by side | 9.86, 9.95 ms | **10.96, 10.99 ms** | 7.49 / 7.17 ms |
| 1280×720: an AI board's own step, median | 3.27, 3.25 ms | **3.60, 3.60 ms** | 2.43 / 2.29 ms |
| 3137×1263: fps | 23 | **15** | 72 / 75 |
| 3137×1263: physics per frame, the rest of a frame | 16.1, 6.1 ms | **17.2, 4.8 ms** | |

How to read it: the full waves cost 11 % more physics per tick than the old waves (and about 15 % more than last night's two trains, by the bench). The frame rates are not comparable with last night's: tonight the physics of 20 boards took 10 to 11 ms a tick instead of 7, so with the player's board, the rest of the frame and the 60 Hz physics clock both seas ran close to the point where the engine starts doing several physics ticks per frame, and the frame rate drops steeply (the old waves too: 44 to 46 fps, 23 at the wide size). On last night's PC state the full waves would add about 0.8 ms to a tick of 7.5 ms, about 80 fps at 1280×720 (an estimate, not a measurement). **For Max to check on his screen:** the frame rate of a 20-board race on the lake, Lake waves on and off.

If the cost must come down, in order of what it would save (estimates): the rail strips could read the planing strips' water at the same stations (12 of the hull's 48 samples a substep, about a quarter of the sea's cost; a small physics change, Michiel's); the 1 m train could leave the hull's view (a quarter of the trains; it is felt at 0.16 along the board when planing, 0.61 across); a native sea (decision 7 below) would cut it several times.

## Checks

On the branch's final code (the counts are filled in from the last runs, see the commit that adds this report):
- `tools/check.sh`: 431 files, 0 failed.
- `tools/test.sh`: 779 of 779 pass in 80 scripts (run again on the final code) (last night 761; the new `test_lake_waves_full.gd` has 18 tests: all four trains, the dispersion with depth against spec 9.16's example, the lake deep for its trains, a shallow lake slowing its long trains, the seeded phases, the fin's water fading per train against a hand sum, the open sea's fin as before, the hull's averaging over its wet bottom along and across, no footprint = the surface itself, the sim's two views, the open sea's one surface, the command line's and the settings' height multiplier reaching the lake, every train below the breaking steepness at 1.5×, the AI's sea height on the lake, the training's lake races on the lake's waves). `test_lake_waves.gd`'s count of physics trains is now 4.
- `tools/test.sh validation`: 48 tests, 38 pass, 8 fail, 2 pending (46 before, plus the two of the new `test_lake_chop.gd`, which pass: the beam reach keeps 92 % of its flat-water speed in the map's wind and 73 % in a steady 18 kt, without a fall): **the same eight known reds with the same numbers** as last night and Session 71 (the polar sweep's speeds and shape, the top speed 14.67 m/s, the planing onset 7.42 m/s; the fin's side force 745 N; the push warning; the skipper's 12 kt limit 12:21.2; the settled speed on waves at TWA 120, 12.09 against 14.67 m/s). The validation sails the open sea, which this branch leaves bit for bit as it was.
- `tools/lan_test.sh --map=lake --seconds=40`: SYNC CHECK: PASS (0.0000 m between what each PC showed and where the other had it); with `--release=1` after `tools/release.sh build`: PASS; with `--release=1 --lake_wave_scale=1.5`: PASS (both PCs: "crests up to 20 cm").
- Screenshots looked at: the start at 1× and 1.5× (1280×720), the start at 3137×1263, from high above the village, the settings page.

## Michiel's seven decisions (research section 6): taken provisionally, for Michiel to confirm

1. **The growth law:** SPM, as today; CEM stays a switch (`growth_law`). The research found nothing to settle it; Max's eye can.
2. **The fetch:** the 9-ray cosine-weighted fetch (the research's recommendation, 1.2), with the wind averaged along the upwind rays (the Lake Neuchâtel paper's suggestion, 1.7 step 2). As built last night.
3. **The physics cut-off:** 1 m: the 8, 4, 2 and 1 m trains in the physics, the 0.5 m train picture-only. It meets PH10 through the hull's view (spec 9.18 step 1): the surface the strips and the buoyancy see is each train averaged over the wet bottom.
4. **Depth decay of the orbital velocity:** e^(kz) per train, for the fin (spec 9.18 step 2). The strips sit at the surface (2 to 5 cm down: e^(kz) would be 0.88 to 0.73 for the 1 m train, 0.98 to 0.96 for the 8 m), so they take the surface's motion, scaled with the heights in the hull's view; a question for Michiel below. Off for the open water's sea, which stays as it was.
5. **Finite-depth dispersion:** in the wave field and the shader, with one reference depth per lake (the median of its depth grid: 47 m on Silvaplana, deep water for every train). The local depth would refract the crests along the shore and needs the phase along rays: left for stage 4 (SWAN).
6. **The LAN contract:** the same function on both PCs within a millimetre, tests bit-exact on one PC: kept. Both PCs build the same lake from the same inputs and seed; the check shows 0.0000 m between them.
7. **Native code (a GDExtension):** not now. The sea stays GDScript; the cost above is within budget. Revisit only if a measurement asks for it (the research's section 5, last rows).

## Questions for Michiel

1. **The hull's view** (spec 9.18 step 1): the Froude–Krylov average over the wet bottom, applied to the buoyancy grid and to the surface the planing strips see. Is that the PH10 fix you want, or should the strips' planing pressure itself be relieved over the beam for waves shorter than it?
2. **The pitch on the 4 m waves:** the remaining loss is mostly there (−17 % at a steady 18 kt, ±3° of pitch, airborne moments at 24 kt). The board crosses the 4 m crests once a second, at its own pitch period near the porpoising boundary (17.12 item 4). PH9 (the legs in pitch) and the stance are the place for it; do you want that before the lake is the standard on main, or after?
3. **The fin's fade with depth for the open water's sea too** (`WaveField.fades_with_depth`, off there now so the validation's sea runs stay bit for bit)?
4. **Depth decay for the strips' water velocity:** not applied (they are 2 to 5 cm down). Fine?
5. **One reference depth per lake** (47 m) or the local depth with refraction (stage 4)?
6. **The 1.5× sea for the AI training:** acceptable as "a rough day", or should the training stay at 1× until PH9?
7. **The falls:** 6 in the 30 manoeuvre cases on the lake (none last night): the right amount of "harder to sail"?
8. From last night, still open: the growth law (SPM or CEM), the fetch definition, and the waves built once per run for the start's wind.

## Files

- New: `Game/tests/unit/test_lake_waves_full.gd` (18 tests), `Game/tests/validation/test_lake_chop.gd` (2 validation cases), `Documentation/reports/waves/lake_waves_full.md` and `lake_waves_full/` (screenshots).
- Physics (Michiel's): `sim/lake_wave_field.gd` (the hull's view `set_footprint()`, `footprint_factor`, dispersion with depth, `crest_height_at()`), `sim/lake_waves.gd` (seeded phases, the reference depth, the breaking hold, `scale_from_arguments()`, the bands' frequencies with depth), `sim/fetch_map.gd` (`median_depth_m()`), `sim/wave_field.gd` (`angular_frequency()`, `velocity_below()`, `fades_with_depth`), `sim/water_surface.gd` (`velocity_below()`), `sim/fin_model.gd` (the water at the fin's depth), `sim/hull_model.gd` (`wet_footprint_m()`), `sim/windsurfer_sim.gd` (`hull_water`, `_update_hull_footprint()`, `set_waves()` follows `place_waves`, the height multiplier), `sim/config/lake_waves_config.gd` (`physics_trains` 4, `phase_seed`, `reference_depth_m`), `sim/config/wave_set_config.gd` (`place_height_scale`), `sim/config/environment_config.gd` (`lake_waves_for(..., height_scale)`), `maps/silvaplana/lake_waves_silvaplana.tres`; PHYSICS_SPEC.md 9.18, 9.17 step 5 and its values, a tuning-log row.
- Picture: `world/gerstner.gdshaderinc` (`wave_omega()`, `wave_depth_m`), `world/water.gdshader` (one line: the shading's phase uses `wave_omega()`).
- Game: `race/race_observation.gd` (`sea_height` on the lake), `race/race_env.gd` (taken after the board is placed), `race/training_drops.gd` (`lake_sea()`, the lake's races on the lake's waves), `ui/settings_values.gd`, `ui/settings_menu.gd` (*Lake wave height*), `maps/silvaplana/sail_silvaplana.gd` (the console line).
- Tools: `dev/run_lake.gd` (the broad reach cases), `dev/lake_waves_table.gd` (`--check=1`), `dev/pitch_budget.gd`, `dev/scenarios/yaw_debug.gd`, `dev/hull_probe.gd` (the hull's view), `tools/train/train.py` and `tools/lan_test.sh` (`--lake_wave_scale`).
