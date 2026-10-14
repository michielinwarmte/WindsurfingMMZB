# Physics requests from the map track (Lake Silvaplana)

Written 14 October 2026 (Session 37, map track) for Michiel and the AI sessions on the physics track. From Max and the map track ([MAP_SILVAPLANA_PLAN.md](MAP_SILVAPLANA_PLAN.md)).

The map track builds the first real spot, Lake Silvaplana (1791 m, Upper Engadin), on the branch `feature/map-silvaplana`. It does not change anything in `Game/sim/`, the shared configs in `Game/config/`, `Game/world/` or `PHYSICS_SPEC.md` (map plan MD7). This document lists what the map would need from the physics, with the numbers and sources we found, so you can decide what to do, how, and when.

**Who does what.**
- **Michiel** does the physics.
- **Max** does the map, and later the wind patterns that belong to it (R5): the daily cycle, the gusts, the shifts, and where the wind is strong or weak on the lake.

The wind patterns describe what the air does; the physics decides what the board does with it. So for R5, Max builds the patterns and Michiel only provides the connection, a way for a map to give `WindField` its own pattern, and checks that the physics stays valid. Everything else in this document is physics, and Michiel decides it.

The interfaces below are suggestions only. D8 applies: every change is a physical effect with a source, not a tuning number.

## Summary

| # | Request | Why | Size | When the map needs it |
|---|---|---|---|---|
| R1 | A map can bring its own environment configs: air, water, wind | Every request below needs it | small | soon (M3 swaps the wind from the scene meanwhile) |
| R2 | Air density as a config value instead of the fixed 1.225 | Measured 0.98 kg/m³ on Maloja afternoons, 20 % less sail force | small | after R1 |
| R3 | Fresh water, 1000 kg/m³ | Silvaplana is a lake; `WaterConfig` already has the field | tiny (only R1) | after R1 |
| R4 | A lakebed the simulation can ask, and running aground | The fin (0.38 m) hits bottom near the shore; the depth is measured | medium | after M1 (the map delivers the depth grid) |
| R5 | Wind that differs from place to place: moving gusts, shifts, the daily cycle. **Max builds the patterns; Michiel provides the connection in `WindField`** | Realistic Maloja; the measured statistics are below | large (mostly Max) | later, a general system for every spot |
| R6 | Waves made by the wind (fetch) | Lake chop instead of the sea swell | large | after the two-body sailor (A-17, spec 17.12) |
| R7 | Replay a measured day, or today's live wind | Fun, and a check of R5 | medium (mostly game side) | after R5 |
| R8 | Other kiters and windsurfers on the water | Life on the lake | large | with main-plan Phase 9 |

The map track will meanwhile use what exists (map plan M3):
- its own `WindConfig` with the current sine gusts and shifts, swapped in by the scene the way `tools/matrix.sh` does,
- the current `waves_default.tres`, unchanged,
- a simple stop in the scene layer when the water under the board gets shallower than the fin.

## R1. A map brings its own environment

`WindsurferSim.create_default()` loads the `Game/config/*_default.tres` files, and `windsurfer.gd` calls it. A map needs to hand over its own air, water and wind settings when the simulation is made. The water config goes into `BuoyancyModel` and `HullModel` at construction, so swapping it afterwards is not enough.

Suggestion: something like `WindsurferSim.create_for(environment)`, where `environment` is a small resource holding the map's `WaterConfig`, `WindConfig`, `WaveSetConfig` and air density. The open water keeps today's defaults, so every existing test and validation stays unchanged.

## R2. Thin air

**Measured.** At Segl-Maria (MeteoSwiss station SIA, 1804 m, at the south-west end of the lake), in the 13 754 ten-minute periods of Maloja wind of the summers 2020 to 2025 (see "The Maloja, measured" below):

| | p10 | median | p90 |
|---|---|---|---|
| station pressure | 817.6 hPa | 822.7 hPa | 826.8 hPa |
| temperature | 11.0 °C | 16.7 °C | 21.1 °C |
| air density (moist air, from pressure, temperature and vapour pressure) | 0.97 kg/m³ | **0.98 kg/m³** | 1.00 kg/m³ |

That is 19.8 % below the 1.225 kg/m³ in the code. For comparison, the standard atmosphere at 1791 m gives 1.028 kg/m³ (16 % below), but a summer afternoon is much warmer than the standard 3.4 °C. The lake is 13 m below the station, which adds about 0.2 %.

