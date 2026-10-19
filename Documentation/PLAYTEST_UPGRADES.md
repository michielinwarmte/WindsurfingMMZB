# Play-test upgrades

From 19 October 2026 the team play-tests the game and writes down what should improve. Each piece of feedback becomes an upgrade in this file: what was felt, what the game does (measured), what the real world says (with sources), why it happens, and a step-by-step plan. Upgrades that change the physics (`Game/sim/`) need Michiel's go-ahead, like every physics change (team decision 5 in [MAP_SILVAPLANA_PLAN.md](MAP_SILVAPLANA_PLAN.md)).

## Status

| # | What | From | Status |
|---|---|---|---|
| U1 | Planing on a smaller wet area | Max, 19 October 2026 | ✅ Go-ahead from Michiel (19 October 2026, given to Max), on the branch `feature/u1-planing-wet-area`. Ready to build (Fable 5.1 leading Opus 5.5 agents, reaches only), not started. Live state: [U1_PROGRESS.md](U1_PROGRESS.md) |
| U2 | The fin bends, and its size | Max, 19 October 2026 (from U1) | 📝 Idea with a first estimate. After U1 |

---

## U1. Planing on a smaller wet area

**Building U1?** Read [U1_PROGRESS.md](U1_PROGRESS.md) (the live state and the prompts), then the [execution brief](#execution-brief). Everything after the brief is the background it relies on.

### The feedback

Max, 19 October 2026, after sailing the game: "The game is playable and feels quite ok. What I feel is that while planing the wet area is really big still. In real life it's only wetted from the front leg to the back of the board. This will reduce drag. This may be due to the shape of the board, or the lift the fin creates and that it's not happening."

Max added, on how a sailor trims the board on flat water: "In my feeling I'm pushing almost all my weight on the back footstrap, and controlling the board with the front. If I want, I can lift the board up (front up) by loading the fin and pulling up on my front foot. In real life it is possible by technique to trim the board."

### The short answer

- **Max is right, by about a factor of two.** At 18 kt on a beam reach the game's board is wet for 1.87 m from the tail. Real boards are wet for about 0.6 to 1.0 m, ending at or behind the front footstraps.
- **The main cause is where the board is pushed down.** The sailor hangs 91 % of their weight in the harness. The rig passes that weight on to the mast foot, 1.30 m from the tail, so the water has to hold the board up far forward. The game's harness line carries 945 N; on a real sailor with the same 6.5 m² sail it was measured at about 415 N.
- **The board's shape adds to it.** The tail kicks up 1 cm over its last 35 cm (an estimate without a source). At the game's low trim the last 20 to 25 cm of the tail then carry nothing, and the lift has to come from further forward. Real freeride and slalom boards are flat from the tail forward.
- **The fin alone is not the cause, but it is part of the cure.** Its lift already tilts with the board, so a heeled board gets some upward lift at the fin (about 36 N here). On its own, that push behind the centre of mass lowers the nose. But in the real technique (Max's, above) the weight stands over the back strap, right above the fin, and the fin carries part of it. The game's sailor never does that. The game's fin also doesn't bend, which tilts a real fin's push further upward (U2).
- **The game's sailor trims the board the wrong way.** Max puts almost all the weight on the back foot and can lift the nose with the front foot. The game's sailor hangs in the harness, doesn't lean back, and presses the bow down with the feet.
- **The catch:** the heavy mast-foot load is also what keeps the board from porpoising (bouncing up and down on its tail; PHYSICS_SPEC.md 7.5). Take it away and the board porpoises at 1.8 Hz. That is the same 1.7 Hz "yaw wag" Session 39 found. So the upgrade must also fix the porpoising, physically.
- **The pay-off:** the friction drops from 223 N to roughly 100 N, while the sail drives with 319 N. The board gets faster, and the validation's speed ranges have to be checked again.

### Execution brief

For the lead who builds U1. It turns the plan below into exact instructions; everything after the brief is background. The live state is in [U1_PROGRESS.md](U1_PROGRESS.md).

#### Go-ahead, branch and team

- **Go-ahead:** Michiel approved building U1 on 19 October 2026 (he told Max). His condition: all work on a git branch.
- **The branch** is `feature/u1-planing-wet-area`, made from `main` at 561849c. It holds this plan.
- **Nothing goes to `main`.** That is a pull request after Stop 3, and the team's call.
- **The lead is Claude Fable 5.1**, the head developer. It:
  - launches the agents;
  - reads their reports and merges their branches;
  - keeps U1_PROGRESS.md up to date;
  - handles the stops.

  It does little hands-on work, because Max has little Fable usage left.
- **The sub-agents are Claude Opus 5.5 at extra-high effort** (`model: "opus"`, `effort: "xhigh"`).
  - At most 5 in all, and at most 3 at a time.
  - Each works in its own git worktree (`isolation: "worktree"`), on a branch `u1/<name>` made from `feature/u1-planing-wet-area`. The lead merges it back.
- **Still open for Michiel, not a blocker:** the planing-onset band from Session 39. Keep it as it is, and report where the onset moves (U1.7).

#### Tokens

- **Read narrowly.** Read this brief and the files of your package. PHYSICS_SPEC.md is over 6000 lines: grep it for the sections you need and never read it whole.
- **Measure with the reach check** (one line per case), not by reading CSV files. Pipe long outputs through `tail`.
- **Pace the checks.** Run `tools/test.sh` after each change. Run the reach check and `tools/test.sh validation` once per finished piece, not after every edit.
- **Report briefly.** At most 300 words plus one table, committed as `Documentation/u1_reports/<name>.md`, and returned to the lead as the same text.

#### If the lead stops

Fable can run out at any moment, so everything needed to go on lives in git:
- **U1_PROGRESS.md** holds the state of each agent, the stops, the latest numbers and the next action. The lead updates and commits it after every launch, report and merge.
- **Each agent's work** is committed on `u1/<name>` as it goes, with its report at the end.
- **The agent prompts** are in this brief, so any lead can launch an agent again in the same form.

**To go on,** Max starts a new Claude Code session in the repo with the resume prompt from U1_PROGRESS.md. Opus 5.5 at extra-high effort can be the lead. The new lead:
1. checks `git worktree list` and the `u1/*` branches;
2. merges the finished agents (their report is committed);
3. launches the unfinished ones again, continuing on their existing branch;
4. carries on from the next action.

#### Rules

From [CLAUDE.md](../CLAUDE.md) and PHYSICS_SPEC.md, the ones that matter here:

**Code**
- Godot 4.7, GDScript with static types.
- The physics lives in `Game/sim/` (plain classes, no Nodes); numbers in `Game/config/*.tres`; SI units, with the unit in the name.

**Checks**
- After every change: `tools/test.sh`.
- After a scene or resource change: `tools/check.sh`.
- After a physics change: `tools/test.sh validation`, and update PHYSICS_SPEC.md:
  - the section the change is in;
  - section 14 for every value and its source;
  - the tuning log in section 16, with the reason.
- New behaviour gets a new test. A bug gets a failing test first.

**Numbers**
- No new stabiliser, damping or fudge constant to reach a target.
- Every new number has a source, or is labelled as an estimate in section 14.

**Git**
- Small commits with clear messages. Commit the `.uid` files; never `Game/.godot/`. Don't touch `Legacy/` or `Game/addons/gut/`.
- Godot rewrites `Game/default_bus_layout.tres` when the game runs. Restore it with `git checkout -- Game/default_bus_layout.tres` unless you changed it on purpose.

**Each session**
- The lead adds an entry at the top of PROGRESS_LOG.md and ticks the boxes in this file.

#### Working on Max's Windows PC

- **Godot:** the `tools/*.sh` scripts run in Git Bash. `GODOT` is set as a user variable; a shell that was open before it was set needs `export GODOT=/c/Users/maxba/AppData/Local/Programs/Godot/Godot_v4.7.2-stable_win64_console.exe`.
- **Timing:** the first Godot run in a new checkout or worktree imports every asset (about 40 s). `tools/test.sh` takes about 100 s.
- **Blender** is not installed, so `board.glb` can't be rebuilt here (U1.4). The physics doesn't need it.
- **`--out=` must be an absolute path** for `tools/simulate.sh`. Godot runs from `Game/`, so a relative path fails with "Cannot write".
- **Overrides:** `tools/simulate.sh` takes `--sailor.<field>=`, `--sail.<field>=`, `--board.<field>=` and `--pilot.<field>=`. A plain number such as `tail_rocker_m` can be overridden.
- **`length_samples` cannot be overridden.** The buoyancy grid is built at start. Build the simulation with its own `BoardConfig` in a test instead.

#### Testing: reaches only

Max, 19 October 2026: U1 is tested on reaches at several headings, not in manoeuvres. No tacks, gybes or turns are run in U1, to save tokens. The team runs the full manoeuvre matrix before the pull request to `main`.

**The reach check:** the beam-reach scenario, flat water, steady wind, 40 s per case, numbers over the last 15 s (t ≥ 25 s):

```
tools/simulate.sh beam_reach 40 --wind_kt=<W> --twa=<A> --steady=1 --gradient=0 --out=<absolute path>.csv
```

W is 12, 18 and 24 kt. A is 60° (close reach), 100° (beam reach) and 135° (broad reach). That makes 9 cases. Agent 1 wraps them in one command that prints one line per case: a `tools/reach_check.sh`, or a runner in `Game/dev/` like `run_matrix.gd`.

| Name in this plan | How it is computed |
|---|---|
| Front of the wet part, from the tail | mean of `wetted_aft_m + wetted_length_m` |
| Wet length | mean of `wetted_length_m` |
| Centre of the water's push, from the tail | `length_m / 2 − mean(planing_cop_z_m)` (1.2 m − z for the default board) |
| Trim | mean of `trim_deg` |
| Steadiness | standard deviation of `pitch_deg` over the window |
| Harness tension | mean of `harness_tension_n` |
| Rig's share of the sailor's weight | mean of `hand_force_up_n` / (sailor mass × g) |
| Mast foot pushing down | − mean of `mast_foot_force_up_n` |
| Friction, drive, speed, planing | means of `hull_friction_n`, `drive_n`, `speed_ms`, `planing_ratio` |

U1.1's validation check computes the same numbers through `Game/tests/validation/validation_run.gd`. Its last-10-s window is fine.

#### The baseline that must not get worse

Agent 1 measures the baseline first, before any change, and writes it into U1_PROGRESS.md:

| Check | Session 39, for comparison |
|---|---|
| `tools/check.sh` | 188 files, 0 failed |
| `tools/test.sh` | 335 of 335 |
| `tools/test.sh validation` | 20 of 20 |
| The reach check | 9 cases (the 18 kt beam reach is the "What the game does now" table below) |
| `tools/matrix.sh --only=straight` (flat water) | no fall; 8.77, 11.10 and 12.01 m/s at 12, 18 and 24 kt |
| `tools/matrix.sh --only=straight --waves=1` (the default sea) | to be measured |
| `tools/lake_matrix.sh --only=straight` (the lake at three times of day) | to be measured |

After every merge:
- no fall and no NaN;
- validation green.

Two exceptions:
- U1.1's check stays `pending` until agent 4.
- A band that U1 changes on purpose is allowed, if it is written in the tuning log with its reason.

#### Targets, in priority order

1. No regression against the baseline.
2. Steady: pitch standard deviation below 0.3° in all 9 cases.
3. At 18 and 24 kt, on the beam reach and the broad reach (100° and 135°): the front of the wet part 0.6 to 1.0 m from the tail.
4. In the same four cases:
   - the centre of the push 0.45 to 0.75 m from the tail;
   - the trim 1.5 to 4°.
5. On the 18 kt beam reach:
   - a harness tension of 350 to 480 N;
   - the rig carrying at most 50 % of the sailor's weight.
6. Speeds: the validation's polar check stays green, so every angle stays inside its real-world range (POLAR_15KT.md).

The close reach (60°) only has to be steady and no worse than the baseline; its wet part is reported. A result that reaches 3 to 5 by giving up 1 or 2 is not done.

#### Stop and report, instead of pushing on, when

- Agent 3 has tested every candidate and none explains the bounce with evidence.
- A target can only be reached with a number that has no source and no physical reason.
- A regression appears that the step can't explain.
- The work needs a file outside the agent's list (below).
- A source contradicts a target of this plan.

The report says what was tried, with the numbers and the options. The lead tells Max in plain language and writes it in U1_PROGRESS.md.

#### Numbers that still need a source (agent 2)

1. **How high the harness hook is above the deck when a sailor hikes out**, and the harness line's length and angle. Winter's body proportions are already in `figure_skeleton.gd`.
2. **How hard a front foot can pull up in its strap**, so how big a nose-up couple the feet can make. The strap spread is 38 to 44 cm (Jem Hall).
3. **The flat-water rail-down angle** for the assist's fin loading (U1.6). If nothing is found, ask Max for his estimate.
4. **Harness tensions for other winds and sails** than Walls & Gale's one sailor, if any exist.

**Found:** write the number into PHYSICS_SPEC.md section 14, with its source.
**Not found:** write an estimate, labelled as one, and list it in the report.

#### Scope

**In U1:**
- U1.1 to U1.8 below.
- U1.6 delivers the assist's safe fin loading.
- The railing-out test, as information only.

**Not in U1:**
- Manoeuvre testing.
- The fin bending and the fin's size: U2.
- The player's own trim and fin-loading control: a team decision, for later.
- A finer buoyancy grid, unless agent 1's grid check moves the wet part by more than 5 cm.

#### The agents and the stops

| # | Name | Package | When | May change |
|---|---|---|---|---|
| 1 | `measure` | The baseline; the reach check command; U1.1 (the validation check, `pending`; telemetry; HUD; the grid check); then U1.4, the flat tail, with its numbers | first | the reach-check script or runner (`tools/`, `Game/dev/`); `Game/tests/validation/test_planing_wet_area.gd` (new); `validation_run.gd` (only to record the new fields); `Game/sim/telemetry.gd`; `Game/sim/hull_model.gd` (only to expose the friction area); the telemetry block at the end of `Game/sim/windsurfer_sim.gd`; `Game/ui/hud.gd`; `Game/config/board_default.tres`; the spec for the tail |
| 2 | `sources` | The four numbers above | with 1 | nothing in the game: its report only |
| 3 | `porpoising` | U1.5's diagnosis | with 1 | nothing in the game: experiments, and its report |
| 4 | `physics` | U1.5's fix, U1.2, U1.3, in that order; U1.1's check becomes real | after Stop 1 | `Game/sim/windsurfer_sim.gd`, `mass_model.gd`, `hull_model.gd`, `config/sailor_config.gd`, `Game/config/sailor_default.tres`, their tests, the spec |
| 5 | `finish` | U1.6, U1.7, U1.8's screenshots | after Stop 2 | the sailor and pilot files for the bank and the rig's lean, their tests, the spec; screenshots in `.screenshots/u1/` (not in git) |

**Agent 3, how:**
- Reproduce the bounce on the 18 kt beam reach with `--sailor.lean_height_drop_m=0.15`. It bounces at 1.78 Hz on the current tail.
- Do the same on the flat tail, with `--board.tail_rocker_m=0`.
- Switch the candidates one at a time:
  - `--sailor.leg_natural_frequency_hz=` and `--sailor.leg_damping_ratio=`;
  - `--sailor.trim_press_max_m=0`;
  - `--sailor.pitch_reflex_m_per_rad_s=0`;
  - `--freeze=<s>` (the sailor stops moving fore and aft from then on);
  - `--board.planing_lift_lag_s=`.
- Compute where the board sits against Savitsky's porpoising limit for a flat bottom.
- Name the cause with numbers.

**The stops:**
- **Stop 1, the lead:** agents 1 to 3 are in. Go on when all three hold:
  - agent 1's check reproduces the reach check;
  - agent 3 names a cause;
  - nothing regressed.

  Otherwise stop for the team.
- **Stop 2: Michiel reviews agent 4's physics** (the diff, the spec, the numbers). Wait for his OK.
- **Stop 3: Max's play-test** (U1.8). Then the team decides on the pull request.

#### Decisions at Stop 1 (Max and Michiel, 19 October 2026)

Agents 1 to 3 are in (their reports are in `Documentation/u1_reports/`). The team decided:

1. **A slight tail vee, documented.** Agent 4 gives the board a slight vee (deadrise) across the tail, with a source for the angle or a labelled estimate in spec section 14, and models its physical effect in `hull_model.gd` (Savitsky's deadrise correction of the planing lift and so of the critical trim; no stabiliser). Target 4's trim band becomes 1.5° up to the porpoising limit of the chosen vee; the 4° upper end is dropped, and the report says what the limit is.
2. **The five cases that bounce in the baseline** (the three close reaches, the 12 kt beam reach, the 18 kt broad reach) must not get worse, and are fixed if the fix is cheap. Target 2's "below 0.3°" is required in the other four: 12 kt 135°, 18 kt 100°, 24 kt 100° and 24 kt 135°.
3. **The grid: try different ones.** Agent 4 runs the reach check with 7, 9, 11 and 13 rows (`length_samples`, by building the simulation with its own `BoardConfig` as in agent 1's grid check) and reports where the wet front and the steadiness stop changing. If the default has to change, it changes in `board_default.tres` with its reason in the tuning log and the cost in run time.
4. **The flat tail (U1.4) comes back** with the vee: `git revert d55bd6a`, update the two tests in `Game/tests/unit/test_buoyancy.gd`, and explain the 18 kt broad reach going bow-down (agent 1's open point, tied to U1.3).

Agent 4's file list is widened by: `Game/config/board_config.gd`, `Game/config/board_default.tres`, `Game/tests/unit/test_buoyancy.gd`, `Game/tests/validation/test_planing_wet_area.gd` (to turn its targets into checks) and the spec sections for the hull and the board.

Still open for Max: his own estimate of the flat-water rail-down angle (agent 2 found no source; the spec holds a 3 to 6° placeholder). Agent 5 needs it for U1.6.

#### Decisions at Stop 2 (Michiel, 19 October 2026)

Michiel accepted agent 4's physics (`u1/physics`, merged). He decided:

1. **The planing onset at 13.3 kn is too fast; a real board planes at about 10 kn. Do not move the band: look for what the model is missing** (hump lift, or whatever lets a real board plane at 10 kn), with a source. Agent 4 (relaunched, on `u1/physics`) does this first; its report is `Documentation/u1_reports/physics_onset.md`.
2. **Fix the rig's lean and the helm first** (U1.6, agent 5, on `u1/finish`, report `Documentation/u1_reports/finish_u16.md`), so the harness line's geometry becomes real (today it runs 1.45 m from the hiked body to the grip because the weather helm tilts the rig back to 8°). U1.2 and U1.3 follow after U1.6 is merged, by agent 4 relaunched. U1.7 and U1.8 follow after that, by agent 5 relaunched.
3. **1° of vee** stays for now.
4. **Riding above Savitsky's flat-bottom limit is accepted, and Michiel wants a plain-language explanation** of why the board is steady there. Agent 4 writes it, at most 200 words, as a section of `physics_onset.md` and in PHYSICS_SPEC.md section 17.2.

#### Decisions after round 3 (Max, 19 October 2026, after a first play-test)

Agent 4's round 3 (U1.2, U1.3) is merged. Its stop rule: targets 3 to 5 conflict with statics as the pilot sails (hooked in, the line carries the whole boom force; the drive's couple holds the push 0.66 m ahead of the weight). Max played it: "a little better", but the push on the fin isn't felt (the sideways load and the fin's bending are U2), and real sailors hold part of the sail through the hands. Decided:

1. **Finish U1 as it stands (option b).** Today's numbers are accepted as the physics of a fully sheeted 6.5 m² sail at 18 kt. Targets 3, 4 and 5 stay `pending` in `test_planing_wet_area.gd`, with the numbers in the report. Round 4: agent 5 does U1.7 and U1.8 (report `finish_u178.md`), then Stop 3.
2. **The hands' share** of the boom force (Max's feel: about a third, which would put the harness near 450 N) is a follow-up, as Max's labelled estimate, only if Michiel agrees. Not in round 4.
3. **The planing onset** stays as Michiel decided: the band is not moved, the buoyancy factor stays off (the 24 kt broad reach bounces with it). Agent 5 reports where the onset is (U1.7) and the team decides at the pull request what to do with the red check.
4. **The fin's sideways push and its bending are U2**, next.

**The agent prompt.** The lead launches every agent with this text, filled in:

> You are agent <n>, `<name>`, of U1 in WindsurfingMMZB (Godot 4.7). Read CLAUDE.md and the U1 execution brief in Documentation/PLAYTEST_UPGRADES.md, then do your package from the brief's agent table and the U1.x boxes it names. Work in your worktree on the branch `u1/<name>`: make it from `feature/u1-planing-wet-area`, or continue on it if it already exists. Commit as you go, and change only the files your row allows. Follow the brief's rules, targets and stop rules, and be careful with tokens. Finish with your report (at most 300 words and one table) committed as Documentation/u1_reports/<name>.md, and return the same text.

For agent 4, add the reports of agents 2 and 3. For agent 5, add agent 4's report.

### How the wet length is decided

The code does not choose a wet length. The board sinks until the water's push carries the weight, and tilts until that push sits right under the loads. Planing theory (Savitsky 1964) says the push of a planing bottom is centred about three quarters of the wet length forward of the tail. So:

**wet length ≈ 1.3 × (distance from the tail to the centre of the push)**

Push down on the board 1.2 m from the tail and it is wet for about 1.6 m; push down at 0.6 m and it is wet for about 0.8 m. Gourlay and Martellotta (2011) found the same factor of 1.3 for an RS:X board, nearly constant from 8 to 24 kt. The trim (the angle between the bottom and the water) follows from it: a short wet part has to meet the water at a steeper angle to carry the same weight.

In the code: `HullModel._wetted_span()` reads the wet part from the buoyancy grid (where the still-water surface cuts the hull), and `_apply_planing_lift()` computes the push strip by strip, scaled to Savitsky's measured lift.

### What the game does now (measured, 19 October 2026)

Method: the reach check's 18 kt beam reach (100°, execution brief), on `main` at 561849c. Positions are measured forward from the tail.

| | Game | Real world |
|---|---|---|
| Boat speed | 12.30 m/s (23.9 kt) | |
| Wet length | **1.87 m** | 0.6 to 1.0 m |
| Centre of the water's push | **1.58 m** from the tail | 0.45 to 0.75 m |
| Trim | **0.93°** | about 1.5 to 4° at these speeds |
| Area the friction acts on | about 1.07 m² | about 0.3 to 0.4 m² |
| Skin friction | **223 N**, against a sail drive of 319 N | |
| Harness line tension | **945 N** | 415 ± 67 N (6.5 m² sail, measured) |
| Sailor's weight carried by the rig | **673 of 736 N (91 %)** | about half or less |
| Mast foot pushing the board down | **678 N**, 1.30 m from the tail | |
| Sailor's feet | 0.38 m from the tail: the "trim press" (`trim_press_max_m`) is at its limit | back straps about 0.4 to 0.6 m |
| Moment of the feet on the board | **−120 N·m, bow down**, at its limit (`feet_moment_max_nm`) | |
| Rig leaned to windward | 9° | 10 to 25° |

With the default gusts and the wind's height profile (`tools/simulate.sh beam_reach 60 --wind_kt=18 --twa=100`, the last 10 s) the board is already porpoising: the wet length swings between 0.75 and 1.99 m (1.37 m on average) and the trim between 0.35° and 1.73°. Friction is 153 N against a drive of 240 N, and the harness line tension is 778 N.

**The HUD hides part of it.** Its "wetted" number (`Telemetry.wetted_area_m2`) is the buoyancy grid's area, 0.63 m² here. The friction uses the larger planing area (wet length × mean width, `HullModel`, step 1), about 1.07 m² here.

### What-if runs (settings changed from the command line, no code changed)

The reach check's 18 kt beam reach. Each run changes one setting with `--sailor.<field>=<value>`.

| Run | Change | Wet length, mean (range) | Trim | Mast foot down | Harness | Friction | Speed | Steady? |
|---|---|---|---|---|---|---|---|---|
| now | none | 1.87 m | 0.93° | 678 N | 945 N | 223 N | 23.9 kt | yes |
| aim for 4° trim | `running_trim_deg=4` | 1.87 m | 0.93° | 681 N | 951 N | 224 N | 23.9 kt | yes: no change, the press is already at its limit |
| no trim press | `trim_press_max_m=0` | 1.34 m (0.66 to 1.88) | 0.95° | 499 N | 767 N | 177 N | 25.0 kt | porpoises |
| feet further back | `stance_planing_z_m=0.8` | 1.38 m (0.67 to 1.90) | 0.93° | 502 N | 771 N | 181 N | 24.9 kt | porpoises |
| hips higher | `lean_height_drop_m=0.3` | 1.31 m (0.63 to 1.80) | 1.00° | 411 N | 706 N | 174 N | 25.1 kt | porpoises |
| hips higher still | `lean_height_drop_m=0.15` | 1.08 m (0.64 to 1.64) | 0.89° | 317 N | 645 N | 152 N | 25.9 kt | porpoises at 1.78 Hz |

What they show:
- **Moving the feet doesn't fix it.** The weight that matters goes through the rig, not the feet.
- **Less weight on the mast foot shortens the wet part straight away.** With higher hips the harness line is flatter and lifts less of the sailor, and the board gets 2 kt faster.
- **The trim stays near 0.9° in every run**, even when the wet part gets shorter. The tail kick (below) is the likely reason.
- **Every run with less mast-foot load porpoises.** The low points of the swing (0.63 to 0.67 m) are in the real range, but the board doesn't stay there.

### What the real world says

Reliability: **measured**, **theory** (a model), **shaper** (a designer's or maker's statement), **expert** (an experienced sailor's statement).

| What | Number | Source | Reliability |
|---|---|---|---|
| Wet length of a planing slalom board | "observed values of mean wetted length are approximately 1.0 m"; wetted area 0.40 m², mean wet width 0.40 m | Sutherland 1993 | theory, with an observed value whose method isn't given; 1993 boards were narrower |
| Wet length and the push's centre | push 0.6 m from the tail, wet length 0.8 m (1.3 × the push's distance), nearly constant from 8 to 24 kt | Gourlay & Martellotta 2011 (RS:X) | theory |
| The flat part a modern board rides on | "the flat section is only about 80 cm"; "you are really standing right at the back, just riding on the gliding surface" | Gnigler (JP-Australia shaper), surf-magazin 2025 | shaper |
| Where the wet part ends | "If the area under the front foot is spending most of the time in the water, the board isn't flying"; a flat rocker "from the front foot back to the tail" | O'Shea & Crossley, Windsurf Magazine 2022 | expert |
| The rocker line | flat "from the tail to beyond your front foot" (Starboard Carve); "planing straight", zero rocker from the tail forward (Carbon Art) | Starboard 2025, Carbon Art | shaper |
| Trim | 3° at 12 kn and 2° at 14 kn, lower toward 24 kn (Gourlay); about 3° "on very flat water" (Sutherland); Savitsky gives 1.6 to 3.4° at 25 kn for a push 0.45 to 0.75 m from the tail | Gourlay 2011, Sutherland 1993, Savitsky 1964 | theory. **No measured trim was found** |
| Harness line force | 381.6 ± 43.2 N with a 5.0 m² sail, 415.0 ± 66.7 N with 6.5 m² (about 50 % of body weight), 12 to 30 kn | Walls & Gale 2001 | **measured** (one expert sailor) |
| The sail carrying weight | 9 to 24 % of the weight, rig 10° to windward (Sutherland); 7 % at 15° (Drake, Formula board) | Sutherland 1993, Drake 2005 | theory |
| Fin lift upward | the fin tip bends to windward, so its force "acts also upwards"; no number | surf-magazin, fin basics | shaper |
| Fittings | mast foot about 1.30 m from the tail; front straps 0.80 to 0.90 m (Starboard iSonic 121) | Jem Hall, Windsurf Magazine; owner's measurement on seabreeze.com.au | expert |

**Not found:** a measured wet length or trim of a modern board (tank test, photos from below, motion sensor), a measured mast-foot force, or a number for the fin's upward lift.

### Why it happens

1. **Too much of the sailor hangs on the rig.** In the harness balance (PHYSICS_SPEC.md 7.5) the line runs from the hips to the boom and takes as much of the pull as its direction allows. Fully hiked, the hips drop to 0.5 m above the deck (`lean_height_drop_m` 0.5 below `com_height_m` 1.0), so the line is steep and lifts most of the body. 945 N against the measured 415 N. Everything the line lifts comes back into the board at the mast foot, ahead of where a real board is wet.
2. **The feet are at their limits.** The trim press has moved them as far back as it may (0.38 m from the tail), and still can't reach `running_trim_deg`. The feet also press the bow down with their maximum moment, −120 N·m. A planing sailor presses the tail with the back foot, not the bow, so this needs looking into. It might be the hands' twist couple, which the body passes through the feet (spec 7.5).
3. **The tail kick eats the trim.** `tail_rocker_m` 0.01 over `tail_rocker_length_m` 0.35 is a curve whose slope at the very tail is 3.3°. At about 1° of pitch the last 20 to 25 cm of the bottom face slightly downward and carry nothing (a strip may not pull). Over a short wet part, the chord (the straight line from the tail to the front of the wet part) is tilted down by about 1°. The board can only carry its weight on a longer wet part. The value came in Session 30 ("the rocker line of a freeride board", spec section 16) without a source; the legacy game had 0.02.
4. **The mast-foot load is the porpoising guard.** Spec 7.5: the mast-foot pressure "holds the nose down at speed and took the porpoising out of the flat-water runs". Every what-if run that lowered it porpoised. So the long wet length is partly what keeps the board steady today.
5. **The rig stands up straight.** It leans 9° to windward, where real sailors lean it 10 to 25°. A rig leaned to windward carries 7 to 24 % of the weight with its lift. This is a smaller effect.
6. **The sailor has no trim technique.** Max's technique, against what the game's sailor does in the steady 18 kt run:

| Max on flat water | The game's sailor |
|---|---|
| Almost all the weight on the back footstrap | The feet stand at the back strap (0.38 m from the tail), but the harness carries 91 % of the weight |
| Leans back against the boom's pull | Doesn't lean back at all (`hang_back_m` 0): the steep harness line lifts the body from in front of the feet, so the hang-back balance in `windsurfer_sim.gd` has nothing to answer |
| Back foot down, front foot pulling up: the nose lifts | The feet press the bow down with 120 N·m. That moment isn't a choice: it is whatever is left over from the body's balance (`_apply_leg_forces`) |
| Loads the fin | The feet hold the board flat (the bank reflex, `feet_roll_stiffness_nm_per_rad`), so the fin only lifts by accident |

**How the technique works.** Take the sailor, rig and board as one system. The sail drives with 319 N about 2 m above the water (the centre of effort is 0.4 × 4.6 m up the mast), and the water holds back at the bottom. That makes a bow-down couple of roughly 600 N·m. The water's push has to sit where it balances this couple and the weight, so the couple pushes it forward. Three things move it back, and together they are the technique:
- **The weight aft:** the body over and behind the back strap, leaning back against the boom.
- **The fin carrying weight:** with the leeward rail a little down, the fin's sideways lift tilts upward and carries part of the weight right under the back foot. The hull then needs less wet area.
- **The rig raked back and to windward:** the sail lifts part of the weight.

Pushing with the back foot and pulling with the front acts between the sailor and the board. It tilts the board nose-up against the body, so the bottom meets the water at a steeper angle and the board rises. The body then has to hold that couple with its weight and the boom. In the game it must come with the body's balance, not as a free torque on the board.

**The fin on its own:** `FinModel` builds its force in the board's frame, so it tilts with the heel and already lifts upward on a heeled board (36 N at 3.6° of heel here). On its own, that push behind the centre of mass lowers the nose. It helps only as part of the technique above, under a sailor standing over it. The fin bending to windward is not modelled, and it is not small (U2).

**Unknown:** whether the coarse buoyancy grid (7 rows, 0.40 m apart) shifts the wet part. The front end of a 0.8 m wet part falls between two rows and is interpolated in a straight line.

### The plan

Who does what, in which order, and the stops: the execution brief's agent table. Each step's boxes:

**U1.1. Measure it first, and keep measuring it** (agent 1)
- [x] The reach check as one command (9 cases, one line each), and the baseline with it, written into U1_PROGRESS.md before any change.
- [x] A validation check, `Game/tests/validation/test_planing_wet_area.gd`, on the reach check's conditions through `validation_run.gd`, in the 9 cases.
  - It checks targets 2 to 4 of the execution brief.
  - Until agent 4 meets them it calls `pending()` with the measured numbers, so the suite stays green and the numbers stay visible.
  - Agent 4 turns it into a real check.
- [x] Telemetry: the area the friction uses (for example `friction_area_m2`), the front of the wet part from the tail, and the centre of the push from the tail. The mast-foot load and the harness tension are already in the telemetry.
- [x] HUD: "wetted" shows the friction's area instead of the buoyancy grid's, plus the front of the wet part, the harness tension and the mast-foot load (in `hud.gd`'s detail panel).
- [x] The grid check: build the simulation with a `BoardConfig` whose `length_samples` is 13, and compare it with 7 at 18 kt. If the front of the wet part moves by more than 5 cm, report it (a finer grid is not in U1's scope without the team).

**U1.2. The harness load** (agent 4; spec 7.5)
- [ ] Target: at 18 kt with the 6.5 m² sail, a harness line tension of 350 to 480 N (Walls & Gale 2001), and the rig carrying at most 50 % of the sailor's weight.
- [x] Check the body's geometry when fully hiked against the figure's skeleton (`figure_skeleton.gd`) and agent 2's hook height. The what-if runs show the hip height alone moves the tension from 945 to 645 N.
- [x] Check the line's share in the least-squares fit (spec 7.5): does it take more of the pull than a real line's direction allows?
- [x] Only together with U1.5's fix (agent 4 does U1.5 first).

**U1.3. The sailor trims the board: Max's technique** (agent 4; spec 7.5)
- [x] Find out why the feet press the bow down at their limit (−120 N·m) in a steady beam reach. Trace `pitch_from_feet_moment_nm` back to its parts: the hands' pull, the twist couple, the posture.
- [x] The sailor leans back against the boom's pull and puts the weight on the back foot. `hang_back_m` is 0 today; find why the hang-back balance sees no pull to answer (perhaps the harness lifting from in front of the feet).
- [x] The feet as a trim control: back foot down, front foot pulling up in the strap, balanced by the body (its weight and the boom), within what the legs can hold (agent 2's number). The autopilot uses it to hold its running trim.
- [ ] At Stop 3 Max checks it on the water's terms: is the weight on the back foot, and does the nose lift when the sailor asks for it?

**U1.4. A flat tail** (agent 1, after U1.1; spec 5, 6 and 14)
- [x] `tail_rocker_m` from 0.01 to 0 in `Game/config/board_default.tres`, flat from the tail forward as the sources say for freeride and slalom boards. Keep a few millimetres only if agent 2 or a later source finds them for freeride boards.
- [x] The reach check, validation and the straight runs. Expected: a higher trim and a shorter wet part. Record the numbers in U1_PROGRESS.md.
- [ ] The board model: `tools/blender.sh tools/blender/build_rig_models.py` reads `board_default.tres` and rebuilds `Game/assets/models/board.glb`. Blender is not on Max's PC, so leave the rebuild as an open item in U1_PROGRESS.md; the physics doesn't need the model.

**U1.5. The porpoising, solved physically** (diagnosis: agent 3; fix: agent 4; the open item 2 of Session 39)

Two kinds of bouncing must not be confused (Max asked, 19 October 2026):
- **Riding over waves:** the water surface moves, and the board pitches and slams with it. Waves force this motion; it is real and stays (the sea and chop settings).
- **Porpoising:** on flat water, in steady wind, the board starts bouncing by itself and keeps going. A small bounce makes the lift move forward and back along the bottom, which feeds the next bounce. Real boards can do this too, usually as a setup problem: a mast foot too far back, a fin that is too big, too little mast-foot pressure. Sailors cure it with the mast foot or the stance. The game's 1.8 Hz bounce is this kind: it happens in steady wind with no waves at all.

- [x] Diagnosis (agent 3): find what makes the board bounce at 1.8 Hz once the mast foot is lighter. The candidates, each switched on its own with the overrides in the execution brief:
  - the sailor's legs: a spring at 1.2 Hz (`leg_natural_frequency_hz`), close to the bounce;
  - the sailor's reflexes chasing the bounce (`trim_press_*`, `pitch_reflex_m_per_rad_s`, the hang-back);
  - the planing strips' own damping in pitch and heave, the transom relief (`TRANSOM_RELIEF_BEAMS`), the lift lag;
  - Savitsky's porpoising limit for a flat bottom (Day & Haag 1952; Savitsky 1964): where do the trim and load sit against it?
- [x] The fix (agent 4), of the cause found. Real boards do porpoise sometimes (a mast foot too far back, a fin too big, top speed on flat water), so a short, occasional bounce at top speed is realistic. A board that bounces all the time at 18 kt is not. Target 2 of the brief: steadiness below 0.3° in all 9 reach cases.
- [x] No new damping constant to hide it.

**U1.6. The rig leaned to windward, and the fin loaded** (agent 5)
- [x] Check how the autopilot and the player's assists lean the rig (`max_rig_lean_deg`, `rig_tilt`), and that the sail's upward lift reaches the sailor and the board. Real: 10 to 25°, and the sail carries 7 to 24 % of the weight.
- [x] "Loading the fin", the assist's safe amount. When planing and powered up on flat water, the sailor's wanted bank (`_wanted_bank_rad`, flat today) becomes a few degrees of leeward rail down. The angle comes from agent 2, or else from Max's estimate. It is a small part of U1 (50 to 100 N of about 900 N), so U1 does not depend on it.
  - What it is on the water. Max, 19 October 2026: "I'm pushing on the rail of the board, and with that I'm also railing the board away from me a little, to tilt the board a bit and load the fin. Now the board wants to fly. If I do it too much, my board comes out of the water and I lose control. It's a fine technique and maybe too hard to replicate." So it is both: the feet push sideways on the rail, and that tips the board away from the sailor (leeward rail down). The fin then pushes harder and partly upward, and the board lifts.
  - What the model already has right. Max: "the force of the sail is also what I push against the fin." The sail's sideways pull goes through the boom and the harness into the sailor, the feet push the board sideways, and the fin holds against it. In the steady 18 kt run: sail side force 508 N to leeward, fin lift 573 N to windward. In yaw, the fin's moment (+546 N·m) and the feet's (−543 N·m) cancel.
  - The board already sails with the leeward rail 3.6° down, so the fin lifts 36 N. At 5 to 10° with the same push, that would be 50 to 100 N, and more when the sail pulls harder: a powered-up sailor can load the fin more.
- [x] The railing-out test, as information for the team's later decision on a player control. In a test, raise the wanted bank step by step. Does the board lift and then rail out above some angle, because the fin's rolling moment beats what the feet can hold (`feet_moment_max_nm`)? Report the angle. Build nothing on it in U1.

**U1.7. Validate again: the board gets faster** (agent 5)
- [x] Friction drops by about half, so the speeds rise. Run the validation suite, the reach check and the three straight runs against the baseline, and the polar against the real ranges in [POLAR_15KT.md](POLAR_15KT.md). No manoeuvres.
- [x] The planing onset band (8 to 10 kn, Michiel's open decision from Session 39) may move. Report where the onset is now.
- [x] If the board becomes faster than real boards, look for a drag that is missing, with a source: spray drag (up to 15 % of a planing hull's drag; Savitsky, DeLorme & Datla 2007), the fin, the sailor's windage. Never make the wet part longer again to slow it down.

**U1.8. The look, and Max's play-test** (agent 5, then Stop 3)
- [x] The spray comes from the front of the wet part (`effects.gd`, `spray_root_local`), so it moves back under the front foot by itself.
- [x] Screenshots from the side on the beam reach at 12, 18 and 24 kt, before (`main`) and after, in `.screenshots/u1/`.
- [ ] Max play-tests:
  - Is the board wet only from the front foot back?
  - Does it feel freer and faster?
  - Does it bounce, on flat water or in chop?
  - Does it still behave in gusts on the lake?

### Done when

| What (the reach check, the execution brief's definitions) | Target |
|---|---|
| The baseline | no regression; validation green, U1.1's check included and no longer `pending` |
| Steadiness in all 9 cases | below 0.3° |
| Front of the wet part at 18 and 24 kt, 100° and 135° | 0.6 to 1.0 m from the tail |
| Centre of the water's push, the same cases | 0.45 to 0.75 m from the tail |
| Trim, the same cases | 1.5 to 4° |
| Harness line tension, 18 kt beam reach | 350 to 480 N, the rig carrying at most 50 % of the sailor's weight |
| Speeds | every polar angle inside its real-world range (the validation's polar check) |
| PHYSICS_SPEC.md | sections 5 and 7.5, section 14 (every new value with its source or labelled an estimate), the tuning log |
| Max's play-test | the wet area looks and feels right |

### Risks and open questions

- The mast-foot load has been the porpoising guard. U1.2 without U1.5 makes the board bounce, which is why agent 4 does U1.5 first.
- The speeds will rise, and the polar and the planing onset may move with them.
- The real-world band (0.6 to 1.0 m) is the agreement of two theory papers, two shapers and two experienced sailors, not a measurement. If a measured wet length or trim turns up (a tank test, photos from below), it replaces this band.
- Moving load off the mast foot changes the feel in chop: the mast-foot pressure is also what holds the nose down there. The default sea's straight runs are in the baseline for that reason.
- Manoeuvres (tacks, gybes, turns) are not tested in U1 (Max's choice, to save tokens), and U1.2 and U1.3 change the sailor, which tacks and gybes rely on. The team runs the full matrix (`tools/matrix.sh`, `--waves=1`, `tools/lake_matrix.sh`) before the pull request to `main`, against Session 39's results.
- For the team, later: should the player get Max's foot trim as a control of their own (lift or drop the nose, load the fin), or should the assist do it? Real sailors use it as a skill, so it could reward good technique: fast with the nose up, and porpoising or a spin-out when overdone. The fin's size could be a setup choice with it (U2).

### Sources

1. Sutherland, L.S. (1993). *Windsurfer Fin Hydrodynamics*. MSc thesis, University of Southampton. https://leighsutherland.com/wp-content/uploads/2022/10/Full-MSc-Thesis.pdf
2. Gourlay, T. & Martellotta, J. (2011). *Aero-Hydrodynamics of an RS:X Olympic Racing Sailboard*. CMST Report 2011-02, Curtin University. https://www.perthhydro.com/pdf/Gourlay2011Aero-hydroRsx.pdf
3. Savitsky, D. (1964). "Hydrodynamic Design of Planing Hulls". *Marine Technology* 1(1), 71–95. The equations as coded in OpenPlaning: https://github.com/elcf/python-openplaning
4. Walls, J. & Gale, T. (2001). "A technique for the assessment of sailboard harness line force". *Journal of Science and Medicine in Sport* 4(3), 348–356. https://figshare.utas.edu.au/articles/journal_contribution/A_Technique_for_the_Assessment_of_Sailboard_Harness_Line_Force/22841867
5. Gnigler, W. (2025). Interview, surf-magazin, 3 September 2025. https://www.surf-magazin.de/en/windsurfing/windsurf-boards/freeride/30-years-of-board-design-from-long-and-narrow-to-short-and-wide-an-interview-with-werner-gnigler/
6. O'Shea & Crossley (2022). "Speed sailing: faster faster faster". *Windsurf Magazine*, 23 May 2022. https://www.windsurf.co.uk/speed-sailing-faster-faster-faster/
7. Drake, J. (2005). *An Introduction to the Physics of Windsurfing* (repost). https://joewindsurfer.wordpress.com/2008/04/27/jim-drakes-windsurf-physics/
8. surf-magazin, "Fin basics". https://www.surf-magazin.de/en/windsurfing/windsurfing-accessories/finns/fin-basics-how-to-find-the-right-fin-for-freeride-and-freerace/
9. Starboard, 2025 Carve. https://star-board.com/products/2025-carve-windsurf-board ; Carbon Art, Boardology. https://www.carbonartwindsurf.com/design/boardology/
10. Hall, J. "Tune-up time". *Windsurf Magazine*. https://www.windsurf.co.uk/jem-hall-tune-up-time/ ; iSonic 121 fittings measured by an owner: https://www.seabreeze.com.au/forums/Windsurfing/Foiling/Foil-Board-Dimensions-Mast-track-to-tail--?page=1
11. Savitsky, D., DeLorme, M.F. & Datla, R. (2007). "Inclusion of whisker spray drag in performance prediction method for high-speed planing hulls". *Marine Technology* 44(1), 35–56.
12. Day, J.P. & Haag, R.J. (1952). *Planing boat porpoising*. Thesis, Webb Institute (the porpoising limits that Savitsky 1964 reproduces).

---

## U2. The fin bends, and its size

**Status:** being built on `feature/u2-fin` (from 19 October 2026); the execution brief below, the live state in [U2_PROGRESS.md](U2_PROGRESS.md).

### The feedback

Max, 19 October 2026: "A fin of 37 cm can create a lot of lift in real life. The fins can bend and therefore create more lift. A 44 cm fin can almost totally lift the kit out of the water."

### What we know so far

- **The game's fin** (`fin_default.tres`: 38 cm, 0.0365 m², its force at 40 % of the span) is a stiff plate, almost exactly Max's 37 cm fin.
- **Size isn't the limit; the push is.** The fin's sideways lift is set by how hard the sailor pushes against it, which is the sail's pull: 573 N at 18 kt. At that speed the same fin could give about 3000 N before it stalls (spin-out), so it works at a fifth of what it can do.
- **What lifts the kit is how much of that push points up:** sideways push × the tilt of the fin's force. Two things tilt it: the board's tilt (the leeward rail down, U1.6) and the fin's bend. Under load the fin bends to windward, most at the tip, and the lift on the bent part tilts upward with it.
- **A rough estimate, without a source.** Assume a 40 cm fin bends about 3 cm under 10 kg hung at its tip, the kind of flex number fin makers quote; the real figure is still to be found. The sailing load would then tilt the tip about 20° and the fin's force about 10° on average. That is 100 to 200 N upward from the bend, on top of the board's tilt.
- **Why a 44 cm fin lifts more:** it bends more, its force acts deeper (a longer lever to tip the board, which tilts it more and loads the fin more, a loop that ends in flying out), and it lets the sailor push harder before it spins out.
- **"Almost totally" adds up.** At 800 N of push with the force tilted 30°: about 460 N upward. The sail raked to windward adds 150 to 200 N. The hull is left with a small part of the 900 N, at the tail.

### Execution brief

For the lead who builds U2. The live state is in [U2_PROGRESS.md](U2_PROGRESS.md). Everything from U1's brief holds unless this one says otherwise: the rules, the tokens, the Windows notes, the reach check, the stop rules, the agent prompt.

#### Go-ahead, branch and team

- **Go-ahead:** Max, 19 October 2026, after U1's play-test ("we cannot say anything before U2"). Michiel reviews the physics at Stop 2, as in U1.
- **The branch** is `feature/u2-fin`, made from `feature/u1-planing-wet-area` (U1 is not on `main` yet; U2 builds on U1's steadiness, stance and rig lean). The pull requests go in that order.
- **The lead is Claude Fable 5.1.** In U2 it does the thinking itself: this design, the review of agent 3's physics before Michiel sees it, and the stops. The agents measure, research, build and draw.
- **The sub-agents are Opus 5.5 at extra-high effort** (`model: "opus"`, `effort: "xhigh"`, `isolation: "worktree"`), at most 4 in all and 3 at a time, on branches `u2/<name>` made from `feature/u2-fin`.
- **Testing:** reaches only, with `tools/reach_check.sh`, as in U1. The team runs the manoeuvre matrix before the pull requests.

#### The physics, designed by the lead

**What the model has.** The fin (`fin_model.gd`, spec section 4) is a stiff plate. Its lift lies flat in the board's plane, square to the flow and against the slip, at 40 % of the span below the root. The only upward part of that force comes from the board's heel: at -4.5 deg of heel and 527 N of fin lift (the 18 kt beam reach, measured 19 October 2026) that is 41 N. The fin works at a 2 deg slip against a 12 deg stall, so at a fifth of what it can carry. Its roll moment, 111 N m, is what heels the board, and `feet_moment_max_nm` is what the sailor can hold against it (U1.6: in control to 21 deg of heel, railed out at 24 deg).

**What it misses: the fin bends.** Under its side force the fin bends toward the side the force points, most at the tip. The lift on a bent piece of fin is normal to that piece. A piece whose tip is displaced toward +x has its normal tilted from +x toward +y: a fin bent toward the force gives an **upward** part of its force, on every tack, of `F * sin(tilt)`. That is the lift Max feels on a big fin, on top of the heel's part.

**The model to build (agent 3), the fin as a cantilever beam:**
1. **Planform.** The chord along the span follows the Blender script's law (`tools/blender/build_rig_models.py`, `fin_chord`): `c(s) = c_root + (c_tip - c_root) * s^1.1`, rounded beyond `s = 0.82`, with `c_tip = 0.37 * c_root` and `c_root = area_m2 / (0.686 * span_m)` (0.686 is the integral of the chord law over the span, so the planform's area is `area_m2` for every span; agent 1 caught that the first law, `0.14 m * sqrt(area / 0.0365)`, gave a 44 cm fin 9 % too much area). For the default fin that is 0.140 m, the Blender script's value. Put the law in `FinConfig` (`root_chord_m`, `tip_chord_ratio`, `thickness_ratio` for the NACA 00xx section) so the physics and the model agree. `span_m` and `area_m2` stay the size.
2. **Stiffness along the span.** For a section of chord `c` and thickness `t = tau * c`, the bending stiffness is `EI(y) = S * c(y)^4` with one scale `S` (the second moment of a thin foil section is proportional to `c * t^3`; the constant and the material join in `S`). The tip, at 37 % of the root chord, is fifty times softer than the root: that is why fins bend at the tip.
3. **One sourced number sets `S`: a flex test.** `flex_test_load_n` hung at `flex_test_position` (a span fraction, 1.0 = the tip) deflects the tip by `flex_test_deflection_m`. At start, integrate the beam for that point load with `S = 1` and scale `S` so the computed deflection equals the test. **Default (agent 1, spec section 14 "U2"): a 37 cm F-Hot carbon slalom fin, 100 N at 80 % of the span moves the load point 20 mm (Nascimento 2017, IST Lisbon).** So `flex_test_load_n = 100`, `flex_test_position = 0.8`, `flex_test_deflection_m = 0.020` measured **at the load point** (the calibration compares the deflection at the load point, not the tip). A G10 freeride fin is probably 2 to 4 times stiffer (estimate); Max's own fin, if he measures it (clamp the base, hang a known weight at the tip, measure the tip's displacement), replaces the default.
4. **Loading.** The lift is spread along the span elliptically from the root (the hull is the end plate, so the root is the mid-span of the mirrored wing): `l(y) = F * (4 / (pi * L)) * sqrt(1 - (y/L)^2)`, which integrates to `F`. Twenty stations.
5. **Beam.** At each station `M(y) = integral from y to L of l(s) (s - y) ds`, the slope `theta(y) = integral from 0 to y of M / EI`, the deflection `w(y) = integral from 0 to y of theta`. Everything is linear in `F`, so precompute `theta1(y_i) = theta(y_i) / F` and `w1(L)` once per fin (at `_init`) and at run time take `theta_i = F * theta1(y_i)`, capped at 35 deg (beyond that the linear beam is wrong and a real fin has long spun out).
6. **The tilted force.** With the station weights `e_i` (the elliptic shares, `sum e_i = 1`): `up = F * sum e_i sin(theta_i)` along the board's +y, `side = F * sum e_i cos(theta_i)` in the old lift direction, applied at the same centre of pressure, drag unchanged. Report `fin_tilt_deg = atan2(up, side)`, `fin_bend_tip_deg = F * theta1(L)`, `fin_bend_tip_m = F * w1(L)`, `fin_up_n` (the bend's part plus the heel's part, in world +y).
7. **Quasi-static.** A fin's first bending mode is at tens of hertz, far above the motions here, so the bend follows the load with no lag. Twist (flex-twist coupling, which changes the angle of attack on some fins) and the small shift of the centre of pressure toward the tip's displacement are left out and written down as such.
8. **Size.** `--fin.span_m=0.44 --fin.area_m2=<catalogue>` gives a 44 cm fin: the chord law and the stiffness follow (the same `S`, the same material; a longer, deeper fin bends more by geometry). Its force acts deeper (`cop_span_fraction * span_m`), so the roll lever and the heel grow with it.

**Tests to write:** with a constant chord (a rectangle) and a tip load, the computed tip deflection equals `P L^3 / (3 EI)` within 1 %; the flex-test calibration reproduces its own deflection; the elliptic weights sum to 1 and the root moment equals `F * 4L / (3 pi)`; a bent fin's force has a positive +y part on both tacks; `F = 0` gives no bend; the stiff limit (`S` very large) gives the old force exactly (the U1 reach check unchanged).

#### Targets, in priority order

1. No regression against U1's Latest (U1_PROGRESS.md): the reach check steady in 9 of 9, no fall, no NaN, validation as it is (the onset check is red on purpose), the polar inside its ranges.
2. The fin bends by beam theory with a sourced stiffness, and the tip angle, the tilt and the upward force are in the telemetry and on the HUD.
3. The 18 kt beam reach reports the fin's upward force for the 37 cm fin, stiff versus sourced flex, and for the 44 cm fin. No number is a target here: the plan's 100 to 200 N was a guess. The report says what the physics gives and why.
4. The 44 cm fin against the 37: more upward force, a larger roll moment and heel, a smaller slip, a later spin-out, with the numbers.
5. The look: the fin visibly bends in the game by the computed amount, and the HUD shows the fin's load as a share of its stall.
6. The feel, at Stop 3: Max feels the push on the fin.

Not in U2: the player's own railing control (a team decision), the fin's twist, ventilation spin-out, the wet-area targets of U1 (though the fin's lift may shorten the wet part: report it).

#### The agents and the stops

| # | Name | Package | When | May change |
|---|---|---|---|---|
| 1 | `fin_sources` | Published flex or deflection tests of 36 to 44 cm freeride and slalom fins (G10, carbon), with the load and where it hung; catalogue dimensions of 37 and 44 cm freeride fins (span, area, root and tip chord, thickness ratio); anything written on fin flex and lift (fin makers on flex and twist, the 2024 Ocean Engineering windsurf VPP, theses on windsurf fins); spin-out slip angles; Max's own fins when he names them. Into PHYSICS_SPEC.md section 14 with sources; estimates labelled | first | the spec; its report |
| 2 | `fin_measure` | The fin's baseline: `--fin.<field>=` overrides in `run_scenario.gd` and `run_reach.gd`; fin columns in the reach check (slip, lift, roll moment, the heel's upward part, the share of stall); `fin_up_n`, `fin_tilt_deg`, `fin_bend_tip_deg` in the telemetry (zero for now) and the HUD; what-ifs with the stiff fin: `--fin.span_m=0.44` with its catalogue area, and `--sailor.fin_load_bank_deg=` 0, 4.5, 8 and 12 (how much the heel alone lifts, and where the sailor loses it); a validation check `test_fin_bend.gd` with the stiff numbers pinned and the bend `pending` | with 1 | `Game/dev/run_scenario.gd`, `Game/dev/run_reach.gd`, `tools/reach_check.sh`, `Game/sim/telemetry.gd`, the telemetry block of `windsurfer_sim.gd`, `Game/ui/hud.gd`, `Game/tests/validation/test_fin_bend.gd` (new), `validation_run.gd` (fields only) |
| 3 | `fin_physics` | The design above, in `fin_config.gd`, `fin_default.tres`, `fin_model.gd`, their tests, the spec (section 4 "The fin bends", 14, 16); the bend check becomes real; the comparisons of targets 3 and 4 | after Stop 1 | those files; `test_fin_bend.gd`; the telemetry block of `windsurfer_sim.gd` (to fill `fin_bend_tip_deg`) |
| 4 | `fin_look` | The fin mesh bends: a `ShaderMaterial` on the fin's `MeshInstance3D` in `rig_visuals.gd` displacing vertices sideways by `w1`'s shape and the telemetry's tip deflection, set each frame from the sim (the sim drives the visuals); the HUD line; stern-view screenshots at 12, 18 and 24 kt with the 37 and the 44 cm fin in `.screenshots/u2/`; the play-test checklist | after Stop 2 | `Game/windsurfer/rig_visuals.gd`, a new shader under `Game/windsurfer/` or `Game/assets/`, `Game/ui/hud.gd`, their tests; screenshots |

**The stops:**
- **Stop 1, the lead:** agents 1 and 2 in; the stiffness has a source or Max's measurement (or a labelled estimate the team accepts); nothing regressed. The lead then fills the numbers into the design and launches agent 3.
- **Stop 2: the lead reviews agent 3's diff itself, then Michiel reviews the physics.** Wait for his OK.
- **Stop 3: Max's play-test.** Then the team decides on the pull requests (U1, then U2).

#### Riding the fin: the experiments (Max, 19 October 2026, after Stop 2 was reached)

Max: "In real life, the more lift the fin generates, the looser the board feels. I think the player uses the fin's lift wrong and the physics may be correct. Try to lift the board with the character." The fin's lift is in the model now, but the sailor does nothing with it, so at the tail it only pushes the bow down (the wet front moved 0 to 9 cm forward). A real sailor rides the fin: weight on the back foot against the tail's lift, the leeward rail down, the sail sheeted in, so the tail rides on the fin and the hull's wet part shrinks.

**Agent 5, `fin_ride`: experiments only, with the overrides that exist, no game file changed.** On `u2/fin_ride`; report `Documentation/u2_reports/fin_ride.md`. The cases: the 18 kt beam reach first, then the 24 kt beam and broad reach and the 12 kt beam reach as spot checks, each 40 s with `tools/simulate.sh beam_reach 40 --wind_kt=W --twa=A --steady=1 --gradient=0 --out=<absolute>.csv` (or `tools/reach_check.sh` with the same overrides for all 9). The knobs (all in `sailor_default.tres` or `fin_default.tres`):
1. The weight aft: `--sailor.running_trim_deg=` 1.5 (today), 2, 2.5, 3, 3.5 (the vee raised the porpoising limit; find where it bounces again), with `--sailor.trim_press_max_m=` 0.3 (today) and 0.45, and `--sailor.hang_back_max_m=` 0.8 and 1.0.
2. The rail down: `--sailor.fin_load_bank_deg=` 4.5 (today), 8, 12, 16 (with the bending fin now; agent 2 did the stiff fin).
3. The fin: the 38 cm (today) and `--fin.span_m=0.44 --fin.area_m2=0.0411`; and the stiff fin `--fin.bends=0` as the control.
4. Combinations of the best of 1 and 2 with both fins.

**What to measure per run** (means over t ≥ 25 s): the wet front and the wet length, the push centre, the trim, the pitch standard deviation, the speed, the fin's lift, its upward part (`fin_up_n`), its roll moment against what the feet can hold (`feet_moment_max_nm` 120 N·m: how close to railing out), the heel, the harness, the mast-foot load, and the hull's grip: `hull_resistance_n`, `rail_grip_n`, `yaw_water_nm`, `roll_water_nm` (the board feels "loose" when the hull's sideways grip and its yaw damping fall and the fin carries the side force alone: report those as the looseness).

**What to report:** the combination that gives the shortest wet part while steady (pitch SD below 0.3°), not slower than today, and inside what the feet can hold; how far the fin's lift then carries the kit (its upward part as a share of the 900 N); whether the board gets "looser" by the measures above; where it bounces, rails out or spins out (the fin's share of stall). Then say which of the knobs is a sailor's choice (a technique the pilot and the assists could use when planing and powered up: a higher trim target, a bigger bank, within the feet's limit) and which would need a new behaviour or a sourced number, so the team can decide. Stop rules as in U1's brief; this is information for a decision, not a change.

**The agent prompt** is U1's, with U2 in place of U1: *You are agent <n>, `<name>`, of U2 in WindsurfingMMZB (Godot 4.7). Read CLAUDE.md and the U2 execution brief in Documentation/PLAYTEST_UPGRADES.md (and U1's brief above it for the rules), then do your package from the brief's agent table. Work in your worktree on the branch `u2/<name>`: make it from `feature/u2-fin`, or continue on it if it already exists. Commit as you go, and change only the files your row allows. Follow the rules, targets and stop rules, and be careful with tokens. Finish with your report (at most 300 words and one table) committed as Documentation/u2_reports/<name>.md, and return the same text.*

### Sources

- The beam: any strength-of-materials text (Euler-Bernoulli cantilever; `delta = P L^3 / (3 EI)` for a tip load). The elliptic loading: lifting-line theory, with the hull as an end plate (spec section 4).
- The fin's measured load: this repository, the 18 kt beam reach of 19 October 2026 (U1's Latest).
- The stiffness and the catalogue numbers: agent 1.
