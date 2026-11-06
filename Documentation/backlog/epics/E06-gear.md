# E06 · The gear: the brands' ranges

Owner: the team's look (Max), Michiel for the physics numbers, the lead and agents for the build | Roadmap: GE1 to GE8, PH40, RA21, GR7 | Questions: Q17, Q18, Q19, Q20

**Goal.** The complete current slalom and free race range of the brands, every model with its real outline and graphics look-alike, every size with its real numbers in the physics, chosen in the hut, sailed by the player and the AI, and measured by polars.

**Done when (1.0).** Every brand on the agreed list (Q17) has every slalom and free race board and sail of the frozen model year as its own look (outline, rocker, deck and panel design close to the real one) and as numbers per size; masts, booms and fins per brand; a polar per item (E01.S13); the AI picks its gear for the course and the wind; the gear's condition and registration exist for the career (E14); the team has looked at every item in the game at sailing distance.

**Where things stand (6 November 2026).** Researched: eleven makers' 2025/2026 slalom and free race lines plus twelve more makers, every physics number and the rules for the unpublished ones (`Documentation/reports/fleet_gear/brand_research.md`, about 150 sources). Built: seventeen made-up brands after the makers (no real name in `Game/`, pinned by tests): Tripletone (Duotone), Savanna (Severne), Point.9 (Point-7), Moonboard (Starboard), NielsTrots (NeilPryde), PJ New Sealand (JP), BMX Boards (FMX), SouthSails (North), s3kauai (S2Maui), Forbidden (Tabou), GG Sails (GA), Montag (Sonntag, fins), and the fin brands M Fins (Z), Start Fins (Finish), Blacksmith (Carpenter), Typhoon (Hurricane), NT8 (NP7); 22 boards (3 slalom and 1 free race per board brand), 36 sails (4 and 1 per sail brand), a slalom fin per fin brand at any depth from 28 to 52 cm; one Blender table builds every model with a shape and a livery per brand (17 MB); the Gear page with a turning 3D preview; the AI personas on their own brand's gear sized for the wind. Only the JP board's outline is traced from photos; every other outline is drawn from rules; one colourway per brand; masts and booms are the default ones stretched; the research's full set is 24 slalom and 17 free race boards and 32 and 26 sails. Max's own board (Patrik) and the other twelve makers are not built.

## Stories

### E06.S01 · The team's look at the brands and the models as they are
Status: review | Size: S | Owner: Max, Michiel | Milestone: M1 | Needs: the night3 build | Roadmap: GE2, GE3, GE4, GE8
Done when: the team has opened the Gear page and sailed a few items and answered: the brands' names and logos (Montag stays?), the model names that sit close to real ones ("uSonic", "SLALOM T-SEC", "ST.RACING", "Stingray"), the fin brands' look and the slider, the Gear page on the pause menu, the race tint on dark sails.
- [ ] T1 The eleven open questions of `brand_research.md` section 5 and the eight open choices of `gear_models.md` answered
- [ ] T2 The race tint shader fix (shade by the brightest channel, one line in `sail_cloth.gdshaderinc`)
- [ ] T3 The fin brands' colours and wind ranges on the cards (GE8's open points)

