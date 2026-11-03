# The fleet closer together, new dice every race, and the gear plan (Session 68, 3 November 2026)

For Max and Michiel. Written by Claude Opus 5.5 on Max's laptop, on `gp/sea-follows-wind`.

Max, after racing the personas: the top three are close and the rest is far behind; they race the same every time; the gear should suit the course and the wind, chosen by the AI with a slight preference of its own. His targets: the fastest and the slowest within about **15 % on a course race (T1)** and **10 % on a slalom (T2)**.

## 1. What changed

- **The level** (`RaceSkipper.level_spread`, `Persona.squeezed()`): every persona's skills of the day (the hands, the upwind and downwind sense, the tacks, the gybes, the start timing) are pulled toward the top: `1 - (1 - skill) x spread`. At 0.5 the rookie's 0.2 becomes 0.6 and the pro's 0.95 a 0.975: the order and the specialists stay, the gaps halve. The style (the risk, the nerve, the start spot, the aggression) is the sheet's. The game's level is `RaceSetup.LEVEL_CLOSE` = 0.5; the Race page's new row "Level" has "Close: everyone can win" (the default) and "Wide: rookie to pro" (the sheets as written, 1). The race tool takes `--spread=<0 to 1>` (1 by default, so the older measurements still compare).
- **New dice every race** (`RaceSetup.race_seed`, -1): at every start the skippers draw a new day (their form, their start timing, their small mistakes) and the AI boards new starting spots. Before, board i always had the seed i + 1 and the spots seed 0, so a race in the same wind replayed exactly. `--seed=<n>` (and `--spawn_seed=<n>`) fix them for a measurement.

## 2. Measured: the extremes alone at level 0.5

`tools/persona_matrix.sh --courses=t1_loop,t2_slalom --alone=1 --jobs=3 --run=spread050 --personas=liv,marco,bruno,tobias,noor,hana,mara,pia,jonas,ravi,greta --gear=1 --spread=0.5` (seed 1, each persona alone, its own gear; the fast and the slow ends of Session 66's table, [characters.md](characters.md) section 4b).

| Race | Fastest | Slowest | Gap | Next slowest | Gap | Session 66 (level 1) |
|---|---|---|---|---|---|---|
| T1 12 kt | Tobias 11:40.6 | Greta 12:29.5 | 7.0 % | Ravi | 6.6 % | 18.6 % |
| T1 18 kt | Marco 7:33.5 | Ravi 9:16.7 (over early, back: +78 s) | 22.8 % | Jonas | 10.8 % | 15.0 % |
| T1 24 kt | Bruno 6:25.1 | Ravi 7:44.9 (a fall) | 20.7 % | Pia | 14.3 % | 23.7 % |
| T2 12 kt | Tobias 4:35.5 | Greta 5:00.9 | 9.2 % | Ravi | 7.5 % | 14.5 % |
| T2 18 kt | Marco 3:06.5 | Jonas 3:14.4 | 4.2 % | Greta | 4.1 % | 24 % |
| T2 24 kt | Bruno 2:32.3 | Liv 2:57.8 (a fall) | 16.7 % | Noor (a fall) | 13.3 % | 54 % |

Without the incidents (a fall, an early start) the boards' own speed is within Max's targets in every race: the course race within 14.3 %, the slalom within 9.2 %. The incidents add to that, as on the water. The winners spread over Tobias, Marco and Bruno; Hana, the pro, is 3rd to 5th; the specialists still show (Bruno first in both 24 kt races, Tobias first in both 12 kt races), less than before. One seed per race: with the new dice every race differs, so these numbers are a sample, not a rule.

## 3. The gear plan (GE7, for later; Max: "yes, it also counts as a physics check")

What Max asked: the AI picks the gear that is best for the course and the wind, from **its own brand** (Max), with a slight preference of its own. Today a persona picks by the wind only (the wind ranges of its brand's items, sized by `rig_power()`); the course plays no part.

1. **Measure every combination in the physics** (Michiel's PC, a night; this laptop crashes on long all-core runs): each brand's boards with its sails and the slalom fins, at 12, 18 and 24 kt, at the angles a race sails (the beat's 45 to 55, 70, 90, 110, the run's 130 to 150), 150 s per case as `tools/push_check.sh` measures the skipper's polar. A polar per combination (`Game/config/gear_polars/`).
2. **The AI's choice**: before the start, each persona works out the time each of its brand's combinations would take on this course in this wind (each leg's length at its angle: a beat at the best upwind angle, a run at the best downwind one, a reach at its own), and picks the fastest; a slight preference (its taste for a size bigger or smaller, `rig_power()`) counts a few percent, and its judgement errs more for a rookie than for a pro.
3. **The physics check**: Max reads the table of what the physics says is best (18 kt slalom: which board, which sail) against what he would rig on the water. Where they differ, that is a finding for Michiel (Session 51 already saw a bigger sail sail slower in this physics than on the water).
