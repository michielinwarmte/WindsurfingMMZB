# The AI at Sotavento: what was measured on the night of 27 to 28 November 2026

For the training night Max said "yes but later" to (question Q63). Everything here is from heats of the live slalom week (`--event=sotavento_2026`): eight AI sailors, the rebuilt course (2.7 km, five reaches), 30 knots steady from 025, the spot's sea at 0.7 of its height (crests to about 1.0 m), a 60 s countdown. The numbers come out of the game's log with `tools/broadcast/heat_stats.py`; the logs are in the test folder's `.logs/` (not in the repository). The stream's numbers are the leader's, the middle of nine heats of the World Cup Fuerteventura 2026.

## In one look

| | The game's AI | The stream's leader |
|---|---|---|
| The winner home after the gun | 188 to 210 s, the middle about 200 s | about 187 s |
| Over the start line after the gun | the middle 6 to 8 s, nine in ten within 14 to 16 s | at the gun, at full speed |
| Speed on a reach | 16 to 19 m/s | about 16 m/s in, 13.5 out (Max's own numbers) |
| The five legs | 35, 36 to 37, 44 to 47, 40 to 41, 45 to 47 s (the middle board) | 32, 33, 38, 38, 40 s |
| Boards home when the fourth is | 4 to 7 of 8, the middle 5 | all eight, as a rule |
| Boards that do not get round mark 1 | about one in eight | none |

The AI is fast enough on the reaches. It loses its time in three places, in this order.

## 1. Mark 1, with the fleet arriving together

About one board in eight does not get round the first mark (8 of 64 and 11 of 64 boards in two runs of eight heats, 5 of 32 in two runs of four). It happens in pairs: two boards of the same heat, at the same second.

One case followed second by second (a one-second trace, `--event_trace=1`; it was at mark 2, the same thing): the board came in at 16 m/s, 23 m on the right side of the mark, turned in for its gybe while its skipper's note said "passing clear, keeping clear", passed 2 m from the buoy on the inside, and tipped over there. Back on the board it was on the wrong side of the mark. It then sailed 100 m back and came at the mark again, twice, each time 40 to 55 m to leeward of where it had to be: on a slalom board in 30 knots and chop it makes no ground to windward (8 to 9 m/s on a "beat", sagging). It never rounded the mark.

Tried against it, none of which cured it:

| Trial | Heats | Result |
|---|---|---|
| Every sailor at least 14 m off a mark (their own margins: 5 to 11 m) | 4 and 8 | no more missed marks beyond mark 1 (0 of 51 legs to mark 3 lost half a minute; before 12 of 94), the winners a little faster; mark 1 unchanged. **Kept** (`EventBroadcast.MARK_MARGIN_M`). |
| At least 20 m | 4 | as 14 m; mark 1 no better |
| 25 knots instead of 30 | 2 | worse: the winner in 213 and 216 s, three of eight stuck at mark 1 in both heats |
| The right-of-way rules off (`--rules=0`) | 8 | no difference (13 boards gave up against 12) |
| The early turn and the gybe at the mark off (`round_early`, `gybe_at_mark`; `--event_round_early=0`) | 4 (with the 14 m margin) | no better at the marks (4 boards gave up in 4 heats, as with it on) and slower (the winner in 205 to 228 s). With the sailors' own margins on top: 7 gave up in 2 heats. **Left on.** |

What the event does about it for now (the lead's rule, Q66): a sailor whose next mark the heat's fourth board rounded more than 45 s ago gives up; the cameras leave him and the commentator says he is out.

## A board's physics breaking

Seven times in about 110 heats one board's turning speed went to infinity in a single step (the engine's message: "The axis Vector3 (0, 0, 0) must be normalized", from `SimRigidBody.integrate()`). Three times nothing more came of it (before the guard); twice the board's place became "not a number", the pictures wrote thousands of errors a second and the heat never ended. Both of those were in the trial with the early turn off; the three harmless ones were in ordinary heats, two of them a moment after a sailor had given up. A pattern, for whoever looks into it: four of the seven came 85 to 95 s into the heat, within a second or so of the moment a sailor gave up at mark 1 (so most likely a board in the mess there: one that has missed the mark, has fallen or is just up again, among others); the others at 159 s, after 122 s, and at a moment the log does not give. **Why the physics does it is not known: a question for Michiel.** Since 02:28 the race looks at every AI board after its step and puts a broken one back at its start spot, retired (`RaceRunner._mend_the_broken_boards()`, one warning in the log); and an event heat is closed eight minutes after its gun at the latest. Checked on the two heats that had hung: one warning, the heat finished; and it caught one more in the final build's ten-heat run (a board at mark 1, 89.7 s into its heat).

## 2. The gybe

Every mark costs the AI about 5 s against the stream's leader: the legs after a gybe are 3 to 9 s longer than his although the reaches are as fast or faster. A board comes out of its gybe at 6 to 9 m/s (measured earlier in the evening: 13 to 18 % of the speed kept through the turn itself). Four marks: 20 s, which is most of the difference between the AI's 200 s and his 187 s.

## 3. The start

With the game's 60 s countdown the timed run works: the line is crossed 6 to 8 s after the gun in the middle, at 8 to 17 m/s. With 30 s it does not (up to 69 s late, falls). The stream's sailors are on the line at the gun at full speed.

Before any of this could be measured, one thing had to be set right: the course file said the wind comes from 205 degrees (it comes from 025), which put all eight boards on one spot and turned the right-of-way rules round.

## Who goes through

The better-ranked half of the provisional roster goes through no more often than the worse half (the four who went through had seeds with the middle 38 to 47; by chance it would be 32). In this AI a sailor's skills set how steady his hands are, how late he starts and how close he rounds; his speed comes mostly from his daring. So a daring tail-ender wins heats. Whoever makes the real roster (Max) decides how much the ranking should count.

## For the training night

In the order the time is lost: the rounding in a crowd at mark 1 (keeping clear without turning inside the mark; going wide instead), the gybe's exit speed, then the last seconds of the start. The method's drill phases (R and L) can be pointed at this course; the heats' own numbers above are the baseline. The roundings were trained on Lake Silvaplana at 12 to 14 m/s; here the boards arrive at 17 to 19.
