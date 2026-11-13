# E03 · The wind

Owner: Max (the map's wind patterns), Michiel for `WindField`'s interface | Roadmap: MA4, MA5, MA6, MA9, PH7, GR2 | Questions: Q15, Q16

**Goal.** Every spot has its own wind: the local system (thermal, trade, funnel, katabatic, river), its day cycle, its gusts, lulls, shifts and lee, measured where data exists and modelled by type where it does not, seen on the water and in the tower's wind viewer, and drawn by day for the season.

**Done when (1.0).** A `WindModel` per spot drives the sailing, the AI, the viewer and the water's look from one set of numbers; each spot's model is checked by someone who sails there; a climatology per spot draws a day's conditions; the open sea's gust statistics are measured, not the lake's copy; the wind viewer and its tactics tools work on any spot.

**Where things stand (6 November 2026).** Silvaplana's Maloja wind is the model: a terrain pattern from a WindNinja run (speed factor and turn per 50 m cell), a day cycle from five MeteoSwiss stations (hourly medians 10:00 to 21:30), gusts as fronts and lanes measured on 22 satellite photos, pulses, shifts, a shore-lee band, all seeded so a day replays; the lake wind multiplier (x0.4 to 2.0, 6 November). The open water reuses the lake's gust pattern (its own spread is unmeasured) and has no day cycle. The code assumes one lake axis (`upwind_end_m`, "along the lake") and a single lee band. The wind viewer (Windfinder colours, 5000 streaks, a clock at 1x to 60x, a probe) and the course maker exist for Silvaplana only. Day types and the start front, the tactics tools (laylines, lifts and headers, which side paid) and a replayed or live day are open.

## Stories

### E03.S01 · Max's look at the lake wind and the gusts on the water
Status: review | Size: S | Owner: Max | Milestone: M1 | Needs: the night3 build | Roadmap: MA9, GR2, MA1
Done when: Max has sailed the lake at x0.44, 1.0 and 1.65 and says whether the wind feels like the Maloja, whether the gusts are readable from the follow camera in time to ease, and whether the time of day on the HUD is useful.
- [ ] T1 The three multipliers sailed and the answer written (MA9)
- [ ] T2 The gust patches' readability while sailing pushed (GR2)
- [ ] T3 The lake play-test's other questions (MA1: the start spot, the shore)

### E03.S02 · A wind model per spot type
Status: todo | Size: L | Owner: Max with the lead; Michiel for the interface | Milestone: M3 | Needs: Q15, E04.S01 | Roadmap: MA7
Done when: a `WindModel` resource bundles a spot's pattern, day cycle, gusts, shifts, lee and type, `MapWind` no longer assumes one lake axis or one lee band, and there is a model for each type with its parameters explained: thermal (Garda's Ora, Alaçatı, Santa Croce, Silvaplana), trade (Bonaire, Pozo, Fuerteventura), funnel (the Gorge, Lüderitz), frontal (Gruissan's Tramontane, Brouwersdam's south-westers), Maestral (Bol).
- [ ] T1 The resource and the loader; Silvaplana moved onto it bit for bit (the replayed day identical)
- [ ] T2 Gust fronts and lanes along any wind direction over any shape of water; several lee bands (a list of shore segments with depth and share)
- [ ] T3 A day cycle per type: the thermal's onset hour and build, the trade's steadiness and its squalls, the frontal wind's days and nights
- [ ] T4 The height profile and the air density per spot (sea level against 1,791 m)
- [ ] T5 The spot's local sailor answers five questions per type (as `SILVAPLANA_SPOT_NOTES.md` did)

### E03.S03 · The terrain wind run as a pipeline step
Status: todo | Size: M | Owner: the lead | Milestone: M3 | Needs: E04.S02 | Roadmap: MA7
Done when: `tools/map/windninja_pattern.py` takes any spot's DEM and wind cases (not Silvaplana's constants) and writes the pattern grid, with the run's settings per spot type documented.
- [ ] T1 The script's Silvaplana constants moved into the spot's config; the cases (directions, speeds, stability) per spot
- [ ] T2 Over the sea the pattern is flat but the shore's lee and the cliffs' acceleration remain (Pozo's gap wind, Lüderitz's funnel)
- [ ] T3 The pattern checked against a station or two per spot

### E03.S04 · Day types, the start front, and the climatology for the season
Status: todo | Size: M | Owner: Max | Milestone: M4 | Needs: E03.S02, Q16 | Roadmap: MA5
Done when: each spot has light, medium and strong days (and for a thermal the onset front travelling down the water), a month-by-month table of the chance of each wind band and sea state, and a "today" draw the season uses.
- [ ] T1 Silvaplana's day types and the start front (W3's postponed part)
- [ ] T2 The climatology table per spot from Windfinder or station statistics (month x wind band x chance), with its source
- [ ] T3 The day draw: the wind, the sea state, the sky; "no wind today" as a lay day
- [ ] T4 Free sailing keeps the hand-picked settings; the season uses the draw

### E03.S05 · The wind viewer on any spot, and the tactics tools
Status: todo | Size: M | Owner: Max with the lead | Milestone: M4 | Needs: E04.S01, E05.S04 | Roadmap: MA4
Done when: the wind viewer (the tower's view) opens on any spot from its `WindModel`, and W4b's tactics tools exist: lifts and headers against the course axis, the stronger lanes, laylines from the polar's angles, which side paid.
- [ ] T1 The viewer scene generic (today inside `Game/maps/silvaplana/`), its clock from the spot's day
- [ ] T2 Laylines from the skipper's polar per wind; the course's axis and the shifts
- [ ] T3 "Which side paid": a replay of the last race's tracks over the wind picture
- [ ] T4 The viewer inside the tower (E05.S04) and in the LAN race director

### E03.S06 · The open sea's gusts measured
Status: todo | Size: S | Owner: the lead | Milestone: M3 | Needs: — | Roadmap: PH7
Done when: the gust patches on the open water and the sea spots have their own spread and sizes from sea data (satellite roughness at a sea spot, or a buoy's record), not the lake's numbers.
- [ ] T1 Sentinel-2 roughness at two sea spots on windy days (the lake's method, `tools/map/satellite_wind.py`)
- [ ] T2 The sea's spread and front sizes as a second gust resource; the settings' gust strength mapped to it
- [ ] T3 Gusts on by default in the game? (the roadmap's open question)

### E03.S07 · A measured day replayed, or today's live wind
Status: todo | Size: M | Owner: Max with Michiel | Milestone: later | Needs: E03.S02 | Roadmap: MA6
Done when: a spot can replay a recorded day from its station (Segl-Maria for Silvaplana, the Santa Croce scrape for that lake) and, as an option, sail today's live wind.
- [ ] T1 A recorded day as a `WindDay` from a station file
- [ ] T2 The live feed (a small fetch at the start of a session; offline the last day)
Notes: optional; Max's weather-station project shows the pattern of a live pipeline.

### E03.S08 · The wind changes during a game, for everyone
Status: todo | Size: S | Owner: the lead | Milestone: M2 | Needs: — | Roadmap: RA24, MP3
Done when: a wind changed in the pause menu or by the race director reaches every board and the LAN guest at one tick, and the waves follow (RA24 is built as "waits for R"; the live turn is Max's preference to decide).
- [ ] T1 Every board's wind and the course turn at once (or at R, Max's call)
- [ ] T2 The host's change reaches the guest; both seas rebuilt at the same tick (MP3)
