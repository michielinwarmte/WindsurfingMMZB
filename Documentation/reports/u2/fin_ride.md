# U2 agent 5, `fin_ride`: report

**Done:** 78 runs with overrides, no game file changed; CSVs and script in `.sim_output/fin_ride/` (not in git); means over t ≥ 25 s.

**The weight aft works.** Trim target 3.5° with `trim_press_max_m=0.45` puts the feet's pressure 0.35 m from the tail, over the back strap and fin: on the 18 kt beam reach the wet front goes 1.76 → 1.45 m, 2 % faster, steady. At 0.3 the press runs out; `hang_back_max_m=1.0` changes nothing.

**The fin's lift does not carry the kit.** At that setting it lifts 109 N (12 % of 900 N), the 44 cm fin 146 N. A 16° rail lifts 247 N (27 %), but the leeward rail sinks (buoyancy 85 → 235 N): wet front 2.06 m, 4 % slower. The bend and the bigger fin lengthen the wet part at every setting; the stiff fin is shortest. Why: the push at the tail pitches the bow down, and the press scales with `planing_ratio`, which the fin's lift lowers (0.66 stiff, 0.56 bent), so the sailor steps forward.

**Looseness:** the fin already carries all the side force (hull ≤ 13 N, `rail_grip_n` 0). The water's yaw moment falls with the weight aft, rises with the rail.

**Limits:** never railed out (heel = bank; fin roll up to 136 N·m against the feet's 120). Weight aft plus 12° of rail bounces. The 24 kt broad reach is at its limit (1.3°) today: every weight-aft setting bounces; trim 3° catapults (fin at 97 % of stall), the 44 cm fin spins out.

**For the team:** weight over the back strap is a sailor's choice for the pilot, with a trim target falling with speed (Savitsky). New behaviour needed: a press not cut by the fin's lift, the front-foot pull (a sourced pitch couple), and a sourced heeled hull before the rail helps.

| 18 kt, 100° | Front m | Trim ° | Pitch SD ° | Speed m/s | Fin up N | Fin roll N·m | Stall % | Mast N | Yaw water N·m |
|---|---|---|---|---|---|---|---|---|---|
| today (38 cm bending) | 1.76 | 1.49 | 0.00 | 12.68 | 113 | 111 | 21 | 340 | 18 |
| stiff fin | 1.71 | 1.64 | 0.00 | 12.74 | 41 | 111 | 20 | 352 | 17 |
| 44 cm | 1.79 | 1.44 | 0.00 | 12.58 | 151 | 124 | 19 | 333 | 17 |
| trim 3.5, press 0.3 | 1.62 | 1.78 | 0.01 | 12.79 | 111 | 110 | 20 | 297 | 18 |
| **aft: trim 3.5, press 0.45** | **1.45** | 2.04 | 0.10 | **12.94** | 109 | 109 | 20 | 269 | 15 |
| bank 8 / 12 / 16 | 1.87 / 1.99 / 2.06 | 1.86 / 2.07 / 1.82 | 0.00 / 0.04 / 0.06 | 12.53 / 12.35 / 12.19 | 160 / 208 / 247 | 119 / 123 / 124 | 23 / 24 / 25 | 349 / 343 / 331 | 29 / 39 / 46 |
| aft + bank 8 / 12 | 1.66 / 1.84 | 2.29 / 2.19 | 0.28 / **0.77** | 12.75 / 12.56 | 156 / 204 | 117 / 121 | 22 / 23 | 281 / 301 | 27 / 40 |
| aft + 44 cm | 1.57 | 1.80 | 0.18 | 12.79 | 146 | 121 | 18 | 274 | 16 |
| aft + 44 cm + bank 12 | 1.94 | 1.83 | **0.67** | 12.41 | 251 | 136 | 21 | 301 | 40 |
| aft + stiff fin | 1.32 | 2.43 | 0.06 | 13.08 | 39 | 107 | 19 | 263 | 11 |

| Spot checks: front m / pitch SD ° / speed m/s | 12 kt 100° | 24 kt 100° | 24 kt 135° |
|---|---|---|---|
| today | 1.88 / 0.01 / 10.23 | 1.71 / 0.01 / 14.20 | 1.70 / 0.25 / 15.86 |
| aft | 1.80 / 0.08 / 10.30 | 1.34 / 0.17 / 14.60 | 1.06 / **0.82** / 14.95 |
| aft + 44 cm | 1.84 / 0.02 / 10.25 | 1.45 / 0.15 / 14.43 | **fell** (spin-out) |
| aft + bank 8 | 1.98 / 0.10 / 10.21 | 1.56 / 0.18 / 14.28 | 1.45 / **1.36** / 16.64 |
| trim 3, press 0.45 | 1.80 / 0.08 / 10.30 | 1.39 / 0.13 / 14.55 | **fell** (catapult) |
| trim 2, press 0.45 | 1.85 / 0.00 / 10.26 | 1.64 / 0.01 / 14.29 | 1.57 / **0.62** / 16.24 |
