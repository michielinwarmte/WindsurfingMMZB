# The AI sailors fastest around two courses: progress and the ledger

The plan is [PLAN.md](PLAN.md). One line per launch, report and merge, newest at the bottom; the ledger counts the agents' tokens (Michiel's Opus usage) and the lead's.

## Ledger

| Who | Package | Tokens | State |
|---|---|---|---|
| the lead (Fable) | the plan, the briefs, the baseline, the diffs, the merges | ~0.1 M so far | running |
| the speeder (Opus, xhigh) | 1, the skipper's speed | — | running |
| the tacker (Opus, xhigh) | 2, the trainer's tacks | — | running |
| the caster (Opus, xhigh) | 3, the characters | — | waits for 1 |

## Log

- 1 November 2026, 21:35: the baseline started (`tools/race_matrix.sh` and `tools/persona_matrix.sh --wind_kt=18`, eight Godot processes) in the lead's repo; the worktrees `../WindsurfingMMZB-speed` (`race/skipper-speed`) and `../WindsurfingMMZB-tacks` (`race/train-tacks`) made from `gear/lead` (f020528).
- 1 November 2026, 21:50: the plan written; the speeder (package 1) and the tacker (package 2) launched at once.
