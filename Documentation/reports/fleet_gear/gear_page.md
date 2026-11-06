# The gear page (31 October 2026)

Part 5 of [the fleet's training and the gear](PLAN.md), by the builder agent on the branch `gear/page`. Michiel asked for a page in the game where you choose the boards, sails and fins of the game's own brands, and then sail them. This part builds the plumbing and the page with **placeholder gear**: fifteen items that sail the numbers the game already had. The researcher (part 2) finds the real gear's sizes, and the shaper (part 4) builds the 3D models and paints them. After that, the shaper only has to add files. No code changes are needed (see "How to add an item").

## What was built

- **A catalogue of gear.** Each board, sail or fin is one small file (a `GearItem`). It holds the brand, a made-up model name, the line (slalom or free race), the size, the wind range, one line of text for its card, the numbers the physics sails, and optionally its own 3D model and pictures. The game finds the files by itself (`GearCatalogue`).
- **The choice is kept in the settings** (`user://settings.cfg`, section `[gear]`: `board`, `sail`, `fin`, each an item's id). An id the game doesn't know sails the default item.
- **The chosen gear is what you sail.** When the sailing scene starts (the open water, the lake, a race), the player's board is built from copies of the chosen items' numbers. The 3D board and rig use the items' models, pictures and sail colour. The AI fleet keeps the default gear (RA8 is for later).
- **The default gear is the game's gear from before**: the board, the 8.0 and the fin of `Game/config/`. A player who never opens the page sails exactly what they sailed before. A test checks this number for number, and also that two boards sailed side by side for 2 s end up in the same place to the last bit.
- **The page.** A **Gear** button on the start menu's main page (next to Settings, Controls, How to sail and Quit) opens it. There are three tabs, **Board**, **Sail** and **Fin**. Each tab has:
  - the brands as cards: the mark, the name, the tagline, and a stripe in the brand's two colours;
  - the chosen brand's logo, name and tagline;
  - its models as cards: the name and size, the line, the wind range and a line about it.

  The chosen model is lit orange and kept at once. On the right, a 3D preview turns slowly:
  - on the Sail tab, the whole rig as it sails;
  - on the Board tab, the board alone, standing on its tail the way shops show boards;
  - on the Fin tab, the board upside down, turning about its fin.

  Under the preview are the item's main numbers. At the top, "You sail:" names all three choices.
- **The F1 panel** names the chosen gear in one line, above the line with the numbers the simulation sails. The game also prints both lines when it starts.
- **Different sizes look right.** The default 3D models were built for the default board and the 8.0. For another size they are now stretched to the size the physics sails:
  - The board is stretched to its length, width and thickness.
  - The sail is stretched along the boom by the boom's length. Up the mast it is fitted so the clew sits at the end of the boom and the head just under the mast top. The foot moves up a little to make that work.
  - The mast is stretched to the mast's length, and the boom to the boom's length.

  This is a first approximation: a 6.5 is not just a small copy of an 8.0. The shaper will build a true model per size, and an item with its own model is not stretched.
- **Measuring tools.**
  - `tools/push_check.sh` takes `--gear_board=<id>`, `--gear_sail=<id>` and `--gear_fin=<id>`. The measurement below uses them.
  - The rig view (`Game/dev/rig_view.tscn`) takes the same options, to look at a model from eleven cameras.

## How it is wired

| Step | Where |
|---|---|
| The items | `Game/gear/boards/`, `Game/gear/sails/`, `Game/gear/fins/` (one `.tres` each), class `GearItem` in `Game/gear/gear_item.gd` |
| Listing and finding them | `GearCatalogue` in `Game/gear/catalogue.gd`: `boards()`, `sails()`, `fins()`, `find(id)`, `by_brand(brand, kind)`, `brands_of(kind)`, `default_board()`/`default_sail()`/`default_fin()`. It reads the folders when asked (`ResourceLoader.list_directory`, which also works in an exported game) |
| The choice of three | `GearChoice` in `Game/gear/gear_choice.gd`: `from_settings()`, `from_ids()` (an unknown id gives the default), `names_line()`, and `sim_with(base)` |
| The settings | `SettingsValues.gear_board`, `gear_sail`, `gear_fin` (`Game/ui/settings_values.gd`), section `[gear]` |
| The sailing scene | `main.gd` `_enter_tree()` sets `windsurfer.gear = GearChoice.from_settings(...)`. The lake's scene runs the same code (`sail_silvaplana.gd` calls `super()`) |
| The player's simulation | `WindsurferNode._ready()` (`Game/windsurfer/windsurfer.gd`): first `WindsurferSim.create_for(...)` as before, then `gear.sim_with(sim)`. This builds a new `WindsurferSim` from copies of the chosen board, sail and fin configs, with everything else (the air, the water, the wind field, the waves, the sailor) taken from the first one. Nothing in `Game/sim/` changed |
| The 3D board and rig | `RigVisuals.build(board, sail, fin, gear)` (`Game/windsurfer/rig_visuals.gd`). It uses an item's own model, deck and bottom pictures and sail panels when it has them, and colours the sail's cloth. Otherwise it uses the default models, stretched (`board_stretch()`, `fit_sail()`) |
| The page | `Game/ui/gear_page.gd` and `.tscn` (a `MenuPage`). `Game/ui/start_menu.gd` and `.tscn` add the Gear button, the page and `--page=gear/<tab>`. When the page closes with other gear chosen, the start menu builds the sailing scene behind it again, so the next run on the open water sails the new gear |
| The tests | `Game/tests/unit/test_gear.gd` (22 tests) |

## How to add an item (for the shaper)

1. **Make the file.** Copy a file from the right folder and name it after its id: `<brand slug>_<line>_<size>.tres`. The line is `slalom` or `freerace`. The size is the gear's own size:
   - a board's litres as a whole number (`moonboard_slalom_105.tres`);
   - a sail's square metres with the tenths after an underscore (`point9_slalom_7_8.tres`);
   - a fin's depth in centimetres (`pj_new_sealand_slalom_42.tres`).

   A test fails if the file's name is not the id, or if two items share an id.

   **A fin is different (6 November 2026, [fin_brands.md](fin_brands.md)).** A fin brand has one file, its fin at 38 cm (`<brand slug>_slalom_38.tres`), and the player sets any depth from 28 to 52 cm with the Fin tab's slider. The game makes the other depths from the 38 cm file when they are first asked for (`GearCatalogue.fin_of()`): the same fin with that depth's `span_m`, the area of a race fin of that depth (`Game/gear/fin_sizes.tres`, times the 38 cm file's own share of the race fin's area: 1 unless its area is not a race fin's), that depth's wind range and card line, and the 38 cm file's model stretched to the depth and the chord. So a **new fin brand** is: the brand (its `.tres` in `Game/gear/brands/` with `makes_fins = true`, its logos, its path in `Brand.PATHS`), and one fin file at 38 cm, copied from `m_fins_slalom_38.tres` with the brand, the `model_name` and the looks changed (`fin_colour`: the body, fully transparent for the model's carbon; `fin_tip_colour` and `fin_tip_share`: the coloured tip). Montag's five sizes (34, 38, 40, 42, 46) keep their own files and models; a file at another depth would be used in place of the made one (keep its numbers those of `fin_sizes.tres`, or the slider jumps there).
2. **Fill in the fields:**

   | Field | What |
   |---|---|
   | `kind` | 0 board, 1 sail, 2 fin (it must match the folder) |
   | `brand` | the brand's `.tres` in `Game/gear/brands/` |
   | `model_name` | made up, without the size: "Crescent". Never a real product's name. A test checks the real makers' names (the list in `test_brands.gd`) |
   | `line` | 0 slalom, 1 free race |
   | `size` | litres, m² or cm as above. A test checks it against the config: a board's `volume_m3` x 1000, a sail's `area_m2`, a fin's `span_m` x 100 |
   | `description` | one line for the card, about 90 characters at most (three lines on the card) |
   | `wind_from_kt`, `wind_to_kt` | the wind range on the card |
   | `config` | the numbers the physics sails: a `BoardConfig`, `SailConfig` or `FinConfig`. Either a file in `Game/config/` (`[ext_resource ... path="res://config/sail_7_8.tres"]`) or the numbers written inside the item's file as a sub-resource. The game always sails a copy, so a run never changes the catalogue |
   | `model` | the part's `.glb` (null: the default model, stretched to the config's size) |
   | `deck`, `bottom` | a board's pictures in the hull's UV, like `board_deck.png` and `board_bottom.png` (null: the default pictures) |
   | `panels` | a sail's panel picture in the sail's UV, with the alpha code of `sail_panels.png` (null: the default picture) |
   | `cloth` | a sail's cloth colour. It replaces the red cloth (alpha 1) of the panel picture. Leave it fully transparent for the brand's primary colour; white keeps the picture's own colours |
   | `fin_colour`, `fin_tip_colour`, `fin_tip_share` | a fin's body colour (fully transparent: the model's own), its tip's colour (fully transparent: none) and how much of the depth the tip's colour covers, from the tip up |

