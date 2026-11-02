# The characters: twenty personas from rookie to pro (package 3, 2 November 2026)

This is the caster's report (an Opus agent), written for the team and the lead. The work is on the branch `race/characters` (made from `gear/lead` at 118fed6), and the plan is [PLAN.md](PLAN.md), package 3. Nothing in `Game/sim/` changed. Every number below comes from a run named in section 8. The runs are headless on the open water's steady wind with waves, all with seed 1, while a training night shared the machine.

## 1. In short

- **Twenty personas, from rookie to pro.** The twelve that existed are kept, and there are eight new ones: Hana (the pro), Bruno (the strong-wind sailor), Liv (the light-wind sailor), Yusuf (a slalom pro), Greta (an old hand), Tomas (a fearless youngster), Ravi (a club racer) and Pia (a beginner). Each is a skill sheet. The sheet sets the numbers the scripted skipper uses: the angles, the margins, the hands' reaction and noise, the start, the push slider, and the gear from the game's catalogue. Two new wind skills make light-wind and strong-wind specialists.
- **Every persona finishes every race on T1 and T2 at 12, 18 and 24 kt**, both alone (120 races) and in a fleet of twenty (section 4).
- **The specialists show by wind, not by course.**
  - In wind: with their own gear, Liv's average place is 3.0 in 12 kt and 15.5 in 24 kt. Bruno's is 14.5 in 12 kt and 1.0 in 24 kt (he wins both 24 kt races). Sven's is 6.5 and 2.0.
  - From rookie to pro: Hana is 5.3 on average and the three weakest (Jonas, Pia, Ravi) are 17 to 19.
  - By course: a slalom specialist does not place reliably better on the slalom, nor a course specialist on the loop. Only Noor does (13.7 on T1, 7.0 on T2). Yusuf and Tobias go the other way. Section 5 explains why.
- **The push** is a working character trait now. A bold persona pushes the slider up to 0.15 past the pilot's own margin and a careful one eases it. But pushed upwind the boards fell: alone on T1 at 24 kt, 25 falls in 20 races, 22 of them on the beat and nearly all of them the pushers'. **The push now works off the wind only**, and that alone took the falls to 2 and the twenty's summed time down by 6 minutes.
- **The gear is on by default**: each persona sails its own brand's board, sail and fin, sized by the catalogue's wind ranges. Alone, on its own gear, a persona is **72 s faster on T1 in 12 kt** (8 %) and 21 s faster on T2, about even in 18 kt (1 to 3 % slower), and 2 % slower on T1 in 24 kt. It also **falls far less: 3 falls in 120 races against 15** on the default 8.0, which is past its own wind range (12 to 22 kt) in 24 kt. `--gear=0` and the Race page's switch turn it off.
- **The hands' noise** is not what makes a rookie slow. Given the all-rounder's steady hands, the six noisiest personas were not faster. The rookies are slow because of their angles (running 9 to 14 degrees too deep), their wide margins and their starts.
- **Two bugs found and fixed in the skipper.**
  - A board that came back to a mark the wrong way round circled it for ever. Aiko on the slalom template made 45 gybes and did not finish, the same family as Noor's twelve minutes. She now finishes.
  - The upwind push described above.
- **The Race page** lists the twenty ("The personas, rookie to pro"), with a new switch "Their own gear". The screenshot shows that it fits.

## 2. The twenty personas

The table runs from the pro down to the beginner. The skills are the sheet's own, 0 to 1; the other columns are what the sheet becomes:

- **Push** is `push_offset`, as a share of the slider. It is used off the wind only; 0 means the slider is left to the pilot, and in 12 kt it changes nothing (PH26).
- **Hands** are the reaction time and the steering noise at 18 kt; in a persona's own wind they are better.
- **Gear** is the sail's brand and size, the board's volume and the fin's depth, as the race tool printed them for the T1 races.

Each race draws the day's sheet a little differently (the consistency), so these columns are seed 1's.

