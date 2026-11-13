# E01 · Physics: the feel

Owner: Michiel (every change in `Game/sim/` needs his OK, a spec update and `tools/test.sh validation`) | Roadmap section: PH | Questions: Q6, Q7, Q8, Q9, Q10

**Goal.** The physics of every component (sail, board, fin, sailor, wind, water, waves) is correct for the player to feel, efficient enough for a fleet, and proven by measurements against sources. Priority one of the whole plan (Max, 6 November 2026): this epic runs alongside every version.

**Done when (1.0).** The validation suite is green, or every red test is replaced by a target with a source; a polar per catalogue board and sail at three sailor weights agrees with published GPS speeds; Max's feel checklist (E01.S15) passes on every physics release; the sea spots' water (swell, depth, tides, current) is in the simulation; 32 boards step at 60 fps (E17.S01). Fin racing only: no foil in 1.0 (Q6 answered 6 November 2026: not in 1.0, maybe a DLC later).

**Where things stand (6 November 2026).** A 6-degree-of-freedom simulation with its own integrator, in SI units, 3 substeps at 60 Hz: the sail from an iQFOiL wind-tunnel study (lift, drag, twist under load), the hull with ITTC friction, a planing strip model scaled to Savitsky, buoyancy on a grid, a fin that bends as a measured beam, a sailor as a point mass on spring legs with reflexes, a harness, the wind with gust patches from the Maloja's satellite pattern, Gerstner swell on the open water and fetch-grown chop on the lake (PH44 stages 1 and 2, on the play branch), the dive after a crest (PH43, in main). Everything is written up in `Documentation/PHYSICS_SPEC.md` (7,300 lines; 99 numbers marked "estimate", 128 "OPEN"). Not modelled: fin ventilation (the spin-out), a structural mast and boom, contact between boards, the sea bottom, tides, currents, foils. Eight validation tests are red (accepted on 5 November until the autopilot improves). Nineteen physics files changed since main wait for Michiel's OK.

## Stories

