# The lake suite's baseline (7 November 2026)

The branch `autopilot/lake-speed` as the tuner starts: the player's board as the autopilot drives it
(the push at 75 %, the night-tuned steering of this morning, every new lake technique number off),
on Lake Silvaplana in the map's Maloja wind on the lake's full waves (`tools/lake_suite.sh
--label=baseline --refs=1 --cases=1`; the logs and the CSVs of every track are in
`.sim_output/lake_speed/suite/baseline/`). The "speed in the gusts" is the mean of the 90th
percentile of the board's speed over the measured part (from 20 s to 75 s) and its mean speed while
the wind at the board is in its top quarter. "Wind at the board" is the map's wind 10 m above the
board's spot, with its gusts, along the track. LV95 is the Swiss coordinate (east, north) of the start.

**In short:** no case reaches Max's targets with waves. Across (beam reach) the speed in the gusts is
34 to 46 km/h against 50; downwind (broad reach) 30 to 35 km/h at x1.3 against 55, and at x1.0 the
board never planes on a broad reach from rest (8 km/h after 75 s; on 100 to 120 degrees it planes
after 6 to 34 s). On flat water at x1.3 the beam reach makes 52 to 56 km/h in the gusts: the target
is in the physics there, and the waves cost 10 to 15 km/h of it. The broad reach is slow on flat
water too (34 to 45 km/h at x1.3), so downwind the waves are not the only gap. Getting going, the
bow dives in the first 3 s from rest in every case (the nose 5 to 9 degrees down, the bow 0.16 to
0.3 m under at x1.0; at x1.3 on 130 degrees 13 to 20 degrees and 0.43 to 0.52 m). No falls.

Note on the wind: at x1.0 the wind at the board is 15 to 19 kt in most places, 22 kt at the south
spot at 15:00 (the map's own pattern), and its gusts along a track are small (the 90th percentile 1
to 2 kt above the mean); the lake's own mean at 10 m is 17.8 to 18.2 kt. At x1.3 it is 19 to 26 kt.
Max's "about 18 kt mean, gusts to about 24" lies between the two.

| gear | case | start (LV95 E, N) | wind at the board, kt (mean / p90) | speed in the gusts km/h | target | short by | mean km/h | max km/h | pitch rate SD | air /min |
|---|---|---|---|---:|---:|---:|---:|---:|---:|---:|
| small | beam_middle_1430_x1.0 | 2780411, 1147084 | 16.0 / 17.9 | 33.6 | 50 | 16.4 | 30.4 | 35.7 | 9.4 | 19 |
| small | beam_south_1500_x1.0p | 2780755, 1146369 | 22.5 / 24.1 | 40.8 | 50 | 9.2 | 39.7 | 49.0 | 15.9 | 79 |
| small | beam_between_1330_x1.3 | 2780582, 1147339 | 24.0 / 26.6 | 44.4 | 50 | 5.6 | 37.4 | 50.3 | 12.8 | 55 |
| small | broad_between_1530_x1.0 | 2780475, 1147085 | 14.7 / 15.0 | 7.8 | 55 | 47.2 | 7.4 | 8.6 | 1.4 | 0 |
| small | broad_middle_1430_x1.3 | 2780360, 1146664 | 23.4 / 24.5 | 29.7 | 55 | 25.3 | 27.6 | 30.6 | 11.3 | 8 |
| medium | beam_middle_1430_x1.0 | 2780411, 1147084 | 15.7 / 17.9 | 35.7 | 50 | 14.3 | 32.4 | 38.8 | 12.1 | 35 |
| medium | beam_south_1500_x1.0p | 2780755, 1146369 | 22.2 / 23.9 | 45.4 | 50 | 4.6 | 40.0 | 47.4 | 15.1 | 93 |
| medium | beam_between_1330_x1.3 | 2780582, 1147339 | 23.7 / 26.6 | 41.2 | 50 | 8.8 | 36.1 | 46.5 | 14.8 | 56 |
| medium | broad_between_1530_x1.0 | 2780475, 1147085 | 14.6 / 14.9 | 8.4 | 55 | 46.6 | 7.7 | 9.7 | 2.5 | 0 |
| medium | broad_middle_1430_x1.3 | 2780360, 1146664 | 22.8 / 24.6 | 31.7 | 55 | 23.3 | 28.1 | 32.9 | 11.6 | 16 |
| big | beam_middle_1430_x1.0 | 2780411, 1147084 | 15.7 / 17.9 | 36.5 | 50 | 13.5 | 33.5 | 38.2 | 12.3 | 48 |
| big | beam_south_1500_x1.0p | 2780755, 1146369 | 22.1 / 23.7 | 46.0 | 50 | 4.0 | 43.4 | 47.7 | 12.8 | 90 |
| big | beam_between_1330_x1.3 | 2780582, 1147339 | 23.7 / 26.5 | 41.2 | 50 | 8.8 | 38.2 | 44.5 | 15.6 | 56 |
| big | broad_between_1530_x1.0 | 2780475, 1147085 | 14.6 / 14.9 | 8.4 | 55 | 46.6 | 7.8 | 9.1 | 1.4 | 0 |
| big | broad_middle_1430_x1.3 | 2780360, 1146664 | 22.0 / 24.7 | 35.2 | 55 | 19.8 | 29.7 | 37.0 | 12.1 | 55 |

