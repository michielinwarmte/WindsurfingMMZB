# Max's six asks of 6 November 2026 (afternoon): the lead's progress file

Started 15:45 on 6 November 2026 by the lead (Claude Fable 5.1) on Max's PC, with Opus 5.5 agents as Max asked ("Run them with opus 5.5 agents"). Base for every branch: `play/6nov-evening` at f72f565 (the evening play-test code with Max's 15:40 key change committed: push on W/S, sheet on Up/Down). Nothing is pushed; nothing goes to `main` without the team.

## The asks (Max's words) and who builds them

| # | Max's ask | Branch (worktree) | Agent | Report |
|---|---|---|---|---|
| 1 | Push in combination with mouse control | `gp2/push-mouse` (WindsurfingMMZB-gp2) | Opus, wave 1 | `gameplay/gp2_push_on_mouse.md` |
| 2 | Silvaplana changable wind (multiplier) | `gr/wind-on-water` (WindsurfingMMZB-shading) | Opus, wave 1 (with 3) | `waves/wind_on_water.md` |
| 3 | Make the windstrength visable to the player. Look at how other games have done this. No white stripes, but effects that happen in real life high winds too. (Visible on watershader) | `gr/wind-on-water` | the same agent | the same |
| 4 | General fx improvements (board to water) | `gr/board-fx`, after 3 is in | Opus, wave 2 | `waves/board_fx.md` |
| 5 | The autopilot still crashes. The detection of what a crash would be is too strict. Move this bar and make the autopilot try harder to stay on the board. | `autopilot/stay-up` (WindsurfingMMZB-fixes) | Opus, wave 1 | `autopilot/stay_on_the_board.md` |
| 6 | Add more fins: Z fins > M fins, Finish fins > Start fins, Carpenter fins > Blacksmith fins, Hurricane fins > Typhoon fins, NP7 > NT8. Add just the brands with a size slider from 28-52 cm. Also add this for the fins already in the game. | `gear/fin-brands`, wave 2 | Opus, wave 2 | `fleet_gear/fin_brands.md` |

CLAUDE.md's rule: at most three Opus agents at a time, so 1, 2+3 and 5 run first; 6 and 4 start as slots free (4 after 3, because both change the water shader).

## The lead's readings where Max could not be asked

- Ask 1: with the body on the mouse, the push goes on the mouse too (the wheel moves the level, the left button is a full push while held), W/S keep working, and the push and the body must not cancel each other silently. The report states this as the assumption for Max to correct.
- Ask 2: a settings slider "Lake wind" times the map's wind (0.5 to 2.0, default 1 = today), plus `--lake_wind_scale=`.
- Ask 3: the water only (Max: "Visible on watershader"); "white stripes" are the wind viewer's Windfinder streaks and painted foam lines, so none of those on the sailing water.
- Ask 5: "the bar" is the fall rule's thresholds in `SailorConfig` (catapult 20°, fell back 25°, standing 40°, the tip time): physics numbers, Michiel's, changed in their own [physics] commits for his review because Max asked for it.
- Ask 6: each fin brand becomes one slalom fin with a continuous size 28 to 52 cm (a slider on the Gear page), the existing Montag and PJ New Sealand fins too; the AI's picks keep working.

## Token ledger

| Agent | Branch | Launched | Done | Tokens (agent's own count) |
|---|---|---|---|---|
| wind look + multiplier | `gr/wind-on-water` | 15:46 | | |
| autopilot | `autopilot/stay-up` | 15:46 | | |
| push on the mouse | `gp2/push-mouse` | 15:47 | 16:38 | 0.31 M (883/883 unit, check 460/0; LAN test not run: a live game held the port) |
| fin brands | `gear/fin-brands` | | | |
| board fx | `gr/board-fx` | | | |

## Merging and the play folder

When an agent reports: read its diff (every `Game/sim/` change in full, for Michiel), run `tools/test.sh` and `tools/check.sh` on the merged tree, merge into `play/6nov-evening` here (WindsurfingMMZB-playtest), then build a play folder `WindsurfingMMZB-play-6nov2026-night` with `tools/release.sh build`, copying the evening-keys folder's launchers and cfgs forward (push AND body on in every launcher: `push_and_body.cfg`), a README that says what is new, a screenshot check from the folder's own exe, and the zip.

## Log

- 15:44 the three branches made from f72f565 in the three free worktrees (their old branches `ph44/swan`, `ui/race-screen`, `gr/sailor-polish` are merged and kept).
- 15:46 three agents launched.
- 16:38 push on the mouse merged (c9efc5e, a49686a). The agent's LAN test joined the live play-test game on this PC for 40 s (the port is fixed, 47520): no LAN tests while wsim.exe runs; the other agents told. Fins agent started in WindsurfingMMZB-gp2 on gear/fin-brands.
