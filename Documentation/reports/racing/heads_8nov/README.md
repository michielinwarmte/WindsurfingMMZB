# The skipper's heads trained on Silvaplana (night of 8 November 2026)

Max's ask (00:30): train the rule-based skipper's heads one at a time (1 course sailing, 2 the start,
3 the racing rules, 4 tactics, 5 the personas) until 9:30, on Silvaplana only, from slightly random
places so it is no one-trick pony, the courses off the shore, enough information about the wind, the
water and the shore, every weird failure looked into and fixed, more wind if there is time.

Branch `ai/skipper-heads-8nov` (from `physics/realism-7nov`), worktree `WindsurfingMMZB-fixes`. Nothing in
`Game/sim/` (the physics) and nothing in the autopilot changed. The log of the night, step by step, with
every number: [PROGRESS.md](PROGRESS.md).

## How the training works (the tools)

- **The suite** (`tools/heads/`): Godot sails the all-rounder alone on Silvaplana, headless, 14 at a time:
  - *races*: every lake course at three hours, from a random spot round the start (the game's spawn);
  - *drops*: the board set down at a random open-water spot on a random leg, heading roughly along it,
    at a random hour, two steps to sail (`tools/race.sh ... --drop_step=random --drop_seed=N`);
  - *starts*: eight personas from random spots, the countdown and 90 s after the gun;
  - *fleet races*: the eight personas, the whole race, with the rules and the wind shadows.
  Every seed gives new places and hours, so a new seed is a test the skipper has never seen.
- **The score** (`tools/heads/suite.py <folder>`): a case is clean when the board gets there, never runs
  aground, never falls and is never stuck; every failure is listed with what the skipper was doing.
- **The fixes** come from reading the failures' tracks (the skipper's aim point is now in the track file).
- **The numbers** are chosen by A/B runs on the suite (`--skipper.<field>=<n>` sets a number of every
  skipper's sheet), never by guessing.

## What changed (results below)

(filled in at the end of the night)
