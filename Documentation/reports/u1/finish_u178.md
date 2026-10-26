# U1 agent 5, `finish`: U1.7 and U1.8 report

**Branch:** the old worktree `agent-a52f683c1457214ae` holds `u1/finish`, so this report is on `worktree-agent-aa9ce25511acb13a6` (the feature branch plus this report). No game file changed.

**U1.7.** Check 0 failed. Validation: 26 pass, 2 pending, and only the onset fails. The reach check equals Latest. No fall, no NaN.
- **The straight runs are 2 to 6 % slower** (table). The old stance (`--sailor.lean_max_m=1.0 --sailor.lean_height_drop_m=0.5`) brings them back to within 3 %. The 45° stance rights less, so the auto-sheet carries less sail.
- **Friction did not halve** (224 → 216 N), so the reaches gained only 2 to 12 %.
- **Polar, 15 kt: inside every range.** 12.7, 16.2, 19.1, 21.5, 23.2, 24.1, 19.1, 12.2 and 9.3 kt at 45 to 165°. At 40° it is 11.2 kt, as on `main` (that angle is checked only for VMG > 0). No drag added. Spray drag is missing from the model and is the first candidate later.
- **Onset: 11.6 kn** (`main` 9.8). The band is not moved.

**U1.8.** The spray root uses the same sum as `wet_front_m`, so it follows the wet front. Not changed. The front moved only 16 cm aft at 18 and 24 kt, and 25 cm forward at 12 kt. It stays 0.35 to 0.5 m ahead of the mast foot.

**Screenshots:** `.screenshots/u1/before_beam_{12,18,24}kt.png` (`main`) and `after_beam_…`, made with `res://dev/figure_view.tscn -- --wind=<kt> --twa=100 --times=30 --views=windward,leeward,stern,close` (the game's camera is too far away).
- **Before:** the sailor stands upright and the rig is nearly vertical.
- **After:** the sailor sits back and low, and the rig leans clearly to windward. The harness at 18 kt goes from 1036 to 830 N.
- **In both:** the spray shows around the mast foot. The trim (under 1°) and the spray hardly change.

| Run | Baseline | Now | Old stance |
|---|---|---|---|
| Flat, 12/18/24 kt (m/s) | 8.77, 11.10, 12.01 | 8.60, 10.49, 11.53 | 8.54, 10.90, 12.13 |
| Sea (m/s) | 8.72, 10.90, 12.07 | 8.47, 10.42, 11.44 | 8.53, 10.83, 11.98 |
| Lake mean (kt) | 22.1, 19.2, 23.3 | 20.8, 18.4, 21.9 | 21.7, 19.1, 22.7 |
| Reach 100° (m/s) | 10.25, 12.30, 13.83 | 10.30, 12.74, 14.31 | |

## Max's play-test

`tools/play.sh res://main.tscn`, then `tools/play.sh lake`:
1. Is the board wet only from the front foot back? (Expected: not yet.)
2. Does it feel freer and faster?
3. Does it bounce, on flat water or in chop?
4. Does it behave in gusts on the lake?
5. Is the weight on the back foot? Does the nose lift when asked?