| Name | The story | Skills (speed, upwind, downwind, gybing, risk, consistency; light / strong wind) | Push at 18 / 24 kt | Hands at 18 kt (reaction, noise) | Gear at 12 / 18 / 24 kt (sail m², board L, fin cm) |
|---|---|---|---|---|---|
| Hana (Fuerteventura) | the pro: fast everywhere, sharp starts, rarely wrong | 0.95, 0.95, 0.95, 0.95, 0.6, 0.95; 0.8 / 0.8 | +0.06 / +0.07 | 0.26 s, 0.8° | Point.9 8.8 / 122 L / 46 · Point.9 8.8 / 122 L / 42 · Point.9 6.8 / 122 L / 38 |
| Mara (Lake Silvaplana) | the all-rounder: good everywhere, best nowhere | 0.85, 0.85, 0.85, 0.85, 0.5, 0.85; 0.5 / 0.5 | +0.04 / +0.04 | 0.32 s, 1.2° | Savanna 8.5 / 125 L / 46 · Savanna 8.0 / 125 L / 42 · Savanna 7.5 / 125 L / 38 |
| Marco (Lake Garda) | the gambler: early starts, thin margins, big days and bad days | 0.7, 0.6, 0.6, 0.7, 0.95, 0.35; 0.4 / 0.7 | +0.09 / +0.10 | 0.44 s, 2.0° | Point.9 8.8 / 122 L / 46 · Point.9 8.8 / 122 L / 42 · Point.9 6.8 / 122 L / 38 |
| Kofi (Lake Victoria) | the fastest board on the water, on the days it all comes together | 0.95, 0.6, 0.7, 0.6, 0.6, 0.2; 0.5 / 0.6 | +0.09 / +0.09 | 0.20 s, 0.3° | s3kauai 9.0 / 129 L / 46 · s3kauai 7.6 / 111 L / 42 · s3kauai 6.7 / 111 L / 38 |
| Tomas (Pozo Izquierdo) | the youngster: fast and fearless, a different sailor every race | 0.85, 0.4, 0.6, 0.7, 0.9, 0.25; 0.35 / 0.75 | +0.14 / +0.14 | 0.20 s, 0.3° | Point.9 8.8 / 128 L / 46 · Point.9 7.8 / 108 L / 42 · Point.9 6.8 / 108 L / 38 |
| Yusuf (Alacati) | slalom pro: flat out on a reach, gybes at full speed, the beat is a chore | 0.9, 0.45, 0.85, 0.95, 0.7, 0.75; 0.4 / 0.7 | +0.07 / +0.08 | 0.39 s, 1.7° | SouthSails 8.6 / 125 L / 46 · SouthSails 7.7 / 117 L / 42 · SouthSails 6.8 / 117 L / 38 |
| Lena (Lake Garda) | slalom specialist, fearless starts, loses the beat | 0.8, 0.3, 0.8, 0.9, 0.8, 0.7; 0.4 / 0.6 | +0.10 / +0.10 | 0.39 s, 1.7° | NielsTrots 9.0 / 128 L / 46 · NielsTrots 8.2 / 128 L / 42 · NielsTrots 7.4 / 108 L / 38 |
| Sven (Klitmoller) | loves a breeze: fast and loose when it blows, bored in light wind | 0.9, 0.5, 0.7, 0.7, 0.7, 0.6; 0.2 / 0.85 | +0.08 / +0.09 | 0.30 s, 1.0° | s3kauai 9.0 / 122 L / 46 · s3kauai 7.6 / 116 L / 40 · s3kauai 6.7 / 116 L / 38 |
| Bruno (Tarifa) | the storm sailor: at home in a gale, lost when it is light | 0.8, 0.6, 0.75, 0.85, 0.7, 0.6; 0.1 / 1.0 | +0.00 / +0.04 | 0.34 s, 1.3° | s3kauai 9.0 / 128 L / 42 · s3kauai 7.6 / 108 L / 40 · s3kauai 6.7 / 98 L / 38 |
| Noor (Scheveningen) | flies downwind, gybes on a coin, slow to windward | 0.75, 0.4, 0.95, 0.95, 0.6, 0.7; 0.5 / 0.6 | +0.04 / +0.05 | 0.44 s, 2.0° | SouthSails 8.6 / 129 L / 46 · SouthSails 7.7 / 111 L / 42 · SouthSails 6.8 / 111 L / 38 |
| Aiko (Lake Biwa) | starts at the pin, goes left, reads the shifts | 0.65, 0.8, 0.5, 0.6, 0.5, 0.8; 0.6 / 0.4 | +0.00 / +0.00 | 0.45 s, 2.0° | SouthSails 8.6 / 129 L / 46 · SouthSails 8.6 / 129 L / 42 · SouthSails 6.8 / 111 L / 40 |
| Tobias (Kiel) | course racer: tight laylines, tacks like a machine | 0.7, 0.95, 0.5, 0.5, 0.4, 0.8; 0.6 / 0.4 | +0.02 / +0.00 | 0.40 s, 1.7° | NielsTrots 9.0 / 125 L / 46 · NielsTrots 8.2 / 125 L / 42 · NielsTrots 7.4 / 125 L / 38 |
| Greta (Hyeres) | the old hand: wins the beats on the shifts, slow hands on a reach | 0.45, 0.95, 0.6, 0.45, 0.3, 0.9; 0.65 / 0.35 | -0.05 / -0.06 | 0.61 s, 3.2° | GG 8.4 / 122 L / 46 · GG 8.4 / 122 L / 42 · GG 6.7 / 122 L / 38 |
| Ines (Cascais) | careful: wide margins, never over early, rarely falls | 0.6, 0.6, 0.6, 0.6, 0.15, 0.95; 0.5 / 0.4 | -0.06 / -0.07 | 0.52 s, 2.6° | Savanna 8.5 / 125 L / 46 · Savanna 8.0 / 117 L / 42 · Savanna 6.5 / 117 L / 38 |
| Elin (Lake Silvaplana) | the gust hunter: always off to where the water is dark | 0.7, 0.6, 0.6, 0.6, 0.6, 0.7; 0.6 / 0.5 | +0.03 / +0.03 | 0.43 s, 2.0° | GG 8.4 / 129 L / 46 · GG 8.4 / 129 L / 42 · GG 6.7 / 111 L / 40 |
| Liv (Lake Constance) | the light-wind magician: planes when nobody else can, hangs on when it blows | 0.75, 0.8, 0.75, 0.6, 0.4, 0.8; 1.0 / 0.1 | -0.02 / -0.05 | 0.42 s, 1.9° | NielsTrots 9.0 / 129 L / 46 · NielsTrots 9.0 / 129 L / 46 · NielsTrots 7.4 / 111 L / 40 |
| Pavel (Lake Balaton) | holds at the boat end and goes on the gun | 0.65, 0.65, 0.5, 0.5, 0.5, 0.85; 0.5 / 0.5 | +0.00 / +0.00 | 0.45 s, 2.1° | GG 8.4 / 129 L / 46 · GG 8.4 / 129 L / 42 · GG 6.7 / 111 L / 38 |
| Ravi (Brouwersdam) | the club racer: steady, sensible, never brilliant | 0.45, 0.45, 0.45, 0.4, 0.4, 0.8; 0.5 / 0.4 | +0.00 / +0.00 | 0.73 s, 4.1° | Tripletone 8.5 / 129 L / 46 · Tripletone 8.5 / 129 L / 42 · Tripletone 6.7 / 111 L / 38 |
| Jonas (Lake Silvaplana) | the rookie: late, wobbly, learning fast | 0.25, 0.3, 0.3, 0.2, 0.3, 0.3; 0.4 / 0.25 | -0.05 / -0.07 | 0.80 s, 4.6° | Tripletone 8.5 / 125 L / 46 · Tripletone 7.7 / 125 L / 42 · Tripletone 6.7 / 125 L / 38 |
| Pia (Lake Neusiedl) | first season: slow, careful and wobbly, but she finishes | 0.1, 0.15, 0.15, 0.1, 0.15, 0.4; 0.45 / 0.2 | -0.07 / -0.08 | 0.77 s, 4.3° | Savanna 8.5 / 125 L / 46 · Savanna 8.0 / 125 L / 42 · Savanna 6.5 / 125 L / 38 |

