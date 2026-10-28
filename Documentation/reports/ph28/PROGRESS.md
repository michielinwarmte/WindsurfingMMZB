# PH28 + PH16: progress (the live state of the branch `ph28/sail-and-hull`)

Max, 28 October 2026: build the sail from the iQFOiL wind-tunnel study, combine it with the hull's wet length, "test and improve until tokens run out, save along the way". Nothing is merged without Michiel's OK. The findings and numbers are in [sail_wind_tunnel.md](sail_wind_tunnel.md).

## Steps

| # | Step | State |
|---|---|---|
| 1 | The paper committed (`Documentation/2501.13254v1.pdf`) | done, a71c5bf |
| 2 | The sail's numbers and its twist (sail model, config, autopilot, spec 2.17, tests) | done, 8584330. Four tests brought to the new sail: the catapult test sheets in at 24 kt (a 75 kg sailor now holds the 6.5 at 18 kt, as in real life); `test_race_env.gd`'s dropped board 5 m in 10 s (7 m now, 10 before) and the course policy within 270 s (245 s now, under 240 before); thin air with the twist. `tools/check.sh` passes. The validation run is in `.logs/ph28_valid.txt` |
| 3 | The measurements: push check, reach check A to D, drag budget | done (the report). The twist on against off in gusts and waves: `tools/push_check.sh --sweep=sail.twist_pressure_pa=140,0 --seconds=120 --jobs=2 --run=ph28_twist` |
| 4 | The hull: why the board rides at 1° of trim with 1.7 m wet | measured, not changed (the report's "What this means"); the levers are the rig's load path (U1.2: harness 663 N, mast foot 365 N) and the porpoising limit, both in Michiel's sailor and hull models, where U1's stop rules fired. The roadmap's PH16 has it |
| 5 | Roadmap, progress log, docs index | done, 63754be |

## Commands used

```
export GODOT=/c/Users/maxba/AppData/Local/Programs/Godot/Godot_v4.7.2-stable_win64_console.exe
tools/reach_check.sh                                    # the tunnel's sail (now the default)
tools/reach_check.sh --sail.camber=0.10 --sail.zero_lift_deg_per_camber=60 --sail.lift_slope_factor=0.9 --sail.cl_transition_gain=0.3 --sail.alpha_luff_deg=5 --sail.twist_pressure_pa=0   # the legacy sail
tools/push_check.sh --sweep=sail.zero_lift_deg_per_camber=60,20 --seconds=120 --jobs=3 --run=paper_zero_lift
tools/simulate.sh beam_reach 60 --wind_kt=18 --twa=100 --steady=1   # the drag budget
```

## To continue (for an AI session)

"Read CLAUDE.md, ROADMAP.md (PH28, PH16), then Documentation/reports/ph28/sail_wind_tunnel.md and this file. Check out `ph28/sail-and-hull`. The sail is rebuilt from the wind tunnel (spec 2.17). Continue with the first open step in the table above, measuring with `tools/reach_check.sh` against the report's tables. Commit and update this file after every step. Physics changes need Michiel's OK before any merge."
