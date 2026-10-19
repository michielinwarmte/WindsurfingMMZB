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

## 19 October 2026 - Session 50: Phase 9 planned (racing, scripted and learned skippers)
**Phase:** 9, planning only. Nothing built.
**Done:** Max asked for a full plan for Phase 9: races with AI opponents, opponents that differ from each other, and one or two courses to train neural-network skippers on by reinforcement learning. Written as [RACING_PLAN.md](RACING_PLAN.md): four parts (9A the race alone, 9B scripted skippers with character sheets, 9C the learning harness with a Godot-to-Python bridge and PPO, 9D learned skippers in the game), the two courses (T1, a windward-leeward loop on open water at 30 % of the class's size; T2, the iQFOiL sprint slalom on Lake Silvaplana placed by Max in the course maker), the rounding geometry, the observation, the actions and the reward of the learned skipper, the curriculum, the personalities, an execution brief in the shape of U1's, and the stop rules. The rebuild plan's Phase 9 section and status row point at it.
**Verified:** the simulation's headless speed, measured for the compute budget: Godot starts in 4.6 s, one board runs 10 times faster than real time (about 610 ticks per second per process; `tools/simulate.sh beam_reach` at 5, 60 and 300 s). Python 3.12.9 and numpy are on Max's laptop; torch and Stable-Baselines3 are not yet. Not verified: the estimate of 7,000 ticks per second with 12 processes (9C.1 measures it).
**Decisions:** RD1 to RD8 in the plan, the main ones: the AI sails through the player's controller with no hidden help; scripted skippers before learned ones; PPO in Python over our own small bridge, with neuroevolution in Godot as the fallback; a brain is a built artefact with a parity test; 9A and 9B on `feature/p9-racing` from `main` now, training after U1 and U2 are merged; two small physics hooks for Michiel (one shared wind step, a contact force).
**Next:** the team reads the plan; Max places and saves `t2_slalom` in the course maker; on the go-ahead the lead makes the branch and P9_PROGRESS.md and launches 9A's `race_core` and `course_on_water` agents.

## 19 October 2026 - Session 49: U2, the fin bends; the cause of the long wet part found and fixed; the sailor's technique
**Phase:** Play-test upgrades, U2 (branch `feature/u2-fin`, on top of U1's branch). Fable 5.1 led; Opus 5.5 agents built; the lead designed the physics and reviewed every diff.
**Done:** (1) The fin bends as a cantilever beam (`fin_model.gd`: EI = S c^4, S from a measured flex test of a 37 cm carbon slalom fin, IST Lisbon 2017; an elliptic load; the bent fin's force tilts up toward the deck on both tacks: about 80 N up on the planing reaches, 150 N with a 44 cm fin). (2) **The cause of the long wet part:** the heeled hull lost 80 % of its lift at 4.5 deg of heel where NACA TN 4187's rolled plate loses a third, because Wagner's climb was applied to the vee at the spray root but not across the heeled strips; fixed in `hull_model.gd` `_wet_width` (each section's depth flattened by 2/pi about its deepest point), the camber sign corrected, the sailor's feet holding the wanted heel against the fin's roll. (3) The sailor's technique from a map of bank x trim against steadiness: bank 2 deg (was 4.5), trim 2.0 deg up to 24 kn falling to 1.5 deg by 26 kn (calibrated on this hull, labelled; the fast end set for the game's gusty wind); the flattening off the wind built but off (the hull bounces flat at 32 kn). (4) The fin mesh bends in the game (`fin_bend.gdshader`), the HUD shows the fin's load, bend and upward push, the F3 force view has an arrow for the fin's upward push. Also: `--fin.<field>=` overrides, fin columns in the reach check, the probe `Game/dev/hull_probe.gd`, Savitsky's critical trim reported (it does not describe this hull: extrapolated below its chart), 78 experiments on riding the fin, the mast track 10 cm aft tested (faster and freer in steady wind, livelier in gusts; not kept: a setup choice for the team).
**Verified:** On the branch (5f8ef4b): `tools/check.sh` 196 files, 0 failed; `tools/test.sh` 360 of 360; `tools/test.sh validation` 30 pass, 2 pending (U1's wet-area targets), 1 fail (the onset, 13.4 kn, red on Michiel's decision); the reach check 9 of 9 steady, the wet front on the planing reaches 1.42, 1.35, 1.35, 1.59 m (U1's end: 1.76, 1.42, 1.71, 1.71), 2 to 5 % faster; the polar inside its ranges; the gusty default wind at 12, 18 and 24 kt: no fall in 60 s. Max played it: "feels quite nice now". Not verified: manoeuvres (none run in U1 or U2), the 44 cm fin's look.
**Decisions:** Max: U2 go; the sailor rides the fin; keep going until the cause and the solution are found (done); the day ends here, other things get built next. Open for the team: Michiel's review of the U2 physics (the questions in U2_PROGRESS.md); the rail on a beam reach (Max); the fin's size and the mast track as player settings; U1's wet-area targets (0.6 to 1.0 m against 1.35 to 1.59: the map says 1.0 m is reachable flat at 18 kt, but the 32 kn broad reach needs heel and a low trim, which may be the 1 deg vee's limit); the onset band; the hands' share of the boom force; the manoeuvre matrix before the pull requests (U1 first, then U2).

## 19 October 2026 - Session 48: U1 rounds 2 to 4, all agents merged, Stop 3
**Phase:** Play-test upgrades, U1 (branch `feature/u1-planing-wet-area`)
**Done:** Stop 1 and Stop 2 passed with the team's decisions (in the brief). Agent 4: a 1° tail vee with the spray root across a sinking bottom fixes the porpoising with no new constant (9 of 9 reach cases steady); the flat tail is back; the grid stays at 7 rows; a planing bottom's smaller buoyancy is built as `planing_buoyancy_factor` but off; the sailor's 45° stance, the hang-back measured from the feet, and the feet's trim (32 N·m bow-up instead of 117 N·m bow-down); `running_trim_deg` 2 → 1.5. Agent 5: the helm's rake-first course hold (now on by default; the rig leans 23°), the fin-loading bank (4.5°, an estimate), the railing-out test (21° holds, 24° rails out), the final validation, the polar and the before-and-after screenshots. On the 18 kt beam reach the harness went from 947 to 683 N, the rig's share from 91 to 63 %, the mast foot from 679 to 352 N.
**Verified:** On the merged branch: `tools/check.sh` 192 files, 0 failed; `tools/test.sh` 343 of 343; `tools/test.sh validation` 26 pass, 2 pending, 1 fail (the planing onset, 11.6 kn against 8 to 10 kn, left red on Michiel's decision not to move the band); the reach check 9 of 9 steady; the polar at 15 kt inside every range; the straight runs 2 to 6 % slower. Not verified: any manoeuvre (none run in U1), and how it feels: Max's first play-test says "a little better", the push on the fin isn't felt (U2).
**Decisions:** U1 is finished as it stands (Max, option b): targets 3 to 5 stay pending (the wet front 1.65 to 1.75 m, the push 1.1 m, the harness 683 N), because hooked in the line carries the whole boom force and the drive's couple holds the push forward. Follow-ups: the hands' share of the boom force (Max's estimate, if Michiel agrees), spray drag, U2. The team runs the manoeuvre matrix before the pull request.

## 19 October 2026 - Session 47: U1 led by Fable, agents 1 to 3 in, stopped at Stop 1
**Phase:** Play-test upgrades, U1 (branch `feature/u1-planing-wet-area`)
**Done:** The lead launched agents 1 (`measure`), 2 (`sources`) and 3 (`porpoising`), Opus 5.5 at extra-high effort in their own worktrees, and merged all three. New: `tools/reach_check.sh` (9 reach cases, one line each), the pending validation check `test_planing_wet_area.gd`, the friction area, wet front and push centre in telemetry and the HUD, the baseline in U1_PROGRESS.md, the four sourced numbers in PHYSICS_SPEC.md section 14, and agent 3's diagnosis: the 1.8 Hz bounce is plain porpoising past Savitsky's critical trim. U1.4, the flat tail, was built and reverted (two buoyancy unit tests outside agent 1's files, and the 18 kt broad reach went bow-down).
**Verified:** On the merged branch: `tools/check.sh` 190 files, 0 failed; `tools/test.sh` all passed; `tools/test.sh validation` no failures, 3 pending (the new check's targets, by design). Not verified: how anything feels to sail; nothing in the game's behaviour changed except the HUD and telemetry.
**Decisions:** Stopped at Stop 1 for the team, because stop rules fired: targets 2 and 4 conflict for a flat bottom (Savitsky), the baseline already misses target 2 in 5 of 9 cases, the grid check moves the wet front by 34 cm, and the flat tail needs files outside agent 1's list. The four decisions are in U1_PROGRESS.md's Next action. Agent 4 is not launched. Also open: Max's own estimate of the flat-water rail-down angle (agent 2 found no source).

## 19 October 2026 - Session 46: play-test feedback, the wet area when planing (U1 planned)

**Phase:** documentation, after the merge of Sessions 38 and 39 to `main`. Max's first play-test of the merged game: "playable and feels quite ok". From now on feedback is researched and planned first, and built later.

**Done:**
- The repository cloned to a new Windows PC (Max's) and Godot 4.7.2 installed there (`GODOT` set as a user variable). Blender 4.5, the map's Python packages (`tifffile`, `Pillow`, `imagecodecs`) and `.map_data/` are not on this PC yet.
- W3's "the day" (start front, day types) moved to Later, L1, by Max: the lake sails well in the average day, and gameplay comes first (MAP_SILVAPLANA_PLAN.md).
- New [PLAYTEST_UPGRADES.md](PLAYTEST_UPGRADES.md), one place for every piece of play-test feedback, linked from the rebuild plan. **U1, planing on a smaller wet area**, researched and planned. Max felt the board is wet much further forward than a real one (from the front foot back). Measured on a steady 18 kt beam reach: the board is wet for 1.87 m from the tail at 0.93° of trim, and the friction is 223 N against a sail drive of 319 N. Real boards are wet for 0.6 to 1.0 m (Sutherland 1993, Gourlay & Martellotta 2011, shapers). The cause is the load path: the harness line carries 945 N (measured on a real sailor with a 6.5 m² sail: 415 N), the rig carries 91 % of the sailor's weight to the mast foot 1.30 m from the tail, and the water must push there. The 1 cm tail kick takes about 1° of trim from a short wet part. The fin alone is not the cause. Max's technique on flat water (almost all the weight on the back strap, the nose lifted by loading the fin and pulling up with the front foot) is the opposite of what the game's sailor does: it hangs in the harness, doesn't lean back (`hang_back_m` 0), presses the bow down with the feet (−120 N·m) and holds the board flat. The plan now gives the sailor that technique (U1.3, U1.6). Six what-if runs with command-line overrides: less mast-foot load gives a shorter wet part and 2 kt more speed, but the board then porpoises at 1.78 Hz, the yaw wag of Session 39. The plan has eight steps (U1.1 to U1.8), targets, risks and sources.

**Verified:** `tools/check.sh` 188 files, 0 failed, and `tools/test.sh` 335 of 335 on the fresh clone. No code changed this session. The what-if CSVs are in `.sim_output/wet/` (not in git). NOT verified: the real-world wet length and trim are theory and statements from shapers and experienced sailors; no measurement was found.

- Later the same day, Max's answers went into the plan:
  - Porpoising is not the same as riding over waves (U1.5).
  - "Loading the fin" is both pushing on the rail and tipping the leeward rail down a little (U1.6).
  - Fins bend, and a 44 cm fin can almost lift the kit out of the water. That became its own upgrade, **U2**, with a first estimate.
- **U1 is ready to build.** It has an execution brief for a lead engineer with sub-agents:
  - the go-ahead and the branch;
  - the project's rules and the Windows PC's pitfalls;
  - exact definitions of every measurement (the "standard run");
  - the baseline that must not get worse, and the targets in priority order;
  - when to stop and report;
  - the numbers still needing a source;
  - the scope;
  - step 0, step 1 (the flat tail), three parallel work packages (measure, sources, porpoising diagnosis), one agent for the coupled physics, then validation and screenshots;
  - three stops: the lead's check, Michiel's review, Max's play-test.
- Then set up for the build Max wants:
  - **The team:** Fable 5.1 as the head developer, leading at most 5 Opus 5.5 sub-agents at extra-high effort, 3 at a time, each in its own worktree on a `u1/<name>` branch. Agent 1 measures, 2 finds sources, 3 diagnoses the porpoising, 4 does the coupled physics, 5 finishes.
  - **Testing on reaches only:** 60°, 100° and 135° at 12, 18 and 24 kt (the "reach check"), plus the straight runs of the matrices. No manoeuvres; the team runs the full matrix before the pull request to `main`.
  - **Token rules**, and a handoff that survives the lead running out: the new [U1_PROGRESS.md](U1_PROGRESS.md) holds the state, the next action, and the start and take-over prompts. The agents commit their reports on their branches.
  - `.gitignore` now ignores the agents' worktrees (`/.claude/worktrees/`).

**Decisions:**
- Documentation mode (Max): play-test feedback becomes a researched plan in PLAYTEST_UPGRADES.md; building comes later.
- **Michiel gave the go-ahead to build U1** (19 October 2026, told to Max), on a git branch: `feature/u1-planing-wet-area`, made from `main` at 561849c. The documents of this session are committed there, not on `main`.
- Not in U1: the fin's bending and size (U2), and a player control for the trim (a team decision, later).

**Next:**
1. Build U1 on `feature/u1-planing-wet-area`, following its execution brief, starting with step 0.
2. Michiel, when it suits him: the planing-onset band still open from Session 39. U1 keeps it as it is and reports where the onset moves.
3. Max: more play-test feedback, each as an upgrade (U3, ...).
4. The open items of Session 39 stand; its item 2 (the porpoising) is now step U1.5.

---

## 16 October 2026 - Session 39: waves by group, Phase 7 and 8, sailing on Silvaplana, the board's shape and the map's wind

**Phase:** 7 (environment and effects) and 8 (audio) built; the map's M3 (sailing on the lake) and W5 (the map's wind in the physics); the waves restructured; the board's shape in the physics. Branch `feature/visuals-and-ui` (on top of Session 38, nothing merged to `main` yet). Michiel's jobs after Session 38's play-test: the sail flutters too much (only without load), the figure's core looked wonky, sail Silvaplana instead of only flying over it and test the physics in the map's wind; then separate the chop from the swell, finish Phase 7 together with the map's work, Phase 8, document everything, and improve the physics with the board's shape. Seven sub-agents (Opus) on their own git worktrees and branches, merged here; the seams fixed by hand are listed under "Merged".

**Done:**
- **The sail flutters only without load** (`rig_visuals.gd`): the flutter follows the pressure in the sail, the lift and drag coefficient together, not the angle of attack. A powered sail (load above 0.55) is still; near luffing a ripple runs just behind the mast; only a sail with no load (below 0.1) flaps all over, with smaller waves (0.03 m at the luff, 0.06 m per metre of chord at the leech) at a speed that follows the apparent wind (0.3 Hz per m/s, a flag's constant Strouhal number; Virot et al. 2013). Measured with `tools/simulate.sh sail_flutter`: the powered beam reach at 18 kt reads flutter 0 every second, the sheeted-out run 1.0.
- **The figure's core is one body** (`figure_skeleton.gd`, `sailor_figure.gd`): three tapered pieces (belly, ribs, chest) on one smooth spine curve from the pelvis to the shoulders, twisting gradually from the hip line to the shoulder line, a shoulder bar, the harness as a belt on the pelvis. Bone lengths and the tests unchanged; a new test checks the pieces meet on the curve without a sharp turn.
- **The waves in two groups** (spec 9.15 and 9.16): each wave is swell or chop (`group` in the `.tres`). The swell follows the wind (`swell_offset_deg`) or comes from a fixed compass bearing (`swell_from_deg`, `swell_relative_to_wind` off); the chop follows the wind with `chop_offset_deg`; `align_to_wind` is gone. The default sea is the same four waves as before (a test pins them), so the validation's sea numbers did not move (90° -1.2 %, 120° +0.3 %, 60° -0.5 % against flat water). New `WindWaves` (`Game/sim/wind_waves.gd`) turns wind speed, fetch and depth into lake chop: the JONSWAP fetch relations in the Shore Protection Manual's form (Hasselmann et al. 1973; SPM 1984), the height capped at 0.6 times the depth (Coastal Engineering Manual 2002), the length from the dispersion relation with depth, the peak wave plus a shorter one at 1.5 times the frequency with a third of the amplitude turned 30° (Mitsuyasu 1975), steepness the physical kA capped at π/7. It matches the Silvaplana table of request R6 within 5 %. The Waves tab gained the swell's source and bearing, the swell height, the chop direction, and a "From the wind" preset with fetch (0.2 to 20 km) and depth. Open: in shallow water the waves have the right length but travel at the deep-water speed (a depth term in spec 9.1 and the shader).
- **Phase 7, with the map's look** (R9 answered with option 1): `Game/world/water.gdshader` has the waves and Max's see-through lake look (depth-based colour and transparency, refraction, Fresnel, ripples that tilt the wave normal and drift downwind), with a parameter set per scene (`Game/world/sea_water.tres`, `Game/maps/silvaplana/lake_water.tres`); the wave formulas moved into `Game/world/gerstner.gdshaderinc`, shared with the foam wake so it rides on the waves. `OceanNode` gained `look`, `render_layers`, `far_area_xz` (keeps a lake's far water inside its shore band) and `set_water_parameter()`; the water no longer casts shadows. The open sea got the map's sky and its 15:00 summer sun and a 20 km haze. New effects (`Game/windsurfer/effects.gd`, `Game/world/effects/`): spray off the rails at the spray root, more off the leeward and the low rail, growing with speed and planing; a foam wake that fades in 7 s; a splash on a hard landing (the water's support jumping by 2.5 times the weight within 0.2 s) and on a fall; a red streamer at the masthead; an orange wind flag on a buoy near the start; the Phase 6 force view on F3 (or `--forces=1`) with a legend. Islands are covered by the real lake and not built. Cost: about 0.04 ms of CPU per frame; the GPU time stayed under 1 ms per frame (165 fps, the display's cap, before and after).
- **Phase 8, the sound** (`Game/audio/`): every sound is made from seeded noise at startup (wind, hiss, whistle, lapping, rumble, flutter loops; splash, crack and swoosh one-shots), played through Wind, Water and Sail buses with filter sub-buses (`Game/default_bus_layout.tres`). `SoundMix` turns the telemetry into levels: the wind grows 12 dB per doubling of the apparent wind (wind noise at a cyclist's ears rises about 13.6 dB per doubling) with a whistle above 16 kt; lapping and rumble cross over to the planing hiss with the planing ratio smoothed over 0.7 s; the sail flaps inside its 5° luff zone, cracks when it fills and swooshes when the rig changes sides in a tack; splashes on slams of 1 m/s or more, a nose digging in, a fall and the water start; silent from the sail while the sailor is in the water; 8 dB quieter behind the start menu. The tuning numbers are in `Game/config/sound_mix_default.tres`; Wind, Water and Sail sliders joined the master on the Audio tab. `res://audio/print_levels.tscn` measures the real output of each bus over an autopilot run (slow: the water louder than the wind; planing: the wind loudest, the hiss above the lapping). Nobody has listened yet.
- **Sailing on Lake Silvaplana** (map plan M3): "Sail on Lake Silvaplana" in the start menu (second option; the fly-over is the fourth) or `tools/play.sh lake`. `sail_silvaplana.tscn` extends the sailing scene: the map's terrain, sky, sun and reflection probe, the start 40 m off the camping beach (LV95 2780880 / 1147510, 23 m of water) heading 132°, a beam reach over the widest part of the lake (the other beam reach hits the beach after 30 m). The lake's own wind file (`wind_silvaplana.tres`: 16 kt from 222°, gusts 0.25, shifts 10° over 60 s) until the map's wind model is connected (below); the settings' waves and sailing options apply. The shore stop of MD6: every tick the depth under the board is read from the 2 m grid (`shore_check.gd`); shallower than the fin plus 12 cm, or off the grid, the simulation freezes, the HUD says "Aground off the shore. R: back to the start" and R restarts at the start. The HUD has a mini-map of the lake (`mini_map.gd`, the outline from the depth grid, the board, the wind and the start) and the compass's north is the real north. 585 to 684 fps on the lake at 1920x1080 on the RTX 3080 Ti.
- **The board's shape in the physics** (spec 5, 6, 14, 16, 17.14): the tapered box is gone. `BoardConfig` holds what a shaper quotes: the widest point (0.72 m, 1.10 m from the tail), the width one foot off the tail (0.45 m, from real 115 to 125 L freeride boards at 0.62 to 0.63 of the width: Starboard Futura 117 47.7 cm, Carve 115 and 125 44 and 48 cm) and off the nose (0.45 m), a thickness profile (12 cm in the middle, 5.5 at the tail, 4 at the nose), and the rails (hard up to 1.2 m from the tail, soft from 2.0 m, a 3 cm edge face); only the tail width is measured, the rest are estimates marked as such in section 14. The buoyancy rows follow the outline (still 120 L; the old taper had made the tail 0.60 m wide). The sideslip physics comes from NACA TN 4187 (Savitsky, Prowse and Lueders 1958, flat planing plates towed at yaw and roll): a flat bottom with sharp edges carries no sideways force of its own; the rail's edge face grips with about the full dynamic pressure once a strip skids past about 7.5° (less when that rail is lower), modelled strip by strip so a spinning hull is held back by its tail and nose. Two things the outline exposed: the hull now takes water along sideways (its sides, about 6 kg at rest, and the fin's 2.8 kg, which also gives 2.3 kg m² of yaw inertia when the hull skims), and the Savitsky anchoring used the nose width whenever the whole hull was wet, which inflated low-speed lift two to six times (1.5 kN of "lift" on a submerged board). The harness rope's damper acted although the rope was off; it is off now. The planing onset: with the lift bug gone the onset was 20 km/h; the real cause was the sailor's stance, walked forward as soon as the bow began to rise (against what `SailorConfig` documents); held aft through the hump the onset is 4.48, 5.05 and 4.99 m/s at 12, 15 and 18 kt (9.8 kn at 15 kt). A catapult at full speed then rolled the thrown board in the air: the rig's water drag pulled 0.5 m below the mast foot; it pulls at the mast foot. **DECISION FOR MICHIEL:** the validation's onset band was 14 to 17 km/h from the legacy game's documents, and the old model met it only through the lift bug; it is now 8 to 10 kn (4.12 to 5.14 m/s) from real boards (GPS reports of the planing threshold at 9 to 10 kn on the seabreeze forum, an iSonic 122 and a 94 L board; boards drop off the plane below about 8 kn, The Windsurf Loop), written in section 14 part B, the tuning log and the test. Tail width works as Savitsky says: towed with the weight aft, a 0.50 m tail needs 98 N to get over the hump, a 0.40 m tail 121 N. The Blender board follows the new outline (a square-pin tail; `board.glb` regenerated). The rail grip in a carve is not done: TN 4187 gives no consistent coefficient for it.
- **The map's wind in the physics (W5), thin air and fresh water (R1 to R3), gust patches (R9):** `MapWindField` (`Game/sim/map_wind_field.gd`) is a `WindField`, so the simulation does not know which it has: it keeps a time of day (14:30 at the start, real time, `--time=hh:mm`), gives the sail and the sailor's windage MapWind's local wind (gusts, lulls, shifts, the shore lee) scaled from the pattern's 5 m with the power law, and the lake's mean wind for the decisions that must not flip with every gust (the sail side, the water start, the TWA, the waves' direction); outside the map the lake mean, never NaN. `EnvironmentConfig` and `WindsurferSim.create_for(env)` let a map bring its own air, water, wind and waves (R1); `environment_silvaplana.tres` sets 0.98 kg/m³ air (R2) and `water_silvaplana.tres` 1000 kg/m³ and 1.14e-6 m²/s (R3); `create_default()` calls it with an empty environment, so nothing on open water changed; the pilots take the air density from the sim. The lake scene is on the ocean's new API (the lake look, layer 2, the far water over the depth grid's area; the hand-dressed meshes are gone); `WindRippleMap` draws the map's wind into a 256 × 256 texture on the graphics card every frame for the shader's `wind_ripple_map` (ripples proportional to the square of local over mean; `--check-gusts=1` compares the texture with MapWind's numbers, within one 8-bit step; about 0.05 ms per frame, the map wind about 0.45 ms per physics tick). The HUD shows the time of day, the lake mean at 10 m and the local wind at the sail. The thin air (`tools/lake_matrix.sh --compare=1`, a beam reach at the same wind): -69 % at 10 kt (it does not plane), -21 % at 11, -8 % at 12, -0.6 % at 14, +1.2 % at 18.2 kt: it costs most at the planing threshold; in a strong Maloja the sailor is overpowered and sheets in anyway, and the body's windage is 20 % lower too. Fresh water adds 0 to 3 %. The gusts show on the water mostly in the glitter; a stronger look needs the shader.
- **The physics tested in the map's wind** (`tools/lake_matrix.sh`, 24 cases at three times of day, flat water): before the hull changes 23 of 24 complete and no falls (12:00: 14.7 kt mean from 218, 14.9 to 18.6 kt at the sail, straight 20.9 kt; 14:30: 18.2 kt from 222, 12.0 to 17.5 at the sail, 18.7 kt; 17:00: 16.5 kt from 222, 14.5 to 18.2 at the sail, 21.9 kt; the 12:00 run turned 58° of the 60° asked). After the hull changes merged, three tacks stopped completing (`tack_stb` and `tack_held` at 14:30, `tack_port` at 17:00). The hull was not at fault: near the shore the lake's mean wind is 15° off the wind at the sail (off the camping beach at 14:30 the local wind comes from 206 against a mean of 222; in the middle at 17:00 from 236), and the sailor waited to flip the rig until 25° past the mean, beyond the 35° a backed sail can push (the boom fully across lies along the wind: angle of attack 0, 1 to 3 N of lift, the board drifting backwards). The old hull got there by about half a degree on its leftover 2 to 2.7 m/s; the new hull, carrying water sideways (correct physics, Newman 1977), had slowed to 0.9 m/s and stopped at 20.5°. The tack's decisions (flip the rig, give up, end the backing) now read the true wind at the sail (`Telemetry.twa_at_sail_deg`): a sailor flips on the wind they feel. No number changed; a test tacks in a wind 16° off its mean. The lake matrix is 24 of 24 with no falls, and the open-water matrices are unchanged to the digit. The 1.7 Hz yaw wag the map-wind agent saw on a close reach (±15°/s with the planing share cycling 26 to 100 %, also on open water at sea level: `tools/lake_matrix.sh --only=straight --wind=steady --air=1.225 --water=1025 --kt=18 --from=207`) is the porpoising seen in yaw: in one 0.67 s cycle the pitch swings 0.6 to 4.2°, the planing lift 70 to 1400 N, the heel 0.5 to 3.9°; it should go when the porpoising does.

**Merged:** the branches `feature/figure`, `feature/waves`, `feature/audio`, `feature/silvaplana`, `feature/effects`, `feature/mapwind`, `feature/physics` and `feature/laketack`, in that order. Seams resolved by hand: the settings file's audio volumes next to the four-option menu clamp; the open-water sun lines (the map's 15:00 sun with the null check the lake scene needs); the spec's tuning log, where two branches appended rows; and `effects.gd`'s spray root, which read the removed width taper and now reads the board's outline (`BoardConfig.width_at`).

**Verified, on the merged tree:** `tools/check.sh` 188 files, 0 failed. `tools/test.sh` 335 of 335 (245 at the end of Session 38: figure and flutter 2, waves 13 plus `test_wind_waves.gd`, audio 28, the lake 8, effects 17, the map wind 10, the environment 5, the hull's new tests). `tools/test.sh validation` 20 of 20 (with the onset band of real boards, the decision above). `tools/matrix.sh` flat 24 of 24, no fall, straight 8.77, 11.10 and 12.01 m/s at 12, 18 and 24 kt (8.75, 10.54, 11.75 before: the real outline wets less bottom, up to 5 % faster, every polar angle still inside its real-world range). The default sea: 1 fall (`gybe_broad` 24 kt, a catapult at 44.6 s after the gybe, launched off a crest at 13.7 m/s) and 2 manoeuvres not completed (`gybe_beam` 24 and the 24 kt run turn, which stops at 50° of the 60° asked). The medium chop: 0 falls (1 before) and 1 not completed; the straight 18 kt run on it went from 12 yaw spikes above 60°/s (peak 124°/s) to 0 (peak 56°/s). The lake matrix as above. Screenshots in `.screenshots/session39/` (not in git): `figure/` (before and after), `waves/`, `audio/`, `lake/`, `effects/` (before and after, the force view, the lake with the old and the unified water), `mapwind/` (14:30 and 11:00, the gusts from above, the high shot toward St. Moritz), and the merged tree's `final_start_menu.png`, `final_sea_orbit.png`, `final_lake_orbit.png`. NOT verified: anything in motion (the flutter, the spray, the gust patches), how the sounds sound, how the lake or the new hull feel to sail, the menus with a real mouse or gamepad.

**Decisions:**
- The flutter is a visual of the sail's load, with its thresholds in `rig_visuals.gd` like the other rig visual numbers.
- The two wave groups keep the default sea wave for wave, so no validation number moved; "From the wind" is a preset, not the default, until the crest landings are solved (its chop is about six times steeper than the default).
- One water shader for the sea and the lake (R9, option 1), parameter sets per scene; the wave formulas in one include file.
- The open-water islands of Phase 7 are not built: the real lake has a real shore.
- On the lake the settings' wind is ignored (the lake's wind file, then the map's wind model); the settings' waves and sailing options apply.
- The board's outline is the shaper's numbers; where no measurement was found the value is an estimate and says so in section 14.
- The planing-onset band is the one decision Michiel must confirm or reject (above): the real range with its sources replaces a legacy number the old model only met through a bug. Nothing was tuned to it: the onset moved for a physical reason (the stance through the hump).
- On the lake the sail side, the TWA and the waves follow the lake's mean wind; only the sail's force and the windage feel the local gust. The thin air applies to the sail and the windage, nothing else.

**Next:**
1. Michiel: confirm or reject the planing-onset band (8 to 10 kn, real boards) in `test_polar_sweep.gd` and section 14.
2. The 24 kt sea cases: the run turn stopping at 50°, the beam gybe, the catapult off a crest after the broad gybe; behind them the porpoising of the planing board on flat water from 15 kt up (near Savitsky's porpoising limit), which is also the close-reach yaw wag.
3. Play-test (the team): the sound by ear (the list in the plan's Phase 8); the lake with the Maloja (Max: the launch spot, the wind's side, the gusts, the shore stop, the mountains); the spray, the wake and the flutter in motion; the new hull's feel (planing onset, carving, chop); the gusts on the water (too faint?); the Waves tab with a swell from another direction.
4. Open from the agents: shallow-water waves travel at the deep-water speed (a depth term in spec 9.1 and the shader); the rail grip in a carve (TN 4187 gives no coefficient); the completion criteria of the gybe test and the lake runner at 24 kt; running aground in the physics (R4); the audio's shutdown warning about leaked looping sounds; the settings header still says "23 rows"; the HUD's top line runs off the right edge at 1280 wide.
5. Then Phase 9 (racing), with the course maker's courses on the lake.

---

## 16 October 2026 - Session 38: the sailor figure, Blender models for the rig, and the game's menus

**Phase:** 6 (rig visuals), plus the sailor figure and a user interface (the UI has no phase of its own in the plan). Branch `feature/visuals-and-ui`, from `main`. Michiel asked for three jobs at once: a sailor that moves like a real windsurfer, a graphics upgrade of board, sail, boom and fin made with Blender, and a start menu with settings. Each job was done by a sub-agent (Opus, extra-high effort) on its own git worktree and branch (`feature/character`, `feature/rig`, `feature/ui`), merged here with one fix at the seam.

**Done:**
- **The split first** (3d9a8d6): `windsurfer.gd` only steps the simulation now; `rig_visuals.gd` draws the board and the rig, `sailor_figure.gd` the sailor, `visual_math.gd` holds the small mesh helpers both use. No change on screen.
- **The sailor figure** (`figure_skeleton.gd`, `sailor_figure.gd`): a skeleton with fixed bone lengths from the sailor's height (Winter's body proportions: for 1.75 m a thigh of 0.43, shin 0.43, upper arm 0.33, forearm 0.26, hips to shoulders 0.50 m), solved every tick from the simulation's centre of mass, feet, grip, lean, stance, harness tension and turn rate with two-bone inverse kinematics, so limbs never stretch, knees bend only in the plane of the foot and forward over the toes, and elbows point down and out. Planing hooked in it shows the "figure 7" stance: front foot about 45° toward the leeward bow and back foot across the board, front leg nearly straight (158°) and back leg bent (135°), arms nearly straight, hands shoulder-width apart, harness lines drawn when hooked in. Standing it is upright with soft knees and bent elbows; in tacks and gybes it crouches, takes the mast in the front hand and turns round through facing the bow. A head with a neck, a cap, sunglasses and a nose looks toward the bow and into turns. Capsule limbs, knee and shoulder balls, a black wetsuit, red lycra, a harness with hook, booties. The one compromise: hanging out, the simulation puts the centre of mass 0.3 m above the deck and 1.5 m from the grip, further than a body of fixed size can hold the boom from, so the hips are kept at least 0.65 m above the deck and drawn toward the boom (0.44 m off the centre of mass at 18 kt; `FigureSkeleton._place_pelvis`).
- **The rig models** (`tools/blender/build_rig_models.py`, 2 s in Blender 5.2): built from scratch from the numbers in `Game/config/*.tres` (the legacy FBX files were a reference only and are deleted), one `.glb` per part in `Game/assets/models/`: a shaped 2.40 m board with deck pad, orange bow, blue bottom, four footstraps, mast track and base plate; a swept foil fin (0.0364 m²); a tapered mast with extension and rubber joint; a 24 × 40 sail grid with cloth, clear windows and a darker luff sleeve, 6.38 m² against 6.5 in the config; a wishbone boom 0.57 m wide with grip, harness lines and outhaul; and our own panel design with "MMZB" lettering (no brand images). The sail bends in a vertex shader driven by the simulation (`sail_cloth.gdshader`, `sail_window.gdshader`, `sail_cloth.gdshaderinc`): belly to leeward (draft 0.10, deepest at 38 % of the chord), twist 8 to 16° at the head with the pull, ripples when luffing, and the belly crosses over in 0.8 s when the sail flips; the mast bends back and to leeward (`mast.gdshader`) and the sail follows. The two pose functions of `RigVisuals` kept their contract; `shape_sail()` feeds the shader each tick. Automatic LODs are off for the sail and the mast.
- **The menus** (`Game/ui/`): the start menu is the project's main scene, with the sailing scene running behind it (the autopilot sails, a slow orbit camera): Sail on open water, Lake Silvaplana (fly over the map), the Silvaplana wind viewer (with the course maker), then Settings, Controls, How to sail and Quit (with a confirmation). Settings on five tabs, saved to `user://settings.cfg` by the `GameSettings` autoload: wind (speed 4 to 35 kt, direction with the compass name, gusts and shifts), waves (off, flat, swell, medium chop, strong chop with the Session 37 numbers, a height scale), sailing (beginner or advanced, auto-sheet, start heading with its point of sail, starting camera, detail panel), graphics (windowed or fullscreen, VSync, anti-aliasing, resolution scale, shadows, frame-rate cap) and audio (master volume, wired to the Master bus for Phase 8). The sailing scene builds its wind and waves from the settings; a new wind applies as soon as the settings close, new waves at the next restart (the pause menu says so). Esc opens a pause menu (resume, restart, settings, controls, how to sail, start menu, quit); the old Esc pause never stopped the physics, because the windsurfer inherited "always run": fixed. Esc returns to the start menu from the two Silvaplana scenes through a small autoload (`ui/map_escape.gd`), with no change to the map track's code. Keyboard and gamepad navigation, a theme for the menus only, a version label. Options for screenshots: `--settings=<file>|defaults`, `--pause=<s>`, `--page=settings/<tab>|controls|howto|quit`.
- **At the seam** (98b6c4e): the physics puts the hand grip on the boom's centre line, which with the wishbone runs between the two arms, inside the sail; the figure's grip (and the harness lines) are moved by `RigVisuals.windward_arm_offset()` onto the windward arm.
- **Dev views:** `Game/dev/figure_view.tscn` saves contact sheets of the figure from six cameras at chosen moments (wind, angle, tack, a tack or a gybe), `Game/dev/rig_view.tscn` the rig from eleven cameras on either tack and prints the frame rate (165 fps, 0.44 ms of GPU time per frame on the RTX 3080 Ti). The commands are in CLAUDE.md.

**Verified:**
- `tools/check.sh`: 152 files, 0 failed. `tools/test.sh`: 245 of 245 (204 before; new: `test_sailor_figure.gd` 6, `test_rig_visuals.gd` 18, `test_game_settings.gd` 12, `test_menus.gd` 5). The physics is untouched: the sailing scene at 8 s shows the same HUD numbers as before the session (40.7 km/h, sail lift 655 N, fin 669 N); no validation run was needed.
- Screenshots, kept in `.screenshots/session38/` (not in git): the figure planing on both tacks, standing, through a tack and a gybe, falling, at 12 and 24 kt (`figure/`); the rig from every side on both tacks and luffing (`rig/`); every menu page, the pause menu over the game, and the proof that the settings reach the physics: with 24 kt from the North and strong chop in the settings file the HUD reads "wind 24.0 kt … from 000" over a choppy sea (`ui/`); the merged game from the follow camera and the deck close-up with the hands on the windward boom arm.
- NOT verified: anything in motion (the figure's turn-around in a tack, hand changes, the ripples and the belly crossing over, the mast bending in gusts), how it feels to play, a real mouse and gamepad in the menus, fullscreen and VSync on the team's monitors, the frame rate on the other PCs, sound (there is none).

**Decisions:**
- The figure is a representation on top of the physics, as Michiel allowed: fixed bone lengths win over the exact centre of mass when the two disagree, and the code says where (`_place_pelvis`). Nothing visual feeds back into the physics.
- The models come from a script that reads the config numbers, not from the legacy FBX, so the team can change a size and rerun it. One `.glb` per part, origins in the script header: the board at the simulation's board origin, the rig parts at the mast foot with the mast along +Y and the sail along +X.
- The start menu is the main scene; `res://main.tscn` stays runnable on its own, so every screenshot command still works. Settings live in `user://settings.cfg`; the `.tres` defaults are never written.
- The rig's boom stays horizontal in the physics' frame when the mast rakes, so the model's sail is slightly sheared at full rake. Kept: it is the physics' contract.

**Next:**
1. Play-test (the team): the figure's stance at 12, 18 and 24 kt and through tacks and gybes; whether the sail's belly, twist and flutter look right; the menus with a mouse and a gamepad; fullscreen.
2. Open from this session: the force-vector debug view (the last Phase 6 box); a skinned character mesh; the figure's elbows (the back elbow is straighter than the front, coaches say the opposite), animated hand changes, a fall that is still a rigid tip-over; the HUD's top line runs off the right edge at 1280 wide (older than this session); a stretch mode for fullscreen (would also scale Max's map panels: ask him); sailing with a gamepad.
3. For the physics track (spec OPEN 2.4): the sail model's area centre is at 0.49 of the luff and 0.41 of the boom; the config uses 0.40 and 0.35. And the figure cannot lean out further than the rig lets it: hiked, the rig leans only about 11° to windward.
4. Then Phase 7 (environment and effects).

---

## 16 October 2026 - The physics and the map tracks merged

**Phase:** none (branches).

**Done:** `feature/physics-sim` (Sessions 30 to 37) merged into `feature/map-silvaplana` (Sessions 37 to 45 of the map track, which had started from the physics branch at Phase 5). The one conflict was this log: both tracks' entries are kept, in date order. Both branches go to `main` through pull requests #2 (the physics) and #3 (the map, which now contains the physics). The map's files need Git LFS: it was not on the Linux PC, so it is installed in `~/.local/bin` (no sudo), `git lfs install` run, and the 114 MB of terrain tiles, photos and the height grid fetched. Small edits so the documents fit together: CLAUDE.md (the map track is part of the project, not a branch; Git LFS), REBUILD_PLAN.md (the side track), MAP_SILVAPLANA_PLAN.md (merge `main` from now on), PHYSICS_REQUESTS_FROM_MAP.md (R6's precondition, the two-body sailor, is done).

**Verified:** on the merged tree `tools/check.sh` 122 files, 0 failed, and `tools/test.sh` 204 of 204 (126 physics, 78 map). The physics is unchanged by the merge (the map does not touch `Game/sim/`), so the validation suite and the matrix were not rerun. Not run: the map's Python tests in `tools/map/tests` (they need `tifffile` and the other map modules, which the Linux PC does not have).

**Next:** the team merges the pull requests (#2 and then #3, or #3 alone), then everyone installs Git LFS and pulls `main`; new work branches from `main`.

## 16 October 2026 - Session 45 (map track): the map documents brought up to date

**Phase:** none (documents only). Branch `feature/map-silvaplana`.

**Why:** Max: "I see some neglected sections. See L1, this we've already done."

**Done:**
- **L1 (the wind patterns)** in MAP_SILVAPLANA_PLAN.md: a status. Max's part is mostly built as the wind analyser (W0 to W4, `MapWind`). Still open: the day types (W3, postponed) and the connection to the sailing (W5, Michiel). The Status table, "Who does what", and a note after the team decisions say the same. CLAUDE.md, REBUILD_PLAN.md and PHYSICS_REQUESTS_FROM_MAP.md no longer say "later the wind patterns".
- **M3's wind direction:** 244° → 222°. W1 found that 244° is the station's spot turning the wind; over the lake the Maloja blows along the lake from about 222°, which Max confirmed. M3 also notes that the sailing keeps a `WindConfig` until W5.
- **Max's verdicts written in where they were missing:** the terrain "is really good and nice" (Session 41, the M1 and M2 checks); the 10 cm photos agreed (M0); the W1 picture right; W0's questions 1 to 6 answered (7 to 10 still open); the W2 colours and gusts done.
- **Facts that had changed since the plan was written:** the lake level (1790.63 m) and the origin, both fixed in M0; the manifest's place (`.map_data/raw/`); the grid formats (numpy for Blender and a 16-bit `.bin` for the game, not PNG or EXR); the photos go on in Godot, not in Blender; no terrain plugin needed.
- **R4 for Michiel** gave the wrong grid format and said the shallows were "checked against the 10 cm aerial photo". Nothing in `heights.py` or its checks does that, so it now says "not yet checked".

**Verified:** each changed fact against the code and the data (`map_config`, `maloja_day.tres`, `.map_data/raw/manifest.json`, `heights.py`, `build.sh`, git). Session 44's work is committed and pushed (`b9cc3a5`, "Map W4a: race course maker in the wind viewer"). No code changed, so no tests were run.

**Max's looks (16 October):** adding marks to a course works well, and so does the see-through lake water (M2). So W4a is checked, and M2 waits only for Michiel's answer to R9.

**Next:**
- W4b, the tactics tools, detailed with Max first: lifts and headers against the course axis, the stronger lanes, laylines (they need the iQFOiL's upwind and downwind angles), which side paid.
- Michiel: R9 (how the see-through water meets his waves), before M3. The small changes to CLAUDE.md and REBUILD_PLAN.md (one sentence each) are to mention to him (MD7).

---

## 15 and 16 October 2026 - Session 37: the sailor as a body of their own, and the rig held by the sailor

**Phase:** between 5 and 6. The team asked for a real character model with the physics updated to include it, then chop work with it. Done: the physics (spec 7.5), the visible figure, the chop runs. Stopped once mid-way on request (commit `271dbb8`); finished in the second half.

**Done (spec 7.5 and 17.13):**
- Two bodies: the hull (`SimRigidBody`, 9 kg plus the water it drags) and the sailor (`SailorBody`, `Game/sim/sailor_body.gd`, 75 kg at the centre of mass). The rig (8 kg) is in balance between the mast foot (a joint) and the hands; the harness line is in that balance, so the line carries about 400 N of the sailor's weight at 18 kt and the mast foot gets it as mast foot pressure. The legs are a vertical spring and damper (1.2 Hz, 0.9) measured from the feet; across the deck the body rides the hull through the force at the deck point under it. The posture (lean, stance, hang-back) is held in the apparent-gravity frame; the lean answers the hands' pull about the feet; the feet go to the windward rail as the body goes out and press a rail when the controls ask; over the hump the feet trim the board to 2 degrees.
- What the feet pass to the deck: the moment the body cannot balance itself, at most 120 Nm in roll, with the toes-and-heels reflex (1500 Nm/rad, 600 Nm s/rad) in what is left. Falls are physical: the excess tips the body; the hips hold 400 N (plus 400 hooked in) for 0.3 s, then "tipped over" or "tipped back". The old heel rules remain as a backstop.
- The rig is held by the sailor, not the deck (`RigFrame`, `Game/sim/rig_frame.gd`): the hull's heading and pitch, upright in roll. This is what fixed the tack catapults at 18 and 24 kt (the whole chain is in 17.13: the light hull snapped upright under the sailor, the rig fixed to the deck swung the sail 15 degrees through the wind in one step, the sail force spiked, the pull went through the feet into yaw, the board spun to 100 deg/s and flung the sailor). The sail model now computes from the rig frame; the scene poses the rig from it.
- The autopilot sheets to what the body holds right now (hike share 1.1, ankle share 0.8) and catches a body tipping back by sheeting in. Telemetry: hand, foot and mast-foot forces, the harness tension, the feet's roll moment and its excess, the attachment force, and the yaw and roll moments on the hull by source (fin, rig, sailor, water, net), which is how the catapult was found.
- Smaller physics: the hull's friction on the dynamically wet bottom; the hull keeps its momentum when the added water grows (`take_water_along`); the posture's own moves capped at a walking pace; the body follows the stepping feet at a walking pace in a tack.
- The visible sailor (`windsurfer.gd`): an articulated figure from the simulation's body: feet on the deck where they press, two-segment legs with the knee bend, torso, head, arms to the boom either side of the grip, the harness line when it carries load; the fall animation pivots the figure about its feet and the rig about the mast foot. Screenshot `.screenshots/rig_9s.png`: 39 km/h, the sailor hiked out horizontally, the rig upright over a board heeled 4 degrees.
- Tests: `test_sailor_body.gd` (4), `test_sail.gd` on `RigFrame.rigid_on`, the legs test, the friction test on the dynamic area, the polar test's fin bound (650 N) and trim floor (0.5 deg), the upwind-on-waves tolerance 35 % to 15 %.

**Verified:**
- `tools/check.sh` 75 files clean. `tools/test.sh` 126 of 126. `tools/test.sh validation` 20 of 20: the polar within the real-world range at every angle, planing onset in range at 15 kt, the sea within 1.2 % of flat water at 60, 90 and 120 degrees (upwind was 28 % slower in Session 36).
- `tools/matrix.sh` flat: 24 of 24, no fall, no NaN, every manoeuvre complete; straight 8.75, 10.54 and 11.75 m/s at 12, 18 and 24 kt; the 18 kt run holds its heading within 0.1 degree and 0.7 deg/s of yaw. `--waves=1`: 23 of 24 (gybe_beam 24 kt catapults at 40 s, after the gybe, from a yaw spike at a landing). Medium chop (`--wave2.amplitude_m=0.04 --wave2.steepness=0.036 --wave3.amplitude_m=0.015 --wave3.steepness=0.027 --wave4.amplitude_m=0.006 --wave4.steepness=0.021`): 23 of 24 (gybe_broad 24 kt). The strong chop of the old game (0.06/0.054, 0.03/0.054, 0.012/0.042): no falls (five in the morning's runs), one gybe at 12 kt tacked instead; speed loss 6, 24 and 19 % at 12, 18 and 24 kt.
- NOT verified: how it feels to sail (the wobble and the bounce are judged from numbers), the figure in motion beyond screenshots, the sound of nothing (there is none yet).

**Everything tried on the way (so nobody repeats it):** the sideways leg spring in every form (soft, torque-free, stiff and capped, velocity-matched, the mass lumped into the hull, the constraint force at the feet, at the sailor's height), the target measured from the feet, the feet ahead of the body, the fixed sheet capacity, the inflated felt heel, the frame flipping under g, 2 Hz legs, the weight at the feet without the harness (porpoising), a rope with a length between the hips and the boom (worse on chop, broke tacks; in the code, off), a lag on the planing lift (no help; off), the rig held in the apparent-gravity frame (a 1 Hz yaw wobble on flat water), feet roll damping 300 and 450 (not enough), stiffer legs 2.0 and 2.5 Hz (no help, worse at 24 kt), the pilot's hike and ankle shares (no effect on the wobble), a rate cap on the posture (kept, harmless). The pilot's depower integrator reacts to the push of the turn the controller asked for and eases the sail while the sailor is fully hiked at a tack's entry; it did not need changing once the rig stopped swinging, but it is a candidate if tacks at speed feel wrong.

**Decisions:**
- The rig is held by the sailor: it pitches with the hull (the mast foot is a metre forward of the centre) and does not roll with it. A rig fixed to the deck is wrong and it is what catapulted the tacks.
- The sailor rides the hull across the deck; only the legs' vertical give is a real degree of freedom; falls are timed from the hips' limit.
- The sailor's roll control is one reflex at the feet, 600 Nm s/rad within 120 Nm; the one-body `balance_heel_gain`, `balance_rate_gain`, `balance_felt_gain`, `posture_sway_max_m`, `toe_heel_m` and the sideways-spring fields are gone.
- The default sea stays the Session 36 swell; the medium chop is nearly clean and can become the default once the landings are fixed.

**Next:**
1. The hull landing off a crest: the yaw rate spikes to 90 to 120 deg/s for a step or two (16 to 25 reversals in 15 s on the medium chop) and that is where the two remaining falls come from. The breakdown (17.13) says the hull's yaw inertia about its centre is 5 kg m2 when it skims, the fin's lift jumps at the landing, and nothing resists the hull spinning under the sailor's feet. Give the planing hull its lateral and yaw resistance in sideslip (Brown and Klosinski 1994) and the legs a lateral stiffness at the feet; then the medium chop as the default sea.
2. The 12 kt bounce at the edge of planing (the planing ratio 0.15 to 1.0 at 1.2 Hz on flat water, there since Session 36): the heave of the light hull against the strip theory's root force.
3. Play-test: the tacks and gybes at 18 and 24 kt, the feel of the sea, the figure.
4. Then Phase 6 (the rig visuals) as planned.

---

## 15 October 2026 - Session 44 (map track): W4 planned; W4a, the race course maker, first version

**Phase:** W4 of the map plan, part a (the course maker). Branch `feature/map-silvaplana`.

**Why:** Max asked what W4 includes, added the iQFOiL Notice of Race and Sailing Instructions of the 2026 U23 Worlds (Puck) "with pictures of the official courses", and then: "we are going to make this also a easy competition course maker. drag buoys in the map via an easy to use system ... so we can make all these courses ourselves and use templates". He agreed to split W4 into W4a (the course maker) and W4b (the tactics tools), to put it inside the wind viewer for now ("later in game it may be different"), and to save courses for the team. He didn't know the beat length.

**Done:**
- **The plan:** W4 split into W4a and W4b, with the sources, Max's decisions (WD5 to WD7), the class's numbers, the estimates, and a measurement of the lake.
- **The course sizes come from the class, not from a guess:** the iQFOiL Class Race Management Guideline (2023) gives mark 1's distance per wind range (windward-leeward 0.9, 1.0 and 1.05 nm at 10 to 13, 13 to 17 and 17+ kt; trapezoid 0.85, 0.95 and 1.0 nm), the reaches, gates (70 to 80 m), lines (start: boards × 2.20 m × 3; finish 30 to 40 m) and the sprint and medal race sizes. They are in `Game/maps/course/iqfoil_courses.tres` with their sources. What the guideline doesn't give is labelled as an estimate there: the gate 150 m above the start, the trapezoid's outer gate and finish, the upwind sprint (1000 m to mark 1, from its 7-minute target time).
- **The lake, measured** on the 2 m shore grid: along the Maloja (222°) about 2.8 km of open water, 760 to 1370 m wide. A full windward-leeward course fits; the full trapezoid's reach (1.3 to 1.5 km) doesn't.
- **The course maker** (`Game/maps/course/`, in the wind viewer, `tools/play.sh wind`):
  - `Course` and `CourseMark`: the marks and the mark order written as in the Notice of Race (`Start-1-4S/4P-1-4S-Finish`), the legs, moving, turning and scaling (gates and lines keep their size), the land warnings, and JSON files with LV95 positions.
  - `CourseTemplates`: LG2, LR2, O2, I2, US3, US4, PD3, SD3, PM1 and SM1, built in the course's own frame like the diagrams and turned to the wind.
  - `CourseEditor`, `CoursePanel`, `CourseOverlay`: choose a template (it appears in the middle of the view, squared to the lake's wind and sized for it); drag marks (a gate moves as a pair), Shift and drag the whole course; Axis, Square to wind, Size %, Boards; Undo (Ctrl+Z), Clear; Save under a name in `Game/maps/silvaplana/courses/`, Load; M hides it. The course is drawn like the diagrams: salmon marks with rounding arrows, green boats with orange and blue flags, dashed lines, black legs side by side. The panel lists the legs (length, compass course, angle to the wind now) and the warnings.
  - Start options for screenshots: `--course=LG2` (or a saved course's name), `--course-at=<east>,<north>`.
- **Small changes to shared map files:** `TopCamera` and `FlyCamera` ignore the keyboard while a text field has it; `tools/play.sh`'s menu and `CLAUDE.md` mention the course maker.

**Verified:**
- `tools/test.sh`: 186 of 186 (18 new: `test_course.gd` 11, `test_course_editor.gd` 7). `tools/check.sh`: 119 files, 0 failed.
- The rounding sides read from the diagrams agree with the way each course turns, in all ten templates (a test).
- Screenshots: the ten templates on the lake (`.screenshots/w4a_templates_sheet.png`), a close-up of a start (committee boat on the right looking upwind, 4S on the left, the finish boat at the upwind end), and the free camera low over the water.
- 98 to 102 fps in the screenshot runs, with and without a course.

Not verified:
- Dragging with a real mouse, and how easy the panel is: Max play-tests. The editing is tested with made-up mouse events.

**Decisions:**
- Templates are set to the wind like a race committee sets a course: mark 1 dead upwind of the start, at the class's distance for the wind of the moment (WD7). "Square to wind" uses the lake's mean wind, without the moving shifts.
- Where the guideline gives a range, the middle. The trapezoid's reach angle: 90°, because the guideline's 80 to 90° doesn't say from which line it is measured.
- The course is drawn on the screen over the 3D view, not as 3D buoys: the same size at every zoom, and the same from both cameras. 3D buoys come with sailing a course in the game (later).
- Saving a course under a name that exists replaces it (the panel says so); git keeps the old versions.

**Max's play-test (16 October):** easy to use (pick, drag, turn, resize, save, load), and the templates look like the diagrams in the Notice of Race. Where the race committee sets the course at Silvaplana and how it would shorten the trapezoid: not important for now.

**Then, Max: "I would like to add a mark to existing courses"** (dropped on a leg, "but it needs to work really well", and typed when that isn't what he wants). Added:
- **Add mark** and a click on the water: the mark goes into the leg drawn nearest to the click (so between a beat and a run on the same line, the one on that side), and into the same leg on the other laps; Shift for only that leg; away from the legs a lone mark. The legs it will go into light up in yellow before the click. Named with the next number, left on the side the course bends round it.
- **The order typed** in the Notice of Race's notation, checked (a wrong order is refused with the reason).
- **A selected mark** (click it): rename (also in the order), port or starboard, delete (Delete key). Esc deselects or stops adding. A click that only selects is no Undo step any more.
- The mouse is matched to the height the marks are drawn at (0.3 m above the lake), so a mark put down lies exactly under it.
- `--course-new-mark=<east>,<north>` shows the Add mark preview for screenshots.
- Verified: `tools/test.sh` 199 of 199 (13 new), `tools/check.sh` 119 files; the preview screenshot (`.screenshots/w4a_add_mark.png`): dropped beside the first run, both runs light up and the beat on the same line doesn't. Not verified: how it feels with a real mouse.

**Then, Max (a screenshot of a 3137 × 1263 window): "the UI is not nice for other resolutions, and the drawing of the arrows is wrong on a gate".**
- The viewer's panels had fixed places for 1280 × 720. A first fix scaled them as a whole; Max: "the UI is just scaled up and I can count the pixels now, it's ugly". Now each panel is anchored to its corner or edge (course panel and legend top right, clock along the bottom, wind chart left), and the viewer switches its window to Godot's "canvas items" stretch (laid out for 1280 × 720, wider windows get more room across), which draws text and lines at the window's full resolution: sharp. Only while the viewer runs; the game's screen settings are unchanged and the window's are put back on exit. Found on the way: `set_anchors_preset()` keeps a control's old size, so a full-window control needs `set_anchors_and_offsets_preset()`.
- The course panel and the clock bar got the wind chart's look (dark, see-through, rounded, with room inside).
- The rounding arrows were the same three-quarter turn from the top of every mark. Now they come in from the leg in, go round the mark's far side and leave along the next leg: at a gate, down between the marks and outwards, back upwind, as on the diagrams.
- Verified: `tools/test.sh` 200 of 200 (a new test for the arrows at a gate and at mark 1), `tools/check.sh` 119 files; screenshots at 3137 × 1263 and 1280 × 720; `--check-colours` 0.8 of 255 (the course is hidden for it).

**Next:**
- Max looks at adding marks: does dropping on a leg pick the leg he means, and is the side right?
- To commit (Max decides): the course maker, the plan, and the Notice of Race PDF in `Documentation/`, which the plan now links to.
- Then W4b, the tactics tools, detailed with Max: lifts and headers against the course axis, the stronger lanes, laylines (they need the iQFOiL's upwind and downwind angles), which side paid.

---

## 15 October 2026 - Session 43 (map track): Wind analyser W2 (the viewer) and W3's gusts and lee, measured on the satellite photos

**Phase:** W2 of the map plan (the wind analyser's viewer), then most of W3 (gusts, pulses, shifts, the lee along the south-east shore). Branch `feature/map-silvaplana`. Nothing new on `feature/physics-sim` or `main` to merge.

**Why:** Max: "Start phase W2 of the map plan: the wind viewer." The Windfinder view in 3D over Silvaplana, to study the Maloja for course-racing tactics. Then, look by look:
- "use this colors for the wind strength" (a screenshot of Windfinder's legend), and "can't see any gust going over the lake now";
- "gusts now come out of nothing and disappear", they should "progress out of the gusts more upwind";
- "they are still round, it is a front that is wider", "too much difference", and "I have the feeling you are guessing it a lot, please be more precise";
- his answers: mostly fronts, sometimes lanes; lanes 50 to 100 m wide; "too much difference" meant the gusts against the wind around them;
- "the rest is really good, good job", but the band along the south-east shore "has too much wind compared to real life; on competition you have to really avoid it, and only once in every 10 or so there is a gust that is favourable and goes down all the way".

**Done (what is in the game now):**
- **The wind, one place for the viewer and later the sailing** (WD1): `MapWind` (`Game/maps/wind/`) = the fixed pattern (`WindPattern`, W1, interpolated as arrows) × the day (`WindDay`, `maloja_day.tres`: the station's hourly medians × 1.3 on the water) + the gusts, pulses and shifts (`WindGusts`, `maloja_gusts.tres`) + the lee along the south-east shore (`WindLee`, `shore_lee.json`). `MapWind.velocity_at(point, time of day)`; for many places at one moment `moment()` + `velocity_in()`.
- **The viewer**, `tools/play.sh wind` (`Game/maps/silvaplana/wind_viewer.tscn`):
  - a map camera looking down (`TopCamera`) and the free camera, Tab to switch;
  - 5000 white streaks moved by the graphics card, drawn as particle trails, also over land up to 2100 m, sped up so they cross the screen in about the same time at every zoom ([ and ] to change);
  - the wind speed as colour on the water in Windfinder's colours (read from Max's screenshot), with a legend like Windfinder's;
  - a clock: Pause, 1×, 10×, 60×, a slider from 10:00 to 21:30;
  - click a point: a marker, and the speed and direction there over the last 10 minutes (a value every 2 s), with a hover readout;
  - `--check-colours`: compares the water's colour on the screen with the colour of the game's numbers.
- **The gusts** (third version): a smooth random pattern ("noise") of fronts across the lake (70 % of the variance) and lanes along the wind (30 %), rolling down the lake with the air (`MapWind.travel_m()`) and slowly changing; as many lulls as gusts. In knots they change only slowly with the wind (the station). The sideways part, which turns the wind, is 0.8 times the part along it (Panofsky and Dutton). The same 32-bit random numbers on the CPU and the graphics card (`WindGusts.noise_3d()`), divided by their local spread so there is no rhythm on the noise's grid.
  - Fitted by measuring the model exactly like the satellite photos: `Game/maps/silvaplana/dev/export_gusts.gd` writes the model on the photos' grid, `tools/map/gust_shapes.py --model` measures both (the table is in the plan, W3; the pictures `gust_photos.png` and `gust_model.png`).
  - The two earlier versions (patches born anywhere; patches rolling from upwind and growing) were replaced after Max's looks: their sizes, spacing, growth and "gustier at Sils" were estimates the photos don't support. The second version's files are kept in `.map_data/work/wind_research/old_versions/`.
- **Pulses and shifts:** three slow waves each (13 to 45 minutes), the station's size (about ±9 % and ±5°), travelling down the lake.
- **The lee along the south-east shore:** measured on the photos at 10 m by `tools/map/shore_lee.py` (MALOJA_WIND_RESEARCH.md, "The lee along the south-east shore"): from the Sils end to the north-east bend, deepest 25 to 100 m from the shore, weaker around "the little corner", deeper when the wind comes from further left (1.1 % per degree) and when it is stronger (4.5 % per knot). Only the strongest 1 in 10 gusts get in (Max; the photos: about 1 in 8) and roll down the band. W1's smoothed version of it is taken out again, so over time the band averages to the photos.
- **Data and scripts:** `tools/map/wind_ground.py` (the ground under the pattern, for the streaks; in `build.sh`), `gust_shapes.py`, `shore_lee.py`; `play.sh` (menu choice 3), the tools README and CLAUDE.md mention the viewer.
- **Tests:** `test_map_wind.gd` (9: the pattern, the day, the clock, the colours, the graphics card's copy of the pattern), `test_map_wind_gusts.gd` (12: exact 32-bit random numbers, spread 1 everywhere, no jumps, the mean kept, knots added, fronts across and lanes along, rolling with the air, the sideways share, pulses and shifts), `test_map_wind_lee.gd` (6: where the lee lies, its depth, 1 in 10 gusts through, a strong gust lifts it and rolls down the band, nothing changes elsewhere).

**Verified:**
- `tools/test.sh`: 168 of 168. `tools/check.sh`: 109 files, 0 failed. `test_wind_pattern.py`: 6 of 6.
- The graphics card computes the same wind as the game, gusts and lee included: `--check-colours` within 1 of 255 at 11:10, 14:30, 16:05 and 19:30 (33 points on the water each).
- The model against the photos, measured the same way: lanes 115 × 61 m (photos 110 × 56), fronts' correlation halves at 230 m (240), spread 7.9 % (8.1), across-lake bands 35 % (39).
- At one point on the open water (13:00 to 15:00): the strongest second in 10 minutes is 1.18 to 1.25 times the mean (the land station: 1.52); a gust of 2 kt or more above the mean every 3 minutes or so, for about 30 s; the direction swings 21 to 25° within 10 minutes.
- In the lee band, 75 m off the shore in the north-east, with the wind 7° further left than usual: about half the wind is gone (8.7 kt where the open lake has about 17).
- Screenshots: from above with and without streaks, from 350 m over the Sils end, from the water at the launch, the evening, four moments 40 s apart (the fronts roll down the lake), the lee band with a probe.
- Speed: 0.6 to 0.8 ms per frame on the graphics card with the PC otherwise idle (1,300 to 1,500 fps); earlier measurements of 2 to 3 ms were taken while other calculations ran.

Not verified:
- How the streaks and the gusts move (screenshots are still pictures), the mouse controls, and the hover readout: Max play-tests.
- How bright water turns into knots: taken 1 to 1 (as in W1) for the gusts' spread and for the lee; sun-glint theory allows up to 1.7 times more. Max judges.
- How long gusts live and how fast they travel: estimates (labelled in `maloja_gusts.tres`).

**Decisions:**
- Windfinder's colours, as Max asked (the first version had one blue, readable for colour-blind people; Max chose the scale sailors know).
- The viewer uses plain (linear) tone mapping and fully covering speed colours, so the water's colours are exactly the legend's; C shows the see-through water.
- Streaks fade out above 2100 m (the pattern up there is not the Maloja), and fly at a quarter of the camera's height, so from the water they lie on the water.
- Gusts add knots, not a percentage (the station; Max's "little corner").
- The gusts are measured, not guessed: every number in `maloja_gusts.tres` and `shore_lee.json` is from the photos, the station, Max or the literature, or labelled as an estimate.
- Max's "mostly fronts" over the photos' "mostly lanes" (19 of 22 photos): his experience on the water wins (WD3), and all photos are from 12:28, while the Maloja builds.
- Pulses and shifts are three slow waves each, so the CPU and the graphics card compute them the same; they repeat only after many hours.
- Found for later: the pattern puts the station at 1.34 × the lake's average, while Max puts the water at 1.3 × the station, so a simulated station would read about 1.7 times too much (plan, notes for W3).
- Found on the photos, not built in: when the wind veers, the lee may switch to the north-west shore.

**Next:**
- **W4, the tactics tools** (Max, 15 October: W3's "the day" is postponed, W4 first, on the average day). The plan's first ideas: a course on the lake (start line, windward mark), lifts and headers relative to the course, the stronger lanes, which side paid over the last minutes. Start the session by planning W4 in detail with Max.
- At the start, Max play-tests the latest version (`tools/play.sh wind`; V hides the streaks, 2 for 10× to see the fronts roll; click near the south-east shore for the lee). To ask him: are the gusts strong enough and the lee deep enough (the brightness-to-knots question), are the gusts visible enough in Windfinder's colours (a "difference from the average" view could help, W4), and does the lee move to the north-west shore when the wind veers?
- Later: W3's "the day" (the start front, light, medium and strong days).
- Committed and pushed at the end of this session: "Map W2 and W3: wind viewer, gusts and lee measured on satellite photos".

---

## 14 October 2026 - Session 42 (map track): Wind analyser W0 (research) and W1 (the fixed pattern)

**Phase:** new phases W0 and W1 of the map plan (the wind analyser). Branch `feature/map-silvaplana`.

**Why:** Max wants the simulated Maloja (speed, gusts, shifts) as a viewer in the game, like Windfinder's map but in 3D over the terrain, real time and sped up, to work out tactics for course racing. It is about how the Maloja behaves once it blows, not when it comes. Max agreed the plan ("run everything, document carefully, first do no. 1", then "do phase 2 as well").

**Done:**
- Plan: the wind analyser's phases W0 to W4 and its decisions WD1 to WD4 in MAP_SILVAPLANA_PLAN.md; WindNinja in the Tools table; a pointer in PHYSICS_REQUESTS_FROM_MAP.md (R5).
- W0, research: [MALOJA_WIND_RESEARCH.md](MALOJA_WIND_RESEARCH.md), with four charts in `Documentation/images/maloja/`.
  - Sources: Mörikofer's 1938 measurements at Sils (found as a 1982 translation), the weather services, spot guides, glider pilots, race reports, papers on wind over lakes and gusts.
  - `download.py wind-valley`: five MeteoSwiss stations, 2010 to now (0.41 GB). `maloja_research.py` and `maloja_charts.py`.
  - Main numbers, 950 Maloja days 2014 to 2026:
    - 12.6 to 13.0 kt mean from 13:00 to 16:00; gusts about +7 kt at every strength;
    - pulses and shifts of 10 to 30 minutes (±8 %, ±6°);
    - the start travels down the valley at about half the wind speed;
    - it turns right until 16:00 and left in the evening.
  - `satellite_wind.py`: Sentinel-2 photos of the lake on Maloja afternoons against calm ones (22 and 5 clean photos). It reads only the lake's corner of each photo (about 10 MB of 1 GB).
    - Smoother water along the south-east shore and at the Sils end.
    - The streak direction was tried and is not usable: the calm photos show the same direction.
- W1, the fixed pattern: WindNinja 4.0.0, unpacked with 7-Zip into `%LOCALAPPDATA%/Programs/WindNinja/4.0.0` (the installer wants admin rights). `windninja_pattern.py` makes 12 runs and compares them with the station and the satellite.
  - Stable air puts the lake's wind along the lake (about 220°) and turns the station's reading 20° to the right, as measured.
  - The strength disagrees with the satellite.
  - The game's pattern takes the direction from WindNinja and the strength on the lake from the satellite: `Game/maps/silvaplana/wind/maloja_pattern.json` + `.bin`. Pictures for Max: `pattern_game.png`, `pattern_lake.png`, `pattern_valley.png`.
- `tools/map/tests/test_wind_pattern.py`: 6 checks of the pattern.
- One run of WindNinja's momentum solver (OpenFOAM, 52 minutes) as a check: it also puts the weaker wind on the south-east side, but can't do stable air; not used for the game.

**Verified:**
- `tools/check.sh`: 89 files, 0 failed. `tools/test.sh`: all passed.
- `test_wind_pattern.py`: 6 of 6.
- The streak-direction maths, on made-up streaks at known angles (within 1°).
- Every chart and picture looked at.

Not verified:
- whether the pattern matches the water (Max),
- whether 10 % rougher water means 10 % more wind (an assumption).

**Decisions:**
- The near-infrared band was dropped for the red one: the atmospheric correction leaves the water at almost exactly 0 there.
- The first satellite selection let cloud shadows and haze through and was replaced by a strict one (no clouds within 500 m, no haze).
- Charts are PNG (light and dark versions) instead of SVG: no browser on this PC to check SVGs, and Godot's SVG reader skips text.
- The fast solver's strength pattern was not used on the lake, because the satellite contradicts it (no inertia, no forest).

**Max's check (15 October):** the pattern is right: weaker along the south-east shore and at the Sils end, the wind along the lake, a little more on the north-west side (which usually pays upwind). New for W3:
- gusts of 100 to 200 m at all time scales, randomly;
- gustier at the Sils end and steadier downwind;
- full-strength gusts now and then in the weak band at the bend of the south-east shore;
- the turn in a gust depends on where you are in it.

His answers are in SILVAPLANA_SPOT_NOTES.md and in the research document, "What Max says".

**Next:**
- Then W2, the viewer.

---

## 14 October 2026 - Session 41 (map track): Realistic lake water

**Phase:** M2 of the map plan, the water. Branch `feature/map-silvaplana`.

**Why:** Max: the terrain "is really good and nice", but the water "is really bad, a plain colour; water is semi-transparent". He asked for research.

**Done:**
- Research into realistic water in Godot 4. The findings and sources are in PHYSICS_REQUESTS_FROM_MAP.md, R9:
  - see-through water reads the depth and the picture behind it,
  - built-in screen-space reflections don't work on see-through materials,
  - mountain reflections come from a reflection probe, a custom SSR or a mirror camera,
  - the depth formula since Godot 4.3.
- The map's own lake water, `Game/maps/lake.gdshader` with `Game/maps/silvaplana/lake.tres`:
  - see-through, darker with depth (red goes first), so the real lakebed makes the shallows turquoise,
  - refraction by the ripples,
  - a Fresnel mirror,
  - two layers of wind ripples drifting downwind, rougher far away.
- `LakeReflections`, a reflection probe in `silvaplana.tscn`. Only the lake water mirrors it (render layer 2), so the lake reflects the mountains, not only the sky. From the village the lake looks dark now, as in reality.
- In the terrain view, G (or `-- --water=game`) switches to the game's water shader to compare.
- 2 new tests in `test_silvaplana_look.gd`: the lake water and the probe.
- R9 rewritten for Michiel: how this water should meet his waves in the game.
  - Option 1: his shader gets these features.
  - Option 2: the wave math moves into a shared include file.
  - It's his choice. The game's water is unchanged until then (MD7).

**Verified:**
- `tools/test.sh`: 141 of 141. `tools/check.sh`: 89 files.
- Screenshots of the new water: from the launch, the village, a drone over the camping beach (turquoise shallows fading to deep blue), and the same view with the old water.
- Frame rate: the new water costs about 6 % (1,280 → 1,200 fps, both measured the same way; an earlier 1,100 was low because another game window was still open).

Not verified:
- whether it looks like the real lake to Max,
- how it looks with the physics' waves (that needs R9).

**Decisions:**
- The new water lives in map files, because the game's water shader is Michiel's (MD7).
- Mountain reflections come from a reflection probe, not a custom SSR or a second camera: cheap, and with Maloja chop a blurred mirror is realistic. The probe makes Godot print a harmless texture-leak warning when it quits.

**Next:**
- Max looks at the water: `tools/play.sh silvaplana`, G to compare. The absorption, the colour and the ripples are numbers in `lake.tres`.
- Michiel answers R9.
- Then M3.

---

## 14 October 2026 - Session 40 (map track): Phase M2, the look

**Phase:** M2 of the map plan, built on Windows. Branch `feature/map-silvaplana`. Nothing new on `feature/physics-sim` or `main` to merge.

**Done:**
- Max agreed to the 1.1 GB of 10 cm photos. `download.py photos-near` fetched the 25 shore-band tiles (2025 flight, checksums checked).
- `tools/map/photos.py`: one WebP photo per chunk.
  - 12 cm on the two tiles of the camping and the launch beach, 0.5 m on the rest of the shore band, 2 m up to 8 km, 8 m beyond. 50 MB.
  - Each photo has a `.import` file, so Godot makes mipmaps and compresses it for the graphics card.
  - The 22 visible tiles in Italy are painted in the colours the Swiss photos have at the same height, slope and lighting, with the small ridges of the 10 m heights.
- `tools/map/tests/test_photos.py`, 4 checks, among them that every photo lines up with the lake.
- In Godot:
  - `terrain.gdshader`: the photo as colour, 25 % darker on cliffs. The game's sun shades the slopes only half, because the photo already has its own (morning) light.
  - `MapTerrain` (`map_terrain.gd`): the root of `terrain.tscn`; it gives every chunk its photo.
  - The map scene `silvaplana.tscn` got its own sky, sun (mid-July 15:00: azimuth 225°, 59° up), haze and fill light.
  - `lake_water.tres`: the lake's colours, measured in the photo, for the game's water shader, without grid lines.
- The skirts are separate meshes now, without shadows. They had cast long dark bands across the slopes.
- `tools/blender/build_terrain.py` writes `terrain.tscn` with the `MapTerrain` script.
- `Game/camera/camera_rig.gd` (shared, one line; mention it to Michiel): the far plane is 35 km instead of 3 km, so the mountains are drawn.
- The terrain view:
  - It uses the map's look and the game camera's near and far planes.
  - `--at=e,n,h --look=e,n,h` starts at any viewpoint.
- `test_silvaplana_look.gd`, 4 tests:
  - every chunk wears its photo and the skirts cast no shadows,
  - the sun's direction (it caught the sun pointing 37° below the horizon: tscn files list a rotation row by row),
  - the camera's far plane,
  - the lake uses the game's water shader.
- `build.sh` downloads the 10 cm photos and runs `photos.py` and its checks.
- Request R9 for Michiel (PHYSICS_REQUESTS_FROM_MAP.md): lighter water in the shallows. It needs a depth texture in `water.gdshader`, which the map track may not change.

**Verified:**
- `tools/test.sh`: 139 of 139. `tools/check.sh`: 88 files.
- The Python checks: 8 of 8 for the heights, 4 of 4 for the photos.
- Screenshots from the launch, the village and above (`.screenshots/m2_*.png`), and one over Sils.
- About 1,500 fps at every viewpoint (RX 6950 XT, 1280 × 720, no vsync).
- The open-water game still looks the same.

Not verified:
- how the lake's colour and the light compare with the real spot (Max's check),
- lighter shallows (R9),
- the Linux PC.

**Decisions:**
- The photos go on in Godot (shader and `MapTerrain`), not into the `.glb` in Blender. A new photo then needs no new meshes, and the shader handles the light.
- The sun is at 15:00. The photos' morning light is softened by letting the game's sun shade the slopes only half.
- The lake colour comes straight from the aerial photo. The first, greener try looked like the Caribbean once the sun pointed the right way.

**Size:** `Game/maps/silvaplana/` is 111 MB of 300 MB.

**Next:**
- Max checks the look: `tools/play.sh silvaplana`, keys 1 to 4.
- Then M3, sailing on the lake:
  - the windsurfer on the map,
  - the Maloja wind setting,
  - the start at the camping beach,
  - the stop at the shore (`TerrainGrid`),
  - the game's water only on the lake. The ocean plane must not cover land below the lake level, such as St. Moritz.

---

## 14 October 2026 - Session 39 (map track): Phase M1, terrain and lakebed in Godot

**Phase:** M1 of the map plan, built on Windows. Branch `feature/map-silvaplana`. Nothing new on `feature/physics-sim` or `main` to merge.

**Done:**
- `tools/map/heights.py` makes the terrain heights, in metres above the lake.
  - Four detail levels, so that a grid cell looks about equally big from the water at every distance:
    - 2 m in the shore band (swissALTI3D plus the lakebed),
    - 10 m up to 3 km from the lake,
    - 20 m up to 8 km,
    - 40 m beyond (swissALTIRegio).
  - Only visible tiles are built: 354 tiles in 80 chunks.
  - Where two levels meet, the edges are stitched, so the meshes join without cracks.
  - The unsurveyed shallow lake (0.16 km²) is filled in smoothly from the shoreline to the survey.
  - It also writes the game's height grid of the shore band (2 m, `shore_heights.bin` and `.json`).
- `tools/map/tests/test_heights.py`: 8 checks:
  - the lake at 0 m,
  - water over the whole lake,
  - the deepest point 76.9 m (published: 77 m),
  - Piz Corvatsch 3450 m (published: 3451 m),
  - the weather station 1803.5 m (published: 1804 m),
  - the camping at the shore,
  - no holes,
  - no cracks.
- `tools/blender/build_terrain.py` builds and exports the 80 chunks as `.glb`:
  - thinned out with Decimate, with each chunk's border locked,
  - a hidden skirt against hairline gaps,
  - normals taken from the height grid,
  - `terrain.tscn`, and two pictures from above.
  - 1.14 million vertices, 49.6 MB, about 1 minute.
- In Godot:
  - `silvaplana.tscn` (the map with its terrain),
  - `TerrainGrid` (`Game/maps/terrain_grid.gd`, the ground height anywhere in the shore band, for M3),
  - `FlyCamera` (`Game/maps/fly_camera.gd`),
  - the view `res://maps/silvaplana/dev/terrain_view.tscn`: viewpoints 1 to 4, a flat lake stand-in, the position and height on screen, and `--measure=1` for the frame rate.
- `test_silvaplana_terrain.gd`: 6 tests:
  - known points,
  - grid heights,
  - meshes within 0.5 m of the grid,
  - every chunk in the scene,
  - LODs.
- `build.sh` runs the new steps; the README describes them.
- `tools/play.sh` (a shared file, small change; mention it to Michiel):
  - Double-clicked, it asks what to start: Enter plays the game as before, 2 opens the Silvaplana terrain.
  - `tools/play.sh silvaplana` opens the terrain directly.
  - Without arguments from a terminal, nothing changed. `silvaplana_area.py` has the known points (`KNOWN_POINTS`).
- Coordinates looked up: the church Santa Maria (OpenStreetMap), the camping area and Piz Corvatsch (swissNAMES3D, through the geo.admin.ch API).

**Verified:**
- `tools/test.sh`: 135 of 135. `tools/check.sh`: 85 files.
- The Python checks: 8 of 8.
- `tools/map/build.sh` from start to end, 2.5 minutes.
- Screenshots from the four viewpoints (`.screenshots/m1_*.png`) and the Blender pictures from above.
- Mesh against grid, at 2000 random points: median 3 cm, worst 52 cm.
- Frame rate: about 1,500 fps at every viewpoint, on the RX 6950 XT, 1280 × 720, without vsync. Max switched off a 100 fps cap in RivaTuner for this measurement.

Not verified:
- the comparison with map.geo.admin.ch in 3D,
- the double-click menu of `play.sh` (it needs a window to type in; the short name and the plain game start were tested),
- how the place feels to someone who knows it (Max's check),
- the Linux PC.

**Decisions:**
- Four detail levels instead of the planned two (10 m and 50 m). Piz Corvatsch is 4.1 km from the water and would have looked blocky at 50 m.
- No `visibility_range` on the terrain. Everything must stay visible, and Godot's automatic LOD already makes far chunks cheap.
- The game grid is a plain 16-bit `.bin` file, because Godot reduces 16-bit PNGs to 8 bits.
- Lake Sils and Lake St. Moritz stay flat surfaces at their own level for now (M2/M3).

**Size:** `Game/maps/silvaplana/` is 62 MB of the 300 MB budget.

**Next:**
- Max flies around the view and checks it against the real spot and map.geo.admin.ch.
- Then M2, the look: aerial photos on the terrain, sky and sun, the far plane of the game camera. The 10 cm photos of the shore band (1.1 GB download) still need the team's go.

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