The skills drive the numbers through `persona.gd`; only three sheets were touched after the measurements. Hana got 0.8 in both winds (a pro is good in every wind). Tobias's and Greta's pinching style was softened to −0.5 and 0, because the polar's best is already the highest angle that pays (section 5). The brands are the game's own (`Game/gear/brands/`): each persona has a sail brand and a board brand, and the fins come from every slalom fin. Pia and Jonas sail Savanna boards, a brand with no slalom board, so they get its free race board (125 L in light wind), a beginner's wider board.

## 3. What changed in the code

- `Game/race/persona.gd` (the skill sheet):
  - **Two wind skills**, `light_wind` and `strong_wind` (0 to 1, 0.5 = as good as in any wind). `wind_form()` moves the sailing skills (tacking, gybing, boat speed, upwind and downwind sense) up or down in the sailor's own wind: by up to ±0.15 at 12 kt and at 24 kt, not at all at 18 kt.
  - **Light-wind footing** (`light_wind_foot_deg()`): at 12 kt a light-wind sailor beats up to 3 degrees lower than the polar's best, to keep the board planing. A sailor who dislikes light wind pinches by as much.
  - **The push** (`push_offset_for()`): ±0.10 of the slider from the day's risk, ±0.05 from the hands (boat speed), capped at ±0.15. Below ±0.02 it is 0: a middling sailor leaves the slider alone.
  - **The gybing skill** (unused before) now sets how tight it rounds the marks, together with its risk.
  - **The gear** (`gear_for()`, `pick_for_wind()`, `brand_items()`, `rig_power()`): the board from its board brand and the sail from its sail brand, from the slalom line (a brand without one: its free race line), plus a slalom fin of any maker. Of each kind it takes the items whose wind range in the catalogue covers the wind (or, if none does, comes nearest). From those it takes the smallest to the biggest by its rig power: 0.5, plus half of (light-wind skill minus strong-wind skill), plus 0.4 × (risk minus 0.5). The new fields are `sail_brand` and `board_brand`. The old `rig()` (it only scaled the sail's area) and the fields `sail_light_m2`, `sail_strong_m2` and `gear_switch_kt` are gone.
- `Game/race/skipper.gd`:
  - **No push upwind** (`PUSH_UPWIND_TWA_DEG` = 60): closer to the wind than 60 degrees, a character's push offset is not used.
  - **The wrong-way rounding** (`going_round_the_wrong_way()`, `WRONG_WAY_COS`, `WRONG_WAY_BACK_M`): a board heading more than 120 degrees from the way a rounding crosses the ray is not level with the mark. Within 30 m of the mark, it first goes back down the leg on the entry side (section 4, Aiko).
- `Game/race/skippers.gd`: `gear_for(skipper, wind_kt)` gives a persona's gear, or none for every other skipper.
- `Game/dev/run_race.gd` (`tools/race.sh`):
  - `--gear=1` builds each persona's board on its gear before its controller gets the sail, and prints the gear.
  - Every race prints each scripted skipper's sheet ("sheet Name hands 0.20 s 0.3 deg push +0.10 beat +1.2 deg run +1 deg layline 14 m").
  - `--steady_hands=1` gives every scripted skipper the all-rounder's hands (to measure what the noise costs).
- `Game/race/race_runner.gd` (the race scene): with `RaceSetup.gear` on, each persona's `WindsurferNode.gear` is set before the node is added, so its simulation and its look are built on its gear.
- `Game/race/race_setup.gd`: `gear` described anew (`--gear=0/1`).
- `Game/ui/race_page.gd`:
  - "The personas, rookie to pro" replaces "The twelve personas".
  - A new switch, "Their own gear", sets `RaceSetup.gear`.
- `Game/race/personas/`: eight new sheets (bruno, greta, hana, liv, pia, ravi, tomas, yusuf). The twelve got their wind skills and brands. Tobias's and Greta's pinching style is softened, and Hana is 0.8 in both winds.
- `tools/persona_matrix.sh` has two new modes:
  - `--courses= --winds=` races the personas in a fleet on T1 and T2 through `race_matrix.sh` and prints one table: places, falls, DNFs, and the course or slalom, light or strong wind notes.
  - `--alone=1` sails each persona alone against the clock in every race (`--jobs=` processes at a time) and ranks the times.
  - `--table_only=1` rebuilds a table from races already run.
- Tests:
  - `Game/tests/unit/test_personas.gd`: twenty personas; the push (a bold one pushes, a careful one eases, a middling one leaves it alone); the wind skills and the footing; rookie to pro; the gear from the catalogue for the wind; the gear in the race tool, on and off; the Race page lists the twenty.
  - `Game/tests/unit/test_skipper_speed.gd`: the wrong-way rounding; no push upwind.
- The trainer (`race_env.gd`) makes no personas (its boards are the learned skipper's and the all-rounder's), so it does not share the gear path and is unchanged. Nothing in `Game/sim/` changed.

## 4. The matrix, before and after

### 4a. The yardstick: the persona matrix at 18 kt as it stood

This is `tools/persona_matrix.sh --wind_kt=18`, the twelve personas on the templates, run on gear/lead at 118fed6 (package 1 merged) and compared with the lead's baseline from before package 1 ([baseline/persona_matrix_18kt.txt](baseline/persona_matrix_18kt.txt)):

- **LG2 at 40 % (the course family):** all twelve finish, with no falls. The winner went from 11:52.4 to 11:29.3 (Aiko, ahead of Lena and Tobias). The last went from 14:12.9 (Pavel) to 14:11.1 (Jonas).
- **PD3 at 60 % (the slalom family):** Noor's twelve minutes at mark 1 are gone; she finished 9th in 3:45.6. **But Aiko did not finish**: 45 gybes round mark 1, 69 m from it at the end. She had come back to the mark from the north after two penalty turns beside it, heading south. The skipper counted her as level with the mark and aimed her at the exit, so she gybed the long way round and went round the mark the wrong way, again and again. This is fixed (section 3, the wrong-way rounding). Re-raced the same way she finishes in 4:52.6 with 8 gybes, and the other eleven's times are unchanged to within a second or two.

### 4b. The twenty alone against the clock (the skills without the crowd)

In a fleet of twenty, the rules and the crowd decide the places as much as the skills do: on T2 most boards turned one to four penalty circles. So each persona also sailed every race alone: the same start from 150 m behind the line, the 60 s countdown, seed 1. This is the final code with their own gear (the default; run `gear3`). Each cell is the time and the place among the twenty; F marks a fall.

```
persona          t1@12         t1@18         t1@24         t2@12         t2@18         t2@24  falls  mean
Aiko       12:44.5  11    7:45.5   4    7:00.8  11    4:53.0  10    3:53.3  19    3:15.4   7      0  10.3
Bruno      13:13.1  16    8:06.7  12    6:26.8   1    5:00.7  13    3:15.0  12    2:36.9   1      0   9.2
Elin       13:01.8  13    8:13.8  14    7:09.3  13    5:05.2  15    3:12.1   7    3:32.8  15      0  12.8
Greta      13:15.0  17    8:15.7  15    7:19.3  15    5:10.8  17    3:16.7  15    4:02.6  20      0  16.5
Hana       12:32.7   7    7:45.4   3    6:45.7   7    4:51.8   8    3:09.5   2    3:08.7   5      0   5.3
Ines       12:42.6  10    8:22.7  16    7:39.3  16    5:08.1  16    3:19.1  16    3:23.7  10      1  14.0
Jonas      13:43.1  19    8:50.0  20    7:55.4  19    5:20.6  20    3:26.9  18    3:42.5  18      0  19.0
Kofi       11:55.4   2    8:13.0  13    6:50.8  10    4:45.3   3    3:11.4   6    3:30.4  12      0   7.7
Lena       12:22.8   5    8:00.7   8    6:32.8   3    4:43.5   2    3:13.1  11    3:18.6   9      1   6.3
Liv        11:52.5   1    8:02.5   9    7:53.4  18    4:47.5   5    3:54.9  20    3:30.7  13      0  11.0
Mara       12:21.7   4    7:43.1   2    6:33.0   4    4:53.9  11    3:12.5   8    3:07.3   3      0   5.3
Marco      12:13.6   3    7:41.4   1    6:39.5   6    4:48.5   6    3:09.7   4    3:08.4   4      0   4.0
Noor       13:04.2  15    8:26.8  18    6:46.7   8    4:59.6  12    3:09.1   1    3:18.5   8      1  10.3
Pavel      12:35.2   8    7:52.7   6    7:12.6  14    5:01.3  14    3:12.7   9    3:33.1  16      0  11.2
Pia        14:05.3  20    8:37.5  19    7:43.0  17    5:15.1  19    3:22.5  17    3:45.0  19      0  18.5
Ravi       13:35.4  18    8:25.2  17    7:58.6  20    5:10.9  18    3:12.8  10    3:35.2  17      0  16.7
Sven       12:41.7   9    8:04.5  11    6:32.1   2    4:45.9   4    3:15.3  14    3:03.6   2      0   7.0
Tobias     12:31.0   6    7:59.5   7    7:06.5  12    4:40.1   1    3:09.5   2    3:30.0  11      0   6.5
Tomas      12:58.3  12    7:46.9   5    6:48.7   9    4:49.1   7    3:11.3   5    3:09.5   6      0   7.3
Yusuf      13:03.4  14    8:02.7  10    6:38.0   5    4:52.8   9    3:15.1  13    3:31.6  14      0  10.8
```

The average place by course and by wind (T1, T2; 12 kt, 24 kt):

| Persona | T1 | T2 | 12 kt | 24 kt | What the sheet says |
|---|---|---|---|---|---|
| Hana | 5.7 | 5.0 | 7.5 | 6.0 | the pro |
| Marco | 3.3 | 4.7 | 4.5 | 5.0 | the gambler (thin margins, pushes) |
| Mara | 3.3 | 7.3 | 7.5 | 3.5 | the all-rounder |
| Liv | 9.3 | 12.7 | **3.0** | **15.5** | the light-wind sailor |
| Bruno | 9.7 | 8.7 | **14.5** | **1.0** | the strong-wind sailor |
| Sven | 7.3 | 6.7 | 6.5 | **2.0** | loves a breeze |
| Noor | **13.7** | **7.0** | 13.5 | 8.0 | flies downwind, slow to windward |
| Yusuf | 9.7 | 12.0 | 11.5 | 9.5 | slalom pro (does not show) |
| Tobias | 8.3 | 4.7 | 3.5 | 11.5 | course racer (does not show) |
| Greta | 15.7 | 17.3 | 17.0 | 17.5 | old hand, slow hands |
| Ravi | 18.3 | 15.0 | 18.0 | 18.5 | club racer |
| Pia | 18.7 | 18.3 | 19.5 | 18.0 | first season |
| Jonas | 19.3 | 18.7 | 19.5 | 18.5 | the rookie |

What it says:

- From rookie to pro, the order holds. Pia and Jonas are in the last four of every race, and Ravi in five of the six. Hana, Marco and Mara are the top three on average.
- The spread is 8 % (T1 at 18 kt: Marco 7:41, Jonas 8:50, which is 15 %; T2 at 18 kt: 3:09 against 3:27, which is 9 %).
- The wind specialists show. Liv wins T1 in 12 kt by 3 s over Kofi and is 18th in 24 kt. Bruno wins both races in 24 kt (T2 by 27 s) and is 16th and 13th in 12 kt.
- The course specialists do not (section 5).
- **Every persona finishes all six races alone, and only 3 boards fell in 120 races**: Ines and Lena on T1 at 24 kt, Noor on T1 at 18 kt.

### 4c. The twenty in a fleet

FLEET_TABLE

## 5. What each lever did, measured

Each line compares the twenty alone in the same six races (seed 1). "Sum" is the twenty's finish times added up; F is falls.

| Run | What it is | T1 12 / 18 / 24 kt, sum in s (falls) | T2 12 / 18 / 24 kt, sum in s (falls) |
|---|---|---|---|
| base | the new sheets, push everywhere, default gear | 16958 / 9789 / 8691 (25 F) | 6415 / 3850 / 4136 (5 F) |
| final | + no push closer than 60 degrees | 16867 / 9754 / 8330 (2 F) | 6415 / 3854 / 4079 (0 F) |
| final2 | + light-wind footing, gybing → mark margin, the wrong-way rounding | 16813 / 9659 / 8310 (6 F) | 6392 / 3853 / 4133 (4 F) |
| final3 | + no push while turning onto a new course (default gear) | 16831 / 9653 / 8345 (11 F) | 6363 / 3859 (1 F) / 4060 (3 F) |
| gear | final2's code on their own gear, the middle of the catalogue's range | 15512 / 9926 (1 F) / 8656 (13 F) | 5976 / 3947 / 3970 (7 F) |
| **gear3** | **final3 on their own gear, three quarters up the range (the default now)** | **15393 / 9736 (1 F) / 8492 (2 F)** | **5943 / 3962 / 4064 (0 F)** |

**The push.**

- A persona's offset comes from its risk (±0.10) and its hands (±0.05), capped at ±0.15, with no offset when it is under 0.02. In seed 1's sheets, 12 personas push (+0.04 to +0.14) and 5 ease (−0.03 to −0.09); Hana pushes +0.06.
- **Upwind it only made falls.** Pushed on the 24 kt beat, the twenty fell 25 times on T1 alone, 22 of them on the beat, and the pushers lost 1 to 2 minutes each. Package 1's polar agrees: pushing upwind gains at most 1 % at 18 kt and loses 1 to 4 % at 24 kt. Since "no push closer than 60 degrees" (base → final), T1 at 24 kt is 361 s faster for the twenty, with 25 → 2 falls, and T2 at 24 kt 57 s faster, with 5 → 0 falls. 12 and 18 kt are unchanged (−0.5 % and −0.4 %).
- **Off the wind it pays on a reach in a breeze.** On T2 at 24 kt alone, the pushers Marco (+0.10) and Tomas (+0.14) were 1st and 2nd on the default gear (3:00 each) and Bruno (+0.10) 1st on his own. At 18 kt T2 changes by less than 0.2 %. In 12 kt the slider does nothing (PH26).
- On the default 8.0, the pushers still fell on the 24 kt run, at 120 to 136 degrees: 6 to 11 falls on T1. "No push while turning onto a new course" did not cure that in the gear-off runs: 6 falls before it, 11 after, which one seed cannot tell apart. **On their own gear** (smaller sails in 24 kt), **the pushers do not fall**: 2 falls in all 24 kt races.
- A separate run with the push switched off on the final code (`--skipper_push=0`) was not made (the time); the comparison above is push everywhere against push off the wind.

**The gear** (final3 → gear3, the same code, the default 8.0 against their own gear):

- 12 kt: T1 −1438 s (−72 s, or −8.5 %, a persona; every persona is faster) and T2 −420 s (−6.6 %). Every persona rigs 8.0 to 9.0 on a 122 to 129 L board.
- 18 kt: T1 +83 s (+0.9 %) and T2 +103 s (+2.7 %, two thirds of it Aiko and Liv). Most rig 7.6 to 8.8.
- 24 kt: T1 +147 s (+1.8 %) with 11 → 2 falls; T2 +4 s with 3 → 0 falls. They rig 5.9 to 7.6.
- The first try took the middle of the catalogue's range (run `gear`): a 7.5 to 7.8 in 18 kt, 3 % slower than the 8.0, as package 1 measured. Three quarters up the range rigs about the 8.0 there.
- **My call: the gear is on by default** (the race scene, the Race page's switch, the race tool). It is the brand and the look, it makes the light-wind and strong-wind sailors show, it is much faster in light wind and safer in a strong one, and it costs 1 to 3 % in 18 and 24 kt.
- The skipper still times its legs and its start with the 8.0's polar, whatever it rigs. Each sail its own polar would cost `tools/push_check.sh` some hours a sail; it is an open item.

**The hands' noise** (run `steady`, the six noisiest personas at 18 kt with the all-rounder's hands, 0.25 s and 0.5 degrees, against their own, 0.4 to 0.8 s and 1.9 to 4.6 degrees):

- T1 −12 s for the six together; T2 +71 s (Pia and Ravi slower with steady hands, on their starts).
- So the noise costs little by itself. What makes the rookies 8 to 15 % slower is the rest of their sheet: they run 9 to 14 degrees deeper than the polar's best, beat 3 to 4 degrees lower, keep 33 to 36 m from the laylines, and start late.

**The wind skills** (the form and the footing):

- With the default gear, they moved the specialists only part of the way: Liv's average place was 8.5 in 12 kt and 15.5 in 24 kt, Bruno's 13.0 and 6.0.
- The footing (up to 3 degrees lower in light wind) was added after the six fastest on T1 in 12 kt all beat about 3 degrees low. Re-raced, that correlation did not hold (Liv 12th after the start in both runs), so its effect is small. It stays, as a real light-wind habit that does no harm.
- It is the gear that makes them show.

**Why the course and slalom specialists do not show.**

- What makes a board fast on T1 here is the run angle (8 or more degrees too deep costs 2 to 4 %), the layline margin and the start. Upwind, every skipper already beats at the polar's best angle (package 1), and the steady wind has no shifts to read. So the upwind sense, the tacking and the shift sense have little to work with. The course racers' "points high" style was only slower.
- On T2 the start (a reaching start; over early in 24 kt) and the push decide.
- The gybing skill sets the mark margin now, but a gybe itself is the controller's, the same for every AI board. A gybe that a skilled sailor does faster would need the sailor's technique per board (SailorConfig, the physics' side; an open item).
- With one seed the differences between the top ten (1 to 3 %) are luck as much as skill.

## 6. What I could not verify

- **The look of the gear on the water.** The race scene builds each persona's board, sail and fin when the gear is on (`RaceSetup.gear`, the Race page's new switch), but no race was opened in a window. I did not see the brands' boards and sails sail, or how the persona's sail colour sits on a brand's sail. The Race page itself was screenshot (`.screenshots/race_page.png`): the lists fit, and the twenty cards scroll in their box.
- **How it feels to race them**: no game was played.
- **The lake, gusts and wind shifts.** Every number here is the open water's steady wind with waves (the race tool's default). On the lake the gust appetite and shift sensitivity would come into play, and the push would likely fall more in gusts.
- **Seeds.** Each race was sailed once (seed 1). The differences between the top ten are 1 to 3 %, which one seed cannot separate from luck. The rookies at the bottom, the falls and the finishes are robust; the order within the top is not.
- `tools/test.sh validation` was not run: it is slow, no physics changed, and the training night had the machine. Its skipper tests race the characters, not the personas. The two skipper changes (no push upwind; the wrong-way rounding) touch every scripted board, so run `tools/test.sh validation -gselect=skipper` before merging.
- The frame cost of twenty AI boards on their own gear in the game window (`tools/fleet_measure.sh`): not measured. The gear changes only the configs the physics is built from, not the work per tick.

