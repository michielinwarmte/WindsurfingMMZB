# Max's play-test of 0.2.0-beta.1 (5 November 2026): what was found, nothing built

For Max and Michiel. Written 5 November 2026 by a Fable session on the branch `gp/sea-follows-wind` (the beta Max plays from `WindsurfingMMZB-speelversie-2nov2026`), after Max's feedback: the many game folders, the fin "way too flexible", LAN multiplayer to be tested on his other PC, package B (the body on the mouse) to be tried, and the nose diving after a wave's crest. Sections 1 to 7 are the investigation (nothing changed in the game); **section 8 is the same evening's research and build** on the branch `ph43/airtime-fin`, which corrects section 3's suspicion about the fin's shape. Every number below is measured on the sim or quoted from a source; an estimate says so.

## 1. In short

| Point | What was found | Whose fix |
|---|---|---|
| The folders | Not copies gone wrong: they are git worktrees (one per builder branch, as CLAUDE.md asks), the play copy and the beta build. Nothing to delete; see section 2 | Max says which may go |
| The fin | The beam bends **along its whole length** (30 % of the tip's angle comes from the root fifth, 5 % from the tip fifth), because its thickness is a fixed 10 % of the chord. At the game's loads (580 to 790 N at 24 kt) the tip moves 60 to 90 mm, 16 to 23 % of the span, and in a spike the drawn bend has no cap. Max's point stands. Twist is already infinitely stiff | Michiel (`Game/sim`), after one measurement by Max |
| LAN multiplayer | **Does not exist**: no network code on any of the 35 branches; the roadmap has it under "Later" (PR4). It cannot be tested yet. The other PC is off the network today; a plan and the test path are in section 4 | the team: a design first |
| Package B | Not built (GP2), but Session 62 built its hooks in the sim (PH3): two fields that add degrees of rail and trim on top of the technique, which the push slider already uses. The mouse can be wired to them with no physics change. A design with a learning curve is in section 5 | an AI session, on a branch |
| The dive after a crest | Reproduced on the sim: at 18 kt on the biggest swell the nose goes from +9.5° to −1.9° in 0.3 s (−27°/s) as the water lets go. The cause is in the model: the rigid body is the bare 7.8 kg hull (3.4 kg·m² in pitch) while the whole kit is about 74 kg·m²; when the hull leaves the water the legs go light, the mast foot's nose-down push wins, and there is no air force on the hull at all | Michiel (`Game/sim`) |

## 2. The folders in `source`

| Folder | What it is | Branch |
|---|---|---|
| `WindsurfingMMZB` | the main checkout | `ph28/sail-and-hull` |
| `WindsurfingMMZB-sail`, `-rider`, `-hull` | the three Fable builders' worktrees of Session 61 (30 October), their WIP pushed, not merged | `ph28/real-eight`, `ph28/rider-feet-body`, `ph28/hull-suction` |
| `WindsurfingMMZB-lead` | the lead's worktree of Sessions 62 to 67: the push slider, the gear, the fleet, the time trial, the waves. **The newest code; the beta was built from it** | `gp/sea-follows-wind` |
| `WindsurfingMMZB_step15`, `WindsurfingMMZB-hull-bounce-ea672f4` | two detached worktrees used to run the same tests on older code (step 15, the bounce) for comparison | detached |
| `WindsurfingMMZB-speelversie-2nov2026` | the beta build to play (`wsim.exe`), not a repository | — |
| `WindsurfingSimulator-0.2.0-beta.1-windows[.zip]` | the beta's zip and its unpacked copy, the release on hold (GR8, the waves 90° off) | — |

CLAUDE.md's rule is that agents work in their own worktrees and that branches and worktrees are not deleted; `git worktree list` in any of them shows the set. The worktrees of finished branches can be removed with `git worktree remove` when Max says so; the branches stay.

## 3. The fin

**What the model is** (`Game/sim/fin_model.gd`, PHYSICS_SPEC.md section 4 "The fin bends", U2, 19 October 2026). A cantilever beam clamped at the hull bottom, with the bending stiffness `EI = S · c(y)⁴`: a thin section's stiffness goes as the chord times the thickness cubed, and the thickness was taken as a **fixed 10 % of the chord** along the whole span (14 mm at the root, 7 mm at 80 % of the span, 0 at the rounded tip). `S` is set so the beam repeats one lab test: a 37 cm F-Hot carbon slalom fin, 100 N hung at 80 % of the span, 20 mm at the load point (Nascimento 2017, IST Lisbon). The lift is spread elliptically from the root. Every strip pushes square to itself, so a bent strip pushes partly up: that is the fin's upward force from the bend. There is no twist in the model: a bend-twist coupling was left out on purpose, so in twist the fin is infinitely stiff, which is what Max describes for a carbon layup.

**Where it bends** (the game's beam redone outside the game, `fin_beam.py`; the same formulas, the same numbers: root chord 14.0 cm, `S` 2.23·10⁵ N/m², `EI` at the root 86 N·m²):

| Part of the span (root to tip) | Share of the tip's angle gained there |
|---|---|
| 0 to 20 % | 30 % |
| 20 to 40 % | 27 % |
| 40 to 60 % | 23 % |
| 60 to 80 % | 15 % |
| 80 to 100 % | 5 % |

So the model's fin bends from the root, like a blade of one thickness, with two thirds of the bend in the inner 60 %. The spec says "where the chord is 37 % of the root's the fin is 53 times softer: that is why fins bend at the tip", but the bending moment is also far larger at the root, and the beam's curvature (moment over stiffness) comes out spread along the span. That is Max's point exactly: a real fin has a thick, stiff root and a thin tip, and bends more and more toward the tip.

**How much it bends.** Per 100 N of lift the tip turns 2.6° and moves 11 mm; everything is linear in the load up to a 35° cap on the angle. The fin's loads in the game, from the runs of section 6 (the beginner at 75 %, straight at 100°, the biggest swell):

| Run | Fin lift median / 90th percentile / max | Tip angle median / max | Tip movement at the median |
|---|---|---|---|
| 18 kt | 326 / 489 / 672 N | 8.6° / 17.7° | 36 mm (9 % of the span) |
| 24 kt | 577 / 637 / 792 N | 15.2° / 20.9° | 63 mm (17 % of the span) |

On the flat-water 18 kt beam reach the fin carries about 690 N (`test_fin_bend.gd`'s pin): 18°, 76 mm, 20 % of the span. At 1 000 N: 26°, 110 mm; the 35° cap is reached at 1 330 N. **The drawn bend has no cap:** `FinModel.bend_tip_m` is the load times 0.11 mm/N with no limit, and the shader draws it (`rig_visuals.gd`, `bend_fin`), so a load spike in chop (the launch of Session 59 had 4 900 N on the fin) draws a tip half a metre out of line. The fin's loads are themselves at the top of what the sources allow: Fagg (1997) gives 300 to 600 N on a planing board, and the validation suite already has a red for 677 N against a 650 N band.

**What the spread bend does to the board.** The upward force from the bend is `F · Σ share_i · sin(θ_i)`, and the root strips carry most of the elliptic load. A fin that bends from the root turns those heavily loaded strips, so the model's upward push is large: 113 N against 41 N for a stiff fin on the 18 kt beam reach (spec, section 4), up to 258 N in the 18 kt run above. PH16 found that this push, acting at the fin behind the centre of mass, **lifts the tail and drops the nose** (0.15 to 0.2° of trim, the wet front 5 to 8 cm forward). A fin bending at the tip only would turn lightly loaded strips and push up less. So the fin's shape also feeds the nose-low ride and the dive of section 6.

**The one real test the calibration rests on is a soft fin for slalom** (hull_balance.md section 10 said so too), and the 3-D model's thickness taper (10 % at the root to 8 % at the tip) is left out of the beam on purpose (spec, section 4, "Left out"). The five gear fins (`Game/gear/fins/montag_slalom_*.tres`) all carry the same flex test, so they are the same material in different sizes.

**What to do (Michiel's, `Game/sim/`; small once measured):**

1. **Max measures his fin** (the spec's section 14 asked for this; `fin_sources.md` point 4): clamp the base as in the box, hang 10 kg at the tip, measure how far the tip moves; and the thickness with callipers at the root, at mid span and 5 cm from the tip. The model's 38 cm fin moves **53 mm** under 10 kg at the tip (this report's beam; the spec's earlier estimate said 44). His number replaces the five `flex_test_*` values, as the spec intended.
2. **A thickness that tapers along the span** in the beam: `EI = S · c(y) · t(y)³` with the thickness ratio falling from the root to the tip (Max's callipers give the law; the 3-D model's 10 to 8 % is the least to do), and the first centimetres above the root stiffer still (the box and the hull clamp the root). This moves the bend to the tip and lowers the upward push. The flex test's calibration stays the same code (`calibrated_stiffness_scale`), so `S` follows.
3. **Cap the drawn deflection** at what the 35° cap allows (about 165 mm on the 38 cm fin), in `rig_visuals.gd`, so a load spike never draws a rubber fin. Visual only, no OK needed.
4. Leave twist out, as it is: Max confirms a carbon fin is stiff in twist.

Tests: `test_fin_beam.gd` (the calibration repeats the flex test, the tip-load formula within 1 %) and the validation `test_fin_bend.gd` (the pinned stiff numbers do not change; the bend is there). Then the reach check, because the upward push and the trim will move.

## 4. LAN multiplayer

**There is nothing to test.** Searched: every branch tip (35 branches, local and on origin) for Godot's networking classes (`ENetMultiplayerPeer`, `MultiplayerAPI`, `@rpc`, `WebSocketPeer`, `PacketPeerUDP`), the commit log of every branch for "multiplayer", "LAN", "two players", and the changelog and progress log. The only network code in the game is the training worker's TCP link to Python (`Game/dev/train_worker.gd`). The roadmap lists multiplayer under "Later" (PR4, "the rebuild plan: multiplayer, a rigged sailor, more boards and sails") with no design. The beta's release notes list it nowhere.

**The other PC is not reachable today.** This PC is `DESKTOP-M8EC7T0` (192.168.1.30). Tailscale is installed on both PCs: Max's account lists `max-school` (Windows), most likely the `maxba` PC, **offline, last seen a day ago**. On the LAN nothing answers as a Windows PC with remote access: 192.168.1.5 is the NAS, .172 a Linux VM, .253 an embedded device, .3 the router's share; five addresses answer ping only. So there is no way in from here until Max switches that PC on and opens one door: Tailscale SSH, Windows' OpenSSH Server, or simply a Claude Code session running there (then this session can message it and ask it to start the game and read its log).

**What LAN play would take** (a plan, not a brief; effort M to L, a few sessions):

1. **Host and join.** One PC hosts (`ENetMultiplayerPeer.create_server`), the others join by IP; a LAN lobby finds hosts by a UDP broadcast every second (`PacketPeerUDP`), so nobody types an address. A page in the main menu: Host / Join / the list.
2. **Every PC sails its own board** with the full physics (rule 7: the same physics, the same controller), as the AI boards already do on threads, and sends its board's state 20 times a second: position, attitude, speed, the sail's and the rig's state, the sailor's posture and the telemetry the HUD and the sounds need. The other boards are drawn as "remote boards", interpolated between packets, the way AI boards are drawn now (`race_runner.gd` already draws boards it does not simulate at full rate).
3. **The host owns the race:** the course, the start sequence, the marks rounded, the rules and the penalties, the finish; and **the sea and the wind:** the settings, the wave set and the gust field's seed go to every joiner, so all PCs sail in the same water (the gust patches are seeded, so this is a seed, not a stream).
4. **No collisions** (there are none now), so no reconciliation of touches is needed in a first version.
5. **Tests without a second PC:** two instances of the release build on one PC (`--host=1` and `--join=127.0.0.1`), the second in a window or headless, and the pair's logs compared: the joiner's view of the host's board against the host's own telemetry.

**How I would test it on two PCs**, once it exists and the other PC is reachable: start the host here with `tools/play.sh`'s race, start the joiner on the other PC over SSH (`wsim_console.exe --join=192.168.1.30 --autopilot=1`), let both sail the same course for a few minutes, and compare the two logs: the remote board's place against the local one, the packet rate and the lag, the race results agreeing. A screenshot from each side with `tools/screenshot.sh` for Max.

## 5. Package B: the body on the mouse, with a learning curve

**What exists.** The design (`Documentation/gameplay_controls_v0.2.pdf`, Tarpie, 23 October): one stick or the mouse is the sailor's body; sideways the rail and the carve, forward and back the fore-aft trim, a button to absorb a wave; a virtual centre that springs back, so the mouse never runs off the desk. The roadmap's GP2 (an experiment on a branch, no physics change) and GP0's measurements (`reports/gameplay/gp0_measure.md`): the rail 0 to 8°, the trim 0.5 to 3.5°; **the back foot is the big one:** 3 to 3.5° of trim is 10 % faster than the technique's 2° on the 18 kt broad reach in gusts and waves and 20 % faster in steady wind; too much trim bounces first (the warning) and catapults at 24 kt; the flattest board is fastest once planing, and rail buys stability: at 24 kt, 3° of trim on a flat board catapults, with 5 to 6° of rail the same trim is safe and the fastest of all. "As flat and as far back as you dare, more rail when it gets wild."

Since then Session 62 built the hooks (PH3): `SimControls.rail_bank_extra_deg` and `trim_aim_extra_deg` add degrees on top of the technique's bank and trim targets (`_fin_load_bank_rad`, `_trim_aim_deg` in `windsurfer_sim.gd`), 0 = bit for bit the technique; the push slider sets them through `PushDial.apply_level` (at the top of the ladder +1° of rail and +0.5° of trim) and `PlayerController._move_the_slider` adds the sea's rail. So GP2 no longer needs to write the config: the mouse writes the same two fields, added to the slider's. Also built: `SimControls.back_foot_push` (PH35, a steering lever, not a fin-loading one) and the front foot's pull (PH28), both of which a later level could use.

**The design proposed, in steps the player climbs:**

| Step | The player does | The game | Why it is learnable |
|---|---|---|---|
| 0. Touch nothing | steers with A/D, pushes with Up/Down | the technique sails the rail and the trim as in 0.1 | as today; a beginner never has to use the mouse |
| 1. The back foot | mouse back = more weight on the tail (trim +0 to +1.5° on the technique's), mouse forward = less (down to −1.5°) | the nose rises, the wet part shortens, the board gets faster, then starts to bounce, then catapults at 24 kt | a 10 to 20 % prize on the broad reach, with the bounce as the warning before the fall; the sweet spot moves with the wind, so it stays a skill |
| 2. The rail | mouse sideways = the leeward rail down (0 to +6° on the technique's), the other way flat | flat is fastest on the reach; railed is safer in chop and gusts, and loads the fin (its hum from SO1 is the signal) | the player learns "flat when it is steady, rail when it gets wild" from the spray, the sound and the falls |
| 3. The sea's rail by hand | the automatic rail for the sea (`wave_rail_deg`) switched off above a slider level, so the player must add rail in waves | | a difficulty step inside strong wind, as GP0's "level 2" was |
| 4. Absorb (GP7) | a mouse button as the nose meets a face: the knees give and the weight goes forward for a moment | the board stays in the water, the fin keeps grip; too late launches it | needs PH11 and the dive of section 6 fixed first; this is where package B meets the waves |

Design rules, from the PDF and the roadmap: the mouse is captured while sailing (Esc releases it; a setting turns package B off); a virtual centre that springs back to the technique over 1 to 2 s, so letting go sails itself; the full range over about 300 px of mouse travel (a setting); the orbit camera's right-drag moves to a held key; **no HUD indicator** (the F1 panel shows the two numbers for tuning only); the ranges clamp inside GP0's measured bands, so the mouse cannot ask for what the feet cannot hold; the mouse does nothing out of the straps or in a turn (the targets act only there), so the manoeuvres stay as they are. The gamepad's right stick gets the same mapping (GP5). What pays and what it costs come out of the existing physics: the bounce, the catapult, the spin-out, the slower railed board.

**Open choices for Max** (GD7 and GP3): the trim's range (±1.5° is inside GP0's band, ±1° is gentler); whether the rail goes both ways (a windward rail is slower everywhere once planing, and PH27 says the hull's heeled lift is still uncertain); the spring-back time; the mouse's sensitivity; which level is the default.

**Build:** `windsurfer/player_controller.gd` (the mouse axis, the spring-back, the clamps, added to the slider's extras), `project.godot` (the capture, the camera key), `camera/camera_rig.gd` (the orbit's key), `ui/` (a Controls toggle and the ranges), a HUD line in the F1 panel, unit tests that set the mouse by values (no device). No file in `Game/sim/`. Effort M. Then Max plays it with GP3's checklist: could you just go, did the back foot pay, did you see the fall coming, could you find and hold the rail.

## 6. The dive after a crest

**Reproduced.** `tools/matrix.sh --only=straight --winds=18,24 --waves=1 --wave_scale=3 --every=2` on this branch: the beginner controller at 75 % straight across the wind, the default sea with every amplitude times three (the menu's biggest swell: the 14 m swell at 0.24 m amplitude), 45 s each. The CSVs are in the session's scratch folder (`matrix_waves/`), read crest by crest with `crest_analysis.py` (a crest: the water under the board at a local maximum over a second).

| | 24 kt | 18 kt |
|---|---|---|
| Crests passed | 12 | 5 (then a catapult at 12.7 s) |
| Water height at the crests | 0.07 to 0.10 m | 0.13 to 0.30 m |
| Pitch drop from the crest to the next trough, median / max | 2.9° / 4.4° | 7.5° / 11.7° |
| Pitch rate in the 0.3 s after a crest | −2 to −9°/s | −4 to **−27°/s** |

The sharpest one, 18 kt, the crest at 7.3 s, read from the CSV every 0.1 s:

| t (s) | wave (m) | pitch (°) | planing lift (N) | buoyancy (N) | wet length (m) | feet's force (N) | feet's nose-up moment (N·m) | mast foot's nose-down (N·m) |
|---|---|---|---|---|---|---|---|---|
| 7.02 | 0.21 | +8.2 | 1 250 | 309 | 1.22 | 730 | +330 | −88 |
| 7.12 | 0.25 | +9.5 | 777 | 193 | 0.91 | 540 | +165 | −85 |
| 7.22 | 0.25 | +8.9 | 354 | 77 | 0.59 | 494 | +112 | −78 |
| 7.32 | 0.26 | +6.2 | 127 | 14 | 0.32 | 391 | −39 | −62 |
| 7.42 | 0.23 | +0.6 | 14 | 2 | 0.29 | 351 | −15 | −44 |
| 7.52 | 0.21 | −1.9 | 131 | 29 | 1.37 | 553 | +127 | −57 |

The board rides up the face nose-high (+9.5°), the water lets go at the top (the planing lift from 1 250 to 14 N, the buoyancy to 2 N, the wet part to 0.3 m), and in 0.3 s the nose is down to −1.9° and the board slams onto the back of the wave with the wet length jumping to 1.4 m. The feet's force on the tail, which holds the nose up, halves as the hull drops away from the body (730 to 351 N), its nose-up moment goes from +330 N·m to nothing, and the mast foot's nose-down push (−45 to −90 N·m: the rig pressing down, the harness pulling the rig) is what is left.

**Why the model does this, and what real life has that it lacks:**

1. **The rigid body is the bare hull.** `MassModel` says so: the simulation's rigid body is the board alone, 7.8 kg, **3.4 kg·m² in pitch**; the sailor is a body of their own on the legs' spring (1.2 Hz, damping 0.9), the rig hangs between the mast foot and the hands. The whole kit, by the model's own inertia formulas at a full hike, is about **74 kg·m²** in pitch, 22 times the hull (an estimate from the model's numbers: the 85 kg sailor at the hike's height and the 9.5 kg rig 1.8 m up). A 60 N·m moment turns the bare hull at about 1 000°/s² and the kit at 47°/s². On the water the added water mass and the planing strips' damping hold the hull; in the air nothing does, so it pitches to wherever the legs and the mast foot push it within a tenth of a second. Real life is the other way round: on a launch the rider's feet are in the straps, board and rider leave the crest as one 100 kg body with the nose-up turn it took off with, and that angular momentum is Max's "weight moment to keep going up for a short time".
2. **The legs go light.** The legs are a spring between the body and the deck. At the crest the water throws the hull up; the body lags; after the crest the body is still moving up while the hull is not, the spring unloads and the feet's push on the tail drops. The straps hold the front foot's pull only as a bounded pitch moment (PH28, `_feet_pitch_within_straps`: 150 N held, 400 N briefly, times the straps' 0.59 m), and the front foot's couple (`_front_foot_couple_nm`) acts only while the **felt** trim (averaged over 1.5 s) is below the aim, which after a crest it is not. So the rider does not pull the nose up on a launch; a real rider does it in anticipation.
3. **No air on the hull.** The only air force in the sim beside the sail is the sailor's windage. A board flying nose-up meets the apparent wind on its bottom. Estimate (a flat plate of 1.64 m², aspect ratio 0.32, in 15 to 20 m/s of apparent wind at 10 to 15° of attack): 35 to 90 N of lift, ahead of the board's centre, so 25 to 120 N·m nose-up depending on the lever (the hull's centre or the kit's centre of mass). That is the same order as the mast foot's nose-down push, and it is zero in the game.
4. **Trimming by feel may walk forward.** After a crest the nose is above the aim, and the feel moves the weight forward at the release rate (0.3 m/s) rather than the slow search rate; the 1.5 s averaging mutes it. The press is not in the CSV, so this is a suspect, not a finding.

The roadmap already holds the airtime question in PH11 ("check a board launched off a crest, its fin out of the water, and the landing") and GP7 says the physics cannot carry the absorb yet; this run gives both their first numbers.

**What to do (Michiel's, `Game/sim/`; effort M):**

1. **Board and rider as one body in pitch when the hull is unloaded:** add the sailor's and the rig's pitch inertia to the hull's (`_inertia_with_added_water` is where the added terms go) in proportion to how far the feet are in the straps and how little the water carries (the planing ratio), so that on the water the hull keeps answering the legs as now (the Session 60 bounce lock depends on it) and in the air the kit turns slowly, with the nose-up rate it left the crest with. Check: the 18 kt run above keeps its nose up over the back of the 7.3 s wave; the flat-water reach check and the bounce lock unchanged (the inertia only adds in the air).
2. **The front foot pulls on a launch:** the front foot's couple from the pitch *rate* as well as the trim (the rider pulls up when the nose starts dropping fast), inside the 150 N held / 400 N brief bounds already there. Check: the feet's nose-up moment in the table above stays positive through 7.3 to 7.5 s.
3. **Air under the board:** a flat-plate lift and drag on the hull's dry bottom from the apparent wind, scaled by the part of the hull out of the water, acting at the plate's centre of pressure. Small on the water, a nose-up help in the air. A source for the plate's coefficients at low aspect ratio is needed (Hoerner's "Fluid-Dynamic Lift" has them; an estimate until then).
4. Then **the absorb** (GP7) can be built on it.

Measured before and after with the two runs above (the median and the worst pitch drop per crest, the pitch rate after the crest, the falls), the reach check and the validation suite; then Max on the biggest swell.

## 7. The order proposed

1. **The fin** (small, Michiel's OK): Max's two measurements (10 kg at the tip; the thickness at three stations), then the thickness taper and the root clamp in the beam, the drawn bend capped. A day's work once the numbers are in.
2. **The dive** (M, Michiel's OK): the inertia in the air, the front foot on a launch, the air under the board; measured on the triple swell runs. This also unlocks the absorb and the waves for package B's step 4.
3. **Package B** (M, an AI session, no physics): GP2 on a branch with the design of section 5, Max's choices as settings, then his play-test with GP3's checklist.
4. **LAN multiplayer** (L): a design brief first (section 4), the other PC made reachable, then the build and the two-PC test.

Tools used: `tools/matrix.sh` (this branch), `crest_analysis.py`, `fin_beam.py` and `inertia_and_loads.py` (copied next to this report; the two wave CSVs stay in the session's scratch folder, 1 MB each, and `tools/matrix.sh` makes them again in 22 s), `tailscale status`, a LAN port scan.

## 8. The same evening: the research, the build and the measurements (PH43)

Max's answers: he cannot measure a fin; the dive is what causes the crashes in waves; LAN multiplayer was investigated on another PC but not pushed; he will send videos of boards over crests (the frame tool is ready: `video_frames.py` next to this report). So the fin and the dive were researched from sources and built on the branch `ph43/airtime-fin` (begun from `gp/sea-follows-wind` at 5d97994 and moved onto its tip 12ca5f1, the laptop's Session 68 with the waves fixed, once that was fetched; in the worktree `WindsurfingMMZB-fix`), not committed, for Michiel's OK. The play build is `WindsurfingMMZB-speelversie-5nov2026/` (its LEESMIJ says what to try). PHYSICS_SPEC.md: section 4 (the fin, a new paragraph) and the new section 7.6; ROADMAP PH43.

### 8.1 The fin: measured, and not too soft after all

The three IST Lisbon theses were read in full ([F1] Nascimento 2017, [F2] Cardoso de Brito 2021, [F7] Santos 2018; all on the same F-Hot 37 cm carbon slalom fin). What they say:

| What | Measured | Source |
|---|---|---|
| Two point-load tests at the quarter chord | **55.2 N/mm at 40 % of the span, 5.0 N/mm at 80 %** (100 N moves the 80 % point 20 mm) | Nascimento 2017, figures 4.5 and 4.6 |
| Their ratio, the one measured number for where the fin bends | **11.05**; the game's beam (`EI = S c⁴`) gives 11.67, a uniform blade 8.0; the power that repeats both tests is 3.55 | `fin_fit.py` |
| The thickness along the span | **8.2, 8.2 and 8.3 % of the chord** at 100, 200 and 300 mm from the root: the same share everywhere, "almost a constant profile" | Santos 2018, table 3.1 |
| The quarter-chord thickness by station | 7.5 mm at the root, 6.65 at 176 mm, 5.36 at 264, 3.11 at 352 mm: it falls with the chord | Cardoso de Brito 2021, table 3.1 |
| The layup | 19 layers a side: 11 unidirectional carbon along the span, 5 E-glass along, 3 woven carbon at 45° | Cardoso de Brito 2021, section 3.1 |
| The tip's movement sailing (FEA calibrated on the tests) | 61 mm at 20 kn and 4° (594 N), 98 mm at 25 kn and 4°, 143 mm at 25 kn and 6° | Cardoso de Brito 2021, tables B.5 and B.6 |

So the game's fin bends where the real one bends (both tests within 6 %), its fixed thickness share is what the real fin has, it is stiff in twist like a carbon layup (the model has no twist at all), and its softness is that fin's measured softness: the beam's 0.11 mm/N is the thesis's 0.10. **Nothing in the force was changed.** Section 3's suspicion about the shape was wrong. The peterman.dk formula-fin table (17 fins, 20 kg at the tip, the deflection read at the quarter points) could not be used for the shape: its deflections are nearly linear along the span (25, 56, 75 % of the tip's at the quarter points), which a clamped beam cannot do, so the clamps gave.

Built: the drawn tip's movement capped where the beam's angle cap is (165 mm on the 38 cm fin; a load spike in chop drew a rubber fin), and a Settings > Sailing slider "Fin stiffness" (0.5 to 4 times the measured fin, `FinConfig.stiffness_factor`, on the player's own copy; the AI boards keep 1), since Max cannot measure his: he finds the fin that feels like his, and that number is then his fin's. Tests in `test_fin_beam.gd`.

### 8.2 The dive: built as three options, on by default, off bit for bit

| Option | What it does | Default |
|---|---|---|
| `SailorConfig.launch_carry_share` | As the hull's load collapses, the rider's and the rig's pitch inertia join the hull's (the kit's 74 kg·m² instead of 3.4), fading in from where the hull carries half of what it has been carrying lately (`launch_load_memory_s` 2 s; the weight is no yardstick, because the rig and the fin carry up to two thirds of it in steady planing), times the stance. The rider joins with the hull's pitch rate. The trim press holds in the air | 0.5 |
| `SailorConfig.front_foot_react_dps` | The front foot pulls up at once when the nose drops fast, the whole held pull from 20°/s down, inside the straps' bounds | 20 |
| `BoardConfig.air_lift` | The apparent wind on the dry bottom, a low-aspect-ratio plate (Polhamus 1966 with Jones' slope; Kv 3.14 and the centre at 0.4 of the dry length from the nose are estimates). Tens of newtons up and nose-up on a flying board, 10 N on the water | on |

Tests: `test_launch.gd` (8). `tools/test.sh` 697 of 698 on the first build (the one red was an old check that now holds the hull still); the touched files re-run green afterwards (`test_launch`, `test_fin_beam`, `test_front_foot`, `test_trim_by_feel`, `test_game_settings`, `test_menus`, `test_hud`); the full suite (9 minutes) and the validation suite were not run again after the last change. `tools/check.sh` 406 files, 0 failed.

**Measured** (`crest_summary.py`; the beginner at 75 % straight across the wind, 45 s; "drop" is the pitch from a crest to the trough after it, "rate" the sharpest nose-down rate in the 0.3 s after a crest):

| Sea, wind | Falls | Drop median / max (°) | Worst rate (°/s) | In the air (s) | Speed (m/s) |
|---|---|---|---|---|---|
| Biggest swell (×3), 18 kt, before | 1 (a catapult at 12.7 s) | 8.6 / 18.2 | −45 | 0.67 | 7.42 |
| Biggest swell, 18 kt, after | 1 (a catapult at 27.7 s) | 8.5 / 13.3 | −28 | 1.07 | 6.96 |
| Biggest swell, 24 kt, before | 0 | 2.9 / 4.4 | −12.5 | 0 | 13.23 |
| Biggest swell, 24 kt, after | 0 | 1.9 / 3.8 | −10.0 | 0 | 13.34 |
| Swell ×2, 18 kt, before / after | 0 / 0 | 1.2 / 5.0 → 0.9 / 3.7 | −11.5 → −8.5 | 0 | 11.88 → 11.94 |
| Swell ×2, 12 kt, before / after | 0 / 0 | 7.3 / 11.0 → 10.1 / 11.2 | −22 → −24 | 0 | 6.82 → 6.77 |

The dive is slower and the board flies longer, as Max describes, and it no longer drops the nose more than 4° on the double swell; on the biggest swell at 18 kt it still catapults once, 15 s later than before. (An earlier build of the coupling with the weight as its yardstick had no fall there at all, but it switched itself on and off on flat water and bounced the 24 kt close reach; it was replaced by the hull's own recent load.) The flat-water reach check (`reach_compare.py`): every case within 1.0 % (the 24 kt close reach −1.0 %, its pitch SD 0.06 → 0.30°; the 18 kt beam reach's 0.09 → 0.23°), so the coupling still touches the two bounciest reaches a little: for Michiel. With the three options off the reach check is the base bit for bit (checked).

**What is left for the dive**, in order: Max's videos against the crest tables (how long a real kit keeps its nose up, and how far it drops); the rig's forces on a flying kit (the mast foot's nose-down push stays on the hull while the hands' pull on the body has no pitch lever: −45 to −90 N·m that a one-body kit would take through the harness); the ground effect of the water under a flying bottom; then the absorb (GP7).

Sources read this evening: [F1] https://fenix.tecnico.ulisboa.pt/downloadFile/1689244997257679/ResumoAlargado_73133.pdf ; [F2] https://fenix.tecnico.ulisboa.pt/downloadFile/281870113705481/Master_Thesis_83711.pdf ; [F7] https://fenix.tecnico.ulisboa.pt/downloadFile/1970719973968155/full_doc_-_9178_eco_version.pdf ; [F4] peterman.dk's flex table; forum and shop pages on fin thickness (a 9 % rule of thumb; "slalom riders want flex toward the tip": opinions, no measurements) and on chop ("wind gets under the board"; the chop hop: back foot down, front foot up); nothing found on a windsurf board's own air lift, so Polhamus and Jones stand in, labelled estimates.
