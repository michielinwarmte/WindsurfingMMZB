# The wind tunnel (PH15): progress and the token ledger

Michiel, 13 November 2026: "You can build the simulations. However if beneficial each test can take up to 45 min."
The goal: the wind shadow's numbers (`Game/config/wind_shadow_default.tres`, PHYSICS_SPEC.md 8.11) measured behind a
windsurf rig in a GPU wind tunnel, where Max's research (13 November, [RESEARCH.md](../racing/dirty_wind_13nov/RESEARCH.md))
found only yacht data and estimates; with PH42 (the shadow's edge) on the way. Branch `ph15/wind-tunnel` from
`ai/roundings-13nov`. Nothing in `Game/` changes here: the numbers are a proposal for Michiel.

The tools: `tools/wind_tunnel.sh` (the tunnel), `tools/cfd/` (the solver `lbm.py`, the rig `rig_shape.py`, the runs
`wind_tunnel.py`, the reading `analyse_wake.py`, the steady states `steady_states.py`, the batch `run_all.sh`).

## Steps

| Step | What | State | Tokens (lead) |
|---|---|---|---|
| 0 | GitHub pulled twice (Max's push of 13 November: `ai/roundings-13nov`, the trail along the apparent wind); the GPU measured (461 M cell updates a second on 9.4 M cells, 3.8 GB) | done | about 60k |
| 1 | The game's steady states: `tools/reach_check.sh --twas=48,100,135 --winds=12,18,24 --csv=1`, averaged by `steady_states.py` (the sail's angle of attack, lift, drag, rake, lean, the sailor's place) | done: nine steady cases, no falls | about 15k |
| 2 | The solver and its checks. Three faults found and fixed: (a) the moving-water floor made the method unstable at air's own viscosity (a millionth's disturbance grew into a jet): the water is a slippery floor; (b) grazing links at a membrane's edge bounced at one end only: the plate's drag coefficient read 5.8, now 1.26 on 20 cm cells; (c) `torch.compile` was suspected and cleared (it agrees with plain PyTorch to 1e-7) | done: the square plate 1.243 on 10 cm cells (Hoerner 1.17; the tunnel's 2 % blockage is about 5 % of it) | about 70k |
| 3 | The solid sail fails its check: a flat wing (aspect ratio 2.5, 10°) gives a lift coefficient of 0.24 to 0.31 against about 0.5 to 0.6, and 0.11 of drag at 0° (about ten times real friction); on 5 cm cells 0.39 (the trend reaches about 0.5 at no cell size). 10 cm cells cannot hold a sail's boundary layer, and 5 cm cells for the whole wake would need 130 M cells. **Changed to the actuator model** (the wind-farm method, Sørensen and Shen 2002): the rig as the game's own forces on the air, spread over the sail and the sailor. Its check, an actuator disk (thrust coefficient 0.6): the air at the disc 0.83 to 0.85 of the wind (momentum theory 0.816), the wake toward 0.66 (theory 0.632 before it mixes), the momentum 90 to 101 % of the thrust | done | about 60k |
| 4 | Two more faults: (a) a 2-step flicker of 2 m/s across the wind everywhere (the shear stresses flip each step at air's own viscosity and never die): a viscosity floor of 0.001 in lattice units kills it (0.02 m²/s at 10 cm, a few percent of a wake's turbulent mixing); (b) the sail's vortex system reached the walls of a 26 x 12 m tunnel (the shadow 5 to 20 % weaker beyond 20 m than in 40 x 16 m): the tunnel is now 40 m wide and 16 m tall. Added: gusty inflow (random Fourier modes, a von Kármán spectrum, about 10 % gustiness at the rig, as over open water), sponges at the edges, the push eased in, the pressure saved for the momentum check (the along-wind budget closes to about 15 %) | done | about 70k |
| 5 | The production runs: 15 cm cells, a tunnel 8 + 50 m long, 40 m wide, 16 m tall (10.9 M cells), gusty air (10 % at the rig) averaged over 17 to 19 flow-throughs (about 45 minutes a case); the analysis by bell curves across the at-rest deficit (the noise floor kept out) | the 18 kt beam reach done (46 min): a board at rest behind loses 8.2 % of its wind at 2 m, 4.7 at 5, 3.4 at 10, 2.7 at 20, 2.3 at 40 m (about 1 / sqrt(distance), as Roncin and Kobus 2004 found for yachts); half-width 1.5 to 3.4 m; bent 3.6° toward the caster's stern; a same-tack follower at its speed headed 3.9° at 2 m, 1.9 at 10, 0.6 at 40 m; the game now: 30 % to 5 m, nothing beyond 20 m. Then the other five (41 to 43 min each; paused at 17:25 for a restart of Michiel's PC, the batch resumed at 17:51 on the new NVIDIA driver 620.70) | about 60k |
| 6 | All six together, the smooth-air bound, the cost and the proposal: at rest 10.6 / 5.3 / 3.7 / 2.9 / 2.3 / 2.0 % at 2 / 5 / 10 / 20 / 30 / 40 m (mean of six; smooth air 5.0 % at 5 m); the "same-speed" share dropped (it magnifies the gusts' noise about four times for a planing board); the game's factor gives most of the header (`header_check.py`); what it costs a board in the game (`reach_check.sh` at 12.6 to 18 kt); a 20-board race timed with the trail at 20 m and 55 m (+25 % and +124 % against no shadows); the options' error over 2 to 20 m (now 15.5 points, A 1.5, B 1.0, C 0.8); the thresholds on the factor (0.85, 0.92) found to need moving with it; the report `wind_tunnel.md` | done | about 90k |
| 7 | The cells' check (smooth air, the 18 kt beam reach, 15 against 10 cm) | done, 18:30: at rest 4.9 against 4.9 % at 5 m, 3.6 against 3.5 at 10, 3.0 against 2.7 at 20; widths within 0.25 m; 15 cm is fine enough. The pictures copied to `pictures/` | about 15k |

Found on the way, not this work's: `test_feet_press.gd` (two runs pinned to 5 decimals) and `test_windsurfer_sim.gd`
(the catapulted board rolls over, 180° against below 90) fail on this PC on `ai/roundings-13nov` as pulled, before
and after the restart; nothing in `Game/` was changed and Max's last push changed no physics. Likely Windows against
Linux floating point in chaotic runs (the numbers were pinned on Max's PC); not proven.

## Ledger

The lead (Claude Opus 5.5 in Claude Code, on Michiel's PC) works alone: no agents. About 425k tokens over the steps.
The GPU runs: about 6 hours of GPU time (six cases at about 42 minutes, the bound, the checks, the tries).

## To continue (for an AI session)

"Read CLAUDE.md, then Documentation/reports/ph15_wind_tunnel/PROGRESS.md and wind_tunnel.md. If Michiel and Max take
option A (section 7): change the six numbers in Game/config/wind_shadow_default.tres together with the thresholds on
the factor (DIRTY_FACTOR in Game/dev/run_race.gd, SLALOM_GAP_DIRTY and SLALOM_GAP_CLEAN in Game/race/skipper.gd,
SkipperConfig.dirty_air_share), run tools/test.sh and tools/check.sh, then measure the start suite on and off by
Documentation/AI_TRAINING_METHOD.md and the fleet of twenty for PH42 (section 8). The tunnel itself:
tools/cfd/run_all.sh (about 45 minutes a case on the GPU)."
