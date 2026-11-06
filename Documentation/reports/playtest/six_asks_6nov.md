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
| wind look + multiplier | `gr/wind-on-water` | 15:46 | 17:05 | 0.61 M (0.5 + 0.11 research helper; 886/886 unit, check 461/0, validation 38/8/2 same reds; crest spray not built) |
| autopilot | `autopilot/stay-up` | 15:46 | 18:40 | 0.54 M (886/886 unit, check 461/0, validation same 8 reds, LAN PASS; two [physics] commits 9f5390a, 702830b for Michiel) |
| push on the mouse | `gp2/push-mouse` | 15:47 | 16:38 | 0.31 M (883/883 unit, check 460/0; LAN test not run: a live game held the port) |
| fin brands | `gear/fin-brands` | 16:40 | 17:38 | 0.40 M (891/891 unit, check 472/0; matrix at 28 and 52 cm, no NaN; stiffness question for Michiel) |
| board fx | `gr/board-fx` | 17:10 | 18:30 | 0.98 M (0.9 + 0.08 helper; 910/910 unit, check 464/0; no measurable frame cost) |

## Merging and the play folder

When an agent reports: read its diff (every `Game/sim/` change in full, for Michiel), run `tools/test.sh` and `tools/check.sh` on the merged tree, merge into `play/6nov-evening` here (WindsurfingMMZB-playtest), then build a play folder `WindsurfingMMZB-play-6nov2026-night` with `tools/release.sh build`, copying the evening-keys folder's launchers and cfgs forward (push AND body on in every launcher: `push_and_body.cfg`), a README that says what is new, a screenshot check from the folder's own exe, and the zip.

## Log

- 15:44 the three branches made from f72f565 in the three free worktrees (their old branches `ph44/swan`, `ui/race-screen`, `gr/sailor-polish` are merged and kept).
- 15:46 three agents launched.
- 16:38 push on the mouse merged (c9efc5e, a49686a). The agent's LAN test joined the live play-test game on this PC for 40 s (the port is fixed, 47520): no LAN tests while wsim.exe runs; the other agents told. Fins agent started in WindsurfingMMZB-gp2 on gear/fin-brands.
- 17:08 wind on the water + lake wind multiplier merged (ce63b35, b1c568f, 5a0acaa; merge 3e8e938). Contact sheets looked at: 8 to 30 kt clearly different, no stripes. Left over: spray off crests above 25 kt, handed to the board-fx agent. Board-fx agent started in WindsurfingMMZB-shading on gr/board-fx.
- 17:40 fin brands merged (e6a6c90..9657e9b). Open for Michiel: the race-shaped fins bend about 1.9x the measured test fin at the same depth (since GE3; a data-only fix is in the report). Open for Max: the colours and marks, the wind ranges on the cards.
- 17:50 interim play folder WindsurfingMMZB-play-6nov2026-night (+ .zip) from 893c6c2: push on the mouse, lake wind multiplier, wind on the water, fin brands; launchers and cfgs copied from evening-keys; checked with a 3137x1263 lake race screenshot from the folder's own exe (.screenshots/play_night_check_3137.png): both gauges, the key strip's wheel/burst, whitecaps, the fleet. LAN test of this build not run (the autopilot agent may be using the fixed port). The live play-test ended ~17:45.

## Max's second list (~18:10, 6 November 2026): eight small issues

| # | Max's ask | Branch | Agent |
|---|---|---|---|
| 7 | Start upwind of the startboat on a slalom race; course builder option: slalom race, course race, iQ hybrid race, free sailing (also easier for the AI to train) | `race/types-start-marks` | wave 3 |
| 8 | UI of the finishing leaderboard out of frame; a resolution-based UI; general UI improvements | `fix/push-and-leaderboard` (WindsurfingMMZB-gp2) | Opus, 18:12 |
| 9 | Host and joined player: after changing things in the race director or the gear menu the push slider is gone | `fix/push-and-leaderboard` | the same |
| 10 | Downwind button (A/D) while pressing Space to gybe instead of heading: now it sometimes tacks when we want to gybe | `gp/manoeuvres` | wave 3 |
| 11 | More interactive gybes and tacks | `gp/manoeuvres` | wave 3 |
| 12 | Start buoys different from rounding marks; marks bigger in general | `race/types-start-marks` | wave 3 |
| 13 | Host and joiners can spectate racers | `mp/spectate` | wave 3 |
| 14 | Draw distance increase option | `fix/push-and-leaderboard` | the same |

- 18:12 fix/push-and-leaderboard agent launched (asks 8, 9, 14).
- 18:32 board fx merged (285301a..47ae38b). Open for Max: the crest bursts at 30 kt maybe too many (CREST_AMOUNT 35), the bow wave's V, the fall's splash. Disk: 7.7 GB free (99 %): no new worktrees; ask Max before any cleanup. Manoeuvres agent started in WindsurfingMMZB-shading on gp/manoeuvres.
- 18:45 autopilot merged (03869c0..9247c7c; the progress log's conflict resolved by keeping all three entries). Lake race falls 14 -> 1, six other hours 13 -> 1, speed kept. For Michiel: the seven fall numbers (PHYSICS_SPEC 7.7), the felt heel in free fall, the awash board's nose. Race-types agent started in WindsurfingMMZB-fixes on race/types-start-marks.
- 19:05 second interim play folder WindsurfingMMZB-play-6nov2026-night2 (no zip: disk) from 355df1c: all six asks; checked with a 3137x1263 LG2 race screenshot at lake wind x1.32 from the folder's own exe (.screenshots/play_night2_check_3137.png): both gauges, the new spray and whitecaps, the fleet.
- 19:25 fix/push-and-leaderboard merged (8f2b578, 80c3a15, b6354ee, db3c61f; 0.6 M; 917/917 unit, check 479/0, LAN PASS). The push bug was LAN-only: the temporary AI hands behind the Esc menu and the director dropped the slider. Still to do by the lead: PROGRESS_LOG entries and ROADMAP rows for the wind, fx, fix, manoeuvres and race-types work (the agents left them to avoid conflicts). Spectate agent started in WindsurfingMMZB-gp2 on mp/spectate.
- 19:50 gp/manoeuvres merged (aaebb76, f58c1a8, ad39b7e, 5d01578; 0.45 M; 927/927 unit, check 0 failed). One conflict in player_controller.gd with the autopilot's reflex: resolved by keeping both, the cue's hold first and the reflex last so its ease wins near a fall. Open for Max: should a flip without a cue come a little late so a good cue pays (changes the hands-off manoeuvre); the sheet keys as a cue; everything at once falls 5 in 45 at 24 kt.
- 20:55 mp/spectate merged (19f2f64..d0facca; 0.35 M; 955/955 unit, check 484/0, LAN PASS x3 with a spectator; PROTOCOL 2 -> 3). The two agents had been cut off by the Opus 5-hour limit at ~20:20 (reset 20:40) and were resumed by message. Open for Max: the camera after a finish (the leader?), a 'Sail now' between races, spectating alone with the AI or in free sailing.