Getting going (from rest, x1.0) and the nose dive (from rest, x1.3):

| gear | case | wind kt (mean) | time to plane s | heel SD deg | pitch SD deg | lean rate /s | nose dives | buried s | deepest pitch deg | bow under m | falls |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| small | start_camping_1330_100 | 15.5 | 34.2 | 1.76 | 3.56 | 0.161 | 1 | 1.42 | -5.4 | 0.188 | 0 |
| small | start_between_1430_120 | 18.7 | 11.92 | 1.9 | 3.76 | 0.11 | 1 | 3.37 | -9.18 | 0.276 | 0 |
| small | start_middle_1530_90p | 16.6 | 10.98 | 1.82 | 3.84 | 0.167 | 1 | 4.43 | -8.17 | 0.255 | 0 |
| small | strong_middle_1430_100 | 19.3 | 6.42 | 2.84 | 3.77 | 0.316 | 1 | 1.93 | -8.65 | 0.286 | 0 |
| small | strong_between_1330_130 | 25.7 | 7.97 | 3.21 | 5.32 | 0.187 | 1 | 2.57 | -13.11 | 0.43 | 0 |
| medium | start_camping_1330_100 | 15.9 | 14.53 | 2.45 | 2.92 | 0.187 | 2 | 1.1 | -5.28 | 0.176 | 0 |
| medium | start_between_1430_120 | 18.5 | 9.78 | 2.13 | 3.46 | 0.217 | 1 | 2.5 | -7.84 | 0.234 | 0 |
| medium | start_middle_1530_90p | 16.7 | 8.43 | 2.19 | 2.86 | 0.104 | 1 | 3.03 | -6.54 | 0.193 | 0 |
| medium | strong_middle_1430_100 | 19.0 | 5.47 | 3.44 | 3.76 | 0.195 | 1 | 1.85 | -9.18 | 0.298 | 0 |
| medium | strong_between_1330_130 | 25.7 | 7.1 | 3.58 | 5.91 | 0.175 | 1 | 2.85 | -16.02 | 0.497 | 0 |
| big | start_camping_1330_100 | 16.2 | 10.13 | 3.19 | 2.69 | 0.14 | 1 | 0.83 | -5.71 | 0.159 | 0 |
| big | start_between_1430_120 | 18.2 | 6.3 | 2.38 | 2.74 | 0.146 | 1 | 1.72 | -6.71 | 0.173 | 0 |
| big | start_middle_1530_90p | 16.6 | 6.87 | 2.14 | 2.45 | 0.132 | 1 | 1.7 | -6.36 | 0.179 | 0 |
| big | strong_middle_1430_100 | 18.7 | 4.6 | 3.81 | 3.46 | 0.159 | 1 | 1.55 | -8.95 | 0.265 | 0 |
| big | strong_between_1330_130 | 25.6 | 5.73 | 3.35 | 5.84 | 0.237 | 1 | 2.67 | -19.55 | 0.523 | 0 |

The references (not scored; the same course and place, flat water, or flat water in sea-level air):

| gear | case | wind kt (mean / p90) | speed in the gusts km/h | mean km/h | the lake's own case with waves: in the gusts / mean |
|---|---|---|---:|---:|---|
| small | ref_beam_flat_x1.0 | 15.7 / 17.9 | 37.6 | 33.0 | 33.6 / 30.4 |
| small | ref_beam_flat_sea_x1.0 | 15.8 / 17.8 | 41.5 | 38.2 | 33.6 / 30.4 |
| small | ref_broad_flat_x1.3 | 22.3 / 24.6 | 34.1 | 30.1 | 29.7 / 27.6 |
| small | ref_beam_flat_x1.3 | 21.8 / 26.8 | 56.4 | 51.1 | 44.4 / 37.4 |
| medium | ref_beam_flat_x1.0 | 15.8 / 17.8 | 40.9 | 36.4 | 35.7 / 32.4 |
| medium | ref_beam_flat_sea_x1.0 | 15.9 / 17.8 | 45.1 | 41.3 | 35.7 / 32.4 |
| medium | ref_broad_flat_x1.3 | 21.7 / 24.7 | 37.9 | 31.5 | 31.7 / 28.1 |
| medium | ref_beam_flat_x1.3 | 21.8 / 26.8 | 55.2 | 51.0 | 41.2 / 36.1 |
| big | ref_beam_flat_x1.0 | 15.9 / 17.8 | 43.1 | 40.2 | 36.5 / 33.5 |
| big | ref_beam_flat_sea_x1.0 | 15.9 / 17.8 | 44.2 | 41.5 | 36.5 / 33.5 |
| big | ref_broad_flat_x1.3 | 21.5 / 24.4 | 44.9 | 35.8 | 35.2 / 29.7 |
| big | ref_beam_flat_x1.3 | 22.1 / 26.8 | 52.0 | 49.5 | 41.2 / 38.2 |

Scores (lower is better; a fall costs 100):

| scenario | cost | falls |
|---|---:|---:|
| start | 286.9 | 0 |
| strong | 278.7 | 0 |
| reach | 479.3 | 0 |
| guards | 161.1 | 0 |
| **total** | **1206.0** | 0 |

The gear: small: 111 L free race + 7.0 m free race (fin 36 cm); medium: 117 L slalom + 7.5 m slalom (fin 38 cm); big: 129 L slalom + 8.0 m slalom (fin 41 cm).
