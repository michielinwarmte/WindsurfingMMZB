# Progress Log

One entry per session, newest first. Sessions 1 to 27 (the Unity version) are in [Legacy/Documentation/PROGRESS_LOG.md](../Legacy/Documentation/PROGRESS_LOG.md).

Template for new entries:

```
## <date> - Session <n>: <topic>
**Phase:** <phase from REBUILD_PLAN.md>
**Done:** what changed, in plain language
**Verified:** which tests/checks/screenshots passed; what could NOT be verified
**Decisions:** anything decided, and why
**Next:** where the next session should pick up
```

---

## 14 October 2026 - Session 38 (map track): Phase M0, tools and data

**Phase:** M0 of the map plan, done on Windows. Branch `feature/map-silvaplana`. Nothing new on `feature/physics-sim` to merge.

**Done:**
- Tools on Max's PC:
  - `tifffile`, `Pillow` and `imagecodecs` (needed for the compressed GeoTIFFs), and QGIS LTR 3.44.14.
  - `tools/common.sh` got `find_blender`, and `tools/blender.sh` runs Blender scripts headless with factory settings.
  - The user variable `BLENDER` is set on this PC.
- Round-trip test:
  - `tools/blender/roundtrip_test.py` builds a test hill and exports `.glb`.
  - `test_map_roundtrip.gd` proves the axes come through (east +X, up +Y, north −Z).
  - `roundtrip_view.tscn` shows it in a screenshot.
- `tools/map/`:
  - `download.py` (STAC v1, SHA-256 checked, in stages),
  - `lake_level.py` (1790.63 m, writes `map_config.tres`),
  - `visible.py` (what you can see from the water),
  - `readers.py`, `silvaplana_area.py`, `build.sh`, `README.md`.
- `MapConfig` (`Game/maps/map_config.gd`) converts LV95 ↔ game, with `test_map_config.gd`.
- Git LFS rules in `Game/maps/.gitattributes` and `Art/.gitattributes`.
- Downloaded 701 MB: heights, lakebed, swissALTIRegio, wind, and 2 m photos of the visible tiles.
- What can be seen:
  - From the water only, about 70 km² at first.
  - Max pointed out that the orbit and replay cameras see more. `visible.py` now looks from the viewpoints in `silvaplana_area.VIEWPOINTS`: the sailor at 2 m, the orbit camera at 60 m, a replay drone at 150 m, and cameras on the shore at 2 m and 50 m.
  - Result: 137 km² in 354 tiles of 1 km (the sailor alone: 76 km²), 90 % within 22 km.
  - The surroundings grew to the west and the north until nothing visible touched the edge.
  - The picture shows the sailor's view in orange and the camera-only land in yellow.
- `build.sh` opens the visibility picture at the end, and keeps a double-clicked window open.
- A Blender preview of the real valley, so the team can see the data (Max asked to see what is being done):
  - `preview_data.py` and `build_preview.py` make `silvaplana_preview.blend`, with the shore band at 5 m with the lakebed, the surroundings at 100 m, and the photos.
  - Four cameras render pictures. The cameras place themselves on the water, or above the ground.
  - It runs as part of `build.sh` (about 1.5 minutes in all).
  - The lakebed's deepest point comes out at 76.8 m, as published.
- BlenderGIS 2.2.10 loads in Blender 4.5, without GDAL or PyProj, which we don't need.
- Found that the game camera draws only up to 3 km (`camera_rig.gd`, `far = 3000`). For the mountains it must go to about 35 km: added to M2.
- 22 of the visible tiles are in Italy, without Swiss aerial photos: added to M2.

