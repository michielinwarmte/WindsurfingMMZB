# E02 · Waves and water

Owner: Michiel for the physics, the lead for the data and the look, Max's eye | Roadmap: PH44, PH11, GR11, GR12, GR6 | Questions: Q14

**Goal.** Realistic waves on every spot: fetch-grown chop on the lakes, swell with groups and sets at sea, the sea bottom (shoaling, refraction, breaking), tides, currents and the shore break, each from a measured or published law, drawn by the same formulas the physics uses, and cheap enough for a fleet.

**Done when (1.0).** Every spot's water is built from its own depth grid, fetch and climate (SWAN offline where the bottom matters); the sea spots have swell, tides and current where the real spot has them; Max's wave checks pass (the crest spacing in board lengths, the height, the whitecap onset, the direction, the gusts' effect, the shore break); the water costs no more than 1.5 ms per board per tick and 2 ms of the graphics card at 1280 by 720.

**Where things stand (6 November 2026).** Research done (`Documentation/reports/waves/wave_system_research.md`, about 70 sources; seven decisions for Michiel, seven questions for Max). Stage 1 and 2 built on the play branch: Lake Silvaplana's fetch-limited chop in four trains (8, 4, 2, 1 m) is in the physics, grown by the SPM law from a 9-ray fetch map, dispersion by depth, the hull's averaged view, the fin's depth fade; a "Lake wave height" setting. Stage 3 (the look): Cox-Munk roughness from the gust picture, whitecaps by Callaghan's law, lingering foam, wind rows, the board's spray, wake, bow wave and splashes. Stage 4 (the bottom): SWAN 41.51 is installed and its 15 Silvaplana cases are ready, but it has never run: five MinGW runtime DLLs are missing next to `swan.exe`. The open water is still four deep-water Gerstner waves with trace chop. No swell spectrum, no sets, no tides, no currents, no shore break, no bottom. Max, 6 November: the lake's waves feel "a little bit low"; the science says the height is right and the biggest waves are about half a real sea's for the same Hs (no sets).

## Stories

### E02.S01 · The wave system's decisions settled
Status: review | Size: S | Owner: Michiel and Max | Milestone: M1 | Needs: — | Roadmap: PH44
Done when: Michiel's seven decisions (growth law SPM or CEM, the fetch's definition, the physics cut-off, orbital decay, finite-depth dispersion, the LAN contract, a native sea or not) and Max's seven answers (crest spacing in board lengths, height, whitecap onset, direction, the gusts' effect, shore break, which spot needs a bottom first) are written into the research report and the spec.
- [ ] T1 Michiel reads section 6 of `wave_system_research.md` and section "Are the waves correct?" of `lake_waves_full.md`; the provisional decisions confirmed or changed
- [ ] T2 Max answers section 8 of the research (on the water, from memory of Silvaplana at 18 and 24 kt)
- [ ] T3 The 1.5x lake wave height: kept as a setting only, or the default after the sets exist (E02.S02)
- [ ] T4 The AI's `sea_height` observation reads the lake's waves, not the settings' (RA13's leftover)

### E02.S02 · SWAN runs, and the sets
Status: blocked | Size: M | Owner: the lead | Milestone: M2 | Needs: the five DLLs copied or allowed by Max | Roadmap: PH44
Done when: SWAN has run the 15 Silvaplana cases, its wave statistics are compared with the game's trains, and the biggest waves of a sea of the same Hs (groups and sets) exist in the game as option A plus C of the SWAN report.
- [ ] T1 The five DLLs (libgfortran-5, libgomp-1, libwinpthread-1, libgcc_s_seh-1, libquadmath-0) next to `swan.exe` in `%LOCALAPPDATA%/Programs/SWAN/41.51` (the winlibs archive is downloaded; Max copies or allows)
- [ ] T2 The 15 cases run (`tools/map/swan_silvaplana.py`), the report filled (`swan_report.py`, `wave_statistics.py`)
- [ ] T3 The set envelope (option A) and the de-octaved trains (option C) in `lake_wave_field.gd` and the shader, bit for bit the old waves when off
- [ ] T4 Measured against the SWAN statistics at the 15 places; the fall rate and speed on the autopilot suite at 1x and with sets
Notes: the bottom matters on under 1 % of Silvaplana; SWAN here is the pipeline's rehearsal for the sea spots.

### E02.S03 · The sea's swell: a spectrum with groups, as a CPU function in bands
Status: todo | Size: L | Owner: Michiel, the lead | Milestone: M3 | Needs: E02.S01, E01.S07 | Roadmap: PH11, PH44
Done when: a sea spot's water is a sum of bands (swell from far away by period and direction, wind sea by fetch) with groups and sets, the same sum in the physics and the shader, costing no more than the lake's four trains per board.
- [ ] T1 The swell as a band set from a spectrum (JONSWAP for the wind sea, a swell peak by period and direction), grouped by a slow envelope; the shader's slots extended or the sum moved to a texture
- [ ] T2 The open water's chop as the default sea, airtime off a crest and the landing (PH11)
- [ ] T3 The wind sea follows the wind of the last hours (a slow rebuild, not per gust); LAN keeps both seas equal (the contract)
- [ ] T4 Cost measured with `tools/sea_bench.sh` and a 20-board race; a native sea (E17.S01) only if the budget breaks
- [ ] T5 Max's eye: the crest spacing, the height, the groups