3. **The models.** Put them in `Game/assets/models/gear/<brand slug>/` (a suggestion; any path works). Build them the way `tools/blender/build_rig_models.py` builds the defaults, with the same node and material names, origins and axes:
   - A **board**: a mesh called `Hull` with the materials `board_deck` and `board_bottom`. Its origin is the board's centre at mid-thickness, and the bow points to -Z.
   - A **sail**: a mesh called `SailCloth` with the surfaces `sail_cloth`, `sail_window` and `sail_sleeve`. It needs the UV and UV2 the cloth shader reads (u along a batten, v up the luff, UV2.x the chord in metres). Its origin is the mast foot, with the luff up +Y and the clew at `(boom_m, boom_height_m, 0)` of its own config.
   - A **fin**: hanging down from its root at the origin, with the leading edge to -Z. It is stretched to `span_m` like the default fin, and along the board by its mean chord (`RigVisuals.fin_stretch()`: a fin made from a 38 cm file wears that file's model, built for the 38 cm fin).

   An item with its own model is drawn at its own size, not stretched. The mast and the boom are always the default models, stretched to the sail's `mast_m` and `boom_m`.
4. **Look at it.** Run `tools/screenshot.sh res://ui/start_menu.tscn .screenshots/gear_page.png 120 --page=gear/sail`, or look at the model from eleven cameras with `tools/screenshot.sh res://dev/rig_view.tscn .screenshots/rig/view.png 600 --gear_sail=<id>` (the pictures get `_gear` in their names). Then run `tools/check.sh` and `tools/test.sh unit -gselect=gear`.

The page lists a brand on a tab as soon as it has one item of that kind there (in the brands' order of `Brand.all()`). A brand's models are listed slalom first, each line from small to big.

The placeholder items (fifteen; "stand-in" ones say so on their card):

| Kind | Id | Model | Its numbers |
|---|---|---|---|
| board | `pj_new_sealand_slalom_117` (**default**) | Selkie | `board_default.tres` (2.28 x 0.72 m, 117 L) |
| board | `tripletone_slalom_117`, `savanna_slalom_117`, `moonboard_slalom_117`, `bmx_boards_slalom_117`, `forbidden_slalom_117` | Chord, Acacia, Crescent, Sprocket, Contraband | `board_default.tres` |
| board | `forbidden_freerace_120` | Curfew | `board_freeride_240.tres` (2.40 x 0.72 m, 120 L) |
| sail | `savanna_slalom_8_0` (**default**, cloth white = today's red) | Cheetah | `sail_default.tres` (8.0) |
| sail | `tripletone_slalom_8_0`, `point9_slalom_8_0`, `nielstrots_slalom_8_0` | Arpeggio, Radix, Pennant | `sail_default.tres` |
| sail | `southsails_freerace_6_5`, `s3kauai_freerace_6_5`, `gg_sails_freerace_6_5` | Due South, Lagoon, Rematch | `sail_6_5.tres` |
| fin | `pj_new_sealand_slalom_38` (**default**) | Whisker | `fin_default.tres` (38 cm) |

The default board and sail belong to the game's brands that stand for the makers of the real gear they were modelled on (`tools/blender/build_rig_models.py` names it; [brands.md](brands.md) pairs the names). The model names and wind ranges are made up for now; the researcher's numbers replace them.

## Screenshots

| What | File (in the worktree `WindsurfingMMZB-page`) | Command |
|---|---|---|
| The Board tab | `.screenshots/gear_page.png` | `tools/screenshot.sh res://ui/start_menu.tscn .screenshots/gear_page.png 120 --page=gear` |
| The Sail tab, the 6.5 chosen | `.screenshots/gear_page_sail.png` | `... --page=gear/sail --settings=<file with [gear] sail="southsails_freerace_6_5">` |
| The Board tab, the 240 chosen (a brand with two boards) | `.screenshots/gear_page_board240.png` | `... --page=gear/board --settings=<file with [gear] board="forbidden_freerace_120">` |
| The Fin tab | `.screenshots/gear_page_fin.png` | `... --page=gear/fin` |
| The main menu with the Gear button | `.screenshots/gear_menu.png` | `tools/screenshot.sh res://ui/start_menu.tscn .screenshots/gear_menu.png 60` |
| Sailing with the 6.5 (SouthSails navy), F1 panel open | `.screenshots/gear_sailing.png` | `tools/screenshot.sh res://main.tscn .screenshots/gear_sailing.png 300 --autopilot=1 --camera=2 --settings=<file>` |
| Sailing with the default 8.0, for comparison | `.screenshots/gear_sailing_default.png` | the same with `sail="savanna_slalom_8_0"` |
| The stretched 6.5 from the rig view | `.screenshots/rig/rig_starboard_{port,boom,three_quarter,masthead}_gear.png` | `tools/screenshot.sh res://dev/rig_view.tscn .screenshots/rig/view.png 600 --gear_sail=southsails_freerace_6_5 --views=port,boom,three_quarter,masthead` |

A settings file for a screenshot needs only the `[gear]` section, for example:

```
[gear]

sail="southsails_freerace_6_5"
```

## The measurement: what the sail sizes do today (PH14)

The board is sailed by the player's beginner controller with the auto-sheet, holding a beam reach (true wind angle 90°), with the push harness (`Game/dev/run_push.gd`). Each case is one run, on one gust pattern. The speeds are **speeds made good along the course, m/s**. Falls: **none in any case**.

**The game's sea and gusts** (waves, gusts of 20 % every 8 s, the wind's height gradient; 150 s per case, the means from 40 s on):

| Wind | Default (8.0, 117 L board) | The 6.5 (same board) | The 240 freeride board (with the 8.0) |
|---|---|---|---|
| 12 kt | **8.63** (planing 72 % of the time) | **2.91** (6 %: it never really planes) | 8.83 (39 %) |
| 18 kt | 11.99 (65 %) | **12.46** (62 %), heels up to 12° | 11.97 (54 %) |
| 24 kt | 13.34 (63 %) | **14.09** (60 %), heels up to 15° | 13.22 (57 %) |

**Off the line** (the same sea, the mean over the first 15 s from rest):

| Wind | 8.0 | 6.5 | 240 board |
|---|---|---|---|
| 12 kt | 2.18 | 1.80 | 2.27 |
| 18 kt | 6.95 | 6.02 | 7.05 |
| 24 kt | 8.72 | 9.48 | 8.98 |

**A steady wind on flat water** (no gusts, no waves; 150 s, the means from 40 s):

| Wind | 8.0 | 6.5 | 240 board |
|---|---|---|---|
| 12 kt | 7.90 (planing 100 %) | 2.46 (0 %) | 8.41 (12 %, pitching: SD 1.1°) |
| 18 kt | 13.11 | 13.24 | 12.85 |
| 24 kt | 14.85 | 15.44 | 14.11 |

What it shows:

1. **With each sail's own numbers, the bigger sail is the faster one in light wind.** In 12 kt the 8.0 planes and the 6.5 doesn't (8.6 against 2.9 m/s), and the 8.0 is also quicker off the line (2.18 against 1.80 m/s over the first 15 s). PH14's warning came from Session 53, where only the sail's *area* was changed on the 6.5's rig (`Persona.rig()`). That set-up made a 7.8 slower than the 6.5. With the full configs (the 8.0's own luff, boom, rig mass and mast foot), the order is the right way round in 12 kt.
2. **From 18 kt the 6.5 is a little faster** (+4 % in 18 kt and +6 % in 24 kt in the gusts; +1 % and +4 % in a steady wind). It heels more, but neither sail ever falls: the auto-sheet eases the 8.0 enough. On the water, an 8.0 in 24 kt is hard to hold and costs falls. Whether the 8.0 should cost more in strong wind is a question for PH14's tuning.
3. **The 240 freeride board sails much like the default slalom board** (within 2 % from 18 kt). It is a little faster in 12 kt, but its config is the game's old one and does not fit the 8.0 well:
   - it has no footstrap positions;
   - the fin's root and the mast foot are placed for the 2.28 m board (they live in the fin's and the sail's configs, as distances from the board's middle);
   - in a steady 12 kt it pitches (SD 1.1°) and planes only 12 % of the time.

   See the open questions.