### E01.S01 · Michiel's OK on the 6 November physics
Status: review | Size: S | Owner: Michiel | Milestone: M1 | Needs: — | Roadmap: PH44, PH45, GE8, GP2
Done when: every `Game/sim/` change on `play/6nov-evening` is read by Michiel and either OK'd, changed or switched off, so the branch can merge into main.
- [ ] T1 The lake waves in the physics (PH44 stages 1 and 2: `lake_waves.gd`, `lake_wave_field.gd`, `fetch_map.gd`, the hull's averaged view, the fin's depth fade; spec 9.17 and 9.18; the eight open questions in `Documentation/reports/waves/lake_waves_full.md`)
- [ ] T2 The feet's press as controls (`SimControls.feet_roll_press` and `feet_pitch_press`, `Documentation/reports/gameplay/gp2_feet_pressure.md` section 10)
- [ ] T3 The fall's bar: the seven numbers of PHYSICS_SPEC 7.7 (catapult 30°, fell back 32°, standing 50°, the pull share 0.2, the times), commit 702830b, and the felt heel in free fall (`Documentation/reports/autopilot/stay_on_the_board.md`)
- [ ] T4 The race fins' stiffness: they bend about 1.9 times the measured test fin at the same depth (`Documentation/reports/fleet_gear/fin_brands.md`); a data-only fix is in the report
- [ ] T5 The +2.3 ms per tick of `ph44/lake-full` even with the lake waves off: the cause found or accepted (the night run's part D re-measures the frame time)
- [ ] T6 The three observations from the sailor polish: the back foot at 100 % stalls a broad reach, the 30 Hz wobble of the sailor's centre of mass, the rig's one-tick rake and side flips
Notes: the diff is `git diff main..play/6nov-evening -- Game/sim/` (19 files, +1,565 lines). The lead reads it first and marks what to look at.

### E01.S02 · The eight red validation tests: a sourced target each, then green
Status: todo | Size: L | Owner: Michiel | Milestone: M3 | Needs: Q7, E01.S08 | Roadmap: PH16, PH17
Done when: each of the eight has a target with a source (a GPS track, a paper, a measurement of Max's board) and passes, or is retired with the reason written in the spec.
- [ ] T1 The polar speeds in the real-world bands (`test_polar_sweep.gd`, old targets: refit them from GPS data per wind strength)
- [ ] T2 The polar's shape (the 45° point slower than 40° with the upwind rail)
- [ ] T3 The top speed (14.67 m/s today; the target from real slalom GPS)
- [ ] T4 The planing onset: 14.4 kn against the 8 to 10 kn band (the hull over the hump, E01.S08)
- [ ] T5 The fin's side force on the beam reach (745 N against the 100 to 650 N bound)
- [ ] T6 The push warning: the pushed 8.0 at 24 kt never catapults the 85 kg sailor (PH26: light wind too weak, strong wind too safe)
- [ ] T7 The skipper's 12 kt time on T1 (12:21 against 12:19)
- [ ] T8 The broad reach on waves (12.09 against 14.67 m/s)
Notes: the night run of 6 to 7 November (part E) records the eight names on the final tree. The test hygiene of PH36 (the catapult test's heel limit, the re-pinned fin test, the NaN of 782f3e5) belongs here too.

### E01.S03 · A real spin-out: fin ventilation
Status: todo | Size: M | Owner: Michiel | Milestone: M2 | Needs: — | Roadmap: PH6, PH35
Done when: pushing too hard on a reach can end in a sudden spin-out with warning signs a player can learn (the fin's hum, the tail going light), and the autopilot and the AI react to it.
- [ ] T1 The model from the research (`Documentation/reports/research/ph6_ventilation_ph15_wind_shadow.md`): a ventilated share as a state, inception past about 15° with an air path, spread over 3.5 to 7 chord lengths, the lift cut to 0.2 to 0.6, washout below about 2° at 10 m/s (Breslin); the two unsourced numbers (`vent_path_depth_m`, the washout time) marked as estimates
- [ ] T2 Seven tests from the research; the spec's section 4 and check T10 updated
- [ ] T3 The back foot's push against the fin (PH35) as the sailor's lever into the spin-out and out of it
- [ ] T4 The player's warning: the fin's hum stutters (SO1 exists), the tail chatters (GR1), the HUD says nothing (the design's rule 2)
- [ ] T5 The autopilot and the AI recover (ease, weight forward) and the fall records count spin-outs apart from catapults
Notes: Max, 5 November: "this must be done". The catapult, the other risk of pushing, exists already.

### E01.S04 · The wind shadow simulated
Status: doing | Size: M | Owner: Michiel, the lead for the simulation | Milestone: M2 | Needs: — | Roadmap: PH15, PH42, RA31
Done when: the shadow's numbers in `config/wind_shadow_default.tres` come from a simulation, the shadow follows the casting board's apparent wind and turns the wind, and a board leaving a shadow at planing speed no longer catapults for no reason.
- [x] T1 A vortex-lattice run (AeroSandbox) of a sail's wake at the race's apparent winds; OpenFOAM only if the lattice disagrees with the books (done 13 November 2026 another way: a GPU wind tunnel, lattice-Boltzmann with the game's rig as its forces on the air, `tools/wind_tunnel.sh`; a board behind loses about 5 % of its wind at 5 m, 4 % at 10, 3 % at 20; the config set to it on Michiel's OK, option A: `deficit` 0.075, `full_until_m` 1, `stern_bend_deg` 3; [wind_tunnel.md](../../reports/ph15_wind_tunnel/wind_tunnel.md); PH15, in main since `merge/main-13nov-evening`)
- [ ] T2 `WindDisturbance.factor_at()` returns a wind change (speed and direction), not a scalar: the interface change for Michiel
- [ ] T3 The shadow's edge: a wake that widens and weakens over a few lengths; the sheet and the stance meet the returning wind (PH42, RA20's eight crowd catapults)
- [ ] T4 Max's crowd race (RA1's F3 Stop): does the shadow feel right, is 20 s the right penalty
- [x] T5 The shadow along the casting board's apparent wind, as a trail of puffs drifting with the true wind, bent 7° toward its stern (Richards et al. 2012 wind tunnel); length 20 m (Max, 13 November 2026: "this needs to be less, make it 20m"); `Game/race/wind_shadow_trail.gd`, `follows_apparent_wind` in the config; branch `ai/roundings-13nov` (not merged)
- [ ] T6 The more scientific model for later (Max, 13 November 2026: "a backlog add for more scientific approach for later"): the deficit and its decay from T1's simulation or a measurement instead of the books (deficit ∝ 1/√distance, Roncin and Kobus 2004); the header in the wake (about 5° close, T2); the safe-leeward and lee-bow gains (+2 to 3 % within a mast height); several shadows multiplied instead of added; the wake's drift speed (0.9 to 1.0 of the true wind); and checked against a windsurf sail, not only yachts (no wake data exist for windsurf, foil or kite rigs)
- [ ] T7 The skippers adapt to the trail (Max: "the skippers need to adapt. but that is for later"): `WindShadows.factor_from()`, the slalom start's clean-wind spot and the dirty-air tactics still guess the old cone straight down the true wind
Notes: Max, 5 November: "simulate the numbers". Research in `Documentation/reports/research/ph6_ventilation_ph15_wind_shadow.md` (section PH15). 13 November 2026: the research for the trail, with the recommended numbers per source, in `Documentation/reports/racing/dirty_wind_13nov/RESEARCH.md` (branch `ai/roundings-13nov`, pushed 13 November). The trail is on by default there (`follows_apparent_wind`), described in the physics spec's 8.11; Michiel to look at the length, the bend and the puffs' spacing (PH15).

### E01.S05 · The dive after a crest checked against video
Status: blocked | Size: S | Owner: Michiel, Max for the videos | Milestone: M2 | Needs: Max's videos | Roadmap: PH43
Done when: the kit's pitch after a crest in Max's videos matches the simulation's crest tables within the measurement's error, and the air lift's Kv and centre are no longer estimates (or are marked as such with the reason).
- [ ] T1 Max records or finds videos of slalom boards over crests (side view, known wind)
- [ ] T2 Frames and contact sheets with `Documentation/reports/playtest/video_frames.py`; the pitch read per frame
- [ ] T3 Compared with the sim's crest tables (`crest_analysis.py`); the Kv, the centre of pressure and the 20°/s reaction adjusted
Notes: PH43 is in main; this is its check (moved to later on 5 November because there is no video yet).

### E01.S06 · The push's risk in every wind: reaction time, light wind, the rail at planing
Status: todo | Size: M | Owner: Michiel | Milestone: M2 | Needs: E07.S01 | Roadmap: PH25, PH26, PH27
Done when: pushing is risky at 12 and 18 kt as in real life (Max), light wind is not too weak, and the rail's gain at planing speed matches Max's experience.
- [ ] T1 The sailor's reaction time in `Autopilot` (the felt apparent wind lagging), set by the dial and the persona; at 0 bit for bit the same (PH25)
- [ ] T2 Light wind: at 12 kt nothing the sailor does changes the speed or makes a fall; the cause shared with the planing onset (PH26, E01.S08)
- [ ] T3 The heeled hull's lift at short wet lengths (PH27, PH31's rolled plate): which way Max tilts a wide board and what it gains
Notes: Max, 5 November: "comes with the control improvement (GP2)".

### E01.S07 · Legs that give, and the slam on short waves: chop in the physics
Status: todo | Size: L | Owner: Michiel | Milestone: M3 | Needs: — | Roadmap: PH9, PH10, PH11, PH5
Done when: the board can slam and skip under a level body on short chop without overstated slams, so the lake's full chop and the sea's wind waves can be the default everywhere, and absorbing with the knees is an input.
- [ ] T1 The two-body sailor's legs that give in pitch and roll (A-17; spec 17.12 item 1)
- [ ] T2 The strips' slam on waves shorter than three hull lengths: the surface smoothed over the board's width, or a pressure-relief time (PH10)
- [ ] T3 The knees as an input (`SimControls`), for the timing button of E07.S07 (PH5)
- [ ] T4 The open water's wind-made chop and airtime as the default sea (PH11): a board launched off a crest, the fin out, the landing
- [ ] T5 The two manoeuvre cases that still fall on the swell, and the beat that loses a third of its speed on the swell (spec 17.12 item 3)
Notes: this gates how much chop E02 may put under the board.

### E01.S08 · The hull over the hump: the planing onset, the wet length, the clip
Status: todo | Size: L | Owner: Michiel, Max for a photo or a tank measurement | Milestone: M3 | Needs: — | Roadmap: PH16, PH30, PH31, PH32, PH34
Done when: the board planes at the real 8 to 10 kn, rides on 0.6 to 1.0 m of wet length without bouncing, and the strips' "no pull" rule (A-05) is replaced by something measured or by a hump moment of its own.
- [ ] T1 A measurement of a rockered planing bottom (a tank test paper, or a side photo of Max's board at speed against the probe's wet length)
- [ ] T2 The clip (A-05) and the push's centre settled; the strips' damping anchored at a flat plate's scale (PH31)
- [ ] T3 The low-trim bounce understood (the rig's pitch lag held 40 s then bounced)
- [ ] T4 The weight forward until the board has way on (PH32); the nose that spears where Max's rears (PH34)
- [ ] T5 The polar and the onset tests green (E01.S02 T4, T1)
Notes: the hull reports: `Documentation/reports/ph28/hull_balance.md`, `hull_suction.md`, `review_hull.md`; the tool `Game/dev/pitch_budget.gd`; the local draft branch `archive/hull-bounce-draft-30oct`.

### E01.S09 · Pumping, and the gybe's flip
Status: todo | Size: M | Owner: Michiel | Milestone: M3 | Needs: E01.S08 | Roadmap: PH39, PH4, GP9
Done when: a sailor can pump onto the plane from a deep course (as a real sailor does on a broad reach from rest), and a gybe flipped too early stalls while one flipped too late backs and catapults, measured at 12, 18 and 24 kt.
- [ ] T1 The pump as an input: the sail swept to windward and back, the stroke's apparent wind and burst of drive, limited by the sailor's effort and the sail's size (PH39)
- [ ] T2 The gybe's timing measured with `SimControls.hold_side` (GP9: a harness of its own)
- [ ] T3 The flip in the physics checked; changed only if it does not stall and back as it should (PH4)
- [ ] T4 The autopilot and the AI pump out of a lull and off the line (RA: the 12 kt start)
Notes: the player's keys are E07.S05 and E07.S06.

### E01.S10 · Contact between boards, and the bottom under the fin
Status: todo | Size: M | Owner: Michiel | Milestone: M2 | Needs: Q9 | Roadmap: PH12, PH13
Done when: two boards that meet push each other apart, lose speed and may fall, a mark can be hit, and a fin touches the bottom in shallow water, all from the simulation.
- [ ] T1 A soft contact force between hulls (and with a mark): a short push and a loss of speed; the rig's contact as a second step (PH12)
- [ ] T2 A depth the simulation can ask for, so the fin (0.38 m) touches the lakebed near the shore; the scene's shore stop retired (PH13)
- [ ] T3 The game's side: the rules count the touch (E11.S01), the HUD shows "contact", the LAN carries it (E12.S02)
- [ ] T4 Option: damage (a broken fin, a torn sail) only as a career setting (Q9 c)

### E01.S11 · The mast foot and the fin root belong to the board; masts and booms per size
Status: todo | Size: S | Owner: Michiel | Milestone: M5 | Needs: E06.S04 | Roadmap: PH40, PH33
Done when: the physics reads the mast track and the fin box from the board (so a 2.44 m board balances as it should), and the rig's mass and stiffness follow the mast and boom of the sail's size.
- [ ] T1 `BoardConfig`'s mast track and fin box used by `windsurfer_sim.gd` instead of the sail's and fin's own positions (PH40)
- [ ] T2 The rig's mass per sail size from the gear table (the real 12.4 kg question of PH33: how a rider handles a heavy rig in irons)
- [ ] T3 The mast's bend per size inside the twist formula (the 140 Pa estimate per size replaced by a rule with a source)

### E01.S12 · The sea in the simulation: swell, depth, tides and current
Status: todo | Size: L | Owner: Michiel, with the lead | Milestone: M3 | Needs: Q14, E02.S02 | Roadmap: PH44, PH11
Done when: the sim's water interface gives a sea spot its swell, its depth-dependent waves (from E02's offline SWAN fields), a water level that moves with the tide and a current field, and the board, the fin and the sailor answer to them.
- [ ] T1 `WaterSurface` with a depth field and a current field (a slow vector field per spot); the hull's and fin's velocities relative to the moving water
- [ ] T2 The swell from E02's wave fields in the physics (the trains per area, not one Gerstner set for the whole sea)
- [ ] T3 Shoaling and breaking as the hull sees them: a steeper, faster face near the beach; a broken crest as foam and a push (a stand-in with a source)
- [ ] T4 The tide as a water level over the day and the current's turn (for Brouwersdam and Fuerteventura); the river's current for the Gorge
- [ ] T5 The AI and the autopilot sail with a current (the laylines move: E09.S06)
Notes: the physics' sea stays a CPU function of place and time (the research's decision), computed offline per spot.

### E01.S13 · Polars per gear and per sailor weight: the yardstick
Status: todo | Size: M | Owner: the lead, Michiel for the sources | Milestone: M5 | Needs: E06.S04 | Roadmap: GE7, RA21, PH14
Done when: every catalogue board and sail has a measured polar at 12, 18 and 24 kt for three sailor weights, compared with published GPS speeds per class, and the AI and the time trial read it.
- [ ] T1 A night of `tools/push_check.sh --gear_sail --gear_board` over the catalogue (on the second machine, Q45)
- [ ] T2 Published GPS speeds per board width and sail size (GPS-Speedsurfing, PWA tracker data) as the real-world bands
- [ ] T3 The polar table in `Game/config/gear_polars/`, read by the skipper (RA21) and the AI's gear choice (E06.S07)
- [ ] T4 The sailor's weight as a physics choice (Q34): the polars at 65, 80 and 95 kg

### E01.S14 · Code follow-ups and the spec's hygiene
Status: todo | Size: S | Owner: Michiel | Milestone: any | Needs: — | Roadmap: PH19, PH20, PH21, PH22, PH23, PH29, PH36, TE7
Done when: the listed follow-ups are done or closed with a reason, and the live spec is the models, the numbers and the checks (the history in a companion file).
- [ ] T1 The hands' cost: `best_alpha_deg()` searches 21 angles every tick (PH19; the first lever of the big fleet)
- [ ] T2 The fin's sea queries (PH20), `reset()` leftovers (PH21), the buoyancy grid rows (PH22), spray drag (PH23)
- [ ] T3 The body breaks beyond its numbers: a test that reproduces the NaN of 782f3e5; the model degrades instead (PH29)
- [ ] T4 The test hygiene of the three reviews (PH36)
- [ ] T5 The spec split: sections 12, 13, 16 and 17 to an archived companion, links rewritten and checked (TE7, Michiel's call)

### E01.S15 · The feel checklist: what Max ticks on every physics release
Status: todo | Size: S | Owner: Max, written by the lead | Milestone: M2 | Needs: Q7 | Roadmap: RA1, MA1, GR6
Done when: a one-page checklist of pass/fail feel checks (the push's risk per wind, the rail, the gybe, the catapult's warning, the chop, the waves, the lake's wind) exists, each with the condition and the expected feeling, and is filled in for every play build.
- [ ] T1 The checks collected from the play-test reports (`Documentation/reports/playtest/`, the gameplay reports' checklists)
- [ ] T2 The form in `Documentation/backlog/feel_checklist.md` with the build's name and the date per column
- [ ] T3 First filled for the 0.2 build

### E01.S16 · Later: the windward bank in a carve, the yaw flutter, the run angle, the old gust sines
Status: todo | Size: S | Owner: Michiel | Milestone: later | Needs: — | Roadmap: PH37, PH38, PH41, PH24
Done when: each is fixed or closed with a reason.
- [ ] T1 The powered board does not bank to windward in a carved head-up (PH37)
- [ ] T2 The 30 Hz yaw flutter on the steady 18 kt reach (PH38)
- [ ] T3 The race's best run angle 10° deeper than the polar's (PH41, a skipper fact)
- [ ] T4 The sine gusts' jump every period, only if the sines are played again (PH24)

### E01.S17 · Downwind: the board cannot hold planing speed at 135° in Silvaplana's conditions (core physics)
Status: todo | Size: L | Owner: Michiel, the lead builds the tests | Milestone: M2 | Needs: Max's GPS tracks (T5) | Roadmap: PH46
Done when: the sail's drive and the board's drag are each checked against a written source, the polar at Silvaplana has no cliff between 120° and 135° (today 56 km/h in the gusts at 120°, 31 to 33 at 135°), the 117 L / 7.5 m in a 24 kt gust (10 m) makes 50 to 55 km/h across and 55 to 60 at 120 to 135° after a flying start, upwind matches Max's reference, and every regression suite is green or re-baselined with Michiel. The full issue, the evidence and the tests: `Documentation/reports/autopilot/lake_speed/ISSUE_downwind_physics.md` (branch `autopilot/lake-speed` until merged). Max (7 November 2026): "this is the core physics so it needs to be 100% right"; check upwind too.
- [x] T1 P1 the tow test: the board's drag curve 15 to 70 km/h, three gear combos, against a reference drag curve (done another way on 7 November: against Savitsky, see the notes)
- [ ] T2 P2 the sail sweep: lift, drag and drive per apparent wind and angle of attack; the controller's 18° against the best drive
- [ ] T3 P3 the polar at Silvaplana: 45 to 165°, 14 to 26 kt, flat and waves, 0.98 and 1.225 kg/m3, from rest and flying
- [ ] T4 P4 the upwind check: pointing, speed and speed made good at 45 to 65° (today 45° cannot be held, 55° 23 km/h)
- [ ] T5 P5 the real reference: Max's GPS tracks at Silvaplana with the station's wind, a measured polar
- [ ] T6 P6 the regression: unit, check, validation (the polar sweep re-baselined), the night and lake suites, the AI race tests, LAN; then the autopilot retuned
Notes: the 7 November audit (branch `physics/realism-7nov`, report `Documentation/reports/physics/realism_audit_7nov2026.md`). T1: a tow in the game could not be built (with no pull on the hands the posture came apart), so the game's hull in 20 sailing states (the 120 L board, 12 to 24 kt, 45 to 135°) was compared with Savitsky's (1964) planing method for the same load and centre of push (`Documentation/reports/physics/savitsky_check.py`): the game's drag over Savitsky's is 0.97 to 1.01 on the reaches, 0.93 to 1.08 broad, 1.0 to 1.18 upwind. The hull's drag is not the cause; the open question is the attitude (the water's push 0.8 to 1.4 m from the tail, Gourlay's RS:X 0.6 m: 15 to 30 % less drag), decided only by a measured trim or wet length. T4 started: upwind 21 to 38 km/h at 48 to 58° after a flying start (20 and 24 kt, flat water); the fin's flat-plate drag at every slip was a fault (it belongs past the stall only), the fix is a switch, off (E01.S19). Whether upwind is too slow waits for T5.

### E01.S18 · The start's spin: a buried bow pivots the board off the wind at low speed
Status: todo | Size: M | Owner: Michiel, the lead measures | Milestone: M2 | Needs: — | Roadmap: —
Done when: a start from rest on Silvaplana (the player's board, Max's settings, recorded headless with the session recorder) no longer pivots off the wind more than a bar Michiel and Max set (today about 30° at first, about 15° either way since the low-speed fix), the water's yaw moment on a buried bow is checked against a source (or an estimate labelled as one), and the 6 November build's start is the "before".
- [ ] T1 The start re-recorded and the moments logged (today at 2.5 s and 7 km/h the nose is 0.24 m under and the water's yaw moment is 280 to 413 N m; the autopilot's helm at its stop cannot hold it)
- [ ] T2 Which part of the hull model gives the yaw (the bow's side force and its lever), and what the real one would be
- [ ] T3 The fix, switchable, before and after over several start times; the lake suite's starts and the night suite's guards
Notes: found 7 November 23:40 with the session recorder (E17.S10); the 6 November evening-keys build (f72f565) does the same, so it is old hull physics, not this week's controller. Max: "much much better, in the beginning there was a little thingy", then "leave it" (for now).

### E01.S19 · Michiel's review of the 7 November physics switches: the balance stance and the fin's plate drag
Status: review | Size: M | Owner: Michiel | Milestone: M2 | Needs: — | Roadmap: —
Done when: Michiel has read `physics/realism-7nov` (the audit report and its commits) and decided for each switch: on, off or retuned. If one goes on, the steering and the autopilot are retuned on it and every suite is green.
- [ ] T1 The balance stance (`SailorConfig.stance_dive_full_deg`; Settings > Sailing > Balance stance (test)): the strong starts' dive -13 to -10°, planing 8.1 to 5.8 s, the reaches the same; but rare falls in turns. Max plays it on and off first
- [ ] T2 The fin's flat-plate drag only past the stall (`FinConfig.cd_plate_post_stall`, after Viterna and Corrigan 1982): upwind +0.7 to +0.9 km/h, the beam reach the same; switched on, the Shift tacks fell and the AI was slower, so the steering needs retuning on it
- [ ] T3 The branch merged with the team after the review (the controller part is E07.S12)
Notes: branch `physics/realism-7nov`, pushed (9e97706 on 8 November), from `autopilot/lake-speed`. Both switches are off by default, so the physics is bit-for-bit as before until Michiel decides.

### E01.S20 · The sail's twist beyond its data, the legs' porpoise on flat water, the waves' cost
Status: todo | Size: M | Owner: Michiel | Milestone: M3 | Needs: — | Roadmap: —
Done when: each of the three is checked against a source or a measurement and fixed or closed with a reason, with before and after numbers.
- [ ] T1 The sail's twist under load: the law 1/(1+q/125) is fitted to the wind tunnel's 8 m/s and used up to 17 m/s; find data at higher apparent winds, refit or bound it
- [ ] T2 The legs: at 135° on flat water the board porpoises (the legs at 1.2 Hz, damping 0.9); softer legs removed it in the audit; choose the numbers from a source and check the chop (E01.S07)
- [ ] T3 The waves' cost in a steady wind (17 to 24 % downwind, 11 to 14 % across): against a source or Max's GPS tracks (E01.S17 T5)
Notes: the 7 November audit's findings D and E and the legs, `Documentation/reports/physics/realism_audit_7nov2026.md`.

### E01.S21 · The lake's north-east corner: a board on starboard crawls
Status: todo | Size: S | Owner: Michiel | Milestone: M2 | Needs: — | Roadmap: —
Done when: it is known why a board on starboard in the north-east of Silvaplana (game x 850 to 1050, z -940 to -1100, 14 to 16 kt at the sail) crawls at a close reach with the fin slipping 7 to 44 degrees and falls off at a standstill, while on port at the same spot it does 6 to 9 m/s; fixed, or explained and left.
- [ ] T1 Reproduce on `ai/skipper-heads-8nov`: `run_race.gd -- --course=iq_pd3 --map=lake --time=14:30 --skippers=persona:hana --spawn=anywhere --spawn_seed=20 --seed=1 --trace=Hana`
- [ ] T2 The cause: the lake's own waves at the long-fetch end, the local wind, the depth
Notes: found 8 Nov 2026 evening by the start-from-anywhere suite (three boards trapped; Bruno fell 12 times on I2). On open water port and starboard are equal (upwind 6.99 against 6.92 m/s, the fin slip 6.5 against 6.2 degrees). Report: `Documentation/reports/racing/heads_8nov/RESTART.md` on `ai/skipper-heads-8nov`.
