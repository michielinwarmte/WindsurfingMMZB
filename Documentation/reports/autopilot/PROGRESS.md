# The autopilot rework: progress and the token ledger

The plan is [PLAN.md](PLAN.md). One row per round; the ledger is the lead's own token use for the round (the runs cost CPU, not tokens). Branch: `ph28/sail-and-hull` after Session 61's merges (nothing in `Game/sim/` changes here).

## Rounds

| Round | What | State | Tokens (lead) |
|---|---|---|---|
| 0 | The baseline on the merged physics (Session 61's measurements) and the suite (`tools/autopilot_suite.sh`, `tools/autopilot_summary.py`) | started 31 October 2026 | |

## Commands

```
tools/autopilot_suite.sh --round=r1 --variants=Documentation/reports/autopilot/rounds/r1.txt     # one round, in the background
python3 -I tools/autopilot_summary.py r1                                                          # one table per variant
```

## To continue (for an AI session)

"Read CLAUDE.md, then Documentation/reports/autopilot/PLAN.md and this file. The goal is PLAN.md section 1; the levers section 2; the rounds section 3. Run the next round as one background batch, read its summary once, keep what meets the goal's rows without failing the others, write the row here with the token count, commit. Nothing in Game/sim/ changes; what needs it is written down for Michiel."
