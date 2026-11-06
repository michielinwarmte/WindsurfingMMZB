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
Status: todo | Size: M | Owner: Michiel, the lead for the simulation | Milestone: M2 | Needs: — | Roadmap: PH15, PH42
Done when: the shadow's numbers in `config/wind_shadow_default.tres` come from a simulation, the shadow follows the casting board's apparent wind and turns the wind, and a board leaving a shadow at planing speed no longer catapults for no reason.
- [ ] T1 A vortex-lattice run (AeroSandbox) of a sail's wake at the race's apparent winds; OpenFOAM only if the lattice disagrees with the books
- [ ] T2 `WindDisturbance.factor_at()` returns a wind change (speed and direction), not a scalar: the interface change for Michiel
- [ ] T3 The shadow's edge: a wake that widens and weakens over a few lengths; the sheet and the stance meet the returning wind (PH42, RA20's eight crowd catapults)
- [ ] T4 Max's crowd race (RA1's F3 Stop): does the shadow feel right, is 20 s the right penalty
Notes: Max, 5 November: "simulate the numbers". Research in `Documentation/reports/research/ph6_ventilation_ph15_wind_shadow.md` (section PH15).

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
