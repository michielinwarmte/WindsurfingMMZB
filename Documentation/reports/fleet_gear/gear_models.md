# The gear models: the brands' boards, sails and fins in 3D (31 October 2026)

Part 4 of [the fleet's training and the gear](PLAN.md), by the shaper agent on the branch `gear/models`. Michiel (31 October 2026): "start shaping and colouring different boards and sails after the brands' designs, shapes and sizes", for the gear page. The brands are the game's own (Tripletone, Savanna, Point.9, Moonboard, NielsTrots, PJ New Sealand, BMX Boards, SouthSails, s3kauai, Forbidden, GG Sails, and Montag for the fins); this document names the real gear each item is modelled on, the game's files never do.

## In short

- **63 items**, each with its own 3D model and pictures: **22 boards** (three slalom sizes and one free race board per board brand, two free race boards for Savanna), **36 sails** (four slalom sizes and one free race sail per sail brand, and the default 8.0 as Savanna's), **5 fins** (34, 38, 40, 42 and 46 cm, Montag's).
- **Every number from the research** (`brand_research.md` section 3): the table `tools/blender/gear_set.py` applies section 3.1's rules to the brands' published numbers, the same way the research's scripts did, and its results equal section 3's tables (checked line by line; the four exceptions are listed below).
- **Shapes and liveries per brand**: each brand has its own outline, cut-outs, bottom vee, deck pads and print layout on the boards, and its own outline, batten layout, sleeve, windows and print layout on the sails (section 2's "what makes the shapes recognisable" and section 4's notes). Every sail's outline has its configured area within 1 %.
- **The folder `Game/assets/models/gear/` is 17.0 MB** (the budget was 25 MB).
- **The default rig is untouched**: `build_rig_models.py` is not changed (it already had its `__main__` guard); rebuilt after this work it gives the same eight files bit for bit as before.
- **Checks**: a new unit test (`test_gear_models.gd`, 8 tests, 5,727 asserts) and `tools/check.sh` are green; the full `tools/test.sh` is green (630 of 630). Contact sheets of every brand are in `.screenshots/gear/`.

## What was built, and how it fits the game

| What | Where |
|---|---|
| The gear table: one record per item (brand, line, model name, size, every config number, the fin, the shape and the livery style), the real model in a comment beside it | `tools/blender/gear_set.py` (plain Python; `python3 tools/blender/gear_set.py` prints it, `--json <file>` writes it) |
| The model builder | `tools/blender/build_gear_models.py` (Blender) |
| The liveries (the pictures) | `tools/blender/gear_liveries.py` (Blender) |
| The models and pictures | `Game/assets/models/gear/<brand slug>/<item id>.glb`, `<item id>_deck.png`, `<item id>_bottom.png` (boards), `<item id>_panels.png` (sails); the fins in `Game/assets/models/gear/montag/` |
| The table as built, with each item's files and the numbers the models fix | `Game/assets/models/gear/gear_set.json` |
| The view for contact sheets | `Game/dev/gear_view.tscn` (+ `gear_view.gd`) |
| The contact sheets | `tools/gear/contact_sheets.sh` |
| The test | `Game/tests/unit/test_gear_models.gd` |

The item ids are `<brand slug>_<line>_<size>`: a board's litres (`moonboard_slalom_111`), a sail's square metres with the tenths after an underscore (`point9_slalom_7_8`), a fin's centimetres (`montag_slalom_40`), as the gear page's `GearItem.id()` makes them.

**The models are built like the default ones.** The builder imports `build_rig_models.py` as a library: that file keeps the default board's and sail's numbers in module-level names (read from `Game/config/` when it loads), and its functions read them there. The builder puts one item's numbers in those names (with the module's own formulas), checks once at the start that the default board's and sail's numbers put in this way give exactly the module's own, and then calls the module's functions: the hull's cross-sections, the rails, the rocker with JP's traced nose, the pads, the fin box, the mast track, the fin, the sail's outline and its grid along the battens, the clew ring and the tack fairing. So every part has the same node and material names, origin and axes as the default part (`build_rig_models.py`'s header), and `RigVisuals` places it as it is: a board's origin is its middle at mid-thickness, a sail's is the mast foot with its clew at `(boom_m, boom_height_m)` and its head 2 cm under the mast top, a fin's is its root. What the default rig does not have is written in the builder: each brand's outline (drawn through the board's own tail, nose and widest point from `BoardConfig`), two-step cut-outs, the bottom's vee and double concave (the centreline stays where the physics has the bottom; only the edges rise), the pad layouts, the batten layouts (seven, raked seven, or six), the sleeve's width by the cams, the windows, and a second clew eyelet.

**What the models fix for the catalogue.** Two numbers belong to the board but live in other configs in the game: the mast foot (`SailConfig.mast_foot_local`: on the deck, 2 cm ahead of the mast track's back end, section 3.1 rule 12) and the fin's root (`FinConfig.root_local`: 0.18 m from the tail, 5 mm up in the bottom, rule 11). The builder works their heights out from the hull and writes both into `gear_set.json` (`mast_foot_local`, `fin_root_local`). For the PJ 117 (the default board) they come out exactly as `sail_default.tres` and `fin_default.tres` have them (0, 0.081, -0.125 and 0, -0.06, 0.96).

**Masts and booms.** The gear page's `RigVisuals` (branch `gear/page`) stretches the default mast to the sail's `mast_m` and the default boom to its `boom_m`; the sails here are built for exactly their own numbers, so it needs no mast or boom per sail, and none were built (the gear view does the same stretch).

## The set

The real gear named here is only in this document and in comments in `gear_set.py`. Sizes: the brands' real sizes nearest to the lead's targets (boards about 95, 112 and 127 L and a free race board of about 115 L; sails about 6.2, 7.0, 7.8 and 8.6 m², and about 7.0 m² free race). Ties went to the bigger size, unless that would have given a brand two nearly equal sizes. The model names are section 3.7's suggestions where they pass the name test; four were changed (below).

### Boards

The fin each board gets is the width rule of section 1.4 (span = 0.30 + 0.64 × (width − 0.60) m), rounded to the nearest of Montag's five fins.

| Brand | Item | Model name | Modelled on | Fin |
|---|---|---|---|---|
| Moonboard | moonboard_slalom_98, _111, _129 | uSonic | Starboard iSonic 63, 67, 77 (2026, Carbon Reflex) | 34, 34, 40 |
| | moonboard_freerace_120 | Orbit | Starboard Futura 120 (2026, Wood Sandwich) | 40 |
| PJ New Sealand | pj_new_sealand_slalom_97, _117, _125 | Slalom T-SEC | JP Australia Slalom S-TEC 62.5 (2026), SL 72 (2025, the default board), 76 (2026) | 34, 38, 40 |
| | pj_new_sealand_freerace_111 | Hyper Sport | JP Super Sport 111 (2026, Wood Pro) | 38 |
| Tripletone | tripletone_slalom_98, _111, _129 | Hawk_Fin | Duotone Falcon_Fin SLS 98, 111, 129 (2026) | 34, 34, 42 |
| | tripletone_freerace_116 | Thunder | Duotone Blitz SLS 116 (2026) | 34 |
| BMX Boards | bmx_boards_slalom_98, _108, _128 | Invincible | FMX Invictus Pro 98, 108, 128 (2026) | 34, 38, 42 |
| | bmx_boards_freerace_118 | Invincible GTS | FMX Invictus GTR 118 (2026) | 38 |
| Forbidden | forbidden_slalom_96, _116, _122 | Stingray | Tabou Manta 61, 71, 77 (2026, Team) | 34, 38, 40 |
| | forbidden_freerace_113 | Missile+ | Tabou Rocket+ 113 (2026, LTD) | 38 |
| Savanna | savanna_freerace_105, _125 | Jackal | Severne Fox Pro 105, 125 (2026) | 34, 38 |

| Brand | The shape (section 2 and 4) | The livery |
|---|---|---|
| Moonboard | A square, wide outline with the widest point near the middle; two-step cut-aways with the small triangle between them painted on the bottom; a flat vee to double concave. The free race board's nose is a wider "spoon" | Midnight deck with a darker band ahead of the tail; two cream racing stripes from the nose, widening toward the mast track; a big yellow tail with the size in cream-outlined numbers; the crescent on a yellow tab on the nose's port side; the name along the deck ahead of the track; cream pads. Bottom: sky blue, yellow nose and tail and cut-out steps, the name along it |
| PJ New Sealand | JP's traced outline (the default board's) for the slalom boards, a parallel outline with a wider tail for the free race board; a double-step tail with the deck wide over it; a "transforming vee"; high rails; JP's pads and the wedge | White deck; the tail split teal (port) and fern green (starboard) as JP splits its tail; a pale recess round the mast track; "PJ" on the nose; the model's name and its numbers ("V117 L228 W72") on the tail; the name along the starboard rail; grey pads with green edges. Bottom: white, teal toward the tail and along the rails, green steps |
| Tripletone | Compact and parallel with a wide, square tail and two big steps; a flatter deck; the free race board narrower with more vee and one small step | Carbon with aqua veins along the board; the tail in the mark's three teal tones, stepped like pixels; white diamonds under the front straps and one black wedge across the tail; the three-tone mark on the nose; the name ahead of the track; "Hawk_Fin" beside it. Bottom: royal blue, the name along it, aqua steps |
| BMX Boards | The longest outline (2.33 m), a wide nose, a long parallel middle, a curved tail; one long cut-out drawn as a removable plate; vee and double concave in the nose, an inverse vee in the tail; a flat deck | One bold yellow; a forward-pointing chevron of thin black lines meeting ahead of the mast track; a black arrow panel behind the track under the black front pads; the chainring on the nose; the name beside the track; "INVINCIBLE" and "233 - 63 - 98" on the tail; a red tail tip. Bottom: yellow, the chainring big at the nose, the name along it, the cut-out plates in black carbon with their screws |
| Forbidden | More curve in the outline, large two-step cut-outs, an extra tail vee and a deep front vee, rails tucked under in the tail; the free race board rounder on the deck | Signal red, deeper crimson across the middle; black hexagon pads framed in bone; bone hexagon outlines round the no-entry mark on the nose and between the front straps; "STINGRAY 116" by the port rail. Bottom: black, the name big near the nose, bone steps and hexagons |
| Savanna | The longest boards (2.39 and 2.44 m), a tapered nose, a narrow tail, a pronounced vee, medium cut-outs | Terracotta with darker veins; "JACKAL" in big outlined gold letters along the deck ahead of the mast track; the sun-and-acacia mark on a brown tab on the nose's port side; an acacia-brown tail with the size in gold. Bottom: brown with a striped gold chevron on the nose, the name along it, terracotta steps |

### Sails

The battens: seven on every sail except SouthSails' free race sail (six, as the real Free Speed). The cams set how far down the luff sleeve is deep (it is wide behind the cammed battens and narrows above); the free race sleeves are narrower, Point.9's race sleeve the widest ("XXL"), SouthSails' air-cam sleeve as wide all the way up.

| Brand | Item | Model name | Modelled on |
|---|---|---|---|
| Tripletone | tripletone_slalom_6_2, _6_7, _7_7, _8_5 | Weft_Fin | Duotone Warp_Fin 6.2, 6.7, 7.7, 8.5 (2026) |
| | tripletone_freerace_7_3 | T_Pace | Duotone S_Pace 7.3 (2026) |
| Savanna | savanna_slalom_5_5, _6_5, _7_5, _8_5 | Cheetah | Severne Mach 9 5.5, 6.5, 7.5, 8.5 (026): the brand makes only five race sizes |
| | savanna_slalom_8_0 | Cheetah | The default sail (the Severne HGO iQFOiL 8.0), its numbers kept exactly |
| | savanna_freerace_7_0 | Gazelle | Severne Overdrive M4 7.0 |
| Point.9 | point9_slalom_5_9, _6_8, _7_8, _8_8 | BC-1 | Point-7 AC-1 LTD 5.9, 6.8, 7.8 (026, stitched), 8.8 (025) |
| | point9_freerace_6_8 | BC-2 | Point-7 AC-2 6.8 |
| NielsTrots | nielstrots_slalom_6_5, _7_4, _8_2, _9_0 | RT:Racing | NeilPryde RS:Racing EVO XVII 6.5, 7.4, 8.2, 9.0 (2026) |
| | nielstrots_freerace_7_2 | V9 | NeilPryde V8 7.2 (2026) |
| SouthSails | southsails_slalom_6_0, _6_8, _7_7, _8_6 | Slalom Sprint | North Sails Slalom Race GEN3 6.0, 6.8, 7.7 (2026), Slalom Race 8.6 (2025) |
| | southsails_freerace_7_7 | Free Sprint | North Sails Free Speed 7.7 (2024 test) |
| s3kauai | s3kauai_slalom_6_1, _6_7, _7_6, _9_0 | Viper | S2Maui Venom-XI 6.1, 6.7, 7.6, 9.0 (2026) |
| | s3kauai_freerace_7_0 | Wild | S2Maui Wicked 7.0 (2026) |
| GG Sails | gg_sails_slalom_5_7, _6_7, _7_7, _8_4 | Vapour | GA Sails Vapor 5.7, 6.7, 7.7, 8.4 (2026) |
| | gg_sails_freerace_7_2 | Cosmos | GA Sails Cosmic 7.2 (2026) |

| Brand | The shape | The livery |
|---|---|---|
| Tripletone | Tall and narrow, a large cutaway at the clew | An aqua sleeve, leech and foot edge; a carbon upper body with a staircase of square "pixels" in the mark's three tones; a white lower body with a big clear window; the name in tall letters down the leech; the model's name low by the leech, the size under the clew |
| Savanna | A race outline with a long, low, seamless foot | All terracotta (translucent), thin dark strips in the luff panel, dark battens; the name over the leech above the boom; the mark on a brown badge high by the luff; the size in huge outlined figures low in the sail with the model's name beside it; a narrow window by the luff |
| Point.9 | The widest race sleeve, the foot cut straight and low along the deck | Smoke black with two pearl blocks near the head and a pearl strip along the foot; a lime line along the luff panel, magenta batten caps; the name near the clew; a window low |
| NielsTrots | A high, narrow head, the battens raked to the sailing rake | Black; crimson rings like a target in the upper body, turning orange toward the boom; the name in big letters up the black luff panel from the boom; a clear window band under the boom with the model's name; an orange foot, clew and head with the size on the foot |
| SouthSails | A plain outline, the air-cam sleeve; six battens on the free race sail | One smooth navy membrane, no seams, lighter fibre lines fanning from the clew and the head; coral lines along the battens; the compass mark on a white disc high by the luff; the name across the upper sail, the model small in the middle; two white-framed windows in the lower panel |
| s3kauai | A classic race outline with two clew eyelets | Lagoon above, a jungle-green band carrying the name and a coral band round the boom; a white lower body with a clear window outlined in black; coral battens; the model's name across the bottom |
| GG Sails | A race outline with a big clew cut-out | Violet with a charcoal luff panel carrying the GG mark big under the head; seams radiating from the sail's middle; gold battens, gold tape along the leech and foot; a clear strip along the lower leech; the name down the leech; a white foot panel with the model's name and three colour bars |

Every sail carries the two race-number boxes of the default sail (port and starboard side, "MMZB"), in the brand's contrast colour, as section 4 asks.

### Fins

`montag_slalom_34`, `_38`, `_40`, `_42`, `_46`: the default fin's planform (a tip chord of 0.37 of the root's, a rounded tip, a 10 % foil section) at the span and the area of Select's Rhino Pro of that length (267, 311, 333, 358, 405 cm²); the builder sets the root chord so the model's area is exactly the configured one. Plain black carbon, no brand print.

