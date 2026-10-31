# The autopilot rework: progress and the token ledger

The plan is [PLAN.md](PLAN.md). One row per round; the ledger is the lead's own token use for the round (the runs cost CPU, not tokens). Branch: `ph28/sail-and-hull` after Session 61's merges (nothing in `Game/sim/` changes here).

## Rounds

| Round | What | State | Tokens (lead) |
|---|---|---|---|
| 0 | The baseline on the merged physics (`ph28/sail-and-hull` at the rest stance 0.05) and the suite (`tools/autopilot_suite.sh`, `tools/autopilot_summary.py`; `rounds/r0.txt`) | done, 31 October 2026. Reach check: **18 kt 100° 15.44 m/s on 0.95 m at 1.46° (SD 0.24), 24 kt 100° 17.25 on 0.89 m at 1.34° (0.22): the goal's wet front, trim and steadiness met, the push 0.77 and 0.71 m (0.75 wanted)**; 18 kt 135° 11.76 on 1.18 m (0.33); 24 kt 135° 13.99 on 1.32 m, **SD 1.07 and a fall**; the close reaches bounce (18 kt 60° SD 1.55, 24 kt 60° 0.93, heel −9°: Max's 10° rail); the rake 0.64 to 0.72 on the planing reaches (off its stop), the rig's lean 22 to 24°, the sheet 0.82 to 0.91, the harness 722 to 798 N. Push check: neutral 2 falls (24 kt 48° and 135°), pushed 1 (24 kt 48°); made good 18 kt 5.96 / 12.45 / 8.23, 24 kt 6.58 / 13.94 / 12.36. Matrix: 24 cases, no fall. `.sim_output/autopilot/r0/` | about 25k |
| 1 | The existing levers one at a time (`rounds/r1.txt`): the rail's shape (U2's 2° to 160°, no upwind extra, 5° upwind, Max's to 160°), `lean_share` 0.3, `max_rake_deg` 18, `running_trim_deg` 3, the couple 250 N, the rig's lean 35°, the pilot's luff band 2° | running (ten variants, about 80 minutes) | |

## Commands

```
tools/autopilot_suite.sh --round=r1 --variants=Documentation/reports/autopilot/rounds/r1.txt     # one round, in the background
python3 -I tools/autopilot_summary.py r1                                                          # one table per variant
```

## To continue (for an AI session)

"Read CLAUDE.md, then Documentation/reports/autopilot/PLAN.md and this file. The goal is PLAN.md section 1; the levers section 2; the rounds section 3. Run the next round as one background batch, read its summary once, keep what meets the goal's rows without failing the others, write the row here with the token count, commit. Nothing in Game/sim/ changes; what needs it is written down for Michiel."
