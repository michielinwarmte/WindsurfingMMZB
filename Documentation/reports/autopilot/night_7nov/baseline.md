# The night suite's baseline, 7 November 2026

The branch `autopilot/night7nov` at 4efccec (19fece0 plus Shift carve and the tap ramp at their starting numbers,
the other new hooks off), scored by `tools/night_suite.py` as the tuner's candidate c0000 (02:10, 97 s on 14 processes).
Costs: lower is better, a fall costs 100. How each scenario is scored: [README.md](README.md).

| scenario | cost | falls |
|---|---:|---:|
| plane | 338.7 | 0 |
| steer | 172.9 | 0 |
| taps | 48.3 | 0 |
| carve | -38.2 | 0 |
| fly | -98.6 | 1 |
| reflex | -150.4 | 0 |
| turns | 702.1 | 2 |
| **total** | **974.8** | 3 |

## Every case

Units: plane_s and settle in s (-1: never), made_good_ms and speed_ms in m/s, hold_rms_deg, turn, heel in degrees,
lean and rake in their -1..1 control units, rate in degrees a second, reflex_share the share of the time the reflex eases,
air_per_min how often a minute the board goes light (water carrying under 30 % of the weight); turns: seconds from Space to the new course.

| case | cost | falls | numbers |
|---|---:|---:|---|
| plane_10_90 | 54.1 | 0 | plane_s -1.0, made_good_ms 1.95 |
| plane_10_130 | 55.0 | 0 | plane_s -1.0, made_good_ms 1.682 |
| plane_12_90 | 30.8 | 0 | plane_s 47.4, made_good_ms 5.537 |
| plane_12_130 | 53.9 | 0 | plane_s -1.0, made_good_ms 2.047 |
| plane_14_90 | 35.8 | 0 | plane_s -1.0, made_good_ms 8.08 |
| plane_14_130 | 23.0 | 0 | plane_s 36.8, made_good_ms 4.607 |
| plane_lake0.6 | 44.4 | 0 | plane_s -1.0, made_good_ms 1.853 |
| plane_lake0.75 | 41.8 | 0 | plane_s -1.0, made_good_ms 2.739 |
| steer_8 | 86.2 | 0 | hold_rms_deg 5.12, speed_ms 1.28; turn30_away: turn 35.18, heel 6.89, lean 0.254, rake 0.917, max 38.91, settle 0.77; turn30_up: turn 51.45, heel 5.74, lean 0.178, rake 1.091, max 61.8, settle -1.0 |
| steer_10 | 86.7 | 0 | hold_rms_deg 6.19, speed_ms 1.568; turn30_away: turn 32.9, heel 6.6, lean 0.267, rake 0.92, max 38.75, settle 0.65; turn30_up: turn 50.26, heel 9.22, lean 0.215, rake 1.056, max 60.84, settle -1.0 |
| taps_8 | 23.0 | 0 | speed_ms 1.625; tap0.1_away: turn 2.29, heel 0.37, lean 0.02, rake 0.191; tap0.1_up: turn 1.13, heel 0.48, lean 0.012, rake 0.155; tap0.2_away: turn 4.16, heel 0.66, lean 0.066, rake 0.291; tap0.2_up: turn 4.53, heel 0.79, lean 0.078, rake 0.323; tap0.3_away: turn 3.93, heel 1.66, lean 0.121, rake 0.361; tap0.3_up: turn 1.99, heel 2.2, lean 0.124, rake 0.389 |
| taps_18 | 25.3 | 0 | speed_ms 12.185; tap0.1_away: turn 2.53, heel 1.67, lean 0.038, rake 0.094; tap0.1_up: turn 1.33, heel 1.11, lean 0.036, rake 0.131; tap0.2_away: turn 4.25, heel 1.15, lean 0.047, rake 0.181; tap0.2_up: turn 6.45, heel 2.65, lean 0.042, rake 0.269; tap0.3_away: turn 9.74, heel 3.32, lean 0.049, rake 0.371; tap0.3_up: turn 6.73, heel 10.98, lean 0.08, rake 0.292 |
| carve_12 | -10.1 | 0 | speed_ms 6.596; sharp_away: turn 19.55, heel 5.05, lean 0.404, rake 0.85, rate 20.39; sharp_up: turn 7.08, heel 3.51, lean 0.2, rake 0.336, rate 13.34; plain_away: turn 9.94, heel 4.87, lean 0.391, rake 0.296, rate 14.48; plain_up: turn 3.83, heel 4.03, lean 0.258, rake 0.245, rate 4.33 |
| carve_18 | -13.7 | 0 | speed_ms 11.356; sharp_away: turn 29.34, heel 3.74, lean 0.557, rake 0.512, rate 34.71; sharp_up: turn 6.79, heel 5.0, lean 0.171, rake 0.333, rate 11.06; plain_away: turn 15.83, heel 4.33, lean 0.242, rake 0.25, rate 19.69; plain_up: turn 3.5, heel 7.35, lean 0.114, rake 0.24, rate 6.72 |
| carve_24 | -14.3 | 0 | speed_ms 12.76; sharp_away: turn 24.25, heel 7.5, lean 0.555, rake 0.483, rate 34.62; sharp_up: turn 6.49, heel 5.12, lean 0.31, rake 0.234, rate 13.15; plain_away: turn 15.44, heel 6.08, lean 0.183, rake 0.344, rate 19.43; plain_up: turn 6.27, heel 4.98, lean 0.233, rake 0.216, rate 6.86 |
| fly_24_110 | -29.3 | 0 | speed_ms 14.628, air_per_min 52.8 |
| fly_24_135 | -24.9 | 0 | speed_ms 12.45, air_per_min 40.8 |
| fly_30_110 | 72.5 | 1 | speed_ms 13.769, air_per_min 103.2 |
| fly_30_135 | -27.4 | 0 | speed_ms 13.679, air_per_min 69.6 |
| fly_24_120_g6.5 | -30.0 | 0 | speed_ms 14.991, air_per_min 43.2 |
| fly_30_120_g6.5 | -26.1 | 0 | speed_ms 13.07, air_per_min 65.6 |
| fly_lake1.32 | -15.1 | 0 | speed_ms 7.569, air_per_min 44.57 |
| fly_lake1.65 | -18.3 | 0 | speed_ms 9.143, air_per_min 58.29 |
| reflex_18_100 | -24.9 | 0 | reflex_share 0.0, speed_ms 12.453 |
| reflex_18_135 | -17.4 | 0 | reflex_share 0.0, speed_ms 8.717 |
| reflex_24_100 | -27.9 | 0 | reflex_share 0.0, speed_ms 13.932 |
| reflex_24_135 | -28.5 | 0 | reflex_share 0.0, speed_ms 14.229 |
| reflex_24_push75_body | -29.4 | 0 | reflex_share 0.0, speed_ms 14.675 |
| reflex_lake1.0 | -9.4 | 0 | reflex_share 0.0, speed_ms 4.691 |
| reflex_lake1.32 | -13.0 | 0 | reflex_share 0.0, speed_ms 6.485 |
| turns_12_space | 36.2 | 0 | tack_stb 6.7, tack_port 6.7, tack_held 6.0, gybe_broad 4.7, gybe_beam 5.8, gybe_beam_key 6.3 |
| turns_12_key | 31.7 | 0 | tack_stb 5.5, tack_port 5.5, tack_held 6.0, gybe_broad 4.2, gybe_beam 5.1, gybe_beam_key 5.4 |
| turns_12_shift | 29.6 | 0 | tack_stb 4.9, tack_port 4.9, tack_held 6.0, gybe_broad 4.0, gybe_beam 4.8, gybe_beam_key 5.0 |
| turns_18_space | 42.6 | 0 | tack_stb 7.9, tack_port 7.9, tack_held 8.5, gybe_broad 4.8, gybe_beam 6.5, gybe_beam_key 7.0 |
| turns_18_key | 39.4 | 0 | tack_stb 7.5, tack_port 7.5, tack_held 8.5, gybe_broad 4.5, gybe_beam 5.5, gybe_beam_key 5.9 |
| turns_18_shift | 35.6 | 0 | tack_stb 5.7, tack_port 5.6, tack_held 8.5, gybe_broad 4.3, gybe_beam 5.7, gybe_beam_key 5.8 |
| turns_24_space | 45.4 | 0 | tack_stb 8.2, tack_port 8.2, tack_held 9.2, gybe_broad 5.2, gybe_beam 6.9, gybe_beam_key 7.7 |
| turns_24_key | 40.2 | 0 | tack_stb 7.0, tack_port 7.0, tack_held 9.2, gybe_broad 4.7, gybe_beam 6.0, gybe_beam_key 6.3 |
| turns_24_shift | 142.6 | 1 | tack_stb 6.3, tack_port 6.3, tack_held 9.2, gybe_broad 4.5, gybe_beam 5.9, gybe_beam_key 10.4 FELL |
| turns_18_key_late | 39.4 | 0 | tack_stb 7.6, tack_port 7.5, tack_held 8.4, gybe_broad 4.5, gybe_beam 5.5, gybe_beam_key 5.9 |
| turns_18_shift_late | 35.9 | 0 | tack_stb 6.2, tack_port 5.6, tack_held 8.4, gybe_broad 4.3, gybe_beam 5.7, gybe_beam_key 5.7 |
| turns_24_key_late | 40.6 | 0 | tack_stb 7.0, tack_port 7.0, tack_held 9.2, gybe_broad 4.7, gybe_beam 6.4, gybe_beam_key 6.3 |
| turns_24_shift_late | 142.9 | 1 | tack_stb 6.3, tack_port 6.3, tack_held 9.2, gybe_broad 4.5, gybe_beam 6.2, gybe_beam_key 10.4 FELL |