### Where the table differs from section 3

1. **PJ 117 (the default board) and the 8.0 (the default sail)** keep `board_default.tres`'s and `sail_default.tres`'s numbers exactly (section 3 gives the PJ 72 a nose of 0.562 m by the rule; the default has 0.56).
2. **Three sails are not in section 3's tables** but are the brand's real size nearest to a target: Point.9's 6.8 (AC-1 LTD 6.8: luff 464, boom 204, mast 430 + 36, 6.1 kg, section 2.3), s3kauai's 6.1 (Venom-XI 6.1: luff 434, boom 187, mast 430, 5.5 kg estimated) and the free race 7.0 (Wicked 7.0: luff 458, boom 204, mast 430, 4.6 kg estimated). Their numbers come from section 2 by the same rules.
3. **The fins**: each board gets the width rule's fin rounded to Montag's five sizes (the lead's brief), where section 3 gives some boards the fin their brand recommends; the boards' `mass_kg` stays section 3's (it includes section 3's fin; the difference is a few grams).
4. **Model names** changed from section 3.7 because they contain a real one: "Futurama" (Futura) is Moonboard's **Orbit**, "Mach 10" (Mach) is Savanna's **Cheetah**, "Bolt" (Goya's free race board) is Tripletone's **Thunder**, "Wolf" and "Underdrive" became **Jackal** and **Gazelle** to keep Savanna's animals together.
5. **The rig's mass**: `gear_set.py` holds both of section 3's columns for every sail (`rig_mass_kg` at the default's 9.5/12.4 ratio, `rig_mass_real_kg`); which one the game sails is Michiel's call (section 5, question 2).

## Choices made here, and why

- **Pictures per item, not per brand.** The brief asked for one deck, bottom and panels picture per brand to keep the folder small, and also for each board's model name and each sail's size to be printed. A sail's picture is read with the cloth's own UV, which also drives its shape in the shader, so one picture cannot show a different size on each sail. Since the pictures pack small (a board's deck about 60 KB, its bottom 25 KB, a sail's panels 150 KB, thanks to storing each row as its difference to the row above), each item has its own: the model name, the size and the board's dimensions are printed where the brand prints them, and every print sits exactly on its own outline. The whole folder is 17.0 MB. If the team prefers one set per brand, the builder can draw each brand's once on a middle size (without the sizes and names).
- **A gear view of its own instead of options in `rig_view.gd`.** The gear page's branch already gave the rig view `--gear_board=`, `--gear_sail=`, `--gear_fin=` (sailing the catalogue's items), which shows these models sailing once their catalogue entries exist. The contact sheets need something else: the gear still, through straight-on cameras, from above, below and both sides, and from below the water. So `Game/dev/gear_view.tscn` does that, and `rig_view.gd` is left as it is (no clash with the page's changes).
- **Prints low in the sail sit just above the lowest batten.** Under it the cloth's rows fan out from the tack (the default sail's layout, which the shader expects), so the picture has few pixels across the foot and a print there blurs. Model names and sizes go just above it, where the picture is sharp.
- **Each sail's outline is fitted to its configured area.** The brand's shape (how wide the head is, how long the foot) is scaled as a whole until the outline has the config's area, within 1 %. The foot's corner is kept 12 cm ahead of the clew and the roach small enough that the clew is the sail's aftmost point (a short-boom sail with a wide head would otherwise bulge behind it).
- **Text** is drawn with Inter, the open-licence font Blender ships for its own interface (found in Blender's data folder on any computer), so nobody needs a font installed to rebuild. The logos are the designer's PNGs, stamped in.
- **The models are lighter than the default ones**: 50 cross-sections of 40 points on the hull (the default has 120 of 48), lighter footstraps, 26 columns on the sail (40): a board is about 217 KB (the default's 440 KB), a sail 125 KB.

## How to rebuild

From the repository root:

```
tools/blender.sh tools/blender/build_gear_models.py                       # all 63 items, about 2 minutes
tools/blender.sh tools/blender/build_gear_models.py --brand=moonboard      # one brand
tools/blender.sh tools/blender/build_gear_models.py --only=sails          # boards, sails or fins
tools/blender.sh tools/blender/build_gear_models.py --item=point9_slalom_7_8
tools/check.sh                                                           # Godot imports the new files
tools/gear/contact_sheets.sh [--brand=<slug>] [--gamescope]              # the contact sheets
```

A new picture gets Godot import settings with mipmaps and graphics-card compression (a print shimmers at a distance without mipmaps); the builder writes them the first time and Godot fills in the rest. After changing a number or a name in `gear_set.py`, rebuild and run `tools/test.sh unit -gselect=gear_models`.

## The contact sheets

`tools/gear/contact_sheets.sh` writes (not committed):

- `.screenshots/gear/<brand slug>.png` for each of the eleven brands: its boards from above, from below and from the starboard side (the bow to the right), its sails from the port side (the prints read) and from the starboard side (the prints show mirrored, as through real cloth);
- `.screenshots/gear/all_boards.png` (every board from above and below) and `.screenshots/gear/all_sails.png` (every sail from the port side);
- the single pictures in `.screenshots/gear/views/`.

What the sheets showed and was fixed: pads drawn a metre behind the tail on the PJ boards (the module's wedge numbers were reset too early), BMX's and PJ's bottoms in the wrong colour (the black "BMX" and the teal "PJ" vanished), the race numbers too wide for the box on small sails, NielsTrots' name running under the number boxes, GG's mark too big for the narrow head, prints blurred in the foot, logos overlapping on the noses, the built-in font's "1" reading as an "I", and a free race sail whose foot reached behind its clew.

On this machine the screens were off during the work: a game window then gets no frames and the view waits for ever. `--gamescope` draws in a headless gamescope session instead (Linux); on a normal desktop the script runs without it.

## What could not be verified

- **How the gear looks in the game, sailing, at a distance and on the team's screens**: the sheets are still, straight-on, under one light. Whether each brand is recognisable at ten metres in the game's light and water, and how the colours come out on other screens, needs the team's eyes once the catalogue shows them in the game.
- **The prints from up close**: the pictures are 512 × 2048 (boards) and 1024 × 2048 (sails); small letters (the dimensions on PJ's tail, the model names on the sails) are sharp in the sheets but soft at the gear page's closest zoom, if it zooms in that far.
- **A race's sail colours on these sails.** The game's tint (`sail_colour` in `sail_cloth.gdshaderinc`) shades the race colour by the red channel of the cloth's own colour. That works for the default red sail, but darkens sails whose cloth has little red: s3kauai's lagoon and SouthSails' navy would turn almost black under a race colour, and the dark sails (Point.9, NielsTrots, Tripletone) stay dark whatever the colour. See the open questions.

## Open choices for the team

1. **A second colourway per brand** (brands.md lists one per brand, e.g. Tripletone's white cloth with a carbon print, BMX's black deck): the livery functions take the brand's colours, so a second colourway is a second palette and a line in the table.
2. **Sizes to add**: section 3 has more (24 slalom and 17 free race boards, 32 and 26 sails); each is one line in `gear_set.py`, about 0.4 MB per board and 0.3 MB per sail.
3. **The race tint on dark and blue sails** (above): shading by the cloth's brightest channel instead of its red one would leave the default sail exactly as it is and let every brand's sail take a race colour. A one-line change in `sail_cloth.gdshaderinc`, not made here (it is the race's look, not the gear's).
4. **One picture set per brand** instead of per item, if the folder must shrink further (about 4 MB less, without the sizes and model names printed).
5. **The model names** (section 3.7's, four changed) and Montag's fin name "Swift" are suggestions.
6. **Masts and booms of their own** per sail size, if the stretched default ones look wrong on the small sails (the stretch also stretches the extension and the rubber joint by up to 20 %).
