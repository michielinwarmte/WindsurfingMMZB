# living_skipper (Part F2): the fleet lives on the water

**Built.** `Skipper` runs a state machine from the race (free sailing in its `SailingArea`, pre-start, racing, finished). `Navigation.route()`. `SailingArea`: a box round the start line, set to the wind, 150 m beyond each end, 100 m below, 50 m above; on the lake kept 80 m off the shore (T2: 270 × 190 m). Farthest T1 corner: 43 s to the line at 12 kt. Line bias with `favoured_end_bias`; `start_style` LOOP or HOLD. Hold-back in the hands (`AiHands.hold_speed_ms`: the controller caps the auto-sheet, never below 1.5 m/s). OCS: back round the nearer end. Random spawn (`--spawn`, `--spawn_seed`, `--free_sail`), `Skippers.make_fleet()` ("Rookie 2"), `race.sh` start report. The head thinks at 2 Hz, spread over the ticks.

**Verified.** 471 unit tests; validation, 16 boards at 15 kt: longest start T1 5.6 s, T2 4.5 s, no OCS, nobody outside; `test_skipper` passes.

**Head cost** (release, AI board's sailor per tick, median/worst ms, loaded laptop): before 0.30/0.51 (8 boards), 0.26/0.41 (32); after 0.13/0.15, 0.17/0.21. The skipper alone (editor engine): 0.184 → 0.021 ms. The rest is the hands every tick: 32 boards ≈ 5 ms, so **3 ms is not met**. For Michiel: `Game/sim/autopilot.gd:196`, `best_alpha_deg()`'s 21-angle search each tick, is a fifth of it.

**Changed in the sheets:** gambler aims +0.5 s (an exact timer made −1.5 s a sure OCS); all-rounder and rookie hold back to 3.5 m/s; run in 60° off the wind.

**Stop:** `tools/release.sh build`, then `tools/release.sh --mute --race=t1_loop --skippers=<16> --prestart=60` (and `t2_slalom`; the pack now carries the lake's .bin/.json). Pictures: `.screenshots/p9/gather_t1*.png`, `gather_t2_gun.png`.

**Not verified:** look and feel; free sailing only headless; the HUD cuts "All-rounder 1" to "All-rounder".

| Board | T1 12 | T1 18 | T1 24 | T2 12 | T2 18 | T2 24 |
|---|---|---|---|---|---|---|
| All-rounder 1 | +2.6 | +3.2 | +8.5 | +1.3 | +0.7 | +0.9 |
| Cautious 1 | +3.0 | +3.5 | +6.7 | +4.4 | +2.5 | +2.0 |
| Gambler 1 | +2.0 | +0.2 | +11.4 | +0.5 | +1.0 | OCS, none |
| Rookie 1 | +17.1 OCS | +4.3 | +6.8 | +2.8 | +4.1 | +4.4 |
| All-rounder 2 | +17.4 | +4.7 | +13.3 | +4.3 | +4.4 | +1.6 |
| Cautious 2 | +4.3 | +3.9 | +3.8 | +6.5 | +5.1 | +5.3 |
| Gambler 2 | +1.8 | +0.9 | +1.8 | +6.3 | +5.4 | +7.1 |
| Rookie 2 | +4.6 | +3.7 | +6.1 | +3.1 | +3.7 | +6.1 |
| All-rounder 3 | +1.7 | +3.5 | +7.8 | +4.0 | +4.5 | +3.1 |
| Cautious 3 | OCS, none | +3.6 | +7.9 | +4.5 | +3.2 | +4.3 |
| Gambler 3 | +4.8 | +1.2 | +3.9 | +0.7 | +0.7 | +0.6 |
| Rookie 3 | +4.2 | +5.7 | +9.8 | +3.5 | +4.3 | +3.4 |
| All-rounder 4 | +1.6 | +0.9 | +5.0 | +0.8 | +3.8 | +2.9 |
| Cautious 4 | +10.0 | +3.9 | +1.5 | +4.7 | +3.2 | +3.9 |
| Gambler 4 | +0.5 | +1.4 | +3.9 | +0.5 | +0.6 | +1.2 |
| Rookie 4 | +3.7 | +2.4 | +5.8 | +3.3 | +3.7 | +3.6 |

Start after the gun (s), 16 boards, random spots (seed 1), stopped at +25 s; "OCS, none": not restarted by then.