**Where 1.225 is now.** `WindsurferSim.RHO_AIR` (`windsurfer_sim.gd:32`, used for the sail at line 176 and the sailor's windage at line 492), and three literal `1.225` values in `autopilot.gd` (lines 364, 388, 403). Tests that pass 1.225 explicitly (`test_sail.gd`) can stay as they are.

**What it does.** Sail lift and drag and the sailor's windage scale with the density, so 20 % less force in the same wind. The speed loss is smaller, because the water drag doesn't change; a validation run on Silvaplana would show how much. Sailors say you need a bigger sail at altitude; Max can say from experience how much bigger.

## R3. Fresh water

`WaterConfig.density_kg_m3` already exists (1025, sea water). Silvaplana needs 1000. That affects buoyancy, the fin force and the hull. The board floats about 2.5 % deeper, so it only needs R1. The viscosity at a summer lake temperature could also differ (`kinematic_viscosity_m2_s` is set for about 15 °C); Max can give the usual water temperature.

## R4. The lakebed, and running aground

**What the map provides** (map plan M1):
- A depth grid of the lake and its shore band, built from swissBATHY3D (1 m survey of 2019, ±0.5 m; it covers the water deeper than about 1 m) and swissALTI3D (the shore, 0.5 m).
- Between the shoreline and the first surveyed point the depth is blended, and checked against the 10 cm aerial photo.
- Format: a 16-bit PNG or EXR with a JSON file for the scale, the offset and the cell size, in the game frame of map plan MD1. Y = 0 is the lake surface, north is −Z.
- The game reads this grid, never the terrain meshes, so the looks can't change the sailing.

**What happens in reality.** In the shallows the fin touches the bottom first. Its tip is 0.38 m below the hull (`fin_default.tres`), so you run aground in about half a metre of water. The board stops hard, the fin may pop out or break, and the sailor steps off or is thrown forward. On the beach the hull grounds as well.

**Suggestion.**
- A `BedSurface` (or a depth query on `WaterSurface`) that returns the bottom height at a point. The open sea has no bottom.
- The fin model checks its tip against it; the hull samples check theirs.
- When the fin touches: no more fin lift, a large resisting force, and the fall state of A-17, so the sailor steps off.

Tests could be:
- sail straight at a sloping bottom at three speeds; the board stops where the water is about fin-deep, without numbers blowing up;
- on the open water nothing changes.

**Lake level.** The level varies through the year (BAFU station 2073, Silvaplanersee–Silvaplana, at about 1791 m). If it varies by more than about 20 cm in summer, the level should be a map setting, so the shallows move with it.

**Meanwhile** the map stops the board in the scene layer when the water gets shallower than the fin plus a margin, and offers a reset. That needs nothing from the physics.

## R5. Wind that differs from place to place

**Who:** Max builds the wind patterns as part of the map work. Michiel is asked for the connection only: a way for a map to hand `WindField` its own pattern, and a check that the validation still passes with it.

**Today.** Spec section 8: one wind for the whole world, gusts as a fixed sum of three sines (`gust_intensity` 0 to 0.5) and shifts as two sines, the same everywhere at the same moment. Section 8 already mentions the legacy `WindManager`'s spatial noise as an idea for gust patches.

**The wish.** A general wind system for every spot:
- gusts and lulls as patches a few hundred metres across, drifting downwind at about the mean wind speed, visible as darker water;
- direction shifts;
- the daily build-up and decay of a thermal wind;
- per-spot effects such as less wind under a shore.

It should stay deterministic (a seed), so tests and replays repeat. `WindField.velocity_at(point)` already takes a position, so the interface may not need to change.

**Targets for Silvaplana, measured** (see the next section):
- a 10-minute mean of 12 kt at the station (p10 9, p90 15),
- the strongest 1-second gust in 10 minutes 1.55 times the mean (p10 1.42, p90 1.77), and the 3-second gust 1.48 times,
- a very steady direction: from 244° (p10 233°, p90 255°), with a median change of 2° and a p90 change of 8° between consecutive 10-minute means.

The station can't show what happens inside the 10 minutes, or where a gust is on the lake. That part is a model, tuned until its 10-minute statistics match these numbers.

**Caveat.** The station stands on land at the upwind end of the lake. Spot guides give 16 to 25 knots on the water, more than the station's 12 kt median. The wind over open water is probably stronger. Max's experience is the check here.

## R6. Waves made by the wind

Lake waves grow with the wind speed and the distance over open water upwind (fetch). With the Maloja along the 3 km lake, the fetch-limited JONSWAP relations (deep water, U10 at 10 m) give:

| Wind (kt) | Fetch | Hs (m) | Peak period (s) | Peak wavelength (m) | Hs / L |
|---|---|---|---|---|---|
| 12 | 3 km | 0.17 | 1.65 | 4.3 | 0.041 |
| 16 | 1.5 km | 0.16 | 1.44 | 3.3 | 0.050 |
| 16 | 3 km | 0.23 | 1.82 | 5.2 | 0.045 |
| 20 | 0.5 km | 0.12 | 1.08 | 1.8 | 0.065 |
| 20 | 3 km | 0.29 | 1.96 | 6.0 | 0.048 |
| 25 | 3 km | 0.36 | 2.11 | 6.9 | 0.052 |

The waves are almost flat near Sils, at the upwind end, and biggest at the camping beach, at the downwind end where the map launches. Formulas: g·Hs/U² = 0.0016·(g·F/U²)^0.5 and g·Tp/U = 0.286·(g·F/U²)^(1/3), with L = g·Tp²/2π.

**This is the hard part.** These waves are shorter and much steeper than the 7 m, 6 cm wave that already halved the speed in Session 36 (spec 17.12). So R6 depends on 17.12's open items 1 and 2: the two-body sailor with compliant legs (A-17), and the strip theory's slam on waves shorter than about three hull lengths. The same system would give every spot, sea or lake, waves that fit its wind.

## R7. Replay and live weather

A game feature on top of R5:
- **Replay:** a measured day from the station's 10-minute data drives the large-scale wind, and R5 adds the gusts inside each 10 minutes.
- **Live:** MeteoSwiss updates `ogd-smn_sia_t_now.csv` every 10 minutes, which gives the live version.

## R8. Other water users

Kitesurfers and windsurfers on the lake, at first for looks only. The AI sailors of main-plan Phase 9 are the natural route.

## The Maloja, measured

**Source.** MeteoSwiss Open Government Data, station Segl-Maria (SIA), file `ogd-smn_sia_t_historical_2020-2029.csv` (10-minute values; timestamps in UTC, so summer local time is UTC+2). Parameters:
- `fkl010z0`: the mean speed,
- `fkl010z1` and `fkl010z3`: the strongest 1-second and 3-second gusts in the 10 minutes,
- `dkl010z0`: the direction,
- `prestas0`, `tre200s0` and `pva200s0`: the pressure, the temperature and the vapour pressure.

Script: `tools/map/maloja_stats.py`.

**Method.** June to September 2020 to 2025, 13:00 to 18:00 local time, mean speed of at least 4 m/s (about 8 kt). Afternoon directions cluster sharply between 225° and 270°, with the most common 15° band at 240 to 255°. The "Maloja sector" is that mode ±45° (202 to 292°): 13 754 ten-minute periods. A "Maloja day" has at least 3 hours of it between 13:00 and 18:00: 445 of 732 summer days, which is 61 %.

**The daily cycle on Maloja days** (local time, medians):

| | 10:00 | 11:00 | 12:00 | 13:00 | 14:00 | 15:00 | 16:00 | 17:00 | 18:00 | 19:00 | 20:00 |
|---|---|---|---|---|---|---|---|---|---|---|---|
| mean (kt) | 5.6 | 9.1 | 11.5 | 12.6 | 12.8 | 12.6 | 12.1 | 11.3 | 10.1 | 8.4 | 6.2 |
| 1 s gust (kt) | 8.7 | 14.4 | 17.3 | 19.0 | 19.6 | 19.6 | 19.2 | 18.3 | 16.7 | 14.2 | 10.9 |
| share from the Maloja sector | 58 % | 81 % | 92 % | 97 % | 99 % | 100 % | 98 % | 97 % | 90 % | 82 % | 69 % |

**Direction on the lake.** The station reads 244°. The lake's long axis runs from about 224° to 44°, so a valley wind along the lake would come from about 224°. The station near Sils may be turned by the local terrain. The map starts from the station's value, and Max checks it on the water.

## Coordination

- The map branch stays out of the physics files listed in map plan MD7. It merges your branch at the start of every map phase and runs `tools/test.sh` and `tools/check.sh` after the merge.
- If you take on a request, the map track can deliver test data for it: the depth grid for R4, the wind statistics for R5.
- Questions about the spot go to Max. Questions about the map data go to the map plan and its progress log entries, marked "(map track)".