### E06.S02 · The brand and model list frozen
Status: todo | Size: S | Owner: Max, Michiel | Milestone: M5 | Needs: Q17 | Roadmap: GE1
Done when: `Documentation/reports/fleet_gear/RANGE_1.0.md` lists every brand, model and size that 1.0 ships, the model year, and what is left out (speed and storm sizes, foil gear), signed off by the team.
- [ ] T1 The makers chosen (the eleven, plus or minus; Patrik for Max?)
- [ ] T2 The model year frozen (2026) and the source per model (the makers' published tables)
- [ ] T3 The list counted (boards, sails, fins, masts, booms) and the build effort estimated

### E06.S03 · Real-like looks: every model traced
Status: todo | Size: L | Owner: an agent per brand, Max's eye | Milestone: M5 | Needs: E06.S02 | Roadmap: GE3
Done when: each board model has its outline, rocker, deck shape, cut-outs, pads and strap positions traced from the maker's photos and specs, and each sail model its panel layout, window shapes, batten count and graphics look-alike, built by the Blender builder per model (not per brand), with a second colourway where the real line has one.
- [ ] T1 The builder takes a per-model shape (today `BOARD_SHAPES` and `SAIL_SHAPES` are per brand)
- [ ] T2 A tracing workflow: the maker's top and side photos scaled by the published length and width; `tools/blender/trace_outline.py`
- [ ] T3 Boards traced, one brand at a time; sails drawn, one brand at a time (an agent per brand, three at a time)
- [ ] T4 Contact sheets per brand checked by Max at sailing distance and in the hut
- [ ] T5 The real names stay out of `Game/` (the tests); the look-alike rule written for the legal check (E18.S05)
Notes: Q18 answered 6 November 2026: the made-up names stay, the designs follow the real ones closely; asking the makers (E06.S09) is optional and later.

### E06.S04 · Every size as numbers
Status: todo | Size: M | Owner: the lead, Michiel | Milestone: M5 | Needs: E06.S02 | Roadmap: GE1, PH40, PH33
Done when: every size of every model has its physics numbers from the maker's published table (length, width, tail width, volume, weight, fin box, straps, mast track; luff, boom, mast, battens, cams, weight), masts and booms per sail size, and the rig's mass follows; the 3D shape is scaled per size by the builder.
- [ ] T1 The published tables into `tools/blender/gear_set.py` (or a CSV it reads), with the source per row
- [ ] T2 Masts (length, IMCS, carbon share) and booms (length range, weight) per sail size
- [ ] T3 The mast foot and the fin root read from the board (E01.S11)
- [ ] T4 The catalogue rebuilt; the Gear page's cards show the real size range and the wind range

### E06.S05 · The fins
Status: todo | Size: M | Owner: the lead, Michiel for the stiffness | Milestone: M5 | Needs: E01.S01 T4 | Roadmap: GE8
Done when: each fin brand has its own planform and mark, the race fins' stiffness matches a measured fin per material (G10 free race fins softer), the slider keeps working, and a fin's wind range and the board's recommended depth are right.
- [ ] T1 Planforms per brand (traced from the makers' photos), a mark on the fin (needs UVs)
- [ ] T2 The stiffness per material and depth from the measured test fin (Michiel's data-only fix)
- [ ] T3 Weed and freeride fins? (out of scope unless Q17 says so)

### E06.S06 · The gear page v2 and the hut's panel
Status: todo | Size: M | Owner: the lead | Milestone: M4 | Needs: E05.S03 | Roadmap: GE4
Done when: the gear UI (the page and the hut) lets the player compare items, filter by wind range and sailor weight, see the polar, build a quiver (the career), and see the item turn in the hut's light.
- [ ] T1 Compare two items side by side; the wind range per sailor weight
- [ ] T2 The quiver: the items the player owns (free sailing: everything; career: what is bought)
- [ ] T3 The 3D preview in the hut with the real-like look

### E06.S07 · The AI picks its gear for the course and the wind
Status: todo | Size: M | Owner: the lead | Milestone: M5 | Needs: E01.S13 | Roadmap: GE7, RA21, RA8
Done when: each AI character chooses, from its own brand, the combination the polars say is fastest for the course and the day's wind, with its persona's preference and a rookie's worse judgement, and the skipper times its legs with its own gear's polar.
- [ ] T1 The polar table per item (E01.S13) read by `Persona.gear_for()`
- [ ] T2 The skipper's polar per board and sail (RA21)
- [ ] T3 The choice shown on the beach racks and in the results

### E06.S08 · Condition, registration and the quiver for the career
Status: todo | Size: M | Owner: the lead, Max for the rules | Milestone: M8 | Needs: E14.S01, Q9 | Roadmap: —
Done when: gear has a condition that wears with use and falls (and damage, if Q9 c), can be repaired at a cost, and the career registers a limited quiver per event as the PWA does.
- [ ] T1 Condition per item (wear by hours, by catapults; a broken fin on a grounding)
- [ ] T2 The quiver rule per event (the registered sails and boards) and the penalty for sailing unregistered gear
- [ ] T3 Repair and replacement at the hut; the costs in E14

### E06.S09 · Ask the makers
Status: todo | Size: S | Owner: Max | Milestone: M7 | Needs: Q18, E06.S03 | Roadmap: GE2
Done when: each maker on the list has been sent a letter with screenshots asking for permission to use the real names and logos in a small game, and the answers are recorded; a yes replaces the made-up name for that brand.
- [ ] T1 The letter and the screenshots (the brand's gear at sailing distance and in the hut)
- [ ] T2 The answers; the brand resources switched where allowed

### E06.S10 · The fleet's gear seen
Status: todo | Size: M | Owner: the lead | Milestone: M6 | Needs: E06.S03, E10.S04 | Roadmap: GR7
Done when: in a race the other boards' sails show their brand, size, number and colour at sailing distance, with the LOD budget of a 32-board fleet kept.
- [ ] T1 Sail numbers and national letters on the sails (the characters' countries)
- [ ] T2 The LOD per distance (the draw distance setting's bands) measured with 32 boards
- [ ] T3 The team's look at the fleet from the follow camera
