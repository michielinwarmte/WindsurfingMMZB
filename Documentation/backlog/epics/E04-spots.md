# E04 · The spots

Owner: Max (the map track) with the lead and agents; local sailors as the checkers | Roadmap: MA1, MA2, MA3, MA7, MA8, TE3 | Questions: Q1, Q11, Q12, Q13, Q14

**Goal.** Thirteen real windsurf racing spots, Silvaplana and the twelve of Max's list (Q1 answered 6 November 2026: Silvaplana is the thirteenth; the order of building is free, Max: "everything needs to be built, no particular order"), each modelled from real terrain and water data with its own wind (E03) and waves (E02), the beach, the hut and the tower (E05), the region's look (buildings, trees, landmarks, boats) and the courses the real events sail there.

**Done when (1.0).** Every spot on the list passes the same ten checks (the story template below), is chosen from one spot list in the menu, the race page and the LAN lobby, and is credited on the credits page with its data's licences. The download stays within the budget of E17.S03.

**Where things stand (6 November 2026).** One spot, Lake Silvaplana: Swiss open data (swissALTI3D 0.5 m terrain, the 2019 lakebed survey, 10 cm aerial photos, swissALTIRegio to the Italian border), a Blender terrain build of 80 chunks, a depth grid for the shore and the shallows, the Maloja wind (E03), the lake's waves (E02), the ten iQFOiL courses fitted, a fly-over and the wind viewer. It took nine map sessions over three days in October plus about fourteen later sessions that touched it; about 5,800 lines of map GDScript, 5,800 of Python tools and 1,700 of shaders; 115 MB of the 300 MB download. **Nothing is generic yet:** 14 of the 21 map scripts import Silvaplana's constants, no script takes a lat/lon or a bounding box, the data sources are Swiss-only, and the lake is hard-wired in about 15 files outside `Game/maps/` (the menu's enum and buttons, the LAN's map enum, the race page's water list, the courses folder, settings labels, dev tools, some 30 tests). The details (the camping, trees, the village, landmarks) are not built (MA3); the sun does not move with the lake's clock; the lake play-test (MA1) and the credits row (MA2, the page exists) are open. Max's folder `santa-croce-wind` already scrapes Lago di Santa Croce's stations (15 years of history).

## The story template for a spot

Every spot story has these ten tasks; a spot is done when all ten are ticked.
1. The dossier: who knows the water (a local sailor to ask five questions), the wind type, the events and their courses, the data sources (from the research dossier in the notes).
2. The data: the terrain model, the bathymetry, the orthophotos, buildings and vegetation, the shoreline, the weather station; licences noted for the credits.
3. Terrain and water built with the pipeline (E04.S02): the chunks, the depth grid, the shore, the start, the sailing area.
4. The wind model (E03.S02) fitted and checked by the local sailor.
5. The waves (E02): the fetch and the swell; the SWAN run where the bottom matters; tides and current where the spot has them.
6. The beach (E05): the launch, the hut, the tower, the landmarks sailors steer by, the region's props.
7. The courses: the templates fitted to the water; the real event's course of the last years.
8. The look (E16.S03): the sky, the sun's path, the haze, the water's colour, the bottom; the credits line.
9. The AI races every course without groundings at every hour of the day; the frame rate within the gate.
10. The check: Max and the local sailor sail it and tick the feel checklist's spot lines.

## What the research of 6 November 2026 found per spot

From `Documentation/reports/spots/spot_dossier.md` (web research, nothing verified on the water). Difficulty is 1 to 5 against Silvaplana.

| Spot | Water, wind | Waves, tides | Open data | Difficulty | Worth knowing |
|---|---|---|---|---|---|
| Brouwersdam | Salt lake side (flat) and North Sea side; synoptic SW to NW, gusty fronts | Flat or chop inside; 0.5 to 2 m waves, about 2.5 m tide, currents at the inlet outside | The best anywhere: AHN lidar 0.5 m, 8 cm photos, open 20 m bathymetry (the Grevelingen's grid to confirm) | 3 (lake side) / 4 (sea side) | DAM-X slalom festival (300 riders, October); no NK slalom found |
| Lago di Santa Croce | Alpine reservoir, S thermal 10 to 25 kt from noon to 19:00 | Chop; the level swings with the hydro plant | Veneto DTM 5 m (1 m in parts), 20 cm photos; no bathymetry | 2 | Max's own station scrape; no racing events found: a freeride lake |
| Lake Garda, Malcesine | Deep lake; Pelèr N in the morning (20 to 30 kt), Ora S in the afternoon (15 kt here, more at Torbole); Balin gusts to 40 kt | Short steep chop; no tide | Tinitaly 10 m, three regions' lidar and photos to stitch; bathymetry by request | 2 | The racing hub is Torbole, 12 km north; Malcesine's castle and the Monte Baldo cable car are the landmarks |
| Gruissan | Sea; Tramontane NW offshore 25 to 45 kt, Marin SE onshore with waves | Flat inshore, chop offshore; no tide | IGN 1 m lidar, 20 cm photos, Litto3D topo-bathymetry: excellent | 3 | The Défi Wind: 10 km legs along the beach, 1,400 riders, May |
| Bol, Brač | Sea channel; Maestral NW thermal 15 to 30 kt in the afternoon | Chop and short waves to 1.5 m; no tide | DGU photos open; lidar DEM unclear or paid; no bathymetry | 3 | PWA slalom 2020 to 2022, IFCA worlds 2025; Vidova Gora 778 m right behind |
| Alaçatı | Shallow bay; Meltem N plus the thermal, 15 to 25 kt | Flat upwind, chop downwind; no tide | Poor: Copernicus 30 m only, no open photos, no bathymetry (Turkish geodata law) | 3 | PWA slalom venue and the youth slalom world cup |
| Bonaire, Lac Bay | Reef lagoon; E trade wind 15 to 25 kt, no terrain | Flat, waist-deep; 0.3 m tide | Weak: an ASTER-based DEM, 2 m coastal bathymetry, 2024 lidar pending | 2 | A freestyle venue (PWA, FPT), no slalom events found; the simplest wind of all |
| Pozo Izquierdo | Ocean; NNE trade wind accelerated to 25 to 50 kt | Swell 1 to 3 m, shore break on boulders; 1 to 2.7 m tide | PNOA lidar and 25 cm photos; no open near-shore bathymetry | 5 | The hardest of the twelve; PWA wave venue, slalom in 2009 and 2023 |
| Fuerteventura, Sotavento | Ocean and a tidal lagoon; NE trade wind funnelled, 20 to 40 kt | The lagoon exists only around high tide; chop and small swell outside; 1 to 2.7 m tide | PNOA lidar (the lagoon floor at low tide) and photos; no bathymetry below low water | 4 | The PWA Grand Slam since 1986 |
| The Gorge, Hood River | River pool; W funnel wind 18 to 40 mph in the afternoon | Steep wind-against-current swell; current 1 to 3 kt; no tide | Excellent, including open river bathymetry (USACE, NOAA) | 4 | Gorge Cup slalom and course series, the Blowout downwinder |
| Lüderitz | A dug 500 m canal in a lagoon; S to SSW 30 to 50 kt | Flat in the canal; the bay cold and choppy | Very poor: 30 m DEM, no photos, no bathymetry | 2 (canal) / 3 (bay) | The speed record venue; the 2026 event cancelled |
| Japan, Yokosuka Tsukuihama | Sea at Tokyo Bay's mouth; synoptic SW or N, 0 to 25 kt, many light days | Chop, typhoon swell at times; 1.5 to 2 m tide | GSI 5 m DEM, 20 cm photos, PLATEAU city model; bathymetry closed | 4 | The PWA World Cup every year since 2017 |

## Stories

### E04.S01 · The spot abstraction: one list of spots drives the game
Status: todo | Size: L | Owner: the lead | Milestone: M10 | Needs: — | Roadmap: MA7
Done when: a `Spot` resource bundles a spot's scene, environment, wind model, waves, courses folder, start, beach, credits and climate; the start menu, the race page, the LAN lobby, the settings labels, the courses, the dev tools and the tests read the spot list; adding a spot means adding a folder and a resource, with no code change; Silvaplana and the open water are the first two spots and play bit for bit as before.
- [ ] T1 `Spot` resource and `Spots` registry (`Game/maps/spots/`); the open water as a spot with no terrain
- [ ] T2 The 15 hard-wired places replaced (`start_menu`, `lan_game`, `net_clock`, `lan_page`, `race_page`, `race_courses`, `race_director_view`, `training_drops`, `persona.home_water`, `settings_menu`, `settings_values`, `map_escape`, `mini_map`, `hud`, `credits_page`, `main.gd`)
- [ ] T3 The fly-over and the wind viewer scenes generic (they live inside `Game/maps/silvaplana/` today)
- [ ] T4 The dev tools and the tests take a spot argument; the LAN sends the spot's id and checks both PCs have it
- [ ] T5 The sun follows the spot's clock (today fixed at mid-July 15:00 on both waters)
Notes: the enabler of every other story here; nothing visible changes for the player.

### E04.S02 · The spot pipeline made generic: a new spot in a week
Status: todo | Size: L | Owner: the lead, Max | Milestone: M10 | Needs: Q13 | Roadmap: MA7, MA8
Done when: `tools/map/` builds a spot from a bounding box and a list of sources (the DEM, the bathymetry, the orthophotos, the buildings, the station), with a reprojection step into the spot's local metric frame, a source adapter per country, the painted-colour fallback where photos are missing, and a written checklist; proven on the first two new spots.
- [ ] T1 `silvaplana_area.py`'s constants become a spot config (bounding box, frame, tile sizes, viewpoints); every script reads it
- [ ] T2 A reprojection step (pyproj) from the source's frame to the spot's local metres (decision MD1 kept inside a spot)
- [ ] T3 Source adapters: swisstopo (done), PDOK and AHN (Netherlands), IGN and RGE Alti (France), PNOA and IGN-ES (Spain), TINITALY and the regional lidar (Italy), GSI (Japan), DGU (Croatia), Copernicus DEM 30 m and GEBCO or EMODnet bathymetry as the fallbacks everywhere, OpenStreetMap for the shoreline, roads and buildings
- [ ] T4 Photos: the national orthophoto where open; Sentinel-2 or the painted colour where not; the far tiles always painted
- [ ] T5 The checklist `tools/map/NEW_SPOT.md`: the steps, the time each takes, what needs Blender, what needs the second machine
- [ ] T6 The build size per spot measured and the tile budget set (E17.S03)
Notes: the research dossier on the twelve spots (`Documentation/reports/spots/spot_dossier.md`, from the 6 November web research) lists the sources per country and a difficulty per spot.

### E04.S03 · Silvaplana completed
Status: todo | Size: L | Owner: Max | Milestone: M10 | Needs: E05.S01, TE2 | Roadmap: MA1, MA2, MA3
Done when: the lake has its details (the camping and the beach from the 10 cm photo and Max's notes, trees from swissSURFACE3D, the buildings of Silvaplana and Surlej, the church, the Corvatsch station, the bridge), the credits line is on the page and the row closed, the lake play-test is done, and the spot passes the ten checks.
- [ ] T1 MA1, the lake play-test: the start spot, the Maloja setting, the shore, the time of day on the HUD
- [ ] T2 MA2 closed (the credits page exists; check swissALTIRegio's version wording)
- [ ] T3 The trees (a MultiMesh sized from swissSURFACE3D minus swissALTI3D) and the buildings (swissBUILDINGS3D)
- [ ] T4 The camping, the beach and the landmarks by hand
- [ ] T5 The ten checks of the template

### E04.S04 · Brouwersdam
Status: todo | Size: XL | Owner: Max | Milestone: M10 | Needs: E04.S01, E04.S02, E02.S04, E02.S05 | Roadmap: MA7
Done when: the ten checks pass. The first sea spot and the pipeline's proof: the Grevelingen side (flat, lake-like) and the North Sea side (waves, tides, the shore break), the dam, the beach by the Brouwersdam surf centres, a south-wester of 20 kt.
- [ ] T1 Dossier
- [ ] T2 Data (AHN4 lidar, Rijkswaterstaat depths of the Grevelingen and the Voordelta, PDOK aerial photos, BAG buildings, KNMI station)
- [ ] T3 Terrain and water
- [ ] T4 Wind
- [ ] T5 Waves, tides on the sea side
- [ ] T6 Beach
- [ ] T7 Courses (the Dutch slalom events' courses)
- [ ] T8 Look
- [ ] T9 AI and fps
- [ ] T10 Check
Notes: the lead's suggestion for the first sea spot (its data is the best anywhere, and it is home water); Max, 6 November 2026: no set order.

### E04.S05 · Lago di Santa Croce
Status: todo | Size: L | Owner: Max | Milestone: M10 | Needs: E04.S02 | Roadmap: MA7
Done when: the ten checks pass. A thermal-wind lake like Silvaplana, with Max's own station scrape as the wind's source.
- [ ] T1 Dossier
- [ ] T2 Data (TINITALY or the Veneto lidar, a lake survey if any, the regional orthophoto, the ARPAV stations and vetercek from `santa-croce-wind`)
- [ ] T3 Terrain and water
- [ ] T4 Wind
- [ ] T5 Waves
- [ ] T6 Beach
- [ ] T7 Courses
- [ ] T8 Look
- [ ] T9 AI and fps
- [ ] T10 Check

### E04.S06 · Lake Garda, Malcesine
Status: todo | Size: XL | Owner: Max | Milestone: M10 | Needs: E04.S02, E03.S02 | Roadmap: MA7
Done when: the ten checks pass. The Ora from the south in the afternoon and the Pelèr from the north in the morning, the long lake between the mountains, Malcesine's castle as the landmark, the slalom venues.
- [ ] T1 Dossier
- [ ] T2 Data (Italian lidar, the lake's depth chart, orthophotos)
- [ ] T3 Terrain and water
- [ ] T4 Wind (two systems in one day)
- [ ] T5 Waves
- [ ] T6 Beach
- [ ] T7 Courses
- [ ] T8 Look
- [ ] T9 AI and fps
- [ ] T10 Check

### E04.S07 · Gruissan
Status: todo | Size: XL | Owner: Max | Milestone: M10 | Needs: E04.S02, E11.S05 | Roadmap: MA7
Done when: the ten checks pass. The Tramontane along the beach, the Défi Wind's long-distance course (E11.S05), the flat-ish water near the beach and the chop further out.
- [ ] T1 Dossier
- [ ] T2 Data (IGN RGE Alti, SHOM or EMODnet bathymetry, IGN orthophotos, Météo-France)
- [ ] T3 Terrain and water
- [ ] T4 Wind
- [ ] T5 Waves
- [ ] T6 Beach
- [ ] T7 Courses (the Défi's 40 km)
- [ ] T8 Look
- [ ] T9 AI and fps
- [ ] T10 Check

### E04.S08 · Bol, Brač
Status: todo | Size: L | Owner: Max | Milestone: M10 | Needs: E04.S02 | Roadmap: MA7
Done when: the ten checks pass. The Maestral through the channel between Brač and Hvar in the afternoon, the Zlatni Rat beach.
- [ ] T1 Dossier
- [ ] T2 Data (Croatian DGU DEM and orthophotos, EMODnet bathymetry, DHMZ station)
- [ ] T3 Terrain and water
- [ ] T4 Wind
- [ ] T5 Waves
- [ ] T6 Beach
- [ ] T7 Courses
- [ ] T8 Look
- [ ] T9 AI and fps
- [ ] T10 Check

### E04.S09 · Alaçatı
Status: todo | Size: L | Owner: Max | Milestone: M10 | Needs: E04.S02 | Roadmap: MA7
Done when: the ten checks pass. The flat, shallow bay with the afternoon thermal, the PWA slalom venue.
- [ ] T1 Dossier
- [ ] T2 Data (Copernicus DEM, EMODnet, Sentinel-2 or a commercial photo, a local station)
- [ ] T3 Terrain and water
- [ ] T4 Wind
- [ ] T5 Waves
- [ ] T6 Beach
- [ ] T7 Courses
- [ ] T8 Look
- [ ] T9 AI and fps
- [ ] T10 Check

### E04.S10 · Bonaire, Lac Bay
Status: todo | Size: L | Owner: Max | Milestone: M10 | Needs: E04.S02 | Roadmap: MA7
Done when: the ten checks pass. The trade wind over a shallow turquoise lagoon behind the reef, Sorobon beach.
- [ ] T1 Dossier
- [ ] T2 Data (a Dutch Caribbean DEM, the lagoon's depths, orthophotos, the airport station)
- [ ] T3 Terrain and water
- [ ] T4 Wind
- [ ] T5 Waves (flat inside, the reef's break outside)
- [ ] T6 Beach
- [ ] T7 Courses
- [ ] T8 Look (the bottom through the water)
- [ ] T9 AI and fps
- [ ] T10 Check

### E04.S11 · Pozo Izquierdo
Status: todo | Size: XL | Owner: Max | Milestone: M10 | Needs: E04.S02, E02.S04, E02.S06 | Roadmap: MA7
Done when: the ten checks pass. The strong trade wind accelerated by the island, the swell and the shore break on a pebble beach, the PWA venue.
- [ ] T1 Dossier
- [ ] T2 Data (PNOA lidar and orthophotos, the Spanish hydrographic depths, AEMET)
- [ ] T3 Terrain and water
- [ ] T4 Wind
- [ ] T5 Waves (SWAN, the shore break)
- [ ] T6 Beach
- [ ] T7 Courses
- [ ] T8 Look
- [ ] T9 AI and fps
- [ ] T10 Check

### E04.S12 · Fuerteventura, Sotavento
Status: todo | Size: XL | Owner: Max | Milestone: M10 | Needs: E04.S02, E02.S05 | Roadmap: MA7
Done when: the ten checks pass. The trade wind, the lagoon that fills at high tide and the open sea outside, the PWA slalom venue.
- [ ] T1 Dossier
- [ ] T2 Data
- [ ] T3 Terrain and water
- [ ] T4 Wind
- [ ] T5 Waves and tides
- [ ] T6 Beach
- [ ] T7 Courses
- [ ] T8 Look
- [ ] T9 AI and fps
- [ ] T10 Check

### E04.S13 · The Columbia River Gorge, Hood River
Status: todo | Size: XL | Owner: Max | Milestone: M10 | Needs: E04.S02, E02.S05 | Roadmap: MA7
Done when: the ten checks pass. The funnel wind up the river against the current, the swell the wind builds against it, the sandbar.
- [ ] T1 Dossier
- [ ] T2 Data (USGS 3DEP lidar, NOAA river charts, NAIP photos, the Hood River station)
- [ ] T3 Terrain and water
- [ ] T4 Wind
- [ ] T5 Waves and the river's current
- [ ] T6 Beach
- [ ] T7 Courses
- [ ] T8 Look
- [ ] T9 AI and fps
- [ ] T10 Check

### E04.S14 · Lüderitz
Status: todo | Size: L | Owner: Max | Milestone: M10 | Needs: E04.S02, E07.S10 | Roadmap: MA7
Done when: the ten checks pass. The speed canal and the bay, the strong funnel wind over the desert, the 500 m speed run (E07.S10).
- [ ] T1 Dossier
- [ ] T2 Data (Copernicus DEM, Sentinel-2, the canal's own survey if published)
- [ ] T3 Terrain and water
- [ ] T4 Wind
- [ ] T5 Waves (flat in the canal)
- [ ] T6 Beach
- [ ] T7 Courses (the speed course)
- [ ] T8 Look
- [ ] T9 AI and fps
- [ ] T10 Check

### E04.S15 · Japan (the spot from Q12)
Status: todo | Size: XL | Owner: Max | Milestone: M10 | Needs: Q12, E04.S02 | Roadmap: MA7
Done when: the ten checks pass at the chosen venue.
- [ ] T1 Dossier
- [ ] T2 Data (GSI 5 m DEM, the hydrographic depths, GSI orthophotos)
- [ ] T3 Terrain and water
- [ ] T4 Wind
- [ ] T5 Waves
- [ ] T6 Beach
- [ ] T7 Courses
- [ ] T8 Look
- [ ] T9 AI and fps
- [ ] T10 Check

### E04.S16 · The regional assets library
Status: todo | Size: L | Owner: Max (Blender), an agent | Milestone: M10 | Needs: E05.S01 | Roadmap: MA3, GR5
Done when: a shared library of props exists to dress any spot: trees by climate (alpine, Mediterranean, palm, desert scrub), building styles (alpine, Mediterranean, Dutch, Caribbean), vans and cars, boats, flags, fences, beach furniture, the race office, with a placement tool from OpenStreetMap and by hand.
- [ ] T1 The list per spot from the dossiers; what OSM gives (footprints, roads) and what is by hand
- [ ] T2 The Blender library (`Art/` is empty today; the sources are committed through LFS)
- [ ] T3 The placement tool (`tools/map/props.py` from OSM, a scene editor for the hand-placed)
- [ ] T4 The frame budget for props at 60 fps with a fleet

### E04.S17 · The download with thirteen spots
Status: todo | Size: M | Owner: the lead | Milestone: M11 | Needs: E04.S02 | Roadmap: TE3
Done when: the game's size with every spot stays within the budget (E17.S03 decides it: one download, or a base plus spot packs), with lower-resolution far tiles and photos only where the camera can see them.
- [ ] T1 The size per spot measured on the first three
- [ ] T2 Far tiles and photos reduced; the near band kept sharp
- [ ] T3 Spot packs downloaded or installed separately if the total passes the budget