**Verified:** `tools/test.sh` 129 of 129, `tools/check.sh` 78 files, the round-trip screenshot (the hill's top under the red marker), and a second `tools/map/build.sh` run that downloads nothing. Not verified: the Linux PC (Blender version, Git LFS, round trip).

**Decisions:**
- Downloads come in stages. The 10 cm photos of the shore band (1.1 GB, for M2) and the surface model (0.34 GB, for M4) wait for the team: the first is over the plan's 1 GB limit, and C: has only 17 GB free.
- `python -I` doesn't see user-installed packages on this PC, so the map scripts run normally from the repo root. Python then only loads code from `tools/map/` and the repo root, never from `.map_data/`.

**Roles** (Max, 14 October 2026):
- Michiel does the physics.
- Max does the map, and later the wind patterns connected to it: the daily cycle, the gusts and shifts, and where the wind is strong or weak. They connect to the physics through `WindField`, agreed with Michiel.
- Updated in the map plan, the physics requests (R5), the rebuild plan and CLAUDE.md.

**Next:** the team looks at `.map_data/work/visible_map.png` and decides on the 10 cm photos. Then M1: `heights.py`, `build_terrain.py` in Blender, and the terrain in Godot. Check the Linux PC when convenient.

---

## 14 October 2026 - Session 37 (map track): Plan for the first map, Lake Silvaplana

**Phase:** side track M (the map), planning only. Branch `feature/map-silvaplana`, started from `feature/physics-sim`.

**Done:**
- Set up Max's Windows PC (Godot 4.7.2 from the official build, SHA-512 checked; the `GODOT` variable for `tools/*.sh`; the godot-tools VS Code extension). Blender 4.5.4 LTS with BlenderGIS was already installed.
- Wrote [MAP_SILVAPLANA_PLAN.md](MAP_SILVAPLANA_PLAN.md): phases M0 to M4, decisions MD1 to MD7, the open data and the tools, plus a "Later" section of physics requests for Michiel (wind simulation, wind-driven waves, mountain-lake physics, live weather, other sailors).
- Wrote [SILVAPLANA_SPOT_NOTES.md](SILVAPLANA_SPOT_NOTES.md): questions for Max's local knowledge of the spot.
- Checked in the STAC API that all the data exists for the area: swissALTI3D, swissALTIRegio (10 m, for the far mountains), SWISSIMAGE, swissSURFACE3D, swissBUILDINGS3D, swissTLM3D, the swissBATHY3D lakebed of Silvaplanersee (survey of 2019), the MeteoSwiss station Segl-Maria (SIA) at the south-west end of the lake (10-minute wind with 1 s and 3 s gusts), and the BAFU lake-level station 2073.
- Wrote [PHYSICS_REQUESTS_FROM_MAP.md](PHYSICS_REQUESTS_FROM_MAP.md) for Michiel: requests R1 to R8 (a map's own air, water and wind; thin air; fresh water; lakebed and running aground; moving gusts; wind waves; replay and live weather; other sailors), with sources, numbers and suggested interfaces. `PHYSICS_SPEC.md` was not touched.
- Measured the Maloja from MeteoSwiss Segl-Maria, 10-minute data of the summers 2020 to 2025 (new script `tools/map/maloja_stats.py`):
  - from 244°, with a median 12 kt mean at the station and 1-second gusts 1.55 times the mean,
  - 61 % of summer days are Maloja days,
  - the air density on Maloja afternoons is 0.98 kg/m³: 20 % below the 1.225 in `WindsurferSim.RHO_AIR` and the autopilot.
  - Worked out the expected lake waves with JONSWAP: about 0.29 m and 6 m long at 20 kt over 3 km.
- Added `/.map_data/` (raw map downloads) to `.gitignore`.
- No code or game files changed. A wave-size experiment was tried and undone at the team's request.

**Verified:** on Windows, `tools/check.sh` (72 files), `tools/test.sh` (122 of 122) and `tools/screenshot.sh` pass on `feature/physics-sim`. `tools/map/maloja_stats.py` run from the repo reproduces the numbers in the requests document. Nothing of the map was built or tested yet. The station's wind speeds were not checked against the wind on the water.

**Decisions:**
- The team's answers (plan, "Team decisions"):
  - only Silvaplana is sailable, and the map is as small as possible: a detailed shore band, plus only what you can see from the water,
  - waves will come from a general wind-wave system later, and until then the current waves stay unchanged,
  - at most 300 MB of map files,
  - one fixed Maloja setting of 12 to 20 knots, with the existing simple gusts and shifts,
  - Michiel makes all physics changes,
  - other sailors on the water come later,
  - Max is the local expert.
- MD1 to MD7: LV95 coordinates straight into the game with the lake surface at Y = 0; Python prepares the data (numpy, tifffile, Pillow; no GDAL); Blender builds the 3D (terrain by a headless script, props by hand) and exports `.glb`, with the `.blend` sources in `Art/`; the game logic reads the grids, never the meshes; the lakebed replaces the flat lake; the map sets its own wind config and never changes `Game/sim/`, the shared configs or the ocean; Michiel's branch is merged into this branch at the start of every map phase.

**Next:** Phase M0: `pip install tifffile pillow`, install QGIS, the Python → Blender → Godot round-trip test, then the download and visibility scripts. Max fills in the spot notes when there is time.

---

## 13 October 2026 - Session 36: Phase 5, waves

**Phase:** 5 done, with the chop limitation below.

**Done:**
- The Gerstner wave field of spec section 9 (`WaveField`, `WaveSetConfig`, `GerstnerWaveConfig`, `waves_default.tres`): the height solve, exact normals, orbital velocity, oriented to the wind; 11 unit tests against the spec's hand-calculated table. The simulation sails on it with `create_default(true)`; the game does.
- The ocean: `water.gdshader` with the same formulas (vertex displacement, analytic normals, Fresnel, lighter crests, foam only at real steepness) and `OceanNode` (a 400 m mesh of 1 m cells following the camera snapped to its grid, a far plane under the fog, the shader clock from the simulation clock). Screenshots show the board on the rendered swell.
- The matrix and the scenario runner take `--waves=1`, `--wave_scale=`, `--waveN.field=`; the scenario runner also `--kick_pitch=`.
- Found and documented why the legacy chop set wrecks the sailing (spec 17.12): slams from the strip theory's curvature term on waves shorter than three hull lengths, taken by a rigid one-body sailor as roll impulses; the hull at Savitsky's porpoising boundary. The default sea is now a swell of 8 cm on 14 m with a little 7 m chop, which the board rides. The fall checks use a 1 s felt push (a jolt is not a fall); the pilot feels the heeling lever over 0.15 s.
- `tools/test.sh validation` has `test_waves.gd`: 60, 90 and 120 degrees on the sea against flat water.

**Verified:**
- `tools/test.sh`: 122 of 122. `tools/test.sh validation`: 20 of 20 (about 70 s). `tools/check.sh`: 72 files. `tools/matrix.sh`: 24 cases clean on flat water; on the sea 22 of 24 (a 12 kt tack and a 24 kt gybe fall).
- On the sea: 90 degrees 10 % slower than flat, 120 degrees 1 %, 60 degrees 32 %; pitch 9 degrees peak to peak; the hull on the surface.
- Not verified: the look of the water beyond two screenshots; the feel of the swell in play.

**Decisions:**
- Steepness is the physical k A: the hull and the fin use the water's velocity, so the trochoid must be consistent.
- Chop waits for the compliant sailor (A-17); the sea ships swell-dominated rather than fake-smooth physics.

**Next:** play-test on the swell; then either the two-body sailor (so the chop can come back) or Phase 6 (rig visuals), the team's choice.

---

## 12 October 2026 - Session 35: Phase 4, the validation suite is green

**Phase:** 4 done.

**Done:**
- `tools/test.sh validation` (about 65 s): the polar sweep of PHYSICS_SPEC.md section 14 at 15 kt on both tacks, with the speed bands, shape rules, top speed, fastest angle, symmetry, upwind VMG, no-go zone, planing onset, acceleration, stability at speed and force sanity read from one sweep; plus the no-fly-off equilibrium, the nose-dive recovery, righting (bare board and balancing sailor) and stopping head to wind. The polar is saved to `Documentation/POLAR_15KT.md`.
- The pilot's course hold has a trim integral (it sailed 10 to 15 degrees wider than asked without one).
- Physics fixed at the source, each from a failed check: form drag of a submerged bow (the deck's immersion at the nose, Cd 0.8); the sailor steps back from the hull's hump speed while the bow is low; the rig's mass leans with the rig; the fore-and-aft balance stands square to gravity; the deck and water under the sail's foot cut the sail's induced drag (end-plate factor 1.4, the lift curve unchanged). Tuning log rows and spec 17.11.
- Three plausibility bounds that were reasoned rather than measured now use the sourced values (planing onset from 14 km/h, beam reach 80 % of the maximum, 135 degrees with 20 %); the note under the shape rules of section 14 says why.
- `tools/simulate.sh` takes `--gradient=0` (the validation wind); a `nose_dive` scenario.

**Verified:**
- `tools/test.sh validation`: 17 of 17. `tools/test.sh`: 111 of 111. `tools/check.sh`: 65 files. `tools/matrix.sh`: 24 cases, 0 falls, 0 NaN.
- The polar: 45 degrees 10.2 kt, 90 degrees 20.0, 120 degrees 24.0, 135 degrees 24.2 (top, 1.62 times the wind), 165 degrees 9.3; both tacks within 0.1 %; planing onset 14.9 km/h.
- Not verified: how it feels; nothing visual changed.

**Decisions:**
- The sail's lift curve stays the measured one; the deck's end plate acts on the induced drag only.
- The validation suite is the regression guard from here: a number leaving its band is a model error to find, never a bound to move (the three sourced bounds above are the exception, recorded in section 14).

**Next:** Phase 5, waves: the Gerstner wave field, its tests, the ocean shader and mesh, and the validation on waves.

---

## 12 October 2026 - Session 34: the manoeuvre matrix, sheeting to the pull, sailing in 24 kt

**Phase:** 3 play-test follow-up (the open items of Session 33); Phase 4 work. Stopped for a play-test.

**Done:**
- A batch harness: `tools/matrix.sh` runs 24 manoeuvre cases (tacks, gybes, a turn on a run, out of irons, straight) at 12, 18 and 24 kt in one Godot process and prints one line per case with falls, NaN, the manoeuvre's timing and how calm the sailing is afterwards; `--pilot.x= --controller.x= --sailor.x= --sail.x=` try other values without editing code (also on `tools/simulate.sh`). This is how the rest of the session was done: one run per hypothesis, a trace only for the one case that needed it.
- The sail is now sheeted to the pull the body can hold (0.9 of the sailor's righting moment, from the sail's curves and the measured heeling lever of sail plus fin) and sheeted in no faster than the body can lean out against it. This replaces the hike integrator, fixes the catapult 4 s into every 24 kt run, and makes 24 kt sailable (depowered, 11.3 m/s on a beam reach).
- The felt heel counted the heel twice; fixed to the exact apparent-gravity angle. That was the 1 Hz sail pumping at every wind. Steady sailing is now steady at 12, 18 and 24 kt.
- Out of irons: the sail stays backed until the bow is 55 degrees off the wind or the board makes 3 m/s (a filled sail on a board without way only rounds it up); no backing without a wanted turn. Works at 12, 18 and 24 kt (2 to 4 s).
- Settling after a manoeuvre only at planing speed, and the gybe's eased sail only through the gybe: the 12 kt gybe keeps its speed.
- The arms' rig tilt range 20 to 30 degrees: the run at 12 kt turns left now.
- Falling to windward counts the sail's pull on the hands in both rules. The rake test of section 3 measures the first two seconds (an unsteered planing board wobbles rail to rail after that; see spec 17.10), and the test pilot now knows the sail and the sailor like the game's pilot.
- Spec 17.10 and the tuning log; this entry; CLAUDE.md lists the matrix tool.

**Verified:**
- `tools/matrix.sh`: 24 cases, 0 falls, 0 NaN, every manoeuvre completed; tacks 6 to 8 s, gybes 5 to 7 s, irons 2 to 4 s at all three winds; straight sailing 7.9 / 10.0 / 11.3 m/s at 12 / 18 / 24 kt with 0 sheet reversals.
- `tools/test.sh`: 111 of 111. `tools/check.sh`: 62 files, 0 failed.
- Not verified: how it feels in the game (no play-test since); nothing visual changed, no screenshot.

**Decisions:**
- Trim by feel, not by integrator: the pilot sheets to the pull the body can hold and in at the pace the body can lean. No state in the trim.
- The felt-gravity reflex stays (gain 1.0): with the felt heel computed right it is steadier than without in every case.
- The rate loop is the yaw damper of a carving board; the open-loop wobble is noted, not hidden.

**Next:** the team plays at a few wind strengths (the wind is in `Game/config/wind_default.tres`, `speed_kt`): tack and gybe with Space, hold A/D, get out of irons by pressing a key, sail a run in light wind. Then waves (Phase 5) or more equipment, adding each to the matrix.

---

## 3 October 2026 - Session 33: tacks, gybes, and a hull that carves

**Phase:** 3 play-tested a third time; Phase 4 work. Stopped at the team's request so they can play-test before more is optimised.

**Done:**
- The play-test said: gybing is a little slow and takes a while to settle; tacking is impossible. Both reproduced in the `player_steer` scenario at 12 and 18 kt and worked on with frame-by-frame traces (`.scratch/trace.py`).
- The hull now knows about heel: the planing strips run across the width, so a banked board carries its lift on the low rail and forward. That gives the righting moment, the sideways force and the turn into the bank that make a real board carve (spec section 5 and 17.9, with a new hull test). Before this a banked board turned away from its bank and gybes could only be spun with the rig.
- The sailor's balance was rebuilt on that: weight on a rail asks for a turn and the reflex banks the board for it (at most 30 degrees, 12 degrees per second); the sailor balances in the apparent gravity of the turn (the measured sideways acceleration of the body, averaged over 0.3 s), and the fall checks use the same felt heel. The balance gains were re-tuned (2.5 and 1.2) to a critically damped loop. The depowering is gradual with an urgent rate near the limits; the player's on-off ease only acts while sheeting by hand.
- The tack is a latched sequence in the pilot that follows the wanted turn: backed across the centreline to take the bow away from the sail (the flip at 25 degrees through and 17 of apparent wind on the new side), backed on its own side to take the bow toward it (after the flip and out of irons), given up when the bow falls back 35 degrees. The arm limit is 350 N and can take the sail down to flapping; the step forward is paced by the nose's depth. The controller rakes fully back whenever the pilot backs.
- Every turn goes through the rate loop (keys 30, tack 15, gybe 30 degrees per second) with the rail sized for the rate and the rig closing the loop; the heading hold uses the rig alone. A gybe keeps the sail eased to 8 degrees of angle of attack until the board has settled; after a manoeuvre the board straightens by itself before the hold takes over. Space tacks up to 100 degrees of true wind angle.
- Stability after a fall: roll added inertia for the hull, a damping cap per point based on that point's own effective mass, an implicit sea anchor, no planing when the bottom does not face the water. No NaN anywhere any more.
- Telemetry and the CSV gained `bow_immersion_m`, `planing_cop_z_m`, `fall_kind`, `wanted_bank_deg`, `felt_push_ms2`, `felt_heel_deg`. The test `test_the_boom_pushed_across_the_centreline` now asks for "luffing or backwinded" (at 5 degrees of apparent wind the sheeted sail is at -7 degrees).

**Verified:**
- `tools/test.sh`: 110 of 111 passing. Failing: `test_beginner_gets_out_of_irons` (D at rest head to wind in 18 kt; the bow hunts at the edge of the 20 degree fill band at 1 m/s). `tools/check.sh`: 61 files, 0 failed.
- Headless scenarios at 18 kt from a 10 m/s beam reach, no falls, no NaN: Space tack through the wind 6.5 s after the key and on the new close reach after 9 s, both tacks mirror images; D held tacks the same way; gybe from a broad reach dead downwind 2.7 s after Space and on the new broad reach after 6.2 s; gybe from a beam reach at 10.5 m/s in 7.1 s; A on a dead run turns left. At 12 kt the tack and the gybe are clean. The steady beam reach at 18 kt is smooth (10.7 m/s, 2.7 degrees of heel, no pumping).
- Not verified: how any of it feels in the game (no play-test since the changes); no screenshot this session (nothing visual changed except the HUD numbers). Advanced mode was not re-tested by hand.

**Known problems left on purpose (the team asked to stop and play-test first):**
1. After the Space tack at 18 kt, on the new close reach at about 6.5 m/s, the hike, the depowering and the heading hold oscillate together (2 s period) and the sailor is catapulted about 10 s after the tack (the `tack_stb_18` run falls at 42 s). The urgent re-powering added last is the first suspect.
2. Out of irons with D at rest in 18 kt fails (above).
3. A full rake step at 10 m/s (advanced mode, `bear_away` scenario) spins the board at 100 degrees per second and the sailor falls; the beginner loop never asks for that, advanced mode has no protection.
4. Everything was tuned at 12 and 18 kt, flat water, one board, one sail.

**Decisions:**
- The rail is for turns, not for holding a course: a planing board carves hard on a few degrees of bank.
- Manoeuvres are rate-controlled like the keys; full helm at planing speed is a spin-out in this physics as on the water.
- Falls and balance use the heel the sailor feels, from the measured acceleration, not from v times the yaw rate.

**Next:** the team plays: tack and gybe with Space at a few wind strengths, hold A/D through the wind, sail close-hauled at 18 kt and see whether the board rocks. Then decide what is worth fixing from the list above before waves, other boards and sails, and other winds add complexity.

---

## 2 October 2026 - Session 32: steering at every speed and on every course

**Phase:** 3 play-tested again; Phase 4 work.

**Done:**
- The play-test said: D turns the board left when planing on starboard tack, and nothing steers dead downwind. Both reproduced headless. The first was the speed-scaled rake of Session 31: at planing speed the rig needs most of its rake just to hold a straight course, so a scaled key command fell below that trim and both keys bore away. The second is physics: rake steers through the sail's side force, which a run does not have.
- The rig's sideways tilt is now a control of its own (the arms, up to 20 degrees on top of where the rig hangs with the lean). `Helm` turns the board the way a sailor does: rig back or forward, rig tilted to the outside of the turn and weight on the inside rail, all together. The beginner's A/D ask for a turn rate (30 degrees per second) and a loop on the measured yaw rate finds the helm, with a trim that settles at whatever the speed and course need; without a key it holds the heading. Space's tack and gybe are one continuous turn. Advanced mode: Q/E rake, Left/Right arrows rig tilt, A/D weight. The autopilot steers with the same helm.
- Spec 17.8 explains it; the tuning log has the rows. Left/Right arrows moved from steering to rig tilt in the input map.

**Verified:**
- `tools/test.sh`: 105/105, with new whole-simulation tests: from rest on either tack the beginner controller sails off and planes by itself, D turns right and A turns left by more than 15 degrees in 3 s while planing, on both tacks, without a fall; on a dead run it holds the course for 25 s and turns either way on command. `tools/check.sh`: 60 files, 0 failed.
- Scenarios: beam reach 34.7 km/h (rake 0.49 instead of 0.8 to hold the course), close-hauled 21.8, broad reach 22.6 from rest; the 24 kt polar from a planing start: 45.3 km/h at 90 degrees, 52.2 at 120, 49.8 at 135, 36.0 at 150. The overpowered scenario still catapults and waterstarts.
- Screenshot `.screenshots/turning.png` with the beginner controller sailing by itself.
- Not verified: how 30 degrees per second feels, the gybe on Space at speed, whether the rig tilt looks right on screen while turning.

**Decisions:**
- Steering is a turn-rate request in beginner mode. The physics is untouched; the loop is the sailor's skill.
- The rig tilt is a sailor's choice, so it is a control, not a function of the lean.

**Next:** the team plays again: steer at low speed, while planing and on a run, on both tacks; tack and gybe with Space; try the arrows in advanced mode. Then Phase 4 proper.

---

## 2 October 2026 - Session 31: first play-test, falls instead of capsizes, downwind speed, low-speed handling

**Phase:** 3 play-tested; the fixes are Phase 4 work (physics corrected at the source).

**Done:**
- The team's play-test said: the whole set capsized when heading up while planing (never happens; the sailor should go over the sail), half wind was faster than downwind (weird), and the board had "grip" at low speed. Each was measured in a scenario, traced to its mechanism and fixed. Spec section 17.7 has the full story with sources; section 16 has one tuning-log row per change.
- Falls: the sailor now goes over when the balance is lost (20 degrees of leeward heel = catapult, 25 degrees of windward heel = fell back). The board is then simulated alone, the rig in the water drags on the mast foot, and after 4 s the sailor waterstarts across the wind. On screen the rig pivots onto the water and the sailor flies over it; the HUD shows a countdown and R waterstarts at once. Why: the mast foot is a joint and feet cannot pull a board up, so a sail cannot roll a board; only a one-body model can.
- Downwind: the pilot and the player's auto-sheet now sheet for the most drive from the sail's own curves instead of a fixed 15 degrees. The polar is run from a planing start (new runner option `--twa2=<deg> --switch=<s>`): at 24 kt the fastest course is 105 to 120 degrees (52 km/h), 135 degrees gives 46 km/h; at 18 kt the beam reach still wins because a 6.5 m2 is marginal for 75 kg in 16 kt at the sail. The sail's lift curve was checked against wind-tunnel measurements of windsurf sails (Zhang et al. 2025, Mok et al. 2023) and kept.
- Low speed: the rounding up from rest is physical (no speed, no fin grip, the sail's centre of effort behind the hull's resistance). Beginner mode now does the sailor's part: auto-sheet on by default (W/S override it for 3 s), a heading hold with the rig when no key is held, speed-sensitive steering (less rake at speed) and an automatic ease when overpowered. Advanced mode keeps the raw controls and the consequences (spin-outs, catapults).
- Numerics: the heave damping is weighted by the wetted area share (a light board alone was undamped) and held to the momentum there is per step (a 9 kg board blew up dead downwind); the sail force is skipped when the board stands on its nose.
- New scenarios: `overpowered`, `bear_away`, `low_speed_turn`; new runner options `--twa2`, `--switch`; `--fall=<s>` for `tools/screenshot.sh`.

**Verified:**
- `tools/test.sh`: 103/103 (new: catapult and waterstart, auto-sheet with override, overpower ease, heading hold on both tacks, speed-sensitive rake, drive-maximising trim). `tools/check.sh`: 59 files, 0 failed.
- Scenarios: `overpowered` (catapult at 23 degrees of heel, the board stops level in a second, waterstart at 4 s), polars at 18 and 24 kt from a planing start, `low_speed_turn`, `bear_away`, dead downwind without NaN.
- Screenshots `.screenshots/fall_mid.png` and `fall.png`: the rig over the water and lying on it, the sailor beyond, the board upright.
- Not verified: how the beginner assists feel in play, whether 20 and 25 degrees are the right fall thresholds in play, the gybe on Space at speed (it may spin out), the planing onset (T2).

**Decisions:**
- Falls are an event in the one-body model (A-17), not a two-body sailor yet. If the team wants to feel the sailor being pulled before a catapult, the two-body sailor is the next step.
- Beginner assists are control, not physics; the physics is identical in both modes.
- The 6.5 m2 sail stays the default; a bigger sail is the team's equipment choice if they want more downwind speed in 18 kt.

**Next:** the team plays again (same checklist, plus: get catapulted on purpose in advanced mode, and bear away from a beam reach at speed in both modes). Then Phase 4 proper: planing onset (T2), steering with the sheet eased (T7), and the polar against GPS data if the team has any.

---

## 2 October 2026 - Session 30: Phase 2 (the headless simulation) and Phase 3 (the playable prototype)

**Phase:** 2 and 3, both done. Same day as Session 29, after the team asked for simulated physics instead of tuned limits (decision D8) and a playable demo.

**Done:**
- Built the whole simulation in `Game/sim/` (14 scripts, no Nodes): a rigid body with its own integrator, the mass model, buoyancy on a grid with a real rocker line, the hull (friction, wave hump, sideways drag, planing lift), the fin, the sail, the wind, the water, the sailor and the `WindsurferSim` that combines them; six config resources in `Game/config/`; 92 unit tests in 11 files; a headless scenario tool `tools/simulate.sh` that writes CSV telemetry; and an autopilot that plays the sailor in tests and scenarios.
- Every number comes from real equipment or real physics; nothing is capped to hit a target. The spec's new section 17 explains each choice; section 16 (the tuning log) has one row per change.
- The hard part was planing. The spec's Savitsky lift at one point made the board porpoise (bounce in pitch), and the sailor's reflexes were hiding it. Holding the sailor still in a scenario showed the board pitching to 24 degrees and capsizing on its own. The fix was physics, not a damper: the planing lift is now computed strip by strip with the slender-body theory of planing, which contains the pitch damping that the water gives a planing hull, matched to Savitsky's measured lift. Section 17.2 of the spec tells the story.
- Along the way, several real effects that were missing were added: the rig leaned to windward with the sailor, the sailor hanging back against the sail's pull, the sailor's legs as a suspension, the sailor's windage, the water's added mass in heave and pitch, flat-plate drag of the fin at large slip, a freeride rocker line, and a planing beam that follows the board's taper.
- Numbers (18 kt at 10 m, 16 kt at the sail): beam reach 35.9 km/h (19.4 kt), close-hauled 22.7 km/h at 52 degrees to the wind with 6.6 kt of upwind VMG, broad reach 21.6 km/h; steady, identical on both tacks; the board rounds up and stops when nobody steers; at rest it displaces 89.8 L and floats level.
- Phase 3, the playable prototype: an input map in `project.godot` (W/S sheet, A/D steer, Q/E rake, Space tack or gybe, T auto-sheet, Tab mode, 1 to 4 cameras, R reset, Esc pause, F1 panel); `windsurfer/windsurfer.tscn`, a node that owns the simulation, steps it every physics tick and copies the state onto simple shapes (a box board with an orange nose, a fin, a mast, a sail that turns with the sheet, the rake and the rig lean, a boom, and a capsule for the sailor that leans and steps back as the simulated sailor does); `windsurfer/player_controller.gd` with a beginner mode (A/D turn left and right on the screen on either tack, automatic balance) and an advanced mode (Q/E rake, A/D weight), both with W/S sheeting, an optional auto-sheet and a tack or gybe on Space; `camera/camera_rig.gd` with follow, orbit (right mouse button to turn, wheel to zoom), top-down (bow up) and free (spectator) cameras on the board's interpolated transform; `ui/hud.gd` with a one-line strip, a detail panel (F1), a wind rose and the key help; `world/water.gdshader`, a flat sea with a 5 m grid so that speed shows; `main.tscn` and `main.gd` that tie it together, with `--camera=`, `--autopilot=1` and `--hud=0` options for screenshots. The old FBX models stay in `assets/models/` for Phase 6; the prototype uses plain shapes.

**Verified:**
- `tools/test.sh`: 92/92 pass in about 8 s. `tools/check.sh`: 50 files, 0 failed.
- Scenarios `beam_reach`, `close_hauled`, `broad_reach` on both tacks, `fixed_controls`, and `beam_reach --freeze=40` (sailor held still fore and aft): all steady.
- Phase 3: `tools/test.sh` 97/97 (five new controller tests: sheet pace, screen-relative steering on both tacks, advanced mode, tack and gybe on Space, a stuck manoeuvre is abandoned); `tools/check.sh` 56 files, 0 failed; screenshots of all four cameras with the autopilot sailing (`tools/screenshot.sh res://main.tscn .screenshots/cam1.png 360 --camera=1 --autopilot=1`, and 2 to 4), looked at and corrected (help line cut off, free camera starting inside the board).
- Not verified: how it feels to sail with the keys (nobody has played it yet; the autopilot sailed for the screenshots), whether the tack and gybe on Space carry the board through the wind in play, the planing-onset speed (check T2), steering with the sheet eased (part of T7), and anything on waves.

**Decisions:**
- The sailor's reflexes (balance, hang-back, legs, pitch reflex) live in the simulation and stay on in every control mode; the player gives intentions. A windsurfer cannot be balanced by someone holding still (spec 17.3).
- The planing model is the strip model of spec 17.2; the point model of section 5 is superseded.
- Added mass, legs and the other additions are physics the spec had left out, not tuning; recorded in the tuning log with their sources.

**Next:** the team play-tests the prototype (checklist in the plan, Phase 3). Then Phase 4, validation and physics fixes at the source, starting with what the play-test turns up and with checks T2 and T7.

---

## 2 October 2026 - Session 29: Physics spec from the Unity version

**Phase:** 1, done. Started on 28 September 2026, finished on 2 October after the session's token limit interrupted the first attempt.

**Done:**
- Wrote [PHYSICS_SPEC.md](PHYSICS_SPEC.md) (about 5,800 lines, 17 sections): conventions and notation; apparent wind; sail; rake steering and the stabilisers around it; fin; hull drag, displacement lift and Savitsky planing; buoyancy and water damping; mass, inertia and the sailor's centre of mass; wind; Gerstner waves; controls; the master table of every tuning value; a register of 36 stabilisers and fudges (`F-01` to `F-36`); the legacy contradictions and their resolution; the default configuration and the Phase 4 validation targets; the open questions; an empty tuning log.
- How it was made: the first attempt fanned the work out to 16 extraction agents with three reviewers each. That exhausted the 5-hour session limit in about ten minutes, so none of the reviewers ran, and the scratch folder with the drafts was wiped before the next session. Nine drafts were recovered from the agents' Write calls and five more from Bash heredocs in their transcripts; the fudge register, the open questions, the tuning log and the header were written by hand. Every section was then read and corrected by hand against the legacy code.
- What the spec found that the plan did not know (header of the spec, "Six things"): the Unity scene file holds the values that ran, and the Session 22 numbers survived to the last played Session 26 scene, so the documented tuning (0.85 lift cap, 4000 damping, Savitsky) was never played; the played planing lift was a speed ramp capped at 6 % of the weight; the body weighed 94 kg while the hull's caps used 91 kg; the sail force acted at the board origin; the sail side came from the Space key, not the wind; the legacy TWA had the opposite sign of the legacy AWA; the validated runs were on flat water in 15 kt (22 kt in the Session 26 commit) with the wind sampled at the board origin.
- Corrected the plan's own fudge list (the "150 × rake" and "0.3 between 15 and 25 kt" figures came from older docs) with a note in the plan, ticked the Phase 1 boxes and set Phase 2 to Next.

**Verified:**
- `tools/test.sh`: 10/10 unit tests pass. `tools/check.sh`: 6 files, 0 failed. Nothing under `Game/` changed this session.
- Read and cross-checked by hand: SailingState, Aerodynamics, AdvancedSail, AdvancedHullDrag, AdvancedBuoyancy, AdvancedFin, Hydrodynamics, BoardMassConfiguration, AdvancedWindsurferController, WindSystem, GerstnerWave, WaterSurface, PhysicsConstants, the setup wizard and the project settings. The inconsistencies found between sections were fixed: the default wind (15 kt from 270°, not the wizard's 12 kt from 45°), the mass arithmetic (8 + 6 + 80 = 94), wrong section numbers, and which section owns the default configuration (section 14).
- Not verified: the automated three-lens reviews (source fidelity, sign conventions, physics) did not run. Line references inside the sections were produced from the files by the agents and were spot-checked, not re-verified one by one. The real-equipment numbers in section 14 come from web pages read on 28 September and were not re-checked. Nothing about how the game feels can be known until Phase 3.

**Decisions:**
- Section 14 owns the default configuration: 120 L board of 2.40 × 0.72 × 0.12 m and 9 kg; 6.5 m² sail with a 4.60 m luff and 1.95 m boom; 38 cm fin of 0.0365 m²; sailor 75 kg, rig 8 kg, total 92 kg; tests in 15 kt from the West on flat water. Open for the team (question 3). The worked examples in the model sections keep the legacy configuration (2.5 × 0.6 m, 91 or 94 kg) because that is what the legacy code was checked against.
- Phase 2 keeps a speed-based planing ratio as a model input (section 5 F4); planing onset is measured as the speed at which dynamic lift carries half the weight (section 14). The planing lift gets one hard cap at exactly the weight and no tunable fraction.
- Every fudge has an ID; config comments and the tuning log cite it, so nothing is re-added by reflex.
- Process: do not run large multi-agent workflows in this project; they exhaust the session limit. Work solo, or with one or two agents at most.

**Next:** Phase 1 Stop. The team answers the seven questions in PHYSICS_SPEC.md section 15 (top speed, fastest point of sail, default equipment, control modes, what Space does, the wind reference height, how fast full rake should turn). Then Phase 2 starts from sections 0, 14 and 11 and the owning sections, in the plan's order: config resources, integrator, environment interfaces, buoyancy, hull drag and planing, fin, sail and apparent wind, rake steering, sailor mass and centre of mass.

---

## 28 September 2026 - Session 28: Switch to Godot, preparation

**Phase:** 0 (preparation), done.

**Done:**
- The team decided to restart from scratch in Godot 4.7 instead of continuing in Unity. The main reason is better AI support: an AI session can now run the tests, check every file and look at screenshots itself. Before, Session 27 had to be written without ever running Unity.
- Moved the whole Unity project, the old docs, README and CONTRIBUTING into `Legacy/` with `git mv`, so their history is kept. The Unity `.gitignore` moved into `Legacy/WindsurfingGame/`. `Legacy/README.md` now starts with a banner explaining what is useful there and which legacy tables are wrong.
- Installed Godot 4.7.2 (official build, SHA-512 checked) in `~/.local/opt/godot/4.7.2-stable/`, with `~/.local/bin/godot` and an app-menu entry. No sudo needed. `tools/install_godot.sh` does this again for anyone on Linux.
- Created the Godot project in `Game/`:
  - Forward+ renderer, 1280×720 window, physics interpolation on
  - untyped GDScript declarations are errors
  - GUT 9.7.1 test framework
  - `DevCapture` autoload for screenshots
  - placeholder `main.tscn` with sky, sun, a water plane, and the old board and sail models (copied from Unity)
  - its own icon
- Tools in `tools/`: `install_godot.sh`, `godot.sh`, `test.sh`, `check.sh`, `screenshot.sh`, `api_docs.sh`, `play.sh`, `edit.sh`, all sharing `common.sh`.
- First tests: `tests/unit/test_engine_conventions.gd` (Godot's axes and angle signs that our physics conventions depend on) and `tests/unit/test_project_setup.gd` (version, typing rule, physics interpolation, main scene). A pending placeholder sits in `tests/validation/`.
- VS Code: installed the godot-tools extension (2.7.1) and set its Godot path in the user settings.
- Wrote `CLAUDE.md`, `README.md`, `Documentation/REBUILD_PLAN.md` and this log.

**Verified:**
- `tools/test.sh`: 10/10 unit tests pass. `tools/test.sh all`: 10 pass, 1 pending (the validation placeholder).
- `tools/check.sh`: every file loads. It was also confirmed to fail on a deliberately broken script and on an untyped variable, and `tools/test.sh` was confirmed to fail on a deliberately failing test. The probe files were deleted afterwards.
- `tools/screenshot.sh`: the placeholder scene renders on the RTX 3080 Ti (Vulkan, Wayland session): sky, water, sail and boom visible. The image was checked.
- Not verified: opening the editor by hand (`tools/edit.sh`) and the GUT editor panel. Everything was driven from the command line.

**Decisions:** see "Key decisions" D1 to D7 in the plan. The biggest one: we write our own rigid-body simulation in plain GDScript (D2), so the physics can be tested headless and fast.

**Found along the way:**
- Legacy `PHYSICS_VALIDATION.md` has port and starboard swapped in its AWA and sail-side tables, and says "rake back = bear away". The Unity code (correctly) uses AWA > 0 for wind from starboard and makes rake back head up.
- `board.fbx` points along X, contains a stray camera and refers to a missing Starboard product photo. `sail.fbx` has a mast without faces and refers to a missing Severne graphic. Details are in the Phase 6 notes of the plan.
- The repository has no LICENSE file, although the old README said MIT.

**Next:** Phase 1, writing `Documentation/PHYSICS_SPEC.md` from the legacy physics code and docs.