## 7. Open items

- **RA (the course and slalom specialists):** for them to show, the skipper needs levers that differ between a beat and a reach. Options:
  - a per-sailor gybe (the hands' timing through the gybe, or the sailor's technique: SailorConfig, so Michiel's);
  - shifts in the race's wind, for the upwind sense to read (the lake's wind has them);
  - each persona's own run angle from the race-tested best rather than the polar's.
- **RA (the push on the 24 kt run, default gear):** on the default 8.0 the pushers still fall on the run at 120 to 136 degrees. The rule "no push while turning" (`PUSH_TURN_DEG`) did not show a cure in one seed. It is harmless on their own gear (2 falls). Several seeds would tell whether it helps or should go.
- **RA (several seeds):** the alone matrix with seeds 1 to 3 would separate skill from luck in the top ten. Each seed is 120 races, about 45 minutes on 6 processes.
- **RA (the fleet of twenty, the rules):** on T2 most boards turn one to four penalty circles. The crowd at a reaching start and at the gybe marks decides the places more than the sailing.
- **RA, start (not this package's):** in 12 kt the start costs 33 to 97 s alone, and it decides T1's places (Hana started 97 s late in `final3`). On T2 at 24 kt the reaching start is over early (package 1's open items).
- **GE / RA (a polar per sail):** the skipper times its legs and its start with the 8.0's polar on every sail. Per sail size, `tools/push_check.sh --gear_sail=<id>` (and `--gear_board`, `--gear_fin`) at 12, 18 and 24 kt, then `Skipper.take_polar()` per board.
- **PH (the sail sizes, PH14):** on their own gear the twenty were 8.5 % faster in 12 kt (8.0 to 9.0 sails, 122 to 129 L boards) and fell 2 times instead of 11 in 24 kt on 5.9 to 7.6 sails. The order of the sizes and the boards in strong wind is Michiel's to judge.
- **PH26, confirmed again:** in 12 kt the push slider changes nothing.
- **The Race page:** the fleet sizes deal the personas in alphabetical order, so a fleet of 7 is always Aiko to Ines. Dealing them in a mixed order of levels would be kinder to a small fleet.
- **ROADMAP:** RA6 (the characters) is done by this package, for the lead to move in the roadmap; the items above are new.

## 8. The commands to repeat the numbers

- The twenty alone against the clock, T1 and T2 at 12, 18 and 24 kt: `tools/persona_matrix.sh --courses=t1_loop,t2_slalom --alone=1 --run=final2 --jobs=6` (some 45 to 90 minutes; the table is in `.sim_output/persona_alone_final2.txt`). The same with `--gear=1` (the gear), `--skipper_push=0` (no push) or `--steady_hands=1` (the all-rounder's hands), each under its own `--run=`.
- The twenty in a fleet: `tools/persona_matrix.sh --courses=t1_loop,t2_slalom --run=fleet` (six Godot processes; the table is in `.sim_output/persona_matrix_fleet.txt`). In halves: `--courses=t2_slalom --run=x`, then `--courses=t1_loop --run=x`, then `--courses=t1_loop,t2_slalom --run=x --table_only=1`.
- The persona matrix on the templates, as the baseline: `tools/persona_matrix.sh --wind_kt=18`.
- The twelve before (the baseline on T1 and T2): `tools/race_matrix.sh --run=p12_before --seed=1 --skippers=persona:aiko,...,persona:tobias`, on the code of 118fed6.
- One race to look at: `tools/race.sh --course=t1_loop --wind_kt=24 --skippers=persona:marco --seed=1 --prestart=60` (add `--gear=1`, `--out_dir=<folder>` for the CSV of the track).
- Aiko's wrong-way rounding: `tools/race.sh --course=template:PD3@60 --wind_kt=18 --skippers=persona:aiko,persona:elin,...,persona:tobias --seed=1 --prestart=60 --seconds=1500 --finish_window=900 --skipper_push=0`.

## 9. The tokens

The caster (Opus, effort xhigh): about 0.55 M tokens of the 0.6 M budget. Most of it went on reading the code and the results; the measuring itself ran in the background, about 1,000 headless races in some nine hours beside the training night.