The commands (from the worktree's root, about 5 minutes in all, one Godot at a time):

```
tools/push_check.sh --winds=12,18,24 --twas=90 --gear_sail=savanna_slalom_8_0 --run=gear_sail80
tools/push_check.sh --winds=12,18,24 --twas=90 --gear_sail=southsails_freerace_6_5 --run=gear_sail65
tools/push_check.sh --winds=12,18,24 --twas=90 --gear_board=forbidden_freerace_120 --run=gear_board240
#   off the line: add --seconds=15 --from=0; steady and flat: add --gusts=0 --waves=0
```

The results are in `.sim_output/push/gear_*/results.csv`.

## Verified, and not

**Verified:**
- The unit tests (the new `test_gear.gd`: the catalogue, the defaults number for number, the settings' round trip, an unknown id, the sim and the scene and the lake on the chosen gear, the rig's pictures and stretch, the page, its keyboard walk, the start menu sailing the new gear).
- `tools/check.sh`.
- The screenshots above (I looked at each one).
- The 6.5's fit in the rig view: the boom on the mast at the simulation's height, its end at the clew, the head under the mast top. The default 8.0 shows the same small boom overhang past the leech in that view.

**Not verified:**
- How the page looks and reads on the team's screens. I only saw it at 1280x720.
- The gamepad. The page uses the same focus rules as the other pages, and a test walks it with Down from the tabs to Back, but no gamepad was pressed.
- How the 6.5 feels to sail. The numbers are above; the feel is the team's.
- Windows and the exported game. The folder listing is meant to work there (`ResourceLoader.list_directory`), but I didn't run an export.

## Open questions for the team

1. **The default sail's colour.** The default sail (Savanna Cheetah 8.0) keeps today's red, so nothing changes for a player who doesn't open the page. The other sails take their brand's main colour. Should the default sail wear Savanna's terracotta too?
2. **Where the mast foot and the fin sit (Michiel).** The physics takes the mast foot from the *sail's* config and the fin's root from the *fin's* config, both as distances from the board's middle. On a board of another length (the 240), both stay where they are on the 2.28 m board: the fin sits 24 cm from the tail instead of 18. Real boards carry the mast track and the fin box, and `BoardConfig` already has `mast_track_*` and `fin_box_*`. Should the physics take them from the board (a physics change, so Michiel's)? Until then, a board item of another length needs a sail and a fin set up for it.
3. **Fins and brands.** None of the eleven brands makes fins, so the one fin is PJ New Sealand's (fins come with the board). Should the fins have brands of their own, or stay with the board makers?
4. **The 8.0 in strong wind** (PH14). Today the 8.0 never falls in 24 kt with the auto-sheet, and is only 6 % slower than the 6.5. Should the bigger sail cost more there?
5. **Gear while paused.** The page is only on the start menu. Should it also be on the pause menu? A change while sailing would build the player's board again, like the restart.
6. **Time trials per gear.** The time trial's best times (GP4) are kept per course and wind, not per gear. With sail sizes to choose, a record per sail size may be wanted.
7. **The main menu at 1280x720** is taller than the screen: the title is cut at the top. This was already so before the Gear button (checked with the old menu). The team plays at a bigger size, so it may not matter.