### E02.S04 · The bottom: shoaling, refraction and breaking, per spot, offline
Status: todo | Size: L | Owner: the lead, Michiel for the physics' reading | Milestone: M3 | Needs: E02.S02, E04.S02 | Roadmap: PH44
Done when: a spot with a bottom that matters (Pozo, Fuerteventura, the Gorge, Brouwersdam's sea side) gets a SWAN run per wind and swell case, the result stored as a field over the area (height, period, direction, breaking share per cell), and the sea function reads it, so the waves steepen, turn and break where they really do.
- [ ] T1 The SWAN pipeline step in `tools/map/`: the depth grid in, the cases per spot's climate, the fields out (`Game/maps/<spot>/waves/`)
- [ ] T2 The sea function reads the field: the band's amplitude and direction per place, the breaking share as foam and a loss of energy
- [ ] T3 The physics' reading of a breaking crest (a stand-in with a source: a steeper face, a push, foam) in E01.S12
- [ ] T4 The look: the crest's foam, the surf zone's white water, the bottom seen through the water (E16.S07)
- [ ] T5 Checked at Brouwersdam first (the pipeline's first sea), then per spot in E04

### E02.S05 · Tides, water level and currents
Status: todo | Size: M | Owner: the lead, Michiel | Milestone: M3 | Needs: Q14, E01.S12 | Roadmap: —
Done when: a spot can have a tide table (the water level over the day, the current's turn), a river current field (the Gorge), and the beach, the shallows and the AI's laylines follow them.
- [ ] T1 The tide as a water level per spot and time (a table from the national service), the depth grid offset by it; the beach's waterline moves
- [ ] T2 A current field per spot (a slow vector grid: tidal current, the river), in the water interface
- [ ] T3 The shore check and the AI's shore lookout read the level; the race's marks drift option (anchored marks do not)
- [ ] T4 The HUD and the tower show the tide and the current; the race director sees the day's tide
Notes: Brouwersdam (sea side), Fuerteventura (the Sotavento lagoon fills at high tide), the Gorge (river 1 to 3 kt against the wind), Lüderitz (the canal is tide-fed).

### E02.S06 · The shore break and the surf zone
Status: todo | Size: M | Owner: the lead | Milestone: M4 | Needs: E02.S04, E05.S05 | Roadmap: —
Done when: at a beach with waves, the last metres break and run up the sand (a look and a hazard for the beach start), the board can be caught by white water, and a calm beach has none.
- [ ] T1 The run-up and the broken wave's foam line on the beach mesh, from the SWAN breaking share near the shore
- [ ] T2 The push of white water on a board at the beach start (E01.S12 T3)
- [ ] T3 Pozo's and Fuerteventura's shore break as the test cases; Silvaplana's and Alaçatı's beaches calm

### E02.S07 · The look of the sea
Status: todo | Size: M | Owner: the lead, Max's eye | Milestone: M3 | Needs: E02.S03 | Roadmap: GR11, GR12, GR6
Done when: the sea's whitecaps, foam streaks, spray off crests, the swell's groups, the colour by depth and the bottom seen through shallow water look right to Max from the follow camera at 60 fps, and the team's look at the water (GR6) is done.
- [ ] T1 The sea's whitecap law by eye (Zhao-Toba or Monahan at sea), long-crested whitecaps on the open water
- [ ] T2 Spray off crests above 25 kt (the crest bursts at 30 kt: CREST_AMOUNT 35?), the bow wave's V, the fall's splash as a sheet and a column, water off the deck (GR12's open points)
- [ ] T3 The colour by depth and the bottom (sand, reef, rocks) through the water: Bonaire's lagoon, Sotavento's, the lake's shallows
- [ ] T4 The graphics card's budget: 2 ms at 1280 by 720 for the water in a 20-board race (today about 1.4 ms more than 0.1 after shading and wind on water)
- [ ] T5 The team's look (GR6): the colour, the foam, the far edge, the spray, the wake, the splash; Max's eye on the lake's whitecap amount at x0.44, 1.0 and 1.65
- [x] T6 The open water's far edge: the square of waves round the camera gone, the far water shades the same waves per pixel (E11.S11 T4, GR14, 12 Nov 2026; Max's look open)

### E02.S08 · The lake's waves finished
Status: todo | Size: S | Owner: the lead, Michiel | Milestone: M2 | Needs: E01.S01, E02.S01 | Roadmap: PH44
Done when: the lake's waves follow the day's wind (rebuilt as the wind changes, not once per run), the gusts' short wavelets and the trains agree, the AI reads them, and the frame cost is back to the old waves' (the +2.3 ms found).
- [ ] T1 The trains rebuilt as the day's wind changes (a slow blend; the LAN contract)
- [ ] T2 The +2.3 ms per tick even with the lake waves off (E01.S01 T5): found and fixed
- [ ] T3 The 1 m train's cost (out of the hull's view?) and the rail strips reading the planing strips' water (the savings named in `lake_waves_full.md`)
- [ ] T4 The OpVectorExtractDynamic warning in `water.gdshader` (the dynamic index) tidied

### E02.S09 · Max's eye on the water of 6 November
Status: review | Size: S | Owner: Max | Milestone: M1 | Needs: the night3 build | Roadmap: GR11, GR12, MA9
Done when: Max has looked at the night3 folder on his screen and answered: the lake's whitecap amount, the crest bursts, the spray, the wake and the bow wave, the lake wind at x0.44, 1.0 and 1.65, the waves' height.
- [ ] T1 The six checks of `lake_wind_shading.md` and the sheets of `wind_on_water.md` and `board_fx.md`
- [ ] T2 Answers written into the reports and the roadmap rows
