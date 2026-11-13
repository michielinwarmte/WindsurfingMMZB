# The wind tunnel: a windsurfer's wind shadow measured on the GPU (PH15)

13 November 2026, branch `ph15/wind-tunnel` (from `ai/roundings-13nov`). For Michiel (the physics) and Max.
The measurement changed nothing in `Game/`; Michiel then took option A (section 7), built the same day with the
thresholds that read the shadow (section 7, "Built"). Nothing in `Game/sim/` changed.

## In short

- **The game's dirty wind is about six times too strong and too short.** Behind the game's own rig, in gusty air as
  on open water, a board loses about **5 % of its wind 5 m behind, 4 % at 10 m, 3 % at 20 m and 2 % at 40 m**
  (six points of sail at 12, 18 and 24 kt, all within about 1.5 points of that). The game takes 30 % to 5 m, 20 %
  at 10 m and nothing beyond 20 m. Even in perfectly smooth air the tunnel's shadow is no stronger than 5 % at 5 m.
- **A simple reason:** a sail can only take out of the air the momentum of its own drag. The game's sail has about
  86 N of drag and the sailor about 80 N on the 18 kt beam reach; spread over a wake the size of the sail that is a
  few percent of the wind. A 30 % shadow would need about six times that force.
- **Max's trail along the apparent wind (13 November) is right.** The wake lies along the casting board's apparent
  wind, bent 2.5 to 5° further toward its stern on the fast cases (the game: 7°) and 3° the other way on the slow
  broad reaches.
- **The shadow's edge (PH42).** The game's edge is a jump of about 27 % of the wind over 2 m: three times the size of
  an ordinary gust. The tunnel's is about 5 % over 2 to 4 m, half an ordinary gust. This supports the guess that the
  catapults in the crowd come from boards sailing out of a too-strong shadow.
- **The header.** Close behind on the same tack a board is also headed 2 to 6°. The game's one number already gives
  a moving board most of that (its true wind cut swings its apparent wind forward); the rest is 1 to 2° close behind.
  No physics change is needed for it.
- **What it costs a board in the game:** at the tunnel's 5 %, a steady beam reach loses about 2 % of its speed, a
  beat 6 % and a broad reach (on the hump) 8 %. At the game's 30 %: 19, 31 and 39 %.
