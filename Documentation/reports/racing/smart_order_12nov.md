# The smart leaderboard: the polar and the laylines (12 November 2026)

Max, 12 November 2026, late evening, watching the AI races with the new TV camera ([tv_camera_12nov.md](tv_camera_12nov.md)):
"the leaderboard is not correctly calculated. please keep the wind polar in consideration. make a smart leaderbaord
with laylines kept in mind".

Branch `watch/tv-camera-12nov` (with the TV camera), worktree `WindsurfingMMZB-fixes`. Not yet seen on Max's screen.
Backlog E11.S12; roadmap RA32.

## What was wrong

The race ranked the boards still racing by the steps they had completed and then by their straight-line distance to
the next step. On a beat that is the wrong measure:
- a board out to one side and higher up the beat is often farther from the mark in a straight line than a board
  straight below it, though it is nearer to getting there: it was shown behind;
- inside the laylines both tacks take the same time to the mark, whatever the sideways place, but the straight line
  favoured the board in the middle;
- a board past the layline (overstood) must sail a wider, slower angle down to the mark, but the straight line could
  show it ahead of a board inside the layline at the same height.

The gaps in the standings were the gaps at the last mark both boards had rounded: on the first beat, the start's gap,
which says nothing about the beat.

## What the leaderboard does now

From the gun on, the boards still racing are ranked by **the time the polar says each still needs to the finish**
(`RaceSim.time_to_finish_s()`), its standing time penalty added (an uncleared penalty adds 20 s at the finish, so it
counts now):
- from where the board is to its next step (the mark, or the nearest point of a line: a gate, the finish), then every
  leg after it, mark to mark, laps included;
- each leg by the skippers' polar (`Game/config/skipper_polar.tres`, the same numbers the AI sails by) in the wind of
  the moment (`RaceTimeLimit.leg_time_s()`, the rule the race's time limit already used):
  - **beat** (the mark closer to the wind than the polar's best beating angle, 50 to 55 degrees): the way toward the
    wind over the speed made good toward it at that angle. Inside the laylines the sideways place costs nothing;
  - **run** (the mark deeper than the best running angle, 129 to 140 degrees): the same away from the wind;
  - **reach** (between them, which includes a board past a layline): the distance over the polar's speed at that angle;
  - the laylines are exactly where a beat or a run turns into a reach, so the time runs on smoothly across them;
- the wind: where it blows from and its strength at 10 m, the wind field's own of the moment (on the lake the lake's
  mean, not the gust one board is in), handed to the race every tick (`RaceRunner._tell_the_race_the_wind()`). A shift
  moves the laylines and the order with them: who gains from a shift shows at once.

A board that has rounded a mark comes out ahead of one that has not, unless it then sails the wrong way. Finished boards
stay first, by their finish time; retired boards last. Before the gun the order is as before (the distance to the line).

**The gaps** in the standings are now the differences of the expected finishes (`RaceSim.expected_finish_s()`: the race
time now plus the time still to sail, or the finish time once a board is in), to the board followed: "-12.3 s" ahead of
it, "+12.3 s" behind. They change live along a leg instead of only at the marks. Before the gun, and on a LAN guest's
copy of the race (which takes the host's order), the gaps are the old ones at the last mark.

What it leaves out: the time of the tacks, gybes and roundings (the polar is steady sailing; the boards on the same leg
mostly need the same number), the wind's gusts and lee where each board is (one wind for all, so the order does not
jump with every gust), the rules (a board that must give way). The AI does not use the order, so the AI sails exactly as
before; the race tool and the trainer do not hand their races the wind, so their places and results are as before.

## Where it is

- `Game/race/race_sim.gd`: `set_wind()`, `ranks_by_time()`, `time_to_finish_s()`, `expected_finish_s()`,
  `legs_after_s()`, `aim_point()`; `_order()` works the times out once per tick (with the order), `_is_ahead()` compares
  them. A LAN guest's host order wins as before.
- `Game/race/race_runner.gd`: `_tell_the_race_the_wind()` after the boards' places, every tick (from an AI board that
  sails: the parked player's board is not stepped while watching).
- `Game/race/race_hud.gd`: `gap_between()` for the standings and the fleet text.
- Everything that uses the order follows by itself: the race card's place, the standings, the race director's view, the
  TV camera's choice of the front, the results of a race that ends at its time limit.

## Verified, and what is not

- `test_race_smart_order.gd` (new, 9): inside the laylines the sideways place costs nothing (beat and run); a board out
  to the side but higher leads though farther from the mark; past the layline behind one inside at the same height; a
  board that rounded ahead of one that has not; a standing penalty counts; the countdown and a race without the wind keep
  the plain order; the expected finish and the gaps; the legs after each step add up to the course. All 121 tests with
  "race" in their name pass; the full unit run 1103/1103; `tools/check.sh` 516/0.
- In the game (the lake's O2, 11 AI boards, 40 to 100 s after the gun): the standings' gaps grow down the list and move
  along the beat.
- Not checked: whether the order matches what Max sees on the water; long races with wind shifts; a LAN race.
