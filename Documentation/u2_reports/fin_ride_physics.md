# U2 agent 3, `fin_physics` (relaunched): the sailor rides the fin

**Branch:** `u2/fin_physics` is checked out in another worktree, so this work is on `worktree-agent-af2853a2b8617cc97` (from 75c12c7).

**A stop rule fired (a source against a target), so the physics is unchanged.** The reach check equals U2's Latest. Unit tests 354/354 (2 new). Validation as before: only the onset fails.

**(b) doesn't hold.** Savitsky's limit is 0.51 to 0.72° on the fast reaches (OpenPlaning's fit, the hull's load, the 1° vee; spec 5 F22). The hull rides steadily at 1.2 to 1.5° there. The 24 kt broad reach starts to bounce at 1.32 to 1.41°, 2.6 times its limit. The target `min(3.5°, limit − 0.3°)` fell to 0.3 to 0.4°: every planing reach got longer and slower. The 18 kt broad reach bounced: the limit swings with the hull's load. The vee plus the heel as deadrise was no better. Committed, then reverted (83b8235, 6b31450). The limit stays, reported only.

**(a) not kept.** At 1.5° the press never runs out, so the wet front moved 0 to 2 cm. But the 24 kt 130° reach went from 0.01 to 0.20° of pitch SD, and `test_no_flying_off_at_speed` failed (0.055 m/s).

**(c) needs no change.** Front strap 0.80 to 0.90 m from the tail, spread 0.38 to 0.44 m (Jem Hall), so the back strap is 0.36 to 0.52 m. Today's full press reaches 0.37 to 0.45 m.

**(d) left out:** 3 to 13 N, 0.4 to 1.7 % of the sailor's weight (flat plate, Helmbold's slope).

**U1 targets 3 and 4 stay pending:** front 1.42 to 1.71 m, push 1.12 to 1.22 m, trim 1.32 to 1.49°.

**Options:** keep 1.5°; a target from this model's own measured onset; or a sailor who backs off at the first bounce (needs a source).

| Planing reach | Latest (= now): front m / speed m/s / pitch SD ° | (a) | (a)+(b) as designed | (a)+(b), vee+heel | Limit / pitch now ° |
|---|---|---|---|---|---|
| 18 kt 100° | 1.76 / 12.68 / 0.00 | 1.76 / 12.68 / 0.00 | 1.84 / 12.58 / 0.00 | 1.78 / 12.65 / 0.00 | 0.72 / 1.43 |
| 18 kt 135° | 1.42 / 12.50 / 0.10 | 1.42 / 12.50 / 0.10 | 1.66 / 11.72 / **0.37** | 1.58 / 11.91 / **0.47** | 1.11 / 1.49 |
| 24 kt 100° | 1.71 / 14.20 / 0.01 | 1.71 / 14.20 / 0.01 | 1.81 / 14.00 / 0.00 | 1.74 / 14.14 / 0.00 | 0.57 / 1.46 |
| 24 kt 135° | 1.71 / 15.86 / 0.25 | 1.69 / 15.90 / 0.25 | 1.79 / 15.22 / 0.11 | 1.75 / 15.42 / 0.15 | 0.51 / 1.21 |