- **Built (Michiel's OK, 13 November 2026; section 7):** in `Game/config/wind_shadow_default.tres` `deficit` 0.30 →
  0.075, `full_until_m` 5 → 1, `stern_bend_deg` 7 → 3; Max's 20 m length and the widths stay (within 20 m the
  tunnel's widths match them). Its error against the tunnel: 1.5 points of the wind, against 15.5 before. No extra
  CPU (a 55 m trail more than doubled a 20-board race's CPU time). The thresholds that read the shadow moved with it.

## 1. Why

Max asked on 5 November to "simulate the numbers" of the wind shadow (PH15). On 13 November the shadow was turned to
follow each board's apparent wind as a trail of puffs (RA31, [RESEARCH.md](../racing/dirty_wind_13nov/RESEARCH.md)),
but its strength (30 % less wind, full for 5 m, gone at 20 m), its widths (2.5 m, widening 8°) and its bend (7°)
are taken from yacht tunnels, tactics books and estimates: the research found no measurement for a windsurfer. PH42
asks how sharp a shadow's edge is: in the fleet of twenty, catapults on close and beam reaches came in the crowd with
no skipper action before them, and the guess was the wind returning at once at the edge of a shadow.

This PC has an RTX 3080 Ti (12 GB). The tunnel built here puts the game's rig in moving air on it and measures the
air behind.

## 2. How the tunnel works, in plain words

**The air** is cut into cubes of 15 cm (10.9 million of them in a tunnel 58 m long, 40 m wide, 16 m tall). Each cube
holds 19 numbers: how much air in it moves in each of 19 directions. Every time step the numbers in each cube relax
toward the mix that fits the cube's density and speed, then move one cube along their direction. That is the
lattice-Boltzmann method; it suits a GPU because every cube does the same small sum at once (PyTorch, about 460
million cube updates a second). A turbulence model (Smagorinsky's) adds the viscosity of the eddies smaller than a
cube.

**The tunnel's frame is the board's.** The air comes in along the board's apparent wind at the sail: the game's wind
(growing with height as the game's `height ^ 0.11`) less the board's speed, so the apparent wind turns with height as
it does on the water (the lower air comes from further ahead). The water is a slippery floor. The incoming air is
gusty: about 10 % gustiness at the sail, as over open water (random Fourier modes from a von Kármán spectrum; Smirnov
et al. 2001), because a wake recovers mostly by mixing with the gusty air around it. A second run in smooth air gives
the longest a shadow can be.

**The rig is the game's own forces.** Each case is a steady state of the game's physics (`tools/reach_check.sh`:
flat water, steady wind, 25 to 40 s), and the tunnel takes from it the sail's lift and drag, its angle of attack,
the rake, the lean, the sheet angle and where the sailor hangs. The sail's force is spread over the sail's own shape
(the 8.0 m² outline, the mast raked and leaned, the boom square to the mast) with the share falling up the sail so
its centre is where the physics puts it; at each height the drag lies along that height's apparent wind and the lift
square to it, tilted up by the lean; the total is the physics' force exactly. The sailor's windage (the physics' 0.5
m² of drag area) is spread along a body from the feet to the shoulders. The air gets the opposite of each force.
This is how wind-farm studies model turbines in the same situation (the actuator line and surface, Sørensen and
Shen 2002); section 3 says why a solid sail did not work.

**What a board behind feels.** The tunnel gives the disturbance: the change the rig makes to the air, the same seen
from any board. A board behind feels it in its own apparent wind, so it matters how fast that board goes:

- *a board at rest* (waiting on the line): its apparent wind is the true wind plus the disturbance;
- *a board at the caster's speed* (two boards on the same reach): its apparent wind is the caster's plus the
  disturbance.

Both are averaged over a sail's height the way a sail's area is spread. The game's shadow is one number, the share of
the true wind left at a point (`WindShadows.factor_at()`), so each is turned into that share: the factor on the true
wind that gives the board behind the same apparent wind strength. "Deficit" below is one less that share, as the
game's `deficit`.

## 3. The checks, and what went wrong on the way

| Check | Tunnel | Expected | |
|---|---|---|---|
| A 2 m square plate across the wind, solid, 10 cm cubes | drag coefficient 1.243 | 1.17 (Hoerner 1965); the tunnel's 2 % blockage adds about 5 % | passed |
| A flat wing, aspect ratio 2.5, 10°, solid, 10 cm cubes | lift coefficient 0.24 to 0.31, drag 0.17; 0.11 of drag at 0° | about 0.5 to 0.6 (Helmbold, lifting line, measured plates) | **failed** |
| The same wing on 5 cm cubes | lift 0.39 | the trend reaches about 0.5 at no cube size | |
| An actuator disk, thrust coefficient 0.6 (the force model's check) | the air at the disc 0.83 to 0.85 of the wind; the wake toward 0.66; the momentum 90 to 101 % of the thrust | 0.816 and toward 0.632 (Rankine and Froude's momentum theory) | passed |
| The momentum the rig's wake carries (smooth air, with the pressure) | about 190 N along the wind | the 163 N the rig puts on the air | within about 15 % |
| The tunnel's size: 26 x 12 m against 40 x 16 m | the shadow 5 to 20 % stronger in the larger beyond 20 m | | the larger is used |
| The cubes' size: the 18 kt beam reach in smooth air at 15 cm against 10 cm (a tunnel 38 x 30 x 12 m) | at rest 8.5 / 4.9 / 3.6 / 3.0 % at 2 / 5 / 10 / 20 m against 8.0 / 4.9 / 3.5 / 2.7; widths within 0.25 m, headers within 0.1° | the same | passed: 15 cm is fine enough |

**Why the solid sail failed.** A wind tunnel of cubes cannot hold the thin layer of air that sticks to a sail unless
the cubes are far smaller than 10 cm: the flat wing had ten times a real plate's friction and half its lift. A solid
sail's wake would have been too strong. 5 cm cubes for the whole wake would need 130 million, beyond 12 GB. So the
sail became its forces (section 2), which also makes the shadow the game's own rig's.

**Faults found and fixed**, each by a test that showed it:

1. A floor moving at the board's speed made the method unstable at air's own viscosity: a disturbance of a millionth
   grew into a jet along the water in 3000 steps. The water is a slippery floor; the wind's height profile comes in
   with the inflow.
2. Links grazing a membrane's edge were bounced at one end and not the other, so air went through one way: the plate
   read a drag coefficient of 5.8. Every link is now bounced at both ends or neither.
3. At air's own viscosity the method's shear stresses flip sign every step and never die: the air flickered across
   the wind at 2 m/s every two steps. A floor on the viscosity of 0.001 in lattice units stops it; at 15 cm cubes it is
   0.03 m²/s, a few percent of the turbulent mixing in a wake (about 0.3 to 1 m²/s).
4. In a tunnel 26 m wide and 12 m tall the sail's vortex system reached the walls (the sideways momentum of the lift
   was lost there): the tunnel is now 40 x 16 m.

(`torch.compile` was suspected for fault 1 and cleared: the compiled sums agree with plain PyTorch to 1e-7.)

## 4. The results

Six of the game's steady states (`tools/reach_check.sh`, flat water, steady wind; the rig took exactly the
physics' lift and drag in every case), each in gusty air (about 10 % gustiness at the rig, measured in the tunnel at
9.5 to 10.1 %), 15 cm cubes, about 42 minutes each on the GPU. "At rest" is the share of the true wind a board
waiting behind loses, the game's `deficit` (section 2): the disturbance's part along the true wind, the same for every
board behind. Measured on the shadow's middle line by a bell curve across it (the gusts' leftover noise of 0.5 to 1.5
points is kept out); the half-width is where the shadow is half as strong as in its middle.

**Wind lost by a board behind, at rest (game now: 30 / 30 / 20 / 0 / 0 / 0 %)**

| Case | Board | Apparent wind | 2 m | 5 m | 10 m | 20 m | 30 m | 40 m |
|---|---|---|---|---|---|---|---|---|
| 18 kt beat (48°) | 7.2 m/s | 14.7 m/s at 25° | 11.0 % | 4.2 | 3.0 | 2.8 | 2.6 | 2.8 |
| 12 kt beam reach (100°) | 11.7 m/s | 12.0 m/s at 28° | 11.2 | 6.9 | 4.7 | 3.9 | 3.7 | 3.8 |
| 18 kt beam reach (100°) | 15.5 m/s | 16.4 m/s at 32° | 8.2 | 4.7 | 3.4 | 2.7 | 2.5 | 2.3 |
| 24 kt beam reach (100°) | 17.2 m/s | 19.1 m/s at 38° | 7.3 | 4.0 | 3.0 | 2.3 | 1.8 | 1.4 |
| 12 kt broad reach (135°) | 5.6 m/s | 4.3 m/s at 75° | 11.3 | 5.7 | 4.0 | 2.8 | 1.7 | 1.0 |
| 18 kt broad reach (135°) | 9.8 m/s | 6.7 m/s at 65° | 14.4 | 6.2 | 4.2 | 2.9 | 1.5 | 0.9 |
| **Mean** | | | **10.6** | **5.3** | **3.7** | **2.9** | **2.3** | **2.0** |
| 18 kt beam reach, smooth air (the most it can be) | | | 8.6 | 5.0 | 3.6 | 3.0 | 3.0 | 3.3 |

**Its width (half-width, m: where the shadow is half as strong as in its middle)**

| Case | 2 m | 5 m | 10 m | 20 m | 40 m |
|---|---|---|---|---|---|
| The game now (its parabola) | 2.0 | 2.3 | 2.8 | 3.8 | 5.7 |
| 18 kt beat | 0.7 | 1.3 | 1.7 | 2.0 | 3.9 |
| 12 kt beam reach | 1.7 | 2.8 | 2.9 | 4.0 | 3.6 |
| 18 kt beam reach | 1.5 | 2.4 | 2.6 | 3.2 | 3.2 |
| 24 kt beam reach | 1.1 | 1.6 | 1.8 | 2.4 | 2.9 |
| 12 kt broad reach | 1.2 | 2.1 | 2.8 | 3.9 | 3.0 |
| 18 kt broad reach | 1.0 | 2.2 | 3.1 | 4.4 | 3.0 |

**Its line and the header.** The shadow's middle line lies along the casting board's apparent wind at its sail, bent
toward its stern by +4.6° (beat), +4.8 / +3.6 / +2.5° (beam reaches at 12, 18, 24 kt) and −3.0 / −2.6° (the slow broad
reaches: bent toward the bow). Richards et al. (2012) measured 5° upwind and 9° on a reach for yachts; the game uses 7°.
A board close behind on the same course is also headed: the tunnel measures 2 to 6° at 5 m, 1 to 3° at 10 m, under 2°
at 20 m. Cutting its true wind by the at-rest share already swings a moving board's apparent wind forward by most of
that in the game's own wind triangle (`tools/cfd/header_check.py`): within 1° from 10 m on every case; 1 to 2° short
at 5 m on the beam reaches and the beat.

**The good place.** The most extra wind anywhere is 2 to 7 %, about 1 m ahead of the mast: inside the rig's own space,
where no other board can be. The "safe leeward" gain of the yacht books does not show at a board's distance.

**Gustiness in the shadow.** About the same as outside it (9.5 to 12 % against 10 %): the shadow does not make the
air noticeably gustier.

**Pictures** (from above; the apparent wind blows left to right, grid lines every 5 m, the mast foot a black dot; red is
less wind for a board at rest, blue more, the darkest red 6 % or more; the black outline is the area of the game's
shadow, laid along the measured line from the mast, the same now and in the proposal of section 7, which changes only
its strength): [18 kt beam reach](pictures/reach_18_100_shadow.png), [18 kt beat](pictures/reach_18_48_shadow.png),
[12 kt broad reach](pictures/reach_12_135_shadow.png); the header behind the 18 kt beam reach (red: headed, ±4°):
[header](pictures/reach_18_100_header.png).

## 5. The shadow's edge (PH42)

PH42 asks how quickly the wind comes back as a board sails out of another's shadow. Across the shadow the wind returns
from 90 % to 10 % of its loss over 1.9 to 4.0 m at 5 m behind (2.4 to 4.4 m at 10 m). The game's parabola does it over
about 2 m, and its loss is 30 %: **a jump of about 27 % of the wind in 2 m**, against the tunnel's **about 5 % over 2
to 4 m**. The open water's ordinary gusts are about 10 % (rms) of the wind. So the game's shadow edge is a gust three
times the size of an ordinary one, met in a fraction of a second at planing speed; the tunnel's is half an ordinary
gust. That fits the guess in [start.md](../fleet_speed/start.md) section 5: the catapults on close reaches in the
crowd (8 of the 15 falls in the fleet of twenty, none of the skipper's doing) come from boards sailing out of a
too-strong shadow. It is not proven: the test is the fleet of twenty again with the new numbers (section 8).

## 6. What it costs a board

The game's steady reaches (`tools/reach_check.sh`) in the wind the game's shadow leaves and in the tunnel's, against
clean 18 kt:

| Wind left | Where | Beat (48°) | Beam reach (100°) | Broad reach (135°) |
|---|---|---|---|---|
| 70 % (12.6 kt) | the game now, 5 m behind | −31 % | −19 % | −39 % |
| 80 % (14.4 kt) | the game now, 10 m behind | −22 % | −10 % | −28 % |
| 95 % (17.1 kt) | the tunnel, 5 m behind | −6 % | −2 % | −8 % |
| 97 % (17.5 kt) | the tunnel, 20 m behind | about −3 % | about −1 % | about −5 % |

(The last row is read between the 17.1 and 18 kt runs.) So dirty wind stays worth avoiding with the tunnel's numbers,
most of all upwind and on the broad reach, where the board sits on the hull's hump (GP11). It stops being a wall.

## 7. The proposal

The game's shadow has one shape (`WindShadows`, `WindShadowTrail`): `deficit` held to `full_until_m`, then a straight
fade to nothing at `length_m`; across it a parabola `half_width_m` wide at the sail, widening at `spread_deg`. The
tunnel's shadow fades more slowly (about as one over the square root of the distance, as Roncin and Kobus 2004 found
behind yachts) and still takes 2 to 3 % at 20 to 40 m.

**The length is a cost.** The trail's puffs are checked by every other board, so a longer trail means more of them.
Timed on a 20-board race (T2, 18 kt, 60 s countdown and 60 s of racing, headless, in a frozen copy of the game; seed
1): no shadows 338 s, the trail at 20 m (now) 424 s (+25 %), at 55 m 758 s (+124 %). So the proposal keeps Max's 20 m.

**The options** (the error is the rms difference from the six cases' at-rest shadow over 2 to 20 m, in points of the
wind; the six cases differ among themselves by 0.8):

| Option | `deficit` | `full_until_m` | `length_m` | `half_width_m` | `spread_deg` | `stern_bend_deg` | Error | Cost |
|---|---|---|---|---|---|---|---|---|
| The game now | 0.30 | 5 | 20 | 2.5 | 8 | 7 | 15.5 | |
| **A (recommended)** | **0.075** | **1** | 20 | 2.5 | 8 | **3** | **1.5** | none: the `.tres` file only |
| B | 0.057 | 1.5 | 40 | 2.9 | 4 | 3 | 1.0 | about +70 % of a race's CPU (between the 20 and 55 m timings) |
| C | 5.5 % × √(5 m / distance), to 20 m | | 20 | 2.5 | 8 | 3 | 0.8 | a small change to the fade's formula in `race/wind_shadows.gd` and its test |

- The widths: fitted within 20 m they are 2.2 m and 7°, the game's 2.5 m and 8° are within 0.1 m of that fit's error;
  kept.
- The bend: +2.5 to +4.8° on every fast case, −3° on the two slow broad reaches; 3° favours the planing boards that
  race each other.
- `most_deficit` (0.5, several shadows added up): not measured (one sail per run). With shadows of 7.5 % it takes
  seven boards in a line to reach it, and adding against multiplying differs by under half a point for two.
- `follows_apparent_wind` stays on: the tunnel confirms the trail along the apparent wind.

Option A is a change of three numbers in one config file that is outside the physics (`Game/race/`'s resource), so
it does not need `tools/test.sh validation`. **But it must not go in alone:** the races and the AI read this factor
against fixed thresholds made for the 30 % shadow. A board counts as in dirty wind below 0.85 of the wind (15 %
lost: `DIRTY_FACTOR` in `dev/run_race.gd`, the start suite's dirty-wind seconds; `SLALOM_GAP_DIRTY` in
`race/skipper.gd`; `SkipperConfig.dirty_air_share` 0.15) and as clean above 0.92 (`SLALOM_GAP_CLEAN`). With option A
one shadow takes at most 7.5 %, so no board would ever count as dirty unless two shadows overlap, and the slalom
start's clean-wind spot would be found everywhere. Those thresholds would move with the numbers (0.96 dirty and 0.98
clean are the same shares of a 7.5 % peak as 0.85 and 0.92 are of 30 %: a half and about a quarter), and the start
suite would be measured again on and off by Max's method.

### Built (13 November 2026)

Michiel: "Please implement the option without extra cpu. Also implement the other changes". Option A, with every
threshold that reads the factor scaled to the new strength (a quarter of before: dirty is half a full shadow, clean
about a quarter of one), each with a comment saying why:

| Where | What it is | Before | Now |
|---|---|---|---|
| `config/wind_shadow_default.tres` (and the script's defaults, `race/wind_shadow_config.gd`) | `deficit`, `full_until_m`, `stern_bend_deg` | 0.30, 5, 7 | 0.075, 1, 3 |
| `dev/run_race.gd` `DIRTY_FACTOR` | the start suite's dirty-wind seconds (`dirty_s`, the training method's "clean wind" check) | 0.85 | 0.9625 |
| `race/skipper.gd` `SLALOM_GAP_DIRTY`, `SLALOM_GAP_CLEAN` | the slalom start's spot out of dirty wind | 0.85, 0.92 | 0.9625, 0.98 |
| `race/skipper_config.gd` `dirty_air_share` | the scripted skipper tacking out of dirty air | 0.15 | 0.0375 |
| `race/persona.gd` `DIRTY_AIR_SHARE_POOR`, `_BEST` | the same, by persona (the poor sense notices only a full shadow) | 0.3, 0.12 | 0.075, 0.03 |
| `race/race_hud.gd` | "in a wind shadow: n % less" shown from | 3 % | 2 % |

The tests: `test_wind_shadows.gd` checks the cone's shape on a test cone with the old round numbers and pins the
default to the tunnel's (`test_the_default_is_the_wind_tunnels_shadow`); `test_wind_shadow_trail.gd` asks for "in
the shadow" as at least 3 % less (it was under 85 %); `test_skipper_slalom_clean_wind.gd`: a board level just to
leeward of another now moves 5 m to leeward instead of 10 (the real shadow fades sooner); new,
`test_dirty_wind_thresholds.gd` ties every threshold to the config's `deficit`, so a later change of the shadow's
strength fails until they move with it; `test_race_env.gd`: the board 6 m behind another loses 4.6 % of its wind
and is still the slower one (it asked for 5 % or more, now 2). Unit tests 1095 of 1097 (the two that fail are
TE8's, failing on this PC before the change too); `tools/check.sh` 517 files, 0 failed. Not done: the start
suite on and off and the fleet of twenty (below); the trained brains (`Game/race/brains/`) learned with the 30 %
shadow and now meet a weaker one.

**For the play-test:** in a race, sail behind and beside other boards: the HUD's "in a wind shadow" shows 2 to 8 %
now (up to 30 before); does dirty wind still feel worth avoiding, especially upwind? Do the AI boards still pick
clean spots at the slalom start, and fall less in the crowd at the start of T1 in 18 and 24 kt (PH42)?

## 8. What was not done, and the next steps

- **Two or three sails in one run** (how shadows add up): not run.
- **The fleet test for PH42:** the fleet of twenty again (`tools/persona_matrix.sh --courses=t1_loop,t2_slalom
  --run=fleet_ph15` with the proposed numbers), counting the catapults on close reaches in the crowd (8 of 15 falls in
  `fleet_after`). Falls are rare (15 in 120 races), so it needs a few seeds: a CPU job of some hours.
- **The AI's start training** (E09, phase S3) scores dirty wind in seconds under the old shadow; its thresholds would
  be looked at again with the new numbers (Max's method: on and off on the tune set, confirmed on the hold-out).
- **A direction term** (the 1 to 2° of header the one number misses close behind): a physics change
  (`WindDisturbance` gives a factor only), not worth it for that size.
- **The solid sail** at 5 cm cubes over a short wake (the sail's own lift and drag from the air, not from the game)
  would need about 25 M cells: it fits the GPU, and is the way to check the game's sail coefficients themselves
  (PH28's tunnel data cover that already).

## How to run it again

```
tools/reach_check.sh --twas=48,100,135 --winds=12,18,24 --csv=1     # the game's steady states
tools/wind_tunnel.sh states                                         # their sail numbers, to JSON
tools/wind_tunnel.sh --check=plate --dx=0.1                         # the solver's checks (and --check=disk, --check=wing)
tools/cfd/run_all.sh                                                # every case (about 45 min each), then the analysis
tools/wind_tunnel.sh analyse --dx=15                                # the tables and pictures, .sim_output/cfd/
python -I tools/cfd/header_check.py                                 # the header the game's factor gives
```

The tools: `tools/wind_tunnel.sh`, and in `tools/cfd/`: `lbm.py` (the air), `rig_shape.py` (the rig and its forces),
`inflow_turbulence.py` (the gusts), `wind_tunnel.py` (the runs and checks), `analyse_wake.py` (the reading),
`steady_states.py`, `header_check.py`, `run_all.sh`. Python with PyTorch and CUDA (the venv `tools/train.sh` uses).
